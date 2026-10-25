//
//  GuardianIslandUpdateChainTests.swift — R2 §D PROOF: the Island update chain keeps APP GROUP WRITE ≠ ACTIVITYKIT
//  UPDATE ≠ ISLAND PRESENTED as three separate facts, models the three operating states explicitly, and reports the
//  SUSPENDED-app gap as BLOCKED (never pretends the update happened).
//
import XCTest
@testable import GuardianMedia

final class GuardianIslandUpdateChainTests: XCTestCase {

    // §D — capture ended → the activity must not look live, regardless of leftover writes.
    func testCaptureEndedIsEndedNotPresenting() {
        let f = GuardianIslandUpdateFactsV1(operatingState: .captureEnded, appGroupWriteFresh: true,
                                            activityKitUpdateApplied: true)
        let c = GuardianIslandUpdateChainV1.derive(f)
        XCTAssertEqual(c.status, .endedNotPresenting, "a stopped capture never keeps a live-looking Island")
        XCTAssertFalse(c.blockedBySuspension)
    }

    // §D — app FOREGROUND, fresh write, ActivityKit updated → the honest ceiling is PRESENTATION_UNVERIFIED.
    func testForegroundUpdatedIsPresentationUnverified() {
        let f = GuardianIslandUpdateFactsV1(operatingState: .appForeground, appGroupWriteFresh: true,
                                            activityKitUpdateApplied: true, islandPresentationVerified: false)
        let c = GuardianIslandUpdateChainV1.derive(f)
        XCTAssertEqual(c.status, .updatedPresentationUnverified,
                       "ActivityKit acceptance is NOT proof of on-screen visibility (no public API)")
        XCTAssertNotEqual(c.status, .updatedPresentationVerified)
        XCTAssertFalse(c.blockedBySuspension)
    }

    // §D — the KNOWN GAP: app SUSPENDED while another app is foreground. A fresh App Group write did NOT become an
    // ActivityKit update (the app-side poller is not running). This must be WRITTEN_NOT_UPDATED + blockedBySuspension.
    func testSuspendedAppWriteIsBlockedNotUpdated() {
        let f = GuardianIslandUpdateFactsV1(operatingState: .appSuspendedOtherForeground, appGroupWriteFresh: true,
                                            activityKitUpdateApplied: false)
        let c = GuardianIslandUpdateChainV1.derive(f)
        XCTAssertEqual(c.status, .writtenNotUpdated, "a write is NOT an update — kept separate")
        XCTAssertTrue(c.blockedBySuspension, "suspended app → the ActivityKit update path is BLOCKED (known gap)")
        XCTAssertEqual(c.reasonRaw, "APP_SUSPENDED_ACTIVITYKIT_UPDATE_BLOCKED")
    }

    // §D — app FOREGROUND, fresh write, but the poller has not ticked yet → WRITTEN_NOT_UPDATED but NOT blocked
    // (transient, not the suspension gap).
    func testForegroundWriteNotYetUpdatedIsPendingNotBlocked() {
        let f = GuardianIslandUpdateFactsV1(operatingState: .appForeground, appGroupWriteFresh: true,
                                            activityKitUpdateApplied: false)
        let c = GuardianIslandUpdateChainV1.derive(f)
        XCTAssertEqual(c.status, .writtenNotUpdated)
        XCTAssertFalse(c.blockedBySuspension, "a foreground pending tick is not the suspension gap")
        XCTAssertEqual(c.reasonRaw, "APP_FOREGROUND_UPDATE_PENDING")
    }

    // §D — no fresh write → NO_DECISION (nothing to present), regardless of a leftover ActivityKit activity.
    func testNoFreshWriteIsNoDecision() {
        let f = GuardianIslandUpdateFactsV1(operatingState: .appForeground, appGroupWriteFresh: false,
                                            activityKitUpdateApplied: true)
        let c = GuardianIslandUpdateChainV1.derive(f)
        XCTAssertEqual(c.status, .noDecision)
    }

    // §D — VERIFIED is reachable ONLY with a real OS-callback proof (reserved capability).
    func testVerifiedOnlyWithOSProof() {
        let f = GuardianIslandUpdateFactsV1(operatingState: .appForeground, appGroupWriteFresh: true,
                                            activityKitUpdateApplied: true, islandPresentationVerified: true)
        let c = GuardianIslandUpdateChainV1.derive(f)
        XCTAssertEqual(c.status, .updatedPresentationVerified)
    }
}
