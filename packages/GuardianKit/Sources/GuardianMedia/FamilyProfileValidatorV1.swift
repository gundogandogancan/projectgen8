//
//  FamilyProfileValidatorV1.swift — R6 §2.1 (P0-2): STORE-LEVEL DOMAIN VALIDATION for the family profile.
//
//  WHY (mandate §2.1 — binding): SwiftUI form validation is NOT enough. A profile persisted by an older build, a
//  corrupted-but-still-decodable blob, or a hand-tampered file can carry an INVALID child/teen record (an impossible
//  age, an adult record still holding a child age, an unsupported jurisdiction, a declaration/age mismatch, or a
//  schema/revision inconsistency). R5 only rejected a profile that FAILED TO DECODE. A record that decodes but is
//  semantically invalid was loaded as VALID — and a wrong age could then reach the frozen ChildAgePolicyEngineV1.
//  The law: an invalid CHILD/TEEN profile must load as FAIL_CLOSED/REVIEW, NEVER as VALID with a wrong age.
//
//  WHAT THIS DOES: a PURE validator (no I/O) that classifies a decoded FamilyProfileV1 against the canonical domain
//  rules, deriving a precise reason when it fails. The store calls it after a successful decode; a failure downgrades
//  the load state so the extension's adjudicator fails closed exactly like a STALE/CORRUPT read (the old child policy
//  is never shown as current). Age bands come from the FROZEN JurisdictionAgeBandRegistryV1 (CHILD < 13, TEEN 13–17,
//  ADULT ≥ 18 — the H1-required-under-age boundary is the canonical child/teen split); jurisdiction support comes
//  from the frozen registry too (no duplicate policy here).
//
//  Pure + headless + versioned + testable. Lives in GuardianMedia (GuardianCore frozen). Dual-compiled app+extension.
//
import Foundation
import GuardianCore

// MARK: - §2.1 — the precise reason a persisted profile is domain-invalid (for the proof log + fail-closed state).

public enum FamilyProfileValidationFailureV1: String, Sendable, Equatable, Codable {
    case childAgeOutOfBand      = "CHILD_AGE_OUT_OF_BAND"      // CHILD mode but the age is not under 13 (or missing)
    case teenAgeOutOfBand       = "TEEN_AGE_OUT_OF_BAND"       // TEEN mode but the age is not in 13–17 (or missing)
    case adultCarriesChildField = "ADULT_CARRIES_CHILD_FIELD"  // ADULT mode must not carry a child age
    case unsupportedJurisdiction = "UNSUPPORTED_JURISDICTION"  // jurisdiction not in the frozen registry
    case declarationAgeInconsistent = "DECLARATION_AGE_INCONSISTENT" // child/teen with an age but no parent declaration
    case schemaInconsistent     = "SCHEMA_INCONSISTENT"        // schema version is not a known supported schema
    case revisionInconsistent   = "REVISION_INCONSISTENT"      // embedded revision is impossible (e.g. negative/overflow sentinel)
}

public struct FamilyProfileValidationResultV1: Sendable, Equatable {
    public let isValid: Bool
    /// The failures found (empty iff valid). ALL failures are listed so the proof log is complete, not just the first.
    public let failures: [FamilyProfileValidationFailureV1]
    public init(isValid: Bool, failures: [FamilyProfileValidationFailureV1]) {
        self.isValid = isValid; self.failures = failures
    }
}

public enum FamilyProfileValidatorV1 {
    public static let version = "family-profile-validator-v1"
    /// The canonical CHILD/TEEN boundary = the frozen registry's H1-required-under-age (13). Below it = CHILD; 13…17 =
    /// TEEN; 18+ = adult-equivalent (a child/teen record claiming an adult age is out-of-band).
    public static var childUnderAge: Int { JurisdictionAgeBandRegistryV1.h1RequiredUnderAge }     // 13
    public static let teenRange: ClosedRange<Int> = 13...17
    /// A plausible entered-age envelope (a profile claiming age 0 or 200 is corrupt, not a real toddler/elder entry).
    public static let plausibleAgeRange: ClosedRange<Int> = 1...17   // only minors are ever stored as child/teen ages

    /// R6 §2.1 — validate a DECODED profile against the canonical domain rules. Pure: same input → same result.
    public static func validate(_ p: FamilyProfileV1) -> FamilyProfileValidationResultV1 {
        var failures: [FamilyProfileValidationFailureV1] = []

        // Schema: only the known supported schema version is accepted (a future schema loads as inconsistent → the
        // store treats it like CORRUPT/stale, never silently as a current child policy).
        if p.schema != FamilyProfileV1.schemaVersion { failures.append(.schemaInconsistent) }

        // Revision: the embedded monotonic revision must be a real published value. The sentinel/overflow guard keeps
        // a tampered record from reading as a plausible fresh policy (a 0 revision is only legal on a never-published
        // record, which the store never persists — a persisted record always carries target >= 1).
        if p.profileRevision == 0 && p.mode != .adult { failures.append(.revisionInconsistent) }

        // Jurisdiction: must be in the FROZEN registry for ANY mode that can produce a child decision.
        let jurisdictionSupported = JurisdictionAgeBandRegistryV1.supportedJurisdictions.contains(p.jurisdictionCode)
        if p.mode != .adult && !jurisdictionSupported { failures.append(.unsupportedJurisdiction) }

        switch p.mode {
        case .adult:
            // ADULT must not carry a child age field (a leftover child age on an adult record is invalid state).
            if p.parentEnteredAgeYears != nil { failures.append(.adultCarriesChildField) }
        case .child:
            guard let age = p.parentEnteredAgeYears else { failures.append(.childAgeOutOfBand); break }
            if !plausibleAgeRange.contains(age) || age >= childUnderAge { failures.append(.childAgeOutOfBand) }
            if !p.parentDeclaration { failures.append(.declarationAgeInconsistent) }
        case .teen:
            guard let age = p.parentEnteredAgeYears else { failures.append(.teenAgeOutOfBand); break }
            if !teenRange.contains(age) { failures.append(.teenAgeOutOfBand) }
            if !p.parentDeclaration { failures.append(.declarationAgeInconsistent) }
        }

        return FamilyProfileValidationResultV1(isValid: failures.isEmpty, failures: failures)
    }
}
