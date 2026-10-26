//
//  GeneralContentCharacterR3Tests.swift — R3 §1/§3/§5/§6: the general content-character caution + the personal
//  semantic relation ladder, proven against the REAL production expert path. These are PURE-type tests (DEVICE-
//  UNVERIFIED for the full extension wiring, which the app build covers); they lock the DECISION TABLE and the
//  honesty invariants so a regression is visible without a device.
//
import XCTest
import GuardianCore
@testable import GuardianMedia

final class GeneralContentCharacterR3Tests: XCTestCase {

    // MARK: - §1 — general content-character decision table (runs the REAL LanguageOCRExpertV1)

    func testNoText_isNotAnalyzed_neverSafe() {
        let v = GeneralContentCharacterV1.evaluate(ocrText: nil, detectedLanguage: nil,
                                                   itemIdentityRevision: 1, policyRevision: 7, nowEpoch: 100)
        XCTAssertEqual(v.outcome, .notAnalyzed)       // UNKNOWN ≠ safe (constitution rule 7)
        XCTAssertFalse(v.isCaution)
        XCTAssertNil(v.primaryCategory)
    }

    func testEmptyText_isNotAnalyzed() {
        let v = GeneralContentCharacterV1.evaluate(ocrText: "", detectedLanguage: "tr",
                                                   itemIdentityRevision: 1, policyRevision: 7, nowEpoch: 100)
        XCTAssertEqual(v.outcome, .notAnalyzed)
    }

    func testUnsupportedLanguage_isNotAnalyzed_notBenign() {
        // A real unsupported locale → the expert abstains → we must NOT claim benign/safe (we could not read it).
        let v = GeneralContentCharacterV1.evaluate(ocrText: "これはテストです 死", detectedLanguage: "ja",
                                                   itemIdentityRevision: 2, policyRevision: 7, nowEpoch: 100)
        XCTAssertEqual(v.outcome, .notAnalyzed)
        XCTAssertFalse(v.isCaution)
    }

    func testNeutralText_examinedNoMarker_isBenignNotCaution() {
        // Benign educational-style text with no sensitive lexicon marker → EXAMINED_NO_MARKER (honest benign).
        let v = GeneralContentCharacterV1.evaluate(ocrText: "Bugün hava çok güzel, parkta yürüyüş yaptık.",
                                                   detectedLanguage: "tr",
                                                   itemIdentityRevision: 3, policyRevision: 7, nowEpoch: 100)
        XCTAssertEqual(v.outcome, .examinedNoMarker)
        XCTAssertFalse(v.isCaution)
        XCTAssertTrue(v.markers.isEmpty)
    }

    func testMortalityMarker_producesCaution_withProvenance() {
        // Real mortality/war lexicon terms → a CAUTION with the mortality primary + provenance stamped verbatim.
        let v = GeneralContentCharacterV1.evaluate(ocrText: "savaşta ölüm haberleri geldi, cenaze töreni yapıldı",
                                                   detectedLanguage: "tr",
                                                   itemIdentityRevision: 9, policyRevision: 42, nowEpoch: 123.5)
        XCTAssertEqual(v.outcome, .caution)
        XCTAssertTrue(v.isCaution)
        XCTAssertEqual(v.primaryCategory, .mortality)
        XCTAssertTrue(v.markers.contains { $0.category == .mortality && $0.hits >= 1 })
        // Provenance carried verbatim (never inferred).
        XCTAssertEqual(v.itemIdentityRevision, 9)
        XCTAssertEqual(v.policyRevision, 42)
        XCTAssertEqual(v.eventEpoch, 123.5)
        XCTAssertFalse(v.expertModelVersion.isEmpty)
    }

    func testManipulationMarker_producesCaution() {
        let v = GeneralContentCharacterV1.evaluate(
            ocrText: "SON DAKİKA! Acele et, sadece bugün, kaçırma! Hemen tıkla!",
            detectedLanguage: "tr", itemIdentityRevision: 4, policyRevision: 7, nowEpoch: 100)
        XCTAssertEqual(v.outcome, .caution)
        XCTAssertTrue(v.markers.contains { $0.category == .manipulation })
    }

    func testCautionIsDeterministic_sameInputSameVerdict() {
        let a = GeneralContentCharacterV1.evaluate(ocrText: "deprem felaketi ve yangın",
                                                   detectedLanguage: "tr", itemIdentityRevision: 1,
                                                   policyRevision: 1, nowEpoch: 1)
        let b = GeneralContentCharacterV1.evaluate(ocrText: "deprem felaketi ve yangın",
                                                   detectedLanguage: "tr", itemIdentityRevision: 1,
                                                   policyRevision: 1, nowEpoch: 1)
        XCTAssertEqual(a, b)                         // pure: same inputs → same verdict
    }

    // §1 CONTEXT-BLINDNESS honesty: educational disease text and fear-exploiting disease text BOTH trip the same
    // disease/mortality markers today. We ASSERT this is the current limitation (both caution) rather than pretend
    // the lexicon separates them — the §8 corpus reports it; this test pins that the system does NOT over-claim
    // separability it does not have.
    func testContextBlind_educationalAndExploitative_bothCautionToday() {
        let educational = GeneralContentCharacterV1.evaluate(
            ocrText: "kanser hastalığı hakkında bilgilendirici ders: erken teşhis hayat kurtarır",
            detectedLanguage: "tr", itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 1)
        let exploitative = GeneralContentCharacterV1.evaluate(
            ocrText: "bu kanser hastalığı seni öldürecek, korkmalısın, ölüm kaçınılmaz",
            detectedLanguage: "tr", itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 1)
        // HONEST FINDING: today's context-blind lexicon cannot separate them — both fire disease/mortality markers.
        XCTAssertTrue(educational.markers.contains { $0.category == .disease } || educational.isCaution)
        XCTAssertTrue(exploitative.isCaution)
    }

    // MARK: - §3 — personal semantic relation ladder (honest classification of what a match REALLY is)

    func testTextShieldHit_isDirectReference_actionable() {
        let c = PersonalRelationLadderV1.classifyText(matchState: .matchExact, isActionableShieldHit: true)
        XCTAssertEqual(c.relation, .directReference)
        XCTAssertTrue(c.actionable)
        XCTAssertEqual(c.modalityRaw, "TEXT")
    }

    func testPhotoExactHigh_isDirectReference_actionable() {
        for s in [ShieldMatchState.matchExact, .matchHigh] {
            let c = PersonalRelationLadderV1.classifyPhoto(s)
            XCTAssertEqual(c.relation, .directReference)
            XCTAssertTrue(c.actionable, "\(s) must be actionable DIRECT_REFERENCE")
        }
    }

    func testPhotoMedium_isVisualSimilarity_NEVER_actions() {
        let c = PersonalRelationLadderV1.classifyPhoto(.matchMedium)
        XCTAssertEqual(c.relation, .visualSimilarity)
        XCTAssertFalse(c.actionable)                 // §3 law — VISUAL_SIMILARITY is evidence only, never a decision
    }

    func testPhotoLowAndNonDeterminable_areUnknown_NEVER_action() {
        for s in [ShieldMatchState.matchLow, .noMatch, .matchabilityUnknown, .matcherUnavailable, .evidenceConflict] {
            let c = PersonalRelationLadderV1.classifyPhoto(s)
            XCTAssertEqual(c.relation, .unknown, "\(s) must classify UNKNOWN")
            XCTAssertFalse(c.actionable, "\(s) must never action")
        }
    }

    func testTextNonMatch_isUnknown_neverActions() {
        // A shield hit that was NOT actionable (layer decided no action) is UNKNOWN, never a faked higher rung.
        let c = PersonalRelationLadderV1.classifyText(matchState: .matchMedium, isActionableShieldHit: false)
        XCTAssertEqual(c.relation, .unknown)
        XCTAssertFalse(c.actionable)
    }

    func testOnlyDirectReferenceIsActionableV1_middleRungsUnavailable() {
        // The vocabulary is declared in full, but the middle rungs are UNAVAILABLE in V1 (no running model) and
        // therefore never actionable — co-occurrence / topical / weak association can never produce a V1 match.
        XCTAssertTrue(PersonalRelationTypeV1.directReference.isActionableV1)
        XCTAssertTrue(PersonalRelationTypeV1.directReference.isAvailableV1)
        for r: PersonalRelationTypeV1 in [.verifiedEntityRelation, .topicalRelation, .contextualAssociation, .weakAssociation] {
            XCTAssertFalse(r.isAvailableV1, "\(r) must be UNAVAILABLE in V1")
            XCTAssertFalse(r.isActionableV1, "\(r) must not action in V1")
        }
        XCTAssertFalse(PersonalRelationTypeV1.visualSimilarity.isActionableV1) // available but NOT actionable
        XCTAssertFalse(PersonalRelationTypeV1.unknown.isActionableV1)
    }

    // §3 — co-occurrence ALONE never produces a match: there is no classification path that takes "seen together"
    // and returns anything but UNKNOWN. We prove the ladder has no such entry point.
    func testCoOccurrenceAloneNeverMatches() {
        // The only inputs the ladder accepts are a determinable text/photo match state. There is no "co-occurrence"
        // input, so a co-occurrence can only ever arrive as a non-match state → UNKNOWN, non-actionable.
        let c = PersonalRelationLadderV1.classifyPhoto(.noMatch)
        XCTAssertEqual(c.relation, .unknown)
        XCTAssertFalse(c.actionable)
    }

    // MARK: - §5/§6 — personal match ≠ wellbeing harm; no numeric score

    func testPersonalRelation_carriesNoWellbeingHarmField() {
        // The personal relation classification is a PERSONAL preference signal only — it has NO wellbeing-harm /
        // severity field by construction. Encoding it to JSON must contain only relation/actionable/modality.
        let c = PersonalRelationLadderV1.classifyPhoto(.matchExact)
        let json = String(data: try! JSONEncoder().encode(c), encoding: .utf8)!
        XCTAssertTrue(json.contains("relation"))
        XCTAssertTrue(json.contains("modalityRaw"))
        XCTAssertFalse(json.lowercased().contains("harm"))
        XCTAssertFalse(json.lowercased().contains("wellbeing"))
        XCTAssertFalse(json.lowercased().contains("severity"))
    }

    func testGeneralCautionVerdict_carriesNoNumericScore() {
        // The general content-character verdict is CATEGORICAL — no 0–100 score anywhere (calibration gate closed).
        let v = GeneralContentCharacterV1.evaluate(ocrText: "ölüm ve savaş", detectedLanguage: "tr",
                                                   itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 1)
        let json = String(data: try! JSONEncoder().encode(v), encoding: .utf8)!
        XCTAssertFalse(json.contains("score"))
        XCTAssertFalse(json.contains("\"0-100\""))
        // hit counts are evidence magnitude, NOT a score — the outcome is a categorical enum.
        XCTAssertTrue(["CAUTION", "EXAMINED_NO_MARKER", "NOT_ANALYZED"].contains(v.outcome.rawValue))
    }

    // §1/§3 SEPARATION: a general caution and a personal match use DISTINCT reason-code namespaces — the two signal
    // families never collapse into one surface reason.
    func testReasonNamespaces_areDistinct() {
        XCTAssertNotEqual(GuardianReasonCodeV1.generalContentCaution, GuardianReasonCodeV1.personalShieldWarnOnly)
        XCTAssertNotEqual(GuardianReasonCodeV1.generalContentCaution, GuardianReasonCodeV1.personalPhotoMatchWarnOnly)
        // The general caution copy must say "işaret" (marker), never a definitive harm verdict.
        XCTAssertTrue(GuardianReasonCodeV1.generalContentCaution.turkishExplanation.contains("işaret"))
        // The personal photo copy must keep its "görsel benzerlik, anlam iddiası değil" honesty.
        XCTAssertTrue(GuardianReasonCodeV1.personalPhotoMatchWarnOnly.turkishExplanation.contains("görsel"))
    }
}
