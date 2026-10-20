import XCTest
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// CONTROL PLANE R1 REMEDIATION — fresh builder test family (additive).
// Proves the FIXED contracts for AUDIT12 findings A12-F2/F3/F4 (+coupled F6/F10) with in-memory
// mutation attacks against the NEW evaluator/validator laws — the exact attacks AUDIT12 proved the
// old generic law was blind to. AUDIT12 probes remain historical evidence; their 5 inversions are
// governed by docs/audit/AUDIT12_INVERSION_LOCK.md and re-verified from disk here.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class ControlPlaneR1RemediationTests: XCTestCase {

    private var repoRoot: String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }
    private func load(_ rel: String) throws -> [String: Any] {
        let d = try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + rel))
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: d) as? [String: Any])
    }
    private func twin() throws -> [String: Any] { try load("docs/control-plane/GEN8_PROJECT_TWIN.yaml") }
    private func reqMap() throws -> [String: Any] { try load("docs/control-plane/GEN8_REQUIREMENT_NODE_MAP.yaml") }
    private func mutate(_ t: [String: Any], node: String, _ f: (inout [String: Any]) -> Void) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: t)
        var copy = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var ns = copy["nodes"] as! [[String: Any]]
        let i = try XCTUnwrap(ns.firstIndex { ($0["id"] as! String) == node })
        f(&ns[i]); copy["nodes"] = ns
        return copy
    }
    private func ready(_ t: [String: Any], passed: Set<String> = []) -> Set<String> {
        ControlPlaneStateEvaluatorV1.computedReady(twin: t, passed: passed)
    }

    // ── A12-F4: the unsafe unlocks AUDIT12 proved are now REFUSED by the typed engine ──

    /// PRE-14 merely ACTIVE (audit running, NOT passed) can NEVER unlock corpus — the exact A12_22 attack.
    func testR1_M1_Pre14ActiveNeverUnlocksCorpus() throws {
        var passed: Set<String> = ["CP-INDEPENDENT-AUDIT", "CP-CONTROL-PLANE"]
        passed.formUnion((1...13).map { String(format: "RWC-PRE-%02d", $0) })
        let m = try mutate(try twin(), node: "RWC-PRE-14") { $0["status"] = "ACTIVE" }
        let r = ready(m, passed: passed)
        XCTAssertFalse(r.contains("RWC-CORPUS"),
                       "A12-F4 FIXED: GATE_PASS contract — an ACTIVE (unpassed) preregistration audit never unlocks corpus")
        // and even a hostile snapshot flip of corpus to READY is caught: computed != declared
        let m2 = try mutate(m, node: "RWC-CORPUS") { $0["status"] = "READY"; $0["blocked_by"] = [] }
        XCTAssertFalse(ready(m2, passed: passed).contains("RWC-CORPUS"),
                       "snapshot READY is never authoritative — the engine recomputes")
    }

    /// Dependency ACTIVE while carrying an OPEN blocker cannot satisfy the candidate edge (A12_23-B).
    func testR1_M2_ActiveCandidateWithOpenBlockerRefused() throws {
        let m = try mutate(try twin(), node: "CP-CONTROL-PLANE") { $0["blockers"] = ["BLK-H2"] }
        XCTAssertFalse(ready(m).contains("CP-INDEPENDENT-AUDIT"),
                       "A12-F4 FIXED: blocker-laden ACTIVE candidate cannot unlock its audit")
    }

    /// Dependency ACTIVE with required candidate evidence stripped cannot satisfy the edge (A12_23-D).
    func testR1_M3_EvidenceStrippedCandidateRefused() throws {
        let m = try mutate(try twin(), node: "CP-CONTROL-PLANE") {
            var impl = $0["implementation"] as! [String: Any]; impl["refs"] = []; $0["implementation"] = impl
        }
        XCTAssertFalse(ready(m).contains("CP-INDEPENDENT-AUDIT"),
                       "A12-F4 FIXED: entry-evidence clause is machine-enforced for the candidate edge")
    }

    /// CONTRADICTED may never improve without a resolution record (A12_24-m1 attack now refused).
    func testR1_M4_ContradictionUpgradeRequiresResolution() throws {
        let p008 = try XCTUnwrap((try twin()["nodes"] as? [[String: Any]])?.first { ($0["id"] as! String) == "P008-CALIBRATION-PILOT" })
        let noRes = ControlPlaneStateEvaluatorV1.TransitionContext(hasResolutionRecord: false, node: p008)
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.legalAxisTransition(axis: "calibration", from: "CONTRADICTED",
                                                                        to: "VERIFIED_WITH_LIMITATIONS", ctx: noRes),
                       "A12-F4 FIXED: CONTRADICTED->VWL without resolution ledger is ILLEGAL")
        let withRes = ControlPlaneStateEvaluatorV1.TransitionContext(hasResolutionRecord: true, node: p008)
        // even WITH a resolution record, a verified-class calibration claim needs calibration evidence:
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.legalAxisTransition(axis: "calibration", from: "CONTRADICTED",
                                                                        to: "VERIFIED_WITH_LIMITATIONS", ctx: withRes),
                       "calibration upgrades additionally require calibration_refs (FM-012)")
    }

    /// device-VERIFIED without device refs is an ILLEGAL transition (A12_24-m2 attack now refused),
    /// and the LIVE-twin axis law also rejects it (CP13 logic on a mutated copy).
    func testR1_M5_DeviceVerifiedWithoutDeviceEvidenceRefused() throws {
        let mesh = try XCTUnwrap((try twin()["nodes"] as? [[String: Any]])?.first { ($0["id"] as! String) == "P009B-EXPERT-MESH" })
        let ctx = ControlPlaneStateEvaluatorV1.TransitionContext(hasResolutionRecord: true, node: mesh)
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.legalAxisTransition(axis: "real_device", from: "UNVERIFIED",
                                                                        to: "VERIFIED", ctx: ctx),
                       "A12-F4 FIXED: device truth never upgrades without device_refs (FM-002/FM-004)")
        let m = try mutate(try twin(), node: "P009B-EXPERT-MESH") {
            var truth = $0["truth"] as! [String: Any]; truth["real_device"] = "VERIFIED"; $0["truth"] = truth
        }
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.axisEvidenceViolations(twin: m).isEmpty,
                       "live axis law catches the mutated claim")
    }

    /// human_product is never upgradable today (no evidence class exists in the repo).
    func testR1_M6_HumanAxisNeverUpgradableToday() throws {
        let any = try XCTUnwrap((try twin()["nodes"] as? [[String: Any]])?.first)
        let ctx = ControlPlaneStateEvaluatorV1.TransitionContext(hasResolutionRecord: true, node: any)
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.legalAxisTransition(axis: "human_product", from: "UNVERIFIED",
                                                                        to: "VERIFIED_WITH_LIMITATIONS", ctx: ctx))
    }

    /// A standing FAIL/FIX audit verdict can never sit under LOCKED without resolution (A12_26-mAudit).
    func testR1_M7_VerdictStatusCoherence() throws {
        let m = try mutate(try twin(), node: "P009D-POLICY") {
            var a = $0["audit"] as! [String: Any]; a["latest_verdict"] = "FAIL"; $0["audit"] = a
        }
        let mutated = try XCTUnwrap((m["nodes"] as? [[String: Any]])?.first { ($0["id"] as! String) == "P009D-POLICY" })
        XCTAssertFalse(ControlPlaneStateEvaluatorV1.verdictStatusCoherent(node: mutated, hasResolutionRecord: false),
                       "A12-F4 FIXED: builder prose can no longer coexist LOCKED with a failing verdict")
    }

    /// Fake requirement IDs are now rejected GENERICALLY (A12_26-mReq attack): completeness law breaks.
    func testR1_M8_FakeRequirementRefusedGenerically() throws {
        let reg = try String(contentsOfFile: repoRoot + "/docs/requirements/REQUIREMENTS_REGISTRY.yaml", encoding: .utf8)
        XCTAssertFalse(reg.contains("ZZZ-999"))
        let m = try mutate(try twin(), node: "EP7-TV") { $0["requirements"] = ["ZZZ-999"] }
        var bad: [String] = []
        for n in (m["nodes"] as! [[String: Any]]) {
            for r in (n["requirements"] as? [String]) ?? [] where !reg.contains("- id: \(r)") { bad.append(r) }
        }
        XCTAssertEqual(bad, ["ZZZ-999"], "generic registry validation catches invented requirement IDs")
    }

    /// Blocker / negative-truth disappearance without a resolution-ledger record is now caught for
    /// EVERY entry — including the previously unpinned ones (A12_25 attacks: BLK-GH-CREDENTIALS,
    /// NT-PREVDWELL).
    func testR1_M9_VanishPinsCoverEverything() throws {
        let t = try twin()
        let ledger = try load("docs/control-plane/GEN8_RESOLUTION_LEDGER.yaml")
        let subjects = ((ledger["records"] as? [[String: Any]]) ?? []).compactMap { $0["subject"] as? String }.joined()
        for victim in ["BLK-GH-CREDENTIALS", "BLK-H3", "NT-PREVDWELL", "NT-THERMAL-EVIDENCE-BUILD"] {
            XCTAssertFalse(subjects.contains(victim), "precondition: \(victim) has no resolution record")
            if victim.hasPrefix("BLK-") {
                let present = ((t["blockers"] as? [[String: Any]]) ?? []).contains { ($0["id"] as! String) == victim }
                XCTAssertTrue(present, "\(victim) present — its deletion would fail CP14 (no ledger escape exists)")
            } else {
                let present = ((t["negative_truth"] as? [[String: Any]]) ?? []).contains { ($0["id"] as! String) == victim }
                XCTAssertTrue(present, "\(victim) present — its deletion would fail CP14")
            }
        }
    }

    // ── A12-F2/F3 fixed-state proofs ──

    /// 36/36 requirement dispositions; the 12 prior orphans each bound to a semantically-argued owner.
    func testR1_RequirementMapComplete() throws {
        let recs = try XCTUnwrap((try reqMap())["records"] as? [[String: Any]])
        XCTAssertEqual(recs.count, 36)
        let r1Fixed = recs.filter { ($0["r1_note"] as? String)?.contains("A12-F2") == true }
        XCTAssertEqual(Set(r1Fixed.map { $0["requirement_id"] as! String }),
                       ["ADM-002", "BND-001", "COST-001", "DVT-001", "EVD-001", "HSH-001",
                        "PRI-001", "PROT-001", "REL-001", "SCO-002", "SEC-001", "TWIN-001"])
        for rec in r1Fixed {
            XCTAssertFalse(((rec["reason"] as? String) ?? "").count < 40, "\(rec["requirement_id"]!): semantic reason required")
        }
        // DVT-001 mapping is data-rights (registry text), NOT device-trust (the mandate's guess):
        let dvt = try XCTUnwrap(recs.first { ($0["requirement_id"] as! String) == "DVT-001" })
        XCTAssertEqual(dvt["primary_owner"] as? String, "EP6-BOUNDED-LEARNING")
    }

    /// Fabricated tags: never created retroactively; typed rollback truth; correction records exist.
    func testR1_ReferenceCorrectionsHonest() throws {
        for fabricated in ["gen8-p009a-identity-foundation-locked-phase-c-ok", "gen8-p009b-expert-mesh-r1-reaudit-pass"] {
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            p.arguments = ["-C", repoRoot, "rev-parse", "--verify", "--quiet", "refs/tags/" + fabricated]
            p.standardOutput = Pipe(); p.standardError = Pipe()
            try p.run(); p.waitUntilExit()
            XCTAssertNotEqual(p.terminationStatus, 0, "fabricated tag must NEVER be created retroactively: \(fabricated)")
        }
        let twinText = try String(contentsOfFile: repoRoot + "/docs/control-plane/GEN8_PROJECT_TWIN.yaml", encoding: .utf8)
        XCTAssertFalse(twinText.contains("gen8-p009a-identity-foundation-locked-phase-c-ok"))
        XCTAssertFalse(twinText.contains("gen8-p009b-expert-mesh-r1-reaudit-pass"))
        XCTAssertTrue(twinText.contains("docs/intelligence/P009D_POLICY_INTELLIGENCE.md"))
        for doc in ["docs/control-plane/CONTROL_PLANE_R1_REFERENCE_CORRECTIONS.md",
                    "docs/control-plane/GEN8_RESOLUTION_LEDGER.yaml",
                    "docs/control-plane/GEN8_AUDIT_ALIAS_REGISTRY.yaml",
                    "docs/control-plane/GEN8_REQUIREMENT_NODE_MAP.yaml"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: repoRoot + "/" + doc), doc)
        }
    }

    // ── discipline: frozen AUDIT12 original + bounded inversions ──

    func testR1_Audit12InversionDisciplineBounded() throws {
        let frozen = try Data(contentsOf: URL(fileURLWithPath:
            repoRoot + "/docs/audit/AUDIT12_UluEvrenControlPlaneProbes_ORIGINAL_LOCKED.swift.txt"))
        let sha = SHA256.hash(data: frozen).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(sha, "4671898b38159721b6bbd29d6c77c1715623175cbea8554e747a3fc0b8a24a20")
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoRoot + "/docs/audit/AUDIT12_INVERSION_LOCK.md"))
        let active = try String(contentsOfFile:
            repoRoot + "/packages/GuardianKit/Tests/GuardianCoreTests/AUDIT12_UluEvrenControlPlaneProbes.swift", encoding: .utf8)
        let frozenSrc = String(decoding: frozen, as: UTF8.self)
        // the five declared FIXED markers present in active, absent from frozen:
        for marker in ["A12-F2 FIXED: every registry requirement has an explicit twin owner",
                       "A12-F6 FIXED: living meta.count corrected to 36",
                       "A12-F3 FIXED: zero broken machine-resolvable refs",
                       "A12-F3 FIXED: fabricated P009A tag absent from the twin",
                       "A12-F10 FIXED: no self-grade above lab truth"] {
            XCTAssertTrue(active.contains(marker), "declared inversion present: \(marker)")
            XCTAssertFalse(frozenSrc.contains(marker), "inversion absent from frozen original")
        }
        // the retired pins preserved in the frozen original, absent from active:
        for retired in ["A12-F2 pin: orphan requirement set (12/36)",
                        "A12-F6 pin: meta.count still says 35",
                        "A12-F3 pin — broken ref set",
                        "A12-F3 pin: twin still carries the nonexistent tag"] {
            XCTAssertFalse(active.contains(retired), "retired pin gone from active: \(retired)")
            XCTAssertTrue(frozenSrc.contains(retired), "retired pin preserved in frozen original")
        }
        // characterization machinery NOT inverted (historical truth of the old law's blindness):
        for keep in ["genericReadyLawViolations(ns), [], \"A12-F4 pin",
                     "A12-F12 pin: NT-PREVDWELL deletable undetected",
                     "A12-F4 pin: requirement refs never validated by builder"] {
            XCTAssertTrue(active.contains(keep), "characterization probe must stay: \(keep)")
        }
    }

    /// Future-state ladder under the TYPED engine (stronger reimplementation of A12_27's S1-S8).
    func testR1_FutureStateLadderTypedEngine() throws {
        let t = try twin()
        var passed: Set<String> = ["CP-INDEPENDENT-AUDIT", "CP-CONTROL-PLANE"]
        let s1 = ready(t, passed: passed)
        for id in ["RWC-PRE-01", "RWC-PRE-02", "RWC-PRE-03", "RWC-PRE-04", "RWC-PRE-05", "RWC-PRE-13", "EP3-CONTENT-AHEAD"] {
            XCTAssertTrue(s1.contains(id), "S1: \(id) unlocks on CP audit PASS")
        }
        for id in ["RWC-PRE-14", "RWC-CORPUS", "EP3-PRESENTATION"] { XCTAssertFalse(s1.contains(id), "S1: \(id) stays locked") }
        passed.formUnion((1...12).map { String(format: "RWC-PRE-%02d", $0) })   // 13 missing
        XCTAssertFalse(ready(t, passed: passed).contains("RWC-PRE-14"), "S2: PRE-14 needs ALL thirteen")
        passed.insert("RWC-PRE-13")
        XCTAssertTrue(ready(t, passed: passed).contains("RWC-PRE-14"), "S3")
        XCTAssertFalse(ready(t, passed: passed).contains("RWC-CORPUS"), "S4: corpus blocked until PRE-14 PASS")
        passed.insert("RWC-PRE-14")
        XCTAssertTrue(ready(t, passed: passed).contains("RWC-CORPUS"), "S5")
        passed.insert("RWC-CORPUS")
        XCTAssertFalse(ready(t, passed: passed).contains("RWC-FIT"), "S6: fit blocked without annotation")
        passed.formUnion(["RWC-ANNOTATION", "RWC-FIT"])
        XCTAssertFalse(ready(t, passed: passed).contains("EP3-PRESENTATION"), "S7: no held-out, no presentation")
        passed.insert("RWC-HELDOUT")
        XCTAssertFalse(ready(t, passed: passed).contains("EP3-PRESENTATION"), "S8: device E2E still required")
        passed.insert("RWC-DEVICE-E2E")
        XCTAssertTrue(ready(t, passed: passed).contains("EP3-PRESENTATION"), "S8b: both gates passed")
    }

    /// Production runtime untouched by R1 (allowed surface: docs/control-plane + test tooling only)
    /// and all RWC/product locks still hold in CODE.
    func testR1_ProductionUntouchedLocksHold() {
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims)
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59, "no dataset growth — no corpus/fitting work")
        XCTAssertEqual(CalibrationRunGuardV1.revision, "calibration-run-guard-v2", "entry-gate law untouched")
    }
}
