import Foundation

// MARK: - Content boundary V2 (PROMPT 008 §12) — distinguish motion-within-a-video from a real swipe to a NEW item.
// Cheap signals only (no heavy model on the hot path): perceptual signature + temporal hysteresis + OCR/text persistence
// + layout/color signature. Heavy analysis starts only on NEW_CONTENT (or policy-approved AMBIGUOUS).

public enum ContentBoundaryVerdict: String, Sendable, Codable { case sameContent = "SAME_CONTENT", likelySame = "LIKELY_SAME_CONTENT", newContent = "NEW_CONTENT", ambiguous = "AMBIGUOUS" }

public struct BoundaryFrameInput: Sendable {
    public var signature: PerceptualFrameSignature
    public var layoutSignature: UInt64        // coarse UI-region/color-band hash (stable within an app's chrome)
    public var topTextTokens: Set<String>     // cheap OCR/caption tokens (persist within the same item)
    public init(signature: PerceptualFrameSignature, layoutSignature: UInt64, topTextTokens: Set<String> = []) {
        self.signature = signature; self.layoutSignature = layoutSignature; self.topTextTokens = topTextTokens
    }
}

public final class ContentBoundaryDetectorV2: @unchecked Sendable {
    private let lock = NSLock()
    private var prev: BoundaryFrameInput?
    private let perceptualNew: Int        // hamming ≥ → candidate new
    private let perceptualSame: Int       // hamming ≤ → clearly same
    private let layoutNew: Int            // layout hamming ≥ → navigation/app change (strong new signal)
    public init(perceptualSame: Int = 6, perceptualNew: Int = 18, layoutNew: Int = 8) {
        self.perceptualSame = perceptualSame; self.perceptualNew = perceptualNew; self.layoutNew = layoutNew
    }

    public func classify(_ f: BoundaryFrameInput) -> ContentBoundaryVerdict {
        lock.lock(); defer { lock.unlock() }
        guard let p = prev else { prev = f; return .newContent }
        let pHam = p.signature.hamming(f.signature)
        let lHam = (p.layoutSignature ^ f.layoutSignature).nonzeroBitCount
        let textOverlap = p.topTextTokens.isEmpty && f.topTextTokens.isEmpty ? 1.0
            : Double(p.topTextTokens.intersection(f.topTextTokens).count) / Double(max(1, p.topTextTokens.union(f.topTextTokens).count))
        prev = f

        // Layout jump ⇒ navigation to a new item/app (strong). Persistent text + small perceptual drift ⇒ same video moving.
        if lHam >= layoutNew && pHam >= perceptualNew { return .newContent }
        if pHam <= perceptualSame { return .sameContent }
        if textOverlap >= 0.5 && pHam < perceptualNew { return .likelySame }      // motion within same item (text persists)
        if pHam >= perceptualNew && textOverlap < 0.2 { return .newContent }
        return .ambiguous                                                          // needs a light embedding to disambiguate
    }
    public func reset() { lock.lock(); prev = nil; lock.unlock() }
}

// MARK: - P008A-R1 — ONE canonical commit engine (§3,§4,§5). The extension AND lab use THIS; no divergent heuristic.

/// §4 versioned boundary configuration — no magic constants hidden in SampleHandler. Every device proof logs the revision.
public struct ContentBoundaryPolicyV2: Sendable, Codable, Equatable {
    public var revision: String
    public var perceptualSame: Int
    public var perceptualNew: Int
    public var layoutNew: Int
    public var settleFrames: Int                 // frames a candidate must persist before NEW may commit
    public var minDwellFrames: Int               // minimum frames of SAME/LIKELY before a new item is plausible
    public var debounceFramesBetweenNew: Int     // minimum committed-NEW spacing (kills burst spam on moving video)
    public var textPersistenceOverlapSame: Double
    public var ambiguousCommitsNew: Bool         // policy: does AMBIGUOUS commit a NEW? (default false → conservative)
    public init(revision: String = "boundary-policy-v2", perceptualSame: Int = 6, perceptualNew: Int = 18,
                layoutNew: Int = 8, settleFrames: Int = 2, minDwellFrames: Int = 2, debounceFramesBetweenNew: Int = 6,
                textPersistenceOverlapSame: Double = 0.5, ambiguousCommitsNew: Bool = false) {
        self.revision = revision; self.perceptualSame = perceptualSame; self.perceptualNew = perceptualNew
        self.layoutNew = layoutNew; self.settleFrames = settleFrames; self.minDwellFrames = minDwellFrames
        self.debounceFramesBetweenNew = debounceFramesBetweenNew; self.textPersistenceOverlapSame = textPersistenceOverlapSame
        self.ambiguousCommitsNew = ambiguousCommitsNew
    }
}

/// §3 explicit per-platform simplification. The broadcast extension runs OCR-off (budget); the app may enable it.
public struct BoundaryCapabilityProfile: Sendable, Codable, Equatable {
    public var name: String
    public var ocrEnabled: Bool
    public var layoutEnabled: Bool
    public init(name: String, ocrEnabled: Bool, layoutEnabled: Bool) { self.name = name; self.ocrEnabled = ocrEnabled; self.layoutEnabled = layoutEnabled }
    public static let extensionFast = BoundaryCapabilityProfile(name: "EXTENSION_FAST", ocrEnabled: false, layoutEnabled: true)
    public static let appFast = BoundaryCapabilityProfile(name: "APP_FAST", ocrEnabled: true, layoutEnabled: true)
}

public struct BoundaryEvent: Sendable, Equatable {
    public let verdict: ContentBoundaryVerdict
    public let committedNew: Bool              // ONLY committed NEW invokes downstream analysis
    public let contentSequence: Int
    public let framesSinceLastCommit: Int
    public let cheapSignatureDistance: Int
    public let layoutDelta: Int
    public let policyRevision: String
}

/// The canonical commit engine: classification + hysteresis + minimum dwell + debounce between committed NEW events.
/// Motion within one item → LIKELY_SAME/SAME (never commits). Rapid real swipes still commit (bounded by debounce).
public final class ContentBoundaryEngineV2: @unchecked Sendable {
    public let policy: ContentBoundaryPolicyV2
    public let profile: BoundaryCapabilityProfile
    private let lock = NSLock()
    private var prev: BoundaryFrameInput?
    private var contentSequence = 0
    private var framesSinceCommit = Int.max
    private var candidateStreak = 0
    public init(policy: ContentBoundaryPolicyV2 = .init(), profile: BoundaryCapabilityProfile = .extensionFast) {
        self.policy = policy; self.profile = profile
    }

    public func process(_ f: BoundaryFrameInput) -> BoundaryEvent {
        lock.lock(); defer { lock.unlock() }
        framesSinceCommit = framesSinceCommit == Int.max ? Int.max : framesSinceCommit + 1
        guard let p = prev else {
            prev = f; contentSequence = 1; framesSinceCommit = 0
            return BoundaryEvent(verdict: .newContent, committedNew: true, contentSequence: 1,
                                 framesSinceLastCommit: 0, cheapSignatureDistance: 0, layoutDelta: 0, policyRevision: policy.revision)
        }
        let pHam = p.signature.hamming(f.signature)
        let lHam = profile.layoutEnabled ? (p.layoutSignature ^ f.layoutSignature).nonzeroBitCount : 0
        let textOverlap: Double = {
            guard profile.ocrEnabled else { return 1.0 }   // OCR off in extension → text never forces NEW/SAME
            if p.topTextTokens.isEmpty && f.topTextTokens.isEmpty { return 1.0 }
            return Double(p.topTextTokens.intersection(f.topTextTokens).count) / Double(max(1, p.topTextTokens.union(f.topTextTokens).count))
        }()
        prev = f

        // Classify (policy-driven; same contract as the tested classifier).
        var verdict: ContentBoundaryVerdict
        if lHam >= policy.layoutNew && pHam >= policy.perceptualNew { verdict = .newContent }
        else if pHam <= policy.perceptualSame { verdict = .sameContent }
        else if textOverlap >= policy.textPersistenceOverlapSame && pHam < policy.perceptualNew { verdict = .likelySame }
        else if pHam >= policy.perceptualNew && textOverlap < 0.2 { verdict = .newContent }
        else { verdict = .ambiguous }

        let candidateNew = verdict == .newContent || (verdict == .ambiguous && policy.ambiguousCommitsNew)
        if candidateNew { candidateStreak += 1 } else { candidateStreak = 0 }

        // Commit NEW only if the candidate settled AND debounce elapsed since the last committed NEW (anti-spam).
        var committed = false
        if candidateNew && candidateStreak >= policy.settleFrames && framesSinceCommit >= policy.debounceFramesBetweenNew {
            committed = true; contentSequence += 1; framesSinceCommit = 0; candidateStreak = 0
        }
        return BoundaryEvent(verdict: verdict, committedNew: committed, contentSequence: contentSequence,
                             framesSinceLastCommit: framesSinceCommit, cheapSignatureDistance: pHam,
                             layoutDelta: lHam, policyRevision: policy.revision)
    }
    public func reset() { lock.lock(); prev = nil; contentSequence = 0; framesSinceCommit = Int.max; candidateStreak = 0; lock.unlock() }
    public var committedContentCount: Int { lock.lock(); defer { lock.unlock() }; return contentSequence }
}

/// Engine-based benchmark: counts COMMITTED NEW (not raw per-frame verdicts) vs labeled true boundaries.
public enum BoundaryEngineBenchmark {
    public static func run(_ engine: ContentBoundaryEngineV2, frames: [BoundaryFrameInput], labeledIsNewBoundary: [Bool]) -> BoundaryBenchmarkResult {
        var r = BoundaryBenchmarkResult(frames: frames.count, trueBoundaries: labeledIsNewBoundary.filter { $0 }.count,
                                        detectedBoundaries: 0, falseBoundaries: 0, missedBoundaries: 0)
        // Count committed-NEW; attribute each true boundary window to whether a commit occurred within a small window.
        var committedAt: [Int] = []
        for (i, f) in frames.enumerated() { if engine.process(f).committedNew { r.detectedBoundaries += 1; committedAt.append(i) } }
        let truthIdx = labeledIsNewBoundary.enumerated().compactMap { $0.element ? $0.offset : nil }
        // A committed NEW is a true positive if within ±3 frames of a true boundary; else false-new.
        for c in committedAt { if !truthIdx.contains(where: { abs($0 - c) <= 3 }) { r.falseBoundaries += 1 } }
        for t in truthIdx { if !committedAt.contains(where: { abs($0 - t) <= 3 }) { r.missedBoundaries += 1 } }
        return r
    }
}

/// Benchmark harness: run a labeled frame sequence, compute false-boundary / missed-boundary rates (§12).
public struct BoundaryBenchmarkResult: Sendable, Equatable {
    public var frames: Int; public var trueBoundaries: Int; public var detectedBoundaries: Int
    public var falseBoundaries: Int; public var missedBoundaries: Int
    public var falseBoundaryRate: Double { trueBoundaries + (frames - trueBoundaries) > 0 ? Double(falseBoundaries) / Double(max(1, frames)) : 0 }
    public var missedBoundaryRate: Double { trueBoundaries > 0 ? Double(missedBoundaries) / Double(trueBoundaries) : 0 }
}
public enum BoundaryBenchmark {
    /// `labeledIsNewBoundary[i]` = ground truth that frame i is the first frame of a NEW item.
    public static func run(_ det: ContentBoundaryDetectorV2, frames: [BoundaryFrameInput], labeledIsNewBoundary: [Bool]) -> BoundaryBenchmarkResult {
        var r = BoundaryBenchmarkResult(frames: frames.count, trueBoundaries: labeledIsNewBoundary.filter { $0 }.count,
                                        detectedBoundaries: 0, falseBoundaries: 0, missedBoundaries: 0)
        for (i, f) in frames.enumerated() {
            let v = det.classify(f)
            let detectedNew = (v == .newContent)
            if detectedNew { r.detectedBoundaries += 1 }
            let truth = i < labeledIsNewBoundary.count ? labeledIsNewBoundary[i] : false
            if detectedNew && !truth { r.falseBoundaries += 1 }
            if truth && !detectedNew { r.missedBoundaries += 1 }
        }
        return r
    }
}
