//
//  ReelsAssetLibraryV1.swift — B: the project-OWNED local reels the controlled player plays.
//
//  WHY THIS EXISTS (mandate B + §5 REAL VIDEOS): the controlled player needs REAL, playable, locally-OWNED
//  videos — never SwiftUI card stand-ins. We generate them programmatically with SyntheticVideo (AVAssetWriter →
//  real H.264 MP4, colored moving background + burned-in text so Vision OCR has genuine material). Because these
//  are app-generated and app-owned, they are the LEGITIMATE controlled surface where a HIDE decision may really
//  EXECUTE. At least three honest cases (mandate B, G3/G4/G10):
//    1. "unmatched"    — text that matches NO user rule → PLAYS.
//    2. "exact-match"  — burns in a term the demo rule targets (e.g. "SPOILER") → HIDDEN before exposure.
//    3. "undetermined" — a near-blank open (no legible early text) → UNKNOWN → explicit decision screen.
//
//  The files are written once into Caches (ephemeral, regenerable) on first run; nothing copyrighted or private.
//
//  §E4 TEMPORAL SCENARIO SET: beyond the three originals + the mid-segment reel, the library now also renders an
//  END-match reel, a MULTI-time-match reel, and a SHORT-BLIP reel whose match falls BETWEEN adaptive sample points
//  (honestly expected to be MISSED → NOT_DETECTED, which the E4 test measures as the recall limit). Seven reels total.
//
import Foundation
#if canImport(AVFoundation)
import AVFoundation

/// Builds + vends the controlled player's OWNED local reels. Deterministic ids/titles so the UI + tests agree.
public struct ReelsAssetLibraryV1: Sendable {
    public static let version = "reels-asset-library-v1"

    /// The canonical demo term the default HIDE rule targets. Burned into the "exact-match" reel so a real OCR
    /// read genuinely triggers a hide (not a hardcoded verdict). Kept uppercase for OCR legibility.
    public static let exactMatchTerm = "SPOILER"

    /// A spec for one reel: id, title (declared metadata), and the SyntheticVideo content to render.
    public struct Plan: Sendable {
        public let id: String
        public let title: String
        public let spec: SyntheticVideo.Spec
        public init(id: String, title: String, spec: SyntheticVideo.Spec) {
            self.id = id; self.title = title; self.spec = spec
        }
    }

    public init() {}

    /// The three canonical plans. Each renders ~2.5s of real video with legible burned-in text at the open so the
    /// pre-exposure OCR has honest material to read.
    public func plans() -> [Plan] {
        [
            Plan(id: "reel-calm-cooking", title: "Calm cooking b-roll",
                 spec: SyntheticVideo.Spec(durationSeconds: 2.5,
                                           textEvents: [(0.0, "CALM COOKING"), (0.6, "CALM COOKING"), (1.2, "FRESH HERBS")],
                                           sceneChanges: [(0.0, 0.90), (1.3, 0.80)])),
            Plan(id: "reel-exact-spoiler", title: "Season finale reaction",
                 spec: SyntheticVideo.Spec(durationSeconds: 2.5,
                                           textEvents: [(0.0, Self.exactMatchTerm), (0.6, Self.exactMatchTerm), (1.2, "\(Self.exactMatchTerm) AHEAD")],
                                           sceneChanges: [(0.0, 0.88), (1.4, 0.30)])),
            // Near-blank open (no legible text early) → OCR yields little → honest UNDETERMINED decision screen.
            Plan(id: "reel-undetermined", title: "Unlabeled clip",
                 spec: SyntheticVideo.Spec(durationSeconds: 2.5, textEvents: [],
                                           sceneChanges: [(0.0, 0.50), (1.2, 0.52)])),
            // §7 TEMPORAL — CLEAN opening, matching term only in the MID segment. The opening-frame-only analysis
            // would MISS it; temporal start/mid/end sampling catches it and HIDES before playback. Longer (6s) so
            // the mid timepoint (~3s) lands squarely inside the burned-in SPOILER window.
            Plan(id: "reel-mid-spoiler", title: "Slow build clip",
                 spec: SyntheticVideo.Spec(durationSeconds: 6.0,
                                           textEvents: [(0.0, "CALM INTRO"), (0.6, "CALM INTRO"),
                                                        (2.7, Self.exactMatchTerm), (3.0, Self.exactMatchTerm),
                                                        (3.3, "\(Self.exactMatchTerm) REVEAL")],
                                           sceneChanges: [(0.0, 0.90), (2.5, 0.40), (4.5, 0.70)])),
            // §E4 END-match — clean until the final second; the near-end sample must catch it (proves end coverage).
            Plan(id: "reel-end-spoiler", title: "Build to reveal",
                 spec: SyntheticVideo.Spec(durationSeconds: 6.0,
                                           textEvents: [(0.0, "CALM INTRO"), (0.6, "CALM INTRO"),
                                                        (5.2, Self.exactMatchTerm), (5.6, "\(Self.exactMatchTerm) ENDING")],
                                           sceneChanges: [(0.0, 0.90), (5.0, 0.35)])),
            // §E4 MULTI-time match — the term appears at the open AND mid AND end, so several samples each cite it.
            // Proves per-sample attribution (E1): more than one timed record carries the matched rule, no fusion lie.
            Plan(id: "reel-multi-spoiler", title: "Recurring reveal",
                 spec: SyntheticVideo.Spec(durationSeconds: 6.0,
                                           textEvents: [(0.1, Self.exactMatchTerm), (2.9, Self.exactMatchTerm),
                                                        (3.1, Self.exactMatchTerm), (5.4, Self.exactMatchTerm)],
                                           sceneChanges: [(0.0, 0.88), (2.6, 0.45), (5.0, 0.60)])),
            // §E4 SHORT-BLIP between samples — the match appears for a brief window (~3.9–4.1s) that falls BETWEEN the
            // adaptive sample points on a 6s clip (open ~0.1, mid ~3.0, interior ~4.5, near-end ~5.7). It is LIKELY
            // MISSED. The E4 test asserts this is reported NOT_DETECTED honestly (recall-limit measurement), never a
            // false "safe". We do NOT tune the sampler to this fixture — the miss is the honest point.
            Plan(id: "reel-short-blip", title: "Blink reveal",
                 spec: SyntheticVideo.Spec(durationSeconds: 6.0,
                                           textEvents: [(0.0, "CALM INTRO"), (0.6, "CALM INTRO"),
                                                        (3.92, Self.exactMatchTerm), (4.04, Self.exactMatchTerm),
                                                        (4.6, "CALM OUTRO"), (5.6, "CALM OUTRO")],
                                           sceneChanges: [(0.0, 0.90), (3.9, 0.5), (4.2, 0.9)]))
        ]
    }

    // MARK: §D — AUDIO-BEARING synthetic fixtures (owned, legally-safe) for the audio evidence sense.
    //
    // HONESTY (mandate D/I): SyntheticVideo is video-only (no audio channel). For the audio sense we generate standalone
    // OWNED audio files with SyntheticAudio — a silence clip, a pure tone, and a synthesized-speech clip. These are
    // genuinely owned and rights-clear. A tone is a tone and silence is silence: the tests assert on what Apple Sound
    // Analysis ACTUALLY returns for each (availability + mechanics + whatever real labels come back), NOT on a wished-
    // for label. The speech clip is AVSpeechSynthesizer output (owned); whether the classifier calls it "speech" is the
    // classifier's call, which the tests observe rather than assert blind. FP/FN claims are made only where real.

    /// §D — one audio fixture spec: id + the kind of owned audio to synthesize. Rendered to a WAV the audio provider
    /// (and SoundAnalysis) can read directly (a WAV carries a real audio track; the reel player can also play it).
    public enum AudioFixtureKind: Sendable { case silence, tone, speech }

    public struct AudioPlan: Sendable {
        public let id: String
        public let title: String
        public let kind: AudioFixtureKind
        public init(id: String, title: String, kind: AudioFixtureKind) { self.id = id; self.title = title; self.kind = kind }
    }

    /// The canonical audio fixtures: a near-silent clip, a 440Hz tone, and a short synthesized-speech clip (all owned).
    public func audioPlans() -> [AudioPlan] {
        [AudioPlan(id: "audio-silence", title: "Sessiz klip", kind: .silence),
         AudioPlan(id: "audio-tone",    title: "Saf ton",     kind: .tone),
         AudioPlan(id: "audio-speech",  title: "Konuşma örneği", kind: .speech)]
    }

    /// §D — generate the audio fixtures into the assets directory (WAV). Returns the ready ReelItemV1s so the audio
    /// evidence provider + player can analyse/play them. `force` regenerates. Best-effort: a fixture that fails to
    /// write is simply omitted (the caller/tests then skip it honestly rather than analyse a missing file).
    public func ensureAudioFixtures(force: Bool = false) async -> [ReelItemV1] {
        let dir = Self.assetsDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var out: [ReelItemV1] = []
        for plan in audioPlans() {
            let url = dir.appendingPathComponent("\(plan.id).wav")
            let exists = FileManager.default.fileExists(atPath: url.path)
            var ok = exists && !force
            if !ok {
                switch plan.kind {
                case .silence: ok = SyntheticAudio.writeTone(frequency: 0, seconds: 2.0, to: url)   // amplitude-zero → silence
                case .tone:    ok = SyntheticAudio.writeTone(frequency: 440, seconds: 2.0, to: url)
                case .speech:  ok = await SyntheticAudio.writeSpeech("merhaba dünya this is a short test",
                                                                     language: "en-US", to: url)
                }
            }
            if ok { out.append(ReelItemV1(id: plan.id, title: plan.title, url: url)) }
        }
        return out
    }

    /// The directory the generated reels live in (Caches — regenerable, not backed up, honestly ephemeral).
    public static func assetsDirectory() -> URL {
        let base = (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Gen8/reels", isDirectory: true)
    }

    /// Generate all reels into the assets directory (idempotent: skips files that already exist and decode). Returns
    /// the ready `ReelItemV1`s for the player model. `force` regenerates even if present (tests use this).
    public func ensureReels(force: Bool = false) async -> [ReelItemV1] {
        let dir = Self.assetsDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var out: [ReelItemV1] = []
        for plan in plans() {
            let url = dir.appendingPathComponent("\(plan.id).mp4")
            let exists = FileManager.default.fileExists(atPath: url.path)
            if force || !exists {
                _ = await SyntheticVideo.write(plan.spec, to: url)
            }
            out.append(ReelItemV1(id: plan.id, title: plan.title, url: url))
        }
        return out
    }
}
#endif
