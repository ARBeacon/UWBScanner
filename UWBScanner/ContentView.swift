//
//  ContentView.swift
//  UWBScanner
//
//  Created by Maitree Hirunteeyakul on 31/01/2025.
//

import SwiftUI
import ARKit

struct ContentView: View {
    
    @StateObject private var uwbManager: UWBManager
    @StateObject private var arViewModel: ARViewModel = ARViewModel()
    
    @State private var isShowingARView: Bool = false
    
    init() {
        let arViewModel = ARViewModel()
        _uwbManager = StateObject(wrappedValue: UWBManager(arViewModel: arViewModel))
        _arViewModel = StateObject(wrappedValue: arViewModel)
        
    }
    
    var beacons: [Beacon] {
        uwbManager.beacons
    }
    
    var trueHeading: Double? {
        arViewModel.trueHeading
    }
    
    var worldMapDefaultOrientation: simd_quatf? {
        arViewModel.worldMapDefaultOrientation
    }
    
    var body: some View {
        VStack{
            if !isShowingARView {
                NavigationView {
                    BeaconsView(beacons: beacons)
                        .navigationTitle("UWB Beacons")
                }
                .environmentObject(uwbManager)
                HeadingBar(worldMapDefaultOrientation: worldMapDefaultOrientation, trueHeading: trueHeading, isShowingARView: $isShowingARView)
            }
            else {
                HeadingBar(worldMapDefaultOrientation: worldMapDefaultOrientation, trueHeading: trueHeading, isShowingARView: $isShowingARView)
                ARViewContainer(arViewModel: arViewModel).ignoresSafeArea(.all)
            }
        }
    }
}

#Preview {
    ContentView()
}
