//
//  Logger.swift
//  UWBScanner
//
//  Created by Maitree Hirunteeyakul on 1/3/2025.
//
import Foundation

struct Log: Identifiable, Encodable{
    let id = UUID()
    var timestamp: Date
    var label: String
    var content: Encodable?
    
    enum CodingKeys: String, CodingKey {
        case timestamp, label, content
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp.timeIntervalSince1970, forKey: .timestamp)
        try container.encode(label, forKey: .label)
        if let content = content{
            try container.encode(content, forKey: .content)
        }
    }
}

struct FlushedLog: Identifiable{
    let id = UUID()
    var timestamp: Date
    let logs: [Log]
}

class Logger: ObservableObject {
    @Published public private(set) var logs: [Log] = []
    @Published public private(set) var flushedLogs: [FlushedLog] = []
    public let sessionIdentifier = UUID().uuidString
    private static var instance: Logger?
    
    static func get() -> Logger {
        if let instance = instance {
            return instance
        } else {
            let newInstance = Logger()
            instance = newInstance
            return newInstance
        }
    }
    
    public static func addLog(label: String, content: Encodable? = nil){
        self.get().addLog(label: label, content: content)
    }
    
    public func addLog(label: String, content: Encodable? = nil){
        DispatchQueue.main.async {
            self.logs.append(Log(timestamp: Date(), label: label, content: content))
        }
    }
    
    @MainActor
    public func save() async {
        let currentDateTime = Date()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss" // Example format: "2024-10-03_14-22-30"
        let dateTimeString = formatter.string(from: currentDateTime)
        
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentDirectory.appendingPathComponent("\(dateTimeString)-\(sessionIdentifier)-ble-arkit-log.json")
            
            do {
                let data = try JSONEncoder().encode(self.logs)
                try data.write(to: fileURL, options: .atomic)
                print("File saved: \(fileURL)")
            } catch {
                print("Error saving file: \(error.localizedDescription)")
            }
        }
        self.flushedLogs.append(FlushedLog(timestamp: currentDateTime, logs: self.logs))
        self.logs = [];
    }
    
}

import ARKit
extension simd_float4x4: @retroactive Encodable {
    enum CodingKeys: String, CodingKey {
        case columns
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let columnsArray = [
            [columns.0.x, columns.0.y, columns.0.z, columns.0.w],
            [columns.1.x, columns.1.y, columns.1.z, columns.1.w],
            [columns.2.x, columns.2.y, columns.2.z, columns.2.w],
            [columns.3.x, columns.3.y, columns.3.z, columns.3.w]
        ]
        
        try container.encode(columnsArray, forKey: .columns)
    }
}
