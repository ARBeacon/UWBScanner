import UIKit
import SceneKit
import PlaygroundSupport
import simd
import SwiftUI

let scene = SCNScene()

@MainActor
func plotLine(from start: simd_float3 = simd_float3(0, 0, 0), to end: simd_float3, color: UIColor, weight: CGFloat = 0.005) -> Void {
    let midPoint = SCNVector3((start.x + end.x) / 2.0, (start.y + end.y) / 2.0, (start.z + end.z) / 2.0)
    let height = CGFloat(sqrtf(powf(end.x - start.x, 2) + powf(end.y - start.y, 2) + powf(end.z - start.z, 2)))
    let lineGeometry = SCNCylinder(radius: weight, height: height)
    lineGeometry.firstMaterial?.diffuse.contents = color
    
    let lineNode = SCNNode(geometry: lineGeometry)
    lineNode.position = midPoint
    
    let delta = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
    let direction = delta.normalized()
    let yAxis = SCNVector3(0, 1, 0)
    
    let dotProduct = yAxis.dot(other: direction)
    let crossProduct = yAxis.cross(other: direction)
    let angle = acos(dotProduct)
    
    lineNode.rotation = SCNVector4(crossProduct.x, crossProduct.y, crossProduct.z, angle)
    scene.rootNode.addChildNode(lineNode)
}

@MainActor
func plotSphere(_ position: simd_float3, color: UIColor, radius: CGFloat = 0.05) {
    let sphere = SCNSphere(radius: radius)
    sphere.firstMaterial?.diffuse.contents = color
    let node = SCNNode(geometry: sphere)
    node.position = SCNVector3(position)
    scene.rootNode.addChildNode(node)
}

@MainActor
func plotGlobalAxes() {
    let red = UIColor.red.withAlphaComponent(0.5)
    let green = UIColor.green.withAlphaComponent(0.5)
    let blue = UIColor.blue.withAlphaComponent(0.5)

    let center: simd_float3 = [0, 0, 0]
    plotSphere(center, color: .black)
    
    let x: simd_float3 = [1, 0, 0]
    plotSphere(x, color: red)
    plotSphere(-x, color: red)
    
    let y: simd_float3 = [0, 1, 0]
    plotSphere(y, color: green)
    plotSphere(-y, color: green)
    
    let z: simd_float3 = [0, 0, 1]
    plotSphere(z, color: blue)
    plotSphere(-z, color: blue)
    
    plotLine(to: x, color: red)
    plotLine(to: y, color: green)
    plotLine(to: z, color: blue)
}

@MainActor
func plotLocalAxes(_ orientation: simd_quatf, weight: CGFloat, height: Float){
    let quat = simd_normalize(orientation)
    let transformedX = quat.act(simd_float3(height, 0, 0))
    let transformedY = quat.act(simd_float3(0, height, 0))
    let transformedZ = quat.act(simd_float3(0, 0, height))
    plotLine(to: transformedX, color: .red, weight: weight)
    plotLine(to: transformedY, color: .green, weight: weight)
    plotLine(to: transformedZ, color: .blue, weight: weight)
}

@MainActor
func getJAxisAndPlotSphere(_ orientation: simd_quatf) -> simd_float3 {
    let quat = simd_normalize(orientation)
    let transformedY = quat.act(simd_float3(0, 0.75, 0))
    
    plotSphere(transformedY, color: .orange, radius: 0.025)
    plotLine(to: transformedY, color: .orange)
    return transformedY
}

@MainActor
func plotIAxis(_ orientation: simd_quatf, color: UIColor, weight: CGFloat = 0.005) {
    let quat = simd_normalize(orientation)
    let transformedX = quat.act(simd_float3(1, 0, 0))
    plotLine(to: transformedX, color: color, weight: weight)
    return
}

func rotateAroundGlobalYAxis(_ orientation: simd_quatf, angle: Float) -> simd_quatf {
    let globalY = simd_float3(0, 1, 0)
    let yAxisRotation = simd_quatf(angle: angle, axis: globalY)
    return orientation * yAxisRotation
}

func angleBetweenVectors(_ vectorA: simd_float3, _ vectorB: simd_float3) -> Float {
    let dotProduct = simd_dot(vectorA, vectorB)
    let magnitudeA = simd_length(vectorA)
    let magnitudeB = simd_length(vectorB)
    return acos(dotProduct / (magnitudeA * magnitudeB))
}

plotGlobalAxes()


let deviceOrientation = simd_normalize(simd_quatf(angle: Float(Angle(degrees: 10).radians), axis: simd_float3(x: 1, y: 1, z: 1)))
let trueHeading = Float(Angle(degrees: -120).radians)

@MainActor
func logic(){
    let j = getJAxisAndPlotSphere(deviceOrientation)
    let jProjectionOnXZ = simd_float3(x: j.x, y: 0, z: j.z)
    plotSphere(jProjectionOnXZ, color: .brown, radius: 0.025)
    let localHeading = angleBetweenVectors(simd_float3(1, 0, 0), jProjectionOnXZ)
    let gravityAlignedOrientation = rotateAroundGlobalYAxis(simd_quatf(angle: 0, axis: simd_float3(x: 0, y: 0, z: 0)), angle: -localHeading)
    plotIAxis(gravityAlignedOrientation, color: .brown)
    let normalOrietation = rotateAroundGlobalYAxis(gravityAlignedOrientation, angle: trueHeading)
    plotIAxis(normalOrietation, color: .black, weight: 0.01)
    plotLocalAxes(normalOrietation, weight: 0.025, height: 0.2)
}
logic()

let cameraNode = SCNNode()
cameraNode.camera = SCNCamera()
cameraNode.position = SCNVector3Make(0, 0, 2)
scene.rootNode.addChildNode(cameraNode)
let sceneView = SCNView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
sceneView.scene = scene
sceneView.allowsCameraControl = true
sceneView.backgroundColor = UIColor.white
PlaygroundPage.current.liveView = sceneView

extension SCNVector3 {
    func length() -> Float {
        return sqrt(x * x + y * y + z * z)
    }
    
    func normalized() -> SCNVector3 {
        let len = length()
        return len > 0 ? SCNVector3(x / len, y / len, z / len) : SCNVector3(0, 0, 0)
    }
    
    func dot(other: SCNVector3) -> Float {
        return x * other.x + y * other.y + z * other.z
    }
    
    func cross(other: SCNVector3) -> SCNVector3 {
        return SCNVector3(y * other.z - z * other.y, z * other.x - x * other.z, x * other.y - y * other.x)
    }
}
