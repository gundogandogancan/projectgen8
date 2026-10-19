import Foundation

// MARK: - P009C §6 — intent graph. Intent is HYPOTHESIS, never fact. Ambiguity is preserved.

public enum ContentIntentV1: String, Sendable, Codable, CaseIterable {
    case inform = "intent:inform", teach = "intent:teach", entertain = "intent:entertain"
    case persuade = "intent:persuade", sell = "intent:sell", provoke = "intent:provoke"
    case warn = "intent:warn", requestAction = "intent:request-action", seekEngagement = "intent:seek-engagement"
    case narrateExperience = "intent:narrate-experience", expressEmotion = "intent:express-emotion"
    case satireHumor = "intent:satire-humor", unknown = "intent:unknown"
}

public struct IntentHypothesisV1: Sendable {
    public let intent: ContentIntentV1
    public var supportingModalities: Set<ExpertDomainV2>
    public var supportingEvidence: [String]
    public var counterEvidence: [String]
    public var temporalScopeMs: ClosedRange<Double>?
    public var weight: Double                      // weighted support, never a verdict probability
    public var uncertainty: Double
}

public final class IntentGraphV1: @unchecked Sendable {
    public static let revision = "intent-graph-v1"
    private(set) public var hypotheses: [ContentIntentV1: IntentHypothesisV1] = [:]
    public let maxHypotheses: Int
    private let lock = NSLock()
    public init(maxHypotheses: Int = 16) { self.maxHypotheses = maxHypotheses }

    public func support(_ intent: ContentIntentV1, modality: ExpertDomainV2, evidence: String,
                        weight: Double, atMs: Double) {
        lock.lock(); defer { lock.unlock() }
        if var h = hypotheses[intent] {
            h.supportingModalities.insert(modality)
            if h.supportingEvidence.count < 16 { h.supportingEvidence.append(evidence) }
            h.weight += max(0, weight)
            if let r = h.temporalScopeMs { h.temporalScopeMs = min(r.lowerBound, atMs)...max(r.upperBound, atMs) }
            h.uncertainty = max(0.2, h.uncertainty - 0.1)     // more independent support → less uncertain, floored
            hypotheses[intent] = h
        } else {
            guard hypotheses.count < maxHypotheses else { return }
            hypotheses[intent] = IntentHypothesisV1(intent: intent, supportingModalities: [modality],
                                                    supportingEvidence: [evidence], counterEvidence: [],
                                                    temporalScopeMs: atMs...atMs, weight: max(0, weight), uncertainty: 0.7)
        }
    }
    public func counter(_ intent: ContentIntentV1, evidence: String) {
        lock.lock(); defer { lock.unlock() }
        guard var h = hypotheses[intent] else { return }
        if h.counterEvidence.count < 16 { h.counterEvidence.append(evidence) }
        h.uncertainty = min(1, h.uncertainty + 0.2)
        hypotheses[intent] = h
    }
    /// §6 ambiguity law: ranked HYPOTHESES; when top candidates are close, ambiguity is explicit.
    public func ranked() -> [IntentHypothesisV1] {
        lock.lock(); defer { lock.unlock() }
        return hypotheses.values.sorted { $0.weight > $1.weight }
    }
    public var isAmbiguous: Bool {
        let r = ranked()
        guard r.count >= 2 else { return r.isEmpty }
        return r[1].weight >= r[0].weight * 0.6                // close competitors → ambiguous, no forced pick
    }
}
