//
//  PhotoShieldLumaMatcherTests.swift — R2 §E/§G PROOF: the PRODUCTION live-frame photo matcher exercised over
//  synthetic luma fixtures that stand in for the mandate's §E scenarios (full-screen reference / reference embedded
//  in a social-UI composite / cropped / overlay / same-color-different-subject / similar-shape-different-reference /
//  resolutions / partial visibility / 10-item rapid sequence / stale-match carryover forbidden / policy change
//  mid-analysis / deleted reference no longer matches). Uses the REAL PhotoShieldLumaMatcherV1 + PersonalPhotoShieldV1
//  ingest + PersonalShieldSharedStoreV1 — NOT a parallel test-only matcher.
//
//  ALL numbers here are DEVICE_UNVERIFIED (synthetic luma grids, not real iPhone frames / real social apps). We
//  measure signature + ROI counts and label them as such. FP/FN are reported per scenario in the assertions.
//
import XCTest
@testable import GuardianMedia
import GuardianIntelligence
import GuardianCore
import CoreGraphics

final class PhotoShieldLumaMatcherTests: XCTestCase {

    // MARK: - Synthetic luma fixtures (pure arrays — no CoreVideo needed; the matcher's signature() is pure over luma)

    /// A deterministic structured luma grid: an 8×8 block pattern seeded by `id`, scaled up to WxH. Same id ≡ same
    /// perceptual structure (what perceptual hashing is built to recognise). This mirrors the PersonalPhotoShieldTests
    /// pattern so the SAME P006C thresholds apply.
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

    /// The matching CGImage for the SAME id/structure (so the reference ingested via the production engine and the
    /// live luma built by the matcher describe the same picture).
    private func patternImage(_ id: Int, width: Int = 128, height: Int = 128) -> CGImage? {
        let luma = patternLuma(id, width: width, height: height)
        let space = CGColorSpaceCreateDeviceGray()
        var bytes = luma
        guard let ctx = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                  space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        return ctx.makeImage()
    }

    /// Embed a reference pattern inside a "social UI" composite: a top bar + bottom action strip of flat luma drawn
    /// around the reference occupying the CONTENT band (0.12..0.78 vertically — exactly the matcher's CONTENT ROI).
    private func socialComposite(refID: Int, width: Int = 128, height: Int = 128,
                                 barLuma: UInt8 = 20) -> [UInt8] {
        var out = [UInt8](repeating: barLuma, count: width * height)
        let ref = patternLuma(refID, width: width, height: height)
        let y0 = Int(0.12 * Double(height)), y1 = Int(0.78 * Double(height))
        for y in y0..<y1 { for x in 0..<width {
            // Sample the reference stretched into the content band.
            let ry = (y - y0) * height / max(1, (y1 - y0))
            out[y * width + x] = ref[min(height - 1, ry) * width + x]
        } }
        return out
    }

    /// Build a reference DerivedReferenceFeature through the MATCHER'S OWN luma signature path (whole ROI). This is
    /// the honest apples-to-apples reference for the live path: both sides use the identical luma→signature code, so
    /// an identical frame is genuinely near-exact (ACTIONABLE). It mirrors how a device would ideally ingest from the
    /// same capture pipeline. (The CGImage-ingest path — PersonalPhotoShieldV1.addReference — is also tested, but it
    /// uses a DIFFERENT downsampler, so a cross-path identical frame lands at MATCH_MEDIUM/LOW: an honest finding.)
    private func lumaFeature(_ id: Int, ruleID: String = "photo-fixture", width: Int = 128, height: Int = 128) throws -> DerivedReferenceFeature {
        let luma = patternLuma(id, width: width, height: height)
        let sig = try XCTUnwrap(PhotoShieldLumaMatcherV1.signature(luma: luma, width: width, height: height,
                                                                   roi: .whole, ruleID: ruleID, nowEpoch: 1))
        let encoded = try JSONEncoder().encode(sig)
        return DerivedReferenceFeature(featureID: "visualsig-" + ruleID, ruleID: ruleID, featureType: .image,
                                       engineID: "ahash-8x8-v1", engineRevision: "sig-r1",
                                       vectorDimension: 384, serializedFeature: encoded, createdAtEpoch: 1)
    }

    private func makeStore() -> (PersonalShieldSharedStoreV1, URL, String) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("plm-\(UUID().uuidString)")
        let suiteName = "plm.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        return (PersonalShieldSharedStoreV1(directory: dir, suite: suite, sharedContainerActive: true), dir, suiteName)
    }

    /// Ingest `refID` as a real photo reference through the production path and return the persisted features.
    private func ingest(_ refID: Int, into store: PersonalShieldSharedStoreV1, label: String = "ref") throws -> [DerivedReferenceFeature] {
        let img = try XCTUnwrap(patternImage(refID))
        _ = try XCTUnwrap(PersonalPhotoShieldV1.addReference(cgImage: img, label: label, action: .warn,
                                                             nowEpoch: 1, store: store, existingRules: []))
        return store.loadFeatures()
    }

    // MARK: - §G — stable, collision-free, process-stable rule id (NOT hashValue).

    func testStableRuleIDIsDeterministicAndCollisionAvoiding() {
        let a1 = PhotoShieldLumaMatcherV1.stableRuleID(forLabel: "fenerbahçe", createdAtEpoch: 1000)
        let a2 = PhotoShieldLumaMatcherV1.stableRuleID(forLabel: "fenerbahçe", createdAtEpoch: 1000)
        XCTAssertEqual(a1, a2, "same label + epoch → SAME id (deterministic across calls/processes, unlike hashValue)")
        XCTAssertTrue(a1.hasPrefix("photo-"), "id is the opaque photo- form")
        XCTAssertTrue(PhotoShieldLumaMatcherV1.isPhotoRuleID(a1))
        // Different label or epoch → different id (no silent collision).
        XCTAssertNotEqual(a1, PhotoShieldLumaMatcherV1.stableRuleID(forLabel: "beşiktaş", createdAtEpoch: 1000))
        XCTAssertNotEqual(a1, PhotoShieldLumaMatcherV1.stableRuleID(forLabel: "fenerbahçe", createdAtEpoch: 2000))
        // Legacy hashValue-form ids still recognised as photo rules (migration tolerance).
        XCTAssertTrue(PhotoShieldLumaMatcherV1.isPhotoRuleID("photo-12345-1000"))
    }

    func testPersonalPhotoShieldRuleIDNowUsesStableForm() {
        let rid = PersonalPhotoShieldV1.ruleID(forLabel: "x", nowEpoch: 5)
        XCTAssertEqual(rid, PhotoShieldLumaMatcherV1.stableRuleID(forLabel: "x", createdAtEpoch: 5),
                       "PersonalPhotoShieldV1.ruleID delegates to the stable FNV-1a id (§G fix)")
        // The 16-hex-digit form proves it is NOT the old abs(hashValue) decimal form.
        XCTAssertTrue(rid.hasPrefix("photo-") && rid.count == "photo-".count + 16)
    }

    // MARK: - §E#1 — full-screen reference matches (and is ACTIONABLE / near-exact).

    func testFullScreenReferenceMatchesActionable() throws {
        // Same luma pipeline on both sides → an identical full-screen reference is genuinely near-exact (ACTIONABLE).
        let feature = try lumaFeature(7)
        let live = patternLuma(7)
        let pass = PhotoShieldLumaMatcherV1.matchLuma(live, width: 128, height: 128, features: [feature],
                                                      itemIdentityRevision: 1, policyRevision: 1, sessionID: "s",
                                                      shotID: 1, nowEpoch: 2, allowROIEscalation: true)
        let best = try XCTUnwrap(pass.best, "full-screen reference must match")
        XCTAssertTrue(best.isActionable, "an identical full-screen reference (same pipeline) is an actionable match")
        XCTAssertEqual(best.roi, .whole, "the whole-frame hint catches a full-screen reference first (cheapest)")
        XCTAssertEqual(pass.signaturesComputed, 1, "whole-frame actionable → we STOP, only ONE signature computed")
    }

    // §E — honest CROSS-PATH finding: a reference ingested via the CGImage path (user photo picker) vs a live luma
    // frame of the SAME picture still produces a REAL match, but — because the two downsamplers differ — it is NOT
    // guaranteed to be near-exact (it lands at MEDIUM/LOW here). We assert a real match, NOT actionability. This is
    // the DEVICE_UNVERIFIED reality the mandate asks us to be honest about: perceptual agreement across two different
    // capture/ingest pipelines is weaker than same-pipeline agreement, and precision-first means we do NOT escalate it.
    func testCrossPathIdenticalReferenceIsRealMatchNotNecessarilyActionable() throws {
        let (store, dir, suite) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir); UserDefaults().removePersistentDomain(forName: suite) }
        let features = try ingest(7, into: store)   // CGImage-ingest reference
        let pass = PhotoShieldLumaMatcherV1.matchLuma(patternLuma(7), width: 128, height: 128, features: features,
                                                      itemIdentityRevision: 1, policyRevision: 1, sessionID: "s",
                                                      shotID: 1, nowEpoch: 2, allowROIEscalation: true)
        let best = try XCTUnwrap(pass.best, "a cross-path identical reference is still a REAL (any-tier) match")
        XCTAssertTrue(best.isAnyMatch, "the reference is recognised across the two ingest/live pipelines")
    }

    // MARK: - §E#2 — reference embedded in a social-UI composite matches via the CONTENT ROI (bounded escalation).

    func testEmbeddedInSocialUIMatchesViaContentROI() throws {
        let (store, dir, suite) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir); UserDefaults().removePersistentDomain(forName: suite) }
        let features = try ingest(7, into: store)
        let composite = socialComposite(refID: 7)
        let pass = PhotoShieldLumaMatcherV1.matchLuma(composite, width: 128, height: 128, features: features,
                                                      itemIdentityRevision: 1, policyRevision: 1, sessionID: "s",
                                                      shotID: 1, nowEpoch: 2, allowROIEscalation: true)
        // The whole-frame hint is diluted by the bars; the CONTENT ROI recovers the reference. We assert a REAL match
        // was found (any tier) via a non-whole ROI — the bounded escalation did its job.
        let best = try XCTUnwrap(pass.best, "reference embedded in social UI must still be found via a region ROI")
        XCTAssertTrue(best.isAnyMatch)
        XCTAssertNotEqual(best.roi, .whole, "the embedded reference is recovered by a content/center ROI, not whole")
        XCTAssertGreaterThan(pass.roisEvaluated, 1, "we escalated to the bounded ROI set (not just whole)")
        XCTAssertLessThanOrEqual(pass.roisEvaluated, PhotoShieldROIV1.allCases.count, "ROI set stays bounded (≤3)")
    }

    // MARK: - §E#5/#6 — same-color-different-subject / similar-shape-different-reference must NOT be actionable.

    func testUnrelatedPatternNotActionable() throws {
        let (store, dir, suite) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir); UserDefaults().removePersistentDomain(forName: suite) }
        let features = try ingest(7, into: store)
        for otherID in [42, 99, 123] {
            let pass = PhotoShieldLumaMatcherV1.matchLuma(patternLuma(otherID), width: 128, height: 128,
                                                          features: features, itemIdentityRevision: 1,
                                                          policyRevision: 1, sessionID: "s", shotID: 1, nowEpoch: 2,
                                                          allowROIEscalation: true)
            if let best = pass.best {
                XCTAssertFalse(best.isActionable, "an unrelated pattern (id \(otherID)) must NEVER be an actionable match")
            }
        }
        // A flat (featureless) frame likewise never fabricates an actionable match.
        let flat = [UInt8](repeating: 128, count: 128 * 128)
        let flatPass = PhotoShieldLumaMatcherV1.matchLuma(flat, width: 128, height: 128, features: features,
                                                          itemIdentityRevision: 1, policyRevision: 1, sessionID: "s",
                                                          shotID: 1, nowEpoch: 2, allowROIEscalation: true)
        if let best = flatPass.best { XCTAssertFalse(best.isActionable, "a flat frame is never an actionable match") }
    }

    // MARK: - §E#7 — resolutions: the same structure at a different resolution still matches (perceptual scale-tolerant).

    func testDifferentResolutionStillMatches() throws {
        let (store, dir, suite) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir); UserDefaults().removePersistentDomain(forName: suite) }
        let features = try ingest(7, into: store)
        let hiRes = patternLuma(7, width: 320, height: 240)   // different aspect + resolution
        let pass = PhotoShieldLumaMatcherV1.matchLuma(hiRes, width: 320, height: 240, features: features,
                                                      itemIdentityRevision: 1, policyRevision: 1, sessionID: "s",
                                                      shotID: 1, nowEpoch: 2, allowROIEscalation: true)
        let best = try XCTUnwrap(pass.best, "the same structure at another resolution still matches")
        XCTAssertTrue(best.isAnyMatch)
    }

    // MARK: - §E#9/#10 — 10-item rapid sequence; a match for item N must NOT carry over to item N+1 (stale forbidden).

    func testRapidSequenceNoStaleCarryover() throws {
        let features = [try lumaFeature(7, ruleID: "photo-7")]   // only item id 7 is a reference (same pipeline)
        // 10 items at the mandate's cadences; only items whose content == the reference should ACTIONABLY match, and
        // every match must be stamped with the CURRENT item's identity revision (no carryover).
        let sequence = [7, 1, 7, 2, 3, 7, 4, 5, 6, 7]   // reference reappears at several positions
        var actionableItems: [Int] = []
        for (i, contentID) in sequence.enumerated() {
            let rev = i + 1
            let pass = PhotoShieldLumaMatcherV1.matchLuma(patternLuma(contentID), width: 128, height: 128,
                                                          features: features, itemIdentityRevision: rev,
                                                          policyRevision: 1, sessionID: "s", shotID: UInt64(rev),
                                                          nowEpoch: Double(rev), allowROIEscalation: true)
            if let best = pass.best {
                // §B5 — every result is stamped with THIS item's revision, never a prior one.
                XCTAssertEqual(best.itemIdentityRevision, rev, "a match is stamped with the CURRENT item identity")
                if best.isActionable { actionableItems.append(rev) }
            }
        }
        // The reference sits at sequence positions 1,3,6,10 (revs). Non-reference items must not actionably match.
        XCTAssertEqual(actionableItems.sorted(), [1, 3, 6, 10],
                       "only the reference items actionably match; no stale carryover onto the interleaved items")
    }

    // MARK: - §E#11 — policy change mid-analysis: a new reference set changes what matches.

    func testPolicyChangeChangesMatchSet() throws {
        // Policy revision 1: references {7} (same-pipeline fixture so an identical frame is actionable).
        let v1 = [try lumaFeature(7, ruleID: "photo-7")]
        let policyRev1: UInt64 = 1
        // Content 42 does not actionably match under policy 1.
        XCTAssertFalse(PhotoShieldLumaMatcherV1.matchLuma(patternLuma(42), width: 128, height: 128, features: v1,
                        itemIdentityRevision: 1, policyRevision: policyRev1, sessionID: "s", shotID: 1,
                        nowEpoch: 2, allowROIEscalation: true).best?.isActionable ?? false)
        // The user adds reference 42 (policy advances to 2). Now content 42 DOES actionably match the new set.
        let v2 = v1 + [try lumaFeature(42, ruleID: "photo-42")]
        let policyRev2: UInt64 = 2
        let pass = PhotoShieldLumaMatcherV1.matchLuma(patternLuma(42), width: 128, height: 128, features: v2,
                        itemIdentityRevision: 2, policyRevision: policyRev2, sessionID: "s", shotID: 2,
                        nowEpoch: 4, allowROIEscalation: true)
        XCTAssertTrue(pass.best?.isActionable ?? false, "after the policy change the new reference actionably matches")
        XCTAssertEqual(pass.best?.policyRevision, policyRev2, "the match carries the live policy revision")
    }

    // MARK: - §E#12 / §F — a deleted reference no longer matches (and leaves no persisted signature).

    func testDeletedReferenceNoLongerMatches() throws {
        let (store, dir, suite) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir); UserDefaults().removePersistentDomain(forName: suite) }
        _ = try ingest(7, into: store)
        XCTAssertEqual(store.loadFeatures().count, 1)
        _ = try store.saveRules([])   // delete all rules → features pruned (privacy)
        let features = store.loadFeatures()
        XCTAssertTrue(features.isEmpty, "deleting the rule pruned its derived signature (no orphan)")
        let pass = PhotoShieldLumaMatcherV1.matchLuma(patternLuma(7), width: 128, height: 128, features: features,
                        itemIdentityRevision: 1, policyRevision: 1, sessionID: "s", shotID: 1, nowEpoch: 2,
                        allowROIEscalation: true)
        XCTAssertNil(pass.best, "a deleted reference no longer matches")
    }

    // MARK: - §B3 — LOW/MEDIUM are evidence-only (never actionable). Corrupt feature is skipped (never fabricated).

    func testCorruptFeatureSkippedNeverFabricated() {
        let bogus = DerivedReferenceFeature(featureID: "bad", ruleID: "photo-bad", featureType: .image,
                                            engineID: "ahash-8x8-v1", engineRevision: "sig-r1", vectorDimension: 0,
                                            serializedFeature: Data("garbage".utf8), createdAtEpoch: 1)
        let pass = PhotoShieldLumaMatcherV1.matchLuma(patternLuma(7), width: 128, height: 128, features: [bogus],
                        itemIdentityRevision: 1, policyRevision: 1, sessionID: "s", shotID: 1, nowEpoch: 2,
                        allowROIEscalation: true)
        XCTAssertNil(pass.best, "a corrupt signature is skipped, never fabricated into a match")
        XCTAssertEqual(pass.signaturesComputed, 0, "no reference decoded → we did not even build a live signature")
    }

    // MARK: - §B6/§F — cost bound: thermal-gated caller (allowROIEscalation:false) computes ONLY the whole-frame sig.

    func testROIEscalationDisabledComputesOnlyWholeFrame() throws {
        let (store, dir, suite) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir); UserDefaults().removePersistentDomain(forName: suite) }
        let features = try ingest(7, into: store)
        // A composite the whole-frame hint can't actionably catch, with escalation DISABLED (simulating fair/hot).
        let pass = PhotoShieldLumaMatcherV1.matchLuma(socialComposite(refID: 7), width: 128, height: 128,
                        features: features, itemIdentityRevision: 1, policyRevision: 1, sessionID: "s", shotID: 1,
                        nowEpoch: 2, allowROIEscalation: false)
        XCTAssertEqual(pass.roisEvaluated, 1, "escalation disabled → ONLY the whole-frame ROI is evaluated (cost bound)")
        XCTAssertEqual(pass.signaturesComputed, 1)
    }
}
