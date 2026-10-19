import Foundation

// MARK: - Privacy-safe decision trace & logging facade
// Ref: PROMPT 001 §17; Build Bible §91 (no chain-of-thought), §102 (no raw private content).

public struct DecisionTrace: Sendable, Equatable {
    public let traceID: String
    public let contentID: ContentID
    public let candidateSource: CandidateSource
    public let cacheHit: Bool
    public let heuristicVersion: String
    public let policyVersion: String
    public let admissionState: AdmissionState
    public let scoreState: ScoreState
    public let reason: DecisionReason
    public let coverage: GuardianCoverageState
    public let decisionLatencyNanos: UInt64
    public let timestampNanos: UInt64

    public init(traceID: String, contentID: ContentID, candidateSource: CandidateSource, cacheHit: Bool,
                heuristicVersion: String, policyVersion: String, admissionState: AdmissionState,
                scoreState: ScoreState, reason: DecisionReason, coverage: GuardianCoverageState,
                decisionLatencyNanos: UInt64, timestampNanos: UInt64) {
        self.traceID = traceID
        self.contentID = contentID
        self.candidateSource = candidateSource
        self.cacheHit = cacheHit
        self.heuristicVersion = heuristicVersion
        self.policyVersion = policyVersion
        self.admissionState = admissionState
        self.scoreState = scoreState
        self.reason = reason
        self.coverage = coverage
        self.decisionLatencyNanos = decisionLatencyNanos
        self.timestampNanos = timestampNanos
    }

    /// Structured, privacy-safe one-line log. Never contains raw media/text/secrets/tokens.
    public var logLine: String {
        "trace=\(traceID) content=\(contentID) src=\(candidateSource.rawValue) cache=\(cacheHit) " +
        "heur=\(heuristicVersion) policy=\(policyVersion) admit=\(admissionState.rawValue) " +
        "score=\(scoreState.rawValue) reason=\(reason.rawValue) cov=\(coverage.rawValue) " +
        "lat_ns=\(decisionLatencyNanos)"
    }
}

/// Minimal privacy-safe logging facade (replaceable with os_log/OSSignposter in the iOS target).
public protocol GuardianLog: Sendable {
    func record(_ trace: DecisionTrace)
}

public final class InMemoryGuardianLog: GuardianLog, @unchecked Sendable {
    private let lock = NSLock()
    public private(set) var traces: [DecisionTrace] = []
    public init() {}
    public func record(_ trace: DecisionTrace) { lock.lock(); traces.append(trace); lock.unlock() }
}
