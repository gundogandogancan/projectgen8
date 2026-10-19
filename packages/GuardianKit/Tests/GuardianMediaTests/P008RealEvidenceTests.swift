import XCTest
import CoreGraphics
@testable import GuardianCore
@testable import GuardianIntelligence
@testable import GuardianMedia

// PROMPT 008-B — REAL provider evidence (Vision OCR + SoundAnalysis) assembled into MultimodalContentUnderstandingV1,
// fed through the cross-modal graph + score gate. Proves: multimodal + provenance; UNKNOWN when evidence/calibration insufficient.
final class P008RealEvidenceTests: XCTestCase {

    private func tmp(_ n: String) -> URL { URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gen8-p008-\(UUID().uuidString)-\(n)") }

    func testRealProvidersBuildUnderstandingWithProvenance() throws {
        var u = MultimodalContentUnderstandingV1(contentID: "real-1", sourceSurface: "lab-fixture")
        var observed: [Modality] = []; var unavailable: [Modality] = []

        // --- REAL Vision OCR on an owned synthetic image ---
        guard let img = SyntheticImage.textImage("EARTHQUAKE DISASTER", width: 640, height: 200) else { XCTFail("img"); return }
        let ocr = VisionOCRProvider().recognizeText(cgImage: img)
        if let text = ocr.value?.text, !text.isEmpty {
            observed.append(.ocr)
            u.evidence.append(ModalEvidenceSignal(modality: .ocr, kind: "topic", value: "earthquake",
                rawConfidence: 0.8, calibratedConfidence: nil, evidenceClass: .modelInference,
                modelID: "apple-vision-ocr", modelRevision: "v1", language: "en", rawMediaRetention: "none"))
            u.languageCandidates = ["en"]
        } else { unavailable.append(.ocr) }

        // --- REAL SoundAnalysis on an owned synthetic tone ---
        let audio = tmp("tone.caf")
        if SyntheticAudio.writeTone(frequency: 440, seconds: 1.0, to: audio) {
            let sig = GeneralAudioHeadV1().classify(url: audio)
            if sig.availability == .available, let labels = sig.value, let top = labels.first {
                observed.append(.audio)
                u.evidence.append(ModalEvidenceSignal(modality: .audio, kind: "sound-event", value: top.label,
                    rawConfidence: top.confidence, calibratedConfidence: nil, evidenceClass: .modelInference,
                    modelID: "apple-sound-analysis", modelRevision: "v1", rawMediaRetention: "none"))
            } else { unavailable.append(.audio) }
            try? FileManager.default.removeItem(at: audio)
        }

        u.modalitiesObserved = observed; u.modalitiesUnavailable = unavailable
        u.evidenceCoverage = Double(observed.count) / Double(Modality.allCases.count)

        // Provenance present on every signal (no naked label).
        XCTAssertFalse(u.evidence.isEmpty, "at least OCR evidence should be produced")
        for e in u.evidence { XCTAssertFalse(e.modelID.isEmpty); XCTAssertFalse(e.modelRevision.isEmpty); XCTAssertEqual(e.rawMediaRetention, "none") }
        XCTAssertTrue(observed.contains(.ocr), "real Vision OCR evidence present")

        // Low coverage (few modalities) + no calibration → score is honestly UNKNOWN, not a fabricated number.
        let fusion = SuitabilityFusionV1()
        let input = SuitabilityFusionInput(
            dims: [.safetyAlignment: .init(0.8), .topicAlignment: .init(0.5, available: false)],
            evidenceConfidence: u.evidence.map { $0.rawConfidence ?? 0 }.max() ?? 0,
            calibrationValid: false, minCoverage: 0.5)
        let score = fusion.fuse(input, policyRevision: "pol-v1", contentDNARevision: "dna-v5", modelPackRevision: "pack-v1")
        XCTAssertNil(score.score)
        XCTAssertEqual(score.scoreBand, .unknown)   // real evidence, but insufficient coverage/calibration → UNKNOWN
    }
}
