import XCTest
import GuardianCore
@testable import GuardianIntelligence
#if canImport(Vision)

final class FastPreflightTests: XCTestCase {

    func testOrchestratesRealProvidersWithProvenance() async throws {
        guard let img = SyntheticImage.textImage("LEARNING SWIFT TODAY"),
              let png = SyntheticImage.pngData(img) else { throw XCTSkip("no image/encode on runtime") }
        let engine = FastPreflightEngineV1()
        let env = await engine.run(imageBytes: png, providedText: nil)

        // Identity real (crypto).
        XCTAssertEqual(env.heads["identity"]?.state, .real)
        XCTAssertEqual(env.heads["identity"]?.provenance, .cryptoHash)
        XCTAssertNotNil(env.identityExactHash)

        // OCR real → text read; language real via NaturalLanguage from OCR text.
        XCTAssertEqual(env.heads["ocr"]?.state, .real)
        XCTAssertTrue((env.ocrText ?? "").uppercased().contains("SWIFT"), "ocr: \(env.ocrText ?? "nil")")
        XCTAssertEqual(env.heads["language"]?.state, .real)
        XCTAssertEqual(env.language, "en")

        // Unbuilt classifiers MUST be UNAVAILABLE — never fabricated (002A §3).
        for head in ["personalBenefit", "violence", "disease", "manipulation", "childSafety", "sensitiveContent"] {
            XCTAssertEqual(env.heads[head]?.state, .unavailable, "\(head) must not be fabricated")
        }
    }

    func testUnavailableHeadsWhenNoImage() async {
        let engine = FastPreflightEngineV1()
        let env = await engine.run(imageBytes: nil, providedText: "The device feels nothing.")
        XCTAssertEqual(env.heads["identity"]?.state, .unavailable)   // no bytes → honest UNAVAILABLE
        XCTAssertEqual(env.heads["ocr"]?.state, .unavailable)
        XCTAssertEqual(env.language, "en")                           // language still works from provided text
    }
}
#endif
