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
    let label: String
    let title: String
    let pitch: Int
    let tempo: Int
    let originalFilePath: String // Full path to the audio file
}

enum SortColumn {
    case type, label, title, pitch, tempo
}

// Function to parse filename into Label and Title
func parseFilename(_ filename: String) -> (label: String, title: String) {
    // Find the last occurrence of " - "
    if let range = filename.range(of: " - ", options: .backwards) {
    let label = String(filename[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
    let title = String(filename[range.upperBound...]).trimmingCharacters(in: .whitespaces)
    return (label, title)
    } else {
    // If no " - " is found, treat the whole filename as the title and label as empty
    return ("", filename.trimmingCharacters(in: .whitespaces))
    }
}

struct ContentView: View {
    enum SortOrder {
    case ascending, descending
    }
    
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
    @State private var isLoadingSongs = false
    @State private var isLoadingCurrentSong = false
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
    @State private var songDatabase: SongDatabaseManager?
    @State private var currentSongPath: String = ""
    @State private var isUserSeeking: Bool = false
    @State private var securityScopedURL: URL?
    
    var sortedSongs: [Song] {
    songs.sorted { (song1: Song, song2: Song) in
        let result: Bool
        switch sortColumn {
        case .type:
            result = song1.type.localizedCaseInsensitiveCompare(song2.type) == .orderedAscending
        case .label:
            result = song1.label.localizedCaseInsensitiveCompare(song2.label) == .orderedAscending
        case .title:
            result = song1.title.localizedCaseInsensitiveCompare(song2.title) == .orderedAscending
        case .pitch:
            result = song1.pitch < song2.pitch
        case .tempo:
            result = song1.tempo < song2.tempo
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
                                            .foregroundColor(isLoadingCurrentSong ? .gray : .black)
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.black, lineWidth: 1)
                                            )
                                    }
                                    .disabled(isLoadingCurrentSong)
                                    
                                    Button(action: {
                                        if audioProcessor.isPlaying {
                                            audioProcessor.pause()
                                        } else {
                                            // Check if a song is actually loaded before trying to play
                                            guard !currentSongPath.isEmpty && duration > 0 else {
                                                print("🎵 ⚠️ No song loaded yet, cannot play")
                                                return
                                            }
                                            // Sync the audio processor's current time with the seek time before playing
                                            audioProcessor.currentTime = seekTime
                                            audioProcessor.play()
                                        }
                                    }) {
                                        ZStack {
                                            Image(systemName: audioProcessor.isPlaying ? "pause.fill" : "play.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(isLoadingCurrentSong ? .clear : .black)
                                                .frame(width: 40, height: 40)
                                            
                                            if isLoadingCurrentSong {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                                    .scaleEffect(0.8)
                                            }
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.black, lineWidth: 1)
                                        )
                                    }
                                    .disabled(isLoadingCurrentSong)
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
                                    VerticalSlider(value: $volume, in: 0...1, label: "Volume", showMax: true, defaultValue: 1.0, allowTapIncrement: true, incrementAmount: 0.1, vuLevel: Double(audioProcessor.audioLevel))
                                        .onChange(of: volume) { _, newValue in
                                            audioProcessor.volume = Float(newValue)
                                        }
                                }
                                
                                // Circular knobs (B/M/T)
                                VStack(spacing: 10) {
                                    CircularKnob(value: $treble, in: -12...12, label: "T")
                                        .onChange(of: treble) { _, newValue in
                                            audioProcessor.trebleBoost = Float(newValue)
                                        }
                                    CircularKnob(value: $mid, in: -12...12, label: "M")
                                        .onChange(of: mid) { _, newValue in
                                            audioProcessor.midBoost = Float(newValue)
                                        }
                                    CircularKnob(value: $bass, in: -12...12, label: "B")
                                        .onChange(of: bass) { _, newValue in
                                            audioProcessor.bassBoost = Float(newValue)
                                        }
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
                                            .frame(width: 3, height: 30.375)
                                            .offset(y: -15.1875)
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
                                    .onTapGesture {
                                        print("Reloading song list...")
                                        loadSongs()
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
                                    .font(.system(size: 16.94, weight: .semibold))
                                    .foregroundColor(.primary)
                                if sortColumn == .type {
                                    Image(systemName: sortOrder == .ascending ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 14.52))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .frame(width: 100, alignment: .leading)
                        
                        Button(action: { toggleSort(.label) }) {
                            HStack {
                                Text("Label")
                                    .font(.system(size: 16.94, weight: .semibold))
                                    .foregroundColor(.primary)
                                if sortColumn == .label {
                                    Image(systemName: sortOrder == .ascending ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 14.52))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .frame(width: 120, alignment: .leading)
                        
                        Button(action: { toggleSort(.title) }) {
                            HStack {
                                Text("Title")
                                    .font(.system(size: 16.94, weight: .semibold))
                                    .foregroundColor(.primary)
                                if sortColumn == .title {
                                    Image(systemName: sortOrder == .ascending ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 14.52))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(action: { toggleSort(.pitch) }) {
                            HStack {
                                Text("Pitch")
                                    .font(.system(size: 16.94, weight: .semibold))
                                    .foregroundColor(.primary)
                                if sortColumn == .pitch {
                                    Image(systemName: sortOrder == .ascending ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 14.52))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .frame(width: 60, alignment: .center)
                        
                        Button(action: { toggleSort(.tempo) }) {
                            HStack {
                                Text("Tempo")
                                    .font(.system(size: 16.94, weight: .semibold))
                                    .foregroundColor(.primary)
                                if sortColumn == .tempo {
                                    Image(systemName: sortOrder == .ascending ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 14.52))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .frame(width: 76, alignment: .center)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    
                    // Song List with iOS scroll indicators
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(sortedSongs) { song in
                                HStack {
                                    Text(song.type)
                                        .font(.system(size: 21.175))
                                        .foregroundColor(getTypeColor(for: song.type))
                                        .frame(width: 100, alignment: .leading)
                                    
                                    Text(song.label)
                                        .font(.system(size: 21.175))
                                        .foregroundColor(getTypeColor(for: song.type))
                                        .frame(width: 120, alignment: .leading)
                                    
                                    Text(song.title)
                                        .font(.system(size: 21.175))
                                        .foregroundColor(getTypeColor(for: song.type))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Text("\(song.pitch)")
                                        .font(.system(size: 21.175))
                                        .foregroundColor(getTypeColor(for: song.type))
                                        .frame(width: 60, alignment: .center)
                                    
                                    Text("\(song.tempo)")
                                        .font(.system(size: 21.175))
                                        .foregroundColor(getTypeColor(for: song.type))
                                        .frame(width: 66, alignment: .center)
                                }
                                .padding(.vertical, 2)
                                .padding(.horizontal, 10)
                                .onTapGesture {
                                    loadSong(song)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.visible)
                    .frame(maxHeight: .infinity)
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            establishSecurityScopedAccess { [self] in
                songDatabase = SongDatabaseManager(musicFolderPath: musicFolder)
                loadSongs()
            }
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
        .onChange(of: musicFolder) { _, newMusicFolder in
            establishSecurityScopedAccess {
                songDatabase = SongDatabaseManager(musicFolderPath: newMusicFolder)
                loadSongs()
            }
        }
        .onChange(of: musicFolderURL) { _, _ in
            establishSecurityScopedAccess {
                loadSongs()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshSongList"))) { _ in
            establishSecurityScopedAccess {
                songDatabase = SongDatabaseManager(musicFolderPath: musicFolder)
                loadSongs()
            }
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
        isLoadingSongs = true
        
        // Move heavy scanning work to background thread
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let fileManager = FileManager.default
            let musicURL = URL(fileURLWithPath: musicFolder)
            
            var tempSongs: [Song] = []
            
            
            scanDirectoryRecursively(url: musicURL, fileManager: fileManager, songs: &tempSongs, database: self.songDatabase)
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.songs = tempSongs
                self.isLoadingSongs = false
            }
        }
    }
    
    func loadSong(_ song: Song) {
        currentSongTitle = song.title
        
        // Set loading state - this will disable play/stop buttons
        isLoadingCurrentSong = true
        
        // Immediately stop playback and clear current audio file
        audioProcessor.stop()
        
        // Clear current song path to prevent playing wrong song
        currentSongPath = ""
        duration = 0
        
        // Update UI state immediately
        currentTime = 0
        seekTime = 0
        tempo = Double(song.tempo)
        audioProcessor.tempoBPM = Float(song.tempo)
        pitch = Double(song.pitch)
        audioProcessor.pitchSemitones = Float(song.pitch)
        
        // Move heavy file loading to background thread
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let startTime = CFAbsoluteTimeGetCurrent()
            let audioURL = URL(fileURLWithPath: song.originalFilePath)
            
            // Check if this song is still the one we want to load (user might have clicked another)
            guard self.currentSongTitle == song.title else {
                print("🎵 ⏭️ Song selection changed, canceling load of: \(song.title)")
                return
            }
            
            if FileManager.default.fileExists(atPath: audioURL.path) {
                let fileExistsTime = CFAbsoluteTimeGetCurrent()
                
                // Check file attributes (size, download status)
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
                } catch {
                    print("🎵 ⚠️ Could not get file attributes: \(error)")
                }
                
                let audioLoadStart = CFAbsoluteTimeGetCurrent()
                
                if audioProcessor.loadAudioFile(from: audioURL) {
                    let audioLoadEnd = CFAbsoluteTimeGetCurrent()
                    DispatchQueue.main.async {
                        // Double-check we're still loading the right song
                        guard self.currentSongTitle == song.title else {
                            print("🎵 ⏭️ Song selection changed during load, discarding: \(song.title)")
                            return
                        }
                        
                        self.currentSongPath = audioURL.path
                        self.duration = audioProcessor.duration
                        self.isLoadingCurrentSong = false // Enable play/stop buttons
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isLoadingCurrentSong = false // Re-enable buttons even on failure
                        print("🎵 ❌ Failed to load audio file: \(song.title)")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoadingCurrentSong = false // Re-enable buttons even on failure
                    print("🎵 ❌ Audio file does not exist: \(audioURL.path)")
                }
            }
        }
    }
    
    
    func establishSecurityScopedAccess(completion: @escaping () -> Void = {}) {
        // Stop any existing security-scoped access first
        stopSecurityScopedAccess()
        
        guard !musicFolderURL.isEmpty,
              let bookmarkData = Data(base64Encoded: musicFolderURL) else {
            DispatchQueue.main.async {
                completion()
            }
            return
        }
        
        // Use a much shorter timeout (3 seconds) and fall back quickly
        let timeoutItem = DispatchWorkItem {
            DispatchQueue.main.async {
                print("🔒 ⚠️ Bookmark resolution timed out - falling back to current path")
                print("🔒 Using existing musicFolder path: \(self.musicFolder)")
                completion()
            }
        }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3.0, execute: timeoutItem)
        
        // Try bookmark resolution with quick fallback
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
                
                // Cancel timeout since we succeeded
                timeoutItem.cancel()
                
                DispatchQueue.main.async {
                    if url.startAccessingSecurityScopedResource() {
                        self.securityScopedURL = url
// Security access established
                        self.musicFolder = url.path
                    } else {
                        print("🔒 ❌ Failed to start accessing security-scoped resource, using current path")
                    }
                    completion()
                }
            } catch {
                timeoutItem.cancel()
                DispatchQueue.main.async {
                    print("🔒 ❌ Error resolving bookmark: \(error.localizedDescription)")
                    print("🔒 Using current musicFolder path: \(self.musicFolder)")
                    completion()
                }
            }
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
        case "vocals":
            return Color(hex: "#AB6900")
        default:
            return .primary
        }
    }
    
    func scanDirectoryRecursively(url: URL, fileManager: FileManager, songs: inout [Song], database: SongDatabaseManager?) {
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
                    scanDirectoryRecursively(url: file, fileManager: fileManager, songs: &songs, database: database)
                } else {
                    // Check if file is in soundfx folder (anywhere in the path)
                    let relativePath = String(file.path.dropFirst(musicFolder.count + 1))
                    if relativePath.lowercased().contains("soundfx/") {
                        continue
                    }
                    
                    let fileExtension = file.pathExtension.lowercased()
                    if fileExtension == "mp3" || fileExtension == "m4a" {
                        let type = relativePath.components(separatedBy: "/").first ?? "unknown"
                        let filenameWithoutExtension = file.lastPathComponent.replacingOccurrences(of: ".\(fileExtension)", with: "")
                        
                        let parsed = parseFilename(filenameWithoutExtension)
                        
                        // Look up pitch and tempo from database
                        var songPitch = 0
                        var songTempo = 125
                        
                        if let db = database {
                            // Get relative path for database lookup
                            let dbLookupPath = relativePath
                            if let dbValues = db.getPitchAndTempo(for: dbLookupPath) {
                                songPitch = dbValues.pitch
                                songTempo = dbValues.tempo
                            }
                        }
                        
                        let song = Song(
                            type: type,
                            label: parsed.label,
                            title: parsed.title,
                            pitch: songPitch,
                            tempo: songTempo,
                            originalFilePath: file.path
                        )
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

