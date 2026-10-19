import XCTest
import GuardianCore
@testable import GuardianIntelligence

final class SpecialistHeadsTests: XCTestCase {

    // H2 — Mortality/Disease/Disaster, TR + EN
    func testMDDEnglishDisaster() {
        let s = MortalityDiseaseDisasterHead().classify(text: "A massive earthquake struck the city.", language: "en")
        XCTAssertEqual(s.availability, .available)
        XCTAssertTrue(s.value?.contains(.disaster) ?? false)
        XCTAssertNil(s.calibratedConfidence)                 // calibration UNAVAILABLE (honest)
        XCTAssertEqual(s.language, "en")
    }
    func testMDDTurkishDisease() {
        let s = MortalityDiseaseDisasterHead().classify(text: "Doktorlar hastaya kanser teşhisi koydu.", language: "tr")
        XCTAssertTrue(s.value?.contains(.diseaseIllness) ?? false)   // TR not treated with EN thresholds
    }
    func testMDDNeutralIsNoneOfAbove() {
        let s = MortalityDiseaseDisasterHead().classify(text: "A tutorial about Swift concurrency.", language: "en")
        XCTAssertEqual(s.value, [.noneOfAbove])
    }
    func testMDDTopicPresenceIsNotTruthClaim() {
        // A medically accurate article still matches DISEASE_ILLNESS — topic ≠ falsehood.
        let s = MortalityDiseaseDisasterHead().classify(text: "Evidence-based overview of this chronic disease.", language: "en")
        XCTAssertTrue(s.value?.contains(.diseaseIllness) ?? false)
    }

    // H5 — Attention / Manipulation
    func testManipulationLexicalSignals() {
        let s = AttentionManipulationHead().analyze(text: "Hurry! Last chance, limited time — subscribe now!", language: "en")
        XCTAssertGreaterThan(s.value?.total ?? 0, 0)
        XCTAssertEqual(s.provenance, .lexiconV1)              // OBSERVED lexical, not hidden-intent
    }

    // H4 — Topic / Message
    func testTopicMessageIntent() async {
        let s = await TopicMessageHead().analyze(text: "Buy now! Click here to subscribe and get the deal.", language: "en")
        XCTAssertEqual(s.value?.intent, .advertisement)
    }

    // H1 — Sensitive Visual: honestly UNAVAILABLE
    func testSensitiveVisualUnavailable() {
        let s = SensitiveVisualHead().classify()
        XCTAssertEqual(s.availability, .unavailable)
        XCTAssertEqual(s.abstentionReason, .notImplemented)
    }

    // H3 — Semantic Shield V1
    func testShieldExactHighExclude() async {
        let shield = SemanticShieldV1()
        let rules = [SemanticShieldRule(kind: .entity, value: "RivalTeam", hard: true)]
        let s = await shield.evaluate(text: "Highlights from RivalTeam last night.", rules: rules, language: "en")
        XCTAssertEqual(s.value?.tier, .high)
        XCTAssertEqual(s.value?.action, .exclude)
        XCTAssertEqual(s.provenance, .embeddingClassifierV1)
    }
    func testShieldNoMatchDoesNotHide() async {
        let shield = SemanticShieldV1()
        let rules = [SemanticShieldRule(kind: .entity, value: "RivalTeam", hard: true)]
        let s = await shield.evaluate(text: "A calm documentary about rivers.", rules: rules, language: "en")
        XCTAssertEqual(s.value?.tier, ShieldDecision.Tier.none)     // unrelated → no hide
        XCTAssertEqual(s.value?.action, ShieldDecision.Action.none)
    }
    func testShieldPersonalCorrectionLocal() async {
        let shield = SemanticShieldV1()
        await shield.correctNotThisConcept("RivalTeam")
        let rules = [SemanticShieldRule(kind: .entity, value: "RivalTeam", hard: true)]
        let s = await shield.evaluate(text: "RivalTeam match report.", rules: rules, language: "en")
        XCTAssertEqual(s.value?.tier, ShieldDecision.Tier.none)    // local forced-allow correction applied
    }
}
