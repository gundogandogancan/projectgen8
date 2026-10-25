//
//  LocalLearningAcceptCoordinatorV1.swift — 1F: the CRASH-ATOMIC accept + recovery protocol for Personal Learning.
//
//  WHY THIS EXISTS (mandate 1F): accepting a learning proposal spans THREE separate durable writes that are NOT one
//  atomic operation — the shield RULE FILE, the UserDefaults POLICY REVISION, and the LEARNING STORE (proposal marked
//  accepted + the undo patch). A crash between any two leaves a HALF-APPLIED accept. This coordinator wraps those
//  writes with a tiny WRITE-AHEAD INTENT (LearningAcceptIntentV1) and a RECOVERY SCAN so the accept is whole-or-nothing
//  across a crash. It is a small, reliable protocol over the EXISTING stores — NOT a persistence framework.
//
//  DESIGN: all three stores are GuardianMedia types, so this coordinator (and the full protocol) is headless + unit-
//  testable. The app-side LocalLearningModel delegates to it (one accept path, one recovery path). Tests drive it with
//  INJECTED FAILURE POINTS (`FailurePointV1`) that simulate a process kill at the exact gap between two writes, then
//  construct a FRESH coordinator (a "relaunch") and run recovery — proving all 4 mandate crash scenarios converge to a
//  consistent state with zero half-applied accepts and an idempotent re-accept guard.
//
import Foundation
import GuardianCore

/// 1F — the honest, user-facing outcome of a crash-atomic accept attempt (mirrors the store CAS results + adds the
/// in-flight / recovered distinctions so the UI never shows a false success).
public enum LearningAcceptOutcomeV1: Sendable, Equatable {
    case applied(newRevision: UInt64, undoPatch: LearningUndoPatchV1)
    case noOpAlreadyAtTarget
    case ruleMissing
    case actionMismatch(found: ShieldAction)
    case revisionMismatch(found: UInt64)
    case writeFailed
    case notPending
    /// A simulated/real crash fired at an injected failure point — the transaction is INCOMPLETE on disk. Only used in
    /// tests (and defensively if a write-ahead write itself fails); recovery on the next launch resolves it.
    case interruptedAtFailurePoint
}

/// 1F — the result of a recovery scan at launch (what recovery did to make an in-flight accept whole-or-nothing).
public enum LearningRecoveryOutcomeV1: Sendable, Equatable {
    case nothingToRecover
    case rolledBack(proposalID: String)                               // nothing was applied — proposal stays pending
    case completed(proposalID: String, undoPatch: LearningUndoPatchV1) // rolled forward to a consistent applied state
    case abandoned(proposalID: String)                                // world moved on; intent dropped, nothing clobbered
    case alreadyComplete(proposalID: String)                          // idempotent — already fully applied before crash
    /// 2.2 FIX — a roll-forward was attempted but a REQUIRED durable write (the learning-store persist, or the
    /// revision bump) FAILED. The intent is DELIBERATELY LEFT ON DISK (never cleared) so the NEXT launch retries;
    /// we NEVER return `.completed` for a transaction that did not actually land. The rule/revision state is left
    /// exactly as the pure resolver found it (nothing is clobbered). This is the honest "try again" state.
    case incompleteRetryable(proposalID: String)
}

/// 1F — INJECTED FAILURE POINTS (tests only). Each names a gap in the accept sequence where a process kill is
/// simulated: the coordinator performs every write UP TO that point, then returns `.interruptedAtFailurePoint`
/// WITHOUT performing the remaining writes — exactly as a real crash would leave the disk.
public enum LearningAcceptFailurePointV1: Sendable, Equatable {
    case afterIntentBeforeRuleWrite        // intent on disk, rule NOT yet written (clean rollback expected)
    case afterRuleWriteBeforeRevisionBump  // Scenario 1: rule file written, revision NOT bumped
    case afterRevisionBumpBeforeLearningStore // Scenario 2/3: rule + revision committed, learning store NOT persisted
}

public final class LocalLearningAcceptCoordinatorV1: @unchecked Sendable {
    private let shieldStore: PersonalShieldSharedStoreV1
    private let learningStore: LocalLearningStoreV1
    private let engine: LocalLearningProposalEngineV1

    public init(shieldStore: PersonalShieldSharedStoreV1, learningStore: LocalLearningStoreV1,
                engine: LocalLearningProposalEngineV1) {
        self.shieldStore = shieldStore; self.learningStore = learningStore; self.engine = engine
    }

    // MARK: - Accept (crash-atomic)

    /// 1F — accept a pending proposal with a write-ahead intent around the three durable writes. `persist` is the
    /// caller's "persist the full learning payload (proposals + undo patch + aggregates)" closure — the coordinator
    /// does NOT own the payload shape, only the ordering + the intent. `failAt` (tests) simulates a crash at a gap.
    /// `nowEpoch` stamps the intent/undo. Returns the honest outcome; on `.applied` the intent is CLEARED (whole).
    @discardableResult
    public func accept(proposalID: String, nowEpoch: Double,
                       persist: (_ undoPatch: LearningUndoPatchV1?) -> Bool,
                       failAt: LearningAcceptFailurePointV1? = nil) -> LearningAcceptOutcomeV1 {
        guard let p = engine.pendingProposals.first(where: { $0.proposalID == proposalID }) else { return .notPending }

        // WRITE-AHEAD (phase .intentRecorded): record the intent BEFORE touching the rule, so a crash during the CAS
        // leaves evidence of what we were doing. Bind it to the exact rule/action/revision the accept targets.
        let intent = LearningAcceptIntentV1(proposalID: p.proposalID, ruleID: p.ruleID,
                                            fromAction: p.currentAction, toAction: p.proposedAction,
                                            expectedRevision: p.producedUnderPolicyRevision,
                                            phase: .intentRecorded, startedAtEpoch: nowEpoch)
        // 2.1 FIX — the write-ahead intent write is MANDATORY. If the durable intent cannot be recorded we must NOT
        // touch the real Personal Shield rule: a rule change with NO write-ahead evidence can never be recovered (a
        // crash would leave a silently-mutated rule with no undo and no provenance). On failure we abort BEFORE any
        // shield mutation and surface an honest write failure — the proposal stays pending, nothing was applied.
        guard learningStore.writeAcceptIntent(intent) else { return .writeFailed }
        if failAt == .afterIntentBeforeRuleWrite { return .interruptedAtFailurePoint }

        // The real, verified store CAS (rule file + revision). We do NOT get to interpose between its two internal
        // writes here (they live in mutateRuleAction); the `.afterRuleWriteBeforeRevisionBump` failure point is
        // therefore simulated below by UN-DOING the revision bump to reproduce the exact rule-written/revision-stale
        // disk state. This keeps the frozen CAS untouched while still proving Scenario 1 recovers.
        let result = shieldStore.mutateRuleAction(ruleID: p.ruleID, expectedAction: p.currentAction,
                                                  to: p.proposedAction,
                                                  expectedRevision: p.producedUnderPolicyRevision)
        switch result {
        case .applied(let newRev):
            if failAt == .afterRuleWriteBeforeRevisionBump {
                // Reproduce the crash-between-the-two-writes disk state: the rule is at `to`, but the revision was
                // NOT (effectively) bumped. We roll the counter back to the expected value; the intent stays at
                // .intentRecorded so recovery sees "rule changed, revision stale" (Scenario 1).
                shieldStore.setPolicyRevisionForTesting(p.producedUnderPolicyRevision)
                return .interruptedAtFailurePoint
            }
            // Advance the intent to .ruleWritten (rule + revision committed). A crash now → recovery completes forward.
            // 2.1 FIX — this phase-advance write is CHECKED. The rule+revision are already committed; the intent is
            // still durably at .intentRecorded (the pure resolver handles that case: observed live state shows the
            // rule at `to` with the revision advanced → it will complete-accept-only on the next launch). So a failed
            // advance is STILL recoverable — we return an honest interruption instead of a false success. We do NOT
            // proceed to persist/clear, because clearing with a half-recorded intent would strand the committed rule.
            var advanced = intent; advanced.phase = .ruleWritten; advanced.appliedRevision = newRev
            guard learningStore.writeAcceptIntent(advanced) else { return .interruptedAtFailurePoint }
            if failAt == .afterRevisionBumpBeforeLearningStore { return .interruptedAtFailurePoint }

            // The learning-store write (proposal accepted + undo patch). On success the intent is CLEARED (whole).
            _ = engine.accept(proposalID: proposalID)
            let patch = LearningUndoPatchV1(proposalID: p.proposalID, ruleID: p.ruleID,
                                            appliedAction: p.proposedAction, priorAction: p.currentAction,
                                            appliedUnderRevision: newRev)
            guard persist(patch) else {
                // The learning-store write FAILED but the rule+revision are committed: leave the intent at .ruleWritten
                // so the NEXT launch completes the learning-store write. Honest: not a clean success yet.
                return .interruptedAtFailurePoint
            }
            // 2.1 FIX — the intent-clear is CHECKED. If the clear fails the transaction is still fully applied on disk
            // (rule + revision + learning store), so the result IS `.applied`; but a lingering intent would re-run
            // recovery next launch. The pure resolver's idempotency guard makes that recovery a no-op (.alreadyComplete),
            // so a failed clear is harmless — we still report the honest applied outcome (never a false failure either).
            _ = learningStore.clearAcceptIntent()
            return .applied(newRevision: newRev, undoPatch: patch)

        case .noOpAlreadyAtTarget:
            _ = engine.accept(proposalID: proposalID)
            _ = persist(nil)
            _ = learningStore.clearAcceptIntent()
            return .noOpAlreadyAtTarget
        case .ruleMissing:      _ = learningStore.clearAcceptIntent(); return .ruleMissing
        case .actionMismatch(let f): _ = learningStore.clearAcceptIntent(); return .actionMismatch(found: f)
        case .revisionMismatch(let f): _ = learningStore.clearAcceptIntent(); return .revisionMismatch(found: f)
        case .writeFailed:      _ = learningStore.clearAcceptIntent(); return .writeFailed
        }
    }

    // MARK: - Recovery (run once at launch, BEFORE surfacing proposals)

    /// 1F — scan for an in-flight accept intent and make it whole-or-nothing. PURE decision via
    /// LearningAcceptRecoveryV1.resolve; this method only EXECUTES the decision against the real stores. `persist`
    /// persists the learning payload (with the recovered undo patch). Idempotent: safe to call every launch.
    @discardableResult
    public func recoverInFlightAccept(nowEpoch: Double,
                                      persist: (_ undoPatch: LearningUndoPatchV1?) -> Bool) -> LearningRecoveryOutcomeV1 {
        guard let intent = learningStore.readAcceptIntent() else { return .nothingToRecover }
        let liveRevision = shieldStore.policyRevision
        let currentAction = shieldStore.loadPolicy().rules.first(where: { $0.ruleID == intent.ruleID })?.action
        let alreadyAccepted = engine.allProposals.contains {
            $0.proposalID == intent.proposalID && $0.status == .accepted
        }
        let action = LearningAcceptRecoveryV1.resolve(intent: intent, currentRuleAction: currentAction,
                                                      liveRevision: liveRevision,
                                                      proposalAlreadyAccepted: alreadyAccepted)
        switch action {
        case .rollBackNothingApplied:
            _ = learningStore.clearAcceptIntent()
            return .rolledBack(proposalID: intent.proposalID)

        case .completeBumpRevisionThenAccept:
            // Scenario 1 roll-forward: the rule is at `to` but the revision is stale. Bump the revision to match the
            // real rule state, then complete the learning-store write + undo patch under the new revision.
            // 2.2 FIX — the persist is now CHECKED. The revision bump reconciles the rule/revision to a consistent
            // APPLIED state (that part is genuinely done + durable). But the learning-store persist (accepted flag +
            // undo patch) is what makes the recovery WHOLE. If persist FAILS we must NOT clear the intent and must NOT
            // claim `.completed`: we re-stamp the intent to .ruleWritten with the just-bumped revision so the NEXT
            // launch takes the completeAcceptOnly path (idempotent — no second bump), and return a retryable state.
            let newRev = shieldStore.bumpPolicyRevision()
            _ = engine.accept(proposalID: intent.proposalID)
            let patch = LearningUndoPatchV1(proposalID: intent.proposalID, ruleID: intent.ruleID,
                                            appliedAction: intent.toAction, priorAction: intent.fromAction,
                                            appliedUnderRevision: newRev)
            guard persist(patch) else {
                var reStamped = intent; reStamped.phase = .ruleWritten; reStamped.appliedRevision = newRev
                _ = learningStore.writeAcceptIntent(reStamped)   // keep (never clear) so recovery retries next launch
                return .incompleteRetryable(proposalID: intent.proposalID)
            }
            _ = learningStore.clearAcceptIntent()
            return .completed(proposalID: intent.proposalID, undoPatch: patch)

        case .completeAcceptOnly(let appliedRevision):
            // 2.2 FIX — persist CHECKED here too. Rule + revision are already committed; only the learning-store write
            // remains. A failed persist must NOT be reported as completed and the intent must NOT be cleared — leave it
            // at .ruleWritten (it already is) so the next launch retries idempotently (engine.accept is idempotent;
            // proposalAlreadyAccepted may now be true → .alreadyComplete, else completeAcceptOnly again).
            _ = engine.accept(proposalID: intent.proposalID)
            let patch = LearningUndoPatchV1(proposalID: intent.proposalID, ruleID: intent.ruleID,
                                            appliedAction: intent.toAction, priorAction: intent.fromAction,
                                            appliedUnderRevision: appliedRevision)
            guard persist(patch) else { return .incompleteRetryable(proposalID: intent.proposalID) }
            _ = learningStore.clearAcceptIntent()
            return .completed(proposalID: intent.proposalID, undoPatch: patch)

        case .alreadyComplete:
            _ = learningStore.clearAcceptIntent()
            return .alreadyComplete(proposalID: intent.proposalID)

        case .abandonDoNotClobber:
            _ = learningStore.clearAcceptIntent()
            return .abandoned(proposalID: intent.proposalID)
        }
    }
}
