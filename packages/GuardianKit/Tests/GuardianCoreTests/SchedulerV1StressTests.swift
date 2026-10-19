import XCTest
@testable import GuardianCore

// Analysis-Ahead Scheduler V1 stress tests (002A §12).
final class SchedulerV1StressTests: XCTestCase {

    private func makeScheduler() -> (LookAheadScheduler, Diagnostics) {
        let parts = GuardianLabFixtures.makePipeline(clock: ManualClock())
        return (LookAheadScheduler(pipeline: parts.pipeline, diagnostics: parts.diagnostics,
                                   profile: GuardianLabFixtures.defaultProfile), parts.diagnostics)
    }
    private func cand(_ n: String, like: Double = 0.5, deadline: UInt64? = nil) -> ContentCandidate {
        ContentCandidate(id: .init(n), source: .lookAhead1, nextExposureLikelihood: like,
                         decisionDeadlineNanos: deadline,
                         fixture: FixtureSignals(goalFit: 0.9, informationDensity: 0.8))
    }

    func testRapidSwipeBurstStaysBoundedAndCancels() async {
        let (s, diag) = makeScheduler()
        // 20 rapid window replacements (swipe burst), 5 candidates each, before any pump.
        for round in 0..<20 {
            let batch = (0..<5).map { cand("r\(round)-c\($0)", like: Double(5 - $0)) }
            await s.update(candidates: batch)
            let pending = await s.pendingCount()
            XCTAssertLessThanOrEqual(pending, 3)             // always bounded ≤3
        }
        await s.pump()
        XCTAssertGreaterThan(diag.cancellations, 0)          // stale windows cancelled
        XCTAssertLessThanOrEqual(diag.peakConcurrentTasks, 3)
    }

    func testDeadlinePriorityOrdersImminentFirst() async {
        let (s, _) = makeScheduler()
        // Lower likelihood but imminent deadline should be kept over higher-likelihood no-deadline.
        await s.update(candidates: [
            cand("no-deadline-high", like: 0.99, deadline: nil),
            cand("urgent", like: 0.1, deadline: 1_000)
        ], maxDepth: 1)
        await s.pump()
        let urgent = await s.decision(for: .init("urgent"))
        XCTAssertNotNil(urgent)                              // urgent (deadline) won the single slot
    }

    func testGovernorDepthOverrideShrinksWindow() async {
        let (s, _) = makeScheduler()
        let batch = (0..<5).map { cand("g\($0)", like: Double(5 - $0)) }
        await s.update(candidates: batch, maxDepth: 1)       // ECO shrink
        let pending = await s.pendingCount()
        XCTAssertEqual(pending, 1)
    }

    func testNoDuplicateAnalysisUnderChurn() async {
        let (s, diag) = makeScheduler()
        let a = GuardianLabFixtures.beneficial("sf-stable")
        await s.update(candidates: [a]); await s.pump()
        let pre = diag.preflightRuns
        for _ in 0..<10 { await s.update(candidates: [a]); await s.pump() }
        XCTAssertEqual(diag.preflightRuns, pre)              // same ContentID never re-analyzed
    }
}
