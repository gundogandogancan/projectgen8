//
//  ControlledReelsModel.swift — app-side orchestration for the GEN8 CONTROLLED REELS PLAYER (mandate B).
//
//  WHAT THIS IS: the @MainActor @Observable the SwiftUI player binds to. It owns the REAL AVPlayer and bridges the
//  headless policy brain (GuardianMedia.ReelsPlayerModelV1) — which it consumes for every decision — to actual
//  playback control. The intelligence/decision logic is NOT duplicated here; this layer only (1) generates/loads
//  the OWNED local reels, (2) runs the pre-playback gate + evaluation through the brain, (3) OBEYS the computed
//  PlaybackIntent on the AVPlayer (attach+play / pause+mute+cover for a HIDE / hold for an UNKNOWN ask), and
//  (4) polls the shared policy revision on a 1s cadence so a live rule change re-evaluates the current reel (A1).
//
//  HONESTY (mandate B2): "Hidden" is only ever shown AFTER the player is really paused + muted and the video layer
//  is covered (no last-frame/thumbnail/audio leak). "Playing" only after the player really started. No fabrication.
//
import Foundation
import Observation
import AVFoundation
import GuardianCore

@MainActor
@Observable
final class ControlledReelsModel {
    /// The real AVPlayer for the controlled surface. The SwiftUI AVPlayerLayer binds to this.
    let player = AVPlayer()

    private(set) var brain: ReelsPlayerModelV1?
    private let store = PersonalShieldSharedStoreV1()

    // User-visible, honest state for the CURRENT reel.
    private(set) var items: [ReelItemV1] = []
    private(set) var currentIndex = 0
    private(set) var isReady = false
    private(set) var currentDecision: ReelDecisionV1?
    private(set) var currentState: ReelItemStateV1 = .pendingEvaluation
    /// True only once the player is REALLY paused+muted+covered for a HIDE (so the UI never says "Gizlendi" early).
    private(set) var coverEngaged = false
    // C1 — DISTINCT applied-action surface flags on OUR controlled player. Each is set ONLY after the real player
    // command was issued, so the UI's "Bulanık / Sessiz" claim is always tied to actual AVPlayer state (honest).
    /// A real Gaussian blur overlay is engaged over the still-playing video (BLUR_IF_CONTROLLED).
    private(set) var blurEngaged = false
    /// Audio is really muted via a MUTE_IF_CONTROLLED decision (image keeps playing) — drives the visible indicator.
    private(set) var muteEngaged = false
    /// A WARN banner is showing over still-playing content (WARN) — the real reason is in currentDecision.reason.
    private(set) var warnEngaged = false
    private(set) var policyRevision: UInt64 = 0
    var sharedContainerActive: Bool { brain?.sharedContainerActive ?? false }

    private var policyTimer: Timer?

    // §3 — ASYNC SAFETY. Every presentation that awaits an async evaluate() captures a GENERATION token bound to the
    // item id + the queue cursor + the live policy revision. A later-arriving result from a SUPERSEDED presentation
    // (the user swiped, skipped, went back, exited, a rule changed, or a new session started during the await) is
    // REJECTED at the PLAYBACK-COMMAND level — A's late decision can never drive B's AVPlayer. This is not merely a
    // visual guard: `apply()` (the only place the player is commanded) refuses a stale decision outright.
    private var presentGeneration: UInt64 = 0
    /// A stable snapshot of "what is current right now" — the presentation is only valid if ALL of these still hold
    /// when the async evidence returns. contentID + queue index + policy revision + generation.
    private struct PresentationTokenV1: Equatable {
        let generation: UInt64
        let contentID: String
        let index: Int
        let policyRevision: UInt64
    }
    /// Mint a fresh token for a NEW presentation, invalidating every in-flight one (the generation advances).
    private func newPresentationToken(for item: ReelItemV1) -> PresentationTokenV1 {
        presentGeneration &+= 1
        return PresentationTokenV1(generation: presentGeneration, contentID: item.id,
                                   index: currentIndex, policyRevision: brain?.policyRevision ?? policyRevision)
    }
    /// Is this token STILL the authoritative presentation? Any drift (new generation, moved cursor, different item,
    /// advanced policy) means a newer presentation superseded it → the stale decision must NOT touch the player.
    private func tokenStillCurrent(_ t: PresentationTokenV1) -> Bool {
        t.generation == presentGeneration
            && t.contentID == currentItem?.id
            && t.index == currentIndex
            && t.policyRevision == (brain?.policyRevision ?? policyRevision)
    }

    // A4 — the honest three-stage warning model for the CONTROLLED surface:
    //   MATCH_DETECTED  → a real shield hit was computed for this reel (decision time).
    //   WARNING_READY   → the hide was really applied on the player (cover engaged).
    //   WARNING_PRESENTED → the shield cover actually APPEARED on screen (tied to SwiftUI .onAppear).
    // Only the LAST writes a "warning presented" timeline event — we never claim the user saw it until the view did.
    enum WarningStage: String { case none, matchDetected, warningReady, warningPresented }
    private(set) var warningStage: WarningStage = .none
    /// A session-scoped, in-app timeline of REAL controlled-player events (hidden / skipped / override / warning).
    /// Distinct from the broadcast-extension timeline; this surfaces what OUR player actually did.
    private let timeline = GuardianSessionTimelineWriterV1(sessionID: "controlled-\(UUID().uuidString)", suite: nil)
    private var timelineRevision = 0
    /// Read-only view of the controlled-player timeline events (for the UI / tests).
    var timelineEvents: [GuardianTimelineEventV1] { timeline.events }

    var currentItem: ReelItemV1? { items.indices.contains(currentIndex) ? items[currentIndex] : nil }

    /// Generate/load the OWNED local reels and build the brain. Called on first appear.
    func start() async {
        guard !isReady else { return }
        let lib = ReelsAssetLibraryV1()
        let reels = await lib.ensureReels()
        let brain = ReelsPlayerModelV1(items: reels, store: store)
        self.brain = brain
        self.items = reels
        self.policyRevision = brain.policyRevision
        self.isReady = true
        await presentCurrent()
        startPolicyPolling()
    }

    /// B1 — present the current reel through the pre-playback gate. If the user has a HIDE preference and the item
    /// is unevaluated, we do NOT attach/auto-play: we evaluate FIRST, then obey the resulting intent. If there is
    /// no hide preference at all, an unevaluated reel may begin, but we still evaluate so the state is honest.
    func presentCurrent() async {
        guard let brain, let item = currentItem else { return }
        tearDownPlayback()                        // never leak the previous reel's frame/audio
        currentDecision = nil
        currentState = brain.state(of: item.id)
        // §3 — bind this presentation to a generation token. The async evaluate() below may resolve AFTER the user
        // has swiped/skipped/exited or a rule changed; `apply()` checks the token and refuses a superseded result.
        let token = newPresentationToken(for: item)

        if brain.mustGateBeforePlay(item.id) {
            // Gate held: show the "preparing evidence" state; do NOT attach output yet (B1).
            currentState = .evaluating
        }
        // C2 — ALL production evaluations go through evaluateGuarded: the brain's generation guard protects the
        // decision/state CACHE (a superseded late result is never committed there), and `apply()` additionally
        // refuses a stale decision at the real playback-command boundary. Two independent firewalls, no stale play.
        let outcome = await brain.evaluateGuarded(item)
        if case .applied(let decision) = outcome {
            apply(decision, for: item, token: token)
        }
        // .superseded: the brain already refused to commit it; the newer presentation owns the player — do nothing.
    }

    /// Obey a decision on the REAL player. This is the only place playback is actually driven. §3: a decision whose
    /// presentation token is NO LONGER current (the queue moved, the item changed, the policy advanced, or a newer
    /// presentation superseded it during the await) is REJECTED here — it never issues a play/hide command for the
    /// wrong reel. The guard is at the real playback-command boundary, not just the UI.
    private func apply(_ decision: ReelDecisionV1, for item: ReelItemV1, token: PresentationTokenV1) {
        guard tokenStillCurrent(token) else {
            // A superseded (stale) result arrived late — drop it silently; the current presentation owns the player.
            return
        }
        currentDecision = decision
        currentState = decision.state
        timelineRevision += 1
        let now = Date().timeIntervalSince1970
        // LIVE DYNAMIC ISLAND: slide the heat marker to THIS reel's band the instant the decision lands. Band comes
        // from the real lifecycle state; confidence is the evaluator's REAL coverage (fraction of matchers that ran)
        // — no fabricated score. No-op unless a session Activity is already live (reels never start one).
        pushIslandMarker(for: decision)
        switch decision.intent {
        case .play:
            warningStage = .none
            attachAndPlay(item)
            if decision.state == .userOverridden {
                // B4 — a REAL user override occurred (content-scoped). Record it honestly.
                timeline.record(category: .preferenceApplied, status: .benign,
                                reasonCodeRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
                                identityRevision: timelineRevision, nowEpoch: now, mirror: false)
            }
        case .hide:
            // B2 — REAL hide: pause, mute, zero volume, and engage the cover so no image/audio leaks. We only set
            // coverEngaged (which the UI reads to say "Gizlendi") AFTER these have been applied.
            engageHide(item)
            // A4 MATCH_DETECTED → WARNING_READY (the hide was really applied). WARNING_PRESENTED is deferred to the
            // cover's .onAppear (markWarningPresented), so we never log "shown" before the view actually appears.
            warningStage = .warningReady
            recordAppliedPreference(now: now, status: .shieldMatch, reason: .textEvidenceMatchedShield)
        case .blur:
            // C1 — REAL blur: the video KEEPS playing (image + audio) under a live Gaussian blur overlay the view
            // draws over the AVPlayerLayer. We set blurEngaged only after play is really issued, so the "Bulanık"
            // claim is tied to actual player state. (Verified in-app; the overlay is a CIFilter-backed layer.)
            attachAndPlay(item)
            blurEngaged = true
            warningStage = .none
            recordAppliedPreference(now: now, status: .shieldMatch, reason: .shieldBlurApplied)
        case .mute:
            // C1 — REAL mute: play the video but force isMuted + zero volume; a visible indicator shows the user why.
            attachAndPlay(item)
            player.isMuted = true
            player.volume = 0
            muteEngaged = true
            warningStage = .none
            recordAppliedPreference(now: now, status: .caution, reason: .shieldMuteApplied)
        case .warn:
            // C1 — REAL warn: content plays with a visible warning banner carrying the real reason. No hide claim.
            attachAndPlay(item)
            warnEngaged = true
            warningStage = .warningReady
            recordAppliedPreference(now: now, status: .caution, reason: .shieldWarnApplied)
        case .skip:
            // C1 — REAL skip: a genuine transition past this item (SKIP_IF_CONTROLLED_AND_ALIGNED). We tear down the
            // player (nothing plays for the skipped item) and record the skip; the queue cursor advances via skip().
            tearDownPlayback()
            warningStage = .none
            recordAppliedPreference(now: now, status: .shieldMatch, reason: .shieldSkipApplied)
        case .askUser, .awaitDecision:
            // UNKNOWN / gate / ASK approval: hold playback, show the explicit decision screen. Nothing plays, nothing
            // claims safe. ASK (a real match needing approval) and UNDETERMINED (abstention) share this hold surface.
            warningStage = .none
            tearDownPlayback()
        }
    }

    /// C1 — one place that records the applied-preference three-beat (matched → preference applied) for any real
    /// shield action on our controlled surface, with the honest reason for that specific action.
    private func recordAppliedPreference(now: Double, status: GuardianTimelineStatusV1, reason: GuardianReasonCodeV1) {
        timeline.record(category: .personalShieldMatched, status: status,
                        reasonCodeRaw: reason.rawValue, identityRevision: timelineRevision, nowEpoch: now, mirror: false)
        timeline.record(category: .preferenceApplied, status: status,
                        reasonCodeRaw: reason.rawValue, identityRevision: timelineRevision, nowEpoch: now, mirror: false)
    }

    /// A4 — the shield cover ACTUALLY appeared on screen (called from SwiftUI .onAppear). ONLY now do we record a
    /// "warning presented" timeline event — the honest tie between a UI event and the claim that the user saw it.
    func markWarningPresented() {
        guard warningStage == .warningReady else { return }
        warningStage = .warningPresented
        timeline.record(category: .warningShown, status: .shieldMatch,
                        reasonCodeRaw: GuardianReasonCodeV1.textEvidenceMatchedShield.rawValue,
                        identityRevision: timelineRevision, nowEpoch: Date().timeIntervalSince1970, mirror: false)
    }

    /// LIVE DYNAMIC ISLAND — map the REAL reel decision → a pure heat marker and slide the Island to it. The band is
    /// derived from the lifecycle state; confidence is the evaluator's REAL coverage (0...1). CLEAR for a playing/
    /// overridden reel, SHIELD for a real hide, UNKNOWN for undetermined — no fabricated 0-100 number anywhere.
    private func pushIslandMarker(for decision: ReelDecisionV1) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        let marker = GuardianHeatMarkerV1.fromReelStateRaw(decision.state.rawValue, confidence: decision.coverage)
        let surface: NativeSurfaceState
        let title: String
        switch marker.band {
        case .shield:         surface = .shieldMatch; title = "Kalkan"
        case .caution:        surface = .caution;     title = "Dikkat"
        case .clear:          surface = .guardianOn;  title = "Oynatılıyor"
        case .userOverridden: surface = .guardianOn;  title = "Senin istisnan"   // §2.2 — conscious exception, not green
        case .unknown:        surface = .unknown;     title = "Belirsiz"
        case .off:            surface = .off;         title = "Kapalı"
        }
        GuardianLiveActivityController.shared.reelMarker(
            label: "Kontrollü oynatıcı", surface: surface, marker: marker,
            title: title, displayStyleRaw: AppSettings.shared.effectiveDisplayStyleRaw)
        #endif
    }

    private func attachAndPlay(_ item: ReelItemV1) {
        coverEngaged = false; blurEngaged = false; muteEngaged = false; warnEngaged = false
        let asset = AVURLAsset(url: item.url)
        let pItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: pItem)
        player.isMuted = false
        player.volume = 1.0
        player.seek(to: .zero)
        player.play()
    }

    private func engageHide(_ item: ReelItemV1) {
        // Ensure no output is attached at all — the strongest no-leak guarantee is to not feed the layer the asset.
        player.pause()
        player.isMuted = true
        player.volume = 0
        player.replaceCurrentItem(with: nil)      // remove the item → the AVPlayerLayer has nothing to render
        coverEngaged = true                        // now it is truthful to show the shield cover + "Gizlendi"
        blurEngaged = false; muteEngaged = false; warnEngaged = false
    }

    private func tearDownPlayback() {
        player.pause()
        player.isMuted = true
        player.volume = 0
        player.replaceCurrentItem(with: nil)
        coverEngaged = false; blurEngaged = false; muteEngaged = false; warnEngaged = false
    }

    // MARK: User actions

    /// B3 — skip to the next reel (real content change). Advances the brain's queue and presents the next item.
    func skip() async {
        guard let brain else { return }
        presentGeneration &+= 1   // §3 — invalidate any in-flight evaluate for the reel we're leaving
        // B3 — a REAL skip of the current content. Record it before advancing.
        timelineRevision += 1
        timeline.record(category: .contentChanged, status: .active,
                        reasonCodeRaw: GuardianReasonCodeV1.contentChangedReset.rawValue,
                        identityRevision: timelineRevision, nowEpoch: Date().timeIntervalSince1970, mirror: false)
        _ = brain.skipCurrent()
        currentIndex = brain.currentIndex
        if currentItem == nil { tearDownPlayback(); return }   // list end
        await presentCurrent()
    }

    /// B3 — directional navigation (swipe). delta +1 next / -1 previous.
    func move(by delta: Int) async {
        guard let brain else { return }
        presentGeneration &+= 1   // §3 — invalidate any in-flight evaluate for the reel we're leaving (fast swipe)
        _ = brain.advance(by: delta)
        currentIndex = brain.currentIndex
        if currentItem == nil { tearDownPlayback(); return }
        await presentCurrent()
    }

    /// B4 — the user chose "Yine de göster" for THIS reel only. Re-evaluates with a content-scoped override, then
    /// obeys (it will PLAY). The override cannot leak to any other reel (enforced in the brain).
    func showAnyway() async {
        guard let brain, let item = currentItem else { return }
        // §3 — a fresh presentation token for the override re-evaluation (supersedes any in-flight evaluate).
        let token = newPresentationToken(for: item)
        // C2 — guarded override re-evaluation: if the user swipes away mid-flight the late decision is not committed.
        let outcome = await brain.userShowAnywayGuarded(item)
        if case .applied(let decision) = outcome {
            apply(decision, for: item, token: token)
        }
    }

    // MARK: A1 — live policy polling

    private func startPolicyPolling() {
        policyTimer?.invalidate()
        // Mirrors the extension's ~1s cadence: a live rule change re-evaluates the current reel without a restart.
        policyTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.pollPolicy() }
        }
    }

    private func pollPolicy() async {
        guard let brain else { return }
        if brain.pollPolicyRevisionAndInvalidateIfChanged() {
            policyRevision = brain.policyRevision
            // The current reel's decision may now be stale → re-present it honestly under the new rules.
            await presentCurrent()
        }
    }

    func stop() {
        presentGeneration &+= 1   // §3 — exiting the player invalidates any in-flight evaluate (no late play command)
        policyTimer?.invalidate(); policyTimer = nil
        tearDownPlayback()
    }
}
