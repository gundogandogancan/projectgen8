import Foundation

// MARK: - Temporal Signal Extraction V1 (PROMPT 002 §19 / 002A §11)
// Coarse sample planning + timestamped windows; each produced signal records WHICH provider made it.
// No continuous full-FPS analysis — coarse-to-fine refinement hooks only.

public struct SamplePlan: Sendable, Equatable {
    public let timestampsSeconds: [Double]
    public let strategy: String        // e.g. "coarse-uniform"
    public init(timestampsSeconds: [Double], strategy: String) {
        self.timestampsSeconds = timestampsSeconds; self.strategy = strategy
    }
}

/// A timestamped signal with explicit provider attribution (002A §11).
public struct TimedSignal: Sendable, Equatable {
    public enum Modality: String, Sendable { case visual, text, audio, semantic }
    public let startSeconds: Double
    public let endSeconds: Double
    public let modality: Modality
    public let producedBy: String          // engine/provider version
    public let headTask: String?           // V2 (§28): WHICH specialist head produced this signal
    public let provenance: SignalProvenance
    public let categories: Set<SensitiveCategory>
    public let confidence: Double?
    // TemporalGraph V3 (PROMPT 004 §24): sampling/deepening state + scene + model versions.
    public let sceneID: Int?
    public let sampled: Bool
    public let deepened: Bool
    public let modelVersions: [String]
    public init(startSeconds: Double, endSeconds: Double, modality: Modality, producedBy: String,
                headTask: String? = nil, provenance: SignalProvenance,
                categories: Set<SensitiveCategory> = [], confidence: Double? = nil,
                sceneID: Int? = nil, sampled: Bool = false, deepened: Bool = false, modelVersions: [String] = []) {
        self.startSeconds = startSeconds; self.endSeconds = endSeconds; self.modality = modality
        self.producedBy = producedBy; self.headTask = headTask; self.provenance = provenance
        self.categories = categories; self.confidence = confidence
        self.sceneID = sceneID; self.sampled = sampled; self.deepened = deepened; self.modelVersions = modelVersions
    }
}

public struct TemporalExtractorV1: Sendable {
    public static let version = "temporal-extract-v1"
    public init() {}

    /// Coarse uniform sample plan — bounded number of samples, NOT per-frame (P0-B).
    public func planCoarseSamples(durationSeconds: Double, maxSamples: Int = 12) -> SamplePlan {
        guard durationSeconds > 0, maxSamples > 0 else { return .init(timestampsSeconds: [], strategy: "coarse-uniform") }
        let step = durationSeconds / Double(maxSamples)
        let ts = (0..<maxSamples).map { (Double($0) + 0.5) * step }
        return .init(timestampsSeconds: ts, strategy: "coarse-uniform")
    }

    /// Refinement hook: given a coarse flagged window, propose a finer plan around it (coarse-to-fine).
    public func refine(around window: (Double, Double), samples: Int = 4) -> SamplePlan {
        let (s, e) = window
        guard e > s, samples > 0 else { return .init(timestampsSeconds: [], strategy: "fine-refine") }
        let step = (e - s) / Double(samples)
        return .init(timestampsSeconds: (0..<samples).map { s + (Double($0) + 0.5) * step }, strategy: "fine-refine")
    }

    /// Build a TemporalGraph from timestamped signals, carrying provider attribution in descriptors.
    public func buildGraph(contentID: ContentID, versionTag: String, durationSeconds: Double,
                           signals: [TimedSignal]) -> TemporalGraphStub {
        let sorted = signals.sorted { $0.startSeconds < $1.startSeconds }
        let segs = sorted.enumerated().map { (i, sig) in
            TemporalSegment(index: i, startSeconds: sig.startSeconds, endSeconds: sig.endSeconds,
                            flaggedCategories: sig.categories,
                            flaggedConcepts: sig.categories.isEmpty ? [] : [sig.producedBy])
        }
        return TemporalGraphStub(contentID: contentID, versionTag: versionTag,
                                 durationSeconds: durationSeconds, segments: segs)
    }
}
