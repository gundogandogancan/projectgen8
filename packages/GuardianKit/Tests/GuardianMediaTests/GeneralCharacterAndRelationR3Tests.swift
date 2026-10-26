//
//  GeneralCharacterAndRelationR3Tests.swift — R3 §1/§3/§5/§6 PROOF: the general content-character caution decision
//  table, the personal semantic relation ladder, and the hard separation/precedence laws.
//
//  ALL inputs are SYNTHETIC text/tiers (not a real iPhone / real social apps) → DEVICE_UNVERIFIED. These tests prove
//  the LOGIC: what the real `LanguageOCRExpertV1` output maps to, which rungs action, and that personal ≠ wellbeing.
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class GeneralCharacterAndRelationR3Tests: XCTestCase {

    // ================= R3 §1 — GENERAL CONTENT-CHARACTER DECISION TABLE =================

    /// No OCR text ⇒ NOT_ANALYZED (UNKNOWN ≠ safe, constitution rule 6/7). Never a benign/positive surface.
    func testNoText_isNotAnalyzed_neverSafe() {
        let v = GeneralContentCharacterV1.evaluate(ocrText: nil, detectedLanguage: "en",
                                                   itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 0)
        XCTAssertEqual(v.outcome, .notAnalyzed)
        XCTAssertFalse(v.isCaution)
        XCTAssertNil(v.primaryCategory)
    }

    /// Empty OCR text ⇒ NOT_ANALYZED (same honesty as nil).
    func testEmptyText_isNotAnalyzed() {
        let v = GeneralContentCharacterV1.evaluate(ocrText: "", detectedLanguage: "en",
                                                   itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 0)
        XCTAssertEqual(v.outcome, .notAnalyzed)
    }

    /// Unsupported language ⇒ the real expert abstains ⇒ NOT_ANALYZED (never a benign claim on unread text).
    func testUnsupportedLanguage_abstains_notAnalyzed() {
        // Real French mortality words, but the expert supports only tr/en → UNSUPPORTED_LANGUAGE abstention.
        let v = GeneralContentCharacterV1.evaluate(ocrText: "décès et funérailles tragiques",
                                                   detectedLanguage: "fr",
                                                   itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 0)
        XCTAssertEqual(v.outcome, .notAnalyzed)
        XCTAssertFalse(v.isCaution)
    }

    /// Benign supported text with NO lexicon marker ⇒ EXAMINED_NO_MARKER (honest benign, NOT a blanket "safe").
    func testBenignSupportedText_examinedNoMarker() {
        let v = GeneralContentCharacterV1.evaluate(ocrText: "a calm afternoon walk in the park with friends",
                                                   detectedLanguage: "en",
                                                   itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 0)
        XCTAssertEqual(v.outcome, .examinedNoMarker)
        XCTAssertFalse(v.isCaution)
        XCTAssertTrue(v.markers.isEmpty)
    }

    /// A real supported marker (English mortality lexicon) ⇒ CAUTION with the mortality marker carried as provenance.
    func testMortalityMarker_caution_withProvenance() {
        let v = GeneralContentCharacterV1.evaluate(ocrText: "breaking: three people died in the fatal crash",
                                                   detectedLanguage: "en",
                                                   itemIdentityRevision: 7, policyRevision: 3, nowEpoch: 123)
        XCTAssertEqual(v.outcome, .caution)
        XCTAssertTrue(v.isCaution)
        XCTAssertTrue(v.markers.contains { $0.category == .mortality })
        // Provenance stamped verbatim (item/policy/time) — so a marker can never drift to another item.
        XCTAssertEqual(v.itemIdentityRevision, 7)
        XCTAssertEqual(v.policyRevision, 3)
        XCTAssertEqual(v.eventEpoch, 123)
        // The outcome raw is exactly the "CAUTION" token SampleHandler maps to the Island surface (NativeSurfaceState
        // .caution). The verdict itself carries no surface field — the surface mapping lives on the decision path.
        XCTAssertEqual(v.outcome.rawValue, "CAUTION")
    }

    /// Turkish supported text with a disaster marker ⇒ CAUTION (the TR lexicon path really runs).
    func testTurkishDisasterMarker_caution() {
        let v = GeneralContentCharacterV1.evaluate(ocrText: "deprem ve sel felaketi haberleri",
                                                   detectedLanguage: "tr",
                                                   itemIdentityRevision: 2, policyRevision: 1, nowEpoch: 0)
        XCTAssertEqual(v.outcome, .caution)
        XCTAssertTrue(v.markers.contains { $0.category == .disaster })
    }

    /// Honesty discipline: the reason copy is a MARKER ("işaret"), never a definitive harm verdict (mandate §1).
    func testCautionReason_isMarkerNotVerdict() {
        let r = GuardianReasonCodeV1.generalContentCaution.turkishExplanation
        XCTAssertTrue(r.contains("işaret"), "general caution copy must say 'işaret' (marker), got: \(r)")
        XCTAssertFalse(r.lowercased().contains("kesinlikle zararlı"), "must never assert certain harm")
    }

    // ================= R3 §3 — PERSONAL SEMANTIC RELATION LADDER =================

    /// A real text shield hit the evaluator acted on ⇒ DIRECT_REFERENCE (text), actionable.
    func testTextShieldHit_isDirectReference_actionable() {
        let c = PersonalRelationLadderV1.classifyText(matchState: .matchExact, isActionableShieldHit: true)
        XCTAssertEqual(c.relation, .directReference)
        XCTAssertTrue(c.actionable)
        XCTAssertEqual(c.modalityRaw, "TEXT")
    }

    /// A photo EXACT/HIGH match ⇒ DIRECT_REFERENCE (visual), actionable.
    func testPhotoExactHigh_isDirectReference_actionable() {
        for state: ShieldMatchState in [.matchExact, .matchHigh] {
            let c = PersonalRelationLadderV1.classifyPhoto(state)
            XCTAssertEqual(c.relation, .directReference, "\(state) should be DIRECT_REFERENCE")
            XCTAssertTrue(c.actionable)
            XCTAssertEqual(c.modalityRaw, "VISUAL")
        }
    }

    /// A photo MEDIUM match ⇒ VISUAL_SIMILARITY, and VISUAL_SIMILARITY NEVER actions (mandate §3 hard law).
    func testPhotoMedium_isVisualSimilarity_neverActions() {
        let c = PersonalRelationLadderV1.classifyPhoto(.matchMedium)
        XCTAssertEqual(c.relation, .visualSimilarity)
        XCTAssertFalse(c.actionable, "VISUAL_SIMILARITY must never action in V1")
    }

    /// LOW / non-determinable photo states ⇒ UNKNOWN, and UNKNOWN NEVER actions (constitution rule 7).
    func testPhotoWeakOrUnknown_isUnknown_neverActions() {
        for state: ShieldMatchState in [.matchLow, .noMatch, .matchabilityUnknown, .matcherUnavailable, .evidenceConflict] {
            let c = PersonalRelationLadderV1.classifyPhoto(state)
            XCTAssertEqual(c.relation, .unknown, "\(state) should be UNKNOWN")
            XCTAssertFalse(c.actionable, "\(state) must never action")
        }
    }

    /// A text match the evaluator did NOT act on (shieldHit=false) ⇒ UNKNOWN, never a faked higher rung.
    func testTextNonActedMatch_isUnknown() {
        let c = PersonalRelationLadderV1.classifyText(matchState: .matchMedium, isActionableShieldHit: false)
        XCTAssertEqual(c.relation, .unknown)
        XCTAssertFalse(c.actionable)
    }

    /// The UNAVAILABLE rungs are declared but structurally unavailable in V1 (no running model) — never fabricated.
    func testUpperRungs_declaredUnavailable() {
        for rung: PersonalRelationTypeV1 in [.verifiedEntityRelation, .topicalRelation,
                                             .contextualAssociation, .weakAssociation] {
            XCTAssertFalse(rung.isAvailableV1, "\(rung) must be UNAVAILABLE in V1")
            XCTAssertFalse(rung.isActionableV1, "\(rung) must never be actionable in V1")
        }
        // Only DIRECT_REFERENCE is actionable at all.
        XCTAssertTrue(PersonalRelationTypeV1.directReference.isActionableV1)
        for other in PersonalRelationTypeV1.allCases where other != .directReference {
            XCTAssertFalse(other.isActionableV1, "\(other) must not be actionable")
        }
    }

    // ================= R3 §5/§6 — SEPARATION + NO-SCORE =================

    /// §5 — a personal match NEVER raises a wellbeing-harm category: the personal relation struct has NO wellbeing
    /// field and the personal reason codes are a DISJOINT namespace from the general content-character reason codes.
    func testPersonalAndWellbeing_reasonNamespaces_disjoint() {
        let personalReasons: Set<GuardianReasonCodeV1> = [.personalShieldWarnOnly, .personalPhotoMatchWarnOnly,
                                                          .textEvidenceMatchedShield]
        let generalReasons: Set<GuardianReasonCodeV1> = [.generalContentCaution, .generalContentExaminedNoMarker,
                                                        .generalContentNotAnalyzed]
        XCTAssertTrue(personalReasons.isDisjoint(with: generalReasons),
                      "personal-shield and general-wellbeing reason codes must be distinct (mandate §3/§5)")
        // A relation classification carries NO harm claim — it is personal-filter provenance only.
        let c = PersonalRelationLadderV1.classifyPhoto(.matchExact)
        XCTAssertTrue(c.modalityRaw == "VISUAL")   // provenance, not a content/harm verdict
    }

    /// §5 — a personal visual match reason explicitly disclaims any meaning/harm claim about the content.
    func testPersonalPhotoReason_disclaimsMeaningClaim() {
        let r = GuardianReasonCodeV1.personalPhotoMatchWarnOnly.turkishExplanation
        XCTAssertTrue(r.contains("görsel"), "must frame as a visual match")
        XCTAssertTrue(r.contains("anlamı hakkında bir iddia değildir") || r.contains("yalnızca görsel"),
                      "personal photo match must NOT claim content meaning/harm")
    }

    /// §5 — NO numeric 0–100 score appears in any new surface's reason copy (calibration gate still closed).
    func testNoNumericScore_inNewReasonCopy() {
        let copies = [GuardianReasonCodeV1.generalContentCaution.turkishExplanation,
                      GuardianReasonCodeV1.generalContentExaminedNoMarker.turkishExplanation,
                      GuardianReasonCodeV1.generalContentNotAnalyzed.turkishExplanation]
        for c in copies {
            // No standalone 0–100 integer token in the honest copy (markers/counts are not surfaced as a score).
            for n in 0...100 {
                XCTAssertFalse(c.contains(" \(n) "), "reason copy must carry no numeric score: found \(n) in \(c)")
            }
        }
    }
}
