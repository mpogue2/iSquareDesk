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
    
    @State private var currentTime: Double = 0
    @State private var seekTime: Double = 0 // Time position controlled by seekbar
    @State private var duration: Double = 0
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
    @AppStorage("musicFolderURL") private var musicFolderURL: String = ""
    @AppStorage("forceMono") private var forceMono: Bool = false
    @State private var songs: [Song] = []
    @State private var sortColumn: SortColumn = .type
    @State private var sortOrder: SortOrder = .ascending
    @State private var currentSongTitle: String = ""
    @State private var currentHour: Double = 0
    @State private var currentMinute: Double = 0 
    @State private var currentSecond: Double = 0
    @State private var clockTime: String = "12:00"
    @StateObject private var audioProcessor = AudioProcessor()
    @State private var currentSongPath: String = ""
    @State private var isUserSeeking: Bool = false
    @State private var securityScopedURL: URL?
    
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
                    .fill(Color.init(hex: "#9C0000"))
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
                        Button(action: { 
                            audioProcessor.stop()
                            currentTime = 0
                            seekTime = 0
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.black, lineWidth: 1)
                                )
                        }
                        
                        Button(action: { 
                            if audioProcessor.isPlaying {
                                audioProcessor.pause()
                            } else {
                                // Sync the audio processor's current time with the seek time before playing
                                audioProcessor.currentTime = seekTime
                                audioProcessor.play()
                            }
                        }) {
                            Image(systemName: audioProcessor.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.black, lineWidth: 1)
                                )
                        }
                    }
                    
                    GeometryReader { geometry in
                        Slider(value: $seekTime, in: 0...max(1.0, audioProcessor.duration)) { editing in
                            isUserSeeking = editing
                            if !editing {
                                // User finished interacting with slider - seek to position
                                print("Seeking to: \(seekTime)")
                                audioProcessor.seek(to: seekTime)
                            }
                        }
                        .accentColor(.gray)
                        .onTapGesture { location in
                            // Calculate the position as a percentage of the slider width
                            let percentage = location.x / geometry.size.width
                            // Convert percentage to time value within the duration range
                            let newTime = max(0, min(audioProcessor.duration, percentage * audioProcessor.duration))
                            
                            // Set user seeking flag to prevent currentTime updates from interfering
                            isUserSeeking = true
                            
                            // Update seek position and jump to that location
                            print("Tap seeking to: \(newTime)")
                            seekTime = newTime
                            audioProcessor.seek(to: newTime)
                            
                            // Reset the flag after a brief delay to allow the seek to complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isUserSeeking = false
                            }
                        }
                    }
                    .frame(height: 44)
                }
                .padding(.top, 10)
                
                Spacer()
            }
            .frame(width: min(550, geometry.size.width * 0.49))
            .padding(.leading, 10)
            
            // Right side: All controls
            VStack(spacing: 20) {
                // Top row: Vertical sliders, circular knobs, and clock
                HStack(spacing: 22) {
                    // Vertical sliders
                    HStack(spacing: 2) {
                        VerticalSlider(value: $pitch, in: -5...5, label: "Pitch", defaultValue: 0, allowTapIncrement: true, incrementAmount: 1.0, snapToIntegers: true)
                            .onChange(of: pitch) { _, newValue in
                                // Slider snaps to integers, so every change is a real change
                                audioProcessor.pitchSemitones = Float(newValue)
                            }
                        VerticalSlider(value: $tempo, in: 110...140, label: "Tempo", defaultValue: 125, allowTapIncrement: true, incrementAmount: 1.0, snapToIntegers: true)
                            .onChange(of: tempo) { _, newValue in
                                // Slider snaps to integers, so every change is a real change
                                audioProcessor.tempoBPM = Float(newValue)
                            }
                        VerticalSlider(value: $volume, in: 0...1, label: "Volume", showMax: true, defaultValue: 1.0, allowTapIncrement: true, incrementAmount: 0.1)
                            .onChange(of: volume) { _, newValue in
                                audioProcessor.volume = Float(newValue)
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
            establishSecurityScopedAccess()
            loadSongs()
            uiUpdate() // Initial update
            
            // Set initial audio processor states
            audioProcessor.forceMono = forceMono
            audioProcessor.pitchSemitones = Float(pitch)
            audioProcessor.tempoBPM = Float(tempo)
            
            // Start timer for UI updates
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                uiUpdate()
            }
        }
        .onChange(of: musicFolder) { _, _ in
            establishSecurityScopedAccess()
            loadSongs()
        }
        .onChange(of: musicFolderURL) { _, _ in
            establishSecurityScopedAccess()
            loadSongs()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshSongList"))) { _ in
            establishSecurityScopedAccess()
            loadSongs()
        }
        .onReceive(audioProcessor.$currentTime) { time in
            if !isUserSeeking {
                currentTime = time
                seekTime = time
            }
        }
        
        .onChange(of: forceMono) { _, newValue in
            audioProcessor.forceMono = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceMonoChanged"))) { _ in
            audioProcessor.forceMono = forceMono
        }
        .onDisappear {
            stopSecurityScopedAccess()
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
        
        scanDirectoryRecursively(url: musicURL, fileManager: fileManager)
    }
    
    func loadSong(_ song: Song) {
        currentSongTitle = song.title
        // Stop any currently playing audio
        audioProcessor.stop()
        
        // Reset playback state for new song
        currentTime = 0
        seekTime = 0
        
        // Reset tempo to 125 BPM (assuming all songs are 125 BPM)
        tempo = 125.0
        audioProcessor.tempoBPM = Float(125.0)
        
        // Load the audio file
        loadAudioFile(for: song)
        print("Loading song: \(song.title) (\(song.type))")
    }
    
    func loadAudioFile(for song: Song) {
        // Try both .mp3 and .m4a extensions
        let extensions = ["mp3", "m4a"]
        var loaded = false
        
        for ext in extensions {
            let fileName = song.title + "." + ext
            
            // Try to use security-scoped URL first (for iCloud folders)
            if let url = getSecurityScopedURL() {
                let audioURL = url.appendingPathComponent(song.type).appendingPathComponent(fileName)
                if FileManager.default.fileExists(atPath: audioURL.path) {
                    if audioProcessor.loadAudioFile(from: audioURL) {
                        currentSongPath = audioURL.path
                        duration = audioProcessor.duration
                        print("Audio file loaded: \(fileName)")
                        loaded = true
                        break
                    }
                }
            } else {
                // Fall back to local file path
                let filePath = musicFolder + "/\(song.type)/\(fileName)"
                
                if FileManager.default.fileExists(atPath: filePath) {
                    guard let url = URL(string: "file://" + filePath) else {
                        continue
                    }
                    
                    if audioProcessor.loadAudioFile(from: url) {
                        currentSongPath = filePath
                        duration = audioProcessor.duration
                        print("Audio file loaded: \(fileName)")
                        loaded = true
                        break
                    }
                }
            }
        }
        
        if !loaded {
            print("Failed to load audio file: \(song.title) in folder: \(song.type)")
        }
    }
    
    func establishSecurityScopedAccess() {
        // Stop any existing security-scoped access first
        stopSecurityScopedAccess()
        
        guard !musicFolderURL.isEmpty,
              let bookmarkData = Data(base64Encoded: musicFolderURL) else {
            return
        }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if url.startAccessingSecurityScopedResource() {
                securityScopedURL = url
                print("Successfully established security-scoped access to: \(url.path)")
            } else {
                print("Failed to start accessing security-scoped resource")
            }
        } catch {
            print("Error resolving bookmark: \(error)")
        }
    }
    
    func getSecurityScopedURL() -> URL? {
        return securityScopedURL
    }
    
    func stopSecurityScopedAccess() {
        if let url = securityScopedURL {
            url.stopAccessingSecurityScopedResource()
            securityScopedURL = nil
            print("Stopped accessing security-scoped resource")
        }
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
