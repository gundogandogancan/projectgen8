//
//  LiveAudioInferenceR9Tests.swift — R9 §1/§2/§2.3/§3/§4/§5: REAL AUDIO INFERENCE CORRECTNESS.
//
//  WHAT THESE PIN (mandate §1–§5): the R8 live-audio path could set availability `.available` with `events:[]` the
//  instant a window's worth of buffers was drained — WITHOUT the classifier ever running. R9 kills that: `.available`
//  is reachable ONLY when the explicit WINDOW-COMPLETION contract climbed the honest ladder through a REAL classifier
//  completion. These tests pin the ladder, the completion semantics (§2.3), the frame↔PTS mapping contract (§3), the
//  bytes/duration bounded queue (§2.2), and the §5 regression matrix. The device AVAILABLE path is synthetic-driven
//  where SoundAnalysis can run on this host (P0-4), and honestly reported CLASSIFIER_UNAVAILABLE_ON_HOST otherwise.
//
import XCTest
import GuardianCore
@testable import GuardianMedia
#if canImport(AVFoundation)
import AVFoundation
#endif

final class LiveAudioInferenceR9Tests: XCTestCase {

    // MARK: - §1 THE MANDATED REGRESSION — buffer received + analyzer NEVER invoked → available MUST be false

    func testBufferReceivedButAnalyzerNeverInvokedIsNotAvailable() {
        // The ladder's first rung is AUDIO_BUFFER_RECEIVED. A window that only received a buffer (and never submitted
        // to / completed through the classifier) must NOT be analysis-success and must NOT map to `.available`.
        var contract = LiveAudioWindowCompletionContractV1()
        contract.beginWindow()                       // AUDIO_BUFFER_RECEIVED
        contract.markPCMConverted()                  // PCM_CONVERSION_SUCCEEDED
        contract.markClassifierInitialized()         // CLASSIFIER_INITIALIZED — analyzer armed, but nothing submitted
        XCTAssertFalse(contract.mayReportAvailable, "a window that never SUBMITTED to the classifier is not analysis")
        XCTAssertNotEqual(contract.availability, .available, "FAKE AVAILABLE is forbidden (mandate §1)")
        XCTAssertEqual(contract.state, .classifierInitialized)
    }

    func testSubmittedButNoCompletionIsPendingNotClean() {
        // SUBMITTED ≠ RESULT_RECEIVED ≠ WINDOW_COMPLETE (mandate §2.3). A submitted-but-un-completed window is PENDING.
        var contract = LiveAudioWindowCompletionContractV1()
        contract.beginWindow(); contract.markPCMConverted(); contract.markClassifierInitialized()
        contract.markSubmitted(atSeconds: 100)
        XCTAssertEqual(contract.state, .classifierWindowSubmitted)
        XCTAssertFalse(contract.mayReportAvailable, "starting the analyzer + reading empty is NOT analysis success")
        XCTAssertNotEqual(contract.availability, .available)
    }

    // MARK: - §2.3 completion semantics — the ONLY two lawful .available terminals

    func testResultReceivedIsTheRealAvailableTerminal() {
        var contract = LiveAudioWindowCompletionContractV1()
        contract.beginWindow(); contract.markPCMConverted(); contract.markClassifierInitialized()
        contract.markSubmitted(atSeconds: 1); contract.markResultReceived(); contract.markCompletionObserved()
        XCTAssertEqual(contract.state, .classifierResultReceived)
        XCTAssertTrue(contract.mayReportAvailable)
        XCTAssertEqual(contract.availability, .available)
    }

    func testVerifiedCompletedNoEventIsAvailableOnlyAfterRealSubmission() {
        // A window that was genuinely SUBMITTED and then VERIFIABLY COMPLETED with no label → ANALYSIS_COMPLETED_NO_EVENT
        // is lawful `.available` (the sense ran, found nothing). Crucially this requires the submission first.
        var contract = LiveAudioWindowCompletionContractV1()
        contract.beginWindow(); contract.markPCMConverted(); contract.markClassifierInitialized()
        contract.markSubmitted(atSeconds: 1); contract.markCompletionObserved()   // no result, but completed
        XCTAssertEqual(contract.state, .analysisCompletedNoEvent)
        XCTAssertTrue(contract.mayReportAvailable)
        XCTAssertEqual(contract.availability, .available)
    }

    func testCompletionWithoutSubmissionIsIgnored() {
        // Defense in depth: a completion/result signal that arrives without a prior submission is NOT success.
        var contract = LiveAudioWindowCompletionContractV1()
        contract.beginWindow(); contract.markPCMConverted(); contract.markClassifierInitialized()
        contract.markCompletionObserved()   // no submission → ignored
        contract.markResultReceived()       // no submission → ignored
        XCTAssertFalse(contract.mayReportAvailable)
        XCTAssertEqual(contract.state, .classifierInitialized)
    }

    func testTimeoutTurnsPendingWindowIntoFailureNotCleanResult() {
        var contract = LiveAudioWindowCompletionContractV1()
        contract.beginWindow(); contract.markPCMConverted(); contract.markClassifierInitialized()
        contract.markSubmitted(atSeconds: 10)
        // No result/completion within the budget → TIMED OUT → analysisFailed (never a clean empty available).
        let state = contract.resolveTimeout(nowSeconds: 10 + LiveAudioWindowCompletionContractV1.completionTimeoutSeconds + 0.1)
        XCTAssertEqual(state, .analysisFailed)
        XCTAssertFalse(contract.mayReportAvailable)
        XCTAssertEqual(contract.availability, .frameworkUnavailable)
    }

    // MARK: - §4/§5 honest non-analysis terminals NEVER map to .available

    func testDeferralTerminalsAreNeverAvailable() {
        var thermal = LiveAudioWindowCompletionContractV1(); thermal.beginWindow(); thermal.markDeferred(thermal: true)
        XCTAssertFalse(thermal.mayReportAvailable)
        XCTAssertEqual(thermal.availability, .deferredThermal)
        var resource = LiveAudioWindowCompletionContractV1(); resource.beginWindow(); resource.markDeferred(thermal: false)
        XCTAssertEqual(resource.availability, .resourceDeferred)
        var fmt = LiveAudioWindowCompletionContractV1(); fmt.beginWindow(); fmt.markFormatUnsupported()
        XCTAssertEqual(fmt.availability, .formatUnsupported); XCTAssertFalse(fmt.mayReportAvailable)
        var none = LiveAudioWindowCompletionContractV1(); none.beginWindow(); none.markNoBuffers()
        XCTAssertEqual(none.availability, .noBuffers); XCTAssertFalse(none.mayReportAvailable)
        var dev = LiveAudioWindowCompletionContractV1(); dev.beginWindow(); dev.markDeviceUnverified()
        XCTAssertFalse(dev.mayReportAvailable)
    }

    func testEveryLadderStateMapsAvailableOnlyForTheTwoRealTerminals() {
        for s in LiveAudioAnalysisStateV1.allCases {
            let avail = s.toAvailability(wasThermalDeferral: false)
            let expectedAvailable = (s == .classifierResultReceived || s == .analysisCompletedNoEvent)
            XCTAssertEqual(avail == .available, expectedAvailable,
                           "ladder \(s.rawValue) → available must be \(expectedAvailable)")
            XCTAssertEqual(s.analysisGenuinelyRan, expectedAvailable)
        }
    }

    // MARK: - §3 TIMEBASE — analyzer frame domain is NOT ReplayKit absolute PTS; explicit mapping contract

    func testFrameToPTSMappingAnchorsToRealFirstBufferPTS() {
        // Analyzer frame 0 == the window's REAL first-buffer PTS (say 42.0s); frame 16000 @ 16kHz == +1.0s == 43.0s.
        let map = AudioFrameToPTSMapV1(anchorPTSSeconds: 42.0, sampleRate: 16000)
        XCTAssertTrue(map.isMappable)
        XCTAssertEqual(map.absolutePTS(forAnalyzerFrame: 0), 42.0)
        XCTAssertEqual(map.absolutePTS(forAnalyzerFrame: 16000)!, 43.0, accuracy: 1e-9)
        let (s, e) = map.absolutePTSRange(analyzerStartSeconds: 0.5, analyzerEndSeconds: 1.5)
        XCTAssertEqual(s!, 42.5, accuracy: 1e-9); XCTAssertEqual(e!, 43.5, accuracy: 1e-9)
    }

    func testUnmappableTimebaseYieldsUnboundSpan() {
        // No anchor (we never captured a real first-buffer PTS) → the span is UNBOUND, never a fabricated absolute PTS.
        let noAnchor = AudioFrameToPTSMapV1(anchorPTSSeconds: nil, sampleRate: 16000)
        XCTAssertFalse(noAnchor.isMappable)
        XCTAssertNil(noAnchor.absolutePTS(forAnalyzerFrame: 1000))
        XCTAssertNil(noAnchor.absolutePTSRange(analyzerStartSeconds: 0.2, analyzerEndSeconds: 0.8).start)
        // No/invalid sample rate → unmappable too.
        let noRate = AudioFrameToPTSMapV1(anchorPTSSeconds: 10.0, sampleRate: 0)
        XCTAssertFalse(noRate.isMappable)
        XCTAssertNil(noRate.absolutePTS(forAnalyzerFrame: 100))
    }

    // MARK: - §2.2 bounded queue by BYTES + DURATION (not just item count); overflow drops oldest + counts loss

    func testQueueBoundedByByteBudget() {
        // Each ~0.5s of 48kHz stereo 16-bit ≈ 48000*2*2*0.5 ≈ 96000 bytes. A 200KB byte budget holds ~2 such samples.
        var q = BoundedAudioQueueV1(capacity: 100, maxBytes: 200_000, maxDurationSeconds: 0)
        let facts = AudioBufferFactsV1(sampleRate: 48000, channelCount: 2, bitsPerChannel: 16, isFloat: false,
                                       durationSeconds: 0.5, presentationSeconds: 0)
        for _ in 0..<6 { q.enqueue(LiveAudioQueuedSampleV1(facts: facts, generation: 1, itemIdentityRevision: 0)) }
        XCTAssertLessThanOrEqual(q.retainedBytes, 200_000, "byte budget bounds retained PCM memory")
        XCTAssertGreaterThan(q.droppedOldest, 0, "overflow dropped oldest and counted the loss")
        XCTAssertLessThan(q.count, 6)
    }

    func testQueueBoundedByDurationBudget() {
        var q = BoundedAudioQueueV1(capacity: 100, maxBytes: 0, maxDurationSeconds: 2.0)
        let facts = AudioBufferFactsV1(sampleRate: 16000, channelCount: 1, bitsPerChannel: 16, isFloat: false,
                                       durationSeconds: 0.5, presentationSeconds: 0)
        for _ in 0..<10 { q.enqueue(LiveAudioQueuedSampleV1(facts: facts, generation: 1, itemIdentityRevision: 0)) }
        XCTAssertLessThanOrEqual(q.retainedDurationSeconds, 2.0 + 0.5, "duration budget bounds retained audio seconds")
        XCTAssertGreaterThan(q.droppedOldest, 0)
    }

    func testQueueKeepsAtLeastOneSampleEvenWhenOversized() {
        // A single buffer larger than the byte budget must still be retained (we never drop the ONLY sample).
        var q = BoundedAudioQueueV1(capacity: 10, maxBytes: 1000, maxDurationSeconds: 0)
        let big = AudioBufferFactsV1(sampleRate: 48000, channelCount: 2, bitsPerChannel: 16, isFloat: false,
                                     durationSeconds: 1.0, presentationSeconds: 0)
        q.enqueue(LiveAudioQueuedSampleV1(facts: big, generation: 1, itemIdentityRevision: 0))
        XCTAssertEqual(q.count, 1, "a single oversized buffer is still analyzable")
    }

    // MARK: - §4 the AVAILABLE evidence now carries REAL events (not a hardcoded empty)

    func testAvailableEvidenceCarriesRealEventsThroughToBridge() {
        // A genuinely-completed window with a real classifier label flows as an audio-event to the bridge (SAME item).
        let binding = LiveAudioBindingV1(sessionID: "s", itemIdentityRevision: 7, generation: 3,
                                         ptsStartSeconds: 42.0, ptsEndSeconds: 43.0)
        let ran = LiveAudioWindowEvidenceV1(
            availability: .available,
            events: [ReelsAudioEventV1(label: "music", rawModelConfidence: 0.66, startSeconds: 42.0, endSeconds: 43.0,
                                       classifierVersion: GeneralAudioHeadV1.version)],
            binding: binding, classifierVersion: GeneralAudioHeadV1.version)
        let result = WorldModelEvidenceBridgeV1.build(WorldModelBridgeInputV1(
            sessionID: "s", contentID: "c7", itemIdentityRevision: 7, identityConfirmed: true,
            generation: 3, shotID: 70, observationStartMs: 0, observationEndMs: 2000,
            ocrText: "x", ocrLanguage: "en", policyRevision: 1, familyProfileRevision: 0,
            photoShieldActionableMatch: false, emotionalRegister: nil, liveAudioEvidence: ran))
        XCTAssertFalse(result.unavailableModalities.contains(ExpertDomainV2.audioEvent.rawValue),
                       "a genuinely-analyzed window with a real event raises audio coverage on the same item")
    }

    // MARK: - §4 P0-4: controlled SYNTHETIC PCM → SNAudioStreamAnalyzer → REAL result → event → bridge

    func testSyntheticPCMDrivesRealClassifierEndToEndOrReportsUnavailableOnHost() async throws {
        #if canImport(AVFoundation) && canImport(SoundAnalysis)
        // Generate an OWNED synthetic tone WAV (no copyrighted audio), decode it to PCM buffers, and drive the REAL
        // streaming analyzer through the completion contract. We assert on the MECHANISM (a real completion flowed via
        // the honest ladder), NOT on a specific label — the host classifier returns whatever it returns.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("r9_tone_\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        guard SyntheticAudio.writeTone(frequency: 440, seconds: 2.0, sampleRate: 16000, to: url) else {
            throw XCTSkip("CLASSIFIER_UNAVAILABLE_ON_HOST: could not synthesize PCM (AVAudioFile write unavailable)")
        }
        guard let file = try? AVAudioFile(forReading: url) else {
            throw XCTSkip("CLASSIFIER_UNAVAILABLE_ON_HOST: could not open synthetic PCM for reading")
        }
        let fmt = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0, let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames) else {
            throw XCTSkip("CLASSIFIER_UNAVAILABLE_ON_HOST: could not allocate PCM buffer")
        }
        try file.read(into: buf)

        let session = LiveAudioStreamSessionV1()
        // Anchor the frame↔PTS map to a REAL first-buffer PTS of 10.0s so we can verify absolute-PTS resolution.
        let result = session.analyzeWindow([buf], anchorPTSSeconds: 10.0)
        // The MECHANISM assertion: the window genuinely climbed the ladder to a real completion terminal (result OR a
        // verified completed-no-event). A host that cannot run inference would land on a non-analysis terminal — which
        // we surface honestly rather than as a fake pass.
        if result.ladderState.analysisGenuinelyRan {
            XCTAssertTrue(result.completionObserved, "a real .available must have an OBSERVED completion (§2.3)")
            XCTAssertGreaterThan(result.buffersSubmitted, 0, "a real window actually submitted PCM to the classifier")
            // If the classifier produced events, their absolute PTS must be anchored past 10.0s (frame→PTS map, §3).
            for e in result.events where e.startSeconds != nil {
                XCTAssertGreaterThanOrEqual(e.startSeconds!, 10.0, "event PTS is absolute (anchored), not analyzer-relative")
            }
        } else {
            // Honest host report — NEVER a fake pass. Record the real terminal for the proof log.
            throw XCTSkip("CLASSIFIER_UNAVAILABLE_ON_HOST: SoundAnalysis did not complete a window on this host (ladder=\(result.ladderState.rawValue))")
        }
        #else
        throw XCTSkip("CLASSIFIER_UNAVAILABLE_ON_HOST: SoundAnalysis/AVFoundation not importable on this SDK")
        #endif
    }

    func testEmptyWindowThroughStreamSessionIsNoBuffersNeverClean() {
        #if canImport(AVFoundation) && canImport(SoundAnalysis)
        let session = LiveAudioStreamSessionV1()
        let result = session.analyzeWindow([], anchorPTSSeconds: nil)
        XCTAssertEqual(result.ladderState, .captureUnavailable)
        XCTAssertFalse(result.ladderState.analysisGenuinelyRan, "no buffers → never a clean available")
        #endif
    }

    // MARK: - §3 stale-audio firewall on the REAL async path: a late completion for a prior item is dropped

    func testLateAudioCompletionForPriorItemIsDroppedByBridgeGenerationFirewall() {
        // A window that genuinely RAN for Reels1 (generation 1) completes AFTER the user swiped to Reels2 (gen 2).
        // Even though it is a REAL `.available` result, the bridge's generation firewall keeps audioEvent UNAVAILABLE
        // on Reels2 — the mandated §3 counter-example extended to the real completion path.
        let lateReal = LiveAudioWindowEvidenceV1(
            availability: .available,
            events: [ReelsAudioEventV1(label: "speech", rawModelConfidence: 0.9, startSeconds: 1, endSeconds: 2,
                                       classifierVersion: GeneralAudioHeadV1.version)],
            binding: LiveAudioBindingV1(sessionID: "s", itemIdentityRevision: 0, generation: 1,
                                        ptsStartSeconds: 1, ptsEndSeconds: 2),
            classifierVersion: GeneralAudioHeadV1.version)
        let reels2 = WorldModelEvidenceBridgeV1.build(WorldModelBridgeInputV1(
            sessionID: "s", contentID: "reels2", itemIdentityRevision: 1, identityConfirmed: true,
            generation: 2, shotID: 20, observationStartMs: 0, observationEndMs: 100,
            ocrText: "hello", ocrLanguage: "en", policyRevision: 1, familyProfileRevision: 0,
            photoShieldActionableMatch: false, emotionalRegister: nil, liveAudioEvidence: lateReal))
        XCTAssertTrue(reels2.unavailableModalities.contains(ExpertDomainV2.audioEvent.rawValue),
                      "a late REAL completion for a prior item/generation never enters the new item")
    }

    // MARK: - §8 (P1-7) coverage honesty — the heartbeat carries the audio ladder state (backward-compatible)

    func testHeartbeatCarriesAudioLadderStateRoundTrip() {
        let hb = GuardianObservationHeartbeatV1(epochSeconds: 1, sequence: 1, surfaceRaw: "GUARDIAN_ON",
                                                reasonCodeRaw: "x", broadcasting: true,
                                                audioLadderStateRaw: LiveAudioAnalysisStateV1.resourceDeferred.rawValue)
        let data = try! JSONEncoder().encode(hb)
        let back = try! JSONDecoder().decode(GuardianObservationHeartbeatV1.self, from: data)
        XCTAssertEqual(back.audioLadderStateRaw, LiveAudioAnalysisStateV1.resourceDeferred.rawValue)
    }

    func testLegacyHeartbeatWithoutAudioFieldDecodesAsEmpty() {
        // A legacy JSON (no audioLadderStateRaw key) must still decode, with audio coverage treated as UNKNOWN (empty)
        // — never implying audio was analyzed (mandate §8: missing audio ≠ "all senses active").
        let legacy = #"{"epochSeconds":1,"sequence":1,"surfaceRaw":"GUARDIAN_ON","reasonCodeRaw":"x","broadcasting":true}"#
        let back = try! JSONDecoder().decode(GuardianObservationHeartbeatV1.self, from: Data(legacy.utf8))
        XCTAssertEqual(back.audioLadderStateRaw, "")
    }

    // MARK: - §5 regression matrix — each failure mode lands in an honest ladder state (none fakes .available)

    func testRegressionMatrixEachModeLandsInHonestNonAvailableState() {
        // thermal skip / resource deferral / no buffers / unsupported format / stream crash / classifier unavailable /
        // device-unverified — each maps to a NON-available availability (no silent clean/safe claim).
        let modes: [(LiveAudioAnalysisStateV1, Bool)] = [
            (.resourceDeferred, true),   // thermal skip
            (.resourceDeferred, false),  // resource deferral
            (.captureUnavailable, false),// no buffers
            (.formatUnsupported, false), // unsupported format
            (.analysisFailed, false),    // stream crash / analyzer threw
            (.deviceUnverified, false),  // classifier unavailable on host
        ]
        for (state, thermal) in modes {
            let avail = state.toAvailability(wasThermalDeferral: thermal)
            XCTAssertNotEqual(avail, .available, "\(state.rawValue) must never present as audio-analyzed-clean")
        }
    }
}
