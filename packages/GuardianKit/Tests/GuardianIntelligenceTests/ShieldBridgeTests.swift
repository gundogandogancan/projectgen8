import XCTest
import CoreGraphics
@testable import GuardianCore
@testable import GuardianIntelligence

final class ShieldBridgeTests: XCTestCase {

    // §12 real NLEmbedding semantic distance; honest skip if no embedding on this runtime (never fake it).
    func testRealSemanticDistanceOrdering() throws {
        let d = ShieldSemanticDistance()
        guard let near = d.distance("a violent bloody fight", "graphic violence", "en"),
              let far  = d.distance("a calm sunny picnic", "graphic violence", "en") else {
            throw XCTSkip("NLEmbedding unavailable on this runtime — honest UNAVAILABLE, not a fake pass.")
        }
        XCTAssertLessThan(near, far, "related text should be semantically closer to the concept than unrelated text")
    }

    // §4,§12 wiring the real distance into the pure-core evaluator produces a deterministic action.
    func testEvaluatorWithRealSemanticDistance() throws {
        let bridge = ShieldSemanticDistance()
        guard bridge.distance("test", "test", "en") != nil else {
            throw XCTSkip("NLEmbedding unavailable — semantic path honestly inactive.")
        }
        var idx = ShieldIndex()
        idx.upsert(ShieldRuleV2(ruleID: "viol", inputType: .semanticConcept, rawUserLabel: "graphic violence", action: .warn))
        let ev = ShieldEvaluatorV2.standard(semanticDistance: bridge.closure)
        var e = ContentObservationEnvelope()
        e.structuredText = [TextSource(origin: .structured, text: "an extremely violent and bloody brawl")]
        let out = ev.evaluate(.init(envelope: e), index: idx)
        XCTAssertTrue([.matchHigh, .matchMedium, .matchLow].contains(out.matchState))
        XCTAssertNotEqual(out.actionRecommendation, .hideIfControlled)   // never silent hide from a semantic-only signal
    }

    // 006C — ingestion derives a serializable signature (no pixels) and a durable DerivedReferenceFeature.
    func testImageReferenceIngestionDerivesSerializableSignature() throws {
        let ingestor = ShieldImageReferenceIngestor()
        guard let img = SyntheticImage.textImage("SHIELD TARGET") else { XCTFail("no synthetic image"); return }
        guard let out = ingestor.ingest(cgImage: img, ruleID: "r1", nowEpoch: 1) else { XCTFail("ingest failed"); return }
        XCTAssertEqual(out.signature.formatVersion, PersistedVisualReferenceSignature.formatVersion)
        XCTAssertTrue(out.signature.allIntact)
        XCTAssertEqual(out.signature.components.count, 3)       // aHash + dHash + normVector
        XCTAssertGreaterThan(out.feature.serializedFeature.count, 0)
        XCTAssertEqual(out.feature.featureType, .image)
        // Re-decode proves the persisted bytes are self-contained (no live object needed).
        XCTAssertEqual(ShieldVisualReferenceMatcher.decodeSignature(out.feature), out.signature)
    }

    // 006C §5 discrimination + variants are proven with structured fixtures in P006CVisualDurabilityTests
    // (perceptual hashing needs spatial structure; sparse text-on-white is an adversarial fixture — documented).

    // 006C §7 — a signature from an incompatible engine revision → MATCHER_UNAVAILABLE (reauthoring), never a false match.
    func testIncompatibleSignatureRevisionUnavailable() throws {
        let ingestor = ShieldImageReferenceIngestor(engine: VisualSignatureEngine(engineRevision: "sig-r0"))  // stale
        let matcher = ShieldVisualReferenceMatcher(engine: VisualSignatureEngine())                            // current sig-r1
        guard let ref = SyntheticImage.textImage("OLD"), let frame = SyntheticImage.textImage("OLD") else { XCTFail("img"); return }
        guard let out = ingestor.ingest(cgImage: ref, ruleID: "r", nowEpoch: 1) else { XCTFail("ingest"); return }
        let m = matcher.match(frame: frame, reference: out.signature)
        XCTAssertEqual(m.state, .matcherUnavailable)
        XCTAssertEqual(m.reason, .referenceReauthoring)
    }
}
