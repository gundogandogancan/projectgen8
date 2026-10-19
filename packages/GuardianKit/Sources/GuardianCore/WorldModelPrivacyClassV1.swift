import Foundation

// MARK: - P009C §20 — world-model privacy classes + persistence law.

public enum WorldModelPrivacyClassV1: String, Sendable, Codable, CaseIterable {
    case ephemeralRawInput = "EPHEMERAL_RAW_INPUT"             // raw OCR/transcript/pixels — never persisted
    case derivedEphemeral = "DERIVED_EPHEMERAL"                // derived, session-only
    case derivedCacheable = "DERIVED_CACHEABLE"                // derived, TTL-bounded cache
    case persistableNonReconstructive = "PERSISTABLE_NONRECONSTRUCTIVE"   // canonical IDs/labels only
    case forbiddenPersistence = "FORBIDDEN_PERSISTENCE"

    /// §20 persistence law: only non-reconstructive derived data may enter durable DNA.
    public var mayEnterDurableDNA: Bool { self == .persistableNonReconstructive }
}

/// §20 structural leak guard: durable payloads carry canonical concept IDs / structural labels ONLY.
/// Free text from OCR/transcripts is raw-class and must never appear. This helper is used by the DNA
/// finalizer and by leak tests: a durable string is lawful only if it is a known canonical form.
public enum WorldModelPersistenceLawV1 {
    public static let revision = "wm-persistence-law-v1"
    /// Lawful durable strings: canonical prefixes produced by our own taxonomies/graphs — never raw text.
    public static let lawfulPrefixes = [
        "concept:", "entity:", "intent:", "event:", "episode:", "narrative:", "contradiction:",
        "safety:", "benefit:", "attention:", "emotion:", "context:", "language:", "modality:",
        "UNSUPPORTED_LANGUAGE", "UNAVAILABLE", "UNKNOWN", "scene:", "audio:", "music", "speech:",
        "symbol:", "temporal:", "topic:", "pattern:", "revision:", "taxonomy:", "wm:"
    ]
    public static func isLawfulDurable(_ s: String) -> Bool {
        lawfulPrefixes.contains { s.hasPrefix($0) }
    }
}
