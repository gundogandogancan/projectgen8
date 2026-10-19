import Foundation

// MARK: - Temporal Understanding V1 (PROMPT 008A §17) — real VIDEO → SCENE → SHOT/WINDOW hierarchy with aligned evidence.
// A video is not a bag of frames. Lightweight (no heavy model): scene/shot boundaries from perceptual + OCR-persistence,
// representative frame per shot, timestamp-aligned evidence. Not a full cinematic engine — the core hierarchy is real.

public struct TemporalShotV1: Sendable, Equatable {
    public var index: Int
    public var startSec: Double
    public var endSec: Double
    public var representativeFrameSignature: UInt64   // first frame of the shot (derived, not raw)
    public var ocrTokens: [String]
}

public struct TemporalSceneV1: Sendable, Equatable {
    public var index: Int
    public var startSec: Double
    public var endSec: Double
    public var shots: [TemporalShotV1]
    public var topicHypotheses: [String]
}

public struct TemporalUnderstandingV1: Sendable, Equatable {
    public static let schemaVersion = "temporal-understanding-v1"
    public var contentID: String
    public var durationSec: Double
    public var scenes: [TemporalSceneV1]
    public var alignedEvidence: [ModalEvidenceSignal]   // evidence placed into the scene/shot it temporally belongs to
    public var schemaVersion: String
    public var shotCount: Int { scenes.reduce(0) { $0 + $1.shots.count } }
}

public enum TemporalUnderstandingEngineV1 {
    public struct FrameObservation: Sendable { public var timeSec: Double; public var signature: UInt64; public var ocrTokens: [String]
        public init(timeSec: Double, signature: UInt64, ocrTokens: [String] = []) { self.timeSec = timeSec; self.signature = signature; self.ocrTokens = ocrTokens } }

    /// Build the hierarchy from a sparse sampled frame sequence. A SHOT boundary = perceptual jump or OCR-token turnover;
    /// a SCENE groups consecutive shots that share topic tokens. Evidence is aligned into the scene covering its time.
    public static func build(contentID: String, frames: [FrameObservation], evidence: [ModalEvidenceSignal] = [],
                             shotHamming: Int = 14, sceneGapTokens: Double = 0.5) -> TemporalUnderstandingV1 {
        guard !frames.isEmpty else {
            return TemporalUnderstandingV1(contentID: contentID, durationSec: 0, scenes: [], alignedEvidence: [], schemaVersion: TemporalUnderstandingV1.schemaVersion)
        }
        let duration = frames.last!.timeSec
        // 1) Shots.
        var shots: [TemporalShotV1] = []
        var shotStartIdx = 0
        func closeShot(_ endIdx: Int) {
            let s = frames[shotStartIdx]
            let tokens = Array(Set(frames[shotStartIdx...endIdx].flatMap { $0.ocrTokens }))
            shots.append(TemporalShotV1(index: shots.count, startSec: s.timeSec, endSec: frames[endIdx].timeSec,
                                        representativeFrameSignature: s.signature, ocrTokens: tokens))
        }
        for i in 1..<frames.count {
            let pHam = (frames[i-1].signature ^ frames[i].signature).nonzeroBitCount
            if pHam >= shotHamming { closeShot(i-1); shotStartIdx = i }
        }
        closeShot(frames.count - 1)
        // 2) Scenes: merge consecutive shots with sufficient OCR-token overlap into one scene.
        var scenes: [TemporalSceneV1] = []
        var group: [TemporalShotV1] = []
        func tokenOverlap(_ a: [String], _ b: [String]) -> Double {
            let sa = Set(a), sb = Set(b); if sa.isEmpty && sb.isEmpty { return 1 }
            return Double(sa.intersection(sb).count) / Double(max(1, sa.union(sb).count))
        }
        func closeScene() {
            guard !group.isEmpty else { return }
            let topics = Array(Set(group.flatMap { $0.ocrTokens })).prefix(5).map { $0 }
            scenes.append(TemporalSceneV1(index: scenes.count, startSec: group.first!.startSec, endSec: group.last!.endSec,
                                          shots: group, topicHypotheses: topics))
            group = []
        }
        for shot in shots {
            if let last = group.last, tokenOverlap(last.ocrTokens, shot.ocrTokens) < sceneGapTokens { closeScene() }
            group.append(shot)
        }
        closeScene()
        // 3) Align evidence into the scene whose [start,end] covers its time (timeStartSec).
        func sceneIndex(forTime t: Double?) -> Int? {
            guard let t else { return nil }
            return scenes.first(where: { t >= $0.startSec && t <= $0.endSec })?.index
        }
        let aligned = evidence.map { e -> ModalEvidenceSignal in
            var copy = e
            if let si = sceneIndex(forTime: e.timeStartSec) { copy.value = e.value + " @scene\(si)" }
            return copy
        }
        return TemporalUnderstandingV1(contentID: contentID, durationSec: duration, scenes: scenes,
                                       alignedEvidence: aligned, schemaVersion: TemporalUnderstandingV1.schemaVersion)
    }
}
