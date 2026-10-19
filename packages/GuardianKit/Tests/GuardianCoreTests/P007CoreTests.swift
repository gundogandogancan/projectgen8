import XCTest
@testable import GuardianCore

final class P007CoreTests: XCTestCase {

    // §24 — native surface state is privacy-safe: positive/neutral content shows only "Guardian on", never a content label.
    func testNativeSurfacePrivacyMapping() {
        XCTAssertEqual(NativeSurfaceState.from(glyph: .humorPositive, guardianEnabled: true), .guardianOn)
        XCTAssertEqual(NativeSurfaceState.from(glyph: .learning, guardianEnabled: true), .guardianOn)
        XCTAssertEqual(NativeSurfaceState.from(glyph: .shieldMatch, guardianEnabled: true), .shieldMatch)
        XCTAssertEqual(NativeSurfaceState.from(glyph: .strongProtection, guardianEnabled: true), .shieldMatch)
        XCTAssertEqual(NativeSurfaceState.from(glyph: .caution, guardianEnabled: true), .caution)
        XCTAssertEqual(NativeSurfaceState.from(glyph: .unknown, guardianEnabled: true), .unknown)
        XCTAssertEqual(NativeSurfaceState.from(glyph: .humorPositive, guardianEnabled: false), .off)
        // lock-safe labels contain no rule text / content character detail.
        XCTAssertEqual(NativeSurfaceState.shieldMatch.lockSafeLabel, "Shield match")
    }

    // §6 — Live Activity update budget: no-change suppressed, debounce suppressed, out-of-order rejected, safety bypasses.
    func testLiveActivityUpdatePolicy() {
        let p = LiveActivityUpdatePolicy(debounceNanos: 1_000)
        XCTAssertEqual(p.consider(contentID: "A", sequence: 1, state: .guardianOn, nowNanos: 0, isSafetyEscalation: false), .accepted)
        XCTAssertEqual(p.consider(contentID: "A", sequence: 2, state: .guardianOn, nowNanos: 100, isSafetyEscalation: false), .suppressedNoChange)
        XCTAssertEqual(p.consider(contentID: "A", sequence: 3, state: .unknown, nowNanos: 200, isSafetyEscalation: false), .suppressedDebounce)
        // Safety escalation bypasses debounce even mid-window.
        XCTAssertEqual(p.consider(contentID: "A", sequence: 4, state: .shieldMatch, nowNanos: 300, isSafetyEscalation: true), .accepted)
        // Out-of-order rejected.
        XCTAssertEqual(p.consider(contentID: "A", sequence: 2, state: .caution, nowNanos: 5_000, isSafetyEscalation: false), .rejectedOutOfOrder)
        let c = p.snapshot()
        XCTAssertEqual(c.accepted, 2); XCTAssertGreaterThanOrEqual(c.suppressed, 2); XCTAssertEqual(c.outOfOrderRejected, 1)
    }

    // §26 — device capability profile routes a compute plan from runtime signals (not marketing names).
    func testDeviceCapabilityRouting() {
        XCTAssertEqual(DeviceCapabilityProfile(memoryClass: .high, computeClass: .advanced).recommendedMode(), .maxProtection)
        XCTAssertEqual(DeviceCapabilityProfile(memoryClass: .low, computeClass: .basic).recommendedMode(), .eco)
        XCTAssertEqual(DeviceCapabilityProfile(memoryClass: .medium, computeClass: .standard).recommendedMode(), .balanced)
        // Thermal/low-power dominate → eco regardless of class.
        XCTAssertEqual(DeviceCapabilityProfile(memoryClass: .high, computeClass: .advanced, lowPower: true).recommendedMode(), .eco)
        XCTAssertEqual(DeviceCapabilityProfile(memoryClass: .high, computeClass: .advanced, thermal: .serious).recommendedMode(), .eco)
        XCTAssertFalse(DeviceCapabilityProfile(computeClass: .advanced, lowPower: true).allowsHeavyModels)
        XCTAssertTrue(DeviceCapabilityProfile(memoryClass: .high, computeClass: .advanced).allowsHeavyModels)
    }

    // §23 — model lifecycle: lazy cold-load once → warm thereafter (no repeated cold-load); unload under pressure; checksum fail.
    func testModelLifecycleV2() {
        let m = ModelLifecycleV2()
        XCTAssertEqual(m.acquire("mdd"), .warm)
        XCTAssertEqual(m.acquire("mdd"), .warm)
        XCTAssertEqual(m.acquire("mdd"), .warm)
        XCTAssertEqual(m.snapshot().coldLoads, 1)       // only ONE cold load across three acquisitions
        XCTAssertEqual(m.snapshot().warmHits, 2)
        m.unloadUnderPressure()
        XCTAssertEqual(m.state("mdd"), .unloaded)
        XCTAssertEqual(m.acquire("mdd"), .warm)         // lazy re-load after pressure
        XCTAssertEqual(m.snapshot().coldLoads, 2)
        XCTAssertEqual(m.acquire("bad", checksumOK: false), .failedChecksum)
        XCTAssertEqual(m.snapshot().checksumFailures, 1)
    }

    // §15 — first trustworthy admission excludes deep stages (fast path does not wait for deep work).
    func testAdmissionTimelineExcludesDeep() {
        var t = AdmissionTimeline(caseName: "fresh-video", route: "fast+deep")
        t.stageNanos = [.identityCache: 1000, .textMerge: 2000, .shield: 1500, .fusion: 500, .admission: 500, .uiStateReady: 500,
                        .deepTemporal: 50_000, .deepSpeech: 40_000]
        XCTAssertEqual(t.firstTrustworthyNanos, 6000)   // fast stages only
        XCTAssertEqual(t.deepNanos, 90_000)             // deep tracked but NOT in first-trustworthy
        XCTAssertLessThan(t.firstTrustworthyNanos, t.deepNanos)
    }

    // §22 — task ledger drains to baseline after churn (no leak).
    func testTaskLedgerBaseline() {
        let l = TaskLedger()
        for _ in 0..<100 { l.start() }
        XCTAssertEqual(l.snapshot().active, 100)
        XCTAssertEqual(l.snapshot().maxConcurrent, 100)
        for i in 0..<100 { if i % 3 == 0 { l.cancel() } else { l.complete() } }
        XCTAssertEqual(l.snapshot().active, 0)
        XCTAssertTrue(l.isAtBaseline)
    }

    // §28 — global language gate: TR/EN carry their own lab-supported state; an unsupported language stays UNASSESSED
    // and does NOT inherit TR/EN thresholds or calibration.
    func testGlobalLanguageGate() {
        let reg = LanguageCapabilityRegistry()
        XCTAssertEqual(reg.capability("en").certification, .labSupported)
        XCTAssertEqual(reg.capability("tr").certification, .labSupported)
        XCTAssertEqual(reg.capability("xx").certification, .unassessed)      // no inheritance
        XCTAssertFalse(reg.isAtLeast("xx", .labSupported))
        XCTAssertEqual(reg.capability("xx").calibrationStatus, "UNAVAILABLE")   // not inherited; no fabricated calibration
    }
}
