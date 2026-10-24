//
//  AdaptiveSessionTests.swift — §5 USER-CONTROLLED ACTIVE/IDLE bridge + §5.2 honest capability probe proofs.
//
//  These are PURE, headless proofs (no ReplayKit runtime, no device): the mode bridge is UserDefaults IPC, and the
//  capability probe is a measurement accumulator whose verdict is honest by construction. The DEVICE behaviour of
//  the ReplayKit app-info attachment is NOT testable here — that is exactly why the probe DEFAULTS to
//  FEATURE_UNAVAILABLE and ships the user-controlled switch instead (mandate §5.2).
//
import XCTest
@testable import GuardianMedia

final class AdaptiveSessionTests: XCTestCase {

    private func suite() -> (UserDefaults, String) {
        let name = "adaptive.tests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }
    private func clean(_ name: String) { UserDefaults().removePersistentDomain(forName: name) }

    // MARK: §5 — the session-mode bridge: ACTIVE by default; toggle crosses the App Group; clear resets to ACTIVE.

    func testSessionModeDefaultsToActiveAndTogglesAndClears() {
        let (s, name) = suite(); defer { clean(name) }
        XCTAssertEqual(GuardianSessionModeBridgeV1.read(suite: s), .active, "a fresh session is ACTIVE, not idle")
        XCTAssertFalse(GuardianSessionModeBridgeV1.isIdle(suite: s))

        GuardianSessionModeBridgeV1.write(.idle, suite: s)
        XCTAssertTrue(GuardianSessionModeBridgeV1.isIdle(suite: s), "the app's idle write must cross to the extension read")

        let back = GuardianSessionModeBridgeV1.toggle(suite: s)
        XCTAssertEqual(back, .active, "one-tap toggle flips idle→active")
        XCTAssertFalse(GuardianSessionModeBridgeV1.isIdle(suite: s))

        GuardianSessionModeBridgeV1.write(.idle, suite: s)
        GuardianSessionModeBridgeV1.clear(suite: s)
        XCTAssertEqual(GuardianSessionModeBridgeV1.read(suite: s), .active, "clear (session end) resets to ACTIVE — never inherits a prior idle")
    }

    func testSessionModeDegradesHonestlyWithoutSuite() {
        // nil suite → DEGRADED: write is a no-op, read defaults to ACTIVE (never a fake idle claim).
        GuardianSessionModeBridgeV1.write(.idle, suite: nil)
        XCTAssertEqual(GuardianSessionModeBridgeV1.read(suite: nil), .active)
        XCTAssertFalse(GuardianSessionModeBridgeV1.isIdle(suite: nil))
    }

    // MARK: §5.2 — the capability probe: honest verdicts, FEATURE_UNAVAILABLE until a key is actually present+updates.

    func testProbeDefaultsToFeatureUnavailableWhenKeyNeverSeen() {
        var probe = GuardianBroadcastCapabilityProbeV1()
        for _ in 0..<10 {
            probe.record(.init(hadAttachments: true, hadApplicationInfoKey: false, applicationInfoDigest: 0))
        }
        XCTAssertEqual(probe.verdict, .featureUnavailable, "no app-info key ever present → FEATURE_UNAVAILABLE")
        XCTAssertEqual(GuardianBroadcastCapabilityProbePlanV1.defaultVerdict, .featureUnavailable)
    }

    func testProbePresentButUnverifiedUntilChangeObserved() {
        var probe = GuardianBroadcastCapabilityProbeV1()
        let digestA = GuardianBroadcastCapabilityProbeV1.privacySafeDigest(of: "com.example.appA")
        for _ in 0..<5 {
            probe.record(.init(hadAttachments: true, hadApplicationInfoKey: true, applicationInfoDigest: digestA))
        }
        // Key present but the value NEVER changed → we cannot claim it updates on a foreground switch.
        XCTAssertEqual(probe.verdict, .presentUnverified)
    }

    func testProbePresentAndUpdatesOnlyAfterRealChange() {
        var probe = GuardianBroadcastCapabilityProbeV1()
        let a = GuardianBroadcastCapabilityProbeV1.privacySafeDigest(of: "com.example.appA")
        let b = GuardianBroadcastCapabilityProbeV1.privacySafeDigest(of: "com.example.appB")
        probe.record(.init(hadAttachments: true, hadApplicationInfoKey: true, applicationInfoDigest: a))
        probe.record(.init(hadAttachments: true, hadApplicationInfoKey: true, applicationInfoDigest: a))
        probe.record(.init(hadAttachments: true, hadApplicationInfoKey: true, applicationInfoDigest: b)) // a foreground switch
        XCTAssertEqual(probe.verdict, .presentAndUpdates, "only a REAL digest change reaches the 'updates' verdict")
        XCTAssertGreaterThanOrEqual(probe.digestChanges, 1)
        XCTAssertEqual(probe.distinctDigests.count, 2)
    }

    func testPrivacySafeDigestNeverReversibleAndStable() {
        let d1 = GuardianBroadcastCapabilityProbeV1.privacySafeDigest(of: "com.example.app")
        let d2 = GuardianBroadcastCapabilityProbeV1.privacySafeDigest(of: "com.example.app")
        XCTAssertEqual(d1, d2, "digest is stable (same input → same digest)")
        XCTAssertNotEqual(d1, GuardianBroadcastCapabilityProbeV1.privacySafeDigest(of: "com.example.other"))
    }

    func testDeviceProbePlanIsDocumented() {
        XCTAssertGreaterThanOrEqual(GuardianBroadcastCapabilityProbePlanV1.steps.count, 5,
                                    "the §5.2 DEVICE probe plan must be documented for a later real-device run")
    }
}
