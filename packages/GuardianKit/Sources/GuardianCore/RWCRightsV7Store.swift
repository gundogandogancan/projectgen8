import Foundation
import CryptoKit

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC ASSET RIGHTS LEDGER STORE V5 (R7; AUDIT20 A20-F1/F3/F4 + R-6 remediation) — supersedes
// RWCAssetRightsLedgerStoreV4 BY RECORD. V4 stays byte-frozen SUPERSEDED_ENGINEERING_HISTORY (its
// scalar `authorizeAcquisition` is the AUDIT20-proven A20-F1 PRE-14-PASS bypass; R6 tests pin that
// history, and the scalar method is sealed `public → package` in R7 so no EXTERNAL consumer can reach
// it while in-package historical probes keep compiling).
//
// IMPLEMENTED_UNVERIFIED: authored in a sandbox that cannot compile/run `swift test`. The main session
// MUST compile, run the full suite green ×2, and iterate before this is an audit candidate. Do NOT
// treat as TESTED until the main-session evidence exists.
//
// A20 COMMON CAUSE (closed here at ONE boundary): V4.authorizeAcquisition wrote the ledger-resident
// authorization record (the precondition reconcileV4 trusts to promote) from CALLER SCALARS
// (candidateCommit / auditResultBlobSHA256), a rights-only V6 grant and a verbatim intendedUse, with
// no methodology-PASS proof, no intended-use check against the grant, and no CURRENT-registry recheck.
// Because the PRE-14 PASS proof type (RWCVerifiedCorpusEntryV5/V6) lives in the RWCAcquisition module
// and GuardianCore cannot import it (acyclic), the write gate could not require it.
//
// R7 CLOSURE — the SEALED AUTHORITY TOKEN. `RWCAcquisitionAuthorityTokenV1` is declared HERE in
// GuardianCore (so the store can name it) but its init is `package`: only GuardianKit-package code can
// mint it, and by design discipline ONLY RWCCorpusAcquisitionRunnerV5.mintAuthorityToken does — after
// RWCCorpusEntryVerifierV6.verify (methodology PASS), RWCPreAcquisitionEvaluatorV3.authorize (source +
// intended-use) and a current-registry currentness recheck. The token carries the PROOF IDENTITY, the
// evaluator-validated acquisition facts and the current-registry witness. authorizeAcquisitionV2
// REQUIRES the token (no scalars), re-checks intended-use (A20-F3) and current reviewer authority
// (A20-F4), and writes the FULL proof identity into RWCAcquisitionAuthorizationRecordV2 so crash
// recovery can reconstruct a durable receipt (R-6). See
// docs/calibration/preregistration/RWC_R7_AUTHORITY_CONVERGENCE_DESIGN.md (authoritative §2).
//
// ZERO-DATA: synthetic fixtures only; no production root, no real grant/media, no PASS lock.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

public enum RWCRightsLedgerErrorV5: Error, Equatable, Sendable {
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
    case useNotAuthorized(use: String)          // A20-F3: intended use not permitted by the grant
    case reviewerNotCurrent(stage: String)      // A20-F4: grant's reviewer not ACTIVE in the current head
    case tokenBindingMismatch(field: String)    // token facts != grant / record facts
}

/// SEALED ACQUISITION AUTHORITY TOKEN (A20-F1). The opaque, structured authority object the R7 ledger
/// write requires. Declared in GuardianCore so `authorizeAcquisitionV2` can name it; its init is
/// `package`, so ONLY GuardianKit-package code can mint it. By design discipline the ONLY minter is
/// `RWCCorpusAcquisitionRunnerV5.mintAuthorityToken` (RWCAcquisition module) — after:
///   (1) RWCCorpusEntryVerifierV6.verify returned a PRE-14 PASS proof (methodology authority),
///   (2) RWCPreAcquisitionEvaluatorV3.authorize validated source + intended-use,
///   (3) a current-registry currentness recheck passed.
/// It is NEVER a free-form scalar / SHA string / JSON digest: it carries the proof identity, the
/// evaluator-validated facts and the current-registry witness captured at mint time. The token is
/// process-local and NEVER persisted — the durable identity lives in RWCAcquisitionAuthorizationRecordV2.
public struct RWCAcquisitionAuthorityTokenV1: Sendable, Equatable {
    // (1) methodology-PASS proof identity (copied from RWCVerifiedCorpusEntryV6)
    public let candidateCommit: String
    public let candidateTagObjectSHA: String
    public let auditCommit: String
    public let auditResultBlobSHA256: String
    public let methodologyAnchorCommit: String
    public let freezeManifestSHA256: String
    public let frozenInventoryDigest: String
    // (2) evaluator-validated acquisition facts (from RWCPreAcquisitionAuthorizationV3)
    public let sessionID: String
    public let assetID: String
    public let sourceReference: String
    public let intendedUseToken: String        // strict "training" | "evaluation"
    public let grantID: String
    public let grantRevision: Int
    // (3) current-registry witness captured at mint time (A20-F4)
    public let currentRegistryRootID: String
    public let currentRegistryRevision: Int
    public let currentRegistryDocumentDigest: String

    /// `package` init — mintable ONLY inside the GuardianKit package, disciplined to RunnerV5.
    package init(candidateCommit: String, candidateTagObjectSHA: String, auditCommit: String,
                 auditResultBlobSHA256: String, methodologyAnchorCommit: String,
                 freezeManifestSHA256: String, frozenInventoryDigest: String,
                 sessionID: String, assetID: String, sourceReference: String, intendedUseToken: String,
                 grantID: String, grantRevision: Int,
                 currentRegistryRootID: String, currentRegistryRevision: Int,
                 currentRegistryDocumentDigest: String) {
        self.candidateCommit = candidateCommit; self.candidateTagObjectSHA = candidateTagObjectSHA
        self.auditCommit = auditCommit; self.auditResultBlobSHA256 = auditResultBlobSHA256
        self.methodologyAnchorCommit = methodologyAnchorCommit
        self.freezeManifestSHA256 = freezeManifestSHA256; self.frozenInventoryDigest = frozenInventoryDigest
        self.sessionID = sessionID; self.assetID = assetID; self.sourceReference = sourceReference
        self.intendedUseToken = intendedUseToken; self.grantID = grantID; self.grantRevision = grantRevision
        self.currentRegistryRootID = currentRegistryRootID
        self.currentRegistryRevision = currentRegistryRevision
        self.currentRegistryDocumentDigest = currentRegistryDocumentDigest
    }
}

/// UNFORGEABLE, ledger-resident acquisition-authorization record V2 (R7). Like V1 but additionally
/// carries the FULL PRE-14 PASS-proof identity (tagObj / auditCommit / anchor / freeze / inventory) so
/// crash recovery can RECONSTRUCT a durable receipt from authenticated ledger evidence (R-6). Its
/// memberwise init is `internal`; the only way it reaches the journal is through authorizeAcquisitionV2,
/// which requires an RWCAcquisitionAuthorityTokenV1.
public struct RWCAcquisitionAuthorizationRecordV2: Equatable, Sendable {
    public let sessionID: String
    public let assetID: String
    public let contentHash: String
    public let grantID: String
    public let grantRevision: Int
    public let reviewRecordID: String
    public let reviewerID: String
    public let sourceReference: String
    public let intendedUse: String
    public let registryDocumentDigest: String
    public let rootID: String
    // full PASS-proof identity (A20-F1 + R-6 receipt reconstruction)
    public let candidateCommit: String
    public let candidateTagObjectSHA: String
    public let auditCommit: String
    public let auditResultBlobSHA256: String
    public let methodologyAnchorCommit: String
    public let freezeManifestSHA256: String
    public let frozenInventoryDigest: String
    public let transactionDate: String

    internal init(sessionID: String, assetID: String, contentHash: String, grantID: String,
                  grantRevision: Int, reviewRecordID: String, reviewerID: String, sourceReference: String,
                  intendedUse: String, registryDocumentDigest: String, rootID: String,
                  candidateCommit: String, candidateTagObjectSHA: String, auditCommit: String,
                  auditResultBlobSHA256: String, methodologyAnchorCommit: String,
                  freezeManifestSHA256: String, frozenInventoryDigest: String, transactionDate: String) {
        self.sessionID = sessionID; self.assetID = assetID; self.contentHash = contentHash
        self.grantID = grantID; self.grantRevision = grantRevision; self.reviewRecordID = reviewRecordID
        self.reviewerID = reviewerID; self.sourceReference = sourceReference; self.intendedUse = intendedUse
        self.registryDocumentDigest = registryDocumentDigest; self.rootID = rootID
        self.candidateCommit = candidateCommit; self.candidateTagObjectSHA = candidateTagObjectSHA
        self.auditCommit = auditCommit; self.auditResultBlobSHA256 = auditResultBlobSHA256
        self.methodologyAnchorCommit = methodologyAnchorCommit; self.freezeManifestSHA256 = freezeManifestSHA256
        self.frozenInventoryDigest = frozenInventoryDigest; self.transactionDate = transactionDate
    }

    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
    var canonicalJSON: String {
        "{\"v\":\"rwc-acq-authorization-v2\",\"session\":\"\(Self.esc(sessionID))\"," +
        "\"asset\":\"\(Self.esc(assetID))\",\"hash\":\"\(Self.esc(contentHash))\"," +
        "\"grant\":\"\(Self.esc(grantID))\",\"rev\":\(grantRevision)," +
        "\"review\":\"\(Self.esc(reviewRecordID))\",\"reviewer\":\"\(Self.esc(reviewerID))\"," +
        "\"source\":\"\(Self.esc(sourceReference))\",\"use\":\"\(Self.esc(intendedUse))\"," +
        "\"registryDoc\":\"\(Self.esc(registryDocumentDigest))\",\"root\":\"\(Self.esc(rootID))\"," +
        "\"candidate\":\"\(Self.esc(candidateCommit))\",\"tagObj\":\"\(Self.esc(candidateTagObjectSHA))\"," +
        "\"auditCommit\":\"\(Self.esc(auditCommit))\",\"auditBlob\":\"\(Self.esc(auditResultBlobSHA256))\"," +
        "\"anchor\":\"\(Self.esc(methodologyAnchorCommit))\",\"freeze\":\"\(Self.esc(freezeManifestSHA256))\"," +
        "\"inventory\":\"\(Self.esc(frozenInventoryDigest))\",\"tx\":\"\(Self.esc(transactionDate))\"}"
    }
    static func parse(_ json: [String: Any]) -> RWCAcquisitionAuthorizationRecordV2? {
        guard json["v"] as? String == "rwc-acq-authorization-v2",
              let session = json["session"] as? String, let asset = json["asset"] as? String,
              let hash = json["hash"] as? String, let grant = json["grant"] as? String,
              let rev = json["rev"] as? Int, let review = json["review"] as? String,
              let reviewer = json["reviewer"] as? String, let source = json["source"] as? String,
              let use = json["use"] as? String, let registryDoc = json["registryDoc"] as? String,
              let root = json["root"] as? String, let candidate = json["candidate"] as? String,
              let tagObj = json["tagObj"] as? String, let auditCommit = json["auditCommit"] as? String,
              let auditBlob = json["auditBlob"] as? String, let anchor = json["anchor"] as? String,
              let freeze = json["freeze"] as? String, let inventory = json["inventory"] as? String,
              let tx = json["tx"] as? String
        else { return nil }
        return RWCAcquisitionAuthorizationRecordV2(
            sessionID: session, assetID: asset, contentHash: hash, grantID: grant, grantRevision: rev,
            reviewRecordID: review, reviewerID: reviewer, sourceReference: source, intendedUse: use,
            registryDocumentDigest: registryDoc, rootID: root, candidateCommit: candidate,
            candidateTagObjectSHA: tagObj, auditCommit: auditCommit, auditResultBlobSHA256: auditBlob,
            methodologyAnchorCommit: anchor, freezeManifestSHA256: freeze, frozenInventoryDigest: inventory,
            transactionDate: tx)
    }

    /// Is the PASS-proof identity complete (R-6 receipt-reconstruction precondition)?
    public var hasCompleteProofIdentity: Bool {
        !candidateCommit.isEmpty && !candidateTagObjectSHA.isEmpty && !auditCommit.isEmpty
        && !auditResultBlobSHA256.isEmpty && !methodologyAnchorCommit.isEmpty
        && !freezeManifestSHA256.isEmpty && !frozenInventoryDigest.isEmpty
    }
}

public final class RWCAssetRightsLedgerStoreV5 {
    public static let version = "rwc-asset-rights-ledger-store-v5"
    static let journalName = "rights-journal-v5.jsonl"
    static let witnessName = "rights-head-v5.json"
    static let lockName = "rights-writer-v5.lock"

    public let directory: URL
    public private(set) var events: [RWCRightsEventV3] = []
    private var records: [String: RWCAssetRightsRecordV3] = [:]
    private var tombstoned: Set<String> = []
    private var revocationDates: [String: RWCDateV3] = [:]
    private var seenGrantIDs: [String: Set<String>] = [:]
    private var seenEvidenceDigests: [String: Set<String>] = [:]
    private var authorizations: [String: RWCAcquisitionAuthorizationRecordV2] = [:]
    private var lastEventDate: RWCDateV3?
    private var lockFD: Int32 = -1

    public var headDigest: String { events.last?.eventDigest ?? RWCRightsEventV3.genesisDigest }
    public var eventCount: Int { events.count }
    public func isTombstoned(_ assetID: String) -> Bool { tombstoned.contains(assetID) }
    public func record(for assetID: String) -> RWCAssetRightsRecordV3? { records[assetID] }
    public func authorizationRecord(forSession sessionID: String) -> RWCAcquisitionAuthorizationRecordV2? {
        authorizations[sessionID]
    }
    public func allAuthorizations() -> [RWCAcquisitionAuthorizationRecordV2] {
        authorizations.values.sorted { $0.sessionID < $1.sessionID }
    }

    private var journalURL: URL { directory.appendingPathComponent(Self.journalName) }
    private var witnessURL: URL { directory.appendingPathComponent(Self.witnessName) }
    private var lockURL: URL { directory.appendingPathComponent(Self.lockName) }

    private init(directory: URL) { self.directory = directory }
    deinit { if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD) } }
    public func closeStore() { if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD); lockFD = -1 } }

    private func acquireWriterLock() throws {
        let fd = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { throw RWCRightsLedgerErrorV5.ioFailure("open lock failed") }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd); throw RWCRightsLedgerErrorV5.lockedByAnotherWriter
        }
        lockFD = fd
    }

    // MARK: lifecycle (durability mechanics identical to the AUDIT-verified V4 store)

    public static func create(directory: URL) throws -> RWCAssetRightsLedgerStoreV5 {
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent(witnessName).path) {
            throw RWCRightsLedgerErrorV5.directoryExists
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = RWCAssetRightsLedgerStoreV5(directory: directory)
        try store.acquireWriterLock()
        try store.writeWitness(count: 0, head: RWCRightsEventV3.genesisDigest)
        guard FileManager.default.createFile(atPath: store.journalURL.path, contents: nil) else {
            throw RWCRightsLedgerErrorV5.ioFailure("journal create failed")
        }
        return store
    }

    public static func openExisting(directory: URL) throws -> RWCAssetRightsLedgerStoreV5 {
        let store = RWCAssetRightsLedgerStoreV5(directory: directory)
        guard FileManager.default.fileExists(atPath: store.witnessURL.path) else {
            throw RWCRightsLedgerErrorV5.witnessMissing
        }
        try store.acquireWriterLock()
        let witness = try store.readWitness()
        guard let raw = try? String(contentsOf: store.journalURL, encoding: .utf8) else {
            throw RWCRightsLedgerErrorV5.ioFailure("journal read failed")
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
                  let payload = obj["payload"] as? String, let _ = obj["rec"] as? String,
                  let digest = obj["digest"] as? String else {
                if i == lines.count - 1 { partialTail = true; break }
                throw RWCRightsLedgerErrorV5.journalMalformed(line: i)
            }
            let rec = obj["rec"] as! String
            guard seq == i else { throw RWCRightsLedgerErrorV5.sequenceGap(expected: i, found: seq) }
            guard p == prev else { throw RWCRightsLedgerErrorV5.chainBreak(line: i) }
            let rebuilt = RWCRightsEventV3(seq: seq, previousDigest: p, assetID: asset, kind: kind,
                                           recordPayloadJSON: payload, recordedDate: rec)
            guard rebuilt.eventDigest == digest else { throw RWCRightsLedgerErrorV5.eventDigestMismatch(line: i) }
            guard seenDigests.insert(digest).inserted else { throw RWCRightsLedgerErrorV5.duplicateEvent(line: i) }
            parsed.append(rebuilt)
            prev = digest
        }
        if parsed.count < witness.count {
            throw RWCRightsLedgerErrorV5.truncatedJournal(witnessCount: witness.count, journalCount: parsed.count)
        }
        if parsed.count == witness.count {
            guard (parsed.last?.eventDigest ?? RWCRightsEventV3.genesisDigest) == witness.head else {
                throw RWCRightsLedgerErrorV5.headMismatch
            }
            if partialTail { try store.rewriteJournal(events: parsed) }
        } else if parsed.count == witness.count + 1 {
            let prefixHead = parsed.count >= 2 ? parsed[parsed.count - 2].eventDigest
                                               : RWCRightsEventV3.genesisDigest
            guard prefixHead == witness.head else { throw RWCRightsLedgerErrorV5.headMismatch }
            if partialTail { try store.rewriteJournal(events: parsed) }
            try store.writeWitness(count: parsed.count, head: parsed.last!.eventDigest)
        } else {
            throw RWCRightsLedgerErrorV5.witnessBehindBeyondOnePending(witnessCount: witness.count,
                                                                       journalCount: parsed.count)
        }
        for (i, e) in parsed.enumerated() {
            let recorded = try RWCDateV3.parse(e.recordedDate, field: "recordedDate")
            switch e.kind {
            case "registered", "reauthorized":
                guard let obj = try? JSONSerialization.jsonObject(with: Data(e.recordPayloadJSON.utf8))
                        as? [String: Any],
                      let record = try? RWCRightsCanonicalV3.parseRecord(obj) else {
                    throw RWCRightsLedgerErrorV5.statePayloadMalformed(line: i)
                }
                store.records[record.assetID] = record
                store.tombstoned.remove(record.assetID)
                store.seenGrantIDs[record.assetID, default: []].insert(record.grant.grantID)
                store.seenEvidenceDigests[record.assetID, default: []].insert(record.grant.evidenceDigest)
            case "revoked":
                store.tombstoned.insert(e.assetID)
                store.revocationDates[e.assetID] = recorded
            case "acquisition-authorized-v2":
                guard let obj = try? JSONSerialization.jsonObject(with: Data(e.recordPayloadJSON.utf8))
                        as? [String: Any],
                      let authz = RWCAcquisitionAuthorizationRecordV2.parse(obj) else {
                    throw RWCRightsLedgerErrorV5.statePayloadMalformed(line: i)
                }
                store.authorizations[authz.sessionID] = authz
            default:
                throw RWCRightsLedgerErrorV5.statePayloadMalformed(line: i)
            }
            store.lastEventDate = recorded
        }
        store.events = parsed
        return store
    }

    // MARK: witness + journal

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
        } catch { throw RWCRightsLedgerErrorV5.ioFailure("witness write failed: \(error)") }
    }

    private func readWitness() throws -> Witness {
        guard let data = try? Data(contentsOf: witnessURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["v"] as? String == Self.version,
              let count = obj["count"] as? Int, let head = obj["head"] as? String else {
            throw RWCRightsLedgerErrorV5.witnessMalformed
        }
        return Witness(count: count, head: head)
    }

    private func rewriteJournal(events: [RWCRightsEventV3]) throws {
        let body = events.map(Self.journalLine).joined()
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
            throw RWCRightsLedgerErrorV5.ioFailure("journal open failed")
        }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(Self.journalLine(e).utf8))
            try handle.synchronize()
        } catch { throw RWCRightsLedgerErrorV5.ioFailure("journal append failed: \(error)") }
        try writeWitness(count: events.count + 1, head: e.eventDigest)
        events.append(e)
        lastEventDate = recordedDate
    }

    // MARK: laws (carried from V4)

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

    /// REGISTRATION (R7): REQUIRES the unforgeable RWCVerifiedRightsGrantV6 (identical to the V4 law).
    public func register(_ r: RWCAssetRightsRecordV3, verifiedGrant: RWCVerifiedRightsGrantV6,
                         clock: RWCRightsClockV3) throws {
        guard verifiedGrant.grant == r.grant else {
            throw RWCRightsLedgerErrorV5.verifiedGrantMismatch(reason: "verified grant != record grant")
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

    /// A20-F1/F3/F4 SEALED WRITE. The ONLY writer of the ledger-resident authorization record the R7
    /// runner trusts to promote. REQUIRES an RWCAcquisitionAuthorityTokenV1 (no caller scalars). The
    /// identity is taken from the token; the write refuses unless:
    ///   • the token's session/asset/grant identity matches this call and the live rights record,
    ///   • intendedUse ∈ grant.allowedUse and ∉ grant.prohibitedUse                         (A20-F3),
    ///   • the CURRENT verified registry lists the grant's reviewer ACTIVE and its documentDigest
    ///     equals the grant's registryDocumentDigest and the token's current-registry witness (A20-F4).
    /// The written record carries the full PASS-proof identity so recovery can reconstruct a receipt.
    @discardableResult
    public func authorizeAcquisitionV2(token: RWCAcquisitionAuthorityTokenV1,
                                       verifiedGrant: RWCVerifiedRightsGrantV6,
                                       currentRegistry: RWCVerifiedReviewerRegistryV2,
                                       clock: RWCRightsClockV3) throws -> RWCAcquisitionAuthorizationRecordV2 {
        try RWCAcquisitionSessionIDV1.validate(token.sessionID)
        if authorizations[token.sessionID] != nil {
            throw RWCRightsLedgerErrorV5.duplicateAuthorizationSession(token.sessionID)
        }
        // token ↔ grant binding
        guard token.grantID == verifiedGrant.grant.grantID,
              token.grantRevision == verifiedGrant.grant.grantRevision else {
            throw RWCRightsLedgerErrorV5.tokenBindingMismatch(field: "grant")
        }
        // the authorized asset must have a live rights record bound to THIS grant.
        guard let record = records[token.assetID], !tombstoned.contains(token.assetID) else {
            throw RWCRightsLedgerErrorV5.authorizationMalformed("no live rights record for asset")
        }
        guard record.grant.grantID == verifiedGrant.grant.grantID,
              record.grant.grantRevision == verifiedGrant.grant.grantRevision,
              record.sourceReference == token.sourceReference else {
            throw RWCRightsLedgerErrorV5.authorizationMalformed("authorization != rights record")
        }
        guard RWCRightsReviewAuthorityV1.isLowercaseHex64(record.contentHash) else {
            throw RWCRightsLedgerErrorV5.authorizationMalformed("contentHash")
        }
        // A20-F3: intended use must be permitted by the grant (belt + suspenders over the evaluator).
        let useToken = token.intendedUseToken
        guard useToken == "training" || useToken == "evaluation" else {
            throw RWCRightsLedgerErrorV5.useNotAuthorized(use: useToken)
        }
        guard verifiedGrant.grant.allowedUse.contains(useToken),
              !verifiedGrant.grant.prohibitedUse.contains(useToken) else {
            throw RWCRightsLedgerErrorV5.useNotAuthorized(use: useToken)
        }
        // A20-F4: CURRENT reviewer authority at authorization-commit time (revocation-effective policy).
        guard currentRegistry.documentDigest == verifiedGrant.registryDocumentDigest else {
            throw RWCRightsLedgerErrorV5.reviewerNotCurrent(stage: "grant-digest-vs-current")
        }
        guard currentRegistry.documentDigest == token.currentRegistryDocumentDigest else {
            throw RWCRightsLedgerErrorV5.reviewerNotCurrent(stage: "token-digest-vs-current")
        }
        guard let reviewer = currentRegistry.reviewer(verifiedGrant.reviewerID),
              reviewer.status == "ACTIVE" else {
            throw RWCRightsLedgerErrorV5.reviewerNotCurrent(stage: "reviewer-not-active-in-current")
        }
        let today = clock.today()
        try requireMonotone(today, rule: "authorization recordedDate >= previous event date")
        let authz = RWCAcquisitionAuthorizationRecordV2(
            sessionID: token.sessionID, assetID: token.assetID, contentHash: record.contentHash,
            grantID: verifiedGrant.grant.grantID, grantRevision: verifiedGrant.grant.grantRevision,
            reviewRecordID: verifiedGrant.reviewRecordID, reviewerID: verifiedGrant.reviewerID,
            sourceReference: token.sourceReference, intendedUse: useToken,
            registryDocumentDigest: verifiedGrant.registryDocumentDigest, rootID: verifiedGrant.rootID,
            candidateCommit: token.candidateCommit, candidateTagObjectSHA: token.candidateTagObjectSHA,
            auditCommit: token.auditCommit, auditResultBlobSHA256: token.auditResultBlobSHA256,
            methodologyAnchorCommit: token.methodologyAnchorCommit,
            freezeManifestSHA256: token.freezeManifestSHA256,
            frozenInventoryDigest: token.frozenInventoryDigest, transactionDate: today.isoString)
        try commitEvent(assetID: token.assetID, kind: "acquisition-authorized-v2",
                        payload: authz.canonicalJSON, recordedDate: today)
        authorizations[token.sessionID] = authz
        return authz
    }
}
