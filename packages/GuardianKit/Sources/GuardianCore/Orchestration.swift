import Foundation

// MARK: - Adaptive orchestration (PROMPT 006 §17,§18,§19,§20,§21,§22) — NOT one giant LLM. No "run all heads".

public enum HeadID: String, Sendable, CaseIterable {
    case language, ocrText, structuredText, semanticTopic, mdd, attention, shield
    case visualFeature, sensitiveVisual, generalAudio, music, speech, temporal, evidence
}

public struct HeadPlan: Sendable, Equatable {
    public let fast: [HeadID]
    public let deep: [HeadID]
    public let skipped: [HeadID]
    public let computeBudget: ComputeBudget
}

public struct ComputeBudget: Sendable, Equatable {
    public let latencyBudgetMs: Int
    public let maxConcurrentHeads: Int
    public let maxFrameSamples: Int
    public let maxAudioWindows: Int
    public let maxDeepWindows: Int
    public let networkAllowed: Bool
    public let cloudAllowed: Bool
    public let mode: ResourceModeV2
}

// §18 Compute budget planner — cloud OFF by default this phase.
public struct ComputeBudgetPlanner: Sendable {
    public init() {}
    public func plan(_ c: ContentComplexityProfile, cached: Bool, mode: ResourceModeV2,
                     thermal: ThermalState, lowPower: Bool, exposureDeadlineMs: Int?) -> ComputeBudget {
        var effective = mode
        if thermal == .serious || thermal == .critical || lowPower { effective = .eco }
        let baseLatency = exposureDeadlineMs ?? 1000
        func scaled(_ eco: Int, _ bal: Int, _ max: Int) -> Int { effective == .eco ? eco : effective == .balanced ? bal : max }
        if cached {
            return ComputeBudget(latencyBudgetMs: min(baseLatency, 300), maxConcurrentHeads: 1, maxFrameSamples: 0,
                                 maxAudioWindows: 0, maxDeepWindows: 0, networkAllowed: false, cloudAllowed: false, mode: effective)
        }
        let heavy = c.lengthClass == .long || c.lengthClass == .veryLong
        return ComputeBudget(latencyBudgetMs: baseLatency,
                             maxConcurrentHeads: scaled(1, 2, 3),
                             maxFrameSamples: heavy ? scaled(8, 16, 32) : scaled(4, 8, 12),
                             maxAudioWindows: scaled(2, 4, 6),
                             maxDeepWindows: scaled(1, 3, 4),
                             networkAllowed: false, cloudAllowed: false, mode: effective)
    }
}

// §17 Adaptive intelligence orchestrator — schedules specialist heads (smallest sufficient).
public struct IntelligenceOrchestrator: Sendable {
    public static let version = "intelligence-orchestrator-v1"
    public init() {}
    public func plan(complexity: ContentComplexityProfile, budget: ComputeBudget, cached: Bool,
                     hasText: Bool, hasAudio: Bool, hasVideo: Bool, policySensitive: Bool) -> HeadPlan {
        if cached {
            return HeadPlan(fast: [], deep: [], skipped: HeadID.allCases, computeBudget: budget)   // reuse: run nothing
        }
        var fast: [HeadID] = []
        var deep: [HeadID] = []
        var skipped: [HeadID] = []
        // FAST: cheap text-first signals.
        if hasText { fast += [.structuredText, .language, .semanticTopic, .mdd, .attention, .shield] }
        if hasVideo { fast += [.ocrText, .visualFeature] }
        if hasAudio { fast += [.generalAudio] }      // coarse audio class is cheap
        // DEEP: selective, deadline-permitting.
        if hasVideo && (complexity.uncertainty > 0.5 || policySensitive) { deep += [.temporal, .sensitiveVisual] }
        if hasAudio && (policySensitive || complexity.speechDensity > 0.3) { deep += [.speech, .music] }
        if policySensitive { deep += [.evidence] }
        // Honor concurrency: anything beyond budget.maxConcurrentHeads in FAST stays but is throttled by caller;
        // heads not applicable are skipped.
        let used = Set(fast + deep)
        skipped = HeadID.allCases.filter { !used.contains($0) }
        return HeadPlan(fast: fast, deep: deep, skipped: skipped, computeBudget: budget)
    }
}

// §19 Sub-second admission orchestrator — real timing, no fake sleep. Deep path does not block.
public struct SubSecondAdmission: Sendable {
    public struct Result: Sendable, Equatable {
        public let state: ScoreState
        public let admission: AdmissionState
        public let latencyNanos: UInt64
        public let route: String
        public let deepScheduled: Bool
    }
    let clock: MonotonicClock
    let fusion = ScoreAdmissionFusionV1()
    public init(clock: MonotonicClock) { self.clock = clock }

    /// Fast path over already-available fast inputs. `cacheHit` short-circuits. Measures real latency.
    public func admit(inputs: FusionInputsV1, cacheHit: Bool, cachedDecision: FusionResultV1?) -> Result {
        let t0 = clock.nowNanos
        if cacheHit, let cached = cachedDecision {
            return Result(state: cached.scoreState, admission: cached.admission,
                          latencyNanos: clock.nowNanos &- t0, route: "CACHE", deepScheduled: false)
        }
        let decision = fusion.decide(inputs)
        return Result(state: decision.scoreState, admission: decision.admission,
                      latencyNanos: clock.nowNanos &- t0, route: "FAST",
                      deepScheduled: decision.scoreState == .provisionalFast)   // deep continues after, non-blocking
    }
}

// §20/§21 Next-content ready queue — truthful candidate readiness; bounded; no invented future content.
public struct NextContentCandidate: Sendable, Equatable {
    public enum Readiness: String, Sendable { case discovered, identityReady, cacheReady, fastReady, admissionReady, unknown }
    public let id: ContentID
    public var readiness: Readiness
    public let revealProbability: Double
    public let timeToRevealMs: Int
    public let resourceCost: Double
    public let riskUncertainty: Double
    public init(id: ContentID, readiness: Readiness = .discovered, revealProbability: Double,
                timeToRevealMs: Int, resourceCost: Double, riskUncertainty: Double) {
        self.id = id; self.readiness = readiness; self.revealProbability = revealProbability
        self.timeToRevealMs = timeToRevealMs; self.resourceCost = resourceCost; self.riskUncertainty = riskUncertainty
    }
    /// Priority: reveal prob × risk ÷ (timeToReveal × cost). Higher = analyze first.
    public var priority: Double {
        (revealProbability * max(0.1, riskUncertainty)) / (Double(max(1, timeToRevealMs)) * max(0.1, resourceCost))
    }
}
public struct NextContentQueue: Sendable {
    public let maxLookAhead: Int
    public init(maxLookAhead: Int = 3) { self.maxLookAhead = maxLookAhead }
    /// Keep top-N by priority; drop stale/low-probability/duplicate (returns kept + droppedCount).
    public func select(_ candidates: [NextContentCandidate], pressure: Bool) -> (kept: [NextContentCandidate], dropped: Int) {
        var byID: [ContentID: NextContentCandidate] = [:]
        for c in candidates { if let e = byID[c.id] { if c.priority > e.priority { byID[c.id] = c } } else { byID[c.id] = c } }
        var ranked = byID.values.sorted { $0.priority > $1.priority }
        if pressure { ranked = ranked.filter { $0.revealProbability >= 0.2 } }   // drop low-prob under pressure
        let kept = Array(ranked.prefix(maxLookAhead))
        return (kept, candidates.count - kept.count)
    }
}
