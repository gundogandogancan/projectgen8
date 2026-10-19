import Foundation
import GuardianCore
#if canImport(AVFoundation)
import AVFoundation

// MARK: - Music Intelligence Stack V1 (PROMPT 006 §10) — music ≠ speech. No copyrighted lyric scraping.

// M1 music/non-music is served by GeneralAudioHeadV1.isMusic (Apple Sound Analysis).
// M3 audio characteristics — bounded loudness/energy via real PCM RMS (ephemeral).
public struct AudioCharacteristicsV1: Sendable {
    public static let version = "audio-characteristics-v1"
    public struct Features: Sendable, Equatable { public let loudnessRMS: Double; public let peak: Double }
    public init() {}
    public func analyze(url: URL) -> IntelligenceSignal<Features> {
        guard let file = try? AVAudioFile(forReading: url) else {
            return .unavailable(task: "audio_characteristics", version: Self.version)
        }
        let format = file.processingFormat
        let frames = AVAudioFrameCount(min(file.length, 16000 * 10))   // bounded window
        guard frames > 0, let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              (try? file.read(into: buf)) != nil, let ch = buf.floatChannelData?[0] else {
            return .unavailable(task: "audio_characteristics", version: Self.version)
        }
        var sumSq = 0.0; var peak = 0.0
        let n = Int(buf.frameLength)
        for i in 0..<n { let v = Double(ch[i]); sumSq += v*v; peak = max(peak, abs(v)) }
        let rms = n > 0 ? (sumSq / Double(n)).squareRoot() : 0
        return IntelligenceSignal(task: "audio_characteristics", value: Features(loudnessRMS: rms, peak: peak),
                                  rawConfidence: 0.8, availability: .available, provenance: .rulesV1,
                                  modelVersion: Self.version)
    }
}

// M2 song identity — ShazamKit requires network + catalog/entitlement → UNAVAILABLE in lab (honest; no fake).
public struct ShazamIdentityAdapter: Sendable {
    public static let version = "shazam-adapter-v1"
    public init() {}
    public func identify(url: URL) -> IntelligenceSignal<String> {
        // No ShazamKit entitlement/network in lab; never fabricate a match; never pretend identity = meaning.
        .unavailable(task: "music_identity", version: Self.version, reason: .notImplemented)
    }
}

// M5 personal music policy — preference, NOT universal truth.
public struct PersonalMusicPolicy: Sendable, Equatable {
    public let excludedArtistsOrSources: Set<String>
    public let avoidHighStimulation: Bool
    public init(excludedArtistsOrSources: Set<String> = [], avoidHighStimulation: Bool = false) {
        self.excludedArtistsOrSources = excludedArtistsOrSources; self.avoidHighStimulation = avoidHighStimulation
    }
    public func excludes(sourceOrArtist: String?) -> Bool {
        guard let s = sourceOrArtist?.lowercased() else { return false }
        return excludedArtistsOrSources.contains { s.contains($0.lowercased()) }
    }
}
#endif
