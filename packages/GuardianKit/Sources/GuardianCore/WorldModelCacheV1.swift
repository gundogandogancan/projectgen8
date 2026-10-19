import Foundation

// MARK: - P009C §22 — world-model cache: authoritative identity only, version/taxonomy/generation-safe,
// split/merge + collision invalidation. Mirrors the R1 F6 cache laws at the semantic layer.

public final class WorldModelCacheV1: @unchecked Sendable {
    public static let revision = "world-model-cache-v1"
    public struct Key: Hashable { public let itemRaw: UInt64 }
    public struct Entry: Sendable {
        public let model: ContentWorldModelV1
        public let identityRevision: UInt64
        public let generation: UInt64
        public let worldModelVersion: String
        public let taxonomyVersion: String
        public let insertedAtMs: Double
        public let ttlMs: Double
    }
    private var store: [Key: Entry] = [:]
    private var order: [Key] = []
    private var pendingReanalysis = Set<UInt64>()
    public let maxEntries: Int, ttlMs: Double
    public private(set) var hits = 0, misses = 0, invalidations = 0
    private let lock = NSLock()
    public init(maxEntries: Int = 64, ttlMs: Double = 3_600_000) { self.maxEntries = maxEntries; self.ttlMs = ttlMs }

    public private(set) var purityRejections = 0
    /// Insert only for CONFIRMED identity models whose evidence is PURE (R1 §8 gate) — provisional or
    /// foreign-evidence models are rejected at the door.
    public func insert(_ model: ContentWorldModelV1, nowMs: Double) {
        guard WorldModelEvidencePurityGateV1.violations(model).isEmpty else {
            lock.lock(); purityRejections += 1; lock.unlock(); return
        }
        guard let item = model.itemID, model.identityStatus == "confirmed", !model.anyEvidenceProvisional else { return }
        lock.lock(); defer { lock.unlock() }
        let k = Key(itemRaw: item.raw)
        if store[k] == nil { order.append(k) }
        store[k] = Entry(model: model, identityRevision: model.identityRevision, generation: model.generation,
                         worldModelVersion: ContentWorldModelV1.modelVersion,
                         taxonomyVersion: model.taxonomyVersion, insertedAtMs: nowMs, ttlMs: ttlMs)
        while order.count > maxEntries { store.removeValue(forKey: order.removeFirst()) }
    }
    public func lookup(item: ContentItemID, identityRevision: UInt64, generation: UInt64, nowMs: Double) -> (ContentWorldModelV1?, String?) {
        lock.lock(); defer { lock.unlock() }
        if pendingReanalysis.remove(item.raw) != nil {
            store.removeValue(forKey: Key(itemRaw: item.raw)); order.removeAll { $0.itemRaw == item.raw }
            misses += 1; invalidations += 1; return (nil, "collision-reanalysis")
        }
        guard let e = store[Key(itemRaw: item.raw)] else { misses += 1; return (nil, nil) }
        if e.identityRevision != identityRevision { removeLocked(item.raw); misses += 1; return (nil, "revision-mismatch") }
        if e.worldModelVersion != ContentWorldModelV1.modelVersion { removeLocked(item.raw); misses += 1; return (nil, "model-version-mismatch") }
        if e.taxonomyVersion != SemanticTaxonomyV1.version { removeLocked(item.raw); misses += 1; return (nil, "taxonomy-version-mismatch") }
        if nowMs - e.insertedAtMs > e.ttlMs { removeLocked(item.raw); misses += 1; return (nil, "ttl-expired") }
        if e.generation != generation { misses += 1; return (nil, "generation-mismatch") }    // never silently reused
        // R1 §8: read-side purity re-check — an impure entry (however it got in) invalidates, never serves
        if !WorldModelEvidencePurityGateV1.violations(e.model).isEmpty {
            removeLocked(item.raw); purityRejections += 1; misses += 1; return (nil, "evidence-purity-violation")
        }
        hits += 1; return (e.model, nil)
    }
    public func invalidate(item: ContentItemID, reason: String) {
        lock.lock(); removeLocked(item.raw); lock.unlock()
    }
    public func reportIdentityCollision(item: ContentItemID, strength: IdentityCollisionStrengthV1) {
        lock.lock(); defer { lock.unlock() }
        switch strength {
        case .strong: removeLocked(item.raw)
        case .ambiguous: pendingReanalysis.insert(item.raw)
        }
    }
    public func sessionReset() { lock.lock(); store.removeAll(); order.removeAll(); pendingReanalysis.removeAll(); lock.unlock() }
    private func removeLocked(_ raw: UInt64) {
        if store.removeValue(forKey: Key(itemRaw: raw)) != nil { invalidations += 1 }
        order.removeAll { $0.itemRaw == raw }
    }
    public var count: Int { lock.lock(); defer { lock.unlock() }; return store.count }
}
