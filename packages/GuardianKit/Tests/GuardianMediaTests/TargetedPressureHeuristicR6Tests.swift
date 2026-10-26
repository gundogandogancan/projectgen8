//
//  TargetedPressureHeuristicR6Tests.swift — R6 §4 + ADDENDUM §5/§6: the targeted-pressure / covert-manipulation
//  heuristic LAWS. These pin the HARD honesty rules: criticism of a team/institution is never a personal attack;
//  quoted insults are the quoted party's; supportive 2nd-person never alarms; humor/irony → UNKNOWN; and the first
//  real separations (directed demeaning/threat, guilt-shame coercion, provocation incitement, deceptive urgency).
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class TargetedPressureHeuristicR6Tests: XCTestCase {

    private func assess(_ text: String, _ lang: String) -> TargetedPressureVerdictV1 {
        TargetedPressureHeuristicV1.assess(text: text, language: lang, itemIdentityRevision: 1,
                                           policyRevision: 1, nowEpoch: 1000)
    }

    // MARK: HONESTY LAWS (counter-examples)

    func testSportCriticismIsNotTargetedPersonalAttack_TR() {
        let v = assess("Takımın savunması bu sezon çok kötü, hoca rotasyonu yine yanlış kurdu.", "tr")
        XCTAssertNotEqual(v.act, .demeaningInsult, "criticism of a team is not a personal insult")
        XCTAssertFalse(v.isSupportedPressure, "team criticism must not warrant a targeted-pressure caution")
        XCTAssertNil(TargetedPressureHeuristicV1.evidenceLabel(v))
    }

    func testInstitutionCriticismIsNotDemeaning_EN() {
        let v = assess("The government failed to act and the policy is wrong and weak.", "en")
        XCTAssertNotEqual(v.act, .demeaningInsult)
        XCTAssertFalse(v.isSupportedPressure)
    }

    func testTargetedPersonalInsultDirected_TR() {
        let v = assess("Sen tam bir beceriksizsin, bu takımda işin yok, defol git.", "tr")
        XCTAssertEqual(v.target, .directedSecondPerson)
        XCTAssertEqual(v.act, .demeaningInsult)
        XCTAssertTrue(v.isSupportedPressure, "a directed personal demeaning insult is a supported pressure signal")
        XCTAssertEqual(TargetedPressureHeuristicV1.evidenceLabel(v), "attention:targeted-demeaning-directed")
    }

    func testTargetedPersonalInsultDirected_EN() {
        let v = assess("You are a complete failure and everyone here wants you gone.", "en")
        XCTAssertEqual(v.target, .directedSecondPerson)
        XCTAssertEqual(v.act, .demeaningInsult)
        XCTAssertTrue(v.isSupportedPressure)
    }

    func testQuotedInsultIsNotSpeakerOwnVoice_TR() {
        let v = assess("Tanık, adamın \"sen tam bir beceriksizsin\" dediğini söyledi.", "tr")
        XCTAssertTrue(v.quotedNotOwnVoice, "a quoted insult is the quoted party's, not the speaker's")
        XCTAssertFalse(v.isSupportedPressure)
        XCTAssertNil(TargetedPressureHeuristicV1.evidenceLabel(v))
    }

    func testSupportiveSecondPersonNeverAlarms_TR() {
        let v = assess("Zor günlerden geçiyorsun ama yalnız değilsin, güçlüsün ve yanındayız.", "tr")
        XCTAssertEqual(v.act, .none)
        XCTAssertEqual(v.mechanism, .none)
        XCTAssertFalse(v.isSupportedPressure, "supportive 2nd-person speech must never alarm")
    }

    func testSupportiveSecondPersonNeverAlarms_EN() {
        let v = assess("You are not alone in this, you are strong and we are with you.", "en")
        XCTAssertFalse(v.isSupportedPressure)
    }

    func testIronyAbstains_TR() {
        let v = assess("Harika, yine \"korkunç tehlike\" başlıklarıyla uyanmış bulunuyoruz, ne sürpriz.", "tr")
        XCTAssertEqual(v.act, .unknown)
        XCTAssertFalse(v.isSupportedPressure, "irony/humor ambiguity must abstain")
    }

    func testRighteousAngerWithoutIncitementIsNotProvocation_TR() {
        // Anger at an injustice WITHOUT a call-to-act structure must NOT be provocation (addendum §3).
        let v = assess("Bu haksızlık gerçekten rezalet, çok öfkeliyim.", "tr")
        XCTAssertNotEqual(v.mechanism, .provocationIncitement)
        XCTAssertFalse(v.isSupportedPressure)
    }

    // MARK: COVERT MECHANISMS (the addendum's success criterion — no overtly negative lexicon required)

    func testGuiltShameCoercion_TR() {
        let v = assess("Senin yüzünden her şey mahvoldu, utanmalısın; hemen ara ve özür dile.", "tr")
        XCTAssertEqual(v.mechanism, .guiltShameCoercion)
        XCTAssertTrue(v.isSupportedPressure)
        XCTAssertEqual(TargetedPressureHeuristicV1.evidenceLabel(v), "attention:covert-guilt-shame-coercion")
    }

    func testGuiltShameCoercion_EN() {
        let v = assess("It's your fault and you should be ashamed, now call them and apologize.", "en")
        XCTAssertEqual(v.mechanism, .guiltShameCoercion)
        XCTAssertTrue(v.isSupportedPressure)
    }

    func testProvocationIncitement_TR() {
        let v = assess("Bu rezalet! Hak ediyorlar, saldırın onlara, haddini bildirin.", "tr")
        XCTAssertEqual(v.mechanism, .provocationIncitement)
        XCTAssertTrue(v.isSupportedPressure)
    }

    func testDeceptiveUrgency_TR() {
        let v = assess("Son şans! Stoklar tükeniyor, hemen satın al, kaçırma!", "tr")
        XCTAssertEqual(v.mechanism, .deceptiveUrgency)
        XCTAssertTrue(v.isSupportedPressure)
    }

    func testSocialComparisonPressure_EN() {
        let v = assess("Everyone is doing it already, don't be left behind, sign up now.", "en")
        XCTAssertEqual(v.mechanism, .socialComparisonPressure)
        XCTAssertTrue(v.isSupportedPressure)
    }

    func testConditionalThreatWithoutSensitiveWords_EN() {
        // The addendum's success criterion: a pressure mechanism detected with no overtly negative lexicon.
        let v = assess("You should be ashamed, now send the message or everyone will know it was your fault.", "en")
        XCTAssertTrue(v.isSupportedPressure, "guilt/shame coercion must be detected without an explicit swear/threat word")
    }

    // MARK: honest abstention on unsupported input

    func testUnsupportedLanguageNotApplicable() {
        let v = assess("Das ist eine Nachricht auf Deutsch.", "de")
        XCTAssertEqual(v.support, .notApplicable)
        XCTAssertFalse(v.isSupportedPressure)
    }

    func testInsufficientTextNotApplicable() {
        let v = assess("ok", "en")
        XCTAssertEqual(v.support, .notApplicable)
    }

    func testCorruptedOCRDoesNotFabricatePressure() {
        let v = assess("S3n t4m b1r b3c3r1ks1zs1n d3f0l", "tr")
        // Leet/garbled text should not confidently produce a directed demeaning insult.
        XCTAssertFalse(v.isSupportedPressure, "corrupted OCR must not fabricate a confident targeted attack")
    }
}
