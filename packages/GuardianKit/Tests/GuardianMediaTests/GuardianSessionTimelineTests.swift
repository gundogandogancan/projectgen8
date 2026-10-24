//
//  GuardianSessionTimelineTests.swift — C/D-lane PROOF: the "Bu Oturum" live session timeline is bounded,
//  deduped, session-scoped, TTL-gated and cleared on session end. Pure/headless — exercises the exact
//  writer/reader the SampleHandler + app use. No fabricated events: every event is a value the engine records.
//
import XCTest
@testable import GuardianMedia

final class GuardianSessionTimelineTests: XCTestCase {

    private func writer(_ session: String = "S1", suite: UserDefaults? = nil) -> GuardianSessionTimelineWriterV1 {
        GuardianSessionTimelineWriterV1(sessionID: session, suite: suite)
    }

    // Records advance a monotonic sequence and preserve category/status/reason/revision.
    func testRecordAppendsEventWithRealFields() {
        let w = writer()
        let ev = w.record(category: .sessionStarted, status: .active, reasonCodeRaw: "observingNoDecisionYet",
                          identityRevision: -1, nowEpoch: 100, mirror: false)
        XCTAssertEqual(ev?.sequence, 1)
        XCTAssertEqual(ev?.category, .sessionStarted)
        XCTAssertEqual(ev?.status, .active)
        XCTAssertEqual(ev?.reasonCodeRaw, "observingNoDecisionYet")
        XCTAssertEqual(w.count, 1)
    }

    // DEDUP (mandate F): a run of IDENTICAL events collapses to the first; a change in ANY field is meaningful.
    func testDuplicateEventsAreCollapsed() {
        let w = writer()
        _ = w.record(category: .decision, status: .benign, reasonCodeRaw: "textEvidenceBenign",
                     identityRevision: 1, nowEpoch: 1, mirror: false)
        // Same everything → suppressed.
        XCTAssertNil(w.record(category: .decision, status: .benign, reasonCodeRaw: "textEvidenceBenign",
                              identityRevision: 1, nowEpoch: 2, mirror: false))
        XCTAssertEqual(w.count, 1)
        // Different revision (new content) → recorded.
        XCTAssertNotNil(w.record(category: .decision, status: .benign, reasonCodeRaw: "textEvidenceBenign",
                                 identityRevision: 2, nowEpoch: 3, mirror: false))
        XCTAssertEqual(w.count, 2)
    }

    // A gap/resume is NEVER deduped away even if it repeats — interruption history must be truthful.
    func testGapResumeAreNeverDeduped() {
        let w = writer()
        XCTAssertNotNil(w.record(category: .observationGap, status: .ended, reasonCodeRaw: "sessionNotObserving",
                                 identityRevision: 0, nowEpoch: 1, mirror: false))
        XCTAssertNotNil(w.record(category: .observationGap, status: .ended, reasonCodeRaw: "sessionNotObserving",
                                 identityRevision: 0, nowEpoch: 2, mirror: false))
        XCTAssertEqual(w.count, 2)
    }

    // BOUNDED ring (mandate D): never exceeds capacity; oldest events drop first.
    func testBoundedRingDropsOldest() {
        let w = writer()
        let cap = GuardianSessionTimelineWriterV1.capacity
        for i in 0..<(cap + 20) {
            // Vary the revision so dedup never suppresses — forces real growth against the cap.
            _ = w.record(category: .decision, status: .benign, reasonCodeRaw: "textEvidenceBenign",
                         identityRevision: i, nowEpoch: Double(i), mirror: false)
        }
        XCTAssertEqual(w.count, cap, "the ring must never exceed capacity")
        XCTAssertGreaterThan(w.events.first!.identityRevision, 0, "oldest events were dropped")
    }

    // IPC round-trip: writer mirrors a bounded snapshot; reader decodes it; session+TTL gate the live feed.
    func testMirrorRoundTripSessionAndTTL() throws {
        let suiteName = "test.gen8.timeline.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        let w = writer("SESSION-X", suite: suite)
        _ = w.record(category: .sessionStarted, status: .active, reasonCodeRaw: nil, identityRevision: -1,
                     nowEpoch: 500, mirror: true)
        _ = w.record(category: .newContent, status: .unknown, reasonCodeRaw: "newIdentityUnconfirmed",
                     identityRevision: 0, nowEpoch: 501, mirror: true)

        let snap = try XCTUnwrap(GuardianSessionTimelineReaderV1.readSnapshot(suite: suite))
        XCTAssertEqual(snap.sessionID, "SESSION-X")
        XCTAssertTrue(snap.broadcasting)

        // Matching session, within TTL → the events are live.
        let live = GuardianSessionTimelineReaderV1.liveEvents(snap, expectedSessionID: "SESSION-X", nowEpoch: 502)
        XCTAssertEqual(live.count, 2)

        // Different session → EMPTY feed (a prior session's events are never shown — mandate D).
        XCTAssertTrue(GuardianSessionTimelineReaderV1.liveEvents(snap, expectedSessionID: "SESSION-Y",
                                                                 nowEpoch: 502).isEmpty)
        // Past TTL (crashed broadcast) → EMPTY feed.
        let ttl = GuardianSessionTimelineWriterV1.snapshotTTLSeconds
        XCTAssertTrue(GuardianSessionTimelineReaderV1.liveEvents(snap, expectedSessionID: "SESSION-X",
                                                                 nowEpoch: 500 + ttl + 5).isEmpty)
    }

    // SESSION-END CLEANUP (mandate D): clear() removes BOTH the RAM ring and the IPC mirror — no history survives.
    func testClearRemovesRingAndMirror() throws {
        let suiteName = "test.gen8.timeline.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        let w = writer("SESSION-Z", suite: suite)
        _ = w.record(category: .decision, status: .shieldMatch, reasonCodeRaw: "textEvidenceMatchedShield",
                     identityRevision: 0, nowEpoch: 10, mirror: true)
        XCTAssertNotNil(GuardianSessionTimelineReaderV1.readSnapshot(suite: suite))
        w.clear()
        XCTAssertEqual(w.count, 0, "RAM ring is cleared")
        XCTAssertNil(GuardianSessionTimelineReaderV1.readSnapshot(suite: suite), "IPC mirror is cleared")
    }

    // markFinished writes a broadcasting=false snapshot so the app shows ENDED, never a lingering 'live'.
    func testMarkFinishedSnapshotIsNotBroadcasting() throws {
        let suiteName = "test.gen8.timeline.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        let w = writer("SESSION-F", suite: suite)
        _ = w.record(category: .sessionStarted, status: .active, reasonCodeRaw: nil, identityRevision: -1,
                     nowEpoch: 1, mirror: true)
        w.markFinished(nowEpoch: 2)
        let snap = try XCTUnwrap(GuardianSessionTimelineReaderV1.readSnapshot(suite: suite))
        XCTAssertFalse(snap.broadcasting, "a finished session must publish broadcasting=false")
    }

    // ACCEPTANCE (A→B content switch): a session where content A gets a benign decision, then content B is a NEW
    // item with its own decision — the timeline shows DISTINCT, correctly-ordered real events bound to each
    // identity revision (no cross-content drift). This is the walkthrough the mandate asks to be demonstrable.
    func testAtoBContentSwitchProducesDistinctRealEvents() {
        let w = writer()
        _ = w.record(category: .sessionStarted, status: .active, reasonCodeRaw: "observingNoDecisionYet",
                     identityRevision: -1, nowEpoch: 0, mirror: false)
        // Content A: evidence + benign decision (rev 0).
        _ = w.record(category: .newContent, status: .unknown, reasonCodeRaw: "newIdentityUnconfirmed",
                     identityRevision: 0, nowEpoch: 1, mirror: false)
        _ = w.record(category: .evidenceCaptured, status: .benign, reasonCodeRaw: "textEvidenceBenign",
                     identityRevision: 0, nowEpoch: 2, mirror: false)
        _ = w.record(category: .decision, status: .benign, reasonCodeRaw: "textEvidenceBenign",
                     identityRevision: 0, nowEpoch: 3, mirror: false)
        // Content switches to B: content changed (prior decision invalid) → new decision (rev 1).
        _ = w.record(category: .contentChanged, status: .unknown, reasonCodeRaw: "contentChangedReset",
                     identityRevision: 1, nowEpoch: 4, mirror: false)
        _ = w.record(category: .decision, status: .shieldMatch, reasonCodeRaw: "textEvidenceMatchedShield",
                     identityRevision: 1, nowEpoch: 5, mirror: false)

        let evs = w.events
        // The A decision and the B decision are DISTINCT events bound to different identity revisions.
        let decisions = evs.filter { $0.category == .decision }
        XCTAssertEqual(decisions.count, 2)
        XCTAssertEqual(decisions[0].identityRevision, 0)
        XCTAssertEqual(decisions[0].status, .benign)
        XCTAssertEqual(decisions[1].identityRevision, 1)
        XCTAssertEqual(decisions[1].status, .shieldMatch)
        // A content-changed event sits between them, invalidating A's decision before B's.
        let changeIdx = evs.firstIndex { $0.category == .contentChanged }!
        let bDecisionIdx = evs.firstIndex { $0.category == .decision && $0.identityRevision == 1 }!
        XCTAssertLessThan(changeIdx, bDecisionIdx, "content changed must precede the new decision")
    }
}
