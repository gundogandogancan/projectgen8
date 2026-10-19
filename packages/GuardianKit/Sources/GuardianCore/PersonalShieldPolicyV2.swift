import Foundation

// MARK: - P009D §7 — Personal Shield V2. LAWS: consumes CANONICAL concepts/atoms only (never raw text);
// cross-language matching happens exclusively through canonical IDs; an unsupported semantic guess can
// NEVER hard-block (advisory only); match confidence is categorical and separate from policy outcome;
// local-first (in-memory config; no cloud field exists, no silent sync possible).

public struct ShieldConfigV2: Sendable {
    public static let version = "personal-shield-policy-v2"
    public let blockedConcepts: Set<String>          // canonical "concept:*" IDs only
    public let sensitiveConcepts: Set<String>        // softer class — caution, not block
    public let preferredConcepts: Set<String>        // positive preference (never outranks protection)
    public let blockedEntities: Set<String>          // canonical "entity:*" durable atom IDs only
    public let freeformGuesses: Set<String>          // UNSUPPORTED user text — advisory only, never hard-block
    public init(blockedConcepts: Set<String> = [], sensitiveConcepts: Set<String> = [],
                preferredConcepts: Set<String> = [], blockedEntities: Set<String> = [],
                freeformGuesses: Set<String> = []) {
        // §7 canonical-ID law enforced at the door: non-canonical strings are demoted to guesses
        func canonicalOnly(_ s: Set<String>, prefix: String) -> (Set<String>, Set<String>) {
            var ok = Set<String>(); var demoted = Set<String>()
            for v in s { if v.hasPrefix(prefix) { ok.insert(v) } else { demoted.insert(v) } }
            return (ok, demoted)
        }
        let (bc, d1) = canonicalOnly(blockedConcepts, prefix: "concept:")
        let (sc, d2) = canonicalOnly(sensitiveConcepts, prefix: "concept:")
        let (pc, d3) = canonicalOnly(preferredConcepts, prefix: "concept:")
        let (be, d4) = canonicalOnly(blockedEntities, prefix: "entity:")
        self.blockedConcepts = bc; self.sensitiveConcepts = sc; self.preferredConcepts = pc
        self.blockedEntities = be
        self.freeformGuesses = freeformGuesses.union(d1).union(d2).union(d3).union(d4)
    }
}

public enum ShieldMatchConfidenceV1: String, Sendable, Codable {
    case exactCanonical = "EXACT_CANONICAL"          // canonical ID equality — eligible for hard outcomes
    case advisoryGuess = "ADVISORY_GUESS"            // unsupported freeform — can NEVER hard-block
    case none = "NONE"
}

public struct ShieldOutcomeV1: Sendable {
    public let topicMatches: [String]                // matched canonical concept IDs
    public let entityMatches: [String]               // matched durable entity atoms
    public let sensitiveMatches: [String]
    public let preferredMatches: [String]
    public let advisoryGuessNotes: [String]          // "guess:<n> unsupported — advisory only" (no raw echo beyond config)
    public let matchConfidence: ShieldMatchConfidenceV1
    public let hardMatch: Bool                       // true ONLY for exact canonical blocked matches
    public let reasons: [PolicyProvenanceV1]
    public let shieldVersion: String
}

public enum PersonalShieldPolicyV2 {
    public static let revision = ShieldConfigV2.version

    public static func evaluate(worldModel m: ContentWorldModelV1, config: ShieldConfigV2) -> ShieldOutcomeV1 {
        // §7: input surface = canonical concepts + durable entity atoms from the world model ONLY
        let contentConcepts = Set((m.primaryTopics + m.secondaryTopics).map { $0.concept })
        let contentEntities = Set(m.entities.compactMap { $0.durableAtomID })
        let topicMatches = contentConcepts.intersection(config.blockedConcepts).sorted()
        let entityMatches = contentEntities.intersection(config.blockedEntities).sorted()
        let sensitiveMatches = contentConcepts.intersection(config.sensitiveConcepts).sorted()
        let preferredMatches = contentConcepts.intersection(config.preferredConcepts).sorted()
        var reasons: [PolicyProvenanceV1] = []
        for t in topicMatches { reasons.append(PolicyProvenanceV1(code: .shieldTopicMatch, producer: revision, basis: t)) }
        for e in entityMatches { reasons.append(PolicyProvenanceV1(code: .shieldEntityMatch, producer: revision, basis: e)) }
        var advisory: [String] = []
        if !config.freeformGuesses.isEmpty {
            advisory = ["unsupported-guesses:\(config.freeformGuesses.count) — advisory only, never hard-block"]
            reasons.append(PolicyProvenanceV1(code: .shieldUnsupportedGuessAdvisory, producer: revision,
                                              basis: "count:\(config.freeformGuesses.count)"))
        }
        let hard = !topicMatches.isEmpty || !entityMatches.isEmpty
        let confidence: ShieldMatchConfidenceV1 = hard ? .exactCanonical : (advisory.isEmpty ? .none : .advisoryGuess)
        return ShieldOutcomeV1(topicMatches: topicMatches, entityMatches: entityMatches,
                               sensitiveMatches: sensitiveMatches, preferredMatches: preferredMatches,
                               advisoryGuessNotes: advisory, matchConfidence: confidence, hardMatch: hard,
                               reasons: reasons, shieldVersion: revision)
    }
}
