//
//  ContentView.swift
//  iSquareDesk
//
//  Created by Mike Pogue on 8/7/25.
//

import SwiftUI
import Foundation
import AVFoundation

struct CustomSliderStyle: ViewModifier {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // Filled portion
                Rectangle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)), height: 4)
                    .position(x: geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) / 2, y: geometry.size.height / 2)
                
                // Custom handle - green line with triangles
                let handlePosition = geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                
                VStack(spacing: 0) {
                    // Top triangle (pointing down)
                    ZStack {
                        Path { path in
                            path.move(to: CGPoint(x: 6, y: 6))
                            path.addLine(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: 12, y: 0))
                            path.closeSubpath()
                        }
                        .fill(Color.green)
                        
                        Path { path in
                            path.move(to: CGPoint(x: 6, y: 6))
                            path.addLine(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: 12, y: 0))
                            path.closeSubpath()
                        }
                        .stroke(Color.black, lineWidth: 0.5)
                    }
                    .frame(width: 12, height: 6)
                    
                    // Vertical green line
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 2, height: 24)
                    
                    // Bottom triangle (pointing up)
                    ZStack {
                        Path { path in
                            path.move(to: CGPoint(x: 6, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: 6))
                            path.addLine(to: CGPoint(x: 12, y: 6))
                            path.closeSubpath()
                        }
                        .fill(Color.green)
                        
                        Path { path in
                            path.move(to: CGPoint(x: 6, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: 6))
                            path.addLine(to: CGPoint(x: 12, y: 6))
                            path.closeSubpath()
                        }
                        .stroke(Color.black, lineWidth: 0.5)
                    }
                    .frame(width: 12, height: 6)
                }
                .position(x: handlePosition, y: geometry.size.height / 2)
                
                // Invisible slider for interaction
                Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
                    .opacity(0.001) // Nearly invisible but still interactive
            }
        }
    }
}

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

struct SingingCallSection {
    let name: String
    let start: Float    // 0.0 to 1.0
    let end: Float      // 0.0 to 1.0
    let color: Color
}

struct Song: Identifiable {
    let id = UUID()
    let type: String
    let label: String
    let title: String
    let pitch: Int
    let tempo: Int
    let originalFilePath: String // Full path to the audio file
    let loop: Bool
    let introPos: Float
    let outroPos: Float
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
    // Stable sort chain: most-recent criterion first
    @State private var sortCriteria: [(SortColumn, SortOrder)] = [(.type, .ascending)]
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
    @State private var searchText: String = ""
    @State private var currentSongLoop: Bool = false
    @State private var currentIntroPos: Float = 0.0
    @State private var currentOutroPos: Float = 1.0
    @State private var isSingingCall: Bool = false
    
    var filteredSongs: [Song] {
        let filtered = searchText.isEmpty ? songs : songs.filter { song in
            song.type.localizedCaseInsensitiveContains(searchText) ||
            song.title.localizedCaseInsensitiveContains(searchText) ||
            song.label.localizedCaseInsensitiveContains(searchText)
        }

        // Build comparator using stable sort criteria (most recent first)
        let criteria = sortCriteria.isEmpty ? [(.type, .ascending)] : sortCriteria
        return filtered.sorted { (a: Song, b: Song) in
            for (col, ord) in criteria {
                let cmp: ComparisonResult
                switch col {
                case .type:
                    cmp = a.type.localizedCaseInsensitiveCompare(b.type)
                case .label:
                    cmp = a.label.localizedCaseInsensitiveCompare(b.label)
                case .title:
                    cmp = a.title.localizedCaseInsensitiveCompare(b.title)
                case .pitch:
                    cmp = (a.pitch == b.pitch) ? .orderedSame : (a.pitch < b.pitch ? .orderedAscending : .orderedDescending)
                case .tempo:
                    cmp = (a.tempo == b.tempo) ? .orderedSame : (a.tempo < b.tempo ? .orderedAscending : .orderedDescending)
                }
                if cmp != .orderedSame {
                    return ord == .ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
                }
            }
            // Final deterministic fallback by title
            let tcmp = a.title.localizedCaseInsensitiveCompare(b.title)
            return tcmp == .orderedAscending
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
                                
                                if isSingingCall {
                                    Text(getCurrentSingingCallSection())
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.red)
                                } else {
                                    Text(formatTime(currentTime))
                                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                                }
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
                                            .foregroundColor((isLoadingCurrentSong || currentSongPath.isEmpty) ? .gray : .black)
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.black, lineWidth: 1)
                                            )
                                    }
                                    .disabled(isLoadingCurrentSong || currentSongPath.isEmpty)
                                    
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
                                                .foregroundColor(isLoadingCurrentSong ? .clear : ((isLoadingCurrentSong || currentSongPath.isEmpty) ? .gray : .black))
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
                                    .disabled(isLoadingCurrentSong || currentSongPath.isEmpty)
                                }
                                
                                GeometryReader { geometry in
                                    ZStack {
                                        // Singing call colored sections (bottom layer)
                                        if isSingingCall && duration > 0 {
                                            let sections = calculateSingingCallSections(introPos: currentIntroPos, outroPos: currentOutroPos)
                                            ForEach(sections.indices, id: \.self) { index in
                                                let section = sections[index]
                                                Rectangle()
                                                    .fill(section.color)
                                                    .frame(
                                                        width: geometry.size.width * CGFloat(section.end - section.start),
                                                        height: geometry.size.height * 0.3
                                                    )
                                                    .position(
                                                        x: geometry.size.width * CGFloat(section.start + (section.end - section.start) / 2),
                                                        y: geometry.size.height * 0.5
                                                    )
                                            }
                                        }
                                        
                                        // Loop brackets overlay (behind slider handle, only for non-singing calls)
                                        if !isSingingCall && currentSongLoop && duration > 0 {
                                            // Left bracket at intro position
                                            Text("[")
                                                .font(.system(size: 36, weight: .bold))
                                                .foregroundColor(.blue)
                                                .position(
                                                    x: geometry.size.width * CGFloat(currentIntroPos),
                                                    y: geometry.size.height * 0.42
                                                )
                                            
                                            // Right bracket at outro position
                                            Text("]")
                                                .font(.system(size: 36, weight: .bold))
                                                .foregroundColor(.blue)
                                                .position(
                                                    x: geometry.size.width * CGFloat(currentOutroPos),
                                                    y: geometry.size.height * 0.42
                                                )
                                        }
                                        
                                        Color.clear
                                            .modifier(CustomSliderStyle(
                                                value: $seekTime,
                                                range: 0...max(1.0, audioProcessor.duration),
                                                onEditingChanged: { editing in
                                                    isUserSeeking = editing
                                                    if !editing {
                                                        // User finished interacting with slider - seek to position
                                                        print("Seeking to: \(seekTime)")
                                                        audioProcessor.seek(to: seekTime)
                                                    }
                                                }
                                            ))
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
                                            // Immediately reflect the new position in UI (for section label)
                                            currentTime = newTime
                                            
                                            // Reset the flag after a brief delay to allow the seek to complete
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                isUserSeeking = false
                                            }
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
                    HStack {
                        TextField("Search...", text: $searchText)
                            .font(.system(size: 20, weight: .medium))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 20))
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    
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
                        
                        // Pitch header (sorting disabled)
                        HStack {
                            Text("Pitch")
                                .font(.system(size: 16.94, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 60, alignment: .center)
                        
                        // Tempo header (sorting disabled)
                        HStack {
                            Text("Tempo")
                                .font(.system(size: 16.94, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 76, alignment: .center)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    
                    // Song List with iOS scroll indicators
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredSongs) { song in
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
                
                // Check for loop detection
                if currentSongLoop && audioProcessor.isPlaying && duration > 0 {
                    let normalizedTime = Float(time / duration)
                    
                    // If we've reached or passed the outro position, jump to intro position
                    if normalizedTime >= currentOutroPos {
                        let introTimeInSeconds = Double(currentIntroPos) * duration
                        audioProcessor.seek(to: introTimeInSeconds)
                        seekTime = introTimeInSeconds
                        currentTime = introTimeInSeconds
                    }
                }
            }
        }
        
        .onChange(of: forceMono) { _, newValue in
            audioProcessor.forceMono = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceMonoChanged"))) { _ in
            audioProcessor.forceMono = forceMono
        }
        // While scrubbing, keep the UI's currentTime in sync so singing-call label updates immediately
        .onChange(of: seekTime) { _, newValue in
            if isUserSeeking {
                currentTime = newValue
            }
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
        // Update sort order for the tapped column
        var newOrder: SortOrder
        if sortColumn == column {
            newOrder = (sortOrder == .ascending) ? .descending : .ascending
        } else {
            newOrder = .ascending
        }

        // Maintain stable chain: move this column to front with new order
        if let idx = sortCriteria.firstIndex(where: { $0.0 == column }) {
            sortCriteria.remove(at: idx)
        }
        sortCriteria.insert((column, newOrder), at: 0)

        // Keep only the relevant columns in the chain (Type, Label, Title)
        sortCriteria = sortCriteria.filter { crit in
            switch crit.0 { case .type, .label, .title: return true; default: return false }
        }

        sortColumn = column
        sortOrder = newOrder
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
        
        // Reset loop state
        currentSongLoop = false
        currentIntroPos = 0.0
        currentOutroPos = 1.0
        isSingingCall = false
        
        // Update UI state immediately
        currentTime = 0
        seekTime = 0
        tempo = Double(song.tempo)
        audioProcessor.tempoBPM = Float(song.tempo)
        pitch = Double(song.pitch)
        audioProcessor.pitchSemitones = Float(song.pitch)
        
        // Check if this is a singing call
        isSingingCall = (song.type == "singing" || song.type == "vocals")
        
        // Update loop settings
        if isSingingCall {
            // For singing calls, disable looping regardless of database setting
            currentSongLoop = false
        } else {
            currentSongLoop = song.loop
        }
        currentIntroPos = song.introPos
        currentOutroPos = song.outroPos
        
        // Move heavy file loading to background thread
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let audioURL = URL(fileURLWithPath: song.originalFilePath)
            
            // Check if this song is still the one we want to load (user might have clicked another)
            guard self.currentSongTitle == song.title else {
                print("🎵 ⏭️ Song selection changed, canceling load of: \(song.title)")
                return
            }
            
            if FileManager.default.fileExists(atPath: audioURL.path) {
                // Check file attributes (size, download status)
                do {
                    let _ = try FileManager.default.attributesOfItem(atPath: audioURL.path)
                } catch {
                    print("🎵 ⚠️ Could not get file attributes: \(error)")
                }
                
                if audioProcessor.loadAudioFile(from: audioURL) {
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
            return Color(hex: "#9C1F00")  // default uses Extras color
        }
    }
    
    func calculateSingingCallSections(introPos: Float, outroPos: Float) -> [SingingCallSection] {
        let D = outroPos - introPos
        
        // Handle edge case where intro and outro are the same
        guard D > 0 else {
            return [SingingCallSection(name: "FULL SONG", start: 0.0, end: 1.0, color: Color(red: 154/255, green: 185/255, blue: 199/255))]
        }
        
        // Define colors
        let introTagColor = Color(red: 154/255, green: 185/255, blue: 199/255)  // INTRO/TAG
        let openerBreakCloserColor = Color(red: 201/255, green: 125/255, blue: 122/255)  // OPENER/BREAK/CLOSER
        let figure1And3Color = Color(red: 118/255, green: 186/255, blue: 178/255)  // FIGURE 1/3
        let figure2And4Color = Color(red: 143/255, green: 154/255, blue: 206/255)  // FIGURE 2/4
        
        return [
            SingingCallSection(name: "INTRO", start: 0.0, end: introPos, color: introTagColor),
            SingingCallSection(name: "OPENER", start: introPos, end: introPos + D/7, color: openerBreakCloserColor),
            SingingCallSection(name: "FIGURE 1", start: introPos + D/7, end: introPos + 2*D/7, color: figure1And3Color),
            SingingCallSection(name: "FIGURE 2", start: introPos + 2*D/7, end: introPos + 3*D/7, color: figure2And4Color),
            SingingCallSection(name: "BREAK", start: introPos + 3*D/7, end: introPos + 4*D/7, color: openerBreakCloserColor),
            SingingCallSection(name: "FIGURE 3", start: introPos + 4*D/7, end: introPos + 5*D/7, color: figure1And3Color),
            SingingCallSection(name: "FIGURE 4", start: introPos + 5*D/7, end: introPos + 6*D/7, color: figure2And4Color),
            SingingCallSection(name: "CLOSER", start: introPos + 6*D/7, end: introPos + 7*D/7, color: openerBreakCloserColor),
            SingingCallSection(name: "TAG", start: introPos + 7*D/7, end: 1.0, color: introTagColor)
        ]
    }
    
    func getCurrentSingingCallSection() -> String {
        guard isSingingCall && duration > 0 else { return "" }
        
        let normalizedTime = Float((currentTime + 1.0) / duration)
        let sections = calculateSingingCallSections(introPos: currentIntroPos, outroPos: currentOutroPos)
        
        for section in sections {
            if normalizedTime >= section.start && normalizedTime < section.end {
                return section.name
            }
        }
        
        // Fallback to last section if we're at the very end
        return sections.last?.name ?? ""
    }
    
    func scanDirectoryRecursively(url: URL, fileManager: FileManager, songs: inout [Song], database: SongDatabaseManager?) {
        // Directories to exclude (case-insensitive) only at the TOP level of the music folder
        let excludedDirs: Set<String> = ["soundfx", "choreography", "sd", "playlists", "reference", "lyrics"]
        do {
            let files = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            
            for file in files {
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: file.path, isDirectory: &isDirectory)
                
                if isDirectory.boolValue {
                    // Skip excluded folders only when scanning the top-level of the music folder
                    if url.path == musicFolder {
                        if excludedDirs.contains(file.lastPathComponent.lowercased()) {
                            continue
                        }
                    }
                    // Recursively scan subdirectories
                    scanDirectoryRecursively(url: file, fileManager: fileManager, songs: &songs, database: database)
                } else {
                    // Skip files that are inside a TOP-LEVEL excluded folder
                    let relativePath = String(file.path.dropFirst(musicFolder.count + 1))
                    let firstComponentLower = relativePath.split(separator: "/").first.map { String($0).lowercased() }
                    if let first = firstComponentLower, excludedDirs.contains(first) {
                        continue
                    }
                    
                    let fileExtension = file.pathExtension.lowercased()
                    if fileExtension == "mp3" || fileExtension == "m4a" {
                        let type = relativePath.components(separatedBy: "/").first ?? "unknown"
                        let filenameWithoutExtension = file.lastPathComponent.replacingOccurrences(of: ".\(fileExtension)", with: "")
                        
                        let parsed = parseFilename(filenameWithoutExtension)
                        
                        // Look up pitch, tempo, and loop data from database
                        var songPitch = 0
                        var songTempo = 125
                        var songLoop = false
                        var songIntroPos: Float = 0.05  // Default for songs not in database
                        var songOutroPos: Float = 0.95  // Default for songs not in database
                        
                        if let db = database {
                            // Get relative path for database lookup
                            let dbLookupPath = relativePath
                            if let dbValues = db.getPitchTempoAndLoop(for: dbLookupPath) {
                                songPitch = dbValues.pitch
                                songTempo = dbValues.tempo
                                songLoop = dbValues.loop
                                songIntroPos = dbValues.introPos
                                songOutroPos = dbValues.outroPos
                            }
                        }
                        
                        let song = Song(
                            type: type,
                            label: parsed.label,
                            title: parsed.title,
                            pitch: songPitch,
                            tempo: songTempo,
                            originalFilePath: file.path,
                            loop: songLoop,
                            introPos: songIntroPos,
                            outroPos: songOutroPos
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
