import Foundation

// MARK: - PROMPT 009A-R1 §4/§12 — Tier-0 rights-clear corpus + device-like replay.
// 100% project-generated descriptor streams. NO captions, NO speech/audio, NO app identity, NO cloud labels —
// exactly the evidence the broadcast extension possesses. Realism model: an edited item keeps its PRODUCTION STYLE
// across internal cuts (color grade → histogram; layout → projections; feed chrome), while the CONTENT signature
// (center region) changes — which is why the shot sensor fires. Different items change style AND content.
// STYLE and CONTENT are therefore decoupled in the builder (the P009A corpus tied them together — part of why the
// Tier-1 lab gate transferred nothing to Tier-0).

public enum Tier0ExpectationV1: String, Sendable { case same = "SAME", new = "NEW", ambiguousOK = "AMBIGUOUS_OK" }

public struct Tier0LabeledShotV1: Sendable {
    public let descriptor: ShotDescriptorV1
    public let trueItemIndex: Int
    public let expected: Tier0ExpectationV1          // expected SAFE decision at this boundary (§4 label)
}
public struct Tier0FixtureV1: Sendable {
    public let name: String
    public let shots: [Tier0LabeledShotV1]
    public var trueItemCount: Int { (shots.map { $0.trueItemIndex }.max() ?? -1) + 1 }
}

public enum Tier0CorpusV1 {
    static func rnd(_ a: Int, _ b: Int) -> Double { SegmentFrameFactoryV4.rnd(a, b) }

    /// Build one SegmentFrameV4 with DECOUPLED style/content. style → histogram + projections + edges/chrome;
    /// content → center/global signatures. All derived; nothing reconstructable.
    static func frame(content: Double, style: Double, chromeTop: Double, chromeBottom: Double, projShift: Int) -> SegmentFrameV4 {
        func clamp(_ v: Double) -> Double { max(0.02, min(0.98, v)) }
        let cv = clamp(content), sv = clamp(style)
        let regions = MultiRegionSignature(
            global: BoundarySignatureFactory.thermo(clamp(0.6 * cv + 0.4 * sv)),
            center: BoundarySignatureFactory.thermo(cv),
            top: BoundarySignatureFactory.thermo(chromeTop), bottom: BoundarySignatureFactory.thermo(chromeBottom),
            left: BoundarySignatureFactory.thermo(sv), right: BoundarySignatureFactory.thermo(sv),
            lumaHistogram: SegmentFrameFactoryV4.smoothHist(sv))
        return SegmentFrameV4(regions: regions,
                              rowProjection: SegmentFrameFactoryV4.projection(base: sv, bins: 8, shift: projShift),
                              colProjection: SegmentFrameFactoryV4.projection(base: sv * 0.7 + 0.1, bins: 8, shift: projShift))
    }

    struct ItemSpec {
        var contentBase: Double                  // per-item content family
        var contentSpread: Double = 0.08         // internal-cut content variation (montage → large)
        var style: Double                        // production style — constant within an item
        var chromeTop: Double = 0.9, chromeBottom: Double = 0.1
        var shots: Int = 1
        var entry: ShotTransitionInV1 = .cut     // device reality: most item boundaries present as CUT
        var entryGate: SwipeGateStateV1 = .noSwipe
        var shotGapMs: Double = 1500             // internal cadence
        var lastDwellMs: Double = 5000           // dwell on the final shot (user watches, then moves on)
        var expectedEntry: Tier0ExpectationV1 = .new
        var expectedInternal: Tier0ExpectationV1 = .same
    }

    static func build(_ name: String, _ items: [ItemSpec], seed: Int) -> Tier0FixtureV1 {
        var shots: [Tier0LabeledShotV1] = []
        var t = 0.0; var raw: UInt64 = 0
        for (ii, item) in items.enumerated() {
            for k in 0..<item.shots {
                raw += 1
                let jitter = item.contentSpread * (2 * rnd(seed * 37 + ii, k) - 1)
                let rep = frame(content: item.contentBase + jitter, style: item.style,
                                chromeTop: item.chromeTop, chromeBottom: item.chromeBottom, projShift: ii * 3)
                let isFirst = k == 0
                let dur = (k == item.shots - 1) ? item.lastDwellMs : item.shotGapMs
                let d = ShotDescriptorV1(shotID: ShotID(raw), observationID: ObservationID(UInt64(seed)),
                                         startMs: t, endMs: t + dur, representative: rep,
                                         transitionIn: (ii == 0 && isFirst) ? .sessionStart : (isFirst ? item.entry : .cut),
                                         swipeGate: isFirst ? item.entryGate : .noSwipe,
                                         replacementRatioIn: 0.85, confidenceIn: 0.7,
                                         captionFingerprint: nil, audioContinuityWithPrevious: nil)   // TIER-0: none
                shots.append(Tier0LabeledShotV1(descriptor: d, trueItemIndex: ii,
                                                expected: isFirst ? item.expectedEntry : item.expectedInternal))
                t += dur
            }
        }
        return Tier0FixtureV1(name: name, shots: shots)
    }

    /// The 24 §4 scenarios (Tier-0 evidence only). `seed` shifts content/style families.
    public static func corpus(seed: Int, stress: Bool = false) -> [Tier0FixtureV1] {
        let s = Double(seed) * 0.04
        func v(_ x: Double) -> Double { max(0.05, min(0.95, x + s)) }
        var out: [Tier0FixtureV1] = []
        // 1 internal abrupt cut same item
        out.append(build("internal-cut-same", [ItemSpec(contentBase: v(0.4), style: v(0.3), shots: 4)], seed: seed))
        // 2 talking-head → B-roll (alternating content clusters, one style)
        out.append(build("talkinghead-broll", [ItemSpec(contentBase: v(0.4), contentSpread: 0.25, style: v(0.35), shots: 6, shotGapMs: 2000)], seed: seed))
        // 3 montage (wild content, constant style)
        out.append(build("montage", [ItemSpec(contentBase: v(0.5), contentSpread: 0.35, style: v(0.5), shots: 8, shotGapMs: 900)], seed: seed))
        // 4 slideshow (distinct stills, same style/chrome, slow cadence)
        out.append(build("slideshow", [ItemSpec(contentBase: v(0.45), contentSpread: 0.3, style: v(0.4), shots: 5, shotGapMs: 2600)], seed: seed))
        // 5 music-video fast cuts
        out.append(build("music-video", [ItemSpec(contentBase: v(0.55), contentSpread: 0.35, style: v(0.6), shots: 10, shotGapMs: 600)], seed: seed))
        // 6 sport/high-motion internal cuts
        out.append(build("sport-internal-cuts", [ItemSpec(contentBase: v(0.5), contentSpread: 0.2, style: v(0.45), shots: 4, shotGapMs: 2400)], seed: seed))
        // 7 panning same item (sensor-level: one long shot) then a real new item
        out.append(build("pan-then-new", [ItemSpec(contentBase: v(0.25), style: v(0.3), shots: 1, lastDwellMs: 9000),
                                          ItemSpec(contentBase: v(0.8), style: v(0.75), shots: 1)], seed: seed))
        // 8 same-theme internal cut (content stays close)
        out.append(build("same-theme-internal", [ItemSpec(contentBase: v(0.4), contentSpread: 0.05, style: v(0.35), shots: 4)], seed: seed))
        // 9 same-template DIFFERENT items after swipe (style close, content differs, swipe present)
        out.append(build("same-template-swipe", [
            ItemSpec(contentBase: v(0.3), style: v(0.5), shots: 2),
            ItemSpec(contentBase: v(0.75), style: v(0.52), shots: 2, entry: .swipeConfirmed, entryGate: .swipeTransitionConfirmed)], seed: seed))
        // 10 visually similar DIFFERENT item as plain cut — Tier-0 info-theoretic limit → AMBIGUOUS is the SAFE label
        out.append(build("visually-similar-cut", [
            ItemSpec(contentBase: v(0.45), style: v(0.5), shots: 2),
            ItemSpec(contentBase: v(0.78), style: v(0.52), shots: 2, entry: .cut, expectedEntry: .ambiguousOK)], seed: seed))
        // 11 different item presented as plain CUT (style+content both change, long dwell before)
        out.append(build("cut-presenting-new", [
            ItemSpec(contentBase: v(0.3), style: v(0.25), shots: 2),
            ItemSpec(contentBase: v(0.8), style: v(0.8), shots: 2, entry: .cut)], seed: seed))
        // 12 rapid swipes (distinct items, short dwell, swipe gate present)
        do {
            var rapid: [ItemSpec] = []
            for i in 0..<4 {
                let cb: Double = v(0.1 + 0.25 * Double(i))
                let st: Double = v(0.15 + 0.22 * Double(i))
                let e: ShotTransitionInV1 = i == 0 ? .cut : .swipeConfirmed
                let g: SwipeGateStateV1 = i == 0 ? .noSwipe : .swipeTransitionConfirmed
                rapid.append(ItemSpec(contentBase: cb, style: st, shots: 1, entry: e, entryGate: g, lastDwellMs: 850))
            }
            out.append(build("rapid-swipes", rapid, seed: seed))
        }
        // 13 slow swipe
        out.append(build("slow-swipe", [ItemSpec(contentBase: v(0.3), style: v(0.3), shots: 1, lastDwellMs: 12000),
                                        ItemSpec(contentBase: v(0.75), style: v(0.7), shots: 1, entry: .swipeConfirmed, entryGate: .swipeTransitionConfirmed)], seed: seed))
        // 14 crossfade new item
        out.append(build("crossfade-new", [ItemSpec(contentBase: v(0.25), style: v(0.3), shots: 2),
                                           ItemSpec(contentBase: v(0.7), style: v(0.72), shots: 2, entry: .crossfade)], seed: seed))
        // 15 persistent chrome (identical chrome; items differ in style+content via cut-presenting boundaries)
        out.append(build("persistent-chrome", [
            ItemSpec(contentBase: v(0.2), style: v(0.25), shots: 2),
            ItemSpec(contentBase: v(0.65), style: v(0.7), shots: 2, entry: .cut),
            ItemSpec(contentBase: v(0.9), style: v(0.35), shots: 1, entry: .cut)], seed: seed))
        // 16 overlay = sensor-level non-boundary → long single-shot item then new
        out.append(build("overlay-within", [ItemSpec(contentBase: v(0.5), style: v(0.45), shots: 1, lastDwellMs: 8000),
                                            ItemSpec(contentBase: v(0.15), style: v(0.8), shots: 1, entry: .cut)], seed: seed))
        // 17 repeated/reposted item (same families reappear — cache scenario; occurrence labeled NEW)
        out.append(build("repeated-item", [ItemSpec(contentBase: v(0.3), style: v(0.3), shots: 2),
                                           ItemSpec(contentBase: v(0.8), style: v(0.78), shots: 1, entry: .cut),
                                           ItemSpec(contentBase: v(0.3), style: v(0.3), shots: 2, entry: .cut)], seed: seed))
        // 18 app/surface transition (chrome changes completely)
        out.append(build("app-surface", [ItemSpec(contentBase: v(0.4), style: v(0.4), shots: 2),
                                         ItemSpec(contentBase: v(0.5), style: v(0.5), chromeTop: 0.3, chromeBottom: 0.7, shots: 2, entry: .appSurface)], seed: seed))
        // 19 long-dwell same item WITH cuts (internal cuts at slow cadence; content family tight → theme anchors)
        out.append(build("long-dwell-cuts", [ItemSpec(contentBase: v(0.35), contentSpread: 0.06, style: v(0.3), shots: 4, shotGapMs: 5000)], seed: seed))
        // 20 short-dwell different items (cut-presenting, full style+content change)
        out.append(build("short-dwell-new", [ItemSpec(contentBase: v(0.2), style: v(0.2), shots: 1, lastDwellMs: 1500),
                                             ItemSpec(contentBase: v(0.7), style: v(0.75), shots: 1, entry: .cut, lastDwellMs: 1500),
                                             ItemSpec(contentBase: v(0.45), style: v(0.1), shots: 1, entry: .cut, lastDwellMs: 1500)], seed: seed))
        // 21 low-motion internal cut
        out.append(build("low-motion-internal", [ItemSpec(contentBase: v(0.3), contentSpread: 0.04, style: v(0.35), shots: 3, shotGapMs: 2800)], seed: seed))
        // 22 bright-to-bright different items
        out.append(build("bright-to-bright", [ItemSpec(contentBase: v(0.8), style: v(0.85), shots: 1),
                                              ItemSpec(contentBase: v(0.6), style: v(0.8), shots: 1, entry: .cut, expectedEntry: .ambiguousOK)], seed: seed))
        // 23 dark-to-dark different items
        out.append(build("dark-to-dark", [ItemSpec(contentBase: v(0.1), style: v(0.12), shots: 1),
                                          ItemSpec(contentBase: v(0.3), style: v(0.14), shots: 1, entry: .cut, expectedEntry: .ambiguousOK)], seed: seed))
        // 24 ambiguous identity (style close, content mid-distance, cut, no cross-modal evidence)
        out.append(build("ambiguous-identity", [ItemSpec(contentBase: v(0.45), contentSpread: 0.02, style: v(0.5), shots: 2, shotGapMs: 2000, lastDwellMs: 2000),
                                                ItemSpec(contentBase: v(0.77), contentSpread: 0.02, style: v(0.52), shots: 2, entry: .cut, shotGapMs: 2000, lastDwellMs: 2000, expectedEntry: .ambiguousOK)], seed: seed))
        if stress {
            out.append(build("stress-long-montage", [ItemSpec(contentBase: v(0.5), contentSpread: 0.38, style: v(0.5), shots: 24, shotGapMs: 700)], seed: seed))
            var r8: [ItemSpec] = []
            for i in 0..<8 {
                let cb: Double = v(0.08 + 0.12 * Double(i))
                let st: Double = v(0.1 + 0.11 * Double(i))
                let e: ShotTransitionInV1 = i == 0 ? .cut : .swipeConfirmed
                let g: SwipeGateStateV1 = i == 0 ? .noSwipe : .swipeTransitionConfirmed
                r8.append(ItemSpec(contentBase: cb, style: st, shots: 1, entry: e, entryGate: g, lastDwellMs: 800))
            }
            out.append(build("stress-rapid-8", r8, seed: seed))
        }
        return out
    }

    /// §12 DEVICE-LIKE replay — statistical shape from the REAL P009A log only (no content recreated):
    /// ~1.6–1.7 s shot cadence · item boundaries overwhelmingly CUT-presenting (65 CUT / 6 CROSSFADE / 1 SWIPE of 72) ·
    /// several multi-cut edited Reels · a rapid-swipe burst · one app switch. ~20 items.
    public static func deviceLike(seed: Int) -> Tier0FixtureV1 {
        let s = Double(seed) * 0.03
        func v(_ x: Double) -> Double { max(0.05, min(0.95, x + s)) }
        var items: [ItemSpec] = []
        var contentWalk = 0.1, styleWalk = 0.15
        func nextFamily(_ i: Int) -> (Double, Double) {
            var c = v(0.08 + rnd(seed * 11, i) * 0.85)
            // distinct feed items: ≥0.15 apart; rapid-swiped items (user skipping) are typically UNRELATED → ≥0.30
            let minSep = (12...15).contains(i) ? 0.30 : 0.15
            if abs(c - contentWalk) < minSep { c = v(c + (c < contentWalk ? -minSep - 0.1 : minSep + 0.1)) }
            contentWalk = c
            styleWalk = v(0.08 + rnd(seed * 13, i + 50) * 0.85)
            return (contentWalk, styleWalk)
        }
        for i in 0..<20 {
            let (c, st) = nextFamily(i)
            let multiCut = [2, 5, 8, 11, 14, 16].contains(i)                 // several edited multi-cut Reels
            let rapid = (12...14).contains(i)                                 // rapid-swipe burst
            let entry: ShotTransitionInV1 = i == 0 ? .cut : (i == 6 ? .crossfade : (i == 13 ? .swipeConfirmed : (i == 17 ? .appSurface : .cut)))
            items.append(ItemSpec(contentBase: c, contentSpread: multiCut ? 0.3 : 0.06, style: st,
                                  chromeTop: i == 17 ? 0.3 : 0.9, chromeBottom: i == 17 ? 0.7 : 0.1,
                                  shots: multiCut ? 2 + Int(rnd(seed, i) * 3.99) : 1,
                                  entry: entry, entryGate: entry == .swipeConfirmed ? .swipeTransitionConfirmed : .noSwipe,
                                  shotGapMs: 1400 + rnd(seed, i + 100) * 600,                  // ≈1.4–2.0 s internal cadence
                                  lastDwellMs: rapid ? 900 : 4200 + rnd(seed, i + 200) * 2600,
                                  expectedEntry: .new))
        }
        return build("device-like", items, seed: seed)
    }
}

// MARK: - §18 eval for V2 (expectation-aware; split/merge asymmetry reported).

public struct Tier0MetricsV1: Sendable {
    public var newTP = 0, newTPExpected = 0, newFP = 0, mergeTP = 0, mergeFP = 0
    public var ambiguous = 0, ambiguousAcceptable = 0
    public var trueBoundaries = 0, trueBoundariesExpectedNew = 0, trueMerges = 0, items = 0, shots = 0, analyses = 0
    public var newPrecision: Double { newTP + newFP > 0 ? Double(newTP)/Double(newTP+newFP) : 1 }
    public var newRecall: Double { trueBoundaries > 0 ? Double(newTP)/Double(trueBoundaries) : 1 }
    /// Recall over boundaries whose §4 expected SAFE decision is NEW (ambiguousOK boundaries excluded from the
    /// denominator — AMBIGUOUS is their labeled-correct outcome; they still count for precision & false-merge).
    public var newRecallExpected: Double { trueBoundariesExpectedNew > 0 ? Double(newTPExpected)/Double(trueBoundariesExpectedNew) : 1 }
    public var newF1: Double { newPrecision + newRecall > 0 ? 2*newPrecision*newRecall/(newPrecision+newRecall) : 0 }
    public var newF1Expected: Double { newPrecision + newRecallExpected > 0 ? 2*newPrecision*newRecallExpected/(newPrecision+newRecallExpected) : 0 }
    public var mergePrecision: Double { mergeTP + mergeFP > 0 ? Double(mergeTP)/Double(mergeTP+mergeFP) : 1 }
    public var mergeRecall: Double { trueMerges > 0 ? Double(mergeTP)/Double(trueMerges) : 1 }
    public var falseCrossItemMergePerItem: Double { items > 0 ? Double(mergeFP)/Double(items) : 0 }
    public var ambiguousRate: Double { (trueBoundaries + trueMerges) > 0 ? Double(ambiguous)/Double(trueBoundaries+trueMerges) : 0 }
    public var shotsPerItem: Double { items > 0 ? Double(shots)/Double(items) : 0 }
    public var analysesAvoidedFraction: Double { shots > 0 ? Double(shots - analyses)/Double(shots) : 0 }
}

public enum Tier0EvalV1 {
    public static func evaluate(_ policy: ProfileAwareItemGroupingPolicyV2, profile: IdentityEvidenceProfileV1,
                                fixtures: [Tier0FixtureV1], coalesce: Bool = true)
        -> (overall: Tier0MetricsV1, perSlice: [String: Tier0MetricsV1]) {
        var overall = Tier0MetricsV1(); var perSlice: [String: Tier0MetricsV1] = [:]
        for fx in fixtures {
            let engine = ContentItemGroupingEngineV2(policy: policy, profile: profile)
            let coalescer = DeferredItemCoalescerV1(themeContinuityMax: policy.themeContinuityMax,
                                                    projectionContinuityMin: policy.projectionContinuityMin)
            var m = Tier0MetricsV1()
            var prevItem = -1
            var decisions: [(truthNew: Bool, state: ItemGroupingStateV1, expected: Tier0ExpectationV1)] = []
            for (i, l) in fx.shots.enumerated() {
                let d = engine.process(l.descriptor)
                if coalesce { _ = coalescer.tryCoalesce(engine: engine, dnaInvalidator: { _ in }) }
                if i > 0 { decisions.append((l.trueItemIndex != prevItem, d.state, l.expected)) }
                prevItem = l.trueItemIndex
            }
            for (truthNew, state, expected) in decisions {
                if truthNew { m.trueBoundaries += 1; if expected == .new { m.trueBoundariesExpectedNew += 1 } } else { m.trueMerges += 1 }
                switch state {
                case .newItemConfirmed:
                    if truthNew { m.newTP += 1; if expected == .new { m.newTPExpected += 1 } } else { m.newFP += 1 }
                case .sameItemConfirmed: truthNew ? (m.mergeFP += 1) : (m.mergeTP += 1)
                case .ambiguous:
                    m.ambiguous += 1
                    if expected == .ambiguousOK { m.ambiguousAcceptable += 1 }
                default: break
                }
            }
            // deferred coalescing can repair ambiguous internal splits after the fact → count repaired merges
            m.items = fx.trueItemCount; m.shots = fx.shots.count
            m.analyses = engine.confirmedOrProvisionalItemCount
            perSlice[fx.name] = m
            overall.newTP += m.newTP; overall.newTPExpected += m.newTPExpected; overall.newFP += m.newFP; overall.mergeTP += m.mergeTP; overall.mergeFP += m.mergeFP
            overall.ambiguous += m.ambiguous; overall.ambiguousAcceptable += m.ambiguousAcceptable
            overall.trueBoundaries += m.trueBoundaries; overall.trueBoundariesExpectedNew += m.trueBoundariesExpectedNew; overall.trueMerges += m.trueMerges
            overall.items += m.items; overall.shots += m.shots; overall.analyses += m.analyses
        }
        return (overall, perSlice)
    }
}
