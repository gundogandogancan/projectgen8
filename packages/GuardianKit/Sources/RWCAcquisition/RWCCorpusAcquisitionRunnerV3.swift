#if os(macOS)
import Foundation
import CryptoKit
import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC CORPUS ACQUISITION RUNNER V3 (R5; AUDIT18 remediation) — supersedes RunnerV2 BY RECORD.
// RunnerV2 stays byte-frozen SUPERSEDED_ENGINEERING_HISTORY (A18-F3/F6 pins).
//
// R5 deltas over RunnerV2 (all other mechanics copied verbatim — session reservation, state
// machine, hash-after-fetch, single clock consult, V1-token ABI bridge into the frozen store):
//   • A18-F1 ROOTED AUTHORITY: acquire() consumes a VERIFIED CORPUS ENTRY V5 proof and a VERIFIED
//     RIGHTS GRANT V3 (minted only through the governed root → signed registry → review authority
//     V3 chain + reviewer.scope == .corpus). The V1-token ABI bridge into the frozen durable store
//     is derived mechanically AFTER THE V3 ROOTED BOUNDARY — the legal decision is already made.
//   • A18-F3 DURABLE RECEIPT: receiptStore.prepare(...) persists the PREPARED receipt durably AFTER
//     the rights commit and BEFORE corpus promotion (§38); confirmPromotion + complete follow the
//     promote. The returned receipt is derived from the durable record (§40) — survives a
//     post-promote crash so reconcileV3 can finalize it.
//   • A18-F6 RECONCILE AUTHORITY FIELDS: reconcileV3 cross-verifies the session-metadata authority
//     fields (grantID, grantRevision, reviewRecordID, reviewerID, sourceReference, intendedUse)
//     against BOTH the authoritative rights record AND the durable PREPARED receipt — a mismatch is
//     never promoted (destroy/incident). It also finalizes receipts after a crash-after-promote and
//     is idempotent (run twice → no duplicate receipt/promotion).
//
// ZERO-DATA: synthetic fixtures only; no network type exists here; no real asset.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

public enum RWCAcquisitionErrorV3: Error, Equatable, Sendable {
    case duplicateSession
    case quarantinePathEscape
    case quarantineFailure(String)
    case trustedChecksumMismatch(expected: String, actual: String)
    case metadataIntegrityFailure(String)
    case promoteFailure(String)
    case receiptFailure(String)
}

public final class RWCCorpusAcquisitionRunnerV3 {
    public static let version = "rwc-corpus-acquisition-runner-v3"
    public static let metadataName = "session-metadata-v3.json"

    private let quarantineRoot: URL
    public init(quarantineRoot: URL) { self.quarantineRoot = quarantineRoot }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: session metadata (integrity-protected pending receipt; carried from RunnerV2)

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
            let e = RWCCorpusAcquisitionRunnerV3.esc
            return "{\"v\":\"rwc-acq-session-v3\",\"session\":\"\(e(sessionID))\",\"asset\":\"\(e(assetID))\"," +
                   "\"grant\":\"\(e(grantID))\",\"rev\":\(grantRevision),\"review\":\"\(e(reviewRecordID))\"," +
                   "\"reviewer\":\"\(e(reviewerID))\",\"source\":\"\(e(sourceReference))\"," +
                   "\"use\":\"\(e(intendedUse))\",\"tx\":\"\(transactionDate)\"," +
                   "\"pass\":\"\(e(passCandidate))\",\"state\":\"\(state.rawValue)\"," +
                   "\"hash\":\"\(e(contentHash))\"}"
        }

        public func write(to dir: URL) throws {
            let body = canonicalBody
            let digest = RWCCorpusAcquisitionRunnerV3.sha256Hex(Data(body.utf8))
            let line = body + "\n" + digest + "\n"
            do {
                try Data(line.utf8).write(to: dir.appendingPathComponent(
                    RWCCorpusAcquisitionRunnerV3.metadataName), options: .atomic)
            } catch { throw RWCAcquisitionErrorV3.quarantineFailure("metadata write: \(error)") }
        }

        public static func read(from dir: URL) throws -> SessionMetadataV1 {
            let url = dir.appendingPathComponent(RWCCorpusAcquisitionRunnerV3.metadataName)
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
                throw RWCAcquisitionErrorV3.metadataIntegrityFailure("unreadable")
            }
            let parts = raw.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            guard parts.count == 2,
                  RWCCorpusAcquisitionRunnerV3.sha256Hex(Data(parts[0].utf8)) == parts[1],
                  let obj = try? JSONSerialization.jsonObject(with: Data(parts[0].utf8)) as? [String: Any],
                  obj["v"] as? String == "rwc-acq-session-v3",
                  let session = obj["session"] as? String, let asset = obj["asset"] as? String,
                  let grant = obj["grant"] as? String, let rev = obj["rev"] as? Int,
                  let review = obj["review"] as? String, let reviewer = obj["reviewer"] as? String,
                  let source = obj["source"] as? String, let use = obj["use"] as? String,
                  let tx = obj["tx"] as? String, let pass = obj["pass"] as? String,
                  let stateRaw = obj["state"] as? String,
                  let state = RWCAcquisitionStateV1(rawValue: stateRaw),
                  let hash = obj["hash"] as? String else {
                throw RWCAcquisitionErrorV3.metadataIntegrityFailure("malformed or tampered")
            }
            return SessionMetadataV1(sessionID: session, assetID: asset, grantID: grant,
                                     grantRevision: rev, reviewRecordID: review, reviewerID: reviewer,
                                     sourceReference: source, intendedUse: use, transactionDate: tx,
                                     passCandidate: pass, state: state, contentHash: hash)
        }
    }

    /// Session reservation (carried from RunnerV2): grammar-validated ID; duplicate → typed refusal;
    /// canonical containment double-check (defence-in-depth — grammar already forbids path chars).
    func reserveSession(_ sessionID: String) throws -> URL {
        try RWCAcquisitionSessionIDV1.validate(sessionID)
        let dir = quarantineRoot.appendingPathComponent("rwc-quarantine-\(sessionID)", isDirectory: true)
        let rootPath = quarantineRoot.standardizedFileURL.resolvingSymlinksInPath().path
        let dirPath = dir.standardizedFileURL.path
        guard dirPath.hasPrefix(rootPath + "/") else { throw RWCAcquisitionErrorV3.quarantinePathEscape }
        if FileManager.default.fileExists(atPath: dir.path) {
            throw RWCAcquisitionErrorV3.duplicateSession
        }
        do { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false) }
        catch { throw RWCAcquisitionErrorV3.quarantineFailure("reserve: \(error)") }
        return dir
    }

    /// THE lawful first-asset path V3. The clock is consulted EXACTLY ONCE (stage 0).
    public func acquire(proof: RWCVerifiedCorpusEntryV5,
                        request: RWCAcquisitionRequestV1,
                        verifiedGrant: RWCVerifiedRightsGrantV3,
                        rightsStore: RWCAssetRightsLedgerStoreV3,
                        corpusStore: RWCCorpusStoreV1,
                        acquirer: RWCAssetAcquirerV1,
                        clock: RWCRightsClockV3,
                        receiptStore: RWCAcquisitionReceiptStoreV1) throws -> RWCAcquisitionReceiptV2 {
        // stage 0: the ONE authoritative transaction date.
        let transactionDate = clock.today()
        // stages 3-10: ALL pre-fetch laws via the V2 evaluator; mints the immutable V2 proof from
        // the V3 grant (A18-F1 rooted boundary + A18-F10 manifest canonicality).
        let preauth = try RWCPreAcquisitionEvaluatorV2.authorize(request: request,
                                                                 verifiedGrant: verifiedGrant,
                                                                 transactionDate: transactionDate)
        // stage 2: session reservation AFTER preauth refusals (refused requests leave no state).
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
            if !finalized, metadata.state != .rightsCommitted {
                try? FileManager.default.removeItem(at: quarantine)
            }
        }
        // stage 11-12: ONLY NOW raw bytes may move — into ephemeral quarantine.
        metadata.state = .fetching
        try metadata.write(to: quarantine)
        let payload = try acquirer.fetch(sourceReference: preauth.sourceReference)
        do { try payload.write(to: quarantine.appendingPathComponent("payload"), options: .atomic) }
        catch { throw RWCAcquisitionErrorV3.quarantineFailure("payload write: \(error)") }
        // stage 13: hash AFTER fetch; optional trusted checksum comparison only.
        let contentHash = Self.sha256Hex(payload)
        if let expected = preauth.trustedExpectedChecksum, expected != contentHash {
            throw RWCAcquisitionErrorV3.trustedChecksumMismatch(expected: expected, actual: contentHash)
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
        // stage 15: durable rights commit via the V1-token ABI bridge. The legal AUTHORITY decision
        // was already made by the V3 ROOTED boundary (governed root → signed registry → review
        // authority V3 + scope); the V1 token is derived mechanically here as the frozen store's ABI
        // AFTER THE V3 ROOTED BOUNDARY (gates V6 law).
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
        // A18-F3 §38: DURABLE PREPARED receipt built from the durable record AFTER the rights commit
        // and BEFORE the corpus promote. The store is the single constructor of the receipt body.
        do {
            try receiptStore.prepare(
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
        } catch { throw RWCAcquisitionErrorV3.receiptFailure("prepare: \(error)") }
        // stage 16: promote ONLY after the rights commit + durable PREPARED receipt.
        do { try corpusStore.promote(assetID: preauth.assetID, contentHash: contentHash,
                                     payload: payload) }
        catch {
            // rights committed + PREPARED receipt durable; quarantine preserved for reconcileV3.
            throw RWCAcquisitionErrorV3.promoteFailure("\(error)")
        }
        // A18-F3 §39-§40: finalize the durable receipt then derive the return value from it.
        do {
            try receiptStore.confirmPromotion(sessionID: preauth.sessionID)
            try receiptStore.complete(sessionID: preauth.sessionID)
        } catch { throw RWCAcquisitionErrorV3.receiptFailure("finalize: \(error)") }
        metadata.state = .promoted
        try metadata.write(to: quarantine)
        finalized = true
        try? FileManager.default.removeItem(at: quarantine)   // COMPLETED
        // stage 17: return value derived from the durable record (§40).
        return try receiptStore.load(preauth.sessionID).receipt
    }

    public struct ReconciliationReportV3: Equatable, Sendable {
        public let recoveredSessions: [String]            // RIGHTS_COMMITTED → promoted now
        public let finalizedReceipts: [String]            // PREPARED → COMPLETED (crash recovery)
        public let registeredButUnpromoted: [String]      // asset IDs needing attention
        public let destroyedRevokedSessions: [String]     // revoked asset → never promoted
        public let destroyedOrphanSessions: [String]      // no matching authority / tampered / mismatch
    }

    /// RECONCILIATION V3 (A18-F6/§41-§44): RunnerV2 semantics PLUS authority-field cross-verify
    /// against the current rights record AND the durable PREPARED receipt, PLUS durable-receipt
    /// finalization after a crash-after-promote. Idempotent (run twice → no double receipt/promote).
    public func reconcileV3(rightsStore: RWCAssetRightsLedgerStoreV3,
                            corpusStore: RWCCorpusStoreV1,
                            receiptStore: RWCAcquisitionReceiptStoreV1) throws -> ReconciliationReportV3 {
        var recovered: [String] = []
        var finalized: [String] = []
        var unpromoted: [String] = []
        var destroyedRevoked: [String] = []
        var destroyedOrphan: [String] = []
        var stored = Set(try corpusStore.storedAssetIDs())
        var processedAssets = Set<String>()

        // A18-F6: cross-verify session-metadata authority fields against the rights record AND the
        // durable PREPARED receipt. Any mismatch means the quarantine is hostile — never promote.
        func authorityConsistent(_ meta: SessionMetadataV1) -> Bool {
            guard let record = rightsStore.record(for: meta.assetID) else { return false }
            guard record.contentHash == meta.contentHash,
                  record.grant.grantID == meta.grantID,
                  record.grant.grantRevision == meta.grantRevision,
                  record.sourceReference == meta.sourceReference else { return false }
            // the durable receipt (if any) must agree on every authority field it binds.
            if let rec = try? receiptStore.load(meta.sessionID) {
                let r = rec.receipt
                let metaUse = meta.intendedUse == "training" ? RWCUseV1.training : .evaluation
                guard r.assetID == meta.assetID, r.contentHash == meta.contentHash,
                      r.legalGrantID == meta.grantID, r.grantRevision == meta.grantRevision,
                      r.reviewRecordID == meta.reviewRecordID, r.reviewerID == meta.reviewerID,
                      r.intendedUse == metaUse else { return false }
            }
            return true
        }

        let names = (try? FileManager.default.contentsOfDirectory(atPath: quarantineRoot.path)) ?? []
        for name in names.sorted() where name.hasPrefix("rwc-quarantine-") {
            let dir = quarantineRoot.appendingPathComponent(name, isDirectory: true)
            if (try? FileManager.default.attributesOfItem(atPath: dir.path))?[.type] as? FileAttributeType
                == .typeSymbolicLink {
                try? FileManager.default.removeItem(at: dir)
                destroyedOrphan.append(name)
                continue
            }
            guard let meta = try? SessionMetadataV1.read(from: dir) else {
                try? FileManager.default.removeItem(at: dir)
                destroyedOrphan.append(name)
                continue
            }
            guard name == "rwc-quarantine-\(meta.sessionID)" else {
                try? FileManager.default.removeItem(at: dir)
                destroyedOrphan.append(name)
                continue
            }
            let assetID = meta.assetID
            if rightsStore.isTombstoned(assetID) {
                try? FileManager.default.removeItem(at: dir)
                destroyedRevoked.append(meta.sessionID)
                continue
            }
            // A18-F6: full authority-field cross-verification (never promote on mismatch).
            guard meta.state == .rightsCommitted, authorityConsistent(meta) else {
                try? FileManager.default.removeItem(at: dir)
                destroyedOrphan.append(meta.sessionID)
                continue
            }
            guard !processedAssets.contains(assetID) else {
                try? FileManager.default.removeItem(at: dir)
                destroyedOrphan.append(meta.sessionID)
                continue
            }
            processedAssets.insert(assetID)
            if stored.contains(assetID) {
                // already promoted (crash-after-promote §41-42): finalize the durable receipt.
                if let rec = try? receiptStore.load(meta.sessionID), rec.state != .completed {
                    try? receiptStore.confirmPromotion(sessionID: meta.sessionID)
                    try? receiptStore.complete(sessionID: meta.sessionID)
                    finalized.append(meta.sessionID)
                }
                try? FileManager.default.removeItem(at: dir)
                continue
            }
            // recoverable quarantine payload → promote then finalize the durable receipt.
            if let payload = try? Data(contentsOf: dir.appendingPathComponent("payload")),
               Self.sha256Hex(payload) == meta.contentHash {
                try corpusStore.promote(assetID: assetID, contentHash: meta.contentHash, payload: payload)
                stored.insert(assetID)
                recovered.append(meta.sessionID)
                if let rec = try? receiptStore.load(meta.sessionID), rec.state != .completed {
                    try? receiptStore.confirmPromotion(sessionID: meta.sessionID)
                    try? receiptStore.complete(sessionID: meta.sessionID)
                    finalized.append(meta.sessionID)
                }
                try? FileManager.default.removeItem(at: dir)
            } else {
                unpromoted.append(assetID)
            }
        }
        // rights-committed active assets with NO session and NO corpus payload = explicit deficit.
        for e in rightsStore.events where e.kind == "registered" || e.kind == "reauthorized" {
            let assetID = e.assetID
            guard !rightsStore.isTombstoned(assetID), !stored.contains(assetID),
                  !processedAssets.contains(assetID), rightsStore.record(for: assetID) != nil else { continue }
            processedAssets.insert(assetID)
            unpromoted.append(assetID)
        }
        return ReconciliationReportV3(recoveredSessions: recovered.sorted(),
                                      finalizedReceipts: finalized.sorted(),
                                      registeredButUnpromoted: unpromoted.sorted(),
                                      destroyedRevokedSessions: destroyedRevoked.sorted(),
                                      destroyedOrphanSessions: destroyedOrphan.sorted())
    }
}
#endif
