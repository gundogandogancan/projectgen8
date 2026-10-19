import XCTest
@testable import GuardianCore

final class TemporalTests: XCTestCase {
    let guardian = TemporalGuardian()

    func testUpcomingFlaggedSegment() {
        let g = GuardianLabFixtures.correctTemporalGraph()
        let seg = guardian.upcomingFlaggedSegment(graph: g, afterSeconds: 0)
        XCTAssertEqual(seg?.index, 1)
        XCTAssertEqual(seg?.startSeconds, 120)
    }

    func testWarningLeadTime() {
        let g = GuardianLabFixtures.correctTemporalGraph()
        XCTAssertNotNil(guardian.shouldWarn(graph: g, playhead: 100, leadSeconds: 30)) // 20s away
        XCTAssertNil(guardian.shouldWarn(graph: g, playhead: 50, leadSeconds: 30))     // 70s away
    }

    func testStrictAutoSkipWhenAligned() {
        let g = GuardianLabFixtures.correctTemporalGraph()
        let id = GuardianLabFixtures.longFormIdentity()      // vid-1 / v1 / I4
        let seg = g.segments[1]
        XCTAssertEqual(guardian.evaluateSkip(segment: seg, identity: id, graph: g, mode: .strict), .autoSkip)
    }

    func testNormalModeAsks() {
        let g = GuardianLabFixtures.correctTemporalGraph()
        let id = GuardianLabFixtures.longFormIdentity()
        XCTAssertEqual(guardian.evaluateSkip(segment: g.segments[1], identity: id, graph: g, mode: .normal), .ask)
    }

    func testWrongVersionRefusesAutoSkip() {
        // Identity is v1 but the TemporalGraph is an alternate cut (v2) → NEVER blind-seek.
        let wrong = GuardianLabFixtures.wrongVersionTemporalGraph()
        let id = GuardianLabFixtures.longFormIdentity()       // v1
        let seg = wrong.segments[1]
        XCTAssertEqual(guardian.evaluateSkip(segment: seg, identity: id, graph: wrong, mode: .strict),
                       .refusedVersionMismatch)
    }

    func testWeakIdentityRefusesAutoSkip() {
        let g = GuardianLabFixtures.correctTemporalGraph()
        let weak = ContentIdentityResult(contentID: .init("vid-1"), state: .i2_probable, versionTag: "v1")
        XCTAssertEqual(guardian.evaluateSkip(segment: g.segments[1], identity: weak, graph: g, mode: .strict),
                       .refusedVersionMismatch)   // I2 < I3 required for high-impact action
    }

    func testAnalysisAheadStates() {
        XCTAssertEqual(guardian.analysisAheadState(playhead: 100, verifiedUntil: 180, analyzingUntil: 240), .verifiedAhead)
        XCTAssertEqual(guardian.analysisAheadState(playhead: 200, verifiedUntil: 180, analyzingUntil: 240), .analyzingAhead)
        XCTAssertEqual(guardian.analysisAheadState(playhead: 300, verifiedUntil: 180, analyzingUntil: 240), .behindPlayhead)
    }
}
