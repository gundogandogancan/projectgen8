import Foundation
import GuardianCore
import GuardianIntelligence

// MARK: - P009B-R1 §4 — audio side of the real-observation adapter: REAL SoundAnalysis (+ music presence)
// over an owned/rights-clear local media file → derived ExpertInputV2 fields. No synthetic fallback.

public struct RealAudioObservationAdapterV1: Sendable {
    public static let version = "real-audio-observation-adapter-v1"
    private let audio = GeneralAudioHeadV1()
    public init() {}

    /// Merges REAL SoundAnalysis classes + music presence into an existing adapted input.
    public func adaptAudio(url: URL, into base: ExpertInputV2) -> (input: ExpertInputV2, provenance: [String]) {
        var input = base
        var provenance: [String] = []
        let sig = audio.classify(url: url)                                   // REAL SNClassifySoundRequest
        if let classes = sig.value, !classes.isEmpty {
            input.soundEvents = classes.map { $0.label }
            provenance.append("audio←\(GeneralAudioHeadV1.version)")
        }
        if let music = audio.isMusic(url: url) {
            input.musicPresence = music
            provenance.append("music←\(GeneralAudioHeadV1.version)")
        }
        return (input, provenance)
    }
}
