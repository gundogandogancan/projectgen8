//
//  AdjudicatorR6Tests.swift — R6 §3: ADJUDICATION FIXES.
//   • §3.1 — an emotional-pressure (or targeted-pressure) finding with NO lexicon category must STILL produce a
//     reasoned categorical caution (R5 could lose it when the base surface was not already CAUTION and no marker
//     fired). Counter-examples: supportive 2nd-person speech must NOT alarm; informational register never upgrades.
//   • §3.2 — child vs personal precedence: AGE_RESTRICTED must NOT silently ERASE a personal SHIELD_MATCH's evidence.
//     The primary reason follows canonical precedence (child floor), but the secondary (personal) evidence survives
//     in provenance (dual-evidence).
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class AdjudicatorR6Tests: XCTestCase {

    private func pressure(_ r: EmotionalRegisterV1 = .fearPressure) -> EmotionalRegisterVerdictV1 {
        EmotionalRegisterVerdictV1(register: r, support: .supported, evidence: ["ev"], languageRaw: "tr",
                                   itemIdentityRevision: 1, policyRevision: 1, eventEpoch: 0,
                                   adapterVersion: EmotionalRegisterAdapterV1.version)
    }
    private func targeted(_ mech: CovertPressureMechanismV1) -> TargetedPressureVerdictV1 {
        TargetedPressureVerdictV1(target: .directedSecondPerson, act: .none, mechanism: mech, support: .supported,
                                  quotedNotOwnVoice: false, evidence: ["mech"], languageRaw: "tr",
                                  itemIdentityRevision: 1, policyRevision: 1, eventEpoch: 0,
                                  heuristicVersion: TargetedPressureHeuristicV1.version)
    }

    // MARK: §3.1 — pressure with NO lexicon category still surfaces a caution

    func testPressureRegisterWithNoMarkerStillCautions() {
        // base GUARDIAN_ON, NO general-character marker (character == nil), supported pressure register → CAUTION.
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON", baseReasonRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
            character: nil, register: pressure(.coerciveThreat), childOutcome: nil, familyDegradedNonAdult: false)
        XCTAssertEqual(a.surfaceRaw, "CAUTION", "a supported pressure register must not be lost when no marker fired")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.emotionalRegisterPressureCaution.rawValue)
    }

    func testPressureRegisterOnUnknownBaseStillCautions() {
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "UNKNOWN", baseReasonRaw: GuardianReasonCodeV1.textEvidenceUnavailable.rawValue,
            character: nil, register: pressure(.fearPressure), childOutcome: nil, familyDegradedNonAdult: false)
        XCTAssertEqual(a.surfaceRaw, "CAUTION")
    }

    func testTargetedPressureWithNoMarkerStillCautions() {
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON", baseReasonRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
            character: nil, register: nil, childOutcome: nil, familyDegradedNonAdult: false,
            targetedPressure: targeted(.guiltShameCoercion))
        XCTAssertEqual(a.surfaceRaw, "CAUTION")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.targetedPressureCaution.rawValue)
    }

    // MARK: §3.1 — counter-examples (no false alarms)

    func testSupportiveTargetedVerdictNeverAlarms() {
        let supportive = TargetedPressureVerdictV1(target: .directedSecondPerson, act: .none, mechanism: .none,
                                                   support: .supported, quotedNotOwnVoice: false, evidence: [],
                                                   languageRaw: "tr", itemIdentityRevision: 1, policyRevision: 1,
                                                   eventEpoch: 0, heuristicVersion: TargetedPressureHeuristicV1.version)
        XCTAssertFalse(supportive.isSupportedPressure)
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON", baseReasonRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
            character: nil, register: nil, childOutcome: nil, familyDegradedNonAdult: false,
            targetedPressure: supportive)
        XCTAssertEqual(a.surfaceRaw, "GUARDIAN_ON", "supportive 2nd-person must never alarm")
    }

    func testInformationalRegisterNeverUpgrades() {
        let info = EmotionalRegisterVerdictV1(register: .informational, support: .supported, evidence: [],
                                              languageRaw: "tr", itemIdentityRevision: 1, policyRevision: 1,
                                              eventEpoch: 0, adapterVersion: EmotionalRegisterAdapterV1.version)
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON", baseReasonRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
            character: nil, register: info, childOutcome: nil, familyDegradedNonAdult: false)
        XCTAssertEqual(a.surfaceRaw, "GUARDIAN_ON")
    }

    // MARK: §3.2 — dual-evidence: AGE_RESTRICTED preserves the personal SHIELD_MATCH evidence

    func testChildRestrictedPreservesPersonalEvidence() {
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "SHIELD_MATCH", baseReasonRaw: GuardianReasonCodeV1.personalShieldWarnOnly.rawValue,
            character: nil, register: nil, childOutcome: .restricted, familyDegradedNonAdult: false)
        // Primary follows canonical precedence (child floor).
        XCTAssertEqual(a.surfaceRaw, "CAUTION")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.childAgeRestricted.rawValue)
        // But the personal evidence is NOT erased — it survives in provenance (dual-evidence).
        XCTAssertTrue(a.adjustments.contains(GuardianReasonCodeV1.dualEvidenceChildPlusPersonal.rawValue),
                      "the personal shield evidence must be recorded, not erased: \(a.adjustments)")
        XCTAssertTrue(a.adjustments.contains { $0.hasPrefix("secondary:") },
                      "the displaced personal reason must be preserved as a secondary: \(a.adjustments)")
    }

    func testChildCautionPreservesPersonalEvidenceAndKeepsShieldSurface() {
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "SHIELD_MATCH", baseReasonRaw: GuardianReasonCodeV1.personalShieldWarnOnly.rawValue,
            character: nil, register: nil, childOutcome: .caution, familyDegradedNonAdult: false)
        // AGE_CAUTION + SHIELD_MATCH: both warn; the personal warn keeps the surface, dual-evidence recorded.
        XCTAssertEqual(a.surfaceRaw, "SHIELD_MATCH")
        XCTAssertTrue(a.adjustments.contains(GuardianReasonCodeV1.dualEvidenceChildPlusPersonal.rawValue))
    }

    func testNoDualEvidenceWhenNoCompetingPersonalSurface() {
        // AGE_RESTRICTED on a plain GUARDIAN_ON base: no personal evidence to preserve → no dual-evidence record.
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON", baseReasonRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
            character: nil, register: nil, childOutcome: .restricted, familyDegradedNonAdult: false)
        XCTAssertEqual(a.surfaceRaw, "CAUTION")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.childAgeRestricted.rawValue)
        // A benign base carried no competing safety evidence, so there is nothing to preserve as secondary.
        XCTAssertFalse(a.adjustments.contains(GuardianReasonCodeV1.dualEvidenceChildPlusPersonal.rawValue))
    }
}
