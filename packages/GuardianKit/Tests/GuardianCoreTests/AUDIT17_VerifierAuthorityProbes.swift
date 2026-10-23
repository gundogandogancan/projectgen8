import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
#if os(macOS)
import RWCAcquisition
#endif

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT17_RWC_PRE14_R3_REAUDIT — part 2 of 3: PASS authority / freeze surface adversarial battery
// on SYNTHETIC git fixtures (the real tracked tree is never modified). Probes pinning defective
// behavior are marked "AUDIT17 FINDING A17-Fn: pins defective behavior".
// ═══════════════════════════════════════════════════════════════════════════════════════════════

#if os(macOS)

struct A17Fixture {
    let root: URL
    let governing: String
    let anchor: String
    let candidate: String
    let audit: String
    let tagObject: String
    let manifestJSON: String
    let resultJSON: String
}

enum A17Fx {
    static let tagName = "a17-candidate-tag"
    static let masterPath = "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml"

    /// Independent fixture (layout distinct from builder fixtures): governed roots norm/src/probes,
    /// hashed root-level Package.swift, nested governed subdirectory, canonical manifest path.
    static func make(verdict: String = "PASS", critical: Int = 0, high: Int = 0, medium: Int = 0,
                     baseline: Int = 982, fresh: Int = 39, total: Int = 1021,
                     freezeVersion: String = "rwc-preregistration-freeze-v4",
                     resultPathInLock: String? = nil,
                     commitResultInAuditCommit: Bool = true,
                     extraCandidateFile: (String, String)? = nil) throws -> A17Fixture {
        let root = A17.tempDir("vfx")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try A17.git(root, ["init", "-q"])
        try A17.write(root, "base/seed.md", "a17 governing base\n")
        try A17.git(root, ["add", "-A"])
        try A17.git(root, ["commit", "-q", "-m", "governing"])
        let governing = try A17.git(root, ["rev-parse", "HEAD"]).1
        try A17.git(root, ["tag", "-a", RWCCorpusEntryVerifierV3.governingTagName, "-m", "gov"])
        // anchor: frozen content + master manifest
        let norm = "{\"a17\": \"norm-law\"}\n"
        let src = "// A17 core engine\nlet a17core = 1\n"
        let deep = "// nested governed file\nlet a17deep = 2\n"
        let probe = "// probe base\nlet a17probe = 3\n"
        let pkg = "// swift-tools-version:6.0 (a17 fixture package)\n"
        try A17.write(root, "norm/rules.yaml", norm)
        try A17.write(root, "src/CoreEngine.swift", src)
        try A17.write(root, "src/sub/DeepEngine.swift", deep)
        try A17.write(root, "probes/ProbeBase.swift", probe)
        try A17.write(root, "Package.swift", pkg)
        try A17.write(root, masterPath,
            "{\"frozen_marker\": \"a17-immutable\", \"data_visibility\": false, \"corpus_count\": 0, " +
            "\"annotator_count\": 0, \"real_fit_count\": 0, \"heldout_open_count\": 0}\n")
        try A17.git(root, ["add", "-A"])
        try A17.git(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try A17.git(root, ["rev-parse", "HEAD"]).1
        // candidate: canonical manifest (+ optional smuggled file INSIDE the candidate tree)
        let artifacts: [(String, String)] = [
            ("norm/rules.yaml", A17.shaHex(norm)),
            ("src/CoreEngine.swift", A17.shaHex(src)),
            ("src/sub/DeepEngine.swift", A17.shaHex(deep)),
            ("probes/ProbeBase.swift", A17.shaHex(probe)),
            ("Package.swift", A17.shaHex(pkg)),
        ]
        let invDigest = A17.shaHex(artifacts.map { "\($0.0):\($0.1)" }.sorted().joined(separator: "\n"))
        let manifestPath = RWCCorpusEntryVerifierV3.canonicalFreezeManifestPath
        let manifest = "{\"freeze_version\": \"\(freezeVersion)\", " +
            "\"methodology_anchor_commit\": \"\(anchor)\", " +
            "\"governing_control_plane_lock\": \"\(governing)\", " +
            "\"frozen_inventory_digest\": \"\(invDigest)\", " +
            "\"artifacts\": [" +
            artifacts.map { "{\"path\": \"\($0.0)\", \"sha256\": \"\($0.1)\"}" }
                .joined(separator: ", ") + "], " +
            "\"surface_rules\": {\"governed_roots\": [\"norm\", \"src\", \"probes\"], " +
            "\"post_anchor_allowed\": [], \"post_audit_allowed_prefixes\": [\"AUDIT\"], " +
            "\"hash_exempt\": []}}"
        try A17.write(root, manifestPath, manifest)
        if let (rel, content) = extraCandidateFile { try A17.write(root, rel, content) }
        try A17.git(root, ["add", "-A"])
        try A17.git(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try A17.git(root, ["rev-parse", "HEAD"]).1
        try A17.git(root, ["tag", "-a", tagName, "-m", "candidate tag"])
        let tagObject = try A17.git(root, ["rev-parse", "refs/tags/\(tagName)"]).1
        // audit commit
        func resultJSON(verdict v: String) -> String {
            "{\"result_version\": \"rwc-pre14-audit-result-v1\", \"verdict\": \"\(v)\", " +
            "\"candidate_commit\": \"\(candidate)\", \"candidate_tag_name\": \"\(tagName)\", " +
            "\"candidate_tag_object_sha\": \"\(tagObject)\", " +
            "\"methodology_anchor_commit\": \"\(anchor)\", " +
            "\"freeze_manifest_path\": \"\(manifestPath)\", " +
            "\"freeze_manifest_sha256\": \"\(A17.shaHex(manifest))\", " +
            "\"frozen_inventory_digest\": \"\(invDigest)\", " +
            "\"governing_control_plane_lock\": \"\(governing)\", " +
            "\"audit_probe_family\": \"AUDIT17_FIXTURE\", " +
            "\"baseline_count\": \(baseline), \"fresh_probe_count\": \(fresh), " +
            "\"total_count\": \(total), \"critical_count\": \(critical), " +
            "\"high_count\": \(high), \"medium_count\": \(medium), " +
            "\"auditor_declaration\": \"a17 fixture independent audit\"}"
        }
        let canonicalResult = resultJSON(verdict: verdict)
        if commitResultInAuditCommit {
            try A17.write(root, RWCPre14AuditResultV1.canonicalPath, canonicalResult)
        } else {
            try A17.write(root, "docs/audit/placeholder.txt", "no result committed\n")
        }
        try A17.git(root, ["add", "-A"])
        try A17.git(root, ["commit", "-q", "-m", "audit"])
        var audit = try A17.git(root, ["rev-parse", "HEAD"]).1
        var lockResultPath = RWCPre14AuditResultV1.canonicalPath
        var lockResultSHA = A17.shaHex(canonicalResult)
        if let fake = resultPathInLock {
            // A17-F4 scenario: honest FIX stays at the canonical path in the audit commit; a LATER
            // commit introduces a PASS result at an attacker-chosen path; the lock points there.
            let fakePass = resultJSON(verdict: "PASS")
            try A17.write(root, fake, fakePass)
            try A17.git(root, ["add", "-A"])
            try A17.git(root, ["commit", "-q", "-m", "attacker-result"])
            audit = try A17.git(root, ["rev-parse", "HEAD"]).1
            lockResultPath = fake
            lockResultSHA = A17.shaHex(fakePass)
        }
        if !commitResultInAuditCommit { lockResultSHA = A17.shaHex(canonicalResult) }
        // closeout lock (live file is the authority input; content cross-checked against git)
        let lock = "{\"lock_version\": \"rwc-pre14-pass-lock-v2\", " +
            "\"audit_result_path\": \"\(lockResultPath)\", " +
            "\"audit_result_blob_sha256\": \"\(lockResultSHA)\", " +
            "\"audit_commit\": \"\(audit)\", \"candidate_commit\": \"\(candidate)\", " +
            "\"candidate_tag_name\": \"\(tagName)\", " +
            "\"candidate_tag_object_sha\": \"\(tagObject)\", " +
            "\"freeze_manifest_path\": \"\(manifestPath)\", " +
            "\"freeze_manifest_sha256\": \"\(A17.shaHex(manifest))\", " +
            "\"methodology_anchor_commit\": \"\(anchor)\", " +
            "\"frozen_inventory_digest\": \"\(invDigest)\", " +
            "\"governing_control_plane_lock\": \"\(governing)\", " +
            "\"corpus_entry_authorized\": true}"
        try A17.write(root, RWCPre14PassLockV2.lockRelPath, lock)
        try A17.git(root, ["add", "-A"])
        try A17.git(root, ["commit", "-q", "-m", "closeout"])
        return A17Fixture(root: root, governing: governing, anchor: anchor, candidate: candidate,
                          audit: audit, tagObject: tagObject, manifestJSON: manifest,
                          resultJSON: canonicalResult)
    }

    static func mutateLock(_ fx: A17Fixture, _ mutate: (inout [String: Any]) -> Void) throws {
        let url = fx.root.appendingPathComponent(RWCPre14PassLockV2.lockRelPath)
        var obj = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        mutate(&obj)
        try JSONSerialization.data(withJSONObject: obj).write(to: url)
    }

    static func mutateMaster(_ fx: A17Fixture, _ mutate: (inout [String: Any]) -> Void) throws {
        let url = fx.root.appendingPathComponent(masterPath)
        var obj = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        mutate(&obj)
        try JSONSerialization.data(withJSONObject: obj).write(to: url)
    }
}

final class AUDIT17_VerifierAuthorityProbes: XCTestCase {

    private func expectEntry(_ root: URL, _ label: String,
                             file: StaticString = #filePath, line: UInt = #line,
                             _ check: @escaping (RWCCorpusEntryErrorV3) -> Bool) {
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV3.verify(repoRoot: root),
                             label, file: file, line: line) { e in
            guard let err = e as? RWCCorpusEntryErrorV3, check(err) else {
                return XCTFail("\(label): unexpected \(e)", file: file, line: line)
            }
        }
    }

    // MARK: lawful mint + FIX / open-findings / decorative-verdict attacks

    func test_A17_20_LawfulMint_Then_FIXAndOpenFindingsRefused() throws {
        let good = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: good.root) }
        let proof = try RWCCorpusEntryVerifierV3.verify(repoRoot: good.root)
        XCTAssertEqual(proof.candidateCommit, good.candidate)
        XCTAssertEqual(proof.candidateTagObjectSHA, good.tagObject)
        XCTAssertEqual(proof.auditResultBlobSHA256, A17.shaHex(good.resultJSON))

        let fix = try A17Fx.make(verdict: "FIX_REQUIRED")
        defer { try? FileManager.default.removeItem(at: fix.root) }
        expectEntry(fix.root, "FIX result refuses") {
            if case .auditVerdictNotPass("FIX_REQUIRED") = $0 { return true }
            return false
        }
        // decorative lock verdict PASS cannot override the committed FIX result
        try A17Fx.mutateLock(fix) { $0["verdict"] = "PASS" }
        expectEntry(fix.root, "decorative PASS over FIX refuses") {
            if case .auditVerdictNotPass = $0 { return true }
            return false
        }
        let open = try A17Fx.make(medium: 1)
        defer { try? FileManager.default.removeItem(at: open.root) }
        expectEntry(open.root, "PASS with medium=1 refuses") {
            if case .auditFindingsOpen(critical: 0, high: 0, medium: 1) = $0 { return true }
            return false
        }
        let negCritical = try A17Fx.make(critical: -1)
        defer { try? FileManager.default.removeItem(at: negCritical.root) }
        expectEntry(negCritical.root, "critical=-1 refuses (==0 law)") {
            if case .auditFindingsOpen = $0 { return true }
            return false
        }
    }

    // MARK: AUDIT17 FINDING A17-F4 — arbitrary audit-result path accepted

    func test_A17_21_FINDING_A17F4_AlternativeResultPath_Accepted() throws {
        // AUDIT17 FINDING A17-F4: pins defective behavior.
        // The honest audit commit carries FIX_REQUIRED at the CANONICAL result path. An attacker
        // commit (candidate still its ancestor) adds a PASS result at docs/audit/a17_fake_pass.json
        // and the lock redirects audit_result_path there. The verifier never requires
        // lock.auditResultPath == RWCPre14AuditResultV1.canonicalPath — the forged PASS MINTS.
        let fx = try A17Fx.make(verdict: "FIX_REQUIRED",
                                resultPathInLock: "docs/audit/a17_fake_pass.json")
        defer { try? FileManager.default.removeItem(at: fx.root) }
        let proof = try RWCCorpusEntryVerifierV3.verify(repoRoot: fx.root)
        XCTAssertEqual(proof.candidateCommit, fx.candidate,
                       "A17-F4: PASS authority redirected to a non-canonical result path")
        // the canonical result in the honest audit history still says FIX_REQUIRED
        let honest = try A17.run("git", ["-C", fx.root.path, "show",
                                         "\(fx.audit)~1:\(RWCPre14AuditResultV1.canonicalPath)"])
        XCTAssertTrue(honest.1.contains("FIX_REQUIRED"),
                      "A17-F4: honest canonical FIX result coexists with the minted fake PASS")
    }

    // MARK: committed-blob authority (live forgery dead) + ancestry

    func test_A17_22_CommittedBlobAuthority_LiveForgery_Ancestry() throws {
        // live PASS forgery over committed FIX: verdict read from git ⇒ refuse
        let fx = try A17Fx.make(verdict: "FIX_REQUIRED")
        defer { try? FileManager.default.removeItem(at: fx.root) }
        let liveURL = fx.root.appendingPathComponent(RWCPre14AuditResultV1.canonicalPath)
        let forged = fx.resultJSON.replacingOccurrences(of: "FIX_REQUIRED", with: "PASS")
        try forged.write(to: liveURL, atomically: true, encoding: .utf8)
        expectEntry(fx.root, "live forgery with committed-FIX sha") {
            if case .auditVerdictNotPass = $0 { return true }
            return false
        }
        // pointing the lock at the forged LIVE hash ⇒ blob hash mismatch
        try A17Fx.mutateLock(fx) { $0["audit_result_blob_sha256"] = A17.shaHex(forged) }
        expectEntry(fx.root, "forged live hash vs committed blob") { $0 == .auditResultHashMismatch }
        // result existing ONLY live (never committed) ⇒ refuse
        let uncommitted = try A17Fx.make(commitResultInAuditCommit: false)
        defer { try? FileManager.default.removeItem(at: uncommitted.root) }
        try A17.write(uncommitted.root, RWCPre14AuditResultV1.canonicalPath, uncommitted.resultJSON)
        expectEntry(uncommitted.root, "live-only result") { $0 == .auditResultMissingInAuditCommit }
        // result only in a commit LATER than lock.audit_commit ⇒ refuse
        let late = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: late.root) }
        try A17Fx.mutateLock(late) { $0["audit_commit"] = late.candidate }
        expectEntry(late.root, "result exists only in a later commit") {
            $0 == .auditResultMissingInAuditCommit
        }
        // unrelated audit commit (candidate not an ancestor) ⇒ refuse
        let unrelated = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: unrelated.root) }
        try A17Fx.mutateLock(unrelated) { $0["audit_commit"] = unrelated.governing }
        expectEntry(unrelated.root, "unrelated audit commit") { $0 == .candidateNotAncestorOfAudit }
    }

    // MARK: lock identity cross-check battery (§30/§32)

    func test_A17_23_LockFieldCrossChecks() throws {
        // tag object tampered in lock ⇒ tagObjectMismatch (git identity law)
        let t1 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: t1.root) }
        try A17Fx.mutateLock(t1) { $0["candidate_tag_object_sha"] = t1.candidate }
        expectEntry(t1.root, "wrong tag object") { $0 == .tagObjectMismatch }
        // unknown tag name ⇒ tagMissing
        let t2 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: t2.root) }
        try A17Fx.mutateLock(t2) { $0["candidate_tag_name"] = "a17-nonexistent-tag" }
        expectEntry(t2.root, "missing tag") { $0 == .tagMissing }
        // governing tampered in lock only ⇒ audit cross-check mismatch
        let t3 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: t3.root) }
        try A17Fx.mutateLock(t3) { $0["governing_control_plane_lock"] = t3.candidate }
        expectEntry(t3.root, "wrong governing") {
            if case .auditTargetMismatch(field: "governing_control_plane_lock") = $0 { return true }
            return false
        }
        // anchor redirected to another real commit ⇒ mismatch vs audit result
        let t4 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: t4.root) }
        try A17Fx.mutateLock(t4) { $0["methodology_anchor_commit"] = t4.governing }
        expectEntry(t4.root, "wrong anchor") {
            if case .auditTargetMismatch(field: "methodology_anchor_commit") = $0 { return true }
            return false
        }
        // inventory digest tampered ⇒ mismatch
        let t5 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: t5.root) }
        try A17Fx.mutateLock(t5) { $0["frozen_inventory_digest"] = A17.shaHex("fake-digest") }
        expectEntry(t5.root, "wrong inventory digest") {
            if case .auditTargetMismatch(field: "frozen_inventory_digest") = $0 { return true }
            return false
        }
        // freeze manifest hash tampered ⇒ mismatch
        let t6 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: t6.root) }
        try A17Fx.mutateLock(t6) { $0["freeze_manifest_sha256"] = A17.shaHex("fake-manifest") }
        expectEntry(t6.root, "wrong manifest hash") {
            if case .auditTargetMismatch(field: "freeze_manifest_sha256") = $0 { return true }
            return false
        }
        // corpus_entry_authorized=false and wrong lock version fail closed
        let t7 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: t7.root) }
        try A17Fx.mutateLock(t7) { $0["corpus_entry_authorized"] = false }
        expectEntry(t7.root, "not authorized") { $0 == .entryNotAuthorized }
        let t8 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: t8.root) }
        try A17Fx.mutateLock(t8) { $0["lock_version"] = "rwc-pre14-pass-lock-v1" }
        expectEntry(t8.root, "wrong lock version") { $0 == .lockVersionUnsupported }
        // missing lock fails closed
        let t9 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: t9.root) }
        try FileManager.default.removeItem(
            at: t9.root.appendingPathComponent(RWCPre14PassLockV2.lockRelPath))
        expectEntry(t9.root, "missing lock") { $0 == .lockMissing }
    }

    // MARK: canonical freeze path + version (§31/§32)

    func test_A17_24_CanonicalFreezePath_MiniManifest_Version() throws {
        // mini manifest at an attacker path (lock+result consistent) ⇒ nonCanonical refusal
        let mini = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: mini.root) }
        let miniJSON = "{\"freeze_version\": \"rwc-preregistration-freeze-v4\", \"artifacts\": []}"
        try A17.write(mini.root, "docs/evil/A17_MINI.yaml", miniJSON)
        try A17Fx.mutateLock(mini) {
            $0["freeze_manifest_path"] = "docs/evil/A17_MINI.yaml"
            $0["freeze_manifest_sha256"] = A17.shaHex(miniJSON)
        }
        expectEntry(mini.root, "mini manifest") {
            if case .auditTargetMismatch(field: "freeze_manifest_path") = $0 { return true }
            if case .nonCanonicalFreezeManifestPath = $0 { return true }
            return false
        }
        // byte-identical manifest under another path ⇒ refused (path law, not content law)
        let alt = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: alt.root) }
        try A17.write(alt.root, "docs/evil/A17_COPY.yaml", alt.manifestJSON)
        try A17Fx.mutateLock(alt) { $0["freeze_manifest_path"] = "docs/evil/A17_COPY.yaml" }
        expectEntry(alt.root, "identical manifest at alternate path") {
            if case .auditTargetMismatch(field: "freeze_manifest_path") = $0 { return true }
            if case .nonCanonicalFreezeManifestPath = $0 { return true }
            return false
        }
        // wrong freeze version (consistently hashed) ⇒ freezeVersionMismatch
        let v3 = try A17Fx.make(freezeVersion: "rwc-preregistration-freeze-v3")
        defer { try? FileManager.default.removeItem(at: v3.root) }
        expectEntry(v3.root, "wrong freeze version") { $0 == .freezeVersionMismatch }
    }

    // MARK: AUDIT17 FINDING A17-F3 — AUDIT* prefix is a GLOBAL basename allowance

    func test_A17_25_FINDING_A17F3_ProductionSource_AUDITPrefix_Bypass() throws {
        // AUDIT17 FINDING A17-F3: pins defective behavior.
        // gates v4 surface_law_v4 scopes the AUDIT* allowance to "the tests root", but the
        // verifier allows ANY basename starting with "AUDIT" in EVERY governed root — including
        // production source roots, where a .swift file is EXECUTABLE (SwiftPM compiles all
        // sources). A post-audit live file therefore bypasses the freeze surface.
        let fx = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: fx.root) }
        try A17.write(fx.root, "src/AUDITBackdoor.swift", "// executable post-audit code\nlet pwn = 1\n")
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV3.verify(repoRoot: fx.root),
                         "A17-F3: AUDIT-prefixed file in a PRODUCTION source root passes the freeze")
        // §34 nested subdirectory variant also passes (basename matching ignores directories)
        try A17.write(fx.root, "src/hidden/AUDITX.swift", "// nested bypass\nlet pwn2 = 2\n")
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV3.verify(repoRoot: fx.root),
                         "A17-F3: nested AUDIT-prefixed file passes too")
        // the allowance was intended for auditor evidence in the tests root — that part is lawful
        try? FileManager.default.removeItem(at: fx.root.appendingPathComponent("src/AUDITBackdoor.swift"))
        try? FileManager.default.removeItem(at: fx.root.appendingPathComponent("src/hidden"))
        try A17.write(fx.root, "probes/AUDIT17_Evidence.swift", "// auditor evidence\n")
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV3.verify(repoRoot: fx.root))
        // case variant does NOT match the prefix (refused) — the allowance is exact-prefix
        try A17.write(fx.root, "src/Audit17Sneak.swift", "// case variant\n")
        expectEntry(fx.root, "case variant refused") {
            if case .surfaceSetMismatch = $0 { return true }
            return false
        }
        // REAL-REPO latency check: no AUDIT-prefixed file currently exists in the real
        // production source roots (the bypass is latent, not exploited at the candidate).
        let real = A17.repoRoot()
        for root in ["packages/GuardianKit/Sources/GuardianCore",
                     "packages/GuardianKit/Sources/RWCAcquisition"] {
            let tree = try A17.git(real, ["ls-tree", "-r", "--name-only", A17.candidate, "--", root]).1
            for path in tree.split(separator: "\n") {
                let name = path.split(separator: "/").last.map(String.init) ?? ""
                XCTAssertFalse(name.hasPrefix("AUDIT"), "unexpected AUDIT file in \(root): \(path)")
            }
            let live = try FileManager.default.contentsOfDirectory(
                atPath: real.appendingPathComponent(root).path)
            for name in live {
                XCTAssertFalse(name.hasPrefix("AUDIT"), "unexpected live AUDIT file in \(root)")
            }
        }
    }

    // MARK: §35/§36 recursive surface, symlink, renamed/removed, git-tree, Package drift

    func test_A17_26_RecursiveSurface_Symlink_PackageDrift() throws {
        // unprefixed live file in nested governed subdirectory ⇒ refuse
        let fx1 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: fx1.root) }
        try A17.write(fx1.root, "src/hidden/Helper.swift", "// smuggled\n")
        expectEntry(fx1.root, "nested unprefixed file") {
            if case .surfaceSetMismatch(let stage, let extra, _) = $0 {
                return stage.hasPrefix("live:") && extra.contains("src/hidden/Helper.swift")
            }
            return false
        }
        // removed frozen source ⇒ refuse
        let fx2 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: fx2.root) }
        try FileManager.default.removeItem(at: fx2.root.appendingPathComponent("src/CoreEngine.swift"))
        expectEntry(fx2.root, "removed source") {
            if case .frozenFileMissing(path: "src/CoreEngine.swift") = $0 { return true }
            return false
        }
        // renamed frozen source ⇒ refuse (missing + would also be extra)
        let fx3 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: fx3.root) }
        let old = fx3.root.appendingPathComponent("src/CoreEngine.swift")
        try FileManager.default.moveItem(at: old,
            to: fx3.root.appendingPathComponent("src/CoreEngineRenamed.swift"))
        expectEntry(fx3.root, "renamed source") {
            if case .frozenFileMissing = $0 { return true }
            if case .surfaceSetMismatch = $0 { return true }
            return false
        }
        // modified frozen source bytes ⇒ drift
        let fx4 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: fx4.root) }
        try A17.write(fx4.root, "src/sub/DeepEngine.swift", "// tampered\nlet a17deep = 99\n")
        expectEntry(fx4.root, "modified source") {
            if case .frozenFileDrift(path: "src/sub/DeepEngine.swift") = $0 { return true }
            return false
        }
        // symlink anywhere under a governed root ⇒ typed refusal
        let fx5 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: fx5.root) }
        try FileManager.default.createSymbolicLink(
            at: fx5.root.appendingPathComponent("src/sub/link.swift"),
            withDestinationURL: fx5.root.appendingPathComponent("base/seed.md"))
        expectEntry(fx5.root, "symlink") {
            if case .symlinkInGovernedSurface = $0 { return true }
            return false
        }
        // Package.swift drift (hashed extra artifact) ⇒ refuse: the manifest-level route to a new
        // target/path is closed by the hash law
        let fx6 = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: fx6.root) }
        try A17.write(fx6.root, "Package.swift",
                      "// swift-tools-version:6.0 (a17 fixture package)\n// + evil new target\n")
        expectEntry(fx6.root, "Package.swift drift") {
            if case .frozenFileDrift(path: "Package.swift") = $0 { return true }
            return false
        }
        // smuggled file INSIDE the candidate git tree (not the live tree) ⇒ git-tree scan refuses
        let fx7 = try A17Fx.make(extraCandidateFile: ("src/SneakInTree.swift", "// in-tree\n"))
        defer { try? FileManager.default.removeItem(at: fx7.root) }
        try FileManager.default.removeItem(at: fx7.root.appendingPathComponent("src/SneakInTree.swift"))
        expectEntry(fx7.root, "git-tree extra") {
            if case .surfaceSetMismatch(let stage, let extra, _) = $0 {
                return stage.hasPrefix("git-tree:") && extra.contains("src/SneakInTree.swift")
            }
            return false
        }
    }

    // MARK: §37 zero counters + type substitution + immutable master fields

    func test_A17_27_ZeroCounters_TypeSubstitution_MasterImmutability() throws {
        for field in ["corpus_count", "annotator_count", "real_fit_count", "heldout_open_count"] {
            let fx = try A17Fx.make()
            defer { try? FileManager.default.removeItem(at: fx.root) }
            try A17Fx.mutateMaster(fx) { $0[field] = 1 }
            expectEntry(fx.root, "nonzero \(field)") { $0 == .zeroDataViolated(field: field) }
        }
        let vis = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: vis.root) }
        try A17Fx.mutateMaster(vis) { $0["data_visibility"] = true }
        expectEntry(vis.root, "visibility true") { $0 == .zeroDataViolated(field: "data_visibility") }
        // type substitution: "0" string / null / missing all fail closed
        let str = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: str.root) }
        try A17Fx.mutateMaster(str) { $0["corpus_count"] = "0" }
        expectEntry(str.root, "string zero") { $0 == .zeroDataViolated(field: "corpus_count") }
        let nul = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: nul.root) }
        try A17Fx.mutateMaster(nul) { $0["annotator_count"] = NSNull() }
        expectEntry(nul.root, "null counter") { $0 == .zeroDataViolated(field: "annotator_count") }
        let missing = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: missing.root) }
        try A17Fx.mutateMaster(missing) { $0.removeValue(forKey: "real_fit_count") }
        expectEntry(missing.root, "missing counter") {
            if case .zeroDataViolated(field: "real_fit_count") = $0 { return true }
            if case .masterImmutableFieldChanged(field: "real_fit_count") = $0 { return true }
            return false
        }
        let visStr = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: visStr.root) }
        try A17Fx.mutateMaster(visStr) { $0["data_visibility"] = "false" }
        expectEntry(visStr.root, "string false") { $0 == .zeroDataViolated(field: "data_visibility") }
        // immutable (non-counter) master field change vs anchor blob ⇒ refuse
        let imm = try A17Fx.make()
        defer { try? FileManager.default.removeItem(at: imm.root) }
        try A17Fx.mutateMaster(imm) { $0["frozen_marker"] = "tampered" }
        expectEntry(imm.root, "immutable field") {
            if case .masterImmutableFieldChanged(field: "frozen_marker") = $0 { return true }
            return false
        }
    }

    // MARK: §24/§25 machine audit-result schema attacks

    func test_A17_28_AuditResultSchema_ParseAttacks() throws {
        func json(_ overrides: [String: Any]) -> Data {
            var o: [String: Any] = [
                "result_version": "rwc-pre14-audit-result-v1", "verdict": "PASS",
                "candidate_commit": A17.candidate, "candidate_tag_name": A17Fx.tagName,
                "candidate_tag_object_sha": A17.tagObject, "methodology_anchor_commit": A17.anchor,
                "freeze_manifest_path": RWCCorpusEntryVerifierV3.canonicalFreezeManifestPath,
                "freeze_manifest_sha256": A17.shaHex("m"), "frozen_inventory_digest": A17.shaHex("i"),
                "governing_control_plane_lock": A17.governing,
                "audit_probe_family": "AUDIT17_RWC_PRE14_R3_REAUDIT",
                "baseline_count": 982, "fresh_probe_count": 39, "total_count": 1021,
                "critical_count": 0, "high_count": 0, "medium_count": 0,
                "auditor_declaration": "a17",
            ]
            for (k, v) in overrides {
                if v is NSNull { o.removeValue(forKey: k) } else { o[k] = v }
            }
            return try! JSONSerialization.data(withJSONObject: o)
        }
        XCTAssertNoThrow(try RWCPre14AuditResultV1.parse(data: json([:])))
        XCTAssertThrowsError(try RWCPre14AuditResultV1.parse(data: json(["critical_count": NSNull()])),
                             "missing count refused")
        XCTAssertThrowsError(try RWCPre14AuditResultV1.parse(data: json(["high_count": "3"])),
                             "string count refused")
        XCTAssertThrowsError(try RWCPre14AuditResultV1.parse(data: json(["verdict": ""])),
                             "empty verdict refused")
        XCTAssertThrowsError(try RWCPre14AuditResultV1.parse(data: json(["result_version": "v2"])),
                             "wrong version refused")
        XCTAssertThrowsError(try RWCPre14AuditResultV1.parse(
            data: Data("[1,2,3]".utf8)), "non-object refused")
        // integer overflow: a 25-digit count is not an Int ⇒ refused
        let big = String(repeating: "9", count: 25)
        XCTAssertThrowsError(try RWCPre14AuditResultV1.parse(
            data: Data("{\"result_version\":\"rwc-pre14-audit-result-v1\",\"critical_count\":\(big)}".utf8)))
        // lowercase / whitespace verdicts parse but can never mint (exact-string PASS law)
        let lower = try RWCPre14AuditResultV1.parse(data: json(["verdict": "pass"]))
        XCTAssertNotEqual(lower.verdict, "PASS")
        let padded = try RWCPre14AuditResultV1.parse(data: json(["verdict": " PASS"]))
        XCTAssertNotEqual(padded.verdict, "PASS")
        // AUDIT17 FINDING A17-F11: pins defective behavior — evidence-count metadata is
        // unvalidated: negative and self-inconsistent counts parse AND mint end-to-end.
        let neg = try RWCPre14AuditResultV1.parse(
            data: json(["baseline_count": -100, "fresh_probe_count": 0, "total_count": 900]))
        XCTAssertEqual(neg.baselineCount, -100,
                       "A17-F11: negative baseline_count accepted by the parser")
        let fx = try A17Fx.make(baseline: -100, fresh: 0, total: 900)
        defer { try? FileManager.default.removeItem(at: fx.root) }
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV3.verify(repoRoot: fx.root),
                         "A17-F11: baseline=-100/fresh=0/total=900 mints a PASS proof end-to-end")
        // fixture verdicts: lowercase pass refuses at the verify stage
        let lc = try A17Fx.make(verdict: "pass")
        defer { try? FileManager.default.removeItem(at: lc.root) }
        expectEntry(lc.root, "lowercase pass") {
            if case .auditVerdictNotPass("pass") = $0 { return true }
            return false
        }
        let unknown = try A17Fx.make(verdict: "APPROVED")
        defer { try? FileManager.default.removeItem(at: unknown.root) }
        expectEntry(unknown.root, "unknown verdict") {
            if case .auditVerdictNotPass = $0 { return true }
            return false
        }
    }

    // MARK: §3/§53 real repo: fail-closed, no PASS lock

    func test_A17_29_RealRepo_FailClosed_NoPassLock() throws {
        let real = A17.repoRoot()
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: real.appendingPathComponent(RWCPre14PassLockV2.lockRelPath).path))
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV3.verify(repoRoot: real)) { e in
            XCTAssertEqual(e as? RWCCorpusEntryErrorV3, .lockMissing)
        }
    }
}

#endif
