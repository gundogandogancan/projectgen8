import Foundation

// MARK: - Pre-exposure metrics (PROMPT 002 §21 / 002A §13) — LAB_MEASURED only (not production SLO)
// Per-exposure timing record + PRE_EXPOSURE_COVERAGE_RATE aggregate. All values labelled LAB_MEASURED.

public struct ExposureRecord: Sendable, Equatable {
    public let contentID: ContentID
    public let candidateDiscoveredAtNanos: UInt64
    public let analysisStartedAtNanos: UInt64
    public let trustworthyDecisionAtNanos: UInt64
    public let contentRevealedAtNanos: UInt64
    public let cacheState: String          // "hit" | "miss"
    public let route: String               // InferenceEngine raw
    public let resourceMode: String        // GovernorMode raw
    public let unknownReason: String?      // nil unless admission UNKNOWN
    public let engineVersions: [String: String]
    public let measurementLabel = "LAB_MEASURED"

    public var leadTimeNanos: Int64 {       // reveal - trustworthy decision (positive = decided before reveal)
        Int64(contentRevealedAtNanos) - Int64(trustworthyDecisionAtNanos)
    }
    public var decisionBeforeReveal: Bool { trustworthyDecisionAtNanos <= contentRevealedAtNanos }

    public init(contentID: ContentID, candidateDiscoveredAtNanos: UInt64, analysisStartedAtNanos: UInt64,
                trustworthyDecisionAtNanos: UInt64, contentRevealedAtNanos: UInt64, cacheState: String,
                route: String, resourceMode: String, unknownReason: String?, engineVersions: [String: String]) {
        self.contentID = contentID
        self.candidateDiscoveredAtNanos = candidateDiscoveredAtNanos
        self.analysisStartedAtNanos = analysisStartedAtNanos
        self.trustworthyDecisionAtNanos = trustworthyDecisionAtNanos
        self.contentRevealedAtNanos = contentRevealedAtNanos
        self.cacheState = cacheState
        self.route = route
        self.resourceMode = resourceMode
        self.unknownReason = unknownReason
        self.engineVersions = engineVersions
    }
}

public final class PreExposureMetrics: @unchecked Sendable {
    private let lock = NSLock()
    private var records: [ExposureRecord] = []
    public init() {}

    public func record(_ r: ExposureRecord) { lock.lock(); records.append(r); lock.unlock() }
    public var all: [ExposureRecord] { lock.lock(); defer { lock.unlock() }; return records }

    /// Fraction of exposures where a trustworthy decision was ready before reveal. LAB_MEASURED.
    public var preExposureCoverageRate: Double {
        lock.lock(); defer { lock.unlock() }
        guard !records.isEmpty else { return 0 }
        let covered = records.filter { $0.decisionBeforeReveal }.count
        return Double(covered) / Double(records.count)
    }
    public var count: Int { lock.lock(); defer { lock.unlock() }; return records.count }
}
