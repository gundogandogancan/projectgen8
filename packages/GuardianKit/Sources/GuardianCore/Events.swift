import Foundation

// MARK: - Local Guardian events (conform to Phase-0 EVENT_CONTRACTS)
// Ref: docs/architecture/EVENT_CONTRACTS.md; PROMPT 001 §18. No raw private content in payloads.

public enum GuardianEvent: Sendable, Equatable {
    case candidateDiscovered(ContentID, CandidateSource)
    case contentIdentityResolved(ContentID, ContentIdentityState)
    case contentDNAResolved(ContentID)
    case fastPreflightCompleted(ContentID, ScoreState)
    case admissionDecisionReady(ContentID, AdmissionState)
    case guardianCoverageChanged(GuardianCoverageState)
    case temporalSegmentFlagged(ContentID, segmentIndex: Int)
    case guardianWarningIssued(ContentID, String)
    case guardianOverride(ContentID, String)
    case autoSkipExecuted(ContentID, segmentIndex: Int)

    public var name: String {
        switch self {
        case .candidateDiscovered: return "CandidateDiscovered"
        case .contentIdentityResolved: return "ContentIdentityResolved"
        case .contentDNAResolved: return "ContentDNAResolved"
        case .fastPreflightCompleted: return "FastPreflightCompleted"
        case .admissionDecisionReady: return "AdmissionDecisionReady"
        case .guardianCoverageChanged: return "GuardianCoverageChanged"
        case .temporalSegmentFlagged: return "TemporalSegmentFlagged"
        case .guardianWarningIssued: return "GuardianWarningIssued"
        case .guardianOverride: return "GuardianOverride"
        case .autoSkipExecuted: return "AutoSkipExecuted"
        }
    }
}

/// A privacy-safe sink for events. Implementations must never persist raw media/secrets.
public protocol GuardianEventSink: AnyObject, Sendable {
    func emit(_ event: GuardianEvent)
}

/// Thread-safe in-memory sink used in tests and GuardianLab diagnostics.
public final class RecordingEventSink: GuardianEventSink, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [GuardianEvent] = []
    public init() {}
    public func emit(_ event: GuardianEvent) {
        lock.lock(); _events.append(event); lock.unlock()
    }
    public var events: [GuardianEvent] {
        lock.lock(); defer { lock.unlock() }; return _events
    }
    public func names() -> [String] { events.map { $0.name } }
    public func clear() { lock.lock(); _events.removeAll(); lock.unlock() }
}
