import AVFoundation
import AudioToolbox
import Combine
import Foundation

enum WhiteNoiseKind: String, CaseIterable, Codable, Identifiable {
    case rain
    case forest
    case ocean
    case cafe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rain: return "雨声"
        case .forest: return "森林"
        case .ocean: return "海浪"
        case .cafe: return "咖啡馆"
        }
    }

    var systemImage: String {
        switch self {
        case .rain: return "cloud.rain.fill"
        case .forest: return "leaf.fill"
        case .ocean: return "water.waves"
        case .cafe: return "cup.and.saucer.fill"
        }
    }
}

/// 实时合成环境声。声音由算法生成，不依赖任何外部或来源不明的音频文件。
@MainActor
final class WhiteNoiseService: ObservableObject {
    @Published private(set) var selectedKind: WhiteNoiseKind?
    @Published private(set) var isPlaying = false
    @Published var volume: Float = 0.35 {
        didSet {
            engine.mainMixerNode.outputVolume = min(max(volume, 0), 1)
        }
    }

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var generator: ProceduralNoiseGenerator?
    private var observerTokens: [NSObjectProtocol] = []
    private var shouldResumeAfterInterruption = false

    init() {
        observeAudioSession()
    }

    deinit {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
    }

    func toggle(_ kind: WhiteNoiseKind) {
        if selectedKind == kind {
            isPlaying ? pause() : resume()
        } else {
            play(kind)
        }
    }

    func play(_ kind: WhiteNoiseKind) {
        tearDownEngine(deactivateSession: false)

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            guard let format = AVAudioFormat(
                standardFormatWithSampleRate: 44_100,
                channels: 2
            ) else {
                return
            }

            let generator = ProceduralNoiseGenerator(kind: kind, sampleRate: format.sampleRate)
            let source = AVAudioSourceNode(format: format) { [generator] _, _, frameCount, audioBufferList in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for frame in 0..<Int(frameCount) {
                    let sample = generator.nextSample()
                    for bufferIndex in 0..<buffers.count {
                        let buffer = buffers[bufferIndex]
                        guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                        let channelCount = max(Int(buffer.mNumberChannels), 1)
                        for channel in 0..<channelCount {
                            data[frame * channelCount + channel] = sample
                        }
                    }
                }
                return noErr
            }

            self.generator = generator
            sourceNode = source
            engine.attach(source)
            engine.connect(source, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = min(max(volume, 0), 1)
            engine.prepare()
            try engine.start()
            selectedKind = kind
            isPlaying = true
        } catch {
            tearDownEngine(deactivateSession: true)
        }
    }

    func pause() {
        guard engine.isRunning else { return }
        engine.pause()
        isPlaying = false
    }

    func resume() {
        guard selectedKind != nil, !engine.isRunning else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        tearDownEngine(deactivateSession: true)
    }

    func setVolume(_ value: Float) {
        volume = min(max(value, 0), 1)
    }

    /// 计时暂停时调用。保留当前声景选择，方便继续计时时恢复。
    func handleFocusPaused() {
        pause()
    }

    /// 计时结束或放弃时调用。彻底释放音频引擎和 Audio Session。
    func handleFocusEnded() {
        stop()
    }

    private func tearDownEngine(deactivateSession: Bool) {
        if engine.isRunning {
            engine.stop()
        }
        if let sourceNode {
            engine.disconnectNodeOutput(sourceNode)
            engine.detach(sourceNode)
        }
        sourceNode = nil
        generator = nil
        selectedKind = nil
        isPlaying = false
        shouldResumeAfterInterruption = false

        if deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: [.notifyOthersOnDeactivation]
            )
        }
    }

    private func observeAudioSession() {
        let interruption = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleInterruption(notification)
            }
        }
        let routeChange = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleRouteChange(notification)
            }
        }
        observerTokens = [interruption, routeChange]
    }

    private func handleInterruption(_ notification: Notification) {
        guard
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else { return }

        switch type {
        case .began:
            shouldResumeAfterInterruption = isPlaying
            engine.pause()
            isPlaying = false
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            if shouldResumeAfterInterruption, options.contains(.shouldResume) {
                resume()
            }
            shouldResumeAfterInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard
            let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason)
        else { return }

        // 耳机被拔出时暂停，避免声音突然从扬声器播放。
        if reason == .oldDeviceUnavailable {
            pause()
        }
    }
}

private final class ProceduralNoiseGenerator {
    private let kind: WhiteNoiseKind
    private let sampleRate: Double
    private var randomState: UInt64 = 0x7a4d_31c9_bf02_e651
    private var previousWhite: Float = 0
    private var lowPass: Float = 0
    private var slowNoise: Float = 0
    private var brownNoise: Float = 0
    private var phase: Double = 0
    private var secondaryPhase: Double = 0
    private var eventSamplesRemaining = 0
    private var eventDuration = 1

    init(kind: WhiteNoiseKind, sampleRate: Double) {
        self.kind = kind
        self.sampleRate = sampleRate
        randomState ^= UInt64(kind.rawValue.utf8.reduce(0, { $0 &+ UInt64($1) }))
    }

    func nextSample() -> Float {
        let value: Float
        switch kind {
        case .rain:
            value = rainSample()
        case .forest:
            value = forestSample()
        case .ocean:
            value = oceanSample()
        case .cafe:
            value = cafeSample()
        }
        return softClip(value)
    }

    private func rainSample() -> Float {
        let white = randomSigned()
        lowPass += 0.035 * (white - lowPass)
        let hiss = white - previousWhite * 0.58
        previousWhite = white

        var drop: Float = 0
        if eventSamplesRemaining <= 0, randomUnit() < 0.00012 {
            eventDuration = Int(sampleRate * (0.012 + Double(randomUnit()) * 0.035))
            eventSamplesRemaining = eventDuration
            phase = 0
        }
        if eventSamplesRemaining > 0 {
            let progress = 1 - Float(eventSamplesRemaining) / Float(max(eventDuration, 1))
            let envelope = expf(-8 * progress)
            phase += 2 * .pi * (1_500 + 1_300 * Double(progress)) / sampleRate
            drop = Float(sin(phase)) * envelope * 0.42
            eventSamplesRemaining -= 1
        }
        return hiss * 0.15 + lowPass * 0.18 + drop
    }

    private func forestSample() -> Float {
        let white = randomSigned()
        slowNoise += 0.0025 * (white - slowNoise)
        brownNoise = min(max(brownNoise + white * 0.012, -1), 1) * 0.998

        var bird: Float = 0
        if eventSamplesRemaining <= 0, randomUnit() < 0.000018 {
            eventDuration = Int(sampleRate * (0.10 + Double(randomUnit()) * 0.18))
            eventSamplesRemaining = eventDuration
            phase = 0
        }
        if eventSamplesRemaining > 0 {
            let progress = 1 - Double(eventSamplesRemaining) / Double(max(eventDuration, 1))
            let envelope = Float(sin(.pi * progress))
            let frequency = 1_900 + 1_100 * sin(progress * .pi)
            phase += 2 * .pi * frequency / sampleRate
            bird = Float(sin(phase)) * envelope * 0.08
            eventSamplesRemaining -= 1
        }
        return slowNoise * 0.24 + brownNoise * 0.10 + bird
    }

    private func oceanSample() -> Float {
        let white = randomSigned()
        lowPass += 0.012 * (white - lowPass)
        brownNoise = min(max(brownNoise + white * 0.008, -1), 1) * 0.999
        phase += 2 * .pi * 0.085 / sampleRate
        secondaryPhase += 2 * .pi * 0.037 / sampleRate
        let swell = Float(0.38 + 0.28 * sin(phase) + 0.16 * sin(secondaryPhase))
        let foam = (white - previousWhite * 0.72) * max(swell, 0.08) * 0.08
        previousWhite = white
        return (lowPass * 0.38 + brownNoise * 0.20) * max(swell, 0.08) + foam
    }

    private func cafeSample() -> Float {
        let white = randomSigned()
        lowPass += 0.055 * (white - lowPass)
        slowNoise += 0.0009 * (randomSigned() - slowNoise)
        phase += 2 * .pi * (170 + 28 * Double(slowNoise)) / sampleRate
        secondaryPhase += 2 * .pi * (247 + 35 * Double(slowNoise)) / sampleRate
        let murmur = Float(sin(phase) + 0.55 * sin(secondaryPhase)) * 0.035
        let roomTone = lowPass * 0.19 + (white - lowPass) * 0.035
        return roomTone * (0.72 + slowNoise * 0.16) + murmur
    }

    private func randomUnit() -> Float {
        randomState ^= randomState << 13
        randomState ^= randomState >> 7
        randomState ^= randomState << 17
        return Float(randomState & 0x00ff_ffff) / Float(0x0100_0000)
    }

    private func randomSigned() -> Float {
        randomUnit() * 2 - 1
    }

    private func softClip(_ input: Float) -> Float {
        tanhf(input * 1.35) * 0.72
    }
}
