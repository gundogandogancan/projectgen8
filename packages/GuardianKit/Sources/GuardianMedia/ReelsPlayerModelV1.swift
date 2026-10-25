//
//  ReelsPlayerModelV1.swift — B: the headless brain of the GEN8 CONTROLLED REELS PLAYER.
//
//  BIG GOAL (mandate B): GEN8's FIRST real video-playback control. On our OWN AVPlayer surface, playing our OWN
//  local videos, the user's personal-shield rules are honestly applied BEFORE exposure: a matching reel is HIDDEN
//  (player paused, image+audio removed) rather than shown; an unmatched reel plays; a reel we cannot evaluate gets
//  an explicit decision screen (never auto-played as if "safe"). This file is the pure, headless state machine so
//  the whole decision/skip/override/live-reload logic is testable WITHOUT the AVPlayer runtime. The SwiftUI layer
//  owns the real AVPlayer and simply obeys the per-item `PlaybackIntent` this model computes.
//
//  WHY A SEPARATE PURE MODEL (constitution §4 Definition of Done; testability): AVPlayer behaviour (pause, rate,
//  mute, layer removal) is proven by integration tests directly on AVPlayer in GuardianMediaTests. The POLICY —
//  pre-playback gate, stale-decision invalidation, per-item state transitions, content-scoped override, skip
//  safety — is proven HERE, deterministically, with an injected evidence provider + an injected shield store.
//
//  FROZEN APIs CONSUMED (never re-implemented): ShieldEvaluatorV2 (the real decision), PersonalShieldSharedStoreV1
//  (the user's real rules + policyRevision), CrossAppObservationBuilder.envelope (the real envelope the extension
//  uses too), ShieldException (B4 override). Nothing about matching semantics is duplicated.
//
import Foundation
import GuardianCore
#if canImport(AVFoundation)

// MARK: - Per-item lifecycle state (mandate B: pending / evaluating / playing / hidden / skipped / overridden)

/// The honest lifecycle of ONE reel in the controlled queue. Each transition is a REAL engine/user moment.
public enum ReelItemStateV1: String, Sendable, Equatable, Codable {
    case pendingEvaluation = "PENDING_EVALUATION"  // not yet analysed; must NOT auto-play if Hide prefs exist (B1)
    case evaluating        = "EVALUATING"          // pre-exposure analysis in flight (frames+OCR+shield)
    case playing           = "PLAYING"             // evaluated → no hide decision → allowed to play
    case hidden            = "HIDDEN"              // a real HIDE decision applied (B2): paused, image+audio removed
    // C1 — DISTINCT applied-action states, each from the ONE policy decision (never a fake HIDE for a non-hide action).
    case blurred           = "BLURRED"             // BLUR_IF_CONTROLLED: video continues under a real Gaussian blur overlay
    case muted             = "MUTED"               // MUTE_IF_CONTROLLED: audio off (isMuted) + visible indicator; image per policy
    case warned            = "WARNED"              // WARN: a visible warning banner with the real reason; content still plays
    case askUser           = "ASK_USER"            // ASK: an approval gate before exposure (distinct from UNDETERMINED abstention)
    case undetermined      = "UNDETERMINED"        // evidence insufficient → explicit decision screen (B1, never "safe")
    case skipped           = "SKIPPED"             // user skipped (or hidden-then-advanced / SKIP_IF_CONTROLLED) (B3)
    case userOverridden    = "USER_OVERRIDDEN"     // user chose "Show anyway" for THIS content (B4, content-scoped)
}

/// What the AVPlayer surface should DO for the current item. The SwiftUI layer obeys this literally — it is the
/// bridge between the pure policy and the real player. `hide` carries the real reason for the "Why hidden?" copy.
public enum PlaybackIntentV1: Sendable, Equatable {
    case awaitDecision                       // pre-playback gate: do NOT attach player output yet (B1)
    case play                                // attach + play real video/audio
    case hide(reason: GuardianReasonCodeV1)  // pause + remove image/audio + show Guardian shield (B2) — HIDE_IF_CONTROLLED
    // C1 — each remaining intent corresponds to a REAL, implementable action on OUR AVPlayer surface. We never fake
    // an action the surface cannot perform; an unsupported action is mapped honestly to the nearest supported one
    // and the decision's `appliedAction` records what the policy actually asked for.
    case blur(reason: GuardianReasonCodeV1)  // video keeps playing UNDER a real Gaussian blur overlay — BLUR_IF_CONTROLLED
    case mute(reason: GuardianReasonCodeV1)  // audio off (isMuted) + a visible muted indicator — MUTE_IF_CONTROLLED
    case warn(reason: GuardianReasonCodeV1)  // content plays with a visible warning banner (real reason) — WARN
    case skip(reason: GuardianReasonCodeV1)  // a real transition past this item — SKIP_IF_CONTROLLED_AND_ALIGNED
    case askUser(reason: GuardianReasonCodeV1) // explicit decision/approval screen (ASK or UNDETERMINED) (B1)
}

// MARK: - A single reel in the controlled queue (OWNED local media)

/// One controlled reel: a local, project-OWNED video file + its declared metadata + a stable content identity the
/// shield decision is bound to (B4 override is scoped to THIS identity). `contentID` is used both as the shield
/// envelope id and the override key, so an override can never leak to a different reel.
public struct ReelItemV1: Sendable, Equatable, Identifiable {
    public let id: String                 // stable identity (also the ShieldException scope value for B4)
    public let title: String              // declared metadata (known source — NOT image understanding)
    public let url: URL                   // local, app-owned asset
    public let firstFrameSeconds: [Double]// which early timestamps to OCR for pre-exposure analysis
    public let languages: [String]
    public init(id: String, title: String, url: URL, firstFrameSeconds: [Double] = [0.2, 0.6],
                languages: [String] = ["en"]) {
        self.id = id; self.title = title; self.url = url
        self.firstFrameSeconds = firstFrameSeconds; self.languages = languages
    }
}

// MARK: - The resolved decision for one item (honest, fully attributed — mandate C)

/// A complete, honest decision record for ONE reel. Carries content identity + policy revision + evidence
/// provenance + match state + the applied action + the surface capability. NO 0-100 score (constitution rule 8).
public struct ReelDecisionV1: Sendable, Equatable {
    public let contentID: String
    public let policyRevision: UInt64             // the rule-set version this decision was produced under
    public let state: ReelItemStateV1
    public let intent: PlaybackIntentV1
    public let matchState: ShieldMatchState
    public let layerDecision: ShieldLayerDecision
    public let appliedAction: ShieldAction?
    public let matchedRuleID: String?
    public let provenance: ReelsEvidenceProvenanceV1
    public let coverage: Double                   // evaluator coverage (fraction of matchers that ran)
    public let uncertainty: Double                // 0 determinable … 1 non-determinable
    public let reason: GuardianReasonCodeV1
    public let surfaceControlled: Bool            // true here: this is OUR controlled surface (hide may EXECUTE)
    /// §D — HONEST temporal-coverage semantics. `sampleExecutionComplete` means ONLY that every PLANNED sample point
    /// decoded + ran — it does NOT mean "the whole video was examined" (5/5 samples ≠ the whole video). The OLD name
    /// `coverageComplete` wrongly implied the latter; it is kept as a deprecated alias so existing callers/tests still
    /// compile, but the honest field + copy ("5 zaman noktası incelendi", never "video analiz edildi") use this.
    public let sampleExecutionComplete: Bool
    /// §D — temporal coverage is ALWAYS limited for a sampled video: we examine a few timepoints, never every frame.
    /// True whenever there are gaps between examined points (which, for sampling, is essentially always). Surfaced so
    /// a benign result is never presented as "the whole video is safe" — only "the points we examined were clean".
    public let temporalCoverageLimited: Bool
    /// DEPRECATED (§D): retained alias for `sampleExecutionComplete`. Do NOT use in new copy — it reads as "whole
    /// video examined", which is false for sampled analysis. Kept only so pre-existing call sites keep compiling.
    public var coverageComplete: Bool { sampleExecutionComplete }
    /// §7 — the video timestamps (seconds) we actually examined. Lets the UI say WHERE we looked (and, for a HIDE,
    /// attribute the match to the earliest matching sampled time). Empty for the legacy single-frame path.
    public let examinedTimepointsSeconds: [Double]
    /// §E1 — the per-sample timed evidence (timestamp + modality + OCR outcome + the ACTUAL matched rule at that
    /// point, if any). This is the Temporal Evidence Map's source of truth: every match cites the sample it came
    /// from, so two different timepoints can never fuse into one fabricated claim. Empty for the legacy path.
    public let timedEvidence: [ReelsTimedEvidenceV1]
    /// §B2 — the SEPARATED coverage counters (planned/attempted/decoded/ocrExecuted/earlyStopped+reason) this
    /// decision was produced under. The UI copy derives from these; an early-stopped 1/5 is never shown as 5/5.
    public let coverageCounters: ReelsCoverageCountersV1
    public init(contentID: String, policyRevision: UInt64, state: ReelItemStateV1, intent: PlaybackIntentV1,
                matchState: ShieldMatchState, layerDecision: ShieldLayerDecision, appliedAction: ShieldAction?,
                matchedRuleID: String?, provenance: ReelsEvidenceProvenanceV1, coverage: Double,
                uncertainty: Double, reason: GuardianReasonCodeV1, surfaceControlled: Bool,
                coverageComplete: Bool = true, examinedTimepointsSeconds: [Double] = [],
                temporalCoverageLimited: Bool = true, timedEvidence: [ReelsTimedEvidenceV1] = [],
                coverageCounters: ReelsCoverageCountersV1 = .empty) {
        self.contentID = contentID; self.policyRevision = policyRevision; self.state = state; self.intent = intent
        self.matchState = matchState; self.layerDecision = layerDecision; self.appliedAction = appliedAction
        self.matchedRuleID = matchedRuleID; self.provenance = provenance; self.coverage = coverage
        self.uncertainty = uncertainty; self.reason = reason; self.surfaceControlled = surfaceControlled
        self.sampleExecutionComplete = coverageComplete; self.examinedTimepointsSeconds = examinedTimepointsSeconds
        self.temporalCoverageLimited = temporalCoverageLimited; self.timedEvidence = timedEvidence
        self.coverageCounters = coverageCounters
    }
}

// MARK: - The pure decision engine (no AVPlayer, no SwiftUI) — fully unit-testable

/// Produces an honest ReelDecisionV1 from gathered evidence + the user's real rules. Pre-playback gate (B1),
/// stale-decision rules (A1/B2), and UNKNOWN honesty (B1) all live here as PURE functions.
public struct ReelsDecisionEngineV1: Sendable {
    public static let version = "reels-decision-engine-v1"
    private let evaluator: ShieldEvaluatorV2
    public init(evaluator: ShieldEvaluatorV2 = .standard()) { self.evaluator = evaluator }

    /// B1 pre-playback gate: if the user has ANY active HIDE preference and the item is NOT yet evaluated, the
    /// player output must NOT be attached — we must evaluate first. Pure predicate over the loaded rules.
    public static func hasActiveHidePreference(rules: [ShieldRuleV2], nowEpoch: Double) -> Bool {
        rules.contains { $0.isActive(nowEpoch: nowEpoch) && Self.isHideAction($0.action) }
    }

    /// A HIDE-class action is one whose configured intent is to remove the content on a controlled surface.
    public static func isHideAction(_ a: ShieldAction) -> Bool {
        a == .hideIfControlled || a == .blurIfControlled || a == .muteIfControlled || a == .skipIfControlledAndAligned
    }

    /// §E2 — does a SINGLE sample's OCR text verify a match? Runs the frozen evaluator on that text alone (same
    /// semantics as the engine's per-sample pass) and reports a real, determinable, non-excepted match. Used by the
    /// adaptive sampler's early-stop probe so we stop decoding the rest of the plan once a match is proven — never
    /// on a guess. Pure (no state).
    public func sampleMatches(contentID: String, sampleText: String, index: ShieldIndex,
                              exceptions: [ShieldException], languages: [String],
                              nowEpoch: Double, userInitiated: Bool) -> Bool {
        sampleMatchOutcome(contentID: contentID, sampleText: sampleText, index: index, exceptions: exceptions,
                           languages: languages, nowEpoch: nowEpoch, userInitiated: userInitiated).matchState.isMatch
    }

    /// §D2 — the full per-sample outcome (not just a boolean) so the early-stop probe can compare the matched sample's
    /// ACTION against the active rule set's strongest possible action. Returns `.clear` for an excepted/no match.
    public func sampleMatchOutcome(contentID: String, sampleText: String, index: ShieldIndex,
                                   exceptions: [ShieldException], languages: [String],
                                   nowEpoch: Double, userInitiated: Bool) -> PersonalShieldDecision {
        guard !sampleText.isEmpty else { return .clear }
        var env = CrossAppObservationBuilder.envelope(contentID: contentID, ocrText: sampleText,
                                                      soundEvents: [], languages: languages)
        env.surfaceCapabilityTier = "C5"
        let outcome = evaluator.evaluate(.init(envelope: env, controlledSurface: true, userInitiated: userInitiated,
                                               nowEpoch: nowEpoch), index: index, exceptions: exceptions)
        return (outcome.matchState.isMatch && !outcome.exceptionApplied) ? outcome : .clear
    }

    /// §D2 — the POLICY-PRIORITY SEVERITY of a ShieldAction on OUR controlled surface. Ordinal only (never a 0-100
    /// score): the stronger the intended intervention, the higher the ordinal. Used to decide whether an early-stop
    /// match is already the STRONGEST possible action for the active rules — if a stronger action could still be
    /// matched by a later sample (e.g. a HIDE rule exists but this sample only matched a WARN), we must NOT early-stop.
    public static func actionSeverity(_ a: ShieldAction?) -> Int {
        switch a {
        case .none, .allow, .allowWithNote: return 0
        case .warn:                         return 1
        case .ask:                          return 2
        case .muteIfControlled:             return 3
        case .blurIfControlled:             return 4
        case .skipIfControlledAndAligned:   return 5
        case .hideIfControlled:             return 6
        }
    }

    /// §D2 — the STRONGEST action any ACTIVE rule in the index could possibly apply. The early-stop law compares a
    /// matched sample's action against this: early-stop is permitted only when the matched action already equals the
    /// maximum possible, so a later HIDE can never be pre-empted by an earlier WARN.
    static func maxActiveActionSeverity(_ index: ShieldIndex, nowEpoch: Double) -> Int {
        index.rules.values
            .filter { $0.isActive(nowEpoch: nowEpoch) }
            .map { actionSeverity($0.action) }
            .max() ?? 0
    }

    /// Evaluate ONE item's evidence against the user's rules on OUR controlled surface, honestly. The returned
    /// decision's `intent` is what the AVPlayer layer obeys. `userInitiated` is passed through so a B4 override
    /// exception can legitimately allow the content.
    public func decide(item: ReelItemV1, evidence: ReelsEvidenceV1, index: ShieldIndex,
                       exceptions: [ShieldException], policyRevision: UInt64, nowEpoch: Double,
                       userInitiated: Bool) -> ReelDecisionV1 {
        // §B1 — PER-UNIT AUTHORITATIVE DECISION. The old code ran the frozen evaluator over the FUSED combined text
        // (metadata + every sample's OCR joined with spaces) and let THAT be the authority. That is the B1 defect: a
        // phrase whose halves appear in two DIFFERENT evidence units ('spo' at t1, 'iler' at t2) could fuse into a
        // match no single unit supports — a fabricated match. The fix: the FINAL decision's applicability derives
        // ONLY from INDIVIDUALLY-VERIFIED evidence units. We evaluate each unit (metadata alone + each decoded
        // sample's OWN text alone) against the SAME frozen evaluator, and the AUTHORITATIVE outcome is the STRONGEST
        // real, non-excepted match among those units. The fused string is used ONLY to WIDEN the display evidence,
        // never to create a match — so cross-unit concatenation can never produce an action.
        //
        // Each evidence unit, carrying its origin so provenance + timed attribution stay honest. §E — audio is a unit
        // of its OWN modality (soundEvents), evaluated SEPARATELY so a sound-class match and an OCR match never fuse
        // into one fabricated claim (E1/E3): each unit cites exactly which sense supported it.
        struct UnitV1 { let text: String; let soundEvents: [String]; let timestamp: Double?; let modality: ReelsEvidenceModalityV1?; let isMetadata: Bool }
        var units: [UnitV1] = []
        if !evidence.metadataText.isEmpty {
            units.append(UnitV1(text: evidence.metadataText, soundEvents: [], timestamp: nil, modality: nil, isMetadata: true))
        }
        for rec in evidence.timedRecords where rec.ocrStatus == .ran && !rec.text.isEmpty {
            units.append(UnitV1(text: rec.text, soundEvents: [], timestamp: rec.timestampSeconds, modality: rec.modality, isMetadata: false))
        }
        // Legacy single-frame path (no timed records): fall back to the whole OCR text as ONE unit (it was one frame).
        if evidence.timedRecords.isEmpty, !evidence.ocrText.isEmpty {
            units.append(UnitV1(text: evidence.ocrText, soundEvents: [], timestamp: nil, modality: .visualOCR, isMetadata: false))
        }
        // §E/§D — the AUDIO unit: the REAL distinct classifier labels become a sound-event envelope the frozen
        // SoundClassMatcher evaluates against the user's `.soundClass` rules. Only present when the audio sense RAN and
        // produced labels — absence/UNAVAILABLE adds NO unit (absence ≠ silence; coverage narrows elsewhere, never a
        // fake "clean"). This is a SEPARATE unit so a sound match is attributable to the audio sense alone (E1/E3).
        let audioLabels = evidence.audioLabels
        if !audioLabels.isEmpty {
            units.append(UnitV1(text: "", soundEvents: audioLabels, timestamp: nil, modality: .audioEvent, isMetadata: false))
        }
        func evaluateUnit(_ text: String, soundEvents: [String] = []) -> PersonalShieldDecision {
            var e = CrossAppObservationBuilder.envelope(contentID: item.id, ocrText: text,
                                                        soundEvents: soundEvents, languages: evidence.languages)
            e.surfaceCapabilityTier = "C5"
            // §E/§D — SHORTLIST BRIDGE (frozen-core aware). The FROZEN ShieldIndex.shortlist keys candidate rules on the
            // envelope's TEXT tokens + source, NOT on soundEvents — so a `.soundClass` rule (indexed by its label token,
            // e.g. "siren") would never be shortlisted for an audio-only unit whose OCR text is empty, and the frozen
            // SoundClassMatcher would never get the chance to run. We cannot edit the frozen index, so we surface the
            // REAL classifier labels as STRUCTURED TEXT purely so shortlist can find the sound rule. This does NOT
            // fabricate a text match: the `.soundClass` rule's `effectiveMatchers` is `[.soundClass]` ONLY, so the
            // ExactTextMatcher never evaluates it — the actual verdict still comes from the SoundClassMatcher matching
            // the real `soundEvents`. The label text is derived from the real classifier output, never invented.
            if !soundEvents.isEmpty {
                e.structuredText = (e.structuredText) + [TextSource(origin: .structured, text: soundEvents.joined(separator: " "))]
            }
            return evaluator.evaluate(.init(envelope: e, controlledSurface: true, userInitiated: userInitiated,
                                            nowEpoch: nowEpoch), index: index, exceptions: exceptions)
        }
        // The authoritative outcome: the STRONGEST per-unit verdict. A unit's match counts only if it is a real match
        // (isMatch) OR a genuine non-determinable signal (abstention must still surface as UNKNOWN, not be dropped).
        // We rank determinable matches by matchRank; a non-determinable unit is kept only if NO determinable match
        // exists (so abstention never outranks a real verdict, per the frozen evaluator's own ordering).
        var authoritative = PersonalShieldDecision.clear
        var sawNonDeterminable = false
        if units.isEmpty {
            // No evidence units at all → run the evaluator once with nil text so it yields the honest no-evidence
            // outcome the no-evidence branch below relies on (a HIDE-pref user then gets an explicit ask).
            authoritative = evaluateUnit("")
        } else {
            // §E2 — CONFLICT DETECTION ACROSS MODALITIES. We track whether any unit produced a real HIDE-class match and
            // whether any produced a genuine CLEAR verdict on the SAME content. The frozen evaluator's strongest-match
            // authority already picks the hide (precedence), but we additionally surface when two modalities genuinely
            // DISAGREE so the decision can be marked UNKNOWN rather than silently trusting one sense over the other.
            var sawRealMatch = false
            for u in units {
                let o = evaluateUnit(u.text, soundEvents: u.soundEvents)
                if o.matchState.isNonDeterminable { sawNonDeterminable = true }
                if o.matchState.isMatch && !o.exceptionApplied { sawRealMatch = true }
                // Prefer a stronger REAL match; otherwise prefer a determinable over a non-determinable authority.
                let better = o.matchState.matchRank > authoritative.matchState.matchRank
                if better { authoritative = o }
            }
            _ = sawRealMatch
            // If we only ever saw non-determinable signals and no real match, surface the first non-determinable
            // outcome (not the synthetic .clear) so the UNKNOWN branch fires honestly.
            if !authoritative.matchState.isMatch && sawNonDeterminable {
                if let firstND = units.map({ evaluateUnit($0.text, soundEvents: $0.soundEvents) }).first(where: { $0.matchState.isNonDeterminable }) {
                    authoritative = firstND
                }
            }
        }
        let outcome = authoritative
        // §E1 — PER-SAMPLE timed evidence. Each decoded sample's OWN text is evaluated ALONE and the matched rule is
        // stamped onto that sample's record — so the Temporal Evidence Map cites the REAL timepoint each match came
        // from and can never show a match no single sample supports (identical evaluation the authority used above).
        var timedEvidence: [ReelsTimedEvidenceV1] = evidence.timedRecords.map { rec in
            guard rec.ocrStatus == .ran, !rec.text.isEmpty else { return rec }
            let sampleOutcome = evaluateUnit(rec.text)
            let matched = (sampleOutcome.matchState.isMatch && !sampleOutcome.exceptionApplied) ? sampleOutcome.ruleID : nil
            return ReelsTimedEvidenceV1(timestampSeconds: rec.timestampSeconds, modality: rec.modality,
                                        ocrStatus: rec.ocrStatus, text: rec.text, matchedRuleID: matched)
        }
        // §D3/§E1/§G — AUDIO timed evidence. Each REAL classifier event becomes its OWN `.audioEvent` record so the
        // İçerik Kanıtı sheet's SES layer shows exactly which sound events we heard, at the REAL time range the
        // framework supplied (or no stamp when it supplied none — never fabricated). The `text` field carries the
        // classifier LABEL (the audio analogue of OCR text; it is NOT raw audio and NOT a transcript). A per-event
        // shield pass stamps the matched `.soundClass` rule id so an audio match is attributable to the right sense.
        if let audio = evidence.audio, audio.senseRan {
            for ev in audio.events {
                let o = evaluateUnit("", soundEvents: [ev.label])
                let matched = (o.matchState.isMatch && !o.exceptionApplied) ? o.ruleID : nil
                timedEvidence.append(ReelsTimedEvidenceV1(timestampSeconds: ev.startSeconds ?? -1,
                                                          modality: .audioEvent, ocrStatus: .ran,
                                                          text: ev.label, matchedRuleID: matched))
            }
        }
        // §D — HONEST temporal-coverage facts. `sampleExecutionComplete` = every PLANNED sample decoded+ran (NOT
        // "whole video examined"). `temporalCoverageLimited` = there are gaps between sampled points (true for any
        // sampled analysis with ≥1 gap, i.e. essentially always) — so a benign result is scoped to examined points.
        let coverageComplete = !evidence.partialCoverage
        let examined = evidence.sampledTimepointsSeconds
        // Temporal coverage is ALWAYS limited for sampled analysis: we examine a handful of timepoints, never every
        // frame. This is a standing honesty law (not a per-run computation) — a clean sampled result means only "the
        // points we examined were clean", never "the whole video is safe". A legacy single-frame path (no timed
        // records) is even MORE limited. Hence: always true whenever we sampled rather than decoded every frame.
        let temporalCoverageLimited = true

        // Map the frozen outcome → an HONEST player intent + lifecycle state. Mandate C1: preserve REAL ShieldAction
        // semantics — the ONE policy decision (`outcome`) dictates the action; we never collapse every match to HIDE.
        // §7: a match at ANY sampled timepoint (start OR mid OR end) triggers it BEFORE playback (combinedText fuses).
        //
        // (1a) layerDecision == .execute → the configured action may run on our controlled surface. We branch on the
        //      REAL `actionRecommendation` so HIDE / BLUR / MUTE / SKIP each produce their OWN intent + state. A nil
        //      recommendation under .execute (should not happen for a real match) falls back to the honest HIDE.
        let realHit = outcome.matchState.isMatch && outcome.layerDecision == .execute && !outcome.exceptionApplied
        if realHit {
            func decision(_ state: ReelItemStateV1, _ intent: PlaybackIntentV1, _ reason: GuardianReasonCodeV1) -> ReelDecisionV1 {
                ReelDecisionV1(contentID: item.id, policyRevision: policyRevision, state: state, intent: intent,
                               matchState: outcome.matchState, layerDecision: outcome.layerDecision,
                               appliedAction: outcome.actionRecommendation, matchedRuleID: outcome.ruleID,
                               provenance: evidence.provenance, coverage: outcome.coverage,
                               uncertainty: outcome.uncertainty, reason: reason, surfaceControlled: true,
                               coverageComplete: coverageComplete, examinedTimepointsSeconds: examined,
                               temporalCoverageLimited: temporalCoverageLimited, timedEvidence: timedEvidence,
                               coverageCounters: evidence.planCounters)
            }
            switch outcome.actionRecommendation {
            case .blurIfControlled:
                // Real on-surface Gaussian blur overlay (the view implements it over the AVPlayerLayer): video + audio
                // continue, the image is obscured. A genuinely implementable action → not downgraded.
                return decision(.blurred, .blur(reason: .shieldBlurApplied), .shieldBlurApplied)
            case .muteIfControlled:
                return decision(.muted, .mute(reason: .shieldMuteApplied), .shieldMuteApplied)
            case .skipIfControlledAndAligned:
                return decision(.skipped, .skip(reason: .shieldSkipApplied), .shieldSkipApplied)
            case .hideIfControlled:
                return decision(.hidden, .hide(reason: .textEvidenceMatchedShield), .textEvidenceMatchedShield)
            case .ask:
                // A rule configured to ASK that reached execute (exact/high match): honour the approval gate honestly.
                return decision(.askUser, .askUser(reason: .shieldAskApproval), .shieldAskApproval)
            case .warn, .allow, .allowWithNote, .none:
                // .execute with a non-HIDE-class recommendation (e.g. a rule configured to WARN that reached execute,
                // or a nil recommendation): honour it as a visible WARN on our surface, never a fabricated HIDE.
                return decision(.warned, .warn(reason: .shieldWarnApplied), .shieldWarnApplied)
            }
        }
        // (1b) A real match whose layer decision is WARN or ASK (a MEDIUM match softens a destructive action to ASK;
        //      a non-destructive action WARNs). These are REAL, distinct surfaces — not HIDE, not "safe".
        if outcome.matchState.isMatch && !outcome.exceptionApplied {
            switch outcome.layerDecision {
            case .warn, .note:
                return ReelDecisionV1(contentID: item.id, policyRevision: policyRevision, state: .warned,
                                      intent: .warn(reason: .shieldWarnApplied),
                                      matchState: outcome.matchState, layerDecision: outcome.layerDecision,
                                      appliedAction: outcome.actionRecommendation, matchedRuleID: outcome.ruleID,
                                      provenance: evidence.provenance, coverage: outcome.coverage,
                                      uncertainty: outcome.uncertainty, reason: .shieldWarnApplied, surfaceControlled: true,
                                      coverageComplete: coverageComplete, examinedTimepointsSeconds: examined,
                                      temporalCoverageLimited: temporalCoverageLimited, timedEvidence: timedEvidence,
                                      coverageCounters: evidence.planCounters)
            case .ask:
                return ReelDecisionV1(contentID: item.id, policyRevision: policyRevision, state: .askUser,
                                      intent: .askUser(reason: .shieldAskApproval),
                                      matchState: outcome.matchState, layerDecision: outcome.layerDecision,
                                      appliedAction: outcome.actionRecommendation, matchedRuleID: outcome.ruleID,
                                      provenance: evidence.provenance, coverage: outcome.coverage,
                                      uncertainty: outcome.uncertainty, reason: .shieldAskApproval, surfaceControlled: true,
                                      coverageComplete: coverageComplete, examinedTimepointsSeconds: examined,
                                      temporalCoverageLimited: temporalCoverageLimited, timedEvidence: timedEvidence,
                                      coverageCounters: evidence.planCounters)
            default:
                break   // .execute handled above; .noShieldAction/.noShieldDecision fall through
            }
        }
        // 2) Non-determinable evidence (matcher unavailable / matchability unknown / conflict) while the user HAS
        //    hide prefs → UNDETERMINED: an explicit decision screen, NEVER auto-played as safe (B1, rule 7).
        //    Also: a HIDE-pref user with NO usable evidence at all gets the same honest ask.
        let nonDeterminable = outcome.matchState.isNonDeterminable
        let noEvidence = evidence.provenance == .none
        if nonDeterminable || (noEvidence && Self.indexHasHidePreference(index, nowEpoch: nowEpoch)) {
            let reason: GuardianReasonCodeV1 = noEvidence ? .textEvidenceUnavailable : .visualEvidenceInsufficient
            return ReelDecisionV1(contentID: item.id, policyRevision: policyRevision, state: .undetermined,
                                  intent: .askUser(reason: reason),
                                  matchState: outcome.matchState, layerDecision: outcome.layerDecision,
                                  appliedAction: outcome.actionRecommendation, matchedRuleID: outcome.ruleID,
                                  provenance: evidence.provenance, coverage: outcome.coverage,
                                  uncertainty: outcome.uncertainty, reason: reason, surfaceControlled: true,
                                  coverageComplete: coverageComplete, examinedTimepointsSeconds: examined,
                                  temporalCoverageLimited: temporalCoverageLimited, timedEvidence: timedEvidence,
                                  coverageCounters: evidence.planCounters)
        }
        // 3) Evaluated, no hide signal (or an exception/override allowed it) → PLAY. If an exception applied via a
        //    user override, record the overridden state so the UI can show "you chose to show this". §7: when the
        //    sampled coverage was PARTIAL, the benign result is scoped — the reason stays benign (it plays) but
        //    coverageComplete=false lets the UI say honestly "başlangıç/orta/son incelendi" vs "tam değil".
        let state: ReelItemStateV1 = outcome.exceptionApplied ? .userOverridden : .playing
        return ReelDecisionV1(contentID: item.id, policyRevision: policyRevision, state: state, intent: .play,
                              matchState: outcome.matchState, layerDecision: outcome.layerDecision,
                              appliedAction: outcome.actionRecommendation, matchedRuleID: outcome.ruleID,
                              provenance: evidence.provenance, coverage: outcome.coverage,
                              uncertainty: outcome.uncertainty, reason: .textEvidenceBenign,
                              surfaceControlled: true,
                              coverageComplete: coverageComplete, examinedTimepointsSeconds: examined,
                              temporalCoverageLimited: temporalCoverageLimited, timedEvidence: timedEvidence,
                              coverageCounters: evidence.planCounters)
    }

    /// Does the live index contain any ACTIVE hide-class rule? Used so a no-evidence item only triggers the
    /// explicit decision screen when the user actually relies on hiding (otherwise there's nothing to gate on).
    static func indexHasHidePreference(_ index: ShieldIndex, nowEpoch: Double) -> Bool {
        index.rules.values.contains { $0.isActive(nowEpoch: nowEpoch) && isHideAction($0.action) }
    }
}

// MARK: - The observable queue model (MainActor; owns state, drives the SwiftUI player)

/// The player queue model the SwiftUI view binds to. Holds per-item states, the current decision, and the live
/// policy revision. All intelligence is delegated to ReelsDecisionEngineV1 + the frozen store; this is the
/// orchestration + state layer (still testable: it takes an injected store + evidence provider).
@MainActor
public final class ReelsPlayerModelV1 {
    public let items: [ReelItemV1]
    private let store: PersonalShieldSharedStoreV1
    private let evidenceProvider: any ReelsEvidenceProviding
    /// §D/§H — the AUDIO evidence provider (Apple Sound Analysis). Injectable so the fusion/coverage logic is testable
    /// with a deterministic stub. nil ⇒ audio sense disabled for this model (vision-only; honest, not "silent/safe").
    private let audioProvider: (any ReelsAudioEvidenceProviding)?
    private let engine: ReelsDecisionEngineV1
    private let clock: @Sendable () -> Double

    // Live policy snapshot (reloaded on demand / on policy-revision change — A1).
    private var index = ShieldIndex()
    private var rules: [ShieldRuleV2] = []
    private var baseExceptions: [ShieldException] = []
    public private(set) var policyRevision: UInt64 = 0
    public private(set) var sharedContainerActive = false

    // B4 — content-scoped overrides: ruleID→exception are keyed to a SPECIFIC content id so "Show anyway" on one
    // reel can never leak to another. Stored per content id; cleared when policy changes (a new rule-set may mean
    // the user no longer wants that exception).
    private var overrides: [String: Bool] = [:]   // contentID → user chose to show it

    // Per-item observable state.
    public private(set) var states: [String: ReelItemStateV1] = [:]
    public private(set) var decisions: [String: ReelDecisionV1] = [:]
    public private(set) var currentIndex: Int = 0

    // §3 — ASYNC SAFETY (pure, testable). A monotonic evaluation GENERATION advances on EVERY event that supersedes
    // an in-flight evaluation: swipe/advance, skip, policy change, a new session. `evaluateGuarded(_:)` captures the
    // generation before awaiting evidence and REJECTS its own result if the generation moved while it was in flight
    // — so A's late decision can never be applied as B's. This proves the policy-level guard the app player obeys.
    public private(set) var evaluationGeneration: UInt64 = 0
    /// Advance the generation — call on any event that invalidates in-flight evaluations (swipe/skip/rule-change/
    /// new-session). Returns the new generation. `advance(by:)`, `skipCurrent()`, and policy invalidation call this.
    @discardableResult
    public func bumpEvaluationGeneration() -> UInt64 { evaluationGeneration &+= 1; return evaluationGeneration }

    // §A1 — THE EVIDENCE-VALIDITY EPOCH, SPLIT FROM NAVIGATION GENERATION. The old defect: the prefetch cache token
    // carried `evaluationGeneration`, which `advance(by:)` bumps on EVERY cursor move. So a NORMAL A→B swipe advanced
    // the generation and the freshly-minted revalidation token for B could never equal the token B was prefetched
    // under — a valid, still-correct pre-exposure decision was REJECTED as a false cache miss, forcing a needless
    // re-decode+re-OCR on the hottest path. The fix separates TWO genuinely different concepts:
    //   • evaluationGeneration (navigation/presentation authority) — "which item is on screen RIGHT NOW is allowed to
    //     drive the player". A→B must supersede A's in-flight evaluate, so this still bumps on every cursor move. It
    //     governs the SUPERSEDE guard inside evaluatePrefetch/evaluateGuarded (A's late decision never reaches B).
    //   • evidenceEpoch (evidence/policy validity) — "is a previously-computed decision for THIS content still VALID".
    //     A plain A→B navigation does NOT invalidate B's already-correct evidence, so this does NOT bump on cursor
    //     moves. It bumps ONLY on events that genuinely change what the right answer for a reel would be: a policy/
    //     rule-set change, an override/exception-state change, or a new session. The prefetch cache token keys on
    //     THIS, so a normal swipe is a real CACHE HIT (acceptance #1/#2) while a rule change is still a correct MISS.
    public private(set) var evidenceEpoch: UInt64 = 0
    /// §A1 — advance the EVIDENCE epoch. Call ONLY when a previously-valid pre-exposure decision becomes stale: a
    /// policy-revision change, an override/exception change, or a new session. NEVER on a plain cursor move. Returns
    /// the new epoch. Separate from `bumpEvaluationGeneration()` (navigation), which still fires on every swipe.
    @discardableResult
    public func bumpEvidenceEpoch() -> UInt64 { evidenceEpoch &+= 1; return evidenceEpoch }

    /// The outcome of a GUARDED evaluation: either the fresh decision (still authoritative) or an explicit rejection
    /// because a newer event superseded this evaluation while its evidence was being gathered.
    public enum GuardedEvaluationV1: Sendable, Equatable {
        case applied(ReelDecisionV1)
        case superseded(contentID: String, capturedGeneration: UInt64, liveGeneration: UInt64)
    }

    public init(items: [ReelItemV1], store: PersonalShieldSharedStoreV1,
                evidenceProvider: any ReelsEvidenceProviding = ReelsEvidenceProviderV1(),
                audioProvider: (any ReelsAudioEvidenceProviding)? = ReelsAudioEvidenceProviderV1(),
                engine: ReelsDecisionEngineV1 = ReelsDecisionEngineV1(),
                clock: @escaping @Sendable () -> Double = { Date().timeIntervalSince1970 }) {
        self.items = items; self.store = store; self.evidenceProvider = evidenceProvider
        self.audioProvider = audioProvider
        self.engine = engine; self.clock = clock
        for it in items { states[it.id] = .pendingEvaluation }
        reloadPolicy()
    }

    public var currentItem: ReelItemV1? { items.indices.contains(currentIndex) ? items[currentIndex] : nil }
    public func state(of id: String) -> ReelItemStateV1 { states[id] ?? .pendingEvaluation }
    public func decision(of id: String) -> ReelDecisionV1? { decisions[id] }

    /// §E2 — build a per-sample EARLY-STOP probe bound to a SNAPSHOT of the live rules + exceptions. The provider
    /// calls it with each decoded sample's OCR text; it runs the FROZEN evaluator on that text alone and returns true
    /// only on a REAL, determinable, non-excepted match — so early-stop fires exclusively on a verified match, never
    /// a guess. The snapshot is captured now (value types) so the Sendable closure is race-free.
    private func makeEarlyStopProbe(for item: ReelItemV1, userInitiated: Bool,
                                    exceptions: [ShieldException]) -> ReelsSampleMatchProbe {
        let idx = index
        let evaluator = engine
        let contentID = item.id
        let langs = item.languages
        let now = clock()
        // §D2 — the strongest action the ACTIVE rules could ever apply. Captured once (value) for the Sendable closure.
        let maxSeverity = ReelsDecisionEngineV1.maxActiveActionSeverity(idx, nowEpoch: now)
        return { sampleText in
            guard !sampleText.isEmpty else { return false }
            let outcome = evaluator.sampleMatchOutcome(contentID: contentID, sampleText: sampleText, index: idx,
                                                       exceptions: exceptions, languages: langs,
                                                       nowEpoch: now, userInitiated: userInitiated)
            guard outcome.matchState.isMatch else { return false }
            // §D2 POLICY-PRIORITY LAW: only stop early if THIS match already carries the STRONGEST possible action for
            // the active rule set. If a stronger action (e.g. a HIDE rule) could still be matched by a later sample,
            // we keep sampling — an early WARN must never pre-empt a later HIDE. Equality (matched == max) means no
            // stronger verdict is reachable, so stopping is safe. A MEDIUM match softens to ASK via the controller, so
            // we compare the EFFECTIVE recommended action, not the raw rule action.
            return ReelsDecisionEngineV1.actionSeverity(outcome.actionRecommendation) >= maxSeverity
        }
    }

    /// §E/§H — does the user have ANY active sound-class/audio rule? If not, the audio sense adds nothing to THIS
    /// user's decision, so we skip the (heavier) audio analysis entirely — honest resource economy, and we never
    /// gather a sense the user's policy can't act on. Pure read of the live index.
    private func hasActiveAudioRule(nowEpoch: Double) -> Bool {
        index.rules.values.contains { r in
            r.isActive(nowEpoch: nowEpoch) && (r.inputType == .soundClass || r.inputType == .audioReference)
        }
    }

    /// §H — PREFETCH/ANALYSIS ORDER: cheap visual FIRST, then audio ONLY if (a) an audio provider exists, (b) the user
    /// has an audio rule to act on, and (c) thermal budget allows (critical pressure DEFERS audio honestly). Audio runs
    /// OFF the MainActor (the provider's analyze is synchronous SoundAnalysis work) via a detached utility Task, so the
    /// UI never blocks (mandate H: no heavy SoundAnalysis synchronously on MainActor). The result is MERGED onto the
    /// visual evidence with its OWN provenance (never fused into the visual facts). Cancellation is honoured (a
    /// superseding swipe/policy change cancels the enclosing evaluate, and the audio Task observes Task.isCancelled).
    private func gatherEvidenceWithAudio(for item: ReelItemV1, visual: ReelsEvidenceV1,
                                         thermal: ReelsThermalBucketV1) async -> ReelsEvidenceV1 {
        guard let audioProvider, hasActiveAudioRule(nowEpoch: clock()) else { return visual }
        if thermal == .critical {
            // §H — defer under critical thermal pressure: attach an honest UNAVAILABLE(DEFERRED) audio bundle so the
            // coverage narrows (audio not run) — never a fabricated clean audio result.
            return visual.withAudio(.unavailable(.deferredThermal, classifierVersion: ReelsAudioEvidenceProviderV1.version))
        }
        let url = item.url
        // Run the synchronous SoundAnalysis work OFF the MainActor so the player stays smooth (H). The provider itself
        // observes Task.isCancelled; a superseding foreground event cancels the enclosing evaluate Task which propagates.
        let audio = await Task.detached(priority: .utility) { () -> ReelsAudioEvidenceV1 in
            await audioProvider.gatherAudioEvidence(url: url, thermal: thermal)
        }.value
        return visual.withAudio(audio)
    }

    /// A1 — reload the user's live rules + policy revision from the shared store. Called at init and whenever the
    /// shared policyRevision advances (the SwiftUI layer polls this on the 1s heartbeat cadence). Returns true if
    /// the revision CHANGED (so the caller can invalidate + re-evaluate the current item without a restart).
    @discardableResult
    public func reloadPolicy() -> Bool {
        let loaded = store.loadPolicy()
        let changed = loaded.policyRevision != policyRevision || index.count != loaded.index.count
        index = loaded.index; rules = loaded.rules; baseExceptions = loaded.exceptions
        policyRevision = loaded.policyRevision; sharedContainerActive = loaded.sharedContainerActive
        if changed {
            overrides.removeAll()        // a rule change invalidates prior per-content overrides (B2/A1)
            bumpEvidenceEpoch()          // §A1 — a real rule-set change makes every prior decision's evidence stale
        }
        return changed
    }

    /// A1 — poll the shared policyRevision cheaply (no full load). If it advanced, reload + invalidate the current
    /// decision so the UI re-evaluates. Returns true when a reload happened.
    @discardableResult
    public func pollPolicyRevisionAndInvalidateIfChanged() -> Bool {
        guard store.policyRevision != policyRevision else { return false }
        _ = reloadPolicy()
        bumpEvaluationGeneration()   // §3 — a rule change supersedes any in-flight evaluate under the old policy
        // Invalidate decisions made under the OLD revision; mark their items pending so they re-evaluate.
        for (id, d) in decisions where PersonalShieldLoadedPolicyV1.isStaleDecision(stamped: d.policyRevision, liveRevision: policyRevision) {
            decisions[id] = nil
            if states[id] != .skipped { states[id] = .pendingEvaluation }
        }
        return true
    }

    /// B1 — the pre-playback gate. If the user has an active HIDE preference and this item is still pending, the
    /// AVPlayer layer must await the decision (don't attach output). Pure read; no side effects.
    public func mustGateBeforePlay(_ id: String) -> Bool {
        guard state(of: id) == .pendingEvaluation else { return false }
        return ReelsDecisionEngineV1.hasActiveHidePreference(rules: rules, nowEpoch: clock())
    }

    /// Evaluate ONE item end-to-end: gather honest pre-exposure evidence → run the frozen shield pass → record the
    /// decision + lifecycle state. Idempotent per revision: re-evaluating under the same revision recomputes.
    /// `userInitiated` carries a B4 override through to the evaluator (so an exception can allow the content).
    @discardableResult
    public func evaluate(_ item: ReelItemV1) async -> ReelDecisionV1 {
        states[item.id] = .evaluating
        let userInitiated = overrides[item.id] == true
        let exceptions = baseExceptions + overrideExceptions(for: item.id)
        // §E2 — adaptive, budgeted, thermal-aware sampling with early-stop on a verified per-sample match.
        let probe = makeEarlyStopProbe(for: item, userInitiated: userInitiated, exceptions: exceptions)
        let thermal = ReelsEvidenceProviderV1.liveThermalBucket()
        let visual = await evidenceProvider.gatherEvidenceAdaptive(url: item.url, metadataTitle: item.title,
                                                                   firstFrameSeconds: item.firstFrameSeconds,
                                                                   languages: item.languages,
                                                                   thermal: thermal, earlyStopProbe: probe)
        // §H — cheap visual first, then audio (only if an audio rule exists + budget allows), merged with its own provenance.
        let evidence = await gatherEvidenceWithAudio(for: item, visual: visual, thermal: thermal)
        let decision = engine.decide(item: item, evidence: evidence, index: index, exceptions: exceptions,
                                     policyRevision: policyRevision, nowEpoch: clock(), userInitiated: userInitiated)
        decisions[item.id] = decision
        states[item.id] = decision.state
        return decision
    }

    /// §3 — GUARDED evaluation. Captures the current evaluation generation, gathers evidence (async), and only
    /// COMMITS the decision to `decisions`/`states` if the generation is UNCHANGED when the evidence returns. If a
    /// swipe/skip/rule-change advanced the generation mid-flight, the result is `.superseded` and is NOT recorded —
    /// the stale decision can never become the item's state (the app player then refuses any playback command too).
    /// `userInitiated` carries a B4 override (the generation is NOT bumped by an override; it re-evaluates the SAME
    /// item, so a concurrent swipe still supersedes it correctly).
    @discardableResult
    public func evaluateGuarded(_ item: ReelItemV1) async -> GuardedEvaluationV1 {
        let captured = evaluationGeneration
        // Capture the PRIOR cached state so a superseded evaluation can RESTORE it — the transient .evaluating marker
        // must never linger in the cache after a supersede (C2: stale write dropped from the cache, not just the
        // player). We only show .evaluating while this generation is still authoritative.
        let priorState = states[item.id]
        states[item.id] = .evaluating
        let userInitiatedPre = overrides[item.id] == true
        let exceptionsPre = baseExceptions + overrideExceptions(for: item.id)
        let probe = makeEarlyStopProbe(for: item, userInitiated: userInitiatedPre, exceptions: exceptionsPre)
        let thermal = ReelsEvidenceProviderV1.liveThermalBucket()
        let visual = await evidenceProvider.gatherEvidenceAdaptive(url: item.url, metadataTitle: item.title,
                                                                   firstFrameSeconds: item.firstFrameSeconds,
                                                                   languages: item.languages,
                                                                   thermal: thermal, earlyStopProbe: probe)
        // §H — audio AFTER visual (visual-first order), off-MainActor, thermal-gated; merged with its own provenance.
        let evidence = await gatherEvidenceWithAudio(for: item, visual: visual, thermal: thermal)
        // The decisive check: did ANY superseding event happen while we awaited evidence?
        guard captured == evaluationGeneration else {
            // Superseded: do NOT commit this item's decision/state — a newer presentation owns it now. Restore the
            // pre-evaluation state so the transient .evaluating we set above is dropped from the cache (C2). We never
            // write `decisions[item.id]` on a superseded path, so a stale decision can never be authoritative in the
            // cache either (not just refused at the player).
            states[item.id] = priorState
            return .superseded(contentID: item.id, capturedGeneration: captured, liveGeneration: evaluationGeneration)
        }
        let userInitiated = overrides[item.id] == true
        let exceptions = baseExceptions + overrideExceptions(for: item.id)
        let decision = engine.decide(item: item, evidence: evidence, index: index, exceptions: exceptions,
                                     policyRevision: policyRevision, nowEpoch: clock(), userInitiated: userInitiated)
        // Re-check after the synchronous decide (cheap) so even a race during decide cannot commit a stale write.
        guard captured == evaluationGeneration else {
            states[item.id] = priorState
            return .superseded(contentID: item.id, capturedGeneration: captured, liveGeneration: evaluationGeneration)
        }
        decisions[item.id] = decision
        states[item.id] = decision.state
        return .applied(decision)
    }

    /// §C3 — a STABLE digest of the user's override/exception state for a content id. Changes whenever the override
    /// is set/cleared so the prefetch token invalidates when "Yine de göster" state changes (acceptance #8: an
    /// override can never be carried to a different reel, because the digest is per content id).
    public func overrideStateDigest(for contentID: String) -> String {
        "ov:\(overrides[contentID] == true ? 1 : 0)|base:\(baseExceptions.count)"
    }

    /// §C/§D3 — PREFETCH evaluation of the N+1 item. Runs the EXACT SAME guarded decision path as the foreground
    /// `evaluateGuarded` (same engine, same evidence provider, same adaptive sampler + early-stop), so a prefetched
    /// decision is IDENTICAL to the on-demand one (D3). Difference: it does NOT touch the FOREGROUND presentation —
    /// it never sets the transient `.evaluating` marker on the current item, and it caches the decision for the
    /// prefetched id in `decisions[id]` ONLY if the generation still holds (a valid, reusable pre-exposure result).
    /// `capturedGeneration` is the generation at prefetch kickoff; if the brain's generation advanced (a foreground
    /// swipe/skip/policy change) by the time evidence returns, the result is `.superseded` and nothing is committed —
    /// so a late prefetch of A's successor can never be applied to a different reel (acceptance #5). Cancellation is
    /// honoured by the provider (it checks Task.isCancelled) so the decode/OCR really stops (C4).
    @discardableResult
    public func evaluatePrefetch(_ item: ReelItemV1, capturedGeneration: UInt64) async -> GuardedEvaluationV1 {
        let userInitiated = overrides[item.id] == true
        let exceptions = baseExceptions + overrideExceptions(for: item.id)
        let probe = makeEarlyStopProbe(for: item, userInitiated: userInitiated, exceptions: exceptions)
        let thermal = ReelsEvidenceProviderV1.liveThermalBucket()
        let visual = await evidenceProvider.gatherEvidenceAdaptive(url: item.url, metadataTitle: item.title,
                                                                   firstFrameSeconds: item.firstFrameSeconds,
                                                                   languages: item.languages,
                                                                   thermal: thermal, earlyStopProbe: probe)
        // §H — prefetch order: cheap visual first, then audio only if an audio rule exists + budget allows. Audio runs
        // off-MainActor; the whole prefetch is already a low-priority detached Task so it never fights the foreground.
        let evidence = await gatherEvidenceWithAudio(for: item, visual: visual, thermal: thermal)
        // The decisive supersede check: if the captured generation moved while we gathered evidence, a foreground
        // event owns the queue now → discard the prefetch (never cache a decision bound to a superseded generation).
        guard capturedGeneration == evaluationGeneration, !Task.isCancelled else {
            return .superseded(contentID: item.id, capturedGeneration: capturedGeneration, liveGeneration: evaluationGeneration)
        }
        let decision = engine.decide(item: item, evidence: evidence, index: index, exceptions: exceptions,
                                     policyRevision: policyRevision, nowEpoch: clock(), userInitiated: userInitiated)
        guard capturedGeneration == evaluationGeneration, !Task.isCancelled else {
            return .superseded(contentID: item.id, capturedGeneration: capturedGeneration, liveGeneration: evaluationGeneration)
        }
        // §C — SANITIZE THE BRAIN'S COPY TOO. The prefetch decision is a PRE-EXPOSURE result whose raw OCR text we no
        // longer need once the verdict is known — and the mandate (C) is explicit that this decisions[id] copy must be
        // sanitized just like the coordinator's cache entry, not only the final cache layer. If we stored the raw copy
        // here, personal screen text would linger in the brain's RAM decision cache for a reel the user has not even
        // reached yet. So we strip the raw text (keeping rule ids + timestamps + per-sample status + coverage counts)
        // BEFORE caching. The foreground `evaluateGuarded` path keeps raw text (the user IS exposed, the Evidence sheet
        // may show it opt-in); only the speculative prefetch copy is redacted. The coordinator ALSO sanitizes its own
        // token-keyed cache entry — two independent redactions, so no raw prefetch text survives anywhere (acceptance #6).
        let sanitized = PrefetchDecisionSanitizerV1.stripRawText(decision)
        decisions[item.id] = sanitized
        if states[item.id] == nil || states[item.id] == .pendingEvaluation { states[item.id] = sanitized.state }
        // Return the UNREDACTED decision to the coordinator: the coordinator performs its OWN sanitize before caching,
        // and the differential test (D3) compares the verdict fields (state/action/rule/matchState) which sanitizing
        // never touches. Returning the full decision keeps the coordinator the single authority on what it caches.
        return .applied(decision)
    }

    /// B4 — the user chose "Show anyway" for THIS content. Records a content-scoped override + re-evaluates this
    /// item so the exception is honoured (it will PLAY, state → userOverridden). Scoped to the item id only.
    @discardableResult
    public func userShowAnyway(_ item: ReelItemV1) async -> ReelDecisionV1 {
        overrides[item.id] = true
        bumpEvidenceEpoch()   // §A1 — the override changes this item's exception state → prior evidence is stale
        return await evaluate(item)
    }

    /// C2 — the GUARDED "Show anyway": the override re-evaluation is itself protected, so if the user swipes away
    /// while the re-evaluation is in flight, the late override decision is NOT committed to the cache. Used by the
    /// app player. The override is recorded before the guard so a retry on the same item still honours it.
    @discardableResult
    public func userShowAnywayGuarded(_ item: ReelItemV1) async -> GuardedEvaluationV1 {
        overrides[item.id] = true
        bumpEvidenceEpoch()   // §A1 — the override changes this item's exception state → prior evidence is stale
        return await evaluateGuarded(item)
    }

    /// B3 — mark the current item skipped and advance to the next unresolved item. Returns the next item (or nil
    /// at the end of the queue). Handles back-to-back hidden items (keeps advancing past already-hidden ones only
    /// when the caller asks to skip them). Direction-agnostic: `advance(by:)` supports swipe fwd/back.
    @discardableResult
    public func skipCurrent() -> ReelItemV1? {
        if let cur = currentItem { states[cur.id] = .skipped }
        return advance(by: 1)   // advance(by:) bumps the evaluation generation (§3 supersede)
    }

    /// Move the queue cursor (B3 swipe). Clamped to bounds; returns the item now current, or nil past the end.
    @discardableResult
    public func advance(by delta: Int) -> ReelItemV1? {
        bumpEvaluationGeneration()   // §3 — any cursor move supersedes an in-flight evaluate (fast swipe/skip/back)
        let next = currentIndex + delta
        guard next >= 0 else { currentIndex = 0; return currentItem }
        guard next < items.count else { currentIndex = items.count; return nil }   // list end (B3)
        currentIndex = next
        return currentItem
    }

    /// B4 — a content-scoped allow exception, iff the user overrode THIS item. Content-scoping is enforced HERE,
    /// not by the frozen exception engine: this method only returns an exception when `overrides[contentID]` is set,
    /// and `evaluate(_:)` only calls it (and only passes `userInitiated: true`) for that same item — so the override
    /// can never leak to another reel. The exception uses `.userInitiated` scope (the frozen engine's user-override
    /// path) plus `allowsOverrideOfGuardianRule` so even a guardian-authored rule can be user-allowed on our own
    /// controlled surface. A `.item`-scoped exception is also supplied (value = content id) as explicit provenance.
    private func overrideExceptions(for contentID: String) -> [ShieldException] {
        guard overrides[contentID] == true else { return [] }
        return [ShieldException(scope: .userInitiated, value: contentID, allowsOverrideOfGuardianRule: true),
                ShieldException(scope: .item, value: contentID, allowsOverrideOfGuardianRule: true)]
    }
}
#endif
