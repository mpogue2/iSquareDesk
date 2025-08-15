/*****************************************************************************
**
** Copyright (C) 2025 Mike Pogue, Dan Lyke
** Contact: mpogue @ zenstarstudio.com
**
** This file is part of the iSquareDesk application.
**
** $ISQUAREDESK_BEGIN_LICENSE$
**
** Commercial License Usage
** For commercial licensing terms and conditions, contact the authors via the
** email address above.
**
** GNU General Public License Usage
** This file may be used under the terms of the GNU
** General Public License version 2.0 or (at your option) the GNU General
** Public license version 3 or any later version approved by the KDE Free
** Qt Foundation. The licenses are as published by the Free Software
** Foundation and appear in the file LICENSE.GPL2 and LICENSE.GPL3
** included in the packaging of this file.
**
** $ISQUAREDESK_END_LICENSE$
**
****************************************************************************/
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
    
    // Track paused state to distinguish resume-from-pause vs. fresh play
    private var wasPaused: Bool = false
    
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
// Pitch updated
        }
    }
    
    // Tempo control
    private let originalBPM: Float = 125.0
    var tempoIsPercent: Bool = false {
        didSet {
            updatePlaybackRate()
        }
    }
    var tempoBPM: Float = 125.0 {
        didSet {
            updatePlaybackRate()
// Tempo updated
        }
    }

    private func updatePlaybackRate() {
        // Calculate rate multiplier (1.0 = original speed)
        let rateMultiplier: Float
        if tempoIsPercent {
            rateMultiplier = max(0.01, tempoBPM / 100.0)
        } else {
            rateMultiplier = max(0.01, tempoBPM / originalBPM)
        }
        pitchNode.rate = rateMultiplier
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

    // MARK: - Looping helpers (Step 1: helpers only, no behavior change)
    // Public loop configuration (in seconds, absolute track time)
    @Published var loopEnabled: Bool = false
    @Published var loopStart: TimeInterval = 0.0
    @Published var loopEnd: TimeInterval = 0.0
    
    // Internal decoded buffer for one full LOOP pass [loopStart, loopEnd)
    private var loopBuffer: AVAudioPCMBuffer?
    
    // Cached file length in frames for precise scheduling
    private var fileLengthFrames: AVAudioFramePosition = 0
    
    // Guard window (seconds) for near-boundary scheduling decisions
    // Used by future logic to decide when to queue the next pass
    let loopDecisionWindow: TimeInterval = 0.04 // 40 ms
    
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
// Audio graph configured for mono
        } else {
            // For stereo: player -> pitch -> EQ -> main mixer
            engine.connect(playerNode, to: pitchNode, format: nil)
            engine.connect(pitchNode, to: eqNode, format: nil)
            engine.connect(eqNode, to: engine.mainMixerNode, format: nil)
// Audio graph configured for stereo
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
            if wasPlaying, audioFile != nil {
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
            let calculatedDuration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            fileLengthFrames = audioFile.length
            
            // Update @Published property on main thread
            DispatchQueue.main.async {
                self.duration = calculatedDuration
            }
            
            return true
        } catch {
            print("Error loading audio file: \(error)")
            return false
        }
    }
    
    func play() {
        guard let audioFile = audioFile,
              let audioFormat = audioFormat else { return }
        
        // If resuming from pause, do NOT reschedule; just resume playback
        if wasPaused {
            playerNode.play()
            wasPaused = false
            
            // Update @Published property on main thread
            DispatchQueue.main.async {
                self.isPlaying = true
            }
            startDisplayTimer()
            startLevelTimer()
            return
        }

        // Fresh play: schedule the file for playback from current position
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
        
        // Update @Published property on main thread
        DispatchQueue.main.async {
            self.isPlaying = true
        }
        
        startDisplayTimer()
        startLevelTimer()
    }
    
    func pause() {
        playerNode.pause()
        
        // Update @Published property on main thread
        DispatchQueue.main.async {
            self.isPlaying = false
        }
        
        stopDisplayTimer()
        startDecayTimer()
        wasPaused = true
    }
    
    func stop() {
        playerNode.stop()
        
        // Update @Published properties on main thread
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
        }
        
        seekOffset = 0
        hasJustSeeked = false
        wasPaused = false
        stopDisplayTimer()
        startDecayTimer()
    }
    
    // MARK: - Loop helpers (Step 1 only; not used yet)
    /// Configure loop using normalized positions (0.0...1.0 of track)
    func setLoop(enabled: Bool, startNormalized: Float, endNormalized: Float) {
        self.loopEnabled = enabled
        guard duration > 0 else {
            self.loopStart = 0
            self.loopEnd = 0
            self.loopBuffer = nil
            return
        }
        let s = max(0.0, min(1.0, Double(startNormalized))) * duration
        let e = max(0.0, min(1.0, Double(endNormalized))) * duration
        setLoopSeconds(enabled: enabled, start: min(s, e), end: max(s, e))
    }

    /// Configure loop using absolute seconds within the current track
    func setLoopSeconds(enabled: Bool, start: TimeInterval, end: TimeInterval) {
        self.loopEnabled = enabled
        let startSec = max(0.0, min(start, duration))
        let endSec = max(0.0, min(end, duration))
        self.loopStart = min(startSec, endSec)
        self.loopEnd = max(startSec, endSec)
        rebuildLoopBuffer()
    }

    /// Build or rebuild the decoded buffer covering [loopStart, loopEnd)
    private func rebuildLoopBuffer() {
        guard let audioFile = audioFile, let audioFormat = audioFormat else {
            loopBuffer = nil
            return
        }
        guard loopEnd > loopStart, (loopEnd - loopStart) >= 0.005 else { // at least 5ms
            loopBuffer = nil
            return
        }
        let sr = audioFormat.sampleRate
        var startFrame = AVAudioFramePosition(loopStart * sr)
        var endFrame = AVAudioFramePosition(loopEnd * sr)
        startFrame = max(0, min(startFrame, fileLengthFrames))
        endFrame = max(0, min(endFrame, fileLengthFrames))
        let frames64 = max(0, endFrame - startFrame)
        guard frames64 > 0 else { loopBuffer = nil; return }
        let frames = AVAudioFrameCount(frames64)
        guard let buf = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frames) else {
            loopBuffer = nil
            return
        }
        buf.frameLength = frames
        do {
            audioFile.framePosition = startFrame
            try audioFile.read(into: buf, frameCount: frames)
        } catch {
            print("Failed reading loop buffer: \(error)")
            loopBuffer = nil
            return
        }
        applyEdgeRamps(to: buf, rampSampleCount: 128)
        loopBuffer = buf
    }

    /// Apply small linear fades at the start and end of a buffer to reduce edge clicks
    private func applyEdgeRamps(to buffer: AVAudioPCMBuffer, rampSampleCount: Int) {
        let total = Int(buffer.frameLength)
        let n = max(0, min(rampSampleCount, total / 2))
        guard n > 0 else { return }
        let channels = Int(buffer.format.channelCount)
        if let fdata = buffer.floatChannelData {
            for ch in 0..<channels {
                let p = fdata[ch]
                // Fade in
                var i = 0
                while i < n {
                    let g = Float(i) / Float(n)
                    p[i] *= g
                    i += 1
                }
                // Fade out
                i = 0
                while i < n {
                    let idx = total - n + i
                    let g = 1.0 - Float(i) / Float(n)
                    p[idx] *= g
                    i += 1
                }
            }
        }
    }

    // MARK: - Timing helpers
    /// Returns timing info from the node’s render clock
    func getNodeTiming() -> (sampleRate: Double, nodeTime: AVAudioTime, playerTime: AVAudioTime)? {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
              let audioFormat = audioFormat else { return nil }
        return (sampleRate: audioFormat.sampleRate, nodeTime: nodeTime, playerTime: playerTime)
    }

    /// Current absolute source frame position in the file (best-effort)
    func currentSourceFrame() -> AVAudioFramePosition? {
        guard let timing = getNodeTiming() else { return nil }
        let elapsedFrames = AVAudioFramePosition(timing.playerTime.sampleTime)
        let offsetFrames = AVAudioFramePosition(seekOffset * timing.sampleRate)
        let cur = max(0, min(offsetFrames + elapsedFrames, fileLengthFrames))
        return cur
    }

    /// Frames remaining to the target absolute frame from current position
    func framesRemaining(to targetFrame: AVAudioFramePosition) -> AVAudioFrameCount? {
        guard let cur = currentSourceFrame() else { return nil }
        let remain64 = max(0, targetFrame - cur)
        return AVAudioFrameCount(remain64)
    }

    /// Create an AVAudioTime that starts after the given frame offset from now
    func makeStartTime(framesUntilStart: AVAudioFrameCount) -> AVAudioTime? {
        guard let timing = getNodeTiming() else { return nil }
        let startSampleTime = timing.playerTime.sampleTime + AVAudioFramePosition(framesUntilStart)
        return AVAudioTime(sampleTime: startSampleTime, atRate: timing.sampleRate)
    }

    // MARK: - Precise scheduling helpers
    /// Schedule one full LOOP pass (no .loops). Requires prebuilt loopBuffer.
    func scheduleOneLoopPass(at startTime: AVAudioTime? = nil) {
        guard let buffer = loopBuffer else { return }
        playerNode.scheduleBuffer(buffer, at: startTime, options: [], completionHandler: nil)
    }

    /// Schedule a file segment [startFrame, endFrame) optionally at a precise start time
    func scheduleFileSegment(startFrame: AVAudioFramePosition, endFrame: AVAudioFramePosition, at startTime: AVAudioTime? = nil) {
        guard let audioFile = audioFile else { return }
        let s = max(0, min(startFrame, fileLengthFrames))
        let e = max(0, min(endFrame, fileLengthFrames))
        let frames64 = max(0, e - s)
        guard frames64 > 0 else { return }
        let frames = AVAudioFrameCount(frames64)
        playerNode.scheduleSegment(audioFile, startingFrame: s, frameCount: frames, at: startTime, completionHandler: nil)
    }

    func seek(to time: TimeInterval) {
        guard audioFile != nil else {
            print("Seek failed: no audio file")
            return
        }

        let wasPlaying = isPlaying
        playerNode.stop()
        isPlaying = false
        wasPaused = false
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
                DispatchQueue.main.async {
                    self.currentTime = self.seekOffset
                }
            }
            return 
        }
        
        let sampleRate = audioFormat.sampleRate
        let nodeCurrentTime = Double(playerTime.sampleTime) / sampleRate
        
        // Calculate the new time value
        let newTime: Double
        if hasJustSeeked && nodeCurrentTime < 0.5 {
            newTime = seekOffset
            // After a few updates, trust the node time
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.hasJustSeeked = false
            }
        } else {
            // Add the seek offset to the node time to get the actual position
            newTime = seekOffset + nodeCurrentTime
            hasJustSeeked = false
        }
        
        // Update @Published property on main thread
        DispatchQueue.main.async {
            self.currentTime = newTime
        }
        
        // Check if we've reached the end
        if newTime >= duration {
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
