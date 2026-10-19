import XCTest
@testable import GuardianCore

final class P006RuntimeTests: XCTestCase {

    // §3 activation state single source of truth + OFF cancels
    func testActivationStateAndCancelOnOff() {
        let store = InMemoryActivationStore(.enabled)
        let ctl = GuardianActivationController(store: store)
        var cancelled = 0
        ctl.onDeactivate { cancelled += 1 }
        XCTAssertTrue(ctl.runtimeActive)
        ctl.set(.disabled)
        XCTAssertFalse(ctl.runtimeActive)
        XCTAssertEqual(cancelled, 1)                       // OFF cancels new work
        XCTAssertFalse(ctl.state.canClaimProtection)       // never claim Protected when off
        // relaunch-safe: a new controller over same store sees disabled
        XCTAssertEqual(GuardianActivationController(store: store).state, .disabled)
    }

    // §7 text first-class: structured preferred over OCR, dedupe, conflict
    func testTextSourceMergePriorityDedupeConflict() {
        let merge = TextSourceMerge()
        let r = merge.merge([
            TextSource(origin: .ocr, text: "Hello World", timestampSeconds: 1),
            TextSource(origin: .structured, text: "hello world", timestampSeconds: 1),   // dup (normalized) — structured wins
            TextSource(origin: .captions, text: "Different caption", timestampSeconds: 1)
        ])
        XCTAssertEqual(r.merged.first?.origin, .structured)    // structured preferred over OCR
        XCTAssertGreaterThanOrEqual(r.avoidedDuplicateAnalysis, 1)
        XCTAssertFalse(r.conflicts.isEmpty)                    // two distinct texts at t=1
    }

    // §16 complexity classes
    func testComplexityClassification() {
        XCTAssertEqual(ContentComplexityProfile.classify(durationSeconds: 5, modalities: 2, uncertainty: 0.3, policySensitivity: 0.2).lengthClass, .micro)
        XCTAssertEqual(ContentComplexityProfile.classify(durationSeconds: 1800, modalities: 3, uncertainty: 0.3, policySensitivity: 0.2).lengthClass, .long)
        XCTAssertEqual(ContentComplexityProfile.classify(durationSeconds: 0, modalities: 1, uncertainty: 0, policySensitivity: 0, live: true).lengthClass, .liveOpenEnded)
    }

    // §17 orchestrator: cached runs nothing; not-all-heads
    func testOrchestratorNotAllHeadsAndCacheRunsNothing() {
        let comp = ContentComplexityProfile.classify(durationSeconds: 30, modalities: 3, uncertainty: 0.2, policySensitivity: 0.2)
        let budget = ComputeBudgetPlanner().plan(comp, cached: false, mode: .balanced, thermal: .nominal, lowPower: false, exposureDeadlineMs: 1000)
        let orch = IntelligenceOrchestrator()
        let plan = orch.plan(complexity: comp, budget: budget, cached: false, hasText: true, hasAudio: false, hasVideo: true, policySensitive: false)
        XCTAssertFalse(plan.fast.isEmpty)
        XCTAssertFalse(plan.skipped.isEmpty)                   // NOT all heads run
        XCTAssertFalse(plan.fast.contains(.speech))            // no audio → no speech head
        let cachedPlan = orch.plan(complexity: comp, budget: budget, cached: true, hasText: true, hasAudio: true, hasVideo: true, policySensitive: true)
        XCTAssertTrue(cachedPlan.fast.isEmpty && cachedPlan.deep.isEmpty)   // reuse → run nothing
    }

    // §18 budget: thermal/low-power forces ECO + cloud off
    func testBudgetThermalDegradeAndCloudOff() {
        let p = ComputeBudgetPlanner()
        let c = ContentComplexityProfile.classify(durationSeconds: 300, modalities: 3, uncertainty: 0.5, policySensitivity: 0.5)
        let hot = p.plan(c, cached: false, mode: .maxProtection, thermal: .critical, lowPower: false, exposureDeadlineMs: nil)
        XCTAssertEqual(hot.mode, .eco)
        XCTAssertFalse(hot.cloudAllowed)                       // cloud OFF by default this phase
    }

    // §19 sub-second admission: cache short-circuit + fast real timing + deep non-blocking
    func testSubSecondAdmission() {
        let clock = SystemMonotonicClock()
        let fusionIn = FusionInputsV1(contentID: .init("x"), benefit: { var b = PersonalBenefitVector(); b.learning = 1; b.skill = 1; b.practicalUsefulness = 1; b.criticalThinking = 0.9; b.hopeMeaning = 0.8; b.entertainment = 0.6; b.creativity = 0.8; return b }(),
                                       profile: GuardianLabFixtures.defaultProfile, availableHeadCount: 3)
        let s = SubSecondAdmission(clock: clock)
        let fresh = s.admit(inputs: fusionIn, cacheHit: false, cachedDecision: nil)
        XCTAssertEqual(fresh.route, "FAST")
        XCTAssertNotEqual(fresh.admission, .unknown)
        let cachedDecision = FusionResultV1(contentID: .init("x"), admission: .approve, scoreState: .verifiedFast, score: 8.0, reasons: [.thresholdMet], confidence: .high, explanation: "cached")
        let cached = s.admit(inputs: fusionIn, cacheHit: true, cachedDecision: cachedDecision)
        XCTAssertEqual(cached.route, "CACHE")
    }

    // §20/§21 next-content queue bounded + drop low-prob under pressure + dedupe
    func testNextContentQueue() {
        let q = NextContentQueue(maxLookAhead: 3)
        let cands = (0..<6).map { NextContentCandidate(id: .init("n\($0)"), revealProbability: $0 == 0 ? 0.05 : 0.8,
                                   timeToRevealMs: 100 + $0*50, resourceCost: 1, riskUncertainty: 0.5) }
        let r = q.select(cands, pressure: true)
        XCTAssertLessThanOrEqual(r.kept.count, 3)
        XCTAssertFalse(r.kept.contains { $0.revealProbability < 0.2 })   // low-prob dropped under pressure
    }

    // §23 disagreement council: visual dominates; missing → unknown; conflict lowers confidence
    func testDisagreementCouncil() {
        let c = MultimodalDisagreementCouncil()
        let dom = c.resolve(visualGraphic: [.gore], textCategories: [], textIsNeutralEducation: false, visualAvailable: true, textAvailable: true)
        XCTAssertTrue(dom.categories.contains(.gore))
        let missing = c.resolve(visualGraphic: [], textCategories: [], textIsNeutralEducation: false, visualAvailable: false, textAvailable: false)
        XCTAssertLessThanOrEqual(missing.confidence, 0.1)
        let conflict = c.resolve(visualGraphic: [], textCategories: [.disease], textIsNeutralEducation: false, visualAvailable: true, textAvailable: true)
        XCTAssertTrue(conflict.conflict)
    }

    // §12 language registry: uncertified language does NOT inherit certified threshold
    func testLanguageRegistryNoInheritance() {
        let reg = LanguageCapabilityRegistry()
        XCTAssertTrue(reg.isAtLeast("en", .labSupported))
        XCTAssertEqual(reg.capability("zz").certification, .unassessed)   // unknown locale → unassessed
        XCTAssertFalse(reg.isAtLeast("zz", .labSupported))
    }
}
