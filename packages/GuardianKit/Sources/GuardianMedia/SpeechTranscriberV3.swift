import Foundation
import Speech
import GuardianCore

// MARK: - TR/EN Speech V3 (PROMPT 007 §7,§8) — real on-device path + explicit, truthful availability probe.
// No microphone (file analysis only). No cloud (requiresOnDeviceRecognition = true). Honest blocker when unavailable.

public struct SpeechAvailabilityReport: Sendable, Equatable, Codable {
    public let localeID: String
    public let recognizerExists: Bool
    public let isAvailable: Bool
    public let supportsOnDevice: Bool
    public let authorizationStatus: String        // notDetermined / denied / restricted / authorized
    public let verdict: String                    // READY / BLOCKED_<reason>
    public var isReady: Bool { verdict == "READY" }
}

public struct SpeechTranscriberV3: Sendable {
    public static let version = "speech-transcriber-v3"
    public init() {}

    /// Probe the on-device speech path for a locale WITHOUT transcribing — the exact, verifiable availability truth.
    public func probe(localeID: String) -> SpeechAvailabilityReport {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID))
        let exists = recognizer != nil
        let available = recognizer?.isAvailable ?? false
        let onDevice = recognizer?.supportsOnDeviceRecognition ?? false
        let auth: String
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: auth = "authorized"
        case .denied: auth = "denied"
        case .restricted: auth = "restricted"
        case .notDetermined: auth = "notDetermined"
        @unknown default: auth = "unknown"
        }
        let verdict: String
        if !exists { verdict = "BLOCKED_NO_RECOGNIZER_FOR_LOCALE" }
        else if auth != "authorized" { verdict = "BLOCKED_NOT_AUTHORIZED" }
        else if !onDevice { verdict = "BLOCKED_NO_ON_DEVICE_ASSET" }
        else if !available { verdict = "BLOCKED_RECOGNIZER_UNAVAILABLE" }
        else { verdict = "READY" }
        return SpeechAvailabilityReport(localeID: localeID, recognizerExists: exists, isAvailable: available,
                                        supportsOnDevice: onDevice, authorizationStatus: auth, verdict: verdict)
    }

    /// Transcribe a file on-device only. Returns the honest signal; abstains (UNAVAILABLE) when the path is not READY.
    public func transcribe(url: URL, localeID: String) async -> (signal: IntelligenceSignal<SpeechTranscriptV2>, report: SpeechAvailabilityReport) {
        let report = probe(localeID: localeID)
        guard report.isReady else {
            return (IntelligenceSignal(task: "speech", value: nil, rawConfidence: nil, availability: .unavailable,
                                       provenance: .appleSpeech, modelVersion: Self.version,
                                       abstentionReason: .notImplemented, language: localeID), report)
        }
        let sig = await SpeechTranscriberV2().transcribeFile(url: url, localeID: localeID)
        return (sig, report)
    }
}
