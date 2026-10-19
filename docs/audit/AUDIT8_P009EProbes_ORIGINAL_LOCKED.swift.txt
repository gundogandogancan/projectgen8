import XCTest
@testable import GuardianCore

// AUDIT8 — INDEPENDENT P009E CALIBRATION / REAL SCORE RED-TEAM PROBES.
// Fresh-context auditor-authored. ADD-ONLY: no existing source or test was modified.
// Mandate: docs/audit/prompts/GEN8_INDEPENDENT_P009E_CALIBRATION_AUDIT.md §17 minimum list.
// All metrics here are recomputed with the AUDITOR'S OWN implementations — builder summaries
// (CalibrationMetricsV1) are compared against, never trusted as the source of truth.

final class AUDIT8_P009EProbes: XCTestCase {

    // ───────────────────────── auditor-owned harness (mirrors the production path, not the test file) ─────────────────────────

    static var reg: CalibrationRegistryV2!                 // auditor FULL resolution (54 pairs, alias-resolved)
    static var fusion: SuitabilityFusionModelV1!
    static var regB: CalibrationRegistryV2!                // BUILDER-EFFECTIVE (52 pairs — alias pairs dropped,
    static var fusionB: SuitabilityFusionModelV1!          // exactly what the shipped P009EScoreTests fit)
    static var resolved: [(pair: CalibrationPairV1, m: ContentWorldModelV1, d: AdmissionStateCandidateV1)] = []
    static var dropped: [String] = []

    func freshBrain() -> GuardianMetaBrainV2 {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1()); b.registry.register(LanguageOCRExpertV1())
        b.registry.register(SpeechExpertV1()); b.registry.register(AudioEventExpertV1())
        b.registry.register(MusicExpertV1()); b.registry.register(SymbolExpertV1())
        b.registry.register(TemporalExpertV1()); b.registry.register(SafetyEvidenceExpertV1())
        b.registry.register(BenefitEvidenceExpertV1()); b.registry.register(AttentionPressureExpertV1())
        return b
    }

    /// Auditor's own pair→scenario resolver (independently re-derived from the dataset contract).
    func resolveScenario(_ pair: CalibrationPairV1) -> P009DPolicyScenarioV1? {
        let item = pair.itemID.replacingOccurrences(of: "ALIAS:", with: "")
        let aliasTarget = pair.corpus.hasPrefix("ALIAS:") ? String(pair.corpus.dropFirst(6)) : nil
        func fromP009C(_ name: String) -> P009DPolicyScenarioV1? {
            for split in P009CSplitV1.allCases {
                if let s = P009CCorpusV1.scenarios(split).first(where: { $0.name == name }) {
                    return P009DPolicyScenarioV1(name: s.name, family: s.family, segments: s.segments,
                                                 childProfile: pair.profile.childProfile,
                                                 parentPreference: pair.profile.parentPreference,
                                                 shieldConfig: pair.profile.shieldConfig, annotation: P009DPolicyAnnotationV1())
                }
            }
            return nil
        }
        switch pair.corpus {
        case "P009D":
            for split in P009DSplitV1.allCases {
                if let s = P009DPolicyCorpusV1.scenarios(split).first(where: { $0.name == item }) {
                    return P009DPolicyScenarioV1(name: s.name, family: s.family, segments: s.segments,
                                                 childProfile: pair.profile.childProfile,
                                                 parentPreference: pair.profile.parentPreference,
                                                 shieldConfig: pair.profile.shieldConfig, annotation: s.annotation)
                }
            }
            return nil
        case "P009C": return fromP009C(item)
        case "P009B_CAL_RESERVED":
            guard let s = P009BCorpusV2.scenarios(.calibrationReserved).first(where: { $0.name == item }) else { return nil }
            let segs = [P009CSegmentV1(startMs: 0, endMs: 3000, input: s.input)]
            return P009DPolicyScenarioV1(name: s.name, family: "cal-reserved", segments: segs,
                                         childProfile: pair.profile.childProfile,
                                         parentPreference: pair.profile.parentPreference,
                                         shieldConfig: pair.profile.shieldConfig, annotation: P009DPolicyAnnotationV1())
        case "P009E_TEEN":
            let segs = [P009CSegmentV1(startMs: 0, endMs: 3000,
                                       input: ExpertInputV2(ocrText: "explicit adult romance scenes compilation uncut",
                                                            detectedLanguage: "en"))]
            return P009DPolicyScenarioV1(name: item, family: "teen-sentinel", segments: segs,
                                         childProfile: pair.profile.childProfile,
                                         parentPreference: pair.profile.parentPreference,
                                         shieldConfig: pair.profile.shieldConfig, annotation: P009DPolicyAnnotationV1())
        default:
            if let t = aliasTarget { return fromP009C(t) }
            return nil
        }
    }

    override class func setUp() {
        super.setUp()
        let t = AUDIT8_P009EProbes()
        var results: [(CalibrationPairV1, ContentWorldModelV1, AdmissionStateCandidateV1)] = []
        var droppedIDs: [String] = []
        for (i, pair) in CalibrationDatasetRegistryV1.pairs.enumerated() {
            guard let sc = t.resolveScenario(pair) else {
                droppedIDs.append("\(pair.split.rawValue)/\(pair.corpus)/\(pair.itemID)")
                continue
            }
            let (m, d) = P009DPolicyCorpusV1.run(sc, brain: t.freshBrain(), item: ContentItemID(UInt64(80_000 + i)))
            results.append((pair, m, d))
        }
        resolved = results.map { (pair: $0.0, m: $0.1, d: $0.2) }
        dropped = droppedIDs
        // auditor refit — TRAIN_TUNE ONLY (identical discipline; proves artifact derivation below)
        let r = CalibrationRegistryV2()
        let train = results.filter { $0.0.split == .trainTune }
        for locale in ["tr", "en"] {
            let slice = train.filter { $0.0.annotation.locale == locale }
            r.register(DimensionCalibratorV1.fit(name: "risk", slice: locale,
                                                 xs: slice.map { $0.1.maxRiskSeen },
                                                 ys: slice.map { $0.0.annotation.finalLabel <= 1 }))
            r.register(DimensionCalibratorV1.fit(name: "benefit", slice: locale,
                                                 xs: slice.map { min(1, Double($0.1.benefitEvidence.count) * 0.4) },
                                                 ys: slice.map { $0.0.annotation.finalLabel >= 3 }))
            r.register(DimensionCalibratorV1.fit(name: "manip", slice: locale,
                                                 xs: slice.map { min(1, Double($0.1.manipulationEvidence.count) * 0.4) },
                                                 ys: slice.map { $0.0.annotation.finalLabel <= 2 }))
        }
        reg = r
        fusion = SuitabilityFusionModelV1.fit(features: Self.features(train, r), targets: train.map { Double($0.0.annotation.finalLabel) })
        // BUILDER-EFFECTIVE replica: the shipped harness drops ALIAS pairs (alias lives in `corpus`,
        // its resolver only checks `itemID`) — reproduce exactly that artifact for metric verification.
        let rB = CalibrationRegistryV2()
        let trainB = train.filter { !$0.0.corpus.hasPrefix("ALIAS:") }
        for locale in ["tr", "en"] {
            let slice = trainB.filter { $0.0.annotation.locale == locale }
            rB.register(DimensionCalibratorV1.fit(name: "risk", slice: locale,
                                                  xs: slice.map { $0.1.maxRiskSeen },
                                                  ys: slice.map { $0.0.annotation.finalLabel <= 1 }))
            rB.register(DimensionCalibratorV1.fit(name: "benefit", slice: locale,
                                                  xs: slice.map { min(1, Double($0.1.benefitEvidence.count) * 0.4) },
                                                  ys: slice.map { $0.0.annotation.finalLabel >= 3 }))
            rB.register(DimensionCalibratorV1.fit(name: "manip", slice: locale,
                                                  xs: slice.map { min(1, Double($0.1.manipulationEvidence.count) * 0.4) },
                                                  ys: slice.map { $0.0.annotation.finalLabel <= 2 }))
        }
        regB = rB
        fusionB = SuitabilityFusionModelV1.fit(features: Self.features(trainB, rB), targets: trainB.map { Double($0.0.annotation.finalLabel) })
    }

    static func features(_ rows: [(CalibrationPairV1, ContentWorldModelV1, AdmissionStateCandidateV1)],
                         _ r: CalibrationRegistryV2) -> [[Double]] {
        rows.map { (pair, m, d) in
            let loc = pair.annotation.locale
            let f = PersonalSuitabilityScoreV2.EngineV1.features(worldModel: m, decision: d)
            return [r.calibrator(name: "risk", slice: loc)?.probability(f.risk) ?? f.risk,
                    r.calibrator(name: "benefit", slice: loc)?.probability(f.benefit) ?? f.benefit,
                    r.calibrator(name: "manip", slice: loc)?.probability(f.manip) ?? f.manip,
                    (d.shieldOutcome?.hardMatch ?? false) ? 1 : 0,
                    (d.childOutcome == .restricted || d.childOutcome == .caution) ? 1 : 0]
        }
    }
    /// engine under audit = the BUILDER-EFFECTIVE artifact (what P009EScoreTests actually fits/ships)
    func engine() -> PersonalSuitabilityScoreV2.EngineV1 {
        PersonalSuitabilityScoreV2.EngineV1(registry: Self.regB, fusion: Self.fusionB)
    }
    func engineFull() -> PersonalSuitabilityScoreV2.EngineV1 {
        PersonalSuitabilityScoreV2.EngineV1(registry: Self.reg, fusion: Self.fusion)
    }
    func rows(_ s: CalibrationSplitV1) -> [(pair: CalibrationPairV1, m: ContentWorldModelV1, d: AdmissionStateCandidateV1)] {
        Self.resolved.filter { $0.pair.split == s }
    }
    /// builder-effective rows (ALIAS pairs excluded — they never execute in the shipped harness)
    func rowsB(_ s: CalibrationSplitV1) -> [(pair: CalibrationPairV1, m: ContentWorldModelV1, d: AdmissionStateCandidateV1)] {
        rows(s).filter { !$0.pair.corpus.hasPrefix("ALIAS:") }
    }
    func teenScenario(_ name: String, text: String, lang: String, age: Int, jur: String = "TR") -> P009DPolicyScenarioV1 {
        P009DPolicyScenarioV1(name: name, family: "audit8-teen",
                              segments: [P009CSegmentV1(startMs: 0, endMs: 3000,
                                                        input: ExpertInputV2(ocrText: text, detectedLanguage: lang))],
                              childProfile: GuardianEnteredChildProfileV1(ageYears: age, jurisdictionCode: jur, enteredByGuardian: true),
                              parentPreference: ParentPreferencePolicyV1(), shieldConfig: nil,
                              annotation: P009DPolicyAnnotationV1())
    }

    // auditor-owned metric implementations (strict half-open bins — every pred in EXACTLY one bin)
    func myECE(_ preds: [Double], _ labels: [Bool], bins: Int = 10) -> (ece: Double, assigned: Int) {
        guard !preds.isEmpty else { return (0, 0) }
        var ece = 0.0, assigned = 0
        for i in 0..<bins {
            let lo = Double(i) / Double(bins), hi = Double(i + 1) / Double(bins)
            let idx = preds.indices.filter { i == bins - 1 ? (preds[$0] >= lo && preds[$0] <= hi) : (preds[$0] >= lo && preds[$0] < hi) }
            guard !idx.isEmpty else { continue }
            assigned += idx.count
            let mp = idx.map { preds[$0] }.reduce(0, +) / Double(idx.count)
            let fp = idx.map { labels[$0] ? 1.0 : 0.0 }.reduce(0, +) / Double(idx.count)
            ece += Double(idx.count) / Double(preds.count) * abs(mp - fp)
        }
        return (ece, assigned)
    }
    func myBrier(_ p: [Double], _ y: [Bool]) -> Double {
        zip(p, y).map { ($0 - ($1 ? 1 : 0)) * ($0 - ($1 ? 1 : 0)) }.reduce(0, +) / Double(max(1, p.count))
    }
    func myAUROC(_ p: [Double], _ y: [Bool]) -> Double? {
        let pos = zip(p, y).filter { $0.1 }.map { $0.0 }, neg = zip(p, y).filter { !$0.1 }.map { $0.0 }
        guard !pos.isEmpty, !neg.isEmpty else { return nil }
        var w = 0.0
        for a in pos { for b in neg { w += a > b ? 1 : (a == b ? 0.5 : 0) } }
        return w / Double(pos.count * neg.count)
    }

    // ───────────────────────── 1. dataset resolution coverage (silent-drop quantification) ─────────────────────────

    func testA8_01_DatasetResolutionCoverage() {
        let declared = CalibrationDatasetRegistryV1.pairs.count
        let builderEffective = Self.resolved.filter { !$0.pair.corpus.hasPrefix("ALIAS:") }.count
        print("AUDIT8_RESOLUTION declared=\(declared) auditorResolved=\(Self.resolved.count) builderEffective=\(builderEffective) phantom=\(Self.dropped.count) :: \(Self.dropped)")
        XCTAssertEqual(declared, 59)
        // FINDING AUDIT8-F1 (pinned): 5 declared TRAIN pairs reference P009D scenario names that DO NOT
        // EXIST in any P009D split (pd-persuasive-ad ×2, pd-manipulative-urgency, pd-calm-nature ×2) —
        // they are silently skipped by every harness.
        XCTAssertEqual(Set(Self.dropped.map { $0.components(separatedBy: "/").last! }),
                       ["pd-persuasive-ad", "pd-manipulative-urgency", "pd-calm-nature"],
                       "phantom item set must not grow or shrink silently")
        XCTAssertEqual(Self.dropped.count, 5)
        XCTAssertEqual(Self.resolved.count, 54, "auditor resolution (alias-resolved) must stay exactly 54")
        // FINDING AUDIT8-F2 (pinned): the shipped harness ALSO drops the 2 ALIAS pairs (alias is declared
        // in `corpus` but its resolver only checks `itemID`) → effective dataset 52/59, train 20/26.
        XCTAssertEqual(builderEffective, 52, "builder-effective dataset is 52, not the declared 59")
        // sentinel split MUST be fully resolved — a dropped sentinel would trivially pass no-false-safe
        XCTAssertEqual(rows(.safetySentinel).count, CalibrationDatasetRegistryV1.pairs(in: .safetySentinel).count,
                       "every SAFETY_SENTINEL pair must actually execute")
        XCTAssertEqual(rows(.heldOutFinal).count, CalibrationDatasetRegistryV1.pairs(in: .heldOutFinal).count,
                       "every HELD_OUT_FINAL pair must actually execute")
        XCTAssertFalse(rows(.ood).isEmpty); XCTAssertFalse(rows(.stress).isEmpty)
    }

    // ───────────────────────── 2. independent metric recomputation ─────────────────────────

    func testA8_02_MetricRecomputationIndependent() {
        // ordinal MAE on CALIBRATION and HELD_OUT_FINAL via the auditor's own loop over the
        // BUILDER-EFFECTIVE rows + artifact (verifies the REPORTED numbers), then full-resolution
        // sensitivity (what the numbers become when the silently-dropped alias pair is included).
        func maeLoop(_ rs: [(pair: CalibrationPairV1, m: ContentWorldModelV1, d: AdmissionStateCandidateV1)],
                     _ e: PersonalSuitabilityScoreV2.EngineV1) -> (mae: Double, n: Int, abstained: Int) {
            var errs: [Double] = []; var abstained = 0
            for r in rs {
                let c = e.evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
                if let sc = c.score { errs.append(abs(sc / 25.0 - Double(r.pair.annotation.finalLabel))) } else { abstained += 1 }
            }
            return (errs.isEmpty ? 0 : errs.reduce(0, +) / Double(errs.count), errs.count, abstained)
        }
        let cal = maeLoop(rowsB(.calibration), engine()), held = maeLoop(rowsB(.heldOutFinal), engine())
        let calFull = maeLoop(rows(.calibration), engineFull())
        print("AUDIT8_MAE builderEffective cal=\(String(format: "%.3f", cal.mae)) n=\(cal.n) abst=\(cal.abstained) | heldOut=\(String(format: "%.3f", held.mae)) n=\(held.n) abst=\(held.abstained)")
        print("AUDIT8_MAE_SENSITIVITY fullResolution cal=\(String(format: "%.3f", calFull.mae)) n=\(calFull.n) (reported .580 moves when the dropped alias pair executes)")
        XCTAssertEqual(cal.mae, 0.580, accuracy: 0.02, "builder-reported CAL MAE .580 must reproduce on the builder-effective set")
        XCTAssertEqual(held.mae, 0.585, accuracy: 0.02, "builder-reported HELD_OUT MAE .585 must reproduce")
        XCTAssertLessThanOrEqual(cal.mae, 1.5); XCTAssertLessThanOrEqual(held.mae, 1.5)
        // risk-calibrator reliability on CALIBRATION — auditor's own ECE/Brier/AUROC
        var preds: [Double] = [], labels: [Bool] = []
        for r in rowsB(.calibration) {
            if let p = Self.regB.calibrator(name: "risk", slice: r.pair.annotation.locale)?.probability(r.m.maxRiskSeen) {
                preds.append(p); labels.append(r.pair.annotation.finalLabel <= 1)
            }
        }
        let mine = myECE(preds, labels)
        let builder = CalibrationMetricsV1.eceAndBins(preds: preds, labels: labels)
        let builderAssigned = builder.bins.map { $0.count }.reduce(0, +)
        print("AUDIT8_RISK_ECE mine=\(String(format: "%.3f", mine.ece)) builder=\(String(format: "%.3f", builder.ece)) assignedMine=\(mine.assigned)/\(preds.count) assignedBuilder=\(builderAssigned)/\(preds.count)")
        print("AUDIT8_RISK brier=\(String(format: "%.3f", myBrier(preds, labels))) auroc=\(myAUROC(preds, labels).map { String(format: "%.3f", $0) } ?? "n/a")")
        XCTAssertEqual(mine.assigned, preds.count, "auditor binning: every prediction in exactly one bin")
        XCTAssertEqual(builderAssigned, preds.count, "builder binning must not double-count on this data")
        XCTAssertEqual(mine.ece, builder.ece, accuracy: 0.02, "independent ECE must agree with the builder implementation")
        XCTAssertEqual(mine.ece, 0.220, accuracy: 0.03, "reported risk ECE 0.220 must reproduce")
        XCTAssertEqual(myBrier(preds, labels), 0.163, accuracy: 0.01)
        XCTAssertEqual(myAUROC(preds, labels) ?? -1, 0.86, accuracy: 0.03)
        // honest truth: ECE 0.22 on a tiny engineering slice is UNMET for production — must stay reported-unmet
        XCTAssertGreaterThan(mine.ece, 0.1, "ECE is genuinely poor — any 'calibrated' production claim would be false")
        // slice metrics: per-locale counts (underpowered slices identified honestly)
        for loc in ["tr", "en"] {
            let n = rowsB(.calibration).filter { $0.pair.annotation.locale == loc }.count
            print("AUDIT8_SLICE calibration locale=\(loc) n=\(n)")
        }
    }

    // ───────────────────────── 3. F-5 reproduction + variants ─────────────────────────

    func testA8_03_F5_TeenSentinelReproductionAndVariants() {
        let sentinelText = "explicit adult romance scenes compilation uncut"
        for age in [13, 14, 17] {
            let (m, d) = P009DPolicyCorpusV1.run(teenScenario("a8-teen-\(age)", text: sentinelText, lang: "en", age: age),
                                                 brain: freshBrain(), item: ContentItemID(90_000 + UInt64(age)))
            XCTAssertNotEqual(d.state, .neutral, "age \(age): sentinel-class teen content must never be NEUTRAL")
            XCTAssertNotEqual(d.childOutcome, .aligned, "age \(age): must never be AGE_ALIGNED")
            let codes = ([d.dominantReason] + d.secondaryReasons).map { $0.code.rawValue }
            XCTAssertTrue(codes.contains("TEEN_SENTINEL_UNAVAILABLE_REVIEW"), "age \(age): teen law code must appear: \(codes)")
            let c = engine().evaluate(worldModel: m, decision: d, profile: .parentTeen14TR, locale: "en")
            XCTAssertNil(c.score, "age \(age): fail-closed review → score must abstain")
        }
        // under-13: H1 law — never aligned/neutral with sentinel text
        let (_, d12) = P009DPolicyCorpusV1.run(teenScenario("a8-child-12", text: sentinelText, lang: "en", age: 12),
                                               brain: freshBrain(), item: ContentItemID(90_012))
        XCTAssertNotEqual(d12.state, .neutral); XCTAssertNotEqual(d12.childOutcome, .aligned)
        // educational sexual-health: review floor stands; educational context may qualify, never erase
        let (_, dEdu) = P009DPolicyCorpusV1.run(teenScenario("a8-teen-edu", text: "sexual health education lesson explained for teenagers by a doctor", lang: "en", age: 14),
                                                brain: freshBrain(), item: ContentItemID(90_020))
        XCTAssertNotEqual(dEdu.state, .neutral, "educational mention must NOT erase the teen review floor")
        XCTAssertNotEqual(dEdu.childOutcome, .aligned)
        // severe variant
        let (_, dSev) = P009DPolicyCorpusV1.run(teenScenario("a8-teen-severe", text: "nsfw 18+ adults only explicit erotic", lang: "en", age: 14),
                                                brain: freshBrain(), item: ContentItemID(90_021))
        XCTAssertNotEqual(dSev.state, .neutral); XCTAssertNotEqual(dSev.childOutcome, .aligned)
        // TR-language variant (lexicon is TR+EN versioned)
        let (_, dTR) = P009DPolicyCorpusV1.run(teenScenario("a8-teen-tr", text: "müstehcen erotik sahneler derlemesi", lang: "tr", age: 14),
                                               brain: freshBrain(), item: ContentItemID(90_022))
        XCTAssertNotEqual(dTR.state, .neutral); XCTAssertNotEqual(dTR.childOutcome, .aligned)
        // unsupported jurisdiction: early fail-closed (AGE_JURISDICTION_UNSUPPORTED), never neutral
        let (_, dJur) = P009DPolicyCorpusV1.run(teenScenario("a8-teen-jur", text: sentinelText, lang: "en", age: 14, jur: "XX"),
                                                brain: freshBrain(), item: ContentItemID(90_023))
        XCTAssertEqual(dJur.childOutcome, .unknownReview)
        XCTAssertNotEqual(dJur.state, .neutral)
        XCTAssertTrue(([dJur.dominantReason] + dJur.secondaryReasons).contains { $0.code == .ageJurisdictionUnsupported })
        // mild romance WITHOUT sentinel tokens — honesty check: if it stays NEUTRAL that is policy-consistent
        // (no trigger), but it must then contain NO sentinel-context label (no silent trigger loss).
        let (mMild, dMild) = P009DPolicyCorpusV1.run(teenScenario("a8-teen-mild", text: "a sweet first date picnic story with flowers", lang: "en", age: 14),
                                                     brain: freshBrain(), item: ContentItemID(90_024))
        if dMild.state == .neutral {
            XCTAssertFalse(mMild.safetyEvidence.contains { $0.hasPrefix("safety:sentinel-context:") },
                           "NEUTRAL is only honest when no sentinel-context trigger fired")
        }
        print("AUDIT8_F5 mild-romance state=\(dMild.state.rawValue) child=\(dMild.childOutcome?.rawValue ?? "-")")
    }
    // ───────────────────────── 4. composite attacks ─────────────────────────

    func testA8_04_BenefitFloodCannotOverrideVeto() {
        // existing stress pair
        if let r = rows(.stress).first(where: { $0.pair.itemID == "sd-benefit-flood-vs-strong-risk" }) {
            XCTAssertNotEqual(r.d.state, .neutral, "benefit flood vs strong risk must never be NEUTRAL")
            let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            XCTAssertNotEqual(c.interpretation, "ALIGNED-CANDIDATE")
            if r.d.state == .strongProtection || r.d.state == .ageRestricted { XCTAssertLessThanOrEqual(c.score ?? 0, 10) }
        } else { XCTFail("benefit-flood stress pair must resolve") }
        // fresh auditor flood: heavy benefit lexicon + severe-risk temporal track, child 9
        let flood = P009DPolicyScenarioV1(name: "a8-benefit-flood", family: "audit8",
            segments: [P009CSegmentV1(startMs: 0, endMs: 4000,
                                      input: ExpertInputV2(ocrText: "learn tutorial lesson guide science course practice exam studying how to", detectedLanguage: "en"),
                                      temporalRisk: 0.95, temporalTopics: ["violence"])],
            childProfile: GuardianEnteredChildProfileV1(ageYears: 9, jurisdictionCode: "TR", enteredByGuardian: true),
            parentPreference: ParentPreferencePolicyV1(), shieldConfig: nil, annotation: P009DPolicyAnnotationV1())
        let (mF, dF) = P009DPolicyCorpusV1.run(flood, brain: freshBrain(), item: ContentItemID(91_000))
        XCTAssertNotEqual(dF.state, .neutral, "flooded benefit must not reach NEUTRAL under high risk + child profile")
        let cF = engine().evaluate(worldModel: mF, decision: dF, profile: .parentChild9TR, locale: "en")
        XCTAssertNotEqual(cF.interpretation, "ALIGNED-CANDIDATE", "benefit flood must not yield a positive interpretation")
        if dF.state == .strongProtection || dF.state == .ageRestricted { XCTAssertLessThanOrEqual(cF.score ?? 0, 10) }
        // fusion-level: even with benefit saturated and risk saturated, rubric stays bounded and risk-dominated
        let f = Self.fusion!
        let floodRubric = f.predictRubric(risk: 1.0, benefit: 1.0, manip: 0, shieldHard: false, childRestrictive: true)
        XCTAssertLessThan(floodRubric * 25, 62.5, "saturated benefit cannot buy an ALIGNED-range score against saturated risk")
    }

    func testA8_05_LowCoverageHighScoreAttempt() {
        guard let r = rows(.ood).first(where: { $0.pair.itemID == "od-empty-content" }) else { return XCTFail() }
        let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: "en")
        XCTAssertNil(c.score, "zero-coverage content must abstain — a 95 score is impossible")
        XCTAssertNotNil(c.abstentionReason)
        // law scan: NO resolved pair may ever emit score ≥ 95 with coverage < 0.2 or confidence "none"
        for r in Self.resolved {
            let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            if let s = c.score, s >= 95 {
                XCTAssertGreaterThanOrEqual(c.evidenceCoverage, 0.2, "\(r.pair.itemID): high score with near-zero coverage")
                XCTAssertNotEqual(c.scoreConfidence, "none")
            }
        }
    }

    func testA8_06_OODHighConfidenceAttempt() {
        for r in rows(.ood) {
            let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            XCTAssertNil(c.score, "\(r.pair.itemID): OOD must abstain, never a confident score")
            XCTAssertNotEqual(c.scoreConfidence, "high")
        }
        // honesty gap scan (code-read finding AUDIT8-F3): scored candidates hardcode oodStatus
        // "in-distribution" — verify no scored candidate currently carries oodFlags > 0.
        var leaks = 0
        for r in Self.resolved {
            let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            if c.score != nil && r.m.oodFlags > 0 { leaks += 1; print("AUDIT8_OOD_STATUS_LEAK \(r.pair.itemID) oodFlags=\(r.m.oodFlags) status=\(c.oodStatus)") }
        }
        print("AUDIT8_OOD scoredWithOodFlags=\(leaks)")
        XCTAssertEqual(leaks, 0, "no scored candidate may carry oodFlags>0 while labeled in-distribution (dataset truth today)")
    }

    // ───────────────────────── 5. cache / profile isolation / stale versions ─────────────────────────

    func testA8_07_StaleCalibratorVersionInvalidatesCache() {
        let cache = ScoreCacheV1()
        guard let r = rows(.calibration).first else { return XCTFail() }
        let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
        func fp(cal: String = CalibrationRegistryV2.version, fus: String = SuitabilityFusionModelV1.version,
                prof: String = r.pair.profile.profileID, shield: String = ShieldConfigV2.version,
                age: String = JurisdictionAgeBandRegistryV1.version, wm: String = ContentWorldModelV1.modelVersion) -> String {
            ScoreCacheV1.fingerprint(calibrationVersion: cal, fusionVersion: fus, profileID: prof,
                                     shieldVersion: shield, ageRegistry: age, wmVersion: wm)
        }
        cache.insert(profileID: r.pair.profile.profileID, item: ContentItemID(7), fp: fp(), candidate: c)
        XCTAssertNotNil(cache.lookup(profileID: r.pair.profile.profileID, item: ContentItemID(7), fp: fp()))
        // EVERY version axis must independently invalidate
        XCTAssertNil(cache.lookup(profileID: r.pair.profile.profileID, item: ContentItemID(7), fp: fp(cal: "calibration-registry-v3")))
        XCTAssertNil(cache.lookup(profileID: r.pair.profile.profileID, item: ContentItemID(7), fp: fp(fus: "suitability-fusion-v2")))
        XCTAssertNil(cache.lookup(profileID: r.pair.profile.profileID, item: ContentItemID(7), fp: fp(shield: "shield-config-v3")))
        XCTAssertNil(cache.lookup(profileID: r.pair.profile.profileID, item: ContentItemID(7), fp: fp(age: "age-registry-v2")))
        XCTAssertNil(cache.lookup(profileID: r.pair.profile.profileID, item: ContentItemID(7), fp: fp(wm: "content-world-model-v2")))
    }

    func testA8_08_ProfileCacheContaminationAndSameDNAMultiProfile() {
        let cache = ScoreCacheV1()
        guard let r = rows(.calibration).first else { return XCTFail() }
        let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: .adultNeutral, locale: "en")
        let fpA = ScoreCacheV1.fingerprint(calibrationVersion: CalibrationRegistryV2.version,
                                           fusionVersion: SuitabilityFusionModelV1.version, profileID: "adult-neutral",
                                           shieldVersion: ShieldConfigV2.version,
                                           ageRegistry: JurisdictionAgeBandRegistryV1.version,
                                           wmVersion: ContentWorldModelV1.modelVersion)
        cache.insert(profileID: "adult-neutral", item: ContentItemID(9), fp: fpA, candidate: c)
        // contamination attempts: other profile id, AND other profile id with ITS OWN fingerprint
        XCTAssertNil(cache.lookup(profileID: "parent-child9-tr", item: ContentItemID(9), fp: fpA))
        let fpB = ScoreCacheV1.fingerprint(calibrationVersion: CalibrationRegistryV2.version,
                                           fusionVersion: SuitabilityFusionModelV1.version, profileID: "parent-child9-tr",
                                           shieldVersion: ShieldConfigV2.version,
                                           ageRegistry: JurisdictionAgeBandRegistryV1.version,
                                           wmVersion: ContentWorldModelV1.modelVersion)
        XCTAssertNil(cache.lookup(profileID: "parent-child9-tr", item: ContentItemID(9), fp: fpB))
        // same DNA, many profiles → divergent personal outcomes from ONE world model (no re-understanding).
        // NOTE (FINDING AUDIT8-F5): the builder's testSameDNAMultipleProfiles counts "profileID:state"
        // strings — ALWAYS 5 distinct — so it can never fail (vacuous). On its own scenario
        // (pd-sensitive-news-adult) the true admission-state set is ONE (all STRONG_PROTECTION).
        // The auditor probes a scenario where divergence genuinely must occur.
        let sNews = P009DPolicyCorpusV1.scenarios(.tune).first { $0.name == "pd-sensitive-news-adult" }!
        let mNews = P009CCorpusV1.run(P009CScenarioV1(name: sNews.name, family: sNews.family, segments: sNews.segments,
                                                      annotation: P009CAnnotationV1()),
                                      brain: freshBrain(), item: ContentItemID(95_000))
        var newsStates: Set<String> = [], newsScores: Set<String> = []
        for p in ProfileFixtureV1.all {
            let d = AdmissionPolicyPipelineV1.evaluate(worldModel: mNews, childProfile: p.childProfile,
                                                       parentPreference: p.parentPreference,
                                                       shieldConfig: p.shieldConfig, nowMs: 0)
            newsStates.insert(d.state.rawValue)
            let c = engine().evaluate(worldModel: mNews, decision: d, profile: p, locale: "tr")
            newsScores.insert("\(p.profileID)→\(c.score.map { String(format: "%.0f", $0) } ?? "NIL")")
        }
        print("AUDIT8_MULTIPROFILE sensitive-news states=\(newsStates) scores=\(newsScores) (builder test vacuous: counts profileID-prefixed strings)")
        // genuine divergence scenario: benign educational content — adult flows, under-13 H1 fails closed
        let sEdu = P009CCorpusV1.scenarios(.tune).first { $0.name == "tc-straight-educational" }!
        let mEdu = P009CCorpusV1.run(sEdu, brain: freshBrain(), item: ContentItemID(95_001))
        var eduStates: Set<String> = []
        for p in ProfileFixtureV1.all {
            let d = AdmissionPolicyPipelineV1.evaluate(worldModel: mEdu, childProfile: p.childProfile,
                                                       parentPreference: p.parentPreference,
                                                       shieldConfig: p.shieldConfig, nowMs: 0)
            eduStates.insert(d.state.rawValue)
        }
        print("AUDIT8_MULTIPROFILE educational states=\(eduStates)")
        XCTAssertGreaterThanOrEqual(eduStates.count, 2, "profiles must genuinely diverge on benign same-DNA content")
    }

    // ───────────────────────── 6. overclaim / leakage / held-out discipline ─────────────────────────

    func testA8_09_SyntheticOnlyOverclaimGuards() {
        XCTAssertFalse(CalibrationDatasetRegistryV1.supportsRealWorldClaims)
        for p in CalibrationDatasetRegistryV1.pairs {
            XCTAssertTrue(p.source == .syntheticDerived || p.source == .structuralOnly,
                          "\(p.itemID): only SYNTHETIC_DERIVED/STRUCTURAL_ONLY may exist in P009E")
        }
        XCTAssertEqual(CalibrationDatasetRegistryV1.sourceClassCounts[.syntheticDerived], 55)
        XCTAssertEqual(CalibrationDatasetRegistryV1.sourceClassCounts[.structuralOnly], 4)
        XCTAssertNil(CalibrationDatasetRegistryV1.sourceClassCounts[.projectOwnedReal])
        XCTAssertNil(CalibrationDatasetRegistryV1.sourceClassCounts[.licensedRightsClear])
        XCTAssertEqual(Self.reg.calibrationClass, .engineeringOnly)
        XCTAssertFalse(Self.reg.productionDisplayAllowed())
        XCTAssertFalse(GuardianMetaBrainV2().calibration.scoreDisplayAllowed(), "P009B skeleton still refuses")
    }

    func testA8_10_DuplicateTranslationAndAliasLeakage() {
        // alias-RESOLVED item-level disjointness (closes the detector blind spot: alias lives in `corpus`)
        var itemSplit: [String: CalibrationSplitV1] = [:]
        for p in CalibrationDatasetRegistryV1.pairs {
            var key = p.itemID.replacingOccurrences(of: "ALIAS:", with: "")
            if p.corpus.hasPrefix("ALIAS:") { key = String(p.corpus.dropFirst(6)) }   // true underlying scenario
            if let s = itemSplit[key] {
                XCTAssertEqual(s, p.split, "alias-resolved item \(key) appears in two splits: \(s) + \(p.split)")
            }
            itemSplit[key] = p.split
        }
        // content-level cross-split audit on the scenarios that actually executed
        func tokens(_ m: [(pair: CalibrationPairV1, m: ContentWorldModelV1, d: AdmissionStateCandidateV1)]) -> [(String, CalibrationSplitV1, Set<String>)] {
            var out: [(String, CalibrationSplitV1, Set<String>)] = []
            var seen = Set<String>()
            for r in m {
                let name = r.pair.itemID.replacingOccurrences(of: "ALIAS:", with: "")
                guard seen.insert(name).inserted, let sc = resolveScenario(r.pair) else { continue }
                let text = sc.segments.compactMap { $0.input.ocrText }.joined(separator: " ") + " "
                    + sc.segments.compactMap { $0.input.speechTranscript }.joined(separator: " ")
                let toks = Set(text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
                out.append((name, r.pair.split, toks))
            }
            return out
        }
        let all = tokens(Self.resolved)
        var worst: (Double, String) = (0, "none")
        for i in all.indices {
            for j in all.indices where j > i && all[i].1 != all[j].1 {
                let a = all[i].2, b = all[j].2
                guard !a.isEmpty || !b.isEmpty else { continue }
                let jac = Double(a.intersection(b).count) / Double(max(1, a.union(b).count))
                if jac > worst.0 { worst = (jac, "\(all[i].1.rawValue)/\(all[i].0) ~ \(all[j].1.rawValue)/\(all[j].0)") }
                XCTAssertLessThanOrEqual(jac, 0.8, "cross-split near-duplicate: \(all[i].0) vs \(all[j].0) J=\(jac)")
                XCTAssertFalse(!a.isEmpty && a == b, "cross-split exact token duplicate (incl. translation templates re-tokenized)")
            }
        }
        print("AUDIT8_LEAKAGE worstCrossSplitJaccard=\(String(format: "%.2f", worst.0)) pair=\(worst.1)")
        // P009C template law still holds (translation-equivalent templates can never sit in two splits)
        XCTAssertTrue(CorpusSplitLeakageAuditorV1.audit().isEmpty, "P009B corpus split independence regressed")
    }

    func testA8_11_HeldOutTuningLeakRefitDeterminism() {
        // the auditor's BUILDER-EFFECTIVE refit (TRAIN_TUNE only, own loop) must EXACTLY reproduce the
        // builder-reported fusion weights — proving the shipped artifact derives from TRAIN only,
        // deterministically. (The FULL-resolution refit differs — see AUDIT8-F2 prints — because the
        // shipped harness silently drops the ALIAS train pair.)
        let f = Self.fusionB!
        XCTAssertTrue(f.fitted)
        XCTAssertEqual(f.wRisk, -1.60, accuracy: 0.02)
        XCTAssertEqual(f.wBenefit, 1.12, accuracy: 0.02)
        XCTAssertEqual(f.wManip, 0.0, accuracy: 0.02)
        XCTAssertEqual(f.wShield, -1.00, accuracy: 0.02)
        XCTAssertEqual(f.wChild, -1.12, accuracy: 0.02)
        XCTAssertEqual(f.trainMAE, 0.681, accuracy: 0.02)
        print("AUDIT8_REFIT builderEffective w=[\(String(format: "%.3f", f.wRisk)),\(String(format: "%.3f", f.wBenefit)),\(String(format: "%.3f", f.wManip)),\(String(format: "%.3f", f.wShield)),\(String(format: "%.3f", f.wChild))] vs fullResolution w=[\(String(format: "%.3f", Self.fusion.wRisk)),\(String(format: "%.3f", Self.fusion.wBenefit)),\(String(format: "%.3f", Self.fusion.wManip)),\(String(format: "%.3f", Self.fusion.wShield)),\(String(format: "%.3f", Self.fusion.wChild))]")
        // counterfactual: had HELD_OUT_FINAL leaked into the fit, the artifact would differ → the match
        // above is load-bearing, not vacuous.
        let trainB = Self.resolved.filter { $0.pair.split == .trainTune && !$0.pair.corpus.hasPrefix("ALIAS:") }.map { ($0.pair, $0.m, $0.d) }
        let held = Self.resolved.filter { $0.pair.split == .heldOutFinal }.map { ($0.pair, $0.m, $0.d) }
        let leakedFit = SuitabilityFusionModelV1.fit(features: Self.features(trainB + held, Self.regB),
                                                     targets: (trainB + held).map { Double($0.0.annotation.finalLabel) })
        let delta = abs(leakedFit.wRisk - f.wRisk) + abs(leakedFit.wBenefit - f.wBenefit)
                  + abs(leakedFit.wManip - f.wManip) + abs(leakedFit.wShield - f.wShield)
                  + abs(leakedFit.wChild - f.wChild) + abs(leakedFit.bias - f.bias)
        print("AUDIT8_LEAK_COUNTERFACTUAL deltaIfHeldOutLeaked=\(String(format: "%.4f", delta))")
        XCTAssertGreaterThan(delta, 1e-6, "held-out inclusion must change the artifact — otherwise this probe proves nothing")
        // sentinel pairs must never enter any fit (structural: splits disjoint + fit filters trainTune)
        XCTAssertFalse(trainB.contains { $0.0.split == .safetySentinel })
    }

    // ───────────────────────── 7. semantics / hardcode / gate ─────────────────────────

    func testA8_12_ScoreConfidenceCoverageFieldDomains() {
        let allowed: Set<String> = ["none", "low", "medium", "high"]
        for r in Self.resolved {
            let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            XCTAssertTrue(allowed.contains(c.scoreConfidence), "confidence must stay categorical")
            XCTAssertTrue(c.evidenceCoverage >= 0 && c.evidenceCoverage <= 1)
            if let s = c.score {
                XCTAssertTrue(s >= 0 && s <= 100)
                XCTAssertNotEqual(s, c.evidenceCoverage, "score must not literally be coverage")
            } else {
                XCTAssertEqual(c.scoreConfidence, "none"); XCTAssertNotNil(c.abstentionReason)
                XCTAssertEqual(c.interpretation, "UNKNOWN", "nil score must present as UNKNOWN, never positive")
            }
            XCTAssertFalse(Double(c.scoreConfidence) != nil, "confidence can never be a number")
        }
    }

    func testA8_13_SentinelRenameNoIDMemorization() {
        // run the SAME teen sentinel input under a fresh name + item id — behavior must be identical
        // (no threshold/special-case memorization of sentinel item IDs anywhere in the path)
        let original = teenScenario("a7-teen-sexual-text-equivalent", text: "explicit adult romance scenes compilation uncut", lang: "en", age: 14)
        let renamed = teenScenario("zz-audit8-renamed-\(UUID().uuidString.prefix(8))", text: "explicit adult romance scenes compilation uncut", lang: "en", age: 14)
        let (_, dO) = P009DPolicyCorpusV1.run(original, brain: freshBrain(), item: ContentItemID(96_000))
        let (_, dR) = P009DPolicyCorpusV1.run(renamed, brain: freshBrain(), item: ContentItemID(96_001))
        XCTAssertEqual(dO.state, dR.state, "outcome must not depend on scenario name")
        XCTAssertEqual(dO.childOutcome, dR.childOutcome)
        XCTAssertNotEqual(dR.state, .neutral)
    }

    func testA8_14_ReleaseGateBypassAttempt() {
        let (open, conditions) = ProductionScoreReleaseGateV1.evaluate()
        XCTAssertFalse(open, "release gate must be CLOSED")
        XCTAssertEqual(conditions.count, 10)
        let unmet = conditions.filter { !$0.met }.map { $0.name }
        XCTAssertEqual(unmet.count, 6, "exactly the six honest blockers: \(unmet)")
        XCTAssertTrue(unmet.contains("rights-clear calibration corpus"))
        XCTAssertTrue(unmet.contains("held-out metrics pass on real data"))
        XCTAssertTrue(unmet.contains("TR/EN required slices (real)"))
        XCTAssertTrue(unmet.contains("age slices pass"))
        XCTAssertTrue(unmet.contains("physical device/in-app proof"))
        XCTAssertTrue(unmet.contains("independent P009E audit PASS"))
        for c in conditions { XCTAssertFalse(c.truth.isEmpty, "every condition carries a truth string") }
        // bypass attempt: nothing in the public API can flip a condition — evaluate() is pure; re-calling
        // after full suite + sentinel-green still returns CLOSED.
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().open)
    }

    func testA8_15_TeenSentinelUnavailableScoreNilEndToEnd() {
        guard let r = rows(.safetySentinel).first(where: { $0.pair.corpus == "P009E_TEEN" }) else {
            return XCTFail("teen sentinel pair must resolve and execute")
        }
        XCTAssertEqual(r.d.childOutcome, .unknownReview)
        XCTAssertNotEqual(r.d.state, .neutral)
        let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: "en")
        XCTAssertNil(c.score)
        XCTAssertEqual(c.interpretation, "UNKNOWN")
        XCTAssertNotNil(c.abstentionReason)
        // uncalibrated-slice honesty (mirrors the HUD's empty-registry path): empty registry must abstain
        let emptyEngine = PersonalSuitabilityScoreV2.EngineV1(registry: CalibrationRegistryV2(), fusion: Self.fusion)
        guard let any = rows(.calibration).first else { return XCTFail() }
        let cEmpty = emptyEngine.evaluate(worldModel: any.m, decision: any.d, profile: any.pair.profile, locale: "en")
        XCTAssertNil(cEmpty.score, "no fitted calibrator for the slice → abstain (HUD therefore shows NIL)")
        XCTAssertEqual(cEmpty.calibrationStatus, "UNCALIBRATED_SLICE")
    }
}
