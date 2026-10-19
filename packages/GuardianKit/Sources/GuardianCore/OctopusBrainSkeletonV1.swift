import Foundation

// MARK: - PROMPT 009A §12–§17 — OCTOPUS meta-brain SKELETON (interfaces/contracts), thin-shell pack contracts,
// and the privacy-gated learning flywheel. These are CONTRACTS + minimal reference implementations for testing —
// adapters wrap existing healthy subsystems (ShotSegmenterV5, ShieldEvaluatorV2, …); nothing is rewritten for naming.
// No downloadable executable code: runtime stays trusted shipped code; packs carry model/data/policy ASSETS only.

// MARK: - §12 expert + routing contracts.

public enum ExpertDomainV1: String, Sendable, Codable, CaseIterable {
    case vision = "VISION", ocrLanguage = "OCR_LANGUAGE", speech = "SPEECH", audio = "AUDIO", music = "MUSIC"
    case symbol = "SYMBOL", temporal = "TEMPORAL", safety = "SAFETY", childAge = "CHILD_AGE"
    case personalization = "PERSONALIZATION", calibration = "CALIBRATION", observation = "OBSERVATION"
    case surfaceMotion = "SURFACE_MOTION"
}
public struct ExpertDescriptorV1: Sendable {
    public let domain: ExpertDomainV1
    public let name: String
    public let version: String
    public let requiredPackIDs: [String]              // [] = built-in (e.g. the V5 shot sensor)
    public let capabilityRequirement: String          // e.g. "neural-engine", "none"
    public init(domain: ExpertDomainV1, name: String, version: String, requiredPackIDs: [String] = [], capabilityRequirement: String = "none") {
        self.domain = domain; self.name = name; self.version = version
        self.requiredPackIDs = requiredPackIDs; self.capabilityRequirement = capabilityRequirement
    }
}
public protocol ExpertRegistry: Sendable {
    func register(_ expert: ExpertDescriptorV1)
    func experts(for domain: ExpertDomainV1) -> [ExpertDescriptorV1]
    var all: [ExpertDescriptorV1] { get }
}
public final class ExpertRegistryV1: ExpertRegistry, @unchecked Sendable {
    private var store: [ExpertDescriptorV1] = []
    private let lock = NSLock()
    public init() {}
    public func register(_ expert: ExpertDescriptorV1) { lock.lock(); store.append(expert); lock.unlock() }
    public func experts(for domain: ExpertDomainV1) -> [ExpertDescriptorV1] { lock.lock(); defer { lock.unlock() }; return store.filter { $0.domain == domain } }
    public var all: [ExpertDescriptorV1] { lock.lock(); defer { lock.unlock() }; return store }
}

public struct IntelligenceTaskV1: Sendable {
    public let domain: ExpertDomainV1
    public let itemID: ContentItemID?
    public let tier: Int                               // 0 = cheap, 1 = escalation (§9)
    public let reason: String
    public init(domain: ExpertDomainV1, itemID: ContentItemID?, tier: Int, reason: String) {
        self.domain = domain; self.itemID = itemID; self.tier = tier; self.reason = reason
    }
}
public protocol IntelligenceTaskRouter: Sendable {
    /// Routes a task to an expert IF capability + resource governor permit; nil = honestly unavailable (UNKNOWN).
    func route(_ task: IntelligenceTaskV1) -> ExpertDescriptorV1?
}

// MARK: - §12 evidence bus + provenance ledger (bounded).

public struct EvidenceBusRecordV1: Sendable {
    public let domain: ExpertDomainV1
    public let itemID: ContentItemID?
    public let summary: String                         // compact derived summary, never raw media
    public let confidence: Double
    public let atMs: Double
    public let modelVersion: String
}
public final class EvidenceBusV1: @unchecked Sendable {
    public let maxRecords: Int
    private var records: [EvidenceBusRecordV1] = []
    private let lock = NSLock()
    public init(maxRecords: Int = 2048) { self.maxRecords = maxRecords }
    public func publish(_ r: EvidenceBusRecordV1) {
        lock.lock(); records.append(r); if records.count > maxRecords { records.removeFirst(records.count - maxRecords) }; lock.unlock()
    }
    public func records(for item: ContentItemID) -> [EvidenceBusRecordV1] {
        lock.lock(); defer { lock.unlock() }; return records.filter { $0.itemID == item }
    }
    public var count: Int { lock.lock(); defer { lock.unlock() }; return records.count }
}

public struct ProvenanceEntryV1: Sendable {
    public let subject: String                         // e.g. "dna:42", "item:7"
    public let producer: String                        // expert/engine name
    public let modelVersion: String
    public let policyVersion: String
    public let atMs: Double
}
public final class ProvenanceLedgerV1: @unchecked Sendable {
    private(set) public var entries: [ProvenanceEntryV1] = []
    public let maxEntries: Int
    private let lock = NSLock()
    public init(maxEntries: Int = 4096) { self.maxEntries = maxEntries }
    public func record(_ e: ProvenanceEntryV1) {
        lock.lock(); entries.append(e); if entries.count > maxEntries { entries.removeFirst(entries.count - maxEntries) }; lock.unlock()
    }
    public func trace(subject: String) -> [ProvenanceEntryV1] { lock.lock(); defer { lock.unlock() }; return entries.filter { $0.subject == subject } }
}

// MARK: - §12/§26 capability + resource governance.

public protocol CapabilityResolver: Sendable {
    func available(_ capability: String) -> Bool
}
public final class CapabilityResolverV1: CapabilityResolver, @unchecked Sendable {
    private let capabilities: Set<String>
    public init(capabilities: Set<String>) { self.capabilities = capabilities }
    public func available(_ capability: String) -> Bool { capability == "none" || capabilities.contains(capability) }
}

/// §26 resource governor: counts the session economy and DEDUPES deep inference (one expensive understanding
/// per item — many cheap reuse decisions). A second deep request for the same (item, domain) is denied → reuse.
public final class ResourceGovernorV1: @unchecked Sendable {
    public private(set) var shotEvents = 0, itemGroups = 0, deepEscalations = 0, cacheHits = 0, deniedDuplicates = 0
    private var deepDone = Set<String>()
    private let lock = NSLock()
    public init() {}
    public func noteShotEvent() { lock.lock(); shotEvents += 1; lock.unlock() }
    public func noteItemGroup() { lock.lock(); itemGroups += 1; lock.unlock() }
    public func noteCacheHit() { lock.lock(); cacheHits += 1; lock.unlock() }
    /// Returns true if the deep escalation may run; false = already done for this item+domain (reuse instead).
    public func requestDeepEscalation(item: ContentItemID, domain: ExpertDomainV1) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let key = "\(item.raw):\(domain.rawValue)"
        if deepDone.contains(key) { deniedDuplicates += 1; return false }
        deepDone.insert(key); deepEscalations += 1; return true
    }
}

/// §12 meta-brain facade: owns registry/router/bus/ledger/governor. Skeleton only — P009B+ fills the behavior.
public protocol GuardianMetaBrain: Sendable {
    var experts: ExpertRegistry { get }
    var evidenceBus: EvidenceBusV1 { get }
    var provenance: ProvenanceLedgerV1 { get }
    var governor: ResourceGovernorV1 { get }
}
public final class GuardianMetaBrainV1: GuardianMetaBrain, IntelligenceTaskRouter, @unchecked Sendable {
    public let experts: ExpertRegistry
    public let evidenceBus = EvidenceBusV1()
    public let provenance = ProvenanceLedgerV1()
    public let governor = ResourceGovernorV1()
    public let capabilities: CapabilityResolver
    public init(experts: ExpertRegistry = ExpertRegistryV1(), capabilities: CapabilityResolver = CapabilityResolverV1(capabilities: [])) {
        self.experts = experts; self.capabilities = capabilities
    }
    public func route(_ task: IntelligenceTaskV1) -> ExpertDescriptorV1? {
        let candidates = experts.experts(for: task.domain).filter { capabilities.available($0.capabilityRequirement) }
        guard let expert = candidates.first else { return nil }                        // honest UNKNOWN upstream
        if task.tier >= 1, let item = task.itemID,
           !governor.requestDeepEscalation(item: item, domain: task.domain) { return nil }  // reuse, not re-run
        return expert
    }
}

// MARK: - §13/§14 thin-shell intelligence pack contracts. Assets only — never executable code.

public struct IntelligencePackManifestV1: Sendable, Codable, Equatable {
    public enum AssetType: String, Sendable, Codable { case model = "MODEL", data = "DATA", config = "CONFIG" }
    public var packID: String
    public var semanticVersion: String
    public var engineCompatibility: String
    public var minimumOS: String
    public var deviceCapabilityRequirements: [String]
    public var sizeBytes: Int64
    public var checksum: UInt64                        // contract-level FNV-1a; production layer uses SHA-256 + signature
    public var signature: String                       // opaque signature token (verified by the platform layer)
    public var assetTypes: [AssetType]
    public var privacyClassification: String
    public var localeScope: [String]
    public var evictionPriority: Int                   // higher = evict sooner
    public var rollbackVersion: String?
    public var dependencies: [String]
    public init(packID: String, semanticVersion: String, engineCompatibility: String, minimumOS: String,
                deviceCapabilityRequirements: [String], sizeBytes: Int64, checksum: UInt64, signature: String,
                assetTypes: [AssetType], privacyClassification: String, localeScope: [String],
                evictionPriority: Int, rollbackVersion: String?, dependencies: [String]) {
        self.packID = packID; self.semanticVersion = semanticVersion; self.engineCompatibility = engineCompatibility
        self.minimumOS = minimumOS; self.deviceCapabilityRequirements = deviceCapabilityRequirements
        self.sizeBytes = sizeBytes; self.checksum = checksum; self.signature = signature; self.assetTypes = assetTypes
        self.privacyClassification = privacyClassification; self.localeScope = localeScope
        self.evictionPriority = evictionPriority; self.rollbackVersion = rollbackVersion; self.dependencies = dependencies
    }
    public static func fnv1a(_ data: [UInt8]) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in data { h ^= UInt64(b); h = h &* 0x100000001b3 }
        return h
    }
}

public enum PackStateV1: String, Sendable, Codable {
    case notInstalled = "NOT_INSTALLED", queued = "QUEUED", downloading = "DOWNLOADING", verifying = "VERIFYING"
    case installed = "INSTALLED", warm = "WARM", cold = "COLD", evictable = "EVICTABLE"
    case rollback = "ROLLBACK", quarantined = "QUARANTINED"
}

public protocol ModelPackRegistry: Sendable {
    func manifest(for packID: String) -> IntelligencePackManifestV1?
    func state(of packID: String) -> PackStateV1
}

/// §14 pack lifecycle contract. Base app stays usable without optional packs; missing capability surfaces as
/// UNKNOWN / pack-required, never as faked capability.
public final class IntelligencePackLifecycleManagerV1: ModelPackRegistry, @unchecked Sendable {
    private var manifests: [String: IntelligencePackManifestV1] = [:]
    private var states: [String: PackStateV1] = [:]
    private var lastUsed: [String: Double] = [:]
    private let lock = NSLock()
    public init() {}
    public func manifest(for packID: String) -> IntelligencePackManifestV1? { lock.lock(); defer { lock.unlock() }; return manifests[packID] }
    public func state(of packID: String) -> PackStateV1 { lock.lock(); defer { lock.unlock() }; return states[packID] ?? .notInstalled }

    /// VERIFY gate: checksum + signature + engine compatibility. Failure → QUARANTINED, never INSTALLED.
    @discardableResult
    public func install(_ m: IntelligencePackManifestV1, payload: [UInt8], engineVersion: String, signatureValid: Bool) -> PackStateV1 {
        lock.lock(); defer { lock.unlock() }
        manifests[m.packID] = m
        states[m.packID] = .verifying
        let ok = IntelligencePackManifestV1.fnv1a(payload) == m.checksum && signatureValid && m.engineCompatibility == engineVersion
        states[m.packID] = ok ? .installed : .quarantined
        return states[m.packID]!
    }
    public func markUsed(_ packID: String, nowMs: Double) {
        lock.lock(); lastUsed[packID] = nowMs
        if states[packID] == .installed || states[packID] == .cold { states[packID] = .warm }
        lock.unlock()
    }
    /// LRU/TTL + storage-pressure eviction (§14). Installed-but-stale packs become EVICTABLE, then NOT_INSTALLED.
    public func evictIfStale(_ packID: String, nowMs: Double, ttlMs: Double, storagePressure: Bool) -> PackStateV1 {
        lock.lock(); defer { lock.unlock() }
        guard var st = states[packID], st != .notInstalled else { return .notInstalled }
        let stale = nowMs - (lastUsed[packID] ?? 0) > ttlMs
        if stale || storagePressure {
            st = st == .evictable ? .notInstalled : .evictable
            states[packID] = st
        }
        return states[packID]!
    }
    /// ROLLBACK: revert to the manifest's declared rollback version; state → ROLLBACK then INSTALLED(old).
    public func rollback(_ packID: String) -> (state: PackStateV1, version: String)? {
        lock.lock(); defer { lock.unlock() }
        guard var m = manifests[packID], let prev = m.rollbackVersion else { return nil }
        states[packID] = .rollback
        m.semanticVersion = prev; m.rollbackVersion = nil
        manifests[packID] = m
        states[packID] = .installed
        return (.installed, prev)
    }
}

// MARK: - §15/§16 learning signal contract — NO raw private media payload, by type construction.

public enum LearningScopeV1: String, Sendable, Codable { case local = "LOCAL", globalAggregate = "GLOBAL_AGGREGATE" }
public enum ConsentClassV1: String, Sendable, Codable { case defaultLocal = "DEFAULT_LOCAL", optInGlobal = "OPT_IN_GLOBAL" }
public struct LearningSignalV1: Sendable, Codable, Equatable {
    public var signalType: String                     // e.g. "correction", "fp", "fn", "latency", "disagreement"
    public var derivedFeatureClass: String            // class name only — never features that reconstruct content
    public var scope: LearningScopeV1
    public var consent: ConsentClassV1
    public var privacyClass: String
    public var modelVersion: String
    public var policyVersion: String
    public var outcome: String
    public var correctionLabel: String?
    public var confidence: Double
    public var latencyMs: Double?
    public var locale: String
    public var deviceCapabilityBucket: String
    public var retentionDays: Int
    public var aggregationEligible: Bool
    public init(signalType: String, derivedFeatureClass: String, scope: LearningScopeV1, consent: ConsentClassV1,
                privacyClass: String, modelVersion: String, policyVersion: String, outcome: String,
                correctionLabel: String?, confidence: Double, latencyMs: Double?, locale: String,
                deviceCapabilityBucket: String, retentionDays: Int, aggregationEligible: Bool) {
        self.signalType = signalType; self.derivedFeatureClass = derivedFeatureClass; self.scope = scope
        self.consent = consent; self.privacyClass = privacyClass; self.modelVersion = modelVersion
        self.policyVersion = policyVersion; self.outcome = outcome; self.correctionLabel = correctionLabel
        self.confidence = confidence; self.latencyMs = latencyMs; self.locale = locale
        self.deviceCapabilityBucket = deviceCapabilityBucket; self.retentionDays = retentionDays
        self.aggregationEligible = aggregationEligible
    }
}
/// §12 learning signal bus — bounded; global-scope signals require opt-in consent or they are rejected.
public final class LearningSignalBusV1: @unchecked Sendable {
    public let maxSignals: Int
    private(set) public var signals: [LearningSignalV1] = []
    public private(set) var rejectedConsent = 0
    private let lock = NSLock()
    public init(maxSignals: Int = 2048) { self.maxSignals = maxSignals }
    @discardableResult
    public func submit(_ s: LearningSignalV1) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if s.scope == .globalAggregate && s.consent != .optInGlobal { rejectedConsent += 1; return false }   // §15
        signals.append(s); if signals.count > maxSignals { signals.removeFirst(signals.count - maxSignals) }
        return true
    }
}

// MARK: - §17 controlled model/policy evolution contracts (no uncontrolled self-rewriting production brain).

public enum EvolutionStageV1: String, Sendable, Codable, CaseIterable {
    case candidate = "CANDIDATE", offlineEval = "OFFLINE_EVAL", shadow = "SHADOW", canary = "CANARY"
    case calibration = "CALIBRATION", gate = "SAFETY_PRIVACY_RESOURCE_GATE", signedRelease = "SIGNED_RELEASE"
    case measuring = "MEASURING", rolledBack = "ROLLED_BACK", killed = "KILLED"
}
public struct EvolutionCandidateV1: Sendable, Codable {
    public var candidateVersion: String
    public var evalEvidenceRef: String                 // path/id of offline eval evidence — REQUIRED before shadow
    public var canaryCohortPercent: Double
    public var stage: EvolutionStageV1
    public var killSwitchArmed: Bool
    public init(candidateVersion: String, evalEvidenceRef: String, canaryCohortPercent: Double,
                stage: EvolutionStageV1 = .candidate, killSwitchArmed: Bool = true) {
        self.candidateVersion = candidateVersion; self.evalEvidenceRef = evalEvidenceRef
        self.canaryCohortPercent = canaryCohortPercent; self.stage = stage; self.killSwitchArmed = killSwitchArmed
    }
    /// Stages may only advance in canonical order; rollback/kill always allowed.
    public mutating func advance(to next: EvolutionStageV1) -> Bool {
        if next == .rolledBack || next == .killed { stage = next; return true }
        let order = EvolutionStageV1.allCases
        guard let cur = order.firstIndex(of: stage), let nxt = order.firstIndex(of: next), nxt == cur + 1 else { return false }
        if next == .shadow && evalEvidenceRef.isEmpty { return false }   // no shadow without offline eval evidence
        stage = next; return true
    }
}
