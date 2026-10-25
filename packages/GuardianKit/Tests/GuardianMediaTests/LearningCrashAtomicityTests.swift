//
//  LearningCrashAtomicityTests.swift — 1F PROOF: the Personal Learning "accept" is crash-atomic across its three
//  separate durable writes (rule file, policy revision, learning store). Each test injects a FAILURE POINT that
//  simulates a process kill at an exact seam, then constructs a FRESH coordinator ("relaunch") and runs recovery —
//  asserting the accept is whole-or-nothing with ZERO half-applied state and an idempotent re-accept guard.
//
//  Headless/XCTest over the GuardianMedia primitives (the coordinator + the pure recovery resolver + the real stores).
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class LearningCrashAtomicityTests: XCTestCase {

    // A tiny in-memory stand-in for the app's learning payload persistence. The coordinator calls `persist`; we record
    // the undo patch + an "accepted" snapshot so a "relaunch" (new engine restored from this) is faithful.
    private final class FakeLearningPersistence {
        var lastUndoPatch: LearningUndoPatchV1?
        var persistCalls = 0
        var failPersist = false
        func persist(_ patch: LearningUndoPatchV1?) -> Bool {
            persistCalls += 1
            if failPersist { return false }
            lastUndoPatch = patch
            return true
        }
    }

    private func makeShield() -> (PersonalShieldSharedStoreV1, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lca-\(UUID().uuidString)")
        let suite = UserDefaults(suiteName: "lca.\(UUID().uuidString)")!
        return (PersonalShieldSharedStoreV1(directory: dir, suite: suite, sharedContainerActive: true), dir)
    }
    private func makeLearningStore() -> (LocalLearningStoreV1, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lcl-\(UUID().uuidString)")
        return (LocalLearningStoreV1(directory: dir), dir)
    }
    private func textRule(_ id: String, _ action: ShieldAction) -> ShieldRuleV2 {
        ShieldRuleV2(ruleID: id, inputType: .textExact, rawUserLabel: "spoiler", locale: "en", action: action,
                     createdAtEpoch: 1, updatedAtEpoch: 1)
    }

    // Build an engine whose single rule has ≥ enough distinct-content LOOSEN evidence to yield a pending proposal
    // (HIDE → ASK). Returns the engine with exactly one pending proposal for rule r1.
    private func engineWithPendingLoosen(rule: ShieldRuleV2, policyRevision: UInt64) -> (LocalLearningProposalEngineV1, LearningProposalV1) {
        let engine = LocalLearningProposalEngineV1(baseThreshold: 3, retentionDays: 30)
        for i in 0..<3 {
            engine.ingest(LearningExplicitSignalV1(ruleID: rule.ruleID, kind: .showAnyway,
                                                   contentToken: "c\(i)", dayStamp: 10), enabled: true)
        }
        let pending = engine.refresh(rules: [rule], nowDay: 10, policyRevision: policyRevision)
        return (engine, pending.first!)
    }

    // MARK: - Happy path: a clean accept leaves NO intent on disk (whole, nothing to recover).

    func testCleanAcceptLeavesNoIntent() throws {
        let (shield, sdir) = makeShield(); defer { try? FileManager.default.removeItem(at: sdir) }
        let (lstore, ldir) = makeLearningStore(); defer { try? FileManager.default.removeItem(at: ldir) }
        let rev0 = try shield.saveRules([textRule("r1", .hideIfControlled)])
        let (engine, prop) = engineWithPendingLoosen(rule: textRule("r1", .hideIfControlled), policyRevision: rev0)
        let coord = LocalLearningAcceptCoordinatorV1(shieldStore: shield, learningStore: lstore, engine: engine)
        let fake = FakeLearningPersistence()

        let outcome = coord.accept(proposalID: prop.proposalID, nowEpoch: 1, persist: fake.persist)
        guard case .applied(let newRev, _) = outcome else { return XCTFail("expected applied, got \(outcome)") }
        XCTAssertEqual(newRev, rev0 + 1)
        XCTAssertEqual(shield.loadPolicy().rules.first?.action, .ask, "the rule really moved HIDE→ASK")
        XCTAssertFalse(lstore.intentExists, "a clean accept clears the write-ahead intent (whole)")
        XCTAssertNotNil(fake.lastUndoPatch, "the undo patch was persisted")
    }

    // MARK: - Scenario: crash AFTER intent, BEFORE the rule write (nothing applied) → clean ROLLBACK.

    func testCrashAfterIntentBeforeRuleWriteRollsBack() throws {
        let (shield, sdir) = makeShield(); defer { try? FileManager.default.removeItem(at: sdir) }
        let (lstore, ldir) = makeLearningStore(); defer { try? FileManager.default.removeItem(at: ldir) }
        let rev0 = try shield.saveRules([textRule("r1", .hideIfControlled)])
        let (engine, prop) = engineWithPendingLoosen(rule: textRule("r1", .hideIfControlled), policyRevision: rev0)
        let coord = LocalLearningAcceptCoordinatorV1(shieldStore: shield, learningStore: lstore, engine: engine)
        let fake = FakeLearningPersistence()

        let outcome = coord.accept(proposalID: prop.proposalID, nowEpoch: 1, persist: fake.persist,
                                   failAt: .afterIntentBeforeRuleWrite)
        XCTAssertEqual(outcome, .interruptedAtFailurePoint)
        XCTAssertTrue(lstore.intentExists, "the write-ahead intent is on disk for recovery")
        XCTAssertEqual(shield.loadPolicy().rules.first?.action, .hideIfControlled, "nothing applied yet")

        // "Relaunch": a fresh engine (same pending proposal, not accepted) + a fresh coordinator run recovery.
        let (engine2, _) = engineWithPendingLoosen(rule: textRule("r1", .hideIfControlled), policyRevision: shield.policyRevision)
        let coord2 = LocalLearningAcceptCoordinatorV1(shieldStore: shield, learningStore: lstore, engine: engine2)
        let fake2 = FakeLearningPersistence()
        let rec = coord2.recoverInFlightAccept(nowEpoch: 2, persist: fake2.persist)
        XCTAssertEqual(rec, .rolledBack(proposalID: prop.proposalID))
        XCTAssertEqual(shield.loadPolicy().rules.first?.action, .hideIfControlled, "rollback: rule still HIDE")
        XCTAssertEqual(shield.policyRevision, rev0, "rollback: revision unchanged")
        XCTAssertFalse(lstore.intentExists, "recovery cleared the intent")
        XCTAssertTrue(engine2.pendingProposals.contains { $0.proposalID == prop.proposalID },
                      "the proposal stays PENDING after a clean rollback")
    }

    // MARK: - Scenario 1: rule file written, revision NOT bumped (crash inside the CAS) → recovery ROLLS FORWARD.

    func testScenario1RuleWrittenRevisionStaleCompletes() throws {
        let (shield, sdir) = makeShield(); defer { try? FileManager.default.removeItem(at: sdir) }
        let (lstore, ldir) = makeLearningStore(); defer { try? FileManager.default.removeItem(at: ldir) }
        let rev0 = try shield.saveRules([textRule("r1", .hideIfControlled)])
        let (engine, prop) = engineWithPendingLoosen(rule: textRule("r1", .hideIfControlled), policyRevision: rev0)
        let coord = LocalLearningAcceptCoordinatorV1(shieldStore: shield, learningStore: lstore, engine: engine)
        let fake = FakeLearningPersistence()

        let outcome = coord.accept(proposalID: prop.proposalID, nowEpoch: 1, persist: fake.persist,
                                   failAt: .afterRuleWriteBeforeRevisionBump)
        XCTAssertEqual(outcome, .interruptedAtFailurePoint)
        // Disk state: rule MOVED to ASK, but the revision was rolled back to the stale value (the crash state).
        XCTAssertEqual(shield.loadPolicy().rules.first?.action, .ask, "rule file was written")
        XCTAssertEqual(shield.policyRevision, rev0, "revision is STALE (not bumped) — the Scenario-1 disk state")
        XCTAssertTrue(lstore.intentExists)

        // Relaunch + recovery: roll forward — bump the revision, mark accepted, persist the undo patch.
        let (engine2, _) = engineWithPendingLoosen(rule: textRule("r1", .hideIfControlled), policyRevision: rev0)
        let coord2 = LocalLearningAcceptCoordinatorV1(shieldStore: shield, learningStore: lstore, engine: engine2)
        let fake2 = FakeLearningPersistence()
        let rec = coord2.recoverInFlightAccept(nowEpoch: 2, persist: fake2.persist)
        guard case .completed(let pid, let patch) = rec else { return XCTFail("expected completed, got \(rec)") }
        XCTAssertEqual(pid, prop.proposalID)
        XCTAssertEqual(shield.loadPolicy().rules.first?.action, .ask, "rule stays ASK (the applied change)")
        XCTAssertEqual(shield.policyRevision, rev0 + 1, "recovery bumped the revision to a consistent value")
        XCTAssertEqual(patch.priorAction, .hideIfControlled, "undo restores HIDE")
        XCTAssertEqual(patch.appliedAction, .ask)
        XCTAssertFalse(lstore.intentExists, "recovery cleared the intent")
        XCTAssertNotNil(fake2.lastUndoPatch, "undo is available post-recovery (A2 survives the crash)")
    }

    // MARK: - Scenario 2/3: rule + revision committed, learning store NOT persisted → recovery COMPLETES accept-only.

    func testScenario2RevisionAdvancedProposalUnsavedCompletes() throws {
        let (shield, sdir) = makeShield(); defer { try? FileManager.default.removeItem(at: sdir) }
        let (lstore, ldir) = makeLearningStore(); defer { try? FileManager.default.removeItem(at: ldir) }
        let rev0 = try shield.saveRules([textRule("r1", .hideIfControlled)])
        let (engine, prop) = engineWithPendingLoosen(rule: textRule("r1", .hideIfControlled), policyRevision: rev0)
        let coord = LocalLearningAcceptCoordinatorV1(shieldStore: shield, learningStore: lstore, engine: engine)
        let fake = FakeLearningPersistence()

        let outcome = coord.accept(proposalID: prop.proposalID, nowEpoch: 1, persist: fake.persist,
                                   failAt: .afterRevisionBumpBeforeLearningStore)
        XCTAssertEqual(outcome, .interruptedAtFailurePoint)
        XCTAssertEqual(shield.loadPolicy().rules.first?.action, .ask, "rule + revision are committed")
        XCTAssertEqual(shield.policyRevision, rev0 + 1, "revision advanced")
        XCTAssertEqual(fake.persistCalls, 0, "the learning store was NOT persisted (the crash seam)")
        XCTAssertTrue(lstore.intentExists)
        // The intent must be at .ruleWritten with the applied revision recorded.
        let saved = try XCTUnwrap(lstore.readAcceptIntent())
        XCTAssertEqual(saved.phase, .ruleWritten)
        XCTAssertEqual(saved.appliedRevision, rev0 + 1)

        // Relaunch (proposal NOT yet accepted in the restored engine) + recovery completes the learning-store write.
        let (engine2, _) = engineWithPendingLoosen(rule: textRule("r1", .hideIfControlled), policyRevision: rev0)
        let coord2 = LocalLearningAcceptCoordinatorV1(shieldStore: shield, learningStore: lstore, engine: engine2)
        let fake2 = FakeLearningPersistence()
        let rec = coord2.recoverInFlightAccept(nowEpoch: 2, persist: fake2.persist)
        guard case .completed(_, let patch) = rec else { return XCTFail("expected completed, got \(rec)") }
        XCTAssertEqual(patch.appliedUnderRevision, rev0 + 1, "undo patch binds to the committed revision")
        XCTAssertEqual(shield.policyRevision, rev0 + 1, "no double-bump — revision stays consistent")
        XCTAssertTrue(engine2.allProposals.contains { $0.proposalID == prop.proposalID && $0.status == .accepted },
                      "the proposal is now recorded accepted (completed forward)")
        XCTAssertFalse(lstore.intentExists)
    }

    // MARK: - Scenario 4: double-accept / idempotent re-accept guard.
    // After a clean accept, a stale intent for the SAME proposal (e.g. a re-issued accept that crashed) recovers as
    // ALREADY COMPLETE and never double-applies or double-bumps.

    func testScenario4DoubleAcceptIsIdempotent() throws {
        let (shield, sdir) = makeShield(); defer { try? FileManager.default.removeItem(at: sdir) }
        let (lstore, ldir) = makeLearningStore(); defer { try? FileManager.default.removeItem(at: ldir) }
        let rev0 = try shield.saveRules([textRule("r1", .hideIfControlled)])
        let (engine, prop) = engineWithPendingLoosen(rule: textRule("r1", .hideIfControlled), policyRevision: rev0)
        let coord = LocalLearningAcceptCoordinatorV1(shieldStore: shield, learningStore: lstore, engine: engine)
        let fake = FakeLearningPersistence()

        // First, a clean accept (rule → ASK, revision bumped, proposal accepted).
        guard case .applied(let rev1, _) = coord.accept(proposalID: prop.proposalID, nowEpoch: 1, persist: fake.persist)
        else { return XCTFail("first accept should apply") }
        XCTAssertEqual(rev1, rev0 + 1)

        // Now simulate a stale/duplicate intent on disk for the SAME proposal at phase .ruleWritten (as if a second
        // accept attempt had crashed after the rule write). The engine already has it accepted (idempotency input).
        let staleIntent = LearningAcceptIntentV1(proposalID: prop.proposalID, ruleID: "r1",
                                                 fromAction: .hideIfControlled, toAction: .ask,
                                                 expectedRevision: rev0, phase: .ruleWritten,
                                                 startedAtEpoch: 1, appliedRevision: rev1)
        _ = lstore.writeAcceptIntent(staleIntent)

        let rec = coord.recoverInFlightAccept(nowEpoch: 2, persist: fake.persist)
        XCTAssertEqual(rec, .alreadyComplete(proposalID: prop.proposalID), "a double-accept recovers as already complete")
        XCTAssertEqual(shield.policyRevision, rev1, "no second bump — idempotent (no double-apply)")
        XCTAssertEqual(shield.loadPolicy().rules.first?.action, .ask, "rule unchanged by the idempotent recovery")
        XCTAssertFalse(lstore.intentExists)
    }

    // MARK: - Guard: a user hand-edit after the crash point is NEVER clobbered by recovery (abandon).

    func testRecoveryAbandonsWhenUserHandEditedRule() throws {
        let (shield, sdir) = makeShield(); defer { try? FileManager.default.removeItem(at: sdir) }
        let (lstore, ldir) = makeLearningStore(); defer { try? FileManager.default.removeItem(at: ldir) }
        let rev0 = try shield.saveRules([textRule("r1", .hideIfControlled)])
        let (engine, prop) = engineWithPendingLoosen(rule: textRule("r1", .hideIfControlled), policyRevision: rev0)
        let coord = LocalLearningAcceptCoordinatorV1(shieldStore: shield, learningStore: lstore, engine: engine)
        let fake = FakeLearningPersistence()

        _ = coord.accept(proposalID: prop.proposalID, nowEpoch: 1, persist: fake.persist,
                         failAt: .afterRevisionBumpBeforeLearningStore)
        XCTAssertTrue(lstore.intentExists)
        // The user hand-edits the rule to WARN before the recovery runs (a different value than the intent's `to`).
        _ = try shield.saveRules([textRule("r1", .warn)])
        let revAfterEdit = shield.policyRevision

        let rec = coord.recoverInFlightAccept(nowEpoch: 2, persist: fake.persist)
        XCTAssertEqual(rec, .abandoned(proposalID: prop.proposalID), "recovery abandons rather than clobber a user edit")
        XCTAssertEqual(shield.loadPolicy().rules.first?.action, .warn, "the user's WARN is preserved (never overwritten)")
        XCTAssertEqual(shield.policyRevision, revAfterEdit, "recovery did not touch the revision")
        XCTAssertFalse(lstore.intentExists)
    }

    // MARK: - Pure resolver exhaustiveness (the 4 scenarios map directly onto the pure decision).

    func testPureResolverCovers4Scenarios() {
        let base = LearningAcceptIntentV1(proposalID: "p", ruleID: "r", fromAction: .hideIfControlled,
                                          toAction: .ask, expectedRevision: 5, phase: .intentRecorded, startedAtEpoch: 0)
        // Scenario 1: rule at `to`, revision stale → bump-then-accept.
        XCTAssertEqual(LearningAcceptRecoveryV1.resolve(intent: base, currentRuleAction: .ask, liveRevision: 5,
                                                        proposalAlreadyAccepted: false), .completeBumpRevisionThenAccept)
        // Scenario 2/3: ruleWritten phase, not yet accepted → complete accept-only.
        var rw = base; rw.phase = .ruleWritten; rw.appliedRevision = 6
        XCTAssertEqual(LearningAcceptRecoveryV1.resolve(intent: rw, currentRuleAction: .ask, liveRevision: 6,
                                                        proposalAlreadyAccepted: false), .completeAcceptOnly(appliedRevision: 6))
        // Scenario 4: already accepted → already complete.
        XCTAssertEqual(LearningAcceptRecoveryV1.resolve(intent: rw, currentRuleAction: .ask, liveRevision: 6,
                                                        proposalAlreadyAccepted: true), .alreadyComplete)
        // Clean rollback: rule still at `from`, revision unmoved.
        XCTAssertEqual(LearningAcceptRecoveryV1.resolve(intent: base, currentRuleAction: .hideIfControlled, liveRevision: 5,
                                                        proposalAlreadyAccepted: false), .rollBackNothingApplied)
        // Abandon: rule at some other action (user edit).
        XCTAssertEqual(LearningAcceptRecoveryV1.resolve(intent: base, currentRuleAction: .warn, liveRevision: 6,
                                                        proposalAlreadyAccepted: false), .abandonDoNotClobber)
        // Abandon: rule deleted.
        XCTAssertEqual(LearningAcceptRecoveryV1.resolve(intent: base, currentRuleAction: nil, liveRevision: 5,
                                                        proposalAlreadyAccepted: false), .abandonDoNotClobber)
        // Defensive: a .ruleWritten intent MISSING its appliedRevision is abandoned (never bound to a guessed revision).
        var rwNoRev = base; rwNoRev.phase = .ruleWritten; rwNoRev.appliedRevision = nil
        XCTAssertEqual(LearningAcceptRecoveryV1.resolve(intent: rwNoRev, currentRuleAction: .ask, liveRevision: 9,
                                                        proposalAlreadyAccepted: false), .abandonDoNotClobber)
    }

    // MARK: - resetAll clears a pending intent (a wipe cancels recovery).

    func testResetAllClearsIntent() throws {
        let (lstore, ldir) = makeLearningStore(); defer { try? FileManager.default.removeItem(at: ldir) }
        let intent = LearningAcceptIntentV1(proposalID: "p", ruleID: "r", fromAction: .warn, toAction: .ask,
                                            expectedRevision: 1, startedAtEpoch: 0)
        XCTAssertTrue(lstore.writeAcceptIntent(intent))
        XCTAssertTrue(lstore.intentExists)
        _ = lstore.resetAll()
        XCTAssertFalse(lstore.intentExists, "resetAll removes any in-flight intent")
    }

    // MARK: - A corrupt intent is treated as nothing-to-recover (never crashes).

    func testCorruptIntentIsNil() throws {
        let (lstore, ldir) = makeLearningStore(); defer { try? FileManager.default.removeItem(at: ldir) }
        try Data("not json".utf8).write(to: lstore.intentStoreURL)
        XCTAssertNil(lstore.readAcceptIntent(), "a corrupt intent decodes to nil (honest, never a crash)")
        XCTAssertFalse(lstore.intentExists, "and is removed so it cannot be re-read")
    }
}
