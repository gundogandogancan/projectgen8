import Foundation

// MARK: - P009A PHASE C — Tier-0 capability closeout contracts.
// Measured Outcome C made the capability truth binding: EXTENSION_FAST_TIER0 provides SHOT segmentation +
// PROVISIONAL item identity only. It never claims authoritative feed-item grouping, exact item counts, full
// ContentDNA identity, or safe positive-state inheritance across ambiguous identity. Full grouping is a
// Tier-1 in-process multimodal capability (or future official shared capability).

// MARK: - §3 Tier-0 provisional identity output.

public enum ProvisionalRelationV1: String, Sendable, Codable {
    case candidateSameItem = "CANDIDATE_SAME_ITEM"       // Tier-0 may NEVER output a confirmed/authoritative SAME
    case candidateNewItem = "CANDIDATE_NEW_ITEM"
    case ambiguous = "AMBIGUOUS"
}

public struct ExtensionProvisionalIdentityV1: Sendable {
    public let shotID: ShotID
    public let provisionalItemID: ContentItemID
    public let relation: ProvisionalRelationV1
    public let strongNew: Bool
    public let compactEvidence: [String]                 // fired evidence-source names (derived, compact)
    public let independentFamilies: Int                  // §7 guard family count at decision time
    public let profileName: String
    public let groupingPolicyRevision: String
    public let shotPolicyRevision: String
    public init(shotID: ShotID, provisionalItemID: ContentItemID, relation: ProvisionalRelationV1, strongNew: Bool,
                compactEvidence: [String], independentFamilies: Int, profileName: String,
                groupingPolicyRevision: String, shotPolicyRevision: String) {
        self.shotID = shotID; self.provisionalItemID = provisionalItemID; self.relation = relation
        self.strongNew = strongNew; self.compactEvidence = compactEvidence
        self.independentFamilies = independentFamilies; self.profileName = profileName
        self.groupingPolicyRevision = groupingPolicyRevision; self.shotPolicyRevision = shotPolicyRevision
    }
    /// §3 reclassification: Tier-0 decisions map to CANDIDATE semantics — never authoritative grouping.
    public static func from(decision: ItemGroupingDecisionV1, shotID: ShotID,
                            profile: IdentityEvidenceProfileV1, groupingRevision: String, shotRevision: String) -> ExtensionProvisionalIdentityV1 {
        let relation: ProvisionalRelationV1
        switch decision.state {
        case .sameItemConfirmed, .candidateSameItem: relation = .candidateSameItem
        case .newItemConfirmed, .candidateNewItem: relation = .candidateNewItem
        default: relation = .ambiguous
        }
        let fired = decision.channels?.firedEvidence ?? []
        let families = Set(fired.compactMap { EvidenceIndependenceGuardV1.family(ofSameSource: $0) }).count
        return ExtensionProvisionalIdentityV1(shotID: shotID, provisionalItemID: decision.itemID, relation: relation,
                                              strongNew: decision.channels?.strongNew ?? false,
                                              compactEvidence: fired, independentFamilies: families,
                                              profileName: profile.name, groupingPolicyRevision: groupingRevision,
                                              shotPolicyRevision: shotRevision)
    }
}

// MARK: - §8 Tier-1 handoff contract — bounded, derived-only; NO raw private media ever.

public struct Tier1IdentityHandoffV1: Sendable {
    public let observationID: ObservationID
    public let shotID: ShotID
    public let provisionalItemID: ContentItemID
    public let transitionType: ShotTransitionInV1
    // temporal evidence (derived)
    public let gapSinceLastBoundaryMs: Double
    public let previousShotDwellMs: Double
    public let elapsedItemMs: Double
    // compact visual evidence (derived scalars — nothing reconstructive)
    public let themeDistance: Double
    public let projectionCorrelation: Double
    public let histogramDistance: Double
    public let chromeDistance: Double
    public let regionalDistance: Double
    public let ambiguityReason: String
    public let strongNew: Bool
    public let priorRelation: ProvisionalRelationV1
    public let thermalBucket: ThermalBucketV1
    public let capabilityProfile: String
    public let modelPolicyVersions: [String]
    public init(observationID: ObservationID, shotID: ShotID, provisionalItemID: ContentItemID,
                transitionType: ShotTransitionInV1, gapSinceLastBoundaryMs: Double, previousShotDwellMs: Double,
                elapsedItemMs: Double, themeDistance: Double, projectionCorrelation: Double, histogramDistance: Double,
                chromeDistance: Double, regionalDistance: Double, ambiguityReason: String, strongNew: Bool,
                priorRelation: ProvisionalRelationV1, thermalBucket: ThermalBucketV1, capabilityProfile: String,
                modelPolicyVersions: [String]) {
        self.observationID = observationID; self.shotID = shotID; self.provisionalItemID = provisionalItemID
        self.transitionType = transitionType; self.gapSinceLastBoundaryMs = gapSinceLastBoundaryMs
        self.previousShotDwellMs = previousShotDwellMs; self.elapsedItemMs = elapsedItemMs
        self.themeDistance = themeDistance; self.projectionCorrelation = projectionCorrelation
        self.histogramDistance = histogramDistance; self.chromeDistance = chromeDistance
        self.regionalDistance = regionalDistance; self.ambiguityReason = ambiguityReason; self.strongNew = strongNew
        self.priorRelation = priorRelation; self.thermalBucket = thermalBucket
        self.capabilityProfile = capabilityProfile; self.modelPolicyVersions = modelPolicyVersions
    }
    public static func from(identity: ExtensionProvisionalIdentityV1, observationID: ObservationID,
                            transition: ShotTransitionInV1, channels: GroupingChannelTelemetryV1?,
                            thermal: ThermalBucketV1) -> Tier1IdentityHandoffV1 {
        Tier1IdentityHandoffV1(observationID: observationID, shotID: identity.shotID,
                               provisionalItemID: identity.provisionalItemID, transitionType: transition,
                               gapSinceLastBoundaryMs: channels?.gapSinceLastBoundaryMs ?? 0,
                               previousShotDwellMs: channels?.previousShotDwellMs ?? 0,
                               elapsedItemMs: channels?.elapsedItemMs ?? 0,
                               themeDistance: channels?.themeDistance ?? 1,
                               projectionCorrelation: channels?.projectionCorrelation ?? 0,
                               histogramDistance: channels?.histogramDistance ?? 1,
                               chromeDistance: channels?.chromeDistance ?? 1,
                               regionalDistance: channels?.regionalDistance ?? 1,
                               ambiguityReason: identity.relation == .ambiguous ? "insufficient-independent-evidence" : "",
                               strongNew: identity.strongNew, priorRelation: identity.relation,
                               thermalBucket: thermal, capabilityProfile: identity.profileName,
                               modelPolicyVersions: [identity.groupingPolicyRevision, identity.shotPolicyRevision,
                                                     EvidenceIndependenceGuardV1.revision])
    }
}

/// Bounded in-process ring of handoff records awaiting Tier-1 (no persistence; no raw media by construction).
public final class Tier1HandoffBufferV1: @unchecked Sendable {
    public let capacity: Int
    private(set) public var records: [Tier1IdentityHandoffV1] = []
    private let lock = NSLock()
    public init(capacity: Int = 64) { self.capacity = max(8, capacity) }
    public func append(_ r: Tier1IdentityHandoffV1) {
        lock.lock(); records.append(r); if records.count > capacity { records.removeFirst(records.count - capacity) }; lock.unlock()
    }
    public var count: Int { lock.lock(); defer { lock.unlock() }; return records.count }
    public func drain() -> [Tier1IdentityHandoffV1] { lock.lock(); defer { lock.unlock() }; let r = records; records = []; return r }
}

// MARK: - §9 SHOT_ONLY evidence record (allowed while item identity is unresolved — never durable item DNA).

public struct ShotOnlyEvidenceRecordV1: Sendable {
    public let shotID: ShotID
    public let provisionalItemID: ContentItemID
    public let riskEscalated: Bool                        // strong risk evidence may escalate immediately (§9)
    public let maxRiskConfidence: Double
    public let provenance: [String]
    public let privacyClass: EvidencePrivacyClassV1
}

// MARK: - §10 release evidence-logging policy — testable pure function used by the extension.

public enum EvidenceBuildPolicyV1 {
    /// High-volume evidence logging (per-frame MOTION, per-shot SHOTEV) is permitted ONLY when the compile-time
    /// evidence flag is set, or in DEBUG builds via an explicit env opt-in. NEVER in release (the Phase-B
    /// measurement drove the device to THERMAL_SERIOUS purely from logging I/O — audit/debug instrument only).
    public static func isEnabled(compileFlagSet: Bool, isDebugBuild: Bool, envOptIn: Bool) -> Bool {
        if compileFlagSet { return true }
        if isDebugBuild && envOptIn { return true }
        return false                                       // release: structurally OFF regardless of env
    }
}
