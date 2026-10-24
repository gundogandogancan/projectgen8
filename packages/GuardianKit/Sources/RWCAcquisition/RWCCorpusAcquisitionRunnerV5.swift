#if os(macOS)
import Foundation
import CryptoKit
import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC CORPUS ACQUISITION RUNNER V5 (R7; AUDIT20 A20-F1 + R-6 remediation) — THE single acquisition /
// authorization coordinator, superseding RunnerV4 BY RECORD. RunnerV4 stays byte-frozen
// SUPERSEDED_ENGINEERING_HISTORY (its reconcileV4 promoted on a scalar-written authorization record).
//
// IMPLEMENTED_UNVERIFIED: authored in a sandbox that cannot compile/run `swift test`. The main session
// MUST compile + run the suite green ×2 before this is an audit candidate.
//
// RunnerV5 is the ONLY place in the whole package that mints RWCAcquisitionAuthorityTokenV1 (A20-F1).
// The token's init is `package`, so only GuardianKit-package code CAN mint it; by discipline only this
// function DOES, and only after:
//   (1) RWCCorpusEntryVerifierV6.verify(repoRoot:) returned a PRE-14 PASS proof (methodology authority),
//   (2) RWCPreAcquisitionEvaluatorV3.authorize validated source + intended-use against the V6 grant,
//   (3) the CURRENT verified registry (from RWCReviewerRegistryVerifierV2.verifyCurrent) is presented.
// authorizeAcquisitionV2 then re-checks intended-use (A20-F3) and current reviewer authority (A20-F4)
// and writes the FULL proof identity into the durable authorization record.
//
// reconcileV5 (recovery): promotes ONLY sessions backed by a ledger-resident RWCAcquisitionAuthorization
// RecordV2 with a COMPLETE proof identity; when a promotable session has NO durable receipt it
// RECONSTRUCTS one from the authenticated authorization record (R-6) so a promoted asset ALWAYS has a
// receipt; a session whose proof identity is incomplete is kept UNPROMOTED and surfaced as an explicit
// receiptDeficit — never silent promotion.
//
// ZERO-DATA: synthetic fixtures only; no production root, no real asset, no PASS lock.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

public enum RWCAcquisitionErrorV5: Error, Equatable, Sendable {
    case duplicateSession
    case quarantinePathEscape
    case quarantineFailure(String)
    case trustedChecksumMismatch(expected: String, actual: String)
    case promoteFailure(String)
    case receiptFailure(String)
    case authorizationFailure(String)
    case proofIdentityIncomplete
}

public final class RWCCorpusAcquisitionRunnerV5 {
    public static let version = "rwc-corpus-acquisition-runner-v5"

    private let quarantineRoot: URL
    public init(quarantineRoot: URL) { self.quarantineRoot = quarantineRoot }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func reserveSession(_ sessionID: String) throws -> URL {
        try RWCAcquisitionSessionIDV1.validate(sessionID)
        let dir = quarantineRoot.appendingPathComponent("rwc-quarantine-\(sessionID)", isDirectory: true)
        let rootPath = quarantineRoot.standardizedFileURL.resolvingSymlinksInPath().path
        let dirPath = dir.standardizedFileURL.path
        guard dirPath.hasPrefix(rootPath + "/") else { throw RWCAcquisitionErrorV5.quarantinePathEscape }
        if FileManager.default.fileExists(atPath: dir.path) { throw RWCAcquisitionErrorV5.duplicateSession }
        do { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false) }
        catch { throw RWCAcquisitionErrorV5.quarantineFailure("reserve: \(error)") }
        return dir
    }

    /// THE ONLY authority-token minter (A20-F1). `package`-init of the token means only in-package code
    /// can construct it; this function is the single disciplined caller. It binds the V6 PASS proof
    /// identity + the evaluator-validated acquisition facts + the current-registry witness. There is NO
    /// path to a token that does not pass through a verified V6 corpus-entry proof, the evaluator and a
    /// verified-current registry.
    func mintAuthorityToken(proof: RWCVerifiedCorpusEntryV6,
                            preauth: RWCPreAcquisitionAuthorizationV3,
                            currentRegistry: RWCVerifiedReviewerRegistryV2) -> RWCAcquisitionAuthorityTokenV1 {
        RWCAcquisitionAuthorityTokenV1(
            candidateCommit: proof.candidateCommit, candidateTagObjectSHA: proof.candidateTagObjectSHA,
            auditCommit: proof.auditCommit, auditResultBlobSHA256: proof.auditResultBlobSHA256,
            methodologyAnchorCommit: proof.methodologyAnchorCommit,
            freezeManifestSHA256: proof.freezeManifestSHA256,
            frozenInventoryDigest: proof.frozenInventoryDigest,
            sessionID: preauth.sessionID, assetID: preauth.assetID,
            sourceReference: preauth.sourceReference,
            intendedUseToken: preauth.intendedUse == .training ? "training" : "evaluation",
            grantID: preauth.grantID, grantRevision: preauth.grantRevision,
            currentRegistryRootID: currentRegistry.rootID,
            currentRegistryRevision: currentRegistry.registryRevision,
            currentRegistryDocumentDigest: currentRegistry.documentDigest)
    }

    /// THE lawful first-asset path V5. Consumes the PRE-14 PASS proof (V6), the rooted V6 grant AND the
    /// CURRENT verified registry (A20-F4). The clock is consulted EXACTLY ONCE.
    @discardableResult
    public func acquire(proof: RWCVerifiedCorpusEntryV6,
                        request: RWCAcquisitionRequestV1,
                        verifiedGrant: RWCVerifiedRightsGrantV6,
                        currentRegistry: RWCVerifiedReviewerRegistryV2,
                        rightsStore: RWCAssetRightsLedgerStoreV5,
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

        let payload = try acquirer.fetch(sourceReference: preauth.sourceReference)
        do { try payload.write(to: quarantine.appendingPathComponent("payload"), options: .atomic) }
        catch { throw RWCAcquisitionErrorV5.quarantineFailure("payload write: \(error)") }
        let contentHash = Self.sha256Hex(payload)
        if let expected = preauth.trustedExpectedChecksum, expected != contentHash {
            throw RWCAcquisitionErrorV5.trustedChecksumMismatch(expected: expected, actual: contentHash)
        }
        let record = RWCAssetRightsRecordV3(
            assetID: preauth.assetID, sourceClass: preauth.sourceClass,
            sourceReference: preauth.sourceReference, owner: preauth.owner,
            grant: verifiedGrant.grant, acquisitionDate: transactionDate,
            contentHash: contentHash, provenanceChain: [preauth.sourceReference])
        try rightsStore.register(record, verifiedGrant: verifiedGrant,
                                 clock: RWCFixedClockV3(transactionDate))
        // A20-F1: mint the token (only here) and write the sealed authorization record.
        let token = mintAuthorityToken(proof: proof, preauth: preauth, currentRegistry: currentRegistry)
        let authz: RWCAcquisitionAuthorizationRecordV2
        do {
            authz = try rightsStore.authorizeAcquisitionV2(token: token, verifiedGrant: verifiedGrant,
                                                           currentRegistry: currentRegistry,
                                                           clock: RWCFixedClockV3(transactionDate))
        } catch { throw RWCAcquisitionErrorV5.authorizationFailure("\(error)") }
        cleanupOnFailure = false
        // durable PREPARED receipt BEFORE promotion (identity from the authenticated record + the REAL
        // ledger head/count at prepare time).
        do {
            try preparedReceipt(from: authz, rightsStore: rightsStore, receiptStore: receiptStore)
        } catch { throw RWCAcquisitionErrorV5.receiptFailure("prepare: \(error)") }
        do { try corpusStore.promote(assetID: preauth.assetID, contentHash: contentHash, payload: payload) }
        catch { throw RWCAcquisitionErrorV5.promoteFailure("\(error)") }
        do {
            try receiptStore.confirmPromotion(sessionID: preauth.sessionID)
            try receiptStore.complete(sessionID: preauth.sessionID)
        } catch { throw RWCAcquisitionErrorV5.receiptFailure("finalize: \(error)") }
        try? FileManager.default.removeItem(at: quarantine)
        return try receiptStore.load(preauth.sessionID).receipt
    }

    /// Prepare a durable PREPARED receipt from an authenticated authorization record V2, using the REAL
    /// ledger head/count at prepare time. Every `prepare` field is present on the V2 record, so this is
    /// also the R-6 reconstruction primitive used by reconcileV5. Uses the R7 `package` overload
    /// `RWCAcquisitionReceiptStoreV2.prepare(authorizationV2:…)` (additive; declared in the lock). The
    /// receipt is idempotent on duplicate session (reconcileV5 only calls this when load() failed).
    private func preparedReceipt(from authz: RWCAcquisitionAuthorizationRecordV2,
                                 rightsStore: RWCAssetRightsLedgerStoreV5,
                                 receiptStore: RWCAcquisitionReceiptStoreV2) throws {
        try receiptStore.prepare(authorizationV2: authz,
                                 rightsLedgerHeadDigest: rightsStore.headDigest,
                                 rightsEventCount: rightsStore.eventCount)
    }

    public struct ReconciliationReportV5: Equatable, Sendable {
        public let recoveredSessions: [String]
        public let finalizedReceipts: [String]
        public let reconstructedReceipts: [String]        // R-6: receipt rebuilt from the ledger record
        public let registeredButUnpromoted: [String]
        public let destroyedRevokedSessions: [String]
        public let destroyedUnauthorizedSessions: [String]
        public let receiptDeficitSessions: [String]       // R-6: promotable but proof identity incomplete
    }

    /// RECONCILIATION V5 (A20-F1 + R-6). Promote ONLY sessions backed by a ledger-resident authorization
    /// record V2 with a COMPLETE proof identity; reconstruct a durable receipt if absent; otherwise keep
    /// unpromoted and report a deficit. Idempotent.
    public func reconcileV5(rightsStore: RWCAssetRightsLedgerStoreV5,
                            corpusStore: RWCCorpusStoreV1,
                            receiptStore: RWCAcquisitionReceiptStoreV2) throws -> ReconciliationReportV5 {
        var recovered: [String] = []; var finalized: [String] = []; var reconstructed: [String] = []
        var unpromoted: [String] = []; var destroyedRevoked: [String] = []
        var destroyedUnauthorized: [String] = []; var deficit: [String] = []
        var stored = Set(try corpusStore.storedAssetIDs())
        var processedAssets = Set<String>()

        // A21-F5 FIX (LANE A; declared supersession in docs/audit/AUDIT21_LANE_A_INVERSION_LOCK.md).
        // OLD (A21-F5 report-fidelity gap): the `rec.state != .completed` branch ran `try?`-swallowed
        // confirmPromotion()/complete() and then UNCONDITIONALLY `finalized.append(...)` — so a FAILED
        // complete() (disk full / read-only / IO error) still reported the session in finalizedReceipts
        // while the DURABLE receipt stayed .prepared. NEW: a session is reported finalized ONLY after a
        // RELOAD confirms the durable state is actually .completed; otherwise it is surfaced as an
        // explicit receiptDeficit (visible, retryable) — never a false finalize, never silent loss.
        // Returns TRUE iff the durable receipt verifiably reached .completed. A FALSE result means the
        // session was recorded as a receiptDeficit; the caller MUST then PRESERVE the quarantine so the
        // payload evidence is not lost and the next reconcile can retry (A21-F5: no evidence loss on
        // quarantine deletion).
        @discardableResult
        func ensureReceipt(_ authz: RWCAcquisitionAuthorizationRecordV2) -> Bool {
            if let rec = try? receiptStore.load(authz.sessionID) {
                if rec.state == .completed { return true }
                // Attempt finalize, then VERIFY durable completion before claiming success.
                do {
                    try receiptStore.confirmPromotion(sessionID: authz.sessionID)
                    try receiptStore.complete(sessionID: authz.sessionID)
                } catch { deficit.append(authz.sessionID); return false }
                if let after = try? receiptStore.load(authz.sessionID), after.state == .completed {
                    finalized.append(authz.sessionID); return true
                } else {
                    deficit.append(authz.sessionID); return false   // finalize did not reach durable .completed
                }
            } else {
                // R-6 RECONSTRUCTION from authenticated ledger evidence — reconstructed ONLY if the
                // durable receipt verifiably reaches .completed (same no-false-report law as above).
                do {
                    try preparedReceipt(from: authz, rightsStore: rightsStore, receiptStore: receiptStore)
                    try receiptStore.confirmPromotion(sessionID: authz.sessionID)
                    try receiptStore.complete(sessionID: authz.sessionID)
                    guard let after = try? receiptStore.load(authz.sessionID),
                          after.state == .completed else {
                        deficit.append(authz.sessionID); return false
                    }
                    reconstructed.append(authz.sessionID); return true
                } catch { deficit.append(authz.sessionID); return false }
            }
        }

        let names = (try? FileManager.default.contentsOfDirectory(atPath: quarantineRoot.path)) ?? []
        for name in names.sorted() where name.hasPrefix("rwc-quarantine-") {
            let dir = quarantineRoot.appendingPathComponent(name, isDirectory: true)
            if (try? FileManager.default.attributesOfItem(atPath: dir.path))?[.type] as? FileAttributeType
                == .typeSymbolicLink {
                try? FileManager.default.removeItem(at: dir); destroyedUnauthorized.append(name); continue
            }
            let sessionID = String(name.dropFirst("rwc-quarantine-".count))
            guard let authz = rightsStore.authorizationRecord(forSession: sessionID) else {
                try? FileManager.default.removeItem(at: dir); destroyedUnauthorized.append(sessionID); continue
            }
            // R-6 gate: refuse to promote on an incomplete proof identity (fail closed, report deficit).
            guard authz.hasCompleteProofIdentity else {
                deficit.append(sessionID); unpromoted.append(authz.assetID); continue
            }
            let assetID = authz.assetID
            guard let rec = rightsStore.record(for: assetID),
                  rec.grant.grantID == authz.grantID, rec.grant.grantRevision == authz.grantRevision,
                  rec.contentHash == authz.contentHash, rec.sourceReference == authz.sourceReference else {
                try? FileManager.default.removeItem(at: dir)
                if rightsStore.isTombstoned(assetID) { destroyedRevoked.append(sessionID) }
                else { destroyedUnauthorized.append(sessionID) }
                continue
            }
            if rightsStore.isTombstoned(assetID) {
                try? FileManager.default.removeItem(at: dir); destroyedRevoked.append(sessionID); continue
            }
            guard !processedAssets.contains(assetID) else {
                try? FileManager.default.removeItem(at: dir); destroyedUnauthorized.append(sessionID); continue
            }
            processedAssets.insert(assetID)
            if stored.contains(assetID) {
                // A21-F5: delete the quarantine ONLY if the receipt is durably complete; preserve the
                // payload evidence on a receiptDeficit so a later reconcile can retry.
                if ensureReceipt(authz) { try? FileManager.default.removeItem(at: dir) }
                continue
            }
            if let payload = try? Data(contentsOf: dir.appendingPathComponent("payload")),
               Self.sha256Hex(payload) == authz.contentHash {
                do { try corpusStore.promote(assetID: assetID, contentHash: authz.contentHash, payload: payload) }
                catch { unpromoted.append(assetID); continue }
                stored.insert(assetID); recovered.append(sessionID)
                // A21-F5: preserve the quarantine on a receiptDeficit (no evidence loss).
                if ensureReceipt(authz) { try? FileManager.default.removeItem(at: dir) }
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
            if !authz.hasCompleteProofIdentity { deficit.append(authz.sessionID) }
        }
        return ReconciliationReportV5(recoveredSessions: recovered.sorted(),
                                      finalizedReceipts: finalized.sorted(),
                                      reconstructedReceipts: reconstructed.sorted(),
                                      registeredButUnpromoted: unpromoted.sorted(),
                                      destroyedRevokedSessions: destroyedRevoked.sorted(),
                                      destroyedUnauthorizedSessions: destroyedUnauthorized.sorted(),
                                      receiptDeficitSessions: deficit.sorted())
    }
}
#endif
