//
//  LongFormGuardianModelV1.swift — mandate D/E/F/G: OCTOPUS LONG-FORM INTELLIGENCE V1.
//
//  WHAT THIS IS (mandate D): a resource-budgeted Long-Form Guardian that evaluates a REAL long video (e.g. 600s)
//  ACROSS TIME, on OUR controlled player, reusing the existing providers/decision engine — NOT a new inference brain.
//  It drives the AdaptiveEvidencePlannerV1 (mandate E) and executes the plan with VideoFrameProvider + Vision OCR +
//  ReelsAudioEvidenceProviderV1, producing per-window evidence + the aggregate honest decision + a plan record.
//
//  THREE DISTINCT LEVELS (mandate D2 — never collapsed into one number):
//    • FAST DECISION      — metadata + the first window → the FIRST valid, limited-evidence decision. Returned as soon
//                           as it is ready (so the UI can act) WITHOUT claiming the whole video was understood.
//    • SELECTIVE COVERAGE — the budgeted windows across the whole duration are examined; the aggregate decision is the
//                           STRONGEST real per-window verdict (hide > skip > blur > mute > ask > warn > clear).
//    • DEEPENING          — extra windows around uncertain/matched regions, executed only if budget + thermal allow;
//                           deferred (recorded, not silently dropped) under pressure.
//
//  CONTENTDNA-STYLE EVIDENCE REUSE (mandate D3): per-window DECODED+OCR'd evidence is cached keyed by (asset identity,
//  model version, coverage). A POLICY CHANGE recomputes the DECISION from the CACHED evidence WITHOUT re-decoding —
//  the old policy's decision is NEVER shown as the new one (every recompute stamps the current policyRevision).
//
//  HONESTY (mandate D/F): a FAST UNKNOWN is an honest UNKNOWN, not a successful full analysis. Unexamined regions are
//  surfaced as unexamined — never claimed safe. Sparse sampling never claims "the whole video is safe". The real
//  HIDE/ASK/WARN contract is preserved via ReelsDecisionEngineV1 (the frozen evaluator), not re-implemented here.
//
import Foundation
import GuardianCore
import GuardianIntelligence
#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics

// MARK: - Result model

/// mandate E1 — the ACTUAL execution outcome of ONE planned window (what ran / was skipped / deferred, and the result).
public struct LongFormWindowOutcomeV1: Sendable, Equatable {
    public enum Status: String, Sendable, Equatable, Codable {
        case examined = "EXAMINED"          // decoded + at least one requested expert ran
        case notDecoded = "NOT_DECODED"     // the frame did not decode (honest absence, not "clean")
        case deferredThermal = "DEFERRED_THERMAL"  // deepening deferred under thermal/memory pressure (not dropped)
        case skippedBudget = "SKIPPED_BUDGET"      // dropped because the budget was exhausted (recorded, not silent)
        case cancelled = "CANCELLED"
    }
    public let window: LongFormPlannedWindowV1
    public let status: Status
    public let ocrRan: Bool
    public let audioRan: Bool
    public let matchedRuleID: String?        // the rule matched in THIS window, if any (attributed to this window)
    public let matchedAction: ShieldAction?  // the action that window's match implies (real contract, not invented)
    public let ocrText: String               // the window's recognised text (derived; no raw frame kept)
    public let audioLabels: [String]         // the window's distinct classifier labels (derived; no raw audio kept)
    public init(window: LongFormPlannedWindowV1, status: Status, ocrRan: Bool, audioRan: Bool,
                matchedRuleID: String?, matchedAction: ShieldAction?, ocrText: String, audioLabels: [String]) {
        self.window = window; self.status = status; self.ocrRan = ocrRan; self.audioRan = audioRan
        self.matchedRuleID = matchedRuleID; self.matchedAction = matchedAction
        self.ocrText = ocrText; self.audioLabels = audioLabels
    }
}

/// mandate D2/F — the aggregate long-form result: the plan, the first (FAST) decision, the final aggregate decision,
/// the per-window outcomes (the evidence map's source of truth), and HONEST coverage facts kept separate.
public struct LongFormResultV1: Sendable, Equatable {
    public let contentID: String
    public let durationSeconds: Double
    public let plan: LongFormPlanV1
    /// The FIRST valid decision (from the FAST window). Its coverage is intentionally tiny — a fast UNKNOWN is honest.
    public let fastDecision: ReelDecisionV1?
    /// The AGGREGATE decision over all EXAMINED windows (strongest real per-window verdict). Separate from fastDecision.
    public let aggregateDecision: ReelDecisionV1?
    public let windowOutcomes: [LongFormWindowOutcomeV1]
    public let policyRevision: UInt64
    // HONEST coverage facts (mandate D2/F) — kept as distinct counts, never one fused "analysed %".
    public let plannedWindows: Int
    public let examinedWindows: Int
    public let ocrCalls: Int
    public let audioWindows: Int
    public let framesDecoded: Int
    public let deepeningExecuted: Int
    public let deepeningDeferred: Int
    public let evidenceCacheHit: Bool          // mandate D3 — did we reuse cached evidence (no re-decode)?
    public let recomputedFromCache: Bool       // mandate D3 — was the DECISION recomputed from cache under a new policy?
    public let firstValidDecisionNanos: UInt64 // time to the FAST decision (mandate G measures this)
    public let totalPlanNanos: UInt64          // time to the full plan completion
    /// mandate F — the examined time ranges (for the evidence-map timeline). Unexamined ranges are the complement.
    public var examinedRanges: [(Double, Double)] {
        windowOutcomes.filter { $0.status == .examined }.map { ($0.window.startSeconds, $0.window.endSeconds) }
    }
    /// mandate F/honesty — the aggregate is ALWAYS temporally partial for a long sampled video (windows, not frames).
    public var temporalCoverageLimited: Bool { true }
}

// MARK: - Evidence cache (ContentDNA-style reuse)

/// mandate D3 — the cached per-window EVIDENCE for one asset+model+coverage. Holds the derived evidence (OCR text,
/// audio labels, timestamps) so a POLICY change recomputes the DECISION without re-decoding. No raw frames/PCM.
struct LongFormEvidenceCacheEntryV1: Sendable {
    let assetIdentity: String        // asset fingerprint (identity) — a different asset never reuses this
    let modelVersion: String         // the provider/model versions this evidence was produced under
    let durationSeconds: Double
    let plan: LongFormPlanV1
    let windowEvidence: [Int: (ocrText: String, audioLabels: [String], actualSeconds: Double, decoded: Bool, ocrRan: Bool, audioRan: Bool)]
    let framesDecoded: Int
    let ocrCalls: Int
    let audioWindows: Int
    // mandate 1C — the modalities this cached evidence ACTUALLY analysed (not merely requested). A cache hit is valid
    // for a new policy ONLY when the new policy's REQUIRED modalities are a subset of these. Otherwise the cache is
    // modality-insufficient (e.g. an OCR-only cache cannot answer a newly-added SoundClass rule) → it must NOT serve a
    // full decision from it (that would silently treat "audio never analysed" as "no sound match" — a false CLEAR).
    let analyzedOCR: Bool            // at least one window really ran OCR (visual coverage exists in the cache)
    let analyzedAudio: Bool          // the whole-file audio sense really RAN (audio coverage exists in the cache)
}

// MARK: - The model

public actor LongFormGuardianModelV1 {
    public static let version = "long-form-guardian-model-v1"
    public static let modelVersion = "lfg-v1|\(VideoFrameProvider.version)|\(VisionOCRProvider.version)|\(ReelsAudioEvidenceProviderV1.version)"

    private let ocr = VisionOCRProvider(mode: .fast)
    private let planner = AdaptiveEvidencePlannerV1()
    private let decisionEngine: ReelsDecisionEngineV1
    private let audioProvider: ReelsAudioEvidenceProviding?
    private var evidenceCache: [String: LongFormEvidenceCacheEntryV1] = [:]   // keyed by asset identity
    /// mandate 1D — AUDIO ECONOMY: the WHOLE-FILE audio evidence for an asset, analysed ONCE per (assetFingerprint +
    /// provider version) and REUSED by every window (each window filters this to its own time range). Keyed so a
    /// different asset or a provider-version change never reuses stale audio. Session-scoped (cleared with the cache).
    private var audioEvidenceCache: [String: ReelsAudioEvidenceV1] = [:]      // keyed by "assetIdentity|providerVersion"
    /// mandate 1D — the REAL number of full-file audio analysis JOBS run this session (the before/after metric). A
    /// correct economy means ONE job per asset no matter how many audio windows the plan has.
    public private(set) var audioJobsRun = 0

    public init(decisionEngine: ReelsDecisionEngineV1 = ReelsDecisionEngineV1(),
                audioProvider: ReelsAudioEvidenceProviding? = ReelsAudioEvidenceProviderV1()) {
        self.decisionEngine = decisionEngine
        self.audioProvider = audioProvider
    }

    public func clearCache() { evidenceCache.removeAll(); audioEvidenceCache.removeAll() }

    /// mandate 1D — gather the WHOLE-FILE audio evidence for an asset ONCE and reuse it. A second request for the same
    /// (asset, provider version) returns the cached bundle WITHOUT re-running SoundAnalysis (no per-window re-scan).
    /// `audioJobsRun` increments ONLY on a real analysis pass, so the test can prove job count is 1, not N windows.
    private func gatherAudioOnce(url: URL, assetIdentity: String, thermal: ReelsThermalBucketV1) async -> ReelsAudioEvidenceV1? {
        guard let audioProvider else { return nil }
        let key = "\(assetIdentity)|\(ReelsAudioEvidenceProviderV1.version)"
        if let cached = audioEvidenceCache[key] { return cached }
        audioJobsRun += 1
        let bundle = await audioProvider.gatherAudioEvidence(url: url, thermal: thermal)
        audioEvidenceCache[key] = bundle
        return bundle
    }

    /// mandate 1D — the distinct labels of the whole-file audio evidence that OVERLAP a window's [start,end] range.
    /// An event with NO time range (framework gave none) is conservatively visible to every window (honest absence of
    /// a stamp ≠ drop the evidence). Events outside the window are excluded — a window only sees its own audio.
    private static func windowAudioLabels(_ audio: ReelsAudioEvidenceV1?, start: Double, end: Double) -> [String] {
        guard let audio, audio.senseRan else { return [] }
        var best: [String: Double] = [:]
        for e in audio.events {
            let overlaps: Bool
            if let s = e.startSeconds, let en = e.endSeconds { overlaps = en >= start && s <= end }
            else { overlaps = true }   // no range → visible everywhere (never fabricate a stamp to exclude it)
            if overlaps { let k = e.label.lowercased(); best[k] = max(best[k] ?? 0, e.rawModelConfidence ?? 0) }
        }
        return best.sorted { $0.value > $1.value }.map { $0.key }
    }

    /// mandate D/E/G — analyse a long video against the user's rules. Executes the plan (FAST → SELECTIVE → DEEPENING),
    /// producing per-window evidence + the FAST decision + the aggregate decision, with HONEST separate coverage facts.
    ///
    /// D3: if valid cached evidence exists for this asset under the SAME model version, the decode/OCR/audio work is
    /// SKIPPED and the decision is RECOMPUTED from the cache under the CURRENT policy (a policy change reuses evidence,
    /// never the old decision). `forceReDecode` bypasses the cache (e.g. a model-version change).
    public func analyze(url: URL, contentID: String, index: ShieldIndex, exceptions: [ShieldException],
                        languages: [String] = ["en"], policyRevision: UInt64,
                        thermal: ReelsThermalBucketV1 = ReelsEvidenceProviderV1.liveThermalBucket(),
                        nowEpoch: Double = Date().timeIntervalSince1970,
                        forceReDecode: Bool = false) async -> LongFormResultV1 {
        let t0 = DispatchTime.now().uptimeNanoseconds
        let assetIdentity = PrefetchTokenV1.assetFingerprint(url: url)

        // Expert selection from the user's REAL rule kinds (mandate E).
        let activeRules = index.rules.values.filter { $0.isActive(nowEpoch: nowEpoch) }
        let hasTextRules = activeRules.contains { !SoundRuleSafetyV1.isSoundInput($0.inputType) }
        let hasSoundRules = activeRules.contains { SoundRuleSafetyV1.isSoundInput($0.inputType) }

        // mandate D3/1C — EVIDENCE REUSE: recompute the decision from cached evidence without re-decode ONLY when the
        // cache is both (a) produced under the same model version AND (b) MODALITY-SUFFICIENT for the CURRENT policy.
        // 1C: a cache hit is honest only when every modality the NEW policy REQUIRES was ACTUALLY analysed in the
        // cache. An OCR-only cache cannot answer a newly-added SoundClass rule — serving it would silently treat
        // "audio never analysed" as "no sound match" (a false CLEAR). When a required modality is MISSING we fall
        // through to a fresh analyse that re-plans with the new rule kinds (so only the needed evidence is gathered),
        // and UNKNOWN is never optimised into CLEAR.
        if !forceReDecode, let cached = evidenceCache[assetIdentity], cached.modelVersion == Self.modelVersion {
            let needOCR = hasTextRules, needAudio = hasSoundRules
            let modalitySufficient = (!needOCR || cached.analyzedOCR) && (!needAudio || cached.analyzedAudio)
            if modalitySufficient {
                return recompute(from: cached, contentID: contentID, index: index, exceptions: exceptions,
                                 languages: languages, policyRevision: policyRevision, nowEpoch: nowEpoch, t0: t0)
            }
            // Modality-insufficient cache: drop it so the fresh pass below can gather the missing modality honestly
            // (no stale decision is ever shown as the new one).
            evidenceCache.removeValue(forKey: assetIdentity)
        }

        // Read duration (real). A failure → an honest empty plan + UNKNOWN (never a fabricated clean result).
        let meta = await MediaAssetSource().loadMetadata(url: url)
        let duration: Double = { if case .success(let m) = meta, m.durationSeconds > 0 { return m.durationSeconds }; return 0 }()

        let plan = planner.plan(contentID: contentID, durationSeconds: duration, thermal: thermal,
                                hasTextRules: hasTextRules, hasSoundRules: hasSoundRules, policyRevision: policyRevision)

        let provider = VideoFrameProvider(url: url)
        var windowEvidence: [Int: (ocrText: String, audioLabels: [String], actualSeconds: Double, decoded: Bool, ocrRan: Bool, audioRan: Bool)] = [:]
        var outcomes: [LongFormWindowOutcomeV1] = []
        var fastDecision: ReelDecisionV1?
        var firstValidNanos: UInt64 = 0
        var framesDecoded = 0, ocrCalls = 0, audioWindows = 0, deepeningExecuted = 0, deepeningDeferred = 0

        // G — BATCHED, DOWNSCALED decode for all OCR windows in ONE pass (the landed bottleneck improvement). We decode
        // every OCR window's representative timestamp together so AVFoundation shares decode setup across the points.
        let ocrWindows = plan.windows.filter { $0.experts.ocr }
        let ocrTimes = ocrWindows.map { $0.sampleSeconds }
        let decoded = ocrTimes.isEmpty ? [] : await provider.framesBatched(url: url, atSeconds: ocrTimes)
        var frameByTime: [Double: ExtractedFrame] = [:]
        for f in decoded { frameByTime[f.requestedTimeSeconds] = f }

        // mandate 1D — AUDIO ECONOMY: if ANY window requests audio, analyse the WHOLE FILE ONCE here (one timestamped
        // reusable evidence bundle) instead of re-classifying the entire file per audio window. Every audio window
        // below reuses this one bundle, filtered to its own time range. One job per asset, not one per window.
        let wholeFileAudio: ReelsAudioEvidenceV1? = plan.windows.contains { $0.experts.audio }
            ? await gatherAudioOnce(url: url, assetIdentity: assetIdentity, thermal: thermal)
            : nil

        // Execute windows in time order; the FAST window yields the first valid decision the moment it is ready.
        for w in plan.windows {
            if Task.isCancelled {
                outcomes.append(.init(window: w, status: .cancelled, ocrRan: false, audioRan: false,
                                      matchedRuleID: nil, matchedAction: nil, ocrText: "", audioLabels: []))
                continue
            }
            // Deepening under pressure is DEFERRED (recorded), not silently dropped (mandate E/H).
            if w.level == .deepening && (thermal == .serious || thermal == .critical) {
                deepeningDeferred += 1
                outcomes.append(.init(window: w, status: .deferredThermal, ocrRan: false, audioRan: false,
                                      matchedRuleID: nil, matchedAction: nil, ocrText: "", audioLabels: []))
                continue
            }

            var ocrText = ""
            var ocrRan = false
            var actualSeconds = w.sampleSeconds
            var decodedOK = false
            if w.experts.ocr {
                if let f = frameByTime[w.sampleSeconds], let img = f.image {
                    decodedOK = true; framesDecoded += 1
                    actualSeconds = f.actualTimeSeconds ?? w.sampleSeconds
                    ocrCalls += 1; ocrRan = true
                    ocrText = ocr.recognizeText(cgImage: img).value?.text ?? ""
                }
            }

            var audioLabels: [String] = []
            var audioRan = false
            if w.experts.audio {
                // mandate 1D — REUSE the one whole-file audio bundle (analysed once above), filtered to THIS window's
                // time range. No per-window re-scan of the file. `senseRan` reflects the single real analysis pass;
                // absence/deferral stays honest (UNAVAILABLE narrows coverage, never fabricated silence).
                audioRan = wholeFileAudio?.senseRan ?? false
                if audioRan {
                    audioWindows += 1
                    audioLabels = Self.windowAudioLabels(wholeFileAudio, start: w.startSeconds, end: w.endSeconds)
                }
            }

            windowEvidence[w.index] = (ocrText, audioLabels, actualSeconds, decodedOK, ocrRan, audioRan)
            if w.level == .deepening && (decodedOK || audioRan) { deepeningExecuted += 1 }

            // Build this window's evidence + decide (reuses the frozen evaluator via ReelsDecisionEngineV1). The FULL
            // ReelDecisionV1 is returned so the FAST decision is the ENGINE'S REAL verdict over THIS window's actual
            // evidence (mandate 1A) — never a second decision rebuilt from empty OCR text.
            let (status, matchedRule, matchedAction, decision) = evaluateWindow(
                contentID: contentID, window: w, ocrText: ocrText, ocrRan: ocrRan, decodedOK: decodedOK,
                actualSeconds: actualSeconds, audioLabels: audioLabels, index: index, exceptions: exceptions,
                languages: languages, policyRevision: policyRevision, nowEpoch: nowEpoch)
            outcomes.append(.init(window: w, status: status, ocrRan: ocrRan, audioRan: audioRan,
                                  matchedRuleID: matchedRule, matchedAction: matchedAction,
                                  ocrText: ocrText, audioLabels: audioLabels))

            // FAST decision (mandate 1A): the moment the fast window is examined, snapshot the ENGINE'S decision over
            // the FAST window's REAL evidence (OCR text + audio labels + matchedRule/matchedAction preserved). A
            // start-of-video HIDE match is therefore a FAST HIDE; a limited/empty-evidence window is an honest
            // UNKNOWN/limited decision — the engine owns the contract, so FAST UNKNOWN is NEVER upgraded to CLEAR and
            // metadata is never conflated with video OCR (there is no metadata text in this evidence).
            if w.level == .fast && fastDecision == nil {
                fastDecision = decision
                firstValidNanos = DispatchTime.now().uptimeNanoseconds &- t0
            }
        }

        // Cache the derived evidence (mandate D3) for future policy-change recomputes without re-decode. mandate 1C —
        // record the modalities ACTUALLY analysed (OCR really ran on ≥1 window; the audio sense really ran) so a later
        // policy that needs a modality this run did not analyse cannot be answered from a modality-insufficient cache.
        let analyzedOCR = windowEvidence.values.contains { $0.ocrRan }
        let analyzedAudio = windowEvidence.values.contains { $0.audioRan }
        evidenceCache[assetIdentity] = LongFormEvidenceCacheEntryV1(
            assetIdentity: assetIdentity, modelVersion: Self.modelVersion, durationSeconds: duration, plan: plan,
            windowEvidence: windowEvidence, framesDecoded: framesDecoded, ocrCalls: ocrCalls, audioWindows: audioWindows,
            analyzedOCR: analyzedOCR, analyzedAudio: analyzedAudio)

        let aggregate = aggregateDecision(from: outcomes, contentID: contentID, policyRevision: policyRevision,
                                          index: index, exceptions: exceptions, nowEpoch: nowEpoch)
        let examinedCount = outcomes.filter { $0.status == .examined }.count
        return LongFormResultV1(contentID: contentID, durationSeconds: duration, plan: plan,
                                fastDecision: fastDecision, aggregateDecision: aggregate, windowOutcomes: outcomes,
                                policyRevision: policyRevision, plannedWindows: plan.windows.count,
                                examinedWindows: examinedCount, ocrCalls: ocrCalls, audioWindows: audioWindows,
                                framesDecoded: framesDecoded, deepeningExecuted: deepeningExecuted,
                                deepeningDeferred: deepeningDeferred, evidenceCacheHit: false, recomputedFromCache: false,
                                firstValidDecisionNanos: firstValidNanos,
                                totalPlanNanos: DispatchTime.now().uptimeNanoseconds &- t0)
    }

    // MARK: - D3 recompute from cached evidence (no re-decode)

    private func recompute(from cached: LongFormEvidenceCacheEntryV1, contentID: String, index: ShieldIndex,
                           exceptions: [ShieldException], languages: [String], policyRevision: UInt64,
                           nowEpoch: Double, t0: UInt64) -> LongFormResultV1 {
        var outcomes: [LongFormWindowOutcomeV1] = []
        var fastDecision: ReelDecisionV1?
        var firstValidNanos: UInt64 = 0
        for w in cached.plan.windows {
            guard let ev = cached.windowEvidence[w.index] else {
                outcomes.append(.init(window: w, status: .skippedBudget, ocrRan: false, audioRan: false,
                                      matchedRuleID: nil, matchedAction: nil, ocrText: "", audioLabels: []))
                continue
            }
            let (status, matchedRule, matchedAction, decision) = evaluateWindow(
                contentID: contentID, window: w, ocrText: ev.ocrText, ocrRan: ev.ocrRan, decodedOK: ev.decoded,
                actualSeconds: ev.actualSeconds, audioLabels: ev.audioLabels, index: index, exceptions: exceptions,
                languages: languages, policyRevision: policyRevision, nowEpoch: nowEpoch)
            outcomes.append(.init(window: w, status: status, ocrRan: ev.ocrRan, audioRan: ev.audioRan,
                                  matchedRuleID: matchedRule, matchedAction: matchedAction,
                                  ocrText: ev.ocrText, audioLabels: ev.audioLabels))
            // mandate 1A — the recomputed FAST decision is the engine's REAL verdict over the CACHED fast-window
            // evidence under the CURRENT policy (stamped with the new policyRevision), never rebuilt from empty text.
            if w.level == .fast && fastDecision == nil {
                fastDecision = decision
                firstValidNanos = DispatchTime.now().uptimeNanoseconds &- t0
            }
        }
        let aggregate = aggregateDecision(from: outcomes, contentID: contentID, policyRevision: policyRevision,
                                          index: index, exceptions: exceptions, nowEpoch: nowEpoch)
        let examinedCount = outcomes.filter { $0.status == .examined }.count
        return LongFormResultV1(contentID: contentID, durationSeconds: cached.durationSeconds, plan: cached.plan,
                                fastDecision: fastDecision, aggregateDecision: aggregate, windowOutcomes: outcomes,
                                policyRevision: policyRevision, plannedWindows: cached.plan.windows.count,
                                examinedWindows: examinedCount, ocrCalls: 0, audioWindows: 0,
                                framesDecoded: 0, deepeningExecuted: 0, deepeningDeferred: 0,
                                evidenceCacheHit: true, recomputedFromCache: true,
                                firstValidDecisionNanos: firstValidNanos,
                                totalPlanNanos: DispatchTime.now().uptimeNanoseconds &- t0)
    }

    // MARK: - per-window evaluation (reuses the frozen evaluator via ReelsDecisionEngineV1)

    /// Evaluate ONE window's derived evidence (OCR text + audio labels) against the user's rules. Returns the honest
    /// window status + the matched rule/action for THIS window (attributed to this window only — no cross-window fuse).
    private func evaluateWindow(contentID: String, window: LongFormPlannedWindowV1, ocrText: String, ocrRan: Bool,
                                decodedOK: Bool, actualSeconds: Double, audioLabels: [String], index: ShieldIndex,
                                exceptions: [ShieldException], languages: [String], policyRevision: UInt64,
                                nowEpoch: Double) -> (LongFormWindowOutcomeV1.Status, String?, ShieldAction?, ReelDecisionV1) {
        let status: LongFormWindowOutcomeV1.Status = (ocrRan || !audioLabels.isEmpty || decodedOK) ? .examined
            : (window.experts.ocr && !decodedOK ? .notDecoded : .examined)
        // Build a single-window ReelsEvidenceV1 and decide. OCR text is ONE unit; audio labels are a SEPARATE unit.
        var records: [ReelsTimedEvidenceV1] = []
        if ocrRan {
            records.append(.init(timestampSeconds: actualSeconds,
                                 modality: .visualOCR,
                                 ocrStatus: ocrText.isEmpty ? .ranNoText : .ran, text: ocrText))
        }
        let audio: ReelsAudioEvidenceV1? = audioLabels.isEmpty ? nil :
            ReelsAudioEvidenceV1(availability: .available,
                                 events: audioLabels.map { ReelsAudioEventV1(label: $0, rawModelConfidence: nil,
                                                                             startSeconds: window.startSeconds,
                                                                             endSeconds: window.endSeconds,
                                                                             classifierVersion: "sound-analysis-v1") },
                                 classifierVersion: "sound-analysis-v1")
        let ev = ReelsEvidenceProviderV1.fuse(ocrText: ocrText, metadataText: "", frameCoverage: decodedOK ? 1 : 0,
                                              ocrExecuted: ocrRan, languages: languages, timedRecords: records)
            .withAudio(audio)
        let item = ReelItemV1(id: contentID, title: "", url: URL(fileURLWithPath: "/dev/null"))
        let d = decisionEngine.decide(item: item, evidence: ev, index: index, exceptions: exceptions,
                                      policyRevision: policyRevision, nowEpoch: nowEpoch, userInitiated: false)
        let matched = (d.matchState.isMatch) ? d.matchedRuleID : nil
        let action = matched != nil ? d.appliedAction : nil
        // mandate 1A — return the engine's FULL decision so the FAST path can surface the REAL verdict (matched rule +
        // applicable action + provenance) instead of rebuilding a second decision from empty text (the old defect).
        return (status, matched, action, d)
    }

    /// mandate D2 — the AGGREGATE decision: the STRONGEST real per-window verdict. We rebuild one fused evidence over
    /// ALL examined windows and let the engine decide (so the real HIDE/ASK/WARN contract + per-sample attribution are
    /// the engine's, not re-implemented). Each window's OCR text is its OWN timed record (no cross-window fusion of a
    /// single phrase); the strongest per-UNIT verdict wins inside the engine.
    private func aggregateDecision(from outcomes: [LongFormWindowOutcomeV1], contentID: String, policyRevision: UInt64,
                                   index: ShieldIndex, exceptions: [ShieldException], nowEpoch: Double) -> ReelDecisionV1 {
        var records: [ReelsTimedEvidenceV1] = []
        var audioEvents: [ReelsAudioEventV1] = []
        for o in outcomes where o.status == .examined {
            if o.ocrRan {
                records.append(.init(timestampSeconds: o.window.sampleSeconds, modality: .visualOCR,
                                     ocrStatus: o.ocrText.isEmpty ? .ranNoText : .ran, text: o.ocrText))
            }
            for lbl in o.audioLabels {
                audioEvents.append(ReelsAudioEventV1(label: lbl, rawModelConfidence: nil,
                                                     startSeconds: o.window.startSeconds, endSeconds: o.window.endSeconds,
                                                     classifierVersion: "sound-analysis-v1"))
            }
        }
        let audio: ReelsAudioEvidenceV1? = audioEvents.isEmpty ? nil :
            ReelsAudioEvidenceV1(availability: .available, events: audioEvents, classifierVersion: "sound-analysis-v1")
        let anyDecoded = records.contains { $0.ocrStatus == .ran || $0.ocrStatus == .ranNoText }
        let ev = ReelsEvidenceProviderV1.fuse(ocrText: records.map { $0.text }.joined(separator: " "),
                                              metadataText: "", frameCoverage: anyDecoded ? 1 : 0,
                                              ocrExecuted: anyDecoded, languages: ["en"], timedRecords: records)
            .withAudio(audio)
        let item = ReelItemV1(id: contentID, title: "", url: URL(fileURLWithPath: "/dev/null"))
        return decisionEngine.decide(item: item, evidence: ev, index: index, exceptions: exceptions,
                                     policyRevision: policyRevision, nowEpoch: nowEpoch, userInitiated: false)
    }
}
#endif
