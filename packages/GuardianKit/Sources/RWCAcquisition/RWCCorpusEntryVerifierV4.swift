#if os(macOS)
import Foundation
import CryptoKit
import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC CORPUS ENTRY AUTHORITY V4 (R4; AUDIT17 remediation) — supersedes VerifierV3 BY RECORD.
// VerifierV3 stays byte-frozen SUPERSEDED_ENGINEERING_HISTORY (A17-F3/F4 pins).
//
// R4 LAWS added on top of the AUDIT17-verified-CLEAN V3 core (git-show committed-blob authority,
// candidate-ancestor-of-audit, three-way governing/freeze/anchor/digest/tag bindings, recursive
// symlink-refusing surface scan, five zero-data counters, field-level master mutability):
//   • A17-F4: the machine audit result path is a CANONICAL CONSTANT for this round
//     (RWCPre14AuditResultV2.canonicalPath = docs/audit/RWC_PRE14_R4_AUDIT_RESULT.json).
//     lock.auditResultPath MUST equal it; identical PASS bytes at ANY other path are refused.
//   • A17-F3: post-audit allowances are PATH-SCOPED OBJECTS {root, filename_prefix} — an
//     allowance applies ONLY to files under its exact root. NO allowance exists for production
//     source roots (Sources/GuardianCore, Sources/RWCAcquisition) or Package.swift; a basename
//     starting with AUDIT grants NOTHING outside the explicitly allowed auditor-evidence root.
//   • A17-F11/F12: audit-result schema V2 count laws — every count is a non-negative integer
//     (Bool/Double/string refused), baseline + fresh == total, verdict is a strict enum
//     {PASS, FIX_REQUIRED, BLOCKED}; PASS semantics additionally require 0/0/0 findings.
// ZERO-DATA: no PASS lock and no R4 audit-result instance exist in this repository; verification
// of the REAL repo fails closed with lockMissing until a lawful AUDIT18 PASS + closeout.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

public enum RWCCorpusEntryErrorV4: Error, Equatable, Sendable {
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
    case carried(RWCCorpusEntryErrorV3)   // V3-core refusals surfaced verbatim
}

/// Machine audit result SCHEMA V2 (A17-F4/F11/F12). Builder defines the schema; ONLY the
/// independent AUDIT18 auditor may create the instance, committed in the audit commit.
public struct RWCPre14AuditResultV2: Sendable {
    public static let expectedVersion = "rwc-pre14-audit-result-v2"
    /// THE canonical R4 instance path — the only path the verifier will ever read (A17-F4).
    public static let canonicalPath = "docs/audit/RWC_PRE14_R4_AUDIT_RESULT.json"
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

    public static func parse(data: Data) throws -> RWCPre14AuditResultV2 {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RWCCorpusEntryErrorV4.auditResultMalformed("not strict JSON")
        }
        func str(_ k: String) throws -> String {
            guard let v = o[k] as? String, !v.isEmpty else {
                throw RWCCorpusEntryErrorV4.auditResultMalformed("missing \(k)")
            }
            return v
        }
        /// Count law (A17-F11): a STRICT non-negative integer — NSNumber bool/double masquerade
        /// and string counts are refused.
        func count(_ k: String) throws -> Int {
            guard let raw = o[k] else { throw RWCCorpusEntryErrorV4.auditCountInvalid(field: k) }
            guard let n = raw as? NSNumber,
                  CFGetTypeID(n) != CFBooleanGetTypeID(),
                  CFNumberIsFloatType(n) == false,
                  n.intValue >= 0 else {
                throw RWCCorpusEntryErrorV4.auditCountInvalid(field: k)
            }
            return n.intValue
        }
        let r = RWCPre14AuditResultV2(
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
            throw RWCCorpusEntryErrorV4.auditResultMalformed("unsupported result_version")
        }
        guard allowedVerdicts.contains(r.verdict) else {
            throw RWCCorpusEntryErrorV4.auditResultMalformed("verdict not in enum")
        }
        // Count consistency law (A17-F12): the declared counting model is baseline + fresh == total.
        guard r.baselineCount + r.freshProbeCount == r.totalCount else {
            throw RWCCorpusEntryErrorV4.auditCountInconsistent(baseline: r.baselineCount,
                                                               fresh: r.freshProbeCount,
                                                               total: r.totalCount)
        }
        return r
    }
}

/// PASS-lock schema V3: identity bindings only (verdict remains non-authoritative decoration).
public struct RWCPre14PassLockV3: Sendable {
    public static let expectedVersion = "rwc-pre14-pass-lock-v3"
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
    public let decorativeVerdict: String?

    public static func parse(data: Data) throws -> RWCPre14PassLockV3 {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RWCCorpusEntryErrorV4.lockMalformed("not strict JSON")
        }
        func str(_ k: String) throws -> String {
            guard let v = o[k] as? String, !v.isEmpty else {
                throw RWCCorpusEntryErrorV4.lockMalformed("missing \(k)")
            }
            return v
        }
        guard let authorized = o["corpus_entry_authorized"] as? Bool else {
            throw RWCCorpusEntryErrorV4.lockMalformed("missing corpus_entry_authorized")
        }
        return RWCPre14PassLockV3(
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

/// Unforgeable V4 proof — fileprivate init; the ONLY mint path is a full verification.
public struct RWCVerifiedCorpusEntryV4: Sendable {
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

public enum RWCCorpusEntryVerifierV4 {
    public static let version = "rwc-corpus-entry-verifier-v4"
    public static let canonicalFreezeManifestPath =
        "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V5.yaml"
    public static let governingTagName = RWCCorpusEntryVerifierV3.governingTagName
    public static let masterMutableFields = RWCCorpusEntryVerifierV3.masterMutableFields
    static let masterManifestPath =
        "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml"

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    struct ScopedAllowance { let root: String; let filenamePrefix: String }

    /// PATH-SCOPED allowance law (A17-F3): a file is allowed ONLY when it sits under the exact
    /// allowance root AND its basename carries the prefix. Nothing is allowed by basename alone.
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

    /// THE authoritative verification V4.
    public static func verify(repoRoot: URL) throws -> RWCVerifiedCorpusEntryV4 {
        let lockURL = repoRoot.appendingPathComponent(RWCPre14PassLockV3.lockRelPath)
        guard FileManager.default.fileExists(atPath: lockURL.path) else {
            throw RWCCorpusEntryErrorV4.lockMissing
        }
        let lock = try RWCPre14PassLockV3.parse(data: try Data(contentsOf: lockURL))
        guard lock.lockVersion == RWCPre14PassLockV3.expectedVersion else {
            throw RWCCorpusEntryErrorV4.lockVersionUnsupported
        }
        guard lock.corpusEntryAuthorized else { throw RWCCorpusEntryErrorV4.entryNotAuthorized }

        // git identity facts (V3-core laws, carried verbatim)
        func carried(_ e: RWCCorpusEntryErrorV3) -> RWCCorpusEntryErrorV4 { .carried(e) }
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
        let deref = try RWCCorpusEntryVerifierV3.git(repoRoot,
            ["rev-parse", lock.candidateTagName + "^{commit}"])
        guard deref.status == 0, deref.out == lock.candidateCommit else {
            throw carried(.tagDereferenceMismatch)
        }
        let candToAudit = try RWCCorpusEntryVerifierV3.git(repoRoot,
            ["merge-base", "--is-ancestor", lock.candidateCommit, lock.auditCommit])
        guard candToAudit.status == 0 else { throw carried(.candidateNotAncestorOfAudit) }
        let anchorToCand = try RWCCorpusEntryVerifierV3.git(repoRoot,
            ["merge-base", "--is-ancestor", lock.methodologyAnchorCommit, lock.candidateCommit])
        guard anchorToCand.status == 0 else { throw carried(.anchorNotAncestorOfCandidate) }

        // A17-F4: CANONICAL audit-result path, committed-blob authority
        guard lock.auditResultPath == RWCPre14AuditResultV2.canonicalPath else {
            throw RWCCorpusEntryErrorV4.nonCanonicalAuditResultPath(lock.auditResultPath)
        }
        guard let auditBlob = try RWCCorpusEntryVerifierV3.gitShowBlob(
                repoRoot, commit: lock.auditCommit, path: lock.auditResultPath) else {
            throw RWCCorpusEntryErrorV4.auditResultMissingInAuditCommit
        }
        guard sha256Hex(auditBlob) == lock.auditResultBlobSHA256 else {
            throw RWCCorpusEntryErrorV4.auditResultHashMismatch
        }
        let audit = try RWCPre14AuditResultV2.parse(data: auditBlob)
        guard audit.verdict == "PASS" else {
            throw RWCCorpusEntryErrorV4.auditVerdictNotPass(audit.verdict)
        }
        guard audit.criticalCount == 0, audit.highCount == 0, audit.mediumCount == 0 else {
            throw RWCCorpusEntryErrorV4.auditFindingsOpen(critical: audit.criticalCount,
                                                          high: audit.highCount,
                                                          medium: audit.mediumCount)
        }
        if let decorative = lock.decorativeVerdict, decorative != audit.verdict {
            throw RWCCorpusEntryErrorV4.auditTargetMismatch(field: "decorative verdict")
        }
        for (field, a, b) in [("candidate_commit", audit.candidateCommit, lock.candidateCommit),
                              ("candidate_tag_object_sha", audit.candidateTagObjectSHA,
                               lock.candidateTagObjectSHA),
                              ("methodology_anchor_commit", audit.methodologyAnchorCommit,
                               lock.methodologyAnchorCommit),
                              ("freeze_manifest_path", audit.freezeManifestPath, lock.freezeManifestPath),
                              ("freeze_manifest_sha256", audit.freezeManifestSHA256,
                               lock.freezeManifestSHA256),
                              ("frozen_inventory_digest", audit.frozenInventoryDigest,
                               lock.frozenInventoryDigest),
                              ("governing_control_plane_lock", audit.governingControlPlaneLock,
                               lock.governingControlPlaneLock)] where a != b {
            throw RWCCorpusEntryErrorV4.auditTargetMismatch(field: field)
        }

        // canonical freeze V5 manifest only
        guard lock.freezeManifestPath == canonicalFreezeManifestPath else {
            throw carried(.nonCanonicalFreezeManifestPath(lock.freezeManifestPath))
        }
        let manifestURL = repoRoot.appendingPathComponent(canonicalFreezeManifestPath)
        guard let manifestData = try? Data(contentsOf: manifestURL) else {
            throw carried(.freezeManifestMissing)
        }
        guard sha256Hex(manifestData) == lock.freezeManifestSHA256 else {
            throw carried(.freezeManifestHashMismatch(stage: "live"))
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
        guard freezeVersion == "rwc-preregistration-freeze-v5" else {
            throw carried(.freezeVersionMismatch)
        }
        guard manifestAnchor == lock.methodologyAnchorCommit else { throw carried(.anchorMismatch) }
        guard manifestGoverning == lock.governingControlPlaneLock else {
            throw carried(.governingLockMismatch(stage: "manifest"))
        }
        let governingDeref = try RWCCorpusEntryVerifierV3.git(repoRoot,
            ["rev-parse", governingTagName + "^{commit}"])
        guard governingDeref.status == 0, governingDeref.out == lock.governingControlPlaneLock else {
            throw carried(.governingLockMismatch(stage: "git-tag"))
        }
        guard manifestDigest == lock.frozenInventoryDigest else {
            throw carried(.inventoryDigestMismatch(stage: "manifest"))
        }
        let allowances: [ScopedAllowance] = rawAllowances.compactMap { a in
            guard let root = a["root"] as? String, let prefix = a["filename_prefix"] as? String else {
                return nil
            }
            return ScopedAllowance(root: root, filenamePrefix: prefix)
        }
        guard allowances.count == rawAllowances.count else {
            throw carried(.freezeManifestMalformed("post_audit_allowances"))
        }

        // live hash recomputation + inventory digest
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

        // recursive, prefix-free, symlink-refusing SET EQUALITY with PATH-SCOPED allowances only
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
                    throw carried(.surfaceSetMismatch(stage: "\(stage):\(root)",
                                                      extra: extra, missing: missing))
                }
            }
        }

        // master manifest field-level law + ALL FIVE zero counters (V3-core, carried)
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

        return RWCVerifiedCorpusEntryV4(
            candidateCommit: lock.candidateCommit, candidateTagObjectSHA: lock.candidateTagObjectSHA,
            auditCommit: lock.auditCommit, auditResultBlobSHA256: lock.auditResultBlobSHA256,
            methodologyAnchorCommit: lock.methodologyAnchorCommit,
            freezeManifestSHA256: lock.freezeManifestSHA256,
            frozenInventoryDigest: lock.frozenInventoryDigest)
    }
}
#endif
