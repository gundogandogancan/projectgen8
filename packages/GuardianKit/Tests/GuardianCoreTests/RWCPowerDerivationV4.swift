import XCTest
import Foundation
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC POWER/PRECISION DERIVATION V4 (A16-F23 closure) — canonical pre-data derivation engine.
//
// Differences vs the frozen V3 engine (which stays as negative-history evidence):
//  • V4 seed law (length-prefixed, A16-F8) everywhere; S = 9999 by the ANALYTICAL precision law
//    (RWCCalibrationMethodologyV4 header) — the failed empirical "mixed <= 1.5%" selection premise
//    is RETIRED (A16-F23).
//  • The MC precision artifact CHARACTERIZES near-boundary verdict uncertainty with FRESH datasets
//    per S candidate (never reusing one draw across candidates — the exact flaw AUDIT16 exposed in
//    the V3 stability artifact) and REPORTS it; nothing is selected from it.
//  • Generator shapes/alternatives are carried verbatim from V3 (independently replicated CLEAN).
//
// Runners (env-gated): GEN8_RWC_DERIVE_V4=precision | power | bench
// Outputs: docs/calibration/preregistration/tools/RWC_CALIBRATION_MC_PRECISION_V4.json
//          docs/calibration/preregistration/tools/RWC_CALIBRATION_POWER_RESULTS_V4.json
// Determinism law: byte-identical across runs (pure function of frozen design).
// ═══════════════════════════════════════════════════════════════════════════════════════════════

enum RWCPowerDerivationV4 {
    static let version = "rwc-power-derivation-v4"
    static let shapes = RWCPowerDerivationV3.shapes
    static let fullAlts = RWCPowerDerivationV3.fullAlts
    static let reducedAlts = RWCPowerDerivationV3.reducedAlts
    static let nGrid = RWCPowerDerivationV3.nGrid
    static let trials = 200

    static func dataset(shape: String, alt: String, n: Int, seedParts: [String]) -> (preds: [Double], labels: [Bool]) {
        var rng = RWCSplitMix64(seed: RWCCalibrationMethodologyV4.seed64(seedParts))
        var preds = [Double](), labels = [Bool]()
        preds.reserveCapacity(n); labels.reserveCapacity(n)
        for _ in 0..<n {
            let p = RWCPowerDerivationV3.confidence(shape, rng: &rng)
            preds.append(p)
            labels.append(rng.double01() < RWCPowerDerivationV3.trueProbability(alt, p: p))
        }
        return (preds, labels)
    }

    static func fmt(_ x: Double) -> String { String(format: "%.6f", x) }
}

final class RWCPowerDerivationV4Runner: XCTestCase {

    private func mode() -> String? { ProcessInfo.processInfo.environment["GEN8_RWC_DERIVE_V4"] }

    /// PRECISION artifact: (a) the ANALYTICAL S-selection table (pure arithmetic — this IS the
    /// selection law); (b) near-boundary verdict-uncertainty CHARACTERIZATION at the selected S
    /// with FRESH independent datasets and independent evaluation seeds (reported, never selected
    /// on); (c) Type-I measurement at S=9999.
    func testDerive_PrecisionArtifact() throws {
        guard mode() == "precision" else { throw XCTSkip("env-gated derivation runner") }
        typealias M4 = RWCCalibrationMethodologyV4
        var out = "{\n  \"version\": \"\(RWCPowerDerivationV4.version)\",\n  \"study\": \"mc-precision-v4\",\n"
        out += "  \"selection_law\": \"ANALYTICAL (pre-data): candidate grid S+1 in {10^k} with (S+1)%20==0; require SE(alpha,S)=sqrt(alpha*(1-alpha)/S) <= alpha/20 = 0.0025. The retired V3 empirical rule (mixed<=1.5%) is negative history (A16-F23).\",\n"
        out += "  \"selection_table\": {\n"
        var rows: [String] = []
        for s in [99, 999, 9999, 99999] {
            let se = M4.analyticalSE(alpha: M4.alpha, sims: s)
            rows.append("    \"S\(s)\": {\"p_resolution\": \(RWCPowerDerivationV4.fmt(1.0 / Double(s + 1))), \"se_at_alpha\": \(RWCPowerDerivationV4.fmt(se)), \"meets_tolerance_0.0025\": \(se <= M4.frozenSETolerance)}")
        }
        out += rows.joined(separator: ",\n") + "\n  },\n  \"selected_S\": \(M4.frozenNullSims),\n"
        // (b) near-boundary characterization at selected S: FRESH datasets, 20 eval seeds each.
        out += "  \"characterization\": {\n"
        var charRows: [String] = []
        for (suite, alt) in [("null", "null"), ("boundary_over05", "over05")] {
            var mixed = 0, total = 0
            for shape in ["uniform", "clustered"] {
                for d in 0..<60 {
                    let data = RWCPowerDerivationV4.dataset(shape: shape, alt: alt, n: 800,
                        seedParts: ["precision-v4", suite, shape, String(d), "data"])
                    var verdicts = Set<Bool>()
                    for e in 0..<20 {
                        let dec = try M4.decideV4(preds: data.preds, labels: data.labels,
                            seedParts: ["precision-v4", suite, shape, String(d), "eval", String(e)])
                        verdicts.insert(dec.passed)
                    }
                    total += 1
                    if verdicts.count > 1 { mixed += 1 }
                }
            }
            charRows.append("    \"\(suite)|S\(M4.frozenNullSims)\": {\"mixed\": \(mixed), \"datasets\": \(total), \"mixed_fraction\": \(RWCPowerDerivationV4.fmt(Double(mixed) / Double(total))), \"semantics\": \"REPORTED near-boundary verdict uncertainty — not a selection criterion\"}")
        }
        out += charRows.joined(separator: ",\n") + "\n  },\n"
        // (c) Type-I at S=9999 across the six shapes (fresh V4 seeds).
        out += "  \"type_I\": {\n"
        var tRows: [String] = []
        for shape in RWCPowerDerivationV4.shapes {
            var rejects = 0
            for t in 0..<RWCPowerDerivationV4.trials {
                let base = ["typei-v4", shape, String(t)]
                let data = RWCPowerDerivationV4.dataset(shape: shape, alt: "null", n: 800,
                                                        seedParts: base + ["data"])
                let dec = try M4.decideV4(preds: data.preds, labels: data.labels, seedParts: base + ["eval"])
                if !dec.passed { rejects += 1 }
            }
            tRows.append("    \"\(shape)|null|n800\": {\"rejects\": \(rejects), \"trials\": \(RWCPowerDerivationV4.trials), \"reject_rate\": \(RWCPowerDerivationV4.fmt(Double(rejects) / Double(RWCPowerDerivationV4.trials)))}")
        }
        out += tRows.joined(separator: ",\n") + "\n  }\n}\n"
        let url = try RWCPowerDerivationV3.writeJSON(out,
            to: "docs/calibration/preregistration/tools/RWC_CALIBRATION_MC_PRECISION_V4.json")
        print("PRECISION_V4_WRITTEN=\(url.path)")
    }

    /// POWER study at the frozen V4 S (9999), V4 seed law, V3-carried generators/cells.
    func testDerive_PowerStudy() throws {
        guard mode() == "power" else { throw XCTSkip("env-gated derivation runner") }
        typealias M4 = RWCCalibrationMethodologyV4
        let s = M4.frozenNullSims
        var out = "{\n  \"version\": \"\(RWCPowerDerivationV4.version)\",\n  \"study\": \"power-v4\",\n"
        out += "  \"design\": {\"trials\": \(RWCPowerDerivationV4.trials), \"S\": \(s), \"bins\": \(M4.bins), \"decision\": \"PASS iff 20*(1+exceed) > S+1 AND nullAdjustedExcessECE <= 0.05\", \"seed_law\": \"V4 length-prefixed SHA-256 (GEN8-RWC-CAL-V4)\", \"n_law\": \"retain n=800 iff over07 AND under07 rejection >= 0.80 for ALL six shapes (carried predeclared rule)\"},\n"
        out += "  \"cells\": {\n"
        var cellLines: [String] = []
        for shape in RWCPowerDerivationV4.shapes {
            for n in RWCPowerDerivationV4.nGrid {
                let alts = n == 800 ? RWCPowerDerivationV4.fullAlts : RWCPowerDerivationV4.reducedAlts
                for alt in alts {
                    var rejects = 0
                    for t in 0..<RWCPowerDerivationV4.trials {
                        let base = ["power-v4", shape, alt, String(n), String(t)]
                        let data = RWCPowerDerivationV4.dataset(shape: shape, alt: alt, n: n,
                                                                seedParts: base + ["data"])
                        let dec = try M4.decideV4(preds: data.preds, labels: data.labels, sims: s,
                                                  seedParts: base + ["eval"])
                        if !dec.passed { rejects += 1 }
                    }
                    cellLines.append("    \"\(shape)|\(alt)|n\(n)\": {\"rejects\": \(rejects), \"trials\": \(RWCPowerDerivationV4.trials), \"reject_rate\": \(RWCPowerDerivationV4.fmt(Double(rejects) / Double(RWCPowerDerivationV4.trials)))}")
                }
            }
        }
        out += cellLines.joined(separator: ",\n") + "\n  }\n}\n"
        let url = try RWCPowerDerivationV3.writeJSON(out,
            to: "docs/calibration/preregistration/tools/RWC_CALIBRATION_POWER_RESULTS_V4.json")
        print("POWER_V4_WRITTEN=\(url.path)")
    }

    func testDerive_Benchmark() throws {
        guard mode() == "bench" else { throw XCTSkip("env-gated derivation runner") }
        let data = RWCPowerDerivationV4.dataset(shape: "uniform", alt: "null", n: 800,
                                                seedParts: ["bench-v4", "data"])
        let t0 = ProcessInfo.processInfo.systemUptime
        _ = try RWCCalibrationMethodologyV4.decideV4(preds: data.preds, labels: data.labels,
                                                     seedParts: ["bench-v4", "eval"])
        print("BENCH_V4_DECIDE_N800_S9999_SECONDS=\(ProcessInfo.processInfo.systemUptime - t0)")
    }
}
