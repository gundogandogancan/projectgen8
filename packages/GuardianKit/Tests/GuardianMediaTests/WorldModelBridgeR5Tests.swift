//
//  WorldModelBridgeR5Tests.swift — R5 §4 (P0-2) + §3 (P0-3): the derived-evidence bridge feeds the FROZEN canonical
//  path (WorldModelBuilderV1 → SafetyPolicyEngineV1 → ChildAgePolicyEngineV1) HONESTLY:
//   • absent modalities are UNAVAILABLE (audio is never "analyzed clean"; H1 visual gap stays visible),
//   • a child is NEVER auto-AGE_ALIGNED just because OCR found no risk word (evidence-coverage gap flows through),
//   • new item → fresh world model (no carryover),
//   • parent preferences are stricter-only on the live inputs,
//   • contradictions route through the canonical resolver (not dropped).
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class WorldModelBridgeR5Tests: XCTestCase {

    private func input(text: String?, lang: String? = "tr", contentID: String = "item-A",
                       revision: Int = 7, confirmed: Bool = true, generation: UInt64 = 3,
                       photoMatch: Bool = false,
                       register: EmotionalRegisterVerdictV1? = nil) -> WorldModelBridgeInputV1 {
        WorldModelBridgeInputV1(sessionID: "S1", contentID: contentID, itemIdentityRevision: revision,
                                identityConfirmed: confirmed, generation: generation, shotID: 42,
                                observationStartMs: 1000, observationEndMs: 2000,
                                ocrText: text, ocrLanguage: lang, policyRevision: 5, familyProfileRevision: 2,
                                photoShieldActionableMatch: photoMatch, emotionalRegister: register)
    }

    private func childProfile(age: Int, jurisdiction: String = "TR") -> GuardianEnteredChildProfileV1 {
        GuardianEnteredChildProfileV1(ageYears: age, jurisdictionCode: jurisdiction, enteredByGuardian: true)
    }

    // MARK: §4 — honest modality coverage

    func testNoTextYieldsHonestUnavailabilityNotClean() {
        let r = WorldModelEvidenceBridgeV1.build(input(text: nil))
        // Audio/speech/music/vision/symbol + the text-derived domains are all UNAVAILABLE — coverage 0, never "clean".
        XCTAssertEqual(r.worldModel.modalityCoverage[.audioEvent] ?? -1, 0)
        XCTAssertEqual(r.worldModel.modalityCoverage[.speech] ?? -1, 0)
        XCTAssertEqual(r.worldModel.modalityCoverage[.languageOCR] ?? -1, 0)
        XCTAssertTrue(r.unavailableModalities.contains(ExpertDomainV2.audioEvent.rawValue))
        XCTAssertTrue(r.unavailableModalities.contains(ExpertDomainV2.vision.rawValue))
        // The world model knows it knows nothing (never a positive knowledge claim from absence).
        XCTAssertTrue(r.worldModel.knowledgeState == .unavailable || r.worldModel.knowledgeState == .unknown,
                      "knowledgeState=\(r.worldModel.knowledgeState)")
        // Visual high-risk dimensions remain UNAVAILABLE in the safety result (H1 law).
        XCTAssertTrue(r.safety.unavailableDimensions.contains(.explicitSexual))
        XCTAssertTrue(r.safety.unavailableDimensions.contains(.violenceGore))
        XCTAssertFalse(r.safety.strongProtectionSupported)
        XCTAssertFalse(r.safety.cautionSupported)   // no evidence ≠ caution; it is UNKNOWN, not BAD
    }

    func testH1VisualGapAlwaysVisibleEvenWithBenignText() {
        let r = WorldModelEvidenceBridgeV1.build(input(text: "bugün parkta güzel bir yürüyüş yaptık", lang: "tr"))
        XCTAssertTrue(r.safety.unavailableDimensions.contains(.violenceGore))
        XCTAssertTrue(r.unavailableModalities.contains(ExpertDomainV2.vision.rawValue))
        XCTAssertEqual(r.worldModel.modalityCoverage[.audioEvent] ?? -1, 0, "soundEvents:[] must never read as analyzed")
    }

    // MARK: §3 — the REAL child chain (frozen engines, live-path evidence)

    func testChildWithNoEvidenceIsUnknownReviewNeverAligned() {
        let r = WorldModelEvidenceBridgeV1.build(input(text: nil))
        let d = ChildAgePolicyEngineV1.evaluate(profile: childProfile(age: 9), safety: r.safety,
                                                worldModel: r.worldModel)
        XCTAssertEqual(d.outcome, .unknownReview)
        XCTAssertTrue(d.jurisdictionSupported)
    }

    func testChildNeverAutoAlignedFromAbsenceOfRiskWords() {
        // Benign text, zero risk markers — the under-13 H1 fail-closed law + coverage gap must still block ALIGNED.
        let r = WorldModelEvidenceBridgeV1.build(input(text: "bugün parkta güzel bir yürüyüş yaptık hava çok güzeldi",
                                                       lang: "tr"))
        let d = ChildAgePolicyEngineV1.evaluate(profile: childProfile(age: 9), safety: r.safety,
                                                worldModel: r.worldModel)
        XCTAssertNotEqual(d.outcome, .aligned, "child must NEVER auto-align on mere absence of OCR risk words")
    }

    func testRiskyTextChildEscalatesAboveAligned() {
        let risky = "savaş ve ölüm haberleri: büyük tehlike, felaket görüntüleri yayıldı"
        let r = WorldModelEvidenceBridgeV1.build(input(text: risky, lang: "tr"))
        // The REAL frozen safety engine must see the lexicon evidence.
        let sens = r.safety.findings.first { $0.dimension == .sensitiveNews }
        XCTAssertEqual(sens?.evidencePresent, true, "sensitive-news evidence must flow through the bridge")
        let d = ChildAgePolicyEngineV1.evaluate(profile: childProfile(age: 9), safety: r.safety,
                                                worldModel: r.worldModel)
        XCTAssertTrue(d.outcome == .caution || d.outcome == .restricted || d.outcome == .unknownReview,
                      "child outcome must escalate, got \(d.outcome)")
        XCTAssertNotEqual(d.outcome, .aligned)
    }

    func testUnsupportedJurisdictionFailsClosed() {
        let r = WorldModelEvidenceBridgeV1.build(input(text: "hello world news", lang: "en"))
        let d = ChildAgePolicyEngineV1.evaluate(profile: childProfile(age: 9, jurisdiction: "XX"),
                                                safety: r.safety, worldModel: r.worldModel)
        XCTAssertEqual(d.outcome, .unknownReview)
        XCTAssertFalse(d.jurisdictionSupported)
    }

    func testParentPreferenceStricterOnlyOnLivePath() {
        // Age 14 (above the fearThreat caution band of 10) + fear lexeme: the BAND alone gives no caution, the
        // parent's stricter-only preference must add it — and the source class must say PARENT_PREFERENCE.
        let r = WorldModelEvidenceBridgeV1.build(input(text: "dikkat büyük tehlike var bölgede", lang: "tr"))
        let fear = r.safety.findings.first { $0.dimension == .fearThreat }
        XCTAssertEqual(fear?.evidencePresent, true)
        let pref = ParentPreferencePolicyV1(extraCautionDimensions: [.fearThreat])
        let with = ChildAgePolicyEngineV1.evaluate(profile: childProfile(age: 14), safety: r.safety,
                                                   worldModel: r.worldModel, parentPreference: pref)
        XCTAssertNotEqual(with.outcome, .aligned)
        XCTAssertEqual(with.sourceClass, .parentPreference)
    }

    // MARK: §4 — fresh world model per item (no carryover)

    func testNewItemGetsFreshWorldModelNoCarryover() {
        let a = WorldModelEvidenceBridgeV1.build(input(text: "savaş ölüm tehlike haberleri", lang: "tr",
                                                       contentID: "item-A", revision: 7, generation: 3))
        let b = WorldModelEvidenceBridgeV1.build(input(text: "bugün parkta yürüyüş yaptık", lang: "tr",
                                                       contentID: "item-B", revision: 8, generation: 4))
        XCTAssertNotEqual(a.worldModel.itemID, b.worldModel.itemID)
        XCTAssertTrue(a.worldModel.evidenceItemIDs.isDisjoint(with: b.worldModel.evidenceItemIDs))
        XCTAssertEqual(b.worldModel.maxRiskSeen, 0, accuracy: 0.0001,
                       "item A's risk must not leak into item B's fresh model")
        XCTAssertNotEqual(a.worldModel.identityRevision, b.worldModel.identityRevision)
    }

    // MARK: §4 — evidence provenance fields

    func testEvidenceCarriesRealProvenance() {
        let r = WorldModelEvidenceBridgeV1.build(input(text: "savaş ölüm tehlike haberleri", lang: "tr",
                                                       generation: 9))
        XCTAssertTrue(r.worldModel.meshModelVersions.contains { $0.hasPrefix("language-ocr-expert-v1") },
                      "the REAL frozen expert's model version must be on the model: \(r.worldModel.meshModelVersions)")
        XCTAssertTrue(r.worldModel.meshModelVersions.contains { $0.hasPrefix("safety-evidence-expert-v1") })
        XCTAssertEqual(r.worldModel.generation, 9)
        XCTAssertEqual(r.worldModel.evidenceGenerations, [9])
        XCTAssertEqual(r.worldModel.modalityCoverage[.languageOCR] ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(r.worldModel.identityStatus, "confirmed")
        XCTAssertGreaterThan(r.evidenceCount, 5)
    }

    func testProvisionalIdentityFlowsThroughHonestly() {
        let r = WorldModelEvidenceBridgeV1.build(input(text: "bugün parkta yürüyüş", lang: "tr", confirmed: false))
        XCTAssertEqual(r.worldModel.identityStatus, "provisional")
        // The frozen child engine fails closed on a provisional identity (it must never ALIGN).
        let d = ChildAgePolicyEngineV1.evaluate(profile: childProfile(age: 15), safety: r.safety,
                                                worldModel: r.worldModel)
        XCTAssertNotEqual(d.outcome, .aligned)
    }

    // MARK: §5 — the register enters as its own evidence (never dressed as a lexicon hit)

    func testPressureRegisterEntersManipulationEvidence() {
        let reg = EmotionalRegisterVerdictV1(register: .fearPressure, support: .supported,
                                             evidence: ["addressee:2nd-person"], languageRaw: "tr",
                                             itemIdentityRevision: 7, policyRevision: 5, eventEpoch: 0,
                                             adapterVersion: EmotionalRegisterAdapterV1.version)
        let r = WorldModelEvidenceBridgeV1.build(input(text: "sen büyük tehlike altındasın", lang: "tr",
                                                       register: reg))
        XCTAssertTrue(r.worldModel.manipulationEvidence.contains("attention:register-fear-pressure"),
                      "manipulationEvidence=\(r.worldModel.manipulationEvidence)")
        let manip = r.safety.findings.first { $0.dimension == .manipulationAttention }
        XCTAssertEqual(manip?.evidencePresent, true)
    }

    func testUnknownRegisterFabricatesNothing() {
        let reg = EmotionalRegisterVerdictV1(register: .unknown, support: .supported, evidence: [],
                                             languageRaw: "tr", itemIdentityRevision: 7, policyRevision: 5,
                                             eventEpoch: 0, adapterVersion: EmotionalRegisterAdapterV1.version)
        let r = WorldModelEvidenceBridgeV1.build(input(text: "bugün parkta yürüyüş yaptık", lang: "tr", register: reg))
        XCTAssertFalse(r.worldModel.manipulationEvidence.contains { $0.hasPrefix("attention:register") })
    }

    // MARK: §4 — contradictions routed through the canonical resolver (not dropped)

    func testRiskPlusBenefitRoutesThroughContradictionResolver() {
        // Risk evidence (war/mortality) AND benefit evidence (educational) in one observation → the FROZEN builder
        // must surface a contradiction resolution (never silently drop either side).
        let text = "savaş ve ölüm tarihi hakkında ders: bu dönemi öğren, tarih eğitimi"
        let r = WorldModelEvidenceBridgeV1.build(input(text: text, lang: "tr"))
        XCTAssertTrue(r.worldModel.benefitEvidence.contains("benefit:educational-candidate"),
                      "benefit=\(r.worldModel.benefitEvidence)")
        XCTAssertFalse(r.worldModel.safetyEvidence.filter { $0.hasPrefix("safety:sensitive") }.isEmpty)
        XCTAssertGreaterThanOrEqual(r.worldModel.contradictionResolutions.count, 1,
                                    "risk-vs-benefit must route through ContradictionResolverV1")
    }

    // MARK: §4 — performance envelope (per-item latency stays extension-safe; synthetic, not a device claim)

    func testBridgeLatencyBoundedSynthetic() {
        let text = "savaş ölüm tehlike felaket haberleri bugün çok kötü şeyler oldu herkes panik içinde"
        var samples: [Double] = []
        for i in 0..<50 {
            let r = WorldModelEvidenceBridgeV1.build(input(text: text, lang: "tr", revision: i, generation: UInt64(i)))
            samples.append(r.latencyMs)
        }
        let sorted = samples.sorted()
        let p95 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        // Generous synthetic bound (SYNTHETIC-TESTED, not device evidence): the per-item bridge must stay far from
        // any per-frame budget. 250ms would already be pathological for four lexicon scans + one observation build.
        XCTAssertLessThan(p95, 250, "bridge p95 \(p95)ms — per-item budget violated")
    }
}
