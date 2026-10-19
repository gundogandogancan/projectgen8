import Foundation

// MARK: - On-device model pack manifest (PROMPT 004 §22) — ACTIVE_LAB only, never production.
// Supply chain: every model entry carries checksum + version + license + rollback artifact.

public struct ModelPackEntry: Sendable, Equatable, Codable {
    public let task: String
    public let modelId: String
    public let checksum: String
    public let sizeBytes: Int
    public let runtime: String          // e.g. "swift-linear", "apple-vision", "apple-nl"
    public let minOS: String
    public let resourceClass: String    // TINY/LIGHT/MEDIUM/HEAVY
    public let calibrationVersion: String?   // nil = UNAVAILABLE
    public let license: String
    public let rollbackArtifact: String
    public init(task: String, modelId: String, checksum: String, sizeBytes: Int, runtime: String,
                minOS: String, resourceClass: String, calibrationVersion: String?, license: String, rollbackArtifact: String) {
        self.task = task; self.modelId = modelId; self.checksum = checksum; self.sizeBytes = sizeBytes
        self.runtime = runtime; self.minOS = minOS; self.resourceClass = resourceClass
        self.calibrationVersion = calibrationVersion; self.license = license; self.rollbackArtifact = rollbackArtifact
    }
}

public struct ModelPackManifest: Sendable, Equatable, Codable {
    public let packId: String
    public let version: String
    public let status: String           // "ACTIVE_LAB"
    public let models: [ModelPackEntry]
    public init(packId: String, version: String, status: String = "ACTIVE_LAB", models: [ModelPackEntry]) {
        self.packId = packId; self.version = version; self.status = status; self.models = models
    }
    /// A model may only activate if its entry has a checksum + rollback artifact (supply-chain gate).
    public func activationEligible(_ entry: ModelPackEntry) -> Bool {
        !entry.checksum.isEmpty && !entry.rollbackArtifact.isEmpty && status == "ACTIVE_LAB"
    }
    /// Verify a loaded model's checksum against its manifest entry (corrupt → reject).
    public func verify(modelId: String, actualChecksum: String) -> Bool {
        guard let e = models.first(where: { $0.modelId == modelId }) else { return false }
        return e.checksum == actualChecksum
    }
}
