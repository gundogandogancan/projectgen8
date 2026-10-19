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

public enum ExpertAvailabilityV2: String, Sendable, Codable {
    case realRuntime = "REAL_RUNTIME"                    // real code, production/runtime wired
    case realButLabOnly = "REAL_BUT_LAB_ONLY"            // real code, app/lab process only
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
    public let profile: RuntimeCapabilityProfileV2
    public let privacyClass: EvidencePrivacyClassV1
    public let requestedDomains: [ExpertDomainV2]
    public let deadlineMs: Double
    public let cancellation: CancellationTokenV2
    public let generation: UInt64                         // identity generation — stale firewall key
    public init(observationID: ObservationID, shotID: ShotID?, itemID: ContentItemID?, itemProvisional: Bool,
                profile: RuntimeCapabilityProfileV2, privacyClass: EvidencePrivacyClassV1 = .derivedNonReconstructive,
                requestedDomains: [ExpertDomainV2], deadlineMs: Double = 1000,
                cancellation: CancellationTokenV2 = CancellationTokenV2(), generation: UInt64) {
        self.observationID = observationID; self.shotID = shotID; self.itemID = itemID
        self.itemProvisional = itemProvisional; self.profile = profile; self.privacyClass = privacyClass
        self.requestedDomains = requestedDomains; self.deadlineMs = deadlineMs
        self.cancellation = cancellation; self.generation = generation
    }
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

// MARK: - §3 resource governor V2 (thermal + dedupe + stats).

public final class ResourceGovernorV2: @unchecked Sendable {
    public private(set) var thermal: ThermalBucketV1 = .nominal
    private var deepDone = Set<String>()
    public private(set) var deniedDuplicates = 0, thermalDeferrals = 0
    private let lock = NSLock()
    public init() {}
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
    /// One expensive understanding per (item, domain) — duplicates denied → reuse.
    public func requestDeep(item: ContentItemID, domain: ExpertDomainV2) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let key = "\(item.raw):\(domain.rawValue)"
        if deepDone.contains(key) { deniedDuplicates += 1; return false }
        deepDone.insert(key); return true
    }
}

// MARK: - §18 intelligence cache V2.

public final class IntelligenceCacheV2: @unchecked Sendable {
    public struct Key: Hashable { public let itemRaw: UInt64; public let domain: ExpertDomainV2; public let modelVersion: String }
    private var store: [Key: ExpertEvidenceV2] = [:]
    private var order: [Key] = []
    public let maxEntries: Int
    public private(set) var hits = 0, misses = 0, staleInvalidations = 0
    private let lock = NSLock()
    public init(maxEntries: Int = 256) { self.maxEntries = maxEntries }
    public func lookup(item: ContentItemID, domain: ExpertDomainV2, modelVersion: String) -> ExpertEvidenceV2? {
        lock.lock(); defer { lock.unlock() }
        let k = Key(itemRaw: item.raw, domain: domain, modelVersion: modelVersion)
        if let v = store[k] { hits += 1; return v }
        misses += 1; return nil
    }
    public func insert(_ e: ExpertEvidenceV2) {
        guard let item = e.itemID, !e.itemProvisional else { return }     // provisional identity never cached durably
        lock.lock(); defer { lock.unlock() }
        let k = Key(itemRaw: item.raw, domain: e.domain, modelVersion: e.modelVersion)
        if store[k] == nil { order.append(k) }
        store[k] = e
        while order.count > maxEntries { store.removeValue(forKey: order.removeFirst()) }
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
        for (k, _) in store where k.itemRaw == item.raw { store.removeValue(forKey: k); order.removeAll { $0 == k }; staleInvalidations += 1 }
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
