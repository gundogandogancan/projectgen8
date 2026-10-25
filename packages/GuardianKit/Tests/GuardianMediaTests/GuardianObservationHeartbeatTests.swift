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

    // A1 — a stale heartbeat from a PREVIOUS session (same time window, different session id) must NOT be read as
    // the current session being live. Session-scoped freshness rejects it.
    func testHeartbeatSessionScopingRejectsPriorSession() {
        let now = 1000.0
        let oldSession = hbS(now - 0.2, session: "SESSION-OLD")   // fresh in time, but a DIFFERENT session
        // Reader observing the NEW session must not treat the old-session heartbeat as active.
        XCTAssertFalse(GuardianObservationHeartbeatBridgeV1.isFresh(oldSession, nowEpoch: now,
                                                                    expectedSessionID: "SESSION-NEW"))
        XCTAssertEqual(GuardianObservationHeartbeatBridgeV1.classify(oldSession, nowEpoch: now,
                                                                     expectedSessionID: "SESSION-NEW"), .stale)
        // The SAME session id (and in-window) IS active.
        XCTAssertTrue(GuardianObservationHeartbeatBridgeV1.isFresh(oldSession, nowEpoch: now,
                                                                   expectedSessionID: "SESSION-OLD"))
        // No expected session (or empty) → backward-compatible freshness (time-only).
        XCTAssertTrue(GuardianObservationHeartbeatBridgeV1.isFresh(oldSession, nowEpoch: now))
    }

    private func hbS(_ epoch: Double, session: String) -> GuardianObservationHeartbeatV1 {
        GuardianObservationHeartbeatV1(epochSeconds: epoch, sequence: 1, surfaceRaw: "", reasonCodeRaw: "OBSERVING",
                                       broadcasting: true, sessionID: session)
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

    // MARK: - R2 §A — INDEPENDENT decision facts in the heartbeat.

    // The new fields round-trip through Codable, and default sensibly on a LEGACY encoding (no hard-fail).
    func testIndependentDecisionFieldsRoundTripAndLegacyDefaults() throws {
        let beat = GuardianObservationHeartbeatV1(epochSeconds: 100, sequence: 3, surfaceRaw: "GUARDIAN_ON",
                                                  reasonCodeRaw: "x", broadcasting: true, sessionID: "s",
                                                  policyRevision: 2, itemIdentityRevision: 7,
                                                  decisionEpochSeconds: 95, currentItemIdentityRevision: 9)
        let data = try JSONEncoder().encode(beat)
        let decoded = try JSONDecoder().decode(GuardianObservationHeartbeatV1.self, from: data)
        XCTAssertEqual(decoded, beat)
        XCTAssertEqual(decoded.itemIdentityRevision, 7, "the DECISION's item")
        XCTAssertEqual(decoded.currentItemIdentityRevision, 9, "the CURRENT item, published independently")
        XCTAssertEqual(decoded.decisionEpochSeconds, 95, "the DECISION's OWN timestamp, not the publish time (100)")

        // A legacy JSON without the new keys still decodes: currentItemIdentityRevision defaults to the decision's
        // item, decisionEpochSeconds defaults to 0 (treated as 'no decision timestamp').
        let legacy = #"{"epochSeconds":100,"sequence":3,"surfaceRaw":"GUARDIAN_ON","reasonCodeRaw":"x","broadcasting":true,"sessionID":"s","policyRevision":2,"itemIdentityRevision":7}"#
        let old = try JSONDecoder().decode(GuardianObservationHeartbeatV1.self, from: Data(legacy.utf8))
        XCTAssertEqual(old.currentItemIdentityRevision, 7, "legacy current defaults to the decision item")
        XCTAssertEqual(old.decisionEpochSeconds, 0, "legacy has no decision timestamp")
    }

    // §A — a FRESH heartbeat (recent publish time) carrying an OLD decision epoch proves the two freshnesses are
    // independent: the heartbeat is fresh, but the decision's own TTL has expired.
    func testFreshHeartbeatCanCarryAnExpiredDecision() {
        let now = 1000.0
        let beat = GuardianObservationHeartbeatV1(epochSeconds: now - 0.2, sequence: 5, surfaceRaw: "GUARDIAN_ON",
                                                  reasonCodeRaw: "x", broadcasting: true,
                                                  itemIdentityRevision: 7, decisionEpochSeconds: now - 30.0,
                                                  currentItemIdentityRevision: 7)
        // The heartbeat itself is fresh (publish 0.2s ago)...
        XCTAssertTrue(GuardianObservationHeartbeatBridgeV1.isFresh(beat, nowEpoch: now))
        // ...but the decision's own age (30s) is far outside the 3s window → the app must treat the decision as stale.
        let decisionAge = now - beat.decisionEpochSeconds
        XCTAssertGreaterThan(decisionAge, GuardianObservationHeartbeatBridgeV1.freshnessWindowSeconds,
                             "a fresh heartbeat does NOT make a 30s-old decision fresh (§A)")
    }
}
