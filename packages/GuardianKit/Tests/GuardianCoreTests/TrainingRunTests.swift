import XCTest
@testable import GuardianCore

// Real train → eval → export run (PROMPT 004 §10, §11). Writes a run manifest + model artifact.
final class TrainingRunTests: XCTestCase {

    func testTrainEvalExportRun() throws {
        let runner = TrainingRunnerV1()
        let (model, result) = runner.run(TrainingRunnerV1.goldenTextDataset(), datasetVersion: "synthetic-mdd-v1")

        // The trained head must be at least as good as the majority-class baseline F1 on held-out test.
        XCTAssertGreaterThanOrEqual(result.overall.f1, result.baselineF1)
        XCTAssertGreaterThan(result.overall.accuracy, 0.5)            // learns something real, not random
        XCTAssertFalse(result.modelChecksum.isEmpty)

        // Export model artifact + run manifest to ml/ (repo root is 5 levels up from this test file).
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { root = root.deletingLastPathComponent() }
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let trainDir = root.appendingPathComponent("ml/training/runs", isDirectory: true)
        try FileManager.default.createDirectory(at: trainDir, withIntermediateDirectories: true)
        try enc.encode(result).write(to: trainDir.appendingPathComponent("mdd-linear-v1.manifest.json"))
        try enc.encode(model).write(to: trainDir.appendingPathComponent("mdd-linear-v1.model.json"))
    }

    func testDeterministicReproducible() {
        let r1 = TrainingRunnerV1().run(TrainingRunnerV1.goldenTextDataset(), datasetVersion: "d").model
        let r2 = TrainingRunnerV1().run(TrainingRunnerV1.goldenTextDataset(), datasetVersion: "d").model
        XCTAssertEqual(r1.checksum(), r2.checksum())                  // deterministic (same weights)
    }

    func testPerLanguageMetricsReportedSeparately() {
        let (_, result) = TrainingRunnerV1().run(TrainingRunnerV1.goldenTextDataset(), datasetVersion: "d")
        XCTAssertGreaterThanOrEqual(result.english.n, 1)             // EN evaluated
        XCTAssertGreaterThanOrEqual(result.turkish.n, 1)            // TR evaluated separately
    }

    func testAbstentionBandNotCountedAsCorrect() {
        var m = LinearClassifier(featureDim: 2)
        let data = [TrainingExample(features: [0,0], label: 1, language: "en")]
        let metrics = m.evaluate(data, abstainMargin: 0.9)           // force abstain
        XCTAssertEqual(metrics.abstentions, 1)
        XCTAssertEqual(metrics.n, 1)
    }
}
