//
//  GuardianLabModel.swift — bridges SwiftUI (MainActor) to the GuardianCore engine.
//  All intelligence lives in GuardianCore (tested headless). This is presentation glue only.
//
import Foundation
import Observation
import GuardianCore
import GuardianIntelligence
// NOTE: GuardianMedia types (GuardianReasonCodeV1, GuardianObservationHeartbeatV1, CaptureTokenV1, …) are
// SOURCE-compiled directly into this app target (see Gen8.xcodeproj — same pattern as Tier1IdentityResolutionV1),
// so they are part of this module. There is intentionally NO `import GuardianMedia` (the app links GuardianCore +
// GuardianIntelligence as products; GuardianMedia is dual-compiled by file, not linked as a module).

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

    // P3 — the REAL observation-session state machine (GuardianCore). iOS capability = system-picker-per-session.
    // Drives the single user-visible state (GuardianUserVisibleState) that the HUD and Live Activity both read.
    private let runtime = GuardianRuntimeManager(platform: "iOS")
    /// The current per-content native surface for the resolved item, or nil until analysis produces one. Reset to
    /// nil on every resolved-identity change so a stale CAUTION/SHIELD can never survive across content.
    private(set) var currentSurface: NativeSurfaceState? = nil
    /// The single user-visible session state (projection of the real core enums — never parallel semantics).
    private(set) var userVisibleState: GuardianUserVisibleState = .off
    /// B3 — the REAL reason code behind the current state (from the engine/heartbeat, never fabricated). Drives the
    /// "Neden?" (Why?) tap-through. nil when no decision/evidence exists yet (shown honestly as "no explanation").
    private(set) var liveReasonCode: GuardianReasonCodeV1? = nil
    /// True while a real content change is being re-evaluated (B2 RE-EVALUATING transition; real-state-driven).
    private(set) var isReEvaluating = false

    /// B3 — the user-facing "Neden?" explanation (Turkish), generated ONLY from the real reason code. When there is
    /// no substantiated reason, we say so honestly rather than inventing one.
    var whyExplanation: String {
        if !guardianEnabled { return GuardianReasonCodeV1.guardianOff.turkishExplanation }
        if !labMode, heartbeatFreshness != .active {
            return heartbeatIPCActive
                ? GuardianReasonCodeV1.sessionNotObserving.turkishExplanation
                : "Yayın süreci ile bağlantı kurulamadı (App Group IPC yok). Gözlem doğrulanamıyor."
        }
        return liveReasonCode?.turkishExplanation ?? "Bu durum için henüz açıklanacak bir kanıt yok."
    }

    // PROMPT 006 §3/§4 — Guardian on/off (single source of truth). Control Center extension is device-gated;
    // this in-app toggle is the fallback and drives the same GuardianActivationController.
    private let activation = GuardianActivationController(store: InMemoryActivationStore(.enabled))

    // A3 — LAB vs PRODUCT mode. The ONLY place the synthetic userStarted/osConfirmedActive transitions are allowed
    // is EXPLICIT lab mode. In product mode, observation-active is derived from the REAL broadcast heartbeat
    // (App Group freshness); the in-app toggle only expresses INTENT (guardianOn/off), never "the broadcast started".
    var labMode: Bool = true
    /// A3 — the live freshness classification of the broadcast heartbeat (product mode). Drives the honest
    /// ACTIVE / DEGRADED / UNAVAILABLE semantics so synthetic data is never presented as real observation.
    private(set) var heartbeatFreshness: GuardianObservationHeartbeatBridgeV1.Freshness = .absent
    /// The App Group suite the broadcast extension writes its heartbeat to (nil → DEGRADED: no cross-process IPC).
    private let heartbeatSuite = UserDefaults(suiteName: GuardianActivationBridge.appGroupID)
    private var heartbeatTimer: Timer?

    var guardianEnabled: Bool = true {
        didSet {
            activation.set(guardianEnabled ? .enabled : .disabled)
            if guardianEnabled {
                runtime.session.apply(.guardianOn)            // OFF → permissionRequired (iOS = systemPickerRequired)
                if labMode {
                    // LAB ONLY (explicit): simulate the OS confirming the broadcast — a controlled harness, never
                    // the product claim. Device/product path flips to ACTIVE only via the real heartbeat below.
                    runtime.session.apply(.userStarted)
                    runtime.session.apply(.osConfirmedActive)
                } else {
                    // PRODUCT: the toggle is intent only. The session stays STARTING until a FRESH real broadcast
                    // heartbeat proves observation is actually live. Start polling for it.
                    startHeartbeatPolling()
                }
            } else {
                runtime.session.apply(.guardianOff)           // → OFF from anywhere (never looks protected)
                currentSurface = nil
                stopHeartbeatPolling()
                heartbeatFreshness = .absent
            }
            refreshUserVisibleState()
            #if canImport(ActivityKit)
            if #available(iOS 16.1, *) {
                // User-initiated Live Activity lifecycle: Guardian ON starts it, OFF ends it (single source of truth).
                if guardianEnabled {
                    GuardianLiveActivityController.shared.start(contentID: "guardianlab",
                                                                surface: userVisibleState.nativeSurface,
                                                                label: userVisibleState.label)
                } else {
                    Task { await GuardianLiveActivityController.shared.end(reason: "guardian-off") }
                }
            }
            #endif
        }
    }
    var guardianActivationLabel: String { activation.state.rawValue }

    // MARK: A3 — real broadcast heartbeat polling (product mode)

    /// Honest IPC diagnostic for the Live Insight card: ACTIVE vs DEGRADED(no App Group). Never a silent fallback.
    var heartbeatIPCActive: Bool { heartbeatSuite != nil }

    private func startHeartbeatPolling() {
        stopHeartbeatPolling()
        pollHeartbeatOnce()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollHeartbeatOnce() }
        }
        RunLoop.main.add(t, forMode: .common)
        heartbeatTimer = t
    }
    private func stopHeartbeatPolling() { heartbeatTimer?.invalidate(); heartbeatTimer = nil }

    /// Read the latest heartbeat, classify freshness, and drive the REAL session machine from broadcast evidence
    /// (NOT the in-app toggle). FRESH → osConfirmedActive (ACTIVE); STALE/ABSENT → interrupted (STARTING/UNAVAILABLE).
    func pollHeartbeatOnce() {
        guard guardianEnabled, !labMode else { return }
        let hb = GuardianObservationHeartbeatBridgeV1.read(suite: heartbeatSuite)
        let now = Date().timeIntervalSince1970
        heartbeatFreshness = GuardianObservationHeartbeatBridgeV1.classify(hb, nowEpoch: now)
        switch heartbeatFreshness {
        case .active:
            // Real broadcast confirmed live. Advance the session to ACTIVE (idempotent transitions).
            if runtime.session.state == .permissionRequired { runtime.session.apply(.userStarted) }
            runtime.session.apply(.osConfirmedActive)
            // Project the REAL surface + reason code the extension published onto the per-content surface.
            if let hb {
                currentSurface = Self.surface(fromRaw: hb.surfaceRaw)
                liveReasonCode = GuardianReasonCodeV1(rawValue: hb.reasonCodeRaw)
            }
        case .stale, .absent:
            // No fresh evidence — the broadcast is NOT (or no longer) live. Never claim ACTIVE. Degrade honestly:
            // a previously-active session goes interrupted (→ STARTING/recoverable); surface is cleared.
            if runtime.session.state == .active { runtime.session.apply(.osInterrupted) }
            currentSurface = nil
            liveReasonCode = heartbeatIPCActive ? .sessionNotObserving : .sessionNotObserving
        }
        refreshUserVisibleState()
    }

    private static func surface(fromRaw raw: String) -> NativeSurfaceState? {
        switch raw {
        case "GUARDIAN_ON": return .guardianOn
        case "CAUTION": return .caution
        case "SHIELD_MATCH": return .shieldMatch
        case "UNKNOWN": return .unknown
        case "OFF": return .off
        default: return nil   // empty = observing, no per-content decision yet
        }
    }

    /// Recompute the single user-visible state from the REAL core enums and push it to the Live Activity. No new
    /// safety semantics: a pure projection via GuardianSessionProjection. Called on toggle + every decision.
    func refreshUserVisibleState() {
        userVisibleState = GuardianSessionProjection.userVisible(
            session: runtime.session.state, activation: activation.state, surface: currentSurface)
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *), guardianEnabled {
            GuardianLiveActivityController.shared.update(contentID: "guardianlab",
                                                         surface: userVisibleState.nativeSurface,
                                                         label: userVisibleState.label)
        }
        #endif
    }

    /// P3 law: a content change invalidates the prior decision. Reset the per-content surface → OBSERVING so a
    /// stale CAUTION/SHIELD cannot survive across resolved items. Call on every resolved-identity change.
    /// B2: entering RE-EVALUATING is a REAL state (a new identity with no decision yet), not decoration.
    func onResolvedIdentityChange() {
        currentSurface = nil            // the old A-decision drops INSTANTLY (no stale CAUTION/SHIELD survives)
        isReEvaluating = true           // RE-EVALUATING appears until the new decision lands (B2)
        liveReasonCode = .contentChangedReset   // honest: "önceki değerlendirme sıfırlandı"
        refreshUserVisibleState()
    }

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
        // P3/P4: project the lab decision's tone onto the lock-safe native surface for THIS resolved item, then
        // refresh the user-visible state + Live Activity. CAUTION/strongCaution → CAUTION; unknown → UNKNOWN
        // (honest abstention, never "safe"); aligned/neutral → GUARDIAN_ON. No numeric score crosses to the surface.
        currentSurface = Self.nativeSurface(for: surface.tone)
        // B3 — map the REAL decision tone to a real reason code (same resolved item). No fabricated reasons.
        liveReasonCode = Self.reasonCode(for: surface.tone)
        isReEvaluating = false
        refreshUserVisibleState()
        // Preload bounded look-ahead (NEXT +1/+2/+3) — cache-first, cancellable.
        let ahead = Array(feed.dropFirst(feedIndex + 1).prefix(3))
        await scheduler.update(candidates: ahead)
        await scheduler.pump()
    }

    /// B3 — the reason code for a lab decision tone. Aligned/neutral with analysis = benign text/visual evidence;
    /// caution = shield/caution signal; unknown = honest abstention (identity/evidence not sufficient).
    static func reasonCode(for tone: GuardianSurfaceState.Tone) -> GuardianReasonCodeV1 {
        switch tone {
        case .aligned, .neutral:        return .textEvidenceBenign
        case .caution, .strongCaution:  return .textEvidenceMatchedShield
        case .unknown:                  return .visualEvidenceInsufficient
        }
    }

    /// Pure projection of the lab's content tone onto the lock-safe surface (no new safety semantics).
    static func nativeSurface(for tone: GuardianSurfaceState.Tone) -> NativeSurfaceState {
        switch tone {
        case .aligned, .neutral: return .guardianOn
        case .caution, .strongCaution: return .caution
        case .unknown: return .unknown
        }
    }

    func advance() async {
        if feedIndex < feed.count - 1 { feedIndex += 1 }
        // A feed advance IS a content change → invalidate the prior decision's surface (no stale CAUTION/SHIELD).
        onResolvedIdentityChange()
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
