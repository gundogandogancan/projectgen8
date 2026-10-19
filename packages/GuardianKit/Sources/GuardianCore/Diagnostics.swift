import Foundation

// MARK: - Device-health & timing abstractions (P0-B)
// Ref: DEVICE_RESOURCE_BUDGETS.yaml, P001_DEVICE_MEASUREMENT_PROTOCOL.md; PROMPT 001 §15.
// Real timing via an injectable monotonic clock. Device conditions injected so tests are deterministic
// and the core stays platform-independent. No faked CPU/GPU/energy values here.

public protocol MonotonicClock: Sendable {
    /// Monotonic timestamp in nanoseconds.
    var nowNanos: UInt64 { get }
}

/// Real wall-clock using DispatchTime (monotonic uptime). Used in app + benchmarks.
public struct SystemMonotonicClock: MonotonicClock {
    public init() {}
    public var nowNanos: UInt64 { DispatchTime.now().uptimeNanoseconds }
}

/// Deterministic clock for tests; advance manually.
public final class ManualClock: MonotonicClock, @unchecked Sendable {
    private let lock = NSLock()
    private var t: UInt64
    public init(start: UInt64 = 0) { self.t = start }
    public var nowNanos: UInt64 { lock.lock(); defer { lock.unlock() }; return t }
    public func advance(nanos: UInt64) { lock.lock(); t &+= nanos; lock.unlock() }
}

public enum ThermalState: String, Sendable { case nominal, fair, serious, critical }

public protocol DeviceConditionProvider: Sendable {
    var thermalState: ThermalState { get }
    var lowPowerMode: Bool { get }
}

/// Deterministic device conditions for tests.
public struct StubDeviceConditions: DeviceConditionProvider {
    public let thermalState: ThermalState
    public let lowPowerMode: Bool
    public init(thermalState: ThermalState = .nominal, lowPowerMode: Bool = false) {
        self.thermalState = thermalState
        self.lowPowerMode = lowPowerMode
    }
}

/// Aggregated runtime counters proving P0-B invariants (bounded work, cache reuse, no redundant analysis).
public final class Diagnostics: @unchecked Sendable {
    private let lock = NSLock()
    public private(set) var cacheHits = 0
    public private(set) var cacheMisses = 0
    public private(set) var preflightRuns = 0
    public private(set) var cancellations = 0
    public private(set) var duplicateAnalysisPrevented = 0
    public private(set) var peakConcurrentTasks = 0
    public private(set) var networkBytes = 0            // must stay 0 on local fixture path
    public private(set) var decisionLatenciesNanos: [UInt64] = []

    public init() {}

    public func recordCacheHit() { lock.lock(); cacheHits += 1; lock.unlock() }
    public func recordCacheMiss() { lock.lock(); cacheMisses += 1; lock.unlock() }
    public func recordPreflight() { lock.lock(); preflightRuns += 1; lock.unlock() }
    public func recordCancellation() { lock.lock(); cancellations += 1; lock.unlock() }
    public func recordDuplicatePrevented() { lock.lock(); duplicateAnalysisPrevented += 1; lock.unlock() }
    public func recordConcurrentTasks(_ n: Int) { lock.lock(); peakConcurrentTasks = max(peakConcurrentTasks, n); lock.unlock() }
    public func recordDecisionLatency(_ nanos: UInt64) { lock.lock(); decisionLatenciesNanos.append(nanos); lock.unlock() }

    public var snapshot: ResourceSnapshot {
        lock.lock(); defer { lock.unlock() }
        let count = decisionLatenciesNanos.count
        let p50: UInt64 = count == 0 ? 0 : decisionLatenciesNanos.sorted()[count / 2]
        return ResourceSnapshot(cacheHits: cacheHits, cacheMisses: cacheMisses, preflightRuns: preflightRuns,
                                cancellations: cancellations, duplicateAnalysisPrevented: duplicateAnalysisPrevented,
                                peakConcurrentTasks: peakConcurrentTasks, networkBytes: networkBytes,
                                decisionCount: count, decisionLatencyP50Nanos: p50)
    }
}

public struct ResourceSnapshot: Sendable, Equatable {
    public let cacheHits: Int
    public let cacheMisses: Int
    public let preflightRuns: Int
    public let cancellations: Int
    public let duplicateAnalysisPrevented: Int
    public let peakConcurrentTasks: Int
    public let networkBytes: Int
    public let decisionCount: Int
    public let decisionLatencyP50Nanos: UInt64
}
