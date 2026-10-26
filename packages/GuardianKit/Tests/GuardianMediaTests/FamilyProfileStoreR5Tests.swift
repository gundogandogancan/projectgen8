//
//  FamilyProfileStoreR5Tests.swift — R5 §2 (P0-1): the shared family profile store laws.
//  Crash-safe atomic persistence, honest state derivation (VALID/MISSING/STALE/CORRUPT/UNSUPPORTED), revision
//  invalidation, deletion, and STRICT independence from the personal shield policy (adult↔child switches must
//  never disturb personal shield rules — pinned here).
//
import XCTest
@testable import GuardianMedia
import GuardianCore

final class FamilyProfileStoreR5Tests: XCTestCase {

    private var dir: URL!
    private var suiteName: String!
    private var suite: UserDefaults!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("family-r5-\(UUID().uuidString)")
        suiteName = "gen8.family.r5.tests.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func makeStore() -> FamilyProfileSharedStoreV1 {
        FamilyProfileSharedStoreV1(directory: dir, suite: suite, sharedContainerActive: true)
    }

    private func childProfile(age: Int = 9, jurisdiction: String = "TR",
                              declaration: Bool = true) -> FamilyProfileV1 {
        FamilyProfileV1(mode: .child, parentEnteredAgeYears: age, parentDeclaration: declaration,
                        jurisdictionCode: jurisdiction, createdEpoch: 1000, modifiedEpoch: 1000)
    }

    // MARK: states

    func testMissingWhenNothingStored() {
        let r = makeStore().load()
        XCTAssertNil(r.profile)
        XCTAssertEqual(r.state, .missing)
        XCTAssertFalse(r.corruptRecovered)
    }

    func testSaveThenLoadValidAndRevisionBumps() {
        let store = makeStore()
        let before = store.familyRevision
        let rev = store.save(childProfile())
        XCTAssertNotNil(rev)
        XCTAssertEqual(rev, before &+ 1)
        let r = store.load()
        XCTAssertEqual(r.state, .valid)
        XCTAssertEqual(r.profile?.mode, .child)
        XCTAssertEqual(r.profile?.parentEnteredAgeYears, 9)
        XCTAssertEqual(r.profile?.profileRevision, rev)
        XCTAssertEqual(r.liveRevision, rev)
    }

    func testCorruptFileRecoveredAndSurfaced() throws {
        let store = makeStore()
        _ = store.save(childProfile())
        // Corrupt the stored bytes directly (simulated disk corruption / incompatible blob).
        try Data("NOT-JSON{{{".utf8).write(to: dir.appendingPathComponent(FamilyProfileSharedStoreV1.fileName))
        let r = store.load()
        XCTAssertEqual(r.state, .corrupt)
        XCTAssertNil(r.profile)                 // recovered to no-profile
        XCTAssertTrue(r.corruptRecovered)       // SURFACED, never silent
        // Recovery: a fresh save fully restores a valid profile.
        XCTAssertNotNil(store.save(childProfile(age: 10)))
        XCTAssertEqual(store.load().state, .valid)
    }

    func testStaleWhenSharedRevisionIsAheadOfReadableFile() {
        let store = makeStore()
        _ = store.save(childProfile())
        // Another writer advanced the shared counter past what this file carries (e.g. our file view is behind).
        suite.set(Int64(bitPattern: store.familyRevision &+ 5), forKey: FamilyProfileSharedStoreV1.familyRevisionKey)
        let r = store.load()
        XCTAssertEqual(r.state, .stale)          // NEVER presented as fresh
        XCTAssertNotNil(r.profile)               // the stale bytes are returned for DISPLAY, state says not-current
    }

    func testUnsupportedJurisdictionFailsClosedAtState() {
        let store = makeStore()
        _ = store.save(childProfile(jurisdiction: "DE"))   // not in the frozen registry (TR/US/EU)
        XCTAssertEqual(store.load().state, .unsupported)
    }

    func testDeleteRemovesProfileAndBumpsRevision() {
        let store = makeStore()
        _ = store.save(childProfile())
        let revBefore = store.familyRevision
        XCTAssertTrue(store.delete())
        XCTAssertEqual(store.load().state, .missing)
        XCTAssertEqual(store.familyRevision, revBefore &+ 1)   // deletion IS a policy change → invalidation
    }

    // MARK: crash safety

    func testCrashBetweenFileWriteAndPublishSelfHeals() throws {
        let store = makeStore()
        _ = store.save(childProfile())
        let live = store.familyRevision
        // Simulate the crash window: the NEXT save wrote the file (embedded revision live+1) + the intent, but
        // crashed BEFORE publishing the suite revision. Reproduce that exact disk state by hand.
        var ahead = childProfile(age: 11)
        ahead.profileRevision = live &+ 1
        try JSONEncoder().encode(ahead).write(to: dir.appendingPathComponent(FamilyProfileSharedStoreV1.fileName))
        try Data(#"{"targetRevision": \#(live &+ 1), "epoch": 123.0}"#.utf8)
            .write(to: dir.appendingPathComponent(FamilyProfileSharedStoreV1.intentFileName))
        let r = store.load()
        XCTAssertEqual(r.state, .valid)                       // self-healed: publish finished on load
        XCTAssertEqual(store.familyRevision, live &+ 1)
        XCTAssertEqual(r.profile?.parentEnteredAgeYears, 11)  // no half-profile anywhere
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent(FamilyProfileSharedStoreV1.intentFileName).path))
    }

    // MARK: independence from the personal shield (mandate §2: switching adult↔child must not disturb shield rules)

    func testFamilyChangesNeverTouchPersonalShieldRevision() {
        let shieldDir = FileManager.default.temporaryDirectory.appendingPathComponent("shield-r5-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: shieldDir) }
        let shield = PersonalShieldSharedStoreV1(directory: shieldDir, suite: suite)
        let shieldRevBefore = shield.policyRevision
        let family = makeStore()
        _ = family.save(childProfile())                                  // adult → child
        var adult = childProfile(); adult.mode = .adult; adult.parentEnteredAgeYears = nil
        _ = family.save(adult)                                           // child → adult
        _ = family.delete()
        XCTAssertEqual(shield.policyRevision, shieldRevBefore)           // personal shield UNTOUCHED
        // And the inverse: a shield bump never advances the family revision.
        let famRev = family.familyRevision
        shield.bumpPolicyRevision()
        XCTAssertEqual(family.familyRevision, famRev)
    }

    // MARK: engine-input honesty

    func testGuardianProfileFailsClosedWithoutDeclarationOrAge() {
        // No declaration → the frozen engine must see enteredByGuardian=false (it then fails closed itself).
        let noDecl = childProfile(declaration: false).guardianEnteredProfile
        XCTAssertFalse(noDecl.enteredByGuardian)
        // No age → same law (sentinel age + not attested; never a fabricated attested age).
        var noAge = childProfile(); noAge.parentEnteredAgeYears = nil
        XCTAssertFalse(noAge.guardianEnteredProfile.enteredByGuardian)
        // Proper child entry → attested, real age.
        let ok = childProfile().guardianEnteredProfile
        XCTAssertTrue(ok.enteredByGuardian)
        XCTAssertEqual(ok.ageYears, 9)
    }

    func testParentPreferencesAreStricterOnlyMapping() {
        var p = childProfile()
        p.extraCautionFearThreat = true
        p.extraCautionManipulation = true
        p.blockSensitiveNews = true
        let pref = p.parentPreferencePolicy
        XCTAssertTrue(pref.extraCautionDimensions.contains(.fearThreat))
        XCTAssertTrue(pref.extraCautionDimensions.contains(.manipulationAttention))
        XCTAssertTrue(pref.blockSensitiveNews)
        // The frozen type has NO loosening field — structurally stricter-only. Empty prefs = empty overlay.
        let none = childProfile().parentPreferencePolicy
        XCTAssertTrue(none.extraCautionDimensions.isEmpty)
        XCTAssertFalse(none.blockSensitiveNews)
    }

    func testDegradedNilSuiteNeverFakesSharedRevision() {
        let degraded = FamilyProfileSharedStoreV1(directory: dir, suite: nil, sharedContainerActive: false)
        XCTAssertEqual(degraded.familyRevision, 0)      // honest: no shared counter readable
        _ = degraded.save(childProfile())
        let r = degraded.load()
        // The file itself is intact; state cannot claim shared-freshness (suite nil → no stale detection, but the
        // store reports sharedContainerActive=false so the caller knows the extension would see MISSING).
        XCTAssertFalse(r.sharedContainerActive)
        XCTAssertNotNil(r.profile)
    }
}
