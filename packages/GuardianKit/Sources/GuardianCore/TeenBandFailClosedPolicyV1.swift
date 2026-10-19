import Foundation

// MARK: - P009E §1 — F-5 closeout: WRITTEN, VERSIONED teen-band (13–17) fail-closed policy.
//
// WHY THIS POLICY EXISTS (mandated documentation):
// The independent P009D audit proved (F-5 MEDIUM) that a guardian-attested teen (e.g. 14) viewing
// sentinel-class sexual-theme content could resolve to AGE_ALIGNED + NEUTRAL, because the relevant
// safety dimensions are UNAVAILABLE and the under-13 H1 law did not extend to teens. That contradicted
// the sentinel doctrine ("high-risk/sentinel child cases must never become neutral/false-safe").
//
// WHAT THIS IS — AND IS NOT:
// This is a POLICY RESPONSE TO EVIDENCE UNAVAILABILITY, not detection. The trigger lexicon below routes
// sentinel-RELEVANT contexts to fail-closed review for minors; it never convicts, never scores, never
// claims the content IS explicit/harmful. Detection capability remains honestly UNAVAILABLE (H1 et al).
// Legal-vs-developmental separation and H1 honesty are preserved (source class + H1 code unchanged).

public enum TeenBandFailClosedPolicyV1 {
    public static let version = "teen-band-fail-closed-policy-v1"
    public static let teenRange = 13...17

    /// Sentinel-context TRIGGER lexicon (versioned policy data; exact-token/phrase via LexiconMatcherV2;
    /// heuristic ROUTING only — class: HEURISTIC_SUPPORT_ONLY, never a safety verdict).
    public static let triggerLexicon: [SafetyDimensionV1: [String: [String]]] = {
        var t: [SafetyDimensionV1: [String: [String]]] = [:]
        t[.explicitSexual] = ["en": ["explicit", "nsfw", "18+", "adults only", "sexual", "erotic"],
                              "tr": ["müstehcen", "erotik", "cinsellik", "cinsel", "yetişkinlere özel"]]
        t[.selfHarm] = ["en": ["self-harm", "suicide"], "tr": ["intihar", "kendine zarar"]]
        t[.drugsAlcohol] = ["en": ["drugs", "narcotics"], "tr": ["uyuşturucu", "narkotik"]]
        t[.gambling] = ["en": ["casino", "betting"], "tr": ["kumar", "bahis"]]
        t[.dangerousBehavior] = ["en": ["deadly challenge", "dangerous stunt", "dangerous challenge"],
                                 "tr": ["tehlikeli meydan okuma", "ölümcül akım"]]
        return t
    }()
    /// The canonical evidence label the mesh emits when a trigger fires (safety: prefix — persistence-law
    /// closed set is extended with exactly these literals).
    public static func contextLabel(_ d: SafetyDimensionV1) -> String { "safety:sentinel-context:\(d.rawValue)" }
    public static var allContextLabels: [String] { triggerLexicon.keys.map { contextLabel($0) } }

    /// Scan derived text for sentinel-context triggers (called by SafetyEvidenceExpertV1).
    public static func triggers(in text: String, language: String?) -> [SafetyDimensionV1] {
        var out: [SafetyDimensionV1] = []
        for (dim, lex) in triggerLexicon {
            if LexiconMatcherV2.hits(text, lexicon: lex, language: language) > 0 { out.append(dim) }
        }
        return out.sorted { $0.rawValue < $1.rawValue }
    }

    public struct TeenDecisionV1: Sendable {
        public let appliesFailClosed: Bool
        public let triggeredDimensions: [SafetyDimensionV1]
        public let educationalQualifier: Bool              // qualifies the review — never erases it
        public let reasons: [PolicyProvenanceV1]
    }

    /// THE LAW: teen (13–17) + sentinel-context trigger whose dimension is UNAVAILABLE
    /// → outcome floor AGE_UNKNOWN_REVIEW (never AGE_ALIGNED; admission never NEUTRAL).
    /// Educational-mention context is RECORDED as a qualifier but cannot erase the review.
    public static func evaluate(profile: GuardianEnteredChildProfileV1, worldModel m: ContentWorldModelV1) -> TeenDecisionV1 {
        guard teenRange.contains(profile.ageYears) else {
            return TeenDecisionV1(appliesFailClosed: false, triggeredDimensions: [], educationalQualifier: false, reasons: [])
        }
        let triggered = SafetyDimensionV1.allCases.filter { dim in
            m.safetyEvidence.contains(contextLabel(dim)) && SafetyDimensionTruthV1.status[dim] == .unavailable
        }
        guard !triggered.isEmpty else {
            return TeenDecisionV1(appliesFailClosed: false, triggeredDimensions: [], educationalQualifier: false, reasons: [])
        }
        let educational = m.episodes.contains { $0.contextTags.contains(.educationalMention) }
        var reasons = triggered.map { dim in
            PolicyProvenanceV1(code: .teenSentinelUnavailableReview, producer: version,
                               basis: "teen \(profile.ageYears) + \(contextLabel(dim)) + dimension UNAVAILABLE → fail-closed review (policy, not detection)")
        }
        if educational {
            reasons.append(PolicyProvenanceV1(code: .contextQualifiedRisk, producer: version,
                                              basis: "educational-mention qualifies the review — does not erase it"))
        }
        return TeenDecisionV1(appliesFailClosed: true, triggeredDimensions: triggered,
                              educationalQualifier: educational, reasons: reasons)
    }
}
