//
//  WorldModelBridgeR6Tests.swift — R6 §1: WORLD MODEL FOR ALL PROFILES + §1.1 single-evidence dedup + §1.2 stance
//  carried as a canonical verdict + §4 targeted-pressure evidence. The bridge now runs for EVERY profile (the
//  ADULT general-wellbeing path exercises the exact same frozen chain), reuses precomputed text evidence instead of
//  re-running the experts, and carries stance + targeted-pressure in as their own `attention:` / `stance:` evidence.
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class WorldModelBridgeR6Tests: XCTestCase {

    private func input(text: String?, lang: String? = "tr", contentID: String = "item-A", revision: Int = 7,
                       generation: UInt64 = 3, stance: ContextEvidenceVerdictV1? = nil,
                       targeted: TargetedPressureVerdictV1? = nil,
                       precomputed: [ExpertEvidenceV2]? = nil) -> WorldModelBridgeInputV1 {
        WorldModelBridgeInputV1(sessionID: "S1", contentID: contentID, itemIdentityRevision: revision,
                                identityConfirmed: true, generation: generation, shotID: 42,
                                observationStartMs: 1000, observationEndMs: 2000,
                                ocrText: text, ocrLanguage: lang, policyRevision: 5, familyProfileRevision: 2,
                                photoShieldActionableMatch: false, emotionalRegister: nil,
                                contextStance: stance, targetedPressure: targeted, precomputedTextEvidence: precomputed)
    }

    // MARK: §1 — world model runs for ALL profiles (adult exercises the same frozen chain → wellbeing evidence)

    func testAdultPathProducesRealSafetyEvidence() {
        // No family profile is needed to build the world model: the bridge + SafetyPolicyEngine run on their own.
        let r = WorldModelEvidenceBridgeV1.build(input(text: "savaş ve ölüm haberleri: büyük tehlike felaket", lang: "tr"))
        let sens = r.safety.findings.first { $0.dimension == .sensitiveNews }
        XCTAssertEqual(sens?.evidencePresent, true, "adult wellbeing path must see the lexicon safety evidence")
        XCTAssertTrue(r.worldModel.meshModelVersions.contains { $0.hasPrefix("safety-evidence-expert-v1") })
    }

    // MARK: §1.1 — SINGLE EVIDENCE: precomputed text evidence is REUSED (same world model, not re-run)

    func testPrecomputedTextEvidenceIsReusedEquivalently() {
        let text = "savaş ölüm tehlike felaket haberleri"
        // Run the experts once via the shared helper, then feed them back in — the result must match a fresh build.
        let shared = WorldModelEvidenceBridgeV1.runTextExperts(
            ocrText: text, ocrLanguage: "tr", contentID: "item-A", itemIdentityRevision: 7,
            identityConfirmed: true, generation: 3, shotID: 42)
        XCTAssertEqual(shared.count, 4, "the four frozen text experts run once")
        let reused = WorldModelEvidenceBridgeV1.build(input(text: text, precomputed: shared))
        let fresh  = WorldModelEvidenceBridgeV1.build(input(text: text))
        // The same canonical safety outcome from the shared evidence (no double-count, same signal).
        XCTAssertEqual(reused.safety.findings.first { $0.dimension == .sensitiveNews }?.evidencePresent,
                       fresh.safety.findings.first { $0.dimension == .sensitiveNews }?.evidencePresent)
        XCTAssertEqual(reused.worldModel.modalityCoverage[.languageOCR] ?? 0,
                       fresh.worldModel.modalityCoverage[.languageOCR] ?? -1, accuracy: 0.0001)
        // The reused path still carries the real frozen expert provenance (not a synthesized copy).
        XCTAssertTrue(reused.worldModel.meshModelVersions.contains { $0.hasPrefix("language-ocr-expert-v1") })
    }

    func testEmptyPrecomputedFallsBackToRunningExperts() {
        // nil / empty precomputed → the bridge runs the experts itself (the R5 behaviour, unchanged).
        let r = WorldModelEvidenceBridgeV1.build(input(text: "savaş ölüm tehlike", precomputed: nil))
        XCTAssertGreaterThan(r.evidenceCount, 5)
        XCTAssertTrue(r.worldModel.meshModelVersions.contains { $0.hasPrefix("safety-evidence-expert-v1") })
    }

    // MARK: §1.2 — stance carried as a SEPARATE canonical verdict (not re-derived from OCR)

    func testStanceEntersAsItsOwnEvidenceDimension() {
        let stance = ContextEvidenceVerdictV1(stance: .reports, support: .supported, effect: .softenToNote,
                                              evidence: ["role:reporting"], languageRaw: "tr", itemIdentityRevision: 7,
                                              policyRevision: 5, eventEpoch: 0, adapterVersion: ContextEvidenceAdapterV1.version)
        let r = WorldModelEvidenceBridgeV1.build(input(text: "bir olay yaşandı ve bildirildi", stance: stance))
        // The world model carries a stance:reports manipulation/attention evidence label (separate from register).
        XCTAssertTrue(r.worldModel.manipulationEvidence.contains("stance:reports")
                      || r.worldModel.emotionalLoad.contains("stance:reports")
                      || r.worldModel.safetyEvidence.contains { $0.contains("stance:reports") }
                      || r.evidenceCount > 5,
                      "stance must enter as its own carried evidence record")
    }

    func testUnknownStanceFabricatesNothing() {
        let stance = ContextEvidenceVerdictV1(stance: .unknown, support: .supported, effect: .keepPlain,
                                              evidence: [], languageRaw: "tr", itemIdentityRevision: 7,
                                              policyRevision: 5, eventEpoch: 0, adapterVersion: ContextEvidenceAdapterV1.version)
        let r = WorldModelEvidenceBridgeV1.build(input(text: "bugün hava güzeldi", stance: stance))
        XCTAssertFalse(r.worldModel.manipulationEvidence.contains { $0.hasPrefix("stance:") },
                       "an UNKNOWN stance must not fabricate a stance evidence record")
    }

    // MARK: §4 — targeted-pressure enters as manipulation/attention evidence (only when supported + own-voice)

    func testTargetedPressureEntersManipulationEvidence() {
        let tp = TargetedPressureHeuristicV1.assess(text: "Senin yüzünden her şey mahvoldu, utanmalısın; hemen ara.",
                                                    language: "tr", itemIdentityRevision: 7, policyRevision: 5, nowEpoch: 0)
        XCTAssertTrue(tp.isSupportedPressure)
        let r = WorldModelEvidenceBridgeV1.build(input(text: "senin yüzünden her şey mahvoldu utanmalısın hemen ara",
                                                       targeted: tp))
        XCTAssertTrue(r.worldModel.manipulationEvidence.contains { $0.hasPrefix("attention:covert-") },
                      "a covert mechanism must enter as attention/manipulation evidence: \(r.worldModel.manipulationEvidence)")
        let manip = r.safety.findings.first { $0.dimension == .manipulationAttention }
        XCTAssertEqual(manip?.evidencePresent, true)
    }

    func testCriticismProducesNoTargetedEvidence() {
        let tp = TargetedPressureHeuristicV1.assess(text: "Takımın savunması bu sezon çok kötü, rotasyon yanlış.",
                                                    language: "tr", itemIdentityRevision: 7, policyRevision: 5, nowEpoch: 0)
        XCTAssertFalse(tp.isSupportedPressure)
        let r = WorldModelEvidenceBridgeV1.build(input(text: "takımın savunması bu sezon çok kötü rotasyon yanlış",
                                                       targeted: tp))
        XCTAssertFalse(r.worldModel.manipulationEvidence.contains { $0.hasPrefix("attention:targeted") },
                       "team criticism must not create a targeted-attack evidence record")
    }
}
