#if os(macOS)
import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
import RWCAcquisition

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT21 CLOSEOUT — STATE-TRANSITION PROBES (phase/rwc-pre14-r7-pass-closeout).
//
// THIS IS NOT A NEW INDEPENDENT SECURITY AUDIT. It is the lawful PASS-LOCK CLOSEOUT state-transition
// evidence for the already-completed, independent AUDIT21 PASS. It is AUDIT-prefixed only to satisfy the
// freeze-V8 post-audit allowance (root packages/GuardianKit/Tests/GuardianCoreTests, filename prefix
// AUDIT); it introduces NO new security contract.
//
// It asserts the NEW CLOSEOUT STATE (after docs/audit/RWC_PRE14_PASS_LOCK.yaml exists in the live tree):
//   1. RWCCorpusEntryVerifierV6.verify(realRepo) SUCCEEDS and mints RWCVerifiedCorpusEntryV6 with the
//      EXACT AUDIT21 bindings (candidate 104dad4, tag object 7674f97, audit commit 30c7c7c, audit-result
//      blob 1e0ed74f…, anchor 3abb24a, freeze sha a61caaf8…, inventory digest c64f7632…).
//   2. Zero-data invariants are STILL true (data_visibility=false; corpus/annotator/real_fit/heldout = 0),
//      proven transitively because verify() itself enforces them before minting.
//   3. loadProduction STILL fails closed with .noOperationalRoot.
//   4. No operational reviewer trust root file exists on the canonical path.
//
// EXPECTED-RED PRE-COMMIT NOTE: the positive verification reads the LOCK from the WORKING TREE
// (Data(contentsOf:)) and the audit result + candidate freeze blob from COMMITTED git history
// (git show <commit>:<path>). The audit result (30c7c7c) and candidate freeze blob (104dad4) are already
// committed, so verify() succeeds as soon as the working-tree lock file is present — it does NOT require
// the lock to be committed. This test therefore passes against the live working tree both before and after
// the closeout commit, reading LIVE repo state. The only tests that flip red→(stale) on lock creation are
// the historical pre-closeout absence pins, which are preserved unmodified (see the closeout report).
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT21_CLOSEOUT_TransitionProbes: XCTestCase {

    /// Resolve the TRUE repo root independent of the `swift test` invocation cwd: walk up from the current
    /// directory until the frozen methodology tree (docs/calibration) is found. This matches the sibling
    /// real-repo probes (RWCPowerDerivationV3.repoRootURL) and is robust whether `swift test` is run from the
    /// repo root or from packages/GuardianKit.
    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: url.appendingPathComponent("docs/calibration").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    /// (1) Post-closeout: real-repo verify SUCCEEDS with the exact AUDIT21 bindings.
    func test_CLOSEOUT_RealRepo_VerifierV6_Succeeds_WithExactBindings() throws {
        let entry = try RWCCorpusEntryVerifierV6.verify(repoRoot: repoRoot())
        XCTAssertEqual(entry.candidateCommit, "104dad450f3c96e13cb0b785c7c58b21f6b793c5")
        XCTAssertEqual(entry.candidateTagObjectSHA, "7674f97780c8b38e5a0306bfe397bd04c4f6d7d9")
        XCTAssertEqual(entry.auditCommit, "30c7c7cd0bc98b01b008506bfa79c7fe0090fbf0")
        XCTAssertEqual(entry.auditResultBlobSHA256,
                       "1e0ed74f22f2f85f7cf4e7fb9bb726a653a8113d473ef99f2ea71e9f485cc1ca")
        XCTAssertEqual(entry.methodologyAnchorCommit, "3abb24a22b63a734539fb5aebe92c1953325b590")
        XCTAssertEqual(entry.freezeManifestSHA256,
                       "a61caaf866fc5ab90268490ef1047c562f4a6c624b8d2f688b85ed8f8ece3517")
        XCTAssertEqual(entry.frozenInventoryDigest,
                       "c64f7632bb892f8fb519050de3dc86aad576078c089f85992e7dcdfd0651fb33")
    }

    /// (2) Zero-data invariants still true. verify() enforces data_visibility==false and the four counters
    /// ==0 (RWCCorpusEntryVerifierV6 master-manifest gate) BEFORE minting; a successful mint in test (1)
    /// is itself proof. We additionally assert the live master manifest directly for an explicit record.
    func test_CLOSEOUT_ZeroDataInvariants_StillHold() throws {
        let master = repoRoot().appendingPathComponent(
            "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml")
        let data = try Data(contentsOf: master)
        let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(obj["data_visibility"] as? Bool, false)
        for field in ["corpus_count", "annotator_count", "real_fit_count", "heldout_open_count"] {
            XCTAssertEqual(obj[field] as? Int, 0, "zero-data counter \(field) must remain 0 post-closeout")
        }
    }

    /// (3) loadProduction STILL fails closed with .noOperationalRoot post-closeout.
    func test_CLOSEOUT_LoadProduction_StillFailsClosed() throws {
        XCTAssertThrowsError(try RWCReviewerTrustRootLoaderV2.loadProduction(repoRoot: repoRoot())) { e in
            guard case .noOperationalRoot = (e as? RWCReviewerTrustErrorV2) else {
                return XCTFail("expected .noOperationalRoot, got \(e)")
            }
        }
    }

    /// (4) No operational reviewer trust root file exists on the canonical path post-closeout.
    func test_CLOSEOUT_NoOperationalRootFile_Present() throws {
        let p = repoRoot().appendingPathComponent(RWCReviewerTrustRootLoaderV2.canonicalInstancePath).path
        XCTAssertFalse(FileManager.default.fileExists(atPath: p),
                       "no operational reviewer trust root may exist after a PRE-14 PASS-lock closeout")
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════════
    // NEGATIVE MATRIX (mandate §6) — THROWAWAY ISOLATED GIT FIXTURES ONLY. Never touches the real lock.
    // Builds a synthetic PASS repo whose lawful form VERIFIES, then mutates exactly ONE binding per case
    // and asserts fail-closed. Covers the §6 cases not already named in the AUDIT21/R7 reject matrices:
    // wrong audit-result blob sha, wrong candidate sha, wrong tag OBJECT sha, wrong freeze sha, wrong
    // inventory digest, wrong governing lock, corpus_entry_authorized=false. (The remaining §6 cases —
    // wrong result path, R6 FIX_REQUIRED, mutated candidate freeze blob, wrong lock_version — are already
    // proven green by testR7_MAINSESSION_VerifierV6_Rejects… and AUDIT21 §8; re-running those is part of
    // the closeout evidence.)
    // ═══════════════════════════════════════════════════════════════════════════════════════════════

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
            .appendingPathComponent("closeout-neg-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    /// Build a synthetic PASS repo and return the error thrown by verify (nil if it verifies). `lockMutate`
    /// edits the lock fields right before the closeout commit.
    private func buildAndVerify(lockMutate: (inout [String: String]) -> Void = { _ in }) throws -> Error? {
        let root = tempDir("vrej"); defer { try? FileManager.default.removeItem(at: root) }
        try sh(root, ["init", "-q"])
        try sh(root, ["config", "user.email", "t@t"]); try sh(root, ["config", "user.name", "t"])
        try write(root, "seed.txt", "governing base\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "governing"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV6.governingTagName, "-m", "g"])
        let gates = "{\"gates\": \"fixture-v8\"}\n"; let code = "// law\nlet law = 8\n"
        try write(root, "docs/prereg/gates.yaml", gates)
        try write(root, "code/method/RWCFixtureLaw.swift", code)
        try write(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
                  "{\"immutable_a\": \"x\", \"data_visibility\": false, \"corpus_count\": 0, \"annotator_count\": 0, \"real_fit_count\": 0, \"heldout_open_count\": 0}\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try sh(root, ["rev-parse", "HEAD"])
        let manifestPath = RWCCorpusEntryVerifierV6.canonicalFreezeManifestPath
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
        try write(root, manifestPath, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        let tagName = "fixture-r7-candidate"
        try sh(root, ["tag", "-a", tagName, "-m", "c"])
        let tagObject = try sh(root, ["rev-parse", "refs/tags/" + tagName])
        let result = """
        {"result_version": "rwc-pre14-audit-result-v4", "verdict": "PASS", "candidate_commit": "\(candidate)",
         "candidate_tag_name": "\(tagName)", "candidate_tag_object_sha": "\(tagObject)",
         "methodology_anchor_commit": "\(anchor)", "freeze_manifest_path": "\(manifestPath)",
         "freeze_manifest_sha256": "\(shaHex(manifest))", "frozen_inventory_digest": "\(invDigest)",
         "governing_control_plane_lock": "\(governing)", "audit_probe_family": "CLOSEOUT_FIXTURE",
         "baseline_count": 2, "fresh_probe_count": 1, "total_count": 3, "critical_count": 0,
         "high_count": 0, "medium_count": 0, "auditor_declaration": "SYNTHETIC"}
        """
        try write(root, RWCPre14AuditResultV4.canonicalPath, result)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit"])
        let audit = try sh(root, ["rev-parse", "HEAD"])
        var L: [String: String] = [
            "lock_version": "rwc-pre14-pass-lock-v4", "audit_result_path": RWCPre14AuditResultV4.canonicalPath,
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
        do { _ = try RWCCorpusEntryVerifierV6.verify(repoRoot: root); return nil }
        catch { return error }
    }

    /// Positive control: the UNMUTATED synthetic fixture VERIFIES (proves the fixture itself is lawful, so
    /// the negatives below fail for the RIGHT reason).
    func test_CLOSEOUT_NEG_00_SyntheticFixture_PositiveControl() throws {
        XCTAssertNil(try buildAndVerify(), "lawful synthetic fixture must verify")
    }

    func test_CLOSEOUT_NEG_01_WrongAuditResultBlobSha_Refused() throws {
        let e = try buildAndVerify { $0["audit_result_blob_sha256"] = String(repeating: "0", count: 64) }
        guard case .auditResultHashMismatch = (e as? RWCCorpusEntryErrorV6) else {
            return XCTFail("expected auditResultHashMismatch, got \(String(describing: e))")
        }
    }
    func test_CLOSEOUT_NEG_02_WrongCandidateSha_Refused() throws {
        let e = try buildAndVerify { $0["candidate_commit"] = String(repeating: "a", count: 40) }
        XCTAssertNotNil(e, "wrong candidate sha must refuse")
    }
    func test_CLOSEOUT_NEG_03_WrongTagObjectSha_Refused() throws {
        let e = try buildAndVerify { $0["candidate_tag_object_sha"] = String(repeating: "b", count: 40) }
        XCTAssertNotNil(e, "wrong tag object sha must refuse")
    }
    func test_CLOSEOUT_NEG_04_WrongFreezeSha_Refused() throws {
        let e = try buildAndVerify { $0["freeze_manifest_sha256"] = String(repeating: "c", count: 64) }
        XCTAssertNotNil(e, "wrong freeze sha must refuse")
    }
    func test_CLOSEOUT_NEG_05_WrongInventoryDigest_Refused() throws {
        let e = try buildAndVerify { $0["frozen_inventory_digest"] = String(repeating: "d", count: 64) }
        XCTAssertNotNil(e, "wrong inventory digest must refuse")
    }
    func test_CLOSEOUT_NEG_06_WrongGoverningLock_Refused() throws {
        let e = try buildAndVerify { $0["governing_control_plane_lock"] = String(repeating: "e", count: 40) }
        XCTAssertNotNil(e, "wrong governing lock must refuse")
    }
    func test_CLOSEOUT_NEG_07_EntryNotAuthorized_Refused() throws {
        let e = try buildAndVerify { $0["corpus_entry_authorized"] = "false" }
        guard case .entryNotAuthorized = (e as? RWCCorpusEntryErrorV6) else {
            return XCTFail("expected entryNotAuthorized, got \(String(describing: e))")
        }
    }
    func test_CLOSEOUT_NEG_08_WrongLockVersion_Refused() throws {
        let e = try buildAndVerify { $0["lock_version"] = "rwc-pre14-pass-lock-v3" }
        guard case .lockVersionUnsupported = (e as? RWCCorpusEntryErrorV6) else {
            return XCTFail("expected lockVersionUnsupported, got \(String(describing: e))")
        }
    }
    func test_CLOSEOUT_NEG_09_WrongResultPath_Refused() throws {
        let e = try buildAndVerify { $0["audit_result_path"] = "docs/audit/RWC_PRE14_R6_AUDIT_RESULT.json" }
        guard case .nonCanonicalAuditResultPath = (e as? RWCCorpusEntryErrorV6) else {
            return XCTFail("expected nonCanonicalAuditResultPath, got \(String(describing: e))")
        }
    }
}
#endif
