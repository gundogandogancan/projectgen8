import Foundation

// MARK: - Personal Suitability Score contract + fusion (PROMPT 008 §16,§17,§18,§19,§35)
// SCORE ≠ MODEL CONFIDENCE. CONFIDENCE ≠ SUITABILITY. UNKNOWN beats a fake number.
// A score is shown ONLY when evidence coverage + calibration gates allow; otherwise score=nil, band=UNKNOWN.

public enum SuitabilityDimension: String, Sendable, Codable, CaseIterable {
    case safetyAlignment = "SAFETY_ALIGNMENT"       // higher = safer / more policy-aligned
    case topicAlignment = "TOPIC_ALIGNMENT"         // explicit user preference / goals / Shield-topic
    case benefit = "BENEFIT"                        // learning / practical / creative value (evidence-backed)
    case attentionPressure = "ATTENTION_PRESSURE"   // higher pressure REDUCES suitability
    case emotionalLoad = "EMOTIONAL_LOAD"           // higher load REDUCES suitability (per policy)
    case positiveExposure = "POSITIVE_EXPOSURE"     // fit with chosen positive-exposure mode
    case childPolicy = "CHILD_POLICY"               // only when applicable
}

/// Score-layer reason codes (canonical, language-neutral; presentation localizes separately).
public enum SuitabilityReason: String, Sendable, Codable {
    case safetyFloor = "SAFETY_FLOOR", hardShield = "HARD_SHIELD", insufficientCoverage = "INSUFFICIENT_COVERAGE"
    case calibrationUnavailable = "CALIBRATION_UNAVAILABLE", safetyCap = "SAFETY_CAP", childPolicyCap = "CHILD_POLICY_CAP"
    case scored = "SCORED"
}

public enum ScoreBand: String, Sendable, Codable {
    case aligned = "ALIGNED", generallyAligned = "GENERALLY_ALIGNED", caution = "CAUTION"
    case lowAlignment = "LOW_ALIGNMENT", strongProtection = "STRONG_PROTECTION_NOT_RECOMMENDED", unknown = "UNKNOWN"
    /// §35 color band (never the only signal; a hard Shield/safety decision may override).
    public var colorToken: String {
        switch self {
        case .aligned: return "GREEN"; case .generallyAligned: return "LIGHT_GREEN"; case .caution: return "AMBER"
        case .lowAlignment: return "ORANGE"; case .strongProtection: return "RED"; case .unknown: return "GREY"
        }
    }
    public static func fromScore(_ s: Int) -> ScoreBand {
        switch s { case 80...100: return .aligned; case 60..<80: return .generallyAligned; case 40..<60: return .caution
        case 20..<40: return .lowAlignment; default: return .strongProtection }
    }
}

public struct PersonalSuitabilityScoreV1: Sendable, Codable, Equatable {
    public static let contractVersion = "suitability-score-v1"
    public var score: Int?                          // 0..100, nil when evidence/calibration insufficient
    public var scoreBand: ScoreBand
    public var confidence: Double                   // evidence confidence — SEPARATE from suitability
    public var evidenceCoverage: Double
    public var admissionState: AdmissionState
    public var reasonCodes: [SuitabilityReason]
    public var dimensionScores: [SuitabilityDimension: Double]   // 0..1 per dimension (transparent)
    public var calibrationRevision: String
    public var policyRevision: String
    public var contentDNARevision: String
    public var modelPackRevision: String
    public var contractVersion: String
    public init(score: Int?, scoreBand: ScoreBand, confidence: Double, evidenceCoverage: Double,
                admissionState: AdmissionState, reasonCodes: [SuitabilityReason], dimensionScores: [SuitabilityDimension: Double],
                calibrationRevision: String, policyRevision: String, contentDNARevision: String, modelPackRevision: String,
                contractVersion: String = PersonalSuitabilityScoreV1.contractVersion) {
        self.score = score; self.scoreBand = scoreBand; self.confidence = confidence; self.evidenceCoverage = evidenceCoverage
        self.admissionState = admissionState; self.reasonCodes = reasonCodes; self.dimensionScores = dimensionScores
        self.calibrationRevision = calibrationRevision; self.policyRevision = policyRevision
        self.contentDNARevision = contentDNARevision; self.modelPackRevision = modelPackRevision; self.contractVersion = contractVersion
    }
}

// Inputs to fusion. Each dimension is a value 0..1 + whether it is available (unavailable ⇒ not counted in coverage).
public struct SuitabilityFusionInput: Sendable {
    public struct Dim: Sendable { public var value: Double; public var available: Bool
        public init(_ v: Double, available: Bool = true) { self.value = v; self.available = available } }
    public var dims: [SuitabilityDimension: Dim]
    public var evidenceConfidence: Double           // overall evidence confidence (0..1)
    public var hardShieldMatch: Bool                // user hard Shield matched (precedence over benefit)
    public var safetyFloorViolation: Bool           // system safety floor (precedence over everything)
    public var calibrationValid: Bool               // calibration valid for this language/modality
    public var minCoverage: Double                  // gate: minimum coverage to show a score
    public var childApplicable: Bool
    public init(dims: [SuitabilityDimension: Dim], evidenceConfidence: Double, hardShieldMatch: Bool = false,
                safetyFloorViolation: Bool = false, calibrationValid: Bool = false, minCoverage: Double = 0.5,
                childApplicable: Bool = false) {
        self.dims = dims; self.evidenceConfidence = evidenceConfidence; self.hardShieldMatch = hardShieldMatch
        self.safetyFloorViolation = safetyFloorViolation; self.calibrationValid = calibrationValid
        self.minCoverage = minCoverage; self.childApplicable = childApplicable
    }
}

/// Deterministic Phase-1 fusion. Weights are VERSIONED SEED weights (expert-set, NOT claimed scientific/calibrated).
public struct SuitabilityFusionV1: Sendable {
    public static let seedWeightsRevision = "seed-weights-v1-UNCALIBRATED"
    // Seed weights (sum of positive contributions); pressure/load are penalties. NOT calibrated — see P008_SCORE_CONTRACT.
    private let w: [SuitabilityDimension: Double] = [
        .safetyAlignment: 0.30, .topicAlignment: 0.22, .benefit: 0.20, .positiveExposure: 0.12,
        .attentionPressure: 0.10, .emotionalLoad: 0.06
    ]
    public init() {}

    public func fuse(_ i: SuitabilityFusionInput, policyRevision: String, contentDNARevision: String,
                     modelPackRevision: String) -> PersonalSuitabilityScoreV1 {
        let available = i.dims.filter { $0.value.available }
        let expected = Double(SuitabilityDimension.allCases.count - (i.childApplicable ? 0 : 1))   // childPolicy optional
        let coverage = min(1, Double(available.count) / max(1, expected))
        var reasons: [SuitabilityReason] = []
        var dimOut: [SuitabilityDimension: Double] = [:]
        for (d, v) in i.dims { dimOut[d] = v.value }

        // ----- Hard precedence (ADR-0007): safety floor > hard Shield > numeric score. These can force the band. -----
        if i.safetyFloorViolation {
            return PersonalSuitabilityScoreV1(score: nil, scoreBand: .strongProtection, confidence: i.evidenceConfidence,
                evidenceCoverage: coverage, admissionState: .hideIfControlled, reasonCodes: [.safetyFloor],
                dimensionScores: dimOut, calibrationRevision: Self.seedWeightsRevision, policyRevision: policyRevision,
                contentDNARevision: contentDNARevision, modelPackRevision: modelPackRevision)
        }
        if i.hardShieldMatch {
            reasons.append(.hardShield)
            return PersonalSuitabilityScoreV1(score: nil, scoreBand: .strongProtection, confidence: i.evidenceConfidence,
                evidenceCoverage: coverage, admissionState: .hideIfControlled, reasonCodes: reasons,
                dimensionScores: dimOut, calibrationRevision: Self.seedWeightsRevision, policyRevision: policyRevision,
                contentDNARevision: contentDNARevision, modelPackRevision: modelPackRevision)
        }

        // ----- Evidence/calibration GATE: without enough coverage OR valid calibration, show NO number (UNKNOWN). -----
        guard coverage >= i.minCoverage, i.calibrationValid else {
            reasons.append(coverage < i.minCoverage ? .insufficientCoverage : .calibrationUnavailable)
            return PersonalSuitabilityScoreV1(score: nil, scoreBand: .unknown, confidence: i.evidenceConfidence,
                evidenceCoverage: coverage, admissionState: .unknown, reasonCodes: reasons, dimensionScores: dimOut,
                calibrationRevision: Self.seedWeightsRevision, policyRevision: policyRevision,
                contentDNARevision: contentDNARevision, modelPackRevision: modelPackRevision)
        }

        // ----- Transparent weighted fusion (only available dims; renormalize). Pressure/load are penalties. -----
        func val(_ d: SuitabilityDimension) -> Double? { i.dims[d]?.available == true ? i.dims[d]?.value : nil }
        var pos = 0.0, posW = 0.0
        for d in [SuitabilityDimension.safetyAlignment, .topicAlignment, .benefit, .positiveExposure] {
            if let v = val(d) { pos += (w[d] ?? 0) * v; posW += (w[d] ?? 0) }
        }
        let positive = posW > 0 ? pos / posW : 0.5
        let pressurePenalty = (val(.attentionPressure) ?? 0) * (w[.attentionPressure] ?? 0)
        let loadPenalty = (val(.emotionalLoad) ?? 0) * (w[.emotionalLoad] ?? 0)
        var raw = positive - pressurePenalty - loadPenalty
        raw = max(0, min(1, raw))
        var score = Int((raw * 100).rounded())
        // Explicit floor/cap: low safety alignment caps suitability.
        if let s = val(.safetyAlignment), s < 0.3 { score = min(score, 39); reasons.append(.safetyCap) }
        if i.childApplicable, let c = val(.childPolicy), c < 0.5 { score = min(score, 39); reasons.append(.childPolicyCap) }
        let band = ScoreBand.fromScore(score)
        reasons.append(.scored)
        let admission: AdmissionState = score >= 60 ? .approve : (score >= 40 ? .approveWithCaution : .notRecommended)
        return PersonalSuitabilityScoreV1(score: score, scoreBand: band, confidence: i.evidenceConfidence,
            evidenceCoverage: coverage, admissionState: admission, reasonCodes: reasons, dimensionScores: dimOut,
            calibrationRevision: Self.seedWeightsRevision, policyRevision: policyRevision,
            contentDNARevision: contentDNARevision, modelPackRevision: modelPackRevision)
    }
}
