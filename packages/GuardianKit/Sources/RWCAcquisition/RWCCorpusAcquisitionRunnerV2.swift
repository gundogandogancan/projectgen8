#if os(macOS)
import Foundation
import CryptoKit
import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC CORPUS ACQUISITION RUNNER V2 (R4; AUDIT17 remediation) — supersedes RunnerV1 BY RECORD.
// RunnerV1 stays byte-frozen SUPERSEDED_ENGINEERING_HISTORY (A17-F2/F5/F6/F7/F8/F9 pins).
//
// FIRST-ASSET ORDERING LAW V2 (mandate §55; enforced by control flow AND types):
//   1  global corpus-entry proof        — RWCVerifiedCorpusEntryV4 parameter (unforgeable type)
//   2  session ID validate + RESERVE    — grammar law; duplicate session = typed refusal; path
//                                         containment double-checked (A17-F6)
//   3-9 signed review / registry / source authorization / intended use / source class / owner /
//       dates — ALL inside RWCPreAcquisitionEvaluatorV1 (A17-F2/F5/F10): verified SIGNED grant V2
//       (authorized reviewer registry + Ed25519) is a parameter type; evaluator checks everything
//       else at the SINGLE transactionDate (A17-F9: clock consulted exactly ONCE, stage 0)
//   10 immutable pre-acquisition PROOF   — RWCPreAcquisitionAuthorizationV1 (fileprivate-minted);
//                                          binds the exact request; no TOCTOU substitution
//   11 ONLY NOW the raw acquirer runs    — spy law: fetchCount == 0 on EVERY earlier refusal
//   12 bytes → EPHEMERAL QUARANTINE      — never the corpus store
//   13 content SHA-256 computed AFTER fetch (A17-F8: no pre-known hash required; optional trusted
//       source checksum compared only if supplied)
//   14 FINAL rights record constructed from the COMPUTED hash
//   15 durable rights commit (store V3 journal+witness; V1-token ABI bridge — see note below)
//   16 corpus promotion (only after successful rights commit)
//   17 immutable receipt V2 (adds intendedUse + transactionDate + session + reviewer identity)
//   18 cleanup / state-machine finalize
//
// TRANSACTION STATE MACHINE (A17-F7; persisted in integrity-protected session metadata):
//   AUTHORIZED → FETCHING → QUARANTINED → RIGHTS_COMMITTED → PROMOTED (metadata+dir removed on
//   COMPLETED) | FAILED_CLEANED (quarantine destroyed). Crash leaves metadata whose state drives
//   deterministic reconciliation — identity-bound by SESSION + ASSET + rights state, NEVER by
//   content hash alone; each ACTIVE asset processed at most once; revoked assets are NEVER
//   promoted (quarantine destroyed); orphans destroyed. Hash verifies BYTES, not ownership.
//
// V1-TOKEN ABI BRIDGE (recorded design decision): the frozen durable store V3 accepts
// RWCVerifiedRightsGrantV1 (mintable via the SUPERSEDED public V1.verify — the A17-F1 pin). In V2
// the LEGAL AUTHORITY decision is made EXCLUSIVELY by the signed/registry V2 boundary BEFORE this
// bridge; the V1 token is then derived mechanically as the store's ABI. Gates V5 law: any ledger
// entry not created through RunnerV2 is NOT corpus-lawful (receipts bind session identity), and
// the V1 mint surface is unlawful for any real path.
// ZERO-DATA: synthetic fixtures only; no network type exists here; no real asset.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

public enum RWCAcquisitionErrorV2: Error, Equatable, Sendable {
    case duplicateSession
    case quarantinePathEscape
    case quarantineFailure(String)
    case trustedChecksumMismatch(expected: String, actual: String)
    case metadataIntegrityFailure(String)
    case promoteFailure(String)
}

public enum RWCAcquisitionStateV1: String, Sendable {
    case authorized = "AUTHORIZED"
    case fetching = "FETCHING"
    case quarantined = "QUARANTINED"
    case rightsCommitted = "RIGHTS_COMMITTED"
    case promoted = "PROMOTED"
    case failedCleaned = "FAILED_CLEANED"
}

/// Receipt V2 (§53 chain + A17-F5/F9 closures: intendedUse + single transactionDate).
public struct RWCAcquisitionReceiptV2: Equatable, Sendable {
    public let sessionID: String
    public let assetID: String
    public let contentHash: String
    public let intendedUse: RWCUseV1
    public let legalGrantID: String
    public let grantRevision: Int
    public let reviewRecordID: String
    public let reviewerID: String
    public let rightsLedgerHeadDigest: String
    public let rightsEventCount: Int
    public let passLockCandidateCommit: String
    public let passLockTagObjectSHA: String
    public let auditResultBlobSHA256: String
    public let freezeManifestSHA256: String
    public let methodologyAnchorCommit: String
    public let transactionDate: String
}

public final class RWCCorpusAcquisitionRunnerV2 {
    public static let version = "rwc-corpus-acquisition-runner-v2"
    public static let metadataName = "session-metadata-v2.json"

    private let quarantineRoot: URL
    public init(quarantineRoot: URL) { self.quarantineRoot = quarantineRoot }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: session metadata (integrity-protected pending receipt; A17-F7)

    public struct SessionMetadataV1 {
        public let sessionID: String
        public let assetID: String
        public let grantID: String
        public let grantRevision: Int
        public let reviewRecordID: String
        public let reviewerID: String
        public let sourceReference: String
        public let intendedUse: String
        public let transactionDate: String
        public let passCandidate: String
        public var state: RWCAcquisitionStateV1
        public var contentHash: String   // "" until QUARANTINED

        public init(sessionID: String, assetID: String, grantID: String, grantRevision: Int,
                    reviewRecordID: String, reviewerID: String, sourceReference: String,
                    intendedUse: String, transactionDate: String, passCandidate: String,
                    state: RWCAcquisitionStateV1, contentHash: String) {
            self.sessionID = sessionID; self.assetID = assetID; self.grantID = grantID
            self.grantRevision = grantRevision; self.reviewRecordID = reviewRecordID
            self.reviewerID = reviewerID; self.sourceReference = sourceReference
            self.intendedUse = intendedUse; self.transactionDate = transactionDate
            self.passCandidate = passCandidate; self.state = state; self.contentHash = contentHash
        }

        var canonicalBody: String {
            let e = RWCCorpusAcquisitionRunnerV2.esc
            return "{\"v\":\"rwc-acq-session-v2\",\"session\":\"\(e(sessionID))\",\"asset\":\"\(e(assetID))\"," +
                   "\"grant\":\"\(e(grantID))\",\"rev\":\(grantRevision),\"review\":\"\(e(reviewRecordID))\"," +
                   "\"reviewer\":\"\(e(reviewerID))\",\"source\":\"\(e(sourceReference))\"," +
                   "\"use\":\"\(e(intendedUse))\",\"tx\":\"\(transactionDate)\"," +
                   "\"pass\":\"\(e(passCandidate))\",\"state\":\"\(state.rawValue)\"," +
                   "\"hash\":\"\(e(contentHash))\"}"
        }

        public func write(to dir: URL) throws {
            let body = canonicalBody
            let digest = RWCCorpusAcquisitionRunnerV2.sha256Hex(Data(body.utf8))
            let line = body + "\n" + digest + "\n"
            do {
                try Data(line.utf8).write(to: dir.appendingPathComponent(
                    RWCCorpusAcquisitionRunnerV2.metadataName), options: .atomic)
            } catch { throw RWCAcquisitionErrorV2.quarantineFailure("metadata write: \(error)") }
        }

        public static func read(from dir: URL) throws -> SessionMetadataV1 {
            let url = dir.appendingPathComponent(RWCCorpusAcquisitionRunnerV2.metadataName)
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
                throw RWCAcquisitionErrorV2.metadataIntegrityFailure("unreadable")
            }
            let parts = raw.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            guard parts.count == 2,
                  RWCCorpusAcquisitionRunnerV2.sha256Hex(Data(parts[0].utf8)) == parts[1],
                  let obj = try? JSONSerialization.jsonObject(with: Data(parts[0].utf8)) as? [String: Any],
                  obj["v"] as? String == "rwc-acq-session-v2",
                  let session = obj["session"] as? String, let asset = obj["asset"] as? String,
                  let grant = obj["grant"] as? String, let rev = obj["rev"] as? Int,
                  let review = obj["review"] as? String, let reviewer = obj["reviewer"] as? String,
                  let source = obj["source"] as? String, let use = obj["use"] as? String,
                  let tx = obj["tx"] as? String, let pass = obj["pass"] as? String,
                  let stateRaw = obj["state"] as? String,
                  let state = RWCAcquisitionStateV1(rawValue: stateRaw),
                  let hash = obj["hash"] as? String else {
                throw RWCAcquisitionErrorV2.metadataIntegrityFailure("malformed or tampered")
            }
            return SessionMetadataV1(sessionID: session, assetID: asset, grantID: grant,
                                     grantRevision: rev, reviewRecordID: review, reviewerID: reviewer,
                                     sourceReference: source, intendedUse: use, transactionDate: tx,
                                     passCandidate: pass, state: state, contentHash: hash)
        }
    }

    /// Session reservation (§58/§26): grammar-validated ID; duplicate → typed refusal; canonical
    /// containment double-check (defence-in-depth — grammar already forbids path characters).
    func reserveSession(_ sessionID: String) throws -> URL {
        try RWCAcquisitionSessionIDV1.validate(sessionID)
        let dir = quarantineRoot.appendingPathComponent("rwc-quarantine-\(sessionID)", isDirectory: true)
        let rootPath = quarantineRoot.standardizedFileURL.resolvingSymlinksInPath().path
        let dirPath = dir.standardizedFileURL.path
        guard dirPath.hasPrefix(rootPath + "/") else { throw RWCAcquisitionErrorV2.quarantinePathEscape }
        if FileManager.default.fileExists(atPath: dir.path) {
            throw RWCAcquisitionErrorV2.duplicateSession
        }
        do { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false) }
        catch { throw RWCAcquisitionErrorV2.quarantineFailure("reserve: \(error)") }
        return dir
    }

    /// THE lawful first-asset path V2. The clock is consulted EXACTLY ONCE (stage 0).
    public func acquire(proof: RWCVerifiedCorpusEntryV4,
                        request: RWCAcquisitionRequestV1,
                        verifiedGrant: RWCVerifiedRightsGrantV2,
                        rightsStore: RWCAssetRightsLedgerStoreV3,
                        corpusStore: RWCCorpusStoreV1,
                        acquirer: RWCAssetAcquirerV1,
                        clock: RWCRightsClockV3) throws -> RWCAcquisitionReceiptV2 {
        // stage 0 (A17-F9): the ONE authoritative transaction date.
        let transactionDate = clock.today()
        // stages 3-10 (A17-F2/F5/F10): ALL pre-fetch laws; mints the immutable proof.
        let preauth = try RWCPreAcquisitionEvaluatorV1.authorize(request: request,
                                                                 verifiedGrant: verifiedGrant,
                                                                 transactionDate: transactionDate)
        // stage 2 (A17-F6): session reservation AFTER preauth refusals (reservation is a side
        // effect; refused requests must leave no state) — grammar was already validated inside
        // the evaluator, so reservation cannot fail on grammar for an authorized request.
        let quarantine = try reserveSession(preauth.sessionID)
        var metadata = SessionMetadataV1(
            sessionID: preauth.sessionID, assetID: preauth.assetID, grantID: preauth.grantID,
            grantRevision: preauth.grantRevision, reviewRecordID: preauth.reviewRecordID,
            reviewerID: preauth.reviewerID, sourceReference: preauth.sourceReference,
            intendedUse: preauth.intendedUse == .training ? "training" : "evaluation",
            transactionDate: transactionDate.isoString, passCandidate: proof.candidateCommit,
            state: .authorized, contentHash: "")
        try metadata.write(to: quarantine)
        var finalized = false
        defer {
            // any non-finalized, non-recoverable outcome destroys the quarantine (no orphan bytes);
            // recoverable states (RIGHTS_COMMITTED) are preserved for reconciliation.
            if !finalized, metadata.state != .rightsCommitted {
                try? FileManager.default.removeItem(at: quarantine)
            }
        }
        // stage 11-12: ONLY NOW raw bytes may move — into ephemeral quarantine.
        metadata.state = .fetching
        try metadata.write(to: quarantine)
        let payload = try acquirer.fetch(sourceReference: preauth.sourceReference)
        do { try payload.write(to: quarantine.appendingPathComponent("payload"), options: .atomic) }
        catch { throw RWCAcquisitionErrorV2.quarantineFailure("payload write: \(error)") }
        // stage 13 (A17-F8): hash AFTER fetch; optional trusted checksum comparison only.
        let contentHash = Self.sha256Hex(payload)
        if let expected = preauth.trustedExpectedChecksum, expected != contentHash {
            throw RWCAcquisitionErrorV2.trustedChecksumMismatch(expected: expected, actual: contentHash)
        }
        metadata.state = .quarantined
        metadata.contentHash = contentHash
        try metadata.write(to: quarantine)
        // stage 14: FINAL record from the COMPUTED hash.
        let record = RWCAssetRightsRecordV3(
            assetID: preauth.assetID, sourceClass: preauth.sourceClass,
            sourceReference: preauth.sourceReference, owner: preauth.owner,
            grant: verifiedGrant.grant, acquisitionDate: transactionDate,
            contentHash: contentHash, provenanceChain: [preauth.sourceReference])
        // stage 15: durable rights commit via the V1-token ABI bridge (authority already decided
        // by the V2 signed/registry boundary — see header law).
        let bridgeReview = RWCRightsReviewRecordV1(
            reviewRecordID: verifiedGrant.reviewRecordID, grantID: verifiedGrant.grant.grantID,
            grantRevision: verifiedGrant.grant.grantRevision,
            evidenceDigest: verifiedGrant.grant.evidenceDigest, decision: "APPROVED",
            reviewDate: transactionDate)
        let v1Token = try RWCRightsReviewAuthorityV1.verify(grant: verifiedGrant.grant,
                                                            reviewRecord: bridgeReview)
        try rightsStore.register(record, verifiedGrant: v1Token,
                                 clock: RWCFixedClockV3(transactionDate))
        metadata.state = .rightsCommitted
        try metadata.write(to: quarantine)
        // stage 16: promote ONLY after the rights commit.
        do { try corpusStore.promote(assetID: preauth.assetID, contentHash: contentHash,
                                     payload: payload) }
        catch {
            // rights committed; quarantine + RIGHTS_COMMITTED metadata preserved for reconcile.
            throw RWCAcquisitionErrorV2.promoteFailure("\(error)")
        }
        metadata.state = .promoted
        try metadata.write(to: quarantine)
        finalized = true
        try? FileManager.default.removeItem(at: quarantine)   // COMPLETED
        // stage 17: receipt V2.
        return RWCAcquisitionReceiptV2(
            sessionID: preauth.sessionID, assetID: preauth.assetID, contentHash: contentHash,
            intendedUse: preauth.intendedUse, legalGrantID: preauth.grantID,
            grantRevision: preauth.grantRevision, reviewRecordID: preauth.reviewRecordID,
            reviewerID: preauth.reviewerID, rightsLedgerHeadDigest: rightsStore.headDigest,
            rightsEventCount: rightsStore.eventCount,
            passLockCandidateCommit: proof.candidateCommit,
            passLockTagObjectSHA: proof.candidateTagObjectSHA,
            auditResultBlobSHA256: proof.auditResultBlobSHA256,
            freezeManifestSHA256: proof.freezeManifestSHA256,
            methodologyAnchorCommit: proof.methodologyAnchorCommit,
            transactionDate: transactionDate.isoString)
    }

    public struct ReconciliationReportV2: Equatable, Sendable {
        public let recoveredSessions: [String]            // RIGHTS_COMMITTED → promoted now
        public let registeredButUnpromoted: [String]      // asset IDs needing attention
        public let destroyedRevokedSessions: [String]     // revoked asset → never promoted
        public let destroyedOrphanSessions: [String]      // no matching rights authority / tampered
    }

    /// RECONCILIATION V2 (A17-F7/§60-§63): driven by PERSISTED SESSION STATE, identity-bound by
    /// SESSION + ASSET + current ACTIVE rights state. Hash verifies bytes only. Each active asset
    /// is processed at most once; revoked assets are never promoted; orphans destroyed.
    public func reconcile(rightsStore: RWCAssetRightsLedgerStoreV3,
                          corpusStore: RWCCorpusStoreV1) throws -> ReconciliationReportV2 {
        var recovered: [String] = []
        var unpromoted: [String] = []
        var destroyedRevoked: [String] = []
        var destroyedOrphan: [String] = []
        var stored = Set(try corpusStore.storedAssetIDs())
        var processedAssets = Set<String>()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: quarantineRoot.path)) ?? []
        for name in names.sorted() where name.hasPrefix("rwc-quarantine-") {
            let dir = quarantineRoot.appendingPathComponent(name, isDirectory: true)
            // symlinked session dirs are hostile: destroy without following
            if (try? FileManager.default.attributesOfItem(atPath: dir.path))?[.type] as? FileAttributeType
                == .typeSymbolicLink {
                try? FileManager.default.removeItem(at: dir)
                destroyedOrphan.append(name)
                continue
            }
            guard let meta = try? SessionMetadataV1.read(from: dir) else {
                try? FileManager.default.removeItem(at: dir)   // tampered/malformed = orphan
                destroyedOrphan.append(name)
                continue
            }
            // identity law: metadata session must match its directory
            guard name == "rwc-quarantine-\(meta.sessionID)" else {
                try? FileManager.default.removeItem(at: dir)
                destroyedOrphan.append(name)
                continue
            }
            let assetID = meta.assetID
            // revoked asset: NEVER promote (deterministic destroy policy)
            if rightsStore.isTombstoned(assetID) {
                try? FileManager.default.removeItem(at: dir)
                destroyedRevoked.append(meta.sessionID)
                continue
            }
            // only RIGHTS_COMMITTED sessions are recoverable; anything earlier is incomplete work
            guard meta.state == .rightsCommitted,
                  let record = rightsStore.record(for: assetID),
                  record.contentHash == meta.contentHash else {
                try? FileManager.default.removeItem(at: dir)
                destroyedOrphan.append(meta.sessionID)
                continue
            }
            // each ACTIVE asset at most once (A17-F7)
            guard !processedAssets.contains(assetID) else {
                try? FileManager.default.removeItem(at: dir)
                destroyedOrphan.append(meta.sessionID)
                continue
            }
            processedAssets.insert(assetID)
            if stored.contains(assetID) {
                try? FileManager.default.removeItem(at: dir)   // already promoted; stale session
                continue
            }
            // SESSION+ASSET bound recovery; hash verifies the bytes
            if let payload = try? Data(contentsOf: dir.appendingPathComponent("payload")),
               Self.sha256Hex(payload) == meta.contentHash {
                try corpusStore.promote(assetID: assetID, contentHash: meta.contentHash, payload: payload)
                stored.insert(assetID)
                recovered.append(meta.sessionID)
                try? FileManager.default.removeItem(at: dir)
            } else {
                unpromoted.append(assetID)   // explicit deficit; quarantine kept for manual policy
            }
        }
        // rights-committed active assets with NO session and NO corpus payload = explicit deficit
        for e in rightsStore.events where e.kind == "registered" || e.kind == "reauthorized" {
            let assetID = e.assetID
            guard !rightsStore.isTombstoned(assetID), !stored.contains(assetID),
                  !processedAssets.contains(assetID), rightsStore.record(for: assetID) != nil else { continue }
            processedAssets.insert(assetID)
            unpromoted.append(assetID)
        }
        return ReconciliationReportV2(recoveredSessions: recovered.sorted(),
                                      registeredButUnpromoted: unpromoted.sorted(),
                                      destroyedRevokedSessions: destroyedRevoked.sorted(),
                                      destroyedOrphanSessions: destroyedOrphan.sorted())
    }
}
#endif
