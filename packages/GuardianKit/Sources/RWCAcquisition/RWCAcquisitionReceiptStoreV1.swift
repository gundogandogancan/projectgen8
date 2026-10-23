#if os(macOS)
import Foundation
import CryptoKit
import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC ACQUISITION RECEIPT STORE V1 (R5; AUDIT18 A18-F3 remediation; §35-§45, §69-§73).
//
// A18-F3 root cause: the RunnerV2 acquisition receipt was an IN-MEMORY return value only. A crash
// AFTER corpus promotion but before the caller persisted the receipt left no durable record that
// the asset had completed acquisition — reconciliation saw a promoted asset with no receipt and
// could neither confirm completion nor distinguish it from an unaudited intruder.
//
// R5 installs a DURABLE, single-writer receipt store in a dedicated directory. Mechanics mirror the
// frozen RWCAssetRightsLedgerStoreV3 pattern (flock single-writer for the store's lifetime; atomic
// temp+rename writes; canonical body + SHA-256 integrity line). Each receipt is one file named by
// sessionID; its state advances PREPARED → PROMOTION_CONFIRMED → COMPLETED.
//
// HONEST WORDING (§72): the SHA-256 line is an INTEGRITY check (CORRUPTION DETECTION on the local
// disk) — NOT tamper-proof AUTHENTICATION. An adversary with write access to the store directory
// can rewrite both body and digest; the receipt is evidence of a completed governed acquisition for
// crash recovery, not an unforgeable attestation. Unforgeable authority lives upstream in the
// signed review / verified grant / verified corpus-entry proof.
//
// STATE LAW (§38-§45): prepare() writes PREPARED durably AFTER the rights commit and BEFORE corpus
// promotion; confirmPromotion() advances to PROMOTION_CONFIRMED right after a successful promote;
// complete() finalizes COMPLETED. Transitions are idempotent and ordered: re-confirming a confirmed
// receipt is a deterministic no-op; completing a prepared receipt confirms then completes.
//
// ZERO-DATA: synthetic fixtures only; no real session, no real asset.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

public enum RWCReceiptStoreErrorV1: Error, Equatable, Sendable {
    case directoryUnavailable(String)
    case lockedByAnotherWriter
    case duplicateSession(String)
    case unknownSession(String)
    case malformedSession(String)
    case integrityFailure(String)       // on-disk corruption detected (NOT authentication)
    case ioFailure(String)
    case illegalTransition(from: String, to: String)
}

public enum RWCReceiptStateV1: String, Sendable, Equatable {
    case prepared = "PREPARED"
    case promotionConfirmed = "PROMOTION_CONFIRMED"
    case completed = "COMPLETED"
}

/// A durable receipt record: all RWCAcquisitionReceiptV2 fields + the lifecycle state.
public struct RWCAcquisitionReceiptRecordV1: Equatable, Sendable {
    public let receipt: RWCAcquisitionReceiptV2
    public let state: RWCReceiptStateV1
    public init(receipt: RWCAcquisitionReceiptV2, state: RWCReceiptStateV1) {
        self.receipt = receipt; self.state = state
    }
}

public final class RWCAcquisitionReceiptStoreV1 {
    public static let version = "rwc-acquisition-receipt-store-v1"
    static let lockName = "receipt-writer-v1.lock"
    static let bodyVersion = "rwc-acq-receipt-v1"

    public let directory: URL
    private var lockFD: Int32 = -1

    private var lockURL: URL { directory.appendingPathComponent(Self.lockName) }

    /// Create (or attach to) the receipt directory and hold the single-writer lock for life.
    public init(directory: URL) throws {
        self.directory = directory
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { throw RWCReceiptStoreErrorV1.directoryUnavailable("\(error)") }
        try acquireWriterLock()
    }

    deinit { if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD) } }

    public func closeStore() {
        if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD); lockFD = -1 }
    }

    private func acquireWriterLock() throws {
        let fd = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { throw RWCReceiptStoreErrorV1.ioFailure("open lock failed") }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            throw RWCReceiptStoreErrorV1.lockedByAnotherWriter
        }
        lockFD = fd
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func fileURL(forSession sessionID: String) -> URL {
        directory.appendingPathComponent("receipt-\(sessionID).json")
    }

    // MARK: canonical fixed-order body (A18-F3; §72 honest naming)

    static func canonicalBody(_ r: RWCAcquisitionReceiptV2, state: RWCReceiptStateV1) -> String {
        let e = Self.esc
        return "{\"v\":\"\(bodyVersion)\",\"state\":\"\(state.rawValue)\"," +
               "\"session\":\"\(e(r.sessionID))\",\"asset\":\"\(e(r.assetID))\"," +
               "\"hash\":\"\(e(r.contentHash))\",\"use\":\"\(e(r.intendedUse == .training ? "training" : "evaluation"))\"," +
               "\"grant\":\"\(e(r.legalGrantID))\",\"rev\":\(r.grantRevision)," +
               "\"review\":\"\(e(r.reviewRecordID))\",\"reviewer\":\"\(e(r.reviewerID))\"," +
               "\"ledgerHead\":\"\(e(r.rightsLedgerHeadDigest))\",\"eventCount\":\(r.rightsEventCount)," +
               "\"candidate\":\"\(e(r.passLockCandidateCommit))\",\"tagObj\":\"\(e(r.passLockTagObjectSHA))\"," +
               "\"auditBlob\":\"\(e(r.auditResultBlobSHA256))\",\"freeze\":\"\(e(r.freezeManifestSHA256))\"," +
               "\"anchor\":\"\(e(r.methodologyAnchorCommit))\",\"tx\":\"\(e(r.transactionDate))\"}"
    }

    private func writeRecord(_ r: RWCAcquisitionReceiptV2, state: RWCReceiptStateV1) throws {
        let body = Self.canonicalBody(r, state: state)
        let line = body + "\n" + Self.sha256Hex(Data(body.utf8)) + "\n"
        do { try Data(line.utf8).write(to: fileURL(forSession: r.sessionID), options: .atomic) }
        catch { throw RWCReceiptStoreErrorV1.ioFailure("receipt write: \(error)") }
    }

    static func parseRecord(_ raw: String) throws -> RWCAcquisitionReceiptRecordV1 {
        let parts = raw.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard parts.count == 2, sha256Hex(Data(parts[0].utf8)) == parts[1],
              let obj = try? JSONSerialization.jsonObject(with: Data(parts[0].utf8)) as? [String: Any],
              obj["v"] as? String == bodyVersion,
              let stateRaw = obj["state"] as? String, let state = RWCReceiptStateV1(rawValue: stateRaw),
              let session = obj["session"] as? String, let asset = obj["asset"] as? String,
              let hash = obj["hash"] as? String, let useRaw = obj["use"] as? String,
              let grant = obj["grant"] as? String, let rev = obj["rev"] as? Int,
              let review = obj["review"] as? String, let reviewer = obj["reviewer"] as? String,
              let ledgerHead = obj["ledgerHead"] as? String, let eventCount = obj["eventCount"] as? Int,
              let candidate = obj["candidate"] as? String, let tagObj = obj["tagObj"] as? String,
              let auditBlob = obj["auditBlob"] as? String, let freeze = obj["freeze"] as? String,
              let anchor = obj["anchor"] as? String, let tx = obj["tx"] as? String else {
            throw RWCReceiptStoreErrorV1.integrityFailure("malformed or corrupted")
        }
        let receipt = RWCAcquisitionReceiptV2(
            sessionID: session, assetID: asset, contentHash: hash,
            intendedUse: useRaw == "training" ? .training : .evaluation,
            legalGrantID: grant, grantRevision: rev, reviewRecordID: review, reviewerID: reviewer,
            rightsLedgerHeadDigest: ledgerHead, rightsEventCount: eventCount,
            passLockCandidateCommit: candidate, passLockTagObjectSHA: tagObj,
            auditResultBlobSHA256: auditBlob, freezeManifestSHA256: freeze,
            methodologyAnchorCommit: anchor, transactionDate: tx)
        return RWCAcquisitionReceiptRecordV1(receipt: receipt, state: state)
    }

    // MARK: API

    /// Durably persist a PREPARED receipt from its scalar fields (the internal RWCAcquisitionReceiptV2
    /// memberwise init is module-internal; callers outside the module pass fields, keeping the store
    /// the single constructor of the receipt body). Duplicate sessionID is a typed refusal (atomic
    /// write, so a crash during write leaves either the old file or a complete new one).
    @discardableResult
    public func prepare(sessionID: String, assetID: String, contentHash: String,
                        intendedUse: RWCUseV1, legalGrantID: String, grantRevision: Int,
                        reviewRecordID: String, reviewerID: String, rightsLedgerHeadDigest: String,
                        rightsEventCount: Int, passLockCandidateCommit: String,
                        passLockTagObjectSHA: String, auditResultBlobSHA256: String,
                        freezeManifestSHA256: String, methodologyAnchorCommit: String,
                        transactionDate: String) throws -> RWCAcquisitionReceiptV2 {
        try RWCAcquisitionSessionIDV1.validate(sessionID)
        if FileManager.default.fileExists(atPath: fileURL(forSession: sessionID).path) {
            throw RWCReceiptStoreErrorV1.duplicateSession(sessionID)
        }
        let receipt = RWCAcquisitionReceiptV2(
            sessionID: sessionID, assetID: assetID, contentHash: contentHash, intendedUse: intendedUse,
            legalGrantID: legalGrantID, grantRevision: grantRevision, reviewRecordID: reviewRecordID,
            reviewerID: reviewerID, rightsLedgerHeadDigest: rightsLedgerHeadDigest,
            rightsEventCount: rightsEventCount, passLockCandidateCommit: passLockCandidateCommit,
            passLockTagObjectSHA: passLockTagObjectSHA, auditResultBlobSHA256: auditResultBlobSHA256,
            freezeManifestSHA256: freezeManifestSHA256, methodologyAnchorCommit: methodologyAnchorCommit,
            transactionDate: transactionDate)
        try writeRecord(receipt, state: .prepared)
        return receipt
    }

    /// Advance PREPARED → PROMOTION_CONFIRMED. Idempotent: re-confirming a confirmed (or completed)
    /// receipt is a deterministic no-op (returns without error). Unknown session is a typed refusal.
    public func confirmPromotion(sessionID: String) throws {
        let rec = try load(sessionID)
        switch rec.state {
        case .prepared: try writeRecord(rec.receipt, state: .promotionConfirmed)
        case .promotionConfirmed, .completed: return   // idempotent no-op
        }
    }

    /// Advance to COMPLETED. From PREPARED this implicitly passes through PROMOTION_CONFIRMED (the
    /// recorded final state is COMPLETED). Idempotent on an already-completed receipt.
    public func complete(sessionID: String) throws {
        let rec = try load(sessionID)
        switch rec.state {
        case .prepared, .promotionConfirmed: try writeRecord(rec.receipt, state: .completed)
        case .completed: return   // idempotent no-op
        }
    }

    public func load(_ sessionID: String) throws -> RWCAcquisitionReceiptRecordV1 {
        let url = fileURL(forSession: sessionID)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RWCReceiptStoreErrorV1.unknownSession(sessionID)
        }
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            throw RWCReceiptStoreErrorV1.ioFailure("receipt read: \(sessionID)")
        }
        return try Self.parseRecord(raw)
    }

    /// All durable receipts, sorted by sessionID. A corrupted file is surfaced as an integrity
    /// failure (never silently dropped) so reconciliation can flag it.
    public func allReceipts() throws -> [RWCAcquisitionReceiptRecordV1] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        var out: [RWCAcquisitionReceiptRecordV1] = []
        for name in names.sorted() where name.hasPrefix("receipt-") && name.hasSuffix(".json") {
            let url = directory.appendingPathComponent(name)
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
                throw RWCReceiptStoreErrorV1.ioFailure("receipt read: \(name)")
            }
            out.append(try Self.parseRecord(raw))
        }
        return out.sorted { $0.receipt.sessionID < $1.receipt.sessionID }
    }
}
#endif
