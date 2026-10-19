import Foundation

// MARK: - Multimodal Temporal Fusion V2 (PROMPT 004 §13) — across windows, deterministic, versioned.
// Visual graphic may dominate exposure safety; text may disambiguate; modality conflict lowers confidence;
// missing modality stays UNKNOWN; local risk ≠ condemning whole video; repeated local risk influences whole.

public struct WindowSignals: Sendable, Equatable {
    public let startSeconds: Double
    public let endSeconds: Double
    public var visualCategories: Set<SensitiveCategory>      // from (future) H1 visual head
    public var textCategories: Set<SensitiveCategory>        // from H2 text head (OCR/transcript)
    public var visualAvailable: Bool
    public var textAvailable: Bool
    public var neutralTextContext: Bool                      // e.g. medical-education context
    public init(startSeconds: Double, endSeconds: Double, visualCategories: Set<SensitiveCategory> = [],
                textCategories: Set<SensitiveCategory> = [], visualAvailable: Bool = false,
                textAvailable: Bool = false, neutralTextContext: Bool = false) {
        self.startSeconds = startSeconds; self.endSeconds = endSeconds
        self.visualCategories = visualCategories; self.textCategories = textCategories
        self.visualAvailable = visualAvailable; self.textAvailable = textAvailable
        self.neutralTextContext = neutralTextContext
    }
}

public struct FusedSegment: Sendable, Equatable {
    public let startSeconds: Double
    public let endSeconds: Double
    public let categories: Set<SensitiveCategory>
    public let confidence: Double
    public let modalityConflict: Bool
}

public struct WholeVideoFusion: Sendable, Equatable {
    public let segments: [FusedSegment]
    public let flaggedFraction: Double          // fraction of duration flagged
    public let repeatedLocalRisk: Bool
    public let anyUnknown: Bool
}

public struct TemporalFusionV2: Sendable {
    public static let version = "temporal-fusion-v2"
    public init() {}

    public func fuseWindow(_ w: WindowSignals) -> FusedSegment {
        // Missing both modalities → UNKNOWN (no categories, low confidence).
        if !w.visualAvailable && !w.textAvailable {
            return FusedSegment(startSeconds: w.startSeconds, endSeconds: w.endSeconds,
                                categories: [], confidence: 0.1, modalityConflict: false)
        }
        var cats = w.visualCategories.union(w.textCategories)
        // Known graphic visual signal dominates exposure safety even if text is neutral.
        let visualGraphic = !w.visualCategories.isEmpty
        // Text disambiguation: neutral medical-education text can downgrade a text-only category.
        if !visualGraphic && w.neutralTextContext { cats = cats.subtracting([.disease]) }
        // Modality conflict: one modality flags, the other (available) does not.
        let conflict = w.visualAvailable && w.textAvailable &&
            (w.visualCategories.isEmpty != w.textCategories.isEmpty)
        let base = cats.isEmpty ? 0.5 : (visualGraphic ? 0.85 : 0.65)
        let confidence = conflict ? base * 0.6 : base      // conflict lowers confidence
        return FusedSegment(startSeconds: w.startSeconds, endSeconds: w.endSeconds,
                            categories: cats, confidence: confidence, modalityConflict: conflict)
    }

    public func fuseVideo(_ windows: [WindowSignals], durationSeconds: Double) -> WholeVideoFusion {
        let segs = windows.map(fuseWindow)
        let flaggedDur = segs.filter { !$0.categories.isEmpty }.reduce(0.0) { $0 + ($1.endSeconds - $1.startSeconds) }
        let frac = durationSeconds > 0 ? min(1.0, flaggedDur / durationSeconds) : 0
        let flaggedCount = segs.filter { !$0.categories.isEmpty }.count
        let anyUnknown = segs.contains { $0.confidence <= 0.15 }
        return WholeVideoFusion(segments: segs, flaggedFraction: frac,
                                repeatedLocalRisk: flaggedCount >= 3, anyUnknown: anyUnknown)
    }
}
