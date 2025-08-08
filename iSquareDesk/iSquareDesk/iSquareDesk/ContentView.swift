//
//  ContentView.swift
//  iSquareDesk
//
//  Created by Mike Pogue on 8/7/25.
//

import SwiftUI
import Foundation

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct Song: Identifiable {
    let id = UUID()
    let type: String
    let title: String
}

enum SortColumn {
    case type, title
}

enum SortOrder {
    case ascending, descending
}

struct ContentView: View {
    @State private var isPlaying = false
    @State private var currentTime: Double = 57
    @State private var seekTime: Double = 57 // Time position controlled by seekbar
    @State private var duration: Double = 334 // 5:34 in seconds
    @State private var showingSettings = false
    @State private var pitch: Double = 0
    @State private var tempo: Double = 125
    @State private var volume: Double = 1.0
    @State private var bass: Double = 0
    @State private var mid: Double = 0
    @State private var treble: Double = 0
    @AppStorage("musicFolderPath") private var musicFolder: String = "/Users/mpogue/ipad_squaredesk/SquareDanceMusic"
    @State private var songs: [Song] = []
    @State private var sortColumn: SortColumn = .type
    @State private var sortOrder: SortOrder = .ascending
    @State private var currentSongTitle: String = "About Time"
    
    var sortedSongs: [Song] {
        songs.sorted { song1, song2 in
            let result: Bool
            switch sortColumn {
            case .type:
                result = song1.type.localizedCaseInsensitiveCompare(song2.type) == .orderedAscending
            case .title:
                result = song1.title.localizedCaseInsensitiveCompare(song2.title) == .orderedAscending
            }
            return sortOrder == .ascending ? result : !result
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top half: Controls
            HStack(spacing: 20) {
            // Left side: About Time section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(currentSongTitle)
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
                    Text("\(formatFullTime(seekTime)) / \(formatFullTime(duration))")
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
                    
                    Slider(value: $seekTime, in: 0...duration)
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
                        VerticalSlider(value: $pitch, in: -5...5, label: "Pitch", defaultValue: 0)
                        VerticalSlider(value: $tempo, in: 110...140, label: "Tempo", defaultValue: 125)
                        VerticalSlider(value: $volume, in: 0...1, label: "Volume", showMax: true, defaultValue: 1.0)
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
                            
                            // Hour tick marks
                            ForEach(0..<12) { hour in
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 1, height: 8)
                                    .offset(y: -41)
                                    .rotationEffect(.degrees(Double(hour) * 30))
                            }
                            
                            // Hour hand
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: 2, height: 30)
                                .offset(y: -15)
                                .rotationEffect(.degrees(-60))
                            
                            // Minute hand
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: 2, height: 35)
                                .offset(y: -17.5)
                                .rotationEffect(.degrees(60))
                            
                            // Second hand (red)
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 1, height: 38)
                                .offset(y: -19)
                                .rotationEffect(.degrees(180))
                            
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
            .frame(height: UIScreen.main.bounds.height / 2)
            
            // Bottom half: Song Table
            VStack(alignment: .leading, spacing: 0) {
                Text("Song List")
                    .font(.system(size: 20, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                
                // Table Header
                HStack {
                    Button(action: { toggleSort(.type) }) {
                        HStack {
                            Text("Type")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            if sortColumn == .type {
                                Image(systemName: sortOrder == .ascending ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .frame(width: 120, alignment: .leading)
                    
                    Spacer()
                    
                    Button(action: { toggleSort(.title) }) {
                        HStack {
                            Text("Title")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            if sortColumn == .title {
                                Image(systemName: sortOrder == .ascending ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                
                // Song List
                List(sortedSongs) { song in
                    HStack {
                        Text(song.type)
                            .font(.system(size: 17.5))
                            .foregroundColor(getTypeColor(for: song.type))
                            .frame(width: 120, alignment: .leading)
                        
                        Text(song.title)
                            .font(.system(size: 17.5))
                            .foregroundColor(getTypeColor(for: song.type))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 2)
                    .onTapGesture {
                        loadSong(song)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .frame(height: UIScreen.main.bounds.height / 2)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            loadSongs()
        }
        .onChange(of: musicFolder) { _, _ in
            loadSongs()
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
    
    func toggleSort(_ column: SortColumn) {
        if sortColumn == column {
            sortOrder = sortOrder == .ascending ? .descending : .ascending
        } else {
            sortColumn = column
            sortOrder = .ascending
        }
    }
    
    func loadSongs() {
        songs.removeAll()
        
        let fileManager = FileManager.default
        let musicURL = URL(fileURLWithPath: musicFolder)
        
        do {
            scanDirectoryRecursively(url: musicURL, fileManager: fileManager)
        } catch {
            print("Error reading music folder: \(error)")
            // Add some sample songs for testing
            songs = [
                Song(type: "sample", title: "Sample Song 1"),
                Song(type: "sample", title: "Sample Song 2"),
                Song(type: "test", title: "Test Track")
            ]
        }
    }
    
    func loadSong(_ song: Song) {
        currentSongTitle = song.title
        // Reset playback state for new song
        isPlaying = false
        currentTime = 0
        seekTime = 0
        // Here you can add additional logic for loading the actual audio file
        print("Loading song: \(song.title) (\(song.type))")
    }
    
    func getTypeColor(for type: String) -> Color {
        switch type {
        case "patter":
            return Color(hex: "#7963FF")
        case "singing":
            return Color(hex: "#00AF5C")
        case "xtras":
            return Color(hex: "#9C1F00")
        default:
            return .primary
        }
    }
    
    func scanDirectoryRecursively(url: URL, fileManager: FileManager) {
        do {
            let files = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            
            for file in files {
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: file.path, isDirectory: &isDirectory)
                
                if isDirectory.boolValue {
                    // Skip soundfx folder
                    if file.lastPathComponent.lowercased() == "soundfx" {
                        continue
                    }
                    // Recursively scan subdirectories
                    scanDirectoryRecursively(url: file, fileManager: fileManager)
                } else {
                    // Check if file is in soundfx folder (anywhere in the path)
                    let relativePath = String(file.path.dropFirst(musicFolder.count + 1))
                    if relativePath.lowercased().contains("soundfx/") {
                        continue
                    }
                    
                    let fileExtension = file.pathExtension.lowercased()
                    if fileExtension == "mp3" || fileExtension == "m4a" {
                        // Parse Type and Title from relative path
                        let pathComponents = relativePath.components(separatedBy: "/")
                        let type = pathComponents.first ?? "unknown"
                        let filename = pathComponents.last ?? relativePath
                        
                        // Remove file extension from title
                        let title = filename.replacingOccurrences(of: ".\(fileExtension)", with: "")
                        
                        let song = Song(type: type, title: title)
                        songs.append(song)
                    }
                }
            }
        } catch {
            print("Error scanning directory \(url): \(error)")
        }
    }
}

#Preview {
    ContentView()
}