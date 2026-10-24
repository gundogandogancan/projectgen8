//
//  Tier1TextSaltTests.swift — P2(c) PRIVACY PROOF: the per-session salt gives cross-session UNLINKABILITY while
//  preserving in-session comparison. We do NOT claim "non-reconstructive" (FNV-1a is non-crypto over a small
//  space); we claim exactly what the salt buys and test THAT.
//
import XCTest
@testable import GuardianMedia

final class Tier1TextSaltTests: XCTestCase {

    // In-session: one salt → the same text yields the SAME hashes, so comparison still works.
    func testSameSaltSameHashes() {
        let salt = Tier1TextSaltV1(value: 0xDEADBEEF)
        let a = Tier1TextSimilarityV1.trigramHashes("COSMOS GALAXY STARS", salt: salt)
        let b = Tier1TextSimilarityV1.trigramHashes("COSMOS GALAXY STARS", salt: salt)
        XCTAssertEqual(a, b)
        XCTAssertFalse(a.isEmpty)
    }

    // Cross-session: different salts → DIFFERENT hash sets for the SAME text. A set cannot be correlated or
    // replayed across sessions. (Overlap is essentially nil for distinct 64-bit-seeded streams.)
    func testDifferentSaltUnlinkable() {
        let s1 = Tier1TextSaltV1(value: 1)
        let s2 = Tier1TextSaltV1(value: 2)
        let a = Tier1TextSimilarityV1.trigramHashes("PASTA KITCHEN RECIPE PART ONE", salt: s1)
        let b = Tier1TextSimilarityV1.trigramHashes("PASTA KITCHEN RECIPE PART ONE", salt: s2)
        XCTAssertNotEqual(a, b, "the same text in two sessions must not produce the same hash set")
        // Jaccard across sessions collapses to ~0 (no stable fingerprint survives the salt).
        XCTAssertLessThan(Tier1TextSimilarityV1.jaccard(a, b), 0.05)
    }

    // Within a session (one salt), DIFFERENT texts still separate (the similarity signal is intact).
    func testInSessionSeparationIntact() {
        let salt = Tier1TextSaltV1.random()
        let a = Tier1TextSimilarityV1.trigramHashes("COSMOS GALAXY STARS PART ONE", salt: salt)
        let b = Tier1TextSimilarityV1.trigramHashes("COSMOS GALAXY STARS PART TWO", salt: salt)
        let c = Tier1TextSimilarityV1.trigramHashes("PASTA KITCHEN RECIPE PART ONE", salt: salt)
        XCTAssertGreaterThan(Tier1TextSimilarityV1.jaccard(a, b), 0.5, "same item, different part → similar")
        XCTAssertLessThan(Tier1TextSimilarityV1.jaccard(a, c), 0.35, "different items → dissimilar")
    }

    // Two fresh trackers (= two sessions) get independent random salts (overwhelmingly different).
    func testTrackersGetIndependentSalts() {
        let t1 = Tier1ItemIdentityV1(policy: .v1)
        let t2 = Tier1ItemIdentityV1(policy: .v1)
        XCTAssertNotEqual(t1.textSalt, t2.textSalt)
    }
}
