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
