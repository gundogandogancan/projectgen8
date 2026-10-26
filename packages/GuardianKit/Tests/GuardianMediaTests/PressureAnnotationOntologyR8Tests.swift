//
//  PressureAnnotationOntologyR8Tests.swift — R8 §6.B: the annotation ontology is a versioned, Codable, pure DATA
//  schema (corpus readiness) — it produces NO verdict/score and maps every R7 failure family to a label.
//
import XCTest
@testable import GuardianMedia

final class PressureAnnotationOntologyR8Tests: XCTestCase {

    func testRecordRoundTripsThroughJSONWithSchemaVersion() throws {
        let rec = PressureAnnotationRecordV1(
            itemID: "item-1", annotatorID: "A", mechanism: .deceptiveUrgency, target: .secondPersonViewer,
            intent: .coerce, stance: .advocates, emotionalPressure: .strong, quotedNotOwnVoice: false,
            legitimateEmergency: false, ambiguous: false, language: .mixedTrEn, notes: "fake scarcity")
        let data = try JSONEncoder().encode(rec)
        let back = try JSONDecoder().decode(PressureAnnotationRecordV1.self, from: data)
        XCTAssertEqual(back, rec)
        XCTAssertEqual(back.schemaVersion_, PressureAnnotationRecordV1.schemaVersion)
    }

    func testEveryR7FailureFamilyHasAMechanismLabel() {
        // The R7 FN families (fake-urgency, guilt-coercion, multi-speaker, mixed-directed, incitement, implicit-target)
        // must each map to a concrete annotation mechanism — proving the schema is ready for the data that was missed.
        let families = ["fake-urgency", "guilt-coercion", "multi-speaker", "mixed-directed", "incitement", "implicit-target"]
        for f in families {
            XCTAssertNotNil(PressureAnnotationOntologyV1.r7FailureFamilyToMechanism[f], "no label for R7 family \(f)")
        }
        XCTAssertEqual(PressureAnnotationOntologyV1.r7FailureFamilyToMechanism["fake-urgency"], .deceptiveUrgency)
        XCTAssertEqual(PressureAnnotationOntologyV1.r7FailureFamilyToMechanism["guilt-coercion"], .conditionalGuilt)
    }

    func testAmbiguousAndLegitimateEmergencyAreFirstClass() {
        // The schema MUST let an annotator say "ambiguous" and "legitimate emergency" (so a real warning is never
        // mislabelled as deceptive urgency and genuine uncertainty is captured, not forced).
        XCTAssertTrue(PressureMechanismV1.allCases.contains(.ambiguous))
        XCTAssertTrue(PressureMechanismV1.allCases.contains(.legitimateEmergency))
        XCTAssertTrue(PressureMechanismV1.allCases.contains(.none))
    }

    func testInterAnnotatorAgreementIsTracked() {
        let r1 = PressureAnnotationRecordV1(itemID: "i", annotatorID: "A", mechanism: .conditionalGuilt,
                                            target: .secondPersonViewer, intent: .coerce, stance: .advocates,
                                            emotionalPressure: .moderate, quotedNotOwnVoice: false,
                                            legitimateEmergency: false, ambiguous: false, language: .turkish)
        let r2 = PressureAnnotationRecordV1(itemID: "i", annotatorID: "B", mechanism: .conditionalGuilt,
                                            target: .secondPersonViewer, intent: .coerce, stance: .advocates,
                                            emotionalPressure: .strong, quotedNotOwnVoice: false,
                                            legitimateEmergency: false, ambiguous: false, language: .turkish)
        let r3 = PressureAnnotationRecordV1(itemID: "i", annotatorID: "C", mechanism: .deceptiveUrgency,
                                            target: .secondPersonViewer, intent: .persuade, stance: .neutral,
                                            emotionalPressure: .mild, quotedNotOwnVoice: false,
                                            legitimateEmergency: false, ambiguous: false, language: .turkish)
        let agree = PressureAnnotationAgreementV1(itemID: "i", records: [r1, r2, r3])
        XCTAssertTrue(agree.annotatorsDisagree)                    // A/B vs C — disagreement is RECORDED
        XCTAssertTrue(agree.hasMajorityMechanism)                  // 2 of 3 agree on conditionalGuilt
        XCTAssertEqual(agree.majorityMechanism, .conditionalGuilt)
    }

    func testFullSplitHasNoMajority() {
        let r1 = PressureAnnotationRecordV1(itemID: "i", annotatorID: "A", mechanism: .conditionalGuilt,
                                            target: .none, intent: .ambiguous, stance: .ambiguous,
                                            emotionalPressure: .ambiguous, quotedNotOwnVoice: false,
                                            legitimateEmergency: false, ambiguous: true, language: .unknown)
        let r2 = PressureAnnotationRecordV1(itemID: "i", annotatorID: "B", mechanism: .satireIrony,
                                            target: .none, intent: .entertain, stance: .neutral,
                                            emotionalPressure: .none, quotedNotOwnVoice: false,
                                            legitimateEmergency: false, ambiguous: false, language: .english)
        let agree = PressureAnnotationAgreementV1(itemID: "i", records: [r1, r2])
        XCTAssertNil(agree.majorityMechanism)   // a full split is unresolved — never silently picked
    }

    func testOnDeviceModelCandidateProbeReportsHonestly() {
        // Prints the REAL canImport facts for the root-cause doc (never fabricated). NaturalLanguage is present in this
        // repo; FoundationModels is reported ONLY if the installed SDK exposes it; CoreML is importable but corpus-blocked.
        print("MODEL_CANDIDATE_PROBE naturalLanguage=\(PressureAnnotationOntologyV1.naturalLanguageAvailable) foundationModels=\(PressureAnnotationOntologyV1.foundationModelsAvailable) coreML=\(PressureAnnotationOntologyV1.coreMLAvailable)")
        XCTAssertTrue(PressureAnnotationOntologyV1.naturalLanguageAvailable, "NaturalLanguage is used across the repo and must be present")
    }

    func testExampleSchemaJSONIsValid() throws {
        let json = PressureAnnotationOntologyV1.exampleRecordJSON()
        XCTAssertNotNil(json)
        let data = json!.data(using: .utf8)!
        XCTAssertNoThrow(try JSONDecoder().decode(PressureAnnotationRecordV1.self, from: data))
    }
}
