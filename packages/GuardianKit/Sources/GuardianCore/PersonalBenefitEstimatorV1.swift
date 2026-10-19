import Foundation

// MARK: - Personal Benefit Estimator V1 (PROMPT 003 §15) — rules-based, deterministic, versioned.
// Produces the STRUCTURED vector (not a single score). Labelled RULES_V1; not a trained model.

public struct PersonalBenefitEstimatorV1: Sendable {
    public static let version = "benefit-estimator-v1"
    public init() {}

    public func estimate(topic: TopicMessage?, manipulation: ManipulationSignals?,
                         mdd: [MortalityDiseaseDisasterLabel]) -> PersonalBenefitVector {
        var v = PersonalBenefitVector()
        if let t = topic {
            switch t.intent {
            case .informational: v.learning = 0.7; v.criticalThinking = 0.5; v.practicalUsefulness = 0.5
            case .personalStory: v.hopeMeaning = 0.4; v.entertainment = 0.4
            case .entertainment: v.entertainment = 0.7; v.relaxation = 0.5
            case .persuasive: v.learning = 0.3; v.criticalThinking = 0.3
            case .advertisement: v.manipulationPressure = 0.5
            case .unknown: break
            }
        }
        if let m = manipulation {
            v.manipulationPressure = max(v.manipulationPressure, min(1.0, Double(m.total) / 4.0))
            v.fearAngerDespairLoad = min(1.0, Double(m.fear + m.anger) / 3.0)
        }
        // Heavy mortality/disaster/war topics add some negative emotional load (NOT a truth/quality claim).
        let heavy = mdd.contains(where: { [.mortality, .disaster, .warConflict, .severeAccident].contains($0) })
        if heavy { v.fearAngerDespairLoad = max(v.fearAngerDespairLoad, 0.4) }
        return v
    }
}
