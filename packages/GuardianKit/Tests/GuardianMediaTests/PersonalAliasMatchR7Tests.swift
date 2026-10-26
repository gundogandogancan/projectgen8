//
//  PersonalAliasMatchR7Tests.swift — R7 §5: SEMANTIC ENTITY & ALIAS V1 (narrow, honest).
//   • alias/canonical word-boundary matches (TR+EN, case/locale-insensitive)
//   • unrelated same-topic text does NOT match (co-occurrence / topical ≠ direct mention)
//   • substring-inside-a-word does NOT match (the frozen substring matcher's weakness this fixes)
//   • delete/revoke removes all aliases (revoked → matches nothing)
//   • provenance carries WHICH alias matched; the ladder classifies it DIRECT_REFERENCE
//   • ambiguity: too-short / common-word terms are WARNED at entry
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class PersonalAliasMatchR7Tests: XCTestCase {

    private func ref(canonical: String = "Ahmet Yılmaz", aliases: [String] = ["Koca Ahmet"], revoked: Bool = false)
        -> PersonalAliasReferenceV1 {
        PersonalAliasReferenceV1(ruleID: "r1", canonicalName: canonical, aliases: aliases, revoked: revoked)
    }

    // MARK: direct mention matches (canonical + alias)

    func testCanonicalNameMatchesWordBoundary() {
        let m = PersonalAliasMatchV1.match(reference: ref(), in: "bugün Ahmet Yılmaz bir açıklama yaptı")
        XCTAssertTrue(m.matched)
        XCTAssertEqual(m.matchedTerm, "Ahmet Yılmaz")
        XCTAssertTrue(m.isCanonical)
    }

    func testUserProvidedAliasMatches() {
        let m = PersonalAliasMatchV1.match(reference: ref(), in: "herkes KOCA AHMET diyor")
        XCTAssertTrue(m.matched)
        XCTAssertEqual(m.matchedTerm, "Koca Ahmet")
        XCTAssertFalse(m.isCanonical, "an alias hit is not the canonical name")
    }

    func testCaseAndDiacriticInsensitiveTR() {
        // "yilmaz" (no diacritic, lowercase) should still match "Yılmaz".
        let m = PersonalAliasMatchV1.match(reference: ref(), in: "ahmet yilmaz konuştu")
        XCTAssertTrue(m.matched)
    }

    func testEnglishAliasMatches() {
        let r = PersonalAliasReferenceV1(ruleID: "r2", canonicalName: "John Smith", aliases: ["JS", "Johnny"])
        XCTAssertTrue(PersonalAliasMatchV1.match(reference: r, in: "and then Johnny said hello").matched)
    }

    // MARK: honest NON-matches — co-occurrence / topical / substring are NOT direct mentions

    func testUnrelatedSameTopicDoesNotMatch() {
        // Same topic (politics / a meeting) but NO direct mention of the named reference → NO match.
        let m = PersonalAliasMatchV1.match(reference: ref(),
            in: "bugün mecliste bütçe görüşmeleri yapıldı, birçok vekil katıldı")
        XCTAssertFalse(m.matched, "co-occurrence / same-topic must never be a direct mention")
    }

    func testSubstringInsideWordDoesNotMatch() {
        // A short alias "Ali" must NOT match inside "kalitesi" / "Ali̇ağa" — word boundary only.
        let r = PersonalAliasReferenceV1(ruleID: "r3", canonicalName: "Ali", aliases: [])
        XCTAssertFalse(PersonalAliasMatchV1.match(reference: r, in: "ürünün kalitesi çok iyi").matched,
                       "substring inside a longer word is not a direct mention (frozen-matcher weakness fixed)")
        // But a real whole-word mention DOES match.
        XCTAssertTrue(PersonalAliasMatchV1.match(reference: r, in: "Ali geldi").matched)
    }

    func testEmptyAndMissingTextNoMatch() {
        XCTAssertFalse(PersonalAliasMatchV1.match(reference: ref(), in: nil).matched)
        XCTAssertFalse(PersonalAliasMatchV1.match(reference: ref(), in: "").matched)
    }

    // MARK: delete / revoke removes all aliases

    func testRevokedReferenceMatchesNothing() {
        let revoked = ref(revoked: true)
        XCTAssertFalse(PersonalAliasMatchV1.match(reference: revoked, in: "Ahmet Yılmaz ve Koca Ahmet").matched,
                       "a revoked/deleted reference must match nothing")
    }

    // MARK: provenance → ladder classification is DIRECT_REFERENCE (actionable)

    func testMatchClassifiesAsDirectReferenceActionable() {
        let m = PersonalAliasMatchV1.match(reference: ref(), in: "Koca Ahmet geldi")
        let cls = PersonalRelationLadderV1.classifyAliasMatch(m)
        XCTAssertEqual(cls.relation, .directReference)
        XCTAssertTrue(cls.actionable, "a direct mention of a user-named term is actionable in V1")
        XCTAssertEqual(cls.modalityRaw, "TEXT")
    }

    func testNonMatchClassifiesUnknownNotActionable() {
        let m = PersonalAliasMatchV1.match(reference: ref(), in: "bambaşka bir konu")
        let cls = PersonalRelationLadderV1.classifyAliasMatch(m)
        XCTAssertEqual(cls.relation, .unknown)
        XCTAssertFalse(cls.actionable)
    }

    // MARK: ambiguity handled honestly (warn at entry)

    func testTooShortAliasIsWarned() {
        XCTAssertEqual(PersonalAliasMatchV1.ambiguity(of: "Al"), .tooShort)
        XCTAssertEqual(PersonalAliasMatchV1.ambiguity(of: "Zx"), .tooShort)   // short, not a common word
    }

    func testCommonWordAliasIsWarned() {
        XCTAssertEqual(PersonalAliasMatchV1.ambiguity(of: "ve"), .commonWord)
        XCTAssertEqual(PersonalAliasMatchV1.ambiguity(of: "the"), .commonWord)
    }

    func testNormalNameIsOk() {
        XCTAssertEqual(PersonalAliasMatchV1.ambiguity(of: "Ahmet"), .ok)
        XCTAssertEqual(PersonalAliasMatchV1.ambiguity(of: "AKP"), .ok)   // 3 chars, not a common word
    }

    // MARK: no auto-discovery — only user-typed terms match (a related-but-unlisted name does NOT)

    func testRelatedButUnlistedNameDoesNotMatch() {
        // The user named "Ahmet Yılmaz" + "Koca Ahmet". A different person "Mehmet Yılmaz" sharing a surname is NOT a
        // match (no auto alias discovery, no same-surname inference).
        let m = PersonalAliasMatchV1.match(reference: ref(), in: "Mehmet Yılmaz bir açıklama yaptı")
        XCTAssertFalse(m.matched, "a same-surname different person must never auto-match (no discovery)")
    }
}
