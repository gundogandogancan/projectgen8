import Foundation

// MARK: - Resource Governor V1 (PROMPT 002 §9) — event-driven, no permanent poll loop
// Degrades on thermal/low-power; idle → no inference without justified queued work.

public enum GovernorMode: String, Sendable { case eco = "ECO", balanced = "BALANCED", maxProtection = "MAX_PROTECTION" }

public struct GovernorInputs: Sendable {
    public let thermal: ThermalState
    public let lowPower: Bool
    public let foreground: Bool
    public let schedulerLoad: Int          // pending items
    public let recentLatencyNanos: UInt64
    public let activeModels: Int
    public let memoryPressure: Bool
    public init(thermal: ThermalState = .nominal, lowPower: Bool = false, foreground: Bool = true,
                schedulerLoad: Int = 0, recentLatencyNanos: UInt64 = 0, activeModels: Int = 0, memoryPressure: Bool = false) {
        self.thermal = thermal; self.lowPower = lowPower; self.foreground = foreground
        self.schedulerLoad = schedulerLoad; self.recentLatencyNanos = recentLatencyNanos
        self.activeModels = activeModels; self.memoryPressure = memoryPressure
    }
}

public struct GovernorOutput: Sendable, Equatable {
    public let mode: GovernorMode
    public let lookAheadDepth: Int          // ≤ 3
    public let maxConcurrentAnalyses: Int
    public let allowDeepAnalysis: Bool
    public let reason: String
}

public struct ResourceGovernor: Sendable {
    public init() {}
    public func evaluate(_ i: GovernorInputs, requested: GovernorMode = .balanced) -> GovernorOutput {
        // Degrade conditions force ECO regardless of request.
        if i.thermal == .critical || i.thermal == .serious {
            return .init(mode: .eco, lookAheadDepth: 1, maxConcurrentAnalyses: 1, allowDeepAnalysis: false,
                         reason: "thermal \(i.thermal.rawValue) → ECO degrade")
        }
        if i.lowPower {
            return .init(mode: .eco, lookAheadDepth: 1, maxConcurrentAnalyses: 1, allowDeepAnalysis: false,
                         reason: "low-power → ECO degrade")
        }
        if i.memoryPressure {
            return .init(mode: .eco, lookAheadDepth: 1, maxConcurrentAnalyses: 1, allowDeepAnalysis: false,
                         reason: "memory pressure → ECO degrade")
        }
        // Idle & nothing queued → no look-ahead work scheduled (event-driven).
        if i.schedulerLoad == 0 && !i.foreground {
            return .init(mode: .eco, lookAheadDepth: 0, maxConcurrentAnalyses: 0, allowDeepAnalysis: false,
                         reason: "idle/background, nothing queued → no inference")
        }
        switch requested {
        case .eco:
            return .init(mode: .eco, lookAheadDepth: 1, maxConcurrentAnalyses: 1, allowDeepAnalysis: false,
                         reason: "requested ECO")
        case .balanced:
            return .init(mode: .balanced, lookAheadDepth: 3, maxConcurrentAnalyses: 2, allowDeepAnalysis: true,
                         reason: "nominal → BALANCED")
        case .maxProtection:
            return .init(mode: .maxProtection, lookAheadDepth: 3, maxConcurrentAnalyses: 3, allowDeepAnalysis: true,
                         reason: "requested MAX_PROTECTION")
        }
    }
}
