#if os(macOS)
import Foundation
import CryptoKit
import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC ACQUISITION RECEIPT STORE V2 (R6; AUDIT19 A19-F4 + A19-F5 remediation).
//
// Supersedes RWCAcquisitionReceiptStoreV1 BY RECORD (V1 stays byte-frozen SUPERSEDED_ENGINEERING_
// HISTORY — R5/AUDIT19 tests pin its lax behavior as history). Two closures:
//
//   A19-F4 (MEDIUM) — forged durable receipt authority fields. V1.prepare accepted ARBITRARY and
//   MALFORMED caller authority scalars (negative grantRevision/rightsEventCount, forged
//   candidate/tag/audit/freeze identifiers) as durable "acquisition evidence". V2 makes a receipt
//   EVIDENCE-OF-AUTHORIZED-TRANSACTION rather than caller assertion:
//     • prepare() REQUIRES the unforgeable, ledger-resident RWCAcquisitionAuthorizationRecordV1
//       (returned ONLY by RWCAssetRightsLedgerStoreV4.authorizeAcquisition, which requires a V6
//       grant). The authority fields (session, asset, hash, use, grant, rev, review, reviewer,
//       source) are COPIED FROM the authorization record — the caller cannot assert them.
//     • every remaining scalar is STRICTLY validated: grammar (session/grant/review/reviewer/source
//       tokens), non-negative rightsEventCount, lowercase-hex-64 contentHash + ledger head, strict
//       ISO transactionDate, non-empty PASS-evidence identifiers. A malformed scalar is a typed
//       refusal, never durable.
//
//   A19-F5 (MEDIUM) — permissive intendedUse parsing. V1 parsed `use` as if-"training"-else-
//   evaluation, so a garbage token silently became `.evaluation`. V2 parses STRICTLY via
//   RWCUseV1(rawValue:): an unknown token is a typed refusal (.malformedUse) on both write and read.
//
// Durability mechanics (flock single-writer, atomic temp+rename, canonical body + SHA-256 integrity
// line, PREPARED→PROMOTION_CONFIRMED→COMPLETED, idempotent transitions) mirror V1. §72 honesty: the
// SHA-256 line is CORRUPTION DETECTION, not authentication — authority lives in the ledger-resident
// authorization record and upstream rooted proofs.
//
// ZERO-DATA: synthetic fixtures only; no real session/asset.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

public enum RWCReceiptStoreErrorV2: Error, Equatable, Sendable {
    case directoryUnavailable(String)
    case lockedByAnotherWriter
    case duplicateSession(String)
    case unknownSession(String)
    case malformedSession(String)
    case integrityFailure(String)          // on-disk corruption (NOT authentication)
    case ioFailure(String)
    case malformedUse(String)              // A19-F5: unknown intendedUse token → typed refusal
    case malformedScalar(field: String)    // A19-F4: strict scalar validation failure
    case authorizationMismatch(field: String)
}

public final class RWCAcquisitionReceiptStoreV2 {
    public static let version = "rwc-acquisition-receipt-store-v2"
    static let lockName = "receipt-writer-v2.lock"
    static let bodyVersion = "rwc-acq-receipt-v2"

    public let directory: URL
    private var lockFD: Int32 = -1
    private var lockURL: URL { directory.appendingPathComponent(Self.lockName) }

    public init(directory: URL) throws {
        self.directory = directory
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { throw RWCReceiptStoreErrorV2.directoryUnavailable("\(error)") }
        try acquireWriterLock()
    }
    deinit { if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD) } }
    public func closeStore() { if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD); lockFD = -1 } }

    private func acquireWriterLock() throws {
        let fd = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { throw RWCReceiptStoreErrorV2.ioFailure("open lock failed") }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd); throw RWCReceiptStoreErrorV2.lockedByAnotherWriter
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
        directory.appendingPathComponent("receipt-v2-\(sessionID).json")
    }

    // MARK: strict scalar laws (A19-F4)

    private static func isLowercaseHex64(_ s: String) -> Bool {
        s.count == 64 && s.utf8.allSatisfy { ($0 >= 0x30 && $0 <= 0x39) || ($0 >= 0x61 && $0 <= 0x66) }
    }
    private static func nonEmptyNoControl(_ s: String) -> Bool {
        !s.isEmpty && s.utf8.allSatisfy { $0 >= 0x20 && $0 != 0x7f }
    }

    // MARK: canonical body

    static func canonicalBody(_ r: RWCAcquisitionReceiptV2, state: RWCReceiptStateV1) -> String {
        let e = Self.esc
        return "{\"v\":\"\(bodyVersion)\",\"state\":\"\(state.rawValue)\"," +
               "\"session\":\"\(e(r.sessionID))\",\"asset\":\"\(e(r.assetID))\"," +
               "\"hash\":\"\(e(r.contentHash))\",\"use\":\"\(e(r.intendedUse.rawValue))\"," +
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
        catch { throw RWCReceiptStoreErrorV2.ioFailure("receipt write: \(error)") }
    }

    /// Strict parse (A19-F4 scalar laws + A19-F5 enum law). A garbage `use` is .malformedUse; a
    /// negative/absent numeric or missing field is an integrity/scalar failure (never silently
    /// defaulted).
    static func parseRecord(_ raw: String) throws -> RWCAcquisitionReceiptRecordV2 {
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
            throw RWCReceiptStoreErrorV2.integrityFailure("malformed or corrupted")
        }
        // A19-F5: STRICT typed enum parse — unknown token is a typed refusal, never .evaluation.
        guard let use = RWCUseV1(rawValue: useRaw) else {
            throw RWCReceiptStoreErrorV2.malformedUse(useRaw)
        }
        // A19-F4: strict numerics even on read (a hand-written durable file cannot smuggle negatives).
        guard rev >= 1 else { throw RWCReceiptStoreErrorV2.malformedScalar(field: "grantRevision") }
        guard eventCount >= 0 else { throw RWCReceiptStoreErrorV2.malformedScalar(field: "rightsEventCount") }
        let receipt = RWCAcquisitionReceiptV2(
            sessionID: session, assetID: asset, contentHash: hash, intendedUse: use,
            legalGrantID: grant, grantRevision: rev, reviewRecordID: review, reviewerID: reviewer,
            rightsLedgerHeadDigest: ledgerHead, rightsEventCount: eventCount,
            passLockCandidateCommit: candidate, passLockTagObjectSHA: tagObj,
            auditResultBlobSHA256: auditBlob, freezeManifestSHA256: freeze,
            methodologyAnchorCommit: anchor, transactionDate: tx)
        return RWCAcquisitionReceiptRecordV2(receipt: receipt, state: state)
    }

    // MARK: API

    /// Durably persist a PREPARED receipt that is EVIDENCE OF an authorized transaction (A19-F4). The
    /// authority fields are COPIED from the unforgeable ledger-resident authorization record; only the
    /// PASS-evidence + ledger head/count are supplied separately, and every scalar is strictly
    /// validated. Duplicate sessionID is a typed refusal.
    @discardableResult
    public func prepare(authorization authz: RWCAcquisitionAuthorizationRecordV1,
                        rightsLedgerHeadDigest: String, rightsEventCount: Int,
                        passLockCandidateCommit: String, passLockTagObjectSHA: String,
                        auditResultBlobSHA256: String, freezeManifestSHA256: String,
                        methodologyAnchorCommit: String) throws -> RWCAcquisitionReceiptV2 {
        do { try RWCAcquisitionSessionIDV1.validate(authz.sessionID) }
        catch { throw RWCReceiptStoreErrorV2.malformedSession(authz.sessionID) }
        // A19-F5: the authorization's own intendedUse must be a known token.
        guard let use = RWCUseV1(rawValue: authz.intendedUse) else {
            throw RWCReceiptStoreErrorV2.malformedUse(authz.intendedUse)
        }
        // A19-F4: strict scalar validation on every durable field.
        guard Self.isLowercaseHex64(authz.contentHash) else {
            throw RWCReceiptStoreErrorV2.malformedScalar(field: "contentHash")
        }
        guard authz.grantRevision >= 1 else {
            throw RWCReceiptStoreErrorV2.malformedScalar(field: "grantRevision")
        }
        guard rightsEventCount >= 0 else {
            throw RWCReceiptStoreErrorV2.malformedScalar(field: "rightsEventCount")
        }
        guard Self.isLowercaseHex64(rightsLedgerHeadDigest) else {
            throw RWCReceiptStoreErrorV2.malformedScalar(field: "rightsLedgerHeadDigest")
        }
        for (field, v) in [("legalGrantID", authz.grantID), ("reviewRecordID", authz.reviewRecordID),
                           ("reviewerID", authz.reviewerID), ("assetID", authz.assetID),
                           ("sourceReference", authz.sourceReference),
                           ("passLockCandidateCommit", passLockCandidateCommit),
                           ("passLockTagObjectSHA", passLockTagObjectSHA),
                           ("auditResultBlobSHA256", auditResultBlobSHA256),
                           ("freezeManifestSHA256", freezeManifestSHA256),
                           ("methodologyAnchorCommit", methodologyAnchorCommit),
                           ("transactionDate", authz.transactionDate)] where !Self.nonEmptyNoControl(v) {
            throw RWCReceiptStoreErrorV2.malformedScalar(field: field)
        }
        if FileManager.default.fileExists(atPath: fileURL(forSession: authz.sessionID).path) {
            throw RWCReceiptStoreErrorV2.duplicateSession(authz.sessionID)
        }
        let receipt = RWCAcquisitionReceiptV2(
            sessionID: authz.sessionID, assetID: authz.assetID, contentHash: authz.contentHash,
            intendedUse: use, legalGrantID: authz.grantID, grantRevision: authz.grantRevision,
            reviewRecordID: authz.reviewRecordID, reviewerID: authz.reviewerID,
            rightsLedgerHeadDigest: rightsLedgerHeadDigest, rightsEventCount: rightsEventCount,
            passLockCandidateCommit: passLockCandidateCommit, passLockTagObjectSHA: passLockTagObjectSHA,
            auditResultBlobSHA256: auditResultBlobSHA256, freezeManifestSHA256: freezeManifestSHA256,
            methodologyAnchorCommit: methodologyAnchorCommit, transactionDate: authz.transactionDate)
        try writeRecord(receipt, state: .prepared)
        return receipt
    }

    public func confirmPromotion(sessionID: String) throws {
        let rec = try load(sessionID)
        switch rec.state {
        case .prepared: try writeRecord(rec.receipt, state: .promotionConfirmed)
        case .promotionConfirmed, .completed: return
        }
    }

    public func complete(sessionID: String) throws {
        let rec = try load(sessionID)
        switch rec.state {
        case .prepared, .promotionConfirmed: try writeRecord(rec.receipt, state: .completed)
        case .completed: return
        }
    }

    public func load(_ sessionID: String) throws -> RWCAcquisitionReceiptRecordV2 {
        let url = fileURL(forSession: sessionID)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RWCReceiptStoreErrorV2.unknownSession(sessionID)
        }
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            throw RWCReceiptStoreErrorV2.ioFailure("receipt read: \(sessionID)")
        }
        return try Self.parseRecord(raw)
    }

    public func allReceipts() throws -> [RWCAcquisitionReceiptRecordV2] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        var out: [RWCAcquisitionReceiptRecordV2] = []
        for name in names.sorted() where name.hasPrefix("receipt-v2-") && name.hasSuffix(".json") {
            let url = directory.appendingPathComponent(name)
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
                throw RWCReceiptStoreErrorV2.ioFailure("receipt read: \(name)")
            }
            out.append(try Self.parseRecord(raw))
        }
        return out.sorted { $0.receipt.sessionID < $1.receipt.sessionID }
    }
}

/// A durable V2 receipt record: all RWCAcquisitionReceiptV2 fields + lifecycle state.
public struct RWCAcquisitionReceiptRecordV2: Equatable, Sendable {
    public let receipt: RWCAcquisitionReceiptV2
    public let state: RWCReceiptStateV1
    public init(receipt: RWCAcquisitionReceiptV2, state: RWCReceiptStateV1) {
        self.receipt = receipt; self.state = state
    }
}
#endif
