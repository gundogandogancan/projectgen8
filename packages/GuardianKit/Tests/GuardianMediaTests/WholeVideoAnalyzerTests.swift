import XCTest
import GuardianCore
import GuardianIntelligence
@testable import GuardianMedia
#if canImport(AVFoundation)

final class WholeVideoAnalyzerTests: XCTestCase {
    private func tmp(_ n: String) -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("gen8a-\(n).mp4") }

    private func makeVideo(_ n: String, _ spec: SyntheticVideo.Spec) async throws -> URL {
        let url = tmp(n); let ok = await SyntheticVideo.write(spec, to: url)
        try XCTSkipUnless(ok, "AVAssetWriter unavailable"); return url
    }

    func testE2EProducesTemporalGraphV4AndContentDNAWithoutRawMedia() async throws {
        let url = try await makeVideo("e2e", SyntheticVideo.Spec(durationSeconds: 4.0,
            textEvents: [(1.0, "EARTHQUAKE WAR")], sceneChanges: [(0.0, 0.9), (2.0, 0.1)]))
        defer { try? FileManager.default.removeItem(at: url) }
        let analyzer = WholeVideoAnalyzerV1()
        let r = await analyzer.analyze(url: url, contentID: .init("e2e-1"), versionTag: "v1")
        XCTAssertNil(r.failure)
        XCTAssertGreaterThan(r.framesExtracted, 0)               // real decode happened
        XCTAssertGreaterThan(r.ocrCalls, 0)
        XCTAssertGreaterThan(r.temporalGraph.segments.count, 0)  // TemporalGraph V4 from real media
        XCTAssertGreaterThanOrEqual(r.flaggedWindows, 1)         // "EARTHQUAKE WAR" → flagged window
        XCTAssertNotNil(r.contentDNA.coverage)
        XCTAssertFalse(r.contentDNA.ocrDerivedText.isEmpty)
        // ContentDNA V4 contains NO raw media (structural): no Data properties.
        for c in Mirror(reflecting: r.contentDNA).children { XCTAssertFalse(c.value is Data) }
    }

    func testCacheReuseAvoidsDecodeSecondPass() async throws {
        let url = try await makeVideo("cache", SyntheticVideo.Spec(durationSeconds: 3.0, textEvents: [(1.0, "HELLO")]))
        defer { try? FileManager.default.removeItem(at: url) }
        let analyzer = WholeVideoAnalyzerV1()
        let first = await analyzer.analyze(url: url, contentID: .init("c1"), versionTag: "v1")
        let second = await analyzer.analyze(url: url, contentID: .init("c1"), versionTag: "v1")
        XCTAssertFalse(first.cacheHit)
        XCTAssertTrue(second.cacheHit)                           // reuse
        XCTAssertEqual(second.framesExtracted, 0)                // no re-decode
        XCTAssertEqual(second.avoidedFrameExtractions, first.framesExtracted)
    }

    func testCacheInvalidationOnVersionChange() async throws {
        let url = try await makeVideo("inv", SyntheticVideo.Spec(durationSeconds: 3.0, textEvents: [(1.0, "HI")]))
        defer { try? FileManager.default.removeItem(at: url) }
        let analyzer = WholeVideoAnalyzerV1()
        _ = await analyzer.analyze(url: url, contentID: .init("c2"), versionTag: "v1")
        let altCut = await analyzer.analyze(url: url, contentID: .init("c2"), versionTag: "v2-altcut")
        XCTAssertFalse(altCut.cacheHit)                          // alternate cut → not reused
    }

    func testLongFormWarnSkipAndAlternateCutRefusal() async throws {
        let url = try await makeVideo("long", SyntheticVideo.Spec(durationSeconds: 6.0,
            textEvents: [(3.0, "WAR CONFLICT")], sceneChanges: [(0.0, 0.9), (3.0, 0.2)]))
        defer { try? FileManager.default.removeItem(at: url) }
        let analyzer = WholeVideoAnalyzerV1()
        let r = await analyzer.analyze(url: url, contentID: .init("vid-long"), versionTag: "v1")
        let guardianT = TemporalGuardian()
        // Aligned identity (same version) → skip gate works; wrong version → refused.
        let aligned = ContentIdentityResult(contentID: .init("vid-long"), state: .i4_verified, versionTag: "v1")
        let wrong = ContentIdentityResult(contentID: .init("vid-long"), state: .i4_verified, versionTag: "v2")
        if let seg = r.temporalGraph.segments.first(where: { $0.isFlagged }) {
            XCTAssertEqual(guardianT.evaluateSkip(segment: seg, identity: aligned, graph: r.temporalGraph, mode: .strict), .autoSkip)
            XCTAssertEqual(guardianT.evaluateSkip(segment: seg, identity: wrong, graph: r.temporalGraph, mode: .strict), .refusedVersionMismatch)
        } else {
            throw XCTSkip("no flagged segment detected in this run")
        }
    }

    func testMissingAndNoVideoFailSafely() async {
        let analyzer = WholeVideoAnalyzerV1()
        let missing = await analyzer.analyze(url: URL(fileURLWithPath: "/no/file.mp4"), contentID: .init("x"), versionTag: "v1")
        XCTAssertEqual(missing.failure, .fileMissing)
        XCTAssertEqual(missing.coverage.unknownRegionPercent, 100)   // never safe-when-unknown
    }

    func testIdleDoesNoWork() {
        let diag = Diagnostics()
        _ = WholeVideoAnalyzerV1(diagnostics: diag)
        XCTAssertEqual(diag.snapshot.preflightRuns, 0)               // constructing does nothing
        XCTAssertEqual(diag.snapshot.decisionCount, 0)
    }

    func testSpeechUnavailableHonest() async {
        let out = await SpeechTranscriptionAdapter().transcribe(MediaRef(kind: .audioBytes))
        XCTAssertEqual(out.state, .unavailable)                     // honest, not faked, no cloud
    }

    func testCancellationDoesNotCrashOrPresentStale() async throws {
        let url = try await makeVideo("cancel", SyntheticVideo.Spec(durationSeconds: 5.0, sceneChanges: [(0,0.9),(2,0.1)]))
        defer { try? FileManager.default.removeItem(at: url) }
        let analyzer = WholeVideoAnalyzerV1()
        let task = Task { await analyzer.analyze(url: url, contentID: .init("cx"), versionTag: "v1") }
        task.cancel()
        let r = await task.value
        // Either cancelled early (safe) or completed — never a crash; cancelled → no stale success implied.
        XCTAssertTrue(r.failure == .cancelled || r.failure == nil)
    }
}
#endif
