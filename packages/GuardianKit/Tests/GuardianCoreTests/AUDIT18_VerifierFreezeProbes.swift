import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
#if os(macOS)
import RWCAcquisition
#endif

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT18_RWC_PRE14_R4_REAUDIT — part 4 of 4: corpus-entry verifier V4 / freeze V5 adversarial
// battery on SYNTHETIC git fixtures that mirror the REAL topology (canonical manifest path under a
// governed root, manifest + master hash-exempt, scoped {root, filename_prefix} allowances, schema
// V2 result, lock V3). The real tracked tree is never modified.
// Probes pinning defective behavior are marked "AUDIT18 FINDING <id>: pins defective behavior".
// ═══════════════════════════════════════════════════════════════════════════════════════════════

#if os(macOS)

struct A18Fixture {
    let root: URL
    let governing: String
    let anchor: String
    let candidate: String
    let audit: String
    let tagObject: String
    let manifest: String
    let inventoryDigest: String
}

enum A18Fx {
    static let tagName = "a18-candidate-tag"
    static let cfgRoot = "docs/calibration/preregistration"   // contains manifest + master
    static var manifestPath: String { RWCCorpusEntryVerifierV4.canonicalFreezeManifestPath }
    static var masterPath: String { A18.masterPath }

    struct Allowance { let root: String; let prefix: String }

    static let srcContent = "// core\nlet a18src = 1\n"
    static let probeContent = "// probe\nlet a18probe = 2\n"
    static let masterContent = "{\"frozen_marker\": \"a18-immutable\", \"data_visibility\": false, " +
        "\"corpus_count\": 0, \"annotator_count\": 0, \"real_fit_count\": 0, " +
        "\"heldout_open_count\": 0}\n"

    /// The default frozen artifact set (src + probe + hash-exempt manifest/master self-entries).
    static func defaultArtifacts() -> [(String, String)] {
        [("src/Core.swift", A18.shaHex(srcContent)),
         ("probes/Probe.swift", A18.shaHex(probeContent)),
         (manifestPath, "exempt"),   // hash-exempt: value is informational only
         (masterPath, A18.shaHex(masterContent))]
    }

    /// Replace the LIVE manifest AFTER the candidate commit and re-issue a matching PASS
    /// result (new audit commit) + lock (new closeout) that binds the NEW manifest — the exact
    /// §39/§41 post-candidate replacement model. Returns nothing; the fixture tree is mutated.
    static func reendorse(_ fx: A18Fixture, governedRoots: [String], allowances: [Allowance],
                          artifacts: [(String, String)], extraLiveFiles: [(String, String)] = [],
                          commitExtras: Bool = true) throws {
        let manifest = buildManifest(anchor: fx.anchor, governing: fx.governing, roots: governedRoots,
                                     allowances: allowances, artifacts: artifacts)
        let inv = inventoryDigest(artifacts)
        try A18.write(fx.root, manifestPath, manifest)
        if commitExtras { for (rel, c) in extraLiveFiles { try A18.write(fx.root, rel, c) } }
        let result = buildResult(version: "rwc-pre14-audit-result-v2", verdict: "PASS",
                                 candidate: fx.candidate, tagName: tagName, tagObject: fx.tagObject,
                                 anchor: fx.anchor, governing: fx.governing,
                                 manifestSHA: A18.shaHex(manifest), inv: inv,
                                 probeFamily: "AUDIT18_RWC_PRE14_R4_REAUDIT", baseline: 5, fresh: 0,
                                 total: 5, critical: 0, high: 0, medium: 0)
        try A18.write(fx.root, RWCPre14AuditResultV2.canonicalPath, result)
        try A18.git(fx.root, ["add", "-A"]); try A18.git(fx.root, ["commit", "-q", "-m", "reendorse-audit"])
        let newAudit = try A18.git(fx.root, ["rev-parse", "HEAD"]).1
        let lock = buildLock(resultPath: RWCPre14AuditResultV2.canonicalPath,
                             resultSHA: A18.shaHex(result), audit: newAudit, candidate: fx.candidate,
                             tagName: tagName, tagObject: fx.tagObject,
                             manifestSHA: A18.shaHex(manifest), anchor: fx.anchor, inv: inv,
                             governing: fx.governing)
        try A18.write(fx.root, RWCPre14PassLockV3.lockRelPath, lock)
        try A18.git(fx.root, ["add", "-A"]); try A18.git(fx.root, ["commit", "-q", "-m", "reendorse-closeout"])
        // uncommitted live-only files (added AFTER the reendorse commits) when commitExtras == false
        if !commitExtras { for (rel, c) in extraLiveFiles { try A18.write(fx.root, rel, c) } }
    }

    /// Build a lawful V4 fixture (or an attacker variant via the knobs). The LIVE manifest is
    /// what `mutateManifestLive` rewrites AFTER the candidate commit; the result+lock are then
    /// regenerated to bind the NEW manifest, exactly the §39/§41 replacement model.
    static func make(verdict: String = "PASS", critical: Int = 0, high: Int = 0, medium: Int = 0,
                     baseline: Int = 5, fresh: Int = 0, total: Int = 5,
                     resultVersion: String = "rwc-pre14-audit-result-v2",
                     resultPathInLock: String? = nil,
                     tagNameInResult: String? = nil,
                     probeFamily: String = "AUDIT18_RWC_PRE14_R4_REAUDIT",
                     governedRoots: [String]? = nil,
                     allowances: [Allowance] = [Allowance(root: "probes", prefix: "AUDIT")],
                     extraArtifacts: [(String, String)] = [],
                     extraCandidateFiles: [(String, String)] = []) throws -> A18Fixture {
        let root = A18.tempDir("fx")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try A18.git(root, ["init", "-q"])
        try A18.write(root, "base/seed.md", "a18 governing base\n")
        try A18.git(root, ["add", "-A"]); try A18.git(root, ["commit", "-q", "-m", "gov"])
        let governing = try A18.git(root, ["rev-parse", "HEAD"]).1
        try A18.git(root, ["tag", "-a", RWCCorpusEntryVerifierV4.governingTagName, "-m", "gov"])
        // anchor commit: frozen content + master manifest (read from anchor blob by the verifier)
        try A18.write(root, "src/Core.swift", srcContent)
        try A18.write(root, "probes/Probe.swift", probeContent)
        try A18.write(root, masterPath, masterContent)
        try A18.git(root, ["add", "-A"]); try A18.git(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try A18.git(root, ["rev-parse", "HEAD"]).1
        // candidate commit: canonical manifest (hash-exempt itself + master) + its artifacts
        let roots = governedRoots ?? [cfgRoot, "src", "probes"]
        let artifacts: [(String, String)] = defaultArtifacts() + extraArtifacts
        let finalManifest = buildManifest(anchor: anchor, governing: governing, roots: roots,
                                          allowances: allowances, artifacts: artifacts)
        let inv = inventoryDigest(artifacts)
        try A18.write(root, manifestPath, finalManifest)
        for (rel, content) in extraCandidateFiles { try A18.write(root, rel, content) }
        try A18.git(root, ["add", "-A"]); try A18.git(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try A18.git(root, ["rev-parse", "HEAD"]).1
        try A18.git(root, ["tag", "-a", tagName, "-m", "cand"])
        let tagObject = try A18.git(root, ["rev-parse", "refs/tags/\(tagName)"]).1
        // audit commit: schema-V2 result at the canonical path
        let result = buildResult(version: resultVersion, verdict: verdict, candidate: candidate,
                                 tagName: tagNameInResult ?? tagName, tagObject: tagObject,
                                 anchor: anchor, governing: governing,
                                 manifestSHA: A18.shaHex(finalManifest), inv: inv,
                                 probeFamily: probeFamily, baseline: baseline, fresh: fresh,
                                 total: total, critical: critical, high: high, medium: medium)
        try A18.write(root, RWCPre14AuditResultV2.canonicalPath, result)
        try A18.git(root, ["add", "-A"]); try A18.git(root, ["commit", "-q", "-m", "audit"])
        let audit = try A18.git(root, ["rev-parse", "HEAD"]).1
        let lockResultPath = resultPathInLock ?? RWCPre14AuditResultV2.canonicalPath
        let lockResultSHA = A18.shaHex(result)
        let lock = buildLock(resultPath: lockResultPath, resultSHA: lockResultSHA, audit: audit,
                            candidate: candidate, tagName: tagName, tagObject: tagObject,
                            manifestSHA: A18.shaHex(finalManifest), anchor: anchor, inv: inv,
                            governing: governing)
        try A18.write(root, RWCPre14PassLockV3.lockRelPath, lock)
        try A18.git(root, ["add", "-A"]); try A18.git(root, ["commit", "-q", "-m", "closeout"])
        return A18Fixture(root: root, governing: governing, anchor: anchor, candidate: candidate,
                          audit: audit, tagObject: tagObject, manifest: finalManifest,
                          inventoryDigest: inv)
    }

    static func buildManifest(anchor: String, governing: String, roots: [String],
                              allowances: [Allowance], artifacts: [(String, String)]) -> String {
        let arts = artifacts.map { "{\"path\": \"\($0.0)\", \"sha256\": \"\($0.1)\"}" }
            .joined(separator: ", ")
        let allow = allowances.map {
            "{\"root\": \"\($0.root)\", \"filename_prefix\": \"\($0.prefix)\"}"
        }.joined(separator: ", ")
        let rootsJSON = roots.map { "\"\($0)\"" }.joined(separator: ", ")
        return "{\"freeze_version\": \"rwc-preregistration-freeze-v5\", " +
            "\"methodology_anchor_commit\": \"\(anchor)\", " +
            "\"governing_control_plane_lock\": \"\(governing)\", " +
            "\"frozen_inventory_digest\": \"\(inventoryDigest(artifacts))\", " +
            "\"artifacts\": [\(arts)], \"surface_rules\": {" +
            "\"governed_roots\": [\(rootsJSON)], \"post_anchor_allowed\": [], " +
            "\"post_audit_allowances\": [\(allow)], " +
            "\"hash_exempt\": [\"\(manifestPath)\", \"\(masterPath)\"]}}"
    }

    static func buildResult(version: String, verdict: String, candidate: String, tagName: String,
                            tagObject: String, anchor: String, governing: String, manifestSHA: String,
                            inv: String, probeFamily: String, baseline: Int, fresh: Int, total: Int,
                            critical: Int, high: Int, medium: Int) -> String {
        "{\"result_version\": \"\(version)\", \"verdict\": \"\(verdict)\", " +
        "\"candidate_commit\": \"\(candidate)\", \"candidate_tag_name\": \"\(tagName)\", " +
        "\"candidate_tag_object_sha\": \"\(tagObject)\", " +
        "\"methodology_anchor_commit\": \"\(anchor)\", \"freeze_manifest_path\": \"\(manifestPath)\", " +
        "\"freeze_manifest_sha256\": \"\(manifestSHA)\", \"frozen_inventory_digest\": \"\(inv)\", " +
        "\"governing_control_plane_lock\": \"\(governing)\", \"audit_probe_family\": \"\(probeFamily)\", " +
        "\"baseline_count\": \(baseline), \"fresh_probe_count\": \(fresh), \"total_count\": \(total), " +
        "\"critical_count\": \(critical), \"high_count\": \(high), \"medium_count\": \(medium), " +
        "\"auditor_declaration\": \"a18 fixture\"}"
    }

    static func buildLock(resultPath: String, resultSHA: String, audit: String, candidate: String,
                          tagName: String, tagObject: String, manifestSHA: String, anchor: String,
                          inv: String, governing: String) -> String {
        "{\"lock_version\": \"rwc-pre14-pass-lock-v3\", \"audit_result_path\": \"\(resultPath)\", " +
        "\"audit_result_blob_sha256\": \"\(resultSHA)\", \"audit_commit\": \"\(audit)\", " +
        "\"candidate_commit\": \"\(candidate)\", \"candidate_tag_name\": \"\(tagName)\", " +
        "\"candidate_tag_object_sha\": \"\(tagObject)\", \"freeze_manifest_path\": \"\(manifestPath)\", " +
        "\"freeze_manifest_sha256\": \"\(manifestSHA)\", \"methodology_anchor_commit\": \"\(anchor)\", " +
        "\"frozen_inventory_digest\": \"\(inv)\", \"governing_control_plane_lock\": \"\(governing)\", " +
        "\"corpus_entry_authorized\": true}"
    }

    static func inventoryDigest(_ artifacts: [(String, String)]) -> String {
        var map: [String: String] = [:]
        for (p, s) in artifacts { map[p] = s }
        return A18.shaHex(map.keys.sorted().map { "\($0):\(map[$0]!)" }.joined(separator: "\n"))
    }

    static func mutateLock(_ fx: A18Fixture, _ mutate: (inout [String: Any]) -> Void) throws {
        let url = fx.root.appendingPathComponent(RWCPre14PassLockV3.lockRelPath)
        var obj = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        mutate(&obj)
        try JSONSerialization.data(withJSONObject: obj).write(to: url)
    }
}

final class AUDIT18_VerifierFreezeProbes: XCTestCase {

    private func expect(_ root: URL, _ label: String,
                        file: StaticString = #filePath, line: UInt = #line,
                        _ check: @escaping (RWCCorpusEntryErrorV4) -> Bool) {
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV4.verify(repoRoot: root), label,
                             file: file, line: line) { e in
            guard let err = e as? RWCCorpusEntryErrorV4, check(err) else {
                return XCTFail("\(label): unexpected \(e)", file: file, line: line)
            }
        }
    }

    // MARK: §38 lawful mint + §45 strict counts

    func test_A18_40_LawfulMint_And_StrictCounts() throws {
        let good = try A18Fx.make()
        defer { try? FileManager.default.removeItem(at: good.root) }
        let proof = try RWCCorpusEntryVerifierV4.verify(repoRoot: good.root)
        XCTAssertEqual(proof.candidateCommit, good.candidate)
        XCTAssertEqual(proof.candidateTagObjectSHA, good.tagObject)
        // FIX_REQUIRED refuses
        let fix = try A18Fx.make(verdict: "FIX_REQUIRED")
        defer { try? FileManager.default.removeItem(at: fix.root) }
        expect(fix.root, "FIX refuses") {
            if case .auditVerdictNotPass("FIX_REQUIRED") = $0 { return true }; return false
        }
        // open medium refuses (PASS requires 0/0/0)
        let med = try A18Fx.make(medium: 1, total: 5)
        defer { try? FileManager.default.removeItem(at: med.root) }
        expect(med.root, "medium=1 refuses") {
            if case .auditFindingsOpen(0, 0, 1) = $0 { return true }; return false
        }
        // inconsistent counts baseline+fresh!=total refuses at parse
        let bad = try A18Fx.make(baseline: 5, fresh: 0, total: 6)
        defer { try? FileManager.default.removeItem(at: bad.root) }
        expect(bad.root, "count inconsistency") {
            if case .auditCountInconsistent = $0 { return true }
            if case .auditResultMalformed = $0 { return true }; return false
        }
        // decorative lock verdict mismatch refuses
        let dec = try A18Fx.make()
        defer { try? FileManager.default.removeItem(at: dec.root) }
        try A18Fx.mutateLock(dec) { $0["verdict"] = "FIX_REQUIRED" }
        expect(dec.root, "decorative mismatch") {
            if case .auditTargetMismatch(field: "decorative verdict") = $0 { return true }; return false
        }
    }

    // MARK: §44 canonical audit-result path (identical PASS bytes elsewhere refused)

    func test_A18_41_CanonicalResultPath_Enforced() throws {
        let fx = try A18Fx.make(resultPathInLock: "docs/audit/a18_fake_pass.json")
        defer { try? FileManager.default.removeItem(at: fx.root) }
        // also physically place identical PASS bytes at the fake path so only the PATH law can refuse
        try A18.write(fx.root, "docs/audit/a18_fake_pass.json", fx.manifest) // content irrelevant
        expect(fx.root, "non-canonical result path") {
            if case .nonCanonicalAuditResultPath = $0 { return true }; return false
        }
    }

    // MARK: §46 AUDIT18 FINDING A18-F4 — audit.candidateTagName is NOT cross-checked to the lock

    func test_A18_42_FINDING_A18F4_TagName_NotCrossChecked() throws {
        // AUDIT18 FINDING A18-F4: pins defective behavior.
        // VerifierV4 cross-checks candidate_commit, tag OBJECT sha, anchor, freeze, inventory,
        // governing — but NEVER compares audit.candidateTagName to lock.candidateTagName. An audit
        // result naming a DIFFERENT tag (while the object SHA still matches the real annotated tag)
        // mints. Evidence-integrity drift: the machine result can advertise a tag identity that the
        // lock does not corroborate.
        let fx = try A18Fx.make(tagNameInResult: "a18-some-other-tag-name")
        defer { try? FileManager.default.removeItem(at: fx.root) }
        let proof = try RWCCorpusEntryVerifierV4.verify(repoRoot: fx.root)
        XCTAssertEqual(proof.candidateCommit, fx.candidate,
                       "A18-F4: result.candidate_tag_name != lock.candidate_tag_name still mints")
    }

    // MARK: §42 production AUDIT file refused; §43 scoped audit file allowed

    func test_A18_43_ScopedAllowance_ProductionAUDIT_Refused() throws {
        // production source root has NO allowance: an AUDIT-prefixed .swift there is surface drift
        let prod = try A18Fx.make()
        defer { try? FileManager.default.removeItem(at: prod.root) }
        try A18.write(prod.root, "src/AUDITBackdoor.swift", "// executable post-audit\nlet pwn = 1\n")
        expect(prod.root, "production AUDIT file") {
            if case .carried(.surfaceSetMismatch(let stage, let extra, _)) = $0 {
                return stage.hasPrefix("live:") && extra.contains("src/AUDITBackdoor.swift")
            }
            return false
        }
        // nested variant also refused (scoped to exact root, not basename-global)
        let nested = try A18Fx.make()
        defer { try? FileManager.default.removeItem(at: nested.root) }
        try A18.write(nested.root, "src/hidden/AUDITX.swift", "// nested\nlet p = 2\n")
        expect(nested.root, "nested production AUDIT file") {
            if case .carried(.surfaceSetMismatch) = $0 { return true }; return false
        }
        // scoped allowance root (probes) + AUDIT prefix IS allowed (auditor evidence)
        let ok = try A18Fx.make()
        defer { try? FileManager.default.removeItem(at: ok.root) }
        try A18.write(ok.root, "probes/AUDIT18_Evidence.swift", "// auditor evidence\n")
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV4.verify(repoRoot: ok.root),
                         "AUDIT file in the scoped tests-equivalent root is lawful")
        // non-AUDIT file in the allowance root still drifts (prefix law inside the scope)
        let nonAudit = try A18Fx.make()
        defer { try? FileManager.default.removeItem(at: nonAudit.root) }
        try A18.write(nonAudit.root, "probes/Sneak.swift", "// not audit-prefixed\n")
        expect(nonAudit.root, "non-AUDIT file in allowance root") {
            if case .carried(.surfaceSetMismatch) = $0 { return true }; return false
        }
    }

    // MARK: §39/§40/§41 AUDIT18 FINDING A18-F5 — live manifest is NOT bound to the candidate blob

    func test_A18_44_FINDING_A18F5_PostCandidate_ManifestReplacement_Endorsed() throws {
        // AUDIT18 FINDING A18-F5: pins defective behavior.
        // The manifest is hash_exempt + its PATH is in the frozen inventory, so the surface scans
        // only prove the FILE EXISTS at the candidate commit — never that its CONTENT equals the
        // candidate-commit blob. The verifier reads the LIVE manifest and only requires
        // live==lock==audit-result freeze sha. Nothing executes
        //   git show <candidate_commit>:<manifest_path>  and compares it.
        // Therefore a manifest REPLACED after the candidate commit, endorsed by a matching PASS
        // result + lock, is accepted. Two concrete exploitations:
        //
        // (A) ALLOWANCE BROADENING + live-only production file: build a LAWFUL fixture (narrow
        //     allowance baked into the candidate), then AFTER the candidate commit re-issue the
        //     manifest with a broadened {src, ""} allowance plus a matching PASS result+lock, and
        //     drop a post-candidate executable file into production `src`. The live scan allows it;
        //     the candidate git-tree never contained it; verify ACCEPTS.
        let broaden = try A18Fx.make()   // candidate manifest has ONLY {probes, AUDIT}
        defer { try? FileManager.default.removeItem(at: broaden.root) }
        // prove the honest candidate manifest does NOT contain the broadened allowance
        let candManifest = try A18.gitShowRaw(broaden.root,
            "\(broaden.candidate):\(A18Fx.manifestPath)").1
        XCTAssertFalse(String(data: candManifest, encoding: .utf8)!
            .contains("\"root\": \"src\", \"filename_prefix\": \"\""),
            "candidate-commit manifest has only the narrow allowance")
        try A18Fx.reendorse(broaden,
            governedRoots: [A18Fx.cfgRoot, "src", "probes"],
            allowances: [A18Fx.Allowance(root: "probes", prefix: "AUDIT"),
                         A18Fx.Allowance(root: "src", prefix: "")],
            artifacts: A18Fx.defaultArtifacts(),
            extraLiveFiles: [("src/Backdoor.swift", "// post-candidate executable\nlet pwn = 1\n")],
            commitExtras: false)   // backdoor is live-only, never in any commit tree
        let proofA = try RWCCorpusEntryVerifierV4.verify(repoRoot: broaden.root)
        XCTAssertEqual(proofA.candidateCommit, broaden.candidate,
                       "A18-F5(A): a manifest REPLACED after the candidate broadened the allowance " +
                       "to admit a live production file; verify accepted — the live manifest is not " +
                       "bound to the candidate-commit blob")
        //
        // (B) GOVERNED-ROOT REMOVAL: after the candidate, drop `src` from governed_roots and from
        //     the artifact list, so the production source root is neither hash-checked nor
        //     surface-checked; a post-candidate LIVE modification to src/Core.swift goes undetected.
        let dropRoot = try A18Fx.make()
        defer { try? FileManager.default.removeItem(at: dropRoot.root) }
        try A18Fx.reendorse(dropRoot,
            governedRoots: [A18Fx.cfgRoot, "probes"],   // src no longer governed
            allowances: [A18Fx.Allowance(root: "probes", prefix: "AUDIT")],
            artifacts: [("probes/Probe.swift", A18.shaHex(A18Fx.probeContent)),
                        (A18Fx.manifestPath, "exempt"),
                        (A18Fx.masterPath, A18.shaHex(A18Fx.masterContent))])   // src/Core dropped
        // tamper the production source AFTER re-endorsement — would be frozenFileDrift if governed
        try A18.write(dropRoot.root, "src/Core.swift", "// TAMPERED post-candidate\nlet a18src = 999\n")
        let proofB = try RWCCorpusEntryVerifierV4.verify(repoRoot: dropRoot.root)
        XCTAssertEqual(proofB.candidateCommit, dropRoot.candidate,
                       "A18-F5(B): removing a production governed root post-candidate let a tampered " +
                       "source pass undetected; the freeze boundary is not bound to the candidate " +
                       "manifest blob")
    }

    // MARK: §39 hash-exempt mutation — the manifest's own bytes can change with no drift signal

    func test_A18_45_FINDING_A18F5_HashExempt_Manifest_SelfMutation() throws {
        // AUDIT18 FINDING A18-F5 (same root cause): because the manifest lists ITSELF in
        // hash_exempt, its own bytes are never hash-verified against anything bound to the
        // candidate; only the lock/result freeze sha (all attacker-chosen together) must agree.
        // Demonstrate: a lawful fixture whose manifest is rebuilt with a DIFFERENT governed-root
        // ordering / allowance set still verifies as long as lock+result are regenerated to match
        // — there is no candidate-blob anchor to contradict it.
        let fx = try A18Fx.make()   // candidate manifest: narrow {probes, AUDIT} only
        defer { try? FileManager.default.removeItem(at: fx.root) }
        try A18Fx.reendorse(fx,
            governedRoots: [A18Fx.cfgRoot, "src", "probes"],
            allowances: [A18Fx.Allowance(root: "probes", prefix: "AUDIT"),
                         A18Fx.Allowance(root: A18Fx.cfgRoot, prefix: "")],
            artifacts: A18Fx.defaultArtifacts(),
            extraLiveFiles: [("\(A18Fx.cfgRoot)/POST_CANDIDATE_NOTE.md", "added after candidate\n")],
            commitExtras: false)
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV4.verify(repoRoot: fx.root),
                         "A18-F5: hash-exempt manifest self-mutation (broadened cfg allowance) " +
                         "endorsed post-candidate with no candidate-blob contradiction")
    }

    // MARK: §48 add-only audit scope (real repo git topology)

    func test_A18_46_AuditCommit_AddOnly_RealRepo_NoPassLock() throws {
        let real = A18.repoRoot()
        // the real repo fails closed (no PASS lock)
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV4.verify(repoRoot: real)) { e in
            XCTAssertEqual(e as? RWCCorpusEntryErrorV4, .lockMissing)
        }
        // R5 INVERSION I-1 (pre-declared in AUDIT18_R5_INVERSION_LOCK.md ADDENDUM 1): the add-only
        // topology guard is pinned to the IMMUTABLE AUDIT18 commit — the audited fact ("the AUDIT18
        // commit was add-only relative to the candidate") is preserved forever and no longer floats
        // with HEAD across lawful later rounds.
        let auditCommit = "ac91974ddba3289031efe1df075185178259472b"
        let names = try A18.git(real, ["diff", "--name-only", A18.candidate, auditCommit]).1
            .split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        for n in names {
            let isAuditSurface = n.hasPrefix("docs/audit/")
                || n.contains("/GuardianCoreTests/AUDIT18_")
            XCTAssertTrue(isAuditSurface,
                          "candidate..HEAD must be add-only auditor surface; unexpected: \(n)")
        }
    }
}

#endif
