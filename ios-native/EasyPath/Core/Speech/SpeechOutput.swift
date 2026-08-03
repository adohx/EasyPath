import AVFoundation

/// Text-to-speech output, replacing the Flutter `flutter_tts` plugin
/// (`app/lib/services/tts_service.dart`).
///
/// Design doc section 3.2.2 requires: short utterances, interruptible,
/// repeatable, and higher-priority alerts must be able to cut off a
/// lower-priority one currently speaking. `priority` maps directly onto
/// that requirement — callers pass the same `AnnouncementPriorityTier`
/// used for proximity alerts (`Core/Models/AnnouncementPriority.swift`),
/// and a higher-priority utterance interrupts whatever is currently
/// speaking.
protocol SpeechOutputting: Sendable {
    func speak(_ text: String, priority: AnnouncementPriorityTier) async
    func stop()
}

final class SpeechOutput: NSObject, SpeechOutputting, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private var currentPriority: AnnouncementPriorityTier?

    func speak(_ text: String, priority: AnnouncementPriorityTier) async {
        // Lower `AnnouncementPriorityTier` rawValues are more urgent
        // (`.riskPoint` == 0), so a smaller value than what's currently
        // speaking is what should interrupt it.
        if let currentPriority, priority < currentPriority, synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentPriority = priority

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        currentPriority = nil
    }
}
