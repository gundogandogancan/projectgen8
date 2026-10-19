import XCTest
import GuardianCore
@testable import GuardianIntelligence

final class IdentityV1Tests: XCTestCase {
    let r = ContentIdentityResolverV1()

    private func bytes(_ s: String) -> Data { Data(s.utf8) }

    func testExactHashDeterministicAndStable() {
        let a = r.exactHash(bytes("hello guardian"))
        let b = r.exactHash(bytes("hello guardian"))
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 64)                 // SHA-256 hex
    }

    func testExactSameFileIsI4() {
        let data = bytes(String(repeating: "abcdefgh", count: 64))
        let ref = r.perceptualHash(data)
        let res = r.resolve(contentID: .init("vid-x"), bytes: data, versionTag: "v1", referencePerceptual: ref)
        XCTAssertEqual(res.state, .i4_verified)
        XCTAssertGreaterThan(res.confidence, 0.95)
    }

    func testReEncodedSimilarStaysStrong() {
        // Same content, slightly perturbed tail bytes (simulated re-encode) → still I3+ (tolerant).
        var original = [UInt8](repeating: 0, count: 256)
        for i in 0..<256 { original[i] = UInt8(i) }
        let ref = r.perceptualHash(Data(original))
        var reenc = original
        for i in 250..<256 { reenc[i] = reenc[i] &+ 1 }   // tiny perturbation
        let res = r.resolve(contentID: .init("vid-x"), bytes: Data(reenc), versionTag: "v1", referencePerceptual: ref)
        XCTAssertTrue(res.state == .i4_verified || res.state == .i3_strong)
    }

    func testDifferentContentIsNotFalseMatched() {
        var a = [UInt8](repeating: 0, count: 256); for i in 0..<256 { a[i] = UInt8(i) }
        var b = [UInt8](repeating: 0, count: 256); for i in 0..<256 { b[i] = UInt8((i * 97 + 13) % 256) }
        let ref = r.perceptualHash(Data(a))
        let res = r.resolve(contentID: .init("vid-y"), bytes: Data(b), versionTag: "v1", referencePerceptual: ref)
        XCTAssertNotEqual(res.state, .i4_verified)          // must not false-match
        XCTAssertLessThan(res.confidence, 0.85)
    }

    func testTextFingerprintNormalizes() {
        let a = r.textFingerprint("Hello   World")
        let b = r.textFingerprint("hello world")
        XCTAssertEqual(a, b)                                // case/whitespace normalized
    }
}
