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
        if sessionIdle { return GuardianReasonCodeV1.observingIdle.turkishExplanation }
        if !labMode, heartbeatFreshness != .active {
            return heartbeatIPCActive
                ? GuardianReasonCodeV1.sessionNotObserving.turkishExplanation
                : "Yayın süreci ile bağlantı kurulamadı (App Group IPC yok). Gözlem doğrulanamıyor."
        }
        return liveReasonCode?.turkishExplanation ?? "Bu durum için henüz açıklanacak bir kanıt yok."
    }

    /// E-lane — the per-EVENT "Neden?" explanation (Turkish), reusing the SAME GuardianReasonCodeV1 mapping as the
    /// Live Insight card. An event with no reason code (pure lifecycle) is explained honestly as having none.
    func whyForEvent(_ event: GuardianTimelineEventV1) -> String {
        guard let raw = event.reasonCodeRaw, let code = GuardianReasonCodeV1(rawValue: raw) else {
            return "Bu olay yalnızca oturum döngüsünü bildirir; açıklanacak ek bir kanıt yok."
        }
        return code.turkishExplanation
    }

    // PROMPT 006 §3/§4 — Guardian on/off (single source of truth). Control Center extension is device-gated;
    // this in-app toggle is the fallback and drives the same GuardianActivationController.
    private let activation = GuardianActivationController(store: InMemoryActivationStore(.enabled))

    // A3 — LAB vs PRODUCT mode. The ONLY place the synthetic userStarted/osConfirmedActive transitions are allowed
    // is EXPLICIT lab mode. In product mode, observation-active is derived from the REAL broadcast heartbeat
    // (App Group freshness); the in-app toggle only expresses INTENT (guardianOn/off), never "the broadcast started".
    /// A3 — PRODUCT MODE IS THE DEFAULT. Observation-active is derived ONLY from a REAL broadcast heartbeat
    /// (App Group freshness); the in-app toggle expresses INTENT, never "the broadcast started". Lab simulation
    /// (synthetic userStarted/osConfirmedActive) is available ONLY by explicitly enabling it in Developer Mode —
    /// gated below so a normal user turning Guardian ON never sees a fabricated OBSERVING state.
    var labMode: Bool = false
    /// A3 — the live freshness classification of the broadcast heartbeat (product mode). Drives the honest
    /// ACTIVE / DEGRADED / UNAVAILABLE semantics so synthetic data is never presented as real observation.
    private(set) var heartbeatFreshness: GuardianObservationHeartbeatBridgeV1.Freshness = .absent
    /// C/E-lane — the live "Bu Oturum" (This Session) timeline, read from the extension's bounded App Group mirror.
    /// Empty when no fresh session snapshot exists (honest: nothing to show). Session-scoped + TTL via the reader.
    private(set) var timelineEvents: [GuardianTimelineEventV1] = []
    /// The session id of the broadcast we are currently observing (from the heartbeat). Used to scope BOTH the
    /// freshness check (A1) and the timeline reader (D) so a prior session's state is never shown as current.
    private(set) var observedSessionID: String? = nil
    /// B2 — the LIVE personal-shield policy revision (bumped whenever the user edits a rule, shared via App Group).
    /// If the heartbeat the extension published was produced under an OLDER revision, the per-content surface it
    /// carries is STALE (the user changed a rule since) and must not be presented as current.
    private let shieldStore = PersonalShieldSharedStoreV1()
    private(set) var policyStale = false
    /// LAB-MODE timeline writer (RAM-only, suite=nil → no IPC mirror). In lab mode there is no real broadcast
    /// extension to read from, so the "Bu Oturum" feed is driven by the REAL GuardianCore lab decisions on the
    /// synthetic fixtures. These are genuine engine events (not fabricated) over SYNTHETIC content, surfaced so the
    /// A→B content-switch walkthrough is demonstrable on the simulator; the UI labels the session as lab.
    @ObservationIgnored
    private let labTimeline = GuardianSessionTimelineWriterV1(sessionID: "lab-\(UUID().uuidString)", suite: nil)
    private var labIdentityRevision = 0
    /// The App Group suite the broadcast extension writes its heartbeat to (nil → DEGRADED: no cross-process IPC).
    private let heartbeatSuite = UserDefaults(suiteName: GuardianActivationBridge.appGroupID)
    private var heartbeatTimer: Timer?

    // §5 — USER-CONTROLLED ACTIVE/IDLE. `sessionIdle` mirrors the App Group mode flag the extension observes. The
    // user flips it from the app (or the Control Center toggle, which writes the SAME flag). Idle is honest: the
    // broadcast stays LIVE but heavy analysis is paused; we never claim "koruma aktif" while idle (§5.4).
    private(set) var sessionIdle = GuardianSessionModeBridgeV1.isIdle(suite: UserDefaults(suiteName: GuardianActivationBridge.appGroupID))
    /// True iff the App Group IPC is available (the idle toggle can actually reach the extension). Honest when not.
    var idleToggleReachesExtension: Bool { heartbeatSuite != nil }

    // §B — DESIRED vs APPLIED. `sessionIdle` above is the DESIRED mode (what the user tapped). `appliedModeIdle` is
    // what the extension has ACTUALLY confirmed it applied (nil = it hasn't acked yet). `appliedModeIsCurrent` is true
    // only when a fresh ack acked the user's LATEST desire — so the UI shows an honest İsteniyor/Uygulandı divergence
    // while a tap is still crossing to the extension, and never claims "applied" before the extension consumed it.
    private(set) var appliedModeIdle: Bool? = nil
    private(set) var appliedModeIsCurrent: Bool = false
    /// §B — refresh the applied-mode ack from the App Group (called on the heartbeat poll cadence). Honest when the
    /// extension is not live / has not acked yet (appliedModeIdle = nil).
    private func refreshAppliedMode(nowEpoch: Double) {
        let ack = GuardianSessionModeBridgeV1.readAppliedAck(suite: heartbeatSuite)
        appliedModeIdle = ack.map { $0.appliedMode == .idle }
        appliedModeIsCurrent = GuardianSessionModeBridgeV1.appliedIsCurrent(suite: heartbeatSuite, nowEpoch: nowEpoch)
    }

    // §B — the HONEST two-fact projection: BROADCAST (OS feed physically live?) and ANALYSIS (heavy path running?).
    // Never one "protected" flag. The view renders both separately.
    var observationProjection: GuardianObservationProjectionV1 {
        GuardianObservationProjectionV1.project(guardianEnabled: guardianEnabled,
                                                broadcastFresh: heartbeatFreshness == .active,
                                                userIdle: sessionIdle)
    }
    /// §B — true when the desired mode and the extension's confirmed applied mode disagree (a tap is still in flight,
    /// or the extension is paused for a different reason). Drives the honest "İsteniyor ≠ Uygulandı" row.
    var sessionModeDiverges: Bool {
        guard let applied = appliedModeIdle, appliedModeIsCurrent else { return false }
        return applied != sessionIdle
    }

    /// §5.5 — one-tap ACTIVE/IDLE toggle. Writes the mode over the App Group (the extension polls it on its heartbeat
    /// cadence) and refreshes the user-visible state so the app reflects idle immediately. Honest about reachability.
    func toggleSessionIdle() { setSessionIdle(!sessionIdle) }
    func setSessionIdle(_ idle: Bool) {
        sessionIdle = idle
        GuardianSessionModeBridgeV1.write(idle ? .idle : .active, suite: heartbeatSuite)
        if idle {
            // Entering idle: drop any per-content surface so a stale positive can't persist; show OBSERVING_IDLE.
            currentSurface = nil
            liveReasonCode = .observingIdle
            isReEvaluating = false
        } else {
            // Waking: old evidence is not reused — return to observing-no-decision until new evidence lands.
            currentSurface = nil
            liveReasonCode = .observingNoDecisionYet
        }
        refreshUserVisibleState()
    }

    var guardianEnabled: Bool = GuardianAnalysisGateV1.isEnabled(suite: UserDefaults(suiteName: GuardianActivationBridge.appGroupID)) {
        didSet {
            activation.set(guardianEnabled ? .enabled : .disabled)
            // §A — write the product on/off intent to the SHARED App Group key so the RUNNING broadcast extension
            // consumes it as a real analysis gate (OFF → heavy analysis genuinely stops in-session). Same key the
            // Control Center ON/OFF intent writes, so the app and the control agree with one source of truth.
            GuardianAnalysisGateV1.setEnabled(guardianEnabled, suite: heartbeatSuite)
            if guardianEnabled {
                runtime.session.apply(.guardianOn)            // OFF → permissionRequired (iOS = systemPickerRequired)
                if labMode {
                    // LAB ONLY (explicit): simulate the OS confirming the broadcast — a controlled harness, never
                    // the product claim. Device/product path flips to ACTIVE only via the real heartbeat below.
                    runtime.session.apply(.userStarted)
                    runtime.session.apply(.osConfirmedActive)
                    // Lab session started — the first real (synthetic-content) timeline event.
                    labTimeline.record(category: .sessionStarted, status: .active,
                                       reasonCodeRaw: GuardianReasonCodeV1.observingNoDecisionYet.rawValue,
                                       identityRevision: labIdentityRevision, nowEpoch: Date().timeIntervalSince1970)
                    timelineEvents = labTimeline.events
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
                // §5.5 — Guardian OFF resets the user-controlled idle choice (a fresh session starts ACTIVE).
                sessionIdle = false
                GuardianSessionModeBridgeV1.clear(suite: heartbeatSuite)
                // E-lane: Guardian OFF stops the event feed and drops any observed-session state (no stale history).
                timelineEvents = []
                observedSessionID = nil
                labTimeline.clear()
            }
            refreshUserVisibleState()
            #if canImport(ActivityKit)
            if #available(iOS 16.1, *) {
                // User-initiated Live Activity lifecycle: Guardian ON starts it, OFF ends it (single source of truth).
                if guardianEnabled {
                    GuardianLiveActivityController.shared.start(contentID: "guardianlab",
                                                                surface: userVisibleState.nativeSurface,
                                                                label: userVisibleState.label,
                                                                marker: heatMarker,
                                                                title: userVisibleState.islandTitle,
                                                                displayStyleRaw: AppSettings.shared.effectiveDisplayStyleRaw)
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
        // A1 — adopt the session id the live heartbeat reports, then classify freshness SCOPED to it so a stale
        // old-session heartbeat (same time window, different session) can never read as the current session live.
        if GuardianObservationHeartbeatBridgeV1.isFresh(hb, nowEpoch: now) { observedSessionID = hb?.sessionID }
        heartbeatFreshness = GuardianObservationHeartbeatBridgeV1.classify(hb, nowEpoch: now,
                                                                           expectedSessionID: observedSessionID)
        switch heartbeatFreshness {
        case .active:
            // Real broadcast confirmed live. Advance the session to ACTIVE (idempotent transitions).
            if runtime.session.state == .permissionRequired { runtime.session.apply(.userStarted) }
            runtime.session.apply(.osConfirmedActive)
            // §5.4 — while the user has chosen IDLE, the broadcast is live but we do NOT adopt a per-content surface
            // (no "koruma aktif" claim). The projection renders OBSERVING_IDLE regardless of any surface in the hb.
            if sessionIdle {
                currentSurface = nil
                liveReasonCode = .observingIdle
                isReEvaluating = false
                pollTimelineOnce(nowEpoch: now)
                refreshUserVisibleState()
                return
            }
            // Project the REAL surface + reason code the extension published onto the per-content surface.
            if let hb {
                // B2 — a decision produced under an older policy revision is STALE (the user changed a rule since).
                // Honest: drop the stale per-content surface + show RE-EVALUATING, never a surface from old rules.
                let live = shieldStore.policyRevision
                policyStale = PersonalShieldLoadedPolicyV1.isStaleDecision(stamped: hb.policyRevision, liveRevision: live)
                if policyStale {
                    currentSurface = nil
                    liveReasonCode = .contentChangedReset
                    isReEvaluating = true
                } else {
                    currentSurface = Self.surface(fromRaw: hb.surfaceRaw)
                    liveReasonCode = GuardianReasonCodeV1(rawValue: hb.reasonCodeRaw)
                    isReEvaluating = false
                }
            }
        case .stale, .absent:
            // No fresh evidence — the broadcast is NOT (or no longer) live. Never claim ACTIVE. Degrade honestly:
            // a previously-active session goes interrupted (→ STARTING/recoverable); surface is cleared.
            if runtime.session.state == .active { runtime.session.apply(.osInterrupted) }
            currentSurface = nil
            liveReasonCode = .sessionNotObserving
        }
        pollTimelineOnce(nowEpoch: now)
        refreshAppliedMode(nowEpoch: now)   // §B — refresh the extension's confirmed applied mode (İsteniyor/Uygulandı)
        refreshUserVisibleState()
    }

    /// C/E-lane — read the extension's bounded timeline mirror, scoped to the observed session + TTL (pure reader).
    /// Guardian OFF → the feed stops (empties). A stale / prior-session snapshot yields an empty feed (honest).
    func pollTimelineOnce(nowEpoch: Double) {
        guard guardianEnabled, !labMode else { timelineEvents = []; return }
        let snap = GuardianSessionTimelineReaderV1.readSnapshot(suite: heartbeatSuite)
        timelineEvents = GuardianSessionTimelineReaderV1.liveEvents(snap, expectedSessionID: observedSessionID,
                                                                    nowEpoch: nowEpoch)
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
            session: runtime.session.state, activation: activation.state, surface: currentSurface,
            userIdle: sessionIdle)
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *), guardianEnabled {
            GuardianLiveActivityController.shared.update(contentID: "guardianlab",
                                                         surface: userVisibleState.nativeSurface,
                                                         label: userVisibleState.label,
                                                         marker: heatMarker,
                                                         title: userVisibleState.islandTitle,
                                                         displayStyleRaw: AppSettings.shared.effectiveDisplayStyleRaw)
        }
        #endif
    }

    /// The LIVE heat-map marker for the Dynamic Island, derived PURELY from real state. Band = the lock-safe surface;
    /// confidence is CATEGORICAL today (a substantiated decision reason ⇒ full within-band commitment; an abstention/
    /// no-evidence reason ⇒ zero, so the marker sits at the band's uncertain edge). NO fabricated numeric score — the
    /// position is state-derived; a calibrated score can later drive GuardianHeatMarkerV1.position with no redesign.
    var heatMarker: GuardianHeatMarkerV1 {
        GuardianHeatMarkerV1.fromSurfaceRaw(userVisibleState.nativeSurface.rawValue,
                                            confidence: Self.confidence(for: liveReasonCode))
    }

    /// Categorical confidence 0...1 from the REAL reason code (never a measured number). A concrete, substantiated
    /// decision (matched/benign/caution) is a confident placement within its band; an abstention/awaiting reason is
    /// low confidence → the marker drifts toward the band boundary. This is the honest, documented placeholder until
    /// a real calibrated confidence exists.
    static func confidence(for code: GuardianReasonCodeV1?) -> Double {
        switch code {
        case .textEvidenceMatchedShield, .textEvidenceBenign, .personalShieldWarnOnly,
             .shieldBlurApplied, .shieldMuteApplied, .shieldSkipApplied:               return 1.0
        case .visualEvidenceInsufficient, .textEvidenceUnavailable,
             .observingNoDecisionYet, .newIdentityUnconfirmed, .contentChangedReset,
             .shieldWarnApplied, .shieldAskApproval:                                    return 0.0
        case .sessionNotObserving, .observingIdle, .guardianOff,
             .guardianOffBroadcastContinuing, .none:                                   return 0.0
        }
    }

    /// P3 law: a content change invalidates the prior decision. Reset the per-content surface → OBSERVING so a
    /// stale CAUTION/SHIELD cannot survive across resolved items. Call on every resolved-identity change.
    /// B2: entering RE-EVALUATING is a REAL state (a new identity with no decision yet), not decoration.
    func onResolvedIdentityChange() {
        currentSurface = nil            // the old A-decision drops INSTANTLY (no stale CAUTION/SHIELD survives)
        isReEvaluating = true           // RE-EVALUATING appears until the new decision lands (B2)
        liveReasonCode = .contentChangedReset   // honest: "önceki değerlendirme sıfırlandı"
        // C/E-lane (lab): a content change is a REAL timeline event — the prior decision is invalidated. Advancing
        // the lab identity revision binds the subsequent decision event to the NEW content (no cross-content drift).
        if labMode {
            labIdentityRevision += 1
            labTimeline.record(category: .contentChanged, status: .unknown,
                               reasonCodeRaw: GuardianReasonCodeV1.contentChangedReset.rawValue,
                               identityRevision: labIdentityRevision, nowEpoch: Date().timeIntervalSince1970)
            timelineEvents = labTimeline.events
        }
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
        // C/E-lane (lab): record the REAL lab decision as a timeline event so "Bu Oturum" is demonstrable. Status
        // reflects the actual tone (caution/shield/benign/unknown) — A4 honest (benign ≠ blanket "safe").
        if labMode {
            let code = Self.reasonCode(for: surface.tone)
            labTimeline.record(category: .decision, status: Self.timelineStatus(for: surface.tone),
                               reasonCodeRaw: code.rawValue, identityRevision: labIdentityRevision,
                               nowEpoch: Date().timeIntervalSince1970)
            timelineEvents = labTimeline.events
        }
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

    /// Pure projection of the lab decision tone onto a timeline STATUS (A4 honest: aligned/neutral = BENIGN, a
    /// scoped "evidence examined, no shield signal" claim — never a blanket "content is safe").
    static func timelineStatus(for tone: GuardianSurfaceState.Tone) -> GuardianTimelineStatusV1 {
        switch tone {
        case .aligned, .neutral:        return .benign
        case .caution, .strongCaution:  return .caution
        case .unknown:                  return .unknown
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
