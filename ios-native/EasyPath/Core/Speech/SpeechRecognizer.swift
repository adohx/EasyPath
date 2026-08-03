import AVFoundation
import Speech

/// Push-to-talk speech recognition, replacing the Flutter
/// `speech_to_text` plugin dependency (declared but unused per
/// `docs/4.接口文档.md` section "一、Flutter ↔ 手机底层接口").
///
/// Implements the "hold to talk" flow from design doc section 3.1.1.1:
/// `startListening()` begins a single recognition session,
/// `stopListening()` ends it and returns the final transcript. This is
/// intentionally not continuous listening — the design doc explicitly
/// rules that out for the first version.
protocol SpeechRecognizing: Sendable {
    func requestAuthorization() async -> Bool
    func startListening() throws
    func stopListening() async -> String?
}

enum SpeechRecognizerError: Error {
    case recognizerUnavailable
    case audioEngineFailure
}

final class SpeechRecognizer: SpeechRecognizing, @unchecked Sendable {
    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latestTranscript: String?

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startListening() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechRecognizerError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        latestTranscript = nil

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [request] buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw SpeechRecognizerError.audioEngineFailure
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            if let result {
                self?.latestTranscript = result.bestTranscription.formattedString
            }
        }
    }

    func stopListening() async -> String? {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        return latestTranscript
    }
}
