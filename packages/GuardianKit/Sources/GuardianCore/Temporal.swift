import Foundation

// MARK: - Temporal Guardian v0 + Skip-Safety Gate + Analysis-Ahead controller
// Ref: Build Bible §377, §386, §393–§394, §551, §632; PROMPT 001 §13, §14. Do NOT reduce a video to one score.
// Auto-skip requires identity I3+ AND version alignment. Wrong-version ⇒ refuse auto-skip (downgrade WARN/UNKNOWN).
// "Skip ≠ delete".

public struct TemporalSegment: Sendable, Equatable {
    public let index: Int
    public let startSeconds: Double
    public let endSeconds: Double
    public let flaggedCategories: Set<SensitiveCategory>
    public let flaggedConcepts: Set<String>
    public init(index: Int, startSeconds: Double, endSeconds: Double,
                flaggedCategories: Set<SensitiveCategory> = [], flaggedConcepts: Set<String> = []) {
        self.index = index
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.flaggedCategories = flaggedCategories
        self.flaggedConcepts = flaggedConcepts
    }
    public var isFlagged: Bool { !flaggedCategories.isEmpty || !flaggedConcepts.isEmpty }
}

public struct TemporalGraphStub: Sendable, Equatable {
    public let contentID: ContentID
    public let versionTag: String
    public let durationSeconds: Double
    public let segments: [TemporalSegment]
    public init(contentID: ContentID, versionTag: String, durationSeconds: Double, segments: [TemporalSegment]) {
        self.contentID = contentID
        self.versionTag = versionTag
        self.durationSeconds = durationSeconds
        self.segments = segments
    }
}

public enum AnalysisAheadState: String, Sendable {
    case verifiedAhead = "VERIFIED_AHEAD"
    case analyzingAhead = "ANALYZING_AHEAD"
    case unknownAhead = "UNKNOWN_AHEAD"
    case behindPlayhead = "BEHIND_PLAYHEAD"
}

public enum SkipDecision: String, Sendable {
    case autoSkip = "AUTO_SKIP"
    case ask = "ASK"
    case warn = "WARN"
    case refusedVersionMismatch = "REFUSED_VERSION_MISMATCH"   // identity/version mismatch → never blind-seek
}

public enum TemporalGuardMode: String, Sendable, CaseIterable {
    case strict = "STRICT"     // auto-skip aligned flagged segments
    case normal = "NORMAL"     // ask
    case guidance = "GUIDANCE" // warn only
}

public struct TemporalGuardian: Sendable {
    public init() {}

    /// Next flagged segment strictly after the given playhead.
    public func upcomingFlaggedSegment(graph: TemporalGraphStub, afterSeconds playhead: Double) -> TemporalSegment? {
        graph.segments.filter { $0.isFlagged && $0.startSeconds > playhead }
             .sorted { $0.startSeconds < $1.startSeconds }
             .first
    }

    /// Should a warning be issued now (flagged segment within `leadSeconds`)?
    public func shouldWarn(graph: TemporalGraphStub, playhead: Double, leadSeconds: Double) -> TemporalSegment? {
        guard let seg = upcomingFlaggedSegment(graph: graph, afterSeconds: playhead) else { return nil }
        return (seg.startSeconds - playhead) <= leadSeconds ? seg : nil
    }

    /// Temporal Skip-Safety Gate. identity MUST belong to the SAME content + version as the graph,
    /// and be strong (I3+), or auto-skip is refused.
    public func evaluateSkip(segment: TemporalSegment,
                             identity: ContentIdentityResult,
                             graph: TemporalGraphStub,
                             mode: TemporalGuardMode) -> SkipDecision {
        let aligned = identity.contentID == graph.contentID && identity.versionTag == graph.versionTag
        guard aligned, identity.state.allowsHighImpactAction else {
            return .refusedVersionMismatch   // downgrade — never blind-seek on stale/mismatched timeline
        }
        switch mode {
        case .strict:   return .autoSkip
        case .normal:   return .ask
        case .guidance: return .warn
        }
    }

    /// Analysis-ahead state from verified/analyzing coverage windows (seconds).
    public func analysisAheadState(playhead: Double, verifiedUntil: Double, analyzingUntil: Double) -> AnalysisAheadState {
        if verifiedUntil >= playhead && verifiedUntil > playhead { return .verifiedAhead }
        if analyzingUntil > playhead { return .analyzingAhead }
        if verifiedUntil < playhead && analyzingUntil < playhead { return .behindPlayhead }
        return .unknownAhead
    }
}
