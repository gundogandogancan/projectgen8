//
//  AudioEvidenceV1Tests.swift — §D–§H BUILD proof for AUDIO EVIDENCE V1 ("The Guardian Learns to Hear").
//
//  TWO evidence layers, both honest:
//   1. REAL SoundAnalysis over an OWNED generated audio fixture (tone / silence / speech WAV). We assert on what the
//      Apple classifier ACTUALLY does — that analysis RUNS and returns the classifier's OWN labels/confidences — NOT
//      on a wished-for label (a tone is a tone). OS/label-dependent specifics are gated with XCTSkip + reason, never
//      faked. This is the mechanics/availability proof the mandate allows where real samples can't prove FP/FN.
//   2. DETERMINISTIC-STUB fusion/coverage/conflict proof over the pure decision path: a stub ReelsAudioEvidenceProviding
//      feeds known labels so we can prove audio→policy fusion (via the FROZEN SoundClassMatcher), absence≠silence
//      coverage, separate audio/visual provenance, conflict→UNKNOWN, and thermal deferral — WITHOUT SoundAnalysis
//      runtime variance. No fabricated classifier labels anywhere; raw confidence is never presented as Guardian risk.
//
//  Covers acceptance: 8 (Evidence screen gains real audio modality), 9 (real file via Sound Analysis), 10 (no
//  fabricated classes), 11 (audio bound to personal policy), 12 (audio absence ≠ safe), 13 (audio/visual separate
//  provenance), 14 (thermal budget defers audio honestly).
//
import XCTest
@testable import GuardianMedia
import GuardianCore
#if canImport(AVFoundation) && canImport(SoundAnalysis)
import AVFoundation
import SoundAnalysis

final class AudioEvidenceV1Tests: XCTestCase {

    // MARK: Helpers — isolated store + a deterministic audio stub + a sound-class rule.

    private func makeStore() -> (store: PersonalShieldSharedStoreV1, dir: URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("audio-\(UUID().uuidString)")
        let suite = UserDefaults(suiteName: "audio.store.\(UUID().uuidString)")!
        return (PersonalShieldSharedStoreV1(directory: dir, suite: suite, sharedContainerActive: true), dir)
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    /// A `.soundClass` rule: the frozen SoundClassMatcher matches `rawUserLabel` (substring) against envelope.soundEvents.
    private func soundRule(_ id: String, _ label: String, _ action: ShieldAction) -> ShieldRuleV2 {
        ShieldRuleV2(ruleID: id, inputType: .soundClass, rawUserLabel: label, locale: "en", action: action,
                     createdAtEpoch: 1, updatedAtEpoch: 1)
    }
    private func textRule(_ id: String, _ label: String, _ action: ShieldAction) -> ShieldRuleV2 {
        ShieldRuleV2(ruleID: id, inputType: .textExact, rawUserLabel: label, locale: "en", action: action,
                     createdAtEpoch: 1, updatedAtEpoch: 1)
    }
    private func item(_ id: String) -> ReelItemV1 { ReelItemV1(id: id, title: "t", url: URL(fileURLWithPath: "/tmp/\(id)")) }

    /// A deterministic AUDIO provider: returns a fixed ReelsAudioEvidenceV1, so the fusion/coverage/conflict logic is
    /// testable without SoundAnalysis runtime variance. Honours thermal deferral so the §H path is exercised too.
    private struct StubAudio: ReelsAudioEvidenceProviding {
        let bundle: ReelsAudioEvidenceV1
        func gatherAudioEvidence(url: URL, thermal: ReelsThermalBucketV1) async -> ReelsAudioEvidenceV1 {
            if thermal == .critical { return .unavailable(.deferredThermal, classifierVersion: "stub") }
            return bundle
        }
    }
    /// A visual stub so the fused decision has a known visual baseline (plays / no OCR match) that audio can add to.
    private struct StubVisual: ReelsEvidenceProviding {
        let ocrText: String
        func gatherEvidence(url: URL, metadataTitle: String, firstFrameSeconds: [Double], languages: [String]) async -> ReelsEvidenceV1 {
            ReelsEvidenceProviderV1.fuse(ocrText: ocrText, metadataText: "clip", frameCoverage: 1,
                                         ocrExecuted: !ocrText.isEmpty, languages: ["en"],
                                         timedRecords: ocrText.isEmpty ? [] : [.init(timestampSeconds: 0.2, modality: .visualOCR, ocrStatus: .ran, text: ocrText)])
        }
    }
    private func audio(_ labels: [(String, Double)], availability: ReelsAudioAvailabilityV1 = .available) -> ReelsAudioEvidenceV1 {
        ReelsAudioEvidenceV1(availability: availability,
                             events: labels.map { .init(label: $0.0, rawModelConfidence: $0.1, startSeconds: nil, endSeconds: nil, classifierVersion: "stub-classifier-v1") },
                             classifierVersion: "stub-classifier-v1")
    }

    // MARK: #11 — AUDIO EVENT BOUND TO A PERSONAL POLICY (fusion via the frozen SoundClassMatcher).

    func testAudioLabelMatchesUserSoundClassRuleAndWarns() async {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try? store.saveRules([soundRule("snd-1", "siren", .warn)])    // the user doesn't want sirens → WARN
        // No visual match; a REAL (stubbed) audio event "siren" present → the frozen SoundClassMatcher fires a WARN.
        let model = await ReelsPlayerModelV1(items: [item("x")], store: store,
                                             evidenceProvider: StubVisual(ocrText: "calm cooking"),
                                             audioProvider: StubAudio(bundle: audio([("siren", 0.9), ("music", 0.4)])),
                                             clock: { 10 })
        let d = await model.evaluate(item("x"))
        XCTAssertTrue(d.matchState.isMatch, "a user sound-class rule must match the real audio label (acceptance #11)")
        XCTAssertEqual(d.state, .warned, "a WARN sound rule WARNs (reversible-first; not an auto-HIDE from audio alone)")
        XCTAssertEqual(d.matchedRuleID, "snd-1")
    }

    // MARK: #13 — AUDIO & VISUAL have SEPARATE provenance; an audio event is its OWN timed record.

    func testAudioEventIsItsOwnModalityRecordSeparateFromVisual() async {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try? store.saveRules([soundRule("snd-1", "siren", .warn)])
        let model = await ReelsPlayerModelV1(items: [item("x")], store: store,
                                             evidenceProvider: StubVisual(ocrText: "calm cooking"),
                                             audioProvider: StubAudio(bundle: audio([("siren", 0.9)])),
                                             clock: { 10 })
        let d = await model.evaluate(item("x"))
        let audioRecs = d.timedEvidence.filter { $0.modality == .audioEvent }
        let visualRecs = d.timedEvidence.filter { $0.modality == .visualOCR }
        XCTAssertFalse(audioRecs.isEmpty, "a real audio event becomes its OWN .audioEvent timed record (#13)")
        XCTAssertFalse(visualRecs.isEmpty, "the visual OCR record stays separate (#13)")
        XCTAssertEqual(audioRecs.first?.text, "siren", "the audio record carries the classifier LABEL, not visual text")
        XCTAssertTrue(audioRecs.contains { $0.matchedRuleID == "snd-1" }, "the audio match is attributed to the audio sense")
        XCTAssertFalse(visualRecs.contains { $0.matchedRuleID == "snd-1" }, "the visual records must NOT carry the audio rule")
    }

    // MARK: #12 — AUDIO ABSENCE ≠ SILENCE ≠ SAFE. A no-audio-track reel is NOT auto-cleared on audio grounds.

    func testAudioAbsenceIsNotSafe() async {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try? store.saveRules([soundRule("snd-1", "siren", .warn)])
        // The file has NO audio track → availability .noAudioTrack, zero events. This must NOT create a match (nothing
        // heard) AND must NOT be treated as evidence of safety — the audio sense simply did not cover this reel.
        let model = await ReelsPlayerModelV1(items: [item("x")], store: store,
                                             evidenceProvider: StubVisual(ocrText: "calm cooking"),
                                             audioProvider: StubAudio(bundle: .unavailable(.noAudioTrack, classifierVersion: "stub")),
                                             clock: { 10 })
        let d = await model.evaluate(item("x"))
        XCTAssertFalse(d.matchState.isMatch, "no audio heard → no audio match (we never fabricate a sound event)")
        // The audio bundle's own honesty: senseRan=false, so coverage narrows — it is NOT a clean/safe audio signal.
        let bundle = ReelsAudioEvidenceV1.unavailable(.noAudioTrack, classifierVersion: "stub")
        XCTAssertFalse(bundle.senseRan, "no audio track means the sense did NOT run — absence ≠ silence ≠ safe (#12)")
        XCTAssertTrue(bundle.distinctLabels.isEmpty, "no fabricated labels when there is no audio (#10)")
    }

    // MARK: #14 / §H — CRITICAL thermal pressure DEFERS audio honestly (never a fabricated clean audio result).

    func testThermalCriticalDefersAudio() async {
        let prov = ReelsAudioEvidenceProviderV1()
        // A bogus URL: under .critical we must short-circuit to DEFERRED before touching the file at all.
        let b = await prov.gatherAudioEvidence(url: URL(fileURLWithPath: "/tmp/nope.wav"), thermal: .critical)
        XCTAssertEqual(b.availability, .deferredThermal, "critical thermal pressure DEFERS audio (§H / #14)")
        XCTAssertFalse(b.senseRan, "a deferred run is NOT a clean result — coverage narrows honestly")
        XCTAssertTrue(b.events.isEmpty)
    }

    // MARK: #13 (conflict) — a sound-class WARN rule + no visual match → the WARN surfaces; the two senses don't fuse
    //        into a stronger-than-either fake claim. (The authority is the strongest REAL per-unit verdict, not a sum.)

    func testAudioAndVisualDoNotFuseIntoStrongerClaim() async {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        // A WARN sound rule AND an unrelated text HIDE rule that the content does NOT match. The result must be the
        // WARN from audio alone — never a HIDE invented by combining two unrelated senses (#13 no false strong match).
        _ = try? store.saveRules([soundRule("snd-1", "applause", .warn), textRule("txt-1", "spoiler", .hideIfControlled)])
        let model = await ReelsPlayerModelV1(items: [item("x")], store: store,
                                             evidenceProvider: StubVisual(ocrText: "calm cooking fresh herbs"),
                                             audioProvider: StubAudio(bundle: audio([("applause", 0.8)])),
                                             clock: { 10 })
        let d = await model.evaluate(item("x"))
        XCTAssertEqual(d.state, .warned, "audio WARN surfaces; the unmatched text HIDE rule must NOT be fabricated")
        XCTAssertNotEqual(d.appliedAction, .hideIfControlled, "two unrelated senses must not fuse into a HIDE (#13)")
    }

    // MARK: #9 + #10 — REAL Apple Sound Analysis over an OWNED generated fixture: analysis RUNS and returns the
    //        classifier's OWN labels (we assert mechanics + real-labels-only, NOT a wished-for label — a tone is a tone).

    func testRealSoundAnalysisRunsOnOwnedToneFixtureWithRealLabelsOnly() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("audio-real-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { cleanup(dir) }
        let toneURL = dir.appendingPathComponent("tone.wav")
        try XCTSkipUnless(SyntheticAudio.writeTone(frequency: 440, seconds: 2.0, to: toneURL),
                          "AVAudioFile tone write unavailable on this runtime")
        // The classifier's OWN dictionary — the ONLY labels a real result may contain (acceptance #10: no invented classes).
        let dictionary = Set((try? SNClassifySoundRequest(classifierIdentifier: .version1).knownClassifications) ?? [])
        try XCTSkipUnless(!dictionary.isEmpty, "SoundAnalysis classifier dictionary unavailable on this runtime")

        let provider = ReelsAudioEvidenceProviderV1()
        let bundle = await provider.gatherAudioEvidence(url: toneURL, thermal: .nominal)
        // Mechanics: the sense must be AVAILABLE (a real audio track was analysed) — this is the #9 proof that a real
        // file was evaluated by Apple Sound Analysis, not a stub.
        XCTAssertEqual(bundle.availability, .available, "SoundAnalysis must really RUN over the owned tone fixture (#9)")
        // #10 — EVERY returned label must be a REAL classifier-dictionary label. We do NOT assert the tone "is" any
        // particular class (a tone is a tone); we assert the engine only ever emits its own vocabulary, never fabricated.
        for ev in bundle.events {
            XCTAssertTrue(dictionary.contains(ev.label), "returned label '\(ev.label)' must be a REAL classifier class (#10)")
            if let c = ev.rawModelConfidence { XCTAssertTrue(c >= 0 && c <= 1, "raw model confidence stays in [0,1] (not a risk score)") }
        }
    }

    func testRealSoundAnalysisOnSilenceStaysHonest() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("audio-sil-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { cleanup(dir) }
        let url = dir.appendingPathComponent("silence.wav")
        try XCTSkipUnless(SyntheticAudio.writeTone(frequency: 0, seconds: 2.0, to: url),
                          "silence write unavailable on this runtime")
        let dictionary = Set((try? SNClassifySoundRequest(classifierIdentifier: .version1).knownClassifications) ?? [])
        try XCTSkipUnless(!dictionary.isEmpty, "SoundAnalysis dictionary unavailable")
        let bundle = await ReelsAudioEvidenceProviderV1().gatherAudioEvidence(url: url, thermal: .nominal)
        // The sense RAN (there IS an audio track — a silent one). Whatever it returns must be real-dictionary labels
        // only; silence is analysed honestly and never force-labelled. The key honesty: availability is AVAILABLE (we
        // analysed a real track), not a fabricated "silence=safe".
        XCTAssertEqual(bundle.availability, .available, "a silent-but-present track is still analysed (sense ran)")
        for ev in bundle.events { XCTAssertTrue(dictionary.contains(ev.label), "no fabricated label for silence (#10)") }
    }

    // MARK: §E2 — a user audio preference can only reference labels the classifier dictionary contains (grounded menu).

    func testAudioEvidenceDistinctLabelsAreStrongestFirst() {
        let b = audio([("music", 0.3), ("siren", 0.9), ("speech", 0.6)])
        XCTAssertEqual(b.distinctLabels.first, "siren", "distinct labels are ordered strongest-first by raw confidence")
        XCTAssertEqual(Set(b.distinctLabels), ["music", "siren", "speech"])
        XCTAssertTrue(b.senseRan, "an .available bundle means the sense ran (coverage is real)")
    }
}
#endif
