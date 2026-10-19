import XCTest
import GuardianCore
import GuardianIntelligence
@testable import GuardianMedia
#if canImport(AVFoundation)

// De-risk + core proof: generate a real MP4 headless, decode sparse frames, run REAL Vision OCR +
// feature-print scene detection over decoded content (PROMPT 005 §2–§9).
final class RealMediaDecodeTests: XCTestCase {

    private func tmpURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("gen8-\(name).mp4")
    }

    func testGenerateLoadMetadataDecodeAndOCR() async throws {
        let url = tmpURL("ocr")
        let spec = SyntheticVideo.Spec(durationSeconds: 3.0, textEvents: [(1.0, "GUARDIAN")],
                                       sceneChanges: [(0.0, 0.92), (1.8, 0.12)])
        let ok = await SyntheticVideo.write(spec, to: url)
        try XCTSkipUnless(ok, "AVAssetWriter unavailable on this runtime")
        defer { try? FileManager.default.removeItem(at: url) }

        // Real async metadata load (no MainActor block).
        let meta = await MediaAssetSource().loadMetadata(url: url)
        guard case .success(let m) = meta else { return XCTFail("metadata load failed: \(meta)") }
        XCTAssertGreaterThan(m.durationSeconds, 2.0)
        XCTAssertTrue(m.hasVideo)
        XCTAssertFalse(m.hasAudio)                      // no audio track

        // Real sparse frame extraction at a timestamp where "GUARDIAN" is on screen.
        let provider = VideoFrameProvider(url: url)
        let frames = await provider.frames(atSeconds: [1.2])
        let img = try XCTUnwrap(frames.first?.image, "no decoded frame")
        // Real Vision OCR over the DECODED frame.
        let ocr = VisionOCRProvider().recognizeText(cgImage: img)
        XCTAssertEqual(ocr.state, .ok)
        XCTAssertTrue((ocr.value?.text ?? "").uppercased().contains("GUARDIAN"),
                      "OCR over decoded video got: \(ocr.value?.text ?? "nil")")
    }

    func testSceneChangeDetectedViaFeaturePrintOnDecodedFrames() async throws {
        let url = tmpURL("scene")
        let spec = SyntheticVideo.Spec(durationSeconds: 3.0, sceneChanges: [(0.0, 0.92), (1.8, 0.08)])
        let ok = await SyntheticVideo.write(spec, to: url)
        try XCTSkipUnless(ok, "writer unavailable")
        defer { try? FileManager.default.removeItem(at: url) }
        let provider = VideoFrameProvider(url: url)
        let frames = await provider.frames(atSeconds: [0.5, 2.5])   // before vs after scene change
        guard let a = frames.first?.image, let b = frames.last?.image else { return XCTFail("no frames") }
        let fp = VisionFeatureProvider()
        guard let d = fp.distance(a, b) else { throw XCTSkip("feature print unavailable") }
        XCTAssertGreaterThan(d, 0.3)                    // decoded scene change is far apart
    }

    func testMissingFileFailsSafely() async {
        let r = await MediaAssetSource().loadMetadata(url: URL(fileURLWithPath: "/no/such/file.mp4"))
        if case .failure(let e) = r { XCTAssertEqual(e, .fileMissing) } else { XCTFail("expected failure") }
    }
}
#endif
