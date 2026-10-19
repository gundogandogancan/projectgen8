import Foundation

// MARK: - P009D §13/§14 — rights-clear POLICY corpus. Scenarios drive the LIVE mesh → world model →
// admission pipeline. Seedless split-authored banks (R1 F2 law). CAPABILITY TRUTH IS THE POINT of many
// families: dimensions without audited capability (drugs/gambling/self-harm/explicit…) must produce
// fail-closed UNKNOWN/REVIEW/CAUTION — never a fake distinction and never a positive state.
// Annotation (§14): independent dual slots for subjective dimensions; disagreement preserved.

public struct P009DPolicyAnnotationV1: Sendable {
    public var expectedAdmission: Set<String> = []          // allowed AdmissionStateV1 raw values
    public var forbiddenAdmission: Set<String> = []
    public var requiredReasonCodes: Set<String> = []        // must appear (dominant or secondary)
    public var forbiddenReasonCodes: Set<String> = []
    public var expectedChildOutcome: String? = nil          // ChildAgeOutcomeV1 raw value
    public var severityAnnotatorA: String? = nil            // subjective severity band — slot A
    public var severityAnnotatorB: String? = nil            // slot B (disagreement preserved)
    public var contextQualifier: String? = nil
    public var expectShieldHardMatch: Bool? = nil
    public init() {}
    public var severityDisagreement: Bool { severityAnnotatorA != nil && severityAnnotatorA != severityAnnotatorB }
}

public struct P009DPolicyScenarioV1: Sendable {
    public let name: String
    public let family: String
    public let segments: [P009CSegmentV1]                   // reuse the semantic segment type
    public let childProfile: GuardianEnteredChildProfileV1?
    public let parentPreference: ParentPreferencePolicyV1
    public let shieldConfig: ShieldConfigV2?
    public let annotation: P009DPolicyAnnotationV1
    public init(name: String, family: String, segments: [P009CSegmentV1],
                childProfile: GuardianEnteredChildProfileV1? = nil,
                parentPreference: ParentPreferencePolicyV1 = ParentPreferencePolicyV1(),
                shieldConfig: ShieldConfigV2? = nil, annotation: P009DPolicyAnnotationV1) {
        self.name = name; self.family = family; self.segments = segments
        self.childProfile = childProfile; self.parentPreference = parentPreference
        self.shieldConfig = shieldConfig; self.annotation = annotation
    }
}

public enum P009DSplitV1: String, CaseIterable, Sendable { case tune = "TUNE", heldOut = "HELD_OUT", stress = "STRESS", ood = "OOD" }

public enum P009DPolicyCorpusV1 {
    public static let revision = "p009d-policy-corpus-v1"
    static func seg(_ s: Double, _ e: Double, _ i: ExpertInputV2, risk: Double = 0, topics: Set<String> = []) -> P009CSegmentV1 {
        P009CSegmentV1(startMs: s, endMs: e, input: i, temporalRisk: risk, temporalTopics: topics)
    }
    static func ann(_ f: (inout P009DPolicyAnnotationV1) -> Void) -> P009DPolicyAnnotationV1 {
        var a = P009DPolicyAnnotationV1(); f(&a); return a
    }
    static func child(_ age: Int, _ jur: String = "TR") -> GuardianEnteredChildProfileV1 {
        GuardianEnteredChildProfileV1(ageYears: age, jurisdictionCode: jur, enteredByGuardian: true)
    }

    public static func scenarios(_ split: P009DSplitV1) -> [P009DPolicyScenarioV1] {
        switch split {
        case .tune: return tune()
        case .heldOut: return heldOut()
        case .stress: return stress()
        case .ood: return ood()
        }
    }

    // ── TUNE — the 20 §13 families ──
    static func tune() -> [P009DPolicyScenarioV1] {
        var out: [P009DPolicyScenarioV1] = []
        out.append(P009DPolicyScenarioV1(name: "pd-educational-graphic", family: "educational-but-graphic",
            segments: [seg(0, 5000, ExpertInputV2(ocrText: "anatomy lesson: fatal injury cases explained for students",
                                                  detectedLanguage: "en"), risk: 0.7, topics: ["medical"])],
            annotation: ann { a in
                a.expectedAdmission = ["CAUTION", "STRONG_PROTECTION"]
                a.forbiddenAdmission = ["NEUTRAL"]
                a.requiredReasonCodes = ["BENEFIT_PRESENT_NOT_OVERRIDING"]
                a.severityAnnotatorA = "strong"; a.severityAnnotatorB = "present"
                a.contextQualifier = "context:educational-mention" }))
        out.append(P009DPolicyScenarioV1(name: "pd-humor-explicit-claim", family: "humorous-but-explicit",
            // explicit dimension is UNAVAILABLE — capability truth: no fake distinction, fail closed for child
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "lol parody sketch — adults only humor tonight",
                                                  detectedLanguage: "en"))],
            childProfile: child(9),
            annotation: ann { a in
                // "adults only" carries the scarcity token "only" → legitimate manipulation caution;
                // CAUTION is an acceptable §12 fail-closed state, with the H1 gap ALWAYS visible <13
                a.expectedChildOutcome = "AGE_CAUTION"
                a.forbiddenAdmission = ["NEUTRAL"]
                a.requiredReasonCodes = ["AGE_H1_REQUIRED_UNAVAILABLE"] }))
        out.append(P009DPolicyScenarioV1(name: "pd-selfharm-prevention-context", family: "prevention-context-self-harm",
            // self-harm dimension UNAVAILABLE — both prevention and encouragement MUST fail closed identically
            segments: [seg(0, 4000, ExpertInputV2(ocrText: "support hotline guide: how to help a friend in crisis",
                                                  detectedLanguage: "en"))],
            childProfile: child(12),
            annotation: ann { a in
                a.expectedChildOutcome = "AGE_UNKNOWN_REVIEW"
                a.forbiddenAdmission = ["NEUTRAL"]
                a.requiredReasonCodes = ["AGE_H1_REQUIRED_UNAVAILABLE"]
                a.forbiddenReasonCodes = [] }))
        out.append(P009DPolicyScenarioV1(name: "pd-selfharm-literal-claim", family: "literal-self-harm-encouragement",
            segments: [seg(0, 4000, ExpertInputV2(ocrText: "dangerous challenge everyone is trying tonight",
                                                  detectedLanguage: "en"))],
            childProfile: child(12),
            annotation: ann { a in
                a.expectedChildOutcome = "AGE_UNKNOWN_REVIEW"       // same fail-closed floor — no fake "safe" split
                a.forbiddenAdmission = ["NEUTRAL"] }))
        out.append(P009DPolicyScenarioV1(name: "pd-drug-education-vs-promotion", family: "drug-education-vs-promotion",
            segments: [seg(0, 4000, ExpertInputV2(ocrText: "madde bağımlılığı dersi: riskleri anlat", detectedLanguage: "tr"))],
            childProfile: child(14),
            annotation: ann { a in
                // drugs dimension UNAVAILABLE: engine may NOT invent a drug distinction; benefit/edu may
                // register but the admission must not be NEUTRAL-with-drug-clearance semantics
                a.forbiddenReasonCodes = []
                a.expectedAdmission = ["NEUTRAL", "CAUTION", "REVIEW", "UNKNOWN"]
                a.severityAnnotatorA = "unknown"; a.severityAnnotatorB = "present" }))
        out.append(P009DPolicyScenarioV1(name: "pd-gambling-news", family: "gambling-news-vs-promotion",
            segments: [seg(0, 4000, ExpertInputV2(ocrText: "breaking news report: casino scandal investigation deaths",
                                                  detectedLanguage: "en"), risk: 0.5, topics: ["news"])],
            annotation: ann { a in
                a.expectedAdmission = ["CAUTION", "STRONG_PROTECTION"]
                a.forbiddenAdmission = ["NEUTRAL"] }))
        out.append(P009DPolicyScenarioV1(name: "pd-profanity-quote", family: "profanity-quote-vs-insult",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "the witness said \"threats and death threats\" in court",
                                                  detectedLanguage: "en"))],
            annotation: ann { a in
                a.contextQualifier = "context:quoted"
                a.expectedAdmission = ["CAUTION"]
                a.requiredReasonCodes = ["CONTEXT_QUALIFIED_RISK"] }))
        out.append(P009DPolicyScenarioV1(name: "pd-child-fear", family: "frightening-child-content",
            segments: [seg(0, 4000, ExpertInputV2(ocrText: "korkunç canavar hikayesi: tehlike ve karanlık",
                                                  detectedLanguage: "tr"), risk: 0.5, topics: ["horror"])],
            childProfile: child(8),
            annotation: ann { a in
                a.expectedChildOutcome = "AGE_CAUTION"
                a.requiredReasonCodes = ["CHILD_AGE_CAUTION_FEAR"]
                a.expectedAdmission = ["AGE_CAUTION", "CAUTION"]
                a.severityAnnotatorA = "present"; a.severityAnnotatorB = "strong" }))
        out.append(P009DPolicyScenarioV1(name: "pd-mild-cartoon-violence", family: "mild-cartoon-violence",
            // violence dimension UNAVAILABLE — mild/severe CANNOT be distinguished; both fail closed for kids
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "funny cartoon chase lol", detectedLanguage: "en",
                                                  visualLabels: ["classroom"], visualConfidence: 0.5))],
            childProfile: child(7),
            annotation: ann { a in
                a.expectedChildOutcome = "AGE_UNKNOWN_REVIEW"
                a.requiredReasonCodes = ["AGE_H1_REQUIRED_UNAVAILABLE"]
                a.forbiddenAdmission = ["NEUTRAL"] }))
        out.append(P009DPolicyScenarioV1(name: "pd-severe-violence-lexical", family: "severe-realistic-violence",
            segments: [seg(0, 4000, ExpertInputV2(ocrText: "savaş görüntüleri: ölüm, bombardıman ve yıkım",
                                                  detectedLanguage: "tr", soundEvents: ["siren"]), risk: 0.9, topics: ["war"])],
            childProfile: child(9),
            annotation: ann { a in
                a.expectedAdmission = ["STRONG_PROTECTION"]
                a.requiredReasonCodes = ["STRONG_RISK_ESCALATION"]
                a.expectedChildOutcome = "AGE_RESTRICTED"
                a.severityAnnotatorA = "strong"; a.severityAnnotatorB = "strong" }))
        out.append(P009DPolicyScenarioV1(name: "pd-sexual-theme-age-band", family: "sexual-themes-by-age-band",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "romantic drama episode recap", detectedLanguage: "en"))],
            childProfile: child(11),
            annotation: ann { a in
                a.expectedChildOutcome = "AGE_UNKNOWN_REVIEW"       // sexualThemes UNAVAILABLE + under-13 H1 law
                a.forbiddenAdmission = ["NEUTRAL"] }))
        out.append(P009DPolicyScenarioV1(name: "pd-child-targeted-cta", family: "manipulative-child-targeted-CTA",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "hurry kids! click now, buy now, don't miss the toy drop",
                                                  detectedLanguage: "en", editDensityCutsPerMinute: 50))],
            childProfile: child(9),
            annotation: ann { a in
                a.requiredReasonCodes = ["CHILD_AGE_CAUTION_MANIPULATION"]
                a.expectedAdmission = ["AGE_CAUTION", "CAUTION"]
                a.forbiddenAdmission = ["NEUTRAL"] }))
        out.append(P009DPolicyScenarioV1(name: "pd-sensitive-news-adult", family: "sensitive-news",
            segments: [seg(0, 4000, ExpertInputV2(ocrText: "deprem felaketi: can kaybı ve enkaz haberleri",
                                                  detectedLanguage: "tr"), risk: 0.85, topics: ["disaster"])],
            annotation: ann { a in
                a.expectedAdmission = ["STRONG_PROTECTION"]
                a.requiredReasonCodes = ["STRONG_RISK_ESCALATION"] }))
        out.append(P009DPolicyScenarioV1(name: "pd-mortality-education-adult", family: "mortality-disease-education",
            segments: [seg(0, 4000, ExpertInputV2(ocrText: "biology lesson: how disease spreads, mortality statistics guide",
                                                  detectedLanguage: "en"), risk: 0.3, topics: ["bio"])],
            annotation: ann { a in
                a.expectedAdmission = ["CAUTION"]
                a.requiredReasonCodes = ["BENEFIT_PRESENT_NOT_OVERRIDING"]
                a.forbiddenAdmission = ["NEUTRAL", "STRONG_PROTECTION"]
                a.contextQualifier = "context:educational-mention" }))
        out.append(P009DPolicyScenarioV1(name: "pd-shield-topic-match", family: "shield-topic-match",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "sakin doğa: orman ve deniz huzur", detectedLanguage: "tr",
                                                  visualLabels: ["forest"], visualConfidence: 0.8))],
            shieldConfig: ShieldConfigV2(blockedConcepts: ["concept:calm-nature"]),
            annotation: ann { a in
                a.expectedAdmission = ["SHIELD_MATCH"]
                a.requiredReasonCodes = ["SHIELD_TOPIC_MATCH"]
                a.expectShieldHardMatch = true }))
        out.append(P009DPolicyScenarioV1(name: "pd-shield-near-miss", family: "shield-near-match-false-positive",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "kitchen cooking guide for beginners", detectedLanguage: "en",
                                                  visualLabels: ["kitchen"], visualConfidence: 0.8))],
            shieldConfig: ShieldConfigV2(blockedConcepts: ["concept:calm-nature"]),
            annotation: ann { a in
                a.expectShieldHardMatch = false
                a.forbiddenAdmission = ["SHIELD_MATCH"]
                a.forbiddenReasonCodes = ["SHIELD_TOPIC_MATCH"] }))
        out.append(P009DPolicyScenarioV1(name: "pd-shield-cross-language", family: "cross-language-shield-match",
            // Shield set once (canonical ID) — TR surface text must match through the taxonomy
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "ölüm ve vefat haberleri bugün", detectedLanguage: "tr"))],
            shieldConfig: ShieldConfigV2(blockedConcepts: ["concept:mortality"]),
            annotation: ann { a in
                a.expectedAdmission = ["SHIELD_MATCH", "STRONG_PROTECTION", "CAUTION"]
                a.requiredReasonCodes = ["SHIELD_TOPIC_MATCH"]
                a.expectShieldHardMatch = true }))
        out.append(P009DPolicyScenarioV1(name: "pd-shield-unsupported-guess", family: "shield-unsupported-guess",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "learn the science lesson guide", detectedLanguage: "en"))],
            shieldConfig: ShieldConfigV2(blockedConcepts: [], freeformGuesses: ["some-vague-vibe"]),
            annotation: ann { a in
                a.expectShieldHardMatch = false
                a.requiredReasonCodes = ["SHIELD_UNSUPPORTED_GUESS_ADVISORY"]
                a.forbiddenAdmission = ["SHIELD_MATCH"] }))
        out.append(P009DPolicyScenarioV1(name: "pd-unsupported-jurisdiction", family: "unsupported-age-jurisdiction",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "calm nature forest relax", detectedLanguage: "en",
                                                  visualLabels: ["forest"], visualConfidence: 0.8))],
            childProfile: GuardianEnteredChildProfileV1(ageYears: 10, jurisdictionCode: "XX", enteredByGuardian: true),
            annotation: ann { a in
                a.expectedChildOutcome = "AGE_UNKNOWN_REVIEW"
                a.requiredReasonCodes = ["AGE_JURISDICTION_UNSUPPORTED"]
                a.expectedAdmission = ["REVIEW"] }))
        out.append(P009DPolicyScenarioV1(name: "pd-h1-unavailable-adult-neutral", family: "h1-unavailable-path",
            // adult, benign visual content: H1 absence must be VISIBLE (reason code) but adults are not
            // blanket-blocked; child path (other scenarios) fails closed instead
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "woodworking tutorial guide", detectedLanguage: "en",
                                                  visualLabels: ["workshop"], visualConfidence: 0.8))],
            annotation: ann { a in
                a.expectedAdmission = ["NEUTRAL"]
                a.requiredReasonCodes = ["H1_VISUAL_UNAVAILABLE"] }))
        out.append(P009DPolicyScenarioV1(name: "pd-multi-policy-conflict", family: "multi-policy-conflict",
            // shield-blocked topic + educational benefit + child caution — precedence must order them
            segments: [seg(0, 4000, ExpertInputV2(ocrText: "tarih dersi: savaş ve ölüm anlatımı", detectedLanguage: "tr"),
                           risk: 0.65, topics: ["history"])],
            childProfile: child(12),
            shieldConfig: ShieldConfigV2(blockedConcepts: ["concept:mortality"], preferredConcepts: ["concept:education"]),
            annotation: ann { a in
                a.expectedAdmission = ["STRONG_PROTECTION", "AGE_RESTRICTED", "SHIELD_MATCH"]
                a.requiredReasonCodes = ["BENEFIT_PRESENT_NOT_OVERRIDING"]
                a.forbiddenAdmission = ["NEUTRAL", "CAUTION"] }))
        return out
    }

    // ── HELD_OUT — distinct instances ──
    static func heldOut() -> [P009DPolicyScenarioV1] {
        var out: [P009DPolicyScenarioV1] = []
        out.append(P009DPolicyScenarioV1(name: "hd-storm-news-child", family: "sensitive-news",
            segments: [seg(0, 4000, ExpertInputV2(ocrText: "hurricane disaster: fatal flood toll rising",
                                                  detectedLanguage: "en", soundEvents: ["siren"]), risk: 0.85, topics: ["storm"])],
            childProfile: child(9, "US"),
            annotation: ann { a in
                a.expectedAdmission = ["STRONG_PROTECTION"]
                a.expectedChildOutcome = "AGE_RESTRICTED" }))
        out.append(P009DPolicyScenarioV1(name: "hd-cooking-neutral-adult", family: "h1-unavailable-path",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "how to cook rice: kitchen guide", detectedLanguage: "en",
                                                  visualLabels: ["kitchen"], visualConfidence: 0.8))],
            annotation: ann { a in
                a.expectedAdmission = ["NEUTRAL"]
                a.requiredReasonCodes = ["H1_VISUAL_UNAVAILABLE"] }))
        out.append(P009DPolicyScenarioV1(name: "hd-teen-sensitive-caution", family: "mortality-disease-education",
            segments: [seg(0, 4000, ExpertInputV2(ocrText: "sağlık dersi: hastalık belirtileri rehberi", detectedLanguage: "tr"))],
            childProfile: child(14, "TR"),
            annotation: ann { a in
                a.expectedChildOutcome = "AGE_ALIGNED"              // 14 ≥ bands; H1 law applies <13 only
                a.expectedAdmission = ["CAUTION"] }))
        out.append(P009DPolicyScenarioV1(name: "hd-shield-entity-match", family: "shield-topic-match",
            segments: [seg(0, 3000, ExpertInputV2(visualLabels: ["spa", "candles"], visualConfidence: 0.85))],
            shieldConfig: ShieldConfigV2(blockedEntities: ["entity:place:spa"]),
            annotation: ann { a in
                a.expectedAdmission = ["SHIELD_MATCH"]
                a.requiredReasonCodes = ["SHIELD_ENTITY_MATCH"]
                a.expectShieldHardMatch = true }))
        out.append(P009DPolicyScenarioV1(name: "hd-cross-language-en-config-tr-content", family: "cross-language-shield-match",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "acele et! son şans hemen tıkla", detectedLanguage: "tr",
                                                  editDensityCutsPerMinute: 45))],
            shieldConfig: ShieldConfigV2(blockedConcepts: ["concept:urgency"]),
            annotation: ann { a in
                a.requiredReasonCodes = ["SHIELD_TOPIC_MATCH"]
                a.expectShieldHardMatch = true }))
        out.append(P009DPolicyScenarioV1(name: "hd-parent-stricter", family: "multi-policy-conflict",
            segments: [seg(0, 4000, ExpertInputV2(ocrText: "news brief: hospital disease report", detectedLanguage: "en"))],
            childProfile: child(14, "EU"),
            parentPreference: ParentPreferencePolicyV1(blockSensitiveNews: true),
            annotation: ann { a in
                a.expectedChildOutcome = "AGE_RESTRICTED"           // parent tightens beyond general band
                a.expectedAdmission = ["AGE_RESTRICTED"] }))
        out.append(P009DPolicyScenarioV1(name: "hd-guess-cannot-block", family: "shield-unsupported-guess",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "bilim eğitimi: deney rehberi", detectedLanguage: "tr"))],
            shieldConfig: ShieldConfigV2(blockedConcepts: ["gaming"], freeformGuesses: []),   // non-canonical → demoted
            annotation: ann { a in
                a.expectShieldHardMatch = false
                a.requiredReasonCodes = ["SHIELD_UNSUPPORTED_GUESS_ADVISORY"]
                a.forbiddenAdmission = ["SHIELD_MATCH"] }))
        out.append(P009DPolicyScenarioV1(name: "hd-identity-provisional-unknown", family: "unknown-fail-closed",
            segments: [seg(0, 2000, ExpertInputV2(ocrText: "plain caption", detectedLanguage: "en"))],
            annotation: ann { a in
                a.expectedAdmission = ["UNKNOWN"]                   // run provisional via harness flag
                a.requiredReasonCodes = ["IDENTITY_PROVISIONAL"] }))
        return out
    }

    // ── STRESS ──
    static func stress() -> [P009DPolicyScenarioV1] {
        var out: [P009DPolicyScenarioV1] = []
        out.append(P009DPolicyScenarioV1(name: "sd-benefit-flood-vs-strong-risk", family: "multi-policy-conflict",
            segments: [seg(0, 5000, ExpertInputV2(ocrText: String(repeating: "learn lesson guide tutorial ", count: 30)
                                                  + "deadly war casualties everywhere", detectedLanguage: "en",
                                                  soundEvents: ["siren", "alarm"]), risk: 0.95, topics: ["war"])],
            childProfile: child(10),
            shieldConfig: ShieldConfigV2(preferredConcepts: ["concept:education"]),
            annotation: ann { a in
                a.expectedAdmission = ["STRONG_PROTECTION"]
                a.requiredReasonCodes = ["STRONG_RISK_ESCALATION", "BENEFIT_PRESENT_NOT_OVERRIDING"]
                a.forbiddenAdmission = ["NEUTRAL", "CAUTION", "AGE_CAUTION"] }))
        out.append(P009DPolicyScenarioV1(name: "sd-many-shield-entries", family: "shield-topic-match",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "sakin orman ve deniz", detectedLanguage: "tr",
                                                  visualLabels: ["forest", "river"], visualConfidence: 0.85))],
            shieldConfig: ShieldConfigV2(blockedConcepts: Set((1...50).map { "concept:synthetic-\($0)" } + ["concept:calm-nature"])),
            annotation: ann { a in
                a.expectedAdmission = ["SHIELD_MATCH"]
                a.expectShieldHardMatch = true }))
        out.append(P009DPolicyScenarioV1(name: "sd-age-boundary-13", family: "age-band-boundary",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "korku hikayesi tehlike", detectedLanguage: "tr"), risk: 0.4, topics: ["h"])],
            childProfile: child(13),
            annotation: ann { a in
                a.expectedChildOutcome = "AGE_ALIGNED"              // 13 = boundary: fear caution is <10; H1 law <13
                a.expectedAdmission = ["CAUTION"] }))
        out.append(P009DPolicyScenarioV1(name: "sd-age-boundary-12", family: "age-band-boundary",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "korku hikayesi tehlike", detectedLanguage: "tr"), risk: 0.4, topics: ["h"])],
            childProfile: child(12),
            annotation: ann { a in
                // authoring correction: this text triggers FEAR (caution <10) not sensitiveNews; at 12 the
                // under-13 H1 law yields REVIEW — the 13-vs-12 pair still proves the band boundary
                a.expectedChildOutcome = "AGE_UNKNOWN_REVIEW"
                a.requiredReasonCodes = ["AGE_H1_REQUIRED_UNAVAILABLE"]
                a.expectedAdmission = ["REVIEW", "CAUTION"] }))
        return out
    }

    // ── OOD ──
    static func ood() -> [P009DPolicyScenarioV1] {
        var out: [P009DPolicyScenarioV1] = []
        out.append(P009DPolicyScenarioV1(name: "od-empty-content", family: "unknown-fail-closed",
            segments: [seg(0, 2000, ExpertInputV2())],
            childProfile: child(10),
            annotation: ann { a in
                a.expectedAdmission = ["UNKNOWN", "REVIEW"]
                a.forbiddenAdmission = ["NEUTRAL", "AGE_CAUTION"] }))
        out.append(P009DPolicyScenarioV1(name: "od-unsupported-language-child", family: "unknown-fail-closed",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "これは日本語です", detectedLanguage: "ja"))],
            childProfile: child(11),
            annotation: ann { a in
                a.expectedAdmission = ["UNKNOWN", "REVIEW"]
                a.forbiddenAdmission = ["NEUTRAL"] }))
        out.append(P009DPolicyScenarioV1(name: "od-unattested-age", family: "unknown-fail-closed",
            segments: [seg(0, 3000, ExpertInputV2(ocrText: "calm forest relax", detectedLanguage: "en"))],
            childProfile: GuardianEnteredChildProfileV1(ageYears: 9, jurisdictionCode: "TR", enteredByGuardian: false),
            annotation: ann { a in
                a.expectedChildOutcome = "AGE_UNKNOWN_REVIEW"
                a.requiredReasonCodes = ["AGE_SOURCE_MISSING"]
                a.expectedAdmission = ["REVIEW"] }))
        out.append(P009DPolicyScenarioV1(name: "od-poisoned-input", family: "unknown-fail-closed",
            segments: [seg(0, 2000, ExpertInputV2(ocrText: "x#1", detectedLanguage: "zz!!",
                                                  editDensityCutsPerMinute: .nan))],
            annotation: ann { a in
                a.expectedAdmission = ["UNKNOWN", "REVIEW"]
                a.forbiddenAdmission = ["NEUTRAL", "SHIELD_MATCH"] }))
        return out
    }

    /// Harness: segments → live mesh → world model → admission pipeline.
    public static func run(_ s: P009DPolicyScenarioV1, brain: GuardianMetaBrainV2, item: ContentItemID,
                           provisional: Bool = false) -> (model: ContentWorldModelV1, decision: AdmissionStateCandidateV1) {
        let semantic = P009CScenarioV1(name: s.name, family: s.family, segments: s.segments, annotation: P009CAnnotationV1())
        let m = P009CCorpusV1.run(semantic, brain: brain, item: item, provisional: provisional)
        let d = AdmissionPolicyPipelineV1.evaluate(worldModel: m, childProfile: s.childProfile,
                                                   parentPreference: s.parentPreference,
                                                   shieldConfig: s.shieldConfig,
                                                   nowMs: s.segments.last?.endMs ?? 0)
        return (m, d)
    }
}
