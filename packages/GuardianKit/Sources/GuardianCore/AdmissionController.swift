import Foundation

// MARK: - Admission Controller (deterministic precedence — ADR-0007 / D-0015)
// LEGAL/SECURITY > CHILD SAFETY FLOOR > MALICIOUS/EXTREME-SAFETY SIGNAL > USER HARD SEMANTIC SHIELD
//   > PERSONAL PROTECTION POLICY (Positive Exposure) > PERSONAL ALGORITHM THRESHOLD > BENEFIT > EXPLORATION.
// Deterministic & reproducible: same inputs + versions ⇒ same decision. No arm has unilateral authority.

public struct ShieldMatch: Sendable, Equatable {
    public enum Confidence: String, Sendable { case high, medium }
    public let rule: SemanticShieldRule
    public let confidence: Confidence
}

public struct AdmissionInputs: Sendable {
    public let contentID: ContentID
    public let identity: ContentIdentityResult
    public let signals: FixtureSignals?
    public let score: PBSResult
    public let profile: PersonalAlgorithmProfile
    public let safety: SafetyPolicy
    /// Fixture-level legal/security block & malicious-signal hooks (contract completeness).
    public let legalSecurityBlock: Bool
    public let maliciousSafetySignal: Bool
    public init(contentID: ContentID, identity: ContentIdentityResult, signals: FixtureSignals?, score: PBSResult,
                profile: PersonalAlgorithmProfile, safety: SafetyPolicy,
                legalSecurityBlock: Bool = false, maliciousSafetySignal: Bool = false) {
        self.contentID = contentID
        self.identity = identity
        self.signals = signals
        self.score = score
        self.profile = profile
        self.safety = safety
        self.legalSecurityBlock = legalSecurityBlock
        self.maliciousSafetySignal = maliciousSafetySignal
    }
}

public struct AdmissionController: Sendable {
    public init() {}

    /// Find the strongest Semantic Shield match (category/entity = high; concept/topic = medium).
    public func matchShield(_ signals: FixtureSignals?, rules: [SemanticShieldRule]) -> ShieldMatch? {
        guard let s = signals else { return nil }
        var best: ShieldMatch?
        for rule in rules {
            switch rule.kind {
            case .category:
                if let cat = SensitiveCategory(rawValue: rule.value), s.sensitiveCategories.contains(cat) {
                    best = ShieldMatch(rule: rule, confidence: .high)
                }
            case .entity:
                if s.entities.contains(rule.value) {
                    best = ShieldMatch(rule: rule, confidence: .high)
                }
            case .concept:
                if s.topics.contains(where: { $0.caseInsensitiveCompare(rule.value) == .orderedSame }) {
                    if best == nil { best = ShieldMatch(rule: rule, confidence: .medium) }
                }
            }
            if best?.confidence == .high { break }
        }
        return best
    }

    public func decide(_ i: AdmissionInputs) -> AdmissionDecision {
        let controlled = i.profile.controlledSurface

        // 0. Insufficient / conflicting evidence ⇒ truthful UNKNOWN (never a stale safe state).
        if i.score.state == .insufficientEvidence || i.score.state == .conflicting {
            return make(i, .unknown, .none, .insufficientEvidence,
                        "Insufficient/conflicting evidence — showing UNKNOWN (?). No safe state is implied.")
        }

        // 1. LEGAL / SECURITY.
        if i.legalSecurityBlock {
            return make(i, controlled ? .hideIfControlled : .notRecommended, .high, .legalSecurity,
                        "Blocked by legal/security policy (highest precedence).")
        }

        // 2. CHILD SAFETY FLOOR (verified guardian authority assumed via SafetyPolicy fixture).
        if i.safety.childMode, let s = i.signals,
           !s.sensitiveCategories.isDisjoint(with: i.safety.blockedCategoriesForChild) {
            return make(i, controlled ? .hideIfControlled : .notRecommended, .high, .childSafetyFloor,
                        "Child-safety floor: contains a category blocked for child mode.")
        }

        // 3. MALICIOUS / EXTREME HIGH-CONFIDENCE SAFETY SIGNAL.
        if i.maliciousSafetySignal {
            return make(i, controlled ? .hideIfControlled : .notRecommended, .high, .maliciousSafetySignal,
                        "High-confidence malicious/extreme-safety signal.")
        }

        // 4. USER HARD SEMANTIC SHIELD (outranks threshold). Low-confidence must NOT silently hard-hide.
        let hardRules = i.profile.shieldRules.filter { $0.hard }
        if let m = matchShield(i.signals, rules: hardRules) {
            if m.confidence == .high {
                return make(i, controlled ? .hideIfControlled : .notRecommended, .high, .userHardSemanticShield,
                            "Matched your hard exclusion (\(m.rule.kind.rawValue): \(m.rule.value)). This overrides the score threshold.")
            } else {
                // medium-confidence concept match → caution + warn, do NOT hard-hide.
                return make(i, .approveWithCaution, .low, .userHardSemanticShield,
                            "Possible match to an excluded concept (\(m.rule.value)) but confidence is low — surfaced as caution, not hidden.")
            }
        }

        // 5. PERSONAL PROTECTION POLICY — Positive Exposure (separate from Truth/Evidence).
        if let s = i.signals, !s.sensitiveCategories.isDisjoint(with: i.profile.positiveExposure.avoid) {
            let truthNote = s.factuallyCorrect ? "The item may be factually correct; Truth/Evidence is unchanged." :
                                                 "Factual accuracy is independent of this policy."
            return make(i, .notRecommended, .medium, .personalProtectionPolicy,
                        "Down-ranked by your Positive Exposure policy (category you chose to avoid). \(truthNote)")
        }

        // 6. PERSONAL ALGORITHM THRESHOLD.
        if let value = i.score.value {
            let conf: AdmissionConfidence = (i.score.state == .verifiedFast) ? .high : .medium
            if value + 1e-9 >= i.profile.minimumPersonalScore {
                return make(i, .approve, conf, .personalAlgorithmThreshold,
                            "Score \(i.score.display) ≥ your threshold \(fmt(i.profile.minimumPersonalScore)).")
            } else {
                return make(i, .notRecommended, conf, .personalAlgorithmThreshold,
                            "Score \(i.score.display) < your threshold \(fmt(i.profile.minimumPersonalScore)).")
            }
        }

        // Fallback (should not reach): unknown.
        return make(i, .unknown, .none, .insufficientEvidence, "No decision path produced a result — UNKNOWN.")
    }

    private func fmt(_ d: Double) -> String { String(format: "%.1f", d) }

    private func make(_ i: AdmissionInputs, _ state: AdmissionState, _ conf: AdmissionConfidence,
                      _ reason: DecisionReason, _ explanation: String) -> AdmissionDecision {
        AdmissionDecision(contentID: i.contentID, state: state, confidence: conf, reason: reason,
                          score: i.score, explanation: explanation, identityState: i.identity.state)
    }
}
