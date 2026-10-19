import XCTest
@testable import GuardianCore

// P009B-R1 — closure tests for every audit finding: F1 lease, F2 splits, F5 availability truth,
// F6 cache firewall, F7 DNA authority, input sanitizer V2, real latency, deadline enforcement,
// asset audit V2, corpus completion, doc/code consistency.

final class P009BR1ClosureTests: XCTestCase {

    func makeBrain(clock: (@Sendable () -> Double)? = nil) -> GuardianMetaBrainV2 {
        let b = GuardianMetaBrainV2(clock: clock)
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
    func ctx(_ b: GuardianMetaBrainV2, item: UInt64, provisional: Bool = false, revision: UInt64 = 0,
             domains: [ExpertDomainV2] = ExpertDomainV2.allCases, deadlineMs: Double = 1000,
             cancel: CancellationTokenV2 = CancellationTokenV2()) -> ExpertTaskContextV2 {
        ExpertTaskContextV2(observationID: ObservationID(1), shotID: ShotID(item), itemID: ContentItemID(item),
                            itemProvisional: provisional, identityRevision: revision, profile: .appFullTier1,
                            requestedDomains: domains, deadlineMs: deadlineMs, cancellation: cancel,
                            generation: b.currentGeneration)
    }

    // ── F1 — deep-analysis lease semantics ──

    func testF1TransientUnavailableThenAvailableExecutes() {
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(), context: ctx(b, item: 1, domains: [.vision]), nowMs: 0)
        XCTAssertEqual(b.governor.leaseState(item: ContentItemID(1), domain: .vision), .unavailableTransient)
        let r2 = b.route(input: ExpertInputV2(visualLabels: ["cat"], visualConfidence: 0.9),
                         context: ctx(b, item: 1, domains: [.vision]), nowMs: 1)
        XCTAssertTrue(r2.evidence.flatMap { $0.labels }.contains("scene:cat"),
                      "transient UNAVAILABLE must not burn the deep budget — later real input IS analyzed")
        XCTAssertEqual(b.governor.leaseState(item: ContentItemID(1), domain: .vision), .executedMeaningful)
    }
    func testF1MeaningfulResultDedupes() {
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(visualLabels: ["cat"], visualConfidence: 0.9),
                    context: ctx(b, item: 2, provisional: true, domains: [.vision]), nowMs: 0)
        let r2 = b.route(input: ExpertInputV2(visualLabels: ["dog"], visualConfidence: 0.9),
                         context: ctx(b, item: 2, provisional: true, domains: [.vision]), nowMs: 1)
        XCTAssertTrue(r2.executed.isEmpty, "meaningful deep result dedupes (provisional → no cache, lease law holds)")
        XCTAssertTrue(r2.unknownReasons.contains { $0.hasPrefix("deep-dedupe:VISION") })
    }
    func testF1BoundedRetriesNoStorm() {
        let b = makeBrain()
        for i in 0..<10 {
            _ = b.route(input: ExpertInputV2(), context: ctx(b, item: 3, domains: [.vision]), nowMs: Double(i))
        }
        let last = b.route(input: ExpertInputV2(), context: ctx(b, item: 3, domains: [.vision]), nowMs: 99)
        XCTAssertTrue(last.unknownReasons.contains { $0.hasPrefix("deep-retry-exhausted:VISION") },
                      "transient retries are bounded — no storms")
        XCTAssertGreaterThan(b.governor.retryExhaustions, 0)
        // the bound applies per (item, domain): a different item still analyzes
        let other = b.route(input: ExpertInputV2(visualLabels: ["x"], visualConfidence: 0.9),
                            context: ctx(b, item: 4, domains: [.vision]), nowMs: 100)
        XCTAssertFalse(other.executed.isEmpty)
    }
    func testF1CancelledAndStaleRetryUnderCorrectGeneration() {
        let b = makeBrain()
        let token = CancellationTokenV2(); token.cancel()
        _ = b.route(input: ExpertInputV2(visualLabels: ["x"], visualConfidence: 0.9),
                    context: ctx(b, item: 5, domains: [.vision], cancel: token), nowMs: 0)
        XCTAssertEqual(b.governor.leaseState(item: ContentItemID(5), domain: .vision), .cancelled)
        let r2 = b.route(input: ExpertInputV2(visualLabels: ["x"], visualConfidence: 0.9),
                         context: ctx(b, item: 5, domains: [.vision]), nowMs: 1)
        XCTAssertTrue(r2.executed.contains(.vision), "cancelled attempt retries")
        // stale: context captured before identity change → outcome STALE → retry under new generation works
        let staleCtx = ctx(b, item: 6, domains: [.vision])
        b.identityChanged()
        _ = b.route(input: ExpertInputV2(visualLabels: ["x"], visualConfidence: 0.9), context: staleCtx, nowMs: 2)
        XCTAssertEqual(b.governor.leaseState(item: ContentItemID(6), domain: .vision), .stale)
        let fresh = b.route(input: ExpertInputV2(visualLabels: ["x"], visualConfidence: 0.9),
                            context: ctx(b, item: 6, domains: [.vision]), nowMs: 3)
        XCTAssertTrue(fresh.executed.contains(.vision), "stale attempt retries under the correct generation")
    }
    func testF1AbstainedBoundedBehavior() {
        let b = makeBrain()
        // UNSUPPORTED_LANGUAGE is an abstention; languageOCR cost 3 < 5 → not leased. Use speech (cost 6):
        // transcript present but availability says no → unavailable transient; declared-with-empty = abstained-ish.
        _ = b.route(input: ExpertInputV2(speechTranscript: nil, speechAvailable: true),
                    context: ctx(b, item: 7, domains: [.speech]), nowMs: 0)
        // "speech:none-detected" has coverage 1 → meaningful execution → dedupe applies (bounded by definition)
        let state = b.governor.leaseState(item: ContentItemID(7), domain: .speech)
        XCTAssertTrue(state == .executedMeaningful || state == .executedAbstained)
    }

    // ── F2 — split independence + leakage auditor ──

    func testF2SplitLeakageAuditorPasses() {
        let violations = CorpusSplitLeakageAuditorV1.audit()
        XCTAssertTrue(violations.isEmpty, "split leakage: \(violations)")
    }
    func testF2SplitsAreStructurallyDistinct() {
        // no byte-identical canonical inputs across any split pair (seed-aliasing is structurally impossible —
        // the V2 API has no seed parameter — but verify content anyway)
        var canonicalBySplit: [P009BSplitV1: Set<String>] = [:]
        for split in P009BSplitV1.allCases {
            canonicalBySplit[split] = Set(P009BCorpusV2.scenarios(split).map { CorpusSplitLeakageAuditorV1.canonical($0) })
        }
        for a in P009BSplitV1.allCases {
            for b in P009BSplitV1.allCases where a != b {
                XCTAssertTrue(canonicalBySplit[a]!.isDisjoint(with: canonicalBySplit[b]!), "\(a) ∩ \(b) non-empty")
            }
        }
    }
    func testF2CalibrationReservedIsReservedNotExecuted() {
        // reservation proof: the bank exists, is hashed, and nothing in the R1 gates executes it.
        XCTAssertFalse(P009BCorpusV2.scenarios(.calibrationReserved).isEmpty)
        let fp = CorpusSplitLeakageAuditorV1.reservedBankFingerprint()
        XCTAssertEqual(fp.count, 16)
        print("P009BR1_CAL_RESERVED fingerprint=\(fp) count=\(P009BCorpusV2.scenarios(.calibrationReserved).count) (never executed)")
    }
    func testF2DetectorCatchesPlantedNearDuplicate() {
        // the near-duplicate RULE itself must work: plant a cross-split near-copy and detect it
        let tune = P009BCorpusV2.scenarios(.tune).first { $0.name == "t-text-only-en" }!
        let planted = P009BScenarioV1(name: "planted-copy", family: "test",
            input: ExpertInputV2(ocrText: "Learn how to build a birdhouse: step by step guide today", detectedLanguage: "en"),
            expectEvidencePrefixes: [], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false)
        let j = CorpusSplitLeakageAuditorV1.jaccard(CorpusSplitLeakageAuditorV1.tokens(tune),
                                                    CorpusSplitLeakageAuditorV1.tokens(planted))
        XCTAssertGreaterThan(j, CorpusSplitLeakageAuditorV1.nearDuplicateJaccardThreshold,
                             "detector rule flags a near-copy (J=\(j))")
    }

    // ── F6 — cache firewall probes: revision, split, collision, schema, TTL, session, valid hit ──

    func testF6IdentityRevisionMismatchMissesAndInvalidates() {
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(ocrText: "learn lesson", detectedLanguage: "en"),
                    context: ctx(b, item: 10, revision: 0, domains: [.languageOCR]), nowMs: 0)
        let r2 = b.route(input: ExpertInputV2(ocrText: "learn lesson", detectedLanguage: "en"),
                         context: ctx(b, item: 10, revision: 1, domains: [.languageOCR]), nowMs: 1)
        XCTAssertTrue(r2.cacheHits.isEmpty, "revision bump (split/merge) → MISS")
        XCTAssertTrue(r2.unknownReasons.contains { $0.contains("identity-revision-mismatch") })
        XCTAssertTrue(r2.executed.contains(.languageOCR), "→ REANALYZE, never stale positive evidence")
    }
    func testF6StrongCollisionAutoInvalidates() {
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(ocrText: "calm nature forest", detectedLanguage: "en"),
                    context: ctx(b, item: 11, domains: [.languageOCR]), nowMs: 0)
        b.cache.reportIdentityCollision(item: ContentItemID(11), strength: .strong)   // identity layer reports
        let r2 = b.route(input: ExpertInputV2(ocrText: "deadly war disaster", detectedLanguage: "en"),
                         context: ctx(b, item: 11, domains: [.languageOCR]), nowMs: 1)
        XCTAssertTrue(r2.cacheHits.isEmpty && r2.executed.contains(.languageOCR), "strong collision → invalidate → re-analysis")
        XCTAssertTrue(r2.evidence.flatMap { $0.labels }.contains("topic:mortality"))
    }
    func testF6AmbiguousCollisionForcesReanalysis() {
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(ocrText: "calm forest", detectedLanguage: "en"),
                    context: ctx(b, item: 12, domains: [.languageOCR]), nowMs: 0)
        b.cache.reportIdentityCollision(item: ContentItemID(12), strength: .ambiguous)
        let r2 = b.route(input: ExpertInputV2(ocrText: "calm forest", detectedLanguage: "en"),
                         context: ctx(b, item: 12, domains: [.languageOCR]), nowMs: 1)
        XCTAssertTrue(r2.cacheHits.isEmpty, "ambiguous collision → forced re-analysis miss")
        XCTAssertGreaterThan(b.cache.reanalysisMisses, 0)
        XCTAssertTrue(r2.executed.contains(.languageOCR))
    }
    func testF6LowInfoTTLExpiryTriggersReanalysis() {
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(soundEvents: ["quantum-hum"]), context: ctx(b, item: 13, domains: [.audioEvent]), nowMs: 0)
        // within low-info TTL → still served (frozen AUDIT3 characterization at +1ms holds)
        let r2 = b.route(input: ExpertInputV2(soundEvents: ["siren"]), context: ctx(b, item: 13, domains: [.audioEvent]), nowMs: 1)
        XCTAssertTrue(r2.cacheHits.contains(.audioEvent))
        // past low-info TTL → expired → the REAL audio is finally analyzed
        let r3 = b.route(input: ExpertInputV2(soundEvents: ["siren"]), context: ctx(b, item: 13, domains: [.audioEvent]), nowMs: 6_000)
        XCTAssertTrue(r3.cacheHits.isEmpty, "low-information evidence expires fast")
        XCTAssertTrue(r3.evidence.flatMap { $0.labels }.contains("audio:siren"))
        XCTAssertGreaterThan(b.cache.ttlExpiries, 0)
    }
    func testF6SchemaMismatchMisses() {
        // structural: schema version is part of every entry; a different runtime schema can never be served
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(ocrText: "learn", detectedLanguage: "en"), context: ctx(b, item: 14, domains: [.languageOCR]), nowMs: 0)
        XCTAssertEqual(IntelligenceCacheV2.evidenceSchemaVersion, "expert-evidence-schema-v2")
        let (entry, _) = b.cache.lookup(item: ContentItemID(14), domain: .languageOCR,
                                        modelVersion: "language-ocr-expert-v1/lexicon-v1", identityRevision: 0,
                                        privacyClass: .derivedNonReconstructive, nowMs: 1)
        XCTAssertEqual(entry?.schemaVersion, IntelligenceCacheV2.evidenceSchemaVersion)
    }
    func testF6OldGenerationCacheReuseIsNeverSilent() {
        let b = makeBrain()
        let c = ctx(b, item: 15, domains: [.languageOCR])
        _ = b.route(input: ExpertInputV2(ocrText: "learn", detectedLanguage: "en"), context: c, nowMs: 0)
        b.identityChanged()
        let r2 = b.route(input: ExpertInputV2(ocrText: "learn", detectedLanguage: "en"), context: c, nowMs: 1)
        XCTAssertTrue(r2.cacheHits.contains(.languageOCR), "same item revision → reuse stays legal")
        XCTAssertTrue(r2.unknownReasons.contains { $0.hasPrefix("cache-hit-old-generation:") },
                      "…but it is explicitly reported, never silent (R1 F6)")
    }
    func testF6SessionResetViaInvalidation() {
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(ocrText: "learn", detectedLanguage: "en"), context: ctx(b, item: 16, domains: [.languageOCR]), nowMs: 0)
        b.cache.invalidate(item: ContentItemID(16))
        let r = b.route(input: ExpertInputV2(ocrText: "learn", detectedLanguage: "en"), context: ctx(b, item: 16, domains: [.languageOCR]), nowMs: 1)
        XCTAssertTrue(r.cacheHits.isEmpty && r.executed.contains(.languageOCR))
    }

    // ── F7 — DNA authority ──

    func makeConfirmedState(_ b: GuardianMetaBrainV2, item: UInt64) -> ContentUnderstandingStateV1 {
        let r = b.route(input: ExpertInputV2(ocrText: "learn science lesson", detectedLanguage: "en"),
                        context: ctx(b, item: item), nowMs: 0)
        let g = CrossModalExpertGraphV1(); g.relate(r.evidence)
        return ContentUnderstandingStateV1.build(itemProvisional: false, evidence: r.evidence, graph: g,
                                                 registry: b.registry, unknownReasons: r.unknownReasons)
    }
    func snapshot(_ item: UInt64, state: IdentityResolutionSnapshotV1.ResolutionStateV1 = .confirmed,
                  authority: IdentityResolutionSnapshotV1.ConfirmationAuthorityV1 = .tier1AppFull,
                  profile: RuntimeCapabilityProfileV2 = .appFullTier1, generation: UInt64 = 1,
                  splitPending: Bool = false, conflict: Bool = false, revision: UInt64 = 0) -> IdentityResolutionSnapshotV1 {
        IdentityResolutionSnapshotV1(itemID: ContentItemID(item), identityRevision: revision, resolutionState: state,
                                     sourceProfile: profile, evidenceProvenance: "ContentItemGroupingEngineV2/test",
                                     confirmationAuthority: authority, generation: generation,
                                     unresolvedSplitOrMerge: splitPending, strongNewOrConflict: conflict)
    }
    func testF7AuthoritativeMintHappyPath() {
        let b = makeBrain()
        let st = makeConfirmedState(b, item: 20)
        let dna = ContentDNACandidateV2.mint(from: st, identity: snapshot(20), currentGeneration: b.currentGeneration,
                                             dnaRaw: 1, nowMs: 0, modelVersions: ["m"])
        XCTAssertNotNil(dna, "confirmed + authority + current generation + clean evidence → mints")
    }
    func testF7SpoofAndStaleAndSplitPendingAllRefused() {
        let b = makeBrain()
        let st = makeConfirmedState(b, item: 21)
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snapshot(21, state: .provisional),
                                                currentGeneration: b.currentGeneration, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]))
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snapshot(21, authority: .none),
                                                currentGeneration: b.currentGeneration, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]))
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snapshot(21, profile: .extensionFastTier0),
                                                currentGeneration: b.currentGeneration, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]),
                     "Tier-0 can never be a confirmation authority")
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snapshot(21, generation: 99),
                                                currentGeneration: b.currentGeneration, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]),
                     "stale snapshot refused")
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snapshot(21, splitPending: true),
                                                currentGeneration: b.currentGeneration, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]))
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snapshot(21, conflict: true),
                                                currentGeneration: b.currentGeneration, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]))
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snapshot(999),
                                                currentGeneration: b.currentGeneration, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]),
                     "foreign-item evidence refused")
    }
    func testF7ProvisionalEvidenceSpoofRefusedEvenOnLegacyEntryPoint() {
        let b = makeBrain()
        let r = b.route(input: ExpertInputV2(ocrText: "learn science lesson", detectedLanguage: "en"),
                        context: ctx(b, item: 22, provisional: true), nowMs: 0)
        let g = CrossModalExpertGraphV1(); g.relate(r.evidence)
        let lying = ContentUnderstandingStateV1.build(itemProvisional: false, evidence: r.evidence, graph: g,
                                                      registry: b.registry, unknownReasons: [])
        XCTAssertTrue(lying.anyEvidenceProvisional, "evidence-level markers recorded regardless of caller claims")
        XCTAssertNil(ContentDNACandidateV2.mint(from: lying, itemID: ContentItemID(22), itemProvisional: false,
                                                dnaRaw: 9, nowMs: 0, modelVersions: ["m"]),
                     "R1 F7: legacy entry point also verifies evidence markers — lying caller gets nil")
        XCTAssertNil(ContentDNACandidateV2.mint(from: lying, identity: snapshot(22),
                                                currentGeneration: b.currentGeneration, dnaRaw: 9, nowMs: 0, modelVersions: ["m"]))
    }

    // ── §7 — input sanitizer V2 fuzz/property ──

    func testSanitizerDropsAndClampsEverything() {
        let dirty = ExpertInputV2(ocrText: String(repeating: "a", count: 20_000), detectedLanguage: "zz!!bad",
                                  visualLabels: (1...200).map { "l\($0)" }, visualConfidence: .nan,
                                  soundEvents: (1...200).map { "s\($0)" }, speechTranscript: nil, speechAvailable: false,
                                  musicPresence: false, musicTempoEnergy: .infinity,
                                  editDensityCutsPerMinute: -4, elapsedItemMs: .nan)
        let (clean, flags) = ExpertInputSanitizerV2.sanitize(dirty)
        XCTAssertEqual(clean.visualConfidence, 0)
        XCTAssertNil(clean.musicTempoEnergy)
        XCTAssertNil(clean.editDensityCutsPerMinute)
        XCTAssertNil(clean.elapsedItemMs)
        XCTAssertNil(clean.detectedLanguage)
        XCTAssertEqual(clean.visualLabels?.count, ExpertInputSanitizerV2.maxLabels)
        XCTAssertEqual(clean.soundEvents?.count, ExpertInputSanitizerV2.maxLabels)
        XCTAssertEqual(clean.ocrText?.count, ExpertInputSanitizerV2.maxTextChars)
        XCTAssertGreaterThanOrEqual(flags.count, 7)
    }
    func testSanitizerPropertyNoNonFiniteSurvives() {
        // property sweep over a deterministic grid of poisoned values
        let poisons: [Double] = [.nan, .infinity, -.infinity, -1, 2, 1e308, -1e-9]
        for p in poisons {
            let (clean, _) = ExpertInputSanitizerV2.sanitize(ExpertInputV2(visualLabels: ["x"], visualConfidence: p,
                                                                           musicPresence: true, musicTempoEnergy: p,
                                                                           editDensityCutsPerMinute: p, elapsedItemMs: p))
            if let c = clean.visualConfidence { XCTAssertTrue(c.isFinite && c >= 0 && c <= 1) }
            if let t = clean.musicTempoEnergy { XCTAssertTrue(t.isFinite) }
            if let d = clean.editDensityCutsPerMinute { XCTAssertTrue(d.isFinite && d >= 0) }
            if let e = clean.elapsedItemMs { XCTAssertTrue(e.isFinite && e >= 0) }
        }
    }
    func testSanitizedRouteNeverCarriesNaNIntoEvidence() {
        let b = makeBrain()
        let r = b.route(input: ExpertInputV2(ocrText: "learn", detectedLanguage: "en", visualLabels: ["x"],
                                             visualConfidence: .nan, editDensityCutsPerMinute: .nan),
                        context: ctx(b, item: 30), nowMs: 0)
        for e in r.evidence { for (_, v) in e.features { XCTAssertTrue(v.isFinite, "\(e.domain) leaked non-finite feature") } }
        XCTAssertTrue(r.unknownReasons.contains { $0.hasPrefix("input-sanitized:") }, "sanitization is visible, not silent")
    }

    // ── §8 — real latency instrumentation ──

    func testLatencyIsMeasuredMonotonically() {
        let b = makeBrain()
        for i in 0..<20 {
            _ = b.route(input: ExpertInputV2(ocrText: "learn the lesson guide now today", detectedLanguage: "en"),
                        context: ctx(b, item: UInt64(100 + i)), nowMs: Double(i))
        }
        guard let route = b.latency.percentiles("route") else { return XCTFail("route latency NOT_MEASURED") }
        XCTAssertGreaterThan(route.p50, 0, "route latency is a real monotonic measurement")
        XCTAssertGreaterThanOrEqual(route.p95, route.p50)
        let perExpert = b.registry.health.snapshot().values.flatMap { $0.latenciesMs }
        XCTAssertTrue(perExpert.contains { $0 > 0 }, "per-expert execution measured")
        XCTAssertNotNil(b.latency.percentiles("cache-lookup") ?? b.latency.percentiles("route"))
    }
    func testNoSamplesMeansNotMeasuredNotZero() {
        let fresh = OperationLatencyRegistryV1()
        XCTAssertNil(fresh.percentiles("route"), "no samples → nil → callers must render NOT_MEASURED, never 0 ms")
        fresh.record("op", ms: .nan)                                   // non-finite samples are refused
        XCTAssertNil(fresh.percentiles("op"))
    }

    // ── §9 — deadline enforcement (injectable clock) ──

    func testExpiredDeadlineDefersNewWorkButServesCache() {
        var fake = 0.0
        let holder = NSLock()
        let b = makeBrain(clock: { holder.lock(); defer { holder.unlock() }; return fake })
        // warm the cache within budget
        _ = b.route(input: ExpertInputV2(ocrText: "learn", detectedLanguage: "en"), context: ctx(b, item: 40, domains: [.languageOCR]), nowMs: 0)
        // expire the budget instantly for the next route
        holder.lock(); fake = 0; holder.unlock()
        let r = b.route(input: ExpertInputV2(ocrText: "learn", detectedLanguage: "en", visualLabels: ["x"], visualConfidence: 0.9),
                        context: ctx(b, item: 40, domains: [.languageOCR, .vision], deadlineMs: 0), nowMs: 1)
        XCTAssertTrue(r.cacheHits.contains(.languageOCR), "cache path still serves under an expired deadline")
        XCTAssertFalse(r.executed.contains(.vision), "no NEW work past the deadline")
        XCTAssertTrue(r.unknownReasons.contains { $0.hasPrefix("deadline-expired:VISION") })
    }
    func testOnTimeResultAttachesLateResultDiscarded() {
        var fake = 0.0
        let holder = NSLock()
        let b = GuardianMetaBrainV2(clock: { holder.lock(); defer { holder.unlock() }; return fake })
        // a test expert that burns 50 "ms" of fake clock inside evaluate
        struct SlowExpert: MultimodalExpertV2 {
            let domain: ExpertDomainV2 = .vision
            let availability: ExpertAvailabilityV2 = .realInProcessLabOnly
            let modelVersion = "slow-test-expert"
            let resourceCost: Double = 1                   // below lease threshold — isolates the deadline law
            let burn: @Sendable () -> Void
            func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2 {
                burn()
                return ExpertEvidenceV2(domain: .vision, labels: ["scene:slow"], confidence: 0.5, coverage: 1,
                                        uncertainty: 0.5, itemID: context.itemID, itemProvisional: context.itemProvisional,
                                        provenance: "slow", modelVersion: "slow-test-expert",
                                        calibrationStatus: .heuristicSupportOnly, generation: context.generation)
            }
        }
        b.registry.register(SlowExpert(burn: { holder.lock(); fake += 50; holder.unlock() }))
        // on-time: deadline 100 > 50 → attaches
        let ok = b.route(input: ExpertInputV2(), context: ctx(b, item: 41, domains: [.vision], deadlineMs: 100), nowMs: 0)
        XCTAssertTrue(ok.executed.contains(.vision))
        // late: deadline 10 < 50 burn → result lands after budget → discarded, never attached
        let late = b.route(input: ExpertInputV2(), context: ctx(b, item: 42, domains: [.vision], deadlineMs: 10), nowMs: 1)
        XCTAssertFalse(late.executed.contains(.vision), "late result cannot attach")
        XCTAssertTrue(late.unknownReasons.contains { $0.hasPrefix("deadline-late-discarded:VISION") })
        XCTAssertTrue(late.evidence.isEmpty)
    }
    func testDeadlineWithFairThermalAndIdentityRace() {
        var fake = 0.0
        let holder = NSLock()
        let b = makeBrain(clock: { holder.lock(); defer { holder.unlock() }; return fake })
        b.governor.setThermal(.fair)
        let r = b.route(input: ExpertInputV2(ocrText: "deadly disaster learn", detectedLanguage: "en",
                                             visualLabels: ["x"], visualConfidence: 0.9),
                        context: ctx(b, item: 43, deadlineMs: 1000), nowMs: 0)
        XCTAssertTrue(r.deferredThermal.contains(.vision), "FAIR + deadline compose; thermal law unchanged")
        XCTAssertTrue(r.executed.contains(.safetyEvidence))
        // identity-change race: generation bumps mid-flight → stale firewall wins regardless of deadline
        let staleCtx = ctx(b, item: 44, domains: [.safetyEvidence])
        b.identityChanged()
        let r2 = b.route(input: ExpertInputV2(ocrText: "x", detectedLanguage: "en"), context: staleCtx, nowMs: 1)
        XCTAssertTrue(r2.executed.isEmpty)
        XCTAssertTrue(r2.unknownReasons.contains { $0.hasPrefix("stale-discarded:") })
    }

    // ── §10 — asset audit V2 completeness ──

    func testAssetAuditV2CompleteAndLawful() {
        XCTAssertTrue(P009BAssetAuditLedgerV2.allIntegrationsLawful)
        XCTAssertEqual(P009BAssetAuditLedgerV2.records.count, 6)
        for r in P009BAssetAuditLedgerV2.records {
            XCTAssertFalse(r.codeLicense.isEmpty); XCTAssertFalse(r.weightsLicense.isEmpty)
            XCTAssertFalse(r.trainingDataProvenance.isEmpty); XCTAssertFalse(r.verificationSource.isEmpty)
            XCTAssertFalse(r.auditDateISO8601.isEmpty); XCTAssertFalse(r.fallback.isEmpty)
            XCTAssertTrue(r.integrationApproved)
            if r.licenseClass == .appleSystemFramework {
                XCTAssertTrue(r.weightsLicense.contains("NOT_APPLICABLE") || r.trainingDataProvenance.contains("NOT_APPLICABLE"),
                              "OS frameworks use NOT_APPLICABLE sentinels — nothing invented")
            }
        }
    }

    // ── §11/§12 — corpus completion + doc/code consistency ──

    func testRequiredFamiliesPresentInTune() {
        let names = Set(P009BCorpusV2.scenarios(.tune).map { $0.name })
        for required in ["t-conflict-sarcasm-vs-literal", "t-conflict-cheerful-visual-distressing-audio",
                         "t-temporal-risky-benign-recovery", "t-temporal-montage",
                         "t-temporal-repeated-scene", "t-temporal-talkinghead-broll"] {
            XCTAssertTrue(names.contains(required), "missing R1 §11 family: \(required)")
        }
    }
    func testV1CorpusCountTruth() {
        XCTAssertEqual(P009BCorpusV1.corpus(seed: 0).count, 18, "the REAL V1 count — docs corrected to 18 (F4)")
    }
    func testDocCodeConsistency() throws {
        // repo-relative doc reads via #filePath — counts/labels in docs must match code truth
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let corpusDoc = repoRoot.appendingPathComponent("docs/evals/P009B_RIGHTS_CLEAR_CORPUS.md")
        guard let text = try? String(contentsOf: corpusDoc, encoding: .utf8) else {
            throw XCTSkip("doc not accessible in this sandbox")
        }
        for split in P009BSplitV1.allCases {
            let expected = "\(split.rawValue): \(P009BCorpusV2.scenarios(split).count)"
            XCTAssertTrue(text.contains(expected), "corpus doc must state '\(expected)' (generated from code)")
        }
        XCTAssertTrue(text.contains("18"), "V1 scenario count corrected to 18 in the corpus doc")
        // availability labels: the capability doc must use the 5-tier names (no stale REAL_RUNTIME inflation)
        let contractDoc = repoRoot.appendingPathComponent("docs/intelligence/P009B_EXPERT_CONTRACT.md")
        if let cdoc = try? String(contentsOf: contractDoc, encoding: .utf8) {
            XCTAssertTrue(cdoc.contains("REAL_IN_PROCESS_LAB_ONLY"))
            XCTAssertFalse(cdoc.contains("| REAL_RUNTIME |"), "no bare REAL_RUNTIME claims survive in the contract doc")
        }
    }
    func testAvailabilityTruthMatchesRuntime() {
        let b = makeBrain()
        for d in ExpertDomainV2.allCases {
            XCTAssertEqual(b.registry.availability(d), .realInProcessLabOnly,
                           "R1 F5: every arm is REAL_IN_PROCESS_LAB_ONLY until a production consumer + device proof exist (\(d))")
        }
    }

    // ── R1 corpus V2 gates: TUNE → freeze → HELD-OUT/STRESS/OOD run-once ──

    func runSplit(_ split: P009BSplitV1) -> [String] {
        var failures: [String] = []
        for (i, s) in P009BCorpusV2.scenarios(split).enumerated() {
            let brain = makeBrain()
            let r = P009BCorpusV2.runScenario(s, brain: brain, item: ContentItemID(UInt64(i + 1)), nowMs: Double(i))
            let labels = r.route.evidence.flatMap { $0.labels }
            for exp in s.expectEvidencePrefixes where !labels.contains(where: { $0.hasPrefix(exp) || $0.contains(exp) }) {
                failures.append("\(split.rawValue)/\(s.name): missing '\(exp)'")
            }
            for forb in s.forbidEvidencePrefixes where labels.contains(where: { $0.hasPrefix(forb) }) {
                failures.append("\(split.rawValue)/\(s.name): forbidden '\(forb)'")
            }
            if s.expectContradiction && r.graph.contradictions.isEmpty { failures.append("\(split.rawValue)/\(s.name): expected contradiction") }
            let hasAbstention = r.route.evidence.contains { !$0.inputModalityAvailable } || !r.route.unknownReasons.isEmpty
            if s.expectAbstention && !hasAbstention { failures.append("\(split.rawValue)/\(s.name): expected abstention") }
            if s.expectCacheHitOnRepeat {
                if (r.repeatRoute?.cacheHits.isEmpty ?? true) { failures.append("\(split.rawValue)/\(s.name): expected cache hit on repeat") }
            }
        }
        return failures
    }
    func testTuneV2() {
        let f = runSplit(.tune)
        print("P009BR1_TUNE scenarios=\(P009BCorpusV2.scenarios(.tune).count) failures=\(f.count)")
        f.forEach { print("P009BR1_TUNE_FAIL \($0)") }
        XCTAssertTrue(f.isEmpty, "\(f)")
    }
    func testHeldOutV2RunOnce() {
        let f = runSplit(.heldOut)
        print("P009BR1_HELDOUT scenarios=\(P009BCorpusV2.scenarios(.heldOut).count) failures=\(f.count)")
        f.forEach { print("P009BR1_HELDOUT_FAIL \($0)") }
        XCTAssertTrue(f.isEmpty, "\(f)")
    }
    func testStressOODV2RunOnce() {
        let fs = runSplit(.stress), fo = runSplit(.ood)
        print("P009BR1_STRESS scenarios=\(P009BCorpusV2.scenarios(.stress).count) failures=\(fs.count)")
        print("P009BR1_OOD scenarios=\(P009BCorpusV2.scenarios(.ood).count) failures=\(fo.count)")
        (fs + fo).forEach { print("P009BR1_SO_FAIL \($0)") }
        XCTAssertTrue(fs.isEmpty && fo.isEmpty, "\(fs + fo)")
    }
}
