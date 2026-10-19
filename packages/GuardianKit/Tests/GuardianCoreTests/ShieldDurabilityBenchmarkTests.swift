import XCTest
@testable import GuardianCore

// 006B §15 — re-run Shield benchmarks on the DURABLE path (persist + rebuild), with p50/p95/p99.
final class ShieldDurabilityBenchmarkTests: XCTestCase {

    private func percentile(_ xs: [Double], _ p: Double) -> Double {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted(); let i = min(s.count - 1, Int(p * Double(s.count)))
        return s[i]
    }
    private func micros(_ block: () -> Void) -> Double {
        let t0 = DispatchTime.now().uptimeNanoseconds; block()
        return Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1000.0
    }

    func testDurableShieldBenchmark() throws {
        let ev = ShieldEvaluatorV2.standard()
        var e = ContentObservationEnvelope()
        e.structuredText = [TextSource(origin: .structured, text: "breaking news about an earthquake near the coast today")]
        e.languageSignals = ["en"]

        for n in [10, 100, 1000, 10_000] {
            var rules = (0..<n).map { ShieldRuleV2(ruleID: "r\($0)", inputType: .textExact, rawUserLabel: "topic\($0)", createdAtEpoch: 1) }
            rules.append(ShieldRuleV2(ruleID: "hit", inputType: .textExact, rawUserLabel: "earthquake", action: .hideIfControlled, createdAtEpoch: 1))

            let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gen8-dur-\(n)-\(UUID().uuidString)")
            let store = FileBackedPersonalShieldStore(directory: dir)
            try store.save(ShieldStoreSnapshot(rules: rules))

            // Cold load + rebuild (fresh store instance = relaunch) → first usable Shield decision.
            var index = ShieldIndex()
            let cold = micros { index = (try? ShieldStoreManager(store: FileBackedPersonalShieldStore(directory: dir)).loadAndRebuild().index) ?? ShieldIndex() }
            let firstDecision = micros { _ = ev.evaluate(.init(envelope: e, controlledSurface: true), index: index) }

            // Warm lookup + exact match (p50/p95/p99 over iterations).
            var lookups: [Double] = []
            let iters = n >= 10_000 ? 200 : 500
            for _ in 0..<iters {
                lookups.append(micros {
                    let out = ev.evaluate(.init(envelope: e, controlledSurface: true), index: index)
                    precondition(out.ruleID == "hit")
                })
            }
            // Delete + reindex, and a rule update.
            let delete = micros { index.remove("hit") }
            let update = micros { index.upsert(ShieldRuleV2(ruleID: "hit", inputType: .textExact, rawUserLabel: "earthquake", action: .hideIfControlled, createdAtEpoch: 1)) }

            print(String(format: "SHIELD_DUR_BENCH rules=%d coldLoad=%.0fµs firstDecision=%.2fµs lookupP50=%.2fµs p95=%.2fµs p99=%.2fµs delete=%.2fµs update=%.2fµs",
                         n, cold, firstDecision, percentile(lookups, 0.50), percentile(lookups, 0.95), percentile(lookups, 0.99), delete, update))

            // Correctness + bounded-work invariants still hold on the durable path.
            let out = ev.evaluate(.init(envelope: e, controlledSurface: true), index: index)
            XCTAssertEqual(out.ruleID, "hit")
            XCTAssertLessThan(out.matchersRun, 60)
            try? store.wipe(); try? FileManager.default.removeItem(at: dir)
        }
    }
}
