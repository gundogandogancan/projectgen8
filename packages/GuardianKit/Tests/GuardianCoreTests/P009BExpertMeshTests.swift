import XCTest
@testable import GuardianCore

final class P009BExpertMeshTests: XCTestCase {

    func makeBrain() -> GuardianMetaBrainV2 {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1())
        b.registry.register(LanguageOCRExpertV1())
        b.registry.register(SpeechExpertV1())
        b.registry.register(AudioEventExpertV1())
        b.registry.register(MusicExpertV1())
        b.registry.register(SymbolExpertV1())
        b.registry.register(TemporalExpertV1())
        b.registry.register(SafetyEvidenceExpertV1())
        b.registry.register(BenefitEvidenceExpertV1())
        b.registry.register(AttentionPressureExpertV1())
        return b
    }
    func ctx(_ b: GuardianMetaBrainV2, item: UInt64, provisional: Bool = false,
             profile: RuntimeCapabilityProfileV2 = .appFullTier1,
             domains: [ExpertDomainV2] = ExpertDomainV2.allCases,
             cancel: CancellationTokenV2 = CancellationTokenV2()) -> ExpertTaskContextV2 {
        ExpertTaskContextV2(observationID: ObservationID(1), shotID: ShotID(item), itemID: ContentItemID(item),
                            itemProvisional: provisional, profile: profile, requestedDomains: domains,
                            cancellation: cancel, generation: b.currentGeneration)
    }

    // ── §39 TUNE/HELD-OUT/STRESS/OOD over the corpus (expectation gates frozen before held-out) ──
    func runCorpus(_ seed: Int, name: String) -> (failures: [String], abstentions: Int, contradictions: Int) {
        var failures: [String] = []; var abst = 0; var contra = 0
        for (i, s) in P009BCorpusV1.corpus(seed: seed).enumerated() {
            let brain = makeBrain()
            let r = P009BCorpusV1.runScenario(s, brain: brain, item: ContentItemID(UInt64(i + 1)), nowMs: Double(i))
            let allLabels = r.route.evidence.flatMap { $0.labels }
            for exp in s.expectEvidencePrefixes where !allLabels.contains(where: { $0.hasPrefix(exp) || $0.contains(exp) }) {
                failures.append("\(name)/\(s.name): missing '\(exp)'")
            }
            for forb in s.forbidEvidencePrefixes where allLabels.contains(where: { $0.hasPrefix(forb) }) {
                failures.append("\(name)/\(s.name): forbidden '\(forb)' present")
            }
            if s.expectContradiction && r.graph.contradictions.isEmpty { failures.append("\(name)/\(s.name): expected contradiction") }
            let hasAbstention = r.route.evidence.contains { !$0.inputModalityAvailable } || !r.route.unknownReasons.isEmpty
            if s.expectAbstention && !hasAbstention { failures.append("\(name)/\(s.name): expected abstention") }
            if hasAbstention { abst += 1 }
            contra += r.graph.contradictions.count
        }
        return (failures, abst, contra)
    }
    func testTuneCorpus() {
        let r = runCorpus(0, name: "TUNE")
        print("P009B_TUNE scenarios=\(P009BCorpusV1.corpus(seed: 0).count) failures=\(r.failures.count) abstentions=\(r.abstentions) contradictions=\(r.contradictions)")   // F4: real count (18), never a hardcoded claim
        r.failures.forEach { print("P009B_TUNE_FAIL \($0)") }
        XCTAssertTrue(r.failures.isEmpty, "\(r.failures)")
    }
    func testHeldOutCorpus() {   // run once, expectations frozen on TUNE
        let r = runCorpus(1, name: "HELDOUT")
        print("P009B_HELDOUT failures=\(r.failures.count) abstentions=\(r.abstentions) contradictions=\(r.contradictions)")
        r.failures.forEach { print("P009B_HELDOUT_FAIL \($0)") }
        XCTAssertTrue(r.failures.isEmpty, "\(r.failures)")
    }
    func testStressOODCorpus() {
        let r2 = runCorpus(2, name: "STRESS"); let r3 = runCorpus(3, name: "OOD")
        XCTAssertTrue(r2.failures.isEmpty, "\(r2.failures)"); XCTAssertTrue(r3.failures.isEmpty, "\(r3.failures)")
    }

    // ── §39 capability truth ──
    func testProfileCapabilityTruth() {
        let b = makeBrain()
        // Tier-0: only temporal permitted; semantics forbidden
        let r0 = b.route(input: ExpertInputV2(ocrText: "learn science", detectedLanguage: "en"),
                         context: ctx(b, item: 1, profile: .extensionFastTier0, domains: [.languageOCR, .temporal]), nowMs: 0)
        XCTAssertTrue(r0.unavailable.contains(.languageOCR), "Tier-0 must not run semantic experts")
        XCTAssertTrue(r0.executed.contains(.temporal))
        // EXTENSION_TIER1_LITE and FUTURE_SHARED: everything unavailable
        for p in [RuntimeCapabilityProfileV2.extensionTier1Lite, .futureSharedTier1] {
            let r = b.route(input: ExpertInputV2(ocrText: "x", detectedLanguage: "en"), context: ctx(b, item: 2, profile: p, domains: [.languageOCR]), nowMs: 0)
            XCTAssertTrue(r.executed.isEmpty, "\(p) must execute nothing until proven/unblocked")
        }
    }
    func testUnavailableExpertExplicit() {
        let b = GuardianMetaBrainV2()   // nothing registered
        let r = b.route(input: ExpertInputV2(ocrText: "x", detectedLanguage: "en"), context: ctx(b, item: 1, domains: [.vision]), nowMs: 0)
        XCTAssertTrue(r.evidence.contains { !$0.inputModalityAvailable }, "unregistered expert → explicit UNAVAILABLE evidence")
        XCTAssertTrue(r.unknownReasons.contains { $0.hasPrefix("expert-unavailable") })
    }

    // ── §39 routing: cheapest-sufficient order + cache + dedupe ──
    func testCheapestSufficientOrderAndCache() {
        let b = makeBrain()
        let input = ExpertInputV2(ocrText: "learn how to lesson", detectedLanguage: "en", visualLabels: ["book"], visualConfidence: 0.8)
        let r1 = b.route(input: input, context: ctx(b, item: 7), nowMs: 0)
        // cheapest-first: symbol/temporal/benefit/attention (cost 1) must precede vision (cost 5)
        if let vIdx = r1.executed.firstIndex(of: .vision), let sIdx = r1.executed.firstIndex(of: .symbol) {
            XCTAssertLessThan(sIdx, vIdx, "cheaper expert runs first")
        }
        // second route on the same confirmed item: cache hits suppress expert reruns
        let r2 = b.route(input: input, context: ctx(b, item: 7), nowMs: 1)
        XCTAssertFalse(r2.cacheHits.isEmpty, "cache must suppress duplicate inference")
        XCTAssertTrue(r2.cacheHits.contains(.languageOCR) || r2.cacheHits.contains(.vision))
        XCTAssertGreaterThan(b.cache.hits, 0)
    }
    func testNoDuplicateHeavyExpert() {
        let b = makeBrain()
        let input = ExpertInputV2(visualLabels: ["cat"], visualConfidence: 0.9, speechTranscript: "hi", speechAvailable: true)
        _ = b.route(input: input, context: ctx(b, item: 9, provisional: true, domains: [.vision, .speech]), nowMs: 0)
        let r2 = b.route(input: input, context: ctx(b, item: 9, provisional: true, domains: [.vision, .speech]), nowMs: 1)
        // provisional → no cache; dedupe must stop the second deep run
        XCTAssertTrue(r2.unknownReasons.contains { $0.hasPrefix("deep-dedupe") }, "heavy experts dedupe per item")
    }

    // ── §21/§39 stale firewall + cancellation ──
    func testStaleResultCannotCrossIdentity() {
        let b = makeBrain()
        let oldGen = b.currentGeneration
        let staleCtx = ctx(b, item: 1)                      // captured at old generation
        b.identityChanged()                                 // identity changes → new generation
        let r = b.route(input: ExpertInputV2(ocrText: "learn lesson", detectedLanguage: "en"), context: staleCtx, nowMs: 0)
        XCTAssertTrue(r.executed.isEmpty, "results from an old generation are discarded, never attached")
        XCTAssertTrue(r.unknownReasons.contains { $0.hasPrefix("stale-discarded") })
        XCTAssertEqual(staleCtx.generation, oldGen)
        // bus-level firewall
        XCTAssertEqual(b.bus.forItem(ContentItemID(1), generation: b.currentGeneration).count, 0)
    }
    func testCancellationStopsWork() {
        let b = makeBrain()
        let token = CancellationTokenV2(); token.cancel()
        let r = b.route(input: ExpertInputV2(ocrText: "x", detectedLanguage: "en"), context: ctx(b, item: 3, cancel: token), nowMs: 0)
        XCTAssertTrue(r.executed.isEmpty)
        XCTAssertTrue(r.unknownReasons.allSatisfy { $0.hasPrefix("cancelled") || $0.hasPrefix("profile") || $0.hasPrefix("expert") })
    }

    // ── §20/§39 thermal routing ──
    func testThermalFairDefersOptionalDeep() {
        let b = makeBrain()
        b.governor.setThermal(.fair)
        let r = b.route(input: ExpertInputV2(ocrText: "learn", detectedLanguage: "en", visualLabels: ["x"], visualConfidence: 0.5, speechTranscript: "y", speechAvailable: true),
                        context: ctx(b, item: 4), nowMs: 0)
        XCTAssertTrue(r.deferredThermal.contains(.vision) || r.deferredThermal.contains(.speech), "FAIR defers deep optional experts")
        XCTAssertTrue(r.executed.contains(.safetyEvidence), "safety-critical cheap path continues at FAIR")
    }
    func testThermalSeriousMinimumSafePath() {
        let b = makeBrain()
        b.governor.setThermal(.serious)
        let r = b.route(input: ExpertInputV2(ocrText: "deadly disaster", detectedLanguage: "en", visualLabels: ["x"], visualConfidence: 0.5),
                        context: ctx(b, item: 5), nowMs: 0)
        XCTAssertFalse(r.executed.contains(.vision), "SERIOUS blocks heavy experts")
        XCTAssertTrue(r.executed.contains(.safetyEvidence) || r.executed.contains(.temporal), "minimum safe path survives")
        XCTAssertFalse(r.unknownReasons.isEmpty, "UNKNOWN reasons recorded under thermal pressure")
    }

    // ── §34/§39 sanitization + malformed handoff quarantine ──
    func testHandoffSanitization() {
        let b = makeBrain()
        b.beginObservation(ObservationID(42))
        func handoff(gap: Double = 100, theme: Double = 0.3, proj: Double = 0.5, obs: UInt64 = 42,
                     shotRaw: UInt64 = 1, versions: [String] = ["v"]) -> Tier1IdentityHandoffV1 {
            Tier1IdentityHandoffV1(observationID: ObservationID(obs), shotID: ShotID(shotRaw), provisionalItemID: ContentItemID(1),
                                   transitionType: .cut, gapSinceLastBoundaryMs: gap, previousShotDwellMs: 100,
                                   elapsedItemMs: 100, themeDistance: theme, projectionCorrelation: proj,
                                   histogramDistance: 0.2, chromeDistance: 0.2, regionalDistance: 0.2,
                                   ambiguityReason: "", strongNew: false, priorRelation: .ambiguous,
                                   thermalBucket: .nominal, capabilityProfile: "T0", modelPolicyVersions: versions)
        }
        XCTAssertEqual(b.handoffConsumer.consume(handoff(), currentObservation: b.currentObservation), .accepted)
        XCTAssertEqual(b.handoffConsumer.consume(handoff(theme: .nan), currentObservation: b.currentObservation), .quarantined)
        XCTAssertEqual(b.handoffConsumer.consume(handoff(proj: .infinity), currentObservation: b.currentObservation), .quarantined)
        XCTAssertEqual(b.handoffConsumer.consume(handoff(gap: -5), currentObservation: b.currentObservation), .quarantined)
        XCTAssertEqual(b.handoffConsumer.consume(handoff(theme: 7.0), currentObservation: b.currentObservation), .quarantined)
        XCTAssertEqual(b.handoffConsumer.consume(handoff(shotRaw: 0), currentObservation: b.currentObservation), .quarantined)
        XCTAssertEqual(b.handoffConsumer.consume(handoff(versions: []), currentObservation: b.currentObservation), .quarantined)
        XCTAssertEqual(b.handoffConsumer.consume(handoff(obs: 999), currentObservation: b.currentObservation), .quarantined, "stale session rejected")
        XCTAssertEqual(b.handoffConsumer.quarantinedCount, 7)
        XCTAssertEqual(b.handoffConsumer.accepted.count, 1, "quarantined records never processed, never positive state")
    }

    // ── §39 expert behaviors ──
    func testOCRUncertaintyAndUnsupportedLanguage() {
        let e = LanguageOCRExpertV1()
        let c = ctx(makeBrain(), item: 1)
        let noisy = e.evaluate(ExpertInputV2(ocrText: "x§", detectedLanguage: "en"), context: c)
        XCTAssertTrue(noisy.oodIndicator); XCTAssertLessThan(noisy.confidence, 0.3)
        let ja = e.evaluate(ExpertInputV2(ocrText: "こんにちは", detectedLanguage: "ja"), context: c)
        XCTAssertTrue(ja.labels.contains("UNSUPPORTED_LANGUAGE")); XCTAssertEqual(ja.calibrationStatus, .unavailable)
    }
    func testSpeechUnavailableHonest() {
        let e = SpeechExpertV1()
        let ev = e.evaluate(ExpertInputV2(speechAvailable: false), context: ctx(makeBrain(), item: 1))
        XCTAssertFalse(ev.inputModalityAvailable); XCTAssertEqual(ev.calibrationStatus, .unavailable)
    }
    func testAudioUnsupportedClassHonest() {
        let e = AudioEventExpertV1()
        let ev = e.evaluate(ExpertInputV2(soundEvents: ["laser-zap"]), context: ctx(makeBrain(), item: 1))
        XCTAssertTrue(ev.labels.contains { $0.hasPrefix("audio:unsupported-classes") })
        XCTAssertTrue(ev.oodIndicator)
    }
    func testTemporalEscalationLaw() {
        let t = TemporalExpertV1()
        t.observe(riskLevel: 0.0, topicLabels: ["topic:calm"])
        t.observe(riskLevel: 0.9, topicLabels: ["topic:war"])
        t.observe(riskLevel: 0.0, topicLabels: ["topic:calm"])    // benign later CANNOT suppress
        let ev = t.evaluate(ExpertInputV2(), context: ctx(makeBrain(), item: 1, provisional: true))
        XCTAssertTrue(ev.labels.contains("temporal:risk-escalated"), "monotone-max risk")
        XCTAssertEqual(ev.features["maxRisk"], 0.9)
        XCTAssertTrue(ev.labels.contains("temporal:identity-provisional"), "works on provisional identity")
    }
    func testSafetyDimensionTagsAndH1Open() {
        XCTAssertEqual(SafetyEvidenceExpertV1.dimensionStatus["violence-injury-visual"], .unavailable, "H1 stays an explicit blocker")
        XCTAssertEqual(SafetyEvidenceExpertV1.dimensionStatus["explicit-sexual-visual"], .unavailable)
        let ev = SafetyEvidenceExpertV1().evaluate(ExpertInputV2(ocrText: "nothing special", detectedLanguage: "en"), context: ctx(makeBrain(), item: 1))
        XCTAssertTrue(ev.labels.contains { $0.contains("H1-visual-dimensions:UNAVAILABLE") })
        XCTAssertTrue(ev.labels.contains { $0.contains("NOT a safe verdict") }, "no safe conclusion from weak-evidence absence")
    }
    func testSafetyVsBenefitConflictRepresented() {
        let b = makeBrain()
        let input = ExpertInputV2(ocrText: "learn how disease spreads: lesson about death", detectedLanguage: "en")
        let r = b.route(input: input, context: ctx(b, item: 11), nowMs: 0)
        let g = CrossModalExpertGraphV1(); g.relate(r.evidence)
        XCTAssertFalse(g.contradictions.isEmpty, "risk-vs-positive contradiction represented, not vote-averaged")
    }

    // ── §16/§17/§39 understanding state + DNA candidate ──
    func testUnderstandingStateAndDNAMintRules() {
        let b = makeBrain()
        let input = ExpertInputV2(ocrText: "learn science lesson", detectedLanguage: "en", visualLabels: ["book"], visualConfidence: 0.7)
        let rProv = b.route(input: input, context: ctx(b, item: 20, provisional: true), nowMs: 0)
        let g = CrossModalExpertGraphV1(); g.relate(rProv.evidence)
        let stProv = ContentUnderstandingStateV1.build(itemProvisional: true, evidence: rProv.evidence, graph: g, registry: b.registry, unknownReasons: rProv.unknownReasons)
        XCTAssertEqual(stProv.identityStatus, "provisional")
        XCTAssertFalse(stProv.contentDNAReady)
        XCTAssertNil(ContentDNACandidateV2.mint(from: stProv, itemID: ContentItemID(20), itemProvisional: true, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]),
                     "no durable DNA from unresolved provisional identity")
        let rConf = b.route(input: input, context: ctx(b, item: 21, provisional: false), nowMs: 1)
        let g2 = CrossModalExpertGraphV1(); g2.relate(rConf.evidence)
        let stConf = ContentUnderstandingStateV1.build(itemProvisional: false, evidence: rConf.evidence, graph: g2, registry: b.registry, unknownReasons: rConf.unknownReasons)
        let dna = ContentDNACandidateV2.mint(from: stConf, itemID: ContentItemID(21), itemProvisional: false, dnaRaw: 2, nowMs: 0, modelVersions: ["m"])
        XCTAssertNotNil(dna, "confirmed identity mints")
        XCTAssertFalse(dna!.provenance.isEmpty, "provenance-bearing")
        XCTAssertEqual(dna!.privacyClass, .derivedNonReconstructive)
    }
    func testCacheInvalidationOnModelVersionAndItemSplit() {
        let b = makeBrain()
        let input = ExpertInputV2(ocrText: "learn", detectedLanguage: "en")
        _ = b.route(input: input, context: ctx(b, item: 30), nowMs: 0)
        XCTAssertGreaterThan(b.cache.count, 0)
        b.cache.invalidate(modelVersionNot: "new-version", domain: .languageOCR)
        XCTAssertNil(b.cache.lookup(item: ContentItemID(30), domain: .languageOCR, modelVersion: "language-ocr-expert-v1/lexicon-v1"), "stale model version invalidated")
        b.cache.invalidate(item: ContentItemID(30))
        XCTAssertGreaterThan(b.cache.staleInvalidations, 0)
    }

    // ── §19/§39 external asset audit + pack fallback ──
    func testExternalAssetAuditRejection() {
        // §19: unclear license/provenance → DO NOT INTEGRATE. The registry currently has ZERO external assets;
        // the gate is the pack manifest VERIFY path (quarantine) + this declared policy. Re-assert the pack gate:
        let mgr = IntelligencePackLifecycleManagerV1()
        let payload: [UInt8] = [1]
        let m = IntelligencePackManifestV1(packID: "unverified.model", semanticVersion: "1", engineCompatibility: "gen8-1",
                                           minimumOS: "17", deviceCapabilityRequirements: [], sizeBytes: 1,
                                           checksum: 0xDEAD /* wrong */, signature: "unverified",
                                           assetTypes: [.model], privacyClassification: "unknown", localeScope: ["*"],
                                           evictionPriority: 1, rollbackVersion: nil, dependencies: [])
        XCTAssertEqual(mgr.install(m, payload: payload, engineVersion: "gen8-1", signatureValid: false), .quarantined)
        XCTAssertEqual(mgr.state(of: "unverified.model"), .quarantined, "unclear provenance never installs")
    }
    func testAssetAuditLedgerLawful() {
        XCTAssertTrue(P009BAssetAuditLedgerV1.allIntegrationsLawful)
        XCTAssertFalse(P009BAssetAuditLedgerV1.records.isEmpty)
        XCTAssertTrue(P009BAssetAuditLedgerV1.records.allSatisfy { $0.licenseClass != .unclearDoNotIntegrate },
                      "§19: unclear license/provenance never integrates")
        // zero NEW external model assets this phase: everything is Apple-OS or project-authored
        XCTAssertTrue(P009BAssetAuditLedgerV1.records.allSatisfy {
            $0.licenseClass == .appleSystemFramework || $0.licenseClass == .projectAuthored })
    }
    func testMissingPackFallbackIsUnavailable() {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1(availability: .unavailable))   // pack missing → expert declares unavailable
        let r = b.route(input: ExpertInputV2(visualLabels: ["x"], visualConfidence: 0.9), context: ctx(b, item: 1, domains: [.vision]), nowMs: 0)
        XCTAssertTrue(r.executed.isEmpty)
        XCTAssertTrue(r.evidence.contains { !$0.inputModalityAvailable })
    }

    // ── §39 legacy bypass + score/calibration + privacy ──
    func testLegacyEngineCannotBypassPhaseC() {
        // the deprecated V1 engine is not reachable from any V2 runtime path: MetaBrain/experts never reference it.
        // Structural check: V2 runtime types hold no V1 engine instance.
        let b = makeBrain()
        let mirror = Mirror(reflecting: b)
        XCTAssertFalse(mirror.children.contains { String(describing: type(of: $0.value)).contains("ContentItemGroupingEngineV1") })
    }
    func testScoreDisplayImpossibleInP009B() {
        let b = makeBrain()
        XCTAssertFalse(b.calibration.scoreDisplayAllowed(), "no numeric score path in P009B")
        XCTAssertFalse(b.calibration.isCalibrated(domain: .safetyEvidence, language: "tr"))
        // every evidence record carries a non-calibrated status
        let r = b.route(input: ExpertInputV2(ocrText: "learn", detectedLanguage: "en"), context: ctx(b, item: 40), nowMs: 0)
        XCTAssertTrue(r.evidence.allSatisfy { $0.calibrationStatus != .implementedCalibrated })
    }
    func testEvidencePrivacyDerivedOnly() {
        let b = makeBrain()
        let r = b.route(input: ExpertInputV2(ocrText: "private text here", detectedLanguage: "en"), context: ctx(b, item: 50), nowMs: 0)
        for e in r.evidence {
            for child in Mirror(reflecting: e).children {
                XCTAssertFalse(child.value is Data); XCTAssertFalse(child.value is [UInt8])
            }
            // labels must not embed raw OCR text verbatim
            XCTAssertFalse(e.labels.contains { $0.contains("private text here") }, "raw text never copied into evidence labels")
            XCTAssertEqual(e.privacyClass, .derivedNonReconstructive)
        }
    }
    func testBoundedRuntimeContainers() {
        let b = makeBrain()
        for i in 0..<3000 {
            b.bus.publish(ExpertEvidenceV2(domain: .symbol, labels: ["x"], confidence: 0, coverage: 0, uncertainty: 1,
                                           provenance: "t", modelVersion: "v", calibrationStatus: .heuristicSupportOnly, generation: 1))
            b.ledger.record(subject: "s\(i)", producer: "p", modelVersion: "v", profile: "t", atMs: Double(i))
        }
        XCTAssertLessThanOrEqual(b.bus.evidence.count, 2048)
        XCTAssertLessThanOrEqual(b.ledger.entries.count, 4096)
    }
}
