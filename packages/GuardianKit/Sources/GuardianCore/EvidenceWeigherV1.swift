import Foundation

// MARK: - P009C §10 — evidence weighting. LAWS: never average all confidences; correlated evidence
// (same independence family) can never multiply certainty — within a family only the MAX survives;
// across families combination is bounded.

public struct WeightedEvidenceV1: Sendable {
    public let family: String                      // independence family (correlated evidence shares one)
    public let weight: Double                      // 0…1 after all discounts
    public let basis: String
}

public enum EvidenceWeigherV1 {
    public static let revision = "evidence-weigher-v1"

    /// Independence family per evidence record — gross-luma lesson from P009A carried into semantics:
    /// lexical evidence from OCR and from speech TRANSCRIPTS of the same words are the SAME family when
    /// both are text-lexicon derived; visual scene labels are one family; audio classes one; temporal one.
    public static func family(of e: ExpertEvidenceV2) -> String {
        switch e.domain {
        case .languageOCR, .speech, .safetyEvidence, .benefitEvidence, .attentionPressure, .symbol:
            return "family:text-lexical"           // all lexicon/text-derived — correlated by construction
        case .vision: return "family:visual"
        case .audioEvent, .music: return "family:audio"
        case .temporal: return "family:temporal"
        }
    }

    /// Per-record weight: calibration class × availability × quality × OOD × staleness discounts.
    public static func weight(of e: ExpertEvidenceV2, contradictionInvolved: Bool, identityStable: Bool) -> Double {
        guard e.inputModalityAvailable, !e.stale else { return 0 }
        var w: Double
        switch e.calibrationStatus {
        case .implementedCalibrated: w = 1.0       // unreachable in P009C (score OFF) — kept for contract completeness
        case .implementedUncalibrated: w = 0.8
        case .heuristicSupportOnly: w = 0.5
        case .unavailable: return 0
        }
        w *= min(1, max(0, e.confidence)) * min(1, max(0, e.coverage))
        if e.oodIndicator { w *= 0.4 }
        if contradictionInvolved { w *= 0.7 }
        if !identityStable { w *= 0.6 }
        return min(1, w)
    }

    /// Combine a set of evidence records into family-weighted strengths.
    /// WITHIN a family: MAX (correlated evidence never stacks).
    /// ACROSS families: bounded support = max + 0.15 per additional independent family, capped at 1.
    public static func combine(_ evidence: [ExpertEvidenceV2], contradictionDomains: Set<ExpertDomainV2> = [],
                               identityStable: Bool = true) -> (strength: Double, families: [WeightedEvidenceV1]) {
        var byFamily: [String: WeightedEvidenceV1] = [:]
        for e in evidence {
            let w = weight(of: e, contradictionInvolved: contradictionDomains.contains(e.domain), identityStable: identityStable)
            guard w > 0 else { continue }
            let f = family(of: e)
            if let existing = byFamily[f] {
                if w > existing.weight { byFamily[f] = WeightedEvidenceV1(family: f, weight: w, basis: e.provenance) }
            } else {
                byFamily[f] = WeightedEvidenceV1(family: f, weight: w, basis: e.provenance)
            }
        }
        let fams = byFamily.values.sorted { $0.weight > $1.weight }
        guard let top = fams.first else { return (0, []) }
        var strength = top.weight
        for extra in fams.dropFirst() where extra.weight > 0.2 { strength = min(1, strength + 0.15) }
        return (strength, fams)
    }
}
