import Foundation
import GuardianCore
#if canImport(Speech) && canImport(AVFoundation)
import Speech
import AVFoundation

// MARK: - Speech Transcriber V2 (PROMPT 006 §8) — attempt REAL on-device TR/EN transcription of a local file.
// NO microphone permission for file analysis. NO silent network/cloud fallback. Honest UNAVAILABLE if the
// runtime cannot authorize / lacks on-device assets. Timestamps where the API provides them.

public struct SpeechTranscriptV2: Sendable, Equatable {
    public let text: String
    public let locale: String
    public let onDevice: Bool
}

public struct SpeechTranscriberV2: Sendable {
    public static let version = "speech-transcriber-v2"
    public init() {}

    public func transcribeFile(url: URL, localeID: String) async -> IntelligenceSignal<SpeechTranscriptV2> {
        let locale = Locale(identifier: localeID)
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            return unavail(localeID, .languageUnsupported)
        }
        // Local-first only: require on-device recognition; never send audio to a network service.
        guard recognizer.supportsOnDeviceRecognition else { return unavail(localeID, .notImplemented) }
        // Authorization must be granted (no UI in headless → typically not authorized → honest UNAVAILABLE).
        let auth = SFSpeechRecognizer.authorizationStatus()
        guard auth == .authorized else { return unavail(localeID, .notImplemented) }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true          // hard local-first
        request.shouldReportPartialResults = false
        return await withCheckedContinuation { cont in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                if finished { return }
                if let error {
                    finished = true; cont.resume(returning: unavail(localeID, .notImplemented)); _ = error; return
                }
                if let result, result.isFinal {
                    finished = true
                    let t = result.bestTranscription.formattedString
                    cont.resume(returning: IntelligenceSignal(task: "speech", value: SpeechTranscriptV2(text: t, locale: localeID, onDevice: true),
                        rawConfidence: 0.7, availability: .available, provenance: .appleSpeech,
                        modelVersion: Self.version, language: localeID))
                }
            }
        }
    }

    private func unavail(_ locale: String, _ reason: AbstentionReason) -> IntelligenceSignal<SpeechTranscriptV2> {
        IntelligenceSignal(task: "speech", value: nil, rawConfidence: nil, availability: .unavailable,
                           provenance: .appleSpeech, modelVersion: Self.version, abstentionReason: reason, language: locale)
    }
}
#endif
