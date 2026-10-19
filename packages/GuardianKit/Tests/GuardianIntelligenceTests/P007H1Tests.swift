import XCTest
import CoreGraphics
@testable import GuardianCore
@testable import GuardianIntelligence

// §11/§12/§14 — H1 sensitive-visual SAFETY is distinct from the visual-reference SHIELD, and remains honestly UNAVAILABLE.
final class P007H1Tests: XCTestCase {

    // H1 is UNAVAILABLE (no rights-clear model) — never fabricated, even when a frame is available.
    func testH1RemainsUnavailable() {
        let sig = SensitiveVisualHead().classify()
        XCTAssertEqual(sig.availability, .unavailable)
        XCTAssertNil(sig.value)
        XCTAssertEqual(sig.abstentionReason, .notImplemented)
    }

    // §14 — a visual REFERENCE shield match ("looks like the image I told you to avoid") must NEVER be read as an H1
    // SAFETY verdict ("contains graphic violence/gore"). They are different types with different reason codes.
    func testVisualShieldIsNotSafetyClassifier() throws {
        let ingestor = ShieldImageReferenceIngestor()
        let matcher = ShieldVisualReferenceMatcher()
        // A benign reference image that happens to match → shield reason is visualReference, NOT a safety category.
        guard let ref = SyntheticImage.textImage("MY BRAND", width: 320, height: 160) else { XCTFail("img"); return }
        guard let out = ingestor.ingest(cgImage: ref, ruleID: "brand", nowEpoch: 1) else { XCTFail("ingest"); return }
        let m = matcher.match(frame: ref, reference: out.signature)
        // The shield result's reason is a reference match, never a sensitive-visual safety reason.
        XCTAssertEqual(m.reason, .visualReference)
        XCTAssertNotEqual(m.reason, .matchabilityUnknown)
        // H1 safety for the very same frame remains UNAVAILABLE — a shield match does not imply a safety verdict.
        XCTAssertEqual(SensitiveVisualHead().classify().availability, .unavailable)
    }
}
