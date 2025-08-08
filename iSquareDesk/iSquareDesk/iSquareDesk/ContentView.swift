//
//  ContentView.swift
//  iSquareDesk
//
//  Created by Mike Pogue on 8/7/25.
//

import SwiftUI
import Foundation
import AVFoundation

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
    @AppStorage("musicFolderPath") private var musicFolder: String = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        return documentsPath + "/SquareDanceMusic"
    }()
    @State private var songs: [Song] = []
    @State private var sortColumn: SortColumn = .type
    @State private var sortOrder: SortOrder = .ascending
    @State private var currentSongTitle: String = ""
    @State private var currentHour: Double = 0
    @State private var currentMinute: Double = 0 
    @State private var currentSecond: Double = 0
    @State private var clockTime: String = "12:00"
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentSongPath: String = ""
    @State private var audioTimer: Timer?
    @State private var isUserSeeking: Bool = false
    
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
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                // Top header with white space
                HStack {
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)
            
            // Top half: Controls
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: geometry.size.width > 1000 ? 20 : 10) {
            // Left side: About Time section
            VStack(alignment: .leading, spacing: 3) {
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
                        Button(action: { stopAudio() }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                        }
                        
                        Button(action: { 
                            if isPlaying {
                                pauseAudio()
                            } else {
                                playAudio()
                            }
                        }) {
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
                    
                    GeometryReader { geometry in
                        Slider(value: $seekTime, in: 0...duration) { editing in
                            isUserSeeking = editing
                            if !editing {
                                // User finished interacting with slider - seek to position
                                seekToPosition()
                            }
                        }
                        .accentColor(.gray)
                        .onTapGesture { location in
                            // Calculate the position as a percentage of the slider width
                            let percentage = location.x / geometry.size.width
                            // Convert percentage to time value within the duration range
                            let newTime = max(0, min(duration, percentage * duration))
                            
                            // Update seek position and jump to that location
                            seekTime = newTime
                            seekToPosition()
                        }
                    }
                    .frame(height: 44)
                }
                .padding(.top, 10)
                
                Spacer()
            }
            .frame(width: min(550, geometry.size.width * 0.45))
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
                            .onChange(of: volume) { _, newValue in
                                updateVolume()
                            }
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
                                .frame(width: 112.5, height: 112.5)
                            
                            // Hour tick marks
                            ForEach(0..<12) { hour in
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 1, height: 8)
                                    .offset(y: -51.25)
                                    .rotationEffect(.degrees(Double(hour) * 30))
                            }
                            
                            // Hour hand
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: 2, height: 37.5)
                                .offset(y: -18.75)
                                .rotationEffect(.degrees(currentHour * 30))
                            
                            // Minute hand
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: 2, height: 43.75)
                                .offset(y: -21.875)
                                .rotationEffect(.degrees(currentMinute * 6))
                            
                            // Second hand (red)
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 1, height: 47.5)
                                .offset(y: -23.75)
                                .rotationEffect(.degrees(currentSecond * 6))
                            
                            // Time overlay on clock face
                            Text(clockTime)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                                .offset(y: 18.75)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.trailing, 10)
            }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .frame(height: geometry.size.height * 0.45)
            
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
            .frame(height: geometry.size.height * 0.45)
            }
            
            // Gear icon overlay in bottom right corner
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            loadSongs()
            uiUpdate() // Initial update
            
            // Start timer for UI updates
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                uiUpdate()
            }
        }
        .onChange(of: musicFolder) { _, _ in
            loadSongs()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshSongList"))) { _ in
            loadSongs()
        }
    }
    
    func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func uiUpdate() {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let second = calendar.component(.second, from: now)
        
        // Convert to 12-hour format for hand positioning
        let hour12 = hour % 12
        
        // Update clock hands (degrees from 12 o'clock position)
        currentHour = Double(hour12) + Double(minute) / 60.0 // Smooth hour hand movement
        currentMinute = Double(minute)
        currentSecond = Double(second)
        
        // Update clock time text
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        clockTime = formatter.string(from: now)
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
        // Stop any currently playing audio
        stopAudio()
        
        // Reset playback state for new song
        isPlaying = false
        currentTime = 0
        seekTime = 0
        
        // Load the audio file
        loadAudioFile(for: song)
        print("Loading song: \(song.title) (\(song.type))")
    }
    
    func loadAudioFile(for song: Song) {
        // Construct the file path based on song type and title
        let fileName = song.title + (song.type == "xtras" ? ".m4a" : ".mp3")
        let filePath = musicFolder + "/\(song.type)/\(fileName)"
        currentSongPath = filePath
        
        // Create URL from file path
        guard let url = URL(string: "file://" + filePath) else {
            print("Invalid file path: \(filePath)")
            return
        }
        
        do {
            // Create and configure audio player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            
            // Set initial volume from slider
            audioPlayer?.volume = Float(volume)
            
            // Update duration
            if let player = audioPlayer {
                duration = player.duration
            }
            
            print("Audio file loaded: \(fileName)")
        } catch {
            print("Error loading audio file: \(error)")
        }
    }
    
    func playAudio() {
        guard let player = audioPlayer else {
            print("No audio player available")
            return
        }
        
        // Set the volume from the slider
        player.volume = Float(volume)
        player.play()
        isPlaying = true
        
        // Start audio timer to update current time
        audioTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = audioPlayer {
                currentTime = player.currentTime
                
                // Only update seekTime if user is not actively seeking
                if !isUserSeeking {
                    seekTime = player.currentTime
                }
                
                // Check if song finished
                if !player.isPlaying && currentTime > 0 {
                    stopAudio()
                }
            }
        }
    }
    
    func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
        audioTimer?.invalidate()
        audioTimer = nil
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        seekTime = 0
        audioTimer?.invalidate()
        audioTimer = nil
    }
    
    func seekToPosition() {
        guard let player = audioPlayer else { return }
        
        // Set the audio player's current time to the seek position
        player.currentTime = seekTime
        currentTime = seekTime
        
        // If the song was playing, continue playing from new position
        // If it wasn't playing, just move the handle without starting playback
        if isPlaying {
            // Ensure playback continues from new position
            if !player.isPlaying {
                player.play()
            }
        }
    }
    
    func updateVolume() {
        // Update the audio player's volume in real-time
        audioPlayer?.volume = Float(volume)
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
