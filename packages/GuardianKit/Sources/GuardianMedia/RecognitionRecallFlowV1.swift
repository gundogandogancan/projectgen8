//
//  RecognitionRecallFlowV1.swift — R11-B P0(3): the RECOGNITION RECALL GATE + FLOW. The single authority that decides
//  whether a verified recognition hit's CACHED evidence may enter the CURRENT world model, and the builder that turns a
//  cached memory record into CURRENT-policy evidence for re-adjudication (mandate §3.1 / §5).
//
//  THE LAW (mandate §3.1): a recognition hit NEVER republishes an old decision. It re-uses only policy-INDEPENDENT
//  cached EVIDENCE, and only after the recall gate confirms the cached record is still valid under the CURRENT
//  context, and only through `WorldModelEvidenceBridgeV1.build` → the frozen SafetyPolicy/Child path → the CURRENT
//  decision. The cached evidence carries its ORIGINAL coverage (4s analyzed → 4s known) and is PROVENANCE-MARKED as
//  cached so the world model distinguishes it from a live observation.
//
//  THE RECALL GATE (`RecognitionRecallGateV1.decide`) is a PURE apply-or-drop firewall — the exact discipline of R10's
//  `AudioAsyncRevalidatorV1`: every binding field must still hold, or the cache is NOT reused and the reason is
//  counted. Precedence is explicit and ordered. This is why "false match is worse than no match" never leaks: a
//  weak/ambiguous recognition, an expired/corrupt/version-mismatched record, a changed policy/family revision, a
//  disabled memory toggle, or a live contradiction all DROP the reuse and fall back to live evidence only.
//
//  Pure + headless. Lives in GuardianMedia; CALLS the GuardianMedia bridge (which calls frozen GuardianCore).
//
import Foundation
import GuardianCore

// MARK: - §3.1 the recall decision (apply-or-drop, with reasons)

/// R11 §3.1 — the outcome of the recall gate. `reuseCachedEvidence` is the ONLY outcome that passes cached evidence
/// into the current world model; every other outcome means "recognize-and-recall did NOT contribute; decide live".
public enum RecognitionRecallDecisionV1: String, Sendable, Equatable, CaseIterable {
    case reuseCachedEvidence         = "REUSE_CACHED_EVIDENCE"          // verified HIGH + record valid under current ctx
    case droppedMemoryDisabled       = "DROPPED_MEMORY_DISABLED"        // the user turned the memory OFF
    case droppedNotHighConfidence    = "DROPPED_NOT_HIGH_CONFIDENCE"    // partial / ambiguous / no-match → no reuse
    case droppedRecordUnusable       = "DROPPED_RECORD_UNUSABLE"        // expired / revoked
    case droppedVersionMismatch      = "DROPPED_VERSION_MISMATCH"       // signature schema/basis/corrupt → no reuse
    case droppedPolicyChanged        = "DROPPED_POLICY_CHANGED"         // policy revision moved since caching
    case droppedFamilyChanged        = "DROPPED_FAMILY_CHANGED"         // family/child revision moved since caching
    case droppedLiveContradiction    = "DROPPED_LIVE_CONTRADICTION"     // a live observation contradicts the cache

    public var reuses: Bool { self == .reuseCachedEvidence }
}

/// R11 §3.1 — the CURRENT context the cached record is revalidated against at recall time. Mirrors the R10 audio
/// `AudioLiveStateV1` shape: the full freshness contract, not just identity.
public struct RecognitionRecallContextV1: Sendable, Equatable {
    public let memoryEnabled: Bool
    public let currentPolicyRevision: UInt64
    public let currentFamilyRevision: UInt64
    /// The policy/family revisions the cached evidence was ORIGINALLY produced under (stored with the record's
    /// provenance by the caller). When current != cached, the cached decision basis is stale → re-adjudicate live.
    public let cachedUnderPolicyRevision: UInt64
    public let cachedUnderFamilyRevision: UInt64
    /// True when the live observation for THIS item CONTRADICTS the cached evidence (e.g. a live safety marker the
    /// cache did not have, or a live identity signal that disagrees). When true, cache authority DROPS (mandate §5).
    public let liveContradiction: Bool
    public let nowEpoch: Double
    public init(memoryEnabled: Bool, currentPolicyRevision: UInt64, currentFamilyRevision: UInt64,
                cachedUnderPolicyRevision: UInt64, cachedUnderFamilyRevision: UInt64,
                liveContradiction: Bool, nowEpoch: Double) {
        self.memoryEnabled = memoryEnabled
        self.currentPolicyRevision = currentPolicyRevision; self.currentFamilyRevision = currentFamilyRevision
        self.cachedUnderPolicyRevision = cachedUnderPolicyRevision; self.cachedUnderFamilyRevision = cachedUnderFamilyRevision
        self.liveContradiction = liveContradiction; self.nowEpoch = nowEpoch
    }
}

public enum RecognitionRecallGateV1 {
    /// R11 §3.1 — the PURE recall decision. Ordered precedence (child-safety-first flavour: any doubt → do NOT reuse):
    /// 1. memory disabled → never reuse. 2. recognition not HIGH/verified → never reuse. 3. record unusable
    /// (expired/revoked) → never reuse. 4. signature version-mismatch/corrupt → never reuse. 5. policy/family revision
    /// changed since caching → re-adjudicate live (the cached BASIS is stale; the evidence itself is policy-independent
    /// but reusing it as-is would risk inheriting a stale decision context). 6. live contradiction → cache authority
    /// drops. Otherwise → reuse.
    public static func decide(level: RecognitionLevelV1,
                              record: ContentEvidenceMemoryRecordV1,
                              context: RecognitionRecallContextV1) -> RecognitionRecallDecisionV1 {
        if !context.memoryEnabled { return .droppedMemoryDisabled }
        guard level.mayReuseCachedEvidence else { return .droppedNotHighConfidence }
        guard record.isUsable(nowEpoch: context.nowEpoch) else { return .droppedRecordUnusable }
        guard record.signature.isComparable else { return .droppedVersionMismatch }
        if context.currentPolicyRevision != context.cachedUnderPolicyRevision { return .droppedPolicyChanged }
        if context.currentFamilyRevision != context.cachedUnderFamilyRevision { return .droppedFamilyChanged }
        if context.liveContradiction { return .droppedLiveContradiction }
        return .reuseCachedEvidence
    }
}

// MARK: - §3.1 turning a cached record into CURRENT-policy evidence envelopes

/// R11 §3.1 — map the stored POLICY-INDEPENDENT cached evidence into frozen `ExpertEvidenceV2` envelopes, bound to the
/// CURRENT item's identity + generation (so the live builder's stale-firewall accepts them as this-item evidence), and
/// PROVENANCE-MARKED as cached (the provenance string is prefixed `cached-evidence-memory-v1:` so the world model + the
/// proof log can always tell a recalled evidence from a live observation). Confidence/coverage/calibration are carried
/// VERBATIM from the cache — we neither inflate nor repair them (mandate §10: memory amplifies prior evidence quality,
/// it does not repair missing intelligence).
public enum RecognitionCachedEvidenceMapperV1 {
    public static let provenancePrefix = "cached-evidence-memory-v1"

    public static func envelopes(from record: ContentEvidenceMemoryRecordV1,
                                 currentContentID: String, currentItemIdentityRevision: Int,
                                 currentGeneration: UInt64, currentShotID: UInt64) -> [ExpertEvidenceV2] {
        let item = WorldModelEvidenceBridgeV1.itemID(for: currentContentID)
        let shot = ShotID(currentShotID)
        return record.evidence.map { e in
            let domain = ExpertDomainV2(rawValue: e.modalityRaw) ?? .temporal
            let calib = EvidenceCalibrationStatusV2(rawValue: e.calibrationStatusRaw) ?? .heuristicSupportOnly
            let startMs = e.scopeStartSeconds * 1000.0
            let endMs = max(startMs, e.scopeEndSeconds * 1000.0)
            return ExpertEvidenceV2(
                domain: domain, labels: e.labels, confidence: e.confidence,
                coverage: e.coverage, uncertainty: e.uncertainty,
                temporalScopeMs: startMs...endMs, shotID: shot, itemID: item, itemProvisional: false,
                provenance: "\(provenancePrefix): \(e.provenance) (RECALLED cached evidence; original epoch \(String(format: "%.0f", record.originalEvidenceEpoch)); coverage honest; NOT a republished decision)",
                modelVersion: e.modelVersion, inputModalityAvailable: true,
                calibrationStatus: calib, generation: currentGeneration)
        }
    }
}

// MARK: - §3.1 the recall flow result

/// R11 §3.1 — the result of a recall attempt: the decision, the world-model re-adjudication result (when reused), the
/// honest coverage the recall contributed, and the user-facing recognition reason code.
public struct RecognitionRecallResultV1: Sendable {
    public let decision: RecognitionRecallDecisionV1
    public let level: RecognitionLevelV1
    /// Only present on reuse: the CURRENT world-model + safety result after re-adjudicating the cached evidence.
    public let reAdjudicated: WorldModelBridgeResultV1?
    /// Honest coverage the recall contributed (seconds of the content that the cached evidence actually covered).
    public let contributedCoverageSeconds: Double
    /// The user-facing recognition reason code for this recall outcome.
    public let reasonCode: GuardianReasonCodeV1
    public let latencyMs: Double
    public init(decision: RecognitionRecallDecisionV1, level: RecognitionLevelV1,
                reAdjudicated: WorldModelBridgeResultV1?, contributedCoverageSeconds: Double,
                reasonCode: GuardianReasonCodeV1, latencyMs: Double) {
        self.decision = decision; self.level = level; self.reAdjudicated = reAdjudicated
        self.contributedCoverageSeconds = contributedCoverageSeconds; self.reasonCode = reasonCode
        self.latencyMs = latencyMs
    }
}

/// R11 §3.1/§5 — the orchestrating flow. Given a verified recognition level + the matched record + the current context
/// + the LIVE evidence inputs for this item, produce the recall result. On reuse it builds a `WorldModelBridgeInputV1`
/// that INCLUDES the recalled cached evidence (as `precomputedTextEvidence`-routed envelopes) alongside any live
/// evidence, then calls the bridge for CURRENT-policy re-adjudication. On any drop it returns the honest "analysis
/// progressing / partial / unknown" state WITHOUT cached influence.
public enum RecognitionRecallFlowV1 {

    /// Map a recall outcome to the user-facing recognition reason code (Turkish strings live on GuardianReasonCodeV1).
    public static func reasonCode(for decision: RecognitionRecallDecisionV1, level: RecognitionLevelV1) -> GuardianReasonCodeV1 {
        switch decision {
        case .reuseCachedEvidence:      return .recognizedPriorEvidenceValid
        case .droppedNotHighConfidence:
            // A partial visual similarity is surfaced honestly; anything weaker is "new content, analysis progressing".
            return level == .partialVisualSimilarity ? .partiallyRecognizedVerificationRequired : .newContentAnalyzing
        case .droppedMemoryDisabled, .droppedRecordUnusable, .droppedVersionMismatch,
             .droppedPolicyChanged, .droppedFamilyChanged, .droppedLiveContradiction:
            // The content may well be recognized visually, but the cache cannot be reused → treat as new/analyzing;
            // the live evidence path decides. (A policy/family change is explicitly a re-adjudication, not a replay.)
            return .newContentAnalyzing
        }
    }

    /// Run the recall. `liveBridgeInput` is the bridge input the caller would have used for a FRESH live-only
    /// evaluation (its own live evidence, current revisions, current identity). On reuse, the cached evidence
    /// envelopes are MERGED into it (appended to any precomputed live text evidence) so the bridge re-adjudicates live
    /// + cached together under the CURRENT policy. On a drop, the bridge is NOT run here (the caller runs its normal
    /// live path); we only return the decision + reason.
    public static func recall(level: RecognitionLevelV1,
                              matchedRecord: ContentEvidenceMemoryRecordV1?,
                              context: RecognitionRecallContextV1,
                              liveBridgeInput: WorldModelBridgeInputV1,
                              reAdjudicate: Bool = true) -> RecognitionRecallResultV1 {
        let t0 = MonotonicClockV1.nowMs()
        guard let record = matchedRecord else {
            let d: RecognitionRecallDecisionV1 = context.memoryEnabled ? .droppedNotHighConfidence : .droppedMemoryDisabled
            return RecognitionRecallResultV1(decision: d, level: level, reAdjudicated: nil,
                                             contributedCoverageSeconds: 0, reasonCode: reasonCode(for: d, level: level),
                                             latencyMs: MonotonicClockV1.nowMs() - t0)
        }
        let decision = RecognitionRecallGateV1.decide(level: level, record: record, context: context)
        guard decision.reuses else {
            return RecognitionRecallResultV1(decision: decision, level: level, reAdjudicated: nil,
                                             contributedCoverageSeconds: 0, reasonCode: reasonCode(for: decision, level: level),
                                             latencyMs: MonotonicClockV1.nowMs() - t0)
        }
        // REUSE: merge cached evidence into the live bridge input and re-adjudicate under CURRENT policy.
        let cached = RecognitionCachedEvidenceMapperV1.envelopes(
            from: record, currentContentID: liveBridgeInput.contentID,
            currentItemIdentityRevision: liveBridgeInput.itemIdentityRevision,
            currentGeneration: liveBridgeInput.generation, currentShotID: liveBridgeInput.shotID)
        var result: WorldModelBridgeResultV1? = nil
        if reAdjudicate {
            let merged = Self.merge(cachedEvidence: cached, into: liveBridgeInput)
            result = WorldModelEvidenceBridgeV1.build(merged)
        }
        return RecognitionRecallResultV1(decision: decision, level: level, reAdjudicated: result,
                                         contributedCoverageSeconds: record.signature.coverageDurationSeconds,
                                         reasonCode: .recognizedPriorEvidenceValid,
                                         latencyMs: MonotonicClockV1.nowMs() - t0)
    }

    /// The text-expert domains the bridge's `precomputedTextEvidence` seam consumes (SINGLE EVIDENCE, MANY DECISIONS).
    /// Only cached evidence in these domains can re-enter the frozen builder through this seam; other modalities
    /// (audioEvent/vision) have their OWN bridge inputs and are NOT fabricated here (honest: no fake modality).
    static let textSeamDomains: Set<ExpertDomainV2> = [.languageOCR, .safetyEvidence, .benefitEvidence, .attentionPressure]

    /// Append the recalled cached TEXT-domain evidence to the live input's precomputed text evidence so the bridge
    /// re-adjudicates live + cached together under the CURRENT policy. CONSUMPTION HONESTY: the bridge only folds
    /// `precomputedTextEvidence` when the item has text context (`ocrText` non-empty). When a recalled item has NO
    /// current text AND the cache is text-only, the cached envelopes are carried in the input (and the result
    /// provenance) but the frozen builder will not fold them this pass — we do NOT fabricate OCR text to force it
    /// (mandate §4: no raw/synthetic text). Broadening non-text cached-modality injection is a NEXT item. We do NOT
    /// overwrite the live audio / register / stance fields — those stay live.
    static func merge(cachedEvidence: [ExpertEvidenceV2], into input: WorldModelBridgeInputV1) -> WorldModelBridgeInputV1 {
        let live = input.precomputedTextEvidence ?? []
        let seamCached = cachedEvidence.filter { textSeamDomains.contains($0.domain) }
        let combined = live + seamCached
        return WorldModelBridgeInputV1(
            sessionID: input.sessionID, contentID: input.contentID,
            itemIdentityRevision: input.itemIdentityRevision, identityConfirmed: input.identityConfirmed,
            generation: input.generation, shotID: input.shotID,
            observationStartMs: input.observationStartMs, observationEndMs: input.observationEndMs,
            ocrText: input.ocrText, ocrLanguage: input.ocrLanguage,
            policyRevision: input.policyRevision, familyProfileRevision: input.familyProfileRevision,
            photoShieldActionableMatch: input.photoShieldActionableMatch,
            emotionalRegister: input.emotionalRegister, contextStance: input.contextStance,
            targetedPressure: input.targetedPressure, liveAudioEvidence: input.liveAudioEvidence,
            precomputedTextEvidence: combined.isEmpty ? nil : combined)
    }
}
