import Foundation

// MARK: - Universal multimodal content understanding (PROMPT 008 §2,§15)
// "Understand the content before scoring it." Every signal carries provenance; no naked unproven label.
// Content CHARACTER ≠ protection/risk ≠ personal suitability — kept strictly separate.

public enum Modality: String, Sendable, Codable, CaseIterable {
    case structuredText = "STRUCTURED_TEXT", caption = "CAPTION", transcript = "TRANSCRIPT", ocr = "OCR"
    case visual = "VISUAL", audio = "AUDIO", speech = "SPEECH", music = "MUSIC", symbol = "SYMBOL"
    case temporal = "TEMPORAL", metadata = "METADATA"
}

public enum EvidenceClass: String, Sendable, Codable {
    case observedFact = "OBSERVED_FACT", modelInference = "MODEL_INFERENCE", lexiconRule = "LEXICON_RULE"
    case weakSignal = "WEAK_SIGNAL", providerMetadata = "PROVIDER_METADATA", unavailable = "UNAVAILABLE"
}

/// One provenance-bearing evidence signal. `calibratedConfidence == nil` ⇒ UNAVAILABLE (never fabricated).
public struct ModalEvidenceSignal: Sendable, Codable, Equatable {
    public var modality: Modality
    public var kind: String                 // e.g. "topic", "entity", "sensitive-category", "manipulation", "sound-event"
    public var value: String
    public var rawConfidence: Double?
    public var calibratedConfidence: Double?
    public var evidenceClass: EvidenceClass
    public var modelID: String
    public var modelRevision: String
    public var language: String?
    public var timeStartSec: Double?
    public var timeEndSec: Double?
    public var rawMediaRetention: String    // "none" | "ephemeral" | "derived-only"
    public init(modality: Modality, kind: String, value: String, rawConfidence: Double? = nil,
                calibratedConfidence: Double? = nil, evidenceClass: EvidenceClass, modelID: String, modelRevision: String,
                language: String? = nil, timeStartSec: Double? = nil, timeEndSec: Double? = nil,
                rawMediaRetention: String = "none") {
        self.modality = modality; self.kind = kind; self.value = value; self.rawConfidence = rawConfidence
        self.calibratedConfidence = calibratedConfidence; self.evidenceClass = evidenceClass; self.modelID = modelID
        self.modelRevision = modelRevision; self.language = language; self.timeStartSec = timeStartSec
        self.timeEndSec = timeEndSec; self.rawMediaRetention = rawMediaRetention
    }
}

public enum ContentIdentityConfidence: String, Sendable, Codable { case exact = "EXACT", strong = "STRONG", provisional = "PROVISIONAL", unknown = "UNKNOWN" }

/// The versioned understanding object produced BEFORE any score. NON-personal (no user policy/score here).
public struct MultimodalContentUnderstandingV1: Sendable, Codable, Equatable {
    public static let schemaVersion = "mmu-v1"
    public var contentID: String
    public var identityConfidence: ContentIdentityConfidence
    public var sourceSurface: String
    public var languageCandidates: [String]
    public var modalitiesObserved: [Modality]
    public var modalitiesUnavailable: [Modality]
    public var evidence: [ModalEvidenceSignal]
    public var topicHypotheses: [String]
    public var entityHypotheses: [String]
    public var crossModalAgreements: [String]
    public var crossModalConflicts: [String]
    public var evidenceCoverage: Double      // 0..1 fraction of expected modalities that produced determinable evidence
    public var uncertainty: Double           // 0..1
    public var modelPackRevision: String
    public var createdAtEpoch: Double
    public init(contentID: String, identityConfidence: ContentIdentityConfidence = .provisional, sourceSurface: String = "unknown",
                languageCandidates: [String] = [], modalitiesObserved: [Modality] = [], modalitiesUnavailable: [Modality] = [],
                evidence: [ModalEvidenceSignal] = [], topicHypotheses: [String] = [], entityHypotheses: [String] = [],
                crossModalAgreements: [String] = [], crossModalConflicts: [String] = [], evidenceCoverage: Double = 0,
                uncertainty: Double = 1, modelPackRevision: String = "pack-v1", createdAtEpoch: Double = 0) {
        self.contentID = contentID; self.identityConfidence = identityConfidence; self.sourceSurface = sourceSurface
        self.languageCandidates = languageCandidates; self.modalitiesObserved = modalitiesObserved
        self.modalitiesUnavailable = modalitiesUnavailable; self.evidence = evidence; self.topicHypotheses = topicHypotheses
        self.entityHypotheses = entityHypotheses; self.crossModalAgreements = crossModalAgreements
        self.crossModalConflicts = crossModalConflicts; self.evidenceCoverage = evidenceCoverage; self.uncertainty = uncertainty
        self.modelPackRevision = modelPackRevision; self.createdAtEpoch = createdAtEpoch
    }
    public func evidence(for m: Modality) -> [ModalEvidenceSignal] { evidence.filter { $0.modality == m } }
}
