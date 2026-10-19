import XCTest
@testable import GuardianCore

// §21/§22 — headless soak: sustained churn of candidates/tasks/cache with Guardian ON/OFF, asserting no unbounded growth
// and return-to-baseline. This is a LAB logic-level soak (not a device energy soak — that is NOT_MEASURED, no hardware).
final class P007SoakTests: XCTestCase {

    func testSoakReturnsToBaseline() {
        let ledger = TaskLedger()
        let lifecycle = ModelLifecycleV2()
        var idx = ShieldIndex()
        for i in 0..<50 { idx.upsert(ShieldRuleV2(ruleID: "r\(i)", inputType: .textExact, rawUserLabel: "topic\(i)", createdAtEpoch: 1)) }
        let ev = ShieldEvaluatorV2.standard()
        let policy = LiveActivityUpdatePolicy(debounceNanos: 1000)

        var guardianOn = true
        var now: UInt64 = 0
        // Simulate 5,000 "swipes": discover candidate → (maybe) analyze → admit → surface → release.
        for i in 0..<5000 {
            now += 10_000
            if i % 500 == 0 { guardianOn.toggle() }      // churn Guardian ON/OFF
            ledger.start(); ledger.retainMedia()
            if guardianOn {
                lifecycle.acquire("mdd")                 // warm model reused, not cold-loaded each time
                var e = ContentObservationEnvelope()
                e.structuredText = [TextSource(origin: .structured, text: i % 7 == 0 ? "a topic3 spoiler" : "ordinary clip \(i)")]
                let out = ev.evaluate(.init(envelope: e, controlledSurface: true), index: idx)
                let surface = NativeSurfaceState.from(glyph: out.matchState == .noMatch ? .neutral : .shieldMatch, guardianEnabled: true)
                // Several micro-updates share one content id (i/5) → repeats must be suppressed (no Dynamic Island spam).
                _ = policy.consider(contentID: "c\(i/5)", sequence: UInt64(i), state: surface, nowNanos: now, isSafetyEscalation: surface == .shieldMatch)
            }
            if i % 1000 == 999 { lifecycle.unloadUnderPressure() }   // periodic memory pressure
            ledger.releaseMedia(); (i % 4 == 0) ? ledger.cancel() : ledger.complete()
        }

        let s = ledger.snapshot()
        XCTAssertEqual(s.started, 5000)
        XCTAssertEqual(s.completed + s.cancelled, 5000)      // every task accounted for (no leak)
        XCTAssertEqual(s.active, 0)                          // drained to baseline
        XCTAssertEqual(s.retainedMediaObjects, 0)            // no retained media objects
        XCTAssertTrue(ledger.isAtBaseline)
        // Model cold-loads bounded (warm reuse + a few pressure reloads), NOT one per item.
        XCTAssertLessThan(lifecycle.snapshot().coldLoads, 20)
        // Index did not grow (no stale-candidate accumulation).
        XCTAssertEqual(idx.count, 50)
        // Live Activity did not spam: accepted far below requested.
        let c = policy.snapshot()
        XCTAssertLessThan(c.accepted, c.requested)
    }
}
