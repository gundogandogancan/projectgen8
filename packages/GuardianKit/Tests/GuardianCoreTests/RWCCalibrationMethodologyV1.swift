import Foundation

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC-PRE-14 R1 — CALIBRATION METHODOLOGY v2 (A14-F7/F8/F10 closure; test/methodology tooling only).
//
// PRIMARY DESIGN (fully specified in-repo; derivation script frozen at
// docs/calibration/preregistration/tools/power_derivation.py):
//   EQUAL-MASS 10-bin ECE  +  NULL-REFERENCED decision rule (parametric bootstrap under H0):
//   null draws y* ~ Bernoulli(p_i) from the model's OWN predictions → null ECE distribution.
//   TEST gate:   observed ECE ≤ Q95(null)      → Type-I error = 5% BY CONSTRUCTION (bias-immune:
//                the null distribution carries the same finite-sample bias as the observation —
//                this is what the frozen-v1 fixed-width point gate lacked, A14-F7).
//   EFFECT gate: debiased gap = max(0, observed − mean(null)) ≤ 0.05 (absolute miscalibration bound,
//                preserving the 5-percentage-point semantics bias-corrected).
//   PASS = TEST gate AND EFFECT gate. Legacy fixed-width 10-bin ECE: REPORT-ONLY (continuity).
//
// IRR DECISION LAW (A14-F10): PASS iff the 95% seeded-bootstrap CI LOWER BOUND ≥ threshold;
// degenerate (nil) replicates are excluded; valid-replicate fraction < 0.80 → INSUFFICIENT_DATA.
// κ=.61 with CI [.30,.75] therefore yields FAIL, deterministically.
//
// All randomness is seeded SplitMix64 — byte-reproducible; ZERO real data touches any of this.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

struct RWCSplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func double01() -> Double { Double(next() >> 11) * (1.0 / 9007199254740992.0) }
}

enum RWCCalibrationMethodologyV1 {
    static let version = "rwc-calibration-methodology-v2"
    static let bins = 10
    static let nullSims = 200
    static let typeITarget = 0.05            // by construction of the Q95 rule
    static let effectBound = 0.05            // debiased absolute miscalibration bound
    static let frozenOverallN = 800          // from the frozen power derivation (see power prereg yaml)

    /// Equal-mass binned ECE (sort by prediction; B near-equal-count bins).
    static func eceEqualMass(preds: [Double], labels: [Bool], bins: Int = bins) -> Double {
        guard !preds.isEmpty, preds.count == labels.count else { return .nan }
        let order = preds.indices.sorted { preds[$0] < preds[$1] }
        let n = preds.count
        var ece = 0.0
        for b in 0..<bins {
            let lo = b * n / bins, hi = (b + 1) * n / bins
            guard hi > lo else { continue }
            let idx = order[lo..<hi]
            let mp = idx.map { preds[$0] }.reduce(0, +) / Double(idx.count)
            let fp = idx.map { labels[$0] ? 1.0 : 0.0 }.reduce(0, +) / Double(idx.count)
            ece += Double(idx.count) / Double(n) * abs(mp - fp)
        }
        return ece
    }

    struct CalibrationDecisionV1: Equatable {
        let observed: Double
        let nullMean: Double
        let nullQ95: Double
        let debiasedGap: Double
        let testGatePassed: Bool          // observed <= Q95(null)
        let effectGatePassed: Bool        // debiasedGap <= effectBound
        var passed: Bool { testGatePassed && effectGatePassed }
    }

    /// The v2 PRIMARY decision: null-referenced equal-mass ECE (seeded, deterministic).
    static func decide(preds: [Double], labels: [Bool], seed: UInt64,
                       sims: Int = nullSims) -> CalibrationDecisionV1 {
        let observed = eceEqualMass(preds: preds, labels: labels)
        var rng = RWCSplitMix64(seed: seed)
        var null = [Double]()
        null.reserveCapacity(sims)
        for _ in 0..<sims {
            let simLabels = preds.map { rng.double01() < $0 }
            null.append(eceEqualMass(preds: preds, labels: simLabels))
        }
        null.sort()
        let q95 = null[max(0, Int(0.95 * Double(sims)) - 1)]
        let mean = null.reduce(0, +) / Double(sims)
        let gap = max(0, observed - mean)
        return CalibrationDecisionV1(observed: observed, nullMean: mean, nullQ95: q95,
                                     debiasedGap: gap,
                                     testGatePassed: observed <= q95,
                                     effectGatePassed: gap <= effectBound)
    }

    // ── predeclared generators (power analysis; NEVER tuned to any single seed — multi-seed law) ──
    static func confidences(_ kind: String, n: Int, rng: inout RWCSplitMix64) -> [Double] {
        switch kind {
        case "skewed": return (0..<n).map { _ in pow(rng.double01(), 2) }
        case "clustered": return (0..<n).map { _ in rng.double01() < 0.5 ? 0.1 + 0.02 * rng.double01()
                                                                          : 0.85 + 0.1 * rng.double01() }
        default: return (0..<n).map { _ in rng.double01() }          // uniform
        }
    }
    static func labels(for preds: [Double], alternative: String, delta: Double = 0.07,
                       rng: inout RWCSplitMix64) -> [Bool] {
        preds.map { p in
            let q: Double
            switch alternative {
            case "over": q = min(1, max(0, p - delta))               // model overconfident by delta
            case "under": q = min(1, max(0, p + delta))
            case "tail": q = p > 0.8 ? min(1, max(0, p - 2 * delta)) : p
            default: q = p                                           // null: perfectly calibrated
            }
            return rng.double01() < q
        }
    }

    // ── IRR decision law (A14-F10) ──
    enum IRRDecisionV1: Equatable { case pass, fail, insufficientData }
    struct IRRResultV1: Equatable {
        let point: Double?
        let ciLower: Double?
        let ciUpper: Double?
        let validReplicateFraction: Double
        let decision: IRRDecisionV1
    }
    static let irrBootstrapB = 2000
    static let irrSeed: UInt64 = 20261020
    static let irrMinValidPairs = 50
    static let irrMinValidReplicateFraction = 0.80

    /// PASS iff lower 95% CI bound ≥ threshold. Degenerate replicates excluded; low valid fraction or
    /// degenerate point → INSUFFICIENT_DATA. Deterministic (seeded percentile bootstrap over items).
    static func irrKappaDecision(a: [Int], b: [Int], categories: Int, threshold: Double,
                                 bootstrapB: Int = irrBootstrapB, seed: UInt64 = irrSeed) -> IRRResultV1 {
        guard a.count == b.count, a.count >= irrMinValidPairs,
              let point = RWCStatisticsV1.quadraticWeightedKappa(a: a, b: b, categories: categories) else {
            return IRRResultV1(point: nil, ciLower: nil, ciUpper: nil, validReplicateFraction: 0,
                               decision: .insufficientData)
        }
        var rng = RWCSplitMix64(seed: seed)
        var replicates = [Double]()
        replicates.reserveCapacity(bootstrapB)
        for _ in 0..<bootstrapB {
            var ra = [Int](), rb = [Int]()
            for _ in a.indices { let i = Int(rng.next() % UInt64(a.count)); ra.append(a[i]); rb.append(b[i]) }
            if let k = RWCStatisticsV1.quadraticWeightedKappa(a: ra, b: rb, categories: categories) {
                replicates.append(k)                                 // nil (degenerate) replicates EXCLUDED
            }
        }
        let validFraction = Double(replicates.count) / Double(bootstrapB)
        guard validFraction >= irrMinValidReplicateFraction else {
            return IRRResultV1(point: point, ciLower: nil, ciUpper: nil,
                               validReplicateFraction: validFraction, decision: .insufficientData)
        }
        replicates.sort()
        let lo = replicates[max(0, Int(0.025 * Double(replicates.count)))]
        let hi = replicates[min(replicates.count - 1, Int(0.975 * Double(replicates.count)))]
        return IRRResultV1(point: point, ciLower: lo, ciUpper: hi, validReplicateFraction: validFraction,
                           decision: lo >= threshold ? .pass : .fail)
    }

    // ── coverage accountability (A14-F9) — exact denominators ──
    struct CoverageV1: Equatable {
        let decisionCoverage: Double          // decided in-distribution / total in-distribution
        let abstentionRate: Double            // abstained in-distribution / total in-distribution
        let oodAbstentionRate: Double         // abstained OOD / total OOD (EXPECTED high — separate)
        let sentinelProtectiveRate: Double    // protective outcome (decision OR abstention) / sentinels
        let sentinelExplicitDecisionRate: Double
        let sentinelAbstentionRate: Double
    }
    static func coverage(inDistDecided: Int, inDistTotal: Int, oodAbstained: Int, oodTotal: Int,
                         sentinelProtective: Int, sentinelDecided: Int, sentinelTotal: Int) -> CoverageV1 {
        func r(_ a: Int, _ b: Int) -> Double { b > 0 ? Double(a) / Double(b) : 0 }
        return CoverageV1(decisionCoverage: r(inDistDecided, inDistTotal),
                          abstentionRate: r(inDistTotal - inDistDecided, inDistTotal),
                          oodAbstentionRate: r(oodAbstained, oodTotal),
                          sentinelProtectiveRate: r(sentinelProtective, sentinelTotal),
                          sentinelExplicitDecisionRate: r(sentinelDecided, sentinelTotal),
                          sentinelAbstentionRate: r(sentinelTotal - sentinelDecided, sentinelTotal))
    }
    /// Frozen pre-data coverage gate (product semantics, documented in the power prereg):
    /// overall in-distribution decision coverage must be ≥ 0.80 for any calibration PASS to count.
    static let frozenMinDecisionCoverage = 0.80
}

// MARK: - §24 — CORPUS ENTRY GUARD contract (deterministic; synthetic-state testable; downloads nothing).
enum RWCCorpusEntryGuardV1 {
    static let version = "rwc-corpus-entry-guard-v1"
    struct StateV1 {
        let pre14Verdict: String                  // must be exactly "PASS"
        let currentFrozenHashes: [String: String] // path -> sha256 (live recomputation)
        let auditedFrozenHashes: [String: String] // from the audited freeze manifest
        let freezeVersion: String
        let auditedFreezeVersion: String
        let dataVisibility: Int                   // must be 0 -> transitioning to 1
        let postAuditMethodologyDrift: Bool
    }
    enum EntryErrorV1: Error, Equatable {
        case pre14NotPassed(String)
        case frozenHashDrift(path: String)
        case freezeVersionMismatch
        case dataAlreadyVisible
        case methodologyDrift
    }
    /// Corpus acquisition may begin ONLY when every clause holds (A14-F13 window law, machine form).
    static func requireEntry(_ s: StateV1) throws {
        guard s.pre14Verdict == "PASS" else { throw EntryErrorV1.pre14NotPassed(s.pre14Verdict) }
        guard s.freezeVersion == s.auditedFreezeVersion else { throw EntryErrorV1.freezeVersionMismatch }
        for (path, audited) in s.auditedFrozenHashes {
            guard s.currentFrozenHashes[path] == audited else { throw EntryErrorV1.frozenHashDrift(path: path) }
        }
        guard s.dataVisibility == 0 else { throw EntryErrorV1.dataAlreadyVisible }
        guard !s.postAuditMethodologyDrift else { throw EntryErrorV1.methodologyDrift }
    }
}
