//
//  HeadingBar.swift
//  UWBScanner
//
//  Created by Maitree Hirunteeyakul on 05/02/2025.
//
import SwiftUI
import ARKit

struct HeadingBar: View {
    
    let worldMapDefaultOrientation: simd_quatf?
    let trueHeading: Double?
    @Binding var isShowingARView: Bool
    
    var body: some View {
        VStack {
            if !isShowingARView {
                HStack{
                    Spacer()
                    Text("Tap to show AR").font(.caption2)
                    Spacer()
                }
            }
            VStack{
                HStack{
                    Text("Heading")
                    Spacer()
                    let headingText = trueHeading != nil ? String(format: "%.0f", trueHeading!) : "N/A"
                    Text("\(headingText)°")
                }
                HStack {
                    Text("World Map Default Orientation")
                    Spacer()
                }
                if let defaultOrientation = worldMapDefaultOrientation?.vector {
                    HStack{
                        Spacer()
                        Text("\(String(format: "%.2f", defaultOrientation.w))")
                        Spacer()
                        Text("\(String(format: "%.2f", defaultOrientation.x))")
                        Spacer()
                        Text("\(String(format: "%.2f", defaultOrientation.y))")
                        Spacer()
                        Text("\(String(format: "%.2f", defaultOrientation.z))")
                        Spacer()
                    }
                }else{
                    Text("N/A")
                }
            }.padding(.horizontal).background(.blue)
            if isShowingARView {
                HStack{
                    Spacer()
                    Text("Tap to show UWB data").font(.caption2)
                    Spacer()
                }
            }
        }.background(.purple)
            .foregroundColor(.white)
            .onTapGesture {
                isShowingARView = !isShowingARView
            }
    }
}

