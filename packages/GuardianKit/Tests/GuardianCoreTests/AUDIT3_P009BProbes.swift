import XCTest
@testable import GuardianCore

// AUDIT3 — INDEPENDENT P009B RED-TEAM PROBES (auditor-authored, fresh session).
// These tests attack: stale-generation attachment, cache/firewall interaction, provisional DNA leaks,
// score-display bypass, capability escalation, quarantine bypass variants, safety-dominance bypass,
// honest-unavailability fuzz (NaN/∞), model-version cache poisoning, thermal law, split/seed honesty.
// CHARACTERIZATION probes assert CURRENT behavior and carry "AUDIT-FINDING" in their message where the
// current behavior is a defect/limitation — the finding lives in the audit report, not in a code change.
// NO existing source or test file was modified by the auditor.

final class AUDIT3_P009BProbes: XCTestCase {

    // MARK: helpers

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
             cancel: CancellationTokenV2 = CancellationTokenV2(),
             generation: UInt64? = nil) -> ExpertTaskContextV2 {
        ExpertTaskContextV2(observationID: ObservationID(1), shotID: ShotID(item), itemID: ContentItemID(item),
                            itemProvisional: provisional, profile: profile, requestedDomains: domains,
                            cancellation: cancel, generation: generation ?? b.currentGeneration)
    }
    func inputsEqual(_ a: ExpertInputV2, _ b: ExpertInputV2) -> Bool {
        a.ocrText == b.ocrText && a.detectedLanguage == b.detectedLanguage && a.visualLabels == b.visualLabels
        && a.visualConfidence == b.visualConfidence && a.soundEvents == b.soundEvents
        && a.speechTranscript == b.speechTranscript && a.speechAvailable == b.speechAvailable
        && a.musicPresence == b.musicPresence && a.musicTempoEnergy == b.musicTempoEnergy
        && a.editDensityCutsPerMinute == b.editDensityCutsPerMinute && a.elapsedItemMs == b.elapsedItemMs
    }

    // MARK: 1. Corpus / split honesty

    func testCorpusActualScenarioCountIs18NotTheClaimed17() {
        // Builder docs + the TUNE print claim "17 scenarios"; the corpus actually contains 18.
        XCTAssertEqual(P009BCorpusV1.corpus(seed: 0).count, 18,
                       "AUDIT-FINDING (claim accuracy): corpus has 18 scenarios; docs/prints say 17")
    }

    func testSplitSeedsCollapseToTwoDistinctInputSets() {
        // seed only acts through seed % 2 → STRESS(2) is byte-identical to TUNE(0), OOD(3) to HELD-OUT(1),
        // and CALIBRATION-RESERVED(9) is structurally identical to HELD-OUT(1).
        let tune = P009BCorpusV1.corpus(seed: 0), heldout = P009BCorpusV1.corpus(seed: 1)
        let stress = P009BCorpusV1.corpus(seed: 2), ood = P009BCorpusV1.corpus(seed: 3)
        let cal = P009BCorpusV1.corpus(seed: 9)
        for i in tune.indices {
            XCTAssertTrue(inputsEqual(tune[i].input, stress[i].input),
                          "AUDIT-FINDING (split vacuity): STRESS seed 2 input ≡ TUNE seed 0 input (\(tune[i].name))")
            XCTAssertTrue(inputsEqual(heldout[i].input, ood[i].input),
                          "AUDIT-FINDING (split vacuity): OOD seed 3 input ≡ HELD-OUT seed 1 input (\(heldout[i].name))")
            XCTAssertTrue(inputsEqual(heldout[i].input, cal[i].input),
                          "AUDIT-FINDING: CAL-RESERVED seed 9 ≡ HELD-OUT seed 1 (reservation is nominal only)")
            XCTAssertEqual(tune[i].expectEvidencePrefixes, heldout[i].expectEvidencePrefixes.map {
                $0.replacingOccurrences(of: "language:tr", with: "language:en") },
                "expectations are shared across splits (template shared by construction) — \(tune[i].name)")
        }
    }

    // MARK: 2. Stale-generation attachment / cache-firewall interaction

    func testStaleContextStillReceivesCacheHitsForItsOldItem() {
        // CHARACTERIZATION: the §21 generation firewall guards EXECUTED results only. A context captured
        // before identityChanged() still receives cached evidence (old generation, stale=false) for its
        // item raw. Legal only under the unenforced invariant that item raws are never reused for
        // different content. Recorded as a limitation, not a crossing-identities exploit per se.
        let b = makeBrain()
        let input = ExpertInputV2(ocrText: "learn science lesson", detectedLanguage: "en")
        let staleCtx = ctx(b, item: 77)                     // generation g1
        _ = b.route(input: input, context: staleCtx, nowMs: 0)   // fills cache for item 77
        b.identityChanged(); b.identityChanged()                 // g3 now current
        let r = b.route(input: input, context: staleCtx, nowMs: 1)
        XCTAssertFalse(r.cacheHits.isEmpty,
                       "AUDIT-FINDING (limitation): cache path bypasses the generation stale firewall")
        XCTAssertTrue(r.evidence.contains { $0.generation < b.currentGeneration && !$0.stale },
                      "cached evidence carries the old generation yet is served as live")
        XCTAssertTrue(r.executed.isEmpty, "no NEW stale work was executed — executed-path firewall holds")
    }

    func testFreshItemAfterIdentityChangeGetsNoForeignCache() {
        // The safe direction: a NEW item raw can never receive another item's cached evidence.
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(ocrText: "learn lesson", detectedLanguage: "en"), context: ctx(b, item: 80), nowMs: 0)
        b.identityChanged()
        let r = b.route(input: ExpertInputV2(ocrText: "learn lesson", detectedLanguage: "en"), context: ctx(b, item: 81), nowMs: 1)
        XCTAssertTrue(r.cacheHits.isEmpty, "different item raw → zero cache reuse (no cross-identity attachment)")
        XCTAssertTrue(r.evidence.allSatisfy { $0.generation == b.currentGeneration || !$0.inputModalityAvailable })
    }

    func testBusFirewallExcludesOldGenerationEvidenceCompletely() {
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(ocrText: "deadly disaster", detectedLanguage: "en"), context: ctx(b, item: 90), nowMs: 0)
        let oldGen = b.currentGeneration
        b.identityChanged()
        XCTAssertEqual(b.bus.forItem(ContentItemID(90), generation: b.currentGeneration).count, 0, "new gen sees nothing")
        XCTAssertEqual(b.bus.forItem(ContentItemID(90), generation: oldGen).count, 0,
                       "old-generation evidence is marked stale — not retrievable even under its own generation")
        XCTAssertGreaterThan(b.bus.staleCount, 0)
    }

    // MARK: 3. Cache poisoning / collision / model-version

    func testCacheIsInputInsensitive_CollisionNeedsManualInvalidation() {
        // CHARACTERIZATION: cache key = (item, domain, modelVersion). Same confirmed item raw with
        // DIFFERENT content returns the FIRST result; nothing auto-detects the collision.
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(ocrText: "calm nature forest", detectedLanguage: "en"),
                    context: ctx(b, item: 100, domains: [.languageOCR]), nowMs: 0)
        let r2 = b.route(input: ExpertInputV2(ocrText: "deadly war death disaster", detectedLanguage: "en"),
                         context: ctx(b, item: 100, domains: [.languageOCR]), nowMs: 1)
        XCTAssertTrue(r2.cacheHits.contains(.languageOCR),
                      "AUDIT-FINDING (limitation): identity collision is NOT auto-detected; re-analysis requires explicit invalidate(item:)")
        XCTAssertFalse(r2.evidence.flatMap { $0.labels }.contains("topic:mortality"),
                       "risky second content was NOT analyzed — stale first understanding served")
        // the documented remedy works when invoked:
        b.cache.invalidate(item: ContentItemID(100))
        let r3 = b.route(input: ExpertInputV2(ocrText: "deadly war death disaster", detectedLanguage: "en"),
                         context: ctx(b, item: 100, domains: [.languageOCR]), nowMs: 2)
        XCTAssertTrue(r3.evidence.flatMap { $0.labels }.contains("topic:mortality"), "invalidate → re-analysis")
    }

    func testLowInformationEvidencePoisonsPerItemCache() {
        // CHARACTERIZATION: a no-validated-events audio result (confidence 0.2) is cached for the
        // confirmed item; a later route with REAL validated audio for the same item gets the cached
        // low-information record and the real audio is never analyzed.
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(soundEvents: ["quantum-hum"]), context: ctx(b, item: 110, domains: [.audioEvent]), nowMs: 0)
        let r2 = b.route(input: ExpertInputV2(soundEvents: ["siren", "alarm"]), context: ctx(b, item: 110, domains: [.audioEvent]), nowMs: 1)
        XCTAssertTrue(r2.cacheHits.contains(.audioEvent),
                      "AUDIT-FINDING (limitation): low-information evidence is cached and suppresses later real analysis for the item")
        XCTAssertFalse(r2.evidence.flatMap { $0.labels }.contains("audio:siren"))
    }

    func testUnavailableResultBurnsDeepDedupeBudget_PermanentBlindness() {
        // Safe direction confirmed: .unavailable factory evidence has itemID nil → the cache refuses it.
        // DEFECT discovered by this probe: ResourceGovernorV2.requestDeep consumes the once-per-(item,domain)
        // deep budget BEFORE evaluation, even when the expert then returns honest UNAVAILABLE (no deep work
        // happened). A later route with REAL provider input for the same item is refused via deep-dedupe —
        // transient provider absence becomes PERMANENT per-item blindness for cost ≥ 5 experts
        // (vision/speech) within the governor's lifetime. Violates the §18/§22 re-analysis intent.
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(), context: ctx(b, item: 120, domains: [.vision]), nowMs: 0)
        XCTAssertEqual(b.cache.count, 0, "honest UNAVAILABLE results never enter the durable cache (good)")
        let r2 = b.route(input: ExpertInputV2(visualLabels: ["cat"], visualConfidence: 0.9),
                         context: ctx(b, item: 120, domains: [.vision]), nowMs: 1)
        // R1-FIX INVERSION (F1; see docs/audit/P009B_R1_AUDIT_FINDINGS_LOCK.md — original characterization
        // asserted the DEFECT: "later real input is NEVER analyzed"). DeepAnalysisLeaseStateV1 now releases
        // the lease on transient UNAVAILABLE, so the later real input IS analyzed and no dedupe refusal fires.
        XCTAssertTrue(r2.evidence.flatMap { $0.labels }.contains("scene:cat"),
                      "R1 F1 FIXED: transient UNAVAILABLE released the lease — later real input IS analyzed")
        XCTAssertFalse(r2.unknownReasons.contains { $0.hasPrefix("deep-dedupe:VISION") },
                       "no dedupe refusal — the budget was never burned by the UNAVAILABLE result")
    }

    func testModelVersionBumpMissesOldCache() {
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(ocrText: "learn", detectedLanguage: "en"), context: ctx(b, item: 130, domains: [.languageOCR]), nowMs: 0)
        XCTAssertNil(b.cache.lookup(item: ContentItemID(130), domain: .languageOCR, modelVersion: "language-ocr-expert-v2/FUTURE"),
                     "a new model version can never be served stale old-version evidence")
        XCTAssertNotNil(b.cache.lookup(item: ContentItemID(130), domain: .languageOCR, modelVersion: "language-ocr-expert-v1/lexicon-v1"))
    }

    // MARK: 4. Provisional identity / DNA leaks

    func testProvisionalItemsNeverCacheAcrossAnyDomain() {
        let b = makeBrain()
        let rich = ExpertInputV2(ocrText: "learn science", detectedLanguage: "en", visualLabels: ["book"], visualConfidence: 0.9,
                                 soundEvents: ["music"], speechTranscript: "hello", speechAvailable: true,
                                 musicPresence: true, musicTempoEnergy: 0.5, editDensityCutsPerMinute: 10)
        _ = b.route(input: rich, context: ctx(b, item: 140, provisional: true), nowMs: 0)
        XCTAssertEqual(b.cache.count, 0, "provisional identity must leave ZERO durable cache entries")
    }

    func testDNAMintTrustsCallerFlag_ProvisionalEvidenceCanMintIfCallerLies() {
        // CHARACTERIZATION/DEFECT: mint() checks the caller-passed itemProvisional flag and
        // state.contentDNAReady, but does NOT cross-check the evidence records' own itemProvisional
        // markers. A caller that wrongly passes itemProvisional=false to BOTH build() and mint() mints
        // durable DNA from provisional-marked evidence.
        let b = makeBrain()
        let r = b.route(input: ExpertInputV2(ocrText: "learn science lesson", detectedLanguage: "en"),
                        context: ctx(b, item: 150, provisional: true), nowMs: 0)
        XCTAssertTrue(r.evidence.contains { $0.itemProvisional }, "evidence is provisional-marked")
        let g = CrossModalExpertGraphV1(); g.relate(r.evidence)
        let lyingState = ContentUnderstandingStateV1.build(itemProvisional: false, evidence: r.evidence,
                                                           graph: g, registry: b.registry, unknownReasons: [])
        let dna = ContentDNACandidateV2.mint(from: lyingState, itemID: ContentItemID(150), itemProvisional: false,
                                             dnaRaw: 9, nowMs: 0, modelVersions: ["m"])
        // R1-FIX INVERSION (F7; see lock doc — original characterization asserted the DEFECT: the spoof
        // minted). mint() now verifies the evidence-level provisional markers recorded in the state —
        // a lying caller gets nil.
        XCTAssertNil(dna,
            "R1 F7 FIXED: evidence-level provisional markers are verified — a lying caller cannot mint DNA")
    }

    func testHonestPathProvisionalDNAStaysNil() {
        let b = makeBrain()
        let r = b.route(input: ExpertInputV2(ocrText: "learn", detectedLanguage: "en"), context: ctx(b, item: 160, provisional: true), nowMs: 0)
        let g = CrossModalExpertGraphV1(); g.relate(r.evidence)
        let st = ContentUnderstandingStateV1.build(itemProvisional: true, evidence: r.evidence, graph: g,
                                                   registry: b.registry, unknownReasons: r.unknownReasons)
        XCTAssertFalse(st.contentDNAReady)
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, itemID: ContentItemID(160), itemProvisional: true,
                                                dnaRaw: 1, nowMs: 0, modelVersions: ["m"]))
        // and with an inconsistent combination (flag says confirmed, state says not ready) it still refuses:
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, itemID: ContentItemID(160), itemProvisional: false,
                                                dnaRaw: 1, nowMs: 0, modelVersions: ["m"]),
                     "contentDNAReady=false blocks mint even if the flag is forged")
    }

    // MARK: 5. Quarantine — new malformed variants the builder did not test

    func testQuarantineVariantsBeyondBuilderSet() {
        let b = makeBrain()
        b.beginObservation(ObservationID(7))
        func h(gap: Double = 10, dwell: Double = 10, elapsed: Double = 10, theme: Double = 0.2, proj: Double = 0.1,
               hist: Double = 0.2, chrome: Double = 0.2, regional: Double = 0.2, obs: UInt64 = 7,
               shot: UInt64 = 3, item: UInt64 = 5, versions: [String] = ["v1"]) -> Tier1IdentityHandoffV1 {
            Tier1IdentityHandoffV1(observationID: ObservationID(obs), shotID: ShotID(shot), provisionalItemID: ContentItemID(item),
                                   transitionType: .cut, gapSinceLastBoundaryMs: gap, previousShotDwellMs: dwell,
                                   elapsedItemMs: elapsed, themeDistance: theme, projectionCorrelation: proj,
                                   histogramDistance: hist, chromeDistance: chrome, regionalDistance: regional,
                                   ambiguityReason: "", strongNew: false, priorRelation: .ambiguous,
                                   thermalBucket: .nominal, capabilityProfile: "T0", modelPolicyVersions: versions)
        }
        let c = b.handoffConsumer
        XCTAssertEqual(c.consume(h(item: 0), currentObservation: b.currentObservation), .quarantined, "zero provisional item ID")
        XCTAssertEqual(c.consume(h(regional: 1.5), currentObservation: b.currentObservation), .quarantined, "regional out of range")
        XCTAssertEqual(c.consume(h(chrome: -0.01), currentObservation: b.currentObservation), .quarantined, "chrome below range")
        XCTAssertEqual(c.consume(h(proj: -2), currentObservation: b.currentObservation), .quarantined, "correlation below -1")
        XCTAssertEqual(c.consume(h(elapsed: .infinity), currentObservation: b.currentObservation), .quarantined, "elapsed ∞")
        XCTAssertEqual(c.consume(h(dwell: .nan), currentObservation: b.currentObservation), .quarantined, "dwell NaN")
        XCTAssertEqual(c.consume(h(elapsed: -1e-9), currentObservation: b.currentObservation), .quarantined, "negative epsilon timestamp")
        // compound poison: NaN + stale session + missing version in ONE record — must not crash, one quarantine
        XCTAssertEqual(c.consume(h(hist: .nan, obs: 999, versions: []), currentObservation: b.currentObservation), .quarantined)
        XCTAssertEqual(c.quarantinedCount, 8)
        XCTAssertTrue(c.accepted.isEmpty, "no quarantined record may create accepted/positive state")
        XCTAssertTrue(c.quarantineReasons.contains { $0.contains("non-finite:hist") })
        XCTAssertTrue(c.quarantineReasons.contains { $0.contains("stale-session") })
        // and a clean record still passes AFTER the poison flood (no sticky failure state)
        XCTAssertEqual(c.consume(h(), currentObservation: b.currentObservation), .accepted)
    }

    // MARK: 6. Score display bypass attempts

    func testScoreDisplayStructurallyImpossible() {
        let b = makeBrain()
        XCTAssertFalse(b.calibration.scoreDisplayAllowed())
        for d in ExpertDomainV2.allCases {
            for lang in ["tr", "en", "", "und", "xx"] {
                XCTAssertFalse(b.calibration.isCalibrated(domain: d, language: lang))
            }
        }
        XCTAssertTrue(Mirror(reflecting: b.calibration).children.isEmpty,
                      "calibration skeleton holds NO mutable state — there is nothing to flip at runtime")
        // no evidence record across all seeds can ever claim calibrated status
        for seed in [0, 1, 2, 3] {
            for (i, s) in P009BCorpusV1.corpus(seed: seed).enumerated() {
                let brain = makeBrain()
                let r = P009BCorpusV1.runScenario(s, brain: brain, item: ContentItemID(UInt64(i + 1)), nowMs: 0)
                XCTAssertTrue(r.route.evidence.allSatisfy { $0.calibrationStatus != .implementedCalibrated })
            }
        }
    }

    // MARK: 7. Capability-profile escalation attempts

    func testCapabilityEscalationDenied() {
        let b = makeBrain()
        let rich = ExpertInputV2(ocrText: "deadly ⚠ learn lesson", detectedLanguage: "en", visualLabels: ["x"],
                                 visualConfidence: 0.9, soundEvents: ["siren"], speechTranscript: "t", speechAvailable: true,
                                 musicPresence: true, editDensityCutsPerMinute: 40)
        // Tier-0: even with ALL experts registered and rich input, only temporal may run — symbol (REAL_RUNTIME,
        // cost 1) must also be refused.
        let r0 = b.route(input: rich, context: ctx(b, item: 200, provisional: true, profile: .extensionFastTier0), nowMs: 0)
        XCTAssertEqual(Set(r0.executed), Set([.temporal]), "Tier-0 executes temporal ONLY")
        XCTAssertTrue(r0.unavailable.contains(.symbol) && r0.unavailable.contains(.safetyEvidence))
        XCTAssertTrue(r0.unknownReasons.contains { $0 == "profile-forbids:SYMBOL" })
        // TIER1_LITE and FUTURE_SHARED: zero execution, all honest refusals
        for p in [RuntimeCapabilityProfileV2.extensionTier1Lite, .futureSharedTier1] {
            let r = b.route(input: rich, context: ctx(b, item: 201, profile: p), nowMs: 0)
            XCTAssertTrue(r.executed.isEmpty && r.cacheHits.isEmpty, "\(p): nothing may run")
            XCTAssertEqual(r.unavailable.count, ExpertDomainV2.allCases.count)
        }
    }

    // MARK: 8. Thermal law

    func testThermalSeriousDeniesEvenCallerDeclaredSafetyCriticalHeavyExperts() {
        let b = makeBrain()
        b.governor.setThermal(.serious)
        // adversarial caller marks heavy experts as safety-critical — cost ≥ 3 must still be denied
        let r = b.route(input: ExpertInputV2(ocrText: "x", detectedLanguage: "en", visualLabels: ["v"], visualConfidence: 0.9,
                                             speechTranscript: "s", speechAvailable: true),
                        context: ctx(b, item: 210), safetyCritical: [.vision, .speech, .languageOCR], nowMs: 0)
        XCTAssertFalse(r.executed.contains(.vision), "SERIOUS: heavy expert denied even when declared safety-critical")
        XCTAssertFalse(r.executed.contains(.speech))
        XCTAssertFalse(r.executed.contains(.languageOCR), "cost-3 expert denied at SERIOUS")
    }

    func testThermalCriticalMinimumSafePath() {
        let b = makeBrain()
        b.governor.setThermal(.critical)
        let r = b.route(input: ExpertInputV2(ocrText: "deadly disaster", detectedLanguage: "en", visualLabels: ["v"], visualConfidence: 0.9),
                        context: ctx(b, item: 220), nowMs: 0)
        // default safety-critical set = {safetyEvidence(2), temporal(1)} — both cost < 3 → run; all else deferred
        XCTAssertEqual(Set(r.executed).subtracting([.safetyEvidence, .temporal]), [],
                       "CRITICAL: only cheap safety-critical experts may run")
        XCTAssertFalse(r.unknownReasons.isEmpty, "degrades to honesty (UNKNOWN reasons), not silence")
        XCTAssertFalse(r.deferredThermal.isEmpty)
    }

    func testThermalFairMatchesDocumentedBoundary() {
        // Doc law: FAIR defers cost ≥ 5 non-safety-critical. audioEvent (cost 4) therefore RUNS at FAIR.
        let b = makeBrain()
        b.governor.setThermal(.fair)
        let r = b.route(input: ExpertInputV2(visualLabels: ["v"], visualConfidence: 0.9, soundEvents: ["siren"]),
                        context: ctx(b, item: 230, domains: [.vision, .audioEvent]), nowMs: 0)
        XCTAssertTrue(r.deferredThermal.contains(.vision), "cost 5 deferred at FAIR")
        XCTAssertTrue(r.executed.contains(.audioEvent), "cost 4 runs at FAIR — matches the frozen doc boundary")
    }

    // MARK: 9. Safety dominance — benefit can never outvote/suppress risk

    func testBenefitFloodCannotSuppressRiskEvidence() {
        let b = makeBrain()
        // many benefit hits + one mortality trigger
        let text = "learn how to tutorial lesson guide science history explain — the deadly war death toll"
        let r = b.route(input: ExpertInputV2(ocrText: text, detectedLanguage: "en"), context: ctx(b, item: 240), nowMs: 0)
        let labels = r.route_evidenceLabels
        XCTAssertTrue(labels.contains("safety:sensitive-death-disease-news"), "risk evidence survives benefit flood")
        XCTAssertTrue(labels.contains("benefit:educational-candidate"))
        let g = CrossModalExpertGraphV1(); g.relate(r.evidence)
        XCTAssertFalse(g.contradictions.isEmpty, "risk-vs-positive is represented as CONTRADICTS — never vote-resolved")
        // there is no aggregation API that could produce a fused verdict/score in P009B — understanding
        // state carries BOTH lists verbatim:
        let st = ContentUnderstandingStateV1.build(itemProvisional: false, evidence: r.evidence, graph: g,
                                                   registry: b.registry, unknownReasons: [])
        XCTAssertFalse(st.safetyEvidence.isEmpty)
        XCTAssertFalse(st.benefitEvidence.isEmpty)
    }

    func testTemporalMonotoneMaxSurvivesNaNAndInfinityInjection() {
        let t = TemporalExpertV1()
        t.observe(riskLevel: 0.9, topicLabels: [])
        t.observe(riskLevel: .nan, topicLabels: [])          // NaN must not corrupt the monotone max
        t.observe(riskLevel: -.infinity, topicLabels: [])    // -∞ must not lower it
        t.observe(riskLevel: 0, topicLabels: [])
        let b = makeBrain()
        let ev = t.evaluate(ExpertInputV2(), context: ctx(b, item: 1))
        XCTAssertEqual(ev.features["maxRisk"], 0.9, "benign/NaN/-∞ later values can never lower escalated risk")
        XCTAssertTrue(ev.labels.contains("temporal:risk-escalated"))
        let t2 = TemporalExpertV1()
        t2.observe(riskLevel: .infinity, topicLabels: [])    // +∞ clamps to 1 — fails SAFE (escalates)
        let ev2 = t2.evaluate(ExpertInputV2(), context: ctx(b, item: 2))
        XCTAssertEqual(ev2.features["maxRisk"], 1.0)
    }

    // MARK: 10. Honest unavailability under fuzz — no expert may be made to guess

    func testNoExpertGuessesUnderNaNFuzz() {
        let b = makeBrain()
        let fuzz = ExpertInputV2(ocrText: nil, detectedLanguage: nil, visualLabels: ["x"], visualConfidence: .nan,
                                 soundEvents: nil, speechTranscript: nil, speechAvailable: false,
                                 musicPresence: true, musicTempoEnergy: .infinity,
                                 editDensityCutsPerMinute: .nan, elapsedItemMs: .nan)
        let r = b.route(input: fuzz, context: ctx(b, item: 250), nowMs: 0)
        // vision: NaN confidence clamps to 0 → OOD, no crash, no confident claim
        if let v = r.evidence.first(where: { $0.domain == .vision && $0.inputModalityAvailable }) {
            XCTAssertEqual(v.confidence, 0); XCTAssertTrue(v.oodIndicator)
            // R1-FIX INVERSION (§7; see lock doc — original characterization asserted the DEFECT: NaN
            // editDensity flowed into features). ExpertInputSanitizerV2 now drops it pre-execution.
            XCTAssertNil(v.features["editDensity"],
                         "R1 §7 FIXED: NaN editDensity is stripped before any expert sees the bundle")
        } else { XCTFail("vision should evaluate (labels present)") }
        // music: ∞ tempo is dropped by the isFinite guard
        if let m = r.evidence.first(where: { $0.domain == .music }) {
            XCTAssertNil(m.features["tempoEnergy"], "∞ tempo never enters evidence")
        }
        // nothing fabricates topics/scenes beyond provided labels; no calibrated claims
        let labels = r.route_evidenceLabels
        XCTAssertFalse(labels.contains { $0.hasPrefix("topic:") })
        XCTAssertTrue(r.evidence.allSatisfy { $0.calibrationStatus != .implementedCalibrated })
    }

    func testEmptyInputAbstentionTruth() {
        let b = makeBrain()
        let r = b.route(input: ExpertInputV2(), context: ctx(b, item: 260), nowMs: 0)
        // every provider-fed expert must be explicitly unavailable from an empty bundle
        for e in r.evidence where e.domain != .temporal && e.domain != .safetyEvidence {
            XCTAssertFalse(e.inputModalityAvailable, "\(e.domain) must not invent evidence from nothing")
        }
        // CHARACTERIZATION: SafetyEvidenceExpertV1 and TemporalExpertV1 ALWAYS emit available records
        // (coverage 0 / status labels). Consequence: the route's `all-modalities-unavailable` UNKNOWN
        // reason can NEVER fire when safety/temporal are among the requested domains — contradicting the
        // STRESS/OOD doc claim that the all-unavailable corpus scenario "reports all-modalities-unavailable".
        XCTAssertTrue(r.evidence.contains { $0.domain == .safetyEvidence && $0.inputModalityAvailable && $0.coverage == 0 })
        XCTAssertFalse(r.unknownReasons.contains("all-modalities-unavailable"),
                       "AUDIT-FINDING (doc contradiction): reason does not fire on the full-domain empty-input path")
        // no fabricated semantics anywhere, and abstention is still visible via UNAVAILABLE records
        XCTAssertFalse(r.evidence.flatMap { $0.labels }.contains { $0.hasPrefix("topic:") || $0.hasPrefix("scene:") })
        XCTAssertTrue(r.evidence.contains { !$0.inputModalityAvailable })
        // and the reason DOES fire when only provider-fed domains are requested:
        let r2 = b.route(input: ExpertInputV2(), context: ctx(b, item: 261, domains: [.vision, .audioEvent]), nowMs: 1)
        XCTAssertTrue(r2.unknownReasons.contains("all-modalities-unavailable"))
    }

    // MARK: 11. Duplicate scheduling

    func testDuplicateDomainInOneRouteDoesNotDoubleExecuteHeavyExpert() {
        let b = makeBrain()
        let r = b.route(input: ExpertInputV2(visualLabels: ["cat"], visualConfidence: 0.9),
                        context: ctx(b, item: 270, provisional: true, domains: [.vision, .vision, .vision]), nowMs: 0)
        XCTAssertEqual(r.executed.filter { $0 == .vision }.count, 1, "duplicate heavy scheduling collapses to one run")
        XCTAssertTrue(r.unknownReasons.contains { $0.hasPrefix("deep-dedupe:VISION") })
    }

    // MARK: 12. Runtime health / latency instrumentation truth

    func testRouteLatencyInstrumentationIsStructurallyZero() {
        // R1-FIX INVERSION (§8; see lock doc — original characterization asserted the DEFECT: every latency
        // was structurally 0 from a single caller-supplied snapshot). route() now measures with a monotonic
        // clock; samples are real and the full set can no longer be pinned to zero.
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(ocrText: "learn lesson now", detectedLanguage: "en"), context: ctx(b, item: 280), nowMs: 1234.5)
        let snap = b.registry.health.snapshot()
        let all = snap.values.flatMap { $0.latenciesMs }
        XCTAssertFalse(all.isEmpty)
        XCTAssertTrue(all.allSatisfy { $0 >= 0 && $0.isFinite })
        XCTAssertFalse(all.allSatisfy { $0 == 0 },
                       "R1 §8 FIXED: per-expert latency is a real monotonic measurement, not structural zero")
        XCTAssertNotNil(b.latency.percentiles("route"), "route-level latency is measured")
    }

    // MARK: 13. §19 asset law

    func testAssetLedgerCannotApproveUnclearLicense() {
        let unclear = ExternalIntelligenceAssetAuditV1(assetName: "mystery-model", provider: "unknown",
                                                       licenseClass: .unclearDoNotIntegrate,
                                                       licenseEvidence: "none found", provenance: "unknown",
                                                       auditedAtISO8601: "2026-10-19")
        XCTAssertFalse(unclear.integrationApproved, "§19: unclear license can NEVER be integration-approved")
        XCTAssertTrue(P009BAssetAuditLedgerV1.allIntegrationsLawful)
        XCTAssertTrue(P009BAssetAuditLedgerV1.records.allSatisfy {
            $0.licenseClass == .appleSystemFramework || $0.licenseClass == .projectAuthored },
            "P009B integrated zero third-party model assets — verified")
    }
}

private extension MetaBrainRouteV2 {
    var route_evidenceLabels: [String] { evidence.flatMap { $0.labels } }
}
