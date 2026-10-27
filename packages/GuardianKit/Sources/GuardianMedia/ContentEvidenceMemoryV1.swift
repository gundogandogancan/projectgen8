//
//  ContentEvidenceMemoryV1.swift — R11-B P0(2): the ON-DEVICE, APP-PRIVATE, USER-CONTROLLED, BOUNDED
//  CONTENT EVIDENCE MEMORY — the "verified recognition + trustworthy evidence memory" store (mandate §3/§4).
//
//  WHAT IT IS: a crash-safe, file-protected, backup-excluded, bounded store of DERIVED recognition records. Each
//  record pairs a `RecognitionSignatureV1` (the versioned multi-keyframe signature) with the POLICY-INDEPENDENT
//  evidence that was genuinely derived for that content in a prior session, plus full provenance + validity metadata.
//  It is NOT a universal archive and NOT a prefetch cache: it only remembers what was actually analyzed, so it can be
//  RECOGNIZED later and its prior evidence RE-ADJUDICATED under the CURRENT policy (never republished).
//
//  WHAT IT STORES (mandate §3 — every mandated field):
//    • opaque local content id (never a platform id; stable within the device)
//    • fingerprint schema + version + basis (the RecognitionSignatureV1 carries these)
//    • observed coverage intervals (coverage honesty: 4s analyzed → 4s known)
//    • evidence modalities + their model versions
//    • POLICY-INDEPENDENT evidence payloads (derived expert labels/coverage/calibration — NOT a decision/verdict)
//    • original evidence timestamps
//    • model-calibration status
//    • observation confidence
//    • provenance
//    • cache creation + expiry epochs
//    • deletion / revocation state
//
//  WHAT IT NEVER STORES (mandate §4 — data minimization): NO raw frames, NO raw OCR text, NO audio, NO screenshots,
//  NO transcripts, and NO cached DECISION/verdict surface. Only perceptual-hash bytes + salted-none trigram HASHES +
//  derived evidence scalars. A recognition hit therefore cannot republish an old decision — only re-adjudicate
//  cached EVIDENCE (mandate §3.1).
//
//  CRASH-SAFETY / PRIVACY: copies the FamilyProfileSharedStoreV1 / LocalLearningStoreV1 discipline — atomic write with
//  a write-ahead intent + self-heal on load, FileProtection .complete, isExcludedFromBackup, schema-versioned Codable
//  with corrupt-record recovery to EMPTY (surfaced, never a silent wrong success), full clear.
//
//  OWNERSHIP: the recognition flow runs in the BROADCAST EXTENSION, so this store lives in the shared App Group
//  container (narrowest viable surface — the SAME group the shield/family stores already use), with a self-healing
//  degrade to the app-private Application Support directory when the group entitlement is unavailable.
//
import Foundation

// MARK: - §3 the policy-INDEPENDENT evidence payload (derived scalars; NEVER a decision)

/// R11 §3 — one derived evidence item as it was produced in a PRIOR session: a modality, its declared labels, the raw
/// coverage/confidence/uncertainty it carried, its temporal scope within the content, its model version, and its
/// calibration status. This is POLICY-INDEPENDENT: it records WHAT was observed, never the decision that followed. On
/// recognition it is replayed into the CURRENT `WorldModelEvidenceBridgeV1` as CACHED evidence and re-adjudicated.
public struct CachedEvidenceItemV1: Sendable, Equatable, Codable {
    /// The expert-domain raw value (e.g. "LANGUAGE_OCR", "SAFETY_EVIDENCE", "AUDIO_EVENT") — stored as a string so this
    /// pure store does not import the frozen ExpertDomainV2 type. The bridge maps it back on reuse.
    public let modalityRaw: String
    public let labels: [String]
    public let confidence: Double
    public let coverage: Double
    public let uncertainty: Double
    /// Temporal scope within the content (seconds) the evidence covered — the coverage-honesty anchor.
    public let scopeStartSeconds: Double
    public let scopeEndSeconds: Double
    public let modelVersion: String
    /// Calibration status raw (e.g. "HEURISTIC_SUPPORT_ONLY", "IMPLEMENTED_UNCALIBRATED") — stored as a string.
    public let calibrationStatusRaw: String
    public let provenance: String

    public init(modalityRaw: String, labels: [String], confidence: Double, coverage: Double, uncertainty: Double,
                scopeStartSeconds: Double, scopeEndSeconds: Double, modelVersion: String,
                calibrationStatusRaw: String, provenance: String) {
        self.modalityRaw = modalityRaw; self.labels = labels; self.confidence = confidence
        self.coverage = coverage; self.uncertainty = uncertainty
        self.scopeStartSeconds = min(scopeStartSeconds, scopeEndSeconds)
        self.scopeEndSeconds = max(scopeStartSeconds, scopeEndSeconds)
        self.modelVersion = modelVersion; self.calibrationStatusRaw = calibrationStatusRaw; self.provenance = provenance
    }
}

// MARK: - §3 the memory record

/// R11 §3 — one content evidence memory record. All mandated fields. Codable + schema-versioned. No raw media.
public struct ContentEvidenceMemoryRecordV1: Sendable, Equatable, Codable {
    public static let schemaVersion = 1
    public var schema: Int
    /// OPAQUE local content id (device-local; never a platform id). Stable so repeated sightings map to one record.
    public let localContentID: String
    /// The versioned multi-keyframe recognition signature (carries fingerprint schema/version/basis + coverage).
    public let signature: RecognitionSignatureV1
    /// The distinct modalities that have REAL (non-UNAVAILABLE) cached evidence (derived strings for the proof log).
    public let evidenceModalities: [String]
    /// The POLICY-INDEPENDENT cached evidence payloads.
    public let evidence: [CachedEvidenceItemV1]
    /// Original (prior-session) evidence epoch (when the analysis was actually produced).
    public let originalEvidenceEpoch: Double
    /// The overall model-calibration status for this record (worst-case of the evidence calibration, as a raw string).
    public let calibrationStatusRaw: String
    /// Observation confidence for the identity (declared, from the recognition build; NOT a suitability score).
    public let observationConfidence: Double
    /// Whether the prior analysis was COMPLETE for the known content, or only partial coverage (mandate §8 — PARTIAL
    /// HISTORY ≠ FULL VIDEO KNOWLEDGE). Honest: default false unless the whole-video analyzer marked completion.
    public let completeHistory: Bool
    public let provenance: String
    /// Cache lifecycle.
    public let createdEpoch: Double
    public let expiryEpoch: Double
    /// Access tracking for LRU eviction (updated on reuse).
    public var lastAccessEpoch: Double
    /// Soft-deletion / revocation state: a revoked record is NEVER reused and is purged on the next maintenance pass.
    public var revoked: Bool

    public init(localContentID: String, signature: RecognitionSignatureV1, evidenceModalities: [String],
                evidence: [CachedEvidenceItemV1], originalEvidenceEpoch: Double, calibrationStatusRaw: String,
                observationConfidence: Double, completeHistory: Bool, provenance: String,
                createdEpoch: Double, expiryEpoch: Double, lastAccessEpoch: Double, revoked: Bool = false,
                schema: Int = ContentEvidenceMemoryRecordV1.schemaVersion) {
        self.schema = schema; self.localContentID = localContentID; self.signature = signature
        self.evidenceModalities = evidenceModalities; self.evidence = evidence
        self.originalEvidenceEpoch = originalEvidenceEpoch; self.calibrationStatusRaw = calibrationStatusRaw
        self.observationConfidence = observationConfidence; self.completeHistory = completeHistory
        self.provenance = provenance; self.createdEpoch = createdEpoch; self.expiryEpoch = expiryEpoch
        self.lastAccessEpoch = lastAccessEpoch; self.revoked = revoked
    }

    /// A record is USABLE for reuse only when not revoked and not expired at `nowEpoch`. (The signature-compatibility
    /// and current-policy checks are enforced separately by the verifier + the recall gate.)
    public func isUsable(nowEpoch: Double) -> Bool { !revoked && nowEpoch < expiryEpoch }
}

// MARK: - §5 the user-controlled settings

/// R11 §5 — the memory settings the product shell exposes. Default ON but LOCAL-ONLY. The extension RESPECTS the
/// toggle: `enabled == false` → no lookup, no write. Retention drives the per-record expiry.
public struct RecognitionMemorySettingsV1: Sendable, Equatable, Codable {
    public static let schemaVersion = 1
    public var schema: Int
    public var enabled: Bool
    /// First-run consent/explanation shown (the scope explanation has been answered).
    public var consentShown: Bool
    /// Retention window in days (drives expiry). Bounded to a sane range on write.
    public var retentionDays: Int
    public init(enabled: Bool = true, consentShown: Bool = false, retentionDays: Int = 30,
                schema: Int = RecognitionMemorySettingsV1.schemaVersion) {
        self.schema = schema; self.enabled = enabled; self.consentShown = consentShown
        self.retentionDays = min(365, max(1, retentionDays))
    }
}

// MARK: - the serialized durable payload (bounded; schema-versioned)

public struct ContentEvidenceMemoryPayloadV1: Sendable, Equatable, Codable {
    public static let schemaVersion = 1
    public var schema: Int
    public var settings: RecognitionMemorySettingsV1
    public var records: [ContentEvidenceMemoryRecordV1]
    public init(settings: RecognitionMemorySettingsV1 = RecognitionMemorySettingsV1(),
                records: [ContentEvidenceMemoryRecordV1] = [],
                schema: Int = ContentEvidenceMemoryPayloadV1.schemaVersion) {
        self.schema = schema; self.settings = settings; self.records = records
    }
    // Forward-migrating decode (missing fields default, never crash) — the LocalLearning discipline.
    enum CodingKeys: String, CodingKey { case schema, settings, records }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        self.schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 1
        self.settings = try c.decodeIfPresent(RecognitionMemorySettingsV1.self, forKey: .settings) ?? RecognitionMemorySettingsV1()
        self.records = try c.decodeIfPresent([ContentEvidenceMemoryRecordV1].self, forKey: .records) ?? []
        self.schema = ContentEvidenceMemoryPayloadV1.schemaVersion
    }
}

/// R11 §4/§6 — the honest result of a load: the payload + whether the on-disk data was CORRUPT (surfaced, not hidden).
public struct ContentEvidenceMemoryLoadResultV1: Sendable, Equatable {
    public let payload: ContentEvidenceMemoryPayloadV1
    public let corruptRecovered: Bool
    public let fileProtectionComplete: Bool
    public let excludedFromBackup: Bool
    public let sharedContainerActive: Bool
}

// MARK: - the store

/// R11 §3/§4 — the crash-safe, bounded, file-protected content evidence memory store. Serial by NSLock. Copies the
/// FamilyProfileSharedStoreV1 3-phase write-ahead + self-heal pattern. Bounded by BOTH record count AND encoded bytes;
/// LRU + expiry eviction. Corrupt-record recovery to empty. Full clear.
public final class ContentEvidenceMemoryV1: @unchecked Sendable {
    public static let fileName = "content-evidence-memory-v1.json"
    public static let intentFileName = "content-evidence-memory-intent-v1.json"
    /// The SAME App Group the shield/family stores use (narrowest viable shared surface for the extension).
    public static let appGroupID = "group.com.gen8.guardian.dev"
    public static let subdirectory = "Gen8/recognition"

    public let maxRecords: Int
    public let maxBytes: Int

    private let fileURL: URL
    private let intentURL: URL
    private let fm = FileManager.default
    private let lock = NSLock()
    public let sharedContainerActive: Bool

    /// Default: the shared App Group container (self-healing degrade to app-private Application Support).
    public init(appGroupID: String = ContentEvidenceMemoryV1.appGroupID, maxRecords: Int = 256, maxBytes: Int = 2 * 1024 * 1024) {
        self.maxRecords = max(1, maxRecords)
        self.maxBytes = max(16 * 1024, maxBytes)
        let (dir, active): (URL, Bool)
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            dir = container.appendingPathComponent(ContentEvidenceMemoryV1.subdirectory, isDirectory: true); active = true
        } else {
            let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                     appropriateFor: nil, create: true))
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            dir = base.appendingPathComponent(ContentEvidenceMemoryV1.subdirectory, isDirectory: true); active = false
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(ContentEvidenceMemoryV1.fileName)
        self.intentURL = dir.appendingPathComponent(ContentEvidenceMemoryV1.intentFileName)
        self.sharedContainerActive = active
    }

    /// Test/injection initializer — explicit directory (no app container needed).
    public init(directory: URL, maxRecords: Int = 256, maxBytes: Int = 2 * 1024 * 1024) {
        self.maxRecords = max(1, maxRecords)
        self.maxBytes = max(16 * 1024, maxBytes)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent(ContentEvidenceMemoryV1.fileName)
        self.intentURL = directory.appendingPathComponent(ContentEvidenceMemoryV1.intentFileName)
        self.sharedContainerActive = false
    }

    public var storeURL: URL { fileURL }
    public var fileExists: Bool { fm.fileExists(atPath: fileURL.path) }

    private struct SaveIntentV1: Codable { let epoch: Double }

    // MARK: load / save / clear

    /// §4/§6 — LOAD. Missing file ⇒ empty default (NOT corrupt). Undecodable ⇒ empty + corruptRecovered. Self-heals a
    /// crash between the file write and the (no-op here, kept for symmetry) post-write step by clearing a live intent.
    public func load() -> ContentEvidenceMemoryLoadResultV1 {
        lock.lock(); defer { lock.unlock() }
        try? fm.removeItem(at: intentURL)   // a stale intent means the last atomic write may not have completed; the
                                            // atomic payload is either the old or the new whole file — both are valid.
        guard fm.fileExists(atPath: fileURL.path) else {
            return ContentEvidenceMemoryLoadResultV1(payload: ContentEvidenceMemoryPayloadV1(), corruptRecovered: false,
                                                     fileProtectionComplete: false, excludedFromBackup: false,
                                                     sharedContainerActive: sharedContainerActive)
        }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(ContentEvidenceMemoryPayloadV1.self, from: data) else {
            return ContentEvidenceMemoryLoadResultV1(payload: ContentEvidenceMemoryPayloadV1(), corruptRecovered: true,
                                                     fileProtectionComplete: protectionIsComplete(), excludedFromBackup: isExcluded(),
                                                     sharedContainerActive: sharedContainerActive)
        }
        return ContentEvidenceMemoryLoadResultV1(payload: decoded, corruptRecovered: false,
                                                 fileProtectionComplete: protectionIsComplete(), excludedFromBackup: isExcluded(),
                                                 sharedContainerActive: sharedContainerActive)
    }

    /// §4/§6 — SAVE a bounded payload atomically (write-ahead intent → atomic payload write → clear intent). The
    /// payload is bounded (count + bytes) BEFORE writing so the on-disk size can never exceed the caps.
    @discardableResult
    public func save(_ payload: ContentEvidenceMemoryPayloadV1, nowEpoch: Double) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let bounded = Self.bounded(payload, maxRecords: maxRecords, maxBytes: maxBytes, nowEpoch: nowEpoch)
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

    /// §5 — upsert ONE record (by localContentID) and persist. Returns the bounded, saved payload. The access epoch is
    /// set so freshly-written records are LRU-recent. NEVER writes per frame (caller writes at item end / threshold).
    @discardableResult
    public func upsert(_ record: ContentEvidenceMemoryRecordV1, nowEpoch: Double) -> ContentEvidenceMemoryPayloadV1 {
        var payload = load().payload
        var r = record; r.lastAccessEpoch = nowEpoch
        if let i = payload.records.firstIndex(where: { $0.localContentID == r.localContentID }) {
            payload.records[i] = r
        } else {
            payload.records.append(r)
        }
        let bounded = Self.bounded(payload, maxRecords: maxRecords, maxBytes: maxBytes, nowEpoch: nowEpoch)
        save(bounded, nowEpoch: nowEpoch)
        return bounded
    }

    /// §5 — mark a record reused: bump lastAccessEpoch (LRU freshness) WITHOUT changing evidence. Persisted.
    public func touch(localContentID: String, nowEpoch: Double) {
        var payload = load().payload
        if let i = payload.records.firstIndex(where: { $0.localContentID == localContentID }) {
            payload.records[i].lastAccessEpoch = nowEpoch
            save(payload, nowEpoch: nowEpoch)
        }
    }

    /// §5 — settings read/write (the product shell toggle + consent + retention).
    public func loadSettings() -> RecognitionMemorySettingsV1 { load().payload.settings }
    @discardableResult
    public func saveSettings(_ settings: RecognitionMemorySettingsV1, nowEpoch: Double) -> Bool {
        var payload = load().payload
        payload.settings = settings
        return save(payload, nowEpoch: nowEpoch)
    }

    /// §5 — CLEAR ALL records but KEEP settings (the "hafızayı temizle" control). Persisted.
    @discardableResult
    public func clearAllRecords(nowEpoch: Double) -> Bool {
        var payload = load().payload
        payload.records = []
        return save(payload, nowEpoch: nowEpoch)
    }

    /// §4/§6 — FULL wipe (file + intent). After this, load() returns empty defaults. Used by consent withdrawal.
    @discardableResult
    public func wipeAll() -> Bool {
        lock.lock(); defer { lock.unlock() }
        try? fm.removeItem(at: intentURL)
        guard fm.fileExists(atPath: fileURL.path) else { return true }
        do { try fm.removeItem(at: fileURL); return true } catch { return false }
    }

    // MARK: §3 bounded eviction (pure, testable)

    /// R11 §3/§6 — bound a payload to the record + byte caps: first DROP expired/revoked records, then evict the
    /// LEAST-RECENTLY-USED until under the record cap AND the encoded-byte cap. Pure + deterministic.
    public static func bounded(_ payload: ContentEvidenceMemoryPayloadV1, maxRecords: Int, maxBytes: Int,
                               nowEpoch: Double) -> ContentEvidenceMemoryPayloadV1 {
        var out = payload
        // 1. Retention/expiry/revocation eviction.
        out.records = out.records.filter { !$0.revoked && nowEpoch < $0.expiryEpoch }
        // 2. Record-count cap — evict LRU (oldest lastAccessEpoch first).
        if out.records.count > maxRecords {
            out.records.sort { $0.lastAccessEpoch > $1.lastAccessEpoch }   // most-recent first
            out.records = Array(out.records.prefix(maxRecords))
        }
        // 3. Byte cap — if the encoded payload exceeds maxBytes, drop LRU records until it fits (or one remains).
        func encodedSize(_ p: ContentEvidenceMemoryPayloadV1) -> Int { (try? JSONEncoder().encode(p))?.count ?? 0 }
        if encodedSize(out) > maxBytes, out.records.count > 1 {
            out.records.sort { $0.lastAccessEpoch > $1.lastAccessEpoch }
            while out.records.count > 1 && encodedSize(out) > maxBytes { out.records.removeLast() }
        }
        return out
    }

    // MARK: privacy attributes (same discipline as FamilyProfileSharedStoreV1)

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
        var url = fileURL
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
    private func isExcluded() -> Bool {
        (try? fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey]))?.isExcludedFromBackup ?? false
    }
}
