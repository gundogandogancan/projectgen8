import Foundation

// MARK: - P009B-R1 §3/§11 — split-INDEPENDENT rights-clear corpus. Replaces the seed-parity V1 design the
// independent audit refuted (F2: STRESS≡TUNE, OOD≡HELD-OUT byte-identical; CAL≡HELD-OUT).
// V2 law: there is NO seed parameter. Each split is a separately AUTHORED scenario bank with distinct
// instances, surface text (TR+EN mixed inside every split — held-out is NOT a translation of tune),
// modality combinations, temporal structures, and OOD transforms. `CorpusSplitLeakageAuditorV1` fails the
// suite on exact duplicates, seed aliasing, or near-template leakage (declared rule below).
// CALIBRATION_RESERVED is authored, hashed for reservation proof, and NEVER executed in P009B.

public enum P009BSplitV1: String, CaseIterable, Sendable {
    case tune = "TUNE", heldOut = "HELD_OUT", stress = "STRESS", ood = "OOD"
    case calibrationReserved = "CALIBRATION_RESERVED"
}

public enum P009BCorpusV2 {
    public static let revision = "p009b-corpus-v2"

    public static func scenarios(_ split: P009BSplitV1) -> [P009BScenarioV1] {
        switch split {
        case .tune: return tuneBank()
        case .heldOut: return heldOutBank()
        case .stress: return stressBank()
        case .ood: return oodBank()
        case .calibrationReserved: return calibrationReservedBank()
        }
    }
    public static var countsBySplit: [P009BSplitV1: Int] {
        Dictionary(uniqueKeysWithValues: P009BSplitV1.allCases.map { ($0, scenarios($0).count) })
    }

    // ── TUNE — full family coverage incl. the six R1 §11 additions ──
    static func tuneBank() -> [P009BScenarioV1] {
        var out: [P009BScenarioV1] = []
        out.append(.init(name: "t-image-only", family: "single-modality",
            input: ExpertInputV2(visualLabels: ["mountain", "lake"], visualConfidence: 0.75),
            expectEvidencePrefixes: ["scene:mountain"], forbidEvidencePrefixes: ["topic:"], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "t-text-only-en", family: "single-modality",
            input: ExpertInputV2(ocrText: "Learn how to build a birdhouse: step by step guide", detectedLanguage: "en"),
            expectEvidencePrefixes: ["language:en", "benefit:educational-candidate"], forbidEvidencePrefixes: ["scene:"], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "t-speech-only-tr", family: "single-modality",
            input: ExpertInputV2(speechTranscript: "bugün tarih dersini anlatıyoruz", speechAvailable: true),
            expectEvidencePrefixes: ["speech:present"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "t-audio-event-only", family: "single-modality",
            input: ExpertInputV2(soundEvents: ["traffic", "engine"]),
            expectEvidencePrefixes: ["audio:traffic", "audio:engine"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "t-music-only", family: "single-modality",
            input: ExpertInputV2(musicPresence: true, musicTempoEnergy: 0.4),
            expectEvidencePrefixes: ["music:present", "music-identity:UNAVAILABLE"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "t-symbol-heavy-tr", family: "single-modality",
            input: ExpertInputV2(ocrText: "⛔ 🚫 girilmez bölge ⚠", detectedLanguage: "tr"),
            expectEvidencePrefixes: ["symbol:warning-candidates", "symbol:context-dependent"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "t-agree-educational", family: "agreement",
            input: ExpertInputV2(ocrText: "science tutorial: explain the lesson", detectedLanguage: "en",
                                 visualLabels: ["whiteboard"], visualConfidence: 0.8,
                                 speechTranscript: "we explain the guide", speechAvailable: true),
            expectEvidencePrefixes: ["benefit:educational-candidate", "scene:whiteboard", "speech:present"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "t-agree-nature-calm", family: "agreement",
            input: ExpertInputV2(ocrText: "sakin doğa, orman ve deniz huzur veriyor", detectedLanguage: "tr",
                                 visualLabels: ["forest", "river"], visualConfidence: 0.8, soundEvents: ["nature", "water"]),
            expectEvidencePrefixes: ["benefit:calm-nature-candidate", "audio:nature", "scene:forest"], forbidEvidencePrefixes: ["safety:sensitive"], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "t-agree-warning-visual-speech", family: "agreement",
            input: ExpertInputV2(ocrText: "⚠ warning danger", detectedLanguage: "en", visualLabels: ["warning-sign"], visualConfidence: 0.7,
                                 speechTranscript: "warning: danger ahead on the road", speechAvailable: true),
            expectEvidencePrefixes: ["symbol:warning-candidates", "safety:fear-threat-candidate", "speech:present"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "t-conflict-benign-caption-risky-visualstory", family: "conflict",
            input: ExpertInputV2(ocrText: "lol so funny 😂 — fatal crash caught on camera", detectedLanguage: "en",
                                 visualLabels: ["street", "smoke"], visualConfidence: 0.6),
            expectEvidencePrefixes: ["safety:sensitive-death-disease-news", "topic:mortality", "scene:street"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "t-conflict-cheerful-visual-distressing-audio", family: "conflict",
            input: ExpertInputV2(ocrText: "relax and have fun tonight", detectedLanguage: "en",
                                 visualLabels: ["party", "balloons"], visualConfidence: 0.8, soundEvents: ["siren", "alarm"]),
            expectEvidencePrefixes: ["audio:siren", "benefit:calm-nature-candidate", "temporal:risk-escalated"], forbidEvidencePrefixes: [], expectContradiction: true, expectAbstention: false,
            temporalScript: [TemporalStepV1(risk: 0.7, topics: ["alarm"])]))
        out.append(.init(name: "t-conflict-educational-sensitive", family: "conflict",
            input: ExpertInputV2(ocrText: "kanser tedavisini anlatan ders: hastalık ve ölüm üzerine rehber", detectedLanguage: "tr"),
            expectEvidencePrefixes: ["benefit:educational-candidate", "safety:sensitive-death-disease-news"], forbidEvidencePrefixes: [], expectContradiction: true, expectAbstention: false))
        out.append(.init(name: "t-conflict-sarcasm-vs-literal", family: "conflict",
            // No sarcasm detector exists — the LAW under test: the literal trigger still fires (fail-safe)
            // and the mesh never fabricates a sarcasm interpretation.
            input: ExpertInputV2(ocrText: "oh sure, 'totally safe' — deadly explosion gone wrong", detectedLanguage: "en"),
            expectEvidencePrefixes: ["safety:sensitive-death-disease-news", "pattern:manipulation-language"], forbidEvidencePrefixes: ["sarcasm"], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "t-temporal-benign-then-risky", family: "temporal",
            input: ExpertInputV2(ocrText: "breaking: war casualties rising", detectedLanguage: "en"),
            expectEvidencePrefixes: ["temporal:risk-escalated", "safety:sensitive-death-disease-news"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false,
            temporalScript: [TemporalStepV1(risk: 0.1, topics: ["nature"]), TemporalStepV1(risk: 0.9, topics: ["war"])]))
        out.append(.init(name: "t-temporal-risky-benign-recovery", family: "temporal",
            // R1 §11 law: recovery NEVER erases historical strong risk — escalation survives the calm ending
            // and is represented as a contradiction against the calm evidence, not averaged away.
            input: ExpertInputV2(ocrText: "şimdi sakin doğa görüntüleri: orman ve deniz", detectedLanguage: "tr"),
            expectEvidencePrefixes: ["temporal:risk-escalated", "benefit:calm-nature-candidate"], forbidEvidencePrefixes: [], expectContradiction: true, expectAbstention: false,
            temporalScript: [TemporalStepV1(risk: 0.8, topics: ["disaster"]), TemporalStepV1(risk: 0.0, topics: ["nature"])]))
        out.append(.init(name: "t-temporal-montage", family: "temporal",
            input: ExpertInputV2(ocrText: "best moments compilation", detectedLanguage: "en", editDensityCutsPerMinute: 45),
            expectEvidencePrefixes: ["attention:rapid-edit-density", "temporal:narrative-shift"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false,
            temporalScript: [TemporalStepV1(risk: 0.2, topics: ["sport"]), TemporalStepV1(risk: 0.2, topics: ["music"]),
                             TemporalStepV1(risk: 0.2, topics: ["travel"]), TemporalStepV1(risk: 0.2, topics: ["food"])]))
        out.append(.init(name: "t-temporal-rapid-cuts", family: "temporal",
            input: ExpertInputV2(ocrText: "hemen izle şimdi", detectedLanguage: "tr", editDensityCutsPerMinute: 60),
            expectEvidencePrefixes: ["attention:rapid-edit-density", "attention:urgency-language"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "t-temporal-repeated-scene", family: "temporal",
            input: ExpertInputV2(ocrText: "learn the history lesson", detectedLanguage: "en", visualLabels: ["classroom"], visualConfidence: 0.7),
            expectEvidencePrefixes: ["benefit:educational-candidate", "scene:classroom"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false,
            routeTwice: true, expectCacheHitOnRepeat: true))
        out.append(.init(name: "t-temporal-talkinghead-broll", family: "temporal",
            input: ExpertInputV2(visualLabels: ["person-speaking"], visualConfidence: 0.7,
                                 speechTranscript: "today we explain how the engine works", speechAvailable: true),
            expectEvidencePrefixes: ["speech:present", "temporal:narrative-shift", "scene:person-speaking"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false,
            temporalScript: [TemporalStepV1(risk: 0, topics: ["interview"]), TemporalStepV1(risk: 0, topics: ["broll"]),
                             TemporalStepV1(risk: 0, topics: ["interview"])]))
        out.append(.init(name: "t-ood-unsupported-lang-de", family: "ood",
            input: ExpertInputV2(ocrText: "Dies ist ein deutscher Text über Geschichte", detectedLanguage: "de"),
            expectEvidencePrefixes: ["UNSUPPORTED_LANGUAGE"], forbidEvidencePrefixes: ["topic:"], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "t-ood-noisy-ocr", family: "ood",
            input: ExpertInputV2(ocrText: "q#7", detectedLanguage: "en"),
            expectEvidencePrefixes: ["language:en"], forbidEvidencePrefixes: ["topic:"], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "t-ood-absent-audio", family: "ood",
            input: ExpertInputV2(ocrText: "plain caption text", detectedLanguage: "en", soundEvents: nil),
            expectEvidencePrefixes: ["UNAVAILABLE:no-audio-provider-input"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "t-ood-empty-bundle", family: "ood",
            input: ExpertInputV2(),
            expectEvidencePrefixes: ["UNAVAILABLE:"], forbidEvidencePrefixes: ["topic:", "scene:"], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "t-ood-unsupported-audio", family: "ood",
            input: ExpertInputV2(soundEvents: ["hyperdrive-hum", "warp-field"]),
            expectEvidencePrefixes: ["audio:unsupported-classes", "audio:no-validated-events"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        return out
    }

    // ── HELD_OUT — distinct instances (new content, new combos; TR+EN mixed; NOT translations of TUNE) ──
    static func heldOutBank() -> [P009BScenarioV1] {
        var out: [P009BScenarioV1] = []
        out.append(.init(name: "h-image-only", family: "single-modality",
            input: ExpertInputV2(visualLabels: ["kitchen", "cooking-pan"], visualConfidence: 0.7),
            expectEvidencePrefixes: ["scene:kitchen"], forbidEvidencePrefixes: ["topic:"], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "h-text-only-tr", family: "single-modality",
            input: ExpertInputV2(ocrText: "bilim eğitimi: deneyleri adım adım anlat", detectedLanguage: "tr"),
            expectEvidencePrefixes: ["language:tr", "benefit:educational-candidate"], forbidEvidencePrefixes: ["scene:"], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "h-speech-only-en", family: "single-modality",
            input: ExpertInputV2(speechTranscript: "welcome to the garden tour", speechAvailable: true),
            expectEvidencePrefixes: ["speech:present"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "h-audio-only", family: "single-modality",
            input: ExpertInputV2(soundEvents: ["applause", "crowd"]),
            expectEvidencePrefixes: ["audio:applause", "audio:crowd"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "h-music-only", family: "single-modality",
            input: ExpertInputV2(musicPresence: true, musicTempoEnergy: 0.9),
            expectEvidencePrefixes: ["music:present", "music-identity:UNAVAILABLE"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "h-symbol-positive", family: "single-modality",
            input: ExpertInputV2(ocrText: "✅ onaylandı 🧠 bilgi 💡", detectedLanguage: "tr"),
            expectEvidencePrefixes: ["symbol:positive-candidates", "symbol:context-dependent"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "h-agree-cooking", family: "agreement",
            input: ExpertInputV2(ocrText: "how to cook pasta: a kitchen guide", detectedLanguage: "en",
                                 visualLabels: ["kitchen"], visualConfidence: 0.8, soundEvents: ["water"]),
            expectEvidencePrefixes: ["benefit:educational-candidate", "scene:kitchen", "audio:water"], forbidEvidencePrefixes: ["safety:sensitive"], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "h-agree-warning", family: "agreement",
            input: ExpertInputV2(ocrText: "dikkat tehlike var ⚠", detectedLanguage: "tr", visualLabels: ["caution-tape"], visualConfidence: 0.6),
            expectEvidencePrefixes: ["safety:fear-threat-candidate", "symbol:warning-candidates", "scene:caution-tape"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "h-conflict-wedding-grief", family: "conflict",
            input: ExpertInputV2(ocrText: "düğün videosu derken: cenaze haberi geldi, vefat acısı", detectedLanguage: "tr",
                                 visualLabels: ["wedding"], visualConfidence: 0.7),
            expectEvidencePrefixes: ["safety:sensitive-death-disease-news", "topic:mortality", "scene:wedding"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "h-conflict-edu-war", family: "conflict",
            input: ExpertInputV2(ocrText: "history lesson: the invasion and its casualties explained", detectedLanguage: "en"),
            expectEvidencePrefixes: ["benefit:educational-candidate", "safety:sensitive-death-disease-news"], forbidEvidencePrefixes: [], expectContradiction: true, expectAbstention: false))
        out.append(.init(name: "h-conflict-spa-alarm", family: "conflict",
            input: ExpertInputV2(ocrText: "calm relaxing ocean sounds", detectedLanguage: "en",
                                 visualLabels: ["spa", "candles"], visualConfidence: 0.8, soundEvents: ["alarm"]),
            expectEvidencePrefixes: ["benefit:calm-nature-candidate", "audio:alarm", "temporal:risk-escalated"], forbidEvidencePrefixes: [], expectContradiction: true, expectAbstention: false,
            temporalScript: [TemporalStepV1(risk: 0.65, topics: ["alarm"])]))
        out.append(.init(name: "h-temporal-vlog-fight", family: "temporal",
            input: ExpertInputV2(ocrText: "kavga görüntüleri tehlike", detectedLanguage: "tr"),
            expectEvidencePrefixes: ["temporal:risk-escalated", "safety:fear-threat-candidate"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false,
            temporalScript: [TemporalStepV1(risk: 0.0, topics: ["vlog"]), TemporalStepV1(risk: 0.75, topics: ["fight"])]))
        out.append(.init(name: "h-temporal-repeated", family: "temporal",
            input: ExpertInputV2(ocrText: "nasıl yapılır rehber", detectedLanguage: "tr", visualLabels: ["workshop"], visualConfidence: 0.6),
            expectEvidencePrefixes: ["benefit:educational-candidate", "scene:workshop"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false,
            routeTwice: true, expectCacheHitOnRepeat: true))
        out.append(.init(name: "h-ood-lang-ar", family: "ood",
            input: ExpertInputV2(ocrText: "هذا نص عربي عن التاريخ", detectedLanguage: "ar"),
            expectEvidencePrefixes: ["UNSUPPORTED_LANGUAGE"], forbidEvidencePrefixes: ["topic:"], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "h-ood-garbage", family: "ood",
            input: ExpertInputV2(ocrText: "∆∆9", detectedLanguage: "tr"),
            expectEvidencePrefixes: ["language:tr"], forbidEvidencePrefixes: ["topic:"], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "h-ood-no-music-provider", family: "ood",
            input: ExpertInputV2(ocrText: "street interview clip", detectedLanguage: "en", musicPresence: nil),
            expectEvidencePrefixes: ["UNAVAILABLE:no-music-provider-input"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        return out
    }

    // ── STRESS — extreme/adversarial variants (distinct from both banks above) ──
    static func stressBank() -> [P009BScenarioV1] {
        var out: [P009BScenarioV1] = []
        let flood = (1...64).map { "obj\($0)" }
        out.append(.init(name: "s-label-flood", family: "stress",
            input: ExpertInputV2(visualLabels: flood, visualConfidence: 0.9),
            expectEvidencePrefixes: ["scene:obj1"], forbidEvidencePrefixes: ["topic:"], expectContradiction: false, expectAbstention: true))
        let longText = String(repeating: "learn the lesson well ", count: 40) + "then deadly war casualties shelling everywhere"
        out.append(.init(name: "s-long-text-mixed", family: "stress",
            input: ExpertInputV2(ocrText: longText, detectedLanguage: "en"),
            expectEvidencePrefixes: ["benefit:educational-candidate", "safety:sensitive-death-disease-news"], forbidEvidencePrefixes: [], expectContradiction: true, expectAbstention: false))
        out.append(.init(name: "s-max-density-urgency", family: "stress",
            input: ExpertInputV2(ocrText: "hemen şimdi tıkla son şans acele et", detectedLanguage: "tr", editDensityCutsPerMinute: 240),
            expectEvidencePrefixes: ["attention:rapid-edit-density", "attention:urgency-language"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "s-all-modalities-benign", family: "stress",
            input: ExpertInputV2(ocrText: "guide to science experiments", detectedLanguage: "en",
                                 visualLabels: ["laboratory"], visualConfidence: 0.85, soundEvents: ["speech", "music"],
                                 speechTranscript: "lesson time for chemistry", speechAvailable: true,
                                 musicPresence: true, musicTempoEnergy: 0.3),
            expectEvidencePrefixes: ["benefit:educational-candidate", "scene:laboratory", "audio:speech", "speech:present", "music:present"], forbidEvidencePrefixes: ["safety:sensitive"], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "s-risk-then-calm-same-text", family: "stress",
            input: ExpertInputV2(ocrText: "ölümcül deprem felaketi: ama önce sakin doğa huzur", detectedLanguage: "tr"),
            expectEvidencePrefixes: ["topic:mortality", "topic:disaster", "benefit:calm-nature-candidate", "safety:sensitive-death-disease-news"], forbidEvidencePrefixes: [], expectContradiction: true, expectAbstention: false))
        out.append(.init(name: "s-repeat-hammer", family: "stress",
            input: ExpertInputV2(ocrText: "tutorial on woodworking", detectedLanguage: "en", visualLabels: ["workbench"], visualConfidence: 0.75),
            expectEvidencePrefixes: ["benefit:educational-candidate"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false,
            routeTwice: true, expectCacheHitOnRepeat: true))
        out.append(.init(name: "s-montage-extreme", family: "stress",
            input: ExpertInputV2(ocrText: "epic cuts", detectedLanguage: "en", editDensityCutsPerMinute: 120),
            expectEvidencePrefixes: ["attention:rapid-edit-density", "temporal:narrative-shift"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false,
            temporalScript: [TemporalStepV1(risk: 0.1, topics: ["a"]), TemporalStepV1(risk: 0.1, topics: ["b"]),
                             TemporalStepV1(risk: 0.1, topics: ["c"]), TemporalStepV1(risk: 0.1, topics: ["d"]),
                             TemporalStepV1(risk: 0.1, topics: ["e"]), TemporalStepV1(risk: 0.1, topics: ["f"]),
                             TemporalStepV1(risk: 0.1, topics: ["g"]), TemporalStepV1(risk: 0.1, topics: ["h"])]))
        out.append(.init(name: "s-symbol-flood", family: "stress",
            input: ExpertInputV2(ocrText: String(repeating: "⚠☠🔞⛔🚫✅💡", count: 10) + " uyarı", detectedLanguage: "tr"),
            expectEvidencePrefixes: ["symbol:warning-candidates", "symbol:positive-candidates"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "s-whitespace-text", family: "stress",
            input: ExpertInputV2(ocrText: "   \n\t   ", detectedLanguage: "en"),
            expectEvidencePrefixes: ["language:en"], forbidEvidencePrefixes: ["topic:"], expectContradiction: false, expectAbstention: false))
        out.append(.init(name: "s-boundary-confidence", family: "stress",
            input: ExpertInputV2(visualLabels: ["foggy-scene"], visualConfidence: 0.15),
            expectEvidencePrefixes: ["scene:foggy-scene"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        return out
    }

    // ── OOD — distinct transforms (malformed values, impossible flags, oversize, new languages) ──
    static func oodBank() -> [P009BScenarioV1] {
        var out: [P009BScenarioV1] = []
        out.append(.init(name: "o-lang-ja", family: "ood",
            input: ExpertInputV2(ocrText: "これは日本語の説明です", detectedLanguage: "ja"),
            expectEvidencePrefixes: ["UNSUPPORTED_LANGUAGE"], forbidEvidencePrefixes: ["topic:"], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "o-malformed-locale", family: "ood",
            input: ExpertInputV2(ocrText: "mixed ascii caption words", detectedLanguage: "zz-!!"),
            expectEvidencePrefixes: ["UNSUPPORTED_LANGUAGE"], forbidEvidencePrefixes: ["topic:"], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "o-nan-edit-density", family: "ood",
            input: ExpertInputV2(ocrText: "steady slow documentary", detectedLanguage: "en", editDensityCutsPerMinute: Double.nan),
            expectEvidencePrefixes: ["language:en"], forbidEvidencePrefixes: ["attention:rapid-edit-density"], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "o-negative-elapsed", family: "ood",
            input: ExpertInputV2(ocrText: "clock skew test video", detectedLanguage: "en", elapsedItemMs: -50),
            expectEvidencePrefixes: ["language:en"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "o-empty-arrays", family: "ood",
            input: ExpertInputV2(visualLabels: [], soundEvents: []),
            expectEvidencePrefixes: ["UNAVAILABLE:no-visual-provider-input", "audio:no-validated-events"], forbidEvidencePrefixes: ["scene:"], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "o-confidence-out-of-range", family: "ood",
            input: ExpertInputV2(visualLabels: ["beach"], visualConfidence: 7.5),
            expectEvidencePrefixes: ["scene:beach"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "o-oversized-labels", family: "ood",
            input: ExpertInputV2(visualLabels: (1...100).map { "bulk\($0)" }, visualConfidence: 0.5),
            expectEvidencePrefixes: ["scene:bulk1"], forbidEvidencePrefixes: ["scene:bulk99"], expectContradiction: false, expectAbstention: true))
        out.append(.init(name: "o-speech-flag-no-transcript", family: "ood",
            input: ExpertInputV2(speechTranscript: nil, speechAvailable: true),
            expectEvidencePrefixes: ["speech:none-detected"], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: true))
        return out
    }

    // ── CALIBRATION_RESERVED — authored + hashed for reservation proof; NEVER executed in P009B ──
    static func calibrationReservedBank() -> [P009BScenarioV1] {
        [
            .init(name: "cal-documentary-tr", family: "reserved",
                  input: ExpertInputV2(ocrText: "belgesel: antik kentin tarihi anlatılıyor", detectedLanguage: "tr"),
                  expectEvidencePrefixes: [], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false),
            .init(name: "cal-gameplay-en", family: "reserved",
                  input: ExpertInputV2(ocrText: "speedrun final boss strategy", detectedLanguage: "en", editDensityCutsPerMinute: 30),
                  expectEvidencePrefixes: [], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false),
            .init(name: "cal-news-flood", family: "reserved",
                  input: ExpertInputV2(ocrText: "son dakika: sel felaketi bölgeyi vurdu", detectedLanguage: "tr"),
                  expectEvidencePrefixes: [], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false),
            .init(name: "cal-asmr-calm", family: "reserved",
                  input: ExpertInputV2(ocrText: "soft rain sounds for sleep", detectedLanguage: "en", soundEvents: ["nature", "water"]),
                  expectEvidencePrefixes: [], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false),
            .init(name: "cal-debate-mixed", family: "reserved",
                  input: ExpertInputV2(ocrText: "tartışma programı: skandal iddialar", detectedLanguage: "tr",
                                       speechTranscript: "iddialar ve cevaplar", speechAvailable: true),
                  expectEvidencePrefixes: [], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false),
            .init(name: "cal-cooking-fail", family: "reserved",
                  input: ExpertInputV2(ocrText: "kitchen experiment goes sideways", detectedLanguage: "en",
                                       visualLabels: ["kitchen", "smoke"], visualConfidence: 0.6),
                  expectEvidencePrefixes: [], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false),
        ]
    }

    // ── mesh harness (V2): temporal script + optional repeat route + measured graph/state latency ──
    public struct RunResultV2 {
        public let route: MetaBrainRouteV2
        public let repeatRoute: MetaBrainRouteV2?
        public let state: ContentUnderstandingStateV1
        public let graph: CrossModalExpertGraphV1
    }
    public static func runScenario(_ s: P009BScenarioV1, brain: GuardianMetaBrainV2, item: ContentItemID,
                                   provisional: Bool = false, nowMs: Double) -> RunResultV2 {
        if !s.temporalScript.isEmpty, let t = brain.registry.expert(for: .temporal) as? TemporalExpertV1 {
            t.reset()
            for step in s.temporalScript { t.observe(riskLevel: step.risk, topicLabels: step.topics) }
        }
        let ctx = ExpertTaskContextV2(observationID: ObservationID(1), shotID: ShotID(item.raw), itemID: item,
                                      itemProvisional: provisional, profile: .appFullTier1,
                                      requestedDomains: ExpertDomainV2.allCases, generation: brain.currentGeneration)
        let route = brain.route(input: s.input, context: ctx, nowMs: nowMs)
        var repeatRoute: MetaBrainRouteV2? = nil
        if s.routeTwice {
            repeatRoute = brain.route(input: s.input, context: ctx, nowMs: nowMs + 1)
        }
        let graph = CrossModalExpertGraphV1()
        let g0 = brain.clock(); graph.relate(route.evidence); brain.latency.record("graph-fusion", ms: brain.clock() - g0)
        let s0 = brain.clock()
        let state = ContentUnderstandingStateV1.build(itemProvisional: provisional, evidence: route.evidence,
                                                      graph: graph, registry: brain.registry, unknownReasons: route.unknownReasons)
        brain.latency.record("state-build", ms: brain.clock() - s0)
        return RunResultV2(route: route, repeatRoute: repeatRoute, state: state, graph: graph)
    }
}

// MARK: - R1 F2 — split-leakage auditor. Declared near-duplicate rule:
// two scenarios in DIFFERENT splits leak when their canonical surface-token sets have Jaccard > 0.8
// AND they share the same modality combination. Exact canonical duplicates and seed-style aliasing
// (byte-identical canonical forms) always fail. CALIBRATION_RESERVED participates in hashing only.

public enum CorpusSplitLeakageAuditorV1 {
    public static let nearDuplicateJaccardThreshold = 0.8

    public static func canonical(_ s: P009BScenarioV1) -> String {
        let i = s.input
        var parts: [String] = []
        parts.append("ocr=" + (i.ocrText ?? "∅"))
        parts.append("lang=" + (i.detectedLanguage ?? "∅"))
        parts.append("vis=" + (i.visualLabels?.joined(separator: ",") ?? "∅"))
        parts.append("vconf=" + (i.visualConfidence.map { String($0) } ?? "∅"))
        parts.append("snd=" + (i.soundEvents?.joined(separator: ",") ?? "∅"))
        parts.append("spt=" + (i.speechTranscript ?? "∅"))
        parts.append("spa=" + String(i.speechAvailable))
        parts.append("mus=" + (i.musicPresence.map { String($0) } ?? "∅"))
        parts.append("tempo=" + (i.musicTempoEnergy.map { String($0) } ?? "∅"))
        parts.append("density=" + (i.editDensityCutsPerMinute.map { String($0) } ?? "∅"))
        parts.append("elapsed=" + (i.elapsedItemMs.map { String($0) } ?? "∅"))
        let script = s.temporalScript.map { step in String(step.risk) + ":" + step.topics.sorted().joined(separator: "+") }
        parts.append("script=" + script.joined(separator: "|"))
        return parts.joined(separator: ";")
    }
    static func modalityCombo(_ s: P009BScenarioV1) -> String {
        let i = s.input
        return [i.ocrText != nil ? "T" : "", i.visualLabels != nil ? "V" : "", i.soundEvents != nil ? "A" : "",
                i.speechTranscript != nil || i.speechAvailable ? "S" : "", i.musicPresence != nil ? "M" : "",
                i.editDensityCutsPerMinute != nil ? "D" : ""].joined()
    }
    static func tokens(_ s: P009BScenarioV1) -> Set<String> {
        let text = [s.input.ocrText, s.input.speechTranscript].compactMap { $0 }.joined(separator: " ")
            + " " + (s.input.visualLabels ?? []).joined(separator: " ")
            + " " + (s.input.soundEvents ?? []).joined(separator: " ")
        return Set(Lexicons.normalize(text).split(separator: " ").map(String.init)).subtracting([""])
    }
    static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        if a.isEmpty && b.isEmpty { return 1 }
        let inter = a.intersection(b).count, uni = a.union(b).count
        return uni == 0 ? 0 : Double(inter) / Double(uni)
    }
    /// Audits all split pairs. Empty result = independent. Each violation names the rule it broke.
    public static func audit() -> [String] {
        var violations: [String] = []
        var bySplit: [(P009BSplitV1, [P009BScenarioV1])] = []
        for split in P009BSplitV1.allCases { bySplit.append((split, P009BCorpusV2.scenarios(split))) }
        // unique names everywhere
        var seenNames = Set<String>()
        for (split, bank) in bySplit {
            for s in bank {
                if !seenNames.insert(s.name).inserted { violations.append("duplicate-name:\(split.rawValue)/\(s.name)") }
            }
        }
        for i in bySplit.indices {
            for j in bySplit.indices where j > i {
                let (sa, ba) = bySplit[i], (sb, bb) = bySplit[j]
                for x in ba {
                    let cx = canonical(x), tx = tokens(x), mx = modalityCombo(x)
                    for y in bb {
                        if cx == canonical(y) {
                            violations.append("exact-duplicate/seed-alias:\(sa.rawValue)/\(x.name)≡\(sb.rawValue)/\(y.name)")
                        } else if mx == modalityCombo(y), !tx.isEmpty || !tokens(y).isEmpty,
                                  jaccard(tx, tokens(y)) > nearDuplicateJaccardThreshold {
                            violations.append("near-template-leak(J>\(nearDuplicateJaccardThreshold)):\(sa.rawValue)/\(x.name)~\(sb.rawValue)/\(y.name)")
                        }
                    }
                }
            }
        }
        return violations
    }
    /// Reservation proof for CALIBRATION_RESERVED without executing it: a stable content hash.
    public static func reservedBankFingerprint() -> String {
        let joined = P009BCorpusV2.scenarios(.calibrationReserved).map(canonical).joined(separator: "\n")
        var h: UInt64 = 1469598103934665603                       // FNV-1a — deterministic, dependency-free
        for b in joined.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return String(format: "%016llx", h)
    }
}
