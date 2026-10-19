import Foundation

// MARK: - Universal multimodal runtime types (PROMPT 006 §5,§6,§7,§16,§18,§20,§24)

// §5 Universal content envelope — missing modality = UNKNOWN, never negative evidence.
public struct ContentObservationEnvelope: Sendable {
    public var contentID: ContentID?
    public var surfaceCapabilityTier: String?          // C5..C0
    public var structuredText: [TextSource]
    public var ocrText: [TextSource]
    public var captions: [TextSource]
    public var transcript: [TextSource]
    public var soundEvents: [String]
    public var musicIdentity: String?
    public var languageSignals: [String]
    public var temporalRanges: [ClosedRange<Double>]
    public var rightsClass: String
    public var privacyClass: String
    public var candidateDeadlineNanos: UInt64?
    public init() {
        contentID = nil; surfaceCapabilityTier = nil; structuredText = []; ocrText = []; captions = []
        transcript = []; soundEvents = []; musicIdentity = nil; languageSignals = []; temporalRanges = []
        rightsClass = "UNKNOWN"; privacyClass = "sensitive"; candidateDeadlineNanos = nil
    }
}

// §7 Text is first-class; source + provenance + timestamp preserved.
public struct TextSource: Sendable, Equatable {
    public enum Origin: Int, Sendable, Comparable {   // priority order (lower = higher priority)
        case structured = 0, captions = 1, subtitles = 2, metadata = 3, transcript = 4, ocr = 5
        public static func < (a: Origin, b: Origin) -> Bool { a.rawValue < b.rawValue }
    }
    public let origin: Origin
    public let text: String
    public let timestampSeconds: Double?
    public init(origin: Origin, text: String, timestampSeconds: Double? = nil) {
        self.origin = origin; self.text = text; self.timestampSeconds = timestampSeconds
    }
}

// §7 Text source merge contract: priority, dedup, provenance, conflict detection.
public struct TextSourceMerge: Sendable {
    public struct Result: Sendable, Equatable {
        public let merged: [TextSource]       // deduped, priority-ordered
        public let conflicts: [String]        // same timestamp, different normalized text across origins
        public let avoidedDuplicateAnalysis: Int
    }
    public init() {}
    public func merge(_ sources: [TextSource]) -> Result {
        let sorted = sources.sorted { $0.origin < $1.origin }
        var seen = Set<String>()
        var merged: [TextSource] = []
        var avoided = 0
        for s in sorted {
            let key = norm(s.text)
            if key.isEmpty { continue }
            if seen.contains(key) { avoided += 1; continue }   // dedupe identical text (no re-analysis)
            seen.insert(key); merged.append(s)
        }
        // Conflict: same timestamp bucket with differing text from different origins.
        var byTime: [Int: Set<String>] = [:]
        for s in merged { if let t = s.timestampSeconds { byTime[Int(t), default: []].insert(norm(s.text)) } }
        let conflicts = byTime.filter { $0.value.count > 1 }.map { "t=\($0.key): \($0.value.count) variants" }
        return Result(merged: merged, conflicts: conflicts.sorted(), avoidedDuplicateAnalysis: avoided)
    }
    private func norm(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
         .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }
}

// §16 Content complexity profile.
public enum ContentLengthClass: String, Sendable { case micro, short, medium, long, veryLong, liveOpenEnded }
public struct ContentComplexityProfile: Sendable, Equatable {
    public let lengthClass: ContentLengthClass
    public let modalityRichness: Int        // count of available modalities
    public let textDensity: Double
    public let speechDensity: Double
    public let sceneChangeRate: Double
    public let uncertainty: Double
    public let policySensitivity: Double
    public init(lengthClass: ContentLengthClass, modalityRichness: Int, textDensity: Double,
                speechDensity: Double, sceneChangeRate: Double, uncertainty: Double, policySensitivity: Double) {
        self.lengthClass = lengthClass; self.modalityRichness = modalityRichness; self.textDensity = textDensity
        self.speechDensity = speechDensity; self.sceneChangeRate = sceneChangeRate
        self.uncertainty = uncertainty; self.policySensitivity = policySensitivity
    }
    public static func classify(durationSeconds: Double, modalities: Int, uncertainty: Double, policySensitivity: Double,
                                live: Bool = false) -> ContentComplexityProfile {
        let lc: ContentLengthClass = live ? .liveOpenEnded :
            durationSeconds < 10 ? .micro : durationSeconds < 90 ? .short :
            durationSeconds < 600 ? .medium : durationSeconds < 3600 ? .long : .veryLong
        return ContentComplexityProfile(lengthClass: lc, modalityRichness: modalities, textDensity: 0,
                                        speechDensity: 0, sceneChangeRate: 0, uncertainty: uncertainty, policySensitivity: policySensitivity)
    }
}

// §18 Live content rolling mode.
public enum LiveContentMode: String, Sendable { case rollingFast, rollingDeep, coverageLag, unknownAhead }

// §23 Multimodal disagreement council — deterministic, no averaging.
public struct MultimodalDisagreementCouncil: Sendable {
    public struct Verdict: Sendable, Equatable {
        public let categories: Set<SensitiveCategory>
        public let confidence: Double
        public let conflict: Bool
        public let dominantReason: String
    }
    public init() {}
    public func resolve(visualGraphic: Set<SensitiveCategory>, textCategories: Set<SensitiveCategory>,
                        textIsNeutralEducation: Bool, visualAvailable: Bool, textAvailable: Bool) -> Verdict {
        if !visualAvailable && !textAvailable {
            return Verdict(categories: [], confidence: 0.1, conflict: false, dominantReason: "no modality → UNKNOWN")
        }
        // High-consequence visual safety may dominate exposure action.
        if !visualGraphic.isEmpty {
            return Verdict(categories: visualGraphic.union(textCategories), confidence: 0.85, conflict: false,
                           dominantReason: "graphic visual dominates exposure safety")
        }
        var cats = textCategories
        if textIsNeutralEducation { cats = cats.subtracting([.disease]) }   // text disambiguation
        let conflict = visualAvailable && textAvailable && (visualGraphic.isEmpty != textCategories.isEmpty)
        return Verdict(categories: cats, confidence: conflict ? 0.5 : 0.65, conflict: conflict,
                       dominantReason: conflict ? "modality conflict → lower confidence" : "text-led")
    }
}
