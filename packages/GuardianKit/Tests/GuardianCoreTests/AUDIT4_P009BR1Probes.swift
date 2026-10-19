import XCTest
@testable import GuardianCore

// ============================================================================
// AUDIT4_P009BR1Probes — INDEPENDENT RE-AUDIT PROBES (fresh-context session, 2026-10-19)
// Mandate: docs/audit/prompts/GEN8_INDEPENDENT_P009B_R1_REAUDIT.md
// LAW: this file only ADDS tests. No existing source or test file was modified by the re-auditor.
// Covers the spec's minimum fresh-probe list: unavailable→available provider, stale cache same item ID,
// DNA mint spoof, NaN editDensity, deadline race, corpus near-duplicate detector, duplicate heavy expert
// scheduling, malformed provenance, FAIR thermal + deadline pressure. (HUD real-vs-synthetic mislabel
// probe lives in GuardianIntelligenceTests/AUDIT4_P009BR1RealPathProbes.swift — needs the real adapter.)
// ============================================================================

final class AUDIT4_P009BR1Probes: XCTestCase {

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
    func ctx(_ b: GuardianMetaBrainV2, item: UInt64?, provisional: Bool = false, revision: UInt64 = 0,
             domains: [ExpertDomainV2] = ExpertDomainV2.allCases, deadlineMs: Double = 1000,
             cancel: CancellationTokenV2 = CancellationTokenV2()) -> ExpertTaskContextV2 {
        ExpertTaskContextV2(observationID: ObservationID(1), shotID: item.map { ShotID($0) },
                            itemID: item.map { ContentItemID($0) },
                            itemProvisional: provisional, identityRevision: revision, profile: .appFullTier1,
                            requestedDomains: domains, deadlineMs: deadlineMs, cancellation: cancel,
                            generation: b.currentGeneration)
    }

    // ── PROBE 1 — unavailable→available provider (F1 recovery + meaningful dedupe + no silent refusal) ──

    func testA4_UnavailableThenAvailableProviderRecovers() {
        let b = makeBrain()
        // t0: provider momentarily yields nothing → honest UNAVAILABLE, lease released as TRANSIENT
        _ = b.route(input: ExpertInputV2(), context: ctx(b, item: 101, domains: [.vision]), nowMs: 0)
        XCTAssertEqual(b.governor.leaseState(item: ContentItemID(101), domain: .vision), .unavailableTransient)
        // t1: the provider comes back → the item MUST be analyzed (the pre-R1 defect burned the budget here)
        let r2 = b.route(input: ExpertInputV2(visualLabels: ["cat"], visualConfidence: 0.9),
                         context: ctx(b, item: 101, domains: [.vision]), nowMs: 1)
        XCTAssertTrue(r2.evidence.flatMap { $0.labels }.contains("scene:cat"),
                      "transient provider absence must never become permanent per-item blindness")
        XCTAssertFalse(r2.unknownReasons.contains { $0.hasPrefix("deep-dedupe:VISION") })
        XCTAssertEqual(b.governor.leaseState(item: ContentItemID(101), domain: .vision), .executedMeaningful)
        // t2: a MEANINGFUL result dedupes — and the refusal is reported, never silent
        let r3 = b.route(input: ExpertInputV2(visualLabels: ["dog"], visualConfidence: 0.9),
                         context: ctx(b, item: 101, provisional: true, domains: [.vision]), nowMs: 2)
        XCTAssertFalse(r3.evidence.flatMap { $0.labels }.contains("scene:dog"))
        XCTAssertTrue(r3.unknownReasons.contains { $0.hasPrefix("deep-dedupe:VISION") })
    }

    func testA4_PermanentUnavailableSuppressesWithExplicitReason() {
        let b = makeBrain()
        b.governor.completeDeep(item: ContentItemID(102), domain: .vision, outcome: .unavailablePermanent)
        let r = b.route(input: ExpertInputV2(visualLabels: ["cat"], visualConfidence: 0.9),
                        context: ctx(b, item: 102, domains: [.vision]), nowMs: 0)
        XCTAssertFalse(r.executed.contains(.vision), "permanent unavailability suppresses deep re-runs")
        XCTAssertTrue(r.unknownReasons.contains { $0.hasPrefix("deep-permanent-unavailable:VISION") },
                      "…and the suppression is reported, never silent")
    }

    func testA4_TransientRetryStormIsBounded() {
        let b = makeBrain()
        for i in 0..<8 { _ = b.route(input: ExpertInputV2(), context: ctx(b, item: 103, domains: [.vision]), nowMs: Double(i)) }
        let last = b.route(input: ExpertInputV2(), context: ctx(b, item: 103, domains: [.vision]), nowMs: 50)
        XCTAssertTrue(last.unknownReasons.contains { $0.hasPrefix("deep-retry-exhausted:VISION") },
                      "bounded retries — no storms")
        // the bound is per (item,domain): another item is unaffected
        let other = b.route(input: ExpertInputV2(visualLabels: ["tree"], visualConfidence: 0.8),
                            context: ctx(b, item: 104, domains: [.vision]), nowMs: 51)
        XCTAssertTrue(other.evidence.flatMap { $0.labels }.contains("scene:tree"))
    }

    // ── PROBE 2 — stale cache, SAME item ID (F6: old generation / revision / collision) ──

    func testA4_StaleCacheSameItemID_OldGenerationReuseIsReported() {
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(ocrText: "learn the lesson", detectedLanguage: "en"),
                    context: ctx(b, item: 110, domains: [.languageOCR]), nowMs: 0)
        b.identityChanged()                                       // generation bumps; same item identity persists
        let r2 = b.route(input: ExpertInputV2(ocrText: "learn the lesson", detectedLanguage: "en"),
                         context: ctx(b, item: 110, domains: [.languageOCR]), nowMs: 1)
        XCTAssertTrue(r2.cacheHits.contains(.languageOCR), "same item + same revision → reuse is legal")
        XCTAssertTrue(r2.unknownReasons.contains { $0.hasPrefix("cache-hit-old-generation:LANGUAGE_OCR") },
                      "R1 F6: old-generation reuse must be explicitly reported, never silent")
    }

    func testA4_StaleCacheSameItemID_RevisionBumpForcesReanalysis() {
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(ocrText: "calm forest nature", detectedLanguage: "en"),
                    context: ctx(b, item: 111, revision: 0, domains: [.languageOCR]), nowMs: 0)
        // identity layer reports a split/merge → revision bump: the old record may NEVER be served
        let r2 = b.route(input: ExpertInputV2(ocrText: "deadly war casualties", detectedLanguage: "en"),
                         context: ctx(b, item: 111, revision: 1, domains: [.languageOCR]), nowMs: 1)
        XCTAssertTrue(r2.cacheHits.isEmpty)
        XCTAssertTrue(r2.unknownReasons.contains { $0.contains("identity-revision-mismatch") })
        XCTAssertTrue(r2.evidence.flatMap { $0.labels }.contains("topic:mortality"),
                      "the NEW content is analyzed — risky content can no longer hide behind a stale entry")
    }

    func testA4_StaleCacheSameItemID_CollisionPathsInvalidate() {
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(ocrText: "calm forest", detectedLanguage: "en"),
                    context: ctx(b, item: 112, domains: [.languageOCR]), nowMs: 0)
        b.cache.reportIdentityCollision(item: ContentItemID(112), strength: .strong)
        let r = b.route(input: ExpertInputV2(ocrText: "deadly disaster", detectedLanguage: "en"),
                        context: ctx(b, item: 112, domains: [.languageOCR]), nowMs: 1)
        XCTAssertTrue(r.cacheHits.isEmpty && r.executed.contains(.languageOCR),
                      "strong collision → automatic invalidation → re-analysis")
        // ambiguous → forced re-analysis on next read
        _ = b.route(input: ExpertInputV2(ocrText: "garden tour", detectedLanguage: "en"),
                    context: ctx(b, item: 113, domains: [.languageOCR]), nowMs: 2)
        b.cache.reportIdentityCollision(item: ContentItemID(113), strength: .ambiguous)
        let r2 = b.route(input: ExpertInputV2(ocrText: "garden tour", detectedLanguage: "en"),
                         context: ctx(b, item: 113, domains: [.languageOCR]), nowMs: 3)
        XCTAssertTrue(r2.cacheHits.isEmpty && r2.executed.contains(.languageOCR))
    }

    func testA4_LowInfoCachePoisonExpiresByTTL() {
        let b = makeBrain()
        _ = b.route(input: ExpertInputV2(soundEvents: ["warp-field-hum"]),      // unsupported → low-information
                    context: ctx(b, item: 114, domains: [.audioEvent]), nowMs: 0)
        let inside = b.route(input: ExpertInputV2(soundEvents: ["siren"]), context: ctx(b, item: 114, domains: [.audioEvent]), nowMs: 4_999)
        XCTAssertTrue(inside.cacheHits.contains(.audioEvent), "inside the 5s low-info TTL the poison still serves")
        let after = b.route(input: ExpertInputV2(soundEvents: ["siren"]), context: ctx(b, item: 114, domains: [.audioEvent]), nowMs: 5_001)
        XCTAssertTrue(after.cacheHits.isEmpty, "low-information evidence expires fast (TTL)")
        XCTAssertTrue(after.evidence.flatMap { $0.labels }.contains("audio:siren"),
                      "the REAL siren is finally analyzed — low-info poisoning is time-bounded")
    }

    // ── PROBE 3 — DNA mint spoof (F7: authoritative snapshot + evidence-level markers) ──

    func confirmedState(_ b: GuardianMetaBrainV2, item: UInt64) -> ContentUnderstandingStateV1 {
        let r = b.route(input: ExpertInputV2(ocrText: "learn science lesson guide", detectedLanguage: "en"),
                        context: ctx(b, item: item), nowMs: 0)
        let g = CrossModalExpertGraphV1(); g.relate(r.evidence)
        return ContentUnderstandingStateV1.build(itemProvisional: false, evidence: r.evidence, graph: g,
                                                 registry: b.registry, unknownReasons: r.unknownReasons)
    }
    func snap(_ item: UInt64, state: IdentityResolutionSnapshotV1.ResolutionStateV1 = .confirmed,
              authority: IdentityResolutionSnapshotV1.ConfirmationAuthorityV1 = .tier1AppFull,
              profile: RuntimeCapabilityProfileV2 = .appFullTier1, generation: UInt64 = 1,
              splitPending: Bool = false, conflict: Bool = false) -> IdentityResolutionSnapshotV1 {
        IdentityResolutionSnapshotV1(itemID: ContentItemID(item), identityRevision: 0, resolutionState: state,
                                     sourceProfile: profile, evidenceProvenance: "re-audit-probe",
                                     confirmationAuthority: authority, generation: generation,
                                     unresolvedSplitOrMerge: splitPending, strongNewOrConflict: conflict)
    }

    func testA4_DNAMintSpoofMatrixAllRefused() {
        let b = makeBrain()
        let st = confirmedState(b, item: 120)
        // control: lawful mint works (so the refusals below are load-bearing, not vacuous)
        XCTAssertNotNil(ContentDNACandidateV2.mint(from: st, identity: snap(120), currentGeneration: 1,
                                                   dnaRaw: 1, nowMs: 0, modelVersions: ["m"]))
        // every spoof axis refused
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snap(120, state: .provisional),
                                                currentGeneration: 1, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]))
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snap(120, state: .mergePending),
                                                currentGeneration: 1, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]))
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snap(120, authority: .none),
                                                currentGeneration: 1, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]))
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snap(120, profile: .extensionFastTier0),
                                                currentGeneration: 1, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]),
                     "Tier-0 may never confirm identity")
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snap(120, generation: 7),
                                                currentGeneration: 1, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]),
                     "stale snapshot refused")
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snap(120, splitPending: true),
                                                currentGeneration: 1, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]))
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snap(120, conflict: true),
                                                currentGeneration: 1, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]))
        XCTAssertNil(ContentDNACandidateV2.mint(from: st, identity: snap(777),
                                                currentGeneration: 1, dnaRaw: 1, nowMs: 0, modelVersions: ["m"]),
                     "foreign-item evidence refused")
    }

    func testA4_DNAMintLyingCallerOnProvisionalEvidenceRefused() {
        let b = makeBrain()
        let r = b.route(input: ExpertInputV2(ocrText: "learn science lesson", detectedLanguage: "en"),
                        context: ctx(b, item: 121, provisional: true), nowMs: 0)
        let g = CrossModalExpertGraphV1(); g.relate(r.evidence)
        // the caller LIES on every flag it controls
        let lying = ContentUnderstandingStateV1.build(itemProvisional: false, evidence: r.evidence, graph: g,
                                                      registry: b.registry, unknownReasons: [])
        XCTAssertTrue(lying.anyEvidenceProvisional, "evidence-level markers are recorded from the records themselves")
        XCTAssertNil(ContentDNACandidateV2.mint(from: lying, itemID: ContentItemID(121), itemProvisional: false,
                                                dnaRaw: 2, nowMs: 0, modelVersions: ["m"]),
                     "legacy entry point: lying caller gets nil (the pre-R1 defect minted here)")
        XCTAssertNil(ContentDNACandidateV2.mint(from: lying, identity: snap(121), currentGeneration: 1,
                                                dnaRaw: 2, nowMs: 0, modelVersions: ["m"]))
    }

    func testA4_DNAMintCrossGenerationEvidenceRefused() {
        let b = makeBrain()
        let r1 = b.route(input: ExpertInputV2(ocrText: "learn science lesson", detectedLanguage: "en"),
                         context: ctx(b, item: 122, domains: [.languageOCR]), nowMs: 0)
        b.identityChanged()                                                      // → generation 2
        let r2 = b.route(input: ExpertInputV2(ocrText: "learn history guide", detectedLanguage: "en"),
                         context: ctx(b, item: 122, domains: [.benefitEvidence]), nowMs: 1)
        let g = CrossModalExpertGraphV1(); g.relate(r1.evidence + r2.evidence)
        let mixed = ContentUnderstandingStateV1.build(itemProvisional: false, evidence: r1.evidence + r2.evidence,
                                                      graph: g, registry: b.registry, unknownReasons: [])
        XCTAssertNil(ContentDNACandidateV2.mint(from: mixed, identity: snap(122, generation: 2),
                                                currentGeneration: 2, dnaRaw: 3, nowMs: 0, modelVersions: ["m"]),
                     "evidence mixed across identity generations may never mint durable DNA")
    }

    // ── PROBE 4 — NaN editDensity (sanitizer pre-route; §7) ──

    func testA4_NaNEditDensityStrippedBeforeAnyExpert() {
        let b = makeBrain()
        let r = b.route(input: ExpertInputV2(ocrText: "steady slow documentary film", detectedLanguage: "en",
                                             visualLabels: ["studio"], visualConfidence: 0.8,
                                             editDensityCutsPerMinute: .nan),
                        context: ctx(b, item: 130), nowMs: 0)
        for e in r.evidence {
            XCTAssertNil(e.features["editDensity"].flatMap { $0.isNaN ? $0 : nil },
                         "\(e.domain): NaN editDensity must never reach evidence features")
            for (k, v) in e.features { XCTAssertTrue(v.isFinite, "\(e.domain).\(k) leaked non-finite") }
        }
        XCTAssertFalse(r.evidence.flatMap { $0.labels }.contains("attention:rapid-edit-density"),
                       "NaN density may never fabricate a rapid-edit claim")
        XCTAssertTrue(r.unknownReasons.contains("input-sanitized:invalid-edit-density-dropped"),
                      "sanitization is visible, never silent")
    }

    func testA4_FuzzSweepNoNonFiniteNoCrashTimestampDisorder() {
        let b = makeBrain()
        let poisons: [Double] = [.nan, .infinity, -.infinity, -1, 7.5, 1e308, -1e-9]
        var nowSequence: [Double] = [100, 50, 0, 200, 1, 99, 3]                 // deliberate timestamp disorder
        for (i, p) in poisons.enumerated() {
            let input = ExpertInputV2(ocrText: i % 2 == 0 ? "learn now" : nil, detectedLanguage: i % 3 == 0 ? "zz-!!" : "en",
                                      visualLabels: (1...100).map { "l\($0)" }, visualConfidence: p,
                                      soundEvents: (1...100).map { "s\($0)" },
                                      speechTranscript: nil, speechAvailable: i % 2 == 1,
                                      musicPresence: true, musicTempoEnergy: p,
                                      editDensityCutsPerMinute: p, elapsedItemMs: -p)
            let r = b.route(input: input, context: ctx(b, item: i == 0 ? nil : UInt64(140 + i)), nowMs: nowSequence[i])
            for e in r.evidence {
                for (k, v) in e.features { XCTAssertTrue(v.isFinite, "poison \(p) leaked into \(e.domain).\(k)") }
                XCTAssertTrue(e.confidence.isFinite && e.confidence >= 0 && e.confidence <= 1)
            }
        }
        _ = nowSequence.removeLast()
        // after the flood, a clean route still works (no sticky poisoning)
        let clean = b.route(input: ExpertInputV2(ocrText: "learn the science lesson", detectedLanguage: "en"),
                            context: ctx(b, item: 160), nowMs: 300)
        XCTAssertTrue(clean.evidence.flatMap { $0.labels }.contains("benefit:educational-candidate"))
    }

    // ── PROBE 5 — deadline race (late result discarded; lease NOT burned; no-work-past-budget) ──

    func testA4_DeadlineRaceLateHeavyResultDiscardedAndRetryable() {
        var fake = 0.0
        let holder = NSLock()
        let b = GuardianMetaBrainV2(clock: { holder.lock(); defer { holder.unlock() }; return fake })
        struct SlowHeavyExpert: MultimodalExpertV2 {
            let domain: ExpertDomainV2 = .vision
            let availability: ExpertAvailabilityV2 = .realInProcessLabOnly
            let modelVersion = "audit4-slow-heavy"
            let resourceCost: Double = 5                                        // deep: lease engaged
            let burn: @Sendable () -> Void
            func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2 {
                burn()
                return ExpertEvidenceV2(domain: .vision, labels: ["scene:slow"], confidence: 0.6, coverage: 1,
                                        uncertainty: 0.4, itemID: context.itemID, itemProvisional: context.itemProvisional,
                                        provenance: "audit4-slow", modelVersion: "audit4-slow-heavy",
                                        resourceCost: 5, calibrationStatus: .heuristicSupportOnly,
                                        generation: context.generation)
            }
        }
        b.registry.register(SlowHeavyExpert(burn: { holder.lock(); fake += 50; holder.unlock() }))
        // race lost: 50ms of work against a 10ms budget → result lands late → discarded, never attached
        let late = b.route(input: ExpertInputV2(), context: ctx(b, item: 170, domains: [.vision], deadlineMs: 10), nowMs: 0)
        XCTAssertTrue(late.evidence.isEmpty, "late result can never attach")
        XCTAssertTrue(late.unknownReasons.contains { $0.hasPrefix("deadline-late-discarded:VISION") })
        // the lost race must NOT burn the deep lease: a later route with budget analyzes the same item
        let retry = b.route(input: ExpertInputV2(), context: ctx(b, item: 170, domains: [.vision], deadlineMs: 100), nowMs: 1)
        XCTAssertTrue(retry.evidence.flatMap { $0.labels }.contains("scene:slow"),
                      "a deadline-lost attempt is retryable — no permanent per-item blindness")
    }

    func testA4_ExpiredBudgetSchedulesNothingButServesCacheAndKeepsLease() {
        var fake = 0.0
        let holder = NSLock()
        let b = makeBrain(clock: { holder.lock(); defer { holder.unlock() }; return fake })
        _ = b.route(input: ExpertInputV2(ocrText: "learn", detectedLanguage: "en"),
                    context: ctx(b, item: 171, domains: [.languageOCR]), nowMs: 0)          // warm cache
        let r = b.route(input: ExpertInputV2(ocrText: "learn", detectedLanguage: "en",
                                             visualLabels: ["cat"], visualConfidence: 0.9),
                        context: ctx(b, item: 171, domains: [.languageOCR, .vision], deadlineMs: 0), nowMs: 1)
        XCTAssertTrue(r.cacheHits.contains(.languageOCR), "serving cache stays legal past the budget")
        XCTAssertFalse(r.executed.contains(.vision), "no NEW work may be scheduled past the budget")
        XCTAssertTrue(r.unknownReasons.contains { $0.hasPrefix("deadline-expired:VISION") })
        // deadline deferral happens BEFORE the lease — the item is analyzable once budget exists
        XCTAssertEqual(b.governor.leaseState(item: ContentItemID(171), domain: .vision), .notAttempted)
        let ok = b.route(input: ExpertInputV2(visualLabels: ["cat"], visualConfidence: 0.9),
                         context: ctx(b, item: 171, domains: [.vision], deadlineMs: 1000), nowMs: 2)
        XCTAssertTrue(ok.evidence.flatMap { $0.labels }.contains("scene:cat"))
    }

    // ── PROBE 6 — FAIR thermal + deadline pressure (composition + conservation law: nothing vanishes silently) ──

    func testA4_FairThermalPlusDeadlinePressureConservation() {
        final class Ticker: @unchecked Sendable {
            private var t = 0.0; private let lock = NSLock()
            func next() -> Double { lock.lock(); defer { lock.unlock() }; t += 1; return t }
        }
        let ticker = Ticker()
        let b = makeBrain(clock: { ticker.next() })
        b.governor.setThermal(.fair)
        let r = b.route(input: ExpertInputV2(ocrText: "deadly disaster learn now hurry", detectedLanguage: "en",
                                             visualLabels: ["street"], visualConfidence: 0.8,
                                             soundEvents: ["siren"], speechTranscript: "warning", speechAvailable: true,
                                             musicPresence: true, editDensityCutsPerMinute: 60),
                        context: ctx(b, item: 180, deadlineMs: 18), nowMs: 0)
        // FAIR law unchanged under deadline pressure: heavy non-safety arms (cost ≥ 5) defer thermally
        XCTAssertTrue(r.deferredThermal.contains(.vision) && r.deferredThermal.contains(.speech))
        XCTAssertTrue(r.unknownReasons.contains { $0.hasPrefix("thermal-deferred:VISION") })
        // pressure is real: some work ran, some hit the budget — and BOTH are reported
        XCTAssertFalse(r.executed.isEmpty, "the cheapest work still executes under combined pressure")
        XCTAssertTrue(r.unknownReasons.contains { $0.hasPrefix("deadline-expired:") },
                      "budget exhaustion under pressure is reported, never silent")
        // CONSERVATION: every requested domain is accounted for — executed, cache, deferred, unavailable,
        // or named in an UNKNOWN reason. Nothing disappears silently.
        for d in r.requested {
            let accounted = r.executed.contains(d) || r.cacheHits.contains(d) || r.deferredThermal.contains(d)
                || r.unavailable.contains(d) || r.unknownReasons.contains { $0.contains(d.rawValue) }
            XCTAssertTrue(accounted, "domain \(d.rawValue) vanished silently under FAIR+deadline pressure")
        }
        // identity race on top: a context captured before identityChanged() can never attach
        let staleCtx = ctx(b, item: 181, domains: [.safetyEvidence])
        b.identityChanged()
        let r2 = b.route(input: ExpertInputV2(ocrText: "x", detectedLanguage: "en"), context: staleCtx, nowMs: 1)
        XCTAssertTrue(r2.executed.isEmpty)
        XCTAssertTrue(r2.unknownReasons.contains { $0.hasPrefix("stale-discarded:") })
    }

    // ── PROBE 7 — duplicate heavy expert scheduling (one run per route, refusal reported) ──

    func testA4_DuplicateHeavySchedulingCollapsesToOneRun() {
        let b = makeBrain()
        // provisional → no cache; the lease must collapse duplicates inside one route
        let r = b.route(input: ExpertInputV2(visualLabels: ["cat"], visualConfidence: 0.9),
                        context: ctx(b, item: 190, provisional: true, domains: [.vision, .vision, .vision]), nowMs: 0)
        XCTAssertEqual(r.executed.filter { $0 == .vision }.count, 1, "duplicate heavy requests collapse to ONE execution")
        XCTAssertEqual(r.unknownReasons.filter { $0.hasPrefix("deep-dedupe:VISION") }.count, 2,
                       "each refused duplicate is reported")
        // confirmed item: duplicates collapse through cache instead — still exactly one execution
        let r2 = b.route(input: ExpertInputV2(visualLabels: ["dog"], visualConfidence: 0.9),
                         context: ctx(b, item: 191, domains: [.vision, .vision]), nowMs: 1)
        XCTAssertEqual(r2.executed.filter { $0 == .vision }.count, 1)
        XCTAssertEqual(r2.cacheHits.filter { $0 == .vision }.count, 1, "second duplicate served from cache")
    }

    // ── PROBE 8 — corpus near-duplicate detector + split independence + reserved-bank lock ──

    func testA4_CorpusSplitIndependenceAndDetectorSelfTest() {
        // the real banks are clean
        XCTAssertEqual(CorpusSplitLeakageAuditorV1.audit(), [])
        // counts match the builder's claims and the eval docs
        XCTAssertEqual(P009BCorpusV2.scenarios(.tune).count, 24)
        XCTAssertEqual(P009BCorpusV2.scenarios(.heldOut).count, 16)
        XCTAssertEqual(P009BCorpusV2.scenarios(.stress).count, 10)
        XCTAssertEqual(P009BCorpusV2.scenarios(.ood).count, 8)
        XCTAssertEqual(P009BCorpusV2.scenarios(.calibrationReserved).count, 6)
        // the DETECTOR itself works — plant an exact duplicate (seed-alias style) and a near-duplicate
        let tune = P009BCorpusV2.scenarios(.tune).first { $0.name == "t-text-only-en" }!
        let exactCopy = P009BScenarioV1(name: "planted-exact", family: "probe", input: tune.input,
                                        expectEvidencePrefixes: [], forbidEvidencePrefixes: [],
                                        expectContradiction: false, expectAbstention: false)
        XCTAssertEqual(CorpusSplitLeakageAuditorV1.canonical(tune), CorpusSplitLeakageAuditorV1.canonical(exactCopy),
                       "exact-duplicate rule fires on byte-identical canonical forms")
        let nearCopy = P009BScenarioV1(name: "planted-near", family: "probe",
            input: ExpertInputV2(ocrText: "Learn how to build a birdhouse: step by step guide now", detectedLanguage: "en"),
            expectEvidencePrefixes: [], forbidEvidencePrefixes: [], expectContradiction: false, expectAbstention: false)
        let j = CorpusSplitLeakageAuditorV1.jaccard(CorpusSplitLeakageAuditorV1.tokens(tune),
                                                    CorpusSplitLeakageAuditorV1.tokens(nearCopy))
        XCTAssertGreaterThan(j, CorpusSplitLeakageAuditorV1.nearDuplicateJaccardThreshold)
        XCTAssertEqual(CorpusSplitLeakageAuditorV1.modalityCombo(tune), CorpusSplitLeakageAuditorV1.modalityCombo(nearCopy),
                       "…and the same-modality-combo condition holds, so audit() would flag it")
        // a genuinely different scenario does NOT trip the rule (no false-positive hair trigger)
        let heldOut = P009BCorpusV2.scenarios(.heldOut).first { $0.name == "h-text-only-tr" }!
        XCTAssertLessThan(CorpusSplitLeakageAuditorV1.jaccard(CorpusSplitLeakageAuditorV1.tokens(tune),
                                                              CorpusSplitLeakageAuditorV1.tokens(heldOut)),
                          CorpusSplitLeakageAuditorV1.nearDuplicateJaccardThreshold)
    }

    func testA4_CalibrationReservedBankContentLocked() {
        // lock the reserved bank CONTENT to the published fingerprint — any drift is contamination evidence
        XCTAssertEqual(CorpusSplitLeakageAuditorV1.reservedBankFingerprint(), "aa6bd546ae28278f",
                       "CALIBRATION_RESERVED content must match the published reservation fingerprint")
        // and nothing in the reserved bank carries gate expectations (it is reserved, not a hidden gate)
        for s in P009BCorpusV2.scenarios(.calibrationReserved) {
            XCTAssertTrue(s.expectEvidencePrefixes.isEmpty && s.forbidEvidencePrefixes.isEmpty)
        }
    }

    // ── PROBE 9 — malformed provenance / licensing (never invented, unclear never ships) ──

    func testA4_MalformedProvenanceAndUnclearLicenseRefused() {
        // V1 law: unclear license is constructor-forced to NOT approved
        let unclear = ExternalIntelligenceAssetAuditV1(assetName: "mystery-model", provider: "unknown",
                                                       licenseClass: .unclearDoNotIntegrate,
                                                       licenseEvidence: "none found", provenance: "unknown origin",
                                                       auditedAtISO8601: "2026-10-19")
        XCTAssertFalse(unclear.integrationApproved, "§19: unclear license/provenance can never be approved")
        // V2 law: same gate; and OS frameworks use sentinels instead of invented facts
        for r in P009BAssetAuditLedgerV2.records where r.licenseClass == .appleSystemFramework {
            XCTAssertTrue(r.trainingDataProvenance.contains(ExternalIntelligenceAssetAuditV2.notApplicableOS),
                          "\(r.assetName): training-data provenance must be a sentinel, never invented")
            XCTAssertTrue(r.weightsLicense.contains(ExternalIntelligenceAssetAuditV2.notApplicableOS))
            XCTAssertTrue(r.warmMemory == ExternalIntelligenceAssetAuditV2.notMeasured
                          || !r.warmMemory.isEmpty)
        }
        XCTAssertTrue(P009BAssetAuditLedgerV2.allIntegrationsLawful)
        XCTAssertEqual(P009BAssetAuditLedgerV2.records.count, 6, "complete ledger: 4 Apple frameworks + 2 project assets")
        // runtime provenance is never invented either: an unknown subject has an EMPTY trace
        XCTAssertTrue(ProvenanceLedgerV2().trace(subject: "item:999999").isEmpty)
    }

    // ── PROBE 10 — score/glyph OFF + H1/child honesty + availability truth (regression guards) ──

    func testA4_ScoreOffH1HonestAvailabilityTruth() {
        let b = makeBrain()
        // score display structurally impossible
        XCTAssertFalse(b.calibration.scoreDisplayAllowed())
        for d in ExpertDomainV2.allCases {
            XCTAssertFalse(b.calibration.isCalibrated(domain: d, language: "en"))
            XCTAssertFalse(b.calibration.isCalibrated(domain: d, language: "tr"))
            // F5: every arm honestly LAB_ONLY until production wiring + device proof exist
            XCTAssertEqual(b.registry.availability(d), .realInProcessLabOnly)
        }
        // H1 honesty: EVERY safety evidence record carries the explicit visual-dimensions blocker…
        let r = b.route(input: ExpertInputV2(ocrText: "calm words only", detectedLanguage: "en"),
                        context: ctx(b, item: 200, domains: [.safetyEvidence]), nowMs: 0)
        let safety = r.evidence.filter { $0.domain == .safetyEvidence }
        XCTAssertFalse(safety.isEmpty)
        for e in safety {
            XCTAssertTrue(e.labels.contains("safety:H1-visual-dimensions:UNAVAILABLE"))
            // …and absence of lexical signal is never a safe verdict
            if !e.labels.contains(where: { $0.hasPrefix("safety:sensitive") || $0.hasPrefix("safety:fear") }) {
                XCTAssertTrue(e.labels.contains { $0.contains("NOT a safe verdict") })
            }
        }
    }
}
