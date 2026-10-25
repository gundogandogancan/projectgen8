//
//  LocalLearningStoreV1.swift — §3.3/§6: the DURABLE, PRIVACY-BOUNDED persistence for Personal Learning V1.
//
//  WHAT THIS IS: the on-device, APP-PRIVATE store for (a) the learning ON/OFF toggle and the first-run consent
//  flag, and (b) the DURABLE proposals (pending + decided). It holds NO raw OCR/audio/transcript/screenshot and NO
//  content-id history — only the LocalLearningProposalV1 records (rule IDs, counts, dates, kinds, from→to, reason).
//  The volatile distinctness aggregates live ONLY in the engine's RAM and are NEVER written here (§3.3).
//
//  PRIVACY / KVKK (mandate §6 — NO "KVKK zero" claim, but real controls):
//   • App-private container (Application Support / an injected test dir). This is NOT the shared App Group — learning
//     evidence does not need the extension and must not widen its exposure surface.
//   • File protection .complete on the file (encrypted at rest when the device is locked).
//   • isExcludedFromBackup is SET (evaluated + decided: learning evidence should not propagate to iCloud/iTunes
//     backups — it is cheap, device-local, and regenerable from future explicit signals; excluding it keeps the
//     derived personalization strictly on THIS device, matching "global pool'a hiçbir otomatik yol yok", §6).
//   • DELETION really clears: resetAll() removes the file AND zeroes the in-memory engine (tested).
//   • SCHEMA VERSION + corrupt-data recovery: a bad/incompatible blob loads as EMPTY (never a crash, never a
//     silently-wrong success) and is reported, so "bozuk kayıt başarı gibi gösterilmez" (§6).
//
import Foundation
import GuardianCore

/// §3.3 / B1 — the serialized durable payload. Schema-versioned; proposals + (schema v2) the durable learning
/// AGGREGATES + the restart-safe UNDO patch + the install salt. A toggle + consent flag. No raw media.
///
/// SCHEMA HISTORY:
///   v1 — learningEnabled, consentShown, proposals.
///   v2 — ADDS: `aggregates` (restart-safe learning progress, mandate B1), `undoPatch` (restart-safe A2 undo),
///        `installSalt` (per-install pseudonymisation salt for content distinctness tokens, mandate B1). A v1 blob is
///        MIGRATED forward (missing fields default to empty / a fresh salt) — never discarded, never crashed.
public struct LocalLearningPersistentV1: Sendable, Equatable, Codable {
    public static let schemaVersion = 2
    public var schema: Int
    public var learningEnabled: Bool
    public var consentShown: Bool                 // §4 — the first-run scope explanation has been shown + answered
    public var proposals: [LearningProposalV1]
    // v2 additions (all optional in the wire format so a v1 blob decodes and migrates):
    public var aggregates: LearningAggregatesSnapshotV1   // B1 — restart-safe independent-evidence counters
    public var undoPatch: LearningUndoPatchV1?            // A2 — restart-safe "last accepted change" inverse patch
    public var installSalt: String                       // B1 — per-install salt for pseudonymised distinctness tokens

    public init(schema: Int = LocalLearningPersistentV1.schemaVersion, learningEnabled: Bool = false,
                consentShown: Bool = false, proposals: [LearningProposalV1] = [],
                aggregates: LearningAggregatesSnapshotV1 = LearningAggregatesSnapshotV1(),
                undoPatch: LearningUndoPatchV1? = nil, installSalt: String = "") {
        self.schema = schema; self.learningEnabled = learningEnabled
        self.consentShown = consentShown; self.proposals = proposals
        self.aggregates = aggregates; self.undoPatch = undoPatch; self.installSalt = installSalt
    }

    // Custom decode so a v1 blob (no aggregates/undoPatch/installSalt) MIGRATES forward instead of failing (mandate B1).
    enum CodingKeys: String, CodingKey { case schema, learningEnabled, consentShown, proposals, aggregates, undoPatch, installSalt }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        self.schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 1
        self.learningEnabled = try c.decodeIfPresent(Bool.self, forKey: .learningEnabled) ?? false
        self.consentShown = try c.decodeIfPresent(Bool.self, forKey: .consentShown) ?? false
        self.proposals = try c.decodeIfPresent([LearningProposalV1].self, forKey: .proposals) ?? []
        self.aggregates = try c.decodeIfPresent(LearningAggregatesSnapshotV1.self, forKey: .aggregates) ?? LearningAggregatesSnapshotV1()
        self.undoPatch = try c.decodeIfPresent(LearningUndoPatchV1.self, forKey: .undoPatch)
        self.installSalt = try c.decodeIfPresent(String.self, forKey: .installSalt) ?? ""
        // Migrate the schema stamp forward once decoded so a re-save writes the current version.
        self.schema = LocalLearningPersistentV1.schemaVersion
    }
}

/// A2 — the restart-safe UNDO patch for the most recently ACCEPTED proposal. Persisting this means "son değişikliği
/// geri al" survives an app restart and still targets the EXACT rule+from/to it was recorded against (never a guess).
public struct LearningUndoPatchV1: Sendable, Equatable, Codable {
    public let proposalID: String
    public let ruleID: String
    public let appliedAction: ShieldAction        // what the rule was set TO when accepted (undo expects this)
    public let priorAction: ShieldAction          // the rule's action BEFORE accept (undo restores this)
    public let appliedUnderRevision: UInt64        // the policy revision produced by the accept write
    public init(proposalID: String, ruleID: String, appliedAction: ShieldAction,
                priorAction: ShieldAction, appliedUnderRevision: UInt64) {
        self.proposalID = proposalID; self.ruleID = ruleID; self.appliedAction = appliedAction
        self.priorAction = priorAction; self.appliedUnderRevision = appliedUnderRevision
    }
}

/// §6 — the honest result of a load: the payload + whether the on-disk data was CORRUPT/incompatible (surfaced, not
/// hidden). `corruptRecovered == true` means a bad blob was found and replaced with an empty payload.
public struct LocalLearningLoadResultV1: Sendable, Equatable {
    public let payload: LocalLearningPersistentV1
    public let corruptRecovered: Bool
    public let fileProtectionComplete: Bool
    public let excludedFromBackup: Bool
}

public final class LocalLearningStoreV1: @unchecked Sendable {
    public static let fileName = "personal-learning-v1.json"

    private let fileURL: URL
    private let fm = FileManager.default
    private let lock = NSLock()

    /// Default: the app-private Application Support directory (NOT the shared App Group). Learning stays device-local.
    public init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("Gen8/learning", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(Self.fileName)
    }

    /// Test / injection initializer — explicit directory (no app container needed).
    public init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent(Self.fileName)
    }

    public var storeURL: URL { fileURL }
    public var fileExists: Bool { fm.fileExists(atPath: fileURL.path) }

    /// B1 — generate a fresh, app-private per-install salt (random 128-bit hex). Stored once in the durable payload and
    /// used to pseudonymise content-distinctness tokens so they cannot be cross-referenced to a global id set without
    /// this device's private salt. Regenerated on reset (resetAll) so a wipe genuinely breaks linkage to prior tokens.
    public static func newInstallSalt() -> String {
        var hex = ""
        for _ in 0..<16 { hex += String(format: "%02x", UInt8.random(in: 0...255)) }
        return hex
    }

    /// §6 — LOAD. Missing file ⇒ empty default (NOT corrupt). Undecodable/incompatible ⇒ empty + corruptRecovered.
    public func load() -> LocalLearningLoadResultV1 {
        lock.lock(); defer { lock.unlock() }
        guard fm.fileExists(atPath: fileURL.path) else {
            return LocalLearningLoadResultV1(payload: LocalLearningPersistentV1(), corruptRecovered: false,
                                             fileProtectionComplete: false, excludedFromBackup: false)
        }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(LocalLearningPersistentV1.self, from: data) else {
            // Undecodable/corrupt (NOT a known-schema blob): recover to EMPTY honestly (never crash, never a wrong
            // "success"). A v1 blob is NOT corrupt — the migrating decoder upgrades it to v2 in-place (mandate B1).
            return LocalLearningLoadResultV1(payload: LocalLearningPersistentV1(), corruptRecovered: true,
                                             fileProtectionComplete: protectionIsComplete(), excludedFromBackup: isExcluded())
        }
        return LocalLearningLoadResultV1(payload: decoded, corruptRecovered: false,
                                         fileProtectionComplete: protectionIsComplete(), excludedFromBackup: isExcluded())
    }

    /// §6 — SAVE with file protection .complete + isExcludedFromBackup. Atomic write. Returns true on success.
    @discardableResult
    public func save(_ payload: LocalLearningPersistentV1) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(payload) else { return false }
        do {
            try data.write(to: fileURL, options: [.atomic])
            applyFileProtection()
            applyExcludedFromBackup()
            return true
        } catch { return false }
    }

    /// §6 — DELETION really clears: remove the file. After this, load() returns an empty default (no residue).
    @discardableResult
    public func resetAll() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard fm.fileExists(atPath: fileURL.path) else { return true }
        do { try fm.removeItem(at: fileURL); return true } catch { return false }
    }

    // MARK: - §6 privacy attributes (evaluated + applied; honest about platform availability).

    private func applyFileProtection() {
        #if canImport(UIKit)
        // iOS: complete protection (encrypted at rest when locked). macOS/headless tests have no file protection —
        // we do NOT pretend it was set there (honest: the flag simply isn't applicable on that platform).
        try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: fileURL.path)
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
