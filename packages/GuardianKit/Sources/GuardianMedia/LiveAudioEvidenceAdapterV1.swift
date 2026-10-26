//
//  LiveAudioEvidenceAdapterV1.swift — R8 §2/§3/§4 (P0-2/P0-3/P0-4): LIVE SoundAnalysis STREAMING ADAPTER.
//
//  WHAT THIS IS (mandate §2): the first LIVE audio sense for the ReplayKit broadcast extension. It wraps Apple's
//  STREAMING classifier (`SNAudioStreamAnalyzer` + `SNClassifySoundRequest(.version1)`) — the streaming sibling of the
//  file-based `GeneralAudioHeadV1` the lab already proves — and reuses the EXACT same evidence model
//  (`ReelsAudioEventV1`), the same window-merge discipline (`ReelsAudioEvidenceProviderV1.mergeAdjacentWindows`), and
//  the same WARN-only `SoundRuleSafetyV1` contract. It is NOT a new sound brain: it is the live→evidence bridge that
//  fills the bridge's currently-UNAVAILABLE `.audioEvent` slot (WorldModelEvidenceBridgeV1) WHEN a window is analyzed.
//
//  THE HONESTY LAWS (mandate §2.1/§2.2/§3/§9):
//   • REAL labels only. The adapter verifies the classifier's `knownClassifications` at construction; it NEVER assumes
//     scream/siren/alarm/crying/explosion by name. An audio rule / caller asking about an UNSUPPORTED label gets an
//     honest UNAVAILABLE (`supportsLabel` is false) — no fabricated class.
//   • RAW model confidence ≠ suitability. Each event carries the classifier's raw number (`ReelsAudioEventV1
//     .rawModelConfidence`), explicitly NOT a calibrated risk or psychological-harm verdict (classifier label ≠ harm).
//   • EVENT EVIDENCE ONLY (first slice). The adapter produces auditory EVENT evidence with a REAL label + time range +
//     analysis-window provenance; it does NOT emit a harmfulness score. A scream may be fiction; an alarm may be real.
//   • IDENTITY BINDING + GENERATION FIREWALL (§3). Every analyzed window is bound to {sessionID, resolved item
//     identity revision, capture generation, PTS span}. A classification that COMPLETES AFTER the item changed is
//     DISCARDED via the same generation-firewall the OCR/photo paths use — stale audio NEVER updates a new item.
//   • NO SOUND ≠ SAFE. A window not analyzed (thermal deferral, backpressure drop, no audioApp buffers) leaves the
//     audio modality UNAVAILABLE/partial — never a clean/safe claim. Child fail-closed on an audio/resource gap is the
//     caller's existing deficit path; this adapter only ever reports honestly whether a window RAN.
//   • NO microphone, no raw persistence, no upload, no cross-session leakage. The analyzer consumes only the
//     application-audio buffers the caller forwarded; nothing is written to disk; the analyzer is torn down on stop.
//
//  SAMPLE-BUFFER SAFETY (mandate §1.2/§4): the ReplayKit video callback is serial and must NOT be blocked by audio.
//  The caller hands each audio buffer to `enqueue(...)` which appends a MINIMAL derived copy to a BOUNDED, drop-oldest
//  queue (small cap) and returns immediately; the analysis (`drain()`) runs OFF the video callback. A format change or
//  stream stop restarts/ tears down the analyzer; the queue is bounded (no unbounded growth).
//
//  Lives in GuardianMedia (GuardianCore frozen). SoundAnalysis is imported conditionally so an SDK without it still
//  compiles (the adapter then reports FRAMEWORK_UNAVAILABLE — honest absence, never a fabricated clean result).
//
import Foundation
import GuardianCore
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(CoreMedia)
import CoreMedia
#endif
#if canImport(SoundAnalysis)
import SoundAnalysis
#endif

/// R8 §2 — availability of the LIVE audio sense (mirrors ReelsAudioAvailabilityV1 but for the streaming path). Distinct
/// from "ran but found nothing": only `.available` means a window was actually analyzed.
public enum LiveAudioAvailabilityV1: String, Sendable, Equatable, Codable {
    case available            = "AVAILABLE"              // the streaming analyzer ran over real audio buffers
    case frameworkUnavailable = "FRAMEWORK_UNAVAILABLE"  // SoundAnalysis / stream analyzer could not be constructed
    case noBuffers            = "NO_BUFFERS"             // no audioApp buffers were ever enqueued (capture gap)
    case deferredThermal      = "DEFERRED_THERMAL"       // §4 — analysis deferred under thermal serious/critical
    case resourceDeferred     = "RESOURCE_DEFERRED"      // §4 — analysis deferred to protect the heavy-path budget
    case formatUnsupported    = "FORMAT_UNSUPPORTED"     // the audio format could not drive the stream analyzer
}

/// R8 §3 — the IDENTITY BINDING an analyzed audio window is stamped with. A window whose binding no longer matches the
/// live resolved identity (generation advanced) is STALE and its events are discarded (the generation firewall).
public struct LiveAudioBindingV1: Sendable, Equatable, Codable {
    public let sessionID: String
    public let itemIdentityRevision: Int
    public let generation: UInt64
    /// The audio PTS span (seconds) of the analyzed window — REAL, from the buffers; never fabricated.
    public let ptsStartSeconds: Double?
    public let ptsEndSeconds: Double?
    public init(sessionID: String, itemIdentityRevision: Int, generation: UInt64,
                ptsStartSeconds: Double?, ptsEndSeconds: Double?) {
        self.sessionID = sessionID; self.itemIdentityRevision = itemIdentityRevision; self.generation = generation
        self.ptsStartSeconds = ptsStartSeconds; self.ptsEndSeconds = ptsEndSeconds
    }
}

/// R8 §2/§3 — the honest result of analyzing ONE bounded audio window: availability + the REAL events (reusing the
/// file-path's ReelsAudioEventV1 model) + the identity binding + the classifier version. `senseRan` is true only when
/// `.available` — a deferred/absent window narrows coverage, never a clean claim.
public struct LiveAudioWindowEvidenceV1: Sendable, Equatable, Codable {
    public let availability: LiveAudioAvailabilityV1
    public let events: [ReelsAudioEventV1]
    public let binding: LiveAudioBindingV1
    public let classifierVersion: String
    public init(availability: LiveAudioAvailabilityV1, events: [ReelsAudioEventV1],
                binding: LiveAudioBindingV1, classifierVersion: String) {
        self.availability = availability; self.events = events; self.binding = binding
        self.classifierVersion = classifierVersion
    }
    public var senseRan: Bool { availability == .available }
    /// The DISTINCT classifier labels (strongest-first) — the `soundEvents` list threaded into the shield envelope so
    /// a user `.soundClass` rule can match in the EXISTING engine (fusion is NOT done here). Empty ≠ "no audio sense".
    public var distinctLabels: [String] {
        var best: [String: Double] = [:]
        for e in events { let k = e.label.lowercased(); best[k] = max(best[k] ?? 0, e.rawModelConfidence ?? 0) }
        return best.sorted { $0.value > $1.value }.map { $0.key }
    }
    public static func unavailable(_ reason: LiveAudioAvailabilityV1, binding: LiveAudioBindingV1,
                                   classifierVersion: String) -> LiveAudioWindowEvidenceV1 {
        LiveAudioWindowEvidenceV1(availability: reason, events: [], binding: binding, classifierVersion: classifierVersion)
    }
}

/// R8 §1.2/§4 — a MINIMAL derived audio sample for the bounded queue. We do NOT keep the CMSampleBuffer (its lifecycle
/// belongs to the serial video callback); the caller converts it to a short-lived PCM copy OFF the callback. For the
/// pure/testable core we only need the derived facts + an opaque PCM handle the SoundAnalysis path consumes.
public struct LiveAudioQueuedSampleV1: Sendable {
    public let facts: AudioBufferFactsV1
    /// The capture generation + item revision this sample belongs to — so a drain after an item change is discarded.
    public let generation: UInt64
    public let itemIdentityRevision: Int
    public init(facts: AudioBufferFactsV1, generation: UInt64, itemIdentityRevision: Int) {
        self.facts = facts; self.generation = generation; self.itemIdentityRevision = itemIdentityRevision
    }
}

/// R8 §1.2/§4 — the BOUNDED, DROP-OLDEST audio hand-off queue. The serial video callback appends a minimal derived
/// sample and returns immediately (never blocked); the analysis drains off-callback. The cap is small and fixed, so
/// the queue can never grow unbounded. Dropping the OLDEST on overflow keeps the freshest audio (most relevant to the
/// current item) and counts the drop honestly (§4 dropped/late buffers). Pure + testable (no CMSampleBuffer here).
public struct BoundedAudioQueueV1: Sendable, Equatable {
    public let capacity: Int
    public private(set) var samples: [LiveAudioQueuedSampleV1] = []
    public private(set) var droppedOldest = 0
    public private(set) var enqueued = 0
    public init(capacity: Int = 24) { self.capacity = max(1, capacity) }

    /// Append a derived sample; drop the oldest if at capacity (bounded growth). O(1) amortized; never blocks.
    public mutating func enqueue(_ s: LiveAudioQueuedSampleV1) {
        enqueued += 1
        samples.append(s)
        while samples.count > capacity { samples.removeFirst(); droppedOldest += 1 }
    }
    /// Drain ONLY the samples still bound to the live generation+item; stale samples (an older generation, i.e. the
    /// user already swiped to a new item) are DISCARDED here — the firewall at the hand-off boundary. Returns the live
    /// samples and the count discarded as stale.
    public mutating func drainLive(liveGeneration: UInt64, liveItemRevision: Int) -> (live: [LiveAudioQueuedSampleV1], discardedStale: Int) {
        let live = samples.filter { $0.generation == liveGeneration && $0.itemIdentityRevision == liveItemRevision }
        let discarded = samples.count - live.count
        samples.removeAll(keepingCapacity: true)
        return (live, discarded)
    }
    public var count: Int { samples.count }
    public mutating func clear() { samples.removeAll(keepingCapacity: true) }
}

extension LiveAudioQueuedSampleV1: Equatable {
    public static func == (l: LiveAudioQueuedSampleV1, r: LiveAudioQueuedSampleV1) -> Bool {
        l.facts == r.facts && l.generation == r.generation && l.itemIdentityRevision == r.itemIdentityRevision
    }
}

public enum LiveAudioEvidenceAdapterV1 {
    public static let version = "live-audio-evidence-adapter-v1"

    /// R8 §4 — the default bounded window budget: how many windows per item we will analyze before deferring (budget
    /// law — audio must not saturate the heavy path; OCR already owns a slice). Small + fixed.
    public static let maxWindowsPerItem = 6
    /// R8 §4 — the bounded hand-off queue cap (drop-oldest). Small so memory is bounded on the serial callback path.
    public static let queueCapacity = 24

    /// R8 §2 — the classifier's REAL supported labels (Apple SoundAnalysis built-in version1 streaming request). Empty
    /// when SoundAnalysis is unavailable on this runtime (then every `supportsLabel` is false — honest UNAVAILABLE).
    /// We read the framework's OWN `knownClassifications` — never a hardcoded list (§2.1: do not assume class names).
    public static func knownClassifications() -> [String] {
        #if canImport(SoundAnalysis)
        if let req = try? SNClassifySoundRequest(classifierIdentifier: .version1) {
            return (try? req.knownClassifications) ?? []
        }
        #endif
        return []
    }

    /// R8 §2.1 — is a specific label actually SUPPORTED by the classifier at runtime? An unsupported label → the caller
    /// must report UNAVAILABLE for that query (never a fabricated miss/hit). Case-insensitive against the real dict.
    public static func supportsLabel(_ label: String, known: [String]? = nil) -> Bool {
        let dict = known ?? knownClassifications()
        return dict.contains { $0.caseInsensitiveCompare(label) == .orderedSame }
    }

    /// R8 §4 — the resource decision for ONE window, honest + testable. Under thermal serious/critical audio is
    /// DEFERRED (AUDIO_NOT_ANALYZED/RESOURCE_DEFERRED), never run; once the per-item window budget is spent further
    /// windows are RESOURCE_DEFERRED; audio yields to OCR when the heavy path is already saturated. A deferral is
    /// NEVER a clean result — the caller keeps the audio modality UNAVAILABLE/partial (no sound ≠ safe).
    public static func windowDecision(thermal: ThermalBucketV1, windowsAlreadyRunThisItem: Int,
                                       ocrSaturatingHeavyPath: Bool) -> LiveAudioAvailabilityV1? {
        if thermal == .serious || thermal == .critical { return .deferredThermal }
        if windowsAlreadyRunThisItem >= maxWindowsPerItem { return .resourceDeferred }
        if ocrSaturatingHeavyPath { return .resourceDeferred }   // audio + OCR never both saturate (§4 / ResourceGovernor)
        return nil   // nil ⇒ the window MAY run
    }
}

#if canImport(SoundAnalysis) && canImport(AVFoundation) && canImport(CoreMedia)
/// R8 §2 — the REAL streaming analyzer session, driven from `SNAudioStreamAnalyzer`. Fed one `AVAudioPCMBuffer` at a
/// time (converted by the caller OFF the serial callback). The observer collects per-window `SNClassificationResult`s
/// EXACTLY like GeneralAudioHeadV1.TimedCollector; we then merge adjacent windows via the SAME file-path discipline.
/// A format change tears down + rebuilds the analyzer; stop() releases it (no cross-session leakage).
public final class LiveAudioStreamSessionV1: @unchecked Sendable {
    private let lock = NSLock()
    private var analyzer: SNAudioStreamAnalyzer?
    private var request: SNClassifySoundRequest?
    private let observer = StreamCollector()
    private var currentFormat: AVAudioFormat?
    private var framePosition: AVAudioFramePosition = 0
    public private(set) var formatRestarts = 0

    public init() {}

    /// Start/restart the stream analyzer for a given PCM format. Returns false if SoundAnalysis could not be armed
    /// (then the caller reports FRAMEWORK_UNAVAILABLE / FORMAT_UNSUPPORTED — never a fabricated clean result).
    @discardableResult
    public func start(format: AVAudioFormat) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let req = try? SNClassifySoundRequest(classifierIdentifier: .version1) else { return false }
        let a = SNAudioStreamAnalyzer(format: format)
        do { try a.add(req, withObserver: observer) } catch { return false }
        analyzer = a; request = req; currentFormat = format; framePosition = 0
        observer.reset()
        return true
    }

    /// Feed ONE PCM buffer to the running analyzer. If the format changed, restart the analyzer first (§1.2 safe
    /// restart on format change). Non-blocking relative to the serial video callback (the caller invokes this on its
    /// own queue). Returns false if the analyzer is not running and could not be (re)started.
    @discardableResult
    public func analyze(_ pcm: AVAudioPCMBuffer) -> Bool {
        lock.lock()
        if currentFormat == nil || currentFormat?.sampleRate != pcm.format.sampleRate
            || currentFormat?.channelCount != pcm.format.channelCount {
            lock.unlock()
            if currentFormat != nil { formatRestarts += 1 }
            guard start(format: pcm.format) else { return false }
            lock.lock()
        }
        guard let a = analyzer else { lock.unlock(); return false }
        let pos = framePosition
        framePosition += AVAudioFramePosition(pcm.frameLength)
        lock.unlock()
        a.analyze(pcm, atAudioFramePosition: pos)
        return true
    }

    /// Collect the per-window classifications observed so far as merged ReelsAudioEventV1 events (same discipline as
    /// the file path), then RESET the observer so the next window starts clean. Pure w.r.t. the merge logic.
    public func drainMergedEvents() -> [ReelsAudioEventV1] {
        let windows = observer.drain()
        return ReelsAudioEvidenceProviderV1.mergeAdjacentWindows(windows, classifierVersion: GeneralAudioHeadV1.version)
    }

    /// Stop + release the analyzer (session end / stream stop). No raw audio or analyzer survives.
    public func stop() {
        lock.lock(); defer { lock.unlock() }
        if let req = request { analyzer?.remove(req) }
        analyzer?.completeAnalysis()
        analyzer = nil; request = nil; currentFormat = nil; framePosition = 0
        observer.reset()
    }

    /// Per-window collector — identical shape to GeneralAudioHeadV1.TimedCollector (top class per window + real range).
    private final class StreamCollector: NSObject, SNResultsObserving, @unchecked Sendable {
        private let lock = NSLock()
        private var out: [TimedAudioClassification] = []
        func request(_ request: SNRequest, didProduce result: SNResult) {
            guard let r = result as? SNClassificationResult, let top = r.classifications.first else { return }
            let range = r.timeRange
            let start: Double? = (range.start.isValid && !range.start.seconds.isNaN) ? range.start.seconds : nil
            let dur: Double? = (range.duration.isValid && !range.duration.seconds.isNaN) ? range.duration.seconds : nil
            let end: Double? = (start != nil && dur != nil) ? (start! + dur!) : nil
            lock.lock()
            out.append(TimedAudioClassification(label: top.identifier, confidence: Double(top.confidence),
                                                startSeconds: start, endSeconds: end))
            lock.unlock()
        }
        func drain() -> [TimedAudioClassification] { lock.lock(); defer { lock.unlock() }; let o = out; out = []; return o }
        func reset() { lock.lock(); out = []; lock.unlock() }
    }
}
#endif
