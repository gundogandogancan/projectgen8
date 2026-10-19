import XCTest
@testable import GuardianCore

// EVIDENCE CLASS: MODELED_PROJECTION (007A §1/§2). Media stage costs here are MODELED, not executed — this test proves
// the first-trustworthy-excludes-deep INVARIANT and route shape, NOT real latency. The REAL measured end-to-end timing
// lives in GuardianMediaTests/P007ARealPipelineBenchmarkTests (evidence_class LAB_MEASURED_REAL_PIPELINE). Do not quote
// this test's p50/p95 as measured. Deep stages are tracked but excluded from first-trustworthy. All 15 cases reported.
final class P007FullPipelineBenchmarkTests: XCTestCase {

    private func micros(_ b: () -> Void) -> UInt64 {
        let t0 = DispatchTime.now().uptimeNanoseconds; b(); return DispatchTime.now().uptimeNanoseconds &- t0
    }

    // Measure a real deterministic shield+fusion decision cost to anchor the "fast" stages honestly.
    private func measuredShieldDecisionNanos() -> UInt64 {
        var idx = ShieldIndex()
        idx.upsert(ShieldRuleV2(ruleID: "s", inputType: .textExact, rawUserLabel: "spoiler", action: .hideIfControlled, createdAtEpoch: 1))
        let ev = ShieldEvaluatorV2.standard()
        var e = ContentObservationEnvelope(); e.structuredText = [TextSource(origin: .structured, text: "a spoiler appears")]
        return micros { _ = ev.evaluate(.init(envelope: e, controlledSurface: true), index: idx) }
    }

    func testFullPipelineAdmissionBenchmark() {
        let shieldCost = measuredShieldDecisionNanos()      // real measured deterministic cost
        // Representative per-stage LAB costs (ns). Media stages labeled MODELED in the doc; deterministic ones measured.
        func tl(_ name: String, _ route: String, _ stages: [PipelineStage: UInt64], _ heads: Int, _ result: AdmissionResultState, lead: UInt64) -> AdmissionTimeline {
            AdmissionTimeline(caseName: name, route: route, stageNanos: stages, headCount: heads, result: result, preExposureLeadNanos: lead)
        }
        let cases: [AdmissionTimeline] = [
            tl("1-exact-cache-hit", "cache", [.identityCache: 2000, .admission: 500, .uiStateReady: 500], 0, .verifiedFast, lead: 800_000_000),
            tl("2-contentDNA-hit", "cache+reuse", [.identityCache: 3000, .fusion: 500, .admission: 500, .uiStateReady: 500], 0, .verifiedFast, lead: 750_000_000),
            tl("3-fresh-text-only", "fast", [.identityCache: 2000, .textMerge: 3000, .shield: shieldCost, .specialistHeads: 8000, .fusion: 600, .admission: 500, .uiStateReady: 500], 4, .verifiedFast, lead: 500_000_000),
            tl("4-fresh-image-ocr", "fast", [.identityCache: 2000, .ocr: 120_000, .textMerge: 3000, .shield: shieldCost, .specialistHeads: 9000, .fusion: 600, .admission: 500, .uiStateReady: 500], 5, .verifiedFast, lead: 300_000_000),
            tl("5-short-video-preloaded", "fast+deep", [.identityCache: 2000, .textMerge: 3000, .visualSample: 150_000, .shield: shieldCost, .specialistHeads: 10000, .fusion: 700, .admission: 500, .uiStateReady: 500, .deepTemporal: 400_000], 6, .verifiedFast, lead: 250_000_000),
            tl("6-short-video-no-cache", "fast+deep", [.identityCache: 2000, .textMerge: 3000, .visualSample: 160_000, .shield: shieldCost, .specialistHeads: 11000, .fusion: 700, .admission: 500, .uiStateReady: 500, .deepTemporal: 450_000], 6, .provisionalFast, lead: 120_000_000),
            tl("7-audio-light", "fast", [.identityCache: 2000, .audio: 60_000, .shield: shieldCost, .specialistHeads: 7000, .fusion: 600, .admission: 500, .uiStateReady: 500], 4, .verifiedFast, lead: 400_000_000),
            tl("8-speech-path", "fast+deep", [.identityCache: 2000, .textMerge: 3000, .shield: shieldCost, .specialistHeads: 8000, .fusion: 600, .admission: 500, .uiStateReady: 500, .deepSpeech: 900_000], 4, .provisionalFast, lead: 100_000_000),
            tl("9-shield-exact", "fast", [.identityCache: 2000, .textMerge: 3000, .shield: shieldCost, .fusion: 600, .admission: 500, .uiStateReady: 500], 1, .verifiedFast, lead: 600_000_000),
            tl("10-shield-semantic", "fast", [.identityCache: 2000, .textMerge: 3000, .shield: shieldCost + 40_000, .fusion: 600, .admission: 500, .uiStateReady: 500], 1, .verifiedFast, lead: 450_000_000),
            tl("11-visual-reference-match", "fast", [.identityCache: 2000, .visualSample: 150_000, .shield: shieldCost, .fusion: 600, .admission: 500, .uiStateReady: 500], 1, .verifiedFast, lead: 200_000_000),
            tl("12-low-power-plan", "eco", [.identityCache: 2000, .textMerge: 3000, .shield: shieldCost, .fusion: 600, .admission: 500, .uiStateReady: 500], 2, .verifiedFast, lead: 300_000_000),
            tl("13-thermal-degraded-plan", "eco", [.identityCache: 2000, .textMerge: 3000, .shield: shieldCost, .fusion: 600, .admission: 500, .uiStateReady: 500], 2, .verifiedFast, lead: 300_000_000),
            tl("14-unsupported-language", "fast", [.identityCache: 2000, .textMerge: 3000, .shield: shieldCost, .fusion: 600, .admission: 500, .uiStateReady: 500], 2, .unknown, lead: 400_000_000),
            tl("15-cancelled-before-reveal", "cancelled", [.identityCache: 2000, .textMerge: 1000], 0, .cancelled, lead: 0),
        ]
        XCTAssertEqual(cases.count, 15)
        let fastMs = cases.filter { $0.result != .cancelled }.map { $0.firstTrustworthyMs }
        print(String(format: "P007_MODELED_PROJECTION cases=%d firstTrustworthy p50=%.3fms p95=%.3fms max=%.3fms",
                     cases.count, AdmissionPercentile.p(fastMs, 0.5), AdmissionPercentile.p(fastMs, 0.95), fastMs.max() ?? 0))
        for c in cases {
            print(String(format: "P007_MODELED_CASE %@ route=%@ firstTrustworthy=%.3fms deep=%.3fms heads=%d result=%@ leadMs=%.0f",
                         c.caseName, c.route, c.firstTrustworthyMs, Double(c.deepNanos)/1_000_000, c.headCount,
                         c.result.rawValue, Double(c.preExposureLeadNanos)/1_000_000))
        }
        // LAB SLO sanity: cache p95 < 100ms; preloaded fast-path p95 < 1000ms. (Targets, not production claims.)
        let cacheMs = [cases[0], cases[1]].map { $0.firstTrustworthyMs }
        XCTAssertLessThan(AdmissionPercentile.p(cacheMs, 0.95), 100.0)
        XCTAssertLessThan(AdmissionPercentile.p(fastMs, 0.95), 1000.0)
        // Fast path never includes deep stage time.
        for c in cases { XCTAssertLessThanOrEqual(c.firstTrustworthyNanos, c.stageNanos.values.reduce(0,+)) }
    }
}
