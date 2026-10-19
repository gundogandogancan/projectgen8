import XCTest
@testable import GuardianCore

final class P006BenchmarkTests: XCTestCase {

    private func repoRoot() -> URL { var r = URL(fileURLWithPath: #filePath); for _ in 0..<5 { r = r.deletingLastPathComponent() }; return r }
    private func writeArtifact<T: Encodable>(_ v: T, _ name: String) throws {
        // P009C-R1 repo hygiene (audit F-8): routine test runs must not churn tracked evidence JSONs.
        // Artifacts are (re)written only in explicit evidence-capture runs (GEN8_WRITE_BENCHMARKS=1).
        guard ProcessInfo.processInfo.environment["GEN8_WRITE_BENCHMARKS"] == "1" else { return }
        let dir = repoRoot().appendingPathComponent("ml/evaluation/results", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(v).write(to: dir.appendingPathComponent(name))
    }

    // §42 Sub-second admission benchmark (fast + cache paths). Real monotonic timing; misses NOT hidden.
    func testSubSecondAdmissionBenchmark() throws {
        let clock = SystemMonotonicClock()
        let s = SubSecondAdmission(clock: clock)
        var benefit = PersonalBenefitVector(); benefit.learning = 1; benefit.skill = 1; benefit.practicalUsefulness = 1
        benefit.criticalThinking = 0.9; benefit.hopeMeaning = 0.8; benefit.entertainment = 0.6; benefit.creativity = 0.8
        let inputs = FusionInputsV1(contentID: .init("b"), benefit: benefit, profile: GuardianLabFixtures.defaultProfile, availableHeadCount: 3)
        let cached = FusionResultV1(contentID: .init("b"), admission: .approve, scoreState: .verifiedFast, score: 8, reasons: [.thresholdMet], confidence: .high, explanation: "c")

        struct Case: Codable { let name: String; let route: String; let p50Nanos: UInt64; let underOneSecond: Bool; let samples: Int }
        func p50(_ block: () -> UInt64, n: Int = 50) -> UInt64 { var xs = (0..<n).map { _ in block() }.sorted(); return xs[xs.count/2] }

        let freshP50 = p50 { s.admit(inputs: inputs, cacheHit: false, cachedDecision: nil).latencyNanos }
        let cacheP50 = p50 { s.admit(inputs: inputs, cacheHit: true, cachedDecision: cached).latencyNanos }
        let cases = [
            Case(name: "fresh-fast-path", route: "FAST", p50Nanos: freshP50, underOneSecond: freshP50 < 1_000_000_000, samples: 50),
            Case(name: "exact-cache-hit", route: "CACHE", p50Nanos: cacheP50, underOneSecond: cacheP50 < 1_000_000_000, samples: 50)
        ]
        // Deterministic fusion fast path is far under 1s (LAB, macOS).
        XCTAssertTrue(cases.allSatisfy { $0.underOneSecond })
        struct Art: Codable { let label = "LAB_MEASURED"; let note: String; let cases: [Case] }
        try writeArtifact(Art(note: "Sub-second ADMISSION latency (deterministic fusion fast path), macOS LAB — NOT device SLO. Misses not hidden.", cases: cases), "p006-subsecond-admission.json")
    }

    // §43 Long-content budget: samples/audio-windows/head counts grow sublinearly with duration.
    func testLongContentBudgetBenchmark() throws {
        let sampler = WholeVideoSampler(); let audio = AudioWindowPlannerV1(); let orch = IntelligenceOrchestrator()
        let planner = ComputeBudgetPlanner()
        struct Row: Codable { let durationSeconds: Double; let samples: Int; let audioWindows: Int; let fastHeads: Int; let deepHeads: Int }
        var rows: [Row] = []
        for d in [60.0, 300, 1800, 3600] {
            let samples = sampler.plan(durationSeconds: d, mode: .balanced).timestampsSeconds.count
            let aw = audio.plan(durationSeconds: d, sceneBoundaries: [], mode: .balanced, cachedTranscript: false).count
            let comp = ContentComplexityProfile.classify(durationSeconds: d, modalities: 3, uncertainty: 0.4, policySensitivity: 0.3)
            let b = planner.plan(comp, cached: false, mode: .balanced, thermal: .nominal, lowPower: false, exposureDeadlineMs: 1000)
            let plan = orch.plan(complexity: comp, budget: b, cached: false, hasText: true, hasAudio: true, hasVideo: true, policySensitive: false)
            rows.append(Row(durationSeconds: d, samples: samples, audioWindows: aw, fastHeads: plan.fast.count, deepHeads: plan.deep.count))
        }
        // Sublinear: a 60x longer video does NOT use 60x samples.
        let s60 = rows.first!.samples, s3600 = rows.last!.samples
        XCTAssertLessThan(Double(s3600) / Double(s60), 10.0)
        struct Art: Codable { let label = "LAB_MEASURED"; let note: String; let rows: [Row] }
        try writeArtifact(Art(note: "Long-content budget grows sublinearly (coarse-first). LAB.", rows: rows), "p006-long-content-budget.json")
    }
}
