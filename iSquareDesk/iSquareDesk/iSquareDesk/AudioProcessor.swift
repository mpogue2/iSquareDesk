//
//  AudioProcessor.swift
//  iSquareDesk
//
//  Created by Assistant on 8/8/25.
//

import Foundation
import AVFoundation
import Accelerate

class AudioProcessor: ObservableObject {
    // Audio engine components
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let monoConverterNode = AVAudioMixerNode()
    private let pitchNode = AVAudioUnitTimePitch()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 3)
    
    // Playback state
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var audioLevel: Float = 0.0 // VU meter level (0.0 to 1.0)
    
    // Track when we've seeked to prevent incorrect time updates
    private var seekOffset: TimeInterval = 0
    private var hasJustSeeked = false
    
    // Audio file and format
    private var audioFile: AVAudioFile?
    private var audioFormat: AVAudioFormat?
    
    // Timer for updating current time
    private var displayTimer: Timer?
    
    // Audio level monitoring
    private var levelTimer: Timer?
    private var peakLevel: Float = 0.0
    private let levelDecayRate: Float = 0.855 // Smooth decay for VU meter (10% faster decay)
    
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
    
    // EQ controls (in dB, range -12 to +12)
    var bassBoost: Float = 0.0 {
        didSet {
            updateEQBand(0, gain: bassBoost) // Bass band
        }
    }
    
    var midBoost: Float = 0.0 {
        didSet {
            updateEQBand(1, gain: midBoost) // Mid band
        }
    }
    
    var trebleBoost: Float = 0.0 {
        didSet {
            updateEQBand(2, gain: trebleBoost) // Treble band
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
        engine.attach(eqNode)
        
        // Initialize pitch node settings
        pitchNode.pitch = 0.0 // No pitch change initially
        pitchNode.rate = 1.0  // Normal playback rate initially (125 BPM = 1.0x rate)
        
        // Initialize EQ bands
        setupEQBands()
        
        // Connect the initial audio chain
        buildAudioGraph()
        
        // Setup audio level monitoring
        setupAudioLevelMonitoring()
        
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
        engine.disconnectNodeOutput(eqNode)
        
        if forceMono {
            // For mono: player -> pitch -> EQ -> converter -> main mixer
            engine.connect(playerNode, to: pitchNode, format: nil)
            engine.connect(pitchNode, to: eqNode, format: nil)
            engine.connect(eqNode, to: monoConverterNode, format: nil)
            
            // Configure the converter to output mono by setting up a mono format
            if let audioFormat = audioFormat {
                let monoFormat = AVAudioFormat(standardFormatWithSampleRate: audioFormat.sampleRate, channels: 1)
                engine.connect(monoConverterNode, to: engine.mainMixerNode, format: monoFormat)
                
                // Configure the mixer to sum stereo to mono
                monoConverterNode.outputVolume = 0.5 // Reduce volume to prevent clipping when summing
            } else {
                engine.connect(monoConverterNode, to: engine.mainMixerNode, format: nil)
            }
            print("Audio graph: Mono mode with pitch and EQ processing")
        } else {
            // For stereo: player -> pitch -> EQ -> main mixer
            engine.connect(playerNode, to: pitchNode, format: nil)
            engine.connect(pitchNode, to: eqNode, format: nil)
            engine.connect(eqNode, to: engine.mainMixerNode, format: nil)
            print("Audio graph: Stereo mode with pitch and EQ processing")
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
        startLevelTimer()
    }
    
    func pause() {
        playerNode.pause()
        isPlaying = false
        stopDisplayTimer()
        startDecayTimer()
    }
    
    func stop() {
        playerNode.stop()
        isPlaying = false
        currentTime = 0
        seekOffset = 0
        hasJustSeeked = false
        stopDisplayTimer()
        startDecayTimer()
    }
    
    func seek(to time: TimeInterval) {
        guard audioFile != nil else {
            print("Seek failed: no audio file")
            return
        }

        let wasPlaying = isPlaying
        playerNode.stop()
        isPlaying = false
        stopDisplayTimer()

        let newTime = max(0, min(time, duration))
        currentTime = newTime

        if wasPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.currentTime = newTime
                self?.play()
            }
        }
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
    
    private func setupEQBands() {
        // Setup Bass band: Peak filter at 125 Hz with Q=4.0
        let bassBand = eqNode.bands[0]
        bassBand.filterType = .parametric
        bassBand.frequency = 125.0
        bassBand.bandwidth = 0.25 // Q=4.0 corresponds to bandwidth ≈ 1/Q = 0.25 octaves
        bassBand.gain = 0.0
        bassBand.bypass = false
        
        // Setup Mid band: Peak filter at 1000 Hz with Q=0.9
        let midBand = eqNode.bands[1]
        midBand.filterType = .parametric
        midBand.frequency = 1000.0
        midBand.bandwidth = 1.11 // Q=0.9 corresponds to bandwidth ≈ 1/Q = 1.11 octaves
        midBand.gain = 0.0
        midBand.bypass = false
        
        // Setup Treble band: Peak filter at 8000 Hz with Q=0.9
        let trebleBand = eqNode.bands[2]
        trebleBand.filterType = .parametric
        trebleBand.frequency = 8000.0
        trebleBand.bandwidth = 1.11 // Q=0.9 corresponds to bandwidth ≈ 1/Q = 1.11 octaves
        trebleBand.gain = 0.0
        trebleBand.bypass = false
    }
    
    private func updateEQBand(_ bandIndex: Int, gain: Float) {
        guard bandIndex < eqNode.bands.count else { return }
        eqNode.bands[bandIndex].gain = gain
        print("EQ Band \(bandIndex) gain set to \(gain) dB")
    }
    
    private func setupAudioLevelMonitoring() {
        // Install tap on the main mixer node to monitor audio levels
        let bufferSize: AVAudioFrameCount = 1024
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // Calculate RMS level from the audio buffer
            let channelData = buffer.floatChannelData!
            let channelCount = Int(buffer.format.channelCount)
            let frameLength = Int(buffer.frameLength)
            
            var rms: Float = 0.0
            for channel in 0..<channelCount {
                var channelRMS: Float = 0.0
                vDSP_rmsqv(channelData[channel], 1, &channelRMS, vDSP_Length(frameLength))
                rms += channelRMS
            }
            rms = rms / Float(channelCount)
            
            // Update peak level with smoothing
            self.peakLevel = max(rms, self.peakLevel * self.levelDecayRate)
        }
    }
    
    private func startLevelTimer() {
        stopLevelTimer()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Convert to logarithmic scale for better visual representation
            let normalizedLevel = self.convertToLogarithmicScale(self.peakLevel)
            DispatchQueue.main.async {
                self.audioLevel = min(1.0, normalizedLevel)
            }
        }
    }
    
    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
        // Don't reset peakLevel - let it decay naturally
    }
    
    private func startDecayTimer() {
        stopLevelTimer()
        // Start a timer that only handles decay (no audio input processing)
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Apply decay to existing level
            self.peakLevel = self.peakLevel * self.levelDecayRate
            // Convert to logarithmic scale for better visual representation
            let normalizedLevel = self.convertToLogarithmicScale(self.peakLevel)
            DispatchQueue.main.async {
                self.audioLevel = min(1.0, normalizedLevel)
                // Stop decay timer when level gets very low
                if self.peakLevel < 0.001 {
                    self.stopLevelTimer()
                    self.audioLevel = 0.0
                }
            }
        }
    }
    
    private func convertToLogarithmicScale(_ linearLevel: Float) -> Float {
        // Convert linear audio level to logarithmic scale for better visual representation
        guard linearLevel > 0 else { return 0 }
        let minDb: Float = -40.0
        let db = 20.0 * log10(linearLevel)
        let normalizedDb = (db - minDb) / (-minDb)
        return max(0, min(1, normalizedDb))
    }
    
    deinit {
        stopDisplayTimer()
        stopLevelTimer()
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.stop()
    }
}
