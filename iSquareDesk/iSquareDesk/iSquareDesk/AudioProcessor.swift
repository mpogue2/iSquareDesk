//
//  AudioProcessor.swift
//  iSquareDesk
//
//  Created by Assistant on 8/8/25.
//

import Foundation
import AVFoundation

class AudioProcessor: ObservableObject {
    // Audio engine components
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let monoConverterNode = AVAudioMixerNode()
    
    // Playback state
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    // Audio file and format
    private var audioFile: AVAudioFile?
    private var audioFormat: AVAudioFormat?
    
    // Timer for updating current time
    private var displayTimer: Timer?
    
    // Volume control
    var volume: Float = 1.0 {
        didSet {
            engine.mainMixerNode.outputVolume = volume
        }
    }
    
    // Force mono control
    var forceMono: Bool = false {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.rebuildAudioGraph()
            }
        }
    }
    
    init() {
        setupAudioSession()
        setupAudioEngine()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        // Attach nodes
        engine.attach(playerNode)
        engine.attach(monoConverterNode)
        
        // Connect the initial audio chain
        buildAudioGraph()
        
        // Prepare and start the engine
        engine.prepare()
        
        do {
            try engine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func buildAudioGraph() {
        // Disconnect existing connections
        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeOutput(monoConverterNode)
        
        if forceMono {
            // For mono: connect player -> converter -> main mixer
            // The converter will sum L+R channels to mono
            engine.connect(playerNode, to: monoConverterNode, format: nil)
            
            // Configure the converter to output mono by setting up a mono format
            if let audioFormat = audioFormat {
                let monoFormat = AVAudioFormat(standardFormatWithSampleRate: audioFormat.sampleRate, channels: 1)
                engine.connect(monoConverterNode, to: engine.mainMixerNode, format: monoFormat)
                
                // Configure the mixer to sum stereo to mono
                monoConverterNode.outputVolume = 0.5 // Reduce volume to prevent clipping when summing
            } else {
                engine.connect(monoConverterNode, to: engine.mainMixerNode, format: nil)
            }
            print("Audio graph: Mono mode")
        } else {
            // For stereo: bypass converter, connect player directly to main mixer
            engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
            print("Audio graph: Stereo mode")
        }
    }
    
    private func rebuildAudioGraph() {
        let wasPlaying = isPlaying
        let currentPosition = currentTime
        
        // Stop playback
        if wasPlaying {
            playerNode.pause()
        }
        
        // Stop the engine to modify the graph
        engine.stop()
        
        // Rebuild the audio graph
        buildAudioGraph()
        
        // Restart the engine
        engine.prepare()
        do {
            try engine.start()
            
            // Resume playback if it was playing
            if wasPlaying, let audioFile = audioFile {
                seek(to: currentPosition)
                playerNode.play()
            }
        } catch {
            print("Failed to restart audio engine: \(error)")
        }
    }
    
    func loadAudioFile(from url: URL) -> Bool {
        do {
            // Stop any current playback
            stop()
            
            // Load the audio file
            audioFile = try AVAudioFile(forReading: url)
            guard let audioFile = audioFile else { return false }
            
            audioFormat = audioFile.processingFormat
            duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            
            return true
        } catch {
            print("Error loading audio file: \(error)")
            return false
        }
    }
    
    func play() {
        guard let audioFile = audioFile else { return }
        
        // Schedule the file for playback
        if !isPlaying {
            playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.handlePlaybackCompletion()
                }
            }
        }
        
        playerNode.play()
        isPlaying = true
        startDisplayTimer()
    }
    
    func pause() {
        playerNode.pause()
        isPlaying = false
        stopDisplayTimer()
    }
    
    func stop() {
        playerNode.stop()
        isPlaying = false
        currentTime = 0
        stopDisplayTimer()
    }
    
    func seek(to time: TimeInterval) {
        guard let audioFile = audioFile,
              let audioFormat = audioFormat else { return }
        
        // Calculate frame position
        let sampleRate = audioFormat.sampleRate
        let newSampleTime = AVAudioFramePosition(sampleRate * time)
        let length = audioFile.length - newSampleTime
        
        // Stop current playback
        playerNode.stop()
        
        // Only schedule if there are frames left to play
        if length > 0 {
            audioFile.framePosition = newSampleTime
            
            if isPlaying {
                // Reschedule from new position
                playerNode.scheduleSegment(audioFile,
                                          startingFrame: newSampleTime,
                                          frameCount: AVAudioFrameCount(length),
                                          at: nil) { [weak self] in
                    DispatchQueue.main.async {
                        self?.handlePlaybackCompletion()
                    }
                }
                playerNode.play()
            }
        }
        
        currentTime = time
    }
    
    private func startDisplayTimer() {
        stopDisplayTimer()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
        }
    }
    
    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }
    
    private func updateCurrentTime() {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
              let audioFormat = audioFormat else { return }
        
        let sampleRate = audioFormat.sampleRate
        currentTime = Double(playerTime.sampleTime) / sampleRate
        
        // Check if we've reached the end
        if currentTime >= duration {
            handlePlaybackCompletion()
        }
    }
    
    private func handlePlaybackCompletion() {
        stop()
    }
    
    
    deinit {
        stopDisplayTimer()
        engine.stop()
    }
}