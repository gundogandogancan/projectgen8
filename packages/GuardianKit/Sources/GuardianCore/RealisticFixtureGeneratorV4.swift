import Foundation

// MARK: - PROMPT 008A-R3 §15/§16 — owned, rights-clear synthetic fixtures parameterized by the REAL
// device motion profile (DeviceMotionProfileV1). Reproduces only STATISTICAL motion characteristics — never
// any real user content. Deterministic. TUNE / HELD-OUT / STRESS splits with no source-seed leakage.

public enum SegmentFrameFactoryV4 {
    // Deterministic bounded pseudo-random in [0,1) from integer coordinates (no Date/Math.random).
    static func rnd(_ a: Int, _ b: Int) -> Double {
        var x = UInt64(bitPattern: Int64(a &* 73856093 ^ b &* 19349663 ^ 0x9E3779B9))
        x ^= x >> 33; x = x &* 0xff51afd7ed558ccd; x ^= x >> 33
        return Double(x % 100000) / 100000.0
    }
    /// Smooth 4-bin luma histogram (realistic): weight spread with a Gaussian kernel around v, so small luma
    /// changes produce small histogram changes (a single-bucket spike would swing wildly on tiny motion).
    static func smoothHist(_ v: Double) -> [Int] {
        let centerPos = max(0, min(3, v * 4 - 0.5))
        var w = [Double](repeating: 0, count: 4); var tot = 0.0
        for i in 0..<4 { let d = Double(i) - centerPos; let g = exp(-(d*d) / (2 * 0.8 * 0.8)); w[i] = g; tot += g }
        return w.map { Int(($0 / max(1e-6, tot)) * 64) }
    }
    /// A structural projection pattern that IDENTIFIES a segment (used by the coherent-translation cue).
    static func projection(base: Double, bins: Int, shift: Int) -> [Double] {
        let freq = 1.0 + base * 3.0
        return (0..<bins).map { i in
            let t = Double((i + shift) % bins) / Double(bins)
            return 0.5 + 0.4 * sin(2 * Double.pi * t * freq + base * 6.28318)
        }
    }
    /// Full-frame content model: center/global (and edges/top/bottom UNLESS pinned as chrome) all move with
    /// `base + motionOffset`, matching real feed video where the whole content area moves. `chromeTop/Bottom/Edge`
    /// when non-nil pin a UI region (persistent chrome / overlay). This produces realistic (undiluted) motion energy.
    public static func frame(base: Double, motionOffset: Double, chromeTop: Double?, chromeBottom: Double?,
                             chromeEdge: Double?, bins: Int, shift: Int) -> SegmentFrameV4 {
        func clamp(_ v: Double) -> Double { max(0.02, min(0.98, v)) }
        let cv = clamp(base + motionOffset)
        let tv = chromeTop ?? cv, bv = chromeBottom ?? cv, ev = chromeEdge ?? cv
        let g = clamp(0.5 * cv + 0.25 * tv + 0.25 * bv)
        let regions = MultiRegionSignature(global: BoundarySignatureFactory.thermo(g),
                                           center: BoundarySignatureFactory.thermo(cv),
                                           top: BoundarySignatureFactory.thermo(tv),
                                           bottom: BoundarySignatureFactory.thermo(bv),
                                           left: BoundarySignatureFactory.thermo(ev),
                                           right: BoundarySignatureFactory.thermo(ev),
                                           lumaHistogram: smoothHist(cv))
        return SegmentFrameV4(regions: regions,
                              rowProjection: projection(base: base, bins: bins, shift: shift),
                              colProjection: projection(base: base * 0.7 + 0.1, bins: bins, shift: shift))
    }
}

public enum TransitionKindV4: Sendable { case start, cut, swipe, crossfade, sameRepeat }

public struct SegmentSpecV4: Sendable {
    public let base: Double          // segment visual identity (0..1)
    public let amp: Double           // within-segment motion amplitude (per-frame offset bound)
    public let n: Int                // frames
    public let top: Double?          // nil = content region (moves with base); value = pinned UI chrome
    public let bottom: Double?
    public let edge: Double?
    public let entry: TransitionKindV4
    public init(base: Double, amp: Double, n: Int, top: Double? = nil, bottom: Double? = nil, edge: Double? = nil, entry: TransitionKindV4) {
        self.base = base; self.amp = amp; self.n = n; self.top = top; self.bottom = bottom; self.edge = edge; self.entry = entry
    }
}

public struct SegmentFixtureV4: Sendable {
    public let name: String
    public let frames: [SegmentFrameV4]
    public let trueBoundaries: [Bool]   // first frame of a NEW distinct segment
    public let overlayFrames: Set<Int>  // frames carrying a transient overlay (not a boundary)
}

public enum RealisticFixtureGeneratorV4 {
    static let bins = 16

    /// Build a fixture from segment specs. Within a segment, the center oscillates around `base` with
    /// bounded amplitude `amp` (realistic sustained motion). Entry kind controls how the new segment's
    /// structural projection relates to the previous one (swipe = coherent translation; cut = independent).
    public static func build(_ name: String, _ specs: [SegmentSpecV4], seed: Int,
                             overlays: [(seg: Int, frame: Int, bottom: Double)] = []) -> SegmentFixtureV4 {
        var frames: [SegmentFrameV4] = []; var bnd: [Bool] = []; var overlaySet = Set<Int>()
        var fIndex = 0
        var prevBase = specs.first?.base ?? 0.5
        var prevShift = 0
        for (si, spec) in specs.enumerated() {
            let shift: Int
            switch spec.entry {
            case .swipe: shift = prevShift + 5                 // coherent translation of structure
            case .sameRepeat: shift = prevShift                // identical structure
            default: shift = (si * 7) % bins                   // cut/crossfade/start → independent structure
            }
            for k in 0..<spec.n {
                // bounded oscillation around base (persistent mean = base) with per-frame jitter
                let r = SegmentFrameFactoryV4.rnd(seed * 1009 + si, k)
                var motion = spec.amp * (2 * r - 1)
                // crossfade: first 2 frames interpolate from the previous base (gradual, accumulates)
                var baseK = spec.base
                if spec.entry == .crossfade && k < 2 {
                    let mix = Double(k + 1) / 3.0
                    baseK = prevBase * (1 - mix) + spec.base * mix
                }
                var bottom = spec.bottom
                if let ov = overlays.first(where: { $0.seg == si && $0.frame == k }) { bottom = ov.bottom; overlaySet.insert(fIndex) }
                // overlays must not move the center
                if overlaySet.contains(fIndex) { motion = spec.amp * (2 * SegmentFrameFactoryV4.rnd(seed, k) - 1) * 0.2 }
                frames.append(SegmentFrameFactoryV4.frame(base: baseK, motionOffset: motion, chromeTop: spec.top,
                                                          chromeBottom: bottom, chromeEdge: spec.edge, bins: bins, shift: shift))
                // true boundary = first frame of a NEW distinct segment (not the very first, not an identical repeat)
                bnd.append(k == 0 && si > 0 && spec.entry != .sameRepeat)
                fIndex += 1
            }
            prevBase = spec.base; prevShift = shift
        }
        return SegmentFixtureV4(name: name, frames: frames, trueBoundaries: bnd, overlayFrames: overlaySet)
    }

    /// The labeled corpus. `seed` selects the split (0=TUNE, 1=HELD-OUT). `stress` inflates motion beyond
    /// observed real ranges and adds pathological rapid-swipe / very-long-high-motion slices (§16).
    public static func corpus(seed: Int, stress: Bool = false) -> [SegmentFixtureV4] {
        let p = DeviceMotionProfileV1.bootstrapV0
        let s = Double(seed) * 0.05
        func b(_ v: Double) -> Double { max(0.05, min(0.95, v + s)) }
        // realistic amplitudes from the profile (stress multiplies them up beyond observed)
        let m = stress ? 1.6 : 1.0
        // realistic within-item motion amplitudes so per-frame motion energy matches the profile
        // (sameItem median ≈ 0.123, high-motion p95 ≈ 0.257). Full-frame motion ⇒ realized energy ≈ amplitude.
        let lowAmp = 0.05 * m, midAmp = p.sameItemMotionMedian * 1.15 * m, highAmp = p.sameItemMotionP95 * 1.0 * m
        let gap = p.transitionDistanceMedian   // ~0.37 realistic inter-segment identity gap
        var out: [SegmentFixtureV4] = []

        out.append(build("low-motion-static", [
            .init(base: b(0.2), amp: lowAmp, n: 8, entry: .start),
            .init(base: b(0.2 + gap), amp: lowAmp, n: 8, entry: .cut),
            .init(base: b(0.2), amp: lowAmp, n: 8, entry: .cut)], seed: seed))
        out.append(build("talking-head", [
            .init(base: b(0.3), amp: midAmp, n: 10, entry: .start),
            .init(base: b(0.3 + gap), amp: midAmp, n: 10, entry: .cut)], seed: seed))
        // high-motion sport: LARGE sustained motion, NO cut mid-segment → must not false-boundary
        out.append(build("high-motion-sport", [
            .init(base: b(0.5), amp: highAmp, n: 22, entry: .start),
            .init(base: b(0.5 - gap), amp: highAmp, n: 22, entry: .cut)], seed: seed))
        out.append(build("panning-landscape", [
            .init(base: b(0.25), amp: midAmp * 1.3, n: 14, entry: .start),
            .init(base: b(0.25 + gap), amp: midAmp * 1.3, n: 14, entry: .cut)], seed: seed))
        out.append(build("subtitles", [.init(base: b(0.4), amp: midAmp, n: 12, bottom: 0.4, entry: .start)], seed: seed,
                         overlays: [(0,3,0.75),(0,4,0.75),(0,8,0.4)]))
        out.append(build("comments-overlay", [.init(base: b(0.5), amp: midAmp, n: 12, bottom: 0.4, entry: .start)], seed: seed,
                         overlays: [(0,5,0.9),(0,6,0.9),(0,7,0.9)]))
        out.append(build("menu-overlay", [.init(base: b(0.6), amp: lowAmp, n: 12, bottom: 0.3, entry: .start)], seed: seed,
                         overlays: [(0,4,0.97),(0,5,0.97),(0,6,0.97),(0,7,0.97)]))
        out.append(build("autoplay-crossfade", [
            .init(base: b(0.2), amp: midAmp, n: 8, entry: .start),
            .init(base: b(0.2 + gap), amp: midAmp, n: 8, entry: .crossfade)], seed: seed))
        out.append(build("ad-transition", [
            .init(base: b(0.15), amp: midAmp, n: 7, top: 0.5, bottom: 0.5, entry: .start),
            .init(base: b(0.9), amp: midAmp, n: 7, top: 0.7, bottom: 0.7, entry: .cut)], seed: seed))
        out.append(build("rapid-3-swipe", [
            .init(base: b(0.15), amp: midAmp, n: 4, entry: .start),
            .init(base: b(0.15 + gap), amp: midAmp, n: 4, entry: .swipe),
            .init(base: b(0.15 + 2*0.28), amp: midAmp, n: 4, entry: .swipe)], seed: seed))
        out.append(build("slow-swipe", [
            .init(base: b(0.25), amp: midAmp, n: 16, entry: .start),
            .init(base: b(0.25 + gap), amp: midAmp, n: 16, entry: .swipe)], seed: seed))
        out.append(build("repeated-same", [
            .init(base: b(0.5), amp: midAmp, n: 7, entry: .start),
            .init(base: b(0.5), amp: midAmp, n: 7, entry: .sameRepeat)], seed: seed))
        // same-theme adjacent items: smaller identity gap (harder)
        out.append(build("same-theme", [
            .init(base: b(0.4), amp: midAmp, n: 10, entry: .start),
            .init(base: b(0.4 + max(p.transitionDistanceMin, 0.30)), amp: midAmp, n: 10, entry: .cut),
            .init(base: b(0.4 + 2*0.30), amp: midAmp, n: 10, entry: .cut)], seed: seed))
        out.append(build("dark-to-dark", [
            .init(base: b(0.08), amp: midAmp, n: 8, top: 0.15, bottom: 0.15, entry: .start),
            .init(base: b(0.08 + gap), amp: midAmp, n: 8, top: 0.15, bottom: 0.15, entry: .cut)], seed: seed))
        out.append(build("bright-to-bright", [
            .init(base: b(0.8), amp: midAmp, n: 8, top: 0.85, bottom: 0.85, entry: .start),
            .init(base: b(0.8 - 0.32), amp: midAmp, n: 8, top: 0.85, bottom: 0.85, entry: .cut)], seed: seed))
        // persistent chrome: top/bottom IDENTICAL across segments; only center identity changes
        out.append(build("persistent-chrome", [
            .init(base: b(0.2), amp: midAmp, n: 10, top: 0.9, bottom: 0.1, entry: .start),
            .init(base: b(0.2 + gap), amp: midAmp, n: 10, top: 0.9, bottom: 0.1, entry: .cut),
            .init(base: b(0.2 + 2*0.3), amp: midAmp, n: 10, top: 0.9, bottom: 0.1, entry: .cut)], seed: seed))
        out.append(build("center-only", [
            .init(base: b(0.3), amp: midAmp, n: 10, top: 0.5, bottom: 0.5, entry: .start),
            .init(base: b(0.3 + gap), amp: midAmp, n: 10, top: 0.5, bottom: 0.5, entry: .cut)], seed: seed))
        out.append(build("partial-screen", [
            .init(base: b(0.35), amp: midAmp, n: 10, top: 0.4, bottom: 0.6, entry: .start),
            .init(base: b(0.35 + gap), amp: midAmp, n: 10, top: 0.4, bottom: 0.6, entry: .cut)], seed: seed))

        if stress {
            // §16 STRESS: exceed observed motion + pathological patterns.
            out.append(build("stress-extreme-motion-no-cut", [
                .init(base: b(0.5), amp: min(0.45, highAmp * 1.6), n: 40, entry: .start)], seed: seed))
            out.append(build("stress-rapid-5-swipe", [
                .init(base: b(0.1), amp: highAmp, n: 2, entry: .start),
                .init(base: b(0.1 + gap), amp: highAmp, n: 2, entry: .swipe),
                .init(base: b(0.1 + 2*0.3), amp: highAmp, n: 2, entry: .swipe),
                .init(base: b(0.95 - gap), amp: highAmp, n: 2, entry: .swipe),
                .init(base: b(0.95), amp: highAmp, n: 2, entry: .swipe)], seed: seed))
            out.append(build("stress-long-high-motion", [
                .init(base: b(0.4), amp: min(0.45, highAmp * 1.4), n: 60, entry: .start)], seed: seed))
            out.append(build("stress-dense-overlays", [.init(base: b(0.5), amp: highAmp, n: 16, bottom: 0.4, entry: .start)],
                             seed: seed, overlays: (3...12).map { (0, $0, $0 % 2 == 0 ? 0.95 : 0.4) }))
        }
        return out
    }
}

public struct SegmentMetricsV4: Sendable, Equatable {
    public var truePositives = 0, falsePositives = 0, falseNegatives = 0, duplicateCommits = 0, committed = 0, trueBoundaries = 0
    public var precision: Double { truePositives + falsePositives > 0 ? Double(truePositives)/Double(truePositives + falsePositives) : 1 }
    public var recall: Double { truePositives + falseNegatives > 0 ? Double(truePositives)/Double(truePositives + falseNegatives) : 1 }
    public var f1: Double { precision + recall > 0 ? 2*precision*recall/(precision+recall) : 0 }
    public var duplicatePerItem: Double { trueBoundaries > 0 ? Double(duplicateCommits)/Double(trueBoundaries) : 0 }
    public var falseNewPerItem: Double { trueBoundaries > 0 ? Double(falsePositives)/Double(trueBoundaries) : Double(falsePositives) }
}

public enum SegmentEvalV4 {
    public static func evaluate(_ policy: ContentBoundaryPolicyV4, fixtures: [SegmentFixtureV4], tolerance: Int = 4)
        -> (overall: SegmentMetricsV4, perSlice: [String: SegmentMetricsV4], maxConsecutiveCommitRun: Int,
            realizedSameItemMotionMedian: Double, realizedTransitionDistanceMedian: Double) {
        var overall = SegmentMetricsV4(); var perSlice: [String: SegmentMetricsV4] = [:]
        var maxRun = 0
        var sameItemEnergies: [Double] = []; var transitionDistances: [Double] = []
        for fx in fixtures {
            let acc = BoundaryEvidenceAccumulatorV4(policy: policy)
            var committedAt: [Int] = []; var lastCommit = -100; var run = 0
            let truth = fx.trueBoundaries.enumerated().compactMap { $0.element ? $0.offset : nil }
            for (i, f) in fx.frames.enumerated() {
                let ev = acc.process(f)
                // realized-distribution telemetry for fixture-representativeness proof (§15)
                if i > 0 {
                    if truth.contains(i) { transitionDistances.append(ev.motionEnergy) }       // energy AT the exact cut
                    else if !truth.contains(where: { abs($0 - i) <= 1 }) { sameItemEnergies.append(ev.motionEnergy) }
                }
                if ev.committedNew && i > 0 {   // ignore the mandatory first-frame segment
                    committedAt.append(i)
                    if i - lastCommit <= 2 { run += 1; maxRun = max(maxRun, run) } else { run = 1 }
                    lastCommit = i
                }
            }
            var m = SegmentMetricsV4(); m.committed = committedAt.count; m.trueBoundaries = truth.count
            var matched = Set<Int>()
            for c in committedAt {
                if let t = truth.first(where: { abs($0 - c) <= tolerance && !matched.contains($0) }) {
                    m.truePositives += 1; matched.insert(t)
                } else if truth.contains(where: { abs($0 - c) <= tolerance }) {
                    m.duplicateCommits += 1
                } else { m.falsePositives += 1 }
            }
            m.falseNegatives = truth.count - matched.count
            perSlice[fx.name] = m
            overall.truePositives += m.truePositives; overall.falsePositives += m.falsePositives
            overall.falseNegatives += m.falseNegatives; overall.duplicateCommits += m.duplicateCommits
            overall.committed += m.committed; overall.trueBoundaries += m.trueBoundaries
        }
        func median(_ a: [Double]) -> Double { a.isEmpty ? 0 : a.sorted()[a.count/2] }
        return (overall, perSlice, maxRun, median(sameItemEnergies), median(transitionDistances))
    }
}
