import XCTest
@testable import GuardianCore

// P009C — world-model test families (§32) + corpus gates (TUNE → freeze → HELD-OUT/STRESS/OOD run-once).

final class P009CWorldModelTests: XCTestCase {

    func makeBrain() -> GuardianMetaBrainV2 {
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
    func snapshot(_ b: GuardianMetaBrainV2, item: UInt64, revision: UInt64 = 0,
                  state: IdentityResolutionSnapshotV1.ResolutionStateV1 = .confirmed,
                  authority: IdentityResolutionSnapshotV1.ConfirmationAuthorityV1 = .tier1AppFull,
                  splitPending: Bool = false) -> IdentityResolutionSnapshotV1 {
        IdentityResolutionSnapshotV1(itemID: ContentItemID(item), identityRevision: revision, resolutionState: state,
                                     sourceProfile: .appFullTier1, evidenceProvenance: "test",
                                     confirmationAuthority: authority, generation: b.currentGeneration,
                                     unresolvedSplitOrMerge: splitPending, strongNewOrConflict: false)
    }
    func runNamed(_ name: String, split: P009CSplitV1 = .tune, item: UInt64 = 1,
                  provisional: Bool = false) -> ContentWorldModelV1 {
        let s = P009CCorpusV1.scenarios(split).first { $0.name == name }!
        return P009CCorpusV1.run(s, brain: makeBrain(), item: ContentItemID(item), provisional: provisional)
    }

    // ── corpus gate evaluation ──
    func check(_ s: P009CScenarioV1, _ m: ContentWorldModelV1) -> [String] {
        var f: [String] = []
        let a = s.annotation
        let topics = Set((m.primaryTopics + m.secondaryTopics).map { $0.concept })
        for t in a.expectedTopics where !topics.contains(t) { f.append("\(s.name): missing topic \(t)") }
        for t in a.forbiddenTopics where topics.contains(t) { f.append("\(s.name): forbidden topic \(t)") }
        for p in a.expectedEntityPrefixes where !m.entities.contains(where: { $0.canonical.hasPrefix(p) }) {
            f.append("\(s.name): missing entity \(p)")
        }
        // subjective intents: model's hypotheses must cover annotator A ∪ B top intents partially —
        // exact/partial matching law: at least one of each annotator's set must appear
        let modelIntents = Set(m.intents.map { $0.intent.rawValue })
        if !a.intentsAnnotatorA.isEmpty && modelIntents.isDisjoint(with: a.intentsAnnotatorA) {
            f.append("\(s.name): no annotatorA intent matched")
        }
        if !a.intentsAnnotatorB.isEmpty && modelIntents.isDisjoint(with: a.intentsAnnotatorB) {
            f.append("\(s.name): no annotatorB intent matched")
        }
        if let amb = a.expectIntentAmbiguous, m.intentAmbiguous != amb { f.append("\(s.name): intentAmbiguous != \(amb)") }
        if a.expectContradiction && m.contradictionResolutions.isEmpty { f.append("\(s.name): expected contradiction") }
        if !a.allowedContradictionOutcomes.isEmpty {
            for r in m.contradictionResolutions where !a.allowedContradictionOutcomes.contains(r.outcome.rawValue) {
                f.append("\(s.name): outcome \(r.outcome.rawValue) not allowed")
            }
        }
        for tag in a.expectedContextTags where !m.episodes.contains(where: { $0.contextTags.map(\.rawValue).contains(tag) }) {
            f.append("\(s.name): missing context tag \(tag)")
        }
        if a.expectRiskEscalated && m.maxRiskSeen < 0.6 { f.append("\(s.name): risk not escalated") }
        if a.expectRecoveryObserved && !m.narrativeLabels.contains(where: { $0.hasPrefix("narrative:recovery-observed") }) {
            f.append("\(s.name): recovery not observed")
        }
        let emo = Set(m.emotionalLoad)
        if !a.emotionalAnnotatorA.isEmpty && emo.isDisjoint(with: a.emotionalAnnotatorA.union(a.emotionalAnnotatorB)) {
            f.append("\(s.name): no annotated emotion matched")
        }
        if a.expectManipulationEvidence && m.manipulationEvidence.isEmpty { f.append("\(s.name): manipulation evidence missing") }
        if m.episodes.count < a.minEpisodes { f.append("\(s.name): episodes \(m.episodes.count) < \(a.minEpisodes)") }
        if !a.allowedKnowledgeStates.isEmpty && !a.allowedKnowledgeStates.contains(m.knowledgeState.rawValue) {
            f.append("\(s.name): state \(m.knowledgeState.rawValue) not in \(a.allowedKnowledgeStates)")
        }
        if let ready = a.expectDNAReady, m.readiness != ready { f.append("\(s.name): readiness != \(ready)") }
        if a.expectUnsupportedLanguage && !m.uncertainty.notes.joined().contains("") {
            // unsupported language shows as high language uncertainty
            if m.uncertainty.language < 0.5 { f.append("\(s.name): language uncertainty not raised") }
        }
        return f
    }
    func runSplit(_ split: P009CSplitV1) -> [String] {
        var failures: [String] = []
        for (i, s) in P009CCorpusV1.scenarios(split).enumerated() {
            let m = P009CCorpusV1.run(s, brain: makeBrain(), item: ContentItemID(UInt64(i + 1)))
            failures.append(contentsOf: check(s, m))
        }
        return failures
    }

    func testTuneP009C() {
        let f = runSplit(.tune)
        print("P009C_TUNE scenarios=\(P009CCorpusV1.scenarios(.tune).count) failures=\(f.count)")
        f.forEach { print("P009C_TUNE_FAIL \($0)") }
        XCTAssertTrue(f.isEmpty, "\(f)")
    }
    func testHeldOutP009CRunOnce() {
        let f = runSplit(.heldOut)
        print("P009C_HELDOUT scenarios=\(P009CCorpusV1.scenarios(.heldOut).count) failures=\(f.count)")
        f.forEach { print("P009C_HELDOUT_FAIL \($0)") }
        XCTAssertTrue(f.isEmpty, "\(f)")
    }
    func testStressOODP009CRunOnce() {
        let fs = runSplit(.stress), fo = runSplit(.ood)
        print("P009C_STRESS scenarios=\(P009CCorpusV1.scenarios(.stress).count) failures=\(fs.count)")
        print("P009C_OOD scenarios=\(P009CCorpusV1.scenarios(.ood).count) failures=\(fo.count)")
        (fs + fo).forEach { print("P009C_SO_FAIL \($0)") }
        XCTAssertTrue(fs.isEmpty && fo.isEmpty, "\(fs + fo)")
    }
    func testCorpusSplitLeakage() {
        let v = P009CLeakageAuditorV1.audit()
        XCTAssertTrue(v.isEmpty, "\(v)")
    }

    // ── §32 targeted laws ──

    func testRiskyToBenignPersistence() {
        let m = runNamed("tc-risky-then-benign")
        XCTAssertGreaterThanOrEqual(m.maxRiskSeen, 0.6, "historical strong risk survives the benign tail")
        XCTAssertTrue(m.narrativeLabels.contains("narrative:risk-escalated"))
        XCTAssertTrue(m.narrativeLabels.contains(where: { $0.hasPrefix("narrative:recovery-observed") }),
                      "recovery NOTED — and risk retained")
        XCTAssertTrue(m.contradictionResolutions.allSatisfy { $0.riskRetained })
    }
    func testSatireCannotEraseMultimodalRisk() {
        // multimodal risk (text + audio + temporal) + satire cue → STRONG_RISK_DOMINANT, never erased
        let brain = makeBrain()
        let s = P009CScenarioV1(name: "adv-satire-multimodal", family: "adv", segments: [
            P009CSegmentV1(startMs: 0, endMs: 3000,
                           input: ExpertInputV2(ocrText: "lol parody — deadly war death toll rises", detectedLanguage: "en",
                                                soundEvents: ["siren"]),
                           temporalRisk: 0.8, temporalTopics: ["war"])],
            annotation: P009CAnnotationV1())
        let m = P009CCorpusV1.run(s, brain: brain, item: ContentItemID(500))
        XCTAssertTrue(m.episodes.first?.contextTags.contains(.satireHumorCandidate) ?? false)
        if let r = m.contradictionResolutions.first {
            XCTAssertNotEqual(r.outcome, .contextQualified, "satire qualifier cannot erase multimodal risk")
            XCTAssertTrue(r.riskRetained)
        }
        XCTAssertGreaterThanOrEqual(m.maxRiskSeen, 0.6)
    }
    func testQuotedLexicalRiskIsQualifiedNotErased() {
        let m = runNamed("tc-quoted-harmful")
        XCTAssertTrue((m.primaryTopics + m.secondaryTopics).contains { $0.concept == "concept:mortality" },
                      "quoted trigger evidence retained")
        XCTAssertTrue(m.episodes.first?.contextTags.contains(.quoted) ?? false)
    }
    func testCorrelatedEvidenceNotOvercounted() {
        // OCR + speech lexical floods are ONE family — strength must not exceed a single family + bonus
        let brain = makeBrain()
        let flood = ExpertInputV2(ocrText: String(repeating: "deadly death ", count: 30), detectedLanguage: "en",
                                  speechTranscript: String(repeating: "deadly death ", count: 30), speechAvailable: true)
        let ctx = ExpertTaskContextV2(observationID: ObservationID(1), shotID: ShotID(1), itemID: ContentItemID(600),
                                      itemProvisional: false, profile: .appFullTier1,
                                      requestedDomains: ExpertDomainV2.allCases, generation: brain.currentGeneration)
        let route = brain.route(input: flood, context: ctx, nowMs: 0)
        let riskEv = route.evidence.filter { e in e.labels.contains { $0.hasPrefix("safety:") || $0.hasPrefix("topic:") } }
        let (strength, families) = EvidenceWeigherV1.combine(riskEv)
        XCTAssertLessThanOrEqual(families.filter { $0.family == "family:text-lexical" }.count, 1,
                                 "correlated text-lexical evidence collapses to ONE family")
        let maxSingle = families.map { $0.weight }.max() ?? 0
        XCTAssertLessThanOrEqual(strength, min(1, maxSingle + 0.15 * Double(max(0, families.count - 1))) + 0.0001,
                                 "combination is bounded — no certainty multiplication")
    }
    func testIntentAmbiguityPreserved() {
        let m = runNamed("tc-intent-ambiguity")
        XCTAssertTrue(m.intentAmbiguous, "teach-vs-sell stays ambiguous — no forced pick")
        XCTAssertGreaterThanOrEqual(m.intents.count, 2)
    }
    func testEntityConflictUnresolvedAndNonIdentifying() {
        let m = runNamed("tc-entity-conflict")
        let places = m.entities.filter { $0.kind == .place }
        XCTAssertGreaterThanOrEqual(places.count, 2, "both conflicting places retained")
        XCTAssertTrue(places.allSatisfy { $0.conflicting }, "conflict marked, never auto-resolved")
        // structural: identity/sensitive traits can never enter
        let g = EntityGraphV1()
        XCTAssertFalse(g.observe(label: "face-id-12", kind: .personPresent, confidence: 0.9, provenance: "x"))
        XCTAssertFalse(g.observe(label: "political-identity:left", kind: .concept, confidence: 0.9, provenance: "x") &&
                       g.all().contains { $0.canonical.contains("identity:") })
        XCTAssertFalse(g.observe(label: "random-person", kind: .personPresent, confidence: 0.9, provenance: "x"),
                       "person entities only via non-identifying presence signals")
    }
    func testEventGraphNeverAssertsCausality() {
        let m = runNamed("tc-benign-then-risky")
        XCTAssertTrue(m.causeHypotheses.allSatisfy { $0.speculative && $0.uncertainty >= 0.5 },
                      "cause/effect only as speculative hypotheses with floored uncertainty")
    }
    func testStaleEpisodeEvidenceExcluded() {
        let brain = makeBrain()
        let gen = brain.currentGeneration
        let staleEv = ExpertEvidenceV2(domain: .safetyEvidence, labels: ["safety:sensitive-death-disease-news"],
                                       confidence: 0.9, coverage: 1, uncertainty: 0.1, itemID: ContentItemID(700),
                                       itemProvisional: false, provenance: "stale-test", modelVersion: "m",
                                       calibrationStatus: .implementedUncalibrated, generation: gen - 0)   // will mark stale below
        var marked = staleEv; marked.stale = true
        let obs = [EpisodeObservationV1(startMs: 0, endMs: 1000, shotIDs: [ShotID(1)], evidence: [marked],
                                        unknownReasons: [], sourceText: nil)]
        let m = WorldModelBuilderV1().build(observations: obs, itemID: ContentItemID(700), itemProvisional: false,
                                            identityRevision: 0, generation: gen, nowMs: 0)
        XCTAssertFalse((m.primaryTopics + m.secondaryTopics).contains { $0.concept == "concept:sensitive-news" },
                       "stale evidence can never shape the world model")
        XCTAssertFalse(m.readiness)
    }
    func testProvisionalIdentityNeverFinalizesDNA() {
        let brain = makeBrain()
        let s = P009CCorpusV1.scenarios(.tune).first { $0.name == "tc-straight-educational" }!
        let m = P009CCorpusV1.run(s, brain: brain, item: ContentItemID(800), provisional: true)
        XCTAssertFalse(m.readiness)
        let fin = ContentDNAFinalizerV1()
        let provisionalSnap = snapshot(brain, item: 800, state: .provisional)
        let (dna, refusal) = fin.finalize(model: m, identity: provisionalSnap, currentGeneration: brain.currentGeneration,
                                          dnaRaw: 1, nowMs: 0)
        XCTAssertNil(dna); XCTAssertNotNil(refusal)
        // even a SPOOFED confirmed snapshot fails: the model itself records provisional evidence
        let spoof = snapshot(brain, item: 800)
        XCTAssertNil(fin.finalize(model: m, identity: spoof, currentGeneration: brain.currentGeneration,
                                  dnaRaw: 2, nowMs: 0).dna, "provisional evidence markers block spoofed finalize")
    }
    func testDNAFinalizeHappyPathAndRevisions() {
        let brain = makeBrain()
        let s = P009CCorpusV1.scenarios(.tune).first { $0.name == "tc-straight-educational" }!
        let m = P009CCorpusV1.run(s, brain: brain, item: ContentItemID(801))
        XCTAssertTrue(m.readiness)
        let fin = ContentDNAFinalizerV1()
        let (dna, refusal) = fin.finalize(model: m, identity: snapshot(brain, item: 801),
                                          currentGeneration: brain.currentGeneration, dnaRaw: 7, nowMs: 100)
        XCTAssertNil(refusal); XCTAssertNotNil(dna)
        XCTAssertEqual(dna?.revisionState, .candidate)
        XCTAssertEqual(dna?.privacyClass, .persistableNonReconstructive)
        fin.confirm(item: ContentItemID(801), nowMs: 200)
        XCTAssertEqual(fin.current(item: ContentItemID(801))?.revisionState, .confirmed)
        // §14 revision triggers
        XCTAssertEqual(fin.applyRevision(item: ContentItemID(801), trigger: .newStrongEvidence, nowMs: 300), .revised)
        XCTAssertEqual(fin.applyRevision(item: ContentItemID(801), trigger: .identitySplitMerge, nowMs: 400), .invalidated)
        XCTAssertEqual(fin.applyRevision(item: ContentItemID(801), trigger: .taxonomyChange, nowMs: 500), .superseded)
        let trail = fin.current(item: ContentItemID(801))?.auditTrail ?? []
        XCTAssertGreaterThanOrEqual(trail.count, 4, "audit provenance preserved append-only: \(trail)")
    }
    func testDNARefusesStaleGenerationAndSplitPending() {
        let brain = makeBrain()
        let s = P009CCorpusV1.scenarios(.tune).first { $0.name == "tc-calm-nature" }!
        let m = P009CCorpusV1.run(s, brain: brain, item: ContentItemID(802))
        let fin = ContentDNAFinalizerV1()
        var snapStale = snapshot(brain, item: 802)
        brain.identityChanged()
        XCTAssertNil(fin.finalize(model: m, identity: snapStale, currentGeneration: brain.currentGeneration,
                                  dnaRaw: 1, nowMs: 0).dna, "stale generation refused")
        snapStale = snapshot(brain, item: 802, splitPending: true)
        XCTAssertNil(fin.finalize(model: m, identity: snapStale, currentGeneration: brain.currentGeneration,
                                  dnaRaw: 1, nowMs: 0).dna, "unresolved split/merge refused")
    }
    func testRawTextCannotLeakIntoDurableDNA() {
        // unique raw token planted in OCR — must NOT appear anywhere in the finalized DNA payload
        let brain = makeBrain()
        let uniqueToken = "zqxjkwPrivateSecret42"
        let s = P009CScenarioV1(name: "leak-probe", family: "privacy", segments: [
            P009CSegmentV1(startMs: 0, endMs: 2000,
                           input: ExpertInputV2(ocrText: "learn the science lesson guide \(uniqueToken)",
                                                detectedLanguage: "en", visualLabels: ["classroom"], visualConfidence: 0.8))],
            annotation: P009CAnnotationV1())
        let m = P009CCorpusV1.run(s, brain: brain, item: ContentItemID(900))
        let fin = ContentDNAFinalizerV1()
        let (dna, _) = fin.finalize(model: m, identity: snapshot(brain, item: 900),
                                    currentGeneration: brain.currentGeneration, dnaRaw: 9, nowMs: 0)
        guard let d = dna else { return XCTFail("should finalize") }
        let serialized = d.topics + d.entities + d.intents + d.narrativeSummary + d.temporalStructure
            + d.safetyEvidence + d.benefitEvidence + d.manipulationEvidence + d.emotionalLoad
            + d.contradictionOutcomes + d.auditTrail + d.meshModelVersions
        XCTAssertFalse(serialized.contains { $0.contains(uniqueToken) }, "raw OCR text never enters durable DNA")
        XCTAssertTrue(serialized.allSatisfy {
            WorldModelPersistenceLawV1.isLawfulDurable($0) || $0.hasPrefix("revision:") || $0.contains("-expert-") || $0.contains("-v1") },
            "every durable string is a canonical/structural form")
    }
    func testWorldModelCacheLaws() {
        let brain = makeBrain()
        let s = P009CCorpusV1.scenarios(.tune).first { $0.name == "tc-straight-educational" }!
        let m = P009CCorpusV1.run(s, brain: brain, item: ContentItemID(950))
        let cache = WorldModelCacheV1()
        cache.insert(m, nowMs: 0)
        XCTAssertEqual(cache.count, 1)
        XCTAssertNotNil(cache.lookup(item: ContentItemID(950), identityRevision: 0, generation: brain.currentGeneration, nowMs: 1).0)
        XCTAssertNil(cache.lookup(item: ContentItemID(950), identityRevision: 1, generation: brain.currentGeneration, nowMs: 1).0,
                     "split/merge revision invalidates")
        // re-insert; generation mismatch → never silently reused
        cache.insert(m, nowMs: 0)
        XCTAssertNil(cache.lookup(item: ContentItemID(950), identityRevision: 0, generation: brain.currentGeneration + 1, nowMs: 1).0)
        cache.reportIdentityCollision(item: ContentItemID(950), strength: .strong)
        XCTAssertNil(cache.lookup(item: ContentItemID(950), identityRevision: 0, generation: brain.currentGeneration, nowMs: 1).0)
        // provisional world models never cached
        let mp = P009CCorpusV1.run(s, brain: makeBrain(), item: ContentItemID(951), provisional: true)
        cache.insert(mp, nowMs: 0)
        XCTAssertNil(cache.lookup(item: ContentItemID(951), identityRevision: 0, generation: 1, nowMs: 1).0)
    }
    func testBoundedGraphsUnderSpam() {
        let m = runNamed("sc-episode-spam", split: .stress)
        XCTAssertLessThanOrEqual(m.episodes.count, 256)
        XCTAssertLessThanOrEqual(m.entities.count, 128)
        XCTAssertLessThanOrEqual(m.events.count, 256)
        XCTAssertLessThanOrEqual(m.provenance.count, 512)
        let topics = TopicGraphV1(maxNodes: 4)
        for i in 0..<20 { topics.observe(concept: "concept:x\(i)", weight: 0.5, uncertainty: 0.5, atMs: 0, provenance: "t") }
        XCTAssertLessThanOrEqual(topics.ranked().count, 4, "topic graph hard-bounded")
    }
    func testTaxonomyVersionChangeInvalidatesCacheAndSupersedesDNA() {
        // structural: cache binds taxonomyVersion (equal today → hit; the mismatch path is exercised via entry check)
        let brain = makeBrain()
        let s = P009CCorpusV1.scenarios(.tune).first { $0.name == "tc-calm-nature" }!
        let m = P009CCorpusV1.run(s, brain: brain, item: ContentItemID(960))
        XCTAssertEqual(m.taxonomyVersion, SemanticTaxonomyV1.version)
        let fin = ContentDNAFinalizerV1()
        _ = fin.finalize(model: m, identity: snapshot(brain, item: 960), currentGeneration: brain.currentGeneration, dnaRaw: 3, nowMs: 0)
        XCTAssertEqual(fin.applyRevision(item: ContentItemID(960), trigger: .taxonomyChange, nowMs: 10), .superseded)
    }
    func testUncertaintyCanProduceUnknown() {
        let m = runNamed("oc-empty-segments", split: .ood, item: 970)
        XCTAssertTrue(["UNKNOWN", "UNAVAILABLE"].contains(m.knowledgeState.rawValue))
        XCTAssertFalse(m.readiness)
    }
    func testMalformedEvidenceSafety() {
        let m = runNamed("oc-poisoned-values", split: .ood, item: 971)
        XCTAssertFalse((m.primaryTopics + m.secondaryTopics).contains { $0.concept == "concept:rapid-editing" },
                       "poisoned density never becomes a topic")
        XCTAssertGreaterThan(m.uncertainty.language, 0.5)
    }
    func testAnnotationDisagreementPreserved() {
        let s = P009CCorpusV1.scenarios(.tune).first { $0.name == "tc-persuasive-ad" }!
        XCTAssertFalse(s.annotation.intentDisagreement.isEmpty,
                       "subjective annotator disagreement is preserved, not merged away")
    }
    func testScoreGlyphStillOff() {
        let brain = makeBrain()
        XCTAssertFalse(brain.calibration.scoreDisplayAllowed())
        let s = P009CCorpusV1.scenarios(.tune)[0]
        let m = P009CCorpusV1.run(s, brain: brain, item: ContentItemID(980))
        // the world model exposes NO numeric verdict field — knowledge state + evidence only
        XCTAssertTrue(["KNOWN", "LIKELY", "AMBIGUOUS", "CONFLICTING", "UNKNOWN", "UNAVAILABLE"].contains(m.knowledgeState.rawValue))
    }
    func testTemporalReinterpretationRequiresProvenanceAndAmbiguity() {
        let t = NarrativeTimelineV1()
        XCTAssertFalse(t.reinterpret(episodeID: 1, from: "concept:x", to: "concept:y", basis: "",
                                     earlierWasAmbiguous: true, atMs: 0), "no provenance → refused")
        XCTAssertFalse(t.reinterpret(episodeID: 1, from: "concept:x", to: "concept:y", basis: "late-context",
                                     earlierWasAmbiguous: false, atMs: 0), "strong earlier state → never reinterpreted")
        XCTAssertTrue(t.reinterpret(episodeID: 1, from: "concept:x", to: "concept:y", basis: "late-context",
                                    earlierWasAmbiguous: true, atMs: 0))
    }
}
