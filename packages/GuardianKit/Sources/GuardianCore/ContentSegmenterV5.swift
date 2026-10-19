import Foundation

// MARK: - PROMPT 008A-R4 — Device-calibrated content segmentation V5 (sensor-layer closeout).
// Fixes the V4 residual over-detection (73/~20 on device): (1) REMOVE the swipe "relief" (a swipe cue could
// lower the confirm bar) → coherent translation is now SUPPORTING evidence through TemporalSwipeGateV1, never a
// discount; (2) explicit PAN-vs-SWIPE (pan = continuous evolution, no abrupt step → SAME_SEGMENT); (3) a
// regionalReplacementRatio requirement (a NEW segment must REPLACE content, not just evolve it); (4) TIME-based
// dwell/refractory (robust to variable ReplayKit cadence); (5) motion-normalized discontinuity V2 seeded from
// DeviceMotionProfileV2 (real on-device scale). No app-specific hacks, no private API, no raw media, deterministic.
// Reuses V4 primitives: SegmentFrameV4, MultiRegionSignature, RobustMotionBaseline, TemporalRegionReliabilityV1,
// CoherentTranslationV4.

public enum SegmentStateV5: String, Sendable, Codable {
    case sameSegment = "SAME_SEGMENT", intraSegmentMotion = "INTRA_SEGMENT_MOTION", panSameSegment = "PAN_SAME_SEGMENT"
    case overlayChange = "OVERLAY_CHANGE", transitionInProgress = "TRANSITION_IN_PROGRESS"
    case newSegmentConfirmed = "NEW_SEGMENT_CONFIRMED", ambiguous = "AMBIGUOUS"
}

public enum SegmentReasonV5: String, Sendable, Codable {
    case abruptCut = "ABRUPT_CUT", persistentContentReplacement = "PERSISTENT_CONTENT_REPLACEMENT"
    case swipeTransitionConfirmed = "SWIPE_TRANSITION_CONFIRMED", panSameSegment = "PAN_SAME_SEGMENT"
    case highMotionSameSegment = "HIGH_MOTION_SAME_SEGMENT", gradualTransition = "GRADUAL_TRANSITION"
    case appSurfaceTransition = "APP_SURFACE_TRANSITION", localOverlay = "LOCAL_OVERLAY"
    case insufficientReplacement = "INSUFFICIENT_REPLACEMENT", insufficientPostPersistence = "INSUFFICIENT_POST_PERSISTENCE"
    case minDwellNotMet = "MIN_DWELL_NOT_MET", ambiguous = "AMBIGUOUS"
}

public enum SwipeGateStateV1: String, Sendable, Codable {
    case noSwipe = "NO_SWIPE", possibleSwipe = "POSSIBLE_SWIPE", swipeTransitionConfirmed = "SWIPE_TRANSITION_CONFIRMED"
}

// MARK: - §7 device motion profile V2 (unbiased ranges; no reconstructive content).

public struct DeviceMotionProfileV2: Sendable, Codable, Equatable {
    public var revision: String
    public var source: String
    public var lowMotionMedian: Double
    public var highMotionP95: Double
    public var panningMedian: Double          // sustained coherent motion within one item
    public var swipeTranslationMedian: Double  // true feed-swipe translation magnitude
    public var cutDistanceMedian: Double
    public var overlayLocalMedian: Double
    public var onDeviceMotionScaleMedian: Double   // robust scale observed on device (the V4 correction)
    public var onDeviceMotionScaleP95: Double
    public var frameIntervalMsMedian: Double
    public var postPersistenceMsMedian: Double
    public init(revision: String, source: String, lowMotionMedian: Double, highMotionP95: Double, panningMedian: Double,
                swipeTranslationMedian: Double, cutDistanceMedian: Double, overlayLocalMedian: Double,
                onDeviceMotionScaleMedian: Double, onDeviceMotionScaleP95: Double, frameIntervalMsMedian: Double,
                postPersistenceMsMedian: Double) {
        self.revision = revision; self.source = source; self.lowMotionMedian = lowMotionMedian
        self.highMotionP95 = highMotionP95; self.panningMedian = panningMedian
        self.swipeTranslationMedian = swipeTranslationMedian; self.cutDistanceMedian = cutDistanceMedian
        self.overlayLocalMedian = overlayLocalMedian; self.onDeviceMotionScaleMedian = onDeviceMotionScaleMedian
        self.onDeviceMotionScaleP95 = onDeviceMotionScaleP95; self.frameIntervalMsMedian = frameIntervalMsMedian
        self.postPersistenceMsMedian = postPersistenceMsMedian
    }
    /// v2 (partial): corrects V1's key bias using the REAL on-device robust scale observed in the V4 run
    /// (commit-point scale p50 0.067, p95 0.119, max 0.133) + the V3 distance-distribution shape. A scripted
    /// UNBIASED per-frame calibration run (§6, via the new GEN8_EVIDENCE_BUILD telemetry) will refine this to v2.1.
    public static let v2 = DeviceMotionProfileV2(
        revision: "device-motion-profile-v2-partial",
        source: "on-device scale from P008A_R3_AFTER_crossapp_device_v4.log (p50 0.067/p95 0.119) + V3 distance shape; derived-only, no raw media; scripted per-frame calibration pending (§6)",
        lowMotionMedian: 0.05, highMotionP95: 0.26, panningMedian: 0.10, swipeTranslationMedian: 0.30,
        cutDistanceMedian: 0.37, overlayLocalMedian: 0.20, onDeviceMotionScaleMedian: 0.067, onDeviceMotionScaleP95: 0.119,
        frameIntervalMsMedian: 33.0, postPersistenceMsMedian: 120.0)
}

// MARK: - §15/§19 versioned frozen policy (time-based; no magic constants in SampleHandler).

public struct ContentBoundaryPolicyV5: Sendable, Codable, Equatable {
    public var revision: String
    // robust motion baseline (§11) — ranges seeded from DeviceMotionProfileV2
    public var mediumWindow: Int
    public var veryShortWindow: Int
    public var madK: Double
    public var minMotionScale: Double
    public var maxMotionScale: Double
    public var baselineReseedCount: Int
    public var warmupFrames: Int
    // OPEN — abrupt STEP (pan filter: a pan is smooth → no single large step)
    public var openStepRatio: Double        // max single inter-frame step ÷ scale to OPEN
    public var absoluteSafetyFloor: Double
    // CONFIRM — motion-normalized discontinuity + replacement + persistence (§10/§11)
    public var confirmMotionRatio: Double   // prePost ÷ max(scale, withinPre, withinPost)
    public var minReplacementRatio: Double  // §10 fraction of reliable regions REPLACED
    public var replacementRegionThreshold: Double  // per-region distance to count as "replaced"
    public var postCoherenceFraction: Double        // POST settled: withinPost ≤ frac·prePost
    public var centerTransitionFloor: Double
    // TIME-based dwell/refractory (§8) — robust to cadence
    public var postPersistenceMs: Double
    public var minSegmentDwellMs: Double     // refractory (time)
    public var maxTransitionMs: Double       // POST must settle within this real time, else → pan/intra
    // §10 overlay
    public var overlayMaxRegions: Int
    public var centerStableFraction: Double
    public var reliabilityAlpha: Double
    public var reliabilityFloor: Double
    // §3 TemporalSwipeGateV1 — supporting evidence only
    public var coherentPeak: Double
    public var coherentMinOffset: Int
    public var swipeDirectionConsistency: Double   // fraction of POST frames translating the same way
    public init(revision: String = "boundary-policy-v5",
                mediumWindow: Int = 40, veryShortWindow: Int = 3, madK: Double = 1.4,
                minMotionScale: Double = 0.03, maxMotionScale: Double = 0.45, baselineReseedCount: Int = 8, warmupFrames: Int = 5,
                openStepRatio: Double = 1.8, absoluteSafetyFloor: Double = 0.14,
                confirmMotionRatio: Double = 1.6, minReplacementRatio: Double = 0.6, replacementRegionThreshold: Double = 0.20,
                postCoherenceFraction: Double = 0.55, centerTransitionFloor: Double = 0.12,
                postPersistenceMs: Double = 66, minSegmentDwellMs: Double = 220, maxTransitionMs: Double = 400,
                overlayMaxRegions: Int = 2, centerStableFraction: Double = 1.0, reliabilityAlpha: Double = 0.1, reliabilityFloor: Double = 0.15,
                coherentPeak: Double = 0.7, coherentMinOffset: Int = 1, swipeDirectionConsistency: Double = 0.6) {
        self.revision = revision; self.mediumWindow = mediumWindow; self.veryShortWindow = veryShortWindow; self.madK = madK
        self.minMotionScale = minMotionScale; self.maxMotionScale = maxMotionScale; self.baselineReseedCount = baselineReseedCount
        self.warmupFrames = warmupFrames; self.openStepRatio = openStepRatio; self.absoluteSafetyFloor = absoluteSafetyFloor
        self.confirmMotionRatio = confirmMotionRatio; self.minReplacementRatio = minReplacementRatio
        self.replacementRegionThreshold = replacementRegionThreshold; self.postCoherenceFraction = postCoherenceFraction
        self.centerTransitionFloor = centerTransitionFloor; self.postPersistenceMs = postPersistenceMs
        self.minSegmentDwellMs = minSegmentDwellMs; self.maxTransitionMs = maxTransitionMs
        self.overlayMaxRegions = overlayMaxRegions; self.centerStableFraction = centerStableFraction
        self.reliabilityAlpha = reliabilityAlpha; self.reliabilityFloor = reliabilityFloor
        self.coherentPeak = coherentPeak; self.coherentMinOffset = coherentMinOffset; self.swipeDirectionConsistency = swipeDirectionConsistency
    }
    /// FROZEN on TUNE only (see P008A_R4_TUNE_RESULTS). Used for HELD-OUT / STRESS / CADENCE-STRESS / device.
    public static let frozenV5 = ContentBoundaryPolicyV5()
}

public struct SegmentEventV5: Sendable, Equatable {
    public let state: SegmentStateV5
    public let committedNew: Bool
    public let segmentSequence: Int
    public let motionEnergy: Double
    public let motionScale: Double
    public let normalizedDiscontinuity: Double
    public let replacementRatio: Double
    public let postPersistenceMs: Double
    public let swipeGate: SwipeGateStateV1
    public let reasons: [SegmentReasonV5]
    public let confidence: Double
    public let policyRevision: String
}

// MARK: - §3 temporal swipe gate: coherent translation is SUPPORTING evidence, never a confirm discount.

public struct TemporalSwipeGateV1 {
    public struct Inputs {
        public var rowCorr: Double, rowOffset: Int, colCorr: Double, colOffset: Int
        public var directionConsistency: Double
        public var prePostDiscontinuity: Double
        public var postPersistenceMs: Double, minPersistenceMs: Double
        public var replacementRatio: Double, minReplacement: Double
        public init(rowCorr: Double, rowOffset: Int, colCorr: Double, colOffset: Int, directionConsistency: Double,
                    prePostDiscontinuity: Double, postPersistenceMs: Double, minPersistenceMs: Double,
                    replacementRatio: Double, minReplacement: Double) {
            self.rowCorr = rowCorr; self.rowOffset = rowOffset; self.colCorr = colCorr; self.colOffset = colOffset
            self.directionConsistency = directionConsistency; self.prePostDiscontinuity = prePostDiscontinuity
            self.postPersistenceMs = postPersistenceMs; self.minPersistenceMs = minPersistenceMs
            self.replacementRatio = replacementRatio; self.minReplacement = minReplacement
        }
    }
    public static func evaluate(_ i: Inputs, policy: ContentBoundaryPolicyV5) -> SwipeGateStateV1 {
        let translated = (i.rowCorr >= policy.coherentPeak && abs(i.rowOffset) >= policy.coherentMinOffset)
                      || (i.colCorr >= policy.coherentPeak && abs(i.colOffset) >= policy.coherentMinOffset)
        guard translated && i.directionConsistency >= policy.swipeDirectionConsistency else { return .noSwipe }
        // A swipe translates AND lands on a new persistent state (replacement + persistence). Translation alone
        // (e.g. a pan) only reaches POSSIBLE_SWIPE and can NEVER by itself confirm a new segment (§2 relief removal).
        if i.replacementRatio >= i.minReplacement && i.postPersistenceMs >= i.minPersistenceMs { return .swipeTransitionConfirmed }
        return .possibleSwipe
    }
}

// MARK: - §15 evidence accumulator V5. Bounded O(1). Time-based. Reuses V4 baseline + reliability.

public final class BoundaryEvidenceAccumulatorV5: @unchecked Sendable {
    public let policy: ContentBoundaryPolicyV5
    private let lock = NSLock()
    private let baseline: RobustMotionBaseline
    private let reliability: TemporalRegionReliabilityV1

    private var recent: [SegmentFrameV4] = []
    private var recentMs: [Double] = []
    private var stepMotions: [Double] = []     // inter-frame motions (very-short window) for the abrupt-STEP test
    private var segmentSequence = 0
    private var lastCommitMs = -1e9

    private var inTransition = false
    private var preRef: SegmentFrameV4?
    private var preWindow: [SegmentFrameV4] = []
    private var postBuf: [SegmentFrameV4] = []
    private var postMotions: [Double] = []
    private var postOffsets: [Int] = []
    private var transitionStartMs = 0.0

    public init(policy: ContentBoundaryPolicyV5 = .init()) {
        self.policy = policy
        self.baseline = RobustMotionBaseline(capacity: policy.mediumWindow)
        self.reliability = TemporalRegionReliabilityV1(alpha: policy.reliabilityAlpha, floor: policy.reliabilityFloor)
    }
    public var committedSegmentCount: Int { lock.lock(); defer { lock.unlock() }; return segmentSequence }
    public func reset() {
        lock.lock(); recent = []; recentMs = []; stepMotions = []; segmentSequence = 0; lastCommitMs = -1e9
        inTransition = false; preRef = nil; preWindow = []; postBuf = []; postMotions = []; postOffsets = []; transitionStartMs = 0
        reliability.reset(); lock.unlock()
    }
    private func pushRecent(_ f: SegmentFrameV4, _ ms: Double) {
        recent.append(f); recentMs.append(ms)
        if recent.count > policy.mediumWindow { recent.removeFirst(); recentMs.removeFirst() }
    }
    private func distance(_ a: SegmentFrameV4, _ b: SegmentFrameV4) -> Double {
        let d = a.regions.distances(to: b.regions); let w = reliability.weights()
        let contentNum = w.center*d.center + w.global*d.global + w.left*d.left + w.right*d.right
        let chromeNum = w.top*d.top + w.bottom*d.bottom
        let num = contentNum + chromeNum + 0.25*d.histogram
        let den = w.center + w.global + w.top + w.bottom + w.left + w.right + 0.25
        return num / max(1e-6, den)
    }
    // §10 fraction of reliability-weighted regions REPLACED (PRE→POST per-region distance ≥ threshold).
    private func replacementRatio(_ pre: SegmentFrameV4, _ post: SegmentFrameV4) -> Double {
        let d = post.regions.distances(to: pre.regions); let w = reliability.weights()
        let regions = [(d.center,w.center),(d.global,w.global),(d.top,w.top),(d.bottom,w.bottom),(d.left,w.left),(d.right,w.right)]
        var repl = 0.0, tot = 0.0
        for (dist, wt) in regions { tot += wt; if dist >= policy.replacementRegionThreshold { repl += wt } }
        return repl / max(1e-6, tot)
    }
    private func medianConsecutive(_ a: [SegmentFrameV4]) -> Double {
        guard a.count > 1 else { return 0 }
        var ds: [Double] = []; for i in 1..<a.count { ds.append(distance(a[i], a[i-1])) }
        return ds.sorted()[ds.count/2]
    }

    public func process(_ f: SegmentFrameV4, timestampMs: Double) -> SegmentEventV5 {
        lock.lock(); defer { lock.unlock() }
        guard let last = recent.last else {
            pushRecent(f, timestampMs); segmentSequence = 1; lastCommitMs = timestampMs
            baseline.seed(policy.minMotionScale, times: 2)
            return event(.newSegmentConfirmed, true, 0, policy.minMotionScale, 0, 0, 0, .noSwipe, [.persistentContentReplacement], 1)
        }
        reliability.update(f.regions.distances(to: last.regions))
        let energy = distance(f, last)
        let scale = baseline.scale(madK: policy.madK, minScale: policy.minMotionScale, maxScale: policy.maxMotionScale)
        // very-short-window MAX single inter-frame step (pan filter: a pan is smooth → small max step).
        stepMotions.append(energy); if stepMotions.count > policy.veryShortWindow { stepMotions.removeFirst() }
        let maxStep = stepMotions.max() ?? energy
        let warm = baseline.count >= policy.warmupFrames
        let lagIdx = max(0, recent.count - 1 - policy.veryShortWindow)
        let lagFrame = recent[lagIdx]

        if !inTransition {
            baseline.update(energy)
            if isOverlay(f.regions.distances(to: last.regions), scale: scale) {
                pushRecent(f, timestampMs)
                return event(.overlayChange, false, energy, scale, 0, 0, 0, .noSwipe, [.localOverlay], 0.6)
            }
            // OPEN only on a genuine abrupt STEP that is a SPIKE above the typical recent motion (continuity break).
            // A pan or sustained high motion has ~uniform inter-frame steps (no spike) → stepSpike ≈ 1 → no open.
            // A cut/swipe is one isolated large step over small neighbours → stepSpike ≫ 1. This is the pan filter.
            let typicalStep = max(policy.minMotionScale, baseline.median())
            let stepSpike = maxStep / typicalStep
            if warm && stepSpike >= policy.openStepRatio && maxStep >= policy.absoluteSafetyFloor {
                inTransition = true; preRef = lagFrame; preWindow = Array(recent.suffix(max(2, policy.veryShortWindow)))
                postBuf = [f]; postMotions = []; postOffsets = []; transitionStartMs = timestampMs
                pushRecent(f, timestampMs)
                return event(.transitionInProgress, false, energy, scale, maxStep/max(1e-6,scale), 0, 0, .possibleSwipe, [], 0.3)
            }
            pushRecent(f, timestampMs)
            let intra = energy > scale
            return event(intra ? .intraSegmentMotion : .sameSegment, false, energy, scale, maxStep/max(1e-6,scale), 0, 0,
                         .noSwipe, intra ? [.highMotionSameSegment] : [], intra ? 0.5 : 0.8)
        }

        // ---- TRANSITION_IN_PROGRESS ----
        if let lp = postBuf.last {
            postMotions.append(distance(f, lp))
            let rt = CoherentTranslationV4.score(lp.rowProjection, f.rowProjection, maxOffset: lp.rowProjection.count/2)
            postOffsets.append(rt.offset)
        }
        postBuf.append(f); pushRecent(f, timestampMs)
        let elapsedMs = timestampMs - transitionStartMs

        let pre = preRef ?? lagFrame
        let postRep = postBuf.last ?? f
        let preW = preWindow.isEmpty ? [pre] : preWindow
        let withinPre = medianConsecutive(preW)
        let withinPost = postMotions.isEmpty ? 0 : postMotions.sorted()[postMotions.count/2]
        let between = postBuf.map { pf -> Double in let ds = preW.map { distance(pf, $0) }.sorted(); return ds[ds.count/2] }.sorted()
        let prePostDistance = between.isEmpty ? 0 : between[between.count/2]
        let localMotion = max(scale, max(withinPre, withinPost))
        let ratio = prePostDistance / max(1e-6, localMotion)
        let replaced = replacementRatio(pre, postRep)
        let coherent = withinPost <= policy.postCoherenceFraction * max(1e-6, prePostDistance)
        let centerMoved = pre.regions.distances(to: postRep.regions).center >= policy.centerTransitionFloor
        // swipe gate (supporting only)
        let rc = CoherentTranslationV4.score(pre.rowProjection, postRep.rowProjection, maxOffset: pre.rowProjection.count/2)
        let cc = CoherentTranslationV4.score(pre.colProjection, postRep.colProjection, maxOffset: pre.colProjection.count/2)
        let dirConsistency = directionConsistency()
        let gate = TemporalSwipeGateV1.evaluate(.init(rowCorr: rc.peak, rowOffset: rc.offset, colCorr: cc.peak, colOffset: cc.offset,
            directionConsistency: dirConsistency, prePostDiscontinuity: prePostDistance, postPersistenceMs: elapsedMs,
            minPersistenceMs: policy.postPersistenceMs, replacementRatio: replaced, minReplacement: policy.minReplacementRatio), policy: policy)

        let persistedEnough = elapsedMs >= policy.postPersistenceMs
        let dwellOK = (timestampMs - lastCommitMs) >= policy.minSegmentDwellMs
        let replacementOK = replaced >= policy.minReplacementRatio
        let discontinuityOK = ratio >= policy.confirmMotionRatio
        // CONFIRM: persistent content REPLACEMENT with discontinuity, settled POST, content moved, min dwell.
        // Swipe is supporting (adds confidence + reason) but can NEVER substitute for replacement+discontinuity.
        if persistedEnough && replacementOK && discontinuityOK && coherent && centerMoved && dwellOK {
            var reasons: [SegmentReasonV5] = [.persistentContentReplacement]
            let abrupt = prePostDistance >= 0.6 * DeviceMotionProfileV2.v2.cutDistanceMedian
            if gate == .swipeTransitionConfirmed { reasons.append(.swipeTransitionConfirmed) }
            else if abrupt { reasons.append(.abruptCut) } else { reasons.append(.gradualTransition) }
            let conf = min(1, 0.55 + 0.45 * (ratio - policy.confirmMotionRatio) / max(0.5, policy.confirmMotionRatio))
            return commit(postRep, timestampMs, energy: energy, scale: scale, ratio: ratio, replaced: replaced,
                          persistMs: elapsedMs, gate: gate, reasons: reasons, confidence: conf)
        }
        if elapsedMs >= policy.maxTransitionMs {
            // POST never settled into a replaced persistent state within the time budget. If translation was
            // sustained & directionally consistent → PAN; else → intra-segment motion. Either way NO commit.
            let sustainedTranslation = dirConsistency >= policy.swipeDirectionConsistency && withinPost > scale
            let st: SegmentStateV5 = sustainedTranslation ? .panSameSegment : .intraSegmentMotion
            let reason: SegmentReasonV5 = sustainedTranslation ? .panSameSegment
                : (!replacementOK ? .insufficientReplacement : .insufficientPostPersistence)
            inTransition = false; preRef = nil; preWindow = []; postBuf = []; postMotions = []; postOffsets = []
            baseline.update(withinPost); baseline.update(energy)
            return event(st, false, energy, scale, ratio, replaced, elapsedMs, gate, [reason], 0.4)
        }
        if replacementOK && discontinuityOK && coherent && centerMoved && !dwellOK {
            return event(.transitionInProgress, false, energy, scale, ratio, replaced, elapsedMs, gate, [.minDwellNotMet], 0.35)
        }
        return event(.transitionInProgress, false, energy, scale, ratio, replaced, elapsedMs, gate,
                     replacementOK ? [] : [.insufficientReplacement], 0.35)
    }

    private func directionConsistency() -> Double {
        guard !postOffsets.isEmpty else { return 0 }
        let pos = postOffsets.filter { $0 > 0 }.count, neg = postOffsets.filter { $0 < 0 }.count
        return Double(max(pos, neg)) / Double(postOffsets.count)
    }
    private func isOverlay(_ d: MultiRegionSignature.RegionDistances, scale: Double) -> Bool {
        let jumped = [d.top, d.bottom, d.left, d.right, d.global].filter { $0 >= max(0.18, 2*scale) }.count
        return d.center <= policy.centerStableFraction * scale && jumped >= 1 && jumped <= policy.overlayMaxRegions
    }
    private func commit(_ post: SegmentFrameV4, _ ms: Double, energy: Double, scale: Double, ratio: Double, replaced: Double,
                        persistMs: Double, gate: SwipeGateStateV1, reasons: [SegmentReasonV5], confidence: Double) -> SegmentEventV5 {
        segmentSequence += 1; lastCommitMs = ms
        inTransition = false; preRef = nil; preWindow = []; postBuf = []; postMotions = []; postOffsets = []
        recent = [post]; recentMs = [ms]; stepMotions = []
        baseline.seed(scale, times: policy.baselineReseedCount)
        return event(.newSegmentConfirmed, true, energy, scale, ratio, replaced, persistMs, gate, reasons, confidence)
    }
    private func event(_ s: SegmentStateV5, _ c: Bool, _ e: Double, _ sc: Double, _ nd: Double, _ rr: Double, _ pp: Double,
                       _ g: SwipeGateStateV1, _ r: [SegmentReasonV5], _ conf: Double) -> SegmentEventV5 {
        SegmentEventV5(state: s, committedNew: c, segmentSequence: segmentSequence, motionEnergy: e, motionScale: sc,
                       normalizedDiscontinuity: nd, replacementRatio: rr, postPersistenceMs: pp, swipeGate: g,
                       reasons: r, confidence: conf, policyRevision: policy.revision)
    }
}
