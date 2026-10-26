//
//  EmotionalRegisterR5Tests.swift — R5 §5 (P1-5): emotional register structural classification + the surface
//  adjudicator precedence laws. Register ≠ stance (separate fields); REPORTS stance + FEAR_PRESSURE register
//  surfaces BOTH; the CHILD floor outranks personal softening; degraded family reads fail closed.
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class EmotionalRegisterR5Tests: XCTestCase {

    private func assess(_ text: String, _ lang: String) -> EmotionalRegisterVerdictV1 {
        EmotionalRegisterAdapterV1.assessRegister(text: text, language: lang, itemIdentityRevision: 1,
                                                  policyRevision: 1, nowEpoch: 1000)
    }

    // MARK: register classes — TR

    func testCoerciveThreatTR() {
        let v = assess("Bu videoyu paylaşmazsan başına kötü şeyler gelecek", "tr")
        XCTAssertEqual(v.register, .coerciveThreat)
        XCTAssertTrue(v.evidence.contains("threat:conditional"))
        XCTAssertTrue(v.register.isPressure)
    }

    func testUrgencyViaFearTR() {
        let v = assess("Büyük tehlike kapıda, hemen al ve korunmak için şimdi harekete geç", "tr")
        XCTAssertEqual(v.register, .urgencyViaFear)
        XCTAssertTrue(v.evidence.contains("couple:fear+cta"))
    }

    func testFearPressureTR() {
        let v = assess("Sen büyük tehlike altındasın, bunu bilmelisin", "tr")
        XCTAssertEqual(v.register, .fearPressure)
        XCTAssertTrue(v.evidence.contains("addressee:2nd-person"))
    }

    func testSensationalPanicTR() {
        let v = assess("Şok! Korkunç felaket! Her şey bitti!!", "tr")
        XCTAssertEqual(v.register, .sensationalPanic)
    }

    func testSupportiveTR() {
        let v = assess("Yalnız değilsin, yanındayız. Destek için buradayız.", "tr")
        XCTAssertEqual(v.register, .supportive)
        XCTAssertFalse(v.register.isPressure)
    }

    func testInformationalTR() {
        let v = assess("Araştırmaya göre düzenli egzersiz kalp hastalığı riskini azaltır.", "tr")
        XCTAssertEqual(v.register, .informational)
    }

    func testQuotedThreatAbstainsTR() {
        let v = assess("Saldırgan \"hepinize büyük tehlike yaşatacağım\" dedi, polis soruşturma başlattı", "tr")
        XCTAssertEqual(v.register, .unknown, "a QUOTED threat is not the speaker's own register")
        XCTAssertFalse(v.register.isPressure)
    }

    // MARK: register classes — EN

    func testCoerciveThreatEN() {
        let v = assess("If you don't share this video, something terrible will happen to you", "en")
        XCTAssertEqual(v.register, .coerciveThreat)
    }

    func testUrgencyViaFearEN() {
        let v = assess("Terrifying danger ahead - buy now before it is too late", "en")
        XCTAssertEqual(v.register, .urgencyViaFear)
    }

    func testFearPressureEN() {
        let v = assess("Warning: you are in grave danger and nobody will protect your family", "en")
        XCTAssertEqual(v.register, .fearPressure)
    }

    func testSensationalPanicEN() {
        let v = assess("SHOCKING!! Total disaster everywhere, nothing is left!!", "en")
        XCTAssertEqual(v.register, .sensationalPanic)
    }

    func testSupportiveEN() {
        let v = assess("You are not alone. We are with you and support is available.", "en")
        XCTAssertEqual(v.register, .supportive)
    }

    func testInformationalEN() {
        let v = assess("According to research, regular exercise reduces the risk of heart disease.", "en")
        XCTAssertEqual(v.register, .informational)
    }

    func testQuotedThreatAbstainsEN() {
        let v = assess("The suspect said \"I will make this a disaster for all of you\" during the arrest", "en")
        XCTAssertEqual(v.register, .unknown)
    }

    // MARK: abstention laws

    func testUnsupportedLanguageNotApplicable() {
        let v = assess("Das ist eine große Gefahr für alle", "de")
        XCTAssertEqual(v.support, .notApplicable)
        XCTAssertEqual(v.register, .unknown)
    }

    func testBareTopicMentionAbstains() {
        // 3rd-person bare fear-topic mention with no structure (possible irony) → UNKNOWN BY DESIGN.
        let v = assess("tehlike konusu dün yine gündemdeydi", "tr")
        XCTAssertEqual(v.register, .unknown)
    }

    func testInsufficientTextAbstains() {
        XCTAssertEqual(assess("ok", "en").register, .unknown)
    }

    // MARK: stance ≠ register (separate dimensions, measured separately)

    func testReportsStanceAndPressureRegisterCoexist() {
        // A reporting-framed sensational panic text: stance can say REPORTS while register says pressure —
        // the two dimensions are SEPARATE fields, computed independently.
        let text = "Korkunç felaket! Şok görüntüler! Hemen izle, büyük tehlike yayılıyor!!"
        let reg = assess(text, "tr")
        XCTAssertTrue(reg.register.isPressure, "register=\(reg.register)")
        let stance = ContextEvidenceAdapterV1.assessStance(text: text, language: "tr", itemIdentityRevision: 1,
                                                           policyRevision: 1, nowEpoch: 1000)
        // Whatever the stance adapter concludes, the register field is its own verdict — never merged.
        XCTAssertNotNil(stance.stance)
    }

    // MARK: the adjudicator precedence laws (pure; pinned here, consumed by SampleHandler)

    private func softenedCharacter() -> GeneralContentCharacterVerdictV1 {
        GeneralContentCharacterVerdictV1(outcome: .contextAssessed, primaryCategory: .mortality,
                                         markers: [GeneralContentMarkerV1(category: .mortality, hits: 2)],
                                         languageRaw: "tr", ocrNoisy: false, itemIdentityRevision: 1,
                                         policyRevision: 1, eventEpoch: 0, expertModelVersion: "test",
                                         contextStance: .reports, contextEffect: .softenToNote,
                                         contextEvidence: ["frame:report"])
    }
    private func pressure(_ r: EmotionalRegisterV1 = .fearPressure) -> EmotionalRegisterVerdictV1 {
        EmotionalRegisterVerdictV1(register: r, support: .supported, evidence: ["test"], languageRaw: "tr",
                                   itemIdentityRevision: 1, policyRevision: 1, eventEpoch: 0,
                                   adapterVersion: EmotionalRegisterAdapterV1.version)
    }

    func testReportsStancePlusFearPressureSurfacesBoth() {
        // THE §5 PIN: a REPORTS-softened marker + a FEAR_PRESSURE register must NOT stay softened — the register
        // blocks the softening and the caution carries the DISTINCT register reason. Reporting ≠ emotionally neutral.
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON",
            baseReasonRaw: GuardianReasonCodeV1.generalContentContextSoftened.rawValue,
            character: softenedCharacter(), register: pressure(.fearPressure),
            childOutcome: nil, familyDegradedNonAdult: false)
        XCTAssertEqual(a.surfaceRaw, "CAUTION")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.emotionalRegisterPressureCaution.rawValue)
    }

    func testInformationalRegisterNeverSoftensAnything() {
        // INFORMATIONAL may only ACCOMPANY stance softening — it adjusts nothing by itself.
        let plainCaution = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "CAUTION", baseReasonRaw: GuardianReasonCodeV1.generalContentCaution.rawValue,
            character: nil,
            register: EmotionalRegisterVerdictV1(register: .informational, support: .supported, evidence: [],
                                                 languageRaw: "tr", itemIdentityRevision: 1, policyRevision: 1,
                                                 eventEpoch: 0, adapterVersion: "t"),
            childOutcome: nil, familyDegradedNonAdult: false)
        XCTAssertEqual(plainCaution.surfaceRaw, "CAUTION")
        XCTAssertEqual(plainCaution.reasonCodeRaw, GuardianReasonCodeV1.generalContentCaution.rawValue)
    }

    func testPressureRegisterNeverWeakensShieldMatch() {
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "SHIELD_MATCH", baseReasonRaw: GuardianReasonCodeV1.personalShieldWarnOnly.rawValue,
            character: softenedCharacter(), register: pressure(), childOutcome: nil, familyDegradedNonAdult: false)
        XCTAssertEqual(a.surfaceRaw, "SHIELD_MATCH")
    }

    func testChildFloorOutranksSoftening() {
        // THE §3 PIN: CHILD policy outcome outranks personal-preference softening.
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON",
            baseReasonRaw: GuardianReasonCodeV1.generalContentContextSoftened.rawValue,
            character: softenedCharacter(), register: nil,
            childOutcome: .caution, familyDegradedNonAdult: false)
        XCTAssertEqual(a.surfaceRaw, "CAUTION")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.childAgeCaution.rawValue)
    }

    func testChildUnknownReviewSurfacesDistinctly() {
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON", baseReasonRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
            character: nil, register: nil, childOutcome: .unknownReview, familyDegradedNonAdult: false)
        XCTAssertEqual(a.surfaceRaw, "UNKNOWN")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.childAgeUnknownReview.rawValue)
    }

    func testChildReviewNeverWeakensAStandingCaution() {
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "CAUTION", baseReasonRaw: GuardianReasonCodeV1.generalContentCaution.rawValue,
            character: nil, register: nil, childOutcome: .unknownReview, familyDegradedNonAdult: false)
        XCTAssertEqual(a.surfaceRaw, "CAUTION", "UNKNOWN_REVIEW must never weaken a standing warn")
    }

    func testChildRestrictedIsTheFloorEverywhere() {
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "SHIELD_MATCH", baseReasonRaw: GuardianReasonCodeV1.personalShieldWarnOnly.rawValue,
            character: nil, register: nil, childOutcome: .restricted, familyDegradedNonAdult: false)
        XCTAssertEqual(a.surfaceRaw, "CAUTION")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.childAgeRestricted.rawValue)
    }

    func testAlignedChildLeavesBaseUntouched() {
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON", baseReasonRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
            character: nil, register: nil, childOutcome: .aligned, familyDegradedNonAdult: false)
        XCTAssertEqual(a.surfaceRaw, "GUARDIAN_ON")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.textEvidenceBenign.rawValue)
    }

    func testDegradedFamilyReadFailsClosed() {
        // THE §2 PIN: App Group read failure with a known child/teen mode → honest UNKNOWN, never stale-as-fresh.
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON", baseReasonRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
            character: nil, register: nil, childOutcome: nil, familyDegradedNonAdult: true)
        XCTAssertEqual(a.surfaceRaw, "UNKNOWN")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.familyProfileUnavailable.rawValue)
    }

    func testAdultModeUnchangedBehavior() {
        // No child outcome, no degradation, no pressure register → base passes through verbatim.
        let a = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: "GUARDIAN_ON",
            baseReasonRaw: GuardianReasonCodeV1.generalContentContextSoftened.rawValue,
            character: softenedCharacter(),
            register: EmotionalRegisterVerdictV1(register: .unknown, support: .supported, evidence: [],
                                                 languageRaw: "tr", itemIdentityRevision: 1, policyRevision: 1,
                                                 eventEpoch: 0, adapterVersion: "t"),
            childOutcome: nil, familyDegradedNonAdult: false)
        XCTAssertEqual(a.surfaceRaw, "GUARDIAN_ON")
        XCTAssertEqual(a.reasonCodeRaw, GuardianReasonCodeV1.generalContentContextSoftened.rawValue)
    }
}
