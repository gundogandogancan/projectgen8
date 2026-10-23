import XCTest
import Foundation
import CryptoKit

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT16 — INDEPENDENT STATISTICAL REPLICATION RUNNER (env-gated; auditor-owned, add-only).
//
// FULLY INDEPENDENT implementation of the frozen v3 statistical laws, written from the normative
// TEXT (RWC_FROZEN_GATES_V3.yaml / RWC_CALIBRATION_POWER_PREREG_V3.yaml / RWC_IRR_PLANNING_V3.md),
// NOT from the builder code. This file imports NOTHING from GuardianCore and calls NO builder
// decide()/eceTieInvariant() — every law below is reimplemented (sandbox denies standalone swiftc,
// so the sanctioned `swift test` runner hosts the tool; it is skipped in normal suite runs).
//
// Run:  GEN8_AUDIT16_STAT=1 swift test -c release -Xswiftc -enable-testing \
//         --filter AUDIT16_StatReplicationRunner
// Output: docs/audit/audit16_tools/results/AUDIT16_STAT_REPLICATION.json
//
// Studies:
//   1. TYPE-I   : combined-rule false-reject under exact H0 (6 shapes, n=800, S=999, 500 trials).
//   2. POWER    : over07/under07 at n∈{400,800} (6 shapes; 300/400 trials) + tail07/osc05/
//                 localized07 at n=800 (300 trials). Wilson 95% CIs.
//   3. STABILITY: S=999 mixed-verdict fraction (null + boundary over05; 2 shapes × 60 datasets ×
//                 20 auditor eval seeds).
//   4. BOUNDARY : integer exactness of the MC law at exceed ∈ {48,49,50,51}, S=999.
//   5. IRR      : kappa CI-lower gate (percentile bootstrap B=2000, degenerate excluded, valid
//                 fraction >= .80) pass rates at n∈{200,300,400} × four agreement mixtures,
//                 thresholds 0.60 AND 0.61, 150 trials/cell. Wilson 95% CIs.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT16_StatReplicationRunner: XCTestCase {

    // MARK: independent RNG + auditor seed law

    private struct Mix {
        var state: UInt64
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

    private func seed(_ parts: [String]) -> UInt64 {
        let ctx = (["AUDIT16-REPLICATION"] + parts).joined(separator: "|")
        let d = SHA256.hash(data: Data(ctx.utf8))
        var v: UInt64 = 0
        for (i, b) in d.enumerated() where i < 8 { v = (v << 8) | UInt64(b) }
        return v
    }

    // MARK: independent tie-group ECE (frozen law text)

    private func ece(_ preds: [Double], _ labels: [Bool], bins: Int) -> Double {
        let n = preds.count
        var counts: [Double: Int] = [:], pos: [Double: Int] = [:]
        for (p, y) in zip(preds, labels) {
            counts[p, default: 0] += 1
            if y { pos[p, default: 0] += 1 }
        }
        var sumP = [Double](repeating: 0, count: bins)
        var sumY = [Double](repeating: 0, count: bins)
        var cnt = [Int](repeating: 0, count: bins)
        var cStart = 0
        for v in counts.keys.sorted() {
            let c = counts[v]!
            let b = (cStart * bins) / n
            sumP[b] += v * Double(c)
            sumY[b] += Double(pos[v] ?? 0)
            cnt[b] += c
            cStart += c
        }
        var e = 0.0
        for b in 0..<bins where cnt[b] > 0 {
            let c = Double(cnt[b])
            e += c / Double(n) * abs(sumP[b] / c - sumY[b] / c)
        }
        return e
    }

    // MARK: independent exact MC decision (p_MC=(1+exceed)/(S+1); FAIL iff 20(1+exceed)<=S+1;
    //       secondary max(0, obs-nullMean) <= 0.05; PASS = both)

    private struct Decision { let pMC: Double; let excess: Double; let passed: Bool }

    private func decide(_ preds: [Double], _ labels: [Bool], bins: Int, s: Int,
                        evalSeed: UInt64) -> Decision {
        let obs = ece(preds, labels, bins: bins)
        var counts: [Double: Int] = [:]
        for p in preds { counts[p, default: 0] += 1 }
        let values = counts.keys.sorted()
        let n = preds.count
        var groupBins: [Int] = []
        var cStart = 0
        for v in values { groupBins.append((cStart * bins) / n); cStart += counts[v]! }
        var rng = Mix(seed: evalSeed)
        var exceed = 0
        var nullSum = 0.0
        for _ in 0..<s {
            var sumP = [Double](repeating: 0, count: bins)
            var sumY = [Double](repeating: 0, count: bins)
            var cnt = [Int](repeating: 0, count: bins)
            for (g, v) in values.enumerated() {
                let c = counts[v]!
                var p = 0
                for _ in 0..<c where rng.double01() < v { p += 1 }
                let b = groupBins[g]
                sumP[b] += v * Double(c)
                sumY[b] += Double(p)
                cnt[b] += c
            }
            var e = 0.0
            for b in 0..<bins where cnt[b] > 0 {
                let c = Double(cnt[b])
                e += c / Double(n) * abs(sumP[b] / c - sumY[b] / c)
            }
            nullSum += e
            if e >= obs { exceed += 1 }
        }
        let pMC = Double(1 + exceed) / Double(s + 1)
        let excess = max(0, obs - nullSum / Double(s))
        let fail = 20 * (1 + exceed) <= (s + 1)
        return Decision(pMC: pMC, excess: excess, passed: !fail && excess <= 0.05)
    }

    // MARK: predeclared generators (from the frozen prereg design text)

    private func conf(_ shape: String, _ rng: inout Mix) -> Double {
        switch shape {
        case "skewed": let u = rng.double01(); return u * u
        case "clustered": return rng.double01() < 0.5 ? 0.1 + 0.02 * rng.double01()
                                                      : 0.85 + 0.1 * rng.double01()
        case "quantized": return Double(min(20, max(0, Int(rng.double01() * 21.0)))) / 20.0
        case "highconf": let u = rng.double01(); return 1.0 - u * u
        case "lowconf": let u = rng.double01(); return u * u * u
        default: return rng.double01()
        }
    }

    private func clamp01(_ x: Double) -> Double { min(1.0, max(0.0, x)) }

    private func trueProb(_ alt: String, _ p: Double) -> Double {
        switch alt {
        case "over03": return clamp01(p - 0.03)
        case "over05": return clamp01(p - 0.05)
        case "over07": return clamp01(p - 0.07)
        case "over10": return clamp01(p - 0.10)
        case "under07": return clamp01(p + 0.07)
        case "tail07": return p > 0.8 ? clamp01(p - 0.14) : p
        case "osc05": return clamp01(p + (Int((p * 10.0).rounded(.down)) % 2 == 0 ? 0.05 : -0.05))
        case "localized07": return (p >= 0.4 && p < 0.6) ? clamp01(p + 0.21) : p
        default: return p
        }
    }

    private func dataset(shape: String, alt: String, n: Int, seed s: UInt64) -> ([Double], [Bool]) {
        var rng = Mix(seed: s)
        var preds = [Double](); preds.reserveCapacity(n)
        var labels = [Bool](); labels.reserveCapacity(n)
        for _ in 0..<n {
            let p = conf(shape, &rng)
            preds.append(p)
            labels.append(rng.double01() < trueProb(alt, p))
        }
        return (preds, labels)
    }

    private func wilson(_ k: Int, _ n: Int) -> (Double, Double) {
        guard n > 0 else { return (0, 1) }
        let z = 1.959963984540054, p = Double(k) / Double(n), nn = Double(n)
        let denom = 1 + z * z / nn
        let center = (p + z * z / (2 * nn)) / denom
        let half = z * ((p * (1 - p) / nn + z * z / (4 * nn * nn)).squareRoot()) / denom
        return (max(0, center - half), min(1, center + half))
    }

    private func f6(_ x: Double) -> String { String(format: "%.6f", x) }

    // MARK: independent quadratic-weighted kappa + bootstrap gate

    private func qwKappa(_ a: [Int], _ b: [Int], k: Int) -> Double? {
        let n = a.count
        guard n > 0 else { return nil }
        var obs = [Double](repeating: 0, count: k * k)
        var ra = [Double](repeating: 0, count: k), rb = [Double](repeating: 0, count: k)
        for i in 0..<n {
            obs[a[i] * k + b[i]] += 1
            ra[a[i]] += 1; rb[b[i]] += 1
        }
        var num = 0.0, den = 0.0
        let kk = Double((k - 1) * (k - 1))
        for i in 0..<k {
            for j in 0..<k {
                let w = Double((i - j) * (i - j)) / kk
                num += w * obs[i * k + j] / Double(n)
                den += w * ra[i] * rb[j] / Double(n * n)
            }
        }
        guard den > 0 else { return nil }
        return 1.0 - num / den
    }

    private func irrGatePasses(a: [Int], b: [Int], k: Int, threshold: Double,
                               rng: inout Mix) -> Bool {
        let n = a.count
        guard qwKappa(a, b, k: k) != nil, n >= 50 else { return false }
        let B = 2000
        var reps: [Double] = []
        reps.reserveCapacity(B)
        var ra = [Int](repeating: 0, count: n), rb = [Int](repeating: 0, count: n)
        for _ in 0..<B {
            for i in 0..<n {
                let j = Int(rng.next() % UInt64(n))
                ra[i] = a[j]; rb[i] = b[j]
            }
            if let kap = qwKappa(ra, rb, k: k) { reps.append(kap) }
        }
        guard Double(reps.count) / Double(B) >= 0.80 else { return false }
        let sorted = reps.sorted()
        let lo = sorted[Int((0.025 * Double(sorted.count - 1)).rounded())]
        return lo >= threshold
    }

    /// Mixture-rater model: B = A with probability `agree`, else an independent uniform redraw.
    /// For uniform marginals the quadratic-weighted kappa of this model ≈ `agree` (the redraw hits
    /// the chance-expected quadratic distance), so cells land near the intended true-kappa targets;
    /// the measured mean kappa is reported per cell.
    private func raterPair(n: Int, agree: Double, rng: inout Mix) -> ([Int], [Int]) {
        var a = [Int](), b = [Int]()
        for _ in 0..<n {
            let x = Int(rng.next() % 5)
            a.append(x)
            b.append(rng.double01() < agree ? x : Int(rng.next() % 5))
        }
        return (a, b)
    }

    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<6 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("docs/calibration").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    // MARK: the runner

    func testAUDIT16_StatReplication() throws {
        // Flag-file alternative gate added by the second AUDIT16 session (whose sandbox denies
        // env-prefixed commands) to re-run the replication and byte-verify the persisted JSON.
        guard ProcessInfo.processInfo.environment["GEN8_AUDIT16_STAT"] == "1"
                || FileManager.default.fileExists(atPath: "/tmp/gen8_audit16_stat.flag") else {
            throw XCTSkip("env-gated auditor replication runner (GEN8_AUDIT16_STAT=1)")
        }
        let shapes = ["uniform", "skewed", "clustered", "quantized", "highconf", "lowconf"]
        var out = "{\n  \"tool\": \"audit16-stat-replication-v1\",\n  \"independent\": true,\n"

        // 4. boundary integer law at S=999
        var boundary: [String] = []
        for exceed in [48, 49, 50, 51] {
            let fails = 20 * (1 + exceed) <= 1000
            boundary.append("    \"exceed_\(exceed)\": {\"p_mc\": \(f6(Double(1 + exceed) / 1000.0)), \"fails\": \(fails)}")
        }
        out += "  \"boundary_law_S999\": {\n" + boundary.joined(separator: ",\n") + "\n  },\n"

        // 1. Type-I under exact H0
        var typeI: [String] = []
        for shape in shapes {
            let trials = 500
            var rejects = 0, testOnly = 0
            for t in 0..<trials {
                let (p, y) = dataset(shape: shape, alt: "null", n: 800,
                                     seed: seed(["typeI", shape, String(t), "data"]))
                let d = decide(p, y, bins: 10, s: 999,
                               evalSeed: seed(["typeI", shape, String(t), "eval"]))
                if !d.passed { rejects += 1 }
                if 20 * Int((d.pMC * 1000).rounded()) <= 1000 { testOnly += 1 }
            }
            let (lo, hi) = wilson(rejects, trials)
            let (tlo, thi) = wilson(testOnly, trials)
            typeI.append("    \"\(shape)\": {\"combined_rejects\": \(rejects), \"trials\": \(trials), \"rate\": \(f6(Double(rejects) / Double(trials))), \"wilson95\": [\(f6(lo)), \(f6(hi))], \"mc_test_only_rejects\": \(testOnly), \"mc_test_only_wilson95\": [\(f6(tlo)), \(f6(thi))]}")
            print("AUDIT16 typeI \(shape): combined=\(rejects)/\(trials) testOnly=\(testOnly)")
        }
        out += "  \"type_I_null_n800_S999\": {\n" + typeI.joined(separator: ",\n") + "\n  },\n"

        // 2. power replication
        var power: [String] = []
        let cells: [(String, Int, Int)] = [("over07", 800, 400), ("under07", 800, 400),
                                           ("over07", 400, 300), ("under07", 400, 300),
                                           ("tail07", 800, 300), ("osc05", 800, 300),
                                           ("localized07", 800, 300)]
        for (alt, n, trials) in cells {
            for shape in shapes {
                var rejects = 0
                for t in 0..<trials {
                    let (p, y) = dataset(shape: shape, alt: alt, n: n,
                                         seed: seed(["power", shape, alt, String(n), String(t), "data"]))
                    let d = decide(p, y, bins: 10, s: 999,
                                   evalSeed: seed(["power", shape, alt, String(n), String(t), "eval"]))
                    if !d.passed { rejects += 1 }
                }
                let (lo, hi) = wilson(rejects, trials)
                power.append("    \"\(shape)|\(alt)|n\(n)\": {\"rejects\": \(rejects), \"trials\": \(trials), \"rate\": \(f6(Double(rejects) / Double(trials))), \"wilson95\": [\(f6(lo)), \(f6(hi))]}")
            }
            print("AUDIT16 power \(alt) n\(n) done")
        }
        out += "  \"power_replication\": {\n" + power.joined(separator: ",\n") + "\n  },\n"

        // 3. stability at S=999 (auditor seeds)
        var stability: [String] = []
        for suite in ["null", "boundary_over05"] {
            let alt = suite == "null" ? "null" : "over05"
            var mixed = 0, total = 0
            for shape in ["uniform", "clustered"] {
                for d in 0..<60 {
                    let (p, y) = dataset(shape: shape, alt: alt, n: 800,
                                         seed: seed(["stab", suite, shape, String(d), "data"]))
                    var verdicts = Set<Bool>()
                    for e in 0..<20 {
                        let dec = decide(p, y, bins: 10, s: 999,
                                         evalSeed: seed(["stab", suite, shape, String(d), "eval", String(e)]))
                        verdicts.insert(dec.passed)
                    }
                    total += 1
                    if verdicts.count > 1 { mixed += 1 }
                }
            }
            let (lo, hi) = wilson(mixed, total)
            stability.append("    \"\(suite)|S999\": {\"mixed\": \(mixed), \"datasets\": \(total), \"fraction\": \(f6(Double(mixed) / Double(total))), \"wilson95\": [\(f6(lo)), \(f6(hi))]}")
            print("AUDIT16 stability \(suite): mixed=\(mixed)/\(total)")
        }
        out += "  \"stability_S999\": {\n" + stability.joined(separator: ",\n") + "\n  },\n"

        // 5. IRR planning replication
        var irr: [String] = []
        for n in [200, 300, 400] {
            for agree in [0.65, 0.70, 0.75, 0.80] {
                let trials = 150
                var pass60 = 0, pass61 = 0
                var kappaSum = 0.0, kappaN = 0
                for t in 0..<trials {
                    var rng = Mix(seed: seed(["irr", String(n), f6(agree), String(t)]))
                    let (a, b) = raterPair(n: n, agree: agree, rng: &rng)
                    if let kap = qwKappa(a, b, k: 5) { kappaSum += kap; kappaN += 1 }
                    var brng = Mix(seed: seed(["irr-boot", String(n), f6(agree), String(t)]))
                    if irrGatePasses(a: a, b: b, k: 5, threshold: 0.60, rng: &brng) { pass60 += 1 }
                    var brng2 = Mix(seed: seed(["irr-boot", String(n), f6(agree), String(t)]))
                    if irrGatePasses(a: a, b: b, k: 5, threshold: 0.61, rng: &brng2) { pass61 += 1 }
                }
                let (lo60, hi60) = wilson(pass60, trials)
                let (lo61, hi61) = wilson(pass61, trials)
                irr.append("    \"n\(n)|agree\(f6(agree))\": {\"mean_kappa\": \(f6(kappaSum / Double(max(1, kappaN)))), \"trials\": \(trials), \"pass_rate_thr060\": \(f6(Double(pass60) / Double(trials))), \"wilson95_thr060\": [\(f6(lo60)), \(f6(hi60))], \"pass_rate_thr061\": \(f6(Double(pass61) / Double(trials))), \"wilson95_thr061\": [\(f6(lo61)), \(f6(hi61))]}")
            }
            print("AUDIT16 irr n\(n) done")
        }
        out += "  \"irr_planning\": {\n" + irr.joined(separator: ",\n") + "\n  }\n}\n"

        let dir = repoRoot().appendingPathComponent("docs/audit/audit16_tools/results")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("AUDIT16_STAT_REPLICATION.json")
        try out.data(using: .utf8)!.write(to: url)
        print("AUDIT16_STAT_WRITTEN=\(url.path)")
    }

    /// §25 COMPLETION (second session): independent power replication at n=1600 (over07/under07,
    /// all six shapes, 150 trials/cell) — the remaining mandate-listed n. Non-law-deciding (the
    /// frozen law selects the SMALLEST clearing n, and n=800 already clears), so it is persisted
    /// to a SEPARATE file to keep AUDIT16_STAT_REPLICATION.json byte-comparable across sessions.
    func testAUDIT16_PowerN1600Replication() throws {
        guard ProcessInfo.processInfo.environment["GEN8_AUDIT16_N1600"] == "1"
                || FileManager.default.fileExists(atPath: "/tmp/gen8_audit16_n1600.flag") else {
            throw XCTSkip("gated auditor n1600 replication runner")
        }
        let shapes = ["uniform", "skewed", "clustered", "quantized", "highconf", "lowconf"]
        var out = "{\n  \"tool\": \"audit16-stat-n1600-v1\",\n  \"independent\": true,\n  \"cells\": {\n"
        var lines: [String] = []
        for alt in ["over07", "under07"] {
            for shape in shapes {
                let trials = 150
                var rejects = 0
                for t in 0..<trials {
                    let (p, y) = dataset(shape: shape, alt: alt, n: 1600,
                                         seed: seed(["power", shape, alt, "1600", String(t), "data"]))
                    let d = decide(p, y, bins: 10, s: 999,
                                   evalSeed: seed(["power", shape, alt, "1600", String(t), "eval"]))
                    if !d.passed { rejects += 1 }
                }
                let (lo, hi) = wilson(rejects, trials)
                lines.append("    \"\(shape)|\(alt)|n1600\": {\"rejects\": \(rejects), \"trials\": \(trials), \"rate\": \(f6(Double(rejects) / Double(trials))), \"wilson95\": [\(f6(lo)), \(f6(hi))]}")
                print("AUDIT16 n1600 \(shape)|\(alt): \(rejects)/\(trials)")
            }
        }
        out += lines.joined(separator: ",\n") + "\n  }\n}\n"
        let dir = repoRoot().appendingPathComponent("docs/audit/audit16_tools/results")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try out.data(using: .utf8)!.write(to: dir.appendingPathComponent("AUDIT16_STAT_N1600.json"))
        print("AUDIT16_N1600_WRITTEN")
    }

    /// PRECISION FOLLOW-UP (predeclared protocol, run once, reported regardless of outcome):
    /// the first replication measured pooled test-only Type-I 185/3000 = 6.17% (> nominal 5%,
    /// ~2.9σ). Under exchangeability the MC gate is exactly 5% conditional on predictions, so this
    /// study measures with higher precision and a FRESH seed namespace:
    ///   (a) uniform shape, n=800, S=999, 3000 trials — shape-level verification;
    ///   (b) implementation oracle: n=50 all-distinct uniform preds, S=999, 5000 trials — theory
    ///       is unambiguous (exact 5% minus tie conservatism), so deviation here = code defect.
    func testAUDIT16_TypeIPrecision() throws {
        // Flag-file alternative gate (see testAUDIT16_StatReplication).
        guard ProcessInfo.processInfo.environment["GEN8_AUDIT16_TYPEI2"] == "1"
                || FileManager.default.fileExists(atPath: "/tmp/gen8_audit16_typei2.flag") else {
            throw XCTSkip("env-gated auditor precision runner (GEN8_AUDIT16_TYPEI2=1)")
        }
        var out = "{\n  \"tool\": \"audit16-typeI-precision-v1\",\n"
        // (a) uniform n=800
        var rejects = 0
        let trialsA = 3000
        for t in 0..<trialsA {
            let (p, y) = dataset(shape: "uniform", alt: "null", n: 800,
                                 seed: seed(["typeI2", "uniform", String(t), "data"]))
            let d = decide(p, y, bins: 10, s: 999,
                           evalSeed: seed(["typeI2", "uniform", String(t), "eval"]))
            if 20 * Int((d.pMC * 1000).rounded()) <= 1000 { rejects += 1 }
        }
        let (loA, hiA) = wilson(rejects, trialsA)
        out += "  \"uniform_n800_S999\": {\"mc_test_rejects\": \(rejects), \"trials\": \(trialsA), \"rate\": \(f6(Double(rejects) / Double(trialsA))), \"wilson95\": [\(f6(loA)), \(f6(hiA))]},\n"
        print("AUDIT16 typeI2 uniform n800: \(rejects)/\(trialsA)")
        // (b) oracle: n=50, S=999
        var rejectsB = 0
        let trialsB = 5000
        for t in 0..<trialsB {
            var rng = Mix(seed: seed(["typeI2", "oracle", String(t), "data"]))
            var preds = [Double](), labels = [Bool]()
            for _ in 0..<50 {
                let p = rng.double01()
                preds.append(p)
                labels.append(rng.double01() < p)
            }
            let d = decide(preds, labels, bins: 10, s: 999,
                           evalSeed: seed(["typeI2", "oracle", String(t), "eval"]))
            if 20 * Int((d.pMC * 1000).rounded()) <= 1000 { rejectsB += 1 }
        }
        let (loB, hiB) = wilson(rejectsB, trialsB)
        out += "  \"oracle_n50_S999\": {\"mc_test_rejects\": \(rejectsB), \"trials\": \(trialsB), \"rate\": \(f6(Double(rejectsB) / Double(trialsB))), \"wilson95\": [\(f6(loB)), \(f6(hiB))]}\n}\n"
        print("AUDIT16 typeI2 oracle n50: \(rejectsB)/\(trialsB)")
        let dir = repoRoot().appendingPathComponent("docs/audit/audit16_tools/results")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("AUDIT16_TYPEI_PRECISION.json")
        try out.data(using: .utf8)!.write(to: url)
        print("AUDIT16_TYPEI2_WRITTEN=\(url.path)")
    }
}
