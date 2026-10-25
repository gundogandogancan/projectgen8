//
//  GuardianSelfEvalCountersV1.swift — R3 §9: MEASURABLE self-evaluation counters for the NEW R3 signals.
//
//  WHY THIS EXISTS (R3 §9): OCTOPUS continues to improve its own work quality, but ONLY with INDEPENDENT ground truth
//  and ONLY via SAFE resource/scheduling optimisations — NEVER by silently changing the user shield, child-safety, or
//  model thresholds (mandate §9). This type is a pure, bounded, derived-scalar accumulator for the honest signals the
//  R3 work produces, so the app/extension can surface "what the system measured about itself" without any hidden
//  behaviour change. It stores COUNTS only — never raw frames/OCR/titles (privacy).
//
//  The counters map 1:1 onto the mandate's §9 list that R3 can honestly produce:
//    • crossPathMismatch     — a reference matched only below the ACTIONABLE bar (any-match but not HIGH/EXACT) — the
//                              R2 defect's residual rate, now measurable so a regression is visible.
//    • staleDiscards         — a photo match computed for item N discarded because the item advanced to N+1 (§5).
//    • legacyNeedsReauthor   — references stored under the pre-canonical basis that must be reauthored (§1.1).
//    • revalidationExtended / revalidationRefused — long-lived decision reuse outcomes (§2).
//    • thermalSkips          — photo-shield passes skipped under thermal pressure (§9 ROI/thermal economy).
//    • blockedIslandUpdates  — App Group writes that could NOT reach ActivityKit (suspended app — §4.3 known gap).
//    • duplicateSignatureWork — signatures recomputed that a cheap cache could have reused (ROI cost signal).
//
//  PURE + headless + Codable. Lives in GuardianMedia (GuardianCore is frozen). No automatic threshold mutation here:
//  this type MEASURES; any optimisation decision that reads it must stay inside resource/scheduling (mandate §9).
//
import Foundation

public struct GuardianSelfEvalCountersV1: Sendable, Equatable, Codable {
    public var crossPathMismatch: Int = 0
    public var staleDiscards: Int = 0
    public var legacyNeedsReauthor: Int = 0
    public var revalidationExtended: Int = 0
    public var revalidationRefused: Int = 0
    public var thermalSkips: Int = 0
    public var blockedIslandUpdates: Int = 0
    public var duplicateSignatureWork: Int = 0

    public init() {}

    /// Fold a photo-shield pass result into the counters (derived scalars only). `discardedStale` is whether the
    /// caller's §B5 firewall dropped the best match because it was for a prior item (independent ground truth = the
    /// caller's resolved item revision, not the pipeline's own id). A best match that is ANY-match but NOT actionable
    /// is a cross-path mismatch residual — the thing R3 §1 set out to drive to zero.
    public mutating func foldPhotoPass(best: PhotoShieldLiveMatchV1?, legacyNeedsReauthor: Int,
                                       signaturesComputed: Int, reusedCachedSignature: Bool,
                                       discardedStale: Bool, thermalSkipped: Bool) {
        self.legacyNeedsReauthor += legacyNeedsReauthor
        if thermalSkipped { thermalSkips += 1 }
        if discardedStale { staleDiscards += 1 }
        if reusedCachedSignature && signaturesComputed > 0 { duplicateSignatureWork += signaturesComputed }
        if let b = best, b.isAnyMatch, !b.isActionable { crossPathMismatch += 1 }
    }

    /// Fold a long-lived-decision revalidation outcome (§2) into the counters.
    public mutating func foldRevalidation(_ outcome: GuardianRevalidationOutcomeV1) {
        switch outcome {
        case .extended: revalidationExtended += 1
        case .refusedIdentityUnstable, .refusedPolicyChanged, .refusedBudgetExhausted, .refusedNoDecision:
            revalidationRefused += 1
        }
    }

    /// Fold an Island update-chain result (§4.3): a suspended-app BLOCKED update is the known gap we count honestly.
    public mutating func foldIslandChain(_ chain: GuardianIslandUpdateChainV1) {
        if chain.blockedBySuspension { blockedIslandUpdates += 1 }
    }

    /// A one-line, privacy-safe summary for a per-session diagnostic log (no raw media/text).
    public var summary: String {
        "crossPathMismatch=\(crossPathMismatch) staleDiscards=\(staleDiscards) legacyNeedsReauthor=\(legacyNeedsReauthor) "
        + "revalExtended=\(revalidationExtended) revalRefused=\(revalidationRefused) thermalSkips=\(thermalSkips) "
        + "blockedIslandUpdates=\(blockedIslandUpdates) dupSigWork=\(duplicateSignatureWork)"
    }
}
