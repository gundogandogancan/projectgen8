//
//  GuardianRealityProjectionTests.swift — §3 PROOF: the single truth projection keeps the eight capture→Guardian→
//  Island facts SEPARATE and derives the Island surface honestly. Covers the mandate's four required synthetic cases:
//    • Guardian ON + capture absent ≠ active protection
//    • fresh session + valid heartbeat → correct observation state
//    • new item identity → old decision/state invalid (no green carryover; UNKNOWN stays gray)
//    • ActivityKit request/accept ≠ confirmed on-screen presentation (DEVICE_UNVERIFIED, never VERIFIED)
//
//  Pure + headless (no IPC) — the projection is a pure function of the facts.
//
import XCTest
@testable import GuardianMedia

final class GuardianRealityProjectionTests: XCTestCase {

    // Convenience: a "fully live + valid decision" fact set we then poke holes in per test.
    private func liveValidFacts() -> GuardianRealityFactsV1 {
        GuardianRealityFactsV1(userRequestedOn: true, osCaptureStarted: true, framesArriving: true,
                               analysisActive: true, appGroupIPCWorking: true, liveActivityAccepted: true,
                               islandPresentationVerified: false,
                               decisionItemIdentityRevision: 7, decisionPolicyRevision: 3,
                               decisionFresh: true, currentItemIdentityRevision: 7, currentPolicyRevision: 3,
                               lastDecisionSurfaceRaw: "GUARDIAN_ON")
    }

    // MARK: - §3 — Guardian ON (toggle) + capture absent ≠ active protection.

    func testGuardianOnButCaptureAbsentIsNotActiveProtection() {
        // User flipped the toggle; NOTHING downstream happened (no OS capture, no frames, no analysis).
        let f = GuardianRealityFactsV1(userRequestedOn: true, appGroupIPCWorking: true)
        let p = GuardianRealityProjectionV1.derive(f)
        XCTAssertEqual(p.observation, .requested, "toggle on but capture not started → REQUESTED, not analyzing")
        XCTAssertFalse(p.activeProtection, "Guardian ON + capture absent is NOT active protection")
        XCTAssertEqual(p.islandSurfaceRaw, "UNKNOWN", "no live observation → gray UNKNOWN, never a safe claim")
    }

    func testCaptureStartedButNoFramesIsNotActiveProtection() {
        var f = GuardianRealityFactsV1(userRequestedOn: true, osCaptureStarted: true, appGroupIPCWorking: true)
        f.framesArriving = false
        let p = GuardianRealityProjectionV1.derive(f)
        XCTAssertEqual(p.observation, .captureStarted, "OS started but no frames → CAPTURE_STARTED")
        XCTAssertFalse(p.activeProtection, "capture started without frames is still not protecting")
    }

    func testFramesArrivingButAnalysisIdleIsObservingNotProtecting() {
        var f = liveValidFacts()
        f.analysisActive = false   // user paused heavy analysis (IDLE)
        let p = GuardianRealityProjectionV1.derive(f)
        XCTAssertEqual(p.observation, .observing, "frames but analysis idle → OBSERVING, not ANALYZING")
        XCTAssertFalse(p.activeProtection, "observing-only (idle) is not active protection")
    }

    // MARK: - §3.1 — a fresh, fully-live session with a valid decision → ANALYZING + active protection.

    func testFreshLiveSessionWithValidDecisionIsAnalyzingAndProtecting() {
        let p = GuardianRealityProjectionV1.derive(liveValidFacts())
        XCTAssertEqual(p.observation, .analyzing)
        XCTAssertEqual(p.decisionValidity, .valid)
        XCTAssertTrue(p.activeProtection, "analyzing + valid current-item decision = genuine active protection")
        XCTAssertEqual(p.islandSurfaceRaw, "GUARDIAN_ON", "a valid decision's surface is shown")
    }

    // MARK: - §3.3 — a NEW item identity invalidates the prior decision (no green carryover; UNKNOWN gray).

    func testNewItemIdentityInvalidatesPriorDecision() {
        var f = liveValidFacts()               // decision was for item rev 7, surface GUARDIAN_ON (a "safe" look)
        f.currentItemIdentityRevision = 8      // a new item swiped in
        let p = GuardianRealityProjectionV1.derive(f)
        XCTAssertEqual(p.decisionValidity, .staleItem, "new item → the old decision is STALE")
        XCTAssertFalse(p.activeProtection, "a stale decision is not active protection for the new item")
        XCTAssertEqual(p.islandSurfaceRaw, "UNKNOWN",
                       "the prior green/safe surface is NOT carried over to the new item — UNKNOWN stays gray")
    }

    func testPolicyChangeInvalidatesPriorDecision() {
        var f = liveValidFacts()
        f.currentPolicyRevision = 4   // user changed a rule since the decision was made (3 → 4)
        let p = GuardianRealityProjectionV1.derive(f)
        XCTAssertEqual(p.decisionValidity, .stalePolicy)
        XCTAssertFalse(p.activeProtection)
        XCTAssertEqual(p.islandSurfaceRaw, "UNKNOWN")
    }

    func testStaleFreshnessInvalidatesPriorDecision() {
        var f = liveValidFacts()
        f.decisionFresh = false   // the decision's evidence aged out
        let p = GuardianRealityProjectionV1.derive(f)
        XCTAssertEqual(p.decisionValidity, .staleFreshness)
        XCTAssertFalse(p.activeProtection)
        XCTAssertEqual(p.islandSurfaceRaw, "UNKNOWN")
    }

    func testNoDecisionYetIsNoneAndUnknownSurface() {
        var f = liveValidFacts()
        f.decisionItemIdentityRevision = nil; f.decisionPolicyRevision = nil; f.lastDecisionSurfaceRaw = ""
        let p = GuardianRealityProjectionV1.derive(f)
        XCTAssertEqual(p.decisionValidity, .none, "no decision produced yet")
        XCTAssertFalse(p.activeProtection)
        XCTAssertEqual(p.islandSurfaceRaw, "UNKNOWN", "observing with no decision → gray, never 'safe'")
    }

    // MARK: - §3.2 — ActivityKit request/accept ≠ confirmed on-screen presentation.

    func testActivityKitAcceptedIsDeviceUnverifiedNeverVerified() {
        var f = liveValidFacts()
        f.liveActivityAccepted = true
        f.islandPresentationVerified = false   // the real world: no public API proves on-screen visibility
        let p = GuardianRealityProjectionV1.derive(f)
        XCTAssertEqual(p.presentation, .deviceUnverified,
                       "ActivityKit acceptance is NOT proof the Island is on screen → DEVICE_UNVERIFIED")
        XCTAssertNotEqual(p.presentation, .verified, "presentation is never VERIFIED without an OS callback proof")
    }

    func testNoLiveActivityIsNotRequested() {
        var f = liveValidFacts()
        f.liveActivityAccepted = false
        let p = GuardianRealityProjectionV1.derive(f)
        XCTAssertEqual(p.presentation, .notRequested)
    }

    func testVerifiedOnlyWhenOSCallbackProvesIt() {
        // Reserved capability: ONLY an explicit OS-callback-set fact can reach VERIFIED. We never set it ourselves in
        // production, but the projection must honour it if a future capability provides a real proof.
        var f = liveValidFacts()
        f.islandPresentationVerified = true
        let p = GuardianRealityProjectionV1.derive(f)
        XCTAssertEqual(p.presentation, .verified)
    }

    // MARK: - §3.1 — a broken App Group IPC degrades honestly (never silently "active").

    func testBrokenIPCWhileCapturingIsDegraded() {
        var f = liveValidFacts()
        f.appGroupIPCWorking = false   // the IPC channel is down but the OS capture did start
        let p = GuardianRealityProjectionV1.derive(f)
        XCTAssertEqual(p.observation, .degraded, "IPC down while capturing → DEGRADED, not analyzing")
        XCTAssertFalse(p.activeProtection, "we cannot confirm protection over a broken IPC channel")
        XCTAssertEqual(p.islandSurfaceRaw, "UNKNOWN")
    }

    func testBrokenIPCBeforeCaptureIsStillRequested() {
        var f = GuardianRealityFactsV1(userRequestedOn: true, appGroupIPCWorking: false)
        f.osCaptureStarted = false
        let p = GuardianRealityProjectionV1.derive(f)
        XCTAssertEqual(p.observation, .requested, "no capture + no IPC → the honest truth is REQUESTED")
    }

    // MARK: - OFF is OFF regardless of downstream facts (a leftover live activity never implies protection).

    func testUserOffIsOffEvenWithLeftoverFacts() {
        var f = liveValidFacts()
        f.userRequestedOn = false   // user turned Guardian off; stale downstream facts linger
        let p = GuardianRealityProjectionV1.derive(f)
        XCTAssertEqual(p.observation, .off)
        XCTAssertFalse(p.activeProtection)
        XCTAssertEqual(p.islandSurfaceRaw, "OFF", "OFF shows OFF, never a carried-over content surface")
    }
}
