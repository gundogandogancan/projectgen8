import Foundation

// MARK: - P009C §11 — semantic uncertainty. Output states prefer UNKNOWN over false certainty.

public enum SemanticKnowledgeStateV1: String, Sendable, Codable {
    case known = "KNOWN", likely = "LIKELY", ambiguous = "AMBIGUOUS"
    case conflicting = "CONFLICTING", unknown = "UNKNOWN", unavailable = "UNAVAILABLE"
}

public struct SemanticUncertaintyV1: Sendable {
    public var epistemic: Double = 0               // model/knowledge limits
    public var missingModality: Double = 0
    public var identity: Double = 0
    public var temporal: Double = 0
    public var language: Double = 0
    public var contradiction: Double = 0
    public var ood: Double = 0
    public var providerUnavailability: Double = 0
    public var notes: [String] = []
    public init() {}
    public var overall: Double {
        min(1, [epistemic, missingModality, identity, temporal, language, contradiction, ood, providerUnavailability].max() ?? 1)
    }
}

public enum SemanticUncertaintyModelV1 {
    public static let revision = "semantic-uncertainty-v1"

    public static func assess(evidence: [ExpertEvidenceV2], unknownReasons: [String],
                              itemProvisional: Bool, contradictions: Int, topicCount: Int) -> SemanticUncertaintyV1 {
        var u = SemanticUncertaintyV1()
        let live = evidence.filter { !$0.stale }
        let available = live.filter { $0.inputModalityAvailable }
        // R1 §9 monotonicity: an OOD reading never counts as trustworthy modality COVERAGE — otherwise
        // adding an out-of-distribution record would spuriously lower missing-modality uncertainty.
        let trustedDomains = Set(available.filter { !$0.oodIndicator }.map { $0.domain })
        u.missingModality = trustedDomains.isEmpty ? 1 : max(0, 1 - Double(trustedDomains.count) / Double(ExpertDomainV2.allCases.count))
        u.providerUnavailability = live.isEmpty ? 1 : Double(live.count - available.count) / Double(max(1, live.count))
        u.identity = itemProvisional ? 0.6 : 0.1
        u.ood = available.contains { $0.oodIndicator } ? 0.5 : 0
        u.language = available.contains { $0.labels.contains("UNSUPPORTED_LANGUAGE") } ? 0.8 : 0
        u.contradiction = contradictions > 0 ? min(1, 0.3 + Double(contradictions) * 0.1) : 0
        // R1 §9: epistemic from the family-law combined strength (1 − strength) — per-record MIN was
        // optimistic (one confident record masked the rest; audit F-7). Monotone: new evidence lowers
        // epistemic only through the bounded family-max law, never through averaging/vote.
        let (strength, _) = EvidenceWeigherV1.combine(available)
        u.epistemic = available.isEmpty ? 1 : 1 - strength
        if unknownReasons.contains(where: { $0.hasPrefix("stale-discarded") || $0.hasPrefix("deadline") }) { u.temporal = 0.4 }
        u.notes = unknownReasons.prefix(8).map { String($0) }
        return u
    }

    /// Map a weighted strength + uncertainty into the §11 knowledge state. Never forces certainty.
    public static func state(strength: Double, uncertainty: SemanticUncertaintyV1,
                             conflicting: Bool, anyEvidence: Bool) -> SemanticKnowledgeStateV1 {
        if !anyEvidence { return .unavailable }
        if conflicting { return .conflicting }
        if uncertainty.overall >= 0.8 { return .unknown }
        if uncertainty.overall >= 0.5 || strength < 0.3 { return .ambiguous }
        if strength >= 0.7 && uncertainty.overall < 0.3 { return .known }
        return .likely
    }
}
