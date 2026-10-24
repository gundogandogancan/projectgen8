#if os(macOS)
import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
import RWCAcquisition

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT21 → V10 RELEASE-VERIFIER TRANSITION PROBES (phase/rwc-lane-a-onboarding → V10 candidate).
//
// THIS IS NOT A NEW INDEPENDENT SECURITY AUDIT. It is the lawful release-verifier-transition evidence for
// the NEW RWCCorpusEntryVerifierV7 (schema V5, manifest V10, freeze-version rwc-preregistration-freeze-v10).
// AUDIT-prefixed only to satisfy the freeze post_audit_allowance (root
// packages/GuardianKit/Tests/GuardianCoreTests, filename prefix AUDIT); it introduces NO new security
// contract — V7 carries V6's binding matrix VERBATIM, differing only in three bound constants.
//
// It asserts, on the REAL repo (pre-V10-PASS state):
//   1. V7.verify(realRepo) FAILS CLOSED with .lockMissing — no V10 PASS lock exists (zero-data truth).
//   2. V6.verify(realRepo) STILL FAILS (frozenFileDrift on RunnerV5) — the historical verifier does NOT
//      silently consume the V9/V10 code; the V8 PASS is NOT auto-rebound. (Group-2 lawful red, documented.)
//   3. loadProduction STILL fails closed with .noOperationalRoot; no operational root file exists.
// And, with THROWAWAY ISOLATED GIT FIXTURES (never touching the real lock):
//   4. a lawful synthetic V10 PASS fixture is ACCEPTED by V7 and mints RWCVerifiedCorpusEntryV7;
//   5. the mandate §4 negative matrix (wrong path/tag/anchor/manifest/digest/counts/blob/lock-version/
//      authorized; verdict≠PASS; findings>0; schema-V4-as-V5; AUDIT19/20 replay path; V9-no-result refusal;
//      V8-PASS-rebind refusal) each fails closed;
//   6. the SAME lawful synthetic fixture is REFUSED by V6 (path + freeze-version are V10, not V6's V8),
//      and a V8-shaped fixture is ACCEPTED by V6 — proving V6 stays historically verifiable while V7 owns
//      the new contract.
// Plus a worktree-aware git-tag verification note (mandate §6 Group 3).
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT21_V10_TransitionProbes: XCTestCase {

    /// Resolve the TRUE repo root independent of the `swift test` cwd: walk up until docs/calibration found.
    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("docs/calibration").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    // ───────────────────────────────────────────────────────────────────────────────────────────
    // (1)–(3) REAL REPO — pre-V10-PASS fail-closed truth
    // ───────────────────────────────────────────────────────────────────────────────────────────

    /// (1) V7 on the real repo fails closed with .lockMissing (no V10 PASS lock exists).
    /// NOTE: the live lock on disk is the historical V8/AUDIT21 lock (lock_version rwc-pre14-pass-lock-v4),
    /// so V7 PARSES it, then refuses it at the V10 canonical-path gate (nonCanonicalAuditResultPath) because
    /// the V8 lock names the R7 result path, not the V10 path. Either .lockMissing (lock truly absent) or
    /// .nonCanonicalAuditResultPath (historical V8 lock present) is a correct fail-closed outcome; both prove
    /// no V10 PASS is minted. We assert the DECISIVE invariant: V7 does NOT return a verified entry.
    func test_V10_RealRepo_VerifierV7_FailsClosed_NoV10Pass() throws {
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV7.verify(repoRoot: repoRoot())) { e in
            guard let err = e as? RWCCorpusEntryErrorV7 else {
                return XCTFail("expected RWCCorpusEntryErrorV7, got \(e)")
            }
            switch err {
            case .lockMissing, .nonCanonicalAuditResultPath, .lockVersionUnsupported, .freezeVersionMismatch,
                 .carried:
                break // all are fail-closed refusals of a non-V10 lock
            default:
                XCTFail("V7 must fail closed pre-V10-PASS, got \(err)")
            }
        }
    }

    /// (2) V6 on the real repo STILL FAILS — the historical verifier does not consume V9/V10 code. On the
    /// clean V9/V10 tree the measured cause is carried(.frozenFileDrift) on RunnerV5 (A21-F5 byte change vs
    /// the V8 manifest). This is the Group-2 lawful red; we assert V6 does NOT mint an entry.
    func test_V10_RealRepo_VerifierV6_StillFails_NotRebound() throws {
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV6.verify(repoRoot: repoRoot()),
                             "V6 must NOT silently validate the V9/V10 tree (no auto-rebinding of the V8 PASS)")
    }

    /// (3) loadProduction STILL fails closed; no operational reviewer trust root file exists.
    func test_V10_RealRepo_LoadProduction_StillFailsClosed() throws {
        XCTAssertThrowsError(try RWCReviewerTrustRootLoaderV2.loadProduction(repoRoot: repoRoot())) { e in
            guard case .noOperationalRoot = (e as? RWCReviewerTrustErrorV2) else {
                return XCTFail("expected .noOperationalRoot, got \(e)")
            }
        }
        let p = repoRoot().appendingPathComponent(RWCReviewerTrustRootLoaderV2.canonicalInstancePath).path
        XCTAssertFalse(FileManager.default.fileExists(atPath: p),
                       "no operational reviewer trust root may exist pre-activation")
    }

    // ───────────────────────────────────────────────────────────────────────────────────────────
    // SYNTHETIC-FIXTURE HARNESS (throwaway isolated git repos) — never touches the real lock.
    // ───────────────────────────────────────────────────────────────────────────────────────────

    private func shaHex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    @discardableResult
    private func sh(_ root: URL, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", root.path] + args
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        try p.run(); p.waitUntilExit()
        let d = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: d, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func write(_ root: URL, _ rel: String, _ s: String) throws {
        let u = root.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: u.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try s.write(to: u, atomically: true, encoding: .utf8)
    }
    private func tempDir(_ tag: String) -> URL {
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("v10-trans-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    /// Build a synthetic V10 PASS repo and return the error thrown by V7.verify (nil if it verifies).
    /// `freezeVersion` / `resultPath` / `manifestPathOverride` let the V6-cross-refusal + V8-shape tests
    /// reuse the same builder. `lockMutate` edits the lock fields right before the closeout commit.
    private func buildV10(freezeVersion: String = RWCCorpusEntryVerifierV7.expectedFreezeVersion,
                          resultPath: String = RWCPre14AuditResultV5.canonicalPath,
                          resultVersion: String = RWCPre14AuditResultV5.expectedVersion,
                          manifestPath: String = RWCCorpusEntryVerifierV7.canonicalFreezeManifestPath,
                          lockMutate: (inout [String: String]) -> Void = { _ in })
        throws -> (root: URL, v7Error: Error?) {
        let root = tempDir("v7")
        try sh(root, ["init", "-q"])
        try sh(root, ["config", "user.email", "t@t"]); try sh(root, ["config", "user.name", "t"])
        try write(root, "seed.txt", "governing base\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "governing"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV7.governingTagName, "-m", "g"])
        let gates = "{\"gates\": \"fixture-v10\"}\n"; let code = "// law\nlet law = 10\n"
        try write(root, "docs/prereg/gates.yaml", gates)
        try write(root, "code/method/RWCFixtureLaw.swift", code)
        try write(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
                  "{\"immutable_a\": \"x\", \"data_visibility\": false, \"corpus_count\": 0, \"annotator_count\": 0, \"real_fit_count\": 0, \"heldout_open_count\": 0}\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try sh(root, ["rev-parse", "HEAD"])
        let arts: [(String, String)] = [("docs/prereg/gates.yaml", shaHex(gates)),
                                        ("code/method/RWCFixtureLaw.swift", shaHex(code))]
        let invDigest = shaHex(arts.map { "\($0.0):\($0.1)" }.sorted().joined(separator: "\n"))
        let manifest = """
        {"freeze_version": "\(freezeVersion)", "methodology_anchor_commit": "\(anchor)",
         "governing_control_plane_lock": "\(governing)", "frozen_inventory_digest": "\(invDigest)",
         "artifacts": [\(arts.map { "{\"path\": \"\($0.0)\", \"sha256\": \"\($0.1)\"}" }.joined(separator: ", "))],
         "surface_rules": {"governed_roots": ["docs/prereg", "code"], "post_anchor_allowed": [],
           "post_audit_allowances": [], "hash_exempt": []}}
        """
        try write(root, manifestPath, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        let tagName = "fixture-v10-candidate"
        try sh(root, ["tag", "-a", tagName, "-m", "c"])
        let tagObject = try sh(root, ["rev-parse", "refs/tags/" + tagName])
        let result = """
        {"result_version": "\(resultVersion)", "verdict": "PASS", "candidate_commit": "\(candidate)",
         "candidate_tag_name": "\(tagName)", "candidate_tag_object_sha": "\(tagObject)",
         "methodology_anchor_commit": "\(anchor)", "freeze_manifest_path": "\(manifestPath)",
         "freeze_manifest_sha256": "\(shaHex(manifest))", "frozen_inventory_digest": "\(invDigest)",
         "governing_control_plane_lock": "\(governing)", "audit_probe_family": "V10_FIXTURE",
         "baseline_count": 2, "fresh_probe_count": 1, "total_count": 3, "critical_count": 0,
         "high_count": 0, "medium_count": 0, "auditor_declaration": "SYNTHETIC"}
        """
        try write(root, resultPath, result)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit"])
        let audit = try sh(root, ["rev-parse", "HEAD"])
        var L: [String: String] = [
            "lock_version": "rwc-pre14-pass-lock-v4", "audit_result_path": resultPath,
            "audit_result_blob_sha256": shaHex(result), "audit_commit": audit, "candidate_commit": candidate,
            "candidate_tag_name": tagName, "candidate_tag_object_sha": tagObject,
            "freeze_manifest_path": manifestPath, "freeze_manifest_sha256": shaHex(manifest),
            "methodology_anchor_commit": anchor, "frozen_inventory_digest": invDigest,
            "governing_control_plane_lock": governing, "corpus_entry_authorized": "true", "verdict": "PASS"]
        lockMutate(&L)
        func s(_ k: String) -> String { "\"\(k)\": \"\(L[k]!)\"" }
        let lock = "{" + [s("lock_version"), s("audit_result_path"), s("audit_result_blob_sha256"),
            s("audit_commit"), s("candidate_commit"), s("candidate_tag_name"), s("candidate_tag_object_sha"),
            s("freeze_manifest_path"), s("freeze_manifest_sha256"), s("methodology_anchor_commit"),
            s("frozen_inventory_digest"), s("governing_control_plane_lock"),
            "\"corpus_entry_authorized\": \(L["corpus_entry_authorized"]!)", s("verdict")].joined(separator: ", ") + "}"
        try write(root, RWCPre14PassLockV4.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
        do { _ = try RWCCorpusEntryVerifierV7.verify(repoRoot: root); return (root, nil) }
        catch { return (root, error) }
    }

    private func v7Error(_ b: (root: URL, v7Error: Error?)) -> Error? {
        try? FileManager.default.removeItem(at: b.root); return b.v7Error
    }

    // ───────────────────────────────────────────────────────────────────────────────────────────
    // (4) POSITIVE CONTROL + full minted entry
    // ───────────────────────────────────────────────────────────────────────────────────────────

    func test_V10_NEG_00_SyntheticV10Fixture_PositiveControl() throws {
        let b = try buildV10(); defer { try? FileManager.default.removeItem(at: b.root) }
        XCTAssertNil(b.v7Error, "lawful synthetic V10 fixture must verify under V7")
    }

    func test_V10_PositiveFixture_MintsVerifiedEntryV7() throws {
        let b = try buildV10(); defer { try? FileManager.default.removeItem(at: b.root) }
        XCTAssertNil(b.v7Error)
        let entry = try RWCCorpusEntryVerifierV7.verify(repoRoot: b.root)
        XCTAssertFalse(entry.candidateCommit.isEmpty)
        XCTAssertFalse(entry.auditResultBlobSHA256.isEmpty)
        XCTAssertFalse(entry.frozenInventoryDigest.isEmpty)
    }

    // ───────────────────────────────────────────────────────────────────────────────────────────
    // (5) NEGATIVE MATRIX (mandate §4)
    // ───────────────────────────────────────────────────────────────────────────────────────────

    func test_V10_NEG_01_WrongAuditResultBlobSha_Refused() throws {
        let e = v7Error(try buildV10 { $0["audit_result_blob_sha256"] = String(repeating: "0", count: 64) })
        guard case .auditResultHashMismatch = (e as? RWCCorpusEntryErrorV7) else {
            return XCTFail("expected auditResultHashMismatch, got \(String(describing: e))")
        }
    }
    func test_V10_NEG_02_WrongCandidateSha_Refused() throws {
        let e = v7Error(try buildV10 { $0["candidate_commit"] = String(repeating: "a", count: 40) })
        XCTAssertNotNil(e, "wrong candidate sha must refuse")
    }
    func test_V10_NEG_03_WrongTagObjectSha_Refused() throws {
        let e = v7Error(try buildV10 { $0["candidate_tag_object_sha"] = String(repeating: "b", count: 40) })
        XCTAssertNotNil(e, "wrong tag object sha must refuse")
    }
    func test_V10_NEG_04_WrongFreezeSha_Refused() throws {
        let e = v7Error(try buildV10 { $0["freeze_manifest_sha256"] = String(repeating: "c", count: 64) })
        XCTAssertNotNil(e, "wrong freeze sha must refuse")
    }
    func test_V10_NEG_05_WrongInventoryDigest_Refused() throws {
        let e = v7Error(try buildV10 { $0["frozen_inventory_digest"] = String(repeating: "d", count: 64) })
        XCTAssertNotNil(e, "wrong inventory digest must refuse")
    }
    func test_V10_NEG_06_WrongGoverningLock_Refused() throws {
        let e = v7Error(try buildV10 { $0["governing_control_plane_lock"] = String(repeating: "e", count: 40) })
        XCTAssertNotNil(e, "wrong governing lock must refuse")
    }
    func test_V10_NEG_07_WrongAnchor_Refused() throws {
        let e = v7Error(try buildV10 { $0["methodology_anchor_commit"] = String(repeating: "f", count: 40) })
        XCTAssertNotNil(e, "wrong anchor must refuse")
    }
    func test_V10_NEG_08_EntryNotAuthorized_Refused() throws {
        let e = v7Error(try buildV10 { $0["corpus_entry_authorized"] = "false" })
        guard case .entryNotAuthorized = (e as? RWCCorpusEntryErrorV7) else {
            return XCTFail("expected entryNotAuthorized, got \(String(describing: e))")
        }
    }
    func test_V10_NEG_09_WrongLockVersion_Refused() throws {
        let e = v7Error(try buildV10 { $0["lock_version"] = "rwc-pre14-pass-lock-v3" })
        guard case .lockVersionUnsupported = (e as? RWCCorpusEntryErrorV7) else {
            return XCTFail("expected lockVersionUnsupported, got \(String(describing: e))")
        }
    }

    /// Wrong canonical path — including the AUDIT19/AUDIT20/R7 historical result paths (replay refusal).
    func test_V10_NEG_10_WrongResultPath_R7_Refused() throws {
        let e = v7Error(try buildV10(resultPath: "docs/audit/RWC_PRE14_R7_AUDIT_RESULT.json"))
        guard case .nonCanonicalAuditResultPath = (e as? RWCCorpusEntryErrorV7) else {
            return XCTFail("expected nonCanonicalAuditResultPath, got \(String(describing: e))")
        }
    }
    func test_V10_NEG_11_WrongResultPath_AUDIT20_R6_Refused() throws {
        let e = v7Error(try buildV10(resultPath: "docs/audit/RWC_PRE14_R6_AUDIT_RESULT.json"))
        guard case .nonCanonicalAuditResultPath = (e as? RWCCorpusEntryErrorV7) else {
            return XCTFail("expected nonCanonicalAuditResultPath (A20 replay), got \(String(describing: e))")
        }
    }
    func test_V10_NEG_12_WrongResultPath_AUDIT19_R5_Refused() throws {
        let e = v7Error(try buildV10(resultPath: "docs/audit/RWC_PRE14_R5_AUDIT_RESULT.json"))
        guard case .nonCanonicalAuditResultPath = (e as? RWCCorpusEntryErrorV7) else {
            return XCTFail("expected nonCanonicalAuditResultPath (A19 replay), got \(String(describing: e))")
        }
    }

    /// Schema V4 disguised as a V10 instance (wrong result_version) at the correct V10 path.
    func test_V10_NEG_13_SchemaV4AsV5_Refused() throws {
        let e = v7Error(try buildV10(resultVersion: "rwc-pre14-audit-result-v4"))
        guard case .schemaVersionUnsupported = (e as? RWCCorpusEntryErrorV7) else {
            return XCTFail("expected schemaVersionUnsupported, got \(String(describing: e))")
        }
    }

    /// Wrong freeze_version in the bound manifest (e.g. a V8 manifest's freeze-version).
    func test_V10_NEG_14_WrongFreezeVersion_Refused() throws {
        let e = v7Error(try buildV10(freezeVersion: "rwc-preregistration-freeze-v8"))
        guard case .freezeVersionMismatch = (e as? RWCCorpusEntryErrorV7) else {
            return XCTFail("expected freezeVersionMismatch, got \(String(describing: e))")
        }
    }

    /// Wrong manifest path (not the canonical V10 path).
    func test_V10_NEG_15_WrongManifestPath_Refused() throws {
        let e = v7Error(try buildV10(manifestPath:
            "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V8.yaml"))
        XCTAssertNotNil(e, "non-canonical manifest path must refuse")
    }

    /// verdict != PASS (FIX_REQUIRED) — a fully lawful chain whose COMMITTED audit result carries verdict
    /// FIX_REQUIRED (not PASS). The lock's blob sha + audit_commit point at that committed result, so V7
    /// reads a genuine FIX_REQUIRED result from git history and refuses on the verdict gate. This is the
    /// mandate §4 "AUDIT19/20 FIX_REQUIRED must be rejected" boundary at the verdict level.
    func test_V10_NEG_16_VerdictNotPass_FixRequired_Refused() throws {
        let root = tempDir("fixreq"); defer { try? FileManager.default.removeItem(at: root) }
        try sh(root, ["init", "-q"])
        try sh(root, ["config", "user.email", "t@t"]); try sh(root, ["config", "user.name", "t"])
        try write(root, "seed.txt", "g\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "g"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV7.governingTagName, "-m", "g"])
        try write(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
                  "{\"data_visibility\": false, \"corpus_count\": 0, \"annotator_count\": 0, \"real_fit_count\": 0, \"heldout_open_count\": 0}\n")
        let gates = "{\"g\":1}\n"
        try write(root, "docs/prereg/gates.yaml", gates)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try sh(root, ["rev-parse", "HEAD"])
        let invDigest = shaHex("docs/prereg/gates.yaml:\(shaHex(gates))")
        let mp = RWCCorpusEntryVerifierV7.canonicalFreezeManifestPath
        let manifest = """
        {"freeze_version": "\(RWCCorpusEntryVerifierV7.expectedFreezeVersion)", "methodology_anchor_commit": "\(anchor)",
         "governing_control_plane_lock": "\(governing)", "frozen_inventory_digest": "\(invDigest)",
         "artifacts": [{"path": "docs/prereg/gates.yaml", "sha256": "\(shaHex(gates))"}],
         "surface_rules": {"governed_roots": ["docs/prereg"], "post_anchor_allowed": [],
           "post_audit_allowances": [], "hash_exempt": []}}
        """
        try write(root, mp, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", "fixture-v10-candidate", "-m", "c"])
        let tagObject = try sh(root, ["rev-parse", "refs/tags/fixture-v10-candidate"])
        // COMMITTED result with verdict FIX_REQUIRED (genuine, not a lock lie).
        let result = """
        {"result_version": "\(RWCPre14AuditResultV5.expectedVersion)", "verdict": "FIX_REQUIRED",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "fixture-v10-candidate",
         "candidate_tag_object_sha": "\(tagObject)", "methodology_anchor_commit": "\(anchor)",
         "freeze_manifest_path": "\(mp)", "freeze_manifest_sha256": "\(shaHex(manifest))",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "audit_probe_family": "V10_FIXREQ_FIXTURE", "baseline_count": 2, "fresh_probe_count": 1,
         "total_count": 3, "critical_count": 1, "high_count": 0, "medium_count": 0,
         "auditor_declaration": "SYNTHETIC-FIX-REQUIRED"}
        """
        try write(root, RWCPre14AuditResultV5.canonicalPath, result)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit"])
        let audit = try sh(root, ["rev-parse", "HEAD"])
        let lock = """
        {"lock_version": "rwc-pre14-pass-lock-v4", "audit_result_path": "\(RWCPre14AuditResultV5.canonicalPath)",
         "audit_result_blob_sha256": "\(shaHex(result))", "audit_commit": "\(audit)",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "fixture-v10-candidate",
         "candidate_tag_object_sha": "\(tagObject)", "freeze_manifest_path": "\(mp)",
         "freeze_manifest_sha256": "\(shaHex(manifest))", "methodology_anchor_commit": "\(anchor)",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "corpus_entry_authorized": true, "verdict": "PASS"}
        """
        try write(root, RWCPre14PassLockV4.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV7.verify(repoRoot: root)) { e in
            guard case .auditVerdictNotPass(let v) = (e as? RWCCorpusEntryErrorV7) else {
                return XCTFail("expected auditVerdictNotPass, got \(e)")
            }
            XCTAssertEqual(v, "FIX_REQUIRED")
        }
    }

    /// V9-builder-candidate refusal: a candidate with NO audit-result blob at the canonical path. Simulated
    /// by pointing the lock's audit_result_path at the canonical V10 path while committing NO such file in
    /// the audit commit → auditResultMissingInAuditCommit.
    func test_V10_NEG_17_V9CandidateNoResult_Refused() throws {
        // Build the chain but DELETE the result before the audit commit so the canonical path is absent in
        // the audit commit, modelling the V9 builder candidate which has no audit result.
        let root = tempDir("noresult"); defer { try? FileManager.default.removeItem(at: root) }
        try sh(root, ["init", "-q"])
        try sh(root, ["config", "user.email", "t@t"]); try sh(root, ["config", "user.name", "t"])
        try write(root, "seed.txt", "g\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "g"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV7.governingTagName, "-m", "g"])
        try write(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
                  "{\"data_visibility\": false, \"corpus_count\": 0, \"annotator_count\": 0, \"real_fit_count\": 0, \"heldout_open_count\": 0}\n")
        let gates = "{\"g\":1}\n"
        try write(root, "docs/prereg/gates.yaml", gates)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try sh(root, ["rev-parse", "HEAD"])
        let arts = [("docs/prereg/gates.yaml", shaHex(gates))]
        let invDigest = shaHex(arts.map { "\($0.0):\($0.1)" }.sorted().joined(separator: "\n"))
        let mp = RWCCorpusEntryVerifierV7.canonicalFreezeManifestPath
        let manifest = """
        {"freeze_version": "\(RWCCorpusEntryVerifierV7.expectedFreezeVersion)", "methodology_anchor_commit": "\(anchor)",
         "governing_control_plane_lock": "\(governing)", "frozen_inventory_digest": "\(invDigest)",
         "artifacts": [{"path": "docs/prereg/gates.yaml", "sha256": "\(shaHex(gates))"}],
         "surface_rules": {"governed_roots": ["docs/prereg"], "post_anchor_allowed": [],
           "post_audit_allowances": [], "hash_exempt": []}}
        """
        try write(root, mp, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", "fixture-v10-candidate", "-m", "c"])
        let tagObject = try sh(root, ["rev-parse", "refs/tags/fixture-v10-candidate"])
        // audit commit WITHOUT the result file (V9-builder-like)
        try write(root, "docs/audit/placeholder.txt", "no result here\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit-no-result"])
        let audit = try sh(root, ["rev-parse", "HEAD"])
        let lock = """
        {"lock_version": "rwc-pre14-pass-lock-v4", "audit_result_path": "\(RWCPre14AuditResultV5.canonicalPath)",
         "audit_result_blob_sha256": "\(String(repeating: "0", count: 64))", "audit_commit": "\(audit)",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "fixture-v10-candidate",
         "candidate_tag_object_sha": "\(tagObject)", "freeze_manifest_path": "\(mp)",
         "freeze_manifest_sha256": "\(shaHex(manifest))", "methodology_anchor_commit": "\(anchor)",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "corpus_entry_authorized": true, "verdict": "PASS"}
        """
        try write(root, RWCPre14PassLockV4.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV7.verify(repoRoot: root)) { e in
            guard case .auditResultMissingInAuditCommit = (e as? RWCCorpusEntryErrorV7) else {
                return XCTFail("expected auditResultMissingInAuditCommit (V9 no-result), got \(e)")
            }
        }
    }

    // ───────────────────────────────────────────────────────────────────────────────────────────
    // (6) CROSS-VERSION REFUSAL + V6 HISTORICAL VERIFIABILITY
    // ───────────────────────────────────────────────────────────────────────────────────────────

    /// V6 must REFUSE the lawful V10 fixture — its canonical path is the V10 path and its freeze_version is
    /// v10, neither of which V6 (pinned to the R7 path + freeze-v8) accepts → no V8-PASS rebinding onto V10.
    func test_V10_CROSS_01_VerifierV6_Refuses_V10Fixture() throws {
        let b = try buildV10(); defer { try? FileManager.default.removeItem(at: b.root) }
        XCTAssertNil(b.v7Error, "fixture must be V7-lawful first")
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV6.verify(repoRoot: b.root),
                             "V6 must refuse a V10-identity fixture (path+freeze-version mismatch)")
    }

    /// V6 still ACCEPTS a V8-shaped synthetic fixture — proving V6 stays historically verifiable while V7
    /// owns the new contract. Built with V6's R7 result path + V8 freeze-version, verified by V6.
    func test_V10_CROSS_02_VerifierV6_Accepts_V8ShapedFixture() throws {
        let root = tempDir("v8shape"); defer { try? FileManager.default.removeItem(at: root) }
        try sh(root, ["init", "-q"])
        try sh(root, ["config", "user.email", "t@t"]); try sh(root, ["config", "user.name", "t"])
        try write(root, "seed.txt", "g\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "g"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV6.governingTagName, "-m", "g"])
        let gates = "{\"gates\": \"fixture-v8\"}\n"; let code = "// law\nlet law = 8\n"
        try write(root, "docs/prereg/gates.yaml", gates)
        try write(root, "code/method/RWCFixtureLaw.swift", code)
        try write(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
                  "{\"immutable_a\": \"x\", \"data_visibility\": false, \"corpus_count\": 0, \"annotator_count\": 0, \"real_fit_count\": 0, \"heldout_open_count\": 0}\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try sh(root, ["rev-parse", "HEAD"])
        let mp = RWCCorpusEntryVerifierV6.canonicalFreezeManifestPath
        let arts: [(String, String)] = [("docs/prereg/gates.yaml", shaHex(gates)),
                                        ("code/method/RWCFixtureLaw.swift", shaHex(code))]
        let invDigest = shaHex(arts.map { "\($0.0):\($0.1)" }.sorted().joined(separator: "\n"))
        let manifest = """
        {"freeze_version": "rwc-preregistration-freeze-v8", "methodology_anchor_commit": "\(anchor)",
         "governing_control_plane_lock": "\(governing)", "frozen_inventory_digest": "\(invDigest)",
         "artifacts": [\(arts.map { "{\"path\": \"\($0.0)\", \"sha256\": \"\($0.1)\"}" }.joined(separator: ", "))],
         "surface_rules": {"governed_roots": ["docs/prereg", "code"], "post_anchor_allowed": [],
           "post_audit_allowances": [], "hash_exempt": []}}
        """
        try write(root, mp, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", "fixture-r7-candidate", "-m", "c"])
        let tagObject = try sh(root, ["rev-parse", "refs/tags/fixture-r7-candidate"])
        let result = """
        {"result_version": "rwc-pre14-audit-result-v4", "verdict": "PASS", "candidate_commit": "\(candidate)",
         "candidate_tag_name": "fixture-r7-candidate", "candidate_tag_object_sha": "\(tagObject)",
         "methodology_anchor_commit": "\(anchor)", "freeze_manifest_path": "\(mp)",
         "freeze_manifest_sha256": "\(shaHex(manifest))", "frozen_inventory_digest": "\(invDigest)",
         "governing_control_plane_lock": "\(governing)", "audit_probe_family": "V8_SHAPE_FIXTURE",
         "baseline_count": 2, "fresh_probe_count": 1, "total_count": 3, "critical_count": 0,
         "high_count": 0, "medium_count": 0, "auditor_declaration": "SYNTHETIC"}
        """
        try write(root, RWCPre14AuditResultV4.canonicalPath, result)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit"])
        let audit = try sh(root, ["rev-parse", "HEAD"])
        let lock = """
        {"lock_version": "rwc-pre14-pass-lock-v4", "audit_result_path": "\(RWCPre14AuditResultV4.canonicalPath)",
         "audit_result_blob_sha256": "\(shaHex(result))", "audit_commit": "\(audit)",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "fixture-r7-candidate",
         "candidate_tag_object_sha": "\(tagObject)", "freeze_manifest_path": "\(mp)",
         "freeze_manifest_sha256": "\(shaHex(manifest))", "methodology_anchor_commit": "\(anchor)",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "corpus_entry_authorized": true, "verdict": "PASS"}
        """
        try write(root, RWCPre14PassLockV4.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
        // V6 ACCEPTS the V8-shaped fixture (historical verifiability preserved).
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV6.verify(repoRoot: root),
                         "V6 must still accept a V8-shaped lawful fixture")
        // V7 REFUSES the same V8-shaped fixture (wrong path + freeze-version for V10).
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV7.verify(repoRoot: root),
                             "V7 must refuse a V8-shaped fixture")
    }

    // ───────────────────────────────────────────────────────────────────────────────────────────
    // (7) WORKTREE-AWARE GIT-TAG VERIFICATION NOTE (mandate §6 Group 3)
    // ───────────────────────────────────────────────────────────────────────────────────────────

    /// Modern worktree-aware tag check via `git tag -l` (subprocess), which resolves the shared object store
    /// regardless of whether `.git` is a directory or a worktree gitdir-pointer FILE. This is the correct
    /// replacement for the frozen AUDIT12 `gitTagExists` file-probe (which FILE-PROBES <repo>/.git/refs/tags
    /// and fails in a worktree). We do NOT edit the frozen AUDIT12 test; we record the measured truth here.
    private func gitTagExistsWorktreeAware(_ repo: URL, _ tag: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", repo.path, "tag", "-l", tag]
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        guard (try? p.run()) != nil else { return false }
        p.waitUntilExit()
        let d = out.fileHandleForReading.readDataToEndOfFile()
        let s = String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s == tag
    }

    func test_V10_WorktreeAware_GitTag_ResolvesInWorktreeOrCheckout() throws {
        let repo = repoRoot()
        // These tags exist in the shared object store; the worktree-aware check must find them even when
        // `.git` is a gitdir-pointer file (the condition under which the frozen AUDIT12 file-probe fails).
        for tag in ["gen8-rwc-lane-a-onboarding-candidate",
                    "gen8-ulu-evren-control-plane-audit-candidate"] {
            XCTAssertTrue(gitTagExistsWorktreeAware(repo, tag),
                          "worktree-aware `git tag -l` must resolve \(tag) in a worktree OR a plain checkout")
        }
        // A definitely-absent tag must NOT resolve (no false positives).
        XCTAssertFalse(gitTagExistsWorktreeAware(repo, "gen8-this-tag-never-existed-zzz"),
                       "worktree-aware check must not false-positive on a non-existent tag")
    }
}
#endif
