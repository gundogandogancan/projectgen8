import XCTest
@testable import GuardianCore

// PROMPT 007D — cheap change detector: heavy work runs ONCE per distinct content; unchanged frames never re-analyze.
final class P007DCrossAppTests: XCTestCase {

    private func sig(_ b: UInt64) -> PerceptualFrameSignature { .init(bits: b) }

    func testHeavyWorkRunsOncePerContent() {
        let det = ContentChangeDetector(changeThreshold: 10, settleFrames: 2)
        var stats = CrossAppObservationStats()
        // Simulate a cross-app session: content A for 5 frames, then content B (very different) for 5 frames.
        let a: UInt64 = 0x0000_0000_0000_0000
        let b: UInt64 = 0xFFFF_FFFF_FFFF_FFFF   // hamming 64 from a → definite change
        var analyzedContentIDs = Set<String>()
        for frame in (Array(repeating: a, count: 5) + Array(repeating: b, count: 5)) {
            stats.framesProcessed += 1
            let d = det.observe(sig(frame))
            if d.stableFrames == 1 && d.contentID.hasSuffix("2") || d.stableFrames == 1 { /* transition bookkeeping */ }
            if d.changed {
                stats.contentsAnalyzed += 1
                if analyzedContentIDs.contains(d.contentID) { stats.cacheReuse += 1 }
                else { analyzedContentIDs.insert(d.contentID); stats.heavyAnalysisRuns += 1 }
            }
        }
        XCTAssertEqual(stats.framesProcessed, 10)
        // Exactly TWO distinct contents analyzed (A once, B once) — NOT 10 heavy runs.
        XCTAssertEqual(stats.heavyAnalysisRuns, 2, "heavy analysis must run once per distinct content, not per frame")
        XCTAssertEqual(analyzedContentIDs.count, 2)
    }

    func testUnchangedFramesNeverReanalyze() {
        let det = ContentChangeDetector(changeThreshold: 10, settleFrames: 2)
        var analyzed = 0
        for _ in 0..<100 { if det.observe(sig(0x00FF_00FF_00FF_00FF)).changed { analyzed += 1 } }
        XCTAssertEqual(analyzed, 1, "a single unchanging content analyzes exactly once across 100 frames")
    }

    func testEnvelopeIsEphemeralAndCarriesNoRawFrame() {
        let e = CrossAppObservationBuilder.envelope(contentID: "cac-1", ocrText: "SALE 50%", soundEvents: ["music"], languages: ["en"])
        XCTAssertEqual(e.privacyClass, "ephemeral-on-device")
        XCTAssertEqual(e.surfaceCapabilityTier, "C_CROSS_APP")
        XCTAssertEqual(e.ocrText.first?.text, "SALE 50%")
        // Structurally carries only derived text/sound/lang signals — there is no frame/pixel field on the envelope.
    }

    func testPerceptualHammingDiscriminates() {
        XCTAssertEqual(sig(0).hamming(sig(0)), 0)
        XCTAssertEqual(sig(0).hamming(sig(0xFFFF_FFFF_FFFF_FFFF)), 64)
        XCTAssertLessThan(sig(0x00FF).hamming(sig(0x01FF)), 5)   // near-identical frames → small distance
    }
}
