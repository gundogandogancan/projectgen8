import Foundation

// MARK: - P009C §17 — emotional/sensitive load of CONTENT (never a claim about the user's state).

public enum EmotionalDimensionV1: String, Sendable, Codable, CaseIterable {
    case calm = "emotion:calm", excitement = "emotion:excitement", fear = "emotion:fear"
    case sadness = "emotion:sadness", anger = "emotion:anger", distress = "emotion:distress"
    case grief = "emotion:grief", urgency = "emotion:urgency"
    case graphicSensitive = "emotion:graphic-sensitive", uncertainty = "emotion:uncertainty"
}

public struct EmotionalSensitiveLoadV1: Sendable {
    public static let revision = "emotional-sensitive-load-v1"
    public private(set) var load: [EmotionalDimensionV1: Double] = [:]   // evidence weight, uncalibrated
    public private(set) var provenance: [String] = []
    public init() {}

    /// Derive from mesh evidence labels — descriptive of content, uncalibrated, never a user-state claim.
    public mutating func observe(labels: [String], weight: Double, provenance src: String) {
        func add(_ d: EmotionalDimensionV1, _ w: Double) { load[d] = min(1, (load[d] ?? 0) + max(0, w)) }
        for l in labels {
            if l.hasPrefix("safety:fear-threat") { add(.fear, weight) }
            if l.hasPrefix("safety:sensitive-death-disease-news") { add(.grief, weight * 0.8); add(.graphicSensitive, weight * 0.5) }
            if l.hasPrefix("attention:urgency") { add(.urgency, weight) }
            if l.hasPrefix("pattern:emotional-language") { add(.distress, weight * 0.6) }
            if l.hasPrefix("benefit:calm-nature") { add(.calm, weight) }
            if l.hasPrefix("attention:rapid-edit-density") { add(.excitement, weight * 0.7) }
            if l == "music:present" { add(.excitement, weight * 0.3) }
        }
        if provenance.count < 16 { provenance.append(src) }
    }
    public mutating func markUncertain(_ w: Double) { load[.uncertainty] = min(1, (load[.uncertainty] ?? 0) + w) }
    public var labels: [String] { load.filter { $0.value > 0 }.keys.map(\.rawValue).sorted() }
}
