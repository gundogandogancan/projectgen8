import Foundation

// MARK: - P009E §5–§9/§12 — calibration core: rubric, dual annotation, dataset registry + provenance
// classes, splits, transparent dimension calibrators (Platt), metrics, CalibrationRegistryV2.
// HONESTY LAW: every item here is SYNTHETIC_DERIVED or STRUCTURAL_ONLY — real-world accuracy claims are
// structurally impossible (`supportsRealWorldClaims == false`); the phase outcome is
// ENGINEERING_CALIBRATION_ONLY and the production release gate stays CLOSED.

public enum CalibrationSourceClassV1: String, Sendable, Codable, CaseIterable {
    case projectOwnedReal = "PROJECT_OWNED_REAL"
    case licensedRightsClear = "LICENSED_RIGHTS_CLEAR"
    case syntheticDerived = "SYNTHETIC_DERIVED"
    case structuralOnly = "STRUCTURAL_ONLY"
    public var supportsRealWorldClaims: Bool { self == .projectOwnedReal || self == .licensedRightsClear }
}

public enum CalibrationSplitV1: String, Sendable, Codable, CaseIterable {
    case trainTune = "TRAIN_TUNE", calibration = "CALIBRATION", heldOutFinal = "HELD_OUT_FINAL"
    case stress = "STRESS", ood = "OOD", safetySentinel = "SAFETY_SENTINEL"
}

/// §5 ordinal suitability rubric (versioned): 0 protect … 4 strongly aligned.
public enum SuitabilityRubricV1 {
    public static let version = "suitability-rubric-v1"
    public static let levels = ["0=strongly-unsuitable/protect", "1=unsuitable", "2=caution/mixed",
                                "3=generally-suitable", "4=strongly-aligned"]
}

/// §6 — dual-annotator ground truth; disagreement preserved; adjudication traced.
public struct CalibrationAnnotationV1: Sendable {
    public let itemID: String
    public let profileID: String
    public let locale: String                      // "tr" | "en"
    public let rubricVersion: String
    public let annotatorA: String                  // pseudonym
    public let labelA: Int                         // 0…4
    public let annotatorB: String
    public let labelB: Int
    public let adjudicated: Int?                   // P009E-R1 rule: permitted on ANY disagreement; REQUIRED when |A−B| ≥ 2
    public let confidence: String                  // categorical: low/med/high
    public var disagreement: Bool { labelA != labelB }
    public var finalLabel: Int { adjudicated ?? Int((Double(labelA + labelB) / 2.0).rounded()) }
    public init(itemID: String, profileID: String, locale: String, annotatorA: String = "ann-A", labelA: Int,
                annotatorB: String = "ann-B", labelB: Int, adjudicated: Int? = nil, confidence: String = "med") {
        self.itemID = itemID; self.profileID = profileID; self.locale = locale
        self.rubricVersion = SuitabilityRubricV1.version
        self.annotatorA = annotatorA; self.labelA = labelA; self.annotatorB = annotatorB; self.labelB = labelB
        self.adjudicated = adjudicated; self.confidence = confidence
    }
}

/// §18 — explicit synthetic policy PROFILE FIXTURES (policy fixtures, not real people).
public struct ProfileFixtureV1: Sendable {
    public let profileID: String
    public let childProfile: GuardianEnteredChildProfileV1?
    public let parentPreference: ParentPreferencePolicyV1
    public let shieldConfig: ShieldConfigV2?
    public static let adultNeutral = ProfileFixtureV1(profileID: "adult-neutral", childProfile: nil,
                                                      parentPreference: ParentPreferencePolicyV1(), shieldConfig: nil)
    public static let adultShieldMortality = ProfileFixtureV1(profileID: "adult-shield-mortality", childProfile: nil,
        parentPreference: ParentPreferencePolicyV1(), shieldConfig: ShieldConfigV2(blockedConcepts: ["concept:mortality"]))
    public static let parentChild9TR = ProfileFixtureV1(profileID: "parent-child9-tr",
        childProfile: GuardianEnteredChildProfileV1(ageYears: 9, jurisdictionCode: "TR", enteredByGuardian: true),
        parentPreference: ParentPreferencePolicyV1(), shieldConfig: nil)
    public static let parentTeen14TR = ProfileFixtureV1(profileID: "parent-teen14-tr",
        childProfile: GuardianEnteredChildProfileV1(ageYears: 14, jurisdictionCode: "TR", enteredByGuardian: true),
        parentPreference: ParentPreferencePolicyV1(), shieldConfig: nil)
    public static let parentTeen14Strict = ProfileFixtureV1(profileID: "parent-teen14-strict",
        childProfile: GuardianEnteredChildProfileV1(ageYears: 14, jurisdictionCode: "TR", enteredByGuardian: true),
        parentPreference: ParentPreferencePolicyV1(extraCautionDimensions: [.fearThreat], blockSensitiveNews: true),
        shieldConfig: nil)
    public static let all: [ProfileFixtureV1] = [adultNeutral, adultShieldMortality, parentChild9TR,
                                                 parentTeen14TR, parentTeen14Strict]
    public init(profileID: String, childProfile: GuardianEnteredChildProfileV1?,
                parentPreference: ParentPreferencePolicyV1, shieldConfig: ShieldConfigV2?) {
        self.profileID = profileID; self.childProfile = childProfile
        self.parentPreference = parentPreference; self.shieldConfig = shieldConfig
    }
}

/// One calibration pair: item (scenario reference) × profile fixture + dual annotation + split + source.
public struct CalibrationPairV1: Sendable {
    public let itemID: String                       // scenario name in the referenced corpus
    public let corpus: String                       // "P009D" | "P009C" | "P009B_CAL_RESERVED" | "P009E_TEEN"
    public let profile: ProfileFixtureV1
    public let split: CalibrationSplitV1
    public let source: CalibrationSourceClassV1
    public let annotation: CalibrationAnnotationV1
}

// MARK: - §9 — transparent 1-D Platt (logistic) calibrator: P(event | strength). Monotonic by
// construction; deterministic Newton fit; slice-aware; ABSTAINS when data is insufficient.

public struct DimensionCalibratorV1: Sendable {
    public static let version = "dimension-calibrator-v1"
    public static let minSamplesPerSlice = 8
    public let name: String
    public let slice: String                        // "tr" | "en" | "all"
    public let a: Double                            // logit slope (constrained ≥ 0 → monotone)
    public let b: Double
    public let sampleCount: Int
    public let fitted: Bool                         // false = insufficient data → consumers must abstain
    public func probability(_ strength: Double) -> Double? {
        guard fitted else { return nil }
        let z = a * strength + b
        return 1.0 / (1.0 + exp(-z))
    }
    /// Deterministic Newton-Raphson logistic fit with slope floored at 0 (monotonicity law).
    public static func fit(name: String, slice: String, xs: [Double], ys: [Bool]) -> DimensionCalibratorV1 {
        guard xs.count == ys.count, xs.count >= minSamplesPerSlice,
              Set(ys).count == 2 else {                                   // need both classes
            return DimensionCalibratorV1(name: name, slice: slice, a: 0, b: 0, sampleCount: xs.count, fitted: false)
        }
        var a = 1.0, b = 0.0
        for _ in 0..<40 {
            var gA = 0.0, gB = 0.0, hAA = 1e-6, hBB = 1e-6, hAB = 0.0
            for (x, yb) in zip(xs, ys) {
                let y = yb ? 1.0 : 0.0
                let p = 1.0 / (1.0 + exp(-(a * x + b)))
                let w = max(p * (1 - p), 1e-6)
                gA += (p - y) * x; gB += (p - y)
                hAA += w * x * x; hBB += w; hAB += w * x
            }
            let det = hAA * hBB - hAB * hAB
            guard abs(det) > 1e-12 else { break }
            a -= (gA * hBB - gB * hAB) / det
            b -= (gB * hAA - gA * hAB) / det
            a = max(0, a)                                                 // monotone where semantics require
        }
        return DimensionCalibratorV1(name: name, slice: slice, a: a, b: b, sampleCount: xs.count, fitted: true)
    }
}

// MARK: - §12 — calibration metrics (recomputable by auditors; no vanity single number).

public enum CalibrationMetricsV1 {
    public struct BinV1: Sendable { public let meanPred: Double; public let fracPos: Double; public let count: Int }
    public static func eceAndBins(preds: [Double], labels: [Bool], bins: Int = 10) -> (ece: Double, brier: Double, bins: [BinV1]) {
        guard !preds.isEmpty else { return (0, 0, []) }
        // A9-R1-F3 LAW: invalid-domain inputs are NEVER silently clamped into the metric. This
        // non-throwing legacy signature returns an explicit NaN refusal marker (empty bins); the
        // calibration pipeline uses eceAndBinsStrict (typed throw).
        if validateProbabilities(preds) != nil { return (.nan, .nan, []) }
        var binData: [BinV1] = []
        var ece = 0.0
        // P009E-R1 A8-F4: index-based assignment — every prediction lands in EXACTLY one bin
        var assignment: [[Int]] = Array(repeating: [], count: bins)
        for i in preds.indices {
            let b = min(bins - 1, max(0, Int(preds[i] * Double(bins))))
            assignment[b].append(i)
        }
        for i in 0..<bins {
            let idx = assignment[i]
            guard !idx.isEmpty else { continue }
            let mp = idx.map { preds[$0] }.reduce(0, +) / Double(idx.count)
            let fp = idx.map { labels[$0] ? 1.0 : 0.0 }.reduce(0, +) / Double(idx.count)
            ece += (Double(idx.count) / Double(preds.count)) * abs(mp - fp)
            binData.append(BinV1(meanPred: mp, fracPos: fp, count: idx.count))
        }
        let brier = zip(preds, labels).map { pow($0 - ($1 ? 1 : 0), 2) }.reduce(0, +) / Double(preds.count)
        return (ece, brier, binData)
    }
    /// LEGACY signature (non-throwing). R1 A10-F3-SIBLINGS law: invalid input ≠ valid metric — any
    /// non-finite value or shape mismatch returns the explicit NaN refusal marker (same marker family
    /// as eceAndBins). No domain bound here (scale is caller-defined on the legacy path); the
    /// calibration pipeline itself uses ONLY the strict typed API (maeStrict, domain-enforced).
    public static func mae(_ predicted: [Double], _ target: [Double]) -> Double {
        guard !predicted.isEmpty else { return 0 }
        guard predicted.count == target.count,
              validateValues(predicted, domain: nil) == nil,
              validateValues(target, domain: nil) == nil else { return .nan }
        return zip(predicted, target).map { abs($0 - $1) }.reduce(0, +) / Double(predicted.count)
    }
    /// LEGACY signature (non-throwing). R1 A10-F3-SIBLINGS law: NaN comparison semantics previously
    /// MISCOUNTED silently (finite wrong value — worse than a marker). Now any invalid probability or
    /// shape mismatch returns nil — the same undefined-channel already used for one-class labels.
    /// The calibration pipeline itself uses ONLY the strict typed API (aurocStrict).
    public static func auroc(preds: [Double], labels: [Bool]) -> Double? {
        guard preds.count == labels.count, validateProbabilities(preds) == nil else { return nil }
        let pos = zip(preds, labels).filter { $0.1 }.map { $0.0 }
        let neg = zip(preds, labels).filter { !$0.1 }.map { $0.0 }
        guard !pos.isEmpty, !neg.isEmpty else { return nil }
        var wins = 0.0
        for p in pos { for n in neg { if p > n { wins += 1 } else if p == n { wins += 0.5 } } }
        return wins / Double(pos.count * neg.count)
    }
}

// MARK: - CalibrationRegistryV2: slice-aware truth. ENGINEERING_CALIBRATION_ONLY class; production
// score display stays structurally OFF (the P009B skeleton remains untouched and refusing).

public final class CalibrationRegistryV2: @unchecked Sendable {
    public static let version = "calibration-registry-v2"
    public enum ClassV1: String, Sendable { case engineeringOnly = "ENGINEERING_CALIBRATION_ONLY"
                                            case productionCalibrated = "PRODUCTION_CALIBRATED" }
    public let calibrationClass: ClassV1 = .engineeringOnly    // honest: synthetic-derived data only
    private var calibrators: [String: DimensionCalibratorV1] = [:]
    private let lock = NSLock()
    public init() {}
    public func register(_ c: DimensionCalibratorV1) { lock.lock(); calibrators["\(c.name)#\(c.slice)"] = c; lock.unlock() }
    public func calibrator(name: String, slice: String) -> DimensionCalibratorV1? {
        lock.lock(); defer { lock.unlock() }
        return calibrators["\(name)#\(slice)"] ?? calibrators["\(name)#all"]
    }
    /// engineering-calibrated for a slice ⇔ a FITTED calibrator exists; NEVER implies production display.
    public func isEngineeringCalibrated(name: String, slice: String) -> Bool {
        calibrator(name: name, slice: slice)?.fitted ?? false
    }
    public func productionDisplayAllowed() -> Bool { false }   // P009E law — display stays OFF
}
