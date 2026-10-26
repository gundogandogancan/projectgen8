//
//  LiveAudioEvidenceR8Tests.swift — R8 §1/§2/§3/§4: the LIVE audio sense (capture probe + streaming adapter +
//  identity-binding firewall + budget). SYNTHETIC-TESTED on the host; the AVAILABLE/device paths are DEVICE_UNVERIFIED.
//
import XCTest
import GuardianCore
@testable import GuardianMedia

final class LiveAudioEvidenceR8Tests: XCTestCase {

    // MARK: - §1 AudioCaptureProbeV1 — honest capture facts, silence vs unavailable, mic refusal, PTS continuity

    func testProbeDefaultVerdictIsFeatureUnverified() {
        let p = AudioCaptureProbeV1()
        XCTAssertEqual(p.verdict, .featureUnverified)
        XCTAssertFalse(p.audioCaptureAvailable)   // off-device: AUDIO_CAPTURE_AVAILABLE is never true without real data
    }

    func testProbeValidBufferUpgradesToPresentWithAudio() {
        var p = AudioCaptureProbeV1()
        let facts = AudioBufferFactsV1(sampleRate: 44100, channelCount: 2, bitsPerChannel: 16, isFloat: false,
                                       durationSeconds: 0.02, presentationSeconds: 1.0)
        p.record(facts: facts, isMicTagged: false, normalizedRMS: 0.5)
        XCTAssertEqual(p.verdict, .presentWithAudio)
        XCTAssertTrue(p.audioCaptureAvailable)
        XCTAssertEqual(p.buffersWithValidFormat, 1)
        XCTAssertGreaterThan(p.totalAudioSeconds, 0)
    }

    func testProbeInvalidFormatBufferIsDroppedNotClean() {
        var p = AudioCaptureProbeV1()
        let bad = AudioBufferFactsV1(sampleRate: nil, channelCount: nil, bitsPerChannel: nil, isFloat: nil,
                                     durationSeconds: nil, presentationSeconds: nil)
        p.record(facts: bad, isMicTagged: false, normalizedRMS: nil)
        XCTAssertEqual(p.verdict, .buffersMissingData)    // buffers came but no usable audio → NOT present-with-audio
        XCTAssertEqual(p.buffersDroppedInvalid, 1)
        XCTAssertFalse(p.audioCaptureAvailable)
    }

    func testProbeSilenceIsObservedNotUnavailable() {
        var p = AudioCaptureProbeV1()
        let facts = AudioBufferFactsV1(sampleRate: 48000, channelCount: 1, bitsPerChannel: 32, isFloat: true,
                                       durationSeconds: 0.01, presentationSeconds: 0.0)
        p.record(facts: facts, isMicTagged: false, normalizedRMS: 0.0001)   // below the silence floor
        XCTAssertEqual(p.buffersSilent, 1)                 // silence is a real observed fact...
        XCTAssertEqual(p.verdict, .presentWithAudio)       // ...NOT "unavailable" — the sense ran
    }

    func testProbeNeverCountsMicBuffers() {
        var p = AudioCaptureProbeV1()
        let facts = AudioBufferFactsV1(sampleRate: 44100, channelCount: 1, bitsPerChannel: 16, isFloat: false,
                                       durationSeconds: 0.02, presentationSeconds: 0.0)
        p.record(facts: facts, isMicTagged: true, normalizedRMS: 0.9)   // defense in depth: mic is never captured
        XCTAssertEqual(p.micBuffersRefused, 1)
        XCTAssertEqual(p.buffersObserved, 0)
        XCTAssertEqual(p.verdict, .featureUnverified)
    }

    func testProbePTSDiscontinuityDetected() {
        var p = AudioCaptureProbeV1()
        func f(_ pts: Double) -> AudioBufferFactsV1 {
            AudioBufferFactsV1(sampleRate: 44100, channelCount: 1, bitsPerChannel: 16, isFloat: false,
                               durationSeconds: 0.02, presentationSeconds: pts)
        }
        p.record(facts: f(1.0), isMicTagged: false, normalizedRMS: 0.5)
        p.record(facts: f(1.02), isMicTagged: false, normalizedRMS: 0.5)   // monotonic
        p.record(facts: f(0.5), isMicTagged: false, normalizedRMS: 0.5)    // went backwards → discontinuity
        XCTAssertEqual(p.ptsDiscontinuities, 1)
    }

    // MARK: - §4 BoundedAudioQueueV1 — drop-oldest, bounded growth, generation firewall drain

    func testBoundedQueueDropsOldestAtCapacity() {
        var q = BoundedAudioQueueV1(capacity: 3)
        let facts = AudioBufferFactsV1(sampleRate: 44100, channelCount: 1, bitsPerChannel: 16, isFloat: false,
                                       durationSeconds: 0.02, presentationSeconds: 0)
        for _ in 0..<5 { q.enqueue(LiveAudioQueuedSampleV1(facts: facts, generation: 1, itemIdentityRevision: 0)) }
        XCTAssertEqual(q.count, 3)              // bounded — never grows past capacity
        XCTAssertEqual(q.droppedOldest, 2)      // the two oldest were dropped honestly
    }

    func testDrainLiveDiscardsStaleGeneration() {
        var q = BoundedAudioQueueV1(capacity: 10)
        let facts = AudioBufferFactsV1(sampleRate: 44100, channelCount: 1, bitsPerChannel: 16, isFloat: false,
                                       durationSeconds: 0.02, presentationSeconds: 0)
        // two samples from the OLD item (gen 1 / rev 0), two from the NEW item (gen 2 / rev 1)
        q.enqueue(LiveAudioQueuedSampleV1(facts: facts, generation: 1, itemIdentityRevision: 0))
        q.enqueue(LiveAudioQueuedSampleV1(facts: facts, generation: 1, itemIdentityRevision: 0))
        q.enqueue(LiveAudioQueuedSampleV1(facts: facts, generation: 2, itemIdentityRevision: 1))
        q.enqueue(LiveAudioQueuedSampleV1(facts: facts, generation: 2, itemIdentityRevision: 1))
        let (live, discarded) = q.drainLive(liveGeneration: 2, liveItemRevision: 1)
        XCTAssertEqual(live.count, 2)           // only the NEW item's samples survive
        XCTAssertEqual(discarded, 2)            // the OLD item's audio is discarded (stale)
    }

    // MARK: - §4 window budget / thermal deferral (audio must never saturate the heavy path OCR owns)

    func testWindowDeferredUnderThermalSerious() {
        let d = LiveAudioEvidenceAdapterV1.windowDecision(thermal: .serious, windowsAlreadyRunThisItem: 0, ocrSaturatingHeavyPath: false)
        XCTAssertEqual(d, .deferredThermal)     // AUDIO_NOT_ANALYZED / RESOURCE_DEFERRED — honest, never clean
    }

    func testWindowDeferredWhenOCRSaturates() {
        let d = LiveAudioEvidenceAdapterV1.windowDecision(thermal: .nominal, windowsAlreadyRunThisItem: 0, ocrSaturatingHeavyPath: true)
        XCTAssertEqual(d, .resourceDeferred)    // audio yields to OCR — both never saturate the heavy path
    }

    func testWindowDeferredWhenBudgetSpent() {
        let d = LiveAudioEvidenceAdapterV1.windowDecision(thermal: .nominal,
                                                          windowsAlreadyRunThisItem: LiveAudioEvidenceAdapterV1.maxWindowsPerItem,
                                                          ocrSaturatingHeavyPath: false)
        XCTAssertEqual(d, .resourceDeferred)
    }

    func testWindowMayRunUnderNominal() {
        let d = LiveAudioEvidenceAdapterV1.windowDecision(thermal: .nominal, windowsAlreadyRunThisItem: 0, ocrSaturatingHeavyPath: false)
        XCTAssertNil(d)                         // nil ⇒ the window may run
    }

    // MARK: - §2 label verification — never assume a class name

    func testUnsupportedLabelAgainstEmptyDictIsUnavailable() {
        // With an explicit empty known list, NO label is supported (honest UNAVAILABLE, never a fabricated hit).
        XCTAssertFalse(LiveAudioEvidenceAdapterV1.supportsLabel("siren", known: []))
        XCTAssertFalse(LiveAudioEvidenceAdapterV1.supportsLabel("scream", known: []))
    }

    func testSupportedLabelIsCaseInsensitive() {
        XCTAssertTrue(LiveAudioEvidenceAdapterV1.supportsLabel("Siren", known: ["siren", "music"]))
        XCTAssertFalse(LiveAudioEvidenceAdapterV1.supportsLabel("explosion", known: ["siren", "music"]))
    }

    // MARK: - §3 the MANDATED counter-example: stale audio from a prior item never enters a new item's evaluation

    func testStaleAudioNeverEntersNewItemViaBridge() {
        // Reels1 audio was analyzed late (generation 1), but the user already swiped to Reels2 (generation 2).
        let stale = LiveAudioWindowEvidenceV1(
            availability: .available,
            events: [ReelsAudioEventV1(label: "siren", rawModelConfidence: 0.8, startSeconds: 0, endSeconds: 1,
                                       classifierVersion: GeneralAudioHeadV1.version)],
            binding: LiveAudioBindingV1(sessionID: "s", itemIdentityRevision: 0, generation: 1,
                                        ptsStartSeconds: 0, ptsEndSeconds: 1),
            classifierVersion: GeneralAudioHeadV1.version)
        // Build Reels2's world model (generation 2, revision 1) passing the STALE Reels1 audio.
        let result = WorldModelEvidenceBridgeV1.build(WorldModelBridgeInputV1(
            sessionID: "s", contentID: "reels2", itemIdentityRevision: 1, identityConfirmed: true,
            generation: 2, shotID: 20, observationStartMs: 0, observationEndMs: 100,
            ocrText: "hello", ocrLanguage: "en", policyRevision: 1, familyProfileRevision: 0,
            photoShieldActionableMatch: false, emotionalRegister: nil, liveAudioEvidence: stale))
        // The stale siren must NOT appear as a real audio-event label; the audioEvent modality stays UNAVAILABLE.
        XCTAssertTrue(result.unavailableModalities.contains(ExpertDomainV2.audioEvent.rawValue),
                      "stale audio from a prior item/generation must leave audioEvent UNAVAILABLE on the new item")
    }

    // MARK: - §3 the controlled counter-example: a fresh audio event DOES raise coverage on the SAME item

    func testFreshAudioEventRaisesCoverageOnSameItem() {
        let binding = LiveAudioBindingV1(sessionID: "s", itemIdentityRevision: 5, generation: 9,
                                         ptsStartSeconds: 2, ptsEndSeconds: 3)
        let fresh = LiveAudioWindowEvidenceV1(
            availability: .available,
            events: [ReelsAudioEventV1(label: "siren", rawModelConfidence: 0.77, startSeconds: 2, endSeconds: 3,
                                       classifierVersion: GeneralAudioHeadV1.version)],
            binding: binding, classifierVersion: GeneralAudioHeadV1.version)
        // Baseline: SAME item WITHOUT audio → audioEvent is UNAVAILABLE.
        let withoutAudio = WorldModelEvidenceBridgeV1.build(WorldModelBridgeInputV1(
            sessionID: "s", contentID: "reelsX", itemIdentityRevision: 5, identityConfirmed: true,
            generation: 9, shotID: 50, observationStartMs: 0, observationEndMs: 100,
            ocrText: "hello", ocrLanguage: "en", policyRevision: 1, familyProfileRevision: 0,
            photoShieldActionableMatch: false, emotionalRegister: nil, liveAudioEvidence: nil))
        XCTAssertTrue(withoutAudio.unavailableModalities.contains(ExpertDomainV2.audioEvent.rawValue))
        // With the FRESH, matching-generation audio → audioEvent is NO LONGER unavailable; coverage rose.
        let withAudio = WorldModelEvidenceBridgeV1.build(WorldModelBridgeInputV1(
            sessionID: "s", contentID: "reelsX", itemIdentityRevision: 5, identityConfirmed: true,
            generation: 9, shotID: 50, observationStartMs: 0, observationEndMs: 100,
            ocrText: "hello", ocrLanguage: "en", policyRevision: 1, familyProfileRevision: 0,
            photoShieldActionableMatch: false, emotionalRegister: nil, liveAudioEvidence: fresh))
        XCTAssertFalse(withAudio.unavailableModalities.contains(ExpertDomainV2.audioEvent.rawValue),
                       "a fresh in-generation audio event must replace the UNAVAILABLE audioEvent record")
        XCTAssertGreaterThan(withAudio.evidenceCount, withoutAudio.evidenceCount - 1,
                             "the real audio-event envelope adds evidence (coverage) to the same item")
    }

    // MARK: - §4 a DEFERRED audio window is never "clean": audioEvent stays UNAVAILABLE (no sound ≠ safe)

    func testDeferredAudioLeavesModalityUnavailable() {
        let deferred = LiveAudioWindowEvidenceV1.unavailable(
            .deferredThermal,
            binding: LiveAudioBindingV1(sessionID: "s", itemIdentityRevision: 3, generation: 4,
                                        ptsStartSeconds: nil, ptsEndSeconds: nil),
            classifierVersion: GeneralAudioHeadV1.version)
        let result = WorldModelEvidenceBridgeV1.build(WorldModelBridgeInputV1(
            sessionID: "s", contentID: "c", itemIdentityRevision: 3, identityConfirmed: true,
            generation: 4, shotID: 30, observationStartMs: 0, observationEndMs: 10,
            ocrText: "x", ocrLanguage: "en", policyRevision: 1, familyProfileRevision: 0,
            photoShieldActionableMatch: false, emotionalRegister: nil, liveAudioEvidence: deferred))
        XCTAssertTrue(result.unavailableModalities.contains(ExpertDomainV2.audioEvent.rawValue),
                      "a thermally-deferred audio window must never be presented as audio-analyzed-clean")
    }
}
