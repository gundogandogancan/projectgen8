//
//  LocalLearningModel.swift — §3/§4/§5: the app-side Personal Learning controller ("Guardian'ım Nasıl Öğreniyor?").
//
//  WHAT THIS IS: the @MainActor @Observable the "How Guardian Learns" screen binds to. It owns the DURABLE learning
//  store + the pure proposal engine (both GuardianMedia types, source-compiled into this app target). It is the ONE
//  place explicit feedback signals are funnelled, proposals are surfaced, and an ACCEPTED proposal is applied to the
//  REAL personal-shield rules through the SAME store boundary MyShieldView uses (so acceptance produces a genuine
//  policyRevision bump → the extension + the reels brain pick up the new rule → behaviour actually changes, §5).
//
//  LAWS THIS GLUE OBEYS:
//   • Learning OFF ⇒ ingest() is a NO-OP and nothing is persisted (§4/§6). The toggle is durable + consent-gated.
//   • A proposal changes NOTHING until the user accepts it (§3.2). Accept writes the rule via the shared store (real
//     revision bump); the inverse patch is retained so "son değişikliği geri al" restores the prior action (§5).
//   • Reset learning history clears aggregates + proposals; it does NOT touch the shield rules (§4). Clearing shield
//     rules is a SEPARATE control (deleteAll on ShieldStudioModel) — surfaced distinctly on the screen.
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

    // Published state for the screen.
    private(set) var learningEnabled = false
    private(set) var consentShown = false
    private(set) var pending: [LearningProposalV1] = []
    private(set) var lastCorruptRecovered = false
    /// §5 — the most recently ACCEPTED proposal that can still be UNDONE (its inverse patch is live). nil when there
    /// is nothing to undo. Drives the "son değişikliği geri al" button.
    private(set) var undoableProposalID: String?
    private(set) var rules: [ShieldRuleV2] = []

    /// A monotonic day index from the wall clock — the engine's deterministic clock input (seconds→days). The engine
    /// never reads the clock itself; this is the single place time enters, so tests inject their own day values.
    private var nowDay: Int { Int(Date().timeIntervalSince1970 / 86_400) }

    init() {
        let loaded = store.load()
        learningEnabled = loaded.payload.learningEnabled
        consentShown = loaded.payload.consentShown
        lastCorruptRecovered = loaded.corruptRecovered
        // Rehydrate the engine's durable proposals from disk (aggregates are volatile by design — §3.3).
        for p in loaded.payload.proposals { engine.restore(p) }
        reloadRules()
        refresh()
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
    /// at this boundary into a distinctness token — the raw id is never stored. Refreshes proposals afterwards.
    func recordSignal(ruleID: String, kind: LearningSignalKindV1, contentID: String?) {
        guard learningEnabled else { return }
        let token = contentID.map { LearningExplicitSignalV1.contentToken(from: $0) }
        let sig = LearningExplicitSignalV1(ruleID: ruleID, kind: kind, contentToken: token, dayStamp: nowDay)
        engine.ingest(sig, enabled: learningEnabled)
        refresh()
    }

    // MARK: - §3/§4 proposals

    /// §3/§4 — recompute the pending proposals from the live rules + aggregates and persist the durable set.
    func refresh() {
        reloadRules()
        pending = engine.refresh(rules: rules, nowDay: nowDay, policyRevision: policyRevision)
        persist()
    }

    /// §3.2/§5 — ACCEPT a proposal: mark accepted in the engine, then APPLY the from→to action to the REAL rule
    /// through the shared store (a genuine policyRevision bump → extension reload + reels re-evaluation + prefetch
    /// invalidation, all already wired). Retains the accepted id as the undoable change. Returns true on a real apply.
    @discardableResult
    func accept(_ proposalID: String) -> Bool {
        guard let accepted = engine.accept(proposalID: proposalID) else { return false }
        let applied = applyActionChange(ruleID: accepted.ruleID, to: accepted.proposedAction)
        if applied { undoableProposalID = accepted.proposalID }
        refresh()
        return applied
    }

    /// §3.2 — REJECT a proposal: behaviour is preserved, nothing is written to the shield. Just updates the engine.
    @discardableResult
    func reject(_ proposalID: String) -> Bool {
        let ok = engine.reject(proposalID: proposalID) != nil
        refresh()
        return ok
    }

    /// §5 — UNDO the last accepted change: restore the rule's PRIOR action via the stored inverse patch (proposed→
    /// current), again through the shared store (real revision bump reverses the chain). Clears the undoable marker.
    @discardableResult
    func undoLast() -> Bool {
        guard let id = undoableProposalID, let p = engine.markUndone(proposalID: id) else { return false }
        let restored = applyActionChange(ruleID: p.ruleID, to: p.currentAction)   // inverse patch: back to the "from"
        undoableProposalID = nil
        refresh()
        return restored
    }

    /// §5 — the real behaviour-change write: set `ruleID`'s action to `action` and save through the shared store
    /// (which applies the §1.1 sound-safety law AND bumps the policyRevision). Returns false if the rule vanished.
    private func applyActionChange(ruleID: String, to action: ShieldAction) -> Bool {
        var current = shieldStore.loadPolicy().rules
        guard let i = current.firstIndex(where: { $0.ruleID == ruleID }) else { return false }
        current[i].action = action
        current[i].updatedAtEpoch = Date().timeIntervalSince1970
        do { _ = try shieldStore.saveRules(current); reloadRules(); return true } catch { return false }
    }

    // MARK: - §4/§6 reset + privacy surface

    /// §4/§6 — reset ONLY the learning history (aggregates + proposals + durable file). Does NOT delete shield rules.
    func resetLearningHistory() {
        engine.resetLearningHistory()
        undoableProposalID = nil
        _ = store.resetAll()
        // Re-persist the toggle/consent so turning learning off-history doesn't lose the user's enabled choice.
        persist()
        refresh()
    }

    /// §6 — honest privacy facts for the screen (no "KVKK zero" claim is made in copy; these are real attributes).
    var privacyFacts: (fileProtection: Bool, excludedFromBackup: Bool, proposalCount: Int, aggregateCount: Int) {
        let r = store.load()
        return (r.fileProtectionComplete, r.excludedFromBackup, engine.proposalCount, engine.aggregateCount)
    }

    private func persist() {
        let payload = LocalLearningPersistentV1(learningEnabled: learningEnabled, consentShown: consentShown,
                                                proposals: engine.allProposals)
        _ = store.save(payload)
    }
}
