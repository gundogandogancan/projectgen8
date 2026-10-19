import XCTest
import GuardianCore
@testable import GuardianIntelligence
#if canImport(Vision)
import CoreGraphics

// Empirical identity robustness (002A §4). Uses Vision feature-print distance on synthetic fixtures.
// We ONLY claim robustness to transformations actually observed to pass here.
final class IdentityRobustnessTests: XCTestCase {
    let fp = VisionFeatureProvider()

    func testByteIdenticalIsNearZeroDistance() throws {
        guard let a = SyntheticImage.textImage("ROBUST CONTENT"),
              let b = SyntheticImage.textImage("ROBUST CONTENT") else { throw XCTSkip("no image") }
        guard let d = fp.distance(a, b) else { throw XCTSkip("feature print unavailable") }
        XCTAssertLessThan(d, 1.0)                 // same content → close
    }

    func testPngReencodeStaysClose() throws {
        guard let a = SyntheticImage.textImage("REENCODE ME"),
              let png = SyntheticImage.pngData(a),
              let b = FastPreflightEngineV1.cgImage(from: png) else { throw XCTSkip("no encode") }
        guard let d = fp.distance(a, b) else { throw XCTSkip("feature print unavailable") }
        XCTAssertLessThan(d, 1.0)                 // PNG round-trip (re-encode) stays close
    }

    func testDifferentContentIsFarNegativeControl() throws {
        guard let a = SyntheticImage.textImage("ALPHA"),
              let b = SyntheticImage.solidImage(gray: 0.1) else { throw XCTSkip("no image") }
        guard let dSame = fp.distance(a, a), let dDiff = fp.distance(a, b) else { throw XCTSkip("unavailable") }
        XCTAssertGreaterThan(dDiff, dSame)        // different content must be farther (no false match)
    }
}
#endif
