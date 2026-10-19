import XCTest
@testable import GuardianCore

final class ContentDNATests: XCTestCase {

    private func sampleDNA(_ id: String, version: String = "v1") -> ContentDNAV1 {
        ContentDNAV1(contentID: id, identityState: "I4_VERIFIED", versionTag: version,
                     exactHash: "deadbeef", perceptualHash: [1,0,1,0],
                     language: "en", topics: ["learning"], entities: ["Swift"],
                     sensitiveCategories: [], engineVersions: ["identity": "identity-v1"],
                     freshnessNanos: 1, provenance: .perceptualHash, confidence: 0.9)
    }

    func testCodableRoundTrip() throws {
        let dna = sampleDNA("c1")
        let data = try JSONEncoder().encode(dna)
        let back = try JSONDecoder().decode(ContentDNAV1.self, from: data)
        XCTAssertEqual(dna, back)                          // serializable + versioned
    }

    func testStoreGetVersionInvalidation() async {
        let store = ContentDNAStore()
        await store.put(sampleDNA("c1", version: "v1"))
        let hit = await store.get("c1", versionTag: "v1")
        XCTAssertNotNil(hit)
        let miss = await store.get("c1", versionTag: "v2")   // version mismatch → invalidated
        XCTAssertNil(miss)
    }

    func testBoundedPersistence() async {
        let store = ContentDNAStore(capacity: 2)
        for i in 0..<5 { await store.put(sampleDNA("c\(i)")) }
        let count = await store.count
        XCTAssertLessThanOrEqual(count, 2)
    }

    func testNoRawMediaFieldsExist() {
        // Structural guarantee: ContentDNAV1 has NO Data/frame/video property (compile-time contract).
        let mirror = Mirror(reflecting: sampleDNA("c1"))
        for child in mirror.children {
            XCTAssertFalse(child.value is Data, "ContentDNA must not store raw bytes: \(child.label ?? "")")
        }
    }
}
