import Foundation

// MARK: - Real-World Calibration Entry Gate — A9-R1-F2 + A9-R1-F3 contracts.
// F2 LAW: declared dataset != resolved dataset -> NO FIT, NO METRICS — typed integrity failure only.
// F3 LAW: probability inputs must be finite and in [0,1]; invalid domain -> typed refusal, never a
// silent clamp into any metric denominator.

public enum CalibrationIntegrityErrorV1: Error, Equatable {
    case unresolvedPairs(declared: Int, resolved: Int, unresolvedIDs: [String], category: String)
}

public enum CalibrationRunGuardV1 {
    public static let revision = "calibration-run-guard-v1"
    /// F2 hard gate: throws unless EVERY declared pair resolved. Diagnostics carry only non-sensitive
    /// identifiers/counts (no content, no PII).
    public static func requireFullResolution(declaredIDs: [String], resolvedIDs: [String],
                                             category: String = "scenario-resolution") throws {
        let unresolved = declaredIDs.filter { !resolvedIDs.contains($0) }
        guard unresolved.isEmpty, declaredIDs.count == resolvedIDs.count else {
            throw CalibrationIntegrityErrorV1.unresolvedPairs(declared: declaredIDs.count,
                                                              resolved: resolvedIDs.count,
                                                              unresolvedIDs: unresolved.sorted(),
                                                              category: category)
        }
    }
}

public enum MetricInputErrorV1: Error, Equatable {
    case nonFinite(index: Int)
    case outOfDomain(index: Int, value: Double)
    case invalidBins(Int)
    case shapeMismatch(preds: Int, labels: Int)
}

public extension CalibrationMetricsV1 {
    /// F3 domain validator: nil = valid; otherwise the FIRST violation (typed, index-bearing).
    static func validateProbabilities(_ preds: [Double]) -> MetricInputErrorV1? {
        for (i, p) in preds.enumerated() {
            if !p.isFinite { return .nonFinite(index: i) }
            if p < 0 || p > 1 { return .outOfDomain(index: i, value: p) }
        }
        return nil
    }
    /// F3 STRICT metric entrypoint — the calibration pipeline's only lawful door. Hard-refuses invalid
    /// domain/shape/bins; valid 0 and 1 inclusive; bin law: index = min(bins-1, floor(p*bins)) —
    /// binary-fp boundary behavior (e.g. 0.3*10 rounds DOWN) is deterministic and documented.
    static func eceAndBinsStrict(preds: [Double], labels: [Bool], bins: Int = 10) throws -> (ece: Double, brier: Double, bins: [BinV1]) {
        guard bins >= 1 else { throw MetricInputErrorV1.invalidBins(bins) }
        guard preds.count == labels.count else { throw MetricInputErrorV1.shapeMismatch(preds: preds.count, labels: labels.count) }
        if let e = validateProbabilities(preds) { throw e }
        return eceAndBins(preds: preds, labels: labels, bins: bins)
    }
}
