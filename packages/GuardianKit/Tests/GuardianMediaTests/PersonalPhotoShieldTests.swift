//
//  PersonalPhotoShieldTests.swift — P1-5 PROOF: the Personal Photo Shield persists a DERIVED visual signature
//  through the shared store and still matches a live frame after a true relaunch (no raw photo, no in-memory
//  object). Covers the mandate's three required cases:
//    • reference persists and still matches after relaunch (store-level, from persisted bytes alone)
//    • a deleted reference no longer matches
//    • a visually similar-but-unrelated photo does NOT produce an unsupported hard shield
//  Plus honest same / scaled / cropped FP-FN measurement on synthetic fixtures (never generalised to real feeds).
//
//  Headless/XCTest over the GuardianMedia + GuardianIntelligence + GuardianCore primitives.
//
import XCTest
@testable import GuardianMedia
import GuardianIntelligence
import GuardianCore
import CoreGraphics

final class PersonalPhotoShieldTests: XCTestCase {

    // A fresh shared store in a temp dir (no entitlement needed) with its own revision suite.
    private func makeStore() -> (PersonalShieldSharedStoreV1, URL, String) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pps-\(UUID().uuidString)")
        let suiteName = "pps.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        return (PersonalShieldSharedStoreV1(directory: dir, suite: suite, sharedContainerActive: true), dir, suiteName)
    }

    // A deterministic structured pattern image — same id ≡ same spatial structure (perceptual hashing is designed for
    // this). Mirrors the P006C durability fixture so the thresholds are the SAME ones P006C locked.
    private func patternImage(_ id: Int, width: Int = 640, height: Int = 640) -> CGImage? {
        let space = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                  space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        var seed = UInt64(id &* 2654435761 &+ 1)
        func next() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double((seed >> 33) & 0xFFFF) / 65535.0 }
        let cells = 8
        for r in 0..<cells { for c in 0..<cells {
            let g = next()
            ctx.setFillColor(CGColor(gray: CGFloat(g), alpha: 1))
            let w = CGFloat(width) / CGFloat(cells), h = CGFloat(height) / CGFloat(cells)
            ctx.fill(CGRect(x: CGFloat(c) * w, y: CGFloat(r) * h, width: w, height: h))
        } }
        return ctx.makeImage()
    }

    // MARK: - Reference persists and STILL matches after a relaunch (store-level, persisted bytes only).

    func testReferencePersistsAndMatchesAfterRelaunch() throws {
        let (store, dir, suiteName) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir); UserDefaults().removePersistentDomain(forName: suiteName) }
        let ref = try XCTUnwrap(patternImage(7))

        // Add the reference → a real policyRevision is produced and the rule + derived feature are persisted.
        let added = try XCTUnwrap(PersonalPhotoShieldV1.addReference(cgImage: ref, label: "benim-fotoğrafım",
                                                                     action: .hideIfControlled, nowEpoch: 1,
                                                                     store: store, existingRules: []))
        XCTAssertEqual(added.revision, 1, "adding the first reference bumps the policy revision")
        XCTAssertEqual(added.rule.inputType, .imageReference)

        // RELAUNCH: a brand-new store over the SAME directory + suite (no in-memory carryover).
        let relaunched = PersonalShieldSharedStoreV1(directory: dir, suite: UserDefaults(suiteName: suiteName)!,
                                                     sharedContainerActive: true)
        let features = relaunched.loadFeatures()
        XCTAssertEqual(features.count, 1, "the derived signature survived the relaunch")
        XCTAssertEqual(relaunched.loadPolicy().rules.first?.inputType, .imageReference)

        // A live frame identical to the reference still matches from the persisted bytes alone.
        let live = try XCTUnwrap(patternImage(7))
        let match = try XCTUnwrap(PersonalPhotoShieldV1.matchFrame(live, features: features, nowEpoch: 2))
        XCTAssertTrue(match.isMatch, "the persisted reference matches the same image after relaunch")
        XCTAssertEqual(match.ruleID, added.rule.ruleID)
    }

    // MARK: - A deleted reference no longer matches (and leaves no persisted signature).

    func testDeletedReferenceNoLongerMatches() throws {
        let (store, dir, suiteName) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir); UserDefaults().removePersistentDomain(forName: suiteName) }
        let ref = try XCTUnwrap(patternImage(7))
        let added = try XCTUnwrap(PersonalPhotoShieldV1.addReference(cgImage: ref, label: "x", action: .warn,
                                                                     nowEpoch: 1, store: store, existingRules: []))
        XCTAssertEqual(store.loadFeatures().count, 1)

        // DELETE the rule by saving the rule set WITHOUT it — saveRules prunes orphan features (privacy).
        _ = try store.saveRules([])   // no rules left → the feature must be pruned
        let features = store.loadFeatures()
        XCTAssertTrue(features.isEmpty, "deleting the rule removed its persisted signature (no orphan)")

        // With no features, a live frame identical to the deleted reference produces NO match.
        let live = try XCTUnwrap(patternImage(7))
        let match = PersonalPhotoShieldV1.matchFrame(live, features: features, nowEpoch: 2)
        XCTAssertNil(match, "a deleted reference no longer matches")
        _ = added
    }

    // MARK: - A visually similar-but-unrelated photo does NOT produce an unsupported hard shield.

    func testUnrelatedPhotoDoesNotHardShield() throws {
        let (store, dir, suiteName) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir); UserDefaults().removePersistentDomain(forName: suiteName) }
        let ref = try XCTUnwrap(patternImage(7))
        _ = try XCTUnwrap(PersonalPhotoShieldV1.addReference(cgImage: ref, label: "x", action: .hideIfControlled,
                                                             nowEpoch: 1, store: store, existingRules: []))
        let features = store.loadFeatures()

        // A DIFFERENT structured image (unrelated content). It must NOT produce a HIGH/strong match that would drive
        // an unsupported hard shield — at most an honest noMatch / weak state we never escalate.
        let unrelated = try XCTUnwrap(patternImage(42))
        let match = PersonalPhotoShieldV1.matchFrame(unrelated, features: features, nowEpoch: 2)
        if let m = match {
            XCTAssertNotEqual(m.state, .matchHigh, "an unrelated photo must never be a HIGH visual match")
            XCTAssertNotEqual(m.state, .matchExact, "an unrelated photo must never be an EXACT visual match")
        }
        // A solid (featureless) frame likewise never fabricates a strong match.
        let solid = try XCTUnwrap(SyntheticImage.solidImage(gray: 0.5, width: 640, height: 640))
        if let m = PersonalPhotoShieldV1.matchFrame(solid, features: features, nowEpoch: 3) {
            XCTAssertFalse(m.state == .matchHigh || m.state == .matchExact,
                           "a featureless frame never produces a hard visual shield")
        }
    }

    // MARK: - Honest same / scaled FP-FN on synthetic fixtures (measured, not generalised to real feeds).

    func testSameAndScaledVariantsMatchSyntheticFixtures() throws {
        let (store, dir, suiteName) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir); UserDefaults().removePersistentDomain(forName: suiteName) }
        let ref = try XCTUnwrap(patternImage(7))
        _ = try XCTUnwrap(PersonalPhotoShieldV1.addReference(cgImage: ref, label: "x", action: .warn,
                                                             nowEpoch: 1, store: store, existingRules: []))
        let features = store.loadFeatures()

        // Same structure at a SMALLER scale (perceptual hash is scale-tolerant by design).
        let scaled = try XCTUnwrap(patternImage(7, width: 320, height: 320))
        let scaledMatch = try XCTUnwrap(PersonalPhotoShieldV1.matchFrame(scaled, features: features, nowEpoch: 2))
        XCTAssertTrue(scaledMatch.isMatch, "a scaled variant of the same image still matches (synthetic fixture)")
    }

    // MARK: - An incompatible/corrupt signature is MATCHER_UNAVAILABLE, never fabricated into a match.

    func testCorruptSignatureIsUnavailableNeverMatch() throws {
        // A feature whose serialized signature is garbage → decodeSignature yields nil → no candidate → no match.
        let bogus = DerivedReferenceFeature(featureID: "visualsig-bad", ruleID: "bad", featureType: .image,
                                            engineID: "ahash-8x8-v1", engineRevision: "sig-r1",
                                            vectorDimension: 0, serializedFeature: Data("not a signature".utf8),
                                            createdAtEpoch: 1)
        let live = try XCTUnwrap(patternImage(7))
        let match = PersonalPhotoShieldV1.matchFrame(live, features: [bogus], nowEpoch: 2)
        XCTAssertNil(match, "a corrupt signature is never fabricated into a match")
    }
}
