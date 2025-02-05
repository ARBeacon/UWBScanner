//
//  BeaconsView.swift
//  UWBScanner
//
//  Created by Maitree Hirunteeyakul on 01/02/2025.
//

import SwiftUI

struct BeaconsView: View {
    
    let beacons:[Beacon]
    
    var body: some View {
        VStack {
            List(beacons){ beacon in
                NavigationLink(destination: BeaconView(beacon: beacon)) {
                    VStack {
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
            }
        }
    }
}

#Preview {
    BeaconsView(beacons: [])
}
