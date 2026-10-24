//
//  Tier1IdentityResolutionV1.swift — P1 (PRODUCT): Tier-1 verdict RESOLVES the content identity that the
//  Guardian evaluates against — BEFORE evidence binding, not a post-hoc log line.
//
//  WHY THIS EXISTS (product mandate P1):
//  Previously the broadcast path ran Guardian evaluation against the TIER-0 proposed identity
//  ("item-<tier0.itemID>") and only AFTERWARD ran Tier1ItemIdentityV1 — whose SAME/NEW/UNKNOWN verdict was
//  merely logged. That means a Tier-0 false-merge (two different videos grouped as one item — the measured
//  Outcome C failure) could let the Guardian keep evaluating against — or worse, REUSE a safe/protective
//  decision for — a DIFFERENT piece of content. That is false safe-state inheritance across items (constitution
//  rule 7: UNKNOWN ≠ BAD; rule: no stale Protected state). This resolver closes that gap:
//
//    Tier-0 PROPOSES an item id  →  Tier-1 CONFIRMS/OVERRIDES  →  RESOLVED identity  →  Guardian binds evidence
//                                                                    to the RESOLVED id.
//
//  SAFETY LAWS encoded here (headless-testable; pure; no Vision / no GuardianCore import needed — Tier-0 and
//  Tier-1 context enter as plain values):
//   L1  Tier-1 NEW overrides a Tier-0 SAME  → a FRESH identity id is minted; the Guardian never reuses the
//       prior item's decision/evidence for it.
//   L2  Strong SAME-vs-NEW CONTRADICTION (Tier-0 opened a new item, Tier-1 says SAME with real confidence, OR
//       Tier-0 said same but Tier-1 says NEW) is NEVER silently resolved to a protective/safe reuse: the
//       contradiction forces a NEW, UNKNOWN identity that must be RE-EVALUATED from scratch (safe-by-isolation).
//   L3  Tier-1 UNKNOWN (honest abstention) DEFERS to the Tier-0 proposal — it neither invents a new split nor
//       forces a merge. (Matches Tier1ItemIdentityV1's own abstention law.)
//   L4  A capture GENERATION token travels with every resolution. An ASYNC result (e.g. OCR / feature print that
//       completes late) carries the generation that was current WHEN THE FRAME WAS CAPTURED; if the live
//       generation has advanced (the item changed underneath it), the stale result is DROPPED, never attached to
//       whatever item happens to be current now. This is the cross-item stale-evidence firewall.
//
//  This type mints product-facing content ids and revisions in the extension/orchestration layer; it does NOT
//  reach into GuardianCore's ContentItemGroupingEngineV2 identity (frozen). Tier-0's own itemID/itemRevision are
//  carried as provenance so the derived proof log can still line the two up.
//
import Foundation

// MARK: - Capture generation token (the stale-evidence firewall)

/// Monotonic per-session token. One generation = "the identity the Guardian is currently bound to". It advances
/// whenever the resolved identity changes (new/contradiction). Async work stamps the generation it was STARTED
/// under; `isStale(_:)` drops anything whose generation the live resolver has already moved past.
public struct CaptureGenerationV1: Sendable, Codable, Equatable, Comparable {
    public let value: UInt64
    public init(_ value: UInt64) { self.value = value }
    public static func < (a: CaptureGenerationV1, b: CaptureGenerationV1) -> Bool { a.value < b.value }
    public static let zero = CaptureGenerationV1(0)
    public func next() -> CaptureGenerationV1 { CaptureGenerationV1(value &+ 1) }
}

// MARK: - Resolved identity (what the Guardian binds evidence to)

/// How the resolved identity relates to the immediately prior resolved identity — drives whether the Guardian may
/// reuse a prior decision at all.
public enum ResolvedIdentityRelationV1: String, Sendable, Codable {
    case continuation = "CONTINUATION"          // same content item as before → prior decision context may continue
    case newConfirmed = "NEW_CONFIRMED"         // a new item both tiers agree on → fresh evaluation
    case newContradiction = "NEW_CONTRADICTION" // tiers disagreed strongly → fresh evaluation, UNKNOWN, isolated
    case unknownDeferred = "UNKNOWN_DEFERRED"   // Tier-1 abstained → kept Tier-0's proposal (may be same or new)
}

public struct ResolvedContentIdentityV1: Sendable, Equatable {
    /// The id the Guardian MUST bind evidence to (e.g. passed as CrossAppObservation contentID).
    public let contentID: String
    /// Monotonic revision of the RESOLVED identity (distinct from Tier-0's itemRevision; increments on every new id).
    public let revision: Int
    /// Live capture generation after this resolution (stamp async work with this).
    public let generation: CaptureGenerationV1
    public let relation: ResolvedIdentityRelationV1
    /// True only when the Guardian may legitimately CONTINUE a prior decision against this id. False on every new
    /// item/contradiction/abstention-into-new — forcing a from-scratch evaluation (no safe-state inheritance).
    public let mayReusePriorDecision: Bool
    /// Compact derived reason (never raw content).
    public let reason: String
    /// Provenance: the Tier-0 ids this resolution was derived from (for the proof log; never authoritative alone).
    public let tier0ItemID: UInt64
    public let tier0ItemRevision: Int
    public let tier1Verdict: Tier1IdentityVerdictV1?
    public let tier1Confidence: Double

    public init(contentID: String, revision: Int, generation: CaptureGenerationV1,
                relation: ResolvedIdentityRelationV1, mayReusePriorDecision: Bool, reason: String,
                tier0ItemID: UInt64, tier0ItemRevision: Int,
                tier1Verdict: Tier1IdentityVerdictV1?, tier1Confidence: Double) {
        self.contentID = contentID; self.revision = revision; self.generation = generation
        self.relation = relation; self.mayReusePriorDecision = mayReusePriorDecision; self.reason = reason
        self.tier0ItemID = tier0ItemID; self.tier0ItemRevision = tier0ItemRevision
        self.tier1Verdict = tier1Verdict; self.tier1Confidence = tier1Confidence
    }
}

// MARK: - Tier-0 proposal (plain scalars — mirrors ContentItemGroupingEngineV2's decision, no Core import)

public struct Tier0IdentityProposalV1: Sendable, Equatable {
    public let itemID: UInt64
    public let itemRevision: Int
    public let openedNewItem: Bool
    public init(itemID: UInt64, itemRevision: Int, openedNewItem: Bool) {
        self.itemID = itemID; self.itemRevision = itemRevision; self.openedNewItem = openedNewItem
    }
}

// MARK: - The resolver (stateful per session; serial by contract, same as the Tier-1 tracker)

/// Resolves the identity the Guardian evaluates against by fusing the Tier-0 proposal with the Tier-1 verdict.
/// One instance per broadcast session. Pure/headless (no Vision, no Core).
public final class Tier1IdentityResolverV1 {
    /// Minimum Tier-1 confidence for a contradiction (Tier-1 SAME against a Tier-0 NEW, or Tier-1 NEW against a
    /// Tier-0 SAME) to be treated as STRONG — below this the verdict is demoted to a deferral (honest, not forced).
    public let strongContradictionMinConfidence: Double

    private var currentContentID: String?
    private var currentRevision = 0
    private var currentTier0ItemID: UInt64?
    private var generation = CaptureGenerationV1.zero
    // Bounded derived counters for the finish-line summary.
    private(set) public var resolvedCount = 0
    private(set) public var newConfirmedCount = 0
    private(set) public var contradictionCount = 0
    private(set) public var overrodeTier0Count = 0        // resolution id differs from what Tier-0 alone would bind

    public init(strongContradictionMinConfidence: Double = 0.60) {
        self.strongContradictionMinConfidence = max(0, strongContradictionMinConfidence)
    }

    public var liveGeneration: CaptureGenerationV1 { generation }

    /// An async result (OCR / feature print) is stale iff the live generation has advanced past the generation it
    /// was started under. Stale results MUST be dropped, never attached to the current item (L4).
    public func isStale(_ startedUnder: CaptureGenerationV1) -> Bool { startedUnder < generation }

    /// Resolve the identity to bind the Guardian to. Call this BEFORE Guardian evaluation.
    /// - tier0: the Tier-0 provisional proposal (itemID / revision / openedNewItem).
    /// - tier1: the Tier-1 verdict for this committed shot, or nil when Tier-1 was dropped (throttle/in-flight).
    @discardableResult
    public func resolve(tier0: Tier0IdentityProposalV1, tier1: (verdict: Tier1IdentityVerdictV1, confidence: Double)?) -> ResolvedContentIdentityV1 {
        resolvedCount += 1
        let v = tier1?.verdict
        let conf = tier1?.confidence ?? 0

        // What the Tier-0 proposal alone would have bound (the OLD behaviour) — for the override counter.
        let tier0WouldOpenNew = tier0.openedNewItem || currentTier0ItemID != tier0.itemID

        // Decide the relation.
        let relation: ResolvedIdentityRelationV1
        switch v {
        case .newItem:
            // L1: Tier-1 NEW always means a fresh item (whether or not Tier-0 agreed).
            relation = (tier0.openedNewItem) ? .newConfirmed : .newContradiction
        case .sameItem where conf >= strongContradictionMinConfidence && tier0.openedNewItem:
            // L2: Tier-1 SAME with real confidence vs a Tier-0 NEW is a STRONG contradiction. We do NOT merge back
            // into the prior item (that would risk inheriting its safe/protective decision onto possibly-different
            // content); we isolate into a NEW, UNKNOWN identity requiring fresh evaluation.
            relation = .newContradiction
        case .sameItem:
            // Tier-1 SAME agreeing with Tier-0 (or low-confidence against a new) → continuation of the current id,
            // but only if we actually have one and Tier-0 did not open a new item.
            relation = (currentContentID != nil && !tier0.openedNewItem) ? .continuation : .unknownDeferred
        case .unknown, .none:
            // L3: Tier-1 abstained (or was dropped) → keep the Tier-0 proposal.
            relation = tier0WouldOpenNew ? .unknownDeferred : .continuation
        }

        switch relation {
        case .continuation:
            // Keep the current resolved id. (currentContentID is guaranteed non-nil on this path.)
            let id = currentContentID ?? mintID(tier0: tier0)
            currentContentID = id; currentTier0ItemID = tier0.itemID
            return record(id: id, revision: currentRevision, relation: relation, mayReuse: true,
                          reason: reasonFor(relation, v, conf), tier0: tier0, v: v, conf: conf,
                          overrode: false)

        case .newConfirmed, .newContradiction, .unknownDeferred:
            // Any path that is NOT a pure continuation mints a fresh identity when the underlying item actually
            // changed; a pure deferral on an unchanged item keeps the current id.
            if relation == .unknownDeferred && !tier0WouldOpenNew, let id = currentContentID {
                currentTier0ItemID = tier0.itemID
                return record(id: id, revision: currentRevision, relation: .continuation, mayReuse: true,
                              reason: reasonFor(.continuation, v, conf), tier0: tier0, v: v, conf: conf,
                              overrode: false)
            }
            // Mint a NEW resolved identity and ADVANCE the generation (stale-evidence firewall).
            currentRevision += 1
            generation = generation.next()
            let id = mintID(tier0: tier0)
            currentContentID = id; currentTier0ItemID = tier0.itemID
            if relation == .newConfirmed { newConfirmedCount += 1 }
            if relation == .newContradiction { contradictionCount += 1 }
            // A contradiction or a Tier-1-driven new (that Tier-0 alone would NOT have opened) is an override.
            let overrode = (relation == .newContradiction) || (v == .newItem && !tier0.openedNewItem)
            if overrode { overrodeTier0Count += 1 }
            // mayReuse is FALSE for every fresh identity: the Guardian must evaluate from scratch, never inherit.
            return record(id: id, revision: currentRevision, relation: relation, mayReuse: false,
                          reason: reasonFor(relation, v, conf), tier0: tier0, v: v, conf: conf,
                          overrode: overrode)
        }
    }

    // MARK: helpers

    /// Product-facing content id. Includes the resolved revision so two DIFFERENT resolved items can never collide
    /// on the same string even if Tier-0 reused an item id (the measured false-merge case).
    private func mintID(tier0: Tier0IdentityProposalV1) -> String {
        "rc-\(currentRevision)-t0item-\(tier0.itemID)"
    }

    private func reasonFor(_ r: ResolvedIdentityRelationV1, _ v: Tier1IdentityVerdictV1?, _ conf: Double) -> String {
        let t1 = v?.rawValue ?? "NONE"
        switch r {
        case .continuation:      return "continue(tier1=\(t1))"
        case .newConfirmed:      return "new-confirmed(tier0+tier1)"
        case .newContradiction:  return "new-contradiction(tier1=\(t1),conf=\(String(format: "%.2f", conf)))->isolate+reeval"
        case .unknownDeferred:   return "unknown-deferred(tier1=\(t1))->keep-tier0"
        }
    }

    private func record(id: String, revision: Int, relation: ResolvedIdentityRelationV1, mayReuse: Bool,
                        reason: String, tier0: Tier0IdentityProposalV1, v: Tier1IdentityVerdictV1?, conf: Double,
                        overrode: Bool) -> ResolvedContentIdentityV1 {
        ResolvedContentIdentityV1(contentID: id, revision: revision, generation: generation, relation: relation,
                                  mayReusePriorDecision: mayReuse, reason: reason,
                                  tier0ItemID: tier0.itemID, tier0ItemRevision: tier0.itemRevision,
                                  tier1Verdict: v, tier1Confidence: conf)
    }
}
