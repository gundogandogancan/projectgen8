import XCTest
@testable import GuardianCore

final class SchedulerTests: XCTestCase {

    private func makeScheduler(_ clock: MonotonicClock)
    -> (LookAheadScheduler, Diagnostics) {
        let parts = GuardianLabFixtures.makePipeline(clock: clock)
        let scheduler = LookAheadScheduler(pipeline: parts.pipeline, diagnostics: parts.diagnostics,
                                           profile: GuardianLabFixtures.defaultProfile)
        return (scheduler, parts.diagnostics)
    }

    func testBoundedToThreeLookAhead() async {
        let (scheduler, diag) = makeScheduler(ManualClock())
        let candidates = (0..<5).map {
            ContentCandidate(id: .init("sf-\($0)"), source: .lookAhead1,
                             nextExposureLikelihood: Double(5 - $0), decisionDeadlineNanos: nil,
                             fixture: FixtureSignals(goalFit: 0.9, informationDensity: 0.8, manipulationRisk: 0.1))
        }
        await scheduler.update(candidates: candidates)
        let pending = await scheduler.pendingCount()
        XCTAssertEqual(pending, 3)                       // only NEXT+1/+2/+3
        XCTAssertLessThanOrEqual(diag.peakConcurrentTasks, 3)
    }

    func testDedupeSameContentID() async {
        let (scheduler, _) = makeScheduler(ManualClock())
        let dup = ContentCandidate(id: .init("sf-x"), source: .lookAhead1, nextExposureLikelihood: 0.9,
                                   decisionDeadlineNanos: nil,
                                   fixture: FixtureSignals(goalFit: 0.9, informationDensity: 0.8))
        await scheduler.update(candidates: [dup, dup, dup])
        let pending = await scheduler.pendingCount()
        XCTAssertEqual(pending, 1)
    }

    func testStaleCandidatesCancelledOnAdvance() async {
        let (scheduler, diag) = makeScheduler(ManualClock())
        func cand(_ n: String, _ l: Double) -> ContentCandidate {
            ContentCandidate(id: .init(n), source: .lookAhead1, nextExposureLikelihood: l, decisionDeadlineNanos: nil,
                             fixture: FixtureSignals(goalFit: 0.9, informationDensity: 0.8))
        }
        await scheduler.update(candidates: [cand("A", 0.9), cand("B", 0.8), cand("C", 0.7)])
        // User advances before pumping — the window is replaced entirely.
        await scheduler.update(candidates: [cand("D", 0.9), cand("E", 0.8), cand("F", 0.7)])
        XCTAssertEqual(diag.cancellations, 3)            // A,B,C cancelled (never ran)
        await scheduler.pump()
        let decided = await scheduler.decidedCount()
        let dDecision = await scheduler.decision(for: .init("D"))
        let aDecision = await scheduler.decision(for: .init("A"))
        XCTAssertEqual(decided, 3)
        XCTAssertNotNil(dDecision)
        XCTAssertNil(aDecision)   // stale never decided
    }

    func testNoRedundantAnalysisOfSameContentID() async {
        let clock = ManualClock()
        let parts = GuardianLabFixtures.makePipeline(clock: clock)
        let scheduler = LookAheadScheduler(pipeline: parts.pipeline, diagnostics: parts.diagnostics,
                                           profile: GuardianLabFixtures.defaultProfile)
        let a = GuardianLabFixtures.beneficial("sf-a")
        await scheduler.update(candidates: [a])
        await scheduler.pump()
        let preflightsAfterFirst = parts.diagnostics.preflightRuns
        // Re-present the SAME content id — must not re-run analysis.
        await scheduler.update(candidates: [a])
        await scheduler.pump()
        XCTAssertEqual(parts.diagnostics.preflightRuns, preflightsAfterFirst)   // no redundant work
        XCTAssertGreaterThanOrEqual(parts.diagnostics.duplicateAnalysisPrevented, 1)
    }

    func testIdleNoWorkWithoutUpdateOrPump() async {
        // S10 — event-driven: constructing the scheduler does NO analysis (no polling loop).
        let parts = GuardianLabFixtures.makePipeline(clock: ManualClock())
        _ = LookAheadScheduler(pipeline: parts.pipeline, diagnostics: parts.diagnostics,
                               profile: GuardianLabFixtures.defaultProfile)
        XCTAssertEqual(parts.diagnostics.preflightRuns, 0)
        XCTAssertEqual(parts.diagnostics.decisionLatenciesNanos.count, 0)
    }
}
