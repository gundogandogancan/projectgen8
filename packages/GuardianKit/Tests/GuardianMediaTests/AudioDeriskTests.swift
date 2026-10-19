import XCTest
import GuardianCore
@testable import GuardianMedia
#if canImport(SoundAnalysis) && canImport(AVFoundation)

final class AudioDeriskTests: XCTestCase {
    func testSoundAnalysisRunsOnGeneratedAudio() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gen8-tone.wav")
        try XCTSkipUnless(SyntheticAudio.writeTone(frequency: 440, seconds: 2.0, to: url), "audio write unavailable")
        defer { try? FileManager.default.removeItem(at: url) }
        let sig = GeneralAudioHeadV1().classify(url: url)
        // Real Apple Sound Analysis must run and either return classes or honest UNKNOWN (never fabricate).
        XCTAssertTrue(sig.availability == .available || sig.availability == .unknown)
        XCTAssertEqual(sig.provenance, .coreML)
        if sig.availability == .available { XCTAssertFalse((sig.value ?? []).isEmpty) }
    }
}
#endif
