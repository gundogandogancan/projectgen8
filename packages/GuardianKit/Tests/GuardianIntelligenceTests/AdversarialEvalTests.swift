import XCTest
import GuardianCore
@testable import GuardianIntelligence

// Adversarial eval V1 (PROMPT 003 §24). Records expected behavior on tricky inputs.
final class AdversarialEvalTests: XCTestCase {
    let mdd = MortalityDiseaseDisasterHead()

    func testNeutralMedicalEducationIsTopicNotHidden() {
        // Neutral medical education → DISEASE_ILLNESS topic present, but this is NOT a hide decision
        // (hiding is a policy decision downstream; the head only reports topic).
        let s = mdd.classify(text: "An educational explainer about how the immune system fights infection.", language: "en")
        XCTAssertTrue(s.value?.contains(.diseaseIllness) ?? false)
        XCTAssertEqual(s.availability, .available)
    }

    func testClickbaitTitleNeutralBodyIntent() async {
        let topic = await TopicMessageHead().analyze(text: "You won't believe this! Subscribe now and click here.", language: "en")
        XCTAssertEqual(topic.value?.intent, .advertisement)   // CTA cues → advertisement intent
    }

    func testTurkishDisasterNotMissed() {
        let s = mdd.classify(text: "Şiddetli sel ve ardından yangın felaketi yaşandı.", language: "tr")
        XCTAssertTrue(s.value?.contains(.disaster) ?? false)  // TR path not silently using EN thresholds
    }

    func testShieldAliasMatch() async {
        let shield = SemanticShieldV1()
        let rules = [SemanticShieldRule(kind: .concept, value: "RivalTeam|Rakip Takım", hard: true)]
        let s = await shield.evaluate(text: "Rakip Takım maçı özetleri.", rules: rules, language: "tr")
        XCTAssertEqual(s.value?.tier, ShieldDecision.Tier.high)   // alias (TR) matched
    }

    func testEmptyTextAbstains() {
        let s = mdd.classify(text: "  ", language: "en")
        XCTAssertEqual(s.availability, .unknown)
        XCTAssertEqual(s.abstentionReason, .insufficientEvidence)
    }
}
