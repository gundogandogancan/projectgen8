import XCTest
@testable import GuardianCore

// P009D — policy intelligence test families (§24) + corpus gates (TUNE → freeze → run-once).

final class P009DPolicyTests: XCTestCase {

    func makeBrain() -> GuardianMetaBrainV2 {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1()); b.registry.register(LanguageOCRExpertV1())
        b.registry.register(SpeechExpertV1()); b.registry.register(AudioEventExpertV1())
        b.registry.register(MusicExpertV1()); b.registry.register(SymbolExpertV1())
        b.registry.register(TemporalExpertV1()); b.registry.register(SafetyEvidenceExpertV1())
        b.registry.register(BenefitEvidenceExpertV1()); b.registry.register(AttentionPressureExpertV1())
        return b
    }
    func runNamed(_ name: String, split: P009DSplitV1 = .tune, item: UInt64 = 1,
                  provisional: Bool = false) -> (ContentWorldModelV1, AdmissionStateCandidateV1) {
        let s = P009DPolicyCorpusV1.scenarios(split).first { $0.name == name }!
        return P009DPolicyCorpusV1.run(s, brain: makeBrain(), item: ContentItemID(item), provisional: provisional)
    }
    func allCodes(_ d: AdmissionStateCandidateV1) -> Set<String> {
        Set(([d.dominantReason] + d.secondaryReasons).map { $0.code.rawValue })
    }

    // ── corpus gate evaluation ──
    func check(_ s: P009DPolicyScenarioV1, _ d: AdmissionStateCandidateV1) -> [String] {
        var f: [String] = []
        let a = s.annotation
        let codes = allCodes(d)
        if !a.expectedAdmission.isEmpty && !a.expectedAdmission.contains(d.state.rawValue) {
            f.append("\(s.name): state \(d.state.rawValue) ∉ \(a.expectedAdmission)")
        }
        if a.forbiddenAdmission.contains(d.state.rawValue) { f.append("\(s.name): forbidden state \(d.state.rawValue)") }
        for c in a.requiredReasonCodes where !codes.contains(c) { f.append("\(s.name): missing code \(c)") }
        for c in a.forbiddenReasonCodes where codes.contains(c) { f.append("\(s.name): forbidden code \(c)") }
        if let expectChild = a.expectedChildOutcome, d.childOutcome?.rawValue != expectChild {
            f.append("\(s.name): child \(d.childOutcome?.rawValue ?? "nil") != \(expectChild)")
        }
        if let hard = a.expectShieldHardMatch, (d.shieldOutcome?.hardMatch ?? false) != hard {
            f.append("\(s.name): shield hardMatch != \(hard)")
        }
        return f
    }
    func runSplit(_ split: P009DSplitV1) -> [String] {
        var failures: [String] = []
        for (i, s) in P009DPolicyCorpusV1.scenarios(split).enumerated() {
            let provisional = s.name.contains("identity-provisional")
            let (_, d) = P009DPolicyCorpusV1.run(s, brain: makeBrain(), item: ContentItemID(UInt64(i + 1)),
                                                 provisional: provisional)
            failures.append(contentsOf: check(s, d))
        }
        return failures
    }
    func testTuneP009D() {
        let f = runSplit(.tune)
        print("P009D_TUNE scenarios=\(P009DPolicyCorpusV1.scenarios(.tune).count) failures=\(f.count)")
        f.forEach { print("P009D_TUNE_FAIL \($0)") }
        XCTAssertTrue(f.isEmpty, "\(f)")
    }
    func testHeldOutP009DRunOnce() {
        let f = runSplit(.heldOut)
        print("P009D_HELDOUT scenarios=\(P009DPolicyCorpusV1.scenarios(.heldOut).count) failures=\(f.count)")
        f.forEach { print("P009D_HELDOUT_FAIL \($0)") }
        XCTAssertTrue(f.isEmpty, "\(f)")
    }
    func testStressOODP009DRunOnce() {
        let fs = runSplit(.stress), fo = runSplit(.ood)
        print("P009D_STRESS scenarios=\(P009DPolicyCorpusV1.scenarios(.stress).count) failures=\(fs.count)")
        print("P009D_OOD scenarios=\(P009DPolicyCorpusV1.scenarios(.ood).count) failures=\(fo.count)")
        (fs + fo).forEach { print("P009D_SO_FAIL \($0)") }
        XCTAssertTrue(fs.isEmpty && fo.isEmpty, "\(fs + fo)")
    }

    // ── §22 predeclared gates ──
    func testStrongProtectionOutranksBenefitAndShieldPreference() {
        let (_, d) = runNamed("sd-benefit-flood-vs-strong-risk", split: .stress)
        XCTAssertEqual(d.state, .strongProtection)
        XCTAssertTrue(allCodes(d).contains("BENEFIT_PRESENT_NOT_OVERRIDING"),
                      "benefit recorded, never overriding")
    }
    func testAgeRestrictionOutranksContentCharacter() {
        let (_, d) = runNamed("hd-parent-stricter", split: .heldOut)
        XCTAssertEqual(d.state, .ageRestricted)
        XCTAssertEqual(d.childOutcome, .restricted)
    }
    func testH1CannotBeTreatedVisuallySafe() {
        XCTAssertFalse(HighRiskVisualSafetyRegistryV1.visuallySafeConclusionAllowed())
        XCTAssertTrue(HighRiskVisualSafetyRegistryV1.allUnavailable)
        for r in HighRiskVisualSafetyRegistryV1.records {
            XCTAssertEqual(r.provider, "NONE"); XCTAssertEqual(r.calibrationStatus, "UNAVAILABLE_EVIDENCE_BACKED")
        }
        // every decision carries the H1 reason code — the gap is visible on EVERY route
        let (_, d) = runNamed("pd-h1-unavailable-adult-neutral")
        XCTAssertTrue(allCodes(d).contains("H1_VISUAL_UNAVAILABLE"))
    }
    func testAgeNeverInferredFromImage() {
        // structural: the ONLY child-profile type requires guardian attestation; no API in the child
        // module accepts image/face/visual types (compile-time truth — asserted by reflection on input)
        let p = GuardianEnteredChildProfileV1(ageYears: 9, jurisdictionCode: "TR", enteredByGuardian: true)
        XCTAssertEqual(p.storage, "LOCAL_FIRST")
        let mirror = Mirror(reflecting: p)
        XCTAssertFalse(mirror.children.contains { "\(type(of: $0.value))".contains("CGImage") || "\(type(of: $0.value))".contains("Data") })
        // unattested profile fails closed
        let (_, d) = runNamed("od-unattested-age", split: .ood)
        XCTAssertEqual(d.childOutcome, .unknownReview)
        XCTAssertTrue(allCodes(d).contains("AGE_SOURCE_MISSING"))
    }
    func testLegalVsDevelopmentalSourceSeparation() {
        XCTAssertFalse(AgeSuitabilityPolicyV1.legalRatingsIngested)
        let brain = makeBrain()
        let s = P009DPolicyCorpusV1.scenarios(.tune).first { $0.name == "pd-child-fear" }!
        let (m, _) = P009DPolicyCorpusV1.run(s, brain: brain, item: ContentItemID(600))
        let safety = SafetyPolicyEngineV1.evaluate(worldModel: m)
        let decision = ChildAgePolicyEngineV1.evaluate(profile: s.childProfile!, safety: safety, worldModel: m)
        XCTAssertEqual(decision.sourceClass, .developmentalSuitability, "source class recorded on every decision")
        XCTAssertFalse(AgeSuitabilityPolicyV1.presentableAsLegalRating(decision),
                       "developmental policy can never present as a legal rating")
    }
    func testShieldCanonicalCrossLanguageAndGuessLaws() {
        let (_, d1) = runNamed("pd-shield-cross-language")
        XCTAssertTrue(d1.shieldOutcome?.hardMatch ?? false, "TR surface → canonical concept → match")
        let (_, d2) = runNamed("pd-shield-unsupported-guess")
        XCTAssertFalse(d2.shieldOutcome?.hardMatch ?? true)
        XCTAssertEqual(d2.shieldOutcome?.matchConfidence, .advisoryGuess)
        XCTAssertNotEqual(d2.state, .shieldMatch, "unsupported guess can NEVER hard-block")
        // non-canonical blocked entry demoted at the door
        let cfg = ShieldConfigV2(blockedConcepts: ["raw text idea"])
        XCTAssertTrue(cfg.blockedConcepts.isEmpty)
        XCTAssertTrue(cfg.freeformGuesses.contains("raw text idea"))
    }
    func testUnknownReviewFirstClass() {
        let (_, d) = runNamed("hd-identity-provisional-unknown", split: .heldOut, provisional: true)
        XCTAssertEqual(d.state, .unknown)
        XCTAssertTrue(allCodes(d).contains("IDENTITY_PROVISIONAL"))
    }
    func testAdmissionStateCategoricalOnlyNoHiddenNumeric() {
        let (_, d) = runNamed("pd-sensitive-news-adult")
        for child in Mirror(reflecting: d).children {
            let t = "\(type(of: child.value))"
            if child.label == "versions" { continue }                       // timestamps live in versions only
            XCTAssertFalse(t == "Double" || t == "Float" || t == "Int",
                           "no numeric field on the candidate (\(child.label ?? "?"): \(t))")
        }
        XCTAssertFalse(makeBrain().calibration.scoreDisplayAllowed())
    }
    func testReasonCodesCarryProvenance() {
        let (_, d) = runNamed("pd-multi-policy-conflict")
        for r in [d.dominantReason] + d.secondaryReasons {
            XCTAssertFalse(r.producer.isEmpty); XCTAssertFalse(r.basis.isEmpty)
        }
        XCTAssertFalse(d.versions.meshModelVersions.isEmpty, "decision binds mesh/model versions")
        XCTAssertEqual(d.versions.policyEngine, PolicyVersionRegistryV1.policyEngineVersion)
    }
    func testCachedDNAChangedPolicyReuse() {
        // same world model + changed shield → DIFFERENT decision WITHOUT re-running the mesh
        let brain = makeBrain()
        let s = P009DPolicyCorpusV1.scenarios(.tune).first { $0.name == "pd-shield-topic-match" }!
        let semantic = P009CScenarioV1(name: s.name, family: s.family, segments: s.segments, annotation: P009CAnnotationV1())
        let m = P009CCorpusV1.run(semantic, brain: brain, item: ContentItemID(700))
        let d1 = AdmissionPolicyPipelineV1.evaluate(worldModel: m, shieldConfig: s.shieldConfig, nowMs: 0)
        XCTAssertEqual(d1.state, .shieldMatch)
        let d2 = AdmissionPolicyPipelineV1.evaluate(worldModel: m, shieldConfig: ShieldConfigV2(), nowMs: 1)
        XCTAssertNotEqual(d2.state, .shieldMatch, "policy change recomputed from the SAME world model")
    }
    func testPolicyCacheIsolation() {
        let (m, _) = runNamed("pd-shield-topic-match", item: 800)
        let cache = PolicyDecisionCacheV1()
        let shield = ShieldConfigV2(blockedConcepts: ["concept:calm-nature"])
        let versions = PolicyVersionRegistryV1(ageRegistry: JurisdictionAgeBandRegistryV1.version, jurisdiction: "none",
                                               shield: ShieldConfigV2.version, meshModelVersions: m.meshModelVersions, atMs: 0)
        let fpA = PolicyDecisionCacheV1.fingerprint(versions: versions, shieldConfig: shield, childAge: nil,
                                                    parent: ParentPreferencePolicyV1())
        let d = AdmissionPolicyPipelineV1.evaluate(worldModel: m, shieldConfig: shield, nowMs: 0)
        cache.insert(profileID: "userA", item: ContentItemID(800), policyFingerprint: fpA, decision: d)
        XCTAssertNotNil(cache.lookup(profileID: "userA", item: ContentItemID(800), policyFingerprint: fpA))
        // §18: cross-user isolation — userB can NEVER see userA's personal decision
        XCTAssertNil(cache.lookup(profileID: "userB", item: ContentItemID(800), policyFingerprint: fpA))
        // changed shield → changed fingerprint → miss (recompute, reuse DNA)
        let fpB = PolicyDecisionCacheV1.fingerprint(versions: versions, shieldConfig: ShieldConfigV2(), childAge: nil,
                                                    parent: ParentPreferencePolicyV1())
        XCTAssertNotEqual(fpA, fpB)
        XCTAssertNil(cache.lookup(profileID: "userA", item: ContentItemID(800), policyFingerprint: fpB))
        cache.clearProfile("userA")
        XCTAssertEqual(cache.count, 0)
    }
    func testNoRawDataInPolicyOutputs() {
        let secret = "zq9PolicySecret"
        let brain = makeBrain()
        let s = P009DPolicyScenarioV1(name: "leak-probe", family: "privacy",
            segments: [P009CSegmentV1(startMs: 0, endMs: 2000,
                                      input: ExpertInputV2(ocrText: "learn the lesson guide \(secret)", detectedLanguage: "en"))],
            childProfile: GuardianEnteredChildProfileV1(ageYears: 9, jurisdictionCode: "TR", enteredByGuardian: true),
            shieldConfig: ShieldConfigV2(blockedConcepts: ["concept:mortality"]),
            annotation: P009DPolicyAnnotationV1())
        let (_, d) = P009DPolicyCorpusV1.run(s, brain: brain, item: ContentItemID(900))
        let serialized = ([d.dominantReason] + d.secondaryReasons).flatMap { [$0.basis, $0.producer] }
            + d.unresolvedConflicts + (d.shieldOutcome?.advisoryGuessNotes ?? [])
        XCTAssertFalse(serialized.contains { $0.contains(secret) }, "policy logs carry derived reason codes only")
    }
    func testSentinelLawNeverNeutral() {
        XCTAssertTrue(SafetySentinelRegistryV1.allDimensionsAccounted)
        XCTAssertEqual(SafetySentinelRegistryV1.sentinels.count, 6)
        // sentinel-class strong-risk input can never be NEUTRAL
        let (_, d) = runNamed("pd-severe-violence-lexical")
        XCTAssertNotEqual(d.state, .neutral)
        XCTAssertEqual(d.state, .strongProtection)
    }
    func testDimensionStatusesNeverSilentlyUpgraded() {
        XCTAssertEqual(SafetyDimensionTruthV1.status.count, SafetyDimensionV1.allCases.count)
        XCTAssertEqual(SafetyDimensionTruthV1.status[.explicitSexual], .unavailable)
        XCTAssertEqual(SafetyDimensionTruthV1.status[.violenceGore], .unavailable)
        XCTAssertEqual(SafetyDimensionTruthV1.status[.selfHarm], .unavailable)
        XCTAssertEqual(SafetyDimensionTruthV1.status[.sensitiveNews], .implementedUncalibrated)
        XCTAssertEqual(SafetyDimensionTruthV1.status[.fearThreat], .heuristicSupportOnly)
        XCTAssertNil(SafetyDimensionTruthV1.status.values.first { $0 == .implementedCalibrated },
                     "nothing is calibrated in P009D — score stays OFF")
    }
    func testQuoteVsLiteralContextQualified() {
        let (m, d) = runNamed("pd-profanity-quote")
        XCTAssertTrue(m.episodes.first?.contextTags.contains(.quoted) ?? false)
        XCTAssertEqual(d.state, .caution)
        XCTAssertTrue(allCodes(d).contains("CONTEXT_QUALIFIED_RISK") || allCodes(d).contains("STRONG_RISK_ESCALATION"))
    }
    func testChildFearVsAdultSameContent() {
        // identical content: child gets AGE_CAUTION; adult path only CAUTION — personal layer separated
        let (_, dChild) = runNamed("pd-child-fear")
        XCTAssertEqual(dChild.childOutcome, .caution)
        let brain = makeBrain()
        let s = P009DPolicyCorpusV1.scenarios(.tune).first { $0.name == "pd-child-fear" }!
        let semantic = P009CScenarioV1(name: s.name, family: s.family, segments: s.segments, annotation: P009CAnnotationV1())
        let m = P009CCorpusV1.run(semantic, brain: brain, item: ContentItemID(950))
        let dAdult = AdmissionPolicyPipelineV1.evaluate(worldModel: m, nowMs: 0)
        XCTAssertNil(dAdult.childOutcome)
        XCTAssertNotEqual(dAdult.state, .ageCaution)
    }
    func testAnnotationDisagreementPreserved() {
        let s = P009DPolicyCorpusV1.scenarios(.tune).first { $0.name == "pd-educational-graphic" }!
        XCTAssertTrue(s.annotation.severityDisagreement, "subjective severity disagreement preserved")
    }
    func testUnavailableDimensionCannotDistinguish() {
        // drug education vs (hypothetical) promotion: dimension UNAVAILABLE → NO distinction invented
        let (m, d) = runNamed("pd-drug-education-vs-promotion")
        let safety = SafetyPolicyEngineV1.evaluate(worldModel: m)
        let drugFinding = safety.findings.first { $0.dimension == .drugsAlcohol }!
        XCTAssertEqual(drugFinding.status, .unavailable)
        XCTAssertFalse(drugFinding.evidencePresent, "UNAVAILABLE dimension never fires")
        XCTAssertFalse(allCodes(d).contains("CHILD_AGE_RESTRICTED_EXPLICIT"))
    }
}
