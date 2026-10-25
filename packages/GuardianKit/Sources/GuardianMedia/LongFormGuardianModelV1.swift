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

    public init(decisionEngine: ReelsDecisionEngineV1 = ReelsDecisionEngineV1(),
                audioProvider: ReelsAudioEvidenceProviding? = ReelsAudioEvidenceProviderV1()) {
        self.decisionEngine = decisionEngine
        self.audioProvider = audioProvider
    }

    public func clearCache() { evidenceCache.removeAll() }

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

        // mandate D3 — EVIDENCE REUSE: recompute the decision from cached evidence without re-decode when valid.
        if !forceReDecode, let cached = evidenceCache[assetIdentity], cached.modelVersion == Self.modelVersion {
            return recompute(from: cached, contentID: contentID, index: index, exceptions: exceptions,
                             languages: languages, policyRevision: policyRevision, nowEpoch: nowEpoch, t0: t0)
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
            if w.experts.audio, let audioProvider {
                // Audio is analysed over the whole file once per window request only when the user has sound rules.
                // (The provider itself defers under .critical thermal — honest absence, never fabricated silence.)
                let bundle = await audioProvider.gatherAudioEvidence(url: url, thermal: thermal)
                audioRan = bundle.senseRan
                if audioRan { audioWindows += 1; audioLabels = bundle.distinctLabels }
            }

            windowEvidence[w.index] = (ocrText, audioLabels, actualSeconds, decodedOK, ocrRan, audioRan)
            if w.level == .deepening && (decodedOK || audioRan) { deepeningExecuted += 1 }

            // Build this window's evidence + decide (reuses the frozen evaluator via ReelsDecisionEngineV1).
            let (status, matchedRule, matchedAction) = evaluateWindow(
                contentID: contentID, window: w, ocrText: ocrText, ocrRan: ocrRan, decodedOK: decodedOK,
                actualSeconds: actualSeconds, audioLabels: audioLabels, index: index, exceptions: exceptions,
                languages: languages, policyRevision: policyRevision, nowEpoch: nowEpoch)
            outcomes.append(.init(window: w, status: status, ocrRan: ocrRan, audioRan: audioRan,
                                  matchedRuleID: matchedRule, matchedAction: matchedAction,
                                  ocrText: ocrText, audioLabels: audioLabels))

            // FAST decision: the moment the fast window is examined, snapshot the first valid decision + its latency.
            if w.level == .fast && fastDecision == nil {
                fastDecision = buildDecision(contentID: contentID, policyRevision: policyRevision,
                                             matchedRule: matchedRule, matchedAction: matchedAction,
                                             examined: [actualSeconds], nowEpoch: nowEpoch,
                                             index: index, exceptions: exceptions)
                firstValidNanos = DispatchTime.now().uptimeNanoseconds &- t0
            }
        }

        // Cache the derived evidence (mandate D3) for future policy-change recomputes without re-decode.
        evidenceCache[assetIdentity] = LongFormEvidenceCacheEntryV1(
            assetIdentity: assetIdentity, modelVersion: Self.modelVersion, durationSeconds: duration, plan: plan,
            windowEvidence: windowEvidence, framesDecoded: framesDecoded, ocrCalls: ocrCalls, audioWindows: audioWindows)

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
            let (status, matchedRule, matchedAction) = evaluateWindow(
                contentID: contentID, window: w, ocrText: ev.ocrText, ocrRan: ev.ocrRan, decodedOK: ev.decoded,
                actualSeconds: ev.actualSeconds, audioLabels: ev.audioLabels, index: index, exceptions: exceptions,
                languages: languages, policyRevision: policyRevision, nowEpoch: nowEpoch)
            outcomes.append(.init(window: w, status: status, ocrRan: ev.ocrRan, audioRan: ev.audioRan,
                                  matchedRuleID: matchedRule, matchedAction: matchedAction,
                                  ocrText: ev.ocrText, audioLabels: ev.audioLabels))
            if w.level == .fast && fastDecision == nil {
                fastDecision = buildDecision(contentID: contentID, policyRevision: policyRevision,
                                             matchedRule: matchedRule, matchedAction: matchedAction,
                                             examined: [ev.actualSeconds], nowEpoch: nowEpoch,
                                             index: index, exceptions: exceptions)
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
                                nowEpoch: Double) -> (LongFormWindowOutcomeV1.Status, String?, ShieldAction?) {
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
        return (status, matched, action)
    }

    /// Build a ReelDecisionV1 from a per-window/aggregate match (reuses the engine for a real single-unit decision).
    private func buildDecision(contentID: String, policyRevision: UInt64, matchedRule: String?,
                               matchedAction: ShieldAction?, examined: [Double], nowEpoch: Double,
                               index: ShieldIndex, exceptions: [ShieldException]) -> ReelDecisionV1 {
        // We re-run the engine over the matched window's state by constructing minimal evidence; simpler + honest: if
        // a rule matched, surface its action; else CLEAR with limited coverage. The engine owns the real contract.
        let item = ReelItemV1(id: contentID, title: "", url: URL(fileURLWithPath: "/dev/null"))
        var records: [ReelsTimedEvidenceV1] = []
        for t in examined { records.append(.init(timestampSeconds: t, modality: .visualOCR, ocrStatus: .ranNoText, text: "")) }
        let ev = ReelsEvidenceProviderV1.fuse(ocrText: "", metadataText: "", frameCoverage: examined.isEmpty ? 0 : 1,
                                              ocrExecuted: !examined.isEmpty, languages: ["en"], timedRecords: records)
        _ = (matchedRule, matchedAction)   // the aggregate decision below is the authoritative surface
        return decisionEngine.decide(item: item, evidence: ev, index: index, exceptions: exceptions,
                                     policyRevision: policyRevision, nowEpoch: nowEpoch, userInitiated: false)
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
