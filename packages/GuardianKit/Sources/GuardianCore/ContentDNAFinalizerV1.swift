import Foundation

// MARK: - P009C §13/§14 — ContentDNA finalization + revision. Finalization requires AUTHORITATIVE
// identity (IdentityResolutionSnapshotV1 — the R1 F7 law), current generation, adequate evidence,
// provenance, and structural integrity. Durable payloads are canonical forms ONLY (persistence law).

public enum DNARevisionStateV1: String, Sendable, Codable {
    case candidate = "CANDIDATE", confirmed = "CONFIRMED", revised = "REVISED"
    case invalidated = "INVALIDATED", superseded = "SUPERSEDED"
}

public struct FinalContentDNAV1: Sendable {
    public let dnaID: ContentDNAID
    public let itemID: ContentItemID
    public let identityRevision: UInt64
    public let dnaRevision: UInt32
    public var revisionState: DNARevisionStateV1
    public let topics: [String]                     // concept IDs only
    public let entities: [String]                   // canonical entity forms only
    public let intents: [String]                    // intent hypotheses (canonical)
    public let intentAmbiguous: Bool
    public let narrativeSummary: [String]           // canonical narrative labels
    public let temporalStructure: [String]          // canonical event kinds in order
    public let safetyEvidence: [String]
    public let benefitEvidence: [String]
    public let manipulationEvidence: [String]
    public let emotionalLoad: [String]
    public let modalityCoverage: [ExpertDomainV2: Double]
    public let maxRiskSeen: Double
    public let uncertaintyOverall: Double
    public let knowledgeState: SemanticKnowledgeStateV1
    public let oodFlags: Int
    public let contradictionOutcomes: [String]
    public let provenanceCount: Int
    public let meshModelVersions: [String]
    public let worldModelVersion: String
    public let taxonomyVersion: String
    public let privacyClass: WorldModelPrivacyClassV1   // always PERSISTABLE_NONRECONSTRUCTIVE
    public let freshnessExpiresAtMs: Double
    public var auditTrail: [String]                 // revision provenance (append-only)
}

public final class ContentDNAFinalizerV1: @unchecked Sendable {
    public static let revision = "content-dna-finalizer-v1"
    public let minEvidenceQuality: Double
    private var finalized: [UInt64: FinalContentDNAV1] = [:]
    private let lock = NSLock()
    public init(minEvidenceQuality: Double = 0.25) { self.minEvidenceQuality = minEvidenceQuality }

    public enum RefusalV1: String { case notAuthoritative, staleGeneration, unresolvedSplitMerge,
        insufficientEvidence, provisionalEvidence, structuralCorruption, privacyViolation, foreignEvidence }

    /// §13 finalize — every gate re-verified here; the world model's own `readiness` is necessary, not sufficient.
    public func finalize(model: ContentWorldModelV1, identity: IdentityResolutionSnapshotV1,
                         currentGeneration: UInt64, dnaRaw: UInt64, nowMs: Double,
                         ttlMs: Double = 86_400_000) -> (dna: FinalContentDNAV1?, refusal: RefusalV1?) {
        guard identity.resolutionState == .confirmed, identity.confirmationAuthority == .tier1AppFull,
              identity.sourceProfile == .appFullTier1 else { return (nil, .notAuthoritative) }
        guard identity.generation == currentGeneration, model.generation == currentGeneration else { return (nil, .staleGeneration) }
        guard !identity.unresolvedSplitOrMerge, !identity.strongNewOrConflict else { return (nil, .unresolvedSplitMerge) }
        guard model.readiness, model.identityStatus == "confirmed" else { return (nil, .insufficientEvidence) }
        guard !model.anyEvidenceProvisional else { return (nil, .provisionalEvidence) }
        guard model.itemID == identity.itemID, model.identityRevision == identity.identityRevision,
              model.evidenceItemIDs.isSubset(of: [identity.itemID.raw]),
              model.evidenceGenerations.isSubset(of: [identity.generation]) else { return (nil, .foreignEvidence) }
        guard model.provenance.count > 0, !model.episodes.isEmpty else { return (nil, .structuralCorruption) }
        let quality = model.episodes.map { $0.confidence }.max() ?? 0
        guard quality >= minEvidenceQuality else { return (nil, .insufficientEvidence) }
        // P009C-R1 F-1: ONLY closed-vocabulary durable atoms may persist as entities — unmapped/ephemeral
        // nodes (durableAtomID == nil) are structurally excluded. No token blacklist anywhere.
        let durableEntities = model.entities.compactMap { $0.durableAtomID }

        let dna = FinalContentDNAV1(
            dnaID: ContentDNAID(dnaRaw), itemID: identity.itemID, identityRevision: identity.identityRevision,
            dnaRevision: 1, revisionState: .candidate,
            topics: (model.primaryTopics + model.secondaryTopics).map { $0.concept },
            entities: durableEntities,
            intents: model.intents.map { $0.intent.rawValue }, intentAmbiguous: model.intentAmbiguous,
            narrativeSummary: model.narrativeLabels,
            temporalStructure: model.events.map { $0.kind.rawValue },
            safetyEvidence: model.safetyEvidence, benefitEvidence: model.benefitEvidence,
            manipulationEvidence: model.manipulationEvidence, emotionalLoad: model.emotionalLoad,
            modalityCoverage: model.modalityCoverage, maxRiskSeen: model.maxRiskSeen,
            uncertaintyOverall: model.uncertainty.overall, knowledgeState: model.knowledgeState,
            oodFlags: model.oodFlags,
            contradictionOutcomes: model.contradictionResolutions.map { "contradiction:\($0.outcome.rawValue)" },
            provenanceCount: model.provenance.count, meshModelVersions: model.meshModelVersions,
            worldModelVersion: ContentWorldModelV1.modelVersion, taxonomyVersion: model.taxonomyVersion,
            privacyClass: .persistableNonReconstructive, freshnessExpiresAtMs: nowMs + ttlMs,
            auditTrail: ["revision:1:candidate@\(Int(nowMs))ms by \(Self.revision)"])
        // P009C-R1 §4: FULL field-by-field persistence audit of the final payload — recursive schema
        // traversal, closed-set/strict-grammar classification, unknown fields fail CLOSED. Any violation
        // refuses persistence (privacyViolation) — this replaces the old prefix-subset check.
        let violations = ContentDNAPersistenceAuditorV1.audit(dna)
        guard violations.isEmpty else { return (nil, .privacyViolation) }
        lock.lock(); finalized[identity.itemID.raw] = dna; lock.unlock()
        return (dna, nil)
    }

    /// §14 revision triggers — audit provenance preserved append-only.
    public enum RevisionTriggerV1: String {
        case newStrongEvidence = "new-strong-evidence", identitySplitMerge = "identity-split-merge"
        case modelVersionChange = "model-version-change", taxonomyChange = "taxonomy-change"
        case staleCache = "stale-cache", validatedLocalCorrection = "validated-local-correction"
    }
    @discardableResult
    public func applyRevision(item: ContentItemID, trigger: RevisionTriggerV1, nowMs: Double) -> DNARevisionStateV1? {
        lock.lock(); defer { lock.unlock() }
        guard var dna = finalized[item.raw] else { return nil }
        let newState: DNARevisionStateV1
        switch trigger {
        case .identitySplitMerge, .staleCache: newState = .invalidated
        case .modelVersionChange, .taxonomyChange: newState = .superseded
        case .newStrongEvidence, .validatedLocalCorrection: newState = .revised
        }
        dna.revisionState = newState
        dna.auditTrail.append("revision:\(dna.dnaRevision + 1):\(newState.rawValue):\(trigger.rawValue)@\(Int(nowMs))ms")
        finalized[item.raw] = dna
        return newState
    }
    public func confirm(item: ContentItemID, nowMs: Double) {
        lock.lock(); defer { lock.unlock() }
        guard var dna = finalized[item.raw], dna.revisionState == .candidate else { return }
        dna.revisionState = .confirmed
        dna.auditTrail.append("revision:confirmed@\(Int(nowMs))ms")
        finalized[item.raw] = dna
    }
    public func current(item: ContentItemID) -> FinalContentDNAV1? {
        lock.lock(); defer { lock.unlock() }; return finalized[item.raw]
    }
}
