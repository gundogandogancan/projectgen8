import XCTest
import Foundation
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC POWER DERIVATION V3 (A15-F7 closure) — the CANONICAL pre-data derivation engine.
//
// WHY SWIFT (recorded design decision): the host has no numpy; a pure-Python engine at the frozen
// simulation budget is computationally infeasible, and AUDIT15 proved the R1 Python engine's
// hash()-based seeding non-reproducible. The canonical engine therefore lives HERE, uses ONLY the
// frozen SHA-256 seed law + SplitMix64 (cross-language stable), and a small pure-Python
// differential tool (tools/rwc_methodology_v3_differential.py) must reproduce selected cells and
// fixture vectors BYTE-IDENTICALLY under any PYTHONHASHSEED — proving the law, not the language.
//
// DETERMINISM LAW: output JSON is a pure function of the frozen design (no wall clock, no process
// state, no hash randomization). Running the derivation twice MUST produce byte-identical files.
//
// RUNNERS (env-gated; excluded from normal suite runs):
//   GEN8_RWC_DERIVE_V3=stability  → RWC_CALIBRATION_MC_STABILITY_V3.json   (choose frozen S)
//   GEN8_RWC_DERIVE_V3=power      → RWC_CALIBRATION_POWER_RESULTS_V3.json  (choose frozen n law)
// Both write into docs/calibration/preregistration/tools/ at the repo root.
//
// PREDECLARED DESIGN (frozen BEFORE any run; see RWC_CALIBRATION_POWER_PREREG_V3.yaml):
//   shapes        : uniform, skewed, clustered, quantized, highconf, lowconf
//   alternatives  : null; over@{.03,.05,.07,.10}; under@.07; tail@.07; osc@.05; localized@.07
//                   (full alternative set at n=800; {null, over07, under07, tail07} at n=400/1600)
//   n grid        : 400 / 800 / 1600
//   trials        : 200 per cell (Wilson 95% CI half-width <= ~7 pp at p=.5, <= ~4 pp at p=.9)
//   S candidates  : 999 / 4999 / 9999 (0.05·(S+1) integer → exact MC test)
//   stability     : 120 null + 120 at-boundary(over@.05) datasets (uniform+clustered, n=800),
//                   20 independent evaluation seeds each; a dataset is MIXED if verdicts differ.
//   S target      : smallest candidate with null-suite mixed fraction <= 1.5%
//                   (justification: flip region is |p* − .05| ≲ 2.5·sqrt(.05·.95/S); at S=4999 that
//                   is ~1.5% of a uniform null p*-population — the residual is inherent statistical
//                   boundary uncertainty, not seed irreproducibility, and the REAL evaluation seed
//                   is itself frozen by the seed law so the production verdict is single-valued).
//   n law target  : smallest n with over@.07 AND under@.07 rejection >= 0.80 for ALL shapes.
// ZERO-DATA: all inputs synthetic; generators predeclared; seeds derived only from frozen strings.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

enum RWCPowerDerivationV3 {
    static let version = "rwc-power-derivation-v3"
    static let shapes = ["uniform", "skewed", "clustered", "quantized", "highconf", "lowconf"]
    static let fullAlts = ["null", "over03", "over05", "over07", "over10", "under07", "tail07",
                           "osc05", "localized07"]
    static let reducedAlts = ["null", "over07", "under07", "tail07"]
    static let nGrid = [400, 800, 1600]
    static let trials = 200
    static let sCandidates = [999, 4999, 9999]

    static func clamp01(_ x: Double) -> Double { min(1.0, max(0.0, x)) }

    static func confidence(_ shape: String, rng: inout RWCSplitMix64) -> Double {
        switch shape {
        case "skewed":
            let u = rng.double01(); return u * u
        case "clustered":
            return rng.double01() < 0.5 ? 0.1 + 0.02 * rng.double01() : 0.85 + 0.1 * rng.double01()
        case "quantized":
            return Double(Int(rng.double01() * 21.0).clamped(0, 20)) / 20.0
        case "highconf":
            let u = rng.double01(); return 1.0 - u * u
        case "lowconf":
            let u = rng.double01(); return u * u * u
        default:
            return rng.double01()
        }
    }

    /// True label probability q(p) per predeclared alternative. delta encoded in the alt name.
    static func trueProbability(_ alt: String, p: Double) -> Double {
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

    static func dataset(shape: String, alt: String, n: Int, seedParts: [String]) -> (preds: [Double], labels: [Bool]) {
        var rng = RWCSplitMix64(seed: RWCCalibrationMethodologyV3.seed64(seedParts))
        var preds = [Double](), labels = [Bool]()
        preds.reserveCapacity(n); labels.reserveCapacity(n)
        for _ in 0..<n {
            let p = confidence(shape, rng: &rng)
            preds.append(p)
            labels.append(rng.double01() < trueProbability(alt, p: p))
        }
        return (preds, labels)
    }

    // MARK: deterministic JSON (sorted keys, fixed %.6f formatting, LF)

    static func fmt(_ x: Double) -> String { String(format: "%.6f", x) }

    static func writeJSON(_ object: String, to relPath: String) throws -> URL {
        let url = repoRootURL().appendingPathComponent(relPath)
        try object.data(using: .utf8)!.write(to: url)
        return url
    }

    static func repoRootURL() -> URL {
        // Tests run from packages/GuardianKit; walk up to the repo root (contains docs/).
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<6 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("docs/calibration").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}

private extension Int {
    func clamped(_ lo: Int, _ hi: Int) -> Int { Swift.min(hi, Swift.max(lo, self)) }
}

// MARK: - Env-gated runners

final class RWCPowerDerivationV3Runner: XCTestCase {

    private func mode() -> String? { ProcessInfo.processInfo.environment["GEN8_RWC_DERIVE_V3"] }

    /// STABILITY STUDY: pick frozen S per predeclared target. Writes
    /// docs/calibration/preregistration/tools/RWC_CALIBRATION_MC_STABILITY_V3.json
    func testDerive_MCStabilityStudy() throws {
        guard mode() == "stability" else { throw XCTSkip("env-gated derivation runner") }
        let n = 800, seedsPerDataset = 20, datasetsPerCell = 60
        var out = "{\n  \"version\": \"\(RWCPowerDerivationV3.version)\",\n  \"study\": \"mc-decision-stability\",\n"
        out += "  \"design\": {\"n\": \(n), \"datasets_per_cell\": \(datasetsPerCell), \"eval_seeds_per_dataset\": \(seedsPerDataset), \"suites\": [\"null\", \"boundary_over05\"], \"shapes\": [\"uniform\", \"clustered\"], \"s_candidates\": [999, 4999, 9999], \"target\": \"smallest S with null-suite mixed fraction <= 0.015\"},\n"
        out += "  \"cells\": {\n"
        var cellLines: [String] = []
        for suite in ["null", "boundary_over05"] {
            let alt = suite == "null" ? "null" : "over05"
            for s in RWCPowerDerivationV3.sCandidates {
                var mixed = 0, total = 0
                for shape in ["uniform", "clustered"] {
                    for d in 0..<datasetsPerCell {
                        let data = RWCPowerDerivationV3.dataset(shape: shape, alt: alt, n: n,
                            seedParts: ["stability", suite, shape, String(d), "data"])
                        var verdicts = Set<Bool>()
                        for e in 0..<seedsPerDataset {
                            let dec = try RWCCalibrationMethodologyV3.decideV3(
                                preds: data.preds, labels: data.labels, sims: s,
                                seedParts: ["stability", suite, shape, String(d), "eval", String(e)])
                            verdicts.insert(dec.passed)
                        }
                        total += 1
                        if verdicts.count > 1 { mixed += 1 }
                    }
                }
                cellLines.append("    \"\(suite)|S\(s)\": {\"mixed\": \(mixed), \"datasets\": \(total), \"mixed_fraction\": \(RWCPowerDerivationV3.fmt(Double(mixed) / Double(total)))}")
            }
        }
        out += cellLines.joined(separator: ",\n") + "\n  }\n}\n"
        let url = try RWCPowerDerivationV3.writeJSON(out,
            to: "docs/calibration/preregistration/tools/RWC_CALIBRATION_MC_STABILITY_V3.json")
        print("STABILITY_WRITTEN=\(url.path)")
    }

    /// POWER STUDY at the frozen S. Writes
    /// docs/calibration/preregistration/tools/RWC_CALIBRATION_POWER_RESULTS_V3.json
    func testDerive_PowerStudy() throws {
        guard mode() == "power" else { throw XCTSkip("env-gated derivation runner") }
        let s = RWCCalibrationMethodologyV3.frozenNullSims
        var out = "{\n  \"version\": \"\(RWCPowerDerivationV3.version)\",\n  \"study\": \"power\",\n"
        out += "  \"design\": {\"trials\": \(RWCPowerDerivationV3.trials), \"S\": \(s), \"bins\": \(RWCCalibrationMethodologyV3.bins), \"alpha\": \(RWCPowerDerivationV3.fmt(RWCCalibrationMethodologyV3.alpha)), \"excess_limit\": \(RWCPowerDerivationV3.fmt(RWCCalibrationMethodologyV3.nullAdjustedExcessLimit)), \"decision\": \"PASS iff p_MC > alpha AND nullAdjustedExcessECE <= excess_limit\", \"seed_law\": \"SHA256(GEN8-RWC-CAL-V3|power|shape|alt|n|trial|{data,eval})[0..8) big-endian\"},\n"
        out += "  \"cells\": {\n"
        var cellLines: [String] = []
        for shape in RWCPowerDerivationV3.shapes {
            for n in RWCPowerDerivationV3.nGrid {
                let alts = n == 800 ? RWCPowerDerivationV3.fullAlts : RWCPowerDerivationV3.reducedAlts
                for alt in alts {
                    var rejects = 0
                    for t in 0..<RWCPowerDerivationV3.trials {
                        let base = ["power", shape, alt, String(n), String(t)]
                        let data = RWCPowerDerivationV3.dataset(shape: shape, alt: alt, n: n,
                                                                seedParts: base + ["data"])
                        let dec = try RWCCalibrationMethodologyV3.decideV3(
                            preds: data.preds, labels: data.labels, sims: s, seedParts: base + ["eval"])
                        if !dec.passed { rejects += 1 }
                    }
                    let rate = Double(rejects) / Double(RWCPowerDerivationV3.trials)
                    cellLines.append("    \"\(shape)|\(alt)|n\(n)\": {\"rejects\": \(rejects), \"trials\": \(RWCPowerDerivationV3.trials), \"reject_rate\": \(RWCPowerDerivationV3.fmt(rate))}")
                }
            }
        }
        out += cellLines.joined(separator: ",\n") + "\n  }\n}\n"
        let url = try RWCPowerDerivationV3.writeJSON(out,
            to: "docs/calibration/preregistration/tools/RWC_CALIBRATION_POWER_RESULTS_V3.json")
        print("POWER_WRITTEN=\(url.path)")
    }

    /// Quick benchmark for budget sanity (env-gated; informational only).
    func testDerive_Benchmark() throws {
        guard mode() == "bench" else { throw XCTSkip("env-gated derivation runner") }
        let data = RWCPowerDerivationV3.dataset(shape: "uniform", alt: "null", n: 800,
                                                seedParts: ["bench", "data"])
        let t0 = ProcessInfo.processInfo.systemUptime
        _ = try RWCCalibrationMethodologyV3.decideV3(preds: data.preds, labels: data.labels,
                                                     sims: 4999, seedParts: ["bench", "eval"])
        let dt = ProcessInfo.processInfo.systemUptime - t0
        print("BENCH_DECIDE_N800_S4999_SECONDS=\(dt)")
    }
}
