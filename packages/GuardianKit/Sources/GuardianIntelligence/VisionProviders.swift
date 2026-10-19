import Foundation
import GuardianCore
#if canImport(Vision)
import Vision
import CoreGraphics

// MARK: - Apple Vision providers (PROMPT 002 §2A, §2B) — REAL, on-device, offline
// OCR via VNRecognizeTextRequest; visual feature print via VNGenerateImageFeaturePrintRequest.
// No raw-image persistence — only derived text/feature distance. Request revision recorded.

public struct VisionOCRProvider: Sendable {
    public static let version = "apple-vision-ocr-v1"
    public enum Mode: Sendable { case fast, accurate }
    public let mode: Mode
    public init(mode: Mode = .accurate) { self.mode = mode }

    public func recognizeText(cgImage: CGImage) -> PortOutcome<TextSpan> {
        let start = DispatchTime.now().uptimeNanoseconds
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = (mode == .fast) ? .fast : .accurate
        req.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([req])
        } catch {
            return .init(state: .failed, value: nil, confidence: nil, provenance: .appleVision,
                         engineVersion: Self.version, latencyNanos: 0, privacy: .onDeviceOnly, cost: .moderate)
        }
        let obs = (req.results ?? []).compactMap { $0 as? VNRecognizedTextObservation }
        let candidates = obs.compactMap { $0.topCandidates(1).first }
        let text = candidates.map { $0.string }.joined(separator: " ")
        let conf = candidates.isEmpty ? nil : Double(candidates.map { $0.confidence }.reduce(0,+) / Float(candidates.count))
        let lat = DispatchTime.now().uptimeNanoseconds &- start
        let rev = "textRequestRevision=\(VNRecognizeTextRequest.currentRevision)"
        if text.isEmpty {
            return .init(state: .unknown, value: nil, confidence: nil, provenance: .appleVision,
                         engineVersion: "\(Self.version);\(rev)", latencyNanos: lat, privacy: .onDeviceOnly, cost: .moderate)
        }
        return .init(state: .ok, value: TextSpan(text), confidence: conf, provenance: .appleVision,
                     engineVersion: "\(Self.version);\(rev)", latencyNanos: lat, privacy: .onDeviceOnly, cost: .moderate)
    }
}

public struct VisionFeatureProvider: Sendable {
    public static let version = "apple-vision-featureprint-v1"
    public init() {}

    /// Returns an opaque feature observation wrapped so callers can compute distance.
    public func featurePrint(cgImage: CGImage) -> VNFeaturePrintObservation? {
        let req = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do { try handler.perform([req]) } catch { return nil }
        return req.results?.first as? VNFeaturePrintObservation
    }

    /// Distance between two images' feature prints (0 = identical; larger = more different).
    public func distance(_ a: CGImage, _ b: CGImage) -> Double? {
        guard let fa = featurePrint(cgImage: a), let fb = featurePrint(cgImage: b) else { return nil }
        var dist = Float(0)
        do { try fa.computeDistance(&dist, to: fb) } catch { return nil }
        return Double(dist)
    }
}
#endif
