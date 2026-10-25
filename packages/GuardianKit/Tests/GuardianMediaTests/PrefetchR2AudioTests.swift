//
//  PrefetchR2CacheHitTests.swift — PREFETCH R2 (§A1/§B1/§B3/§C) proof.
//
//  The A1 CACHE-HIT regression. It drives the EXACT production sequence the app's ControlledReelsModel.move(by:)
//  drives: prefetch N+1 → advance the brain cursor (a plain navigation move) → revalidate the cached decision for
//  the now-current reel. A COUNTING evidence provider counts every gatherEvidence call (our decode+OCR proxy). The
//  A1 fix is proven by the counter: a normal A→B swipe reuses the prefetch with ZERO new gather calls (before the
//  fix, advance(by:) bumped evaluationGeneration and the token missed → a needless re-gather). The correct action is
//  applied and a cache HIT is recorded. There is no app-target XCTest host, so we cannot instantiate the SwiftUI
//  @Observable model here; instead we exercise the coordinator + brain path it calls verbatim — the cache logic
//  under test is identical production code (ControlledReelsModel.move(by:) is a thin wrapper over exactly this).
//
import XCTest
@testable import GuardianMedia
import GuardianCore
#if canImport(AVFoundation)
import AVFoundation

final class PrefetchR2CacheHitTests: XCTestCase {

    // MARK: Helpers

    private func makeStore() -> (store: PersonalShieldSharedStoreV1, dir: URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gen8-r2-\(UUID().uuidString)")
        let suite = UserDefaults(suiteName: "r2.tests.\(UUID().uuidString)")!
        return (PersonalShieldSharedStoreV1(directory: dir, suite: suite, sharedContainerActive: true), dir)
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }
    private func rule(_ id: String, _ label: String, _ action: ShieldAction) -> ShieldRuleV2 {
        ShieldRuleV2(ruleID: id, inputType: .textExact, rawUserLabel: label, locale: "en", action: action,
                     createdAtEpoch: 1, updatedAtEpoch: 1)
    }
    private func item(_ id: String) -> ReelItemV1 { ReelItemV1(id: id, title: "t", url: URL(fileURLWithPath: "/tmp/\(id).mp4")) }

    /// A COUNTING evidence provider: every gatherEvidence(Adaptive) call bumps `gathers` (our decode+OCR proxy). The
    /// A1 test asserts the counter does NOT move on a cache-hit swipe (zero re-decode/re-OCR). Deterministic text.
    private final class CountingProvider: ReelsEvidenceProviding, @unchecked Sendable {
        private let lock = NSLock()
        private var _gathers = 0
        let byID: [String: String]   // contentID (file basename sans ext) → OCR text
        init(byID: [String: String]) { self.byID = byID }
        var gathers: Int { lock.lock(); defer { lock.unlock() }; return _gathers }
        func gatherEvidence(url: URL, metadataTitle: String, firstFrameSeconds: [Double], languages: [String]) async -> ReelsEvidenceV1 {
            await gatherEvidenceAdaptive(url: url, metadataTitle: metadataTitle, firstFrameSeconds: firstFrameSeconds,
                                         languages: languages, thermal: .nominal, earlyStopProbe: nil)
        }
        func gatherEvidenceAdaptive(url: URL, metadataTitle: String, firstFrameSeconds: [Double], languages: [String],
                                    thermal: ReelsThermalBucketV1, earlyStopProbe: ReelsSampleMatchProbe?) async -> ReelsEvidenceV1 {
            lock.lock(); _gathers += 1; lock.unlock()
            let key = url.deletingPathExtension().lastPathComponent
            let text = byID[key] ?? ""
            let rec = ReelsTimedEvidenceV1(timestampSeconds: 0.2, modality: .visualOCR,
                                           ocrStatus: text.isEmpty ? .ranNoText : .ran, text: text)
            return ReelsEvidenceProviderV1.fuse(ocrText: text, metadataText: "clip", frameCoverage: 1,
                                                ocrExecuted: true, languages: ["en"], timedRecords: [rec])
        }
    }

    // MARK: §A1 / acceptance #1 + #2 — a NORMAL A→B swipe is a REAL cache-hit (zero re-decode/re-OCR).

    /// Drives the production coordinator+brain sequence ControlledReelsModel.move(by:) drives: while A is current we
    /// prefetch N+1 (=B); then advance the cursor to B (a plain navigation move — the exact thing that USED to bump
    /// evaluationGeneration and falsely invalidate the cache); then revalidate. The A1 fix: the token keys on
    /// evidenceEpoch (NOT the navigation generation), so the plain move leaves the token equal → CACHE HIT → zero new
    /// gather calls, and B's correct HIDE action is applied from the pre-exposure decision.
    @MainActor
    func testNormalSwipeIsRealCacheHitWithZeroReDecode() async throws {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try store.saveRules([rule("u-1", "spoiler", .hideIfControlled)])
        // B contains the matching term; A is clean. Both resolve via the counting provider.
        let provider = CountingProvider(byID: ["reel-a": "calm cooking", "reel-b": "big spoiler ahead"])
        let items = [item("reel-a"), item("reel-b")]
        let brain = ReelsPlayerModelV1(items: items, store: store, evidenceProvider: provider, clock: { 10 })
        let coord = PrefetchCoordinatorV1(sessionID: "s", brain: brain, items: items)

        // A is current (index 0). Evaluate A on-demand (1 gather), then prefetch B (the N+1).
        _ = await brain.evaluateGuarded(items[0])
        XCTAssertEqual(provider.gathers, 1, "A evaluated once on-demand")
        coord.prefetchNext(after: 0)
        try await waitUntil { coord.prefetchCompleted == 1 }   // let the .utility prefetch Task complete
        let afterPrefetch = provider.gathers
        XCTAssertEqual(afterPrefetch, 2, "B prefetched exactly once (its N+1 pre-evaluation)")

        // NORMAL SWIPE A→B: exactly what move(by:+1) does — advance the brain cursor (bumps evaluationGeneration, the
        // navigation authority) then revalidate the cached decision for the now-current reel B.
        _ = brain.advance(by: 1)
        XCTAssertEqual(brain.currentIndex, 1)
        guard let cached = coord.revalidatedDecision(for: items[1], atIndex: 1) else {
            return XCTFail("A1 DEFECT: a valid prefetch for B was falsely invalidated by a plain navigation move")
        }
        // THE A1 PROOF: the cache HIT reused B's decision with ZERO new decode/OCR.
        XCTAssertEqual(provider.gathers, afterPrefetch, "a cache-hit swipe must NOT re-decode/re-OCR (zero new gathers)")
        XCTAssertEqual(coord.cacheHits, 1, "a real consumed cache-hit is recorded")
        XCTAssertEqual(cached.state, .hidden, "B's correct pre-computed HIDE is applied")
        XCTAssertEqual(cached.appliedAction, .hideIfControlled, "the correct action is applied from the cache")
        if case .hide = cached.intent {} else { XCTFail("the applied intent must be the real HIDE") }
    }

    // MARK: §A1 — a POLICY change still correctly MISSES (the fix never over-caches a genuinely stale decision).

    @MainActor
    func testPolicyChangeInvalidatesPrefetchHonestly() async throws {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try store.saveRules([rule("u-1", "spoiler", .hideIfControlled)])
        let provider = CountingProvider(byID: ["reel-a": "calm", "reel-b": "big spoiler ahead"])
        let items = [item("reel-a"), item("reel-b")]
        let brain = ReelsPlayerModelV1(items: items, store: store, evidenceProvider: provider, clock: { 10 })
        let coord = PrefetchCoordinatorV1(sessionID: "s", brain: brain, items: items)
        _ = await brain.evaluateGuarded(items[0])
        coord.prefetchNext(after: 0)
        try await waitUntil { coord.prefetchCompleted == 1 }
        // A REAL rule-set change bumps policyRevision AND the evidence epoch → the token for B no longer matches.
        _ = try store.saveRules([rule("u-1", "spoiler", .hideIfControlled), rule("u-2", "promo", .warn)])
        _ = brain.pollPolicyRevisionAndInvalidateIfChanged()
        _ = brain.advance(by: 1)
        let hit = coord.revalidatedDecision(for: items[1], atIndex: 1)
        XCTAssertNil(hit, "a real policy change must invalidate the prefetch (honest MISS, acceptance #7)")
        XCTAssertGreaterThanOrEqual(coord.cacheMisses, 1, "the miss is counted honestly")
    }

    // MARK: §B1 — an OLD in-flight prefetch task completing cannot overwrite a NEWER target's cache.

    @MainActor
    func testOldPrefetchCannotClobberNewerTarget() async throws {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try store.saveRules([rule("u-1", "spoiler", .hideIfControlled)])
        let provider = CountingProvider(byID: ["reel-a": "calm", "reel-b": "spoiler", "reel-c": "calm"])
        let items = [item("reel-a"), item("reel-b"), item("reel-c")]
        let brain = ReelsPlayerModelV1(items: items, store: store, evidenceProvider: provider, clock: { 10 })
        let coord = PrefetchCoordinatorV1(sessionID: "s", brain: brain, items: items)
        _ = await brain.evaluateGuarded(items[0])
        coord.prefetchNext(after: 0)       // targets B
        coord.cancel(reason: "user-swipe") // a foreground move cancels it (C4) before it can cache
        _ = brain.advance(by: 1)           // now at B
        coord.prefetchNext(after: 1)       // targets C
        try await waitUntil { coord.prefetchCompleted >= 1 }
        // The only cached entry must be for C (the current target), never a late B leftover.
        _ = brain.advance(by: 1)           // now at C
        let hit = coord.revalidatedDecision(for: items[2], atIndex: 2)
        XCTAssertEqual(hit?.contentID, "reel-c", "an old B prefetch can never clobber the newer C target (B1)")
    }

    // MARK: §B3 — the prefetch STATE enum publishes a real lifecycle; the chip refreshes only on real completion.

    @MainActor
    func testPrefetchStateReflectsRealLifecycle() async throws {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        _ = try store.saveRules([rule("u-1", "spoiler", .hideIfControlled)])
        let provider = CountingProvider(byID: ["reel-a": "calm", "reel-b": "spoiler"])
        let items = [item("reel-a"), item("reel-b")]
        let brain = ReelsPlayerModelV1(items: items, store: store, evidenceProvider: provider, clock: { 10 })
        let coord = PrefetchCoordinatorV1(sessionID: "s", brain: brain, items: items)
        XCTAssertEqual(coord.state, .notStarted, "nothing prefetched yet")
        _ = await brain.evaluateGuarded(items[0])
        coord.prefetchNext(after: 0)
        // Immediately after kickoff the state is EVALUATING (work generated, not yet complete).
        XCTAssertEqual(coord.state, .evaluating, "a kicked-off prefetch is EVALUATING until it really completes (B3)")
        try await waitUntil { coord.prefetchCompleted == 1 }
        XCTAssertEqual(coord.state, .ready, "READY only after the task REALLY completed (B3 chip refresh)")
        XCTAssertTrue(coord.revalidatedDecisionIsCachedPeek(forNextAfter: 0), "the ready peek reflects the real cache")
    }

    // MARK: §C — the content-head hash distinguishes same-name/size/second files with different bytes (collision guard).

    func testContentFingerprintUsesContentHashNotJustMetadata() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gen8-fp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { cleanup(dir) }
        let a = dir.appendingPathComponent("same.bin")
        let b = dir.appendingPathComponent("same.bin")   // same path reused after a rewrite
        try Data(repeating: 0x41, count: 4096).write(to: a)
        let fpA = PrefetchTokenV1.assetFingerprint(url: a)
        // Overwrite with DIFFERENT bytes of the SAME size (a name+size collision the old fingerprint could not detect).
        try Data(repeating: 0x42, count: 4096).write(to: b)
        let fpB = PrefetchTokenV1.assetFingerprint(url: b)
        XCTAssertNotEqual(fpA, fpB, "different bytes at the same path/size must yield a DIFFERENT fingerprint (C collision guard)")
    }

    // MARK: Helpers

    /// Poll a condition on the MainActor until true or a timeout (prefetch Tasks are .utility/async). Honest bounded
    /// wait — fails the test if the condition never holds, never a fabricated sleep-and-assume.
    @MainActor
    private func waitUntil(timeoutSeconds: Double = 5.0, _ cond: @MainActor () -> Bool) async throws {
        let start = Date()
        while !cond() {
            if Date().timeIntervalSince(start) > timeoutSeconds { XCTFail("waitUntil timed out"); return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
#endif
