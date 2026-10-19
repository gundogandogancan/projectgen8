import Foundation

// MARK: - Content identity & candidates (platform-independent domain types)
// Ref: Build Bible §17, §20, §498, §550, §621; EVENT_CONTRACTS; CORE_DOMAIN_BOUNDARIES.

/// Stable identifier for a piece of content. In PROMPT 001 these are fixture IDs/hashes.
public struct ContentID: Hashable, Sendable, CustomStringConvertible {
    public let raw: String
    public init(_ raw: String) { self.raw = raw }
    public var description: String { raw }
}

/// Identity resolution confidence gate (I0–I4). Auto-skip / high-impact actions require I3+.
public enum ContentIdentityState: String, Sendable, CaseIterable {
    case i0_unknown = "I0_UNKNOWN"
    case i1_screenObserved = "I1_SCREEN_OBSERVED"
    case i2_probable = "I2_PROBABLE"
    case i3_strong = "I3_STRONG"
    case i4_verified = "I4_VERIFIED"

    /// Minimum identity required for high-impact actions (auto-skip, hard hide on controlled surface).
    public var allowsHighImpactAction: Bool { self == .i3_strong || self == .i4_verified }
}

public struct ContentIdentityResult: Sendable, Equatable {
    public let contentID: ContentID
    public let state: ContentIdentityState
    /// Version/edition fingerprint — mismatch is a release-blocking safety concern for temporal skip.
    public let versionTag: String
    public init(contentID: ContentID, state: ContentIdentityState, versionTag: String) {
        self.contentID = contentID
        self.state = state
        self.versionTag = versionTag
    }
}

/// How a content item entered the pipeline.
public enum CandidateSource: String, Sendable {
    case currentlyViewing = "CURRENT"
    case lookAhead1 = "NEXT+1"
    case lookAhead2 = "NEXT+2"
    case lookAhead3 = "NEXT+3"
}

/// A bounded look-ahead candidate (short-form). The platform must actually preload it —
/// we never invent unseen future content (Bible §15 Prompt 000, §617).
public struct ContentCandidate: Sendable, Equatable {
    public let id: ContentID
    public let source: CandidateSource
    /// Likelihood this becomes the next exposure (priority ordering input).
    public let nextExposureLikelihood: Double
    /// Deadline (monotonic nanos) by which a decision should be ready, or nil.
    public let decisionDeadlineNanos: UInt64?
    /// Deterministic fixture signals (TEST_FIXTURE). Nil → insufficient evidence.
    public let fixture: FixtureSignals?
    public init(id: ContentID, source: CandidateSource, nextExposureLikelihood: Double,
                decisionDeadlineNanos: UInt64?, fixture: FixtureSignals?) {
        self.id = id
        self.source = source
        self.nextExposureLikelihood = nextExposureLikelihood
        self.decisionDeadlineNanos = decisionDeadlineNanos
        self.fixture = fixture
    }
}

/// Non-personal reusable content intelligence stub (ContentDNA). Personal decisions are NOT stored here.
public struct ContentDNAStub: Sendable, Equatable {
    public let contentID: ContentID
    public let topics: [String]
    public let sensitiveCategories: Set<SensitiveCategory>
    public let entities: Set<String>
    public init(contentID: ContentID, topics: [String], sensitiveCategories: Set<SensitiveCategory>, entities: Set<String>) {
        self.contentID = contentID
        self.topics = topics
        self.sensitiveCategories = sensitiveCategories
        self.entities = entities
    }
}

/// Low-valence categories a user may opt to down-rank (Positive Exposure, Bible §9, §421, §439).
public enum SensitiveCategory: String, Sendable, CaseIterable, Codable {
    case death, disease, disaster, severeAccident, violentConflict, gore
}

/// Provenance label for any produced signal/score — never call fixtures/heuristics "production AI" (§3 of PROMPT 001).
public enum SignalProvenance: String, Sendable, Codable {
    case testFixture = "TEST_FIXTURE"
    case heuristicV0 = "HEURISTIC_V0"
    case cryptoHash = "CRYPTO_HASH"                 // real: CryptoKit SHA-256 (exact identity)
    case perceptualHash = "PERCEPTUAL_HASH"         // real: deterministic perceptual fingerprint
    case appleNaturalLanguage = "APPLE_NATURAL_LANGUAGE"
    case appleVision = "APPLE_VISION"
    case appleSpeech = "APPLE_SPEECH"
    case coreML = "CORE_ML"
    case lexiconV1 = "LEXICON_V1"                   // deterministic TR+EN lexicon signal (NOT "AI")
    case embeddingClassifierV1 = "EMBEDDING_CLASSIFIER_V1"  // NLEmbedding nearest-concept classifier
    case rulesV1 = "RULES_V1"
    case unavailable = "UNAVAILABLE"
}

/// Deterministic fixture signals used by the HEURISTIC_V0 preflight (no real model, clearly labelled).
public struct FixtureSignals: Sendable, Equatable {
    public let topics: [String]
    public let entities: Set<String>
    public let sensitiveCategories: Set<SensitiveCategory>
    /// Component contributions in 0...1; used by the explicit deterministic score formula.
    public let goalFit: Double
    public let informationDensity: Double
    public let manipulationRisk: Double
    /// Whether the fixture carries enough signal to score at all.
    public let hasSufficientEvidence: Bool
    /// Whether two content sources disagree (→ CONFLICTING).
    public let conflicting: Bool
    /// Factual correctness of the item (truth plane) — kept SEPARATE from exposure policy.
    public let factuallyCorrect: Bool

    public init(topics: [String] = [], entities: Set<String> = [], sensitiveCategories: Set<SensitiveCategory> = [],
                goalFit: Double = 0, informationDensity: Double = 0, manipulationRisk: Double = 0,
                hasSufficientEvidence: Bool = true, conflicting: Bool = false, factuallyCorrect: Bool = true) {
        self.topics = topics
        self.entities = entities
        self.sensitiveCategories = sensitiveCategories
        self.goalFit = goalFit
        self.informationDensity = informationDensity
        self.manipulationRisk = manipulationRisk
        self.hasSufficientEvidence = hasSufficientEvidence
        self.conflicting = conflicting
        self.factuallyCorrect = factuallyCorrect
    }
}
