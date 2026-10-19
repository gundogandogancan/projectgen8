import XCTest
@testable import GuardianCore

final class CacheTests: XCTestCase {

    private func sampleDecision(_ id: String) -> AdmissionDecision {
        AdmissionDecision(contentID: .init(id), state: .approve, confidence: .high,
                          reason: .personalAlgorithmThreshold,
                          score: PBSResult(value: 7.9, state: .verifiedFast, provenance: .heuristicV0, formulaVersion: "v"),
                          explanation: "ok", identityState: .i4_verified)
    }

    func testMissThenStoreThenHit() async {
        let clock = ManualClock()
        let cache = LocalAdmissionCache(clock: clock)
        let id = ContentID("c1")
        let miss = await cache.lookup(id, heuristicVersion: "h1", policyVersion: "p1")
        XCTAssertNil(miss)
        await cache.store(CacheEntry(decision: sampleDecision("c1"), heuristicVersion: "h1",
                                     policyVersion: "p1", storedAtNanos: clock.nowNanos))
        let hit = await cache.lookup(id, heuristicVersion: "h1", policyVersion: "p1")
        XCTAssertNotNil(hit)
    }

    func testPolicyVersionMismatchIsMiss() async {
        let clock = ManualClock()
        let cache = LocalAdmissionCache(clock: clock)
        await cache.store(CacheEntry(decision: sampleDecision("c1"), heuristicVersion: "h1",
                                     policyVersion: "p1", storedAtNanos: clock.nowNanos))
        let miss = await cache.lookup(.init("c1"), heuristicVersion: "h1", policyVersion: "p2")
        XCTAssertNil(miss)   // version change invalidates reuse
    }

    func testTTLExpiry() async {
        let clock = ManualClock()
        let cache = LocalAdmissionCache(clock: clock, capacity: 8, ttlNanos: 1_000)
        await cache.store(CacheEntry(decision: sampleDecision("c1"), heuristicVersion: "h1",
                                     policyVersion: "p1", storedAtNanos: clock.nowNanos))
        clock.advance(nanos: 2_000)   // beyond TTL
        let miss = await cache.lookup(.init("c1"), heuristicVersion: "h1", policyVersion: "p1")
        XCTAssertNil(miss)
    }

    func testClear() async {
        let clock = ManualClock()
        let cache = LocalAdmissionCache(clock: clock)
        await cache.store(CacheEntry(decision: sampleDecision("c1"), heuristicVersion: "h1",
                                     policyVersion: "p1", storedAtNanos: clock.nowNanos))
        await cache.clear()
        let count = await cache.count
        XCTAssertEqual(count, 0)
    }

    func testBoundedEviction() async {
        let clock = ManualClock()
        let cache = LocalAdmissionCache(clock: clock, capacity: 2, ttlNanos: .max)
        for i in 0..<5 {
            await cache.store(CacheEntry(decision: sampleDecision("c\(i)"), heuristicVersion: "h1",
                                         policyVersion: "p1", storedAtNanos: clock.nowNanos))
        }
        let count = await cache.count
        XCTAssertLessThanOrEqual(count, 2)   // bounded
    }
}
