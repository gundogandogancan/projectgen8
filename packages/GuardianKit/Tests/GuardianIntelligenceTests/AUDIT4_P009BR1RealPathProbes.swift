import XCTest
import CoreGraphics
import CoreText
@testable import GuardianIntelligence
@testable import GuardianCore

// ============================================================================
// AUDIT4_P009BR1RealPathProbes — INDEPENDENT RE-AUDIT (fresh-context session, 2026-10-19).
// HUD real-vs-synthetic mislabel attempt, probed at the layer the HUD banner depends on:
// the SwiftUI HUD (app target) labels SOURCE: REAL only when RealObservationToExpertInputAdapterV1
// returned non-empty providerProvenance. These probes attack that truth condition directly.
// This file only ADDS tests; no existing source/test file was modified by the re-auditor.
// ============================================================================

final class AUDIT4_P009BR1RealPathProbes: XCTestCase {

    func renderOwnedImage(text: String, width: Int = 900, height: Int = 240) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 64, nil)
        let attr = NSAttributedString(string: text, attributes: [
            kCTFontAttributeName as NSAttributedString.Key: font,
            kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ])
        ctx.textPosition = CGPoint(x: 40, y: height / 2 - 24)
        CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
        return ctx.makeImage()
    }

    /// MISLABEL ATTEMPT 1 — empty/blank perception may never produce "real provider" provenance,
    /// so the HUD rule (`providerProvenance.isEmpty ? .none : .real`) cannot show a REAL banner for nothing.
    func testA4_NoProvenanceWithoutRealProviderOutput() async {
        let adapter = RealObservationToExpertInputAdapterV1()
        // empty text path: nothing real happened → provenance MUST be empty → HUD cannot label REAL
        let emptyText = await adapter.adapt(providerText: "")
        XCTAssertTrue(emptyText.providerProvenance.isEmpty,
                      "no provider output → no provenance → the REAL banner is unreachable")
        XCTAssertNil(emptyText.input.ocrText)
        XCTAssertNil(emptyText.input.detectedLanguage, "no language may be fabricated from nothing")
    }

    /// MISLABEL ATTEMPT 2 — when the adapter DOES report provenance, every entry must name a known REAL
    /// in-process provider chain. Synthetic/corpus inputs structurally cannot appear here: the corpus path
    /// (GuardianCore) has no provenance/sourceMode channel at all.
    func testA4_ProvenanceEntriesOnlyFromRealProviderChains() async throws {
        guard let image = renderOwnedImage(text: "SCIENCE LESSON GUIDE TODAY") else { XCTFail(); return }
        let adapted = await RealObservationToExpertInputAdapterV1().adapt(cgImage: image)
        XCTAssertEqual(adapted.sourceMode, "REAL_IN_PROCESS", "the adapter can only ever emit REAL_IN_PROCESS")
        if adapted.providerProvenance.isEmpty {
            throw XCTSkip("Vision runtime unavailable in this environment — mislabel attempt not reachable here")
        }
        for entry in adapted.providerProvenance {
            XCTAssertTrue(entry.hasPrefix("ocr←") || entry.hasPrefix("language←") || entry.hasPrefix("visual←")
                          || entry.hasPrefix("text←"),
                          "unexpected provenance channel: \(entry)")
        }
        // if OCR text exists, it must be the text Vision actually read from the owned pixels
        if let ocr = adapted.input.ocrText {
            XCTAssertTrue(ocr.uppercased().contains("SCIENCE") || ocr.uppercased().contains("LESSON"),
                          "OCR provenance must correspond to the real pixels, got: \(ocr)")
            XCTAssertTrue(adapted.providerProvenance.contains { $0.hasPrefix("ocr←apple-vision-ocr") })
        }
    }

    /// MISLABEL ATTEMPT 3 — feeding a corpus-authored synthetic STRING through the text path is the only
    /// way lab content could reach the adapter; it is labeled as an upstream-text channel, never as
    /// Vision OCR perception (`ocr←apple-vision-ocr`), so a corpus replay cannot impersonate camera/pixels.
    func testA4_CorpusTextCannotImpersonateVisionOCR() async {
        let corpusText = "Learn how to build a birdhouse: step by step guide"   // t-text-only-en surface
        let adapted = await RealObservationToExpertInputAdapterV1().adapt(providerText: corpusText)
        XCTAssertFalse(adapted.providerProvenance.contains { $0.hasPrefix("ocr←apple-vision-ocr") },
                       "text injection may never claim Vision-OCR perception provenance")
        XCTAssertTrue(adapted.providerProvenance.contains { $0.hasPrefix("text←upstream-real-provider") })
    }
}
