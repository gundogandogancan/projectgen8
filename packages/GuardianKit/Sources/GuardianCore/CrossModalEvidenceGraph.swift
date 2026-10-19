import Foundation

// MARK: - Cross-modal evidence graph (PROMPT 008 §14) — links evidence by concept/entity/time across modalities.
// NOT a confidence average: multi-modality agreement BOOSTS; contradiction PENALIZES; missing modality is tracked,
// never silently treated as agreement or as zero.

public struct ConceptEvidence: Sendable, Equatable {
    public let concept: String
    public let supportingModalities: [Modality]
    public let conflictingModalities: [Modality]
    public let fusedConfidence: Double      // after agreement boost / conflict penalty (bounded 0..1)
    public let agreement: Bool
    public let conflict: Bool
}

public struct CrossModalEvidenceGraphV1: Sendable, Equatable {
    public let concepts: [ConceptEvidence]
    public let agreements: [String]
    public let conflicts: [String]
    public init(concepts: [ConceptEvidence], agreements: [String], conflicts: [String]) {
        self.concepts = concepts; self.agreements = agreements; self.conflicts = conflicts
    }
    public func concept(_ c: String) -> ConceptEvidence? { concepts.first { $0.concept == c } }
}

public enum CrossModalEvidenceFuser {
    /// Fuse per-concept across modalities. Agreement across ≥2 modalities boosts; a same-concept contradiction penalizes.
    /// `conflictPairs` lists concept pairs that are mutually contradictory (e.g. "funny-cats" vs "political-rally").
    public static func build(_ u: MultimodalContentUnderstandingV1,
                             conflictPairs: [(String, String)] = []) -> CrossModalEvidenceGraphV1 {
        // Group determinable evidence by (kind=topic/entity concept) → value.
        var byConcept: [String: [ModalEvidenceSignal]] = [:]
        for e in u.evidence where (e.kind == "topic" || e.kind == "entity" || e.kind == "concept") {
            guard e.calibratedConfidence != nil || e.rawConfidence != nil else { continue }   // skip UNAVAILABLE
            byConcept[e.value, default: []].append(e)
        }
        var concepts: [ConceptEvidence] = []
        var agreements: [String] = []
        for (concept, sigs) in byConcept {
            let mods = Array(Set(sigs.map { $0.modality }))
            let base = sigs.map { $0.calibratedConfidence ?? $0.rawConfidence ?? 0 }.max() ?? 0
            // Agreement boost: each additional corroborating modality closes part of the gap to 1.0 (diminishing).
            var fused = base
            let extraModalities = max(0, mods.count - 1)
            for _ in 0..<extraModalities { fused = fused + (1 - fused) * 0.35 }
            let agree = extraModalities >= 1
            if agree { agreements.append("\(concept)[\(mods.map{$0.rawValue}.joined(separator: "+"))]") }
            concepts.append(ConceptEvidence(concept: concept, supportingModalities: mods, conflictingModalities: [],
                                            fusedConfidence: min(1, fused), agreement: agree, conflict: false))
        }
        // Contradiction penalty: if both sides of a conflict pair are present, penalize BOTH (ambiguous content).
        var conflicts: [String] = []
        var penalized = concepts
        for (a, b) in conflictPairs {
            guard let ia = penalized.firstIndex(where: { $0.concept == a }),
                  let ib = penalized.firstIndex(where: { $0.concept == b }) else { continue }
            conflicts.append("\(a)<x>\(b)")
            let otherMods: [Modality] = Array(Set(penalized[ia].supportingModalities + penalized[ib].supportingModalities))
            for idx in [ia, ib] {
                let c = penalized[idx]
                penalized[idx] = ConceptEvidence(concept: c.concept, supportingModalities: c.supportingModalities,
                                                 conflictingModalities: otherMods,
                                                 fusedConfidence: c.fusedConfidence * 0.4, agreement: c.agreement, conflict: true)
            }
        }
        return CrossModalEvidenceGraphV1(concepts: penalized, agreements: agreements, conflicts: conflicts)
    }
}
