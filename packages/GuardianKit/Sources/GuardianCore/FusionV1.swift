import Foundation

// MARK: - Semantic Shield decision (shared type) + Score/Admission Fusion V1 + Explanation (PROMPT 003 §9,§16,§17)
// Deterministic, versioned fusion over STRUCTURED signals. No averaging of head probabilities.
// Truth/Evidence stays separate from exposure policy. No numeric score below evidence-coverage threshold.

public struct ShieldDecision: Sendable, Equatable, Codable {
    public enum Tier: String, Sendable, Codable { case none, low, medium, high }
    public enum Action: String, Sendable, Codable { case none, caution, exclude }
    public let matched: String?
    public let tier: Tier
    public let action: Action
    public init(matched: String?, tier: Tier, action: Action) { self.matched = matched; self.tier = tier; self.action = action }
    public static let noMatch = ShieldDecision(matched: nil, tier: .none, action: .none)
}

/// Map topic labels → Positive-Exposure sensitive categories (topic presence, NOT truth).
public func sensitiveCategory(for label: MortalityDiseaseDisasterLabel) -> SensitiveCategory? {
    switch label {
    case .mortality: return .death
    case .diseaseIllness: return .disease
    case .disaster: return .disaster
    case .severeAccident: return .severeAccident
    case .warConflict: return .violentConflict
    case .medicalHospital, .noneOfAbove, .unknown: return nil
    }
}

public struct FusionInputsV1: Sendable {
    public let contentID: ContentID
    public let mddLabels: [MortalityDiseaseDisasterLabel]
    public let mddConfidence: Double?
    public let manipulation: ManipulationSignals?
    public let shield: ShieldDecision
    public let benefit: PersonalBenefitVector?
    public let profile: PersonalAlgorithmProfile
    public let positiveMode: PositiveExposureMode
    public let childPolicy: SafetyPolicy
    public let availableHeadCount: Int
    public let requiredHeadCount: Int
    public init(contentID: ContentID, mddLabels: [MortalityDiseaseDisasterLabel] = [], mddConfidence: Double? = nil,
                manipulation: ManipulationSignals? = nil, shield: ShieldDecision = .noMatch,
                benefit: PersonalBenefitVector? = nil, profile: PersonalAlgorithmProfile,
                positiveMode: PositiveExposureMode = .balancedPositive, childPolicy: SafetyPolicy = .init(),
                availableHeadCount: Int = 0, requiredHeadCount: Int = 2) {
        self.contentID = contentID; self.mddLabels = mddLabels; self.mddConfidence = mddConfidence
        self.manipulation = manipulation; self.shield = shield; self.benefit = benefit; self.profile = profile
        self.positiveMode = positiveMode; self.childPolicy = childPolicy
        self.availableHeadCount = availableHeadCount; self.requiredHeadCount = requiredHeadCount
    }
}

public struct FusionResultV1: Sendable, Equatable {
    public let contentID: ContentID
    public let admission: AdmissionState
    public let scoreState: ScoreState
    public let score: Double?                 // nil unless evidence sufficient + eligible
    public let reasons: [ReasonCode]
    public let confidence: AdmissionConfidence
    public let explanation: String
}

/// Deterministic fusion. Precedence follows ADR-0007 over structured signals.
public struct ScoreAdmissionFusionV1: Sendable {
    public static let version = "fusion-v1"
    public init() {}

    public func decide(_ i: FusionInputsV1) -> FusionResultV1 {
        let controlled = i.profile.controlledSurface
        func r(_ a: AdmissionState, _ ss: ScoreState, _ score: Double?, _ reasons: [ReasonCode],
               _ c: AdmissionConfidence, _ ex: String) -> FusionResultV1 {
            FusionResultV1(contentID: i.contentID, admission: a, scoreState: ss, score: score,
                           reasons: reasons, confidence: c, explanation: ex)
        }

        // 0. Evidence coverage gate — NO numeric score below threshold.
        if i.availableHeadCount < i.requiredHeadCount {
            return r(.unknown, .insufficientEvidence, nil, [.lowEvidence], .none,
                     "Insufficient evidence coverage (\(i.availableHeadCount)/\(i.requiredHeadCount) heads) — UNKNOWN, no score.")
        }

        // 1. CHILD SAFETY FLOOR (verified guardian authority via policy).
        if i.childPolicy.childMode {
            let cats = Set(i.mddLabels.compactMap { sensitiveCategory(for: $0) })
            if !cats.isDisjoint(with: i.childPolicy.blockedCategoriesForChild) {
                return r(controlled ? .hideIfControlled : .notRecommended, .provisionalFast, nil,
                         [.childPolicyBlock], .high, "Child-safety floor: blocked category present.")
            }
        }

        // 2. USER HARD SEMANTIC SHIELD (outranks threshold). Low confidence must NOT silently hide.
        switch i.shield.tier {
        case .high where i.shield.action == .exclude:
            return r(controlled ? .hideIfControlled : .notRecommended, .provisionalFast, nil,
                     [.semanticShieldEntityMatch], .high,
                     "Matched your exclusion (\(i.shield.matched ?? "concept")) with high confidence — overrides threshold.")
        case .medium:
            return r(.approveWithCaution, .provisionalFast, nil, [.semanticShieldLowConfidence], .low,
                     "Possible match to an excluded concept (\(i.shield.matched ?? "")) — surfaced as caution, not hidden.")
        default: break
        }

        // 3. PERSONAL PROTECTION — Positive Exposure (separate from Truth/Evidence).
        let present = Set(i.mddLabels.compactMap { sensitiveCategory(for: $0) })
        let avoided = present.intersection(i.profile.positiveExposure.avoid)
        if !avoided.isEmpty {
            switch i.positiveMode {
            case .protectedPositive:
                let code: ReasonCode = avoided.contains(.disease) ? .positiveExposureDisease : .positiveExposureCategory
                return r(.notRecommended, .provisionalFast, nil, [code], .medium,
                         "Down-ranked by Positive Exposure (\(avoided.map{$0.rawValue}.joined(separator: ","))). Truth/Evidence is independent and unchanged.")
            case .balancedPositive, .openWithWarnings:
                return r(.approveWithCaution, .provisionalFast, nil, [.positiveExposureCategory], .medium,
                         "Contains an avoided category (\(avoided.map{$0.rawValue}.joined(separator: ","))) — shown with warning. Truth/Evidence unchanged.")
            }
        }

        // 4. Manipulation pressure (observed) → caution (never auto-hide on observed lexical signals alone).
        if let m = i.manipulation, m.total >= 3 {
            return r(.approveWithCaution, .provisionalFast, nil, [.manipulationPressureHigh], .medium,
                     "High observed attention/manipulation pressure (count \(m.total)).")
        }

        // 5. Personal benefit → deterministic provisional scalar vs threshold (only with coverage met).
        if let b = i.benefit {
            let benefitScalar = provisionalBenefit(b)   // 0..10, deterministic, versioned
            if benefitScalar + 1e-9 >= i.profile.minimumPersonalScore {
                return r(.approve, .provisionalFast, benefitScalar, [.thresholdMet], .medium,
                         String(format: "Provisional benefit %.1f ≥ threshold %.1f.", benefitScalar, i.profile.minimumPersonalScore))
            } else {
                return r(.notRecommended, .provisionalFast, benefitScalar, [.thresholdNotMet, .personalGoalLowAlignment], .medium,
                         String(format: "Provisional benefit %.1f < threshold %.1f.", benefitScalar, i.profile.minimumPersonalScore))
            }
        }

        // No benefit vector but coverage met → neutral approve-with-caution, no number.
        return r(.approveWithCaution, .insufficientEvidence, nil, [.lowEvidence], .low,
                 "Coverage met but no benefit vector — no numeric score produced.")
    }

    /// Deterministic provisional benefit scalar (versioned). NOT an LLM score; requires ScoreContract for production.
    public func provisionalBenefit(_ b: PersonalBenefitVector) -> Double {
        let positive = 0.25*b.learning + 0.2*b.skill + 0.2*b.practicalUsefulness + 0.1*b.creativity
                     + 0.1*b.criticalThinking + 0.1*b.hopeMeaning + 0.05*b.entertainment
        let penalty = 0.4*b.fearAngerDespairLoad + 0.5*b.manipulationPressure
        let raw = max(0, min(1, positive - penalty))
        return (raw * 10 * 10).rounded() / 10
    }
}

// MARK: Explanation Engine V1 — reason codes → short human text (no chain-of-thought)
public struct ExplanationEngineV1: Sendable {
    public init() {}
    public func text(for reasons: [ReasonCode]) -> String {
        reasons.map { code in
            switch code {
            case .topicExcluded: return "Excluded topic."
            case .graphicContentHighConfidence: return "Graphic content (high confidence)."
            case .positiveExposureDisease: return "Positive Exposure: disease topic avoided (truth unchanged)."
            case .positiveExposureCategory: return "Positive Exposure: avoided category."
            case .semanticShieldEntityMatch: return "Matched your exclusion."
            case .semanticShieldLowConfidence: return "Possible excluded concept (low confidence)."
            case .lowEvidence: return "Insufficient evidence."
            case .personalGoalLowAlignment: return "Low alignment to your goals."
            case .childPolicyBlock: return "Blocked by child-safety policy."
            case .thresholdMet: return "Meets your score threshold."
            case .thresholdNotMet: return "Below your score threshold."
            case .manipulationPressureHigh: return "High attention/manipulation pressure."
            }
        }.joined(separator: " ")
    }
}
