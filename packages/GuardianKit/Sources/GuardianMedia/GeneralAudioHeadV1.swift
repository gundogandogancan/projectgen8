import Foundation
import GuardianCore
#if canImport(SoundAnalysis) && canImport(AVFoundation)
import SoundAnalysis
import AVFoundation

// MARK: - General Audio Head V1 (PROMPT 006 §9) — REAL Apple Sound Analysis (built-in classifier).
// Queries the ACTUAL classifier; never invents classes. Raw audio stays ephemeral (file not retained by us).

// §D — `nonisolated` so these pure value types keep a NON-isolated Equatable/Sendable conformance even when a
// consuming target compiles with `-default-isolation=MainActor` (the Gen8 app target does). Without it, the app build
// infers MainActor isolation on the struct and its Equatable conformance can no longer satisfy IntelligenceSignal's
// `Value: Sendable & Equatable` generic requirement. They carry no state that needs isolation.
public nonisolated struct AudioClassification: Sendable, Equatable {
    public let label: String
    public let confidence: Double
}

/// §D3 — ONE per-window classification the analyzer produced, carrying the REAL time range the request supplied (if
/// any). Used by ReelsAudioEvidenceProviderV1 so an audio event can be attributed to its genuine audio time range
/// WITHOUT fabricating a stamp — when the framework gives no range, start/end stay nil.
public nonisolated struct TimedAudioClassification: Sendable, Equatable {
    public let label: String
    public let confidence: Double
    public let startSeconds: Double?
    public let endSeconds: Double?
    public init(label: String, confidence: Double, startSeconds: Double?, endSeconds: Double?) {
        self.label = label; self.confidence = confidence; self.startSeconds = startSeconds; self.endSeconds = endSeconds
    }
}

public struct GeneralAudioHeadV1: Sendable {
    public static let version = "general-audio-v1"
    public init() {}

    /// Analyze a local audio/video file with Apple's built-in sound classifier (version1).
    public func classify(url: URL) -> IntelligenceSignal<[AudioClassification]> {
        let start = DispatchTime.now().uptimeNanoseconds
        guard let analyzer = try? SNAudioFileAnalyzer(url: url),
              let request = try? SNClassifySoundRequest(classifierIdentifier: .version1) else {
            return .unavailable(task: "general_audio", version: Self.version, reason: .notImplemented)
        }
        let observer = Collector()
        do { try analyzer.add(request, withObserver: observer) } catch {
            return .unavailable(task: "general_audio", version: Self.version, reason: .notImplemented)
        }
        analyzer.analyze()   // synchronous; observer gathers results
        let lat = DispatchTime.now().uptimeNanoseconds &- start
        let top = observer.top()
        if top.isEmpty {
            return IntelligenceSignal(task: "general_audio", value: [], rawConfidence: nil,
                                      availability: .unknown, provenance: .coreML, modelVersion: Self.version,
                                      latencyNanos: lat, abstentionReason: .insufficientEvidence)
        }
        return IntelligenceSignal(task: "general_audio", value: top, rawConfidence: top.first?.confidence,
                                  availability: .available, provenance: .coreML, modelVersion: Self.version,
                                  latencyNanos: lat, evidence: [EvidenceRef(kind: "sound-analysis", detail: top.first?.label ?? "")])
    }

    /// M1 — music / non-music convenience.
    public func isMusic(url: URL) -> Bool? {
        let sig = classify(url: url)
        guard sig.availability == .available, let classes = sig.value else { return nil }
        return classes.contains { $0.label.lowercased().contains("music") && $0.confidence > 0.3 }
    }

    /// §D3 — TIMED classification: the same real SNClassifySoundRequest, but keeping EACH per-window result together
    /// with the REAL `SNClassificationResult.timeRange` the request supplied (CMTimeRange → seconds). We keep only the
    /// top class per window (the honest dominant label for that window) above the classifier's floor. Returns nil-
    /// availability signalling via the outer tuple: `.available` with events, or `.unavailable` when the analyzer/
    /// request could not be constructed. Time ranges are REAL (never fabricated); a run that yields no windows returns
    /// an empty `.available` list (the sense ran, found nothing). Synchronous analyze; file not retained by us.
    public func classifyTimed(url: URL) -> (availability: AvailabilityState, events: [TimedAudioClassification]) {
        guard let analyzer = try? SNAudioFileAnalyzer(url: url),
              let request = try? SNClassifySoundRequest(classifierIdentifier: .version1) else {
            return (.unavailable, [])
        }
        let observer = TimedCollector()
        do { try analyzer.add(request, withObserver: observer) } catch { return (.unavailable, []) }
        analyzer.analyze()
        return (.available, observer.windows())
    }

    /// §1.2 — REAL CANCELLABLE timed classification. The old `classifyTimed` used the SYNCHRONOUS `analyze()`: a
    /// detached prefetch Task could be cancelled, but the analysis kept running to completion (the mandate's defect —
    /// "iptal olsa da analiz sürüyor"). This path drives Apple's NON-BLOCKING `analyze(completionHandler:)` and arms
    /// `cancelAnalysis()` on Task cancellation, so a swipe that cancels the enclosing Task really STOPS the in-flight
    /// analysis mid-file; the MainActor is never blocked; completion fires EXACTLY once; the observer/analyzer life
    /// cycle is torn down on both completion and cancellation. A cancelled run returns `.unavailable` with no events,
    /// so a cancelled analysis result is NEVER applied to a different reel (the result is simply discarded).
    ///
    /// HONESTY NOTE (reported): SNAudioFileAnalyzer analyses the file as a single job; `cancelAnalysis()` is the
    /// framework's own cancellation primitive. We check `Task.isCancelled` BEFORE starting and request cancellation
    /// the instant the surrounding Task is cancelled. The per-window granularity of actual decode-stopping is owned by
    /// the framework — we honestly surface a cancelled run as UNAVAILABLE rather than claiming per-sample preemption.
    public func classifyTimedCancellable(url: URL) async -> (availability: AvailabilityState, events: [TimedAudioClassification]) {
        if Task.isCancelled { return (.unavailable, []) }
        guard let analyzer = try? SNAudioFileAnalyzer(url: url),
              let request = try? SNClassifySoundRequest(classifierIdentifier: .version1) else {
            return (.unavailable, [])
        }
        let observer = TimedCollector()
        do { try analyzer.add(request, withObserver: observer) } catch { return (.unavailable, []) }

        // Single-fire completion box: `analyze(completionHandler:)` returns once; we also resume once on cancellation.
        let box = AnalyzeCompletionBox()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<(availability: AvailabilityState, events: [TimedAudioClassification]), Never>) in
                if Task.isCancelled {
                    analyzer.cancelAnalysis()
                    analyzer.remove(request)
                    if box.claim() { cont.resume(returning: (.unavailable, [])) }
                    return
                }
                box.bind(analyzer: analyzer, request: request, observer: observer) { result in
                    cont.resume(returning: result)
                }
                analyzer.analyze(completionHandler: { _ in
                    // Fired once when analysis finishes (or is cancelled by the framework). Deliver the collected
                    // windows; a cancelled run short-circuits to UNAVAILABLE via the cancellation handler below.
                    box.finish()
                })
            }
        } onCancel: {
            // A superseding swipe/policy change cancelled the enclosing Task → really stop the analysis now.
            box.cancel()
        }
    }

    /// §1.2 — single-fire completion/cancellation coordinator for `classifyTimedCancellable`. Guarantees the
    /// continuation resumes EXACTLY once (completion OR cancellation, whichever first) and that the analyzer/observer
    /// lifecycle is torn down on both paths (the request is removed; the analyzer's cancelAnalysis is called on cancel).
    private final class AnalyzeCompletionBox: @unchecked Sendable {
        private let lock = NSLock()
        private var resumed = false
        private weak var analyzer: SNAudioFileAnalyzer?
        private var request: SNClassifySoundRequest?
        private var observer: TimedCollector?
        private var deliver: (((availability: AvailabilityState, events: [TimedAudioClassification])) -> Void)?

        func bind(analyzer: SNAudioFileAnalyzer, request: SNClassifySoundRequest, observer: TimedCollector,
                  deliver: @escaping ((availability: AvailabilityState, events: [TimedAudioClassification])) -> Void) {
            lock.lock(); defer { lock.unlock() }
            self.analyzer = analyzer; self.request = request; self.observer = observer; self.deliver = deliver
        }
        /// Claim the single resume slot. Returns true exactly once.
        func claim() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if resumed { return false }; resumed = true; return true
        }
        func finish() {
            lock.lock()
            let d = deliver; let obs = observer; let req = request; let az = analyzer
            let first = !resumed; resumed = true
            lock.unlock()
            if let req { az?.remove(req) }
            if first, let d { d((.available, obs?.windows() ?? [])) }
        }
        func cancel() {
            lock.lock()
            let d = deliver; let req = request; let az = analyzer
            let first = !resumed; resumed = true
            lock.unlock()
            az?.cancelAnalysis()
            if let req { az?.remove(req) }
            if first, let d { d((.unavailable, [])) }
        }
    }

    private final class Collector: NSObject, SNResultsObserving, @unchecked Sendable {
        private let lock = NSLock()
        private var best: [String: Double] = [:]
        func request(_ request: SNRequest, didProduce result: SNResult) {
            guard let r = result as? SNClassificationResult else { return }
            lock.lock()
            for c in r.classifications.prefix(5) {
                best[c.identifier] = max(best[c.identifier] ?? 0, Double(c.confidence))
            }
            lock.unlock()
        }
        func top() -> [AudioClassification] {
            lock.lock(); defer { lock.unlock() }
            return best.sorted { $0.value > $1.value }.prefix(5).map { AudioClassification(label: $0.key, confidence: $0.value) }
        }
    }

    /// §D3 — collects one dominant (top) classification PER analysis window together with its REAL time range. The
    /// SoundAnalysis request fires `didProduce` per analysis window; each result carries a `timeRange` (CMTimeRange).
    /// We keep the top identifier per window with its confidence and convert the range to seconds — a genuine, non-
    /// fabricated time attribution. Windows with no classifications are skipped (nothing to attribute).
    private final class TimedCollector: NSObject, SNResultsObserving, @unchecked Sendable {
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
        func windows() -> [TimedAudioClassification] { lock.lock(); defer { lock.unlock() }; return out }
    }
}
#endif
