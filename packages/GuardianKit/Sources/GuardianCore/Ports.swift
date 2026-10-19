import Foundation

// MARK: - Intelligence Port contracts (PROMPT 002 §3)
// Responsibility interfaces for specialist heads — NOT separate processes. Each returns a
// confidence/provenance/version envelope; no naked Bool where ambiguity exists; UNKNOWN is explicit.

public enum PortCost: String, Sendable { case free, cheap, moderate, heavy }
public enum PortPrivacy: String, Sendable { case onDeviceOnly, derivedShareable }

/// Universal result envelope for every port.
public struct PortOutcome<Value: Sendable>: Sendable {
    public enum State: String, Sendable { case ok, unavailable, unknown, failed }
    public let state: State
    public let value: Value?
    public let confidence: Double?           // nil when not applicable
    public let provenance: SignalProvenance
    public let engineVersion: String
    public let latencyNanos: UInt64
    public let privacy: PortPrivacy
    public let cost: PortCost

    public init(state: State, value: Value?, confidence: Double?, provenance: SignalProvenance,
                engineVersion: String, latencyNanos: UInt64, privacy: PortPrivacy, cost: PortCost) {
        self.state = state; self.value = value; self.confidence = confidence
        self.provenance = provenance; self.engineVersion = engineVersion
        self.latencyNanos = latencyNanos; self.privacy = privacy; self.cost = cost
    }

    public static func unavailable(engineVersion: String) -> PortOutcome<Value> {
        .init(state: .unavailable, value: nil, confidence: nil, provenance: .unavailable,
              engineVersion: engineVersion, latencyNanos: 0, privacy: .onDeviceOnly, cost: .free)
    }
    public static func unknown(engineVersion: String) -> PortOutcome<Value> {
        .init(state: .unknown, value: nil, confidence: nil, provenance: .unavailable,
              engineVersion: engineVersion, latencyNanos: 0, privacy: .onDeviceOnly, cost: .free)
    }
}

// Media reference kept abstract so the core stays platform-free; adapters bind to real assets.
public struct MediaRef: Sendable, Equatable {
    public enum Kind: String, Sendable { case imageBytes, audioBytes, text, fileURL }
    public let kind: Kind
    public let bytes: Data?
    public let text: String?
    public let url: String?
    public init(kind: Kind, bytes: Data? = nil, text: String? = nil, url: String? = nil) {
        self.kind = kind; self.bytes = bytes; self.text = text; self.url = url
    }
}

public struct TextSpan: Sendable, Equatable { public let text: String; public init(_ t: String) { text = t } }
public struct LanguageSignal: Sendable, Equatable { public let language: String; public init(_ l: String) { language = l } }
public struct VisualFingerprint: Sendable, Equatable { public let bits: [UInt8]; public init(_ b: [UInt8]) { bits = b } }
public struct EntityHit: Sendable, Equatable { public let name: String; public init(_ n: String) { name = n } }
public struct SensitiveSignal: Sendable, Equatable { public let categories: Set<SensitiveCategory>; public init(_ c: Set<SensitiveCategory>) { categories = c } }
public struct TopicSignal: Sendable, Equatable { public let topics: [String]; public init(_ t: [String]) { topics = t } }
public struct SemanticMatchResult: Sendable, Equatable { public let matched: Bool; public let score: Double; public init(matched: Bool, score: Double) { self.matched = matched; self.score = score } }
public struct TemporalSignal: Sendable, Equatable { public let segmentIndex: Int; public let categories: Set<SensitiveCategory>; public init(segmentIndex: Int, categories: Set<SensitiveCategory>) { self.segmentIndex = segmentIndex; self.categories = categories } }
public struct EvidenceSignal: Sendable, Equatable { public let supported: Bool?; public let note: String; public init(supported: Bool?, note: String) { self.supported = supported; self.note = note } }

// The nine ports (§3). Implementations live in adapter targets; all are cancellation-aware (async).
public protocol TextExtractionPort: Sendable { var engineVersion: String { get }; func extractText(_ media: MediaRef) async -> PortOutcome<TextSpan> }
public protocol SpeechTranscriptionPort: Sendable { var engineVersion: String { get }; func transcribe(_ media: MediaRef) async -> PortOutcome<TextSpan> }
public protocol VisualFeaturePort: Sendable { var engineVersion: String { get }; func fingerprint(_ media: MediaRef) async -> PortOutcome<VisualFingerprint> }
public protocol EntityDetectionPort: Sendable { var engineVersion: String { get }; func entities(_ media: MediaRef) async -> PortOutcome<[EntityHit]> }
public protocol SensitiveContentPort: Sendable { var engineVersion: String { get }; func sensitive(_ media: MediaRef) async -> PortOutcome<SensitiveSignal> }
public protocol TopicMessagePort: Sendable { var engineVersion: String { get }; func topics(_ text: String) async -> PortOutcome<TopicSignal> }
public protocol SemanticMatchPort: Sendable { var engineVersion: String { get }; func match(_ text: String, concept: String) async -> PortOutcome<SemanticMatchResult> }
public protocol TemporalSignalPort: Sendable { var engineVersion: String { get }; func segments(_ media: MediaRef) async -> PortOutcome<[TemporalSignal]> }
public protocol EvidenceSignalPort: Sendable { var engineVersion: String { get }; func evidence(for claim: String) async -> PortOutcome<EvidenceSignal> }

public protocol LanguagePort: Sendable { var engineVersion: String { get }; func identify(_ text: String) async -> PortOutcome<LanguageSignal> }
