import Foundation
import CryptoKit

// MARK: - Durable Personal Shield store (006B §5,§6,§7,§8) — survives relaunch; raw reference media NEVER persisted.

/// 006B §7 — stable, versioned derived-reference representation. Holds a derived vector only, never source media.
public struct DerivedReferenceFeature: Codable, Sendable, Equatable {
    public enum FeatureType: String, Codable, Sendable { case image = "IMAGE", logo = "LOGO", audio = "AUDIO", music = "MUSIC" }
    public var featureID: String
    public var ruleID: String
    public var featureType: FeatureType
    public var engineID: String
    public var engineRevision: String
    public var vectorDimension: Int
    public var serializedFeature: Data          // derived vector bytes — NOT raw media
    public var checksum: String                 // SHA-256 of serializedFeature
    public var createdAtEpoch: Double
    public var rightsClass: String
    public var privacyClass: String
    public init(featureID: String, ruleID: String, featureType: FeatureType, engineID: String, engineRevision: String,
                vectorDimension: Int, serializedFeature: Data, createdAtEpoch: Double,
                rightsClass: String = "user-permitted", privacyClass: String = "on-device-only") {
        self.featureID = featureID; self.ruleID = ruleID; self.featureType = featureType; self.engineID = engineID
        self.engineRevision = engineRevision; self.vectorDimension = vectorDimension; self.serializedFeature = serializedFeature
        self.checksum = Self.checksum(of: serializedFeature); self.createdAtEpoch = createdAtEpoch
        self.rightsClass = rightsClass; self.privacyClass = privacyClass
    }
    public static func checksum(of data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public var isIntact: Bool { checksum == Self.checksum(of: serializedFeature) }
    /// 006B §7 — a feature is usable only if the current engine revision can consume it.
    public func isCompatible(engineID: String, engineRevision: String) -> Bool {
        self.engineID == engineID && self.engineRevision == engineRevision && isIntact
    }
}

/// The full durable snapshot persisted to disk.
public struct ShieldStoreSnapshot: Codable, Sendable, Equatable {
    public static let storeVersion = "shield-store-v1"
    public var storeVersion: String
    public var indexVersion: String
    public var rules: [ShieldRuleV2]
    public var exceptions: [ShieldException]
    public var features: [DerivedReferenceFeature]
    public init(rules: [ShieldRuleV2] = [], exceptions: [ShieldException] = [], features: [DerivedReferenceFeature] = [],
                storeVersion: String = ShieldStoreSnapshot.storeVersion, indexVersion: String = ShieldIndex.indexVersion) {
        self.storeVersion = storeVersion; self.indexVersion = indexVersion
        self.rules = rules; self.exceptions = exceptions; self.features = features
    }
    /// 006C §13 — deleting a rule removes the rule AND all its derived signatures/features (no orphan sensitive data).
    public mutating func deleteRule(_ ruleID: String) {
        rules.removeAll { $0.ruleID == ruleID }
        features.removeAll { $0.ruleID == ruleID }
    }
}

public enum ShieldStoreError: Error, Equatable { case corrupted(String), unreadable(String), incompatibleVersion(String) }

public protocol PersonalShieldStore: Sendable {
    func load() throws -> ShieldStoreSnapshot
    func save(_ snapshot: ShieldStoreSnapshot) throws
    func wipe() throws
}

/// On-disk envelope with a payload checksum for corruption detection; written atomically.
private struct ShieldStoreEnvelope: Codable { var envelopeVersion: String; var payloadChecksum: String; var payload: Data }

public final class FileBackedPersonalShieldStore: PersonalShieldStore, @unchecked Sendable {
    private let fileURL: URL
    private let protectData: Bool
    private let lock = NSLock()
    public init(directory: URL, fileName: String = "personal-shield.store.json", protectData: Bool = true) {
        self.fileURL = directory.appendingPathComponent(fileName); self.protectData = protectData
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func load() throws -> ShieldStoreSnapshot {
        lock.lock(); defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return ShieldStoreSnapshot() }   // first launch
        let raw: Data
        do { raw = try Data(contentsOf: fileURL) } catch { throw ShieldStoreError.unreadable("\(error)") }
        guard let env = try? JSONDecoder().decode(ShieldStoreEnvelope.self, from: raw) else {
            throw ShieldStoreError.corrupted("envelope decode failed")
        }
        guard DerivedReferenceFeature.checksum(of: env.payload) == env.payloadChecksum else {
            throw ShieldStoreError.corrupted("payload checksum mismatch")
        }
        guard var snap = try? JSONDecoder().decode(ShieldStoreSnapshot.self, from: env.payload) else {
            throw ShieldStoreError.corrupted("payload decode failed")
        }
        snap = Self.migrate(snap)
        return snap
    }

    public func save(_ snapshot: ShieldStoreSnapshot) throws {
        lock.lock(); defer { lock.unlock() }
        let payload = try JSONEncoder().encode(snapshot)
        let env = ShieldStoreEnvelope(envelopeVersion: ShieldStoreSnapshot.storeVersion,
                                      payloadChecksum: DerivedReferenceFeature.checksum(of: payload), payload: payload)
        let data = try JSONEncoder().encode(env)
        try data.write(to: fileURL, options: [.atomic])   // atomic write (temp + rename under the hood)
        #if os(iOS)
        if protectData {
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: fileURL.path)
        }
        #endif
    }

    public func wipe() throws {
        lock.lock(); defer { lock.unlock() }
        if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
    }

    /// Versioned migration hook. v1 is current; older versions would be upgraded here.
    private static func migrate(_ snap: ShieldStoreSnapshot) -> ShieldStoreSnapshot { snap }
}

/// Ties the durable store to the live index + engine-revision feature compatibility (006B §5,§7,§8).
public struct ShieldStoreManager: Sendable {
    public let store: PersonalShieldStore
    public let currentEngineID: String
    public let currentEngineRevision: String
    // Defaults track the 006C serializable-signature engine (Strategy A), NOT the old Vision feature-print.
    public init(store: PersonalShieldStore, currentEngineID: String = "ahash-8x8-v1",
                currentEngineRevision: String = "sig-r1") {
        self.store = store; self.currentEngineID = currentEngineID; self.currentEngineRevision = currentEngineRevision
    }

    /// Load snapshot, classify each reference rule's functional state, and return a freshly rebuilt index.
    /// The index is derived — never trusted from disk (crash-safe). Does NOT touch the MainActor.
    public func loadAndRebuild() throws -> (snapshot: ShieldStoreSnapshot, index: ShieldIndex) {
        var snap = try store.load()
        let featuresByRule = Dictionary(grouping: snap.features, by: { $0.ruleID })
        snap.rules = snap.rules.map { rule in
            var r = rule
            let needsReference = rule.inputType == .imageReference || rule.inputType == .logoReference
                || rule.inputType == .audioReference || rule.inputType == .musicTrack || rule.inputType == .musicArtist
            if needsReference {
                let feats = featuresByRule[rule.ruleID] ?? []
                if feats.contains(where: { !$0.isIntact }) {
                    r.corrupt = true                               // 006C §8 — checksum failure → CORRUPT, not active
                } else {
                    let hasUsable = feats.contains { $0.isCompatible(engineID: currentEngineID, engineRevision: currentEngineRevision) }
                    if !hasUsable { r.referenceReauthoringRequired = true }   // §7 — never silently pretend it works
                }
            }
            return r
        }
        return (snap, ShieldIndex.rebuilt(from: snap.rules))
    }

    /// Fetch the durable feature bytes for a rule (what the visual matcher decodes after relaunch).
    public func feature(for ruleID: String) throws -> DerivedReferenceFeature? {
        try store.load().features.first { $0.ruleID == ruleID }
    }
}
