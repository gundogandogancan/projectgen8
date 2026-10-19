import XCTest
@testable import GuardianCore

// Pre-exposure metrics (002A §13) — PRE_EXPOSURE_COVERAGE_RATE is LAB_MEASURED, not production SLO.
final class PreExposureMetricsTests: XCTestCase {

    private func record(_ id: String, decidedAt: UInt64, revealedAt: UInt64) -> ExposureRecord {
        ExposureRecord(contentID: .init(id), candidateDiscoveredAtNanos: 0, analysisStartedAtNanos: 10,
                       trustworthyDecisionAtNanos: decidedAt, contentRevealedAtNanos: revealedAt,
                       cacheState: "miss", route: "APPLE_NATIVE", resourceMode: "BALANCED",
                       unknownReason: nil, engineVersions: ["identity": "identity-v1"])
    }

    func testCoverageRateComputed() {
        let m = PreExposureMetrics()
        m.record(record("a", decidedAt: 100, revealedAt: 200))   // decided before reveal ✓
        m.record(record("b", decidedAt: 150, revealedAt: 150))   // exactly at reveal ✓
        m.record(record("c", decidedAt: 300, revealedAt: 200))   // decided AFTER reveal ✗
        XCTAssertEqual(m.count, 3)
        XCTAssertEqual(m.preExposureCoverageRate, 2.0/3.0, accuracy: 1e-9)   // LAB_MEASURED
        XCTAssertEqual(m.all.first?.measurementLabel, "LAB_MEASURED")
    }

    func testLeadTimeAndBeforeRevealFlags() {
        let r = record("x", decidedAt: 100, revealedAt: 250)
        XCTAssertTrue(r.decisionBeforeReveal)
        XCTAssertEqual(r.leadTimeNanos, 150)
    }
}
