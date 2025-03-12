//
//  LogView.swift
//  UWBScanner
//
//  Created by Maitree Hirunteeyakul on 1/3/2025.
//
import SwiftUI

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS, d MMM y"
    return formatter
}()

struct FlushedLogView: View {
    @ObservedObject var logger: Logger = Logger.get()
    var body: some View {
        let flushedLogs = logger.flushedLogs
        VStack{
            if flushedLogs.isEmpty {
                Text("No Flushing Occurred")
            }
            else {
                List{
                    VStack{
                        HStack{
                            Text("Session Identifier").font(.caption)
                            Spacer()
                        }
                        HStack{
                            Text("\(logger.sessionIdentifier)").font(.caption)
                            Spacer()
                        }
                    }
                    ForEach(flushedLogs) { flushedLog in
                    Section(header: Text(dateFormatter.string(from: flushedLog.timestamp))) {
                        if flushedLog.logs.isEmpty {
                            Text("Empty Flushing")
                        }
                        ForEach(flushedLog.logs) { log in
                            VStack(alignment: .leading) {
                                HStack{
                                    Text(dateFormatter.string(from: log.timestamp))
                                        .font(.caption)
                                }
                                HStack{
                                    Text("\(log.label)")
                                        .font(.headline)
                                }
                                if let content = log.content {
                                    HStack{
                                        Spacer()
                                        Text("\(content)")
                                            .font(.footnote)
                                    }
                                }
                            }
                        }
                    }
                }}
            }
        }.navigationTitle("Flushed Log")
    }
}

struct LogView: View {
    @ObservedObject var logger: Logger = Logger.get()
    @State private var isSaving = false
    @State private var navigateToFlushedLogView = false
    
    var body: some View {
        let logs = logger.logs
        VStack{
            if logs.isEmpty {
                Text("Empty log")
            }
            else {
                List(logs) { log in
                    VStack(alignment: .leading) {
                        HStack{
                            Text(dateFormatter.string(from: log.timestamp))
                                .font(.caption)
                        }
                        HStack{
                            Text("\(log.label)")
                                .font(.headline)
                        }
                        if let content = log.content {
                            HStack{
                                Spacer()
                                Text("\(content)")
                                    .font(.footnote)
                            }
                        }
                    }
                }
            }}.navigationTitle("Log")
            .toolbar {
                Button(action: {
                    guard !isSaving else { return }
                    isSaving = true
                    Task {
                        await logger.save()
                        isSaving = false
                    }
                }) {
                    Text("Flush")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .disabled(isSaving)
                .simultaneousGesture(LongPressGesture().onEnded { _ in
                    navigateToFlushedLogView = true
                })
            }
            .navigationDestination(isPresented: $navigateToFlushedLogView) {
                FlushedLogView(logger: logger)
            }
    }
}

extension Logger {
    static func sampleLogger() -> Logger {
        let logger = Logger()
        
        if logger.logs.isEmpty {
            logger.addLog(label: "First Log", content: "This is a test log")
            logger.addLog(label: "Second Log", content: nil)
            logger.addLog(label: "Third Log", content: [1,2,3])
        }
        
        return logger
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        let logger = Logger.sampleLogger()
        
        return NavigationView {
            LogView(logger: logger)
                .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
