import XCTest
@testable import GuardianCore

// PROMPT 008A-R1 — the ONE canonical ContentBoundaryEngineV2 (shared by lab + extension). Proves motion-within-item is
// NOT committed as NEW, rapid real swipes ARE, overlays don't boundary, dwell/debounce bound burst-spam.
final class P008AR1BoundaryTests: XCTestCase {

    private func f(_ sig: UInt64, _ layout: UInt64, _ tokens: Set<String> = []) -> BoundaryFrameInput {
        .init(signature: .init(bits: sig), layoutSignature: layout, topTextTokens: tokens)
    }

    // §5 — high-motion WITHIN one Reel: perceptual drifts every frame, layout stable → must NOT commit dozens of NEW.
    func testHighMotionSameContentNotSpammed() {
        let e = ContentBoundaryEngineV2(policy: .init(), profile: .extensionFast)
        var committed = 0
        var bits: UInt64 = 0x0F0F_0F0F_0F0F_0F0F
        for i in 0..<40 {                                   // 40 frames of gradual motion, SAME layout 0xAAAA
            bits = bits ^ (UInt64(1) << UInt64(i % 20))     // drift a bit each frame
            if e.process(f(bits, 0xAAAA)).committedNew { committed += 1 }
        }
        XCTAssertEqual(committed, 1, "only the initial content commits; gradual motion must not spam NEW (got \(committed))")
    }

    // §5 — rapid real swipes: each swipe = layout jump + big perceptual change → must still commit (bounded by debounce).
    func testRapidSwipeStillDetected() {
        var committed = 0
        // Maximally-distinct items (consecutive hamming ≥ 32) + layout jumps = real swipes.
        let items: [(UInt64, UInt64)] = [(0x0000_0000_0000_0000, 0xAAAA), (0xFFFF_FFFF_FFFF_FFFF, 0x5555),
                                         (0xAAAA_AAAA_AAAA_AAAA, 0xF0F0), (0x5555_5555_5555_5555, 0x0F0F)]
        let e2 = ContentBoundaryEngineV2(policy: .init(perceptualNew: 18, layoutNew: 8, settleFrames: 1, debounceFramesBetweenNew: 3), profile: .extensionFast)
        for (sig, layout) in items { for _ in 0..<5 { if e2.process(f(sig, layout)).committedNew { committed += 1 } } }
        XCTAssertEqual(committed, items.count, "each distinct swiped item commits exactly once (got \(committed))")
    }

    // §5 — comments/UI overlay on the SAME content (small perceptual change, same layout) → not a boundary.
    func testOverlayIsNotABoundary() {
        let e = ContentBoundaryEngineV2(policy: .init(), profile: .extensionFast)
        _ = e.process(f(0x1234_5678, 0xAAAA))
        var committed = 0
        for _ in 0..<10 { if e.process(f(0x1234_5679, 0xAAAA)).committedNew { committed += 1 } }   // tiny delta, same layout
        XCTAssertEqual(committed, 0)
    }

    // §4 — policy revision is carried on every event (no hidden magic constants).
    func testPolicyRevisionLogged() {
        let e = ContentBoundaryEngineV2(policy: .init(revision: "boundary-policy-v2"), profile: .extensionFast)
        XCTAssertEqual(e.process(f(0x1, 0x1)).policyRevision, "boundary-policy-v2")
    }

    // §13 — engine-benchmark on a 3-item moving sequence: committed count ≈ true items (material reduction vs raw-frame spam).
    func testEngineBenchmarkMaterialReduction() {
        let e = ContentBoundaryEngineV2(policy: .init(settleFrames: 1, debounceFramesBetweenNew: 4), profile: .extensionFast)
        var frames: [BoundaryFrameInput] = []; var labels: [Bool] = []
        // 3 items × 10 frames each; within-item gradual motion; layout jump at each item start.
        let layouts: [UInt64] = [0xAAAA, 0x5555, 0xF0F0]
        let bases: [UInt64] = [0x0000_0000_0000_0000, 0xFFFF_FFFF_FFFF_FFFF, 0xAAAA_AAAA_AAAA_AAAA]  // inter-item hamming ≥32
        for item in 0..<3 {
            for k in 0..<10 {
                let sig = bases[item] ^ (UInt64(k) & 0x3)   // tiny within-item drift (≤2 bits), huge between items
                frames.append(f(sig, layouts[item])); labels.append(k == 0)
            }
        }
        let r = BoundaryEngineBenchmark.run(e, frames: frames, labeledIsNewBoundary: labels)
        XCTAssertEqual(r.trueBoundaries, 3)
        XCTAssertLessThanOrEqual(r.detectedBoundaries, 4, "committed NEW ≈ 3 items, NOT ~30 frames (material reduction)")
        XCTAssertLessThanOrEqual(r.missedBoundaries, 1)
    }

    // §3 — extension profile has OCR off (budget); app profile has it on. Same engine, explicit capability difference.
    func testCapabilityProfilesExplicit() {
        XCTAssertFalse(BoundaryCapabilityProfile.extensionFast.ocrEnabled)
        XCTAssertTrue(BoundaryCapabilityProfile.appFast.ocrEnabled)
    }
}
