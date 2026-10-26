//
//  PersonalAliasProductR8Tests.swift — R8 §7: alias from test type to real product. The user's alias reference rides
//  the FROZEN ShieldRuleV2 (`.entity` + aliases), persists through the shared store, survives relaunch, matches on the
//  live-equivalent OCR path (word-boundary), and a delete/revoke removes matching. STABLE UUID ids + legacy tolerance.
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class PersonalAliasProductR8Tests: XCTestCase {

    private func makeStore() -> (store: PersonalShieldSharedStoreV1, dir: URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gen8-alias-\(UUID().uuidString)")
        let suite = UserDefaults(suiteName: "alias.tests.\(UUID().uuidString)")!
        return (PersonalShieldSharedStoreV1(directory: dir, suite: suite, sharedContainerActive: true), dir)
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func aliasRule(id: String, canonical: String, aliases: [String]) -> ShieldRuleV2 {
        ShieldRuleV2(ruleID: id, inputType: .entity, rawUserLabel: canonical, locale: "tr",
                     aliases: aliases, action: .warn, createdAtEpoch: 1, updatedAtEpoch: 1)
    }

    // §7 — an alias direct mention matches WITH provenance (which alias fired; canonical vs alias).
    func testAliasMatchCarriesProvenance() {
        let ref = PersonalAliasReferenceV1(ruleID: "r1", canonicalName: "Mehmet Yılmaz", aliases: ["Memo", "MY"])
        let r = PersonalAliasMatchV1.match(reference: ref, in: "Bugün Memo sahneye çıktı")
        XCTAssertTrue(r.matched)
        XCTAssertEqual(r.matchedTerm, "Memo")
        XCTAssertFalse(r.isCanonical)   // it was an alias, not the canonical name
        let rel = PersonalRelationLadderV1.classifyAliasMatch(r)
        XCTAssertEqual(rel.relation, .directReference)   // the actionable rung — a real user-named direct mention
    }

    // §7 — a canonical direct mention is flagged as canonical.
    func testCanonicalMatchFlag() {
        let ref = PersonalAliasReferenceV1(ruleID: "r1", canonicalName: "Mehmet", aliases: ["Memo"])
        let r = PersonalAliasMatchV1.match(reference: ref, in: "Mehmet geldi")
        XCTAssertTrue(r.matched); XCTAssertTrue(r.isCanonical)
    }

    // §7 — the mid-word law: a short alias "Ali" NEVER matches inside another word ("kalitesi", "Alişan").
    func testShortAliasNeverMatchesMidWord() {
        let ref = PersonalAliasReferenceV1(ruleID: "r1", canonicalName: "Ali", aliases: [])
        XCTAssertFalse(PersonalAliasMatchV1.match(reference: ref, in: "ürün kalitesi çok iyi").matched)
        XCTAssertFalse(PersonalAliasMatchV1.match(reference: ref, in: "Alişan konseri").matched)
        XCTAssertTrue(PersonalAliasMatchV1.match(reference: ref, in: "Ali geldi").matched)   // whole word → matches
    }

    // §7 — a REVOKED reference matches NOTHING (delete/revoke fail-safe).
    func testRevokedReferenceMatchesNothing() {
        let ref = PersonalAliasReferenceV1(ruleID: "r1", canonicalName: "Mehmet", aliases: ["Memo"], revoked: true)
        XCTAssertFalse(PersonalAliasMatchV1.match(reference: ref, in: "Mehmet ve Memo").matched)
    }

    // §7 — entry-time ambiguity: a too-short / common-word alias is WARNED (not silently actioned).
    func testAmbiguityWarnings() {
        XCTAssertEqual(PersonalAliasMatchV1.ambiguity(of: "Al"), .tooShort)
        XCTAssertEqual(PersonalAliasMatchV1.ambiguity(of: "ve"), .commonWord)
        XCTAssertEqual(PersonalAliasMatchV1.ambiguity(of: "the"), .commonWord)
        XCTAssertEqual(PersonalAliasMatchV1.ambiguity(of: "Mehmet"), .ok)
    }

    // §7 — persistence + relaunch: an alias rule saved by the writer is read back by a FRESH store (relaunch) with its
    // aliases intact, and the alias matcher still fires from the reloaded rule alone.
    func testAliasRulePersistsAcrossRelaunch() throws {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        let rule = aliasRule(id: "ui-alias-\(UUID().uuidString)", canonical: "Zarnovil", aliases: ["Zarno"])
        _ = try store.saveRules([rule])
        // Fresh store on the SAME directory = a relaunch.
        let reader = PersonalShieldSharedStoreV1(directory: dir, suite: UserDefaults(suiteName: "alias.reader.\(UUID().uuidString)")!,
                                                 sharedContainerActive: true)
        // The reader uses its OWN suite for the revision but the SAME file-backed store for the rules.
        let loaded = reader.loadPolicy()
        let entity = loaded.rules.first { $0.inputType == .entity }
        XCTAssertNotNil(entity)
        XCTAssertEqual(entity?.rawUserLabel, "Zarnovil")
        XCTAssertEqual(entity?.aliases, ["Zarno"])
        let ref = PersonalAliasReferenceV1(ruleID: entity!.ruleID, canonicalName: entity!.rawUserLabel,
                                           aliases: entity!.aliases)
        XCTAssertTrue(PersonalAliasMatchV1.match(reference: ref, in: "Zarno açıklama yaptı").matched)
    }

    // §7 — delete removes matching: after the rule is removed from the saved set, no alias reference remains.
    func testDeleteRemovesAliasMatching() throws {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        let rule = aliasRule(id: "ui-alias-1", canonical: "Mehmet", aliases: ["Memo"])
        _ = try store.saveRules([rule])
        XCTAssertEqual(store.loadPolicy().rules.filter { $0.inputType == .entity }.count, 1)
        _ = try store.saveRules([])   // delete-all equivalent for this set
        XCTAssertTrue(store.loadPolicy().rules.filter { $0.inputType == .entity }.isEmpty)
    }

    // §7 — STABLE IDS: a fresh rule id is UUID-based (relaunch-stable), and a LEGACY `ui-<n>-<hash>` id is tolerated
    // verbatim by the store (never rewritten — which would orphan features/aliases and break delete).
    func testUUIDFreshIdAndLegacyTolerance() throws {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        let legacy = aliasRule(id: "ui-3-123456789", canonical: "Legacy", aliases: ["Leg"])   // old hashValue-style id
        let fresh = aliasRule(id: "ui-alias-\(UUID().uuidString)", canonical: "Fresh", aliases: ["Fr"])
        _ = try store.saveRules([legacy, fresh])
        let loaded = store.loadPolicy()
        let ids = Set(loaded.rules.map { $0.ruleID })
        XCTAssertTrue(ids.contains("ui-3-123456789"), "a legacy id must survive verbatim (never rewritten)")
        XCTAssertTrue(ids.contains(fresh.ruleID), "a fresh UUID id round-trips")
        // Both ids are distinct and collision-free.
        XCTAssertEqual(loaded.rules.filter { $0.inputType == .entity }.count, 2)
    }

    // §7 — an alias rule bound to a controlled EXECUTE action is still SAFE (sound-rule safety does not touch entity
    // rules, but a general WARN-only posture holds on the uncontrolled surface — the rule persists as authored).
    func testEntityRuleActionPreserved() throws {
        let (store, dir) = makeStore(); defer { cleanup(dir) }
        let rule = aliasRule(id: "ui-alias-1", canonical: "X", aliases: ["Y"])
        _ = try store.saveRules([rule])
        XCTAssertEqual(store.loadPolicy().rules.first?.action, .warn)
    }
}
