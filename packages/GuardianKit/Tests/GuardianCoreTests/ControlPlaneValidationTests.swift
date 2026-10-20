import XCTest
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// ULU EVREN CONTROL PLANE — deterministic machine validation (mandate §19/§30).
// Canonical files are STRICT-JSON-subset-of-YAML (schema §1) so this suite validates them with
// zero new dependencies on every run. The twin/DAG are DATA; the forbidden-state laws below also
// cross-check data claims against CODE truth (gates) so the graph can never drift green.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class ControlPlaneValidationTests: XCTestCase {

    private var repoRoot: String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }
    private func loadJSON(_ rel: String) throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + rel))
        let obj = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(obj as? [String: Any], "\(rel): top level must be an object")
    }
    private func twin() throws -> [String: Any] { try loadJSON("docs/control-plane/GEN8_PROJECT_TWIN.yaml") }
    private func dag() throws -> [String: Any] { try loadJSON("docs/control-plane/GEN8_ULU_EVREN_MASTER_EXECUTION_DAG.yaml") }
    private func fm() throws -> [String: Any] { try loadJSON("docs/control-plane/GEN8_ENGINEERING_FAILURE_MEMORY.yaml") }
    private func nodes(_ t: [String: Any]) throws -> [[String: Any]] { try XCTUnwrap(t["nodes"] as? [[String: Any]]) }

    private let taxonomy: Set<String> = ["VERIFIED", "VERIFIED_WITH_LIMITATIONS", "PLAUSIBLE_NOT_PROVEN",
                                         "LAB_ONLY", "UNVERIFIED", "UNAVAILABLE", "CONTRADICTED", "OPEN", "BLOCKED"]
    private let statuses: Set<String> = ["LOCKED", "ACTIVE", "READY", "BLOCKED", "PLANNED", "RETIRED"]
    private let axes = ["overall", "functional", "calibration", "real_device", "privacy", "security",
                        "resource_performance", "human_product"]

    // ── schema: parseable, IDs unique, statuses/taxonomy valid, 7 axes present ──
    func testCP01_SchemaAndTaxonomy() throws {
        let t = try twin()
        let ns = try nodes(t)
        XCTAssertGreaterThanOrEqual(ns.count, 40, "twin must map the full remaining program")
        var seen = Set<String>()
        for n in ns {
            let id = try XCTUnwrap(n["id"] as? String)
            XCTAssertTrue(seen.insert(id).inserted, "duplicate node ID: \(id)")
            XCTAssertTrue(statuses.contains(try XCTUnwrap(n["status"] as? String)), "\(id): invalid status")
            let truth = try XCTUnwrap(n["truth"] as? [String: Any], "\(id): truth missing")
            for a in axes {
                let v = try XCTUnwrap(truth[a] as? String, "\(id): axis \(a) missing — axes may never be collapsed")
                XCTAssertTrue(taxonomy.contains(v), "\(id).truth.\(a) = \(v) not in taxonomy")
            }
            for forbidden in ["DONE", "COMPLETE", "PRODUCTION_READY"] {
                XCTAssertFalse((truth.values.compactMap { $0 as? String }).contains(forbidden),
                               "\(id): forbidden pseudo-truth \(forbidden)")
            }
        }
        // declared taxonomy in the file matches the binding one
        XCTAssertEqual(Set(try XCTUnwrap(t["truth_taxonomy"] as? [String])), taxonomy)
    }

    // ── graph: dependency refs valid, blocks symmetry, DAG acyclic ──
    func testCP02_GraphRefsAndAcyclicity() throws {
        let ns = try nodes(try twin())
        let ids = Set(ns.map { $0["id"] as! String })
        var deps: [String: [String]] = [:]
        for n in ns {
            let id = n["id"] as! String
            let d = (n["depends_on"] as? [String]) ?? []
            deps[id] = d
            for x in d { XCTAssertTrue(ids.contains(x), "\(id): unknown dependency \(x)") }
            for b in (n["blocks"] as? [String]) ?? [] {
                XCTAssertTrue(ids.contains(b), "\(id): unknown blocks target \(b)")
                let target = ns.first { ($0["id"] as! String) == b }!
                let tDeps = Set(((target["depends_on"] as? [String]) ?? []) + ((target["blocked_by"] as? [String]) ?? []))
                XCTAssertTrue(tDeps.contains(id), "blocks/depends asymmetry: \(id) blocks \(b) but \(b) does not reference \(id)")
            }
        }
        // cycle detection (DFS, 3-color)
        var color: [String: Int] = [:]
        func visit(_ u: String) -> Bool {              // true = cycle
            if color[u] == 1 { return true }
            if color[u] == 2 { return false }
            color[u] = 1
            for v in deps[u] ?? [] where visit(v) { return true }
            color[u] = 2
            return false
        }
        for id in ids { XCTAssertFalse(visit(id), "dependency cycle through \(id)") }
    }

    // ── blockers: registry valid, node blocker refs resolve, BLOCKED nodes carry reasons ──
    func testCP03_BlockerIntegrity() throws {
        let t = try twin()
        let ns = try nodes(t)
        let reg = try XCTUnwrap(t["blockers"] as? [[String: Any]])
        let blkIDs = Set(reg.map { $0["id"] as! String })
        let nodeIDs = Set(ns.map { $0["id"] as! String })
        for b in reg {
            XCTAssertFalse((b["title"] as! String).isEmpty)
            XCTAssertFalse((b["status"] as! String).isEmpty)
            XCTAssertFalse((b["currency_note"] as! String).isEmpty, "\(b["id"]!): staleness/currency must be explicit")
        }
        for n in ns {
            let id = n["id"] as! String
            for b in (n["blockers"] as? [String]) ?? [] {
                XCTAssertTrue(blkIDs.contains(b), "\(id): unknown blocker ref \(b)")
            }
            if (n["status"] as! String) == "BLOCKED" {
                let reasons = ((n["blocked_by"] as? [String]) ?? []) + ((n["blockers"] as? [String]) ?? [])
                XCTAssertFalse(reasons.isEmpty, "\(id): BLOCKED without a blocker reason")
                for r in (n["blocked_by"] as? [String]) ?? [] {
                    XCTAssertTrue(blkIDs.contains(r) || nodeIDs.contains(r), "\(id): blocked_by \(r) resolves to nothing")
                }
            }
        }
        // carried findings may never vanish
        for required in ["BLK-A10-F1-COVERAGE", "BLK-A11-APIBYPASS", "BLK-A11-IDCHARSET",
                         "BLK-A11-COMPOSITE-ALIAS", "BLK-A11-LEGACY-P008", "BLK-ECE-UNMET",
                         "BLK-DEVICE-RWC-OPEN", "BLK-C6", "BLK-B1"] {
            XCTAssertTrue(blkIDs.contains(required), "carried blocker vanished from registry: \(required)")
        }
    }

    // ── READY law: deps satisfied; no BLOCKED node READY; deterministic single next action ──
    func testCP04_ReadyLawAndNextActionDeterminism() throws {
        let t = try twin()
        let ns = try nodes(t)
        let byID = Dictionary(uniqueKeysWithValues: ns.map { ($0["id"] as! String, $0) })
        let ready = ns.filter { ($0["status"] as! String) == "READY" }.map { $0["id"] as! String }
        for id in ready {
            for d in (byID[id]!["depends_on"] as? [String]) ?? [] {
                let s = byID[d]!["status"] as! String
                XCTAssertTrue(s == "LOCKED" || s == "ACTIVE",
                              "READY node \(id) has unsatisfied hard dependency \(d) (status \(s))")
            }
            XCTAssertTrue(((byID[id]!["blocked_by"] as? [String]) ?? []).isEmpty, "READY node \(id) is also blocked")
        }
        XCTAssertEqual(ready, ["CP-INDEPENDENT-AUDIT"],
                       "the next-action engine must resolve deterministically to the control-plane audit")
        let d = try dag()
        let na = try XCTUnwrap(d["current_next_action"] as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(na["ready_nodes"] as? [String]), ready, "DAG next-action must equal twin READY set")
    }

    // ── forbidden states: graph claims cross-checked against CODE truth ──
    func testCP05_ForbiddenStates_GraphAndCodeAgree() throws {
        let ns = try nodes(try twin())
        let byID = Dictionary(uniqueKeysWithValues: ns.map { ($0["id"] as! String, $0) })
        // no Presentation unlock — in the graph AND in code
        XCTAssertEqual(byID["EP3-PRESENTATION"]!["status"] as! String, "BLOCKED")
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0, "code truth: production score gate must be CLOSED")
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed(), "code truth: display structurally OFF")
        // no corpus acquisition READY before preregistration audit
        XCTAssertEqual(byID["RWC-CORPUS"]!["status"] as! String, "BLOCKED")
        XCTAssertTrue((byID["RWC-CORPUS"]!["blocked_by"] as! [String]).contains("RWC-PRE-14"))
        // every RWC-PRE node gated behind the control-plane audit
        for i in 1...13 {
            let id = String(format: "RWC-PRE-%02d", i)
            XCTAssertEqual(byID[id]!["status"] as! String, "BLOCKED", "\(id) must stay blocked until CP audit PASS")
        }
        // engineering-only class still true in code (claim ceiling)
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims,
                       "code truth: no real/licensed items — twin may not claim real-world calibration anywhere")
        for n in ns {
            XCTAssertNotEqual((n["truth"] as! [String: Any])["calibration"] as! String, "VERIFIED",
                              "\(n["id"]!): calibration axis can never be VERIFIED before the RWC program (FM-012)")
        }
    }

    // ── negative truth preserved: contradictions and open facts cannot be cleaned up ──
    func testCP06_NegativeTruthPreserved() throws {
        let t = try twin()
        let nts = try XCTUnwrap(t["negative_truth"] as? [[String: Any]])
        let byID = Dictionary(uniqueKeysWithValues: nts.map { ($0["id"] as! String, $0["fact"] as! String) })
        XCTAssertTrue(try XCTUnwrap(byID["NT-TIER0-GROUPING"]).contains("CONTRADICTED"),
                      "historical Tier-0 contradiction must stay recorded")
        XCTAssertTrue(try XCTUnwrap(byID["NT-ECE-UNMET"]).contains("UNMET"), "ECE .250 unmet preserved")
        XCTAssertTrue(try XCTUnwrap(byID["NT-F1-COVERAGE"]).contains("NOT validated"), "F1 limitation preserved")
        XCTAssertTrue(try XCTUnwrap(byID["NT-DEVICE-RWC"]).contains("OPEN"), "physical-device truth stays OPEN")
        XCTAssertNotNil(byID["NT-C6-LOADBEARING"]); XCTAssertNotNil(byID["NT-P008-PILOT-FAILED"])
        XCTAssertNotNil(byID["NT-APIBYPASS"]); XCTAssertNotNil(byID["NT-THERMAL-EVIDENCE-BUILD"])
        // P008 node carries the contradiction on its calibration axis — never upgraded silently
        let ns = try nodes(t)
        let p008 = ns.first { ($0["id"] as! String) == "P008-CALIBRATION-PILOT" }!
        XCTAssertEqual((p008["truth"] as! [String: Any])["calibration"] as! String, "CONTRADICTED")
    }

    // ── evidence law: VERIFIED-class truth requires evidence refs; AUDIT11 lock referenced ──
    func testCP07_EvidenceRefsAndAudit11Lock() throws {
        let ns = try nodes(try twin())
        for n in ns {
            let truth = (n["truth"] as! [String: Any]).values.compactMap { $0 as? String }
            let hasVerifiedClass = truth.contains("VERIFIED") || truth.contains("VERIFIED_WITH_LIMITATIONS")
            if hasVerifiedClass {
                let e = n["evidence"] as! [String: Any]
                let total = e.values.compactMap { $0 as? [String] }.map { $0.count }.reduce(0, +)
                XCTAssertGreaterThan(total, 0, "\(n["id"]!): verified-class truth without any evidence ref")
            }
        }
        let gate = ns.first { ($0["id"] as! String) == "RWC-ENTRY-GATE" }!
        let auditRefs = ((gate["evidence"] as! [String: Any])["audit_refs"] as! [String]).joined()
        XCTAssertTrue(auditRefs.contains("AUDIT11"), "AUDIT11 engineering lock must be referenced")
        XCTAssertEqual((gate["rollback"] as! [String: Any])["tag"] as! String, "gen8-rwc-entry-gate-r1-locked-engineering")
        // evidence artefacts the twin points at actually exist on disk
        for rel in ["docs/canonical/RWC_ENTRY_GATE_R1_ENGINEERING_LOCK.md",
                    "docs/audit/GEN8_RWC_ENTRY_GATE_R1_INDEPENDENT_REAUDIT.md",
                    "docs/audit/AUDIT10_INVERSION_LOCK.md",
                    "docs/audit/AUDIT9_F3_INVERSION_LOCK.md",
                    "docs/calibration/REAL_WORLD_CALIBRATION_CONSTITUTION_v1.md"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: repoRoot + "/" + rel), "stale evidence ref: \(rel)")
        }
    }

    // ── failure memory: all seeded records present, refs resolve both ways ──
    func testCP08_FailureMemoryIntegrity() throws {
        let f = try fm()
        let recs = try XCTUnwrap(f["records"] as? [[String: Any]])
        let fmIDs = Set(recs.map { $0["id"] as! String })
        for i in 1...14 {
            XCTAssertTrue(fmIDs.contains(String(format: "FM-%03d", i)), "seed failure memory FM-\(i) missing")
        }
        for r in recs {
            for k in ["failure", "first_seen", "root_cause", "invariant", "status"] {
                XCTAssertFalse((r[k] as! String).isEmpty, "\(r["id"]!): \(k) empty")
            }
            XCTAssertFalse((r["evidence"] as! [String]).isEmpty, "\(r["id"]!): failure memory without evidence")
        }
        for n in try nodes(try twin()) {
            for ref in (n["failure_memory_refs"] as? [String]) ?? [] {
                XCTAssertTrue(fmIDs.contains(ref), "\(n["id"]!): unknown FM ref \(ref)")
            }
        }
    }

    // ── DAG/twin consistency: mapping IDs resolve; wave order never inverts; epochs complete ──
    func testCP09_DagTwinConsistency() throws {
        let t = try twin(); let d = try dag()
        let ids = Set(try nodes(t).map { $0["id"] as! String })
        for m in try XCTUnwrap(d["phase_mapping"] as? [[String: Any]]) {
            for nid in m["dag_nodes"] as! [String] {
                XCTAssertTrue(ids.contains(nid), "DAG mapping references unknown twin node \(nid)")
            }
        }
        let epochs = (d["epochs"] as! [[String: Any]]).map { $0["id"] as! String }
        XCTAssertEqual(epochs, ["EPOCH_I", "EPOCH_II", "EPOCH_III", "EPOCH_IV", "EPOCH_V", "EPOCH_VI", "EPOCH_VII", "EPOCH_VIII"])
        let waves = (d["release_waves"] as! [[String: Any]]).map { $0["id"] as! String }
        XCTAssertEqual(waves, ["W0", "W1", "W2", "W3"], "release wave order may never invert")
        for n in try nodes(t) {
            let e = n["epoch"] as! String
            XCTAssertTrue(epochs.contains(e) || e == "META", "\(n["id"]!): unknown epoch \(e)")
            if let w = (n["release"] as! [String: Any])["wave"] as? String {
                XCTAssertTrue(waves.contains(w), "\(n["id"]!): unknown wave \(w)")
            }
        }
    }
}
