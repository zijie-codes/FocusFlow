import AudioToolbox
import UIKit

/// 仅使用系统声音和系统触觉，不捆绑任何外部音频素材。
@MainActor
final class FeedbackService {
    enum Event {
        case countdownTick
        case focusCompleted
        case breakCompleted
        case warning
    }

    func play(_ event: Event, soundEnabled: Bool, hapticEnabled: Bool) {
        if soundEnabled {
            AudioServicesPlaySystemSound(soundID(for: event))
        }

        guard hapticEnabled else { return }
        switch event {
        case .countdownTick:
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred(intensity: 0.55)
        case .focusCompleted, .breakCompleted:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
        }
    }

    func vibrateOnly() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    private func soundID(for event: Event) -> SystemSoundID {
        switch event {
        case .countdownTick:
            return 1104
        case .focusCompleted:
            return 1007
        case .breakCompleted:
            return 1013
        case .warning:
            return 1053
        }
    }
}
