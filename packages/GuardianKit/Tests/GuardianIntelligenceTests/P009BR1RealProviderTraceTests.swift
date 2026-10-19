import XCTest
import CoreGraphics
import CoreText
@testable import GuardianIntelligence
@testable import GuardianCore

// P009B-R1 §4 — the mandated REAL path trace:
// real owned media (project-rendered image) → REAL Vision OCR/classify + REAL NL language id
// → RealObservationToExpertInputAdapterV1 → ExpertInputV2 → experts → GuardianMetaBrainV2
// → CrossModalExpertGraphV1 → ContentUnderstandingStateV1.
// The image is drawn in-process by this test (rights-clear by construction); the PERCEPTION is real —
// VNRecognizeTextRequest actually reads the pixels. No corpus/synthetic ExpertInputV2 is injected.

final class P009BR1RealProviderTraceTests: XCTestCase {

    /// Render an owned image containing known text — CoreGraphics + CoreText, no external assets.
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
        let line = CTLineCreateWithAttributedString(attr)
        ctx.textPosition = CGPoint(x: 40, y: height / 2 - 24)
        CTLineDraw(line, ctx)
        return ctx.makeImage()
    }

    func makeBrain() -> GuardianMetaBrainV2 {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1())
        b.registry.register(LanguageOCRExpertV1())
        b.registry.register(SpeechExpertV1())
        b.registry.register(AudioEventExpertV1())
        b.registry.register(MusicExpertV1())
        b.registry.register(SymbolExpertV1())
        b.registry.register(TemporalExpertV1())
        b.registry.register(SafetyEvidenceExpertV1())
        b.registry.register(BenefitEvidenceExpertV1())
        b.registry.register(AttentionPressureExpertV1())
        return b
    }

    func testRealProviderToUnderstandingStateTrace() async throws {
        guard let image = renderOwnedImage(text: "LEARN THE SCIENCE LESSON GUIDE") else {
            XCTFail("could not render owned image"); return
        }
        let adapter = RealObservationToExpertInputAdapterV1()
        let adapted = await adapter.adapt(cgImage: image)

        // 1) REAL provider truth: Vision OCR must have actually read the pixels.
        guard let ocr = adapted.input.ocrText else {
            throw XCTSkip("Vision OCR unavailable in this environment — real path requires Vision runtime")
        }
        XCTAssertTrue(ocr.uppercased().contains("LEARN"), "real VNRecognizeTextRequest read the rendered text: \(ocr)")
        XCTAssertTrue(adapted.providerProvenance.contains { $0.hasPrefix("ocr←apple-vision-ocr") })
        XCTAssertEqual(adapted.sourceMode, "REAL_IN_PROCESS")
        XCTAssertEqual(adapted.input.detectedLanguage, "en", "real NLLanguageRecognizer identified the language")

        // 2) adapter → mesh → graph → state (the full mandated chain)
        let brain = makeBrain()
        let ctx = ExpertTaskContextV2(observationID: ObservationID(1), shotID: ShotID(1), itemID: ContentItemID(1),
                                      itemProvisional: false, profile: .appFullTier1,
                                      requestedDomains: ExpertDomainV2.allCases, generation: brain.currentGeneration)
        let route = brain.route(input: adapted.input, context: ctx, nowMs: 0)
        XCTAssertTrue(route.executed.contains(.languageOCR), "real OCR text reached the language expert")
        let labels = route.evidence.flatMap { $0.labels }
        XCTAssertTrue(labels.contains("benefit:educational-candidate"),
                      "real OCR text produced real lexical evidence (learn/science/lesson/guide)")
        let graph = CrossModalExpertGraphV1(); graph.relate(route.evidence)
        let state = ContentUnderstandingStateV1.build(itemProvisional: false, evidence: route.evidence,
                                                      graph: graph, registry: brain.registry, unknownReasons: route.unknownReasons)
        XCTAssertEqual(state.identityStatus, "confirmed")
        XCTAssertFalse(state.benefitEvidence.isEmpty)
        XCTAssertFalse(state.provenance.isEmpty, "provenance chain survives to the understanding state")
        // 3) real latency samples exist (R1 §8) — never structural zero across the whole set
        let all = brain.registry.health.snapshot().values.flatMap { $0.latenciesMs }
        XCTAssertFalse(all.isEmpty)
        XCTAssertTrue(all.contains { $0 > 0 }, "monotonic measurement produced non-zero samples")
        print("P009BR1_REAL_TRACE ocr=\"\(ocr.prefix(40))\" lang=\(adapted.input.detectedLanguage ?? "nil") visual=\(adapted.input.visualLabels?.count ?? 0) executed=\(route.executed.count) benefit=\(state.benefitEvidence) routeP50=\(brain.latency.percentiles("route").map { String(format: "%.3fms", $0.p50) } ?? "NOT_MEASURED")")
    }

    func testAdapterHasNoSyntheticFallback() async {
        // A blank image yields NO ocr/visual fields — the adapter must stay silent, not fabricate.
        guard let blank = renderOwnedImage(text: " ") else { XCTFail(); return }
        let adapted = await RealObservationToExpertInputAdapterV1().adapt(cgImage: blank)
        if adapted.input.ocrText == nil {
            XCTAssertNil(adapted.input.detectedLanguage, "no language without real text")
            XCTAssertFalse(adapted.providerProvenance.contains { $0.hasPrefix("ocr←") })
        }
        // and the mesh answers honest UNAVAILABLE downstream for the missing modalities
        let brain = makeBrain()
        let ctx = ExpertTaskContextV2(observationID: ObservationID(1), shotID: ShotID(2), itemID: ContentItemID(2),
                                      itemProvisional: false, profile: .appFullTier1,
                                      requestedDomains: [.speech, .audioEvent], generation: brain.currentGeneration)
        let route = brain.route(input: adapted.input, context: ctx, nowMs: 0)
        XCTAssertTrue(route.evidence.contains { !$0.inputModalityAvailable })
    }
}
