//
//  R7IntegrityFixesTests.swift — R7 P0 DECISION-INTEGRITY FIXES.
//   • §1 THERMAL CHILD-SAFETY GAP — an active CHILD/TEEN profile with the world-model analysis SKIPPED (thermal/
//     resource) must FAIL CLOSED to an ANALYSIS-DEFICIT state (childAnalysisDeferred), NEVER a benign/AGE_ALIGNED
//     surface. A previously-supported STRICTER decision (SHIELD_MATCH / standing CAUTION) persists.
//   • §2 FAMILY REVISION IN GUARDIAN TRUTH — a family-revision mismatch makes the decision STALE_FAMILY immediately;
//     a child/teen decision that cannot be verified fails closed; the heartbeat decodes legacy JSON tolerantly.
//   • §3 WORLD MODEL → GENERAL SURFACE (every profile) — a SafetyPolicy supported caution/strong finding raises/keeps
//     the general surface WITHOUT a child profile and WITHOUT a personal rule; benign text → no phantom caution.
//   • §4 SINGLE-PASS EXPERT REUSE — GeneralContentCharacter interpreting a SHARED LanguageOCR envelope equals running
//     the expert itself; the per-item census shows each text expert exactly once.
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class R7IntegrityFixesTests: XCTestCase {

    // MARK: - §1 THERMAL CHILD-SAFETY GAP (the adjudicator fails closed on a deficit)

    func testChildAnalysisDeficitFailsClosedNotBenign() {
        // Active CHILD/TEEN + analysis skipped (thermal). childOutcome is nil (analysis never ran). The benign base
        // GUARDIAN_ON must NOT survive — it becomes the ANALYSIS-DEFICIT UNKNOWN, never AGE_ALIGNED.
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON", baseReasonRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
            character: nil, register: nil, childOutcome: nil, familyDegradedNonAdult: false,
            childAnalysisDeficit: true)
        XCTAssertEqual(a.surfaceRaw, "UNKNOWN", "a resource skip must never leave a benign child surface")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.childAnalysisDeferred.rawValue)
        XCTAssertNotEqual(a.reasonCodeRaw, GuardianReasonCodeV1.generalContentExaminedNoMarker.rawValue)
    }

    func testChildAnalysisDeficitNeverAlignedEvenIfOutcomeAlignedLeaked() {
        // Defensive: even if an AGE_ALIGNED outcome were (wrongly) present, the deficit path returns BEFORE the child
        // floor and refuses a positive surface. (In production childOutcome is nil on the skipped path.)
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON", baseReasonRaw: GuardianReasonCodeV1.generalContentExaminedNoMarker.rawValue,
            character: nil, register: nil, childOutcome: .aligned, familyDegradedNonAdult: false,
            childAnalysisDeficit: true)
        XCTAssertEqual(a.surfaceRaw, "UNKNOWN")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.childAnalysisDeferred.rawValue)
        XCTAssertFalse(a.adjustments.contains("child:AGE_ALIGNED-no-change"))
    }

    func testChildAnalysisDeficitPreservesStrongerPersonalMatch() {
        // A previously/standing STRICTER personal SHIELD_MATCH persists through a resource deficit (never weakened).
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "SHIELD_MATCH", baseReasonRaw: GuardianReasonCodeV1.personalShieldWarnOnly.rawValue,
            character: nil, register: nil, childOutcome: nil, familyDegradedNonAdult: false,
            childAnalysisDeficit: true)
        XCTAssertEqual(a.surfaceRaw, "SHIELD_MATCH")
        XCTAssertTrue(a.adjustments.contains("child:analysis-deferred-resource-limit"))
    }

    // THE MANDATED §1 TEST: ADULT→CHILD switch + thermal serious + static content → deficit state; old positive
    // decision cannot survive. We model it end-to-end at the adjudication boundary (the pure decision point): the
    // base surface was a prior positive GUARDIAN_ON (the old adult-era decision) and the live profile is now CHILD
    // with analysis skipped under thermal serious.
    func testAdultToChildThermalSeriousStaticContentDeficit() {
        let oldPositiveSurface = "GUARDIAN_ON"
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: oldPositiveSurface, baseReasonRaw: GuardianReasonCodeV1.generalContentExaminedNoMarker.rawValue,
            character: nil, register: nil, childOutcome: nil, familyDegradedNonAdult: false,
            childAnalysisDeficit: true)   // CHILD now active, thermal serious → analysis skipped
        XCTAssertEqual(a.surfaceRaw, "UNKNOWN")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.childAnalysisDeferred.rawValue)
    }

    func testAdultProfileNeverGetsChildDeficit() {
        // childAnalysisDeficit is computed only for a non-adult live profile; an adult path never sets it. With it
        // false, a benign adult surface is unchanged (no spurious deficit).
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON", baseReasonRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
            character: nil, register: nil, childOutcome: nil, familyDegradedNonAdult: false,
            childAnalysisDeficit: false)
        XCTAssertEqual(a.surfaceRaw, "GUARDIAN_ON")
    }

    // MARK: - §3 WORLD MODEL → GENERAL SURFACE for EVERY profile (no child, no personal rule)

    private func riskyWorldModelSafety() -> GuardianFamilySurfaceAdjudicatorV1.WorldModelSafetyInputV1 {
        // Build the REAL frozen safety result from risky TR text (the adult wellbeing path), then summarize it.
        let r = WorldModelEvidenceBridgeV1.build(WorldModelBridgeInputV1(
            sessionID: "S", contentID: "c1", itemIdentityRevision: 1, identityConfirmed: true, generation: 1,
            shotID: 1, observationStartMs: 0, observationEndMs: 10, ocrText: "savaş ve ölüm haberleri: büyük felaket",
            ocrLanguage: "tr", policyRevision: 1, familyProfileRevision: 0, photoShieldActionableMatch: false,
            emotionalRegister: nil))
        XCTAssertTrue(r.safety.cautionSupported || r.safety.strongProtectionSupported,
                      "the risky text must produce a supported safety finding")
        return .from(r.safety)
    }

    func testWorldModelCautionRaisesAdultGeneralSurfaceWithoutChildOrPersonalRule() {
        let wm = riskyWorldModelSafety()
        // ADULT (no childOutcome), NO personal rule (base GUARDIAN_ON benign) → the supported safety finding RAISES
        // the general surface to a CAUTION with its own world-model provenance reason.
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON", baseReasonRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
            character: nil, register: nil, childOutcome: nil, familyDegradedNonAdult: false,
            worldModelSafety: wm)
        XCTAssertEqual(a.surfaceRaw, "CAUTION", "world-model safety must influence the adult general surface")
        XCTAssertTrue(a.reasonCodeRaw == GuardianReasonCodeV1.worldModelSafetyCaution.rawValue
                      || a.reasonCodeRaw == GuardianReasonCodeV1.worldModelStrongProtection.rawValue)
        XCTAssertTrue(a.adjustments.contains { $0.hasPrefix("worldmodel:") })
    }

    func testBenignTextProducesNoPhantomWorldModelCaution() {
        // Benign TR text → no supported safety finding → the general surface stays benign (no phantom caution).
        let r = WorldModelEvidenceBridgeV1.build(WorldModelBridgeInputV1(
            sessionID: "S", contentID: "c2", itemIdentityRevision: 1, identityConfirmed: true, generation: 1,
            shotID: 1, observationStartMs: 0, observationEndMs: 10, ocrText: "bugün güzel bir kahvaltı yaptık",
            ocrLanguage: "tr", policyRevision: 1, familyProfileRevision: 0, photoShieldActionableMatch: false,
            emotionalRegister: nil))
        let wm = GuardianFamilySurfaceAdjudicatorV1.WorldModelSafetyInputV1.from(r.safety)
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON", baseReasonRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
            character: nil, register: nil, childOutcome: nil, familyDegradedNonAdult: false,
            worldModelSafety: wm)
        XCTAssertEqual(a.surfaceRaw, "GUARDIAN_ON", "benign content must not get a phantom world-model caution")
    }

    func testWorldModelNeverWeakensStandingShieldMatch() {
        let wm = riskyWorldModelSafety()
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "SHIELD_MATCH", baseReasonRaw: GuardianReasonCodeV1.personalShieldWarnOnly.rawValue,
            character: nil, register: nil, childOutcome: nil, familyDegradedNonAdult: false,
            worldModelSafety: wm)
        XCTAssertEqual(a.surfaceRaw, "SHIELD_MATCH", "a stricter personal warn is never weakened by the world model")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.personalShieldWarnOnly.rawValue)
        // The supported safety finding is still recorded in provenance (never silently dropped).
        XCTAssertTrue(a.adjustments.contains { $0.hasPrefix("worldmodel:supported-under-standing") })
    }

    // MARK: - §2 FAMILY REVISION IN GUARDIAN TRUTH

    private func facts(decItem: Int = 5, decPolicy: UInt64 = 2, curItem: Int = 5, curPolicy: UInt64 = 2,
                       decFam: UInt64? = 3, curFam: UInt64? = 3, nonAdult: Bool = false,
                       surface: String = "GUARDIAN_ON") -> GuardianRealityFactsV1 {
        GuardianRealityFactsV1(userRequestedOn: true, osCaptureStarted: true, framesArriving: true,
                               analysisActive: true, appGroupIPCWorking: true, liveActivityAccepted: true,
                               decisionItemIdentityRevision: decItem, decisionPolicyRevision: decPolicy,
                               decisionFresh: true, currentItemIdentityRevision: curItem,
                               currentPolicyRevision: curPolicy, lastDecisionSurfaceRaw: surface,
                               decisionFamilyRevision: decFam, currentFamilyRevision: curFam,
                               decisionFamilyNonAdult: nonAdult)
    }

    func testFamilyRevisionMatchIsValid() {
        let p = GuardianRealityProjectionV1.derive(facts(decFam: 3, curFam: 3))
        XCTAssertEqual(p.decisionValidity, .valid)
        XCTAssertEqual(p.islandSurfaceRaw, "GUARDIAN_ON")
        XCTAssertTrue(p.activeProtection)
    }

    func testFamilyRevisionChangedMakesDecisionStaleImmediately() {
        // The live family revision advanced past the decision's → STALE_FAMILY, surface collapses to UNKNOWN NOW.
        let p = GuardianRealityProjectionV1.derive(facts(decFam: 3, curFam: 4))
        XCTAssertEqual(p.decisionValidity, .staleFamily)
        XCTAssertEqual(p.islandSurfaceRaw, "UNKNOWN", "a family change can never carry over a positive surface")
        XCTAssertFalse(p.activeProtection)
    }

    func testChildTeenDecisionFailsClosedWhenFamilyUnverifiable() {
        // A child/teen decision with an UNKNOWN current family revision fails closed (never a stale child claim).
        let p = GuardianRealityProjectionV1.derive(facts(decFam: 3, curFam: nil, nonAdult: true))
        XCTAssertEqual(p.decisionValidity, .staleFamily)
        XCTAssertFalse(p.activeProtection)
    }

    func testChildTeenDecisionWithNoBoundFamilyRevisionFailsClosed() {
        let p = GuardianRealityProjectionV1.derive(facts(decFam: nil, curFam: 3, nonAdult: true))
        XCTAssertEqual(p.decisionValidity, .staleFamily)
    }

    func testAdultDecisionWithNoFamilyBindingUnaffected() {
        // Adult decision, no family binding → family check does not force stale (shield/freshness still govern).
        let p = GuardianRealityProjectionV1.derive(facts(decFam: nil, curFam: nil, nonAdult: false))
        XCTAssertEqual(p.decisionValidity, .valid)
    }

    func testLegacyHeartbeatDecodesWithoutFamilyFields() throws {
        // A legacy heartbeat JSON missing the R7 family keys must still decode (tolerant) with safe defaults.
        let legacyJSON = """
        {"epochSeconds":100.0,"sequence":1,"surfaceRaw":"GUARDIAN_ON","reasonCodeRaw":"textEvidenceBenign",
         "broadcasting":true,"sessionID":"S1","policyRevision":2,"itemIdentityRevision":5,
         "decisionEpochSeconds":100.0,"currentItemIdentityRevision":5}
        """
        let hb = try JSONDecoder().decode(GuardianObservationHeartbeatV1.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(hb.decisionFamilyRevision, 0, "legacy heartbeat → no family binding")
        XCTAssertEqual(hb.familyModeRaw, "")
        XCTAssertEqual(hb.familyStateRaw, "")
        XCTAssertEqual(hb.surfaceRaw, "GUARDIAN_ON")   // the rest decodes as before
    }

    func testHeartbeatFamilyFieldsRoundTrip() throws {
        let hb = GuardianObservationHeartbeatV1(
            epochSeconds: 1, sequence: 2, surfaceRaw: "CAUTION", reasonCodeRaw: "childAgeCaution",
            broadcasting: true, sessionID: "S", policyRevision: 2, itemIdentityRevision: 5,
            decisionEpochSeconds: 1, currentItemIdentityRevision: 5,
            decisionFamilyRevision: 7, familyModeRaw: "CHILD", familyStateRaw: "VALID")
        let data = try JSONEncoder().encode(hb)
        let back = try JSONDecoder().decode(GuardianObservationHeartbeatV1.self, from: data)
        XCTAssertEqual(back.decisionFamilyRevision, 7)
        XCTAssertEqual(back.familyModeRaw, "CHILD")
        XCTAssertEqual(back.familyStateRaw, "VALID")
    }

    // MARK: - §4 SINGLE-PASS EXPERT REUSE

    func testGeneralCharacterReusedEnvelopeEqualsSelfRun() {
        let text = "savaş ölüm tehlike felaket haberleri"
        // Shared single run of the four text experts (the live-path pattern).
        let shared = WorldModelEvidenceBridgeV1.runTextExperts(
            ocrText: text, ocrLanguage: "tr", contentID: "item-A", itemIdentityRevision: 7,
            identityConfirmed: true, generation: 3, shotID: 42)
        let languageEv = shared.first { $0.domain == .languageOCR }
        XCTAssertNotNil(languageEv)
        // Interpret the SHARED envelope (no second invocation) vs the self-run path — they must be identical.
        let reused = GeneralContentCharacterV1.evaluate(
            precomputedLanguageEvidence: languageEv, detectedLanguage: "tr",
            itemIdentityRevision: 7, policyRevision: 5, nowEpoch: 0)
        let selfRun = GeneralContentCharacterV1.evaluate(
            ocrText: text, detectedLanguage: "tr", itemIdentityRevision: 7, policyRevision: 5, nowEpoch: 0)
        XCTAssertEqual(reused.outcome, selfRun.outcome)
        XCTAssertEqual(reused.primaryCategory, selfRun.primaryCategory)
        XCTAssertEqual(reused.markers, selfRun.markers)
    }

    func testReusedEnvelopeNilFallsBackToNotAnalyzed() {
        let v = GeneralContentCharacterV1.evaluate(
            precomputedLanguageEvidence: nil, detectedLanguage: "tr",
            itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 0)
        XCTAssertEqual(v.outcome, .notAnalyzed, "no shared envelope must never fabricate a benign surface")
    }

    func testPerItemCensusShowsEachTextExpertExactlyOnce() {
        // Simulate the live-path census: runTextExperts returns one envelope per text expert; the census counts one
        // invocation each. GeneralContentCharacter reuses the LanguageOCR envelope (NOT a second invocation).
        let shared = WorldModelEvidenceBridgeV1.runTextExperts(
            ocrText: "savaş ölüm tehlike", ocrLanguage: "tr", contentID: "x", itemIdentityRevision: 1,
            identityConfirmed: true, generation: 1, shotID: 1)
        var census: [String: Int] = [:]
        for e in shared { census[e.domain.rawValue, default: 0] += 1 }
        // GeneralContentCharacter reuses — does NOT add another LanguageOCR invocation.
        let langEv = shared.first { $0.domain == .languageOCR }
        _ = GeneralContentCharacterV1.evaluate(precomputedLanguageEvidence: langEv, detectedLanguage: "tr",
                                               itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 0)
        var counters = GuardianSelfEvalCountersV1()
        counters.foldItemExpertCensus(census)
        // Each of the four frozen text-expert DOMAINS ran exactly once; no single-pass violation.
        for name in GuardianSelfEvalCountersV1.textExpertNames {
            XCTAssertEqual(counters.expertInvocationCensus[name], 1, "\(name) must run exactly once per item")
        }
        XCTAssertEqual(counters.duplicateTextExpertItems, 0, "no text expert ran twice on the single-pass path")
    }

    func testCensusDetectsADuplicateViolation() {
        // A regression where LanguageOCR ran twice for one item must be VISIBLE as a duplicate.
        var counters = GuardianSelfEvalCountersV1()
        counters.foldItemExpertCensus([ExpertDomainV2.languageOCR.rawValue: 2])
        XCTAssertEqual(counters.duplicateTextExpertItems, 1)
    }
}
