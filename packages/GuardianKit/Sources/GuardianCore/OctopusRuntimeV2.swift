import Foundation

// MARK: - P009B §3/§4 — OCTOPUS RUNTIME CORE V2: the skeleton becomes an exercised runtime.
// The Meta-Brain inspects capability + cache, routes the cheapest sufficient experts, cancels stale work on
// identity change, escalates ambiguity/high-risk, collects provenance, and prefers UNKNOWN over forced
// interpretation. NO numeric score, NO glyph — evidence only.

// MARK: - §2 capability profiles (runtime).

public enum RuntimeCapabilityProfileV2: String, Sendable, Codable {
    case extensionFastTier0 = "EXTENSION_FAST_TIER0"
    case extensionTier1Lite = "EXTENSION_TIER1_LITE"     // MUST stay UNAVAILABLE until physically proven
    case appFullTier1 = "APP_FULL_TIER1"
    case futureSharedTier1 = "FUTURE_SHARED_TIER1"       // BLOCKED
}

// MARK: - §4 expert contract.

public enum ExpertDomainV2: String, Sendable, Codable, CaseIterable {
    case vision = "VISION", languageOCR = "LANGUAGE_OCR", speech = "SPEECH", audioEvent = "AUDIO_EVENT"
    case music = "MUSIC", symbol = "SYMBOL", temporal = "TEMPORAL"
    case safetyEvidence = "SAFETY_EVIDENCE", benefitEvidence = "BENEFIT_EVIDENCE", attentionPressure = "ATTENTION_PRESSURE"
}

/// R1 F5 — 5-tier capability truth. Classification is from ACTUAL wiring + evidence, never aspiration:
/// DEVICE_PROVEN requires a physically exercised on-device run; NOT_DEVICE_PROVEN requires a production
/// (non-DEBUG) in-app consumer; LAB_ONLY = real code exercised in-process (tests/DEBUG HUD) only.
public enum ExpertAvailabilityV2: String, Sendable, Codable {
    case realRuntimeDeviceProven = "REAL_RUNTIME_DEVICE_PROVEN"
    case realRuntimeNotDeviceProven = "REAL_RUNTIME_NOT_DEVICE_PROVEN"
    case realInProcessLabOnly = "REAL_IN_PROCESS_LAB_ONLY"
    case contractOnly = "CONTRACT_ONLY"
    case unavailable = "UNAVAILABLE"
}

public enum EvidenceCalibrationStatusV2: String, Sendable, Codable {
    case implementedCalibrated = "IMPLEMENTED_CALIBRATED"
    case implementedUncalibrated = "IMPLEMENTED_UNCALIBRATED"
    case heuristicSupportOnly = "HEURISTIC_SUPPORT_ONLY"
    case unavailable = "UNAVAILABLE"
}

/// §4 input context for every expert call.
public struct ExpertTaskContextV2: Sendable {
    public let observationID: ObservationID
    public let shotID: ShotID?
    public let itemID: ContentItemID?
    public let itemProvisional: Bool
    public let identityRevision: UInt64                   // R1 F6 — per-item identity revision (split/merge bumps)
    public let profile: RuntimeCapabilityProfileV2
    public let privacyClass: EvidencePrivacyClassV1
    public let requestedDomains: [ExpertDomainV2]
    public let deadlineMs: Double                         // R1 §9 — remaining-budget from route start (monotonic)
    public let cancellation: CancellationTokenV2
    public let generation: UInt64                         // identity generation — stale firewall key
    /// P009C: segment/shot-scoped analysis must NOT be served from (or into) the per-ITEM cache — a shot
    /// moment is not the whole item's understanding. Default true preserves all prior behavior.
    public let cacheEligible: Bool
    public init(observationID: ObservationID, shotID: ShotID?, itemID: ContentItemID?, itemProvisional: Bool,
                identityRevision: UInt64 = 0,
                profile: RuntimeCapabilityProfileV2, privacyClass: EvidencePrivacyClassV1 = .derivedNonReconstructive,
                requestedDomains: [ExpertDomainV2], deadlineMs: Double = 1000,
                cancellation: CancellationTokenV2 = CancellationTokenV2(), generation: UInt64,
                cacheEligible: Bool = true) {
        self.observationID = observationID; self.shotID = shotID; self.itemID = itemID
        self.itemProvisional = itemProvisional; self.identityRevision = identityRevision
        self.profile = profile; self.privacyClass = privacyClass
        self.requestedDomains = requestedDomains; self.deadlineMs = deadlineMs
        self.cancellation = cancellation; self.generation = generation
        self.cacheEligible = cacheEligible
    }
}

/// R1 §8 — monotonic clock for real latency/deadline measurement (never wall clock, never structural 0).
public enum MonotonicClockV1 {
    public static func nowMs() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000.0 }
}

/// R1 §8 — named-operation latency registry (route / cache-lookup / graph-fusion / state-build / discards).
public final class OperationLatencyRegistryV1: @unchecked Sendable {
    private var samples: [String: [Double]] = [:]
    private let lock = NSLock(); public let maxSamplesPerOp: Int
    public init(maxSamplesPerOp: Int = 512) { self.maxSamplesPerOp = maxSamplesPerOp }
    public func record(_ op: String, ms: Double) {
        guard ms.isFinite, ms >= 0 else { return }
        lock.lock(); var s = samples[op] ?? []; s.append(ms)
        if s.count > maxSamplesPerOp { s.removeFirst(s.count - maxSamplesPerOp) }
        samples[op] = s; lock.unlock()
    }
    /// nil = NOT_MEASURED (no samples) — callers must render "NOT_MEASURED", never "0 ms".
    public func percentiles(_ op: String) -> (p50: Double, p95: Double, count: Int)? {
        lock.lock(); defer { lock.unlock() }
        guard let s = samples[op], !s.isEmpty else { return nil }
        let sorted = s.sorted()
        return (sorted[sorted.count / 2], sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))], sorted.count)
    }
    public var operations: [String] { lock.lock(); defer { lock.unlock() }; return Array(samples.keys).sorted() }
}

public final class CancellationTokenV2: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    public init() {}
    public var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    public func cancel() { lock.lock(); cancelled = true; lock.unlock() }
}

/// §4 output: evidence, never a bare label.
public struct ExpertEvidenceV2: Sendable {
    public let domain: ExpertDomainV2
    public let labels: [String]                           // canonical semantic labels (language-independent)
    public let features: [String: Double]                 // continuous features where justified
    public let confidence: Double                         // 0..1 (uncalibrated unless stated)
    public let coverage: Double                           // fraction of requested scope actually observed
    public let uncertainty: Double
    public let oodIndicator: Bool
    public let temporalScopeMs: ClosedRange<Double>?
    public let shotID: ShotID?
    public let itemID: ContentItemID?
    public let itemProvisional: Bool
    public let provenance: String                         // expert + provider chain
    public let modelVersion: String
    public let inputModalityAvailable: Bool               // false = honest UNAVAILABLE
    public let privacyClass: EvidencePrivacyClassV1
    public let latencyMs: Double
    public let resourceCost: Double                       // coarse normalized cost unit
    public var stale: Bool = false
    public let calibrationStatus: EvidenceCalibrationStatusV2
    public let generation: UInt64
    public init(domain: ExpertDomainV2, labels: [String], features: [String: Double] = [:], confidence: Double,
                coverage: Double, uncertainty: Double, oodIndicator: Bool = false,
                temporalScopeMs: ClosedRange<Double>? = nil, shotID: ShotID? = nil, itemID: ContentItemID? = nil,
                itemProvisional: Bool = true, provenance: String, modelVersion: String,
                inputModalityAvailable: Bool = true, privacyClass: EvidencePrivacyClassV1 = .derivedNonReconstructive,
                latencyMs: Double = 0, resourceCost: Double = 1, calibrationStatus: EvidenceCalibrationStatusV2,
                generation: UInt64 = 0) {
        self.domain = domain; self.labels = labels; self.features = features; self.confidence = confidence
        self.coverage = coverage; self.uncertainty = uncertainty; self.oodIndicator = oodIndicator
        self.temporalScopeMs = temporalScopeMs; self.shotID = shotID; self.itemID = itemID
        self.itemProvisional = itemProvisional; self.provenance = provenance; self.modelVersion = modelVersion
        self.inputModalityAvailable = inputModalityAvailable; self.privacyClass = privacyClass
        self.latencyMs = latencyMs; self.resourceCost = resourceCost; self.calibrationStatus = calibrationStatus
        self.generation = generation
    }
    /// Honest UNAVAILABLE evidence (never fabricated content).
    public static func unavailable(_ domain: ExpertDomainV2, reason: String, generation: UInt64) -> ExpertEvidenceV2 {
        ExpertEvidenceV2(domain: domain, labels: ["UNAVAILABLE:\(reason)"], confidence: 0, coverage: 0, uncertainty: 1,
                         oodIndicator: false, provenance: "unavailable", modelVersion: "n/a",
                         inputModalityAvailable: false, calibrationStatus: .unavailable, generation: generation)
    }
}

/// §4 the one semantic interface all arms implement.
public protocol MultimodalExpertV2: Sendable {
    var domain: ExpertDomainV2 { get }
    var availability: ExpertAvailabilityV2 { get }
    var modelVersion: String { get }
    var resourceCost: Double { get }                      // coarse: 1 cheap … 10 heavy
    func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2
}

/// Derived-only input bundle (what an expert may see — never raw private media in GuardianCore).
public struct ExpertInputV2: Sendable {
    public var ocrText: String?                           // ephemeral in-process text (never persisted by experts)
    public var detectedLanguage: String?
    public var visualLabels: [String]?                    // provider-supplied scene/object labels (Apple Vision etc.)
    public var visualConfidence: Double?
    public var soundEvents: [String]?                     // provider-supplied validated sound classes
    public var speechTranscript: String?                  // ephemeral; nil = unavailable
    public var speechAvailable: Bool
    public var musicPresence: Bool?
    public var musicTempoEnergy: Double?
    public var shotDescriptor: ShotDescriptorV1?
    public var editDensityCutsPerMinute: Double?
    public var elapsedItemMs: Double?
    public init(ocrText: String? = nil, detectedLanguage: String? = nil, visualLabels: [String]? = nil,
                visualConfidence: Double? = nil, soundEvents: [String]? = nil, speechTranscript: String? = nil,
                speechAvailable: Bool = false, musicPresence: Bool? = nil, musicTempoEnergy: Double? = nil,
                shotDescriptor: ShotDescriptorV1? = nil, editDensityCutsPerMinute: Double? = nil, elapsedItemMs: Double? = nil) {
        self.ocrText = ocrText; self.detectedLanguage = detectedLanguage; self.visualLabels = visualLabels
        self.visualConfidence = visualConfidence; self.soundEvents = soundEvents; self.speechTranscript = speechTranscript
        self.speechAvailable = speechAvailable; self.musicPresence = musicPresence; self.musicTempoEnergy = musicTempoEnergy
        self.shotDescriptor = shotDescriptor; self.editDensityCutsPerMinute = editDensityCutsPerMinute; self.elapsedItemMs = elapsedItemMs
    }
}

// MARK: - R1 §7 — expert-input sanitizer V2. Runs BEFORE any expert sees the bundle. Normalizes only
// where semantically safe (non-finite confidence → 0 = maximal uncertainty); otherwise the value is
// DROPPED with a flag so the expert abstains honestly. Invalid values never become confident evidence.

public enum ExpertInputSanitizerV2 {
    public static let revision = "expert-input-sanitizer-v2"
    public static let maxLabels = 64, maxTextChars = 10_000
    /// Returns the sanitized bundle + flags (surfaced as `input-sanitized:` unknown reasons).
    public static func sanitize(_ input: ExpertInputV2) -> (input: ExpertInputV2, flags: [String]) {
        var s = input; var flags: [String] = []
        if let c = s.visualConfidence, !c.isFinite {
            s.visualConfidence = 0; flags.append("non-finite-visual-confidence→0")   // 0 = maximal uncertainty, OOD fires
        } else if let c = s.visualConfidence, c < 0 || c > 1 {
            s.visualConfidence = min(1, max(0, c)); flags.append("visual-confidence-clamped")
        }
        if let e = s.musicTempoEnergy, !e.isFinite { s.musicTempoEnergy = nil; flags.append("non-finite-tempo-dropped") }
        if s.musicPresence != true && s.musicTempoEnergy != nil {
            s.musicTempoEnergy = nil; flags.append("tempo-without-music-presence-dropped")   // impossible modality flag
        }
        if let d = s.editDensityCutsPerMinute, !d.isFinite || d < 0 {
            s.editDensityCutsPerMinute = nil; flags.append("invalid-edit-density-dropped")   // abstain over fabricate
        }
        if let t = s.elapsedItemMs, !t.isFinite || t < 0 { s.elapsedItemMs = nil; flags.append("invalid-elapsed-dropped") }
        if let lang = s.detectedLanguage {
            let ok = (2...8).contains(lang.count) && lang.allSatisfy { $0.isLetter || $0 == "-" }
            if !ok { s.detectedLanguage = nil; flags.append("malformed-locale-dropped") }    // → und → UNSUPPORTED abstention
        }
        if let v = s.visualLabels, v.count > maxLabels { s.visualLabels = Array(v.prefix(maxLabels)); flags.append("visual-labels-truncated") }
        if let a = s.soundEvents, a.count > maxLabels { s.soundEvents = Array(a.prefix(maxLabels)); flags.append("sound-events-truncated") }
        if let t = s.ocrText, t.count > maxTextChars { s.ocrText = String(t.prefix(maxTextChars)); flags.append("ocr-text-truncated") }
        if let t = s.speechTranscript, t.count > maxTextChars { s.speechTranscript = String(t.prefix(maxTextChars)); flags.append("transcript-truncated") }
        return (s, flags)
    }
}

// MARK: - §3 registry V2 + health.

public struct ExpertHealthV1: Sendable {
    public var calls = 0, cacheHits = 0, cancellations = 0, staleDiscards = 0, failures = 0
    public var latenciesMs: [Double] = []                 // bounded
    public var p50: Double { latenciesMs.isEmpty ? 0 : latenciesMs.sorted()[latenciesMs.count/2] }
    public var p95: Double { latenciesMs.isEmpty ? 0 : latenciesMs.sorted()[min(latenciesMs.count-1, Int(Double(latenciesMs.count)*0.95))] }
}
public final class ExpertHealthRegistryV1: @unchecked Sendable {
    private var health: [ExpertDomainV2: ExpertHealthV1] = [:]
    private let lock = NSLock()
    public init() {}
    public func note(_ d: ExpertDomainV2, latencyMs: Double? = nil, cacheHit: Bool = false, cancelled: Bool = false, stale: Bool = false, failed: Bool = false) {
        lock.lock(); defer { lock.unlock() }
        var h = health[d] ?? ExpertHealthV1()
        h.calls += 1
        if cacheHit { h.cacheHits += 1 }; if cancelled { h.cancellations += 1 }
        if stale { h.staleDiscards += 1 }; if failed { h.failures += 1 }
        if let l = latencyMs { h.latenciesMs.append(l); if h.latenciesMs.count > 512 { h.latenciesMs.removeFirst() } }
        health[d] = h
    }
    public func snapshot() -> [ExpertDomainV2: ExpertHealthV1] { lock.lock(); defer { lock.unlock() }; return health }
}

public final class ExpertRegistryV2: @unchecked Sendable {
    private var experts: [ExpertDomainV2: any MultimodalExpertV2] = [:]
    private let lock = NSLock()
    public let health = ExpertHealthRegistryV1()
    public init() {}
    public func register(_ e: any MultimodalExpertV2) { lock.lock(); experts[e.domain] = e; lock.unlock() }
    public func expert(for d: ExpertDomainV2) -> (any MultimodalExpertV2)? { lock.lock(); defer { lock.unlock() }; return experts[d] }
    public var registeredDomains: [ExpertDomainV2] { lock.lock(); defer { lock.unlock() }; return Array(experts.keys) }
    public func availability(_ d: ExpertDomainV2) -> ExpertAvailabilityV2 {
        lock.lock(); defer { lock.unlock() }; return experts[d]?.availability ?? .unavailable
    }
}

// MARK: - §3 capability resolver V2 (capability truth per profile).

public final class CapabilityResolverV2: @unchecked Sendable {
    public init() {}
    /// Which domains a profile may run at all. EXTENSION_TIER1_LITE stays empty until physically proven (§2B).
    public func permittedDomains(for profile: RuntimeCapabilityProfileV2) -> Set<ExpertDomainV2> {
        switch profile {
        case .extensionFastTier0: return [.temporal]                       // identity/temporal only — no semantics
        case .extensionTier1Lite: return []                                // UNAVAILABLE until device-proven
        case .appFullTier1: return Set(ExpertDomainV2.allCases)
        case .futureSharedTier1: return []                                 // BLOCKED
        }
    }
}

// MARK: - §3 resource governor V2 (thermal + deep-analysis LEASE machine + stats).

/// R1 F1 — explicit deep-analysis lease/outcome states. A lease is only CONSUMED by a meaningful
/// execution; transient unavailability / cancellation / staleness release it for bounded retry.
public enum DeepAnalysisLeaseStateV1: String, Sendable {
    case notAttempted = "NOT_ATTEMPTED"
    case leased = "LEASED"
    case executedMeaningful = "EXECUTED_MEANINGFUL"
    case executedAbstained = "EXECUTED_ABSTAINED"
    case unavailableTransient = "UNAVAILABLE_TRANSIENT"
    case unavailablePermanent = "UNAVAILABLE_PERMANENT"
    case cancelled = "CANCELLED"
    case stale = "STALE"
    case failed = "FAILED"
}

public final class ResourceGovernorV2: @unchecked Sendable {
    public private(set) var thermal: ThermalBucketV1 = .nominal
    private var leaseState: [String: DeepAnalysisLeaseStateV1] = [:]
    private var leaseAttempts: [String: Int] = [:]
    private var leaseOrder: [String] = []                              // bounded LRU of keys
    public let maxLeaseKeys: Int
    public let maxRetryAttempts: Int                                   // bound for non-meaningful retries — no storms
    public private(set) var deniedDuplicates = 0, thermalDeferrals = 0, retryExhaustions = 0
    private let lock = NSLock()
    public init(maxLeaseKeys: Int = 4096, maxRetryAttempts: Int = 3) {
        self.maxLeaseKeys = maxLeaseKeys; self.maxRetryAttempts = maxRetryAttempts
    }
    public func setThermal(_ t: ThermalBucketV1) { lock.lock(); thermal = t; lock.unlock() }
    /// §20 thermal routing law: FAIR defers optional deep experts; SERIOUS/CRITICAL → minimum safe path.
    public func allows(expert: any MultimodalExpertV2, safetyCritical: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        switch thermal {
        case .nominal: return true
        case .fair:
            if expert.resourceCost >= 5 && !safetyCritical { thermalDeferrals += 1; return false }
            return true
        case .serious, .critical:
            if expert.resourceCost >= 3 || !safetyCritical { thermalDeferrals += 1; return safetyCritical && expert.resourceCost < 3 }
            return true
        }
    }
    private func key(_ item: ContentItemID, _ domain: ExpertDomainV2, _ shotRaw: UInt64?) -> String {
        // P009C: segment-scoped analysis leases per (item, SHOT, domain) — a multi-shot item legitimately
        // runs deep experts once per shot-moment; item-level dedupe (shotRaw nil) is unchanged.
        shotRaw.map { "\(item.raw):\($0):\(domain.rawValue)" } ?? "\(item.raw):\(domain.rawValue)"
    }
    /// R1 F1 lease grant law:
    /// - EXECUTED_MEANINGFUL → deny (dedupe — the understanding exists; reuse it)
    /// - UNAVAILABLE_PERMANENT → deny for the current capability/session version
    /// - transient/abstained/failed → retry allowed while attempts < maxRetryAttempts (bounded, no storms)
    /// - cancelled/stale → retry allowed under the correct generation (attempt counter still bounds storms)
    public func requestDeep(item: ContentItemID, domain: ExpertDomainV2, shotRaw: UInt64? = nil) -> (granted: Bool, denyReason: String?) {
        lock.lock(); defer { lock.unlock() }
        let k = key(item, domain, shotRaw)
        let state = leaseState[k] ?? .notAttempted
        switch state {
        case .executedMeaningful:
            deniedDuplicates += 1; return (false, "deep-dedupe:\(domain.rawValue)")
        case .unavailablePermanent:
            deniedDuplicates += 1; return (false, "deep-permanent-unavailable:\(domain.rawValue)")
        case .leased:
            deniedDuplicates += 1; return (false, "deep-dedupe:\(domain.rawValue)")   // in-flight — no duplicate
        case .notAttempted, .unavailableTransient, .executedAbstained, .cancelled, .stale, .failed:
            let attempts = leaseAttempts[k] ?? 0
            if state != .notAttempted && attempts >= maxRetryAttempts {
                retryExhaustions += 1; return (false, "deep-retry-exhausted:\(domain.rawValue)")
            }
            leaseAttempts[k] = attempts + 1
            setState(k, .leased)
            return (true, nil)
        }
    }
    /// Report the outcome of a leased execution — this is what decides whether the lease was consumed.
    public func completeDeep(item: ContentItemID, domain: ExpertDomainV2, outcome: DeepAnalysisLeaseStateV1, shotRaw: UInt64? = nil) {
        lock.lock(); setState(key(item, domain, shotRaw), outcome); lock.unlock()
    }
    public func leaseState(item: ContentItemID, domain: ExpertDomainV2, shotRaw: UInt64? = nil) -> DeepAnalysisLeaseStateV1 {
        lock.lock(); defer { lock.unlock() }; return leaseState[key(item, domain, shotRaw)] ?? .notAttempted
    }
    private func setState(_ k: String, _ s: DeepAnalysisLeaseStateV1) {
        if leaseState[k] == nil { leaseOrder.append(k) }
        leaseState[k] = s
        while leaseOrder.count > maxLeaseKeys {
            let evict = leaseOrder.removeFirst(); leaseState.removeValue(forKey: evict); leaseAttempts.removeValue(forKey: evict)
        }
    }
}

// MARK: - §18 intelligence cache V2 — R1 F6: every record binds identity revision + schema + TTL +
// privacy scope + model version; mismatch → MISS/REANALYZE, never positive evidence. Collision handling
// is AUTOMATIC once the identity layer reports it (route input text is NOT identity evidence — the
// grouping/identity layer owns collision detection and reports here).

public enum IdentityCollisionStrengthV1: String, Sendable { case strong = "STRONG", ambiguous = "AMBIGUOUS" }

public final class IntelligenceCacheV2: @unchecked Sendable {
    public static let evidenceSchemaVersion = "expert-evidence-schema-v2"
    public struct Key: Hashable { public let itemRaw: UInt64; public let domain: ExpertDomainV2; public let modelVersion: String }
    public struct Entry: Sendable {
        public let evidence: ExpertEvidenceV2
        public let identityRevision: UInt64
        public let schemaVersion: String
        public let privacyClass: EvidencePrivacyClassV1
        public let generationAtInsert: UInt64
        public let insertedAtMs: Double
        public let ttlMs: Double
    }
    /// Low-information evidence (abstentions, no-validated, unsupported) expires FAST so later real
    /// input gets re-analyzed; meaningful evidence keeps the long TTL.
    public let normalTTLMs: Double, lowInfoTTLMs: Double
    private var store: [Key: Entry] = [:]
    private var order: [Key] = []
    private var pendingReanalysis = Set<UInt64>()                      // ambiguous collision → next lookup misses
    public let maxEntries: Int
    public private(set) var hits = 0, misses = 0, staleInvalidations = 0, collisionInvalidations = 0, reanalysisMisses = 0, ttlExpiries = 0
    private let lock = NSLock()
    public init(maxEntries: Int = 256, normalTTLMs: Double = 3_600_000, lowInfoTTLMs: Double = 5_000) {
        self.maxEntries = maxEntries; self.normalTTLMs = normalTTLMs; self.lowInfoTTLMs = lowInfoTTLMs
    }
    static func isLowInformation(_ e: ExpertEvidenceV2) -> Bool {
        e.confidence < 0.3 || e.coverage == 0
            || e.labels.contains { $0.hasPrefix("UNSUPPORTED") || $0.contains("no-validated-events") || $0.hasPrefix("UNAVAILABLE") }
    }
    /// Full R1 F6 lookup — every binding dimension checked; any mismatch is a MISS (and revision/schema
    /// mismatches invalidate the record so it can never be served again).
    public func lookup(item: ContentItemID, domain: ExpertDomainV2, modelVersion: String,
                       identityRevision: UInt64, privacyClass: EvidencePrivacyClassV1,
                       nowMs: Double?) -> (entry: Entry?, missReason: String?) {
        lock.lock(); defer { lock.unlock() }
        if pendingReanalysis.contains(item.raw) {
            pendingReanalysis.remove(item.raw)
            removeLocked { $0.itemRaw == item.raw }
            misses += 1; reanalysisMisses += 1
            return (nil, "collision-reanalysis")
        }
        let k = Key(itemRaw: item.raw, domain: domain, modelVersion: modelVersion)
        guard let e = store[k] else { misses += 1; return (nil, nil) }
        if e.identityRevision != identityRevision {
            removeLocked { $0 == k }; collisionInvalidations += 1; misses += 1
            return (nil, "identity-revision-mismatch")                 // split/merge revision invalidates
        }
        if e.schemaVersion != Self.evidenceSchemaVersion {
            removeLocked { $0 == k }; staleInvalidations += 1; misses += 1
            return (nil, "schema-version-mismatch")
        }
        if e.privacyClass != privacyClass { misses += 1; return (nil, "privacy-scope-mismatch") }
        if let now = nowMs, now - e.insertedAtMs > e.ttlMs {
            removeLocked { $0 == k }; ttlExpiries += 1; misses += 1
            return (nil, "ttl-expired")
        }
        hits += 1; return (e, nil)
    }
    /// Legacy 3-arg lookup (kept for existing tests/probes): revision 0, current schema, TTL not evaluated.
    public func lookup(item: ContentItemID, domain: ExpertDomainV2, modelVersion: String) -> ExpertEvidenceV2? {
        lookup(item: item, domain: domain, modelVersion: modelVersion, identityRevision: 0,
               privacyClass: .derivedNonReconstructive, nowMs: nil).entry?.evidence
    }
    public func insert(_ e: ExpertEvidenceV2, identityRevision: UInt64 = 0, generation: UInt64 = 0, nowMs: Double = 0) {
        guard let item = e.itemID, !e.itemProvisional else { return }     // provisional identity never cached durably
        lock.lock(); defer { lock.unlock() }
        let k = Key(itemRaw: item.raw, domain: e.domain, modelVersion: e.modelVersion)
        if store[k] == nil { order.append(k) }
        store[k] = Entry(evidence: e, identityRevision: identityRevision, schemaVersion: Self.evidenceSchemaVersion,
                         privacyClass: e.privacyClass, generationAtInsert: generation, insertedAtMs: nowMs,
                         ttlMs: Self.isLowInformation(e) ? lowInfoTTLMs : normalTTLMs)
        while order.count > maxEntries { store.removeValue(forKey: order.removeFirst()) }
    }
    /// R1 F6 automatic collision handling — called by the IDENTITY layer (grouping/handoff), never inferred
    /// from semantic inputs. Strong mismatch → invalidate now; ambiguous → force re-analysis on next read.
    public func reportIdentityCollision(item: ContentItemID, strength: IdentityCollisionStrengthV1) {
        lock.lock(); defer { lock.unlock() }
        switch strength {
        case .strong:
            removeLocked { $0.itemRaw == item.raw }; collisionInvalidations += 1
        case .ambiguous:
            pendingReanalysis.insert(item.raw)
        }
    }
    /// stale model version → invalidate (§18).
    public func invalidate(modelVersionNot current: String, domain: ExpertDomainV2) {
        lock.lock(); defer { lock.unlock() }
        for (k, _) in store where k.domain == domain && k.modelVersion != current {
            store.removeValue(forKey: k); order.removeAll { $0 == k }; staleInvalidations += 1
        }
    }
    public func invalidate(item: ContentItemID) {
        lock.lock(); defer { lock.unlock() }
        let before = store.count
        removeLocked { $0.itemRaw == item.raw }
        if store.count < before { staleInvalidations += 1 }
    }
    private func removeLocked(_ match: (Key) -> Bool) {
        for k in store.keys where match(k) { store.removeValue(forKey: k) }
        order.removeAll(where: match)
    }
    public var count: Int { lock.lock(); defer { lock.unlock() }; return store.count }
}

// MARK: - §3 provenance ledger V2 + evidence bus V2 (bounded).

public final class ProvenanceLedgerV2: @unchecked Sendable {
    public struct Entry: Sendable { public let subject: String, producer: String, modelVersion: String, profile: String, atMs: Double }
    private(set) public var entries: [Entry] = []
    private let lock = NSLock(); public let maxEntries: Int
    public init(maxEntries: Int = 4096) { self.maxEntries = maxEntries }
    public func record(subject: String, producer: String, modelVersion: String, profile: String, atMs: Double) {
        lock.lock(); entries.append(Entry(subject: subject, producer: producer, modelVersion: modelVersion, profile: profile, atMs: atMs))
        if entries.count > maxEntries { entries.removeFirst(entries.count - maxEntries) }; lock.unlock()
    }
    public func trace(subject: String) -> [Entry] { lock.lock(); defer { lock.unlock() }; return entries.filter { $0.subject == subject } }
}

public final class EvidenceBusV2: @unchecked Sendable {
    private(set) public var evidence: [ExpertEvidenceV2] = []
    private let lock = NSLock(); public let maxRecords: Int
    public init(maxRecords: Int = 2048) { self.maxRecords = maxRecords }
    public func publish(_ e: ExpertEvidenceV2) {
        lock.lock(); evidence.append(e); if evidence.count > maxRecords { evidence.removeFirst(evidence.count - maxRecords) }; lock.unlock()
    }
    public func forItem(_ item: ContentItemID, generation: UInt64) -> [ExpertEvidenceV2] {
        lock.lock(); defer { lock.unlock() }
        return evidence.filter { $0.itemID == item && $0.generation == generation && !$0.stale }
    }
    /// §21 stale firewall: mark everything from older generations stale (never crosses identities).
    public func markStale(before generation: UInt64) {
        lock.lock(); for i in evidence.indices where evidence[i].generation < generation { evidence[i].stale = true }; lock.unlock()
    }
    public var staleCount: Int { lock.lock(); defer { lock.unlock() }; return evidence.filter { $0.stale }.count }
}

// MARK: - §3 calibration registry SKELETON (P009B: everything uncalibrated; score display impossible).

public final class CalibrationRegistrySkeletonV1: @unchecked Sendable {
    public init() {}
    /// P009B truth: no domain is calibrated; numeric score display is always refused.
    public func isCalibrated(domain: ExpertDomainV2, language: String) -> Bool { false }
    public func scoreDisplayAllowed() -> Bool { false }
}
