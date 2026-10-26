//
//  ContextEvidenceAdapterR4Tests.swift — R4 §3/§4: unit tests for the FIRST REAL CONTEXTUAL SEPARATION.
//
//  These lock the STANCE inference contract: negation scope, quotation / reported speech, subject-action-object role
//  (advocacy vs reporting), explicit anti-stance, victim support, and the UNKNOWN-by-design honesty laws. They run
//  the REAL ContextEvidenceAdapterV1 (which uses Apple NaturalLanguage POS on-device) over SYNTHETIC, rights-clean
//  strings. DEVICE_UNVERIFIED for the full extension wiring (the app build covers that); these pin the pure logic.
//
import XCTest
@testable import GuardianMedia

final class ContextEvidenceAdapterR4Tests: XCTestCase {

    private func stance(_ text: String, _ lang: String) -> ContextEvidenceVerdictV1 {
        ContextEvidenceAdapterV1.assessStance(text: text, language: lang,
                                              itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 1)
    }

    // MARK: - Supported-language gate (§3)

    func testUnsupportedLanguage_isNotApplicable_keepsPlain() {
        let v = stance("これは暴力です 死", "ja")
        XCTAssertEqual(v.support, .notApplicable)
        XCTAssertEqual(v.stance, .unknown)
        XCTAssertEqual(v.effect, .keepPlain)        // never softens a marker in an unsupported language
        XCTAssertTrue(v.evidence.isEmpty)
    }

    func testEmptyOrTinyText_isNotApplicable() {
        XCTAssertEqual(stance("", "tr").support, .notApplicable)
        XCTAssertEqual(stance("a", "en").support, .notApplicable)
    }

    func testLanguagePrefixMatching_enUS_supported() {
        XCTAssertTrue(ContextEvidenceAdapterV1.isSupported(language: "en-US"))
        XCTAssertTrue(ContextEvidenceAdapterV1.isSupported(language: "tr_TR"))
        XCTAssertFalse(ContextEvidenceAdapterV1.isSupported(language: "de"))
        XCTAssertFalse(ContextEvidenceAdapterV1.isSupported(language: nil))
    }

    // MARK: - Negation scope (§1 — clause-scoped, not bag-of-words) — CRITICIZES

    func testTurkishAntiViolence_negationClause_isCriticizes_soften() {
        // "şiddete karşıyız" — against violence. Contains the violence word but the STANCE is opposition.
        let v = stance("Biz her türlü şiddete karşıyız, bu kabul edilemez.", "tr")
        XCTAssertEqual(v.support, .supported)
        XCTAssertEqual(v.stance, .criticizes)
        XCTAssertEqual(v.effect, .softenToNote)
        XCTAssertTrue(v.evidence.contains { $0.hasPrefix("antistance:") })
    }

    func testEnglishNegationOverHarm_isCriticizes() {
        let v = stance("This is not acceptable. We say no to violence and hate.", "en")
        XCTAssertEqual(v.stance, .criticizes)
        XCTAssertEqual(v.effect, .softenToNote)
    }

    func testTurkishExplicitNegation_degil_isCriticizes() {
        let v = stance("Çözüm şiddet değil, sevgi ve diyalogdur.", "tr")
        XCTAssertEqual(v.stance, .criticizes)
        XCTAssertTrue(v.evidence.contains { $0.hasPrefix("negation:") })
    }

    // MARK: - Quotation / reported speech (§3 — a quote is NOT the speaker's stance)

    func testQuotedAdvocacy_withReportingFrame_isReports_notAdvocates() {
        // The subject quotes someone ELSE advocating violence; the SPEAKER is reporting → REPORTS, never ADVOCATES.
        let v = stance("Saldırgan \"onları öldürün\" dedi; polis olayı araştırıyor.", "tr")
        XCTAssertEqual(v.stance, .reports)
        XCTAssertNotEqual(v.stance, .advocates)     // the §3 hard law
        XCTAssertEqual(v.effect, .softenToNote)
    }

    func testEnglishReportingFrame_isReports() {
        let v = stance("Police said three people were killed in the attack.", "en")
        XCTAssertEqual(v.stance, .reports)
        XCTAssertEqual(v.effect, .softenToNote)
    }

    // MARK: - Role: first-person advocacy (§4 — keep/raise, never soften)

    func testTurkishFirstPersonAdvocacy_isAdvocates_keepOrRaise() {
        let v = stance("Hepsini gebertin, hak ettiler! Yaşasın savaş!", "tr")
        XCTAssertEqual(v.stance, .advocates)
        XCTAssertEqual(v.effect, .keepOrRaise)      // a real advocacy signal is kept/raised, NEVER softened
        XCTAssertTrue(v.evidence.contains { $0.hasPrefix("role:advocacy") })
    }

    func testEnglishFirstPersonAdvocacy_isAdvocates() {
        let v = stance("Let's attack them, they deserve it. Kill them all.", "en")
        XCTAssertEqual(v.stance, .advocates)
        XCTAssertEqual(v.effect, .keepOrRaise)
    }

    // MARK: - Reporting role (§4 — may soften)

    func testTurkishReportingEvent_isReports() {
        let v = stance("Dün gece bir patlama yaşandı; olayda iki kişi yaralandı, soruşturma başlatıldı.", "tr")
        XCTAssertEqual(v.stance, .reports)
        XCTAssertEqual(v.effect, .softenToNote)
    }

    // MARK: - Victim support (§4)

    func testVictimSupport_isSupportsVictims() {
        let v = stance("Depremde hayatını kaybedenlerin ailelerinin yanındayız; başınız sağolsun.", "tr")
        XCTAssertEqual(v.stance, .supportsVictims)
        XCTAssertEqual(v.effect, .softenToNote)
    }

    // MARK: - UNKNOWN by design (§1/§4 — never fabricate a stance we cannot read)

    func testMixedAdvocacyAndOpposition_isUnknown_keepPlain() {
        // Both an advocacy call AND an opposition marker → cannot tell → UNKNOWN, keep the plain marker.
        let v = stance("Bazıları \"saldırın\" diyor ama biz şiddete karşıyız; yine de vuralım diyenler var.", "tr")
        XCTAssertEqual(v.stance, .unknown)
        XCTAssertEqual(v.effect, .keepPlain)        // UNKNOWN never softens a real risk
    }

    func testBareTopicMention_noDecisiveStructure_isUnknown_keepPlain() {
        // A bare topic mention with no stance structure → UNKNOWN (supported, but we looked and could not tell).
        let v = stance("Savaş. Ölüm. Felaket.", "tr")
        XCTAssertEqual(v.support, .supported)
        XCTAssertEqual(v.stance, .unknown)
        XCTAssertEqual(v.effect, .keepPlain)
    }

    func testSarcasm_isUnknown_byDesign_keepPlain() {
        // Sarcasm/irony is NOT structurally detectable → UNKNOWN by design (we never guess intent we cannot read).
        // "Harika, yine şiddet, ne güzel" reads positive on the surface but is ironic — structure cannot disambiguate.
        let v = stance("Harika, yine şiddet, ne güzel bir dünya.", "tr")
        XCTAssertEqual(v.stance, .unknown)
        XCTAssertEqual(v.effect, .keepPlain)
    }

    // MARK: - Purity + provenance

    func testDeterministic_sameInputSameVerdict() {
        let a = stance("Police said two were killed.", "en")
        let b = stance("Police said two were killed.", "en")
        XCTAssertEqual(a, b)
    }

    func testVerdict_carriesProvenance_noRawText_noScore() {
        let v = ContextEvidenceAdapterV1.assessStance(text: "Biz şiddete karşıyız.", language: "tr",
                                                      itemIdentityRevision: 9, policyRevision: 42, nowEpoch: 123.5)
        XCTAssertEqual(v.itemIdentityRevision, 9)
        XCTAssertEqual(v.policyRevision, 42)
        XCTAssertEqual(v.eventEpoch, 123.5)
        XCTAssertFalse(v.adapterVersion.isEmpty)
        let json = String(data: try! JSONEncoder().encode(v), encoding: .utf8)!
        XCTAssertFalse(json.contains("score"))
        // Evidence cues are structural (e.g. "antistance:karsi"), never the raw OCR sentence verbatim.
        XCTAssertFalse(json.contains("Biz şiddete karşıyız."), "the raw OCR sentence must never leak into the verdict")
    }
}
