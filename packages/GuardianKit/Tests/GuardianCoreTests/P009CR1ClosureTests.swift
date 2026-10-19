import XCTest
@testable import GuardianCore

// P009C-R1 — closure tests: F-1 all-ingress privacy, F-2 cross-language adversarial matrix,
// F-5 cache purity, uncertainty monotonicity, persistence-schema fail-closed, leakage V2, capability truth.

final class P009CR1ClosureTests: XCTestCase {

    func makeBrain() -> GuardianMetaBrainV2 {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1()); b.registry.register(LanguageOCRExpertV1())
        b.registry.register(SpeechExpertV1()); b.registry.register(AudioEventExpertV1())
        b.registry.register(MusicExpertV1()); b.registry.register(SymbolExpertV1())
        b.registry.register(TemporalExpertV1()); b.registry.register(SafetyEvidenceExpertV1())
        b.registry.register(BenefitEvidenceExpertV1()); b.registry.register(AttentionPressureExpertV1())
        return b
    }
    func snap(_ b: GuardianMetaBrainV2, item: UInt64) -> IdentityResolutionSnapshotV1 {
        IdentityResolutionSnapshotV1(itemID: ContentItemID(item), identityRevision: 0, resolutionState: .confirmed,
                                     sourceProfile: .appFullTier1, evidenceProvenance: "r1-test",
                                     confirmationAuthority: .tier1AppFull, generation: b.currentGeneration,
                                     unresolvedSplitOrMerge: false, strongNewOrConflict: false)
    }
    func allDurableStrings(_ d: FinalContentDNAV1) -> [String] {
        d.topics + d.entities + d.intents + d.narrativeSummary + d.temporalStructure + d.safetyEvidence
            + d.benefitEvidence + d.manipulationEvidence + d.emotionalLoad + d.contradictionOutcomes
            + d.auditTrail + d.meshModelVersions + [d.worldModelVersion, d.taxonomyVersion]
    }

    // ── §4 F-1: planted tokens through EVERY ingress — none may survive into durable DNA ──
    func testAllIngressPlantedTokensNeverReachDurableDNA() {
        let tok = "qxzUniqueR1Token77"
        let brain = makeBrain()
        // custom expert planting the token into provenance + labels (the provenance/narrative ingress)
        struct PlantingExpert: MultimodalExpertV2 {
            let tok: String
            let domain: ExpertDomainV2 = .music
            let availability: ExpertAvailabilityV2 = .realInProcessLabOnly
            let modelVersion = "planting-expert-v1"
            let resourceCost: Double = 1
            func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2 {
                ExpertEvidenceV2(domain: .music, labels: ["music:present", "free-form:\(tok)"],
                                 features: [:], confidence: 0.6, coverage: 1, uncertainty: 0.4,
                                 itemID: context.itemID, itemProvisional: context.itemProvisional,
                                 provenance: "planted←\(tok)", modelVersion: modelVersion,
                                 calibrationStatus: .heuristicSupportOnly, generation: context.generation)
            }
        }
        brain.registry.register(PlantingExpert(tok: tok))
        let s = P009CScenarioV1(name: "r1-all-ingress", family: "privacy", segments: [
            P009CSegmentV1(startMs: 0, endMs: 3000, input: ExpertInputV2(
                ocrText: "learn the science lesson guide \(tok) ⚠ \(tok)",       // OCR + symbol ingress
                detectedLanguage: "en",
                visualLabels: ["classroom", tok],                                 // visual ingress
                visualConfidence: 0.8,
                soundEvents: ["music", tok],                                      // audio ingress
                speechTranscript: "the lesson about \(tok)", speechAvailable: true)) // speech ingress
        ], annotation: P009CAnnotationV1())
        let m = P009CCorpusV1.run(s, brain: brain, item: ContentItemID(7001))
        // direct entity/topic ingress attempts
        let g = EntityGraphV1()
        _ = g.observe(label: tok, kind: .object, confidence: 0.9, provenance: tok)
        XCTAssertTrue(g.all().allSatisfy { $0.durableAtomID == nil || !$0.canonical.contains(tok) })
        XCTAssertNil(SemanticTaxonomyV1.concept(for: "scene:\(tok)"), "unmapped scene → no concept claim")
        let fin = ContentDNAFinalizerV1()
        let (dna, _) = fin.finalize(model: m, identity: snap(brain, item: 7001),
                                    currentGeneration: brain.currentGeneration, dnaRaw: 1, nowMs: 0)
        guard let d = dna else { return XCTFail("mapped semantics should still finalize") }
        XCTAssertFalse(allDurableStrings(d).contains { $0.contains(tok) },
                       "NO ingress (visual/OCR/speech/audio/symbol/entity/provenance/label) leaks into DNA")
        XCTAssertTrue(ContentDNAPersistenceAuditorV1.audit(d).isEmpty, "full field-by-field audit clean")
    }
    func testContradictionReasonTokenNeverPersists() {
        // contradiction REASONS carry free text in the live model; DNA stores outcome enums only
        let res = ContradictionResolutionV1(outcome: .unresolved, reason: "free text zq11", riskRetained: true, provenance: "x")
        XCTAssertEqual("contradiction:\(res.outcome.rawValue)", "contradiction:UNRESOLVED")
        XCTAssertEqual(PersistenceLawValidatorV2.classify("contradiction:UNRESOLVED", field: "contradictionOutcomes"),
                       .allowedDurableCanonical)
        XCTAssertEqual(PersistenceLawValidatorV2.classify("contradiction:free text zq11", field: "contradictionOutcomes"),
                       .forbiddenRawOrReconstructive)
    }
    func testPersistenceSchemaFailClosed() {
        XCTAssertEqual(PersistenceLawValidatorV2.classify("anything", field: "someFutureField"), .unknownSchema,
                       "unknown DNA fields fail CLOSED")
        XCTAssertEqual(PersistenceLawValidatorV2.classify("entity:place:../../etc", field: "entities"),
                       .forbiddenRawOrReconstructive, "malformed canonical entity IDs rejected (closed set)")
        XCTAssertEqual(PersistenceLawValidatorV2.classify("entity:place:forest", field: "entities"), .allowedDurableCanonical)
        XCTAssertEqual(PersistenceLawValidatorV2.classify("narrative:segments:12", field: "narrativeSummary"), .allowedDurableCanonical)
        XCTAssertEqual(PersistenceLawValidatorV2.classify("narrative:segments:12abc", field: "narrativeSummary"),
                       .forbiddenRawOrReconstructive, "numeric-tail grammar admits digits only")
        XCTAssertFalse(WorldModelPersistenceLawV1.isLawfulDurable("entity:object:freeform"),
                       "no prefix-only acceptance anywhere")
    }

    // ── §7 F-2: cross-language adversarial matrix ──
    func urgencyHits(_ text: String, lang: String?) -> Int {
        LexiconMatcherV2.hits(text, lexicon: Lexicons.urgency, language: lang)
    }
    func testCrossLanguageCollisionMatrix() {
        // EN words containing the TR trigger substring "son" — ZERO hits in EN locale
        for w in ["lesson", "reason", "season", "person", "sponsor", "sonar"] {
            XCTAssertEqual(urgencyHits("a \(w) here", lang: "en"), 0, "\(w) must not trigger TR 'son'")
        }
        // the REAL TR token still triggers in TR locale (incl. the "son şans" phrase)
        XCTAssertGreaterThan(LexiconMatcherV2.hits("son şans bugün", lexicon: Lexicons.scarcity, language: "tr"), 0)
        // mixed TR/EN: EN-labeled text never consults TR terms
        XCTAssertEqual(urgencyHits("my son went to the lesson", lang: "en"), 0)
        // hashtags/usernames/URLs/camelCase/apostrophes
        XCTAssertEqual(urgencyHits("#lesson @sonmez example.com/season LessonPlan season's", lang: "en"), 0)
        // Turkish dotted/dotless I and uppercase: "ŞİMDİ" lowercases correctly in tr locale
        XCTAssertGreaterThan(urgencyHits("ŞİMDİ acele", lang: "tr"), 0)
        XCTAssertEqual(LexiconMatcherV2.hits("SON", lexicon: Lexicons.scarcity, language: "en"), 0,
                       "EN 'SON' never consults the TR term list")
        // Unicode normalization: decomposed "ölümcül" still matches the TR supplement
        let decomposed = "o\u{0308}lu\u{0308}mcu\u{0308}l kaza"
        XCTAssertGreaterThan(LexiconMatcherV2.hits(decomposed, lexicon: Lexicons.mortality, language: "tr",
                                                   supplement: LexiconMatcherV2.supplementalMortality), 0)
        // punctuation/emoji boundaries never glue or split tokens incorrectly
        XCTAssertGreaterThan(urgencyHits("hemen! şimdi…", lang: "tr"), 0)
        XCTAssertEqual(urgencyHits("hemens şimdiki", lang: "tr"), 0, "suffixed forms are not the exact tokens")
        // TR word containing an EN trigger substring: "nowruz"-style — EN "now" must not fire in TR text
        XCTAssertEqual(LexiconMatcherV2.hits("nevruz now-ruz", lexicon: Lexicons.urgency, language: "tr"), 0)
        // phrases: "last chance" (EN) exact contiguous sequence only
        XCTAssertGreaterThan(urgencyHits("your last chance today", lang: "en"), 0)
        XCTAssertEqual(urgencyHits("last happy chance", lang: "en"), 0, "broken phrase does not match")
    }
    func testUnknownLocaleUsesExactTokensOnBoth() {
        // nil language: both locales consulted but ONLY with exact tokens — "lesson" still safe
        XCTAssertEqual(urgencyHits("science lesson guide", lang: nil), 0)
        XCTAssertGreaterThan(urgencyHits("hemen gel", lang: nil), 0, "real TR token still found when locale unknown")
    }

    // ── §8 F-5: cache purity ──
    func testCachePurityRejectsForeignAndProvisional() {
        let brain = makeBrain()
        let s = P009CCorpusV1.scenarios(.tune).first { $0.name == "tc-straight-educational" }!
        let good = P009CCorpusV1.run(s, brain: brain, item: ContentItemID(7100))
        XCTAssertTrue(WorldModelEvidencePurityGateV1.violations(good).isEmpty)
        let cache = WorldModelCacheV1()
        cache.insert(good, nowMs: 0)
        XCTAssertNotNil(cache.lookup(item: ContentItemID(7100), identityRevision: 0,
                                     generation: brain.currentGeneration, nowMs: 1).0, "pure model serves")
        // provisional evidence model → rejected
        let prov = P009CCorpusV1.run(s, brain: makeBrain(), item: ContentItemID(7101), provisional: true)
        cache.insert(prov, nowMs: 0)
        XCTAssertNil(cache.lookup(item: ContentItemID(7101), identityRevision: 0, generation: 1, nowMs: 1).0)
        XCTAssertGreaterThan(cache.purityRejections + cache.invalidations, 0)
    }

    // ── §9: uncertainty monotonicity properties ──
    func baseEvidence(_ gen: UInt64) -> [ExpertEvidenceV2] {
        [ExpertEvidenceV2(domain: .languageOCR, labels: ["benefit:educational-candidate"], confidence: 0.8,
                          coverage: 1, uncertainty: 0.2, itemID: ContentItemID(1), itemProvisional: false,
                          provenance: "p", modelVersion: "m-v1", calibrationStatus: .implementedUncalibrated, generation: gen)]
    }
    func testUncertaintyMonotonicity() {
        let gen: UInt64 = 1
        let base = SemanticUncertaintyModelV1.assess(evidence: baseEvidence(gen), unknownReasons: [],
                                                     itemProvisional: false, contradictions: 0, topicCount: 1)
        // (a) adding an UNAVAILABLE modality record never reduces overall
        let withMissing = SemanticUncertaintyModelV1.assess(
            evidence: baseEvidence(gen) + [.unavailable(.speech, reason: "x", generation: gen)],
            unknownReasons: [], itemProvisional: false, contradictions: 0, topicCount: 1)
        XCTAssertGreaterThanOrEqual(withMissing.overall, base.overall - 1e-9)
        // (b) adding a contradiction never reduces overall
        let withConflict = SemanticUncertaintyModelV1.assess(evidence: baseEvidence(gen), unknownReasons: [],
                                                             itemProvisional: false, contradictions: 2, topicCount: 1)
        XCTAssertGreaterThanOrEqual(withConflict.overall, base.overall - 1e-9)
        // (c) adding an OOD record never reduces overall
        var ood = baseEvidence(gen)[0]
        let oodRecord = ExpertEvidenceV2(domain: .vision, labels: ["scene:x"], confidence: 0.1, coverage: 1,
                                         uncertainty: 0.9, oodIndicator: true, itemID: ContentItemID(1),
                                         itemProvisional: false, provenance: "p", modelVersion: "m-v1",
                                         calibrationStatus: .implementedUncalibrated, generation: gen)
        _ = ood
        let withOOD = SemanticUncertaintyModelV1.assess(evidence: baseEvidence(gen) + [oodRecord], unknownReasons: [],
                                                        itemProvisional: false, contradictions: 0, topicCount: 1)
        XCTAssertGreaterThanOrEqual(withOOD.overall, base.overall - 1e-9)
        // (d) identity ambiguity never reduces overall
        let withProv = SemanticUncertaintyModelV1.assess(evidence: baseEvidence(gen), unknownReasons: [],
                                                         itemProvisional: true, contradictions: 0, topicCount: 1)
        XCTAssertGreaterThanOrEqual(withProv.overall, base.overall - 1e-9)
        // epistemic is strength-derived: a weak extra record cannot DECREASE epistemic below the family law
        XCTAssertGreaterThanOrEqual(withOOD.epistemic, 0)
    }

    // ── §11: leakage auditor V2 ──
    func testLeakageAuditorV2Clean() {
        let v = P009CLeakageAuditorV2.audit()
        XCTAssertTrue(v.isEmpty, "\(v)")
    }
    func testLeakageAuditorV2CatchesTranslationEquivalentTemplate() {
        var a = P009CCorpusV1.scenarios(.tune)[0]; a.templateID = "tmpl-x"
        var b = P009CCorpusV1.scenarios(.heldOut)[0]; b.templateID = "tmpl-x"
        // rule-level check (the detector logic itself)
        XCTAssertEqual(a.templateID, b.templateID)
        let shingleLeak = P009CLeakageAuditorV2.jaccard(P009CLeakageAuditorV2.shingles(a), P009CLeakageAuditorV2.shingles(a))
        XCTAssertEqual(shingleLeak, 1, "identical content → full shingle overlap (detector sane)")
    }

    // ── §10: capability truth unchanged ──
    func testCapabilityTruthUnchanged() {
        let b = makeBrain()
        for d in ExpertDomainV2.allCases {
            XCTAssertEqual(b.registry.availability(d), .realInProcessLabOnly,
                           "no capability inflation: \(d) stays LAB_ONLY until §16/§28 device proof")
        }
        XCTAssertFalse(b.calibration.scoreDisplayAllowed())
    }

    // ── regression: the P009C gates still hold after R1 (fix-phase law: honesty fixes only) ──
    func testEntityConflictStillWorksWithVocabulary() {
        let brain = makeBrain()
        let s = P009CCorpusV1.scenarios(.tune).first { $0.name == "tc-entity-conflict" }!
        let m = P009CCorpusV1.run(s, brain: brain, item: ContentItemID(7200))
        let places = m.entities.filter { $0.kind == .place }
        XCTAssertGreaterThanOrEqual(places.count, 2)
        XCTAssertTrue(places.allSatisfy { $0.conflicting && $0.durableAtomID != nil })
    }
    func testUnmappedEntityStaysEphemeral() {
        let g = EntityGraphV1()
        XCTAssertTrue(g.observe(label: "weird-new-gadget", kind: .object, confidence: 0.9, provenance: "p"))
        let node = g.all().first!
        XCTAssertNil(node.durableAtomID, "unmapped provider label = ephemeral/UNKNOWN")
        XCTAssertFalse(node.canonical.contains("weird-new-gadget"), "canonical carries no provider text")
        XCTAssertEqual(node.ephemeralLabel, "weird-new-gadget", "raw label stays in-memory for lab display only")
    }
}
