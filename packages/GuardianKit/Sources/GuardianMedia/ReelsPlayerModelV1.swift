//
//  ReelsPlayerModelV1.swift — B: the headless brain of the GEN8 CONTROLLED REELS PLAYER.
//
//  BIG GOAL (mandate B): GEN8's FIRST real video-playback control. On our OWN AVPlayer surface, playing our OWN
//  local videos, the user's personal-shield rules are honestly applied BEFORE exposure: a matching reel is HIDDEN
//  (player paused, image+audio removed) rather than shown; an unmatched reel plays; a reel we cannot evaluate gets
//  an explicit decision screen (never auto-played as if "safe"). This file is the pure, headless state machine so
//  the whole decision/skip/override/live-reload logic is testable WITHOUT the AVPlayer runtime. The SwiftUI layer
//  owns the real AVPlayer and simply obeys the per-item `PlaybackIntent` this model computes.
//
//  WHY A SEPARATE PURE MODEL (constitution §4 Definition of Done; testability): AVPlayer behaviour (pause, rate,
//  mute, layer removal) is proven by integration tests directly on AVPlayer in GuardianMediaTests. The POLICY —
//  pre-playback gate, stale-decision invalidation, per-item state transitions, content-scoped override, skip
//  safety — is proven HERE, deterministically, with an injected evidence provider + an injected shield store.
//
//  FROZEN APIs CONSUMED (never re-implemented): ShieldEvaluatorV2 (the real decision), PersonalShieldSharedStoreV1
//  (the user's real rules + policyRevision), CrossAppObservationBuilder.envelope (the real envelope the extension
//  uses too), ShieldException (B4 override). Nothing about matching semantics is duplicated.
//
import Foundation
import GuardianCore
#if canImport(AVFoundation)

// MARK: - Per-item lifecycle state (mandate B: pending / evaluating / playing / hidden / skipped / overridden)

/// The honest lifecycle of ONE reel in the controlled queue. Each transition is a REAL engine/user moment.
public enum ReelItemStateV1: String, Sendable, Equatable, Codable {
    case pendingEvaluation = "PENDING_EVALUATION"  // not yet analysed; must NOT auto-play if Hide prefs exist (B1)
    case evaluating        = "EVALUATING"          // pre-exposure analysis in flight (frames+OCR+shield)
    case playing           = "PLAYING"             // evaluated → no hide decision → allowed to play
    case hidden            = "HIDDEN"              // a real HIDE decision applied (B2): paused, image+audio removed
    case undetermined      = "UNDETERMINED"        // evidence insufficient → explicit decision screen (B1, never "safe")
    case skipped           = "SKIPPED"             // user skipped (or hidden-then-advanced) (B3)
    case userOverridden    = "USER_OVERRIDDEN"     // user chose "Show anyway" for THIS content (B4, content-scoped)
}

/// What the AVPlayer surface should DO for the current item. The SwiftUI layer obeys this literally — it is the
/// bridge between the pure policy and the real player. `hide` carries the real reason for the "Why hidden?" copy.
public enum PlaybackIntentV1: Sendable, Equatable {
    case awaitDecision                       // pre-playback gate: do NOT attach player output yet (B1)
    case play                                // attach + play real video/audio
    case hide(reason: GuardianReasonCodeV1)  // pause + remove image/audio + show Guardian shield (B2)
    case askUser(reason: GuardianReasonCodeV1) // explicit decision screen for an UNDETERMINED item (B1)
}

// MARK: - A single reel in the controlled queue (OWNED local media)

/// One controlled reel: a local, project-OWNED video file + its declared metadata + a stable content identity the
/// shield decision is bound to (B4 override is scoped to THIS identity). `contentID` is used both as the shield
/// envelope id and the override key, so an override can never leak to a different reel.
public struct ReelItemV1: Sendable, Equatable, Identifiable {
    public let id: String                 // stable identity (also the ShieldException scope value for B4)
    public let title: String              // declared metadata (known source — NOT image understanding)
    public let url: URL                   // local, app-owned asset
    public let firstFrameSeconds: [Double]// which early timestamps to OCR for pre-exposure analysis
    public let languages: [String]
    public init(id: String, title: String, url: URL, firstFrameSeconds: [Double] = [0.2, 0.6],
                languages: [String] = ["en"]) {
        self.id = id; self.title = title; self.url = url
        self.firstFrameSeconds = firstFrameSeconds; self.languages = languages
    }
}

// MARK: - The resolved decision for one item (honest, fully attributed — mandate C)

/// A complete, honest decision record for ONE reel. Carries content identity + policy revision + evidence
/// provenance + match state + the applied action + the surface capability. NO 0-100 score (constitution rule 8).
public struct ReelDecisionV1: Sendable, Equatable {
    public let contentID: String
    public let policyRevision: UInt64             // the rule-set version this decision was produced under
    public let state: ReelItemStateV1
    public let intent: PlaybackIntentV1
    public let matchState: ShieldMatchState
    public let layerDecision: ShieldLayerDecision
    public let appliedAction: ShieldAction?
    public let matchedRuleID: String?
    public let provenance: ReelsEvidenceProvenanceV1
    public let coverage: Double                   // evaluator coverage (fraction of matchers that ran)
    public let uncertainty: Double                // 0 determinable … 1 non-determinable
    public let reason: GuardianReasonCodeV1
    public let surfaceControlled: Bool            // true here: this is OUR controlled surface (hide may EXECUTE)
    public init(contentID: String, policyRevision: UInt64, state: ReelItemStateV1, intent: PlaybackIntentV1,
                matchState: ShieldMatchState, layerDecision: ShieldLayerDecision, appliedAction: ShieldAction?,
                matchedRuleID: String?, provenance: ReelsEvidenceProvenanceV1, coverage: Double,
                uncertainty: Double, reason: GuardianReasonCodeV1, surfaceControlled: Bool) {
        self.contentID = contentID; self.policyRevision = policyRevision; self.state = state; self.intent = intent
        self.matchState = matchState; self.layerDecision = layerDecision; self.appliedAction = appliedAction
        self.matchedRuleID = matchedRuleID; self.provenance = provenance; self.coverage = coverage
        self.uncertainty = uncertainty; self.reason = reason; self.surfaceControlled = surfaceControlled
    }
}

// MARK: - The pure decision engine (no AVPlayer, no SwiftUI) — fully unit-testable

/// Produces an honest ReelDecisionV1 from gathered evidence + the user's real rules. Pre-playback gate (B1),
/// stale-decision rules (A1/B2), and UNKNOWN honesty (B1) all live here as PURE functions.
public struct ReelsDecisionEngineV1: Sendable {
    public static let version = "reels-decision-engine-v1"
    private let evaluator: ShieldEvaluatorV2
    public init(evaluator: ShieldEvaluatorV2 = .standard()) { self.evaluator = evaluator }

    /// B1 pre-playback gate: if the user has ANY active HIDE preference and the item is NOT yet evaluated, the
    /// player output must NOT be attached — we must evaluate first. Pure predicate over the loaded rules.
    public static func hasActiveHidePreference(rules: [ShieldRuleV2], nowEpoch: Double) -> Bool {
        rules.contains { $0.isActive(nowEpoch: nowEpoch) && Self.isHideAction($0.action) }
    }

    /// A HIDE-class action is one whose configured intent is to remove the content on a controlled surface.
    public static func isHideAction(_ a: ShieldAction) -> Bool {
        a == .hideIfControlled || a == .blurIfControlled || a == .muteIfControlled || a == .skipIfControlledAndAligned
    }

    /// Evaluate ONE item's evidence against the user's rules on OUR controlled surface, honestly. The returned
    /// decision's `intent` is what the AVPlayer layer obeys. `userInitiated` is passed through so a B4 override
    /// exception can legitimately allow the content.
    public func decide(item: ReelItemV1, evidence: ReelsEvidenceV1, index: ShieldIndex,
                       exceptions: [ShieldException], policyRevision: UInt64, nowEpoch: Double,
                       userInitiated: Bool) -> ReelDecisionV1 {
        // Build the SAME envelope the extension uses, but mark the OCR text with its true origin. Metadata-only
        // evidence is still passed as text (it can match an exact term) — the provenance field keeps us honest
        // about what it is; we never claim the pixels were understood when only the title matched.
        var env = CrossAppObservationBuilder.envelope(contentID: item.id, ocrText: evidence.combinedText.isEmpty ? nil : evidence.combinedText,
                                                       soundEvents: [], languages: evidence.languages)
        env.surfaceCapabilityTier = "C5"   // our own player = fully controlled surface
        let outcome = evaluator.evaluate(.init(envelope: env, controlledSurface: true, userInitiated: userInitiated,
                                               nowEpoch: nowEpoch), index: index, exceptions: exceptions)

        // Map the frozen outcome → an HONEST player intent + lifecycle state.
        // 1) A real, determinable match whose action EXECUTEs on a controlled surface → HIDE (B2).
        let realHit = outcome.matchState.isMatch && outcome.layerDecision == .execute && !outcome.exceptionApplied
        if realHit {
            return ReelDecisionV1(contentID: item.id, policyRevision: policyRevision, state: .hidden,
                                  intent: .hide(reason: .textEvidenceMatchedShield),
                                  matchState: outcome.matchState, layerDecision: outcome.layerDecision,
                                  appliedAction: outcome.actionRecommendation, matchedRuleID: outcome.ruleID,
                                  provenance: evidence.provenance, coverage: outcome.coverage,
                                  uncertainty: outcome.uncertainty, reason: .textEvidenceMatchedShield,
                                  surfaceControlled: true)
        }
        // 2) Non-determinable evidence (matcher unavailable / matchability unknown / conflict) while the user HAS
        //    hide prefs → UNDETERMINED: an explicit decision screen, NEVER auto-played as safe (B1, rule 7).
        //    Also: a HIDE-pref user with NO usable evidence at all gets the same honest ask.
        let nonDeterminable = outcome.matchState.isNonDeterminable
        let noEvidence = evidence.provenance == .none
        if nonDeterminable || (noEvidence && Self.indexHasHidePreference(index, nowEpoch: nowEpoch)) {
            let reason: GuardianReasonCodeV1 = noEvidence ? .textEvidenceUnavailable : .visualEvidenceInsufficient
            return ReelDecisionV1(contentID: item.id, policyRevision: policyRevision, state: .undetermined,
                                  intent: .askUser(reason: reason),
                                  matchState: outcome.matchState, layerDecision: outcome.layerDecision,
                                  appliedAction: outcome.actionRecommendation, matchedRuleID: outcome.ruleID,
                                  provenance: evidence.provenance, coverage: outcome.coverage,
                                  uncertainty: outcome.uncertainty, reason: reason, surfaceControlled: true)
        }
        // 3) Evaluated, no hide signal (or an exception/override allowed it) → PLAY. If an exception applied via a
        //    user override, record the overridden state so the UI can show "you chose to show this".
        let state: ReelItemStateV1 = outcome.exceptionApplied ? .userOverridden : .playing
        return ReelDecisionV1(contentID: item.id, policyRevision: policyRevision, state: state, intent: .play,
                              matchState: outcome.matchState, layerDecision: outcome.layerDecision,
                              appliedAction: outcome.actionRecommendation, matchedRuleID: outcome.ruleID,
                              provenance: evidence.provenance, coverage: outcome.coverage,
                              uncertainty: outcome.uncertainty, reason: .textEvidenceBenign,
                              surfaceControlled: true)
    }

    /// Does the live index contain any ACTIVE hide-class rule? Used so a no-evidence item only triggers the
    /// explicit decision screen when the user actually relies on hiding (otherwise there's nothing to gate on).
    static func indexHasHidePreference(_ index: ShieldIndex, nowEpoch: Double) -> Bool {
        index.rules.values.contains { $0.isActive(nowEpoch: nowEpoch) && isHideAction($0.action) }
    }
}

// MARK: - The observable queue model (MainActor; owns state, drives the SwiftUI player)

/// The player queue model the SwiftUI view binds to. Holds per-item states, the current decision, and the live
/// policy revision. All intelligence is delegated to ReelsDecisionEngineV1 + the frozen store; this is the
/// orchestration + state layer (still testable: it takes an injected store + evidence provider).
@MainActor
public final class ReelsPlayerModelV1 {
    public let items: [ReelItemV1]
    private let store: PersonalShieldSharedStoreV1
    private let evidenceProvider: any ReelsEvidenceProviding
    private let engine: ReelsDecisionEngineV1
    private let clock: @Sendable () -> Double

    // Live policy snapshot (reloaded on demand / on policy-revision change — A1).
    private var index = ShieldIndex()
    private var rules: [ShieldRuleV2] = []
    private var baseExceptions: [ShieldException] = []
    public private(set) var policyRevision: UInt64 = 0
    public private(set) var sharedContainerActive = false

    // B4 — content-scoped overrides: ruleID→exception are keyed to a SPECIFIC content id so "Show anyway" on one
    // reel can never leak to another. Stored per content id; cleared when policy changes (a new rule-set may mean
    // the user no longer wants that exception).
    private var overrides: [String: Bool] = [:]   // contentID → user chose to show it

    // Per-item observable state.
    public private(set) var states: [String: ReelItemStateV1] = [:]
    public private(set) var decisions: [String: ReelDecisionV1] = [:]
    public private(set) var currentIndex: Int = 0

    public init(items: [ReelItemV1], store: PersonalShieldSharedStoreV1,
                evidenceProvider: any ReelsEvidenceProviding = ReelsEvidenceProviderV1(),
                engine: ReelsDecisionEngineV1 = ReelsDecisionEngineV1(),
                clock: @escaping @Sendable () -> Double = { Date().timeIntervalSince1970 }) {
        self.items = items; self.store = store; self.evidenceProvider = evidenceProvider
        self.engine = engine; self.clock = clock
        for it in items { states[it.id] = .pendingEvaluation }
        reloadPolicy()
    }

    public var currentItem: ReelItemV1? { items.indices.contains(currentIndex) ? items[currentIndex] : nil }
    public func state(of id: String) -> ReelItemStateV1 { states[id] ?? .pendingEvaluation }
    public func decision(of id: String) -> ReelDecisionV1? { decisions[id] }

    /// A1 — reload the user's live rules + policy revision from the shared store. Called at init and whenever the
    /// shared policyRevision advances (the SwiftUI layer polls this on the 1s heartbeat cadence). Returns true if
    /// the revision CHANGED (so the caller can invalidate + re-evaluate the current item without a restart).
    @discardableResult
    public func reloadPolicy() -> Bool {
        let loaded = store.loadPolicy()
        let changed = loaded.policyRevision != policyRevision || index.count != loaded.index.count
        index = loaded.index; rules = loaded.rules; baseExceptions = loaded.exceptions
        policyRevision = loaded.policyRevision; sharedContainerActive = loaded.sharedContainerActive
        if changed { overrides.removeAll() }   // a rule change invalidates prior per-content overrides (B2/A1)
        return changed
    }

    /// A1 — poll the shared policyRevision cheaply (no full load). If it advanced, reload + invalidate the current
    /// decision so the UI re-evaluates. Returns true when a reload happened.
    @discardableResult
    public func pollPolicyRevisionAndInvalidateIfChanged() -> Bool {
        guard store.policyRevision != policyRevision else { return false }
        _ = reloadPolicy()
        // Invalidate decisions made under the OLD revision; mark their items pending so they re-evaluate.
        for (id, d) in decisions where PersonalShieldLoadedPolicyV1.isStaleDecision(stamped: d.policyRevision, liveRevision: policyRevision) {
            decisions[id] = nil
            if states[id] != .skipped { states[id] = .pendingEvaluation }
        }
        return true
    }

    /// B1 — the pre-playback gate. If the user has an active HIDE preference and this item is still pending, the
    /// AVPlayer layer must await the decision (don't attach output). Pure read; no side effects.
    public func mustGateBeforePlay(_ id: String) -> Bool {
        guard state(of: id) == .pendingEvaluation else { return false }
        return ReelsDecisionEngineV1.hasActiveHidePreference(rules: rules, nowEpoch: clock())
    }

    /// Evaluate ONE item end-to-end: gather honest pre-exposure evidence → run the frozen shield pass → record the
    /// decision + lifecycle state. Idempotent per revision: re-evaluating under the same revision recomputes.
    /// `userInitiated` carries a B4 override through to the evaluator (so an exception can allow the content).
    @discardableResult
    public func evaluate(_ item: ReelItemV1) async -> ReelDecisionV1 {
        states[item.id] = .evaluating
        let evidence = await evidenceProvider.gatherEvidence(url: item.url, metadataTitle: item.title,
                                                             firstFrameSeconds: item.firstFrameSeconds,
                                                             languages: item.languages)
        let userInitiated = overrides[item.id] == true
        let exceptions = baseExceptions + overrideExceptions(for: item.id)
        let decision = engine.decide(item: item, evidence: evidence, index: index, exceptions: exceptions,
                                     policyRevision: policyRevision, nowEpoch: clock(), userInitiated: userInitiated)
        decisions[item.id] = decision
        states[item.id] = decision.state
        return decision
    }

    /// B4 — the user chose "Show anyway" for THIS content. Records a content-scoped override + re-evaluates this
    /// item so the exception is honoured (it will PLAY, state → userOverridden). Scoped to the item id only.
    @discardableResult
    public func userShowAnyway(_ item: ReelItemV1) async -> ReelDecisionV1 {
        overrides[item.id] = true
        return await evaluate(item)
    }

    /// B3 — mark the current item skipped and advance to the next unresolved item. Returns the next item (or nil
    /// at the end of the queue). Handles back-to-back hidden items (keeps advancing past already-hidden ones only
    /// when the caller asks to skip them). Direction-agnostic: `advance(by:)` supports swipe fwd/back.
    @discardableResult
    public func skipCurrent() -> ReelItemV1? {
        if let cur = currentItem { states[cur.id] = .skipped }
        return advance(by: 1)
    }

    /// Move the queue cursor (B3 swipe). Clamped to bounds; returns the item now current, or nil past the end.
    @discardableResult
    public func advance(by delta: Int) -> ReelItemV1? {
        let next = currentIndex + delta
        guard next >= 0 else { currentIndex = 0; return currentItem }
        guard next < items.count else { currentIndex = items.count; return nil }   // list end (B3)
        currentIndex = next
        return currentItem
    }

    /// B4 — a content-scoped allow exception, iff the user overrode THIS item. Content-scoping is enforced HERE,
    /// not by the frozen exception engine: this method only returns an exception when `overrides[contentID]` is set,
    /// and `evaluate(_:)` only calls it (and only passes `userInitiated: true`) for that same item — so the override
    /// can never leak to another reel. The exception uses `.userInitiated` scope (the frozen engine's user-override
    /// path) plus `allowsOverrideOfGuardianRule` so even a guardian-authored rule can be user-allowed on our own
    /// controlled surface. A `.item`-scoped exception is also supplied (value = content id) as explicit provenance.
    private func overrideExceptions(for contentID: String) -> [ShieldException] {
        guard overrides[contentID] == true else { return [] }
        return [ShieldException(scope: .userInitiated, value: contentID, allowsOverrideOfGuardianRule: true),
                ShieldException(scope: .item, value: contentID, allowsOverrideOfGuardianRule: true)]
    }
}
#endif
