//
//  UWBScannerApp.swift
//  UWBScanner
//
//  Created by Maitree Hirunteeyakul on 31/01/2025.
//

import SwiftUI

@main
struct UWBScannerApp: App {
    init(){
        Logger.addLog(label: "Application launched")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
