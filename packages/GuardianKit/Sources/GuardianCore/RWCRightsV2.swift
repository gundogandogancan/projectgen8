import Foundation
import CryptoKit

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC RIGHTS TRUTH MODEL V2 — canonical rights authority after AUDIT15 (R2).
//
// Supersedes (BY RECORD, not by mutation) the V1 surfaces in RWCAssetRightsLedgerV1.swift, which
// remain byte-frozen as AUDIT15 negative evidence (A15-F1/F2/F3/F4/F13/F16/F18 pins).
//
// Laws implemented here (R2 mandate §§4-12):
//  • RWCDateV2            — real proleptic-Gregorian civil date; strict ASCII YYYY-MM-DD; month
//                           lengths + leap-year law; no locale/timezone/Foundation-Calendar.
//  • RWCRightsClockV1     — typed clock authority. Eligibility logic NEVER reads a hidden clock and
//                           NEVER accepts a caller date STRING; event dates come from the clock.
//                           Tests inject RWCFixedClockV1; the real acquisition boundary must use
//                           RWCAcquisitionClockV1 (explicit UTC civil-date source).
//  • Evidence identity    — RWCRightsEvidenceIdentityV1: WHAT evidence is = SHA-256 digest (+
//                           version); WHERE it lives = pointer. Relicense law keys on the DIGEST:
//                           a renamed pointer over the same proof can NEVER reauthorize (A15-F3).
//  • Chronology law       — every event date is clock-supplied and must be >= the previous event
//                           date; registration >= acquisition; reauthorization acquisition >=
//                           revocation date (A15-F2). Already-expired grants are refused at
//                           registration (A15-F16). Queries older than the last event are refused
//                           (no time travel).
//  • Durable event chain  — SHA-256 over canonical length-prefixed event bytes; previousDigest
//                           chaining; versioned genesis constant. NO Swift Hasher anywhere in
//                           durable semantics (A15-F4). Cross-process stable by construction.
//  • Durable journal      — RWCAssetRightsJournalV1: append-only JSONL of opaque IDs/digests/state
//                           (no raw evidence); replay verifies sequence, chain, per-event digest,
//                           duplicates; head verification detects truncation.
//  • Registration vs use  — register() validates record integrity only; .training/.evaluation
//                           authorization is checked per requested use at requireEligible
//                           (A15-F13: a lawful training-only record is registrable and still fails
//                           evaluation use).
//  • Pointer grammar V2   — rwc-rights-ref- / rwc-source-ref- + [a-z0-9-]{4,64} with AT LEAST ONE
//                           alphanumeric in the suffix (A15-F18).
//
// ZERO-DATA: this module manages rights STATE only; it stores/loads no media, no labels, no model
// outputs. All R2 usage is synthetic-fixture tests. corpus_count remains 0.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

// MARK: - Typed errors

public enum RWCRightsErrorV2: Error, Equatable, Sendable {
    case malformedDate(field: String)
    case impossibleDate(field: String)
    case invalidAssetID(String)
    case ineligibleSourceClass(RWCSourceClassV1)
    case missingOwner
    case missingRightsHolder
    case invalidEvidencePointer(field: String)
    case invalidEvidenceDigest
    case invalidEvidenceVersion
    case invalidContentHash
    case emptyProvenance
    case duplicateProvenance
    case useConsistencyViolation(reason: String)
    case useNotAllowed(use: String)
    case dateOrderViolation(rule: String)
    case expiredAtRegistration
    case acquisitionInFuture
    case assetUnknown
    case duplicateRegistration
    case notRevoked
    case revoked
    case expired
    case resurrectionRefused
    case reauthorizationRequiresNewEvidence
    case chronologyViolation(rule: String)
}

// MARK: - RWCDateV2: real Gregorian civil date (deterministic, locale/timezone-free)

public struct RWCDateV2: Equatable, Comparable, Hashable, Sendable {
    public let year: Int   // 0...9999
    public let month: Int  // 1...12
    public let day: Int    // 1...monthLength(month, leap(year))

    public static func isLeapYear(_ y: Int) -> Bool {
        (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
    }

    public static func monthLength(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 0
        }
    }

    /// Strict parse: exactly "YYYY-MM-DD", ASCII digits 0-9 only (no Unicode digits, no whitespace,
    /// no signs), REAL calendar validity (month length + leap-year law). Typed refusal otherwise.
    public static func parse(_ s: String, field: String) throws -> RWCDateV2 {
        let u = Array(s.utf8)
        guard u.count == 10, u[4] == 0x2D, u[7] == 0x2D else { throw RWCRightsErrorV2.malformedDate(field: field) }
        func digits(_ range: Range<Int>) throws -> Int {
            var v = 0
            for i in range {
                let b = u[i]
                guard b >= 0x30, b <= 0x39 else { throw RWCRightsErrorV2.malformedDate(field: field) }
                v = v * 10 + Int(b - 0x30)
            }
            return v
        }
        let y = try digits(0..<4), m = try digits(5..<7), d = try digits(8..<10)
        guard (1...12).contains(m) else { throw RWCRightsErrorV2.impossibleDate(field: field) }
        guard d >= 1, d <= monthLength(year: y, month: m) else { throw RWCRightsErrorV2.impossibleDate(field: field) }
        return RWCDateV2(year: y, month: m, day: d)
    }

    public init(year: Int, month: Int, day: Int) { self.year = year; self.month = month; self.day = day }

    public var isoString: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public static func < (a: RWCDateV2, b: RWCDateV2) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }
}

// MARK: - Clock authority

/// Typed time authority for rights semantics. Eligibility/event logic obtains "today" ONLY through
/// this protocol — never a hidden Date(), never a caller-supplied date string.
public protocol RWCRightsClockV1: Sendable {
    func today() -> RWCDateV2
}

/// Deterministic injected clock for tests / replay.
public struct RWCFixedClockV1: RWCRightsClockV1 {
    public let date: RWCDateV2
    public init(_ date: RWCDateV2) { self.date = date }
    public init(_ iso: String) throws { self.date = try RWCDateV2.parse(iso, field: "clock") }
    public func today() -> RWCDateV2 { date }
}

/// THE production acquisition clock: explicit UTC civil date from an explicit time source.
/// LAW (RWC_RIGHTS_LAW_V2.md): every REAL acquisition session MUST construct its store with this
/// clock (system source), so "today" cannot be claimed by argument. Construction is explicit —
/// there is no ambient default inside any eligibility law.
public struct RWCAcquisitionClockV1: RWCRightsClockV1 {
    private let secondsSince1970: @Sendable () -> Int64
    public init(secondsSince1970: @escaping @Sendable () -> Int64) { self.secondsSince1970 = secondsSince1970 }
    public static func systemUTC() -> RWCAcquisitionClockV1 {
        RWCAcquisitionClockV1 { Int64(Date().timeIntervalSince1970.rounded(.down)) }
    }
    /// Civil-from-epoch (proleptic Gregorian, UTC) — Howard Hinnant's algorithm; no Foundation
    /// Calendar, no locale, no timezone database.
    public func today() -> RWCDateV2 {
        let z = Int(secondsSince1970() / 86_400) + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return RWCDateV2(year: m <= 2 ? y + 1 : y, month: m, day: d)
    }
}

// MARK: - Evidence identity (WHAT vs WHERE)

public struct RWCRightsEvidenceIdentityV1: Equatable, Sendable {
    /// WHERE the evidence lives: opaque pointer, grammar `rwc-rights-ref-` + [a-z0-9-]{4,64},
    /// at least one alphanumeric in the suffix (A15-F18).
    public let pointer: String
    /// WHAT the evidence is: lowercase-hex SHA-256 of the canonical rights-evidence bundle.
    /// Synthetic digests only until corpus phase.
    public let evidenceDigest: String
    /// Grant version label, [a-z0-9.-]{1,40}.
    public let evidenceVersion: String
    public init(pointer: String, evidenceDigest: String, evidenceVersion: String) {
        self.pointer = pointer; self.evidenceDigest = evidenceDigest; self.evidenceVersion = evidenceVersion
    }
}

// MARK: - Record V2

public struct RWCAssetRightsRecordV2: Sendable {
    public let assetID: String
    public let sourceClass: RWCSourceClassV1
    public let sourceReference: String       // opaque pointer, rwc-source-ref- grammar
    public let owner: String
    public let rightsHolder: String
    public let licenseType: String
    public let evidence: RWCRightsEvidenceIdentityV1
    public let allowedUse: [String]          // lowercase tokens from {"training","evaluation"}
    public let prohibitedUse: [String]
    public let trainingAllowed: Bool
    public let evaluationAllowed: Bool
    public let acquisitionDate: RWCDateV2
    public let expiryDate: RWCDateV2?
    public let contentHash: String           // 64 lowercase hex
    public let provenanceChain: [String]

    public init(assetID: String, sourceClass: RWCSourceClassV1, sourceReference: String, owner: String,
                rightsHolder: String, licenseType: String, evidence: RWCRightsEvidenceIdentityV1,
                allowedUse: [String], prohibitedUse: [String], trainingAllowed: Bool,
                evaluationAllowed: Bool, acquisitionDate: RWCDateV2, expiryDate: RWCDateV2?,
                contentHash: String, provenanceChain: [String]) {
        self.assetID = assetID; self.sourceClass = sourceClass; self.sourceReference = sourceReference
        self.owner = owner; self.rightsHolder = rightsHolder; self.licenseType = licenseType
        self.evidence = evidence; self.allowedUse = allowedUse; self.prohibitedUse = prohibitedUse
        self.trainingAllowed = trainingAllowed; self.evaluationAllowed = evaluationAllowed
        self.acquisitionDate = acquisitionDate; self.expiryDate = expiryDate
        self.contentHash = contentHash; self.provenanceChain = provenanceChain
    }
}

// MARK: - Record laws (pure, deterministic)

public enum RWCRightsLawV2 {
    public static let version = "rwc-rights-law-v2"
    public static let knownUses: Set<String> = ["training", "evaluation"]

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func isLowercaseHex64(_ s: String) -> Bool {
        s.count == 64 && s.utf8.allSatisfy { ($0 >= 0x30 && $0 <= 0x39) || ($0 >= 0x61 && $0 <= 0x66) }
    }

    /// Pointer grammar V2: prefix + suffix of [a-z0-9-]{4,64} containing >= 1 alphanumeric.
    static func isOpaquePointer(_ s: String, prefix: String) -> Bool {
        guard s.hasPrefix(prefix) else { return false }
        let t = s.dropFirst(prefix.count)
        guard (4...64).contains(t.count) else { return false }
        var hasAlnum = false
        for u in t.utf8 {
            let isLower = u >= 0x61 && u <= 0x7A
            let isDigit = u >= 0x30 && u <= 0x39
            if isLower || isDigit { hasAlnum = true; continue }
            if u == 0x2D { continue }
            return false
        }
        return hasAlnum
    }

    static func isEvidenceVersion(_ s: String) -> Bool {
        guard (1...40).contains(s.count) else { return false }
        return s.utf8.allSatisfy { ($0 >= 0x61 && $0 <= 0x7A) || ($0 >= 0x30 && $0 <= 0x39) || $0 == 0x2E || $0 == 0x2D }
    }

    /// Single authoritative use truth: flags and lists must MIRROR each other exactly; any
    /// contradiction, case-variant, unknown token or allowed∩prohibited overlap is typed refusal.
    public static func requireUseConsistency(_ r: RWCAssetRightsRecordV2) throws {
        for t in r.allowedUse where !knownUses.contains(t) {
            throw RWCRightsErrorV2.useConsistencyViolation(reason: "unknown allowedUse token: \(t)")
        }
        for t in r.prohibitedUse where !knownUses.contains(t) {
            throw RWCRightsErrorV2.useConsistencyViolation(reason: "unknown prohibitedUse token: \(t)")
        }
        let allowed = Set(r.allowedUse), prohibited = Set(r.prohibitedUse)
        guard allowed.count == r.allowedUse.count else {
            throw RWCRightsErrorV2.useConsistencyViolation(reason: "duplicate allowedUse token")
        }
        guard prohibited.count == r.prohibitedUse.count else {
            throw RWCRightsErrorV2.useConsistencyViolation(reason: "duplicate prohibitedUse token")
        }
        guard allowed.isDisjoint(with: prohibited) else {
            throw RWCRightsErrorV2.useConsistencyViolation(reason: "token both allowed and prohibited")
        }
        guard r.trainingAllowed == allowed.contains("training") else {
            throw RWCRightsErrorV2.useConsistencyViolation(reason: "trainingAllowed flag does not mirror allowedUse")
        }
        guard r.evaluationAllowed == allowed.contains("evaluation") else {
            throw RWCRightsErrorV2.useConsistencyViolation(reason: "evaluationAllowed flag does not mirror allowedUse")
        }
        guard !r.trainingAllowed || !prohibited.contains("training") else {
            throw RWCRightsErrorV2.useConsistencyViolation(reason: "training both granted and prohibited")
        }
        guard !r.evaluationAllowed || !prohibited.contains("evaluation") else {
            throw RWCRightsErrorV2.useConsistencyViolation(reason: "evaluation both granted and prohibited")
        }
    }

    /// Record-integrity validation (REGISTRATION law — deliberately use-agnostic, A15-F13).
    public static func validateRecord(_ r: RWCAssetRightsRecordV2) throws {
        if let e = RWCAssetIdentityV1.validateAssetID(r.assetID) {
            throw RWCRightsErrorV2.invalidAssetID("\(e)")
        }
        guard r.sourceClass.eligible else { throw RWCRightsErrorV2.ineligibleSourceClass(r.sourceClass) }
        guard !r.owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RWCRightsErrorV2.missingOwner }
        guard !r.rightsHolder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RWCRightsErrorV2.missingRightsHolder }
        guard isOpaquePointer(r.evidence.pointer, prefix: "rwc-rights-ref-") else {
            throw RWCRightsErrorV2.invalidEvidencePointer(field: "evidence.pointer")
        }
        guard isOpaquePointer(r.sourceReference, prefix: "rwc-source-ref-") else {
            throw RWCRightsErrorV2.invalidEvidencePointer(field: "sourceReference")
        }
        guard isLowercaseHex64(r.evidence.evidenceDigest) else { throw RWCRightsErrorV2.invalidEvidenceDigest }
        guard isEvidenceVersion(r.evidence.evidenceVersion) else { throw RWCRightsErrorV2.invalidEvidenceVersion }
        guard isLowercaseHex64(r.contentHash) else { throw RWCRightsErrorV2.invalidContentHash }
        guard !r.provenanceChain.isEmpty else { throw RWCRightsErrorV2.emptyProvenance }
        guard Set(r.provenanceChain).count == r.provenanceChain.count else { throw RWCRightsErrorV2.duplicateProvenance }
        try requireUseConsistency(r)
        if let exp = r.expiryDate {
            guard exp >= r.acquisitionDate else {
                throw RWCRightsErrorV2.dateOrderViolation(rule: "expiryDate >= acquisitionDate")
            }
        }
    }
}

// MARK: - Durable event chain (SHA-256, canonical bytes; NO Swift Hasher)

public struct RWCRightsEventV2: Equatable, Sendable {
    public static let formatVersion = "rwc-rights-event-v2"
    public static let genesisDigest = RWCRightsLawV2.sha256Hex(Data("GEN8-RWC-RIGHTS-CHAIN-V2-GENESIS".utf8))

    public let seq: Int
    public let previousDigest: String
    public let assetID: String
    public let kind: String          // "registered" | "revoked" | "reauthorized"
    public let evidenceDigest: String
    public let effectiveDate: String // ISO civil date of the rights effect (e.g. acquisition)
    public let recordedDate: String  // ISO civil date supplied by the clock at event time
    public let eventDigest: String

    /// Canonical bytes: for each field in fixed order, UInt32 big-endian byte length + UTF-8 bytes.
    /// Unambiguous (length-prefixed), cross-process and cross-language stable.
    static func canonicalBytes(seq: Int, previousDigest: String, assetID: String, kind: String,
                               evidenceDigest: String, effectiveDate: String, recordedDate: String) -> Data {
        var out = Data()
        for field in [formatVersion, String(seq), previousDigest, assetID, kind, evidenceDigest,
                      effectiveDate, recordedDate] {
            let bytes = Data(field.utf8)
            var len = UInt32(bytes.count).bigEndian
            withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
            out.append(bytes)
        }
        return out
    }

    init(seq: Int, previousDigest: String, assetID: String, kind: String, evidenceDigest: String,
         effectiveDate: String, recordedDate: String) {
        self.seq = seq; self.previousDigest = previousDigest; self.assetID = assetID; self.kind = kind
        self.evidenceDigest = evidenceDigest; self.effectiveDate = effectiveDate; self.recordedDate = recordedDate
        self.eventDigest = RWCRightsLawV2.sha256Hex(RWCRightsEventV2.canonicalBytes(
            seq: seq, previousDigest: previousDigest, assetID: assetID, kind: kind,
            evidenceDigest: evidenceDigest, effectiveDate: effectiveDate, recordedDate: recordedDate))
    }
}

// MARK: - Durable journal (append-only JSONL; opaque IDs/digests/state only)

public enum RWCRightsJournalErrorV1: Error, Equatable, Sendable {
    case ioFailure(String)
    case malformedLine(index: Int)
    case sequenceGap(expected: Int, found: Int)
    case chainBreak(index: Int)
    case digestMismatch(index: Int)
    case duplicateEvent(index: Int)
    case truncated(expectedCount: Int, found: Int)
    case headMismatch
}

public final class RWCAssetRightsJournalV1 {
    public let url: URL
    public init(url: URL) { self.url = url }

    /// Canonical line: fixed key order, no whitespace. The digest is over canonical EVENT bytes,
    /// so JSON is transport only; any byte tamper is caught by digest recomputation.
    static func line(for e: RWCRightsEventV2) -> String {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        }
        return "{\"v\":\"\(RWCRightsEventV2.formatVersion)\",\"seq\":\(e.seq),\"prev\":\"\(esc(e.previousDigest))\"," +
               "\"asset\":\"\(esc(e.assetID))\",\"kind\":\"\(esc(e.kind))\",\"evd\":\"\(esc(e.evidenceDigest))\"," +
               "\"eff\":\"\(e.effectiveDate)\",\"rec\":\"\(e.recordedDate)\",\"digest\":\"\(esc(e.eventDigest))\"}"
    }

    public func append(_ e: RWCRightsEventV2) throws {
        let data = Data((RWCAssetRightsJournalV1.line(for: e) + "\n").utf8)
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                throw RWCRightsJournalErrorV1.ioFailure("createFile failed: \(url.path)")
            }
        }
        guard let handle = try? FileHandle(forWritingTo: url) else {
            throw RWCRightsJournalErrorV1.ioFailure("open failed: \(url.path)")
        }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.synchronize()
        } catch {
            throw RWCRightsJournalErrorV1.ioFailure("append failed: \(error)")
        }
    }

    /// Replay with full verification: contiguous sequence from 0, previous-digest chaining from the
    /// versioned genesis, per-event digest recomputation (mutation detection), duplicate detection.
    public static func replay(url: URL) throws -> [RWCRightsEventV2] {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            throw RWCRightsJournalErrorV1.ioFailure("read failed: \(url.path)")
        }
        var events: [RWCRightsEventV2] = []
        var seenDigests = Set<String>()
        var prev = RWCRightsEventV2.genesisDigest
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: true)
        for (i, lineSub) in lines.enumerated() {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(lineSub.utf8)) as? [String: Any],
                  obj["v"] as? String == RWCRightsEventV2.formatVersion,
                  let seq = obj["seq"] as? Int, let p = obj["prev"] as? String,
                  let asset = obj["asset"] as? String, let kind = obj["kind"] as? String,
                  let evd = obj["evd"] as? String, let eff = obj["eff"] as? String,
                  let rec = obj["rec"] as? String, let digest = obj["digest"] as? String else {
                throw RWCRightsJournalErrorV1.malformedLine(index: i)
            }
            guard seq == i else { throw RWCRightsJournalErrorV1.sequenceGap(expected: i, found: seq) }
            guard p == prev else { throw RWCRightsJournalErrorV1.chainBreak(index: i) }
            let rebuilt = RWCRightsEventV2(seq: seq, previousDigest: p, assetID: asset, kind: kind,
                                           evidenceDigest: evd, effectiveDate: eff, recordedDate: rec)
            guard rebuilt.eventDigest == digest else { throw RWCRightsJournalErrorV1.digestMismatch(index: i) }
            guard seenDigests.insert(digest).inserted else { throw RWCRightsJournalErrorV1.duplicateEvent(index: i) }
            events.append(rebuilt)
            prev = digest
        }
        return events
    }

    /// Truncation detection: the chain is internally consistent under truncation, so the HEAD
    /// digest + count must be verified against an external witness (store state / PASS-lock-era
    /// acquisition records).
    public static func verifyHead(url: URL, expectedHeadDigest: String, expectedCount: Int) throws {
        let events = try replay(url: url)
        guard events.count == expectedCount else {
            throw RWCRightsJournalErrorV1.truncated(expectedCount: expectedCount, found: events.count)
        }
        guard events.last?.eventDigest ?? RWCRightsEventV2.genesisDigest == expectedHeadDigest else {
            throw RWCRightsJournalErrorV1.headMismatch
        }
    }
}

// MARK: - Store V2 (canonical eligibility authority; clock-supplied dates; monotone chronology)

public final class RWCAssetRightsLedgerStoreV2 {
    public static let version = "rwc-asset-rights-ledger-store-v2"

    public private(set) var events: [RWCRightsEventV2] = []
    private var records: [String: RWCAssetRightsRecordV2] = [:]
    private var tombstoned: Set<String> = []
    private var seenEvidenceDigests: [String: Set<String>] = [:]
    private var revocationDates: [String: RWCDateV2] = [:]
    private var lastEventDate: RWCDateV2?
    private let journal: RWCAssetRightsJournalV1?

    public init(journal: RWCAssetRightsJournalV1? = nil) { self.journal = journal }

    public var headDigest: String { events.last?.eventDigest ?? RWCRightsEventV2.genesisDigest }
    public var eventCount: Int { events.count }

    private func appendEvent(assetID: String, kind: String, evidenceDigest: String,
                             effectiveDate: RWCDateV2, recordedDate: RWCDateV2) throws {
        let e = RWCRightsEventV2(seq: events.count, previousDigest: headDigest, assetID: assetID,
                                 kind: kind, evidenceDigest: evidenceDigest,
                                 effectiveDate: effectiveDate.isoString, recordedDate: recordedDate.isoString)
        if let journal { try journal.append(e) }
        events.append(e)
        lastEventDate = recordedDate
    }

    /// Monotone chronology law: no event or query may be dated before the last recorded event.
    private func requireMonotone(_ today: RWCDateV2, rule: String) throws {
        if let last = lastEventDate, today < last {
            throw RWCRightsErrorV2.chronologyViolation(rule: rule)
        }
    }

    /// REGISTRATION (use-agnostic record-integrity gate; A15-F13).
    public func register(_ r: RWCAssetRightsRecordV2, clock: RWCRightsClockV1) throws {
        try RWCRightsLawV2.validateRecord(r)
        let today = clock.today()
        try requireMonotone(today, rule: "registration recordedDate >= previous event date")
        if tombstoned.contains(r.assetID) { throw RWCRightsErrorV2.resurrectionRefused }
        if records[r.assetID] != nil { throw RWCRightsErrorV2.duplicateRegistration }
        guard r.acquisitionDate <= today else { throw RWCRightsErrorV2.acquisitionInFuture }
        if let exp = r.expiryDate, exp < today { throw RWCRightsErrorV2.expiredAtRegistration }
        records[r.assetID] = r
        seenEvidenceDigests[r.assetID, default: []].insert(r.evidence.evidenceDigest)
        try appendEvent(assetID: r.assetID, kind: "registered", evidenceDigest: r.evidence.evidenceDigest,
                        effectiveDate: r.acquisitionDate, recordedDate: today)
    }

    /// REVOCATION: tombstones forever for all existing evidence; date comes from the CLOCK.
    public func revoke(assetID: String, clock: RWCRightsClockV1) throws {
        guard let r = records[assetID] else { throw RWCRightsErrorV2.assetUnknown }
        guard !tombstoned.contains(assetID) else { throw RWCRightsErrorV2.revoked }
        let today = clock.today()
        try requireMonotone(today, rule: "revocation recordedDate >= previous event date")
        guard today >= r.acquisitionDate else {
            throw RWCRightsErrorV2.dateOrderViolation(rule: "revocationDate >= acquisitionDate")
        }
        tombstoned.insert(assetID)
        revocationDates[assetID] = today
        try appendEvent(assetID: assetID, kind: "revoked", evidenceDigest: r.evidence.evidenceDigest,
                        effectiveDate: today, recordedDate: today)
    }

    /// REAUTHORIZATION: only path out of a tombstone. Requires a genuinely NEW evidence identity
    /// (digest not seen before for this asset — pointer renames are irrelevant, A15-F3) and a
    /// chronology-coherent new grant (new acquisition >= revocation date, recorded now).
    public func reauthorize(_ r: RWCAssetRightsRecordV2, clock: RWCRightsClockV1) throws {
        try RWCRightsLawV2.validateRecord(r)
        guard records[r.assetID] != nil else { throw RWCRightsErrorV2.assetUnknown }
        guard tombstoned.contains(r.assetID) else { throw RWCRightsErrorV2.notRevoked }
        let today = clock.today()
        try requireMonotone(today, rule: "reauthorization recordedDate >= previous event date")
        if seenEvidenceDigests[r.assetID, default: []].contains(r.evidence.evidenceDigest) {
            throw RWCRightsErrorV2.reauthorizationRequiresNewEvidence
        }
        guard let revokedOn = revocationDates[r.assetID] else { throw RWCRightsErrorV2.notRevoked }
        guard r.acquisitionDate >= revokedOn else {
            throw RWCRightsErrorV2.dateOrderViolation(rule: "reauthorized acquisitionDate >= revocationDate")
        }
        guard r.acquisitionDate <= today else { throw RWCRightsErrorV2.acquisitionInFuture }
        if let exp = r.expiryDate, exp < today { throw RWCRightsErrorV2.expiredAtRegistration }
        records[r.assetID] = r
        tombstoned.remove(r.assetID)
        seenEvidenceDigests[r.assetID, default: []].insert(r.evidence.evidenceDigest)
        try appendEvent(assetID: r.assetID, kind: "reauthorized", evidenceDigest: r.evidence.evidenceDigest,
                        effectiveDate: r.acquisitionDate, recordedDate: today)
    }

    /// USE-ELIGIBILITY at clock-now. Expiry is valid THROUGH the expiry date. Queries may not
    /// travel behind the ledger's last event (no time travel; A15-F16).
    public func requireEligible(assetID: String, use: RWCUseV1, clock: RWCRightsClockV1) throws {
        guard let r = records[assetID] else { throw RWCRightsErrorV2.assetUnknown }
        if tombstoned.contains(assetID) { throw RWCRightsErrorV2.revoked }
        let today = clock.today()
        try requireMonotone(today, rule: "eligibility query date >= last event date")
        if let exp = r.expiryDate, today > exp { throw RWCRightsErrorV2.expired }
        switch use {
        case .training:
            guard r.trainingAllowed, r.allowedUse.contains("training"),
                  !r.prohibitedUse.contains("training") else {
                throw RWCRightsErrorV2.useNotAllowed(use: "training")
            }
        case .evaluation:
            guard r.evaluationAllowed, r.allowedUse.contains("evaluation"),
                  !r.prohibitedUse.contains("evaluation") else {
                throw RWCRightsErrorV2.useNotAllowed(use: "evaluation")
            }
        }
    }

    public func record(for assetID: String) -> RWCAssetRightsRecordV2? { records[assetID] }
    public func isTombstoned(_ assetID: String) -> Bool { tombstoned.contains(assetID) }
}
