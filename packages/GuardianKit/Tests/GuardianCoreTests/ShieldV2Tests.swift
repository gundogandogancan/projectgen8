import XCTest
@testable import GuardianCore

final class ShieldV2Tests: XCTestCase {

    private func env(text: String = "", ocr: String = "", transcript: String = "", sounds: [String] = [],
                     langs: [String] = ["en"], contentID: String? = nil) -> ContentObservationEnvelope {
        var e = ContentObservationEnvelope()
        e.contentID = contentID.map { ContentID($0) }
        e.surfaceCapabilityTier = "C3"
        if !text.isEmpty { e.structuredText = [TextSource(origin: .structured, text: text)] }
        if !ocr.isEmpty { e.ocrText = [TextSource(origin: .ocr, text: ocr)] }
        if !transcript.isEmpty { e.transcript = [TextSource(origin: .transcript, text: transcript)] }
        e.soundEvents = sounds
        e.languageSignals = langs
        return e
    }

    func testRuleIsVersionedAndCodable() throws {
        let r = ShieldRuleV2(ruleID: "r1", inputType: .textExact, rawUserLabel: "spoiler", action: .hideIfControlled)
        XCTAssertEqual(r.version, "shield-rule-v2")
        let data = try JSONEncoder().encode(r)
        XCTAssertEqual(r, try JSONDecoder().decode(ShieldRuleV2.self, from: data))
    }

    func testExactTextMatchAcrossSources() {
        let r = ShieldRuleV2(ruleID: "r1", inputType: .textExact, rawUserLabel: "earthquake")
        let m = ExactTextMatcher()
        XCTAssertEqual(m.match(rule: r, envelope: env(text: "Big EARTHQUAKE today")).state, .matchExact)
        XCTAssertEqual(m.match(rule: r, envelope: env(ocr: "earthquake warning")).reason, .ocr)
        XCTAssertEqual(m.match(rule: r, envelope: env(transcript: "an earthquake struck")).reason, .transcript)
        XCTAssertEqual(m.match(rule: r, envelope: env(text: "sunny day")).state, .noMatch)
    }

    func testAliasEntityMatch() {
        let r = ShieldRuleV2(ruleID: "r2", inputType: .entity, rawUserLabel: "Acme Corp", aliases: ["acme", "acmecorp"])
        let m = AliasEntityMatcher()
        XCTAssertEqual(m.match(rule: r, envelope: env(text: "news about ACME today")).state, .matchHigh)
        XCTAssertEqual(m.match(rule: r, envelope: env(text: "unrelated")).state, .noMatch)
    }

    func testSourceMatch() {
        let r = ShieldRuleV2(ruleID: "r3", inputType: .source, rawUserLabel: "that channel", sourceScope: "doomchannel")
        let m = SourceMatcher()
        XCTAssertEqual(m.match(rule: r, envelope: env(contentID: "doomchannel/video/42")).state, .matchExact)
        XCTAssertEqual(m.match(rule: r, envelope: env(contentID: "other/video/1")).state, .noMatch)
    }

    // 006B §1 — no audio track → sound matcher is UNAVAILABLE (cannot determine), NOT a no-match and NOT safe.
    func testSoundClassMatchAndUnavailable() {
        let r = ShieldRuleV2(ruleID: "r4", inputType: .soundClass, rawUserLabel: "gunshot")
        let m = SoundClassMatcher()
        XCTAssertEqual(m.match(rule: r, envelope: env(sounds: ["speech", "gunshot_single"])).state, .matchHigh)
        XCTAssertEqual(m.match(rule: r, envelope: env(sounds: ["music"])).state, .noMatch)
        XCTAssertEqual(m.match(rule: r, envelope: env(sounds: [])).state, .matcherUnavailable)
    }

    // 006B §1 — semantic matcher UNAVAILABLE when no embedding; it never fabricates a match.
    func testSemanticMatchAndUnavailable() {
        let near = SemanticTextMatcher(distance: { _, _, _ in 0.5 })
        let far  = SemanticTextMatcher(distance: { _, _, _ in 1.2 })
        let none = SemanticTextMatcher(distance: { _, _, _ in nil })
        let r = ShieldRuleV2(ruleID: "r5", inputType: .semanticConcept, rawUserLabel: "graphic violence")
        XCTAssertEqual(near.match(rule: r, envelope: env(text: "a violent clip")).state, .matchHigh)
        XCTAssertEqual(far.match(rule: r, envelope: env(text: "a mild clip")).state, .matchLow)
        XCTAssertEqual(none.match(rule: r, envelope: env(text: "anything")).state, .matcherUnavailable)
    }

    // 006B §1/§2 — controller ABSTAINS on unknown/unavailable; low never silently hides; high executes.
    func testControllerAbstainsOnNonDeterminable() {
        let c = ShieldActionControllerV2()
        let hideRule = ShieldRuleV2(ruleID: "h", inputType: .textExact, rawUserLabel: "x", action: .hideIfControlled)
        XCTAssertEqual(c.decide(rule: hideRule, match: .matchExact).decision, .execute)
        XCTAssertEqual(c.decide(rule: hideRule, match: .matchMedium).decision, .ask)   // destructive softened
        XCTAssertEqual(c.decide(rule: hideRule, match: .matchLow).decision, .note)
        XCTAssertEqual(c.decide(rule: hideRule, match: .noMatch).decision, .noShieldAction)
        XCTAssertEqual(c.decide(rule: hideRule, match: .matchabilityUnknown).decision, .noShieldDecision)
        XCTAssertEqual(c.decide(rule: hideRule, match: .matcherUnavailable).decision, .noShieldDecision)
        XCTAssertNil(c.decide(rule: hideRule, match: .matcherUnavailable).action)       // no action, Shield abstains
    }

    func testIndexShortlistBounded() {
        var idx = ShieldIndex()
        for i in 0..<1000 { idx.upsert(ShieldRuleV2(ruleID: "bulk\(i)", inputType: .textExact, rawUserLabel: "topic\(i)")) }
        idx.upsert(ShieldRuleV2(ruleID: "hit", inputType: .textExact, rawUserLabel: "earthquake"))
        XCTAssertEqual(idx.count, 1001)
        let short = idx.shortlist(envelope: env(text: "today there was an earthquake"))
        XCTAssertTrue(short.contains { $0.ruleID == "hit" })
        XCTAssertLessThan(short.count, 50)
    }

    func testExceptionPrecedence() {
        let eng = ShieldExceptionEngine()
        let userRule = ShieldRuleV2(ruleID: "u", authority: .user, inputType: .source, rawUserLabel: "x", sourceScope: "src")
        let guardianRule = ShieldRuleV2(ruleID: "g", authority: .guardian, inputType: .source, rawUserLabel: "x", sourceScope: "src")
        let floorRule = ShieldRuleV2(ruleID: "f", authority: .systemSafetyFloor, inputType: .source, rawUserLabel: "x")
        let ex = [ShieldException(scope: .source, value: "src")]
        XCTAssertTrue(eng.allows(rule: userRule, exceptions: ex, matchedSource: "src", userInitiated: false))
        XCTAssertFalse(eng.allows(rule: guardianRule, exceptions: ex, matchedSource: "src", userInitiated: false))
        XCTAssertFalse(eng.allows(rule: floorRule, exceptions: ex, matchedSource: "src", userInitiated: false))
    }

    func testCorrectionLoop() {
        let applier = ShieldCorrectionApplier()
        let r = ShieldRuleV2(ruleID: "r", inputType: .semanticConcept, rawUserLabel: "x", action: .warn)
        XCTAssertNil(applier.apply(.delete, to: r))
        XCTAssertEqual(applier.apply(.pause, to: r)?.enabled, false)
        XCTAssertEqual(applier.apply(.makeNarrower, to: r)?.inputType, .textExact)
        XCTAssertEqual(applier.apply(.alwaysBlock, to: r)?.action, .hideIfControlled)
    }

    // End-to-end: exact hide executes; no-match clears; exception allows.
    func testEvaluatorEndToEnd() {
        var idx = ShieldIndex()
        idx.upsert(ShieldRuleV2(ruleID: "spoiler", inputType: .textExact, rawUserLabel: "spoiler", action: .hideIfControlled))
        let ev = ShieldEvaluatorV2.standard()
        XCTAssertEqual(ev.evaluate(.init(envelope: env(text: "nice weather")), index: idx), .clear)
        let hit = ev.evaluate(.init(envelope: env(text: "major SPOILER ahead"), controlledSurface: true), index: idx)
        XCTAssertEqual(hit.layerDecision, .execute)
        XCTAssertEqual(hit.actionRecommendation, .hideIfControlled)
        XCTAssertEqual(hit.matchState, .matchExact)
        let allowed = ev.evaluate(.init(envelope: env(text: "major SPOILER ahead"), userInitiated: true), index: idx,
                                  exceptions: [ShieldException(scope: .userInitiated, value: "")])
        XCTAssertTrue(allowed.exceptionApplied)
        XCTAssertEqual(allowed.actionRecommendation, .allow)
    }
}
