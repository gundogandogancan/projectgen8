import Foundation
import NaturalLanguage
import GuardianCore

// MARK: - Apple NaturalLanguage semantic embedding provider (PROMPT 002 §2C) — REAL where available
// NLEmbedding shared instances are NOT concurrency-safe → isolate in an actor (serialized access).
// If an embedding is unavailable for a language on this runtime, return UNAVAILABLE — never fake it.

public actor SemanticEmbeddingProvider: SemanticMatchPort {
    public nonisolated let engineVersion = "apple-nl-embedding-v1"
    private var cache: [String: NLEmbedding] = [:]

    public init() {}

    private func embedding(for language: NLLanguage) -> NLEmbedding? {
        let key = language.rawValue
        if let e = cache[key] { return e }
        // Prefer sentence embedding; fall back to word embedding.
        let e = NLEmbedding.sentenceEmbedding(for: language) ?? NLEmbedding.wordEmbedding(for: language)
        if let e { cache[key] = e }
        return e
    }

    /// Semantic distance (0 = identical meaning; larger = less similar); nil if unavailable.
    public func distance(_ a: String, _ b: String, language: NLLanguage = .english) -> Double? {
        guard let emb = embedding(for: language) else { return nil }
        let d = emb.distance(between: a, and: b)   // NLDistance (cosine-based); lower = closer
        return d.isFinite ? Double(d) : nil
    }

    /// SemanticMatchPort: does `text` match `concept` above a similarity bar?
    public func match(_ text: String, concept: String) async -> PortOutcome<SemanticMatchResult> {
        let start = DispatchTime.now().uptimeNanoseconds
        guard let emb = embedding(for: .english) else {
            return .unavailable(engineVersion: engineVersion)   // honest: embedding not available
        }
        let d = emb.distance(between: text, and: concept)
        guard d.isFinite else { return .unknown(engineVersion: engineVersion) }
        // NLDistance: smaller = more similar. Threshold is deliberately conservative (no silent hard match).
        let matched = d < 1.0
        let score = max(0, 1.0 - Double(d) / 2.0)   // crude 0..1 similarity for reporting only
        let lat = DispatchTime.now().uptimeNanoseconds &- start
        return .init(state: .ok, value: SemanticMatchResult(matched: matched, score: score),
                     confidence: score, provenance: .appleNaturalLanguage, engineVersion: engineVersion,
                     latencyNanos: lat, privacy: .onDeviceOnly, cost: .cheap)
    }

    public func isAvailable(language: NLLanguage = .english) -> Bool { embedding(for: language) != nil }
}
