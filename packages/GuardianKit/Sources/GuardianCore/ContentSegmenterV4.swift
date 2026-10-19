import Foundation

// MARK: - PROMPT 008A-R3 — Motion-normalized content segmentation V4.
// Problem reformulation (§2): not "did THIS frame change enough?" but "did the stream enter a NEW
// PERSISTENT content segment?". A Reel/video is a temporal segment; normal motion inside it is NOT a
// boundary. V3 failed on-device (477 commits / ~20 items) because it used an ABSOLUTE change floor and
// EXCLUDED motion frames from the baseline, so the baseline never learned real motion. V4 fixes this:
//   LEARN motion (robust baseline over ALL eligible frames) → measure discontinuity RELATIVE to motion
//   → confirm a NEW PERSISTENT state (PRE/POST persistence) → keep compute bounded, raw content private.
// No app-specific hacks, no private API, no hardcoded pixel coordinates, no raw media, deterministic.

// MARK: Canonical outputs (§2)

public enum SegmentStateV4: String, Sendable, Codable {
    case sameSegment = "SAME_SEGMENT"
    case intraSegmentMotion = "INTRA_SEGMENT_MOTION"
    case overlayChange = "OVERLAY_CHANGE"
    case transitionInProgress = "TRANSITION_IN_PROGRESS"
    case newSegmentConfirmed = "NEW_SEGMENT_CONFIRMED"
    case ambiguous = "AMBIGUOUS"
}

// §12 compact derived reason codes (engineering evidence, not user UI).
public enum SegmentReasonV4: String, Sendable, Codable {
    case prePostPersistentDiscontinuity = "PRE_POST_PERSISTENT_DISCONTINUITY"
    case coherentSwipe = "COHERENT_SWIPE"
    case abruptCut = "ABRUPT_CUT"
    case gradualNewSegment = "GRADUAL_NEW_SEGMENT"
    case appSurfaceTransition = "APP_SURFACE_TRANSITION"
    case localOverlayOnly = "LOCAL_OVERLAY_ONLY"
    case highMotionSameSegment = "HIGH_MOTION_SAME_SEGMENT"
    case insufficientPostPersistence = "INSUFFICIENT_POST_PERSISTENCE"
    case refractoryWeak = "REFRACTORY_WEAK"
    case ambiguous = "AMBIGUOUS"
}

// §8 legitimate transition modes.
public enum TransitionModeV4: String, Sendable, Codable {
    case cut = "CUT", scrollSwipe = "SCROLL_SWIPE", crossfadeAutoplay = "CROSSFADE_AUTOPLAY"
    case appSurface = "APP_SURFACE", overlay = "OVERLAY", none = "NONE"
}

// MARK: - §3/§9 frame feature: multi-region signature + small bounded row/col luma projections.

public struct SegmentFrameV4: Sendable, Equatable {
    public var regions: MultiRegionSignature
    public var rowProjection: [Double]   // normalized 0..1 luma per horizontal band (for vertical scroll)
    public var colProjection: [Double]   // normalized 0..1 luma per vertical band (for horizontal swipe)
    public init(regions: MultiRegionSignature, rowProjection: [Double], colProjection: [Double]) {
        self.regions = regions; self.rowProjection = rowProjection; self.colProjection = colProjection
    }
}

// Cheap coherent-translation cue (§9): normalized cross-correlation of a projection vector across small
// offsets; a strong peak at a non-zero offset ≈ a coherent scroll/swipe translation. Supporting evidence only.
public enum CoherentTranslationV4 {
    public static func score(_ a: [Double], _ b: [Double], maxOffset: Int) -> (peak: Double, offset: Int) {
        guard a.count == b.count, a.count > 2 else { return (0, 0) }
        func corr(_ x: ArraySlice<Double>, _ y: ArraySlice<Double>) -> Double {
            let n = min(x.count, y.count); guard n > 1 else { return 0 }
            let xs = Array(x.prefix(n)), ys = Array(y.prefix(n))
            let mx = xs.reduce(0,+)/Double(n), my = ys.reduce(0,+)/Double(n)
            var num = 0.0, dx = 0.0, dy = 0.0
            for i in 0..<n { let a0 = xs[i]-mx, b0 = ys[i]-my; num += a0*b0; dx += a0*a0; dy += b0*b0 }
            let den = (dx*dy).squareRoot()
            return den <= 1e-9 ? 0 : num/den
        }
        var best = corr(a[...], b[...]); var bestOff = 0
        let lim = min(maxOffset, a.count - 2)
        if lim >= 1 {
            for off in 1...lim {
                let c1 = corr(a[off...], b[..<(b.count-off)])   // b shifted one way
                let c2 = corr(a[..<(a.count-off)], b[off...])   // b shifted the other way
                if c1 > best { best = c1; bestOff = off }
                if c2 > best { best = c2; bestOff = -off }
            }
        }
        return (max(0, best), bestOff)
    }
}

// MARK: - §13/§14 device-derived motion profile (derived-only; no raw media / content).

public struct DeviceMotionProfileV1: Sendable, Codable, Equatable {
    public var revision: String
    public var source: String
    public var sameItemMotionMedian: Double
    public var sameItemMotionP75: Double
    public var sameItemMotionP95: Double
    public var sameItemMotionMax: Double
    public var highMotionP95: Double
    public var transitionDistanceMin: Double
    public var transitionDistanceMedian: Double
    public var transitionDistanceP95: Double
    public var transitionDistanceMax: Double
    public var typicalMotionScale: Double
    public var transitionToMotionRatio: Double
    public init(revision: String, source: String, sameItemMotionMedian: Double, sameItemMotionP75: Double,
                sameItemMotionP95: Double, sameItemMotionMax: Double, highMotionP95: Double,
                transitionDistanceMin: Double, transitionDistanceMedian: Double, transitionDistanceP95: Double,
                transitionDistanceMax: Double, typicalMotionScale: Double, transitionToMotionRatio: Double) {
        self.revision = revision; self.source = source
        self.sameItemMotionMedian = sameItemMotionMedian; self.sameItemMotionP75 = sameItemMotionP75
        self.sameItemMotionP95 = sameItemMotionP95; self.sameItemMotionMax = sameItemMotionMax
        self.highMotionP95 = highMotionP95; self.transitionDistanceMin = transitionDistanceMin
        self.transitionDistanceMedian = transitionDistanceMedian; self.transitionDistanceP95 = transitionDistanceP95
        self.transitionDistanceMax = transitionDistanceMax; self.typicalMotionScale = typicalMotionScale
        self.transitionToMotionRatio = transitionToMotionRatio
    }
    /// Bootstrap v0 derived from the 477 V3 commit-point D values (derived-only telemetry, no raw media).
    /// within-item (strong=false,n=411): med 0.123 p75 0.169 p95 0.257 max 0.392; cut-like (strong=true,n=66):
    /// med 0.370 min 0.301 p95 0.472 max 0.573; ratio ≈ 3.0. A scripted calibration run (§24) refines this.
    public static let bootstrapV0 = DeviceMotionProfileV1(
        revision: "device-motion-profile-bootstrap-v0",
        source: "derived from P008A_R2_AFTER_crossapp_device_v3.log commit-point D (biased ≥0.07; no raw media)",
        sameItemMotionMedian: 0.123, sameItemMotionP75: 0.169, sameItemMotionP95: 0.257, sameItemMotionMax: 0.392,
        highMotionP95: 0.257, transitionDistanceMin: 0.301, transitionDistanceMedian: 0.370,
        transitionDistanceP95: 0.472, transitionDistanceMax: 0.573,
        typicalMotionScale: 0.123, transitionToMotionRatio: 3.01)
}

// MARK: - §4 robust bounded motion baseline that LEARNS motion (incl. sustained high motion).

final class RobustMotionBaseline {
    private var buf: [Double] = []
    let capacity: Int
    init(capacity: Int) { self.capacity = max(4, capacity) }
    var count: Int { buf.count }
    func update(_ v: Double) { buf.append(max(0, v)); if buf.count > capacity { buf.removeFirst() } }
    func seed(_ v: Double, times: Int) { for _ in 0..<max(1, times) { update(v) } }
    func median() -> Double {
        guard !buf.isEmpty else { return 0 }
        let s = buf.sorted(); let n = s.count
        return n % 2 == 1 ? s[n/2] : (s[n/2 - 1] + s[n/2]) / 2
    }
    func mad() -> Double {   // median absolute deviation
        guard !buf.isEmpty else { return 0 }
        let m = median(); let dev = buf.map { abs($0 - m) }.sorted(); let n = dev.count
        return n % 2 == 1 ? dev[n/2] : (dev[n/2 - 1] + dev[n/2]) / 2
    }
    func trimmedMean(trim: Double) -> Double {
        guard !buf.isEmpty else { return 0 }
        let s = buf.sorted(); let k = Int(Double(s.count) * min(0.49, max(0, trim)))
        let lo = k, hi = s.count - k; guard hi > lo else { return median() }
        let slice = s[lo..<hi]; return slice.reduce(0,+) / Double(slice.count)
    }
    /// Robust motion scale: median + madK·MAD, bounded. This is the denominator for motion-normalized jumps.
    func scale(madK: Double, minScale: Double, maxScale: Double) -> Double {
        min(maxScale, max(minScale, median() + madK * mad()))
    }
}

// MARK: - §10 temporal region reliability (chrome persists → low transition influence; content → high).

public final class TemporalRegionReliabilityV1: @unchecked Sendable {
    // Per-region EMA of per-frame change. Regions that rarely change (chrome) get low reliability (floored),
    // dynamic content regions get high reliability. Never permanently discards edges.
    private var changeEMA: [Double]   // [center, global, top, bottom, left, right]
    private let alpha: Double
    private let floor: Double
    public init(alpha: Double = 0.1, floor: Double = 0.15) {
        self.changeEMA = [Double](repeating: 0.1, count: 6); self.alpha = alpha; self.floor = floor
    }
    public func update(_ d: MultiRegionSignature.RegionDistances) {
        let obs = [d.center, d.global, d.top, d.bottom, d.left, d.right]
        for i in 0..<6 { changeEMA[i] = (1 - alpha) * changeEMA[i] + alpha * obs[i] }
    }
    /// Reliability weight per region in [floor, 1], normalized so the most dynamic region ≈ 1.
    public func weights() -> (center: Double, global: Double, top: Double, bottom: Double, left: Double, right: Double) {
        let mx = max(changeEMA.max() ?? 1, 1e-6)
        let w = changeEMA.map { max(floor, $0 / mx) }
        return (w[0], w[1], w[2], w[3], w[4], w[5])
    }
    public func reset() { changeEMA = [Double](repeating: 0.1, count: 6) }
}

// MARK: - §18 versioned frozen policy (no magic constants in SampleHandler).

public struct ContentBoundaryPolicyV4: Sendable, Codable, Equatable {
    public var revision: String
    // multi-timescale windows (§7) — all bounded
    public var veryShortWindow: Int      // immediate motion
    public var shortWindow: Int          // transition confirmation (POST)
    public var mediumWindow: Int         // same-segment motion baseline
    // robust baseline (§4)
    public var madK: Double
    public var minMotionScale: Double    // safety floor only (NOT the primary rule, §6)
    public var maxMotionScale: Double
    public var baselineReseedCount: Int  // on commit: reseed (not clear) so scale never collapses
    public var warmupFrames: Int         // learn motion first; no OPEN until baseline has this many samples
    // motion-normalized discontinuity (§6)
    public var openNormalizedJump: Double     // relative multiple (abrupt/scale) to OPEN a candidate
    public var confirmNormalizedJump: Double   // (legacy, logged) relative multiple vs scale
    public var confirmMotionRatio: Double      // CONFIRM: PRE→POST distance ÷ max(scale, withinPre, withinPost)
    public var absoluteSafetyFloor: Double     // tiny guard vs near-zero-motion noise
    // pre/post persistence (§5)
    public var postPersistenceFrames: Int
    public var postCoherenceFraction: Double   // within-POST motion must be ≤ frac·prePostDistance
    public var maxTransitionFrames: Int        // POST must stabilize within this, else → intra-motion
    public var segRefAlpha: Double             // EMA update of the segment reference state
    // regional / overlay (§10)
    public var overlayMaxRegions: Int          // overlay = change confined to ≤ this many low-reliability regions
    public var centerStableFraction: Double    // overlay requires center change ≤ frac·scale
    public var reliabilityAlpha: Double
    public var reliabilityFloor: Double
    // coherent translation (§9)
    public var coherentPeak: Double
    public var coherentMinOffset: Int
    public var swipeConfirmRelief: Double      // coherent swipe lowers the confirm bar (supporting evidence)
    public var centerTransitionFloor: Double   // a NEW segment must move the CONTENT (center); overlays keep it stable
    // refractory / segment guards (§11)
    public var minSegmentFrames: Int
    public init(revision: String = "boundary-policy-v4",
                veryShortWindow: Int = 3, shortWindow: Int = 8, mediumWindow: Int = 40,
                madK: Double = 1.4, minMotionScale: Double = 0.05, maxMotionScale: Double = 0.45, baselineReseedCount: Int = 8,
                warmupFrames: Int = 5,
                openNormalizedJump: Double = 1.3, confirmNormalizedJump: Double = 1.7, confirmMotionRatio: Double = 1.6, absoluteSafetyFloor: Double = 0.16,
                postPersistenceFrames: Int = 2, postCoherenceFraction: Double = 0.6, maxTransitionFrames: Int = 10,
                segRefAlpha: Double = 0.1,
                overlayMaxRegions: Int = 2, centerStableFraction: Double = 1.0, reliabilityAlpha: Double = 0.1, reliabilityFloor: Double = 0.15,
                coherentPeak: Double = 0.7, coherentMinOffset: Int = 1, swipeConfirmRelief: Double = 0.4,
                centerTransitionFloor: Double = 0.1,
                minSegmentFrames: Int = 3) {
        self.revision = revision
        self.veryShortWindow = veryShortWindow; self.shortWindow = shortWindow; self.mediumWindow = mediumWindow
        self.madK = madK; self.minMotionScale = minMotionScale; self.maxMotionScale = maxMotionScale; self.baselineReseedCount = baselineReseedCount
        self.warmupFrames = warmupFrames
        self.openNormalizedJump = openNormalizedJump; self.confirmNormalizedJump = confirmNormalizedJump
        self.confirmMotionRatio = confirmMotionRatio; self.absoluteSafetyFloor = absoluteSafetyFloor
        self.postPersistenceFrames = postPersistenceFrames; self.postCoherenceFraction = postCoherenceFraction
        self.maxTransitionFrames = maxTransitionFrames; self.segRefAlpha = segRefAlpha
        self.overlayMaxRegions = overlayMaxRegions; self.centerStableFraction = centerStableFraction
        self.reliabilityAlpha = reliabilityAlpha; self.reliabilityFloor = reliabilityFloor
        self.coherentPeak = coherentPeak; self.coherentMinOffset = coherentMinOffset; self.swipeConfirmRelief = swipeConfirmRelief
        self.centerTransitionFloor = centerTransitionFloor
        self.minSegmentFrames = minSegmentFrames
    }
    /// FROZEN on TUNE only (see P008A_R3_TUNE_RESULTS). Used for HELD-OUT, STRESS, and device validation.
    public static let frozenV4 = ContentBoundaryPolicyV4()
}

public struct SegmentEventV4: Sendable, Equatable {
    public let state: SegmentStateV4
    public let committedNew: Bool
    public let segmentSequence: Int
    public let motionEnergy: Double
    public let motionScale: Double
    public let normalizedJump: Double
    public let postPersistence: Int
    public let transitionMode: TransitionModeV4
    public let reasons: [SegmentReasonV4]
    public let confidence: Double
    public let policyRevision: String
}

// MARK: - §11 evidence accumulator V4 = the segmenter state machine. Bounded O(1) memory.

public final class BoundaryEvidenceAccumulatorV4: @unchecked Sendable {
    public let policy: ContentBoundaryPolicyV4
    private let lock = NSLock()
    private let baseline: RobustMotionBaseline
    private let reliability: TemporalRegionReliabilityV1

    private var recent: [SegmentFrameV4] = []   // bounded ring of recent frames (continuity anchor + §7 timescales)
    private var segmentSequence = 0
    private var framesSinceCommit = Int.max

    // candidate / POST state
    private var inTransition = false
    private var preRef: SegmentFrameV4?
    private var preWindow: [SegmentFrameV4] = []    // §5 pre-change window (for within-PRE motion estimate)
    private var postBuf: [SegmentFrameV4] = []
    private var postMotions: [Double] = []
    private var transitionFrames = 0
    private var candidateMode: TransitionModeV4 = .none

    public init(policy: ContentBoundaryPolicyV4 = .init()) {
        self.policy = policy
        self.baseline = RobustMotionBaseline(capacity: policy.mediumWindow)
        self.reliability = TemporalRegionReliabilityV1(alpha: policy.reliabilityAlpha, floor: policy.reliabilityFloor)
    }
    public var committedSegmentCount: Int { lock.lock(); defer { lock.unlock() }; return segmentSequence }
    public func reset() {
        lock.lock(); recent = []; segmentSequence = 0; framesSinceCommit = Int.max
        inTransition = false; preRef = nil; preWindow = []; postBuf = []; postMotions = []; transitionFrames = 0; candidateMode = .none
        reliability.reset(); lock.unlock()
    }
    private func pushRecent(_ f: SegmentFrameV4) { recent.append(f); if recent.count > policy.mediumWindow { recent.removeFirst() } }

    // Reliability-weighted distance between two frames = MotionEnergy / SegmentDiscontinuity depending on refs.
    private func distance(_ a: SegmentFrameV4, _ b: SegmentFrameV4) -> Double {
        let d = a.regions.distances(to: b.regions)
        let w = reliability.weights()
        // content regions dominate; chrome regions floored but never zero. Histogram + global add scene change.
        let contentNum = w.center * d.center + w.global * d.global + w.left * d.left + w.right * d.right
        let chromeNum = w.top * d.top + w.bottom * d.bottom
        let num = contentNum + chromeNum + 0.25 * d.histogram
        let den = w.center + w.global + w.top + w.bottom + w.left + w.right + 0.25
        return num / max(1e-6, den)
    }

    private func classifyMode(_ pre: SegmentFrameV4, _ post: SegmentFrameV4, abrupt: Bool) -> (TransitionModeV4, Bool) {
        let rt = CoherentTranslationV4.score(pre.rowProjection, post.rowProjection, maxOffset: pre.rowProjection.count/2)
        let ct = CoherentTranslationV4.score(pre.colProjection, post.colProjection, maxOffset: pre.colProjection.count/2)
        let swipe = (rt.peak >= policy.coherentPeak && abs(rt.offset) >= policy.coherentMinOffset)
                 || (ct.peak >= policy.coherentPeak && abs(ct.offset) >= policy.coherentMinOffset)
        if swipe { return (.scrollSwipe, true) }
        if abrupt { return (.cut, false) }
        return (.crossfadeAutoplay, false)
    }

    private func isOverlay(_ d: MultiRegionSignature.RegionDistances, scale: Double) -> Bool {
        // Overlay = change confined to a few low-reliability (chrome) regions with the CENTER essentially stable.
        let jumped = [d.top, d.bottom, d.left, d.right, d.global].filter { $0 >= max(0.18, 2*scale) }.count
        let centerStable = d.center <= policy.centerStableFraction * scale
        return centerStable && jumped >= 1 && jumped <= policy.overlayMaxRegions
    }

    private func commit(_ post: SegmentFrameV4, reasons: [SegmentReasonV4], mode: TransitionModeV4,
                        energy: Double, scale: Double, normJump: Double, persistence: Int, confidence: Double) -> SegmentEventV4 {
        segmentSequence += 1; framesSinceCommit = 0
        inTransition = false; preRef = nil; preWindow = []; postBuf = []; postMotions = []; transitionFrames = 0; candidateMode = .none
        recent = [post]   // fresh continuity anchor for the NEW segment (no stale pre-cut frame)
        // Reseed (NOT clear) the motion baseline with the recent motion scale so it never collapses to the floor.
        baseline.seed(scale, times: policy.baselineReseedCount)
        return SegmentEventV4(state: .newSegmentConfirmed, committedNew: true, segmentSequence: segmentSequence,
                              motionEnergy: energy, motionScale: scale, normalizedJump: normJump, postPersistence: persistence,
                              transitionMode: mode, reasons: reasons, confidence: confidence, policyRevision: policy.revision)
    }

    public func process(_ f: SegmentFrameV4) -> SegmentEventV4 {
        lock.lock(); defer { lock.unlock() }
        framesSinceCommit = framesSinceCommit == Int.max ? Int.max : framesSinceCommit + 1
        guard let last = recent.last else {
            pushRecent(f); segmentSequence = 1; framesSinceCommit = 0
            baseline.seed(policy.minMotionScale, times: 2)
            return SegmentEventV4(state: .newSegmentConfirmed, committedNew: true, segmentSequence: 1, motionEnergy: 0,
                                  motionScale: policy.minMotionScale, normalizedJump: 0, postPersistence: 0,
                                  transitionMode: .none, reasons: [.prePostPersistentDiscontinuity], confidence: 1,
                                  policyRevision: policy.revision)
        }
        reliability.update(f.regions.distances(to: last.regions))
        let energy = distance(f, last)                         // §3 MotionEnergy (immediate, vs previous frame)
        let scale = baseline.scale(madK: policy.madK, minScale: policy.minMotionScale, maxScale: policy.maxMotionScale)
        // §7 very-short-window ABRUPT change: compare to a frame a few back. Smooth motion / panning has
        // temporal continuity → small over a short window; a CUT spikes. This is the continuity filter.
        let lagIdx = max(0, recent.count - 1 - policy.veryShortWindow)
        let lagFrame = recent[lagIdx]
        let abruptChange = distance(f, lagFrame)
        let normAbrupt = abruptChange / max(1e-6, scale)       // §6 motion-NORMALIZED discontinuity
        let warm = baseline.count >= policy.warmupFrames

        if !inTransition {
            baseline.update(energy)                            // §4 ALWAYS learn motion (incl. sustained) — THE V3 FIX
            // §10 overlay: localized chrome change with a stable center → never a segment change.
            if isOverlay(f.regions.distances(to: last.regions), scale: scale) {
                pushRecent(f)
                return SegmentEventV4(state: .overlayChange, committedNew: false, segmentSequence: segmentSequence,
                                      motionEnergy: energy, motionScale: scale, normalizedJump: normAbrupt,
                                      postPersistence: 0, transitionMode: .overlay, reasons: [.localOverlayOnly],
                                      confidence: 0.6, policyRevision: policy.revision)
            }
            // overlay can look "abrupt" vs a lagged frame (it has been ON for a few frames); suppress it.
            let abruptIsOverlay = isOverlay(f.regions.distances(to: lagFrame.regions), scale: scale)
            if warm && !abruptIsOverlay && normAbrupt >= policy.openNormalizedJump && abruptChange >= policy.absoluteSafetyFloor {
                // open a candidate: PRE = the pre-change (lagged) frame + a short pre-window, begin POST window
                inTransition = true; preRef = lagFrame; preWindow = Array(recent.suffix(max(2, policy.veryShortWindow)))
                postBuf = [f]; postMotions = []; transitionFrames = 1
                candidateMode = classifyMode(lagFrame, f, abrupt: abruptChange >= 0.6 * policy.transitionAbruptHint).0
                pushRecent(f)
                return SegmentEventV4(state: .transitionInProgress, committedNew: false, segmentSequence: segmentSequence,
                                      motionEnergy: energy, motionScale: scale, normalizedJump: normAbrupt, postPersistence: 1,
                                      transitionMode: candidateMode, reasons: [], confidence: 0.3, policyRevision: policy.revision)
            }
            pushRecent(f)
            let intra = energy > scale
            return SegmentEventV4(state: intra ? .intraSegmentMotion : .sameSegment, committedNew: false,
                                  segmentSequence: segmentSequence, motionEnergy: energy, motionScale: scale,
                                  normalizedJump: normAbrupt, postPersistence: 0, transitionMode: .none,
                                  reasons: intra ? [.highMotionSameSegment] : [], confidence: intra ? 0.5 : 0.8,
                                  policyRevision: policy.revision)
        }

        // ---- TRANSITION_IN_PROGRESS: accumulate POST and test for a persistent new state (§5) ----
        if let lp = postBuf.last { postMotions.append(distance(f, lp)) }
        postBuf.append(f); transitionFrames += 1
        if postBuf.count > policy.shortWindow { postBuf.removeFirst() }
        if postMotions.count > policy.shortWindow { postMotions.removeFirst() }

        let pre = preRef ?? lagFrame
        let postRep = postBuf.last ?? f
        // Robust PRE→POST discontinuity = MEDIAN distance of POST frames to PRE. Oscillating intra-segment
        // motion hovers near the segment mean (≈ PRE) → median small → no persistent discontinuity. A true
        // cut keeps EVERY post frame far from PRE → median large. This is the core high-motion-vs-cut fix.
        // §5 PRE-window vs POST-window: discontinuity = median over POST frames of their median distance to the
        // PRE window. withinPre/withinPost = internal motion of each window. A true new segment has
        // between-window distance MATERIALLY larger than BOTH within-window motions; a motion excursion
        // (burst/pan that returns) has within-PRE/within-POST comparable to the between distance → rejected.
        let preW = preWindow.isEmpty ? [pre] : preWindow
        func medianConsecutive(_ a: [SegmentFrameV4]) -> Double {
            guard a.count > 1 else { return 0 }
            var ds: [Double] = []; for i in 1..<a.count { ds.append(distance(a[i], a[i-1])) }
            return ds.sorted()[ds.count/2]
        }
        let withinPre = medianConsecutive(preW)
        let withinPost = postMotions.isEmpty ? 0 : postMotions.sorted()[postMotions.count/2]
        let betweenList = postBuf.map { pf -> Double in
            let ds = preW.map { distance(pf, $0) }.sorted(); return ds[ds.count/2]
        }.sorted()
        let prePostDistance = betweenList.isEmpty ? 0 : betweenList[betweenList.count/2]
        let localMotion = max(scale, max(withinPre, withinPost))
        let ratio = prePostDistance / max(1e-6, localMotion)          // discontinuity relative to real motion
        let normJump = ratio
        let coherent = withinPost <= policy.postCoherenceFraction * max(1e-6, prePostDistance)  // POST settled?
        let modeInfo = classifyMode(pre, postRep, abrupt: prePostDistance >= 0.6 * policy.transitionAbruptHint)
        let mode = modeInfo.0, isSwipe = modeInfo.1
        let effectiveConfirm = policy.confirmMotionRatio - (isSwipe ? policy.swipeConfirmRelief : 0)

        let persistedEnough = transitionFrames >= policy.postPersistenceFrames
        let refractoryOK = framesSinceCommit >= policy.minSegmentFrames
        // §10 a NEW segment must move the CONTENT (center). A persistent overlay/chrome change keeps center
        // stable → rejected even if it persisted. (A swipe translates content → center moves.)
        let centerMoved = pre.regions.distances(to: postRep.regions).center >= policy.centerTransitionFloor
        if persistedEnough && centerMoved && ratio >= effectiveConfirm && refractoryOK {
            var reasons: [SegmentReasonV4] = [.prePostPersistentDiscontinuity]
            switch mode { case .scrollSwipe: reasons.append(.coherentSwipe)
                          case .cut: reasons.append(.abruptCut)
                          case .crossfadeAutoplay: reasons.append(.gradualNewSegment)
                          case .appSurface: reasons.append(.appSurfaceTransition)
                          default: break }
            let confidence = min(1, 0.5 + 0.5 * (normJump - effectiveConfirm) / max(0.5, effectiveConfirm))
            return commit(postRep, reasons: reasons, mode: mode, energy: energy, scale: scale,
                          normJump: normJump, persistence: transitionFrames, confidence: confidence)
        }
        if transitionFrames >= policy.maxTransitionFrames {
            // POST never stabilized into a new persistent state → it was sustained intra-segment motion.
            let tf = transitionFrames
            inTransition = false; preRef = nil; preWindow = []; postBuf = []; postMotions = []; candidateMode = .none; transitionFrames = 0
            // fold the observed motion into the baseline (it IS real motion).
            baseline.update(withinPost); baseline.update(energy)
            pushRecent(f)
            return SegmentEventV4(state: .intraSegmentMotion, committedNew: false, segmentSequence: segmentSequence,
                                  motionEnergy: energy, motionScale: scale, normalizedJump: normJump, postPersistence: tf,
                                  transitionMode: .none, reasons: [coherent ? .refractoryWeak : .insufficientPostPersistence, .highMotionSameSegment],
                                  confidence: 0.4, policyRevision: policy.revision)
        }
        pushRecent(f)
        return SegmentEventV4(state: .transitionInProgress, committedNew: false, segmentSequence: segmentSequence,
                              motionEnergy: energy, motionScale: scale, normalizedJump: normJump, postPersistence: transitionFrames,
                              transitionMode: mode, reasons: coherent ? [] : [.insufficientPostPersistence],
                              confidence: 0.35, policyRevision: policy.revision)
    }
}

public extension ContentBoundaryPolicyV4 {
    /// Hint for "abrupt" magnitude (used only to label CUT vs CROSSFADE) — derived from the device profile.
    var transitionAbruptHint: Double { DeviceMotionProfileV1.bootstrapV0.transitionDistanceMedian }
}
