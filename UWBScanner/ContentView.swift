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
    @State private var navigateToLogView: Bool = false
    
    @ObservedObject var logger: Logger = Logger.get()
    
    init(logger: Logger? = nil) {
        let arViewModel = ARViewModel()
        _uwbManager = StateObject(wrappedValue: UWBManager(arViewModel: arViewModel))
        _arViewModel = StateObject(wrappedValue: arViewModel)
        
        if let logger {
            logger.addLog(label: "ContentView Initialize", content: "Mocked Logger")
            _logger = ObservedObject(wrappedValue: logger)
        }
        else {
            let logger = Logger.get()
            logger.addLog(label: "ContentView Initialize")
            _logger = ObservedObject(wrappedValue:logger)
        }
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
                NavigationStack {
                    BeaconsView(beacons: beacons)
                        .navigationTitle("UWB Beacons")
                        .toolbar {
                            Button(action: {
                                navigateToLogView = true
                            }) {
                                Text("Log")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .navigationDestination(isPresented: $navigateToLogView) {
                            LogView(logger: logger)
                        }
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
