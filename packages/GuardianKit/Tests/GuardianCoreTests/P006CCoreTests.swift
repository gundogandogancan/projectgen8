import XCTest
@testable import GuardianCore

final class P006CCoreTests: XCTestCase {

    // §11 — audio-reference durability is classified truthfully (no implied parity with visual rules).
    func testAudioReferenceDurabilityClassification() {
        XCTAssertEqual(AudioReferenceDurability.classify(.soundClass), .functionallyDurable)
        XCTAssertEqual(AudioReferenceDurability.classify(.audioReference), .metadataOnly)
        XCTAssertEqual(AudioReferenceDurability.classify(.musicTrack), .matcherUnavailable)
        XCTAssertEqual(AudioReferenceDurability.classify(.musicArtist), .matcherUnavailable)
        XCTAssertEqual(AudioReferenceDurability.classify(.spokenReference), .metadataOnly)
    }

    // §8 — functional states: a durable record in a non-functional state never reads as ACTIVE/protecting.
    func testFunctionalStates() {
        var r = ShieldRuleV2(ruleID: "r", inputType: .imageReference, rawUserLabel: "x", createdAtEpoch: 1)
        XCTAssertEqual(r.functionalState(nowEpoch: 2), .active)
        XCTAssertTrue(r.functionalState(nowEpoch: 2).isProtectingNow)
        r.enabled = false; XCTAssertEqual(r.functionalState(nowEpoch: 2), .paused)
        r.enabled = true; r.expiresAtEpoch = 1; XCTAssertEqual(r.functionalState(nowEpoch: 2), .expired)
        r.expiresAtEpoch = nil; r.referenceReauthoringRequired = true
        XCTAssertEqual(r.functionalState(nowEpoch: 2), .referenceReauthoringRequired)
        XCTAssertFalse(r.functionalState(nowEpoch: 2).isProtectingNow)
        r.referenceReauthoringRequired = false; r.corrupt = true
        XCTAssertEqual(r.functionalState(nowEpoch: 2), .corrupt)
        r.corrupt = false; r.migrating = true; XCTAssertEqual(r.functionalState(nowEpoch: 2), .migrating)
    }

    // §9 — startup index truth: the index is DERIVED (rebuilt from durable rules), identical across rebuilds, never trusted from disk.
    func testStartupIndexRebuiltDeterministically() {
        let rules = (0..<50).map { ShieldRuleV2(ruleID: "r\($0)", inputType: .textExact, rawUserLabel: "topic\($0)", createdAtEpoch: 1) }
        let a = ShieldIndex.rebuilt(from: rules)
        let b = ShieldIndex.rebuilt(from: rules)
        XCTAssertEqual(a.count, 50)
        XCTAssertEqual(a.count, b.count)
        var e = ContentObservationEnvelope(); e.structuredText = [TextSource(origin: .structured, text: "topic7 appears")]
        XCTAssertEqual(a.shortlist(envelope: e).first?.ruleID, b.shortlist(envelope: e).first?.ruleID)
        XCTAssertEqual(ShieldIndex.indexVersion, "shield-index-v2")
    }
}
