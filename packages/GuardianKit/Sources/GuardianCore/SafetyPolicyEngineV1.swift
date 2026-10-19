import Foundation

// MARK: - P009D §4 — H1 high-risk visual safety registry: evidence-backed UNAVAILABLE, never inferred
// safe from generic Vision labels, never a positive admission from missing evidence.

public struct HighRiskVisualClassRecordV1: Sendable, Codable {
    public let classID: String
    public let classDefinition: String
    public let provider: String                   // "NONE" — no dedicated audited classifier exists
    public let capabilityProfile: String
    public let datasetProvenance: String
    public let calibrationStatus: String
    public let heldOutEvidence: String
    public let falseSafeEvidence: String
    public let deviceRuntimeStatus: String
    public let version: String
}

public enum HighRiskVisualSafetyRegistryV1 {
    public static let version = "h1-visual-safety-registry-v1"
    static func unavailableRecord(_ id: String, _ def: String) -> HighRiskVisualClassRecordV1 {
        HighRiskVisualClassRecordV1(classID: id, classDefinition: def, provider: "NONE",
                                    capabilityProfile: "NONE (no profile may claim it)",
                                    datasetProvenance: "NONE — no rights-clear audited dataset integrated",
                                    calibrationStatus: "UNAVAILABLE_EVIDENCE_BACKED",
                                    heldOutEvidence: "NONE", falseSafeEvidence: "NONE",
                                    deviceRuntimeStatus: "UNAVAILABLE", version: version)
    }
    /// H1 remains an explicit, evidence-backed OPEN blocker — every class honestly UNAVAILABLE.
    public static let records: [HighRiskVisualClassRecordV1] = [
        unavailableRecord("h1.explicit-sexual-visual", "sexually explicit imagery detection"),
        unavailableRecord("h1.violence-gore-visual", "graphic violence / gore / severe injury imagery"),
        unavailableRecord("h1.self-harm-visual", "self-harm act imagery"),
        unavailableRecord("h1.dangerous-act-visual", "imitable dangerous behavior imagery")
    ]
    public static var allUnavailable: Bool {
        records.allSatisfy { $0.calibrationStatus == "UNAVAILABLE_EVIDENCE_BACKED" && $0.provider == "NONE" }
    }
    /// LAW: generic Vision scene labels can never produce a visually-safe conclusion.
    public static func visuallySafeConclusionAllowed() -> Bool { false }
}

// MARK: - §4/§3 — safety policy engine: world model → per-dimension findings with TRUTHFUL statuses.

public struct SafetyDimensionFindingV1: Sendable {
    public let dimension: SafetyDimensionV1
    public let status: EvidenceCalibrationStatusV2         // from SafetyDimensionTruthV1 — never upgraded
    public let evidencePresent: Bool                       // only meaningful when status != .unavailable
    public let severityBand: String                        // "none" | "present" | "strong" (categorical)
    public let basis: [String]                             // canonical evidence labels
}

public struct SafetyPolicyResultV1: Sendable {
    public let findings: [SafetyDimensionFindingV1]
    public let strongProtectionSupported: Bool
    public let strongProtectionBasis: [String]
    public let cautionSupported: Bool
    public let unavailableDimensions: [SafetyDimensionV1]
    public let reasons: [PolicyProvenanceV1]
}

public enum SafetyPolicyEngineV1 {
    public static let revision = "safety-policy-engine-v1"

    public static func evaluate(worldModel m: ContentWorldModelV1) -> SafetyPolicyResultV1 {
        var findings: [SafetyDimensionFindingV1] = []
        var reasons: [PolicyProvenanceV1] = []
        var unavailable: [SafetyDimensionV1] = []
        let safety = Set(m.safetyEvidence)
        let manip = m.manipulationEvidence

        for dim in SafetyDimensionV1.allCases {
            let status = SafetyDimensionTruthV1.status[dim] ?? .unavailable
            switch dim {
            case .sensitiveNews:
                let present = safety.contains { $0.hasPrefix("safety:sensitive-death-disease-news") }
                let strong = present && m.maxRiskSeen >= 0.6
                findings.append(SafetyDimensionFindingV1(dimension: dim, status: status, evidencePresent: present,
                                                         severityBand: strong ? "strong" : (present ? "present" : "none"),
                                                         basis: m.safetyEvidence.filter { $0.hasPrefix("safety:sensitive") }))
            case .fearThreat:
                let present = safety.contains { $0.hasPrefix("safety:fear-threat") }
                findings.append(SafetyDimensionFindingV1(dimension: dim, status: status, evidencePresent: present,
                                                         severityBand: present && m.maxRiskSeen >= 0.6 ? "strong" : (present ? "present" : "none"),
                                                         basis: m.safetyEvidence.filter { $0.hasPrefix("safety:fear") }))
            case .manipulationAttention:
                let present = !manip.isEmpty
                findings.append(SafetyDimensionFindingV1(dimension: dim, status: status, evidencePresent: present,
                                                         severityBand: manip.count >= 2 ? "strong" : (present ? "present" : "none"),
                                                         basis: manip))
            default:
                // §3/§4 capability truth: no dedicated audited capability — the dimension can neither
                // clear nor convict. UNAVAILABLE is a state, never silence.
                unavailable.append(dim)
                findings.append(SafetyDimensionFindingV1(dimension: dim, status: .unavailable, evidencePresent: false,
                                                         severityBand: "none", basis: []))
            }
        }
        reasons.append(PolicyProvenanceV1(code: .h1VisualUnavailable, producer: revision,
                                          basis: "H1 registry: all visual high-risk classes UNAVAILABLE_EVIDENCE_BACKED"))

        // §4 escalation law: strong lexical/audio/world-model risk escalates even with H1 open.
        let multimodalDominant = m.contradictionResolutions.contains { $0.outcome == .strongRiskDominant }
        let strongRisk = m.maxRiskSeen >= 0.8 && !m.safetyEvidence.isEmpty && m.knowledgeState != .unavailable
        let strongProtection = strongRisk || (multimodalDominant && m.maxRiskSeen >= 0.6)
        var strongBasis: [String] = []
        if strongProtection {
            strongBasis = m.safetyEvidence + (multimodalDominant ? ["contradiction:STRONG_RISK_DOMINANT"] : [])
            reasons.append(PolicyProvenanceV1(code: .strongRiskEscalation, producer: revision,
                                              basis: "maxRisk=\(String(format: "%.2f", m.maxRiskSeen)) multimodalDominant=\(multimodalDominant)"))
            if multimodalDominant {
                reasons.append(PolicyProvenanceV1(code: .highRiskMultimodalConflict, producer: revision,
                                                  basis: "risk-vs-positive resolved STRONG_RISK_DOMINANT"))
            }
        }
        let caution = !strongProtection && findings.contains { $0.status != .unavailable && $0.evidencePresent }
        return SafetyPolicyResultV1(findings: findings, strongProtectionSupported: strongProtection,
                                    strongProtectionBasis: strongBasis, cautionSupported: caution,
                                    unavailableDimensions: unavailable, reasons: reasons)
    }
}
