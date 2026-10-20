import Foundation
import CryptoKit
import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC CORPUS ENTRY AUTHORITY V2 (A15-F12 closure) — supersedes RWCCorpusEntryGuardV1 BY RECORD.
//
// AUDIT15 proved RWCCorpusEntryGuardV1 is a policy function over CALLER-SUPPLIED state: a forged
// pre14Verdict="PASS" string + matching fake dictionaries entered. V2 is an AUTHORITATIVE,
// offline, deterministic verifier: it obtains every fact FROM THE REPOSITORY ITSELF (git object
// store + live file hashing + full surface scan) and never accepts caller booleans as facts.
//
// TWO-STAGE DESIGN (R2 mandate §35):
//   Stage 1 (THIS code, builder R2): the PASS-LOCK SCHEMA + the verifier. NO PASS LOCK EXISTS in
//     R2 — RWCPreregistrationR2Tests pins the lock file's ABSENCE and pins that verification of
//     the real repository FAILS with .lockMissing.
//   Stage 2 (ONLY after an independent PRE-14 R2 audit PASS): a closeout session creates the real
//     lock at docs/audit/RWC_PRE14_PASS_LOCK.yaml with corpus_entry_authorized=true.
//
// FORGERY RESISTANCE:
//   * A caller cannot mint VerifiedCorpusEntryV1 — its init is fileprivate; the ONLY mint path is
//     a full successful repository verification.
//   * A forged lock file fails on git facts (tag OBJECT sha, dereferenced commit, audit commit,
//     ancestor law) and on live hash recomputation.
//   * Surface expansion is caught by SET EQUALITY: every governed file found by the scan must be
//     in the frozen inventory (or the explicit post-anchor allowance list) AND vice versa — new,
//     removed and renamed methodology files are all drift (A15-F12 extra-file attack).
//
// The schema is normatively documented in RWC_PRE14_PASS_LOCK_SCHEMA.yaml (frozen v3 artifact).
// ═══════════════════════════════════════════════════════════════════════════════════════════════

enum RWCCorpusEntryErrorV2: Error, Equatable {
    case lockMissing
    case lockMalformed(String)
    case lockVersionUnsupported
    case notCreatedByCloseout
    case entryNotAuthorized
    case verdictNotPass(String)
    case gitUnavailable(String)
    case commitMissing(field: String)
    case tagMissing
    case tagNotAnnotated
    case tagObjectMismatch(expected: String, found: String)
    case tagDereferenceMismatch(expected: String, found: String)
    case anchorNotAncestorOfCandidate
    case freezeManifestMissing
    case freezeManifestHashMismatch
    case freezeManifestMalformed(String)
    case frozenFileMissing(path: String)
    case frozenFileDrift(path: String)
    case surfaceSetMismatch(extra: [String], missing: [String])
    case auditReportHashMismatch
    case masterManifestMalformed
    case dataAlreadyVisible
    case corpusCountNonZero
}

/// The §36 PASS-lock schema. `corpus_entry_authorized` may be true ONLY in a lock produced by a
/// closeout session AFTER an independent PRE-14 PASS. Builder sessions never create this file.
struct RWCPre14PassLockV1 {
    static let expectedVersion = "rwc-pre14-pass-lock-v1"
    static let lockRelPath = "docs/audit/RWC_PRE14_PASS_LOCK.yaml"

    let lockVersion: String
    let verdict: String
    let candidateCommit: String
    let candidateTagName: String
    let candidateTagObjectSHA: String
    let auditCommit: String
    let auditReportPath: String
    let auditReportSHA256: String
    let freezeVersion: String
    let freezeManifestPath: String
    let freezeManifestSHA256: String
    let methodologyAnchorCommit: String
    let frozenInventoryDigest: String
    let governingControlPlaneLock: String
    let createdByCloseout: Bool
    let corpusEntryAuthorized: Bool

    static func parse(data: Data) throws -> RWCPre14PassLockV1 {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RWCCorpusEntryErrorV2.lockMalformed("not strict JSON")
        }
        func str(_ k: String) throws -> String {
            guard let v = obj[k] as? String, !v.isEmpty else {
                throw RWCCorpusEntryErrorV2.lockMalformed("missing field \(k)")
            }
            return v
        }
        func bool(_ k: String) throws -> Bool {
            guard let v = obj[k] as? Bool else { throw RWCCorpusEntryErrorV2.lockMalformed("missing field \(k)") }
            return v
        }
        return RWCPre14PassLockV1(
            lockVersion: try str("lock_version"), verdict: try str("verdict"),
            candidateCommit: try str("candidate_commit"), candidateTagName: try str("candidate_tag_name"),
            candidateTagObjectSHA: try str("candidate_tag_object_sha"), auditCommit: try str("audit_commit"),
            auditReportPath: try str("audit_report_path"), auditReportSHA256: try str("audit_report_sha256"),
            freezeVersion: try str("freeze_version"), freezeManifestPath: try str("freeze_manifest_path"),
            freezeManifestSHA256: try str("freeze_manifest_sha256"),
            methodologyAnchorCommit: try str("methodology_anchor_commit"),
            frozenInventoryDigest: try str("frozen_inventory_digest"),
            governingControlPlaneLock: try str("governing_control_plane_lock"),
            createdByCloseout: try bool("created_by_closeout"),
            corpusEntryAuthorized: try bool("corpus_entry_authorized"))
    }
}

/// Unforgeable proof of a successful repository verification: fileprivate init — the ONLY mint
/// path is RWCCorpusEntryVerifierV2.verify(repoRoot:). A caller-constructed struct cannot exist.
struct RWCVerifiedCorpusEntryV1 {
    let candidateCommit: String
    let candidateTagObjectSHA: String
    let auditCommit: String
    let methodologyAnchorCommit: String
    let freezeManifestSHA256: String
    let frozenInventoryDigest: String
    fileprivate init(candidateCommit: String, candidateTagObjectSHA: String, auditCommit: String,
                     methodologyAnchorCommit: String, freezeManifestSHA256: String,
                     frozenInventoryDigest: String) {
        self.candidateCommit = candidateCommit; self.candidateTagObjectSHA = candidateTagObjectSHA
        self.auditCommit = auditCommit; self.methodologyAnchorCommit = methodologyAnchorCommit
        self.freezeManifestSHA256 = freezeManifestSHA256; self.frozenInventoryDigest = frozenInventoryDigest
    }
}

enum RWCCorpusEntryVerifierV2 {
    static let version = "rwc-corpus-entry-verifier-v2"

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
        do { try p.run() } catch { throw RWCCorpusEntryErrorV2.gitUnavailable("\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }

    static func commitExists(_ repoRoot: URL, _ sha: String) throws -> Bool {
        let r = try git(repoRoot, ["rev-parse", "--verify", "--quiet", sha + "^{commit}"])
        return r.status == 0 && r.out == sha
    }

    /// Full-surface scan per the manifest's surface rules: every file under the governed doc root,
    /// plus files in governed code roots whose FILENAME begins with a governed prefix.
    static func scanGovernedSurface(repoRoot: URL, docRoot: String,
                                    codeScan: [(root: String, prefixes: [String])]) -> Set<String> {
        var found = Set<String>()
        let fm = FileManager.default
        let docURL = repoRoot.appendingPathComponent(docRoot).resolvingSymlinksInPath()
        if let e = fm.enumerator(at: docURL, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let f as URL in e where (try? f.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                let resolved = f.resolvingSymlinksInPath().path
                guard resolved.hasPrefix(docURL.path + "/") else { continue }
                found.insert(docRoot + "/" + resolved.dropFirst(docURL.path.count + 1))
            }
        }
        for (root, prefixes) in codeScan {
            let rootURL = repoRoot.appendingPathComponent(root)
            if let names = try? fm.contentsOfDirectory(atPath: rootURL.path) {
                for name in names where prefixes.contains(where: { name.hasPrefix($0) }) {
                    found.insert(root + "/" + name)
                }
            }
        }
        return found
    }

    /// Deterministic digest of the frozen inventory (sorted "path:sha256" lines).
    static func inventoryDigest(_ pathToSHA: [String: String]) -> String {
        let lines = pathToSHA.keys.sorted().map { "\($0):\(pathToSHA[$0]!)" }.joined(separator: "\n")
        return sha256Hex(Data(lines.utf8))
    }

    /// THE authoritative verification. Every clause gathers truth from the repository.
    static func verify(repoRoot: URL) throws -> RWCVerifiedCorpusEntryV1 {
        let lockURL = repoRoot.appendingPathComponent(RWCPre14PassLockV1.lockRelPath)
        guard FileManager.default.fileExists(atPath: lockURL.path) else {
            throw RWCCorpusEntryErrorV2.lockMissing
        }
        let lock = try RWCPre14PassLockV1.parse(data: try Data(contentsOf: lockURL))
        guard lock.lockVersion == RWCPre14PassLockV1.expectedVersion else {
            throw RWCCorpusEntryErrorV2.lockVersionUnsupported
        }
        guard lock.createdByCloseout else { throw RWCCorpusEntryErrorV2.notCreatedByCloseout }
        guard lock.corpusEntryAuthorized else { throw RWCCorpusEntryErrorV2.entryNotAuthorized }
        guard lock.verdict == "PASS" else { throw RWCCorpusEntryErrorV2.verdictNotPass(lock.verdict) }

        // git facts
        guard try commitExists(repoRoot, lock.candidateCommit) else {
            throw RWCCorpusEntryErrorV2.commitMissing(field: "candidate_commit")
        }
        guard try commitExists(repoRoot, lock.auditCommit) else {
            throw RWCCorpusEntryErrorV2.commitMissing(field: "audit_commit")
        }
        guard try commitExists(repoRoot, lock.methodologyAnchorCommit) else {
            throw RWCCorpusEntryErrorV2.commitMissing(field: "methodology_anchor_commit")
        }
        let tagObj = try git(repoRoot, ["rev-parse", "--verify", "--quiet", "refs/tags/" + lock.candidateTagName])
        guard tagObj.status == 0, !tagObj.out.isEmpty else { throw RWCCorpusEntryErrorV2.tagMissing }
        guard tagObj.out != lock.candidateCommit else { throw RWCCorpusEntryErrorV2.tagNotAnnotated }
        guard tagObj.out == lock.candidateTagObjectSHA else {
            throw RWCCorpusEntryErrorV2.tagObjectMismatch(expected: lock.candidateTagObjectSHA, found: tagObj.out)
        }
        let deref = try git(repoRoot, ["rev-parse", lock.candidateTagName + "^{commit}"])
        guard deref.status == 0, deref.out == lock.candidateCommit else {
            throw RWCCorpusEntryErrorV2.tagDereferenceMismatch(expected: lock.candidateCommit, found: deref.out)
        }
        let ancestor = try git(repoRoot, ["merge-base", "--is-ancestor",
                                          lock.methodologyAnchorCommit, lock.candidateCommit])
        guard ancestor.status == 0 else { throw RWCCorpusEntryErrorV2.anchorNotAncestorOfCandidate }

        // freeze manifest identity + content
        let manifestURL = repoRoot.appendingPathComponent(lock.freezeManifestPath)
        guard let manifestData = try? Data(contentsOf: manifestURL) else {
            throw RWCCorpusEntryErrorV2.freezeManifestMissing
        }
        guard sha256Hex(manifestData) == lock.freezeManifestSHA256 else {
            throw RWCCorpusEntryErrorV2.freezeManifestHashMismatch
        }
        guard let manifest = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              let artifacts = manifest["artifacts"] as? [[String: Any]],
              let rules = manifest["surface_rules"] as? [String: Any],
              let docRoot = rules["doc_root"] as? String,
              let codeScanRaw = rules["code_scan"] as? [[String: Any]],
              let postAnchorAllowed = rules["post_anchor_allowed"] as? [String] else {
            throw RWCCorpusEntryErrorV2.freezeManifestMalformed("artifacts/surface_rules")
        }
        let hashExempt = Set((rules["hash_exempt"] as? [String]) ?? [])

        // live hash recomputation of EVERY listed artifact
        var pathToSHA: [String: String] = [:]
        for a in artifacts {
            guard let path = a["path"] as? String, let sha = a["sha256"] as? String else {
                throw RWCCorpusEntryErrorV2.freezeManifestMalformed("artifact entry")
            }
            pathToSHA[path] = sha
            if hashExempt.contains(path) { continue }
            guard let data = try? Data(contentsOf: repoRoot.appendingPathComponent(path)) else {
                throw RWCCorpusEntryErrorV2.frozenFileMissing(path: path)
            }
            guard sha256Hex(data) == sha else { throw RWCCorpusEntryErrorV2.frozenFileDrift(path: path) }
        }
        guard inventoryDigest(pathToSHA) == lock.frozenInventoryDigest else {
            throw RWCCorpusEntryErrorV2.freezeManifestMalformed("frozen_inventory_digest mismatch")
        }

        // SET-EQUALITY surface law (expansion/removal/rename detection)
        let codeScan: [(String, [String])] = codeScanRaw.compactMap { entry in
            guard let root = entry["root"] as? String, let prefixes = entry["prefixes"] as? [String] else { return nil }
            return (root, prefixes)
        }
        let scanned = scanGovernedSurface(repoRoot: repoRoot, docRoot: docRoot, codeScan: codeScan)
        let allowed = Set(pathToSHA.keys).union(postAnchorAllowed)
        let extra = scanned.subtracting(allowed).sorted()
        // inventory entries that live inside the governed surface MUST be found by the scan
        let governedInventory = Set(pathToSHA.keys).filter { path in
            if path.hasPrefix(docRoot + "/") { return true }
            return codeScan.contains { root, prefixes in
                path.hasPrefix(root + "/") && prefixes.contains { String(path.dropFirst(root.count + 1)).hasPrefix($0) }
            }
        }
        let missing = governedInventory.subtracting(scanned).sorted()
        guard extra.isEmpty, missing.isEmpty else {
            throw RWCCorpusEntryErrorV2.surfaceSetMismatch(extra: extra, missing: missing)
        }

        // audit report identity
        guard let reportData = try? Data(contentsOf: repoRoot.appendingPathComponent(lock.auditReportPath)),
              sha256Hex(reportData) == lock.auditReportSHA256 else {
            throw RWCCorpusEntryErrorV2.auditReportHashMismatch
        }

        // zero-visibility transition law
        let masterURL = repoRoot.appendingPathComponent(
            "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml")
        guard let masterData = try? Data(contentsOf: masterURL),
              let master = try? JSONSerialization.jsonObject(with: masterData) as? [String: Any],
              let visibility = master["data_visibility"] as? Bool,
              let corpusCount = master["corpus_count"] as? Int else {
            throw RWCCorpusEntryErrorV2.masterManifestMalformed
        }
        guard visibility == false else { throw RWCCorpusEntryErrorV2.dataAlreadyVisible }
        guard corpusCount == 0 else { throw RWCCorpusEntryErrorV2.corpusCountNonZero }

        return RWCVerifiedCorpusEntryV1(
            candidateCommit: lock.candidateCommit, candidateTagObjectSHA: lock.candidateTagObjectSHA,
            auditCommit: lock.auditCommit, methodologyAnchorCommit: lock.methodologyAnchorCommit,
            freezeManifestSHA256: lock.freezeManifestSHA256,
            frozenInventoryDigest: lock.frozenInventoryDigest)
    }

    /// FUTURE acquisition boundary (corpus phase): requires the UNFORGEABLE proof type PLUS the
    /// per-asset rights gate — one gate can never substitute for the other (mandate §41).
    static func requireAcquisitionStart(proof: RWCVerifiedCorpusEntryV1,
                                        store: RWCAssetRightsLedgerStoreV2,
                                        assetID: String, use: RWCUseV1,
                                        clock: RWCRightsClockV1) throws {
        try store.requireEligible(assetID: assetID, use: use, clock: clock)
        _ = proof // the typed proof is the global gate; its existence implies full verification
    }
}
