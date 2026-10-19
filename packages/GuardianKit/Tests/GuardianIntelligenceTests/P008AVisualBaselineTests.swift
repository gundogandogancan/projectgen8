import XCTest
import CoreGraphics
@testable import GuardianCore
@testable import GuardianIntelligence

// PROMPT 008A §3 — real Apple Vision semantic baseline on owned fixtures (no external VLM). Honest availability.
final class P008AVisualBaselineTests: XCTestCase {
    func testVisualSemanticBaselineRunsReal() {
        guard let img = SyntheticImage.textImage("MOUNTAIN LAKE SUNSET", width: 640, height: 400) else { XCTFail("img"); return }
        let e = VisualSemanticBaselineV1().analyze(cgImage: img)
        // Real Vision runs: at least OCR concepts or categories or feature print; availability is honest, never faked.
        XCTAssertTrue(["available", "partial", "unavailable"].contains(e.availability))
        XCTAssertTrue(e.hasFeaturePrint || !e.ocrConcepts.isEmpty || !e.imageCategories.isEmpty)
        // Evidence carries provenance + rawMediaRetention=none (no raw pixels).
        let sig = VisualSemanticBaselineV1().evidence(e)
        for s in sig { XCTAssertEqual(s.rawMediaRetention, "none"); XCTAssertFalse(s.modelID.isEmpty) }
    }
}
