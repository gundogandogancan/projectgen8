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
    /// §3/§5 — the Personal Learning sink. The decision surface is the REAL interaction point for behaviour-change
    /// feedback (content-scoped "Yine de göster", ASK answers, the explicit "daha az göster" / "yardımcı olmadı"
    /// buttons). Each becomes ONE explicit signal for the rule that produced the decision, so the learning engine can
    /// accumulate INDEPENDENT evidence across DISTINCT reels and (only then) propose a change (§3.1). nil = unwired.
    weak var learning: LocalLearningModel?
    /// §3.1 — emit an explicit feedback signal for the CURRENT reel's matched rule, if any. No matched rule ⇒ no
    /// signal (we never attribute feedback to a rule that did not act). Content id is HASHED inside the learning model.
    private func emitLearningSignal(_ kind: LearningSignalKindV1) {
        guard let ruleID = currentDecision?.matchedRuleID, let item = currentItem else { return }
        learning?.recordSignal(ruleID: ruleID, kind: kind, contentID: item.id)
    }
    // §C/§E — the PREFETCH coordinator (N+1 pre-exposure). Built in start(); drives low-priority pre-evaluation of the
    // next reel and the token-revalidated instant apply on swipe. Island is NEVER loaded with the prefetch queue.
    private var prefetch: PrefetchCoordinatorV1?
    private let sessionID = "reels-\(UUID().uuidString)"
    /// §E — optional low-profile "değerlendirme hazır" indicator: true when a VALID prefetch decision is cached for
    /// the NEXT reel. No notification / attention-grab — the view may show a tiny chip, nothing more.
    private(set) var nextPrefetchReady = false
    /// §B3 — the honest published prefetch lifecycle state for N+1 (NOT_STARTED/EVALUATING/READY/INVALIDATED/
    /// CANCELLED/UNAVAILABLE). The chip refreshes from THIS so it shows "hazır" only when the async prefetch really
    /// completed with a re-validatable decision — never while work is still in flight. Mirrors coordinator.state.
    private(set) var nextPrefetchState: PrefetchStateV1 = .notStarted
    /// §G — REAL in-process swipe→decision latency (ms) for the LAST transition, separated by cache-hit vs on-demand.
    /// Measured, never fabricated; nil until a transition happened. DEVICE_UNVERIFIED for device-class numbers.
    private(set) var lastTransitionLatencyMs: Double?
    private(set) var lastTransitionWasCacheHit = false
    /// §G — the coordinator's honest telemetry line (started/completed/cancelled/hits/misses/wasted) for the UI/tests.
    var prefetchSummary: String { prefetch?.summary ?? "prefetch=inactive" }

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
        // §C/§E — build the prefetch coordinator for THIS session + queue. §2.4 — inject the REAL analysis-consent
        // reader (the existing fail-closed GuardianAnalysisGateV1 gate, read from the shared App Group suite) so a
        // Guardian-OFF / unknown-consent state genuinely stops heavy pre-exposure work on this surface.
        let suite = UserDefaults(suiteName: PersonalShieldStoreLocationV1.appGroupID)
        let coordinator = PrefetchCoordinatorV1(sessionID: sessionID, brain: brain, items: reels,
                                                analysisConsent: { GuardianAnalysisGateV1.analysisConsent(suite: suite) })
        // §2.2 — READY the instant the async prefetch completes: the coordinator pushes its state change here (no
        // timer polling). Hop to the MainActor and refresh the published chip state directly from the completion.
        coordinator.onStateChange = { [weak self] st in
            guard let self else { return }
            self.nextPrefetchState = st
            self.refreshPrefetchReady()
        }
        self.prefetch = coordinator
        self.isReady = true
        await presentCurrent()
        startPolicyPolling()
    }

    /// B1 — present the current reel through the pre-playback gate. If the user has a HIDE preference and the item
    /// is unevaluated, we do NOT attach/auto-play: we evaluate FIRST, then obey the resulting intent. If there is
    /// no hide preference at all, an unevaluated reel may begin, but we still evaluate so the state is honest.
    func presentCurrent() async {
        guard let brain else { return }
        // B3 — AUTO-SKIP LOOP. A reel whose decision is a real SKIP advances the cursor + evaluates the NEXT item
        // automatically. The loop is BOUNDED by the queue length so back-to-back SKIP matches can never spin forever;
        // at the end of the list we settle into a safe end state (nothing plays, nothing claims safe). Each iteration
        // evaluates exactly one item; `apply` returns true only for a genuine SKIP, which is the sole continue signal.
        var guardCounter = 0
        let maxIterations = max(1, items.count) + 1   // hard cap: at most one pass over the queue + the terminal step
        while guardCounter < maxIterations {
            guardCounter += 1
            guard let item = currentItem else {
                // End of the list reached by auto-skip: safe terminal state (no player, no false "safe").
                tearDownPlayback(); currentState = .skipped; currentDecision = nil; return
            }
            tearDownPlayback()                        // never leak the previous reel's frame/audio
            currentDecision = nil
            currentState = brain.state(of: item.id)
            // §3 — bind this presentation to a generation token. The async evaluate() below may resolve AFTER the user
            // has swiped/skipped/exited or a rule changed; `apply()` checks the token and refuses a superseded result.
            let token = newPresentationToken(for: item)
            if brain.mustGateBeforePlay(item.id) {
                currentState = .evaluating            // B1 gate held: don't attach output yet
            }
            // C2 — ALL production evaluations go through evaluateGuarded: the brain's generation guard protects the
            // decision/state CACHE (a superseded late result is never committed there), and `apply()` additionally
            // refuses a stale decision at the real playback-command boundary. Two independent firewalls, no stale play.
            let outcome = await brain.evaluateGuarded(item)
            guard case .applied(let decision) = outcome else { return }  // .superseded: a newer presentation owns it
            let needsAutoSkip = apply(decision, for: item, token: token)
            if !needsAutoSkip {
                // §C2/§E — the current reel reached a SETTLED state (play/hide/blur/mute/warn/ask/undetermined). NOW is
                // the moment to pre-evaluate N+1 at low priority: the foreground decision is already applied, so the
                // prefetch never competes with it. No-op at the end of the list. Island is untouched.
                prefetch?.prefetchNext(after: currentIndex)
                refreshPrefetchReady()
                return                                // settled — stop the loop
            }
            // B3 — a REAL auto-skip: record it + advance the brain cursor, then evaluate the next item on the next pass.
            timelineRevision += 1
            timeline.record(category: .contentChanged, status: .shieldMatch,
                            reasonCodeRaw: GuardianReasonCodeV1.shieldSkipApplied.rawValue,
                            identityRevision: timelineRevision, nowEpoch: Date().timeIntervalSince1970, mirror: false)
            _ = brain.skipCurrent()                   // marks current .skipped + advances cursor (bumps generation)
            currentIndex = brain.currentIndex
        }
    }

    /// Obey a decision on the REAL player. This is the only place playback is actually driven. §3: a decision whose
    /// presentation token is NO LONGER current (the queue moved, the item changed, the policy advanced, or a newer
    /// presentation superseded it during the await) is REJECTED here — it never issues a play/hide command for the
    /// wrong reel. The guard is at the real playback-command boundary, not just the UI.
    /// B3 — returns TRUE when the applied decision is a real auto-SKIP, so the caller advances the queue + evaluates
    /// the next item (a genuine content transition, not merely a torn-down player). False otherwise.
    @discardableResult
    private func apply(_ decision: ReelDecisionV1, for item: ReelItemV1, token: PresentationTokenV1) -> Bool {
        guard tokenStillCurrent(token) else {
            // A superseded (stale) result arrived late — drop it silently; the current presentation owns the player.
            return false
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
            recordAppliedPreference(now: now, status: .shieldMatch, reason: .textEvidenceMatchedShield,
                                    warningReadied: true)
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
            recordAppliedPreference(now: now, status: .caution, reason: .shieldWarnApplied, warningReadied: true)
        case .skip:
            // B3 — REAL auto-SKIP: a genuine transition PAST this item (SKIP_IF_CONTROLLED_AND_ALIGNED). We tear down
            // the player (nothing plays for the skipped item), record the skip, and tell the caller to actually
            // advance the queue cursor + evaluate the NEXT item. Returning true is what makes the skip real rather
            // than a cosmetic torn-down player (the old defect: cursor never moved).
            tearDownPlayback()
            warningStage = .none
            recordAppliedPreference(now: now, status: .shieldMatch, reason: .shieldSkipApplied)
            return true
        case .askUser, .awaitDecision:
            // UNKNOWN / gate / ASK approval: hold playback, show the explicit decision screen. Nothing plays, nothing
            // claims safe. ASK (a real match needing approval) and UNDETERMINED (abstention) share this hold surface.
            warningStage = .none
            tearDownPlayback()
        }
        return false
    }

    /// C1 + 1G — one place that records the applied-preference chain for any real shield action on our controlled
    /// surface. Base beat: matched → preference applied. When the action carries a user-facing WARNING (hide cover /
    /// warn banner, i.e. `warningReadied`), we extend the honest 1G presentation chain: MATCH_DETECTED (the match was
    /// identified) → WARNING_READY (the warning was PREPARED by our controlled surface) → WARNING_DELIVERED (handed to
    /// our OWN SwiftUI layer to present). PRESENTED is NOT written here — it is deferred to the real `.onAppear`
    /// (markWarningPresented), so "kullanıcı gördü" is only ever claimed when our view actually rendered.
    private func recordAppliedPreference(now: Double, status: GuardianTimelineStatusV1, reason: GuardianReasonCodeV1,
                                         warningReadied: Bool = false) {
        timeline.record(category: .personalShieldMatched, status: status,
                        reasonCodeRaw: reason.rawValue, identityRevision: timelineRevision, nowEpoch: now, mirror: false)
        if warningReadied {
            timeline.record(category: .matchDetected, status: status,
                            reasonCodeRaw: reason.rawValue, identityRevision: timelineRevision, nowEpoch: now, mirror: false)
        }
        timeline.record(category: .preferenceApplied, status: status,
                        reasonCodeRaw: reason.rawValue, identityRevision: timelineRevision, nowEpoch: now, mirror: false)
        if warningReadied {
            // Our controlled surface really prepared + handed the warning to SwiftUI to render; the actual on-screen
            // appearance (PRESENTED) is confirmed separately by markWarningPresented's real onAppear.
            timeline.record(category: .warningReady, status: status,
                            reasonCodeRaw: reason.rawValue, identityRevision: timelineRevision, nowEpoch: now, mirror: false)
            timeline.record(category: .warningDelivered, status: status,
                            reasonCodeRaw: reason.rawValue, identityRevision: timelineRevision, nowEpoch: now, mirror: false)
        }
    }

    /// A4 + 1G — the shield cover/banner ACTUALLY appeared on screen (called from SwiftUI .onAppear). ONLY now do we
    /// record a WARNING_PRESENTED timeline event — the honest tie between a REAL UI event and the claim the user saw
    /// it. This is the one place the vocabulary is allowed to reach PRESENTED, because our OWN controlled view really
    /// rendered (unlike the broadcast extension, which observes a 3rd-party app it cannot prove it drew over). The
    /// stage machine guarantees PRESENTED only ever follows a real WARNING_READY (never fabricated without a match).
    func markWarningPresented() {
        guard warningStage == .warningReady else { return }
        warningStage = .warningPresented
        timeline.record(category: .warningPresented, status: .shieldMatch,
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
        prefetch?.cancel(reason: "user-skip")   // §C4 — foreground action cancels any in-flight prefetch
        // B3 — a REAL skip of the current content. Record it before advancing.
        timelineRevision += 1
        timeline.record(category: .contentChanged, status: .active,
                        reasonCodeRaw: GuardianReasonCodeV1.contentChangedReset.rawValue,
                        identityRevision: timelineRevision, nowEpoch: Date().timeIntervalSince1970, mirror: false)
        _ = brain.skipCurrent()
        currentIndex = brain.currentIndex
        if currentItem == nil { tearDownPlayback(); return }   // list end
        await presentCurrentPreferringPrefetch()
    }

    /// B3 — directional navigation (swipe). delta +1 next / -1 previous.
    func move(by delta: Int) async {
        guard let brain else { return }
        presentGeneration &+= 1   // §3 — invalidate any in-flight evaluate for the reel we're leaving (fast swipe)
        prefetch?.cancel(reason: "user-swipe")   // §C4 — foreground swipe cancels any in-flight prefetch
        _ = brain.advance(by: delta)
        currentIndex = brain.currentIndex
        if currentItem == nil { tearDownPlayback(); return }
        await presentCurrentPreferringPrefetch()
    }

    /// §C2/§E/§G — present the now-current reel, PREFERRING a valid prefetched decision. On a forward swipe to the
    /// pre-evaluated N+1 the cached decision is token-REVALIDATED and, on a hit, applied WITHOUT re-decode/OCR — an
    /// instant, honest transition (a hidden reel is hidden before it starts). On a miss (backward move, token drift,
    /// end-of-list, or nothing cached) we fall through to the normal on-demand gate. The swipe→decision latency is
    /// measured in-process and tagged cache-hit vs on-demand (G, REAL numbers; device-class claims are DEVICE_UNVERIFIED).
    private func presentCurrentPreferringPrefetch() async {
        guard let brain, let item = currentItem else { return }
        let t0 = DispatchTime.now().uptimeNanoseconds
        if let cached = prefetch?.revalidatedDecision(for: item, atIndex: currentIndex) {
            // §C2 cache HIT — apply the already-computed decision directly. Bind a fresh presentation token so the
            // normal supersede guard still protects the real player command; a valid cached decision is current.
            tearDownPlayback()
            currentDecision = nil
            let token = newPresentationToken(for: item)
            let needsAutoSkip = apply(cached, for: item, token: token)
            lastTransitionLatencyMs = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
            lastTransitionWasCacheHit = true
            if needsAutoSkip {
                // A cached SKIP still advances honestly via the normal loop (which also re-prefetches after settling).
                timelineRevision += 1
                _ = brain.skipCurrent()
                currentIndex = brain.currentIndex
                await presentCurrent()
            } else {
                prefetch?.prefetchNext(after: currentIndex)   // immediately pre-evaluate the NEW N+1
                refreshPrefetchReady()
            }
            return
        }
        // Cache MISS — normal on-demand gate. Measure its latency too so cache-hit vs on-demand is a REAL comparison.
        lastTransitionWasCacheHit = false
        await presentCurrent()
        lastTransitionLatencyMs = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
    }

    /// §E — refresh the low-profile "next evaluation ready" indicator from the coordinator's real cache state.
    private func refreshPrefetchReady() {
        guard let p = prefetch, p.nextIndex(after: currentIndex) != nil else {
            nextPrefetchReady = false; nextPrefetchState = .unavailable; return   // §B3 — end of list: honest UNAVAILABLE
        }
        // §B3 — publish the coordinator's REAL lifecycle state; the chip shows "hazır" ONLY on .ready. A non-consuming
        // peek keeps the "ready" boolean in exact agreement with .ready so the two can never disagree.
        nextPrefetchState = p.state
        nextPrefetchReady = (p.state == .ready) && p.revalidatedDecisionIsCachedPeek(forNextAfter: currentIndex)
    }

    /// B4 — the user chose "Yine de göster" for THIS reel only. Re-evaluates with a content-scoped override, then
    /// obeys (it will PLAY). The override cannot leak to any other reel (enforced in the brain).
    func showAnyway() async {
        guard let brain, let item = currentItem else { return }
        // §3.1 — an EXPLICIT content-scoped "Yine de göster" is a LOOSEN signal for the matched rule (recorded BEFORE
        // the override re-evaluation clears the matched-rule context). One signal per DISTINCT reel; same-reel repeats
        // collapse in the engine. Only recorded when learning is ON (the sink no-ops otherwise).
        emitLearningSignal(.showAnyway)
        // §C3/§C4 — the override changes this item's exception state → any cached prefetch decision for it is stale
        // (its token's exceptionState no longer matches). Invalidate the cache so an override can never be read from a
        // pre-override cached decision, and cancel in-flight work for a clean re-evaluation.
        prefetch?.cancel(reason: "override")
        prefetch?.invalidate(reason: "override")
        // §3 — a fresh presentation token for the override re-evaluation (supersedes any in-flight evaluate).
        let token = newPresentationToken(for: item)
        // C2 — guarded override re-evaluation: if the user swipes away mid-flight the late decision is not committed.
        let outcome = await brain.userShowAnywayGuarded(item)
        if case .applied(let decision) = outcome {
            apply(decision, for: item, token: token)
            prefetch?.prefetchNext(after: currentIndex)
            refreshPrefetchReady()
        }
    }

    // MARK: §3.1 — EXPLICIT feedback buttons on the decision surface (deliberate user actions only)

    /// §3.1 — "Bunun gibi daha az göster": an explicit request to TIGHTEN the matched rule. Recorded as one signal
    /// for the current reel's matched rule; no behaviour changes now (a proposal may form later, §3.2).
    func feedbackShowLess() { emitLearningSignal(.showLessLikeThis) }

    /// §3.1 — "Bu uyarı yardımcı olmadı": an explicit LOOSEN signal (the warning wasn't wanted) for the matched rule.
    func feedbackWarningNotHelpful() { emitLearningSignal(.warningNotHelpful) }

    /// §3.1 — the user answered an ASK prompt. ALLOW ⇒ a LOOSEN signal + plays via the override path; BLOCK ⇒ a
    /// TIGHTEN signal + the content stays held. Both are explicit, content-scoped, and attributed to the matched rule.
    func answerAsk(allow: Bool) async {
        emitLearningSignal(allow ? .askAllowed : .askBlocked)
        if allow { await showAnywayKeepingContext() }
        // BLOCK: nothing to play — the hold surface stays; the signal is the only effect (tighten evidence).
    }

    /// Internal — the ASK-ALLOW path reuses the override re-evaluation WITHOUT re-emitting a showAnyway signal (the
    /// ASK answer already emitted its own askAllowed signal; we must not double-count the same explicit action).
    private func showAnywayKeepingContext() async {
        guard let brain, let item = currentItem else { return }
        prefetch?.cancel(reason: "ask-allow"); prefetch?.invalidate(reason: "ask-allow")
        let token = newPresentationToken(for: item)
        let outcome = await brain.userShowAnywayGuarded(item)
        if case .applied(let decision) = outcome {
            apply(decision, for: item, token: token)
            prefetch?.prefetchNext(after: currentIndex)
            refreshPrefetchReady()
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
            // §C4 — a policy-revision change CANCELS the in-flight prefetch AND invalidates the cached decision: the
            // old pre-exposure result was computed under the old rules (acceptance #7: policy change ⇒ old prefetch
            // unusable). The cache token's policyRevision would already miss, but we invalidate explicitly for clarity.
            prefetch?.cancel(reason: "policy-change")
            prefetch?.invalidate(reason: "policy-change")
            refreshPrefetchReady()
            // The current reel's decision may now be stale → re-present it honestly under the new rules.
            await presentCurrent()
        }
        // §2.2 — NOTE: the chip no longer depends on this 1s poll to learn a prefetch COMPLETED. The coordinator
        // pushes its state transition through `onStateChange` (wired in start()), so "sıradaki hazır" flips the exact
        // moment a re-validatable decision is cached — directly from the async completion, not a timer tick.
    }

    func stop() {
        presentGeneration &+= 1   // §3 — exiting the player invalidates any in-flight evaluate (no late play command)
        prefetch?.teardown()      // §C5 — cancel in-flight prefetch + wipe the cache + temporary evidence (session end)
        nextPrefetchReady = false
        policyTimer?.invalidate(); policyTimer = nil
        tearDownPlayback()
    }
}
