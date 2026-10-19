import XCTest
@testable import GuardianCore

// REAL-WORLD CALIBRATION ENTRY GATE — fresh tests for A9-R1-F1/F2/F3 (additive; AUDIT9 untouched
// except the single pre-declared F3 inversion).

final class RealWorldCalibrationEntryGateTests: XCTestCase {
    func brain() -> GuardianMetaBrainV2 {
        let b = GuardianMetaBrainV2()
        b.registry.register(VisionExpertV1()); b.registry.register(LanguageOCRExpertV1())
        b.registry.register(SpeechExpertV1()); b.registry.register(AudioEventExpertV1())
        b.registry.register(MusicExpertV1()); b.registry.register(SymbolExpertV1())
        b.registry.register(TemporalExpertV1()); b.registry.register(SafetyEvidenceExpertV1())
        b.registry.register(BenefitEvidenceExpertV1()); b.registry.register(AttentionPressureExpertV1())
        return b
    }
    func run(_ text: String, lang: String, risk: Double, child: GuardianEnteredChildProfileV1?,
             shield: ShieldConfigV2? = nil, parent: ParentPreferencePolicyV1 = ParentPreferencePolicyV1(),
             item: UInt64) -> AdmissionStateCandidateV1 {
        let seg = [P009CSegmentV1(startMs: 0, endMs: 3000,
                                  input: ExpertInputV2(ocrText: text, detectedLanguage: lang),
                                  temporalRisk: risk, temporalTopics: ["t"])]
        let sc = P009DPolicyScenarioV1(name: "eg-\(item)", family: "entry-gate", segments: seg,
                                       childProfile: child, parentPreference: parent,
                                       shieldConfig: shield, annotation: P009DPolicyAnnotationV1())
        return P009DPolicyCorpusV1.run(sc, brain: brain(), item: ContentItemID(item)).1
    }
    func teen(_ a: Int = 14) -> GuardianEnteredChildProfileV1 { .init(ageYears: a, jurisdictionCode: "TR", enteredByGuardian: true) }

    // ── F1 matrix: unbanded/unavailable never AGE_ALIGNED; genuine aligned still possible ──
    func testF1_TeenSevereViolenceNeverAligned() {
        for age in [13, 14, 17] {
            let d = run("savaş görüntüleri: ölüm, bombardıman ve yıkım", lang: "tr", risk: 0.9,
                        child: teen(age), item: UInt64(9000 + age))
            XCTAssertNotEqual(d.childOutcome, .aligned, "age \(age): unbanded strong-violence can never be AGE_ALIGNED")
            XCTAssertEqual(d.childOutcome, .unknownReview)
            XCTAssertEqual(d.state, .strongProtection, "safety state unchanged — no loosening")
        }
    }
    func testF1_SafetyMatrixUnchanged() {
        // sexual sentinel (teen) → review via teen law (regression)
        let s = run("explicit adult romance scenes compilation", lang: "en", risk: 0, child: teen(14), item: 9100)
        XCTAssertEqual(s.childOutcome, .unknownReview)
        // under-13 H1 law intact
        let u = run("funny cartoon chase lol", lang: "en", risk: 0, child: teen(9), item: 9101)
        XCTAssertEqual(u.childOutcome, .unknownReview)
        // fear/threat banded behavior intact (teen 13 aligned-capable on sub-strong fear)
        let f = run("korku hikayesi tehlike", lang: "tr", risk: 0.4, child: teen(13), item: 9102)
        XCTAssertEqual(f.childOutcome, .aligned, "banded sub-strong evidence may still be ALIGNED (missing != negative)")
        // teen strict parent → restricted on sensitive news (unchanged)
        let p = run("news brief: hospital disease report", lang: "en", risk: 0, child: teen(14),
                    parent: ParentPreferencePolicyV1(blockSensitiveNews: true), item: 9103)
        XCTAssertEqual(p.childOutcome, .restricted)
        // adult path untouched; shield precedence untouched
        let a = run("savaş ölüm yıkım", lang: "tr", risk: 0.9, child: nil,
                    shield: ShieldConfigV2(blockedConcepts: ["concept:mortality"]), item: 9104)
        XCTAssertNil(a.childOutcome); XCTAssertEqual(a.state, .strongProtection)
        // benign control: teen stays genuinely alignable
        let b = run("bilim dersi: deney rehberi anlat", lang: "tr", risk: 0, child: teen(15), item: 9105)
        XCTAssertEqual(b.childOutcome, .aligned)
        XCTAssertNotEqual(b.state, .strongProtection)
    }

    // ── F2: declared != resolved → typed refusal; fit/metrics never invoked ──
    func testF2_FullResolutionSucceeds() throws {
        let ids = CalibrationDatasetRegistryV2.pairs.map { $0.itemID + "#" + $0.profile.profileID }
        try CalibrationRunGuardV1.requireFullResolution(declaredIDs: ids, resolvedIDs: ids)
    }
    func testF2_SilentDropImpossible() {
        let declared = ["a#p", "b#p", "phantom-item#p"]
        let resolved = ["a#p", "b#p"]
        var fitterCalled = false
        do {
            try CalibrationRunGuardV1.requireFullResolution(declaredIDs: declared, resolvedIDs: resolved)
            fitterCalled = true   // would be the fit/metric entrypoint
            XCTFail("must throw")
        } catch let e as CalibrationIntegrityErrorV1 {
            guard case let .unresolvedPairs(d, r, ids, cat) = e else { return XCTFail() }
            XCTAssertEqual(d, 3); XCTAssertEqual(r, 2); XCTAssertEqual(ids, ["phantom-item#p"])
            XCTAssertEqual(cat, "scenario-resolution")
        } catch { XCTFail("typed error required") }
        XCTAssertFalse(fitterCalled, "58/59-style partial metrics are impossible — fitter never runs")
        // alias-to-missing / malformed references are the same contract
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["ALIAS:ghost#p"], resolvedIDs: []))
    }

    // ── F3: domain contract — typed refusal; no drop; no double count; boundaries exact ──
    func testF3_InvalidDomainHardRefusal() {
        for bad in [-0.001, 1.001, Double.nan, .infinity, -.infinity, -Double.leastNonzeroMagnitude] {
            XCTAssertThrowsError(try CalibrationMetricsV1.eceAndBinsStrict(preds: [0.5, bad], labels: [true, false]),
                                 "\(bad) must refuse") { err in
                XCTAssertTrue(err is MetricInputErrorV1)
            }
            let legacy = CalibrationMetricsV1.eceAndBins(preds: [bad], labels: [true])
            XCTAssertTrue(legacy.ece.isNaN && legacy.bins.isEmpty, "legacy path refuses via NaN marker, never clamps")
        }
        XCTAssertThrowsError(try CalibrationMetricsV1.eceAndBinsStrict(preds: [0.5], labels: []))
        XCTAssertThrowsError(try CalibrationMetricsV1.eceAndBinsStrict(preds: [0.5], labels: [true], bins: 0))
    }
    func testF3_ValidBoundariesExactlyOnce() throws {
        let preds = [0.0, 0.1, 0.2, 0.3, 0.5, 0.999999, 1.0, 0.3, 0.3]   // repeats + fp edges + inclusive 0/1
        let labels = [false, false, true, true, false, true, true, true, false]
        let r = try CalibrationMetricsV1.eceAndBinsStrict(preds: preds, labels: labels)
        XCTAssertEqual(r.bins.map { $0.count }.reduce(0, +), preds.count, "no drop, no double count")
        // bins=1: everything in one bin
        let one = try CalibrationMetricsV1.eceAndBinsStrict(preds: [0.2, 0.9], labels: [false, true], bins: 1)
        XCTAssertEqual(one.bins.count, 1); XCTAssertEqual(one.bins[0].count, 2)
        // hand calculation on a tiny fixture: preds [0.25(×2 → bin2), 0.75(×2 → bin7)], labels [T,F / T,T]
        let h = try CalibrationMetricsV1.eceAndBinsStrict(preds: [0.25, 0.25, 0.75, 0.75],
                                                          labels: [true, false, true, true])
        // ECE = 0.5*|0.25-0.5| + 0.5*|0.75-1.0| = 0.25 ; Brier = ((0.75²+0.25²)+(0.25²+0.25²))/4
        XCTAssertEqual(h.ece, 0.25, accuracy: 1e-12)
        XCTAssertEqual(h.brier, (0.5625 + 0.0625 + 0.0625 + 0.0625) / 4, accuracy: 1e-12)
        // historical valid-domain ECE unchanged by F3 (regression on the engineering fixture is suite-wide)
        XCTAssertNil(CalibrationMetricsV1.validateProbabilities([0, 0.3, 1]))
    }

    // ── locks regression ──
    func testLocksStillClosed() {
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().open)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertFalse(GuardianMetaBrainV2().calibration.scoreDisplayAllowed())
    }
}
