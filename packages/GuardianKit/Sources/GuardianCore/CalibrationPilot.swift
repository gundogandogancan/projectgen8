import Foundation

// MARK: - Calibration pilot (PROMPT 008A §12,§13,§14) — REAL held-out calibration on a LAB pilot set.
// Status never exceeds evidence: at most LAB_CALIBRATED_LIMITED. A LAB pilot must NOT make real content show a falsely
// precise number — the score gate checks CalibrationScope (language/modality) before displaying any score.
//
// RWC-PRE-03 RETIREMENT LAW (BLK-A11-LEGACY-P008): this entire file is a HISTORICAL P008 LAB surface,
// ENGINEERING_ONLY forever. Its pilot FAILED (false-safe 0.50, verdict POOR) — preserved as immutable
// negative evidence (NT-P008-PILOT-FAILED, FM-014). Real-world calibration structurally CANNOT enter:
// (1) `CalibrationPilotRunner.run` requires an EngineeringOnlyExecutionContextV1 — a type with NO
//     real-world case, so a real-world caller cannot even express the call (compile-time separation);
// (2) no conversion exists between PreparedCalibrationDatasetV1 (the canonical RWC door) and
//     PilotExample — the type worlds are bridgeless by design;
// (3) the lawful real-world surface is RealWorldCalibrationExecutorV1 ONLY (strict typed metrics).
// Behavior is intentionally UNCHANGED (AUDIT11 pins the legacy semantics as historical evidence).

/// RWC-PRE-03: the ONLY execution context the legacy pilot accepts. A real-world case deliberately
/// does not exist — adding one is an FM-013/FM-014-class violation an audit must catch.
public enum EngineeringOnlyExecutionContextV1: Sendable { case engineeringLab }

public enum CalibrationLevel: String, Sendable, Codable, Comparable {
    case uncalibrated = "UNCALIBRATED", labCalibratedLimited = "LAB_CALIBRATED_LIMITED"
    case deviceCalibratedLimited = "DEVICE_CALIBRATED_LIMITED", languageCalibrated = "LANGUAGE_CALIBRATED"
    case productionCalibrated = "PRODUCTION_CALIBRATED"
    private var rank: Int { switch self { case .uncalibrated: 0; case .labCalibratedLimited: 1; case .deviceCalibratedLimited: 2; case .languageCalibrated: 3; case .productionCalibrated: 4 } }
    public static func < (a: CalibrationLevel, b: CalibrationLevel) -> Bool { a.rank < b.rank }
}

public struct CalibrationScope: Sendable, Codable, Equatable {
    public var languages: Set<String>
    public var modalities: Set<String>
    public var level: CalibrationLevel
    public var revision: String
    public init(languages: Set<String>, modalities: Set<String>, level: CalibrationLevel, revision: String) {
        self.languages = languages; self.modalities = modalities; self.level = level; self.revision = revision
    }
    /// §14 — a score may display only if the calibration scope actually covers this language + modality.
    public func covers(language: String, modality: String) -> Bool {
        level >= .labCalibratedLimited && languages.contains(language) && modalities.contains(modality)
    }
}

/// One pilot example: the UNcalibrated fused suitability (0..1) + independently authored truth label.
public struct PilotExample: Sendable, Equatable {
    public var id: String; public var language: String; public var modality: String
    public var rawSuitability: Double; public var labelSuitable: Bool; public var labelScore: Double
    public init(id: String, language: String, modality: String, rawSuitability: Double, labelSuitable: Bool, labelScore: Double) {
        self.id = id; self.language = language; self.modality = modality
        self.rawSuitability = rawSuitability; self.labelSuitable = labelSuitable; self.labelScore = labelScore
    }
}

/// Transparent 1D logistic (Platt) calibrator: p = sigmoid(a*raw + b), fit by gradient descent on BCE. Deterministic.
public struct LogisticCalibrator: Sendable, Codable, Equatable {
    public var a: Double; public var b: Double
    public init(a: Double = 1, b: Double = 0) { self.a = a; self.b = b }
    public func calibrated(_ raw: Double) -> Double { 1.0 / (1.0 + exp(-(a * raw + b))) }
    public static func fit(_ data: [(raw: Double, label: Bool)], iterations: Int = 2000, lr: Double = 0.3) -> LogisticCalibrator {
        var a = 1.0, b = 0.0; let n = Double(max(1, data.count))
        for _ in 0..<iterations {
            var ga = 0.0, gb = 0.0
            for d in data {
                let p = 1.0 / (1.0 + exp(-(a * d.raw + b)))
                let y = d.label ? 1.0 : 0.0
                ga += (p - y) * d.raw; gb += (p - y)
            }
            a -= lr * ga / n; b -= lr * gb / n
        }
        return LogisticCalibrator(a: a, b: b)
    }
}

public struct SliceMetrics: Sendable, Equatable {
    public var count: Int; public var ece: Double; public var brier: Double; public var mae: Double
    public var precision: Double; public var recall: Double; public var f1: Double; public var falseSafe: Double
}

public struct CalibrationPilotResult: Sendable, Equatable {
    public var level: CalibrationLevel
    public var revision: String
    public var overall: SliceMetrics
    public var byLanguage: [String: SliceMetrics]
    public var scope: CalibrationScope
}

public enum CalibrationPilotRunner {
    /// Fit on `train`, evaluate on held-out `test`. Returns real per-language metrics. decisionThreshold on calibrated p.
    /// RWC-PRE-03: `context` is type-bound to the engineering lab — no real-world case exists.
    @available(*, deprecated, message: "P008 LAB pilot — ENGINEERING_ONLY (pilot FAILED, preserved as negative evidence). Real-world calibration MUST use CalibrationRunPreparationV1 -> RealWorldCalibrationExecutorV1.")
    public static func run(train: [PilotExample], test: [PilotExample], modalities: Set<String>,
                           revision: String, decisionThreshold: Double = 0.5,
                           context: EngineeringOnlyExecutionContextV1 = .engineeringLab) -> CalibrationPilotResult {
        _ = context   // type-level law: only .engineeringLab can ever be passed
        let cal = LogisticCalibrator.fit(train.map { ($0.rawSuitability, $0.labelSuitable) })
        func metrics(_ xs: [PilotExample]) -> SliceMetrics {
            let conf = xs.map { cal.calibrated($0.rawSuitability) }
            let correct = xs.enumerated().map { (i, e) in (conf[i] >= decisionThreshold) == e.labelSuitable }
            let predSuitable = conf.map { $0 >= decisionThreshold }
            let truth = xs.map { $0.labelSuitable }
            var tp = 0, fp = 0, fn = 0
            for i in xs.indices { if predSuitable[i] && truth[i] { tp += 1 }; if predSuitable[i] && !truth[i] { fp += 1 }; if !predSuitable[i] && truth[i] { fn += 1 } }
            let prf = CalibrationMetrics.precisionRecallF1(tp: tp, fp: fp, fn: fn)
            let fs = CalibrationMetrics.falseSafeRate(predictedSafe: predSuitable, groundTruthSafe: truth)
            let ece = CalibrationMetrics.ece(confidences: conf, correct: correct, bins: 5)
            let brier = CalibrationMetrics.brier(confidences: conf, correct: xs.map { $0.labelSuitable })
            let mae = CalibrationMetrics.mae(predicted: conf, truth: xs.map { $0.labelScore })
            return SliceMetrics(count: xs.count, ece: ece, brier: brier, mae: mae, precision: prf.precision,
                                recall: prf.recall, f1: prf.f1, falseSafe: fs)
        }
        var byLang: [String: SliceMetrics] = [:]
        for lang in Set(test.map { $0.language }) { byLang[lang] = metrics(test.filter { $0.language == lang }) }
        let scope = CalibrationScope(languages: Set(test.map { $0.language }), modalities: modalities,
                                     level: .labCalibratedLimited, revision: revision)
        return CalibrationPilotResult(level: .labCalibratedLimited, revision: revision, overall: metrics(test),
                                      byLanguage: byLang, scope: scope)
    }
}
