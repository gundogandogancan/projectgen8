import Foundation
import CryptoKit

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC RIGHTS TRUTH MODEL V3 — canonical rights authority after AUDIT16 (R3).
//
// Supersedes (BY RECORD, not by mutation) the V2 surfaces in RWCRightsV2.swift, which remain
// byte-frozen as AUDIT16 negative evidence (A16-F1/F2/F3/F4/F5/F6/F7 pins).
//
// R3 laws:
//  • RWCDateV3 (A16-F1)   — INVALID DATES ARE UNREPRESENTABLE. There is NO public memberwise
//                           initializer; the only constructors are throwing `make` and `parse`.
//                           If you possess an RWCDateV3, it is a valid proleptic-Gregorian date.
//  • UTC clock (A16-F2)   — civil-from-epoch uses mathematical FLOOR division: negative epoch
//                           seconds map to the correct prior UTC day (no truncation-toward-zero).
//  • Legal grant (A16-F3) — SHA-256 evidence digest proves WHAT BYTES WERE REVIEWED; it is NOT
//                           legal authority. Three distinct concepts: pointer (WHERE), evidence
//                           digest (WHAT BYTES), RWCLegalGrantIdentityV1 (WHICH APPROVED LEGAL
//                           AUTHORIZATION). Registration/reauthorization require an
//                           RWCVerifiedRightsGrantV1 — mintable ONLY by the rights-review
//                           verification boundary from an APPROVED review record. The code never
//                           certifies lawfulness in the abstract; it enforces that an approved
//                           rights-review record exists, is pinned to the evidence bytes, covers
//                           the requested scope, and is current (RWC_RIGHTS_LAW_V3.md §46 law).
//  • Relicense law        — after revocation: same grantID (ANY revision/bytes) ⇒ refused forever;
//                           new bytes alone (reserialization ⇒ new digest) ⇒ refused (digest is
//                           not authority); lawful reauthorization = NEW grant identity + APPROVED
//                           review record + its evidence digest.
//  • Durable authority    — RWCAssetRightsLedgerStoreV3 is EVENT-SOURCED with FULL normalized
//    (A16-F4/F5/F6/F7)      state payload per event: the complete eligibility state (records,
//                           tombstones, seen grants/digests, revocation dates, chronology) is
//                           reconstructed from genesis on `openExisting`. A separate durable HEAD
//                           WITNESS (atomic temp+rename, updated transactionally AFTER the journal
//                           append) makes truncation detectable across restarts. EXACTLY ONE
//                           writer: an OS advisory lock (flock EX|NB) is held for the store's
//                           lifetime. Crash law: journal==witness → clean; journal==witness+1
//                           valid event → deterministic ROLL-FORWARD; valid prefix==witness with a
//                           partial/invalid tail → deterministic DISCARD of the pending tail; any
//                           other divergence → typed refusal (never silent reset-to-empty).
//
// ZERO-DATA: rights STATE only; synthetic fixtures; no media, labels, model outputs, or real
// grants. corpus_count remains 0. No PASS lock exists or is created here.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

// MARK: - Typed errors

public enum RWCRightsErrorV3: Error, Equatable, Sendable {
    case malformedDate(field: String)
    case impossibleDate(field: String)
    case invalidAssetID(String)
    case ineligibleSourceClass(RWCSourceClassV1)
    case missingOwner
    case missingRightsHolder
    case invalidPointer(field: String)
    case invalidGrantID
    case invalidGrantRevision
    case invalidEvidenceDigest
    case invalidReviewRecordID
    case reviewNotApproved
    case reviewRecordMismatch(reason: String)
    case invalidContentHash
    case emptyProvenance
    case duplicateProvenance
    case unknownUseToken(String)
    case useOverlap
    case useNotAllowed(use: String)
    case dateOrderViolation(rule: String)
    case acquisitionOutsideGrantValidity
    case expiredAtRegistration
    case acquisitionInFuture
    case assetUnknown
    case duplicateRegistration
    case notRevoked
    case revoked
    case expired
    case resurrectionRefused
    case grantAlreadyUsed
    case evidenceAlreadyUsed
    case chronologyViolation(rule: String)
}

public enum RWCRightsLedgerErrorV3: Error, Equatable, Sendable {
    case directoryExists
    case directoryMissing
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
}

// MARK: - RWCDateV3: invalid dates are UNREPRESENTABLE

public struct RWCDateV3: Equatable, Comparable, Hashable, Sendable {
    public let year: Int   // 0...9999
    public let month: Int  // 1...12
    public let day: Int    // 1...monthLength

    // The ONLY stored-property initializer. Private: no public memberwise construction exists.
    private init(validatedYear: Int, validatedMonth: Int, validatedDay: Int) {
        self.year = validatedYear; self.month = validatedMonth; self.day = validatedDay
    }

    public static func isLeapYear(_ y: Int) -> Bool { (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }

    public static func monthLength(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 0
        }
    }

    /// Throwing factory — the lawful construction path for component values.
    public static func make(year: Int, month: Int, day: Int, field: String = "date") throws -> RWCDateV3 {
        guard year >= 0, year <= 9999 else { throw RWCRightsErrorV3.impossibleDate(field: field) }
        guard month >= 1, month <= 12 else { throw RWCRightsErrorV3.impossibleDate(field: field) }
        guard day >= 1, day <= monthLength(year: year, month: month) else {
            throw RWCRightsErrorV3.impossibleDate(field: field)
        }
        return RWCDateV3(validatedYear: year, validatedMonth: month, validatedDay: day)
    }

    /// Strict parse: exactly "YYYY-MM-DD", ASCII digits only, real-calendar validity.
    public static func parse(_ s: String, field: String) throws -> RWCDateV3 {
        let u = Array(s.utf8)
        guard u.count == 10, u[4] == 0x2D, u[7] == 0x2D else { throw RWCRightsErrorV3.malformedDate(field: field) }
        func digits(_ range: Range<Int>) throws -> Int {
            var v = 0
            for i in range {
                let b = u[i]
                guard b >= 0x30, b <= 0x39 else { throw RWCRightsErrorV3.malformedDate(field: field) }
                v = v * 10 + Int(b - 0x30)
            }
            return v
        }
        return try make(year: try digits(0..<4), month: try digits(5..<7), day: try digits(8..<10),
                        field: field)
    }

    public var isoString: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public static func < (a: RWCDateV3, b: RWCDateV3) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }
}

// MARK: - Clock authority V2 (floor-division UTC civil date; A16-F2)

public protocol RWCRightsClockV3: Sendable {
    func today() -> RWCDateV3
}

public struct RWCFixedClockV3: RWCRightsClockV3 {
    public let date: RWCDateV3
    public init(_ date: RWCDateV3) { self.date = date }
    public init(_ iso: String) throws { self.date = try RWCDateV3.parse(iso, field: "clock") }
    public func today() -> RWCDateV3 { date }
}

/// Production acquisition clock: explicit UTC civil date. FLOOR division fixes A16-F2
/// (negative epoch seconds land on the correct prior day). Supported civil-year domain: the
/// RWCDateV3 domain 0000-01-01 … 9999-12-31; out-of-domain epochs are a programmer error trapped
/// by the throwing factory (clamped construction is deliberately NOT provided).
public struct RWCAcquisitionClockV2: RWCRightsClockV3 {
    private let secondsSince1970: @Sendable () -> Int64
    public init(secondsSince1970: @escaping @Sendable () -> Int64) { self.secondsSince1970 = secondsSince1970 }
    public static func systemUTC() -> RWCAcquisitionClockV2 {
        RWCAcquisitionClockV2 { Int64(Date().timeIntervalSince1970.rounded(.down)) }
    }
    static func floorDiv(_ a: Int64, _ b: Int64) -> Int64 {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }
    public func today() -> RWCDateV3 {
        let days = Int(RWCAcquisitionClockV2.floorDiv(secondsSince1970(), 86_400))
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        // The epoch domain handled here (1970±...) is strictly inside the RWCDateV3 domain.
        return try! RWCDateV3.make(year: m <= 2 ? y + 1 : y, month: m, day: d, field: "clock")
    }
}

// MARK: - Legal grant identity (A16-F3): pointer=WHERE, digest=WHAT BYTES, grant=WHICH AUTHORITY

public struct RWCLegalGrantIdentityV1: Equatable, Sendable {
    public let grantID: String            // rwc-grant- + [a-z0-9-]{4,64}, >=1 alphanumeric
    public let grantRevision: Int         // >= 1
    public let evidenceDigest: String     // 64 lowercase hex — SHA-256 of the reviewed proof bytes
    public let evidencePointer: String    // rwc-rights-ref- grammar (location only)
    public let rightsHolder: String
    public let allowedUse: [String]       // SINGLE use truth (subset of {"training","evaluation"})
    public let prohibitedUse: [String]
    public let effectiveDate: RWCDateV3
    public let expiryDate: RWCDateV3?
    public let reviewDecision: String     // must be exactly "APPROVED" to ever become verified
    public let reviewRecordID: String     // rwc-review- grammar

    public init(grantID: String, grantRevision: Int, evidenceDigest: String, evidencePointer: String,
                rightsHolder: String, allowedUse: [String], prohibitedUse: [String],
                effectiveDate: RWCDateV3, expiryDate: RWCDateV3?, reviewDecision: String,
                reviewRecordID: String) {
        self.grantID = grantID; self.grantRevision = grantRevision; self.evidenceDigest = evidenceDigest
        self.evidencePointer = evidencePointer; self.rightsHolder = rightsHolder
        self.allowedUse = allowedUse; self.prohibitedUse = prohibitedUse
        self.effectiveDate = effectiveDate; self.expiryDate = expiryDate
        self.reviewDecision = reviewDecision; self.reviewRecordID = reviewRecordID
    }
}

/// The review record an authorized rights review produces (synthetic in pre-corpus tests).
public struct RWCRightsReviewRecordV1: Equatable, Sendable {
    public let reviewRecordID: String
    public let grantID: String
    public let grantRevision: Int
    public let evidenceDigest: String
    public let decision: String           // "APPROVED" / anything else
    public let reviewDate: RWCDateV3
    public init(reviewRecordID: String, grantID: String, grantRevision: Int, evidenceDigest: String,
                decision: String, reviewDate: RWCDateV3) {
        self.reviewRecordID = reviewRecordID; self.grantID = grantID; self.grantRevision = grantRevision
        self.evidenceDigest = evidenceDigest; self.decision = decision; self.reviewDate = reviewDate
    }
}

/// UNFORGEABLE verified-grant token: fileprivate init — the ONLY mint path is the review boundary.
/// Possessing one means: "an APPROVED rights-review record exists and matches this grant identity
/// and these evidence bytes" — nothing more (no abstract legality claim).
public struct RWCVerifiedRightsGrantV1: Sendable {
    public let grant: RWCLegalGrantIdentityV1
    public let reviewRecordID: String
    fileprivate init(grant: RWCLegalGrantIdentityV1, reviewRecordID: String) {
        self.grant = grant; self.reviewRecordID = reviewRecordID
    }
}

public enum RWCRightsReviewAuthorityV1 {
    public static let knownUses: Set<String> = ["training", "evaluation"]

    static func isToken(_ s: String, prefix: String) -> Bool {
        guard s.hasPrefix(prefix) else { return false }
        let t = s.dropFirst(prefix.count)
        guard (4...64).contains(t.count) else { return false }
        var alnum = false
        for u in t.utf8 {
            if (u >= 0x61 && u <= 0x7A) || (u >= 0x30 && u <= 0x39) { alnum = true; continue }
            if u == 0x2D { continue }
            return false
        }
        return alnum
    }

    static func isLowercaseHex64(_ s: String) -> Bool {
        s.count == 64 && s.utf8.allSatisfy { ($0 >= 0x30 && $0 <= 0x39) || ($0 >= 0x61 && $0 <= 0x66) }
    }

    public static func validateGrant(_ g: RWCLegalGrantIdentityV1) throws {
        guard isToken(g.grantID, prefix: "rwc-grant-") else { throw RWCRightsErrorV3.invalidGrantID }
        guard g.grantRevision >= 1 else { throw RWCRightsErrorV3.invalidGrantRevision }
        guard isLowercaseHex64(g.evidenceDigest) else { throw RWCRightsErrorV3.invalidEvidenceDigest }
        guard isToken(g.evidencePointer, prefix: "rwc-rights-ref-") else {
            throw RWCRightsErrorV3.invalidPointer(field: "evidencePointer")
        }
        guard !g.rightsHolder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RWCRightsErrorV3.missingRightsHolder
        }
        guard isToken(g.reviewRecordID, prefix: "rwc-review-") else { throw RWCRightsErrorV3.invalidReviewRecordID }
        for t in g.allowedUse where !knownUses.contains(t) { throw RWCRightsErrorV3.unknownUseToken(t) }
        for t in g.prohibitedUse where !knownUses.contains(t) { throw RWCRightsErrorV3.unknownUseToken(t) }
        let a = Set(g.allowedUse), p = Set(g.prohibitedUse)
        guard a.count == g.allowedUse.count, p.count == g.prohibitedUse.count, a.isDisjoint(with: p) else {
            throw RWCRightsErrorV3.useOverlap
        }
        if let exp = g.expiryDate {
            guard exp >= g.effectiveDate else {
                throw RWCRightsErrorV3.dateOrderViolation(rule: "grant expiryDate >= effectiveDate")
            }
        }
    }

    /// THE rights-review verification boundary. A new SHA-256 alone can never produce a verified
    /// grant: the APPROVED review record must exist and must match the grant identity AND the
    /// evidence digest it reviewed.
    public static func verify(grant: RWCLegalGrantIdentityV1,
                              reviewRecord r: RWCRightsReviewRecordV1) throws -> RWCVerifiedRightsGrantV1 {
        try validateGrant(grant)
        guard grant.reviewDecision == "APPROVED", r.decision == "APPROVED" else {
            throw RWCRightsErrorV3.reviewNotApproved
        }
        guard r.reviewRecordID == grant.reviewRecordID else {
            throw RWCRightsErrorV3.reviewRecordMismatch(reason: "reviewRecordID")
        }
        guard r.grantID == grant.grantID, r.grantRevision == grant.grantRevision else {
            throw RWCRightsErrorV3.reviewRecordMismatch(reason: "grant identity")
        }
        guard r.evidenceDigest == grant.evidenceDigest else {
            throw RWCRightsErrorV3.reviewRecordMismatch(reason: "evidenceDigest")
        }
        return RWCVerifiedRightsGrantV1(grant: grant, reviewRecordID: r.reviewRecordID)
    }
}

// MARK: - Record V3

public struct RWCAssetRightsRecordV3: Equatable, Sendable {
    public let assetID: String
    public let sourceClass: RWCSourceClassV1
    public let sourceReference: String
    public let owner: String
    public let grant: RWCLegalGrantIdentityV1
    public let acquisitionDate: RWCDateV3
    public let contentHash: String
    public let provenanceChain: [String]
    public init(assetID: String, sourceClass: RWCSourceClassV1, sourceReference: String, owner: String,
                grant: RWCLegalGrantIdentityV1, acquisitionDate: RWCDateV3, contentHash: String,
                provenanceChain: [String]) {
        self.assetID = assetID; self.sourceClass = sourceClass; self.sourceReference = sourceReference
        self.owner = owner; self.grant = grant; self.acquisitionDate = acquisitionDate
        self.contentHash = contentHash; self.provenanceChain = provenanceChain
    }
}

// MARK: - Canonical serialization (events carry FULL state payload — A16-F5)

enum RWCRightsCanonicalV3 {
    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Fixed-key-order canonical JSON for the full record payload (reconstruction-complete).
    static func recordJSON(_ r: RWCAssetRightsRecordV3) -> String {
        let g = r.grant
        let allowed = g.allowedUse.map { "\"\(esc($0))\"" }.joined(separator: ",")
        let prohibited = g.prohibitedUse.map { "\"\(esc($0))\"" }.joined(separator: ",")
        let prov = r.provenanceChain.map { "\"\(esc($0))\"" }.joined(separator: ",")
        let expiry = g.expiryDate.map { "\"\($0.isoString)\"" } ?? "null"
        return "{\"asset\":\"\(esc(r.assetID))\",\"sourceClass\":\"\(r.sourceClass.rawValue)\"," +
               "\"sourceRef\":\"\(esc(r.sourceReference))\",\"owner\":\"\(esc(r.owner))\"," +
               "\"grantID\":\"\(esc(g.grantID))\",\"grantRev\":\(g.grantRevision)," +
               "\"evd\":\"\(esc(g.evidenceDigest))\",\"ptr\":\"\(esc(g.evidencePointer))\"," +
               "\"holder\":\"\(esc(g.rightsHolder))\",\"allowed\":[\(allowed)],\"prohibited\":[\(prohibited)]," +
               "\"effective\":\"\(g.effectiveDate.isoString)\",\"expiry\":\(expiry)," +
               "\"decision\":\"\(esc(g.reviewDecision))\",\"review\":\"\(esc(g.reviewRecordID))\"," +
               "\"acq\":\"\(r.acquisitionDate.isoString)\",\"hash\":\"\(esc(r.contentHash))\"," +
               "\"prov\":[\(prov)]}"
    }

    static func parseRecord(_ json: [String: Any]) throws -> RWCAssetRightsRecordV3 {
        func str(_ k: String) throws -> String {
            guard let v = json[k] as? String else { throw RWCRightsLedgerErrorV3.statePayloadMalformed(line: -1) }
            return v
        }
        guard let cls = RWCSourceClassV1(rawValue: try str("sourceClass")),
              let rev = json["grantRev"] as? Int,
              let allowed = json["allowed"] as? [String],
              let prohibited = json["prohibited"] as? [String],
              let prov = json["prov"] as? [String] else {
            throw RWCRightsLedgerErrorV3.statePayloadMalformed(line: -1)
        }
        let expiry: RWCDateV3?
        if let e = json["expiry"] as? String { expiry = try RWCDateV3.parse(e, field: "expiry") } else { expiry = nil }
        let grant = RWCLegalGrantIdentityV1(
            grantID: try str("grantID"), grantRevision: rev, evidenceDigest: try str("evd"),
            evidencePointer: try str("ptr"), rightsHolder: try str("holder"),
            allowedUse: allowed, prohibitedUse: prohibited,
            effectiveDate: try RWCDateV3.parse(try str("effective"), field: "effective"),
            expiryDate: expiry, reviewDecision: try str("decision"), reviewRecordID: try str("review"))
        return RWCAssetRightsRecordV3(
            assetID: try str("asset"), sourceClass: cls, sourceReference: try str("sourceRef"),
            owner: try str("owner"), grant: grant,
            acquisitionDate: try RWCDateV3.parse(try str("acq"), field: "acq"),
            contentHash: try str("hash"), provenanceChain: prov)
    }
}

public struct RWCRightsEventV3: Equatable, Sendable {
    public static let formatVersion = "rwc-rights-event-v3"
    public static let genesisDigest =
        RWCRightsCanonicalV3.sha256Hex(Data("GEN8-RWC-RIGHTS-CHAIN-V3-GENESIS".utf8))

    public let seq: Int
    public let previousDigest: String
    public let assetID: String
    public let kind: String            // "registered" | "revoked" | "reauthorized"
    public let recordPayloadJSON: String  // full canonical record JSON ("" for revocation)
    public let recordedDate: String
    public let eventDigest: String

    static func canonicalBytes(seq: Int, previousDigest: String, assetID: String, kind: String,
                               recordPayloadJSON: String, recordedDate: String) -> Data {
        var out = Data()
        for field in [formatVersion, String(seq), previousDigest, assetID, kind,
                      recordPayloadJSON, recordedDate] {
            let bytes = Data(field.utf8)
            var len = UInt32(bytes.count).bigEndian
            withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
            out.append(bytes)
        }
        return out
    }

    init(seq: Int, previousDigest: String, assetID: String, kind: String,
         recordPayloadJSON: String, recordedDate: String) {
        self.seq = seq; self.previousDigest = previousDigest; self.assetID = assetID; self.kind = kind
        self.recordPayloadJSON = recordPayloadJSON; self.recordedDate = recordedDate
        self.eventDigest = RWCRightsCanonicalV3.sha256Hex(RWCRightsEventV3.canonicalBytes(
            seq: seq, previousDigest: previousDigest, assetID: assetID, kind: kind,
            recordPayloadJSON: recordPayloadJSON, recordedDate: recordedDate))
    }
}

// MARK: - Durable, single-writer, crash-consistent ledger store V3

public final class RWCAssetRightsLedgerStoreV3 {
    public static let version = "rwc-asset-rights-ledger-store-v3"
    static let journalName = "rights-journal-v3.jsonl"
    static let witnessName = "rights-head-v3.json"
    static let lockName = "rights-writer-v3.lock"

    public let directory: URL
    public private(set) var events: [RWCRightsEventV3] = []
    private var records: [String: RWCAssetRightsRecordV3] = [:]
    private var tombstoned: Set<String> = []
    private var revocationDates: [String: RWCDateV3] = [:]
    private var seenGrantIDs: [String: Set<String>] = [:]
    private var seenEvidenceDigests: [String: Set<String>] = [:]
    private var lastEventDate: RWCDateV3?
    private var lockFD: Int32 = -1

    public var headDigest: String { events.last?.eventDigest ?? RWCRightsEventV3.genesisDigest }
    public var eventCount: Int { events.count }
    public func isTombstoned(_ assetID: String) -> Bool { tombstoned.contains(assetID) }
    public func record(for assetID: String) -> RWCAssetRightsRecordV3? { records[assetID] }

    private var journalURL: URL { directory.appendingPathComponent(Self.journalName) }
    private var witnessURL: URL { directory.appendingPathComponent(Self.witnessName) }
    private var lockURL: URL { directory.appendingPathComponent(Self.lockName) }

    private init(directory: URL) { self.directory = directory }
    deinit { if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD) } }

    // MARK: single-writer law (A16-F7)

    private func acquireWriterLock() throws {
        let fd = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { throw RWCRightsLedgerErrorV3.ioFailure("open lock failed") }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            throw RWCRightsLedgerErrorV3.lockedByAnotherWriter
        }
        lockFD = fd
    }

    public func closeStore() {
        if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD); lockFD = -1 }
    }

    // MARK: lifecycle — explicit create vs openExisting (A16-F4); no silent-empty constructor

    public static func create(directory: URL) throws -> RWCAssetRightsLedgerStoreV3 {
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent(witnessName).path) {
            throw RWCRightsLedgerErrorV3.directoryExists
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = RWCAssetRightsLedgerStoreV3(directory: directory)
        try store.acquireWriterLock()
        try store.writeWitness(count: 0, head: RWCRightsEventV3.genesisDigest)
        guard FileManager.default.createFile(atPath: store.journalURL.path, contents: nil) else {
            throw RWCRightsLedgerErrorV3.ioFailure("journal create failed")
        }
        return store
    }

    /// Durable reopen: load witness, replay journal, verify chain + head agreement, reconstruct
    /// the COMPLETE eligibility state. Crash law: roll-forward exactly-one-pending; discard a
    /// partial tail matching the witness; refuse anything else. Never resets to empty.
    public static func openExisting(directory: URL) throws -> RWCAssetRightsLedgerStoreV3 {
        let store = RWCAssetRightsLedgerStoreV3(directory: directory)
        guard FileManager.default.fileExists(atPath: store.witnessURL.path) else {
            throw RWCRightsLedgerErrorV3.witnessMissing
        }
        try store.acquireWriterLock()
        let witness = try store.readWitness()
        guard let raw = try? String(contentsOf: store.journalURL, encoding: .utf8) else {
            throw RWCRightsLedgerErrorV3.ioFailure("journal read failed")
        }
        var parsed: [RWCRightsEventV3] = []
        var partialTail = false
        var prev = RWCRightsEventV3.genesisDigest
        var seenDigests = Set<String>()
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init).filter { !$0.isEmpty || false }
        for (i, line) in lines.enumerated() {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  obj["v"] as? String == RWCRightsEventV3.formatVersion,
                  let seq = obj["seq"] as? Int, let p = obj["prev"] as? String,
                  let asset = obj["asset"] as? String, let kind = obj["kind"] as? String,
                  let payload = obj["payload"] as? String, let rec = obj["rec"] as? String,
                  let digest = obj["digest"] as? String else {
                // malformed tail is a pending-transaction candidate ONLY if it is the last line
                if i == lines.count - 1 { partialTail = true; break }
                throw RWCRightsLedgerErrorV3.journalMalformed(line: i)
            }
            guard seq == i else { throw RWCRightsLedgerErrorV3.sequenceGap(expected: i, found: seq) }
            guard p == prev else { throw RWCRightsLedgerErrorV3.chainBreak(line: i) }
            let rebuilt = RWCRightsEventV3(seq: seq, previousDigest: p, assetID: asset, kind: kind,
                                           recordPayloadJSON: payload, recordedDate: rec)
            guard rebuilt.eventDigest == digest else { throw RWCRightsLedgerErrorV3.eventDigestMismatch(line: i) }
            guard seenDigests.insert(digest).inserted else { throw RWCRightsLedgerErrorV3.duplicateEvent(line: i) }
            parsed.append(rebuilt)
            prev = digest
        }
        // witness agreement law
        if parsed.count < witness.count {
            throw RWCRightsLedgerErrorV3.truncatedJournal(witnessCount: witness.count, journalCount: parsed.count)
        }
        if parsed.count == witness.count {
            guard (parsed.last?.eventDigest ?? RWCRightsEventV3.genesisDigest) == witness.head else {
                throw RWCRightsLedgerErrorV3.headMismatch
            }
            if partialTail {
                // pending partial append after the committed head: deterministic DISCARD
                try store.rewriteJournal(events: parsed)
            }
        } else if parsed.count == witness.count + 1 {
            // crash after journal append, before witness update: deterministic ROLL-FORWARD —
            // but only if the committed prefix agrees with the witness head.
            let prefixHead = parsed.count >= 2 ? parsed[parsed.count - 2].eventDigest
                                               : RWCRightsEventV3.genesisDigest
            guard prefixHead == witness.head else { throw RWCRightsLedgerErrorV3.headMismatch }
            if partialTail { try store.rewriteJournal(events: parsed) }
            try store.writeWitness(count: parsed.count, head: parsed.last!.eventDigest)
        } else {
            throw RWCRightsLedgerErrorV3.witnessBehindBeyondOnePending(witnessCount: witness.count,
                                                                       journalCount: parsed.count)
        }
        // full state reconstruction (A16-F5)
        for (i, e) in parsed.enumerated() {
            let recorded = try RWCDateV3.parse(e.recordedDate, field: "recordedDate")
            switch e.kind {
            case "registered", "reauthorized":
                guard let obj = try? JSONSerialization.jsonObject(with: Data(e.recordPayloadJSON.utf8))
                        as? [String: Any],
                      let record = try? RWCRightsCanonicalV3.parseRecord(obj) else {
                    throw RWCRightsLedgerErrorV3.statePayloadMalformed(line: i)
                }
                store.records[record.assetID] = record
                store.tombstoned.remove(record.assetID)
                store.seenGrantIDs[record.assetID, default: []].insert(record.grant.grantID)
                store.seenEvidenceDigests[record.assetID, default: []].insert(record.grant.evidenceDigest)
            case "revoked":
                store.tombstoned.insert(e.assetID)
                store.revocationDates[e.assetID] = recorded
            default:
                throw RWCRightsLedgerErrorV3.statePayloadMalformed(line: i)
            }
            store.lastEventDate = recorded
        }
        store.events = parsed
        return store
    }

    // MARK: witness (A16-F6) — atomic temp+rename

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
        } catch {
            throw RWCRightsLedgerErrorV3.ioFailure("witness write failed: \(error)")
        }
    }

    private func readWitness() throws -> Witness {
        guard let data = try? Data(contentsOf: witnessURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["v"] as? String == Self.version,
              let count = obj["count"] as? Int, let head = obj["head"] as? String else {
            throw RWCRightsLedgerErrorV3.witnessMalformed
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

    /// TRANSACTION: append journal (fsync) THEN update witness. A crash between the two is the
    /// exactly-one-pending state that openExisting rolls forward deterministically.
    private func commitEvent(assetID: String, kind: String, payload: String,
                             recordedDate: RWCDateV3) throws {
        let e = RWCRightsEventV3(seq: events.count, previousDigest: headDigest, assetID: assetID,
                                 kind: kind, recordPayloadJSON: payload,
                                 recordedDate: recordedDate.isoString)
        guard let handle = try? FileHandle(forWritingTo: journalURL) else {
            throw RWCRightsLedgerErrorV3.ioFailure("journal open failed")
        }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(Self.journalLine(e).utf8))
            try handle.synchronize()
        } catch { throw RWCRightsLedgerErrorV3.ioFailure("journal append failed: \(error)") }
        try writeWitness(count: events.count + 1, head: e.eventDigest)
        events.append(e)
        lastEventDate = recordedDate
    }

    // MARK: laws

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
        // acquisition must sit inside the grant's validity window
        guard r.acquisitionDate >= r.grant.effectiveDate else {
            throw RWCRightsErrorV3.acquisitionOutsideGrantValidity
        }
        if let exp = r.grant.expiryDate {
            guard r.acquisitionDate <= exp else { throw RWCRightsErrorV3.acquisitionOutsideGrantValidity }
        }
    }

    /// REGISTRATION — use-agnostic record-integrity gate; REQUIRES a verified grant token.
    public func register(_ r: RWCAssetRightsRecordV3, verifiedGrant: RWCVerifiedRightsGrantV1,
                         clock: RWCRightsClockV3) throws {
        guard verifiedGrant.grant == r.grant else {
            throw RWCRightsErrorV3.reviewRecordMismatch(reason: "verified grant != record grant")
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

    /// REAUTHORIZATION (relicense law, A16-F3): requires a verified grant whose grantID AND
    /// evidenceDigest were never used for this asset. Same grantID (any revision/bytes) refused;
    /// new bytes alone (new digest, previously used grantID) refused; chronology coherent.
    public func reauthorize(_ r: RWCAssetRightsRecordV3, verifiedGrant: RWCVerifiedRightsGrantV1,
                            clock: RWCRightsClockV3) throws {
        guard verifiedGrant.grant == r.grant else {
            throw RWCRightsErrorV3.reviewRecordMismatch(reason: "verified grant != record grant")
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
}
