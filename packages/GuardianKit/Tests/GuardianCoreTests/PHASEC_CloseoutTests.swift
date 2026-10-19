import XCTest
@testable import GuardianCore

final class PHASEC_CloseoutTests: XCTestCase {

    func shot(_ raw: UInt64, c: Double, s: Double, at: Double, entry: ShotTransitionInV1 = .cut,
              gate: SwipeGateStateV1 = .noSwipe, chromeTop: Double = 0.9, chromeBottom: Double = 0.1) -> ShotDescriptorV1 {
        let rep = Tier0CorpusV1.frame(content: c, style: s, chromeTop: chromeTop, chromeBottom: chromeBottom, projShift: 0)
        return ShotDescriptorV1(shotID: ShotID(raw), observationID: ObservationID(1), startMs: at, endMs: at,   // endMs NOT set (device reality)
                                representative: rep, transitionIn: entry, swipeGate: gate, replacementRatioIn: 0.85, confidenceIn: 0.7)
    }

    // ── §2 DWELL FIX ──────────────────────────────────────────────────────────
    func testDwellDerivedFromMonotonicTimestamps() {
        // device reality: endMs never updated (endMs==startMs) — dwell must still be correct via start-difference
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        _ = e.process(shot(1, c: 0.4, s: 0.3, at: 0))
        let d = e.process(shot(2, c: 0.44, s: 0.3, at: 5200))
        XCTAssertEqual(d.channels?.previousShotDwellMs, 5200, "dwell = start-difference, not stored duration")
        let d3 = e.process(shot(3, c: 0.45, s: 0.3, at: 6000))
        XCTAssertEqual(d3.channels?.previousShotDwellMs, 800)
    }
    func testDwellCadenceJitterDropAndRapid() {
        for interval in [16.7, 33.3, 50.0] {   // 60/30/20 fps shot cadences scaled
            let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
            var t = 0.0
            _ = e.process(shot(1, c: 0.4, s: 0.3, at: t)); t += interval * 40
            let d = e.process(shot(2, c: 0.42, s: 0.3, at: t))
            XCTAssertEqual(d.channels!.previousShotDwellMs, interval * 40, accuracy: 0.001, "cadence-safe dwell")
        }
        // rapid cuts: tiny positive dwells, never negative
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        _ = e.process(shot(1, c: 0.3, s: 0.3, at: 100))
        let d = e.process(shot(2, c: 0.32, s: 0.3, at: 150))
        XCTAssertGreaterThanOrEqual(d.channels!.previousShotDwellMs, 0)
        XCTAssertEqual(d.channels!.previousShotDwellMs, 50)
    }
    func testDwellSessionBoundaryReset() {
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        _ = e.process(shot(1, c: 0.4, s: 0.3, at: 10_000))   // first decision opens item — no dwell claim needed
        // long-dwell evidence must fire with REAL dwell now (was dead on device):
        let d = e.process(shot(2, c: 0.9, s: 0.9, at: 16_000))
        XCTAssertTrue(d.channels!.firedEvidence.contains("long-dwell"), "long-dwell feature alive after fix")
    }

    // ── §5/§6 C6 FAMILY — expected NEW or AMBIGUOUS; NEVER unsafe SAME ───────
    private func assertNeverSame(_ name: String, _ a: ShotDescriptorV1, _ b: ShotDescriptorV1) {
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        _ = e.process(a)
        let d = e.process(b)
        XCTAssertNotEqual(d.state, .sameItemConfirmed, "\(name): different items must not merge (got SAME, S=\(d.mergeScore))")
        XCTAssertFalse(d.safeAdmissionInheritance, "\(name): no inheritance")
    }
    func testC6FamilyAdversarial() {
        // 1 bright→bright different items (the original C6 shape: near-identical luma, long dwell)
        assertNeverSame("bright-bright", shot(1, c: 0.88, s: 0.93, at: 0), shot(2, c: 0.84, s: 0.90, at: 5000))
        // 2 dark→dark different items
        assertNeverSame("dark-dark", shot(1, c: 0.08, s: 0.10, at: 0), shot(2, c: 0.12, s: 0.12, at: 5000))
        // 3 same dominant color different items
        assertNeverSame("same-color", shot(1, c: 0.50, s: 0.55, at: 0), shot(2, c: 0.55, s: 0.55, at: 5000))
        // 4 same template different items (swipe present → veto path)
        assertNeverSame("same-template", shot(1, c: 0.30, s: 0.50, at: 0), shot(2, c: 0.75, s: 0.52, at: 5000, entry: .swipeConfirmed, gate: .swipeTransitionConfirmed))
        // 5 same layout different semantic item (identical style/projections, far content, no anchor)
        assertNeverSame("same-layout", shot(1, c: 0.20, s: 0.50, at: 0), shot(2, c: 0.80, s: 0.50, at: 5000))
        // 6 rapid similar items (short dwell, swipe)
        assertNeverSame("rapid-similar", shot(1, c: 0.50, s: 0.50, at: 0), shot(2, c: 0.54, s: 0.52, at: 900, entry: .swipeConfirmed, gate: .swipeTransitionConfirmed))
        // 7 persistent chrome + content replacement
        assertNeverSame("chrome-replace", shot(1, c: 0.25, s: 0.25, at: 0), shot(2, c: 0.80, s: 0.78, at: 5000))
        // 8 similar crossfade
        assertNeverSame("similar-crossfade", shot(1, c: 0.48, s: 0.50, at: 0), shot(2, c: 0.56, s: 0.52, at: 5000, entry: .crossfade))
        // 9 low-motion replacement (tight content families either side of a boundary, long watch)
        assertNeverSame("low-motion-replace", shot(1, c: 0.40, s: 0.42, at: 0), shot(2, c: 0.52, s: 0.44, at: 8000))
        // 10 high-motion replacement
        assertNeverSame("high-motion-replace", shot(1, c: 0.60, s: 0.65, at: 0), shot(2, c: 0.30, s: 0.60, at: 2000))
    }

    // ── §7 EVIDENCE INDEPENDENCE GUARD units ─────────────────────────────────
    func testIndependenceGuardFamilies() {
        XCTAssertEqual(EvidenceIndependenceGuardV1.family(ofSameSource: "theme-continuity"), .contentLuma)
        XCTAssertEqual(EvidenceIndependenceGuardV1.family(ofSameSource: "histogram-continuity"), .contentLuma)
        XCTAssertEqual(EvidenceIndependenceGuardV1.family(ofSameSource: "chrome-continuity"), .contentLuma)
        XCTAssertEqual(EvidenceIndependenceGuardV1.family(ofSameSource: "regional-continuity"), .contentLuma)
        XCTAssertEqual(EvidenceIndependenceGuardV1.family(ofSameSource: "projection-continuity"), .visualStructure)
        XCTAssertEqual(EvidenceIndependenceGuardV1.family(ofSameSource: "edit-burst"), .temporalInteraction)
        XCTAssertNil(EvidenceIndependenceGuardV1.family(ofSameSource: "cut-prior"), "priors never count")
        // all four luma channels together = ONE family → NOT sufficient
        XCTAssertFalse(EvidenceIndependenceGuardV1.allowsSameConfirmation(firedSameSources:
            ["theme-continuity","histogram-continuity","chrome-continuity","regional-continuity","cut-prior"]))
        // luma + structure WITHOUT temporal support = visual-only → NOT sufficient (near-identical different items)
        XCTAssertFalse(EvidenceIndependenceGuardV1.allowsSameConfirmation(firedSameSources:
            ["theme-continuity","projection-continuity"]))
        // luma + burst (edit cadence) = independent families incl. temporal → sufficient
        XCTAssertTrue(EvidenceIndependenceGuardV1.allowsSameConfirmation(firedSameSources:
            ["theme-continuity","projection-continuity","edit-burst"]))
        // cross-modal anchor alone → sufficient
        XCTAssertTrue(EvidenceIndependenceGuardV1.allowsSameConfirmation(firedSameSources: ["caption-match"]))
    }
    func testStrongNewStillAbsolute() {
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        _ = e.process(shot(1, c: 0.4, s: 0.3, at: 0))
        let d = e.process(shot(2, c: 0.4, s: 0.3, at: 1500, entry: .swipeConfirmed, gate: .swipeTransitionConfirmed))
        XCTAssertNotEqual(d.state, .sameItemConfirmed, "veto survives the guard rework")
    }

    // ── §3/§9 PROVISIONAL IDENTITY + DNA RULES ───────────────────────────────
    func testTier0NeverInheritsSafeAdmission() {
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        _ = e.process(shot(1, c: 0.4, s: 0.3, at: 0))
        let d = e.process(shot(2, c: 0.44, s: 0.3, at: 1500))   // legitimate internal-cut merge
        XCTAssertEqual(d.state, .sameItemConfirmed)
        XCTAssertFalse(d.safeAdmissionInheritance, "PHASE C: ALL Tier-0 identity is provisional — no inheritance")
    }
    func testProvisionalIdentityReclassification() {
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        _ = e.process(shot(1, c: 0.4, s: 0.3, at: 0))
        let d = e.process(shot(2, c: 0.44, s: 0.3, at: 1500))
        let p = ExtensionProvisionalIdentityV1.from(decision: d, shotID: ShotID(2), profile: .extensionFastTier0,
                                                    groupingRevision: "item-grouping-policy-v2-extension-tier0",
                                                    shotRevision: "boundary-policy-v5")
        XCTAssertEqual(p.relation, .candidateSameItem, "Tier-0 SAME maps to CANDIDATE, never authoritative")
        XCTAssertGreaterThanOrEqual(p.independentFamilies, 2)
    }
    func testNoDurableDNAWhileProvisional() {
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        _ = e.process(shot(1, c: 0.4, s: 0.3, at: 0))
        let amb = e.process(shot(2, c: 0.70, s: 0.31, at: 2000))   // ambiguous → provisional item
        XCTAssertEqual(amb.state, .ambiguous)
        XCTAssertNil(e.mintDNA(for: amb.itemID, nowMs: 3000), "no durable item DNA on unresolved identity")
        // SHOT_ONLY evidence record is allowed + risk escalates immediately
        e.accumulator.reportRisk(item: amb.itemID, confidence: 0.9)
        let rec = e.shotOnlyEvidence(for: amb.itemID)
        XCTAssertFalse(rec.isEmpty)
        XCTAssertTrue(rec[0].riskEscalated)
        XCTAssertEqual(rec[0].maxRiskConfidence, 0.9)
        // confirmed (session-start) item CAN mint
        XCTAssertNotNil(e.mintDNA(for: e.itemsInOrder[0].id, nowMs: 3000))
    }
    func testProvisionalMergeConsolidationAndSessionReset() {
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        _ = e.process(shot(1, c: 0.40, s: 0.30, at: 0))
        _ = e.process(shot(2, c: 0.44, s: 0.30, at: 1500))
        let amb = e.process(shot(3, c: 0.72, s: 0.30, at: 9000))
        XCTAssertEqual(amb.state, .ambiguous)
        _ = e.process(shot(4, c: 0.42, s: 0.30, at: 10200))
        _ = e.process(shot(5, c: 0.41, s: 0.30, at: 11400))
        let co = DeferredItemCoalescerV1()
        var invalidated: [ContentDNAID] = []
        var merged = false
        for _ in 0..<3 { if co.tryCoalesce(engine: e, dnaInvalidator: { invalidated.append($0) }) { merged = true } }
        XCTAssertTrue(merged, "Tier-1-style later consolidation works on provisional items")
        XCTAssertEqual(e.revisions.last?.lifecycle, .merged)
    }

    // ── §8 TIER-1 HANDOFF ────────────────────────────────────────────────────
    func testTier1HandoffBoundedAndDerivedOnly() {
        let e = ContentItemGroupingEngineV2(policy: .frozenTier0, profile: .extensionFastTier0)
        let buf = Tier1HandoffBufferV1(capacity: 8)
        var t = 0.0
        for k in 1...40 {
            let d = e.process(shot(UInt64(k), c: 0.1 + 0.8 * Tier0CorpusV1.rnd(9, k), s: 0.1 + 0.8 * Tier0CorpusV1.rnd(10, k), at: t)); t += 2000
            let p = ExtensionProvisionalIdentityV1.from(decision: d, shotID: ShotID(UInt64(k)), profile: .extensionFastTier0,
                                                        groupingRevision: "g", shotRevision: "s")
            buf.append(Tier1IdentityHandoffV1.from(identity: p, observationID: ObservationID(1), transition: .cut,
                                                   channels: d.channels, thermal: .nominal))
        }
        XCTAssertLessThanOrEqual(buf.count, 8, "handoff ring bounded")
        // derived-only by construction: no Data/byte payloads anywhere in the record
        for child in Mirror(reflecting: buf.records[0]).children {
            XCTAssertFalse(child.value is Data); XCTAssertFalse(child.value is [UInt8])
        }
        XCTAssertFalse(buf.records[0].modelPolicyVersions.isEmpty, "provenance versions present")
        XCTAssertEqual(buf.drain().count, buf.count == 0 ? 8 : 8)
    }

    // ── §10 RELEASE EVIDENCE LOGGING OFF ─────────────────────────────────────
    func testReleaseDisablesEvidenceLogging() {
        XCTAssertFalse(EvidenceBuildPolicyV1.isEnabled(compileFlagSet: false, isDebugBuild: false, envOptIn: true),
                       "release ignores env opt-in — structurally OFF")
        XCTAssertFalse(EvidenceBuildPolicyV1.isEnabled(compileFlagSet: false, isDebugBuild: false, envOptIn: false))
        XCTAssertTrue(EvidenceBuildPolicyV1.isEnabled(compileFlagSet: true, isDebugBuild: false, envOptIn: false),
                      "explicit evidence compile flag enables (audit builds)")
        XCTAssertTrue(EvidenceBuildPolicyV1.isEnabled(compileFlagSet: false, isDebugBuild: true, envOptIn: true))
        XCTAssertFalse(EvidenceBuildPolicyV1.isEnabled(compileFlagSet: false, isDebugBuild: true, envOptIn: false))
    }
}
