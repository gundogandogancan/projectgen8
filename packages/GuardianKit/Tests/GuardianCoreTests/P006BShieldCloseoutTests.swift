import XCTest
@testable import GuardianCore

// A music-identity matcher stub that is always UNAVAILABLE (no Shazam catalog) — used to prove routing isolation.
private struct UnavailableMusicMatcher: ShieldMatcher {
    let id = ShieldMatcherID.musicIdentity
    func handles(_ t: ShieldInputType) -> Bool { t == .musicTrack || t == .musicArtist }
    func match(rule: ShieldRuleV2, envelope: ContentObservationEnvelope) -> ShieldMatchResult {
        ShieldMatchResult(ruleID: rule.ruleID, matcherID: id.rawValue, state: .matcherUnavailable, rawConfidence: nil,
                          reason: .matcherUnavailable, modality: "music", engineVersion: "music-stub")
    }
}

private struct StubBridge: CrossLanguageConceptBridge {
    let verdictToReturn: CrossLanguageVerdict
    func verdict(ruleLocale: String, contentLocale: String, concept: String, canonicalConceptID: String?) -> CrossLanguageVerdict {
        ruleLocale == contentLocale ? .sameLanguage : verdictToReturn
    }
}

final class P006BShieldCloseoutTests: XCTestCase {

    private func textEnv(_ s: String, lang: String = "en") -> ContentObservationEnvelope {
        var e = ContentObservationEnvelope()
        e.structuredText = [TextSource(origin: .structured, text: s)]
        e.languageSignals = [lang]
        return e
    }

    // §3 — a MUSIC rule whose matcher is unavailable must NOT warn/hold a (text) item. It abstains, item proceeds.
    func testMissingMusicMatcherDoesNotPoisonItem() {
        var idx = ShieldIndex()
        idx.upsert(ShieldRuleV2(ruleID: "m", inputType: .musicTrack, rawUserLabel: "nickelback", action: .hideIfControlled))
        let ev = ShieldEvaluatorV2(matchers: [ExactTextMatcher(), AliasEntityMatcher(), SourceMatcher(),
                                              SoundClassMatcher(), UnavailableMusicMatcher()])
        // Content mentions the track name in text, so the rule IS shortlisted, but only the music matcher is routed.
        let out = ev.evaluate(.init(envelope: textEnv("a review praising nickelback live"), controlledSurface: true), index: idx)
        XCTAssertFalse(out.matchState.isMatch)                 // no actual match fabricated
        XCTAssertEqual(out.layerDecision, .noShieldAction)     // the Shield does NOT warn/hold
        let admit = GlobalAdmissionController().admit(shield: out, mode: .normal, controlledSurface: true,
                                                      modalityExpectedButUnavailable: true)
        XCTAssertEqual(admit.state, .proceed)                  // normal mode never holds on unavailable
    }

    // §4 — strict mode is the ONLY path to HOLD on unverified; normal mode proceeds.
    func testStrictModeHoldVsNormalProceed() {
        let abstain = PersonalShieldDecision(ruleID: "r", matchState: .matcherUnavailable, layerDecision: .noShieldDecision,
                                             actionRecommendation: nil, coverage: 0, missingMatchers: ["music-identity"],
                                             uncertainty: 1, reasonCodes: [.matcherUnavailable], exceptionApplied: false,
                                             evaluatedRules: 1, matchersRun: 1)
        let gac = GlobalAdmissionController()
        XCTAssertEqual(gac.admit(shield: abstain, mode: .normal, controlledSurface: true, modalityExpectedButUnavailable: true).state, .proceed)
        XCTAssertEqual(gac.admit(shield: abstain, mode: .strictNoExposureIfUnverified, controlledSurface: true, modalityExpectedButUnavailable: true).state, .hold)
        // Strict but modality not actually expected → still proceed (no blanket hold).
        XCTAssertEqual(gac.admit(shield: abstain, mode: .strictNoExposureIfUnverified, controlledSurface: true, modalityExpectedButUnavailable: false).state, .proceed)
    }

    // §5/§13 — rule survives a store round-trip (relaunch), index rebuilds, rule matches; edit & pause persist; delete removes.
    func testPersistenceRelaunchProof() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gen8-shield-test-\(UUID().uuidString)")
        let store = FileBackedPersonalShieldStore(directory: dir)
        var snap = ShieldStoreSnapshot(rules: [ShieldRuleV2(ruleID: "r1", inputType: .textExact, rawUserLabel: "spoiler", action: .hideIfControlled)])
        try store.save(snap)

        // "Relaunch": brand-new store instance reads from disk.
        let store2 = FileBackedPersonalShieldStore(directory: dir)
        let mgr = ShieldStoreManager(store: store2)
        var (loaded, index) = try mgr.loadAndRebuild()
        XCTAssertEqual(loaded.rules.count, 1)
        let ev = ShieldEvaluatorV2.standard()
        XCTAssertEqual(ev.evaluate(.init(envelope: textEnv("big spoiler here")), index: index).layerDecision, .execute)

        // Edit persists.
        loaded.rules[0].rawUserLabel = "ending"
        try store2.save(loaded)
        (snap, index) = try ShieldStoreManager(store: FileBackedPersonalShieldStore(directory: dir)).loadAndRebuild()
        XCTAssertEqual(snap.rules[0].rawUserLabel, "ending")
        XCTAssertEqual(ev.evaluate(.init(envelope: textEnv("the ending is sad")), index: index).layerDecision, .execute)

        // Pause persists → rule not active.
        snap.rules[0].enabled = false
        try store2.save(snap)
        (snap, index) = try ShieldStoreManager(store: FileBackedPersonalShieldStore(directory: dir)).loadAndRebuild()
        XCTAssertTrue(ev.evaluate(.init(envelope: textEnv("the ending is sad")), index: index) == .clear)

        // Delete removes rule + index entry.
        snap.rules.removeAll()
        try store2.save(snap)
        (snap, index) = try ShieldStoreManager(store: FileBackedPersonalShieldStore(directory: dir)).loadAndRebuild()
        XCTAssertEqual(index.count, 0)
        try? store2.wipe()
    }

    // §8 — a deleted rule can never match from a stale index cache.
    func testDeletedRuleCannotMatchFromCache() {
        var idx = ShieldIndex()
        idx.upsert(ShieldRuleV2(ruleID: "d", inputType: .textExact, rawUserLabel: "earthquake", action: .hideIfControlled))
        XCTAssertFalse(idx.shortlist(envelope: textEnv("earthquake news")).isEmpty)
        idx.remove("d")
        XCTAssertTrue(idx.shortlist(envelope: textEnv("earthquake news")).isEmpty)   // no stale token entry survives
        XCTAssertEqual(idx.count, 0)
    }

    // §7 — an image rule whose derived feature is from an incompatible engine revision → REAUTHORING_REQUIRED (inactive).
    func testIncompatibleFeatureBecomesReauthoringRequired() throws {
        let rule = ShieldRuleV2(ruleID: "img", inputType: .imageReference, rawUserLabel: "logo",
                                referenceFeatureIDs: ["f1"], action: .hideIfControlled)
        let staleFeature = DerivedReferenceFeature(featureID: "f1", ruleID: "img", featureType: .image,
                                                   engineID: "apple-vision-featureprint-shield-v1", engineRevision: "r0",
                                                   vectorDimension: 8, serializedFeature: Data([1,2,3,4]), createdAtEpoch: 1)
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gen8-shield-reauth-\(UUID().uuidString)")
        let store = FileBackedPersonalShieldStore(directory: dir)
        try store.save(ShieldStoreSnapshot(rules: [rule], features: [staleFeature]))
        // Current engine revision is r1 → the r0 feature is incompatible.
        let mgr = ShieldStoreManager(store: store, currentEngineRevision: "r1")
        let (snap, index) = try mgr.loadAndRebuild()
        XCTAssertTrue(snap.rules[0].referenceReauthoringRequired)   // not silently pretended to work
        XCTAssertTrue(index.shortlist(envelope: textEnv("logo"), nowEpoch: 2).isEmpty)  // inactive until re-authored
        try? store.wipe()
    }

    // §6 — corruption detection on load (checksum mismatch).
    func testCorruptionDetected() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gen8-shield-corrupt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("personal-shield.store.json")
        try Data("not a valid envelope".utf8).write(to: file)
        let store = FileBackedPersonalShieldStore(directory: dir)
        XCTAssertThrowsError(try store.load())
        try? FileManager.default.removeItem(at: dir)
    }

    // §12 — Dynamic Island ordering: out-of-order late update rejected; content change invalidates; stale old content → unknown.
    func testGlyphSurfaceOrderingSafety() {
        let ctrl = GlyphSurfaceController()
        let eng = GuardianGlyphEngine()
        let tokenA = eng.token(for: .learning, style: .minimalSymbols)
        let tokenB = eng.token(for: .music, style: .minimalSymbols)

        _ = ctrl.apply(GlyphSurfaceState(token: tokenA, contentID: "A", sequence: 2, computedAtNanos: 0, staleAfterNanos: .max), style: .minimalSymbols)
        // Out-of-order lower sequence for same content → rejected, keeps A.
        let kept = ctrl.apply(GlyphSurfaceState(token: tokenB, contentID: "A", sequence: 1, computedAtNanos: 0, staleAfterNanos: .max), style: .minimalSymbols)
        XCTAssertEqual(kept.family, .learning)

        // Content switches to B.
        let analyzing = ctrl.contentChanged(to: "B", sequence: 10, style: .minimalSymbols)
        XCTAssertEqual(analyzing.family, .analyzing)
        // A delayed update for OLD content A (lower seq) arrives → must NOT show A's positive glyph.
        let late = ctrl.apply(GlyphSurfaceState(token: tokenA, contentID: "A", sequence: 3, computedAtNanos: 0, staleAfterNanos: .max), style: .minimalSymbols)
        XCTAssertEqual(late.family, .unknown)
        // App paused / Guardian off → never a positive glyph.
        XCTAssertEqual(ctrl.invalidate(style: .minimalSymbols).family, .unknown)
    }

    // §14 — authority precedence: SYSTEM_SAFETY_FLOOR > GUARDIAN > USER > USER_EXCEPTION.
    func testAuthorityPrecedenceAudit() {
        let eng = ShieldExceptionEngine()
        let ex = [ShieldException(scope: .userInitiated, value: "")]
        let userRule = ShieldRuleV2(ruleID: "u", authority: .user, inputType: .textExact, rawUserLabel: "x")
        let guardianRule = ShieldRuleV2(ruleID: "g", authority: .guardian, inputType: .textExact, rawUserLabel: "x")
        let floorRule = ShieldRuleV2(ruleID: "f", authority: .systemSafetyFloor, inputType: .textExact, rawUserLabel: "x")
        // Adult can bypass own rule via exception.
        XCTAssertTrue(eng.allows(rule: userRule, exceptions: ex, matchedSource: nil, userInitiated: true))
        // Child cannot override a guardian-protected rule with an ordinary exception.
        XCTAssertFalse(eng.allows(rule: guardianRule, exceptions: ex, matchedSource: nil, userInitiated: true))
        // Nobody overrides the system safety floor.
        let override = [ShieldException(scope: .userInitiated, value: "", allowsOverrideOfGuardianRule: true)]
        XCTAssertFalse(eng.allows(rule: floorRule, exceptions: override, matchedSource: nil, userInitiated: true))
        // A guardian-authorized exception CAN override a guardian rule (explicit).
        XCTAssertTrue(eng.allows(rule: guardianRule, exceptions: override, matchedSource: nil, userInitiated: true))
    }

    // §9 — cross-language uses concept certification, not locale-string difference.
    func testCrossLanguageBridgeDrivenNotMechanical() {
        let r = ShieldRuleV2(ruleID: "x", inputType: .semanticConcept, rawUserLabel: "savaş", locale: "tr")
        let strongDistance: @Sendable (String, String, String) -> Double? = { _, _, _ in 0.5 }  // would be HIGH
        // Verified canonical bridge → stays HIGH even though locales differ.
        let verified = SemanticTextMatcher(distance: strongDistance, bridge: StubBridge(verdictToReturn: .verifiedCanonicalBridge))
        XCTAssertEqual(verified.match(rule: r, envelope: textEnv("war footage", lang: "en")).state, .matchHigh)
        // Unverified bridge → downgraded.
        let unverified = SemanticTextMatcher(distance: strongDistance, bridge: StubBridge(verdictToReturn: .unverifiedBridge))
        XCTAssertEqual(unverified.match(rule: r, envelope: textEnv("war footage", lang: "en")).state, .matchMedium)
        // Same language → not downgraded.
        let same = SemanticTextMatcher(distance: strongDistance, bridge: StubBridge(verdictToReturn: .unverifiedBridge))
        XCTAssertEqual(same.match(rule: r, envelope: textEnv("savaş görüntüleri", lang: "tr")).state, .matchHigh)
    }
}
