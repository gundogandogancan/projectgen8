import Foundation

// MARK: - Device capability profile + model lifecycle (PROMPT 007 §23,§26)
// Routes a compute plan from a RUNTIME profile (chip/memory/OS/thermal/low-power) — never from hardcoded marketing names.

public struct DeviceCapabilityProfile: Sendable, Equatable {
    public enum MemoryClass: String, Sendable, Codable { case low, medium, high }        // derived from physical RAM, not model name
    public enum ComputeClass: String, Sendable, Codable { case basic, standard, advanced } // derived from core/NE availability
    public var memoryClass: MemoryClass
    public var computeClass: ComputeClass
    public var neuralEngineAvailable: Bool
    public var osMajorVersion: Int
    public var speechAssetsAvailable: Bool
    public var liveActivitySupported: Bool
    public var controlCenterControlSupported: Bool
    public var lowPower: Bool
    public var thermal: ThermalState
    public init(memoryClass: MemoryClass = .medium, computeClass: ComputeClass = .standard, neuralEngineAvailable: Bool = true,
                osMajorVersion: Int = 26, speechAssetsAvailable: Bool = false, liveActivitySupported: Bool = true,
                controlCenterControlSupported: Bool = true, lowPower: Bool = false, thermal: ThermalState = .nominal) {
        self.memoryClass = memoryClass; self.computeClass = computeClass; self.neuralEngineAvailable = neuralEngineAvailable
        self.osMajorVersion = osMajorVersion; self.speechAssetsAvailable = speechAssetsAvailable
        self.liveActivitySupported = liveActivitySupported; self.controlCenterControlSupported = controlCenterControlSupported
        self.lowPower = lowPower; self.thermal = thermal
    }

    /// Select a resource mode from runtime signals. Thermal/low-power dominate; then compute/memory class.
    public func recommendedMode() -> ResourceModeV2 {
        if thermal == .serious || thermal == .critical || lowPower { return .eco }
        switch (computeClass, memoryClass) {
        case (.advanced, .high): return .maxProtection
        case (.basic, _), (_, .low): return .eco
        default: return .balanced
        }
    }
    /// Whether heavy on-device models (e.g. a future H1 Core ML head) may be scheduled on this profile.
    public var allowsHeavyModels: Bool {
        !lowPower && thermal != .critical && thermal != .serious && computeClass != .basic && memoryClass != .low
    }
}

// §23 Model lifecycle V2 — lazy load, warm retention, unload under pressure, thermal/low-power downgrade, checksum/rollback.
public final class ModelLifecycleV2: @unchecked Sendable {
    public enum State: String, Sendable, Equatable { case cold, warm, unloaded, failedChecksum }
    public struct Stats: Sendable, Equatable { public var coldLoads = 0, warmHits = 0, unloads = 0, checksumFailures = 0, rollbacks = 0 }
    private let lock = NSLock()
    private var states: [String: State] = [:]
    private var stats = Stats()

    public init() {}

    /// Acquire a model handle. Lazy cold-load the first time; warm-hit thereafter (no repeated cold-load per item).
    @discardableResult
    public func acquire(_ modelID: String, checksumOK: Bool = true) -> State {
        lock.lock(); defer { lock.unlock() }
        guard checksumOK else { states[modelID] = .failedChecksum; stats.checksumFailures += 1; return .failedChecksum }
        switch states[modelID] {
        case .warm: stats.warmHits += 1; return .warm
        case .none, .unloaded, .cold, .failedChecksum:
            states[modelID] = .warm; stats.coldLoads += 1; return .warm   // cold→warm transition counts once
        }
    }

    /// Pressure/thermal/low-power downgrade → unload warm models (next acquire cold-loads lazily).
    public func unloadUnderPressure() {
        lock.lock(); defer { lock.unlock() }
        for (k, v) in states where v == .warm { states[k] = .unloaded; stats.unloads += 1 }
    }
    public func rollback(_ modelID: String) { lock.lock(); states[modelID] = .unloaded; stats.rollbacks += 1; lock.unlock() }
    public func state(_ modelID: String) -> State { lock.lock(); defer { lock.unlock() }; return states[modelID] ?? .cold }
    public func snapshot() -> Stats { lock.lock(); defer { lock.unlock() }; return stats }
}
