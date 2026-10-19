import Foundation

// MARK: - Model Router V1 (PROMPT 002 §8) — deterministic, local-first, smallest-sufficient
// cache wins → cheap deterministic/Apple-native before heavy → early exit → UNKNOWN if no route.

public enum InferenceEngine: String, Sendable {
    case cache = "CACHE"
    case deterministic = "DETERMINISTIC"
    case appleNative = "APPLE_NATIVE"
    case smallLocal = "SMALL_LOCAL"
    case localFoundation = "LOCAL_FOUNDATION"
    case privacyCloud = "PRIVACY_CLOUD"
    case abstain = "ABSTAIN"
}

public enum InferenceTask: String, Sendable {
    case identity, textExtraction, language, topics, sensitive, semanticMatch, temporal, evidence
}

public struct RouteRequest: Sendable {
    public let task: InferenceTask
    public let deadlineNanos: UInt64?
    public let needsHighConfidence: Bool
    public let thermal: ThermalState
    public let lowPower: Bool
    public let cacheAvailable: Bool
    public let privacy: PortPrivacy
    public let localEngineAvailable: Bool
    public let networkAllowed: Bool
    public init(task: InferenceTask, deadlineNanos: UInt64? = nil, needsHighConfidence: Bool = false,
                thermal: ThermalState = .nominal, lowPower: Bool = false, cacheAvailable: Bool = false,
                privacy: PortPrivacy = .onDeviceOnly, localEngineAvailable: Bool = true, networkAllowed: Bool = false) {
        self.task = task; self.deadlineNanos = deadlineNanos; self.needsHighConfidence = needsHighConfidence
        self.thermal = thermal; self.lowPower = lowPower; self.cacheAvailable = cacheAvailable
        self.privacy = privacy; self.localEngineAvailable = localEngineAvailable; self.networkAllowed = networkAllowed
    }
}

public struct RouteDecision: Sendable, Equatable {
    public let engine: InferenceEngine
    public let reason: String
    public let fallback: InferenceEngine?
    public let abstain: Bool
}

public struct ModelRouter: Sendable {
    public init() {}
    public func route(_ r: RouteRequest) -> RouteDecision {
        // 1. Cache always wins when valid.
        if r.cacheAvailable {
            return .init(engine: .cache, reason: "valid cache entry", fallback: .deterministic, abstain: false)
        }
        // 2. Identity is a cheap deterministic/crypto path — never needs a heavy model.
        if r.task == .identity {
            return .init(engine: .deterministic, reason: "identity uses hash/perceptual (no heavy model)",
                         fallback: nil, abstain: false)
        }
        // 3. Thermal-critical or low-power → prefer the cheapest viable engine; no heavy models.
        if r.thermal == .critical || r.thermal == .serious || r.lowPower {
            if r.localEngineAvailable {
                return .init(engine: .appleNative, reason: "constrained (thermal/low-power) → cheap Apple-native only",
                             fallback: .deterministic, abstain: false)
            }
            return .init(engine: .abstain, reason: "constrained and no cheap local engine → abstain (UNKNOWN)",
                         fallback: nil, abstain: true)
        }
        // 4. Prefer Apple-native/local; escalate only if high confidence is required AND available.
        if r.localEngineAvailable {
            let engine: InferenceEngine = r.needsHighConfidence ? .smallLocal : .appleNative
            return .init(engine: engine, reason: "local-first, smallest sufficient", fallback: .deterministic, abstain: false)
        }
        // 5. No local engine: only use privacy cloud if explicitly allowed; else abstain.
        if r.networkAllowed && r.privacy == .derivedShareable {
            return .init(engine: .privacyCloud, reason: "no local engine; network allowed for shareable-derived data",
                         fallback: .abstain, abstain: false)
        }
        return .init(engine: .abstain, reason: "no sufficient local route and cloud not permitted → UNKNOWN",
                     fallback: nil, abstain: true)
    }
}
