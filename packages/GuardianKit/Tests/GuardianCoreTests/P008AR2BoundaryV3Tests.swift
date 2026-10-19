import XCTest
@testable import GuardianCore

final class P008AR2BoundaryV3Tests: XCTestCase {

    // §11 TUNE-only scan: optimize on corpus(seed:0). Prints candidate metrics; the winner is frozen below.
    func testTuneScanExploratory() {
        let tune = BoundaryFixtureGenerator.corpus(seed: 0)
        let candidates: [(String, ContentBoundaryPolicyV3)] = [
            ("default", .init()),
            ("c2r2", .init(minRegionAgreement: 2, confirmFrames: 2, refractoryFrames: 2, dynamicJumpMultiplier: 2.0)),
            ("c1r2", .init(confirmFrames: 1, refractoryFrames: 2, dynamicJumpMultiplier: 1.8)),
            ("sensitive", .init(regionJumpFraction: 0.18, transitionFloor: 0.10, confirmFrames: 1, refractoryFrames: 2, dynamicJumpMultiplier: 1.6)),
            ("frozen", .frozenV3),
        ]
        for (name, p) in candidates {
            let r = BoundaryEvalV3.evaluate(p, fixtures: tune)
            print(String(format: "P008AR2_TUNE %@ P=%.3f R=%.3f F1=%.3f dup/item=%.3f committed=%d true=%d",
                         name, r.overall.precision, r.overall.recall, r.overall.f1, r.overall.duplicatePerItem, r.overall.committed, r.overall.trueBoundaries))
        }
        XCTAssertFalse(tune.isEmpty)
    }

    // §12/§13 — HELD-OUT eval runs ONCE with the FROZEN policy on corpus(seed:1) (unseen derivatives). Predeclared targets.
    func testHeldOutMeetsPredeclaredTargets() {
        let heldOut = BoundaryFixtureGenerator.corpus(seed: 1)
        let r = BoundaryEvalV3.evaluate(.frozenV3, fixtures: heldOut)
        print(String(format: "P008AR2_HELDOUT P=%.3f R=%.3f F1=%.3f dup/item=%.3f committed=%d true=%d",
                     r.overall.precision, r.overall.recall, r.overall.f1, r.overall.duplicatePerItem, r.overall.committed, r.overall.trueBoundaries))
        for (name, m) in r.perSlice.sorted(by: { $0.key < $1.key }) {
            print(String(format: "P008AR2_SLICE %@ P=%.2f R=%.2f tp=%d fp=%d fn=%d dup=%d", name, m.precision, m.recall, m.truePositives, m.falsePositives, m.falseNegatives, m.duplicateCommits))
        }
        // Predeclared engineering acceptance targets (§12) — locked BEFORE this eval.
        XCTAssertGreaterThanOrEqual(r.overall.precision, 0.90, "held-out precision")
        XCTAssertGreaterThanOrEqual(r.overall.recall, 0.85, "held-out recall")
        XCTAssertGreaterThanOrEqual(r.overall.f1, 0.87, "held-out F1")
        XCTAssertLessThanOrEqual(r.overall.duplicatePerItem, 0.10, "held-out duplicate commits per item")
    }

    // §5/§21 — high-motion WITHIN one item must NOT false-boundary (adaptive baseline absorbs sustained motion).
    func testHighMotionSameItemNoFalseBoundary() {
        let acc = BoundaryEvidenceAccumulatorV3(policy: .frozenV3)
        var committed = 0
        var c = 0.1
        for i in 0..<30 {                                   // sustained large center motion, stable chrome, no cut
            c = min(0.95, c + 0.08 * (i % 2 == 0 ? 1 : -1) + 0.02)  // high oscillating motion
            let s = BoundarySignatureFactory.sig(center: c, top: 0.5, bottom: 0.5, left: 0.5, right: 0.5, global: 0.5*c+0.25)
            if acc.process(s).committedNew { committed += 1 }
        }
        XCTAssertLessThanOrEqual(committed, 2, "sustained within-item motion must not spam NEW (got \(committed))")
    }

    // §6 — overlay (single bottom region) is NOT a boundary.
    func testOverlayNotBoundary() {
        let acc = BoundaryEvidenceAccumulatorV3(policy: .frozenV3)
        _ = acc.process(BoundarySignatureFactory.sig(center: 0.5, top: 0.5, bottom: 0.4, left: 0.5, right: 0.5, global: 0.5))
        var committed = 0
        for b in [0.9, 0.9, 0.9, 0.4] {                      // only bottom changes (comments/menu), center stable
            if acc.process(BoundarySignatureFactory.sig(center: 0.5, top: 0.5, bottom: b, left: 0.5, right: 0.5, global: 0.5)).committedNew { committed += 1 }
        }
        XCTAssertEqual(committed, 0)
    }

    // §6/§7 — rapid distinct swipes still commit distinctly (strong jumps break the soft refractory).
    func testRapidSwipeDistinctCommits() {
        let acc = BoundaryEvidenceAccumulatorV3(policy: .frozenV3)
        var committed = 0
        let centers = [0.1, 0.6, 0.95, 0.3]                  // 4 distinct items, short dwell
        for ctr in centers { for _ in 0..<3 { if acc.process(BoundarySignatureFactory.sig(center: ctr, top: 0.5, bottom: 0.5, left: 0.5, right: 0.5, global: 0.5*ctr+0.25)).committedNew { committed += 1 } } }
        XCTAssertGreaterThanOrEqual(committed, 4, "rapid distinct swipes must each commit (got \(committed))")
    }

    // §4 — multi-region distances separate chrome from content.
    func testMultiRegionDistances() {
        let a = BoundarySignatureFactory.sig(center: 0.2, top: 0.9, bottom: 0.1, left: 0.5, right: 0.5, global: 0.4)
        let b = BoundarySignatureFactory.sig(center: 0.8, top: 0.9, bottom: 0.1, left: 0.5, right: 0.5, global: 0.6)  // only center changed
        let d = b.distances(to: a)
        XCTAssertGreaterThan(d.center, 0.4); XCTAssertEqual(d.top, 0.0, accuracy: 0.02); XCTAssertEqual(d.bottom, 0.0, accuracy: 0.02)
    }

    func testPolicyRevisionV3() { XCTAssertEqual(ContentBoundaryPolicyV3.frozenV3.revision, "boundary-policy-v3") }
}
