//
//  AdaptiveR2EvidenceMapTests.swift — ADAPTIVE GUARDIAN R2 + TEMPORAL EVIDENCE MAP proofs (mandate A–F).
//
//  PURE, headless proofs for the new behaviour. Media-dependent proofs (real reels) live in ReelsPlayerTests; here we
//  prove the policy/plumbing logic deterministically: the analysis gate (A), desired/applied sync (B), honest action
//  mapping (C1), guarded cache safety (C2), temporal semantics (D), per-sample attribution + adaptive sampler + recall
//  limit (E1/E2/E4), and the transition-correlation probe (F).
//
import XCTest
@testable import GuardianMedia
import GuardianCore
#if canImport(AVFoundation)
import AVFoundation

final class AdaptiveR2EvidenceMapTests: XCTestCase {

    // MARK: Helpers

    private func suite() -> (UserDefaults, String) {
        let name = "r2.tests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }
    private func clean(_ name: String) { UserDefaults().removePersistentDomain(forName: name) }

    private func makeStore() -> (store: PersonalShieldSharedStoreV1, dir: URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("r2-\(UUID().uuidString)")
        let suite = UserDefaults(suiteName: "r2.store.\(UUID().uuidString)")!
        return (PersonalShieldSharedStoreV1(directory: dir, suite: suite, sharedContainerActive: true), dir)
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }
    private func rule(_ id: String, _ label: String, _ action: ShieldAction) -> ShieldRuleV2 {
        ShieldRuleV2(ruleID: id, inputType: .textExact, rawUserLabel: label, locale: "en", action: action,
                     createdAtEpoch: 1, updatedAtEpoch: 1)
    }
    private func item(_ id: String) -> ReelItemV1 { ReelItemV1(id: id, title: "t", url: URL(fileURLWithPath: "/tmp/\(id)")) }

    private struct StubEvidence: ReelsEvidenceProviding {
        let byID: [String: ReelsEvidenceV1]
        func gatherEvidence(url: URL, metadataTitle: String, firstFrameSeconds: [Double], languages: [String]) async -> ReelsEvidenceV1 {
            byID[url.lastPathComponent] ?? .empty
        }
    }

    // MARK: A — the real analysis gate: `guardian.enabled` read as a gate; OFF projects analysis-off honestly.

    func testAnalysisGateDefaultsEnabledAndReadsWrite() {
        let (s, name) = suite(); defer { clean(name) }
        XCTAssertTrue(GuardianAnalysisGateV1.isEnabled(suite: s), "absent key defaults to ENABLED (fresh install is on)")
        GuardianAnalysisGateV1.setEnabled(false, suite: s)
        XCTAssertFalse(GuardianAnalysisGateV1.isEnabled(suite: s), "a written OFF crosses the App Group")
        GuardianAnalysisGateV1.setEnabled(true, suite: s)
        XCTAssertTrue(GuardianAnalysisGateV1.isEnabled(suite: s))
    }

    func testAnalysisGateDegradesEnabledWithoutSuite() {
        // nil suite (DEGRADED): we cannot read a deliberate OFF, so we NEVER fabricate one — default ENABLED.
        XCTAssertTrue(GuardianAnalysisGateV1.isEnabled(suite: nil))
    }

    func testObservationProjectionSeparatesBroadcastFromAnalysis() {
        // OFF never looks live; analysis runs ONLY when live + enabled + not idle.
        let off = GuardianObservationProjectionV1.project(guardianEnabled: true, broadcastFresh: false, userIdle: false)
        XCTAssertFalse(off.broadcasting); XCTAssertFalse(off.analysisRunning)

        let disabledButLive = GuardianObservationProjectionV1.project(guardianEnabled: false, broadcastFresh: true, userIdle: false)
        XCTAssertTrue(disabledButLive.broadcasting, "the OS feed is still physically live")
        XCTAssertFalse(disabledButLive.analysisRunning, "but Guardian OFF means heavy analysis is NOT running")
        XCTAssertTrue(disabledButLive.broadcastingButAnalysisOff, "the honest case: broadcast continues, analysis off")

        let idleButLive = GuardianObservationProjectionV1.project(guardianEnabled: true, broadcastFresh: true, userIdle: true)
        XCTAssertFalse(idleButLive.analysisRunning, "user idle also pauses analysis (no protection claim)")

        let running = GuardianObservationProjectionV1.project(guardianEnabled: true, broadcastFresh: true, userIdle: false)
        XCTAssertTrue(running.analysisRunning)
    }

    // MARK: B — desired vs applied: the extension's ack is current only when it acked the LATEST desired generation.

    func testDesiredVsAppliedDivergenceAndConvergence() {
        let (s, name) = suite(); defer { clean(name) }
        let now = 1000.0
        // User taps IDLE → desired advances. No ack yet → not current (the tap is still crossing to the extension).
        GuardianSessionModeBridgeV1.write(.idle, suite: s)
        XCTAssertFalse(GuardianSessionModeBridgeV1.appliedIsCurrent(suite: s, nowEpoch: now),
                       "no ack yet → the applied state is NOT current (honest İsteniyor≠Uygulandı)")
        // Extension acks an OLD generation → still not current.
        GuardianSessionModeBridgeV1.writeAppliedAck(.active, ackedGeneration: 0, nowEpoch: now, suite: s)
        XCTAssertFalse(GuardianSessionModeBridgeV1.appliedIsCurrent(suite: s, nowEpoch: now))
        // Extension acks the LIVE desired generation → now current.
        let gen = GuardianSessionModeBridgeV1.desiredGeneration(suite: s)
        GuardianSessionModeBridgeV1.writeAppliedAck(.idle, ackedGeneration: gen, nowEpoch: now, suite: s)
        XCTAssertTrue(GuardianSessionModeBridgeV1.appliedIsCurrent(suite: s, nowEpoch: now),
                      "an ack of the live generation makes the applied state current")
        XCTAssertEqual(GuardianSessionModeBridgeV1.readAppliedAck(suite: s)?.appliedMode, .idle)
    }

    func testAppliedAckAgesOutLikeHeartbeat() {
        let (s, name) = suite(); defer { clean(name) }
        GuardianSessionModeBridgeV1.write(.idle, suite: s)
        let gen = GuardianSessionModeBridgeV1.desiredGeneration(suite: s)
        GuardianSessionModeBridgeV1.writeAppliedAck(.idle, ackedGeneration: gen, nowEpoch: 1000, suite: s)
        XCTAssertFalse(GuardianSessionModeBridgeV1.appliedIsCurrent(suite: s, nowEpoch: 1000 + 60),
                       "a stale ack (beyond the freshness window) is not current — a dead extension can't claim applied")
    }

    func testClearResetsDesiredGenerationAndAck() {
        let (s, name) = suite(); defer { clean(name) }
        GuardianSessionModeBridgeV1.write(.idle, suite: s)
        GuardianSessionModeBridgeV1.writeAppliedAck(.idle, ackedGeneration: 1, nowEpoch: 1, suite: s)
        GuardianSessionModeBridgeV1.clear(suite: s)
        XCTAssertNil(GuardianSessionModeBridgeV1.readAppliedAck(suite: s))
        XCTAssertEqual(GuardianSessionModeBridgeV1.desiredGeneration(suite: s), 0)
        XCTAssertEqual(GuardianSessionModeBridgeV1.read(suite: s), .active)
    }

    // MARK: C1 — honest action mapping: each ShieldAction → its OWN intent/state (never a blanket HIDE).

    private func decideWith(action: ShieldAction, text: String) async -> ReelDecisionV1 {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try? store.saveRules([rule("u-1", "spoiler", action)])
        let ev = StubEvidence(byID: ["x": ReelsEvidenceProviderV1.fuse(ocrText: text, metadataText: "clip",
                                                                       frameCoverage: 1, ocrExecuted: true, languages: ["en"])])
        let model = await ReelsPlayerModelV1(items: [item("x")], store: store, evidenceProvider: ev, clock: { 10 })
        return await model.evaluate(item("x"))
    }

    func testHideActionMapsToHide() async {
        let d = await decideWith(action: .hideIfControlled, text: "SPOILER ahead")
        XCTAssertEqual(d.state, .hidden)
        if case .hide = d.intent {} else { XCTFail("intent must be .hide") }
        XCTAssertEqual(d.appliedAction, .hideIfControlled)
    }

    func testBlurActionMapsToBlurNotHide() async {
        let d = await decideWith(action: .blurIfControlled, text: "SPOILER ahead")
        XCTAssertEqual(d.state, .blurred, "BLUR must be its own state, never a fake HIDE")
        if case .blur = d.intent {} else { XCTFail("intent must be .blur") }
        XCTAssertEqual(d.appliedAction, .blurIfControlled)
    }

    func testMuteActionMapsToMute() async {
        let d = await decideWith(action: .muteIfControlled, text: "SPOILER ahead")
        XCTAssertEqual(d.state, .muted)
        if case .mute = d.intent {} else { XCTFail("intent must be .mute") }
        XCTAssertEqual(d.appliedAction, .muteIfControlled)
    }

    func testSkipActionMapsToSkip() async {
        let d = await decideWith(action: .skipIfControlledAndAligned, text: "SPOILER ahead")
        XCTAssertEqual(d.state, .skipped)
        if case .skip = d.intent {} else { XCTFail("intent must be .skip") }
        XCTAssertEqual(d.appliedAction, .skipIfControlledAndAligned)
    }

    func testWarnActionMapsToWarnAndStillPlays() async {
        // WARN is a non-destructive configured action → a match reaches execute and we WARN (content still plays).
        let d = await decideWith(action: .warn, text: "SPOILER ahead")
        XCTAssertEqual(d.state, .warned)
        if case .warn = d.intent {} else { XCTFail("intent must be .warn, got \(d.intent)") }
    }

    func testAskActionMapsToAskApproval() async {
        let d = await decideWith(action: .ask, text: "SPOILER ahead")
        XCTAssertEqual(d.state, .askUser)
        if case .askUser = d.intent {} else { XCTFail("intent must be .askUser") }
    }

    // MARK: C2 — guarded evaluation drops the stale write from the CACHE (not just the player).

    private actor GateEvidence: ReelsEvidenceProviding {
        private var gate: CheckedContinuation<Void, Never>?
        let result: ReelsEvidenceV1
        init(result: ReelsEvidenceV1) { self.result = result }
        func release() { gate?.resume(); gate = nil }
        func gatherEvidence(url: URL, metadataTitle: String, firstFrameSeconds: [Double], languages: [String]) async -> ReelsEvidenceV1 {
            await withCheckedContinuation { c in gate = c }
            return result
        }
    }

    func testSupersededEvaluationLeavesNoStaleEvaluatingInCache() async throws {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try store.saveRules([rule("u-1", "spoiler", .hideIfControlled)])
        let gate = GateEvidence(result: ReelsEvidenceProviderV1.fuse(ocrText: "SPOILER", metadataText: "a",
                                                                     frameCoverage: 1, ocrExecuted: true, languages: ["en"]))
        let model = await ReelsPlayerModelV1(items: [item("a"), item("b")], store: store, evidenceProvider: gate, clock: { 10 })
        async let guarded = model.evaluateGuarded(item("a"))
        try? await Task.sleep(nanoseconds: 50_000_000)
        _ = await model.advance(by: 1)         // supersede
        await gate.release()
        let outcome = await guarded
        guard case .superseded = outcome else { return XCTFail("must be superseded") }
        // C2: the transient .evaluating must NOT linger; the cache is restored to the pre-evaluation state.
        let aState = await model.state(of: "a")
        XCTAssertNotEqual(aState, .evaluating, "a superseded evaluation must drop its .evaluating write from the cache")
        XCTAssertNotEqual(aState, .hidden, "and must never commit A's late HIDE")
        let aDecision = await model.decision(of: "a")
        XCTAssertNil(aDecision, "no decision is written to the cache for a superseded evaluation")
    }

    // MARK: D — temporal coverage semantics: sampleExecutionComplete ≠ "whole video"; temporalCoverageLimited true.

    func testTemporalCoverageIsAlwaysLimitedEvenAtFullSampleExecution() async {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try? store.saveRules([rule("u-1", "spoiler", .hideIfControlled)])
        let records: [ReelsTimedEvidenceV1] = [
            .init(timestampSeconds: 0.1, modality: .visualOCR, ocrStatus: .ran, text: "calm"),
            .init(timestampSeconds: 3.0, modality: .visualOCR, ocrStatus: .ran, text: "calm")
        ]
        let ev = StubEvidence(byID: ["q": ReelsEvidenceProviderV1.fuse(ocrText: "calm", metadataText: "clip",
            frameCoverage: 1, ocrExecuted: true, languages: ["en"], timedRecords: records)])
        let model = await ReelsPlayerModelV1(items: [item("q")], store: store, evidenceProvider: ev, clock: { 10 })
        let d = await model.evaluate(item("q"))
        XCTAssertTrue(d.sampleExecutionComplete, "every PLANNED sample decoded+ran → execution complete")
        XCTAssertTrue(d.temporalCoverageLimited, "but temporal coverage is ALWAYS limited for sampled analysis (D honesty)")
        XCTAssertEqual(d.coverageComplete, d.sampleExecutionComplete, "the deprecated alias mirrors the honest field")
    }

    // MARK: E1 — per-sample attribution: a match CITES the sample it came from; no cross-sample fabrication.

    func testPerSampleMatchCitesItsOwnTimepoint() async {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try? store.saveRules([rule("u-1", "spoiler", .hideIfControlled)])
        // Clean open, SPOILER only at the MID sample. The matched rule must be stamped on the 3.0s record, not 0.1s.
        let records: [ReelsTimedEvidenceV1] = [
            .init(timestampSeconds: 0.1, modality: .visualOCR, ocrStatus: .ran, text: "CALM INTRO"),
            .init(timestampSeconds: 3.0, modality: .visualOCR, ocrStatus: .ran, text: "SPOILER"),
            .init(timestampSeconds: 5.7, modality: .visualOCR, ocrStatus: .ran, text: "calm outro")
        ]
        let ev = StubEvidence(byID: ["m": ReelsEvidenceProviderV1.fuse(
            ocrText: records.map { $0.text }.joined(separator: " "), metadataText: "clip",
            frameCoverage: 1, ocrExecuted: true, languages: ["en"], timedRecords: records)])
        let model = await ReelsPlayerModelV1(items: [item("m")], store: store, evidenceProvider: ev, clock: { 10 })
        let d = await model.evaluate(item("m"))
        XCTAssertEqual(d.state, .hidden)
        let matched = d.timedEvidence.filter { $0.matchedAtThisSample }
        XCTAssertEqual(matched.count, 1, "exactly the mid sample matched")
        XCTAssertEqual(matched.first?.timestampSeconds, 3.0, "the match is attributed to its REAL timepoint (3.0s)")
        XCTAssertNotNil(matched.first?.matchedRuleID, "the matched rule id is cited on that sample")
        XCTAssertFalse(d.timedEvidence.first(where: { $0.timestampSeconds == 0.1 })?.matchedAtThisSample ?? true,
                       "the clean opening sample is NOT falsely marked matched")
    }

    func testNoCrossSampleConcatenationFabricatesAMatch() async {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        // Rule matches the exact phrase "major spoiler". Split across two samples ("major" @0.1, "spoiler" @3.0).
        // The fused combinedText "major spoiler" could match the phrase, but NO SINGLE sample contains it → per-sample
        // attribution must show ZERO matched samples (a match must cite a sample; fusion cannot invent one).
        _ = try? store.saveRules([rule("u-1", "major spoiler", .hideIfControlled)])
        let records: [ReelsTimedEvidenceV1] = [
            .init(timestampSeconds: 0.1, modality: .visualOCR, ocrStatus: .ran, text: "major"),
            .init(timestampSeconds: 3.0, modality: .visualOCR, ocrStatus: .ran, text: "spoiler")
        ]
        let ev = StubEvidence(byID: ["c": ReelsEvidenceProviderV1.fuse(
            ocrText: "major spoiler", metadataText: "clip",
            frameCoverage: 1, ocrExecuted: true, languages: ["en"], timedRecords: records)])
        let model = await ReelsPlayerModelV1(items: [item("c")], store: store, evidenceProvider: ev, clock: { 10 })
        let d = await model.evaluate(item("c"))
        XCTAssertTrue(d.timedEvidence.allSatisfy { !$0.matchedAtThisSample },
                      "no single sample contains the phrase → NO sample may be cited as a match (E1 fusion safety)")
    }

    // MARK: E2 — adaptive sampler: budget scales with duration, shrinks under thermal pressure, bounded ≤5.

    func testAdaptiveSamplerBudgetScalesAndClamps() {
        XCTAssertEqual(ReelsAdaptiveSamplerV1.budget(durationSeconds: 1.0, thermal: .nominal), 2, "short clip → minimum 2")
        XCTAssertEqual(ReelsAdaptiveSamplerV1.budget(durationSeconds: 100.0, thermal: .nominal),
                       ReelsAdaptiveSamplerV1.maxBudget, "long clip clamps to the ≤5 ceiling")
        XCTAssertLessThanOrEqual(ReelsAdaptiveSamplerV1.budget(durationSeconds: 100.0, thermal: .serious), 3,
                                 "SERIOUS thermal shrinks the budget")
        XCTAssertEqual(ReelsAdaptiveSamplerV1.budget(durationSeconds: 100.0, thermal: .critical), 2,
                       "CRITICAL thermal → bare minimum")
    }

    func testAdaptiveSamplerCoversStartMidEndWithinBudget() {
        let times = ReelsAdaptiveSamplerV1().sampleTimes(durationSeconds: 6.0, seedEarly: [0.1], thermal: .nominal)
        XCTAssertLessThanOrEqual(times.count, ReelsAdaptiveSamplerV1.maxBudget)
        XCTAssertGreaterThanOrEqual(times.count, 3)
        XCTAssertLessThan(times.first ?? 99, 1.0, "anchors near the start")
        XCTAssertGreaterThan(times.last ?? 0, 5.0, "anchors near the end")
        XCTAssertTrue(times.contains { $0 > 2.5 && $0 < 3.5 }, "includes a mid point")
    }

    func testAdaptiveSamplerFallsBackToSeedWhenNoDuration() {
        let times = ReelsAdaptiveSamplerV1().sampleTimes(durationSeconds: 0, seedEarly: [0.2, 0.6], thermal: .nominal)
        XCTAssertEqual(times, [0.2, 0.6], "no duration → honest seed-only, no fabricated mid/end")
    }

    func testEarlyStopOnlyOnVerifiedMatch() {
        let es = ReelsEarlyStopV1()
        XCTAssertTrue(es.shouldStop(verifiedMatchAtSample: true))
        XCTAssertFalse(es.shouldStop(verifiedMatchAtSample: false), "a non-match never stops early — keep looking")
    }

    // MARK: F — transition-correlation probe: data presence/change alone is NOT success; scripted agreement is.

    func testProbeV2FeatureUnavailableWhenNoIdentityEverSeen() {
        var p = GuardianBroadcastCapabilityProbeV2(script: GuardianBroadcastCapabilityProbeV2.defaultScript, sessionKey: 7)
        for _ in 0..<5 { p.observeAbsent(source: .sampleAttachment) }
        XCTAssertEqual(p.verdict(for: .sampleAttachment), .featureUnavailable)
    }

    func testProbeV2StaleOrFixedWhenPresentButNeverChanges() {
        var p = GuardianBroadcastCapabilityProbeV2(script: GuardianBroadcastCapabilityProbeV2.defaultScript, sessionKey: 7)
        // A REAL bundle id (not the label), asserted at step 0 (A) every time — present but never changing.
        for _ in 0..<5 { p.observe(rawIdentity: "com.app.realbundle.A", source: .sampleAttachment, assertedStepIndex: 0) }
        XCTAssertEqual(p.verdict(for: .sampleAttachment), .presentStaleOrFixed,
                       "a present-but-fixed value is NOT 'updates' (the V1 defect fixed)")
    }

    func testProbeV2ChangesUnscriptedWhenChangeDisagreesWithScript() {
        var p = GuardianBroadcastCapabilityProbeV2(script: GuardianBroadcastCapabilityProbeV2.defaultScript, sessionKey: 7)
        // The source changes but the operator never advances the schedule (asserts nil) → free-run: present + changing
        // but NOT scripted agreement. REAL bundle ids, never the opaque labels.
        p.observe(rawIdentity: "com.app.one", source: .sampleAttachment, assertedStepIndex: nil)
        p.observe(rawIdentity: "com.app.two", source: .sampleAttachment, assertedStepIndex: nil)
        p.observe(rawIdentity: "com.app.three", source: .sampleAttachment, assertedStepIndex: nil)
        XCTAssertEqual(p.verdict(for: .sampleAttachment), .presentChangesUnscripted)
    }

    // §F — THE DIGEST-DOMAIN FIX. The observed values are REAL bundle ids (NOT the labels "A"/"B"); agreement is
    // reached purely through the operator's runtime step assertions binding each label to its observed identity.
    func testProbeV2PresentAndUpdatesViaOperatorAssertedScriptWithRealBundleIds() {
        var p = GuardianBroadcastCapabilityProbeV2(script: GuardianBroadcastCapabilityProbeV2.defaultScript, sessionKey: 7)
        // Device experiment: operator foregrounds app A (step 0), then app B (step 1), then back to app A (step 2).
        p.observe(rawIdentity: "com.instagram.ios", source: .sampleAttachment, assertedStepIndex: 0)  // A baseline
        p.observe(rawIdentity: "com.safari.mobile", source: .sampleAttachment, assertedStepIndex: 1)  // A→B
        p.observe(rawIdentity: "com.instagram.ios", source: .sampleAttachment, assertedStepIndex: 2)  // B→A (same id as A)
        XCTAssertEqual(p.verdict(for: .sampleAttachment), .presentAndUpdates,
                       "runtime-learned label↔identity binding + scripted order reaches PRESENT_AND_UPDATES — no label-digest comparison")
        XCTAssertEqual(p.verdict(for: .annotationCallback), .featureUnavailable, "channels scored independently")
    }

    // §F FALSE-POSITIVE guard: a source that returns the SAME id at step 2 that it showed at step 1 (i.e. does NOT
    // track the return to A) must NOT be scored as agreement — the step-2 digest contradicts A's learned binding.
    func testProbeV2FalsePositiveGuardWhenReturnStepIdentityContradictsLearnedBinding() {
        var p = GuardianBroadcastCapabilityProbeV2(script: GuardianBroadcastCapabilityProbeV2.defaultScript, sessionKey: 7)
        p.observe(rawIdentity: "com.app.A", source: .sampleAttachment, assertedStepIndex: 0)  // A ← learn A
        p.observe(rawIdentity: "com.app.B", source: .sampleAttachment, assertedStepIndex: 1)  // A→B ok
        p.observe(rawIdentity: "com.app.B", source: .sampleAttachment, assertedStepIndex: 2)  // step 2 says A but id is B's → contradiction
        XCTAssertGreaterThan(p.attachment.contradictions, 0, "a return-step identity that contradicts A's binding is a contradiction")
        XCTAssertEqual(p.verdict(for: .sampleAttachment), .presentChangesUnscripted,
                       "contradiction forbids PRESENT_AND_UPDATES (no false positive)")
    }

    // §F FALSE-NEGATIVE guard: intermittent ABSENCE between asserted steps must not break a genuinely-tracking source
    // (absence is recorded honestly but does not erase a learned binding or a completed scripted transition).
    func testProbeV2FalseNegativeGuardWithIntermittentAbsence() {
        var p = GuardianBroadcastCapabilityProbeV2(script: GuardianBroadcastCapabilityProbeV2.defaultScript, sessionKey: 7)
        p.observe(rawIdentity: "com.app.A", source: .sampleAttachment, assertedStepIndex: 0)  // A
        p.observeAbsent(source: .sampleAttachment)                                            // key missing a frame
        p.observe(rawIdentity: "com.app.B", source: .sampleAttachment, assertedStepIndex: 1)  // A→B
        p.observeAbsent(source: .sampleAttachment)
        p.observe(rawIdentity: "com.app.A", source: .sampleAttachment, assertedStepIndex: 2)  // B→A
        XCTAssertEqual(p.verdict(for: .sampleAttachment), .presentAndUpdates,
                       "intermittent absence does not block agreement for a genuinely-tracking source (no false negative)")
    }

    // §F — a source that carries identity but the operator asserts NO schedule can never claim scripted agreement,
    // even if it transitions a lot (auto-idle must stay FEATURE_UNAVAILABLE off a controlled device experiment).
    func testProbeV2FreeRunNeverReachesPresentAndUpdates() {
        var p = GuardianBroadcastCapabilityProbeV2(script: GuardianBroadcastCapabilityProbeV2.defaultScript, sessionKey: 7)
        for i in 0..<10 { p.observe(rawIdentity: "com.app.\(i)", source: .sampleAttachment, assertedStepIndex: nil) }
        XCTAssertNotEqual(p.verdict(for: .sampleAttachment), .presentAndUpdates)
    }

    func testProbeV2SessionKeyedDigestIsNotCrossSessionStable() {
        let d1 = GuardianBroadcastCapabilityProbeV2.sessionKeyedDigest(of: "com.app.A", key: 1)
        let d2 = GuardianBroadcastCapabilityProbeV2.sessionKeyedDigest(of: "com.app.A", key: 2)
        XCTAssertNotEqual(d1, d2, "the SAME identity digests DIFFERENTLY per session key — no cross-session identity")
    }

    // MARK: Reason-code honesty — the new reasons have real Turkish explanations.

    func testNewReasonCodesHaveExplanations() {
        for code: GuardianReasonCodeV1 in [.guardianOffBroadcastContinuing, .shieldBlurApplied, .shieldMuteApplied,
                                           .shieldWarnApplied, .shieldAskApproval, .shieldSkipApplied] {
            XCTAssertFalse(code.turkishExplanation.isEmpty, "\(code) must have an honest explanation")
        }
    }

    // MARK: A1 — FAIL-CLOSED analysis consent (unknown ≠ consent) + session-scoped OFF ACK.

    func testAnalysisConsentFailsClosedOnUnknown() {
        // nil suite → cannot read a deliberate consent → ABSTAIN (unknown ≠ a yes). The heavy path must not run.
        XCTAssertEqual(GuardianAnalysisGateV1.analysisConsent(suite: nil), .unknownAbstain)
        XCTAssertFalse(GuardianAnalysisGateV1.analysisConsent(suite: nil).mayRunAnalysis)
        let (s, name) = suite(); defer { clean(name) }
        // Absent key → still ABSTAIN for the HEAVY path (the "fresh install is on" convenience is NOT applied here).
        XCTAssertEqual(GuardianAnalysisGateV1.analysisConsent(suite: s), .unknownAbstain)
        // A deliberate ENABLED → CONSENTED.
        GuardianAnalysisGateV1.setEnabled(true, suite: s)
        XCTAssertEqual(GuardianAnalysisGateV1.analysisConsent(suite: s), .consented)
        XCTAssertTrue(GuardianAnalysisGateV1.analysisConsent(suite: s).mayRunAnalysis)
        // A deliberate OFF → DENIED_OFF (distinct from unknown).
        GuardianAnalysisGateV1.setEnabled(false, suite: s)
        XCTAssertEqual(GuardianAnalysisGateV1.analysisConsent(suite: s), .deniedOff)
        XCTAssertFalse(GuardianAnalysisGateV1.analysisConsent(suite: s).mayRunAnalysis)
    }

    func testSetEnabledAdvancesDesiredGeneration() {
        let (s, name) = suite(); defer { clean(name) }
        let g0 = GuardianAnalysisGateV1.desiredGeneration(suite: s)
        GuardianAnalysisGateV1.setEnabled(false, suite: s)
        let g1 = GuardianAnalysisGateV1.desiredGeneration(suite: s)
        GuardianAnalysisGateV1.setEnabled(true, suite: s)
        let g2 = GuardianAnalysisGateV1.desiredGeneration(suite: s)
        XCTAssertGreaterThan(g1, g0); XCTAssertGreaterThan(g2, g1)
    }

    func testOffAckConfirmedOnlyForLiveSessionAndGeneration() {
        let (s, name) = suite(); defer { clean(name) }
        let session = "sess-A"
        GuardianAnalysisGateV1.setEnabled(false, suite: s)              // user wants OFF
        let gen = GuardianAnalysisGateV1.desiredGeneration(suite: s)
        // No ack yet → NOT confirmed-applied (İsteniyor, not Uygulandı) — a silent bypass cannot read as applied.
        XCTAssertFalse(GuardianAnalysisOffAckV1.offConfirmedApplied(intentOff: true, liveSessionID: session,
                                                                    liveDesiredGeneration: gen, suite: s))
        // The analysing process ACKs OFF for THIS session + generation → confirmed.
        GuardianAnalysisOffAckV1.writeAck(.init(sessionID: session, appliedGeneration: gen, analysisOff: true, epochSeconds: 1), suite: s)
        XCTAssertTrue(GuardianAnalysisOffAckV1.offConfirmedApplied(intentOff: true, liveSessionID: session,
                                                                   liveDesiredGeneration: gen, suite: s))
        // A stale ack from a DIFFERENT session must NOT confirm (session-scoped).
        XCTAssertFalse(GuardianAnalysisOffAckV1.offConfirmedApplied(intentOff: true, liveSessionID: "sess-B",
                                                                    liveDesiredGeneration: gen, suite: s))
        // A NEWER desired generation (user toggled again) invalidates the old ack.
        XCTAssertFalse(GuardianAnalysisOffAckV1.offConfirmedApplied(intentOff: true, liveSessionID: session,
                                                                    liveDesiredGeneration: gen &+ 1, suite: s))
        // An ack that says analysis is still RUNNING never confirms an OFF.
        GuardianAnalysisOffAckV1.writeAck(.init(sessionID: session, appliedGeneration: gen, analysisOff: false, epochSeconds: 1), suite: s)
        XCTAssertFalse(GuardianAnalysisOffAckV1.offConfirmedApplied(intentOff: true, liveSessionID: session,
                                                                    liveDesiredGeneration: gen, suite: s))
        GuardianAnalysisOffAckV1.clear(suite: s)
        XCTAssertNil(GuardianAnalysisOffAckV1.readAck(suite: s))
    }

    // MARK: B1 — split-phrase: halves in two DIFFERENT samples must NOT fabricate a match (per-unit authority).

    /// A stub whose adaptive gather returns PER-SAMPLE timed records (so the per-unit decision path is exercised).
    private struct TimedStub: ReelsEvidenceProviding {
        let records: [ReelsTimedEvidenceV1]
        let metadata: String
        func gatherEvidence(url: URL, metadataTitle: String, firstFrameSeconds: [Double], languages: [String]) async -> ReelsEvidenceV1 {
            await gatherEvidenceAdaptive(url: url, metadataTitle: metadataTitle, firstFrameSeconds: firstFrameSeconds,
                                         languages: languages, thermal: .nominal, earlyStopProbe: nil)
        }
        func gatherEvidenceAdaptive(url: URL, metadataTitle: String, firstFrameSeconds: [Double], languages: [String],
                                    thermal: ReelsThermalBucketV1, earlyStopProbe: ReelsSampleMatchProbe?) async -> ReelsEvidenceV1 {
            let ocrPieces = records.filter { $0.ocrStatus == .ran }.map { $0.text }
            let counters = ReelsCoverageCountersV1(plannedSampleCount: records.count, attemptedSampleCount: records.count,
                                                   decodedSampleCount: records.filter { $0.ocrStatus != .notDecoded }.count,
                                                   ocrExecutedCount: records.filter { $0.ocrStatus != .notDecoded }.count,
                                                   earlyStopped: false, earlyStopReason: .none)
            return ReelsEvidenceProviderV1.fuse(ocrText: ocrPieces.joined(separator: " "), metadataText: metadata,
                                                frameCoverage: 1, ocrExecuted: !ocrPieces.isEmpty, languages: languages,
                                                timedRecords: records, planCounters: counters)
        }
    }

    func testSplitPhraseAcrossSamplesDoesNotFabricateMatch() async {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try? store.saveRules([rule("u-1", "spoiler", .hideIfControlled)])
        // 'spo' at t1 and 'iler' at t2 — neither sample alone contains 'spoiler'. The old fused-text authority could
        // join them ('spo iler'); the per-unit authority must NOT, so the reel PLAYS (no fabricated HIDE).
        let recs = [ReelsTimedEvidenceV1(timestampSeconds: 0.2, modality: .visualOCR, ocrStatus: .ran, text: "spo"),
                    ReelsTimedEvidenceV1(timestampSeconds: 1.0, modality: .visualOCR, ocrStatus: .ran, text: "iler")]
        let ev = TimedStub(records: recs, metadata: "clip")
        let model = await ReelsPlayerModelV1(items: [item("x")], store: store, evidenceProvider: ev, clock: { 10 })
        let d = await model.evaluate(item("x"))
        XCTAssertEqual(d.state, .playing, "no single sample contains 'spoiler' → must NOT fabricate a match")
        XCTAssertFalse(d.timedEvidence.contains { $0.matchedAtThisSample }, "no per-sample match either")
    }

    func testSingleSampleContainingPhraseStillMatches() async {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try? store.saveRules([rule("u-1", "spoiler", .hideIfControlled)])
        let recs = [ReelsTimedEvidenceV1(timestampSeconds: 0.2, modality: .visualOCR, ocrStatus: .ran, text: "big spoiler ahead")]
        let ev = TimedStub(records: recs, metadata: "clip")
        let model = await ReelsPlayerModelV1(items: [item("x")], store: store, evidenceProvider: ev, clock: { 10 })
        let d = await model.evaluate(item("x"))
        XCTAssertEqual(d.state, .hidden, "a single sample that really contains the term DOES match")
        XCTAssertTrue(d.timedEvidence.contains { $0.matchedAtThisSample })
    }

    // MARK: B2 — separated coverage counters flow into the decision.

    func testCoverageCountersFlowIntoDecision() async {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try? store.saveRules([rule("u-1", "spoiler", .hideIfControlled)])
        let recs = [ReelsTimedEvidenceV1(timestampSeconds: 0.2, modality: .visualOCR, ocrStatus: .ran, text: "calm"),
                    ReelsTimedEvidenceV1(timestampSeconds: 1.0, modality: .visualOCR, ocrStatus: .ranNoText, text: ""),
                    ReelsTimedEvidenceV1(timestampSeconds: 2.0, modality: .visualOCR, ocrStatus: .notDecoded, text: "")]
        let ev = TimedStub(records: recs, metadata: "clip")
        let model = await ReelsPlayerModelV1(items: [item("x")], store: store, evidenceProvider: ev, clock: { 10 })
        let d = await model.evaluate(item("x"))
        XCTAssertEqual(d.coverageCounters.plannedSampleCount, 3)
        XCTAssertEqual(d.coverageCounters.decodedSampleCount, 2, "two points decoded; one not-decoded")
        XCTAssertTrue(d.temporalCoverageLimited, "sampled analysis is always temporally limited")
    }

    // MARK: D2 — early-stop must not pre-empt a stronger possible action.

    func testEarlyStopSeverityOrdering() {
        XCTAssertGreaterThan(ReelsDecisionEngineV1.actionSeverity(.hideIfControlled),
                             ReelsDecisionEngineV1.actionSeverity(.warn))
        XCTAssertGreaterThan(ReelsDecisionEngineV1.actionSeverity(.skipIfControlledAndAligned),
                             ReelsDecisionEngineV1.actionSeverity(.muteIfControlled))
        XCTAssertEqual(ReelsDecisionEngineV1.actionSeverity(.allow), 0)
    }

    // MARK: C3/C5 — prefetch token scoping + raw-text stripping.

    func testPrefetchTokenInvalidatesAcrossPolicyAndOverride() async {
        let a = PrefetchTokenV1(sessionID: "s", contentID: "c", assetFingerprint: "f", policyRevision: 1,
                                evaluatorVersion: "e", providerVersion: "p", generation: 0, exceptionState: "ov:0", coveragePlan: 5)
        let diffPolicy = PrefetchTokenV1(sessionID: "s", contentID: "c", assetFingerprint: "f", policyRevision: 2,
                                         evaluatorVersion: "e", providerVersion: "p", generation: 0, exceptionState: "ov:0", coveragePlan: 5)
        let diffOverride = PrefetchTokenV1(sessionID: "s", contentID: "c", assetFingerprint: "f", policyRevision: 1,
                                           evaluatorVersion: "e", providerVersion: "p", generation: 0, exceptionState: "ov:1", coveragePlan: 5)
        let diffContent = PrefetchTokenV1(sessionID: "s", contentID: "OTHER", assetFingerprint: "f", policyRevision: 1,
                                          evaluatorVersion: "e", providerVersion: "p", generation: 0, exceptionState: "ov:0", coveragePlan: 5)
        XCTAssertNotEqual(a, diffPolicy, "a policy change invalidates the prefetch token (acceptance #7)")
        XCTAssertNotEqual(a, diffOverride, "an override change invalidates the token (acceptance #8 — no leak)")
        XCTAssertNotEqual(a, diffContent, "a different content id is a different token (no cross-reel reuse)")
    }

    func testPrefetchSanitizerStripsRawTextKeepsRuleAndCounts() {
        let timed = [ReelsTimedEvidenceV1(timestampSeconds: 1, modality: .visualOCR, ocrStatus: .ran,
                                          text: "secret spoiler text", matchedRuleID: "u-1")]
        let d = ReelDecisionV1(contentID: "c", policyRevision: 1, state: .hidden, intent: .hide(reason: .textEvidenceMatchedShield),
                               matchState: .matchExact, layerDecision: .execute, appliedAction: .hideIfControlled,
                               matchedRuleID: "u-1", provenance: .realOCR, coverage: 1, uncertainty: 0,
                               reason: .textEvidenceMatchedShield, surfaceControlled: true, timedEvidence: timed,
                               coverageCounters: ReelsCoverageCountersV1(plannedSampleCount: 1, attemptedSampleCount: 1,
                                                                         decodedSampleCount: 1, ocrExecutedCount: 1,
                                                                         earlyStopped: false, earlyStopReason: .none))
        let s = PrefetchDecisionSanitizerV1.stripRawText(d)
        XCTAssertEqual(s.timedEvidence.first?.text, "", "raw OCR text is stripped after the verdict (C5)")
        XCTAssertEqual(s.timedEvidence.first?.matchedRuleID, "u-1", "the matched rule id is KEPT")
        XCTAssertEqual(s.timedEvidence.first?.ocrStatus, .ran, "the OCR status is kept")
        XCTAssertEqual(s.state, .hidden, "the verdict is unchanged")
        XCTAssertEqual(s.coverageCounters.plannedSampleCount, 1, "counts are kept")
    }

    // MARK: D3 — DIFFERENTIAL: on-demand vs prefetch must produce IDENTICAL decisions across the 7-reel library.

    func testPrefetchEqualsOnDemandDecisionDifferential() async {
        // Build two independent brains over the SAME synthetic evidence; one evaluates on-demand, the other via the
        // prefetch path. Every decision field that matters must be identical (D3 — speed never changes the verdict).
        func makeModel() async -> (ReelsPlayerModelV1, URL) {
            let (store, dir) = makeStore()
            _ = try? store.saveRules([rule("u-1", "spoiler", .hideIfControlled), rule("u-2", "promo", .warn)])
            let recsByID: [String: [ReelsTimedEvidenceV1]] = [
                "r1": [.init(timestampSeconds: 0.2, modality: .visualOCR, ocrStatus: .ran, text: "calm cooking")],
                "r2": [.init(timestampSeconds: 0.2, modality: .visualOCR, ocrStatus: .ran, text: "big spoiler ahead")],
                "r3": [.init(timestampSeconds: 0.2, modality: .visualOCR, ocrStatus: .ran, text: "limited promo")],
                "r4": [.init(timestampSeconds: 0.2, modality: .visualOCR, ocrStatus: .ranNoText, text: "")],
            ]
            // One stub resolving per id via lastPathComponent.
            struct MultiStub: ReelsEvidenceProviding {
                let byID: [String: [ReelsTimedEvidenceV1]]
                func gatherEvidence(url: URL, metadataTitle: String, firstFrameSeconds: [Double], languages: [String]) async -> ReelsEvidenceV1 {
                    await gatherEvidenceAdaptive(url: url, metadataTitle: metadataTitle, firstFrameSeconds: firstFrameSeconds,
                                                 languages: languages, thermal: .nominal, earlyStopProbe: nil)
                }
                func gatherEvidenceAdaptive(url: URL, metadataTitle: String, firstFrameSeconds: [Double], languages: [String],
                                            thermal: ReelsThermalBucketV1, earlyStopProbe: ReelsSampleMatchProbe?) async -> ReelsEvidenceV1 {
                    let recs = byID[url.lastPathComponent] ?? []
                    let pieces = recs.filter { $0.ocrStatus == .ran }.map { $0.text }
                    return ReelsEvidenceProviderV1.fuse(ocrText: pieces.joined(separator: " "), metadataText: "t",
                                                        frameCoverage: 1, ocrExecuted: !pieces.isEmpty, languages: ["en"],
                                                        timedRecords: recs)
                }
            }
            let items = ["r1", "r2", "r3", "r4"].map { item($0) }
            let model = await ReelsPlayerModelV1(items: items, store: store, evidenceProvider: MultiStub(byID: recsByID), clock: { 10 })
            return (model, dir)
        }
        let (onDemand, d1) = await makeModel(); defer { cleanup(d1) }
        let (prefetchModel, d2) = await makeModel(); defer { cleanup(d2) }
        for id in ["r1", "r2", "r3", "r4"] {
            let od = await onDemand.evaluate(item(id))
            let pf = await prefetchModel.evaluatePrefetch(item(id), capturedGeneration: prefetchModel.evaluationGeneration)
            guard case .applied(let pfDecision) = pf else { XCTFail("prefetch should apply for \(id)"); continue }
            XCTAssertEqual(od.state, pfDecision.state, "\(id): state must match on-demand vs prefetch")
            XCTAssertEqual(od.appliedAction, pfDecision.appliedAction, "\(id): action must match")
            XCTAssertEqual(od.matchedRuleID, pfDecision.matchedRuleID, "\(id): matched rule must match")
            XCTAssertEqual(od.matchState, pfDecision.matchState, "\(id): match state must match")
        }
    }

    // MARK: B3 — prefetch supersede: a prefetch whose generation advanced mid-flight is discarded (never applied).

    func testPrefetchSupersededWhenGenerationAdvances() async {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try? store.saveRules([rule("u-1", "spoiler", .hideIfControlled)])
        let ev = StubEvidence(byID: ["x": ReelsEvidenceProviderV1.fuse(ocrText: "SPOILER", metadataText: "t",
                                                                       frameCoverage: 1, ocrExecuted: true, languages: ["en"])])
        let model = await ReelsPlayerModelV1(items: [item("x")], store: store, evidenceProvider: ev, clock: { 10 })
        let captured = await model.evaluationGeneration
        _ = await model.bumpEvaluationGeneration()   // a foreground swipe happened AFTER we captured
        let r = await model.evaluatePrefetch(item("x"), capturedGeneration: captured)
        if case .superseded = r {} else { XCTFail("a prefetch bound to a superseded generation must be discarded") }
    }
}
#endif
