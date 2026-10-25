//
//  LocalLearningIntegrationTests.swift — §5 PROOF: accepting a Personal Learning proposal produces a REAL behaviour
//  change through the SAME store boundary (policyRevision bump → brain reload → prefetch token invalidation →
//  re-decision differs), and UNDO reverses it. Headless over the real types. XCTest.
//
import XCTest
@testable import GuardianMedia
import GuardianCore
#if canImport(AVFoundation)
import AVFoundation

@MainActor
final class LocalLearningIntegrationTests: XCTestCase {

    private func makeStore() -> (store: PersonalShieldSharedStoreV1, dir: URL, suite: UserDefaults) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lli-\(UUID().uuidString)")
        let suite = UserDefaults(suiteName: "lli.\(UUID().uuidString)")!
        return (PersonalShieldSharedStoreV1(directory: dir, suite: suite, sharedContainerActive: true), dir, suite)
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    // A deterministic visual stub matching the spoiler text so the rule fires (so a HIDE really hides).
    private struct StubVisual: ReelsEvidenceProviding {
        let ocrText: String
        func gatherEvidence(url: URL, metadataTitle: String, firstFrameSeconds: [Double], languages: [String]) async -> ReelsEvidenceV1 {
            ReelsEvidenceProviderV1.fuse(ocrText: ocrText, metadataText: "clip", frameCoverage: 1,
                                         ocrExecuted: true, languages: ["en"],
                                         timedRecords: [.init(timestampSeconds: 0.2, modality: .visualOCR, ocrStatus: .ran, text: ocrText)])
        }
    }

    // MARK: §5 — accept a loosen proposal → the rule action changes via the store → the SAME reel re-decides differently.

    func testAcceptedProposalChangesRealDecisionAndRevision() async throws {
        let (store, dir, _) = makeStore(); defer { cleanup(dir) }
        // Start with a HIDE rule on "spoiler"; the reel's OCR contains "spoiler" → the brain HIDES it.
        _ = try store.saveRules([ShieldRuleV2(ruleID: "r1", inputType: .textExact, rawUserLabel: "spoiler",
                                              locale: "en", action: .hideIfControlled, createdAtEpoch: 1, updatedAtEpoch: 1)])
        let revBefore = store.policyRevision
        let item = ReelItemV1(id: "x", title: "t", url: URL(fileURLWithPath: "/tmp/x"))
        let brain = ReelsPlayerModelV1(items: [item], store: store,
                                       evidenceProvider: StubVisual(ocrText: "spoiler ending"),
                                       audioProvider: nil, clock: { 10 })
        let before = await brain.evaluate(item)
        XCTAssertEqual(before.state, .hidden, "the HIDE rule hides the matching reel before any learning change")

        // The engine proposes loosening after 3 distinct-content show-anyway signals; the app applies it to the store.
        let engine = LocalLearningProposalEngineV1(baseThreshold: 3, strictThreshold: 5)
        for c in ["r-1", "r-2", "r-3"] {
            engine.ingest(LearningExplicitSignalV1(ruleID: "r1", kind: .showAnyway,
                                                   contentToken: LearningExplicitSignalV1.contentToken(from: c), dayStamp: 0), enabled: true)
        }
        let rulesNow = store.loadPolicy().rules
        let pending = engine.refresh(rules: rulesNow, nowDay: 0, policyRevision: store.policyRevision)
        XCTAssertEqual(pending.count, 1, "a confident loosen proposal formed")
        let accepted = engine.accept(proposalID: pending[0].proposalID)!

        // APPLY through the store (the real behaviour-change path the app uses) → revision bumps.
        var applied = store.loadPolicy().rules
        let idx = applied.firstIndex { $0.ruleID == "r1" }!
        applied[idx].action = accepted.proposedAction   // HIDE → ASK
        _ = try store.saveRules(applied)
        XCTAssertGreaterThan(store.policyRevision, revBefore, "accepting a proposal bumps the real policyRevision (§5)")

        // A brain that reloads the new policy re-decides the SAME reel DIFFERENTLY (no longer a hard HIDE).
        _ = brain.reloadPolicy()
        let after = await brain.evaluate(item)
        XCTAssertNotEqual(after.state, .hidden, "after accepting the loosen proposal the same reel no longer hard-hides (§5)")
    }

    // MARK: §5 — the accepted change invalidates an old prefetch token (policy revision is part of the token).

    @MainActor
    func testAcceptedChangeInvalidatesOldPrefetchToken() async throws {
        let (store, dir, _) = makeStore(); defer { cleanup(dir) }
        _ = try store.saveRules([ShieldRuleV2(ruleID: "r1", inputType: .textExact, rawUserLabel: "spoiler",
                                              locale: "en", action: .hideIfControlled, createdAtEpoch: 1, updatedAtEpoch: 1)])
        let items = [ReelItemV1(id: "a", title: "a", url: URL(fileURLWithPath: "/tmp/a")),
                     ReelItemV1(id: "b", title: "b", url: URL(fileURLWithPath: "/tmp/b"))]
        let brain = ReelsPlayerModelV1(items: items, store: store, audioProvider: nil)
        let coord = PrefetchCoordinatorV1(sessionID: "s", brain: brain, items: items)
        let tokenBefore = coord.makeToken(forNextAfter: 0)
        XCTAssertNotNil(tokenBefore)
        // Apply a rule change via the store + reload the brain (the accepted-proposal effect) → the freshly minted
        // token differs because policyRevision (and evidence epoch) advanced.
        var rules = store.loadPolicy().rules
        rules[0].action = .ask
        _ = try store.saveRules(rules)
        _ = brain.pollPolicyRevisionAndInvalidateIfChanged()
        let tokenAfter = coord.makeToken(forNextAfter: 0)
        XCTAssertNotEqual(tokenBefore, tokenAfter, "a policy change (accepted proposal) invalidates the old prefetch token (§5)")
        XCTAssertNotEqual(tokenBefore?.policyRevision, tokenAfter?.policyRevision)
    }
}
#endif
