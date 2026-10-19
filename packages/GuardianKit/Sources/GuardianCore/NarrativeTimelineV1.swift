import Foundation

// MARK: - P009C §8 — narrative timeline. LAW: historical strong-risk evidence remains part of the
// narrative; later benign evidence can NEVER erase it. Later context may reinterpret earlier AMBIGUOUS
// evidence only with provenance.

public struct NarrativeSegmentV1: Sendable {
    public let episodeID: UInt64
    public let startMs: Double, endMs: Double
    public let dominantConcepts: [String]
    public let riskLevel: Double                   // this segment's own evidence
    public let benefitPresent: Bool
    public let manipulationPresent: Bool
}

public struct NarrativeMotifV1: Sendable {
    public let concept: String
    public let occurrences: Int                    // repeated motifs / scene returns
}

public struct NarrativeReinterpretationV1: Sendable {
    public let episodeID: UInt64
    public let from: String, to: String
    public let basis: String                        // provenance REQUIRED
    public let atMs: Double
}

public final class NarrativeTimelineV1: @unchecked Sendable {
    public static let revision = "narrative-timeline-v1"
    private(set) public var segments: [NarrativeSegmentV1] = []
    private(set) public var reinterpretations: [NarrativeReinterpretationV1] = []
    private(set) public var maxRiskSeen: Double = 0            // monotone — the §8 law
    private(set) public var riskEscalationAtMs: Double?
    private(set) public var recoveryObservedAtMs: Double?      // recorded, but risk retained
    private(set) public var ctaNearEnd = false
    private(set) public var unresolvedEnding = false
    public let maxSegments: Int
    private let lock = NSLock()
    public init(maxSegments: Int = 256) { self.maxSegments = maxSegments }

    /// Historical risk registration (includes the temporal expert's monotone memory). Separate from the
    /// per-segment CURRENT risk so recovery can be observed while escalation is never erased.
    public func registerRisk(_ risk: Double, atMs: Double) {
        lock.lock(); defer { lock.unlock() }
        if risk > maxRiskSeen {
            maxRiskSeen = risk
            if risk >= 0.6 && riskEscalationAtMs == nil { riskEscalationAtMs = atMs }
        }
    }
    public func append(_ s: NarrativeSegmentV1) {
        lock.lock(); defer { lock.unlock() }
        guard segments.count < maxSegments else { return }
        segments.append(s)
        if s.riskLevel > maxRiskSeen {
            maxRiskSeen = s.riskLevel
            if s.riskLevel >= 0.6 && riskEscalationAtMs == nil { riskEscalationAtMs = s.startMs }
        } else if maxRiskSeen >= 0.6 && s.riskLevel < 0.2 && recoveryObservedAtMs == nil {
            recoveryObservedAtMs = s.startMs                   // de-escalation NOTED; maxRiskSeen untouched
        }
    }
    /// §8: reinterpreting earlier evidence requires (a) the earlier state to be ambiguous-class and
    /// (b) explicit provenance. Strong risk is never reinterpretable away.
    @discardableResult
    public func reinterpret(episodeID: UInt64, from: String, to: String, basis: String,
                            earlierWasAmbiguous: Bool, atMs: Double) -> Bool {
        guard earlierWasAmbiguous, !basis.isEmpty else { return false }
        lock.lock(); defer { lock.unlock() }
        guard reinterpretations.count < 64 else { return false }
        reinterpretations.append(NarrativeReinterpretationV1(episodeID: episodeID, from: from, to: to, basis: basis, atMs: atMs))
        return true
    }
    public func markCTANearEnd() { lock.lock(); ctaNearEnd = true; lock.unlock() }
    public func markUnresolvedEnding() { lock.lock(); unresolvedEnding = true; lock.unlock() }

    /// repeated motifs + scene returns (same dominant concept re-appearing after absence)
    public func motifs() -> [NarrativeMotifV1] {
        lock.lock(); defer { lock.unlock() }
        var counts: [String: Int] = [:]
        var lastConceptSet: Set<String> = []
        var returns: [String: Int] = [:]
        for s in segments {
            let cs = Set(s.dominantConcepts)
            for c in cs {
                counts[c, default: 0] += 1
                if !lastConceptSet.contains(c), counts[c]! > 1 { returns[c, default: 0] += 1 }
            }
            lastConceptSet = cs
        }
        return counts.filter { $0.value > 1 }.map { NarrativeMotifV1(concept: $0.key, occurrences: $0.value) }
            .sorted { $0.occurrences > $1.occurrences }
    }
    /// canonical narrative labels (durable-lawful forms only)
    public func summaryLabels() -> [String] {
        lock.lock(); defer { lock.unlock() }
        var out = ["narrative:segments:\(segments.count)"]
        if maxRiskSeen >= 0.6 { out.append("narrative:risk-escalated") }
        if recoveryObservedAtMs != nil { out.append("narrative:recovery-observed (historical risk retained)") }
        if ctaNearEnd { out.append("narrative:cta-near-end") }
        if unresolvedEnding { out.append("narrative:unresolved-ending") }
        if !reinterpretations.isEmpty { out.append("narrative:reinterpretations:\(reinterpretations.count)") }
        return out
    }
}
