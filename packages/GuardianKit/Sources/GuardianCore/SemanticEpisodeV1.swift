import Foundation

// MARK: - P009C §3/§18 — semantic episodes (bounded semantic units, not shots) + context tags.

/// §18 context qualifiers — may QUALIFY lexical evidence; can never erase strong multimodal risk.
public enum SemanticContextTagV1: String, Sendable, Codable, CaseIterable {
    case literal = "context:literal"
    case quoted = "context:quoted"
    case educationalMention = "context:educational-mention"
    case satireHumorCandidate = "context:satire-humor-candidate"
    case dramatizationFictionCandidate = "context:dramatization-fiction-candidate"
    case unknownContext = "context:unknown"
}

public struct SemanticEpisodeV1: Sendable {
    public let episodeID: UInt64
    public var startMs: Double
    public var endMs: Double
    public var shotIDs: [ShotID]
    public let itemID: ContentItemID?
    public let itemProvisional: Bool
    public var topicCandidates: [String]           // canonical concept IDs
    public var entityCandidates: [String]          // canonical entity forms
    public var intentCandidates: [String]          // canonical intent hypotheses
    public var safetyEvidence: [String]
    public var benefitEvidence: [String]
    public var manipulationEvidence: [String]
    public var emotionalLoad: [String]
    public var contextTags: [SemanticContextTagV1]
    public var modalityCoverage: [ExpertDomainV2: Double]
    public var contradictions: Int
    public var confidence: Double
    public var uncertainty: Double
    public var oodFlags: Int
    public var provenance: [String]
    public var revision: UInt32                    // bumped on merge/split/reinterpretation
    public var stale: Bool = false
    public let generation: UInt64

    public init(episodeID: UInt64, startMs: Double, endMs: Double, shotIDs: [ShotID], itemID: ContentItemID?,
                itemProvisional: Bool, topicCandidates: [String] = [], entityCandidates: [String] = [],
                intentCandidates: [String] = [], safetyEvidence: [String] = [], benefitEvidence: [String] = [],
                manipulationEvidence: [String] = [], emotionalLoad: [String] = [],
                contextTags: [SemanticContextTagV1] = [], modalityCoverage: [ExpertDomainV2: Double] = [:],
                contradictions: Int = 0, confidence: Double = 0, uncertainty: Double = 1, oodFlags: Int = 0,
                provenance: [String] = [], revision: UInt32 = 1, generation: UInt64) {
        self.episodeID = episodeID; self.startMs = startMs; self.endMs = endMs; self.shotIDs = shotIDs
        self.itemID = itemID; self.itemProvisional = itemProvisional
        self.topicCandidates = topicCandidates; self.entityCandidates = entityCandidates
        self.intentCandidates = intentCandidates; self.safetyEvidence = safetyEvidence
        self.benefitEvidence = benefitEvidence; self.manipulationEvidence = manipulationEvidence
        self.emotionalLoad = emotionalLoad; self.contextTags = contextTags
        self.modalityCoverage = modalityCoverage; self.contradictions = contradictions
        self.confidence = confidence; self.uncertainty = uncertainty; self.oodFlags = oodFlags
        self.provenance = provenance; self.revision = revision; self.generation = generation
    }

    /// Episodes MERGE when adjacent, same identity, and sharing a dominant topic — revision bumps,
    /// provenance union, uncertainty = max (merging can never manufacture certainty).
    public static func merge(_ a: SemanticEpisodeV1, _ b: SemanticEpisodeV1, newID: UInt64) -> SemanticEpisodeV1? {
        guard a.itemID == b.itemID, a.generation == b.generation, !a.stale, !b.stale,
              !Set(a.topicCandidates).isDisjoint(with: Set(b.topicCandidates)) || a.topicCandidates.isEmpty else { return nil }
        return SemanticEpisodeV1(episodeID: newID, startMs: min(a.startMs, b.startMs), endMs: max(a.endMs, b.endMs),
                                 shotIDs: a.shotIDs + b.shotIDs, itemID: a.itemID,
                                 itemProvisional: a.itemProvisional || b.itemProvisional,
                                 topicCandidates: Array(Set(a.topicCandidates).union(b.topicCandidates)).sorted(),
                                 entityCandidates: Array(Set(a.entityCandidates).union(b.entityCandidates)).sorted(),
                                 intentCandidates: Array(Set(a.intentCandidates).union(b.intentCandidates)).sorted(),
                                 safetyEvidence: Array(Set(a.safetyEvidence).union(b.safetyEvidence)).sorted(),
                                 benefitEvidence: Array(Set(a.benefitEvidence).union(b.benefitEvidence)).sorted(),
                                 manipulationEvidence: Array(Set(a.manipulationEvidence).union(b.manipulationEvidence)).sorted(),
                                 emotionalLoad: Array(Set(a.emotionalLoad).union(b.emotionalLoad)).sorted(),
                                 contextTags: Array(Set(a.contextTags.map(\.rawValue)).union(b.contextTags.map(\.rawValue)))
                                    .compactMap { SemanticContextTagV1(rawValue: $0) },
                                 modalityCoverage: a.modalityCoverage.merging(b.modalityCoverage) { max($0, $1) },
                                 contradictions: a.contradictions + b.contradictions,
                                 confidence: min(a.confidence, b.confidence),
                                 uncertainty: max(a.uncertainty, b.uncertainty),
                                 oodFlags: a.oodFlags + b.oodFlags,
                                 provenance: a.provenance + b.provenance,
                                 revision: max(a.revision, b.revision) &+ 1, generation: a.generation)
    }
}
