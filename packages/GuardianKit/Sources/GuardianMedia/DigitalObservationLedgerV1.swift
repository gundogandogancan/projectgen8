//
//  DigitalObservationLedgerV1.swift — R11-D P1: the OPT-IN, LOCAL-FIRST DIGITAL OBSERVATION LEDGER + the DIGITAL
//  CONTRIBUTION EVIDENCE CONTRACT (mandate document-2 §4/§5/§6).
//
//  WHAT IT IS: the canonical evidence FOUNDATION for future weekly/monthly digital-life reports. It is NOT a second
//  world model, scoring engine, or decision engine — it only records MINIMAL DERIVED observation events (what was
//  observed, for how long, with what coverage), so a later report can be computed from eligible days. OPT-IN and
//  default OFF: with consent withdrawn (or Guardian off) there are NO ledger writes.
//
//  THE HONESTY LAWS (mandate §4/§5): time exposed ≠ attention/comprehension/engagement. Repeated video = another
//  DURATION observation, not necessarily another unique learning item. Unobserved time is NEVER counted. Never
//  attribute unseen app usage to GEN8. Educational-looking ≠ learning; negative emotion ≠ harm; longer ≠ more benefit;
//  entertainment/rest ≠ wasted time. Monotonic clock for durations; calendar-aware local stamps for reporting periods.
//
//  CONTRIBUTION SCORE ≠ P009E SUITABILITY (mandate §5): separate constructs, labels, calibration, release gates. The
//  composite Contribution Score TYPE exists but is LOCKED/DISABLED (same discipline as the P009E numeric lock) until
//  validity + calibration. No leakage between the two.
//
//  Crash-safe, file-protected, backup-excluded, bounded, fully deletable — the same store discipline as the content
//  evidence memory. App-private (NOT shared App Group): the ledger aggregates at item end inside the app/extension
//  boundary and is strictly device-local, never uploaded.
//
import Foundation

// MARK: - §4 the observation record (minimal, derived, versioned)

/// R11 §4 — one item observation record. Monotonic `observedDurationSeconds` (never wall-clock delta) + calendar-aware
/// LOCAL period stamps for reporting. `isRepeatView` separates a repeated viewing from a unique item. Coverage by
/// modality is honest. NO raw recordings / audio / transcripts — only derived scalars + opaque refs.
public struct DigitalObservationRecordV1: Sendable, Equatable, Codable {
    public static let schemaVersion = 1
    public var schema: Int
    /// Ephemeral session reference (opaque; a broadcast session id, not a device/user id).
    public let sessionRef: String
    /// Privacy-preserving content reference (the opaque local content id — never a platform id, never raw content).
    public let contentRef: String
    /// Source platform coverage status (e.g. "reels", "shorts", "unknown") — a coarse derived string.
    public let sourcePlatform: String
    /// Observation window — LOCAL calendar stamps for the reporting period (epoch seconds, local-tz interpreted).
    public let observationStartEpoch: Double
    public let observationEndEpoch: Double
    /// MONOTONIC observed duration (seconds) — the only trustworthy "how long" (never end-start wall-clock).
    public let observedDurationSeconds: Double
    /// Whether this record is a REPEATED viewing of a content the ledger has already recorded (unique-vs-repeat).
    public let isRepeatView: Bool
    /// Recognition confidence for the identity (declared; not a suitability score).
    public let recognitionConfidence: Double
    /// Analysis coverage by modality (modalityRaw → fraction 0...1 actually observed). Honest; missing modality absent.
    public let coverageByModality: [String: Double]
    /// Derived content themes (coarse labels from the world model) + their provenance string. Never raw text.
    public let derivedThemes: [String]
    public let evidenceProvenance: String
    /// Model/schema versions that produced the observation (for later report provenance).
    public let modelSchemaVersions: [String]
    /// Analysis completeness for this observation.
    public let completeness: DigitalObservationCompletenessV1
    public let createdEpoch: Double

    public init(sessionRef: String, contentRef: String, sourcePlatform: String,
                observationStartEpoch: Double, observationEndEpoch: Double, observedDurationSeconds: Double,
                isRepeatView: Bool, recognitionConfidence: Double, coverageByModality: [String: Double],
                derivedThemes: [String], evidenceProvenance: String, modelSchemaVersions: [String],
                completeness: DigitalObservationCompletenessV1, createdEpoch: Double,
                schema: Int = DigitalObservationRecordV1.schemaVersion) {
        self.schema = schema; self.sessionRef = sessionRef; self.contentRef = contentRef
        self.sourcePlatform = sourcePlatform
        self.observationStartEpoch = observationStartEpoch; self.observationEndEpoch = observationEndEpoch
        self.observedDurationSeconds = max(0, observedDurationSeconds)
        self.isRepeatView = isRepeatView; self.recognitionConfidence = recognitionConfidence
        self.coverageByModality = coverageByModality; self.derivedThemes = derivedThemes
        self.evidenceProvenance = evidenceProvenance; self.modelSchemaVersions = modelSchemaVersions
        self.completeness = completeness; self.createdEpoch = createdEpoch
    }
}

public enum DigitalObservationCompletenessV1: String, Sendable, Equatable, Codable {
    case complete = "COMPLETE", partial = "PARTIAL", deferred = "DEFERRED", unknown = "UNKNOWN"
}

// MARK: - §4 the opt-in consent + the durable payload

public struct DigitalLedgerConsentV1: Sendable, Equatable, Codable {
    public static let schemaVersion = 1
    public var schema: Int
    /// DEFAULT OFF — the ledger is strictly opt-in (mandate §4). No consent → no writes.
    public var enabled: Bool
    public var consentShown: Bool
    public var retentionDays: Int
    public init(enabled: Bool = false, consentShown: Bool = false, retentionDays: Int = 90,
                schema: Int = DigitalLedgerConsentV1.schemaVersion) {
        self.schema = schema; self.enabled = enabled; self.consentShown = consentShown
        self.retentionDays = min(400, max(1, retentionDays))
    }
}

public struct DigitalLedgerPayloadV1: Sendable, Equatable, Codable {
    public static let schemaVersion = 1
    public var schema: Int
    public var consent: DigitalLedgerConsentV1
    public var records: [DigitalObservationRecordV1]
    public init(consent: DigitalLedgerConsentV1 = DigitalLedgerConsentV1(), records: [DigitalObservationRecordV1] = [],
                schema: Int = DigitalLedgerPayloadV1.schemaVersion) {
        self.schema = schema; self.consent = consent; self.records = records
    }
    enum CodingKeys: String, CodingKey { case schema, consent, records }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        self.schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 1
        self.consent = try c.decodeIfPresent(DigitalLedgerConsentV1.self, forKey: .consent) ?? DigitalLedgerConsentV1()
        self.records = try c.decodeIfPresent([DigitalObservationRecordV1].self, forKey: .records) ?? []
        self.schema = DigitalLedgerPayloadV1.schemaVersion
    }
}

public struct DigitalLedgerLoadResultV1: Sendable, Equatable {
    public let payload: DigitalLedgerPayloadV1
    public let corruptRecovered: Bool
    public let fileProtectionComplete: Bool
    public let excludedFromBackup: Bool
}

// MARK: - §4 the store

/// R11 §4 — the opt-in, app-private, crash-safe, bounded observation ledger. Writes happen OUTSIDE the video callback
/// (the caller aggregates at ITEM END). Guardian OFF / consent withdrawn → `appendIfEnabled` is a no-op. Full deletion
/// wipes everything. Same crash-safe discipline as ContentEvidenceMemoryV1.
public final class DigitalObservationLedgerV1: @unchecked Sendable {
    public static let fileName = "digital-observation-ledger-v1.json"
    public static let intentFileName = "digital-observation-ledger-intent-v1.json"
    public static let subdirectory = "Gen8/ledger"

    public let maxRecords: Int
    private let fileURL: URL
    private let intentURL: URL
    private let fm = FileManager.default
    private let lock = NSLock()

    /// Default: APP-PRIVATE Application Support (NOT the shared App Group — the ledger must not widen the extension's
    /// exposure surface; it aggregates derived events inside the app boundary and stays strictly device-local).
    public init(maxRecords: Int = 5000) {
        self.maxRecords = max(1, maxRecords)
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent(DigitalObservationLedgerV1.subdirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(DigitalObservationLedgerV1.fileName)
        self.intentURL = dir.appendingPathComponent(DigitalObservationLedgerV1.intentFileName)
    }

    public init(directory: URL, maxRecords: Int = 5000) {
        self.maxRecords = max(1, maxRecords)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent(DigitalObservationLedgerV1.fileName)
        self.intentURL = directory.appendingPathComponent(DigitalObservationLedgerV1.intentFileName)
    }

    public var storeURL: URL { fileURL }
    public var fileExists: Bool { fm.fileExists(atPath: fileURL.path) }
    private struct SaveIntentV1: Codable { let epoch: Double }

    public func load() -> DigitalLedgerLoadResultV1 {
        lock.lock(); defer { lock.unlock() }
        try? fm.removeItem(at: intentURL)
        guard fm.fileExists(atPath: fileURL.path) else {
            return DigitalLedgerLoadResultV1(payload: DigitalLedgerPayloadV1(), corruptRecovered: false,
                                             fileProtectionComplete: false, excludedFromBackup: false)
        }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(DigitalLedgerPayloadV1.self, from: data) else {
            return DigitalLedgerLoadResultV1(payload: DigitalLedgerPayloadV1(), corruptRecovered: true,
                                             fileProtectionComplete: protectionIsComplete(), excludedFromBackup: isExcluded())
        }
        return DigitalLedgerLoadResultV1(payload: decoded, corruptRecovered: false,
                                         fileProtectionComplete: protectionIsComplete(), excludedFromBackup: isExcluded())
    }

    @discardableResult
    public func save(_ payload: DigitalLedgerPayloadV1, nowEpoch: Double) -> Bool {
        lock.lock(); defer { lock.unlock() }
        var bounded = payload
        // Retention eviction, then count cap (drop oldest by createdEpoch).
        let cutoff = nowEpoch - Double(payload.consent.retentionDays) * 86400.0
        bounded.records = bounded.records.filter { $0.createdEpoch >= cutoff }
        if bounded.records.count > maxRecords {
            bounded.records.sort { $0.createdEpoch > $1.createdEpoch }
            bounded.records = Array(bounded.records.prefix(maxRecords))
        }
        guard let intentData = try? JSONEncoder().encode(SaveIntentV1(epoch: nowEpoch)),
              let data = try? JSONEncoder().encode(bounded) else { return false }
        do {
            try intentData.write(to: intentURL, options: [.atomic])
            try data.write(to: fileURL, options: [.atomic])
            applyFileProtection(fileURL); applyExcludedFromBackup(); applyFileProtection(intentURL)
            try? fm.removeItem(at: intentURL)
            return true
        } catch { try? fm.removeItem(at: intentURL); return false }
    }

    /// R11 §4/§8 — append ONE observation ONLY IF the ledger is enabled (consent) AND Guardian is active. A no-op
    /// otherwise (returns false). This is the single write entry point; the caller passes the LIVE guardian state so a
    /// Guardian-OFF session can never write (mandate §9: "Guardian OFF → no ledger writes"). Called at ITEM END.
    @discardableResult
    public func appendIfEnabled(_ record: DigitalObservationRecordV1, guardianActive: Bool, nowEpoch: Double) -> Bool {
        let payload = load().payload
        guard payload.consent.enabled, guardianActive else { return false }
        var next = payload
        next.records.append(record)
        return save(next, nowEpoch: nowEpoch)
    }

    public func loadConsent() -> DigitalLedgerConsentV1 { load().payload.consent }
    @discardableResult
    public func saveConsent(_ consent: DigitalLedgerConsentV1, nowEpoch: Double) -> Bool {
        var payload = load().payload
        payload.consent = consent
        // CONSENT WITHDRAWAL WIPES THE LEDGER (mandate §4/§9): turning enabled OFF clears all records.
        if !consent.enabled { payload.records = [] }
        return save(payload, nowEpoch: nowEpoch)
    }

    /// Full deletion (file + intent). Used by consent withdrawal / "verileri sil".
    @discardableResult
    public func wipeAll() -> Bool {
        lock.lock(); defer { lock.unlock() }
        try? fm.removeItem(at: intentURL)
        guard fm.fileExists(atPath: fileURL.path) else { return true }
        do { try fm.removeItem(at: fileURL); return true } catch { return false }
    }

    private func applyFileProtection(_ url: URL) {
        #if canImport(UIKit)
        try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
    }
    private func protectionIsComplete() -> Bool {
        #if canImport(UIKit)
        let attrs = try? fm.attributesOfItem(atPath: fileURL.path)
        return (attrs?[.protectionKey] as? FileProtectionType) == .complete
        #else
        return false
        #endif
    }
    private func applyExcludedFromBackup() {
        var url = fileURL; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
    private func isExcluded() -> Bool {
        (try? fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey]))?.isExcludedFromBackup ?? false
    }
}
