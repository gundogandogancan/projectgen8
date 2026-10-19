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
    // §5 derived-only per-frame motion telemetry. Enabled at BUILD level (no App Group needed): compile with
    // -D GEN8_EVIDENCE_BUILD, OR env GEN8_EVIDENCE_BUILD=1. Logs ONLY derived scalars — NEVER raw frames/audio/OCR/title.
    #if GEN8_EVIDENCE_BUILD
    private let evidenceBuild = true
    #else
    private let evidenceBuild = ProcessInfo.processInfo.environment["GEN8_EVIDENCE_BUILD"] == "1"
    #endif
    private var evFrame = 0
    private var stats = CrossAppObservationStats()
    private let evaluator = ShieldEvaluatorV2.standard()
    private var index = ShieldIndex()
    private let log = Logger(subsystem: "com.gen8.guardian.dev.GuardianBroadcast", category: "CrossApp")
    private let sp = OSSignposter(subsystem: "com.gen8.guardian.dev.GuardianBroadcast", category: .pointsOfInterest)
    private var sessionStartNanos: UInt64 = 0
    private var peakMemoryMB = 0.0
    private var frameDurationsNs: [UInt64] = []      // bounded sample for latency telemetry

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        sessionStartNanos = DispatchTime.now().uptimeNanoseconds
        index.upsert(ShieldRuleV2(ruleID: "demo-spoiler", inputType: .textExact, rawUserLabel: "spoiler", action: .hideIfControlled, createdAtEpoch: 1))
        // Honest labeling (audit C1): raw FRAMES are never persisted; this derived proof log IS a disk write.
        emit("BROADCAST_STARTED ephemeral=true rawFramesPersisted=false derivedProofLog=true cloud=false shotPolicy=\(shotSegmenter.policyRevision) groupingPolicy=\(itemGrouper.policy.revision) profile=\(itemGrouper.profile.name) sameCeiling=\(String(format: "%.2f", itemGrouper.sameCeiling)) evidence=\(evidenceBuild)")
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

        // P009A-R2 §2 (audit B1) — MEASURED per-channel evidence at every SHOT TRANSITION. Derived scalars ONLY:
        // no raw frames/screenshots/video/audio/OCR text/captions/titles/app-private content. Evidence builds only.
        if evidenceBuild, let ch = decision.channels {
            emit("SHOTEV ts=\(String(format: "%.0f", tsMs)) shot=\(boundary.newShot.shotID.raw) in=\(boundary.newShot.transitionIn.rawValue) gate=\(boundary.newShot.swipeGate.rawValue) repl=\(String(format: "%.2f", boundary.newShot.replacementRatioIn)) item=\(decision.itemID.raw) state=\(decision.state.rawValue) prov=\(decision.provisional) S=\(String(format: "%.3f", decision.mergeScore)) N=\(String(format: "%.3f", decision.newScore)) theme=\(String(format: "%.3f", ch.themeDistance)) proj=\(String(format: "%.3f", ch.projectionCorrelation)) hist=\(String(format: "%.3f", ch.histogramDistance)) chrome=\(String(format: "%.3f", ch.chromeDistance)) regional=\(String(format: "%.3f", ch.regionalDistance)) gapMs=\(String(format: "%.0f", ch.gapSinceLastBoundaryMs)) prevDwellMs=\(String(format: "%.0f", ch.previousShotDwellMs)) itemMs=\(String(format: "%.0f", ch.elapsedItemMs)) strongNew=\(ch.strongNew) anchored=\(ch.anchored) coalesced=\(coalesced) fired=\(ch.firedEvidence.joined(separator: "+"))")
        }

        let t0 = DispatchTime.now().uptimeNanoseconds
        // §9/§26 one expensive understanding per ITEM: downstream analysis runs only when a NEW item opens
        // (confirmed or provisional/ambiguous — safety-first: ambiguous never reuses the prior item's state).
        var firstTrustworthyMs = 0.0
        var matchState = "REUSED_ITEM"
        if decision.openedNewItem {
            governor.noteItemGroup()
            stats.contentsAnalyzed += 1
            stats.heavyAnalysisRuns += 1
            let env = CrossAppObservationBuilder.envelope(contentID: "item-\(decision.itemID.raw)", ocrText: nil, soundEvents: [], languages: ["en"])
            let outcome = evaluator.evaluate(.init(envelope: env, controlledSurface: true), index: index)
            matchState = outcome.matchState.rawValue
            firstTrustworthyMs = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
        } else {
            stats.cacheReuse += 1
            governor.noteCacheHit()
        }
        let memMB = Self.residentMemoryMB(); peakMemoryMB = max(peakMemoryMB, memMB)

        // Derived log schema P009A — NO raw pixels / OCR text / audio. SHOT + ITEM levels, never collapsed.
        let reasons = boundary.reasons.map { $0.rawValue }.joined(separator: "+")
        emit("SHOT id=\(boundary.newShot.shotID.raw) policy=\(boundary.policyRevision) in=\(boundary.newShot.transitionIn.rawValue) swipe=\(boundary.newShot.swipeGate.rawValue) repl=\(String(format: "%.2f", boundary.newShot.replacementRatioIn)) reasons=\(reasons)")
        emit("ITEM id=\(decision.itemID.raw) rev=\(decision.itemRevision.number) state=\(decision.state.rawValue) groupingPolicy=\(itemGrouper.policy.revision) openedNew=\(decision.openedNewItem) provisional=\(decision.provisional) merge=\(String(format: "%.2f", decision.mergeScore)) new=\(String(format: "%.2f", decision.newScore)) analysisInvoked=\(decision.openedNewItem) firstTrustworthyMs=\(String(format: "%.3f", firstTrustworthyMs)) memoryMB=\(String(format: "%.1f", memMB)) thermal=\(Self.thermalString()) lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled) score=UNKNOWN match=\(matchState)")
        sp.endInterval("frame", spState)
    }

    override func broadcastFinished() {
        let s = frameDurationsNs.map { Double($0) / 1_000_000 }.sorted()
        let p50 = s.isEmpty ? 0 : s[s.count/2], p95 = s.isEmpty ? 0 : s[min(s.count-1, Int(Double(s.count)*0.95))]
        emit(String(format: "BROADCAST_FINISHED frames=%d changes=%d analyzed=%d heavy=%d reuse=%d shots=%d items=%d cheapP50ms=%.3f cheapP95ms=%.3f peakMemoryMB=%.1f thermal=%@ shotPolicy=%@ groupingPolicy=%@",
                    stats.framesProcessed, stats.contentChanges, stats.contentsAnalyzed, stats.heavyAnalysisRuns, stats.cacheReuse,
                    shotSegmenter.shotCount, itemGrouper.confirmedOrProvisionalItemCount,
                    p50, p95, peakMemoryMB, Self.thermalString(), shotSegmenter.policyRevision, itemGrouper.policy.revision))
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

    // Unified log + append to the extension container (pullable) — derived text only, NEVER a frame.
    private func emit(_ s: String) {
        log.notice("\(s, privacy: .public)")
        let line = "GEN8_CA \(s)\n"
        if let dir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            let url = dir.appendingPathComponent("gen8_crossapp_proof.log")
            if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
            else { try? line.data(using: .utf8)?.write(to: url) }
        }
    }
}
