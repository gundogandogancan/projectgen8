import XCTest
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC ENTRY GATE — R1 FIX TEST FAMILY (additive).
// Asserts the FIXED behavior for the AUDIT10 findings:
//   A10-F2-WIRING   — canonical pipeline wired; silent drop impossible by construction
//   A10-F2-MULTISET — exact identity with uniqueness law (typed duplicate integrity errors)
//   A10-F3-SIBLINGS — maeStrict/aurocStrict + legacy refusal markers (one domain doctrine)
//   A10-A9-DISCIPLINE / A10-F3-FPEDGE — lock/erratum artefacts exist; frozen originals byte-exact
// AUDIT10's own probes remain historical evidence; their three pre-declared inversions are governed
// by docs/audit/AUDIT10_INVERSION_LOCK.md and re-verified from disk here.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class RWCEntryGateR1Tests: XCTestCase {

    private var repoRoot: String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }
    private func realResolver(_ pair: CalibrationPairV1) -> P009DPolicyScenarioV1? {
        P009EScoreTests().scenario(for: pair)
    }
    private func phantomPair(_ item: String) -> CalibrationPairV1 {
        CalibrationPairV1(itemID: item, corpus: "P009D", profile: .adultNeutral, split: .trainTune,
                          source: .syntheticDerived,
                          annotation: CalibrationAnnotationV1(itemID: item, profileID: "adult-neutral",
                                                              locale: "en", labelA: 2, labelB: 2))
    }

    // ═════════ F2 matrix (mandate §5 A–K) — REAL pipeline where the shape allows it ═════════

    /// A + J(real): full 59/59 ledger through the REAL resolver through the canonical gate → SUCCESS,
    /// one record per declared pair, composite IDs unique (the uniqueness precondition, verified live).
    func testR1_F2_A_RealLedgerFullResolutionSucceeds() throws {
        let records = try CalibrationRunPreparationV1.prepare(declared: CalibrationDatasetRegistryV2.pairs,
                                                              resolve: realResolver)
        XCTAssertEqual(records.count, 59)
        let ids = records.map { CalibrationRunPreparationV1.compositeID($0.pair) }
        XCTAssertEqual(Set(ids).count, 59, "59 composite IDs, all unique — uniqueness law holds on the real ledger")
    }

    /// B: 58/59 — one REAL registry pair made unresolvable → the ACTUAL entrypoint refuses with the
    /// typed error naming exactly that composite ID; zero records escape.
    func testR1_F2_B_58of59Refused() {
        let victim = CalibrationRunPreparationV1.compositeID(CalibrationDatasetRegistryV2.pairs[7])
        var escaped: Int? = nil
        do {
            let r = try CalibrationRunPreparationV1.prepare(declared: CalibrationDatasetRegistryV2.pairs) { pair in
                CalibrationRunPreparationV1.compositeID(pair) == victim ? nil : realResolver(pair)
            }
            escaped = r.count
        } catch let e as CalibrationIntegrityErrorV1 {
            guard case let .unresolvedPairs(d, r, ids, cat) = e else { return XCTFail("wrong case: \(e)") }
            XCTAssertEqual(d, 59); XCTAssertEqual(r, 58)
            XCTAssertEqual(ids, [victim]); XCTAssertEqual(cat, "scenario-resolution")
        } catch { XCTFail("typed CalibrationIntegrityErrorV1 required, got \(error)") }
        XCTAssertNil(escaped, "NO records may escape a partial resolution — fit stage unreachable")
    }

    /// C: same count, different identity set → refused naming the missing ID (extra cannot cancel it).
    func testR1_F2_C_SameCountDifferentIdentity() {
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["a", "b", "c"], resolvedIDs: ["a", "b", "x"])) { e in
            guard case let .unresolvedPairs(3, 3, ids, _)? = e as? CalibrationIntegrityErrorV1
            else { return XCTFail("typed unresolvedPairs required") }
            XCTAssertEqual(ids, ["c"])
        }
    }

    /// D: duplicate DECLARED [a,a,b] → typed duplicate-declaration integrity error (regardless of resolved).
    func testR1_F2_D_DuplicateDeclaredRefused() {
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["a", "a", "b"], resolvedIDs: ["a", "b", "b"])) { e in
            XCTAssertEqual(e as? CalibrationIntegrityErrorV1,
                           .duplicateDeclaredIDs(ids: ["a"], category: "scenario-resolution"))
        }
        // and through the canonical pipeline with a REAL duplicated pair:
        let dup = CalibrationDatasetRegistryV2.pairs + [CalibrationDatasetRegistryV2.pairs[0]]
        XCTAssertThrowsError(try CalibrationRunPreparationV1.prepare(declared: dup, resolve: realResolver)) { e in
            guard case .duplicateDeclaredIDs? = e as? CalibrationIntegrityErrorV1
            else { return XCTFail("duplicate declared pair must be a typed declaration-integrity error") }
        }
    }

    /// E: duplicate RESOLVED [a,b,b] under unique declared → typed duplicate-resolution integrity error.
    func testR1_F2_E_DuplicateResolvedRefused() {
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["a", "b", "c"], resolvedIDs: ["a", "b", "b"])) { e in
            XCTAssertEqual(e as? CalibrationIntegrityErrorV1,
                           .duplicateResolvedIDs(ids: ["b"], category: "scenario-resolution"))
        }
    }

    /// F: masked duplicate — declared [a,a], resolved [a,b] → refused (duplicate declared, the
    /// unexpected extra can no longer cancel it).
    func testR1_F2_F_MaskedDuplicateRefused() {
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["a", "a"], resolvedIDs: ["a", "b"])) { e in
            XCTAssertEqual(e as? CalibrationIntegrityErrorV1,
                           .duplicateDeclaredIDs(ids: ["a"], category: "scenario-resolution"))
        }
    }

    /// G: unexpected extra resolved → typed unexpected-resolved integrity error (named, sorted).
    func testR1_F2_G_UnexpectedExtraRefused() {
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["a"], resolvedIDs: ["a", "surplus"])) { e in
            XCTAssertEqual(e as? CalibrationIntegrityErrorV1,
                           .unexpectedResolvedIDs(ids: ["surplus"], category: "scenario-resolution"))
        }
    }

    /// H: alias-to-missing through the REAL resolver → refused naming the alias composite ID.
    func testR1_F2_H_AliasToMissingRefused() {
        let ghost = phantomPair("ALIAS:pc-ghost-item")
        XCTAssertThrowsError(try CalibrationRunPreparationV1.prepare(
            declared: CalibrationDatasetRegistryV2.pairs + [ghost], resolve: realResolver)) { e in
            guard case let .unresolvedPairs(60, 59, ids, _)? = e as? CalibrationIntegrityErrorV1
            else { return XCTFail("typed unresolvedPairs required") }
            XCTAssertEqual(ids, ["ALIAS:pc-ghost-item#adult-neutral"])
        }
    }

    /// I: malformed/empty IDs on either side → typed malformed-ID refusal (counts only, no payload).
    func testR1_F2_I_MalformedIDsRefused() {
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["", "a"], resolvedIDs: ["", "a"])) { e in
            XCTAssertEqual(e as? CalibrationIntegrityErrorV1,
                           .malformedIDs(declared: 1, resolved: 1, category: "scenario-resolution"))
        }
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["a"], resolvedIDs: ["   "]))
    }

    /// J: order difference ONLY → success (identity is a set law, not an ordering law).
    func testR1_F2_J_OrderIndependentAcceptance() throws {
        try CalibrationRunGuardV1.requireFullResolution(declaredIDs: ["a", "b", "c"], resolvedIDs: ["c", "a", "b"])
        let all = CalibrationDatasetRegistryV2.pairs.map(CalibrationRunPreparationV1.compositeID)
        try CalibrationRunGuardV1.requireFullResolution(declaredIDs: all, resolvedIDs: all.reversed())
    }

    /// K: one unresolved pair injected into the REAL ledger → the REAL fit/evaluation entrypoint
    /// (the exact prepare+resolver call the production harness setUp makes) REFUSES; additionally the
    /// LIVE harness run went through the gate (wired proof, not a local-flow tautology).
    func testR1_F2_K_RealEntrypointRefusesInjectedPhantom() {
        var fitInputsExist = false
        do {
            let records = try CalibrationRunPreparationV1.prepare(
                declared: CalibrationDatasetRegistryV2.pairs + [phantomPair("r1-phantom-item")],
                resolve: realResolver)
            fitInputsExist = !records.isEmpty
        } catch let e as CalibrationIntegrityErrorV1 {
            guard case let .unresolvedPairs(60, 59, ids, _) = e else { return XCTFail("wrong case: \(e)") }
            XCTAssertEqual(ids, ["r1-phantom-item#adult-neutral"])
        } catch { XCTFail("typed error required, got \(error)") }
        XCTAssertFalse(fitInputsExist, "fit inputs cannot exist on a 59/60 ledger — refusal precedes fit")
        // the LIVE production harness itself passes the wired gate (selection-independent: trigger
        // the harness class preparation if this focused run has not executed it yet)
        if P009EScoreTests.pairResults.isEmpty && P009EScoreTests.integrityRefusal == nil {
            P009EScoreTests.setUp()
        }
        XCTAssertNil(P009EScoreTests.integrityRefusal, "live harness: canonical gate accepted 59/59")
        XCTAssertEqual(P009EScoreTests.pairResults.count, 59, "live harness: one result per declared pair")
    }

    // ═════════ F3 siblings — one domain doctrine for MAE/AUROC (strict + legacy markers) ═════════

    func testR1_F3_MAEStrictMatrix() throws {
        // invalid values refuse with typed index-bearing errors (default probability domain)
        for bad in [Double.nan, .infinity, -.infinity, -0.001, 1.001] {
            XCTAssertThrowsError(try CalibrationMetricsV1.maeStrict([0.5, bad], [0.4, 0.5]), "pred \(bad)") { e in
                XCTAssertTrue(e is MetricInputErrorV1)
            }
            XCTAssertThrowsError(try CalibrationMetricsV1.maeStrict([0.5, 0.5], [0.4, bad]), "target \(bad)") { e in
                XCTAssertTrue(e is MetricInputErrorV1)
            }
        }
        // shape mismatch both ways; empty input is not a valid metric
        XCTAssertThrowsError(try CalibrationMetricsV1.maeStrict([0.5, 0.6], [0.5])) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .shapeMismatch(preds: 2, labels: 1))
        }
        XCTAssertThrowsError(try CalibrationMetricsV1.maeStrict([], [])) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .emptyInput)
        }
        // explicit domain law: 3.7 is invalid as a probability, valid on the rubric scale 0…4
        XCTAssertThrowsError(try CalibrationMetricsV1.maeStrict([3.7], [3.0]))
        XCTAssertEqual(try CalibrationMetricsV1.maeStrict([3.7], [3.0], domain: 0...4), 0.7, accuracy: 1e-12)
        // valid values: strict == legacy exactly (no value drift from the hardening)
        let p = [0.1, 0.4, 0.9], t = [0.2, 0.4, 0.5]
        XCTAssertEqual(try CalibrationMetricsV1.maeStrict(p, t), CalibrationMetricsV1.mae(p, t), accuracy: 1e-15)
    }

    func testR1_F3_AUROCStrictMatrix() throws {
        for bad in [Double.nan, .infinity, -.infinity, -0.001, 1.001] {
            XCTAssertThrowsError(try CalibrationMetricsV1.aurocStrict(preds: [0.5, bad], labels: [true, false]),
                                 "\(bad)") { e in XCTAssertTrue(e is MetricInputErrorV1) }
        }
        // degenerate one-class labels: typed refusal (undefined metric), both directions
        XCTAssertThrowsError(try CalibrationMetricsV1.aurocStrict(preds: [0.2, 0.8], labels: [true, true])) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .degenerateLabels(positives: 2, negatives: 0))
        }
        XCTAssertThrowsError(try CalibrationMetricsV1.aurocStrict(preds: [0.2, 0.8], labels: [false, false])) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .degenerateLabels(positives: 0, negatives: 2))
        }
        XCTAssertThrowsError(try CalibrationMetricsV1.aurocStrict(preds: [0.5], labels: [true, false])) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .shapeMismatch(preds: 1, labels: 2))
        }
        XCTAssertThrowsError(try CalibrationMetricsV1.aurocStrict(preds: [], labels: [])) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .emptyInput)
        }
        // valid values: strict == legacy exactly; hand-verified fixture (perfect separation = 1.0)
        let p = [0.9, 0.8, 0.2, 0.1], l = [true, true, false, false]
        XCTAssertEqual(try CalibrationMetricsV1.aurocStrict(preds: p, labels: l), 1.0, accuracy: 1e-12)
        XCTAssertEqual(try CalibrationMetricsV1.aurocStrict(preds: p, labels: l),
                       CalibrationMetricsV1.auroc(preds: p, labels: l)!, accuracy: 1e-15)
        // ties counted 0.5 (unchanged law)
        XCTAssertEqual(try CalibrationMetricsV1.aurocStrict(preds: [0.5, 0.5], labels: [true, false]), 0.5, accuracy: 1e-12)
    }

    func testR1_F3_LegacyMarkersNeverSilent() {
        // legacy mae: explicit NaN refusal marker on non-finite input AND on shape mismatch (which
        // previously truncated silently via zip)
        XCTAssertTrue(CalibrationMetricsV1.mae([Double.nan, 0.5], [0.0, 0.5]).isNaN)
        XCTAssertTrue(CalibrationMetricsV1.mae([.infinity], [0.0]).isNaN)
        XCTAssertTrue(CalibrationMetricsV1.mae([0.5, 0.6], [0.5]).isNaN, "shape mismatch is a refusal, not a silent truncation")
        XCTAssertEqual(CalibrationMetricsV1.mae([], []), 0, "legacy empty semantics preserved")
        // legacy auroc: nil undefined-channel on invalid preds — NEVER a finite miscount
        XCTAssertNil(CalibrationMetricsV1.auroc(preds: [Double.nan, 0.9], labels: [false, true]))
        XCTAssertNil(CalibrationMetricsV1.auroc(preds: [1.5, 0.9], labels: [false, true]))
        XCTAssertNil(CalibrationMetricsV1.auroc(preds: [0.5], labels: [true, false]), "shape mismatch refused")
        XCTAssertNil(CalibrationMetricsV1.auroc(preds: [0.2, 0.8], labels: [true, true]), "degenerate unchanged")
        // ECE/Brier regression: valid-domain values unchanged by R1 (hand-verified fixture)
        let tiny = CalibrationMetricsV1.eceAndBins(preds: [0.25, 0.25], labels: [true, false])
        XCTAssertEqual(tiny.ece, 0.25, accuracy: 1e-12)
        XCTAssertEqual(tiny.brier, (0.0625 + 0.5625) / 2, accuracy: 1e-12)
    }

    // ═════════ discipline artefacts — frozen originals byte-exact; manifests exist; inversions bounded ═════════

    func testR1_Discipline_FrozenOriginalsAndManifests() throws {
        // AUDIT10 frozen original byte-exact (SHA pre-declared in the inversion manifest)
        let frozen = try Data(contentsOf: URL(fileURLWithPath:
            repoRoot + "/docs/audit/AUDIT10_RealWorldCalibrationEntryGateProbes_ORIGINAL_LOCKED.swift.txt"))
        let sha = SHA256.hash(data: frozen).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(sha, "a1ffb855cea4af9b9ee83e88e9240982d4df31d5393dac2b5a668c597caf0580")
        // AUDIT9 frozen original untouched by R1
        let frozen9 = try Data(contentsOf: URL(fileURLWithPath:
            repoRoot + "/docs/audit/AUDIT9_P009ER1Probes_ORIGINAL_LOCKED.swift.txt"))
        let sha9 = SHA256.hash(data: frozen9).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(sha9, "a349a487dc091d444f04939864582175409542f47d6275c6bb0bd8022163bc4e")
        // manifests + lock/erratum/pointer artefacts exist
        for doc in ["docs/audit/AUDIT10_INVERSION_LOCK.md",
                    "docs/audit/AUDIT9_F3_INVERSION_LOCK.md",
                    "docs/audit/AUDIT9_FPEDGE_ERRATUM.md",
                    "docs/calibration/ENTRY_GATE_LOCK_NOTES.md"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: repoRoot + "/" + doc), doc)
        }
        // active AUDIT10 probe file carries the three declared FIXED inversions and none of the
        // retired pinned assertions (I-1/I-2/I-3 — exactly as pre-declared)
        let active = try String(contentsOfFile:
            repoRoot + "/packages/GuardianKit/Tests/GuardianCoreTests/AUDIT10_RealWorldCalibrationEntryGateProbes.swift",
            encoding: .utf8)
        let frozenSrc = String(decoding: frozen, as: UTF8.self)
        for marker in ["A10-F2-WIRING FIXED: the real fit path routes through the canonical integrity pipeline",
                       "A10-F2-MULTISET FIXED: [a,a,b] vs [a,b,b] refused",
                       "A10-F3-SIBLINGS FIXED: legacy auroc refuses invalid preds via nil marker"] {
            XCTAssertTrue(active.contains(marker), "declared inversion present: \(marker)")
            XCTAssertFalse(frozenSrc.contains(marker), "inversion absent from frozen original: \(marker)")
        }
        for retired in ["FINDING A10-F2-UNWIRED: if this now fails",
                        "guard currently ACCEPTS [a,a,b] vs [a,b,b]",
                        "auroc() swallows NaN via comparison semantics"] {
            XCTAssertFalse(active.contains(retired), "retired pin gone from active: \(retired)")
            XCTAssertTrue(frozenSrc.contains(retired), "retired pin preserved in frozen original: \(retired)")
        }
        // AUDIT9 active file untouched by R1: still differs from ITS frozen original by exactly the
        // single declared A9-R1-F3 hunk (same shape AUDIT10 P17 pins)
        let active9 = try String(contentsOfFile:
            repoRoot + "/packages/GuardianKit/Tests/GuardianCoreTests/AUDIT9_P009ER1Probes.swift", encoding: .utf8)
        let f9 = String(decoding: frozen9, as: UTF8.self).components(separatedBy: "\n")
        let a9 = active9.components(separatedBy: "\n")
        XCTAssertEqual(a9.count - f9.count, 2, "AUDIT9 single-hunk shape unchanged by R1 (net +2 lines)")
    }

    /// fp-edge truth is corrected in the LIVING sources and preserved-by-erratum in historical ones.
    func testR1_FPEdge_CorrectedInLivingSources() throws {
        XCTAssertEqual(Int(0.3 * 10.0), 3, "ground truth: 0.3*10 == exactly 3.0 → bin 3")
        let integritySrc = try String(contentsOfFile:
            repoRoot + "/packages/GuardianKit/Sources/GuardianCore/CalibrationIntegrityV1.swift", encoding: .utf8)
        XCTAssertTrue(integritySrc.contains("rounds UP to exactly 3.0"), "living doc-comment corrected")
        XCTAssertFalse(integritySrc.contains("rounds DOWN"), "false claim gone from the living source")
        let report = try String(contentsOfFile:
            repoRoot + "/docs/calibration/REAL_WORLD_CALIBRATION_ENTRY_GATE_IMPLEMENTATION_REPORT.md", encoding: .utf8)
        XCTAssertTrue(report.contains("CORRECTED per A10-F3-FPEDGE"), "implementation report corrected in place")
        let erratum = try String(contentsOfFile:
            repoRoot + "/docs/audit/AUDIT9_FPEDGE_ERRATUM.md", encoding: .utf8)
        XCTAssertTrue(erratum.contains("rounds DOWN in binary fp"), "original false wording preserved verbatim in the erratum")
    }

    // ═════════ locks — R1 changed none of them ═════════

    func testR1_LocksUnchanged() {
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0, "production score gate CLOSED")
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims,
                       "still zero PROJECT_OWNED_REAL/LICENSED items — no real-world claim possible")
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59, "no dataset growth — no fitting work happened")
    }
}
