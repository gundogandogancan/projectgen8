import Foundation

// MARK: - P009C §4/§19 — topic graph + TR+EN multilingual canonical taxonomy (versioned).

/// §19 canonical concept taxonomy — TR+EN mapped to ONE concept ID. Versioned; translation-equivalent
/// mapping is explicit; translation is never used to fake held-out independence (corpus law).
public enum SemanticTaxonomyV1 {
    public static let version = "p009c-taxonomy-v1"
    /// concept ID → (en terms, tr terms). Built on the REAL P003 lexicons + P009B label canon — no duplication:
    /// lexical HITS still come from `Lexicons`; this maps hit/label families to canonical concepts.
    public static let conceptForLabel: [String: String] = [
        // from languageOCR/safety evidence labels
        "topic:mortality": "concept:mortality", "topic:disease": "concept:disease", "topic:disaster": "concept:disaster",
        "safety:sensitive-death-disease-news": "concept:sensitive-news",
        "safety:fear-threat-candidate": "concept:fear-threat",
        "pattern:manipulation-language": "concept:manipulation-language",
        "pattern:emotional-language": "concept:emotional-language",
        // from benefit evidence
        "benefit:educational-candidate": "concept:education", "benefit:calm-nature-candidate": "concept:calm-nature",
        "benefit:music-presence": "concept:music",
        // from attention evidence
        "attention:rapid-edit-density": "concept:rapid-editing", "attention:urgency-language": "concept:urgency",
        "attention:cta-clickbait": "concept:cta-engagement",
        // from audio/music/speech
        "audio:siren": "concept:emergency-sound", "audio:alarm": "concept:emergency-sound",
        "audio:nature": "concept:calm-nature", "audio:water": "concept:calm-nature",
        "audio:music": "concept:music", "music:present": "concept:music",
        "audio:crowd": "concept:crowd", "audio:applause": "concept:performance",
        "audio:traffic": "concept:traffic", "audio:engine": "concept:traffic",
        // symbols
        "symbol:warning-candidates": "concept:warning-symbolism", "symbol:positive-candidates": "concept:positive-symbolism"
    ]
    /// locale synonym normalization for scene labels (provider labels → canonical scene concepts)
    public static let sceneConcept: [String: String] = [
        "forest": "concept:calm-nature", "river": "concept:calm-nature", "mountain": "concept:calm-nature",
        "lake": "concept:calm-nature", "spa": "concept:calm-nature", "candles": "concept:calm-nature",
        "whiteboard": "concept:education", "classroom": "concept:education", "laboratory": "concept:education",
        "workshop": "concept:education", "workbench": "concept:education",
        "kitchen": "concept:cooking", "cooking-pan": "concept:cooking",
        "party": "concept:celebration", "balloons": "concept:celebration", "wedding": "concept:celebration",
        "warning-sign": "concept:warning-symbolism", "caution-tape": "concept:warning-symbolism",
        "person-speaking": "concept:talking-head", "street": "concept:urban", "smoke": "concept:incident-visual"
    ]
    /// map a mesh evidence label to a canonical concept (nil = no concept claim; NOT forced)
    public static func concept(for label: String) -> String? {
        if let c = conceptForLabel[label] { return c }
        for (prefix, c) in conceptForLabel where label.hasPrefix(prefix) { return c }
        if label.hasPrefix("scene:") {
            let scene = String(label.dropFirst("scene:".count))
            return sceneConcept[scene]
        }
        return nil
    }
    /// §18 satire/humor cues (project-authored heuristic; qualifier evidence only, never verdicts)
    public static let satireHumorCues: [String] = ["lol", "😂", "parody", "parodi", "skeç", "şaka", "just kidding",
                                                   "komedi", "comedy sketch", "mizah"]
    public static let quoteCues: [String] = ["\"", "“", "”", "dedi ki", " said ", "quote:", "alıntı"]
}

public struct TopicNodeV1: Sendable {
    public let concept: String
    public var episodeCount: Int              // persistence
    public var totalWeight: Double            // dominance (weighted evidence, NOT averaged confidence)
    public var firstSeenMs: Double
    public var lastSeenMs: Double
    public var uncertainty: Double
    public var provenance: [String]
}

public struct TopicTransitionV1: Sendable {
    public let fromConcept: String
    public let toConcept: String
    public let atMs: Double
}

/// §4 — multi-topic by design: ranked candidates, transitions, persistence, dominance; no forced single label.
public final class TopicGraphV1: @unchecked Sendable {
    public static let revision = "topic-graph-v1/\(SemanticTaxonomyV1.version)"
    private(set) public var nodes: [String: TopicNodeV1] = [:]
    private(set) public var transitions: [TopicTransitionV1] = []
    public let maxNodes: Int, maxTransitions: Int
    private var lastDominant: String?
    private let lock = NSLock()
    public init(maxNodes: Int = 64, maxTransitions: Int = 128) { self.maxNodes = maxNodes; self.maxTransitions = maxTransitions }

    public func observe(concept: String, weight: Double, uncertainty: Double, atMs: Double, provenance: String) {
        lock.lock(); defer { lock.unlock() }
        if var n = nodes[concept] {
            n.episodeCount += 1; n.totalWeight += max(0, weight); n.lastSeenMs = atMs
            n.uncertainty = min(n.uncertainty, uncertainty)
            if n.provenance.count < 16 { n.provenance.append(provenance) }
            nodes[concept] = n
        } else {
            guard nodes.count < maxNodes else { return }      // bounded — overflow is dropped, never corrupted
            nodes[concept] = TopicNodeV1(concept: concept, episodeCount: 1, totalWeight: max(0, weight),
                                         firstSeenMs: atMs, lastSeenMs: atMs, uncertainty: uncertainty,
                                         provenance: [provenance])
        }
        let dominant = dominantLocked()
        if let d = dominant, let prev = lastDominant, d != prev, transitions.count < maxTransitions {
            transitions.append(TopicTransitionV1(fromConcept: prev, toConcept: d, atMs: atMs))
        }
        if let d = dominant { lastDominant = d }
    }
    private func dominantLocked() -> String? { nodes.values.max { $0.totalWeight < $1.totalWeight }?.concept }
    /// ranked topics — ALL candidates, never a forced single classification
    public func ranked() -> [TopicNodeV1] {
        lock.lock(); defer { lock.unlock() }
        return nodes.values.sorted { $0.totalWeight > $1.totalWeight }
    }
    public var transitionCount: Int { lock.lock(); defer { lock.unlock() }; return transitions.count }
}
