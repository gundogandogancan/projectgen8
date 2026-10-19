import Foundation

// MARK: - Pre-exposure pipeline (the canonical contract, real code)
// CandidateDiscovered → ContentIdentityResolved → LocalCacheLookup → FastPreflight →
// PersonalPolicyFusion → AdmissionDecisionReady → GuardianSurfaceUpdate (PROMPT 001 §4, §10).
// Real timing + real cache + deterministic fusion. No fabricated scores.

public struct PipelineResult: Sendable, Equatable {
    public let decision: AdmissionDecision
    public let trace: DecisionTrace
    public let surface: GuardianSurfaceState
    public init(decision: AdmissionDecision, trace: DecisionTrace, surface: GuardianSurfaceState) {
        self.decision = decision
        self.trace = trace
        self.surface = surface
    }
}

public struct PreExposurePipeline: Sendable {
    let cache: LocalAdmissionCache
    let clock: MonotonicClock
    let preflight: HeuristicV0Preflight
    let scoreEngine: ScoreEngine
    let controller: AdmissionController
    let identityResolver: @Sendable (ContentID) -> ContentIdentityResult
    let diagnostics: Diagnostics
    let log: GuardianLog
    let events: GuardianEventSink

    public init(cache: LocalAdmissionCache,
                clock: MonotonicClock,
                identityResolver: @escaping @Sendable (ContentID) -> ContentIdentityResult,
                diagnostics: Diagnostics,
                log: GuardianLog,
                events: GuardianEventSink,
                preflight: HeuristicV0Preflight = .init(),
                scoreEngine: ScoreEngine = .init(),
                controller: AdmissionController = .init()) {
        self.cache = cache
        self.clock = clock
        self.identityResolver = identityResolver
        self.diagnostics = diagnostics
        self.log = log
        self.events = events
        self.preflight = preflight
        self.scoreEngine = scoreEngine
        self.controller = controller
    }

    public func decide(candidate: ContentCandidate,
                       profile: PersonalAlgorithmProfile,
                       safety: SafetyPolicy = .init()) async -> PipelineResult {
        let t0 = clock.nowNanos
        let id = candidate.id
        events.emit(.candidateDiscovered(id, candidate.source))

        let identity = identityResolver(id)
        events.emit(.contentIdentityResolved(id, identity.state))

        let heuristicVersion = HeuristicV0Preflight.version
        let policyVersion = profile.version

        var cacheHit = false
        let decision: AdmissionDecision

        if let entry = await cache.lookup(id, heuristicVersion: heuristicVersion, policyVersion: policyVersion) {
            cacheHit = true
            diagnostics.recordCacheHit()
            decision = entry.decision
        } else {
            diagnostics.recordCacheMiss()
            diagnostics.recordPreflight()
            let pf = preflight.run(candidate: candidate)
            events.emit(.contentDNAResolved(id))
            let score = scoreEngine.score(pf.signals)
            events.emit(.fastPreflightCompleted(id, score.state))
            let inputs = AdmissionInputs(contentID: id, identity: identity, signals: pf.signals,
                                         score: score, profile: profile, safety: safety)
            decision = controller.decide(inputs)
            await cache.store(CacheEntry(decision: decision, heuristicVersion: heuristicVersion,
                                         policyVersion: policyVersion, storedAtNanos: clock.nowNanos))
        }

        let t1 = clock.nowNanos
        let latency = t1 &- t0
        diagnostics.recordDecisionLatency(latency)
        events.emit(.admissionDecisionReady(id, decision.state))

        let coverage = coverageFor(decision)
        events.emit(.guardianCoverageChanged(coverage))
        let surface = GuardianSurfaceState.from(decision, coverage: coverage)

        let trace = DecisionTrace(traceID: "\(id.raw)-\(t0)", contentID: id, candidateSource: candidate.source,
                                  cacheHit: cacheHit, heuristicVersion: heuristicVersion, policyVersion: policyVersion,
                                  admissionState: decision.state, scoreState: decision.score.state,
                                  reason: decision.reason, coverage: coverage,
                                  decisionLatencyNanos: latency, timestampNanos: t0)
        log.record(trace)
        return PipelineResult(decision: decision, trace: trace, surface: surface)
    }

    private func coverageFor(_ d: AdmissionDecision) -> GuardianCoverageState {
        switch d.state {
        case .unknown: return .unknown
        default:
            switch d.score.state {
            case .verifiedFast: return .verified
            case .provisionalFast: return .analyzing
            case .insufficientEvidence, .conflicting: return .unknown
            }
        }
    }
}
