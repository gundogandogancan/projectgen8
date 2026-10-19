import Foundation

// MARK: - Adaptive content boundary V3 (PROMPT 008A-R2) — general, cheap, multi-region + temporal + bounded evidence.
// Goal: suppress motion INSIDE one item AND still detect real feed/item transitions through shared UI chrome.
// No app-specific hacks, no hardcoded pixel coordinates, no heavy optical flow, no raw media. Deterministic.

/// Cheap multi-region perceptual signature. Each region is an 8-bit "thermometer"-style luma code (0..64 via popcount);
/// hamming between regions ≈ magnitude of regional change. Plus a tiny luma histogram. Chrome vs content is separable.
public struct MultiRegionSignature: Sendable, Equatable, Codable {
    public var global: UInt64
    public var center: UInt64
    public var top: UInt64
    public var bottom: UInt64
    public var left: UInt64
    public var right: UInt64
    public var lumaHistogram: [Int]   // small, e.g. 4 bins
    public init(global: UInt64, center: UInt64, top: UInt64, bottom: UInt64, left: UInt64, right: UInt64, lumaHistogram: [Int]) {
        self.global = global; self.center = center; self.top = top; self.bottom = bottom
        self.left = left; self.right = right; self.lumaHistogram = lumaHistogram
    }
    static func d(_ a: UInt64, _ b: UInt64) -> Double { Double((a ^ b).nonzeroBitCount) / 64.0 }   // 0..1
    public struct RegionDistances: Sendable, Equatable {
        public var global, center, top, bottom, left, right, histogram: Double
        public var sides: Double { (left + right) / 2 }
    }
    public func distances(to o: MultiRegionSignature) -> RegionDistances {
        let hist: Double = {
            guard lumaHistogram.count == o.lumaHistogram.count, !lumaHistogram.isEmpty else { return 0 }
            let tot = Double(max(1, lumaHistogram.reduce(0,+)))
            var s = 0; for i in lumaHistogram.indices { s += abs(lumaHistogram[i] - o.lumaHistogram[i]) }
            return min(1, Double(s) / (2 * tot))
        }()
        return RegionDistances(global: Self.d(global, o.global), center: Self.d(center, o.center), top: Self.d(top, o.top),
                               bottom: Self.d(bottom, o.bottom), left: Self.d(left, o.left), right: Self.d(right, o.right), histogram: hist)
    }
}

public enum BoundaryVerdictV3: String, Sendable, Codable {
    case sameContent = "SAME_CONTENT", likelySame = "LIKELY_SAME_CONTENT", overlayChange = "OVERLAY_CHANGE"
    case transitionCandidate = "TRANSITION_CANDIDATE", newContent = "NEW_CONTENT", ambiguous = "AMBIGUOUS"
}

/// §7 versioned policy — no magic constants in the extension; the revision is logged every session.
public struct ContentBoundaryPolicyV3: Sendable, Codable, Equatable {
    public var revision: String
    // content-region weights (chrome low, center high; edges not fully ignored for edge-to-edge apps)
    public var wCenter, wGlobal, wTop, wBottom, wSides, wHistogram: Double
    public var sameThreshold: Double          // weighted D ≤ → clearly same
    public var regionJumpFraction: Double      // a region "jumped" if its distance ≥ this
    public var minRegionAgreement: Int         // regions that must jump together for a transition candidate
    public var transitionFloor: Double         // absolute floor for weighted D to be a candidate
    public var strongJumpDistance: Double       // broad+large weighted D → may bypass refractory
    public var strongRegionAgreement: Int
    public var centerContentFloor: Double       // content (center) must move at least this much for a transition
    public var confirmFrames: Int              // candidate persistence before commit
    public var refractoryFrames: Int           // soft refractory: weak candidates suppressed, strong break through
    public var dynamicWindow: Int              // bounded rolling baseline length (for high-motion adaptation)
    public var dynamicJumpMultiplier: Double   // D must exceed baselineMean + mult*baselineMAD
    public var minDynamicThreshold: Double
    public var maxDynamicThreshold: Double
    public init(revision: String = "boundary-policy-v3",
                wCenter: Double = 0.42, wGlobal: Double = 0.18, wTop: Double = 0.06, wBottom: Double = 0.06,
                wSides: Double = 0.10, wHistogram: Double = 0.18,
                sameThreshold: Double = 0.06, regionJumpFraction: Double = 0.22, minRegionAgreement: Int = 2,
                transitionFloor: Double = 0.07, strongJumpDistance: Double = 0.30, strongRegionAgreement: Int = 3,
                centerContentFloor: Double = 0.12,
                confirmFrames: Int = 1, refractoryFrames: Int = 2, dynamicWindow: Int = 12,
                dynamicJumpMultiplier: Double = 1.5, minDynamicThreshold: Double = 0.07, maxDynamicThreshold: Double = 0.40) {
        self.revision = revision; self.wCenter = wCenter; self.wGlobal = wGlobal; self.wTop = wTop; self.wBottom = wBottom
        self.wSides = wSides; self.wHistogram = wHistogram; self.sameThreshold = sameThreshold
        self.regionJumpFraction = regionJumpFraction; self.minRegionAgreement = minRegionAgreement
        self.transitionFloor = transitionFloor; self.strongJumpDistance = strongJumpDistance
        self.strongRegionAgreement = strongRegionAgreement; self.centerContentFloor = centerContentFloor; self.confirmFrames = confirmFrames
        self.refractoryFrames = refractoryFrames; self.dynamicWindow = dynamicWindow
        self.dynamicJumpMultiplier = dynamicJumpMultiplier; self.minDynamicThreshold = minDynamicThreshold
        self.maxDynamicThreshold = maxDynamicThreshold
    }
    /// FROZEN policy selected on the TUNE split only (see P008A_R2_TUNE_RESULTS). Used for HELD-OUT + device validation.
    public static let frozenV3 = ContentBoundaryPolicyV3()
}

public struct BoundaryEventV3: Sendable, Equatable {
    public let verdict: BoundaryVerdictV3
    public let committedNew: Bool
    public let contentSequence: Int
    public let weightedDistance: Double
    public let dynamicThreshold: Double
    public let regionAgreement: Int
    public let strong: Bool
    public let policyRevision: String
}

/// §6 bounded evidence accumulator. Rolling baseline of within-item motion (bounded memory) → adaptive jump detection;
/// region agreement separates broad transitions from local overlays; strong jumps bypass the soft refractory.
public final class BoundaryEvidenceAccumulatorV3: @unchecked Sendable {
    public let policy: ContentBoundaryPolicyV3
    private let lock = NSLock()
    private var prev: MultiRegionSignature?
    private var recent: [Double] = []     // bounded within-item weighted distances
    private var contentSequence = 0
    private var framesSinceCommit = Int.max
    private var confirmStreak = 0
    public init(policy: ContentBoundaryPolicyV3 = .init()) { self.policy = policy }
    public var committedContentCount: Int { lock.lock(); defer { lock.unlock() }; return contentSequence }
    public func reset() { lock.lock(); prev = nil; recent = []; contentSequence = 0; framesSinceCommit = Int.max; confirmStreak = 0; lock.unlock() }

    private func weighted(_ d: MultiRegionSignature.RegionDistances) -> Double {
        let p = policy
        let sum = p.wCenter + p.wGlobal + p.wTop + p.wBottom + p.wSides + p.wHistogram
        return (p.wCenter*d.center + p.wGlobal*d.global + p.wTop*d.top + p.wBottom*d.bottom + p.wSides*d.sides + p.wHistogram*d.histogram) / max(0.0001, sum)
    }
    private func baseline() -> (mean: Double, mad: Double) {
        guard !recent.isEmpty else { return (0, 0) }
        let m = recent.reduce(0,+) / Double(recent.count)
        let mad = recent.reduce(0) { $0 + abs($1 - m) } / Double(recent.count)
        return (m, mad)
    }

    public func process(_ sig: MultiRegionSignature) -> BoundaryEventV3 {
        lock.lock(); defer { lock.unlock() }
        framesSinceCommit = framesSinceCommit == Int.max ? Int.max : framesSinceCommit + 1
        guard let p = prev else {
            prev = sig; contentSequence = 1; framesSinceCommit = 0
            return BoundaryEventV3(verdict: .newContent, committedNew: true, contentSequence: 1, weightedDistance: 0,
                                   dynamicThreshold: policy.minDynamicThreshold, regionAgreement: 0, strong: false, policyRevision: policy.revision)
        }
        let dist = sig.distances(to: p); prev = sig
        let D = weighted(dist)
        let regionVals = [dist.center, dist.global, dist.top, dist.bottom, dist.sides]
        let agreement = regionVals.filter { $0 >= policy.regionJumpFraction }.count
        let (bMean, bMad) = baseline()
        let dynThr = min(policy.maxDynamicThreshold, max(policy.minDynamicThreshold, bMean + policy.dynamicJumpMultiplier * bMad))
        let strong = D >= policy.strongJumpDistance && agreement >= policy.strongRegionAgreement
        // CENTER is the content region; TOP/BOTTOM/SIDES are chrome. A chrome-only change with a stable center = overlay.
        let chromeOnly = dist.center < policy.sameThreshold &&
            (dist.top >= policy.regionJumpFraction || dist.bottom >= policy.regionJumpFraction || dist.sides >= policy.regionJumpFraction)
        // A content transition requires the CONTENT (center) to actually move, confirmed by the adaptive threshold.
        let contentMoved = dist.center >= policy.centerContentFloor
        let isJump = strong || (contentMoved && D >= dynThr && D >= policy.transitionFloor)

        var verdict: BoundaryVerdictV3
        var committed = false
        if !isJump {
            if chromeOnly { verdict = .overlayChange }                 // chrome/overlay blip → never a boundary, not baseline motion
            else if D <= policy.sameThreshold { verdict = .sameContent }
            else { verdict = .likelySame }
            confirmStreak = 0
            if !chromeOnly { recent.append(D); if recent.count > policy.dynamicWindow { recent.removeFirst() } }  // within-item motion only
        } else {
            verdict = .transitionCandidate
            confirmStreak += 1
            let refractoryOK = framesSinceCommit >= policy.refractoryFrames || strong   // strong bypasses soft refractory
            if confirmStreak >= (strong ? 1 : policy.confirmFrames) && refractoryOK {
                verdict = .newContent; committed = true; contentSequence += 1; framesSinceCommit = 0; confirmStreak = 0
                recent.removeAll()   // new item → reset motion baseline (don't carry prior item's motion stats)
            }
            // NOTE: jump D is deliberately NOT added to the within-item baseline.
        }
        return BoundaryEventV3(verdict: verdict, committedNew: committed, contentSequence: contentSequence,
                               weightedDistance: D, dynamicThreshold: dynThr, regionAgreement: agreement,
                               strong: strong, policyRevision: policy.revision)
    }
}
