//
//  GuardianSelfEvalCountersV1.swift — R3 §9: MEASURABLE self-evaluation counters for the NEW R3 signals.
//
//  WHY THIS EXISTS (R3 §9): OCTOPUS continues to improve its own work quality, but ONLY with INDEPENDENT ground truth
//  and ONLY via SAFE resource/scheduling optimisations — NEVER by silently changing the user shield, child-safety, or
//  model thresholds (mandate §9). This type is a pure, bounded, derived-scalar accumulator for the honest signals the
//  R3 work produces, so the app/extension can surface "what the system measured about itself" without any hidden
//  behaviour change. It stores COUNTS only — never raw frames/OCR/titles (privacy).
//
//  R4 §2D — COUNTER SEMANTICS HONESTY FIX. The old `crossPathMismatch` name implied it measured a FALSE NEGATIVE
//  (a real match we missed). It does NOT: without an INDEPENDENT truth label it can only count a reference that
//  matched BELOW the actionable bar — a NON-ACTIONABLE VISUAL CANDIDATE, which may be a correct non-match just as
//  easily as a missed one. Calling that a "mismatch" / implying error was dishonest. It is renamed
//  `nonActionableVisualCandidate` and a SEPARATE counter `independentlyLabeledModelError` is reserved for the ONLY
//  thing that is a real model error: a divergence from an INDEPENDENT ground-truth label. That counter stays ZERO
//  until such labels exist (no self-graded "error"). (Mandate §9: self-eval never treats its own guess as truth.)
//
//  The counters map 1:1 onto the mandate's §9 list that R3/R4 can honestly produce:
//    • nonActionableVisualCandidate — a reference matched only below the ACTIONABLE bar (any-match but not HIGH/EXACT).
//                              A NON-ACTIONABLE CANDIDATE, NOT a false negative (no independent truth label exists) —
//                              a resource/precision signal, so a regression in match-rate is visible. (R4 §2D rename.)
//    • independentlyLabeledModelError — RESERVED: a divergence from an INDEPENDENT ground-truth label (a real model
//                              error). Zero until labelled data exists — the system NEVER counts its own guess as error.
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
    /// R4 §2D — a reference that matched BELOW the actionable bar (any-match, not HIGH/EXACT). A NON-ACTIONABLE
    /// VISUAL CANDIDATE — NOT a false negative (no independent truth label). Renamed from the misleading
    /// `crossPathMismatch`. A resource/precision signal only.
    public var nonActionableVisualCandidate: Int = 0
    /// R4 §2D — RESERVED for a divergence from an INDEPENDENT ground-truth label (a real model error). Stays ZERO
    /// until labelled data exists; the system never counts its own prediction as an error (mandate §9).
    public var independentlyLabeledModelError: Int = 0
    public var staleDiscards: Int = 0
    public var legacyNeedsReauthor: Int = 0
    public var revalidationExtended: Int = 0
    public var revalidationRefused: Int = 0
    public var thermalSkips: Int = 0
    public var blockedIslandUpdates: Int = 0
    public var duplicateSignatureWork: Int = 0
    // R5 §10 — NEW measure-only counters (counts only; never a behaviour change, never a self-graded "error"):
    /// The emotional-register adapter ABSTAINED (UNKNOWN) on a SUPPORTED language — a coverage signal for the new
    /// register capability (NOT a misread claim: without independent labels an abstention is not an error).
    public var registerSupportedAbstentions: Int = 0
    /// A family-profile read came back DEGRADED (STALE/CORRUPT) — each one is a real fail-closed event the parent
    /// should eventually see (the §2 stale-read error class).
    public var familyProfileDegradedReads: Int = 0
    /// Honest modality gaps the world-model bridge declared UNAVAILABLE (per bridged item, summed) — the §4
    /// coverage-gap magnitude (how much of the world model is running on text alone).
    public var bridgeUnavailableModalityRecords: Int = 0

    public init() {}

    /// R5 §10 — fold the per-item R5 signals (register verdict / family read state / bridge coverage) into the
    /// measure-only counters. Pure counting; no thresholds, no behaviour.
    public mutating func foldR5(registerWasSupportedUnknown: Bool, familyReadDegraded: Bool,
                                bridgeUnavailableCount: Int) {
        if registerWasSupportedUnknown { registerSupportedAbstentions += 1 }
        if familyReadDegraded { familyProfileDegradedReads += 1 }
        bridgeUnavailableModalityRecords += max(0, bridgeUnavailableCount)
    }

    /// Fold a photo-shield pass result into the counters (derived scalars only). `discardedStale` is whether the
    /// caller's §B5 firewall dropped the best match because it was for a prior item (the caller's resolved item
    /// revision — a real identity fact, not the pipeline's own guess). A best match that is ANY-match but NOT
    /// actionable is a NON-ACTIONABLE VISUAL CANDIDATE (R4 §2D) — honestly a resource/precision signal, NOT a false
    /// negative (we have no independent label telling us it SHOULD have matched).
    public mutating func foldPhotoPass(best: PhotoShieldLiveMatchV1?, legacyNeedsReauthor: Int,
                                       signaturesComputed: Int, reusedCachedSignature: Bool,
                                       discardedStale: Bool, thermalSkipped: Bool) {
        self.legacyNeedsReauthor += legacyNeedsReauthor
        if thermalSkipped { thermalSkips += 1 }
        if discardedStale { staleDiscards += 1 }
        if reusedCachedSignature && signaturesComputed > 0 { duplicateSignatureWork += signaturesComputed }
        if let b = best, b.isAnyMatch, !b.isActionable { nonActionableVisualCandidate += 1 }
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

    /// A one-line, privacy-safe summary for a per-session diagnostic log (no raw media/text). R4 §2D: the counter is
    /// named for what it HONESTLY measures (non-actionable candidates), and the reserved independent-error counter is
    /// surfaced so its zero value is visible (it is a RESERVED slot, not an omission).
    public var summary: String {
        "nonActionableVisualCandidate=\(nonActionableVisualCandidate) independentlyLabeledModelError=\(independentlyLabeledModelError) "
        + "staleDiscards=\(staleDiscards) legacyNeedsReauthor=\(legacyNeedsReauthor) "
        + "revalExtended=\(revalidationExtended) revalRefused=\(revalidationRefused) thermalSkips=\(thermalSkips) "
        + "blockedIslandUpdates=\(blockedIslandUpdates) dupSigWork=\(duplicateSignatureWork) "
        + "registerAbstain=\(registerSupportedAbstentions) familyDegradedReads=\(familyProfileDegradedReads) "
        + "bridgeUnavailableRecords=\(bridgeUnavailableModalityRecords)"
    }
}
