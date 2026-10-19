import Foundation

// MARK: - P009C §7 — event/state graph. LAW: never invent causality — cause/effect are HYPOTHESES with
// uncertainty, added only under explicit adjacency conditions and always marked speculative.

public enum EventKindV1: String, Sendable, Codable {
    case topicShift = "event:topic-shift", riskEscalation = "event:risk-escalation"
    case riskRecovery = "event:risk-recovery", sceneReturn = "event:scene-return"
    case ctaAppearance = "event:cta-appearance", contradictionSurfaced = "event:contradiction"
    case modalityChange = "event:modality-change", stateChange = "event:state-change"
}

public struct SemanticEventV1: Sendable {
    public let kind: EventKindV1
    public let atMs: Double
    public let detail: String                      // canonical form only
    public let episodeID: UInt64?
    public let provenance: String
}

public struct CauseHypothesisV1: Sendable {
    public let causeEvent: EventKindV1
    public let effectEvent: EventKindV1
    public let uncertainty: Double                 // always high; floor 0.5 — speculation never hardens
    public let basis: String
    public let speculative = true                  // structurally ALWAYS speculative in P009C
}

public final class EventStateGraphV1: @unchecked Sendable {
    public static let revision = "event-state-graph-v1"
    private(set) public var events: [SemanticEventV1] = []
    private(set) public var causeHypotheses: [CauseHypothesisV1] = []
    private(set) public var riskState: Double = 0              // monotone-max mirror of the narrative law
    public let maxEvents: Int, maxHypotheses: Int
    private let lock = NSLock()
    public init(maxEvents: Int = 256, maxHypotheses: Int = 32) { self.maxEvents = maxEvents; self.maxHypotheses = maxHypotheses }

    public func record(_ e: SemanticEventV1) {
        lock.lock(); defer { lock.unlock() }
        guard events.count < maxEvents else { return }
        events.append(e)
        if e.kind == .riskEscalation { riskState = max(riskState, 0.6) }
        // §7 cause/effect: ONLY same-episode adjacent pairs become hypotheses, always speculative
        if events.count >= 2 {
            let prev = events[events.count - 2]
            if prev.episodeID != nil, prev.episodeID == e.episodeID, e.atMs - prev.atMs < 10_000,
               causeHypotheses.count < maxHypotheses {
                causeHypotheses.append(CauseHypothesisV1(causeEvent: prev.kind, effectEvent: e.kind,
                                                         uncertainty: max(0.5, 0.8), basis: "temporal-adjacency-only"))
            }
        }
    }
    /// de-escalation is RECORDED but can never lower riskState (narrative law mirror)
    public func recordRecovery(atMs: Double, episodeID: UInt64?) {
        record(SemanticEventV1(kind: .riskRecovery, atMs: atMs, detail: "event:risk-recovery (historical risk retained)",
                               episodeID: episodeID, provenance: Self.revision))
    }
    public var ordered: [SemanticEventV1] { lock.lock(); defer { lock.unlock() }; return events }
    public var count: Int { lock.lock(); defer { lock.unlock() }; return events.count }
}
