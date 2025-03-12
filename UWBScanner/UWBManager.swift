//
//  UWBManager.swift
//  UWBScanner
//
//  Created by Maitree Hirunteeyakul on 01/02/2025.
//

import CoreBluetooth
import NearbyInteraction
import ARKit

struct TransferService {
    static let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let rxCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    static let txCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
}

struct QorvoNIService {
    static let serviceUUID = CBUUID(string: "2E938FD0-6A61-11ED-A1EB-0242AC120002")
    
    static let scCharacteristicUUID = CBUUID(string: "2E93941C-6A61-11ED-A1EB-0242AC120002")
    static let rxCharacteristicUUID = CBUUID(string: "2E93998A-6A61-11ED-A1EB-0242AC120002")
    static let txCharacteristicUUID = CBUUID(string: "2E939AF2-6A61-11ED-A1EB-0242AC120002")
}

enum MessageId: UInt8 {
    // Messages from the accessory.
    case accessoryConfigurationData = 0x1
    case accessoryUwbDidStart = 0x2
    case accessoryUwbDidStop = 0x3
    
    // Messages to the accessory.
    case initialize = 0xA
    case configureAndStart = 0xB
    case stop = 0xC
    
    // User defined/notification messages
    case getReserved = 0x20
    case setReserved = 0x21
    
    case iOSNotify = 0x2F
}

class Beacon: Identifiable, ObservableObject, Hashable {
    static func == (lhs: Beacon, rhs: Beacon) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    let id = UUID()
    let peripheral: CBPeripheral
    var niSession: NISession? = nil
    
    struct CBScanResult {
        let timestamp: Date
        let advertisementData: [String: Any]
        let rssi: NSNumber
    }
    
    struct RangingResult {
        let timestamp: Date
        let location: NINearbyObject?
        let worldMapPosition: simd_float3?
    }
    
    @Published var lastCBScan: CBScanResult? = nil
    @Published var lastRanging: RangingResult? = nil
    
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
    }
    
    func identifier() -> UUID {
        return peripheral.identifier
    }
}

class UWBManager: NSObject, ObservableObject {
    @Published private(set) var beacons: [Beacon] = []
    
    private var centralManager: CBCentralManager!
    var isBluetoothOn: Bool = false
    
    struct CurrentBeaconCommunication {
        let beacon: Beacon
        var rxCharacteristic: CBCharacteristic?
        var txCharacteristic: CBCharacteristic?
    }
    
    enum UWBState {
        case idle
        case busy(with: CurrentBeaconCommunication)
    }
    @Published private(set) var uwbState: UWBState = .idle
    
    private var arViewModel: ARViewModel
    init(arViewModel: ARViewModel) {
        self.arViewModel = arViewModel
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        startScaning()
    }
    
    deinit {
        centralManager.stopScan()
    }
    
    private var beaconARAnchor: [Beacon: SCNNode] = [:]
}

extension UWBManager {
    func startScaning() {
        if !isBluetoothOn { return }
        centralManager.scanForPeripherals(withServices: [TransferService.serviceUUID, QorvoNIService.serviceUUID],
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
}

// Scanning Logic
extension UWBManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            isBluetoothOn = true
            startScaning()
        default:
            print("Bluetooth is not ready")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let beacon = getOrCreateBeacon(from: peripheral)
        beacon.lastCBScan = Beacon.CBScanResult(timestamp: Date(), advertisementData: advertisementData, rssi: RSSI)
        if let index = beacons.firstIndex(where: { $0.id == beacon.id }) { beacons[index] = beacon }
    }
    
    
    func sendData(_ data: Data, peripheral: CBPeripheral, chacteristic: CBCharacteristic){
        func packetData(_ data: Data, peripheral: CBPeripheral) -> Data {
            let mtu = peripheral.maximumWriteValueLength(for: .withResponse)
            let bytesToCopy: size_t = min(mtu, data.count)
            var rawPacket = [UInt8](repeating: 0, count: bytesToCopy)
            data.copyBytes(to: &rawPacket, count: bytesToCopy)
            let packetData = Data(bytes: &rawPacket, count: bytesToCopy)
            return packetData
        }
        peripheral.writeValue(
            packetData(data, peripheral: peripheral),
            for: chacteristic,
            type: .withResponse
        )
    }
    
}

extension UWBManager {
    private func getOrCreateBeacon(from peripheral: CBPeripheral) -> Beacon {
        if let beacon = beacons.first(where: {$0.peripheral == peripheral}) { return beacon }
        let newBeacon = Beacon(peripheral: peripheral)
        beacons.append(newBeacon)
        return newBeacon
    }
}

// MARK: Flow of UWB Ranging
extension UWBManager: CBPeripheralDelegate {
    func connect(to beacon: Beacon){
        if case .busy(let currentBeaconCommunication) = uwbState {
            let oldBeacon = currentBeaconCommunication.beacon
            disconnect(from: oldBeacon)
        }
        uwbState = .busy(with: CurrentBeaconCommunication(beacon: beacon))
        let peripheral = beacon.peripheral
        print("DEBUG: Connecting to \(peripheral.name ?? "Unknown"))")
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect(from beacon: Beacon){
        let peripheral = beacon.peripheral
        centralManager.cancelPeripheralConnection(peripheral)
        
        if let niSession = beacon.niSession {
            niSession.pause()
        }
        uwbState = .idle
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        print("DEBUG: didFailToConnect to \(peripheral.name ?? "Unknown")")
        uwbState = .idle
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("DEBUG: didConnect to \(peripheral.name ?? "Unknown")")
        peripheral.delegate = self
        peripheral.discoverServices([TransferService.serviceUUID, QorvoNIService.serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("DEBUG: didDisconnectPeripheral to \(peripheral.name ?? "Unknown")")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("DEBUG: didDiscoverServices to \(peripheral.name ?? "Unknown"))")
        guard let peripheralServices = peripheral.services else { return }
        for service in peripheralServices {
            peripheral.discoverCharacteristics([TransferService.rxCharacteristicUUID,
                                                TransferService.txCharacteristicUUID,
                                                QorvoNIService.rxCharacteristicUUID,
                                                QorvoNIService.txCharacteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("DEBUG: didDiscoverCharacteristicsFor \(peripheral.name ?? "Unknown"))")
        guard let serviceCharacteristics = service.characteristics else { return }
        guard case .busy(var currentBeaconCommunication) = uwbState else { return }
        
        for characteristic in serviceCharacteristics where characteristic.uuid == TransferService.rxCharacteristicUUID {
            currentBeaconCommunication.rxCharacteristic = characteristic
        }
        for characteristic in serviceCharacteristics where characteristic.uuid == QorvoNIService.rxCharacteristicUUID {
            currentBeaconCommunication.rxCharacteristic = characteristic
        }
        
        for characteristic in serviceCharacteristics where characteristic.uuid == TransferService.txCharacteristicUUID {
            currentBeaconCommunication.txCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }
        
        for characteristic in serviceCharacteristics where characteristic.uuid == QorvoNIService.txCharacteristicUUID {
            currentBeaconCommunication.txCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }
        
        let niSession = NISession()
        niSession.delegate = self
        
        if let arSession = arViewModel.sceneView?.session {
            niSession.setARSession(arSession)
        }
        
        currentBeaconCommunication.beacon.niSession = niSession
        let msg = Data([MessageId.initialize.rawValue])
        sendData(msg, peripheral: peripheral, chacteristic: currentBeaconCommunication.rxCharacteristic!)
        uwbState = .busy(with: currentBeaconCommunication)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            return
        }
        
        guard let data = characteristic.value else { return }
        guard let messageId = MessageId(rawValue: data.first!) else {
            fatalError("\(data.first!) is not a valid MessageId.")
        }
        
        switch messageId {
        case .accessoryConfigurationData:
            assert(data.count > 1)
            let configData = data.advanced(by: 1)
            do {
                let configuration = try NINearbyAccessoryConfiguration(data: configData)
                configuration.isCameraAssistanceEnabled = true
                guard case .busy(let currentBeaconCommunication) = uwbState else { return }
                currentBeaconCommunication.beacon.niSession?.run(configuration)
            } catch {
                print("ERROR: NINearbyAccessoryConfiguration could not be created: \(error)")
            }
        case .accessoryUwbDidStart:
            break
            // NOTE: handleAccessoryUwbDidStart(deviceID)
        case .accessoryUwbDidStop:
            guard case .busy(let currentBeaconCommunication) = uwbState else { return }
            disconnect(from: currentBeaconCommunication.beacon)
        default:
            break
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Check if the peripheral reported an error.
        if let error = error {
            print("Error changing notification state: \(error.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            // Indicates the notification began.
            print("Notification began on \(characteristic)")
        } else {
            // Because the notification stopped, disconnect from the peripheral.
            print("Notification stopped on \(characteristic). Disconnecting")
        }
    }
}

// MARK: - `NISessionDelegate`.
extension UWBManager: NISessionDelegate {
    func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject) {
        var msg = Data([MessageId.configureAndStart.rawValue])
        msg.append(shareableConfigurationData)
        guard case .busy(let currentBeaconCommunication) = uwbState else { return }
        let peripheral = currentBeaconCommunication.beacon.peripheral
        
        sendData(msg, peripheral: peripheral, chacteristic: currentBeaconCommunication.rxCharacteristic!)
    }
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let accessory = nearbyObjects.first else { return }
        guard case .busy(let currentBeaconCommunication) = uwbState else { return }
        
        let beacon = currentBeaconCommunication.beacon
        
        func fullfilWorldMapPosition(_ wordMapPosition: simd_float3?) -> simd_float3? {
            if wordMapPosition == nil {
                return currentBeaconCommunication.beacon.lastRanging?.worldMapPosition
            } else {
                return wordMapPosition
            }
        }
        let wordMapPosition = fullfilWorldMapPosition(session.worldTransform(for: accessory)?.translation)
        
        beacon.lastRanging = Beacon.RangingResult(
            timestamp: Date(),
            location: accessory,
            worldMapPosition: wordMapPosition
        )
        
        putToAR(beacon)
        sendBeaconLocationToLogger(beacon)
        
        if let index = beacons.firstIndex(where: { $0 == beacon }) { beacons[index] = beacon }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        if nearbyObjects.first == nil { return }
        guard case .busy(let currentBeaconCommunication) = uwbState else { return }
        disconnect(from: currentBeaconCommunication.beacon)
    }
    
    func session(_ session: NISession, didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence, for object: NINearbyObject?){
        
    }
    
    func sessionWasSuspended(_ session: NISession) {
        let msg = Data([MessageId.stop.rawValue])
        guard case .busy(let currentBeaconCommunication) = uwbState else { return }
        guard let rxCharacteristic = currentBeaconCommunication.rxCharacteristic else { return }
        sendData(msg, peripheral: currentBeaconCommunication.beacon.peripheral, chacteristic: rxCharacteristic)
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        let msg = Data([MessageId.initialize.rawValue])
        guard case .busy(let currentBeaconCommunication) = uwbState else { return }
        guard let rxCharacteristic = currentBeaconCommunication.rxCharacteristic else { return }
        sendData(msg, peripheral: currentBeaconCommunication.beacon.peripheral, chacteristic: rxCharacteristic)
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error){
        
    }
    
}

// MARK: Logger helper
extension UWBManager {
    private func sendBeaconLocationToLogger(_ beacon: Beacon){
        struct LocationUpdateLog: Codable {
            let beaconName: String?
            let position: simd_float3?
        }
        Logger.addLog(
            label: "Beacon Location Update",
            content: LocationUpdateLog(
                beaconName: beacon.peripheral.name,
                position: beacon.lastRanging?.worldMapPosition
            )
        )
    }
}

extension UWBManager {
    private func putToAR(_ beacon: Beacon){
        guard let position = beacon.lastRanging?.worldMapPosition else { return }
        guard let scene = arViewModel.sceneView?.scene else { return }
        
        let colorList: [UIColor] = [.red, .blue, .yellow, .green, .orange]
        
        if let sphereNode = beaconARAnchor[beacon] {
            sphereNode.position = SCNVector3(x: position.x, y: position.y, z: position.z)
            if let worldMapDefaultOrientation = arViewModel.worldMapDefaultOrientation {
                let orientationVector = worldMapDefaultOrientation.vector
                sphereNode.orientation = SCNQuaternion(orientationVector)
            }
        } else {
            let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.02))
            sphereNode.geometry?.firstMaterial?.diffuse.contents = colorList.randomElement()
            sphereNode.position = SCNVector3(x: position.x, y: position.y, z: position.z)
            if let worldMapDefaultOrientation = arViewModel.worldMapDefaultOrientation {
                let orientationVector = worldMapDefaultOrientation.vector
                sphereNode.orientation = SCNQuaternion(orientationVector)
            }
            
            let axisLength: Float = 0.1
            let xAxis = SCNNode(geometry: SCNCylinder(radius: 0.001, height: CGFloat(axisLength)))
            xAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            xAxis.position = SCNVector3Make(Float(axisLength) / 2, 0, 0)
            xAxis.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            
            let yAxis = SCNNode(geometry: SCNCylinder(radius: 0.001, height: CGFloat(axisLength)))
            yAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            yAxis.position = SCNVector3Make(0, Float(axisLength) / 2, 0)
            
            let zAxis = SCNNode(geometry: SCNCylinder(radius: 0.001, height: CGFloat(axisLength)))
            zAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            zAxis.position = SCNVector3Make(0, 0, Float(axisLength) / 2)
            zAxis.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            
            sphereNode.addChildNode(xAxis)
            sphereNode.addChildNode(yAxis)
            sphereNode.addChildNode(zAxis)
            
            scene.rootNode.addChildNode(sphereNode)
            beaconARAnchor[beacon] = sphereNode
        }
    }
}

import RealityKit
extension simd_float4x4 {
    var translation: simd_float3 {
        return [columns.3.x, columns.3.y, columns.3.z]
    }
    
    var rotation: simd_quatf {
        return Transform(matrix: self).rotation
    }
    
    var scale: simd_float3 {
        return [
            simd_length(simd_float3(columns.0.x, columns.0.y, columns.0.z)),
            simd_length(simd_float3(columns.1.x, columns.1.y, columns.1.z)),
            simd_length(simd_float3(columns.2.x, columns.2.y, columns.2.z)),
        ]
    }
}


