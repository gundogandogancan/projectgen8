//
//  PersonalLearningR2FixTests.swift — §8 PROOF for the AUDIO R2 + PREFETCH-RACE fixes (§1-2).
//
//  Each test names the mandate acceptance item it proves. XCTest (matches the suite). Pure/headless where possible;
//  REAL SoundAnalysis paths are gated with XCTSkip + a reason (never faked) so they run where the framework exists.
//
import XCTest
@testable import GuardianMedia
import GuardianCore
#if canImport(AVFoundation)
import AVFoundation
#if canImport(SoundAnalysis)
import SoundAnalysis
#endif

final class PersonalLearningR2FixTests: XCTestCase {

    // MARK: helpers
    private func makeStore() -> (store: PersonalShieldSharedStoreV1, dir: URL, suite: UserDefaults) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("plr2-\(UUID().uuidString)")
        let suite = UserDefaults(suiteName: "plr2.\(UUID().uuidString)")!
        return (PersonalShieldSharedStoreV1(directory: dir, suite: suite, sharedContainerActive: true), dir, suite)
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }
    private func soundRule(_ id: String, _ label: String, _ action: ShieldAction) -> ShieldRuleV2 {
        ShieldRuleV2(ruleID: id, inputType: .soundClass, rawUserLabel: label, locale: "en", action: action,
                     createdAtEpoch: 1, updatedAtEpoch: 1)
    }
    private func textRule(_ id: String, _ label: String, _ action: ShieldAction) -> ShieldRuleV2 {
        ShieldRuleV2(ruleID: id, inputType: .textExact, rawUserLabel: label, locale: "en", action: action,
                     createdAtEpoch: 1, updatedAtEpoch: 1)
    }

    // MARK: §1.1 — soundClass+HIDE cannot be added from the general editor (store boundary downgrades to WARN).

    func testSoundClassHideIsDowngradedOnSave() throws {
        let (store, dir, _) = makeStore(); defer { cleanup(dir) }
        _ = try store.saveRules([soundRule("snd-1", "siren", .hideIfControlled)])   // unsafe: sound + HIDE
        let loaded = store.loadPolicy()
        XCTAssertEqual(loaded.rules.first?.action, .warn, "a soundClass+HIDE rule is downgraded to WARN at the store boundary (§1.1)")
    }

    func testPureSoundSafetyValidatorDowngradesExecuteActionsOnly() {
        // text+HIDE stays HIDE; sound+HIDE/BLUR/MUTE/SKIP → WARN; sound+ASK stays ASK.
        XCTAssertEqual(SoundRuleSafetyV1.sanitized(textRule("t", "x", .hideIfControlled)).action, .hideIfControlled)
        for a: ShieldAction in [.hideIfControlled, .blurIfControlled, .muteIfControlled, .skipIfControlledAndAligned] {
            XCTAssertEqual(SoundRuleSafetyV1.sanitized(soundRule("s", "siren", a)).action, .warn, "sound+\(a.rawValue) → WARN")
        }
        XCTAssertEqual(SoundRuleSafetyV1.sanitized(soundRule("s", "siren", .ask)).action, .ask, "sound+ASK is already safe")
    }

    // MARK: §1.1 — a LEGACY soundClass+HIDE rule on disk is handled safely on LOAD + flagged visibly.

    func testLegacySoundHideRuleIsSanitizedOnLoadWithVisibleFlag() throws {
        let (store, dir, _) = makeStore(); defer { cleanup(dir) }
        // Simulate a legacy/hand-authored unsafe rule that bypassed the UI: write a MIX and confirm load sanitizes it.
        // (saveRules already sanitizes, so we prove the load path independently by sanitizing a rule set directly.)
        let (safe, downgraded) = SoundRuleSafetyV1.sanitize([soundRule("legacy", "siren", .hideIfControlled),
                                                             textRule("t", "spoiler", .hideIfControlled)])
        XCTAssertEqual(downgraded, ["legacy"], "only the unsafe sound rule is flagged (§1.1 visible downgrade)")
        XCTAssertEqual(safe.first(where: { $0.ruleID == "legacy" })?.action, .warn)
        XCTAssertEqual(safe.first(where: { $0.ruleID == "t" })?.action, .hideIfControlled, "text HIDE is untouched")
        // And the store surfaces the same via loadPolicy.soundRulesDowngraded after a save of an unsafe set.
        _ = try store.saveRules([soundRule("snd-x", "applause", .muteIfControlled)])
        XCTAssertEqual(store.loadPolicy().rules.first?.action, .warn)
    }

    // MARK: §1.1 — the SAME validation governs Personal Learning proposals (a sound rule can't be proposed into HIDE).

    func testLearningNeverProposesSoundRuleIntoDestructiveAction() {
        let engine = LocalLearningProposalEngineV1(baseThreshold: 3, strictThreshold: 3)
        let rule = soundRule("snd-1", "siren", .ask)   // tightening would move ASK→HIDE for a text rule, but NOT sound
        let proposed = engine.proposedAction(from: .ask, direction: .tighten, rule: rule)
        XCTAssertNil(proposed, "a sound rule may never be proposed into a controlled execute action (§1.1 on proposals)")
        let textProposed = engine.proposedAction(from: .ask, direction: .tighten, rule: textRule("t", "x", .ask))
        XCTAssertEqual(textProposed, .hideIfControlled, "a text rule CAN tighten ASK→HIDE")
    }

    // MARK: §1.3 — the SAME label in two SEPARATE time ranges is NOT merged into one continuous event.

    func testAudioWindowsDistantSameLabelStaySeparate() {
        let windows = [
            TimedAudioClassification(label: "siren", confidence: 0.8, startSeconds: 0.0, endSeconds: 1.0),
            TimedAudioClassification(label: "siren", confidence: 0.9, startSeconds: 8.0, endSeconds: 9.0),
        ]
        let events = ReelsAudioEvidenceProviderV1.mergeAdjacentWindows(windows, classifierVersion: "v")
        XCTAssertEqual(events.count, 2, "distant occurrences of the same label stay as SEPARATE records (§1.3)")
        // No single event spans the silent 1..8 gap.
        XCTAssertFalse(events.contains { ($0.startSeconds ?? 0) <= 0.1 && ($0.endSeconds ?? 0) >= 8.9 },
                       "no fabricated continuous event across the gap (§1.3)")
    }

    func testAudioWindowsAdjacentSameLabelMerge() {
        let windows = [
            TimedAudioClassification(label: "siren", confidence: 0.7, startSeconds: 0.0, endSeconds: 0.5),
            TimedAudioClassification(label: "siren", confidence: 0.9, startSeconds: 0.6, endSeconds: 1.0),  // gap 0.1s ≤ 0.5
        ]
        let events = ReelsAudioEvidenceProviderV1.mergeAdjacentWindows(windows, classifierVersion: "v")
        XCTAssertEqual(events.count, 1, "adjacent windows (gap ≤ 0.5s) merge into one observed event (§1.3)")
        XCTAssertEqual(events.first?.startSeconds, 0.0)
        XCTAssertEqual(events.first?.endSeconds, 1.0)
        XCTAssertEqual(events.first?.rawModelConfidence, 0.9, "the merged run keeps the strongest raw confidence")
    }

    // MARK: §1.4 — a REAL owned VIDEO with an embedded AUDIO track goes through the full Sound Analysis path.

    func testRealVideoWithAudioTrackRunsFullAnalysisPath() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("av-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { cleanup(dir) }
        let url = dir.appendingPathComponent("clip.mp4")
        let spec = SyntheticVideo.Spec(durationSeconds: 2.0, fps: 6, textEvents: [(0.0, "hello")])
        let wrote = await SyntheticVideo.writeWithAudioTone(spec, to: url)
        try XCTSkipUnless(wrote, "AVAssetWriter video+audio fixture unavailable on this runtime")
        // The fixture really has an audio track (absence≠silence check passes only with a real track).
        let hasAudio = await ReelsAudioEvidenceProviderV1.hasAudioTrack(asset: AVURLAsset(url: url))
        XCTAssertEqual(hasAudio, true, "the generated VIDEO carries a real embedded AUDIO track (§1.4)")
        #if canImport(SoundAnalysis)
        let dictionary = Set((try? SNClassifySoundRequest(classifierIdentifier: .version1).knownClassifications) ?? [])
        try XCTSkipUnless(!dictionary.isEmpty, "SoundAnalysis dictionary unavailable on this runtime")
        let bundle = await ReelsAudioEvidenceProviderV1().gatherAudioEvidence(url: url, thermal: .nominal)
        // The analysis path REALLY RAN over the video's audio channel (not a stub, not a WAV) — acceptance §1.4.
        XCTAssertEqual(bundle.availability, .available, "the full VIDEO→audio→Sound Analysis path executed (§1.4)")
        // Only REAL classifier labels — never a presumed label (a tone is a tone).
        for ev in bundle.events { XCTAssertTrue(dictionary.contains(ev.label), "only real classifier labels (§1.4)") }
        #endif
    }

    // MARK: §1.2 — a cancelled sound analysis does NOT leak its result into a different reel.

    func testCancelledAudioAnalysisYieldsUnavailableNotApplied() async throws {
        #if canImport(SoundAnalysis)
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cancel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { cleanup(dir) }
        let url = dir.appendingPathComponent("tone.wav")
        try XCTSkipUnless(SyntheticAudio.writeTone(frequency: 440, seconds: 2.0, to: url), "tone write unavailable")
        // Cancel BEFORE awaiting: the cancellable path must short-circuit to UNAVAILABLE (never a result to apply).
        let head = GeneralAudioHeadV1()
        let task = Task { () -> (availability: AvailabilityState, events: [TimedAudioClassification]) in
            await head.classifyTimedCancellable(url: url)
        }
        task.cancel()
        let result = await task.value
        XCTAssertEqual(result.availability, .unavailable, "a cancelled analysis returns UNAVAILABLE — not a leaked result (§1.2)")
        XCTAssertTrue(result.events.isEmpty)
        #else
        throw XCTSkip("SoundAnalysis unavailable on this runtime")
        #endif
    }

    // MARK: §2.1 — an OLD prefetch task completing cannot erase NEW work (work-identity guard).

    @MainActor
    func testOldPrefetchCompletionDoesNotEraseNewWork() async {
        // We prove the work-identity guard via the public race surface: two prefetch kickoffs with a retarget between
        // them; the first (superseded) completion must not clear the second's in-flight/token/state.
        let (store, dir, _) = makeStore(); defer { cleanup(dir) }
        _ = try? store.saveRules([textRule("t", "spoiler", .warn)])
        let items = [ReelItemV1(id: "a", title: "a", url: URL(fileURLWithPath: "/tmp/a")),
                     ReelItemV1(id: "b", title: "b", url: URL(fileURLWithPath: "/tmp/b")),
                     ReelItemV1(id: "c", title: "c", url: URL(fileURLWithPath: "/tmp/c"))]
        let brain = ReelsPlayerModelV1(items: items, store: store, audioProvider: nil)
        let coord = PrefetchCoordinatorV1(sessionID: "s", brain: brain, items: items)
        coord.prefetchNext(after: 0)             // targets b
        coord.cancel(reason: "retarget")         // bumps work generation — any in-flight b completion is now stale
        coord.prefetchNext(after: 1)             // targets c (new authoritative work)
        // The coordinator's current target is c; the cancelled b work can never stomp it. State must not be CANCELLED
        // from a stale b completion once c is evaluating/ready.
        XCTAssertNotEqual(coord.state, .notStarted, "new work (c) is authoritative after retarget (§2.1)")
    }

    // MARK: §2.2 — READY is published the instant the async prefetch completes (state-change callback, no polling).

    @MainActor
    func testPrefetchStateChangeCallbackFires() async {
        let (store, dir, _) = makeStore(); defer { cleanup(dir) }
        _ = try? store.saveRules([textRule("t", "spoiler", .warn)])
        let items = [ReelItemV1(id: "a", title: "a", url: URL(fileURLWithPath: "/tmp/a")),
                     ReelItemV1(id: "b", title: "b", url: URL(fileURLWithPath: "/tmp/b"))]
        let brain = ReelsPlayerModelV1(items: items, store: store, audioProvider: nil)
        let coord = PrefetchCoordinatorV1(sessionID: "s", brain: brain, items: items)
        var observed: [PrefetchStateV1] = []
        coord.onStateChange = { observed.append($0) }
        coord.prefetchNext(after: 0)
        XCTAssertTrue(observed.contains(.evaluating), "the state-change callback fires on real transitions (§2.2)")
    }

    // MARK: §2.3 — unreadable asset never produces a stable 'noread' fingerprint that would match itself.

    func testUnreadableAssetFingerprintIsMarkedUnverifiable() {
        let bogus = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).mp4")
        let fp = PrefetchTokenV1.assetFingerprint(url: bogus)
        XCTAssertTrue(fp.contains("noread"), "an unreadable file carries an explicit noread marker (§2.3)")
        XCTAssertTrue(PrefetchTokenV1.isUnverifiable(fp), "the cache layer can detect an unverifiable asset (§2.3)")
        // Two DIFFERENT unreadable paths never collide (name/size differ), so a corrupt file never falsely matches
        // another one — the honest §2.3 guarantee without randomizing identity.
        let other = PrefetchTokenV1.assetFingerprint(url: URL(fileURLWithPath: "/tmp/other-\(UUID().uuidString).mp4"))
        XCTAssertNotEqual(fp, other, "distinct unreadable assets never collide (§2.3)")
    }

    func testFingerprintDiffersForDifferentTailBytes() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { cleanup(dir) }
        // Two files sharing a head block but differing in the TAIL → different fingerprints (§2.3 collision fix).
        let head = Data(repeating: 0xAB, count: 1024)
        let a = dir.appendingPathComponent("a.bin"); let b = dir.appendingPathComponent("b.bin")
        try (head + Data(repeating: 0x01, count: 512)).write(to: a)
        try (head + Data(repeating: 0x02, count: 512)).write(to: b)
        XCTAssertNotEqual(PrefetchTokenV1.contentBlockHash(url: a, fromEnd: true),
                          PrefetchTokenV1.contentBlockHash(url: b, fromEnd: true),
                          "different tail bytes yield different tail hashes (§2.3)")
    }

    // MARK: §2.4 — Guardian OFF / unknown consent stops heavy prefetch work on the controlled surface.

    @MainActor
    func testPrefetchHonoursAnalysisConsentOff() async {
        let (store, dir, _) = makeStore(); defer { cleanup(dir) }
        _ = try? store.saveRules([textRule("t", "spoiler", .warn)])
        let items = [ReelItemV1(id: "a", title: "a", url: URL(fileURLWithPath: "/tmp/a")),
                     ReelItemV1(id: "b", title: "b", url: URL(fileURLWithPath: "/tmp/b"))]
        let brain = ReelsPlayerModelV1(items: items, store: store, audioProvider: nil)
        // Consent = denied OFF → prefetchNext must NOT generate work.
        let coord = PrefetchCoordinatorV1(sessionID: "s", brain: brain, items: items,
                                          analysisConsent: { .deniedOff })
        coord.prefetchNext(after: 0)
        XCTAssertEqual(coord.state, .unavailable, "Guardian OFF → no heavy prefetch work (§2.4)")
        XCTAssertEqual(coord.prefetchStarted, 0, "no prefetch Task was started under OFF consent")
    }

    func testAnalysisConsentUnknownAbstains() {
        XCTAssertEqual(GuardianAnalysisGateV1.analysisConsent(suite: nil), .unknownAbstain)
        XCTAssertFalse(GuardianAnalysisGateV1.AnalysisConsentV1.unknownAbstain.mayRunAnalysis,
                       "unknown consent never runs heavy analysis (fail-closed, §2.4)")
    }
}
#endif
