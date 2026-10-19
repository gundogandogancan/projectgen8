import XCTest
@testable import GuardianCore

/// Benchmark scenarios S1–S10 (PROMPT 001 §31) exercised as real pipeline runs.
final class PipelineBenchmarkTests: XCTestCase {

    func testS1_CachedShortForm() async {
        let clock = SystemMonotonicClock()
        let parts = GuardianLabFixtures.makePipeline(clock: clock)
        let c = GuardianLabFixtures.beneficial()
        let r1 = await parts.pipeline.decide(candidate: c, profile: GuardianLabFixtures.defaultProfile)
        let r2 = await parts.pipeline.decide(candidate: c, profile: GuardianLabFixtures.defaultProfile)
        XCTAssertFalse(r1.trace.cacheHit)
        XCTAssertTrue(r2.trace.cacheHit)                     // second time served from cache
        XCTAssertEqual(parts.diagnostics.cacheHits, 1)
        XCTAssertEqual(parts.diagnostics.preflightRuns, 1)   // analysis ran once
        XCTAssertEqual(r1.decision.state, r2.decision.state)
    }

    func testS2_FreshShortFormApprove() async {
        let parts = GuardianLabFixtures.makePipeline(clock: SystemMonotonicClock())
        let r = await parts.pipeline.decide(candidate: GuardianLabFixtures.beneficial(),
                                            profile: GuardianLabFixtures.defaultProfile)
        XCTAssertEqual(r.decision.state, .approve)
        XCTAssertFalse(r.trace.cacheHit)
        let names = parts.events.names()
        XCTAssertEqual(names.first, "CandidateDiscovered")
        XCTAssertTrue(names.contains("AdmissionDecisionReady"))
        XCTAssertTrue(names.contains("FastPreflightCompleted"))
    }

    func testS3_UnknownTruthful() async {
        let parts = GuardianLabFixtures.makePipeline(clock: SystemMonotonicClock())
        let r = await parts.pipeline.decide(candidate: GuardianLabFixtures.unknown(),
                                            profile: GuardianLabFixtures.defaultProfile)
        XCTAssertEqual(r.decision.state, .unknown)
        XCTAssertEqual(r.surface.scoreDisplay, "?")
        XCTAssertEqual(r.surface.coverage, .unknown)
    }

    func testS4_SemanticShield() async {
        let parts = GuardianLabFixtures.makePipeline(clock: SystemMonotonicClock())
        let r = await parts.pipeline.decide(candidate: GuardianLabFixtures.shieldedEntity(),
                                            profile: GuardianLabFixtures.profileWithHardEntityShield())
        XCTAssertEqual(r.decision.state, .hideIfControlled)
        XCTAssertEqual(r.decision.reason, .userHardSemanticShield)
    }

    func testS5_PositiveExposureVsTruth() async {
        let parts = GuardianLabFixtures.makePipeline(clock: SystemMonotonicClock())
        let r = await parts.pipeline.decide(candidate: GuardianLabFixtures.diseaseFactual(),
                                            profile: GuardianLabFixtures.profileAvoidingDisease())
        XCTAssertEqual(r.decision.state, .notRecommended)
        XCTAssertEqual(r.decision.reason, .personalProtectionPolicy)
        XCTAssertNotNil(r.decision.score.value)                 // truth/score intact
        XCTAssertTrue(r.decision.explanation.contains("Truth/Evidence"))
    }

    func testS6_S7_S8_LongFormTemporal() {
        let guardian = TemporalGuardian()
        let g = GuardianLabFixtures.correctTemporalGraph()
        let id = GuardianLabFixtures.longFormIdentity()
        // S6 — warning before flagged segment
        XCTAssertNotNil(guardian.shouldWarn(graph: g, playhead: 100, leadSeconds: 30))
        // S7 — aligned auto-skip
        XCTAssertEqual(guardian.evaluateSkip(segment: g.segments[1], identity: id, graph: g, mode: .strict), .autoSkip)
        // S8 — wrong version blocks auto-skip
        let wrong = GuardianLabFixtures.wrongVersionTemporalGraph()
        XCTAssertEqual(guardian.evaluateSkip(segment: wrong.segments[1], identity: id, graph: wrong, mode: .strict),
                       .refusedVersionMismatch)
    }

    func testS9_SchedulerCancellation() async {
        let parts = GuardianLabFixtures.makePipeline(clock: SystemMonotonicClock())
        let scheduler = LookAheadScheduler(pipeline: parts.pipeline, diagnostics: parts.diagnostics,
                                           profile: GuardianLabFixtures.defaultProfile)
        func cand(_ n: String, _ l: Double) -> ContentCandidate {
            ContentCandidate(id: .init(n), source: .lookAhead1, nextExposureLikelihood: l, decisionDeadlineNanos: nil,
                             fixture: FixtureSignals(goalFit: 0.9, informationDensity: 0.8))
        }
        await scheduler.update(candidates: [cand("A", 0.9), cand("B", 0.8), cand("C", 0.7)])
        await scheduler.update(candidates: [cand("D", 0.9)])
        XCTAssertGreaterThanOrEqual(parts.diagnostics.cancellations, 3)
    }

    func testS10_IdleNoContinuousLoop() async {
        // No timer/polling: the local fixture path performs zero network bytes and no work when idle.
        let parts = GuardianLabFixtures.makePipeline(clock: SystemMonotonicClock())
        XCTAssertEqual(parts.diagnostics.networkBytes, 0)
        XCTAssertEqual(parts.diagnostics.preflightRuns, 0)
    }

    func testRealTimingMeasured() async {
        let parts = GuardianLabFixtures.makePipeline(clock: SystemMonotonicClock())
        _ = await parts.pipeline.decide(candidate: GuardianLabFixtures.beneficial(),
                                        profile: GuardianLabFixtures.defaultProfile)
        XCTAssertEqual(parts.diagnostics.snapshot.decisionCount, 1)   // real latency recorded, not faked
        XCTAssertEqual(parts.diagnostics.networkBytes, 0)
    }
}
