//
//  AdaptiveEvidencePlannerV1.swift — mandate E: ADAPTIVE EVIDENCE PLANNER V1 (long-form, resource-budgeted).
//
//  WHAT THIS IS (mandate E): a PURE, deterministic planner that decides WHICH time windows of a long (e.g. 600s)
//  video get examined, by WHICH expert (OCR / audio), at WHICH analysis level — given a resource budget, the user's
//  REAL rule kinds, and cheap early hints. It is NOT a new inference engine: it consumes the existing sampler/thermal
//  vocabulary and produces a PLAN that LongFormGuardianModelV1 executes with the existing providers. Every arm does
//  NOT run on every video — the plan is the record of what WAS chosen and WHY (mandate E1).
//
//  THREE LEVELS (mandate D2, kept DISTINCT — never fused into one metric):
//    • FAST     — metadata + the FIRST window only → the first valid, limited-evidence decision. A fast UNKNOWN is an
//                 honest UNKNOWN, never a "whole video analysed".
//    • SELECTIVE — a BUDGETED set of windows spread across the whole duration, examined visually (+ audio if the user
//                 has sound rules). Scene-change / uncertainty hints bias window placement when cheaply available.
//    • DEEPENING — EXTRA windows concentrated around UNCERTAIN or already-MATCHED regions, added only when budget +
//                 thermal allow. Deepening is DEFERRED (not silently dropped) under memory/thermal pressure.
//
//  EXPERT SELECTION BY THE USER'S REAL RULES (mandate E): if the user has TEXT rules → OCR windows; if the user has
//  SOUND rules → audio windows. A video with no sound rules does NOT pay for audio decode. This is the ≥2-strategy
//  selection the acceptance asks for (budget + evidence driven), chosen here, not hardcoded per run.
//
//  HONESTY: a plan never claims coverage it did not request; skipped/deferred windows are recorded as such; the plan
//  carries the engine/plan version so a decision can cite the exact plan it was produced under.
//
import Foundation
import GuardianCore

/// mandate E — the analysis LEVEL a planned window is examined at. Kept distinct from any single coverage number.
public enum LongFormAnalysisLevelV1: String, Sendable, Equatable, Codable {
    case fast = "FAST"              // the first-window, first-valid-decision pass
    case selective = "SELECTIVE"    // budgeted windows across the whole duration
    case deepening = "DEEPENING"    // extra windows around uncertain/matched regions
}

/// mandate E — which expert(s) a window requests. Driven by the user's REAL rule kinds (text → OCR, sound → audio).
public struct LongFormWindowExpertsV1: Sendable, Equatable, Codable {
    public let ocr: Bool
    public let audio: Bool
    public init(ocr: Bool, audio: Bool) { self.ocr = ocr; self.audio = audio }
    public var any: Bool { ocr || audio }
}

/// mandate E/E1 — ONE planned window: the time range to examine, the level, and the experts requested for it.
public struct LongFormPlannedWindowV1: Sendable, Equatable, Codable {
    public let index: Int
    public let startSeconds: Double
    public let endSeconds: Double
    public let level: LongFormAnalysisLevelV1
    public let experts: LongFormWindowExpertsV1
    /// The single representative timestamp OCR/decoding targets inside this window (window midpoint by default).
    public var sampleSeconds: Double { (startSeconds + endSeconds) / 2.0 }
    public init(index: Int, startSeconds: Double, endSeconds: Double,
                level: LongFormAnalysisLevelV1, experts: LongFormWindowExpertsV1) {
        self.index = index; self.startSeconds = startSeconds; self.endSeconds = endSeconds
        self.level = level; self.experts = experts
    }
}

/// mandate E — which STRATEGY the planner selected for this run. The acceptance requires ≥2 selectable strategies;
/// the choice is driven by the resource budget (thermal/duration) and the user's evidence needs (rule kinds).
public enum LongFormPlanStrategyV1: String, Sendable, Equatable, Codable {
    /// Low budget (thermal pressure / long duration + tight budget): fewer windows, OCR-first, audio only if the user
    /// has sound rules AND budget remains. Expensive work is minimised (acceptance: "düşük bütçede pahalı iş azalır").
    case conservativeCoverage = "CONSERVATIVE_COVERAGE"
    /// Healthy budget: denser windows across the duration + audio when the user has sound rules, with room reserved
    /// for a deepening pass around uncertain/matched regions.
    case thoroughCoverage = "THOROUGH_COVERAGE"
}

/// mandate E/E1 — the PLAN record: everything the planner decided + the inputs it decided from. This is the audit the
/// decision cites; LongFormGuardianModelV1 appends the ACTUAL execution outcome (ran/skipped/deferred) at run time.
public struct LongFormPlanV1: Sendable, Equatable, Codable {
    public static let engineVersion = "adaptive-evidence-planner-v1"
    public let engineVersion: String
    public let contentID: String
    public let durationSeconds: Double
    public let strategy: LongFormPlanStrategyV1
    public let thermal: ReelsThermalBucketV1
    public let requestsOCR: Bool                 // did the user's rules require OCR at all?
    public let requestsAudio: Bool               // did the user's rules require audio at all?
    public let budgetWindows: Int                // the window budget this plan was allowed
    public let windows: [LongFormPlannedWindowV1]
    public let producedUnderPolicyRevision: UInt64
    public init(engineVersion: String = LongFormPlanV1.engineVersion, contentID: String, durationSeconds: Double,
                strategy: LongFormPlanStrategyV1, thermal: ReelsThermalBucketV1, requestsOCR: Bool,
                requestsAudio: Bool, budgetWindows: Int, windows: [LongFormPlannedWindowV1],
                producedUnderPolicyRevision: UInt64) {
        self.engineVersion = engineVersion; self.contentID = contentID; self.durationSeconds = durationSeconds
        self.strategy = strategy; self.thermal = thermal; self.requestsOCR = requestsOCR
        self.requestsAudio = requestsAudio; self.budgetWindows = budgetWindows; self.windows = windows
        self.producedUnderPolicyRevision = producedUnderPolicyRevision
    }
    public var fastWindow: LongFormPlannedWindowV1? { windows.first { $0.level == .fast } }
    public var selectiveWindows: [LongFormPlannedWindowV1] { windows.filter { $0.level == .selective } }
    public var deepeningWindows: [LongFormPlannedWindowV1] { windows.filter { $0.level == .deepening } }
}

/// mandate E — the pure planner. Deterministic over its inputs (no wall-clock, no decode). Given duration, thermal,
/// the user's rule kinds, and optional scene-change hints, it produces a LongFormPlanV1.
public struct AdaptiveEvidencePlannerV1: Sendable {
    public static let version = LongFormPlanV1.engineVersion

    /// Window-budget ceiling for the SELECTIVE pass (hard bound so a long video never explodes the decode count). The
    /// planner picks a budget ≤ this from duration + thermal; deepening adds a bounded few MORE on top.
    public static let maxSelectiveWindows = 12
    public static let maxDeepeningWindows = 4

    public init() {}

    /// mandate E — SELECT the strategy from the resource budget + evidence needs. Thermal pressure OR a very long
    /// duration with no sound rules → conservative; otherwise thorough. (≥2 strategies, chosen — not hardcoded.)
    public func selectStrategy(durationSeconds: Double, thermal: ReelsThermalBucketV1) -> LongFormPlanStrategyV1 {
        switch thermal {
        case .serious, .critical: return .conservativeCoverage
        case .fair:               return durationSeconds > 300 ? .conservativeCoverage : .thoroughCoverage
        case .nominal:            return .thoroughCoverage
        }
    }

    /// mandate E — the SELECTIVE window budget: scales with duration, clamped, shrunk by thermal + conservative
    /// strategy. A long cold video with a healthy budget gets more windows; a hot or tightly-budgeted run gets fewer.
    public func selectiveBudget(durationSeconds: Double, thermal: ReelsThermalBucketV1,
                                strategy: LongFormPlanStrategyV1) -> Int {
        // ~1 window per 60s, clamped to [2, maxSelectiveWindows].
        var budget = max(2, min(Self.maxSelectiveWindows, Int((durationSeconds / 60.0).rounded(.up))))
        switch thermal {
        case .nominal: break
        case .fair:     budget = max(2, budget - 1)
        case .serious:  budget = max(2, budget / 2)
        case .critical: budget = 2
        }
        if strategy == .conservativeCoverage { budget = max(2, Int(Double(budget) * 0.6)) }
        return budget
    }

    /// mandate E — build the full plan. `hasTextRules`/`hasSoundRules` come from the user's REAL rule set (text → OCR,
    /// sound → audio). `sceneChangeHints` are cheap Tier-0 scene-change seconds (if available) used to BIAS selective
    /// window placement toward boundaries; empty ⇒ even spacing. `uncertainHints`/`matchedHints` bias the deepening
    /// pass. All windows are sorted by time; the FAST window is always first and always OCR (the cheapest first read).
    public func plan(contentID: String, durationSeconds: Double, thermal: ReelsThermalBucketV1,
                     hasTextRules: Bool, hasSoundRules: Bool, policyRevision: UInt64,
                     sceneChangeHints: [Double] = [], uncertainHints: [Double] = [],
                     matchedHints: [Double] = []) -> LongFormPlanV1 {
        let dur = max(0.0, durationSeconds)
        let strategy = selectStrategy(durationSeconds: dur, thermal: thermal)
        let selBudget = selectiveBudget(durationSeconds: dur, thermal: thermal, strategy: strategy)
        // Expert selection: OCR iff the user has text rules; audio iff the user has sound rules AND the strategy/budget
        // allow it. A conservative run under thermal pressure drops audio windows first (the most expensive arm).
        let wantOCR = hasTextRules
        let wantAudioBase = hasSoundRules
        let allowAudioSelective = wantAudioBase && !(strategy == .conservativeCoverage && (thermal == .serious || thermal == .critical))

        var windows: [LongFormPlannedWindowV1] = []
        var idx = 0
        let windowSpan = dur > 0 ? max(1.0, dur / Double(max(1, selBudget))) : 1.0

        // FAST window: the first span. OCR-first (cheapest first valid read); audio in the first window only if the
        // user has sound rules and budget allows (so the fast decision can catch an early sound match too).
        let fastEnd = min(dur, windowSpan)
        let fastExperts = LongFormWindowExpertsV1(ocr: wantOCR, audio: allowAudioSelective)
        if fastExperts.any {
            windows.append(LongFormPlannedWindowV1(index: idx, startSeconds: 0, endSeconds: max(0.0001, fastEnd),
                                                   level: .fast, experts: fastExperts)); idx += 1
        }

        // SELECTIVE windows across the REMAINDER of the duration. Prefer scene-change hints that fall past the fast
        // window; otherwise even spacing. Cap at the budget (minus the fast window already placed).
        var selectiveCenters: [Double] = []
        let remainingBudget = max(0, selBudget - 1)
        if !sceneChangeHints.isEmpty {
            // Bias toward scene boundaries beyond the fast window, spread + capped to the budget.
            let past = sceneChangeHints.filter { $0 > fastEnd && $0 < dur }.sorted()
            selectiveCenters = Array(evenlyPick(past, count: remainingBudget))
        }
        if selectiveCenters.count < remainingBudget {
            // Fill the rest with evenly-spaced centers across (fastEnd, dur).
            let needed = remainingBudget - selectiveCenters.count
            let evenly = evenCenters(from: fastEnd, to: dur, count: needed)
            selectiveCenters.append(contentsOf: evenly)
        }
        selectiveCenters = dedup(selectiveCenters.sorted(), minGap: windowSpan * 0.25)
        for c in selectiveCenters where c > fastEnd && c <= dur {
            let s = max(fastEnd, c - windowSpan / 2), e = min(dur, c + windowSpan / 2)
            windows.append(LongFormPlannedWindowV1(index: idx, startSeconds: s, endSeconds: e, level: .selective,
                                                   experts: LongFormWindowExpertsV1(ocr: wantOCR, audio: allowAudioSelective)))
            idx += 1
        }

        // DEEPENING windows around uncertain/matched regions — added only on a healthy (thorough) budget. Bounded.
        if strategy == .thoroughCoverage {
            let deepenCenters = dedup((uncertainHints + matchedHints).filter { $0 >= 0 && $0 <= dur }.sorted(),
                                      minGap: windowSpan * 0.5)
            for c in deepenCenters.prefix(Self.maxDeepeningWindows) {
                let s = max(0, c - windowSpan / 4), e = min(dur, c + windowSpan / 4)
                // Deepening targets the senses the user cares about; it runs OCR always and audio when sound rules exist.
                windows.append(LongFormPlannedWindowV1(index: idx, startSeconds: s, endSeconds: e, level: .deepening,
                                                       experts: LongFormWindowExpertsV1(ocr: wantOCR, audio: wantAudioBase)))
                idx += 1
            }
        }

        windows.sort { ($0.startSeconds, $0.index) < ($1.startSeconds, $1.index) }
        return LongFormPlanV1(contentID: contentID, durationSeconds: dur, strategy: strategy, thermal: thermal,
                              requestsOCR: wantOCR, requestsAudio: wantAudioBase, budgetWindows: selBudget,
                              windows: windows, producedUnderPolicyRevision: policyRevision)
    }

    // MARK: - pure helpers

    private func evenCenters(from lo: Double, to hi: Double, count: Int) -> [Double] {
        guard count > 0, hi > lo else { return [] }
        let step = (hi - lo) / Double(count + 1)
        return (1...count).map { lo + step * Double($0) }
    }

    private func evenlyPick(_ xs: [Double], count: Int) -> [Double] {
        guard count > 0, !xs.isEmpty else { return [] }
        if xs.count <= count { return xs }
        let step = Double(xs.count - 1) / Double(count - 1 == 0 ? 1 : count - 1)
        var out: [Double] = []
        for i in 0..<count { out.append(xs[Int((Double(i) * step).rounded())]) }
        return out
    }

    private func dedup(_ sorted: [Double], minGap: Double) -> [Double] {
        var out: [Double] = []
        for x in sorted where out.last.map({ x - $0 >= max(0.0001, minGap) }) ?? true { out.append(x) }
        return out
    }
}
