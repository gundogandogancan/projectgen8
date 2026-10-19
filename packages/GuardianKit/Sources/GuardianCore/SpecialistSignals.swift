import Foundation

// MARK: - Specialist head result envelope (PROMPT 003 §5) + structured signal value types
// No head returns a naked Bool / final score / opaque string. Calibration separate from raw confidence;
// abstention explicit; provenance + version + language always present.

public enum AvailabilityState: String, Sendable, Codable { case available, unavailable, unknown }

public enum AbstentionReason: String, Sendable, Codable {
    case insufficientEvidence, belowConfidenceFloor, modalityMissing, notImplemented, languageUnsupported
}

public struct EvidenceRef: Sendable, Equatable, Codable {
    public let kind: String      // e.g. "lexicon", "embedding", "ocr", "entity"
    public let detail: String
    public init(kind: String, detail: String) { self.kind = kind; self.detail = detail }
}

public struct IntelligenceSignal<Value: Sendable & Equatable>: Sendable, Equatable {
    public let task: String
    public let value: Value?
    public let rawConfidence: Double?
    public let calibratedConfidence: Double?       // nil ⇒ calibration UNAVAILABLE (never fabricated)
    public let availability: AvailabilityState
    public let provenance: SignalProvenance
    public let modelVersion: String
    public let latencyNanos: UInt64
    public let evidence: [EvidenceRef]
    public let abstentionReason: AbstentionReason?
    public let language: String?

    public init(task: String, value: Value?, rawConfidence: Double?, calibratedConfidence: Double? = nil,
                availability: AvailabilityState, provenance: SignalProvenance, modelVersion: String,
                latencyNanos: UInt64 = 0, evidence: [EvidenceRef] = [], abstentionReason: AbstentionReason? = nil,
                language: String? = nil) {
        self.task = task; self.value = value; self.rawConfidence = rawConfidence
        self.calibratedConfidence = calibratedConfidence; self.availability = availability
        self.provenance = provenance; self.modelVersion = modelVersion; self.latencyNanos = latencyNanos
        self.evidence = evidence; self.abstentionReason = abstentionReason; self.language = language
    }

    public static func unavailable(task: String, version: String, reason: AbstentionReason = .notImplemented) -> IntelligenceSignal<Value> {
        .init(task: task, value: nil, rawConfidence: nil, availability: .unavailable,
              provenance: .unavailable, modelVersion: version, abstentionReason: reason)
    }
}

// MARK: Structured value types for the heads

/// H2 — mortality/disease/disaster topic labels (topic presence ≠ truth ≠ exposure preference).
public enum MortalityDiseaseDisasterLabel: String, Sendable, Equatable, Codable {
    case mortality = "MORTALITY"
    case diseaseIllness = "DISEASE_ILLNESS"
    case disaster = "DISASTER"
    case severeAccident = "SEVERE_ACCIDENT"
    case warConflict = "WAR_CONFLICT"
    case medicalHospital = "MEDICAL_HOSPITAL"
    case noneOfAbove = "NONE_OF_ABOVE"
    case unknown = "UNKNOWN"
}

/// H4 — topic/message + intent.
public enum ContentIntent: String, Sendable, Equatable, Codable {
    case informational = "INFORMATIONAL", persuasive = "PERSUASIVE", entertainment = "ENTERTAINMENT"
    case personalStory = "PERSONAL_STORY", advertisement = "ADVERTISEMENT", unknown = "UNKNOWN"
}
public struct TopicMessage: Sendable, Equatable, Codable {
    public let topics: [String]
    public let coreMessage: String?
    public let intent: ContentIntent
    public init(topics: [String], coreMessage: String?, intent: ContentIntent) {
        self.topics = topics; self.coreMessage = coreMessage; self.intent = intent
    }
}

/// H5 — attention/manipulation OBSERVED signals (lexical). OBSERVED vs INFERENCE kept separate.
public struct ManipulationSignals: Sendable, Equatable, Codable {
    public var urgency: Int = 0
    public var scarcity: Int = 0
    public var fear: Int = 0
    public var anger: Int = 0
    public var repeatedCTA: Int = 0
    public var clickbait: Int = 0
    public var total: Int { urgency + scarcity + fear + anger + repeatedCTA + clickbait }
    public init() {}
}

/// H7 — Personal Benefit VECTOR (not a single score).
public struct PersonalBenefitVector: Sendable, Equatable, Codable {
    public var learning: Double = 0
    public var skill: Double = 0
    public var practicalUsefulness: Double = 0
    public var creativity: Double = 0
    public var criticalThinking: Double = 0
    public var entertainment: Double = 0
    public var relaxation: Double = 0
    public var hopeMeaning: Double = 0
    public var fearAngerDespairLoad: Double = 0
    public var manipulationPressure: Double = 0
    public init() {}
}

// MARK: Explanation reason codes (§17) — structured, no chain-of-thought
public enum ReasonCode: String, Sendable, Equatable, Codable {
    case topicExcluded = "TOPIC_EXCLUDED"
    case graphicContentHighConfidence = "GRAPHIC_CONTENT_HIGH_CONFIDENCE"
    case positiveExposureDisease = "POSITIVE_EXPOSURE_DISEASE"
    case positiveExposureCategory = "POSITIVE_EXPOSURE_CATEGORY"
    case semanticShieldEntityMatch = "SEMANTIC_SHIELD_ENTITY_MATCH"
    case semanticShieldLowConfidence = "SEMANTIC_SHIELD_LOW_CONFIDENCE"
    case lowEvidence = "LOW_EVIDENCE"
    case personalGoalLowAlignment = "PERSONAL_GOAL_LOW_ALIGNMENT"
    case childPolicyBlock = "CHILD_POLICY_BLOCK"
    case thresholdMet = "THRESHOLD_MET"
    case thresholdNotMet = "THRESHOLD_NOT_MET"
    case manipulationPressureHigh = "MANIPULATION_PRESSURE_HIGH"
}

// MARK: Positive Exposure V1 modes (§13)
public enum PositiveExposureMode: String, Sendable, Equatable, Codable {
    case protectedPositive = "PROTECTED_POSITIVE"
    case balancedPositive = "BALANCED_POSITIVE"
    case openWithWarnings = "OPEN_WITH_WARNINGS"
}

// MARK: Spiritual Wellbeing Lens V1 (§14) — opt-in, interpretive only, never alters truth/score
public enum SpiritualValueTag: String, Sendable, Equatable, Codable, CaseIterable {
    case peace, compassion, gratitude, hope, meaning, service, nature, contemplation
}
public struct SpiritualLensV1: Sendable, Equatable, Codable {
    public let enabled: Bool
    public let values: [SpiritualValueTag]
    public init(enabled: Bool, values: [SpiritualValueTag] = []) { self.enabled = enabled; self.values = values }
}
