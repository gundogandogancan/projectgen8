import Foundation
import CryptoKit

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC CALIBRATION METHODOLOGY V4 — canonical statistical law after AUDIT16 (R3).
//
// Supersedes (BY RECORD, not by mutation) RWCCalibrationMethodologyV3, which stays byte-frozen as
// AUDIT16 negative evidence (A16-F8/F9/F23 pins). The estimator CORE is UNCHANGED and reused from
// V3 verbatim-by-call (tie-group binning, strict input domain, exact integer MC boundary) — AUDIT16
// independently verified those CLEAN; only what A16-F8/F9/F23 require changes (R3 mandate §47).
//
// V4 LAWS:
//  • SEED ENCODING (A16-F8): canonical LENGTH-PREFIXED context — no separator join, no aliasing:
//      bytes = LP("GEN8-RWC-CAL-V4") + UInt32BE(partCount) + for each part LP(part)
//      where LP(x) = UInt32BE(len(utf8 x)) + utf8 x;  seed64 = first 8 bytes of SHA-256, big-endian.
//      ["a|b","c"] and ["a","b|c"] are DIFFERENT by construction; empty parts unambiguous.
//  • EVALUATION SEED MANIFEST (A16-F9): the REAL evaluation seed hashes
//      RWCEvaluationSeedManifestV1 — a TYPED, outcome-independent identity record. The type has NO
//      field capable of carrying labels/annotations/adjudication/predictions/metric outputs, and
//      the frozen schema law (RWC_EVALUATION_SEED_MANIFEST_SCHEMA_V1.yaml) forbids them. Seed
//      context = ["eval", manifestSHA256, metricID, purpose].
//  • S LAW (A16-F23): the failed empirical premise "smallest S with mixed-verdict <= 1.5%" is
//      RETIRED (AUDIT16 replication measured 5.0% null mixed; builder's 0.0% was a dataset-reuse
//      artifact — that artifact stays as negative history). V4 selects S ANALYTICALLY, pre-data:
//        criterion (frozen): candidate grid S+1 ∈ {10^k} (clean p-value resolution 1/(S+1)) with
//        (S+1)%20==0 exactness; REQUIRE Monte-Carlo standard error of the exceedance probability
//        at p = alpha, SE = sqrt(alpha·(1-alpha)/S), to be <= alpha/20 = 0.0025.
//        S=999 → SE 0.00690 (REJECTED). S=9999 → SE 0.00218 (SELECTED; resolution 1e-4).
//      No claim of seed-invariance is made: MC is random by nature. The frozen claim is:
//      deterministic under the frozen seed law + predeclared MC precision; near-boundary verdict
//      uncertainty is CHARACTERIZED (not selected on) in RWC_CALIBRATION_MC_PRECISION_V4.json.
//  • IRR (A16-F11): canonical ordinal kappa hard threshold RESTORED to the historical frozen 0.60.
//      The v3 "0.61" was undisclosed drift and remains recorded negative evidence. Planning law
//      unchanged: MIN_VALID=50, PLANNED_TARGET_N=300.
//  • SENTINEL COUNTERS (A16-F10): remodeled as four exhaustive mutually-exclusive categories whose
//      SUM IS the total — impossible totals are unrepresentable; protective abstention is valid.
//
// ZERO-DATA: synthetic inputs only. No real predictions/labels/corpus. No PASS lock exists.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

enum RWCCalibrationMethodologyV4 {
    static let version = "rwc-calibration-methodology-v4"
    static let bins = RWCCalibrationMethodologyV3.bins                   // 10 (carried, CLEAN)
    static let alpha = 0.05
    /// ANALYTICAL precision law (see header): SE(alpha, S) <= alpha/20 on the 10^k grid.
    static let frozenNullSims = 9999
    static let frozenSETolerance = 0.0025
    static let nullAdjustedExcessLimit = RWCCalibrationMethodologyV3.nullAdjustedExcessLimit // 0.05
    static let frozenOverallN = 800   // retained ONLY if V4 power re-derivation upholds the law
    static let frozenMinDecisionCoverage = RWCCalibrationMethodologyV3.frozenMinDecisionCoverage
    /// A16-F11: canonical historical threshold RESTORED.
    static let irrOrdinalKappaThreshold = 0.60
    static let irrMinValidPairs = 50
    static let irrPlannedTargetPairs = 300

    static func analyticalSE(alpha: Double, sims: Int) -> Double {
        (alpha * (1 - alpha) / Double(sims)).squareRoot()
    }

    // MARK: Seed law V4 — canonical length-prefixed context (A16-F8)

    static func canonicalSeedContext(_ parts: [String]) -> Data {
        var out = Data()
        func lp(_ s: String) {
            let bytes = Data(s.utf8)
            var len = UInt32(bytes.count).bigEndian
            withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
            out.append(bytes)
        }
        lp("GEN8-RWC-CAL-V4")
        var count = UInt32(parts.count).bigEndian
        withUnsafeBytes(of: &count) { out.append(contentsOf: $0) }
        for p in parts { lp(p) }
        return out
    }

    static func seed64(_ parts: [String]) -> UInt64 {
        let digest = SHA256.hash(data: canonicalSeedContext(parts))
        var v: UInt64 = 0
        for (i, byte) in digest.enumerated() where i < 8 { v = (v << 8) | UInt64(byte) }
        return v
    }

    // MARK: Evaluation seed manifest (A16-F9) — outcome-independent BY TYPE

    /// Pre-outcome identity ONLY. There is no field for labels, annotations, adjudication results,
    /// predictions, metric outputs or any post-evaluation fact — such data is unrepresentable here.
    struct RWCEvaluationSeedManifestV1: Equatable {
        let datasetID: String            // sealed dataset identity token
        let sealedAssetIDsDigest: String // SHA-256 over the sorted sealed asset-ID list
        let splitID: String              // frozen split identity
        let datasetVersion: String
        let modelArtifactID: String      // model/version under evaluation (pre-outcome)
        let methodologyVersion: String   // e.g. "rwc-calibration-methodology-v4"
        let evaluationRunID: String

        /// Canonical serialization: fixed field order, length-prefixed (same LP law as seeds).
        func canonicalBytes() -> Data {
            var out = Data()
            for f in ["rwc-eval-seed-manifest-v1", datasetID, sealedAssetIDsDigest, splitID,
                      datasetVersion, modelArtifactID, methodologyVersion, evaluationRunID] {
                let bytes = Data(f.utf8)
                var len = UInt32(bytes.count).bigEndian
                withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
                out.append(bytes)
            }
            return out
        }

        var sha256Hex: String {
            SHA256.hash(data: canonicalBytes()).map { String(format: "%02x", $0) }.joined()
        }
    }

    /// The frozen REAL-evaluation seed derivation (outcome-independent by construction).
    static func evaluationSeed(manifest: RWCEvaluationSeedManifestV1, metricID: String,
                               purpose: String) -> UInt64 {
        seed64(["eval", manifest.sha256Hex, metricID, purpose])
    }

    // MARK: Primary decision V4 — estimator core reused from V3 (CLEAN), S and seeding per V4

    struct CalibrationDecisionV4: Equatable {
        let observed: Double
        let pMC: Double
        let nullMean: Double
        let nullAdjustedExcessECE: Double
        let sims: Int
        let testGatePassed: Bool
        let excessGatePassed: Bool
        var passed: Bool { testGatePassed && excessGatePassed }
    }

    static func decideV4(preds: [Double], labels: [Bool], bins: Int = bins,
                         sims: Int = frozenNullSims, seedParts: [String]) throws -> CalibrationDecisionV4 {
        guard sims >= 19, (sims + 1) % 20 == 0 else {
            throw RWCCalibrationInputErrorV1.invalidSimulationCount(sims)
        }
        let observed = try RWCCalibrationMethodologyV3.eceTieInvariant(preds: preds, labels: labels, bins: bins)
        let plan = RWCCalibrationMethodologyV3.tieGroupPlan(preds: preds, bins: bins)
        var rng = RWCSplitMix64(seed: seed64(seedParts))
        var exceed = 0
        var nullSum = 0.0
        for _ in 0..<sims {
            // identical null-estimator law as the frozen V3 core (per tie group, item-level draws)
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
            var e = 0.0
            for b in 0..<plan.bins where count[b] > 0 {
                let c = Double(count[b])
                e += c / Double(plan.n) * abs(sumP[b] / c - sumY[b] / c)
            }
            nullSum += e
            if e >= observed { exceed += 1 }
        }
        let pMC = Double(1 + exceed) / Double(sims + 1)
        let nullMean = nullSum / Double(sims)
        let excess = max(0, observed - nullMean)
        let testFails = 20 * (1 + exceed) <= (sims + 1)   // integer boundary law (carried, CLEAN)
        return CalibrationDecisionV4(observed: observed, pMC: pMC, nullMean: nullMean,
                                     nullAdjustedExcessECE: excess, sims: sims,
                                     testGatePassed: !testFails,
                                     excessGatePassed: excess <= nullAdjustedExcessLimit)
    }

    // MARK: Sentinel counters V2 (A16-F10) — exhaustive categories, impossible totals unrepresentable

    enum RWCSentinelCountsErrorV1: Error, Equatable {
        case negativeCount(field: String)
    }

    /// Four mutually exclusive, exhaustive outcome categories for sentinel items. The TOTAL is the
    /// sum — there is no independent total field to contradict. Protective abstention is a valid
    /// protective outcome; an explicit non-protective (unsafe) decision is representable and is
    /// NEVER counted as protective.
    struct RWCSentinelCountsV2: Equatable {
        let explicitProtective: Int
        let explicitUnsafe: Int
        let protectiveAbstention: Int
        let otherAbstention: Int

        init(explicitProtective: Int, explicitUnsafe: Int, protectiveAbstention: Int,
             otherAbstention: Int) throws {
            for (name, v) in [("explicitProtective", explicitProtective), ("explicitUnsafe", explicitUnsafe),
                              ("protectiveAbstention", protectiveAbstention), ("otherAbstention", otherAbstention)]
            where v < 0 { throw RWCSentinelCountsErrorV1.negativeCount(field: name) }
            self.explicitProtective = explicitProtective; self.explicitUnsafe = explicitUnsafe
            self.protectiveAbstention = protectiveAbstention; self.otherAbstention = otherAbstention
        }

        var total: Int { explicitProtective + explicitUnsafe + protectiveAbstention + otherAbstention }
        var protectiveOutcomes: Int { explicitProtective + protectiveAbstention }
        var explicitDecisions: Int { explicitProtective + explicitUnsafe }
        var abstentions: Int { protectiveAbstention + otherAbstention }

        func rate(_ numerator: Int) -> RWCCalibrationMethodologyV3.RWCRateV2 {
            total > 0 ? .value(Double(numerator) / Double(total)) : .notApplicable
        }
    }
}
