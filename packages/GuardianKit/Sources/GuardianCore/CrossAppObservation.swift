import Foundation

// MARK: - Cross-app observation core (PROMPT 007D)
// Frame-driven HEAVY AI is forbidden. An ultra-cheap perceptual-signature change detector runs on every frame; heavy
// analysis runs ONCE per distinct content. Pure/headless-testable; the ReplayKit broadcast extension drives it on device.

/// 64-bit perceptual signature of a downsampled grayscale frame (average-hash). Computed cheaply from pixel bytes.
public struct PerceptualFrameSignature: Sendable, Equatable {
    public let bits: UInt64
    public init(bits: UInt64) { self.bits = bits }
    public func hamming(_ other: PerceptualFrameSignature) -> Int { (bits ^ other.bits).nonzeroBitCount }
}

/// Decides, per frame, whether content MEANINGFULLY changed — so heavy work never reruns on the same content.
public final class ContentChangeDetector: @unchecked Sendable {
    public struct Decision: Sendable, Equatable {
        public let changed: Bool          // true → a new distinct content → analyze
        public let stableFrames: Int      // consecutive frames at the current content
        public let contentID: String      // derived id for the current distinct content (cheap signature-based)
    }
    private let lock = NSLock()
    private var last: PerceptualFrameSignature?
    private var contentSeq = 0
    private var stable = 0
    private let changeThreshold: Int        // hamming distance to count as a new content
    private let settleFrames: Int           // frames to settle before we trust/analyze (avoid transition blur)
    public init(changeThreshold: Int = 10, settleFrames: Int = 2) {
        self.changeThreshold = changeThreshold; self.settleFrames = settleFrames
    }

    /// Feed a frame signature. Returns whether this is a new distinct content worth analyzing (once).
    public func observe(_ sig: PerceptualFrameSignature) -> Decision {
        lock.lock(); defer { lock.unlock() }
        guard let prev = last else {
            last = sig; contentSeq += 1; stable = 1
            return Decision(changed: false, stableFrames: 1, contentID: "cac-\(contentSeq)")   // first frame: settle, don't analyze yet
        }
        if prev.hamming(sig) >= changeThreshold {
            last = sig; contentSeq += 1; stable = 1
            return Decision(changed: false, stableFrames: 1, contentID: "cac-\(contentSeq)")   // transition detected → start settling
        }
        // Same content (within threshold): advance stability; analyze exactly once when we first settle.
        last = sig; stable += 1
        let justSettled = (stable == settleFrames)
        return Decision(changed: justSettled, stableFrames: stable, contentID: "cac-\(contentSeq)")
    }
    public func reset() { lock.lock(); last = nil; contentSeq = 0; stable = 0; lock.unlock() }
}

/// Counters for the cross-app session — proof of change-vs-analyzed and cache reuse (no raw media).
public struct CrossAppObservationStats: Sendable, Equatable {
    public var framesProcessed = 0
    public var contentChanges = 0
    public var contentsAnalyzed = 0
    public var cacheReuse = 0
    public var heavyAnalysisRuns = 0
    public init() {}
}

/// Builds a minimal, privacy-safe ContentObservationEnvelope from cheap cross-app signals (no raw frame).
public enum CrossAppObservationBuilder {
    public static func envelope(contentID: String, ocrText: String?, soundEvents: [String], languages: [String]) -> ContentObservationEnvelope {
        var e = ContentObservationEnvelope()
        e.contentID = ContentID(contentID)
        e.surfaceCapabilityTier = "C_CROSS_APP"
        if let t = ocrText, !t.isEmpty { e.ocrText = [TextSource(origin: .ocr, text: t)] }
        e.soundEvents = soundEvents
        e.languageSignals = languages.isEmpty ? ["en"] : languages
        e.rightsClass = "user-permitted-screen-capture"
        e.privacyClass = "ephemeral-on-device"      // raw frame never persisted; derived signals only
        return e
    }
}
