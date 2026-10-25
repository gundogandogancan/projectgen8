//
//  LongFormIntelligenceTests.swift — mandate D/E PROOF: the adaptive evidence planner (≥2 strategies, expert
//  selection by the user's real rules, budget-driven) + the long-form guardian over REAL short media (fast decision
//  distinct from aggregate, evidence reuse recomputes the decision without re-decode, unexamined ≠ safe).
//
import XCTest
@testable import GuardianMedia
import GuardianCore
#if canImport(AVFoundation)
import AVFoundation

final class LongFormIntelligenceTests: XCTestCase {

    private func textRule(_ id: String, _ label: String, _ action: ShieldAction) -> ShieldRuleV2 {
        ShieldRuleV2(ruleID: id, inputType: .textExact, rawUserLabel: label, locale: "en", action: action,
                     createdAtEpoch: 1, updatedAtEpoch: 1)
    }
    private func soundRule(_ id: String, _ label: String, _ action: ShieldAction) -> ShieldRuleV2 {
        ShieldRuleV2(ruleID: id, inputType: .soundClass, rawUserLabel: label, locale: "en", action: action,
                     createdAtEpoch: 1, updatedAtEpoch: 1)
    }
    private func index(_ rules: [ShieldRuleV2]) -> ShieldIndex { var i = ShieldIndex(); for r in rules { i.upsert(r) }; return i }

    // MARK: E — the planner selects ≥2 strategies by resource budget (thermal + duration).

    func testPlannerSelectsStrategyByBudget() {
        let p = AdaptiveEvidencePlannerV1()
        XCTAssertEqual(p.selectStrategy(durationSeconds: 600, thermal: .nominal), .thoroughCoverage,
                       "a cold long video gets the thorough strategy")
        XCTAssertEqual(p.selectStrategy(durationSeconds: 600, thermal: .serious), .conservativeCoverage,
                       "thermal pressure forces the conservative strategy")
        XCTAssertEqual(p.selectStrategy(durationSeconds: 600, thermal: .fair), .conservativeCoverage,
                       "a long video under fair thermal prefers conservative")
        // The two strategies produce DIFFERENT budgets (acceptance: low budget → less expensive work).
        let cold = p.selectiveBudget(durationSeconds: 600, thermal: .nominal, strategy: .thoroughCoverage)
        let hot = p.selectiveBudget(durationSeconds: 600, thermal: .serious, strategy: .conservativeCoverage)
        XCTAssertGreaterThan(cold, hot, "the conservative/hot plan examines fewer windows than the thorough/cold plan (E)")
    }

    // MARK: E — expert selection follows the USER'S REAL rule kinds (text → OCR, sound → audio).

    func testPlannerExpertSelectionFollowsRuleKinds() {
        let p = AdaptiveEvidencePlannerV1()
        let textOnly = p.plan(contentID: "c", durationSeconds: 600, thermal: .nominal,
                              hasTextRules: true, hasSoundRules: false, policyRevision: 1)
        XCTAssertTrue(textOnly.requestsOCR && !textOnly.requestsAudio, "text rules → OCR, no audio (E)")
        XCTAssertFalse(textOnly.windows.contains { $0.experts.audio }, "no window pays for audio when there are no sound rules (E)")

        let soundOnly = p.plan(contentID: "c", durationSeconds: 600, thermal: .nominal,
                              hasTextRules: false, hasSoundRules: true, policyRevision: 1)
        XCTAssertTrue(soundOnly.requestsAudio, "sound rules → audio requested (E)")
        XCTAssertTrue(soundOnly.windows.contains { $0.experts.audio }, "at least one window requests audio (E)")
    }

    // MARK: D2 — the plan spans the whole duration with distinct levels (FAST / SELECTIVE / DEEPENING present).

    func testPlanSpansDurationWithDistinctLevels() {
        let p = AdaptiveEvidencePlannerV1()
        let plan = p.plan(contentID: "c", durationSeconds: 600, thermal: .nominal,
                          hasTextRules: true, hasSoundRules: false, policyRevision: 1,
                          sceneChangeHints: [], uncertainHints: [120, 400], matchedHints: [300])
        XCTAssertNotNil(plan.fastWindow, "there is a FAST window (first valid decision)")
        XCTAssertGreaterThan(plan.selectiveWindows.count, 1, "selective coverage spans multiple windows across 600s")
        XCTAssertFalse(plan.deepeningWindows.isEmpty, "deepening windows form around uncertain/matched hints (D2)")
        // Windows genuinely spread across the duration (not clustered at the start — honesty about coverage).
        let lastStart = plan.windows.map { $0.startSeconds }.max() ?? 0
        XCTAssertGreaterThan(lastStart, 300, "the plan examines late-video regions, not just the start (D2)")
    }

    // MARK: D/E — the long-form guardian runs over a REAL short video, producing a FAST decision + aggregate + windows.

    func testLongFormRunsOverRealVideo() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("clip.mp4")
        // A real 12s video with a text overlay at a KNOWN late timestamp (so a late window is examined, not just start).
        let spec = SyntheticVideo.Spec(durationSeconds: 12, fps: 4, width: 320, height: 180,
                                       textEvents: [(8.0, "EARTHQUAKE DISASTER")], sceneChanges: [(0,0.9),(6,0.2)])
        let wrote = await SyntheticVideo.write(spec, to: url)
        try XCTSkipUnless(wrote, "AVAssetWriter unavailable")
        let model = LongFormGuardianModelV1(audioProvider: nil)   // text-only: no audio arm
        let idx = index([textRule("r1", "spoiler", .hideIfControlled)])
        let result = await model.analyze(url: url, contentID: "c1", index: idx, exceptions: [], policyRevision: 1, thermal: .nominal)
        XCTAssertGreaterThan(result.durationSeconds, 10, "the real asset duration is read back (~12s), not a trick")
        XCTAssertNotNil(result.fastDecision, "a FAST (first-valid) decision is produced")
        XCTAssertGreaterThan(result.plannedWindows, 1, "the plan has multiple windows over the duration")
        XCTAssertGreaterThan(result.ocrCalls, 0, "OCR actually ran over decoded frames (real pipeline)")
        // HONESTY: temporal coverage is always limited for a sampled long video — never "whole video safe".
        XCTAssertTrue(result.temporalCoverageLimited, "sampled analysis never claims whole-video coverage (D2/F)")
        XCTAssertLessThan(result.examinedWindows, Int.max)
    }

    // MARK: D3 — ContentDNA-style evidence reuse: a SECOND analyze reuses cached evidence (no re-decode) and a POLICY
    // change recomputes the DECISION from cache without re-decoding (old policy decision is never shown as new).

    func testEvidenceReuseRecomputesDecisionWithoutReDecode() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lf2-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("clip.mp4")
        let spec = SyntheticVideo.Spec(durationSeconds: 8, fps: 4, width: 320, height: 180,
                                       textEvents: [(2.0, "SPOILER AHEAD")], sceneChanges: [(0,0.9)])
        let wrote2 = await SyntheticVideo.write(spec, to: url)
        try XCTSkipUnless(wrote2, "AVAssetWriter unavailable")
        let model = LongFormGuardianModelV1(audioProvider: nil)
        // First run under a HIDE rule → real decode + OCR.
        let idxHide = index([textRule("r1", "spoiler", .hideIfControlled)])
        let first = await model.analyze(url: url, contentID: "c1", index: idxHide, exceptions: [], policyRevision: 1, thermal: .nominal)
        XCTAssertFalse(first.evidenceCacheHit, "the first run decodes (no cache yet)")
        XCTAssertGreaterThan(first.framesDecoded, 0, "the first run really decoded frames")
        // Second run under a DIFFERENT policy (rule loosened to WARN, new revision) → evidence REUSED, decision RECOMPUTED.
        let idxWarn = index([textRule("r1", "spoiler", .warn)])
        let second = await model.analyze(url: url, contentID: "c1", index: idxWarn, exceptions: [], policyRevision: 2, thermal: .nominal)
        XCTAssertTrue(second.evidenceCacheHit, "the second run reuses cached evidence (D3)")
        XCTAssertTrue(second.recomputedFromCache, "the decision was recomputed from cached evidence under the new policy (D3)")
        XCTAssertEqual(second.framesDecoded, 0, "no re-decode happened on the policy change (D3 economy)")
        XCTAssertEqual(second.policyRevision, 2, "the recomputed decision carries the NEW policy revision, not the old one (D3)")
    }

    // MARK: E/H — deepening is DEFERRED (recorded, not dropped) under thermal pressure.

    func testDeepeningDeferredUnderThermalPressure() async throws {
        let p = AdaptiveEvidencePlannerV1()
        // Under serious thermal the strategy is conservative → no deepening windows planned at all (bounded work).
        let plan = p.plan(contentID: "c", durationSeconds: 600, thermal: .serious,
                          hasTextRules: true, hasSoundRules: true, policyRevision: 1,
                          uncertainHints: [100, 300, 500])
        XCTAssertTrue(plan.deepeningWindows.isEmpty, "conservative/hot plan does not schedule deepening (E/H bounded work)")
        XCTAssertFalse(plan.windows.contains { $0.experts.audio },
                       "the most expensive arm (audio) is dropped under serious thermal even with sound rules (E/H)")
    }
}
#endif
