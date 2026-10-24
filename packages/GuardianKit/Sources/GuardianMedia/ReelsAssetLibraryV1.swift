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
                                           sceneChanges: [(0.0, 0.90), (2.5, 0.40), (4.5, 0.70)]))
        ]
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
