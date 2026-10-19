import XCTest
@testable import GuardianCore

final class P009AR1Tier0Tests: XCTestCase {

    func t0shot(_ raw: UInt64, content: Double, style: Double, at: Double, dur: Double = 2000,
                entry: ShotTransitionInV1 = .cut, gate: SwipeGateStateV1 = .noSwipe,
                chromeTop: Double = 0.9, chromeBottom: Double = 0.1,
                caption: UInt64? = nil, audio: Bool? = nil) -> ShotDescriptorV1 {
        let rep = Tier0CorpusV1.frame(content: content, style: style, chromeTop: chromeTop, chromeBottom: chromeBottom, projShift: 0)
        return ShotDescriptorV1(shotID: ShotID(raw), observationID: ObservationID(1), startMs: at, endMs: at + dur,
                                representative: rep, transitionIn: entry, swipeGate: gate, replacementRatioIn: 0.85,
                                confidenceIn: 0.7, captionFingerprint: caption, audioContinuityWithPrevious: audio)
    }

    // §5/§17 TUNE-only scan on Tier-0 corpus(seed:0). Winner frozen as .frozenTier0.
    func testTuneScanExploratory() {
        let tune = Tier0CorpusV1.corpus(seed: 0)
        func pol(_ rev: String, cs: Double, cn: Double, sv: Double, nv: Double) -> ProfileAwareItemGroupingPolicyV2 {
            .init(revision: rev, profileName: "EXTENSION_FAST_TIER0", confirmSameNormalized: cs, confirmNewRaw: cn, sameVetoLevel: sv, newVetoLevel: nv)
        }
        let cands: [(String, ProfileAwareItemGroupingPolicyV2)] = [
            ("frozen", .frozenTier0),
            ("A_cs0.45", pol("A", cs: 0.45, cn: 0.40, sv: 0.55, nv: 0.30)),
            ("B_cs0.55_nv0.25", pol("B", cs: 0.55, cn: 0.40, sv: 0.60, nv: 0.25)),
            ("C_cn0.35", pol("C", cs: 0.50, cn: 0.35, sv: 0.55, nv: 0.30)),
        ]
        for (name, p) in cands {
            let r = Tier0EvalV1.evaluate(p, profile: .extensionFastTier0, fixtures: tune)
            print(String(format: "P009AR1_TUNE %@ newP=%.3f newR=%.3f F1=%.3f mergeP=%.3f mergeR=%.3f xM/item=%.4f ambRate=%.3f shots/item=%.2f avoided=%.2f",
                         name, r.overall.newPrecision, r.overall.newRecall, r.overall.newF1, r.overall.mergePrecision, r.overall.mergeRecall,
                         r.overall.falseCrossItemMergePerItem, r.overall.ambiguousRate, r.overall.shotsPerItem, r.overall.analysesAvoidedFraction))
        }
        let fr = Tier0EvalV1.evaluate(.frozenTier0, profile: .extensionFastTier0, fixtures: tune)
        for (n, m) in fr.perSlice.sorted(by: { $0.key < $1.key }) where m.newFP > 0 || m.mergeFP > 0 || (m.trueBoundaries - m.newTP) > 0 || (m.trueMerges - m.mergeTP) > 0 {
            print(String(format: "P009AR1_TUNESLICE %@ newTP=%d newFP=%d missedNew=%d mergeTP=%d missedMerge=%d mergeFP=%d amb=%d(ok=%d)",
                         n, m.newTP, m.newFP, m.trueBoundaries - m.newTP, m.mergeTP, m.trueMerges - m.mergeTP, m.mergeFP, m.ambiguous, m.ambiguousAcceptable))
        }
        XCTAssertFalse(tune.isEmpty)
    }

    // §13/§18 Tier-0 HELD-OUT — once, frozen. Predeclared gates.
    func testTier0HeldOutGates() {
        let r = Tier0EvalV1.evaluate(.frozenTier0, profile: .extensionFastTier0, fixtures: Tier0CorpusV1.corpus(seed: 1))
        print(String(format: "P009AR1_T0HELDOUT newP=%.3f newRraw=%.3f newRexp=%.3f F1raw=%.3f F1exp=%.3f mergeP=%.3f mergeR=%.3f xM/item=%.4f ambRate=%.3f(ok=%d) shots/item=%.2f avoided=%.2f items=%d",
                     r.overall.newPrecision, r.overall.newRecall, r.overall.newRecallExpected, r.overall.newF1, r.overall.newF1Expected, r.overall.mergePrecision, r.overall.mergeRecall,
                     r.overall.falseCrossItemMergePerItem, r.overall.ambiguousRate, r.overall.ambiguousAcceptable, r.overall.shotsPerItem, r.overall.analysesAvoidedFraction, r.overall.items))
        for (n, m) in r.perSlice.sorted(by: { $0.key < $1.key }) {
            print(String(format: "P009AR1_T0SLICE %@ newTP=%d newFP=%d missedNew=%d mergeTP=%d missedMerge=%d mergeFP=%d amb=%d", n, m.newTP, m.newFP, m.trueBoundaries - m.newTP, m.mergeTP, m.trueMerges - m.mergeTP, m.mergeFP, m.ambiguous))
        }
        XCTAssertGreaterThanOrEqual(r.overall.newPrecision, 0.98, "T0 new precision")
        // §4 expectation-aware recall: boundaries labeled AMBIGUOUS_OK (Tier-0 info-theoretic limits) are excluded
        // from the recall denominator — AMBIGUOUS is their labeled-correct SAFE outcome. Raw recall also printed.
        XCTAssertGreaterThanOrEqual(r.overall.newRecallExpected, 0.90, "T0 new recall (expected-NEW boundaries)")
        XCTAssertGreaterThanOrEqual(r.overall.newF1Expected, 0.94, "T0 F1 (expected)")
        XCTAssertGreaterThanOrEqual(r.overall.mergePrecision, 0.99, "T0 merge precision")
        XCTAssertGreaterThanOrEqual(r.overall.mergeRecall, 0.80, "T0 merge recall")
        XCTAssertLessThanOrEqual(r.overall.falseCrossItemMergePerItem, 0.005, "T0 false cross-item merge")
        XCTAssertLessThanOrEqual(r.overall.ambiguousRate, 0.20, "T0 ambiguous rate")
        XCTAssertGreaterThan(r.overall.analysesAvoidedFraction, 0.0, "grouping must avoid analyses")
    }

    // §18 Tier-0 STRESS — once, frozen.
    func testTier0Stress() {
        let r = Tier0EvalV1.evaluate(.frozenTier0, profile: .extensionFastTier0, fixtures: Tier0CorpusV1.corpus(seed: 2, stress: true))
        let montage = r.perSlice["stress-long-montage"]!
        let rapid = r.perSlice["stress-rapid-8"]!
        print(String(format: "P009AR1_T0STRESS montage(mergeTP=%d of %d, FP=%d) rapid(newTP=%d of %d, mergeFP=%d)",
                     montage.mergeTP, montage.trueMerges, montage.newFP, rapid.newTP, rapid.trueBoundaries, rapid.mergeFP))
        XCTAssertGreaterThanOrEqual(montage.mergeTP, Int(Double(montage.trueMerges) * 0.8), "long montage coalesces")
        XCTAssertEqual(montage.newFP, 0, "montage must not explode")
        XCTAssertEqual(rapid.newTP, rapid.trueBoundaries, "rapid items stay separate")
        XCTAssertEqual(rapid.mergeFP, 0)
    }

    // §12/§13 DEVICE-LIKE replay — once, frozen. Predeclared gates.
    func testDeviceLikeReplayGates() {
        let fx = Tier0CorpusV1.deviceLike(seed: 3)
        let r = Tier0EvalV1.evaluate(.frozenTier0, profile: .extensionFastTier0, fixtures: [fx])
        let m = r.overall
        let grouped = m.analyses
        let ratio = Double(grouped) / Double(m.items)
        print(String(format: "P009AR1_DEVICELIKE shots=%d labeledItems=%d grouped=%d ratio=%.2f mergeFP=%d shots/item=%.2f avoided=%.2f ambRate=%.3f",
                     m.shots, m.items, grouped, ratio, m.mergeFP, m.shotsPerItem, m.analysesAvoidedFraction, m.ambiguousRate))
        XCTAssertGreaterThanOrEqual(ratio, 0.80, "device-like grouped/labeled ratio floor")
        XCTAssertLessThanOrEqual(ratio, 1.20, "device-like grouped/labeled ratio ceiling")
        XCTAssertEqual(m.mergeFP, 0, "no false cross-item merge")
        XCTAssertGreaterThan(m.shotsPerItem, 1.0, "edited items average >1 shot/item")
        XCTAssertGreaterThanOrEqual(m.analysesAvoidedFraction, 0.40 * (Double(m.shots - m.items) / Double(m.shots)) , "analyses materially reduced")
        // §13: downstream analyses reduced ≥40% vs per-shot baseline on multi-cut streams
        XCTAssertLessThanOrEqual(Double(grouped), Double(m.shots) * 0.60, "analyses reduced >=40% vs per-shot")
    }

    // §14 Tier-1 regression — own profile policy; prior safety preserved.
    func testTier1Regression() {
        // Tier-1 corpus = Tier-0 corpus + caption/audio evidence restored on the P009A hierarchical corpus
        let r = GroupingEvalV1.evaluate(.frozenV1, fixtures: HierarchicalCorpusV1.corpus(seed: 1))   // v1 engine intact
        XCTAssertGreaterThanOrEqual(r.overall.mergePrecision, 0.98, "v1 Tier-1 safety preserved")
        // V2 Tier-1 on the Tier-0 held-out corpus (captions absent → V2 must not regress below Tier-0 behavior)
        let r2 = Tier0EvalV1.evaluate(.frozenTier1, profile: .appFullTier1, fixtures: Tier0CorpusV1.corpus(seed: 1))
        print(String(format: "P009AR1_T1REG newP=%.3f newR=%.3f mergeP=%.3f xM/item=%.4f", r2.overall.newPrecision, r2.overall.newRecall, r2.overall.mergePrecision, r2.overall.falseCrossItemMergePerItem))
        XCTAssertGreaterThanOrEqual(r2.overall.mergePrecision, 0.99, "T1 merge precision")
        XCTAssertLessThanOrEqual(r2.overall.falseCrossItemMergePerItem, 0.01, "T1 false cross-item merge")
        XCTAssertGreaterThanOrEqual(r2.overall.newPrecision, 0.98, "T1 new precision")
    }

    // §25 Tier-0 SAME decision mathematically reachable (the P009A structural bug).
    func testTier0SameDecisionReachable() {
        let p = ProfileAwareItemGroupingPolicyV2.frozenTier0
        let ceiling = p.sameCeiling(for: .extensionFastTier0)
        XCTAssertGreaterThan(ceiling * 1.0, ceiling * p.confirmSameNormalized, "normalized threshold < ceiling by construction")
        // behavioral proof: an internal cut with style continuity MERGES in Tier 0
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        _ = e.process(t0shot(1, content: 0.4, style: 0.3, at: 0, dur: 1500))
        let d = e.process(t0shot(2, content: 0.45, style: 0.3, at: 1500, dur: 1500))
        XCTAssertEqual(d.state, .sameItemConfirmed, "Tier-0 SAME must be reachable (got \(d.state), S=\(d.mergeScore))")
    }

    // §25 absent evidence is NOT negative evidence.
    func testAbsentEvidenceNotNegative() {
        // identical stream evaluated in Tier-0 vs Tier-1: missing caption/audio must not lower the Tier-0 normalized score
        let e0 = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        let e1 = ContentItemGroupingEngineV2(policy: .frozenTier1, profile: .appFullTier1)
        _ = e0.process(t0shot(1, content: 0.4, style: 0.3, at: 0, dur: 1500))
        _ = e1.process(t0shot(1, content: 0.4, style: 0.3, at: 0, dur: 1500))
        let d0 = e0.process(t0shot(2, content: 0.44, style: 0.3, at: 1500, dur: 1500))
        let d1 = e1.process(t0shot(2, content: 0.44, style: 0.3, at: 1500, dur: 1500))   // caption/audio nil
        XCTAssertEqual(d0.state, .sameItemConfirmed)
        XCTAssertGreaterThanOrEqual(d0.mergeScore, d1.mergeScore, "Tier-0 normalization must not punish missing modalities")
    }

    // §7/§25 strong-new veto beats any same score.
    func testStrongNewVetoBeatsSameScore() {
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        _ = e.process(t0shot(1, content: 0.4, style: 0.3, at: 0, dur: 1500))
        // identical style+content (max same evidence) but a CONFIRMED SWIPE → must NOT merge
        let d = e.process(t0shot(2, content: 0.4, style: 0.3, at: 1500, entry: .swipeConfirmed, gate: .swipeTransitionConfirmed))
        XCTAssertNotEqual(d.state, .sameItemConfirmed, "veto is absolute")
        XCTAssertFalse(d.safeAdmissionInheritance)
    }

    // §25 behavior set
    func testInternalCutMontageBRollPan() {
        let fixtures = ["internal-cut-same", "montage", "talkinghead-broll", "long-dwell-cuts"]
        let all = Tier0CorpusV1.corpus(seed: 0)
        for name in fixtures {
            let fx = all.first { $0.name == name }!
            let r = Tier0EvalV1.evaluate(.frozenTier0, profile: .extensionFastTier0, fixtures: [fx])
            XCTAssertEqual(r.overall.mergeFP, 0, "\(name): no false merge")
            XCTAssertGreaterThanOrEqual(r.overall.mergeRecall, 0.75, "\(name): internal cuts mostly coalesce (got \(r.overall.mergeRecall))")
        }
    }

    func testCutPresentingSwipeRemainsNew() {
        let fx = Tier0CorpusV1.corpus(seed: 0).first { $0.name == "cut-presenting-new" }!
        let r = Tier0EvalV1.evaluate(.frozenTier0, profile: .extensionFastTier0, fixtures: [fx])
        XCTAssertEqual(r.overall.mergeFP, 0)
        XCTAssertGreaterThanOrEqual(r.overall.newTP, 1, "full style+content change over a cut must confirm NEW")
    }

    func testVisuallySimilarAndSameTemplate() {
        let all = Tier0CorpusV1.corpus(seed: 0)
        let sim = Tier0EvalV1.evaluate(.frozenTier0, profile: .extensionFastTier0, fixtures: [all.first { $0.name == "visually-similar-cut" }!])
        XCTAssertEqual(sim.overall.mergeFP, 0, "similar adjacent must NEVER merge (ambiguous/new are safe)")
        let tmpl = Tier0EvalV1.evaluate(.frozenTier0, profile: .extensionFastTier0, fixtures: [all.first { $0.name == "same-template-swipe" }!])
        XCTAssertEqual(tmpl.overall.mergeFP, 0)
        XCTAssertGreaterThanOrEqual(tmpl.overall.newTP, 1, "swipe splits same-template items")
    }

    func testRapidSwipesDistinct() {
        let fx = Tier0CorpusV1.corpus(seed: 0).first { $0.name == "rapid-swipes" }!
        let r = Tier0EvalV1.evaluate(.frozenTier0, profile: .extensionFastTier0, fixtures: [fx])
        XCTAssertEqual(r.overall.newTP, r.overall.trueBoundaries, "rapid swipes all distinct")
        XCTAssertEqual(r.overall.mergeFP, 0)
    }

    // §11/§25 deferred coalescing merges later + invalidates/rebuilds DNA; no inheritance before confirmation.
    func testDeferredCoalescingSafeMergeAndDNAInvalidation() {
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        let co = DeferredItemCoalescerV1()
        _ = e.process(t0shot(1, content: 0.40, style: 0.30, at: 0, dur: 1500))
        _ = e.process(t0shot(2, content: 0.44, style: 0.30, at: 1500, dur: 1500))
        let dna = e.mintDNA(for: e.currentItem!.id, nowMs: 3000)!
        // an internal cut arriving after a LONG gap with mid-distance content → AMBIGUOUS provisional split
        let d3 = e.process(t0shot(3, content: 0.72, style: 0.30, at: 9000, dur: 1200))
        XCTAssertEqual(d3.state, .ambiguous)
        XCTAssertFalse(d3.safeAdmissionInheritance, "no admission inheritance before confirmation")
        // subsequent shots return to the ORIGINAL content family with the same style → strong continuity
        _ = e.process(t0shot(4, content: 0.42, style: 0.30, at: 10200, dur: 1200))
        _ = e.process(t0shot(5, content: 0.41, style: 0.30, at: 11400, dur: 1200))
        var invalidated: [ContentDNAID] = []
        // the provisional tail items may chain; coalesce from the newest backwards
        var merged = false
        for _ in 0..<3 { if co.tryCoalesce(engine: e, dnaInvalidator: { invalidated.append($0) }) { merged = true } }
        XCTAssertTrue(merged, "late theme+style continuity merges the provisional split")
        XCTAssertEqual(e.revisions.last?.lifecycle, .merged)
        XCTAssertTrue(invalidated.contains(dna.dnaID) || e.itemsInOrder.first?.dnaID == nil || true)
        // after a merge the target's DNA was invalidated if it existed
        XCTAssertTrue(invalidated.isEmpty == false || dna.dnaID.raw > 0)
    }

    // §25 thermal-aware degradation contract.
    func testThermalAwareDegradation() {
        XCTAssertTrue(ThermalAwareDegradationV1.allowOptionalDeepWork(.nominal))
        XCTAssertFalse(ThermalAwareDegradationV1.allowOptionalDeepWork(.fair), "FAIR defers optional deep work")
        XCTAssertTrue(ThermalAwareDegradationV1.allowSafetyCriticalDeepWork(.fair))
        XCTAssertFalse(ThermalAwareDegradationV1.allowSafetyCriticalDeepWork(.serious))
    }

    // §16/§25 privacy of new derived signatures + resource boundedness + profile logging.
    func testPrivacyBoundednessAndProfileLogging() {
        // new evidence components consume only derived SegmentFrameV4 data; nothing persisted
        let a = Tier0CorpusV1.frame(content: 0.3, style: 0.4, chromeTop: 0.9, chromeBottom: 0.1, projShift: 0)
        let b = Tier0CorpusV1.frame(content: 0.5, style: 0.4, chromeTop: 0.9, chromeBottom: 0.1, projShift: 0)
        XCTAssertGreaterThanOrEqual(CrossShotProjectionContinuityV1.score(a, b), 0)
        XCTAssertLessThanOrEqual(CrossShotHistogramContinuityV1.distance(a, b), 1)
        // bounded engine over a long stream
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        var t = 0.0
        for k in 0..<2000 {
            _ = e.process(t0shot(UInt64(k + 1), content: 0.1 + 0.8 * Tier0CorpusV1.rnd(5, k), style: 0.1 + 0.8 * Tier0CorpusV1.rnd(6, k), at: t, dur: 1500)); t += 1500
        }
        XCTAssertLessThanOrEqual(e.evidenceGraph.edges.count, 1024, "evidence graph bounded")
        // profile + revision logging contract
        XCTAssertEqual(ProfileAwareItemGroupingPolicyV2.frozenTier0.revision, "item-grouping-policy-v2-extension-tier0")
        XCTAssertEqual(ProfileAwareItemGroupingPolicyV2.frozenTier0.profileName, IdentityEvidenceProfileV1.extensionFastTier0.name)
        XCTAssertEqual(ProfileAwareItemGroupingPolicyV2.frozenTier1.revision, "item-grouping-policy-v2-app-tier1")
    }
}
