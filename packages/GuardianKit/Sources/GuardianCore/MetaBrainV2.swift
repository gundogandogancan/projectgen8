import Foundation

// MARK: - P009B §3/§20/§21/§34 — GuardianMetaBrainV2: the exercised runtime; + sanitizer + handoff consumer.

// MARK: - §34 input sanitization — bad handoff: reject/quarantine, never crash, never positive state.

public enum SanitizationVerdictV1: String, Sendable { case accepted = "ACCEPTED", quarantined = "QUARANTINED" }
public struct SanitizationResultV1: Sendable {
    public let verdict: SanitizationVerdictV1
    public let reasons: [String]
    public let sanitized: Tier1IdentityHandoffV1?
}
public enum InputSanitizerV1 {
    public static let revision = "input-sanitizer-v1"
    static func bad(_ v: Double) -> Bool { v.isNaN || v.isInfinite }
    public static func sanitize(_ h: Tier1IdentityHandoffV1, currentObservation: ObservationID?) -> SanitizationResultV1 {
        var reasons: [String] = []
        for (name, v) in [("gapMs", h.gapSinceLastBoundaryMs), ("prevDwellMs", h.previousShotDwellMs),
                          ("elapsedItemMs", h.elapsedItemMs), ("theme", h.themeDistance), ("proj", h.projectionCorrelation),
                          ("hist", h.histogramDistance), ("chrome", h.chromeDistance), ("regional", h.regionalDistance)] {
            if bad(v) { reasons.append("non-finite:\(name)") }
        }
        if h.gapSinceLastBoundaryMs < 0 || h.previousShotDwellMs < 0 || h.elapsedItemMs < 0 { reasons.append("negative-timestamp") }
        for (name, v) in [("theme", h.themeDistance), ("hist", h.histogramDistance), ("chrome", h.chromeDistance), ("regional", h.regionalDistance)] {
            if !bad(v) && (v < 0 || v > 1) { reasons.append("out-of-range:\(name)") }
        }
        if !bad(h.projectionCorrelation) && (h.projectionCorrelation < -1 || h.projectionCorrelation > 1) { reasons.append("out-of-range:proj") }
        if h.modelPolicyVersions.isEmpty { reasons.append("missing-model-version") }
        if h.shotID.raw == 0 || h.provisionalItemID.raw == 0 { reasons.append("malformed-id") }
        if let cur = currentObservation, cur.raw != h.observationID.raw { reasons.append("stale-session") }
        if reasons.isEmpty { return SanitizationResultV1(verdict: .accepted, reasons: [], sanitized: h) }
        return SanitizationResultV1(verdict: .quarantined, reasons: reasons, sanitized: nil)   // never positive state
    }
}

/// §34 consumer: accepts only sanitized handoffs; quarantined records are counted, never processed.
public final class Tier1IdentityHandoffConsumerV1: @unchecked Sendable {
    public private(set) var accepted: [Tier1IdentityHandoffV1] = []
    public private(set) var quarantinedCount = 0
    public private(set) var quarantineReasons: [String] = []
    public let maxAccepted: Int
    private let lock = NSLock()
    public init(maxAccepted: Int = 256) { self.maxAccepted = maxAccepted }
    @discardableResult
    public func consume(_ h: Tier1IdentityHandoffV1, currentObservation: ObservationID?) -> SanitizationVerdictV1 {
        let r = InputSanitizerV1.sanitize(h, currentObservation: currentObservation)
        lock.lock(); defer { lock.unlock() }
        switch r.verdict {
        case .accepted:
            accepted.append(r.sanitized!)
            if accepted.count > maxAccepted { accepted.removeFirst(accepted.count - maxAccepted) }
        case .quarantined:
            quarantinedCount += 1
            quarantineReasons.append(contentsOf: r.reasons)
            if quarantineReasons.count > 512 { quarantineReasons.removeFirst(quarantineReasons.count - 512) }
        }
        return r.verdict
    }
}

// MARK: - §3 the Meta-Brain runtime.

public struct MetaBrainRouteV2: Sendable {
    public let requested: [ExpertDomainV2]
    public let permitted: [ExpertDomainV2]
    public let cacheHits: [ExpertDomainV2]
    public let executed: [ExpertDomainV2]
    public let deferredThermal: [ExpertDomainV2]
    public let unavailable: [ExpertDomainV2]
    public let evidence: [ExpertEvidenceV2]
    public let unknownReasons: [String]
}

public final class GuardianMetaBrainV2: @unchecked Sendable {
    public let registry = ExpertRegistryV2()
    public let capabilities = CapabilityResolverV2()
    public let governor = ResourceGovernorV2()
    public let cache = IntelligenceCacheV2()
    public let bus = EvidenceBusV2()
    public let ledger = ProvenanceLedgerV2()
    public let calibration = CalibrationRegistrySkeletonV1()
    public let handoffConsumer = Tier1IdentityHandoffConsumerV1()
    public let latency = OperationLatencyRegistryV1()                  // R1 §8 — real measured samples only
    let clock: @Sendable () -> Double                                  // monotonic ms; injectable for deadline tests
    private let lock = NSLock()
    private(set) public var currentGeneration: UInt64 = 1
    private(set) public var currentObservation: ObservationID?
    public init(clock: (@Sendable () -> Double)? = nil) { self.clock = clock ?? { MonotonicClockV1.nowMs() } }

    /// §21 identity change → new generation; stale firewall marks all earlier evidence stale; cache for the old
    /// item is left intact (cache is per confirmed item — reuse is legal), in-flight tokens are the caller's to cancel.
    @discardableResult
    public func identityChanged() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        currentGeneration += 1
        bus.markStale(before: currentGeneration)
        return currentGeneration
    }
    public func beginObservation(_ o: ObservationID) { lock.lock(); currentObservation = o; lock.unlock() }

    /// Map an executed result to its R1 F1 lease outcome — this decides whether the deep lease was consumed.
    static func leaseOutcome(for ev: ExpertEvidenceV2) -> DeepAnalysisLeaseStateV1 {
        if !ev.inputModalityAvailable { return .unavailableTransient }     // provider input absent NOW — may arrive later
        if ev.coverage == 0 || ev.labels.contains(where: { $0.hasPrefix("UNSUPPORTED") }) { return .executedAbstained }
        return .executedMeaningful
    }

    /// §3 route law (R1): sanitize → capability → cache(full binding) → thermal → deadline → lease →
    /// cancellation → execute (measured) → late/stale discard → lease outcome → provenance → UNKNOWN.
    public func route(input rawInput: ExpertInputV2, context: ExpertTaskContextV2,
                      safetyCritical: Set<ExpertDomainV2> = [.safetyEvidence, .temporal], nowMs: Double) -> MetaBrainRouteV2 {
        let routeStart = clock()
        var permitted: [ExpertDomainV2] = []
        var unavailable: [ExpertDomainV2] = []
        var cacheHits: [ExpertDomainV2] = []
        var deferredThermal: [ExpertDomainV2] = []
        var executed: [ExpertDomainV2] = []
        var evidence: [ExpertEvidenceV2] = []
        var unknown: [String] = []
        // R1 §7 — sanitize BEFORE any expert sees the bundle; invalid values never become confident evidence
        let (input, sanitizeFlags) = ExpertInputSanitizerV2.sanitize(rawInput)
        unknown.append(contentsOf: sanitizeFlags.map { "input-sanitized:\($0)" })
        let allowedByProfile = capabilities.permittedDomains(for: context.profile)
        // cheapest-sufficient: sort requested domains by expert resource cost (unknown experts go last)
        let ordered = context.requestedDomains.sorted {
            (registry.expert(for: $0)?.resourceCost ?? 99) < (registry.expert(for: $1)?.resourceCost ?? 99)
        }
        for domain in ordered {
            guard allowedByProfile.contains(domain) else {
                unavailable.append(domain); unknown.append("profile-forbids:\(domain.rawValue)"); continue
            }
            permitted.append(domain)
            guard let expert = registry.expert(for: domain), expert.availability != .unavailable else {
                unavailable.append(domain); unknown.append("expert-unavailable:\(domain.rawValue)")
                evidence.append(.unavailable(domain, reason: "not-registered", generation: context.generation)); continue
            }
            // §18 cache first (confirmed items only) — R1 F6 full binding; serving is cheap and allowed past deadline
            if let item = context.itemID, !context.itemProvisional {
                let c0 = clock()
                let (entry, missReason) = cache.lookup(item: item, domain: domain, modelVersion: expert.modelVersion,
                                                       identityRevision: context.identityRevision,
                                                       privacyClass: context.privacyClass, nowMs: nowMs)
                latency.record("cache-lookup", ms: clock() - c0)
                if let hit = entry {
                    cacheHits.append(domain); registry.health.note(domain, cacheHit: true)
                    if hit.generationAtInsert != currentGeneration {
                        // R1 F6: old-generation reuse for the SAME item revision stays legal but is never silent
                        unknown.append("cache-hit-old-generation:\(domain.rawValue)")
                    }
                    evidence.append(hit.evidence); continue
                }
                if let r = missReason { unknown.append("cache-miss-\(r):\(domain.rawValue)") }
            }
            // §20 thermal gates
            guard governor.allows(expert: expert, safetyCritical: safetyCritical.contains(domain)) else {
                deferredThermal.append(domain); unknown.append("thermal-deferred:\(domain.rawValue)"); continue
            }
            // R1 §9 — deadline: no NEW work may be scheduled past the budget (cache above stays servable)
            if clock() - routeStart >= context.deadlineMs {
                deferredThermal.append(domain); unknown.append("deadline-expired:\(domain.rawValue)"); continue
            }
            // R1 F1 — deep-analysis lease (cost ≥ 5); only meaningful executions consume it
            var leasedItem: ContentItemID? = nil
            if expert.resourceCost >= 5, let item = context.itemID {
                let (granted, denyReason) = governor.requestDeep(item: item, domain: domain)
                guard granted else { unknown.append(denyReason ?? "deep-denied:\(domain.rawValue)"); continue }
                leasedItem = item
            }
            // §21 cancellation before work
            if context.cancellation.isCancelled {
                registry.health.note(domain, cancelled: true); unknown.append("cancelled:\(domain.rawValue)")
                if let li = leasedItem { governor.completeDeep(item: li, domain: domain, outcome: .cancelled) }
                continue
            }
            let t0 = clock()
            var ev = expert.evaluate(input, context: context)
            let execMs = clock() - t0
            // §21 stale firewall: result from an older generation can never attach to the current identity
            if ev.generation != currentGeneration {
                registry.health.note(domain, stale: true)
                unknown.append("stale-discarded:\(domain.rawValue)")
                latency.record("stale-discard", ms: execMs)
                if let li = leasedItem { governor.completeDeep(item: li, domain: domain, outcome: .stale) }
                continue
            }
            // R1 §9 — a result landing after the deadline can never attach (late-result law)
            if clock() - routeStart >= context.deadlineMs {
                unknown.append("deadline-late-discarded:\(domain.rawValue)")
                latency.record("deadline-late-discard", ms: execMs)
                if let li = leasedItem { governor.completeDeep(item: li, domain: domain, outcome: .stale) }
                continue
            }
            ev.stale = false
            executed.append(domain)
            registry.health.note(domain, latencyMs: execMs)                 // R1 §8 — measured, not structural
            if let li = leasedItem { governor.completeDeep(item: li, domain: domain, outcome: Self.leaseOutcome(for: ev)) }
            bus.publish(ev)
            cache.insert(ev, identityRevision: context.identityRevision, generation: currentGeneration, nowMs: nowMs)
            ledger.record(subject: context.itemID.map { "item:\($0.raw)" } ?? "shot:\(context.shotID?.raw ?? 0)",
                          producer: "\(domain.rawValue)-expert", modelVersion: ev.modelVersion,
                          profile: context.profile.rawValue, atMs: nowMs)
            evidence.append(ev)
        }
        if evidence.allSatisfy({ !$0.inputModalityAvailable }) && !evidence.isEmpty {
            unknown.append("all-modalities-unavailable")                        // §22 prefer UNKNOWN
        }
        latency.record("route", ms: clock() - routeStart)
        return MetaBrainRouteV2(requested: context.requestedDomains, permitted: permitted, cacheHits: cacheHits,
                                executed: executed, deferredThermal: deferredThermal, unavailable: unavailable,
                                evidence: evidence, unknownReasons: unknown)
    }
}
