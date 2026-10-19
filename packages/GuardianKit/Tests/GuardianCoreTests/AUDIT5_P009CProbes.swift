import XCTest
@testable import GuardianCore

// AUDIT5 — independent P009C red-team probes (fresh-context auditor, 2026-10-19).
// ADD-ONLY file: no production source or prior test was modified. Probes marked FINDING assert the
// CURRENT (defective or gap) behavior so the suite stays green while the defect is proven and reported
// in docs/audit/GEN8_P009C_INDEPENDENT_AUDIT_REPORT.md. Fixing the defect SHOULD flip those asserts.

final class AUDIT5_P009CProbes: XCTestCase {

    // ── independent harness (mirrors, does not reuse, the shipped fixture) ──
    func brain() -> GuardianMetaBrainV2 {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1())
        b.registry.register(LanguageOCRExpertV1())
        b.registry.register(SpeechExpertV1())
        b.registry.register(AudioEventExpertV1())
        b.registry.register(MusicExpertV1())
        b.registry.register(SymbolExpertV1())
        b.registry.register(TemporalExpertV1())
        b.registry.register(SafetyEvidenceExpertV1())
        b.registry.register(BenefitEvidenceExpertV1())
        b.registry.register(AttentionPressureExpertV1())
        return b
    }
    func snap(_ b: GuardianMetaBrainV2, item: UInt64,
              state: IdentityResolutionSnapshotV1.ResolutionStateV1 = .confirmed) -> IdentityResolutionSnapshotV1 {
        IdentityResolutionSnapshotV1(itemID: ContentItemID(item), identityRevision: 0, resolutionState: state,
                                     sourceProfile: .appFullTier1, evidenceProvenance: "audit5",
                                     confirmationAuthority: .tier1AppFull, generation: b.currentGeneration,
                                     unresolvedSplitOrMerge: false, strongNewOrConflict: false)
    }
    func scenario(_ name: String, _ segs: [P009CSegmentV1]) -> P009CScenarioV1 {
        P009CScenarioV1(name: name, family: "audit5", segments: segs, annotation: P009CAnnotationV1())
    }
    func seg(_ s: Double, _ e: Double, _ i: ExpertInputV2, risk: Double = 0, topics: Set<String> = []) -> P009CSegmentV1 {
        P009CSegmentV1(startMs: s, endMs: e, input: i, temporalRisk: risk, temporalTopics: topics)
    }
    func run(_ s: P009CScenarioV1, item: UInt64, provisional: Bool = false) -> (ContentWorldModelV1, GuardianMetaBrainV2) {
        let b = brain()
        return (P009CCorpusV1.run(s, brain: b, item: ContentItemID(item), provisional: provisional), b)
    }
    func allTopics(_ m: ContentWorldModelV1) -> Set<String> { Set((m.primaryTopics + m.secondaryTopics).map { $0.concept }) }

    // 1 ── simultaneous topics in ONE moment: no forced single classification
    func testProbe_SimultaneousTopics() {
        let (m, _) = run(scenario("a5-simultaneous", [
            seg(0, 4000, ExpertInputV2(ocrText: "learn the lesson guide today", detectedLanguage: "en",
                                       visualLabels: ["kitchen"], visualConfidence: 0.8, musicPresence: true,
                                       musicTempoEnergy: 0.5))]), item: 5001)
        let t = allTopics(m)
        XCTAssertTrue(t.contains("concept:education"), "\(t)")
        XCTAssertTrue(t.contains("concept:cooking"), "\(t)")
        XCTAssertGreaterThanOrEqual(m.primaryTopics.count, 2, "multi-topic coexistence, no forced single")
        XCTAssertTrue(m.primaryTopics.allSatisfy { !$0.provenance.isEmpty }, "every topic carries provenance")
    }

    // 2 ── rapid topic shift: transitions + shift events + distinct episodes
    func testProbe_RapidTopicShift() {
        // NOTE: texts deliberately avoid cross-language substring traps (see F-2 probe below):
        // "lesson" contains TR urgency word "son" and would pollute every segment with concept:urgency.
        var segs: [P009CSegmentV1] = []
        for i in 0..<6 {
            let text = i % 2 == 0 ? "we explain the physics experiment guide" : "hurry buy now limited offer click"
            segs.append(seg(Double(i) * 1000, Double(i + 1) * 1000,
                            ExpertInputV2(ocrText: text, detectedLanguage: "en")))
        }
        let (m, _) = run(scenario("a5-rapid-shift", segs), item: 5002)
        XCTAssertGreaterThanOrEqual(m.episodes.count, 4, "alternating concepts never merge into one episode")
        XCTAssertGreaterThanOrEqual(m.events.filter { $0.kind == .topicShift }.count, 2,
                                    "\(m.episodes.map { $0.topicCandidates })")
        XCTAssertGreaterThanOrEqual(m.topicTransitions.count, 1)
    }

    // 2b ── AUDIT5 FINDING F-2 (documented quality defect): LexMatch substring containment matches
    // lexicon words of EVERY locale regardless of detectedLanguage — EN "lesson"/"sponsor" contain the
    // TR urgency token "son", so plain educational EN text silently gains concept:urgency +
    // concept:manipulation-language. Direction is conservative (extra candidate topics, never fewer),
    // but it suppresses topic-shift events/transitions (concept sets stop being disjoint) and the TUNE
    // gates never assert forbidden urgency on educational scenarios, so the eval bank cannot see it.
    func testProbe_FINDING_CrossLanguageSubstringTopicPollution() {
        let (m, _) = run(scenario("a5-substring-pollution", [
            seg(0, 3000, ExpertInputV2(ocrText: "science lesson guide part", detectedLanguage: "en"))]), item: 5022)
        // P009C-R1 FIX INVERSION (F-2; pre-declared in docs/audit/P009C_R1_FINDINGS_LOCK.md). Locale-
        // partitioned exact-token matching (LexiconMatcherV2): EN text never consults TR terms and
        // "lesson" is not the token "son" — no false urgency/manipulation pollution.
        XCTAssertFalse(allTopics(m).contains("concept:urgency"),
                       "F-2 FIXED: EN 'lesson' can no longer match TR 'son'")
        XCTAssertFalse(allTopics(m).contains("concept:manipulation-language"))
        XCTAssertTrue(allTopics(m).contains("concept:education"), "legitimate semantics intact")
    }

    // 3 ── entity ambiguity retained unresolved + structural non-identification
    func testProbe_EntityAmbiguityNonIdentifying() {
        let (m, _) = run(scenario("a5-entity-ambig", [
            seg(0, 3000, ExpertInputV2(visualLabels: ["forest", "spa"], visualConfidence: 0.85))]), item: 5003)
        let places = m.entities.filter { $0.kind == .place }
        XCTAssertGreaterThanOrEqual(places.count, 2, "both place candidates retained")
        XCTAssertTrue(places.allSatisfy { $0.conflicting && $0.uncertainty >= 0.7 }, "conflict marked, never auto-resolved")
        let g = EntityGraphV1()
        XCTAssertFalse(g.observe(label: "name:john-doe", kind: .personPresent, confidence: 0.99, provenance: "a5"))
        XCTAssertFalse(g.observe(label: "ethnicity-guess", kind: .concept, confidence: 0.99, provenance: "a5"))
        XCTAssertFalse(g.observe(label: "stranger", kind: .personPresent, confidence: 0.99, provenance: "a5"),
                       "person-present only from non-identifying presence signals")
        XCTAssertEqual(g.count, 0)
    }

    // 4 ── ambiguous intent (fresh wording): teach vs sell/engagement must stay ambiguous
    func testProbe_IntentAmbiguityFresh() {
        let (m, _) = run(scenario("a5-intent-ambig", [
            seg(0, 4000, ExpertInputV2(ocrText: "learn this lesson guide now! subscribe fast — limited offer",
                                       detectedLanguage: "en"))]), item: 5004)
        XCTAssertTrue(m.intentAmbiguous, "close competing intents: \(m.intents.map { ($0.intent.rawValue, $0.weight) })")
        XCTAssertGreaterThanOrEqual(m.intents.count, 2)
        XCTAssertTrue(m.intents.allSatisfy { $0.uncertainty > 0 }, "intent is hypothesis, never certain fact")
    }

    // 5 ── sarcasm vs literal: qualifier annotates, lexical risk evidence survives
    func testProbe_SarcasmVsLiteral() {
        let (sarcastic, _) = run(scenario("a5-sarcasm", [
            seg(0, 3000, ExpertInputV2(ocrText: "lol parody: deadly stunt goes wrong, just kidding",
                                       detectedLanguage: "en"))]), item: 5005)
        XCTAssertTrue(sarcastic.episodes.first?.contextTags.contains(.satireHumorCandidate) ?? false)
        XCTAssertTrue(allTopics(sarcastic).contains("concept:mortality"),
                      "satire qualifier can never DELETE the lexical risk evidence")
        XCTAssertTrue(sarcastic.contradictionResolutions.allSatisfy { $0.riskRetained })
        let (literal, _) = run(scenario("a5-literal", [
            seg(0, 3000, ExpertInputV2(ocrText: "deadly accident reported on the highway", detectedLanguage: "en"))]),
            item: 5006)
        XCTAssertTrue(literal.episodes.first?.contextTags.contains(.literal) ?? false)
        XCTAssertFalse(literal.episodes.first?.contextTags.contains(.satireHumorCandidate) ?? true)
    }

    // 6 ── quote vs speaker stance: quoted threat retained + provoke intent explicitly countered
    func testProbe_QuoteVsSpeakerStance() {
        let (m, _) = run(scenario("a5-quote", [
            seg(0, 4000, ExpertInputV2(ocrText: "the report said \"they threaten to kill everyone\" in the statement",
                                       detectedLanguage: "en"))]), item: 5007)
        XCTAssertTrue(m.episodes.first?.contextTags.contains(.quoted) ?? false)
        XCTAssertTrue(allTopics(m).contains("concept:fear-threat") || allTopics(m).contains("concept:mortality"),
                      "quoted risk evidence retained: \(allTopics(m))")
        if let provoke = m.intents.first(where: { $0.intent == .provoke }) {
            XCTAssertTrue(provoke.counterEvidence.contains("context:quoted"),
                          "quote context counters the provoke hypothesis without erasing it")
        }
    }

    // 7 ── benign caption + strong risk (audio+temporal): risk dominates/retains, never erased by caption
    func testProbe_BenignCaptionStrongRiskConflict() {
        let (m, _) = run(scenario("a5-benign-caption-risk", [
            seg(0, 4000, ExpertInputV2(ocrText: "relax and enjoy the calm spa day", detectedLanguage: "en",
                                       visualLabels: ["spa"], visualConfidence: 0.8, soundEvents: ["siren", "alarm"]),
                risk: 0.75, topics: ["alarm"])]), item: 5008)
        XCTAssertGreaterThanOrEqual(m.contradictionResolutions.count, 1, "conflict must be represented")
        for r in m.contradictionResolutions {
            XCTAssertTrue([.strongRiskDominant, .modalityPriority, .unresolved, .temporalReinterpretation].contains(r.outcome),
                          "benign caption can never CONTEXT_QUALIFY away non-lexical risk: \(r.outcome)")
            XCTAssertTrue(r.riskRetained)
        }
        XCTAssertGreaterThanOrEqual(m.maxRiskSeen, 0.6)
    }

    // 8 ── risky→benign: monotone historical risk law + recovery observed, nothing erased
    func testProbe_RiskyToBenignMonotoneLaw() {
        let (m, _) = run(scenario("a5-risky-benign", [
            seg(0, 3000, ExpertInputV2(ocrText: "korkunç kaza: ölüm ve yaralılar var", detectedLanguage: "tr"),
                risk: 0.9, topics: ["accident"]),
            seg(3000, 6000, ExpertInputV2(ocrText: "şimdi huzurlu göl kenarında sakin bir akşam", detectedLanguage: "tr",
                                          visualLabels: ["lake"], visualConfidence: 0.85), risk: 0, topics: ["calm"])]),
            item: 5009)
        XCTAssertGreaterThanOrEqual(m.maxRiskSeen, 0.6, "benign tail can NEVER erase historical strong risk")
        XCTAssertTrue(m.narrativeLabels.contains("narrative:risk-escalated"))
        XCTAssertTrue(m.narrativeLabels.contains(where: { $0.hasPrefix("narrative:recovery-observed") }))
        XCTAssertTrue(m.contradictionResolutions.allSatisfy { $0.riskRetained })
        XCTAssertGreaterThanOrEqual(m.episodes.count, 2)
    }

    // 9 ── benign→risky: escalation is an EVENT; risk registers fully
    func testProbe_BenignToRiskyEscalation() {
        let (m, _) = run(scenario("a5-benign-risky", [
            seg(0, 3000, ExpertInputV2(ocrText: "mutlu kutlama hazırlığı", detectedLanguage: "tr",
                                       visualLabels: ["balloons"], visualConfidence: 0.8), risk: 0.05, topics: ["party"]),
            seg(3000, 6000, ExpertInputV2(ocrText: "yangın felaketi: ölüm riski artıyor", detectedLanguage: "tr",
                                          soundEvents: ["alarm"]), risk: 0.85, topics: ["fire"])]), item: 5010)
        XCTAssertGreaterThanOrEqual(m.maxRiskSeen, 0.6)
        XCTAssertTrue(m.events.contains { $0.kind == .riskEscalation }, "\(m.events.map { $0.kind.rawValue })")
    }

    // 10 ── montage: multiple topics survive, episodes stay distinct
    func testProbe_MontageMultiTopic() {
        let scenes = ["classroom", "kitchen", "forest", "party"]
        let segs = scenes.enumerated().map { (i, sc) in
            seg(Double(i) * 1000, Double(i + 1) * 1000,
                ExpertInputV2(visualLabels: [sc], visualConfidence: 0.8, editDensityCutsPerMinute: 60), topics: [sc])
        }
        let (m, _) = run(scenario("a5-montage", segs), item: 5011)
        XCTAssertGreaterThanOrEqual(m.episodes.count, 3)
        let t = allTopics(m)
        XCTAssertTrue(t.isSuperset(of: ["concept:education", "concept:cooking", "concept:calm-nature", "concept:celebration"]), "\(t)")
    }

    // 11 ── B-roll return: A-B-A keeps three episodes and surfaces the returning motif
    func testProbe_BRollReturnMotif() {
        let (m, _) = run(scenario("a5-broll", [
            seg(0, 2000, ExpertInputV2(visualLabels: ["person-speaking"], visualConfidence: 0.8)),
            seg(2000, 4000, ExpertInputV2(visualLabels: ["workbench"], visualConfidence: 0.7)),
            seg(4000, 6000, ExpertInputV2(visualLabels: ["person-speaking"], visualConfidence: 0.8))]), item: 5012)
        XCTAssertGreaterThanOrEqual(m.episodes.count, 3, "B-roll break prevents cross-topic merge")
        XCTAssertTrue(m.narrativeMotifs.contains { $0.concept == "concept:talking-head" && $0.occurrences >= 2 },
                      "scene return is a motif: \(m.narrativeMotifs)")
        XCTAssertTrue(m.entities.contains { $0.kind == .personPresent }, "non-identifying presence only")
    }

    // 12 ── repeated scene: adjacent same-topic episodes MERGE with revision bump, never duplicate
    func testProbe_RepeatedSceneMergeRevision() {
        let (m, _) = run(scenario("a5-repeat", [
            seg(0, 2000, ExpertInputV2(visualLabels: ["forest"], visualConfidence: 0.85)),
            seg(2000, 4000, ExpertInputV2(visualLabels: ["forest"], visualConfidence: 0.85)),
            seg(4000, 6000, ExpertInputV2(visualLabels: ["forest"], visualConfidence: 0.85))]), item: 5013)
        XCTAssertEqual(m.episodes.count, 1, "same dominant topic, adjacent → one merged episode")
        XCTAssertGreaterThanOrEqual(m.episodes[0].revision, 2, "merge bumps revision (temporal/revision-aware)")
        XCTAssertEqual(m.episodes[0].shotIDs.count, 3)
        XCTAssertEqual(m.episodes[0].endMs, 6000)
    }

    // 13 ── stale/late episode evidence: wrong-generation evidence can never shape the model
    func testProbe_GenerationMismatchEvidenceExcluded() {
        let g: UInt64 = 7
        let old = ExpertEvidenceV2(domain: .safetyEvidence, labels: ["safety:sensitive-death-disease-news"],
                                   confidence: 0.95, coverage: 1, uncertainty: 0.05, itemID: ContentItemID(5014),
                                   itemProvisional: false, provenance: "a5-old-gen", modelVersion: "m",
                                   calibrationStatus: .implementedUncalibrated, generation: g - 1)
        let obs = [EpisodeObservationV1(startMs: 0, endMs: 1000, shotIDs: [ShotID(1)], evidence: [old],
                                        unknownReasons: [], sourceText: nil)]
        let m = WorldModelBuilderV1().build(observations: obs, itemID: ContentItemID(5014), itemProvisional: false,
                                            identityRevision: 0, generation: g, nowMs: 0)
        XCTAssertTrue(allTopics(m).isEmpty, "old-generation evidence excluded: \(allTopics(m))")
        XCTAssertTrue(m.uncertainty.notes.contains { $0.hasPrefix("wm:stale-evidence-excluded") })
        XCTAssertFalse(m.readiness)
    }

    // 14 ── provisional identity can NEVER finalize DNA — including via a spoofed confirmed snapshot
    func testProbe_ProvisionalDNARefusalIncludingSpoof() {
        let s = scenario("a5-prov", [
            seg(0, 4000, ExpertInputV2(ocrText: "learn the science lesson: a clear guide", detectedLanguage: "en",
                                       visualLabels: ["classroom"], visualConfidence: 0.8))])
        let b = brain()
        let m = P009CCorpusV1.run(s, brain: b, item: ContentItemID(5015), provisional: true)
        XCTAssertFalse(m.readiness)
        XCTAssertTrue(m.anyEvidenceProvisional, "evidence-level provisional markers exist independently of the caller")
        let fin = ContentDNAFinalizerV1()
        XCTAssertNil(fin.finalize(model: m, identity: snap(b, item: 5015, state: .provisional),
                                  currentGeneration: b.currentGeneration, dnaRaw: 1, nowMs: 0).dna)
        let spoofed = fin.finalize(model: m, identity: snap(b, item: 5015), // falsely claims CONFIRMED
                                   currentGeneration: b.currentGeneration, dnaRaw: 2, nowMs: 0)
        XCTAssertNil(spoofed.dna, "spoofed authoritative snapshot still refused — evidence markers win")
    }

    // 15 ── confirmed item SPLITS after DNA: DNA invalidated + semantic cache refuses the new revision
    func testProbe_SplitAfterDNAInvalidatesDNAAndCache() {
        let s = scenario("a5-split", [
            seg(0, 4000, ExpertInputV2(ocrText: "learn the science lesson: a clear guide", detectedLanguage: "en",
                                       visualLabels: ["classroom"], visualConfidence: 0.8))])
        let b = brain()
        let m = P009CCorpusV1.run(s, brain: b, item: ContentItemID(5016))
        let fin = ContentDNAFinalizerV1()
        let (dna, refusal) = fin.finalize(model: m, identity: snap(b, item: 5016),
                                          currentGeneration: b.currentGeneration, dnaRaw: 3, nowMs: 0)
        XCTAssertNil(refusal); XCTAssertNotNil(dna)
        XCTAssertEqual(fin.applyRevision(item: ContentItemID(5016), trigger: .identitySplitMerge, nowMs: 10), .invalidated)
        XCTAssertEqual(fin.current(item: ContentItemID(5016))?.revisionState, .invalidated)
        let cache = WorldModelCacheV1()
        cache.insert(m, nowMs: 0)
        XCTAssertNotNil(cache.lookup(item: ContentItemID(5016), identityRevision: 0, generation: m.generation, nowMs: 1).0)
        let (hit, reason) = cache.lookup(item: ContentItemID(5016), identityRevision: 1, generation: m.generation, nowMs: 1)
        XCTAssertNil(hit); XCTAssertEqual(reason, "revision-mismatch")
        XCTAssertNil(cache.lookup(item: ContentItemID(5016), identityRevision: 0, generation: m.generation, nowMs: 2).0,
                     "revision mismatch EVICTS — stale world model is gone, not resurrectable")
    }

    // 16 ── model/taxonomy version change: DNA superseded with append-only audit trail
    func testProbe_ModelAndTaxonomyChangeSupersede() {
        let s = scenario("a5-tax", [
            seg(0, 4000, ExpertInputV2(ocrText: "learn the science lesson: a clear guide", detectedLanguage: "en",
                                       visualLabels: ["classroom"], visualConfidence: 0.8))])
        let b = brain()
        let m = P009CCorpusV1.run(s, brain: b, item: ContentItemID(5017))
        XCTAssertEqual(m.taxonomyVersion, SemanticTaxonomyV1.version, "world model binds the live taxonomy version")
        let fin = ContentDNAFinalizerV1()
        _ = fin.finalize(model: m, identity: snap(b, item: 5017), currentGeneration: b.currentGeneration, dnaRaw: 4, nowMs: 0)
        XCTAssertEqual(fin.applyRevision(item: ContentItemID(5017), trigger: .modelVersionChange, nowMs: 10), .superseded)
        XCTAssertEqual(fin.applyRevision(item: ContentItemID(5017), trigger: .taxonomyChange, nowMs: 20), .superseded)
        let trail = fin.current(item: ContentItemID(5017))?.auditTrail ?? []
        XCTAssertGreaterThanOrEqual(trail.count, 3, "append-only provenance: \(trail)")
        XCTAssertTrue(trail.allSatisfy { $0.hasPrefix("revision:") })
    }

    // 17 ── unsupported language (fresh locale fr): abstention + DNA refusal, no fabricated topics
    func testProbe_UnsupportedLanguageFrenchAbstains() {
        let s = scenario("a5-fr", [
            seg(0, 3000, ExpertInputV2(ocrText: "une petite histoire du soir pour les enfants", detectedLanguage: "fr"))])
        let b = brain()
        let m = P009CCorpusV1.run(s, brain: b, item: ContentItemID(5018))
        XCTAssertGreaterThanOrEqual(m.uncertainty.language, 0.5, "language axis must be raised")
        XCTAssertFalse(m.readiness)
        let fin = ContentDNAFinalizerV1()
        let (dna, refusal) = fin.finalize(model: m, identity: snap(b, item: 5018),
                                          currentGeneration: b.currentGeneration, dnaRaw: 5, nowMs: 0)
        XCTAssertNil(dna); XCTAssertNotNil(refusal)
    }

    // 18 ── correlated evidence amplification: 4 same-family records give ZERO extra certainty
    func testProbe_CorrelatedEvidenceNeverAmplifies() {
        func ev(_ d: ExpertDomainV2) -> ExpertEvidenceV2 {
            ExpertEvidenceV2(domain: d, labels: ["safety:sensitive-death-disease-news"], confidence: 0.9, coverage: 1,
                             uncertainty: 0.1, itemProvisional: false, provenance: "a5-\(d.rawValue)",
                             modelVersion: "m", calibrationStatus: .implementedUncalibrated, generation: 0)
        }
        let single = EvidenceWeigherV1.combine([ev(.languageOCR)])
        let flood = EvidenceWeigherV1.combine([ev(.languageOCR), ev(.speech), ev(.safetyEvidence), ev(.attentionPressure)])
        XCTAssertEqual(flood.families.count, 1, "OCR/speech/safety/attention lexical records = ONE family")
        XCTAssertEqual(flood.strength, single.strength, accuracy: 1e-9,
                       "4 correlated records add exactly ZERO certainty over 1")
        // independent families are bounded, never multiplied
        let cross = EvidenceWeigherV1.combine([ev(.languageOCR),
            ExpertEvidenceV2(domain: .vision, labels: ["scene:smoke"], confidence: 0.9, coverage: 1, uncertainty: 0.1,
                             itemProvisional: false, provenance: "a5-vis", modelVersion: "m",
                             calibrationStatus: .implementedUncalibrated, generation: 0)])
        XCTAssertLessThanOrEqual(cross.strength, single.strength + 0.15 + 1e-9)
    }

    // 19 ── raw OCR + raw TRANSCRIPT leakage: planted unique tokens must never reach durable DNA
    func testProbe_RawTextAndTranscriptCannotReachDNA() {
        let tok = "zq9auditSecret77"
        let s = scenario("a5-leak-text", [
            seg(0, 4000, ExpertInputV2(ocrText: "learn the science lesson guide \(tok)", detectedLanguage: "en",
                                       visualLabels: ["classroom"], visualConfidence: 0.8,
                                       speechTranscript: "the lesson \(tok) continues", speechAvailable: true))])
        let b = brain()
        let m = P009CCorpusV1.run(s, brain: b, item: ContentItemID(5019))
        let fin = ContentDNAFinalizerV1()
        guard let d = fin.finalize(model: m, identity: snap(b, item: 5019),
                                   currentGeneration: b.currentGeneration, dnaRaw: 6, nowMs: 0).dna else {
            return XCTFail("educational scenario should finalize")
        }
        let durable = d.topics + d.entities + d.intents + d.narrativeSummary + d.temporalStructure + d.safetyEvidence
            + d.benefitEvidence + d.manipulationEvidence + d.emotionalLoad + d.contradictionOutcomes
            + d.auditTrail + d.meshModelVersions + [d.worldModelVersion, d.taxonomyVersion]
        XCTAssertFalse(durable.contains { $0.contains(tok) }, "raw OCR/transcript text never persists")
        // and the live world model's episodes also carry no raw text
        XCTAssertFalse(m.episodes.flatMap { $0.topicCandidates + $0.safetyEvidence + $0.benefitEvidence }
            .contains { $0.contains(tok) })
    }

    // 20 ── AUDIT5 FINDING F-1 (documented defect): a planted token in PROVIDER VISUAL LABELS flows
    // verbatim into durable DNA as `entity:object:<token>` because the persistence-law whitelist accepts
    // ANY string with an `entity:` prefix and neither the sanitizer nor EntityGraph whitelists label text.
    // The shipped leak test only plants tokens in OCR text. This assert PROVES the current gap; a proper
    // fix (canonical entity vocabulary or label whitelist) should FLIP this assertion.
    func testProbe_FINDING_VisualLabelTokenReachesDurableDNA() {
        let tok = "zq9plantedlabel"
        let s = scenario("a5-leak-visual", [
            seg(0, 4000, ExpertInputV2(ocrText: "learn the science lesson: a clear guide", detectedLanguage: "en",
                                       visualLabels: ["classroom", tok], visualConfidence: 0.8))])
        let b = brain()
        let m = P009CCorpusV1.run(s, brain: b, item: ContentItemID(5020))
        let fin = ContentDNAFinalizerV1()
        let (dna, refusal) = fin.finalize(model: m, identity: snap(b, item: 5020),
                                          currentGeneration: b.currentGeneration, dnaRaw: 7, nowMs: 0)
        // P009C-R1 FIX INVERSION (F-1; pre-declared in docs/audit/P009C_R1_FINDINGS_LOCK.md — the auditor's
        // own comment: "a proper fix ... should FLIP this assertion"). Closed-vocabulary law, NOT a token
        // blacklist: the unmapped provider label stays ephemeral; finalize succeeds WITHOUT the token.
        XCTAssertNil(refusal, "finalize succeeds — the mapped 'classroom' atom is lawful; the planted label is simply ephemeral")
        let leaked = (dna?.entities ?? []).contains { $0.contains(tok) }
        XCTAssertFalse(leaked, "F-1 FIXED: provider visual-label text can never reach durable DNA")
        XCTAssertFalse(WorldModelPersistenceLawV1.isLawfulDurable("entity:object:\(tok)"),
                       "F-1 FIXED: entity strings are lawful only as closed-vocabulary atoms")
        XCTAssertTrue(dna?.entities.contains("entity:place:classroom") ?? false, "mapped atoms still persist")
    }

    // 21 ── unbounded episode spam: hard bounds hold, overflow is dropped HONESTLY (reason surfaced)
    func testProbe_EpisodeSpamBounded() {
        let g: UInt64 = 1
        var obs: [EpisodeObservationV1] = []
        for i in 0..<300 {
            let label = i % 2 == 0 ? "benefit:educational-candidate" : "attention:urgency-language"
            let domain: ExpertDomainV2 = i % 2 == 0 ? .benefitEvidence : .attentionPressure
            let e = ExpertEvidenceV2(domain: domain, labels: [label], confidence: 0.8, coverage: 1, uncertainty: 0.2,
                                     itemID: ContentItemID(5021), itemProvisional: false, provenance: "a5-spam",
                                     modelVersion: "m", calibrationStatus: .implementedUncalibrated, generation: g)
            obs.append(EpisodeObservationV1(startMs: Double(i) * 100, endMs: Double(i + 1) * 100,
                                            shotIDs: [ShotID(UInt64(i + 1))], evidence: [e], unknownReasons: []))
        }
        let m = WorldModelBuilderV1().build(observations: obs, itemID: ContentItemID(5021), itemProvisional: false,
                                            identityRevision: 0, generation: g, nowMs: 0)
        XCTAssertEqual(m.episodes.count, 256, "hard episode bound")
        XCTAssertTrue(m.uncertainty.notes.contains { $0.hasPrefix("wm:episodes-bounded-dropped") },
                      "overflow is reported, never silent: \(m.uncertainty.notes)")
        XCTAssertLessThanOrEqual(m.events.count, 256)
        XCTAssertLessThanOrEqual(m.provenance.count, 512)
        XCTAssertLessThanOrEqual(m.primaryTopics.count + m.secondaryTopics.count, 64 + 128)
    }

    // 22 ── foreign evidence: finalizer refuses it (law holds); AUDIT5 FINDING F-5 (LOW, documented):
    // WorldModelCacheV1 happily caches a model whose evidence belongs to ANOTHER item — no evidence-purity
    // mirror of the finalizer's foreignEvidence gate. No production writer exists today (cache is unwired),
    // so impact is latent; assert documents the current gap.
    func testProbe_ForeignEvidenceDNARefusedButCacheAccepts() {
        let b = brain()
        let ctx = ExpertTaskContextV2(observationID: ObservationID(1), shotID: ShotID(1), itemID: ContentItemID(111),
                                      itemProvisional: false, profile: .appFullTier1,
                                      requestedDomains: ExpertDomainV2.allCases, generation: b.currentGeneration,
                                      cacheEligible: false)
        let route = b.route(input: ExpertInputV2(ocrText: "learn the science lesson: a clear guide",
                                                 detectedLanguage: "en", visualLabels: ["classroom"],
                                                 visualConfidence: 0.8), context: ctx, nowMs: 0)
        let obs = [EpisodeObservationV1(startMs: 0, endMs: 4000, shotIDs: [ShotID(1)], evidence: route.evidence,
                                        unknownReasons: route.unknownReasons, sourceText: nil)]
        // model claims item 222 while ALL its evidence is stamped item 111
        let m = WorldModelBuilderV1().build(observations: obs, itemID: ContentItemID(222), itemProvisional: false,
                                            identityRevision: 0, generation: b.currentGeneration, nowMs: 4000)
        XCTAssertEqual(m.evidenceItemIDs, [111])
        let fin = ContentDNAFinalizerV1()
        let (dna, refusal) = fin.finalize(model: m, identity: snap(b, item: 222),
                                          currentGeneration: b.currentGeneration, dnaRaw: 8, nowMs: 0)
        XCTAssertNil(dna)
        XCTAssertEqual(refusal, .foreignEvidence, "DNA layer: foreign evidence structurally refused")
        let cache = WorldModelCacheV1()
        cache.insert(m, nowMs: 0)
        XCTAssertNotNil(cache.lookup(item: ContentItemID(222), identityRevision: 0,
                                     generation: b.currentGeneration, nowMs: 1).0,
                        "F-5: cache layer accepts the impure model (no foreign-evidence gate)")
    }
}
