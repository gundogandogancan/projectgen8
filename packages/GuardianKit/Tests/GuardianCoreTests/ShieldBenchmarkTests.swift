import XCTest
@testable import GuardianCore

// PROMPT 006A §16 — Shield index must stay bounded & fast as rule count grows (10 / 100 / 1000).
final class ShieldBenchmarkTests: XCTestCase {

    private func buildIndex(_ n: Int) -> ShieldIndex {
        var idx = ShieldIndex()
        for i in 0..<n { idx.upsert(ShieldRuleV2(ruleID: "r\(i)", inputType: .textExact, rawUserLabel: "topic\(i)")) }
        idx.upsert(ShieldRuleV2(ruleID: "hit", inputType: .textExact, rawUserLabel: "earthquake", action: .hideIfControlled))
        return idx
    }

    private func sample() -> ContentObservationEnvelope {
        var e = ContentObservationEnvelope()
        e.structuredText = [TextSource(origin: .structured, text: "breaking news about an earthquake today near the coast")]
        e.languageSignals = ["en"]
        return e
    }

    func testShieldScalesTo1000Rules() {
        let ev = ShieldEvaluatorV2.standard()
        let env = sample()
        for n in [10, 100, 1000] {
            let idx = buildIndex(n)
            let iterations = 500
            let start = DispatchTime.now().uptimeNanoseconds
            var lastMatchers = 0
            for _ in 0..<iterations {
                let out = ev.evaluate(.init(envelope: env, controlledSurface: true), index: idx)
                lastMatchers = out.matchersRun
                XCTAssertEqual(out.ruleID, "hit")                 // correctness holds at every scale
                XCTAssertEqual(out.actionRecommendation, .hideIfControlled)
            }
            let elapsed = DispatchTime.now().uptimeNanoseconds &- start
            let perEvalMicros = Double(elapsed) / Double(iterations) / 1000.0
            // Bounded work: matchers run on the shortlist, not on all N rules.
            XCTAssertLessThan(lastMatchers, 60, "matchers run on shortlist, not all \(n) rules")
            print("SHIELD_BENCH rules=\(n) perEval=\(String(format: "%.2f", perEvalMicros))µs matchersRun=\(lastMatchers)")
        }
    }
}
