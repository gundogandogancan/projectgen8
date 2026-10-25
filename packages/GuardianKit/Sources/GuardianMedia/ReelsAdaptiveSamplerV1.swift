//
//  ReelsAdaptiveSamplerV1.swift — §E2: the adaptive, budgeted PRE-EXPOSURE sampling plan for the controlled player.
//
//  WHY (mandate E2): "not every frame — a better decision about WHICH frames are useful." The opening-only analysis
//  misses a mid-video match; sampling every frame is unaffordable. This PURE, testable planner decides a small set
//  of timepoints (≤ a hard budget) from the real duration, with thermal pressure shrinking the budget, and supports
//  EARLY-STOP once a sample has verified a match (no point decoding the rest) and CANCELLATION when the content
//  changes under us. It computes PLANS; the provider executes them against real frames. No fabricated coverage — the
//  plan knows it samples points, never the whole video (the decision layer then stamps temporalCoverageLimited).
//
//  HONESTY: an event that falls BETWEEN two samples CAN be missed. That is an accepted, measured limit (E4 proves it
//  with the short-blip scenario and reports NOT_DETECTED honestly). The planner's job is to spend a tiny budget
//  WELL (cover start/mid/end + fill the largest gaps), not to claim completeness.
//
import Foundation

/// The thermal pressure bucket the sampler reads (mirrors ProcessInfo.ThermalState without importing it into pure
/// code, so this stays unit-testable on any platform). The extension / provider maps the real ProcessInfo state.
public enum ReelsThermalBucketV1: String, Sendable, Equatable, Codable {
    case nominal, fair, serious, critical
}

/// The adaptive sampler: a pure function from (duration, seed early points, thermal, budget) → a sorted, de-duped,
/// in-range set of sample timestamps. Budgeted (≤ `maxBudget`), thermal-aware (serious+ shrinks the budget), and
/// always anchored at start/mid/end when the budget allows so a mid-video match is reachable.
public struct ReelsAdaptiveSamplerV1: Sendable {
    public static let version = "reels-adaptive-sampler-v1"

    /// The hard ceiling on sample points regardless of duration (mandate E2: ≤5 budget). Never exceeded.
    public static let maxBudget = 5

    public init() {}

    /// The budget for a given duration + thermal state. Short clips need fewer points; longer clips earn more (up to
    /// the ceiling); SERIOUS/CRITICAL thermal pressure shrinks the budget so heavy decode never fights the device.
    public static func budget(durationSeconds: Double, thermal: ReelsThermalBucketV1) -> Int {
        // Duration-based baseline: ~1 point per 1.5s of content, clamped to [2, maxBudget]. A sub-second clip still
        // gets 2 (open + near-end) so we never analyse a single instant and call it coverage.
        let byDuration = max(2, min(maxBudget, Int((durationSeconds / 1.5).rounded(.up))))
        switch thermal {
        case .nominal, .fair:   return byDuration
        case .serious:          return min(byDuration, 3)   // shrink under real thermal pressure
        case .critical:         return 2                    // bare minimum: open + near-end only
        }
    }

    /// Compute the sample timestamps. `seedEarly` anchors the START region (the caller's first-frame hints); we add
    /// the midpoint, a near-end point, and — if budget remains — fill the LARGEST remaining gaps (so a long clip gets
    /// interior coverage rather than three clustered points). Pure + deterministic.
    public func sampleTimes(durationSeconds dur: Double, seedEarly: [Double],
                            thermal: ReelsThermalBucketV1 = .nominal) -> [Double] {
        guard dur > 0 else {
            // No duration known → honest fallback to the seed early points only (never a fabricated mid/end).
            return dedupSorted(seedEarly.isEmpty ? [0.1] : seedEarly)
        }
        let b = Self.budget(durationSeconds: dur, thermal: thermal)
        let nearEnd = max(0, dur - min(0.3, dur * 0.1))    // a hair before the very end (avoid past-duration seek)
        // Always include the earliest seed (start) + near-end; add the midpoint if budget ≥ 3.
        var points: [Double] = []
        let firstEarly = (seedEarly.filter { $0 >= 0 && $0 < dur }.min()) ?? min(0.1, dur * 0.02)
        points.append(firstEarly)
        points.append(nearEnd)
        if b >= 3 { points.append(dur * 0.5) }
        // Fill the largest gaps with the remaining budget (interior coverage for longer clips).
        var current = dedupSorted(points)
        while current.count < b {
            guard let mid = largestGapMidpoint(current, lower: firstEarly, upper: nearEnd) else { break }
            current = dedupSorted(current + [mid])
        }
        return Array(current.prefix(b))
    }

    /// The midpoint of the largest gap between consecutive sampled points (used to fill interior coverage). nil when
    /// no meaningful gap remains (all points are effectively adjacent).
    private func largestGapMidpoint(_ sorted: [Double], lower: Double, upper: Double) -> Double? {
        guard sorted.count >= 2 else { return (lower + upper) / 2 }
        var bestGap = 0.0, bestMid: Double? = nil
        for i in 1..<sorted.count {
            let gap = sorted[i] - sorted[i-1]
            if gap > bestGap { bestGap = gap; bestMid = (sorted[i] + sorted[i-1]) / 2 }
        }
        return bestGap > 0.05 ? bestMid : nil   // ignore trivially small gaps
    }

    private func dedupSorted(_ xs: [Double]) -> [Double] {
        Array(Set(xs.map { ($0 * 1000).rounded() / 1000 })).sorted()
    }
}

/// §E2 — EARLY-STOP controller. The provider calls `shouldStopAfter(...)` per decoded+OCR'd sample: once a sample has
/// VERIFIED a match (real OCR text that the caller confirmed matched a rule), there is no value in decoding the
/// remaining planned points — we already know the item will be acted on. This is a PURE, testable gate (no media).
/// It is conservative: a NON-match or an UNDETERMINED sample NEVER stops early (we keep looking), and it never stops
/// before at least the first sample ran (so a 1-point early stop still examined something).
public struct ReelsEarlyStopV1: Sendable {
    public init() {}
    /// Return true to stop sampling the rest of the plan. `verifiedMatchAtSample` must be the caller's REAL per-sample
    /// verdict (a rule actually matched this sample's OCR text) — never a guess. We stop only on a verified match.
    public func shouldStop(verifiedMatchAtSample: Bool) -> Bool { verifiedMatchAtSample }
}
