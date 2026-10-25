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

/// §3.3 — the serialized durable payload. Schema-versioned; proposals only; a toggle + consent flag. No raw media.
public struct LocalLearningPersistentV1: Sendable, Equatable, Codable {
    public static let schemaVersion = 1
    public var schema: Int
    public var learningEnabled: Bool
    public var consentShown: Bool                 // §4 — the first-run scope explanation has been shown + answered
    public var proposals: [LearningProposalV1]
    public init(schema: Int = LocalLearningPersistentV1.schemaVersion, learningEnabled: Bool = false,
                consentShown: Bool = false, proposals: [LearningProposalV1] = []) {
        self.schema = schema; self.learningEnabled = learningEnabled
        self.consentShown = consentShown; self.proposals = proposals
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

    /// §6 — LOAD. Missing file ⇒ empty default (NOT corrupt). Undecodable/incompatible ⇒ empty + corruptRecovered.
    public func load() -> LocalLearningLoadResultV1 {
        lock.lock(); defer { lock.unlock() }
        guard fm.fileExists(atPath: fileURL.path) else {
            return LocalLearningLoadResultV1(payload: LocalLearningPersistentV1(), corruptRecovered: false,
                                             fileProtectionComplete: false, excludedFromBackup: false)
        }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(LocalLearningPersistentV1.self, from: data),
              decoded.schema == LocalLearningPersistentV1.schemaVersion else {
            // Corrupt or schema-mismatch: recover to EMPTY honestly (never crash, never a wrong "success").
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
