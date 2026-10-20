import Foundation
import CryptoKit

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC CALIBRATION METHODOLOGY V3 — canonical statistical law after AUDIT15 (R2).
//
// Supersedes (BY RECORD, not by mutation) RWCCalibrationMethodologyV1 ("rwc-calibration-
// methodology-v2"), which stays byte-frozen as AUDIT15 negative evidence (A15-F5/F9/F10/F11 pins).
//
// PRIMARY DECISION RULE (frozen; see RWC_FROZEN_GATES_V3.yaml):
//   statistic  : tie-invariant equal-mass binned ECE (TIE-GROUP BINNING LAW below).
//   test       : exact Monte-Carlo p-value under the consistency null H0: y*_i ~ Bernoulli(p_i),
//                p_MC = (1 + #{ECE_null >= ECE_observed}) / (S + 1), with S chosen so that
//                0.05·(S+1) is an integer — the test is EXACT at level 5% under exchangeability
//                (ties counted conservatively toward rejection-avoidance via ">=").
//                FAIL iff p_MC <= 0.05.
//   secondary  : nullAdjustedExcessECE = max(0, observed − mean(null)) <= 0.05.
//                SCIENTIFIC STATUS (A15-F10): this is an OPERATIONAL CALIBRATION ACCEPTANCE
//                STATISTIC — a heuristic Monte-Carlo bias adjustment. It is NOT an unbiased
//                estimator of, nor an upper/lower BOUND on, population calibration error; AUDIT15
//                measured systematic underestimation of true L1 miscalibration (up to ~62%
//                relative, oscillating profile). A future PASS therefore means exactly:
//                "passed this preregistered operational calibration acceptance test on the decided
//                evaluation set" — never "true calibration error <= 5%" and never "calibrated
//                everywhere". Detection limits are characterized pre-data in
//                RWC_CALIBRATION_POWER_RESULTS_V3.json.
//   PASS = test gate AND excess gate.
//
// TIE-GROUP BINNING LAW (A15-F9; cross-language identical, see rwc_methodology_v3_differential.py):
//   1. Form tie groups: items with EXACTLY equal prediction value form one atomic group.
//   2. Order groups by ascending prediction value.
//   3. cStart(g) = number of items with prediction strictly below g's value.
//   4. bin(g) = (cStart(g) * B) / n  — INTEGER arithmetic; a group is never split across bins.
//   5. Per-bin sums use exact arithmetic: sumP_b = Σ_g p_g·count_g, sumY_b = Σ_g positives_g,
//      accumulated in ascending-group order. ECE = Σ_b (count_b/n)·|sumP_b/count_b − sumY_b/count_b|.
//   The statistic is a pure function of the (prediction, label) MULTISET: permutation-invariant by
//   construction. Labels are never tie-breakers. Effective bins may be fewer than B under ties.
//
// INPUT DOMAIN LAW (A15-F5): every entry point validates and throws typed refusals. INVALID INPUT
// != VALID METRIC — no NaN, no clamp, no silent PASS/0.
//
// SEED LAW (A15-F11/F7; cross-language stable, no Python hash(), no Swift Hasher):
//   seed64(context) = big-endian UInt64 of the first 8 bytes of SHA-256(context), where
//   context = "GEN8-RWC-CAL-V3|" + part1 + "|" + part2 + ... For the REAL evaluation the frozen
//   formula is "GEN8-RWC-CAL-V3|eval|<datasetManifestSHA256>|<metricID>" — fixed pre-data, never
//   outcome-inspecting; anyone can re-derive the identical verdict.
//   frozenNullSims (S) is selected PRE-DATA by the Monte-Carlo stability study
//   (RWC_CALIBRATION_MC_STABILITY_V3.json) against the predeclared instability target.
//
// ZERO-DATA: synthetic inputs only; no real predictions, labels or corpus touch this module.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

enum RWCCalibrationInputErrorV1: Error, Equatable {
    case emptyInput
    case countMismatch(predictions: Int, labels: Int)
    case nonFiniteProbability(index: Int)
    case probabilityOutOfRange(index: Int)
    case invalidBins(bins: Int, n: Int)
    case invalidSimulationCount(Int)
}

enum RWCCalibrationMethodologyV3 {
    static let version = "rwc-calibration-methodology-v3"
    static let bins = 10
    /// Exact-test size: 0.05 * (S+1) must be an integer (enforced as (S+1) % 20 == 0). Chosen by
    /// the pre-data MC stability study per the PREDECLARED rule "smallest candidate S with
    /// null-suite mixed-verdict fraction <= 1.5%": measured null-suite mixed fraction was 0.0% at
    /// ALL candidates {999, 4999, 9999} (RWC_CALIBRATION_MC_STABILITY_V3.json), so the rule selects
    /// S = 999. At-boundary (over@.05) mixed fraction 3.3% at S=999 vs 2.5% at S>=4999 is inherent
    /// statistical boundary uncertainty, honestly reported; the REAL evaluation verdict is
    /// single-valued regardless, because the evaluation seed itself is frozen by the seed law.
    static let frozenNullSims = 999
    static let alpha = 0.05
    /// Operational acceptance threshold for nullAdjustedExcessECE (heuristic statistic — see header).
    static let nullAdjustedExcessLimit = 0.05
    /// Frozen overall decided-set size law from the v3 power derivation
    /// (RWC_CALIBRATION_POWER_RESULTS_V3.json).
    static let frozenOverallN = 800
    /// Coverage hard-gate threshold (carried from v2 law; typed-counter enforcement is new).
    static let frozenMinDecisionCoverage = 0.80

    // MARK: Seed law

    static func seed64(_ parts: [String]) -> UInt64 {
        let context = (["GEN8-RWC-CAL-V3"] + parts).joined(separator: "|")
        let digest = SHA256.hash(data: Data(context.utf8))
        var v: UInt64 = 0
        for (i, byte) in digest.enumerated() where i < 8 { v = (v << 8) | UInt64(byte) }
        return v
    }

    // MARK: Input domain

    static func validate(preds: [Double], labels: [Bool], bins: Int) throws {
        guard !preds.isEmpty else { throw RWCCalibrationInputErrorV1.emptyInput }
        guard preds.count == labels.count else {
            throw RWCCalibrationInputErrorV1.countMismatch(predictions: preds.count, labels: labels.count)
        }
        for (i, p) in preds.enumerated() {
            guard p.isFinite else { throw RWCCalibrationInputErrorV1.nonFiniteProbability(index: i) }
            guard p >= 0.0, p <= 1.0 else { throw RWCCalibrationInputErrorV1.probabilityOutOfRange(index: i) }
        }
        guard bins >= 1, bins <= preds.count else {
            throw RWCCalibrationInputErrorV1.invalidBins(bins: bins, n: preds.count)
        }
    }

    // MARK: Tie-group binning

    struct TieGroupPlanV1: Equatable {
        let n: Int
        let bins: Int
        let groupValues: [Double]   // ascending unique prediction values
        let groupCounts: [Int]
        let groupBins: [Int]        // integer law: (cStart * bins) / n
    }

    static func tieGroupPlan(preds: [Double], bins: Int) -> TieGroupPlanV1 {
        let sorted = preds.sorted()
        var values: [Double] = [], counts: [Int] = [], groupBins: [Int] = []
        var i = 0
        while i < sorted.count {
            let v = sorted[i]
            var j = i
            while j < sorted.count, sorted[j] == v { j += 1 }
            values.append(v)
            counts.append(j - i)
            groupBins.append((i * bins) / sorted.count)
            i = j
        }
        return TieGroupPlanV1(n: sorted.count, bins: bins, groupValues: values, groupCounts: counts,
                              groupBins: groupBins)
    }

    /// Tie-invariant equal-mass ECE. Pure function of the (p, y) multiset.
    static func eceTieInvariant(preds: [Double], labels: [Bool], bins: Int = bins) throws -> Double {
        try validate(preds: preds, labels: labels, bins: bins)
        let plan = tieGroupPlan(preds: preds, bins: bins)
        // positives per group: aggregate by prediction value (order-free integer sums)
        var positivesByValue: [Double: Int] = [:]
        for (p, y) in zip(preds, labels) where y { positivesByValue[p, default: 0] += 1 }
        var sumP = [Double](repeating: 0, count: bins)
        var sumY = [Double](repeating: 0, count: bins)
        var count = [Int](repeating: 0, count: bins)
        for g in 0..<plan.groupValues.count {
            let b = plan.groupBins[g]
            sumP[b] += plan.groupValues[g] * Double(plan.groupCounts[g])
            sumY[b] += Double(positivesByValue[plan.groupValues[g]] ?? 0)
            count[b] += plan.groupCounts[g]
        }
        var ece = 0.0
        for b in 0..<bins where count[b] > 0 {
            let c = Double(count[b])
            ece += c / Double(plan.n) * abs(sumP[b] / c - sumY[b] / c)
        }
        return ece
    }

    // MARK: Primary decision

    struct CalibrationDecisionV3: Equatable {
        let observed: Double
        let pMC: Double
        let nullMean: Double
        let nullAdjustedExcessECE: Double
        let sims: Int
        let testGatePassed: Bool     // p_MC > alpha
        let excessGatePassed: Bool   // nullAdjustedExcessECE <= limit
        var passed: Bool { testGatePassed && excessGatePassed }
    }

    /// Null ECE for one simulation, reusing the dataset's tie-group plan (identical estimator law).
    private static func nullECE(plan: TieGroupPlanV1, rng: inout RWCSplitMix64) -> Double {
        var sumP = [Double](repeating: 0, count: plan.bins)
        var sumY = [Double](repeating: 0, count: plan.bins)
        var count = [Int](repeating: 0, count: plan.bins)
        for g in 0..<plan.groupValues.count {
            let b = plan.groupBins[g], p = plan.groupValues[g], c = plan.groupCounts[g]
            var pos = 0
            for _ in 0..<c where rng.double01() < p { pos += 1 }
            sumP[b] += p * Double(c)
            sumY[b] += Double(pos)
            count[b] += c
        }
        var ece = 0.0
        for b in 0..<plan.bins where count[b] > 0 {
            let c = Double(count[b])
            ece += c / Double(plan.n) * abs(sumP[b] / c - sumY[b] / c)
        }
        return ece
    }

    /// The frozen v3 decision. `seedParts` must follow the frozen seed law (never outcome-derived).
    static func decideV3(preds: [Double], labels: [Bool], bins: Int = bins,
                         sims: Int = frozenNullSims, seedParts: [String]) throws -> CalibrationDecisionV3 {
        // Exactness is enforced in INTEGER arithmetic (alpha = 1/20): (S+1) must be divisible by 20.
        guard sims >= 19, (sims + 1) % 20 == 0 else {
            throw RWCCalibrationInputErrorV1.invalidSimulationCount(sims)
        }
        let observed = try eceTieInvariant(preds: preds, labels: labels, bins: bins)
        let plan = tieGroupPlan(preds: preds, bins: bins)
        var rng = RWCSplitMix64(seed: seed64(seedParts))
        var exceed = 0
        var nullSum = 0.0
        for _ in 0..<sims {
            let e = nullECE(plan: plan, rng: &rng)
            nullSum += e
            if e >= observed { exceed += 1 }
        }
        let pMC = Double(1 + exceed) / Double(sims + 1)
        let nullMean = nullSum / Double(sims)
        let excess = max(0, observed - nullMean)
        // Boundary law in INTEGER arithmetic (immune to binary representation of 0.05):
        // FAIL iff p_MC <= alpha  ⇔  20·(1 + exceed) <= (S + 1).
        let testFails = 20 * (1 + exceed) <= (sims + 1)
        return CalibrationDecisionV3(observed: observed, pMC: pMC, nullMean: nullMean,
                                     nullAdjustedExcessECE: excess, sims: sims,
                                     testGatePassed: !testFails,
                                     excessGatePassed: excess <= nullAdjustedExcessLimit)
    }

    // MARK: Coverage V2 (typed counters; A15-F6)

    enum RWCCoverageErrorV1: Error, Equatable {
        case negativeCount(field: String)
        case impossibleCount(rule: String)
        case hardGateRequiresInDistribution
        case decisionCoverageBelowGate(coverage: Double)
    }

    struct RWCCoverageCountsV1: Equatable {
        let inDistDecided: Int
        let inDistTotal: Int
        let oodAbstained: Int
        let oodTotal: Int
        let sentinelProtective: Int
        let sentinelDecided: Int
        let sentinelTotal: Int
        init(inDistDecided: Int, inDistTotal: Int, oodAbstained: Int, oodTotal: Int,
             sentinelProtective: Int, sentinelDecided: Int, sentinelTotal: Int) {
            self.inDistDecided = inDistDecided; self.inDistTotal = inDistTotal
            self.oodAbstained = oodAbstained; self.oodTotal = oodTotal
            self.sentinelProtective = sentinelProtective; self.sentinelDecided = sentinelDecided
            self.sentinelTotal = sentinelTotal
        }
    }

    /// Undefined rates are NOT 0 — they are explicitly not applicable (zero denominator).
    enum RWCRateV2: Equatable {
        case value(Double)
        case notApplicable
    }

    struct RWCCoverageReportV2: Equatable {
        let decisionCoverage: RWCRateV2
        let abstentionRate: RWCRateV2
        let oodAbstentionRate: RWCRateV2
        let sentinelProtectiveRate: RWCRateV2
        let sentinelExplicitDecisionRate: RWCRateV2
        let sentinelAbstentionRate: RWCRateV2
    }

    static func coverageV2(_ c: RWCCoverageCountsV1) throws -> RWCCoverageReportV2 {
        let fields: [(String, Int)] = [("inDistDecided", c.inDistDecided), ("inDistTotal", c.inDistTotal),
                                       ("oodAbstained", c.oodAbstained), ("oodTotal", c.oodTotal),
                                       ("sentinelProtective", c.sentinelProtective),
                                       ("sentinelDecided", c.sentinelDecided), ("sentinelTotal", c.sentinelTotal)]
        for (name, v) in fields where v < 0 { throw RWCCoverageErrorV1.negativeCount(field: name) }
        guard c.inDistDecided <= c.inDistTotal else {
            throw RWCCoverageErrorV1.impossibleCount(rule: "inDistDecided <= inDistTotal")
        }
        guard c.oodAbstained <= c.oodTotal else {
            throw RWCCoverageErrorV1.impossibleCount(rule: "oodAbstained <= oodTotal")
        }
        guard c.sentinelProtective <= c.sentinelTotal else {
            throw RWCCoverageErrorV1.impossibleCount(rule: "sentinelProtective <= sentinelTotal")
        }
        guard c.sentinelDecided <= c.sentinelTotal else {
            throw RWCCoverageErrorV1.impossibleCount(rule: "sentinelDecided <= sentinelTotal")
        }
        func rate(_ a: Int, _ b: Int) -> RWCRateV2 { b > 0 ? .value(Double(a) / Double(b)) : .notApplicable }
        return RWCCoverageReportV2(
            decisionCoverage: rate(c.inDistDecided, c.inDistTotal),
            abstentionRate: rate(c.inDistTotal - c.inDistDecided, c.inDistTotal),
            oodAbstentionRate: rate(c.oodAbstained, c.oodTotal),
            sentinelProtectiveRate: rate(c.sentinelProtective, c.sentinelTotal),
            sentinelExplicitDecisionRate: rate(c.sentinelDecided, c.sentinelTotal),
            sentinelAbstentionRate: rate(c.sentinelTotal - c.sentinelDecided, c.sentinelTotal))
    }

    /// Coverage HARD GATE: requires a valid nonzero in-distribution denominator; calibration claims
    /// are DECIDED-SET conditional (gates v3 claim-scope law).
    static func requireDecisionCoverageGate(_ c: RWCCoverageCountsV1) throws {
        let report = try coverageV2(c)
        guard case let .value(cov) = report.decisionCoverage else {
            throw RWCCoverageErrorV1.hardGateRequiresInDistribution
        }
        guard cov >= frozenMinDecisionCoverage else {
            throw RWCCoverageErrorV1.decisionCoverageBelowGate(coverage: cov)
        }
    }

    // MARK: IRR planning law (A15-F14; thresholds unchanged)

    /// Mathematical evaluability floor (unchanged): below this the bootstrap is INSUFFICIENT_DATA.
    static let irrMinValidPairs = 50
    /// PLANNED campaign target (pre-data planning law, RWC_IRR_PLANNING_V3.md): the CI-lower-bound
    /// gate is strongly conservative at small n (AUDIT15: true kappa=.70 passes only 17-42% at
    /// n<=200), so annotation campaigns must PLAN n >= this target; the gate itself is NOT weakened.
    static let irrPlannedTargetPairs = 300
}
