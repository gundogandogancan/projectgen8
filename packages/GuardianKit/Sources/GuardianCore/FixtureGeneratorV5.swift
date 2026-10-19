import Foundation

// MARK: - PROMPT 008A-R4 §12/§13 — rights-clear fixtures V5, parameterized by DeviceMotionProfileV2, with
// per-frame TIMESTAMPS (cadence) and an explicit CONTINUOUS-PAN slice (smooth evolution, no abrupt step → must
// stay SAME_SEGMENT). Reuses SegmentFrameFactoryV4. 100% project-generated; reproduces only motion statistics.

public enum PanOrCut: Sendable { case start, cut, swipe, crossfade, sameRepeat, panContinue }

public struct SegmentSpecV5: Sendable {
    public let base: Double, amp: Double, drift: Double, n: Int
    public let top: Double?, bottom: Double?, edge: Double?
    public let entry: PanOrCut
    public init(base: Double, amp: Double, n: Int, drift: Double = 0, top: Double? = nil, bottom: Double? = nil, edge: Double? = nil, entry: PanOrCut) {
        self.base = base; self.amp = amp; self.drift = drift; self.n = n; self.top = top; self.bottom = bottom; self.edge = edge; self.entry = entry
    }
}

public struct SegmentFixtureV5: Sendable {
    public let name: String
    public let frames: [SegmentFrameV4]
    public let times: [Double]              // timestampMs per frame
    public let trueBoundaries: [Bool]
}

public enum FixtureGeneratorV5 {
    static let bins = 16

    /// Build a timestamped fixture. `frameIntervalMs` sets nominal cadence; `jitter` adds irregular spacing;
    /// `dropEvery` skips a sample periodically (dropped-frame gap). `drift` makes a segment evolve smoothly
    /// (panning) WITHOUT an abrupt step.
    public static func build(_ name: String, _ specs: [SegmentSpecV5], seed: Int,
                             frameIntervalMs: Double = 33.0, jitter: Double = 0, dropEvery: Int = 0,
                             overlays: [(seg: Int, frame: Int, bottom: Double)] = []) -> SegmentFixtureV5 {
        var frames: [SegmentFrameV4] = []; var times: [Double] = []; var bnd: [Bool] = []
        var t = 0.0; var gIndex = 0; var prevShift = 0
        for (si, spec) in specs.enumerated() {
            let shift: Int
            switch spec.entry {
            case .swipe: shift = prevShift + 5
            case .panContinue, .sameRepeat: shift = prevShift
            default: shift = (si * 7) % bins
            }
            for k in 0..<spec.n {
                let r = SegmentFrameFactoryV4.rnd(seed * 1009 + si, k)
                var motion = spec.amp * (2 * r - 1)
                // continuous evolution (pan): base drifts smoothly across the segment, no jump
                var baseK = spec.base + spec.drift * Double(k)
                if spec.entry == .crossfade && k < 2 {
                    let mix = Double(k + 1) / 3.0; baseK = (specs[max(0,si-1)].base) * (1 - mix) + spec.base * mix
                }
                var bottom = spec.bottom
                var isOverlay = false
                if let ov = overlays.first(where: { $0.seg == si && $0.frame == k }) { bottom = ov.bottom; isOverlay = true; motion = spec.amp * (2*r-1) * 0.2 }
                // drift the projection shift smoothly during a pan so translation is coherent but continuous
                let effShift = spec.entry == .panContinue ? prevShift + Int(Double(k) * 0.6) : shift
                let f = SegmentFrameFactoryV4.frame(base: baseK, motionOffset: motion, chromeTop: spec.top,
                                                    chromeBottom: bottom, chromeEdge: spec.edge, bins: bins, shift: effShift)
                let skip = dropEvery > 0 && gIndex > 0 && gIndex % dropEvery == 0
                if !skip {
                    frames.append(f); times.append(t)
                    bnd.append(k == 0 && si > 0 && spec.entry != .sameRepeat && spec.entry != .panContinue)
                }
                let jit = jitter == 0 ? 0 : frameIntervalMs * jitter * (2 * SegmentFrameFactoryV4.rnd(seed+7, gIndex) - 1)
                t += frameIntervalMs + jit
                gIndex += 1
                _ = isOverlay
            }
            prevShift = (spec.entry == .panContinue) ? prevShift + Int(Double(spec.n) * 0.6) : shift
        }
        return SegmentFixtureV5(name: name, frames: frames, times: times, trueBoundaries: bnd)
    }

    public static func corpus(seed: Int, stress: Bool = false, frameIntervalMs: Double = 33.0, jitter: Double = 0, dropEvery: Int = 0) -> [SegmentFixtureV5] {
        let p = DeviceMotionProfileV2.v2
        let s = Double(seed) * 0.05
        func b(_ v: Double) -> Double { max(0.05, min(0.95, v + s)) }
        let m = stress ? 1.6 : 1.0
        let lowAmp = max(0.03, p.lowMotionMedian) * m, midAmp = 0.14 * m, highAmp = p.highMotionP95 * m
        let gap = p.cutDistanceMedian
        func fx(_ name: String, _ specs: [SegmentSpecV5], ov: [(seg: Int, frame: Int, bottom: Double)] = []) -> SegmentFixtureV5 {
            build(name, specs, seed: seed, frameIntervalMs: frameIntervalMs, jitter: jitter, dropEvery: dropEvery, overlays: ov)
        }
        var out: [SegmentFixtureV5] = []
        out.append(fx("low-motion-static", [.init(base: b(0.2), amp: lowAmp, n: 8, entry: .start), .init(base: b(0.2+gap), amp: lowAmp, n: 8, entry: .cut), .init(base: b(0.2), amp: lowAmp, n: 8, entry: .cut)]))
        out.append(fx("talking-head", [.init(base: b(0.3), amp: midAmp, n: 10, entry: .start), .init(base: b(0.3+gap), amp: midAmp, n: 10, entry: .cut)]))
        out.append(fx("high-motion-sport", [.init(base: b(0.5), amp: highAmp, n: 22, entry: .start), .init(base: b(0.5-gap), amp: highAmp, n: 22, entry: .cut)]))
        // CONTINUOUS PAN — one item, SMOOTH base drift (low per-frame noise, like real camera pan), NO abrupt step.
        out.append(fx("panning-continuous", [.init(base: b(0.2), amp: 0.03, n: 22, drift: 0.028, entry: .start)]))
        out.append(fx("pan-then-cut", [.init(base: b(0.2), amp: 0.03, n: 14, drift: 0.03, entry: .start), .init(base: b(0.9), amp: lowAmp, n: 10, entry: .cut)]))
        out.append(fx("subtitles", [.init(base: b(0.4), amp: midAmp, n: 12, bottom: 0.4, entry: .start)], ov: [(0,3,0.75),(0,4,0.75),(0,8,0.4)]))
        out.append(fx("comments-overlay", [.init(base: b(0.5), amp: midAmp, n: 12, bottom: 0.4, entry: .start)], ov: [(0,5,0.9),(0,6,0.9),(0,7,0.9)]))
        out.append(fx("menu-overlay", [.init(base: b(0.6), amp: lowAmp, n: 12, bottom: 0.3, entry: .start)], ov: [(0,4,0.97),(0,5,0.97),(0,6,0.97),(0,7,0.97)]))
        out.append(fx("autoplay-crossfade", [.init(base: b(0.2), amp: midAmp, n: 8, entry: .start), .init(base: b(0.2+gap), amp: midAmp, n: 10, entry: .crossfade)]))
        out.append(fx("ad-transition", [.init(base: b(0.15), amp: midAmp, n: 7, top: 0.5, bottom: 0.5, entry: .start), .init(base: b(0.9), amp: midAmp, n: 8, top: 0.7, bottom: 0.7, entry: .cut)]))
        out.append(fx("rapid-3-swipe", [.init(base: b(0.15), amp: midAmp, n: 5, entry: .start), .init(base: b(0.15+gap), amp: midAmp, n: 5, entry: .swipe), .init(base: b(0.15+2*0.28), amp: midAmp, n: 5, entry: .swipe)]))
        out.append(fx("slow-swipe", [.init(base: b(0.25), amp: midAmp, n: 16, entry: .start), .init(base: b(0.25+gap), amp: midAmp, n: 16, entry: .swipe)]))
        out.append(fx("repeated-same", [.init(base: b(0.5), amp: midAmp, n: 8, entry: .start), .init(base: b(0.5), amp: midAmp, n: 8, entry: .sameRepeat)]))
        out.append(fx("same-theme", [.init(base: b(0.4), amp: midAmp, n: 10, entry: .start), .init(base: b(0.4+max(0.30, gap*0.85)), amp: midAmp, n: 10, entry: .cut), .init(base: b(0.4+2*0.30), amp: midAmp, n: 10, entry: .cut)]))
        out.append(fx("dark-to-dark", [.init(base: b(0.08), amp: midAmp, n: 8, top: 0.15, bottom: 0.15, entry: .start), .init(base: b(0.08+gap), amp: midAmp, n: 8, top: 0.15, bottom: 0.15, entry: .cut)]))
        out.append(fx("bright-to-bright", [.init(base: b(0.8), amp: midAmp, n: 8, top: 0.85, bottom: 0.85, entry: .start), .init(base: b(0.8-0.32), amp: midAmp, n: 8, top: 0.85, bottom: 0.85, entry: .cut)]))
        out.append(fx("persistent-chrome", [.init(base: b(0.2), amp: midAmp, n: 10, top: 0.9, bottom: 0.1, entry: .start), .init(base: b(0.2+gap), amp: midAmp, n: 10, top: 0.9, bottom: 0.1, entry: .cut), .init(base: b(0.2+2*0.3), amp: midAmp, n: 10, top: 0.9, bottom: 0.1, entry: .cut)]))
        out.append(fx("partial-screen", [.init(base: b(0.35), amp: midAmp, n: 10, top: 0.4, bottom: 0.6, entry: .start), .init(base: b(0.35+gap), amp: midAmp, n: 10, top: 0.4, bottom: 0.6, entry: .cut)]))
        if stress {
            out.append(fx("stress-extreme-motion-no-cut", [.init(base: b(0.5), amp: min(0.45, highAmp*1.6), n: 40, entry: .start)]))
            out.append(fx("stress-long-pan-no-cut", [.init(base: b(0.15), amp: 0.035, n: 50, drift: 0.015, entry: .start)]))
            out.append(fx("stress-long-high-motion", [.init(base: b(0.4), amp: min(0.45, highAmp*1.4), n: 60, entry: .start)]))
            out.append(fx("stress-dense-overlays", [.init(base: b(0.5), amp: highAmp, n: 16, bottom: 0.4, entry: .start)], ov: (3...12).map { (0, $0, $0 % 2 == 0 ? 0.95 : 0.4) }))
        }
        return out
    }
}

public struct SegmentMetricsV5: Sendable, Equatable {
    public var truePositives = 0, falsePositives = 0, falseNegatives = 0, duplicateCommits = 0, committed = 0, trueBoundaries = 0
    public var precision: Double { truePositives + falsePositives > 0 ? Double(truePositives)/Double(truePositives+falsePositives) : 1 }
    public var recall: Double { truePositives + falseNegatives > 0 ? Double(truePositives)/Double(truePositives+falseNegatives) : 1 }
    public var f1: Double { precision + recall > 0 ? 2*precision*recall/(precision+recall) : 0 }
    public var duplicatePerItem: Double { trueBoundaries > 0 ? Double(duplicateCommits)/Double(trueBoundaries) : 0 }
    public var falseNewPerItem: Double { trueBoundaries > 0 ? Double(falsePositives)/Double(trueBoundaries) : Double(falsePositives) }
}

public enum SegmentEvalV5 {
    public static func evaluate(_ policy: ContentBoundaryPolicyV5, fixtures: [SegmentFixtureV5], tolerance: Int = 7)
        -> (overall: SegmentMetricsV5, perSlice: [String: SegmentMetricsV5], maxRun: Int, totalCommitted: Int) {
        var overall = SegmentMetricsV5(); var perSlice: [String: SegmentMetricsV5] = [:]; var maxRun = 0; var total = 0
        for fx in fixtures {
            let acc = BoundaryEvidenceAccumulatorV5(policy: policy)
            var committedAt: [Int] = []; var lastC = -100; var run = 0
            for (i, f) in fx.frames.enumerated() {
                let ev = acc.process(f, timestampMs: fx.times[i])
                if ev.committedNew && i > 0 {
                    committedAt.append(i); total += 1
                    if i - lastC <= 3 { run += 1; maxRun = max(maxRun, run) } else { run = 1 }
                    lastC = i
                }
            }
            let truth = fx.trueBoundaries.enumerated().compactMap { $0.element ? $0.offset : nil }
            var m = SegmentMetricsV5(); m.committed = committedAt.count; m.trueBoundaries = truth.count
            var matched = Set<Int>()
            for c in committedAt {
                if let t = truth.first(where: { abs($0 - c) <= tolerance && !matched.contains($0) }) { m.truePositives += 1; matched.insert(t) }
                else if truth.contains(where: { abs($0 - c) <= tolerance }) { m.duplicateCommits += 1 }
                else { m.falsePositives += 1 }
            }
            m.falseNegatives = truth.count - matched.count
            perSlice[fx.name] = m
            overall.truePositives += m.truePositives; overall.falsePositives += m.falsePositives
            overall.falseNegatives += m.falseNegatives; overall.duplicateCommits += m.duplicateCommits
            overall.committed += m.committed; overall.trueBoundaries += m.trueBoundaries
        }
        return (overall, perSlice, maxRun, total)
    }
}
