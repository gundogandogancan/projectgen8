import Foundation

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC-PRE-08/09 — deterministic statistical methodology tooling (test/calibration-methodology code;
// zero app-runtime coupling; NO fitted model, NO real labels, NO real corpus — fixtures only).
// Every method states its assumptions. Formulas are frozen pre-data (PRE-11 invalidation law applies).
// ═══════════════════════════════════════════════════════════════════════════════════════════════

enum RWCStatisticsV1 {
    static let version = "rwc-statistics-v1"

    /// Quadratic-weighted Cohen's kappa for two raters on an ordinal scale 0..(k-1).
    /// ASSUMPTIONS: paired complete labels (abstain pairs excluded upstream); weights
    /// w_ij = 1 - (i-j)^2/(k-1)^2. Returns nil (INSUFFICIENT_DATA) on degenerate input:
    /// <1 pair, single-rater-constant marginal making expected weight undefined (denominator 0).
    static func quadraticWeightedKappa(a: [Int], b: [Int], categories k: Int) -> Double? {
        guard a.count == b.count, !a.isEmpty, k >= 2,
              a.allSatisfy({ (0..<k).contains($0) }), b.allSatisfy({ (0..<k).contains($0) }) else { return nil }
        let n = Double(a.count)
        var observed = Array(repeating: Array(repeating: 0.0, count: k), count: k)
        for (x, y) in zip(a, b) { observed[x][y] += 1 }
        var rowM = Array(repeating: 0.0, count: k), colM = Array(repeating: 0.0, count: k)
        for i in 0..<k { for j in 0..<k { rowM[i] += observed[i][j]; colM[j] += observed[i][j] } }
        func w(_ i: Int, _ j: Int) -> Double { 1.0 - pow(Double(i - j), 2) / pow(Double(k - 1), 2) }
        var po = 0.0, pe = 0.0
        for i in 0..<k { for j in 0..<k {
            po += w(i, j) * observed[i][j] / n
            pe += w(i, j) * (rowM[i] / n) * (colM[j] / n)
        } }
        let denom = 1.0 - pe
        guard abs(denom) > 1e-12 else { return nil }          // degenerate marginals → INSUFFICIENT_DATA
        return (po - pe) / denom
    }

    /// Krippendorff's alpha, nominal data, two coders, no missing values (missing handled upstream
    /// by exclusion + separate abstention-rate reporting per PRE-08).
    /// ASSUMPTIONS: binary/nominal categories; coincidence-matrix formulation.
    /// Returns nil on degenerate data (single category overall → De == 0).
    static func krippendorffAlphaNominal(a: [Int], b: [Int]) -> Double? {
        guard a.count == b.count, !a.isEmpty else { return nil }
        // coincidence counts over pairable values (each item contributes the ordered pairs (a,b),(b,a))
        var counts: [Int: Double] = [:]
        var coincidence: [Int: [Int: Double]] = [:]
        for (x, y) in zip(a, b) {
            counts[x, default: 0] += 1; counts[y, default: 0] += 1
            coincidence[x, default: [:]][y, default: 0] += 1
            coincidence[y, default: [:]][x, default: 0] += 1
        }
        let nTotal = Double(2 * a.count)
        guard counts.count >= 2 else { return nil }           // single category → undefined (typed upstream)
        var doDisagree = 0.0
        for (x, row) in coincidence { for (y, c) in row where x != y { doDisagree += c } }
        doDisagree /= nTotal
        var deDisagree = 0.0
        for (x, nx) in counts { for (y, ny) in counts where x != y { deDisagree += nx * ny } }
        deDisagree /= (nTotal * (nTotal - 1))
        guard deDisagree > 1e-12 else { return nil }
        return 1.0 - doDisagree / deDisagree
    }

    /// Wilson score interval for a binomial proportion. ASSUMPTION: iid Bernoulli trials.
    static func wilson(successes: Int, n: Int, z: Double = 1.959963984540054) -> (lo: Double, hi: Double)? {
        guard n > 0, successes >= 0, successes <= n else { return nil }
        let p = Double(successes) / Double(n), nn = Double(n), z2 = z * z
        let center = (p + z2 / (2 * nn)) / (1 + z2 / nn)
        let half = (z / (1 + z2 / nn)) * ( (p * (1 - p) / nn + z2 / (4 * nn * nn)).squareRoot() )
        return (max(0, center - half), min(1, center + half))
    }

    /// Rule of three: 95% upper bound for an event rate after ZERO observed events in n trials.
    /// ASSUMPTION: iid trials; exact bound 1-(1-p)^n = .95 → p ≈ 3/n (classic approximation; we return
    /// the exact solution). LAW: zero-observed NEVER claims zero-rate — always report this bound.
    static func zeroEventUpperBound95(n: Int) -> Double? {
        guard n > 0 else { return nil }
        return 1.0 - pow(0.05, 1.0 / Double(n))
    }

    /// Planning sample size for estimating a proportion within half-width h at confidence z.
    /// ASSUMPTION: normal approximation (planning only — final inference uses Wilson/bootstrap).
    static func planningSampleSize(p: Double, halfWidth h: Double, z: Double = 1.959963984540054) -> Int? {
        guard p > 0, p < 1, h > 0 else { return nil }
        return Int((z * z * p * (1 - p) / (h * h)).rounded(.up))
    }

    /// Deterministic seeded bootstrap SPECIFICATION helper (xorshift64*): reproducible index resampling
    /// for CI computation at evaluation time. No data exists yet — exercised on fixtures only.
    static func bootstrapIndices(n: Int, draws: Int, seed: UInt64) -> [[Int]] {
        var state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
        func next() -> UInt64 {
            state ^= state >> 12; state ^= state << 25; state ^= state >> 27
            return state &* 2685821657736338717
        }
        guard n > 0, draws > 0 else { return [] }
        return (0..<draws).map { _ in (0..<n).map { _ in Int(next() % UInt64(n)) } }
    }
}
