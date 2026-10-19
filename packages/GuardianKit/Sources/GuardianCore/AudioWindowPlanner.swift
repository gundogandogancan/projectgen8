import Foundation

// MARK: - Audio Window Planner V1 (PROMPT 005 §13) — do NOT transcribe hours of audio blindly.
// Coarse/refine/skip windows; short dense, long sparse-first; boundaries + uncertainty deepen; cache wins.

public struct AudioWindow: Sendable, Equatable {
    public enum Kind: String, Sendable { case coarse, refine, skip }
    public let startSeconds: Double
    public let endSeconds: Double
    public let kind: Kind
    public let priority: Double
    public init(startSeconds: Double, endSeconds: Double, kind: Kind, priority: Double) {
        self.startSeconds = startSeconds; self.endSeconds = endSeconds; self.kind = kind; self.priority = priority
    }
}

public struct AudioWindowPlannerV1: Sendable {
    public static let version = "audio-window-planner-v1"
    public init() {}

    public func plan(durationSeconds: Double, sceneBoundaries: [Double], mode: ResourceModeV2,
                     cachedTranscript: Bool, uncertainRegions: [Double] = []) -> [AudioWindow] {
        guard durationSeconds > 0 else { return [] }
        if cachedTranscript {
            return [AudioWindow(startSeconds: 0, endSeconds: durationSeconds, kind: .skip, priority: 0)]  // cache wins
        }
        let coarseCount: Int
        switch mode {
        case .eco: coarseCount = durationSeconds < 60 ? 2 : 3
        case .balanced: coarseCount = durationSeconds < 60 ? 4 : 6
        case .maxProtection: coarseCount = durationSeconds < 60 ? 6 : 10
        }
        let step = durationSeconds / Double(coarseCount)
        var windows: [AudioWindow] = (0..<coarseCount).map {
            AudioWindow(startSeconds: Double($0)*step, endSeconds: Double($0+1)*step, kind: .coarse, priority: 0.5)
        }
        // Refine windows around boundaries + uncertain regions (bounded).
        for b in (sceneBoundaries + uncertainRegions).prefix(coarseCount) {
            windows.append(AudioWindow(startSeconds: max(0, b - 1), endSeconds: min(durationSeconds, b + 3),
                                       kind: .refine, priority: 0.9))
        }
        return windows.sorted { $0.priority > $1.priority }
    }
}
