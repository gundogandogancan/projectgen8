import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT16 — POWER-DERIVATION REPRODUCIBILITY PROBE (mandate §24/§49; auditor-owned, add-only).
//
// Gated by a FLAG FILE instead of an env var because the second AUDIT16 session's sandbox denies
// env-prefixed commands (`GEN8_...=x swift test` is not grantable there). The flag file is created
// immediately before the filtered run and deleted afterwards; in normal suite runs the probe skips.
//
// Verification law (§24): the canonical derivation must be byte-reproducible. This probe runs the
// builder's EXACT derivation code path (RWCPowerDerivationV3 statics + decideV3, same seed law)
// TWICE IN MEMORY — never touching the committed artifact — and requires:
//   run1 == run2 (byte identity), and SHA-256(run1) == SHA-256(committed artifact bytes)
//   == SHA-256(git show HEAD:<artifact>) == 3f71f356… (the builder-claimed hash).
// This is strictly stronger than overwrite-and-restore: the working tree is never mutated.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT16_DerivationReproProbes: XCTestCase {

    static let flagPath = "/tmp/gen8_audit16_repro.flag"
    private let claimedPowerSHA256 =
        "3f71f3568a075a030567256f91fd5e6cb86aba87cd4f54d4bedb2d106c7460ad"
    private let powerRelPath =
        "docs/calibration/preregistration/tools/RWC_CALIBRATION_POWER_RESULTS_V3.json"

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

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Byte-exact in-memory regeneration of the power artifact via the builder's own derivation
    /// code (identical loops/format strings to RWCPowerDerivationV3Runner.testDerive_PowerStudy,
    /// minus the file write).
    private func derivePowerJSONInMemory() throws -> String {
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
        return out
    }

    func testAUDIT16_PowerDerivation_ByteReproducible_x2_MatchesCommitted() throws {
        guard FileManager.default.fileExists(atPath: Self.flagPath) else {
            throw XCTSkip("flag-gated auditor reproducibility probe (create \(Self.flagPath))")
        }
        let run1 = try derivePowerJSONInMemory()
        let run2 = try derivePowerJSONInMemory()
        XCTAssertEqual(run1, run2, "power derivation is not run-to-run byte-reproducible")
        let sha1 = sha256Hex(Data(run1.utf8))
        print("AUDIT16_POWER_REPRO run1==run2 sha=\(sha1)")
        XCTAssertEqual(sha1, claimedPowerSHA256, "regenerated artifact differs from the builder claim")
        // committed working-tree artifact byte identity
        let committed = try Data(contentsOf: repoRoot().appendingPathComponent(powerRelPath))
        XCTAssertEqual(sha256Hex(committed), claimedPowerSHA256,
                       "committed artifact differs from the regenerated derivation")
        // HEAD blob identity (the derivation output equals what is committed at the candidate)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git", "-C", repoRoot().path, "show", "HEAD:" + powerRelPath]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        try p.run()
        let headData = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0)
        XCTAssertEqual(sha256Hex(headData), claimedPowerSHA256,
                       "HEAD-committed artifact differs from the regenerated derivation")
    }
}
