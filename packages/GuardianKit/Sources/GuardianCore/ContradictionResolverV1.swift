import Foundation

// MARK: - P009C §9/§18 — contradiction resolution. NO majority vote. Context qualifiers may qualify
// lexical evidence but can NEVER erase strong multimodal risk without support.

public enum ContradictionOutcomeV1: String, Sendable, Codable {
    case unresolved = "UNRESOLVED"
    case modalityPriority = "MODALITY_PRIORITY"
    case temporalReinterpretation = "TEMPORAL_REINTERPRETATION"
    case contextQualified = "CONTEXT_QUALIFIED"
    case strongRiskDominant = "STRONG_RISK_DOMINANT"
    case insufficientEvidence = "INSUFFICIENT_EVIDENCE"
}

public struct ContradictionCaseV1: Sendable {
    public let riskEvidence: [ExpertEvidenceV2]
    public let positiveEvidence: [ExpertEvidenceV2]
    public let contextTags: [SemanticContextTagV1]
    public let riskEarlierMs: Double?
    public let positiveLaterMs: Double?
}

public struct ContradictionResolutionV1: Sendable {
    public let outcome: ContradictionOutcomeV1
    public let reason: String
    public let riskRetained: Bool                  // historical strong risk is NEVER erased
    public let provenance: String
}

public enum ContradictionResolverV1 {
    public static let revision = "contradiction-resolver-v1"

    public static func resolve(_ c: ContradictionCaseV1) -> ContradictionResolutionV1 {
        let liveRisk = c.riskEvidence.filter { !$0.stale && $0.inputModalityAvailable }
        let livePos = c.positiveEvidence.filter { !$0.stale && $0.inputModalityAvailable }
        // stale-only sides → not a live contradiction
        if liveRisk.isEmpty && livePos.isEmpty {
            return ContradictionResolutionV1(outcome: .insufficientEvidence, reason: "both sides stale/unavailable",
                                             riskRetained: !c.riskEvidence.isEmpty, provenance: revision)
        }
        if liveRisk.isEmpty || livePos.isEmpty {
            return ContradictionResolutionV1(outcome: .insufficientEvidence, reason: "one side has no live evidence",
                                             riskRetained: !liveRisk.isEmpty || !c.riskEvidence.isEmpty, provenance: revision)
        }
        let (riskStrength, riskFams) = EvidenceWeigherV1.combine(liveRisk)
        let (posStrength, _) = EvidenceWeigherV1.combine(livePos)
        let riskMultimodal = riskFams.count >= 2
        let qualifierTags: Set<SemanticContextTagV1> = [.quoted, .satireHumorCandidate, .educationalMention, .dramatizationFictionCandidate]
        let qualifier: SemanticContextTagV1? = c.contextTags.first(where: { qualifierTags.contains($0) })
        // §18 LAW: strong multimodal risk dominates regardless of qualifiers lacking support
        if riskMultimodal && riskStrength >= 0.5 {
            return ContradictionResolutionV1(outcome: .strongRiskDominant,
                reason: "multimodal risk (families=\(riskFams.count), strength=\(String(format: "%.2f", riskStrength))) — qualifier cannot erase",
                riskRetained: true, provenance: revision)
        }
        // qualifier + lexical-only risk → QUALIFIED (risk evidence retained, interpretation annotated)
        if let q = qualifier, !riskMultimodal {
            return ContradictionResolutionV1(outcome: .contextQualified,
                reason: "lexical-only risk qualified by \(q.rawValue) — evidence retained, meaning annotated",
                riskRetained: true, provenance: revision)
        }
        // temporal pattern: risk strictly earlier, positive strictly later → narrative change, risk retained
        if let r = c.riskEarlierMs, let p = c.positiveLaterMs, p > r {
            return ContradictionResolutionV1(outcome: .temporalReinterpretation,
                reason: "temporal change (risk@\(Int(r))ms → positive@\(Int(p))ms); historical risk retained by law",
                riskRetained: true, provenance: revision)
        }
        // one side vastly stronger via INDEPENDENT families → modality priority (never a vote count)
        if riskStrength >= posStrength * 2 || posStrength >= riskStrength * 2 {
            return ContradictionResolutionV1(outcome: .modalityPriority,
                reason: "independent-family strength asymmetry (risk=\(String(format: "%.2f", riskStrength)) vs pos=\(String(format: "%.2f", posStrength)))",
                riskRetained: true, provenance: revision)
        }
        return ContradictionResolutionV1(outcome: .unresolved,
            reason: "comparable live evidence on both sides — represented, not resolved",
            riskRetained: true, provenance: revision)
    }

    /// §18 heuristic context detection from derived text (qualifier evidence only, heuristicSupportOnly).
    /// P009C-R1 F-2: token/phrase-based (language-aware); punctuation/emoji cues stay character-based.
    public static func detectContextTags(text: String?, language: String? = nil) -> [SemanticContextTagV1] {
        guard let t = text, !t.isEmpty else { return [.unknownContext] }
        var tags: [SemanticContextTagV1] = []
        let quoteChars: [Character] = ["\"", "“", "”"]
        let quotePhrases = ["dedi ki", "said", "quote", "alıntı"]
        if t.contains(where: { quoteChars.contains($0) })
            || LexiconMatcherV2.containsToken(t, anyOf: quotePhrases, language: language) { tags.append(.quoted) }
        let satireEmoji = ["😂"]
        let satireWords = ["lol", "parody", "parodi", "skeç", "şaka", "just kidding", "komedi", "comedy sketch", "mizah"]
        if satireEmoji.contains(where: { t.contains($0) })
            || LexiconMatcherV2.containsToken(t, anyOf: satireWords, language: language) { tags.append(.satireHumorCandidate) }
        if LexiconMatcherV2.containsToken(t, anyOf: ["lesson", "ders", "educational", "eğitim"], language: language) {
            tags.append(.educationalMention)
        }
        if tags.isEmpty { tags.append(.literal) }
        return tags
    }
}
