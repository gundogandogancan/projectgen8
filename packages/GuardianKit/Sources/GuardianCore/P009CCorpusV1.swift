import Foundation

// MARK: - P009C §23/§24 — rights-clear SEMANTIC corpus + formal annotation schema.
// Seedless, split-authored banks (the R1 F2 law carried forward). 100% project-authored derived-input
// bundles. For SUBJECTIVE dimensions (intent, emotional load) TWO independent annotation slots are
// authored and DISAGREEMENT IS PRESERVED — expectations accept the union, never silently merge.

public struct P009CSegmentV1: Sendable {
    public let startMs: Double, endMs: Double
    public let input: ExpertInputV2
    public let temporalRisk: Double                // fed to TemporalExpertV1.observe before routing
    public let temporalTopics: Set<String>
    public init(startMs: Double, endMs: Double, input: ExpertInputV2, temporalRisk: Double = 0,
                temporalTopics: Set<String> = []) {
        self.startMs = startMs; self.endMs = endMs; self.input = input
        self.temporalRisk = temporalRisk; self.temporalTopics = temporalTopics
    }
}

/// §24 formal annotation schema — structural labels; subjective dims carry A/B annotator slots.
public struct P009CAnnotationV1: Sendable {
    public var expectedTopics: Set<String> = []            // canonical concept IDs (exact match)
    public var forbiddenTopics: Set<String> = []
    public var expectedEntityPrefixes: Set<String> = []
    public var intentsAnnotatorA: Set<String> = []         // subjective — two independent annotations
    public var intentsAnnotatorB: Set<String> = []
    public var expectIntentAmbiguous: Bool? = nil
    public var expectContradiction = false
    public var allowedContradictionOutcomes: Set<String> = []
    public var expectedContextTags: Set<String> = []
    public var expectRiskEscalated = false
    public var expectRecoveryObserved = false
    public var emotionalAnnotatorA: Set<String> = []       // subjective
    public var emotionalAnnotatorB: Set<String> = []
    public var expectManipulationEvidence = false
    public var minEpisodes = 1
    public var allowedKnowledgeStates: Set<String> = []    // empty = unchecked
    public var expectDNAReady: Bool? = nil
    public var expectUnsupportedLanguage = false
    public init() {}
    public var intentDisagreement: Set<String> { intentsAnnotatorA.symmetricDifference(intentsAnnotatorB) }
}

public struct P009CScenarioV1: Sendable {
    public let name: String
    public let family: String
    public let segments: [P009CSegmentV1]
    public let annotation: P009CAnnotationV1
}

public enum P009CSplitV1: String, CaseIterable, Sendable { case tune = "TUNE", heldOut = "HELD_OUT", stress = "STRESS", ood = "OOD" }

public enum P009CCorpusV1 {
    public static let revision = "p009c-corpus-v1"

    public static func scenarios(_ split: P009CSplitV1) -> [P009CScenarioV1] {
        switch split {
        case .tune: return tune()
        case .heldOut: return heldOut()
        case .stress: return stress()
        case .ood: return ood()
        }
    }
    public static var countsBySplit: [P009CSplitV1: Int] {
        Dictionary(uniqueKeysWithValues: P009CSplitV1.allCases.map { ($0, scenarios($0).count) })
    }

    static func seg(_ s: Double, _ e: Double, _ i: ExpertInputV2, risk: Double = 0, topics: Set<String> = []) -> P009CSegmentV1 {
        P009CSegmentV1(startMs: s, endMs: e, input: i, temporalRisk: risk, temporalTopics: topics)
    }
    static func ann(_ f: (inout P009CAnnotationV1) -> Void) -> P009CAnnotationV1 { var a = P009CAnnotationV1(); f(&a); return a }

    // ── TUNE — all 23 §23 families ──
    static func tune() -> [P009CScenarioV1] {
        var out: [P009CScenarioV1] = []
        out.append(P009CScenarioV1(name: "tc-straight-educational", family: "straightforward-educational", segments: [
            seg(0, 4000, ExpertInputV2(ocrText: "learn the science lesson: a clear guide", detectedLanguage: "en",
                                       visualLabels: ["whiteboard"], visualConfidence: 0.8)),
            seg(4000, 8000, ExpertInputV2(ocrText: "the tutorial continues with history", detectedLanguage: "en",
                                          visualLabels: ["classroom"], visualConfidence: 0.8))],
            annotation: ann { a in
                a.expectedTopics = ["concept:education"]; a.forbiddenTopics = ["concept:mortality"]
                a.intentsAnnotatorA = ["intent:teach"]; a.intentsAnnotatorB = ["intent:teach", "intent:inform"]
                a.allowedKnowledgeStates = ["KNOWN", "LIKELY"]; a.expectDNAReady = true }))
        out.append(P009CScenarioV1(name: "tc-educational-plus-sensitive", family: "educational-sensitive", segments: [
            seg(0, 5000, ExpertInputV2(ocrText: "hastalık nasıl yayılır: ölüm oranları üstüne tıbbi ders",
                                       detectedLanguage: "tr"))],
            annotation: ann { a in
                a.expectedTopics = ["concept:education", "concept:sensitive-news"]
                a.expectContradiction = true
                a.allowedContradictionOutcomes = ["CONTEXT_QUALIFIED", "UNRESOLVED", "MODALITY_PRIORITY", "STRONG_RISK_DOMINANT"]
                a.expectedContextTags = ["context:educational-mention"]
                a.intentsAnnotatorA = ["intent:teach"]; a.intentsAnnotatorB = ["intent:inform"] }))
        out.append(P009CScenarioV1(name: "tc-humor", family: "humor", segments: [
            seg(0, 3000, ExpertInputV2(ocrText: "comedy sketch lol 😂 harmless fun tonight", detectedLanguage: "en",
                                       musicPresence: true, musicTempoEnergy: 0.7))],
            annotation: ann { a in
                a.expectedContextTags = ["context:satire-humor-candidate"]
                a.intentsAnnotatorA = ["intent:entertain", "intent:satire-humor"]; a.intentsAnnotatorB = ["intent:satire-humor"]
                a.forbiddenTopics = ["concept:sensitive-news"] }))
        out.append(P009CScenarioV1(name: "tc-sarcasm-lexical-risk", family: "sarcasm", segments: [
            seg(0, 3000, ExpertInputV2(ocrText: "oh sure 'perfectly safe' lol — deadly stunt parody", detectedLanguage: "en"))],
            annotation: ann { a in
                a.expectedTopics = ["concept:mortality"]            // literal trigger survives (fail-safe)
                a.expectedContextTags = ["context:satire-humor-candidate"]
                a.expectContradiction = false
                a.allowedKnowledgeStates = ["AMBIGUOUS", "LIKELY", "CONFLICTING", "UNKNOWN"] }))
        out.append(P009CScenarioV1(name: "tc-quoted-harmful", family: "quoted-harmful", segments: [
            seg(0, 4000, ExpertInputV2(ocrText: "the report quoted: \"they threatened violence and death\" dedi ki uzman",
                                       detectedLanguage: "en"))],
            annotation: ann { a in
                a.expectedTopics = ["concept:mortality"]            // retained, qualified — never erased
                a.expectedContextTags = ["context:quoted"] }))
        out.append(P009CScenarioV1(name: "tc-literal-harmful", family: "literal-harmful", segments: [
            seg(0, 4000, ExpertInputV2(ocrText: "breaking: fatal crash kills several on highway", detectedLanguage: "en",
                                       visualLabels: ["street", "smoke"], visualConfidence: 0.7), risk: 0.8, topics: ["accident"])],
            annotation: ann { a in
                a.expectedTopics = ["concept:mortality", "concept:sensitive-news"]
                a.expectRiskEscalated = true
                a.expectedContextTags = ["context:literal"]
                a.emotionalAnnotatorA = ["emotion:grief"]; a.emotionalAnnotatorB = ["emotion:grief", "emotion:graphic-sensitive"] }))
        out.append(P009CScenarioV1(name: "tc-persuasive-ad", family: "persuasive-ad", segments: [
            seg(0, 3000, ExpertInputV2(ocrText: "buy now! limited time offer — subscribe and click here today only",
                                       detectedLanguage: "en", editDensityCutsPerMinute: 30))],
            annotation: ann { a in
                a.expectedTopics = ["concept:urgency", "concept:cta-engagement"]
                a.expectManipulationEvidence = true
                a.intentsAnnotatorA = ["intent:sell", "intent:persuade"]; a.intentsAnnotatorB = ["intent:seek-engagement", "intent:sell"] }))
        out.append(P009CScenarioV1(name: "tc-manipulative-urgency", family: "manipulative-urgency", segments: [
            seg(0, 3000, ExpertInputV2(ocrText: "ACELE ET şimdi son şans kaçırma hemen tıkla", detectedLanguage: "tr",
                                       editDensityCutsPerMinute: 50))],
            annotation: ann { a in
                a.expectedTopics = ["concept:urgency", "concept:rapid-editing"]
                a.expectManipulationEvidence = true
                a.emotionalAnnotatorA = ["emotion:urgency"]; a.emotionalAnnotatorB = ["emotion:urgency", "emotion:excitement"] }))
        out.append(P009CScenarioV1(name: "tc-calm-nature", family: "calm-nature", segments: [
            seg(0, 6000, ExpertInputV2(ocrText: "sakin orman ve deniz: doğa huzur", detectedLanguage: "tr",
                                       visualLabels: ["forest", "river"], visualConfidence: 0.85, soundEvents: ["nature", "water"]))],
            annotation: ann { a in
                a.expectedTopics = ["concept:calm-nature"]; a.forbiddenTopics = ["concept:urgency"]
                a.expectedEntityPrefixes = ["entity:place:"]
                a.emotionalAnnotatorA = ["emotion:calm"]; a.emotionalAnnotatorB = ["emotion:calm"]
                a.expectDNAReady = true }))
        out.append(P009CScenarioV1(name: "tc-music-only", family: "music-only", segments: [
            seg(0, 4000, ExpertInputV2(soundEvents: ["music"], musicPresence: true, musicTempoEnergy: 0.6))],
            annotation: ann { a in
                a.expectedTopics = ["concept:music"]
                a.allowedKnowledgeStates = ["AMBIGUOUS", "LIKELY", "UNKNOWN"] }))
        out.append(P009CScenarioV1(name: "tc-sensitive-news", family: "sensitive-news", segments: [
            seg(0, 5000, ExpertInputV2(ocrText: "deprem felaketi: can kaybı artıyor, enkaz altında arama",
                                       detectedLanguage: "tr", soundEvents: ["siren"]), risk: 0.85, topics: ["disaster"])],
            annotation: ann { a in
                a.expectedTopics = ["concept:disaster", "concept:sensitive-news", "concept:emergency-sound"]
                a.expectRiskEscalated = true
                a.intentsAnnotatorA = ["intent:inform"]; a.intentsAnnotatorB = ["intent:inform", "intent:warn"] }))
        out.append(P009CScenarioV1(name: "tc-montage-multitopic", family: "montage+multi-topic", segments: [
            seg(0, 2000, ExpertInputV2(ocrText: "best sports moments", detectedLanguage: "en", editDensityCutsPerMinute: 60), topics: ["sport"]),
            seg(2000, 4000, ExpertInputV2(ocrText: "kitchen cooking guide tips", detectedLanguage: "en",
                                          visualLabels: ["kitchen"], visualConfidence: 0.8, editDensityCutsPerMinute: 60), topics: ["cooking"]),
            seg(4000, 6000, ExpertInputV2(ocrText: "calm nature forest break", detectedLanguage: "en",
                                          visualLabels: ["forest"], visualConfidence: 0.8, editDensityCutsPerMinute: 60), topics: ["nature"])],
            annotation: ann { a in
                a.expectedTopics = ["concept:rapid-editing", "concept:cooking", "concept:calm-nature"]
                a.minEpisodes = 2 }))
        out.append(P009CScenarioV1(name: "tc-broll-scene-return", family: "b-roll+repeated-scene", segments: [
            seg(0, 2000, ExpertInputV2(visualLabels: ["person-speaking"], visualConfidence: 0.8,
                                       speechTranscript: "today we explain the engine lesson", speechAvailable: true), topics: ["interview"]),
            seg(2000, 4000, ExpertInputV2(visualLabels: ["workshop"], visualConfidence: 0.7), topics: ["broll"]),
            seg(4000, 6000, ExpertInputV2(visualLabels: ["person-speaking"], visualConfidence: 0.8,
                                          speechTranscript: "back to the main explanation guide", speechAvailable: true), topics: ["interview"])],
            annotation: ann { a in
                a.expectedTopics = ["concept:talking-head", "concept:education"]
                a.expectedEntityPrefixes = ["entity:person-present:"]
                a.minEpisodes = 2 }))
        out.append(P009CScenarioV1(name: "tc-topic-shift", family: "topic-shift", segments: [
            seg(0, 3000, ExpertInputV2(ocrText: "science lesson part one guide", detectedLanguage: "en",
                                       visualLabels: ["classroom"], visualConfidence: 0.8), topics: ["education"]),
            seg(3000, 6000, ExpertInputV2(ocrText: "hurry limited offer buy now click", detectedLanguage: "en",
                                          editDensityCutsPerMinute: 40), topics: ["ad"])],
            annotation: ann { a in
                a.expectedTopics = ["concept:education", "concept:urgency"]
                a.expectManipulationEvidence = true
                a.minEpisodes = 2 }))
        out.append(P009CScenarioV1(name: "tc-benign-then-risky", family: "benign-to-risky", segments: [
            seg(0, 3000, ExpertInputV2(ocrText: "calm nature morning forest", detectedLanguage: "en",
                                       visualLabels: ["forest"], visualConfidence: 0.8), risk: 0.05, topics: ["nature"]),
            seg(3000, 6000, ExpertInputV2(ocrText: "sudden disaster: deadly flood waters rising fast", detectedLanguage: "en",
                                          soundEvents: ["siren"]), risk: 0.9, topics: ["disaster"])],
            annotation: ann { a in
                a.expectedTopics = ["concept:calm-nature", "concept:disaster"]
                // benign→risky is ESCALATION (an event), not a same-moment contradiction — the risk
                // arrives after the benefit, so no risk-vs-positive pair coexists in one segment
                a.expectRiskEscalated = true; a.expectContradiction = false }))
        out.append(P009CScenarioV1(name: "tc-risky-then-benign", family: "risky-to-benign", segments: [
            seg(0, 3000, ExpertInputV2(ocrText: "savaş görüntüleri: ölüm ve yıkım her yerde", detectedLanguage: "tr"),
                risk: 0.85, topics: ["war"]),
            seg(3000, 6000, ExpertInputV2(ocrText: "şimdi sakin deniz ve huzur", detectedLanguage: "tr",
                                          visualLabels: ["forest"], visualConfidence: 0.8), risk: 0.0, topics: ["nature"])],
            annotation: ann { a in
                a.expectedTopics = ["concept:mortality", "concept:calm-nature"]
                a.expectRiskEscalated = true                      // historical risk NEVER erased
                a.expectRecoveryObserved = true
                a.expectContradiction = true }))
        out.append(P009CScenarioV1(name: "tc-multimodal-contradiction", family: "multimodal-contradiction", segments: [
            seg(0, 4000, ExpertInputV2(ocrText: "relax and enjoy the calm party", detectedLanguage: "en",
                                       visualLabels: ["party"], visualConfidence: 0.8, soundEvents: ["siren", "alarm"]),
                risk: 0.7, topics: ["alarm"])],
            annotation: ann { a in
                a.expectedTopics = ["concept:calm-nature", "concept:emergency-sound"]
                a.expectContradiction = true
                a.allowedContradictionOutcomes = ["STRONG_RISK_DOMINANT", "MODALITY_PRIORITY", "UNRESOLVED"] }))
        out.append(P009CScenarioV1(name: "tc-entity-conflict", family: "entity-conflict", segments: [
            seg(0, 3000, ExpertInputV2(visualLabels: ["forest", "spa"], visualConfidence: 0.8))],
            annotation: ann { a in
                a.expectedEntityPrefixes = ["entity:place:forest", "entity:place:spa"]   // both retained, unresolved
                a.allowedKnowledgeStates = ["AMBIGUOUS", "LIKELY", "UNKNOWN"] }))
        out.append(P009CScenarioV1(name: "tc-intent-ambiguity", family: "intent-ambiguity", segments: [
            seg(0, 4000, ExpertInputV2(ocrText: "learn this trick now! limited guide — subscribe for the lesson",
                                       detectedLanguage: "en"))],
            annotation: ann { a in
                a.expectIntentAmbiguous = true                     // teach vs sell/engagement stays ambiguous
                a.intentsAnnotatorA = ["intent:teach", "intent:sell"]; a.intentsAnnotatorB = ["intent:seek-engagement", "intent:teach"] }))
        out.append(P009CScenarioV1(name: "tc-unsupported-language", family: "unsupported-language", segments: [
            seg(0, 3000, ExpertInputV2(ocrText: "これは日本語の物語です", detectedLanguage: "ja"))],
            annotation: ann { a in
                a.expectUnsupportedLanguage = true
                a.forbiddenTopics = ["concept:mortality", "concept:education"]
                a.allowedKnowledgeStates = ["UNKNOWN", "AMBIGUOUS", "UNAVAILABLE"]
                a.expectDNAReady = false }))
        out.append(P009CScenarioV1(name: "tc-ood-noisy", family: "ood-noisy", segments: [
            seg(0, 2000, ExpertInputV2(ocrText: "x#9", detectedLanguage: "en", editDensityCutsPerMinute: .nan))],
            annotation: ann { a in
                a.forbiddenTopics = ["concept:rapid-editing"]
                a.allowedKnowledgeStates = ["UNKNOWN", "AMBIGUOUS", "UNAVAILABLE"]
                a.expectDNAReady = false }))
        return out
    }

    // ── HELD_OUT — distinct instances (authored separately; NOT translations) ──
    static func heldOut() -> [P009CScenarioV1] {
        var out: [P009CScenarioV1] = []
        out.append(P009CScenarioV1(name: "hc-educational-cooking", family: "straightforward-educational", segments: [
            seg(0, 4000, ExpertInputV2(ocrText: "how to cook rice: kitchen guide for beginners", detectedLanguage: "en",
                                       visualLabels: ["kitchen"], visualConfidence: 0.8, soundEvents: ["water"]))],
            annotation: ann { a in
                a.expectedTopics = ["concept:education", "concept:cooking"]
                a.intentsAnnotatorA = ["intent:teach"]; a.intentsAnnotatorB = ["intent:teach"]
                a.expectDNAReady = true }))
        out.append(P009CScenarioV1(name: "hc-edu-war-history", family: "educational-sensitive", segments: [
            seg(0, 5000, ExpertInputV2(ocrText: "history lesson: the invasion casualties explained for students",
                                       detectedLanguage: "en"))],
            annotation: ann { a in
                a.expectedTopics = ["concept:education", "concept:mortality"]
                a.expectContradiction = true
                a.expectedContextTags = ["context:educational-mention"] }))
        out.append(P009CScenarioV1(name: "hc-quoted-threat-news", family: "quoted-harmful", segments: [
            seg(0, 4000, ExpertInputV2(ocrText: "muhabir aktardı: \"tehdit ve tehlike sözleri\" alıntı haberde",
                                       detectedLanguage: "tr"))],
            annotation: ann { a in
                a.expectedContextTags = ["context:quoted"]
                a.expectedTopics = ["concept:fear-threat"] }))
        out.append(P009CScenarioV1(name: "hc-urgent-flashsale", family: "manipulative-urgency", segments: [
            seg(0, 3000, ExpertInputV2(ocrText: "don't miss it — act fast, sign up, follow, today only!",
                                       detectedLanguage: "en", editDensityCutsPerMinute: 45))],
            annotation: ann { a in
                a.expectedTopics = ["concept:urgency"]
                a.expectManipulationEvidence = true }))
        out.append(P009CScenarioV1(name: "hc-ocean-calm", family: "calm-nature", segments: [
            seg(0, 5000, ExpertInputV2(ocrText: "relax by the ocean: calm waves", detectedLanguage: "en",
                                       visualLabels: ["river"], visualConfidence: 0.85, soundEvents: ["water", "nature"]))],
            annotation: ann { a in
                a.expectedTopics = ["concept:calm-nature"]
                a.emotionalAnnotatorA = ["emotion:calm"]; a.emotionalAnnotatorB = ["emotion:calm"] }))
        out.append(P009CScenarioV1(name: "hc-wedding-grief-shift", family: "benign-to-risky", segments: [
            seg(0, 3000, ExpertInputV2(ocrText: "düğün hazırlıkları neşeyle sürüyor", detectedLanguage: "tr",
                                       visualLabels: ["wedding"], visualConfidence: 0.8), risk: 0.05, topics: ["wedding"]),
            seg(3000, 6000, ExpertInputV2(ocrText: "acı haber: vefat ve cenaze duyurusu", detectedLanguage: "tr"),
                risk: 0.8, topics: ["grief"])],
            annotation: ann { a in
                a.expectedTopics = ["concept:celebration", "concept:mortality"]
                a.expectRiskEscalated = true; a.expectContradiction = false }))
        out.append(P009CScenarioV1(name: "hc-storm-recovery", family: "risky-to-benign", segments: [
            seg(0, 3000, ExpertInputV2(ocrText: "hurricane disaster: deadly storm hits coast", detectedLanguage: "en",
                                       soundEvents: ["siren"]), risk: 0.9, topics: ["storm"]),
            seg(3000, 6000, ExpertInputV2(ocrText: "after the storm: calm forest recovery", detectedLanguage: "en",
                                          visualLabels: ["forest"], visualConfidence: 0.8), risk: 0.0, topics: ["recovery"])],
            annotation: ann { a in
                a.expectRiskEscalated = true; a.expectRecoveryObserved = true
                a.expectedTopics = ["concept:disaster", "concept:calm-nature"] }))
        out.append(P009CScenarioV1(name: "hc-cheer-alarm-conflict", family: "multimodal-contradiction", segments: [
            seg(0, 4000, ExpertInputV2(ocrText: "kutlama: sakin ve huzurlu bir akşam", detectedLanguage: "tr",
                                       visualLabels: ["party"], visualConfidence: 0.75, soundEvents: ["alarm"]),
                risk: 0.65, topics: ["alarm"])],
            annotation: ann { a in
                a.expectContradiction = true
                a.allowedContradictionOutcomes = ["STRONG_RISK_DOMINANT", "MODALITY_PRIORITY", "UNRESOLVED"] }))
        out.append(P009CScenarioV1(name: "hc-teach-or-sell", family: "intent-ambiguity", segments: [
            seg(0, 4000, ExpertInputV2(ocrText: "ders gibi anlatım ama hemen kaydol: sınırlı rehber fırsatı",
                                       detectedLanguage: "tr"))],
            annotation: ann { a in a.expectIntentAmbiguous = true }))
        out.append(P009CScenarioV1(name: "hc-lang-ar", family: "unsupported-language", segments: [
            seg(0, 3000, ExpertInputV2(ocrText: "قصة قصيرة عن البحر", detectedLanguage: "ar"))],
            annotation: ann { a in
                a.expectUnsupportedLanguage = true; a.expectDNAReady = false
                a.allowedKnowledgeStates = ["UNKNOWN", "AMBIGUOUS", "UNAVAILABLE"] }))
        return out
    }

    // ── STRESS — extremes ──
    static func stress() -> [P009CScenarioV1] {
        var out: [P009CScenarioV1] = []
        var spamSegments: [P009CSegmentV1] = []
        for i in 0..<40 {
            let even = i % 2 == 0
            let text: String = even ? "science lesson guide" : "hurry buy now limited"
            let topic: String = even ? "edu" : "ad"
            let input = ExpertInputV2(ocrText: text, detectedLanguage: "en", editDensityCutsPerMinute: 80)
            spamSegments.append(seg(Double(i) * 500, Double(i + 1) * 500, input, topics: [topic]))
        }
        out.append(P009CScenarioV1(name: "sc-episode-spam", family: "boundedness", segments: spamSegments,
            annotation: ann { a in
                a.expectedTopics = ["concept:education", "concept:urgency"]; a.minEpisodes = 4 }))
        var longTail: [P009CSegmentV1] = [
            seg(0, 2000, ExpertInputV2(ocrText: "catastrophe: deadly explosion wreck casualties", detectedLanguage: "en"),
                risk: 0.95, topics: ["disaster"])]
        for i in 1...8 {
            let calmInput = ExpertInputV2(ocrText: "calm nature relax forest ocean", detectedLanguage: "en",
                                          visualLabels: ["forest"], visualConfidence: 0.85)
            longTail.append(seg(Double(i) * 2000, Double(i + 1) * 2000, calmInput, risk: 0, topics: ["calm"]))
        }
        out.append(P009CScenarioV1(name: "sc-long-risk-tail", family: "risky-to-benign", segments: longTail,
            annotation: ann { a in
                a.expectRiskEscalated = true                      // 8 benign segments cannot erase 1 strong risk
                a.expectRecoveryObserved = true; a.expectContradiction = true }))
        out.append(P009CScenarioV1(name: "sc-correlated-lexical-flood", family: "evidence-weighting", segments: [
            seg(0, 4000, ExpertInputV2(ocrText: String(repeating: "deadly death fatal killed ", count: 20),
                                       detectedLanguage: "en", speechTranscript: String(repeating: "deadly death ", count: 20),
                                       speechAvailable: true))],
            annotation: ann { a in
                a.expectedTopics = ["concept:mortality"]
                // correlated OCR+speech lexical floods are ONE family — never "many proofs"
                a.allowedKnowledgeStates = ["LIKELY", "AMBIGUOUS", "KNOWN", "CONFLICTING"] }))
        out.append(P009CScenarioV1(name: "sc-rapid-topic-storm", family: "topic-shift", segments:
            ["classroom", "kitchen", "forest", "party", "street"].enumerated().map { (i, scene) in
                seg(Double(i) * 1000, Double(i + 1) * 1000,
                    ExpertInputV2(visualLabels: [scene], visualConfidence: 0.8, editDensityCutsPerMinute: 90), topics: [scene]) },
            annotation: ann { a in a.minEpisodes = 3 }))
        return out
    }

    // ── OOD ──
    static func ood() -> [P009CScenarioV1] {
        var out: [P009CScenarioV1] = []
        out.append(P009CScenarioV1(name: "oc-empty-segments", family: "ood-noisy", segments: [
            seg(0, 2000, ExpertInputV2()), seg(2000, 4000, ExpertInputV2())],
            annotation: ann { a in
                a.allowedKnowledgeStates = ["UNAVAILABLE", "UNKNOWN"]; a.expectDNAReady = false }))
        out.append(P009CScenarioV1(name: "oc-poisoned-values", family: "ood-noisy", segments: [
            seg(0, 2000, ExpertInputV2(ocrText: "plain text", detectedLanguage: "zz!!", visualLabels: ["x"],
                                       visualConfidence: .nan, editDensityCutsPerMinute: -5))],
            annotation: ann { a in
                a.expectUnsupportedLanguage = true
                a.forbiddenTopics = ["concept:rapid-editing"]; a.expectDNAReady = false }))
        out.append(P009CScenarioV1(name: "oc-lang-de-story", family: "unsupported-language", segments: [
            seg(0, 3000, ExpertInputV2(ocrText: "Eine kurze Geschichte über den Wald", detectedLanguage: "de"))],
            annotation: ann { a in
                a.expectUnsupportedLanguage = true; a.expectDNAReady = false }))
        out.append(P009CScenarioV1(name: "oc-audio-unknown-classes", family: "ood-noisy", segments: [
            seg(0, 3000, ExpertInputV2(soundEvents: ["quantum-drone", "xeno-chirp"]))],
            annotation: ann { a in
                a.allowedKnowledgeStates = ["UNKNOWN", "AMBIGUOUS", "UNAVAILABLE"]; a.expectDNAReady = false }))
        return out
    }

    // ── harness: segments → mesh routes → EpisodeObservationV1 → WorldModelBuilderV1 ──
    public static func run(_ s: P009CScenarioV1, brain: GuardianMetaBrainV2, item: ContentItemID,
                           provisional: Bool = false, identityRevision: UInt64 = 0) -> ContentWorldModelV1 {
        let temporal = brain.registry.expert(for: .temporal) as? TemporalExpertV1
        temporal?.reset()
        var observations: [EpisodeObservationV1] = []
        for (i, segment) in s.segments.enumerated() {
            temporal?.observe(riskLevel: segment.temporalRisk, topicLabels: segment.temporalTopics)
            // cacheEligible=false: each segment is a SHOT-moment analysis — the per-item cache must not
            // serve segment 1's understanding as segment N's evidence (world-model input law)
            let ctx = ExpertTaskContextV2(observationID: ObservationID(1), shotID: ShotID(UInt64(i + 1)), itemID: item,
                                          itemProvisional: provisional, identityRevision: identityRevision,
                                          profile: .appFullTier1, requestedDomains: ExpertDomainV2.allCases,
                                          generation: brain.currentGeneration, cacheEligible: false)
            let route = brain.route(input: segment.input, context: ctx, nowMs: segment.startMs)
            observations.append(EpisodeObservationV1(startMs: segment.startMs, endMs: segment.endMs,
                                                     shotIDs: [ShotID(UInt64(i + 1))], evidence: route.evidence,
                                                     unknownReasons: route.unknownReasons,
                                                     sourceText: segment.input.ocrText ?? segment.input.speechTranscript,
                                                     sourceLanguage: segment.input.detectedLanguage))
        }
        return WorldModelBuilderV1().build(observations: observations, itemID: item, itemProvisional: provisional,
                                           identityRevision: identityRevision, generation: brain.currentGeneration,
                                           nowMs: s.segments.last?.endMs ?? 0)
    }
}

// MARK: - split-leakage audit for the P009C corpus (same declared rule as R1 F2: J>0.8 + same modality combo)

public enum P009CLeakageAuditorV1 {
    static func tokens(_ s: P009CScenarioV1) -> Set<String> {
        let text = s.segments.compactMap { $0.input.ocrText ?? $0.input.speechTranscript }.joined(separator: " ")
            + " " + s.segments.flatMap { $0.input.visualLabels ?? [] }.joined(separator: " ")
        return Set(Lexicons.normalize(text).split(separator: " ").map(String.init))
    }
    static func combo(_ s: P009CScenarioV1) -> String {
        s.segments.map { seg in
            [seg.input.ocrText != nil ? "T" : "", seg.input.visualLabels != nil ? "V" : "",
             seg.input.soundEvents != nil ? "A" : "", seg.input.speechTranscript != nil ? "S" : ""].joined()
        }.joined(separator: "|")
    }
    public static func audit() -> [String] {
        var violations: [String] = []
        var names = Set<String>()
        let banks = P009CSplitV1.allCases.map { ($0, P009CCorpusV1.scenarios($0)) }
        for (split, bank) in banks {
            for s in bank where !names.insert(s.name).inserted { violations.append("dup-name:\(split.rawValue)/\(s.name)") }
        }
        for i in banks.indices {
            for j in banks.indices where j > i {
                for a in banks[i].1 {
                    for b in banks[j].1 {
                        let ta = tokens(a), tb = tokens(b)
                        let inter = ta.intersection(tb).count, uni = ta.union(tb).count
                        let jac = uni == 0 ? 0 : Double(inter) / Double(uni)
                        if jac > 0.8 && combo(a) == combo(b) {
                            violations.append("near-leak:\(banks[i].0.rawValue)/\(a.name)~\(banks[j].0.rawValue)/\(b.name)")
                        }
                    }
                }
            }
        }
        return violations
    }
}
