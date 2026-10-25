//
//  LongFormFixtureV1.swift — mandate D1: a REAL, OWNED 600-second long-form test asset (generated, never committed).
//
//  WHY (mandate D1): the 600s benchmark must run on a GENUINELY 600-second video with real scene/text/audio events
//  across the whole duration — NOT a "600s metadata + 2s media" trick. This generator produces such an asset at test
//  time via the EXISTING SyntheticVideo AVAssetWriter path (so the file is a real, decodable H.264 MP4 with an audio
//  track), keeps it small (low fps / low resolution), and ships a verifiable MANIFEST. The binary is NEVER committed
//  (it is written to a temp dir and verified against the manifest in-test, then deleted).
//
//  HONESTY: the events are at KNOWN timestamps spread across the full 600s so a sampled plan can be checked to examine
//  genuinely different time regions. The manifest records the intended duration + event layout so a test can assert
//  the generated file really is ~600s (duration read back from the asset), not a padded short clip.
//
import Foundation
import GuardianCore
#if canImport(AVFoundation)
import AVFoundation

/// mandate D1 — the verifiable manifest for the generated 600s asset. No media bytes; just the claimed shape so a
/// test can confirm the generated file matches (duration read back from the real asset must be within tolerance).
public struct LongFormFixtureManifestV1: Sendable, Equatable, Codable {
    public let durationSeconds: Double
    public let fps: Int
    public let width: Int
    public let height: Int
    public let textEventSeconds: [Double]     // the times a text overlay appears (known match points)
    public let sceneChangeSeconds: [Double]   // the times the background scene changes
    public let hasAudioTrack: Bool
    public init(durationSeconds: Double, fps: Int, width: Int, height: Int,
                textEventSeconds: [Double], sceneChangeSeconds: [Double], hasAudioTrack: Bool) {
        self.durationSeconds = durationSeconds; self.fps = fps; self.width = width; self.height = height
        self.textEventSeconds = textEventSeconds; self.sceneChangeSeconds = sceneChangeSeconds
        self.hasAudioTrack = hasAudioTrack
    }
}

public enum LongFormFixtureV1 {
    /// mandate D1 — the canonical 600s spec: 2fps / 480x270, text overlays + scene changes spread across the FULL
    /// duration (early / several mid / near-end), with an audio tone track. At 2fps a 600s clip is ~1200 frames — a
    /// real but small file. The text events are plain English words so the benchmark can exercise OCR rules.
    public static func canonicalSpec(durationSeconds: Double = 600,
                                     textLabel: String = "EARTHQUAKE DISASTER") -> SyntheticVideo.Spec {
        // Text overlays at known points across the whole 600s (not clustered at the start — mandate "farklı zaman").
        let textTimes: [Double] = [30, 150, 300, 450, 570]
        let textEvents: [(Double, String)] = textTimes.map { ($0, textLabel) }
        // Scene changes every ~60s so a selective plan can find different regions.
        let sceneTimes = stride(from: 0.0, through: durationSeconds, by: 60.0).map { ($0, CGFloat(($0 / 60).truncatingRemainder(dividingBy: 2) == 0 ? 0.85 : 0.2)) }
        return SyntheticVideo.Spec(durationSeconds: durationSeconds, fps: 2, width: 480, height: 270,
                                   textEvents: textEvents, sceneChanges: Array(sceneTimes))
    }

    public static func manifest(for spec: SyntheticVideo.Spec, hasAudioTrack: Bool) -> LongFormFixtureManifestV1 {
        LongFormFixtureManifestV1(durationSeconds: spec.durationSeconds, fps: spec.fps, width: spec.width,
                                  height: spec.height, textEventSeconds: spec.textEvents.map { $0.0 },
                                  sceneChangeSeconds: spec.sceneChanges.map { $0.0 }, hasAudioTrack: hasAudioTrack)
    }

    /// mandate D1 — GENERATE the 600s asset with a real audio track at `url` and return its manifest on success.
    /// Generation may take ~1-2 min (bounded by the 2fps frame count). The binary is NOT committed; the caller writes
    /// it to a temp dir and deletes it after the test.
    @discardableResult
    public static func generate(to url: URL, spec: SyntheticVideo.Spec? = nil) async -> LongFormFixtureManifestV1? {
        let s = spec ?? canonicalSpec()
        let ok = await SyntheticVideo.writeWithAudioTone(s, to: url)
        guard ok else { return nil }
        return manifest(for: s, hasAudioTrack: true)
    }

    /// mandate D1 — VERIFY the generated file really matches the manifest: the asset's REAL duration (read back from
    /// AVFoundation, not the spec) must be within `toleranceSeconds` of the claimed 600s, and the audio-track claim
    /// must hold. Returns (durationMatches, audioMatches, actualDuration). This is the anti-"metadata trick" check.
    public static func verify(url: URL, manifest: LongFormFixtureManifestV1,
                              toleranceSeconds: Double = 2.0) async -> (durationMatches: Bool, audioMatches: Bool, actualDuration: Double) {
        let asset = AVURLAsset(url: url)
        let actual: Double = await {
            if let d = try? await asset.load(.duration) { return CMTimeGetSeconds(d) }
            return 0
        }()
        let durationMatches = abs(actual - manifest.durationSeconds) <= toleranceSeconds
        let hasAudio = (await ReelsAudioEvidenceProviderV1.hasAudioTrack(asset: asset)) ?? false
        return (durationMatches, hasAudio == manifest.hasAudioTrack, actual)
    }
}
#endif
