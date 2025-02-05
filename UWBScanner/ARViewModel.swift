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
        sceneView = makeARView()
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.headingFilter = kCLHeadingFilterNone
        locationManager.startUpdatingHeading()
    }
    
    public static var defaultConfiguration: ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic
        
        configuration.worldAlignment = .gravity
        configuration.isCollaborationEnabled = false
        configuration.userFaceTrackingEnabled = false
        configuration.initialWorldMap = nil
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
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        worldMapDefaultOrientation = getAlignedOrientation()
    }
}

extension ARViewModel {
    func getAlignedOrientation() -> simd_quatf? {
        guard let trueHeading = trueHeading else { return nil }
        guard let arSession = sceneView?.session else { return nil }
        guard let cameraOrientation = arSession.currentFrame?.camera.transform.rotation else { return nil }
        let headingAngle = Float(trueHeading * .pi / 180.0)
        
        // Rotate Q by A degrees about the Y-axis.
        let rotY = simd_quatf(angle: headingAngle, axis: simd_float3(0, 1, 0))
        let Qprime = rotY * cameraOrientation
        
        // Compute where the local J axis (0,1,0) ended up.
        let J = Qprime.act(simd_float3(0, 1, 0))
        let worldY = simd_float3(0, 1, 0)
        
        // Compute the axis (and angle) needed to rotate J into alignment with worldY.
        // The axis is the cross product of J and worldY.
        let cross = simd_cross(J, worldY)
        let dot = simd_dot(J, worldY)
        
        // Clamp dot to the valid range of acos.
        let dotClamped = simd_clamp(dot, -1, 1)
        let angleToAlign = acos(dotClamped)
        
        // If J is already (almost) aligned, then no extra rotation is needed.
        if abs(angleToAlign) < 1e-5 {
            return Qprime
        }
        
        // Normalize the rotation axis.
        let axisAlignment = simd_normalize(cross)
        
        let alignmentQuat = simd_quatf(angle: angleToAlign, axis: axisAlignment)
        let finalQuat = alignmentQuat * Qprime
        return finalQuat
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
