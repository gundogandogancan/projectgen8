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
    // C/D-lane — the LIVE SESSION TIMELINE writer (bounded RAM ring + bounded App Group mirror). Session-scoped;
    // cleared on finish. Distinct cadence from the heartbeat (meaningful events only, never per frame).
    private lazy var timeline = GuardianSessionTimelineWriterV1(sessionID: sessionID, suite: heartbeatSuite)
    private var lastTimelineIdentityRevision = -1

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        sessionStartNanos = DispatchTime.now().uptimeNanoseconds
        index.upsert(ShieldRuleV2(ruleID: "demo-spoiler", inputType: .textExact, rawUserLabel: "spoiler", action: .hideIfControlled, createdAtEpoch: 1))
        // Honest labeling (audit C1): raw FRAMES are never persisted; this derived proof log IS a disk write.
        emit("BROADCAST_STARTED ephemeral=true rawFramesPersisted=false derivedProofLog=true cloud=false shotPolicy=\(shotSegmenter.policyRevision) groupingPolicy=\(itemGrouper.policy.revision) profile=\(itemGrouper.profile.name) sameCeiling=\(String(format: "%.2f", itemGrouper.sameCeiling)) evidence=\(evidenceBuild)")
        // A3 — the broadcast is REALLY live now: publish an initial OBSERVING heartbeat (no per-content decision
        // yet). The app flips to OBSERVING off this freshness, not off its own toggle. IPC unavailable → no-op.
        lastResolvedSurfaceRaw = ""   // observing, no decision yet
        lastReasonCodeRaw = GuardianReasonCodeV1.observingNoDecisionYet.rawValue
        publishHeartbeat(nowEpoch: Date().timeIntervalSince1970)
        emit("HEARTBEAT_IPC \(heartbeatSuite != nil ? "ACTIVE" : "DEGRADED(no-app-group)")")
        // C-lane — the first REAL timeline event: the session actually started (broadcast live).
        timeline.record(category: .sessionStarted, status: .active,
                        reasonCodeRaw: GuardianReasonCodeV1.observingNoDecisionYet.rawValue,
                        identityRevision: -1, nowEpoch: Date().timeIntervalSince1970)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with type: RPSampleBufferType) {
        guard type == .video else { return }
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
        let mustEvaluate = !resolved.mayReusePriorDecision
        if mustEvaluate {
            governor.noteItemGroup()
            stats.contentsAnalyzed += 1
            stats.heavyAnalysisRuns += 1
            let t0 = DispatchTime.now().uptimeNanoseconds
            let env = CrossAppObservationBuilder.envelope(contentID: resolved.contentID, ocrText: ocrText, soundEvents: [], languages: ocrLangs)
            let outcome = evaluator.evaluate(.init(envelope: env, controlledSurface: true), index: index)
            matchState = outcome.matchState.rawValue
            firstTrustworthyMs = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
            emit("OCR resolvedID=\(resolved.contentID) status=\(ocrStatus.rawValue) hasText=\(ocrText != nil) chars=\(ocrText?.count ?? 0) long=\(ocrLong) latMs=\(String(format: "%.1f", ocrLatencyMs)) match=\(matchState)")
            // A3/B3 — derive the lock-safe surface + REAL reason code for the fresh decision (same resolved id).
            let shieldHit = outcome.matchState.rawValue.uppercased().contains("MATCH") && outcome.matchState.rawValue.uppercased() != "NO_MATCH"
            if shieldHit {
                lastResolvedSurfaceRaw = "SHIELD_MATCH"
                lastReasonCodeRaw = GuardianReasonCodeV1.textEvidenceMatchedShield.rawValue
            } else if ocrText != nil {
                lastResolvedSurfaceRaw = "GUARDIAN_ON"
                lastReasonCodeRaw = GuardianReasonCodeV1.textEvidenceBenign.rawValue
            } else {
                // Fresh identity but no text evidence yet → honest: UNKNOWN surface, not a "safe" claim.
                lastResolvedSurfaceRaw = "UNKNOWN"
                lastReasonCodeRaw = (resolved.relation == .newContradiction || resolved.tier1Verdict == nil)
                    ? GuardianReasonCodeV1.newIdentityUnconfirmed.rawValue
                    : GuardianReasonCodeV1.textEvidenceUnavailable.rawValue
            }
            // C-lane TIMELINE — fresh identity ⇒ real content-lifecycle events (dedup-collapsed; never fabricated).
            // Each uses the SAME resolved identity revision so an event can never drift to another item.
            recordContentEvents(resolved: resolved, shieldHit: shieldHit, hasText: ocrText != nil,
                                nowEpoch: Date().timeIntervalSince1970)
        } else {
            stats.cacheReuse += 1
            governor.noteCacheHit()
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

    /// C-lane — translate a fresh resolved identity + its decision into the REAL timeline events. Called ONLY when
    /// a fresh identity was minted (mustEvaluate), so every event here is a genuine engine moment, not decoration.
    /// Events are dedup-collapsed by the writer, so re-entrant identical states never spam the feed.
    private func recordContentEvents(resolved: ResolvedContentIdentityV1, shieldHit: Bool, hasText: Bool,
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
        let decisionStatus: GuardianTimelineStatusV1 = shieldHit ? .shieldMatch : (hasText ? .benign : .unknown)
        timeline.record(category: .decision, status: decisionStatus,
                        reasonCodeRaw: lastReasonCodeRaw, identityRevision: rev, nowEpoch: nowEpoch)
    }

    /// A3 — publish a derived observation heartbeat so the app can prove the broadcast is REALLY live (freshness),
    /// never from its own in-app toggle. Derived scalars only; no raw media/text. Cheap (one JSON encode / frame).
    private func publishHeartbeat(nowEpoch: Double) {
        heartbeatSeq &+= 1
        let hb = GuardianObservationHeartbeatV1(epochSeconds: nowEpoch, sequence: heartbeatSeq,
                                                surfaceRaw: lastResolvedSurfaceRaw, reasonCodeRaw: lastReasonCodeRaw,
                                                broadcasting: true, sessionID: sessionID)
        GuardianObservationHeartbeatBridgeV1.write(hb, suite: heartbeatSuite)
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
        // A3/D-lane — the broadcast stopped: CLEAR the heartbeat so the app can NEVER keep looking "observing" after
        // the broadcast ends (session-end cleanup; no stale protection claim). App reads ABSENT → UNAVAILABLE.
        GuardianObservationHeartbeatBridgeV1.clear(suite: heartbeatSuite)
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
        timeline.record(category: .observationGap, status: .ended,
                        reasonCodeRaw: GuardianReasonCodeV1.sessionNotObserving.rawValue,
                        identityRevision: lastTimelineIdentityRevision, nowEpoch: Date().timeIntervalSince1970)
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
