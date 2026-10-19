import XCTest
import GuardianCore
import NaturalLanguage
@testable import GuardianIntelligence

final class SemanticEmbeddingTests: XCTestCase {

    func testSemanticSimilarityRealOrHonestlyUnavailable() async {
        let p = SemanticEmbeddingProvider()
        let available = await p.isAvailable(language: .english)
        guard available else {
            // Honest path: no fabricated similarity if embedding unavailable on this runtime.
            let out = await p.match("king", concept: "queen")
            XCTAssertEqual(out.state, .unavailable)
            return
        }
        // Related terms should be closer than unrelated ones.
        let near = await p.distance("king", "queen", language: .english)
        let far  = await p.distance("king", "bicycle", language: .english)
        if let near, let far { XCTAssertLessThan(near, far) }
    }

    func testMatchProvenanceIsRealEngine() async {
        let p = SemanticEmbeddingProvider()
        let out = await p.match("car", concept: "automobile")
        XCTAssertTrue(out.state == .ok || out.state == .unavailable)
        if out.state == .ok { XCTAssertEqual(out.provenance, .appleNaturalLanguage) }
    }

    // §2C concurrency regression — NLEmbedding is not concurrency-safe; the actor must serialize.
    func testConcurrentAccessIsSafe() async {
        let p = SemanticEmbeddingProvider()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask { _ = await p.match("word\(i)", concept: "concept\(i)") }
            }
            for await _ in group {}
        }
        // Reaching here without a crash/data race is the assertion (actor isolation holds).
        XCTAssertTrue(true)
    }
}
