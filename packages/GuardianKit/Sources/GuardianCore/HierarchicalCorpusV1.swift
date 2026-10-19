import Foundation

// MARK: - PROMPT 009A §18/§19 — rights-clear hierarchical eval corpus with EXACT shot + item labels.
// 100% project-generated deterministic descriptor streams (no third-party media; nothing reconstructable).
// Covers the 24 required scenarios. TUNE(seed:0) / HELD-OUT(seed:1) / STRESS(seed:2) — no leakage.

public struct LabeledShotV1: Sendable {
    public let descriptor: ShotDescriptorV1
    public let trueItemIndex: Int                      // exact ItemID label
    public let expectAmbiguousOK: Bool                 // scenario 24: AMBIGUOUS is an acceptable outcome here
}
public struct GroupingFixtureV1: Sendable {
    public let name: String
    public let shots: [LabeledShotV1]
    public var trueItemCount: Int { (shots.map { $0.trueItemIndex }.max() ?? -1) + 1 }
}

public enum HierarchicalCorpusV1 {
    static func rnd(_ a: Int, _ b: Int) -> Double { SegmentFrameFactoryV4.rnd(a, b) }

    /// One synthetic item: theme (visual identity family), caption, audio continuity, chrome, shots with entries.
    struct ItemSpec {
        var theme: Double                               // 0..1 visual family; internal cuts vary around it
        var themeSpread: Double = 0.10                  // internal-cut visual variation (montage → large)
        var caption: UInt64?                            // nil = no caption/no-audio scenarios
        var audioContinuous: Bool? = true               // nil = no audio
        var chromeTop: Double = 0.9
        var chromeBottom: Double = 0.1
        var shots: Int = 1
        var entry: ShotTransitionInV1 = .cut            // transition INTO this item's first shot
        var entrySwipeGate: SwipeGateStateV1 = .noSwipe
        var shotGapMs: Double = 1500                    // internal cut cadence
        var dwellBeforeExitMs: Double = 5000            // last-shot dwell (user watches, then moves on)
        var firstShotAudioBreak = true                  // audio breaks at item boundary by default
        var expectAmbiguous = false
    }

    static func build(_ name: String, _ items: [ItemSpec], seed: Int) -> GroupingFixtureV1 {
        var shots: [LabeledShotV1] = []
        var t = 0.0; var shotRaw: UInt64 = 0
        for (ii, item) in items.enumerated() {
            for k in 0..<item.shots {
                shotRaw += 1
                let jitter = item.themeSpread * (2 * rnd(seed * 31 + ii, k) - 1)
                let rep = SegmentFrameFactoryV4.frame(base: max(0.03, min(0.97, item.theme + jitter)), motionOffset: 0,
                                                      chromeTop: item.chromeTop, chromeBottom: item.chromeBottom,
                                                      chromeEdge: 0.5, bins: 8, shift: ii * 5 + k)
                let isFirst = k == 0
                let dur = isFirst && item.shots == 1 ? item.dwellBeforeExitMs
                        : (k == item.shots - 1 ? item.dwellBeforeExitMs : item.shotGapMs)
                let audio: Bool? = item.audioContinuous == nil ? nil : (isFirst ? (ii == 0 ? true : !item.firstShotAudioBreak) : item.audioContinuous)
                let d = ShotDescriptorV1(shotID: ShotID(shotRaw), observationID: ObservationID(UInt64(seed)),
                                         startMs: t, endMs: t + dur, representative: rep,
                                         transitionIn: ii == 0 && isFirst ? .sessionStart : (isFirst ? item.entry : .cut),
                                         swipeGate: isFirst ? item.entrySwipeGate : .noSwipe,
                                         replacementRatioIn: isFirst ? 0.9 : 0.7, confidenceIn: 0.7,
                                         captionFingerprint: item.caption,
                                         audioContinuityWithPrevious: (ii == 0 && isFirst) ? nil : audio)
                shots.append(LabeledShotV1(descriptor: d, trueItemIndex: ii, expectAmbiguousOK: item.expectAmbiguous && isFirst))
                t += dur
            }
        }
        return GroupingFixtureV1(name: name, shots: shots)
    }

    /// The 24 §18 scenarios. `seed` shifts themes/captions (different derivatives, same structure).
    public static func corpus(seed: Int, stress: Bool = false) -> [GroupingFixtureV1] {
        let s = Double(seed) * 0.04
        func th(_ v: Double) -> Double { max(0.05, min(0.95, v + s)) }
        func cap(_ i: Int) -> UInt64 { UInt64(seed * 1000 + i + 1) }
        let swipe: (Double, Int, Int) -> ItemSpec = { theme, c, n in
            ItemSpec(theme: th(theme), caption: cap(c), shots: n, entry: .swipeConfirmed, entrySwipeGate: .swipeTransitionConfirmed)
        }
        // device reality: many real swipes present as plain CUTs (translation unseen between samples) →
        // boundary must be caught by caption/audio/theme discontinuity + dwell:
        let cutSwipe: (Double, Int, Int) -> ItemSpec = { theme, c, n in
            ItemSpec(theme: th(theme), caption: cap(c), shots: n, entry: .cut)
        }
        var out: [GroupingFixtureV1] = []
        // 1. one item / one shot
        out.append(build("one-shot-one-item", [ItemSpec(theme: th(0.3), caption: cap(0), shots: 1)], seed: seed))
        // 2. one item / many abrupt internal cuts
        out.append(build("multi-cut-one-item", [ItemSpec(theme: th(0.4), caption: cap(1), shots: 6)], seed: seed))
        // 3. montage (large visual spread, same audio/caption)
        out.append(build("montage", [ItemSpec(theme: th(0.5), themeSpread: 0.3, caption: cap(2), shots: 8, shotGapMs: 900)], seed: seed))
        // 4. talking head + B-roll (two alternating visual clusters — spread captures it; same audio)
        out.append(build("talking-head-broll", [ItemSpec(theme: th(0.35), themeSpread: 0.25, caption: cap(3), shots: 6, shotGapMs: 2000)], seed: seed))
        // 5. slideshow (distinct stills, same caption/chrome, no audio)
        out.append(build("slideshow", [ItemSpec(theme: th(0.45), themeSpread: 0.3, caption: cap(4), audioContinuous: nil, shots: 5, shotGapMs: 2500)], seed: seed))
        // 6. music-video fast cuts
        out.append(build("music-video", [ItemSpec(theme: th(0.55), themeSpread: 0.35, caption: cap(5), shots: 10, shotGapMs: 600)], seed: seed))
        // 7. high-motion sport (one item, few shots) then new item
        out.append(build("high-motion-then-new", [ItemSpec(theme: th(0.5), themeSpread: 0.2, caption: cap(6), shots: 3),
                                                  swipe(0.15, 7, 2)], seed: seed))
        // 8. pan within item = sensor-level (no shot boundary) → represented as one long shot + next item
        out.append(build("pan-within-item", [ItemSpec(theme: th(0.25), caption: cap(8), shots: 1, dwellBeforeExitMs: 9000),
                                             swipe(0.7, 9, 1)], seed: seed))
        // 9. same speaker across cuts (audio continuity carries the merge)
        out.append(build("same-speaker-cuts", [ItemSpec(theme: th(0.3), themeSpread: 0.28, caption: nil, shots: 5)], seed: seed))
        // 10. topic-continuous scene changes (caption continuity across visually new scenes)
        out.append(build("topic-continuous-scenes", [ItemSpec(theme: th(0.4), themeSpread: 0.33, caption: cap(10), shots: 6, shotGapMs: 2800)], seed: seed))
        // 11. visually-similar ADJACENT DIFFERENT items (swipe + caption change; themes nearly identical)
        out.append(build("visually-similar-adjacent", [swipe(0.5, 11, 2), swipe(0.53, 12, 2)], seed: seed))
        // 12. same-template adjacent different items (chrome identical, similar theme; cut-presenting swipe)
        out.append(build("same-template-adjacent", [cutSwipe(0.45, 13, 2), cutSwipe(0.5, 14, 2)], seed: seed))
        // 13. repeated/reposted item (same theme+caption reappears later — cache scenario; labeled as a NEW item occurrence)
        out.append(build("repeated-item", [swipe(0.3, 15, 2), swipe(0.8, 16, 1), swipe(0.3, 15, 2)], seed: seed))
        // 14. ad-like item after content (strong theme + caption + chrome change)
        out.append(build("ad-after-content", [ItemSpec(theme: th(0.3), caption: cap(17), shots: 3),
                                              ItemSpec(theme: th(0.9), caption: cap(18), chromeTop: 0.6, chromeBottom: 0.6, shots: 1, entry: .cut)], seed: seed))
        // 15. rapid feed swipes (short dwell, confirmed swipes)
        out.append(build("rapid-swipes", [ItemSpec(theme: th(0.1), caption: cap(19), shots: 1, dwellBeforeExitMs: 900),
                                          ItemSpec(theme: th(0.45), caption: cap(20), shots: 1, entry: .swipeConfirmed, entrySwipeGate: .swipeTransitionConfirmed, dwellBeforeExitMs: 800),
                                          ItemSpec(theme: th(0.75), caption: cap(21), shots: 1, entry: .swipeConfirmed, entrySwipeGate: .swipeTransitionConfirmed, dwellBeforeExitMs: 800),
                                          ItemSpec(theme: th(0.25), caption: cap(22), shots: 1, entry: .swipeConfirmed, entrySwipeGate: .swipeTransitionConfirmed, dwellBeforeExitMs: 900)], seed: seed))
        // 16. slow swipe
        out.append(build("slow-swipe", [ItemSpec(theme: th(0.3), caption: cap(23), shots: 1, dwellBeforeExitMs: 12000), swipe(0.7, 24, 1)], seed: seed))
        // 17. crossfade/autoplay (gradual entry + caption/audio change)
        out.append(build("crossfade-autoplay", [ItemSpec(theme: th(0.25), caption: cap(25), shots: 2),
                                                ItemSpec(theme: th(0.65), caption: cap(26), shots: 2, entry: .crossfade)], seed: seed))
        // 18. persistent chrome (identical chrome; items differ by theme+caption via swipe)
        out.append(build("persistent-chrome-items", [swipe(0.2, 27, 2), swipe(0.6, 28, 2), swipe(0.85, 29, 1)], seed: seed))
        // 19. comments/overlay = sensor-level non-boundary → long single-shot item then new item
        out.append(build("overlay-within-item", [ItemSpec(theme: th(0.5), caption: cap(30), shots: 1, dwellBeforeExitMs: 8000), swipe(0.15, 31, 1)], seed: seed))
        // 20. app/surface transition (chrome changes completely)
        out.append(build("app-surface-transition", [ItemSpec(theme: th(0.4), caption: cap(32), shots: 2),
                                                    ItemSpec(theme: th(0.5), caption: cap(33), chromeTop: 0.3, chromeBottom: 0.7, shots: 2, entry: .appSurface)], seed: seed))
        // 21. no-audio (caption-only continuity)
        out.append(build("no-audio-item", [ItemSpec(theme: th(0.35), themeSpread: 0.25, caption: cap(34), audioContinuous: nil, shots: 4)], seed: seed))
        // 22. caption continuity (visual scene changes, caption constant)
        out.append(build("caption-continuity", [ItemSpec(theme: th(0.3), themeSpread: 0.34, caption: cap(35), shots: 5, shotGapMs: 2600)], seed: seed))
        // 23. caption topic change (cut-presenting swipe caught by caption change + dwell)
        out.append(build("caption-topic-change", [cutSwipe(0.4, 36, 2), cutSwipe(0.47, 37, 2)], seed: seed))
        // 24. ambiguous identity (no caption, no audio, similar theme, cut entry, no dwell signal) → AMBIGUOUS OK
        do {
            var a = ItemSpec(theme: th(0.5), caption: nil, audioContinuous: nil, shots: 2, shotGapMs: 2000, dwellBeforeExitMs: 2000)
            var b = ItemSpec(theme: th(0.56), caption: nil, audioContinuous: nil, shots: 2, entry: .cut, shotGapMs: 2000, dwellBeforeExitMs: 2000)
            a.expectAmbiguous = true; b.expectAmbiguous = true
            out.append(build("ambiguous-identity", [a, b], seed: seed))
        }
        if stress {
            // long montage must NOT explode item count; many rapid distinct items must NOT collapse (§20)
            out.append(build("stress-long-montage", [ItemSpec(theme: th(0.5), themeSpread: 0.36, caption: cap(40), shots: 24, shotGapMs: 700)], seed: seed))
            out.append(build("stress-many-rapid-items", (0..<8).map { i in
                ItemSpec(theme: th(0.1 + 0.11 * Double(i)), caption: cap(41 + i), shots: 1,
                         entry: i == 0 ? .cut : .swipeConfirmed, entrySwipeGate: i == 0 ? .noSwipe : .swipeTransitionConfirmed,
                         dwellBeforeExitMs: 800) }, seed: seed))
        }
        return out
    }
}

// MARK: - §19 metrics: new-item boundary P/R/F1, merge precision/recall, false cross-item merge, efficiency.

public struct GroupingMetricsV1: Sendable {
    public var confirmedNewTP = 0, confirmedNewFP = 0
    public var mergeTP = 0, mergeFP = 0                 // mergeFP = FALSE CROSS-ITEM MERGE (safety-critical)
    public var ambiguous = 0, ambiguousAcceptable = 0
    public var trueBoundaries = 0, trueMerges = 0
    public var items = 0, shots = 0
    public var newPrecision: Double { confirmedNewTP + confirmedNewFP > 0 ? Double(confirmedNewTP)/Double(confirmedNewTP+confirmedNewFP) : 1 }
    public var newRecall: Double { trueBoundaries > 0 ? Double(confirmedNewTP)/Double(trueBoundaries) : 1 }
    public var newF1: Double { newPrecision + newRecall > 0 ? 2*newPrecision*newRecall/(newPrecision+newRecall) : 0 }
    public var mergePrecision: Double { mergeTP + mergeFP > 0 ? Double(mergeTP)/Double(mergeTP+mergeFP) : 1 }
    public var mergeRecall: Double { trueMerges > 0 ? Double(mergeTP)/Double(trueMerges) : 1 }
    public var falseCrossItemMergePerItem: Double { items > 0 ? Double(mergeFP)/Double(items) : 0 }
    public var shotsPerItem: Double { items > 0 ? Double(shots)/Double(items) : 0 }
}

public enum GroupingEvalV1 {
    public static func evaluate(_ policy: ItemGroupingPolicyV1, fixtures: [GroupingFixtureV1],
                                profile: GroupingCapabilityProfileV1 = .appFull)
        -> (overall: GroupingMetricsV1, perSlice: [String: GroupingMetricsV1]) {
        var overall = GroupingMetricsV1(); var perSlice: [String: GroupingMetricsV1] = [:]
        for fx in fixtures {
            let engine = ContentItemGroupingEngineV1(policy: policy, profile: profile)
            var m = GroupingMetricsV1()
            var prevTrueItem = -1
            for (i, labeled) in fx.shots.enumerated() {
                let decision = engine.process(labeled.descriptor)
                guard i > 0 else { prevTrueItem = labeled.trueItemIndex; continue }
                let truthNew = labeled.trueItemIndex != prevTrueItem
                if truthNew { m.trueBoundaries += 1 } else { m.trueMerges += 1 }
                switch decision.state {
                case .newItemConfirmed: truthNew ? (m.confirmedNewTP += 1) : (m.confirmedNewFP += 1)
                case .sameItemConfirmed: truthNew ? (m.mergeFP += 1) : (m.mergeTP += 1)
                case .ambiguous:
                    m.ambiguous += 1
                    if labeled.expectAmbiguousOK { m.ambiguousAcceptable += 1 }
                default: break
                }
                prevTrueItem = labeled.trueItemIndex
            }
            m.items = fx.trueItemCount
            m.shots = fx.shots.count
            perSlice[fx.name] = m
            overall.confirmedNewTP += m.confirmedNewTP; overall.confirmedNewFP += m.confirmedNewFP
            overall.mergeTP += m.mergeTP; overall.mergeFP += m.mergeFP
            overall.ambiguous += m.ambiguous; overall.ambiguousAcceptable += m.ambiguousAcceptable
            overall.trueBoundaries += m.trueBoundaries; overall.trueMerges += m.trueMerges
            overall.items += m.items; overall.shots += m.shots
        }
        return (overall, perSlice)
    }
}
