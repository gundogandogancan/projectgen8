import Foundation

// MARK: - P009C-R1 §8 — world-model evidence purity gate. The cache may never hold a model whose
// evidence does not PURELY belong to the claimed item/revision/generation — the semantic mirror of the
// DNA finalizer's foreignEvidence law. Foreign/stale/incompatible → reject (write) / invalidate (read).

public enum WorldModelEvidencePurityGateV1 {
    public static let revision = "world-model-evidence-purity-gate-v1"
    public enum ImpurityV1: String, Sendable {
        case foreignItemEvidence = "foreign-item-evidence"
        case foreignGenerationEvidence = "foreign-generation-evidence"
        case provisionalEvidence = "provisional-evidence"
        case staleExcludedResidue = "stale-evidence-present"
        case modelVersionIncompatible = "model-version-incompatible"
        case taxonomyIncompatible = "taxonomy-incompatible"
        case identityNotConfirmed = "identity-not-confirmed"
    }
    public static func violations(_ model: ContentWorldModelV1) -> [ImpurityV1] {
        var v: [ImpurityV1] = []
        guard let item = model.itemID else { return [.identityNotConfirmed] }
        if model.identityStatus != "confirmed" { v.append(.identityNotConfirmed) }
        if model.anyEvidenceProvisional { v.append(.provisionalEvidence) }
        if !model.evidenceItemIDs.isSubset(of: [item.raw]) { v.append(.foreignItemEvidence) }
        if !model.evidenceGenerations.isSubset(of: [model.generation]) { v.append(.foreignGenerationEvidence) }
        if ContentWorldModelV1.modelVersion != "content-world-model-v1" { v.append(.modelVersionIncompatible) }
        if model.taxonomyVersion != SemanticTaxonomyV1.version { v.append(.taxonomyIncompatible) }
        return v
    }
}
