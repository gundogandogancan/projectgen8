import Foundation

// MARK: - Calibration metrics + eval dataset contract (PROMPT 008 §20,§21)
// Metrics CODE exists and is tested. Real calibration status is reported honestly: with no rights-clear labeled dataset,
// calibration = UNAVAILABLE_INSUFFICIENT_DATA. A high average score must never hide false-safe failures.

public enum CalibrationStatus: String, Sendable, Codable { case calibrated = "CALIBRATED", insufficientData = "UNAVAILABLE_INSUFFICIENT_DATA" }

/// One labeled example in the suitability eval dataset (rights/provenance tracked; no silent personal-capture training).
public struct SuitabilityEvalExample: Sendable, Codable, Equatable {
    public var id: String
    public var rightsClass: String            // e.g. "project-owned" | "public-domain" | "licensed"
    public var language: String
    public var modality: String
    public var contentType: String            // text-only | image+text | audio | speech | short-video | meme | ...
    public var sourceSurface: String
    public var groundTruthDimensions: [String: Double]   // dimension raw → 0..1 label
    public var annotatorAgreement: Double
    public var expectedAdmission: String
    public var sensitiveSliceTags: [String]
    public init(id: String, rightsClass: String, language: String, modality: String, contentType: String,
                sourceSurface: String, groundTruthDimensions: [String: Double], annotatorAgreement: Double,
                expectedAdmission: String, sensitiveSliceTags: [String] = []) {
        self.id = id; self.rightsClass = rightsClass; self.language = language; self.modality = modality
        self.contentType = contentType; self.sourceSurface = sourceSurface; self.groundTruthDimensions = groundTruthDimensions
        self.annotatorAgreement = annotatorAgreement; self.expectedAdmission = expectedAdmission; self.sensitiveSliceTags = sensitiveSliceTags
    }
}

/// RWC-PRE-03 RETIREMENT LAW: legacy P008 metrics enum — ENGINEERING_ONLY forever. Behavior is
/// intentionally UNCHANGED (AUDIT11 pins mae min-count truncation and silent-NaN ece as historical
/// evidence). The real-world pipeline uses ONLY the strict typed CalibrationMetricsV1 APIs
/// (eceAndBinsStrict / maeStrict / aurocStrict) behind RealWorldCalibrationExecutorV1.
@available(*, deprecated, message: "P008 legacy metrics — ENGINEERING_ONLY; real-world metrics are CalibrationMetricsV1 strict typed APIs only.")
public enum CalibrationMetrics {
    // --- Classification ---
    public static func precisionRecallF1(tp: Int, fp: Int, fn: Int) -> (precision: Double, recall: Double, f1: Double) {
        let p = tp + fp > 0 ? Double(tp) / Double(tp + fp) : 0
        let r = tp + fn > 0 ? Double(tp) / Double(tp + fn) : 0
        let f1 = p + r > 0 ? 2 * p * r / (p + r) : 0
        return (p, r, f1)
    }
    /// False-safe rate: predicted SAFE/suitable but ground truth was UNSAFE/not-suitable. The catastrophic metric.
    public static func falseSafeRate(predictedSafe: [Bool], groundTruthSafe: [Bool]) -> Double {
        var falseSafe = 0, actualUnsafe = 0
        for i in 0..<min(predictedSafe.count, groundTruthSafe.count) where !groundTruthSafe[i] {
            actualUnsafe += 1; if predictedSafe[i] { falseSafe += 1 }
        }
        return actualUnsafe > 0 ? Double(falseSafe) / Double(actualUnsafe) : 0
    }

    // --- Probability calibration ---
    /// Expected Calibration Error over `bins` equal-width confidence bins.
    public static func ece(confidences: [Double], correct: [Bool], bins: Int = 10) -> Double {
        guard !confidences.isEmpty else { return 0 }
        let n = Double(confidences.count); var ece = 0.0
        for b in 0..<bins {
            let lo = Double(b) / Double(bins), hi = Double(b + 1) / Double(bins)
            var idxs: [Int] = []
            for (i, c) in confidences.enumerated() where (c > lo || (b == 0 && c >= lo)) && c <= hi { idxs.append(i) }
            guard !idxs.isEmpty else { continue }
            let acc = Double(idxs.filter { correct[$0] }.count) / Double(idxs.count)
            let conf = idxs.map { confidences[$0] }.reduce(0, +) / Double(idxs.count)
            ece += Double(idxs.count) / n * abs(acc - conf)
        }
        return ece
    }
    public static func brier(confidences: [Double], correct: [Bool]) -> Double {
        guard !confidences.isEmpty else { return 0 }
        var s = 0.0
        for i in confidences.indices { let y = correct[i] ? 1.0 : 0.0; s += (confidences[i] - y) * (confidences[i] - y) }
        return s / Double(confidences.count)
    }

    // --- Ordinal/continuous suitability ---
    public static func mae(predicted: [Double], truth: [Double]) -> Double {
        guard !predicted.isEmpty else { return 0 }
        var s = 0.0; for i in 0..<min(predicted.count, truth.count) { s += abs(predicted[i] - truth[i]) }
        return s / Double(min(predicted.count, truth.count))
    }
}
