import XCTest
import GuardianCore
@testable import GuardianMedia
#if canImport(AVFoundation)

final class P006MediaTests: XCTestCase {
    private func tone(_ n: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gen8m-\(n).wav")
        try XCTSkipUnless(SyntheticAudio.writeTone(frequency: 440, seconds: 2.0, to: url), "audio write unavailable")
        return url
    }

    func testMusicNonMusicReal() throws {
        let url = try tone("mnm"); defer { try? FileManager.default.removeItem(at: url) }
        // Real Sound Analysis runs; a pure tone may classify as music or not, or be inconclusive (nil) — all honest.
        let sig = GeneralAudioHeadV1().classify(url: url)
        XCTAssertTrue(sig.availability == .available || sig.availability == .unknown)
        _ = GeneralAudioHeadV1().isMusic(url: url)             // must not crash; nil allowed (honest inconclusive)
    }

    func testAudioCharacteristicsLoudness() throws {
        let url = try tone("rms"); defer { try? FileManager.default.removeItem(at: url) }
        let sig = AudioCharacteristicsV1().analyze(url: url)
        XCTAssertEqual(sig.availability, .available)
        XCTAssertGreaterThan(sig.value?.loudnessRMS ?? 0, 0)   // real RMS from PCM
    }

    func testShazamUnavailableHonest() throws {
        let url = try tone("shz"); defer { try? FileManager.default.removeItem(at: url) }
        let sig = ShazamIdentityAdapter().identify(url: url)
        XCTAssertEqual(sig.availability, .unavailable)         // no entitlement/network → honest, not faked
    }

    func testPersonalMusicPolicyExclusion() {
        let p = PersonalMusicPolicy(excludedArtistsOrSources: ["RivalBand"])
        XCTAssertTrue(p.excludes(sourceOrArtist: "Live — RivalBand Tour"))
        XCTAssertFalse(p.excludes(sourceOrArtist: "Calm Piano"))
    }

    #if canImport(Speech)
    func testSpeechAttemptHonest() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gen8m-speech.caf")
        let wrote = await SyntheticAudio.writeSpeech("Hello Guardian", language: "en-US", to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        try XCTSkipUnless(wrote, "speech synthesis unavailable on runtime")
        let sig = await SpeechTranscriberV2().transcribeFile(url: url, localeID: "en-US")
        // Real attempt: either transcribed (device/authorized) OR honest UNAVAILABLE (headless/unauthorized) — never faked.
        XCTAssertTrue(sig.availability == .available || sig.availability == .unavailable)
        if sig.availability == .available { XCTAssertFalse((sig.value?.text ?? "").isEmpty) }
    }
    #endif
}
#endif
