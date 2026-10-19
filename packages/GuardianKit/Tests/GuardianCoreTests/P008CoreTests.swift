import XCTest
@testable import GuardianCore

final class P008CoreTests: XCTestCase {

    // helper: a topic evidence signal
    private func topic(_ m: Modality, _ v: String, conf: Double) -> ModalEvidenceSignal {
        ModalEvidenceSignal(modality: m, kind: "topic", value: v, rawConfidence: conf, calibratedConfidence: conf,
                            evidenceClass: .modelInference, modelID: "test", modelRevision: "r1")
    }

    // §2 understanding carries provenance; evidence(for:) filters by modality.
    func testUnderstandingProvenance() {
        var u = MultimodalContentUnderstandingV1(contentID: "c1")
        u.evidence = [topic(.ocr, "earthquake", conf: 0.8), topic(.speech, "earthquake", conf: 0.7)]
        XCTAssertEqual(u.evidence(for: .ocr).count, 1)
        XCTAssertEqual(u.evidence.first?.modelRevision, "r1")   // no naked label — every signal has a revision
    }

    // §14 cross-modal: agreement across modalities BOOSTS (not averages); a conflict pair PENALIZES both.
    func testCrossModalAgreementBoostAndConflictPenalty() {
        var u = MultimodalContentUnderstandingV1(contentID: "c")
        u.evidence = [topic(.ocr, "earthquake", conf: 0.6), topic(.speech, "earthquake", conf: 0.6),
                      topic(.caption, "funny-cats", conf: 0.7), topic(.visual, "political-rally", conf: 0.7)]
        let g = CrossModalEvidenceFuser.build(u, conflictPairs: [("funny-cats", "political-rally")])
        // Agreement: earthquake seen by 2 modalities → fused > the single-modality base (0.6), NOT the 0.6 average.
        let eq = g.concept("earthquake")!
        XCTAssertTrue(eq.agreement)
        XCTAssertGreaterThan(eq.fusedConfidence, 0.6)
        // Conflict: both sides penalized (ambiguous content), not silently averaged.
        XCTAssertTrue(g.conflicts.contains("funny-cats<x>political-rally"))
        XCTAssertLessThan(g.concept("funny-cats")!.fusedConfidence, 0.7)
        XCTAssertTrue(g.concept("political-rally")!.conflict)
    }

    private func dims(_ pairs: [SuitabilityDimension: Double], unavailable: [SuitabilityDimension] = []) -> [SuitabilityDimension: SuitabilityFusionInput.Dim] {
        var d: [SuitabilityDimension: SuitabilityFusionInput.Dim] = [:]
        for (k, v) in pairs { d[k] = .init(v, available: !unavailable.contains(k)) }
        return d
    }
    private func fuse(_ input: SuitabilityFusionInput) -> PersonalSuitabilityScoreV1 {
        SuitabilityFusionV1().fuse(input, policyRevision: "pol-v1", contentDNARevision: "dna-v5", modelPackRevision: "pack-v1")
    }

    // §16/§19 — insufficient coverage ⇒ score nil + UNKNOWN (never a fabricated 7.4).
    func testInsufficientCoverageIsUnknown() {
        let r = fuse(.init(dims: dims([.safetyAlignment: 0.9], unavailable: []), evidenceConfidence: 0.3,
                           calibrationValid: true, minCoverage: 0.5))
        XCTAssertNil(r.score); XCTAssertEqual(r.scoreBand, .unknown); XCTAssertEqual(r.admissionState, .unknown)
    }

    // §16 — calibration invalid ⇒ UNKNOWN (no calibrated number shown).
    func testCalibrationGate() {
        let full = dims([.safetyAlignment: 0.9, .topicAlignment: 0.8, .benefit: 0.7, .positiveExposure: 0.6, .attentionPressure: 0.1, .emotionalLoad: 0.1])
        let r = fuse(.init(dims: full, evidenceConfidence: 0.9, calibrationValid: false, minCoverage: 0.5))
        XCTAssertNil(r.score); XCTAssertEqual(r.scoreBand, .unknown)
        XCTAssertTrue(r.reasonCodes.contains(.calibrationUnavailable))
    }

    // §18 — hard Shield / safety floor precedence overrides numeric score (NOT_RECOMMENDED even if benefit high).
    func testHardShieldAndSafetyFloorPrecedence() {
        let full = dims([.safetyAlignment: 0.9, .topicAlignment: 0.9, .benefit: 0.95, .positiveExposure: 0.8, .attentionPressure: 0.0, .emotionalLoad: 0.0])
        let shield = fuse(.init(dims: full, evidenceConfidence: 0.9, hardShieldMatch: true, calibrationValid: true))
        XCTAssertEqual(shield.scoreBand, .strongProtection); XCTAssertNil(shield.score)
        XCTAssertTrue(shield.reasonCodes.contains(.hardShield))
        let floor = fuse(.init(dims: full, evidenceConfidence: 0.9, safetyFloorViolation: true, calibrationValid: true))
        XCTAssertEqual(floor.scoreBand, .strongProtection); XCTAssertEqual(floor.admissionState, .hideIfControlled)
    }

    // §19 — SCORE ≠ CONFIDENCE: high suitability can coexist with low evidence confidence, and vice-versa.
    func testScoreIsNotConfidence() {
        let good = dims([.safetyAlignment: 0.95, .topicAlignment: 0.9, .benefit: 0.85, .positiveExposure: 0.8, .attentionPressure: 0.05, .emotionalLoad: 0.05])
        let highSuitLowConf = fuse(.init(dims: good, evidenceConfidence: 0.2, calibrationValid: true))
        XCTAssertNotNil(highSuitLowConf.score); XCTAssertGreaterThanOrEqual(highSuitLowConf.score!, 60)
        XCTAssertEqual(highSuitLowConf.confidence, 0.2)   // confidence is reported SEPARATELY, not as the score
        let bad = dims([.safetyAlignment: 0.2, .topicAlignment: 0.1, .benefit: 0.1, .positiveExposure: 0.2, .attentionPressure: 0.9, .emotionalLoad: 0.9])
        let lowSuitHighConf = fuse(.init(dims: bad, evidenceConfidence: 0.95, calibrationValid: true))
        XCTAssertNotNil(lowSuitHighConf.score); XCTAssertLessThan(lowSuitHighConf.score!, 40)
        XCTAssertEqual(lowSuitHighConf.confidence, 0.95)
        XCTAssertTrue(lowSuitHighConf.reasonCodes.contains(.safetyCap))   // low safety alignment caps suitability
    }

    // §28 — stability: same input ⇒ identical score (deterministic, reproducible).
    func testScoreStability() {
        let d = dims([.safetyAlignment: 0.7, .topicAlignment: 0.6, .benefit: 0.5, .positiveExposure: 0.5, .attentionPressure: 0.2, .emotionalLoad: 0.2])
        let a = fuse(.init(dims: d, evidenceConfidence: 0.8, calibrationValid: true))
        let b = fuse(.init(dims: d, evidenceConfidence: 0.8, calibrationValid: true))
        XCTAssertEqual(a.score, b.score); XCTAssertEqual(a.scoreBand, b.scoreBand)
    }

    // §12 boundary V2: same-video motion (text persists, small drift) ≠ NEW; real swipe (layout jump, no text overlap) = NEW.
    func testContentBoundaryV2() {
        let det = ContentBoundaryDetectorV2()
        _ = det.classify(.init(signature: .init(bits: 0x0F0F_0F0F_0F0F_0F0F), layoutSignature: 0xAAAA, topTextTokens: ["reel", "dance"]))
        // small perceptual drift + same layout + persistent text → motion within the SAME item
        let same = det.classify(.init(signature: .init(bits: 0x0F0F_0F0F_0F0F_0F1F), layoutSignature: 0xAAAA, topTextTokens: ["reel", "dance"]))
        XCTAssertTrue(same == .sameContent || same == .likelySame)
        // big perceptual change + layout jump + no text overlap → NEW item
        let new = det.classify(.init(signature: .init(bits: 0xF0F0_F0F0_F0F0_F0F0), layoutSignature: 0x5555, topTextTokens: ["other"]))
        XCTAssertEqual(new, .newContent)
    }

    // §12 benchmark: a 2-item sequence → detector should not over-fire (bounded false-boundary rate).
    func testBoundaryBenchmark() {
        let det = ContentBoundaryDetectorV2()
        var frames: [BoundaryFrameInput] = []
        var labels: [Bool] = []
        // item A: 5 frames (first is boundary), item B: 5 frames (first is boundary)
        for i in 0..<5 { frames.append(.init(signature: .init(bits: UInt64(0x1111 + i)), layoutSignature: 0xAAAA, topTextTokens: ["a"])); labels.append(i == 0) }
        for i in 0..<5 { frames.append(.init(signature: .init(bits: UInt64(0xF000_0000_0000 + UInt64(i))), layoutSignature: 0x5555, topTextTokens: ["b"])); labels.append(i == 0) }
        let r = BoundaryBenchmark.run(det, frames: frames, labeledIsNewBoundary: labels)
        XCTAssertEqual(r.trueBoundaries, 2)
        XCTAssertLessThanOrEqual(r.falseBoundaries, 2)   // bounded false-positive firing
    }

    // §13 identity V2: provider→EXACT(reuse); multi-signal→STRONG(reuse); single→PROVISIONAL(no reuse); none→UNKNOWN.
    func testContentIdentityV2() {
        XCTAssertEqual(ContentIdentityResolverV2.resolve(.init(providerID: "yt:abc")).confidence, .exact)
        XCTAssertTrue(ContentIdentityResolverV2.resolve(.init(providerID: "yt:abc")).mayReuseContentDNA)
        let strong = ContentIdentityResolverV2.resolve(.init(textSignature: "t", visualSignature: 123))
        XCTAssertEqual(strong.confidence, .strong); XCTAssertTrue(strong.mayReuseContentDNA)
        let prov = ContentIdentityResolverV2.resolve(.init(visualSignature: 123))
        XCTAssertEqual(prov.confidence, .provisional); XCTAssertFalse(prov.mayReuseContentDNA)  // never reuse weak identity
        XCTAssertEqual(ContentIdentityResolverV2.resolve(.init()).confidence, .unknown)
    }

    // §21 calibration metrics behave; false-safe is surfaced (not hidden by a high average).
    func testCalibrationMetrics() {
        let prf = CalibrationMetrics.precisionRecallF1(tp: 8, fp: 2, fn: 2)
        XCTAssertEqual(prf.precision, 0.8, accuracy: 0.001); XCTAssertEqual(prf.recall, 0.8, accuracy: 0.001)
        // Predicted safe on 2 of 3 actually-unsafe items → false-safe rate 2/3, regardless of overall accuracy.
        let fs = CalibrationMetrics.falseSafeRate(predictedSafe: [true, true, false], groundTruthSafe: [false, false, false])
        XCTAssertEqual(fs, 2.0/3.0, accuracy: 0.001)
        XCTAssertEqual(CalibrationMetrics.mae(predicted: [0.5, 0.5], truth: [0.0, 1.0]), 0.5, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(CalibrationMetrics.ece(confidences: [0.9, 0.8], correct: [false, false]), 0.0)
    }
}
