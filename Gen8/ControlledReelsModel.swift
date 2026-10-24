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
    private(set) var policyRevision: UInt64 = 0
    var sharedContainerActive: Bool { brain?.sharedContainerActive ?? false }

    private var policyTimer: Timer?

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

        if brain.mustGateBeforePlay(item.id) {
            // Gate held: show the "preparing evidence" state; do NOT attach output yet (B1).
            currentState = .evaluating
            let decision = await brain.evaluate(item)
            apply(decision, for: item)
        } else {
            // No hide preference OR already resolved → evaluate (honest) and obey.
            let decision = await brain.evaluate(item)
            apply(decision, for: item)
        }
    }

    /// Obey a decision on the REAL player. This is the only place playback is actually driven.
    private func apply(_ decision: ReelDecisionV1, for item: ReelItemV1) {
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
            timeline.record(category: .personalShieldMatched, status: .shieldMatch,
                            reasonCodeRaw: GuardianReasonCodeV1.textEvidenceMatchedShield.rawValue,
                            identityRevision: timelineRevision, nowEpoch: now, mirror: false)
            timeline.record(category: .preferenceApplied, status: .shieldMatch,
                            reasonCodeRaw: GuardianReasonCodeV1.textEvidenceMatchedShield.rawValue,
                            identityRevision: timelineRevision, nowEpoch: now, mirror: false)
        case .askUser, .awaitDecision:
            // UNKNOWN / gate: hold playback, show the explicit decision screen. Nothing plays, nothing claims safe.
            warningStage = .none
            tearDownPlayback()
        }
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
        switch marker.band {
        case .shield:  surface = .shieldMatch
        case .caution: surface = .caution
        case .clear:   surface = .guardianOn
        case .unknown: surface = .unknown
        case .off:     surface = .off
        }
        GuardianLiveActivityController.shared.reelMarker(
            label: "Kontrollü oynatıcı", surface: surface, marker: marker)
        #endif
    }

    private func attachAndPlay(_ item: ReelItemV1) {
        coverEngaged = false
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
    }

    private func tearDownPlayback() {
        player.pause()
        player.isMuted = true
        player.volume = 0
        player.replaceCurrentItem(with: nil)
        coverEngaged = false
    }

    // MARK: User actions

    /// B3 — skip to the next reel (real content change). Advances the brain's queue and presents the next item.
    func skip() async {
        guard let brain else { return }
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
        _ = brain.advance(by: delta)
        currentIndex = brain.currentIndex
        if currentItem == nil { tearDownPlayback(); return }
        await presentCurrent()
    }

    /// B4 — the user chose "Yine de göster" for THIS reel only. Re-evaluates with a content-scoped override, then
    /// obeys (it will PLAY). The override cannot leak to any other reel (enforced in the brain).
    func showAnyway() async {
        guard let brain, let item = currentItem else { return }
        let decision = await brain.userShowAnyway(item)
        apply(decision, for: item)
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
        policyTimer?.invalidate(); policyTimer = nil
        tearDownPlayback()
    }
}
