import XCTest
@testable import GuardianCore

// P009E — calibration + internal score test families (§27). Fit on TRAIN_TUNE only; evaluate
// CALIBRATION + HELD_OUT_FINAL once; sentinel split never fitted. ENGINEERING_CALIBRATION_ONLY.

final class P009EScoreTests: XCTestCase {

    static var fittedRegistry: CalibrationRegistryV2!
    static var fittedFusion: SuitabilityFusionModelV1!
    static var pairResults: [(pair: CalibrationPairV1, m: ContentWorldModelV1, d: AdmissionStateCandidateV1)] = []

    func makeBrain() -> GuardianMetaBrainV2 {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1()); b.registry.register(LanguageOCRExpertV1())
        b.registry.register(SpeechExpertV1()); b.registry.register(AudioEventExpertV1())
        b.registry.register(MusicExpertV1()); b.registry.register(SymbolExpertV1())
        b.registry.register(TemporalExpertV1()); b.registry.register(SafetyEvidenceExpertV1())
        b.registry.register(BenefitEvidenceExpertV1()); b.registry.register(AttentionPressureExpertV1())
        return b
    }
    func scenario(for pair: CalibrationPairV1) -> P009DPolicyScenarioV1? {
        let item = pair.itemID.replacingOccurrences(of: "ALIAS:", with: "")
        func wrap(_ s: P009CScenarioV1) -> P009DPolicyScenarioV1 {
            P009DPolicyScenarioV1(name: s.name, family: s.family, segments: s.segments,
                                  childProfile: pair.profile.childProfile,
                                  parentPreference: pair.profile.parentPreference,
                                  shieldConfig: pair.profile.shieldConfig, annotation: P009DPolicyAnnotationV1())
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
        case "P009C", "ALIAS:P009C":
            for split in P009CSplitV1.allCases {
                if let s = P009CCorpusV1.scenarios(split).first(where: { $0.name == item }) { return wrap(s) }
            }
        case "P009B_CAL_RESERVED":
            // FIRST CONSUMPTION of the reserved bank — calibration split only, content untouched.
            if let s = P009BCorpusV2.scenarios(.calibrationReserved).first(where: { $0.name == item }) {
                let segs = [P009CSegmentV1(startMs: 0, endMs: 3000, input: s.input)]
                return P009DPolicyScenarioV1(name: s.name, family: "cal-reserved", segments: segs,
                                             childProfile: pair.profile.childProfile,
                                             parentPreference: pair.profile.parentPreference,
                                             shieldConfig: pair.profile.shieldConfig, annotation: P009DPolicyAnnotationV1())
            }
        case "P009E_TEEN":
            let segs = [P009CSegmentV1(startMs: 0, endMs: 3000,
                                       input: ExpertInputV2(ocrText: "explicit adult romance scenes compilation uncut",
                                                            detectedLanguage: "en"))]
            return P009DPolicyScenarioV1(name: item, family: "teen-sentinel", segments: segs,
                                         childProfile: pair.profile.childProfile,
                                         parentPreference: pair.profile.parentPreference,
                                         shieldConfig: pair.profile.shieldConfig, annotation: P009DPolicyAnnotationV1())
        default:
            if pair.itemID.hasPrefix("ALIAS:") {
                for split in P009CSplitV1.allCases {
                    if let s = P009CCorpusV1.scenarios(split).first(where: { $0.name == item }) { return wrap(s) }
                }
            }
        }
        return nil
    }

    /// R1 (A10-F2-WIRING): non-nil ⇔ the canonical integrity gate REFUSED the declared ledger —
    /// in that case NO world-model runs happen, NO fit happens, NO metric exists (typed refusal only).
    static var integrityRefusal: CalibrationIntegrityErrorV1?

    override class func setUp() {
        super.setUp()
        let tester = P009EScoreTests()
        // A10-F2-WIRING FIX: the declared ledger enters this harness ONLY through the canonical
        // pipeline (CalibrationRunPreparationV1 → CalibrationRunGuardV1). The former silent-drop loop
        // is gone: ANY unresolved/duplicate/malformed/mismatched pair aborts the ENTIRE run here.
        let prepared: [(pair: CalibrationPairV1, resolved: P009DPolicyScenarioV1)]
        do {
            prepared = try CalibrationRunPreparationV1.prepare(declared: CalibrationDatasetRegistryV2.pairs,
                                                               resolve: { tester.scenario(for: $0) })
            integrityRefusal = nil
        } catch let e as CalibrationIntegrityErrorV1 {
            integrityRefusal = e
            pairResults = []
            fittedRegistry = CalibrationRegistryV2()                       // nothing fitted
            fittedFusion = SuitabilityFusionModelV1.fit(features: [], targets: [])   // unfitted
            return                                                         // FIT/METRICS unreached
        } catch {
            preconditionFailure("calibration preparation may only throw CalibrationIntegrityErrorV1: \(error)")
        }
        var results: [(CalibrationPairV1, ContentWorldModelV1, AdmissionStateCandidateV1)] = []
        for (i, item) in prepared.enumerated() {
            let provisional = false
            let (m, d) = P009DPolicyCorpusV1.run(item.resolved, brain: tester.makeBrain(),
                                                 item: ContentItemID(UInt64(10_000 + i)), provisional: provisional)
            results.append((item.pair, m, d))
        }
        pairResults = results.map { (pair: $0.0, m: $0.1, d: $0.2) }
        // ── FIT on TRAIN_TUNE ONLY ──
        let reg = CalibrationRegistryV2()
        let train = results.filter { $0.0.split == .trainTune }
        for locale in ["tr", "en"] {
            let slice = train.filter { $0.0.annotation.locale == locale }
            let riskX = slice.map { $0.1.maxRiskSeen }
            let riskY = slice.map { $0.0.annotation.finalLabel <= 1 }      // P(unsuitable)
            reg.register(DimensionCalibratorV1.fit(name: "risk", slice: locale, xs: riskX, ys: riskY))
            let benX = slice.map { min(1, Double($0.1.benefitEvidence.count) * 0.4) }
            let benY = slice.map { $0.0.annotation.finalLabel >= 3 }
            reg.register(DimensionCalibratorV1.fit(name: "benefit", slice: locale, xs: benX, ys: benY))
            let manX = slice.map { min(1, Double($0.1.manipulationEvidence.count) * 0.4) }
            let manY = slice.map { $0.0.annotation.finalLabel <= 2 }
            reg.register(DimensionCalibratorV1.fit(name: "manip", slice: locale, xs: manX, ys: manY))
        }
        var feats: [[Double]] = [], targets: [Double] = []
        for (pair, m, d) in train {
            let locale = pair.annotation.locale
            let f = PersonalSuitabilityScoreV2.EngineV1.features(worldModel: m, decision: d)
            let riskC = reg.calibrator(name: "risk", slice: locale)?.probability(f.risk) ?? f.risk
            let benC = reg.calibrator(name: "benefit", slice: locale)?.probability(f.benefit) ?? f.benefit
            let manC = reg.calibrator(name: "manip", slice: locale)?.probability(f.manip) ?? f.manip
            feats.append([riskC, benC, manC, (d.shieldOutcome?.hardMatch ?? false) ? 1 : 0,
                          (d.childOutcome == .restricted || d.childOutcome == .caution) ? 1 : 0])
            targets.append(Double(pair.annotation.finalLabel))
        }
        fittedRegistry = reg
        fittedFusion = SuitabilityFusionModelV1.fit(features: feats, targets: targets)
        print("P009E_FIT train=\(train.count) fusionFitted=\(fittedFusion.fitted) trainMAE=\(String(format: "%.3f", fittedFusion.trainMAE)) w=[\(String(format: "%.2f", fittedFusion.wRisk)),\(String(format: "%.2f", fittedFusion.wBenefit)),\(String(format: "%.2f", fittedFusion.wManip)),\(String(format: "%.2f", fittedFusion.wShield)),\(String(format: "%.2f", fittedFusion.wChild))]")
    }

    func engine() -> PersonalSuitabilityScoreV2.EngineV1 {
        PersonalSuitabilityScoreV2.EngineV1(registry: Self.fittedRegistry, fusion: Self.fittedFusion)
    }
    func results(_ split: CalibrationSplitV1) -> [(pair: CalibrationPairV1, m: ContentWorldModelV1, d: AdmissionStateCandidateV1)] {
        Self.pairResults.filter { $0.pair.split == split }
    }
    func evalMAE(_ split: CalibrationSplitV1) -> (mae: Double, n: Int, abstained: Int) {
        var preds: [Double] = [], targets: [Double] = []; var abstained = 0
        for r in results(split) {
            let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            if let s = c.score { preds.append(s / 25.0); targets.append(Double(r.pair.annotation.finalLabel)) }
            else { abstained += 1 }
        }
        return (CalibrationMetricsV1.mae(preds, targets), preds.count, abstained)
    }

    // ── fits + split hygiene ──
    /// R1 (A10-F2-WIRING): the live run is lawful ⇔ the canonical gate ACCEPTED the full ledger —
    /// and a refusal would have left this harness with zero results and nothing fitted (asserted here).
    func testCalibrationLedgerIntegrityGateWired() {
        XCTAssertNil(Self.integrityRefusal, "canonical integrity gate must accept the 59/59 ledger: \(String(describing: Self.integrityRefusal))")
        XCTAssertEqual(Self.pairResults.count, CalibrationDatasetRegistryV2.pairs.count,
                       "exactly one world-model result per DECLARED pair — no silent drop, no surplus")
        XCTAssertEqual(CalibrationRunGuardV1.revision, "calibration-run-guard-v2")
        XCTAssertEqual(CalibrationRunPreparationV1.version, "calibration-run-preparation-v1")
    }
    func testDatasetSplitDisjointAndProvenanceHonest() {
        XCTAssertTrue(CalibrationDatasetRegistryV2.itemSplitViolations.isEmpty,
                      "\(CalibrationDatasetRegistryV2.itemSplitViolations)")
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims,
                       "no PROJECT_OWNED_REAL/LICENSED items — real-world claims structurally unsupported")
        XCTAssertEqual(Self.fittedRegistry.calibrationClass, .engineeringOnly)
        print("P009E_DATASET pairs=\(CalibrationDatasetRegistryV2.pairs.count) sources=\(CalibrationDatasetRegistryV2.sourceClassCounts.map { "\($0.key.rawValue):\($0.value)" }.sorted())")
    }
    func testCalibratorsFittedPerSliceAndMonotonic() {
        for locale in ["tr", "en"] {
            guard let c = Self.fittedRegistry.calibrator(name: "risk", slice: locale) else { return XCTFail() }
            XCTAssertTrue(c.fitted, "risk calibrator fitted for \(locale) (n=\(c.sampleCount))")
            XCTAssertGreaterThanOrEqual(c.a, 0, "monotone slope law")
            let p1 = c.probability(0.2)!, p2 = c.probability(0.9)!
            XCTAssertLessThanOrEqual(p1, p2 + 1e-9, "P(unsuitable) monotone in risk strength")
        }
        // insufficient-data abstention law
        let tiny = DimensionCalibratorV1.fit(name: "x", slice: "tr", xs: [0.1, 0.9], ys: [false, true])
        XCTAssertFalse(tiny.fitted); XCTAssertNil(tiny.probability(0.5))
    }
    func testCalibrationSplitMetrics() {
        let (mae, n, abstained) = evalMAE(.calibration)
        print("P009E_CALIBRATION n=\(n) abstained=\(abstained) ordinalMAE=\(String(format: "%.3f", mae)) (rubric units)")
        XCTAssertGreaterThan(n, 0)
        XCTAssertLessThanOrEqual(mae, 1.5, "engineering gate: ordinal MAE within 1.5 rubric levels")
        // risk-calibrator reliability on the calibration split (binary unsuitable)
        var preds: [Double] = [], labels: [Bool] = []
        for r in results(.calibration) {
            let locale = r.pair.annotation.locale
            if let p = Self.fittedRegistry.calibrator(name: "risk", slice: locale)?.probability(r.m.maxRiskSeen) {
                preds.append(p); labels.append(r.pair.annotation.finalLabel <= 1)
            }
        }
        let (ece, brier, bins) = CalibrationMetricsV1.eceAndBins(preds: preds, labels: labels)
        print("P009E_RISK_CAL ece=\(String(format: "%.3f", ece)) brier=\(String(format: "%.3f", brier)) bins=\(bins.count) auroc=\(CalibrationMetricsV1.auroc(preds: preds, labels: labels).map { String(format: "%.2f", $0) } ?? "n/a")")
        XCTAssertFalse(preds.isEmpty)
    }
    func testHeldOutFinalRunOnce() {
        let (mae, n, abstained) = evalMAE(.heldOutFinal)
        print("P009E_HELDOUT_FINAL n=\(n) abstained=\(abstained) ordinalMAE=\(String(format: "%.3f", mae))")
        XCTAssertGreaterThan(n, 0)
        XCTAssertLessThanOrEqual(mae, 1.5, "held-out engineering gate")
    }
    func testStressAndOOD() {
        // stress: vetoes dominate regardless of fusion output
        for r in results(.stress) {
            let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            if r.d.state == .strongProtection || r.d.state == .ageRestricted {
                XCTAssertTrue(c.score == nil || c.score! <= 10, "\(r.pair.itemID): veto caps")
                XCTAssertEqual(c.interpretation, c.score == nil ? c.interpretation : "PROTECTED")
            }
        }
        // OOD: abstain — nil score, UNKNOWN state class
        for r in results(.ood) {
            let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            XCTAssertNil(c.score, "\(r.pair.itemID): OOD/unknown must abstain")
            XCTAssertNotNil(c.abstentionReason)
        }
    }
    func testSentinelNoFalseSafe() {
        var falseSafe = 0
        for r in results(.safetySentinel) {
            let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
            let positive = (c.score ?? 0) >= 62.5 && c.interpretation == "ALIGNED-CANDIDATE"
            let neutralState = r.d.state == .neutral
            if positive || (neutralState && r.pair.annotation.finalLabel == 0) { falseSafe += 1 }
        }
        print("P009E_SENTINEL n=\(results(.safetySentinel).count) falseSafe=\(falseSafe)")
        XCTAssertEqual(falseSafe, 0, "sentinel no-false-safe law")
    }

    // ── §27 law tests ──
    func testVetoCannotBeOverriddenByScore() {
        guard let r = results(.stress).first(where: { $0.d.state == .strongProtection }) else { return XCTFail() }
        let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
        if let s = c.score { XCTAssertLessThanOrEqual(s, 10) }
        XCTAssertNotEqual(c.interpretation, "ALIGNED-CANDIDATE")
    }
    func testScoreConfidenceCoverageAreSeparate() {
        guard let r = results(.calibration).first(where: { $0.d.state == .neutral || $0.d.state == .caution }) else { return XCTFail() }
        let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
        XCTAssertNotNil(c.score)
        XCTAssertTrue(["none", "low", "medium", "high"].contains(c.scoreConfidence), "confidence is categorical, not the score")
        XCTAssertTrue(c.evidenceCoverage >= 0 && c.evidenceCoverage <= 1)
        XCTAssertNotEqual(String(describing: c.score), c.scoreConfidence)
    }
    func testNilScoreUnderInsufficientEvidenceAndUnsupportedLocale() {
        guard let r = results(.calibration).first else { return XCTFail() }
        let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: "ja")
        XCTAssertNil(c.score); XCTAssertEqual(c.abstentionReason, "language-slice-unsupported")
    }
    func testSameDNAMultipleProfiles() {
        // one expensive understanding → many cheap personal decisions with DIFFERENT outcomes
        let brain = makeBrain()
        // moderate-risk content: strong-risk items CORRECTLY protect every profile (no divergence there),
        // so divergence is asserted on fear-band content where child policy differs from adult
        let s = P009DPolicyCorpusV1.scenarios(.tune).first { $0.name == "pd-child-fear" }!
        let semantic = P009CScenarioV1(name: s.name, family: s.family, segments: s.segments, annotation: P009CAnnotationV1())
        let m = P009CCorpusV1.run(semantic, brain: brain, item: ContentItemID(20_000))
        // P009E-R1 A8-F5: assert DISTINCT STATE VALUES (the old profileID-prefixed set could never fail)
        var byProfile: [String: AdmissionStateV1] = [:]
        for p in ProfileFixtureV1.all {
            let d = AdmissionPolicyPipelineV1.evaluate(worldModel: m, childProfile: p.childProfile,
                                                       parentPreference: p.parentPreference,
                                                       shieldConfig: p.shieldConfig, nowMs: 0)
            byProfile[p.profileID] = d.state
        }
        let distinctStates = Set(byProfile.values.map { $0.rawValue })
        XCTAssertGreaterThanOrEqual(distinctStates.count, 2, "genuinely different STATES on the same DNA: \(byProfile)")
        XCTAssertNotEqual(byProfile["adult-neutral"], byProfile["parent-child9-tr"],
                          "child policy must diverge from adult on sensitive news")
    }
    func testScoreCacheIsolationAndVersionInvalidation() {
        let cache = ScoreCacheV1()
        guard let r = results(.calibration).first else { return XCTFail() }
        let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
        let fp = ScoreCacheV1.fingerprint(calibrationVersion: CalibrationRegistryV2.version,
                                          fusionVersion: SuitabilityFusionModelV1.version,
                                          profileID: r.pair.profile.profileID, shieldVersion: ShieldConfigV2.version,
                                          ageRegistry: JurisdictionAgeBandRegistryV1.version,
                                          wmVersion: ContentWorldModelV1.modelVersion)
        cache.insert(profileID: r.pair.profile.profileID, item: ContentItemID(1), fp: fp, candidate: c)
        XCTAssertNotNil(cache.lookup(profileID: r.pair.profile.profileID, item: ContentItemID(1), fp: fp))
        XCTAssertNil(cache.lookup(profileID: "other-user", item: ContentItemID(1), fp: fp), "cross-user impossible")
        let fp2 = ScoreCacheV1.fingerprint(calibrationVersion: "calibration-registry-v3-FUTURE",
                                           fusionVersion: SuitabilityFusionModelV1.version,
                                           profileID: r.pair.profile.profileID, shieldVersion: ShieldConfigV2.version,
                                           ageRegistry: JurisdictionAgeBandRegistryV1.version,
                                           wmVersion: ContentWorldModelV1.modelVersion)
        XCTAssertNil(cache.lookup(profileID: r.pair.profile.profileID, item: ContentItemID(1), fp: fp2),
                     "calibration version change invalidates")
    }
    func testScoreMonotonicityInRisk() {
        let f = Self.fittedFusion!
        let lo = f.predictRubric(risk: 0.1, benefit: 0.5, manip: 0.2, shieldHard: false, childRestrictive: false)
        let hi = f.predictRubric(risk: 0.9, benefit: 0.5, manip: 0.2, shieldHard: false, childRestrictive: false)
        XCTAssertLessThanOrEqual(hi, lo + 1e-9, "suitability non-increasing in calibrated risk")
        XCTAssertLessThanOrEqual(f.wRisk, 0); XCTAssertGreaterThanOrEqual(f.wBenefit, 0)
    }
    func testLowCoverageHighScorePrevented() {
        // empty-modality model → coverage 0 → abstain (never a confident high score)
        guard let r = results(.ood).first(where: { $0.pair.itemID == "od-empty-content" }) else { return XCTFail() }
        let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: "en")
        XCTAssertNil(c.score)
    }
    func testReleaseGateClosedWithTruthfulConditions() {
        let (open, conditions) = ProductionScoreReleaseGateV1.evaluate()
        XCTAssertFalse(open, "release gate CLOSED in P009E")
        XCTAssertEqual(conditions.count, 10)
        XCTAssertFalse(conditions.first { $0.name.contains("rights-clear") }!.met)
        XCTAssertFalse(conditions.first { $0.name.contains("device") }!.met)
        XCTAssertFalse(conditions.first { $0.name.contains("independent") }!.met)
        print("P009E_RELEASE_GATE open=false unmet=\(conditions.filter { !$0.met }.count)/10")
    }
    func testProductionDisplayStillOff() {
        XCTAssertFalse(Self.fittedRegistry.productionDisplayAllowed())
        XCTAssertFalse(GuardianMetaBrainV2().calibration.scoreDisplayAllowed(), "P009B skeleton untouched + refusing")
    }
    func testTeenSentinelScorePathFailsClosed() {
        guard let r = results(.safetySentinel).first(where: { $0.pair.corpus == "P009E_TEEN" }) else { return XCTFail() }
        XCTAssertEqual(r.d.childOutcome, .unknownReview)
        let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: "en")
        XCTAssertNil(c.score, "teen sentinel fail-closed → REVIEW → abstain")
    }
    func testAnnotationDisagreementAndAdjudicationTrace() {
        let disagreements = CalibrationDatasetRegistryV2.pairs.filter { $0.annotation.disagreement }
        XCTAssertGreaterThan(disagreements.count, 3, "disagreement preserved, not hidden")
        let adjudicated = CalibrationDatasetRegistryV2.pairs.filter { $0.annotation.adjudicated != nil }
        XCTAssertGreaterThan(adjudicated.count, 0)
        for p in adjudicated { XCTAssertGreaterThanOrEqual(abs(p.annotation.labelA - p.annotation.labelB), 1) }
    }
    func testNoRawPrivateDataInScoreOutputs() {
        guard let r = results(.calibration).first else { return XCTFail() }
        let c = engine().evaluate(worldModel: r.m, decision: r.d, profile: r.pair.profile, locale: r.pair.annotation.locale)
        let strings = c.explanation.topDimensions + c.explanation.policyVetoes + c.explanation.versionProvenance
            + [c.interpretation, c.calibrationStatus, c.oodStatus]
        XCTAssertFalse(strings.contains { $0.count > 200 }, "structured short fields only — no prose/raw text")
    }
}
