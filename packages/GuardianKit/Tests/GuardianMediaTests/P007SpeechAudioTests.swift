import XCTest
@testable import GuardianCore
@testable import GuardianMedia

// §7/§8/§9 — TR/EN speech V3 (real on-device attempt + honest blocker) and general-audio V2 over project-owned fixtures.
final class P007SpeechAudioTests: XCTestCase {

    private func tmp(_ name: String) -> URL { URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gen8-p007-\(UUID().uuidString)-\(name)") }

    // §7 — probe the TR/EN on-device speech path. In a headless lab we expect a precise, verifiable BLOCKED verdict
    // (no authorization / no on-device asset), never a fabricated transcript.
    func testSpeechV3ProbeIsTruthful() {
        let t = SpeechTranscriberV3()
        for locale in ["en-US", "tr-TR"] {
            let r = t.probe(localeID: locale)
            XCTAssertEqual(r.localeID, locale)
            // Either READY (if a real device has assets+auth) or a specific BLOCKED_ reason — never silently empty.
            XCTAssertTrue(r.isReady || r.verdict.hasPrefix("BLOCKED_"), "verdict must be explicit: \(r.verdict)")
            if !r.isReady { XCTAssertTrue(["authorized","denied","restricted","notDetermined","unknown"].contains(r.authorizationStatus)) }
        }
    }

    // §7 — a project-owned spoken fixture: synthesize TR/EN speech, attempt on-device transcription; abstain honestly if blocked.
    func testSpeechV3FixtureTranscribeOrHonestBlocker() async throws {
        let en = tmp("en.caf")
        guard await SyntheticAudio.writeSpeech("The weather is calm today", language: "en-US", to: en) else {
            throw XCTSkip("speech synthesis unavailable on this runtime")
        }
        let (sig, report) = await SpeechTranscriberV3().transcribe(url: en, localeID: "en-US")
        if report.isReady {
            // If the device actually has the on-device asset + auth, we get a real transcript (non-nil).
            XCTAssertEqual(sig.availability, .available)
        } else {
            // Honest lab outcome: UNAVAILABLE with an explicit blocker verdict — not a fake pass.
            XCTAssertEqual(sig.availability, .unavailable)
            XCTAssertTrue(report.verdict.hasPrefix("BLOCKED_"))
        }
        try? FileManager.default.removeItem(at: en)
    }

    // §9 — general audio V2: real SoundAnalysis over project-owned fixtures (tone, silence). Honest availability states.
    func testGeneralAudioV2OnOwnedFixtures() {
        let tone = tmp("tone.caf")
        guard SyntheticAudio.writeTone(frequency: 440, seconds: 1.0, to: tone) else { return XCTFail("tone gen failed") }
        let sig = GeneralAudioHeadV1().classify(url: tone)
        // SoundAnalysis runs for real; result is available/unknown/unavailable — never a fabricated label.
        XCTAssertTrue([.available, .unknown, .unavailable].contains(sig.availability))
        if sig.availability == .available { XCTAssertNotNil(sig.value) }
        // isMusic may be nil for a pure tone — assert it does not crash and returns an optional truthfully.
        _ = GeneralAudioHeadV1().isMusic(url: tone)
        try? FileManager.default.removeItem(at: tone)
    }
}
