//
//  ContentView.swift
//  iSquareDesk
//
//  Created by Mike Pogue on 8/7/25.
//

import SwiftUI

struct ContentView: View {
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 334 // 5:34 in seconds
    @State private var showingSettings = false
    @State private var pitch: Double = 0
    @State private var tempo: Double = 125
    @State private var volume: Double = 1.0
    @State private var bass: Double = 0
    @State private var mid: Double = 0
    @State private var treble: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Complete layout spanning full width
                VStack(alignment: .leading, spacing: 0) {
                    // Title and countdown timer above orange line
                    HStack {
                        Text("About Time")
                            .font(.system(size: 40, weight: .medium))
                        
                        Spacer()
                        
                        // Countdown timer right-justified above orange line
                        Text(formatTime(duration - currentTime))
                            .font(.system(size: 48, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 4)
                    
                    // Extended orange line spanning full width
                    Rectangle()
                        .fill(Color.orange)
                        .frame(height: 4)
                        .padding(.horizontal, 25)
                    
                    // Time display right-justified under orange line
                    HStack {
                        Spacer()
                        Text("\(formatFullTime(currentTime)) / \(formatFullTime(duration))")
                            .font(.system(size: 16, design: .monospaced))
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 8)
                    
                    // Controls row with play buttons, seekbar, and sliders
                    HStack(spacing: 20) {
                        // Play/Stop buttons
                        VStack(spacing: 6) {
                            Button(action: {}) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.blue, lineWidth: 2)
                                    )
                            }
                            
                            Button(action: { isPlaying.toggle() }) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.blue, lineWidth: 2)
                                    )
                            }
                        }
                        
                        // Extended seekbar
                        Slider(value: $currentTime, in: 0...duration)
                            .accentColor(.gray)
                        
                        // Right section: Sliders
                        HStack(spacing: 20) {
                            // Audio controls
                            VerticalSlider(value: $pitch, in: -12...12, label: "Pitch")
                            VerticalSlider(value: $tempo, in: 80...150, label: "Tempo")
                            VerticalSlider(value: $volume, in: 0...1, label: "Volume", showMax: true)
                            
                            // Separator
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 1, height: 140)
                            
                            // EQ controls
                            VerticalSlider(value: $bass, in: -12...12, label: "B")
                            VerticalSlider(value: $mid, in: -12...12, label: "M")
                            VerticalSlider(value: $treble, in: -12...12, label: "T")
                        }
                        
                        // Far right: Clock and settings
                        VStack(spacing: 8) {
                            // Clock
                            ZStack {
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                                    .frame(width: 80, height: 80)
                                
                                // Clock hands
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 2, height: 25)
                                    .offset(y: -12.5)
                                    .rotationEffect(.degrees(-60))
                                
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 2, height: 30)
                                    .offset(y: -15)
                                    .rotationEffect(.degrees(60))
                            }
                            
                            // Time display
                            Text("2:50 AM")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                            
                            // Settings gear
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 12)
                }
                
                Spacer()
            }
        }
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