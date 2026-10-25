//
//  LocalLearningEngineTests.swift — §8 PROOF for PERSONAL LEARNING V1 (§3-6): the proposal engine + the durable
//  store + the real behaviour-change chain. Deterministic (caller-supplied day index). XCTest.
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class LocalLearningEngineTests: XCTestCase {

    private func textRule(_ id: String, _ action: ShieldAction = .hideIfControlled) -> ShieldRuleV2 {
        ShieldRuleV2(ruleID: id, inputType: .textExact, rawUserLabel: "x", locale: "en", action: action,
                     createdAtEpoch: 1, updatedAtEpoch: 1)
    }
    private func sig(_ rule: String, _ kind: LearningSignalKindV1, content: String?, day: Int = 0) -> LearningExplicitSignalV1 {
        LearningExplicitSignalV1(ruleID: rule, kind: kind,
                                 contentToken: content.map { LearningExplicitSignalV1.contentToken(from: $0) }, dayStamp: day)
    }

    // MARK: §3.1 — a SINGLE override makes NO silent change and produces NO proposal.

    func testSingleOverrideMakesNoProposal() {
        let e = LocalLearningProposalEngineV1(baseThreshold: 3, strictThreshold: 5)
        e.ingest(sig("r1", .showAnyway, content: "reel-1"), enabled: true)
        let p = e.computeProposal(for: textRule("r1"), nowDay: 0, policyRevision: 1)
        XCTAssertNil(p, "one override is never a decisive preference → NO proposal (§3.1/§3.4)")
    }

    // MARK: §3.1 — repeated taps on the SAME content collapse (not independent evidence).

    func testSameContentRepeatsCollapse() {
        let e = LocalLearningProposalEngineV1(baseThreshold: 3, strictThreshold: 5)
        for _ in 0..<10 { e.ingest(sig("r1", .showAnyway, content: "reel-1"), enabled: true) }   // same reel x10
        XCTAssertEqual(e.independentEvidence(ruleID: "r1", direction: .loosen), 1,
                       "same-content repeats collapse to ONE independent unit (§3.1)")
        XCTAssertNil(e.computeProposal(for: textRule("r1"), nowDay: 0, policyRevision: 1))
    }

    // MARK: §3 — ≥3 INDEPENDENT signals on DISTINCT content produce ONE explainable proposal.

    func testThreeDistinctContentSignalsProduceProposal() {
        let e = LocalLearningProposalEngineV1(baseThreshold: 3, strictThreshold: 5)
        e.ingest(sig("r1", .showAnyway, content: "reel-1"), enabled: true)
        e.ingest(sig("r1", .showAnyway, content: "reel-2"), enabled: true)
        e.ingest(sig("r1", .warningNotHelpful, content: "reel-3"), enabled: true)
        XCTAssertEqual(e.independentEvidence(ruleID: "r1", direction: .loosen), 3)
        let p = e.computeProposal(for: textRule("r1", .hideIfControlled), nowDay: 0, policyRevision: 7)
        XCTAssertNotNil(p, "3 distinct-content loosen signals → a proposal (§3)")
        XCTAssertEqual(p?.direction, .loosen)
        XCTAssertEqual(p?.currentAction, .hideIfControlled)
        XCTAssertEqual(p?.proposedAction, .ask, "a strong HIDE loosens one conservative step to ASK (not straight to ALLOW)")
        XCTAssertEqual(p?.independentEvidenceCount, 3)
        XCTAssertFalse(p?.reason.isEmpty ?? true, "the proposal carries a human-readable reason (no raw media)")
    }

    // MARK: §3.4 — CONFLICTING directions (both at threshold) → NO confident proposal.

    func testConflictingEvidenceSuppressesProposal() {
        // loosen floor = base(2); tighten floor = strict(2, clamped to base+1 = 3). Give both directions enough to be
        // READY at their OWN floor, so the result is ambiguous and MUST be suppressed.
        let e = LocalLearningProposalEngineV1(baseThreshold: 2, strictThreshold: 3)
        e.ingest(sig("r1", .showAnyway, content: "a"), enabled: true)
        e.ingest(sig("r1", .warningNotHelpful, content: "b"), enabled: true)   // loosen x2 (≥ base 2)
        e.ingest(sig("r1", .showLessLikeThis, content: "c"), enabled: true)
        e.ingest(sig("r1", .askBlocked, content: "d"), enabled: true)
        e.ingest(sig("r1", .showLessLikeThis, content: "e"), enabled: true)    // tighten x3 (≥ strict 3)
        let p = e.computeProposal(for: textRule("r1", .warn), nowDay: 0, policyRevision: 1)
        XCTAssertNil(p, "confident evidence in BOTH directions is ambiguous → no proposal (§3.4)")
    }

    // MARK: §3.4 — high-impact (tighten) uses the STRICTER threshold.

    func testTightenUsesStricterThreshold() {
        let e = LocalLearningProposalEngineV1(baseThreshold: 3, strictThreshold: 5)
        // 4 distinct tighten signals — enough for base(3) but NOT for strict(5).
        for i in 0..<4 { e.ingest(sig("r1", .showLessLikeThis, content: "c\(i)"), enabled: true) }
        XCTAssertNil(e.computeProposal(for: textRule("r1", .warn), nowDay: 0, policyRevision: 1),
                     "tightening needs the stricter threshold (§3.4)")
        e.ingest(sig("r1", .showLessLikeThis, content: "c4"), enabled: true)   // now 5
        XCTAssertNotNil(e.computeProposal(for: textRule("r1", .warn), nowDay: 0, policyRevision: 1))
    }

    // MARK: §4/§6 — learning OFF ⇒ ZERO new persistent signals.

    func testLearningOffProducesNoSignals() {
        let e = LocalLearningProposalEngineV1(baseThreshold: 2, strictThreshold: 2)
        for i in 0..<5 { e.ingest(sig("r1", .showAnyway, content: "c\(i)"), enabled: false) }   // learning OFF
        XCTAssertEqual(e.independentEvidence(ruleID: "r1", direction: .loosen), 0, "learning OFF → no evidence (§4/§6)")
        XCTAssertNil(e.computeProposal(for: textRule("r1"), nowDay: 0, policyRevision: 1))
    }

    // MARK: §3.2 — reject preserves behaviour; accept + undo flip status (the inverse patch is retained).

    func testAcceptRejectUndoLifecycle() {
        let e = LocalLearningProposalEngineV1(baseThreshold: 2, strictThreshold: 2)
        e.ingest(sig("r1", .showAnyway, content: "a"), enabled: true)
        e.ingest(sig("r1", .showAnyway, content: "b"), enabled: true)
        let pending = e.refresh(rules: [textRule("r1", .hideIfControlled)], nowDay: 0, policyRevision: 1)
        XCTAssertEqual(pending.count, 1)
        let id = pending[0].proposalID
        let accepted = e.accept(proposalID: id)
        XCTAssertEqual(accepted?.status, .accepted)
        XCTAssertEqual(accepted?.currentAction, .hideIfControlled)
        XCTAssertEqual(accepted?.proposedAction, .ask, "the inverse patch is (ask → hideIfControlled) for undo")
        let undone = e.markUndone(proposalID: id)
        XCTAssertEqual(undone?.status, .undone, "undo flips status; the app restores currentAction via the inverse patch (§5)")
    }

    // MARK: §4/§6 — reset clears learning history (aggregates + proposals).

    func testResetClearsHistory() {
        let e = LocalLearningProposalEngineV1(baseThreshold: 2, strictThreshold: 2)
        e.ingest(sig("r1", .showAnyway, content: "a"), enabled: true)
        e.ingest(sig("r1", .showAnyway, content: "b"), enabled: true)
        _ = e.refresh(rules: [textRule("r1")], nowDay: 0, policyRevision: 1)
        XCTAssertGreaterThan(e.proposalCount + e.aggregateCount, 0)
        e.resetLearningHistory()
        XCTAssertEqual(e.proposalCount, 0); XCTAssertEqual(e.aggregateCount, 0)
    }

    // MARK: §3.3/§6 — the DURABLE proposal record carries NO raw media (schema test).

    func testProposalRecordHasNoRawMedia() throws {
        let p = LearningProposalV1(proposalID: "p1", ruleID: "r1", direction: .loosen,
                                   signalKinds: [.showAnyway], independentEvidenceCount: 3,
                                   currentAction: .hideIfControlled, proposedAction: .ask,
                                   reason: "3 bağımsız geri bildirim", status: .pending, createdDay: 0,
                                   retentionDays: 30, producedUnderPolicyRevision: 1)
        let data = try JSONEncoder().encode(p)
        let json = String(data: data, encoding: .utf8) ?? ""
        // The schema has NO field for raw ocr/audio/transcript/screenshot or content-id history (§3.3).
        for banned in ["ocr", "transcript", "screenshot", "rawText", "contentID", "contentId"] {
            XCTAssertFalse(json.contains(banned), "durable proposal must not carry '\(banned)' (§3.3/§6)")
        }
    }

    // MARK: §6 — the durable STORE: save/load round-trip, deletion really clears, corrupt data recovers honestly.

    func testStoreRoundTripDeletionAndCorruptRecovery() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("learnstore-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = LocalLearningStoreV1(directory: dir)
        let payload = LocalLearningPersistentV1(learningEnabled: true, consentShown: true,
                                                proposals: [LearningProposalV1(proposalID: "p1", ruleID: "r1",
                                                    direction: .loosen, signalKinds: [.showAnyway],
                                                    independentEvidenceCount: 3, currentAction: .hideIfControlled,
                                                    proposedAction: .ask, reason: "r", status: .pending, createdDay: 0,
                                                    retentionDays: 30, producedUnderPolicyRevision: 1)])
        XCTAssertTrue(store.save(payload))
        XCTAssertTrue(store.load().payload.learningEnabled, "save/load round-trips the toggle")
        XCTAssertEqual(store.load().payload.proposals.count, 1)
        // Corrupt the file → load recovers to EMPTY + flags corruptRecovered (never a crash, never a wrong success).
        try Data("{ not json".utf8).write(to: store.storeURL)
        let bad = store.load()
        XCTAssertTrue(bad.corruptRecovered, "corrupt data is surfaced, not hidden (§6)")
        XCTAssertFalse(bad.payload.learningEnabled, "corrupt → empty default (never a silently-wrong success)")
        // Deletion really clears.
        XCTAssertTrue(store.save(payload)); XCTAssertTrue(store.fileExists)
        XCTAssertTrue(store.resetAll()); XCTAssertFalse(store.fileExists, "deletion really clears the file (§6)")
    }

    // MARK: §5 (engine half) — an ACCEPTED proposal is produced under the live policy revision (traceability).

    func testProposalCarriesProducingPolicyRevision() {
        let e = LocalLearningProposalEngineV1(baseThreshold: 2, strictThreshold: 2)
        e.ingest(sig("r1", .showAnyway, content: "a"), enabled: true)
        e.ingest(sig("r1", .showAnyway, content: "b"), enabled: true)
        let p = e.computeProposal(for: textRule("r1", .hideIfControlled), nowDay: 0, policyRevision: 42)
        XCTAssertEqual(p?.producedUnderPolicyRevision, 42, "the proposal records the policy revision it was formed under")
    }
}
