import XCTest
@testable import GuardianCore

final class RouterGovernorTests: XCTestCase {
    let router = ModelRouter()
    let gov = ResourceGovernor()

    // MARK: ModelRouter V1
    func testCacheWins() {
        let d = router.route(RouteRequest(task: .topics, cacheAvailable: true))
        XCTAssertEqual(d.engine, .cache)
    }
    func testIdentityUsesDeterministicNotHeavy() {
        let d = router.route(RouteRequest(task: .identity))
        XCTAssertEqual(d.engine, .deterministic)
    }
    func testThermalConstrainedPrefersCheapOrAbstains() {
        let d = router.route(RouteRequest(task: .topics, thermal: .critical, localEngineAvailable: true))
        XCTAssertEqual(d.engine, .appleNative)
        let d2 = router.route(RouteRequest(task: .topics, thermal: .critical, localEngineAvailable: false))
        XCTAssertTrue(d2.abstain)                         // no cheap local → UNKNOWN
    }
    func testLowPowerDegrades() {
        let d = router.route(RouteRequest(task: .sensitive, lowPower: true, localEngineAvailable: true))
        XCTAssertEqual(d.engine, .appleNative)
    }
    func testNoLocalEngineNoNetworkAbstains() {
        let d = router.route(RouteRequest(task: .evidence, localEngineAvailable: false, networkAllowed: false))
        XCTAssertTrue(d.abstain)
    }
    func testPrivacyRestrictedRouteStaysOnDevice() {
        // onDeviceOnly privacy must not go to cloud even if network allowed.
        let d = router.route(RouteRequest(task: .topics, privacy: .onDeviceOnly,
                                          localEngineAvailable: false, networkAllowed: true))
        XCTAssertTrue(d.abstain)
    }

    // MARK: ResourceGovernor V1
    func testThermalForcesEco() {
        let o = gov.evaluate(GovernorInputs(thermal: .serious, schedulerLoad: 3), requested: .maxProtection)
        XCTAssertEqual(o.mode, .eco)
        XCTAssertEqual(o.lookAheadDepth, 1)
        XCTAssertFalse(o.allowDeepAnalysis)
    }
    func testLowPowerForcesEco() {
        let o = gov.evaluate(GovernorInputs(lowPower: true, schedulerLoad: 3), requested: .balanced)
        XCTAssertEqual(o.mode, .eco)
    }
    func testIdleBackgroundNoWork() {
        let o = gov.evaluate(GovernorInputs(foreground: false, schedulerLoad: 0), requested: .balanced)
        XCTAssertEqual(o.lookAheadDepth, 0)
        XCTAssertEqual(o.maxConcurrentAnalyses, 0)         // no inference when idle/background & empty
    }
    func testBalancedBoundedToThree() {
        let o = gov.evaluate(GovernorInputs(schedulerLoad: 5), requested: .balanced)
        XCTAssertEqual(o.mode, .balanced)
        XCTAssertLessThanOrEqual(o.lookAheadDepth, 3)
    }
    func testRecoveryAfterNormalState() {
        _ = gov.evaluate(GovernorInputs(thermal: .serious, schedulerLoad: 3))
        let o = gov.evaluate(GovernorInputs(thermal: .nominal, schedulerLoad: 3), requested: .balanced)
        XCTAssertEqual(o.mode, .balanced)                  // recovers when conditions normalize
    }
}
