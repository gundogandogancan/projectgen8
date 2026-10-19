import XCTest
import GuardianCore
@testable import GuardianIntelligence
#if canImport(Vision)
import Vision

final class VisionProvidersTests: XCTestCase {

    func testOCRReadsSyntheticText() throws {
        guard let img = SyntheticImage.textImage("GUARDIAN") else {
            throw XCTSkip("Could not create synthetic image on this runtime")
        }
        let ocr = VisionOCRProvider(mode: .accurate)
        let out = ocr.recognizeText(cgImage: img)
        // REAL Vision OCR must read our rendered text (case-insensitive contains).
        XCTAssertEqual(out.state, .ok)
        XCTAssertEqual(out.provenance, .appleVision)
        XCTAssertTrue((out.value?.text ?? "").uppercased().contains("GUARDIAN"),
                      "OCR got: \(out.value?.text ?? "nil")")
    }

    func testOCREmptyImageIsUnknownNotFabricated() throws {
        guard let img = SyntheticImage.solidImage(gray: 1.0) else { throw XCTSkip("no image") }
        let out = VisionOCRProvider().recognizeText(cgImage: img)
        XCTAssertNotEqual(out.state, .ok)   // blank → unknown/failed, never a fabricated string
    }

    func testFeaturePrintSameImageIsCloserThanDifferent() throws {
        guard let a = SyntheticImage.textImage("ALPHA CONTENT"),
              let a2 = SyntheticImage.textImage("ALPHA CONTENT"),
              let b = SyntheticImage.solidImage(gray: 0.2) else { throw XCTSkip("no image") }
        let fp = VisionFeatureProvider()
        guard let dSame = fp.distance(a, a2), let dDiff = fp.distance(a, b) else {
            throw XCTSkip("feature print unavailable on this runtime")
        }
        XCTAssertLessThan(dSame, dDiff)   // identical content closer than different content
    }
}
#endif
