//
//  LocalLearningModel.swift — §3/§4/§5 + R2 A/B: the app-side Personal Learning controller ("Guardian'ım Nasıl Öğreniyor?").
//
//  WHAT THIS IS: the @MainActor @Observable the "How Guardian Learns" screen binds to. It owns the DURABLE learning
//  store + the pure proposal engine (both GuardianMedia types, source-compiled into this app target). It is the ONE
//  place explicit feedback signals are funnelled, proposals are surfaced, and an ACCEPTED proposal is applied to the
//  REAL personal-shield rules through the SAME store boundary MyShieldView uses.
//
//  R2 TRANSACTION INTEGRITY (mandate A — the measured P0 defects, all fixed here):
//   • A1 — accept() is ATOMIC. The old path marked a proposal ACCEPTED first and wrote the rule second (and never
//     checked the rule's current action), so a store-write failure or a stale proposal could desync disk+memory and
//     still report success. Now accept() performs a store COMPARE-AND-SWAP (mutateRuleAction) that writes ONLY if the
//     rule is still in the proposal's "from" action under the expected policy revision; the proposal is marked
//     accepted ONLY after a SUCCEEDED write. A failed/refused write keeps the proposal PENDING and surfaces an honest
//     error — never a false "accepted".
//   • A2 — undoLast() is SAFE + RESTART-SAFE. The inverse patch is PERSISTED (LearningUndoPatchV1), so undo survives a
//     relaunch. Undo CAS-checks that the rule is STILL in the applied action; if the user hand-edited it in between,
//     undo is REFUSED with an honest message (it never overwrites a manual edit). Undo targets ONLY the recorded rule.
//   • A3 — idempotent. Applying the same proposal twice is a no-op (proposal state + store no-op guard). A failed
//     transaction is never counted as success; an unseen rule change never happens.
//   • B1 — DURABLE learning progress. The engine's aggregates are now persisted (schema v2) and rehydrated at launch,
//     so "2 feedback → restart → 3rd → proposal" works. Content tokens are install-salted pseudonymised distinctness
//     keys (documented honestly as pseudonymisation, not anonymisation) — never raw media.
//
import Foundation
import Observation
import GuardianCore

@MainActor
@Observable
final class LocalLearningModel {
    // The DURABLE, app-private learning store (file-protected, backup-excluded) + the pure engine (GuardianMedia).
    private let store = LocalLearningStoreV1()
    private let engine = LocalLearningProposalEngineV1()
    // The SHARED personal-shield store — the SAME one ShieldStudioModel writes — so an accepted proposal bumps the
    // real policyRevision the extension + reels brain observe (§5). We read the live rules from it and write through it.
    private let shieldStore = PersonalShieldSharedStoreV1()
    // 1F — the CRASH-ATOMIC accept + recovery coordinator (GuardianMedia). It wraps the three accept writes with a
    // write-ahead intent so a crash can never leave a half-applied accept, and recovers one at launch (below).
    @ObservationIgnored private lazy var acceptCoordinator = LocalLearningAcceptCoordinatorV1(shieldStore: shieldStore,
                                                                                              learningStore: store, engine: engine)

    // Published state for the screen.
    private(set) var learningEnabled = false
    private(set) var consentShown = false
    private(set) var pending: [LearningProposalV1] = []
    private(set) var lastCorruptRecovered = false
    /// §5/A2 — the most recently ACCEPTED proposal that can still be UNDONE (its inverse patch is live + PERSISTED).
    /// nil when there is nothing to undo. Drives the "son değişikliği geri al" button.
    private(set) var undoableProposalID: String?
    private(set) var rules: [ShieldRuleV2] = []

    /// A1/A2 — the honest, user-facing result of the last accept/undo attempt (so the UI shows truth, never a false
    /// success). nil = no attempt yet. Turkish copy, no raw media.
    private(set) var lastTransactionMessage: String?
    private(set) var lastTransactionSucceeded: Bool = false

    /// B1 — the per-install pseudonymisation salt for content-distinctness tokens (loaded/created once, persisted).
    private var installSalt: String = ""
    /// A2 — the restart-safe undo patch (persisted alongside proposals).
    private var undoPatch: LearningUndoPatchV1?

    /// A monotonic day index from the wall clock — the engine's deterministic clock input (seconds→days). The engine
    /// never reads the clock itself; this is the single place time enters, so tests inject their own day values.
    private var nowDay: Int { Int(Date().timeIntervalSince1970 / 86_400) }

    init() {
        let loaded = store.load()
        learningEnabled = loaded.payload.learningEnabled
        consentShown = loaded.payload.consentShown
        lastCorruptRecovered = loaded.corruptRecovered
        // B1 — load or create the per-install salt (persisted so tokens stay stable across launches on this install).
        installSalt = loaded.payload.installSalt.isEmpty ? LocalLearningStoreV1.newInstallSalt() : loaded.payload.installSalt
        // Rehydrate the engine's durable proposals AND aggregates from disk (mandate B1 — progress survives restart).
        for p in loaded.payload.proposals { engine.restore(p) }
        engine.restoreAggregates(loaded.payload.aggregates)
        // A2 — restore the restart-safe undo patch + its marker.
        undoPatch = loaded.payload.undoPatch
        undoableProposalID = loaded.payload.undoPatch?.proposalID
        reloadRules()
        // 1F — RECOVERY SCAN: before surfacing any proposal, make a crash-interrupted accept whole-or-nothing. A
        // completed recovery installs the recovered undo patch so "son değişikliği geri al" still works post-crash;
        // a rollback leaves the proposal pending; an abandon never clobbers a user edit. Idempotent every launch.
        recoverInFlightAccept()
        refresh()
    }

    /// 1F — run the launch-time recovery. Delegates the whole-or-nothing decision to the coordinator; mirrors any
    /// recovered undo patch into the published state so the UI reflects the repaired, consistent result.
    private func recoverInFlightAccept() {
        let outcome = acceptCoordinator.recoverInFlightAccept(nowEpoch: Date().timeIntervalSince1970,
                                                              persist: { [weak self] patch in
            guard let self else { return false }
            self.undoPatch = patch
            return self.persistWith(undoPatch: patch)
        })
        switch outcome {
        case .completed(_, let patch):
            undoPatch = patch; undoableProposalID = patch.proposalID
        case .rolledBack, .abandoned:
            // Nothing applied (or world moved on) — ensure no stale undo marker lingers for this proposal.
            break
        case .alreadyComplete, .nothingToRecover:
            break
        }
    }

    private func reloadRules() { rules = shieldStore.loadPolicy().rules }

    var policyRevision: UInt64 { shieldStore.policyRevision }

    // MARK: - §4 toggle + consent

    /// §4/§6 — turn local learning ON/OFF. OFF immediately stops any NEW persistent signal (ingest no-ops) but does
    /// NOT erase existing proposals (the user can still act on them) — a separate reset clears history.
    func setLearningEnabled(_ on: Bool) {
        learningEnabled = on
        persist()
    }

    /// §4 — the first-run scope explanation has been shown + acknowledged (so it isn't re-shown every launch).
    func markConsentShown() { consentShown = true; persist() }

    // MARK: - §3.1 explicit signal intake (the ONLY inputs)

    /// §3 — record an explicit feedback signal. NO-OP when learning is OFF (§4/§6). The content id (if any) is HASHED
    /// with the per-install salt at this boundary into a pseudonymised distinctness token — the raw id is never stored.
    func recordSignal(ruleID: String, kind: LearningSignalKindV1, contentID: String?) {
        guard learningEnabled else { return }
        let token = contentID.map { LearningExplicitSignalV1.contentToken(from: $0, salt: installSalt) }
        let sig = LearningExplicitSignalV1(ruleID: ruleID, kind: kind, contentToken: token, dayStamp: nowDay)
        engine.ingest(sig, enabled: learningEnabled)
        refresh()   // persists aggregates too (B1)
    }

    // MARK: - §3/§4 proposals

    /// §3/§4 — recompute the pending proposals from the live rules + aggregates and persist the durable set+aggregates.
    func refresh() {
        reloadRules()
        pending = engine.refresh(rules: rules, nowDay: nowDay, policyRevision: policyRevision)
        persist()
    }

    /// §3.2/§5 + A1 — ACCEPT a proposal ATOMICALLY. Order (mandate A1): the proposal must be pending+valid → the rule
    /// must still exist → the rule's CURRENT action must equal the proposal's "from" → the store COMPARE-AND-SWAP must
    /// SUCCEED (verifying the expected policy revision) → ONLY THEN is the proposal marked accepted and its inverse
    /// patch persisted for undo. A failed/refused CAS keeps the proposal PENDING and surfaces an honest error. Returns
    /// true only on a REAL applied change.
    @discardableResult
    func accept(_ proposalID: String) -> Bool {
        // 1F — delegate to the crash-atomic coordinator. It writes a write-ahead intent, performs the verified CAS,
        // advances the intent as each durable write lands, persists the learning store, then clears the intent — so a
        // crash at any seam is recoverable on the next launch. `persist` captures the recovered undo patch.
        let outcome = acceptCoordinator.accept(proposalID: proposalID, nowEpoch: Date().timeIntervalSince1970,
                                               persist: { [weak self] patch in
            guard let self else { return false }
            self.undoPatch = patch
            return self.persistWith(undoPatch: patch)
        })
        switch outcome {
        case .applied(_, let patch):
            undoPatch = patch; undoableProposalID = patch.proposalID
            setTransaction(true, "Değişiklik uygulandı."); refresh(); return true
        case .noOpAlreadyAtTarget:
            setTransaction(true, "Kural zaten bu durumda — değişiklik gerekmedi."); refresh(); return false
        case .notPending:
            setTransaction(false, "Bu öneri artık geçerli değil."); return false
        case .ruleMissing:
            setTransaction(false, "Kural silinmiş; öneri uygulanamadı."); refresh(); return false
        case .actionMismatch:
            setTransaction(false, "Kuralı bu arada değiştirdiniz; eski öneri üzerine yazılmadı."); refresh(); return false
        case .revisionMismatch:
            setTransaction(false, "Kalkan politikası güncellendi; öneri yeniden değerlendirilecek."); refresh(); return false
        case .writeFailed, .interruptedAtFailurePoint:
            // A1/1F — nothing clean persisted; proposal stays pending; honest error. NEVER a false success. A real
            // (non-test) interruption leaves the intent on disk for the next-launch recovery scan.
            setTransaction(false, "Kaydetme başarısız oldu; öneri bekliyor."); return false
        }
    }

    /// §3.2 — REJECT a proposal: behaviour is preserved, nothing is written to the shield. Just updates the engine.
    @discardableResult
    func reject(_ proposalID: String) -> Bool {
        let ok = engine.reject(proposalID: proposalID) != nil
        refresh()
        return ok
    }

    /// §5 + A2 — UNDO the last accepted change SAFELY + RESTART-SAFE. Restores the rule's PRIOR action via the
    /// PERSISTED inverse patch, but ONLY if the rule is STILL in the applied action (CAS). If the user hand-edited the
    /// rule after accepting, undo is REFUSED with an honest message — it never clobbers a manual edit. Clears the undo
    /// marker only on a real restore (or when the patch is genuinely stale/irrelevant).
    @discardableResult
    func undoLast() -> Bool {
        guard let patch = undoPatch else { setTransaction(false, "Geri alınacak bir değişiklik yok."); return false }
        // A2 — CAS: the rule must still be in the action we applied, else the user edited it → refuse to overwrite.
        let result = shieldStore.mutateRuleAction(ruleID: patch.ruleID, expectedAction: patch.appliedAction,
                                                  to: patch.priorAction)
        switch result {
        case .applied:
            _ = engine.markUndone(proposalID: patch.proposalID)
            clearUndo()
            setTransaction(true, "Son değişiklik geri alındı.")
            refresh()
            return true
        case .noOpAlreadyAtTarget:
            // Already back at the prior action (nothing to do) — clear the marker honestly.
            _ = engine.markUndone(proposalID: patch.proposalID)
            clearUndo()
            setTransaction(true, "Kural zaten eski durumunda.")
            refresh()
            return false
        case .actionMismatch:
            // The user manually changed the rule after accepting → do NOT overwrite their edit. Keep honest; the undo
            // marker is retired because the original change no longer owns this rule's state.
            clearUndo()
            setTransaction(false, "Kuralı elle değiştirdiğiniz için otomatik geri alma yapılmadı.")
            refresh()
            return false
        case .ruleMissing:
            clearUndo(); setTransaction(false, "Kural silinmiş; geri alınacak bir şey yok."); refresh(); return false
        case .revisionMismatch:
            // No expectedRevision was passed to undo, so this case cannot occur; handle defensively.
            setTransaction(false, "Politika güncellendi; tekrar deneyin."); return false
        case .writeFailed:
            setTransaction(false, "Geri alma kaydı başarısız oldu; durum değişmedi."); return false
        }
    }

    private func clearUndo() { undoPatch = nil; undoableProposalID = nil }
    private func setTransaction(_ ok: Bool, _ msg: String) { lastTransactionSucceeded = ok; lastTransactionMessage = msg }

    // MARK: - §4/§6 reset + privacy surface

    /// §4/§6 — reset ONLY the learning history (aggregates + proposals + durable file + undo patch + salt). Does NOT
    /// delete shield rules. A fresh install salt is generated so a wipe genuinely breaks linkage to prior tokens.
    func resetLearningHistory() {
        engine.resetLearningHistory()
        clearUndo()
        _ = store.resetAll()
        installSalt = LocalLearningStoreV1.newInstallSalt()
        // Re-persist the toggle/consent + fresh salt so turning learning off-history doesn't lose the user's choice.
        persist()
        refresh()
    }

    /// §6 — honest privacy facts for the screen (no "KVKK zero" claim is made in copy; these are real attributes).
    var privacyFacts: (fileProtection: Bool, excludedFromBackup: Bool, proposalCount: Int, aggregateCount: Int) {
        let r = store.load()
        return (r.fileProtectionComplete, r.excludedFromBackup, engine.proposalCount, engine.aggregateCount)
    }

    private func persist() { _ = persistWith(undoPatch: undoPatch) }

    /// 1F — persist the full learning payload with a SPECIFIC undo patch (used by the coordinator's persist closure so
    /// the accepted proposal state + the recovered undo patch land together). Returns the store's success flag so the
    /// coordinator can keep the intent for the next launch if the learning-store write itself failed.
    @discardableResult
    private func persistWith(undoPatch patch: LearningUndoPatchV1?) -> Bool {
        let payload = LocalLearningPersistentV1(learningEnabled: learningEnabled, consentShown: consentShown,
                                                proposals: engine.allProposals,
                                                aggregates: engine.aggregatesSnapshot(),
                                                undoPatch: patch, installSalt: installSalt)
        return store.save(payload)
    }
}
