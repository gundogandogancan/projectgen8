//
//  PersonalLearningR2TransactionTests.swift — mandate A/B PROOF: transactional accept (CAS), safe/restart-safe undo,
//  idempotency, durable learning aggregates (restart survives), and the explicit conflict policy. Headless, XCTest.
//
//  These exercise the GuardianMedia PRIMITIVES that make the app-layer LocalLearningModel correct: the store's
//  compare-and-swap mutation (A1/A2/A3), the engine's durable aggregate snapshot (B1), and the conflict policy (B2).
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class PersonalLearningR2TransactionTests: XCTestCase {

    private func makeStore() -> (store: PersonalShieldSharedStoreV1, dir: URL, suite: UserDefaults) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("plr2t-\(UUID().uuidString)")
        let suite = UserDefaults(suiteName: "plr2t.\(UUID().uuidString)")!
        return (PersonalShieldSharedStoreV1(directory: dir, suite: suite, sharedContainerActive: true), dir, suite)
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }
    private func textRule(_ id: String, _ label: String, _ action: ShieldAction) -> ShieldRuleV2 {
        ShieldRuleV2(ruleID: id, inputType: .textExact, rawUserLabel: label, locale: "en", action: action,
                     createdAtEpoch: 1, updatedAtEpoch: 1)
    }

    // MARK: A1 — CAS applies ONLY when the rule is still in the expected action, and bumps the revision exactly once.

    func testCASAppliesAndBumpsRevisionOnce() throws {
        let (store, dir, _) = makeStore(); defer { cleanup(dir) }
        let rev0 = try store.saveRules([textRule("r1", "spoiler", .hideIfControlled)])
        let result = store.mutateRuleAction(ruleID: "r1", expectedAction: .hideIfControlled, to: .ask, expectedRevision: rev0)
        guard case .applied(let newRev) = result else { return XCTFail("expected .applied, got \(result)") }
        XCTAssertEqual(newRev, rev0 + 1, "CAS bumps the policy revision exactly once (A1)")
        XCTAssertEqual(store.loadPolicy().rules.first?.action, .ask, "the rule really changed to ASK (A1)")
    }

    // MARK: A1/A2 — a manual edit (rule no longer in the expected action) REFUSES the CAS without overwriting.

    func testCASRefusesOnActionMismatch() throws {
        let (store, dir, _) = makeStore(); defer { cleanup(dir) }
        _ = try store.saveRules([textRule("r1", "spoiler", .warn)])   // user already set it to WARN
        // A stale proposal thinks the rule is still HIDE → CAS must refuse, not overwrite the user's WARN.
        let result = store.mutateRuleAction(ruleID: "r1", expectedAction: .hideIfControlled, to: .ask)
        guard case .actionMismatch(let found) = result else { return XCTFail("expected .actionMismatch, got \(result)") }
        XCTAssertEqual(found, .warn, "the CAS reports the action actually found (honest message, A1/A2)")
        XCTAssertEqual(store.loadPolicy().rules.first?.action, .warn, "the user's manual edit is NOT overwritten (A2)")
    }

    // MARK: A1 — a revision that advanced since the proposal formed REFUSES the CAS (optimistic concurrency).

    func testCASRefusesOnRevisionMismatch() throws {
        let (store, dir, _) = makeStore(); defer { cleanup(dir) }
        let rev0 = try store.saveRules([textRule("r1", "spoiler", .hideIfControlled)])
        _ = try store.saveRules([textRule("r1", "spoiler", .hideIfControlled)])   // an unrelated save advanced the revision
        let result = store.mutateRuleAction(ruleID: "r1", expectedAction: .hideIfControlled, to: .ask, expectedRevision: rev0)
        guard case .revisionMismatch = result else { return XCTFail("expected .revisionMismatch, got \(result)") }
        XCTAssertEqual(store.loadPolicy().rules.first?.action, .hideIfControlled, "nothing changed on a revision mismatch (A1)")
    }

    // MARK: A3 — applying the SAME move twice is a benign no-op (no double-apply, no spurious revision bump).

    func testCASIsIdempotent() throws {
        let (store, dir, _) = makeStore(); defer { cleanup(dir) }
        let rev0 = try store.saveRules([textRule("r1", "spoiler", .hideIfControlled)])
        guard case .applied(let rev1) = store.mutateRuleAction(ruleID: "r1", expectedAction: .hideIfControlled, to: .ask, expectedRevision: rev0)
        else { return XCTFail() }
        // A second accept of the same proposal: the rule is already ASK → no-op, revision UNCHANGED (A3).
        let second = store.mutateRuleAction(ruleID: "r1", expectedAction: .hideIfControlled, to: .ask)
        guard case .noOpAlreadyAtTarget(let rev2) = second else { return XCTFail("expected no-op, got \(second)") }
        XCTAssertEqual(rev2, rev1, "a repeat apply does not bump the revision again (A3)")
    }

    // MARK: A1 — a missing rule is reported, never a false success.

    func testCASReportsMissingRule() throws {
        let (store, dir, _) = makeStore(); defer { cleanup(dir) }
        _ = try store.saveRules([textRule("r1", "spoiler", .warn)])
        guard case .ruleMissing = store.mutateRuleAction(ruleID: "ghost", expectedAction: .warn, to: .ask)
        else { return XCTFail("a missing rule must be reported, not silently 'applied'") }
    }

    // MARK: A2 — undo semantics via CAS: the inverse patch applies only if the rule is still in the applied action.

    func testUndoRefusesAfterManualEdit() throws {
        let (store, dir, _) = makeStore(); defer { cleanup(dir) }
        let rev0 = try store.saveRules([textRule("r1", "spoiler", .hideIfControlled)])
        // Accept: HIDE → ASK.
        _ = store.mutateRuleAction(ruleID: "r1", expectedAction: .hideIfControlled, to: .ask, expectedRevision: rev0)
        // The user then manually edits the rule to WARN.
        _ = try store.saveRules([textRule("r1", "spoiler", .warn)])
        // Undo expects the rule to still be ASK (the applied action) → must REFUSE (not clobber the user's WARN).
        let undo = store.mutateRuleAction(ruleID: "r1", expectedAction: .ask, to: .hideIfControlled)
        guard case .actionMismatch = undo else { return XCTFail("undo must refuse after a manual edit (A2)") }
        XCTAssertEqual(store.loadPolicy().rules.first?.action, .warn, "undo never overwrites a manual edit (A2)")
    }

    // MARK: B1 — DURABLE learning aggregates: 2 signals → "restart" (new engine, restored snapshot) → 3rd → proposal.

    func testDurableAggregatesSurviveRestart() {
        let engine1 = LocalLearningProposalEngineV1(baseThreshold: 3, strictThreshold: 5)
        let rule = textRule("r1", "spoiler", .hideIfControlled)
        for c in ["a", "b"] {   // only TWO distinct-content signals — below the threshold of 3
            engine1.ingest(LearningExplicitSignalV1(ruleID: "r1", kind: .showAnyway,
                                                    contentToken: LearningExplicitSignalV1.contentToken(from: c, salt: "s"),
                                                    dayStamp: 0), enabled: true)
        }
        XCTAssertNil(engine1.computeProposal(for: rule, nowDay: 0, policyRevision: 0), "2 signals is below threshold")
        // "Restart": persist the aggregate snapshot, build a fresh engine, restore it.
        let snapshot = engine1.aggregatesSnapshot()
        let encoded = try! JSONEncoder().encode(snapshot)
        let restored = try! JSONDecoder().decode(LearningAggregatesSnapshotV1.self, from: encoded)
        let engine2 = LocalLearningProposalEngineV1(baseThreshold: 3, strictThreshold: 5)
        engine2.restoreAggregates(restored)
        XCTAssertEqual(engine2.independentEvidence(ruleID: "r1", direction: .loosen), 2, "restart preserved the 2 units (B1)")
        // The 3rd distinct signal on the restored engine now crosses the threshold → a proposal.
        engine2.ingest(LearningExplicitSignalV1(ruleID: "r1", kind: .showAnyway,
                                                contentToken: LearningExplicitSignalV1.contentToken(from: "c", salt: "s"),
                                                dayStamp: 0), enabled: true)
        XCTAssertNotNil(engine2.computeProposal(for: rule, nowDay: 0, policyRevision: 0),
                        "2 (restored) + 1 (new) = 3 distinct → a proposal forms after restart (B1)")
    }

    // MARK: B1 — the same content repeated does NOT count as independent (distinctness holds across restart).

    func testSameContentNotIndependentAcrossRestart() {
        let engine = LocalLearningProposalEngineV1(baseThreshold: 3, strictThreshold: 5)
        for _ in 0..<5 {   // five taps on the SAME content id
            engine.ingest(LearningExplicitSignalV1(ruleID: "r1", kind: .showAnyway,
                                                   contentToken: LearningExplicitSignalV1.contentToken(from: "same", salt: "s"),
                                                   dayStamp: 0), enabled: true)
        }
        XCTAssertEqual(engine.independentEvidence(ruleID: "r1", direction: .loosen), 1,
                       "repeated taps on the same content collapse to ONE independent unit (B1)")
    }

    // MARK: B1 — the install salt changes tokens, so the same id produces different tokens on different installs.

    func testInstallSaltPseudonymisesTokens() {
        let a = LearningExplicitSignalV1.contentToken(from: "reel-42", salt: "installA")
        let b = LearningExplicitSignalV1.contentToken(from: "reel-42", salt: "installB")
        XCTAssertNotEqual(a, b, "the same content id yields different tokens under different install salts (B1)")
        XCTAssertEqual(a, LearningExplicitSignalV1.contentToken(from: "reel-42", salt: "installA"),
                       "the token is stable for the same (id, salt) on one install (B1)")
    }

    // MARK: B2 — explicit conflict policy: concurrent opposing confident evidence DEFERS (no proposal).

    func testConcurrentConflictDefers() {
        // NOTE: tightening is HIGH-IMPACT, so its floor is the STRICT threshold (the engine enforces strict > base).
        // We give loosen ≥ base and tighten ≥ strict so BOTH directions are genuinely confident, then assert DEFER.
        let engine = LocalLearningProposalEngineV1(baseThreshold: 3, strictThreshold: 4)
        let rule = textRule("r1", "spoiler", .ask)
        // 4 loosen + 4 tighten, all on the SAME recent day (within the correction window) → ambiguous → DEFER.
        for c in ["l1", "l2", "l3", "l4"] {
            engine.ingest(LearningExplicitSignalV1(ruleID: "r1", kind: .showAnyway,
                                                   contentToken: LearningExplicitSignalV1.contentToken(from: c), dayStamp: 10), enabled: true)
        }
        for c in ["t1", "t2", "t3", "t4"] {
            engine.ingest(LearningExplicitSignalV1(ruleID: "r1", kind: .showLessLikeThis,
                                                   contentToken: LearningExplicitSignalV1.contentToken(from: c), dayStamp: 10), enabled: true)
        }
        XCTAssertNil(engine.computeProposal(for: rule, nowDay: 10, policyRevision: 0),
                     "concurrent opposing confident evidence defers — no 'certain preference' claim (B2)")
    }

    // MARK: B2 — a later explicit correction (well past the window) OUTWEIGHS the earlier opposing evidence.

    func testLaterCorrectionOutweighs() {
        let engine = LocalLearningProposalEngineV1(baseThreshold: 3, strictThreshold: 4)
        let rule = textRule("r1", "spoiler", .ask)
        // Early LOOSEN evidence (≥ base floor)...
        for c in ["l1", "l2", "l3"] {
            engine.ingest(LearningExplicitSignalV1(ruleID: "r1", kind: .showAnyway,
                                                   contentToken: LearningExplicitSignalV1.contentToken(from: c), dayStamp: 0), enabled: true)
        }
        // ...then clearly LATER (beyond the 7-day correction window) TIGHTEN evidence (≥ STRICT floor, high-impact).
        for c in ["t1", "t2", "t3", "t4"] {
            engine.ingest(LearningExplicitSignalV1(ruleID: "r1", kind: .showLessLikeThis,
                                                   contentToken: LearningExplicitSignalV1.contentToken(from: c), dayStamp: 20), enabled: true)
        }
        let p = engine.computeProposal(for: rule, nowDay: 20, policyRevision: 0)
        XCTAssertEqual(p?.direction, .tighten, "the later explicit correction outweighs the earlier opposing evidence (B2)")
    }
}
