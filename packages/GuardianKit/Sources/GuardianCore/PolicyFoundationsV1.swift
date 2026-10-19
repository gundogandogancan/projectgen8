import Foundation

// MARK: - P009D §2/§3/§10/§11/§17 — policy foundations: safety dimensions with TRUTHFUL implementation
// states, typed reason codes, provenance, version binding, categorical admission states.
// LAW: no numeric score anywhere; statuses are never silently upgraded; UNKNOWN/REVIEW are first-class.

public enum SafetyDimensionV1: String, Sendable, Codable, CaseIterable {
    case explicitSexual = "explicit-sexual"
    case violenceGore = "violence-gore-severe-injury"
    case fearThreat = "fear-threat"
    case selfHarm = "self-harm"
    case drugsAlcohol = "drugs-alcohol"
    case gambling = "gambling"
    case dangerousBehavior = "dangerous-behavior"
    case profanity = "profanity"
    case sexualThemes = "sexual-themes"
    case sensitiveNews = "sensitive-death-disease-disaster-news"
    case manipulationAttention = "manipulation-attention-pressure"
}

/// §3 — the single source of implementation truth per dimension. NEVER silently upgraded; changing a
/// status requires new audited evidence + a version bump (test-asserted against this table).
public enum SafetyDimensionTruthV1 {
    public static let version = "safety-dimension-truth-v1"
    public static let status: [SafetyDimensionV1: EvidenceCalibrationStatusV2] = [
        .explicitSexual: .unavailable,            // H1 — no dedicated audited classifier
        .violenceGore: .unavailable,              // H1
        .fearThreat: .heuristicSupportOnly,       // TR+EN fear lexicon (+r1 supplement)
        .selfHarm: .unavailable,
        .drugsAlcohol: .unavailable,
        .gambling: .unavailable,
        .dangerousBehavior: .unavailable,
        .profanity: .unavailable,
        .sexualThemes: .unavailable,
        .sensitiveNews: .implementedUncalibrated, // real P003 lexicons via the mesh/world model
        .manipulationAttention: .implementedUncalibrated
    ]
}

/// §11 — stable typed reason codes. Every emitted code carries provenance (PolicyProvenanceV1).
public enum PolicyReasonCodeV1: String, Sendable, Codable, CaseIterable {
    case h1VisualUnavailable = "H1_VISUAL_UNAVAILABLE"
    case highRiskMultimodalConflict = "HIGH_RISK_MULTIMODAL_CONFLICT"
    case childAgeRestrictedExplicit = "CHILD_AGE_RESTRICTED_EXPLICIT"
    case childAgeRestrictedSensitive = "CHILD_AGE_RESTRICTED_SENSITIVE"
    case childAgeCautionFear = "CHILD_AGE_CAUTION_FEAR"
    case childAgeCautionSensitiveNews = "CHILD_AGE_CAUTION_SENSITIVE_NEWS"
    case childAgeCautionManipulation = "CHILD_AGE_CAUTION_MANIPULATION"
    case shieldTopicMatch = "SHIELD_TOPIC_MATCH"
    case shieldEntityMatch = "SHIELD_ENTITY_MATCH"
    case shieldUnsupportedGuessAdvisory = "SHIELD_UNSUPPORTED_GUESS_ADVISORY"
    case policyConflictUnresolved = "POLICY_CONFLICT_UNRESOLVED"
    case evidenceInsufficient = "EVIDENCE_INSUFFICIENT"
    case providerUnavailable = "PROVIDER_UNAVAILABLE"
    case identityProvisional = "IDENTITY_PROVISIONAL"
    case oodUnknown = "OOD_UNKNOWN"
    case strongRiskEscalation = "STRONG_RISK_ESCALATION"
    case ageJurisdictionUnsupported = "AGE_JURISDICTION_UNSUPPORTED"
    case ageH1RequiredUnavailable = "AGE_H1_REQUIRED_UNAVAILABLE"
    case ageSourceMissing = "AGE_SOURCE_MISSING"
    case benefitPresentNotOverriding = "BENEFIT_PRESENT_NOT_OVERRIDING"
    case contextQualifiedRisk = "CONTEXT_QUALIFIED_RISK"
    case teenSentinelUnavailableReview = "TEEN_SENTINEL_UNAVAILABLE_REVIEW"     // P009E F-5 law
    case childAgeCautionParentPreference = "CHILD_AGE_CAUTION_PARENT_PREFERENCE" // P009E F-2 fix
}

/// §17 — every policy decision binds EVERY relevant version + freshness.
public struct PolicyVersionRegistryV1: Sendable, Codable, Equatable {
    public static let policyEngineVersion = "p009d-policy-engine-v1"
    public let policyEngine: String
    public let taxonomy: String
    public let ageRegistry: String
    public let jurisdiction: String
    public let shield: String
    public let worldModel: String
    public let safetyDimensionTruth: String
    public let meshModelVersions: [String]
    public let atMs: Double
    public init(taxonomy: String = SemanticTaxonomyV1.version, ageRegistry: String, jurisdiction: String,
                shield: String, worldModel: String = ContentWorldModelV1.modelVersion,
                meshModelVersions: [String], atMs: Double) {
        self.policyEngine = Self.policyEngineVersion
        self.taxonomy = taxonomy; self.ageRegistry = ageRegistry; self.jurisdiction = jurisdiction
        self.shield = shield; self.worldModel = worldModel
        self.safetyDimensionTruth = SafetyDimensionTruthV1.version
        self.meshModelVersions = meshModelVersions; self.atMs = atMs
    }
}

public struct PolicyProvenanceV1: Sendable, Codable {
    public let code: PolicyReasonCodeV1
    public let producer: String                    // which engine emitted it
    public let basis: String                       // canonical evidence basis (derived only — never raw)
    public init(code: PolicyReasonCodeV1, producer: String, basis: String) {
        self.code = code; self.producer = producer; self.basis = basis
    }
}

/// §10 — categorical ONLY. There is no numeric field anywhere in this type (audit law).
public enum AdmissionStateV1: String, Sendable, Codable, CaseIterable {
    case strongProtection = "STRONG_PROTECTION"
    case ageRestricted = "AGE_RESTRICTED"
    case shieldMatch = "SHIELD_MATCH"
    case caution = "CAUTION"
    case ageCaution = "AGE_CAUTION"
    case unknown = "UNKNOWN"
    case review = "REVIEW"
    case neutral = "NEUTRAL"
    /// §8 canonical precedence rank (lower = stronger). Positive/benefit can never outrank 0–4.
    public var precedenceRank: Int {
        switch self {
        case .strongProtection: return 0
        case .ageRestricted: return 1
        case .shieldMatch: return 2
        case .caution, .ageCaution: return 3
        case .unknown, .review: return 4
        case .neutral: return 5
        }
    }
}

public struct AdmissionStateCandidateV1: Sendable {
    public let state: AdmissionStateV1
    public let dominantReason: PolicyProvenanceV1
    public let secondaryReasons: [PolicyProvenanceV1]
    public let unresolvedConflicts: [String]       // canonical conflict descriptors
    public let confidenceClass: SemanticKnowledgeStateV1   // categorical confidence — NOT a number
    public let versions: PolicyVersionRegistryV1
    public let childOutcome: ChildAgeOutcomeV1?    // nil when no child profile active
    public let childSourceClass: AgePolicySourceClassV1?   // P009E F-6: carried, never hardcoded in UI
    public let shieldOutcome: ShieldOutcomeV1?
    public init(state: AdmissionStateV1, dominantReason: PolicyProvenanceV1,
                secondaryReasons: [PolicyProvenanceV1], unresolvedConflicts: [String],
                confidenceClass: SemanticKnowledgeStateV1, versions: PolicyVersionRegistryV1,
                childOutcome: ChildAgeOutcomeV1?, childSourceClass: AgePolicySourceClassV1? = nil,
                shieldOutcome: ShieldOutcomeV1?) {
        self.state = state; self.dominantReason = dominantReason; self.secondaryReasons = secondaryReasons
        self.unresolvedConflicts = unresolvedConflicts; self.confidenceClass = confidenceClass
        self.versions = versions; self.childOutcome = childOutcome; self.childSourceClass = childSourceClass
        self.shieldOutcome = shieldOutcome
    }
}
