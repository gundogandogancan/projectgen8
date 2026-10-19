import XCTest
@testable import GuardianCore

// AUDIT7 — INDEPENDENT P009D RED-TEAM PROBES (add-only; no production source modified).
// Fresh adversarial scenarios authored by the independent auditor against tag gen8-p009d-audit-candidate
// (b50f592). Every probe uses NEW surface tokens (never corpus text) unless a lexicon hit is the point.
// Probes that PIN a suspicious behavior say so explicitly — a pinned behavior is reported as a FINDING
// in docs/audit/GEN8_P009D_INDEPENDENT_AUDIT_REPORT.md, not silently accepted.

final class AUDIT7_P009DProbes: XCTestCase {

    func makeBrain() -> GuardianMetaBrainV2 {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1()); b.registry.register(LanguageOCRExpertV1())
        b.registry.register(SpeechExpertV1()); b.registry.register(AudioEventExpertV1())
        b.registry.register(MusicExpertV1()); b.registry.register(SymbolExpertV1())
        b.registry.register(TemporalExpertV1()); b.registry.register(SafetyEvidenceExpertV1())
        b.registry.register(BenefitEvidenceExpertV1()); b.registry.register(AttentionPressureExpertV1())
        return b
    }
    func seg(_ s: Double, _ e: Double, _ i: ExpertInputV2, risk: Double = 0, topics: Set<String> = []) -> P009CSegmentV1 {
        P009CSegmentV1(startMs: s, endMs: e, input: i, temporalRisk: risk, temporalTopics: topics)
    }
    func run(_ name: String, segments: [P009CSegmentV1],
             child: GuardianEnteredChildProfileV1? = nil,
             parent: ParentPreferencePolicyV1 = ParentPreferencePolicyV1(),
             shield: ShieldConfigV2? = nil, item: UInt64 = 7001,
             provisional: Bool = false) -> (ContentWorldModelV1, AdmissionStateCandidateV1) {
        let s = P009DPolicyScenarioV1(name: name, family: "audit7", segments: segments,
                                      childProfile: child, parentPreference: parent,
                                      shieldConfig: shield, annotation: P009DPolicyAnnotationV1())
        return P009DPolicyCorpusV1.run(s, brain: makeBrain(), item: ContentItemID(item), provisional: provisional)
    }
    func codes(_ d: AdmissionStateCandidateV1) -> Set<String> {
        Set(([d.dominantReason] + d.secondaryReasons).map { $0.code.rawValue })
    }
    func allStrings(_ d: AdmissionStateCandidateV1) -> [String] {
        ([d.dominantReason] + d.secondaryReasons).flatMap { [$0.basis, $0.producer, $0.code.rawValue] }
            + d.unresolvedConflicts
            + (d.shieldOutcome.map { $0.topicMatches + $0.entityMatches + $0.sensitiveMatches
                                     + $0.preferredMatches + $0.advisoryGuessNotes + [$0.shieldVersion] } ?? [])
            + [d.state.rawValue, d.versions.policyEngine, d.versions.taxonomy, d.versions.ageRegistry,
               d.versions.jurisdiction, d.versions.shield, d.versions.worldModel, d.versions.safetyDimensionTruth]
            + d.versions.meshModelVersions
    }

    // ── P1: benefit flood + severe risk (fresh tokens) — benefit can NEVER override strong protection ──
    func testP1_BenefitFloodVsSevereRisk() {
        let text = String(repeating: "science tutorial explain history ", count: 25)
            + "funeral obituary fatal casualties"
        let (_, d) = run("a7-benefit-flood", segments: [seg(0, 5000,
            ExpertInputV2(ocrText: text, detectedLanguage: "en", soundEvents: ["siren"]), risk: 0.92, topics: ["war"])],
            child: GuardianEnteredChildProfileV1(ageYears: 10, jurisdictionCode: "TR", enteredByGuardian: true),
            shield: ShieldConfigV2(preferredConcepts: ["concept:education"]))
        XCTAssertEqual(d.state, .strongProtection, "benefit flood must not dilute strong protection")
        XCTAssertTrue(codes(d).contains("STRONG_RISK_ESCALATION"))
        XCTAssertTrue(codes(d).contains("BENEFIT_PRESENT_NOT_OVERRIDING"), "benefit recorded, never overriding")
        XCTAssertNotEqual(d.state, .neutral)
    }

    // ── P2: humor + explicit claim, child 9 — explicit dim UNAVAILABLE ⇒ fail closed, never NEUTRAL ──
    func testP2_HumorPlusExplicitChildFailsClosed() {
        let (m, d) = run("a7-humor-explicit", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "standup comedy special: uncensored explicit adult material haha",
                          detectedLanguage: "en"))],
            child: GuardianEnteredChildProfileV1(ageYears: 9, jurisdictionCode: "US", enteredByGuardian: true))
        XCTAssertNotEqual(d.state, .neutral, "child + unscreenable claim must not be NEUTRAL")
        XCTAssertTrue(codes(d).contains("AGE_H1_REQUIRED_UNAVAILABLE"), "<13 H1 gap must be visible")
        let explicit = SafetyPolicyEngineV1.evaluate(worldModel: m).findings.first { $0.dimension == .explicitSexual }!
        XCTAssertEqual(explicit.status, .unavailable)
        XCTAssertFalse(explicit.evidencePresent, "UNAVAILABLE dimension can neither clear nor convict")
    }

    // ── P3: prevention-context vs literal encouragement self-harm — MUST fail closed IDENTICALLY.
    // The self-harm dimension is UNAVAILABLE: any divergence between the two would be a fake distinction. ──
    func testP3_PreventionVsEncouragementIdenticalFailClosed() {
        let child = GuardianEnteredChildProfileV1(ageYears: 12, jurisdictionCode: "TR", enteredByGuardian: true)
        let (m1, d1) = run("a7-sh-prevention", segments: [seg(0, 4000,
            ExpertInputV2(ocrText: "support line guide: helping a friend recover and heal", detectedLanguage: "en"))],
            child: child, item: 7301)
        let (m2, d2) = run("a7-sh-encouragement", segments: [seg(0, 4000,
            ExpertInputV2(ocrText: "viral trend: everyone should try hurting themselves for views", detectedLanguage: "en"))],
            child: child, item: 7302)
        XCTAssertEqual(d1.childOutcome, d2.childOutcome, "no fake prevention/encouragement split from an UNAVAILABLE dim")
        XCTAssertEqual(d1.state, d2.state, "identical fail-closed admission")
        XCTAssertEqual(d1.childOutcome, .unknownReview)
        XCTAssertNotEqual(d1.state, .neutral); XCTAssertNotEqual(d2.state, .neutral)
        for m in [m1, m2] {
            let f = SafetyPolicyEngineV1.evaluate(worldModel: m).findings.first { $0.dimension == .selfHarm }!
            XCTAssertEqual(f.status, .unavailable); XCTAssertFalse(f.evidencePresent)
        }
        XCTAssertTrue(codes(d1).contains("AGE_H1_REQUIRED_UNAVAILABLE"))
        XCTAssertTrue(codes(d2).contains("AGE_H1_REQUIRED_UNAVAILABLE"))
    }

    // ── P4: drug education vs promotion — dimension UNAVAILABLE ⇒ no invented distinction ──
    func testP4_DrugEducationVsPromotionNoInventedDistinction() {
        let child = GuardianEnteredChildProfileV1(ageYears: 12, jurisdictionCode: "EU", enteredByGuardian: true)
        let (m1, d1) = run("a7-drug-edu", segments: [seg(0, 4000,
            ExpertInputV2(ocrText: "chemistry course: substance abuse risks explained for class", detectedLanguage: "en"))],
            child: child, item: 7401)
        let (m2, d2) = run("a7-drug-promo", segments: [seg(0, 4000,
            ExpertInputV2(ocrText: "best party pills cheap deals delivered discreet", detectedLanguage: "en"))],
            child: child, item: 7402)
        for m in [m1, m2] {
            let f = SafetyPolicyEngineV1.evaluate(worldModel: m).findings.first { $0.dimension == .drugsAlcohol }!
            XCTAssertEqual(f.status, .unavailable); XCTAssertFalse(f.evidencePresent, "drugs dim never fires")
        }
        XCTAssertEqual(d1.childOutcome, d2.childOutcome, "no edu-vs-promo drug distinction can be invented")
        XCTAssertEqual(d1.childOutcome, .unknownReview, "<13 fail-closed floor")
        XCTAssertFalse(codes(d1).union(codes(d2)).contains("CHILD_AGE_RESTRICTED_EXPLICIT"))
    }

    // ── P5: gambling reporting vs promotion — gambling dim UNAVAILABLE; only IMPLEMENTED signals differ ──
    func testP5_GamblingReportingVsPromotion() {
        let (m1, d1) = run("a7-gambling-news", segments: [seg(0, 4000,
            ExpertInputV2(ocrText: "investigative report: casino fraud scheme and fatal fallout",
                          detectedLanguage: "en"), risk: 0.5, topics: ["news"])], item: 7501)
        let (m2, d2) = run("a7-gambling-promo", segments: [seg(0, 4000,
            ExpertInputV2(ocrText: "casino jackpot bonus free spins mega deals", detectedLanguage: "en"))], item: 7502)
        for m in [m1, m2] {
            let f = SafetyPolicyEngineV1.evaluate(worldModel: m).findings.first { $0.dimension == .gambling }!
            XCTAssertEqual(f.status, .unavailable); XCTAssertFalse(f.evidencePresent)
        }
        // the news item is distinguished ONLY by the implemented sensitive-news/mortality capability
        XCTAssertNotEqual(d1.state, .neutral, "mortality lexicon evidence → at least CAUTION")
        XCTAssertTrue(codes(d1).contains("H1_VISUAL_UNAVAILABLE"))
        XCTAssertTrue(codes(d2).contains("H1_VISUAL_UNAVAILABLE"))
        // honesty: NO gambling-specific reason code exists anywhere in the emitted set
        XCTAssertFalse(codes(d1).union(codes(d2)).contains { $0.lowercased().contains("gambling") })
    }

    // ── P6: mild cartoon vs severe realistic violence — violence dim UNAVAILABLE; severity comes only
    // from implemented lexical/temporal capability; both child paths fail closed ──
    func testP6_MildCartoonVsSevereRealisticViolence() {
        let child7 = GuardianEnteredChildProfileV1(ageYears: 7, jurisdictionCode: "TR", enteredByGuardian: true)
        let (m1, d1) = run("a7-mild-cartoon", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "silly cartoon chase scene giggles", detectedLanguage: "en"))],
            child: child7, item: 7601)
        let (m2, d2) = run("a7-severe-war", segments: [seg(0, 4000,
            ExpertInputV2(ocrText: "cephe görüntüleri: ölüm, cenaze ve yıkım her yerde",
                          detectedLanguage: "tr", soundEvents: ["siren"]), risk: 0.9, topics: ["war"])],
            child: child7, item: 7602)
        for m in [m1, m2] {
            let f = SafetyPolicyEngineV1.evaluate(worldModel: m).findings.first { $0.dimension == .violenceGore }!
            XCTAssertEqual(f.status, .unavailable, "violence/gore has no audited classifier — both ways")
        }
        XCTAssertEqual(d1.childOutcome, .unknownReview, "mild-looking cartoon cannot be cleared visually")
        XCTAssertNotEqual(d1.state, .neutral)
        XCTAssertEqual(d2.state, .strongProtection, "strong lexical risk escalates with H1 open")
        XCTAssertEqual(d2.childOutcome, .restricted)
    }

    // ── P7: age-band boundaries — sensitiveNews strong at 9/10 and present at 12/13 (TR) ──
    func testP7_AgeBandBoundaries() {
        func at(_ age: Int, _ item: UInt64) -> (ContentWorldModelV1, AdmissionStateCandidateV1) {
            run("a7-ageband-\(age)", segments: [seg(0, 4000,
                ExpertInputV2(ocrText: "vefat ve cenaze haberleri aktarılıyor", detectedLanguage: "tr"),
                risk: 0.65, topics: ["news"])],
                child: GuardianEnteredChildProfileV1(ageYears: age, jurisdictionCode: "TR", enteredByGuardian: true),
                item: item)
        }
        let (_, d9) = at(9, 7701); let (_, d10) = at(10, 7702)
        let (_, d12) = at(12, 7703); let (_, d13) = at(13, 7704)
        XCTAssertEqual(d9.childOutcome, .restricted, "strong sensitiveNews < 10 → AGE_RESTRICTED")
        XCTAssertEqual(d9.state, .ageRestricted)
        XCTAssertEqual(d10.childOutcome, .caution, "10 is on the non-restricted side of the strong band")
        XCTAssertEqual(d12.childOutcome, .caution, "sensitiveNews caution < 13")
        XCTAssertEqual(d13.childOutcome, .aligned, "13 outside caution band; H1 law applies <13 only")
        for d in [d9, d10, d12] { XCTAssertTrue(codes(d).contains("AGE_H1_REQUIRED_UNAVAILABLE"), "<13 H1 gap visible") }
        XCTAssertNotEqual(d13.state, .neutral, "evidence-bearing dimension still yields CAUTION for the content")
    }

    // ── P8: unsupported jurisdiction (a REAL code outside the registry) — fail closed ──
    func testP8_UnsupportedJurisdictionDE() {
        let (_, d) = run("a7-jurisdiction-de", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "quiet lake morning walk", detectedLanguage: "en",
                          visualLabels: ["lake"], visualConfidence: 0.8))],
            child: GuardianEnteredChildProfileV1(ageYears: 10, jurisdictionCode: "DE", enteredByGuardian: true))
        XCTAssertEqual(d.childOutcome, .unknownReview)
        XCTAssertEqual(d.state, .review)
        XCTAssertTrue(codes(d).contains("AGE_JURISDICTION_UNSUPPORTED"))
    }

    // ── P9: spoofed age-from-image — structurally impossible + unattested age fails closed ──
    func testP9_SpoofedAgeFromImagePaths() {
        // (a) there is NO image/face/visual input anywhere on the child profile or its engine signature
        let p = GuardianEnteredChildProfileV1(ageYears: 8, jurisdictionCode: "TR", enteredByGuardian: true)
        for child in Mirror(reflecting: p).children {
            let t = "\(type(of: child.value))"
            XCTAssertFalse(t.contains("CGImage") || t.contains("Image") || t.contains("Data") || t.contains("URL"),
                           "no visual/binary field on the guardian profile (\(child.label ?? "?"): \(t))")
        }
        // (b) an "age classifier" smuggler: content full of confident visual person labels + NO profile
        // must produce NO child outcome at all — age exists only via the guardian profile
        let (_, dNoProfile) = run("a7-visual-person-no-profile", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "street interview chat", detectedLanguage: "en",
                          visualLabels: ["person-speaking", "street"], visualConfidence: 0.95))], item: 7901)
        XCTAssertNil(dNoProfile.childOutcome, "no guardian profile ⇒ no child decision can exist")
        // (c) unattested (e.g. inferred elsewhere and injected) age fails closed with AGE_SOURCE_MISSING
        let (_, dSpoof) = run("a7-unattested-age", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "quiet forest walk video", detectedLanguage: "en"))],
            child: GuardianEnteredChildProfileV1(ageYears: 9, jurisdictionCode: "TR", enteredByGuardian: false),
            item: 7902)
        XCTAssertEqual(dSpoof.childOutcome, .unknownReview)
        XCTAssertTrue(codes(dSpoof).contains("AGE_SOURCE_MISSING"))
        XCTAssertEqual(dSpoof.state, .review)
    }

    // ── P10: shield canonical cross-language — ONE canonical config, TR and EN content both match ──
    func testP10_ShieldCrossLanguageBothDirections() {
        let config = ShieldConfigV2(blockedConcepts: ["concept:mortality"])
        let (_, dTR) = run("a7-shield-tr", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "vefat ve cenaze haberleri bülteni", detectedLanguage: "tr"))],
            shield: config, item: 8001)
        let (_, dEN) = run("a7-shield-en", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "funeral and obituary news bulletin", detectedLanguage: "en"))],
            shield: config, item: 8002)
        XCTAssertTrue(dTR.shieldOutcome?.hardMatch ?? false, "TR surface → canonical ID → match")
        XCTAssertTrue(dEN.shieldOutcome?.hardMatch ?? false, "EN surface → the SAME canonical ID → match")
        XCTAssertTrue(dTR.shieldOutcome?.topicMatches.contains("concept:mortality") ?? false)
        XCTAssertTrue(dEN.shieldOutcome?.topicMatches.contains("concept:mortality") ?? false)
        XCTAssertEqual(dTR.shieldOutcome?.matchConfidence, .exactCanonical)
        XCTAssertEqual(dEN.shieldOutcome?.matchConfidence, .exactCanonical)
    }

    // ── P11: shield near-match / raw-substring attack — prefix-of-a-real-ID and raw text must NEVER block ──
    func testP11_ShieldNearMatchAndRawSubstringNeverBlock() {
        // "concept:mortal" is a strict prefix of the real "concept:mortality"; "concept:calm" of
        // "concept:calm-nature"; "ölüm" is raw text (demoted to advisory at the constructor door)
        let config = ShieldConfigV2(blockedConcepts: ["concept:mortal", "concept:calm", "ölüm"])
        XCTAssertTrue(config.freeformGuesses.contains("ölüm"), "raw entry demoted to advisory at the door")
        XCTAssertFalse(config.blockedConcepts.contains("ölüm"))
        let (_, d) = run("a7-shield-prefix-attack", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "vefat ve cenaze haberleri özel", detectedLanguage: "tr"))],
            shield: config, item: 8101)
        XCTAssertFalse(d.shieldOutcome?.hardMatch ?? true, "prefix/substring entries can NEVER hard-match")
        XCTAssertNotEqual(d.state, .shieldMatch)
        XCTAssertFalse(codes(d).contains("SHIELD_TOPIC_MATCH"))
        XCTAssertTrue(codes(d).contains("SHIELD_UNSUPPORTED_GUESS_ADVISORY"), "advisory demotion is visible")
        // exact canonical control: the full ID DOES match the same content
        let (_, dExact) = run("a7-shield-exact-control", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "vefat ve cenaze haberleri özel", detectedLanguage: "tr"))],
            shield: ShieldConfigV2(blockedConcepts: ["concept:mortality"]), item: 8102)
        XCTAssertTrue(dExact.shieldOutcome?.hardMatch ?? false)
    }

    // ── P12: cross-user cache contamination ──
    func testP12_CrossUserCacheContamination() {
        let (m, d) = run("a7-cache-src", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "sakin orman ve göl manzarası", detectedLanguage: "tr",
                          visualLabels: ["forest"], visualConfidence: 0.85))],
            shield: ShieldConfigV2(blockedConcepts: ["concept:calm-nature"]), item: 8201)
        let cache = PolicyDecisionCacheV1()
        let versions = PolicyVersionRegistryV1(ageRegistry: JurisdictionAgeBandRegistryV1.version,
                                               jurisdiction: "none", shield: ShieldConfigV2.version,
                                               meshModelVersions: m.meshModelVersions, atMs: 0)
        let fp = PolicyDecisionCacheV1.fingerprint(versions: versions,
                                                   shieldConfig: ShieldConfigV2(blockedConcepts: ["concept:calm-nature"]),
                                                   childAge: nil, parent: ParentPreferencePolicyV1())
        cache.insert(profileID: "audit-userA", item: ContentItemID(8201), policyFingerprint: fp, decision: d)
        XCTAssertNotNil(cache.lookup(profileID: "audit-userA", item: ContentItemID(8201), policyFingerprint: fp))
        XCTAssertNil(cache.lookup(profileID: "audit-userB", item: ContentItemID(8201), policyFingerprint: fp),
                     "cross-user lookup must be structurally impossible")
        XCTAssertNil(cache.lookup(profileID: "audit-userA", item: ContentItemID(9999), policyFingerprint: fp),
                     "different item never served")
        cache.clearProfile("audit-userB")
        XCTAssertNotNil(cache.lookup(profileID: "audit-userA", item: ContentItemID(8201), policyFingerprint: fp),
                        "clearing another profile must not evict userA")
        cache.clearProfile("audit-userA")
        XCTAssertEqual(cache.count, 0)
    }

    // ── P13: changed shield + SAME world model (ContentDNA stand-in) — recompute, different outcome;
    // PLUS a pinned FINDING: fingerprints IGNORE freeformGuesses and preferredConcepts, so two configs
    // that differ only in those fields COLLIDE (stale advisory/preferred fields could be served). ──
    func testP13_ChangedShieldSameDNA_andFingerprintCollisionPinned() {
        let brain = makeBrain()
        let semantic = P009CScenarioV1(name: "a7-dna-reuse", family: "audit7",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "sakin orman nehir manzara", detectedLanguage: "tr",
                                                  visualLabels: ["river"], visualConfidence: 0.85))],
            annotation: P009CAnnotationV1())
        let m = P009CCorpusV1.run(semantic, brain: brain, item: ContentItemID(8301))
        let d1 = AdmissionPolicyPipelineV1.evaluate(worldModel: m,
            shieldConfig: ShieldConfigV2(blockedConcepts: ["concept:calm-nature"]), nowMs: 0)
        XCTAssertEqual(d1.state, .shieldMatch)
        let d2 = AdmissionPolicyPipelineV1.evaluate(worldModel: m, shieldConfig: ShieldConfigV2(), nowMs: 1)
        XCTAssertNotEqual(d2.state, .shieldMatch, "policy change recomputes from the SAME world model")
        let versions = PolicyVersionRegistryV1(ageRegistry: JurisdictionAgeBandRegistryV1.version,
                                               jurisdiction: "none", shield: ShieldConfigV2.version,
                                               meshModelVersions: m.meshModelVersions, atMs: 0)
        let fpBlockA = PolicyDecisionCacheV1.fingerprint(versions: versions,
            shieldConfig: ShieldConfigV2(blockedConcepts: ["concept:calm-nature"]), childAge: nil,
            parent: ParentPreferencePolicyV1())
        let fpBlockNone = PolicyDecisionCacheV1.fingerprint(versions: versions, shieldConfig: ShieldConfigV2(),
            childAge: nil, parent: ParentPreferencePolicyV1())
        XCTAssertNotEqual(fpBlockA, fpBlockNone, "state-affecting shield change ⇒ new fingerprint")
        // ── PINNED FINDING (AUDIT7-F3): guesses/preferred are NOT part of the fingerprint ──
        let fpGuess1 = PolicyDecisionCacheV1.fingerprint(versions: versions,
            shieldConfig: ShieldConfigV2(freeformGuesses: ["vibe-one"]), childAge: nil, parent: ParentPreferencePolicyV1())
        let fpGuess2 = PolicyDecisionCacheV1.fingerprint(versions: versions,
            shieldConfig: ShieldConfigV2(freeformGuesses: ["totally-different-vibe", "second"]), childAge: nil,
            parent: ParentPreferencePolicyV1())
        let fpPref = PolicyDecisionCacheV1.fingerprint(versions: versions,
            shieldConfig: ShieldConfigV2(preferredConcepts: ["concept:education"]), childAge: nil,
            parent: ParentPreferencePolicyV1())
        XCTAssertEqual(fpGuess1, fpGuess2, "PINNED: guess-only config changes collide (advisory staleness risk)")
        XCTAssertEqual(fpGuess1, fpBlockNone, "PINNED: preferred/guess fields invisible to the fingerprint")
        XCTAssertEqual(fpPref, fpBlockNone, "PINNED: preferred-only change collides")
        // mitigating truth: neither guesses nor preferred can change the admission STATE (advisory only)
        let dG = AdmissionPolicyPipelineV1.evaluate(worldModel: m,
            shieldConfig: ShieldConfigV2(freeformGuesses: ["vibe-one"]), nowMs: 2)
        XCTAssertEqual(dG.state, d2.state, "guesses never move the categorical state")
    }

    // ── P14: H1 rides EVERY decision — try to produce one without the code via the public pipeline ──
    func testP14_H1RidesEveryDecision() {
        var decisions: [AdmissionStateCandidateV1] = []
        decisions.append(run("a7-h1-neutral", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "garden tools maintenance walkthrough", detectedLanguage: "en",
                          visualLabels: ["workshop"], visualConfidence: 0.95))], item: 8401).1)
        decisions.append(run("a7-h1-strong", segments: [seg(0, 4000,
            ExpertInputV2(ocrText: "funeral obituary fatal toll", detectedLanguage: "en"), risk: 0.9, topics: ["x"])], item: 8402).1)
        decisions.append(run("a7-h1-shield", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "sakin orman gölü", detectedLanguage: "tr", visualLabels: ["forest"], visualConfidence: 0.85))],
            shield: ShieldConfigV2(blockedConcepts: ["concept:calm-nature"]), item: 8403).1)
        decisions.append(run("a7-h1-child-review", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "crafting paper shapes tutorial", detectedLanguage: "en"))],
            child: GuardianEnteredChildProfileV1(ageYears: 9, jurisdictionCode: "TR", enteredByGuardian: true), item: 8404).1)
        decisions.append(run("a7-h1-provisional", segments: [seg(0, 2000,
            ExpertInputV2(ocrText: "plain words", detectedLanguage: "en"))], item: 8405, provisional: true).1)
        for d in decisions {
            XCTAssertTrue(codes(d).contains("H1_VISUAL_UNAVAILABLE"),
                          "H1 gap must be visible on EVERY route (state=\(d.state.rawValue))")
        }
        // confident benign visuals can never flip an UNAVAILABLE dimension to "safe/clear"
        XCTAssertFalse(HighRiskVisualSafetyRegistryV1.visuallySafeConclusionAllowed())
        XCTAssertTrue(HighRiskVisualSafetyRegistryV1.allUnavailable)
        // structural: outside @testable, SafetyPolicyResultV1 has no public initializer — the only
        // public producer is SafetyPolicyEngineV1.evaluate, which appends the H1 code unconditionally.
    }

    // ── P15: reason-code ↔ provenance consistency + a pinned mismatch FINDING on the parent overlay ──
    func testP15_ReasonCodeProvenanceConsistency() {
        let (_, d) = run("a7-prov-multi", segments: [seg(0, 4000,
            ExpertInputV2(ocrText: "tarih sunumu: vefat ve cenaze kayıtları", detectedLanguage: "tr"), risk: 0.65, topics: ["h"])],
            child: GuardianEnteredChildProfileV1(ageYears: 12, jurisdictionCode: "TR", enteredByGuardian: true),
            shield: ShieldConfigV2(blockedConcepts: ["concept:mortality"]), item: 8501)
        for r in [d.dominantReason] + d.secondaryReasons {
            XCTAssertFalse(r.producer.isEmpty); XCTAssertFalse(r.basis.isEmpty)
            if r.code.rawValue.hasPrefix("SHIELD_") {
                XCTAssertEqual(r.producer, PersonalShieldPolicyV2.revision, "shield codes come from the shield engine")
            }
            if r.code == .h1VisualUnavailable {
                XCTAssertTrue(r.basis.contains("UNAVAILABLE_EVIDENCE_BACKED"), "H1 basis names the registry truth")
            }
        }
        // ── PINNED FINDING (AUDIT7-F2): parent-preference extra caution on a NON-news dimension emits
        // CHILD_AGE_CAUTION_SENSITIVE_NEWS (wrong code class; basis string is truthful). ──
        let (_, dParent) = run("a7-parent-fear-overlay", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "tehlike ve korkunç uyarı hikayesi", detectedLanguage: "tr"))],
            child: GuardianEnteredChildProfileV1(ageYears: 12, jurisdictionCode: "TR", enteredByGuardian: true),
            parent: ParentPreferencePolicyV1(extraCautionDimensions: [.fearThreat]), item: 8502)
        XCTAssertEqual(dParent.childOutcome, .caution, "parent tightened fear caution beyond the <10 band")
        let overlay = ([dParent.dominantReason] + dParent.secondaryReasons)
            .first { $0.basis.hasPrefix("parent-preference extra caution") }
        XCTAssertNotNil(overlay)
        XCTAssertEqual(overlay?.code, .childAgeCautionSensitiveNews,
                       "PINNED: fear-dimension parent overlay mislabeled with the SENSITIVE_NEWS code (finding)")
        XCTAssertTrue(overlay?.basis.contains("fear-threat") ?? false, "basis carries the true dimension")
    }

    // ── P16: OOD policy inputs — garbage config/profile must fail closed, never crash, never block ──
    func testP16_OODPolicyInputs() {
        let weirdShield = ShieldConfigV2(blockedConcepts: ["", " ", "concept:"],
                                         blockedEntities: ["entity:"], freeformGuesses: ["", "🙃"])
        let (_, d) = run("a7-ood-garbage", segments: [seg(0, 2000,
            ExpertInputV2(ocrText: "y#2", detectedLanguage: "q!!", editDensityCutsPerMinute: .nan))],
            child: GuardianEnteredChildProfileV1(ageYears: Int.min, jurisdictionCode: "", enteredByGuardian: true),
            shield: weirdShield, item: 8601)
        XCTAssertNotEqual(d.state, .neutral, "OOD input can never be NEUTRAL")
        XCTAssertNotEqual(d.state, .shieldMatch, "garbage shield entries can never hard-block")
        XCTAssertEqual(d.childOutcome, .unknownReview, "empty jurisdiction fails closed")
        // ── PINNED FINDING (AUDIT7-F4): when the world model is OOD/unknown, the resolver's neutral→
        // UNKNOWN branch takes identity/knowledge first and the child engine's fail-closed reason codes
        // (here AGE_JURISDICTION_UNSUPPORTED, emitted by ChildAgePolicyEngineV1) are DROPPED from the
        // candidate's reason set — the state stays correctly fail-closed and childOutcome is carried,
        // but reason-code completeness is lost on this path (cf. P8 where knowledge is KNOWN and the
        // code IS present). ──
        XCTAssertFalse(codes(d).contains("AGE_JURISDICTION_UNSUPPORTED"),
                       "PINNED: child fail-closed reason dropped under OOD-dominant branch (finding)")
        XCTAssertTrue(codes(d).contains("OOD_UNKNOWN") || codes(d).contains("IDENTITY_PROVISIONAL")
                      || codes(d).contains("EVIDENCE_INSUFFICIENT"), "fail-closed dominant reason present")
        // bare prefixes "concept:"/"entity:" pass the door but can never equal a real canonical ID
        XCTAssertFalse(d.shieldOutcome?.hardMatch ?? true)
        // empty content + child → UNKNOWN/REVIEW family
        let (_, dEmpty) = run("a7-ood-empty", segments: [seg(0, 2000, ExpertInputV2())],
            child: GuardianEnteredChildProfileV1(ageYears: 10, jurisdictionCode: "US", enteredByGuardian: true), item: 8602)
        XCTAssertTrue([.unknown, .review].contains(dEmpty.state), "empty content fails closed, got \(dEmpty.state.rawValue)")
    }

    // ── P17: teen (13–17) + sentinel-class unscreenable text — PINNED behavior: AGE_ALIGNED + NEUTRAL.
    // The sentinel registry declares "never NEUTRAL for child profiles" for age-critical-sexual, but with
    // sexualThemes UNAVAILABLE and no lexicon hit, a 14-year-old gets NEUTRAL/ALIGNED (H1 code is the
    // only honesty marker). Reported as a FINDING (doc-truth / teen fail-closed gap), not silently passed. ──
    func testP17_TeenSentinelClassNeutralSurfacePinned() {
        let (_, d) = run("a7-teen-sexual-text", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "explicit adult romance scenes compilation uncut", detectedLanguage: "en",
                          visualLabels: ["street"], visualConfidence: 0.8))],
            child: GuardianEnteredChildProfileV1(ageYears: 14, jurisdictionCode: "TR", enteredByGuardian: true), item: 8701)
        XCTAssertEqual(d.childOutcome, .aligned, "PINNED: 13+ has no fail-closed floor on UNAVAILABLE dims")
        XCTAssertEqual(d.state, .neutral, "PINNED: sentinel-class teen content can reach NEUTRAL (finding)")
        XCTAssertTrue(codes(d).contains("H1_VISUAL_UNAVAILABLE"), "the H1 gap is at least visible")
        // the under-13 floor DOES hold on identical content
        let (_, dYoung) = run("a7-child-sexual-text", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "explicit adult romance scenes compilation uncut", detectedLanguage: "en",
                          visualLabels: ["street"], visualConfidence: 0.8))],
            child: GuardianEnteredChildProfileV1(ageYears: 12, jurisdictionCode: "TR", enteredByGuardian: true), item: 8702)
        XCTAssertEqual(dYoung.childOutcome, .unknownReview)
        XCTAssertNotEqual(dYoung.state, .neutral)
    }

    // ── P18: admission candidate carries NO hidden numeric anywhere reachable (deep mirror) ──
    func testP18_NoHiddenNumericDeepMirror() {
        let (_, d) = run("a7-numeric-mirror", segments: [seg(0, 4000,
            ExpertInputV2(ocrText: "funeral obituary report", detectedLanguage: "en"), risk: 0.85, topics: ["n"])],
            child: GuardianEnteredChildProfileV1(ageYears: 9, jurisdictionCode: "TR", enteredByGuardian: true),
            shield: ShieldConfigV2(blockedConcepts: ["concept:mortality"]), item: 8801)
        func assertNoNumeric(_ value: Any, path: String, depth: Int) {
            if depth > 4 { return }
            let mirror = Mirror(reflecting: value)
            for child in mirror.children {
                let p = "\(path).\(child.label ?? "?")"
                if p.hasSuffix(".atMs") { continue }          // declared freshness timestamp (§17) — the only number
                let t = "\(type(of: child.value))"
                XCTAssertFalse(t == "Double" || t == "Float" || t == "Int" || t == "CGFloat",
                               "hidden numeric at \(p): \(t)")
                assertNoNumeric(child.value, path: p, depth: depth + 1)
            }
        }
        assertNoNumeric(d, path: "candidate", depth: 0)
        XCTAssertFalse(makeBrain().calibration.scoreDisplayAllowed(), "score display stays OFF")
    }

    // ── P19: planted unique tokens in content + shield config must never surface in policy outputs ──
    func testP19_PlantedTokenPrivacy() {
        let contentSecret = "qx7ContentSecret"
        let guessSecret = "qx7GuessSecret"
        let rawShieldSecret = "qx7RawShieldSecret"
        let (_, d) = run("a7-privacy-plant", segments: [seg(0, 3000,
            ExpertInputV2(ocrText: "study guide lesson \(contentSecret) chapter", detectedLanguage: "en"))],
            child: GuardianEnteredChildProfileV1(ageYears: 9, jurisdictionCode: "TR", enteredByGuardian: true),
            shield: ShieldConfigV2(blockedConcepts: ["concept:mortality", rawShieldSecret],
                                   freeformGuesses: [guessSecret]), item: 8901)
        let surface = allStrings(d)
        for secret in [contentSecret, guessSecret, rawShieldSecret] {
            XCTAssertFalse(surface.contains { $0.contains(secret) },
                           "planted token \(secret) leaked into policy outputs")
        }
        // the child's exact age must not be echoed into any reason basis (band thresholds are policy, not data)
        XCTAssertFalse(surface.contains { $0.contains("age 9 ") || $0.hasSuffix("age 9") || $0.contains("ageYears") },
                       "child age never echoed raw into policy outputs")
    }

    // ── P20: sentinel registry intactness + strong-risk sentinel never NEUTRAL ──
    func testP20_SentinelsIntactAndStrongRiskNeverNeutral() {
        XCTAssertEqual(SafetySentinelRegistryV1.sentinels.count, 6)
        XCTAssertTrue(SafetySentinelRegistryV1.allDimensionsAccounted)
        let ids = Set(SafetySentinelRegistryV1.sentinels.map { $0.sentinelID })
        for required in ["sentinel.explicit", "sentinel.severe-violence", "sentinel.self-harm-encouragement",
                         "sentinel.dangerous-behavior", "sentinel.age-critical-sexual",
                         "sentinel.child-targeted-manipulation"] {
            XCTAssertTrue(ids.contains(required))
        }
        let (_, d) = run("a7-sentinel-strong", segments: [seg(0, 4000,
            ExpertInputV2(ocrText: "ölümcül saldırı görüntüleri: vefat haberleri", detectedLanguage: "tr",
                          soundEvents: ["alarm"]), risk: 0.95, topics: ["w"])], item: 9001)
        XCTAssertNotEqual(d.state, .neutral)
        XCTAssertEqual(d.state, .strongProtection)
        // dimension truth table is intact (no silent upgrade since the audited SHA)
        XCTAssertEqual(SafetyDimensionTruthV1.status[.explicitSexual], .unavailable)
        XCTAssertEqual(SafetyDimensionTruthV1.status[.sensitiveNews], .implementedUncalibrated)
        XCTAssertEqual(SafetyDimensionTruthV1.status[.fearThreat], .heuristicSupportOnly)
        XCTAssertNil(SafetyDimensionTruthV1.status.values.first { $0 == .implementedCalibrated })
    }

    // ── P21: legal vs developmental — no emitted decision can ever present as a legal rating ──
    func testP21_DevelopmentalNeverPresentsAsLegal() {
        XCTAssertFalse(AgeSuitabilityPolicyV1.legalRatingsIngested)
        XCTAssertFalse(AgeSuitabilityPolicyV1.providerRatingsIngested)
        let brain = makeBrain()
        let semantic = P009CScenarioV1(name: "a7-legal-sep", family: "audit7",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "korkunç tehlike hikayesi", detectedLanguage: "tr"))],
            annotation: P009CAnnotationV1())
        let m = P009CCorpusV1.run(semantic, brain: brain, item: ContentItemID(9101))
        let safety = SafetyPolicyEngineV1.evaluate(worldModel: m)
        // every source-class path reachable today refuses legal presentation
        for parent in [ParentPreferencePolicyV1(), ParentPreferencePolicyV1(extraCautionDimensions: [.fearThreat])] {
            let dec = ChildAgePolicyEngineV1.evaluate(
                profile: GuardianEnteredChildProfileV1(ageYears: 8, jurisdictionCode: "TR", enteredByGuardian: true),
                safety: safety, worldModel: m, parentPreference: parent)
            XCTAssertNotEqual(dec.sourceClass, .legalRating)
            XCTAssertFalse(AgeSuitabilityPolicyV1.presentableAsLegalRating(dec))
        }
    }
}
