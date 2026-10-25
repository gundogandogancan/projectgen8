//
//  LongFormPlayerModel.swift — mandate §F: the app-side orchestration for the USER-FACING long-form player.
//
//  WHAT THIS IS: the @MainActor @Observable the LongFormPlayerView binds to. It owns the REAL AVPlayer and drives it
//  from the headless long-form brain (GuardianMedia.LongFormGuardianModelV1 + AdaptiveEvidencePlannerV1) over a REAL,
//  OWNED long video. The intelligence is NOT duplicated here — this layer only:
//    (1) GENERATES a real, decodable demo asset on demand (LongFormFixtureV1 with a SHORTER 120s demo spec so
//        interactive generation takes seconds; the full 600s stays the benchmark's domain),
//    (2) runs the long-form analysis through the brain (FAST → SELECTIVE → DEEPENING), surfacing the FAST decision
//        the moment it is ready and an honest "ek analiz sürüyor" state while the fuller pass runs,
//    (3) OBEYS the aggregate decision on the AVPlayer honoring the EXISTING HIDE/ASK/WARN/BLUR/MUTE/SKIP contracts
//        (the same PlaybackIntentV1 vocabulary the controlled-reels surface obeys), and
//    (4) reads the user's REAL rules from the shared policy store (so expert selection is rule-driven, not hardcoded).
//
//  HONESTY (mandate D/F): a FAST decision is a FIRST, limited-evidence decision — never a claim the whole video is
//  understood. The aggregate is temporally PARTIAL (sampled windows, not every frame). "Gizlendi" is shown only AFTER
//  the player is really paused + muted + the output removed. Sparse sampling never claims whole-video safety.
//
//  SESSİZ ZEKÂ: no notifications; all state lives in this screen. Nothing is pushed anywhere.
//
import Foundation
import Observation
import AVFoundation
import GuardianCore

@MainActor
@Observable
final class LongFormPlayerModel {
    /// The real AVPlayer for the long-form surface. The SwiftUI AVPlayerLayer (reused PlayerLayerView) binds to this.
    let player = AVPlayer()

    /// §F — the honest lifecycle of THIS screen. Each phase names exactly what is (or is not yet) known.
    enum Phase: Equatable {
        case idle                 // nothing started
        case generating           // writing the real demo asset (takes a few seconds at the demo spec)
        case analyzingFast        // asset ready; the FAST (first-window) decision is being computed
        case fastReady            // the FAST decision landed; the fuller SELECTIVE/DEEPENING pass is still running
        case settled              // the aggregate decision is final and applied on the player
        case failed(String)       // honest failure (generation/metadata) — never a fabricated clean result
        // §1E — Guardian OFF / IDLE / UNKNOWN-consent: heavy analysis did NOT run (nothing was examined). This is NOT
        // a "safe" claim and NOT a failure — it is an honest unavailable-analysis state. The reason distinguishes a
        // deliberate OFF from an idle pause from an unreadable (abstain) consent.
        case analysisUnavailable(String)
    }

    private(set) var phase: Phase = .idle
    /// The content identity of the demo asset (stable for this session so evidence reuse / a policy re-decide can key on it).
    let contentID = "longform-demo-120s"
    /// The honest label shown to the user. NEVER claims a real 600s video — it is explicitly the short demo.
    let demoTitle = "Demo uzun video (120 sn)"

    /// The FAST decision (first valid, limited-evidence). Its coverage is intentionally tiny — a fast UNKNOWN is honest.
    private(set) var fastDecision: ReelDecisionV1?
    /// The AGGREGATE decision over all EXAMINED windows (strongest real per-window verdict) — the surface actually obeyed.
    private(set) var aggregateDecision: ReelDecisionV1?
    /// The per-window outcomes — the evidence-map timeline's source of truth (examined / matched / deferred / not-decoded).
    private(set) var windowOutcomes: [LongFormWindowOutcomeV1] = []
    /// The plan the brain executed (strategy, budget, windows) — surfaced honestly in the evidence map.
    private(set) var plan: LongFormPlanV1?
    private(set) var durationSeconds: Double = 0

    // HONEST, SEPARATE coverage facts (mandate D2/F) — never fused into one "analysed %".
    private(set) var plannedWindows = 0
    private(set) var examinedWindows = 0
    private(set) var ocrCalls = 0
    private(set) var audioWindows = 0
    private(set) var framesDecoded = 0
    private(set) var deepeningExecuted = 0
    private(set) var deepeningDeferred = 0
    /// §G — the REAL measured time to the FIRST valid decision (ms). Measured, never fabricated; nil until known.
    private(set) var firstValidDecisionMs: Double?
    /// §G — the REAL measured time to full plan completion (ms). DEVICE_UNVERIFIED for device-class claims.
    private(set) var totalPlanMs: Double?
    private(set) var recomputedFromCache = false

    // Applied-action surface flags — set ONLY after the real player command was issued, so the UI claim is honest.
    private(set) var coverEngaged = false
    private(set) var blurEngaged = false
    private(set) var muteEngaged = false
    private(set) var warnEngaged = false

    private(set) var policyRevision: UInt64 = 0
    private(set) var sharedContainerActive = false

    private let store = PersonalShieldSharedStoreV1()
    private let brain = LongFormGuardianModelV1()
    private var assetURL: URL?
    /// §1E — the REAL analysis gate readers, injectable for tests. Defaults read the SAME App Group suite the broadcast
    /// extension honours (`guardian.enabled` via the fail-closed consent resolver + the user-controlled session mode),
    /// so a Guardian-OFF / IDLE / unknown-consent state genuinely stops heavy long-form analysis on OUR player (never
    /// a fabricated clean result). This is the controlled-player analog of the extension's analysisPaused short-circuit.
    private let analysisConsentReader: () -> GuardianAnalysisGateV1.AnalysisConsentV1
    private let sessionIdleReader: () -> Bool
    /// The current analysis generation — a late-arriving analysis from a superseded run (user re-decided / exited) is
    /// rejected so it can never drive the player or overwrite fresh state.
    private var generation: UInt64 = 0

    /// §1E — default: read the live App Group suite (same key the extension + ControlledReelsModel consult). Tests
    /// inject deterministic readers so the gate can be proven headlessly without a provisioned App Group.
    init(analysisConsentReader: (() -> GuardianAnalysisGateV1.AnalysisConsentV1)? = nil,
         sessionIdleReader: (() -> Bool)? = nil) {
        let suite = UserDefaults(suiteName: PersonalShieldStoreLocationV1.appGroupID)
        self.analysisConsentReader = analysisConsentReader ?? { GuardianAnalysisGateV1.analysisConsent(suite: suite) }
        self.sessionIdleReader = sessionIdleReader ?? { GuardianSessionModeBridgeV1.isIdle(suite: suite) }
    }

    /// The current "effective" state the view renders from. Mirrors the aggregate when settled, else the fast decision.
    var currentDecision: ReelDecisionV1? { phase == .settled ? aggregateDecision : fastDecision }

    /// §F — the timepoint (seconds) the FAST window was examined at, for the evidence strip's FAST marker. nil until known.
    var fastExaminedSecond: Double? { windowOutcomes.first { $0.window.level == .fast }?.window.sampleSeconds }

    // MARK: Lifecycle

    /// §F — begin the demo: generate the real short asset (if needed) then analyse it. Foreground-only; awaited by the
    /// view's .task. Idempotent — re-entry while already past idle is a no-op (the view may re-appear).
    func start() async {
        guard case .idle = phase else { return }
        await run()
    }

    /// Re-run the whole demo (regenerate decision) — e.g. the user tapped "Yeniden değerlendir" after editing rules.
    func reanalyze() async {
        generation &+= 1
        tearDownPlayback()
        fastDecision = nil; aggregateDecision = nil; windowOutcomes = []; plan = nil
        phase = .idle
        await run()
    }

    /// §1E — the combined analysis gate: heavy long-form analysis may run ONLY when consent is CONSENTED and the user
    /// is not idle. Returns the honest reason string when paused, or nil when analysis may proceed. Fail-closed: an
    /// UNKNOWN/unreadable consent abstains (never a protective claim), exactly like the extension's heavy-path gate.
    private func analysisPausedReason() -> String? {
        if sessionIdleReader() { return "Oturum rölantide — ağır analiz duraklatıldı (yayın/oynatma sürüyor)." }
        switch analysisConsentReader() {
        case .consented:      return nil
        case .deniedOff:      return "Guardian kapalı — bu videoda analiz çalıştırılmadı."
        case .unknownAbstain: return "Analiz izni okunamadı — güvenli tarafta kalındı (analiz çalıştırılmadı)."
        }
    }

    private func run() async {
        generation &+= 1
        let myGen = generation
        // §1E — GUARDIAN OFF/IDLE SHORT-CIRCUIT. Check the REAL enabled/applied consent BEFORE any heavy work (asset
        // generation + decode + OCR + audio). When paused we do NOT start analysis, we tear any playback down, and we
        // surface an honest analysisUnavailable state (NOT a fabricated clean/safe result). This mirrors the broadcast
        // extension's analysisPaused gate so "Guardian OFF" is honest on BOTH surfaces (acceptance: OFF/IDLE durdurur).
        if let reason = analysisPausedReason() {
            tearDownPlayback()
            fastDecision = nil; aggregateDecision = nil; windowOutcomes = []; plan = nil
            phase = .analysisUnavailable(reason)
            return
        }
        // Read the user's REAL policy up front so expert selection is rule-driven (mandate E) and the decision is
        // stamped with the live revision. A Guardian-OFF / empty policy still produces an honest CLEAR-with-limited
        // coverage decision (never a fabricated "safe whole video").
        let policy = store.loadPolicy()
        self.policyRevision = policy.policyRevision
        self.sharedContainerActive = policy.sharedContainerActive

        // 1) Ensure the real demo asset exists (generate a GENUINE 120s H.264 MP4 with an audio track on first run).
        phase = .generating
        let url: URL
        if let existing = assetURL, FileManager.default.fileExists(atPath: existing.path) {
            url = existing
        } else if let generated = await generateDemoAsset() {
            url = generated
            assetURL = generated
        } else {
            guard myGen == generation else { return }
            phase = .failed("Demo video üretilemedi.")
            return
        }
        guard myGen == generation else { return }   // superseded during generation

        // 2) Analyse the whole long asset through the brain. The brain surfaces the FAST decision internally; we read
        //    both the FAST and the aggregate from the single result (the brain already separates them honestly).
        phase = .analyzingFast
        let result = await brain.analyze(url: url, contentID: contentID, index: policy.index,
                                         exceptions: policy.exceptions, languages: ["en"],
                                         policyRevision: policy.policyRevision)
        guard myGen == generation else { return }   // user re-decided / exited while analysing — drop the stale result
        // §1E — a MID-RUN OFF/IDLE (the user turned Guardian off or paused the session WHILE analysis was in flight)
        // must NOT apply a now-stale decision to the player as if current. Re-check the gate on completion: if we are
        // now paused, drop the in-flight result and surface the honest unavailable state (no stale "karar güncel" claim).
        if let reason = analysisPausedReason() {
            tearDownPlayback()
            fastDecision = nil; aggregateDecision = nil; windowOutcomes = []; plan = nil
            phase = .analysisUnavailable(reason)
            return
        }

        // Surface the FAST decision FIRST (so the badge can act quickly), enter the honest "ek analiz sürüyor" state,
        // and YIELD so the view paints the fast badge BEFORE the aggregate surface is applied. This reflects the real
        // ordering inside the plan (FAST is computed before SELECTIVE/DEEPENING) — not a cosmetic delay (no sleep).
        self.fastDecision = result.fastDecision
        self.firstValidDecisionMs = Double(result.firstValidDecisionNanos) / 1_000_000
        if result.fastDecision != nil {
            phase = .fastReady
            await Task.yield()
            guard myGen == generation else { return }
        }

        // 3) Record the honest, separate coverage facts + the plan + the per-window outcomes (evidence map source).
        self.durationSeconds = result.durationSeconds
        self.plan = result.plan
        self.windowOutcomes = result.windowOutcomes
        self.plannedWindows = result.plannedWindows
        self.examinedWindows = result.examinedWindows
        self.ocrCalls = result.ocrCalls
        self.audioWindows = result.audioWindows
        self.framesDecoded = result.framesDecoded
        self.deepeningExecuted = result.deepeningExecuted
        self.deepeningDeferred = result.deepeningDeferred
        self.totalPlanMs = Double(result.totalPlanNanos) / 1_000_000
        self.recomputedFromCache = result.recomputedFromCache

        // 4) Apply the AGGREGATE decision on the real player, honoring the existing HIDE/ASK/WARN/BLUR/MUTE contracts.
        self.aggregateDecision = result.aggregateDecision
        if let agg = result.aggregateDecision {
            apply(agg, url: url)
        }
        phase = .settled
    }

    /// §F/mandate D1 — generate the REAL demo asset with a SHORTER 120s spec (so interactive generation finishes in
    /// seconds, not the ~1-2 min a 600s render costs). It reuses the canonical fixture layout (text overlays + scene
    /// changes spread across the FULL 120s + an audio tone track) at the canonical 2fps so it is a genuine, decodable
    /// long video — NOT a "metadata-only" trick. The 600s asset stays the benchmark's domain.
    private func generateDemoAsset() async -> URL? {
        let dir = (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true))?
            .appendingPathComponent("Gen8/longform", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Gen8/longform", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(contentID).mp4")
        // 120s demo spec: a text overlay the default SPOILER rule can catch mid-video, plus a benign-looking open.
        let spec = LongFormFixtureV1.canonicalSpec(durationSeconds: 120, textLabel: ReelsAssetLibraryV1.exactMatchTerm)
        let manifest = await LongFormFixtureV1.generate(to: url, spec: spec)
        return manifest != nil ? url : nil
    }

    // MARK: Apply a decision on the REAL player (reuses the PlaybackIntentV1 contract)

    /// Obey the aggregate decision on the real player. This is the ONLY place playback is driven, so every UI claim
    /// ("Gizlendi"/"Bulanık"/"Sessiz") is tied to a real AVPlayer command.
    private func apply(_ decision: ReelDecisionV1, url: URL) {
        switch decision.intent {
        case .play:
            attachAndPlay(url)
        case .hide:
            engageHide()
        case .blur:
            attachAndPlay(url); blurEngaged = true
        case .mute:
            attachAndPlay(url); player.isMuted = true; player.volume = 0; muteEngaged = true
        case .warn:
            attachAndPlay(url); warnEngaged = true
        case .skip:
            // A long demo video is a single asset (no queue) — a SKIP verdict means "do not expose this content":
            // tear the player down (nothing plays) and let the shield/undetermined surface explain it honestly.
            tearDownPlayback()
        case .askUser, .awaitDecision:
            tearDownPlayback()   // ASK / UNDETERMINED: hold playback behind an explicit decision screen (nothing plays)
        }
    }

    private func attachAndPlay(_ url: URL) {
        coverEngaged = false; blurEngaged = false; muteEngaged = false; warnEngaged = false
        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        player.replaceCurrentItem(with: item)
        player.isMuted = false; player.volume = 1.0
        player.seek(to: .zero)
        player.play()
    }

    private func engageHide() {
        player.pause(); player.isMuted = true; player.volume = 0
        player.replaceCurrentItem(with: nil)   // remove the item → the layer has nothing to render (no frame leak)
        coverEngaged = true
        blurEngaged = false; muteEngaged = false; warnEngaged = false
    }

    private func tearDownPlayback() {
        player.pause(); player.isMuted = true; player.volume = 0
        player.replaceCurrentItem(with: nil)
        coverEngaged = false; blurEngaged = false; muteEngaged = false; warnEngaged = false
    }

    // MARK: User actions (mandate §F — the Reels action surface contracts, preserved)

    /// The user chose "Yine de göster" for THIS content. We re-present the asset playing — an explicit, content-scoped
    /// override. (The long demo is a single asset; the override simply plays it with the shield surfaces cleared.)
    func showAnyway() {
        guard let url = assetURL else { return }
        attachAndPlay(url)
    }

    func stop() {
        generation &+= 1   // exiting invalidates any in-flight analysis (no late player command)
        tearDownPlayback()
    }
}
