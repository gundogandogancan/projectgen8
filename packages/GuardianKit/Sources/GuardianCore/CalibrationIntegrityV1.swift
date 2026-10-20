import Foundation

// MARK: - Real-World Calibration Entry Gate — A9-R1-F2 + A9-R1-F3 contracts.
// F2 LAW: declared dataset != resolved dataset -> NO FIT, NO METRICS — typed integrity failure only.
// F3 LAW: probability inputs must be finite and in [0,1]; invalid domain -> typed refusal, never a
// silent clamp into any metric denominator.

public enum CalibrationIntegrityErrorV1: Error, Equatable {
    case unresolvedPairs(declared: Int, resolved: Int, unresolvedIDs: [String], category: String)
    // R1 (A10-F2-MULTISET): composite IDs are UNIQUE by contract — duplicates are their own typed
    // integrity failures, which makes multiset-cancellation attacks structurally impossible.
    case duplicateDeclaredIDs(ids: [String], category: String)
    case duplicateResolvedIDs(ids: [String], category: String)
    case unexpectedResolvedIDs(ids: [String], category: String)
    case malformedIDs(declared: Int, resolved: Int, category: String)
}

public enum CalibrationRunGuardV1 {
    public static let revision = "calibration-run-guard-v2"   // R1: exact-identity + uniqueness law
    /// F2 hard gate (R1 CANONICAL IDENTITY LAW): DECLARED identities must equal RESOLVED identities
    /// exactly. Enforced invariants, in order: (1) no malformed/empty ID on either side; (2) declared
    /// IDs unique; (3) resolved IDs unique; (4) every declared ID resolved (missing named, sorted);
    /// (5) no unexpected resolved extras. With (2)+(3), set equality == multiset equality — the
    /// AUDIT10 cancellation shapes ([a,a,b]~[a,b,b], [a,a]~[a,b]) are refused at (2). Acceptance is
    /// order-independent. Diagnostics carry only opaque IDs/counts/category (no content, no PII).
    public static func requireFullResolution(declaredIDs: [String], resolvedIDs: [String],
                                             category: String = "scenario-resolution") throws {
        func duplicates(_ ids: [String]) -> [String] {
            var seen = Set<String>(), dup = Set<String>()
            for id in ids { if !seen.insert(id).inserted { dup.insert(id) } }
            return dup.sorted()
        }
        let malformedD = declaredIDs.filter { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        let malformedR = resolvedIDs.filter { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard malformedD.isEmpty, malformedR.isEmpty else {
            throw CalibrationIntegrityErrorV1.malformedIDs(declared: malformedD.count,
                                                           resolved: malformedR.count, category: category)
        }
        let dupD = duplicates(declaredIDs)
        guard dupD.isEmpty else {
            throw CalibrationIntegrityErrorV1.duplicateDeclaredIDs(ids: dupD, category: category)
        }
        let dupR = duplicates(resolvedIDs)
        guard dupR.isEmpty else {
            throw CalibrationIntegrityErrorV1.duplicateResolvedIDs(ids: dupR, category: category)
        }
        let declared = Set(declaredIDs), resolved = Set(resolvedIDs)
        let missing = declared.subtracting(resolved)
        guard missing.isEmpty else {
            throw CalibrationIntegrityErrorV1.unresolvedPairs(declared: declaredIDs.count,
                                                              resolved: resolvedIDs.count,
                                                              unresolvedIDs: missing.sorted(),
                                                              category: category)
        }
        let extras = resolved.subtracting(declared)
        guard extras.isEmpty else {
            throw CalibrationIntegrityErrorV1.unexpectedResolvedIDs(ids: extras.sorted(), category: category)
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
