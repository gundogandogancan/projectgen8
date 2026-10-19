import Foundation

// MARK: - Trainable linear (logistic-regression) classifier (PROMPT 004 §9, §10)
// Compact "distilled embeddings + linear head" architecture. Pure Swift, deterministic (fixed seed),
// no external deps. Real train→eval→export loop. NOT a giant LLM. Calibration handled separately.

public struct TrainingExample: Sendable {
    public let features: [Double]
    public let label: Int           // 0 / 1
    public let language: String
    public init(features: [Double], label: Int, language: String) {
        self.features = features; self.label = label; self.language = language
    }
}

public struct ClassifierMetrics: Sendable, Codable, Equatable {
    public var n: Int
    public var precision: Double
    public var recall: Double
    public var f1: Double
    public var accuracy: Double
    public var abstentions: Int
}

public struct LinearClassifier: Sendable, Codable, Equatable {
    public var weights: [Double]
    public var bias: Double
    public var featureDim: Int
    public var version: String

    public init(featureDim: Int, version: String = "linear-head-v1") {
        self.weights = Array(repeating: 0, count: featureDim); self.bias = 0
        self.featureDim = featureDim; self.version = version
    }

    private static func sigmoid(_ z: Double) -> Double { 1.0 / (1.0 + exp(-z)) }

    public func probability(_ x: [Double]) -> Double {
        guard x.count == featureDim else { return 0.5 }
        var z = bias
        for i in 0..<featureDim { z += weights[i] * x[i] }
        return Self.sigmoid(z)
    }

    /// Deterministic gradient-descent training (seedless: starts at zeros → deterministic).
    public mutating func train(_ data: [TrainingExample], epochs: Int = 300, lr: Double = 0.1, l2: Double = 0.001) {
        guard !data.isEmpty else { return }
        for _ in 0..<epochs {
            var gradW = Array(repeating: 0.0, count: featureDim)
            var gradB = 0.0
            for ex in data {
                let p = probability(ex.features)
                let err = p - Double(ex.label)
                for i in 0..<featureDim { gradW[i] += err * ex.features[i] }
                gradB += err
            }
            let m = Double(data.count)
            for i in 0..<featureDim { weights[i] -= lr * (gradW[i] / m + l2 * weights[i]) }
            bias -= lr * (gradB / m)
        }
    }

    /// Evaluate with an abstention band around 0.5 (|p-0.5| < margin ⇒ abstain, not a forced guess).
    public func evaluate(_ data: [TrainingExample], decisionThreshold: Double = 0.5, abstainMargin: Double = 0.1) -> ClassifierMetrics {
        var tp = 0, fp = 0, tn = 0, fn = 0, abst = 0
        for ex in data {
            let p = probability(ex.features)
            if abs(p - 0.5) < abstainMargin { abst += 1; continue }
            let pred = p >= decisionThreshold ? 1 : 0
            switch (pred, ex.label) {
            case (1,1): tp += 1; case (1,0): fp += 1; case (0,0): tn += 1; default: fn += 1
            }
        }
        let prec = tp + fp == 0 ? 0 : Double(tp)/Double(tp+fp)
        let rec = tp + fn == 0 ? 0 : Double(tp)/Double(tp+fn)
        let f1 = prec + rec == 0 ? 0 : 2*prec*rec/(prec+rec)
        let scored = tp+fp+tn+fn
        let acc = scored == 0 ? 0 : Double(tp+tn)/Double(scored)
        return ClassifierMetrics(n: data.count, precision: prec, recall: rec, f1: f1, accuracy: acc, abstentions: abst)
    }

    /// Checksum of exported weights (for the model-pack manifest / supply chain).
    public func checksum() -> String {
        var h = 1469598103934665603 as UInt64   // FNV-1a
        func mix(_ d: Double) { for b in withUnsafeBytes(of: d, Array.init) { h = (h ^ UInt64(b)) &* 1099511628211 } }
        mix(bias); weights.forEach(mix)
        return String(h, radix: 16)
    }
}
