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

    // ═══════════ R1 layers (A12-F2/F3/F4 closure): L2 refs · L3 requirements · L5-L8 state engine ═══════════

    private func reqMap() throws -> [String: Any] { try loadJSON("docs/control-plane/GEN8_REQUIREMENT_NODE_MAP.yaml") }
    private func aliasReg() throws -> [String: Any] { try loadJSON("docs/control-plane/GEN8_AUDIT_ALIAS_REGISTRY.yaml") }
    private func resolutionLedger() throws -> [String: Any] { try loadJSON("docs/control-plane/GEN8_RESOLUTION_LEDGER.yaml") }
    private func registryIDs() throws -> [String] {
        let reg = try String(contentsOfFile: repoRoot + "/docs/requirements/REQUIREMENTS_REGISTRY.yaml", encoding: .utf8)
        var out: [String] = []
        let regex = try NSRegularExpression(pattern: "\\n  - id: ([A-Z]+-\\d+)")
        for m in regex.matches(in: reg, range: NSRange(reg.startIndex..., in: reg)) {
            out.append(String(reg[Range(m.range(at: 1), in: reg)!]))
        }
        return out
    }
    private func gitTag(_ t: String) -> Bool {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", repoRoot, "rev-parse", "--verify", "--quiet", "refs/tags/" + t]
        p.standardOutput = Pipe(); p.standardError = Pipe()
        try? p.run(); p.waitUntilExit()
        return p.terminationStatus == 0
    }

    /// CP10 — L2: FULL machine-reference resolution (no hardcoded shortcut; A12-F3 root-cause fix).
    /// Every FILE/DIR/TAG/LEDGER-ANCHOR/AUDIT-ALIAS machine ref in twin + FM must resolve; commits
    /// resolve via a verified prefix set; semantic refs are allowed but never counted as machine.
    func testCP10_FullMachineReferenceResolution() throws {
        let t = try twin(); let f = try fm()
        let csv = try String(contentsOfFile: repoRoot + "/docs/audit/GEN8_CLAIM_EVIDENCE_LEDGER.csv", encoding: .utf8)
        let aliases = try XCTUnwrap((try aliasReg())["aliases"] as? [String: Any])
        var broken: [String] = []
        func check(_ ref: String, _ ctx: String) {
            let r = ref.trimmingCharacters(in: .whitespaces)
            if r.hasSuffix("/") {
                var isDir: ObjCBool = false
                let path = r.components(separatedBy: " ").first ?? r
                if !FileManager.default.fileExists(atPath: repoRoot + "/" + path, isDirectory: &isDir) || !isDir.boolValue { broken.append("\(ctx): dir \(r)") }
            } else if r.contains(".csv:") {
                let token = r.components(separatedBy: ".csv:")[1].components(separatedBy: " ")[0]
                if !csv.contains("\n\(token),") { broken.append("\(ctx): anchor \(token)") }
            } else if r.hasPrefix("docs/") && r.contains(".") && !r.contains(" ") {
                if !FileManager.default.fileExists(atPath: repoRoot + "/" + r) { broken.append("\(ctx): \(r)") }
            } else if r.hasPrefix("gen8-") {
                if !gitTag(r) { broken.append("\(ctx): tag \(r)") }
            } else if r.range(of: "^AUDIT\\d+$", options: .regularExpression) != nil {
                if aliases[r] == nil { broken.append("\(ctx): unregistered audit alias \(r)") }
            }
        }
        for n in try nodes(t) {
            let id = n["id"] as! String
            for r in ((n["implementation"] as? [String: Any])?["refs"] as? [String]) ?? [] { check(r, id) }
            for r in ((n["tests"] as? [String: Any])?["refs"] as? [String]) ?? [] { check(r, id) }
            for r in ((n["audit"] as? [String: Any])?["refs"] as? [String]) ?? [] { check(r, id) }
            for (_, v) in (n["evidence"] as? [String: Any]) ?? [:] { for r in (v as? [String]) ?? [] { check(r, id) } }
            let rb = (n["rollback"] as? [String: Any]) ?? [:]
            if let tag = rb["tag"] as? String, !tag.isEmpty {
                check(tag, id + ".rollback")
                XCTAssertEqual(rb["tag_status"] as? String, "EXISTS", "\(id): non-empty tag requires tag_status EXISTS")
            }
            if (rb["tag_status"] as? String) == "NEVER_CREATED" {
                XCTAssertEqual((rb["tag"] as? String) ?? "x", "", "\(id): NEVER_CREATED forbids a tag claim")
                XCTAssertFalse(((rb["commit"] as? String) ?? "").isEmpty, "\(id): rollback-by-commit anchor required")
            }
        }
        for s in (t["sources"] as? [[String: Any]]) ?? [] { check(s["path"] as! String, "sources") }
        for nt in (t["negative_truth"] as? [[String: Any]]) ?? [] { for e in (nt["evidence"] as? [String]) ?? [] { check(e, nt["id"] as! String) } }
        for r in (f["records"] as? [[String: Any]]) ?? [] { for e in (r["evidence"] as? [String]) ?? [] { check(e, r["id"] as! String) } }
        XCTAssertEqual(broken, [], "zero broken machine-resolvable refs (A12-F3 law)")
        // alias registry itself fully resolves
        for (alias, recAny) in aliases {
            let rec = try XCTUnwrap(recAny as? [String: Any])
            for k in ["report_path", "probe_path", "frozen_original", "inversion_lock"] {
                if let p = rec[k] as? String {
                    XCTAssertTrue(FileManager.default.fileExists(atPath: repoRoot + "/" + p), "\(alias).\(k): \(p)")
                }
            }
            XCTAssertFalse(((rec["verdict"] as? String) ?? "").isEmpty, "\(alias): verdict resolver required")
        }
    }

    /// CP11 — L3: requirement completeness law. registry IDs == mapped IDs (except explicit
    /// DEFER/SUPERSEDED); owners exist; node requirement IDs validate GENERICALLY against the registry.
    func testCP11_RequirementCompletenessLaw() throws {
        let reg = Set(try registryIDs())
        XCTAssertEqual(reg.count, 36)
        let m = try reqMap()
        let recs = try XCTUnwrap(m["records"] as? [[String: Any]])
        let mapped = Set(recs.map { $0["requirement_id"] as! String })
        let deferred = Set(recs.filter { ($0["disposition"] as! String) == "EXPLICIT_DEFER" }.map { $0["requirement_id"] as! String })
        let superseded = Set(recs.filter { ($0["disposition"] as! String) == "SUPERSEDED" }.map { $0["requirement_id"] as! String })
        XCTAssertEqual(reg, mapped, "registry requirement IDs == mapped IDs — NO invisible orphan")
        let ns = try nodes(try twin())
        let nodeIDs = Set(ns.map { $0["id"] as! String })
        var twinUsed = Set<String>()
        for n in ns {
            for r in (n["requirements"] as? [String]) ?? [] {
                XCTAssertTrue(reg.contains(r), "\(n["id"]!): requirement \(r) not in registry (generic law)")
                twinUsed.insert(r)
            }
        }
        for rec in recs {
            let rid = rec["requirement_id"] as! String
            let dispo = rec["disposition"] as! String
            XCTAssertTrue(["MAP_EXISTING_NODE", "CREATE_MISSING_NODE", "EXPLICIT_DEFER", "SUPERSEDED"].contains(dispo))
            if dispo == "EXPLICIT_DEFER" {
                XCTAssertFalse(((rec["reason"] as? String) ?? "").isEmpty, "\(rid): DEFER requires reason")
                XCTAssertNotNil(rec["deferred_until"] as? String, "\(rid): DEFER requires deferred_until")
                XCTAssertEqual(rec["release_blocking"] as? Bool, false,
                               "\(rid): a release-blocking requirement may never be silently deferred")
            } else if dispo != "SUPERSEDED" {
                let owners = (rec["owner_nodes"] as? [String]) ?? []
                XCTAssertFalse(owners.isEmpty, "\(rid): owner required")
                for o in owners { XCTAssertTrue(nodeIDs.contains(o), "\(rid): owner \(o) not a twin node") }
                XCTAssertTrue(owners.contains(rec["primary_owner"] as! String), "\(rid): primary owner in owners")
                XCTAssertTrue(twinUsed.contains(rid), "\(rid): mapped requirement must appear on >=1 twin node")
                let primary = ns.first { ($0["id"] as! String) == (rec["primary_owner"] as! String) }!
                XCTAssertNotEqual(primary["status"] as! String, "RETIRED",
                                  "\(rid): release-relevant requirement mapped only to RETIRED node")
            }
        }
        XCTAssertEqual(reg.subtracting(twinUsed).subtracting(deferred).subtracting(superseded), [],
                       "every non-deferred requirement is bound to at least one twin node")
    }

    /// CP12 — L5: typed contracts cover the graph exactly; computed readiness == declared status;
    /// blocked_by legacy-mirror law; no generic ACTIVE rule anywhere.
    func testCP12_TypedContractsAndComputedReadiness() throws {
        let t = try twin()
        let ns = try nodes(t)
        let contracts = try XCTUnwrap(t["dependency_contracts"] as? [String: [[String: Any]]])
        let gates = (t["gates"] as? [String: [String]]) ?? [:]
        for n in ns {
            let id = n["id"] as! String
            let deps = (n["depends_on"] as? [String]) ?? []
            let cl = contracts[id] ?? []
            XCTAssertEqual(Set(cl.map { $0["node"] as! String }), Set(deps), "\(id): contract per edge, exactly")
            for c in cl {
                let req = c["requires"] as! String
                XCTAssertTrue(["LOCKED", "GATE_PASS", "CANDIDATE_READY"].contains(req), "\(id): typed requires")
                if req == "CANDIDATE_READY" {
                    XCTAssertEqual(id, "CP-INDEPENDENT-AUDIT", "CANDIDATE_READY is a single declared edge — no global exception")
                }
            }
            // legacy mirror law (deprecated field, byte-stable for frozen AUDIT12 probes): every
            // blocked_by entry must appear in the canonical registries; gates MAY exceed the mirror
            // (new structural gates land ONLY in gates[] — e.g. EP3-CONTENT-AHEAD's CP-audit gate,
            // which was prose-only at 4d6649c).
            let blockedBy = Set((n["blocked_by"] as? [String]) ?? [])
            for e in blockedBy {
                if e.hasPrefix("BLK-") { continue }
                XCTAssertTrue((gates[id] ?? []).contains(e), "\(id): legacy mirror node-gate \(e) missing from canonical gates[]")
            }
        }
        // computed readiness is authoritative and equals declared state
        let computed = ControlPlaneStateEvaluatorV1.computedReady(twin: t, requirementMap: try reqMap())
        let declared = Set(ns.filter { ($0["status"] as! String) == "READY" }.map { $0["id"] as! String })
        XCTAssertEqual(computed, declared, "computed readiness must equal declared READY set")
        XCTAssertEqual(computed, ["CP-INDEPENDENT-AUDIT"])
    }

    /// CP13 — L6: axis-specific evidence adequacy on the LIVE twin (axis-blind checks abolished).
    func testCP13_AxisSpecificEvidenceAdequacy() throws {
        XCTAssertEqual(ControlPlaneStateEvaluatorV1.axisEvidenceViolations(twin: try twin()), [])
    }

    /// CP14 — L9: census vanish-pins — COMPLETE blocker + negative-truth ID sets; removal lawful only
    /// via a resolution-ledger record (registry-driven with ledger escape; no partial famous-only list).
    func testCP14_CompleteVanishPins() throws {
        let t = try twin()
        let ledger = try resolutionLedger()
        let resolvedSubjects = ((ledger["records"] as? [[String: Any]]) ?? []).map { ($0["subject"] as? String) ?? "" }.joined(separator: " | ")
        let pinnedBlockers = ["BLK-B1", "BLK-B2", "BLK-C1", "BLK-C2", "BLK-C3", "BLK-C4", "BLK-C5", "BLK-C6",
                              "BLK-H1", "BLK-H2", "BLK-H3", "BLK-H4", "BLK-H5", "BLK-ECE-UNMET",
                              "BLK-DEVICE-RWC-OPEN", "BLK-A10-F1-COVERAGE", "BLK-A10-F1-FALSETRIGGER",
                              "BLK-A11-IDCHARSET", "BLK-A11-COMPOSITE-ALIAS", "BLK-A11-LEGACY-P008",
                              "BLK-A11-APIBYPASS", "BLK-GH-CREDENTIALS"]
        let present = Set(((t["blockers"] as? [[String: Any]]) ?? []).map { $0["id"] as! String })
        for id in pinnedBlockers where !present.contains(id) {
            XCTAssertTrue(resolvedSubjects.contains(id), "blocker \(id) vanished WITHOUT a resolution-ledger record")
        }
        XCTAssertEqual(present.count, 22)
        let pinnedNTs = ["NT-TIER0-GROUPING", "NT-C6-LOADBEARING", "NT-PREVDWELL", "NT-THERMAL-EVIDENCE-BUILD",
                         "NT-P008-PILOT-FAILED", "NT-ECE-UNMET", "NT-F1-COVERAGE", "NT-APIBYPASS", "NT-DEVICE-RWC"]
        let ntPresent = Set(((t["negative_truth"] as? [[String: Any]]) ?? []).map { $0["id"] as! String })
        for id in pinnedNTs where !ntPresent.contains(id) {
            XCTAssertTrue(resolvedSubjects.contains(id), "negative truth \(id) vanished WITHOUT a resolution-ledger record")
        }
        XCTAssertEqual(ntPresent.count, 9)
    }

    /// CP15 — L7/L8: transition + authority + verdict-coherence laws on the LIVE twin.
    func testCP15_TransitionAuthorityCoherenceLaws() throws {
        let t = try twin()
        let auth = try loadJSON("docs/control-plane/GEN8_EVIDENCE_AUTHORITY.yaml")
        let domains = try XCTUnwrap(auth["domains"] as? [String: Any])
        for d in ["functional", "real_device", "calibration", "privacy", "security",
                  "resource_performance", "human_product", "history"] {
            XCTAssertNotNil(domains[d], "authority matrix domain missing: \(d)")
        }
        for n in try nodes(t) {
            XCTAssertTrue(ControlPlaneStateEvaluatorV1.verdictStatusCoherent(node: n, hasResolutionRecord: false),
                          "\(n["id"]!): FAIL/FIX verdict under LOCKED without resolution")
            // CONTRADICTED axes may not coexist with a verified-class value on the same axis elsewhere
            // in this node (single-axis law) and may only change via resolution (checked by mutation
            // tests in ControlPlaneR1RemediationTests using legalAxisTransition).
        }
        // domain-aware law anchors: device evidence cannot upgrade privacy; synthetic cannot upgrade calibration
        let dev = try XCTUnwrap(domains["privacy"] as? [String: Any])
        XCTAssertTrue(((dev["can_never_upgrade"] as? [String]) ?? []).contains("MEASURED_REAL_DEVICE"))
        let cal = try XCTUnwrap(domains["calibration"] as? [String: Any])
        XCTAssertTrue(((cal["can_never_upgrade"] as? [String]) ?? []).contains("LAB_BENCHMARK"))
    }

    /// CP16 — forbidden-future-state law via the EVALUATOR (not hardcoded equality alone): under the
    /// typed law, PRE-14 merely ACTIVE can never unlock corpus; Presentation is never READY while the
    /// production score gate is CLOSED in code.
    func testCP16_EvaluatorForbiddenStates() throws {
        let t = try twin()
        // live: corpus not ready
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.computedReady(twin: t).contains("RWC-CORPUS"))
        // simulated full preregistration EXCEPT the audit gate: corpus still not ready
        var passed: Set<String> = ["CP-INDEPENDENT-AUDIT", "CP-CONTROL-PLANE"]
        passed.formUnion((1...13).map { String(format: "RWC-PRE-%02d", $0) })
        let readyNoGate = ControlPlaneStateEvaluatorV1.computedReady(twin: t, passed: passed)
        XCTAssertTrue(readyNoGate.contains("RWC-PRE-14"), "PRE-14 unlocks when all thirteen lanes passed")
        XCTAssertFalse(readyNoGate.contains("RWC-CORPUS"), "corpus NEVER unlocks before PRE-14 PASS (typed GATE_PASS)")
        // with PRE-14 passed, corpus may become ready
        XCTAssertTrue(ControlPlaneStateEvaluatorV1.computedReady(twin: t, passed: passed.union(["RWC-PRE-14"])).contains("RWC-CORPUS"))
        // Presentation: gated by held-out + device E2E; and code gate must be CLOSED today
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0)
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.computedReady(twin: t, passed: passed.union(["RWC-PRE-14", "RWC-CORPUS", "RWC-ANNOTATION", "RWC-FIT"])).contains("EP3-PRESENTATION"),
                       "Presentation never READY without held-out + device E2E PASS")
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
