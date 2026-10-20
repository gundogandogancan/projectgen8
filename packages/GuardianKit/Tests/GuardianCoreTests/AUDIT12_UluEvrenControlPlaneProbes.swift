import XCTest
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT12 — ULU EVREN CONTROL PLANE — INDEPENDENT CLEAN-SESSION RED-TEAM PROBES (add-only).
//
// Candidate: 4d6649c7a67a22c0b5eed5f1fd94bd3f3d25e8f8 (tag gen8-ulu-evren-control-plane-audit-candidate)
// Predecessor lock: e983b360711d96f0af51b853ab05d889aaedb0e8 (gen8-rwc-entry-gate-r1-locked-engineering)
//
// DOCTRINE (same as AUDIT2..AUDIT11 probe families):
//   • Probes assert the CANDIDATE AS-IS. Defects are PINNED as current truth with FINDING
//     annotations (A12-Fxx), never fixed here. If a pinned defect is later fixed, the pin flips
//     and must be inverted via the frozen-original + manifest discipline (FM-003).
//   • All mutation tests operate on IN-MEMORY DEEP COPIES. No canonical file is ever modified.
//   • The builder's 9 ControlPlaneValidationTests are REIMPLEMENTED here (independently) so each
//     mutation records which existing builder check catches it vs which needs future hardening.
//
// FINDINGS PINNED BY THIS FILE (full report: docs/audit/GEN8_ULU_EVREN_CONTROL_PLANE_INDEPENDENT_AUDIT.md)
//   A12-F1 (LOW)    builder-summary recount errors: programs = 10 (not 9), depends_on edges = 75 (not 74).
//   A12-F2 (MEDIUM) 12 of 36 registry P0 requirements are ORPHANS — mapped to NO twin node.
//   A12-F3 (MEDIUM) THREE broken machine-resolvable refs in the canonical twin: two rollback tags
//                   that never existed in git (P009A / P009B nodes) + P009D-POLICY implementation ref
//                   "docs/implementation/P009D_IMPLEMENTATION_EVIDENCE.md" (file does not exist; the
//                   real artifact is docs/intelligence/P009D_POLICY_INTELLIGENCE.md).
//   A12-F4 (MEDIUM) READY/transition law is prose-first: generic "dep LOCKED-or-ACTIVE == satisfied"
//                   rule + hardcoded next-action list; illegal transitions/deletions pass validators.
//   A12-F5 (LOW)    blocked_by[] overloaded: mixes node IDs and blocker IDs vs schema §2 declaration.
//   A12-F6 (LOW)    REQUIREMENTS_REGISTRY meta.count=35 vs 36 actual entries (twin repeats "35").
//   A12-F7 (LOW)    wave certification is prose-only: EP8-RELEASE-WAVES gate blocks no W1/W2/W3 node.
//   A12-F8 (LOW)    progress model partially reproducible (A yes; B needs undocumented ~80% priv/sec
//                   input and is not reconciled with Epoch-I ≈60%; C/D narrative-only). Honestly
//                   labeled PLANNING ESTIMATE.
//   A12-F9 (INFO)   2 of 22 sources[].path entries are prose-hybrids, not machine-resolvable paths.
//   A12-F10 (LOW)   CP-CONTROL-PLANE privacy/security = VERIFIED_WITH_LIMITATIONS while its own
//                   audit.status == PENDING — violates the twin's own transition law (schema §5).
//   A12-F11 (INFO)  stale "ECE 0.220" figure in OPEN_BLOCKERS.md P009E restatement vs audit-verified
//                   0.250 (twin correctly uses the audit figure — authority order respected).
//   A12-F12 (INFO)  validator census gaps: CP03 pins only 9/22 blockers, CP06 pins 8/9 negative
//                   truths (NT-PREVDWELL deletable undetected).
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT12_UluEvrenControlPlaneProbes: XCTestCase {

    // ── shared loading ──────────────────────────────────────────────────────────────────────────

    private var repoRoot: String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }
    private func loadJSON(_ rel: String) throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + rel))
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
    private func text(_ rel: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: repoRoot + "/" + rel), encoding: .utf8)
    }
    private func twin() throws -> [String: Any] { try loadJSON("docs/control-plane/GEN8_PROJECT_TWIN.yaml") }
    private func dag() throws -> [String: Any] { try loadJSON("docs/control-plane/GEN8_ULU_EVREN_MASTER_EXECUTION_DAG.yaml") }
    private func fmDoc() throws -> [String: Any] { try loadJSON("docs/control-plane/GEN8_ENGINEERING_FAILURE_MEMORY.yaml") }
    private func nodes(_ t: [String: Any]) throws -> [[String: Any]] { try XCTUnwrap(t["nodes"] as? [[String: Any]]) }
    private func str(_ n: [String: Any], _ k: String) -> String { (n[k] as? String) ?? "" }
    private func arr(_ n: [String: Any], _ k: String) -> [String] { (n[k] as? [String]) ?? [] }
    private func fileExists(_ rel: String) -> Bool { FileManager.default.fileExists(atPath: repoRoot + "/" + rel) }

    private func registryRequirementIDs() throws -> [String] {
        let t = try text("docs/requirements/REQUIREMENTS_REGISTRY.yaml")
        var ids: [String] = []
        for line in t.components(separatedBy: "\n") where line.hasPrefix("  - id: ") {
            ids.append(String(line.dropFirst("  - id: ".count)).trimmingCharacters(in: .whitespaces))
        }
        return ids
    }

    private func gitTagExists(_ tag: String) -> Bool {
        if FileManager.default.fileExists(atPath: repoRoot + "/.git/refs/tags/" + tag) { return true }
        if let packed = try? String(contentsOf: URL(fileURLWithPath: repoRoot + "/.git/packed-refs"), encoding: .utf8) {
            return packed.contains("refs/tags/" + tag + "\n") || packed.hasSuffix("refs/tags/" + tag)
        }
        return false
    }

    // ── independent reimplementation of the 9 builder checks (for mutation attribution) ─────────
    // Each returns a list of violation strings; empty == the builder-equivalent check passes.

    private func b_CP01_schema(_ ns: [[String: Any]]) -> [String] {
        let taxonomy: Set<String> = ["VERIFIED", "VERIFIED_WITH_LIMITATIONS", "PLAUSIBLE_NOT_PROVEN",
                                     "LAB_ONLY", "UNVERIFIED", "UNAVAILABLE", "CONTRADICTED", "OPEN", "BLOCKED"]
        let statuses: Set<String> = ["LOCKED", "ACTIVE", "READY", "BLOCKED", "PLANNED", "RETIRED"]
        let axes = ["overall", "functional", "calibration", "real_device", "privacy", "security",
                    "resource_performance", "human_product"]
        var v: [String] = []; var seen = Set<String>()
        for n in ns {
            let id = str(n, "id")
            if !seen.insert(id).inserted { v.append("dup \(id)") }
            if !statuses.contains(str(n, "status")) { v.append("\(id) bad status") }
            guard let truth = n["truth"] as? [String: Any] else { v.append("\(id) no truth"); continue }
            for a in axes {
                guard let val = truth[a] as? String, taxonomy.contains(val) else { v.append("\(id).\(a)"); continue }
            }
        }
        return v
    }
    private func b_CP02_graph(_ ns: [[String: Any]]) -> [String] {
        var v: [String] = []
        let ids = Set(ns.map { str($0, "id") })
        var deps: [String: [String]] = [:]
        let byID = Dictionary(uniqueKeysWithValues: ns.map { (str($0, "id"), $0) })
        for n in ns {
            let id = str(n, "id"); deps[id] = arr(n, "depends_on")
            for x in arr(n, "depends_on") where !ids.contains(x) { v.append("\(id) unknown dep \(x)") }
            for b in arr(n, "blocks") {
                guard ids.contains(b), let target = byID[b] else { v.append("\(id) unknown blocks \(b)"); continue }
                let tRefs = Set(arr(target, "depends_on") + arr(target, "blocked_by"))
                if !tRefs.contains(id) { v.append("asym \(id)->\(b)") }
            }
        }
        var color: [String: Int] = [:]
        func visit(_ u: String) -> Bool {
            if color[u] == 1 { return true }
            if color[u] == 2 { return false }
            color[u] = 1
            for w in deps[u] ?? [] where visit(w) { return true }
            color[u] = 2; return false
        }
        for id in ids where visit(id) { v.append("cycle via \(id)") }
        return v
    }
    private func b_CP03_blockers(_ t: [String: Any], _ ns: [[String: Any]]) -> [String] {
        var v: [String] = []
        let reg = (t["blockers"] as? [[String: Any]]) ?? []
        let blkIDs = Set(reg.map { str($0, "id") })
        let nodeIDs = Set(ns.map { str($0, "id") })
        for b in reg where str(b, "title").isEmpty || str(b, "status").isEmpty || str(b, "currency_note").isEmpty {
            v.append("registry field empty \(str(b, "id"))")
        }
        for n in ns {
            for b in arr(n, "blockers") where !blkIDs.contains(b) { v.append("\(str(n, "id")) unknown blocker \(b)") }
            if str(n, "status") == "BLOCKED" {
                if (arr(n, "blocked_by") + arr(n, "blockers")).isEmpty { v.append("\(str(n, "id")) BLOCKED w/o reason") }
                for r in arr(n, "blocked_by") where !(blkIDs.contains(r) || nodeIDs.contains(r)) {
                    v.append("\(str(n, "id")) blocked_by unresolvable \(r)")
                }
            }
        }
        for required in ["BLK-A10-F1-COVERAGE", "BLK-A11-APIBYPASS", "BLK-A11-IDCHARSET",
                         "BLK-A11-COMPOSITE-ALIAS", "BLK-A11-LEGACY-P008", "BLK-ECE-UNMET",
                         "BLK-DEVICE-RWC-OPEN", "BLK-C6", "BLK-B1"] where !blkIDs.contains(required) {
            v.append("carried blocker vanished \(required)")
        }
        return v
    }
    private func b_CP04_ready(_ ns: [[String: Any]]) -> [String] {
        var v: [String] = []
        let byID = Dictionary(uniqueKeysWithValues: ns.map { (str($0, "id"), $0) })
        let ready = ns.filter { str($0, "status") == "READY" }.map { str($0, "id") }
        for id in ready {
            for d in arr(byID[id]!, "depends_on") {
                let s = str(byID[d] ?? [:], "status")
                if !(s == "LOCKED" || s == "ACTIVE") { v.append("READY \(id) dep \(d)=\(s)") }
            }
            if !arr(byID[id]!, "blocked_by").isEmpty { v.append("READY \(id) also blocked") }
        }
        if ready != ["CP-INDEPENDENT-AUDIT"] { v.append("ready set drifted: \(ready)") }
        return v
    }
    /// CP04 WITHOUT the hardcoded equality — the GENERIC per-node READY law only (§13 attack surface).
    private func genericReadyLawViolations(_ ns: [[String: Any]]) -> [String] {
        var v: [String] = []
        let byID = Dictionary(uniqueKeysWithValues: ns.map { (str($0, "id"), $0) })
        for n in ns where str(n, "status") == "READY" {
            for d in arr(n, "depends_on") {
                let s = str(byID[d] ?? [:], "status")
                if !(s == "LOCKED" || s == "ACTIVE") { v.append("\(str(n, "id")) dep \(d)=\(s)") }
            }
            if !arr(n, "blocked_by").isEmpty { v.append("\(str(n, "id")) blocked") }
        }
        return v
    }
    private func b_CP05_forbidden(_ ns: [[String: Any]]) -> [String] {
        var v: [String] = []
        let byID = Dictionary(uniqueKeysWithValues: ns.map { (str($0, "id"), $0) })
        if str(byID["EP3-PRESENTATION"] ?? [:], "status") != "BLOCKED" { v.append("presentation unblocked") }
        if str(byID["RWC-CORPUS"] ?? [:], "status") != "BLOCKED" { v.append("corpus unblocked") }
        if !arr(byID["RWC-CORPUS"] ?? [:], "blocked_by").contains("RWC-PRE-14") { v.append("corpus gate ref gone") }
        for i in 1...13 {
            let id = String(format: "RWC-PRE-%02d", i)
            if str(byID[id] ?? [:], "status") != "BLOCKED" { v.append("\(id) unblocked") }
        }
        for n in ns where ((n["truth"] as? [String: Any])?["calibration"] as? String) == "VERIFIED" {
            v.append("\(str(n, "id")) calibration VERIFIED")
        }
        return v
    }
    private func b_CP06_negativeTruth(_ t: [String: Any]) -> [String] {
        var v: [String] = []
        let nts = (t["negative_truth"] as? [[String: Any]]) ?? []
        let byID = Dictionary(uniqueKeysWithValues: nts.map { (str($0, "id"), str($0, "fact")) })
        if !(byID["NT-TIER0-GROUPING"]?.contains("CONTRADICTED") ?? false) { v.append("NT-TIER0") }
        if !(byID["NT-ECE-UNMET"]?.contains("UNMET") ?? false) { v.append("NT-ECE") }
        if !(byID["NT-F1-COVERAGE"]?.contains("NOT validated") ?? false) { v.append("NT-F1") }
        if !(byID["NT-DEVICE-RWC"]?.contains("OPEN") ?? false) { v.append("NT-DEVICE") }
        for id in ["NT-C6-LOADBEARING", "NT-P008-PILOT-FAILED", "NT-APIBYPASS", "NT-THERMAL-EVIDENCE-BUILD"]
        where byID[id] == nil { v.append(id) }
        return v
    }
    private func b_CP07_evidence(_ ns: [[String: Any]]) -> [String] {
        var v: [String] = []
        for n in ns {
            let truth = ((n["truth"] as? [String: Any]) ?? [:]).values.compactMap { $0 as? String }
            if truth.contains("VERIFIED") || truth.contains("VERIFIED_WITH_LIMITATIONS") {
                let e = (n["evidence"] as? [String: Any]) ?? [:]
                let total = e.values.compactMap { $0 as? [String] }.map(\.count).reduce(0, +)
                if total == 0 { v.append("\(str(n, "id")) verified-class w/o evidence") }
            }
        }
        return v
    }
    private func b_CP08_fm(_ f: [String: Any], _ ns: [[String: Any]]) -> [String] {
        var v: [String] = []
        let recs = (f["records"] as? [[String: Any]]) ?? []
        let fmIDs = Set(recs.map { str($0, "id") })
        for i in 1...14 where !fmIDs.contains(String(format: "FM-%03d", i)) { v.append("FM-\(i) missing") }
        for n in ns { for r in arr(n, "failure_memory_refs") where !fmIDs.contains(r) { v.append("\(str(n, "id")) FM ref \(r)") } }
        return v
    }

    private func allBuilderChecks(_ t: [String: Any], _ f: [String: Any]) throws -> [String] {
        let ns = try nodes(t)
        return b_CP01_schema(ns) + b_CP02_graph(ns) + b_CP03_blockers(t, ns) + b_CP04_ready(ns)
             + b_CP05_forbidden(ns) + b_CP06_negativeTruth(t) + b_CP07_evidence(ns) + b_CP08_fm(f, ns)
    }

    private func deepCopy(_ t: [String: Any]) throws -> [String: Any] {
        let d = try JSONSerialization.data(withJSONObject: t)
        return try JSONSerialization.jsonObject(with: d) as! [String: Any]
    }
    private func mutate(_ t: [String: Any], node id: String, _ change: (inout [String: Any]) -> Void) throws -> [String: Any] {
        var copy = try deepCopy(t)
        var ns = copy["nodes"] as! [[String: Any]]
        let i = try XCTUnwrap(ns.firstIndex { str($0, "id") == id })
        change(&ns[i])
        copy["nodes"] = ns
        return copy
    }

    // ═══════════════════ §2/§27 — INDEPENDENT RECOUNT ═══════════════════

    func testA12_01_CanonicalRecount_PinsBuilderSummaryDiscrepancies() throws {
        let t = try twin()
        let ns = try nodes(t)
        XCTAssertEqual(ns.count, 60, "node recount")
        XCTAssertEqual(ns.map { arr($0, "depends_on").count }.reduce(0, +), 75,
                       "A12-F1: depends_on edges = 75 (builder summary said 74)")
        XCTAssertEqual(ns.map { arr($0, "blocks").count }.reduce(0, +), 49,
                       "blocks[] is a declared CONVENIENCE inverse (49 edges), not a bijection of depends_on (75)")
        XCTAssertEqual(Set(ns.map { str($0, "program") }),
                       ["CONTROL_PLANE", "TRUSTED_BRAIN", "RWC_PREREGISTRATION", "REALITY", "GUARDIAN_BODY",
                        "HUMAN_SYSTEM", "SOCIAL_COMMAND_OS", "LIVING_INTELLIGENCE", "UNIVERSALIZATION",
                        "PRODUCTION_CIVILIZATION"],
                       "A12-F1: programs = 10 (builder summary said 9)")
        XCTAssertEqual(Set(ns.map { str($0, "epoch") }).count, 9, "8 epochs + META")
        XCTAssertEqual((t["blockers"] as? [[String: Any]])?.count, 22)
        XCTAssertEqual((t["negative_truth"] as? [[String: Any]])?.count, 9)
        XCTAssertEqual((t["sources"] as? [[String: Any]])?.count, 22)
        var census: [String: Int] = [:]
        for n in ns { census[str(n, "status"), default: 0] += 1 }
        XCTAssertEqual(census, ["ACTIVE": 9, "LOCKED": 6, "READY": 1, "BLOCKED": 20, "PLANNED": 24])
        XCTAssertEqual(ns.filter { str($0, "status") == "READY" }.map { str($0, "id") }, ["CP-INDEPENDENT-AUDIT"])
        XCTAssertEqual((try fmDoc()["records"] as? [[String: Any]])?.count, 14)
    }

    func testA12_02_GraphIntegrity_IndependentRecomputation() throws {
        let ns = try nodes(try twin())
        let ids = ns.map { str($0, "id") }
        XCTAssertEqual(Set(ids).count, ids.count, "node IDs unique")
        XCTAssertEqual(b_CP02_graph(ns), [], "no dangling refs, no asymmetry, no cycles (own DFS)")
        // every depends_on edge resolves; count by epoch for the record
        let idSet = Set(ids)
        for n in ns {
            for d in arr(n, "depends_on") { XCTAssertTrue(idSet.contains(d), "\(str(n, "id")) -> \(d)") }
            for b in arr(n, "blocks") { XCTAssertTrue(idSet.contains(b), "\(str(n, "id")) blocks \(b)") }
        }
    }

    // ═══════════════════ §15 — blocked_by FIELD OVERLOAD (A12-F5) ═══════════════════

    func testA12_03_BlockedByOverload_MixesNodeIDsAndBlockerIDs_FINDING() throws {
        let t = try twin()
        let ns = try nodes(t)
        let nodeIDs = Set(ns.map { str($0, "id") })
        let blkIDs = Set(((t["blockers"] as? [[String: Any]]) ?? []).map { str($0, "id") })
        var nodeRefs = 0, blockerRefs = 0
        for n in ns {
            for r in arr(n, "blocked_by") {
                if nodeIDs.contains(r) { nodeRefs += 1 }
                else if blkIDs.contains(r) { blockerRefs += 1 }
                else { XCTFail("\(str(n, "id")).blocked_by unresolvable: \(r)") }
            }
        }
        // Schema §2 declares blocked_by = "blocker IDs (BLK-… / finding IDs)". The instance uses it
        // for gating NODE IDs 18 times (CP-INDEPENDENT-AUDIT ×14 on RWC-PRE-01..14, RWC-PRE-14 ×4 on
        // corpus/annotation/fit/held-out) and blocker IDs only 2 times (BLK-DEVICE-RWC-OPEN on
        // RWC-DEVICE-E2E, BLK-C4 on EP3-PRESENTATION). CP02/CP03 EXPLICITLY accept both. PINNED as
        // A12-F5 (field overload — dependency vs blocker vs gate not structurally distinct).
        XCTAssertEqual(nodeRefs, 18, "A12-F5 pin: node-ID uses of blocked_by")
        XCTAssertEqual(blockerRefs, 2, "A12-F5 pin: blocker-ID uses of blocked_by")
    }

    // ═══════════════════ §4/§5 — REQUIREMENT GRAPH ═══════════════════

    func testA12_04_EveryNodeRequirementResolvesInRegistry() throws {
        let reg = Set(try registryRequirementIDs())
        for n in try nodes(try twin()) {
            for r in arr(n, "requirements") {
                XCTAssertTrue(reg.contains(r), "\(str(n, "id")): requirement \(r) not in REQUIREMENTS_REGISTRY")
            }
        }
    }

    // A12-F2 FIXED (inversion pre-declared in docs/audit/AUDIT12_INVERSION_LOCK.md I-1; original pinned
    // 12 orphans): every registry requirement now has an explicit twin owner; full ownership record in
    // docs/control-plane/GEN8_REQUIREMENT_NODE_MAP.yaml (dispositions, primary owners, reasons).
    func testA12_05_OrphanRegistryRequirements_FINDING() throws {
        let reg = Set(try registryRequirementIDs())
        var used = Set<String>()
        for n in try nodes(try twin()) { used.formUnion(arr(n, "requirements")) }
        let orphans = reg.subtracting(used).sorted()
        XCTAssertEqual(orphans, [],
                       "A12-F2 FIXED: every registry requirement has an explicit twin owner (see GEN8_REQUIREMENT_NODE_MAP.yaml)")
    }

    // A12-F6 FIXED (inversion pre-declared in docs/audit/AUDIT12_INVERSION_LOCK.md I-2; original pinned
    // the stale 35 figure in living metadata): registry meta corrected to 36; twin source note corrected.
    func testA12_06_RegistryCountMetaMismatch_FINDING() throws {
        let ids = try registryRequirementIDs()
        XCTAssertEqual(ids.count, 36, "actual registry entries")
        let regText = try text("docs/requirements/REQUIREMENTS_REGISTRY.yaml")
        XCTAssertTrue(regText.contains("count: 36"), "A12-F6 FIXED: living meta.count corrected to 36")
        XCTAssertFalse(regText.contains("count: 35"), "A12-F6 FIXED: stale figure gone from living metadata")
        let twinText = try text("docs/control-plane/GEN8_PROJECT_TWIN.yaml")
        XCTAssertTrue(twinText.contains("36 P0 requirements"),
                      "A12-F6 FIXED: twin source note carries the corrected figure")
    }

    // ═══════════════════ §4 — EVIDENCE REFERENCE INTEGRITY ═══════════════════

    func testA12_07_DecisionRefsResolveInLedger() throws {
        let ledger = try text("docs/canonical/DECISION_LEDGER.md")
        let combined = (try text("docs/control-plane/GEN8_PROJECT_TWIN.yaml"))
                     + (try text("docs/control-plane/GEN8_ULU_EVREN_MASTER_EXECUTION_DAG.yaml"))
                     + (try text("docs/control-plane/GEN8_ENGINEERING_FAILURE_MEMORY.yaml"))
        let regex = try NSRegularExpression(pattern: "D-\\d{4}")
        let ms = regex.matches(in: combined, range: NSRange(combined.startIndex..., in: combined))
        let dids = Set(ms.map { String(combined[Range($0.range, in: combined)!]) })
        XCTAssertFalse(dids.isEmpty)
        for d in dids.sorted() {
            XCTAssertTrue(ledger.contains("## \(d)"), "decision \(d) not found as a ledger heading")
        }
    }

    func testA12_08_FullReferenceCensus_ClassifiedAndResolved() throws {
        let t = try twin()
        let ns = try nodes(t)
        let f = try fmDoc()
        var total = 0, filePaths = 0, dirScopes = 0, ledgerAnchors = 0, commits = 0, tags = 0
        var testSymbols = 0, sourceSymbols = 0, auditAliases = 0, semantic = 0
        var broken: [String] = []

        let testDir = repoRoot + "/packages/GuardianKit/Tests/GuardianCoreTests/"
        let testFiles = (try? FileManager.default.contentsOfDirectory(atPath: testDir)) ?? []
        let knownCommitPrefixes: Set<String> = ["11e673b", "4ce238f", "de58f0c", "42b96a2", "aaa0cf6",
                                                "0046925", "9c049f3", "70fc222", "8dfdbf0", "f991aba",
                                                "28865c3", "06b3386", "e5b5d61", "e983b36"]
        func classify(_ ref: String, context: String) {
            total += 1
            let r = ref.trimmingCharacters(in: .whitespaces)
            if r.hasSuffix("/") {
                dirScopes += 1
                var isDir: ObjCBool = false
                let path = r.components(separatedBy: " ").first ?? r
                if !FileManager.default.fileExists(atPath: repoRoot + "/" + path, isDirectory: &isDir) || !isDir.boolValue {
                    broken.append("\(context): dir \(r)")
                }
            } else if r.contains(".csv:") {
                ledgerAnchors += 1
                let token = r.components(separatedBy: ".csv:")[1].components(separatedBy: " ")[0]
                let csv = (try? text("docs/audit/GEN8_CLAIM_EVIDENCE_LEDGER.csv")) ?? ""
                if !csv.contains("\n\(token),") { broken.append("\(context): ledger anchor \(token)") }
            } else if r.hasPrefix("docs/") && r.contains(".") && !r.contains(" ") {
                filePaths += 1
                if !fileExists(r) { broken.append("\(context): \(r)") }
            } else if r.hasPrefix("docs/") {
                semantic += 1 // prose-hybrid path (A12-F9)
            } else if knownCommitPrefixes.contains(r) {
                commits += 1 // resolvability proven out-of-band via git rev-parse (see audit report §1)
            } else if r.hasPrefix("gen8-") {
                tags += 1
                if !gitTagExists(r) { broken.append("\(context): tag \(r)") }
            } else if r.range(of: "^AUDIT\\d+$", options: .regularExpression) != nil {
                auditAliases += 1 // alias → report file mapping asserted in testA12_11
            } else if r.hasSuffix(".swift") && !r.contains("/") {
                sourceSymbols += 1
            } else if testFiles.contains(r + ".swift") || testFiles.contains(where: { $0.hasPrefix(r) && $0.hasSuffix(".swift") }) {
                testSymbols += 1
            } else {
                semantic += 1 // HUMAN_DESCRIPTION / composite prose — deterministically NON-machine-resolvable
            }
        }
        for n in ns {
            let id = str(n, "id")
            let impl = (n["implementation"] as? [String: Any]) ?? [:]
            for r in (impl["refs"] as? [String]) ?? [] { classify(r, context: id) }
            for c in (impl["commits"] as? [String]) ?? [] { classify(c, context: id) }
            for r in ((n["tests"] as? [String: Any])?["refs"] as? [String]) ?? [] { classify(r, context: id) }
            for r in ((n["audit"] as? [String: Any])?["refs"] as? [String]) ?? [] { classify(r, context: id) }
            for (_, v) in (n["evidence"] as? [String: Any]) ?? [:] {
                for r in (v as? [String]) ?? [] { classify(r, context: id) }
            }
            let rb = (n["rollback"] as? [String: Any]) ?? [:]
            for k in ["commit", "tag"] {
                let val = (rb[k] as? String) ?? ""
                if !val.isEmpty { classify(val, context: id + ".rollback") }
            }
        }
        for s in (t["sources"] as? [[String: Any]]) ?? [] { classify(str(s, "path"), context: "sources") }
        for b in (t["blockers"] as? [[String: Any]]) ?? [] { classify(str(b, "source"), context: str(b, "id")) }
        for nt in (t["negative_truth"] as? [[String: Any]]) ?? [] {
            for e in arr(nt, "evidence") { classify(e, context: str(nt, "id")) }
        }
        for r in (f["records"] as? [[String: Any]]) ?? [] {
            for e in arr(r, "evidence") { classify(e, context: str(r, "id")) }
            for rt in arr(r, "regression_tests") { classify(rt, context: str(r, "id") + ".regression") }
        }
        // A12-F3 pin: EXACTLY three broken machine-resolvable refs exist in the canonical twin —
        //  (1) P009A rollback tag never created in git, (2) P009B rollback tag never created in git,
        //  (3) P009D-POLICY implementation ref points to a nonexistent file (the real artifact is
        //      docs/intelligence/P009D_POLICY_INTELLIGENCE.md). The builder's CP07 misses all three
        //      (it validates only 5 hardcoded paths). "broken refs = 0" is FALSE for the candidate.
        XCTAssertEqual(broken.sorted(),
                       ["P009A-IDENTITY-FOUNDATION.rollback: tag gen8-p009a-identity-foundation-locked-phase-c-ok",
                        "P009B-EXPERT-MESH.rollback: tag gen8-p009b-expert-mesh-r1-reaudit-pass",
                        "P009D-POLICY: docs/implementation/P009D_IMPLEMENTATION_EVIDENCE.md"],
                       "A12-F3 pin — broken ref set")
        XCTAssertFalse(fileExists("docs/implementation/P009D_IMPLEMENTATION_EVIDENCE.md"), "A12-F3 pin")
        XCTAssertTrue(fileExists("docs/intelligence/P009D_POLICY_INTELLIGENCE.md"),
                      "the real P009D artifact lives elsewhere — wrong path, not missing evidence")
        print("A12-CENSUS total=\(total) filePath=\(filePaths) dirScope=\(dirScopes) ledgerAnchor=\(ledgerAnchors) "
            + "commit=\(commits) tag=\(tags) testSymbol=\(testSymbols) sourceSymbol=\(sourceSymbols) "
            + "auditAlias=\(auditAliases) semantic=\(semantic) broken=\(broken.count)")
        XCTAssertEqual(total, filePaths + dirScopes + ledgerAnchors + commits + tags + testSymbols
                              + sourceSymbols + auditAliases + semantic, "census partition is total")
        // Exact census PINNED (candidate 4d6649c): any canonical edit is a new candidate and must
        // re-derive these. Builder summary said "~95 refs" — actual census is 253 (A12-F1 class).
        XCTAssertEqual(total, 253, "census total")
        XCTAssertEqual([filePaths, dirScopes, ledgerAnchors, commits, tags, testSymbols, sourceSymbols,
                        auditAliases, semantic],
                       [71, 7, 8, 22, 8, 29, 2, 16, 90], "census class breakdown")
        let machine = filePaths + dirScopes + ledgerAnchors + commits + tags + auditAliases + testSymbols + sourceSymbols
        XCTAssertEqual(machine, 163, "machine-resolvable refs; 90 remain SEMANTIC/human-prose, so the twin may never claim 100% machine resolvability")
        XCTAssertGreaterThan(machine, semantic, "majority of refs must stay machine-resolvable")
    }

    func testA12_09_RollbackTagAnchors_TwoNeverExisted_FINDING() throws {
        // real tags resolve
        for tag in ["gen8-p009c-locked", "gen8-p009d-locked", "gen8-p009e-r1-locked-engineering-only",
                    "gen8-rwc-entry-gate-r1-locked-engineering", "gen8-ulu-evren-control-plane-audit-candidate"] {
            XCTAssertTrue(gitTagExists(tag), "expected real tag missing: \(tag)")
        }
        // A12-F3 (MEDIUM): canonical twin cites two rollback tags that exist NOWHERE in git and in no
        // other repo document — fabricated anchors on two LOCKED nodes (commits 4ce238f / 42b96a2 ARE
        // valid, so rollback-by-commit still works; the tag strings are invented history — FM-003 class).
        XCTAssertFalse(gitTagExists("gen8-p009a-identity-foundation-locked-phase-c-ok"), "A12-F3 pin")
        XCTAssertFalse(gitTagExists("gen8-p009b-expert-mesh-r1-reaudit-pass"), "A12-F3 pin")
        let ns = try nodes(try twin())
        let p009a = try XCTUnwrap(ns.first { str($0, "id") == "P009A-IDENTITY-FOUNDATION" })
        XCTAssertEqual(((p009a["rollback"] as? [String: Any])?["tag"] as? String),
                       "gen8-p009a-identity-foundation-locked-phase-c-ok",
                       "A12-F3 pin: twin still carries the nonexistent tag")
    }

    func testA12_10_ClaimLedgerAnchorsResolve() throws {
        let csv = try text("docs/audit/GEN8_CLAIM_EVIDENCE_LEDGER.csv")
        for n in try nodes(try twin()) {
            for ref in ((n["evidence"] as? [String: Any])?["claim_refs"] as? [String]) ?? []
            where ref.contains("GEN8_CLAIM_EVIDENCE_LEDGER.csv:") {
                let token = ref.components(separatedBy: ".csv:")[1].components(separatedBy: " ")[0]
                XCTAssertTrue(csv.contains("\n\(token),"), "\(str(n, "id")): no ledger row for \(token)")
            }
        }
    }

    func testA12_11_AuditAliasResolution_ConventionNotMachineEncoded() throws {
        // Alias → artifact convention recovered independently from the audit directory:
        let aliasToReport: [String: String] = [
            "AUDIT2": "docs/audit/GEN8_PHASE_C_CLOSEOUT_AUDIT_REPORT.md",
            "AUDIT3": "docs/audit/GEN8_P009B_INDEPENDENT_AUDIT_REPORT.md",
            "AUDIT4": "docs/audit/GEN8_P009B_R1_REAUDIT_REPORT.md",
            "AUDIT5": "docs/audit/GEN8_P009C_INDEPENDENT_AUDIT_REPORT.md",
            "AUDIT6": "docs/audit/GEN8_P009C_R1_REAUDIT_REPORT.md",
            "AUDIT7": "docs/audit/GEN8_P009D_INDEPENDENT_AUDIT_REPORT.md",
            "AUDIT8": "docs/audit/GEN8_P009E_INDEPENDENT_AUDIT_REPORT.md",
            "AUDIT9": "docs/audit/GEN8_P009E_R1_INDEPENDENT_REAUDIT_REPORT.md",
            "AUDIT10": "docs/audit/GEN8_REAL_WORLD_CALIBRATION_ENTRY_GATE_INDEPENDENT_AUDIT.md",
            "AUDIT11": "docs/audit/GEN8_RWC_ENTRY_GATE_R1_INDEPENDENT_REAUDIT.md",
        ]
        for (alias, report) in aliasToReport {
            XCTAssertTrue(fileExists(report), "\(alias) → \(report) missing")
        }
        // The mapping above lives ONLY in auditor/human convention — no machine-readable alias table
        // exists in the control plane. Classified SEMANTIC in the census; acceptable because each
        // alias is unique-per-phase, but a future alias table would make it machine-resolvable.
        let twinText = try text("docs/control-plane/GEN8_PROJECT_TWIN.yaml")
        XCTAssertFalse(twinText.contains("alias_table"), "no machine alias table exists (documented limitation)")
    }

    func testA12_12_TestAndSourceSymbolRefsExist() throws {
        let testDir = repoRoot + "/packages/GuardianKit/Tests/GuardianCoreTests/"
        let files = Set((try FileManager.default.contentsOfDirectory(atPath: testDir)))
        // every bare test-symbol referenced by the twin's tests.refs must exist as a test file
        let symbolish = try NSRegularExpression(pattern: "^[A-Za-z0-9_]+$")
        for n in try nodes(try twin()) {
            for ref in ((n["tests"] as? [String: Any])?["refs"] as? [String]) ?? []
            where symbolish.firstMatch(in: ref, range: NSRange(ref.startIndex..., in: ref)) != nil
                  && ref.hasSuffix("Tests") {
                XCTAssertTrue(files.contains(ref + ".swift"), "\(str(n, "id")): test symbol \(ref) has no file")
            }
        }
        // FM regression_tests: machine-checkable symbols must exist (prose entries stay SEMANTIC)
        for r in (try fmDoc()["records"] as? [[String: Any]]) ?? [] {
            for rt in arr(r, "regression_tests") {
                let head = rt.components(separatedBy: " ")[0]
                if head.hasSuffix("Tests") {
                    XCTAssertTrue(files.contains(head + ".swift"), "\(str(r, "id")): regression symbol \(head)")
                }
            }
        }
        XCTAssertTrue(files.contains("AUDIT_ArtifactIntegrityTests.swift"), "FM-002 regression family exists")
    }

    // ═══════════════════ §3/§17 — SOURCE AUTHORITY ═══════════════════

    func testA12_13_SourceAuthorityClassesAndResolvability() throws {
        let sources = try XCTUnwrap(try twin()["sources"] as? [[String: Any]])
        let allowed: Set<String> = ["AUTHORITATIVE", "DERIVED", "HISTORICAL_FROZEN", "AUDIT_EVIDENCE",
                                    "GENERATED_VIEW", "SUPERSEDED", "UNKNOWN"]
        var proseHybrids: [String] = []
        for s in sources {
            XCTAssertTrue(allowed.contains(str(s, "class")), "unknown source class \(str(s, "class"))")
            let p = str(s, "path")
            if p.contains(" ") { proseHybrids.append(p); continue }
            XCTAssertTrue(fileExists(p), "source path missing: \(p)")
        }
        // A12-F9 pin: exactly 2 prose-hybrid source paths (audit-dir aggregate + sibling-views aggregate)
        XCTAssertEqual(proseHybrids.count, 2, "A12-F9 pin: \(proseHybrids)")
        // domain safety spot-checks: ledgers are AUDIT_EVIDENCE (never DERIVED); views GENERATED_VIEW
        func cls(_ path: String) -> String {
            sources.first { str($0, "path").hasPrefix(path) }.map { str($0, "class") } ?? "?"
        }
        XCTAssertEqual(cls("docs/audit/GEN8_OPEN_BLOCKERS.md"), "AUDIT_EVIDENCE")
        XCTAssertEqual(cls("docs/audit/GEN8_CLAIM_EVIDENCE_LEDGER.csv"), "AUDIT_EVIDENCE")
        XCTAssertEqual(cls("docs/control-plane/CURRENT_STATE.md"), "GENERATED_VIEW")
        XCTAssertEqual(cls("docs/canonical/DECISION_LEDGER.md"), "AUTHORITATIVE")
        XCTAssertEqual(cls("docs/capability/PLATFORM_CAPABILITY_MATRIX.yaml"), "AUTHORITATIVE")
        // an audit REPORT is never classified as authoritative architecture
        for s in sources where str(s, "path").hasPrefix("docs/audit/") {
            XCTAssertEqual(str(s, "class"), "AUDIT_EVIDENCE", "\(str(s, "path")) must stay AUDIT_EVIDENCE")
        }
    }

    func testA12_14_NoNewestWinsLaw_StaleLedgerFlaggedNotOverwritten() throws {
        // domain-aware precedence documented; no "newest file wins" anywhere in control-plane docs
        let schema = try text("docs/control-plane/GEN8_PROJECT_TWIN_SCHEMA.md")
        XCTAssertTrue(schema.contains("Newer ≠ more authoritative"), "anti-newest-wins law present")
        XCTAssertTrue(schema.contains("Domain-awareness"), "domain-aware authority law present")
        // BLK-H1: ledger row contradicted by repo history → twin flags STALE_LEDGER, does NOT close it,
        // and the AUDIT_EVIDENCE ledger file still contains the ORIGINAL claim unmodified.
        let t = try twin()
        let h1 = try XCTUnwrap((t["blockers"] as? [[String: Any]])?.first { str($0, "id") == "BLK-H1" })
        XCTAssertEqual(str(h1, "status"), "STALE_LEDGER")
        XCTAssertTrue(str(h1, "currency_note").contains("NOT silently closed"))
        let ledger = try text("docs/audit/GEN8_OPEN_BLOCKERS.md")
        XCTAssertTrue(ledger.contains("H1 — Git anchoring absent"),
                      "original ledger text preserved (immutable AUDIT_EVIDENCE)")
        // and git history NOW really is anchored (the staleness is genuine): candidate repo has tags
        XCTAssertTrue(gitTagExists("gen8-rwc-entry-gate-r1-locked-engineering"))
    }

    // ═══════════════════ §8/§9 — TRUTH AXES & CLAIM INFLATION ═══════════════════

    func testA12_15_NodeAxisMatrix_VerifiedClassInventoryExactlyPinned() throws {
        let ns = try nodes(try twin())
        var fullVerified: [String] = []     // "NODE.axis" with VERIFIED
        var vwl: [String] = []              // with VERIFIED_WITH_LIMITATIONS
        for n in ns {
            let truth = try XCTUnwrap(n["truth"] as? [String: Any])
            for (axis, v) in truth {
                if v as? String == "VERIFIED" { fullVerified.append("\(str(n, "id")).\(axis)") }
                if v as? String == "VERIFIED_WITH_LIMITATIONS" { vwl.append("\(str(n, "id")).\(axis)") }
            }
        }
        // The ONLY plain-VERIFIED axes in the whole twin are the entry gate's functional + privacy,
        // both backed by AUDIT11 §13 ("Privacy / security — VERIFIED") and the R1 lock. No device,
        // calibration or human axis is VERIFIED anywhere. No unrelated-lab-evidence inheritance found.
        XCTAssertEqual(Set(fullVerified), ["RWC-ENTRY-GATE.functional", "RWC-ENTRY-GATE.privacy"],
                       "plain-VERIFIED inventory drifted: \(fullVerified.sorted())")
        XCTAssertFalse(vwl.contains { $0.hasSuffix(".calibration") }, "no calibration axis may be verified-class")
        XCTAssertFalse(fullVerified.contains { $0.hasSuffix(".real_device") }, "no device axis VERIFIED")
        XCTAssertFalse(vwl.contains { $0.hasSuffix(".human_product") }, "no human axis verified-class")
        // every verified-class node has at least one evidence ref (independent of CP07)
        XCTAssertEqual(b_CP07_evidence(ns), [])
    }

    func testA12_16_ControlPlaneSelfGrade_PrecedesItsOwnAudit_FINDING() throws {
        let ns = try nodes(try twin())
        let cp = try XCTUnwrap(ns.first { str($0, "id") == "CP-CONTROL-PLANE" })
        let truth = try XCTUnwrap(cp["truth"] as? [String: Any])
        // A12-F10 (LOW): privacy/security already VERIFIED_WITH_LIMITATIONS while audit.status==PENDING.
        // Schema §5 requires an independent audit ref for LAB_ONLY→VWL. The node's own audit has not
        // happened — self-graded axes. (overall stays UNVERIFIED, so no unlock results; pinned.)
        XCTAssertEqual(truth["privacy"] as? String, "VERIFIED_WITH_LIMITATIONS", "A12-F10 pin")
        XCTAssertEqual(truth["security"] as? String, "VERIFIED_WITH_LIMITATIONS", "A12-F10 pin")
        XCTAssertEqual(((cp["audit"] as? [String: Any])?["status"] as? String), "PENDING", "A12-F10 pin")
        XCTAssertEqual(truth["overall"] as? String, "UNVERIFIED", "overall honestly UNVERIFIED (contains the self-grade)")
    }

    func testA12_17_ClaimInflationSweep_ForbiddenClaimsAbsent_CodeTruthAgrees() throws {
        let ns = try nodes(try twin())
        let byID = Dictionary(uniqueKeysWithValues: ns.map { (str($0, "id"), $0) })
        // Tier-0 CONTRADICTED preserved; ECE UNMET; F1 NOT validated; device OPEN; P008 pilot preserved
        XCTAssertEqual(b_CP06_negativeTruth(try twin()), [])
        XCTAssertEqual(((byID["P008-CALIBRATION-PILOT"]!["truth"] as! [String: Any])["calibration"] as! String),
                       "CONTRADICTED")
        XCTAssertEqual(((byID["RWC-ENTRY-GATE"]!["truth"] as! [String: Any])["real_device"] as! String), "OPEN")
        XCTAssertEqual(str(byID["EP3-PRESENTATION"]!, "status"), "BLOCKED")
        XCTAssertEqual(str(byID["RWC-CORPUS"]!, "status"), "BLOCKED")
        // CODE truth (independent of graph): production score gate CLOSED, display OFF, engineering-only
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims)
        // views: forbidden-claim rows stay FALSE/NOT VALIDATED with unambiguous underlying taxonomy
        let matrix = try text("docs/control-plane/CLAIM_TRUTH_MATRIX.md")
        XCTAssertTrue(matrix.contains("FORBIDDEN CLAIM — FALSE"))
        XCTAssertTrue(matrix.contains("NOT VALIDATED"))
        XCTAssertTrue(matrix.contains("CONTRADICTED"))
        // no pseudo-truth anywhere in the twin
        let twinText = try text("docs/control-plane/GEN8_PROJECT_TWIN.yaml")
        for forbidden in ["\"PRODUCTION_READY\"", "\"DONE\"", "\"COMPLETE\""] {
            XCTAssertFalse(twinText.contains(forbidden), "forbidden pseudo-truth \(forbidden)")
        }
    }

    func testA12_18_StaleEceFigureInLedger_TwinUsesAuditValue_INFO() throws {
        // A12-F11 (INFO): the builder's P009E restatement in the immutable ledger says "ECE 0.220";
        // the independent audits (AUDIT9/AUDIT11) and the twin say 0.250. The twin correctly follows
        // the higher-authority audit figure; the ledger row is historical and stays unmodified.
        let ledger = try text("docs/audit/GEN8_OPEN_BLOCKERS.md")
        XCTAssertTrue(ledger.contains("ECE 0.220"), "A12-F11 pin: stale builder figure preserved in ledger")
        let twinText = try text("docs/control-plane/GEN8_PROJECT_TWIN.yaml")
        XCTAssertTrue(twinText.contains("ECE .250"), "twin carries the audit-verified figure")
        let audit11 = try text("docs/audit/GEN8_RWC_ENTRY_GATE_R1_INDEPENDENT_REAUDIT.md")
        XCTAssertTrue(audit11.contains("ECE 0.250"), "audit recomputation anchor")
    }

    // ═══════════════════ §10/§11/§18 — NEGATIVE TRUTH, BLOCKERS, FAILURE MEMORY ═══════════════════

    func testA12_19_NegativeTruthCompleteness_AllNineWithEvidence() throws {
        let nts = try XCTUnwrap(try twin()["negative_truth"] as? [[String: Any]])
        XCTAssertEqual(Set(nts.map { str($0, "id") }),
                       ["NT-TIER0-GROUPING", "NT-C6-LOADBEARING", "NT-PREVDWELL", "NT-THERMAL-EVIDENCE-BUILD",
                        "NT-P008-PILOT-FAILED", "NT-ECE-UNMET", "NT-F1-COVERAGE", "NT-APIBYPASS", "NT-DEVICE-RWC"])
        for nt in nts {
            XCTAssertFalse(arr(nt, "evidence").isEmpty, "\(str(nt, "id")) has no evidence")
            XCTAssertFalse(str(nt, "fact").isEmpty)
        }
        // Independent sweep anchors: the honest device-underperformance record and the FAILED-pilot
        // record remain readable in immutable artifacts (nothing was cleaned up).
        let ledger = try text("docs/audit/GEN8_OPEN_BLOCKERS.md")
        XCTAssertTrue(ledger.contains("economy 1.4% vs lab 43-48%"), "device Tier-0 FAIL preserved in ledger")
        XCTAssertTrue(ledger.contains("false-safe 0.50"), "P008 pilot failure preserved in ledger")
    }

    func testA12_20_BlockerCurrency_AllLedgerRowsCarried_NoneClosed() throws {
        let t = try twin()
        let reg = try XCTUnwrap(t["blockers"] as? [[String: Any]])
        let ids = Set(reg.map { str($0, "id") })
        // all 13 original ledger rows carried
        for orig in ["BLK-B1", "BLK-B2", "BLK-C1", "BLK-C2", "BLK-C3", "BLK-C4", "BLK-C5", "BLK-C6",
                     "BLK-H1", "BLK-H2", "BLK-H3", "BLK-H4", "BLK-H5"] {
            XCTAssertTrue(ids.contains(orig), "ledger blocker \(orig) vanished")
        }
        // nobody is CLOSED/RESOLVED in the registry; stale rows are explicitly STALE_LEDGER
        for b in reg {
            let s = str(b, "status")
            XCTAssertFalse(["CLOSED", "RESOLVED", "FIXED", "DONE"].contains(s),
                           "\(str(b, "id")): blocker silently closed (\(s))")
            XCTAssertFalse(str(b, "currency_note").isEmpty)
        }
        XCTAssertEqual(reg.count, 22)
        // view shows all 22
        let view = try text("docs/control-plane/OPEN_BLOCKERS_VIEW.md")
        for b in reg { XCTAssertTrue(view.contains(str(b, "id")), "view missing \(str(b, "id"))") }
    }

    func testA12_21_FailureMemory_HistoricallyEvidenced_NoInventedHistory() throws {
        let recs = try XCTUnwrap(try fmDoc()["records"] as? [[String: Any]])
        XCTAssertEqual(recs.count, 14)
        let nodeIDs = Set(try nodes(try twin()).map { str($0, "id") })
        let allowedStatus: Set<String> = ["ACTIVE_INVARIANT", "MITIGATED_GUARDED", "OPEN_SCOPE_LIMITATION"]
        for r in recs {
            XCTAssertTrue(allowedStatus.contains(str(r, "status")), "\(str(r, "id")): status \(str(r, "status"))")
            XCTAssertFalse(arr(r, "evidence").isEmpty)
            XCTAssertFalse(str(r, "first_seen").isEmpty)
            XCTAssertFalse(str(r, "root_cause").isEmpty)
            XCTAssertFalse(str(r, "invariant").isEmpty)
            for a in arr(r, "applies_to") where a != "ALL" && !a.hasSuffix("*") && !a.contains(" ") {
                XCTAssertTrue(nodeIDs.contains(a), "\(str(r, "id")): applies_to \(a) is not a twin node")
            }
        }
        // spot-verify historical anchors really exist (no invented history)
        XCTAssertTrue(fileExists("docs/audit/AUDIT9_F3_INVERSION_LOCK.md"))      // FM-003
        XCTAssertTrue(fileExists("docs/audit/AUDIT10_INVERSION_LOCK.md"))        // FM-003
        XCTAssertTrue(fileExists("docs/audit/AUDIT9_FPEDGE_ERRATUM.md"))         // FM-014
        let a10 = try text("docs/audit/GEN8_REAL_WORLD_CALIBRATION_ENTRY_GATE_INDEPENDENT_AUDIT.md")
        XCTAssertTrue(a10.contains("A10-F2-MULTISET"), "FM-005 first_seen anchor")
        XCTAssertTrue(a10.contains("A10-F2-WIRING"), "FM-006 first_seen anchor")
        let a11 = try text("docs/audit/GEN8_RWC_ENTRY_GATE_R1_INDEPENDENT_REAUDIT.md")
        XCTAssertTrue(a11.contains("A11-F2-APIBYPASS"), "FM-013 first_seen anchor")
    }

    // ═══════════════════ §13/§16/§29 — MUTATION TESTING (in-memory only) ═══════════════════

    func testA12_22_Mutation_ActiveIncompleteDependencyUnlock_GenericLawAccepts_FINDING() throws {
        let t = try twin()
        // (A) RWC-PRE-14 merely ACTIVE (in progress, NOT passed) + RWC-CORPUS flipped READY:
        var m = try mutate(t, node: "RWC-PRE-14") { $0["status"] = "ACTIVE" }
        m = try mutate(m, node: "RWC-CORPUS") { $0["status"] = "READY"; $0["blocked_by"] = [] }
        let ns = try nodes(m)
        // A12-F4 pin: the GENERIC per-node READY law (dep LOCKED-or-ACTIVE == satisfied) ACCEPTS this
        // forbidden unlock — corpus work authorized while the preregistration audit is merely running.
        XCTAssertEqual(genericReadyLawViolations(ns), [], "A12-F4 pin: generic law blind to ACTIVE-incomplete deps")
        // Today it is caught ONLY by hardcoded pins (next-action equality + forbidden-state list):
        XCTAssertFalse(b_CP04_ready(ns).isEmpty, "hardcoded equality catches it (for now)")
        XCTAssertFalse(b_CP05_forbidden(ns).isEmpty, "hardcoded forbidden-state pin catches it (for now)")
    }

    func testA12_23_Mutation_DependencyWithOpenBlocker_GenericLawAccepts_FINDING() throws {
        let t = try twin()
        // (B/C) dep ACTIVE while carrying open blockers; child READY.
        // CP-CONTROL-PLANE (ACTIVE) given a live blocker; CP-INDEPENDENT-AUDIT stays READY:
        let m = try mutate(t, node: "CP-CONTROL-PLANE") { $0["blockers"] = ["BLK-H2"] }
        let ns = try nodes(m)
        XCTAssertEqual(genericReadyLawViolations(ns), [],
                       "A12-F4 pin: generic law ignores open blockers on dependencies entirely")
        XCTAssertEqual(b_CP04_ready(ns), [], "builder CP04 ALSO accepts it — blocker-on-dep is not machine-checked")
        // (D) dep ACTIVE with required evidence absent — evidence presence is likewise not part of the
        // machine READY law (documented ready_law demands it; prose-only). Same acceptance:
        let m2 = try mutate(t, node: "CP-CONTROL-PLANE") {
            $0["evidence"] = ["claim_refs": [], "implementation_refs": [], "test_refs": [],
                              "device_refs": [], "calibration_refs": [], "audit_refs": []]
        }
        XCTAssertEqual(genericReadyLawViolations(try nodes(m2)), [], "A12-F4 pin: entry-evidence clause unenforced")
    }

    func testA12_24_Mutation_IllegalTransitions_ProseOnly_FINDING() throws {
        let t = try twin(); let f = try fmDoc()
        // CONTRADICTED → VERIFIED_WITH_LIMITATIONS without a resolution record (FM-014 violation):
        let m1 = try mutate(t, node: "P008-CALIBRATION-PILOT") {
            var truth = $0["truth"] as! [String: Any]
            truth["calibration"] = "VERIFIED_WITH_LIMITATIONS"
            $0["truth"] = truth
        }
        XCTAssertEqual(try allBuilderChecks(m1, f).filter { !$0.contains("NT-") }, [],
                       "A12-F4 pin: CONTRADICTED→VWL passes every structural builder check")
        // (CP06 would still see the NT text, but the NODE AXIS upgrade itself is not transition-checked;
        //  only the specific value VERIFIED on the calibration axis is pinned by CP05.)
        let m1Violations = try allBuilderChecks(m1, f)
        XCTAssertTrue(m1Violations.isEmpty, "no builder check fails on the axis upgrade: \(m1Violations)")
        // device VERIFIED without any device evidence ref (axis-specific adequacy gap):
        let m2 = try mutate(t, node: "P009B-EXPERT-MESH") {
            var truth = $0["truth"] as! [String: Any]
            truth["real_device"] = "VERIFIED"
            $0["truth"] = truth
        }
        XCTAssertEqual(try allBuilderChecks(m2, f), [],
                       "A12-F4 pin: device-VERIFIED w/o device_refs passes (CP07 counts ANY evidence array)")
        // UNVERIFIED → VERIFIED_WITH_LIMITATIONS with zero evidence IS caught (CP07 total==0):
        let m3 = try mutate(t, node: "EP7-TV") {
            var truth = $0["truth"] as! [String: Any]
            truth["functional"] = "VERIFIED_WITH_LIMITATIONS"
            $0["truth"] = truth
        }
        XCTAssertFalse(try allBuilderChecks(m3, f).isEmpty, "zero-evidence verified-class IS caught by CP07 logic")
    }

    func testA12_25_Mutation_CensusDeletions_PartiallyUndetected_FINDING() throws {
        let t = try twin(); let f = try fmDoc()
        // Deleting NT-PREVDWELL (1 of 9) passes CP06 (only 8 IDs pinned) — A12-F12:
        var c1 = try deepCopy(t)
        c1["negative_truth"] = (c1["negative_truth"] as! [[String: Any]]).filter { str($0, "id") != "NT-PREVDWELL" }
        XCTAssertEqual(b_CP06_negativeTruth(c1), [], "A12-F12 pin: NT-PREVDWELL deletable undetected")
        // Deleting NT-P008-PILOT-FAILED IS caught:
        var c2 = try deepCopy(t)
        c2["negative_truth"] = (c2["negative_truth"] as! [[String: Any]]).filter { str($0, "id") != "NT-P008-PILOT-FAILED" }
        XCTAssertFalse(b_CP06_negativeTruth(c2).isEmpty)
        // Deleting BLK-GH-CREDENTIALS (not among CP03's 9 pins, not carried by any node) passes CP03:
        var c3 = try deepCopy(t)
        c3["blockers"] = (c3["blockers"] as! [[String: Any]]).filter { str($0, "id") != "BLK-GH-CREDENTIALS" }
        XCTAssertEqual(b_CP03_blockers(c3, try nodes(c3)), [], "A12-F12 pin: unpinned blocker deletable undetected")
        // Deleting BLK-ECE-UNMET IS caught:
        var c4 = try deepCopy(t)
        c4["blockers"] = (c4["blockers"] as! [[String: Any]]).filter { str($0, "id") != "BLK-ECE-UNMET" }
        XCTAssertFalse(b_CP03_blockers(c4, try nodes(c4)).isEmpty)
        // Deleting FM-004 IS caught (CP08 1...14 census):
        var c5 = try deepCopy(f)
        c5["records"] = (c5["records"] as! [[String: Any]]).filter { str($0, "id") != "FM-004" }
        XCTAssertFalse(b_CP08_fm(c5, try nodes(t)).isEmpty)
    }

    func testA12_26_Mutation_StructuralAttacks_CatchMatrix() throws {
        let t = try twin(); let f = try fmDoc()
        // cycle insertion → caught (CP02):
        let mCycle = try mutate(t, node: "P001-DEVICE-MEASUREMENT") { $0["depends_on"] = ["P009E-CALIBRATION"] }
        XCTAssertFalse(b_CP02_graph(try nodes(mCycle)).isEmpty, "cycle caught")
        // missing dependency target → caught (CP02):
        let mDangling = try mutate(t, node: "RWC-FIT") { $0["depends_on"] = ["RWC-ANNOTATION", "GHOST-NODE"] }
        XCTAssertFalse(b_CP02_graph(try nodes(mDangling)).isEmpty, "dangling dep caught")
        // calibration VERIFIED anywhere → caught (CP05):
        let mCal = try mutate(t, node: "P009E-CALIBRATION") {
            var truth = $0["truth"] as! [String: Any]; truth["calibration"] = "VERIFIED"; $0["truth"] = truth
        }
        XCTAssertFalse(b_CP05_forbidden(try nodes(mCal)).isEmpty, "false VERIFIED calibration caught")
        // Presentation READY while score gate CLOSED → caught (CP04 equality + CP05):
        let mPres = try mutate(t, node: "EP3-PRESENTATION") { $0["status"] = "READY"; $0["blocked_by"] = [] }
        XCTAssertFalse((b_CP04_ready(try nodes(mPres)) + b_CP05_forbidden(try nodes(mPres))).isEmpty)
        // nonexistent REQ ID → NOT caught by any builder check (A12-F4 census):
        let mReq = try mutate(t, node: "EP7-TV") { $0["requirements"] = ["ZZZ-999"] }
        XCTAssertEqual(try allBuilderChecks(mReq, f), [], "A12-F4 pin: requirement refs never validated by builder")
        // broken file evidence ref → NOT caught (CP07 checks only 5 hardcoded paths):
        let mRef = try mutate(t, node: "P001-DEVICE-MEASUREMENT") {
            var ev = $0["evidence"] as! [String: Any]
            ev["implementation_refs"] = ["docs/implementation/DOES_NOT_EXIST.md"]
            $0["evidence"] = ev
        }
        XCTAssertEqual(try allBuilderChecks(mRef, f), [], "A12-F4 pin: arbitrary evidence paths unvalidated")
        // builder claim overriding audit verdict (audit says PASS → flipped to FAIL, status stays LOCKED):
        let mAudit = try mutate(t, node: "P009D-POLICY") {
            var a = $0["audit"] as! [String: Any]; a["latest_verdict"] = "FAIL"; $0["audit"] = a
        }
        XCTAssertEqual(try allBuilderChecks(mAudit, f), [],
                       "A12-F4 pin: verdict↔status coherence not machine-checked (authority conflicts prose-only)")
        // W2 node jumped to W0 (wave inversion in node data) → NOT caught (CP09 checks only membership):
        let mWave = try mutate(t, node: "EP7-TV") {
            var r = $0["release"] as! [String: Any]; r["wave"] = "W0"; $0["release"] = r
        }
        XCTAssertEqual(try allBuilderChecks(mWave, f), [], "A12-F7 pin: wave reassignment undetected")
    }

    // ═══════════════════ §14 — FUTURE-STATE SIMULATION (state machine, not snapshot) ═══════════════

    /// Simulation semantics per documented ready_law: a dependency is satisfied ONLY by a terminal
    /// PASS/LOCKED state (simulated "done" set). Gates must be PASSED, not merely started.
    private func simulateReady(done: Set<String>, _ ns: [[String: Any]]) -> Set<String> {
        var ready = Set<String>()
        for n in ns where !done.contains(str(n, "id")) {
            let deps = arr(n, "depends_on")
            if deps.allSatisfy({ done.contains($0) }) { ready.insert(str(n, "id")) }
        }
        return ready
    }

    func testA12_27_FutureStateSimulations_EightScenarios() throws {
        let ns = try nodes(try twin())
        let locked: Set<String> = Set(ns.filter { str($0, "status") == "LOCKED" }.map { str($0, "id") })
            .union(["CP-CONTROL-PLANE"]) // control plane completes when its audit passes

        // S1: CP audit PASS → PRE-01..05 and PRE-13 become READY (direct deps); 06..12,14 still not.
        let s1 = simulateReady(done: locked.union(["CP-INDEPENDENT-AUDIT"]), ns)
        for id in ["RWC-PRE-01", "RWC-PRE-02", "RWC-PRE-03", "RWC-PRE-04", "RWC-PRE-05", "RWC-PRE-13"] {
            XCTAssertTrue(s1.contains(id), "S1: \(id) should unlock on CP audit PASS")
        }
        for id in ["RWC-PRE-06", "RWC-PRE-14", "RWC-CORPUS", "RWC-FIT", "EP3-PRESENTATION"] {
            XCTAssertFalse(s1.contains(id), "S1: \(id) must NOT unlock yet")
        }
        // S2: PRE-01..13 minus one (12 missing) → PRE-14 NOT ready.
        var pre = Set((1...13).map { String(format: "RWC-PRE-%02d", $0) })
        pre.remove("RWC-PRE-12")
        let s2 = simulateReady(done: locked.union(["CP-INDEPENDENT-AUDIT"]).union(pre), ns)
        XCTAssertFalse(s2.contains("RWC-PRE-14"), "S2: PRE-14 requires ALL thirteen")
        // S3: all 13 done → PRE-14 READY.
        pre.insert("RWC-PRE-12")
        let s3done = locked.union(["CP-INDEPENDENT-AUDIT"]).union(pre)
        XCTAssertTrue(simulateReady(done: s3done, ns).contains("RWC-PRE-14"), "S3")
        // S4: PRE-14 not passed → CORPUS not ready.
        XCTAssertFalse(simulateReady(done: s3done, ns).contains("RWC-CORPUS"), "S4")
        // S5: PRE-14 PASS → CORPUS may become READY.
        let s5done = s3done.union(["RWC-PRE-14"])
        XCTAssertTrue(simulateReady(done: s5done, ns).contains("RWC-CORPUS"), "S5")
        // S6: corpus done, annotation NOT done → FIT not ready.
        let s6done = s5done.union(["RWC-CORPUS"])
        XCTAssertFalse(simulateReady(done: s6done, ns).contains("RWC-FIT"), "S6")
        // S7: fit done, held-out NOT sealed/passed → Presentation (production score) stays locked.
        let s7done = s6done.union(["RWC-ANNOTATION", "RWC-FIT"])
        XCTAssertFalse(simulateReady(done: s7done, ns).contains("EP3-PRESENTATION"), "S7")
        // S8: held-out passes but device E2E absent → Presentation STILL not ready.
        let s8done = s7done.union(["RWC-HELDOUT"])
        XCTAssertFalse(simulateReady(done: s8done, ns).contains("EP3-PRESENTATION"),
                       "S8: presentation requires RWC-DEVICE-E2E as well")
        XCTAssertTrue(simulateReady(done: s8done.union(["RWC-DEVICE-E2E"]), ns).contains("EP3-PRESENTATION"),
                      "S8b: with held-out + device E2E both passed, presentation finally unlocks")
    }

    // ═══════════════════ §12/§24 — DAG SEMANTICS & RWC-PRE SUBGRAPH ═══════════════════

    func testA12_28_CriticalPathEdges_SemanticallyRequired() throws {
        let ns = try nodes(try twin())
        let byID = Dictionary(uniqueKeysWithValues: ns.map { (str($0, "id"), $0) })
        func deps(_ id: String) -> [String] { arr(byID[id] ?? [:], "depends_on") }
        XCTAssertEqual(deps("CP-INDEPENDENT-AUDIT"), ["CP-CONTROL-PLANE"])
        XCTAssertEqual(deps("RWC-PRE-06"), ["RWC-PRE-05"], "isolation protocol needs the frozen handbook")
        XCTAssertEqual(deps("RWC-PRE-07"), ["RWC-PRE-06"])
        XCTAssertEqual(deps("RWC-PRE-08"), ["RWC-PRE-07"])
        XCTAssertEqual(deps("RWC-PRE-09"), ["RWC-PRE-08"])
        XCTAssertEqual(deps("RWC-PRE-10"), ["RWC-PRE-09"])
        XCTAssertEqual(Set(deps("RWC-PRE-11")), ["RWC-PRE-09", "RWC-PRE-10"],
                       "gate freeze REQUIRES feasibility + slices first (feasibility-before-thresholds)")
        XCTAssertEqual(deps("RWC-PRE-12"), ["RWC-PRE-11"], "sealing after gate freeze — before data visibility")
        XCTAssertEqual(Set(deps("RWC-PRE-14")), Set((1...13).map { String(format: "RWC-PRE-%02d", $0) }))
        XCTAssertEqual(deps("RWC-CORPUS"), ["RWC-PRE-14"])
        XCTAssertEqual(deps("RWC-ANNOTATION"), ["RWC-CORPUS"])
        XCTAssertEqual(deps("RWC-FIT"), ["RWC-ANNOTATION"])
        XCTAssertEqual(deps("RWC-HELDOUT"), ["RWC-FIT"])
        XCTAssertEqual(Set(deps("RWC-DEVICE-E2E")), ["RWC-HELDOUT", "RWC-PRE-13"])
        XCTAssertEqual(Set(deps("EP3-PRESENTATION")), ["RWC-HELDOUT", "RWC-DEVICE-E2E"])
        // P008 history kept in the chain: P009A depends on the FAILED pilot node (negative evidence kept
        // in-line, not bypassed); P009E engineering calibration does NOT claim the RWC program:
        XCTAssertEqual(deps("P009A-IDENTITY-FOUNDATION"), ["P008-CALIBRATION-PILOT"])
        let p009e = byID["P009E-CALIBRATION"]!
        XCTAssertTrue(str(p009e["capability"] as? [String: Any] ?? [:], "availability")
                        .contains("ENGINEERING_CALIBRATION_ONLY"))
    }

    func testA12_29_WaveModel_W0ScopeComplete_ButCertificationGateIsTerminal_FINDING() throws {
        let t = try twin(); let d = try dag()
        let ns = try nodes(t)
        // W0 node census — matches the canonical W0 core-proof scope:
        let w0 = Set(ns.filter { (($0["release"] as? [String: Any])?["wave"] as? String) == "W0" }.map { str($0, "id") })
        XCTAssertEqual(w0, ["EP3-PRESENTATION", "EP3-CONTENT-AHEAD", "EP3-CONTROLLED-BROWSER",
                            "EP3-LONGFORM-TEMPORAL", "EP3-ANDROID-GUARDIAN", "EP4-FAMILY-AUTHORITY",
                            "EP5-ADAPTERS-RECONCILIATION", "EP8-RELEASE-WAVES"])
        // no iOS-polish / TV as W0 prereq:
        for notW0 in ["EP3-IOS-GUARDIAN", "EP7-TV"] { XCTAssertFalse(w0.contains(notW0)) }
        let waves = ((d["release_waves"] as? [[String: Any]]) ?? []).map { str($0, "id") }
        XCTAssertEqual(waves, ["W0", "W1", "W2", "W3"])
        // A12-F7 pin (LOW): EP8-RELEASE-WAVES — the wave-certification GATE — blocks NOTHING; no W1/W2/W3
        // node depends on it. Wave-order never-invert is enforced only as prose + the waves-array order.
        let gate = try XCTUnwrap(ns.first { str($0, "id") == "EP8-RELEASE-WAVES" })
        XCTAssertEqual(arr(gate, "blocks"), [], "A12-F7 pin: certification gate is a graph SINK")
        let dependents = ns.filter { arr($0, "depends_on").contains("EP8-RELEASE-WAVES") }
        XCTAssertTrue(dependents.isEmpty, "A12-F7 pin: no node is structurally gated by wave certification")
    }

    // ═══════════════════ §6 — BUILD BIBLE COVERAGE (independent 665/665 validation) ═══════════════

    func testA12_30_BibleCoverageMatrix_NoGaps_NoSilentLoss() throws {
        let m = try text("docs/traceability/CANONICAL_SECTION_COVERAGE_MATRIX.md")
        var covered = Set<Int>()
        var duplicates: [String] = []
        var apps = Set<String>()
        let rangeRegex = try NSRegularExpression(pattern: "^\\| §(\\d+)(?:[–-]§(\\d+))? \\|")
        let appRegex = try NSRegularExpression(pattern: "^\\| App ([A-H]) \\|")
        for line in m.components(separatedBy: "\n") {
            let nsr = NSRange(line.startIndex..., in: line)
            if let match = rangeRegex.firstMatch(in: line, range: nsr) {
                let lo = Int(line[Range(match.range(at: 1), in: line)!])!
                let hi = match.range(at: 2).location == NSNotFound ? lo
                       : Int(line[Range(match.range(at: 2), in: line)!])!
                XCTAssertLessThanOrEqual(lo, hi, "inverted range row: \(line)")
                for s in lo...hi {
                    if !covered.insert(s).inserted { duplicates.append("§\(s)") }
                }
            } else if let match = appRegex.firstMatch(in: line, range: nsr) {
                let a = String(line[Range(match.range(at: 1), in: line)!])
                if !apps.insert(a).inserted { duplicates.append("App \(a)") }
            }
        }
        // COMPLETE: every §0..§656 covered exactly once; all 8 appendices; zero duplicate inflation.
        XCTAssertEqual(covered, Set(0...656), "missing sections: \(Set(0...656).subtracting(covered).sorted())")
        XCTAssertEqual(apps, ["A", "B", "C", "D", "E", "F", "G", "H"])
        XCTAssertEqual(duplicates, [], "duplicate mappings would inflate the 665 count")
        XCTAssertEqual(covered.count + apps.count, 665, "the 665/665 claim is arithmetically TRUE")
        // superseded sections explicitly flagged, never silently dropped:
        XCTAssertTrue(m.contains("SUP"), "superseded disposition in use")
        XCTAssertTrue(m.contains("§63"), "OCTOPUS 12→20 supersession visible")
        XCTAssertTrue(m.contains("Pure Bar"), "Star→Pure Bar supersession visible")
        XCTAssertTrue(m.contains("D-0006"), "supersession tied to a decision ID")
    }

    // ═══════════════════ §25 — PROGRESS MODEL REPRODUCTION ═══════════════════

    func testA12_31_ProgressModel_AReproducible_BUnderdetermined_FINDING() throws {
        // documented inputs (CURRENT_STATE.md): weights I:18 II:12 III:20 IV:12 V:14 VI:8 VII:10 VIII:6
        // per-epoch completions I:60 II:8 III:2 IV:3 V:1 VI:3 VII:2 VIII:4
        let weights: [Double] = [18, 12, 20, 12, 14, 8, 10, 6]
        let completion: [Double] = [0.60, 0.08, 0.02, 0.03, 0.01, 0.03, 0.02, 0.04]
        XCTAssertEqual(weights.reduce(0, +), 100, "epoch weights sum to 100")
        let overall = zip(weights, completion).map(*).reduce(0, +)
        XCTAssertEqual(overall, 13.34, accuracy: 0.01, "A: OVERALL recomputes to 13.34 → '≈13%' REPRODUCIBLE")
        // B (core brain ≈55%): documented inputs functional .85 ×.4 + device .15 ×.2 + calibration .10 ×.2
        // leave 0.39; reaching 0.55 REQUIRES an UNDOCUMENTED privacy/security ≈0.80 input.
        let documentedB = 0.4 * 0.85 + 0.2 * 0.15 + 0.2 * 0.10
        XCTAssertEqual(documentedB, 0.39, accuracy: 0.001)
        let impliedPrivSec = (0.55 - documentedB) / 0.2
        XCTAssertEqual(impliedPrivSec, 0.80, accuracy: 0.001,
                       "A12-F8 pin: B=55% needs an undocumented ~80% priv/sec input (and is not reconciled with Epoch-I ≈60% used in A)")
        // the view honestly brackets everything as PLANNING ESTIMATE (bounding is explicit):
        let cs = try text("docs/control-plane/CURRENT_STATE.md")
        XCTAssertTrue(cs.contains("PLANNING ESTIMATE"))
        XCTAssertTrue(cs.contains("not a scientific measurement"))
    }

    // ═══════════════════ §26 — GENERATED VIEW CONSISTENCY ═══════════════════

    func testA12_32_GeneratedViews_NoDriftAgainstCanonicalState() throws {
        let cs = try text("docs/control-plane/CURRENT_STATE.md")
        let naw = try text("docs/control-plane/NEXT_ALLOWED_WORK.md")
        let es = try text("docs/control-plane/EPOCH_STATUS.md")
        let cp = try text("docs/control-plane/CRITICAL_PATH.md")
        let dagMD = try text("docs/control-plane/GEN8_ULU_EVREN_MASTER_EXECUTION_DAG.md")
        for v in [cs, naw, es, cp, dagMD] {
            XCTAssertTrue(v.contains("GENERATED") || v.contains("GENERATED_VIEW"), "view must self-declare GENERATED")
        }
        XCTAssertTrue(cs.contains("CP-INDEPENDENT-AUDIT") && naw.contains("CP-INDEPENDENT-AUDIT"))
        XCTAssertTrue(naw.contains("Corpus acquisition (needs RWC-PRE-14 PASS)"))
        XCTAssertTrue(naw.contains("Presentation/Glyph/Motion"))
        // DAG yaml current_next_action == twin READY set (builder asserts too; recomputed here)
        let na = try XCTUnwrap(try dag()["current_next_action"] as? [String: Any])
        XCTAssertEqual(na["ready_nodes"] as? [String], ["CP-INDEPENDENT-AUDIT"])
        for forbidden in ["corpus acquisition", "fitting", "held-out seal", "Presentation/Glyph/Motion"] {
            XCTAssertTrue(((na["forbidden_now"] as? [String]) ?? []).contains(where: { $0.contains(forbidden.split(separator: " ").first!) }),
                          "forbidden_now must include \(forbidden)")
        }
        // no view is stronger than the twin: none may contain a VERIFIED calibration or real-world claim
        for v in [cs, es, cp] {
            XCTAssertFalse(v.contains("calibration VERIFIED"), "view stronger than twin")
            XCTAssertFalse(v.lowercased().contains("real-world calibrated"), "forbidden claim in view")
        }
        // EPOCH_STATUS percentages match CURRENT_STATE's documented completions
        for anchor in ["≈60%", "≈8%", "≈2%", "≈3%", "≈1%", "≈4%"] {
            XCTAssertTrue(es.contains(anchor), "EPOCH_STATUS missing \(anchor)")
        }
        XCTAssertTrue(es.contains("≈ 13%") || es.contains("≈13%"), "overall consistent across views")
    }

    // ═══════════════════ §21/§22/§23 — SOCIAL / FAMILY / CONTROLLED LEARNING COVERAGE ═══════════════

    func testA12_33_EpochScopeCoverage_SocialFamilyLearning() throws {
        let d = try dag()
        let epochs = Dictionary(uniqueKeysWithValues:
            ((d["epochs"] as? [[String: Any]]) ?? []).map { (str($0, "id"), str($0, "scope")) })
        // EPOCH V — social command surface list:
        let v = try XCTUnwrap(epochs["EPOCH_V"])
        for item in ["Accounts", "Unified Inbox", "Create", "Asset Library", "Publish",
                     "Scheduler/Calendar", "Insights", "adapter reliability", "reconciliation", "Creator Bridge"] {
            XCTAssertTrue(v.contains(item), "EPOCH_V scope missing \(item)")
        }
        // deep requirements (OAuth, wrong-account, idempotency, reconcile) live in PUB-001 — resolvable:
        let reg = try text("docs/requirements/REQUIREMENTS_REGISTRY.yaml")
        for item in ["OAuth/PKCE", "idempotent publish", "Wrong-account publish", "reconciliation",
                     "Duplicate external post prevented"] {
            XCTAssertTrue(reg.contains(item), "PUB-001 depth missing: \(item)")
        }
        // EPOCH IV — family/human surface:
        let e4 = try XCTUnwrap(epochs["EPOCH_IV"])
        for item in ["guardian authority", "anti-tamper", "device trust", "household", "entitlement"] {
            XCTAssertTrue(e4.contains(item), "EPOCH_IV scope missing \(item)")
        }
        for item in ["anti-coercion", "Child cannot silently disable", "no covert surveillance",
                     "travel/away modes", "device revoke supported"] {
            XCTAssertTrue(reg.contains(item), "family depth missing in registry: \(item)")
        }
        // EPOCH VI — controlled learning three-tier shape + anti-self-modification law:
        let e6 = try XCTUnwrap(epochs["EPOCH_VI"])
        for item in ["bounded personal learning", "privacy-safe shared learning", "shadow", "canary", "rollback"] {
            XCTAssertTrue(e6.contains(item), "EPOCH_VI scope missing \(item)")
        }
        let ns = try nodes(try twin())
        let byID = Dictionary(uniqueKeysWithValues: ns.map { (str($0, "id"), $0) })
        XCTAssertEqual(str((byID["EP6-BOUNDED-LEARNING"]!["release"] as! [String: Any]), "gate"), "privacy audit")
        XCTAssertEqual(str((byID["EP6-MODEL-EVOLUTION"]!["release"] as! [String: Any]), "gate"),
                       "signed manifests + rollback artifacts")
        XCTAssertTrue(str((byID["EP6-BOUNDED-LEARNING"]!["capability"] as! [String: Any]), "availability")
                        .contains("explicit consent"), "immutable rule 16 bound to the node")
        let schema = try text("docs/control-plane/GEN8_PROJECT_TWIN_SCHEMA.md")
        XCTAssertTrue(schema.contains("auto-merge, auto-deploy, weaken gates"),
                      "governance limits forbid self-granted authority")
        // NOTE (pinned limitation, not a failure): the twin carries Social/Family depth at PROGRAM
        // granularity; the richer surface lives in the registry + coverage matrix (Bible §319-375 → SOC
        // reqs are explicitly DEFER/P1 there). Coverage preserved, granularity deferred.
        let matrix = try text("docs/traceability/CANONICAL_SECTION_COVERAGE_MATRIX.md")
        XCTAssertTrue(matrix.contains("SOC reqs P1"), "SOC depth is explicitly DEFERred, not lost")
    }

    // ═══════════════════ §32 — PHASE PACKET REPRESENTABILITY ═══════════════════

    func testA12_34_PhasePacket_AllFieldsPresent_RwcPre02Instantiable() throws {
        let tpl = try text("docs/control-plane/GEN8_PHASE_PACKET_TEMPLATE.yaml")
        for field in ["phase_id:", "purpose:", "entry_sha:", "locked_predecessors:", "requirements:",
                      "dependencies:", "scope:", "in:", "out:", "forbidden_actions:", "files_modules:",
                      "invariants:", "known_failures:", "blockers:", "tests:", "required_families:",
                      "regression:", "privacy:", "security:", "resource:", "device_evidence:",
                      "calibration_evidence:", "rollback:", "tag:", "commit:", "audit_requirements:",
                      "definition_of_done:", "stop_condition:", "next_allowed_node:"] {
            XCTAssertTrue(tpl.contains(field), "packet template missing mandatory field \(field)")
        }
        // Instantiate RWC-PRE-02 from the twin — every critical execution datum must be representable:
        let ns = try nodes(try twin())
        let n = try XCTUnwrap(ns.first { str($0, "id") == "RWC-PRE-02" })
        let packet: [String: Any] = [
            "phase_id": str(n, "id"),
            "purpose": str(n, "name"),
            "entry_sha": "4d6649c7a67a22c0b5eed5f1fd94bd3f3d25e8f8",
            "locked_predecessors": ["gen8-rwc-entry-gate-r1-locked-engineering",
                                    "gen8-ulu-evren-control-plane-audit-candidate"],
            "requirements": arr(n, "requirements"),
            "dependencies": arr(n, "depends_on"),
            "scope_in": ["opaque asset-ID charset law", "composite-ID separator escaping"],
            "scope_out": ["corpus acquisition", "fitting", "Presentation"],
            "forbidden_actions": ["no corpus", "no fitting", "no gate tuning after data visibility"],
            "invariants": arr(n, "failure_memory_refs"),
            "known_failures": arr(n, "failure_memory_refs"),
            "blockers": arr(n, "blockers"),
            "rollback_tag": "gen8-ulu-evren-control-plane-audit-candidate",
            "audit_requirements": "independent clean-session audit (THREE_VERDICT)",
            "stop_condition": str((n["next"] as? [String: Any]) ?? [:], "allowed_when"),
            "next_allowed_node": "RWC-PRE-14 (gate)",
        ]
        XCTAssertEqual(packet["blockers"] as? [String], ["BLK-A11-IDCHARSET", "BLK-A11-COMPOSITE-ALIAS"],
                       "the packet carries exactly the owner blockers from the twin")
        XCTAssertEqual(packet["invariants"] as? [String], ["FM-005"], "FM binding representable")
        XCTAssertEqual(packet["dependencies"] as? [String], ["CP-INDEPENDENT-AUDIT"])
        XCTAssertFalse((packet["stop_condition"] as? String ?? "").isEmpty)
        // nothing critical was unrepresentable → template SUFFICIENT for RWC-PRE execution packets.
    }

    // ═══════════════════ §30 — CONTROL-PLANE SECURITY / PRODUCTION UNTOUCHED ═══════════════════

    func testA12_35_NoSecretsNoSideEffects_FrozenArtifactsIntact() throws {
        for rel in ["docs/control-plane/GEN8_PROJECT_TWIN.yaml",
                    "docs/control-plane/GEN8_ULU_EVREN_MASTER_EXECUTION_DAG.yaml",
                    "docs/control-plane/GEN8_ENGINEERING_FAILURE_MEMORY.yaml"] {
            let s = try text(rel).lowercased()
            for needle in ["private key", "password", "api_key", "secret=", "bearer "] {
                XCTAssertFalse(s.contains(needle), "\(rel): suspicious secret-like content (\(needle))")
            }
        }
        // frozen audit originals byte-intact (SHA-256 anchors cited by the twin's sources[] note):
        func sha256(_ rel: String) throws -> String {
            let d = try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + rel))
            return SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
        }
        XCTAssertEqual(try sha256("docs/audit/AUDIT9_P009ER1Probes_ORIGINAL_LOCKED.swift.txt"),
                       "a349a487dc091d444f04939864582175409542f47d6275c6bb0bd8022163bc4e")
        XCTAssertEqual(try sha256("docs/audit/AUDIT10_RealWorldCalibrationEntryGateProbes_ORIGINAL_LOCKED.swift.txt"),
                       "a1ffb855cea4af9b9ee83e88e9240982d4df31d5393dac2b5a668c597caf0580")
        // RWC locks preserved in CODE (the control plane changed zero runtime behavior):
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims)
    }

    // ═══════════════════ baseline coherence of the whole candidate ═══════════════════

    func testA12_36_BuilderChecksReimplemented_AllGreenOnCandidateAsIs() throws {
        // Sanity: the candidate as-committed passes every reimplemented builder check — so every
        // mutation "caught/uncaught" attribution above is meaningful relative to a green baseline.
        XCTAssertEqual(try allBuilderChecks(try twin(), try fmDoc()), [])
    }
}
