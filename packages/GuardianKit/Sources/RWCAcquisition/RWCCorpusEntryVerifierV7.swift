#if os(macOS)
import Foundation
import CryptoKit
import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC CORPUS ENTRY AUTHORITY V7 (LANE A V10 release-verifier transition) — supersedes VerifierV6 BY
// RECORD. VerifierV6 stays byte-frozen SUPERSEDED_ENGINEERING_HISTORY: it is pinned to the R7 result path
// (docs/audit/RWC_PRE14_R7_AUDIT_RESULT.json, schema V4) + manifest V8 + freeze-version
// rwc-preregistration-freeze-v8, and continues to validate the HISTORICAL V8-era AUDIT21 lock from the
// historical candidate (104dad4). V6 is NEVER rebound to V9/V10 code.
//
// WHY V7 EXISTS (mandate §3-§4): V9 landed the A21-F5 RunnerV5 fix + the governed onboarding engine, so the
// V8 manifest no longer describes the live tree — V6.verify(realRepo) correctly fails closed with
// frozenFileDrift (expected freeze-V8 invalidation). The historical V8 PASS must NOT be auto-rebound to the
// new code. V7 is the smallest real delta from V6 that lawfully binds the NEW V10 identity.
//
// IMPLEMENTED_UNVERIFIED: authored in a worktree. Main session compiles + runs the positive/negative suite
// (AUDIT21_V10_TransitionProbes) before this is a V10 audit candidate.
//
// V7 binds the V10 identity under schema V5 — the ONLY delta from V6 is three bound constants:
//   • canonical audit-result path  = docs/audit/RWC_PRE14_V10_AUDIT_RESULT.json  (schema V5 instance)
//   • canonical freeze manifest    = …RWC_PREREGISTRATION_FREEZE_MANIFEST_V10.yaml
//   • freeze_version               = rwc-preregistration-freeze-v10
// Everything else (git identity chain, tag-object + tag-name cross-checks, candidate-ancestry,
// candidate-freeze-blob binding A18-F5, recursive symlink-refusing surface set equality, master field-law
// + five zero counters, STRICT count laws + verdict/finding gates) is carried from V6/V5's V3-core plumbing
// VERBATIM. There is NO fallback to the V6/V5 verifiers, the V6/V8 manifests, or the R5/R6/R7 result paths.
//
// It REUSES the existing PASS-lock schema RWCPre14PassLockV4 (lock_version rwc-pre14-pass-lock-v4)
// UNCHANGED — the lock already carries every binding V7 needs; V10 identity is enforced through the VALUES
// V7 checks (result path, manifest path, freeze_version), not a new lock field. See
// docs/audit/AUDIT21_V10_TRANSITION_LOCK.md §5.
//
// IT CREATES NO PASS: verifying the real repo fails closed with lockMissing (no V10 PASS lock exists). The
// AUDIT19/AUDIT20 FIX_REQUIRED results, the V9 builder candidate (which has NO audit result), a different
// candidate's PASS, and any attempt to rebind the V8 PASS to V9/V10 code are permanently refused.
//
// ZERO-DATA: no V10 PASS lock, no V10 audit-result instance exists in this repository.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

public enum RWCCorpusEntryErrorV7: Error, Equatable, Sendable {
    case lockMissing
    case lockMalformed(String)
    case lockVersionUnsupported
    case entryNotAuthorized
    case nonCanonicalAuditResultPath(String)
    case auditResultMissingInAuditCommit
    case auditResultHashMismatch
    case auditResultMalformed(String)
    case auditVerdictNotPass(String)
    case auditFindingsOpen(critical: Int, high: Int, medium: Int)
    case auditCountInvalid(field: String)
    case auditCountInconsistent(baseline: Int, fresh: Int, total: Int)
    case auditTargetMismatch(field: String)
    case candidateFreezeBlobMissing
    case candidateFreezeBlobMismatch(stage: String)
    case tagNameMismatch(stage: String)
    case schemaVersionUnsupported(String)       // schema-V4-disguised-as-V5 etc.
    case freezeVersionMismatch                   // not rwc-preregistration-freeze-v10
    case carried(RWCCorpusEntryErrorV3)
}

/// Machine audit result SCHEMA V5 (V10). Carries schema V4's strict count laws verbatim; differs ONLY in
/// expectedVersion + the canonical V10 result path. Builder defines the schema; ONLY the independent
/// AUDIT22T auditor may create the instance (with a genuinely earned verdict).
public struct RWCPre14AuditResultV5: Sendable {
    public static let expectedVersion = "rwc-pre14-audit-result-v5"
    public static let canonicalPath = "docs/audit/RWC_PRE14_V10_AUDIT_RESULT.json"
    public static let allowedVerdicts: Set<String> = ["PASS", "FIX_REQUIRED", "BLOCKED"]

    public let resultVersion: String
    public let verdict: String
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

    public static func parse(data: Data) throws -> RWCPre14AuditResultV5 {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RWCCorpusEntryErrorV7.auditResultMalformed("not strict JSON")
        }
        func str(_ k: String) throws -> String {
            guard let v = o[k] as? String, !v.isEmpty else {
                throw RWCCorpusEntryErrorV7.auditResultMalformed("missing \(k)")
            }
            return v
        }
        func count(_ k: String) throws -> Int {
            guard let raw = o[k] else { throw RWCCorpusEntryErrorV7.auditCountInvalid(field: k) }
            guard let n = raw as? NSNumber,
                  CFGetTypeID(n) != CFBooleanGetTypeID(),
                  CFNumberIsFloatType(n) == false,
                  n.intValue >= 0 else {
                throw RWCCorpusEntryErrorV7.auditCountInvalid(field: k)
            }
            return n.intValue
        }
        let r = RWCPre14AuditResultV5(
            resultVersion: try str("result_version"), verdict: try str("verdict"),
            candidateCommit: try str("candidate_commit"), candidateTagName: try str("candidate_tag_name"),
            candidateTagObjectSHA: try str("candidate_tag_object_sha"),
            methodologyAnchorCommit: try str("methodology_anchor_commit"),
            freezeManifestPath: try str("freeze_manifest_path"),
            freezeManifestSHA256: try str("freeze_manifest_sha256"),
            frozenInventoryDigest: try str("frozen_inventory_digest"),
            governingControlPlaneLock: try str("governing_control_plane_lock"),
            auditProbeFamily: try str("audit_probe_family"),
            baselineCount: try count("baseline_count"), freshProbeCount: try count("fresh_probe_count"),
            totalCount: try count("total_count"), criticalCount: try count("critical_count"),
            highCount: try count("high_count"), mediumCount: try count("medium_count"),
            auditorDeclaration: try str("auditor_declaration"))
        guard r.resultVersion == expectedVersion else {
            throw RWCCorpusEntryErrorV7.schemaVersionUnsupported(r.resultVersion)
        }
        guard allowedVerdicts.contains(r.verdict) else {
            throw RWCCorpusEntryErrorV7.auditResultMalformed("verdict not in enum")
        }
        guard r.baselineCount + r.freshProbeCount == r.totalCount else {
            throw RWCCorpusEntryErrorV7.auditCountInconsistent(baseline: r.baselineCount,
                                                               fresh: r.freshProbeCount, total: r.totalCount)
        }
        return r
    }
}

/// Unforgeable V7 proof — fileprivate init; the ONLY mint path is a full verification.
public struct RWCVerifiedCorpusEntryV7: Sendable {
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

public enum RWCCorpusEntryVerifierV7 {
    public static let version = "rwc-corpus-entry-verifier-v7"
    public static let canonicalFreezeManifestPath =
        "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V10.yaml"
    public static let expectedFreezeVersion = "rwc-preregistration-freeze-v10"
    public static let governingTagName = RWCCorpusEntryVerifierV3.governingTagName
    public static let masterMutableFields = RWCCorpusEntryVerifierV3.masterMutableFields
    static let masterManifestPath =
        "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml"

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    struct ScopedAllowance { let root: String; let filenamePrefix: String }

    static func allowed(path: String, inventory: [String: String], postAnchorAllowed: [String],
                        allowances: [ScopedAllowance]) -> Bool {
        if inventory[path] != nil { return true }
        if postAnchorAllowed.contains(path) { return true }
        let name = path.split(separator: "/").last.map(String.init) ?? path
        for a in allowances where path.hasPrefix(a.root + "/") && name.hasPrefix(a.filenamePrefix) {
            return true
        }
        return false
    }

    /// THE authoritative V10 verification. Fails closed with .lockMissing on the real repo (no V10 PASS lock
    /// exists). Reuses the PASS-lock schema V4 shape (RWCPre14PassLockV4) but binds the V10 result path
    /// (schema V5) + V10 manifest + freeze-v10. NO fallback to V6/V5.
    public static func verify(repoRoot: URL) throws -> RWCVerifiedCorpusEntryV7 {
        let lockURL = repoRoot.appendingPathComponent(RWCPre14PassLockV4.lockRelPath)
        guard FileManager.default.fileExists(atPath: lockURL.path) else {
            throw RWCCorpusEntryErrorV7.lockMissing
        }
        let lock: RWCPre14PassLockV4
        do { lock = try RWCPre14PassLockV4.parse(data: try Data(contentsOf: lockURL)) }
        catch { throw RWCCorpusEntryErrorV7.lockMalformed("\(error)") }
        guard lock.lockVersion == RWCPre14PassLockV4.expectedVersion else {
            throw RWCCorpusEntryErrorV7.lockVersionUnsupported
        }
        guard lock.corpusEntryAuthorized else { throw RWCCorpusEntryErrorV7.entryNotAuthorized }

        func carried(_ e: RWCCorpusEntryErrorV3) -> RWCCorpusEntryErrorV7 { .carried(e) }
        guard try RWCCorpusEntryVerifierV3.commitExists(repoRoot, lock.candidateCommit) else {
            throw carried(.commitMissing(field: "candidate_commit"))
        }
        guard try RWCCorpusEntryVerifierV3.commitExists(repoRoot, lock.auditCommit) else {
            throw carried(.commitMissing(field: "audit_commit"))
        }
        guard try RWCCorpusEntryVerifierV3.commitExists(repoRoot, lock.methodologyAnchorCommit) else {
            throw carried(.commitMissing(field: "methodology_anchor_commit"))
        }
        let tagObj = try RWCCorpusEntryVerifierV3.git(repoRoot,
            ["rev-parse", "--verify", "--quiet", "refs/tags/" + lock.candidateTagName])
        guard tagObj.status == 0, !tagObj.out.isEmpty else { throw carried(.tagMissing) }
        guard tagObj.out != lock.candidateCommit else { throw carried(.tagNotAnnotated) }
        guard tagObj.out == lock.candidateTagObjectSHA else { throw carried(.tagObjectMismatch) }
        let deref = try RWCCorpusEntryVerifierV3.git(repoRoot, ["rev-parse", lock.candidateTagName + "^{commit}"])
        guard deref.status == 0, deref.out == lock.candidateCommit else { throw carried(.tagDereferenceMismatch) }
        let candToAudit = try RWCCorpusEntryVerifierV3.git(repoRoot,
            ["merge-base", "--is-ancestor", lock.candidateCommit, lock.auditCommit])
        guard candToAudit.status == 0 else { throw carried(.candidateNotAncestorOfAudit) }
        let anchorToCand = try RWCCorpusEntryVerifierV3.git(repoRoot,
            ["merge-base", "--is-ancestor", lock.methodologyAnchorCommit, lock.candidateCommit])
        guard anchorToCand.status == 0 else { throw carried(.anchorNotAncestorOfCandidate) }

        // CANONICAL V10 (schema V5) result path only — NOT R5/R6/R7.
        guard lock.auditResultPath == RWCPre14AuditResultV5.canonicalPath else {
            throw RWCCorpusEntryErrorV7.nonCanonicalAuditResultPath(lock.auditResultPath)
        }
        guard let auditBlob = try RWCCorpusEntryVerifierV3.gitShowBlob(
                repoRoot, commit: lock.auditCommit, path: lock.auditResultPath) else {
            throw RWCCorpusEntryErrorV7.auditResultMissingInAuditCommit
        }
        guard sha256Hex(auditBlob) == lock.auditResultBlobSHA256 else {
            throw RWCCorpusEntryErrorV7.auditResultHashMismatch
        }
        let audit = try RWCPre14AuditResultV5.parse(data: auditBlob)
        guard audit.verdict == "PASS" else { throw RWCCorpusEntryErrorV7.auditVerdictNotPass(audit.verdict) }
        guard audit.criticalCount == 0, audit.highCount == 0, audit.mediumCount == 0 else {
            throw RWCCorpusEntryErrorV7.auditFindingsOpen(critical: audit.criticalCount,
                                                          high: audit.highCount, medium: audit.mediumCount)
        }
        if let decorative = lock.decorativeVerdict, decorative != audit.verdict {
            throw RWCCorpusEntryErrorV7.auditTargetMismatch(field: "decorative verdict")
        }
        for (field, a, b) in [("candidate_commit", audit.candidateCommit, lock.candidateCommit),
                              ("candidate_tag_object_sha", audit.candidateTagObjectSHA, lock.candidateTagObjectSHA),
                              ("methodology_anchor_commit", audit.methodologyAnchorCommit, lock.methodologyAnchorCommit),
                              ("freeze_manifest_path", audit.freezeManifestPath, lock.freezeManifestPath),
                              ("freeze_manifest_sha256", audit.freezeManifestSHA256, lock.freezeManifestSHA256),
                              ("frozen_inventory_digest", audit.frozenInventoryDigest, lock.frozenInventoryDigest),
                              ("governing_control_plane_lock", audit.governingControlPlaneLock,
                               lock.governingControlPlaneLock)] where a != b {
            throw RWCCorpusEntryErrorV7.auditTargetMismatch(field: field)
        }
        guard audit.candidateTagName == lock.candidateTagName else {
            throw RWCCorpusEntryErrorV7.tagNameMismatch(stage: "result-vs-lock")
        }
        let derefByName = try RWCCorpusEntryVerifierV3.git(repoRoot, ["rev-parse", lock.candidateTagName + "^{commit}"])
        guard derefByName.status == 0, derefByName.out == lock.candidateCommit else {
            throw RWCCorpusEntryErrorV7.tagNameMismatch(stage: "name-dereference")
        }

        // canonical freeze V10 manifest only
        guard lock.freezeManifestPath == canonicalFreezeManifestPath else {
            throw carried(.nonCanonicalFreezeManifestPath(lock.freezeManifestPath))
        }
        let manifestURL = repoRoot.appendingPathComponent(canonicalFreezeManifestPath)
        guard let manifestData = try? Data(contentsOf: manifestURL) else { throw carried(.freezeManifestMissing) }
        let liveManifestSHA = sha256Hex(manifestData)
        guard liveManifestSHA == lock.freezeManifestSHA256 else {
            throw carried(.freezeManifestHashMismatch(stage: "live"))
        }
        // A18-F5 candidate freeze-blob binding
        guard let candidateBlob = try RWCCorpusEntryVerifierV3.gitShowBlob(
                repoRoot, commit: lock.candidateCommit, path: canonicalFreezeManifestPath) else {
            throw RWCCorpusEntryErrorV7.candidateFreezeBlobMissing
        }
        let candidateBlobSHA = sha256Hex(candidateBlob)
        guard candidateBlobSHA == liveManifestSHA else {
            throw RWCCorpusEntryErrorV7.candidateFreezeBlobMismatch(stage: "live-vs-candidate")
        }
        guard candidateBlobSHA == audit.freezeManifestSHA256 else {
            throw RWCCorpusEntryErrorV7.candidateFreezeBlobMismatch(stage: "candidate-vs-result")
        }
        guard candidateBlobSHA == lock.freezeManifestSHA256 else {
            throw RWCCorpusEntryErrorV7.candidateFreezeBlobMismatch(stage: "candidate-vs-lock")
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
              let rawAllowances = rules["post_audit_allowances"] as? [[String: Any]],
              let hashExempt = (rules["hash_exempt"] as? [String]).map(Set.init) else {
            throw carried(.freezeManifestMalformed("fields"))
        }
        guard freezeVersion == expectedFreezeVersion else { throw RWCCorpusEntryErrorV7.freezeVersionMismatch }
        guard manifestAnchor == lock.methodologyAnchorCommit else { throw carried(.anchorMismatch) }
        guard manifestGoverning == lock.governingControlPlaneLock else {
            throw carried(.governingLockMismatch(stage: "manifest"))
        }
        let governingDeref = try RWCCorpusEntryVerifierV3.git(repoRoot, ["rev-parse", governingTagName + "^{commit}"])
        guard governingDeref.status == 0, governingDeref.out == lock.governingControlPlaneLock else {
            throw carried(.governingLockMismatch(stage: "git-tag"))
        }
        guard manifestDigest == lock.frozenInventoryDigest else {
            throw carried(.inventoryDigestMismatch(stage: "manifest"))
        }
        let allowances: [ScopedAllowance] = rawAllowances.compactMap { a in
            guard let root = a["root"] as? String, let prefix = a["filename_prefix"] as? String else { return nil }
            return ScopedAllowance(root: root, filenamePrefix: prefix)
        }
        guard allowances.count == rawAllowances.count else {
            throw carried(.freezeManifestMalformed("post_audit_allowances"))
        }

        var pathToSHA: [String: String] = [:]
        for a in artifacts {
            guard let path = a["path"] as? String, let sha = a["sha256"] as? String else {
                throw carried(.freezeManifestMalformed("artifact entry"))
            }
            pathToSHA[path] = sha
            if hashExempt.contains(path) { continue }
            guard let data = try? Data(contentsOf: repoRoot.appendingPathComponent(path)) else {
                throw carried(.frozenFileMissing(path: path))
            }
            guard sha256Hex(data) == sha else { throw carried(.frozenFileDrift(path: path)) }
        }
        guard RWCCorpusEntryVerifierV3.inventoryDigest(pathToSHA) == lock.frozenInventoryDigest else {
            throw carried(.inventoryDigestMismatch(stage: "recomputed"))
        }

        for root in governedRoots {
            let live: Set<String>
            do { live = try RWCCorpusEntryVerifierV3.liveScan(repoRoot: repoRoot, root: root) }
            catch let e as RWCCorpusEntryErrorV3 { throw carried(e) }
            let tree = try RWCCorpusEntryVerifierV3.gitTreeScan(repoRoot: repoRoot,
                                                                commit: lock.candidateCommit, root: root)
            let inventoryHere = Set(pathToSHA.keys.filter { $0.hasPrefix(root + "/") })
            for (stage, found) in [("live", live), ("git-tree", tree)] {
                let extra = found.filter {
                    !allowed(path: $0, inventory: pathToSHA, postAnchorAllowed: postAnchorAllowed,
                             allowances: allowances)
                }.sorted()
                let missing = inventoryHere.subtracting(found).sorted()
                guard extra.isEmpty, missing.isEmpty else {
                    throw carried(.surfaceSetMismatch(stage: "\(stage):\(root)", extra: extra, missing: missing))
                }
            }
        }

        let masterURL = repoRoot.appendingPathComponent(masterManifestPath)
        guard let liveMasterData = try? Data(contentsOf: masterURL),
              let liveMaster = try? JSONSerialization.jsonObject(with: liveMasterData) as? [String: Any],
              let anchorMasterData = try RWCCorpusEntryVerifierV3.gitShowBlob(
                  repoRoot, commit: lock.methodologyAnchorCommit, path: masterManifestPath),
              let anchorMaster = try? JSONSerialization.jsonObject(with: anchorMasterData) as? [String: Any]
        else { throw carried(.masterManifestMalformed) }
        for key in Set(liveMaster.keys).union(anchorMaster.keys) where !masterMutableFields.contains(key) {
            let a = liveMaster[key].map { "\($0)" } ?? "<absent>"
            let b = anchorMaster[key].map { "\($0)" } ?? "<absent>"
            guard a == b else { throw carried(.masterImmutableFieldChanged(field: key)) }
        }
        guard liveMaster["data_visibility"] as? Bool == false else {
            throw carried(.zeroDataViolated(field: "data_visibility"))
        }
        for field in ["corpus_count", "annotator_count", "real_fit_count", "heldout_open_count"] {
            guard liveMaster[field] as? Int == 0 else { throw carried(.zeroDataViolated(field: field)) }
        }

        return RWCVerifiedCorpusEntryV7(
            candidateCommit: lock.candidateCommit, candidateTagObjectSHA: lock.candidateTagObjectSHA,
            auditCommit: lock.auditCommit, auditResultBlobSHA256: lock.auditResultBlobSHA256,
            methodologyAnchorCommit: lock.methodologyAnchorCommit,
            freezeManifestSHA256: lock.freezeManifestSHA256,
            frozenInventoryDigest: lock.frozenInventoryDigest)
    }
}
#endif
