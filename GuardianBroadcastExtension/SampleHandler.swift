//
//  SampleHandler.swift — ReplayKit Broadcast Upload Extension (PROMPT 007D)
//  The ONLY official iOS cross-app screen path: user starts a system broadcast (red bar), this extension receives
//  whole-screen CMSampleBuffers of WHATEVER app is on screen (Instagram, etc.). 100% public API. No private API.
//
//  Discipline (enforced here):
//  - Raw frames are EPHEMERAL: processed in-place, never written to disk, never uploaded. We keep only a 64-bit
//    perceptual signature (aHash) + derived counters.
//  - Frame-driven heavy AI is forbidden: every frame runs an ultra-cheap aHash + layout hash through the canonical
//    ContentBoundaryEngineV2 (shared with lab); downstream analysis runs ONLY on a committed NEW_CONTENT. ~50 MB budget.
//  - os_signpost intervals make CPU/energy measurable in Instruments.
//
import ReplayKit
import CoreVideo
import GuardianCore
import os
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(SoundAnalysis)
import SoundAnalysis
#endif

final class SampleHandler: RPBroadcastSampleHandler {
    // P009A: the FROZEN V5 sensor reclassified under its true contract — SHOT/persistent-visual-segment detection
    // (boundary-policy-v5, untouched). Above it, the extension-local TIER-0 item-grouping brain (§9/§22): cheap
    // derived continuity only (visual theme + chrome + transition + cadence; no caption/audio in this process).
    // Item grouping decides which shots belong to the same CONTENT ITEM; shots never claim to be items again.
    private let shotSegmenter = ShotSegmenterV5(observationID: ObservationID(1))
    // P009A-R1: PROFILE-AWARE grouping — the extension runs its OWN frozen Tier-0 policy
    // (item-grouping-policy-v2-extension-tier0), gated by its OWN predeclared Tier-0 lab suite. Same-scores are
    // normalized by the Tier-0 evidence ceiling; missing modalities are never negative evidence; strong-new veto
    // absolute. Deferred coalescer repairs ambiguous internal splits later (content-anchored, never forced).
    private let itemGrouper = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
    private let coalescer = DeferredItemCoalescerV1()
    private let governor = ResourceGovernorV1()
    // PHASE C §3/§8: Tier-0 emits PROVISIONAL identity + a bounded Tier-1 handoff buffer (derived-only, in-process).
    private let handoffBuffer = Tier1HandoffBufferV1()
    // §5 derived-only per-frame motion telemetry. Enabled at BUILD level (no App Group needed): compile with
    // -D GEN8_EVIDENCE_BUILD, OR env GEN8_EVIDENCE_BUILD=1. Logs ONLY derived scalars — NEVER raw frames/audio/OCR/title.
    // §10 release policy (testable: EvidenceBuildPolicyV1) — high-volume evidence logging is structurally OFF in
    // release; compile flag enables it; DEBUG builds may opt in via env. The Phase-B THERMAL_SERIOUS incident was
    // caused by this logging and is NOT release behavior.
    #if GEN8_EVIDENCE_BUILD
    private let evidenceBuild = EvidenceBuildPolicyV1.isEnabled(compileFlagSet: true, isDebugBuild: true, envOptIn: false)
    #elseif DEBUG
    private let evidenceBuild = EvidenceBuildPolicyV1.isEnabled(compileFlagSet: false, isDebugBuild: true,
        envOptIn: ProcessInfo.processInfo.environment["GEN8_EVIDENCE_BUILD"] == "1")
    #else
    private let evidenceBuild = EvidenceBuildPolicyV1.isEnabled(compileFlagSet: false, isDebugBuild: false, envOptIn: false)
    #endif
    private var evFrame = 0
    private var stats = CrossAppObservationStats()
    private let evaluator = ShieldEvaluatorV2.standard()
    private var index = ShieldIndex()
    // B1/B2 — the user's REAL personal shield rules, loaded from the SHARED App Group store at broadcast start
    // (replaces the old hardcoded `demo-spoiler` rule). The app is the writer; this extension is the reader. The
    // policy REVISION is captured so every decision this session is stamped with the rule-set version it ran under
    // (mandate B2: a later rule change invalidates a decision produced under the old revision).
    private let sharedShieldStore = PersonalShieldSharedStoreV1()
    private var shieldExceptions: [ShieldException] = []
    // R8 §7 — the user's RAW rules (with aliases) kept alongside the rebuilt index, so the live ALIAS pass
    // (PersonalAliasMatchV1) can read each `.entity` rule's canonical name + user-typed aliases. The frozen index
    // alone does not expose the alias terms in a form the word-boundary matcher needs; the raw rules do.
    private var shieldRules: [ShieldRuleV2] = []
    private var policyRevision: UInt64 = 0
    private var sharedRulesActive = false   // false → no shared rules visible (honest: we don't claim protection)
    // R2 §B — the user's DERIVED PHOTO-REFERENCE signatures (image/logo), loaded alongside the rules. The live
    // photo-shield matcher (PhotoShieldLumaMatcherV1) compares the current frame's in-place luma signature against
    // these. Empty → no photo references → the photo pass is a cheap no-op. Raw media is NEVER here (P006C: derived
    // signature bytes only). Reloaded on the same ~1s policy gate as the text rules.
    private var shieldFeatures: [DerivedReferenceFeature] = []
    // R2 §B6 — session counters for the honest cost report (how much visual work the photo shield actually did).
    private var photoSignaturesComputed = 0
    private var photoROIsEvaluated = 0
    private var photoItemsConsidered = 0
    private var photoActionableMatches = 0
    private var photoSkippedThermal = 0
    // R3 §2 (sibling deferral) — LONG-LIVED DECISION VALIDITY window. On STATIC content (same resolved item, no new
    // decision) a cheap revalidation EXTENDS the decision's validity so the user does not lose their band on content
    // they are still looking at — WITHOUT falsifying the original evidence epoch (GuardianDecisionRevalidationV1). The
    // window is opened whenever a fresh decision is produced and cheaply revalidated on the reuse (static) path.
    private var decisionValidityWindow: GuardianDecisionValidityWindowV1? = nil
    // R4 §2B — STATIC-FRAME REVALIDATION on a SHOT-INDEPENDENT time gate. The R3 revalidation only ran on the
    // committed-shot (reuse) path, so a TRULY STATIC screen — one that commits NO new shots — never revalidated and
    // its decision silently aged out under the user while they were still looking at it. This gate runs a CHEAP,
    // shot-independent validity check on frame cadence (identity stable iff the cheap motion signal shows no scene
    // change AND the decision item/policy are unchanged). On acceptance it EXTENDS the validity window (its own
    // timestamp + provenance; the original evidence epoch NEVER moves). When the bounded budget (12) is exhausted the
    // revalidation REFUSES — which the decision-validity publish then reflects as an honest aged-out state (no fake
    // extension forever). Same ~1s cadence as the heartbeat; cost is one cheap check per interval (no OCR/Tier-1).
    private var lastRevalidationTickMs: Double = -.greatestFiniteMagnitude
    private static let revalidationTickMinIntervalMs: Double = 1000.0
    // R3 §9 (sibling deferral) — MEASURE-ONLY self-eval counters folded over the session (never a behaviour change).
    private var selfEvalCounters = GuardianSelfEvalCountersV1()
    // A1 — set true when a live rule reload advanced the policy revision; forces the current item to re-evaluate
    // against the new policy on the very next committed frame (consumed once in processSampleBuffer).
    private var policyChangedForceReeval = false
    // R7 §1 — THERMAL-RECOVERY BOUNDED REEVALUATION. When the world-model analysis was SKIPPED for a CHILD/TEEN item
    // under thermal pressure, the item's decision is a fail-closed ANALYSIS-DEFICIT state. If thermal later RECOVERS
    // while the user is still on the SAME item, that item must be RE-EVALUATED once (the deficit decision cannot
    // persist now that the analysis can run). We remember the last item that was child-deferred under thermal; when a
    // committed frame arrives with a non-hot thermal bucket for that same item, we force a single fresh evaluation
    // (reusing the existing force-reeval path). Reset once the reevaluation runs (bounded: one forced reeval per
    // deferral episode, not per frame). -1 = nothing deferred.
    private var thermalDeferredChildItemRevision = -1
    // R5 §2 — the SHARED FAMILY PROFILE (app = writer, this extension = reader). Loaded at broadcast start and
    // re-read on the SAME ~1s policy gate via its OWN monotonic revision key (independent of the personal-shield
    // revision — the two policies never disturb each other). A family change invalidates the current decision
    // exactly like a shield policy change (surface dropped + validity window killed + forced re-eval), so the
    // Island can never carry a decision produced under the old family policy.
    private let familyStore = FamilyProfileSharedStoreV1()
    private var familyProfile: FamilyProfileV1? = nil
    private var familyProfileState: FamilyProfileStateV1 = .missing
    private var familyRevision: UInt64 = 0
    // R5 §2 — true when a child/teen mode is/was known active but the CURRENT family read is degraded (STALE /
    // CORRUPT). The adjudicator fails closed on this (UNKNOWN surface, distinct reason) — the old child policy is
    // NEVER presented as current (mandate: App Group read failure → honest state, never stale-as-fresh).
    private var familyDegradedNonAdult = false
    // C3 fix: REAL on-device Vision OCR, EVENT-GATED (only when a new item opens) + RATE-LIMITED (>=1s between
    // runs) + SERIAL (in-flight guard drops overlapping requests). See BroadcastOCRRunner.swift for cost rationale.
    private var ocrThrottle = BroadcastOCRThrottleV1(minIntervalMs: 1000)
    // P010 TIER-1: multimodal item identity (Vision feature print + OCR trigram + Tier-0 tie-break fusion).
    // Tier-0 PROPOSES item boundaries; Tier-1 CONFIRMS/OVERRIDES; UNKNOWN keeps the Tier-0 proposal (abstention
    // law). Same cost discipline as C3 OCR: committed-shot event gate + >=1s rate limit + serial + <=512px
    // downscale, all inside the component (Tier1ItemIdentityV1.swift — shared source, GuardianMedia-owned).
    private let tier1 = Tier1ItemIdentityV1(policy: .v1)
    // P1 PRODUCT: Tier-1's SAME/NEW/UNKNOWN verdict RESOLVES the identity the Guardian binds evidence to, BEFORE
    // the shield pass. Prevents false safe-state inheritance across items (a Tier-0 false-merge can no longer let
    // the Guardian reuse a prior item's decision for different content). Pure/headless — Tier1IdentityResolutionV1.
    private lazy var identityResolver = Tier1IdentityResolverV1(sessionID: sessionID)
    private let log = Logger(subsystem: "com.gen8.guardian.dev.GuardianBroadcast", category: "CrossApp")
    private let sp = OSSignposter(subsystem: "com.gen8.guardian.dev.GuardianBroadcast", category: .pointsOfInterest)
    private var sessionStartNanos: UInt64 = 0
    private var peakMemoryMB = 0.0
    private var frameDurationsNs: [UInt64] = []      // bounded sample for latency telemetry
    // A3 — REAL observation-active evidence published to the app over the App Group (heartbeat). The app derives
    // observation-active from the FRESHNESS of this (never from its own in-app toggle). nil suite → DEGRADED (no
    // cross-process IPC); we still run, we just can't prove liveness to the app, which then shows UNAVAILABLE.
    private let heartbeatSuite = UserDefaults(suiteName: "group.com.gen8.guardian.dev")
    private var heartbeatSeq: UInt64 = 0
    private var lastResolvedSurfaceRaw = ""
    private var lastReasonCodeRaw = GuardianReasonCodeV1.observingNoDecisionYet.rawValue
    // R2 §A — INDEPENDENT decision facts, tracked separately from the heartbeat publish time so the app can enforce
    // "a fresh heartbeat does NOT make an old decision fresh" and "a new current item invalidates the prior decision".
    // `lastDecisionEpoch` is the REAL time the current per-content surface was produced (0 = none yet). `lastDecision
    // ItemRevision` is the item identity that surface was bound to. `lastObservedItemRevision` is the LATEST item the
    // engine has seen on screen — it can advance past the decision's item before a fresh decision is produced, which
    // is exactly the STALE_ITEM case the app must catch. These are published as distinct heartbeat fields.
    private var lastDecisionEpoch: Double = 0
    private var lastDecisionItemRevision: Int = -1
    private var lastObservedItemRevision: Int = -1
    // A1 — a per-SESSION id, minted once per broadcast. Stamped on the heartbeat, the capture tokens and the
    // timeline so a PREVIOUS session's stale IPC state (heartbeat that is still within the time window, a repeated
    // shot id, a prior timeline snapshot) can NEVER be mistaken for this session's. New session ⇒ new id ⇒ old
    // evidence rejected.
    private let sessionID = UUID().uuidString
    // A1 — the heartbeat is now written on a LOW-FREQUENCY TIME GATE from the RAW VIDEO path (every frame enters,
    // but we only write at most once per interval), NOT only from the committed-shot path. A static scene commits
    // no shots, so the old shot-driven heartbeat could go STALE within the 3s window and the app would wrongly show
    // the session as stopped. This time gate keeps liveness truthful on a frozen scene at a tiny, bounded cost
    // (one JSON encode per interval, never per frame).
    private static let heartbeatMinIntervalMs: Double = 1000.0
    private var lastHeartbeatMs: Double = -.greatestFiniteMagnitude
    // A1 (FIX — live rule reload): the extension previously loaded the user's rules ONCE at broadcastStarted, so a
    // rule edited DURING a broadcast never took effect and the user had to restart. We now RE-READ the shared
    // policy revision on the SAME ~1s heartbeat time-gate. When it advances we reload the rule index + exceptions,
    // IMMEDIATELY invalidate any decision stamped under the old revision (so the stale surface is never shown as
    // "current"), and force the CURRENT item to be re-evaluated against the new policy — no restart required. On a
    // load failure we degrade HONESTLY to UNKNOWN/UNAVAILABLE rather than keeping a stale "protected" claim.
    private var lastPolicyCheckMs: Double = -.greatestFiniteMagnitude
    private static let policyCheckMinIntervalMs: Double = 1000.0
    // §5 — USER-CONTROLLED ACTIVE/IDLE. The app / Control Center writes the session mode to the App Group; the
    // extension re-reads it on the SAME ~1s heartbeat gate (cheap: one UserDefaults read). In IDLE the heavy path
    // (OCR / Tier-1 / shield commit) is SKIPPED and we publish an OBSERVING_IDLE heartbeat so "koruma aktif" is
    // suppressed — the honesty law of §5.4. App-based AUTO idle stays OFF (DEVICE_UNVERIFIED — see the probe below).
    private var sessionIdle = false
    // §A — the user's PRODUCT on/off intent, read from the SAME App Group key the Control Center ON/OFF intent and the
    // app write (`guardian.enabled`). This is now a REAL analysis gate: Guardian OFF short-circuits the heavy path
    // exactly like idle (shot-brain / Tier-0 / OCR / Tier-1 / shield commit are SKIPPED), the heartbeat publishes an
    // honest OFF-equivalent state, and — because iOS owns the ReplayKit feed — the OS broadcast physically continues
    // (we never claim we stopped it). Re-read on the same ~1s gate as the mode. Defaults ENABLED (fresh/absent) and
    // when IPC is DEGRADED (we never fabricate an OFF we cannot actually read).
    private var guardianEnabled = true
    // A1 — the FAIL-CLOSED analysis-consent resolution (unknown ≠ consent). `guardianEnabled` above is the raw intent
    // used ONLY for the honest OFF-vs-UNKNOWN reason copy; whether the HEAVY path may run is decided by `analysisConsent`
    // (CONSENTED only when a deliberate ENABLED intent is readable). A nil/degraded suite or an absent key ABSTAINS —
    // the heavy path does NOT run and we never claim protection (acceptance #12: a silent OFF bypass is impossible).
    private var analysisConsent: GuardianAnalysisGateV1.AnalysisConsentV1 = .unknownAbstain
    // §A/§B — the combined gate: heavy analysis runs only when the consent is CONSENTED and the user is not idle.
    // Edge handling mirrors idle (drop stale surface on entering a paused state; force re-eval on resuming analysis).
    private var analysisPaused: Bool { sessionIdle || !analysisConsent.mayRunAnalysis }
    // §5.5 — on the ACTIVE→IDLE edge we invalidate the current surface so a stale positive decision can never
    // survive into idle; on IDLE→ACTIVE (wake) we force a fresh evaluation so old evidence is never reused.
    private var idleEdgeForceReeval = false
    // §B — the last applied-gate state we ACKed to the app (so we only write a new ack when the effective mode
    // actually changed), and whether we have ever acked this session.
    private var lastAckedAppliedIdle: Bool? = nil
    // §5.2 — the HONEST capability probe (app-identity from ReplayKit attachments). Runs ONLY under the evidence
    // gate; default verdict is FEATURE_UNAVAILABLE until a real device run proves PRESENT_AND_UPDATES. It changes
    // NO behaviour — it only measures, so auto-idle cannot be fabricated.
    private var capabilityProbe = GuardianBroadcastCapabilityProbeV1()
    // §F — the TRANSITION-CORRELATION probe (V2). It scores temporal AGREEMENT against a pre-defined A→B→A foreground
    // script (performed by a device operator), separates the two identity SOURCES (annotation callback vs sample
    // attachment), and compares via a per-session key WITHOUT retaining identity. Runs ONLY under the evidence gate;
    // changes NO behaviour (default FEATURE_UNAVAILABLE off-device). The attachment source is fed the SAME documented
    // key V1 reads; the callback source is fed from broadcastAnnotated(withApplicationInfo:) if iOS ever delivers it.
    private var capabilityProbeV2 = GuardianBroadcastCapabilityProbeV2(script: GuardianBroadcastCapabilityProbeV2.defaultScript)
    // §F — the OPERATOR-ASSERTED scripted step index for the device experiment. nil in normal operation (free-run →
    // the probe can never claim scripted agreement). During a controlled, consented device run an operator harness
    // writes the current schedule step (0=A, 1=B, 2=A) to this App Group key per the tap schedule; the extension reads
    // it on the evidence gate so the probe can learn the label↔identity binding and score temporal agreement HONESTLY.
    private static let probeScriptStepKey = "guardian.probe.assertedStepIndex.v1"
    private var probeAssertedStepIndex: Int? {
        guard evidenceBuild, let suite = heartbeatSuite, suite.object(forKey: Self.probeScriptStepKey) != nil else { return nil }
        return suite.integer(forKey: Self.probeScriptStepKey)
    }
    private var lastProbeLogMs: Double = -.greatestFiniteMagnitude
    private static let probeLogMinIntervalMs: Double = 2000.0
    // C/D-lane — the LIVE SESSION TIMELINE writer (bounded RAM ring + bounded App Group mirror). Session-scoped;
    // cleared on finish. Distinct cadence from the heartbeat (meaningful events only, never per frame).
    private lazy var timeline = GuardianSessionTimelineWriterV1(sessionID: sessionID, suite: heartbeatSuite)
    private var lastTimelineIdentityRevision = -1
    // R4 §6 — PROGRESSIVE UNDERSTANDING. Track the decision reason the CURRENT item last surfaced under, so that when
    // the SAME item is re-evaluated and the surface CHANGES (more context accumulated while the user stayed), the
    // timeline records the change WITH provenance (previous reason + change reason). Keyed to the item revision so a
    // prior item's reason can NEVER leak onto a new item (evidence isolation — pinned by a test).
    private var lastDecisionReasonForItem: String? = nil
    private var lastDecisionReasonItemRevision = -1

    // R8 §1 — LIVE AUDIO CAPTURE. The capability probe (derived counters only; never raw audio) + the bounded
    // drop-oldest hand-off queue. Audio buffers arrive on `processSampleBuffer(_:with: .audioApp)`; we record their
    // derived facts into the probe and append a minimal derived sample to the bounded queue, then RETURN immediately
    // so the serial callback is never blocked by analysis. `.audioMic` is NEVER processed (explicit comment at the
    // callback). Off-device no audioApp buffers arrive, so the probe verdict stays FEATURE_UNVERIFIED (the mechanism
    // is the deliverable; AUDIO_CAPTURE_AVAILABLE requires a real device run = DEVICE_UNVERIFIED).
    private var audioCaptureProbe = AudioCaptureProbeV1()
    // R10 §1 — whether a capture session is live (true between broadcastStarted/broadcastFinished). The async audio
    // completion reads it: a result completing after capture stopped is DROPPED (no apply into a dead capture). Written
    // only on the ReplayKit lifecycle callbacks (serial); read under no lock (a stale `true` just lets the revalidator
    // catch the other mismatches; a stale `false` can only make the completion MORE conservative — drop — never apply).
    private var captureActive = false
    // R9 §2.1/§2.2 — the PARALLEL bounded PCM store (device path only). The capture callback extracts a MINIMAL
    // short-lived AVAudioPCMBuffer COPY (owns its own memory; safe after the callback returns) and appends it here
    // alongside the queue's derived facts. AVAudioPCMBuffer is a reference type (not Sendable/Equatable), so it cannot
    // live in the pure testable BoundedAudioQueueV1; this store is bounded by the SAME capacity and drops oldest in
    // lockstep with the queue. Off-device no audioApp buffers arrive → it stays empty. Never written to disk/network.
    #if canImport(AVFoundation) && canImport(SoundAnalysis)
    private struct QueuedPCMV1 { let pcm: AVAudioPCMBuffer; let ptsSeconds: Double?; let generation: UInt64; let itemRevision: Int }
    private var audioPCMStore: [QueuedPCMV1] = []   // the short-lived PCM copies (SoundAnalysis-typed; released at window completion)
    private let audioPCMLock = NSLock()             // R10 §2 — guards audioPCMStore (touched on callback + apply paths)
    // R10 §2.2 — the dedicated OFF-CALLBACK audio worker queue (serial). PCM conversion already ran on the callback
    // (minimal, short-lived); the heavy SoundAnalysis window drive runs on THIS queue so it never blocks the ReplayKit
    // video callback. R10 §1: the window analysis is SUBMITTED ASYNC here and the heavy path RETURNS immediately — the
    // completion re-validates + applies progressively. The queue is serial so windows don't interleave on it.
    private let audioWorkerQueue = DispatchQueue(label: "com.gen8.guardian.audio.worker", qos: .utility)
    private let audioStreamSession = LiveAudioStreamSessionV1()
    #endif
    // R10 §2 — the ONE OWNERSHIP store: bounds the derived hand-off (count/bytes/duration) AND the OUTSTANDING-window
    // count under one serial-queue discipline; tracks a memory high-water mark; purged at session end (no leakage).
    private let audioHandoff = AudioHandoffStoreV1()
    // R8 §4 — how many audio windows were analyzed for the CURRENT item (bounded per item; reset on item change). The
    // §4 budget gate (windowDecision) uses this so audio never saturates the heavy path OCR already owns.
    private var audioWindowsRunThisItem = 0
    private var audioWindowItemRevision = -1
    // R8 §3 / R10 §1 — the LAST RESOLVED audio window's evidence for the CURRENT item, bound to {session, revision,
    // generation, PTS span}. Updated by the ASYNC completion (revalidated first); read by the heavy path + heartbeat.
    // Guarded by `audioStateLock` because the async apply writes it off the ReplayKit callback thread (R10 §2 threading).
    private let audioStateLock = NSLock()
    private var liveAudioForItem: LiveAudioWindowEvidenceV1? = nil
    // R10 §1 — the DISTINCT PENDING coverage lifecycle for the current item: `.pending` while a window is in flight on
    // the async worker (coverage = "ses: analiz sürüyor"); `.resolved` once a completion applied; `.notAttempted` when
    // no window was requested. PENDING ≠ AVAILABLE — surfaced honestly (§1/§P1-7). Guarded by `audioStateLock`.
    private var audioCoverageLifecycle: AudioCoverageLifecycleV1 = .notAttempted
    // R10 §1 — the monotonic audio window request id + the item revision a PENDING window is in flight for (so a late
    // completion can be revalidated against the live identity). -1 = no window pending.
    private var pendingAudioItemRevision = -1
    // R10 §1 — honest counters for the async apply-or-drop outcomes (every drop is counted, never silent — §1).
    private var audioApplied = 0
    private var audioDroppedLate = 0
    private var audioLastDropReason = ""
    // R10 §1/§5 — the minimal SNAPSHOT captured when a decision is produced for the current item, so the async audio
    // completion can run a BOUNDED progressive RE-ADJUDICATION of the SAME item through the existing bridge/adjudicator
    // (not a second engine). Captured under `audioStateLock`; carries only derived/ephemeral facts the bridge needs.
    private struct AudioReadjudicationSnapshotV1 {
        let ticket: AudioApplyTicketV1
        let contentID: String
        let itemRevision: Int
        let identityConfirmed: Bool
        let generation: UInt64
        let shotID: UInt64
        let observationMs: Double
        let ocrText: String?
        let ocrLanguage: String?
        let photoActionable: Bool
        let register: EmotionalRegisterVerdictV1?
        let contextStance: ContextEvidenceVerdictV1?
        let targeted: TargetedPressureVerdictV1?
        let sharedTextEvidence: [ExpertEvidenceV2]?
        let baseSurfaceRaw: String
        let baseReasonRaw: String
        let generalCharacter: GeneralContentCharacterVerdictV1
        let familyMode: FamilyPolicyModeV1
        let familyGuardianProfile: GuardianEnteredChildProfileV1?
        let parentPreference: ParentPreferencePolicyV1?
        let familyDegradedNonAdult: Bool
        let familyRevision: UInt64
        let policyRevision: UInt64
    }
    private var audioReadjudicationSnapshot: AudioReadjudicationSnapshotV1? = nil
    // R8 §2 — the classifier's REAL supported labels, read ONCE at broadcast start (knownClassifications). Empty when
    // SoundAnalysis is unavailable on this runtime → every audio query is honestly UNAVAILABLE (never a fabricated class).
    private var audioKnownClassifications: [String] = []
    // R8 §2 — session audio counters for the honest cost report (how much audio work actually ran).
    private var audioWindowsAnalyzed = 0
    private var audioWindowsDeferred = 0
    private var audioStaleDiscarded = 0

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        sessionStartNanos = DispatchTime.now().uptimeNanoseconds
        captureActive = true   // R10 §1 — capture is live; a late async audio result may apply (subject to revalidation)
        // B1/B2 — load the user's REAL rules from the shared store (NO hardcoded demo rule). The rebuilt index is
        // crash-safe (never trusted from disk). If the shared container is unavailable or has no rules we honestly
        // run with an EMPTY index and never claim protection.
        let loaded = sharedShieldStore.loadPolicy()
        index = loaded.index
        shieldExceptions = loaded.exceptions
        shieldRules = loaded.rules          // R8 §7 — raw rules (with aliases) for the live alias pass.
        policyRevision = loaded.policyRevision
        sharedRulesActive = loaded.sharedContainerActive
        shieldFeatures = loaded.features   // R2 §B — the user's derived photo-reference signatures (no raw media).
        emit("SHIELD_RULES_LOADED shared=\(loaded.sharedContainerActive) activeRules=\(loaded.index.count) photoRefs=\(loaded.features.count) policyRev=\(loaded.policyRevision)")
        // R5 §2 — load the ACTIVE family profile (parent-entered only; declaration ≠ verified identity). An
        // absent/degraded App Group yields honest MISSING/STALE state — never a stale child policy as fresh.
        reloadFamilyProfile(nowEpoch: Date().timeIntervalSince1970, invalidate: false)
        emit("FAMILY_PROFILE_LOADED state=\(familyProfileState.rawValue) mode=\(familyProfile?.mode.rawValue ?? "-") familyRev=\(familyRevision) shared=\(familyStore.sharedContainerActive)")
        // R8 §2 — read the classifier's REAL supported labels ONCE (knownClassifications). Empty when SoundAnalysis is
        // unavailable on this runtime → every audio query is honestly UNAVAILABLE (never a fabricated class name).
        audioKnownClassifications = LiveAudioEvidenceAdapterV1.knownClassifications()
        emit("AUDIO_CLASSIFIER knownClassifications=\(audioKnownClassifications.count) (classes verified at runtime; no assumed class names)")
        // Honest labeling (audit C1): raw FRAMES are never persisted; this derived proof log IS a disk write.
        emit("BROADCAST_STARTED ephemeral=true rawFramesPersisted=false derivedProofLog=true cloud=false shotPolicy=\(shotSegmenter.policyRevision) groupingPolicy=\(itemGrouper.policy.revision) profile=\(itemGrouper.profile.name) sameCeiling=\(String(format: "%.2f", itemGrouper.sameCeiling)) evidence=\(evidenceBuild)")
        // A3 — the broadcast is REALLY live now: publish an initial OBSERVING heartbeat (no per-content decision
        // yet). The app flips to OBSERVING off this freshness, not off its own toggle. IPC unavailable → no-op.
        lastResolvedSurfaceRaw = ""   // observing, no decision yet
        lastReasonCodeRaw = GuardianReasonCodeV1.observingNoDecisionYet.rawValue
        // §5.5 — a NEW broadcast session always starts ACTIVE; never inherit a prior session's idle choice.
        GuardianSessionModeBridgeV1.clear(suite: heartbeatSuite)
        sessionIdle = false
        // §A — read the PRODUCT on/off intent at start: if Guardian is already OFF, we begin PAUSED (no heavy analysis)
        // and publish the honest OFF-equivalent surface immediately, never an initial OBSERVING claim. iOS still owns
        // the feed, so the broadcast is physically live regardless.
        analysisConsent = GuardianAnalysisGateV1.analysisConsent(suite: heartbeatSuite)
        guardianEnabled = (analysisConsent == .consented)
        if analysisPaused {
            // A1 — OFF or UNKNOWN-ABSTAIN both pause the heavy path. Distinguish the honest reason: a deliberate OFF
            // says "Guardian kapalı, yayın sürüyor"; an UNKNOWN control state is NOT a protective claim and NOT an
            // explicit OFF — it is an unavailable analysis state (we could not read a deliberate consent).
            lastResolvedSurfaceRaw = "OFF"
            lastReasonCodeRaw = (analysisConsent == .deniedOff
                ? GuardianReasonCodeV1.guardianOffBroadcastContinuing
                : GuardianReasonCodeV1.sessionNotObserving).rawValue
        }
        // §B — publish the initial applied ack matching the start gate (so the app sees a current applied state at once).
        lastAckedAppliedIdle = analysisPaused
        GuardianSessionModeBridgeV1.writeAppliedAck(analysisPaused ? .idle : .active,
                                                    ackedGeneration: GuardianSessionModeBridgeV1.desiredGeneration(suite: heartbeatSuite),
                                                    nowEpoch: Date().timeIntervalSince1970, suite: heartbeatSuite)
        // A1 — publish the SESSION-SCOPED analysis OFF-ACK at start so the app can distinguish İsteniyor vs Uygulandı
        // from the first frame. The ack carries THIS session id + the desired generation we observed + whether the
        // heavy path is actually off. A later session or a newer generation invalidates it (no stale confirmation).
        writeAnalysisOffAck()
        publishHeartbeat(nowEpoch: Date().timeIntervalSince1970)
        emit("HEARTBEAT_IPC \(heartbeatSuite != nil ? "ACTIVE" : "DEGRADED(no-app-group)")")
        // C-lane — the first REAL timeline event: the session actually started (broadcast live).
        timeline.record(category: .sessionStarted, status: .active,
                        reasonCodeRaw: GuardianReasonCodeV1.observingNoDecisionYet.rawValue,
                        identityRevision: -1, nowEpoch: Date().timeIntervalSince1970)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with type: RPSampleBufferType) {
        // R8 §1 — APPLICATION AUDIO is GEN8's audio sense (the user-authorized broadcast's app audio). We record its
        // derived capture facts + hand a minimal derived sample to a BOUNDED queue, then return — the serial video
        // callback is never blocked by audio analysis. The MICROPHONE is DELIBERATELY NEVER PROCESSED: `.audioMic` is
        // ignored by design (GEN8 opens no mic session, requests no mic authorization, performs no hidden mic
        // fallback — mandate §1.1). Off-device no audioApp buffers arrive, so this path is DEVICE_UNVERIFIED; the
        // probe mechanism itself is the deliverable.
        switch type {
        case .video:
            break   // fall through to the video path below (unchanged)
        case .audioApp:
            handleAudioAppBuffer(sampleBuffer)
            return
        case .audioMic:
            // EXPLICITLY IGNORED (honest capability note): GEN8 never captures the microphone. No counter, no probe,
            // no analysis — the mic is simply not part of the capture contract. Documented in AudioCaptureProbeV1.
            return
        @unknown default:
            return
        }
        guard let px = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let spState = sp.beginInterval("frame")
        let frameStart = DispatchTime.now().uptimeNanoseconds
        stats.framesProcessed += 1

        // §8 TIME-based: real presentation timestamp (ms) drives dwell/persistence (robust to variable cadence).
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let tsMs = pts.isValid ? CMTimeGetSeconds(pts) * 1000.0 : Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000.0

        // A1 — SHOT-INDEPENDENT heartbeat on a LOW-FREQUENCY TIME GATE. The old heartbeat only published from the
        // committed-shot path, so a STATIC scene (no shot commits) let freshness expire and the app wrongly showed
        // the session stopped. We now publish from the raw frame stream at most once per interval — proving the
        // session is alive regardless of scene motion, at a tiny bounded cost (one JSON encode per interval).
        if tsMs - lastHeartbeatMs >= Self.heartbeatMinIntervalMs {
            lastHeartbeatMs = tsMs
            publishHeartbeat(nowEpoch: Date().timeIntervalSince1970)
        }

        // A1 — LIVE RULE RELOAD on the ~1s time gate (SHOT-INDEPENDENT, like the heartbeat). Cheap: one UserDefaults
        // read per interval, a full reload ONLY when the revision actually advanced.
        if tsMs - lastPolicyCheckMs >= Self.policyCheckMinIntervalMs {
            lastPolicyCheckMs = tsMs
            reloadPolicyIfChanged(nowEpoch: Date().timeIntervalSince1970)
            // R5 §2 — re-read the FAMILY revision on the SAME cadence (one UserDefaults read when unchanged).
            reloadFamilyProfileIfChanged(nowEpoch: Date().timeIntervalSince1970)
            // §5 — re-read the USER-CONTROLLED session mode on the SAME cadence (cheap single read).
            // §A — re-read the PRODUCT on/off intent (`guardian.enabled`) on the SAME cadence (one UserDefaults read).
            let wantIdle = GuardianSessionModeBridgeV1.isIdle(suite: heartbeatSuite)
            // A1 — FAIL-CLOSED consent re-read. `wantConsent` drives whether the heavy path may run; the raw enabled
            // flag is derived only for the honest reason copy.
            let wantConsent = GuardianAnalysisGateV1.analysisConsent(suite: heartbeatSuite)
            let wantEnabled = (wantConsent == .consented)
            let wasPaused = analysisPaused
            if wantIdle != sessionIdle || wantConsent != analysisConsent {
                sessionIdle = wantIdle
                analysisConsent = wantConsent
                guardianEnabled = wantEnabled
                let nowPaused = analysisPaused
                if nowPaused {
                    // §5.5/§A paused edge: drop the current surface so no stale positive survives while heavy analysis
                    // is off. The heartbeat carries an honest OFF-equivalent reason: OBSERVING_IDLE when the user chose
                    // idle, GUARDIAN_OFF when a deliberate OFF, or SESSION_NOT_OBSERVING when the control state is
                    // UNKNOWN (A1: unknown ≠ a protective claim, and ≠ an explicit OFF either).
                    lastResolvedSurfaceRaw = "OFF"   // OFF-like gray band; never a protective look while paused
                    lastReasonCodeRaw = {
                        if sessionIdle { return GuardianReasonCodeV1.observingIdle.rawValue }
                        return (analysisConsent == .deniedOff
                            ? GuardianReasonCodeV1.guardianOffBroadcastContinuing
                            : GuardianReasonCodeV1.sessionNotObserving).rawValue
                    }()
                } else {
                    // §5.5/§A resume edge (wake / re-enable): force a fresh evaluation so OLD evidence is never reused;
                    // the surface returns to observing-no-decision until new content produces one.
                    idleEdgeForceReeval = true
                    lastResolvedSurfaceRaw = ""
                    lastReasonCodeRaw = GuardianReasonCodeV1.observingNoDecisionYet.rawValue
                }
                clearDecisionFacts()   // §A — paused/resume edge: the prior decision no longer applies.
                publishHeartbeat(nowEpoch: Date().timeIntervalSince1970)
                timeline.record(category: nowPaused ? .observationGap : .observationResumed,
                                status: nowPaused ? .ended : .active,
                                reasonCodeRaw: lastReasonCodeRaw,
                                identityRevision: lastTimelineIdentityRevision, nowEpoch: Date().timeIntervalSince1970)
                // A1 — on every effective-gate change, re-publish the SESSION-SCOPED analysis OFF-ACK so the app can
                // prove the heavy path really stopped (Uygulandı) vs merely requested (İsteniyor). Written for THIS
                // session at the CURRENT desired generation — a silent bypass (intent OFF, analysis still running) is
                // impossible to misread because the ack carries `analysisOff` = our true applied state.
                writeAnalysisOffAck()
                emit("SESSION_GATE idle=\(sessionIdle) consent=\(analysisConsent.rawValue) paused=\(nowPaused) (user-controlled; app-based auto-idle=FEATURE_UNAVAILABLE)")
            }
            // §B — ACK the applied mode back to the app on this cadence so Live Insight can show İsteniyor/Uygulandı
            // divergence honestly. We re-ack when EITHER the applied idle-equivalent state changed OR the desired
            // generation advanced (so even a desired churn that lands on the same applied state still re-stamps the
            // ack to the LATEST generation — otherwise `appliedIsCurrent` would wrongly report "pending" forever). We
            // stamp the DESIRED generation we actually observed so a stale ack can never read as current.
            let liveDesiredGen = GuardianSessionModeBridgeV1.desiredGeneration(suite: heartbeatSuite)
            let ackedGen = GuardianSessionModeBridgeV1.readAppliedAck(suite: heartbeatSuite)?.ackedGeneration
            if lastAckedAppliedIdle != analysisPaused || ackedGen != liveDesiredGen {
                lastAckedAppliedIdle = analysisPaused
                GuardianSessionModeBridgeV1.writeAppliedAck(analysisPaused ? .idle : .active,
                                                            ackedGeneration: liveDesiredGen,
                                                            nowEpoch: Date().timeIntervalSince1970, suite: heartbeatSuite)
            }
            _ = wasPaused
        }

        // §5.2 — the capability probe runs ONLY under the evidence gate (structurally off in release). It changes no
        // behaviour; it just measures whether the documented ReplayKit app-info attachment is present/updates so a
        // device run can later verify auto-idle. Verdict defaults to FEATURE_UNAVAILABLE off-device.
        if evidenceBuild {
            capabilityProbe.probe(sampleBuffer)
            // §F — feed the V2 transition-correlation probe from the SAME documented attachment the V1 probe reads.
            // We extract the raw application-info value (never retained/logged) and hand it to V2's session-keyed
            // digester; absence is recorded honestly so an intermittently-present key is scored correctly.
            let s = GuardianBroadcastCapabilityProbeV1.sample(from: sampleBuffer)
            if s.hadApplicationInfoKey {
                // The raw value is app-private: V2 digests it immediately with the per-session key and never keeps it.
                // We pass the V1 digest string form as the opaque identity token (stable within session, no raw id).
                // §F — `assertedStepIndex` is the OPERATOR'S scripted-step assertion; it is NIL in the live extension
                // (there is no operator schedule input at runtime). A nil assertion means FREE-RUN: the probe counts
                // presence + transitions but can NEVER claim scripted temporal agreement — so without a device
                // experiment the verdict honestly stays FEATURE_UNAVAILABLE / PRESENT_* and auto-idle stays off.
                capabilityProbeV2.observe(rawIdentity: String(s.applicationInfoDigest), source: .sampleAttachment,
                                          assertedStepIndex: probeAssertedStepIndex)
            } else {
                capabilityProbeV2.observeAbsent(source: .sampleAttachment)
            }
            if tsMs - lastProbeLogMs >= Self.probeLogMinIntervalMs {
                lastProbeLogMs = tsMs
                emit("CAPABILITY_PROBE \(capabilityProbe.summary)")
                emit("CAPABILITY_PROBE_V2 \(capabilityProbeV2.summary)")
            }
        }

        // §5.1/§5.5/§A — ANALYSIS-PAUSED SHORT-CIRCUIT. The broadcast is still LIVE (we keep the cheap heartbeat so
        // liveness/freshness stay truthful), but the heavy path — shot-brain, Tier-0 grouping, OCR, Tier-1, shield
        // commit — is SKIPPED whenever analysis is paused: EITHER the user chose IDLE (§5) OR Guardian is OFF (§A,
        // `guardian.enabled`). Cost drops to the per-interval heartbeat; we never report it as "zero" (the heartbeat
        // still runs). No decision is produced while paused — so a disabled Guardian genuinely stops analysis (the
        // OS feed, owned by iOS, physically continues; we never claim we stopped it).
        if analysisPaused {
            frameDurationsNs.append(DispatchTime.now().uptimeNanoseconds &- frameStart)
            if frameDurationsNs.count > 4000 { frameDurationsNs.removeFirst() }
            sp.endInterval("frame", spState)
            return
        }

        // Ultra-cheap MULTI-REGION signature + bounded 8×8 row/col projections sampled in place — no decode, no copy,
        // raw buffer not retained. Together they form the SegmentFrameV4 feature (projections drive the swipe cue).
        guard let frame = Self.segmentFrame(px) else { sp.endInterval("frame", spState); return }
        let bState = sp.beginInterval("segment")
        let (ev, shotBoundary) = shotSegmenter.process(frame, timestampMs: tsMs)
        sp.endInterval("segment", bState)
        if ev.state == .transitionInProgress || ev.state == .newSegmentConfirmed { stats.contentChanges += 1 }

        // §5/§6 derived-only per-frame motion telemetry (evidence build). ONLY derived scalars. No raw media.
        if evidenceBuild {
            evFrame += 1
            emit("MOTION f=\(evFrame) ts=\(String(format: "%.0f", tsMs)) state=\(ev.state.rawValue) energy=\(String(format: "%.3f", ev.motionEnergy)) scale=\(String(format: "%.3f", ev.motionScale)) disc=\(String(format: "%.3f", ev.normalizedDiscontinuity)) repl=\(String(format: "%.2f", ev.replacementRatio)) postMs=\(String(format: "%.0f", ev.postPersistenceMs)) swipe=\(ev.swipeGate.rawValue) committed=\(ev.committedNew)")
        }

        // ONLY a committed SHOT boundary enters the brain (motion within a shot never commits).
        guard let boundary = shotBoundary else {
            // R4 §2B — STATIC-FRAME REVALIDATION (shot-independent). No shot committed this frame → this is the static
            // path the R3 revalidation never reached. On a ~1s gate, cheaply revalidate the standing decision using
            // ONLY the cheap motion signal already computed (no OCR / no Tier-1): identity is "stable" iff the scene is
            // not transitioning (no new-segment / transition-in-progress) AND we are below the cheap scene-change
            // threshold. A stable static screen EXTENDS the validity window (its own timestamp; original evidence epoch
            // untouched); a budget-exhausted window refuses honestly (the publish ages the decision out, no fake green).
            if tsMs - lastRevalidationTickMs >= Self.revalidationTickMinIntervalMs, decisionValidityWindow != nil {
                lastRevalidationTickMs = tsMs
                let sceneStable = ev.state != .transitionInProgress && ev.state != .newSegmentConfirmed
                    && ev.normalizedDiscontinuity < 0.5
                let identityStable = sceneStable && lastDecisionItemRevision >= 0
                    && lastObservedItemRevision == lastDecisionItemRevision
                let (newWindow, outcome) = GuardianDecisionRevalidationV1.revalidate(
                    decisionValidityWindow, identityStable: identityStable, currentPolicyRevision: policyRevision,
                    currentItemIdentityRevision: lastDecisionItemRevision, nowEpoch: Date().timeIntervalSince1970)
                if outcome == .extended { decisionValidityWindow = newWindow }
                selfEvalCounters.foldRevalidation(outcome)
                emit("STATIC_REVALIDATE outcome=\(outcome.rawValue) sceneStable=\(sceneStable) item=\(lastDecisionItemRevision) policyRev=\(policyRevision) revalCount=\(decisionValidityWindow?.revalidationCount ?? 0) validUntil=\(String(format: "%.3f", decisionValidityWindow?.validUntilEpoch ?? 0))")
                // Re-publish the heartbeat so the extended (or refused) validity reaches the app promptly on a static
                // screen (the heartbeat time-gate above may not have fired this exact frame). Cheap: one JSON encode.
                publishHeartbeat(nowEpoch: Date().timeIntervalSince1970)
            }
            frameDurationsNs.append(DispatchTime.now().uptimeNanoseconds &- frameStart)
            if frameDurationsNs.count > 4000 { frameDurationsNs.removeFirst() }   // bounded
            sp.endInterval("frame", spState); return
        }
        governor.noteShotEvent()

        // P009A-R1 §6/§8 — PROFILE-AWARE Tier-0 item grouping + deferred coalescing (content-anchored repair).
        let gState = sp.beginInterval("itemgroup")
        let decision = itemGrouper.process(boundary.newShot)
        let coalesced = coalescer.tryCoalesce(engine: itemGrouper, dnaInvalidator: { _ in })
        sp.endInterval("itemgroup", gState)
        if coalesced { emit("COALESCE deferredMerges=\(coalescer.deferredMerges) items=\(itemGrouper.confirmedOrProvisionalItemCount)") }

        // PHASE C §3: reclassified Tier-0 output — PROVISIONAL identity (CANDIDATE semantics, never authoritative).
        let provisional = ExtensionProvisionalIdentityV1.from(decision: decision, shotID: boundary.newShot.shotID,
                                                              profile: itemGrouper.profile,
                                                              groupingRevision: itemGrouper.policy.revision,
                                                              shotRevision: shotSegmenter.policyRevision)
        // §8: Tier-1 handoff record (bounded ring; derived scalars only; no raw media by construction).
        let thermalBucket: ThermalBucketV1 = {
            switch ProcessInfo.processInfo.thermalState {
            case .nominal: return .nominal; case .fair: return .fair; case .serious: return .serious
            case .critical: return .critical; @unknown default: return .serious }
        }()
        handoffBuffer.append(Tier1IdentityHandoffV1.from(identity: provisional, observationID: shotSegmenter.observationID,
                                                         transition: boundary.newShot.transitionIn,
                                                         channels: decision.channels, thermal: thermalBucket))

        // P009A-R2 §2 (audit B1) — MEASURED per-channel evidence at every SHOT TRANSITION. Derived scalars ONLY:
        // no raw frames/screenshots/video/audio/OCR text/captions/titles/app-private content. Evidence builds only.
        if evidenceBuild, let ch = decision.channels {
            emit("SHOTEV ts=\(String(format: "%.0f", tsMs)) shot=\(boundary.newShot.shotID.raw) in=\(boundary.newShot.transitionIn.rawValue) gate=\(boundary.newShot.swipeGate.rawValue) repl=\(String(format: "%.2f", boundary.newShot.replacementRatioIn)) item=\(decision.itemID.raw) state=\(decision.state.rawValue) prov=\(decision.provisional) S=\(String(format: "%.3f", decision.mergeScore)) N=\(String(format: "%.3f", decision.newScore)) theme=\(String(format: "%.3f", ch.themeDistance)) proj=\(String(format: "%.3f", ch.projectionCorrelation)) hist=\(String(format: "%.3f", ch.histogramDistance)) chrome=\(String(format: "%.3f", ch.chromeDistance)) regional=\(String(format: "%.3f", ch.regionalDistance)) gapMs=\(String(format: "%.0f", ch.gapSinceLastBoundaryMs)) prevDwellMs=\(String(format: "%.0f", ch.previousShotDwellMs)) itemMs=\(String(format: "%.0f", ch.elapsedItemMs)) strongNew=\(ch.strongNew) anchored=\(ch.anchored) coalesced=\(coalesced) fired=\(ch.firedEvidence.joined(separator: "+"))")
        }

        // §9/§26 one expensive understanding per ITEM. ORDER (P1 fix): OCR → TIER-1 verdict → RESOLVE identity →
        // GUARDIAN binds evidence to the RESOLVED identity. Tier-1 is no longer a post-hoc log line; its SAME/NEW/
        // UNKNOWN verdict now decides WHICH content id the shield pass runs against.
        var firstTrustworthyMs = 0.0
        var matchState = "REUSED_ITEM"
        var ocrStatus = BroadcastOCRStatus.skippedThrottle   // default: we did not run OCR this item
        var ocrLatencyMs = 0.0
        var ocrLong = 0
        var ocrText: String? = nil      // shared C3 OCR evidence — feeds Tier-1 fusion AND the resolved shield pass
        var ocrLangs: [String] = []

        // (1) C3 OCR — event-gated (Tier-0 opened a new item) + rate-limited/serial. A1 FIX: the result is
        // SOURCE-CORRELATED to the SHOT it was captured from (`ocrCaptureToken.shotID = boundary.newShot.shotID`),
        // NOT pre-stamped with a generation guess. Correlation by source lets same-frame OCR bind to an id minted
        // THIS frame while still rejecting OCR captured from an earlier shot/item.
        let thisShotID = boundary.newShot.shotID.raw
        var ocrCaptureToken: CaptureTokenV1? = nil
        if decision.openedNewItem {
            if ocrThrottle.shouldRun(nowMs: tsMs) {
                ocrThrottle.beginRun(nowMs: tsMs)
                let r = BroadcastOCRRunnerV1.recognize(px, fastMode: true)   // downscale<=720p + VNRecognizeTextRequest
                ocrThrottle.endRun()
                ocrStatus = r.status; ocrLatencyMs = r.latencyMs; ocrLong = r.downscaledLongSide
                ocrText = r.text                      // non-nil only when status==.ran (non-empty recognized text)
                ocrLangs = r.languages
                ocrCaptureToken = CaptureTokenV1(sessionID: sessionID, shotID: thisShotID, generation: identityResolver.liveGeneration)
            }
        }

        // (2) P010 TIER-1 item identity — committed-shot event gate (never per frame) + >=1s rate limit + serial +
        // <=512px downscale inside the component; an over-cadence burst is DROPPED (nil), never queued.
        let t1State = sp.beginInterval("tier1")
        let tier1Assessment = tier1.assess(pixelBuffer: px, ocrText: ocrText,
                                           tier0OpenedNewItem: decision.openedNewItem,
                                           tier0StrongNew: decision.channels?.strongNew ?? false,
                                           tier0ProjectionCorrelation: decision.channels?.projectionCorrelation,
                                           nowMs: tsMs)
        sp.endInterval("tier1", t1State)

        // (3) RESOLVE the identity the Guardian will bind to. Tier-1 NEW overrides a Tier-0 SAME; a strong
        // SAME-vs-NEW contradiction isolates into a fresh UNKNOWN identity that must be re-evaluated (never inherit
        // a safe/protective decision across content). Resolving advances the capture generation on any new id.
        let tier1ForResolve: (verdict: Tier1IdentityVerdictV1, confidence: Double)? =
            tier1Assessment.map { ($0.verdict, $0.confidence) }
        let resolved = identityResolver.resolve(
            tier0: Tier0IdentityProposalV1(itemID: decision.itemID.raw, itemRevision: decision.itemRevision.number,
                                           openedNewItem: decision.openedNewItem),
            tier1: tier1ForResolve,
            shotID: thisShotID)
        // R2 §A — the LATEST observed current item (independent of whether a decision is produced for it). When a new
        // item resolves but we do not (yet) produce a fresh decision, this advances past `lastDecisionItemRevision`,
        // and the heartbeat then reports current != decision → the app sees STALE_ITEM (no green carryover).
        lastObservedItemRevision = resolved.revision

        // A1 FIREWALL (SOURCE-CORRELATED): OCR is valid for the resolved identity iff it was captured from the SHOT
        // the identity is now bound to. Same-frame OCR for an id minted THIS frame CORRELATES (shotID matches) and
        // is KEPT — the previous generation-ordering firewall wrongly dropped it. OCR captured from an EARLIER shot
        // (a genuinely different item) is still rejected, so one item's text can never bind to another.
        if let tok = ocrCaptureToken, ocrText != nil, identityResolver.rejects(tok) {
            emit("STALE_EVIDENCE_DROP kind=ocr capShot=\(tok.shotID) boundShot=\(identityResolver.bindingShotID ?? 0) capGen=\(tok.generation.value) liveGen=\(resolved.generation.value) resolvedID=\(resolved.contentID)")
            ocrText = nil; ocrCaptureToken = nil
        }

        // A2 — Tier-1 NEW → EVIDENCE COMPLETION. Tier-0 can commit a new SHOT without opening a new ITEM (so the
        // OCR event-gate above never fired), yet Tier-1 may resolve this as a genuinely NEW identity. When that
        // happens and we have NO text evidence for the fresh id, attempt OCR ONCE here under the SAME throttle
        // budget (rate-limit + in-flight guard — new-identity events are rare, so this respects the cost law). The
        // result is source-correlated to THIS shot, so it can only ever bind to the identity just minted.
        if ocrText == nil, !resolved.mayReusePriorDecision, !decision.openedNewItem {
            if ocrThrottle.shouldRun(nowMs: tsMs) {
                ocrThrottle.beginRun(nowMs: tsMs)
                let r = BroadcastOCRRunnerV1.recognize(px, fastMode: true)
                ocrThrottle.endRun()
                ocrStatus = r.status; ocrLatencyMs = r.latencyMs; ocrLong = r.downscaledLongSide
                ocrText = r.text; ocrLangs = r.languages
                ocrCaptureToken = CaptureTokenV1(sessionID: sessionID, shotID: thisShotID, generation: identityResolver.liveGeneration)
                emit("TIER1_NEW_OCR resolvedID=\(resolved.contentID) status=\(r.status.rawValue) hasText=\(r.text != nil)")
            } else {
                emit("TIER1_NEW_OCR_SKIPPED resolvedID=\(resolved.contentID) reason=throttle")
            }
        }

        // (4) GUARDIAN evaluation against the RESOLVED identity. Runs whenever a fresh identity was minted (new /
        // contradiction / deferral-into-new) — i.e. whenever we may NOT reuse a prior decision. A pure continuation
        // keeps the prior decision context (no re-work). This is the no-safe-state-inheritance guarantee.
        // A1 — a live rule change forces a fresh evaluation of the CURRENT item even if the identity is unchanged
        // (the prior decision is stale under the new policy revision). The flag is consumed once here.
        // §5.5 — a wake from idle ALSO forces a fresh evaluation of the current item (old evidence is never reused).
        // R7 §1 — THERMAL-RECOVERY BOUNDED REEVALUATION: if THIS item was child-deferred under thermal and thermal has
        // now recovered (not serious/critical), force ONE fresh evaluation so the fail-closed deficit decision cannot
        // persist once the analysis can actually run. Bounded: the tracker is cleared on consumption (one reeval per
        // deferral episode), never a per-frame re-run.
        let thermalRecoveredForDeferredChild = thermalDeferredChildItemRevision >= 0
            && thermalDeferredChildItemRevision == resolved.revision
            && thermalBucket != .serious && thermalBucket != .critical
        if thermalRecoveredForDeferredChild {
            emit("THERMAL_RECOVERY_REEVAL item=\(resolved.revision) bucket=\(thermalBucket.rawValue)")
            thermalDeferredChildItemRevision = -1
        }
        let mustEvaluate = !resolved.mayReusePriorDecision || policyChangedForceReeval || idleEdgeForceReeval
            || thermalRecoveredForDeferredChild
        policyChangedForceReeval = false
        idleEdgeForceReeval = false
        if mustEvaluate {
            governor.noteItemGroup()
            stats.contentsAnalyzed += 1
            stats.heavyAnalysisRuns += 1
            let t0 = DispatchTime.now().uptimeNanoseconds
            // R8 §2/§3/§4 — analyze ONE bounded AUDIO window for THIS item BEFORE the shield pass, so a real
            // `.soundClass` rule can match the classifier labels in the SAME frozen evaluator (fusion in the existing
            // engine), and the world-model bridge can consume the audio-event evidence bound to this identity. The
            // §4 budget gate defers under thermal pressure / when the heavy path is saturated (audio yields to OCR).
            // `ocrSaturating` is true when OCR already ran a heavy recognition for this item (both must not saturate).
            let ocrSaturating = (ocrStatus == .ran)
            // R10 §1 — this SUBMITS the audio window ASYNC and RETURNS IMMEDIATELY (the video decision path NEVER waits
            // on SoundAnalysis). The current pass uses whatever audio evidence is resolved RIGHT NOW (PENDING for a
            // fresh in-flight window → contributes no sound events: no sound ≠ safe). The real result arrives later and
            // progressively re-adjudicates THIS item (§5) if the identity is still valid.
            analyzeAudioWindowForItem(resolved: resolved, thermal: thermalBucket, ocrSaturating: ocrSaturating, nowMs: tsMs)
            // Snapshot the current resolved audio evidence ONCE (under the lock — the async path may write it).
            audioStateLock.lock(); let currentAudioForItem = liveAudioForItem; audioStateLock.unlock()
            // The DISTINCT audio labels feed the shield envelope's `soundEvents` ONLY when a window actually ran with
            // events (senseRan); a deferred/absent/PENDING window contributes NOTHING (no sound ≠ safe — labels stay []).
            let audioSoundEvents = (currentAudioForItem?.senseRan == true) ? (currentAudioForItem?.distinctLabels ?? []) : []
            let env = CrossAppObservationBuilder.envelope(contentID: resolved.contentID, ocrText: ocrText, soundEvents: audioSoundEvents, languages: ocrLangs)
            // B3 — ReplayKit observes a 3rd-party app: we do NOT control that feed (constitution rule 18). So the
            // surface is UNCONTROLLED: a shield match becomes an iOS-supported WARNING, never a hide/skip claim.
            // `controlledSurface: false` keeps the frozen evaluator honest (its hide/skip actions never "execute").
            let outcome = evaluator.evaluate(.init(envelope: env, controlledSurface: false), index: index,
                                             exceptions: shieldExceptions)
            matchState = outcome.matchState.rawValue
            firstTrustworthyMs = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
            emit("OCR resolvedID=\(resolved.contentID) status=\(ocrStatus.rawValue) hasText=\(ocrText != nil) chars=\(ocrText?.count ?? 0) long=\(ocrLong) latMs=\(String(format: "%.1f", ocrLatencyMs)) match=\(matchState) rule=\(outcome.ruleID ?? "-") layer=\(outcome.layerDecision.rawValue) policyRev=\(policyRevision)")
            // A3/B3 — derive the lock-safe surface + REAL reason code for the fresh decision (same resolved id).
            // A real match is a match ONLY in the evaluator's own ShieldMatchState sense (never a non-determinable
            // state). Exception-allowed items are NOT a shield hit (the user allowed them).
            let evaluatorShieldHit = outcome.matchState.isMatch && outcome.layerDecision != .noShieldAction && !outcome.exceptionApplied

            // R8 §7 — LIVE PERSONAL ALIAS PASS. Runs ONCE per fresh item on the SAME resolved OCR text (no extra OCR),
            // ONLY when the user has `.entity` alias rules. PersonalAliasMatchV1 is WORD-BOUNDARY (TR+EN folded), so a
            // short alias ("Ali") never matches inside another word ("kalitesi"). A real DIRECT mention of the canonical
            // name OR a user-typed alias is a DIRECT_REFERENCE personal match (the ladder's actionable rung) — WARN-only
            // on this uncontrolled 3rd-party surface (rule 18). This is the user's AVOIDANCE PREFERENCE, never a harm
            // verdict about the referenced person. The provenance (WHICH alias fired + canonical-vs-alias) is emitted
            // so the user sees WHY. Only runs on the resolved OCR text bound to THIS item (no cross-item leakage).
            var aliasMatch: PersonalAliasMatchResultV1? = nil
            if ocrText?.isEmpty == false {
                for rule in shieldRules where rule.inputType == .entity && rule.enabled {
                    let ref = PersonalAliasReferenceV1(ruleID: rule.ruleID, canonicalName: rule.rawUserLabel,
                                                       aliases: rule.aliases, revoked: !rule.enabled)
                    let r = PersonalAliasMatchV1.match(reference: ref, in: ocrText)
                    if r.matched { aliasMatch = r; break }   // first actionable direct mention wins (deterministic)
                }
                if let m = aliasMatch {
                    emit("ALIAS_MATCH rule=\(m.ruleID) term=\(m.matchedTerm ?? "-") canonical=\(m.isCanonical) item=\(resolved.revision) policyRev=\(policyRevision) (DIRECT_REFERENCE; WARN-only; avoidance preference, not a harm verdict)")
                }
            }
            // The TEXT shield hit the surface treats as a personal match = the evaluator hit OR a real alias mention.
            let shieldHit = evaluatorShieldHit || (aliasMatch != nil)

            // R2 §B — LIVE PHOTO-SHIELD pass. Runs ONCE per fresh item (inside mustEvaluate — never per frame), ONLY
            // when the user has photo references AND we are not under thermal pressure (§F/§B6: the heavy visual work
            // is bounded per item and skipped under thermal serious/critical so it never slows the main Guardian on a
            // hot device). The pass reuses the SAME in-place luma the cheap path already reads (no second decode); the
            // whole-frame hint runs first and only escalates to the bounded center+content ROIs if it was ambiguous.
            // The result is stamped with THIS resolved identity revision + session + policy + shot, so a §B5 stale
            // carryover is impossible (a match for this item can never surface on the next). Precision-first (§B3):
            // only a near-exact HIGH/EXACT match drives a WARN surface; LOW/MEDIUM are recorded as evidence only.
            var photoActionable: PhotoShieldLiveMatchV1? = nil
            if !shieldFeatures.isEmpty {
                photoItemsConsidered += 1
                let hot = thermalBucket == .serious || thermalBucket == .critical
                if hot {
                    photoSkippedThermal += 1
                    emit("PHOTO_SHIELD_SKIP reason=thermal bucket=\(thermalBucket.rawValue) refs=\(shieldFeatures.count)")
                } else if let plane = PhotoShieldLumaMatcherV1.lumaPlane(from: px) {
                    let pState = sp.beginInterval("photoshield")
                    // ROI escalation is allowed only on a nominal thermal bucket (fair still runs whole-frame only,
                    // to keep the hot-ish path cheap). Newest-item-wins is guaranteed because this runs for the item
                    // just resolved on THIS frame; a later item re-enters this block with its own fresh identity.
                    let pass = PhotoShieldLumaMatcherV1.matchLuma(
                        plane.luma, width: plane.width, height: plane.height, features: shieldFeatures,
                        itemIdentityRevision: resolved.revision, policyRevision: policyRevision,
                        sessionID: sessionID, shotID: thisShotID, nowEpoch: Date().timeIntervalSince1970,
                        allowROIEscalation: thermalBucket == .nominal)
                    sp.endInterval("photoshield", pState)
                    photoSignaturesComputed += pass.signaturesComputed
                    photoROIsEvaluated += pass.roisEvaluated
                    // R3 §9 / R4 §2D — MEASURE-ONLY: fold this photo pass into the self-eval counters. A best match
                    // that is ANY-match but NOT actionable is a NON-ACTIONABLE VISUAL CANDIDATE (not a false negative —
                    // no independent label); a stale drop is counted via `discardedStale`. No behaviour change.
                    let staleDrop = pass.best.map { !($0.itemIdentityRevision == resolved.revision && $0.sessionID == sessionID) } ?? false
                    selfEvalCounters.foldPhotoPass(best: pass.best, legacyNeedsReauthor: pass.legacyNeedsReauthor,
                                                   signaturesComputed: pass.signaturesComputed,
                                                   reusedCachedSignature: false, discardedStale: staleDrop,
                                                   thermalSkipped: false)
                    if let best = pass.best {
                        // §B5 FIREWALL — the match must be for the identity we are about to surface (it always is here
                        // because we passed `resolved.revision`, but we assert it so a future refactor cannot leak a
                        // stale result). Only an ACTIONABLE (near-exact) match may escalate the surface.
                        let fresh = best.itemIdentityRevision == resolved.revision && best.sessionID == sessionID
                        if best.isActionable && fresh {
                            photoActionable = best
                            photoActionableMatches += 1
                        }
                        emit("PHOTO_SHIELD_MATCH rule=\(best.ruleID) state=\(best.state.rawValue) roi=\(best.roi.rawValue) aHam=\(best.aHashHamming.map(String.init) ?? "-") dHam=\(best.dHashHamming.map(String.init) ?? "-") actionable=\(best.isActionable) fresh=\(fresh) sigs=\(pass.signaturesComputed) rois=\(pass.roisEvaluated) item=\(resolved.revision) policyRev=\(policyRevision)")
                    }
                }
            }

            // R3 §3 — PERSONAL SEMANTIC RELATION LADDER. Classify what each personal match REALLY is today so the user
            // sees WHY (provenance). A word/phrase rule text hit = DIRECT_REFERENCE(text); a photo EXACT/HIGH =
            // DIRECT_REFERENCE(visual); a photo MEDIUM = VISUAL_SIMILARITY (NOT actionable). ONLY DIRECT_REFERENCE is
            // actionable in V1 — the ladder's `actionable` flag is asserted against the paths that already gate the
            // surface (text `shieldHit`, photo `isActionable`), so a MEDIUM photo / UNKNOWN can never action here.
            // R8 §7 — an ALIAS direct mention is a DIRECT_REFERENCE(text) via its own classifier (the evaluator's
            // matchState is noMatch for an alias-only hit, so classifyText would under-report it). Prefer the alias
            // classification when an alias fired; otherwise fall back to the evaluator's text relation.
            let textRelation = aliasMatch.map { PersonalRelationLadderV1.classifyAliasMatch($0) }
                ?? PersonalRelationLadderV1.classifyText(matchState: outcome.matchState,
                                                         isActionableShieldHit: shieldHit)
            let photoRelation = photoActionable.map { PersonalRelationLadderV1.classify($0) }
            if shieldHit { emit("RELATION_TEXT type=\(textRelation.relation.rawValue) actionable=\(textRelation.actionable) modality=\(textRelation.modalityRaw)") }
            if let pr = photoRelation { emit("RELATION_PHOTO type=\(pr.relation.rawValue) actionable=\(pr.actionable) modality=\(pr.modalityRaw)") }

            // R3 §1 — GENERAL CONTENT-CHARACTER CAUTION. The MAIN wellbeing intelligence: run the REAL OCTOPUS
            // language/OCR expert over the resolved OCR text and translate its honest lexicon markers into a general
            // caution. Context discipline: a marker is a RISK MARKER ("işaret"), NEVER a harm certainty. UNKNOWN
            // discipline: no text / unsupported language = NOT_ANALYZED (never "safe"). KEPT SEPARATE from the
            // personal shield — a general caution is a wellbeing signal, never conflated with a user avoidance match.
            // R4 §4 — CONTEXT-AWARE pass: run the R3 marker pass, then (only when a marker fired AND the language is
            // supported) infer the SPEAKER STANCE from linguistic structure (negation / quotation / role). The marker
            // is NEVER dropped; the stance only re-frames it (ADVOCATES keeps/raises; reporting/criticism/victim-
            // support softens to an examined-with-context note; UNKNOWN keeps the plain marker).
            // R7 §4 — REAL SINGLE-PASS. Run the FOUR frozen text experts ONCE per item HERE (before both the
            // general-character interpretation AND the world-model bridge), so the LanguageOCR expert is invoked
            // exactly once. The R6 duplicate was: GeneralContentCharacter.evaluateWithContext ran its own
            // LanguageOCRExpertV1 AND the bridge's runTextExperts ran it again. Now the SAME envelopes feed both.
            // Cheap bounded lexicon scans — safe even on the thermal-skip path (text-only; not the heavy WM build).
            var itemExpertCensus: [String: Int] = [:]
            let sharedTextEvidence: [ExpertEvidenceV2] = (ocrText?.isEmpty == false)
                ? WorldModelEvidenceBridgeV1.runTextExperts(
                    ocrText: ocrText, ocrLanguage: ocrLangs.first, contentID: resolved.contentID,
                    itemIdentityRevision: resolved.revision,
                    identityConfirmed: resolved.relation == .newConfirmed || resolved.relation == .continuation,
                    generation: resolved.generation.value, shotID: thisShotID)
                : []
            // Census the real invocations BY DOMAIN (one per returned text-expert envelope — runTextExperts runs each
            // once; an abstaining expert still counts as one invocation of its domain). GeneralContentCharacter below
            // REUSES the LanguageOCR envelope — it does NOT add a second LANGUAGE_OCR invocation (§4 single-pass).
            for e in sharedTextEvidence { itemExpertCensus[e.domain.rawValue, default: 0] += 1 }
            let sharedLanguageEvidence = sharedTextEvidence.first { $0.domain == .languageOCR }
            let generalCharacter = GeneralContentCharacterV1.evaluateWithContext(
                ocrText: ocrText, detectedLanguage: ocrLangs.first,
                itemIdentityRevision: resolved.revision, policyRevision: policyRevision,
                nowEpoch: Date().timeIntervalSince1970,
                precomputedLanguageEvidence: sharedLanguageEvidence)   // R7 §4 — reuse the shared LanguageOCR run
            emit("GENERAL_CHARACTER outcome=\(generalCharacter.outcome.rawValue) primary=\(generalCharacter.primaryCategory?.rawValue ?? "-") markers=\(generalCharacter.markers.map { "\($0.category.rawValue):\($0.hits)" }.joined(separator: "+")) stance=\(generalCharacter.contextStance?.rawValue ?? "-") effect=\(generalCharacter.contextEffect?.rawValue ?? "-") ctxEv=\(generalCharacter.contextEvidence.joined(separator: "|")) lang=\(generalCharacter.languageRaw) noisy=\(generalCharacter.ocrNoisy) model=\(generalCharacter.expertModelVersion) item=\(resolved.revision) policyRev=\(policyRevision)")
            // R7 §4 — fold THIS item's expert-invocation census: each text expert ran exactly once (the shared run);
            // GeneralContentCharacter reused the LanguageOCR envelope (no second invocation). A single-pass violation
            // would show a count > 1 for a text expert here → `duplicateTextExpertItems` increments (expected 0).
            selfEvalCounters.foldItemExpertCensus(itemExpertCensus)
            emit("EXPERT_CENSUS item=\(resolved.revision) \(itemExpertCensus.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: " "))")

            // R4 §2A — FOUR-WAY SEPARATION (the NOT_ANALYZED false-positive fallback fix). A PERSONAL avoidance match
            // still takes precedence (ADR-0007). Below it the general-character outcome maps to DISTINCT surfaces so a
            // NOT_ANALYZED can NEVER fall through to a benign GUARDIAN_ON:
            //   • NOT_ANALYZED (text present but unsupported language / unreliable) → UNKNOWN / coverage-limited gray.
            //   • EXAMINED_NO_MARKER → GUARDIAN_ON with the scope-limited "incelenen metin kapsamında işaret yok" copy.
            //   • CAUTION (marker, plain or ADVOCACY-backed context)              → the caution surface.
            //   • CONTEXT_ASSESSED + SOFTEN                                       → GUARDIAN_ON with the calm context note.
            let anyShieldHit = shieldHit || (photoActionable != nil)
            if anyShieldHit {
                lastResolvedSurfaceRaw = "SHIELD_MATCH"
                lastReasonCodeRaw = shieldHit ? GuardianReasonCodeV1.personalShieldWarnOnly.rawValue
                                              : GuardianReasonCodeV1.personalPhotoMatchWarnOnly.rawValue
            } else if generalCharacter.isCaution {
                // A marker fired and it remains a caution (plain R3 marker, OR CONTEXT_ASSESSED with an ADVOCACY
                // stance that KEEPS/RAISES the caution). Distinct reason codes so the user sees whether context was read.
                lastResolvedSurfaceRaw = "CAUTION"
                lastReasonCodeRaw = (generalCharacter.outcome == .contextAssessed)
                    ? GuardianReasonCodeV1.generalContentContextCaution.rawValue   // ADVOCACY: context-backed caution
                    : GuardianReasonCodeV1.generalContentCaution.rawValue          // R3 plain marker (incl. UNKNOWN stance)
            } else if generalCharacter.isContextSoftened {
                // R4 §4 — a marker was present but the inferred stance (reporting / criticism / victim-support) softened
                // it: examined WITH context. The marker is NOT dropped; the surface is calmer (GUARDIAN_ON) with a
                // DISTINCT reason that explicitly is NOT a "safe" claim. This is the first real false-alarm reduction.
                lastResolvedSurfaceRaw = "GUARDIAN_ON"
                lastReasonCodeRaw = GuardianReasonCodeV1.generalContentContextSoftened.rawValue
            } else if generalCharacter.outcome == .notAnalyzed, ocrText != nil {
                // R4 §2A THE FIX — OCR text WAS present but the general brain could not analyze it (unsupported
                // language / unreliable evidence). This must NOT become a benign GUARDIAN_ON. It is a COVERAGE-LIMITED
                // UNKNOWN (gray): "incelenemedi… bu 'güvenli' anlamına gelmez" (`generalContentNotAnalyzed`).
                lastResolvedSurfaceRaw = "UNKNOWN"
                lastReasonCodeRaw = GuardianReasonCodeV1.generalContentNotAnalyzed.rawValue
            } else if generalCharacter.outcome == .examinedNoMarker {
                // Text examined, no personal match and no supported general marker → honest SCOPE-LIMITED benign (only
                // the examined text's scope; NOT a whole-content "safe" claim).
                lastResolvedSurfaceRaw = "GUARDIAN_ON"
                lastReasonCodeRaw = GuardianReasonCodeV1.generalContentExaminedNoMarker.rawValue
            } else if ocrText != nil {
                // Text present, personal pass examined it, no general marker and (defensively) not the cases above →
                // honest benign (NOT "safe"). This retains the R3 text-benign copy for the residual path.
                lastResolvedSurfaceRaw = "GUARDIAN_ON"
                lastReasonCodeRaw = GuardianReasonCodeV1.textEvidenceBenign.rawValue
            } else {
                // Fresh identity but NO text evidence at all → honest: UNKNOWN surface, not a "safe" claim.
                lastResolvedSurfaceRaw = "UNKNOWN"
                lastReasonCodeRaw = (resolved.relation == .newContradiction || resolved.tier1Verdict == nil)
                    ? GuardianReasonCodeV1.newIdentityUnconfirmed.rawValue
                    : GuardianReasonCodeV1.textEvidenceUnavailable.rawValue
            }

            // R5 §5 — EMOTIONAL REGISTER: a SEPARATE dimension from stance (structural; TR/EN; abstention-first).
            // Runs per ITEM (inside mustEvaluate) on text the pass already has — never per frame, no extra OCR.
            let register = EmotionalRegisterAdapterV1.assessRegister(
                text: ocrText, language: ocrLangs.first,
                itemIdentityRevision: resolved.revision, policyRevision: policyRevision,
                nowEpoch: Date().timeIntervalSince1970)
            emit("EMOTIONAL_REGISTER register=\(register.register.rawValue) support=\(register.support.rawValue) ev=\(register.evidence.joined(separator: "|")) lang=\(register.languageRaw) item=\(resolved.revision) policyRev=\(policyRevision)")

            // R6 §4 + addendum — TARGETED PRESSURE / COVERT MANIPULATION heuristic. Runs per ITEM on the SAME OCR
            // text (no extra OCR). Structural TARGET/ACT/MECHANISM; abstains honestly (criticism / 3rd-party / quoted
            // / humor / unsupported → no own-voice pressure). Fed into the world-model bridge + the adjudicator.
            let targeted = TargetedPressureHeuristicV1.assess(
                text: ocrText, language: ocrLangs.first,
                itemIdentityRevision: resolved.revision, policyRevision: policyRevision,
                nowEpoch: Date().timeIntervalSince1970)
            emit("TARGETED_PRESSURE target=\(targeted.target.rawValue) act=\(targeted.act.rawValue) mech=\(targeted.mechanism.rawValue) support=\(targeted.support.rawValue) quoted=\(targeted.quotedNotOwnVoice) label=\(TargetedPressureHeuristicV1.evidenceLabel(targeted) ?? "-") ev=\(targeted.evidence.joined(separator: "|")) item=\(resolved.revision)")

            // R6 §1 — WORLD MODEL FOR ALL PROFILES. The bridge + SafetyPolicyEngine now run for EVERY profile (adult
            // included) on the per-item path; the ChildAgePolicyEngine overlay runs ONLY for child/teen. R6 §1.1 —
            // SINGLE EVIDENCE: the four frozen text experts run ONCE here and the SHARED envelopes feed BOTH this
            // bridge AND (conceptually) the general-character interpretation, so no text signal double-counts. R6
            // §1.2 — the R4 stance verdict is carried in as a CANONICAL verdict (not re-derived from OCR).
            // RESOURCE DISCIPLINE (§1): under thermal serious/critical we SKIP the world model for this item and mark
            // its coverage UNKNOWN/PARTIAL — never presented as "ran" (honest budget skip, no fabricated coverage).
            var childOutcome: ChildAgeOutcomeV1? = nil
            // R7 §3 — the world-model SafetyPolicy summary that flows into the GENERAL surface for EVERY profile
            // (adult included), through the adjudicator. nil whenever the world model did not run (thermal skip).
            var worldModelSafetyForSurface: GuardianFamilySurfaceAdjudicatorV1.WorldModelSafetyInputV1? = nil
            let wmThermalSkip = thermalBucket == .serious || thermalBucket == .critical
            // R7 §1 — CHILD-SAFETY ANALYSIS DEFICIT. When the world-model analysis is SKIPPED (thermal here; any
            // resource gate in general) AND an active CHILD/TEEN profile is relied upon for age-suitability, the
            // child analysis did NOT run → the adjudicator must FAIL CLOSED to an ANALYSIS-DEFICIT state, never a
            // benign/AGE_ALIGNED surface. Computed independent of childOutcome (which stays nil on this path).
            let activeNonAdultProfile = (familyProfile?.mode ?? .adult) != .adult
            let childAnalysisDeficit = wmThermalSkip && activeNonAdultProfile
            if wmThermalSkip {
                emit("WORLD_MODEL_SKIP reason=thermal bucket=\(thermalBucket.rawValue) coverage=UNKNOWN_PARTIAL item=\(resolved.revision) childAnalysisDeficit=\(childAnalysisDeficit) nonAdult=\(activeNonAdultProfile)")
                // R7 §1 — remember this item is child-deferred so a later thermal recovery forces a bounded reeval.
                if childAnalysisDeficit { thermalDeferredChildItemRevision = resolved.revision }
                selfEvalCounters.foldR5(registerWasSupportedUnknown: false, familyReadDegraded: false,
                                        bridgeUnavailableCount: 0)
            } else {
                // R7 §4 — REUSE the shared text-expert run computed above (do NOT re-run runTextExperts here). This
                // is the duplicate the R6 single-pass claim missed; the bridge consumes the SAME envelopes via
                // precomputedTextEvidence so each text expert is invoked exactly once per item.
                let bridged = WorldModelEvidenceBridgeV1.build(WorldModelBridgeInputV1(
                    sessionID: sessionID, contentID: resolved.contentID,
                    itemIdentityRevision: resolved.revision,
                    identityConfirmed: resolved.relation == .newConfirmed || resolved.relation == .continuation,
                    generation: resolved.generation.value, shotID: thisShotID,
                    observationStartMs: tsMs, observationEndMs: tsMs,
                    ocrText: ocrText, ocrLanguage: ocrLangs.first,
                    policyRevision: policyRevision, familyProfileRevision: familyRevision,
                    photoShieldActionableMatch: photoActionable != nil,
                    emotionalRegister: register,
                    contextStance: generalCharacter.contextStance.map { _ in
                        ContextEvidenceVerdictV1(stance: generalCharacter.contextStance!,
                                                 support: .supported,
                                                 effect: generalCharacter.contextEffect ?? .keepPlain,
                                                 evidence: generalCharacter.contextEvidence,
                                                 languageRaw: generalCharacter.languageRaw,
                                                 itemIdentityRevision: resolved.revision,
                                                 policyRevision: policyRevision,
                                                 eventEpoch: Date().timeIntervalSince1970,
                                                 adapterVersion: ContextEvidenceAdapterV1.version) },
                    targetedPressure: targeted,
                    liveAudioEvidence: currentAudioForItem,   // R8 §2/§3 + R10 §1 — resolved audio (PENDING contributes none)
                    precomputedTextEvidence: sharedTextEvidence.isEmpty ? nil : sharedTextEvidence))
                emit("WORLD_MODEL_BRIDGE item=\(resolved.revision) evidence=\(bridged.evidenceCount) unavailable=\(bridged.unavailableModalities.joined(separator: "+")) knowledge=\(bridged.worldModel.knowledgeState.rawValue) identity=\(bridged.worldModel.identityStatus) maxRisk=\(String(format: "%.2f", bridged.worldModel.maxRiskSeen)) latMs=\(String(format: "%.2f", bridged.latencyMs)) profile=\(familyProfile?.mode.rawValue ?? "ADULT") dedup=\(!sharedTextEvidence.isEmpty) audio=\(liveAudioForItem?.availability.rawValue ?? "NONE")")
                // R7 §3 — carry the FROZEN SafetyPolicy's SUPPORTED summary into the GENERAL surface for EVERY profile
                // (not only the child overlay below). The adjudicator caps heuristic-only support at a CAUTION "işaret".
                worldModelSafetyForSurface = GuardianFamilySurfaceAdjudicatorV1.WorldModelSafetyInputV1.from(bridged.safety)
                emit("WORLD_MODEL_SAFETY_SURFACE item=\(resolved.revision) caution=\(bridged.safety.cautionSupported) strong=\(bridged.safety.strongProtectionSupported) unavailDims=\(bridged.safety.unavailableDimensions.count)")
                // R5 §3 — CHILD/TEEN OVERLAY ONLY for a relevant family profile (adult = general wellbeing only).
                if let fam = familyProfile, fam.mode != .adult {
                    let childDecision = ChildAgePolicyEngineV1.evaluate(
                        profile: fam.guardianEnteredProfile, safety: bridged.safety,
                        worldModel: bridged.worldModel, parentPreference: fam.parentPreferencePolicy)
                    childOutcome = childDecision.outcome
                    emit("CHILD_POLICY outcome=\(childDecision.outcome.rawValue) source=\(childDecision.sourceClass.rawValue) jurisdictionSupported=\(childDecision.jurisdictionSupported) registry=\(childDecision.registryVersion) reasons=\(childDecision.reasons.map { String(describing: $0.code) }.joined(separator: "+")) mode=\(fam.mode.rawValue) familyRev=\(familyRevision)")
                }
                // R5 §10 — measure-only: the bridge's honest coverage-gap magnitude for this item.
                selfEvalCounters.foldR5(registerWasSupportedUnknown: false, familyReadDegraded: false,
                                        bridgeUnavailableCount: bridged.unavailableModalities.count)
            }
            // R5 §10 — measure-only: register abstention on a SUPPORTED language is a coverage signal (never an error claim).
            selfEvalCounters.foldR5(registerWasSupportedUnknown: register.support == .supported && register.register == .unknown && ocrText != nil,
                                    familyReadDegraded: false, bridgeUnavailableCount: 0)

            // R5/R6 — ONE pure adjudication applies the canonical precedence: a pressure register (or a targeted
            // structural pressure) is a reasoned caution that BLOCKS context softening even without a lexicon marker
            // (§3.1); the CHILD floor outranks personal softening and preserves the displaced evidence (§3.2 dual-
            // evidence); a degraded/invalid family read fails closed. Pinned by GuardianMediaTests (laws in the pure type).
            let adjudicated = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
                baseSurfaceRaw: lastResolvedSurfaceRaw, baseReasonRaw: lastReasonCodeRaw,
                character: generalCharacter, register: register, childOutcome: childOutcome,
                familyDegradedNonAdult: familyDegradedNonAdult, targetedPressure: targeted,
                worldModelSafety: worldModelSafetyForSurface, childAnalysisDeficit: childAnalysisDeficit)
            if adjudicated.surfaceRaw != lastResolvedSurfaceRaw || adjudicated.reasonCodeRaw != lastReasonCodeRaw {
                emit("SURFACE_ADJUDICATED from=\(lastResolvedSurfaceRaw)/\(lastReasonCodeRaw) to=\(adjudicated.surfaceRaw)/\(adjudicated.reasonCodeRaw) adj=\(adjudicated.adjustments.joined(separator: "+"))")
            }
            lastResolvedSurfaceRaw = adjudicated.surfaceRaw
            lastReasonCodeRaw = adjudicated.reasonCodeRaw

            // R2 §A — stamp the DECISION'S OWN independent facts: the real time it was produced + the item identity it
            // was bound to. A later heartbeat re-publishing this same surface carries THIS epoch (not the publish
            // time), so the app ages the DECISION out on its own TTL — a fresh heartbeat cannot refresh an old decision.
            lastDecisionEpoch = Date().timeIntervalSince1970
            lastDecisionItemRevision = resolved.revision
            // R3 §2 — a FRESH decision opens a validity window keyed to THIS item identity + policy revision. The
            // static-content path below can cheaply EXTEND it; a new item / policy change invalidates it immediately.
            decisionValidityWindow = GuardianDecisionRevalidationV1.open(
                decisionItemIdentityRevision: resolved.revision, decisionPolicyRevision: policyRevision,
                evidenceEpoch: lastDecisionEpoch)
            // R4 §2B — a FRESH decision restarts the static-revalidation budget: the next static tick starts counting
            // from zero against THIS decision (so the bounded cap governs each decision independently).
            lastRevalidationTickMs = -.greatestFiniteMagnitude
            // R10 §1/§5 — CAPTURE the progressive RE-ADJUDICATION SNAPSHOT for THIS item, so a LATE async audio result
            // (still valid for this item) can re-run the SAME bridge/adjudicator with the new `.audioEvent` evidence —
            // a progressive same-item update, not a second engine. Only captured when the world model actually RAN
            // (not thermal-skipped); on a thermal skip there is no bridge context to re-run and audio stays deferred.
            if !wmThermalSkip {
                let snapTicket = AudioApplyTicketV1(sessionID: sessionID, itemIdentityRevision: resolved.revision,
                                                    generation: resolved.generation.value, policyRevision: policyRevision,
                                                    familyRevision: familyRevision, requestID: 0)
                audioStateLock.lock()
                audioReadjudicationSnapshot = AudioReadjudicationSnapshotV1(
                    ticket: snapTicket, contentID: resolved.contentID, itemRevision: resolved.revision,
                    identityConfirmed: resolved.relation == .newConfirmed || resolved.relation == .continuation,
                    generation: resolved.generation.value, shotID: thisShotID, observationMs: tsMs,
                    ocrText: ocrText, ocrLanguage: ocrLangs.first, photoActionable: photoActionable != nil,
                    register: register, contextStance: generalCharacter.contextStance.map {
                        ContextEvidenceVerdictV1(stance: $0, support: .supported,
                                                 effect: generalCharacter.contextEffect ?? .keepPlain,
                                                 evidence: generalCharacter.contextEvidence,
                                                 languageRaw: generalCharacter.languageRaw,
                                                 itemIdentityRevision: resolved.revision, policyRevision: policyRevision,
                                                 eventEpoch: Date().timeIntervalSince1970,
                                                 adapterVersion: ContextEvidenceAdapterV1.version) },
                    targeted: targeted,
                    sharedTextEvidence: sharedTextEvidence.isEmpty ? nil : sharedTextEvidence,
                    baseSurfaceRaw: lastResolvedSurfaceRaw, baseReasonRaw: lastReasonCodeRaw,
                    generalCharacter: generalCharacter,
                    familyMode: familyProfile?.mode ?? .adult,
                    familyGuardianProfile: familyProfile?.guardianEnteredProfile,
                    parentPreference: familyProfile?.parentPreferencePolicy,
                    familyDegradedNonAdult: familyDegradedNonAdult,
                    familyRevision: familyRevision, policyRevision: policyRevision)
                audioStateLock.unlock()
            }
            // C-lane TIMELINE — fresh identity ⇒ real content-lifecycle events (dedup-collapsed; never fabricated).
            // Each uses the SAME resolved identity revision so an event can never drift to another item.
            recordContentEvents(resolved: resolved, shieldHit: shieldHit, hasText: ocrText != nil,
                                shieldOutcome: shieldHit ? outcome : nil,
                                photoMatch: photoActionable,
                                generalCaution: (!anyShieldHit && generalCharacter.isCaution) ? generalCharacter : nil,
                                textRelation: shieldHit ? textRelation : nil,
                                photoRelation: photoRelation,
                                nowEpoch: Date().timeIntervalSince1970)
        } else {
            stats.cacheReuse += 1
            governor.noteCacheHit()
            // R3 §2 — STATIC-CONTENT REVALIDATION. We are reusing a prior decision for the SAME resolved item (no new
            // decision produced). This is the static case where the evidence TTL would otherwise expire under the user
            // while they are still on the same content. A CHEAP revalidation (identity stable iff we may reuse the
            // prior decision AND the item revision is unchanged; policy unchanged) EXTENDS the validity window with its
            // OWN timestamp — the original evidence epoch is NOT falsified. Bounded: after a cap it refuses so a slow
            // drift forces a real re-analysis. Measure-only: the outcome is recorded; no surface is fabricated here.
            let identityStable = resolved.mayReusePriorDecision && resolved.revision == lastDecisionItemRevision
            let (newWindow, outcome) = GuardianDecisionRevalidationV1.revalidate(
                decisionValidityWindow, identityStable: identityStable, currentPolicyRevision: policyRevision,
                currentItemIdentityRevision: resolved.revision, nowEpoch: Date().timeIntervalSince1970)
            if outcome == .extended { decisionValidityWindow = newWindow }
            selfEvalCounters.foldRevalidation(outcome)
            emit("DECISION_REVALIDATE outcome=\(outcome.rawValue) item=\(resolved.revision) policyRev=\(policyRevision) revalCount=\(decisionValidityWindow?.revalidationCount ?? 0) validUntil=\(String(format: "%.3f", decisionValidityWindow?.validUntilEpoch ?? 0))")
        }

        // (5) Diagnostics — resolution + Tier-1 verdict (derived scalars only; never raw media/text).
        emit("RESOLVE resolvedID=\(resolved.contentID) rev=\(resolved.revision) gen=\(resolved.generation.value) relation=\(resolved.relation.rawValue) reuse=\(resolved.mayReusePriorDecision) t0item=\(resolved.tier0ItemID) t0rev=\(resolved.tier0ItemRevision) t1=\(resolved.tier1Verdict?.rawValue ?? "-") conf=\(String(format: "%.2f", resolved.tier1Confidence)) reason=\(resolved.reason)")
        if let t1 = tier1Assessment {
            emit("TIER1 item=\(decision.itemID.raw) verdict=\(t1.verdict.rawValue) conf=\(String(format: "%.2f", t1.confidence)) fpDist=\(t1.fpDistance.map { String(format: "%.3f", $0) } ?? "-") ocrSim=\(t1.ocrSimilarity.map { String(format: "%.2f", $0) } ?? "-") tie=\(t1.tieBreaker ?? "-") tier0New=\(decision.openedNewItem) disagree=\(t1.disagreesWithTier0) reason=\(t1.reason) latMs=\(String(format: "%.1f", t1.latencyMs)) long=\(t1.downscaledLongSide) policy=\(tier1.policy.revision)")
        }
        let memMB = Self.residentMemoryMB(); peakMemoryMB = max(peakMemoryMB, memMB)

        // Derived log schema P009A — NO raw pixels / OCR text / audio. SHOT + ITEM levels, never collapsed.
        let reasons = boundary.reasons.map { $0.rawValue }.joined(separator: "+")
        emit("SHOT id=\(boundary.newShot.shotID.raw) policy=\(boundary.policyRevision) in=\(boundary.newShot.transitionIn.rawValue) swipe=\(boundary.newShot.swipeGate.rawValue) repl=\(String(format: "%.2f", boundary.newShot.replacementRatioIn)) reasons=\(reasons)")
        emit("ITEM id=\(decision.itemID.raw) rev=\(decision.itemRevision.number) relation=\(provisional.relation.rawValue) families=\(provisional.independentFamilies) state=\(decision.state.rawValue) groupingPolicy=\(itemGrouper.policy.revision) openedNew=\(decision.openedNewItem) provisional=\(decision.provisional) merge=\(String(format: "%.2f", decision.mergeScore)) new=\(String(format: "%.2f", decision.newScore)) analysisInvoked=\(decision.openedNewItem) firstTrustworthyMs=\(String(format: "%.3f", firstTrustworthyMs)) memoryMB=\(String(format: "%.1f", memMB)) thermal=\(Self.thermalString()) lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled) score=UNKNOWN match=\(matchState)")
        publishHeartbeat(nowEpoch: Date().timeIntervalSince1970)
        sp.endInterval("frame", spState)
    }

    /// R8 §1/§4 — handle ONE application-audio CMSampleBuffer. Runs on the serial callback, so it does the MINIMUM:
    /// record the derived capture facts into the probe + append a minimal derived sample to the BOUNDED drop-oldest
    /// queue (bounded growth; freshest audio kept). No PCM analysis here. When analysis is paused (idle / Guardian off)
    /// we skip entirely (no audio work while paused). Mic buffers never reach this method (dropped at the callback).
    private func handleAudioAppBuffer(_ sampleBuffer: CMSampleBuffer) {
        if analysisPaused { return }   // §5/§A — no heavy OR audio work while the user paused / Guardian is off
        guard let facts = AudioCaptureProbeV1.facts(from: sampleBuffer) else {
            // No format description at all → an invalid buffer; record it honestly (dropped), never a clean claim.
            audioCaptureProbe.record(facts: AudioBufferFactsV1(sampleRate: nil, channelCount: nil, bitsPerChannel: nil,
                                                               isFloat: nil, durationSeconds: nil, presentationSeconds: nil),
                                     isMicTagged: false, normalizedRMS: nil)
            return
        }
        // §1.1 — these are APP buffers (the caller routed `.audioApp` here; `.audioMic` is dropped before this). We
        // pass isMicTagged=false explicitly; the probe's mic-refusal counter is defense in depth for a future refactor.
        audioCaptureProbe.record(facts: facts, isMicTagged: false, normalizedRMS: nil)
        // §4 — append a minimal derived sample to the bounded queue, stamped with the CURRENT capture generation +
        // observed item so a drain after an item change can discard stale audio (the firewall at the hand-off boundary).
        let gen = identityResolver.liveGeneration.value
        let rev = lastObservedItemRevision
        // R10 §2 — the ONE OWNERSHIP store owns the derived bounded hand-off (count/bytes/duration + high-water).
        audioHandoff.enqueue(LiveAudioQueuedSampleV1(facts: facts, generation: gen, itemIdentityRevision: rev))
        // R9 §2.1 — extract the MINIMAL short-lived PCM COPY on the callback (the copy owns its memory, so the
        // CMSampleBuffer can be released immediately — mandate §2.1: no access to invalid memory after the callback).
        // The HEAVY SoundAnalysis drive runs later on the off-callback worker; here we only make the owned copy.
        #if canImport(AVFoundation) && canImport(SoundAnalysis)
        if let (pcm, pts) = LiveAudioPCMExtractorV1.extractPCMCopy(from: sampleBuffer) {
            audioPCMLock.lock()
            audioPCMStore.append(QueuedPCMV1(pcm: pcm, ptsSeconds: pts, generation: gen, itemRevision: rev))
            // Bounded in lockstep with the queue capacity (drop oldest; the handoff store already counted the loss).
            while audioPCMStore.count > LiveAudioEvidenceAdapterV1.queueCapacity { audioPCMStore.removeFirst() }
            audioPCMLock.unlock()
        }
        #endif
        if evidenceBuild { let s = audioHandoff.snapshot; emit("AUDIO_BUFFER \(audioCaptureProbe.summary) queued=\(s.queuedSamples) dropped=\(s.droppedOldest) bytes=\(s.retainedBytes) dur=\(String(format: "%.2f", s.retainedDurationSeconds)) peakBytes=\(s.peakRetainedBytes) outstanding=\(s.outstandingWindows)") }
    }

    /// R8 §2/§3/§4 + R9 §1/§2/§2.3/§3 — attempt to analyze ONE bounded audio window for the resolved item, honoring the
    /// budget/thermal gate, driving the REAL SoundAnalysis streaming classifier through the explicit WINDOW-COMPLETION
    /// contract, and binding the result to {session, revision, generation, PTS span}. Produces `liveAudioForItem` with
    /// `availability == .available` ONLY when the classifier GENUINELY ran AND completed the window (a real
    /// SNClassificationResult, or a VERIFIED completed-no-event) — mandate §1: a buffer arriving is NOT analysis; an
    /// empty collector read immediately is NOT success. A deferral / absence / unmappable format / stale-generation /
    /// host-can't-infer set leaves it UNAVAILABLE (no sound ≠ safe). Runs inside `mustEvaluate` (per item, never per
    /// frame). The real drive runs on the off-callback audio worker; off-device no audioApp buffers arrive, so the
    /// honest result is `.noBuffers` / `DEVICE_UNVERIFIED` — the AVAILABLE path is device-only.
    private func analyzeAudioWindowForItem(resolved: ResolvedContentIdentityV1, thermal: ThermalBucketV1,
                                           ocrSaturating: Bool, nowMs: Double) {
        // Reset the per-item window budget on an item change.
        if audioWindowItemRevision != resolved.revision { audioWindowItemRevision = resolved.revision; audioWindowsRunThisItem = 0 }
        let binding = LiveAudioBindingV1(sessionID: sessionID, itemIdentityRevision: resolved.revision,
                                         generation: resolved.generation.value, ptsStartSeconds: nil, ptsEndSeconds: nil)
        // §4 — resource decision. Thermal serious/critical → DEFERRED_THERMAL; budget spent or OCR saturating → RESOURCE_DEFERRED.
        if let deferred = LiveAudioEvidenceAdapterV1.windowDecision(thermal: thermal,
                                                                    windowsAlreadyRunThisItem: audioWindowsRunThisItem,
                                                                    ocrSaturatingHeavyPath: ocrSaturating) {
            setLiveAudio(.unavailable(deferred, binding: binding, classifierVersion: GeneralAudioHeadV1.version), lifecycle: .resolved)
            audioWindowsDeferred += 1
            emit("AUDIO_WINDOW_DEFERRED reason=\(deferred.rawValue) item=\(resolved.revision) thermal=\(thermal.rawValue) ocrSat=\(ocrSaturating)")
            return
        }
        // §3 firewall — drain ONLY the samples still bound to the live generation+item; stale samples are discarded.
        let (live, discardedStale) = audioHandoff.drainLive(liveGeneration: resolved.generation.value, liveItemRevision: resolved.revision)
        audioStaleDiscarded += discardedStale
        if live.isEmpty {
            // No audioApp buffers for this item (the off-device state, or a genuine capture gap). Honest NO_BUFFERS —
            // the audio modality stays UNAVAILABLE for this item (no sound ≠ safe). Never a fabricated clean result.
            setLiveAudio(.unavailable(.noBuffers, binding: binding, classifierVersion: GeneralAudioHeadV1.version), lifecycle: .resolved)
            if discardedStale > 0 { emit("AUDIO_WINDOW_STALE_DISCARD item=\(resolved.revision) discarded=\(discardedStale)") }
            return
        }

        #if canImport(AVFoundation) && canImport(SoundAnalysis)
        // R10 §1 — the TRUE ASYNC PRODUCTION PATH. Collect the short-lived PCM copies still bound to THIS generation+
        // item (the firewall boundary — stale PCM from a prior item is dropped), SUBMIT the window to the off-callback
        // async worker, and RETURN IMMEDIATELY. The heavy video decision path does NOT wait for SoundAnalysis (mandate
        // §1: the kill of `audioWorkerQueue.sync`). While the window is in flight the coverage is PENDING (≠ AVAILABLE).
        audioPCMLock.lock()
        let livePCM = audioPCMStore.filter { $0.generation == resolved.generation.value && $0.itemRevision == resolved.revision }
        audioPCMStore.removeAll(keepingCapacity: true)   // one bounded window per item; the store is drained with the queue
        audioPCMLock.unlock()
        if livePCM.isEmpty {
            // We have derived facts (buffers arrived) but NO owned PCM copy (extraction failed / off-device format we
            // could not represent). Honest FORMAT_UNSUPPORTED — the sense could not actually run (never "clean").
            setLiveAudio(.unavailable(.formatUnsupported, binding: binding, classifierVersion: GeneralAudioHeadV1.version), lifecycle: .resolved)
            emit("AUDIO_WINDOW_NO_PCM item=\(resolved.revision) buffers=\(live.count) (derived facts only; no owned PCM → FORMAT_UNSUPPORTED)")
            return
        }
        // R10 §2 — may we spawn a window now? The ONE store bounds concurrent (outstanding) windows. At the cap we
        // defer HONESTLY (RESOURCE_DEFERRED) — a window is never spawned unbounded (mandate §2 "max inference windows").
        guard let requestID = audioHandoff.trySubmitWindow() else {
            setLiveAudio(.unavailable(.resourceDeferred, binding: binding, classifierVersion: GeneralAudioHeadV1.version), lifecycle: .resolved)
            audioWindowsDeferred += 1
            emit("AUDIO_WINDOW_DEFERRED reason=OUTSTANDING_WINDOW_CAP item=\(resolved.revision) cap=\(audioHandoff.maxOutstandingWindows)")
            return
        }
        // R10 §1 — snapshot the APPLY TICKET: the live identity the window is submitted under. The async completion
        // revalidates the (real, analyzed) result against the live state via AudioAsyncRevalidatorV1 before applying.
        let ticket = AudioApplyTicketV1(sessionID: sessionID, itemIdentityRevision: resolved.revision,
                                        generation: resolved.generation.value, policyRevision: policyRevision,
                                        familyRevision: familyRevision, requestID: requestID)
        // R10 §1 — coverage is now PENDING (analiz sürüyor) — a DISTINCT honest state, NOT available. The heavy path
        // that triggered this continues with whatever audio evidence is currently resolved (PENDING contributes no
        // sound events — no sound ≠ safe). The completion will progressively update this item if still valid.
        setLiveAudio(.unavailable(.frameworkUnavailable, binding: binding, classifierVersion: GeneralAudioHeadV1.version),
                     lifecycle: .pending, pendingItem: resolved.revision)
        let anchorPTS = livePCM.first?.ptsSeconds
        let pcmBuffers = livePCM.map { $0.pcm }
        emit("AUDIO_WINDOW_SUBMITTED_ASYNC item=\(resolved.revision) req=\(requestID) buffers=\(pcmBuffers.count) discardedStale=\(discardedStale) (video path NOT blocked; coverage PENDING)")
        // DISPATCH ASYNC — the window runs OFF the ReplayKit serial video callback; this method returns NOW.
        audioWorkerQueue.async { [weak self] in
            guard let self else { return }
            let windowResult = self.audioStreamSession.analyzeWindow(pcmBuffers, anchorPTSSeconds: anchorPTS,
                                                                     nowSeconds: Date().timeIntervalSince1970)
            self.applyAsyncAudioResult(windowResult, ticket: ticket)
            self.audioHandoff.completeWindow()   // §2 — release the outstanding-window slot + PCM (pcmBuffers freed here)
        }
        #else
        // SoundAnalysis/AVFoundation not importable on this SDK → the sense genuinely cannot run. Honest ladder
        // DEVICE_UNVERIFIED → UNAVAILABLE. We NEVER fabricate an `.available` on a host that cannot run the classifier.
        let state = LiveAudioAnalysisStateV1.deviceUnverified
        setLiveAudio(.unavailable(state.toAvailability(wasThermalDeferral: false), binding: binding,
                                  classifierVersion: GeneralAudioHeadV1.version), lifecycle: .resolved)
        emit("AUDIO_WINDOW_FRAMEWORK_UNAVAILABLE item=\(resolved.revision) buffers=\(live.count) ladder=\(state.rawValue) (SoundAnalysis absent on this SDK → UNAVAILABLE, never clean)")
        _ = discardedStale
        #endif
    }

    /// R10 §1/§2 — thread-safe write of the current item's resolved audio evidence + coverage lifecycle. Both the
    /// ReplayKit callback path and the async completion write here, so it is guarded by `audioStateLock`.
    private func setLiveAudio(_ evidence: LiveAudioWindowEvidenceV1, lifecycle: AudioCoverageLifecycleV1,
                              pendingItem: Int = -1) {
        audioStateLock.lock()
        liveAudioForItem = evidence
        audioCoverageLifecycle = lifecycle
        pendingAudioItemRevision = (lifecycle == .pending) ? pendingItem : -1
        audioStateLock.unlock()
    }

    #if canImport(AVFoundation) && canImport(SoundAnalysis)
    /// R10 §1 — the ASYNC COMPLETION handler. Runs on the audio worker AFTER a real SoundAnalysis window completed.
    /// It REVALIDATES the (real, analyzed) result against the CURRENT live identity (AudioAsyncRevalidatorV1): valid →
    /// apply the audio evidence + run a BOUNDED progressive re-adjudication of the SAME item through the existing
    /// bridge/adjudicator; invalid → DROP + count the reason (mandate §1: ASYNC CALLBACK ≠ SAFE TO APPLY). The live
    /// state is read under `audioStateLock` so the race against a concurrent item change on the video callback is safe.
    private func applyAsyncAudioResult(_ windowResult: LiveAudioStreamWindowResultV1, ticket: AudioApplyTicketV1) {
        // Build the LIVE state at completion time (read the engine's current identity/policy/consent — all are either
        // atomically-published scalars or read under the lock). captureActive=false once the broadcast finished.
        let live = AudioLiveStateV1(
            sessionID: sessionID, itemIdentityRevision: lastObservedItemRevision,
            generation: identityResolver.liveGeneration.value, policyRevision: policyRevision,
            familyRevision: familyRevision, guardianActive: !analysisPaused, captureActive: captureActive,
            latestRequestID: audioHandoff.latestRequestID)
        let decision = AudioAsyncRevalidatorV1.decide(ticket: ticket, live: live)
        guard decision.didApply else {
            audioDroppedLate += 1; audioLastDropReason = decision.rawValue
            // R10 §1 — if THIS item's coverage was PENDING for the dropped window, it is no longer in flight. We do NOT
            // overwrite a newer item's state (pendingAudioItemRevision only clears when it still matches the ticket).
            audioStateLock.lock()
            if pendingAudioItemRevision == ticket.itemIdentityRevision { pendingAudioItemRevision = -1; audioCoverageLifecycle = .resolved }
            audioStateLock.unlock()
            emit("AUDIO_ASYNC_DROPPED reason=\(decision.rawValue) ticketItem=\(ticket.itemIdentityRevision) ticketGen=\(ticket.generation) liveItem=\(live.itemIdentityRevision) liveGen=\(live.generation) guardian=\(live.guardianActive) capture=\(live.captureActive) (ASYNC CALLBACK ≠ SAFE TO APPLY)")
            return
        }
        // VALID — the user is still on the SAME item under the SAME policy/family/session with Guardian on. Build the
        // honest evidence (the ladder state is the single authority for `.available`) and progressively apply it.
        let bind = LiveAudioBindingV1(sessionID: ticket.sessionID, itemIdentityRevision: ticket.itemIdentityRevision,
                                      generation: ticket.generation,
                                      ptsStartSeconds: windowResult.ptsStartSeconds, ptsEndSeconds: windowResult.ptsEndSeconds)
        let evidence: LiveAudioWindowEvidenceV1
        if windowResult.ladderState.analysisGenuinelyRan {
            audioWindowsRunThisItem += 1; audioWindowsAnalyzed += 1
            evidence = LiveAudioWindowEvidenceV1(availability: .available, events: windowResult.events,
                                                 binding: bind, classifierVersion: GeneralAudioHeadV1.version)
            emit("AUDIO_WINDOW_RAN_ASYNC item=\(ticket.itemIdentityRevision) req=\(ticket.requestID) ladder=\(windowResult.ladderState.rawValue) buffers=\(windowResult.buffersSubmitted) results=\(windowResult.resultsReceived) events=\(windowResult.events.count) completed=\(windowResult.completionObserved) ptsStart=\(windowResult.ptsStartSeconds.map { String(format: "%.3f", $0) } ?? "UNBOUND")")
        } else {
            let avail = windowResult.ladderState.toAvailability(wasThermalDeferral: false)
            evidence = .unavailable(avail, binding: bind, classifierVersion: GeneralAudioHeadV1.version)
            emit("AUDIO_WINDOW_NOT_ANALYZED_ASYNC item=\(ticket.itemIdentityRevision) ladder=\(windowResult.ladderState.rawValue) availability=\(avail.rawValue) (classifier did not genuinely complete → UNAVAILABLE)")
        }
        setLiveAudio(evidence, lifecycle: .resolved)
        audioApplied += 1
        // R10 §1/§5 — PROGRESSIVE SAME-ITEM RE-ADJUDICATION through the EXISTING bridge/adjudicator (no second engine).
        progressivelyReadjudicateCurrentItemWithAudio(evidence: evidence, ticket: ticket)
    }

    /// R10 §5 — PROGRESSIVE AUDIOVISUAL WORLD MODEL. A LATE, VALID audio result for the CURRENT item re-runs the SAME
    /// frozen bridge (WorldModelEvidenceBridgeV1) + the SAME adjudicator (GuardianFamilySurfaceAdjudicatorV1) with the
    /// item's captured text/context snapshot PLUS the new `.audioEvent` evidence — NOT a second timeline/safety engine
    /// (mandate §5). If the canonical surface CHANGES, the new surface is stamped (decision epoch advances) and the
    /// change is recorded in the timeline WITH provenance (previous reason → new reason, changeReason=AUDIO_EVIDENCE),
    /// reusing the R4 progressive-understanding mechanism. Runs on the audio worker; re-reads the snapshot under the
    /// lock and re-checks the live identity (the ticket already passed the revalidator, but a change could race in).
    private func progressivelyReadjudicateCurrentItemWithAudio(evidence: LiveAudioWindowEvidenceV1, ticket: AudioApplyTicketV1) {
        audioStateLock.lock(); let snapOpt = audioReadjudicationSnapshot; audioStateLock.unlock()
        guard let snap = snapOpt, snap.itemRevision == ticket.itemIdentityRevision,
              snap.generation == ticket.generation else {
            emit("AUDIO_READJUDICATE_SKIP reason=NO_SNAPSHOT_FOR_ITEM item=\(ticket.itemIdentityRevision)")
            return
        }
        // Re-check the live identity has not advanced since the apply decision (race safety: the video callback may
        // have minted a new item between the revalidator's read and now).
        guard lastObservedItemRevision == ticket.itemIdentityRevision,
              identityResolver.liveGeneration.value == ticket.generation,
              policyRevision == ticket.policyRevision, familyRevision == ticket.familyRevision,
              !analysisPaused, captureActive else {
            emit("AUDIO_READJUDICATE_SKIP reason=IDENTITY_RACED item=\(ticket.itemIdentityRevision)")
            return
        }
        // Re-run the FROZEN bridge with the SAME text/context evidence + the NEW audio evidence (progressive update).
        let bridged = WorldModelEvidenceBridgeV1.build(WorldModelBridgeInputV1(
            sessionID: sessionID, contentID: snap.contentID, itemIdentityRevision: snap.itemRevision,
            identityConfirmed: snap.identityConfirmed, generation: snap.generation, shotID: snap.shotID,
            observationStartMs: snap.observationMs, observationEndMs: snap.observationMs,
            ocrText: snap.ocrText, ocrLanguage: snap.ocrLanguage,
            policyRevision: snap.policyRevision, familyProfileRevision: snap.familyRevision,
            photoShieldActionableMatch: snap.photoActionable, emotionalRegister: snap.register,
            contextStance: snap.contextStance, targetedPressure: snap.targeted,
            liveAudioEvidence: evidence,
            precomputedTextEvidence: snap.sharedTextEvidence))
        // Re-run the child overlay ONLY for a relevant family profile (adult = general wellbeing only) — same as the
        // heavy path. A nil guardian profile (adult) leaves childOutcome nil.
        var childOutcome: ChildAgeOutcomeV1? = nil
        if snap.familyMode != .adult, let gp = snap.familyGuardianProfile, let pp = snap.parentPreference {
            childOutcome = ChildAgePolicyEngineV1.evaluate(profile: gp, safety: bridged.safety,
                                                           worldModel: bridged.worldModel, parentPreference: pp).outcome
        }
        let wmSafety = GuardianFamilySurfaceAdjudicatorV1.WorldModelSafetyInputV1.from(bridged.safety)
        let adjudicated = GuardianFamilySurfaceAdjudicatorV1.adjudicate(
            baseSurfaceRaw: snap.baseSurfaceRaw, baseReasonRaw: snap.baseReasonRaw,
            character: snap.generalCharacter, register: snap.register, childOutcome: childOutcome,
            familyDegradedNonAdult: snap.familyDegradedNonAdult, targetedPressure: snap.targeted,
            worldModelSafety: wmSafety, childAnalysisDeficit: false)
        let prevReason = lastReasonCodeRaw
        let surfaceChanged = adjudicated.surfaceRaw != lastResolvedSurfaceRaw || adjudicated.reasonCodeRaw != lastReasonCodeRaw
        emit("AUDIO_READJUDICATE item=\(snap.itemRevision) audio=\(evidence.availability.rawValue) events=\(evidence.distinctLabels.count) from=\(lastResolvedSurfaceRaw)/\(prevReason) to=\(adjudicated.surfaceRaw)/\(adjudicated.reasonCodeRaw) changed=\(surfaceChanged) adj=\(adjudicated.adjustments.joined(separator: "+"))")
        guard surfaceChanged else { return }   // no change ⇒ no provenance event, no epoch move (honest: nothing new)
        // The canonical decision for THIS item CHANGED because real audio arrived. Stamp the new surface + advance the
        // decision epoch (a genuinely new decision), and record the change WITH provenance in the timeline (R4 reuse).
        lastResolvedSurfaceRaw = adjudicated.surfaceRaw
        lastReasonCodeRaw = adjudicated.reasonCodeRaw
        lastDecisionEpoch = Date().timeIntervalSince1970
        lastDecisionItemRevision = snap.itemRevision
        decisionValidityWindow = GuardianDecisionRevalidationV1.open(
            decisionItemIdentityRevision: snap.itemRevision, decisionPolicyRevision: policyRevision,
            evidenceEpoch: lastDecisionEpoch)
        // R4 §6 reuse — record the progressive change WITH provenance (previous reason → new reason, changeReason =
        // audio-evidence-arrived). This is the SAME mechanism the heavy path uses for context accumulation.
        let decisionStatus: GuardianTimelineStatusV1 = {
            switch adjudicated.surfaceRaw {
            case "SHIELD_MATCH": return .shieldMatch
            case "CAUTION": return .caution
            case "UNKNOWN", "OFF": return .unknown
            default: return .benign
            }
        }()
        timeline.recordSurfaceChange(status: decisionStatus, newReasonCodeRaw: adjudicated.reasonCodeRaw,
                                     previousReasonCodeRaw: prevReason,
                                     changeReasonRaw: "audio-evidence-arrived-same-item",
                                     identityRevision: snap.itemRevision, nowEpoch: lastDecisionEpoch)
        lastDecisionReasonForItem = adjudicated.reasonCodeRaw
        lastDecisionReasonItemRevision = snap.itemRevision
        publishHeartbeat(nowEpoch: Date().timeIntervalSince1970)
    }
    #endif

    /// C-lane — translate a fresh resolved identity + its decision into the REAL timeline events. Called ONLY when
    /// a fresh identity was minted (mustEvaluate), so every event here is a genuine engine moment, not decoration.
    /// Events are dedup-collapsed by the writer, so re-entrant identical states never spam the feed.
    private func recordContentEvents(resolved: ResolvedContentIdentityV1, shieldHit: Bool, hasText: Bool,
                                     shieldOutcome: PersonalShieldDecision? = nil,
                                     photoMatch: PhotoShieldLiveMatchV1? = nil,
                                     generalCaution: GeneralContentCharacterVerdictV1? = nil,
                                     textRelation: PersonalRelationClassificationV1? = nil,
                                     photoRelation: PersonalRelationClassificationV1? = nil,
                                     nowEpoch: Double) {
        let rev = resolved.revision
        // (a) Content lifecycle: a NEW_CONFIRMED item is new content; a CONTRADICTION/DEFERRED-into-new is the prior
        // decision being invalidated → CONTENT_CHANGED. A brand-new first item (prior rev -1) is NEW_CONTENT.
        if rev != lastTimelineIdentityRevision {
            switch resolved.relation {
            case .newConfirmed:
                timeline.record(category: lastTimelineIdentityRevision < 0 ? .newContent : .contentChanged,
                                status: lastTimelineIdentityRevision < 0 ? .active : .unknown,
                                reasonCodeRaw: GuardianReasonCodeV1.contentChangedReset.rawValue,
                                identityRevision: rev, nowEpoch: nowEpoch)
            case .newContradiction:
                timeline.record(category: .contentChanged, status: .unknown,
                                reasonCodeRaw: GuardianReasonCodeV1.newIdentityUnconfirmed.rawValue,
                                identityRevision: rev, nowEpoch: nowEpoch)
            case .unknownDeferred:
                timeline.record(category: .newContent, status: .unknown,
                                reasonCodeRaw: GuardianReasonCodeV1.newIdentityUnconfirmed.rawValue,
                                identityRevision: rev, nowEpoch: nowEpoch)
            case .continuation:
                break   // continuation never mints a fresh identity → no lifecycle event
            }
            // (b) Identity resolved by the Tier-1 fusion (honest: only when Tier-1 actually produced a verdict).
            if let v = resolved.tier1Verdict {
                timeline.record(category: .identityResolved, status: v == .unknown ? .unknown : .active,
                                reasonCodeRaw: (v == .unknown ? GuardianReasonCodeV1.visualEvidenceInsufficient
                                                             : GuardianReasonCodeV1.newIdentityUnconfirmed).rawValue,
                                identityRevision: rev, nowEpoch: nowEpoch)
            }
            lastTimelineIdentityRevision = rev
        }
        // (c) Evidence captured — only when real text evidence was obtained for THIS resolved id (mandate: scoped).
        if hasText {
            timeline.record(category: .evidenceCaptured, status: .benign,
                            reasonCodeRaw: GuardianReasonCodeV1.textEvidenceBenign.rawValue,
                            identityRevision: rev, nowEpoch: nowEpoch)
        }
        // (d) The Guardian DECISION. Status reflects the REAL surface: shield match / caution / benign / unknown.
        // A4 honesty: a non-match is BENIGN (evidence examined, no shield signal), NEVER a blanket "safe" claim.
        // R3 §1 — a general content-character CAUTION (no personal match) surfaces as a .caution decision status, so
        // the timeline shows the general wellbeing signal distinctly from a personal SHIELD_MATCH.
        let decisionStatus: GuardianTimelineStatusV1 = (shieldHit || photoMatch != nil) ? .shieldMatch
                                                        : (generalCaution != nil ? .caution
                                                           : (hasText ? .benign : .unknown))
        // R4 §6 — PROGRESSIVE UNDERSTANDING: if this is the SAME item as the last decision-reason we recorded and the
        // reason CHANGED (context accumulated while the user stayed), record the change WITH provenance (previous
        // reason + why). A prior item's reason is never used (we only carry it when `rev` matches), so evidence can
        // never leak across items. First evidence / a new item → a plain `.decision` record (no fabricated change).
        let priorReasonForThisItem = (rev == lastDecisionReasonItemRevision) ? lastDecisionReasonForItem : nil
        timeline.recordSurfaceChange(status: decisionStatus, newReasonCodeRaw: lastReasonCodeRaw,
                                     previousReasonCodeRaw: priorReasonForThisItem,
                                     changeReasonRaw: priorReasonForThisItem != nil ? "context-accumulated-same-item" : nil,
                                     identityRevision: rev, nowEpoch: nowEpoch)
        lastDecisionReasonForItem = lastReasonCodeRaw
        lastDecisionReasonItemRevision = rev
        // R3 §1 — record the general content-character CAUTION as a distinct EVIDENCE_CAPTURED event (its own
        // provenance reason) so İçerik Kanıtı shows the wellbeing marker without conflating it with a personal match.
        if let gc = generalCaution {
            timeline.record(category: .evidenceCaptured, status: .caution,
                            reasonCodeRaw: GuardianReasonCodeV1.generalContentCaution.rawValue,
                            identityRevision: rev, nowEpoch: nowEpoch)
            emit("GENERAL_CAUTION_EVENT primary=\(gc.primaryCategory?.rawValue ?? "-") markers=\(gc.markers.count) item=\(rev)")
        }
        _ = textRelation; _ = photoRelation   // classified for provenance (emitted at decision site); kept for audit.
        // (e) B4 + 1G + 2.3 — PERSONAL FILTER events (ONLY on a REAL shield hit against the user's own rules). The
        // honest UNCONTROLLED-SURFACE chain the mandate (2.3) asks for: policy match → ACTION SELECTED → warning ready
        // → (delivery requested) → PRESENTATION UNVERIFIED. On a 3rd-party app (ReplayKit) we do NOT own the feed
        // (rule 18): we can SELECT the user's configured action and PREPARE/REQUEST a warning, but we have NO
        // onAppear / render callback for the OTHER app's screen, so we can NEVER prove the warning was actually
        // PRESENTED — and the user's preference was therefore NEVER actually APPLIED to the content.
        //
        // 2.3 FIX: the extension no longer writes PREFERENCE_APPLIED here. On an uncontrolled surface the user's
        // action is only SELECTED (what we WOULD do), not applied — the content was not hidden/blurred/skipped.
        // PREFERENCE_APPLIED is reserved for a CONTROLLED surface where a preference outcome was REALLY executed.
        if shieldHit, let outcome = shieldOutcome {
            timeline.record(category: .personalShieldMatched, status: .shieldMatch,
                            reasonCodeRaw: GuardianReasonCodeV1.personalShieldWarnOnly.rawValue,
                            identityRevision: rev, nowEpoch: nowEpoch)
            timeline.record(category: .matchDetected, status: .shieldMatch,
                            reasonCodeRaw: GuardianReasonCodeV1.personalShieldWarnOnly.rawValue,
                            identityRevision: rev, nowEpoch: nowEpoch)
            // 2.3 — the user's configured action is SELECTED (not executed). On a 3rd-party surface it degrades to
            // WARN-only (rule 18); recording ACTION_SELECTED makes the "what we would do" honest without claiming it
            // was applied to the feed.
            timeline.record(category: .actionSelected, status: .shieldMatch,
                            reasonCodeRaw: GuardianReasonCodeV1.personalShieldWarnOnly.rawValue,
                            identityRevision: rev, nowEpoch: nowEpoch)
            timeline.record(category: .warningReady, status: .caution,
                            reasonCodeRaw: GuardianReasonCodeV1.personalShieldWarnOnly.rawValue,
                            identityRevision: rev, nowEpoch: nowEpoch)
            // 2.3 — we REQUEST delivery of the prepared warning (hand it to a surface) — still not proof of on-screen.
            timeline.record(category: .warningDeliveryRequested, status: .caution,
                            reasonCodeRaw: GuardianReasonCodeV1.personalShieldWarnOnly.rawValue,
                            identityRevision: rev, nowEpoch: nowEpoch)
            // 1G/2.3 — the extension cannot observe the 3rd-party app's screen: presentation is UNVERIFIED, never
            // claimed, and PREFERENCE_APPLIED is NEVER written on this uncontrolled path.
            timeline.record(category: .presentationUnverified, status: .unknown,
                            reasonCodeRaw: GuardianReasonCodeV1.personalShieldWarnOnly.rawValue,
                            identityRevision: rev, nowEpoch: nowEpoch)
            emit("PERSONAL_SHIELD_MATCH rule=\(outcome.ruleID ?? "-") layer=\(outcome.layerDecision.rawValue) action=ACTION_SELECTED_WARN_READY_DELIVERY_REQUESTED_PRESENTATION_UNVERIFIED_UNCONTROLLED policyRev=\(policyRevision)")
        }
        // R2 §B4/§C/§2.3 — the PHOTO-SHIELD chain, recorded with the DISTINCT personalPhotoMatchWarnOnly reason so a
        // VISUAL personal match is never conflated with a text/wellbeing signal. Same uncontrolled-surface honesty: we
        // SELECT the user's action and PREPARE a warning, but on a 3rd-party app presentation is UNVERIFIED and no
        // PREFERENCE_APPLIED is ever written. Full provenance is in the match (rule id, roi, hamming, item revision,
        // policy revision, session, timestamp). We record it only for an ACTIONABLE (near-exact) match (the caller
        // already filtered LOW/MEDIUM to evidence-only), so the timeline never shows a weak visual guess as a decision.
        if let photo = photoMatch {
            timeline.record(category: .personalShieldMatched, status: .shieldMatch,
                            reasonCodeRaw: GuardianReasonCodeV1.personalPhotoMatchWarnOnly.rawValue,
                            identityRevision: rev, nowEpoch: nowEpoch)
            timeline.record(category: .matchDetected, status: .shieldMatch,
                            reasonCodeRaw: GuardianReasonCodeV1.personalPhotoMatchWarnOnly.rawValue,
                            identityRevision: rev, nowEpoch: nowEpoch)
            timeline.record(category: .actionSelected, status: .shieldMatch,
                            reasonCodeRaw: GuardianReasonCodeV1.personalPhotoMatchWarnOnly.rawValue,
                            identityRevision: rev, nowEpoch: nowEpoch)
            timeline.record(category: .warningReady, status: .caution,
                            reasonCodeRaw: GuardianReasonCodeV1.personalPhotoMatchWarnOnly.rawValue,
                            identityRevision: rev, nowEpoch: nowEpoch)
            timeline.record(category: .warningDeliveryRequested, status: .caution,
                            reasonCodeRaw: GuardianReasonCodeV1.personalPhotoMatchWarnOnly.rawValue,
                            identityRevision: rev, nowEpoch: nowEpoch)
            timeline.record(category: .presentationUnverified, status: .unknown,
                            reasonCodeRaw: GuardianReasonCodeV1.personalPhotoMatchWarnOnly.rawValue,
                            identityRevision: rev, nowEpoch: nowEpoch)
            emit("PHOTO_SHIELD_DECISION rule=\(photo.ruleID) state=\(photo.state.rawValue) roi=\(photo.roi.rawValue) item=\(photo.itemIdentityRevision) action=ACTION_SELECTED_WARN_READY_DELIVERY_REQUESTED_PRESENTATION_UNVERIFIED_UNCONTROLLED policyRev=\(policyRevision)")
        }
    }

    /// A1 (FIX) — re-read the shared policy revision; if it advanced since broadcast start / the last reload, load
    /// the new rule set and INVALIDATE the current decision so it is re-evaluated against the new policy without a
    /// restart. Cheap when nothing changed (one revision read). Honest on failure: an empty reload clears the
    /// surface to UNKNOWN rather than keeping a stale protective claim.
    private func reloadPolicyIfChanged(nowEpoch: Double) {
        let liveRevision = sharedShieldStore.policyRevision
        guard liveRevision != policyRevision else { return }
        let loaded = sharedShieldStore.loadPolicy()
        index = loaded.index
        shieldExceptions = loaded.exceptions
        shieldRules = loaded.rules          // R8 §7 — reload raw rules (with aliases) under the new policy revision.
        policyRevision = loaded.policyRevision
        sharedRulesActive = loaded.sharedContainerActive
        shieldFeatures = loaded.features   // R2 §B — reload photo-reference signatures under the new policy revision.
        // The previous decision was produced under an OLDER revision → it is STALE and must not be shown as current.
        // Drop the resolved surface to a neutral OBSERVING state and force a fresh evaluation of the current item.
        lastResolvedSurfaceRaw = ""
        lastReasonCodeRaw = GuardianReasonCodeV1.observingNoDecisionYet.rawValue
        clearDecisionFacts()   // §A/§B2 — the decision under the old policy revision is stale; publish no decision.
        policyChangedForceReeval = true
        publishHeartbeat(nowEpoch: nowEpoch)
        // C-lane — the rule change is a real engine moment: the prior decision was invalidated.
        timeline.record(category: .contentChanged, status: .unknown,
                        reasonCodeRaw: GuardianReasonCodeV1.contentChangedReset.rawValue,
                        identityRevision: lastTimelineIdentityRevision, nowEpoch: nowEpoch)
        emit("POLICY_RELOAD liveRev=\(policyRevision) activeRules=\(index.count) shared=\(sharedRulesActive) forcedReeval=true")
    }

    /// R5 §2 — re-read the FAMILY revision on the ~1s gate; when it advanced, reload the profile and INVALIDATE the
    /// current decision (the old decision was produced under an old family policy — it must never be shown as
    /// current; the Island cannot carry it). Cheap when unchanged: one UserDefaults read.
    private func reloadFamilyProfileIfChanged(nowEpoch: Double) {
        guard familyStore.familyRevision != familyRevision else { return }
        reloadFamilyProfile(nowEpoch: nowEpoch, invalidate: true)
    }

    /// R5 §2 — (re)load the shared family profile with HONEST state handling. STALE/CORRUPT reads NEVER present the
    /// old profile as current: when a child/teen mode is (or was last known) active, the degraded flag makes the
    /// adjudicator fail closed to UNKNOWN with the distinct family reason until a VALID profile is readable again.
    private func reloadFamilyProfile(nowEpoch: Double, invalidate: Bool) {
        let wasNonAdult = (familyProfile?.mode ?? .adult) != .adult
        let loaded = familyStore.load()
        familyRevision = loaded.liveRevision
        familyProfileState = loaded.state
        switch loaded.state {
        case .valid, .unsupported:
            // UNSUPPORTED is carried through: the FROZEN engine fails closed on the jurisdiction itself (§12 law).
            familyProfile = loaded.profile
            familyDegradedNonAdult = false
        case .missing:
            familyProfile = nil           // explicit absence = adult default posture (honest; nothing to protect FROM)
            familyDegradedNonAdult = false
        case .stale, .corrupt, .invalid:
            // The bytes we could read (if any) must not be used as current. Fail closed if the degraded record — or
            // the last known live profile — was a child/teen mode. R6 §2.1: a DOMAIN-INVALID child/teen record
            // (impossible age / adult-carrying-child-field / declaration mismatch) is treated exactly like STALE/
            // CORRUPT — the wrong age NEVER reaches the frozen ChildAgePolicyEngineV1.
            let staleKnownNonAdult = (loaded.profile?.mode ?? .adult) != .adult
            familyProfile = nil
            familyDegradedNonAdult = staleKnownNonAdult || wasNonAdult
            // R5 §10 — measure-only: every degraded family read is counted (the §2 stale-read error class).
            selfEvalCounters.foldR5(registerWasSupportedUnknown: false, familyReadDegraded: true,
                                    bridgeUnavailableCount: 0)
        }
        if invalidate {
            lastResolvedSurfaceRaw = ""
            lastReasonCodeRaw = GuardianReasonCodeV1.observingNoDecisionYet.rawValue
            clearDecisionFacts()          // the decision under the old family policy is stale — publish none
            decisionValidityWindow = nil  // the window was opened under the OLD family policy — it must not extend
            policyChangedForceReeval = true
            publishHeartbeat(nowEpoch: nowEpoch)
            timeline.record(category: .contentChanged, status: .unknown,
                            reasonCodeRaw: GuardianReasonCodeV1.contentChangedReset.rawValue,
                            identityRevision: lastTimelineIdentityRevision, nowEpoch: nowEpoch)
            emit("FAMILY_POLICY_RELOAD familyRev=\(familyRevision) state=\(familyProfileState.rawValue) mode=\(familyProfile?.mode.rawValue ?? "-") degradedNonAdult=\(familyDegradedNonAdult) forcedReeval=true")
        }
    }

    /// A1 — write the SESSION-SCOPED analysis OFF-ACK. `analysisOff` is our TRUE applied heavy-path state (paused),
    /// stamped with this session id + the CURRENT desired generation we observed. Because the app matches the ack
    /// against the live session + generation, a stale ack (previous session / older toggle) can never read as a
    /// current OFF confirmation, and an intent-OFF-but-analysis-still-running mismatch is surfaced, not hidden.
    private func writeAnalysisOffAck() {
        let ack = GuardianAnalysisOffAckV1(sessionID: sessionID,
                                           appliedGeneration: GuardianAnalysisGateV1.desiredGeneration(suite: heartbeatSuite),
                                           analysisOff: analysisPaused,
                                           epochSeconds: Date().timeIntervalSince1970)
        GuardianAnalysisOffAckV1.writeAck(ack, suite: heartbeatSuite)
    }

    /// R2 §A — clear the independent DECISION facts so a stale decision can never linger in the heartbeat after the
    /// surface was dropped (policy reload / idle / wake / OFF). `lastObservedItemRevision` is deliberately NOT reset
    /// here — the engine's latest observed item is independent of whether a decision exists; it advances on its own.
    private func clearDecisionFacts() {
        lastDecisionItemRevision = -1; lastDecisionEpoch = 0
        // R4 §6 — a dropped decision (policy reload / idle / wake / OFF) must not leave a prior reason that a later
        // decision could treat as "the previous surface for this item" — clear the progressive-understanding tracker.
        lastDecisionReasonForItem = nil; lastDecisionReasonItemRevision = -1
    }

    /// A3 — publish a derived observation heartbeat so the app can prove the broadcast is REALLY live (freshness),
    /// never from its own in-app toggle. Derived scalars only; no raw media/text. Cheap (one JSON encode / frame).
    private func publishHeartbeat(nowEpoch: Double) {
        heartbeatSeq &+= 1
        // §3 — publish the resolved ITEM IDENTITY REVISION this surface belongs to, so the app-side truth projection
        // can detect a NEW item and invalidate the prior decision's surface (no green carryover to new content).
        // R2 §A — publish the INDEPENDENT decision facts: `itemIdentityRevision` is the DECISION's item (fact 6),
        // `decisionEpochSeconds` is the DECISION's own timestamp (so re-publishing an old decision can't refresh it),
        // and `currentItemIdentityRevision` is the LATEST observed item (which can diverge from the decision's item →
        // the app reports STALE_ITEM). When there is no per-content decision the decision facts stay empty (-1 / 0).
        // R4 §2C — the VALIDITY FACT. Published ONLY when the standing validity window is for the SAME decision item +
        // policy revision the heartbeat carries (so an extension-extended window can never leak onto a different item
        // or a stale policy). The app consumes these to avoid calling "stale" what the extension lawfully extended —
        // WITHOUT ever moving `decisionEpochSeconds` (the original evidence epoch stays put). A mismatch publishes 0s.
        let w = decisionValidityWindow
        let windowApplies = (w != nil)
            && w!.decisionItemIdentityRevision == lastDecisionItemRevision
            && w!.decisionPolicyRevision == policyRevision
            && lastDecisionItemRevision >= 0
        // R7 §2 — publish the FAMILY policy facts so the app's truth projection can require the family revision to
        // match too (a family change makes the decision stale immediately, even before the next inference). The
        // decision's family revision is the one the decision was bound to (`familyRevision` is the live family rev the
        // decision ran under; it advances + forces re-eval on any family change). The mode/state let the app fail
        // closed on a child/teen decision it cannot verify.
        let famMode = familyProfile?.mode.rawValue ?? (familyDegradedNonAdult ? "NON_ADULT_DEGRADED" : "ADULT")
        let famNonAdult = (familyProfile?.mode ?? .adult) != .adult || familyDegradedNonAdult
        // R9 §8 (P1-7) — publish the HONEST AUDIO-ANALYSIS ladder state for the decision's item so the coverage UI can
        // never imply "all senses active". Derived from the current `liveAudioForItem.availability`: a real
        // `.available` reads as ANALYSIS_COMPLETED_NO_EVENT (ran, no event) when it has no events, or
        // CLASSIFIER_RESULT_RECEIVED when it carries real events; every UNAVAILABLE reason maps to its honest ladder
        // rung. Empty only when no audio window was attempted for this decision (coverage genuinely unknown).
        // R10 §1/§P1-7 — read the audio evidence + coverage lifecycle under the lock (the async apply writes them off
        // this thread). A PENDING lifecycle for the DECISION's item surfaces the DISTINCT "analiz sürüyor" rung — never
        // AVAILABLE — so the coverage row is honest while a window is in flight.
        audioStateLock.lock()
        let audioEvidenceSnapshot = liveAudioForItem
        let audioPending = (audioCoverageLifecycle == .pending && pendingAudioItemRevision == lastDecisionItemRevision)
        audioStateLock.unlock()
        let audioLadderRaw = audioPending
            ? AudioCoverageLifecycleV1.pending.pendingLadderState.rawValue
            : Self.audioLadderRaw(for: audioEvidenceSnapshot)
        let hb = GuardianObservationHeartbeatV1(epochSeconds: nowEpoch, sequence: heartbeatSeq,
                                                surfaceRaw: lastResolvedSurfaceRaw, reasonCodeRaw: lastReasonCodeRaw,
                                                broadcasting: true, sessionID: sessionID,
                                                policyRevision: policyRevision,
                                                itemIdentityRevision: lastDecisionItemRevision,
                                                decisionEpochSeconds: lastDecisionEpoch,
                                                currentItemIdentityRevision: lastObservedItemRevision,
                                                validUntilEpoch: windowApplies ? w!.validUntilEpoch : 0,
                                                revalidationCount: windowApplies ? w!.revalidationCount : 0,
                                                lastRevalidationEpoch: windowApplies ? w!.lastRevalidationEpoch : 0,
                                                decisionFamilyRevision: lastDecisionItemRevision >= 0 ? familyRevision : 0,
                                                familyModeRaw: famNonAdult ? famMode : "",
                                                familyStateRaw: familyProfileState.rawValue,
                                                audioLadderStateRaw: audioLadderRaw)
        GuardianObservationHeartbeatBridgeV1.write(hb, suite: heartbeatSuite)
    }

    /// R9 §8 (P1-7) — map the current audio evidence to an HONEST ladder-state raw for the coverage UI. The coverage
    /// display must never imply audio ran when it did not: a real `.available` with events → CLASSIFIER_RESULT_RECEIVED;
    /// a real `.available` with none → ANALYSIS_COMPLETED_NO_EVENT (ran, found nothing); each UNAVAILABLE reason → its
    /// honest non-analysis rung; nil → empty (no window attempted). Never fabricates an "analyzed" state.
    private static func audioLadderRaw(for evidence: LiveAudioWindowEvidenceV1?) -> String {
        guard let e = evidence else { return "" }
        switch e.availability {
        case .available:
            return (e.events.isEmpty ? LiveAudioAnalysisStateV1.analysisCompletedNoEvent
                                     : LiveAudioAnalysisStateV1.classifierResultReceived).rawValue
        case .deferredThermal, .resourceDeferred:
            return LiveAudioAnalysisStateV1.resourceDeferred.rawValue
        case .formatUnsupported:
            return LiveAudioAnalysisStateV1.formatUnsupported.rawValue
        case .noBuffers:
            return LiveAudioAnalysisStateV1.captureUnavailable.rawValue
        case .frameworkUnavailable:
            return LiveAudioAnalysisStateV1.deviceUnverified.rawValue
        }
    }

    override func broadcastFinished() {
        let s = frameDurationsNs.map { Double($0) / 1_000_000 }.sorted()
        let p50 = s.isEmpty ? 0 : s[s.count/2], p95 = s.isEmpty ? 0 : s[min(s.count-1, Int(Double(s.count)*0.95))]
        emit(String(format: "BROADCAST_FINISHED frames=%d changes=%d analyzed=%d heavy=%d reuse=%d shots=%d items=%d cheapP50ms=%.3f cheapP95ms=%.3f peakMemoryMB=%.1f thermal=%@ shotPolicy=%@ groupingPolicy=%@",
                    stats.framesProcessed, stats.contentChanges, stats.contentsAnalyzed, stats.heavyAnalysisRuns, stats.cacheReuse,
                    shotSegmenter.shotCount, itemGrouper.confirmedOrProvisionalItemCount,
                    p50, p95, peakMemoryMB, Self.thermalString(), shotSegmenter.policyRevision, itemGrouper.policy.revision))
        // P010: Tier-1 session summary — bounded derived counters only (per-session, one line).
        emit("TIER1_SUMMARY policy=\(tier1.policy.revision) assessed=\(tier1.assessedCount) same=\(tier1.sameCount) new=\(tier1.newCount) unknown=\(tier1.unknownCount) disagree=\(tier1.disagreementCount) skippedThrottle=\(tier1.skippedThrottleCount)")
        // P1: identity-resolution session summary — how often Tier-1 changed the Guardian-bound identity.
        emit("RESOLVE_SUMMARY resolved=\(identityResolver.resolvedCount) newConfirmed=\(identityResolver.newConfirmedCount) contradictions=\(identityResolver.contradictionCount) overrodeTier0=\(identityResolver.overrodeTier0Count) finalGen=\(identityResolver.liveGeneration.value)")
        // R2 §B6 — PHOTO-SHIELD cost summary (per-session, derived counters only): how many items we considered, how
        // many signatures/ROIs the visual matcher computed, how many actionable matches, and how many items were
        // SKIPPED under thermal pressure. This is the honest resource accounting the mandate's §B6/§E/§RESOURCE asks
        // for — the photo shield is bounded per ITEM (not per frame) and never ran on the hot path.
        emit("PHOTO_SHIELD_SUMMARY refs=\(shieldFeatures.count) itemsConsidered=\(photoItemsConsidered) signatures=\(photoSignaturesComputed) rois=\(photoROIsEvaluated) actionable=\(photoActionableMatches) skippedThermal=\(photoSkippedThermal)")
        // R8 §1/§2/§4 — LIVE AUDIO session summary (derived counters only; never raw audio). The capture-probe verdict
        // is the honest AUDIO_CAPTURE_AVAILABLE status (FEATURE_UNVERIFIED off-device; PRESENT_WITH_AUDIO is
        // DEVICE_UNVERIFIED). The window counters report how much audio work actually ran vs was deferred/stale-dropped.
        emit("AUDIO_CAPTURE_SUMMARY \(audioCaptureProbe.summary)")
        let hs = audioHandoff.snapshot
        emit("AUDIO_WINDOW_SUMMARY knownClasses=\(audioKnownClassifications.count) analyzed=\(audioWindowsAnalyzed) deferred=\(audioWindowsDeferred) staleDiscarded=\(audioStaleDiscarded) queueDropped=\(hs.droppedOldest) asyncApplied=\(audioApplied) asyncDropped=\(audioDroppedLate) lastDrop=\(audioLastDropReason.isEmpty ? "-" : audioLastDropReason) peakBytes=\(hs.peakRetainedBytes) peakOutstanding=\(hs.peakOutstandingWindows) windowsSubmitted=\(hs.totalSubmitted)")
        // R10 §1/§2 — capture is OVER. Mark it so any still-in-flight async window completion is DROPPED (never applied
        // into a dead capture). §1.2 — no cross-session audio leakage: PURGE the ONE ownership store (queue + bytes +
        // outstanding) + reset per-item audio state + coverage lifecycle at session end.
        captureActive = false
        audioHandoff.purgeForSessionEnd()
        setLiveAudio(.unavailable(.noBuffers, binding: LiveAudioBindingV1(sessionID: sessionID, itemIdentityRevision: -1,
                      generation: 0, ptsStartSeconds: nil, ptsEndSeconds: nil), classifierVersion: GeneralAudioHeadV1.version),
                     lifecycle: .notAttempted)
        audioStateLock.lock(); liveAudioForItem = nil; audioReadjudicationSnapshot = nil; audioStateLock.unlock()
        audioWindowsRunThisItem = 0; audioWindowItemRevision = -1
        // R9 §2.1/§5 — release the short-lived PCM copies + tear down the stream analyzer (zero-retention: no raw audio
        // or analyzer survives the session; PCM copies are never persisted and are dropped here at the latest).
        #if canImport(AVFoundation) && canImport(SoundAnalysis)
        audioPCMLock.lock(); audioPCMStore.removeAll(); audioPCMLock.unlock(); audioStreamSession.stop()
        #endif
        // R3 §9 — MEASURE-ONLY self-eval counters for the session (counts only; never raw media/text; no behaviour
        // change). Lets the per-session summary surface "what the system measured about itself" (§9 honesty).
        emit("SELF_EVAL_SUMMARY \(selfEvalCounters.summary)")
        // A3/D-lane — the broadcast stopped: CLEAR the heartbeat so the app can NEVER keep looking "observing" after
        // the broadcast ends (session-end cleanup; no stale protection claim). App reads ABSENT → UNAVAILABLE.
        GuardianObservationHeartbeatBridgeV1.clear(suite: heartbeatSuite)
        // §5.5 — clear the user-controlled mode so the NEXT broadcast starts ACTIVE, never inheriting this idle choice.
        GuardianSessionModeBridgeV1.clear(suite: heartbeatSuite)
        // A1 — clear the SESSION-SCOPED analysis OFF-ACK so a stale ack never survives into the next session as a
        // false "OFF applied" confirmation (session-end cleanup; the next session re-proves its own applied state).
        GuardianAnalysisOffAckV1.clear(suite: heartbeatSuite)
        // §5.2 — one honest capability-probe summary for the session (FEATURE_UNAVAILABLE unless a device run upgraded it).
        if evidenceBuild {
            emit("CAPABILITY_PROBE_FINAL \(capabilityProbe.summary)")
            emit("CAPABILITY_PROBE_V2_FINAL \(capabilityProbeV2.summary)")
        }
        emit("HEARTBEAT_CLEARED onFinish=true")
        // C/D-lane — the session ended. Record the final SESSION_ENDED event (writes a broadcasting=false snapshot so
        // the app shows ENDED, never a lingering "live"), then CLEAR the timeline (mandatory session-end cleanup —
        // mandate D: no history survives the session; history retention is a separate explicit user preference).
        timeline.record(category: .sessionEnded, status: .ended, reasonCodeRaw: nil,
                        identityRevision: lastTimelineIdentityRevision, nowEpoch: Date().timeIntervalSince1970)
        timeline.markFinished(nowEpoch: Date().timeIntervalSince1970)
        timeline.clear()
        emit("TIMELINE_CLEARED onFinish=true")
    }

    // A1 / C-lane — interruption lifecycle. ReplayKit pauses the sample stream on interruptions (incoming call,
    // Control Center, etc.). We record the real OBSERVATION_GAP so the user sees honest interruption history, and
    // we STOP refreshing the heartbeat so the app degrades to STALE within the freshness window (never a fake live).
    override func broadcastPaused() {
        emit("BROADCAST_PAUSED")
        audioCaptureProbe.noteInterruption()   // R8 §1 — a capture interruption resets the PTS continuity baseline.
        timeline.record(category: .observationGap, status: .ended,
                        reasonCodeRaw: GuardianReasonCodeV1.sessionNotObserving.rawValue,
                        identityRevision: lastTimelineIdentityRevision, nowEpoch: Date().timeIntervalSince1970)
    }

    // §F — the ANNOTATION-CALLBACK source, now actually wired. `broadcastAnnotated(withApplicationInfo:)` is the
    // documented RPBroadcastSampleHandler hook the host app uses to push application info (distinct guarantee from the
    // per-sample attachment key). We feed its payload into V2's CALLBACK channel (digested + session-keyed, never
    // retained), so the two sources are scored INDEPENDENTLY. Absence/empty is recorded honestly. Only under the
    // evidence gate; it changes NO behaviour (measurement only). Previously this override did not exist, so the
    // callback channel could never carry identity — a real gap this closes.
    override func broadcastAnnotated(withApplicationInfo applicationInfo: [AnyHashable: Any]) {
        guard evidenceBuild else { return }
        // Build a stable, privacy-safe opaque token from the keys+values present (sorted for determinism). We never
        // log or retain the raw contents; V2 digests the token with the per-session key immediately.
        let token = applicationInfo.keys
            .map { "\($0)" }
            .sorted()
            .joined(separator: "|")
        if token.isEmpty {
            capabilityProbeV2.observeAbsent(source: .annotationCallback)
        } else {
            capabilityProbeV2.observe(rawIdentity: token, source: .annotationCallback,
                                      assertedStepIndex: probeAssertedStepIndex)
        }
        emit("BROADCAST_ANNOTATED keys=\(applicationInfo.count) probeV2=\(capabilityProbeV2.summary)")
    }

    override func broadcastResumed() {
        emit("BROADCAST_RESUMED")
        // Republish an immediate heartbeat so the app flips back to live the moment observation resumes.
        lastHeartbeatMs = -.greatestFiniteMagnitude
        publishHeartbeat(nowEpoch: Date().timeIntervalSince1970)
        timeline.record(category: .observationResumed, status: .active,
                        reasonCodeRaw: GuardianReasonCodeV1.observingNoDecisionYet.rawValue,
                        identityRevision: lastTimelineIdentityRevision, nowEpoch: Date().timeIntervalSince1970)
    }

    private static func thermalString() -> String {
        switch ProcessInfo.processInfo.thermalState { case .nominal: "nominal"; case .fair: "fair"; case .serious: "serious"; case .critical: "critical"; @unknown default: "unknown" }
    }
    /// Resident memory (MB) via mach task_info — official API; proxy for extension footprint vs ~50MB budget.
    private static func residentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count) } }
        return kr == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576.0 : 0
    }
    /// Generic MULTI-REGION signature + bounded row/col luma projections → SegmentFrameV4. Normalized sub-rects
    /// (NO hardcoded pixel coords, no app geometry). One cheap in-place pass; raw buffer NOT retained.
    private static func segmentFrame(_ px: CVPixelBuffer) -> SegmentFrameV4? {
        CVPixelBufferLockBaseAddress(px, .readOnly); defer { CVPixelBufferUnlockBaseAddress(px, .readOnly) }
        let w = CVPixelBufferGetWidth(px), h = CVPixelBufferGetHeight(px); guard w >= 8, h >= 8 else { return nil }
        let fmt = CVPixelBufferGetPixelFormatType(px)
        guard let base = CVPixelBufferGetBaseAddressOfPlane(px, 0) ?? CVPixelBufferGetBaseAddress(px) else { return nil }
        let stride = CVPixelBufferGetBytesPerRowOfPlane(px, 0) != 0 ? CVPixelBufferGetBytesPerRowOfPlane(px, 0) : CVPixelBufferGetBytesPerRow(px)
        let bpp = (fmt == kCVPixelFormatType_32BGRA || fmt == kCVPixelFormatType_32ARGB) ? 4 : 1
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        func luma(_ xf: Double, _ yf: Double) -> Int {
            let x = min(w-1, max(0, Int(xf * Double(w)))), y = min(h-1, max(0, Int(yf * Double(h))))
            return Int(ptr[y*stride + x*bpp])
        }
        func regionHash(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> UInt64 {
            var s = [Int](repeating: 0, count: 64); var total = 0
            for gy in 0..<8 { for gx in 0..<8 {
                let xf = x0 + (x1-x0)*(Double(gx)+0.5)/8, yf = y0 + (y1-y0)*(Double(gy)+0.5)/8
                let v = luma(xf, yf); s[gy*8+gx] = v; total += v
            } }
            let mean = total/64; var bits: UInt64 = 0
            for i in 0..<64 where s[i] >= mean { bits |= (UInt64(1) << UInt64(i)) }
            return bits
        }
        var hist = [0,0,0,0]
        for gy in 0..<8 { for gx in 0..<8 {
            let v = luma((Double(gx)+0.5)/8, (Double(gy)+0.5)/8)
            hist[min(3, v/64)] += 1
        } }
        let regions = MultiRegionSignature(
            global: regionHash(0,0,1,1), center: regionHash(0.25,0.25,0.75,0.75),
            top: regionHash(0,0,1,0.25), bottom: regionHash(0,0.75,1,1),
            left: regionHash(0,0,0.25,1), right: regionHash(0.75,0,1,1), lumaHistogram: hist)
        // Bounded 8-bin row/col luma projections (mean luma per band, normalized 0..1) — for the coherent
        // scroll/swipe cue (§17: 8×8 preserves swipe/pan discrimination at ~¼ the projection cost of 16×16).
        let bins = 8
        var rows = [Double](repeating: 0, count: bins), cols = [Double](repeating: 0, count: bins)
        for b in 0..<bins {
            var rs = 0, cs = 0
            for k in 0..<bins {
                rs += luma((Double(k)+0.5)/Double(bins), (Double(b)+0.5)/Double(bins))   // row band b: vary x
                cs += luma((Double(b)+0.5)/Double(bins), (Double(k)+0.5)/Double(bins))   // col band b: vary y
            }
            rows[b] = Double(rs) / Double(bins) / 255.0
            cols[b] = Double(cs) / Double(bins) / 255.0
        }
        return SegmentFrameV4(regions: regions, rowProjection: rows, colProjection: cols)
    }

    // C1 FIX — derived-only diagnostic emit. Two channels, both privacy-safe (derived text, NEVER a frame/OCR):
    //
    //  1. os_log (.notice) ALWAYS — this is in-memory, rate-managed by the OS, costs no disk I/O, and is the
    //     correct production diagnostic channel. (Not retained by us; subject to the system log buffer.)
    //  2. The high-volume APPEND-TO-DISK proof log is gated behind `evidenceBuild` (the §10 EvidenceBuildPolicyV1
    //     — structurally OFF in release; DEBUG + explicit env/compile opt-in only). The Phase-B THERMAL_SERIOUS
    //     incident was caused by this per-frame disk append; it must NEVER be release behaviour. Every high-volume
    //     call site also already checks `evidenceBuild`, so in release this method only ever hits os_log.
    private func emit(_ s: String) {
        log.notice("\(s, privacy: .public)")
        guard evidenceBuild else { return }   // C1: no disk writes unless evidence build is explicitly enabled
        let line = "GEN8_CA \(s)\n"
        if let dir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            let url = dir.appendingPathComponent("gen8_crossapp_proof.log")
            if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
            else { try? line.data(using: .utf8)?.write(to: url) }
        }
    }
}
