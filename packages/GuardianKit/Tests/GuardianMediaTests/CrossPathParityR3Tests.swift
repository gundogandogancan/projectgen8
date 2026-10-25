//
//  CrossPathParityR3Tests.swift — R3 §1/§2/§3/§4 PROOF: the cross-path photo-shield parity fix, the long-lived
//  decision revalidation truth, the single-source Island snapshot invariants, and the Island event lifecycle.
//
//  ALL numbers are SYNTHETIC / DEVICE_UNVERIFIED (synthetic luma grids + synthetic timestamps, not a real iPhone /
//  real social apps). The point of §1 here is the PIPELINE parity: the SAME image, ingested via the CGImage path and
//  observed via the live luma path, now reaches an ACTIONABLE (HIGH/EXACT) match because BOTH paths sample through the
//  ONE canonical sampler — closing the R2 MEDIUM/LOW defect. We measure FP and FN separately per scenario.
//
import XCTest
@testable import GuardianMedia
import GuardianIntelligence
import GuardianCore
import CoreGraphics

final class CrossPathParityR3Tests: XCTestCase {

    // MARK: - fixtures (shared shape with PhotoShieldLumaMatcherTests so the SAME P006C thresholds apply)

    private func patternLuma(_ id: Int, width: Int = 128, height: Int = 128) -> [UInt8] {
        var seed = UInt64(id &* 2654435761 &+ 1)
        func next() -> UInt8 { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return UInt8((seed >> 40) & 0xFF) }
        var cells = [UInt8](repeating: 0, count: 64)
        for i in 0..<64 { cells[i] = next() }
        var out = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height { for x in 0..<width {
            let cx = x * 8 / width, cy = y * 8 / height
            out[y * width + x] = cells[cy * 8 + cx]
        } }
        return out
    }

    private func patternImage(_ id: Int, width: Int = 128, height: Int = 128) -> CGImage? {
        let luma = patternLuma(id, width: width, height: height)
        let space = CGColorSpaceCreateDeviceGray()
        var bytes = luma
        guard let ctx = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                  space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        return ctx.makeImage()
    }

    private func makeStore() -> (PersonalShieldSharedStoreV1, URL, String) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("r3-\(UUID().uuidString)")
        let suiteName = "r3.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        return (PersonalShieldSharedStoreV1(directory: dir, suite: suite, sharedContainerActive: true), dir, suiteName)
    }

    // ================= R3 §1 — CROSS-PATH PARITY =================

    /// §1.3 #1+#2 — the REAL chain: a user photo ingested via the CGImage path (PhotosPicker-equivalent) now reaches
    /// an ACTIONABLE match against a live luma frame of the SAME picture. This is the R2 defect FIXED: it used to land
    /// at MEDIUM/LOW (not actionable), so a user looking at their own forbidden image got no warning.
    func testCrossPathIdenticalImageIsNowActionable() throws {
        let (store, dir, suite) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir); UserDefaults().removePersistentDomain(forName: suite) }
        let img = try XCTUnwrap(patternImage(7))
        _ = try XCTUnwrap(PersonalPhotoShieldV1.addReference(cgImage: img, label: "benim-fotoğrafım", action: .warn,
                                                             nowEpoch: 1, store: store, existingRules: []))
        let features = store.loadFeatures()
        // Live frame of the SAME picture through the live luma path.
        let pass = PhotoShieldLumaMatcherV1.matchLuma(patternLuma(7), width: 128, height: 128, features: features,
                                                      itemIdentityRevision: 1, policyRevision: 1, sessionID: "s",
                                                      shotID: 1, nowEpoch: 2, allowROIEscalation: true)
        let best = try XCTUnwrap(pass.best, "the user's ingested photo must match the live frame of the same picture")
        XCTAssertTrue(best.isActionable, "CROSS-PATH identical image is now ACTIONABLE (R2 MEDIUM/LOW defect fixed)")
    }

    /// §1.3 #8 (false positive) — a DIFFERENT (lookalike) image must NOT be actionable. Parity must not be bought by
    /// loosening thresholds: the near-exact bar still rejects a different picture. Measures FP = 0.
    func testCrossPathLookalikeNotActionableNoFP() throws {
        let (store, dir, suite) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir); UserDefaults().removePersistentDomain(forName: suite) }
        let img = try XCTUnwrap(patternImage(7))
        _ = try XCTUnwrap(PersonalPhotoShieldV1.addReference(cgImage: img, label: "ref", action: .warn,
                                                             nowEpoch: 1, store: store, existingRules: []))
        let features = store.loadFeatures()
        var falsePositives = 0
        for other in [8, 42, 99, 123, 256] {
            let pass = PhotoShieldLumaMatcherV1.matchLuma(patternLuma(other), width: 128, height: 128, features: features,
                                                          itemIdentityRevision: 1, policyRevision: 1, sessionID: "s",
                                                          shotID: 1, nowEpoch: 2, allowROIEscalation: true)
            if pass.best?.isActionable == true { falsePositives += 1 }
        }
        XCTAssertEqual(falsePositives, 0, "no different image actionably matches (FP=0 — thresholds NOT loosened)")
    }

    /// §1.2 — real BGRA luminance: the canonical luma601 weights are a true luminance, NOT the old B-channel-only
    /// proxy. A pure-blue vs pure-red pixel must yield DIFFERENT luma (the old proxy wrongly made blue the brightest).
    func testBGRALuminanceIsRealNotBlueChannel() {
        // BT.601: green dominates, blue is the weakest. luma(pure green) > luma(pure red) > luma(pure blue).
        let lg = GuardianCanonicalSamplerV1.luma601(r: 0, g: 255, b: 0)
        let lr = GuardianCanonicalSamplerV1.luma601(r: 255, g: 0, b: 0)
        let lb = GuardianCanonicalSamplerV1.luma601(r: 0, g: 0, b: 255)
        XCTAssertGreaterThan(lg, lr, "green is the brightest luminance (BT.601)")
        XCTAssertGreaterThan(lr, lb, "red is brighter than blue — the OLD B-only proxy had this exactly backwards")
        XCTAssertEqual(GuardianCanonicalSamplerV1.luma601(r: 255, g: 255, b: 255), 255, "white stays white")
        XCTAssertEqual(GuardianCanonicalSamplerV1.luma601(r: 0, g: 0, b: 0), 0, "black stays black")
    }

    /// §1.1 — the canonical sampler AREA-AVERAGES: a uniform plane yields a uniform grid; a half-dark/half-bright
    /// plane yields the per-cell average, never a single point sample. This is what makes the two paths agree.
    func testCanonicalSamplerAreaAverages() throws {
        // 16x16 plane, left half 0, right half 200. Area-average to 2x1 → ~[0, 200]; to 1x1 → ~100 (the mean).
        var plane = [UInt8](repeating: 0, count: 16 * 16)
        for y in 0..<16 { for x in 8..<16 { plane[y * 16 + x] = 200 } }
        let g2 = try XCTUnwrap(GuardianCanonicalSamplerV1.grid(fromLuma: plane, width: 16, height: 16,
                                                               roi: (0, 0, 1, 1), targetW: 2, targetH: 1))
        XCTAssertEqual(g2[0], 0, "left cell averages the dark half")
        XCTAssertEqual(g2[1], 200, "right cell averages the bright half")
        let g1 = try XCTUnwrap(GuardianCanonicalSamplerV1.grid(fromLuma: plane, width: 16, height: 16,
                                                               roi: (0, 0, 1, 1), targetW: 1, targetH: 1))
        XCTAssertEqual(Int(g1[0]), 100, "a single cell averages the whole plane (area, not a point sample)")
    }

    /// §1.2 — an UNSUPPORTED format classifies honestly; the extract-format switch never silently guesses.
    func testUnsupportedPixelFormatIsHonestUnavailable() {
        XCTAssertEqual(PhotoShieldLumaMatcherV1.extractFormat(kCVPixelFormatType_32BGRA), .bgra)
        XCTAssertEqual(PhotoShieldLumaMatcherV1.extractFormat(kCVPixelFormatType_32ARGB), .argb)
        XCTAssertEqual(PhotoShieldLumaMatcherV1.extractFormat(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), .yuv420)
        XCTAssertEqual(PhotoShieldLumaMatcherV1.extractFormat(kCVPixelFormatType_32RGBA), .unsupported,
                       "an unlisted format is UNSUPPORTED (honest) — never a wrong-layout read")
    }

    /// §1.1 — a LEGACY (pre-canonical) persisted signature is NOT silently matched against a canonical live frame; it
    /// is reported NEEDS_REAUTHOR. This prevents a mixed-basis comparison from producing a weak/false match.
    func testLegacyBasisSignatureReportsNeedsReauthor() throws {
        // Build a LEGACY signature the old way (algorithm id without the canonical basis tag).
        let legacy = PersistedVisualReferenceSignature(ruleID: "photo-legacy", components: [
            VisualSignatureComponent(kind: .aHash, algorithmID: "ahash-8x8-v1",
                                     engineRevision: PersistedVisualReferenceSignature.currentEngineRevision,
                                     dimension: 64, data: VisualSignatureBits.pack(0xDEAD_BEEF_0000_0000),
                                     normalization: "mean-threshold", createdAtEpoch: 1),
            VisualSignatureComponent(kind: .dHash, algorithmID: "dhash-9x8-v1",
                                     engineRevision: PersistedVisualReferenceSignature.currentEngineRevision,
                                     dimension: 64, data: VisualSignatureBits.pack(0x0000_0000_DEAD_BEEF),
                                     normalization: "row-gradient", createdAtEpoch: 1),
        ])
        XCTAssertEqual(PhotoShieldLumaMatcherV1.basisOfSignature(legacy), .legacy)
        let encoded = try JSONEncoder().encode(legacy)
        let feature = DerivedReferenceFeature(featureID: "f", ruleID: "photo-legacy", featureType: .image,
                                              engineID: "ahash-8x8-v1", engineRevision: "sig-r1",
                                              vectorDimension: 128, serializedFeature: encoded, createdAtEpoch: 1)
        let pass = PhotoShieldLumaMatcherV1.matchLuma(patternLuma(7), width: 128, height: 128, features: [feature],
                                                      itemIdentityRevision: 1, policyRevision: 1, sessionID: "s",
                                                      shotID: 1, nowEpoch: 2, allowROIEscalation: true)
        XCTAssertNil(pass.best, "a legacy-basis reference is NOT silently matched against a canonical live signature")
        XCTAssertEqual(pass.legacyNeedsReauthor, 1, "it is surfaced as NEEDS_REAUTHOR (honest), never a false match")
    }

    /// §6 — a NEW rule id is a UUID minted at creation (no label-derived identity), yet still recognised as a photo id.
    func testNewRuleIDIsUUIDAndCollisionFree() {
        let a = PhotoShieldLumaMatcherV1.newRuleID(), b = PhotoShieldLumaMatcherV1.newRuleID()
        XCTAssertNotEqual(a, b, "two new rule ids never collide (random UUID, not a label digest)")
        XCTAssertTrue(PhotoShieldLumaMatcherV1.isPhotoRuleID(a), "a UUID rule id is still recognised as a photo rule")
        XCTAssertTrue(PhotoShieldLumaMatcherV1.isPhotoRuleID("photo-12345-1000"), "legacy ids still recognised (migration)")
    }

    // ================= R3 §2 — LONG-LIVED DECISION REVALIDATION =================

    /// §2 — STATIC content beyond the base TTL is REVALIDATED (not stale, not fake-fresh) when identity is stable +
    /// policy unchanged, and the ORIGINAL evidence epoch is PRESERVED (freshness is not falsified).
    func testStaticContentRevalidatedBeyondTTL() {
        let w0 = GuardianDecisionRevalidationV1.open(decisionItemIdentityRevision: 5, decisionPolicyRevision: 1,
                                                     evidenceEpoch: 100)
        // Just past the base validity window → would be stale with no revalidation.
        let tStale = 100 + GuardianDecisionRevalidationV1.baseValidityWindowSeconds + 0.5
        XCTAssertFalse(GuardianDecisionRevalidationV1.isValid(w0, currentItemIdentityRevision: 5,
                       currentPolicyRevision: 1, nowEpoch: tStale), "without revalidation the decision aged out")
        // A cheap revalidation (identity stable, policy unchanged) extends validity.
        let (w1, outcome) = GuardianDecisionRevalidationV1.revalidate(w0, identityStable: true, currentPolicyRevision: 1,
                                                                      currentItemIdentityRevision: 5, nowEpoch: tStale)
        XCTAssertEqual(outcome, .extended)
        let w1u = try! XCTUnwrap(w1)
        XCTAssertTrue(GuardianDecisionRevalidationV1.isValid(w1u, currentItemIdentityRevision: 5,
                      currentPolicyRevision: 1, nowEpoch: tStale), "after revalidation the static decision is valid again")
        XCTAssertEqual(w1u.originalEvidenceEpoch, 100, "the ORIGINAL evidence epoch is preserved (not fake-fresh)")
        XCTAssertEqual(w1u.lastRevalidationEpoch, tStale, "the revalidation carries its OWN timestamp (provenance)")
        XCTAssertEqual(w1u.revalidationCount, 1, "the revalidation is counted (audit)")
    }

    /// §2 — revalidation is REFUSED when identity is unstable (a new/unconfirmed item) → the decision invalidates.
    func testRevalidationRefusedWhenIdentityUnstable() {
        let w0 = GuardianDecisionRevalidationV1.open(decisionItemIdentityRevision: 5, decisionPolicyRevision: 1,
                                                     evidenceEpoch: 100)
        // Same item id but identity NOT confirmed stable → refuse.
        let (w1, o1) = GuardianDecisionRevalidationV1.revalidate(w0, identityStable: false, currentPolicyRevision: 1,
                                                                 currentItemIdentityRevision: 5, nowEpoch: 101)
        XCTAssertEqual(o1, .refusedIdentityUnstable); XCTAssertNil(w1)
        // Different item id → refuse (a new item invalidates immediately).
        let (w2, o2) = GuardianDecisionRevalidationV1.revalidate(w0, identityStable: true, currentPolicyRevision: 1,
                                                                 currentItemIdentityRevision: 6, nowEpoch: 101)
        XCTAssertEqual(o2, .refusedIdentityUnstable); XCTAssertNil(w2)
    }

    /// §2 — a policy bump MID-STATIC invalidates immediately; no cheap revalidation can rescue a stale-policy decision.
    func testPolicyBumpInvalidatesImmediately() {
        let w0 = GuardianDecisionRevalidationV1.open(decisionItemIdentityRevision: 5, decisionPolicyRevision: 1,
                                                     evidenceEpoch: 100)
        let (w1, o) = GuardianDecisionRevalidationV1.revalidate(w0, identityStable: true, currentPolicyRevision: 2,
                                                                currentItemIdentityRevision: 5, nowEpoch: 101)
        XCTAssertEqual(o, .refusedPolicyChanged, "a policy change refuses reuse (must re-analyse)")
        XCTAssertNil(w1)
        XCTAssertFalse(GuardianDecisionRevalidationV1.isValid(w0, currentItemIdentityRevision: 5,
                       currentPolicyRevision: 2, nowEpoch: 101), "the decision is invalid under the new policy")
    }

    /// §2 — bounded: after the cap, a cheap revalidation is REFUSED (forces a full re-analysis — never extend forever).
    func testRevalidationBudgetIsBounded() {
        var w: GuardianDecisionValidityWindowV1? = GuardianDecisionRevalidationV1.open(
            decisionItemIdentityRevision: 5, decisionPolicyRevision: 1, evidenceEpoch: 100)
        var t = 100.0
        for _ in 0..<GuardianDecisionRevalidationV1.maxConsecutiveRevalidations {
            t += 1
            let (nw, o) = GuardianDecisionRevalidationV1.revalidate(w, identityStable: true, currentPolicyRevision: 1,
                                                                    currentItemIdentityRevision: 5, nowEpoch: t)
            XCTAssertEqual(o, .extended); w = nw
        }
        t += 1
        let (nw, o) = GuardianDecisionRevalidationV1.revalidate(w, identityStable: true, currentPolicyRevision: 1,
                                                                currentItemIdentityRevision: 5, nowEpoch: t)
        XCTAssertEqual(o, .refusedBudgetExhausted, "past the cap, cheap reuse is refused → force a full re-analysis")
        XCTAssertNil(nw)
    }

    // ================= R3 §3 — ISLAND SINGLE SOURCE OF TRUTH (snapshot invariants) =================

    private func snapshot(_ facts: GuardianRealityFactsV1, reason: String = "") -> GuardianSurfaceSnapshotV1 {
        GuardianSurfaceSnapshotV1.derive(projection: GuardianRealityProjectionV1.derive(facts),
                                         sessionID: "s", currentItemIdentityRevision: facts.currentItemIdentityRevision,
                                         decisionItemIdentityRevision: facts.decisionItemIdentityRevision,
                                         policyRevision: facts.currentPolicyRevision ?? 0,
                                         decisionEpochSeconds: 0, decisionReasonRaw: reason, evidenceCoverageRaw: "TEXT")
    }

    /// §3 invariant — STALE_ITEM: a new item on screen ⇒ the writer cannot publish the previous GUARDIAN_ON.
    func testSnapshotStaleItemCannotPublishPreviousGuardianOn() {
        var f = GuardianRealityFactsV1()
        f.userRequestedOn = true; f.osCaptureStarted = true; f.framesArriving = true; f.analysisActive = true
        f.appGroupIPCWorking = true
        f.decisionItemIdentityRevision = 1; f.decisionPolicyRevision = 1; f.decisionFresh = true
        f.currentItemIdentityRevision = 2   // a NEW item is on screen
        f.currentPolicyRevision = 1
        f.lastDecisionSurfaceRaw = "GUARDIAN_ON"   // the prior item's green
        let snap = snapshot(f)
        XCTAssertTrue(snap.isStaleItem)
        XCTAssertEqual(snap.islandPublishSurfaceRaw, "UNKNOWN", "a stale item collapses to UNKNOWN (no carried green)")
        XCTAssertFalse(snap.activeProtection, "stale item ⇒ not active protection")
        XCTAssertNotEqual(snap.islandPublishSurfaceRaw, "GUARDIAN_ON", "the previous GUARDIAN_ON is never republished")
    }

    /// §3 invariant — CAPTURE_NOT_RUNNING: no live protection may be shown.
    func testSnapshotCaptureNotRunningNoLiveProtection() {
        var f = GuardianRealityFactsV1()
        f.userRequestedOn = true; f.appGroupIPCWorking = true
        f.osCaptureStarted = false; f.framesArriving = false   // requested, but capture not running
        let snap = snapshot(f)
        XCTAssertFalse(snap.captureRunning)
        XCTAssertFalse(snap.canShowLiveProtection, "CAPTURE_NOT_RUNNING can never show live protection")
        XCTAssertEqual(snap.islandPublishSurfaceRaw, "UNKNOWN", "no content surface while capture is not confirmed")
    }

    /// §3 invariant — UNKNOWN: no safe-looking value leaks.
    func testSnapshotUnknownNeverSafeLooking() {
        var f = GuardianRealityFactsV1()
        f.userRequestedOn = true; f.osCaptureStarted = true; f.framesArriving = true; f.analysisActive = true
        f.appGroupIPCWorking = true
        // Observing/analyzing but NO decision yet → UNKNOWN, never a green/safe value.
        f.currentItemIdentityRevision = 1; f.currentPolicyRevision = 1
        let snap = snapshot(f)
        XCTAssertEqual(snap.islandPublishSurfaceRaw, "UNKNOWN")
        XCTAssertFalse(snap.activeProtection, "no valid decision ⇒ not active protection (UNKNOWN ≠ safe)")
    }

    /// §3 — a VALID current-item decision DOES surface + is active protection (the snapshot is not merely pessimistic).
    func testSnapshotValidDecisionSurfacesActiveProtection() {
        var f = GuardianRealityFactsV1()
        f.userRequestedOn = true; f.osCaptureStarted = true; f.framesArriving = true; f.analysisActive = true
        f.appGroupIPCWorking = true
        f.decisionItemIdentityRevision = 3; f.decisionPolicyRevision = 1; f.decisionFresh = true
        f.currentItemIdentityRevision = 3; f.currentPolicyRevision = 1
        f.lastDecisionSurfaceRaw = "GUARDIAN_ON"
        let snap = snapshot(f)
        XCTAssertEqual(snap.islandPublishSurfaceRaw, "GUARDIAN_ON", "a valid current-item decision surfaces honestly")
        XCTAssertTrue(snap.activeProtection)
        XCTAssertTrue(snap.canShowLiveProtection)
    }

    // ================= R3 §4.3 — ISLAND EVENT LIFECYCLE (staleDate) =================

    /// §4.3 — a dead capture (staleDate passed) collapses ANY reached rung to CAPTURE_STALE → no evergreen live band.
    func testIslandEventStaleDateForcesCaptureStale() {
        let live = GuardianIslandEventLifecycleFactsV1(reached: .activityUpdateApplied, staleDateEpoch: 110,
                                                       nowEpoch: 105)
        XCTAssertEqual(GuardianIslandEventLifecycleV1.resolve(live), .activityUpdateApplied)
        XCTAssertTrue(GuardianIslandEventLifecycleV1.canShowLiveBand(live))
        let dead = GuardianIslandEventLifecycleFactsV1(reached: .activityUpdateApplied, staleDateEpoch: 110,
                                                       nowEpoch: 111)   // past staleDate
        XCTAssertEqual(GuardianIslandEventLifecycleV1.resolve(dead), .captureStale,
                       "past the staleDate the band collapses to CAPTURE_STALE (no evergreen live)")
        XCTAssertFalse(GuardianIslandEventLifecycleV1.canShowLiveBand(dead))
    }

    /// §4.3 — capture ended is a hard terminal stale regardless of how far the ladder got.
    func testIslandEventCaptureEndedIsTerminalStale() {
        let ended = GuardianIslandEventLifecycleFactsV1(reached: .activityUpdateApplied, staleDateEpoch: 999,
                                                        nowEpoch: 100, captureEnded: true)
        XCTAssertEqual(GuardianIslandEventLifecycleV1.resolve(ended), .captureStale)
        XCTAssertFalse(GuardianIslandEventLifecycleV1.canShowLiveBand(ended))
    }

    /// §4.3 — a mid-ladder rung (written, not yet updated) is NOT a live band (the write-vs-update gap stays honest).
    func testIslandEventWrittenNotUpdatedIsNotLiveBand() {
        let written = GuardianIslandEventLifecycleFactsV1(reached: .appGroupWritten, staleDateEpoch: 110, nowEpoch: 105)
        XCTAssertEqual(GuardianIslandEventLifecycleV1.resolve(written), .appGroupWritten)
        XCTAssertFalse(GuardianIslandEventLifecycleV1.canShowLiveBand(written),
                       "an App Group write is NOT an ActivityKit update → not a live Island band")
    }

    // ================= R3 §9 — SELF-EVAL COUNTERS =================

    /// §9 — the counters MEASURE the new R3 signals (never mutate a threshold). A cross-path residual (any-match but
    /// not actionable) is counted; a stale discard is counted; legacy-needs-reauthor is accumulated; a suspended-app
    /// blocked Island update is counted. Independent ground truth = the caller's flags, not the pipeline's own id.
    func testSelfEvalCountersMeasureNewSignals() {
        var c = GuardianSelfEvalCountersV1()
        let anyNotActionable = PhotoShieldLiveMatchV1(ruleID: "r", featureID: "f", state: .matchLow, roi: .whole,
                                                      aHashHamming: 12, dHashHamming: 16, itemIdentityRevision: 1,
                                                      policyRevision: 1, sessionID: "s", shotID: 1, eventEpoch: 1)
        c.foldPhotoPass(best: anyNotActionable, legacyNeedsReauthor: 2, signaturesComputed: 1,
                        reusedCachedSignature: false, discardedStale: true, thermalSkipped: false)
        XCTAssertEqual(c.crossPathMismatch, 1, "an any-match-but-not-actionable residual is measured")
        XCTAssertEqual(c.staleDiscards, 1)
        XCTAssertEqual(c.legacyNeedsReauthor, 2)
        c.foldRevalidation(.extended); c.foldRevalidation(.refusedPolicyChanged)
        XCTAssertEqual(c.revalidationExtended, 1); XCTAssertEqual(c.revalidationRefused, 1)
        let blocked = GuardianIslandUpdateChainV1.derive(
            GuardianIslandUpdateFactsV1(operatingState: .appSuspendedOtherForeground, appGroupWriteFresh: true,
                                        activityKitUpdateApplied: false))
        c.foldIslandChain(blocked)
        XCTAssertEqual(c.blockedIslandUpdates, 1, "the suspended-app known gap is counted honestly")
        XCTAssertFalse(c.summary.isEmpty)
    }

    /// §9 — an ACTIONABLE match is NOT a cross-path mismatch (the fix working is not counted as a residual).
    func testActionableMatchIsNotCrossPathMismatch() {
        var c = GuardianSelfEvalCountersV1()
        let actionable = PhotoShieldLiveMatchV1(ruleID: "r", featureID: "f", state: .matchHigh, roi: .whole,
                                                aHashHamming: 2, dHashHamming: 3, itemIdentityRevision: 1,
                                                policyRevision: 1, sessionID: "s", shotID: 1, eventEpoch: 1)
        c.foldPhotoPass(best: actionable, legacyNeedsReauthor: 0, signaturesComputed: 1,
                        reusedCachedSignature: false, discardedStale: false, thermalSkipped: false)
        XCTAssertEqual(c.crossPathMismatch, 0, "a HIGH/EXACT match is the fix working — not a residual")
    }
}
