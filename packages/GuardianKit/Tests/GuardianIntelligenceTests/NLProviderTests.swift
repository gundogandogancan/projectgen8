import XCTest
import GuardianCore
@testable import GuardianIntelligence

final class NLProviderTests: XCTestCase {
    let p = NLTextSignalProvider()

    func testRealLanguageIdentificationEnglish() async {
        let r = await p.identify("The quick brown fox jumps over the lazy dog every morning.")
        XCTAssertEqual(r.state, .ok)
        XCTAssertEqual(r.value?.language, "en")
        XCTAssertEqual(r.provenance, .appleNaturalLanguage)   // REAL Apple engine, not fixture
    }

    func testRealLanguageIdentificationTurkish() async {
        let r = await p.identify("Bugün hava çok güzel ve kuşlar şarkı söylüyor.")
        XCTAssertEqual(r.state, .ok)
        XCTAssertEqual(r.value?.language, "tr")
    }

    func testTooShortIsUnknownNotGuessed() async {
        let r = await p.identify("a")
        XCTAssertEqual(r.state, .unknown)                     // honest UNKNOWN, no fabricated guess
    }

    func testTopicsExtractNouns() async {
        let r = await p.topics("Guardian protects attention and learning on the device.")
        XCTAssertEqual(r.state, .ok)
        XCTAssertFalse((r.value?.topics ?? []).isEmpty)
    }
}
