import Foundation

// MARK: - P009B §26/§27 — rights-clear multimodal eval corpus. 100% project-authored derived-input bundles with
// exact modality labels + expected-evidence expectations. No private production content; provenance = this file.
// Splits: TUNE(0) / CALIBRATION-RESERVED(9, untouched in P009B) / HELD-OUT(1) / STRESS(2) / OOD(3). No template
// leakage across the decision boundary: expectations are structural (which evidence families must/must-not appear),
// and seeds vary surface text/labels.

/// One temporal observation step for scripted narratives (risky→benign recovery, montage, B-roll).
public struct TemporalStepV1: Sendable {
    public let risk: Double
    public let topics: Set<String>
    public init(risk: Double, topics: Set<String>) { self.risk = risk; self.topics = topics }
}

public struct P009BScenarioV1: Sendable {
    public let name: String
    public let family: String                 // single-modality | agreement | conflict | temporal | ood
    public let input: ExpertInputV2
    public let expectEvidencePrefixes: [String]      // labels that MUST appear across the mesh output
    public let forbidEvidencePrefixes: [String]      // labels that must NOT appear
    public let expectContradiction: Bool
    public let expectAbstention: Bool                // UNKNOWN/unavailable expected from ≥1 requested expert
    // R1 additions (defaulted — V1 scenarios byte-identical in behavior)
    public let temporalScript: [TemporalStepV1]      // fed to TemporalExpertV1.observe before routing
    public let routeTwice: Bool                      // repeated-scene/cache families: route the same item again
    public let expectCacheHitOnRepeat: Bool
    public init(name: String, family: String, input: ExpertInputV2, expectEvidencePrefixes: [String],
                forbidEvidencePrefixes: [String], expectContradiction: Bool, expectAbstention: Bool,
                temporalScript: [TemporalStepV1] = [], routeTwice: Bool = false, expectCacheHitOnRepeat: Bool = false) {
        self.name = name; self.family = family; self.input = input
        self.expectEvidencePrefixes = expectEvidencePrefixes; self.forbidEvidencePrefixes = forbidEvidencePrefixes
        self.expectContradiction = expectContradiction; self.expectAbstention = expectAbstention
        self.temporalScript = temporalScript; self.routeTwice = routeTwice; self.expectCacheHitOnRepeat = expectCacheHitOnRepeat
    }
}

/// R1 F2 NOTE: this V1 corpus is FROZEN AUDIT EVIDENCE. Its seed-parity design was found non-independent
/// by the independent P009B audit (STRESS≡TUNE, OOD≡HELD-OUT byte-identical) and it no longer feeds any
/// gate. The rebuilt, split-independent corpus is `P009BCorpusV2`. V1 is retained so the auditor's AUDIT3
/// characterization probes keep running against the exact artifact they characterized.
public enum P009BCorpusV1 {
    static func t(_ seed: Int, _ en: String, _ tr: String) -> String { seed % 2 == 0 ? en : tr }
    static func lang(_ seed: Int) -> String { seed % 2 == 0 ? "en" : "tr" }

    public static func corpus(seed: Int) -> [P009BScenarioV1] {
        var out: [P009BScenarioV1] = []
        let L = lang(seed)
        // ── single modality ──
        out.append(P009BScenarioV1(name: "image-only", family: "single-modality",
            input: ExpertInputV2(visualLabels: ["landscape", "mountain"], visualConfidence: 0.8),
            expectEvidencePrefixes: ["scene:landscape"], forbidEvidencePrefixes: ["topic:"], expectContradiction: false, expectAbstention: true))
        out.append(P009BScenarioV1(name: "text-only", family: "single-modality",
            input: ExpertInputV2(ocrText: t(seed, "How to learn science: a lesson guide", "Bilim öğren: ders rehberi"), detectedLanguage: L),
            expectEvidencePrefixes: ["language:\(L)", "benefit:educational-candidate"], forbidEvidencePrefixes: ["scene:"], expectContradiction: false, expectAbstention: true))
        out.append(P009BScenarioV1(name: "speech-only", family: "single-modality",
            input: ExpertInputV2(speechTranscript: t(seed, "today we explain the lesson", "bugün dersi anlatıyoruz"), speechAvailable: true),
            expectEvidencePrefixes: ["speech:present"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        out.append(P009BScenarioV1(name: "audio-event-only", family: "single-modality",
            input: ExpertInputV2(soundEvents: ["siren", "crowd"]),
            expectEvidencePrefixes: ["audio:siren", "audio:crowd"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        out.append(P009BScenarioV1(name: "music-only", family: "single-modality",
            input: ExpertInputV2(musicPresence: true, musicTempoEnergy: 0.7),
            expectEvidencePrefixes: ["music:present", "music-identity:UNAVAILABLE"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        out.append(P009BScenarioV1(name: "symbol-heavy", family: "single-modality",
            input: ExpertInputV2(ocrText: "⚠☠ dikkat ⚠ " + t(seed, "warning", "uyarı"), detectedLanguage: L),
            expectEvidencePrefixes: ["symbol:warning-candidates", "symbol:context-dependent"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        // ── cross-modal agreement ──
        out.append(P009BScenarioV1(name: "educational-agreement", family: "agreement",
            input: ExpertInputV2(ocrText: t(seed, "learn how to build: tutorial lesson", "nasıl yapılır öğren: ders"), detectedLanguage: L,
                                 visualLabels: ["whiteboard", "classroom"], visualConfidence: 0.7,
                                 speechTranscript: t(seed, "we explain the guide", "rehberi anlatıyoruz"), speechAvailable: true),
            expectEvidencePrefixes: ["benefit:educational-candidate", "scene:whiteboard"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        out.append(P009BScenarioV1(name: "nature-calm-agreement", family: "agreement",
            input: ExpertInputV2(ocrText: t(seed, "calm nature forest relax", "sakin doğa orman huzur"), detectedLanguage: L,
                                 visualLabels: ["forest", "river"], visualConfidence: 0.8, soundEvents: ["nature", "water"]),
            expectEvidencePrefixes: ["benefit:calm-nature-candidate", "audio:nature"], forbidEvidencePrefixes: ["safety:sensitive"], expectContradiction: false, expectAbstention: false))
        // ── cross-modal conflict ──
        out.append(P009BScenarioV1(name: "benign-caption-risky-text", family: "conflict",
            input: ExpertInputV2(ocrText: t(seed, "so funny lol — breaking: deadly earthquake disaster kills",
                                                   "çok komik — son dakika: ölümcül deprem felaketi can aldı"), detectedLanguage: L,
                                 visualLabels: ["smiling-person"], visualConfidence: 0.6),
            expectEvidencePrefixes: ["safety:sensitive-death-disease-news", "topic:"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        out.append(P009BScenarioV1(name: "educational-plus-sensitive", family: "conflict",
            input: ExpertInputV2(ocrText: t(seed, "learn how disease spreads: medical lesson about death and illness",
                                                   "hastalık nasıl yayılır öğren: ölüm ve hastalık üstüne tıbbi ders"), detectedLanguage: L),
            expectEvidencePrefixes: ["benefit:educational-candidate", "safety:sensitive-death-disease-news"], forbidEvidencePrefixes: [], expectContradiction: true, expectAbstention: false))
        out.append(P009BScenarioV1(name: "urgency-manipulation", family: "conflict",
            input: ExpertInputV2(ocrText: t(seed, "HURRY! last chance, act now, you won't believe, click now, limited",
                                                   "ACELE ET! son şans, hemen şimdi, inanamayacaksın, tıkla, sınırlı"), detectedLanguage: L),
            expectEvidencePrefixes: ["attention:urgency-language", "pattern:manipulation-language"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        // ── temporal ──
        out.append(P009BScenarioV1(name: "benign-then-risky", family: "temporal",
            input: ExpertInputV2(ocrText: t(seed, "calm forest... then deadly war violence death everywhere",
                                                   "sakin orman... sonra ölümcül savaş ölüm her yerde"), detectedLanguage: L),
            expectEvidencePrefixes: ["safety:sensitive-death-disease-news"], forbidEvidencePrefixes: [], expectContradiction: true, expectAbstention: false))
        out.append(P009BScenarioV1(name: "rapid-cuts-pressure", family: "temporal",
            input: ExpertInputV2(ocrText: t(seed, "watch this", "şunu izle"), detectedLanguage: L, editDensityCutsPerMinute: 40),
            expectEvidencePrefixes: ["attention:rapid-edit-density"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        // ── OOD / missing ──
        out.append(P009BScenarioV1(name: "unsupported-language", family: "ood",
            input: ExpertInputV2(ocrText: "これは日本語のテキストです", detectedLanguage: "ja"),
            expectEvidencePrefixes: ["UNSUPPORTED_LANGUAGE"], forbidEvidencePrefixes: ["topic:"], expectContradiction: false, expectAbstention: true))
        out.append(P009BScenarioV1(name: "noisy-ocr", family: "ood",
            input: ExpertInputV2(ocrText: "x§2#", detectedLanguage: L),
            expectEvidencePrefixes: ["language:\(L)"], forbidEvidencePrefixes: ["topic:"], expectContradiction: false, expectAbstention: false))
        out.append(P009BScenarioV1(name: "absent-audio", family: "ood",
            input: ExpertInputV2(ocrText: t(seed, "normal text", "normal metin"), detectedLanguage: L, soundEvents: nil),
            expectEvidencePrefixes: ["UNAVAILABLE:no-audio-provider-input"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        out.append(P009BScenarioV1(name: "all-unavailable", family: "ood",
            input: ExpertInputV2(),
            expectEvidencePrefixes: ["UNAVAILABLE:"], forbidEvidencePrefixes: ["topic:", "scene:"], expectContradiction: false, expectAbstention: true))
        out.append(P009BScenarioV1(name: "unsupported-audio-classes", family: "ood",
            input: ExpertInputV2(soundEvents: ["quantum-hum", "unknown-xyz"]),
            expectEvidencePrefixes: ["audio:unsupported-classes", "audio:no-validated-events"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        return out
    }

    /// Run one scenario through the full mesh (registry/router/graph/state). Shared by tune/held-out/stress tests.
    public static func runScenario(_ s: P009BScenarioV1, brain: GuardianMetaBrainV2, item: ContentItemID,
                                   provisional: Bool = false, nowMs: Double) -> (route: MetaBrainRouteV2, state: ContentUnderstandingStateV1, graph: CrossModalExpertGraphV1) {
        let ctx = ExpertTaskContextV2(observationID: ObservationID(1), shotID: ShotID(item.raw), itemID: item,
                                      itemProvisional: provisional, profile: .appFullTier1,
                                      requestedDomains: ExpertDomainV2.allCases, generation: brain.currentGeneration)
        let route = brain.route(input: s.input, context: ctx, nowMs: nowMs)
        let graph = CrossModalExpertGraphV1()
        graph.relate(route.evidence)
        let state = ContentUnderstandingStateV1.build(itemProvisional: provisional, evidence: route.evidence,
                                                      graph: graph, registry: brain.registry, unknownReasons: route.unknownReasons)
        return (route, state, graph)
    }
}
