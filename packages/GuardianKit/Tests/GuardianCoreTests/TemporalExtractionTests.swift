import XCTest
@testable import GuardianCore

final class TemporalExtractionTests: XCTestCase {
    let ex = TemporalExtractorV1()

    func testCoarseSamplePlanIsBounded() {
        let plan = ex.planCoarseSamples(durationSeconds: 600, maxSamples: 12)
        XCTAssertEqual(plan.timestampsSeconds.count, 12)   // NOT per-frame — coarse
        XCTAssertTrue(plan.timestampsSeconds.allSatisfy { $0 >= 0 && $0 <= 600 })
    }

    func testRefineAroundWindow() {
        let plan = ex.refine(around: (120, 150), samples: 4)
        XCTAssertEqual(plan.timestampsSeconds.count, 4)
        XCTAssertTrue(plan.timestampsSeconds.allSatisfy { $0 >= 120 && $0 <= 150 })
    }

    func testGraphCarriesProviderAttribution() {
        let signals = [
            TimedSignal(startSeconds: 120, endSeconds: 150, modality: .visual,
                        producedBy: "apple-vision-ocr-v1", provenance: .appleVision,
                        categories: [.violentConflict], confidence: 0.7)
        ]
        let g = ex.buildGraph(contentID: .init("vid-1"), versionTag: "v1", durationSeconds: 600, signals: signals)
        let flagged = g.segments.first { $0.isFlagged }
        XCTAssertNotNil(flagged)
        XCTAssertTrue(flagged!.flaggedConcepts.contains("apple-vision-ocr-v1"))  // WHICH provider is recorded
    }
}
