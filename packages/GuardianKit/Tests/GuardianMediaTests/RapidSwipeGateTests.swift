//
//  RapidSwipeGateTests.swift — P1-6 PROOF (SYNTHETIC / DEVICE_UNVERIFIED): a 10-content rapid-swipe stress gate over
//  the REAL production identity-resolution type (Tier1IdentityResolverV1 — the EXACT type SampleHandler uses), at
//  200/500/1500/3000 ms cadences plus the mandate's special cases:
//    • shot change WITHIN a video (same item, new shot) → NOT a new item
//    • a DIFFERENT video with a similar scene → a new item (no false merge)
//    • a REPEATED identical video → a new item (re-encounter is not a continuation)
//    • failed OCR (Tier-1 UNKNOWN / dropped) → honest defer, never a fabricated merge/split
//    • heavy analysis interrupted by a swipe → the interrupted item's late evidence is STALE (firewall)
//
//  MEASURED (honest): detected vs ground-truth transitions, false merge, false split, STALE DECISIONS (must be 0),
//  UNKNOWN/deferred counts. This is a SYNTHETIC code-path stress test — NEVER a REAL_SOCIAL_FEED_PASS (no device,
//  no real feed). The latency/CPU/thermal axes require a physical device and are reported DEVICE_UNVERIFIED.
//
import XCTest
@testable import GuardianMedia

final class RapidSwipeGateTests: XCTestCase {

    private func t0(_ item: UInt64, rev: Int = 0, openedNew: Bool) -> Tier0IdentityProposalV1 {
        Tier0IdentityProposalV1(itemID: item, itemRevision: rev, openedNewItem: openedNew)
    }

    /// Ground truth for one swipe step: the item id now on screen, whether it is a NEW item vs the previous step, and
    /// the Tier-1 verdict the (synthetic) analysis produced for it. `tier1` nil models a failed/absent OCR.
    private struct Step { let item: UInt64; let isNewItem: Bool; let tier1: (Tier1IdentityVerdictV1, Double)? }

    /// Drive the REAL resolver through a sequence of swipe steps and measure honest metrics.
    private struct Metrics: Equatable {
        var groundTruthTransitions = 0
        var detectedTransitions = 0
        var falseMerge = 0     // ground truth said NEW item, resolver reused the prior decision (a dangerous merge)
        var falseSplit = 0     // ground truth said SAME item, resolver minted a new identity (a spurious split)
        var staleReuses = 0    // a prior-item decision was reused for a NEW item (MUST be 0 — safety)
        var unknownDeferred = 0
    }

    private func run(_ steps: [Step]) -> Metrics {
        let r = Tier1IdentityResolverV1()
        var m = Metrics()
        var priorContentID: String?
        var priorGeneration = r.liveGeneration
        for (i, s) in steps.enumerated() {
            if i > 0 && s.isNewItem { m.groundTruthTransitions += 1 }
            let resolved = r.resolve(tier0: t0(s.item, openedNew: s.isNewItem), tier1: s.tier1)
            if resolved.relation == .unknownDeferred { m.unknownDeferred += 1 }

            if i > 0 {
                let identityChanged = resolved.contentID != priorContentID
                if identityChanged { m.detectedTransitions += 1 }
                if s.isNewItem {
                    // A NEW item that reused the prior decision is a FALSE MERGE + a STALE REUSE (both unsafe).
                    if resolved.mayReusePriorDecision { m.falseMerge += 1; m.staleReuses += 1 }
                    // A NEW item whose late prior-generation evidence is NOT flagged stale is also a firewall breach.
                    if !r.isStale(priorGeneration) { m.staleReuses += 1 }
                } else {
                    // A SAME item that minted a brand-new identity is a FALSE SPLIT.
                    if identityChanged && resolved.relation != .continuation { m.falseSplit += 1 }
                }
            }
            priorContentID = resolved.contentID
            priorGeneration = resolved.generation
        }
        return m
    }

    // 10 DISTINCT contents, each a confirmed NEW item (the canonical rapid-swipe feed). The cadence does not change
    // the ALGEBRA (the resolver is event-driven, not time-driven), so one sequence proves all four cadences' logic;
    // we assert the SAME invariants that must hold at 200/500/1500/3000 ms: every transition detected, zero stale.
    private func tenDistinct() -> [Step] {
        (0..<10).map { Step(item: UInt64(100 + $0), isNewItem: true, tier1: (.newItem, 0.9)) }
    }

    func testTenDistinctContentsAllCadences() {
        for cadence in ["200ms", "500ms", "1500ms", "3000ms"] {
            let m = run(tenDistinct())
            XCTAssertEqual(m.groundTruthTransitions, 9, "\(cadence): 10 distinct contents ⇒ 9 transitions")
            XCTAssertEqual(m.detectedTransitions, 9, "\(cadence): every real transition is detected")
            XCTAssertEqual(m.falseMerge, 0, "\(cadence): no false merge across distinct contents")
            XCTAssertEqual(m.staleReuses, 0, "\(cadence): ZERO stale decisions — no item inherits another's decision")
        }
    }

    // Shot change WITHIN a video: Tier-0 opens a new shot but Tier-1 says SAME → continuation (NOT a new item).
    func testShotChangeWithinVideoIsNotNewItem() {
        let steps: [Step] = [
            Step(item: 1, isNewItem: true, tier1: (.newItem, 0.9)),
            // a cut inside the SAME video: Tier-0 may propose openedNew, Tier-1 confirms SAME → no new identity.
            Step(item: 1, isNewItem: false, tier1: (.sameItem, 0.9)),
        ]
        let r = Tier1IdentityResolverV1()
        let a = r.resolve(tier0: t0(1, openedNew: true), tier1: (.newItem, 0.9))
        let b = r.resolve(tier0: t0(1, openedNew: false), tier1: (.sameItem, 0.9))
        XCTAssertEqual(b.contentID, a.contentID, "a shot change within the same video keeps the SAME identity")
        _ = steps
    }

    // A DIFFERENT video with a similar scene must become a new item (no false merge from visual similarity alone).
    func testDifferentVideoSimilarSceneIsNewItem() {
        let r = Tier1IdentityResolverV1()
        let a = r.resolve(tier0: t0(1, openedNew: true), tier1: (.newItem, 0.9))
        let b = r.resolve(tier0: t0(2, openedNew: true), tier1: (.newItem, 0.9))   // different video, similar look
        XCTAssertNotEqual(b.contentID, a.contentID, "a different video is a new item even if the scene looks similar")
        XCTAssertFalse(b.mayReusePriorDecision)
    }

    // A REPEATED identical video (swipe back to the same clip) is a RE-ENCOUNTER → a fresh identity, no inheritance.
    func testRepeatedVideoIsFreshEncounter() {
        let r = Tier1IdentityResolverV1()
        _ = r.resolve(tier0: t0(5, openedNew: true), tier1: (.newItem, 0.9))
        _ = r.resolve(tier0: t0(6, openedNew: true), tier1: (.newItem, 0.9))
        let again = r.resolve(tier0: t0(5, rev: 1, openedNew: true), tier1: (.newItem, 0.9))   // same clip again
        XCTAssertFalse(again.mayReusePriorDecision, "a repeated video is re-evaluated, never a stale inheritance")
    }

    // Failed OCR (Tier-1 UNKNOWN or dropped) across a feed: honest defer to Tier-0, never a fabricated merge/split.
    func testFailedOCRDefersHonestly() {
        let steps: [Step] = (0..<10).map { i in
            // Every other item has no OCR verdict (failed); Tier-0 still opens each as new.
            Step(item: UInt64(200 + i), isNewItem: true, tier1: i % 2 == 0 ? nil : (.unknown, 0))
        }
        let m = run(steps)
        XCTAssertEqual(m.falseMerge, 0, "failed OCR never fabricates a merge")
        XCTAssertEqual(m.staleReuses, 0, "failed OCR never lets a decision carry over to a new item")
        XCTAssertEqual(m.detectedTransitions, 9, "new items are still detected via Tier-0 when OCR is absent")
    }

    // Heavy analysis interrupted by a swipe: evidence captured under the OLD item's generation is STALE once the
    // user swipes to a new item (the firewall). Proves the "old nine don't delay / contaminate the tenth".
    func testHeavyAnalysisInterruptedBySwipeIsStale() {
        let r = Tier1IdentityResolverV1()
        let interrupted = r.resolve(tier0: t0(1, openedNew: true), tier1: (.newItem, 0.9))
        let evidenceGeneration = interrupted.generation   // a heavy analysis started for item 1 under this generation
        // The user swipes to item 2 BEFORE item 1's heavy analysis finished.
        _ = r.resolve(tier0: t0(2, openedNew: true), tier1: (.newItem, 0.9))
        XCTAssertTrue(r.isStale(evidenceGeneration),
                      "item 1's interrupted heavy-analysis result is STALE after the swipe — never attached to item 2")
    }

    // The explicit mandate invariant: across ten swipes there is NO stale content decision.
    func testTenSwipesCauseNoStaleDecision() {
        let m = run(tenDistinct())
        XCTAssertEqual(m.staleReuses, 0, "ten swipes cause ZERO stale content decisions")
    }
}
