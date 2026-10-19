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
    private let lock = NSLock()
    private(set) public var currentGeneration: UInt64 = 1
    private(set) public var currentObservation: ObservationID?
    public init() {}

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

    /// §3 route: capability → cache → cheapest-sufficient order → thermal gates → execute → provenance → UNKNOWN.
    public func route(input: ExpertInputV2, context: ExpertTaskContextV2, safetyCritical: Set<ExpertDomainV2> = [.safetyEvidence, .temporal], nowMs: Double) -> MetaBrainRouteV2 {
        var permitted: [ExpertDomainV2] = []
        var unavailable: [ExpertDomainV2] = []
        var cacheHits: [ExpertDomainV2] = []
        var deferredThermal: [ExpertDomainV2] = []
        var executed: [ExpertDomainV2] = []
        var evidence: [ExpertEvidenceV2] = []
        var unknown: [String] = []
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
            // §18 cache first (confirmed items only)
            if let item = context.itemID, !context.itemProvisional,
               let hit = cache.lookup(item: item, domain: domain, modelVersion: expert.modelVersion) {
                cacheHits.append(domain); registry.health.note(domain, cacheHit: true)
                evidence.append(hit); continue
            }
            // §20 thermal gates
            guard governor.allows(expert: expert, safetyCritical: safetyCritical.contains(domain)) else {
                deferredThermal.append(domain); unknown.append("thermal-deferred:\(domain.rawValue)"); continue
            }
            // dedupe deep experts per item
            if expert.resourceCost >= 5, let item = context.itemID, !governor.requestDeep(item: item, domain: domain) {
                unknown.append("deep-dedupe:\(domain.rawValue)"); continue
            }
            // §21 cancellation before work
            if context.cancellation.isCancelled {
                registry.health.note(domain, cancelled: true); unknown.append("cancelled:\(domain.rawValue)"); continue
            }
            let t0 = nowMs
            var ev = expert.evaluate(input, context: context)
            // §21 stale firewall: result from an older generation can never attach to the current identity
            if ev.generation != currentGeneration {
                var stale = ev; stale.stale = true
                registry.health.note(domain, stale: true)
                unknown.append("stale-discarded:\(domain.rawValue)")
                continue
            }
            ev.stale = false
            executed.append(domain)
            registry.health.note(domain, latencyMs: max(0, nowMs - t0))
            bus.publish(ev)
            cache.insert(ev)
            ledger.record(subject: context.itemID.map { "item:\($0.raw)" } ?? "shot:\(context.shotID?.raw ?? 0)",
                          producer: "\(domain.rawValue)-expert", modelVersion: ev.modelVersion,
                          profile: context.profile.rawValue, atMs: nowMs)
            evidence.append(ev)
        }
        if evidence.allSatisfy({ !$0.inputModalityAvailable }) && !evidence.isEmpty {
            unknown.append("all-modalities-unavailable")                        // §22 prefer UNKNOWN
        }
        return MetaBrainRouteV2(requested: context.requestedDomains, permitted: permitted, cacheHits: cacheHits,
                                executed: executed, deferredThermal: deferredThermal, unavailable: unavailable,
                                evidence: evidence, unknownReasons: unknown)
    }
}
