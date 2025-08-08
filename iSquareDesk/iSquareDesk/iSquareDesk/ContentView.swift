//
//  ContentView.swift
//  iSquareDesk
//
//  Created by Mike Pogue on 8/7/25.
//

import SwiftUI

struct ContentView: View {
    @State private var isPlaying = false
    @State private var currentTime: Double = 57
    @State private var duration: Double = 334 // 5:34 in seconds
    @State private var showingSettings = false
    @State private var pitch: Double = 0
    @State private var tempo: Double = 125
    @State private var volume: Double = 1.0
    @State private var bass: Double = 0
    @State private var mid: Double = 0
    @State private var treble: Double = 0
    
    var body: some View {
        HStack(spacing: 20) {
            // Left side: About Time section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("About Time")
                        .font(.system(size: 28, weight: .medium))
                    
                    Spacer()
                    
                    Text(formatTime(currentTime))
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                }
                
                // Orange line
                Rectangle()
                    .fill(Color.orange)
                    .frame(height: 3)
                
                // Time progress
                HStack {
                    Spacer()
                    Text("\(formatFullTime(currentTime)) / \(formatFullTime(duration))")
                        .font(.system(size: 14, design: .monospaced))
                }
                .padding(.top, 4)
                
                // Play controls and seekbar
                HStack(spacing: 12) {
                    VStack(spacing: 8) {
                        Button(action: {}) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                        }
                        
                        Button(action: { isPlaying.toggle() }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                        }
                    }
                    
                    Slider(value: $currentTime, in: 0...duration)
                        .accentColor(.gray)
                }
                .padding(.top, 10)
                
                Spacer()
            }
            .frame(width: 550)
            .padding(.leading, 10)
            
            // Right side: All controls
            VStack(spacing: 20) {
                // Top row: Vertical sliders, circular knobs, and clock
                HStack(spacing: 20) {
                    // Vertical sliders
                    HStack(spacing: 18) {
                        VerticalSlider(value: $pitch, in: -12...12, label: "Pitch")
                        VerticalSlider(value: $tempo, in: 80...150, label: "Tempo")
                        VerticalSlider(value: $volume, in: 0...1, label: "Volume", showMax: true)
                    }
                    
                    // Circular knobs (B/M/T)
                    VStack(spacing: 10) {
                        CircularKnob(value: $treble, in: -12...12, label: "T")
                        CircularKnob(value: $mid, in: -12...12, label: "M")
                        CircularKnob(value: $bass, in: -12...12, label: "B")
                    }
                    
                    // Clock section
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                                .frame(width: 90, height: 90)
                            
                            // Clock hands
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: 2, height: 30)
                                .offset(y: -15)
                                .rotationEffect(.degrees(-60))
                            
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: 2, height: 35)
                                .offset(y: -17.5)
                                .rotationEffect(.degrees(60))
                            
                            // Time overlay on clock face
                            Text("2:50")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                                .offset(y: 15)
                        }
                        
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.trailing, 10)
        }
        .padding(.top, 20)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func formatFullTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}