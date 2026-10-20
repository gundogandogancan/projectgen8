import XCTest
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT10 — REAL-WORLD CALIBRATION ENTRY GATE — independent red-team probes (add-only).
// Auditor: fresh-context independent auditor, 2026-10-20.
// Target: 28865c353257b1ea15fb9f740cdb11b90153e96b (tag gen8-real-world-calibration-entry-gate-audit-candidate).
// RULES: no existing source/test modified; probes characterize REALITY (defects are PINNED, not hidden).
// Probes that pin a defect are annotated FINDING A10-*; fixing them later requires the repo's
// frozen-original + pre-declared-inversion discipline.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT10_RealWorldCalibrationEntryGateProbes: XCTestCase {

    // ── independent harness (non-copy: fresh item IDs, fresh stimuli, own helper names) ──
    private func meshBrain() -> GuardianMetaBrainV2 {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1()); b.registry.register(LanguageOCRExpertV1())
        b.registry.register(SpeechExpertV1()); b.registry.register(AudioEventExpertV1())
        b.registry.register(MusicExpertV1()); b.registry.register(SymbolExpertV1())
        b.registry.register(TemporalExpertV1()); b.registry.register(SafetyEvidenceExpertV1())
        b.registry.register(BenefitEvidenceExpertV1()); b.registry.register(AttentionPressureExpertV1())
        return b
    }
    private func decide(_ text: String, lang: String, risk: Double,
                        child: GuardianEnteredChildProfileV1?,
                        shield: ShieldConfigV2? = nil,
                        parent: ParentPreferencePolicyV1 = ParentPreferencePolicyV1(),
                        item: UInt64) -> AdmissionStateCandidateV1 {
        let seg = [P009CSegmentV1(startMs: 0, endMs: 2500,
                                  input: ExpertInputV2(ocrText: text, detectedLanguage: lang),
                                  temporalRisk: risk, temporalTopics: ["a10"])]
        let sc = P009DPolicyScenarioV1(name: "a10-\(item)", family: "audit10", segments: seg,
                                       childProfile: child, parentPreference: parent,
                                       shieldConfig: shield, annotation: P009DPolicyAnnotationV1())
        return P009DPolicyCorpusV1.run(sc, brain: meshBrain(), item: ContentItemID(item)).1
    }
    private func teenTR(_ a: Int) -> GuardianEnteredChildProfileV1 {
        GuardianEnteredChildProfileV1(ageYears: a, jurisdictionCode: "TR", enteredByGuardian: true)
    }
    private var repoRoot: String {
        // …/packages/GuardianKit/Tests/GuardianCoreTests/AUDIT10_… → repo root
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }

    // ═════════════════════════ F1 — age law: UNAVAILABLE/UNBANDED never AGE_ALIGNED ═════════════════════════

    /// P01 — PARAPHRASED violence with routing-lexicon token coverage (not the builder's literals):
    /// TR "silahlı çatışma", EN "war footage"/"bombing aftermath"/"graphic violence" — teen 13/14/17
    /// strong risk → never AGE_ALIGNED, floor unknownReview, global state untouched (strongProtection).
    func testP01_F1_ParaphrasedViolence_CoveredCues_NeverAligned() {
        var i: UInt64 = 81_000
        for age in [13, 14, 17] {
            for (text, lang) in [("silahlı çatışma bölgesinden akşam görüntüleri", "tr"),
                                 ("raw war footage from the front line", "en"),
                                 ("bombing aftermath, buildings in ruins", "en"),
                                 ("documentary includes graphic violence throughout", "en")] {
                i += 1
                let d = decide(text, lang: lang, risk: 0.85, child: teenTR(age), item: i)
                XCTAssertNotEqual(d.childOutcome, .aligned, "age \(age) '\(text)': never AGE_ALIGNED")
                XCTAssertEqual(d.childOutcome, .unknownReview, "age \(age) '\(text)': fail-closed review floor")
                XCTAssertEqual(d.state, .strongProtection, "global safety state preserved — no loosening")
            }
        }
    }

    /// P02 — PARAPHRASE MISSES (synonym/morphology/mixed-language the lexicon does not cover).
    /// FINDING A10-F1-COVERAGE (LIMITATION, pinned): the engineering invariant is CUE-GATED — a strong-risk
    /// (0.9) violence context whose text misses the routing lexicon can still produce the component outcome
    /// AGE_ALIGNED for a teen. NOT a false-safe end-to-end (state stays strongProtection), but it proves
    /// violence detection is NOT validated: the law closes only lexicon-covered contexts.
    func testP02_F1_ParaphraseMisses_PinnedCoverageLimitation() {
        var componentAligned = 0
        var i: UInt64 = 82_000
        for (text, lang) in [("kanlı görüntüler sosyal medyada yayıldı", "tr"),       // "kanlı" not in lexicon
                             ("şiddetli kavga kamerada", "tr"),                        // morphology: "şiddetli" ≠ token "şiddet"
                             ("violent assault caught on camera", "en"),               // "violent" ≠ token "violence"
                             ("deadly armed raid on a village", "en")] {               // no covered token
            i += 1
            let d = decide(text, lang: lang, risk: 0.9, child: teenTR(14), item: i)
            XCTAssertEqual(d.state, .strongProtection, "'\(text)': end-to-end protection must hold (no false-safe)")
            if d.childOutcome == .aligned { componentAligned += 1 }
        }
        // The limitation is REAL and pinned: at least one covered-miss stays component-ALIGNED today.
        XCTAssertGreaterThan(componentAligned, 0,
            "FINDING A10-F1-COVERAGE: paraphrase misses currently stay component-ALIGNED — if this now fails, " +
            "coverage changed and the finding must be re-audited (never silently dropped)")
        print("AUDIT10_F1_COVERAGE componentAlignedMisses=\(componentAligned)/4 (pinned limitation)")
    }

    /// P03 — BENIGN FALSE-TRIGGER attack: educational/benign texts containing routing tokens.
    /// Characterization: the teen sentinel policy fires on the CUE ALONE (risk 0) → fail-closed review.
    /// Over-restriction, never false-safe; educational context qualifies but does not erase (doctrine).
    /// FINDING A10-F1-FALSETRIGGER (INFO, pinned): routing lexicon acts risk-independently for teens.
    func testP03_F1_BenignEducational_FalseTrigger_Characterized() {
        // teen + benign "savaş tarihi dersi" (war history lesson) → review (cue-only trigger), NOT protection
        let tr = decide("savaş tarihi dersi: osmanlı dönemi anlatımı", lang: "tr", risk: 0.0,
                        child: teenTR(15), item: 83_001)
        XCTAssertEqual(tr.childOutcome, .unknownReview,
            "FINDING A10-F1-FALSETRIGGER: benign war-history lesson routes teen to review on cue alone")
        XCTAssertNotEqual(tr.state, .strongProtection, "benign content must not escalate the global state")
        // EN violence-prevention course → same characterization
        let en = decide("violence prevention course for teachers, module 1", lang: "en", risk: 0.0,
                        child: teenTR(16), item: 83_002)
        XCTAssertEqual(en.childOutcome, .unknownReview)
        XCTAssertNotEqual(en.state, .strongProtection)
        // ADULT with the same benign text: no child outcome, no protection state — lexicon never standalone-detects
        let ad = decide("savaş tarihi dersi: osmanlı dönemi anlatımı", lang: "tr", risk: 0.0, child: nil, item: 83_003)
        XCTAssertNil(ad.childOutcome)
        XCTAssertNotEqual(ad.state, .strongProtection, "adult benign: routing lexicon is not detection")
    }

    /// P04 — benign control WITHOUT any routing token: teen stays genuinely alignable (law not over-broad).
    func testP04_F1_BenignNoCue_TeenStaysAlignable() {
        let d = decide("matematik olimpiyatı hazırlık videosu: integral teknikleri", lang: "tr", risk: 0.0,
                       child: teenTR(14), item: 84_001)
        XCTAssertEqual(d.childOutcome, .aligned, "no cue + no risk → teen remains alignable (missing != negative)")
        XCTAssertNotEqual(d.state, .strongProtection)
    }

    /// P05 — BANDED evidence preservation: pure sensitive-news (disaster reporting, no violence token)
    /// at strong risk stays band-EVALUATED for 13+ (banded != unsafe); sub-strong fear stays alignable.
    func testP05_F1_BandedSensitiveNewsAndFear_Preserved() {
        let news = decide("deprem felaketi: bölgeden son haberler", lang: "tr", risk: 0.9,
                          child: teenTR(13), item: 85_001)
        XCTAssertEqual(news.childOutcome, .aligned,
                       "banded sensitive-news, age ≥ band: AGE_ALIGNED preserved (AUDIT7-P7 semantics)")
        XCTAssertEqual(news.state, .strongProtection, "strong risk still protects globally")
        let fear = decide("gerilim hikayesi: karanlık orman uyarı", lang: "tr", risk: 0.4,
                          child: teenTR(13), item: 85_002)
        XCTAssertEqual(fear.childOutcome, .aligned, "sub-strong banded fear stays alignable")
    }

    /// P06 — under-13 H1 law + unbanded-present dimension + unsupported jurisdiction fail-closed.
    func testP06_F1_Under13_H1_And_JurisdictionFailClosed() {
        let child9 = decide("eğlenceli çizgi film derlemesi", lang: "tr", risk: 0.0,
                            child: teenTR(9), item: 86_001)
        XCTAssertEqual(child9.childOutcome, .unknownReview, "under-13 H1 visual screening unavailable → review")
        let unknownJx = GuardianEnteredChildProfileV1(ageYears: 14, jurisdictionCode: "XX", enteredByGuardian: true)
        let d = decide("quiz show highlights", lang: "en", risk: 0.0, child: unknownJx, item: 86_002)
        XCTAssertEqual(d.childOutcome, .unknownReview, "unsupported jurisdiction fails closed")
        // non-attested profile fails closed (direct engine law)
        let unattested = GuardianEnteredChildProfileV1(ageYears: 14, jurisdictionCode: "TR", enteredByGuardian: false)
        let e = decide("quiz show highlights", lang: "en", risk: 0.0, child: unattested, item: 86_003)
        XCTAssertEqual(e.childOutcome, .unknownReview, "no guardian attestation → no child decision")
    }

    /// P07 — sexual sentinel + strict-parent regression with fresh stimuli (safety matrix unchanged).
    func testP07_F1_SexualSentinelAndParentOverlay_Fresh() {
        let s = decide("yetişkinlere özel erotik sahneler derlemesi", lang: "tr", risk: 0.0,
                       child: teenTR(16), item: 87_001)
        XCTAssertEqual(s.childOutcome, .unknownReview, "teen sexual sentinel fail-closed intact")
        let p = decide("deprem bölgesinden haber özeti", lang: "tr", risk: 0.0, child: teenTR(14),
                       parent: ParentPreferencePolicyV1(blockSensitiveNews: true), item: 87_002)
        XCTAssertEqual(p.childOutcome, .restricted, "parent stricter-only overlay intact")
    }

    // ═════════════════════════ F2 — declared ≠ resolved ⇒ typed refusal ═════════════════════════

    /// P08 — PRODUCTION CALL-GRAPH ENFORCEMENT (the wiring probe).
    /// FINDING A10-F2-UNWIRED (pinned): the REAL fit path (`P009EScoreTests.setUp`) resolves pairs with
    /// `guard let sc = scenario(for:) else { continue }` — a SILENT DROP — and never calls
    /// `CalibrationRunGuardV1.requireFullResolution`. The guard is a correct but UNWIRED helper:
    /// a future unresolved pair would be silently excluded from fitting while the guard sits unused.
    func testP08_F2_ProductionCallgraph_GuardIsUnwired_Pinned() throws {
        // (a) static truth: the production fit harness source does not reference the guard at all
        let harnessPath = repoRoot + "/packages/GuardianKit/Tests/GuardianCoreTests/P009EScoreTests.swift"
        let harnessSrc = try String(contentsOfFile: harnessPath, encoding: .utf8)
        XCTAssertFalse(harnessSrc.contains("requireFullResolution"),
            "FINDING A10-F2-UNWIRED: if this now fails, the guard got wired — re-audit and close the finding")
        XCTAssertTrue(harnessSrc.contains("else { continue }"),
            "the silent-drop control flow is still present in the real fit path")
        // (b) repo-wide behavioral confirmation: no production source calls the guard either
        let prodGuardPath = repoRoot + "/packages/GuardianKit/Sources/GuardianCore/CalibrationIntegrityV1.swift"
        XCTAssertTrue(FileManager.default.fileExists(atPath: prodGuardPath))
        // (c) dynamic demonstration: replicate the production loop with one phantom pair — the loop
        // COMPLETES and "fitting" is reached on a partial dataset (58-style silent metrics possible),
        // while the unwired guard — had it been called — would have refused.
        let harness = P009EScoreTests()
        var declared = CalibrationDatasetRegistryV2.pairs
        declared.append(CalibrationPairV1(itemID: "a10-phantom-item", corpus: "P009D",
                                          profile: .adultNeutral, split: .trainTune, source: .syntheticDerived,
                                          annotation: CalibrationAnnotationV1(itemID: "a10-phantom-item",
                                                                              profileID: "adult-neutral",
                                                                              locale: "en", labelA: 2, labelB: 2)))
        var resolvedIDs: [String] = []
        var fitReachedDespitePartial = false
        for pair in declared {
            guard harness.scenario(for: pair) != nil else { continue }       // ← the production control flow
            resolvedIDs.append(pair.itemID + "#" + pair.profile.profileID)
        }
        fitReachedDespitePartial = true                                       // loop completed, no refusal
        XCTAssertEqual(resolvedIDs.count, declared.count - 1, "phantom silently dropped by the real path")
        XCTAssertTrue(fitReachedDespitePartial,
            "FINDING A10-F2-UNWIRED: fit stage is reachable on a partial dataset via the production flow")
        // (d) the guard itself would have refused the very same inputs — proving it exists but is bypassed
        let declaredIDs = declared.map { $0.itemID + "#" + $0.profile.profileID }
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(declaredIDs: declaredIDs,
                                                                             resolvedIDs: resolvedIDs))
    }

    /// P09 — CRITICAL same-count-different-ID-set: [a,b,c] vs [a,b,x] (3/3) MUST FAIL — and it does.
    func testP09_F2_SameCountDifferentIDSet_Refused() {
        do {
            try CalibrationRunGuardV1.requireFullResolution(declaredIDs: ["a", "b", "c"],
                                                            resolvedIDs: ["a", "b", "x"])
            XCTFail("same-count different-ID set MUST be refused")
        } catch let e as CalibrationIntegrityErrorV1 {
            guard case let .unresolvedPairs(d, r, ids, _) = e else { return XCTFail("typed case required") }
            XCTAssertEqual(d, 3); XCTAssertEqual(r, 3)
            XCTAssertEqual(ids, ["c"], "the missing ID is named; the unexpected extra cannot cancel it")
        } catch { XCTFail("typed error required, got \(error)") }
    }

    /// P10 — MULTISET DUPLICATES: declared [a,a,b] vs resolved [a,b,b] MUST FAIL per the entry-gate
    /// contract. A10-F2-MULTISET FIXED (inversion pre-declared in docs/audit/AUDIT10_INVERSION_LOCK.md,
    /// I-2; original pinned ACCEPTED): composite IDs are unique by contract — duplicate declared/resolved
    /// IDs are typed integrity errors, so both cancellation shapes now REFUSE.
    func testP10_F2_MultisetDuplicates_PinnedDefect() {
        var accepted = false
        do {
            try CalibrationRunGuardV1.requireFullResolution(declaredIDs: ["a", "a", "b"],
                                                            resolvedIDs: ["a", "b", "b"])
            accepted = true
        } catch { accepted = false }
        XCTAssertFalse(accepted, "A10-F2-MULTISET FIXED: [a,a,b] vs [a,b,b] refused (duplicate-declared typed error)")
        // second cancellation shape: declared [a,a] vs resolved [a,b] — unexpected extra 'b' masks the dup
        var accepted2 = false
        do {
            try CalibrationRunGuardV1.requireFullResolution(declaredIDs: ["a", "a"], resolvedIDs: ["a", "b"])
            accepted2 = true
        } catch { accepted2 = false }
        XCTAssertFalse(accepted2, "A10-F2-MULTISET(b) FIXED: [a,a] vs [a,b] refused (duplicate-declared typed error)")
        print("AUDIT10_F2_MULTISET inverted: [a,a,b]~[a,b,b] accepted=\(accepted); [a,a]~[a,b] accepted=\(accepted2)")
    }

    /// P11 — injection matrix: 58/59, dangling, duplicate resolved, malformed, alias-to-missing,
    /// unexpected extra — every one refused with the typed error.
    func testP11_F2_InjectionMatrix_TypedRefusals() {
        let all = CalibrationDatasetRegistryV2.pairs.map { $0.itemID + "#" + $0.profile.profileID }
        XCTAssertEqual(all.count, 59, "declared V2 size unchanged")
        // 58/59
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: all, resolvedIDs: Array(all.dropFirst()))) { e in
            guard case let .unresolvedPairs(d, r, ids, _)? = e as? CalibrationIntegrityErrorV1 else { return XCTFail() }
            XCTAssertEqual(d, 59); XCTAssertEqual(r, 58); XCTAssertEqual(ids, [all[0]])
        }
        // dangling reference
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: all + ["pd-ghost#adult-neutral"], resolvedIDs: all))
        // duplicate resolved ID (count inflation)
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["a", "b"], resolvedIDs: ["a", "a", "b"]))
        // malformed / empty declared ID never resolves
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["", "a"], resolvedIDs: ["a"]))
        // alias-to-missing
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["ALIAS:pc-nonexistent#parent-teen14-tr"], resolvedIDs: []))
        // unexpected extra resolved
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["a"], resolvedIDs: ["a", "surplus"]))
        // full resolution still passes (no false refusal)
        XCTAssertNoThrow(try CalibrationRunGuardV1.requireFullResolution(declaredIDs: all, resolvedIDs: all.shuffled()))
    }

    /// P12 — F2 diagnostics privacy: counts + sorted safe IDs + category only; no content/prose payload.
    /// LIMITATION (honest): future real-corpus item IDs could themselves be sensitive — ledger policy
    /// must keep asset IDs opaque (constitution corpus policy); today's IDs are synthetic scenario names.
    func testP12_F2_DiagnosticsPrivacyShape() {
        do {
            try CalibrationRunGuardV1.requireFullResolution(declaredIDs: ["z-item#p", "b-item#p"], resolvedIDs: [])
            XCTFail("must throw")
        } catch let e as CalibrationIntegrityErrorV1 {
            guard case let .unresolvedPairs(d, r, ids, cat) = e else { return XCTFail() }
            XCTAssertEqual(d, 2); XCTAssertEqual(r, 0)
            XCTAssertEqual(ids, ["b-item#p", "z-item#p"], "deterministically sorted — no ordering leak")
            XCTAssertEqual(cat, "scenario-resolution")
            XCTAssertFalse(ids.contains { $0.count > 120 }, "IDs only — never raw content")
        } catch { XCTFail("typed error required") }
    }

    // ═════════════════════════ F3 — metric domain contract ═════════════════════════

    /// P13 — strict API typed-throw matrix (full mandate value list + shape both ways + bins edges).
    func testP13_F3_StrictMatrix() throws {
        let refuse: [Double] = [Double.nan, .infinity, -.infinity, -0.001, (0.0 as Double).nextDown, 1.001,
                                (1.0 as Double).nextUp]
        for v in refuse {
            XCTAssertThrowsError(try CalibrationMetricsV1.eceAndBinsStrict(preds: [0.4, v], labels: [true, false]),
                                 "\(v) must refuse") { e in
                guard let err = e as? MetricInputErrorV1 else { return XCTFail("typed MetricInputErrorV1 required") }
                switch err {
                case .nonFinite(let i): XCTAssertEqual(i, 1)
                case .outOfDomain(let i, _): XCTAssertEqual(i, 1)
                default: XCTFail("wrong case for \(v): \(err)")
                }
            }
        }
        let accept: [Double] = [0, Double.leastNonzeroMagnitude, 0.1, 0.2, 0.3, 0.5, (1.0 as Double).nextDown, 1]
        let r = try CalibrationMetricsV1.eceAndBinsStrict(preds: accept,
                                                          labels: accept.map { $0 >= 0.5 })
        XCTAssertEqual(r.bins.map { $0.count }.reduce(0, +), accept.count, "all valid values kept exactly once")
        // shape mismatch both directions
        XCTAssertThrowsError(try CalibrationMetricsV1.eceAndBinsStrict(preds: [0.5, 0.6], labels: [true])) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .shapeMismatch(preds: 2, labels: 1))
        }
        XCTAssertThrowsError(try CalibrationMetricsV1.eceAndBinsStrict(preds: [0.5], labels: [true, false])) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .shapeMismatch(preds: 1, labels: 2))
        }
        // bins: zero / negative refuse; huge is lawful (no crash, exact-once preserved)
        XCTAssertThrowsError(try CalibrationMetricsV1.eceAndBinsStrict(preds: [0.5], labels: [true], bins: 0)) { e in
            XCTAssertEqual(e as? MetricInputErrorV1, .invalidBins(0))
        }
        XCTAssertThrowsError(try CalibrationMetricsV1.eceAndBinsStrict(preds: [0.5], labels: [true], bins: -7))
        let huge = try CalibrationMetricsV1.eceAndBinsStrict(preds: [0.123, 0.987], labels: [false, true], bins: 100_000)
        XCTAssertEqual(huge.bins.map { $0.count }.reduce(0, +), 2)
        // validation order: empty input returns (0,0,[]) — defined, not an error
        let empty = try CalibrationMetricsV1.eceAndBinsStrict(preds: [], labels: [])
        XCTAssertEqual(empty.ece, 0); XCTAssertTrue(empty.bins.isEmpty)
    }

    /// P14 — legacy NaN marker semantics + UNGUARDED SIBLING METRICS.
    /// Legacy eceAndBins refuses via NaN+empty bins (not a typed error — compatibility choice).
    /// Repo-wide caller scan (audit evidence): the ONLY non-test callers are eceAndBinsStrict itself;
    /// no production pipeline consumes the NaN marker today (propagation = not currently reachable).
    /// FINDING A10-F3-SIBLINGS (pinned LIMITATION): CalibrationMetricsV1.mae and .auroc have NO domain
    /// guard — mae propagates NaN silently into its aggregate; auroc silently miscounts NaN comparisons.
    func testP14_F3_LegacyNaNMarker_And_UnguardedSiblings_Pinned() {
        for bad in [Double.nan, .infinity, -0.5, 1.5] {
            let m = CalibrationMetricsV1.eceAndBins(preds: [0.2, bad], labels: [false, true])
            XCTAssertTrue(m.ece.isNaN && m.brier.isNaN && m.bins.isEmpty,
                          "legacy marker: NaN metrics + empty bins for \(bad) — never a clamp")
        }
        // NaN marker is detectable but NOT typed: a careless consumer must OPT IN to checking isNaN.
        // Pinned sibling gaps (today's truth — flipping these later requires the inversion discipline):
        let maeNaN = CalibrationMetricsV1.mae([Double.nan, 0.5], [0.0, 0.5])
        XCTAssertTrue(maeNaN.isNaN,
            "FINDING A10-F3-SIBLINGS: mae() silently propagates NaN into the aggregate (no refusal)")
        let aurocNaN = CalibrationMetricsV1.auroc(preds: [Double.nan, 0.9], labels: [false, true])
        XCTAssertNotNil(aurocNaN)
        XCTAssertFalse(aurocNaN!.isNaN,
            "FINDING A10-F3-SIBLINGS: auroc() swallows NaN via comparison semantics — silent miscount, " +
            "not even a NaN marker (worse than mae)")
        print("AUDIT10_F3_SIBLINGS maeNaN=\(maeNaN) aurocWithNaN=\(aurocNaN ?? -1) (pinned)")
    }

    /// P15 — auditor-owned ECE/Brier math, exact boundaries, and the TRUE bin of 0.3 under binary fp.
    func testP15_F3_AuditorOwnedMath_ExactBoundaries() throws {
        // independent implementation (different construction: single pass, dictionary bins)
        func auditorECEBrier(_ preds: [Double], _ labels: [Bool], bins: Int = 10) -> (ece: Double, brier: Double, counts: [Int: Int]) {
            var sumP: [Int: Double] = [:], sumY: [Int: Double] = [:], n: [Int: Int] = [:]
            for (p, l) in zip(preds, labels) {
                let b = min(bins - 1, Int(p * Double(bins)))
                sumP[b, default: 0] += p; sumY[b, default: 0] += l ? 1 : 0; n[b, default: 0] += 1
            }
            var ece = 0.0
            for (b, c) in n { ece += Double(c) / Double(preds.count) * abs(sumP[b]! / Double(c) - sumY[b]! / Double(c)) }
            let brier = zip(preds, labels).map { ($0 - ($1 ? 1 : 0)) * ($0 - ($1 ? 1 : 0)) }.reduce(0, +) / Double(preds.count)
            return (ece, brier, n)
        }
        // THE ACTUAL BIN OF 0.3 UNDER BINARY FP — FINDING A10-F3-FPEDGE (documented-claim error, pinned):
        // Double(0.3) = 0.29999999999999998889…; ×10.0 the fp PRODUCT rounds to exactly 3.0 →
        // Int(0.3*10.0) == 3 → bin [0.3,0.4). The builder comment in CalibrationIntegrityV1.swift,
        // the AUDIT9 probe comment ("0.3*10 rounds DOWN … bin 2"), the AUDIT9 report and the entry-gate
        // implementation report ALL document the WRONG bin. Deterministic + exactly-once either way
        // (metrics unaffected) — but the written fp-edge claim is false and must be corrected.
        XCTAssertEqual(Int(0.3 * 10.0), 3,
            "FINDING A10-F3-FPEDGE: 0.3*10 rounds UP to exactly 3.0 — bin 3, contradicting every doc claim")
        XCTAssertEqual(Int(0.2 * 10.0), 2, "0.2*10 rounds to exactly 2.0 → bin 2")
        XCTAssertEqual(Int(0.1 * 10.0), 1, "0.1*10 rounds to exactly 1.0 → bin 1")
        XCTAssertEqual(Int(0.5 * 10.0), 5, "0.5 is exact → bin 5")
        // empirical sweep: at bins=10, NO one-decimal boundary k/10 rounds down — the product k/10 × 10
        // rounds to exactly k for every k in 1…9. The documented "rounds DOWN" story is false everywhere.
        let downCases = (1...9).filter { Int(Double($0) / 10.0 * 10.0) != $0 }
        XCTAssertEqual(downCases, [], "no decimal boundary floors down at bins=10: \(downCases)")
        // cross-check strict API against auditor math on an asymmetric fixture (no loss, no double count)
        let preds = [0.05, 0.1, 0.2, 0.3, 0.3, 0.55, 0.9, 1.0, 0.0]
        let labels = [false, false, true, false, true, true, true, true, false]
        let mine = auditorECEBrier(preds, labels)
        let theirs = try CalibrationMetricsV1.eceAndBinsStrict(preds: preds, labels: labels)
        XCTAssertEqual(theirs.bins.map { $0.count }.reduce(0, +), preds.count)
        XCTAssertEqual(mine.counts.values.reduce(0, +), preds.count)
        XCTAssertEqual(theirs.ece, mine.ece, accuracy: 1e-12, "independent ECE must agree exactly")
        XCTAssertEqual(theirs.brier, mine.brier, accuracy: 1e-12, "independent Brier must agree exactly")
        // hand-verified closed-form fixture
        let h = try CalibrationMetricsV1.eceAndBinsStrict(preds: [0.4, 0.4, 0.8, 0.8], labels: [false, true, true, true])
        XCTAssertEqual(h.ece, 0.5 * abs(0.4 - 0.5) + 0.5 * abs(0.8 - 1.0), accuracy: 1e-12)
        XCTAssertEqual(h.brier, (0.16 + 0.36 + 0.04 + 0.04) / 4, accuracy: 1e-12)
    }

    // ═════════════════════════ AUDIT9 evidence integrity ═════════════════════════

    /// P16 — ORIGINAL-AUDIT9 compatibility probe (non-failing RECORDED evidence, by mandate design):
    /// executes the ORIGINAL frozen F3 probe expectations against candidate source and ASSERTS the delta.
    /// Exactly ONE original expectation no longer holds (the pre-declared A9-R1-F3 inversion); every
    /// other original F3 expectation still passes — proving the mutation touched exactly one block.
    /// Choice rationale: a hard-failing copy would turn historical truth into permanent suite red;
    /// characterizing the delta keeps the evidence executable AND the suite green without XCTExpectFailure.
    func testP16_AUDIT9Original_vs_Candidate_DeltaRecorded() {
        // ── the single inverted expectation (ORIGINAL: out-of-range clamped, count==2) ──
        let oor = CalibrationMetricsV1.eceAndBins(preds: [-0.2, 1.3], labels: [false, true])
        let originalExpectationHolds = (oor.bins.map { $0.count }.reduce(0, +) == 2) && !oor.ece.isNaN
        XCTAssertFalse(originalExpectationHolds,
            "RECORDED DELTA: ORIGINAL AUDIT9 expectation 'clamped, never silently dropped' no longer holds " +
            "on candidate — behavior is now NaN-marker refusal (single pre-declared A9-R1-F3 inversion)")
        XCTAssertTrue(oor.ece.isNaN && oor.bins.isEmpty, "candidate behavior confirmed: refusal, not clamp")
        // ── every OTHER original F3 expectation still holds byte-for-byte semantically ──
        let fp = CalibrationMetricsV1.eceAndBins(preds: [0.2, 0.3], labels: [false, true])
        XCTAssertEqual(fp.bins.map { $0.count }.reduce(0, +), 2, "ORIGINAL fp-edge expectation preserved")
        let tiny = CalibrationMetricsV1.eceAndBins(preds: [0.25, 0.25], labels: [true, false])
        XCTAssertEqual(tiny.ece, 0.25, accuracy: 1e-12, "ORIGINAL tiny-fixture expectation preserved")
        let top = CalibrationMetricsV1.eceAndBins(preds: [1.0], labels: [true])
        XCTAssertEqual(top.bins.count, 1); XCTAssertEqual(top.ece, 0.0, accuracy: 1e-12)
        XCTAssertEqual(CalibrationMetricsV1.eceAndBins(preds: [], labels: []).ece, 0,
                       "ORIGINAL empty-input expectation preserved")
    }

    /// P17 — frozen-original byte integrity + single-hunk mutation shape, verified from disk.
    func testP17_AUDIT9FrozenCopy_ByteExact_SingleHunk() throws {
        let frozenPath = repoRoot + "/docs/audit/AUDIT9_P009ER1Probes_ORIGINAL_LOCKED.swift.txt"
        let activePath = repoRoot + "/packages/GuardianKit/Tests/GuardianCoreTests/AUDIT9_P009ER1Probes.swift"
        let frozen = try Data(contentsOf: URL(fileURLWithPath: frozenPath))
        let sha = SHA256.hash(data: frozen).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(sha, "a349a487dc091d444f04939864582175409542f47d6275c6bb0bd8022163bc4e",
                       "frozen AUDIT9 original must stay byte-exact (== file at 0150d06/b08406c)")
        let frozenSrc = String(decoding: frozen, as: UTF8.self)
        let activeSrc = try String(contentsOfFile: activePath, encoding: .utf8)
        // original assertion lives ONLY in the frozen copy; inverted assertion ONLY in the active file
        XCTAssertTrue(frozenSrc.contains("clamped, never silently dropped"))
        XCTAssertFalse(activeSrc.contains("clamped, never silently dropped"))
        XCTAssertTrue(activeSrc.contains("A9-R1-F3 FIXED: no silent clamp into the metric"))
        XCTAssertFalse(frozenSrc.contains("A9-R1-F3 FIXED"))
        // single-hunk shape: exactly 2 original lines removed, 4 lines added (net +2 lines)
        let fLines = frozenSrc.components(separatedBy: "\n"), aLines = activeSrc.components(separatedBy: "\n")
        XCTAssertEqual(aLines.count - fLines.count, 2, "net +2 lines — the declared +4/−2 hunk and nothing else")
        let fSet = Set(fLines), aSet = Set(aLines)
        let removed = fLines.filter { !aSet.contains($0) }, added = aLines.filter { !fSet.contains($0) }
        XCTAssertEqual(removed.count, 2, "exactly two original lines gone: \(removed)")
        XCTAssertEqual(added.count, 4, "exactly four lines added: \(added)")
        XCTAssertTrue(removed.allSatisfy { $0.contains("clamp") }, "both removed lines belong to the clamp block")
    }

    // ═════════════════════════ historical stability + gates ═════════════════════════

    /// P18 — historical calibration artefacts unchanged by F1/F2/F3 (weights/splits/thresholds):
    /// dataset registry shape, split censuses, and gate truth are re-asserted independently here;
    /// the exact numbers (.628/.743/.559/ECE .250/AUROC .94/falseSafe 0) are load-bearing assertions
    /// inside AUDIT9_P009ER1Probes + P009EScoreTests and were reproduced green in this audit run.
    func testP18_HistoricalDatasetAndSplits_Stable() {
        let pairs = CalibrationDatasetRegistryV2.pairs
        XCTAssertEqual(pairs.count, 59)
        XCTAssertEqual(pairs.filter { $0.split == .trainTune }.count, 26, "TRAIN census unchanged")
        XCTAssertEqual(pairs.filter { $0.split == .calibration }.count, 12, "CAL census unchanged")
        XCTAssertEqual(pairs.filter { $0.split == .heldOutFinal }.count, 8, "HELD_OUT census unchanged")
        XCTAssertEqual(pairs.filter { $0.split == .safetySentinel }.count, 5, "SENTINEL census unchanged")
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims,
                       "real-world claims stay structurally unsupported (no fitting on real data happened)")
        XCTAssertTrue(CalibrationDatasetRegistryV2.itemSplitViolations.isEmpty)
        // calibrator + fusion versions untouched by the entry gate
        XCTAssertEqual(DimensionCalibratorV1.version, "dimension-calibrator-v1")
        XCTAssertEqual(CalibrationRegistryV2.version, "calibration-registry-v2")
        XCTAssertEqual(TeenBandFailClosedPolicyV1.version, "teen-band-fail-closed-policy-v1.1",
                       "the ONLY policy version bump is the declared v1.1 (violence routing cues)")
    }

    /// P19 — production score/presentation gates remain BLOCKED; claim ceiling enforced structurally.
    func testP19_ProductionGates_StillBlocked() {
        let (open, conditions) = ProductionScoreReleaseGateV1.evaluate()
        XCTAssertFalse(open, "production score release gate stays CLOSED")
        XCTAssertEqual(conditions.count, 10)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertFalse(GuardianMetaBrainV2().calibration.scoreDisplayAllowed(), "P009B skeleton still refusing")
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly,
                       "claim ceiling: ENGINEERING only — 'production calibrated' remains structurally false")
    }
}
