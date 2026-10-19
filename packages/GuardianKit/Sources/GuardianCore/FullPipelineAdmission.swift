import Foundation

// MARK: - Full-pipeline admission timeline + task ledger (PROMPT 007 §15,§16,§22)
// Measures candidate_discovered_at → first_trustworthy_admission_at across REAL stages (not fusion-only).
// The fast path must not wait for the deep path — deep stages are recorded but excluded from first-trustworthy.

public enum PipelineStage: String, Sendable, Codable, CaseIterable {
    case identityCache = "IDENTITY_CACHE", textMerge = "TEXT_MERGE", ocr = "OCR", audio = "AUDIO", speech = "SPEECH"
    case visualSample = "VISUAL_SAMPLE", shield = "SHIELD", specialistHeads = "SPECIALIST_HEADS"
    case fusion = "FUSION", admission = "ADMISSION", uiStateReady = "UI_STATE_READY"
    case deepTemporal = "DEEP_TEMPORAL", deepSpeech = "DEEP_SPEECH"   // deep = non-blocking, excluded from first-trustworthy
    public var isDeep: Bool { self == .deepTemporal || self == .deepSpeech }
}

public enum AdmissionResultState: String, Sendable, Codable {
    case verifiedFast = "VERIFIED_FAST", provisionalFast = "PROVISIONAL_FAST", unknown = "UNKNOWN", cancelled = "CANCELLED"
}

/// Accumulates per-stage durations and computes first-trustworthy admission latency (fast stages only).
public struct AdmissionTimeline: Sendable, Equatable {
    public var caseName: String
    public var route: String
    public var stageNanos: [PipelineStage: UInt64]
    public var headCount: Int
    public var result: AdmissionResultState
    public var preExposureLeadNanos: UInt64      // how far before reveal the admission was ready
    public init(caseName: String, route: String, stageNanos: [PipelineStage: UInt64] = [:], headCount: Int = 0,
                result: AdmissionResultState = .unknown, preExposureLeadNanos: UInt64 = 0) {
        self.caseName = caseName; self.route = route; self.stageNanos = stageNanos
        self.headCount = headCount; self.result = result; self.preExposureLeadNanos = preExposureLeadNanos
    }
    /// First trustworthy admission = sum of NON-deep stages only (fast path does not wait for deep work).
    public var firstTrustworthyNanos: UInt64 { stageNanos.filter { !$0.key.isDeep }.values.reduce(0, +) }
    public var deepNanos: UInt64 { stageNanos.filter { $0.key.isDeep }.values.reduce(0, +) }
    public var firstTrustworthyMs: Double { Double(firstTrustworthyNanos) / 1_000_000 }
}

public enum AdmissionPercentile {
    public static func p(_ xs: [Double], _ q: Double) -> Double {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted(); return s[min(s.count - 1, Int(q * Double(s.count)))]
    }
}

// §22 Task-leak ledger — accounts active/cancelled/completed/maxConcurrent so soak tests can assert return-to-baseline.
public final class TaskLedger: @unchecked Sendable {
    public struct Stats: Sendable, Equatable {
        public var started = 0, completed = 0, cancelled = 0, active = 0, maxConcurrent = 0
        public var retainedMediaObjects = 0
    }
    private let lock = NSLock()
    private var stats = Stats()
    public init() {}
    public func start() { lock.lock(); stats.started += 1; stats.active += 1; stats.maxConcurrent = max(stats.maxConcurrent, stats.active); lock.unlock() }
    public func complete() { lock.lock(); stats.completed += 1; stats.active = max(0, stats.active - 1); lock.unlock() }
    public func cancel() { lock.lock(); stats.cancelled += 1; stats.active = max(0, stats.active - 1); lock.unlock() }
    public func retainMedia() { lock.lock(); stats.retainedMediaObjects += 1; lock.unlock() }
    public func releaseMedia() { lock.lock(); stats.retainedMediaObjects = max(0, stats.retainedMediaObjects - 1); lock.unlock() }
    public func snapshot() -> Stats { lock.lock(); defer { lock.unlock() }; return stats }
    /// True when all work has drained and no media objects are retained (soak return-to-baseline).
    public var isAtBaseline: Bool { let s = snapshot(); return s.active == 0 && s.retainedMediaObjects == 0 }
}
