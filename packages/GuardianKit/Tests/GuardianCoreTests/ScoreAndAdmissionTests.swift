import XCTest
@testable import GuardianCore

final class ScoreAndAdmissionTests: XCTestCase {
    let engine = ScoreEngine()
    let controller = AdmissionController()

    // MARK: Score states (PROMPT 001 §7)

    func testScoreBeneficialDeterministicVerifiedFast() {
        let r = engine.score(GuardianLabFixtures.beneficial().fixture)
        XCTAssertEqual(r.state, .verifiedFast)
        XCTAssertNotNil(r.value)
        XCTAssertEqual(r.display, "7.9")          // explicit deterministic formula
        XCTAssertEqual(r.provenance, .heuristicV0)
    }

    func testScoreInsufficientEvidenceShowsQuestionMark() {
        let r = engine.score(GuardianLabFixtures.unknown().fixture)
        XCTAssertEqual(r.state, .insufficientEvidence)
        XCTAssertNil(r.value)
        XCTAssertEqual(r.display, "?")
    }

    func testScoreConflictingHasNoNumber() {
        let r = engine.score(GuardianLabFixtures.conflicting().fixture)
        XCTAssertEqual(r.state, .conflicting)
        XCTAssertNil(r.value)
    }

    func testScoreReproducible() {
        let a = engine.score(GuardianLabFixtures.beneficial().fixture)
        let b = engine.score(GuardianLabFixtures.beneficial().fixture)
        XCTAssertEqual(a, b)                        // same inputs + version ⇒ same score
    }

    // MARK: Admission precedence (ADR-0007)

    private func decide(_ cand: ContentCandidate, _ profile: PersonalAlgorithmProfile,
                        _ safety: SafetyPolicy = .init()) -> AdmissionDecision {
        let id = cand.id
        let signals = cand.fixture
        let score = engine.score(signals)
        let inputs = AdmissionInputs(contentID: id, identity: GuardianLabFixtures.identity(for: id),
                                     signals: signals, score: score, profile: profile, safety: safety)
        return controller.decide(inputs)
    }

    func testThresholdApprove() {
        let d = decide(GuardianLabFixtures.beneficial(), GuardianLabFixtures.defaultProfile)
        XCTAssertEqual(d.state, .approve)
        XCTAssertEqual(d.reason, .personalAlgorithmThreshold)
    }

    func testBelowThresholdNotRecommended() {
        let d = decide(GuardianLabFixtures.lowValue(), GuardianLabFixtures.defaultProfile)
        XCTAssertEqual(d.state, .notRecommended)
        XCTAssertEqual(d.reason, .personalAlgorithmThreshold)
    }

    func testHardShieldOutranksThreshold() {
        // High score (would APPROVE) but matches a hard entity shield → hidden on controlled surface.
        let d = decide(GuardianLabFixtures.shieldedEntity(), GuardianLabFixtures.profileWithHardEntityShield())
        XCTAssertEqual(d.state, .hideIfControlled)
        XCTAssertEqual(d.reason, .userHardSemanticShield)
        XCTAssertNotNil(d.score.value)              // score still computed; shield just outranks it
    }

    func testLowConfidenceConceptShieldDoesNotSilentlyHardHide() {
        var p = GuardianLabFixtures.defaultProfile
        p.shieldRules = [SemanticShieldRule(kind: .concept, value: "swift", hard: true)]
        let d = decide(GuardianLabFixtures.beneficial(), p)   // topic "swift" = medium-confidence concept
        XCTAssertEqual(d.state, .approveWithCaution)          // surfaced as caution, NOT hidden
        XCTAssertNotEqual(d.state, .hideIfControlled)
    }

    func testPositiveExposureRejectsFactualItem_TruthSeparate() {
        // Score 7.9 would APPROVE, but Positive Exposure (avoid disease) rejects — truth unchanged.
        let d = decide(GuardianLabFixtures.diseaseFactual(), GuardianLabFixtures.profileAvoidingDisease())
        XCTAssertEqual(d.state, .notRecommended)
        XCTAssertEqual(d.reason, .personalProtectionPolicy)
        XCTAssertTrue(d.explanation.contains("Truth/Evidence"))   // separation is visible
        XCTAssertNotNil(d.score.value)                            // factual score still present
    }

    func testChildSafetyFloorOutranksEverythingBelow() {
        // gore + hard entity shield + high score + child mode → CHILD_SAFETY_FLOOR wins.
        let signals = FixtureSignals(entities: ["RivalTeam"], sensitiveCategories: [.gore],
                                     goalFit: 0.95, informationDensity: 0.9, manipulationRisk: 0.05)
        let cand = ContentCandidate(id: .init("sf-combined"), source: .currentlyViewing,
                                    nextExposureLikelihood: 1, decisionDeadlineNanos: nil, fixture: signals)
        var p = GuardianLabFixtures.profileWithHardEntityShield()
        p.positiveExposure = PositiveExposurePolicy(avoid: [.gore])
        let d = decide(cand, p, GuardianLabFixtures.childSafety())
        XCTAssertEqual(d.reason, .childSafetyFloor)
        XCTAssertEqual(d.state, .hideIfControlled)
    }

    func testInsufficientEvidenceIsUnknownNotSafe() {
        let d = decide(GuardianLabFixtures.unknown(), GuardianLabFixtures.defaultProfile)
        XCTAssertEqual(d.state, .unknown)
        XCTAssertEqual(d.reason, .insufficientEvidence)
        let surface = GuardianSurfaceState.from(d, coverage: .unknown)
        XCTAssertEqual(surface.tone, .unknown)
        XCTAssertEqual(surface.scoreDisplay, "?")   // never a stale safe/green state
    }
}
