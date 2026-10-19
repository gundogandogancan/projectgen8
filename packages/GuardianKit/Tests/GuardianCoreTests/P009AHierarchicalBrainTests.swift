import XCTest
@testable import GuardianCore

final class P009AHierarchicalBrainTests: XCTestCase {

    // MARK: helpers
    func shot(_ raw: UInt64, item ii: Int = 0, theme: Double, at: Double, dur: Double = 3000,
              entry: ShotTransitionInV1 = .cut, gate: SwipeGateStateV1 = .noSwipe,
              caption: UInt64? = nil, audio: Bool? = nil, chromeTop: Double = 0.9, chromeBottom: Double = 0.1) -> ShotDescriptorV1 {
        let rep = SegmentFrameFactoryV4.frame(base: theme, motionOffset: 0, chromeTop: chromeTop, chromeBottom: chromeBottom, chromeEdge: 0.5, bins: 8, shift: Int(raw))
        return ShotDescriptorV1(shotID: ShotID(raw), observationID: ObservationID(1), startMs: at, endMs: at + dur,
                                representative: rep, transitionIn: entry, swipeGate: gate, replacementRatioIn: 0.8,
                                confidenceIn: 0.7, captionFingerprint: caption, audioContinuityWithPrevious: audio)
    }

    // MARK: §31.6 TUNE-only scan (grouping policy candidates). Winner frozen as .frozenV1.
    func testTuneScanExploratory() {
        let tune = HierarchicalCorpusV1.corpus(seed: 0)
        let cands: [(String, ItemGroupingPolicyV1)] = [
            ("frozen", .frozenV1),
            ("A_margin0.10", .init(confirmNewThreshold: 0.42, confirmSameThreshold: 0.40, decisionMargin: 0.10)),
            ("B_strictMerge", .init(confirmNewThreshold: 0.42, confirmSameThreshold: 0.50, decisionMargin: 0.12)),
            ("C_looseNew", .init(confirmNewThreshold: 0.38, confirmSameThreshold: 0.45, decisionMargin: 0.10)),
        ]
        for (name, p) in cands {
            let r = GroupingEvalV1.evaluate(p, fixtures: tune)
            print(String(format: "P009A_TUNE %@ newP=%.3f newR=%.3f F1=%.3f mergeP=%.3f mergeR=%.3f xMerge/item=%.4f amb=%d shots/item=%.2f",
                         name, r.overall.newPrecision, r.overall.newRecall, r.overall.newF1, r.overall.mergePrecision,
                         r.overall.mergeRecall, r.overall.falseCrossItemMergePerItem, r.overall.ambiguous, r.overall.shotsPerItem))
        }
        let fr = GroupingEvalV1.evaluate(.frozenV1, fixtures: tune)
        for (n, m) in fr.perSlice.sorted(by: { $0.key < $1.key }) where m.confirmedNewFP > 0 || m.mergeFP > 0 || (m.trueBoundaries - m.confirmedNewTP) > 0 {
            print(String(format: "P009A_TUNESLICE %@ newTP=%d newFP=%d missedNew=%d mergeFP=%d amb=%d", n, m.confirmedNewTP, m.confirmedNewFP, m.trueBoundaries - m.confirmedNewTP, m.mergeFP, m.ambiguous))
        }
        XCTAssertFalse(tune.isEmpty)
    }

    // MARK: §31.8 HELD-OUT — run once with the FROZEN policy on corpus(seed:1). §20 predeclared gates.
    func testHeldOutGroupingTargets() {
        let r = GroupingEvalV1.evaluate(.frozenV1, fixtures: HierarchicalCorpusV1.corpus(seed: 1))
        print(String(format: "P009A_HELDOUT newP=%.3f newR=%.3f F1=%.3f mergeP=%.3f mergeR=%.3f xMerge/item=%.4f amb=%d(ok=%d) shots/item=%.2f items=%d",
                     r.overall.newPrecision, r.overall.newRecall, r.overall.newF1, r.overall.mergePrecision, r.overall.mergeRecall,
                     r.overall.falseCrossItemMergePerItem, r.overall.ambiguous, r.overall.ambiguousAcceptable, r.overall.shotsPerItem, r.overall.items))
        for (n, m) in r.perSlice.sorted(by: { $0.key < $1.key }) {
            print(String(format: "P009A_SLICE %@ newTP=%d newFP=%d missed=%d mergeTP=%d mergeFP=%d amb=%d", n, m.confirmedNewTP, m.confirmedNewFP, m.trueBoundaries - m.confirmedNewTP, m.mergeTP, m.mergeFP, m.ambiguous))
        }
        XCTAssertGreaterThanOrEqual(r.overall.newPrecision, 0.97, "new-item precision")
        XCTAssertGreaterThanOrEqual(r.overall.newRecall, 0.90, "new-item recall")
        XCTAssertGreaterThanOrEqual(r.overall.newF1, 0.93, "new-item F1")
        XCTAssertGreaterThanOrEqual(r.overall.mergePrecision, 0.98, "same-item merge precision")
        XCTAssertLessThanOrEqual(r.overall.falseCrossItemMergePerItem, 0.01, "false cross-item merge per item")
    }

    // §20 stress: internal cuts must not explode item count; rapid distinct items must not collapse.
    func testStressGrouping() {
        let r = GroupingEvalV1.evaluate(.frozenV1, fixtures: HierarchicalCorpusV1.corpus(seed: 2, stress: true))
        let montage = r.perSlice["stress-long-montage"]!
        let rapid = r.perSlice["stress-many-rapid-items"]!
        print(String(format: "P009A_STRESS montage(newFP=%d amb=%d of 23 merges) rapid(newTP=%d of %d)", montage.confirmedNewFP, montage.ambiguous, rapid.confirmedNewTP, rapid.trueBoundaries))
        XCTAssertLessThanOrEqual(montage.confirmedNewFP + montage.ambiguous, 2, "24-cut montage must not explode")
        XCTAssertGreaterThanOrEqual(rapid.confirmedNewTP, 6, "rapid distinct items must not collapse (7 boundaries)")
        XCTAssertEqual(rapid.mergeFP, 0, "no cross-item merge under rapid swipes")
    }

    // MARK: §28 individual behaviors
    func testOneShotOneItem() {
        let e = ContentItemGroupingEngineV1()
        _ = e.process(shot(1, theme: 0.3, at: 0, caption: 10))
        XCTAssertEqual(e.confirmedOrProvisionalItemCount, 1)
    }

    func testInternalCutNotNewItem_MultiCutCoalesces() {
        let e = ContentItemGroupingEngineV1()
        _ = e.process(shot(1, theme: 0.4, at: 0, dur: 1500, caption: 10))
        for k in 2...6 {
            let d = e.process(shot(UInt64(k), theme: 0.4 + 0.05 * Double(k % 2), at: Double(k) * 1500, dur: 1500, caption: 10, audio: true))
            XCTAssertEqual(d.state, .sameItemConfirmed, "internal cut \(k) must merge")
        }
        XCTAssertEqual(e.confirmedOrProvisionalItemCount, 1, "6-cut edited video = ONE item")
    }

    func testTalkingHeadBRollSameItem() {
        let e = ContentItemGroupingEngineV1()
        _ = e.process(shot(1, theme: 0.3, at: 0, dur: 2000, caption: 7))
        let themes = [0.65, 0.3, 0.65, 0.3]   // alternating clusters, same caption+audio
        for (i, t) in themes.enumerated() {
            let d = e.process(shot(UInt64(i + 2), theme: t, at: Double(i + 1) * 2000, dur: 2000, caption: 7, audio: true))
            XCTAssertNotEqual(d.state, .newItemConfirmed, "B-roll alternation must not split")
        }
        XCTAssertEqual(e.confirmedOrProvisionalItemCount, 1)
    }

    func testPanSameItem_SensorLevel() {
        // §28 pan: the SHOT sensor already proves pan ≠ boundary (V5). Via ShotSegmenterV5 a pan emits NO shot event.
        let seg = ShotSegmenterV5(observationID: ObservationID(9))
        let fx = FixtureGeneratorV5.build("pan", [.init(base: 0.2, amp: 0.03, n: 24, drift: 0.028, entry: .start)], seed: 3)
        var boundaries = 0
        for (i, f) in fx.frames.enumerated() { if seg.process(f, timestampMs: fx.times[i]).boundary != nil && i > 0 { boundaries += 1 } }
        XCTAssertEqual(boundaries, 0, "pan must not emit shot boundaries")
    }

    func testRealNewItemAfterSwipe() {
        let e = ContentItemGroupingEngineV1()
        _ = e.process(shot(1, theme: 0.3, at: 0, dur: 5000, caption: 1))
        let d = e.process(shot(2, theme: 0.8, at: 5000, entry: .swipeConfirmed, gate: .swipeTransitionConfirmed, caption: 2, audio: false))
        XCTAssertEqual(d.state, .newItemConfirmed)
        XCTAssertFalse(d.safeAdmissionInheritance)
    }

    func testVisuallySimilarAdjacentDifferentItems() {
        let e = ContentItemGroupingEngineV1()
        _ = e.process(shot(1, theme: 0.50, at: 0, dur: 5000, caption: 1))
        let d = e.process(shot(2, theme: 0.53, at: 5000, entry: .swipeConfirmed, gate: .swipeTransitionConfirmed, caption: 2, audio: false))
        XCTAssertEqual(d.state, .newItemConfirmed, "swipe + caption change beats visual similarity")
    }

    func testSameTemplateAdjacentDifferentItems() {
        // cut-presenting swipe (device reality): caught by caption change + audio break + long dwell
        let e = ContentItemGroupingEngineV1()
        _ = e.process(shot(1, theme: 0.45, at: 0, dur: 6000, caption: 1))
        let d = e.process(shot(2, theme: 0.50, at: 6000, entry: .cut, caption: 2, audio: false))
        XCTAssertEqual(d.state, .newItemConfirmed, "same-template adjacent items must split on caption+audio+dwell")
    }

    func testRepeatedItemCacheReuse() {
        let cache = ContentIdentityCacheV1()
        let sig = SegmentFrameFactoryV4.frame(base: 0.3, motionOffset: 0, chromeTop: 0.9, chromeBottom: 0.1, chromeEdge: 0.5, bins: 8, shift: 1).regions
        cache.insert(IdentityCacheRecordV1(dnaID: ContentDNAID(42), fullSignature: sig, confidence: 0.9, version: "v1",
                                           expiresAtMs: 100_000, localScope: true, privacyClass: .derivedNonReconstructive), for: sig)
        guard case .hit(let dna, _) = cache.lookup(sig, nowMs: 0) else { return XCTFail("expected cache hit") }
        XCTAssertEqual(dna, ContentDNAID(42))
        XCTAssertEqual(cache.hits, 1)
    }

    func testCacheCollisionReanalysis() {
        let cache = ContentIdentityCacheV1(collisionMaxDistance: 0.05)
        let a = SegmentFrameFactoryV4.frame(base: 0.30, motionOffset: 0, chromeTop: 0.9, chromeBottom: 0.1, chromeEdge: 0.5, bins: 8, shift: 1).regions
        // craft a signature with the SAME quantized key (equal popcounts) but far-apart bit layout → collision
        var b = a
        b.center = a.center << 32                        // same popcount (thermo run ≤ 32 bits), hamming ≈ 2×popcount
        cache.insert(IdentityCacheRecordV1(dnaID: ContentDNAID(7), fullSignature: b, confidence: 0.9, version: "v1",
                                           expiresAtMs: 100_000, localScope: true, privacyClass: .derivedNonReconstructive), for: b)
        let outcome = cache.lookup(a, nowMs: 0)
        if case .hit = outcome { XCTFail("colliding signature must not hit") }
        // .collisionReanalyze or .miss are both safe; if key matched, it must degrade to re-analysis
        if case .collisionReanalyze = outcome { XCTAssertEqual(cache.collisions, 1) }
    }

    func testRapidSwipeDistinctItems() {
        let e = ContentItemGroupingEngineV1()
        _ = e.process(shot(1, theme: 0.1, at: 0, dur: 900, caption: 1))
        var confirmed = 0
        for (i, t) in [0.45, 0.75, 0.25].enumerated() {
            let d = e.process(shot(UInt64(i + 2), theme: t, at: Double(i + 1) * 900, dur: 900,
                                   entry: .swipeConfirmed, gate: .swipeTransitionConfirmed, caption: UInt64(i + 2), audio: false))
            if d.state == .newItemConfirmed { confirmed += 1 }
        }
        XCTAssertEqual(confirmed, 3, "rapid swipes stay distinct")
    }

    // §7 safety-first merge: conflicting evidence must NOT merge and must NOT inherit safe admission.
    func testFalseCrossItemMergeProtection_AmbiguousSafeSplit() {
        let e = ContentItemGroupingEngineV1()
        _ = e.process(shot(1, theme: 0.5, at: 0, dur: 2000))
        // no caption, no audio, similar theme, cut, no strong signals → AMBIGUOUS provisional split
        let d = e.process(shot(2, theme: 0.56, at: 2000, dur: 2000))
        XCTAssertEqual(d.state, .ambiguous)
        XCTAssertTrue(d.provisional)
        XCTAssertFalse(d.safeAdmissionInheritance, "§7: uncertain boundary never inherits safe admission")
        XCTAssertEqual(e.confirmedOrProvisionalItemCount, 2, "provisional split, not merge")
    }

    func testLaterEvidenceMergesProvisionalSafely() {
        let e = ContentItemGroupingEngineV1()
        _ = e.process(shot(1, theme: 0.5, at: 0, dur: 2000))
        let d = e.process(shot(2, theme: 0.56, at: 2000, dur: 2000))
        XCTAssertEqual(d.state, .ambiguous)
        XCTAssertTrue(e.reviseMergeProvisional(itemID: d.itemID, strongEvidenceConfidence: 0.9))
        XCTAssertEqual(e.confirmedOrProvisionalItemCount, 1, "late strong evidence merges the provisional item")
        XCTAssertEqual(e.revisions.last?.lifecycle, .merged)
        XCTAssertFalse(e.reviseMergeProvisional(itemID: d.itemID, strongEvidenceConfidence: 0.5), "weak evidence cannot merge")
    }

    func testContentDNAInvalidationOnSplit() {
        let e = ContentItemGroupingEngineV1()
        _ = e.process(shot(1, theme: 0.4, at: 0, dur: 1500, caption: 3))
        _ = e.process(shot(2, theme: 0.42, at: 1500, dur: 1500, caption: 3, audio: true))
        let item = e.currentItem!.id
        let dna = e.mintDNA(for: item, nowMs: 3000)!
        var invalidated: [ContentDNAID] = []
        let newID = e.splitItem(itemID: item, atShotIndex: 1, dnaInvalidator: { invalidated.append($0) })
        XCTAssertNotNil(newID)
        XCTAssertEqual(invalidated, [dna.dnaID], "split must invalidate the item's DNA")
        XCTAssertEqual(e.revisions.last?.lifecycle, .provisional)
    }

    func testItemRiskEscalation() {
        // §8: a later dangerous shot escalates the ITEM; earlier harmless evidence never suppresses it.
        let acc = ContentItemEvidenceAccumulatorV1()
        let item = ContentItemID(1)
        acc.reportRisk(item: item, confidence: 0.0)
        acc.reportRisk(item: item, confidence: 0.9)
        acc.reportRisk(item: item, confidence: 0.1)
        XCTAssertEqual(acc.items[item]?.maxRiskConfidence, 0.9, "risk is monotone-max")
    }

    func testBoundedGraphMemory() {
        let g = HierarchicalTemporalGraphV1(maxActiveShots: 16)
        for i in 1...200 {
            let s = shot(UInt64(i), theme: 0.5, at: Double(i) * 1000, dur: 1000)
            g.addShot(s, item: ContentItemID(UInt64(i / 10)))
        }
        XCTAssertLessThanOrEqual(g.activeShotCount, 16, "graph must stay bounded")
        XCTAssertFalse(g.compacted.isEmpty, "evicted history must compact into summaries")
        let totalCompacted = g.compacted.reduce(0) { $0 + $1.shotCount }
        XCTAssertEqual(totalCompacted + g.activeShotCount, 200, "no shots silently lost")
    }

    func testResourceGovernorDedupesDeepInference() {
        let gov = ResourceGovernorV1()
        XCTAssertTrue(gov.requestDeepEscalation(item: ContentItemID(1), domain: .vision))
        XCTAssertFalse(gov.requestDeepEscalation(item: ContentItemID(1), domain: .vision), "duplicate deep run denied")
        XCTAssertTrue(gov.requestDeepEscalation(item: ContentItemID(1), domain: .ocrLanguage))
        XCTAssertEqual(gov.deepEscalations, 2); XCTAssertEqual(gov.deniedDuplicates, 1)
    }

    func testMetaBrainRoutingHonestUnavailability() {
        let brain = GuardianMetaBrainV1(capabilities: CapabilityResolverV1(capabilities: []))
        brain.experts.register(ExpertDescriptorV1(domain: .vision, name: "vision-fp", version: "1", capabilityRequirement: "neural-engine"))
        XCTAssertNil(brain.route(IntelligenceTaskV1(domain: .vision, itemID: ContentItemID(1), tier: 1, reason: "test")),
                     "missing capability → nil → honest UNKNOWN upstream, never faked")
        brain.experts.register(ExpertDescriptorV1(domain: .surfaceMotion, name: "shot-sensor-v5", version: "boundary-policy-v5"))
        XCTAssertNotNil(brain.route(IntelligenceTaskV1(domain: .surfaceMotion, itemID: nil, tier: 0, reason: "shot")))
    }

    // §13/§14 pack contracts
    func testPackManifestVerification() {
        let mgr = IntelligencePackLifecycleManagerV1()
        let payload: [UInt8] = Array("model-weights".utf8)
        let m = IntelligencePackManifestV1(packID: "vision.fp", semanticVersion: "1.2.0", engineCompatibility: "gen8-1",
                                           minimumOS: "17.0", deviceCapabilityRequirements: [], sizeBytes: 13,
                                           checksum: IntelligencePackManifestV1.fnv1a(payload), signature: "sig",
                                           assetTypes: [.model], privacyClassification: "none", localeScope: ["*"],
                                           evictionPriority: 1, rollbackVersion: "1.1.0", dependencies: [])
        XCTAssertEqual(mgr.install(m, payload: payload, engineVersion: "gen8-1", signatureValid: true), .installed)
        XCTAssertEqual(mgr.install(m, payload: payload + [0], engineVersion: "gen8-1", signatureValid: true), .quarantined, "checksum mismatch → quarantine")
        XCTAssertEqual(mgr.install(m, payload: payload, engineVersion: "gen8-1", signatureValid: false), .quarantined, "bad signature → quarantine")
        XCTAssertEqual(mgr.install(m, payload: payload, engineVersion: "gen8-2", signatureValid: true), .quarantined, "engine mismatch → quarantine")
    }

    func testPackRollbackContract() {
        let mgr = IntelligencePackLifecycleManagerV1()
        let payload: [UInt8] = [1, 2, 3]
        let m = IntelligencePackManifestV1(packID: "p", semanticVersion: "2.0.0", engineCompatibility: "gen8-1",
                                           minimumOS: "17.0", deviceCapabilityRequirements: [], sizeBytes: 3,
                                           checksum: IntelligencePackManifestV1.fnv1a(payload), signature: "s",
                                           assetTypes: [.model], privacyClassification: "none", localeScope: ["*"],
                                           evictionPriority: 1, rollbackVersion: "1.9.0", dependencies: [])
        _ = mgr.install(m, payload: payload, engineVersion: "gen8-1", signatureValid: true)
        let rb = mgr.rollback("p")
        XCTAssertEqual(rb?.version, "1.9.0"); XCTAssertEqual(rb?.state, .installed)
        XCTAssertNil(mgr.rollback("p"), "second rollback has no target")
    }

    func testPackEvictionContract() {
        let mgr = IntelligencePackLifecycleManagerV1()
        let payload: [UInt8] = [9]
        let m = IntelligencePackManifestV1(packID: "e", semanticVersion: "1.0", engineCompatibility: "gen8-1",
                                           minimumOS: "17.0", deviceCapabilityRequirements: [], sizeBytes: 1,
                                           checksum: IntelligencePackManifestV1.fnv1a(payload), signature: "s",
                                           assetTypes: [.data], privacyClassification: "none", localeScope: ["*"],
                                           evictionPriority: 9, rollbackVersion: nil, dependencies: [])
        _ = mgr.install(m, payload: payload, engineVersion: "gen8-1", signatureValid: true)
        mgr.markUsed("e", nowMs: 0)
        XCTAssertEqual(mgr.evictIfStale("e", nowMs: 10_000, ttlMs: 1_000, storagePressure: false), .evictable)
        XCTAssertEqual(mgr.evictIfStale("e", nowMs: 20_000, ttlMs: 1_000, storagePressure: false), .notInstalled)
    }

    // §16 LearningSignal has NO raw-media payload — asserted structurally over all stored properties.
    func testLearningSignalNoRawMedia() {
        let s = LearningSignalV1(signalType: "correction", derivedFeatureClass: "identity-split", scope: .local,
                                 consent: .defaultLocal, privacyClass: "derived", modelVersion: "v1", policyVersion: "p1",
                                 outcome: "accepted", correctionLabel: "same-item", confidence: 0.8, latencyMs: 3,
                                 locale: "tr", deviceCapabilityBucket: "a17", retentionDays: 30, aggregationEligible: false)
        for child in Mirror(reflecting: s).children {
            XCTAssertFalse(child.value is Data, "no raw Data payload in LearningSignal")
            XCTAssertFalse(child.value is [UInt8], "no raw byte payload in LearningSignal")
        }
        // consent gate: global without opt-in is rejected
        let bus = LearningSignalBusV1()
        var g = s; g.scope = .globalAggregate; g.consent = .defaultLocal
        XCTAssertFalse(bus.submit(g)); XCTAssertEqual(bus.rejectedConsent, 1)
        g.consent = .optInGlobal
        XCTAssertTrue(bus.submit(g))
    }

    // §17 controlled evolution: canonical order only; no shadow without eval evidence; kill/rollback always allowed.
    func testControlledEvolutionPipeline() {
        var c = EvolutionCandidateV1(candidateVersion: "cand-1", evalEvidenceRef: "", canaryCohortPercent: 1)
        XCTAssertTrue(c.advance(to: .offlineEval))
        XCTAssertFalse(c.advance(to: .shadow), "no shadow without offline eval evidence")
        c.evalEvidenceRef = "docs/evals/x.md"
        XCTAssertTrue(c.advance(to: .shadow))
        XCTAssertFalse(c.advance(to: .signedRelease), "cannot skip canary/calibration/gate")
        XCTAssertTrue(c.advance(to: .canary)); XCTAssertTrue(c.advance(to: .calibration))
        XCTAssertTrue(c.advance(to: .gate)); XCTAssertTrue(c.advance(to: .signedRelease))
        XCTAssertTrue(c.advance(to: .rolledBack), "rollback always allowed")
    }

    // §23 privacy firewall + provenance traceability.
    func testPrivacyAndProvenanceTraceability() {
        let graph = ContentIdentityEvidenceGraphV1(maxEdges: 64)
        let e = graph.add(modality: .visual, source: "theme", from: ShotID(1), to: ShotID(2), supportsSameItem: true,
                          confidence: 0.5, atMs: 0, privacy: .derivedNonReconstructive, capability: "tier0-visual",
                          modelVersion: "item-grouping-policy-v1")
        XCTAssertEqual(e.privacyClass, .derivedNonReconstructive)
        XCTAssertEqual(e.modelVersion, "item-grouping-policy-v1")
        for _ in 0..<200 { _ = graph.add(modality: .visual, source: "x", from: ShotID(1), to: ShotID(2), supportsSameItem: true, confidence: 0.1, atMs: 0, privacy: .ephemeralOnly, capability: "t", modelVersion: "v") }
        XCTAssertLessThanOrEqual(graph.edges.count, 64, "evidence graph bounded")
        let ledger = ProvenanceLedgerV1()
        ledger.record(ProvenanceEntryV1(subject: "dna:1", producer: "grouping-engine", modelVersion: "v1", policyVersion: "item-grouping-policy-v1", atMs: 1))
        XCTAssertEqual(ledger.trace(subject: "dna:1").count, 1)
    }

    func testShotSegmenterContractAndPolicyLogging() {
        // §3: wrapper preserves V5 semantics + revision; emits shot descriptors with transition metadata.
        let seg = ShotSegmenterV5(observationID: ObservationID(5))
        XCTAssertEqual(seg.policyRevision, "boundary-policy-v5")
        let fx = FixtureGeneratorV5.build("cut", [.init(base: 0.2, amp: 0.03, n: 8, entry: .start), .init(base: 0.8, amp: 0.03, n: 10, entry: .cut)], seed: 4)
        var boundaries: [ShotBoundaryEvent] = []
        for (i, f) in fx.frames.enumerated() { if let b = seg.process(f, timestampMs: fx.times[i]).boundary { if i > 0 { boundaries.append(b) } } }
        XCTAssertEqual(boundaries.count, 1, "one real cut = one shot boundary")
        XCTAssertEqual(boundaries.first?.policyRevision, "boundary-policy-v5")
        XCTAssertNotNil(boundaries.first?.closedShot)
    }
}
