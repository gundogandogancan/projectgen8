import XCTest
import GuardianCore
@testable import GuardianMedia
#if canImport(AVFoundation)

// Real-media E2E benchmark (PROMPT 005 §31). LAB_MEASURED only. Emits a machine-readable artifact.
// Kept to a few short assets to bound test time; longer durations are device/manual (documented).
final class RealMediaBenchmarkTests: XCTestCase {

    struct Row: Codable {
        let asset: String; let durationSeconds: Double; let sampleCount: Int; let framesExtracted: Int
        let ocrCalls: Int; let sceneBoundaries: Int; let flaggedWindows: Int
        let coverageVisualPercent: Double; let analysisMs: Double; let source = "SIMULATOR/LAB(macOS)"
    }

    func testRealMediaBenchmarkRuns() async throws {
        let specs: [(String, SyntheticVideo.Spec)] = [
            ("neutral-2s", .init(durationSeconds: 2.0, sceneChanges: [(0,0.9)])),
            ("textoverlay-3s", .init(durationSeconds: 3.0, textEvents: [(1.0, "LEARNING SWIFT")], sceneChanges: [(0,0.9),(1.8,0.2)])),
            ("flagged-4s", .init(durationSeconds: 4.0, textEvents: [(2.0, "EARTHQUAKE DISASTER")], sceneChanges: [(0,0.9),(2.0,0.15)]))
        ]
        let analyzer = WholeVideoAnalyzerV1()
        let sampler = WholeVideoSampler()
        var rows: [Row] = []
        for (name, spec) in specs {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("gen8b-\(name).mp4")
            let ok = await SyntheticVideo.write(spec, to: url)
            try XCTSkipUnless(ok, "writer unavailable")
            defer { try? FileManager.default.removeItem(at: url) }
            let plan = sampler.plan(durationSeconds: spec.durationSeconds, mode: .balanced)
            let r = await analyzer.analyze(url: url, contentID: .init(name), versionTag: "v1")
            XCTAssertNil(r.failure)
            rows.append(Row(asset: name, durationSeconds: spec.durationSeconds, sampleCount: plan.timestampsSeconds.count,
                            framesExtracted: r.framesExtracted, ocrCalls: r.ocrCalls, sceneBoundaries: r.sceneBoundaries.count,
                            flaggedWindows: r.flaggedWindows, coverageVisualPercent: r.coverage.visualPercent,
                            analysisMs: Double(r.analysisLatencyNanos) / 1_000_000.0))
        }
        XCTAssertEqual(rows.count, 3)
        struct Artifact: Codable { let label = "LAB_MEASURED"; let note: String; let rows: [Row] }
        let art = Artifact(note: "Real AVFoundation decode + Vision OCR E2E. macOS LAB timing — NOT device certification. Longer durations are device/manual.", rows: rows)
        // P009C-R1 repo hygiene (audit F-8): write only in explicit evidence-capture runs.
        guard ProcessInfo.processInfo.environment["GEN8_WRITE_BENCHMARKS"] == "1" else { return }
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { root = root.deletingLastPathComponent() }
        let outDir = root.appendingPathComponent("ml/evaluation/results", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(art).write(to: outDir.appendingPathComponent("p005-e2e-benchmark.json"))
    }
}
#endif
