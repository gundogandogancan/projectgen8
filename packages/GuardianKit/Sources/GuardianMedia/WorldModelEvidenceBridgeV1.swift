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
    /// R6 §1.2 — the R4 CONTEXT (stance) verdict carried in as a CANONICAL verdict+provenance. The bridge no longer
    /// re-derives stance from OCR: it carries the already-computed verdict so stance and register stay SEPARATE
    /// evidence dimensions (REPORTS ≠ SAFE, CRITICIZES ≠ NO EMOTIONAL LOAD). nil = adapter did not run.
    public let contextStance: ContextEvidenceVerdictV1?
    /// R6 §4 + addendum — the targeted-pressure / covert-manipulation heuristic verdict (nil = did not run). A
    /// SUPPORTED own-voice pressure finding enters as `attention:` evidence (declared heuristic, like the register).
    public let targetedPressure: TargetedPressureVerdictV1?
    /// R8 §2/§3 — the LIVE audio-event evidence for THIS item (nil = the audio sense did not run on this path). When
    /// it is `.available` with real events, the bridge REPLACES its honest-UNAVAILABLE `.audioEvent` record with a REAL
    /// `.audioEvent` envelope (the classifier's labels + raw confidence + analysis-window provenance). When it is any
    /// UNAVAILABLE/deferred reason — or nil — the bridge keeps `.audioEvent` UNAVAILABLE (no sound ≠ safe, pinned). The
    /// binding is checked by the CALLER against the live generation BEFORE it is passed here (stale audio never enters).
    public let liveAudioEvidence: LiveAudioWindowEvidenceV1?
    /// R6 §1.1 — SINGLE EVIDENCE, MANY DECISIONS. When the caller already ran the four frozen text experts for THIS
    /// item (GeneralContentCharacter's LanguageOCRExpert pass, etc.), it passes their envelopes here so the bridge
    /// REUSES them instead of re-running (no double-count of a text-expert signal through two routes). nil = the
    /// bridge runs the experts itself (the R5 behaviour — kept for the pure bridge tests). The envelopes MUST be the
    /// real frozen-expert outputs for this item; the bridge re-stamps nothing.
    public let precomputedTextEvidence: [ExpertEvidenceV2]?

    public init(sessionID: String, contentID: String, itemIdentityRevision: Int, identityConfirmed: Bool,
                generation: UInt64, shotID: UInt64, observationStartMs: Double, observationEndMs: Double,
                ocrText: String?, ocrLanguage: String?, policyRevision: UInt64, familyProfileRevision: UInt64,
                photoShieldActionableMatch: Bool, emotionalRegister: EmotionalRegisterVerdictV1?,
                contextStance: ContextEvidenceVerdictV1? = nil, targetedPressure: TargetedPressureVerdictV1? = nil,
                liveAudioEvidence: LiveAudioWindowEvidenceV1? = nil,
                precomputedTextEvidence: [ExpertEvidenceV2]? = nil) {
        self.sessionID = sessionID; self.contentID = contentID
        self.itemIdentityRevision = itemIdentityRevision; self.identityConfirmed = identityConfirmed
        self.generation = generation; self.shotID = shotID
        self.observationStartMs = observationStartMs; self.observationEndMs = observationEndMs
        self.ocrText = ocrText; self.ocrLanguage = ocrLanguage
        self.policyRevision = policyRevision; self.familyProfileRevision = familyProfileRevision
        self.photoShieldActionableMatch = photoShieldActionableMatch; self.emotionalRegister = emotionalRegister
        self.contextStance = contextStance; self.targetedPressure = targetedPressure
        self.liveAudioEvidence = liveAudioEvidence
        self.precomputedTextEvidence = precomputedTextEvidence
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

    // R6 §1.1 — DECLARED-HEURISTIC markers (NOT measured calibration). These confidence/coverage numbers are honest
    // placeholders for the derived structural findings (register / targeted-pressure); the real calibration status is
    // carried by `calibrationStatus: .heuristicSupportOnly` on every such record, so the frozen policy never treats
    // them as a calibrated score. Named constants (never inline 0.7/0.5 magic) so the "declared heuristic, not
    // calibration" contract is explicit and auditable (§1.1: "sabit heuristic değerler gerçek kalibrasyon gibi
    // kullanılmamalı").
    static let declaredHeuristicConfidence = 0.5   // declared, not measured — the honest "we have a structural signal"
    static let declaredHeuristicCoverage   = 0.6   // declared coverage of the text modality for a structural finding
    static let declaredHeuristicUncertainty = 0.5  // high residual uncertainty (structural ≠ certain intent)
    static let personalVisualSliceConfidence = 0.5 // a near-exact perceptual match is a narrow OBSERVED slice, declared
    static let personalVisualSliceCoverage   = 0.1 // one tiny observed slice ≠ visual screening (H1 untouched)

    /// R6 §1.1 — run the FOUR frozen text experts ONCE for an item's OCR text and return their envelopes. The caller
    /// (SampleHandler) uses this to produce the SHARED per-item text evidence, then hands it to both its own
    /// interpretation and the bridge's `precomputedTextEvidence` — so a text-expert signal is produced exactly once.
    /// Pure (the experts are pure). Returns [] when there is no text (the bridge then records UNAVAILABLE honestly).
    public static func runTextExperts(ocrText: String?, ocrLanguage: String?, contentID: String,
                                      itemIdentityRevision: Int, identityConfirmed: Bool,
                                      generation: UInt64, shotID: UInt64) -> [ExpertEvidenceV2] {
        guard ocrText?.isEmpty == false else { return [] }
        let item = itemID(for: contentID)
        let (sanitized, _) = ExpertInputSanitizerV2.sanitize(
            ExpertInputV2(ocrText: ocrText, detectedLanguage: ocrLanguage))
        let ctx = ExpertTaskContextV2(observationID: ObservationID(generation), shotID: ShotID(shotID), itemID: item,
                                      itemProvisional: !identityConfirmed,
                                      identityRevision: UInt64(max(0, itemIdentityRevision)),
                                      profile: .extensionFastTier0,
                                      requestedDomains: [.languageOCR, .safetyEvidence, .benefitEvidence,
                                                         .attentionPressure],
                                      generation: generation, cacheEligible: false)
        return [LanguageOCRExpertV1().evaluate(sanitized, context: ctx),
                SafetyEvidenceExpertV1().evaluate(sanitized, context: ctx),
                BenefitEvidenceExpertV1().evaluate(sanitized, context: ctx),
                AttentionPressureExpertV1().evaluate(sanitized, context: ctx)]
    }

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
            if let shared = input.precomputedTextEvidence, !shared.isEmpty {
                // R6 §1.1 — SINGLE EVIDENCE, MANY DECISIONS: the caller already ran the four frozen text experts for
                // this item; REUSE their exact envelopes (no re-run, no double-count through a second route). The
                // envelopes ARE the P009B evidence — nothing is synthesized or re-stamped here.
                evidence.append(contentsOf: shared)
                unknownReasons.append("bridge:reused-shared-text-evidence(\(shared.count))")
            } else {
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
            }
        } else {
            // NO text on this item: the text-derived domains are honestly UNAVAILABLE — never "examined clean".
            for d in [ExpertDomainV2.languageOCR, .safetyEvidence, .benefitEvidence, .attentionPressure] {
                evidence.append(.unavailable(d, reason: "no-ocr-text-on-extension-path", generation: gen))
                unavailable.append(d.rawValue)
            }
            unknownReasons.append("bridge:no-text-evidence")
        }

        // Modalities the extension genuinely does NOT analyze — HONEST UNAVAILABLE, never silence, never "clean".
        // Speech / music / symbol remain UNAVAILABLE on this path (no provider). R8 §2/§3: AUDIO_EVENT is now the ONE
        // seam that may carry a REAL record — WHEN a live SoundAnalysis window was actually analyzed for this item.
        evidence.append(.unavailable(.speech, reason: "no-speech-analysis-on-extension-path", generation: gen))
        evidence.append(.unavailable(.music, reason: "no-music-analysis-on-extension-path", generation: gen))
        evidence.append(.unavailable(.symbol, reason: "no-symbol-provider-on-extension-path", generation: gen))
        unavailable.append(contentsOf: [ExpertDomainV2.speech.rawValue,
                                        ExpertDomainV2.music.rawValue, ExpertDomainV2.symbol.rawValue])

        // R8 §2/§3 — AUDIO EVENT EVIDENCE. The audio sense enters HERE and ONLY as event evidence (no harm score). A
        // live window that genuinely RAN (`senseRan`) with real classifier events replaces the honest-UNAVAILABLE
        // record with a REAL `.audioEvent` envelope: the classifier's labels, RAW model confidence (NEVER a calibrated
        // suitability), the analysis-window PTS span, and classifier-version provenance. `calibrationStatus` stays
        // `.implementedUncalibrated` — a real on-device classifier output, but NOT a calibrated risk score (label ≠
        // harm). Any UNAVAILABLE/deferred reason — or no audio at all — keeps `.audioEvent` UNAVAILABLE: a window that
        // did NOT run is NEVER "audio analyzed clean" (no sound ≠ safe). Each distinct label is one record (bounded by
        // the adapter's small per-item window budget), temporal-scoped to the audio window, bound to THIS generation.
        if let audio = input.liveAudioEvidence, audio.senseRan, !audio.events.isEmpty,
           audio.binding.generation == gen, audio.binding.itemIdentityRevision == input.itemIdentityRevision {
            // Window PTS span (seconds → ms) for the evidence temporal scope; falls back to the observation span when
            // the framework supplied no range (never a fabricated stamp — we use the item observation window instead).
            let winStartMs = (audio.binding.ptsStartSeconds).map { $0 * 1000.0 } ?? input.observationStartMs
            let winEndMs = (audio.binding.ptsEndSeconds).map { $0 * 1000.0 } ?? max(input.observationStartMs, input.observationEndMs)
            for ev in audio.events {
                evidence.append(ExpertEvidenceV2(
                    domain: .audioEvent, labels: ["audio:\(ev.label.lowercased())"],
                    confidence: ev.rawModelConfidence ?? 0,       // RAW classifier confidence — NOT a suitability score
                    coverage: declaredHeuristicCoverage, uncertainty: declaredHeuristicUncertainty,
                    temporalScopeMs: min(winStartMs, winEndMs)...max(winStartMs, winEndMs),
                    shotID: shot, itemID: item, itemProvisional: provisional,
                    provenance: "live-audio-evidence-adapter-v1 (SNAudioStreamAnalyzer SNClassifySoundRequest.version1; raw model confidence, NOT a suitability/harm score; classifier label ≠ psychological harm)",
                    modelVersion: audio.classifierVersion,
                    calibrationStatus: .implementedUncalibrated, generation: gen))
            }
            unknownReasons.append("bridge:audio-event-analyzed(\(audio.events.count))")
        } else {
            // No analyzed audio window for this item (nil / deferred / absent / stale generation) → honest UNAVAILABLE.
            let reason = input.liveAudioEvidence.map { "audio-window-not-analyzed:\($0.availability.rawValue)" }
                ?? "no-audio-analysis-on-extension-path"
            evidence.append(.unavailable(.audioEvent, reason: reason, generation: gen))
            unavailable.append(ExpertDomainV2.audioEvent.rawValue)
        }
        unknownReasons.append("bridge:speech-music-symbol-unavailable")
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
                confidence: personalVisualSliceConfidence, coverage: personalVisualSliceCoverage, uncertainty: declaredHeuristicUncertainty,
                temporalScopeMs: input.observationStartMs...max(input.observationStartMs, input.observationEndMs),
                shotID: shot, itemID: item, itemProvisional: provisional,
                provenance: "photo-shield-luma-matcher-v1 (personal reference; not a safety classifier; declared-heuristic)",
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
                confidence: declaredHeuristicConfidence, coverage: declaredHeuristicCoverage, uncertainty: declaredHeuristicUncertainty,
                temporalScopeMs: input.observationStartMs...max(input.observationStartMs, input.observationEndMs),
                shotID: shot, itemID: item, itemProvisional: provisional,
                provenance: "emotional-register-adapter-v1 (structural register; separate from stance; declared-heuristic)",
                modelVersion: EmotionalRegisterAdapterV1.version,
                calibrationStatus: .heuristicSupportOnly, generation: gen))
        }

        // R6 §1.2 — STANCE as a SEPARATE, canonical carried verdict (NOT re-derived from OCR here). A SUPPORTED stance
        // enters as its own `stance:` evidence with the adapter's provenance, so stance and register remain distinct
        // dimensions in the world model (REPORTS ≠ SAFE, CRITICIZES ≠ NO EMOTIONAL LOAD). This is context provenance
        // — it does NOT itself create a safety class (the register/safety experts carry risk); it records what the
        // speaker's relation to a flagged harm was, for the proof log + downstream non-softening laws.
        if let st = input.contextStance, st.support == .supported, st.stance != .unknown {
            evidence.append(ExpertEvidenceV2(
                domain: .attentionPressure, labels: ["stance:\(st.stance.rawValue.lowercased())"],
                confidence: declaredHeuristicConfidence, coverage: declaredHeuristicCoverage, uncertainty: declaredHeuristicUncertainty,
                temporalScopeMs: input.observationStartMs...max(input.observationStartMs, input.observationEndMs),
                shotID: shot, itemID: item, itemProvisional: provisional,
                provenance: "context-evidence-adapter-v1 (speaker stance; separate from register; declared-heuristic)",
                modelVersion: ContextEvidenceAdapterV1.version,
                calibrationStatus: .heuristicSupportOnly, generation: gen))
        }

        // R6 §4 + addendum — TARGETED PRESSURE / COVERT MANIPULATION as its OWN `attention:` evidence. Only a
        // SUPPORTED, own-voice pressure finding (directed personal demeaning/threat, or a real covert mechanism)
        // produces a label; criticism / 3rd-party / quoted / unknown produce NOTHING (no fabricated modality). This
        // is the canonical manipulation-evidence family — declared heuristic, never an "abuse detector" claim.
        if let tp = input.targetedPressure, let label = TargetedPressureHeuristicV1.evidenceLabel(tp) {
            evidence.append(ExpertEvidenceV2(
                domain: .attentionPressure, labels: [label],
                confidence: declaredHeuristicConfidence, coverage: declaredHeuristicCoverage, uncertainty: declaredHeuristicUncertainty,
                temporalScopeMs: input.observationStartMs...max(input.observationStartMs, input.observationEndMs),
                shotID: shot, itemID: item, itemProvisional: provisional,
                provenance: "targeted-pressure-heuristic-v1 (structural TARGET/ACT/MECHANISM; declared-heuristic)",
                modelVersion: TargetedPressureHeuristicV1.version,
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
