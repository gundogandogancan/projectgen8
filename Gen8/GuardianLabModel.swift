//
//  GuardianLabModel.swift — bridges SwiftUI (MainActor) to the GuardianCore engine.
//  All intelligence lives in GuardianCore (tested headless). This is presentation glue only.
//
import Foundation
import Observation
import GuardianCore
import GuardianIntelligence

/// A debug row for the GuardianLab internal diagnostics (REAL/UNAVAILABLE/UNKNOWN per head).
struct DebugHead: Identifiable { let id: String; let state: String }

@MainActor
@Observable
final class GuardianLabModel {
    private let clock = SystemMonotonicClock()
    private let pipeline: PreExposurePipeline
    let diagnostics: Diagnostics
    private let events: RecordingEventSink
    private let scheduler: LookAheadScheduler
    private let temporal = TemporalGuardian()

    // Onboarding-editable Personal Algorithm (inspectable).
    var mode: GuardianMode = .balance
    var threshold: Double = 7.5
    private(set) var profile: PersonalAlgorithmProfile = GuardianLabFixtures.defaultProfile

    // Short-form feed
    private let feed: [ContentCandidate]
    private(set) var feedIndex = 0
    private(set) var surface = GuardianSurfaceState(tone: .unknown, label: "Idle", scoreDisplay: "?", coverage: .unknown)
    private(set) var explanation = "Set your algorithm, then enter GuardianLab."
    private(set) var lastDecisionCached = false
    private(set) var lastReason = ""

    // Long-form
    var playhead: Double = 0
    var useWrongVersion = false
    var temporalMode: TemporalGuardMode = .normal
    private(set) var temporalBanner: String? = nil
    private(set) var temporalStatus = "idle"
    var showAskSheet = false
    private(set) var pendingSkipSegment: TemporalSegment? = nil

    // PROMPT 006 §3/§4 — Guardian on/off (single source of truth). Control Center extension is device-gated;
    // this in-app toggle is the fallback and drives the same GuardianActivationController.
    private let activation = GuardianActivationController(store: InMemoryActivationStore(.enabled))
    var guardianEnabled: Bool = true {
        didSet {
            activation.set(guardianEnabled ? .enabled : .disabled)
            #if canImport(ActivityKit)
            if #available(iOS 16.1, *) {
                // User-initiated Live Activity lifecycle: Guardian ON starts it, OFF ends it (single source of truth).
                if guardianEnabled {
                    GuardianLiveActivityController.shared.start(contentID: "guardianlab",
                                                                surface: .guardianOn,
                                                                label: String(localized: "Guardian on"))
                } else {
                    Task { await GuardianLiveActivityController.shared.end(reason: "guardian-off") }
                }
            }
            #endif
        }
    }
    var guardianActivationLabel: String { activation.state.rawValue }

    init() {
        let parts = GuardianLabFixtures.makePipeline(clock: clock)
        pipeline = parts.pipeline
        diagnostics = parts.diagnostics
        events = parts.events
        scheduler = LookAheadScheduler(pipeline: parts.pipeline, diagnostics: parts.diagnostics,
                                       profile: GuardianLabFixtures.defaultProfile)
        feed = [GuardianLabFixtures.beneficial(), GuardianLabFixtures.lowValue(),
                GuardianLabFixtures.diseaseFactual(), GuardianLabFixtures.shieldedEntity(),
                GuardianLabFixtures.unknown()]
    }

    func applyOnboarding() {
        var p = PersonalAlgorithmProfile(mode: mode, minimumPersonalScore: threshold)
        // Demo rules so the policy scenarios are observable in the lab.
        p.shieldRules = [SemanticShieldRule(kind: .entity, value: "RivalTeam", hard: true)]
        p.positiveExposure = PositiveExposurePolicy(avoid: [.disease])
        profile = p
        Task { await scheduler.setProfile(p) }
    }

    var currentCandidate: ContentCandidate { feed[min(feedIndex, feed.count - 1)] }
    var feedCount: Int { feed.count }

    func decideCurrent() async {
        let r = await pipeline.decide(candidate: currentCandidate, profile: profile)
        surface = r.surface
        explanation = r.decision.explanation
        lastDecisionCached = r.trace.cacheHit
        lastReason = r.decision.reason.rawValue
        // Preload bounded look-ahead (NEXT +1/+2/+3) — cache-first, cancellable.
        let ahead = Array(feed.dropFirst(feedIndex + 1).prefix(3))
        await scheduler.update(candidates: ahead)
        await scheduler.pump()
    }

    func advance() async {
        if feedIndex < feed.count - 1 { feedIndex += 1 }
        await decideCurrent()
    }

    func restartFeed() async {
        feedIndex = 0
        await decideCurrent()
    }

    // MARK: Long-form
    var temporalGraph: TemporalGraphStub {
        useWrongVersion ? GuardianLabFixtures.wrongVersionTemporalGraph()
                        : GuardianLabFixtures.correctTemporalGraph()
    }
    var temporalIdentity: ContentIdentityResult { GuardianLabFixtures.longFormIdentity() }
    var temporalDuration: Double { GuardianLabFixtures.correctTemporalGraph().durationSeconds }

    func tickTemporal() {
        let g = temporalGraph
        if let seg = temporal.shouldWarn(graph: g, playhead: playhead, leadSeconds: 20) {
            let cats = seg.flaggedCategories.map { $0.rawValue }.joined(separator: ", ")
            temporalBanner = "Flagged segment ahead at \(Int(seg.startSeconds))s (\(cats))."
        } else {
            temporalBanner = nil
        }
        let ahead = temporal.analysisAheadState(playhead: playhead,
                                                verifiedUntil: g.durationSeconds, analyzingUntil: g.durationSeconds)
        temporalStatus = "lead=\(ahead.rawValue) · graph=\(g.versionTag) · id=\(temporalIdentity.versionTag)"
    }

    func requestSkip() {
        let g = temporalGraph
        guard let seg = temporal.upcomingFlaggedSegment(graph: g, afterSeconds: playhead)
                ?? g.segments.first(where: { $0.isFlagged }) else { return }
        switch temporal.evaluateSkip(segment: seg, identity: temporalIdentity, graph: g, mode: temporalMode) {
        case .autoSkip:
            playhead = seg.endSeconds   // skip ≠ delete — resume after the segment
            temporalStatus = "AUTO_SKIP → resumed at \(Int(seg.endSeconds))s"
        case .ask:
            pendingSkipSegment = seg; showAskSheet = true
        case .warn:
            temporalBanner = "Warning: flagged segment ahead (guidance mode)."
        case .refusedVersionMismatch:
            temporalStatus = "SKIP REFUSED — identity/version mismatch → WARN/UNKNOWN (no blind seek)."
        }
    }

    func confirmSkip() {
        if let s = pendingSkipSegment { playhead = s.endSeconds; temporalStatus = "User skipped → \(Int(s.endSeconds))s" }
        showAskSheet = false; pendingSkipSegment = nil
    }
    func continueThrough() {
        showAskSheet = false; pendingSkipSegment = nil; temporalStatus = "User chose to continue."
    }

    var snapshot: ResourceSnapshot { diagnostics.snapshot }

    // MARK: Real preflight debug (PROMPT 002A §18) — internal/debug only; exposes REAL vs UNAVAILABLE heads.
    private(set) var preflightHeads: [DebugHead] = []
    private(set) var preflightSummary = "Run real preflight to see live provider routing."

    func runRealPreflightDebug() async {
        guard let img = SyntheticImage.textImage("LEARNING GUARDIAN"), let png = SyntheticImage.pngData(img) else {
            preflightSummary = "synthetic image unavailable on this device"; return
        }
        let env = await FastPreflightEngineV1().run(imageBytes: png, providedText: nil)
        preflightHeads = env.heads.sorted { $0.key < $1.key }.map { DebugHead(id: $0.key, state: $0.value.state.rawValue) }
        // P003 §29: run specialist heads on a demo text + the OCR text, show structured signals.
        let demo = "A massive earthquake struck the city. Hurry, last chance — subscribe now!"
        let mdd = MortalityDiseaseDisasterHead().classify(text: demo, language: "en")
        let manip = AttentionManipulationHead().analyze(text: demo, language: "en")
        let mddLabels = (mdd.value ?? []).map { $0.rawValue }.joined(separator: ",")
        preflightHeads.append(DebugHead(id: "mdd(demo)", state: mddLabels.isEmpty ? "NONE" : mddLabels))
        preflightHeads.append(DebugHead(id: "manip(demo)", state: "count \(manip.value?.total ?? 0)"))
        // P004 §30: whole-video coarse-analysis demo (sampler + deepening over a synthetic 5-min timeline).
        let sampler = WholeVideoSampler()
        let plan = sampler.plan(durationSeconds: 300, mode: .balanced)
        preflightHeads.append(DebugHead(id: "wholeVideo(samples)", state: "\(plan.timestampsSeconds.count) @balanced"))
        let ocr = (env.ocrText ?? "").prefix(24)
        preflightSummary = "route=\(env.route.rawValue) · mode=\(env.resourceMode.rawValue) · id=\(env.identityState?.rawValue ?? "?") · lang=\(env.language ?? "?") · ocr=\(ocr) · wv=\(plan.strategy)"
    }
}
