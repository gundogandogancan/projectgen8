//
//  Tier1ItemIdentityV1.swift — TIER-1 content-item identity (P010 first working prototype)
//
//  WHY THIS EXISTS (measured Outcome C, P009A_R2_MEASURED_TIER0_RESULTS.md):
//  The device run proved Tier-0's five cheap visual channels (theme/hist/chrome/regional/proj) OVERLAP between
//  SAME-item internal cuts and NEW-item boundaries — "TIER-0 IS NOT SAFELY SEPARABLE". Item count is therefore
//  declared APPROXIMATE at Tier-0. This component is the first Tier-1 multimodal discriminator behind item
//  identity: Vision FEATURE PRINTS (semantic image embedding, on-device, public API) fused with OCR-text
//  trigram similarity (C3 output) and the one measured one-sided Tier-0 signal (projection correlation) as a
//  tie-breaker. Tier-0 PROPOSES item boundaries; Tier-1 CONFIRMS or OVERRIDES; UNKNOWN is a legitimate verdict
//  (abstention law — UNKNOWN ≠ BAD, and UNKNOWN defers to the Tier-0 proposal, never invents certainty).
//
//  DESIGN DECISION (alternatives considered):
//  - VNGenerateImageFeaturePrintRequest (CHOSEN): supported public API, on-device, no model bundling, one
//    forward pass per committed shot (not per frame), distance semantics designed for image similarity.
//  - Bundled CoreML embedding model: strictly heavier (model weights in a ~50MB extension, loading cost,
//    maintenance), no capability we need beyond what feature prints give at this stage.
//  - VNClassifyImageRequest label-set overlap: coarser (taxonomy labels collapse distinct items of the same
//    class — two different cooking videos share labels), so weaker as an identity signal.
//
//  COST DISCIPLINE (same C3 law as BroadcastOCRRunner):
//  - EVENT-GATED: callers invoke only at COMMITTED shot boundaries (never per frame / intra-shot motion).
//  - RATE-LIMITED + SERIAL: >=1s between runs, in-flight guard DROPS (never queues) — identical throttle law.
//  - DOWNSCALED: <=512px long side before the Vision pass; transients released in an autoreleasepool.
//  - BOUNDED STATE: at most `maxReferencePrints` feature prints (~few KB each) + one hashed-trigram set
//    (capped) per CURRENT item. No raw frames, no raw OCR text retained — trigrams are 64-bit hashes
//    (non-reconstructive, derived-only; same privacy class as the existing proof log).
//
//  COMPILATION: lives in GuardianMedia (OUTSIDE the V8/V9 freeze-governed roots) and is additionally compiled
//  directly into the GuardianBroadcastExtension and Gen8 app targets (GuardianLiveShared.swift precedent) —
//  the extension links GuardianCore only, so no new product dependency is introduced. No GuardianCore import
//  is needed: Tier-0 context enters as plain scalars.
//
import Foundation
import CoreVideo
import CoreGraphics
#if canImport(Vision)
import Vision
import CoreImage
#endif

// MARK: - Verdict + policy

public enum Tier1IdentityVerdictV1: String, Sendable, Codable {
    case sameItem = "SAME_ITEM"
    case newItem = "NEW_ITEM"
    case unknown = "UNKNOWN"        // legitimate abstention — caller keeps the Tier-0 proposal
}

/// Versioned thresholds. CALIBRATION TIER: SYNTHETIC (rights-clear rendered fixtures, Tier1IdentityBenchmarkTests)
/// — device-pending. Feature-print distances use the request's current revision semantics (observed synthetic
/// scale: same-item variants ≪ different-item scenes); the benchmark prints the measured distributions that
/// justified these numbers. Never claim device validity until a device evidence run exists.
public struct Tier1IdentityPolicyV1: Sendable {
    public let revision: String
    public let fpSameMax: Double          // feature-print distance ≤ → SAME (visual family)
    public let fpNewMin: Double           // feature-print distance ≥ → NEW
    public let ocrSameMin: Double         // trigram Jaccard ≥ → SAME tie-break (ambiguous fp band)
    public let ocrNewMax: Double          // trigram Jaccard ≤ → NEW tie-break (both sides must have text)
    public let ocrMinTrigrams: Int        // below this, a text side is "honestly absent" (no negative evidence)
    public let projSameMin: Double        // Tier-0 projection correlation ≥ → SAME tie-break (the ONE measured
                                          // one-sided Tier-0 signal: high-continuity mode ≥0.70, Outcome C §proj)
    public let maxReferencePrints: Int    // bounded per-item visual memory
    public let maxTrigramSet: Int         // bounded per-item text memory (hashed, non-reconstructive)
    public let minIntervalMs: Double      // rate limit between Vision passes (C3 law)
    public let maxLongSide: Int           // downscale target before the Vision pass

    public init(revision: String = "tier1-item-identity-v1",
                fpSameMax: Double = 0.55, fpNewMin: Double = 0.90,
                ocrSameMin: Double = 0.30, ocrNewMax: Double = 0.05, ocrMinTrigrams: Int = 8,
                projSameMin: Double = 0.70,
                maxReferencePrints: Int = 3, maxTrigramSet: Int = 4096,
                minIntervalMs: Double = 1000, maxLongSide: Int = 512) {
        self.revision = revision
        self.fpSameMax = fpSameMax; self.fpNewMin = fpNewMin
        self.ocrSameMin = ocrSameMin; self.ocrNewMax = ocrNewMax; self.ocrMinTrigrams = ocrMinTrigrams
        self.projSameMin = projSameMin
        self.maxReferencePrints = maxReferencePrints; self.maxTrigramSet = maxTrigramSet
        self.minIntervalMs = max(0, minIntervalMs); self.maxLongSide = max(64, maxLongSide)
    }
    /// Frozen v1 defaults (synthetic-calibrated; device-pending).
    public static let v1 = Tier1IdentityPolicyV1()
}

// MARK: - Pure text similarity (hashed character trigrams — raw text is NEVER retained)

public enum Tier1TextSimilarityV1 {
    /// 64-bit FNV-1a hashed, lowercased, whitespace-collapsed character trigrams. Non-reconstructive by design:
    /// only hashes leave this function; the caller may drop the raw OCR text immediately.
    public static func trigramHashes(_ text: String) -> Set<UInt64> {
        let cleaned = text.lowercased().split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
        let chars = Array(cleaned.unicodeScalars)
        guard chars.count >= 3 else { return [] }
        var out = Set<UInt64>(); out.reserveCapacity(chars.count - 2)
        for i in 0...(chars.count - 3) {
            var h: UInt64 = 0xcbf29ce484222325
            for j in i..<(i + 3) { h = (h ^ UInt64(chars[j].value)) &* 0x100000001b3 }
            out.insert(h)
        }
        return out
    }
    public static func jaccard(_ a: Set<UInt64>, _ b: Set<UInt64>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let inter = a.intersection(b).count
        let union = a.count + b.count - inter
        return union == 0 ? 0 : Double(inter) / Double(union)
    }
}

// MARK: - Throttle (same pure law as BroadcastOCRThrottleV1; local copy keeps this file dependency-free)

public struct Tier1ThrottleV1: Sendable {
    public let minIntervalMs: Double
    private var lastRunStartMs: Double? = nil
    private(set) public var inFlight = false
    public init(minIntervalMs: Double) { self.minIntervalMs = max(0, minIntervalMs) }
    public func shouldRun(nowMs: Double) -> Bool {
        if inFlight { return false }
        guard let last = lastRunStartMs else { return true }
        return (nowMs - last) >= minIntervalMs
    }
    public mutating func beginRun(nowMs: Double) { lastRunStartMs = nowMs; inFlight = true }
    public mutating func endRun() { inFlight = false }
}

// MARK: - Feature print wrapper + extractor (Vision; honest .unavailable degradation elsewhere)

public struct Tier1FeaturePrintV1 {
    #if canImport(Vision)
    let observation: VNFeaturePrintObservation
    init(observation: VNFeaturePrintObservation) { self.observation = observation }
    #endif
    /// Distance under the current VNGenerateImageFeaturePrintRequest revision; nil when incomparable.
    public func distance(to other: Tier1FeaturePrintV1) -> Double? {
        #if canImport(Vision)
        var d: Float = 0
        do { try observation.computeDistance(&d, to: other.observation); return Double(d) } catch { return nil }
        #else
        return nil
        #endif
    }
}

public enum Tier1FeaturePrintExtractorV1 {
    #if canImport(Vision)
    // One reusable CIContext (BroadcastOCRRunnerV1 pattern) — never per-call allocation.
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Downscale (never upscale) to `maxLongSide`, run VNGenerateImageFeaturePrintRequest. Synchronous; the
    /// caller guarantees seriality (throttle in-flight guard). Transients die inside the autoreleasepool.
    public static func extract(_ px: CVPixelBuffer, maxLongSide: Int) -> (print: Tier1FeaturePrintV1?, longSide: Int) {
        autoreleasepool {
            let w = CVPixelBufferGetWidth(px), h = CVPixelBufferGetHeight(px)
            guard w > 0, h > 0 else { return (nil, 0) }
            let longSide = max(w, h)
            let scale = longSide > maxLongSide ? Double(maxLongSide) / Double(longSide) : 1.0
            let outLong = Int((Double(longSide) * scale).rounded())
            var ci = CIImage(cvPixelBuffer: px)
            if scale < 1.0 { ci = ci.transformed(by: CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale))) }
            guard let cg = ciContext.createCGImage(ci, from: ci.extent) else { return (nil, outLong) }
            return (featurePrint(cgImage: cg), outLong)
        }
    }

    /// CGImage path (HUD self-test + headless benchmark). Same request, same revision semantics.
    public static func featurePrint(cgImage: CGImage) -> Tier1FeaturePrintV1? {
        autoreleasepool {
            let req = VNGenerateImageFeaturePrintRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do { try handler.perform([req]) } catch { return nil }
            guard let obs = req.results?.first as? VNFeaturePrintObservation else { return nil }
            return Tier1FeaturePrintV1(observation: obs)
        }
    }
    #else
    public static func extract(_ px: CVPixelBuffer, maxLongSide: Int) -> (print: Tier1FeaturePrintV1?, longSide: Int) { (nil, 0) }
    public static func featurePrint(cgImage: CGImage) -> Tier1FeaturePrintV1? { nil }
    #endif
}

// MARK: - Pure fusion law (headless-testable; no Vision dependency once distances exist)

public struct Tier1FusionInputV1: Sendable {
    public let fpDistance: Double?                 // min distance to current-item reference prints; nil = unavailable
    public let ocrSimilarity: Double?              // trigram Jaccard vs item text memory; nil = a side honestly lacks text
    public let tier0ProjectionCorrelation: Double? // Tier-0 proj channel (tie-breaker only)
    public let tier0StrongNew: Bool                // swipe/surface strong-new (measured-reliable; veto is absolute)
    public init(fpDistance: Double?, ocrSimilarity: Double?, tier0ProjectionCorrelation: Double?, tier0StrongNew: Bool) {
        self.fpDistance = fpDistance; self.ocrSimilarity = ocrSimilarity
        self.tier0ProjectionCorrelation = tier0ProjectionCorrelation; self.tier0StrongNew = tier0StrongNew
    }
}

public enum Tier1IdentityFusionV1 {
    public struct Outcome: Sendable {
        public let verdict: Tier1IdentityVerdictV1
        public let confidence: Double
        public let tieBreaker: String?     // nil = feature print decided alone
        public let reason: String          // compact derived reason — never raw content
    }
    /// The fusion law (documented order):
    /// 1. Tier-0 strong-new veto is ABSOLUTE for SAME (frozen policy law): Tier-1 may confirm NEW or abstain,
    ///    never merge against a confirmed swipe/surface transition.
    /// 2. Feature print decides when outside the ambiguous band [fpSameMax, fpNewMin].
    /// 3. Ambiguous band → OCR trigram similarity (both sides must have real text).
    /// 4. Still ambiguous → Tier-0 projection high-continuity mode (the one measured one-sided cheap signal).
    /// 5. Otherwise UNKNOWN (abstention; caller keeps the Tier-0 proposal).
    public static func fuse(_ input: Tier1FusionInputV1, policy: Tier1IdentityPolicyV1) -> Outcome {
        func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }
        if let d = input.fpDistance {
            if d >= policy.fpNewMin {
                return Outcome(verdict: .newItem, confidence: 0.65 + 0.35 * clamp01((d - policy.fpNewMin) / max(policy.fpNewMin, 1e-9)),
                               tieBreaker: nil, reason: "fp-new(d=\(String(format: "%.3f", d)))")
            }
            if d <= policy.fpSameMax {
                if input.tier0StrongNew {
                    return Outcome(verdict: .unknown, confidence: 0, tieBreaker: nil,
                                   reason: "strong-new-veto(fp-said-same,d=\(String(format: "%.3f", d)))")
                }
                return Outcome(verdict: .sameItem, confidence: 0.65 + 0.35 * clamp01(1 - d / max(policy.fpSameMax, 1e-9)),
                               tieBreaker: nil, reason: "fp-same(d=\(String(format: "%.3f", d)))")
            }
        }
        // Ambiguous fp band, or fp unavailable → OCR tie-break (both-sides-present enforced upstream via nil).
        if let j = input.ocrSimilarity {
            if j >= policy.ocrSameMin {
                if input.tier0StrongNew {
                    return Outcome(verdict: .unknown, confidence: 0, tieBreaker: "ocr-trigram",
                                   reason: "strong-new-veto(ocr-said-same,j=\(String(format: "%.2f", j)))")
                }
                return Outcome(verdict: .sameItem, confidence: 0.60, tieBreaker: "ocr-trigram",
                               reason: "ocr-same(j=\(String(format: "%.2f", j)))")
            }
            if j <= policy.ocrNewMax {
                return Outcome(verdict: .newItem, confidence: 0.60, tieBreaker: "ocr-trigram",
                               reason: "ocr-new(j=\(String(format: "%.2f", j)))")
            }
        }
        if !input.tier0StrongNew, let p = input.tier0ProjectionCorrelation, p >= policy.projSameMin {
            return Outcome(verdict: .sameItem, confidence: 0.50, tieBreaker: "tier0-projection",
                           reason: "proj-same(p=\(String(format: "%.2f", p)))")
        }
        let band = input.fpDistance.map { "fp-ambiguous(d=\(String(format: "%.3f", $0)))" } ?? "fp-unavailable"
        return Outcome(verdict: .unknown, confidence: 0, tieBreaker: nil, reason: band)
    }
}

// MARK: - Assessment record (derived scalars only — proof-log safe)

public struct Tier1IdentityAssessmentV1: Sendable {
    public let verdict: Tier1IdentityVerdictV1
    public let confidence: Double
    public let fpDistance: Double?
    public let ocrSimilarity: Double?
    public let tieBreaker: String?
    public let reason: String
    public let tier0OpenedNewItem: Bool
    public let disagreesWithTier0: Bool    // SAME vs tier0-new, or NEW vs tier0-same
    public let latencyMs: Double
    public let downscaledLongSide: Int
}

// MARK: - The stateful Tier-1 tracker (one per broadcast session / benchmark run)

/// Tier-0 proposes, Tier-1 confirms/overrides. State is the CURRENT item's bounded visual+text memory.
/// Serial by contract: callers invoke from one processing context (ReplayKit callback / test loop); the
/// throttle's in-flight guard additionally drops any overlap rather than queueing (C3 law).
public final class Tier1ItemIdentityV1 {
    public let policy: Tier1IdentityPolicyV1
    private var throttle: Tier1ThrottleV1
    private var referencePrints: [Tier1FeaturePrintV1] = []
    private var itemTrigrams = Set<UInt64>()
    // Bounded session counters for the finish-line summary (derived scalars only).
    private(set) public var assessedCount = 0
    private(set) public var sameCount = 0
    private(set) public var newCount = 0
    private(set) public var unknownCount = 0
    private(set) public var disagreementCount = 0
    private(set) public var skippedThrottleCount = 0

    public init(policy: Tier1IdentityPolicyV1 = .v1) {
        self.policy = policy
        self.throttle = Tier1ThrottleV1(minIntervalMs: policy.minIntervalMs)
    }

    /// Broadcast path: assess a committed shot keyframe. Returns nil when rate-limited/in-flight (dropped,
    /// never queued — the caller keeps the Tier-0 proposal and logs nothing heavy).
    public func assess(pixelBuffer: CVPixelBuffer, ocrText: String?, tier0OpenedNewItem: Bool,
                       tier0StrongNew: Bool, tier0ProjectionCorrelation: Double?, nowMs: Double) -> Tier1IdentityAssessmentV1? {
        guard throttle.shouldRun(nowMs: nowMs) else { skippedThrottleCount += 1; return nil }
        throttle.beginRun(nowMs: nowMs)
        defer { throttle.endRun() }
        let start = DispatchTime.now().uptimeNanoseconds
        let (print_, longSide) = Tier1FeaturePrintExtractorV1.extract(pixelBuffer, maxLongSide: policy.maxLongSide)
        return assessExtracted(print_, longSide: longSide, ocrText: ocrText, tier0OpenedNewItem: tier0OpenedNewItem,
                               tier0StrongNew: tier0StrongNew, tier0ProjectionCorrelation: tier0ProjectionCorrelation,
                               startNanos: start)
    }

    /// Headless/HUD path (owned CGImage fixtures). NOT throttled — lab callers control cadence explicitly.
    public func assess(cgImage: CGImage, ocrText: String?, tier0OpenedNewItem: Bool,
                       tier0StrongNew: Bool, tier0ProjectionCorrelation: Double?) -> Tier1IdentityAssessmentV1 {
        let start = DispatchTime.now().uptimeNanoseconds
        let p = Tier1FeaturePrintExtractorV1.featurePrint(cgImage: cgImage)
        return assessExtracted(p, longSide: max(cgImage.width, cgImage.height), ocrText: ocrText,
                               tier0OpenedNewItem: tier0OpenedNewItem, tier0StrongNew: tier0StrongNew,
                               tier0ProjectionCorrelation: tier0ProjectionCorrelation, startNanos: start)
    }

    private func assessExtracted(_ newPrint: Tier1FeaturePrintV1?, longSide: Int, ocrText: String?,
                                 tier0OpenedNewItem: Bool, tier0StrongNew: Bool,
                                 tier0ProjectionCorrelation: Double?, startNanos: UInt64) -> Tier1IdentityAssessmentV1 {
        // Hash the OCR text immediately; the raw string is never stored (non-reconstructive discipline).
        let newTrigrams = ocrText.map { Tier1TextSimilarityV1.trigramHashes($0) } ?? []
        let textPresent = newTrigrams.count >= policy.ocrMinTrigrams

        func finish(_ verdict: Tier1IdentityVerdictV1, _ confidence: Double, _ fp: Double?, _ ocr: Double?,
                    _ tie: String?, _ reason: String) -> Tier1IdentityAssessmentV1 {
            assessedCount += 1
            switch verdict {
            case .sameItem: sameCount += 1
            case .newItem: newCount += 1
            case .unknown: unknownCount += 1
            }
            let disagrees = (verdict == .sameItem && tier0OpenedNewItem) || (verdict == .newItem && !tier0OpenedNewItem)
            if disagrees { disagreementCount += 1 }
            // State transition: NEW (or UNKNOWN while Tier-0 opened new) resets item memory; SAME accumulates.
            let treatAsNew = verdict == .newItem || (verdict == .unknown && tier0OpenedNewItem)
            if treatAsNew {
                referencePrints = newPrint.map { [$0] } ?? []
                itemTrigrams = textPresent ? newTrigrams : []
            } else {
                if let p = newPrint {
                    referencePrints.append(p)
                    if referencePrints.count > policy.maxReferencePrints {
                        // keep the FIRST (item anchor) + most recent prints
                        referencePrints.remove(at: 1)
                    }
                }
                if textPresent, itemTrigrams.count + newTrigrams.count <= policy.maxTrigramSet {
                    itemTrigrams.formUnion(newTrigrams)
                }
            }
            let lat = Double(DispatchTime.now().uptimeNanoseconds &- startNanos) / 1_000_000
            return Tier1IdentityAssessmentV1(verdict: verdict, confidence: confidence, fpDistance: fp,
                                             ocrSimilarity: ocr, tieBreaker: tie, reason: reason,
                                             tier0OpenedNewItem: tier0OpenedNewItem, disagreesWithTier0: disagrees,
                                             latencyMs: lat, downscaledLongSide: longSide)
        }

        // First committed shot: no reference yet → honest UNKNOWN that seeds the memory.
        guard !referencePrints.isEmpty || !itemTrigrams.isEmpty else {
            return finish(.unknown, 0, nil, nil, nil, "no-reference-seeded")
        }
        let fpDistance: Double? = newPrint.flatMap { np in
            referencePrints.compactMap { np.distance(to: $0) }.min()
        }
        let ocrSim: Double? = (textPresent && !itemTrigrams.isEmpty)
            ? Tier1TextSimilarityV1.jaccard(newTrigrams, itemTrigrams) : nil
        let fused = Tier1IdentityFusionV1.fuse(
            Tier1FusionInputV1(fpDistance: fpDistance, ocrSimilarity: ocrSim,
                               tier0ProjectionCorrelation: tier0ProjectionCorrelation, tier0StrongNew: tier0StrongNew),
            policy: policy)
        return finish(fused.verdict, fused.confidence, fpDistance, ocrSim, fused.tieBreaker, fused.reason)
    }
}
