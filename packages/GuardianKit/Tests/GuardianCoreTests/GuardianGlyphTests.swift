import XCTest
@testable import GuardianCore

final class GuardianGlyphTests: XCTestCase {
    private let engine = GuardianGlyphEngine()

    // §19 content-character families when guardian state is aligned.
    func testContentFamiliesWhenAligned() {
        XCTAssertEqual(engine.primaryFamily(content: .learning, guardian: .aligned), .learning)
        XCTAssertEqual(engine.primaryFamily(content: .music, guardian: .aligned), .music)
        XCTAssertEqual(engine.primaryFamily(content: .calm, guardian: .aligned), .calmNature)
    }

    // 006B §10 FIREWALL — a positive content glyph NEVER overrides a protection/admission signal.
    func testFirewallProtectionOutranksContent() {
        XCTAssertEqual(engine.primaryFamily(content: .humor, guardian: .strongProtection), .strongProtection)
        XCTAssertEqual(engine.primaryFamily(content: .humor, guardian: .shieldMatch), .shieldMatch) // humor video + hard shield → NOT 🙂
        XCTAssertEqual(engine.primaryFamily(content: .humor, guardian: .cautionConflict), .caution)
        XCTAssertEqual(engine.primaryFamily(content: .humor, guardian: .unknown), .unknown)
    }

    // 006B §1 — shield match states drive the guardian axis correctly; unavailable/unknown → unknown (not safe).
    func testGuardianStateFromShield() {
        XCTAssertEqual(engine.guardianState(for: GlyphInputs(shieldState: .matchHigh)), .shieldMatch)
        XCTAssertEqual(engine.guardianState(for: GlyphInputs(shieldState: .evidenceConflict)), .cautionConflict)
        XCTAssertEqual(engine.guardianState(for: GlyphInputs(shieldState: .matcherUnavailable)), .unknown)
        XCTAssertEqual(engine.guardianState(for: GlyphInputs(shieldState: .matchabilityUnknown)), .unknown)
        XCTAssertEqual(engine.guardianState(for: GlyphInputs(shieldState: .noMatch, contentCharacter: .humor, minConfidence: 0.9)), .aligned)
    }

    // §21 truth: UNKNOWN / ANALYZING never claim safe.
    func testUnknownNeverClaimsSafe() {
        XCTAssertFalse(engine.token(for: .unknown, style: .minimalSymbols).isTruthfulSafeClaim)
        XCTAssertFalse(engine.token(for: .analyzing, style: .minimalSymbols).isTruthfulSafeClaim)
        XCTAssertTrue(engine.token(for: .learning, style: .minimalSymbols).isTruthfulSafeClaim)
    }

    // protection-signal flag is set only for guardian-state families.
    func testProtectionSignalFlag() {
        XCTAssertTrue(engine.token(for: .shieldMatch, style: .minimalSymbols).isProtectionSignal)
        XCTAssertTrue(engine.token(for: .strongProtection, style: .minimalSymbols).isProtectionSignal)
        XCTAssertFalse(engine.token(for: .humorPositive, style: .minimalSymbols).isProtectionSignal)
    }

    func testStyleSelection() {
        XCTAssertNil(engine.token(for: GlyphInputs(contentCharacter: .humor, minConfidence: 0.9), style: .off))
        XCTAssertEqual(engine.token(for: GlyphInputs(contentCharacter: .humor, minConfidence: 0.9), style: .emoji)?.emoji, "🙂")
        XCTAssertEqual(engine.token(for: GlyphInputs(contentCharacter: .humor, minConfidence: 0.9), style: .minimalSymbols)?.emoji, "")
    }

    // 006B §11 — plain, non-diagnostic wording; no "healthy" claim.
    func testWordingSafety() {
        let banned = ["diagnos", "disease", "disorder", "cure", "treat", "patient", "symptom", "healthy"]
        for f: GlyphFamily in [.learning, .humorPositive, .creativity, .calmNature, .music, .entertainment,
                               .caution, .shieldMatch, .strongProtection, .neutral, .unknown, .analyzing] {
            let label = engine.token(for: f, style: .minimalSymbols).label.lowercased()
            for b in banned { XCTAssertFalse(label.contains(b), "glyph label '\(label)' contains '\(b)'") }
        }
        XCTAssertEqual(engine.token(for: .shieldMatch, style: .minimalSymbols).label, "Matches your Shield")
    }

    // §22 stabilization
    func testStabilizerRapidSwipeStaysAnalyzing() {
        let s = GuardianGlyphStabilizer(requiredStreak: 2, minConfidence: 0.45)
        XCTAssertEqual(s.observe(contentID: "a", raw: .humorPositive, confidence: 0.9), .analyzing)
        XCTAssertEqual(s.observe(contentID: "b", raw: .learning, confidence: 0.9), .analyzing)
        XCTAssertEqual(s.observe(contentID: "c", raw: .music, confidence: 0.9), .analyzing)
    }
    func testStabilizerCommitsWhenStable() {
        let s = GuardianGlyphStabilizer(requiredStreak: 2, minConfidence: 0.45)
        _ = s.observe(contentID: "x", raw: .learning, confidence: 0.9)
        XCTAssertEqual(s.observe(contentID: "x", raw: .learning, confidence: 0.9), .learning)
    }
    func testStabilizerProtectionCommitsImmediately() {
        let s = GuardianGlyphStabilizer()
        _ = s.observe(contentID: "x", raw: .neutral, confidence: 0.9)
        XCTAssertEqual(s.observe(contentID: "x", raw: .strongProtection, confidence: 0.9), .strongProtection)
    }

    // §24 stale → UNKNOWN (never stale-green).
    func testStaleStateNeverShowsSafeGlyph() {
        let token = engine.token(for: .learning, style: .minimalSymbols)
        let surface = GlyphSurfaceState(token: token, contentID: "A", sequence: 1, computedAtNanos: 1_000, staleAfterNanos: 500)
        XCTAssertEqual(surface.render(nowNanos: 1_200, style: .minimalSymbols).family, .learning)
        let stale = surface.render(nowNanos: 5_000, style: .minimalSymbols)
        XCTAssertEqual(stale.family, .unknown)
        XCTAssertFalse(stale.isTruthfulSafeClaim)
    }
}
