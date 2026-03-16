import AVFoundation

enum SFXType {
    // UI
    case tap, menuOpen, menuClose
    // Feeding
    case feed, munch, gulp
    // Stats
    case hungerRumble, healthWarning, happyChime
    // Minigames
    case win, lose, roundStart
    // Progression
    case levelup, evolve, crit
    // World
    case event, night
    // Death
    case death, dying, revive
    // Foraging
    case dig, itemFound, rareFind
    // Crafting
    case craftBubble, craftDone
    // Expedition
    case expeditionGo, expeditionReturn, lootSparkle
    // Grub states
    case snore, growl, chirp
    // Misc
    case crumb
}

class AudioEngine {
    var enabled: Bool = true

    private let engine = AVAudioEngine()
    private let mixerNode: AVAudioMixerNode
    private let format: AVAudioFormat
    private var playerPool: [AVAudioPlayerNode] = []
    private let poolSize = 8
    private var nextPlayer = 0
    private let audioQueue = DispatchQueue(label: "com.grub.audio", qos: .userInitiated)
    private var isRunning = false

    init() {
        let sampleRate: Double = 44100
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        mixerNode = engine.mainMixerNode

        // Create player pool
        for _ in 0..<poolSize {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixerNode, format: format)
            playerPool.append(player)
        }

        setupAudioSession()
        startEngine()

        // Restart engine after interruptions (phone calls, Siri, etc.)
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            if type == .ended {
                self?.isRunning = false
                self?.setupAudioSession()
                self?.startEngine()
            }
        }
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    private func startEngine() {
        guard !isRunning else { return }
        do {
            try engine.start()
            for player in playerPool {
                player.play()
            }
            isRunning = true
        } catch {
            print("Audio engine start failed: \(error)")
        }
    }

    private func getNextPlayer() -> AVAudioPlayerNode {
        let player = playerPool[nextPlayer]
        nextPlayer = (nextPlayer + 1) % poolSize
        return player
    }

    func play(_ sfx: SFXType) {
        guard enabled else { return }
        if !isRunning { startEngine() }
        switch sfx {

        // ── UI ──
        case .tap:
            // Soft click — short square blip
            playTone(freq: 880, duration: 0.025, volume: 0.06)
            playTone(freq: 660, duration: 0.02, delay: 0.02, volume: 0.04)

        case .menuOpen:
            // Rising sweep
            playTone(freq: 440, duration: 0.04, volume: 0.08)
            playTone(freq: 660, duration: 0.04, delay: 0.04, volume: 0.08)
            playTone(freq: 880, duration: 0.05, delay: 0.08, volume: 0.06)

        case .menuClose:
            // Falling sweep
            playTone(freq: 660, duration: 0.04, volume: 0.07)
            playTone(freq: 440, duration: 0.05, delay: 0.04, volume: 0.06)

        // ── Feeding ──
        case .feed:
            // Cheerful ascending chomp
            playTone(freq: 350, duration: 0.06, volume: 0.12)
            playTone(freq: 500, duration: 0.06, delay: 0.07, volume: 0.12)
            playTone(freq: 700, duration: 0.08, delay: 0.14, volume: 0.10)

        case .munch:
            // Crunchy chew — noise + tone
            playNoise(duration: 0.04, volume: 0.10)
            playTone(freq: 250, duration: 0.05, delay: 0.02, volume: 0.08)
            playNoise(duration: 0.04, volume: 0.08, delay: 0.08)

        case .gulp:
            // Descending swallow
            playSweep(startFreq: 600, endFreq: 150, duration: 0.15, volume: 0.10)

        // ── Stats ──
        case .hungerRumble:
            // Low growling stomach
            playTone(freq: 80, duration: 0.3, type: .sine, volume: 0.08)
            playTone(freq: 90, duration: 0.2, type: .sine, delay: 0.15, volume: 0.06)
            playNoise(duration: 0.1, volume: 0.03, delay: 0.1)

        case .healthWarning:
            // Urgent double beep
            playTone(freq: 880, duration: 0.08, volume: 0.12)
            playTone(freq: 880, duration: 0.08, delay: 0.15, volume: 0.12)

        case .happyChime:
            // Bright little ding
            playTone(freq: 1047, duration: 0.1, type: .sine, volume: 0.08)
            playTone(freq: 1319, duration: 0.12, type: .sine, delay: 0.08, volume: 0.06)

        // ── Minigames ──
        case .win:
            // Victory fanfare — ascending major
            let freqs: [Double] = [523, 659, 784, 1047]
            for (i, f) in freqs.enumerated() {
                playTone(freq: f, duration: 0.12, delay: Double(i) * 0.1, volume: 0.12)
            }

        case .lose:
            // Sad descending
            playTone(freq: 400, duration: 0.12, volume: 0.12)
            playTone(freq: 300, duration: 0.12, delay: 0.13, volume: 0.10)
            playTone(freq: 200, duration: 0.2, delay: 0.26, volume: 0.08)

        case .roundStart:
            // Quick attention-getting blip
            playTone(freq: 440, duration: 0.05, volume: 0.10)
            playNoise(duration: 0.03, volume: 0.06, delay: 0.06)
            playTone(freq: 880, duration: 0.06, delay: 0.10, volume: 0.10)

        // ── Progression ──
        case .levelup:
            // Triumphant scale
            let freqs: [Double] = [262, 330, 392, 523, 659, 784]
            for (i, f) in freqs.enumerated() {
                playTone(freq: f, duration: 0.1, type: .triangle, delay: Double(i) * 0.09, volume: 0.12)
            }

        case .evolve:
            // Magical transformation — noise burst + rising chord
            playNoise(duration: 0.06, volume: 0.15)
            let freqs: [Double] = [262, 330, 392, 523, 659]
            for (i, f) in freqs.enumerated() {
                playTone(freq: f, duration: 0.25, type: .triangle, delay: 0.08 + Double(i) * 0.12, volume: 0.12)
            }
            // Sparkle on top
            playTone(freq: 1568, duration: 0.15, type: .sine, delay: 0.7, volume: 0.06)

        case .crit:
            // Low thud warning
            playTone(freq: 120, duration: 0.15, volume: 0.15)
            playNoise(duration: 0.06, volume: 0.05, delay: 0.05)
            playTone(freq: 120, duration: 0.15, delay: 0.3, volume: 0.12)

        // ── World ──
        case .event:
            // Mystery discovery — low knock + question tone
            playTone(freq: 180, duration: 0.08, volume: 0.12)
            playNoise(duration: 0.05, volume: 0.06, delay: 0.1)
            playTone(freq: 440, duration: 0.1, type: .triangle, delay: 0.18, volume: 0.10)
            playTone(freq: 523, duration: 0.15, type: .triangle, delay: 0.28, volume: 0.08)

        case .night:
            // Gentle lullaby tones
            let freqs: [Double] = [392, 330, 262]
            for (i, f) in freqs.enumerated() {
                playTone(freq: f, duration: 0.25, type: .sine, delay: Double(i) * 0.3, volume: 0.06)
            }

        // ── Death ──
        case .death:
            // Somber descending — slow, heavy
            let freqs: [Double] = [392, 349, 330, 262, 196]
            for (i, f) in freqs.enumerated() {
                playTone(freq: f, duration: 0.3, type: .triangle, delay: Double(i) * 0.28, volume: 0.10)
            }

        case .dying:
            // Heartbeat — two low thuds
            playTone(freq: 60, duration: 0.12, type: .sine, volume: 0.15)
            playTone(freq: 55, duration: 0.15, type: .sine, delay: 0.18, volume: 0.12)

        case .revive:
            // Rising relief — ascending + sparkle
            playSweep(startFreq: 200, endFreq: 800, duration: 0.3, type: .triangle, volume: 0.12)
            playTone(freq: 1047, duration: 0.15, type: .sine, delay: 0.3, volume: 0.08)
            playTone(freq: 1319, duration: 0.15, type: .sine, delay: 0.4, volume: 0.06)

        // ── Foraging ──
        case .dig:
            // Scratching in dirt — noise bursts
            for i in 0..<3 {
                playNoise(duration: 0.06, volume: 0.08, delay: Double(i) * 0.1)
                playTone(freq: Double.random(in: 150...250), duration: 0.04, delay: Double(i) * 0.1 + 0.02, volume: 0.05)
            }

        case .itemFound:
            // Cheerful ping
            playTone(freq: 880, duration: 0.08, type: .sine, volume: 0.10)
            playTone(freq: 1175, duration: 0.1, type: .sine, delay: 0.08, volume: 0.08)

        case .rareFind:
            // Sparkly rare discovery
            playTone(freq: 880, duration: 0.06, type: .sine, volume: 0.10)
            playTone(freq: 1175, duration: 0.06, type: .sine, delay: 0.06, volume: 0.10)
            playTone(freq: 1568, duration: 0.08, type: .sine, delay: 0.12, volume: 0.10)
            playTone(freq: 2093, duration: 0.15, type: .sine, delay: 0.18, volume: 0.08)
            // Noise sparkle
            playNoise(duration: 0.04, volume: 0.04, delay: 0.25)

        // ── Crafting ──
        case .craftBubble:
            // Bubbly mixing
            playTone(freq: 300, duration: 0.05, type: .sine, volume: 0.06)
            playTone(freq: 450, duration: 0.05, type: .sine, delay: 0.08, volume: 0.06)
            playTone(freq: 350, duration: 0.05, type: .sine, delay: 0.16, volume: 0.06)

        case .craftDone:
            // Satisfying completion ding
            playTone(freq: 523, duration: 0.08, volume: 0.10)
            playTone(freq: 784, duration: 0.08, delay: 0.08, volume: 0.10)
            playTone(freq: 1047, duration: 0.15, delay: 0.16, volume: 0.08)

        // ── Expedition ──
        case .expeditionGo:
            // Adventurous departure — ascending with energy
            playTone(freq: 262, duration: 0.08, volume: 0.10)
            playTone(freq: 330, duration: 0.08, delay: 0.08, volume: 0.10)
            playTone(freq: 392, duration: 0.08, delay: 0.16, volume: 0.10)
            playTone(freq: 523, duration: 0.12, delay: 0.24, volume: 0.12)
            playNoise(duration: 0.06, volume: 0.04, delay: 0.24)

        case .expeditionReturn:
            // Triumphant return fanfare
            playTone(freq: 392, duration: 0.1, type: .triangle, volume: 0.12)
            playTone(freq: 523, duration: 0.1, type: .triangle, delay: 0.1, volume: 0.12)
            playTone(freq: 659, duration: 0.1, type: .triangle, delay: 0.2, volume: 0.12)
            playTone(freq: 784, duration: 0.2, type: .triangle, delay: 0.3, volume: 0.10)

        case .lootSparkle:
            // Shimmery sparkle
            playTone(freq: 1568, duration: 0.06, type: .sine, volume: 0.06)
            playTone(freq: 2093, duration: 0.06, type: .sine, delay: 0.05, volume: 0.05)
            playTone(freq: 1760, duration: 0.08, type: .sine, delay: 0.1, volume: 0.04)

        // ── Grub States ──
        case .snore:
            // Soft low breathing
            playSweep(startFreq: 80, endFreq: 60, duration: 0.4, type: .sine, volume: 0.05)
            playSweep(startFreq: 60, endFreq: 80, duration: 0.3, type: .sine, delay: 0.5, volume: 0.04)

        case .growl:
            // Angry low rumble
            playTone(freq: 100, duration: 0.2, volume: 0.12)
            playNoise(duration: 0.15, volume: 0.06, delay: 0.05)
            playTone(freq: 80, duration: 0.15, delay: 0.2, volume: 0.10)

        case .chirp:
            // Happy little chirp
            playTone(freq: 1200, duration: 0.04, type: .sine, volume: 0.08)
            playTone(freq: 1500, duration: 0.04, type: .sine, delay: 0.05, volume: 0.06)

        // ── Misc ──
        case .crumb:
            playTone(freq: 800, duration: 0.04, type: .sine, volume: 0.06)
        }
    }

    // MARK: - Synthesis

    enum WaveType {
        case square, sine, triangle
    }

    private func playTone(freq: Double, duration: Double, type: WaveType = .square, delay: Double = 0, volume: Float = 0.15) {
        audioQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            let buffer = self.generateToneBuffer(freq: freq, duration: duration, type: type, volume: volume)
            self.scheduleBuffer(buffer)
        }
    }

    private func playNoise(duration: Double, volume: Float = 0.1, delay: Double = 0) {
        audioQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            let buffer = self.generateNoiseBuffer(duration: duration, volume: volume)
            self.scheduleBuffer(buffer)
        }
    }

    private func playSweep(startFreq: Double, endFreq: Double, duration: Double, type: WaveType = .square, delay: Double = 0, volume: Float = 0.15) {
        audioQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            let buffer = self.generateSweepBuffer(startFreq: startFreq, endFreq: endFreq, duration: duration, type: type, volume: volume)
            self.scheduleBuffer(buffer)
        }
    }

    private func generateToneBuffer(freq: Double, duration: Double, type: WaveType, volume: Float) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let numSamples = Int(sampleRate * duration)
        guard numSamples > 0 else { return nil }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(numSamples)

        let data = buffer.floatChannelData![0]
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let phase = 2.0 * .pi * freq * t
            var sample: Double

            switch type {
            case .square:
                sample = sin(phase) >= 0 ? 1.0 : -1.0
            case .sine:
                sample = sin(phase)
            case .triangle:
                let p = phase / (.pi * 2)
                let frac = p - floor(p)
                sample = 4.0 * abs(frac - 0.5) - 1.0
            }

            let envelope = exp(-5.0 * t / duration)
            data[i] = Float(sample * Double(volume) * envelope)
        }

        return buffer
    }

    private func generateSweepBuffer(startFreq: Double, endFreq: Double, duration: Double, type: WaveType, volume: Float) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let numSamples = Int(sampleRate * duration)
        guard numSamples > 0 else { return nil }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(numSamples)

        let data = buffer.floatChannelData![0]
        var phase = 0.0
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let progress = t / duration
            let freq = startFreq + (endFreq - startFreq) * progress
            phase += 2.0 * .pi * freq / sampleRate

            var sample: Double
            switch type {
            case .square:
                sample = sin(phase) >= 0 ? 1.0 : -1.0
            case .sine:
                sample = sin(phase)
            case .triangle:
                let p = phase / (.pi * 2)
                let frac = p - floor(p)
                sample = 4.0 * abs(frac - 0.5) - 1.0
            }

            let envelope = exp(-3.0 * t / duration)
            data[i] = Float(sample * Double(volume) * envelope)
        }

        return buffer
    }

    private func generateNoiseBuffer(duration: Double, volume: Float) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let numSamples = Int(sampleRate * duration)
        guard numSamples > 0 else { return nil }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(numSamples)

        let data = buffer.floatChannelData![0]
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let envelope = exp(-5.0 * t / duration)
            data[i] = Float.random(in: -1...1) * volume * Float(envelope)
        }

        return buffer
    }

    private func scheduleBuffer(_ buffer: AVAudioPCMBuffer?) {
        guard let buffer = buffer else { return }
        let player = getNextPlayer()
        player.scheduleBuffer(buffer, completionHandler: nil)
    }
}
