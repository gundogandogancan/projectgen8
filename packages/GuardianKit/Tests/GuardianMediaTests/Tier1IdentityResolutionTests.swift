//
//  Tier1IdentityResolutionTests.swift — P1 PRODUCT PROOF: the Tier-1 verdict RESOLVES the Guardian-bound
//  identity (before evidence binding), no decision/evidence transfers across different content, and honest
//  UNKNOWN. Pure/headless — exercises Tier1IdentityResolverV1 directly (the exact type SampleHandler uses).
//
import XCTest
@testable import GuardianMedia

final class Tier1IdentityResolutionTests: XCTestCase {

    private func t0(_ item: UInt64, rev: Int = 0, openedNew: Bool) -> Tier0IdentityProposalV1 {
        Tier0IdentityProposalV1(itemID: item, itemRevision: rev, openedNewItem: openedNew)
    }

    // (i) Tier-1 verdict CHANGES the Guardian-bound identity: Tier-0 says SAME (did not open a new item), but
    // Tier-1 says NEW with confidence → a FRESH identity id is minted and prior-decision reuse is forbidden.
    func testTier1NewOverridesTier0Same() {
        let r = Tier1IdentityResolverV1()
        // Seed a first item so there is a "prior" identity to (not) inherit.
        let first = r.resolve(tier0: t0(1, openedNew: true), tier1: (.newItem, 0.8))
        XCTAssertFalse(first.mayReusePriorDecision)

        // Tier-0 proposes SAME (openedNewItem=false, same item id); Tier-1 overrides → NEW.
        let over = r.resolve(tier0: t0(1, openedNew: false), tier1: (.newItem, 0.8))
        XCTAssertEqual(over.relation, .newContradiction)
        XCTAssertFalse(over.mayReusePriorDecision, "a Tier-1 NEW over a Tier-0 SAME must force fresh evaluation")
        XCTAssertNotEqual(over.contentID, first.contentID, "the Guardian-bound identity id must CHANGE")
        XCTAssertGreaterThan(over.generation.value, first.generation.value, "a new identity advances the generation")
        XCTAssertEqual(r.overrodeTier0Count, 1)
    }

    // (ii) NO evidence/decision transfer between two DIFFERENT videos: two confirmed-new items produce distinct
    // content ids and neither is allowed to reuse the other's decision.
    func testNoDecisionTransferBetweenTwoDifferentItems() {
        let r = Tier1IdentityResolverV1()
        let a = r.resolve(tier0: t0(10, openedNew: true), tier1: (.newItem, 0.9))     // video A
        let b = r.resolve(tier0: t0(11, openedNew: true), tier1: (.newItem, 0.9))     // video B
        XCTAssertNotEqual(a.contentID, b.contentID, "two different videos must bind to DIFFERENT identities")
        XCTAssertFalse(a.mayReusePriorDecision)
        XCTAssertFalse(b.mayReusePriorDecision, "video B must NEVER inherit video A's (possibly safe) decision")
        XCTAssertGreaterThan(b.generation.value, a.generation.value)
    }

    // (ii-b) The STALE-EVIDENCE FIREWALL: an async result started under an earlier generation is stale once the
    // identity advances. Guarantees late OCR from video A cannot attach to video B.
    func testStaleEvidenceFirewall() {
        let r = Tier1IdentityResolverV1()
        let a = r.resolve(tier0: t0(20, openedNew: true), tier1: (.newItem, 0.9))
        let capturedUnder = a.generation                 // OCR for A started under A's generation
        _ = r.resolve(tier0: t0(21, openedNew: true), tier1: (.newItem, 0.9))   // item advances to B
        XCTAssertTrue(r.isStale(capturedUnder), "A's late OCR must be dropped once we've moved to B")
        XCTAssertFalse(r.isStale(r.liveGeneration), "a result stamped with the live generation is NOT stale")
    }

    // (iii) UNKNOWN honesty: Tier-1 UNKNOWN (or dropped) DEFERS to Tier-0 — it neither forces a split nor a merge.
    func testUnknownDefersToTier0() {
        let r = Tier1IdentityResolverV1()
        _ = r.resolve(tier0: t0(30, openedNew: true), tier1: (.newItem, 0.9))   // seed item A

        // Tier-0 keeps the same item; Tier-1 abstains → continuation of A (no new identity, but reuse allowed only
        // because BOTH tiers kept the item). Honest: UNKNOWN never fabricated a new split.
        let cont = r.resolve(tier0: t0(30, openedNew: false), tier1: (.unknown, 0))
        XCTAssertEqual(cont.relation, .continuation)

        // Tier-0 opens a new item; Tier-1 abstains (or was dropped: nil) → defers to Tier-0's NEW, fresh identity,
        // and reuse is forbidden (a new item is never a safe inheritance even when Tier-1 is silent).
        let deferredNew = r.resolve(tier0: t0(31, openedNew: true), tier1: nil)
        XCTAssertFalse(deferredNew.mayReusePriorDecision)
        XCTAssertNotEqual(deferredNew.contentID, cont.contentID)
    }

    // (iii-b) A strong Tier-1 SAME against a Tier-0 NEW is a CONTRADICTION → isolate + re-evaluate, never merge
    // back into the prior item (which would risk inheriting its safe/protective state onto different content).
    func testStrongSameVsNewContradictionIsolates() {
        let r = Tier1IdentityResolverV1(strongContradictionMinConfidence: 0.60)
        _ = r.resolve(tier0: t0(40, openedNew: true), tier1: (.newItem, 0.9))     // seed A
        let contra = r.resolve(tier0: t0(41, openedNew: true), tier1: (.sameItem, 0.75)) // T0 NEW vs T1 SAME(strong)
        XCTAssertEqual(contra.relation, .newContradiction)
        XCTAssertFalse(contra.mayReusePriorDecision, "a strong contradiction must re-evaluate, not inherit")
        XCTAssertEqual(r.contradictionCount, 1)
    }

    // A LOW-confidence Tier-1 SAME against a Tier-0 NEW is NOT forced into a contradiction — honest demotion to a
    // deferral (we don't manufacture certainty from a weak signal).
    func testWeakSameVsNewIsDeferredNotContradiction() {
        let r = Tier1IdentityResolverV1(strongContradictionMinConfidence: 0.60)
        _ = r.resolve(tier0: t0(50, openedNew: true), tier1: (.newItem, 0.9))
        let weak = r.resolve(tier0: t0(51, openedNew: true), tier1: (.sameItem, 0.3))
        XCTAssertNotEqual(weak.relation, .newContradiction)
        XCTAssertFalse(weak.mayReusePriorDecision, "a Tier-0 new is still a new item → no inheritance")
    }

    // MARK: A1 — SOURCE-CORRELATED evidence acceptance (the fixed defect)

    // (A1-i) THE BUG, FIXED: OCR captured from the SAME shot that mints a NEW identity THIS frame must be ACCEPTED
    // (the old generation-ordering firewall wrongly dropped it). We stamp the token with the shot BEFORE resolve,
    // resolve advances the generation, and `accepts` must still return true because the source shot matches.
    func testSameFrameOCRForFreshIdentityIsAccepted() {
        let r = Tier1IdentityResolverV1()
        let shot: UInt64 = 1001
        // OCR for THIS frame is captured under the pre-resolution generation (exactly as SampleHandler does).
        let token = CaptureTokenV1(shotID: shot, generation: r.liveGeneration)
        let resolved = r.resolve(tier0: t0(70, openedNew: true), tier1: (.newItem, 0.9), shotID: shot)
        XCTAssertFalse(resolved.mayReusePriorDecision)
        XCTAssertTrue(r.accepts(token), "same-shot OCR for the id minted this frame MUST bind (A1 fix)")
        XCTAssertFalse(r.rejects(token))
        XCTAssertEqual(r.bindingShotID, shot)
    }

    // (A1-ii) Genuinely LATE OCR from an EARLIER shot (video A) must be REJECTED once the identity is bound to a
    // LATER shot (video B) — the cross-item firewall still holds.
    func testLateOCRFromEarlierShotIsRejected() {
        let r = Tier1IdentityResolverV1()
        let shotA: UInt64 = 2001, shotB: UInt64 = 2002
        let tokenA = CaptureTokenV1(shotID: shotA, generation: r.liveGeneration)
        _ = r.resolve(tier0: t0(80, openedNew: true), tier1: (.newItem, 0.9), shotID: shotA)   // bound to A
        XCTAssertTrue(r.accepts(tokenA), "A's OCR is valid while A is bound")
        _ = r.resolve(tier0: t0(81, openedNew: true), tier1: (.newItem, 0.9), shotID: shotB)   // now bound to B
        XCTAssertTrue(r.rejects(tokenA), "A's late OCR must NOT bind to B (cross-item firewall)")
        let tokenB = CaptureTokenV1(shotID: shotB, generation: r.liveGeneration)
        XCTAssertTrue(r.accepts(tokenB), "B's own-shot OCR is valid")
    }

    // (A1-iii) Session restart: a brand-new resolver binds a fresh shot; an old session's token (different shot) is
    // rejected — proving a stale result from before a stop/restart cannot be accepted.
    func testSessionRestartRejectsOldShotToken() {
        let old = Tier1IdentityResolverV1()
        let oldShot: UInt64 = 3001
        let oldToken = CaptureTokenV1(shotID: oldShot, generation: old.liveGeneration)
        _ = old.resolve(tier0: t0(90, openedNew: true), tier1: (.newItem, 0.9), shotID: oldShot)

        // Fresh session (new resolver) binds a different shot.
        let fresh = Tier1IdentityResolverV1()
        _ = fresh.resolve(tier0: t0(90, openedNew: true), tier1: (.newItem, 0.9), shotID: 4001)
        XCTAssertTrue(fresh.rejects(oldToken), "a prior session's result must not be accepted after restart")
    }

    // MARK: B3 — identity-level reason codes are bound to the SAME resolved identity (no drift)

    func testIdentityReasonCodesAreHonest() {
        let r = Tier1IdentityResolverV1()
        let confirmed = r.resolve(tier0: t0(100, openedNew: true), tier1: (.newItem, 0.9), shotID: 10)
        XCTAssertEqual(confirmed.reasonCode, .contentChangedReset, "a confirmed new item = content changed/reset")

        let contra = r.resolve(tier0: t0(100, openedNew: false), tier1: (.newItem, 0.9), shotID: 11)
        XCTAssertEqual(contra.relation, .newContradiction)
        XCTAssertEqual(contra.reasonCode, .newIdentityUnconfirmed, "a contradiction is an unconfirmed new identity")

        let cont = r.resolve(tier0: t0(100, openedNew: false), tier1: (.sameItem, 0.9), shotID: 11)
        XCTAssertEqual(cont.relation, .continuation)
        XCTAssertEqual(cont.reasonCode, .observingNoDecisionYet)
    }
}
