import Foundation
import CryptoKit

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC ASSET RIGHTS LEDGER STORE V4 (R6; AUDIT19 A19-F1 CRITICAL remediation).
//
// Supersedes RWCAssetRightsLedgerStoreV3 BY RECORD. The V3 store stays byte-frozen
// SUPERSEDED_ENGINEERING_HISTORY (R5 tests pin its V1-token register ABI as history). V4 closes the
// two A19-F1 root causes:
//
//   1. FORGED-V1-TOKEN REGISTER: V3.register took a PUBLIC no-crypto RWCVerifiedRightsGrantV1 token,
//      so an attacker who forged a V1 token could commit a rights record. V4.register REQUIRES an
//      unforgeable RWCVerifiedRightsGrantV6 (minted ONLY through the capability-gated trust root V2 →
//      governed current registry V2 → authority V6 chain). The V1 token can no longer register.
//
//   2. RECONCILE ACQUISITION BACKDOOR: reconcileV3 promoted any quarantine whose caller-constructed
//      metadata + receipt + rights record agreed — none unforgeable. V4 adds an UNFORGEABLE,
//      LEDGER-RESIDENT ACQUISITION AUTHORIZATION EVENT, written INSIDE the same flock-protected,
//      append-only, SHA-256-chained journal BY the authorized acquisition path at authorization time.
//      Writing it requires BOTH an RWCVerifiedRightsGrantV6 AND an RWCVerifiedCorpusEntryV5 PASS
//      proof (both fileprivate-init types an attacker cannot construct). reconcileV4
//      (RWCCorpusAcquisitionRunnerV4) promotes ONLY a session that matches a ledger-resident
//      authorization record — caller metadata/receipts can never substitute.
//
// The authorization event is use-agnostic bookkeeping over the rights chain; it is NOT a rights
// record (does not change eligibility). Its kind is "acquisition-authorized"; replay/crash laws are
// identical to V3 (roll-forward exactly-one-pending; refuse divergence; never reset to empty).
//
// ZERO-DATA: synthetic fixtures only; no production root, no real grant/media.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

public enum RWCRightsLedgerErrorV4: Error, Equatable, Sendable {
    case directoryExists
    case lockedByAnotherWriter
    case ioFailure(String)
    case witnessMissing
    case witnessMalformed
    case journalMalformed(line: Int)
    case sequenceGap(expected: Int, found: Int)
    case chainBreak(line: Int)
    case eventDigestMismatch(line: Int)
    case duplicateEvent(line: Int)
    case truncatedJournal(witnessCount: Int, journalCount: Int)
    case witnessBehindBeyondOnePending(witnessCount: Int, journalCount: Int)
    case headMismatch
    case statePayloadMalformed(line: Int)
    case verifiedGrantMismatch(reason: String)
    case authorizationMalformed(String)
    case duplicateAuthorizationSession(String)
    case authorizationRecordIntegrity(String)
}

/// An UNFORGEABLE, ledger-resident acquisition-authorization record. The marker binds every fact the
/// A19-F1 reconcile must trust to a rooted authority at WRITE time. It is constructed ONLY inside
/// RWCAssetRightsLedgerStoreV4.authorizeAcquisition (which requires the V6 grant + V5 corpus-entry
/// proof); the memberwise init is `internal` so no external consumer can fabricate one, and the only
/// way it reaches the journal is through the authorized write path.
public struct RWCAcquisitionAuthorizationRecordV1: Equatable, Sendable {
    public let sessionID: String
    public let assetID: String
    public let contentHash: String
    public let grantID: String
    public let grantRevision: Int
    public let reviewRecordID: String
    public let reviewerID: String
    public let sourceReference: String
    public let intendedUse: String             // strict "training" | "evaluation" (validated at write)
    public let registryDocumentDigest: String  // the governed current registry at authorization time
    public let rootID: String
    public let candidateCommit: String          // from the V5 corpus-entry PASS proof
    public let auditResultBlobSHA256: String
    public let transactionDate: String
    internal init(sessionID: String, assetID: String, contentHash: String, grantID: String,
                  grantRevision: Int, reviewRecordID: String, reviewerID: String,
                  sourceReference: String, intendedUse: String, registryDocumentDigest: String,
                  rootID: String, candidateCommit: String, auditResultBlobSHA256: String,
                  transactionDate: String) {
        self.sessionID = sessionID; self.assetID = assetID; self.contentHash = contentHash
        self.grantID = grantID; self.grantRevision = grantRevision; self.reviewRecordID = reviewRecordID
        self.reviewerID = reviewerID; self.sourceReference = sourceReference
        self.intendedUse = intendedUse; self.registryDocumentDigest = registryDocumentDigest
        self.rootID = rootID; self.candidateCommit = candidateCommit
        self.auditResultBlobSHA256 = auditResultBlobSHA256; self.transactionDate = transactionDate
    }

    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
    var canonicalJSON: String {
        "{\"v\":\"rwc-acq-authorization-v1\",\"session\":\"\(Self.esc(sessionID))\"," +
        "\"asset\":\"\(Self.esc(assetID))\",\"hash\":\"\(Self.esc(contentHash))\"," +
        "\"grant\":\"\(Self.esc(grantID))\",\"rev\":\(grantRevision)," +
        "\"review\":\"\(Self.esc(reviewRecordID))\",\"reviewer\":\"\(Self.esc(reviewerID))\"," +
        "\"source\":\"\(Self.esc(sourceReference))\",\"use\":\"\(Self.esc(intendedUse))\"," +
        "\"registryDoc\":\"\(Self.esc(registryDocumentDigest))\",\"root\":\"\(Self.esc(rootID))\"," +
        "\"candidate\":\"\(Self.esc(candidateCommit))\",\"auditBlob\":\"\(Self.esc(auditResultBlobSHA256))\"," +
        "\"tx\":\"\(Self.esc(transactionDate))\"}"
    }
    static func parse(_ json: [String: Any]) -> RWCAcquisitionAuthorizationRecordV1? {
        guard json["v"] as? String == "rwc-acq-authorization-v1",
              let session = json["session"] as? String, let asset = json["asset"] as? String,
              let hash = json["hash"] as? String, let grant = json["grant"] as? String,
              let rev = json["rev"] as? Int, let review = json["review"] as? String,
              let reviewer = json["reviewer"] as? String, let source = json["source"] as? String,
              let use = json["use"] as? String, let registryDoc = json["registryDoc"] as? String,
              let root = json["root"] as? String, let candidate = json["candidate"] as? String,
              let auditBlob = json["auditBlob"] as? String, let tx = json["tx"] as? String
        else { return nil }
        return RWCAcquisitionAuthorizationRecordV1(
            sessionID: session, assetID: asset, contentHash: hash, grantID: grant, grantRevision: rev,
            reviewRecordID: review, reviewerID: reviewer, sourceReference: source, intendedUse: use,
            registryDocumentDigest: registryDoc, rootID: root, candidateCommit: candidate,
            auditResultBlobSHA256: auditBlob, transactionDate: tx)
    }
}

public final class RWCAssetRightsLedgerStoreV4 {
    public static let version = "rwc-asset-rights-ledger-store-v4"
    static let journalName = "rights-journal-v4.jsonl"
    static let witnessName = "rights-head-v4.json"
    static let lockName = "rights-writer-v4.lock"

    public let directory: URL
    public private(set) var events: [RWCRightsEventV3] = []
    private var records: [String: RWCAssetRightsRecordV3] = [:]
    private var tombstoned: Set<String> = []
    private var revocationDates: [String: RWCDateV3] = [:]
    private var seenGrantIDs: [String: Set<String>] = [:]
    private var seenEvidenceDigests: [String: Set<String>] = [:]
    private var authorizations: [String: RWCAcquisitionAuthorizationRecordV1] = [:]   // sessionID -> record
    private var lastEventDate: RWCDateV3?
    private var lockFD: Int32 = -1

    public var headDigest: String { events.last?.eventDigest ?? RWCRightsEventV3.genesisDigest }
    public var eventCount: Int { events.count }
    public func isTombstoned(_ assetID: String) -> Bool { tombstoned.contains(assetID) }
    public func record(for assetID: String) -> RWCAssetRightsRecordV3? { records[assetID] }
    /// The ledger-resident acquisition authorization for a session (A19-F1), or nil if none exists.
    public func authorizationRecord(forSession sessionID: String) -> RWCAcquisitionAuthorizationRecordV1? {
        authorizations[sessionID]
    }
    /// All ledger-resident acquisition authorizations (A19-F1), sorted by sessionID.
    public func allAuthorizations() -> [RWCAcquisitionAuthorizationRecordV1] {
        authorizations.values.sorted { $0.sessionID < $1.sessionID }
    }

    private var journalURL: URL { directory.appendingPathComponent(Self.journalName) }
    private var witnessURL: URL { directory.appendingPathComponent(Self.witnessName) }
    private var lockURL: URL { directory.appendingPathComponent(Self.lockName) }

    private init(directory: URL) { self.directory = directory }
    deinit { if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD) } }
    public func closeStore() { if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD); lockFD = -1 } }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func acquireWriterLock() throws {
        let fd = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { throw RWCRightsLedgerErrorV4.ioFailure("open lock failed") }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd); throw RWCRightsLedgerErrorV4.lockedByAnotherWriter
        }
        lockFD = fd
    }

    // MARK: lifecycle

    public static func create(directory: URL) throws -> RWCAssetRightsLedgerStoreV4 {
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent(witnessName).path) {
            throw RWCRightsLedgerErrorV4.directoryExists
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = RWCAssetRightsLedgerStoreV4(directory: directory)
        try store.acquireWriterLock()
        try store.writeWitness(count: 0, head: RWCRightsEventV3.genesisDigest)
        guard FileManager.default.createFile(atPath: store.journalURL.path, contents: nil) else {
            throw RWCRightsLedgerErrorV4.ioFailure("journal create failed")
        }
        return store
    }

    public static func openExisting(directory: URL) throws -> RWCAssetRightsLedgerStoreV4 {
        let store = RWCAssetRightsLedgerStoreV4(directory: directory)
        guard FileManager.default.fileExists(atPath: store.witnessURL.path) else {
            throw RWCRightsLedgerErrorV4.witnessMissing
        }
        try store.acquireWriterLock()
        let witness = try store.readWitness()
        guard let raw = try? String(contentsOf: store.journalURL, encoding: .utf8) else {
            throw RWCRightsLedgerErrorV4.ioFailure("journal read failed")
        }
        var parsed: [RWCRightsEventV3] = []
        var partialTail = false
        var prev = RWCRightsEventV3.genesisDigest
        var seenDigests = Set<String>()
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init).filter { !$0.isEmpty }
        for (i, line) in lines.enumerated() {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  obj["v"] as? String == RWCRightsEventV3.formatVersion,
                  let seq = obj["seq"] as? Int, let p = obj["prev"] as? String,
                  let asset = obj["asset"] as? String, let kind = obj["kind"] as? String,
                  let payload = obj["payload"] as? String, let rec = obj["rec"] as? String,
                  let digest = obj["digest"] as? String else {
                if i == lines.count - 1 { partialTail = true; break }
                throw RWCRightsLedgerErrorV4.journalMalformed(line: i)
            }
            guard seq == i else { throw RWCRightsLedgerErrorV4.sequenceGap(expected: i, found: seq) }
            guard p == prev else { throw RWCRightsLedgerErrorV4.chainBreak(line: i) }
            let rebuilt = RWCRightsEventV3(seq: seq, previousDigest: p, assetID: asset, kind: kind,
                                           recordPayloadJSON: payload, recordedDate: rec)
            guard rebuilt.eventDigest == digest else { throw RWCRightsLedgerErrorV4.eventDigestMismatch(line: i) }
            guard seenDigests.insert(digest).inserted else { throw RWCRightsLedgerErrorV4.duplicateEvent(line: i) }
            parsed.append(rebuilt)
            prev = digest
        }
        if parsed.count < witness.count {
            throw RWCRightsLedgerErrorV4.truncatedJournal(witnessCount: witness.count, journalCount: parsed.count)
        }
        if parsed.count == witness.count {
            guard (parsed.last?.eventDigest ?? RWCRightsEventV3.genesisDigest) == witness.head else {
                throw RWCRightsLedgerErrorV4.headMismatch
            }
            if partialTail { try store.rewriteJournal(events: parsed) }
        } else if parsed.count == witness.count + 1 {
            let prefixHead = parsed.count >= 2 ? parsed[parsed.count - 2].eventDigest
                                               : RWCRightsEventV3.genesisDigest
            guard prefixHead == witness.head else { throw RWCRightsLedgerErrorV4.headMismatch }
            if partialTail { try store.rewriteJournal(events: parsed) }
            try store.writeWitness(count: parsed.count, head: parsed.last!.eventDigest)
        } else {
            throw RWCRightsLedgerErrorV4.witnessBehindBeyondOnePending(witnessCount: witness.count,
                                                                       journalCount: parsed.count)
        }
        for (i, e) in parsed.enumerated() {
            let recorded = try RWCDateV3.parse(e.recordedDate, field: "recordedDate")
            switch e.kind {
            case "registered", "reauthorized":
                guard let obj = try? JSONSerialization.jsonObject(with: Data(e.recordPayloadJSON.utf8))
                        as? [String: Any],
                      let record = try? RWCRightsCanonicalV3.parseRecord(obj) else {
                    throw RWCRightsLedgerErrorV4.statePayloadMalformed(line: i)
                }
                store.records[record.assetID] = record
                store.tombstoned.remove(record.assetID)
                store.seenGrantIDs[record.assetID, default: []].insert(record.grant.grantID)
                store.seenEvidenceDigests[record.assetID, default: []].insert(record.grant.evidenceDigest)
            case "revoked":
                store.tombstoned.insert(e.assetID)
                store.revocationDates[e.assetID] = recorded
            case "acquisition-authorized":
                guard let obj = try? JSONSerialization.jsonObject(with: Data(e.recordPayloadJSON.utf8))
                        as? [String: Any],
                      let authz = RWCAcquisitionAuthorizationRecordV1.parse(obj) else {
                    throw RWCRightsLedgerErrorV4.statePayloadMalformed(line: i)
                }
                store.authorizations[authz.sessionID] = authz
            default:
                throw RWCRightsLedgerErrorV4.statePayloadMalformed(line: i)
            }
            store.lastEventDate = recorded
        }
        store.events = parsed
        return store
    }

    // MARK: witness + journal (atomic temp+rename; fsync append)

    struct Witness { let count: Int; let head: String }

    private func writeWitness(count: Int, head: String) throws {
        let json = "{\"v\":\"\(Self.version)\",\"count\":\(count),\"head\":\"\(head)\"}\n"
        let tmp = directory.appendingPathComponent(Self.witnessName + ".tmp")
        do {
            try Data(json.utf8).write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: witnessURL.path) {
                _ = try FileManager.default.replaceItemAt(witnessURL, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: witnessURL)
            }
        } catch { throw RWCRightsLedgerErrorV4.ioFailure("witness write failed: \(error)") }
    }

    private func readWitness() throws -> Witness {
        guard let data = try? Data(contentsOf: witnessURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["v"] as? String == Self.version,
              let count = obj["count"] as? Int, let head = obj["head"] as? String else {
            throw RWCRightsLedgerErrorV4.witnessMalformed
        }
        return Witness(count: count, head: head)
    }

    private func rewriteJournal(events: [RWCRightsEventV3]) throws {
        let body = events.map(RWCAssetRightsLedgerStoreV4.journalLine).joined()
        let tmp = directory.appendingPathComponent(Self.journalName + ".tmp")
        try Data(body.utf8).write(to: tmp, options: .atomic)
        _ = try FileManager.default.replaceItemAt(journalURL, withItemAt: tmp)
    }

    static func journalLine(_ e: RWCRightsEventV3) -> String {
        let esc = RWCRightsCanonicalV3.esc
        return "{\"v\":\"\(RWCRightsEventV3.formatVersion)\",\"seq\":\(e.seq),\"prev\":\"\(esc(e.previousDigest))\"," +
               "\"asset\":\"\(esc(e.assetID))\",\"kind\":\"\(esc(e.kind))\"," +
               "\"payload\":\"\(esc(e.recordPayloadJSON))\",\"rec\":\"\(e.recordedDate)\"," +
               "\"digest\":\"\(esc(e.eventDigest))\"}\n"
    }

    private func commitEvent(assetID: String, kind: String, payload: String,
                             recordedDate: RWCDateV3) throws {
        let e = RWCRightsEventV3(seq: events.count, previousDigest: headDigest, assetID: assetID,
                                 kind: kind, recordPayloadJSON: payload,
                                 recordedDate: recordedDate.isoString)
        guard let handle = try? FileHandle(forWritingTo: journalURL) else {
            throw RWCRightsLedgerErrorV4.ioFailure("journal open failed")
        }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(RWCAssetRightsLedgerStoreV4.journalLine(e).utf8))
            try handle.synchronize()
        } catch { throw RWCRightsLedgerErrorV4.ioFailure("journal append failed: \(error)") }
        try writeWitness(count: events.count + 1, head: e.eventDigest)
        events.append(e)
        lastEventDate = recordedDate
    }

    // MARK: laws (carried from V3)

    private func requireMonotone(_ today: RWCDateV3, rule: String) throws {
        if let last = lastEventDate, today < last { throw RWCRightsErrorV3.chronologyViolation(rule: rule) }
    }

    private func validateRecordIntegrity(_ r: RWCAssetRightsRecordV3) throws {
        if let e = RWCAssetIdentityV1.validateAssetID(r.assetID) { throw RWCRightsErrorV3.invalidAssetID("\(e)") }
        guard r.sourceClass.eligible else { throw RWCRightsErrorV3.ineligibleSourceClass(r.sourceClass) }
        guard !r.owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RWCRightsErrorV3.missingOwner }
        guard RWCRightsReviewAuthorityV1.isToken(r.sourceReference, prefix: "rwc-source-ref-") else {
            throw RWCRightsErrorV3.invalidPointer(field: "sourceReference")
        }
        guard RWCRightsReviewAuthorityV1.isLowercaseHex64(r.contentHash) else { throw RWCRightsErrorV3.invalidContentHash }
        guard !r.provenanceChain.isEmpty else { throw RWCRightsErrorV3.emptyProvenance }
        guard Set(r.provenanceChain).count == r.provenanceChain.count else { throw RWCRightsErrorV3.duplicateProvenance }
        try RWCRightsReviewAuthorityV1.validateGrant(r.grant)
        guard r.acquisitionDate >= r.grant.effectiveDate else {
            throw RWCRightsErrorV3.acquisitionOutsideGrantValidity
        }
        if let exp = r.grant.expiryDate {
            guard r.acquisitionDate <= exp else { throw RWCRightsErrorV3.acquisitionOutsideGrantValidity }
        }
    }

    /// REGISTRATION (A19-F1 fix #1): REQUIRES an unforgeable RWCVerifiedRightsGrantV6. The public
    /// no-crypto V1 token can NO LONGER register into the R6 store.
    public func register(_ r: RWCAssetRightsRecordV3, verifiedGrant: RWCVerifiedRightsGrantV6,
                         clock: RWCRightsClockV3) throws {
        guard verifiedGrant.grant == r.grant else {
            throw RWCRightsLedgerErrorV4.verifiedGrantMismatch(reason: "verified grant != record grant")
        }
        try validateRecordIntegrity(r)
        let today = clock.today()
        try requireMonotone(today, rule: "registration recordedDate >= previous event date")
        if tombstoned.contains(r.assetID) { throw RWCRightsErrorV3.resurrectionRefused }
        if records[r.assetID] != nil { throw RWCRightsErrorV3.duplicateRegistration }
        guard r.acquisitionDate <= today else { throw RWCRightsErrorV3.acquisitionInFuture }
        if let exp = r.grant.expiryDate, exp < today { throw RWCRightsErrorV3.expiredAtRegistration }
        try commitEvent(assetID: r.assetID, kind: "registered",
                        payload: RWCRightsCanonicalV3.recordJSON(r), recordedDate: today)
        records[r.assetID] = r
        seenGrantIDs[r.assetID, default: []].insert(r.grant.grantID)
        seenEvidenceDigests[r.assetID, default: []].insert(r.grant.evidenceDigest)
    }

    public func revoke(assetID: String, clock: RWCRightsClockV3) throws {
        guard records[assetID] != nil else { throw RWCRightsErrorV3.assetUnknown }
        guard !tombstoned.contains(assetID) else { throw RWCRightsErrorV3.revoked }
        let today = clock.today()
        try requireMonotone(today, rule: "revocation recordedDate >= previous event date")
        try commitEvent(assetID: assetID, kind: "revoked", payload: "", recordedDate: today)
        tombstoned.insert(assetID)
        revocationDates[assetID] = today
    }

    public func reauthorize(_ r: RWCAssetRightsRecordV3, verifiedGrant: RWCVerifiedRightsGrantV6,
                            clock: RWCRightsClockV3) throws {
        guard verifiedGrant.grant == r.grant else {
            throw RWCRightsLedgerErrorV4.verifiedGrantMismatch(reason: "verified grant != record grant")
        }
        try validateRecordIntegrity(r)
        guard records[r.assetID] != nil else { throw RWCRightsErrorV3.assetUnknown }
        guard tombstoned.contains(r.assetID) else { throw RWCRightsErrorV3.notRevoked }
        let today = clock.today()
        try requireMonotone(today, rule: "reauthorization recordedDate >= previous event date")
        if seenGrantIDs[r.assetID, default: []].contains(r.grant.grantID) {
            throw RWCRightsErrorV3.grantAlreadyUsed
        }
        if seenEvidenceDigests[r.assetID, default: []].contains(r.grant.evidenceDigest) {
            throw RWCRightsErrorV3.evidenceAlreadyUsed
        }
        guard let revokedOn = revocationDates[r.assetID] else { throw RWCRightsErrorV3.notRevoked }
        guard r.acquisitionDate >= revokedOn else {
            throw RWCRightsErrorV3.dateOrderViolation(rule: "reauthorized acquisitionDate >= revocationDate")
        }
        guard r.acquisitionDate <= today else { throw RWCRightsErrorV3.acquisitionInFuture }
        if let exp = r.grant.expiryDate, exp < today { throw RWCRightsErrorV3.expiredAtRegistration }
        try commitEvent(assetID: r.assetID, kind: "reauthorized",
                        payload: RWCRightsCanonicalV3.recordJSON(r), recordedDate: today)
        records[r.assetID] = r
        tombstoned.remove(r.assetID)
        seenGrantIDs[r.assetID, default: []].insert(r.grant.grantID)
        seenEvidenceDigests[r.assetID, default: []].insert(r.grant.evidenceDigest)
    }

    public func requireEligible(assetID: String, use: RWCUseV1, clock: RWCRightsClockV3) throws {
        guard let r = records[assetID] else { throw RWCRightsErrorV3.assetUnknown }
        if tombstoned.contains(assetID) { throw RWCRightsErrorV3.revoked }
        let today = clock.today()
        try requireMonotone(today, rule: "eligibility query date >= last event date")
        if let exp = r.grant.expiryDate, today > exp { throw RWCRightsErrorV3.expired }
        let token = use == .training ? "training" : "evaluation"
        guard r.grant.allowedUse.contains(token), !r.grant.prohibitedUse.contains(token) else {
            throw RWCRightsErrorV3.useNotAllowed(use: token)
        }
    }

    /// A19-F1 fix #2: write the UNFORGEABLE, LEDGER-RESIDENT acquisition-authorization event. The
    /// load-bearing unforgeable gate is the RWCVerifiedRightsGrantV6 argument (rooted authority —
    /// mintable ONLY through the capability-gated trust root V2 chain closed by A19-F2, so an
    /// ordinary consumer cannot obtain one). The `candidateCommit` / `auditResultBlobSHA256` evidence
    /// is extracted by RWCCorpusAcquisitionRunnerV4 from the RWCVerifiedCorpusEntryV5 PASS proof it
    /// consumes at its own boundary (the V5 proof type lives in the RWCAcquisition module, which
    /// GuardianCore cannot import; requiring it at the RunnerV4 boundary is the lawful-path gate,
    /// while the V6 grant is the write gate here). The marker binds the session to the asset, the
    /// computed content hash, the exact grant/reviewer/source and the governed current registry
    /// digest. A caller cannot fabricate the V6 grant, so a caller cannot inject an authorization
    /// record — the precondition reconcileV4 verifies before any promotion.
    /// R7 A20-F1: this SCALAR writer is the AUDIT20-proven PRE-14-PASS bypass (it accepts free-form
    /// candidateCommit / auditResultBlobSHA256 and never binds a methodology-PASS proof). It is demoted
    /// `public → package` (declared in AUDIT20_R7_INVERSION_LOCK.md) so no EXTERNAL consumer can reach
    /// it; the lawful R7 path uses RWCAssetRightsLedgerStoreV5.authorizeAcquisitionV2(token:), which
    /// requires an RWCAcquisitionAuthorityTokenV1 mintable only by the RWCAcquisition coordinator.
    /// In-package R6 builder probes keep compiling (they use `@testable` access). Semantics unchanged.
    @discardableResult
    package func authorizeAcquisition(sessionID: String, assetID: String, contentHash: String,
                                      intendedUse: RWCUseV1, sourceReference: String,
                                      verifiedGrant: RWCVerifiedRightsGrantV6,
                                      candidateCommit: String, auditResultBlobSHA256: String,
                                      clock: RWCRightsClockV3) throws -> RWCAcquisitionAuthorizationRecordV1 {
        try RWCAcquisitionSessionIDV1.validate(sessionID)
        if authorizations[sessionID] != nil {
            throw RWCRightsLedgerErrorV4.duplicateAuthorizationSession(sessionID)
        }
        guard RWCRightsReviewAuthorityV1.isLowercaseHex64(contentHash) else {
            throw RWCRightsLedgerErrorV4.authorizationMalformed("contentHash")
        }
        // the authorized asset must have a live (non-tombstoned) rights record bound to THIS grant.
        guard let record = records[assetID], !tombstoned.contains(assetID) else {
            throw RWCRightsLedgerErrorV4.authorizationMalformed("no live rights record for asset")
        }
        guard record.grant.grantID == verifiedGrant.grant.grantID,
              record.grant.grantRevision == verifiedGrant.grant.grantRevision,
              record.contentHash == contentHash, record.sourceReference == sourceReference else {
            throw RWCRightsLedgerErrorV4.authorizationMalformed("authorization != rights record")
        }
        let today = clock.today()
        try requireMonotone(today, rule: "authorization recordedDate >= previous event date")
        let authz = RWCAcquisitionAuthorizationRecordV1(
            sessionID: sessionID, assetID: assetID, contentHash: contentHash,
            grantID: verifiedGrant.grant.grantID, grantRevision: verifiedGrant.grant.grantRevision,
            reviewRecordID: verifiedGrant.reviewRecordID, reviewerID: verifiedGrant.reviewerID,
            sourceReference: sourceReference, intendedUse: intendedUse == .training ? "training" : "evaluation",
            registryDocumentDigest: verifiedGrant.registryDocumentDigest, rootID: verifiedGrant.rootID,
            candidateCommit: candidateCommit,
            auditResultBlobSHA256: auditResultBlobSHA256,
            transactionDate: today.isoString)
        try commitEvent(assetID: assetID, kind: "acquisition-authorized",
                        payload: authz.canonicalJSON, recordedDate: today)
        authorizations[sessionID] = authz
        return authz
    }
}
