import Foundation
import NaturalLanguage
import GuardianCore

// MARK: - Semantic Shield V1 (PROMPT 003 §9) — exact/alias + REAL semantic similarity (NLEmbedding)
// low confidence → no silent hide; medium → caution; high (exact or strong semantic) → exclude.
// Personal corrections stay local/personal (not global truth).

public actor SemanticShieldV1 {
    public nonisolated static let version = "semantic-shield-v1"
    private let embedding = SemanticEmbeddingProvider()
    // Local personal correction memory (per concept): forced-allow / forced-exclude.
    private var forcedAllow: Set<String> = []
    private var forcedExclude: Set<String> = []

    public init() {}

    public func correctNotThisConcept(_ concept: String) { forcedAllow.insert(norm(concept)) }
    public func correctAlwaysThisConcept(_ concept: String) { forcedExclude.insert(norm(concept)) }

    public func evaluate(text: String, rules: [SemanticShieldRule], language: String?) async
    -> IntelligenceSignal<ShieldDecision> {
        let start = DispatchTime.now().uptimeNanoseconds
        let t = norm(text)
        guard !t.isEmpty else {
            return IntelligenceSignal(task: "semantic_shield", value: nil, rawConfidence: nil,
                                      availability: .unknown, provenance: .embeddingClassifierV1,
                                      modelVersion: Self.version, abstentionReason: .insufficientEvidence, language: language)
        }
        var best = ShieldDecision.noMatch
        var bestConf = 0.0
        var evidence: [EvidenceRef] = []

        for rule in rules {
            let value = norm(rule.value)
            // Personal corrections take precedence (local only).
            if forcedAllow.contains(value) { continue }
            let forced = forcedExclude.contains(value)

            // 1. Exact / alias (aliases split by '|').
            let aliases = rule.value.split(separator: "|").map { norm(String($0)) }
            if forced || aliases.contains(where: { !$0.isEmpty && t.contains($0) }) {
                best = ShieldDecision(matched: rule.value, tier: .high, action: rule.hard ? .exclude : .caution)
                evidence.append(EvidenceRef(kind: "exact", detail: rule.value)); bestConf = 0.95
                break
            }
            // 2. Semantic similarity (real embedding) for concept rules.
            if let d = await embedding.distance(text, rule.value, language: language == "tr" ? .turkish : .english) {
                // smaller distance = more similar
                if d < 0.85 {
                    best = ShieldDecision(matched: rule.value, tier: .high, action: rule.hard ? .exclude : .caution)
                    bestConf = max(bestConf, 0.85); evidence.append(EvidenceRef(kind: "embedding", detail: "d=\(String(format: "%.2f", d))"))
                } else if d < 1.05, bestConf < 0.6 {
                    best = ShieldDecision(matched: rule.value, tier: .medium, action: .caution)
                    bestConf = max(bestConf, 0.6); evidence.append(EvidenceRef(kind: "embedding", detail: "d=\(String(format: "%.2f", d))"))
                }
            }
        }
        let lat = DispatchTime.now().uptimeNanoseconds &- start
        return IntelligenceSignal(task: "semantic_shield", value: best,
                                  rawConfidence: best.tier == .none ? 0.4 : bestConf,
                                  availability: .available, provenance: .embeddingClassifierV1,
                                  modelVersion: Self.version, latencyNanos: lat, evidence: evidence, language: language)
    }

    private nonisolated func norm(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
