#if os(macOS)
import Foundation
import CryptoKit
import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC CORPUS ACQUISITION RUNNER V4 (R6; AUDIT19 A19-F1 CRITICAL remediation) — supersedes RunnerV3
// BY RECORD. RunnerV3 stays byte-frozen SUPERSEDED_ENGINEERING_HISTORY (its reconcileV3 is the
// AUDIT19-proven acquisition backdoor; R5/AUDIT19 tests pin that history).
//
// A19-F1 ROOT CAUSE (R5): reconcileV3 promoted any quarantine whose caller-constructed metadata +
// receipt + rights record agreed — all three forgeable (the rights record via the PUBLIC no-crypto
// V1 token, the metadata + receipt via public constructors). No unforgeable, authority-bound marker
// proved the transaction was originally authorized by the rooted acquisition path.
//
// R6 CLOSURE:
//   • acquire() consumes an RWCVerifiedCorpusEntryV5 PASS proof + an RWCVerifiedRightsGrantV6 (rooted
//     via the capability-gated trust root V2 → governed current registry V2 → authority V6 chain),
//     commits the rights record into RWCAssetRightsLedgerStoreV4 (which REQUIRES the V6 grant — the
//     forged V1 token can no longer register), then writes an UNFORGEABLE, LEDGER-RESIDENT
//     ACQUISITION AUTHORIZATION record (store.authorizeAcquisition requires the V6 grant), then
//     PREPAREs a V2 receipt bound to that authorization, then promotes, then finalizes.
//   • reconcileV4 drives ENTIRELY off the ledger-resident authorization records (NOT the forgeable
//     quarantine metadata or receipt): a quarantine is promoted ONLY when a matching authorization
//     record exists in the flock-protected, hash-chained ledger AND the quarantined payload hashes to
//     the authorized content hash. No authorization record ⇒ the quarantine is a hostile orphan and
//     is destroyed, never promoted. Caller-constructed metadata/receipts cannot substitute, because
//     writing an authorization record requires the unforgeable V6 grant.
//
// Crash windows (A19 §28-§34 re-proven on the new path): a crash between authorize and promote leaves
// an authorization record + quarantine payload that reconcileV4 recovers (promote + finalize); a
// crash after promote leaves the asset stored and reconcileV4 finalizes the receipt with no double
// promotion; a crash before the authorization write leaves NO authorization record, so reconcileV4
// safely refuses to promote (fail closed) and reports the rights-registered asset as unpromoted.
//
// ZERO-DATA: synthetic fixtures only; no network type here; no real asset.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

public enum RWCAcquisitionErrorV4: Error, Equatable, Sendable {
    case duplicateSession
    case quarantinePathEscape
    case quarantineFailure(String)
    case trustedChecksumMismatch(expected: String, actual: String)
    case promoteFailure(String)
    case receiptFailure(String)
    case authorizationFailure(String)
}

public final class RWCCorpusAcquisitionRunnerV4 {
    public static let version = "rwc-corpus-acquisition-runner-v4"
    public static let metadataName = "session-metadata-v4.json"

    private let quarantineRoot: URL
    public init(quarantineRoot: URL) { self.quarantineRoot = quarantineRoot }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Session reservation: grammar-validated ID; duplicate → typed refusal; canonical containment.
    func reserveSession(_ sessionID: String) throws -> URL {
        try RWCAcquisitionSessionIDV1.validate(sessionID)
        let dir = quarantineRoot.appendingPathComponent("rwc-quarantine-\(sessionID)", isDirectory: true)
        let rootPath = quarantineRoot.standardizedFileURL.resolvingSymlinksInPath().path
        let dirPath = dir.standardizedFileURL.path
        guard dirPath.hasPrefix(rootPath + "/") else { throw RWCAcquisitionErrorV4.quarantinePathEscape }
        if FileManager.default.fileExists(atPath: dir.path) {
            throw RWCAcquisitionErrorV4.duplicateSession
        }
        do { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false) }
        catch { throw RWCAcquisitionErrorV4.quarantineFailure("reserve: \(error)") }
        return dir
    }

    /// THE lawful first-asset path V4. The clock is consulted EXACTLY ONCE (stage 0).
    @discardableResult
    public func acquire(proof: RWCVerifiedCorpusEntryV5,
                        request: RWCAcquisitionRequestV1,
                        verifiedGrant: RWCVerifiedRightsGrantV6,
                        rightsStore: RWCAssetRightsLedgerStoreV4,
                        corpusStore: RWCCorpusStoreV1,
                        acquirer: RWCAssetAcquirerV1,
                        clock: RWCRightsClockV3,
                        receiptStore: RWCAcquisitionReceiptStoreV2) throws -> RWCAcquisitionReceiptV2 {
        let transactionDate = clock.today()
        let preauth = try RWCPreAcquisitionEvaluatorV3.authorize(request: request,
                                                                 verifiedGrant: verifiedGrant,
                                                                 transactionDate: transactionDate)
        let quarantine = try reserveSession(preauth.sessionID)
        var cleanupOnFailure = true
        defer { if cleanupOnFailure { try? FileManager.default.removeItem(at: quarantine) } }

        // fetch → quarantine (raw bytes never touch the corpus store).
        let payload = try acquirer.fetch(sourceReference: preauth.sourceReference)
        do { try payload.write(to: quarantine.appendingPathComponent("payload"), options: .atomic) }
        catch { throw RWCAcquisitionErrorV4.quarantineFailure("payload write: \(error)") }
        let contentHash = Self.sha256Hex(payload)
        if let expected = preauth.trustedExpectedChecksum, expected != contentHash {
            throw RWCAcquisitionErrorV4.trustedChecksumMismatch(expected: expected, actual: contentHash)
        }
        // durable rights commit — REQUIRES the unforgeable V6 grant (forged V1 token cannot register).
        let record = RWCAssetRightsRecordV3(
            assetID: preauth.assetID, sourceClass: preauth.sourceClass,
            sourceReference: preauth.sourceReference, owner: preauth.owner,
            grant: verifiedGrant.grant, acquisitionDate: transactionDate,
            contentHash: contentHash, provenanceChain: [preauth.sourceReference])
        try rightsStore.register(record, verifiedGrant: verifiedGrant,
                                 clock: RWCFixedClockV3(transactionDate))
        // A19-F1 unforgeable, ledger-resident authorization marker (survives a post-write crash).
        let authz: RWCAcquisitionAuthorizationRecordV1
        do {
            authz = try rightsStore.authorizeAcquisition(
                sessionID: preauth.sessionID, assetID: preauth.assetID, contentHash: contentHash,
                intendedUse: preauth.intendedUse, sourceReference: preauth.sourceReference,
                verifiedGrant: verifiedGrant, candidateCommit: proof.candidateCommit,
                auditResultBlobSHA256: proof.auditResultBlobSHA256,
                clock: RWCFixedClockV3(transactionDate))
        } catch { throw RWCAcquisitionErrorV4.authorizationFailure("\(error)") }
        // Once the rights record + ledger-resident authorization are durable, a later crash (promote
        // or finalize) MUST preserve the quarantine payload so reconcileV4 can recover it.
        cleanupOnFailure = false
        // durable PREPARED receipt (A19-F4 strict + authority-bound) BEFORE promotion.
        do {
            try receiptStore.prepare(
                authorization: authz, rightsLedgerHeadDigest: rightsStore.headDigest,
                rightsEventCount: rightsStore.eventCount,
                passLockCandidateCommit: proof.candidateCommit,
                passLockTagObjectSHA: proof.candidateTagObjectSHA,
                auditResultBlobSHA256: proof.auditResultBlobSHA256,
                freezeManifestSHA256: proof.freezeManifestSHA256,
                methodologyAnchorCommit: proof.methodologyAnchorCommit)
        } catch { throw RWCAcquisitionErrorV4.receiptFailure("prepare: \(error)") }
        // promote ONLY after the rights commit + ledger authorization + durable PREPARED receipt.
        do { try corpusStore.promote(assetID: preauth.assetID, contentHash: contentHash, payload: payload) }
        catch { throw RWCAcquisitionErrorV4.promoteFailure("\(error)") }
        do {
            try receiptStore.confirmPromotion(sessionID: preauth.sessionID)
            try receiptStore.complete(sessionID: preauth.sessionID)
        } catch { throw RWCAcquisitionErrorV4.receiptFailure("finalize: \(error)") }
        try? FileManager.default.removeItem(at: quarantine)   // COMPLETED
        return try receiptStore.load(preauth.sessionID).receipt
    }

    public struct ReconciliationReportV4: Equatable, Sendable {
        public let recoveredSessions: [String]            // authorized quarantine → promoted now
        public let finalizedReceipts: [String]            // PREPARED → COMPLETED (crash recovery)
        public let registeredButUnpromoted: [String]      // asset IDs needing attention
        public let destroyedRevokedSessions: [String]     // revoked asset → never promoted
        public let destroyedUnauthorizedSessions: [String]// NO ledger authorization → hostile orphan
    }

    /// RECONCILIATION V4 (A19-F1): promote ONLY sessions backed by a ledger-resident authorization
    /// record whose authorized content hash matches the quarantined payload. Entirely independent of
    /// the forgeable quarantine metadata / receipt. Idempotent.
    public func reconcileV4(rightsStore: RWCAssetRightsLedgerStoreV4,
                            corpusStore: RWCCorpusStoreV1,
                            receiptStore: RWCAcquisitionReceiptStoreV2) throws -> ReconciliationReportV4 {
        var recovered: [String] = []
        var finalized: [String] = []
        var unpromoted: [String] = []
        var destroyedRevoked: [String] = []
        var destroyedUnauthorized: [String] = []
        var stored = Set(try corpusStore.storedAssetIDs())
        var processedAssets = Set<String>()

        func finalizeReceiptIfPresent(_ sessionID: String) {
            if let rec = try? receiptStore.load(sessionID), rec.state != .completed {
                try? receiptStore.confirmPromotion(sessionID: sessionID)
                try? receiptStore.complete(sessionID: sessionID)
                finalized.append(sessionID)
            }
        }

        let names = (try? FileManager.default.contentsOfDirectory(atPath: quarantineRoot.path)) ?? []
        for name in names.sorted() where name.hasPrefix("rwc-quarantine-") {
            let dir = quarantineRoot.appendingPathComponent(name, isDirectory: true)
            // symlink or non-directory → hostile, destroy.
            if (try? FileManager.default.attributesOfItem(atPath: dir.path))?[.type] as? FileAttributeType
                == .typeSymbolicLink {
                try? FileManager.default.removeItem(at: dir)
                destroyedUnauthorized.append(name)
                continue
            }
            let sessionID = String(name.dropFirst("rwc-quarantine-".count))
            // A19-F1 GATE: an unforgeable ledger-resident authorization record MUST exist.
            guard let authz = rightsStore.authorizationRecord(forSession: sessionID) else {
                try? FileManager.default.removeItem(at: dir)
                destroyedUnauthorized.append(sessionID)
                continue
            }
            let assetID = authz.assetID
            // the authorized asset must still have a live rights record consistent with the marker.
            guard let rec = rightsStore.record(for: assetID),
                  rec.grant.grantID == authz.grantID, rec.grant.grantRevision == authz.grantRevision,
                  rec.contentHash == authz.contentHash, rec.sourceReference == authz.sourceReference else {
                if rightsStore.isTombstoned(assetID) {
                    try? FileManager.default.removeItem(at: dir)
                    destroyedRevoked.append(sessionID)
                } else {
                    try? FileManager.default.removeItem(at: dir)
                    destroyedUnauthorized.append(sessionID)
                }
                continue
            }
            if rightsStore.isTombstoned(assetID) {
                try? FileManager.default.removeItem(at: dir)
                destroyedRevoked.append(sessionID)
                continue
            }
            guard !processedAssets.contains(assetID) else {
                try? FileManager.default.removeItem(at: dir)
                destroyedUnauthorized.append(sessionID)
                continue
            }
            processedAssets.insert(assetID)
            if stored.contains(assetID) {
                finalizeReceiptIfPresent(sessionID)
                try? FileManager.default.removeItem(at: dir)
                continue
            }
            // recoverable quarantine payload → promote (authorized) then finalize the receipt.
            if let payload = try? Data(contentsOf: dir.appendingPathComponent("payload")),
               Self.sha256Hex(payload) == authz.contentHash {
                do { try corpusStore.promote(assetID: assetID, contentHash: authz.contentHash,
                                             payload: payload) }
                catch { unpromoted.append(assetID); continue }
                stored.insert(assetID)
                recovered.append(sessionID)
                finalizeReceiptIfPresent(sessionID)
                try? FileManager.default.removeItem(at: dir)
            } else {
                unpromoted.append(assetID)
            }
        }
        // authorized-but-unpromoted assets with no surviving quarantine payload = explicit deficit.
        for authz in rightsStore.allAuthorizations() {
            let assetID = authz.assetID
            guard !rightsStore.isTombstoned(assetID), !stored.contains(assetID),
                  !processedAssets.contains(assetID), rightsStore.record(for: assetID) != nil else { continue }
            processedAssets.insert(assetID)
            unpromoted.append(assetID)
        }
        return ReconciliationReportV4(recoveredSessions: recovered.sorted(),
                                      finalizedReceipts: finalized.sorted(),
                                      registeredButUnpromoted: unpromoted.sorted(),
                                      destroyedRevokedSessions: destroyedRevoked.sorted(),
                                      destroyedUnauthorizedSessions: destroyedUnauthorized.sorted())
    }
}
#endif
