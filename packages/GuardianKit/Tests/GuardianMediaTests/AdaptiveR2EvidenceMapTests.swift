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
        for _ in 0..<5 { p.observe(rawIdentity: "com.app.A", source: .sampleAttachment) }
        XCTAssertEqual(p.verdict(for: .sampleAttachment), .presentStaleOrFixed,
                       "a present-but-fixed value is NOT 'updates' (the V1 defect fixed)")
    }

    func testProbeV2ChangesUnscriptedWhenChangeDisagreesWithScript() {
        var p = GuardianBroadcastCapabilityProbeV2(script: GuardianBroadcastCapabilityProbeV2.defaultScript, sessionKey: 7)
        // Changes, but NOT A→B→A (random identities) → it changed but did not AGREE with the script.
        p.observe(rawIdentity: "com.app.A", source: .sampleAttachment)
        p.observe(rawIdentity: "com.app.Z", source: .sampleAttachment)
        p.observe(rawIdentity: "com.app.Q", source: .sampleAttachment)
        XCTAssertEqual(p.verdict(for: .sampleAttachment), .presentChangesUnscripted)
    }

    func testProbeV2PresentAndUpdatesOnlyOnScriptedAgreement() {
        var p = GuardianBroadcastCapabilityProbeV2(script: GuardianBroadcastCapabilityProbeV2.defaultScript, sessionKey: 7)
        // Perform the scripted A → B → A sequence on the attachment source.
        p.observe(rawIdentity: "A", source: .sampleAttachment)
        p.observe(rawIdentity: "B", source: .sampleAttachment)   // A→B agrees with step 2
        p.observe(rawIdentity: "A", source: .sampleAttachment)   // B→A agrees with step 3
        XCTAssertEqual(p.verdict(for: .sampleAttachment), .presentAndUpdates,
                       "only scripted TEMPORAL AGREEMENT reaches PRESENT_AND_UPDATES")
        // The other source saw nothing → still FEATURE_UNAVAILABLE (channels scored independently).
        XCTAssertEqual(p.verdict(for: .annotationCallback), .featureUnavailable)
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
}
#endif
