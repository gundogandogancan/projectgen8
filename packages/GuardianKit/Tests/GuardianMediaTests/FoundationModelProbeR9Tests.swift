//
//  FoundationModelProbeR9Tests.swift — R9 §6/§6.1 (P1-6): FOUNDATION MODELS CAPABILITY PROBE + the conditional-guilt
//  structured-output CONTRACT + its unsupported-field VALIDATOR. The mechanism is the deliverable; inference on host
//  is reported honestly (not asserted). These tests pin the guardrails, not a model label.
//
import XCTest
import GuardianCore
@testable import GuardianMedia

final class FoundationModelProbeR9Tests: XCTestCase {

    // MARK: - §6 the honest capability report — every rung is a provable fact or UNKNOWN (never a fabricated YES)

    func testCapabilityReportNeverFabricatesInference() {
        let report = ConditionalPressureModelProbeV1.capabilityReport()
        // Inference-succeeds is the ONLY rung that proves a real session ran. The STATIC capability report never runs
        // a session, so it must NOT claim inference succeeded (it stays UNKNOWN until tryStructuredProbe genuinely runs).
        XCTAssertNotEqual(report.rungs[.inferenceSucceeds], .yes,
                          "the capability report must never claim inference succeeded without a real session")
        // The SDK rung is a compile-time fact and must be decisively YES or NO, never UNKNOWN.
        XCTAssertNotEqual(report.rungs[.sdkFrameworkAvailable], .unknown)
        XCTAssertFalse(report.inferenceProvenOnHost)
        XCTAssertFalse(report.summary.isEmpty)
    }

    func testEveryRungHasAStatus() {
        let report = ConditionalPressureModelProbeV1.capabilityReport()
        for rung in FoundationModelCapabilityRungV1.allCases {
            XCTAssertNotNil(report.rungs[rung], "rung \(rung.rawValue) must have an honest status")
        }
    }

    // MARK: - §6.1 the VALIDATOR guardrail — the model may NOT invent fields the input text does not support

    func testValidatorRejectsFabricatedTarget() {
        // Input has NO named person. A candidate that claims target "Ahmet" must be REJECTED (nulled + listed).
        let candidate = ConditionalPressureStructuredOutputV1(
            speaker: nil, target: "Ahmet", conditionalStructure: "if you cared",
            requestedAction: nil, mechanism: .conditionalGuilt, counterEvidence: [],
            uncertainty: .moderate, evidenceSpan: "if you cared")
        let cleaned = ConditionalPressureModelProbeV1.rejectUnsupportedFields(
            candidate: candidate, inputText: "if you cared you would do this for me")
        XCTAssertNil(cleaned.target, "a target absent from the input must be rejected")
        XCTAssertTrue(cleaned.rejectedUnsupportedFields.contains("target"))
        // The conditional + mechanism ARE supported by the input, so they survive.
        XCTAssertNotNil(cleaned.conditionalStructure)
        XCTAssertEqual(cleaned.mechanism, .conditionalGuilt)
    }

    func testValidatorDropsMechanismWhenEvidenceSpanIsUnsupported() {
        // The evidence span the mechanism rests on is NOT in the input → both are rejected (no unsupported mechanism).
        let candidate = ConditionalPressureStructuredOutputV1(
            speaker: nil, target: nil, conditionalStructure: nil, requestedAction: nil,
            mechanism: .deceptiveUrgency, counterEvidence: [], uncertainty: .strong,
            evidenceSpan: "act now before midnight deadline")
        let cleaned = ConditionalPressureModelProbeV1.rejectUnsupportedFields(
            candidate: candidate, inputText: "hava bugün çok güzel, yürüyüş yaptık")
        XCTAssertNil(cleaned.evidenceSpan)
        XCTAssertNil(cleaned.mechanism, "a mechanism whose evidence span is unsupported must be rejected")
        XCTAssertTrue(cleaned.rejectedUnsupportedFields.contains("mechanism"))
    }

    func testValidatorKeepsSupportedFields() {
        let candidate = ConditionalPressureStructuredOutputV1(
            speaker: nil, target: nil, conditionalStructure: "eğer beni sevseydin",
            requestedAction: "yapardın", mechanism: .conditionalGuilt, counterEvidence: [],
            uncertainty: .moderate, evidenceSpan: "eğer beni gerçekten sevseydin bunu yapardın")
        let cleaned = ConditionalPressureModelProbeV1.rejectUnsupportedFields(
            candidate: candidate, inputText: "Eğer beni gerçekten sevseydin bunu benim için yapardın.")
        XCTAssertNotNil(cleaned.conditionalStructure)
        XCTAssertNotNil(cleaned.evidenceSpan)
        XCTAssertEqual(cleaned.mechanism, .conditionalGuilt)
        XCTAssertTrue(cleaned.rejectedUnsupportedFields.isEmpty, "fully-supported fields are never rejected")
    }

    func testAbstainOutputCarriesNoMechanism() {
        let a = ConditionalPressureStructuredOutputV1.abstain(counterEvidence: ["supportive: unconditional"])
        XCTAssertNil(a.mechanism); XCTAssertNil(a.conditionalStructure); XCTAssertEqual(a.uncertainty, .none)
    }

    // MARK: - §6.1 inference is reported honestly, never faked

    func testStructuredProbeIsHonest_NilWhenUnavailable_GroundedWhenItRuns() async {
        // R10: the probe now contains the REAL FoundationModels call-path. Its honesty contract: it returns a result
        // ONLY when inference GENUINELY RAN on host; nil otherwise (never a fabricated structure). On an ELIGIBLE host
        // (as observed on the macOS build host) it genuinely runs and returns a GROUNDED structure; on an ineligible
        // host it returns nil. We assert the contract both ways via the richer `runStructuredInference`.
        let input = "Eğer beni gerçekten sevseydin bunu yapardın."
        let full = await ConditionalPressureModelProbeV1.runStructuredInference(inputText: input)
        let out = await ConditionalPressureModelProbeV1.tryStructuredProbe(inputText: input)
        if full.inferenceRan {
            // Inference ran → tryStructuredProbe surfaces the validated output; every surviving span is verbatim.
            XCTAssertNotNil(out, "a genuinely-run inference returns its validated structure")
            if let span = out?.evidenceSpan {
                let folded = ConditionalPressureModelProbeV1.foldForMatch(input)
                XCTAssertTrue(folded.contains(ConditionalPressureModelProbeV1.foldForMatch(span)),
                              "a surviving evidence span is always verbatim in the input (validator guardrail)")
            }
        } else {
            // Inference did NOT run → nil, never a fabricated structure (the honest unavailable contract).
            XCTAssertNil(out, "no on-host inference → nil, never a fabricated result (\(full.unavailableReason ?? "-"))")
        }
    }

    // MARK: - §7 the fresh eval probes are TR+EN with anti-false-positive controls (not the R7 regression set)

    func testFreshEvalProbesIncludeCoercionAndSupportiveControls() {
        let probes = ConditionalPressureModelProbeV1.freshEvalProbes
        XCTAssertTrue(probes.contains { $0.expectCoercion }, "has real conditional-guilt cases")
        XCTAssertTrue(probes.contains { !$0.expectCoercion }, "has supportive/normal controls (must NOT flag)")
        XCTAssertTrue(probes.contains { $0.language == .turkish } && probes.contains { $0.language == .english },
                      "TR + EN coverage")
    }
}
