import Foundation

// MARK: - Owned rights-clear boundary fixture harness (PROMPT 008A-R2 §3,§11,§12,§13) — DETERMINISTIC, generated.
// All material is project-generated (no third-party clips). Each slice has exact labeled true-boundary frames.
// TUNE and HELD-OUT use different seeds (different derivatives) → no leakage by source clip.

public enum BoundarySignatureFactory {
    /// Thermometer code: value 0..1 → lowest round(v*64) bits set. hamming(a,b) ≈ |va-vb|*64 → controllable distances.
    public static func thermo(_ v: Double) -> UInt64 {
        let k = max(0, min(64, Int(((v.isFinite ? v : 0) * 64).rounded())))
        return k >= 64 ? ~UInt64(0) : (k == 0 ? 0 : (UInt64(1) << UInt64(k)) - 1)
    }
    public static func hist(center v: Double) -> [Int] {
        var h = [0,0,0,0]; h[max(0, min(3, Int(v * 4)))] = 64; return h
    }
    public static func sig(center: Double, top: Double, bottom: Double, left: Double, right: Double, global: Double) -> MultiRegionSignature {
        MultiRegionSignature(global: thermo(global), center: thermo(center), top: thermo(top), bottom: thermo(bottom),
                             left: thermo(left), right: thermo(right), lumaHistogram: hist(center: center))
    }
}

public struct BoundaryFixture: Sendable {
    public let name: String
    public let frames: [MultiRegionSignature]
    public let trueBoundaries: [Bool]   // frame is the first frame of a NEW distinct item
}

public enum BoundaryFixtureGenerator {
    /// Build one fixture from a list of items; each item = (centerBase, perFrameCenterDrift, top, bottom, frames).
    /// Optional overlays: at (frame, region, delta) apply a local change WITHIN an item (NOT a boundary).
    static func build(_ name: String, items: [(c: Double, drift: Double, top: Double, bottom: Double, n: Int)],
                      edgesStatic: Double = 0.5, globalFollowsCenter: Bool = true,
                      overlays: [(frame: Int, bottom: Double)] = []) -> BoundaryFixture {
        var frames: [MultiRegionSignature] = []; var bnd: [Bool] = []
        var f = 0
        for (idx, it) in items.enumerated() {
            for k in 0..<it.n {
                var c = it.c + Double(k) * it.drift
                c = max(0, min(1, c))
                var bottom = it.bottom
                if let ov = overlays.first(where: { $0.frame == f }) { bottom = ov.bottom }
                let g = globalFollowsCenter ? (0.5*c + 0.25*it.top + 0.25*bottom) : 0.5
                frames.append(BoundarySignatureFactory.sig(center: c, top: it.top, bottom: bottom, left: edgesStatic, right: edgesStatic, global: g))
                bnd.append(k == 0 && idx >= 0)   // first frame of each item = a true boundary (incl. the first item)
                f += 1
            }
        }
        return BoundaryFixture(name: name, frames: frames, trueBoundaries: bnd)
    }

    /// The 18 labeled slices (§3). `seed` shifts content values so TUNE (seed 0) and HELD-OUT (seed 1) differ.
    public static func corpus(seed: Int) -> [BoundaryFixture] {
        let s = Double(seed) * 0.07   // small deterministic offset per split (different derivatives, same structure)
        func c(_ v: Double) -> Double { max(0.02, min(0.98, v + s)) }
        var out: [BoundaryFixture] = []

        // 1 static cards (distinct center per item, ~0 motion)
        out.append(build("static-cards", items: [(c(0.15),0,0.5,0.5,5),(c(0.55),0,0.5,0.5,5),(c(0.9),0,0.5,0.5,5)]))
        // 2 talking-head (small motion)
        out.append(build("talking-head", items: [(c(0.3),0.01,0.5,0.5,8),(c(0.75),0.01,0.5,0.5,8)]))
        // 3 high-motion sport (LARGE within-item motion, NO cut mid-item) — must NOT false-boundary
        out.append(build("high-motion-sport", items: [(c(0.1),0.10,0.5,0.5,10),(c(0.85),0.10,0.5,0.5,10)]))
        // 4 panning landscape (steady coherent drift)
        out.append(build("panning-landscape", items: [(c(0.2),0.05,0.5,0.5,10),(c(0.8),0.05,0.5,0.5,10)]))
        // 5 subtitles appear/disappear (bottom overlay within item)
        out.append(build("subtitles", items: [(c(0.4),0.01,0.5,0.4,10)], overlays: [(3,0.7),(4,0.7),(7,0.4)]))
        // 6 comments overlay (bottom change, same content)
        out.append(build("comments-overlay", items: [(c(0.5),0.01,0.5,0.4,10)], overlays: [(5,0.85),(6,0.85),(7,0.85)]))
        // 7 menu/keyboard overlay (bottom big, single region)
        out.append(build("menu-overlay", items: [(c(0.6),0.0,0.5,0.3,10)], overlays: [(4,0.95),(5,0.95),(6,0.95),(7,0.95)]))
        // 8 autoplay transition (clean new item)
        out.append(build("autoplay-transition", items: [(c(0.2),0.01,0.5,0.5,6),(c(0.7),0.01,0.5,0.5,6)]))
        // 9 ad-like transition (big histogram/brightness shift)
        out.append(build("ad-transition", items: [(c(0.15),0.0,0.5,0.5,6),(c(0.95),0.0,0.6,0.6,6)]))
        // 10 rapid 3-item swipe (short dwell)
        out.append(build("rapid-3-swipe", items: [(c(0.1),0.0,0.5,0.5,3),(c(0.55),0.0,0.5,0.5,3),(c(0.95),0.0,0.5,0.5,3)]))
        // 11 slow swipe (long dwell)
        out.append(build("slow-swipe", items: [(c(0.2),0.005,0.5,0.5,14),(c(0.8),0.005,0.5,0.5,14)]))
        // 12 repeated SAME item (visually identical → NOT a new visual boundary) — relabel second start as non-boundary
        do {
            var fx = build("repeated-same", items: [(c(0.5),0.0,0.5,0.5,6),(c(0.5),0.0,0.5,0.5,6)])
            var b = fx.trueBoundaries; if b.count > 6 { b[6] = false }   // identical repeat is not a detectable visual boundary
            out.append(BoundaryFixture(name: fx.name, frames: fx.frames, trueBoundaries: b)); _ = fx
        }
        // 13 same visual theme, different items (moderate center change)
        out.append(build("same-theme", items: [(c(0.40),0.005,0.5,0.5,8),(c(0.58),0.005,0.5,0.5,8),(c(0.76),0.005,0.5,0.5,8)]))
        // 14 dark-to-dark transition (both low luma, center pattern differs)
        out.append(build("dark-to-dark", items: [(c(0.08),0.0,0.15,0.15,6),(c(0.22),0.0,0.15,0.15,6)]))
        // 15 bright-to-bright transition
        out.append(build("bright-to-bright", items: [(c(0.8),0.0,0.85,0.85,6),(c(0.95),0.0,0.85,0.85,6)]))
        // 16 persistent chrome (top/bottom IDENTICAL across items; only center changes)
        out.append(build("persistent-chrome", items: [(c(0.2),0.01,0.9,0.1,8),(c(0.75),0.01,0.9,0.1,8),(c(0.45),0.01,0.9,0.1,8)]))
        // 17 center-only content (edges static; content lives in center)
        out.append(build("center-only", items: [(c(0.25),0.02,0.5,0.5,8),(c(0.85),0.02,0.5,0.5,8)], edgesStatic: 0.5, globalFollowsCenter: false))
        // 18 partial-screen media (content in center, moderate)
        out.append(build("partial-screen", items: [(c(0.35),0.01,0.4,0.6,8),(c(0.7),0.01,0.4,0.6,8)]))
        return out
    }
}

public struct BoundaryMetrics: Sendable, Equatable {
    public var truePositives = 0, falsePositives = 0, falseNegatives = 0, duplicateCommits = 0, committed = 0, trueBoundaries = 0
    public var precision: Double { truePositives + falsePositives > 0 ? Double(truePositives) / Double(truePositives + falsePositives) : 0 }
    public var recall: Double { truePositives + falseNegatives > 0 ? Double(truePositives) / Double(truePositives + falseNegatives) : 0 }
    public var f1: Double { precision + recall > 0 ? 2*precision*recall/(precision+recall) : 0 }
    public var duplicatePerItem: Double { trueBoundaries > 0 ? Double(duplicateCommits) / Double(trueBoundaries) : 0 }
}

public enum BoundaryEvalV3 {
    /// Run the accumulator over a fixture; greedily match committed NEW to labeled boundaries within ±tolerance frames.
    public static func evaluate(_ policy: ContentBoundaryPolicyV3, fixtures: [BoundaryFixture], tolerance: Int = 3) -> (overall: BoundaryMetrics, perSlice: [String: BoundaryMetrics]) {
        var overall = BoundaryMetrics(); var perSlice: [String: BoundaryMetrics] = [:]
        for fx in fixtures {
            let acc = BoundaryEvidenceAccumulatorV3(policy: policy)
            var committedAt: [Int] = []
            for (i, s) in fx.frames.enumerated() { if acc.process(s).committedNew { committedAt.append(i) } }
            let truth = fx.trueBoundaries.enumerated().compactMap { $0.element ? $0.offset : nil }
            var m = BoundaryMetrics(); m.committed = committedAt.count; m.trueBoundaries = truth.count
            var matchedTruth = Set<Int>(); var matchedByTruth: [Int: Int] = [:]
            for c in committedAt {
                if let t = truth.first(where: { abs($0 - c) <= tolerance && (matchedByTruth[$0] == nil) }) {
                    m.truePositives += 1; matchedTruth.insert(t); matchedByTruth[t] = c
                } else if truth.contains(where: { abs($0 - c) <= tolerance }) {
                    m.duplicateCommits += 1   // extra commit near an already-matched true boundary
                } else {
                    m.falsePositives += 1
                }
            }
            m.falseNegatives = truth.count - matchedTruth.count
            perSlice[fx.name] = m
            overall.truePositives += m.truePositives; overall.falsePositives += m.falsePositives
            overall.falseNegatives += m.falseNegatives; overall.duplicateCommits += m.duplicateCommits
            overall.committed += m.committed; overall.trueBoundaries += m.trueBoundaries
        }
        return (overall, perSlice)
    }
}
