import XCTest
import GuardianCore
@testable import GuardianIntelligence

final class EvalHarnessTests: XCTestCase {

    func testHarnessRunsAndEmitsPerTaskMetrics() async throws {
        let results = await EvalHarness().run(EvalHarness.goldenV0())
        XCTAssertFalse(results.perTask.isEmpty)
        // Per-task only — there is NO single aggregate "AI accuracy" field.
        let tasks = Set(results.perTask.map { $0.task })
        XCTAssertTrue(tasks.contains("language"))
        XCTAssertTrue(tasks.contains("ocr"))
        XCTAssertTrue(tasks.contains("identity"))
        for m in results.perTask {
            XCTAssertGreaterThanOrEqual(m.n, 1)
            XCTAssertLessThanOrEqual(m.correct, m.n - m.abstentions)   // abstentions not counted as correct
        }
        // Emit machine-readable artifact next to the package (ml/evaluation/results/latest.json).
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(results)
        // Repo root (Gen8) is 5 levels up from this test file.
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { root = root.deletingLastPathComponent() }     // → .../PROJECTGEN8/Gen8
        let outDir = root.appendingPathComponent("ml/evaluation/results", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        try data.write(to: outDir.appendingPathComponent("latest.json"))
    }

    func testLanguageTaskIsAccurateOnGolden() async {
        let results = await EvalHarness().run(EvalHarness.goldenV0())
        if let lang = results.perTask.first(where: { $0.task == "language" }) {
            XCTAssertGreaterThanOrEqual(lang.accuracyExclAbstentions, 0.9)   // en+tr detected
        }
    }
}
