import Foundation

// MARK: - P009C — world-model provenance: every semantic conclusion carries who/what/when, bounded.

public struct WorldModelProvenanceEntryV1: Sendable, Codable {
    public let subject: String                 // what was concluded (canonical form)
    public let producer: String                // which subsystem produced it
    public let basis: [String]                 // evidence provenance strings it rests on
    public let modelVersions: [String]
    public let taxonomyVersion: String
    public let generation: UInt64
    public let atMs: Double
    public init(subject: String, producer: String, basis: [String], modelVersions: [String],
                taxonomyVersion: String, generation: UInt64, atMs: Double) {
        self.subject = subject; self.producer = producer; self.basis = basis
        self.modelVersions = modelVersions; self.taxonomyVersion = taxonomyVersion
        self.generation = generation; self.atMs = atMs
    }
}

public final class WorldModelProvenanceV1: @unchecked Sendable {
    public static let revision = "world-model-provenance-v1"
    private(set) public var entries: [WorldModelProvenanceEntryV1] = []
    public let maxEntries: Int
    private let lock = NSLock()
    public init(maxEntries: Int = 512) { self.maxEntries = maxEntries }
    public func record(_ e: WorldModelProvenanceEntryV1) {
        lock.lock(); entries.append(e)
        if entries.count > maxEntries { entries.removeFirst(entries.count - maxEntries) }
        lock.unlock()
    }
    public func trace(subjectPrefix: String) -> [WorldModelProvenanceEntryV1] {
        lock.lock(); defer { lock.unlock() }
        return entries.filter { $0.subject.hasPrefix(subjectPrefix) }
    }
    public var count: Int { lock.lock(); defer { lock.unlock() }; return entries.count }
}
