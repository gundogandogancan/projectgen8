#if os(macOS)
import Foundation
import CryptoKit
import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC CORPUS ENTRY AUTHORITY V3 (AUDIT16 R3) — REAL, NON-TEST acquisition gate (A16-F22/§39).
// Supersedes RWCCorpusEntryGuardV1 and the test-target RWCCorpusEntryVerifierV2 BY RECORD.
//
// AUTHORITY MODEL — the verifier derives EVERY fact from Git objects + canonical audited files +
// live surface verification; caller strings are never authority:
//  • A16-F12: the PASS truth is the MACHINE AUDIT RESULT (RWC_PRE14_AUDIT_RESULT schema) created
//    ONLY by the independent auditor and read FROM THE AUDIT COMMIT OBJECT; the lock's own
//    "verdict" field is non-authoritative decoration (if present it must match, but it can never
//    authorize). PASS law: verdict==PASS AND critical==high==medium==0 AND all identities match.
//  • A16-F13: audit artifacts are read via `git show <audit_commit>:<path>` — committed blob is
//    the authority; a live-file PASS forgery over a FIX-committed audit cannot mint.
//  • A16-F14: the candidate commit MUST be an ancestor of the audit commit (add-only audit
//    topology), and the audit result's candidate identity must equal the lock's.
//  • A16-F15: EVERY lock field is verified — governing control-plane lock (three-way: lock ==
//    freeze manifest == live git tag dereference), freeze_version, methodology anchor,
//    frozen inventory digest. No parsed-but-unused fields.
//  • A16-F16: ONLY the canonical freeze manifest path is accepted; its SHA must match the lock
//    AND the committed audit result. Attacker mini-manifests cannot narrow authority.
//  • A16-F17: ALL FIVE zero-data counters (corpus, annotator, fit, heldout, visibility) are
//    required zero/false before entry. Master-manifest field-level mutability is enforced by
//    comparing the live file against the ANCHOR-COMMIT blob: immutable fields must be identical.
//  • A16-F18/F19/F20: governed-surface law uses GIT TREE enumeration at the candidate commit plus
//    a FULL RECURSIVE live filesystem scan — no filename prefixes, no top-level-only listing;
//    a symlink anywhere under a governed root is a typed REFUSAL (never followed, never skipped).
//    SET EQUALITY both directions against the frozen inventory (+ explicit post-anchor allowances
//    and the AUDIT*-prefixed auditor-evidence pattern inside the tests root).
//
// R3 creates NO PASS lock and NO audit result instance; this component exists so the FUTURE first
// asset is structurally gated by a real library, not a test helper. ZERO-DATA holds throughout.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

public enum RWCCorpusEntryErrorV3: Error, Equatable, Sendable {
    case lockMissing
    case lockMalformed(String)
    case lockVersionUnsupported
    case entryNotAuthorized
    case gitUnavailable(String)
    case commitMissing(field: String)
    case tagMissing
    case tagNotAnnotated
    case tagObjectMismatch
    case tagDereferenceMismatch
    case candidateNotAncestorOfAudit
    case anchorNotAncestorOfCandidate
    case auditResultMissingInAuditCommit
    case auditResultMalformed(String)
    case auditResultHashMismatch
    case auditVerdictNotPass(String)
    case auditFindingsOpen(critical: Int, high: Int, medium: Int)
    case auditTargetMismatch(field: String)
    case lockVerdictContradictsAuditResult
    case governingLockMismatch(stage: String)
    case nonCanonicalFreezeManifestPath(String)
    case freezeManifestMissing
    case freezeManifestHashMismatch(stage: String)
    case freezeManifestMalformed(String)
    case freezeVersionMismatch
    case anchorMismatch
    case inventoryDigestMismatch(stage: String)
    case frozenFileMissing(path: String)
    case frozenFileDrift(path: String)
    case symlinkInGovernedSurface(path: String)
    case surfaceSetMismatch(stage: String, extra: [String], missing: [String])
    case masterManifestMalformed
    case masterImmutableFieldChanged(field: String)
    case zeroDataViolated(field: String)
}

/// Machine-readable independent audit result (R3 mandate §25/§50). Builder defines the schema;
/// ONLY an independent PRE-14 auditor may instantiate it, committed in the audit commit.
public struct RWCPre14AuditResultV1: Sendable {
    public static let expectedVersion = "rwc-pre14-audit-result-v1"
    public static let canonicalPath = "docs/audit/RWC_PRE14_R3_AUDIT_RESULT.json"

    public let resultVersion: String
    public let verdict: String                   // "PASS" | "FIX_REQUIRED" | "BLOCKED"
    public let candidateCommit: String
    public let candidateTagName: String
    public let candidateTagObjectSHA: String
    public let methodologyAnchorCommit: String
    public let freezeManifestPath: String
    public let freezeManifestSHA256: String
    public let frozenInventoryDigest: String
    public let governingControlPlaneLock: String
    public let auditProbeFamily: String
    public let baselineCount: Int
    public let freshProbeCount: Int
    public let totalCount: Int
    public let criticalCount: Int
    public let highCount: Int
    public let mediumCount: Int
    public let auditorDeclaration: String

    public static func parse(data: Data) throws -> RWCPre14AuditResultV1 {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RWCCorpusEntryErrorV3.auditResultMalformed("not strict JSON")
        }
        func str(_ k: String) throws -> String {
            guard let v = o[k] as? String, !v.isEmpty else {
                throw RWCCorpusEntryErrorV3.auditResultMalformed("missing \(k)")
            }
            return v
        }
        func int(_ k: String) throws -> Int {
            guard let v = o[k] as? Int else { throw RWCCorpusEntryErrorV3.auditResultMalformed("missing \(k)") }
            return v
        }
        let r = RWCPre14AuditResultV1(
            resultVersion: try str("result_version"), verdict: try str("verdict"),
            candidateCommit: try str("candidate_commit"), candidateTagName: try str("candidate_tag_name"),
            candidateTagObjectSHA: try str("candidate_tag_object_sha"),
            methodologyAnchorCommit: try str("methodology_anchor_commit"),
            freezeManifestPath: try str("freeze_manifest_path"),
            freezeManifestSHA256: try str("freeze_manifest_sha256"),
            frozenInventoryDigest: try str("frozen_inventory_digest"),
            governingControlPlaneLock: try str("governing_control_plane_lock"),
            auditProbeFamily: try str("audit_probe_family"),
            baselineCount: try int("baseline_count"), freshProbeCount: try int("fresh_probe_count"),
            totalCount: try int("total_count"), criticalCount: try int("critical_count"),
            highCount: try int("high_count"), mediumCount: try int("medium_count"),
            auditorDeclaration: try str("auditor_declaration"))
        guard r.resultVersion == expectedVersion else {
            throw RWCCorpusEntryErrorV3.auditResultMalformed("unsupported result_version")
        }
        return r
    }
}

/// PASS-lock schema v2 (§51): identity bindings only; no authoritative verdict of its own.
public struct RWCPre14PassLockV2: Sendable {
    public static let expectedVersion = "rwc-pre14-pass-lock-v2"
    public static let lockRelPath = "docs/audit/RWC_PRE14_PASS_LOCK.yaml"

    public let lockVersion: String
    public let auditResultPath: String
    public let auditResultBlobSHA256: String
    public let auditCommit: String
    public let candidateCommit: String
    public let candidateTagName: String
    public let candidateTagObjectSHA: String
    public let freezeManifestPath: String
    public let freezeManifestSHA256: String
    public let methodologyAnchorCommit: String
    public let frozenInventoryDigest: String
    public let governingControlPlaneLock: String
    public let corpusEntryAuthorized: Bool
    public let decorativeVerdict: String?        // non-authoritative; must match audit result if set

    public static func parse(data: Data) throws -> RWCPre14PassLockV2 {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RWCCorpusEntryErrorV3.lockMalformed("not strict JSON")
        }
        func str(_ k: String) throws -> String {
            guard let v = o[k] as? String, !v.isEmpty else {
                throw RWCCorpusEntryErrorV3.lockMalformed("missing \(k)")
            }
            return v
        }
        guard let authorized = o["corpus_entry_authorized"] as? Bool else {
            throw RWCCorpusEntryErrorV3.lockMalformed("missing corpus_entry_authorized")
        }
        return RWCPre14PassLockV2(
            lockVersion: try str("lock_version"), auditResultPath: try str("audit_result_path"),
            auditResultBlobSHA256: try str("audit_result_blob_sha256"), auditCommit: try str("audit_commit"),
            candidateCommit: try str("candidate_commit"), candidateTagName: try str("candidate_tag_name"),
            candidateTagObjectSHA: try str("candidate_tag_object_sha"),
            freezeManifestPath: try str("freeze_manifest_path"),
            freezeManifestSHA256: try str("freeze_manifest_sha256"),
            methodologyAnchorCommit: try str("methodology_anchor_commit"),
            frozenInventoryDigest: try str("frozen_inventory_digest"),
            governingControlPlaneLock: try str("governing_control_plane_lock"),
            corpusEntryAuthorized: authorized, decorativeVerdict: o["verdict"] as? String)
    }
}

/// Unforgeable proof: fileprivate init — the ONLY mint path is a full successful verification.
public struct RWCVerifiedCorpusEntryV3: Sendable {
    public let candidateCommit: String
    public let candidateTagObjectSHA: String
    public let auditCommit: String
    public let auditResultBlobSHA256: String
    public let methodologyAnchorCommit: String
    public let freezeManifestSHA256: String
    public let frozenInventoryDigest: String
    fileprivate init(candidateCommit: String, candidateTagObjectSHA: String, auditCommit: String,
                     auditResultBlobSHA256: String, methodologyAnchorCommit: String,
                     freezeManifestSHA256: String, frozenInventoryDigest: String) {
        self.candidateCommit = candidateCommit; self.candidateTagObjectSHA = candidateTagObjectSHA
        self.auditCommit = auditCommit; self.auditResultBlobSHA256 = auditResultBlobSHA256
        self.methodologyAnchorCommit = methodologyAnchorCommit
        self.freezeManifestSHA256 = freezeManifestSHA256; self.frozenInventoryDigest = frozenInventoryDigest
    }
}

public enum RWCCorpusEntryVerifierV3 {
    public static let version = "rwc-corpus-entry-verifier-v3"
    /// A16-F16: the ONLY acceptable freeze manifest (canonical constant, not caller input).
    public static let canonicalFreezeManifestPath =
        "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V4.yaml"
    public static let governingTagName = "gen8-ulu-evren-control-plane-r1-locked-governing"
    /// Master-manifest field-level mutability law (A16-F17/§38): ONLY these top-level fields may
    /// ever differ from the anchor-commit blob, via explicit post-entry transitions.
    public static let masterMutableFields: Set<String> =
        ["data_visibility", "corpus_count", "annotator_count", "real_fit_count", "heldout_open_count"]
    static let masterManifestPath =
        "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml"

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    static func git(_ repoRoot: URL, _ args: [String]) throws -> (status: Int32, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git", "-C", repoRoot.path] + args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { throw RWCCorpusEntryErrorV3.gitUnavailable("\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }

    static func gitShowBlob(_ repoRoot: URL, commit: String, path: String) throws -> Data? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git", "-C", repoRoot.path, "show", "\(commit):\(path)"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { throw RWCCorpusEntryErrorV3.gitUnavailable("\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return p.terminationStatus == 0 ? data : nil
    }

    static func commitExists(_ repoRoot: URL, _ sha: String) throws -> Bool {
        let r = try git(repoRoot, ["rev-parse", "--verify", "--quiet", sha + "^{commit}"])
        return r.status == 0 && r.out == sha
    }

    /// FULL RECURSIVE live scan (A16-F18/F19): every regular file under the root, no prefixes, no
    /// top-level shortcuts; SYMLINK = typed refusal (A16-F20), never followed, never skipped.
    static func liveScan(repoRoot: URL, root: String) throws -> Set<String> {
        var found = Set<String>()
        let fm = FileManager.default
        func walk(_ rel: String) throws {
            let abs = repoRoot.appendingPathComponent(rel).path
            guard let names = try? fm.contentsOfDirectory(atPath: abs) else { return }
            for name in names.sorted() {
                let childRel = rel + "/" + name
                let childAbs = abs + "/" + name
                let attrs = try? fm.attributesOfItem(atPath: childAbs)
                if attrs?[.type] as? FileAttributeType == .typeSymbolicLink {
                    throw RWCCorpusEntryErrorV3.symlinkInGovernedSurface(path: childRel)
                }
                var isDir: ObjCBool = false
                fm.fileExists(atPath: childAbs, isDirectory: &isDir)
                if isDir.boolValue { try walk(childRel) } else { found.insert(childRel) }
            }
        }
        try walk(root)
        return found
    }

    /// Git-tree enumeration at an exact commit (A16-F18/§35): the canonical frozen surface.
    static func gitTreeScan(repoRoot: URL, commit: String, root: String) throws -> Set<String> {
        let r = try git(repoRoot, ["ls-tree", "-r", "--name-only", commit, "--", root])
        guard r.status == 0 else { throw RWCCorpusEntryErrorV3.commitMissing(field: "surface commit") }
        return Set(r.out.split(separator: "\n").map(String.init).filter { !$0.isEmpty })
    }

    static func inventoryDigest(_ pathToSHA: [String: String]) -> String {
        sha256Hex(Data(pathToSHA.keys.sorted().map { "\($0):\(pathToSHA[$0]!)" }
            .joined(separator: "\n").utf8))
    }

    /// THE authoritative verification (see header for the per-finding law map).
    public static func verify(repoRoot: URL) throws -> RWCVerifiedCorpusEntryV3 {
        // 1. lock
        let lockURL = repoRoot.appendingPathComponent(RWCPre14PassLockV2.lockRelPath)
        guard FileManager.default.fileExists(atPath: lockURL.path) else {
            throw RWCCorpusEntryErrorV3.lockMissing
        }
        let lock = try RWCPre14PassLockV2.parse(data: try Data(contentsOf: lockURL))
        guard lock.lockVersion == RWCPre14PassLockV2.expectedVersion else {
            throw RWCCorpusEntryErrorV3.lockVersionUnsupported
        }
        guard lock.corpusEntryAuthorized else { throw RWCCorpusEntryErrorV3.entryNotAuthorized }

        // 2. git identities
        guard try commitExists(repoRoot, lock.candidateCommit) else {
            throw RWCCorpusEntryErrorV3.commitMissing(field: "candidate_commit")
        }
        guard try commitExists(repoRoot, lock.auditCommit) else {
            throw RWCCorpusEntryErrorV3.commitMissing(field: "audit_commit")
        }
        guard try commitExists(repoRoot, lock.methodologyAnchorCommit) else {
            throw RWCCorpusEntryErrorV3.commitMissing(field: "methodology_anchor_commit")
        }
        let tagObj = try git(repoRoot, ["rev-parse", "--verify", "--quiet",
                                        "refs/tags/" + lock.candidateTagName])
        guard tagObj.status == 0, !tagObj.out.isEmpty else { throw RWCCorpusEntryErrorV3.tagMissing }
        guard tagObj.out != lock.candidateCommit else { throw RWCCorpusEntryErrorV3.tagNotAnnotated }
        guard tagObj.out == lock.candidateTagObjectSHA else { throw RWCCorpusEntryErrorV3.tagObjectMismatch }
        let deref = try git(repoRoot, ["rev-parse", lock.candidateTagName + "^{commit}"])
        guard deref.status == 0, deref.out == lock.candidateCommit else {
            throw RWCCorpusEntryErrorV3.tagDereferenceMismatch
        }
        // A16-F14: audit topology — candidate is ancestor of the audit commit.
        let candToAudit = try git(repoRoot, ["merge-base", "--is-ancestor",
                                             lock.candidateCommit, lock.auditCommit])
        guard candToAudit.status == 0 else { throw RWCCorpusEntryErrorV3.candidateNotAncestorOfAudit }
        let anchorToCand = try git(repoRoot, ["merge-base", "--is-ancestor",
                                              lock.methodologyAnchorCommit, lock.candidateCommit])
        guard anchorToCand.status == 0 else { throw RWCCorpusEntryErrorV3.anchorNotAncestorOfCandidate }

        // 3. A16-F12/F13: the committed machine audit result IS the PASS authority.
        guard let auditBlob = try gitShowBlob(repoRoot, commit: lock.auditCommit,
                                              path: lock.auditResultPath) else {
            throw RWCCorpusEntryErrorV3.auditResultMissingInAuditCommit
        }
        guard sha256Hex(auditBlob) == lock.auditResultBlobSHA256 else {
            throw RWCCorpusEntryErrorV3.auditResultHashMismatch
        }
        let audit = try RWCPre14AuditResultV1.parse(data: auditBlob)
        guard audit.verdict == "PASS" else { throw RWCCorpusEntryErrorV3.auditVerdictNotPass(audit.verdict) }
        guard audit.criticalCount == 0, audit.highCount == 0, audit.mediumCount == 0 else {
            throw RWCCorpusEntryErrorV3.auditFindingsOpen(critical: audit.criticalCount,
                                                          high: audit.highCount, medium: audit.mediumCount)
        }
        if let decorative = lock.decorativeVerdict, decorative != audit.verdict {
            throw RWCCorpusEntryErrorV3.lockVerdictContradictsAuditResult
        }
        for (field, a, b) in [("candidate_commit", audit.candidateCommit, lock.candidateCommit),
                              ("candidate_tag_object_sha", audit.candidateTagObjectSHA, lock.candidateTagObjectSHA),
                              ("methodology_anchor_commit", audit.methodologyAnchorCommit, lock.methodologyAnchorCommit),
                              ("freeze_manifest_path", audit.freezeManifestPath, lock.freezeManifestPath),
                              ("freeze_manifest_sha256", audit.freezeManifestSHA256, lock.freezeManifestSHA256),
                              ("frozen_inventory_digest", audit.frozenInventoryDigest, lock.frozenInventoryDigest),
                              ("governing_control_plane_lock", audit.governingControlPlaneLock,
                               lock.governingControlPlaneLock)] where a != b {
            throw RWCCorpusEntryErrorV3.auditTargetMismatch(field: field)
        }

        // 4. A16-F16: canonical freeze manifest ONLY; hash three-way bound.
        guard lock.freezeManifestPath == canonicalFreezeManifestPath else {
            throw RWCCorpusEntryErrorV3.nonCanonicalFreezeManifestPath(lock.freezeManifestPath)
        }
        let manifestURL = repoRoot.appendingPathComponent(canonicalFreezeManifestPath)
        guard let manifestData = try? Data(contentsOf: manifestURL) else {
            throw RWCCorpusEntryErrorV3.freezeManifestMissing
        }
        guard sha256Hex(manifestData) == lock.freezeManifestSHA256 else {
            throw RWCCorpusEntryErrorV3.freezeManifestHashMismatch(stage: "live")
        }
        guard let m = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              let freezeVersion = m["freeze_version"] as? String,
              let manifestAnchor = m["methodology_anchor_commit"] as? String,
              let manifestGoverning = m["governing_control_plane_lock"] as? String,
              let manifestDigest = m["frozen_inventory_digest"] as? String,
              let artifacts = m["artifacts"] as? [[String: Any]],
              let rules = m["surface_rules"] as? [String: Any],
              let governedRoots = rules["governed_roots"] as? [String],
              let postAnchorAllowed = rules["post_anchor_allowed"] as? [String],
              let allowedPatterns = rules["post_audit_allowed_prefixes"] as? [String],
              let hashExempt = (rules["hash_exempt"] as? [String]).map(Set.init) else {
            throw RWCCorpusEntryErrorV3.freezeManifestMalformed("fields")
        }
        guard freezeVersion == "rwc-preregistration-freeze-v4" else {
            throw RWCCorpusEntryErrorV3.freezeVersionMismatch
        }
        // A16-F15: every binding cross-checked (lock == manifest == audit result == git).
        guard manifestAnchor == lock.methodologyAnchorCommit else { throw RWCCorpusEntryErrorV3.anchorMismatch }
        guard manifestGoverning == lock.governingControlPlaneLock else {
            throw RWCCorpusEntryErrorV3.governingLockMismatch(stage: "manifest")
        }
        let governingDeref = try git(repoRoot, ["rev-parse", governingTagName + "^{commit}"])
        guard governingDeref.status == 0, governingDeref.out == lock.governingControlPlaneLock else {
            throw RWCCorpusEntryErrorV3.governingLockMismatch(stage: "git-tag")
        }
        guard manifestDigest == lock.frozenInventoryDigest else {
            throw RWCCorpusEntryErrorV3.inventoryDigestMismatch(stage: "manifest")
        }

        // 5. live hash recomputation of every non-exempt artifact + digest recomputation
        var pathToSHA: [String: String] = [:]
        for a in artifacts {
            guard let path = a["path"] as? String, let sha = a["sha256"] as? String else {
                throw RWCCorpusEntryErrorV3.freezeManifestMalformed("artifact entry")
            }
            pathToSHA[path] = sha
            if hashExempt.contains(path) { continue }
            guard let data = try? Data(contentsOf: repoRoot.appendingPathComponent(path)) else {
                throw RWCCorpusEntryErrorV3.frozenFileMissing(path: path)
            }
            guard sha256Hex(data) == sha else { throw RWCCorpusEntryErrorV3.frozenFileDrift(path: path) }
        }
        guard inventoryDigest(pathToSHA) == lock.frozenInventoryDigest else {
            throw RWCCorpusEntryErrorV3.inventoryDigestMismatch(stage: "recomputed")
        }

        // 6. A16-F18/F19/F20: recursive, prefix-free, symlink-refusing SET EQUALITY —
        //    live surface AND candidate git tree, both against inventory ∪ allowances.
        func allowed(_ path: String) -> Bool {
            if pathToSHA[path] != nil { return true }
            if postAnchorAllowed.contains(path) { return true }
            let name = path.split(separator: "/").last.map(String.init) ?? path
            return allowedPatterns.contains { name.hasPrefix($0) }
        }
        for root in governedRoots {
            let live = try liveScan(repoRoot: repoRoot, root: root)
            let tree = try gitTreeScan(repoRoot: repoRoot, commit: lock.candidateCommit, root: root)
            let inventoryHere = Set(pathToSHA.keys.filter { $0.hasPrefix(root + "/") })
            let liveExtra = live.filter { !allowed($0) }.sorted()
            let liveMissing = inventoryHere.subtracting(live).sorted()
            guard liveExtra.isEmpty, liveMissing.isEmpty else {
                throw RWCCorpusEntryErrorV3.surfaceSetMismatch(stage: "live:\(root)",
                                                               extra: liveExtra, missing: liveMissing)
            }
            let treeExtra = tree.filter { !allowed($0) }.sorted()
            let treeMissing = inventoryHere.subtracting(tree).sorted()
            guard treeExtra.isEmpty, treeMissing.isEmpty else {
                throw RWCCorpusEntryErrorV3.surfaceSetMismatch(stage: "git-tree:\(root)",
                                                               extra: treeExtra, missing: treeMissing)
            }
        }

        // 7. A16-F17/§38: master manifest — field-level mutability + ALL FIVE zero counters.
        let masterURL = repoRoot.appendingPathComponent(masterManifestPath)
        guard let liveMasterData = try? Data(contentsOf: masterURL),
              let liveMaster = try? JSONSerialization.jsonObject(with: liveMasterData) as? [String: Any],
              let anchorMasterData = try gitShowBlob(repoRoot, commit: lock.methodologyAnchorCommit,
                                                     path: masterManifestPath),
              let anchorMaster = try? JSONSerialization.jsonObject(with: anchorMasterData) as? [String: Any] else {
            throw RWCCorpusEntryErrorV3.masterManifestMalformed
        }
        for key in Set(liveMaster.keys).union(anchorMaster.keys) where !masterMutableFields.contains(key) {
            let a = liveMaster[key].map { "\($0)" } ?? "<absent>"
            let b = anchorMaster[key].map { "\($0)" } ?? "<absent>"
            guard a == b else { throw RWCCorpusEntryErrorV3.masterImmutableFieldChanged(field: key) }
        }
        guard liveMaster["data_visibility"] as? Bool == false else {
            throw RWCCorpusEntryErrorV3.zeroDataViolated(field: "data_visibility")
        }
        for field in ["corpus_count", "annotator_count", "real_fit_count", "heldout_open_count"] {
            guard liveMaster[field] as? Int == 0 else {
                throw RWCCorpusEntryErrorV3.zeroDataViolated(field: field)
            }
        }

        return RWCVerifiedCorpusEntryV3(
            candidateCommit: lock.candidateCommit, candidateTagObjectSHA: lock.candidateTagObjectSHA,
            auditCommit: lock.auditCommit, auditResultBlobSHA256: lock.auditResultBlobSHA256,
            methodologyAnchorCommit: lock.methodologyAnchorCommit,
            freezeManifestSHA256: lock.freezeManifestSHA256,
            frozenInventoryDigest: lock.frozenInventoryDigest)
    }
}
#endif
