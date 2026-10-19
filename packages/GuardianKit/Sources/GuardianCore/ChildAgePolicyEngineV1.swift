import Foundation

// MARK: - P009D §5/§6 — child/family age policy. LAWS: age is parent/guardian-ENTERED only (never
// inferred — there is structurally no image/face input to this engine); jurisdiction-aware versioned
// bands; legal ratings are a SEPARATE source class from developmental suitability; fail-closed to
// AGE_UNKNOWN_REVIEW; no numeric child score.

public enum AgePolicySourceClassV1: String, Sendable, Codable, CaseIterable {
    case legalRating = "LEGAL_RATING"                    // statutory/board ratings (none ingested yet)
    case providerRating = "PROVIDER_RATING"              // platform-declared (none ingested yet)
    case parentPreference = "PARENT_PREFERENCE"
    case developmentalSuitability = "DEVELOPMENTAL_SUITABILITY"   // Gen8's versioned developmental policy
    case gen8Evidence = "GEN8_EVIDENCE"                  // world-model evidence feeding the above
}

public enum ChildAgeOutcomeV1: String, Sendable, Codable {
    case aligned = "AGE_ALIGNED"
    case caution = "AGE_CAUTION"
    case restricted = "AGE_RESTRICTED"
    case unknownReview = "AGE_UNKNOWN_REVIEW"
}

/// §5 — guardian-entered profile. The ONLY constructor requires the guardian attestation flag; there is
/// no API that accepts an image, a face, or an inferred age anywhere in this module.
public struct GuardianEnteredChildProfileV1: Sendable {
    public let ageYears: Int
    public let jurisdictionCode: String               // e.g. "TR", "US", "EU"
    public let enteredByGuardian: Bool                // must be true — asserted by the engine
    public let storage: String = "LOCAL_FIRST"        // §16 — local/private default; no cloud field exists
    public init(ageYears: Int, jurisdictionCode: String, enteredByGuardian: Bool) {
        self.ageYears = ageYears; self.jurisdictionCode = jurisdictionCode; self.enteredByGuardian = enteredByGuardian
    }
}

/// §5/§6 — versioned, jurisdiction-aware developmental age bands. Developmental policy ONLY — never
/// presented as a legal rating (source class is carried on every decision).
public enum JurisdictionAgeBandRegistryV1 {
    public static let version = "jurisdiction-age-band-registry-v1"
    public static let supportedJurisdictions: Set<String> = ["TR", "US", "EU"]
    public struct DimensionAgePolicyV1: Sendable {
        public let cautionUnderAge: Int               // below this: CAUTION when evidence present
        public let restrictedUnderAge: Int            // below this: RESTRICTED when evidence strong
    }
    /// Developmental thresholds for the dimensions Gen8 can actually evidence today. Identical across
    /// the three launch jurisdictions in v1 (documented); the registry structure is per-jurisdiction so
    /// future divergence is a data change, not a code change.
    public static func policy(jurisdiction: String, dimension: SafetyDimensionV1) -> DimensionAgePolicyV1? {
        guard supportedJurisdictions.contains(jurisdiction) else { return nil }   // unsupported → fail closed upstream
        switch dimension {
        case .sensitiveNews: return DimensionAgePolicyV1(cautionUnderAge: 13, restrictedUnderAge: 10)
        case .fearThreat: return DimensionAgePolicyV1(cautionUnderAge: 10, restrictedUnderAge: 7)
        case .manipulationAttention: return DimensionAgePolicyV1(cautionUnderAge: 13, restrictedUnderAge: 0)
        default: return nil                            // UNAVAILABLE dimensions cannot be banded — fail closed
        }
    }
    /// H1 visual screening is REQUIRED for young bands: with H1 open, no AGE_ALIGNED below this age.
    public static let h1RequiredUnderAge = 13
}

/// §6 — parent preference overlay (stricter-only in v1: parents can tighten, never loosen policy).
public struct ParentPreferencePolicyV1: Sendable {
    public static let version = "parent-preference-policy-v1"
    public let extraCautionDimensions: Set<SafetyDimensionV1>     // parent demands caution on ANY evidence
    public let blockSensitiveNews: Bool
    public init(extraCautionDimensions: Set<SafetyDimensionV1> = [], blockSensitiveNews: Bool = false) {
        self.extraCautionDimensions = extraCautionDimensions; self.blockSensitiveNews = blockSensitiveNews
    }
}

public struct ChildAgeDecisionV1: Sendable {
    public let outcome: ChildAgeOutcomeV1
    public let sourceClass: AgePolicySourceClassV1    // every decision records its source (§6)
    public let reasons: [PolicyProvenanceV1]
    public let jurisdictionSupported: Bool
    public let registryVersion: String
}

public enum ChildAgePolicyEngineV1 {
    public static let revision = "child-age-policy-engine-v1"

    public static func evaluate(profile: GuardianEnteredChildProfileV1, safety: SafetyPolicyResultV1,
                                worldModel m: ContentWorldModelV1,
                                parentPreference: ParentPreferencePolicyV1 = ParentPreferencePolicyV1()) -> ChildAgeDecisionV1 {
        var reasons: [PolicyProvenanceV1] = []
        // §5: guardian attestation is mandatory — no attestation, no child decision (fail closed)
        guard profile.enteredByGuardian else {
            return ChildAgeDecisionV1(outcome: .unknownReview, sourceClass: .parentPreference,
                                      reasons: [PolicyProvenanceV1(code: .ageSourceMissing, producer: revision,
                                                                   basis: "child age not guardian-attested")],
                                      jurisdictionSupported: false, registryVersion: JurisdictionAgeBandRegistryV1.version)
        }
        // §12: unsupported jurisdiction → fail closed
        guard JurisdictionAgeBandRegistryV1.supportedJurisdictions.contains(profile.jurisdictionCode) else {
            return ChildAgeDecisionV1(outcome: .unknownReview, sourceClass: .developmentalSuitability,
                                      reasons: [PolicyProvenanceV1(code: .ageJurisdictionUnsupported, producer: revision,
                                                                   basis: "jurisdiction:\(profile.jurisdictionCode) not in registry \(JurisdictionAgeBandRegistryV1.version)")],
                                      jurisdictionSupported: false, registryVersion: JurisdictionAgeBandRegistryV1.version)
        }
        var outcome: ChildAgeOutcomeV1 = .aligned
        func escalate(_ to: ChildAgeOutcomeV1) {
            let order: [ChildAgeOutcomeV1] = [.aligned, .caution, .unknownReview, .restricted]
            if order.firstIndex(of: to)! > order.firstIndex(of: outcome)! { outcome = to }
        }
        // evidence-bearing dimensions against the versioned developmental bands
        for f in safety.findings where f.status != .unavailable && f.evidencePresent {
            guard let band = JurisdictionAgeBandRegistryV1.policy(jurisdiction: profile.jurisdictionCode, dimension: f.dimension) else { continue }
            if f.severityBand == "strong" && profile.ageYears < band.restrictedUnderAge {
                escalate(.restricted)
                reasons.append(PolicyProvenanceV1(code: .childAgeRestrictedSensitive, producer: revision,
                                                  basis: "\(f.dimension.rawValue) strong < age \(band.restrictedUnderAge)"))
            } else if profile.ageYears < band.cautionUnderAge {
                escalate(.caution)
                let code: PolicyReasonCodeV1 = f.dimension == .fearThreat ? .childAgeCautionFear
                    : (f.dimension == .manipulationAttention ? .childAgeCautionManipulation : .childAgeCautionSensitiveNews)
                reasons.append(PolicyProvenanceV1(code: code, producer: revision,
                                                  basis: "\(f.dimension.rawValue) present < age \(band.cautionUnderAge)"))
            }
        }
        // parent preference overlay — stricter only
        for f in safety.findings where f.evidencePresent && parentPreference.extraCautionDimensions.contains(f.dimension) {
            escalate(.caution)
            reasons.append(PolicyProvenanceV1(code: .childAgeCautionSensitiveNews, producer: revision,
                                              basis: "parent-preference extra caution: \(f.dimension.rawValue)"))
        }
        if parentPreference.blockSensitiveNews,
           safety.findings.contains(where: { $0.dimension == .sensitiveNews && $0.evidencePresent }) {
            escalate(.restricted)
            reasons.append(PolicyProvenanceV1(code: .childAgeRestrictedSensitive, producer: revision,
                                              basis: "parent-preference blocks sensitive news"))
        }
        // §12 fail-closed: young bands REQUIRE visual screening; H1 is open → never AGE_ALIGNED.
        // The H1 gap is ALWAYS visible for under-13 decisions (reason code on every route), and an
        // otherwise-aligned outcome escalates to UNKNOWN_REVIEW. A lexical CAUTION/RESTRICTED outcome is
        // itself an acceptable fail-closed state per §12 (CAUTION is stricter than review in practice).
        if profile.ageYears < JurisdictionAgeBandRegistryV1.h1RequiredUnderAge {
            reasons.append(PolicyProvenanceV1(code: .ageH1RequiredUnavailable, producer: revision,
                                              basis: "age<\(JurisdictionAgeBandRegistryV1.h1RequiredUnderAge) requires H1 visual screening — UNAVAILABLE_EVIDENCE_BACKED"))
            if outcome == .aligned { outcome = .unknownReview }
        }
        // identity/evidence insufficiency also fails closed
        if m.identityStatus != "confirmed" || m.knowledgeState == .unavailable || m.knowledgeState == .unknown {
            if outcome == .aligned { outcome = .unknownReview }
            reasons.append(PolicyProvenanceV1(code: m.identityStatus != "confirmed" ? .identityProvisional : .evidenceInsufficient,
                                              producer: revision, basis: "identity=\(m.identityStatus) knowledge=\(m.knowledgeState.rawValue)"))
        }
        let source: AgePolicySourceClassV1 = reasons.contains { $0.basis.hasPrefix("parent-preference") } ? .parentPreference : .developmentalSuitability
        return ChildAgeDecisionV1(outcome: outcome, sourceClass: source, reasons: reasons,
                                  jurisdictionSupported: true, registryVersion: JurisdictionAgeBandRegistryV1.version)
    }
}

/// §6 — source-truth separation record: developmental policy may never masquerade as a legal rating.
public enum AgeSuitabilityPolicyV1 {
    public static let version = "age-suitability-policy-v1"
    public static let legalRatingsIngested = false       // honest: no legal/provider rating feed exists
    public static let providerRatingsIngested = false
    public static func presentableAsLegalRating(_ d: ChildAgeDecisionV1) -> Bool {
        d.sourceClass == .legalRating                    // structurally false today — test-asserted
    }
}
