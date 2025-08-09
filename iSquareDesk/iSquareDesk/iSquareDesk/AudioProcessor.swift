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
    private let pitchNode = AVAudioUnitTimePitch()
    
    // Playback state
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    // Track when we've seeked to prevent incorrect time updates
    private var seekOffset: TimeInterval = 0
    private var hasJustSeeked = false
    
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
    
    // Pitch control (in semitones, range -5 to +5)
    var pitchSemitones: Float = 0.0 {
        didSet {
            pitchNode.pitch = pitchSemitones * 100.0 // AVAudioUnitTimePitch uses cents (100 cents = 1 semitone)
            print("Pitch changed to \(pitchSemitones) semitones (\(pitchNode.pitch) cents)")
        }
    }
    
    // Tempo control (in BPM, range 110-140, assuming original is 125 BPM)
    private let originalBPM: Float = 125.0
    var tempoBPM: Float = 125.0 {
        didSet {
            // Calculate rate multiplier (1.0 = original speed, 0.5 = half speed, 2.0 = double speed)
            let rateMultiplier = tempoBPM / originalBPM
            pitchNode.rate = rateMultiplier
            print("Tempo changed to \(tempoBPM) BPM (rate: \(rateMultiplier)x)")
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
        engine.attach(pitchNode)
        
        // Initialize pitch node settings
        pitchNode.pitch = 0.0 // No pitch change initially
        pitchNode.rate = 1.0  // Normal playback rate initially (125 BPM = 1.0x rate)
        
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
        engine.disconnectNodeOutput(pitchNode)
        
        if forceMono {
            // For mono: player -> pitch -> converter -> main mixer
            engine.connect(playerNode, to: pitchNode, format: nil)
            engine.connect(pitchNode, to: monoConverterNode, format: nil)
            
            // Configure the converter to output mono by setting up a mono format
            if let audioFormat = audioFormat {
                let monoFormat = AVAudioFormat(standardFormatWithSampleRate: audioFormat.sampleRate, channels: 1)
                engine.connect(monoConverterNode, to: engine.mainMixerNode, format: monoFormat)
                
                // Configure the mixer to sum stereo to mono
                monoConverterNode.outputVolume = 0.5 // Reduce volume to prevent clipping when summing
            } else {
                engine.connect(monoConverterNode, to: engine.mainMixerNode, format: nil)
            }
            print("Audio graph: Mono mode with pitch processing")
        } else {
            // For stereo: player -> pitch -> main mixer
            engine.connect(playerNode, to: pitchNode, format: nil)
            engine.connect(pitchNode, to: engine.mainMixerNode, format: nil)
            print("Audio graph: Stereo mode with pitch processing")
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
        guard let audioFile = audioFile,
              let audioFormat = audioFormat else { return }
        
        // Schedule the file for playback from current position
        if !isPlaying {
            // Track the seek position
            seekOffset = currentTime
            hasJustSeeked = true
            
            // Calculate current frame position
            let sampleRate = audioFormat.sampleRate
            let currentFramePosition = AVAudioFramePosition(sampleRate * currentTime)
            let remainingFrames = audioFile.length - currentFramePosition
            
            // Only schedule if there are frames left to play
            if remainingFrames > 0 {
                audioFile.framePosition = currentFramePosition
                
                playerNode.scheduleSegment(audioFile,
                                          startingFrame: currentFramePosition,
                                          frameCount: AVAudioFrameCount(remainingFrames),
                                          at: nil) { [weak self] in
                    DispatchQueue.main.async {
                        self?.handlePlaybackCompletion()
                    }
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
        seekOffset = 0
        hasJustSeeked = false
        stopDisplayTimer()
    }
    
    func seek(to time: TimeInterval) {
        guard let audioFile = audioFile,
              let audioFormat = audioFormat else { return }
        
        // Store playing state before stopping
        let wasPlaying = isPlaying
        
        // Track the seek
        seekOffset = time
        hasJustSeeked = true
        
        // Calculate frame position
        let sampleRate = audioFormat.sampleRate
        let newSampleTime = AVAudioFramePosition(sampleRate * time)
        let length = audioFile.length - newSampleTime
        
        // Stop current playback
        playerNode.stop()
        
        // Only schedule if there are frames left to play
        if length > 0 {
            audioFile.framePosition = newSampleTime
            
            if wasPlaying {
                // Reschedule from new position and continue playing
                playerNode.scheduleSegment(audioFile,
                                          startingFrame: newSampleTime,
                                          frameCount: AVAudioFrameCount(length),
                                          at: nil) { [weak self] in
                    DispatchQueue.main.async {
                        self?.handlePlaybackCompletion()
                    }
                }
                playerNode.play()
                // Ensure isPlaying stays true
                isPlaying = true
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
              let audioFormat = audioFormat else { 
            // If we can't get the player time but we just seeked, use the seek offset
            if hasJustSeeked {
                currentTime = seekOffset
            }
            return 
        }
        
        let sampleRate = audioFormat.sampleRate
        let nodeCurrentTime = Double(playerTime.sampleTime) / sampleRate
        
        // If we just seeked and the node reports 0 or a very small time, use our seek offset
        if hasJustSeeked && nodeCurrentTime < 0.5 {
            currentTime = seekOffset
            // After a few updates, trust the node time
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.hasJustSeeked = false
            }
        } else {
            // Add the seek offset to the node time to get the actual position
            currentTime = seekOffset + nodeCurrentTime
            hasJustSeeked = false
        }
        
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