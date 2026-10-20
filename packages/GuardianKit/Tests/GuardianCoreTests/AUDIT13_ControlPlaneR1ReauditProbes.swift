import XCTest
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT13 — INDEPENDENT CONTROL-PLANE R1 RE-AUDIT PROBES (clean session, add-only).
// Target candidate: 12300e66723d92cbfcafc6368cb1372ba3e1604f
//                   (tag gen8-ulu-evren-control-plane-r1-audit-candidate, object fef8f54c…).
// Baseline audited against AUDIT12 verdict commit b0039eb7f75de9bcdb3432b41b3b22933955cd1a.
//
// LAW OF THIS FAMILY: nothing here copies the builder's R1 tests. Every readiness/census/
// completeness/vanish law exercised below is EITHER an independent reimplementation (struct
// A13Engine / A13Census / the A13 law functions) OR a direct adversarial exercise of the builder's
// evaluator against in-memory mutated deep copies. Probes are GREEN against the candidate AS-IS;
// defects found by this audit are PINNED as assertions of CURRENT truth (A13-F1…A13-F8) so they can
// never silently vanish. Mutation tests never touch canonical files (deep copies only).
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT13_ControlPlaneR1ReauditProbes: XCTestCase {

    // ── plumbing ──
    private var repoRoot: String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }
    private func text(_ rel: String) throws -> String {
        try String(contentsOfFile: repoRoot + "/" + rel, encoding: .utf8)
    }
    private func exists(_ rel: String) -> Bool {
        FileManager.default.fileExists(atPath: repoRoot + "/" + rel)
    }
    private func json(_ rel: String) throws -> [String: Any] {
        let d = try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + rel))
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: d) as? [String: Any], "\(rel): strict JSON")
    }
    private func twin() throws -> [String: Any] { try json("docs/control-plane/GEN8_PROJECT_TWIN.yaml") }
    private func reqMap() throws -> [String: Any] { try json("docs/control-plane/GEN8_REQUIREMENT_NODE_MAP.yaml") }
    private func aliases() throws -> [String: [String: Any]] {
        try XCTUnwrap((try json("docs/control-plane/GEN8_AUDIT_ALIAS_REGISTRY.yaml"))["aliases"] as? [String: [String: Any]])
    }
    private func ledger() throws -> [String: Any] { try json("docs/control-plane/GEN8_RESOLUTION_LEDGER.yaml") }
    private func deepCopy(_ t: [String: Any]) throws -> [String: Any] {
        let d = try JSONSerialization.data(withJSONObject: t)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: d) as? [String: Any])
    }
    private func mutated(_ t: [String: Any], node id: String, _ f: (inout [String: Any]) -> Void) throws -> [String: Any] {
        var c = try deepCopy(t)
        var ns = try XCTUnwrap(c["nodes"] as? [[String: Any]])
        let i = try XCTUnwrap(ns.firstIndex { ($0["id"] as? String) == id }, "node \(id)")
        f(&ns[i]); c["nodes"] = ns
        return c
    }
    @discardableResult
    private func git(_ args: [String]) -> (status: Int32, out: String) {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", repoRoot] + args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        do { try p.run() } catch { return (127, "") }
        let d = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: d, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }
    private func commitResolves(_ c: String) -> Bool { git(["rev-parse", "--verify", "--quiet", c + "^{commit}"]).status == 0 }
    private func tagExists(_ t: String) -> Bool { git(["rev-parse", "--verify", "--quiet", "refs/tags/" + t]).status == 0 }

    private let candidateSHA = "12300e66723d92cbfcafc6368cb1372ba3e1604f"
    private let candidateTagObject = "fef8f54c2a567114b0bb6e8d3fbb50e4827c3b5e"
    private let audit12VerdictSHA = "b0039eb7f75de9bcdb3432b41b3b22933955cd1a"

    // ═══════════ A13Engine — INDEPENDENT readiness reimplementation (not the builder's) ═══════════
    private struct A13Engine {
        let nodes: [String: [String: Any]]
        let order: [String]
        let contracts: [String: [[String: Any]]]
        let gates: [String: [String]]
        let blockerStatus: [String: String]
        static let blocking: Set<String> = ["OPEN", "STALE_LEDGER"]

        init(_ t: [String: Any]) {
            let ns = (t["nodes"] as? [[String: Any]]) ?? []
            order = ns.map { ($0["id"] as? String) ?? "" }
            nodes = Dictionary(uniqueKeysWithValues: ns.map { (($0["id"] as? String) ?? "", $0) })
            contracts = (t["dependency_contracts"] as? [String: [[String: Any]]]) ?? [:]
            gates = (t["gates"] as? [String: [String]]) ?? [:]
            blockerStatus = Dictionary(uniqueKeysWithValues:
                ((t["blockers"] as? [[String: Any]]) ?? []).map { (($0["id"] as? String) ?? "", ($0["status"] as? String) ?? "") })
        }
        func str(_ d: [String: Any], _ k: String) -> String { (d[k] as? String) ?? "" }
        func arr(_ d: [String: Any], _ k: String) -> [String] { (d[k] as? [String]) ?? [] }
        func refs(_ n: [String: Any], _ outer: String, _ inner: String) -> [String] {
            ((n[outer] as? [String: Any])?[inner] as? [String]) ?? []
        }
        func candidateEvidence(_ dep: [String: Any]) -> Bool {
            !refs(dep, "implementation", "refs").isEmpty && !refs(dep, "tests", "refs").isEmpty
        }
        func depSatisfied(_ c: [String: Any], _ passed: Set<String>) -> Bool {
            guard let dep = nodes[str(c, "node")] else { return false }
            switch str(c, "requires") {
            case "LOCKED":    return str(dep, "status") == "LOCKED" || passed.contains(str(c, "node"))
            case "GATE_PASS": return passed.contains(str(c, "node")) || str(dep, "status") == "LOCKED"
            case "CANDIDATE_READY":
                if passed.contains(str(c, "node")) { return true }
                guard ["ACTIVE", "LOCKED"].contains(str(dep, "status")) else { return false }
                for b in arr(dep, "blockers") where A13Engine.blocking.contains(blockerStatus[b] ?? "") { return false }
                return candidateEvidence(dep)
            default: return false // unknown contract type: fail closed
            }
        }
        func ready(_ passed: Set<String> = []) -> Set<String> {
            var out = Set<String>()
            for id in order {
                guard let n = nodes[id] else { continue }
                let st = str(n, "status")
                if ["LOCKED", "RETIRED", "ACTIVE"].contains(st) || passed.contains(id) { continue }
                let cl = contracts[id] ?? []
                guard arr(n, "depends_on").count == cl.count, cl.allSatisfy({ depSatisfied($0, passed) }) else { continue }
                guard (gates[id] ?? []).allSatisfy({ passed.contains($0) || str(nodes[$0] ?? [:], "status") == "LOCKED" }) else { continue }
                guard arr(n, "blockers").allSatisfy({ blockerStatus[$0] != nil }) else { continue }
                let v = str((n["audit"] as? [String: Any]) ?? [:], "latest_verdict").uppercased()
                guard !(v.contains("FIX REQUIRED") || v.hasPrefix("FAIL")) else { continue }
                out.insert(id)
            }
            return out
        }
        func declaredReady() -> Set<String> {
            Set(order.filter { str(nodes[$0] ?? [:], "status") == "READY" })
        }
    }
    private func engine(_ t: [String: Any]) -> A13Engine { A13Engine(t) }

    // ═══════════ independent completeness-law reimplementation (multiset-aware) ═══════════
    private func registryIDs() throws -> [String] {
        let raw = try text("docs/requirements/REQUIREMENTS_REGISTRY.yaml")
        var out: [String] = []
        let rx = try NSRegularExpression(pattern: "(?m)^  - id: ([A-Z]{2,5}-\\d{3})$")
        rx.enumerateMatches(in: raw, range: NSRange(raw.startIndex..., in: raw)) { m, _, _ in
            if let m, let r = Range(m.range(at: 1), in: raw) { out.append(String(raw[r])) }
        }
        return out
    }
    private func a13CompletenessViolations(records: [[String: Any]], registry: [String],
                                           nodesByID: [String: [String: Any]]) -> [String] {
        var v: [String] = []
        let ids = records.map { ($0["requirement_id"] as? String) ?? "" }
        if Set(ids).count != ids.count { v.append("duplicate map records") }
        if Set(registry).count != registry.count { v.append("duplicate registry IDs") }
        for missing in Set(registry).subtracting(ids) { v.append("orphan (unmapped) requirement: \(missing)") }
        for fake in Set(ids).subtracting(registry) { v.append("mapped requirement not in registry: \(fake)") }
        for r in records {
            let rid = (r["requirement_id"] as? String) ?? "?"
            let dispo = (r["disposition"] as? String) ?? ""
            if dispo == "EXPLICIT_DEFER" {
                if ((r["reason"] as? String) ?? "").isEmpty { v.append("\(rid): DEFER without reason") }
                if r["deferred_until"] as? String == nil { v.append("\(rid): DEFER without deferred_until") }
                if (r["release_blocking"] as? Bool) == true { v.append("\(rid): release blocker silently deferred") }
            } else if dispo != "SUPERSEDED" {
                let owners = (r["owner_nodes"] as? [String]) ?? []
                if owners.isEmpty { v.append("\(rid): no owner") }
                for o in owners where nodesByID[o] == nil { v.append("\(rid): ghost owner \(o)") }
                if let po = r["primary_owner"] as? String {
                    if !owners.contains(po) { v.append("\(rid): primary not in owners") }
                    if (nodesByID[po]?["status"] as? String) == "RETIRED" { v.append("\(rid): RETIRED primary") }
                } else { v.append("\(rid): no primary owner") }
                let statuses = owners.compactMap { nodesByID[$0]?["status"] as? String }
                if !statuses.isEmpty && statuses.allSatisfy({ $0 == "RETIRED" }) { v.append("\(rid): all owners RETIRED") }
            }
        }
        return v
    }
    /// Builder CP11 law, replicated faithfully (SET-based) ONLY to measure what it catches vs mine.
    private func builderStyleSetLawHolds(records: [[String: Any]], registry: [String]) -> Bool {
        Set(registry) == Set(records.map { ($0["requirement_id"] as? String) ?? "" })
    }

    // ═══════════ independent vanish-law reimplementation ═══════════
    private let all22Blockers = ["BLK-B1", "BLK-B2", "BLK-C1", "BLK-C2", "BLK-C3", "BLK-C4", "BLK-C5",
                                 "BLK-C6", "BLK-H1", "BLK-H2", "BLK-H3", "BLK-H4", "BLK-H5",
                                 "BLK-ECE-UNMET", "BLK-DEVICE-RWC-OPEN", "BLK-A10-F1-COVERAGE",
                                 "BLK-A10-F1-FALSETRIGGER", "BLK-A11-IDCHARSET", "BLK-A11-COMPOSITE-ALIAS",
                                 "BLK-A11-LEGACY-P008", "BLK-A11-APIBYPASS", "BLK-GH-CREDENTIALS"]
    private let all9NTs = ["NT-TIER0-GROUPING", "NT-C6-LOADBEARING", "NT-PREVDWELL", "NT-THERMAL-EVIDENCE-BUILD",
                           "NT-P008-PILOT-FAILED", "NT-ECE-UNMET", "NT-F1-COVERAGE", "NT-APIBYPASS", "NT-DEVICE-RWC"]
    private func a13VanishViolations(twin t: [String: Any], ledgerSubjects: String) -> [String] {
        let present = Set(((t["blockers"] as? [[String: Any]]) ?? []).compactMap { $0["id"] as? String })
        let ntPresent = Set(((t["negative_truth"] as? [[String: Any]]) ?? []).compactMap { $0["id"] as? String })
        var v: [String] = []
        for id in all22Blockers where !present.contains(id) && !ledgerSubjects.contains(id) { v.append(id) }
        for id in all9NTs where !ntPresent.contains(id) && !ledgerSubjects.contains(id) { v.append(id) }
        return v
    }
    private func ledgerSubjects() throws -> String {
        (((try ledger())["records"] as? [[String: Any]]) ?? []).compactMap { $0["subject"] as? String }.joined(separator: " | ")
    }

    // ═════════════════════════════ §0 CUSTODY & SCOPE ═════════════════════════════

    func testA13_01_CustodyTagAndCandidate() throws {
        XCTAssertEqual(git(["rev-parse", "gen8-ulu-evren-control-plane-r1-audit-candidate"]).out,
                       candidateTagObject, "annotated tag object")
        XCTAssertEqual(git(["rev-parse", "gen8-ulu-evren-control-plane-r1-audit-candidate^{commit}"]).out,
                       candidateSHA, "tag dereferences to the R1 candidate")
        XCTAssertTrue(commitResolves(audit12VerdictSHA), "AUDIT12 verdict commit present")
        XCTAssertTrue(commitResolves("4d6649c"), "original CP candidate present")
        XCTAssertTrue(commitResolves("e983b36"), "RWC lock predecessor present")
    }

    func testA13_02_NoProductSourceChangeInR1Round() throws {
        let files = git(["diff", "--name-only", audit12VerdictSHA, candidateSHA]).out
            .split(separator: "\n").map(String.init)
        XCTAssertEqual(files.count, 16, "R1 surface is exactly 16 files")
        let allowed = ["docs/audit/", "docs/control-plane/", "docs/requirements/",
                       "packages/GuardianKit/Tests/GuardianCoreTests/"]
        for f in files {
            XCTAssertTrue(allowed.contains { f.hasPrefix($0) }, "outside allowed R1 surface: \(f)")
            XCTAssertFalse(f.contains("/Sources/"), "production source touched: \(f)")
        }
        XCTAssertTrue(files.contains("docs/control-plane/GEN8_REQUIREMENT_NODE_MAP.yaml"))
        XCTAssertTrue(files.contains("packages/GuardianKit/Tests/GuardianCoreTests/ControlPlaneStateEvaluatorV1.swift"))
    }

    // ═════════════════════════════ §27 AUDIT12 INVERSION DISCIPLINE ═════════════════════════════

    func testA13_03_FrozenOriginalSHAExact() throws {
        let d = try Data(contentsOf: URL(fileURLWithPath:
            repoRoot + "/docs/audit/AUDIT12_UluEvrenControlPlaneProbes_ORIGINAL_LOCKED.swift.txt"))
        XCTAssertEqual(SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined(),
                       "4671898b38159721b6bbd29d6c77c1715623175cbea8554e747a3fc0b8a24a20")
    }

    func testA13_04_ManifestPrecedesFirstInversionCommit() throws {
        // manifest commit 3a94990 must be a strict ancestor of the first inverting commit bb8f76f
        XCTAssertEqual(git(["merge-base", "--is-ancestor",
                            "3a949906452e5ce55fb734b05b8cef4d7b5faf8f",
                            "bb8f76fe29987a053a281244fa289057e996abbf"]).status, 0)
        let tManifest = Int(git(["show", "-s", "--format=%ct", "3a94990"]).out) ?? 0
        let tInvert = Int(git(["show", "-s", "--format=%ct", "bb8f76f"]).out) ?? 0
        XCTAssertGreaterThan(tManifest, 0)
        XCTAssertLessThan(tManifest, tInvert, "pre-declaration strictly precedes the first inversion")
    }

    func testA13_05_InversionDiffBoundedToFiveDeclaredProbes() throws {
        let frozen = try text("docs/audit/AUDIT12_UluEvrenControlPlaneProbes_ORIGINAL_LOCKED.swift.txt")
            .components(separatedBy: "\n")
        let active = try text("packages/GuardianKit/Tests/GuardianCoreTests/AUDIT12_UluEvrenControlPlaneProbes.swift")
            .components(separatedBy: "\n")
        // multiset line delta pinned exactly (recomputed independently of the builder's hooks)
        var cf: [String: Int] = [:]; for l in frozen { cf[l, default: 0] += 1 }
        var ca: [String: Int] = [:]; for l in active { ca[l, default: 0] += 1 }
        var added = 0, removed = 0
        for (l, n) in ca { added += max(0, n - (cf[l] ?? 0)) }
        for (l, n) in cf { removed += max(0, n - (ca[l] ?? 0)) }
        XCTAssertEqual(added, 45, "lines only in active probe file")
        XCTAssertEqual(removed, 40, "lines only in frozen original")
        // characterization probes (NOT inverted) byte-present in BOTH files
        for sig in ["func testA12_22_Mutation_ActiveIncompleteDependencyUnlock_GenericLawAccepts_FINDING",
                    "func testA12_23_Mutation_DependencyWithOpenBlocker_GenericLawAccepts_FINDING",
                    "func testA12_24_Mutation_IllegalTransitions_ProseOnly_FINDING",
                    "func testA12_25_Mutation_CensusDeletions_PartiallyUndetected_FINDING",
                    "func testA12_26_Mutation_StructuralAttacks_CatchMatrix",
                    "func testA12_36_BuilderChecksReimplemented_AllGreenOnCandidateAsIs"] {
            XCTAssertTrue(frozen.contains { $0.contains(sig) }, "frozen keeps \(sig)")
            XCTAssertTrue(active.contains { $0.contains(sig) }, "active keeps \(sig) (not inverted)")
        }
        // the historical 4d6649c census stays preserved in the frozen original ONLY
        XCTAssertTrue(frozen.contains { $0.contains("XCTAssertEqual(total, 253, \"census total\")") })
        XCTAssertTrue(active.contains { $0.contains("XCTAssertEqual(total, 257, \"census total\")") })
    }

    func testA13_06_HistoricalAudit12ReportAndRegistryHistoryClean() throws {
        let reportLog = git(["log", "--format=%H", "--",
                             "docs/audit/GEN8_ULU_EVREN_CONTROL_PLANE_INDEPENDENT_AUDIT.md"]).out
        XCTAssertEqual(reportLog, audit12VerdictSHA, "AUDIT12 report touched by exactly one commit (its own)")
        let regLog = git(["log", "--format=%H", "--", "docs/requirements/REQUIREMENTS_REGISTRY.yaml"]).out
            .split(separator: "\n").map(String.init)
        XCTAssertEqual(regLog, ["bb8f76fe29987a053a281244fa289057e996abbf",
                                "95116c23cd73be90490d3470fe36c9d66a1a3fd5"],
                       "registry edited only by the R1 count-correction commit since authoring")
    }

    // ═════════════════════════════ §2/§3 A12-F2 REQUIREMENT COMPLETENESS ═════════════════════════════

    func testA13_07_RegistryMapExactSet36() throws {
        let reg = try registryIDs()
        XCTAssertEqual(reg.count, 36); XCTAssertEqual(Set(reg).count, 36, "no duplicate registry IDs")
        let recs = try XCTUnwrap((try reqMap())["records"] as? [[String: Any]])
        let mapped = recs.compactMap { $0["requirement_id"] as? String }
        XCTAssertEqual(mapped.count, 36); XCTAssertEqual(Set(mapped).count, 36, "no duplicate map records")
        XCTAssertEqual(Set(reg), Set(mapped), "REGISTRY SET == MAP SET (zero orphans, zero fakes)")
        let ns = A13Engine(try twin()).nodes
        XCTAssertEqual(try a13CompletenessViolations(records: recs, registry: reg, nodesByID: ns), [],
                       "independent completeness law: zero violations on the candidate")
    }

    func testA13_08_AllDispositionsMapExisting_NoRetiredNodesExist() throws {
        let recs = try XCTUnwrap((try reqMap())["records"] as? [[String: Any]])
        XCTAssertTrue(recs.allSatisfy { ($0["disposition"] as? String) == "MAP_EXISTING_NODE" },
                      "0 DEFER / 0 SUPERSEDED / 0 CREATE_MISSING on the candidate")
        let statuses = ((try twin())["nodes"] as? [[String: Any]])?.compactMap { $0["status"] as? String } ?? []
        XCTAssertFalse(statuses.contains("RETIRED"), "no RETIRED node exists — no requirement can hide on one")
    }

    func testA13_09_FormerOrphansSemanticOwnership() throws {
        // All 12 prior orphans: semantic primary owners verified against the REGISTRY TEXT read in
        // this audit (descriptions quoted in the A13 report §3).
        let expectedPrimary: [String: String] = [
            "ADM-002": "P009D-POLICY",               // deterministic precedence implemented lab-side (D-0024)
            "BND-001": "P003-CONTENT-BOUNDARY",      // ObservedContentSession boundary scope
            "COST-001": "EP8-PRODUCTION-CIVILIZATION",
            "DVT-001": "EP6-BOUNDED-LEARNING",       // DATA-RIGHTS/cross-user reuse — NOT device trust
            "EVD-001": "P009C-WORLD-MODEL",          // EvidenceWeigherV1 provenance families
            "HSH-001": "EP4-FAMILY-AUTHORITY",
            "PRI-001": "EP8-PRODUCTION-CIVILIZATION",
            "PROT-001": "P006-SHIELD-GLYPH",
            "REL-001": "EP8-PRODUCTION-CIVILIZATION",
            "SCO-002": "EP3-PRESENTATION",
            "SEC-001": "EP8-PRODUCTION-CIVILIZATION",
            "TWIN-001": "EP4-GROWTH-TWIN"]
        let recs = try XCTUnwrap((try reqMap())["records"] as? [[String: Any]])
        let twinNodes = A13Engine(try twin()).nodes
        for (rid, owner) in expectedPrimary {
            let r = try XCTUnwrap(recs.first { ($0["requirement_id"] as? String) == rid }, rid)
            XCTAssertEqual(r["primary_owner"] as? String, owner, "\(rid): semantic primary owner")
            XCTAssertEqual(r["release_blocking"] as? Bool, true, "\(rid): P0 ⇒ release blocking")
            XCTAssertTrue(((r["r1_note"] as? String) ?? "").contains("A12-F2"), "\(rid): closure traceable")
            XCTAssertGreaterThanOrEqual(((r["reason"] as? String) ?? "").count, 40,
                                        "\(rid): non-cosmetic semantic reason")
            // primary owner binding surfaced on the twin node itself
            let reqs = (twinNodes[owner]?["requirements"] as? [String]) ?? []
            XCTAssertTrue(reqs.contains(rid), "\(rid): twin node \(owner) carries the binding")
        }
        // DVT-001 is data-rights by REGISTRY TEXT (independent source read, not builder claim)
        let reg = try text("docs/requirements/REQUIREMENTS_REGISTRY.yaml")
        XCTAssertTrue(reg.contains("Data rights before cross-user reuse; private => GLOBAL_REUSE=DENY"),
                      "DVT-001 registry title is data-rights")
        XCTAssertTrue(reg.contains("owner: data-rights"), "DVT-001 owner family is data-rights")
    }

    func testA13_10_ReleaseBlockingFieldContradictsRegistryP0_FINDING() throws {
        // A13-F2 (LOW, pinned current truth): the registry declares ALL 36 requirements priority P0
        // ("release-blocking foundational proof"), but 14 canonical map records carry
        // release_blocking:false. CP11's "release blocker never silently deferred" guard keys on this
        // field, so the defer-protection is void for exactly these 14 P0 requirements. No live effect
        // (zero DEFER dispositions exist; readiness never consumes the field) — forward protection gap.
        let reg = try text("docs/requirements/REQUIREMENTS_REGISTRY.yaml")
        XCTAssertEqual(reg.components(separatedBy: "priority: P0").count - 1, 36, "all 36 registry entries are P0")
        let recs = try XCTUnwrap((try reqMap())["records"] as? [[String: Any]])
        let falseSet = Set(recs.filter { ($0["release_blocking"] as? Bool) == false }
            .compactMap { $0["requirement_id"] as? String })
        XCTAssertEqual(falseSet, ["ADM-001", "CDNA-001", "COG-001", "IDR-001", "OPS-001", "OPS-002",
                                  "PAI-001", "PROT-002", "PUB-001", "SCO-001", "TMP-001", "TMP-002",
                                  "UX-001", "VAL-001"],
                       "A13-F2 pin: exactly these 14 P0 requirements are marked non-release-blocking in the map")
        // demonstrate the gap on a deep copy: deferring SCO-001 (P0!) passes the builder-style defer law
        var copy = try deepCopy(try reqMap())
        var rs = try XCTUnwrap(copy["records"] as? [[String: Any]])
        let i = try XCTUnwrap(rs.firstIndex { ($0["requirement_id"] as? String) == "SCO-001" })
        rs[i]["disposition"] = "EXPLICIT_DEFER"; rs[i]["reason"] = "hostile defer"; rs[i]["deferred_until"] = "never"
        copy["records"] = rs
        let r = rs[i]
        let builderDeferLawRejects = (r["release_blocking"] as? Bool) == true   // CP11's only defer brake
        XCTAssertFalse(builderDeferLawRejects,
                       "A13-F2 pin: the defer brake does NOT fire for SCO-001 because the map misdeclares it non-blocking")
    }

    // ═════════════════════════════ §4 REQUIREMENT MUTATION ATTACKS ═════════════════════════════

    func testA13_11_Mutation_DeleteMapRecordCaught() throws {
        let reg = try registryIDs()
        let ns = A13Engine(try twin()).nodes
        var recs = try XCTUnwrap((try deepCopy(try reqMap()))["records"] as? [[String: Any]])
        recs.removeAll { ($0["requirement_id"] as? String) == "ACC-001" }
        XCTAssertFalse(a13CompletenessViolations(records: recs, registry: reg, nodesByID: ns).isEmpty,
                       "deletion caught by my law")
        XCTAssertFalse(builderStyleSetLawHolds(records: recs, registry: reg),
                       "deletion ALSO caught by the builder's CP11 set law")
    }

    func testA13_12_Mutation_DuplicateRecordOnlyMyLawCatches() throws {
        let reg = try registryIDs()
        let ns = A13Engine(try twin()).nodes
        var recs = try XCTUnwrap((try deepCopy(try reqMap()))["records"] as? [[String: Any]])
        recs.append(recs[0])   // duplicate ACC-001
        XCTAssertTrue(a13CompletenessViolations(records: recs, registry: reg, nodesByID: ns)
            .contains("duplicate map records"), "duplicate caught by my multiset law")
        XCTAssertTrue(builderStyleSetLawHolds(records: recs, registry: reg),
                      "pinned: the builder's SET-based CP11 equality is BLIND to duplicate records (A13 report note)")
    }

    func testA13_13_Mutation_FakeRequirementAndGhostOwnerCaught() throws {
        let reg = try registryIDs()
        let ns = A13Engine(try twin()).nodes
        var recs = try XCTUnwrap((try deepCopy(try reqMap()))["records"] as? [[String: Any]])
        recs.append(["requirement_id": "ZZZ-999", "disposition": "MAP_EXISTING_NODE",
                     "owner_nodes": ["EP7-TV"], "primary_owner": "EP7-TV", "release_blocking": true])
        var v = a13CompletenessViolations(records: recs, registry: reg, nodesByID: ns)
        XCTAssertTrue(v.contains { $0.contains("ZZZ-999") }, "fake requirement caught")
        XCTAssertFalse(builderStyleSetLawHolds(records: recs, registry: reg), "also caught by CP11 set law")
        // ghost owner
        recs = try XCTUnwrap((try deepCopy(try reqMap()))["records"] as? [[String: Any]])
        let i = try XCTUnwrap(recs.firstIndex { ($0["requirement_id"] as? String) == "TWIN-001" })
        recs[i]["owner_nodes"] = ["GHOST-NODE"]; recs[i]["primary_owner"] = "GHOST-NODE"
        v = a13CompletenessViolations(records: recs, registry: reg, nodesByID: ns)
        XCTAssertTrue(v.contains { $0.contains("ghost owner") }, "nonexistent owner node caught")
    }

    func testA13_14_Mutation_RetiredOnlyOwnerAndBadDeferCaught() throws {
        let reg = try registryIDs()
        // release blocker mapped only to a RETIRED node
        let retiredTwin = try mutated(try twin(), node: "EP4-GROWTH-TWIN") { $0["status"] = "RETIRED" }
        let ns = A13Engine(retiredTwin).nodes
        let recs = try XCTUnwrap((try reqMap())["records"] as? [[String: Any]])
        let v = a13CompletenessViolations(records: recs, registry: reg, nodesByID: ns)
        XCTAssertTrue(v.contains { $0.contains("TWIN-001") && $0.contains("RETIRED") },
                      "release blocker on RETIRED-only owner caught (TWIN-001 single-owner)")
        // EXPLICIT_DEFER without reason / deferred release blocker
        var rs = try XCTUnwrap((try deepCopy(try reqMap()))["records"] as? [[String: Any]])
        let i = try XCTUnwrap(rs.firstIndex { ($0["requirement_id"] as? String) == "ADM-002" })
        rs[i]["disposition"] = "EXPLICIT_DEFER"; rs[i]["reason"] = ""
        let v2 = a13CompletenessViolations(records: rs, registry: reg, nodesByID: A13Engine(try twin()).nodes)
        XCTAssertTrue(v2.contains("ADM-002: DEFER without reason"))
        XCTAssertTrue(v2.contains("ADM-002: DEFER without deferred_until"))
        XCTAssertTrue(v2.contains("ADM-002: release blocker silently deferred"),
                      "deferred release blocker has a blocking consequence under my law (and under CP11 for rb=true records)")
    }

    // ═════════════════════════════ §5 A12-F3 FULL REFERENCE RECENSUS ═════════════════════════════

    private struct A13Census {
        var filePath = 0, dirScope = 0, ledgerAnchor = 0, commitSHA = 0, tag = 0
        var auditAlias = 0, decisionID = 0, requirementID = 0, testSymbol = 0, sourceSymbol = 0, semantic = 0
        var broken: [String] = []
        var total: Int { filePath + dirScope + ledgerAnchor + commitSHA + tag + auditAlias
            + decisionID + requirementID + testSymbol + sourceSymbol + semantic }
        var machine: Int { total - semantic }
    }
    /// Own classifier (NOT the AUDIT12/builder classifier): adds DECISION_ID and REQUIREMENT_ID
    /// machine classes and verifies EVERY commit ref via git rev-parse (no prefix whitelist).
    private func runCensus(twin t: [String: Any], fm: [String: Any]) throws -> A13Census {
        var c = A13Census()
        let csv = try text("docs/audit/GEN8_CLAIM_EVIDENCE_LEDGER.csv")
        let decisions = try text("docs/canonical/DECISION_LEDGER.md")
        let reqIDs = Set(try registryIDs())
        let aliasKeys = Set(try aliases().keys)
        let testDir = repoRoot + "/packages/GuardianKit/Tests/GuardianCoreTests"
        let testFiles = Set((try? FileManager.default.contentsOfDirectory(atPath: testDir)) ?? [])
        var srcFiles = Set<String>()
        if let en = FileManager.default.enumerator(atPath: repoRoot + "/packages/GuardianKit/Sources") {
            for case let p as String in en where p.hasSuffix(".swift") {
                srcFiles.insert((p as NSString).lastPathComponent)
            }
        }
        var commitCache: [String: Bool] = [:], tagCache: [String: Bool] = [:]
        func isIdentifier(_ s: String) -> Bool { s.range(of: "^[A-Za-z0-9_]+$", options: .regularExpression) != nil }
        func classify(_ ref: String, _ ctx: String) {
            let r = ref.trimmingCharacters(in: .whitespaces)
            if r.hasSuffix("/") {
                c.dirScope += 1
                var isDir: ObjCBool = false
                let p = r.components(separatedBy: " ").first ?? r
                if !FileManager.default.fileExists(atPath: repoRoot + "/" + p, isDirectory: &isDir) || !isDir.boolValue {
                    c.broken.append("\(ctx): dir \(r)")
                }
            } else if r.contains(".csv:") {
                c.ledgerAnchor += 1
                let token = r.components(separatedBy: ".csv:")[1].components(separatedBy: " ")[0]
                if !csv.contains("\n\(token),") { c.broken.append("\(ctx): anchor \(token)") }
            } else if r.hasPrefix("docs/"), !r.contains(" "),
                      ((r as NSString).lastPathComponent).contains(".") {
                c.filePath += 1
                if !exists(r) { c.broken.append("\(ctx): file \(r)") }
            } else if r.hasPrefix("packages/"), !r.contains(" "), r.hasSuffix(".swift") {
                c.filePath += 1
                if !exists(r) { c.broken.append("\(ctx): file \(r)") }
            } else if r.range(of: "^[0-9a-f]{7,40}$", options: .regularExpression) != nil {
                c.commitSHA += 1
                let ok = commitCache[r] ?? { let v = commitResolves(r); commitCache[r] = v; return v }()
                if !ok { c.broken.append("\(ctx): commit \(r)") }
            } else if r.hasPrefix("gen8-") {
                c.tag += 1
                let ok = tagCache[r] ?? { let v = tagExists(r); tagCache[r] = v; return v }()
                if !ok { c.broken.append("\(ctx): tag \(r)") }
            } else if r.range(of: "^AUDIT\\d+$", options: .regularExpression) != nil {
                c.auditAlias += 1
                if !aliasKeys.contains(r) { c.broken.append("\(ctx): unregistered alias \(r)") }
            } else if r.range(of: "^D-\\d{4}$", options: .regularExpression) != nil {
                c.decisionID += 1
                if !decisions.contains(r) { c.broken.append("\(ctx): decision \(r)") }
            } else if reqIDs.contains(r) {
                c.requirementID += 1
            } else if !r.contains(" "), testFiles.contains(r + ".swift") {
                c.testSymbol += 1
            } else if !r.contains(" "), r.hasSuffix(".swift"), !r.contains("/") {
                c.sourceSymbol += 1
                if !srcFiles.contains(r), !testFiles.contains(r) { c.broken.append("\(ctx): swift file \(r)") }
            } else if isIdentifier(r), srcFiles.contains(r + ".swift") {
                c.sourceSymbol += 1
            } else {
                c.semantic += 1   // SEMANTIC_DESCRIPTION — honest, NEVER counted machine-resolvable
            }
        }
        for n in (t["nodes"] as? [[String: Any]]) ?? [] {
            let id = (n["id"] as? String) ?? "?"
            let impl = (n["implementation"] as? [String: Any]) ?? [:]
            for r in (impl["refs"] as? [String]) ?? [] { classify(r, id) }
            for cm in (impl["commits"] as? [String]) ?? [] { classify(cm, id) }
            for r in ((n["tests"] as? [String: Any])?["refs"] as? [String]) ?? [] { classify(r, id) }
            for r in ((n["audit"] as? [String: Any])?["refs"] as? [String]) ?? [] { classify(r, id) }
            for (_, v) in (n["evidence"] as? [String: Any]) ?? [:] {
                for r in (v as? [String]) ?? [] { classify(r, id) }
            }
            let rb = (n["rollback"] as? [String: Any]) ?? [:]
            for k in ["commit", "tag"] where !(((rb[k] as? String) ?? "").isEmpty) { classify(rb[k] as! String, id + ".rollback") }
        }
        for s in (t["sources"] as? [[String: Any]]) ?? [] { classify((s["path"] as? String) ?? "", "sources") }
        for b in (t["blockers"] as? [[String: Any]]) ?? [] { classify((b["source"] as? String) ?? "", (b["id"] as? String) ?? "?") }
        for nt in (t["negative_truth"] as? [[String: Any]]) ?? [] {
            for e in (nt["evidence"] as? [String]) ?? [] { classify(e, (nt["id"] as? String) ?? "?") }
        }
        for r in (fm["records"] as? [[String: Any]]) ?? [] {
            for e in (r["evidence"] as? [String]) ?? [] { classify(e, (r["id"] as? String) ?? "?") }
            for rt in (r["regression_tests"] as? [String]) ?? [] { classify(rt, ((r["id"] as? String) ?? "?") + ".regression") }
        }
        return c
    }

    func testA13_15_IndependentFullReferenceCensus_BrokenZero() throws {
        let c = try runCensus(twin: try twin(), fm: try json("docs/control-plane/GEN8_ENGINEERING_FAILURE_MEMORY.yaml"))
        XCTAssertEqual(c.broken, [], "ZERO broken machine-resolvable refs — A12-F3 closure independently confirmed")
        XCTAssertEqual(c.total, 257, "independent census total agrees with the builder total")
        // my partition (differs from the builder's by design: D-xxxx decision IDs resolved as machine)
        XCTAssertEqual([c.filePath, c.dirScope, c.ledgerAnchor, c.commitSHA, c.tag, c.auditAlias,
                        c.decisionID, c.requirementID, c.testSymbol, c.sourceSymbol, c.semantic],
                       [77, 7, 8, 22, 6, 16, 8, 0, 29, 2, 82], "A13 classifier partition")
        XCTAssertEqual(c.machine, 175, "machine refs under MY classifier (builder counts the 8 D-IDs semantic → 167)")
        XCTAssertEqual(c.total, c.machine + c.semantic, "partition law: SEMANTIC never counted machine")
        XCTAssertGreaterThan(c.machine, c.semantic)
    }

    func testA13_16_ReferenceMutations_AllFailDeterministically() throws {
        var t = try deepCopy(try twin())
        var ns = try XCTUnwrap(t["nodes"] as? [[String: Any]])
        var ev = try XCTUnwrap(ns[0]["evidence"] as? [String: Any])
        ev["audit_refs"] = ["docs/audit/NO_SUCH_REPORT_ZZZ.md",                       // broken file
                            "gen8-nonexistent-tag-zzz",                               // fake tag
                            "GEN8_CLAIM_EVIDENCE_LEDGER.csv:ZZZANCHOR",               // bad ledger row
                            "deadbeef1234567890abcdef1234567890abcdef",               // bad commit
                            "AUDIT99",                                                // unregistered alias
                            "D-9999"]                                                 // bad decision ID
        ns[0]["evidence"] = ev
        t["nodes"] = ns
        let c = try runCensus(twin: t, fm: ["records": []])
        XCTAssertEqual(c.broken.count, 6, "every machine-shaped fake ref is individually flagged: \(c.broken)")
        // bad requirement ID on a node → generic registry law (exercised exactly as CP11 does, on a copy)
        let reg = try text("docs/requirements/REQUIREMENTS_REGISTRY.yaml")
        let m = try mutated(try twin(), node: "EP7-TV") { $0["requirements"] = ["QQQ-404"] }
        var bad: [String] = []
        for n in try XCTUnwrap(m["nodes"] as? [[String: Any]]) {
            for r in (n["requirements"] as? [String]) ?? [] where !reg.contains("- id: \(r)") { bad.append(r) }
        }
        XCTAssertEqual(bad, ["QQQ-404"], "bad node requirement ID caught generically")
        // bad test symbol: a nonexistent symbol is NEVER counted as resolved machine evidence
        var t2 = try deepCopy(try twin())
        var ns2 = try XCTUnwrap(t2["nodes"] as? [[String: Any]])
        var tests = try XCTUnwrap(ns2[0]["tests"] as? [String: Any])
        tests["refs"] = ["NoSuchProbeFamilyZZZ"]; ns2[0]["tests"] = tests; t2["nodes"] = ns2
        let base = try runCensus(twin: try twin(), fm: ["records": []])
        let c2 = try runCensus(twin: t2, fm: ["records": []])
        XCTAssertEqual(c2.testSymbol, base.testSymbol - 1, "fake symbol not classed TEST_SYMBOL")
        XCTAssertEqual(c2.semantic, base.semantic + 1, "fake symbol demoted to SEMANTIC — never machine-resolved")
    }

    // ═════════════════════════════ §6/§7 FABRICATED HISTORY + P009D ═════════════════════════════

    func testA13_17_FabricatedTagsStillDoNotExist_TypedRollbackTruth() throws {
        for fab in ["gen8-p009a-identity-foundation-locked-phase-c-ok", "gen8-p009b-expert-mesh-r1-reaudit-pass"] {
            XCTAssertFalse(tagExists(fab), "fabricated tag must never be retroactively created: \(fab)")
        }
        let twinText = try text("docs/control-plane/GEN8_PROJECT_TWIN.yaml")
        XCTAssertFalse(twinText.contains("gen8-p009a-identity-foundation-locked-phase-c-ok"))
        XCTAssertFalse(twinText.contains("gen8-p009b-expert-mesh-r1-reaudit-pass"))
        let e = engine(try twin())
        for (id, commit) in [("P009A-IDENTITY-FOUNDATION", "4ce238f75074e8adda0c5ea9f02c1139f4086704"),
                             ("P009B-EXPERT-MESH", "42b96a203cb07c879728dcb25cf353918ad27257")] {
            let rb = try XCTUnwrap(e.nodes[id]?["rollback"] as? [String: Any])
            XCTAssertEqual(rb["tag_status"] as? String, "NEVER_CREATED")
            XCTAssertEqual(rb["tag"] as? String, "")
            XCTAssertEqual(git(["rev-parse", (rb["commit"] as? String ?? "") + "^{commit}"]).out, commit,
                           "\(id): rollback-by-commit anchor is real")
        }
        // correction records exist: RES-001/RES-002 + the corrections document
        let subj = try ledgerSubjects()
        XCTAssertTrue(subj.contains("P009A-IDENTITY-FOUNDATION.rollback.tag"))
        XCTAssertTrue(subj.contains("P009B-EXPERT-MESH.rollback.tag"))
        XCTAssertTrue(try text("docs/control-plane/CONTROL_PLANE_R1_REFERENCE_CORRECTIONS.md")
            .contains("NO retroactive tag creation"))
        // the fabricated strings remain preserved in FROZEN evidence (history not rewritten)
        let frozen = try text("docs/audit/AUDIT12_UluEvrenControlPlaneProbes_ORIGINAL_LOCKED.swift.txt")
        XCTAssertTrue(frozen.contains("gen8-p009a-identity-foundation-locked-phase-c-ok"))
    }

    func testA13_18_RollbackTruthMachineChecked_All60Nodes() throws {
        for (id, n) in engine(try twin()).nodes {
            let rb = try XCTUnwrap(n["rollback"] as? [String: Any], id)
            let status = rb["tag_status"] as? String
            let tagV = (rb["tag"] as? String) ?? ""
            let commitV = (rb["commit"] as? String) ?? ""
            XCTAssertTrue(["EXISTS", "NEVER_CREATED", "NOT_APPLICABLE"].contains(status ?? ""), id)
            switch status {
            case "EXISTS":
                XCTAssertFalse(tagV.isEmpty, id); XCTAssertTrue(tagExists(tagV), "\(id): tag \(tagV)")
                XCTAssertTrue(commitResolves(commitV), "\(id): rollback commit resolves")
                // tag deref consistency with the node's lock lineage: the rollback commit is an
                // ancestor-or-equal of the tag target
                let tagCommit = git(["rev-parse", tagV + "^{commit}"]).out
                XCTAssertEqual(git(["merge-base", "--is-ancestor", commitV, tagCommit]).status, 0,
                               "\(id): rollback commit within the tag's lineage")
            case "NEVER_CREATED":
                XCTAssertTrue(tagV.isEmpty, "\(id): NEVER_CREATED forbids a tag claim")
                XCTAssertTrue(commitResolves(commitV), "\(id): commit anchor required and real")
            default:
                XCTAssertTrue(tagV.isEmpty && commitV.isEmpty, "\(id): NOT_APPLICABLE pretends no anchor")
            }
        }
    }

    func testA13_19_P009D_CanonicalArtifactGenuine_NoLivingStaleRef() throws {
        XCTAssertFalse(exists("docs/implementation/P009D_IMPLEMENTATION_EVIDENCE.md"), "old path still nonexistent")
        let artifact = try text("docs/intelligence/P009D_POLICY_INTELLIGENCE.md")
        XCTAssertTrue(artifact.hasPrefix("# P009D — Safety + Child Age + Personal Shield Policy Intelligence"),
                      "artifact is genuinely the P009D policy-intelligence evidence (title line)")
        XCTAssertTrue(artifact.contains("AdmissionPolicyPipelineV1"), "content matches P009D scope, not a shell")
        // git: artifact predates the control-plane program (authored in the P009D era, not invented at R1)
        let firstCommit = git(["log", "--format=%H", "--follow", "--diff-filter=A", "--",
                               "docs/intelligence/P009D_POLICY_INTELLIGENCE.md"]).out
            .split(separator: "\n").map(String.init).last ?? ""
        XCTAssertEqual(git(["merge-base", "--is-ancestor", firstCommit, "9c049f3"]).status, 0,
                       "artifact existed at/before the P009D lock merge 9c049f3")
        // no LIVING canonical file still references the dead path (correction records excepted)
        let dir = repoRoot + "/docs/control-plane"
        let whitelist: Set<String> = ["CONTROL_PLANE_R1_REFERENCE_CORRECTIONS.md",
                                      "GEN8_RESOLUTION_LEDGER.yaml",
                                      "GEN8_CONTROL_PLANE_R1_REMEDIATION_REPORT.md"]
        for f in try FileManager.default.contentsOfDirectory(atPath: dir) where !whitelist.contains(f) {
            let body = (try? String(contentsOfFile: dir + "/" + f, encoding: .utf8)) ?? ""
            XCTAssertFalse(body.contains("P009D_IMPLEMENTATION_EVIDENCE"),
                           "living control-plane file still cites the dead path: \(f)")
        }
        XCTAssertTrue(try text("docs/control-plane/GEN8_PROJECT_TWIN.yaml")
            .contains("docs/intelligence/P009D_POLICY_INTELLIGENCE.md"), "twin cites the real artifact")
    }

    // ═════════════════════════════ §8 AUDIT ALIAS REGISTRY ═════════════════════════════

    func testA13_20_AliasRegistryResolvesDeterministically_NoCollision() throws {
        let a = try aliases()
        XCTAssertEqual(Set(a.keys), Set((2...13).map { "AUDIT\($0)" }),
                       "exactly AUDIT2..AUDIT13 (AUDIT13 resolver added at governing lock; inversion I-2, AUDIT13_INVERSION_LOCK.md)")
        var reports = Set<String>(), probes = Set<String>()
        for (alias, rec) in a {
            for key in ["report_path", "probe_path", "frozen_original", "inversion_lock"] {
                if let p = rec[key] as? String {
                    XCTAssertTrue(exists(p), "\(alias).\(key): \(p)")
                }
            }
            let rp = try XCTUnwrap(rec["report_path"] as? String)
            XCTAssertTrue(reports.insert(rp).inserted, "report collision: \(rp)")
            let pp = try XCTUnwrap(rec["probe_path"] as? String)
            XCTAssertTrue(probes.insert(pp).inserted, "probe collision: \(pp)")
            XCTAssertTrue(commitResolves(try XCTUnwrap(rec["target_commit"] as? String)), "\(alias): target SHA real")
            if let ac = rec["audit_commit"] as? String { XCTAssertTrue(commitResolves(ac), "\(alias): audit SHA real") }
            XCTAssertFalse(((rec["verdict"] as? String) ?? "").isEmpty)
        }
        // generation pointers: AUDIT12 points at the ORIGINAL CP candidate, with its verdict commit
        XCTAssertEqual(a["AUDIT12"]?["target_commit"] as? String, "4d6649c")
        XCTAssertEqual(a["AUDIT12"]?["audit_commit"] as? String, "b0039eb")
    }

    func testA13_21_AliasVerdictIntegrity_TwoUpgradedRecords_FINDING() throws {
        let a = try aliases()
        // exact-match records: registry verdict text appears VERBATIM in the referenced report
        for alias in ["AUDIT2", "AUDIT3", "AUDIT4", "AUDIT5", "AUDIT6", "AUDIT7", "AUDIT9", "AUDIT10", "AUDIT12"] {
            let rec = try XCTUnwrap(a[alias])
            let report = try text(try XCTUnwrap(rec["report_path"] as? String))
            XCTAssertTrue(report.contains(try XCTUnwrap(rec["verdict"] as? String)),
                          "\(alias): registry verdict matches the report verdict line")
        }
        // class-preserving abbreviations (no upgrade): AUDIT8, AUDIT11
        XCTAssertTrue(try text("docs/audit/GEN8_P009E_INDEPENDENT_AUDIT_REPORT.md")
            .contains("PASS WITH LIMITATION — ENGINEERING CALIBRATION ONLY; PRODUCTION SCORE REMAINS BLOCKED"))
        XCTAssertTrue(((a["AUDIT8"]?["verdict"] as? String) ?? "").hasPrefix("PASS WITH LIMITATION"))
        XCTAssertTrue(try text("docs/audit/GEN8_RWC_ENTRY_GATE_R1_INDEPENDENT_REAUDIT.md")
            .contains("PASS — REAL-WORLD CALIBRATION ENTRY GATE ENGINEERING LOCKABLE"))
        XCTAssertTrue(((a["AUDIT11"]?["verdict"] as? String) ?? "").hasPrefix("PASS"))
        // ── A13-F1 FIXED (inversion pre-declared in docs/audit/AUDIT13_INVERSION_LOCK.md I-1; original
        // pinned PASS-class paraphrases): the registry now carries the EXACT immutable FIX verdicts plus
        // explicit later-generation pointers (resolution record RES-006). Living history reads:
        // P009B: AUDIT3 FIX -> remediation -> AUDIT4 PASS; P009C: AUDIT5 FIX -> remediation -> AUDIT6 PASS.
        let r3 = try text("docs/audit/GEN8_P009B_INDEPENDENT_AUDIT_REPORT.md")
        XCTAssertTrue(r3.contains("FIX CRITICAL P009B FINDINGS"), "AUDIT3's real verdict line")
        XCTAssertFalse(r3.contains("PASS WITH LIMITATION — ENGINEERING MESH LOCKED"),
                       "the old paraphrase appears NOWHERE in the AUDIT3 report")
        XCTAssertEqual(a["AUDIT3"]?["verdict"] as? String, "FIX CRITICAL P009B FINDINGS",
                       "A13-F1 FIXED: exact historical verdict")
        XCTAssertEqual(a["AUDIT3"]?["superseded_by"] as? String, "AUDIT4", "later successful re-audit generation")
        let r5 = try text("docs/audit/GEN8_P009C_INDEPENDENT_AUDIT_REPORT.md")
        XCTAssertTrue(r5.contains("FIX CRITICAL P009C FINDINGS"), "AUDIT5's real verdict line")
        XCTAssertEqual(a["AUDIT5"]?["verdict"] as? String, "FIX CRITICAL P009C FINDINGS",
                       "A13-F1 FIXED: exact historical verdict")
        XCTAssertEqual(a["AUDIT5"]?["superseded_by"] as? String, "AUDIT6", "later successful re-audit generation")
        // the lock lineage itself is NOT inflated: twin P009B/P009C latest verdicts are the R1 re-audit PASSes
        let e = engine(try twin())
        XCTAssertEqual((e.nodes["P009B-EXPERT-MESH"]?["audit"] as? [String: Any])?["latest_verdict"] as? String,
                       "PASS — P009B MULTIMODAL EXPERT MESH LOCKED; GO TO P009C")
        XCTAssertEqual((e.nodes["P009C-WORLD-MODEL"]?["audit"] as? [String: Any])?["latest_verdict"] as? String,
                       "PASS — P009C CONTENT WORLD MODEL LOCKED; GO TO P009D")
    }

    // ═════════════════════════════ §10/§11 STATE ENGINE CONTRACTS ═════════════════════════════

    func testA13_22_NoGenericActiveSatisfactionAnywhere() throws {
        let t = try twin()
        // functional proof 1: an ACTIVE dependency NEVER satisfies a LOCKED contract
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.dependencySatisfied(
            contract: ["node": "P008-CALIBRATION-PILOT", "requires": "LOCKED"], twin: t, passed: []),
            "ACTIVE dep does not satisfy LOCKED (generic rule abolished)")
        // functional proof 2: an ACTIVE dependency NEVER satisfies GATE_PASS
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.dependencySatisfied(
            contract: ["node": "CP-CONTROL-PLANE", "requires": "GATE_PASS"], twin: t, passed: []),
            "ACTIVE dep does not satisfy GATE_PASS")
        // functional proof 3: unknown contract types fail closed (both engines)
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.dependencySatisfied(
            contract: ["node": "P009A-IDENTITY-FOUNDATION", "requires": "ACTIVE_OK"], twin: t, passed: []))
        XCTAssertFalse(engine(t).depSatisfied(["node": "P009A-IDENTITY-FOUNDATION", "requires": "ACTIVE_OK"], []))
        // A13-F7 (INFO, pinned current truth): CP04's DECLARED-set sanity check still contains a
        // generic `LOCKED || ACTIVE` acceptance. It cannot authorize anything (CP12 equality against
        // the typed engine governs), but the residual generic pattern should be retired with the mirror.
        let validator = try text("packages/GuardianKit/Tests/GuardianCoreTests/ControlPlaneValidationTests.swift")
        XCTAssertTrue(validator.contains("s == \"LOCKED\" || s == \"ACTIVE\""), "A13-F7 pin (residual, CP04 only)")
        let evaluator = try text("packages/GuardianKit/Tests/GuardianCoreTests/ControlPlaneStateEvaluatorV1.swift")
        XCTAssertFalse(evaluator.contains("s == \"LOCKED\" || s == \"ACTIVE\""), "evaluator itself carries no such rule")
    }

    func testA13_23_CandidateReadyCensus_ExactlyOneDeclaredEdge() throws {
        let t = try twin()
        let contracts = try XCTUnwrap(t["dependency_contracts"] as? [String: [[String: Any]]])
        var edges: [(String, String)] = []
        for (nid, cl) in contracts {
            for c in cl where (c["requires"] as? String) == "CANDIDATE_READY" {
                edges.append((nid, (c["node"] as? String) ?? "?"))
            }
        }
        XCTAssertEqual(edges.count, 1, "exactly ONE CANDIDATE_READY edge in the whole graph")
        XCTAssertEqual(edges.first?.0, "CP-INDEPENDENT-AUDIT")
        XCTAssertEqual(edges.first?.1, "CP-CONTROL-PLANE")
        // typed distribution over all 75 edges
        let dist = contracts.values.flatMap { $0 }.reduce(into: [String: Int]()) { $0[($1["requires"] as? String) ?? "?", default: 0] += 1 }
        XCTAssertEqual(dist, ["LOCKED": 60, "GATE_PASS": 14, "CANDIDATE_READY": 1])
        // every node's contracts cover its depends_on exactly (one contract per edge)
        let e = engine(t)
        for (id, n) in e.nodes {
            XCTAssertEqual(Set((contracts[id] ?? []).compactMap { $0["node"] as? String }),
                           Set(e.arr(n, "depends_on")), "\(id): contract per edge, exactly")
        }
    }

    func testA13_24_CandidateReadyEdgeDemandsRealCandidate() throws {
        let t = try twin()
        // live: lawful (ACTIVE + impl refs + test refs + zero blockers) → audit is READY
        XCTAssertEqual(engine(t).ready(), ["CP-INDEPENDENT-AUDIT"])
        // attack 1: blocker-laden candidate refused (both engines)
        let m1 = try mutated(t, node: "CP-CONTROL-PLANE") { $0["blockers"] = ["BLK-H3"] }
        XCTAssertFalse(engine(m1).ready().contains("CP-INDEPENDENT-AUDIT"))
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.computedReady(twin: m1).contains("CP-INDEPENDENT-AUDIT"))
        // attack 2: implementation evidence stripped → refused
        let m2 = try mutated(t, node: "CP-CONTROL-PLANE") {
            var impl = $0["implementation"] as! [String: Any]; impl["refs"] = []; $0["implementation"] = impl
        }
        XCTAssertFalse(engine(m2).ready().contains("CP-INDEPENDENT-AUDIT"))
        // attack 3: test evidence stripped → refused
        let m3 = try mutated(t, node: "CP-CONTROL-PLANE") {
            var ts = $0["tests"] as! [String: Any]; ts["refs"] = []; $0["tests"] = ts
        }
        XCTAssertFalse(engine(m3).ready().contains("CP-INDEPENDENT-AUDIT"))
        // attack 4: a RANDOM ACTIVE node (P008, carries open-ish history) must not satisfy the edge
        var c = try deepCopy(t)
        var dc = try XCTUnwrap(c["dependency_contracts"] as? [String: [[String: Any]]])
        dc["CP-INDEPENDENT-AUDIT"] = [["node": "P001-DEVICE-MEASUREMENT", "requires": "CANDIDATE_READY"]]
        c["dependency_contracts"] = dc
        var ns = try XCTUnwrap(c["nodes"] as? [[String: Any]])
        let i = try XCTUnwrap(ns.firstIndex { ($0["id"] as? String) == "CP-INDEPENDENT-AUDIT" })
        ns[i]["depends_on"] = ["P001-DEVICE-MEASUREMENT"]; c["nodes"] = ns
        XCTAssertFalse(engine(c).ready().contains("CP-INDEPENDENT-AUDIT"),
                       "P001 is ACTIVE with evidence but carries OPEN blocker BLK-H4 — not a lawful candidate")
        // attack 5: standing FAIL verdict on the consumer blocks it
        let m5 = try mutated(t, node: "CP-INDEPENDENT-AUDIT") {
            var a = $0["audit"] as! [String: Any]; a["latest_verdict"] = "FIX REQUIRED — X"; $0["audit"] = a
        }
        XCTAssertFalse(engine(m5).ready().contains("CP-INDEPENDENT-AUDIT"), "standing FIX verdict blocks readiness")
    }

    // ═════════════════════════════ §12 OWN-BLOCKER / CLOSER-NODE LAW ═════════════════════════════

    func testA13_25_OwnBlockerLaw_ClosersStartable_UnknownsFailClosed() throws {
        let t = try twin()
        let e = engine(t)
        // S1: the closer nodes whose MISSION is their own open blockers become work-ready
        let s1 = e.ready(["CP-INDEPENDENT-AUDIT", "CP-CONTROL-PLANE"])
        XCTAssertTrue(s1.contains("RWC-PRE-02"), "closer law: PRE-02 startable while OWNING BLK-A11-IDCHARSET (OPEN)")
        XCTAssertTrue(s1.contains("RWC-PRE-04"), "closer law: PRE-04 startable while OWNING BLK-A11-APIBYPASS (OPEN)")
        XCTAssertTrue(s1.contains("RWC-PRE-13"), "closer law: PRE-13 startable while OWNING BLK-DEVICE-RWC-OPEN")
        XCTAssertEqual(e.blockerStatus["BLK-A11-IDCHARSET"], "OPEN")
        XCTAssertEqual(e.blockerStatus["BLK-A11-APIBYPASS"], "OPEN")
        // unknown blocker ID on a node fails closed
        let m = try mutated(t, node: "RWC-PRE-02") { $0["blockers"] = ["BLK-A11-IDCHARSET", "BLK-UNKNOWN-XYZ"] }
        XCTAssertFalse(engine(m).ready(["CP-INDEPENDENT-AUDIT", "CP-CONTROL-PLANE"]).contains("RWC-PRE-02"),
                       "unknown blocker ID vetoes readiness (fail closed)")
        // SEMANTIC DANGER AUDIT: own blockers never self-veto WORK, but they must still bind RELEASE.
        // EP3-PRESENTATION owns BLK-C4 (no calibrated score): its work-readiness under S10 does NOT
        // grant release/display — release stays bound by release.gate prose + the CODE gate (A13_27/32).
        XCTAssertEqual(e.str(e.nodes["EP3-PRESENTATION"] ?? [:], "status"), "BLOCKED")
        XCTAssertEqual(e.blockerStatus["BLK-C4"], "OPEN_BY_DESIGN")
        XCTAssertTrue((e.nodes["EP3-PRESENTATION"]?["release"] as? [String: Any])?["gate"] as? String ==
                      "ProductionScoreReleaseGateV1 + RWC audits", "release relation lives in release.gate, not blockers[]")
    }

    // ═════════════════════════════ §13 WORK-READY ≠ RELEASE-READY (S10 hard case) ═════════════════════════════

    func testA13_26_S10_FourAnswers_WorkYes_ReleaseNo_DisplayNo_AdmissionNo() throws {
        let t = try twin()
        var passed: Set<String> = ["CP-INDEPENDENT-AUDIT", "CP-CONTROL-PLANE"]
        passed.formUnion((1...14).map { String(format: "RWC-PRE-%02d", $0) })
        passed.formUnion(["RWC-CORPUS", "RWC-ANNOTATION", "RWC-FIT", "RWC-HELDOUT", "RWC-DEVICE-E2E"])
        let s10 = engine(t).ready(passed)
        // Q1 — may Presentation IMPLEMENTATION begin? YES (graph work-readiness; next.allowed_when met)
        XCTAssertTrue(s10.contains("EP3-PRESENTATION"), "S10: Presentation implementation work may begin")
        // Q2 — may Presentation RELEASE? NO: release.gate demands ProductionScoreReleaseGateV1 + RWC
        // audits; the CODE gate is closed and no engine state exists that could open it.
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0, "S10: release gate CLOSED in code")
        // Q3 — may a NUMERIC SCORE be displayed? NO: display law structurally OFF in code.
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed(), "S10: numeric display stays OFF")
        // Q4 — may PRODUCTION ADMISSION proceed? NO: EP8 is not even work-ready at S10.
        XCTAssertFalse(s10.contains("EP8-PRODUCTION-CIVILIZATION"), "S10: production admission not reachable")
        XCTAssertFalse(s10.contains("EP8-RELEASE-WAVES"))
        // exact S10 work-ready set (nothing else leaks open)
        XCTAssertEqual(s10, ["EP3-PRESENTATION", "EP3-CONTENT-AHEAD"])
        // A13-F3 (LOW, pinned current truth): the status machine has NO distinct RELEASE_READY /
        // LOCK_READY axis — READY is WORK-START readiness only; release readiness is prose
        // (release.gate) + CODE gates + THREE_VERDICT audits. The collapse authorizes nothing
        // (Q2/Q3/Q4 all independently refuse), but the distinction is not machine-representable.
        XCTAssertEqual(Set(try XCTUnwrap((t["node_statuses"] as? [String]))),
                       ["LOCKED", "ACTIVE", "READY", "BLOCKED", "PLANNED", "RETIRED"],
                       "A13-F3 pin: single READY status; no typed release-readiness state exists")
    }

    // ═════════════════════════════ §14 COMPUTED vs DECLARED / HOSTILE SNAPSHOTS ═════════════════════════════

    func testA13_27_ComputedEqualsDeclared_Live_BothEngines() throws {
        let t = try twin()
        XCTAssertEqual(engine(t).ready(), engine(t).declaredReady(), "my engine: computed == declared")
        XCTAssertEqual(ControlPlaneStateEvaluatorV1.computedReady(twin: t, requirementMap: try reqMap()),
                       ["CP-INDEPENDENT-AUDIT"], "builder engine agrees")
        XCTAssertEqual(engine(t).ready(), ["CP-INDEPENDENT-AUDIT"])
    }

    func testA13_28_HostileSnapshotEdits_AllOverridden() throws {
        let t = try twin()
        for victim in ["RWC-CORPUS", "EP3-PRESENTATION", "RWC-PRE-14", "EP6-BOUNDED-LEARNING"] {
            let m = try mutated(t, node: victim) { $0["status"] = "READY"; $0["blocked_by"] = [] }
            let e = engine(m)
            XCTAssertFalse(e.ready().contains(victim), "\(victim): snapshot READY recomputed away")
            XCTAssertTrue(e.declaredReady().contains(victim), "hostile snapshot IS declared…")
            XCTAssertNotEqual(e.ready(), e.declaredReady(),
                              "…so computed != declared — the CP12 equality law must fail this twin")
            XCTAssertFalse(ControlPlaneStateEvaluatorV1.computedReady(twin: m).contains(victim),
                           "\(victim): builder evaluator also refuses")
        }
        // blocked_by emptied while still BLOCKED → the blocked-without-reason law (CP03 logic) fails
        let m = try mutated(t, node: "RWC-CORPUS") { $0["blocked_by"] = []; $0["blockers"] = [] }
        let node = try XCTUnwrap((m["nodes"] as? [[String: Any]])?.first { ($0["id"] as? String) == "RWC-CORPUS" })
        let reasons = ((node["blocked_by"] as? [String]) ?? []) + ((node["blockers"] as? [String]) ?? [])
        XCTAssertEqual(node["status"] as? String, "BLOCKED")
        XCTAssertTrue(reasons.isEmpty, "mutation applied…")
        XCTAssertFalse(engine(m).ready().contains("RWC-CORPUS"),
                       "…and corpus STILL not ready (gate RWC-PRE-14 is canonical in gates[], not in the mirror)")
    }

    // ═════════════════════════════ §15 GATE-REGISTRY PROSE-GAP SCAN ═════════════════════════════

    func testA13_29_ProseGapScan_NoEntryProhibitionWithoutStructure() throws {
        let t = try twin()
        let e = engine(t)
        // S1 census: EXACTLY the seven CP-audit-gated entry nodes unlock on CP PASS — nothing else
        let s1 = e.ready(["CP-INDEPENDENT-AUDIT", "CP-CONTROL-PLANE"])
        XCTAssertEqual(s1, ["RWC-PRE-01", "RWC-PRE-02", "RWC-PRE-03", "RWC-PRE-04", "RWC-PRE-05",
                            "RWC-PRE-13", "EP3-CONTENT-AHEAD"])
        // every node whose prose says "prohibited until RWC-PRE-14 PASS / RWC program PASS" is
        // structurally outside S1 (the EP3-CONTENT-AHEAD prose-only gate class is closed)
        for (id, n) in e.nodes {
            let proh = ((n["next"] as? [String: Any])?["prohibited_until"] as? String) ?? ""
            if proh.contains("RWC-PRE-14") || proh.contains("RWC program") {
                XCTAssertFalse(s1.contains(id), "prose-blocked node engine-ready at S1: \(id)")
            }
        }
        // EP3-CONTENT-AHEAD's once-prose CP gate is now structural in gates[]
        XCTAssertEqual(e.gates["EP3-CONTENT-AHEAD"], ["CP-INDEPENDENT-AUDIT"])
        XCTAssertFalse(e.ready().contains("EP3-CONTENT-AHEAD"), "live: still gated")
        // corpus/annotation/fit/heldout all carry the structural PRE-14 gate
        for id in ["RWC-CORPUS", "RWC-ANNOTATION", "RWC-FIT", "RWC-HELDOUT"] {
            XCTAssertEqual(e.gates[id], ["RWC-PRE-14"], "\(id): PRE-14 gate structural")
        }
        // deeper prohibitions (EP4+: prohibited until EP3-PRESENTATION) stay closed even at S10
        var passed: Set<String> = ["CP-INDEPENDENT-AUDIT", "CP-CONTROL-PLANE"]
        passed.formUnion((1...14).map { String(format: "RWC-PRE-%02d", $0) })
        passed.formUnion(["RWC-CORPUS", "RWC-ANNOTATION", "RWC-FIT", "RWC-HELDOUT", "RWC-DEVICE-E2E"])
        let s10 = e.ready(passed)
        for (id, n) in e.nodes where (((n["next"] as? [String: Any])?["prohibited_until"] as? String) ?? "").contains("EP3-PRESENTATION") {
            XCTAssertFalse(s10.contains(id), "\(id): EP4+ node leaks open at S10")
        }
        // A13-F6 (INFO pin): schema addendum says the legacy mirror equals gates[]+blockers "exactly",
        // but EP3-CONTENT-AHEAD's new structural gate deliberately lives ONLY in gates[] (mirror is
        // byte-stable for frozen probes) — the wording overstates the enforced law. Current truth:
        let blockedBy = Set((e.nodes["EP3-CONTENT-AHEAD"]?["blocked_by"] as? [String]) ?? [])
        XCTAssertFalse(blockedBy.contains("CP-INDEPENDENT-AUDIT"), "A13-F6 pin: mirror does NOT carry the new gate")
    }

    // ═════════════════════════════ §16/§17 TRANSITIONS + VERDICT COHERENCE ═════════════════════════════

    func testA13_30_LifecycleTransitions_MachineVsProse_HonestClassification() throws {
        let t = try twin()
        let e = engine(t)
        // PLANNED→READY is machine-computed (EP3-CONTENT-AHEAD enters READY exactly at S1) — proven above.
        // ACTIVE→LOCKED with a standing FIX/FAIL verdict: machine-refused (both engines)
        let m = try mutated(t, node: "P009D-POLICY") {
            var a = $0["audit"] as! [String: Any]; a["latest_verdict"] = "FAIL — hostile"; $0["audit"] = a
        }
        let mutatedNode = try XCTUnwrap((m["nodes"] as? [[String: Any]])?.first { ($0["id"] as? String) == "P009D-POLICY" })
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.verdictStatusCoherent(node: mutatedNode, hasResolutionRecord: false),
                       "LOCKED + FAIL without resolution is machine-illegal")
        XCTAssertTrue(ControlPlaneStateEvaluatorV1.verdictStatusCoherent(node: mutatedNode, hasResolutionRecord: true),
                      "the ONLY escape is an explicit resolution record")
        // live data: every LOCKED node carries a PASS-class audit status (P009E honestly
        // PASS_WITH_LIMITATION) — no prose-held lock today
        for (id, n) in e.nodes where e.str(n, "status") == "LOCKED" {
            XCTAssertTrue((((n["audit"] as? [String: Any])?["status"] as? String) ?? "").hasPrefix("PASS"), id)
        }
        // HONEST CLASSIFICATION (report §16): ACTIVE→LOCKED *without any verdict at all* is NOT
        // machine-refused (verdictStatusCoherent only fires on FAIL/FIX text). Pin of current truth:
        let m2 = try mutated(t, node: "CP-CONTROL-PLANE") { $0["status"] = "LOCKED" }
        let hostileLock = try XCTUnwrap((m2["nodes"] as? [[String: Any]])?.first { ($0["id"] as? String) == "CP-CONTROL-PLANE" })
        XCTAssertTrue(ControlPlaneStateEvaluatorV1.verdictStatusCoherent(node: hostileLock, hasResolutionRecord: false),
                      "pinned: lock-without-audit is caught by status pins/reviews, not by a generic machine law — " +
                      "lifecycle enforcement remains PARTLY PROSE (carried as explicit non-governing limitation)")
    }

    func testA13_31_ContradictionUpgradeLaws_AllMutantsRefused() throws {
        let t = try twin()
        let p008 = try XCTUnwrap(engine(t).nodes["P008-CALIBRATION-PILOT"])
        // (a) CONTRADICTED → VWL without resolution: refused
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.legalAxisTransition(
            axis: "calibration", from: "CONTRADICTED", to: "VERIFIED_WITH_LIMITATIONS",
            ctx: .init(hasResolutionRecord: false, node: p008)))
        // (b) with a FAKE resolution: the ledger carries NO subject for P008 calibration, so a truthful
        // caller may not pass hasResolutionRecord=true — pin the ledger truth that forbids it
        XCTAssertFalse(try ledgerSubjects().contains("P008"), "no P008 resolution subject exists in the ledger")
        // (c) WITH resolution but WITHOUT axis-compatible evidence: still refused (evidence law)
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.legalAxisTransition(
            axis: "calibration", from: "CONTRADICTED", to: "VERIFIED_WITH_LIMITATIONS",
            ctx: .init(hasResolutionRecord: true, node: p008)),
            "P008 has no calibration_refs — upgrade illegal even with a resolution record")
        // (d) live twin keeps the contradiction visible
        XCTAssertEqual((p008["truth"] as? [String: Any])?["calibration"] as? String, "CONTRADICTED")
    }

    // ═════════════════════════════ §19/§20 AXIS EVIDENCE DEPTH ═════════════════════════════

    func testA13_32_AxisEvidenceLaw_MutantsAndOutcomeBlindness_FINDING() throws {
        let t = try twin()
        // device VERIFIED without device refs → refused by both the transition and live laws
        let mesh = try XCTUnwrap(engine(t).nodes["P009B-EXPERT-MESH"])
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.legalAxisTransition(
            axis: "real_device", from: "UNVERIFIED", to: "VERIFIED",
            ctx: .init(hasResolutionRecord: true, node: mesh)))
        let m1 = try mutated(t, node: "P009B-EXPERT-MESH") {
            var tr = $0["truth"] as! [String: Any]; tr["real_device"] = "VERIFIED"; $0["truth"] = tr
        }
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.axisEvidenceViolations(twin: m1).isEmpty)
        // calibration VERIFIED anywhere is blocked by the suite-level FM-012 pin (CP05) AND the live twin
        for (_, n) in engine(t).nodes {
            XCTAssertNotEqual((n["truth"] as? [String: Any])?["calibration"] as? String, "VERIFIED")
        }
        // security VERIFIED with an irrelevant-but-existing audit ref: PASSES the existence-only law —
        // A13-F4 (LOW, pinned current truth): axisEvidenceLaw checks evidence-class EXISTENCE, not
        // OUTCOME/RELEVANCE. Not exploitable on the live twin (every LOCKED node's audit.status is
        // PASS — see A13_30 — and CP05 pins calibration); forward-hardening for RWC phases.
        let m2 = try mutated(t, node: "RWC-ENTRY-GATE") {
            var tr = $0["truth"] as! [String: Any]; tr["security"] = "VERIFIED"; $0["truth"] = tr
        }
        let violations = ControlPlaneStateEvaluatorV1.axisEvidenceViolations(twin: m2)
        XCTAssertFalse(violations.contains { $0.contains("RWC-ENTRY-GATE.security") },
                       "A13-F4 pin: outcome-blind — an audit ref's VERDICT is not consulted by the axis law")
        // privacy VERIFIED with audit refs present: same blindness class, same pin
        let m3 = try mutated(t, node: "P009E-CALIBRATION") {
            var tr = $0["truth"] as! [String: Any]; tr["privacy"] = "VERIFIED"; $0["truth"] = tr
        }
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.axisEvidenceViolations(twin: m3)
            .contains { $0.contains("P009E-CALIBRATION.privacy") }, "A13-F4 pin (privacy variant)")
        // but a node with NO audit refs at all still fails the law (existence check is real)
        let m4 = try mutated(t, node: "RWC-PRE-01") {
            var tr = $0["truth"] as! [String: Any]; tr["privacy"] = "VERIFIED"; $0["truth"] = tr
        }
        XCTAssertTrue(ControlPlaneStateEvaluatorV1.axisEvidenceViolations(twin: m4)
            .contains { $0.contains("RWC-PRE-01.privacy") })
    }

    func testA13_33_HumanProductAxis_VersionedUnavailability_NoAdHocDoor() throws {
        let t = try twin()
        // never upgradable today — evaluator law
        let any = try XCTUnwrap(engine(t).nodes["P009A-IDENTITY-FOUNDATION"])
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.legalAxisTransition(
            axis: "human_product", from: "UNVERIFIED", to: "VERIFIED_WITH_LIMITATIONS",
            ctx: .init(hasResolutionRecord: true, node: any)))
        XCTAssertEqual(ControlPlaneStateEvaluatorV1.axisEvidenceLaw["human_product"], [])
        // no node claims verified-class human truth
        for (id, n) in engine(t).nodes {
            let v = (n["truth"] as? [String: Any])?["human_product"] as? String
            XCTAssertFalse(v == "VERIFIED" || v == "VERIFIED_WITH_LIMITATIONS", id)
        }
        // forward architecture is VERSIONED, not a dead end: the authority matrix names the owning
        // evidence class (REAL_WORLD_HUMAN_CALIBRATION) and the documented reason
        let auth = try json("docs/control-plane/GEN8_EVIDENCE_AUTHORITY.yaml")
        let hp = try XCTUnwrap((auth["domains"] as? [String: Any])?["human_product"] as? [String: Any])
        XCTAssertEqual((hp["dominant"] as? [String]), ["REAL_WORLD_HUMAN_CALIBRATION"],
                       "upgrade door is the human-calibration evidence class (RWC/human program), not ad hoc")
        XCTAssertTrue(((hp["note"] as? String) ?? "").contains("no evidence class exists"),
                      "unavailability explicitly documented")
        XCTAssertEqual(auth["authority_version"] as? String, "1.0.0", "versioned")
    }

    // ═════════════════════════════ §21/§22 VANISH LAWS — FULL CENSUS ═════════════════════════════

    func testA13_34_BlockerVanish_All22Fail() throws {
        let t = try twin()
        let subjects = try ledgerSubjects()
        XCTAssertEqual(a13VanishViolations(twin: t, ledgerSubjects: subjects), [], "live: nothing vanished")
        for victim in all22Blockers {
            var c = try deepCopy(t)
            var bl = try XCTUnwrap(c["blockers"] as? [[String: Any]])
            bl.removeAll { ($0["id"] as? String) == victim }
            c["blockers"] = bl
            // no blocker has a deletion-resolution subject in the ledger → every deletion is unlawful
            XCTAssertEqual(a13VanishViolations(twin: c, ledgerSubjects: subjects), [victim],
                           "\(victim): deletion without resolution record must fail (no famous-subset shortcut)")
        }
    }

    func testA13_35_NegativeTruthVanish_All9Fail() throws {
        let t = try twin()
        let subjects = try ledgerSubjects()
        for victim in all9NTs {
            var c = try deepCopy(t)
            var nts = try XCTUnwrap(c["negative_truth"] as? [[String: Any]])
            nts.removeAll { ($0["id"] as? String) == victim }
            c["negative_truth"] = nts
            XCTAssertEqual(a13VanishViolations(twin: c, ledgerSubjects: subjects), [victim],
                           "\(victim): NT deletion without resolution record must fail")
        }
        // the five mandate-named NTs are indeed in the census
        for named in ["NT-PREVDWELL", "NT-THERMAL-EVIDENCE-BUILD", "NT-P008-PILOT-FAILED", "NT-F1-COVERAGE", "NT-APIBYPASS"] {
            XCTAssertTrue(all9NTs.contains(named))
        }
    }

    // ═════════════════════════════ §18 RESOLUTION LEDGER ═════════════════════════════

    func testA13_36_ResolutionLedger_RealPriorStates_NoInventedClosure() throws {
        let l = try ledger()
        let recs = try XCTUnwrap(l["records"] as? [[String: Any]])
        XCTAssertEqual(recs.compactMap { $0["id"] as? String },
                       ["RES-001", "RES-002", "RES-003", "RES-004", "RES-006", "RES-005"],
                       "RES-006 inserted at governing lock (inversion I-3, AUDIT13_INVERSION_LOCK.md)")
        for r in recs {
            XCTAssertFalse(((r["prior_state"] as? String) ?? "").isEmpty)
            XCTAssertFalse(((r["evidence"] as? [String]) ?? []).isEmpty, "\(r["id"]!): evidence required")
            XCTAssertFalse(((r["audit_ref"] as? String) ?? "").isEmpty)
            for e in (r["evidence"] as? [String]) ?? [] where e.hasPrefix("docs/") {
                XCTAssertTrue(exists(e), "\(r["id"]!): evidence file \(e)")
            }
        }
        // RES-001/002 prior states are REAL (fabricated strings preserved in frozen AUDIT12 evidence)
        let frozen = try text("docs/audit/AUDIT12_UluEvrenControlPlaneProbes_ORIGINAL_LOCKED.swift.txt")
        XCTAssertTrue(frozen.contains("gen8-p009b-expert-mesh-r1-reaudit-pass"))
        // RES-003 prior state real (path absent), new state real (file exists)
        XCTAssertFalse(exists("docs/implementation/P009D_IMPLEMENTATION_EVIDENCE.md"))
        XCTAssertTrue(exists("docs/intelligence/P009D_POLICY_INTELLIGENCE.md"))
        // RES-004 applied: living registry metadata says 36
        XCTAssertTrue(try text("docs/requirements/REQUIREMENTS_REGISTRY.yaml").contains("count: 36"))
        // RES-005 applied: CP node privacy/security honestly LAB_ONLY while its audit is pending
        let cp = try XCTUnwrap(engine(try twin()).nodes["CP-CONTROL-PLANE"])
        XCTAssertEqual((cp["truth"] as? [String: Any])?["privacy"] as? String, "LAB_ONLY")
        XCTAssertEqual((cp["truth"] as? [String: Any])?["security"] as? String, "LAB_ONLY")
        XCTAssertEqual((cp["audit"] as? [String: Any])?["status"] as? String, "PENDING")
        // BLK-H1 deliberately NOT closed here — stale-ledger truth stays visible
        let open = try XCTUnwrap(l["open_subjects_not_resolved_here"] as? [[String: Any]])
        XCTAssertTrue((open.first?["subject"] as? String ?? "").contains("BLK-H1"))
        // A13-F8 FIXED for RES-001..005 exactly as this pin prescribed ("re-anchored to the candidate
        // SHA at lock time via the ledger"; inversion I-3): machine-resolvable 12300e6. The NEWEST
        // record (RES-006) structurally cannot carry its own commit SHA — it keeps the symbolic label
        // plus a machine anchor_tag (documented latest-record limitation, carried).
        for r in recs where (r["id"] as? String) != "RES-006" {
            XCTAssertEqual(r["effective_commit"] as? String, "12300e6", "A13-F8 FIXED: machine-resolvable anchor")
        }
        let res6 = try XCTUnwrap(recs.first { ($0["id"] as? String) == "RES-006" })
        XCTAssertEqual(res6["effective_commit"] as? String, "CP-GOVERNING-LOCK")
        XCTAssertEqual(res6["anchor_tag"] as? String, "gen8-ulu-evren-control-plane-r1-locked-governing",
                       "latest-record anchor is the governing lock tag (resolvable post-lock)")
    }

    // ═════════════════════════════ §23 AUTHORITY MATRIX ═════════════════════════════

    func testA13_37_AuthorityMatrix_DomainConflicts_NoGlobalRanking() throws {
        let auth = try json("docs/control-plane/GEN8_EVIDENCE_AUTHORITY.yaml")
        let domains = try XCTUnwrap(auth["domains"] as? [String: Any])
        func domain(_ d: String) throws -> [String: Any] { try XCTUnwrap(domains[d] as? [String: Any]) }
        // conflict 1: builder device-VERIFIED vs device-audit-OPEN → builder claim can never upgrade
        let dev = try domain("real_device")
        XCTAssertTrue(((dev["can_never_upgrade"] as? [String]) ?? []).contains("BUILDER_CLAIM"))
        XCTAssertTrue(((dev["can_never_upgrade"] as? [String]) ?? []).contains("IMPLEMENTATION_AND_TESTS"))
        XCTAssertEqual(dev["dominant"] as? [String], ["MEASURED_REAL_DEVICE"], "OPEN wins until measured on device")
        // conflict 2: view-says-calibrated vs RWC LAB_ONLY → lab benchmarks can never upgrade calibration
        let cal = try domain("calibration")
        XCTAssertTrue(((cal["can_never_upgrade"] as? [String]) ?? []).contains("LAB_BENCHMARK"))
        let laws = (auth["conflict_law"] as? [String] ?? []).joined(separator: " | ")
        XCTAssertTrue(laws.contains("generated view stronger than canonical twin -> view is wrong by definition"))
        // conflict 3: device-good vs privacy-unresolved → device may upgrade, privacy may NOT
        XCTAssertTrue(laws.contains("device runtime proven + privacy unresolved -> real_device axis may improve, privacy axis may NOT"))
        let priv = try domain("privacy")
        XCTAssertTrue(((priv["can_never_upgrade"] as? [String]) ?? []).contains("MEASURED_REAL_DEVICE"))
        // audit FAIL + newer builder PASS prose → FAIL stands
        XCTAssertTrue(laws.contains("audit FAIL + newer builder PASS prose -> FAIL stands until an independent re-audit resolution"))
        // NO one-dimensional global ranking: domain-specific dominants differ
        XCTAssertNotEqual(try domain("real_device")["dominant"] as? [String],
                          try domain("privacy")["dominant"] as? [String])
        XCTAssertTrue(((auth["format_law"] as? String) ?? "").contains("NO single global ranking"))
        // ENFORCEMENT CLASSIFICATION (report §23, honest): the matrix is DECLARATIVE with partial
        // machine anchors — the evaluator never reads this file; hard-coded evaluator laws cover the
        // device/calibration/CONTRADICTED anchors, CP15 checks matrix presence. Pin of current truth:
        let evaluator = try text("packages/GuardianKit/Tests/GuardianCoreTests/ControlPlaneStateEvaluatorV1.swift")
        XCTAssertFalse(evaluator.contains("EVIDENCE_AUTHORITY"),
                       "pinned: evaluator does not consume the authority matrix (partially declarative)")
    }

    // ═════════════════════════════ §24/§25 INDEPENDENT RWC FUTURE-STATE LADDER ═════════════════════════════

    func testA13_38_IndependentLadder_S0toS10() throws {
        let t = try twin()
        let e = engine(t)
        // S0 — current: ONLY the control-plane audit is work-ready
        XCTAssertEqual(e.ready(), ["CP-INDEPENDENT-AUDIT"])
        // S1 — CP PASS: initial PRE lanes (exact set asserted in A13_29)
        var passed: Set<String> = ["CP-INDEPENDENT-AUDIT", "CP-CONTROL-PLANE"]
        XCTAssertTrue(e.ready(passed).contains("RWC-PRE-01"))
        XCTAssertFalse(e.ready(passed).contains("RWC-PRE-06"), "PRE-06 needs PRE-05 first (lane order)")
        // S2 — one PRE missing (PRE-07, a different hole than the builder's test): PRE-14 not ready
        passed.formUnion(["RWC-PRE-01", "RWC-PRE-02", "RWC-PRE-03", "RWC-PRE-04", "RWC-PRE-05", "RWC-PRE-06",
                          "RWC-PRE-08", "RWC-PRE-09", "RWC-PRE-10", "RWC-PRE-11", "RWC-PRE-12", "RWC-PRE-13"])
        XCTAssertFalse(e.ready(passed).contains("RWC-PRE-14"), "S2: PRE-14 demands ALL thirteen lanes")
        XCTAssertFalse(e.ready(passed).contains("RWC-CORPUS"))
        // S3 — all 13: PRE-14 ready
        passed.insert("RWC-PRE-07")
        XCTAssertTrue(e.ready(passed).contains("RWC-PRE-14"), "S3")
        // S4 — PRE-14 merely ACTIVE: corpus forbidden (typed GATE_PASS, not status theater)
        let active14 = try mutated(t, node: "RWC-PRE-14") { $0["status"] = "ACTIVE" }
        XCTAssertFalse(engine(active14).ready(passed).contains("RWC-CORPUS"), "S4: ACTIVE audit never unlocks corpus")
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.computedReady(twin: active14, passed: passed).contains("RWC-CORPUS"))
        // S5 — PRE-14 PASS: corpus ready
        passed.insert("RWC-PRE-14")
        XCTAssertTrue(e.ready(passed).contains("RWC-CORPUS"), "S5")
        // S6 — corpus done, annotation absent: fit forbidden
        passed.insert("RWC-CORPUS")
        XCTAssertTrue(e.ready(passed).contains("RWC-ANNOTATION"))
        XCTAssertFalse(e.ready(passed).contains("RWC-FIT"), "S6: no fit without annotation")
        // S7 — annotation done: fit ready ONLY through the canonical door
        passed.insert("RWC-ANNOTATION")
        XCTAssertTrue(e.ready(passed).contains("RWC-FIT"), "S7")
        let fitAvail = try XCTUnwrap((e.nodes["RWC-FIT"]?["capability"] as? [String: Any])?["availability"] as? String)
        XCTAssertTrue(fitAvail.contains("MUST enter via CalibrationRunPreparationV1"),
                      "S7: canonical calibration door law on the node")
        XCTAssertTrue(fitAvail.contains("RWC-PRE-04"), "S7: door ownership (PRE-04 invariant)")
        // S8 — fit done, held-out incomplete: production score surfaces forbidden
        passed.insert("RWC-FIT")
        XCTAssertFalse(e.ready(passed).contains("EP3-PRESENTATION"), "S8: no presentation without held-out")
        XCTAssertFalse(e.ready(passed).contains("RWC-DEVICE-E2E"), "S8: device E2E waits for held-out")
        // S9 — held-out done, device absent: release/presentation admission forbidden
        passed.insert("RWC-HELDOUT")
        XCTAssertFalse(e.ready(passed).contains("EP3-PRESENTATION"), "S9: device E2E still required")
        XCTAssertTrue(e.ready(passed).contains("RWC-DEVICE-E2E"), "S9: device E2E itself becomes work-ready")
        // S10 — handled exhaustively in A13_26 (four-answer analysis)
        passed.insert("RWC-DEVICE-E2E")
        XCTAssertTrue(e.ready(passed).contains("EP3-PRESENTATION"))
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0, "S10: score release gate closed in CODE regardless")
    }

    func testA13_39_Pre04CanonicalDoor_StructuralChainProof() throws {
        let t = try twin()
        let e = engine(t)
        // the open bypass finding is owned by PRE-04 and still visible
        XCTAssertEqual(e.blockerStatus["BLK-A11-APIBYPASS"], "OPEN")
        XCTAssertTrue(e.arr(try XCTUnwrap(e.nodes["RWC-PRE-04"]), "blockers").contains("BLK-A11-APIBYPASS"))
        XCTAssertTrue(((t["negative_truth"] as? [[String: Any]]) ?? [])
            .contains { ($0["id"] as? String) == "NT-APIBYPASS" })
        // chain: everything passed EXCEPT PRE-04 → PRE-14, corpus, fit all stay forbidden
        var passed: Set<String> = ["CP-INDEPENDENT-AUDIT", "CP-CONTROL-PLANE"]
        passed.formUnion((1...13).compactMap { $0 == 4 ? nil : String(format: "RWC-PRE-%02d", $0) })
        let r = e.ready(passed)
        XCTAssertFalse(r.contains("RWC-PRE-14"), "PRE-14 contract demands PRE-04 LOCKED")
        XCTAssertFalse(r.contains("RWC-CORPUS"))
        // the protection for fit is the PRE-14 contract chain — assert it structurally:
        let pre14Contracts = (t["dependency_contracts"] as? [String: [[String: Any]]])?["RWC-PRE-14"] ?? []
        XCTAssertTrue(pre14Contracts.contains { ($0["node"] as? String) == "RWC-PRE-04" && ($0["requires"] as? String) == "LOCKED" },
                      "PRE-04 is a LOCKED-contract input to the preregistration audit")
        XCTAssertEqual(e.gates["RWC-FIT"], ["RWC-PRE-14"], "fit gate = PRE-14 (which structurally owns PRE-04)")
        // and no fitting happened in this audit: dataset untouched (59 synthetic pairs), guard v2
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59)
        XCTAssertEqual(CalibrationRunGuardV1.revision, "calibration-run-guard-v2")
    }

    // ═════════════════════════════ §26 PRODUCTION-CODE TRUTH ═════════════════════════════

    func testA13_40_ProductionCodeTruth_ControlPlaneCannotOverride() throws {
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0, "production score gate CLOSED")
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed(), "display structurally OFF")
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims)
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59, "no dataset growth in R1")
        // the graph agrees with code (never the other way around)
        let e = engine(try twin())
        XCTAssertEqual(e.str(try XCTUnwrap(e.nodes["EP3-PRESENTATION"]), "status"), "BLOCKED")
        XCTAssertEqual(e.str(try XCTUnwrap(e.nodes["RWC-CORPUS"]), "status"), "BLOCKED")
        XCTAssertEqual((e.nodes["P009E-CALIBRATION"]?["release"] as? [String: Any])?["gate"] as? String,
                       "ProductionScoreReleaseGateV1 CLOSED")
    }

    // ═════════════════════════════ §30/§31/§32 VIEWS, PROGRESS, CARRIED ═════════════════════════════

    func testA13_41_ViewsConsistentWithIndependentRecount() throws {
        let t = try twin()
        let e = engine(t)
        // my own recount
        XCTAssertEqual(e.nodes.count, 60)
        XCTAssertEqual(e.nodes.values.reduce(0) { $0 + (($1["depends_on"] as? [String])?.count ?? 0) }, 75)
        XCTAssertEqual(Set(e.nodes.values.compactMap { $0["program"] as? String }).count, 10)
        XCTAssertEqual((t["blockers"] as? [[String: Any]])?.count, 22)
        XCTAssertEqual((t["negative_truth"] as? [[String: Any]])?.count, 9)
        // view carries the SAME computed numbers (A12-F1 closure holds against MY recount)
        let cs = try text("docs/control-plane/CURRENT_STATE.md")
        XCTAssertTrue(cs.contains("60 nodes · 75 depends_on edges · 10 programs"))
        XCTAssertTrue(cs.contains("22 blockers · 9 negative truths"))
        XCTAssertTrue(cs.contains("257 total / 167 machine-resolvable / 90 semantic /"))
        XCTAssertTrue(cs.contains("0 broken"))
        // no view implies governance / started RWC work / calibrated score
        XCTAssertTrue((e.nodes["CP-CONTROL-PLANE"]?["limitations"] as? [String] ?? []).joined()
            .contains("becomes governing system ONLY after independent control-plane audit PASS"))
        XCTAssertTrue(try text("docs/control-plane/EPOCH_STATUS.md")
            .contains("Zero corpus, zero human annotation, zero real fitting"))
        XCTAssertTrue(try text("docs/control-plane/CLAIM_TRUTH_MATRIX.md")
            .contains("FORBIDDEN CLAIM — FALSE"), "real-world-calibrated stays a forbidden claim")
        let naw = try text("docs/control-plane/NEXT_ALLOWED_WORK.md")
        XCTAssertTrue(naw.contains("READY now (exactly one)"))
        XCTAssertTrue(naw.contains("CP-INDEPENDENT-AUDIT"))
        XCTAssertTrue(naw.contains("Corpus acquisition (needs RWC-PRE-14 PASS)"))
        XCTAssertTrue(naw.contains("Production score display; Presentation/Glyph/Motion"))
        // A13-F5 (INFO, pinned current truth): the living corrections record still carries the
        // intermediate census (251/161) superseded by the final candidate census (257/167).
        let corr = try text("docs/control-plane/CONTROL_PLANE_R1_REFERENCE_CORRECTIONS.md")
        XCTAssertTrue(corr.contains("total 251 · machine-resolvable 161"),
                      "A13-F5 pin: stale intermediate census figure in the living correction record")
    }

    func testA13_42_ProgressModel_OverallReproducible_BCDNarrative() throws {
        // overall ≈ 13.34 from the documented weights — reproduced independently
        let weights: [Double] = [18, 12, 20, 12, 14, 8, 10, 6]
        let completion: [Double] = [0.60, 0.08, 0.02, 0.03, 0.01, 0.03, 0.02, 0.04]
        let overall = zip(weights, completion).map(*).reduce(0, +)
        XCTAssertEqual(overall, 13.34, accuracy: 0.001)
        let cs = try text("docs/control-plane/CURRENT_STATE.md")
        XCTAssertTrue(cs.contains("OVERALL VISION PROGRESS ≈ 13%"), "view rounds the reproducible 13.34")
        // B/C/D are labeled narrative with zero authorization effect — label present on all three
        XCTAssertEqual(cs.components(separatedBy: "NARRATIVE PLANNING ESTIMATE").count - 1, 3)
        XCTAssertTrue(cs.contains("never governs phase authorization"))
    }

    func testA13_43_CarriedLowInfo_AllStillVisible_NoneSilentlyClosed() throws {
        let t = try twin()
        let e = engine(t)
        // A12-F7 wave sink — carried, documented (not claimed enforced)
        XCTAssertTrue(try text("docs/control-plane/GEN8_CONTROL_PLANE_R1_REMEDIATION_REPORT.md")
            .contains("A12-F7 (LOW, wave sink)"))
        // A12-F8 — narrative labels (asserted in A13_42)
        // A12-F9 — the two prose-hybrid source paths still present and honestly non-machine
        let hybrids = ((t["sources"] as? [[String: Any]]) ?? [])
            .compactMap { $0["path"] as? String }.filter { $0.contains(" ") }
        XCTAssertEqual(hybrids.count, 2, "A12-F9 carried: exactly the two prose-hybrid source paths")
        // A12-F11 — stale ECE .220 ledger row immutable; twin uses the audited .250
        XCTAssertTrue(try text("docs/audit/GEN8_CLAIM_EVIDENCE_LEDGER.csv").contains("ECE .220"))
        let calRefs = ((e.nodes["P009E-CALIBRATION"]?["evidence"] as? [String: Any])?["calibration_refs"] as? [String] ?? []).joined()
        XCTAssertTrue(calRefs.contains("ECE .250"), "twin carries the audited value, not the stale row")
        // A12-F5 — deprecated blocked_by mirror still present (removal scheduled via ledger)
        XCTAssertNotNil(e.nodes["RWC-CORPUS"]?["blocked_by"], "legacy mirror field still exists")
        XCTAssertTrue(((t["edge_law"] as? String) ?? "").contains("DEPRECATED LEGACY MIRROR"))
        // BLK-H1 STALE_LEDGER — flagged, not silently closed
        XCTAssertEqual(e.blockerStatus["BLK-H1"], "STALE_LEDGER")
        XCTAssertTrue(try text("docs/control-plane/CURRENT_STATE.md").contains("STALE_LEDGER"))
        // ECE gate truth carried
        XCTAssertEqual(e.blockerStatus["BLK-ECE-UNMET"], "OPEN")
        XCTAssertEqual(e.blockerStatus["BLK-DEVICE-RWC-OPEN"], "OPEN")
        XCTAssertEqual(e.blockerStatus["BLK-H3"], "OPEN")
        XCTAssertEqual(e.blockerStatus["BLK-GH-CREDENTIALS"], "OPEN")
    }

    // ═════════════════════════════ RWC / CONTROL-PLANE LOCKS (final) ═════════════════════════════

    func testA13_44_LocksHold_ControlPlaneStillNonGoverning() throws {
        let e = engine(try twin())
        // control plane is NOT governing: its own node is ACTIVE/UNVERIFIED with audit PENDING
        let cp = try XCTUnwrap(e.nodes["CP-CONTROL-PLANE"])
        XCTAssertEqual(e.str(cp, "status"), "ACTIVE")
        XCTAssertEqual((cp["truth"] as? [String: Any])?["overall"] as? String, "UNVERIFIED")
        XCTAssertEqual((cp["audit"] as? [String: Any])?["status"] as? String, "PENDING")
        // every RWC-PRE lane and every RWC execution node stays BLOCKED in the live twin
        for i in 1...14 { XCTAssertEqual(e.str(e.nodes[String(format: "RWC-PRE-%02d", i)] ?? [:], "status"), "BLOCKED") }
        for id in ["RWC-CORPUS", "RWC-ANNOTATION", "RWC-FIT", "RWC-HELDOUT", "RWC-DEVICE-E2E", "EP3-PRESENTATION"] {
            XCTAssertEqual(e.str(e.nodes[id] ?? [:], "status"), "BLOCKED", id)
        }
        // remediation report records the locks in prose too
        let rep = try text("docs/control-plane/GEN8_CONTROL_PLANE_R1_REMEDIATION_REPORT.md")
        XCTAssertTrue(rep.contains("NON-GOVERNING"))
        XCTAssertTrue(rep.contains("corpus/annotation/fitting/held-out"))
    }
}
