import XCTest
@testable import GuardianCore

final class WholeVideoTests: XCTestCase {

    // §3 sampler budget bounds + MAX/ECO/BALANCED routing
    func testSamplerBoundedAndModeScaled() {
        let s = WholeVideoSampler()
        let eco = s.plan(durationSeconds: 3600, mode: .eco)
        let bal = s.plan(durationSeconds: 3600, mode: .balanced)
        let mx = s.plan(durationSeconds: 3600, mode: .maxProtection)
        XCTAssertLessThan(eco.timestampsSeconds.count, mx.timestampsSeconds.count)   // ECO < MAX
        XCTAssertLessThanOrEqual(mx.timestampsSeconds.count, 100)                     // bounded even for 1h
        XCTAssertFalse(bal.timestampsSeconds.isEmpty)
    }
    func testSamplerShortVsLongStrategy() {
        let s = WholeVideoSampler()
        XCTAssertTrue(s.plan(durationSeconds: 15, mode: .balanced).strategy.contains("short-dense"))
        XCTAssertTrue(s.plan(durationSeconds: 1800, mode: .balanced).strategy.contains("long-coarse"))
    }

    // §4 scene/shot boundary detection
    func testSceneBoundaryHardCutVsStatic() {
        let d = SceneBoundaryDetectorV1()
        func f(_ t: Double, _ v: Double) -> FrameDescriptor { FrameDescriptor(timestampSeconds: t, features: [v, v, v, v]) }
        // static scene → no boundary; hard cut (big feature jump) → boundary.
        let staticSeq = [f(0,0.2), f(2,0.21), f(4,0.2)]
        XCTAssertTrue(d.detect(staticSeq).isEmpty)
        let cut = [f(0,0.1), f(2,0.1), f(4,0.9)]
        XCTAssertFalse(d.detect(cut).isEmpty)
    }
    func testSceneBoundaryMinGapSuppressesDuplicates() {
        let d = SceneBoundaryDetectorV1(threshold: 0.3, minGapSeconds: 5)
        func f(_ t: Double, _ v: Double) -> FrameDescriptor { FrameDescriptor(timestampSeconds: t, features: [v]) }
        let rapid = [f(0,0.0), f(1,0.9), f(2,0.0), f(3,0.9)]   // flicker within min gap
        XCTAssertLessThanOrEqual(d.detect(rapid).count, 1)     // suppressed
    }

    // §5/§6 coverage + confidence eligibility
    func testScoreEligibilityGates() {
        let good = WholeVideoConfidence(signalConfidence: 0.8, segmentConfidence: 0.8, videoCoverage: 0.9,
                                        identityConfidence: 0.95, policyConfidence: 0.9)
        XCTAssertTrue(good.overallScoreEligible(minCoverage: 0.6, minIdentity: 0.8, unresolvedConflict: false))
        let lowCov = WholeVideoConfidence(signalConfidence: 0.8, segmentConfidence: 0.8, videoCoverage: 0.3,
                                          identityConfidence: 0.95, policyConfidence: 0.9)
        XCTAssertFalse(lowCov.overallScoreEligible(minCoverage: 0.6, minIdentity: 0.8, unresolvedConflict: false))
        let conflict = WholeVideoConfidence(signalConfidence: 0.8, segmentConfidence: 0.8, videoCoverage: 0.9,
                                            identityConfidence: 0.95, policyConfidence: 0.9)
        XCTAssertFalse(conflict.overallScoreEligible(minCoverage: 0.6, minIdentity: 0.8, unresolvedConflict: true))
    }

    // §15 deepening: high-risk/uncertain deepened; low-risk early exit
    func testDeepeningPrioritizesUncertainFlaggedAndEarlyExits() {
        let flagged = CoarseWindow(startSeconds: 10, endSeconds: 20, sampled: true, deepened: false,
                                   categories: [.violentConflict], uncertainty: 0.9, value: 0.3)
        let calm = CoarseWindow(startSeconds: 20, endSeconds: 30, sampled: true, deepened: false,
                                categories: [], uncertainty: 0.05, value: 0.8)
        let map = CoarseTemporalMapV1(contentID: .init("v"), versionTag: "v1", windows: [calm, flagged], coverage: WholeVideoCoverage())
        let plan = DeepeningPlannerV1().plan(map: map, playheadSeconds: 0, maxDeepen: 1)
        XCTAssertEqual(plan.first, 1)                           // flagged/uncertain window wins
        // All-calm, near-zero uncertainty → nothing worth deepening.
        let calmMap = CoarseTemporalMapV1(contentID: .init("v"), versionTag: "v1", windows: [calm], coverage: WholeVideoCoverage())
        XCTAssertTrue(DeepeningPlannerV1().plan(map: calmMap, playheadSeconds: 0, maxDeepen: 3).isEmpty)
    }

    // §16 analysis-ahead v2 degradation
    func testAnalysisAheadBehindDegrades() {
        let a = AnalysisAheadV2()
        let lead = a.lead(playhead: 100, coarseUntil: 105, deepUntil: 102, safetyMarginSeconds: 10)
        XCTAssertTrue(lead.behind)
        XCTAssertEqual(a.actionWhenBehind(strictControlledSurface: true), .strictHold)
        XCTAssertEqual(a.actionWhenBehind(strictControlledSurface: false), .cautionUnknown)
    }

    // §13 temporal fusion v2: modality disagreement + missing modality unknown
    func testFusionModalityConflictLowersConfidenceAndMissingUnknown() {
        let f = TemporalFusionV2()
        let conflict = f.fuseWindow(WindowSignals(startSeconds: 0, endSeconds: 10, visualCategories: [.gore],
                                                  textCategories: [], visualAvailable: true, textAvailable: true))
        XCTAssertTrue(conflict.modalityConflict)
        XCTAssertLessThan(conflict.confidence, 0.85)
        let missing = f.fuseWindow(WindowSignals(startSeconds: 0, endSeconds: 10, visualAvailable: false, textAvailable: false))
        XCTAssertTrue(missing.categories.isEmpty)
        XCTAssertLessThanOrEqual(missing.confidence, 0.15)     // UNKNOWN
    }

    // §25 personal projection reuses shared map (no re-analysis)
    func testPersonalProjectionOverSharedMap() {
        let flagged = CoarseWindow(startSeconds: 0, endSeconds: 30, sampled: true, deepened: false,
                                   categories: [.disease], uncertainty: 0.2, value: 0.6)
        let map = CoarseTemporalMapV1(contentID: .init("v"), versionTag: "v1", windows: [flagged], coverage: WholeVideoCoverage())
        var p = GuardianLabFixtures.defaultProfile; p.positiveExposure = PositiveExposurePolicy(avoid: [.disease])
        let out = PersonalProjectionLayer().project(map: map, profile: p, positiveMode: .protectedPositive,
                                                    childPolicy: .init(), availableHeadCount: 3)
        XCTAssertEqual(out.reasons.first, .positiveExposureDisease)   // cheap personal decision over reuse
    }

    // §22 model pack supply chain
    func testModelPackChecksumAndRollbackGate() {
        let entry = ModelPackEntry(task: "mdd", modelId: "mdd-linear-v1", checksum: "abc", sizeBytes: 100,
                                   runtime: "swift-linear", minOS: "iOS17", resourceClass: "TINY",
                                   calibrationVersion: nil, license: "OWNED", rollbackArtifact: "mdd-linear-v0")
        let pack = ModelPackManifest(packId: "gen8-lab", version: "v1", models: [entry])
        XCTAssertTrue(pack.activationEligible(entry))
        XCTAssertTrue(pack.verify(modelId: "mdd-linear-v1", actualChecksum: "abc"))
        XCTAssertFalse(pack.verify(modelId: "mdd-linear-v1", actualChecksum: "corrupt"))   // checksum failure
        let noRollback = ModelPackEntry(task: "x", modelId: "y", checksum: "c", sizeBytes: 1, runtime: "r",
                                        minOS: "iOS17", resourceClass: "TINY", calibrationVersion: nil, license: "OWNED", rollbackArtifact: "")
        XCTAssertFalse(pack.activationEligible(noRollback))   // no rollback → cannot activate
    }

    // §23 ContentDNA V3 round-trip
    func testContentDNAV3RoundTrip() throws {
        var dna = ContentDNAV1(contentID: "v1", identityState: "I4_VERIFIED", versionTag: "v1", rightsState: "OWNED")
        var cov = WholeVideoCoverage(); cov.visualPercent = 40; cov.unknownRegionPercent = 30
        dna.coverage = cov; dna.sceneBoundarySeconds = [12.0, 48.0]; dna.deepenedWindowSeconds = [48.0]
        dna.modelPackVersion = "gen8-lab-v1"
        let back = try JSONDecoder().decode(ContentDNAV1.self, from: JSONEncoder().encode(dna))
        XCTAssertEqual(dna, back)
        XCTAssertEqual(back.coverage?.visualPercent, 40)
    }
}
