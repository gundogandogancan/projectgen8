import Foundation

// MARK: - Whole-Video Intelligence V1 (PROMPT 004 §3,§4,§5,§6,§14,§15,§16)
// Coarse-to-fine. NO full-FPS brute force. Everything deterministic + bounded + testable.

public enum ResourceModeV2: String, Sendable { case eco, balanced, maxProtection }

// MARK: §3 Coarse-to-fine sampler
public struct WholeVideoSampler: Sendable {
    public static let version = "whole-video-sampler-v1"
    public init() {}

    /// Max sample budget by resource mode — bounded, never per-frame.
    public func budget(for mode: ResourceModeV2, durationSeconds: Double) -> Int {
        let base: Int
        switch mode {
        case .eco: base = 8
        case .balanced: base = 16
        case .maxProtection: base = 32
        }
        // Long videos get more absolute samples but sub-linearly (coarse density).
        let extra = min(base, Int((durationSeconds / 60.0).rounded(.down)) * 2)
        return max(3, min(base + extra, base * 3))
    }

    /// Coarse representative timestamps. Short videos sample densely; long videos coarsely.
    /// Extra density is added around provided boundary candidates (more samples near cuts).
    public func plan(durationSeconds: Double, mode: ResourceModeV2,
                     boundaries: [Double] = []) -> SamplePlan {
        guard durationSeconds > 0 else { return SamplePlan(timestampsSeconds: [], strategy: "empty") }
        let n = budget(for: mode, durationSeconds: durationSeconds)
        let step = durationSeconds / Double(n)
        var ts = (0..<n).map { (Double($0) + 0.5) * step }
        // Add a sample just after each boundary (bounded to +n/2 extra).
        let extra = boundaries.prefix(n / 2).map { min(durationSeconds - 0.001, $0 + 0.25) }
        ts.append(contentsOf: extra)
        ts = Array(Set(ts.map { ($0 * 100).rounded() / 100 })).sorted()
        let strategy = durationSeconds < 60 ? "short-dense" : "long-coarse"
        return SamplePlan(timestampsSeconds: ts, strategy: "\(strategy)+boundary(\(mode.rawValue))")
    }
}

// MARK: §4 Scene / shot boundary detection
public struct FrameDescriptor: Sendable, Equatable {
    public let timestampSeconds: Double
    public let features: [Double]       // e.g. normalized luminance histogram / perceptual bits
    public init(timestampSeconds: Double, features: [Double]) {
        self.timestampSeconds = timestampSeconds; self.features = features
    }
}
public struct SceneBoundary: Sendable, Equatable {
    public let timestampSeconds: Double
    public let confidence: Double
    public let evidence: String
}
public struct SceneBoundaryDetectorV1: Sendable {
    public static let version = "scene-boundary-v1"
    public let threshold: Double
    public let minGapSeconds: Double
    public init(threshold: Double = 0.35, minGapSeconds: Double = 1.0) {
        self.threshold = threshold; self.minGapSeconds = minGapSeconds
    }
    private func distance(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 1.0 }
        let s = zip(a, b).reduce(0.0) { $0 + abs($1.0 - $1.1) }
        return s / Double(a.count)
    }
    /// Detect boundaries via successive feature difference + min-gap suppression (avoids overlay/dup spam).
    public func detect(_ frames: [FrameDescriptor]) -> [SceneBoundary] {
        guard frames.count > 1 else { return [] }
        var out: [SceneBoundary] = []
        var lastBoundary = -Double.greatestFiniteMagnitude
        for i in 1..<frames.count {
            let d = distance(frames[i-1].features, frames[i].features)
            if d >= threshold && (frames[i].timestampSeconds - lastBoundary) >= minGapSeconds {
                out.append(SceneBoundary(timestampSeconds: frames[i].timestampSeconds,
                                         confidence: min(1.0, d), evidence: "feature-diff \(String(format: "%.2f", d))"))
                lastBoundary = frames[i].timestampSeconds
            }
        }
        return out
    }
}

// MARK: §5 Coverage contract (NOT binary)
public struct WholeVideoCoverage: Sendable, Equatable, Codable {
    public var visualPercent: Double = 0
    public var audioPercent: Double = 0
    public var transcriptPercent: Double = 0
    public var semanticPercent: Double = 0
    public var temporalPercent: Double = 0
    public var highRiskRegionPercent: Double = 0
    public var unknownRegionPercent: Double = 100
    public init() {}
}

// MARK: §6 Confidence model (separate dimensions — no single magic number)
public struct WholeVideoConfidence: Sendable, Equatable {
    public let signalConfidence: Double?
    public let segmentConfidence: Double?
    public let videoCoverage: Double
    public let identityConfidence: Double
    public let policyConfidence: Double?
    public init(signalConfidence: Double?, segmentConfidence: Double?, videoCoverage: Double,
                identityConfidence: Double, policyConfidence: Double?) {
        self.signalConfidence = signalConfidence; self.segmentConfidence = segmentConfidence
        self.videoCoverage = videoCoverage; self.identityConfidence = identityConfidence
        self.policyConfidence = policyConfidence
    }
    /// A numeric overall score is eligible only when all gates pass.
    public func overallScoreEligible(minCoverage: Double, minIdentity: Double, unresolvedConflict: Bool) -> Bool {
        videoCoverage >= minCoverage && identityConfidence >= minIdentity && !unresolvedConflict
    }
}

// MARK: §14 Coarse temporal map
public struct CoarseWindow: Sendable, Equatable {
    public let startSeconds: Double
    public let endSeconds: Double
    public let sampled: Bool
    public let deepened: Bool
    public let categories: Set<SensitiveCategory>
    public let uncertainty: Double          // 0..1 (1 = fully unknown)
    public let value: Double                // 0..1 expected personal value
    public init(startSeconds: Double, endSeconds: Double, sampled: Bool, deepened: Bool,
                categories: Set<SensitiveCategory>, uncertainty: Double, value: Double) {
        self.startSeconds = startSeconds; self.endSeconds = endSeconds; self.sampled = sampled
        self.deepened = deepened; self.categories = categories; self.uncertainty = uncertainty; self.value = value
    }
    public var isFlagged: Bool { !categories.isEmpty }
}
public struct CoarseTemporalMapV1: Sendable, Equatable {
    public let contentID: ContentID
    public let versionTag: String
    public let windows: [CoarseWindow]
    public let coverage: WholeVideoCoverage
    public var flaggedWindows: [CoarseWindow] { windows.filter { $0.isFlagged } }
    public var unknownWindows: [CoarseWindow] { windows.filter { $0.uncertainty >= 0.7 } }
    public init(contentID: ContentID, versionTag: String, windows: [CoarseWindow], coverage: WholeVideoCoverage) {
        self.contentID = contentID; self.versionTag = versionTag; self.windows = windows; self.coverage = coverage
    }
}

// MARK: §15 Priority deepening engine (explicit, versioned formula)
public struct DeepeningPlannerV1: Sendable {
    public static let version = "deepening-planner-v1"
    public init() {}
    /// priority = (risk_uncertainty × exposure_imminence × policy_importance × info_gain) ÷ compute_cost
    public func priority(uncertainty: Double, exposureImminence: Double, policyImportance: Double,
                         expectedInfoGain: Double, computeCost: Double) -> Double {
        let cost = max(0.1, computeCost)
        return (uncertainty * exposureImminence * policyImportance * expectedInfoGain) / cost
    }
    /// Rank windows for deepening; returns indices in priority order, bounded by `maxDeepen`.
    public func plan(map: CoarseTemporalMapV1, playheadSeconds: Double, maxDeepen: Int, minPriority: Double = 0.05) -> [Int] {
        let scored = map.windows.enumerated().map { (idx, w) -> (Int, Double) in
            let imminence = w.startSeconds >= playheadSeconds ? max(0.1, 1.0 / (1.0 + (w.startSeconds - playheadSeconds) / 30.0)) : 0.2
            let policy = w.isFlagged ? 1.0 : 0.4
            let p = priority(uncertainty: w.uncertainty, exposureImminence: imminence,
                             policyImportance: policy, expectedInfoGain: w.uncertainty, computeCost: w.deepened ? 2.0 : 1.0)
            return (idx, w.deepened ? 0 : p)
        }
        // Early exit: windows below minPriority (calm + near-certain) are not worth deepening.
        return scored.sorted { $0.1 > $1.1 }.prefix(max(0, maxDeepen)).filter { $0.1 >= minPriority }.map { $0.0 }
    }
}

// MARK: §16 Analysis-Ahead V2
public struct AnalysisAheadV2: Sendable {
    public struct Lead: Sendable, Equatable {
        public let analyzedUntil: Double
        public let coarseUntil: Double
        public let deepUntil: Double
        public let unknownFrom: Double
        public let behind: Bool
    }
    public init() {}
    public func lead(playhead: Double, coarseUntil: Double, deepUntil: Double, safetyMarginSeconds: Double) -> Lead {
        let analyzed = max(coarseUntil, deepUntil)
        let behind = (analyzed - playhead) < safetyMarginSeconds
        return Lead(analyzedUntil: analyzed, coarseUntil: coarseUntil, deepUntil: deepUntil,
                    unknownFrom: analyzed, behind: behind)
    }
    public enum BehindAction: String, Sendable { case strictHold, cautionUnknown }
    public func actionWhenBehind(strictControlledSurface: Bool) -> BehindAction {
        strictControlledSurface ? .strictHold : .cautionUnknown   // never stale-safe
    }
}
