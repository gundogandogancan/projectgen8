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
    // PRE-14 R1 (A14-F5): RWC composite-grammar law at the canonical door — diagnostics carry
    // count + first offending index + category ONLY (invalid raw strings are never echoed).
    case invalidRWCCompositeIDs(count: Int, firstIndex: Int, category: String)
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
    // R1 (A10-F3-SIBLINGS): one domain doctrine for EVERY metric — INVALID INPUT ≠ VALID METRIC.
    case emptyInput
    case degenerateLabels(positives: Int, negatives: Int)      // AUROC undefined on one-class labels
}

public extension CalibrationMetricsV1 {
    /// F3 domain validator: nil = valid; otherwise the FIRST violation (typed, index-bearing).
    static func validateProbabilities(_ preds: [Double]) -> MetricInputErrorV1? {
        validateValues(preds, domain: 0...1)
    }
    /// R1 shared validation rule (A10-F3-SIBLINGS): finite always; domain bounds where the metric
    /// defines them. ECE/Brier/MAE/AUROC all bind to this single doctrine.
    static func validateValues(_ xs: [Double], domain: ClosedRange<Double>?) -> MetricInputErrorV1? {
        for (i, x) in xs.enumerated() {
            if !x.isFinite { return .nonFinite(index: i) }
            if let d = domain, !d.contains(x) { return .outOfDomain(index: i, value: x) }
        }
        return nil
    }
    /// F3 STRICT metric entrypoint — the calibration pipeline's only lawful door. Hard-refuses invalid
    /// domain/shape/bins; valid 0 and 1 inclusive; bin law: index = min(bins-1, floor(p*bins)).
    /// fp-boundary truth (A10-F3-FPEDGE corrected; see docs/audit/AUDIT9_FPEDGE_ERRATUM.md): the fp
    /// product 0.3*10.0 rounds UP to exactly 3.0 → Int(0.3*10.0) == 3 → bin 3; empirically NO k/10
    /// boundary floors down at bins=10. Deterministic and exactly-once either way.
    static func eceAndBinsStrict(preds: [Double], labels: [Bool], bins: Int = 10) throws -> (ece: Double, brier: Double, bins: [BinV1]) {
        guard bins >= 1 else { throw MetricInputErrorV1.invalidBins(bins) }
        guard preds.count == labels.count else { throw MetricInputErrorV1.shapeMismatch(preds: preds.count, labels: labels.count) }
        if let e = validateProbabilities(preds) { throw e }
        return eceAndBins(preds: preds, labels: labels, bins: bins)
    }
    /// R1 STRICT MAE (A10-F3-SIBLINGS): exact shape, finite everywhere, both arrays inside `domain`
    /// (probabilities 0…1 by default; the suitability pipeline passes its rubric scale 0…4 explicitly).
    /// Empty input is not a valid metric.
    static func maeStrict(_ predicted: [Double], _ target: [Double],
                          domain: ClosedRange<Double> = 0...1) throws -> Double {
        guard predicted.count == target.count else {
            throw MetricInputErrorV1.shapeMismatch(preds: predicted.count, labels: target.count)
        }
        guard !predicted.isEmpty else { throw MetricInputErrorV1.emptyInput }
        if let e = validateValues(predicted, domain: domain) { throw e }
        if let e = validateValues(target, domain: domain) { throw e }
        return zip(predicted, target).map { abs($0 - $1) }.reduce(0, +) / Double(predicted.count)
    }
    /// R1 STRICT AUROC (A10-F3-SIBLINGS): probability domain enforced; one-class label sets are a
    /// typed refusal (AUROC undefined), never a silent nil or a miscounted finite value.
    static func aurocStrict(preds: [Double], labels: [Bool]) throws -> Double {
        guard preds.count == labels.count else {
            throw MetricInputErrorV1.shapeMismatch(preds: preds.count, labels: labels.count)
        }
        guard !preds.isEmpty else { throw MetricInputErrorV1.emptyInput }
        if let e = validateProbabilities(preds) { throw e }
        let pos = labels.filter { $0 }.count, neg = labels.count - pos
        guard pos > 0, neg > 0 else { throw MetricInputErrorV1.degenerateLabels(positives: pos, negatives: neg) }
        return auroc(preds: preds, labels: labels)!     // validated: non-degenerate, in-domain
    }
}
