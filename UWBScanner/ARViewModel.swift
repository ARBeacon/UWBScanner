//
//  ARViewModel.swift
//  UWBScanner
//
//  Created by Maitree Hirunteeyakul on 05/02/2025.
//
import SwiftUI
import SceneKit
import ARKit

class ARViewModel: NSObject, ObservableObject, ARSessionDelegate, ARSCNViewDelegate {
    @Published var sceneView: ARSCNView?
    
    @Published private(set) var trueHeading: Double?
    @Published private(set) var worldMapDefaultOrientation: simd_quatf?
    
    private var locationManager: CLLocationManager!
    
    override init() {
        super.init()
        Logger.addLog(label: "Initialize ARViewModel")
        sceneView = makeARView()
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.headingFilter = kCLHeadingFilterNone
        locationManager.startUpdatingHeading()
        Logger.addLog(label: "Finished Initialize ARViewModel")
    }
    
    public static var defaultConfiguration: ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic
        
        configuration.worldAlignment = .gravity
        configuration.isCollaborationEnabled = false
        configuration.userFaceTrackingEnabled = false
        configuration.initialWorldMap = nil
        
        if let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) {
            print("DEBUG: Found \(referenceImages.count) AR reference images")
            configuration.detectionImages = referenceImages
        }
        
        return configuration
    }
    
    func makeARView() -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.session.run(ARViewModel.defaultConfiguration, options: [.removeExistingAnchors,.resetSceneReconstruction,.resetTracking])
        return sceneView
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return false
    }
    
}

// MARK: Logic for worldMapDefaultOrientation
extension ARViewModel {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if let alignedOrientation = getAlignedOrientation(){
            worldMapDefaultOrientation = alignedOrientation
        }
    }
    
    func getAlignedOrientation() -> simd_quatf? {
        guard let trueHeadingDegrees = trueHeading else { return nil }
        let trueHeading = Angle(degrees: trueHeadingDegrees).radians
        guard let arSession = sceneView?.session else { return nil }
        guard let cameraOrientation = arSession.currentFrame?.camera.transform.rotation else { return nil }
        
        // https://stackoverflow.com/questions/57501327/arkit-arcamera-transform-incorrectly-rotated-90-degrees-clockwise
        // https://stackoverflow.com/questions/59671828/what-is-the-orientation-of-arkits-camera-space#:~:text=landscapeRight%20orientation%E2%80%94that%20is%2C%20the,device%20on%20the%20screen%20side.
        let deviceOrientation = cameraOrientation * simd_quatf(angle: .pi/2, axis: simd_float3(x: 0, y: 0, z: 1))
        
        func getJAxis(_ orientation: simd_quatf) -> simd_float3 {
            let quat = simd_normalize(orientation)
            let transformedY = quat.act(simd_float3(x: 0, y: 1, z: 0))
            return transformedY
        }
        
        let globalY = simd_float3(x: 0, y: 1, z: 0)
        let j = getJAxis(deviceOrientation)
        
        func isInRetrivalRange() -> Bool{
            let isOnDepression: Bool = j.y < 0.1
            func getKAxis(_ orientation: simd_quatf) -> simd_float3 {
                let quat = simd_normalize(orientation)
                let transformedZ = quat.act(simd_float3(x: 0, y: 0, z: 1))
                return transformedZ
            }
            let isOnElevation: Bool = getKAxis(deviceOrientation).y < 0.1
            return !isOnDepression && !isOnElevation
        }
        if !isInRetrivalRange() { return nil }
        
        let jProjectionOnXZ = simd_float3(x: j.x, y: 0, z: j.z)
        
        func getSIM3DString(_ vector: simd_float3) -> String {
            return "(\(String(format: "%.2f", vector.x)), \(String(format: "%.2f", vector.y)), \(String(format: "%.2f", vector.z)))"
        }
        // print("\(getSIM3DString(j)) \(getSIM3DString(jProjectionOnXZ))")
        
        func signedAngleBetweenVectors(_ vectorA: simd_float3, _ vectorB: simd_float3) -> Float {
            let dotProduct = simd_dot(vectorA, vectorB)
            let magnitudeA = simd_length(vectorA)
            let magnitudeB = simd_length(vectorB)
            let angle = acos(dotProduct / (magnitudeA * magnitudeB))
            let crossProduct = simd_cross(vectorA, vectorB)
            let direction = simd_dot(crossProduct, globalY)
            return (direction < 0) ? angle : -angle
        }
        
        let localHeading = signedAngleBetweenVectors(simd_float3(x: 1, y: 0, z: 0), jProjectionOnXZ)
        
        if localHeading.isNaN { return nil }
        
        let northRoatationLocalRelativeAngle = localHeading-Float(trueHeading)
        
        func normalizeRadian(_ angle: Float) -> Float{
            let aRound = 2*Float.pi
            var r = angle
            while r >= aRound || r < 0 {
                if r >= aRound { r -= aRound }
                else { r += aRound }
            }
            return r
        }
        
        let normalOrietation = simd_quatf(angle: normalizeRadian(northRoatationLocalRelativeAngle), axis: simd_float3(x: 0, y: -1, z: 0))
        
        func getAngleString(_ angle: Float) -> String {
            if angle.isNaN { return "NaN" }
            if angle < 0 { return "-" + getAngleString(-angle) }
            return String(format: "%.2f", angle*180.0/Float.pi)
        }
        
        // print("Local: \(getAngleString(localHeading)), Global: \(getAngleString(Float(trueHeading))) = \(String(format: "%.2f", northRoatationLocalRelativeAngle))")
        
        return normalOrietation
    }
}

// MARK: - `CLLocationManagerDelegate`.
extension ARViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        trueHeading = newHeading.trueHeading
    }
    
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return true
    }
}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var arViewModel: ARViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        return arViewModel.sceneView ?? ARSCNView()
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

// MARK: ImageAnchor
struct AnchorLog: Encodable{
    let name: String?
    let identifier: UUID
    let transform: simd_float4x4
}

extension ARViewModel {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        print(anchor)
        switch anchor {
        case let imageAnchor as ARImageAnchor:
            handleImageAnchor(imageAnchor, node: node)
        case _ as ARPlaneAnchor: break
        default: break
        }
        
        func handleImageAnchor(_ imageAnchor: ARImageAnchor, node: SCNNode) {
            
            Logger.addLog(
                label: "ARImageAnchor didAdd",
                content: AnchorLog(
                    name: imageAnchor.referenceImage.name,
                    identifier: imageAnchor.identifier,
                    transform: imageAnchor.transform
                )
            )
            
            let planeNode = createPlaneNode(for: imageAnchor)
            
            node.addChildNode(planeNode)
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        
        for anchor in anchors {
            switch anchor {
            case let imageAnchor as ARImageAnchor:
                handleImageAnchor(imageAnchor)
            case _ as ARPlaneAnchor: break
            default: break
            }
        }
        
        func handleImageAnchor(_ imageAnchor: ARImageAnchor) {
            Logger.addLog(
                label: "ARImageAnchor didUpdate",
                content: AnchorLog(
                    name: imageAnchor.referenceImage.name,
                    identifier: imageAnchor.identifier,
                    transform: imageAnchor.transform)
            )
        }
        
    }
    
    private func createPlaneNode(for imageAnchor: ARImageAnchor) -> SCNNode {
        let referenceImage = imageAnchor.referenceImage
        let plane = SCNPlane(width: referenceImage.physicalSize.width, height: referenceImage.physicalSize.height)
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x = -.pi / 2
        
        plane.firstMaterial?.diffuse.contents = UIColor.blue.withAlphaComponent(0.8)
        
        return planeNode
    }
}
