import Foundation

// MARK: - Shield evaluator + global admission separation (006B §2,§3,§4)
// The Shield layer produces a PersonalShieldDecision and MAY ABSTAIN. Only the Global Admission Controller may HOLD,
// and only under explicit strict policy. A missing matcher for one modality never poisons unrelated items.

public struct ShieldEvaluationInput: Sendable {
    public var envelope: ContentObservationEnvelope
    public var controlledSurface: Bool
    public var userInitiated: Bool
    public var matchedSource: String?
    public var nowEpoch: Double
    public init(envelope: ContentObservationEnvelope, controlledSurface: Bool = false,
                userInitiated: Bool = false, matchedSource: String? = nil, nowEpoch: Double = 0) {
        self.envelope = envelope; self.controlledSurface = controlledSurface
        self.userInitiated = userInitiated; self.matchedSource = matchedSource; self.nowEpoch = nowEpoch
    }
}

/// 006B §2 — the Shield layer's own output contract. Separate from global admission.
public struct PersonalShieldDecision: Sendable, Equatable {
    public let ruleID: String?
    public let matchState: ShieldMatchState
    public let layerDecision: ShieldLayerDecision
    public let actionRecommendation: ShieldAction?
    public let coverage: Double            // fraction of the winning rule's expected matchers that could run [0,1]
    public let missingMatchers: [String]   // matcher ids that were unavailable / could not determine
    public let uncertainty: Double         // 0 = fully determinable, 1 = entirely non-determinable
    public let reasonCodes: [ShieldReasonCode]
    public let exceptionApplied: Bool
    public let evaluatedRules: Int
    public let matchersRun: Int
    public static let clear = PersonalShieldDecision(ruleID: nil, matchState: .noMatch, layerDecision: .noShieldAction,
                                             actionRecommendation: nil, coverage: 1, missingMatchers: [], uncertainty: 0,
                                             reasonCodes: [.none], exceptionApplied: false, evaluatedRules: 0, matchersRun: 0)
    public init(ruleID: String?, matchState: ShieldMatchState, layerDecision: ShieldLayerDecision,
                actionRecommendation: ShieldAction?, coverage: Double, missingMatchers: [String], uncertainty: Double,
                reasonCodes: [ShieldReasonCode], exceptionApplied: Bool, evaluatedRules: Int, matchersRun: Int) {
        self.ruleID = ruleID; self.matchState = matchState; self.layerDecision = layerDecision
        self.actionRecommendation = actionRecommendation; self.coverage = coverage; self.missingMatchers = missingMatchers
        self.uncertainty = uncertainty; self.reasonCodes = reasonCodes; self.exceptionApplied = exceptionApplied
        self.evaluatedRules = evaluatedRules; self.matchersRun = matchersRun
    }
}

public struct ShieldEvaluatorV2: Sendable {
    private let matchers: [ShieldMatcher]
    private let controller = ShieldActionControllerV2()
    private let exceptions = ShieldExceptionEngine()
    public init(matchers: [ShieldMatcher]) { self.matchers = matchers }

    public static func standard(semanticDistance: (@Sendable (String, String, String) -> Double?)? = nil,
                                bridge: CrossLanguageConceptBridge = DefaultCrossLanguageBridge()) -> ShieldEvaluatorV2 {
        var m: [ShieldMatcher] = [ExactTextMatcher(), AliasEntityMatcher(), SourceMatcher(), SoundClassMatcher()]
        if let d = semanticDistance { m.append(SemanticTextMatcher(distance: d, bridge: bridge)) }
        else { m.append(SemanticTextMatcher(distance: { _, _, _ in nil }, bridge: bridge)) }
        return ShieldEvaluatorV2(matchers: m)
    }

    public func evaluate(_ input: ShieldEvaluationInput, index: ShieldIndex, exceptions exList: [ShieldException] = []) -> PersonalShieldDecision {
        let candidates = index.shortlist(envelope: input.envelope, nowEpoch: input.nowEpoch)
        guard !candidates.isEmpty else { return .clear }

        var best = ShieldMatchResult.noMatch("", matcherID: "")
        var bestRule: ShieldRuleV2?
        var matchersRun = 0
        var missing: [String] = []
        var expectedForBest = 1
        var ranForBest = 0
        var sawConflict = false

        for rule in candidates {
            // 006B §3 — route only the matchers this rule actually requires.
            let allowed = rule.effectiveMatchers
            let applicable = matchers.filter { allowed.contains($0.id.rawValue) && $0.handles(rule.inputType) }
            var ruleBest = ShieldMatchResult.noMatch(rule.ruleID, matcherID: "")
            var ruleMissing: [String] = []
            var ran = 0
            for matcher in applicable {
                matchersRun += 1; ran += 1
                let r = matcher.match(rule: rule, envelope: input.envelope)
                if r.state == .evidenceConflict { sawConflict = true }
                if r.state.isNonDeterminable { ruleMissing.append(matcher.id.rawValue) }
                if r.state.matchRank > ruleBest.state.matchRank { ruleBest = r }
            }
            // This rule wins if its actual match is stronger than the current best.
            if ruleBest.state.matchRank > best.state.matchRank {
                best = ruleBest; bestRule = rule; missing = ruleMissing
                expectedForBest = max(1, applicable.count); ranForBest = ran
            }
        }

        // No rule produced an actual match → clear (non-determinable matchers never fabricate a match).
        guard let rule = bestRule, best.state.isMatch else {
            return PersonalShieldDecision(ruleID: nil, matchState: .noMatch, layerDecision: .noShieldAction, actionRecommendation: nil,
                                  coverage: 1, missingMatchers: [], uncertainty: 0, reasonCodes: [.none],
                                  exceptionApplied: false, evaluatedRules: candidates.count, matchersRun: matchersRun)
        }

        // Exceptions (child/guardian precedence enforced inside the engine).
        if exceptions.allows(rule: rule, exceptions: exList, matchedSource: input.matchedSource, userInitiated: input.userInitiated) {
            return PersonalShieldDecision(ruleID: rule.ruleID, matchState: best.state, layerDecision: .noShieldAction, actionRecommendation: .allow,
                                  coverage: 1, missingMatchers: missing, uncertainty: 0, reasonCodes: [best.reason],
                                  exceptionApplied: true, evaluatedRules: candidates.count, matchersRun: matchersRun)
        }

        var state = best.state
        if sawConflict && state.isMatch { state = .evidenceConflict }
        let (layer, action) = controller.decide(rule: rule, match: state)
        let coverage = Double(ranForBest - missing.count) / Double(expectedForBest)
        let uncertainty = missing.isEmpty ? 0 : Double(missing.count) / Double(max(1, expectedForBest))
        return PersonalShieldDecision(ruleID: rule.ruleID, matchState: state, layerDecision: layer, actionRecommendation: action,
                              coverage: max(0, min(1, coverage)), missingMatchers: missing, uncertainty: uncertainty,
                              reasonCodes: [best.reason], exceptionApplied: false,
                              evaluatedRules: candidates.count, matchersRun: matchersRun)
    }
}

// MARK: - Global Admission Controller (006B §2,§4) — the ONLY place strict HOLD may originate.
public enum AdmissionMode: String, Sendable, Codable { case normal = "NORMAL", strictNoExposureIfUnverified = "STRICT_NO_EXPOSURE_IF_UNVERIFIED" }
public enum GlobalAdmissionState: String, Sendable, Codable { case proceed = "PROCEED", caution = "CAUTION", unknown = "UNKNOWN", hold = "HOLD" }
public enum AdmissionReason: String, Sendable, Codable {
    case shieldExecute = "ADMIT_SHIELD_EXECUTE", shieldWarn = "ADMIT_SHIELD_WARN", shieldAsk = "ADMIT_SHIELD_ASK"
    case shieldNote = "ADMIT_SHIELD_NOTE", noShieldDecision = "ADMIT_NO_SHIELD_DECISION"
    case strictHoldUnverified = "ADMIT_STRICT_HOLD_UNVERIFIED", proceedOtherEvidence = "ADMIT_PROCEED_OTHER_EVIDENCE"
}

public struct GlobalAdmissionResult: Sendable, Equatable {
    public let state: GlobalAdmissionState
    public let reasons: [AdmissionReason]
    public init(state: GlobalAdmissionState, reasons: [AdmissionReason]) { self.state = state; self.reasons = reasons }
}

public struct GlobalAdmissionController: Sendable {
    public init() {}
    /// `modalityExpectedButUnavailable`: a modality the rule needed was actually present/expected yet its matcher
    /// could not run. Only THEN, under strict policy and a controlled surface, may global admission HOLD.
    public func admit(shield: PersonalShieldDecision, mode: AdmissionMode, controlledSurface: Bool,
                      modalityExpectedButUnavailable: Bool) -> GlobalAdmissionResult {
        switch shield.layerDecision {
        case .execute: return .init(state: .hold, reasons: [.shieldExecute]) // user's own hard rule matched → honor it
        case .warn:    return .init(state: .caution, reasons: [.shieldWarn])
        case .ask:     return .init(state: .caution, reasons: [.shieldAsk])
        case .note:    return .init(state: .proceed, reasons: [.shieldNote])
        case .noShieldAction:
            return .init(state: .proceed, reasons: [.proceedOtherEvidence])
        case .noShieldDecision:
            // 006B §1/§4 — abstention is NOT a match and NOT auto-hold. Strict mode is the only exception.
            if mode == .strictNoExposureIfUnverified && controlledSurface && modalityExpectedButUnavailable {
                return .init(state: .hold, reasons: [.strictHoldUnverified])
            }
            return .init(state: .proceed, reasons: [.noShieldDecision, .proceedOtherEvidence])
        }
    }
}
