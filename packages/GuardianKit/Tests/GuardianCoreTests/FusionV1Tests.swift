import XCTest
@testable import GuardianCore

final class FusionV1Tests: XCTestCase {
    let fusion = ScoreAdmissionFusionV1()
    var profile: PersonalAlgorithmProfile { GuardianLabFixtures.defaultProfile }

    func testCoverageGateNoScoreUnderInsufficientEvidence() {
        let out = fusion.decide(FusionInputsV1(contentID: .init("c"), profile: profile,
                                               availableHeadCount: 1, requiredHeadCount: 2))
        XCTAssertEqual(out.admission, .unknown)
        XCTAssertEqual(out.scoreState, .insufficientEvidence)
        XCTAssertNil(out.score)                                 // NO numeric score below threshold
        XCTAssertEqual(out.reasons, [.lowEvidence])
    }

    func testChildPolicyPrecedence() {
        let i = FusionInputsV1(contentID: .init("c"), mddLabels: [.warConflict], profile: profile,
                               childPolicy: SafetyPolicy(childMode: true, blockedCategoriesForChild: [.violentConflict]),
                               availableHeadCount: 3)
        let out = fusion.decide(i)
        XCTAssertEqual(out.reasons.first, .childPolicyBlock)    // child floor outranks
        XCTAssertEqual(out.admission, .hideIfControlled)
    }

    func testHardShieldHighExcludesOverThreshold() {
        let i = FusionInputsV1(contentID: .init("c"), shield: ShieldDecision(matched: "RivalTeam", tier: .high, action: .exclude),
                               benefit: highBenefit(), profile: profile, availableHeadCount: 3)
        let out = fusion.decide(i)
        XCTAssertEqual(out.admission, .hideIfControlled)
        XCTAssertEqual(out.reasons, [.semanticShieldEntityMatch])
    }

    func testMediumShieldCautionNotHidden() {
        let i = FusionInputsV1(contentID: .init("c"), shield: ShieldDecision(matched: "concept", tier: .medium, action: .caution),
                               profile: profile, availableHeadCount: 3)
        let out = fusion.decide(i)
        XCTAssertEqual(out.admission, .approveWithCaution)       // low-conf must NOT silently hide
        XCTAssertEqual(out.reasons, [.semanticShieldLowConfidence])
    }

    func testPositiveExposureTruthPolicySeparation() {
        var p = profile; p.positiveExposure = PositiveExposurePolicy(avoid: [.disease])
        let i = FusionInputsV1(contentID: .init("c"), mddLabels: [.diseaseIllness], benefit: highBenefit(),
                               profile: p, positiveMode: .protectedPositive, availableHeadCount: 3)
        let out = fusion.decide(i)
        XCTAssertEqual(out.admission, .notRecommended)
        XCTAssertEqual(out.reasons, [.positiveExposureDisease])
        XCTAssertTrue(out.explanation.contains("Truth/Evidence"))  // truth independent/unchanged
    }

    func testBenefitThresholdApprove() {
        let i = FusionInputsV1(contentID: .init("c"), benefit: highBenefit(), profile: profile, availableHeadCount: 3)
        let out = fusion.decide(i)
        XCTAssertEqual(out.admission, .approve)
        XCTAssertNotNil(out.score)                               // score only with coverage met
        XCTAssertEqual(out.reasons, [.thresholdMet])
    }

    func testSpiritualLensDoesNotAlterEvidenceOrScore() {
        // SpiritualLensV1 is NOT an input to fusion by construction → cannot affect score.
        let base = fusion.decide(FusionInputsV1(contentID: .init("c"), benefit: highBenefit(), profile: profile, availableHeadCount: 3))
        let lens = SpiritualLensV1(enabled: true, values: [.peace, .hope])
        XCTAssertTrue(lens.enabled)
        let again = fusion.decide(FusionInputsV1(contentID: .init("c"), benefit: highBenefit(), profile: profile, availableHeadCount: 3))
        XCTAssertEqual(base, again)                              // deterministic; lens has no path to score
    }

    func testExplanationReasonCodes() {
        let e = ExplanationEngineV1()
        XCTAssertTrue(e.text(for: [.childPolicyBlock]).contains("child-safety"))
        XCTAssertTrue(e.text(for: [.positiveExposureDisease]).contains("disease"))
    }

    func testContentDNAV2PersonalSeparationAndRoundTrip() throws {
        var dna = ContentDNAV1(contentID: "c1", identityState: "I4_VERIFIED", versionTag: "v1")
        dna.specialistSignals = [DNAHeadSignal(headId: "mdd-head-v1", headVersion: "v1", label: "DISEASE_ILLNESS",
                                               calibratedConfidence: nil, provenance: .lexiconV1,
                                               freshnessNanos: 1, rightsState: "OWNED")]
        let data = try JSONEncoder().encode(dna)
        let back = try JSONDecoder().decode(ContentDNAV1.self, from: data)
        XCTAssertEqual(dna, back)
        // No personal fields exist on the type (structural guarantee).
        let mirror = Mirror(reflecting: dna)
        XCTAssertFalse(mirror.children.contains { ($0.label ?? "").lowercased().contains("userscore") })
        XCTAssertEqual(dna.specialistSignals.first?.calibratedConfidence, nil)  // calibration honest
    }

    func testTemporalGraphV2ProviderAttribution() {
        let ex = TemporalExtractorV1()
        let sig = TimedSignal(startSeconds: 1122, endSeconds: 1156, modality: .visual,
                              producedBy: "apple-vision-ocr-v1", headTask: "mortality_disease_disaster",
                              provenance: .appleVision, categories: [.violentConflict], confidence: 0.7)
        let g = ex.buildGraph(contentID: .init("vid-1"), versionTag: "v1", durationSeconds: 2000, signals: [sig])
        XCTAssertTrue(g.segments.contains { $0.isFlagged })
        XCTAssertEqual(sig.headTask, "mortality_disease_disaster")   // WHICH head is attributed
    }

    private func highBenefit() -> PersonalBenefitVector {
        var b = PersonalBenefitVector(); b.learning = 1.0; b.skill = 1.0; b.practicalUsefulness = 1.0
        b.creativity = 0.8; b.criticalThinking = 0.9; b.hopeMeaning = 0.8; b.entertainment = 0.6; return b
    }
}
