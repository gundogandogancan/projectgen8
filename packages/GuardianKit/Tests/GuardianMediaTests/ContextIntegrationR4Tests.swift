//
//  ContextIntegrationR4Tests.swift — R4 §2A/§2B/§2C/§4: the P0 FIX regressions + the context-aware integration,
//  proven against the REAL pure types the broadcast extension calls. These lock the decision table the SampleHandler
//  surface mapping depends on, plus the static-revalidation + validity-IPC-fact semantics, so a device-less
//  regression is visible. (Full extension wiring is DEVICE_UNVERIFIED; the app build covers the live path.)
//
import XCTest
import GuardianCore
@testable import GuardianMedia

final class ContextIntegrationR4Tests: XCTestCase {

    // MARK: - §4 — the CONTEXT-AWARE general-character evaluation (evaluateWithContext)

    private func ctx(_ text: String, _ lang: String) -> GeneralContentCharacterVerdictV1 {
        GeneralContentCharacterV1.evaluateWithContext(ocrText: text, detectedLanguage: lang,
                                                      itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 1)
    }

    func testAdvocacyMarker_isContextCaution_keepOrRaise_stillCaution() {
        // A real mortality/violence marker + first-person advocacy stance → CONTEXT_ASSESSED, KEEP_OR_RAISE, still a
        // caution (the risk is NEVER softened away). This is the §4 "ADVOCATES keeps/raises caution" law.
        let v = ctx("Hepsini gebertin, hak ettiler! Ölüm onlara! Yaşasın savaş!", "tr")
        XCTAssertEqual(v.outcome, .contextAssessed)
        XCTAssertEqual(v.contextStance, .advocates)
        XCTAssertEqual(v.contextEffect, .keepOrRaise)
        XCTAssertTrue(v.isCaution)                 // a context-backed caution is STILL a caution
        XCTAssertFalse(v.isContextSoftened)
        XCTAssertFalse(v.markers.isEmpty)          // the marker is preserved verbatim (never dropped)
    }

    func testReportingMarker_isContextSoftened_markerPreserved() {
        // A mortality marker reported as NEWS → CONTEXT_ASSESSED, SOFTEN_TO_NOTE: examined WITH context. The marker is
        // STILL present (never dropped) but the surface is calmer — the first real false-alarm reduction.
        let v = ctx("Polis açıkladı: saldırıda iki kişi öldü, soruşturma başlatıldı.", "tr")
        XCTAssertEqual(v.outcome, .contextAssessed)
        XCTAssertEqual(v.contextStance, .reports)
        XCTAssertTrue(v.isContextSoftened)
        XCTAssertFalse(v.isCaution)                // softened ≠ plain caution surface
        XCTAssertFalse(v.markers.isEmpty)          // §4: the real risk signal is NEVER dropped
    }

    func testCriticismMarker_isContextSoftened() {
        let v = ctx("Bu saldırıyı şiddetle kınıyoruz; her türlü ölüm ve şiddete karşıyız.", "tr")
        XCTAssertEqual(v.outcome, .contextAssessed)
        XCTAssertEqual(v.contextStance, .criticizes)
        XCTAssertTrue(v.isContextSoftened)
    }

    func testUnknownStance_keepsPlainCaution_R3FallbackIntact() {
        // A marker with NO decisive structure → UNKNOWN stance → the R3 plain CAUTION is KEPT (never softened). This
        // pins the §4 law: UNKNOWN never drops a real risk signal; the R3 marker path stays intact.
        let v = ctx("Savaş. Ölüm. Felaket.", "tr")
        XCTAssertEqual(v.outcome, .caution)        // stays a plain R3 caution, NOT context-assessed-softened
        XCTAssertTrue(v.isCaution)
        XCTAssertFalse(v.isContextSoftened)
    }

    func testUnsupportedLanguageMarker_keepsPlainCaution() {
        // A marker in a supported-by-lexicon but NOT-supported-by-adapter case: if the adapter cannot run, the R3
        // CAUTION is unchanged. (Use a marker-bearing TR string tagged as a language the adapter does not support.)
        let v = GeneralContentCharacterV1.evaluateWithContext(
            ocrText: "savaşta ölüm haberleri geldi", detectedLanguage: "de",
            itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 1)
        // The LEXICON still fires on the tokens, but the adapter abstains (de unsupported) → plain CAUTION kept.
        if v.outcome == .caution { XCTAssertNil(v.contextStance) }  // no stance fabricated
        XCTAssertNotEqual(v.outcome, .contextAssessed)
    }

    func testBenignText_neverReachesContext() {
        // No marker → context analysis NEVER runs (a stance is only meaningful relative to a flagged risk).
        let v = ctx("Bugün hava çok güzel, parkta yürüyüş yaptık.", "tr")
        XCTAssertEqual(v.outcome, .examinedNoMarker)
        XCTAssertNil(v.contextStance)
    }

    func testNotAnalyzed_neverReachesContext_neverSafe() {
        let v = GeneralContentCharacterV1.evaluateWithContext(ocrText: nil, detectedLanguage: nil,
                                                              itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 1)
        XCTAssertEqual(v.outcome, .notAnalyzed)
        XCTAssertNil(v.contextStance)
        XCTAssertFalse(v.isCaution)
    }

    // MARK: - §2A — NOT_ANALYZED false-positive fallback REGRESSION (the surface-mapping decision table)
    //
    // The SampleHandler maps the general-character outcome to a surface. The defect was: OCR text present +
    // NOT_ANALYZED fell through to a benign GUARDIAN_ON. We reproduce the SAME mapping the extension uses as a pure
    // decision table so the four-way separation is pinned without a device.

    /// The exact mapping the extension applies (mirrors SampleHandler §2A). Returns (surfaceRaw, reasonCode).
    private func surfaceFor(_ v: GeneralContentCharacterVerdictV1, hasText: Bool) -> (String, GuardianReasonCodeV1) {
        if v.isCaution {
            return v.outcome == .contextAssessed
                ? ("CAUTION", .generalContentContextCaution)
                : ("CAUTION", .generalContentCaution)
        } else if v.isContextSoftened {
            return ("GUARDIAN_ON", .generalContentContextSoftened)
        } else if v.outcome == .notAnalyzed, hasText {
            return ("UNKNOWN", .generalContentNotAnalyzed)          // THE FIX — never benign GUARDIAN_ON
        } else if v.outcome == .examinedNoMarker {
            return ("GUARDIAN_ON", .generalContentExaminedNoMarker)
        } else if hasText {
            return ("GUARDIAN_ON", .textEvidenceBenign)
        } else {
            return ("UNKNOWN", .textEvidenceUnavailable)
        }
    }

    func testNotAnalyzedWithText_mapsToUnknown_notBenign() {
        // Text present, unsupported language → NOT_ANALYZED. MUST map to UNKNOWN/coverage-limited, NEVER GUARDIAN_ON.
        let v = GeneralContentCharacterV1.evaluateWithContext(ocrText: "これはテストです 死", detectedLanguage: "ja",
                                                              itemIdentityRevision: 1, policyRevision: 1, nowEpoch: 1)
        XCTAssertEqual(v.outcome, .notAnalyzed)
        let (surface, reason) = surfaceFor(v, hasText: true)
        XCTAssertEqual(surface, "UNKNOWN", "REGRESSION: NOT_ANALYZED with text must be UNKNOWN, never benign GUARDIAN_ON")
        XCTAssertEqual(reason, .generalContentNotAnalyzed)
        XCTAssertTrue(reason.turkishExplanation.contains("incelenemedi"))
        XCTAssertTrue(reason.turkishExplanation.contains("'güvenli' anlamına gelmez"))
    }

    func testExaminedNoMarker_mapsToScopeLimitedBenign() {
        let v = ctx("Bugün hava çok güzel, parkta yürüyüş yaptık.", "tr")
        let (surface, reason) = surfaceFor(v, hasText: true)
        XCTAssertEqual(surface, "GUARDIAN_ON")
        XCTAssertEqual(reason, .generalContentExaminedNoMarker)
        XCTAssertTrue(reason.turkishExplanation.contains("kapsamında") || reason.turkishExplanation.contains("incelendi"))
    }

    func testCautionAndContextSoftened_mapToDistinctSurfaces() {
        let advocacy = ctx("Hepsini gebertin, hak ettiler! Ölüm onlara!", "tr")
        XCTAssertEqual(surfaceFor(advocacy, hasText: true).0, "CAUTION")
        XCTAssertEqual(surfaceFor(advocacy, hasText: true).1, .generalContentContextCaution)

        let reporting = ctx("Polis açıkladı: saldırıda iki kişi öldü.", "tr")
        XCTAssertEqual(surfaceFor(reporting, hasText: true).0, "GUARDIAN_ON")
        XCTAssertEqual(surfaceFor(reporting, hasText: true).1, .generalContentContextSoftened)
        XCTAssertFalse(reporting.markers.isEmpty)   // the marker is still carried — never a silent drop
    }

    // MARK: - §2B — STATIC-FRAME REVALIDATION (shot-independent)

    func testStaticScreen_pastTTL_revalidatesWithoutShots() {
        // Open a decision window at t=100. At t=102 (past the base TTL of 3s? no — within), a static revalidation with
        // identity stable extends the window with its OWN timestamp; the ORIGINAL evidence epoch never moves.
        let w0 = GuardianDecisionRevalidationV1.open(decisionItemIdentityRevision: 5, decisionPolicyRevision: 1,
                                                     evidenceEpoch: 100)
        XCTAssertEqual(w0.originalEvidenceEpoch, 100)
        let (w1, out1) = GuardianDecisionRevalidationV1.revalidate(w0, identityStable: true, currentPolicyRevision: 1,
                                                                   currentItemIdentityRevision: 5, nowEpoch: 102.5)
        XCTAssertEqual(out1, .extended)
        XCTAssertEqual(w1?.originalEvidenceEpoch, 100, "original evidence epoch NEVER moves on revalidation")
        XCTAssertGreaterThan(w1!.validUntilEpoch, w0.validUntilEpoch, "validity window extended")
        XCTAssertEqual(w1?.lastRevalidationEpoch, 102.5, "the revalidation carries its OWN timestamp")
        XCTAssertEqual(w1?.revalidationCount, 1)
        // The decision is now VALID well past the original 3s TTL on a static screen — the P0-B fix.
        XCTAssertTrue(GuardianDecisionRevalidationV1.isValid(w1, currentItemIdentityRevision: 5,
                                                             currentPolicyRevision: 1, nowEpoch: 106))
    }

    func testStaticRevalidation_budgetExhaustion_degradesHonestly() {
        // Beyond the bounded cap (12), a static screen can no longer be extended on cheap checks → REFUSED (a genuine
        // re-analysis / honest UNKNOWN must follow). We never extend forever on cheap signals alone.
        var w: GuardianDecisionValidityWindowV1? = GuardianDecisionRevalidationV1.open(
            decisionItemIdentityRevision: 5, decisionPolicyRevision: 1, evidenceEpoch: 100)
        var lastOutcome = GuardianRevalidationOutcomeV1.extended
        for i in 1...(GuardianDecisionRevalidationV1.maxConsecutiveRevalidations + 1) {
            let r = GuardianDecisionRevalidationV1.revalidate(w, identityStable: true, currentPolicyRevision: 1,
                                                              currentItemIdentityRevision: 5, nowEpoch: 100 + Double(i))
            if r.outcome == .extended { w = r.window }
            lastOutcome = r.outcome
        }
        XCTAssertEqual(lastOutcome, .refusedBudgetExhausted, "beyond the cap, cheap revalidation refuses honestly")
    }

    func testStaticRevalidation_newItem_invalidatesImmediately() {
        let w = GuardianDecisionRevalidationV1.open(decisionItemIdentityRevision: 5, decisionPolicyRevision: 1,
                                                    evidenceEpoch: 100)
        let (w2, out) = GuardianDecisionRevalidationV1.revalidate(w, identityStable: false, currentPolicyRevision: 1,
                                                                  currentItemIdentityRevision: 6, nowEpoch: 101)
        XCTAssertEqual(out, .refusedIdentityUnstable)
        XCTAssertNil(w2, "a new item cannot be rescued by cheap revalidation")
    }

    // MARK: - §2C — the VALIDITY IPC FACT (heartbeat carries it; never fakes decisionEpoch forward)

    func testHeartbeat_carriesValidityFact_tolerantDecodeBackwardCompatible() {
        let hb = GuardianObservationHeartbeatV1(epochSeconds: 100, sequence: 1, surfaceRaw: "CAUTION",
                                                reasonCodeRaw: "generalContentCaution", broadcasting: true,
                                                sessionID: "S", policyRevision: 1, itemIdentityRevision: 5,
                                                decisionEpochSeconds: 90, currentItemIdentityRevision: 5,
                                                validUntilEpoch: 108, revalidationCount: 2, lastRevalidationEpoch: 103)
        let data = try! JSONEncoder().encode(hb)
        let back = try! JSONDecoder().decode(GuardianObservationHeartbeatV1.self, from: data)
        XCTAssertEqual(back.validUntilEpoch, 108)
        XCTAssertEqual(back.revalidationCount, 2)
        XCTAssertEqual(back.lastRevalidationEpoch, 103)
        // §2C law — the DECISION's own evidence epoch is NOT moved forward by the validity extension.
        XCTAssertEqual(back.decisionEpochSeconds, 90, "validity extension never fakes decisionEpoch forward")
    }

    func testHeartbeat_legacyJSONWithoutValidity_decodesToZeroDefaults() {
        // A pre-R4 heartbeat JSON (no validity keys) must still decode (tolerant) with zeroed validity.
        let legacy = """
        {"epochSeconds":100,"sequence":1,"surfaceRaw":"CAUTION","reasonCodeRaw":"x","broadcasting":true,\
        "sessionID":"S","policyRevision":1,"itemIdentityRevision":5,"decisionEpochSeconds":90,\
        "currentItemIdentityRevision":5}
        """.data(using: .utf8)!
        let hb = try! JSONDecoder().decode(GuardianObservationHeartbeatV1.self, from: legacy)
        XCTAssertEqual(hb.validUntilEpoch, 0)
        XCTAssertEqual(hb.revalidationCount, 0)
        XCTAssertEqual(hb.decisionEpochSeconds, 90)
    }

    // MARK: - §2D — self-eval counter SEMANTICS

    // MARK: - §6 — progressive understanding (surface-change provenance + evidence isolation)

    func testSurfaceChange_onSameItem_carriesProvenance() {
        let w = GuardianSessionTimelineWriterV1(sessionID: "S", suite: nil)
        // First evidence for item 1: a plain decision (no prior reason → no change provenance).
        let e1 = w.recordSurfaceChange(status: .benign, newReasonCodeRaw: "textEvidenceBenign",
                                       previousReasonCodeRaw: nil, changeReasonRaw: nil,
                                       identityRevision: 1, nowEpoch: 1)
        XCTAssertNotNil(e1)
        XCTAssertNil(e1?.previousReasonCodeRaw)       // first evidence carries no change provenance
        // Context accumulated on the SAME item → the surface is revised to a caution WITH provenance.
        let e2 = w.recordSurfaceChange(status: .caution, newReasonCodeRaw: "generalContentContextCaution",
                                       previousReasonCodeRaw: "textEvidenceBenign",
                                       changeReasonRaw: "context-accumulated-same-item",
                                       identityRevision: 1, nowEpoch: 2)
        XCTAssertEqual(e2?.previousReasonCodeRaw, "textEvidenceBenign")
        XCTAssertEqual(e2?.changeReasonRaw, "context-accumulated-same-item")
        XCTAssertEqual(e2?.reasonCodeRaw, "generalContentContextCaution")
    }

    func testSurfaceChange_evidenceNeverLeaksAcrossItems() {
        // A change on item 2 must NOT carry item 1's reason as its "previous" — the caller only passes a prior reason
        // when the item matches. We simulate: item 1 benign, then item 2's FIRST decision (prior = nil) → no leak.
        let w = GuardianSessionTimelineWriterV1(sessionID: "S", suite: nil)
        _ = w.recordSurfaceChange(status: .benign, newReasonCodeRaw: "textEvidenceBenign",
                                  previousReasonCodeRaw: nil, changeReasonRaw: nil, identityRevision: 1, nowEpoch: 1)
        let e2 = w.recordSurfaceChange(status: .caution, newReasonCodeRaw: "generalContentCaution",
                                       previousReasonCodeRaw: nil,          // item 2 first evidence — NO cross-item prior
                                       changeReasonRaw: nil, identityRevision: 2, nowEpoch: 2)
        XCTAssertNil(e2?.previousReasonCodeRaw, "item 1's reason must never leak onto item 2")
        XCTAssertNil(e2?.changeReasonRaw)
    }

    func testTimelineEvent_tolerantDecode_legacyNoProvenance() {
        let legacy = """
        {"sequence":1,"epochSeconds":1,"category":"DECISION","status":"BENIGN",\
        "reasonCodeRaw":"textEvidenceBenign","identityRevision":1}
        """.data(using: .utf8)!
        let ev = try! JSONDecoder().decode(GuardianTimelineEventV1.self, from: legacy)
        XCTAssertNil(ev.previousReasonCodeRaw)
        XCTAssertNil(ev.changeReasonRaw)
        XCTAssertEqual(ev.reasonCodeRaw, "textEvidenceBenign")
    }

    func testSelfEvalCounter_nonActionableCandidate_isNotFalseNegative() {
        var c = GuardianSelfEvalCountersV1()
        let candidate = PhotoShieldLiveMatchV1(ruleID: "r", featureID: "f", state: .matchLow, roi: .whole,
                                               aHashHamming: 12, dHashHamming: 16, itemIdentityRevision: 1,
                                               policyRevision: 1, sessionID: "s", shotID: 1, eventEpoch: 1)
        c.foldPhotoPass(best: candidate, legacyNeedsReauthor: 0, signaturesComputed: 1,
                        reusedCachedSignature: false, discardedStale: false, thermalSkipped: false)
        XCTAssertEqual(c.nonActionableVisualCandidate, 1)
        // The real-error counter stays ZERO — without an independent label we never count a candidate as an error.
        XCTAssertEqual(c.independentlyLabeledModelError, 0)
        XCTAssertTrue(c.summary.contains("nonActionableVisualCandidate"))
        XCTAssertTrue(c.summary.contains("independentlyLabeledModelError"))
        XCTAssertFalse(c.summary.contains("crossPathMismatch"), "the dishonest name is gone")
    }
}
