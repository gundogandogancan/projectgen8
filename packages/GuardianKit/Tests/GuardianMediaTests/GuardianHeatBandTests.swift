//
//  GuardianHeatBandTests.swift — BUILD proof for the LIVE Dynamic Island HEAT-MAP band model (micro-iteration).
//
//  Proves the pure, categorical band logic that drives the Island marker:
//   • NO fabricated 0-100 number: the band is derived ONLY from real decision states; position stays in 0...1.
//   • The marker slides to the correct band for each decision state (surface path + controlled-reels path).
//   • A content/state switch moves the marker to the NEW band — and the computation is pure (in-process), asserted
//     here with a tight latency bound so "marker move the instant content changes" is substantiated where lawful.
//   • UNKNOWN is honest abstention: it never lands in the CLEAR zone regardless of confidence (rule 7).
//   • OFF is dormant: no live marker (never a protective look).
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class GuardianHeatBandTests: XCTestCase {

    // MARK: Band mapping — lock-safe surface raw → band (pure 1:1 projection of existing semantics)

    func testSurfaceRawMapsToExpectedBand() {
        XCTAssertEqual(GuardianHeatBandV1.band(fromSurfaceRaw: "GUARDIAN_ON"), .clear)
        XCTAssertEqual(GuardianHeatBandV1.band(fromSurfaceRaw: "CAUTION"), .caution)
        XCTAssertEqual(GuardianHeatBandV1.band(fromSurfaceRaw: "SHIELD_MATCH"), .shield)
        XCTAssertEqual(GuardianHeatBandV1.band(fromSurfaceRaw: "UNKNOWN"), .unknown)
        XCTAssertEqual(GuardianHeatBandV1.band(fromSurfaceRaw: "OFF"), .off)
        // Unmapped/garbage → UNKNOWN, never a positive/safe default.
        XCTAssertEqual(GuardianHeatBandV1.band(fromSurfaceRaw: ""), .unknown)
        XCTAssertEqual(GuardianHeatBandV1.band(fromSurfaceRaw: "???"), .unknown)
    }

    func testReelStateRawMapsToExpectedBand() {
        XCTAssertEqual(GuardianHeatBandV1.band(fromReelStateRaw: "PLAYING"), .clear)
        // §2.2 — USER_OVERRIDDEN is its OWN band now (a conscious exception, never auto-green).
        XCTAssertEqual(GuardianHeatBandV1.band(fromReelStateRaw: "USER_OVERRIDDEN"), .userOverridden)
        XCTAssertEqual(GuardianHeatBandV1.band(fromReelStateRaw: "HIDDEN"), .shield)
        XCTAssertEqual(GuardianHeatBandV1.band(fromReelStateRaw: "UNDETERMINED"), .unknown)
        // Pre-decision / transient states are honestly UNKNOWN (no decision yet), never CLEAR.
        XCTAssertEqual(GuardianHeatBandV1.band(fromReelStateRaw: "PENDING_EVALUATION"), .unknown)
        XCTAssertEqual(GuardianHeatBandV1.band(fromReelStateRaw: "EVALUATING"), .unknown)
        XCTAssertEqual(GuardianHeatBandV1.band(fromReelStateRaw: "SKIPPED"), .unknown)
    }

    // MARK: Position — categorical today, continuous, never a 0-100 score

    func testPositionAlwaysInBandRangeAndUnitInterval() {
        for band in [GuardianHeatBandV1.off, .clear, .unknown, .caution, .shield] {
            for c in stride(from: 0.0, through: 1.0, by: 0.1) {
                let m = GuardianHeatMarkerV1.make(band: band, confidence: c)
                XCTAssertGreaterThanOrEqual(m.position, 0.0)
                XCTAssertLessThanOrEqual(m.position, 1.0)
                if band != .off {
                    XCTAssertTrue(band.range.contains(m.position),
                                  "band \(band) pos \(m.position) escaped its range \(band.range)")
                }
            }
        }
    }

    func testBandsAreOrderedCoolToHot() {
        // Confident placements must be strictly ordered clear < unknown < caution < shield on the bar.
        let clear   = GuardianHeatMarkerV1.make(band: .clear, confidence: 1).position
        let unknown = GuardianHeatMarkerV1.make(band: .unknown, confidence: 1).position
        let caution = GuardianHeatMarkerV1.make(band: .caution, confidence: 1).position
        let shield  = GuardianHeatMarkerV1.make(band: .shield, confidence: 1).position
        XCTAssertLessThan(clear, unknown)
        XCTAssertLessThan(unknown, caution)
        XCTAssertLessThan(caution, shield)
    }

    // §2.2 — FIXED categorical anchors: confidence NO LONGER moves the marker within a band (the old coverage-
    // derived 0/1 was not a calibrated probability, so it implied precision we do not have). The position for a
    // given band is IDENTICAL regardless of confidence; confidence survives only as a diagnostic field.
    func testConfidenceDoesNotMoveTheMarkerWithinABand() {
        for band in [GuardianHeatBandV1.clear, .unknown, .caution, .shield, .userOverridden] {
            let hi = GuardianHeatMarkerV1.make(band: band, confidence: 1)
            let lo = GuardianHeatMarkerV1.make(band: band, confidence: 0)
            XCTAssertEqual(hi.position, lo.position, "band \(band) position must be a FIXED anchor, not confidence-driven")
            XCTAssertEqual(hi.position, band.anchor, "position must equal the band's categorical anchor")
            XCTAssertTrue(band.range.contains(hi.position), "anchor must sit inside the band range")
            // confidence is retained as a diagnostic, distinct value.
            XCTAssertEqual(hi.confidence, 1); XCTAssertEqual(lo.confidence, 0)
        }
    }

    // §2.2 — USER_OVERRIDDEN is a distinct band: a conscious exception, NEVER an evidence-clear green state.
    func testUserOverriddenIsDistinctAndNotEvidenceClear() {
        XCTAssertEqual(GuardianHeatBandV1.band(fromReelStateRaw: "USER_OVERRIDDEN"), .userOverridden)
        XCTAssertEqual(GuardianHeatBandV1.band(fromReelStateRaw: "PLAYING"), .clear)   // PLAYING stays CLEAR
        XCTAssertFalse(GuardianHeatBandV1.userOverridden.isEvidenceClear, "override is NOT evidence-clear")
        XCTAssertTrue(GuardianHeatBandV1.clear.isEvidenceClear)
        XCTAssertFalse(GuardianHeatBandV1.userOverridden.impliesAttention)  // a conscious exception is not protection
        // It shares the CLEAR horizontal zone (content plays) but is a SEPARATE band value (own colour/outline).
        XCTAssertEqual(GuardianHeatBandV1.userOverridden.anchor, GuardianHeatBandV1.clear.anchor)
        XCTAssertNotEqual(GuardianHeatBandV1.userOverridden, GuardianHeatBandV1.clear)
    }

    func testUnknownNeverLandsInClearZoneRegardlessOfConfidence() {
        // Rule 7: UNKNOWN is honest abstention — it must never read as CLEAR, no matter the confidence value.
        for c in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let m = GuardianHeatMarkerV1.make(band: .unknown, confidence: c)
            XCTAssertEqual(m.band, .unknown)
            XCTAssertFalse(GuardianHeatBandV1.clear.range.contains(m.position),
                           "UNKNOWN drifted into the CLEAR zone at confidence \(c)")
        }
    }

    func testOffHasNoLiveMarker() {
        let m = GuardianHeatMarkerV1.make(band: .off, confidence: 1)
        XCTAssertFalse(m.isLive)
        XCTAssertEqual(m.position, 0)
        XCTAssertFalse(GuardianHeatBandV1.off.impliesAttention)
    }

    func testOnlyAttentionBandsImplyAttention() {
        XCTAssertTrue(GuardianHeatBandV1.caution.impliesAttention)
        XCTAssertTrue(GuardianHeatBandV1.shield.impliesAttention)
        XCTAssertFalse(GuardianHeatBandV1.clear.impliesAttention)
        XCTAssertFalse(GuardianHeatBandV1.unknown.impliesAttention)   // abstention does NOT claim protection
        XCTAssertFalse(GuardianHeatBandV1.off.impliesAttention)
    }

    // MARK: Content-switch → marker move (pure, in-process; assert the move AND a tight latency bound)

    func testContentSwitchMovesMarkerToNewBand() {
        // Watching a CLEAR reel, then the next content is a real HIDE → the marker must jump to the SHIELD band.
        let before = GuardianHeatMarkerV1.fromReelStateRaw("PLAYING", confidence: 1)
        let after  = GuardianHeatMarkerV1.fromReelStateRaw("HIDDEN", confidence: 1)
        XCTAssertEqual(before.band, .clear)
        XCTAssertEqual(after.band, .shield)
        XCTAssertGreaterThan(after.position, before.position)   // slid toward HOT
    }

    func testMarkerComputationIsSubMillisecond() {
        // The band computation is pure — the "instant" marker move is dominated by this in-process cost, which must
        // be well under a frame. Average over many iterations so we assert a stable bound, not a one-shot fluke.
        let iterations = 10_000
        let raws = ["GUARDIAN_ON", "CAUTION", "SHIELD_MATCH", "UNKNOWN", "OFF"]
        let start = DispatchTime.now().uptimeNanoseconds
        var sink = 0.0
        for i in 0..<iterations {
            let m = GuardianHeatMarkerV1.fromSurfaceRaw(raws[i % raws.count], confidence: Double(i % 11) / 10.0)
            sink += m.position
        }
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        let perCallNanos = Double(elapsed) / Double(iterations)
        XCTAssertGreaterThanOrEqual(sink, 0)   // keep the optimizer honest
        // Generous bound (<0.1ms/call) — the real in-process path is ~sub-microsecond; this just guards a regression.
        XCTAssertLessThan(perCallNanos, 100_000, "band computation \(perCallNanos)ns/call is too slow for 'instant'")
    }

    // MARK: Codable round-trip (the marker crosses into the ActivityKit ContentState as primitives)

    func testMarkerCodableRoundTrip() throws {
        let m = GuardianHeatMarkerV1.make(band: .caution, confidence: 0.6)
        let data = try JSONEncoder().encode(m)
        let back = try JSONDecoder().decode(GuardianHeatMarkerV1.self, from: data)
        XCTAssertEqual(m, back)
    }
}
