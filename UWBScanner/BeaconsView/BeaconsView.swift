//  BeaconsView.swift
//  UWBScanner
//
//  Created by Maitree Hirunteeyakul on 01/02/2025.
//

import SwiftUI

struct BeaconsView: View {
    
    @StateObject var uwbManager: UWBManager
    
    var beacons: [Beacon] {
        uwbManager.beacons
    }
    
    var isAutoSchedulingOn: Bool {
        uwbManager.isAutoSchedulingOn
    }
    
    var doneAutoRanging: Set<Beacon> {
        uwbManager.doneAutoRanging
    }
    
    var currentBeacon: Beacon? {
        if case .busy(let currentBeaconCommunication) = uwbManager.uwbState { return currentBeaconCommunication.beacon }
        return nil
    }
    
    var body: some View {
        List(beacons) { beacon in
            VStack {
                NavigationLink(destination: BeaconView(
                    beacon: beacon,
                    isAutoSchedulingOn: isAutoSchedulingOn
                )) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("\(beacon.peripheral.name ?? "Unknown")")
                            Spacer()
                        }
                        if let lastCBScan = beacon.lastCBScan {
                            HStack {
                                Spacer()
                                Text("RSSI: \(lastCBScan.rssi) dBm")
                            }
                            HStack {
                                Spacer()
                                Text("Last seen: \(DateFormatter.localizedString(from: lastCBScan.timestamp, dateStyle: .none, timeStyle: .medium))")
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, isAutoSchedulingOn ? 1 : 13)
                
                if isAutoSchedulingOn {
                    HStack {
                        Spacer()
                        Text(statusText(for: beacon))
                        Spacer()
                    }
                    .background(statusColor(for: beacon))
                    .foregroundColor(.white)
                    .listRowInsets(EdgeInsets())
                }
            }
            .padding(.horizontal, -20)
            .padding(.bottom, -13)
        }
    }
    
    private func statusText(for beacon: Beacon) -> String {
        if currentBeacon == beacon {
            return "Ranging"
        } else if doneAutoRanging.contains(beacon) {
            return "Finished Ranging"
        } else {
            return "Queued"
        }
    }
    
    private func statusColor(for beacon: Beacon) -> Color {
        if currentBeacon == beacon {
            return Color.orange
        } else if doneAutoRanging.contains(beacon) {
            return Color.green
        } else {
            return Color.red
        }
    }
}
