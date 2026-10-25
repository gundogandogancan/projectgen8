//
//  GuardianDecisionRevalidationV1.swift — R3 §2: LONG-LIVED CONTENT DECISION TRUTH (explainable evidence reuse).
//
//  WHY THIS EXISTS (R3 §2 — the P0 defect): on STATIC content (a paused video, a single long post) the decision's
//  evidence-freshness TTL expires while the user is STILL on the SAME content, and nothing re-triggers analysis (no
//  new item, no policy change). The decision then reads STALE even though the content never changed — the user loses
//  their protection band on content they are still looking at.
//
//  THE FIX — explainable evidence reuse + cheap selective revalidation, keeping FIVE concepts STRICTLY SEPARATE
//  (mandate §2): (1) observation liveness, (2) content identity stability, (3) evidence freshness, (4) decision
//  validity, (5) policy freshness. This type governs ONLY concept (4) — how a decision's validity may be EXTENDED —
//  and it does so with an EXPLICIT, recorded rule, NEVER by silently touching a heartbeat timestamp.
//
//  THE RULE (explainable, provenance-stamped):
//    • A decision's validity may be EXTENDED by a REVALIDATION EVENT iff the content identity is VERIFIABLY STABLE
//      (Tier-0 AND/OR Tier-1 confirm the SAME item — concept 2) AND the policy is unchanged (concept 5). A
//      revalidation is a CHEAP check (e.g. the existing Tier-0 continuity signal), NOT a full OCR / full re-analysis.
//    • Each revalidation carries its OWN timestamp + the rule id that authorised it, recorded in provenance. The
//      decision's evidence freshness (concept 3) is NOT falsified — the ORIGINAL evidence epoch is preserved; what is
//      extended is the VALIDITY window, with an audit trail of how many cheap revalidations extended it and until when.
//    • A NEW item identity (concept 2 breaks) or a POLICY change (concept 5 breaks) INVALIDATES immediately — no
//      revalidation can rescue it; the decision must be re-analysed from scratch.
//    • There is a BOUNDED number of consecutive cheap revalidations before a FULL re-analysis is forced, so a decision
//      can never be extended forever on cheap checks alone (defends against a slowly-drifting static scene).
//
//  PURE + headless + testable with synthetic timestamps. Lives in GuardianMedia (GuardianCore is frozen).
//
import Foundation

/// R3 §2 — why a revalidation was ACCEPTED or REFUSED (explainable; recorded in provenance, surfaced honestly).
public enum GuardianRevalidationOutcomeV1: String, Sendable, Equatable, Codable {
    case extended            = "EXTENDED"              // identity stable + policy unchanged → validity window extended
    case refusedIdentityUnstable = "REFUSED_IDENTITY_UNSTABLE" // identity not confirmed same → cannot reuse evidence
    case refusedPolicyChanged    = "REFUSED_POLICY_CHANGED"    // policy changed → decision invalid, must re-analyse
    case refusedBudgetExhausted  = "REFUSED_BUDGET_EXHAUSTED"  // too many cheap revalidations → force full re-analysis
    case refusedNoDecision       = "REFUSED_NO_DECISION"       // nothing to revalidate yet
}

/// R3 §2 — the explainable VALIDITY state of a long-lived decision, kept separate from evidence freshness. This is a
/// VALUE recomputed on each cheap tick; it never mutates the underlying evidence.
public struct GuardianDecisionValidityWindowV1: Sendable, Equatable, Codable {
    /// The item identity revision the ORIGINAL decision was produced for (identity stability anchor).
    public let decisionItemIdentityRevision: Int
    /// The policy revision the decision was produced under (policy freshness anchor).
    public let decisionPolicyRevision: UInt64
    /// The ORIGINAL evidence epoch — PRESERVED across revalidations (concept 3 is never falsified).
    public let originalEvidenceEpoch: Double
    /// The current end of the VALIDITY window (extended by accepted revalidations). The decision is valid while
    /// `now <= validUntilEpoch` AND identity+policy still match.
    public let validUntilEpoch: Double
    /// How many cheap revalidations have extended this decision (audit; bounded by `maxConsecutiveRevalidations`).
    public let revalidationCount: Int
    /// The epoch of the MOST RECENT accepted revalidation (0 = none yet). Its own timestamp — distinct from the
    /// original evidence epoch — so provenance shows exactly when validity was last cheaply confirmed.
    public let lastRevalidationEpoch: Double

    public init(decisionItemIdentityRevision: Int, decisionPolicyRevision: UInt64, originalEvidenceEpoch: Double,
                validUntilEpoch: Double, revalidationCount: Int = 0, lastRevalidationEpoch: Double = 0) {
        self.decisionItemIdentityRevision = decisionItemIdentityRevision
        self.decisionPolicyRevision = decisionPolicyRevision
        self.originalEvidenceEpoch = originalEvidenceEpoch
        self.validUntilEpoch = validUntilEpoch
        self.revalidationCount = revalidationCount
        self.lastRevalidationEpoch = lastRevalidationEpoch
    }
}

public enum GuardianDecisionRevalidationV1 {
    /// Base validity window (seconds) for a fresh decision's evidence — the same order as the heartbeat freshness
    /// window; a decision is valid this long on its original evidence before it needs a cheap confirmation.
    public static let baseValidityWindowSeconds: Double = 3.0
    /// Each accepted cheap revalidation extends validity by this much (shorter than the base — a cheap check is less
    /// authoritative than a full analysis, so it buys less time, but it is enough to cover a static scene).
    public static let revalidationExtensionSeconds: Double = 5.0
    /// Hard cap on consecutive cheap revalidations before a FULL re-analysis is forced (defends against slow drift).
    public static let maxConsecutiveRevalidations: Int = 12

    /// R3 §2 — open a validity window for a FRESH decision (called when a real analysis produces a decision).
    public static func open(decisionItemIdentityRevision: Int, decisionPolicyRevision: UInt64,
                            evidenceEpoch: Double) -> GuardianDecisionValidityWindowV1 {
        GuardianDecisionValidityWindowV1(
            decisionItemIdentityRevision: decisionItemIdentityRevision,
            decisionPolicyRevision: decisionPolicyRevision,
            originalEvidenceEpoch: evidenceEpoch,
            validUntilEpoch: evidenceEpoch + baseValidityWindowSeconds,
            revalidationCount: 0, lastRevalidationEpoch: 0)
    }

    /// R3 §2 — attempt a CHEAP revalidation of a static decision. Inputs are the SEPARATE facts:
    ///   - `identityStable`: Tier-0/Tier-1 confirm the SAME item is still on screen (concept 2). FALSE ⇒ refuse.
    ///   - `currentPolicyRevision`: the live policy (concept 5). Different from the window's ⇒ refuse (invalidate).
    ///   - `nowEpoch`: the cheap-check instant (its own timestamp — recorded, NOT the evidence epoch).
    /// On acceptance the validity window is extended and the revalidation is counted + timestamped; the ORIGINAL
    /// evidence epoch is untouched. The outcome is returned so the caller can record it in provenance + surface it.
    public static func revalidate(_ window: GuardianDecisionValidityWindowV1?,
                                  identityStable: Bool, currentPolicyRevision: UInt64,
                                  currentItemIdentityRevision: Int, nowEpoch: Double)
        -> (window: GuardianDecisionValidityWindowV1?, outcome: GuardianRevalidationOutcomeV1) {
        guard let w = window else { return (nil, .refusedNoDecision) }
        // Policy change invalidates immediately — no cheap reuse can rescue a decision under stale rules (concept 5).
        if currentPolicyRevision != w.decisionPolicyRevision { return (nil, .refusedPolicyChanged) }
        // Identity must be the SAME item AND confirmed stable (concept 2). A different item invalidates immediately.
        if currentItemIdentityRevision != w.decisionItemIdentityRevision || !identityStable {
            return (nil, .refusedIdentityUnstable)
        }
        // Bounded: too many cheap extensions ⇒ force a full re-analysis (never extend forever on cheap checks).
        if w.revalidationCount >= maxConsecutiveRevalidations { return (nil, .refusedBudgetExhausted) }
        let extended = GuardianDecisionValidityWindowV1(
            decisionItemIdentityRevision: w.decisionItemIdentityRevision,
            decisionPolicyRevision: w.decisionPolicyRevision,
            originalEvidenceEpoch: w.originalEvidenceEpoch,                 // concept 3 preserved — never falsified
            validUntilEpoch: max(w.validUntilEpoch, nowEpoch) + revalidationExtensionSeconds,
            revalidationCount: w.revalidationCount + 1,
            lastRevalidationEpoch: nowEpoch)                               // the revalidation's OWN timestamp
        return (extended, .extended)
    }

    /// R3 §2 — is the decision VALID right now? Valid iff identity + policy still match AND we are within the (possibly
    /// extended) validity window. This is concept (4), derived from the separate facts — it never consults a heartbeat.
    public static func isValid(_ window: GuardianDecisionValidityWindowV1?,
                               currentItemIdentityRevision: Int, currentPolicyRevision: UInt64,
                               nowEpoch: Double) -> Bool {
        guard let w = window else { return false }
        return currentItemIdentityRevision == w.decisionItemIdentityRevision
            && currentPolicyRevision == w.decisionPolicyRevision
            && nowEpoch <= w.validUntilEpoch
    }
}
