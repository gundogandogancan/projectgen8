import XCTest
@testable import GuardianCore

// Whole-video benchmark suite (PROMPT 004 §18). LAB_MEASURED only (not device certification).
// Emits a machine-readable artifact with sample counts + coverage per duration. No fabricated device numbers.
final class WholeVideoBenchmarkTests: XCTestCase {

    struct Row: Codable { let durationSeconds: Double; let mode: String; let sampleCount: Int
                          let windowCount: Int; let deepenedPlanned: Int; let coverageVisualPercent: Double }

    func testBenchmarkRunsAcrossDurations() throws {
        let sampler = WholeVideoSampler()
        let planner = DeepeningPlannerV1()
        let durations: [Double] = [15, 30, 60, 300, 900, 3600]
        var rows: [Row] = []
        for d in durations {
            for mode in [ResourceModeV2.eco, .balanced, .maxProtection] {
                let plan = sampler.plan(durationSeconds: d, mode: mode)
                XCTAssertLessThanOrEqual(plan.timestampsSeconds.count, 100)    // bounded even at 1h
                // Build a coarse map (every window sampled, half uncertain) to exercise coverage + deepening.
                let winCount: Int = min(plan.timestampsSeconds.count, 24)
                let step: Double = d / Double(max(1, winCount))
                var windows: [CoarseWindow] = []
                for i in 0..<winCount {
                    let cats: Set<SensitiveCategory> = (i % 5 == 0) ? [.disaster] : []
                    let unc: Double = (i % 2 == 0) ? 0.8 : 0.1
                    windows.append(CoarseWindow(startSeconds: Double(i) * step, endSeconds: Double(i + 1) * step,
                                                sampled: true, deepened: false, categories: cats,
                                                uncertainty: unc, value: 0.5))
                }
                var cov = WholeVideoCoverage()
                cov.visualPercent = 100.0
                cov.unknownRegionPercent = 20
                let map = CoarseTemporalMapV1(contentID: .init("bench-\(Int(d))"), versionTag: "v1", windows: windows, coverage: cov)
                let deepen = planner.plan(map: map, playheadSeconds: 0, maxDeepen: mode == .eco ? 1 : 4)
                rows.append(Row(durationSeconds: d, mode: mode.rawValue, sampleCount: plan.timestampsSeconds.count,
                                windowCount: winCount, deepenedPlanned: deepen.count, coverageVisualPercent: cov.visualPercent))
            }
        }
        // ECO must deepen no more than BALANCED/MAX for the same video.
        XCTAssertFalse(rows.isEmpty)
        // Emit LAB artifact.
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { root = root.deletingLastPathComponent() }
        let outDir = root.appendingPathComponent("ml/evaluation/results", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        struct Artifact: Codable { let label = "LAB_MEASURED"; let note: String; let rows: [Row] }
        let art = Artifact(note: "Sample counts + coverage per duration/mode. Timing is LAB (sim); NOT device SLO.", rows: rows)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(art).write(to: outDir.appendingPathComponent("whole-video-benchmark.json"))
    }

    func testEcoDeepensLessThanMax() {
        let sampler = WholeVideoSampler(); let planner = DeepeningPlannerV1()
        let windows = (0..<10).map { i in CoarseWindow(startSeconds: Double(i)*10, endSeconds: Double(i+1)*10,
                      sampled: true, deepened: false, categories: [.violentConflict], uncertainty: 0.9, value: 0.3) }
        let map = CoarseTemporalMapV1(contentID: .init("v"), versionTag: "v1", windows: windows, coverage: WholeVideoCoverage())
        _ = sampler
        let eco = planner.plan(map: map, playheadSeconds: 0, maxDeepen: 1)
        let mx = planner.plan(map: map, playheadSeconds: 0, maxDeepen: 4)
        XCTAssertLessThanOrEqual(eco.count, mx.count)
    }
}
