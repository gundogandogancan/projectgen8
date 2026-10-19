import Foundation
import GuardianCore
#if canImport(SoundAnalysis) && canImport(AVFoundation)
import SoundAnalysis
import AVFoundation

// MARK: - General Audio Head V1 (PROMPT 006 §9) — REAL Apple Sound Analysis (built-in classifier).
// Queries the ACTUAL classifier; never invents classes. Raw audio stays ephemeral (file not retained by us).

public struct AudioClassification: Sendable, Equatable {
    public let label: String
    public let confidence: Double
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
}
#endif
