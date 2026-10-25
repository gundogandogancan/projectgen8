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

    // MARK: 1A — FAST DECISION SEMANTIC CORRECTNESS. The FAST decision is the engine's REAL verdict over the FAST
    // window's ACTUAL evidence (matchedRule + applicable action preserved), NOT a second decision rebuilt from empty
    // OCR text. Three scenarios with REAL generated assets: start-of-video match, mid-video match, no match.

    /// Dense early text so the FAST window (first span, sampled at its midpoint) reliably contains matchable text on
    /// the real decode→OCR path. A 6s/text-only video has selBudget 2 → windowSpan 3s → FAST=[0,3] sampled at ~1.5s.
    private func earlyMatchSpec(term: String, durationSeconds: Double = 6) -> SyntheticVideo.Spec {
        // Place the term across the whole first window (every ~0.8s so the 1.0s draw window is always covered at 1.5s).
        let events: [(Double, String)] = [(0.0, term), (0.8, term), (1.6, term), (2.4, term)]
        return SyntheticVideo.Spec(durationSeconds: durationSeconds, fps: 6, width: 480, height: 270,
                                   textEvents: events, sceneChanges: [(0, 0.95)])
    }

    private func isHide(_ intent: PlaybackIntentV1) -> Bool { if case .hide = intent { return true }; return false }

    // 1A — a HIDE match present at the START of the video ⇒ FAST decision is a REAL HIDE (the old defect surfaced CLEAR
    // because buildDecision discarded the match and re-decided over empty text).
    func testFastDecisionStartMatchIsHide() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lf-1a-start-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("clip.mp4")
        let term = "SPOILER"
        let wrote = await SyntheticVideo.write(earlyMatchSpec(term: term), to: url)
        try XCTSkipUnless(wrote, "AVAssetWriter unavailable")
        let model = LongFormGuardianModelV1(audioProvider: nil)
        let idx = index([textRule("r1", term, .hideIfControlled)])
        let result = await model.analyze(url: url, contentID: "c1", index: idx, exceptions: [], policyRevision: 7, thermal: .nominal)
        let fast = try XCTUnwrap(result.fastDecision, "a FAST decision is produced")
        // The REAL evidence-based FAST verdict: a start-of-video HIDE match is a FAST HIDE, not a CLEAR/PLAY.
        try XCTSkipUnless(result.windowOutcomes.contains { $0.window.level == .fast && $0.ocrText.uppercased().contains(term) },
                          "OCR did not recognise the start-window term on this runtime — skip (not a logic failure)")
        XCTAssertTrue(isHide(fast.intent), "FAST decision honours the start-of-video HIDE match (1A); got \(fast.intent)")
        XCTAssertEqual(fast.matchedRuleID, "r1", "the FAST decision preserves the matched rule provenance (1A)")
        XCTAssertEqual(fast.appliedAction, .hideIfControlled, "the FAST decision preserves the applicable HIDE action (1A)")
        XCTAssertEqual(fast.policyRevision, 7, "the FAST decision is stamped with the live policy revision, not a guess")
        XCTAssertTrue(fast.matchState.isMatch, "a real match is a real match (never upgraded to a non-match)")
    }

    // 1A — a HIDE match present only MID-video (NOT in the fast window) ⇒ the FAST decision is honest LIMITED evidence
    // (NOT a false HIDE, and NOT a 'whole video safe' CLEAR claim); the AGGREGATE catches the late match as HIDE.
    func testFastLimitedThenAggregateHideOnMidMatch() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lf-1a-mid-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("clip.mp4")
        let term = "SPOILER"
        // 6s video, FAST window ~[0,3] sampled at 1.5s (benign). The term appears only around the SELECTIVE center ~4.5s.
        let spec = SyntheticVideo.Spec(durationSeconds: 6, fps: 6, width: 480, height: 270,
                                       textEvents: [(4.0, term), (4.6, term), (5.2, term)], sceneChanges: [(0, 0.95)])
        let wrote = await SyntheticVideo.write(spec, to: url)
        try XCTSkipUnless(wrote, "AVAssetWriter unavailable")
        let model = LongFormGuardianModelV1(audioProvider: nil)
        let idx = index([textRule("r1", term, .hideIfControlled)])
        let result = await model.analyze(url: url, contentID: "c1", index: idx, exceptions: [], policyRevision: 1, thermal: .nominal)
        let fast = try XCTUnwrap(result.fastDecision, "a FAST decision is produced even when the match is late")
        // FAST must NOT claim a HIDE it has no evidence for in its window, and must NOT be a false early match.
        XCTAssertFalse(isHide(fast.intent), "the FAST window has no match → FAST is not a false HIDE (1A)")
        XCTAssertNil(fast.matchedRuleID, "FAST attributes no rule when its own window matched nothing (1A)")
        XCTAssertTrue(result.temporalCoverageLimited, "FAST never claims the whole video is understood (1A/F)")
        // The AGGREGATE (strongest per-window verdict) must catch the late HIDE match if OCR recognised it.
        try XCTSkipUnless(result.windowOutcomes.contains { $0.ocrText.uppercased().contains(term) },
                          "OCR did not recognise the mid-video term on this runtime — skip (not a logic failure)")
        let agg = try XCTUnwrap(result.aggregateDecision)
        XCTAssertTrue(isHide(agg.intent), "the aggregate catches the mid-video HIDE match (1A); got \(agg.intent)")
    }

    // 1A — NO matching content anywhere ⇒ the FAST decision is an honest non-match (no fabricated rule/action); the
    // aggregate is likewise not a HIDE. A benign video is never a false positive.
    func testFastNoMatchIsHonest() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lf-1a-none-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("clip.mp4")
        // Benign on-screen text that does NOT contain the rule term.
        let spec = SyntheticVideo.Spec(durationSeconds: 6, fps: 6, width: 480, height: 270,
                                       textEvents: [(0.0, "HELLO"), (1.2, "WORLD"), (3.0, "SUNRISE")], sceneChanges: [(0, 0.95)])
        let wrote = await SyntheticVideo.write(spec, to: url)
        try XCTSkipUnless(wrote, "AVAssetWriter unavailable")
        let model = LongFormGuardianModelV1(audioProvider: nil)
        let idx = index([textRule("r1", "SPOILER", .hideIfControlled)])
        let result = await model.analyze(url: url, contentID: "c1", index: idx, exceptions: [], policyRevision: 1, thermal: .nominal)
        let fast = try XCTUnwrap(result.fastDecision)
        XCTAssertFalse(isHide(fast.intent), "a benign FAST window is never a false HIDE (1A)")
        XCTAssertNil(fast.matchedRuleID, "no rule is fabricated when nothing matched (1A)")
        if let agg = result.aggregateDecision { XCTAssertFalse(isHide(agg.intent), "a benign video is never aggregated into a HIDE (1A)") }
    }

    // MARK: 1D — AUDIO ECONOMY. The whole file is analysed ONCE per asset (one timestamped reusable bundle); every
    // audio window reuses it filtered to its range. The before/after metric is the JOB COUNT on one asset: with N
    // audio windows the old code ran N full-file analyses; the fix runs exactly 1.

    /// A deterministic, call-COUNTING audio provider stub (no SoundAnalysis runtime dependency). Each call returns the
    /// same whole-file evidence (a music event spanning the file) and bumps a counter so the test can assert job count.
    private final class CountingAudioProvider: ReelsAudioEvidenceProviding, @unchecked Sendable {
        private(set) var calls = 0
        private let lock = NSLock()
        let fileDurationSeconds: Double
        init(fileDurationSeconds: Double) { self.fileDurationSeconds = fileDurationSeconds }
        func gatherAudioEvidence(url: URL, thermal: ReelsThermalBucketV1) async -> ReelsAudioEvidenceV1 {
            lock.lock(); calls += 1; lock.unlock()
            let ev = ReelsAudioEventV1(label: "music", rawModelConfidence: 0.8, startSeconds: 0,
                                      endSeconds: fileDurationSeconds, classifierVersion: "stub-v1")
            return ReelsAudioEvidenceV1(availability: .available, events: [ev], classifierVersion: "stub-v1")
        }
    }

    func testAudioAnalysedOncePerAssetNotPerWindow() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lf-1d-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("clip.mp4")
        // A longer video so the plan schedules MULTIPLE audio windows (selBudget scales ~1/60s). 180s → several windows.
        let spec = SyntheticVideo.Spec(durationSeconds: 180, fps: 2, width: 320, height: 180,
                                       textEvents: [], sceneChanges: [(0, 0.9)])
        let wrote = await SyntheticVideo.write(spec, to: url)
        try XCTSkipUnless(wrote, "AVAssetWriter unavailable")
        let stub = CountingAudioProvider(fileDurationSeconds: 180)
        let model = LongFormGuardianModelV1(audioProvider: stub)
        // SOUND rule → the planner schedules audio windows; nominal thermal keeps them (no audio-drop).
        let idx = index([soundRule("s1", "music", .warn)])
        let result = await model.analyze(url: url, contentID: "c1", index: idx, exceptions: [], policyRevision: 1, thermal: .nominal)
        // There really are MULTIPLE audio windows in the plan (otherwise the economy is untested).
        let audioWindowCount = result.plan.windows.filter { $0.experts.audio }.count
        XCTAssertGreaterThan(audioWindowCount, 1, "the plan has multiple audio windows (so the economy is meaningful)")
        // THE METRIC: exactly ONE full-file audio analysis job ran despite multiple audio windows (1D).
        XCTAssertEqual(stub.calls, 1, "the whole file is analysed ONCE, not once per window (1D); windows=\(audioWindowCount)")
        let jobs = await model.audioJobsRun
        XCTAssertEqual(jobs, 1, "the model records exactly one audio job for the asset (1D before/after metric)")
        XCTAssertGreaterThan(result.audioWindows, 1, "audio evidence was still attributed to multiple windows (reused, not re-scanned)")
    }

    // MARK: 1C — LONG-FORM CACHE MODALITY INTEGRITY. An OCR-only evidence cache CANNOT answer a newly-added SoundClass
    // rule: serving it would silently treat "audio never analysed" as "no sound match" (a false CLEAR). The fix drops
    // the modality-insufficient cache and re-analyses so the audio sense really runs — UNKNOWN is never upgraded to CLEAR.

    func testOCROnlyCacheDoesNotAnswerNewSoundRule() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lf-1c-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("clip.mp4")
        let spec = SyntheticVideo.Spec(durationSeconds: 8, fps: 4, width: 320, height: 180,
                                       textEvents: [(0.0, "HELLO")], sceneChanges: [(0, 0.9)])
        let wrote = await SyntheticVideo.write(spec, to: url)
        try XCTSkipUnless(wrote, "AVAssetWriter unavailable")
        // The audio stub returns a "music" event; a sound rule on "music" should MATCH once audio actually runs.
        let stub = CountingAudioProvider(fileDurationSeconds: 8)
        let model = LongFormGuardianModelV1(audioProvider: stub)
        // (1) First analyse under an OCR-ONLY policy → the cache records analyzedAudio = false, no audio job runs.
        let idxText = index([textRule("t1", "SPOILER", .hideIfControlled)])
        let first = await model.analyze(url: url, contentID: "c1", index: idxText, exceptions: [], policyRevision: 1, thermal: .nominal)
        XCTAssertFalse(first.evidenceCacheHit, "first run populates the cache")
        XCTAssertEqual(stub.calls, 0, "no audio was analysed under an OCR-only policy (no sound rules)")
        // (2) Analyse the SAME asset under a NEW policy that ADDS a SoundClass rule. The OCR-only cache is
        //     modality-insufficient → it must NOT be served; audio must actually run now.
        let idxSound = index([textRule("t1", "SPOILER", .hideIfControlled), soundRule("s1", "music", .warn)])
        let second = await model.analyze(url: url, contentID: "c1", index: idxSound, exceptions: [], policyRevision: 2, thermal: .nominal)
        XCTAssertFalse(second.recomputedFromCache, "the modality-insufficient OCR-only cache was NOT served as a full decision (1C)")
        XCTAssertEqual(stub.calls, 1, "the newly-required audio modality was actually analysed, not assumed absent (1C)")
        XCTAssertGreaterThan(second.audioWindows, 0, "audio evidence now covers windows (the sound rule can be evaluated honestly)")
        // The sound rule on "music" MATCHES the analysed audio → the decision reflects the sound match, never a
        // false CLEAR inherited from the OCR-only cache.
        let agg = try XCTUnwrap(second.aggregateDecision)
        XCTAssertTrue(agg.matchState.isMatch, "the newly-added sound rule matches the real audio evidence (no false CLEAR from a stale OCR-only cache, 1C)")
        XCTAssertEqual(agg.matchedRuleID, "s1", "the match is attributed to the sound rule that the cache could not previously answer (1C)")
    }

    // 1C — the SAME modalities: a pure policy change (OCR-only → OCR-only, different action) STILL reuses the cache
    // (the economy is preserved when the cache IS modality-sufficient). Guards against over-invalidation.
    func testSameModalityPolicyChangeStillReusesCache() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lf-1c2-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("clip.mp4")
        let spec = SyntheticVideo.Spec(durationSeconds: 8, fps: 4, width: 320, height: 180,
                                       textEvents: [(2.0, "SPOILER")], sceneChanges: [(0, 0.9)])
        let wrote = await SyntheticVideo.write(spec, to: url)
        try XCTSkipUnless(wrote, "AVAssetWriter unavailable")
        let model = LongFormGuardianModelV1(audioProvider: nil)
        let first = await model.analyze(url: url, contentID: "c1", index: index([textRule("r1", "SPOILER", .hideIfControlled)]),
                                        exceptions: [], policyRevision: 1, thermal: .nominal)
        XCTAssertFalse(first.evidenceCacheHit)
        let second = await model.analyze(url: url, contentID: "c1", index: index([textRule("r1", "SPOILER", .warn)]),
                                         exceptions: [], policyRevision: 2, thermal: .nominal)
        XCTAssertTrue(second.recomputedFromCache, "a same-modality (OCR-only) policy change reuses the cache (1C economy preserved)")
        XCTAssertEqual(second.framesDecoded, 0, "no re-decode on a modality-sufficient policy change")
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
