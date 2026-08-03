import UIKit

/// Vibration feedback, replacing the Flutter `vibration` plugin
/// (`app/lib/services/vibration_service.dart`).
///
/// The four patterns below come directly from design doc section 3.2.1's
/// vibration table. `UIFeedbackGenerator` is used instead of Core Haptics
/// because these are short, semantic cues (not a custom waveform), and it
/// works without checking device capability up front.
enum HapticPattern {
    /// 短震一次 — an upcoming turn or an ordinary navigation functional
    /// point.
    case shortTap
    /// 长震一次 — off-route, or approaching a risk point.
    case longPulse
    /// 短震加长震 — approaching a bus/taxi board or alight point.
    case shortThenLong
    /// 连续短震 — needs immediate attention (clear off-route).
    case urgentBurst
}

protocol HapticsPlaying: Sendable {
    func play(_ pattern: HapticPattern) async
}

@MainActor
final class HapticsPlayer: HapticsPlaying {
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    func play(_ pattern: HapticPattern) async {
        switch pattern {
        case .shortTap:
            impact.impactOccurred()
        case .longPulse:
            notification.notificationOccurred(.warning)
        case .shortThenLong:
            impact.impactOccurred()
            try? await Task.sleep(for: .milliseconds(250))
            notification.notificationOccurred(.warning)
        case .urgentBurst:
            for _ in 0..<3 {
                notification.notificationOccurred(.error)
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }
}
