//
//  WorldModelEvidenceBridgeV1.swift — R5 §4 (P0-2): the MINIMUM DERIVED-EVIDENCE BRIDGE from the extension's REAL
//  evidence to the FROZEN canonical world-model path (P009B Expert Evidence → WorldModelBuilderV1 →
//  SafetyPolicyEngineV1 → ChildAgePolicyEngineV1).
//
//  WHY: R4 proved the frozen engines are real but UNREACHABLE from the broadcast extension — no evidence envelopes
//  were ever built on that path, so `ChildAgePolicyEngineV1.evaluate` could only run in tests. This bridge closes
//  that gap WITHOUT a second world model and WITHOUT fabricating evidence:
//
//   • It RUNS THE REAL FROZEN TEXT EXPERTS (LanguageOCRExpertV1, SafetyEvidenceExpertV1, BenefitEvidenceExpertV1,
//     AttentionPressureExpertV1 — the exact arms the lab mesh uses) over the OCR text the extension actually has.
//     The envelopes they return ARE the P009B evidence — nothing is synthesized or re-labeled.
//   • Modalities the extension genuinely does NOT analyze (vision scene classes, speech, audio events, music,
//     symbols) enter as HONEST `ExpertEvidenceV2.unavailable` records — coverage 0, inputModalityAvailable=false.
//     `soundEvents: []` is NEVER presented as "audio analyzed clean". The H1 visual high-risk gap stays visible:
//     SafetyPolicyEngineV1 keeps those dimensions UNAVAILABLE (SafetyDimensionTruthV1) regardless of anything here.
//   • The EMOTIONAL REGISTER verdict (R5 §5) enters as its OWN evidence record (attentionPressure domain, its own
//     provenance + model version, heuristicSupportOnly) — a real structural finding, never dressed as a lexicon hit.
//   • An actionable PERSONAL photo-shield match enters as a narrow visual evidence slice (a real luma-signature
//     observation; label namespaced `personal:` so it can never masquerade as a safety/wellbeing class).
//   • Contradictions are NOT dropped: the frozen WorldModelBuilderV1 routes risk-vs-positive evidence through
//     ContradictionResolverV1 internally (the canonical path; no second resolver here).
//   • NEW ITEM → FRESH WORLD MODEL: a NEW builder instance per call; evidence is stamped with the item + generation
//     and the builder's stale/generation firewall excludes anything else. No carryover (pinned by test).
//
//  PERFORMANCE LAW (§4): the bridge runs PER ITEM (inside the extension's `mustEvaluate` gate) — never per frame.
//  All four text experts are bounded lexicon scans; the builder sees ONE observation. Tier-0 stays cheap.
//
//  Pure + headless + versioned. Lives in GuardianMedia; CALLS GuardianCore (frozen) — never edits it.
//
import Foundation
import GuardianCore

// MARK: - §4 — the bridge input: ONLY facts the extension really has (every field is already derived/ephemeral).

public struct WorldModelBridgeInputV1: Sendable {
    public let sessionID: String
    /// The RESOLVED content identity (Tier-1-resolved) this evidence binds to.
    public let contentID: String
    public let itemIdentityRevision: Int
    /// True only when the identity is tier-confirmed (`.newConfirmed`/continuation of a confirmed id). A provisional
    /// identity flows through honestly — the frozen child engine fails closed on it (identity != confirmed).
    public let identityConfirmed: Bool
    public let generation: UInt64
    public let shotID: UInt64
    public let observationStartMs: Double
    public let observationEndMs: Double
    /// EPHEMERAL on-screen OCR text (never persisted; passed through to the builder's context-tag heuristics only).
    public let ocrText: String?
    public let ocrLanguage: String?
    public let policyRevision: UInt64
    public let familyProfileRevision: UInt64
    /// True when an ACTIONABLE personal photo-shield match exists for THIS item (a real visual observation slice).
    public let photoShieldActionableMatch: Bool
    /// R5 §5 — the emotional-register verdict for this item's text (nil = adapter did not run).
    public let emotionalRegister: EmotionalRegisterVerdictV1?

    public init(sessionID: String, contentID: String, itemIdentityRevision: Int, identityConfirmed: Bool,
                generation: UInt64, shotID: UInt64, observationStartMs: Double, observationEndMs: Double,
                ocrText: String?, ocrLanguage: String?, policyRevision: UInt64, familyProfileRevision: UInt64,
                photoShieldActionableMatch: Bool, emotionalRegister: EmotionalRegisterVerdictV1?) {
        self.sessionID = sessionID; self.contentID = contentID
        self.itemIdentityRevision = itemIdentityRevision; self.identityConfirmed = identityConfirmed
        self.generation = generation; self.shotID = shotID
        self.observationStartMs = observationStartMs; self.observationEndMs = observationEndMs
        self.ocrText = ocrText; self.ocrLanguage = ocrLanguage
        self.policyRevision = policyRevision; self.familyProfileRevision = familyProfileRevision
        self.photoShieldActionableMatch = photoShieldActionableMatch; self.emotionalRegister = emotionalRegister
    }
}

// MARK: - §4 — the bridge result: the REAL canonical artifacts + honest coverage accounting.

public struct WorldModelBridgeResultV1: Sendable {
    public let worldModel: ContentWorldModelV1
    public let safety: SafetyPolicyResultV1
    public let evidenceCount: Int
    /// The modalities honestly declared UNAVAILABLE on this pass (derived strings for the proof log).
    public let unavailableModalities: [String]
    public let latencyMs: Double
}

public enum WorldModelEvidenceBridgeV1 {
    public static let version = "world-model-evidence-bridge-v1"

    /// Stable 64-bit id for the resolved content-id string (FNV-1a) — the ContentItemID the evidence binds to.
    /// Deterministic within and across sessions for the same resolved id; carries no content semantics.
    public static func itemID(for contentID: String) -> ContentItemID {
        var hash: UInt64 = 0xcbf29ce484222325
        for b in contentID.utf8 { hash = (hash ^ UInt64(b)) &* 0x100000001b3 }
        return ContentItemID(hash)
    }

    /// Build the REAL world model + safety result for ONE resolved item. Per-item only (caller: inside
    /// `mustEvaluate`) — never per frame. A fresh `WorldModelBuilderV1` per call = no cross-item carryover.
    public static func build(_ input: WorldModelBridgeInputV1) -> WorldModelBridgeResultV1 {
        let t0 = MonotonicClockV1.nowMs()
        let item = itemID(for: input.contentID)
        let shot = ShotID(input.shotID)
        let gen = input.generation
        let provisional = !input.identityConfirmed
        var evidence: [ExpertEvidenceV2] = []
        var unknownReasons: [String] = []
        var unavailable: [String] = []

        let hasText = (input.ocrText?.isEmpty == false)
        if hasText {
            // THE REAL FROZEN TEXT EXPERTS — the same arms the lab mesh runs; their envelopes are the evidence.
            let (sanitized, flags) = ExpertInputSanitizerV2.sanitize(
                ExpertInputV2(ocrText: input.ocrText, detectedLanguage: input.ocrLanguage))
            unknownReasons.append(contentsOf: flags.map { "input-sanitized:\($0)" })
            let ctx = ExpertTaskContextV2(observationID: ObservationID(gen), shotID: shot, itemID: item,
                                          itemProvisional: provisional,
                                          identityRevision: UInt64(max(0, input.itemIdentityRevision)),
                                          profile: .extensionFastTier0,
                                          requestedDomains: [.languageOCR, .safetyEvidence, .benefitEvidence,
                                                             .attentionPressure],
                                          generation: gen, cacheEligible: false)
            evidence.append(LanguageOCRExpertV1().evaluate(sanitized, context: ctx))
            evidence.append(SafetyEvidenceExpertV1().evaluate(sanitized, context: ctx))
            evidence.append(BenefitEvidenceExpertV1().evaluate(sanitized, context: ctx))
            evidence.append(AttentionPressureExpertV1().evaluate(sanitized, context: ctx))
        } else {
            // NO text on this item: the text-derived domains are honestly UNAVAILABLE — never "examined clean".
            for d in [ExpertDomainV2.languageOCR, .safetyEvidence, .benefitEvidence, .attentionPressure] {
                evidence.append(.unavailable(d, reason: "no-ocr-text-on-extension-path", generation: gen))
                unavailable.append(d.rawValue)
            }
            unknownReasons.append("bridge:no-text-evidence")
        }

        // Modalities the extension genuinely does NOT analyze — HONEST UNAVAILABLE, never silence, never "clean".
        // (soundEvents is structurally [] on this path: audio coverage is UNAVAILABLE, not examined.)
        evidence.append(.unavailable(.speech, reason: "no-speech-analysis-on-extension-path", generation: gen))
        evidence.append(.unavailable(.audioEvent, reason: "no-audio-analysis-on-extension-path", generation: gen))
        evidence.append(.unavailable(.music, reason: "no-music-analysis-on-extension-path", generation: gen))
        evidence.append(.unavailable(.symbol, reason: "no-symbol-provider-on-extension-path", generation: gen))
        unavailable.append(contentsOf: [ExpertDomainV2.speech.rawValue, ExpertDomainV2.audioEvent.rawValue,
                                        ExpertDomainV2.music.rawValue, ExpertDomainV2.symbol.rawValue])
        unknownReasons.append("bridge:audio-speech-music-symbol-unavailable")
        // H1: the high-risk VISUAL classes are UNAVAILABLE (registry law). SafetyPolicyEngineV1 enforces the
        // dimension truth itself; this record keeps the gap visible in modality coverage too.
        evidence.append(.unavailable(.vision, reason: "h1-visual-high-risk-classes-unavailable", generation: gen))
        unavailable.append(ExpertDomainV2.vision.rawValue)
        unknownReasons.append("bridge:h1-visual-high-risk-unavailable")

        // An ACTIONABLE personal photo-shield match is a REAL (narrow) visual observation: a near-exact perceptual
        // signature match against the user's own reference. Namespaced `personal:` — it can never read as a safety
        // class, and the H1 unavailability above is untouched (one tiny observed slice ≠ visual screening).
        if input.photoShieldActionableMatch {
            evidence.append(ExpertEvidenceV2(
                domain: .vision, labels: ["personal:photo-reference-match"],
                confidence: 0.7, coverage: 0.1, uncertainty: 0.3,
                temporalScopeMs: input.observationStartMs...max(input.observationStartMs, input.observationEndMs),
                shotID: shot, itemID: item, itemProvisional: provisional,
                provenance: "photo-shield-luma-matcher-v1 (personal reference; not a safety classifier)",
                modelVersion: "photo-shield-luma-matcher-v1",
                calibrationStatus: .heuristicSupportOnly, generation: gen))
        }

        // R5 §5 — the emotional-register finding as its OWN evidence record. Only REAL, supported verdicts enter;
        // UNKNOWN/notApplicable produce NOTHING (no fabricated modality). Pressure registers are attention/
        // manipulation-pressure evidence (`attention:` namespace = the canonical manipulation evidence family);
        // informational/supportive are carried as counter-evidence context labels (never a safety clear).
        if let reg = input.emotionalRegister, reg.support == .supported, reg.register != .unknown {
            let label: String
            switch reg.register {
            case .fearPressure:     label = "attention:register-fear-pressure"
            case .coerciveThreat:   label = "attention:register-coercive-threat"
            case .sensationalPanic: label = "attention:register-sensational-panic"
            case .urgencyViaFear:   label = "attention:register-urgency-via-fear"
            case .informational:    label = "pattern:register-informational"
            case .supportive:       label = "pattern:register-supportive"
            case .unknown:          label = ""   // structurally unreachable (guarded above)
            }
            evidence.append(ExpertEvidenceV2(
                domain: .attentionPressure, labels: [label],
                confidence: 0.5, coverage: 0.6, uncertainty: 0.5,
                temporalScopeMs: input.observationStartMs...max(input.observationStartMs, input.observationEndMs),
                shotID: shot, itemID: item, itemProvisional: provisional,
                provenance: "emotional-register-adapter-v1 (structural register; separate from stance)",
                modelVersion: EmotionalRegisterAdapterV1.version,
                calibrationStatus: .heuristicSupportOnly, generation: gen))
        }

        // ONE observation per item pass (bounded memory; the builder's episode cap bounds the rest).
        let observation = EpisodeObservationV1(
            startMs: input.observationStartMs, endMs: max(input.observationStartMs, input.observationEndMs),
            shotIDs: [shot], evidence: evidence, unknownReasons: unknownReasons,
            sourceText: input.ocrText,             // EPHEMERAL — context-tag heuristics only, never persisted
            sourceLanguage: input.ocrLanguage)

        // FRESH builder per item (no carryover law) → the FROZEN canonical path end-to-end.
        let model = WorldModelBuilderV1(maxEpisodes: 4).build(
            observations: [observation], itemID: item, itemProvisional: provisional,
            identityRevision: UInt64(max(0, input.itemIdentityRevision)), generation: gen,
            nowMs: MonotonicClockV1.nowMs())
        let safety = SafetyPolicyEngineV1.evaluate(worldModel: model)
        return WorldModelBridgeResultV1(worldModel: model, safety: safety, evidenceCount: evidence.count,
                                        unavailableModalities: unavailable,
                                        latencyMs: MonotonicClockV1.nowMs() - t0)
    }
}
