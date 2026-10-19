import XCTest
@testable import GuardianCore

// AUDIT6 — independent P009C-R1 RE-AUDIT probes (fresh-context auditor, 2026-10-19).
// ADD-ONLY file: no production source or prior test was modified. Tokens are the AUDITOR'S OWN
// (never the builder's AUDIT5/R1 fixtures), so any fixture-token blacklist would be useless.
// Probes marked FINDING assert CURRENT behavior so the suite stays green while the defect is
// reported in docs/audit/GEN8_P009C_R1_REAUDIT_REPORT.md.

final class AUDIT6_P009CR1Probes: XCTestCase {

    // ── independent harness (mirrors, does not reuse, the shipped fixtures) ──
    func brain() -> GuardianMetaBrainV2 {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1()); b.registry.register(LanguageOCRExpertV1())
        b.registry.register(SpeechExpertV1()); b.registry.register(AudioEventExpertV1())
        b.registry.register(MusicExpertV1()); b.registry.register(SymbolExpertV1())
        b.registry.register(TemporalExpertV1()); b.registry.register(SafetyEvidenceExpertV1())
        b.registry.register(BenefitEvidenceExpertV1()); b.registry.register(AttentionPressureExpertV1())
        return b
    }
    func snap(_ b: GuardianMetaBrainV2, item: UInt64, provenance: String = "audit6") -> IdentityResolutionSnapshotV1 {
        IdentityResolutionSnapshotV1(itemID: ContentItemID(item), identityRevision: 0, resolutionState: .confirmed,
                                     sourceProfile: .appFullTier1, evidenceProvenance: provenance,
                                     confirmationAuthority: .tier1AppFull, generation: b.currentGeneration,
                                     unresolvedSplitOrMerge: false, strongNewOrConflict: false)
    }
    func scenario(_ name: String, _ segs: [P009CSegmentV1]) -> P009CScenarioV1 {
        P009CScenarioV1(name: name, family: "audit6", segments: segs, annotation: P009CAnnotationV1())
    }
    func seg(_ s: Double, _ e: Double, _ i: ExpertInputV2, risk: Double = 0, topics: Set<String> = []) -> P009CSegmentV1 {
        P009CSegmentV1(startMs: s, endMs: e, input: i, temporalRisk: risk, temporalTopics: topics)
    }
    /// FULL recursive debug serialization — every stored property of the durable payload, at any depth.
    func recursiveDump(_ any: Any, depth: Int = 0) -> String {
        guard depth < 8 else { return String(describing: any) }
        let m = Mirror(reflecting: any)
        if m.children.isEmpty { return String(describing: any) }
        return m.children.map { "\($0.label ?? "_")=\(recursiveDump($0.value, depth: depth + 1))" }
            .joined(separator: ";") + "|\(String(describing: any))"
    }

    // ── 1. F-1: ALTERNATE auditor tokens through EVERY ingress; full serialized DNA must be token-free ──
    func testProbe6_AlternateTokensAllIngress_FullSerializedDNATokenFree() {
        let toks = ["gw7vizKanarya", "gw7ocrMenekse", "gw7spkLeylak", "gw7audSumbul",
                    "gw7symOrkide", "gw7entZambak", "gw7provFulya", "gw7lblNergis"]
        let b = brain()
        struct NestedPlantingExpert: MultimodalExpertV2 {
            let tok1: String, tok2: String
            let domain: ExpertDomainV2 = .music
            let availability: ExpertAvailabilityV2 = .realInProcessLabOnly
            let modelVersion = "audit6-planting-expert"
            let resourceCost: Double = 1
            func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2 {
                ExpertEvidenceV2(domain: .music, labels: ["music:present", "free:\(tok1)"],
                                 features: ["feature-\(tok1)": 0.5],                 // feature-KEY ingress
                                 confidence: 0.6, coverage: 1, uncertainty: 0.4,
                                 itemID: context.itemID, itemProvisional: context.itemProvisional,
                                 provenance: "nested→inner(\(tok2))→leaf",           // NESTED provenance ingress
                                 modelVersion: modelVersion,
                                 calibrationStatus: .heuristicSupportOnly, generation: context.generation)
            }
        }
        b.registry.register(NestedPlantingExpert(tok1: toks[7], tok2: toks[6]))
        let s = scenario("a6-all-ingress", [
            seg(0, 3000, ExpertInputV2(
                ocrText: "learn the science lesson guide \(toks[1]) ⚠ \(toks[4])",   // OCR + symbol ingress
                detectedLanguage: "en",
                visualLabels: ["classroom", toks[0]],                                // visual ingress
                visualConfidence: 0.8,
                soundEvents: ["music", toks[3]],                                     // audio-class ingress
                speechTranscript: "the lesson covers \(toks[2]) today", speechAvailable: true),
                topics: [toks[5]])                                                   // temporal/narrative topic ingress
        ])
        let m = P009CCorpusV1.run(s, brain: b, item: ContentItemID(60001))
        // direct entity / topic / intent attempts with auditor tokens
        let g = EntityGraphV1()
        _ = g.observe(label: toks[5], kind: .object, confidence: 0.95, provenance: toks[6])
        XCTAssertTrue(g.all().allSatisfy { $0.durableAtomID == nil && !$0.canonical.contains(toks[5]) },
                      "unmapped auditor label stays ephemeral; canonical carries no provider text")
        XCTAssertNil(SemanticTaxonomyV1.concept(for: toks[5]))
        XCTAssertNil(SemanticTaxonomyV1.concept(for: "scene:\(toks[5])"))
        XCTAssertNil(DurableEntityVocabularyV1.atom(forProviderLabel: toks[0]))
        let fin = ContentDNAFinalizerV1()
        let (dna, refusal) = fin.finalize(model: m, identity: snap(b, item: 60001, provenance: toks[6]),
                                          currentGeneration: b.currentGeneration, dnaRaw: 61, nowMs: 0)
        XCTAssertNil(refusal, "mapped semantics must still finalize (law is vocabulary, not blacklist)")
        guard let d = dna else { return XCTFail("expected DNA") }
        let dump = recursiveDump(d)
        for t in toks {
            XCTAssertFalse(dump.contains(t), "ingress token '\(t)' must NEVER appear anywhere in serialized DNA")
        }
        XCTAssertTrue(ContentDNAPersistenceAuditorV1.audit(d).isEmpty, "field-by-field audit clean")
        XCTAssertTrue(d.entities.contains("entity:place:classroom"), "mapped atom persists")
        // live-model durable-bound collections are also token-free (ephemeral labels may hold raw text in-memory)
        let liveDurable = (m.primaryTopics + m.secondaryTopics).map { $0.concept }
            + m.entities.compactMap { $0.durableAtomID } + m.narrativeLabels
        XCTAssertFalse(liveDurable.contains { s in toks.contains { s.contains($0) } })
    }

    // ── 2. F-1: contradiction-reason free text can never persist (only outcome enums do) ──
    func testProbe6_ContradictionReasonAndUnknownReasonsNeverPersist() {
        let tok = "gw7reasonAkasya"
        let b = brain()
        let s = scenario("a6-contradiction", [
            seg(0, 4000, ExpertInputV2(ocrText: "relax calm spa day \(tok)", detectedLanguage: "en",
                                       visualLabels: ["spa"], visualConfidence: 0.8, soundEvents: ["siren", "alarm"]),
                risk: 0.75, topics: ["alarm"])])
        let m = P009CCorpusV1.run(s, brain: b, item: ContentItemID(60002))
        XCTAssertGreaterThanOrEqual(m.contradictionResolutions.count, 1)
        let (dna, _) = ContentDNAFinalizerV1().finalize(model: m, identity: snap(b, item: 60002),
                                                        currentGeneration: b.currentGeneration, dnaRaw: 62, nowMs: 0)
        if let d = dna {
            XCTAssertFalse(recursiveDump(d).contains(tok))
            XCTAssertTrue(d.contradictionOutcomes.allSatisfy { $0.hasPrefix("contradiction:") })
            XCTAssertTrue(d.contradictionOutcomes.allSatisfy {
                PersistenceLawValidatorV2.classify($0, field: "contradictionOutcomes") == .allowedDurableCanonical })
        }
        // even if a resolver carried free text in its reason, the DNA path persists ONLY the outcome enum
        let r = ContradictionResolutionV1(outcome: .strongRiskDominant, reason: "free \(tok) text", riskRetained: true,
                                          provenance: tok)
        XCTAssertEqual(PersistenceLawValidatorV2.classify("contradiction:\(r.outcome.rawValue)",
                                                          field: "contradictionOutcomes"), .allowedDurableCanonical)
        XCTAssertEqual(PersistenceLawValidatorV2.classify("contradiction:\(r.reason)", field: "contradictionOutcomes"),
                       .forbiddenRawOrReconstructive)
    }

    // ── 3. unknown FUTURE DNA field fails closed + the schema registry is COMPLETE for the current type ──
    func testProbe6_UnknownFutureFieldFailClosed_SchemaRegistryComplete() {
        XCTAssertEqual(PersistenceLawValidatorV2.classify("harmless", field: "futureSummaryText"), .unknownSchema)
        XCTAssertEqual(PersistenceLawValidatorV2.classify("concept:education", field: "futureSummaryText"), .unknownSchema,
                       "even canonical VALUES fail closed under an unregistered FIELD")
        // completeness: every stored property of FinalContentDNAV1 is registered — a future field would
        // surface as UNKNOWN_SCHEMA in audit() (fail closed), so the registry cannot silently rot.
        let b = brain()
        let s = scenario("a6-schema", [
            seg(0, 3000, ExpertInputV2(ocrText: "learn the science lesson guide", detectedLanguage: "en",
                                       visualLabels: ["classroom"], visualConfidence: 0.8))])
        let m = P009CCorpusV1.run(s, brain: b, item: ContentItemID(60003))
        guard let d = ContentDNAFinalizerV1().finalize(model: m, identity: snap(b, item: 60003),
                                                       currentGeneration: b.currentGeneration,
                                                       dnaRaw: 63, nowMs: 0).dna else { return XCTFail() }
        let registered = ContentDNAPersistenceAuditorV1.stringFields.union(ContentDNAPersistenceAuditorV1.numericOrTypedFields)
        for child in Mirror(reflecting: d).children {
            guard let label = child.label else { continue }
            XCTAssertTrue(registered.contains(label), "unregistered field '\(label)' — auditor would fail closed")
        }
        XCTAssertEqual(Mirror(reflecting: d).children.count,
                       ContentDNAPersistenceAuditorV1.stringFields.count
                        + ContentDNAPersistenceAuditorV1.numericOrTypedFields.count,
                       "registry covers EXACTLY the current schema (no dead registrations hiding gaps)")
        // smuggling raw text under a REGISTERED field is forbidden
        XCTAssertEqual(PersistenceLawValidatorV2.classify("some raw sentence", field: "topics"), .forbiddenRawOrReconstructive)
        XCTAssertEqual(PersistenceLawValidatorV2.classify("gw7smuggle", field: "safetyEvidence"), .forbiddenRawOrReconstructive)
    }

    // ── 4. malformed canonical entity IDs: ONLY exact closed-vocabulary members are lawful ──
    func testProbe6_MalformedCanonicalEntityIDsRejected() {
        let malformed = ["entity:place:forest ",                 // trailing space
                         "ENTITY:PLACE:FOREST",                  // case variant
                         "entity:place:forêt",                   // diacritic cousin
                         "entity:place:fore\u{200B}st",          // zero-width smuggle
                         "entity:place:forest/../spa",           // traversal shape
                         "entity:unmapped:object#1",             // EPHEMERAL canonical must never be durable
                         "entity:object:gw7entZambak",           // auditor token
                         "entity:place:",                        // empty tail
                         "entity:person-present:john"]           // not in vocabulary
        for s in malformed {
            XCTAssertEqual(PersistenceLawValidatorV2.classify(s, field: "entities"), .forbiddenRawOrReconstructive, s)
            XCTAssertFalse(WorldModelPersistenceLawV1.isLawfulDurable(s), s)
        }
        XCTAssertEqual(PersistenceLawValidatorV2.classify("entity:place:forest", field: "entities"), .allowedDurableCanonical)
        // vocabulary lookup is exact — a case-variant provider label maps to NOTHING (stays ephemeral)
        XCTAssertNil(DurableEntityVocabularyV1.atom(forProviderLabel: "Classroom"))
        let g = EntityGraphV1()
        _ = g.observe(label: "entity:place:evil-fake", kind: .object, confidence: 0.9, provenance: "a6")
        let node = g.all().first
        XCTAssertNil(node?.durableAtomID, "canonical-LOOKING provider label is still just an unmapped ephemeral")
        XCTAssertFalse(node?.canonical.contains("evil-fake") ?? true)
    }

    // ── 5. F-2: cross-language collisions the builder did NOT list ──
    func testProbe6_UnlistedCrossLanguageCollisions() {
        func urg(_ t: String, _ l: String?) -> Int { LexiconMatcherV2.hits(t, lexicon: Lexicons.urgency, language: l) }
        func scar(_ t: String, _ l: String?) -> Int { LexiconMatcherV2.hits(t, lexicon: Lexicons.scarcity, language: l) }
        // EN words embedding TR trigger "son" that the builder's matrix does not cover
        for w in ["arson", "prison", "comparison", "jettison", "sonnet", "songs", "sonata", "parson"] {
            XCTAssertEqual(urg("the \(w) case", "en") + scar("the \(w) case", "en"), 0, w)
            XCTAssertEqual(urg("the \(w) case", nil) + scar("the \(w) case", nil), 0, "\(w) with UNKNOWN locale")
        }
        // EN word "son" itself (child) — exact token, but NOT an EN term; and EN never consults TR terms
        XCTAssertEqual(scar("my son plays chess", "en"), 0)
        // EN-internal substring: "only" is a real EN scarcity term; words CONTAINING it must not fire
        for w in ["commonly", "suddenly", "onlyfansy"] {
            XCTAssertEqual(scar("it happens \(w) here", "en"), 0, w)
        }
        XCTAssertGreaterThan(scar("only today", "en"), 0, "the real EN token still fires")
        // TR words that CONTAIN "son" as a prefix — exact-token law: no scarcity hit in TR locale
        XCTAssertEqual(scar("sonbahar geldi sonra sonuç açıklandı", "tr"), 0, "sonbahar/sonra/sonuç are not 'son'")
        XCTAssertGreaterThan(scar("bu son fırsat", "tr"), 0, "the real TR token still fires in TR")
        // tr_TR casing: dotless/dotted I — uppercase TR words lowercase through the tr locale
        XCTAssertGreaterThan(scar("SON ŞANS", "tr"), 0, "TR uppercase SON lowercases to the exact token")
        XCTAssertEqual(scar("SONUÇ BELLİ", "tr"), 0)
        XCTAssertGreaterThan(urg("ŞİMDİ GEL", "tr"), 0, "dotted capital İ lowercases correctly in tr")
        // Unicode normalization: decomposed ş/i sequences still match after NFC
        let decomposedSimdi = "s\u{0327}imdi gel"                 // s + combining cedilla
        XCTAssertGreaterThan(urg(decomposedSimdi, "tr"), 0, "decomposed 'şimdi' matches after NFC")
        // EN words carrying TR tokens as substrings, unknown locale (both consulted, exact tokens only)
        XCTAssertEqual(urg("the hemenway tour simdiq", nil), 0, "hemen/şimdi substrings never fire")
        // code-switched EN trigger inside TR-labeled text: TR locale never consults EN terms
        XCTAssertEqual(urg("toplantı now başlıyor", "tr"), 0)
        XCTAssertEqual(urg("hurry dedi ve gitti", "tr"), 0)
        // punctuation/hashtag/URL boundaries with TR tokens
        XCTAssertEqual(scar("#sonbahar @sonmez takip.et/sonuc", "tr"), 0)
        // phrases: TR "son şans" — contiguous tokens across punctuation, but never reordered/broken
        XCTAssertGreaterThan(LexiconMatcherV2.hits("son, şans!", lexicon: Lexicons.urgency, language: "tr"), 0,
                             "TR phrase 'son şans' (urgency list) matches across punctuation")
        XCTAssertEqual(LexiconMatcherV2.hits("şans asla son değil", lexicon: Lexicons.urgency, language: "tr"), 0,
                       "reordered words never form the 'son şans' phrase")
        XCTAssertEqual(LexiconMatcherV2.hits("son büyük şans", lexicon: Lexicons.urgency, language: "tr"), 0,
                       "'son şans' phrase does NOT match with an intervening token")
        // unsupported locale: no lexical claims at all
        XCTAssertEqual(urg("şimdi hemen now hurry", "de"), 0, "unsupported locale → zero lexical claims")
        // end-to-end: EN educational text with my own trap words must carry NO urgency/manipulation topic
        let b = brain()
        let m = P009CCorpusV1.run(scenario("a6-unlisted-collisions", [
            seg(0, 3000, ExpertInputV2(ocrText: "a comparison of prison reform seasons this season",
                                       detectedLanguage: "en"))]), brain: b, item: ContentItemID(60004))
        let topics = Set((m.primaryTopics + m.secondaryTopics).map { $0.concept })
        XCTAssertFalse(topics.contains("concept:urgency"), "\(topics)")
        XCTAssertFalse(topics.contains("concept:manipulation-language"), "\(topics)")
    }

    // ── 6. F-5: cache purity — foreign/stale/mixed-revision/split/provenance variants ──
    func testProbe6_CachePurityForeignStaleSplitVariants() {
        let b = brain()
        let good = P009CCorpusV1.run(scenario("a6-pure", [
            seg(0, 3000, ExpertInputV2(ocrText: "learn the science lesson guide", detectedLanguage: "en",
                                       visualLabels: ["classroom"], visualConfidence: 0.8))]),
            brain: b, item: ContentItemID(60100))
        XCTAssertTrue(WorldModelEvidencePurityGateV1.violations(good).isEmpty)
        let cache = WorldModelCacheV1()
        cache.insert(good, nowMs: 0)
        XCTAssertNotNil(cache.lookup(item: ContentItemID(60100), identityRevision: 0,
                                     generation: b.currentGeneration, nowMs: 1).0)
        // (a) FOREIGN-ITEM evidence: model claims 60200, evidence stamped 60100 → write-rejected
        let ctx = ExpertTaskContextV2(observationID: ObservationID(9), shotID: ShotID(9), itemID: ContentItemID(60100),
                                      itemProvisional: false, profile: .appFullTier1,
                                      requestedDomains: ExpertDomainV2.allCases, generation: b.currentGeneration,
                                      cacheEligible: false)
        let route = b.route(input: ExpertInputV2(ocrText: "learn the science lesson guide", detectedLanguage: "en",
                                                 visualLabels: ["classroom"], visualConfidence: 0.8),
                            context: ctx, nowMs: 0)
        let obs = [EpisodeObservationV1(startMs: 0, endMs: 3000, shotIDs: [ShotID(9)], evidence: route.evidence,
                                        unknownReasons: route.unknownReasons, sourceText: nil)]
        let foreign = WorldModelBuilderV1().build(observations: obs, itemID: ContentItemID(60200),
                                                  itemProvisional: false, identityRevision: 0,
                                                  generation: b.currentGeneration, nowMs: 3000)
        XCTAssertTrue(WorldModelEvidencePurityGateV1.violations(foreign).contains(.foreignItemEvidence))
        let before = cache.purityRejections
        cache.insert(foreign, nowMs: 0)
        XCTAssertGreaterThan(cache.purityRejections, before, "foreign evidence rejected ON WRITE, counted")
        XCTAssertNil(cache.lookup(item: ContentItemID(60200), identityRevision: 0,
                                  generation: b.currentGeneration, nowMs: 1).0)
        // (b) STALE GENERATION: a pure entry is NEVER served for a different generation
        let (stale, staleReason) = cache.lookup(item: ContentItemID(60100), identityRevision: 0,
                                                generation: b.currentGeneration + 1, nowMs: 1)
        XCTAssertNil(stale); XCTAssertEqual(staleReason, "generation-mismatch")
        // (c) MIXED REVISION: revision bump evicts, not just misses
        let (rev, revReason) = cache.lookup(item: ContentItemID(60100), identityRevision: 5,
                                            generation: b.currentGeneration, nowMs: 1)
        XCTAssertNil(rev); XCTAssertEqual(revReason, "revision-mismatch")
        XCTAssertNil(cache.lookup(item: ContentItemID(60100), identityRevision: 0,
                                  generation: b.currentGeneration, nowMs: 1).0, "evicted — not resurrectable")
        // (d) SPLIT / collision: strong collision purges; ambiguous forces reanalysis exactly once
        cache.insert(good, nowMs: 2)
        cache.reportIdentityCollision(item: ContentItemID(60100), strength: .strong)
        XCTAssertNil(cache.lookup(item: ContentItemID(60100), identityRevision: 0,
                                  generation: b.currentGeneration, nowMs: 3).0)
        cache.insert(good, nowMs: 4)
        cache.reportIdentityCollision(item: ContentItemID(60100), strength: .ambiguous)
        let (amb, ambReason) = cache.lookup(item: ContentItemID(60100), identityRevision: 0,
                                            generation: b.currentGeneration, nowMs: 5)
        XCTAssertNil(amb); XCTAssertEqual(ambReason, "collision-reanalysis")
        // (e) PROVENANCE-SCOPE mismatch is expressed through evidence item/generation sets (the gate's
        // law); a model with foreign-generation evidence is rejected by the same gate
        XCTAssertTrue(WorldModelEvidencePurityGateV1.violations(foreign).count >= 1)
        // (f) provisional evidence rejected on write
        let prov = P009CCorpusV1.run(scenario("a6-prov", [
            seg(0, 3000, ExpertInputV2(ocrText: "learn the science lesson guide", detectedLanguage: "en"))]),
            brain: brain(), item: ContentItemID(60300), provisional: true)
        let before2 = cache.purityRejections
        cache.insert(prov, nowMs: 0)
        XCTAssertNil(cache.lookup(item: ContentItemID(60300), identityRevision: 0, generation: 1, nowMs: 1).0)
        XCTAssertGreaterThanOrEqual(cache.purityRejections, before2)
    }

    // ── 7. uncertainty monotonicity under AUDITOR perturbations (incl. high-confidence OOD) ──
    func mkEv(_ d: ExpertDomainV2, conf: Double, ood: Bool = false, gen: UInt64 = 1) -> ExpertEvidenceV2 {
        ExpertEvidenceV2(domain: d, labels: ["benefit:educational-candidate"], confidence: conf, coverage: 1,
                         uncertainty: 1 - conf, oodIndicator: ood, itemID: ContentItemID(1), itemProvisional: false,
                         provenance: "a6", modelVersion: "m-v1", calibrationStatus: .implementedUncalibrated,
                         generation: gen)
    }
    func testProbe6_UncertaintyMonotonicity_AuditorPerturbations() {
        // (a) conflict count strictly monotone
        let c0 = SemanticUncertaintyModelV1.assess(evidence: [mkEv(.languageOCR, conf: 0.8)], unknownReasons: [],
                                                   itemProvisional: false, contradictions: 0, topicCount: 1)
        let c3 = SemanticUncertaintyModelV1.assess(evidence: [mkEv(.languageOCR, conf: 0.8)], unknownReasons: [],
                                                   itemProvisional: false, contradictions: 3, topicCount: 1)
        XCTAssertGreaterThanOrEqual(c3.overall, c0.overall - 1e-9)
        // (b) identity ambiguity monotone
        let idp = SemanticUncertaintyModelV1.assess(evidence: [mkEv(.languageOCR, conf: 0.8)], unknownReasons: [],
                                                    itemProvisional: true, contradictions: 0, topicCount: 1)
        XCTAssertGreaterThanOrEqual(idp.overall, c0.overall - 1e-9)
        // (c) OOD can never manufacture trusted coverage or a KNOWN/LIKELY state
        let onlyOOD = SemanticUncertaintyModelV1.assess(evidence: [mkEv(.vision, conf: 1.0, ood: true)],
                                                        unknownReasons: [], itemProvisional: false,
                                                        contradictions: 0, topicCount: 0)
        XCTAssertEqual(onlyOOD.missingModality, 1, "OOD-only evidence = ZERO trusted coverage")
        XCTAssertGreaterThanOrEqual(onlyOOD.overall, 0.5, "OOD floor pins overall ≥ 0.5 (state ≤ AMBIGUOUS)")
        // (d) AUDIT6 FINDING R1-A (documented current behavior): a HIGH-CONFIDENCE OOD record still feeds
        // the epistemic strength through its 0.4-discounted weight, so adding an OOD record CAN reduce
        // `overall` (0.84 → 0.70 below) and flip the knowledge state UNKNOWN → AMBIGUOUS. The builder's
        // monotonicity test only sampled a LOW-confidence OOD record (conf 0.1), which cannot reach the
        // weight threshold. Bounded: the OOD floor (0.5) makes KNOWN/LIKELY unreachable, so the certainty
        // gain is capped at AMBIGUOUS. Asserting CURRENT behavior; reported in the re-audit report.
        let weakBase = SemanticUncertaintyModelV1.assess(
            evidence: [mkEv(.languageOCR, conf: 0.2), mkEv(.speech, conf: 0.2), mkEv(.safetyEvidence, conf: 0.2)],
            unknownReasons: [], itemProvisional: false, contradictions: 0, topicCount: 1)
        let weakPlusStrongOOD = SemanticUncertaintyModelV1.assess(
            evidence: [mkEv(.languageOCR, conf: 0.2), mkEv(.speech, conf: 0.2), mkEv(.safetyEvidence, conf: 0.2),
                       mkEv(.vision, conf: 1.0, ood: true)],
            unknownReasons: [], itemProvisional: false, contradictions: 0, topicCount: 1)
        let sBase = SemanticUncertaintyModelV1.state(strength: 0.16, uncertainty: weakBase,
                                                     conflicting: false, anyEvidence: true)
        let sOOD = SemanticUncertaintyModelV1.state(strength: 0.32, uncertainty: weakPlusStrongOOD,
                                                    conflicting: false, anyEvidence: true)
        XCTAssertLessThan(weakPlusStrongOOD.overall, weakBase.overall,
                          "FINDING R1-A: high-confidence OOD record REDUCES overall "
                          + "(\(weakBase.overall) → \(weakPlusStrongOOD.overall))")
        XCTAssertEqual(sBase, .unknown)
        XCTAssertEqual(sOOD, .ambiguous, "FINDING R1-A: OOD addition flips UNKNOWN → AMBIGUOUS")
        XCTAssertNotEqual(sOOD, .known); XCTAssertNotEqual(sOOD, .likely)
        // (e) adding an honest UNAVAILABLE modality record never reduces overall
        let withUnavail = SemanticUncertaintyModelV1.assess(
            evidence: [mkEv(.languageOCR, conf: 0.8), .unavailable(.speech, reason: "a6", generation: 1)],
            unknownReasons: [], itemProvisional: false, contradictions: 0, topicCount: 1)
        XCTAssertGreaterThanOrEqual(withUnavail.overall, c0.overall - 1e-9)
    }

    // ── 8. capability / source-mode truth: no inflation anywhere ──
    func testProbe6_NoCapabilityOrSourceModeInflation() {
        let b = brain()
        for d in ExpertDomainV2.allCases {
            XCTAssertEqual(b.registry.availability(d), .realInProcessLabOnly,
                           "\(d) must stay REAL_IN_PROCESS_LAB_ONLY (no device proof exists)")
        }
        XCTAssertFalse(b.calibration.scoreDisplayAllowed(), "score display stays OFF")
        // evidence produced by every arm self-declares ≤ lab-only truth via calibration status
        let ctx = ExpertTaskContextV2(observationID: ObservationID(1), shotID: ShotID(1), itemID: ContentItemID(60400),
                                      itemProvisional: false, profile: .appFullTier1,
                                      requestedDomains: ExpertDomainV2.allCases, generation: b.currentGeneration,
                                      cacheEligible: false)
        let route = b.route(input: ExpertInputV2(ocrText: "learn the science lesson guide", detectedLanguage: "en",
                                                 visualLabels: ["classroom"], visualConfidence: 0.8),
                            context: ctx, nowMs: 0)
        XCTAssertTrue(route.evidence.allSatisfy { $0.calibrationStatus != .implementedCalibrated },
                      "no arm may claim CALIBRATED in P009C (score OFF)")
    }

    // ── 9. CAL_RESERVED untouched + leakage V2 posture ──
    func testProbe6_CALReservedFingerprintAndLeakageV2() {
        XCTAssertEqual(CorpusSplitLeakageAuditorV1.reservedBankFingerprint(), "aa6bd546ae28278f",
                       "CAL_RESERVED content-locked, consumed as fingerprint metadata only")
        XCTAssertTrue(P009CLeakageAuditorV2.audit().isEmpty, "V1+V2 leakage rules clean on current banks")
        // honesty note (verified): NO current scenario sets templateID — the translation-equivalent law
        // is authoring metadata and currently fires on nothing (declared in the leakage doc, not hidden)
        for split in P009CSplitV1.allCases {
            XCTAssertTrue(P009CCorpusV1.scenarios(split).allSatisfy { $0.templateID == nil })
        }
        // detector sanity on AUDITOR-built scenarios (never corpus mutation)
        let segA = seg(0, 3000, ExpertInputV2(ocrText: "learn the quick science lesson guide today",
                                              detectedLanguage: "en"))
        var a = scenario("a6-tmpl-a", [segA]); a.templateID = "a6-shared"
        var bScn = scenario("a6-tmpl-b", [seg(0, 3000, ExpertInputV2(
            ocrText: "bugün hızlı bilim dersi rehberini öğren", detectedLanguage: "tr"))])
        bScn.templateID = "a6-shared"
        XCTAssertEqual(a.templateID, bScn.templateID, "translated twins share the authored templateID")
        XCTAssertEqual(P009CLeakageAuditorV2.templateFingerprint(a), P009CLeakageAuditorV2.templateFingerprint(bScn),
                       "same family+modality shape → same template fingerprint")
        XCTAssertEqual(P009CLeakageAuditorV2.jaccard(P009CLeakageAuditorV2.shingles(a),
                                                     P009CLeakageAuditorV2.shingles(a)), 1)
        // near-template: two EN variants of one template exceed the 0.5 shingle threshold
        let a2 = scenario("a6-tmpl-a2", [seg(0, 3000, ExpertInputV2(
            ocrText: "learn the quick science lesson guide now", detectedLanguage: "en"))])
        XCTAssertGreaterThan(P009CLeakageAuditorV2.jaccard(P009CLeakageAuditorV2.shingles(a),
                                                           P009CLeakageAuditorV2.shingles(a2)), 0.5,
                             "token 3-shingles catch near-template rewrites")
    }

    // ── 10. end-to-end spot regression: world model remains REAL (not annotation echo) ──
    func testProbe6_WorldModelStillRealEndToEnd() {
        let b = brain()
        let m = P009CCorpusV1.run(scenario("a6-real", [
            seg(0, 2000, ExpertInputV2(ocrText: "deadly crash reported near the hospital", detectedLanguage: "en")),
            seg(2000, 4000, ExpertInputV2(ocrText: "huzurlu göl kenarında sakin akşam", detectedLanguage: "tr",
                                          visualLabels: ["lake"], visualConfidence: 0.85))]),
            brain: b, item: ContentItemID(60500))
        let topics = Set((m.primaryTopics + m.secondaryTopics).map { $0.concept })
        XCTAssertTrue(topics.contains("concept:mortality"), "\(topics)")
        XCTAssertTrue(topics.contains("concept:calm-nature"), "\(topics)")
        XCTAssertGreaterThanOrEqual(m.episodes.count, 2)
        XCTAssertTrue(m.entities.contains { $0.durableAtomID == "entity:place:lake" })
        XCTAssertGreaterThan(m.provenance.count, 0)
        XCTAssertTrue(m.uncertainty.overall > 0, "approximate truth is never exact")
    }
}
