import Foundation

// MARK: - Local admission cache (actor, bounded, no raw media)
// Ref: Build Bible §85, §499; PROMPT 001 §12. Stores only decision payloads keyed by ContentID+versions.
// No raw frames/video, no private-content global semantics. Bounded (LRU) + freshness TTL.

public struct CacheEntry: Sendable, Equatable {
    public let decision: AdmissionDecision
    public let heuristicVersion: String
    public let policyVersion: String
    public let storedAtNanos: UInt64
    public init(decision: AdmissionDecision, heuristicVersion: String, policyVersion: String, storedAtNanos: UInt64) {
        self.decision = decision
        self.heuristicVersion = heuristicVersion
        self.policyVersion = policyVersion
        self.storedAtNanos = storedAtNanos
    }
}

public actor LocalAdmissionCache {
    private let clock: MonotonicClock
    private let capacity: Int
    private let ttlNanos: UInt64
    private var entries: [ContentID: CacheEntry] = [:]
    private var lru: [ContentID] = []   // most-recent at end

    public init(clock: MonotonicClock, capacity: Int = 256, ttlNanos: UInt64 = 5 * 60 * 1_000_000_000) {
        self.clock = clock
        self.capacity = capacity
        self.ttlNanos = ttlNanos
    }

    /// Returns a fresh entry only if present, version-matched and within TTL. Else nil (caller treats as miss).
    public func lookup(_ id: ContentID, heuristicVersion: String, policyVersion: String) -> CacheEntry? {
        guard let e = entries[id] else { return nil }
        guard e.heuristicVersion == heuristicVersion, e.policyVersion == policyVersion else { return nil }
        guard clock.nowNanos &- e.storedAtNanos <= ttlNanos else {
            entries[id] = nil; lru.removeAll { $0 == id }; return nil
        }
        touch(id)
        return e
    }

    public func store(_ entry: CacheEntry) {
        let id = entry.decision.contentID
        entries[id] = entry
        touch(id)
        evictIfNeeded()
    }

    public func clear() { entries.removeAll(); lru.removeAll() }
    public var count: Int { entries.count }

    private func touch(_ id: ContentID) {
        lru.removeAll { $0 == id }
        lru.append(id)
    }

    private func evictIfNeeded() {
        while entries.count > capacity, let oldest = lru.first {
            lru.removeFirst()
            entries[oldest] = nil
        }
    }
}
