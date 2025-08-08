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
    @State private var duration: Double = 180 // 3 minutes placeholder
    
    var body: some View {
        VStack(spacing: 40) {
            // Title
            Text("iSquareDesk")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Album Art Placeholder
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 300, height: 300)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 100))
                        .foregroundColor(.gray)
                )
            
            // Song Info
            VStack(spacing: 8) {
                Text("Song Title")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Artist Name")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar
            VStack(spacing: 12) {
                Slider(value: $currentTime, in: 0...duration)
                    .accentColor(.blue)
                
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatTime(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 40)
            
            // Playback Controls
            HStack(spacing: 40) {
                Button(action: {}) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 30))
                }
                
                Button(action: { isPlaying.toggle() }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                }
                
                Button(action: {}) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 30))
                }
            }
            .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
    }
    
    func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}
