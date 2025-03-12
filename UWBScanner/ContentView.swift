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
    
    
    var trueHeading: Double? {
        arViewModel.trueHeading
    }
    
    var worldMapDefaultOrientation: simd_quatf? {
        arViewModel.worldMapDefaultOrientation
    }
    
    var isAutoSchedulingOn: Bool {
        uwbManager.isAutoSchedulingOn
    }
    
    var body: some View {
        VStack{
            if !isShowingARView {
                NavigationStack {
                    BeaconsView(uwbManager: uwbManager)
                        .navigationTitle("UWB Beacons")
                        .toolbar {
                            Toggle(isOn:
                                    Binding(
                                        get:{isAutoSchedulingOn},
                                        set:{_ in
                                            uwbManager.toggleAutoScheduling()
                                        }
                                    )
                            )
                            { Text("Auto Scheduling") }
                                .tint(.green)
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
