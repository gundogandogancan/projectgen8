//
//  LocalLearningProposalEngineV1.swift — §3: PERSONAL LEARNING V1 (the Personal Policy Adaptation loop).
//  "The Guardian Learns With You — Under Your Control."
//
//  WHAT THIS IS (mandate §3, L1 PERSONAL only): a LIGHT adaptor on top of the FROZEN LearningSignalBusV1
//  (GuardianCore). It is NOT a parallel brain, NOT model-weight training, NOT a silent threshold adapter. It
//  consumes EXPLICIT user feedback signals ONLY and, when enough INDEPENDENT same-direction evidence accumulates
//  for the SAME rule, it emits ONE honest PROPOSAL ("you chose 'show anyway' a few times for this rule — change
//  your behaviour?"). A proposal changes NOTHING until the user ACCEPTS it (§3.2 propose-then-confirm). The engine
//  is PURE + DETERMINISTIC over its inputs (no wall-clock reads inside the law; the caller supplies `nowDays`), so
//  every threshold/retention rule is unit-testable.
//
//  HONESTY LAWS (mandate §3.1/§3.2/§3.4 + constitution):
//   • EXPLICIT signals only. The signal KINDS below are all deliberate user actions (rule edits, content-scoped
//     "show anyway", an ASK answer, an explicit "show me less like this", an explicit "this warning didn't help").
//     There is NO signal kind for dwell / swipe / watch-time — behavioural inference is impossible by construction.
//   • INDEPENDENT evidence only. The threshold counts DISTINCT content ids per (rule, direction). Repeated taps on
//     the SAME content COLLAPSE to one evidence unit (§3.1: "repeat clicks on the same content are not independent").
//     A single override is never a decisive preference (§3.1): the threshold is ≥3 distinct-content signals.
//   • NO raw media in the persistent record. A stored proposal/aggregate carries rule IDs, counts, dates, kinds,
//     the proposed change and reason — NEVER raw OCR/audio/transcript/screenshot (§3.3). Content ids are kept only
//     as a BOUNDED, HASHED distinctness set inside the volatile aggregate and are NOT part of the durable proposal.
//   • BOUNDED + RETENTION-DATED. Aggregates and proposals carry a retention window; stale evidence is pruned by the
//     caller-supplied clock so a contradiction-over-time never silently becomes a rule change (§3.4).
//   • NO confident proposal ⇒ NO proposal (§3.4). High-impact / sensitive directions use a STRICTER threshold.
//
//  SCOPE: this type produces PROPOSALS and the INVERSE PATCH needed to UNDO an accepted change. Applying a proposal
//  to the real policy (SharedStore + policyRevision bump) is done by the app layer (ShieldStudioModel) so the one
//  write path stays the store boundary — this engine never writes rules itself (no silent policy change, §3.2).
//
import Foundation
import GuardianCore

// MARK: - §3.1 explicit signal model (the ONLY inputs; all deliberate user actions).

/// The explicit feedback KINDS. Each maps to a DIRECTION (loosen vs tighten) for a specific rule. There is no kind
/// derivable from passive behaviour — dwell/swipe/watch-time have NO representation here (impossible by construction).
public enum LearningSignalKindV1: String, Sendable, Equatable, Codable {
    /// The user chose "Yine de göster" (content-scoped show-anyway) against a rule that would have acted. LOOSEN.
    case showAnyway = "SHOW_ANYWAY"
    /// The user answered an ASK prompt by ALLOWING the content for this rule. LOOSEN.
    case askAllowed = "ASK_ALLOWED"
    /// The user answered an ASK prompt by BLOCKING/keeping the content hidden for this rule. TIGHTEN.
    case askBlocked = "ASK_BLOCKED"
    /// Explicit button "Bunun gibi daha az göster" on the decision surface. TIGHTEN (wants stronger action).
    case showLessLikeThis = "SHOW_LESS_LIKE_THIS"
    /// Explicit button "Bu uyarı yardımcı olmadı" on the decision surface. LOOSEN (the warning wasn't wanted).
    case warningNotHelpful = "WARNING_NOT_HELPFUL"

    /// §3.1 — the adaptation DIRECTION this kind argues for. LOOSEN = relax the rule toward ALLOW/ASK;
    /// TIGHTEN = strengthen toward a stronger action. Mixed directions on a rule CANCEL (no confident proposal).
    public enum Direction: String, Sendable, Equatable, Codable { case loosen = "LOOSEN", tighten = "TIGHTEN" }
    public var direction: Direction {
        switch self {
        case .showAnyway, .askAllowed, .warningNotHelpful: return .loosen
        case .askBlocked, .showLessLikeThis:               return .tighten
        }
    }
}

/// §3.1 — ONE explicit signal event, as submitted by a REAL interaction point (ShieldStudioModel rule edit,
/// ControlledReelsModel show-anyway / ASK answer, the explicit feedback buttons). Carries the rule it pertains to,
/// the deliberate kind, a content-distinctness token (HASHED at the boundary — never raw text), and the day it
/// happened (caller-supplied clock → deterministic). `contentToken` is used ONLY for distinctness collapsing and is
/// NEVER persisted in a durable proposal; a nil token means "not content-scoped" (e.g. a rule edit) and counts once.
public struct LearningExplicitSignalV1: Sendable, Equatable, Codable {
    public let ruleID: String
    public let kind: LearningSignalKindV1
    public let contentToken: String?     // bounded hashed distinctness key (NOT raw content); nil = non-content-scoped
    public let dayStamp: Int             // integer day index from the caller clock (deterministic; no wall-clock here)
    public init(ruleID: String, kind: LearningSignalKindV1, contentToken: String?, dayStamp: Int) {
        self.ruleID = ruleID; self.kind = kind; self.contentToken = contentToken; self.dayStamp = dayStamp
    }

    /// §3.3 — PRIVACY HELPER: derive a bounded, non-reversible content-distinctness token from a content id WITHOUT
    /// keeping the id itself. FNV-1a over the id → a short hex string. This is a DISTINCTNESS key only (two different
    /// content ids yield different tokens with high probability); it is NOT a trust/identity root and never leaves
    /// the device. It exists so "3 distinct reels" can be counted without storing which reels they were.
    public static func contentToken(from contentID: String) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for b in contentID.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return String(h, radix: 16)
    }
}

// MARK: - §3.3 proposal record (DURABLE, bounded, no raw media).

public enum LearningProposalStatusV1: String, Sendable, Equatable, Codable {
    case pending = "PENDING", accepted = "ACCEPTED", rejected = "REJECTED", undone = "UNDONE"
}

/// §3.3 — ONE proposal. DURABLE fields ONLY: rule ID, direction, independent-evidence COUNT, the signal kinds that
/// produced it, the PROPOSED change (from→to action), a reason string with no raw media, status, dates. There is NO
/// raw OCR/audio/transcript and NO content-id history here (the distinctness set lives only in the volatile aggregate).
public struct LearningProposalV1: Sendable, Equatable, Codable {
    public let proposalID: String
    public let ruleID: String
    public let direction: LearningSignalKindV1.Direction
    public let signalKinds: [LearningSignalKindV1]        // which explicit kinds contributed (provenance, no content)
    public let independentEvidenceCount: Int              // DISTINCT-content evidence units (the threshold metric)
    public let currentAction: ShieldAction                // the rule's action at proposal time (from)
    public let proposedAction: ShieldAction               // the action the user would move to (to)
    public let reason: String                             // human-readable, derived — NEVER raw media
    public var status: LearningProposalStatusV1
    public let createdDay: Int
    public let retentionDays: Int                         // the proposal expires (and is pruned) after this window
    public let producedUnderPolicyRevision: UInt64        // the policy revision active when this proposal was formed
    public init(proposalID: String, ruleID: String, direction: LearningSignalKindV1.Direction,
                signalKinds: [LearningSignalKindV1], independentEvidenceCount: Int,
                currentAction: ShieldAction, proposedAction: ShieldAction, reason: String,
                status: LearningProposalStatusV1 = .pending, createdDay: Int, retentionDays: Int,
                producedUnderPolicyRevision: UInt64) {
        self.proposalID = proposalID; self.ruleID = ruleID; self.direction = direction
        self.signalKinds = signalKinds; self.independentEvidenceCount = independentEvidenceCount
        self.currentAction = currentAction; self.proposedAction = proposedAction; self.reason = reason
        self.status = status; self.createdDay = createdDay; self.retentionDays = retentionDays
        self.producedUnderPolicyRevision = producedUnderPolicyRevision
    }
    public func isExpired(nowDay: Int) -> Bool { nowDay - createdDay > retentionDays }
}

/// §3.3 — the volatile (RAM) aggregate for one (rule, direction): the DISTINCT content tokens seen, the kinds, and
/// the last-seen day for retention pruning. The distinct-token set is BOUNDED and never persisted to the durable
/// store — it is the independence counter only. Same-content repeats collapse because the set dedupes by token.
struct LearningAggregateV1: Sendable, Equatable {
    var ruleID: String
    var direction: LearningSignalKindV1.Direction
    var distinctContentTokens: Set<String>     // bounded; non-content-scoped signals use a synthetic per-signal token
    var kinds: Set<LearningSignalKindV1>
    var firstDay: Int
    var lastDay: Int
    var nonContentUnits: Int                    // units from signals with no content token (each counts once, bounded)
}

// MARK: - §3 the engine (pure, deterministic, bounded).

/// §3 — the Local Learning Proposal Engine. Pure adaptor over LearningSignalBusV1-shaped explicit signals. Holds
/// bounded per-(rule,direction) aggregates and the current proposal set. Deterministic: all time is caller-supplied.
public final class LocalLearningProposalEngineV1: @unchecked Sendable {
    public static let version = "local-learning-proposal-engine-v1"

    // §3.4 THRESHOLD LAW. The default: ≥3 INDEPENDENT same-direction units on DISTINCT content for the SAME rule
    // within the retention window. A STRICTER threshold applies to HIGH-IMPACT directions (tightening toward a
    // destructive action, or any sound-rule direction) so a few noisy signals can never propose a strong change.
    public let baseThreshold: Int
    public let strictThreshold: Int
    public let retentionDays: Int
    public let proposalRetentionDays: Int
    public let maxAggregates: Int
    public let maxProposals: Int

    private var aggregates: [String: LearningAggregateV1] = [:]   // key = "rule|direction"
    private var proposals: [LearningProposalV1] = []
    private var proposalSeq: UInt64 = 0
    private var syntheticSeq: UInt64 = 0                          // for non-content-scoped distinctness tokens
    private let lock = NSLock()

    public init(baseThreshold: Int = 3, strictThreshold: Int = 5, retentionDays: Int = 30,
                proposalRetentionDays: Int = 30, maxAggregates: Int = 256, maxProposals: Int = 128) {
        self.baseThreshold = max(2, baseThreshold)          // a single override is NEVER decisive (≥2 floor)
        self.strictThreshold = max(self.baseThreshold + 1, strictThreshold)
        self.retentionDays = retentionDays; self.proposalRetentionDays = proposalRetentionDays
        self.maxAggregates = maxAggregates; self.maxProposals = maxProposals
    }

    private func key(_ ruleID: String, _ dir: LearningSignalKindV1.Direction) -> String { "\(ruleID)|\(dir.rawValue)" }

    /// §3.4 — the effective threshold for a (rule, direction). Stricter when the proposed move is HIGH IMPACT:
    /// tightening (toward a stronger/destructive action) or a SOUND rule (a classifier label is not calibrated risk).
    public func effectiveThreshold(for rule: ShieldRuleV2, direction: LearningSignalKindV1.Direction) -> Int {
        let highImpact = direction == .tighten || SoundRuleSafetyV1.isSoundInput(rule.inputType)
        return highImpact ? strictThreshold : baseThreshold
    }

    /// §3 — INGEST one explicit signal. Updates the (rule,direction) aggregate with DISTINCT-content collapsing and
    /// retention pruning. Returns nothing; proposals are produced lazily by `proposals(for:nowDay:)` / `refresh`.
    /// `enabled` is the LEARNING-ON switch (§4/§6): when learning is OFF this is a NO-OP (no persistent signal is
    /// ever recorded — mandate §4/§6 "learning-off produces zero new records"). The caller MUST pass the live toggle.
    public func ingest(_ signal: LearningExplicitSignalV1, enabled: Bool) {
        guard enabled else { return }   // §4/§6 — learning OFF ⇒ no new persistent evidence, full stop.
        lock.lock(); defer { lock.unlock() }
        let k = key(signal.ruleID, signal.kind.direction)
        var agg = aggregates[k] ?? LearningAggregateV1(ruleID: signal.ruleID, direction: signal.kind.direction,
                                                       distinctContentTokens: [], kinds: [],
                                                       firstDay: signal.dayStamp, lastDay: signal.dayStamp,
                                                       nonContentUnits: 0)
        // Retention pruning: if the last evidence is older than the window, the aggregate is STALE → reset it (a
        // contradiction/preference that has gone cold must not silently accumulate into a change, §3.4).
        if signal.dayStamp - agg.lastDay > retentionDays {
            agg.distinctContentTokens = []; agg.kinds = []; agg.nonContentUnits = 0; agg.firstDay = signal.dayStamp
        }
        agg.kinds.insert(signal.kind)
        agg.lastDay = max(agg.lastDay, signal.dayStamp)
        agg.firstDay = min(agg.firstDay, signal.dayStamp)
        if let token = signal.contentToken {
            // DISTINCT content collapsing: repeated taps on the SAME content do NOT add independent evidence (§3.1).
            if agg.distinctContentTokens.count < maxAggregates { agg.distinctContentTokens.insert(token) }
        } else {
            // A non-content-scoped signal (e.g. a rule edit / global button) counts as ONE independent unit each,
            // bounded so a spam loop can't inflate it without bound.
            syntheticSeq &+= 1
            if agg.nonContentUnits < maxAggregates { agg.nonContentUnits += 1 }
        }
        aggregates[k] = agg
        if aggregates.count > maxAggregates { evictOldestAggregate() }
    }

    private func evictOldestAggregate() {
        guard let oldest = aggregates.min(by: { $0.value.lastDay < $1.value.lastDay })?.key else { return }
        aggregates.removeValue(forKey: oldest)
    }

    /// §3 — the INDEPENDENT-evidence count for a (rule, direction): distinct content tokens + non-content units.
    public func independentEvidence(ruleID: String, direction: LearningSignalKindV1.Direction) -> Int {
        lock.lock(); defer { lock.unlock() }
        guard let agg = aggregates[key(ruleID, direction)] else { return 0 }
        return agg.distinctContentTokens.count + agg.nonContentUnits
    }

    /// §3.2/§3.4 — COMPUTE the proposal (if any) for a rule at `nowDay` under `policyRevision`. Returns nil when no
    /// confident proposal exists: below threshold, OR CONFLICTING directions (both loosen AND tighten have evidence →
    /// the preference is ambiguous → NO proposal, §3.4), OR the proposed action would be a no-op / unsafe. A sound
    /// rule can never be proposed INTO a destructive action (the SoundRuleSafety law also governs proposals, §1.1).
    public func computeProposal(for rule: ShieldRuleV2, nowDay: Int, policyRevision: UInt64) -> LearningProposalV1? {
        lock.lock(); defer { lock.unlock() }
        return computeProposalLocked(for: rule, nowDay: nowDay, policyRevision: policyRevision)
    }

    private func computeProposalLocked(for rule: ShieldRuleV2, nowDay: Int, policyRevision: UInt64) -> LearningProposalV1? {
        let loosen = aggregates[key(rule.ruleID, .loosen)]
        let tighten = aggregates[key(rule.ruleID, .tighten)]
        let loosenN = evidenceCount(loosen, nowDay: nowDay)
        let tightenN = evidenceCount(tighten, nowDay: nowDay)
        // §3.4 — CONFLICTING evidence in BOTH directions (each at/above its own floor) ⇒ ambiguous ⇒ NO proposal.
        let loosenFloor = effectiveThreshold(for: rule, direction: .loosen)
        let tightenFloor = effectiveThreshold(for: rule, direction: .tighten)
        let loosenReady = loosenN >= loosenFloor
        let tightenReady = tightenN >= tightenFloor
        if loosenReady && tightenReady { return nil }   // mixed confident evidence → abstain (no confident proposal)
        let dir: LearningSignalKindV1.Direction
        let agg: LearningAggregateV1
        let count: Int
        if loosenReady, let l = loosen { dir = .loosen; agg = l; count = loosenN }
        else if tightenReady, let t = tighten { dir = .tighten; agg = t; count = tightenN }
        else { return nil }                              // below threshold → no proposal (§3.4)

        guard let proposed = proposedAction(from: rule.action, direction: dir, rule: rule) else { return nil }
        guard proposed != rule.action else { return nil }   // would be a no-op — never propose nothing
        proposalSeq &+= 1
        let reason = Self.reason(dir: dir, kinds: agg.kinds, count: count)
        return LearningProposalV1(proposalID: "prop-\(rule.ruleID)-\(proposalSeq)", ruleID: rule.ruleID,
                                  direction: dir, signalKinds: agg.kinds.sorted { $0.rawValue < $1.rawValue },
                                  independentEvidenceCount: count, currentAction: rule.action,
                                  proposedAction: proposed, reason: reason, status: .pending,
                                  createdDay: nowDay, retentionDays: proposalRetentionDays,
                                  producedUnderPolicyRevision: policyRevision)
    }

    private func evidenceCount(_ agg: LearningAggregateV1?, nowDay: Int) -> Int {
        guard let agg else { return 0 }
        if nowDay - agg.lastDay > retentionDays { return 0 }   // stale aggregate contributes nothing (§3.4)
        return agg.distinctContentTokens.count + agg.nonContentUnits
    }

    /// §3.2 — the SINGLE-STEP action move for a direction. LOOSEN softens one step toward ALLOW; TIGHTEN strengthens
    /// one step. Deliberately CONSERVATIVE (one step, never a jump to the most extreme action) and SAFETY-BOUNDED:
    /// a sound/audio rule can never be proposed INTO a controlled EXECUTE action (SoundRuleSafety §1.1 governs here
    /// too). Returns nil when there is no safe, meaningful next step in that direction.
    func proposedAction(from current: ShieldAction, direction: LearningSignalKindV1.Direction,
                        rule: ShieldRuleV2) -> ShieldAction? {
        // The honest loosen/tighten ladder for the controlled surface (reversible-first ordering).
        //   ALLOW  <  WARN  <  ASK  <  HIDE/BLUR/MUTE/SKIP (strongest, controlled execute)
        let next: ShieldAction?
        switch (direction, current) {
        case (.loosen, .hideIfControlled), (.loosen, .blurIfControlled),
             (.loosen, .muteIfControlled), (.loosen, .skipIfControlledAndAligned):
            next = .ask                       // from a strong action, loosen to ASK (not straight to ALLOW)
        case (.loosen, .ask):  next = .warn
        case (.loosen, .warn): next = .allow
        case (.loosen, .allow), (.loosen, .allowWithNote): next = nil   // already as loose as it goes
        case (.tighten, .allow), (.tighten, .allowWithNote): next = .warn
        case (.tighten, .warn): next = .ask
        case (.tighten, .ask):  next = .hideIfControlled   // the strongest step; sound rules are blocked below
        case (.tighten, _):     next = nil                 // already at a strong action
        }
        guard let candidate = next else { return nil }
        // §1.1 — a sound/audio rule may NEVER be proposed into a controlled execute action.
        if SoundRuleSafetyV1.isSoundInput(rule.inputType),
           SoundRuleSafetyV1.disallowedSoundActions.contains(candidate) { return nil }
        return candidate
    }

    static func reason(dir: LearningSignalKindV1.Direction, kinds: Set<LearningSignalKindV1>, count: Int) -> String {
        let kindList = kinds.map { $0.rawValue }.sorted().joined(separator: ",")
        switch dir {
        case .loosen:  return "\(count) bağımsız geri bildirim bu kuralı gevşetmeyi öneriyor (kinds:\(kindList))"
        case .tighten: return "\(count) bağımsız geri bildirim bu kuralı güçlendirmeyi öneriyor (kinds:\(kindList))"
        }
    }

    // MARK: - Durable proposal lifecycle (pending/accept/reject/undo).

    /// §3/§4 — REFRESH the pending-proposal set from the current aggregates for the supplied rules. Produces at most
    /// ONE pending proposal per rule (the strongest confident direction). Already-decided (accepted/rejected/undone)
    /// proposals for a rule suppress a NEW pending one for the SAME current-action (don't re-nag a settled decision).
    /// Prunes expired proposals. Returns the live pending proposals (deterministic ordering by rule id).
    @discardableResult
    public func refresh(rules: [ShieldRuleV2], nowDay: Int, policyRevision: UInt64) -> [LearningProposalV1] {
        lock.lock(); defer { lock.unlock() }
        proposals.removeAll { $0.isExpired(nowDay: nowDay) }
        for rule in rules {
            // Skip if a decided proposal already covers THIS rule at THIS action (user already answered this question).
            let alreadyDecided = proposals.contains {
                $0.ruleID == rule.ruleID && $0.currentAction == rule.action &&
                ($0.status == .accepted || $0.status == .rejected || $0.status == .undone)
            }
            let alreadyPending = proposals.contains { $0.ruleID == rule.ruleID && $0.status == .pending }
            if alreadyDecided || alreadyPending { continue }
            if let p = computeProposalLocked(for: rule, nowDay: nowDay, policyRevision: policyRevision) {
                proposals.append(p)
                if proposals.count > maxProposals { proposals.removeFirst(proposals.count - maxProposals) }
            }
        }
        return proposals.filter { $0.status == .pending }.sorted { $0.ruleID < $1.ruleID }
    }

    /// §3.3 — REHYDRATE a durable proposal from the persistent store at launch (the aggregates stay volatile by
    /// design). Appends if a proposal with the same ID is not already present; keeps the proposal sequence ahead of
    /// any restored id so freshly computed proposals never collide. Bounded by maxProposals.
    public func restore(_ p: LearningProposalV1) {
        lock.lock(); defer { lock.unlock() }
        guard !proposals.contains(where: { $0.proposalID == p.proposalID }) else { return }
        proposals.append(p)
        if proposals.count > maxProposals { proposals.removeFirst(proposals.count - maxProposals) }
        // Keep the sequence monotonic beyond any restored numeric suffix so new proposal IDs can't collide.
        if let suffix = p.proposalID.split(separator: "-").last, let n = UInt64(suffix) { proposalSeq = max(proposalSeq, n) }
    }

    public var allProposals: [LearningProposalV1] { lock.lock(); defer { lock.unlock() }; return proposals }
    public var pendingProposals: [LearningProposalV1] {
        lock.lock(); defer { lock.unlock() }; return proposals.filter { $0.status == .pending }.sorted { $0.ruleID < $1.ruleID }
    }

    /// §3.2/§5 — ACCEPT a pending proposal. Marks it accepted and CLEARS the aggregates that produced it (the
    /// evidence has been acted on; it must not re-fire). Returns the accepted proposal (with the from→to the APP
    /// applies to the real rule via the store) or nil if not found/pending. This engine NEVER writes the rule itself.
    @discardableResult
    public func accept(proposalID: String) -> LearningProposalV1? {
        lock.lock(); defer { lock.unlock() }
        guard let i = proposals.firstIndex(where: { $0.proposalID == proposalID && $0.status == .pending }) else { return nil }
        proposals[i].status = .accepted
        let p = proposals[i]
        aggregates.removeValue(forKey: key(p.ruleID, p.direction))   // consumed evidence — don't re-propose immediately
        return p
    }

    /// §3.2 — REJECT a pending proposal. Behaviour is PRESERVED (nothing changes). Clears the aggregate so the same
    /// evidence does not instantly re-propose; new future evidence may raise it again (honest, not permanently muted).
    @discardableResult
    public func reject(proposalID: String) -> LearningProposalV1? {
        lock.lock(); defer { lock.unlock() }
        guard let i = proposals.firstIndex(where: { $0.proposalID == proposalID && $0.status == .pending }) else { return nil }
        proposals[i].status = .rejected
        let p = proposals[i]
        aggregates.removeValue(forKey: key(p.ruleID, p.direction))
        return p
    }

    /// §4/§5 — mark an accepted proposal as UNDONE (the user hit "son değişikliği geri al"). The inverse rule patch
    /// is (proposedAction → currentAction); the APP applies it to the store. Returns the proposal so the app can
    /// restore the prior action, or nil if the proposal isn't in the accepted state.
    @discardableResult
    public func markUndone(proposalID: String) -> LearningProposalV1? {
        lock.lock(); defer { lock.unlock() }
        guard let i = proposals.firstIndex(where: { $0.proposalID == proposalID && $0.status == .accepted }) else { return nil }
        proposals[i].status = .undone
        return proposals[i]
    }

    /// §4/§6 — RESET the learning history (aggregates + proposals). Does NOT touch the user's actual shield rules
    /// (the app clears those separately — "geçmiş sıfırlama mevcut kuralları SİLMEZ", §4). After this, there is zero
    /// learning evidence on-device until the user produces new explicit signals.
    public func resetLearningHistory() {
        lock.lock(); defer { lock.unlock() }
        aggregates.removeAll(); proposals.removeAll(); proposalSeq = 0; syntheticSeq = 0
    }

    /// §6 — counts for the privacy/telemetry surface (no raw media anywhere in these numbers).
    public var aggregateCount: Int { lock.lock(); defer { lock.unlock() }; return aggregates.count }
    public var proposalCount: Int { lock.lock(); defer { lock.unlock() }; return proposals.count }
}
