import XCTest
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// GOVERNING LOCK — closeout verification (additive). Proves the post-lock overlay is consistent,
// the A13-F1 correction is exact, frozen evidence is intact, and every hard lock still holds.
// The candidate snapshot (nodes[], current_next_action) stays byte-pinned by frozen AUDIT12/13 probes;
// the canonical post-lock state lives in the ADDITIVE governing_lock overlay (schema law).
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class ControlPlaneGoverningLockTests: XCTestCase {

    private var repoRoot: String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }
    private func load(_ rel: String) throws -> [String: Any] {
        let d = try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + rel))
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: d) as? [String: Any])
    }

    func testGL1_OverlayConsistent_EffectiveReadinessMachineDerived() throws {
        let t = try load("docs/control-plane/GEN8_PROJECT_TWIN.yaml")
        let gl = try XCTUnwrap(t["governing_lock"] as? [String: Any])
        XCTAssertEqual(gl["locked"] as? Bool, true)
        XCTAssertEqual(gl["audit"] as? String, "AUDIT13")
        XCTAssertEqual(gl["candidate"] as? String, "12300e66723d92cbfcafc6368cb1372ba3e1604f")
        XCTAssertEqual(gl["audit_commit"] as? String, "f72e9adfd197e457fef02c3226d2ab8e5dae4e1a")
        // the recorded work-ready set MUST equal the evaluator's machine computation with the overlay's
        // effective_passed — the exact path AUDIT13 exercised. No hand-typed divergence allowed.
        let passed = Set(try XCTUnwrap(gl["effective_passed"] as? [String]))
        XCTAssertEqual(passed, ["CP-CONTROL-PLANE", "CP-INDEPENDENT-AUDIT"])
        let computed = ControlPlaneStateEvaluatorV1.computedReady(twin: t, passed: passed)
        XCTAssertEqual(computed, Set(try XCTUnwrap(gl["computed_work_ready"] as? [String])),
                       "overlay work-ready set must be machine-derived, not hand-typed")
        XCTAssertEqual(computed, ["RWC-PRE-01", "RWC-PRE-02", "RWC-PRE-03", "RWC-PRE-04", "RWC-PRE-05",
                                  "RWC-PRE-13", "EP3-CONTENT-AHEAD"])
        // snapshot untouched: live (no-overlay) readiness still the pinned candidate truth
        XCTAssertEqual(ControlPlaneStateEvaluatorV1.computedReady(twin: t), ["CP-INDEPENDENT-AUDIT"])
        // corpus/presentation never in the post-lock work-ready set
        XCTAssertFalse(computed.contains("RWC-CORPUS")); XCTAssertFalse(computed.contains("EP3-PRESENTATION"))
        // authorized program is exactly one, and distinct from the work-ready set
        XCTAssertEqual(gl["authorized_program"] as? String, "RWC PREREGISTRATION PREPARATION")
        // overlay CP states: LOCKED/PASS with AUDIT13 refs; privacy/security NOT auto-upgraded
        let ov = try XCTUnwrap(gl["cp_state_overlay"] as? [String: Any])
        let cp = try XCTUnwrap(ov["CP-CONTROL-PLANE"] as? [String: Any])
        XCTAssertEqual(cp["status"] as? String, "LOCKED")
        XCTAssertTrue(((cp["audit_refs"] as? [String]) ?? []).contains("AUDIT13"))
        let truth = try XCTUnwrap(cp["truth_overlay"] as? [String: Any])
        XCTAssertEqual(truth["overall"] as? String, "VERIFIED_WITH_LIMITATIONS")
        XCTAssertEqual(truth["privacy"] as? String, "LAB_ONLY", "axis discipline: no convenience upgrade")
        XCTAssertEqual(truth["security"] as? String, "LAB_ONLY")
        let audit = try XCTUnwrap(ov["CP-INDEPENDENT-AUDIT"] as? [String: Any])
        XCTAssertEqual(audit["status"] as? String, "LOCKED")
        XCTAssertTrue((audit["history_note"] as? String ?? "").contains("AUDIT12 FIX"),
                      "the FIX generation is preserved in the lineage, never erased")
    }

    func testGL2_AliasTruthAndLedger_A13F1Fixed() throws {
        let a = try XCTUnwrap((try load("docs/control-plane/GEN8_AUDIT_ALIAS_REGISTRY.yaml"))["aliases"] as? [String: [String: Any]])
        XCTAssertEqual(a["AUDIT3"]?["verdict"] as? String, "FIX CRITICAL P009B FINDINGS")
        XCTAssertEqual(a["AUDIT3"]?["superseded_by"] as? String, "AUDIT4")
        XCTAssertEqual(a["AUDIT5"]?["verdict"] as? String, "FIX CRITICAL P009C FINDINGS")
        XCTAssertEqual(a["AUDIT5"]?["superseded_by"] as? String, "AUDIT6")
        let v13 = try XCTUnwrap(a["AUDIT13"]?["verdict"] as? String)
        XCTAssertTrue(v13.hasPrefix("PASS — ULU EVREN CONTROL PLANE R1 LOCKABLE"))
        // registry verdict text appears verbatim in the AUDIT13 report (exact-match law)
        let report = try String(contentsOfFile: repoRoot + "/docs/audit/GEN8_ULU_EVREN_CONTROL_PLANE_R1_INDEPENDENT_REAUDIT.md", encoding: .utf8)
        XCTAssertTrue(report.contains("PASS — ULU EVREN CONTROL PLANE R1 LOCKABLE"))
        // RES-006 exists; historical AUDIT3/AUDIT5 reports untouched (their FIX verdict lines intact)
        let ledger = try load("docs/control-plane/GEN8_RESOLUTION_LEDGER.yaml")
        let ids = ((ledger["records"] as? [[String: Any]]) ?? []).compactMap { $0["id"] as? String }
        XCTAssertTrue(ids.contains("RES-006"))
        XCTAssertTrue(try String(contentsOfFile: repoRoot + "/docs/audit/GEN8_P009B_INDEPENDENT_AUDIT_REPORT.md", encoding: .utf8).contains("FIX CRITICAL P009B FINDINGS"))
        XCTAssertTrue(try String(contentsOfFile: repoRoot + "/docs/audit/GEN8_P009C_INDEPENDENT_AUDIT_REPORT.md", encoding: .utf8).contains("FIX CRITICAL P009C FINDINGS"))
    }

    func testGL3_FrozenEvidenceIntactAndHardLocksHold() throws {
        func sha(_ rel: String) throws -> String {
            let d = try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + rel))
            return SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
        }
        XCTAssertEqual(try sha("docs/audit/AUDIT13_ControlPlaneR1ReauditProbes_ORIGINAL_LOCKED.swift.txt"),
                       "be8384cc60efe38b297518f56454f900a44a980836b004a9b40792c7572b097f")
        XCTAssertEqual(try sha("docs/audit/AUDIT12_UluEvrenControlPlaneProbes_ORIGINAL_LOCKED.swift.txt"),
                       "4671898b38159721b6bbd29d6c77c1715623175cbea8554e747a3fc0b8a24a20")
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoRoot + "/docs/canonical/GEN8_ULU_EVREN_CONTROL_PLANE_R1_LOCK.md"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoRoot + "/docs/audit/AUDIT13_INVERSION_LOCK.md"))
        // hard locks in CODE — the governing index can never override these
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims)
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59, "no corpus, no dataset growth")
        // DAG post-lock section consistent with the twin overlay
        let d = try load("docs/control-plane/GEN8_ULU_EVREN_MASTER_EXECUTION_DAG.yaml")
        let pl = try XCTUnwrap(d["post_lock_next_action"] as? [String: Any])
        XCTAssertEqual(Set(try XCTUnwrap(pl["work_ready_nodes"] as? [String])),
                       Set(try XCTUnwrap(((try load("docs/control-plane/GEN8_PROJECT_TWIN.yaml"))["governing_lock"] as? [String: Any])?["computed_work_ready"] as? [String])))
        XCTAssertEqual(pl["authorized_program"] as? String, "RWC PREREGISTRATION PREPARATION")
    }
}
