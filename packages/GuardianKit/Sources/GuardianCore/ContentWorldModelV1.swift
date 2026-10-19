import Foundation

// MARK: - P009C §12 — the content world model: coherent, temporal, provenance-bearing meaning.
// NOT personalized; NOT a verdict; NOT a score.

public struct ContentWorldModelV1: Sendable {
    public static let modelVersion = "content-world-model-v1"
    public let identityStatus: String                          // "provisional" | "confirmed"
    public let itemID: ContentItemID?
    public let identityRevision: UInt64
    public let generation: UInt64
    public let episodes: [SemanticEpisodeV1]
    public let primaryTopics: [TopicNodeV1]                    // ranked; multi-topic by design
    public let secondaryTopics: [TopicNodeV1]
    public let topicTransitions: [TopicTransitionV1]
    public let entities: [EntityNodeV1]
    public let intents: [IntentHypothesisV1]                   // hypotheses, ambiguity preserved
    public let intentAmbiguous: Bool
    public let events: [SemanticEventV1]
    public let causeHypotheses: [CauseHypothesisV1]            // always speculative
    public let narrativeLabels: [String]
    public let narrativeMotifs: [NarrativeMotifV1]
    public let maxRiskSeen: Double                             // monotone narrative law
    public let safetyEvidence: [String]
    public let benefitEvidence: [String]
    public let manipulationEvidence: [String]
    public let emotionalLoad: [String]
    public let contradictionResolutions: [ContradictionResolutionV1]
    public let modalityCoverage: [ExpertDomainV2: Double]
    public let uncertainty: SemanticUncertaintyV1
    public let knowledgeState: SemanticKnowledgeStateV1
    public let oodFlags: Int
    public let provenance: WorldModelProvenanceV1
    public let freshnessAtMs: Double
    public let taxonomyVersion: String
    public let meshModelVersions: [String]
    public let privacyClass: WorldModelPrivacyClassV1          // DERIVED_CACHEABLE while live
    public let anyEvidenceProvisional: Bool
    public let evidenceItemIDs: Set<UInt64>
    public let evidenceGenerations: Set<UInt64>
    /// readiness for DNA finalization — necessary, not sufficient (the finalizer re-verifies identity)
    public let readiness: Bool
}
