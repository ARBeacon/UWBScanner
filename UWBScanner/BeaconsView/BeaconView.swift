//
//  BeaconView.swift
//  UWBScanner
//
//  Created by Maitree Hirunteeyakul on 01/02/2025.
//

import SwiftUI

struct BeaconView: View {
    
    @StateObject var beacon: Beacon
    @EnvironmentObject var uwbManager: UWBManager
    
    var uwbState: UWBManager.UWBState {
        uwbManager.uwbState
    }
    
    var showConnectButton: Bool {
        guard case .busy(let currentBeaconCommunication) = uwbState else { return true }
        return currentBeaconCommunication.beacon.id != beacon.id
    }
    
    var body: some View {
        ScrollView {
            HStack {
                Text("\(beacon.peripheral.name ?? "Unknown")").font(.title)
                Spacer()
            }
            if let lastCBScan = beacon.lastCBScan {
                Divider()
                HStack {
                    Spacer()
                    Text("RSSI: \(lastCBScan.rssi) dBm")
                }
                HStack {
                    Spacer()
                    Text("Last seen: \(DateFormatter.localizedString(from: lastCBScan.timestamp, dateStyle: .none, timeStyle: .medium))")
                }
            }
            
            if let lastRanging = beacon.lastRanging {
                Divider()
                if let location = lastRanging.location{
                    HStack {
                        Text("Distance")
                        Spacer()
                        let distanceString: String = (location.distance != nil) ? "\(String(format: "%.2f",location.distance!))" : "N/A"
                        Text("\(distanceString) m")
                    }
                    VStack {
                        HStack{
                            Text("Direction")
                            Spacer()
                        }
                        if let direction = location.direction{
                            HStack{
                                Spacer()
                                Text("\(String(format: "%.2f", direction.x))")
                                Spacer()
                                Text("\(String(format: "%.2f", direction.y))")
                                Spacer()
                                Text("\(String(format: "%.2f", direction.z))")
                                Spacer()
                            }
                        } else {
                            Text("N/A")
                        }
                    }
                    HStack {
                        Text("Horizontal Angle")
                        Spacer()
                        if let horizontalAngle = location.horizontalAngle {
                            let degree = horizontalAngle * 180 / Float.pi
                            Text("\(String(format: "%.0f", degree))°")
                        } else {
                            Text("N/A")
                        }
                    }
                }
                
                VStack {
                    HStack{
                        Text("World Map Position")
                        Spacer()
                    }
                    if let position = lastRanging.worldMapPosition {
                        HStack{
                            Spacer()
                            Text("\(String(format: "%.2f", position.x))")
                            Spacer()
                            Text("\(String(format: "%.2f", position.y))")
                            Spacer()
                            Text("\(String(format: "%.2f", position.z))")
                            Spacer()
                        }
                    } else {
                        Text("N/A")
                    }
                }
                HStack {
                    Spacer()
                    Text("Last ranging: \(DateFormatter.localizedString(from: lastRanging.timestamp, dateStyle: .none, timeStyle: .medium))")
                }
            }
        }.padding().toolbar{
            VStack{
                if showConnectButton{
                    Button("Connect"){
                        uwbManager.connect(to: beacon)
                    }
                }
                else {
                    Button("Disconnect"){
                        uwbManager.disconnect(from: beacon)
                    }.foregroundColor(.red)
                }
            }
        }
    }
}




