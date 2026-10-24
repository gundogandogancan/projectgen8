import Foundation
import CryptoKit

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC RIGHTS REVIEW TRUST-ROOT ARCHITECTURE V6 (R6; AUDIT19 remediation A19-F1/F2/F3).
//
// SUPERSESSION NOT MUTATION. The R5 surfaces in RWCRightsV5.swift (RWCReviewerTrustRootLoaderV1,
// RWCReviewerRegistryVerifierV1, RWCRightsReviewAuthorityV3) and the R5 durable store
// RWCAssetRightsLedgerStoreV3 stay BYTE-FROZEN SUPERSEDED_ENGINEERING_HISTORY — the R5 builder
// tests pin their behavior as history. R6 installs NEW surfaces that close the three authority
// findings AUDIT19 proved reachable, and moves the lawful corpus-entry path onto them:
//
//   A19-F2 (HIGH) — PUBLIC trust-root self-mint. R5's RWCReviewerTrustRootLoaderV1.mint(fromJSON:)
//   was PUBLIC: any ordinary GuardianCore consumer minted a verified root from attacker JSON, and
//   loadProduction(repoRoot:) with a caller-chosen directory yielded a verified production root
//   ("path != trust"). R6 FIX (STRUCTURAL): RWCReviewerTrustRootLoaderV2 exposes NO public mint.
//   The ONLY production entry is loadProduction(repoRoot:), which requires an ONBOARDING CAPABILITY
//   that only the governed onboarding path can mint (its init is `internal`, unreachable from an
//   ordinary consumer module). No capability + no governed file ⇒ fail closed .noOperationalRoot.
//   The synthetic test factory stays `internal` (test target only). An ordinary external SwiftPM
//   consumer (no @testable) can reach NEITHER a mint nor the synthetic factory (proven by the /tmp
//   ordinary-consumer package). The verified root type RWCVerifiedReviewerTrustRootV2 has a
//   fileprivate init — possession is proof, and it can be produced ONLY inside this file.
//
//   A19-F3 (HIGH) — registry replay / revoked-reviewer resurrection. R5's
//   RWCReviewerRegistryVerifierV1.verify accepted ANY standalone root-signed document when
//   previousVerified == nil (so revision > 1 with an arbitrary previousRegistryDigest verified, and
//   replaying an old rev1 resurrected a revoked reviewer). R6 FIX: a GOVERNED CURRENT-REGISTRY HEAD
//   WITNESS (RWCReviewerRegistryCurrentnessStoreV1 — durable, append-only, monotonic,
//   rollback-refusing, flock single-writer, reusing the proven ledger-store pattern) names the
//   active (rootID, revision, documentDigest). RWCReviewerRegistryVerifierV2.verifyCurrent binds the
//   document to that witness: a document whose digest != the current head is refused; revision > 1
//   with previousVerified == nil is refused; a stale/rolled-back/replayed revision is refused.
//   HONEST THREAT MODEL (local disk): the witness file is user-writable; this prevents accidental
//   and old-signed-file replay and enforces monotonic advance, but it is NOT an absolute offline
//   rollback proof against an adversary with write access to the witness directory. That residual is
//   documented in the R6 security design; absolute currentness requires an external monotonic
//   authority (future onboarding).
//
//   A19-F1 (CRITICAL) — reconcile acquisition backdoor + forged V1-token register. R5's
//   reconcileV3 promoted any quarantine whose caller-constructed metadata + receipt + a rights
//   record (registered via the PUBLIC no-crypto RWCRightsReviewAuthorityV1.verify V1 token) agreed —
//   all three forgeable, no rooted proof. R6 FIX lives in RWCAssetRightsLedgerStoreV4 +
//   RWCCorpusAcquisitionRunnerV4 (RWCCorpusAcquisitionRunnerV4.swift): (a) register REQUIRES an
//   unforgeable RWCVerifiedRightsGrantV6 (minted only through the V2 root → current registry →
//   authority V6 chain) — the public V1 token can no longer register into the R6 store; (b) the
//   authorized acquisition path writes an UNFORGEABLE, LEDGER-RESIDENT ACQUISITION AUTHORIZATION
//   EVENT inside the flock-protected, append-only, hash-chained ledger AT AUTHORIZATION TIME, bound
//   to (sessionID, assetID, contentHash, grantID, reviewerID, registryHead, corpus-entry proof) —
//   and reconcileV4 promotes ONLY a session that matches a ledger-resident authorization record.
//   Caller-constructed metadata/receipts can never substitute, because writing the authorization
//   event requires the full verified V6 grant + V5 corpus-entry proof at write time (both
//   fileprivate-init proof types an attacker cannot construct).
//
// ZERO-DATA: synthetic fixtures only; no production root, no real reviewer/grant/media.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

// MARK: - Trust-root V2 typed errors (R6 / A19-F2)

public enum RWCReviewerTrustErrorV2: Error, Equatable, Sendable {
    case noOperationalRoot                       // production root / onboarding capability absent — FAIL CLOSED
    case rootMalformed(String)
    case rootNotActive(status: String)
    case malformedRootID
    case malformedRootKey
    // registry document (R6 currentness)
    case registryMalformed(String)
    case registryRootMismatch
    case registryVersionUnsupported
    case registrySignatureInvalid
    case registryRevisionNotMonotonic(expected: Int, found: Int)
    case registryPreviousDigestMismatch
    case malformedReviewerID
    case malformedReviewerKey
    case duplicateReviewerInDocument(reviewerID: String)
    case malformedReviewerScope(String)
    case malformedReviewerStatus(String)
    // A19-F3 currentness
    case noCurrentRegistryHead                   // currentness witness empty — FAIL CLOSED
    case registryNotCurrent(stage: String)       // document digest != current head
    case revisionWithoutAncestry(revision: Int)  // revision > 1 with previousVerified == nil
    case currentnessStale(currentRevision: Int, presentedRevision: Int)
    case currentnessRootMismatch
}

// MARK: - Governed reviewer trust root V2 (A19-F2)

/// UNFORGEABLE verified trust root V2 — fileprivate init; mintable ONLY inside this file, and ONLY
/// by the capability-gated production loader or the internal synthetic test factory. There is NO
/// public mint surface (the A19-F2 fix). Possession proves "this Ed25519 public key is the governed,
/// ACTIVE reviewer trust root under the R6 bootstrap".
public struct RWCVerifiedReviewerTrustRootV2: Sendable {
    public let rootID: String
    public let publicKey: Curve25519.Signing.PublicKey
    public let publicKeyRawHex: String
    public let governanceRecordID: String
    fileprivate init(rootID: String, publicKey: Curve25519.Signing.PublicKey,
                     publicKeyRawHex: String, governanceRecordID: String) {
        self.rootID = rootID; self.publicKey = publicKey
        self.publicKeyRawHex = publicKeyRawHex; self.governanceRecordID = governanceRecordID
    }
}

/// GOVERNED ONBOARDING CAPABILITY (A19-F2). Its init is `internal`: it can be constructed ONLY by a
/// `@testable` test target (synthetic) OR by a future in-module governed onboarding path — NEVER by
/// an ordinary external consumer of GuardianCore. Possession is the structural precondition for the
/// production mint. In R6 no governed instance exists, so production stays fail-closed.
public struct RWCReviewerRootOnboardingCapabilityV1: Sendable {
    /// The onboarding record this capability was granted under (opaque, audit pointer only).
    public let onboardingRecordID: String
    internal init(onboardingRecordID: String) { self.onboardingRecordID = onboardingRecordID }
}

public enum RWCReviewerTrustRootLoaderV2 {
    public static let version = "rwc-reviewer-trust-root-loader-v2"
    public static let canonicalInstancePath = "docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json"

    /// PRODUCTION loader — FAILS CLOSED. Requires a governed onboarding CAPABILITY (unreachable by an
    /// ordinary consumer) AND the canonical governed file. In R6 neither exists on the lawful path, so
    /// every production call throws .noOperationalRoot. A caller-chosen `repoRoot` is NOT trust: even
    /// with an attacker-authored file at the canonical path, no capability can be supplied by an
    /// ordinary consumer, so no verified root is minted (the A19-F2 "path != trust" closure).
    public static func loadProduction(repoRoot: URL) throws -> RWCVerifiedReviewerTrustRootV2 {
        // No governed onboarding capability exists in R6 — structurally fail closed BEFORE any file
        // read, so a caller-chosen directory can never determine trust.
        throw RWCReviewerTrustErrorV2.noOperationalRoot
    }

    /// GOVERNED onboarding mint — `internal`. Reachable ONLY with an onboarding capability (whose init
    /// is internal) + the governed JSON bytes. This is the ONLY mint path, and it is unreachable from
    /// an ordinary consumer module. Tests drive it with a synthetic capability + synthetic JSON.
    internal static func mint(fromJSON data: Data,
                              capability: RWCReviewerRootOnboardingCapabilityV1
    ) throws -> RWCVerifiedReviewerTrustRootV2 {
        _ = capability   // possession is the structural precondition (A19-F2)
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RWCReviewerTrustErrorV2.rootMalformed("not strict JSON")
        }
        func str(_ k: String) throws -> String {
            guard let v = o[k] as? String, !v.isEmpty else {
                throw RWCReviewerTrustErrorV2.rootMalformed("missing \(k)")
            }
            return v
        }
        let rootID = try str("root_id")
        let keyHex = try str("public_key_raw_hex")
        let algorithm = try str("algorithm")
        let governanceRecordID = try str("governance_record_id")
        let statusRaw = try str("status")
        _ = try RWCDateV3.parse(try str("activation_date"), field: "activation_date")
        guard RWCRightsReviewAuthorityV1.isToken(rootID, prefix: "rwc-root-") else {
            throw RWCReviewerTrustErrorV2.malformedRootID
        }
        guard algorithm == "ed25519" else { throw RWCReviewerTrustErrorV2.rootMalformed("algorithm") }
        guard statusRaw == "ACTIVE" else { throw RWCReviewerTrustErrorV2.rootNotActive(status: statusRaw) }
        guard RWCTrustHex.isHex(keyHex, length: 64), let keyData = RWCTrustHex.hexToData(keyHex),
              let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else {
            throw RWCReviewerTrustErrorV2.malformedRootKey
        }
        return RWCVerifiedReviewerTrustRootV2(rootID: rootID, publicKey: pub,
                                              publicKeyRawHex: keyHex,
                                              governanceRecordID: governanceRecordID)
    }

    /// TEST-ONLY synthetic factory — ACCESS-CONTROLLED (`internal`). Only a @testable import can
    /// reach it; an ordinary consumer cannot mint a trust-root proof from thin air. Returns the
    /// verified-root proof + its ephemeral private key (never persisted).
    internal static func makeSyntheticTestRoot(
        rootID: String = "rwc-root-synthetic01",
        governanceRecordID: String = "rwc-gov-synthetic01",
        privateKey: Curve25519.Signing.PrivateKey = Curve25519.Signing.PrivateKey()
    ) -> (root: RWCVerifiedReviewerTrustRootV2, privateKey: Curve25519.Signing.PrivateKey) {
        let keyHex = privateKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let root = RWCVerifiedReviewerTrustRootV2(rootID: rootID, publicKey: privateKey.publicKey,
                                                  publicKeyRawHex: keyHex,
                                                  governanceRecordID: governanceRecordID)
        return (root, privateKey)
    }

    /// TEST-ONLY synthetic onboarding capability, so the test target can exercise the governed mint.
    internal static func makeSyntheticOnboardingCapability(
        onboardingRecordID: String = "rwc-onboard-synthetic01"
    ) -> RWCReviewerRootOnboardingCapabilityV1 {
        RWCReviewerRootOnboardingCapabilityV1(onboardingRecordID: onboardingRecordID)
    }
}

// MARK: - A19-F3: governed current-registry head witness (durable, monotonic, rollback-refusing)

public enum RWCRegistryCurrentnessErrorV1: Error, Equatable, Sendable {
    case directoryExists
    case witnessMissing
    case witnessMalformed
    case lockedByAnotherWriter
    case ioFailure(String)
    case rootMismatch(expected: String, found: String)
    case notMonotonic(current: Int, presented: Int)
    case previousDigestMismatch
}

/// A durable, single-writer, append-only, hash-chained CURRENT-REGISTRY HEAD witness. Reuses the
/// proven RWCAssetRightsLedgerStoreV3 durability pattern (flock single-writer for life; atomic
/// temp+rename witness; SHA-256-chained journal; crash roll-forward). It names the ACTIVE
/// (rootID, revision, documentDigest). Advancing the head is monotonic: a new entry must carry
/// revision == current+1 and previousDocumentDigest == current digest, or it is refused. There is no
/// rewind API — a rolled-back or replayed registry can never become current.
public final class RWCReviewerRegistryCurrentnessStoreV1 {
    public static let version = "rwc-reviewer-registry-currentness-store-v1"
    static let journalName = "registry-currentness-v1.jsonl"
    static let witnessName = "registry-currentness-head-v1.json"
    static let lockName = "registry-currentness-v1.lock"

    public struct HeadV1: Equatable, Sendable {
        public let rootID: String
        public let revision: Int
        public let documentDigest: String
    }

    public struct EntryV1: Equatable, Sendable {
        public let seq: Int
        public let previousDigest: String
        public let rootID: String
        public let revision: Int
        public let documentDigest: String
        public let previousDocumentDigest: String
        public let recordedDate: String
        public let chainDigest: String
    }

    public let directory: URL
    public private(set) var entries: [EntryV1] = []
    private var lockFD: Int32 = -1

    private var journalURL: URL { directory.appendingPathComponent(Self.journalName) }
    private var witnessURL: URL { directory.appendingPathComponent(Self.witnessName) }
    private var lockURL: URL { directory.appendingPathComponent(Self.lockName) }

    public static let genesisDigest =
        SHA256.hash(data: Data("GEN8-RWC-REGISTRY-CURRENTNESS-V1-GENESIS".utf8))
            .map { String(format: "%02x", $0) }.joined()

    public var currentHead: HeadV1? {
        guard let last = entries.last else { return nil }
        return HeadV1(rootID: last.rootID, revision: last.revision, documentDigest: last.documentDigest)
    }
    public var headChainDigest: String { entries.last?.chainDigest ?? Self.genesisDigest }

    private init(directory: URL) { self.directory = directory }
    deinit { if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD) } }
    public func closeStore() { if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD); lockFD = -1 } }

    private static func sha256Hex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func acquireWriterLock() throws {
        let fd = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { throw RWCRegistryCurrentnessErrorV1.ioFailure("open lock failed") }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd); throw RWCRegistryCurrentnessErrorV1.lockedByAnotherWriter
        }
        lockFD = fd
    }

    static func entryChainDigest(previous: String, rootID: String, revision: Int,
                                 documentDigest: String, previousDocumentDigest: String,
                                 recordedDate: String, seq: Int) -> String {
        var out = Data()
        for field in ["rwc-registry-currentness-v1", String(seq), previous, rootID, String(revision),
                      documentDigest, previousDocumentDigest, recordedDate] {
            let bytes = Data(field.utf8)
            var len = UInt32(bytes.count).bigEndian
            withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
            out.append(bytes)
        }
        return SHA256.hash(data: out).map { String(format: "%02x", $0) }.joined()
    }

    static func journalLine(_ e: EntryV1) -> String {
        "{\"v\":\"rwc-registry-currentness-v1\",\"seq\":\(e.seq),\"prev\":\"\(esc(e.previousDigest))\"," +
        "\"root\":\"\(esc(e.rootID))\",\"rev\":\(e.revision),\"doc\":\"\(esc(e.documentDigest))\"," +
        "\"prevDoc\":\"\(esc(e.previousDocumentDigest))\",\"rec\":\"\(esc(e.recordedDate))\"," +
        "\"digest\":\"\(esc(e.chainDigest))\"}\n"
    }

    private func writeWitness() throws {
        let head = currentHead
        let json = "{\"v\":\"\(Self.version)\",\"count\":\(entries.count)," +
            "\"root\":\"\(Self.esc(head?.rootID ?? ""))\",\"rev\":\(head?.revision ?? 0)," +
            "\"doc\":\"\(Self.esc(head?.documentDigest ?? ""))\"," +
            "\"head\":\"\(headChainDigest)\"}\n"
        let tmp = directory.appendingPathComponent(Self.witnessName + ".tmp")
        do {
            try Data(json.utf8).write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: witnessURL.path) {
                _ = try FileManager.default.replaceItemAt(witnessURL, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: witnessURL)
            }
        } catch { throw RWCRegistryCurrentnessErrorV1.ioFailure("witness write: \(error)") }
    }

    public static func create(directory: URL) throws -> RWCReviewerRegistryCurrentnessStoreV1 {
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent(witnessName).path) {
            throw RWCRegistryCurrentnessErrorV1.directoryExists
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = RWCReviewerRegistryCurrentnessStoreV1(directory: directory)
        try store.acquireWriterLock()
        guard FileManager.default.createFile(atPath: store.journalURL.path, contents: nil) else {
            throw RWCRegistryCurrentnessErrorV1.ioFailure("journal create failed")
        }
        try store.writeWitness()
        return store
    }

    public static func openExisting(directory: URL) throws -> RWCReviewerRegistryCurrentnessStoreV1 {
        let store = RWCReviewerRegistryCurrentnessStoreV1(directory: directory)
        guard FileManager.default.fileExists(atPath: store.witnessURL.path) else {
            throw RWCRegistryCurrentnessErrorV1.witnessMissing
        }
        try store.acquireWriterLock()
        guard let raw = try? String(contentsOf: store.journalURL, encoding: .utf8) else {
            throw RWCRegistryCurrentnessErrorV1.ioFailure("journal read failed")
        }
        var parsed: [EntryV1] = []
        var prev = genesisDigest
        var prevDoc = genesisDigest
        var lastRev = 0
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        for (i, line) in lines.enumerated() {
            guard let o = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  o["v"] as? String == "rwc-registry-currentness-v1",
                  let seq = o["seq"] as? Int, let p = o["prev"] as? String,
                  let root = o["root"] as? String, let rev = o["rev"] as? Int,
                  let doc = o["doc"] as? String, let prevD = o["prevDoc"] as? String,
                  let rec = o["rec"] as? String, let digest = o["digest"] as? String else {
                throw RWCRegistryCurrentnessErrorV1.witnessMalformed
            }
            guard seq == i, p == prev, prevD == prevDoc, rev == lastRev + 1 else {
                throw RWCRegistryCurrentnessErrorV1.witnessMalformed
            }
            let rebuilt = entryChainDigest(previous: p, rootID: root, revision: rev, documentDigest: doc,
                                           previousDocumentDigest: prevD, recordedDate: rec, seq: seq)
            guard rebuilt == digest else { throw RWCRegistryCurrentnessErrorV1.witnessMalformed }
            parsed.append(EntryV1(seq: seq, previousDigest: p, rootID: root, revision: rev,
                                  documentDigest: doc, previousDocumentDigest: prevD,
                                  recordedDate: rec, chainDigest: digest))
            prev = digest; prevDoc = doc; lastRev = rev
        }
        store.entries = parsed
        return store
    }

    /// Advance the current head. MONOTONIC + rollback-refusing: for revision 1 the previousDocument
    /// digest must be genesis; for revision n > 1 it must equal the CURRENT head digest and revision
    /// must be exactly current+1; the rootID must match the current head's root (root rotation is a
    /// deliberate, separate governed event, not modeled here — a different root is refused). There is
    /// no rewind.
    public func advance(rootID: String, revision: Int, documentDigest: String,
                        recordedDate: String) throws {
        if let head = currentHead {
            guard rootID == head.rootID else {
                throw RWCRegistryCurrentnessErrorV1.rootMismatch(expected: head.rootID, found: rootID)
            }
            guard revision == head.revision + 1 else {
                throw RWCRegistryCurrentnessErrorV1.notMonotonic(current: head.revision, presented: revision)
            }
        } else {
            guard revision == 1 else {
                throw RWCRegistryCurrentnessErrorV1.notMonotonic(current: 0, presented: revision)
            }
        }
        let prevDoc = currentHead?.documentDigest ?? Self.genesisDigest
        let seq = entries.count
        let chain = Self.entryChainDigest(previous: headChainDigest, rootID: rootID, revision: revision,
                                          documentDigest: documentDigest, previousDocumentDigest: prevDoc,
                                          recordedDate: recordedDate, seq: seq)
        let e = EntryV1(seq: seq, previousDigest: headChainDigest, rootID: rootID, revision: revision,
                        documentDigest: documentDigest, previousDocumentDigest: prevDoc,
                        recordedDate: recordedDate, chainDigest: chain)
        guard let handle = try? FileHandle(forWritingTo: journalURL) else {
            throw RWCRegistryCurrentnessErrorV1.ioFailure("journal open failed")
        }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(Self.journalLine(e).utf8))
            try handle.synchronize()
        } catch { throw RWCRegistryCurrentnessErrorV1.ioFailure("journal append: \(error)") }
        entries.append(e)
        try writeWitness()
    }
}

// MARK: - Reviewer registry verifier V2 (A19-F3: current-head bound)

/// UNFORGEABLE verified registry V2 — fileprivate init; the ONLY mint path is
/// RWCReviewerRegistryVerifierV2.verifyCurrent (root signature + chain laws + CURRENT-HEAD binding).
public struct RWCVerifiedReviewerRegistryV2: Sendable {
    public let rootID: String
    public let registryRevision: Int
    public let documentDigest: String
    private let reviewers: [String: RWCReviewerRegistryEntryV1]
    fileprivate init(rootID: String, registryRevision: Int, documentDigest: String,
                     reviewers: [String: RWCReviewerRegistryEntryV1]) {
        self.rootID = rootID; self.registryRevision = registryRevision
        self.documentDigest = documentDigest; self.reviewers = reviewers
    }
    public func reviewer(_ id: String) -> RWCReviewerRegistryEntryV1? { reviewers[id] }
    public var reviewerCount: Int { reviewers.count }
}

public enum RWCReviewerRegistryVerifierV2 {
    public static let version = "rwc-reviewer-registry-verifier-v2"

    /// THE R6 registry authority boundary (A19-F3). Beyond the R5 structural laws (root signature,
    /// per-entry grammar, duplicate refusal, monotonic chain when previousVerified is supplied), this
    /// REQUIRES the document to be the governed CURRENT head:
    ///   • revision > 1 with previousVerified == nil is REFUSED (.revisionWithoutAncestry) — the exact
    ///     A19-F3 "previousVerified:nil skips the chain law" hole;
    ///   • the document digest MUST equal the currentness head digest (.registryNotCurrent) — a stale,
    ///     rolled-back or replayed revision is refused even though its root signature is valid;
    ///   • the currentness head rootID MUST match the trust root (.currentnessRootMismatch);
    ///   • an empty currentness witness fails closed (.noCurrentRegistryHead).
    public static func verifyCurrent(document d: RWCReviewerRegistryDocumentV2,
                                     trustRoot: RWCVerifiedReviewerTrustRootV2,
                                     currentness: RWCReviewerRegistryCurrentnessStoreV1,
                                     previousVerified: RWCVerifiedReviewerRegistryV2? = nil
    ) throws -> RWCVerifiedReviewerRegistryV2 {
        guard d.registryVersion == RWCReviewerRegistryDocumentV2.schemaVersion else {
            throw RWCReviewerTrustErrorV2.registryVersionUnsupported
        }
        guard d.rootID == trustRoot.rootID else { throw RWCReviewerTrustErrorV2.registryRootMismatch }
        guard d.registryRevision >= 1 else {
            throw RWCReviewerTrustErrorV2.registryMalformed("revision < 1")
        }
        // ROOT signature over the canonical payload.
        guard let sig = RWCTrustHex.hexToData(d.signatureHex), sig.count == 64,
              trustRoot.publicKey.isValidSignature(sig, for: d.canonicalPayloadBytes) else {
            throw RWCReviewerTrustErrorV2.registrySignatureInvalid
        }
        // A19-F3 ancestry law: revision > 1 may NOT present without a verified predecessor.
        if let prev = previousVerified {
            guard d.registryRevision == prev.registryRevision + 1 else {
                throw RWCReviewerTrustErrorV2.registryRevisionNotMonotonic(
                    expected: prev.registryRevision + 1, found: d.registryRevision)
            }
            guard d.previousRegistryDigest == prev.documentDigest else {
                throw RWCReviewerTrustErrorV2.registryPreviousDigestMismatch
            }
        } else {
            guard d.registryRevision == 1 else {
                throw RWCReviewerTrustErrorV2.revisionWithoutAncestry(revision: d.registryRevision)
            }
            guard d.previousRegistryDigest == RWCReviewerRegistryDocumentV2.genesisPreviousDigest else {
                throw RWCReviewerTrustErrorV2.registryPreviousDigestMismatch
            }
        }
        // A19-F3 CURRENT-HEAD binding: the document MUST be the governed current registry.
        guard let head = currentness.currentHead else {
            throw RWCReviewerTrustErrorV2.noCurrentRegistryHead
        }
        guard head.rootID == trustRoot.rootID else {
            throw RWCReviewerTrustErrorV2.currentnessRootMismatch
        }
        guard head.documentDigest == d.documentDigest else {
            throw RWCReviewerTrustErrorV2.registryNotCurrent(stage: "digest")
        }
        guard head.revision == d.registryRevision else {
            throw RWCReviewerTrustErrorV2.currentnessStale(currentRevision: head.revision,
                                                           presentedRevision: d.registryRevision)
        }
        // per-entry grammar + duplicate refusal (A18-F1 carried).
        var lookup: [String: RWCReviewerRegistryEntryV1] = [:]
        for e in d.reviewers {
            guard RWCRightsReviewAuthorityV1.isToken(e.reviewerID, prefix: "rwc-reviewer-") else {
                throw RWCReviewerTrustErrorV2.malformedReviewerID
            }
            guard RWCTrustHex.isHex(e.publicKeyRawHex, length: 64),
                  RWCTrustHex.hexToData(e.publicKeyRawHex) != nil else {
                throw RWCReviewerTrustErrorV2.malformedReviewerKey
            }
            guard ["ACTIVE", "REVOKED", "SUSPENDED"].contains(e.status) else {
                throw RWCReviewerTrustErrorV2.malformedReviewerStatus(e.status)
            }
            guard RWCReviewerScopeV1(rawValue: e.scope) != nil else {
                throw RWCReviewerTrustErrorV2.malformedReviewerScope(e.scope)
            }
            guard e.revision >= 1 else {
                throw RWCReviewerTrustErrorV2.registryMalformed("entry revision < 1")
            }
            if let exp = e.validUntil {
                guard exp >= e.validFrom else {
                    throw RWCReviewerTrustErrorV2.registryMalformed("validUntil < validFrom")
                }
            }
            guard lookup[e.reviewerID] == nil else {
                throw RWCReviewerTrustErrorV2.duplicateReviewerInDocument(reviewerID: e.reviewerID)
            }
            lookup[e.reviewerID] = e
        }
        return RWCVerifiedReviewerRegistryV2(rootID: d.rootID, registryRevision: d.registryRevision,
                                             documentDigest: d.documentDigest, reviewers: lookup)
    }
}

// MARK: - Review authority V6 (A19-F1/F2/F3: rooted, current-registry-bound verified grant)

/// UNFORGEABLE verified grant V6 — fileprivate init; the ONLY mint path is
/// RWCRightsReviewAuthorityV6.verify (signature + CURRENT VERIFIED-registry V2 authority + scope ==
/// .corpus). This is the grant type the R6 store/runner require; the public no-crypto V1 token and
/// the V5-rooted V3 grant can NOT substitute (different, fileprivate-init type).
public struct RWCVerifiedRightsGrantV6: Sendable {
    public let grant: RWCLegalGrantIdentityV1
    public let reviewRecordID: String
    public let reviewerID: String
    public let sourceAuthorization: RWCSourceAuthorizationV1
    public let registryDocumentDigest: String
    public let rootID: String
    fileprivate init(grant: RWCLegalGrantIdentityV1, reviewRecordID: String, reviewerID: String,
                     sourceAuthorization: RWCSourceAuthorizationV1, registryDocumentDigest: String,
                     rootID: String) {
        self.grant = grant; self.reviewRecordID = reviewRecordID; self.reviewerID = reviewerID
        self.sourceAuthorization = sourceAuthorization
        self.registryDocumentDigest = registryDocumentDigest; self.rootID = rootID
    }
}

public enum RWCRightsReviewAuthorityV6 {
    public static let version = "rwc-rights-review-authority-v6"

    /// THE V6 authority boundary. Identical review-binding laws to V3, but the reviewer is looked up
    /// in the CURRENT verified registry V2 (A19-F3), itself rooted in the capability-gated trust root
    /// V2 (A19-F2). Scope MUST be `.corpus` (A18-F2 carried).
    public static func verify(signedReview r: RWCSignedRightsReviewV1,
                              grant: RWCLegalGrantIdentityV1,
                              verifiedRegistry: RWCVerifiedReviewerRegistryV2
    ) throws -> RWCVerifiedRightsGrantV6 {
        try RWCRightsReviewAuthorityV1.validateGrant(grant)
        guard RWCRightsReviewAuthorityV1.isToken(r.reviewerID, prefix: "rwc-reviewer-") else {
            throw RWCRightsAuthorityErrorV3.malformedReviewerID
        }
        guard let reviewer = verifiedRegistry.reviewer(r.reviewerID) else {
            throw RWCRightsAuthorityErrorV3.reviewerNotInVerifiedRegistry
        }
        guard reviewer.status == "ACTIVE" else {
            throw RWCRightsAuthorityErrorV3.reviewerNotActive(status: reviewer.status)
        }
        guard reviewer.role == RWCReviewerRegistryDocumentV2.requiredRole else {
            throw RWCRightsAuthorityErrorV3.reviewerRoleUnauthorized
        }
        guard reviewer.scope == RWCReviewerScopeV1.corpus.rawValue else {
            throw RWCRightsAuthorityErrorV3.reviewerScopeUnauthorized(scope: reviewer.scope)
        }
        guard r.reviewDate >= reviewer.validFrom,
              reviewer.validUntil.map({ r.reviewDate <= $0 }) ?? true else {
            throw RWCRightsAuthorityErrorV3.reviewerOutsideValidity
        }
        guard RWCTrustHex.isHex(reviewer.publicKeyRawHex, length: 64),
              let keyData = RWCTrustHex.hexToData(reviewer.publicKeyRawHex),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else {
            throw RWCRightsAuthorityErrorV3.malformedPublicKey
        }
        guard let signature = RWCTrustHex.hexToData(r.signatureHex), signature.count == 64,
              publicKey.isValidSignature(signature, for: r.canonicalPayloadBytes) else {
            throw RWCRightsAuthorityErrorV3.signatureInvalid
        }
        guard r.decision == "APPROVED" else { throw RWCRightsAuthorityErrorV3.decisionNotApproved }
        for (field, a, b) in [("grantID", r.grantID, grant.grantID),
                              ("evidenceDigest", r.evidenceDigest, grant.evidenceDigest),
                              ("rightsHolder", r.rightsHolder, grant.rightsHolder),
                              ("reviewRecordID", r.reviewRecordID, grant.reviewRecordID),
                              ("effectiveDate", r.effectiveDate.isoString, grant.effectiveDate.isoString),
                              ("expiryDate", r.expiryDate?.isoString ?? "NONE",
                               grant.expiryDate?.isoString ?? "NONE")] where a != b {
            throw RWCRightsAuthorityErrorV3.payloadFieldMismatch(field: field)
        }
        guard r.grantRevision == grant.grantRevision else {
            throw RWCRightsAuthorityErrorV3.payloadFieldMismatch(field: "grantRevision")
        }
        guard r.allowedUse == grant.allowedUse, r.prohibitedUse == grant.prohibitedUse else {
            throw RWCRightsAuthorityErrorV3.payloadFieldMismatch(field: "use lists")
        }
        return RWCVerifiedRightsGrantV6(grant: grant, reviewRecordID: r.reviewRecordID,
                                        reviewerID: r.reviewerID,
                                        sourceAuthorization: r.sourceAuthorization,
                                        registryDocumentDigest: verifiedRegistry.documentDigest,
                                        rootID: verifiedRegistry.rootID)
    }
}

// MARK: - Pre-acquisition authorization V3 (R6: V6-grant input; A18-F10 manifest law carried)

/// UNFORGEABLE pre-acquisition proof V3 — fileprivate init; minted ONLY by RWCPreAcquisitionEvaluatorV3
/// after ALL pre-fetch laws against a V6 (rooted, current-registry-bound) grant. Same bound fields as
/// V2; the only delta is the V6-grant input.
public struct RWCPreAcquisitionAuthorizationV3: Sendable {
    public let assetID: String
    public let sourceReference: String
    public let intendedUse: RWCUseV1
    public let sessionID: String
    public let grantID: String
    public let grantRevision: Int
    public let reviewRecordID: String
    public let reviewerID: String
    public let owner: String
    public let sourceClass: RWCSourceClassV1
    public let transactionDate: RWCDateV3
    public let trustedExpectedChecksum: String?
    fileprivate init(request: RWCAcquisitionRequestV1, grant: RWCVerifiedRightsGrantV6,
                     transactionDate: RWCDateV3) {
        self.assetID = request.assetID; self.sourceReference = request.sourceReference
        self.intendedUse = request.intendedUse; self.sessionID = request.sessionID
        self.grantID = grant.grant.grantID; self.grantRevision = grant.grant.grantRevision
        self.reviewRecordID = grant.reviewRecordID; self.reviewerID = grant.reviewerID
        self.owner = request.owner; self.sourceClass = request.sourceClass
        self.transactionDate = transactionDate
        self.trustedExpectedChecksum = request.trustedExpectedChecksum
    }
}

public enum RWCPreAcquisitionEvaluatorV3 {
    public static let version = "rwc-preacquisition-evaluator-v3"

    /// Same pre-fetch laws as V2 (source eligibility, grammar, source binding via the A18-F10
    /// canonical manifest law, intended-use, expiry, owner, trusted-checksum shape) but takes the V6
    /// rooted grant. Reuses the internal V2 membership helper (same module).
    public static func authorize(request: RWCAcquisitionRequestV1,
                                 verifiedGrant: RWCVerifiedRightsGrantV6,
                                 transactionDate: RWCDateV3) throws -> RWCPreAcquisitionAuthorizationV3 {
        let g = verifiedGrant.grant
        if let e = RWCAssetIdentityV1.validateAssetID(request.assetID) {
            throw RWCRightsErrorV3.invalidAssetID("\(e)")
        }
        try RWCAcquisitionSessionIDV1.validate(request.sessionID)
        guard request.sourceClass.eligible else {
            throw RWCRightsAuthorityErrorV2.ineligibleSourceClass(request.sourceClass)
        }
        guard RWCRightsReviewAuthorityV1.isToken(request.sourceReference, prefix: "rwc-source-ref-") else {
            throw RWCRightsErrorV3.invalidPointer(field: "sourceReference")
        }
        guard try RWCPreAcquisitionEvaluatorV3.sourceCovered(verifiedGrant.sourceAuthorization,
                                                             request: request) else {
            throw RWCRightsAuthorityErrorV2.sourceNotAuthorized
        }
        guard !g.allowedUse.isEmpty else { throw RWCRightsAuthorityErrorV2.allowedUseEmpty }
        let useToken = request.intendedUse == .training ? "training" : "evaluation"
        guard g.allowedUse.contains(useToken), !g.prohibitedUse.contains(useToken) else {
            throw RWCRightsAuthorityErrorV2.intendedUseNotAllowed(use: useToken)
        }
        guard transactionDate >= g.effectiveDate else { throw RWCRightsAuthorityErrorV2.grantNotEffective }
        if let exp = g.expiryDate, transactionDate > exp { throw RWCRightsAuthorityErrorV2.grantExpired }
        guard !request.owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RWCRightsAuthorityErrorV2.recordPreconditionFailed(reason: "owner")
        }
        if let checksum = request.trustedExpectedChecksum {
            guard RWCRightsReviewAuthorityV1.isLowercaseHex64(checksum) else {
                throw RWCRightsAuthorityErrorV2.recordPreconditionFailed(reason: "trustedExpectedChecksum")
            }
        }
        return RWCPreAcquisitionAuthorizationV3(request: request, grant: verifiedGrant,
                                                transactionDate: transactionDate)
    }

    static func sourceCovered(_ authorization: RWCSourceAuthorizationV1,
                              request: RWCAcquisitionRequestV1) throws -> Bool {
        switch authorization {
        case .exactSource(let s):
            return s == request.sourceReference
        case .sourceManifest(let digest):
            guard let sources = request.manifestSources else { return false }
            let canonical = try RWCSourceManifestLawV2.canonicalManifestDigest(sources: sources)
            guard canonical == digest else { return false }
            return sources.contains(request.sourceReference)
        }
    }
}
