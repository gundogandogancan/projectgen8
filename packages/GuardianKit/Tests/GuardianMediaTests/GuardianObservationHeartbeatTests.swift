//
//  GuardianObservationHeartbeatTests.swift — A3 PROOF: observation-active is derived from REAL broadcast
//  heartbeat freshness, NOT from an in-app toggle. Pure/headless — exercises the freshness policy + IPC round-trip.
//
import XCTest
@testable import GuardianMedia

final class GuardianObservationHeartbeatTests: XCTestCase {

    private func hb(_ epoch: Double, seq: UInt64 = 1, surface: String = "", reason: String = "OBSERVING",
                    broadcasting: Bool = true) -> GuardianObservationHeartbeatV1 {
        GuardianObservationHeartbeatV1(epochSeconds: epoch, sequence: seq, surfaceRaw: surface,
                                       reasonCodeRaw: reason, broadcasting: broadcasting)
    }

    // A fresh, broadcasting heartbeat within the window → ACTIVE.
    func testFreshHeartbeatIsActive() {
        let now = 1000.0
        let beat = hb(now - 0.5)
        XCTAssertTrue(GuardianObservationHeartbeatBridgeV1.isFresh(beat, nowEpoch: now))
        XCTAssertEqual(GuardianObservationHeartbeatBridgeV1.classify(beat, nowEpoch: now), .active)
    }

    // A heartbeat older than the freshness window → STALE (a stopped/crashed broadcast must NOT look active).
    func testStaleHeartbeatIsNotActive() {
        let now = 1000.0
        let beat = hb(now - 10.0)  // 10s old, window is 3s
        XCTAssertFalse(GuardianObservationHeartbeatBridgeV1.isFresh(beat, nowEpoch: now))
        XCTAssertEqual(GuardianObservationHeartbeatBridgeV1.classify(beat, nowEpoch: now), .stale)
    }

    // No heartbeat at all → ABSENT (IPC unavailable / never started) → never active.
    func testAbsentHeartbeat() {
        XCTAssertFalse(GuardianObservationHeartbeatBridgeV1.isFresh(nil, nowEpoch: 1000))
        XCTAssertEqual(GuardianObservationHeartbeatBridgeV1.classify(nil, nowEpoch: 1000), .absent)
    }

    // A heartbeat that is NOT broadcasting (e.g. a lingering record) is never active regardless of age.
    func testNotBroadcastingIsNeverActive() {
        let now = 1000.0
        XCTAssertFalse(GuardianObservationHeartbeatBridgeV1.isFresh(hb(now, broadcasting: false), nowEpoch: now))
    }

    // IPC round-trip through a real UserDefaults suite: write → read → fresh; clear → absent.
    func testWriteReadClearRoundTrip() throws {
        let suiteName = "test.gen8.heartbeat.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        let now = 5000.0
        GuardianObservationHeartbeatBridgeV1.write(hb(now, seq: 7, surface: "SHIELD_MATCH",
                                                      reason: "textEvidenceMatchedShield"), suite: suite)
        let read = GuardianObservationHeartbeatBridgeV1.read(suite: suite)
        XCTAssertEqual(read?.sequence, 7)
        XCTAssertEqual(read?.surfaceRaw, "SHIELD_MATCH")
        XCTAssertTrue(GuardianObservationHeartbeatBridgeV1.isFresh(read, nowEpoch: now + 1))

        GuardianObservationHeartbeatBridgeV1.clear(suite: suite)
        XCTAssertNil(GuardianObservationHeartbeatBridgeV1.read(suite: suite),
                     "after clear (broadcastFinished), nothing may look observing")
    }

    // B3 — every reason code yields a non-empty, jargon-free Turkish explanation; none is fabricated.
    func testReasonCodesHaveTurkishExplanations() {
        let all: [GuardianReasonCodeV1] = [
            .textEvidenceMatchedShield, .textEvidenceBenign, .contentChangedReset, .newIdentityUnconfirmed,
            .visualEvidenceInsufficient, .textEvidenceUnavailable, .observingNoDecisionYet,
            .sessionNotObserving, .guardianOff
        ]
        for code in all {
            XCTAssertFalse(code.turkishExplanation.isEmpty, "\(code) must have a user string")
            XCTAssertGreaterThan(code.turkishExplanation.count, 5)
        }
        XCTAssertEqual(GuardianReasonCodeV1.contentChangedReset.turkishExplanation,
                       "İçerik değiştiği için önceki değerlendirme sıfırlandı.")
    }
}
