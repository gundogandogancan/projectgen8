import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import GuardianCore
@testable import GuardianIntelligence

// 006C — FUNCTIONAL durability: the rule must still work after the process (all in-memory matcher objects) dies.
final class P006CVisualDurabilityTests: XCTestCase {

    private func tempDir() -> URL { URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gen8-visdur-\(UUID().uuidString)") }
    private func pngRoundTrip(_ image: CGImage) -> CGImage? {
        guard let data = SyntheticImage.pngData(image),
              let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    /// Deterministic structured pattern (an 8×8 grayscale grid) — models a real logo/photo with spatial structure,
    /// which is what perceptual hashing is designed for. Same `id` → same structure at any size; different `id` → different.
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

    // Debug: print distances so thresholds are empirically grounded, not guessed.
    func testSignatureDistanceDebug() throws {
        let eng = VisualSignatureEngine()
        guard let a = patternImage(7), let aSame = patternImage(7),
              let aSmall = patternImage(7, width: 320, height: 320),
              let b = patternImage(42), let solid = SyntheticImage.solidImage(gray: 0.5) else { XCTFail("img"); return }
        let cmp = VisualSignatureComparator()
        func d(_ x: CGImage, _ y: CGImage) -> VisualSignatureComparator.Distances? {
            guard let sx = eng.signature(from: x, ruleID: "r", nowEpoch: 0), let sy = eng.signature(from: y, ruleID: "r", nowEpoch: 0) else { return nil }
            return cmp.compare(sx, sy).distances
        }
        print("SIGDBG same=\(d(a, aSame)!) resized=\(d(a, aSmall)!) reencode=\(d(a, pngRoundTrip(a)!)!) other=\(d(a, b)!) solid=\(d(a, solid)!)")
    }

    // §5 — true teardown/relaunch boundary. NO in-memory object survives; reference comes only from persisted bytes.
    func testFunctionalRelaunchMatch() throws {
        let dir = tempDir()
        let ruleID = "img-rule"
        guard let refImage = patternImage(7) else { XCTFail("img"); return }

        // --- Session 1: ingest + persist, then let everything go out of scope. ---
        do {
            let ingestor = ShieldImageReferenceIngestor()
            guard let out = ingestor.ingest(cgImage: refImage, ruleID: ruleID, nowEpoch: 1) else { XCTFail("ingest"); return }
            var snap = ShieldStoreSnapshot(rules: [ShieldRuleV2(ruleID: ruleID, inputType: .imageReference,
                                                                rawUserLabel: "acme logo", referenceFeatureIDs: [out.feature.featureID],
                                                                action: .hideIfControlled, createdAtEpoch: 1)],
                                           features: [out.feature])
            try FileBackedPersonalShieldStore(directory: dir).save(snap)
            snap.rules.removeAll()   // scrub local copy; disk is the only survivor
        }

        // --- Session 2 ("relaunch"): brand-new store + index + matcher. Reference reconstructed from disk only. ---
        let mgr = ShieldStoreManager(store: FileBackedPersonalShieldStore(directory: dir))
        let (snapshot, index) = try mgr.loadAndRebuild()
        XCTAssertEqual(snapshot.rules.first?.functionalState(nowEpoch: 2), .active)   // durable + compatible → ACTIVE
        XCTAssertFalse(index.shortlist(envelope: {
            var e = ContentObservationEnvelope(); e.structuredText = [TextSource(origin: .structured, text: "acme logo")]; return e
        }(), nowEpoch: 2).isEmpty)

        guard let feature = try mgr.feature(for: ruleID),
              let persistedSig = ShieldVisualReferenceMatcher.decodeSignature(feature) else { XCTFail("no persisted sig"); return }
        let matcher = ShieldVisualReferenceMatcher()

        // Positive: the same reference content now matches purely from persisted derived state.
        guard let liveSame = patternImage(7) else { XCTFail("img"); return }
        let mSame = matcher.match(frame: liveSame, reference: persistedSig)
        XCTAssertTrue([.matchHigh, .matchMedium].contains(mSame.state), "post-relaunch same → match; got \(mSame.state)")

        // Negative control: unrelated image does not match after relaunch.
        guard let other = patternImage(42) else { XCTFail("img"); return }
        XCTAssertFalse(matcher.match(frame: other, reference: persistedSig).state.isMatch)
        try? FileBackedPersonalShieldStore(directory: dir).wipe()
    }

    // §6 — variant robustness that is ACTUALLY demonstrated: lossless re-encode + resize. (Crop/brightness: see docs.)
    func testVariantsDemonstrated() throws {
        let eng = VisualSignatureEngine(); let cmp = VisualSignatureComparator()
        guard let a = patternImage(7),
              let reenc = pngRoundTrip(patternImage(7)!),
              let resized = patternImage(7, width: 400, height: 400) else { XCTFail("img"); return }
        func state(_ x: CGImage, _ y: CGImage) -> ShieldMatchState {
            cmp.compare(eng.signature(from: x, ruleID: "r", nowEpoch: 0)!, eng.signature(from: y, ruleID: "r", nowEpoch: 0)!).state
        }
        XCTAssertTrue([.matchHigh, .matchMedium].contains(state(a, reenc)), "lossless re-encode should still match")
        XCTAssertTrue([.matchHigh, .matchMedium, .matchLow].contains(state(a, resized)), "resized should still match (possibly weaker)")
    }

    // §7 — store-level incompatible revision → rule becomes REFERENCE_REAUTHORING_REQUIRED, not a stale match.
    func testStoreMarksReauthoringOnIncompatibleRevision() throws {
        let dir = tempDir(); let ruleID = "img2"
        guard let ref = patternImage(11, width: 320, height: 320) else { XCTFail("img"); return }
        let staleIngestor = ShieldImageReferenceIngestor(engine: VisualSignatureEngine(engineRevision: "sig-r0"))
        guard let out = staleIngestor.ingest(cgImage: ref, ruleID: ruleID, nowEpoch: 1) else { XCTFail("ingest"); return }
        try FileBackedPersonalShieldStore(directory: dir).save(
            ShieldStoreSnapshot(rules: [ShieldRuleV2(ruleID: ruleID, inputType: .imageReference, rawUserLabel: "logo",
                                                     referenceFeatureIDs: [out.feature.featureID], createdAtEpoch: 1)],
                                features: [out.feature]))
        let (snap, _) = try ShieldStoreManager(store: FileBackedPersonalShieldStore(directory: dir)).loadAndRebuild() // current sig-r1
        XCTAssertEqual(snap.rules.first?.functionalState(nowEpoch: 2), .referenceReauthoringRequired)
        try? FileBackedPersonalShieldStore(directory: dir).wipe()
    }

    // §13 — deleting a rule removes its derived signature from the store (no orphan sensitive data).
    func testDeletingRuleRemovesDerivedSignature() throws {
        let dir = tempDir(); let ruleID = "imgDel"
        guard let ref = patternImage(13, width: 320, height: 320) else { XCTFail("img"); return }
        guard let out = ShieldImageReferenceIngestor().ingest(cgImage: ref, ruleID: ruleID, nowEpoch: 1) else { XCTFail("ingest"); return }
        let store = FileBackedPersonalShieldStore(directory: dir)
        var snap = ShieldStoreSnapshot(rules: [ShieldRuleV2(ruleID: ruleID, inputType: .imageReference, rawUserLabel: "del",
                                                            referenceFeatureIDs: [out.feature.featureID], createdAtEpoch: 1)],
                                       features: [out.feature])
        try store.save(snap)
        snap = try store.load(); XCTAssertEqual(snap.features.count, 1)
        snap.deleteRule(ruleID)
        try store.save(snap)
        let reloaded = try FileBackedPersonalShieldStore(directory: dir).load()
        XCTAssertTrue(reloaded.rules.isEmpty)
        XCTAssertTrue(reloaded.features.isEmpty)   // derived signature gone with the rule
        try? store.wipe()
    }

    // §9/§10 — startup load+rebuild runs OFF the MainActor (persistence/index setup must not block UI).
    func testStartupRunsOffMainActor() async throws {
        let dir = tempDir()
        let rules = (0..<200).map { ShieldRuleV2(ruleID: "r\($0)", inputType: .textExact, rawUserLabel: "t\($0)", createdAtEpoch: 1) }
        try FileBackedPersonalShieldStore(directory: dir).save(ShieldStoreSnapshot(rules: rules))
        let built: Int = await Task.detached(priority: .utility) {
            let (_, index) = (try? ShieldStoreManager(store: FileBackedPersonalShieldStore(directory: dir)).loadAndRebuild()) ?? (ShieldStoreSnapshot(), ShieldIndex())
            return index.count
        }.value
        XCTAssertEqual(built, 200)   // completed entirely on a background executor
        try? FileBackedPersonalShieldStore(directory: dir).wipe()
    }
}
