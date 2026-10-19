import Foundation
import GuardianCore
#if canImport(AVFoundation)
import AVFoundation

// MARK: - Audio provider + Speech transcription adapter (PROMPT 005 §10, §11, §12)
// Local-first; NO microphone permission for local-file analysis; NO silent network/cloud fallback.

public struct AudioProviderV1: Sendable {
    public static let version = "audio-provider-v1"
    public init() {}
    /// Detect audio track presence (bounded; no full-file PCM copy). Full windowed extraction is future work.
    public func audioAvailable(url: URL) async -> Bool {
        await MediaAssetSource().hasAudioTrack(url: url)
    }
}

/// SpeechTranscriptionPort adapter. In the headless LAB there is no spoken-audio fixture and locale
/// transcription assets are not verified installable without network — so transcription is honestly
/// UNAVAILABLE here (never faked, never silent cloud). Structure is production-shaped for later device work.
public struct SpeechTranscriptionAdapter: SpeechTranscriptionPort, Sendable {
    public let engineVersion = "speech-adapter-v1"
    public init() {}
    public func transcribe(_ media: MediaRef) async -> PortOutcome<TextSpan> {
        // No spoken-audio fixture + unverified on-device locale assets + no network allowed → UNAVAILABLE.
        .unavailable(engineVersion: engineVersion)
    }
}
#endif
