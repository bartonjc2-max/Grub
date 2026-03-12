import AVFoundation

enum SFXType {
    case feed, win, lose, crit, crumb, tap, levelup, evolve, death, night, event
}

class AudioEngine {
    private var audioEngine: AVAudioEngine?
    private var isSetup = false

    init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    func play(_ sfx: SFXType) {
        switch sfx {
        case .feed:
            playTone(freq: 400, duration: 0.08)
            playTone(freq: 600, duration: 0.08, delay: 0.09)
            playTone(freq: 800, duration: 0.1, delay: 0.18)
        case .win:
            let freqs: [Double] = [523, 659, 784, 1047]
            for (i, f) in freqs.enumerated() {
                playTone(freq: f, duration: 0.1, delay: Double(i) * 0.12)
            }
        case .lose:
            playTone(freq: 400, duration: 0.15)
            playTone(freq: 200, duration: 0.2, delay: 0.17)
        case .crit:
            playTone(freq: 150, duration: 0.2, volume: 0.2)
            playTone(freq: 150, duration: 0.2, volume: 0.2, delay: 0.35)
        case .crumb:
            playTone(freq: 800, duration: 0.06, type: .sine, volume: 0.1)
        case .tap:
            playTone(freq: 600, duration: 0.03, volume: 0.08)
        case .levelup:
            let freqs: [Double] = [262, 294, 330, 392, 440, 523]
            for (i, f) in freqs.enumerated() {
                playTone(freq: f, duration: 0.1, delay: Double(i) * 0.1)
            }
        case .evolve:
            playNoise(duration: 0.05, volume: 0.3)
            let freqs: [Double] = [330, 523, 659]
            for (i, f) in freqs.enumerated() {
                playTone(freq: f, duration: 0.2, type: .triangle, volume: 0.2, delay: 0.1 + Double(i) * 0.15)
            }
        case .death:
            let freqs: [Double] = [392, 349, 330, 262]
            for (i, f) in freqs.enumerated() {
                playTone(freq: f, duration: 0.25, volume: 0.12, delay: Double(i) * 0.3)
            }
        case .night:
            let freqs: [Double] = [330, 294, 262]
            for (i, f) in freqs.enumerated() {
                playTone(freq: f, duration: 0.2, type: .triangle, volume: 0.08, delay: Double(i) * 0.25)
            }
        case .event:
            playTone(freq: 200, duration: 0.1, volume: 0.15)
            playNoise(duration: 0.08, volume: 0.08, delay: 0.12)
        }
    }

    enum WaveType {
        case square, sine, triangle
    }

    private func playTone(freq: Double, duration: Double, type: WaveType = .square, volume: Float = 0.15, delay: Double = 0) {
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.generateAndPlayTone(freq: freq, duration: duration, type: type, volume: volume)
        }
    }

    private func playNoise(duration: Double, volume: Float = 0.1, delay: Double = 0) {
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.generateAndPlayNoise(duration: duration, volume: volume)
        }
    }

    private func generateAndPlayTone(freq: Double, duration: Double, type: WaveType, volume: Float) {
        let sampleRate: Double = 44100
        let numSamples = Int(sampleRate * duration)
        guard numSamples > 0 else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else { return }
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

            // Envelope: exponential decay
            let envelope = exp(-5.0 * t / duration)
            data[i] = Float(sample * Double(volume) * envelope)
        }

        playBuffer(buffer, format: format)
    }

    private func generateAndPlayNoise(duration: Double, volume: Float) {
        let sampleRate: Double = 44100
        let numSamples = Int(sampleRate * duration)
        guard numSamples > 0 else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else { return }
        buffer.frameLength = AVAudioFrameCount(numSamples)

        let data = buffer.floatChannelData![0]
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let envelope = exp(-5.0 * t / duration)
            data[i] = Float.random(in: -1...1) * volume * Float(envelope)
        }

        playBuffer(buffer, format: format)
    }

    private func playBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat) {
        do {
            let engine = AVAudioEngine()
            let playerNode = AVAudioPlayerNode()
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
            try engine.start()
            playerNode.play()
            playerNode.scheduleBuffer(buffer) {
                engine.stop()
            }
            // Keep engine alive
            Thread.sleep(forTimeInterval: Double(buffer.frameLength) / format.sampleRate + 0.05)
        } catch {
            // Silently fail audio
        }
    }
}
