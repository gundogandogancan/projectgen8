import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC PRE-14 R2 BUILDER TESTS — fresh family for the AUDIT15 remediation (A15-F1..F12 + coupled).
// Zero AUDIT15 probe inversions (supersession strategy): these tests prove the NEW canonical V2/V3
// laws; the AUDIT15 pins keep proving the OLD V1 defects on the byte-frozen V1 surfaces.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class RWCPreregistrationR2Tests: XCTestCase {

    // MARK: helpers

    private func repoRoot() -> URL { RWCPowerDerivationV3.repoRootURL() }

    private func sha256(_ rel: String) throws -> String {
        let d = try Data(contentsOf: repoRoot().appendingPathComponent(rel))
        return SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }

    private func read(_ rel: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(rel), encoding: .utf8)
    }

    private func json(_ rel: String) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: repoRoot().appendingPathComponent(rel))) as! [String: Any]
    }

    private func date(_ s: String) -> RWCDateV2 { try! RWCDateV2.parse(s, field: "test") }
    private func clock(_ s: String) -> RWCFixedClockV1 { try! RWCFixedClockV1(s) }

    private func evidence(_ suffix: String, digestSeed: String) -> RWCRightsEvidenceIdentityV1 {
        let digest = SHA256.hash(data: Data(digestSeed.utf8)).map { String(format: "%02x", $0) }.joined()
        return RWCRightsEvidenceIdentityV1(pointer: "rwc-rights-ref-\(suffix)", evidenceDigest: digest,
                                           evidenceVersion: "v1.0")
    }

    private func record(id: String = "rwc-asset-r2aaaa01", acquisition: String = "2026-09-01",
                        expiry: String? = "2027-09-01", evidence ev: RWCRightsEvidenceIdentityV1? = nil,
                        allowed: [String] = ["training", "evaluation"], prohibited: [String] = [],
                        training: Bool = true, evaluation: Bool = true,
                        hashSeed: String = "content-a") -> RWCAssetRightsRecordV2 {
        let contentHash = SHA256.hash(data: Data(hashSeed.utf8)).map { String(format: "%02x", $0) }.joined()
        return RWCAssetRightsRecordV2(
            assetID: id, sourceClass: .licensedRightsClear, sourceReference: "rwc-source-ref-r2src01",
            owner: "gen8", rightsHolder: "licensor-a", licenseType: "written-license",
            evidence: ev ?? evidence("r2ev0001", digestSeed: "proof-a"),
            allowedUse: allowed, prohibitedUse: prohibited, trainingAllowed: training,
            evaluationAllowed: evaluation, acquisitionDate: date(acquisition),
            expiryDate: expiry.map { date($0) }, contentHash: contentHash,
            provenanceChain: ["rwc-source-ref-r2src01"])
    }

    private func expectV2(_ expected: RWCRightsErrorV2, _ body: () throws -> Void,
                          file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try body(), file: file, line: line) { e in
            XCTAssertEqual(e as? RWCRightsErrorV2, expected, file: file, line: line)
        }
    }

    // MARK: 1 — discipline

    func testR2_Discipline_FrozenOriginal_ZeroInversions_AuditEvidenceIntact() throws {
        let locked = try sha256("docs/audit/AUDIT15_RWCPre14R1ReauditProbes_ORIGINAL_LOCKED.swift.txt")
        XCTAssertEqual(locked, "a68a8d5013f3fa51c7b41972fb3b38bc9b73be2c9aaf1411b2cfa3c80bd9fc4d")
        // ZERO-INVERSION PROOF: the ACTIVE AUDIT15 probe file is byte-identical to the frozen original.
        let active = try sha256("packages/GuardianKit/Tests/GuardianCoreTests/AUDIT15_RWCPre14R1ReauditProbes.swift")
        XCTAssertEqual(active, locked)
        let lock = try read("docs/audit/AUDIT15_R2_INVERSION_LOCK.md")
        XCTAssertTrue(lock.contains("ZERO INVERSIONS DECLARED"))
        XCTAssertTrue(lock.contains("SUPERSESSION, NOT MUTATION"))
        let report = try read("docs/audit/GEN8_RWC_PREREGISTRATION_PRE14_R1_INDEPENDENT_REAUDIT.md")
        XCTAssertTrue(report.contains("FIX REQUIRED"))
        // AUDIT14 negative-evidence chain untouched
        XCTAssertEqual(try sha256("docs/audit/AUDIT14_RWCPreregistrationPre14Probes_ORIGINAL_LOCKED.swift.txt"),
                       "18ac2633dd55e6073cf80be309db75af3f07c96a2bedd62cf8a360c246186886")
    }

    // MARK: 2 — A15-F1 real Gregorian dates

    func testR2_F1_RealGregorianDateLaw() throws {
        XCTAssertNoThrow(try RWCDateV2.parse("2028-02-29", field: "d"))   // leap
        XCTAssertNoThrow(try RWCDateV2.parse("2000-02-29", field: "d"))   // 400-rule leap
        XCTAssertNoThrow(try RWCDateV2.parse("0000-01-01", field: "d"))
        XCTAssertNoThrow(try RWCDateV2.parse("9999-12-31", field: "d"))
        for bad in ["2026-02-29", "1900-02-29", "2026-02-30", "2026-02-31", "2026-04-31",
                    "2026-06-31", "2026-00-01", "2026-13-01", "2026-01-00", "2026-01-32"] {
            XCTAssertThrowsError(try RWCDateV2.parse(bad, field: "d"), bad) { e in
                XCTAssertEqual(e as? RWCRightsErrorV2, .impossibleDate(field: "d"), bad)
            }
        }
        for malformed in ["2026-1-01", "2026-01-1", "2026/01/01", " 2026-01-01", "2026-01-01\n",
                          "2026-01-01 ", "٢٠٢٦-٠١-٠١", "２０２６-01-01", "2026-01", "not-a-date", ""] {
            XCTAssertThrowsError(try RWCDateV2.parse(malformed, field: "d"), malformed) { e in
                XCTAssertEqual(e as? RWCRightsErrorV2, .malformedDate(field: "d"), malformed)
            }
        }
        XCTAssertTrue(date("2026-02-28") < date("2026-03-01"))
        XCTAssertTrue(date("2025-12-31") < date("2026-01-01"))
        // store refuses impossible dates structurally (parse boundary — cannot even construct)
        let store = RWCAssetRightsLedgerStoreV2()
        XCTAssertThrowsError(try store.register(record(), clock: RWCFixedClockV1("2026-02-31")))
        // acquisition clock: known civil-from-epoch vectors (UTC)
        XCTAssertEqual(RWCAcquisitionClockV1(secondsSince1970: { 0 }).today(), date("1970-01-01"))
        XCTAssertEqual(RWCAcquisitionClockV1(secondsSince1970: { 86_399 }).today(), date("1970-01-01"))
        XCTAssertEqual(RWCAcquisitionClockV1(secondsSince1970: { 86_400 }).today(), date("1970-01-02"))
        XCTAssertEqual(RWCAcquisitionClockV1(secondsSince1970: { 951_782_400 }).today(), date("2000-02-29"))
    }

    // MARK: 3 — A15-F1/F16 expiry + registration time laws

    func testR2_F1F16_ExpiryBoundary_RegistrationTimeLaws() throws {
        let store = RWCAssetRightsLedgerStoreV2()
        try store.register(record(expiry: "2026-12-31"), clock: clock("2026-10-01"))
        // valid THROUGH expiry
        XCTAssertNoThrow(try store.requireEligible(assetID: "rwc-asset-r2aaaa01", use: .training,
                                                   clock: clock("2026-12-31")))
        expectV2(.expired) { try store.requireEligible(assetID: "rwc-asset-r2aaaa01", use: .training,
                                                       clock: self.clock("2027-01-01")) }
        // NO TIME TRAVEL: query dated before the last event is refused (A15-F16)
        expectV2(.chronologyViolation(rule: "eligibility query date >= last event date")) {
            try store.requireEligible(assetID: "rwc-asset-r2aaaa01", use: .training,
                                      clock: self.clock("2026-09-15"))
        }
        // already-expired registration refused (A15-F16)
        let s2 = RWCAssetRightsLedgerStoreV2()
        expectV2(.expiredAtRegistration) {
            try s2.register(self.record(acquisition: "2026-01-01", expiry: "2026-06-30"),
                            clock: self.clock("2026-10-01"))
        }
        // future acquisition refused
        expectV2(.acquisitionInFuture) {
            try s2.register(self.record(acquisition: "2026-12-01", expiry: nil), clock: self.clock("2026-10-01"))
        }
        // expiry before acquisition refused at record level
        expectV2(.dateOrderViolation(rule: "expiryDate >= acquisitionDate")) {
            try s2.register(self.record(acquisition: "2026-09-01", expiry: "2026-08-01"),
                            clock: self.clock("2026-10-01"))
        }
    }

    // MARK: 4 — A15-F2 chronology

    func testR2_F2_EventChronologyLaws() throws {
        let store = RWCAssetRightsLedgerStoreV2()
        try store.register(record(), clock: clock("2026-10-01"))
        // revoke dated BEFORE the registration event: refused
        expectV2(.chronologyViolation(rule: "revocation recordedDate >= previous event date")) {
            try store.revoke(assetID: "rwc-asset-r2aaaa01", clock: self.clock("2020-01-01"))
        }
        try store.revoke(assetID: "rwc-asset-r2aaaa01", clock: clock("2026-10-10"))
        // reauthorize dated BEFORE the revocation: refused
        expectV2(.chronologyViolation(rule: "reauthorization recordedDate >= previous event date")) {
            try store.reauthorize(self.record(acquisition: "2026-10-12",
                                              evidence: self.evidence("r2ev0002", digestSeed: "proof-b")),
                                  clock: self.clock("2019-06-01"))
        }
        // new grant acquisition must be >= revocation date
        expectV2(.dateOrderViolation(rule: "reauthorized acquisitionDate >= revocationDate")) {
            try store.reauthorize(self.record(acquisition: "2026-10-05",
                                              evidence: self.evidence("r2ev0002", digestSeed: "proof-b")),
                                  clock: self.clock("2026-10-20"))
        }
        // malformed clock date is a typed malformedDate at the clock boundary — never acquisitionInFuture
        XCTAssertThrowsError(try RWCFixedClockV1("not-a-date")) { e in
            XCTAssertEqual(e as? RWCRightsErrorV2, .malformedDate(field: "clock"))
        }
        // lawful reauthorization with coherent chronology
        XCTAssertNoThrow(try store.reauthorize(record(acquisition: "2026-10-12",
                                                      evidence: evidence("r2ev0002", digestSeed: "proof-b")),
                                               clock: clock("2026-10-20")))
        // event dates are monotone in the chain
        let dates = store.events.map(\.recordedDate)
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertEqual(store.events.map(\.kind), ["registered", "revoked", "reauthorized"])
    }

    // MARK: 5 — A15-F13 use-agnostic registration + use truth

    func testR2_F13_TrainingOnlyRegistration_UseTruth() throws {
        let store = RWCAssetRightsLedgerStoreV2()
        let trainingOnly = record(allowed: ["training"], prohibited: ["evaluation"],
                                  training: true, evaluation: false)
        XCTAssertNoThrow(try store.register(trainingOnly, clock: clock("2026-10-01")))   // A15-F13 closed
        XCTAssertNoThrow(try store.requireEligible(assetID: "rwc-asset-r2aaaa01", use: .training,
                                                   clock: clock("2026-10-02")))
        expectV2(.useNotAllowed(use: "evaluation")) {
            try store.requireEligible(assetID: "rwc-asset-r2aaaa01", use: .evaluation,
                                      clock: self.clock("2026-10-02"))
        }
        // contradiction battery (typed at registration)
        let s2 = RWCAssetRightsLedgerStoreV2()
        let cases: [RWCAssetRightsRecordV2] = [
            record(allowed: ["training"], prohibited: [], training: true, evaluation: true),       // flag not mirrored
            record(allowed: ["training", "evaluation"], prohibited: ["training"],
                   training: true, evaluation: true),                                              // granted+prohibited
            record(allowed: ["Training"], prohibited: [], training: true, evaluation: false),      // case variant
            record(allowed: ["training", "training"], prohibited: [], training: true,
                   evaluation: false),                                                             // duplicate (refused in V2)
            record(allowed: ["finetuning"], prohibited: [], training: false, evaluation: false),   // unknown token
        ]
        for (i, r) in cases.enumerated() {
            XCTAssertThrowsError(try s2.register(r, clock: clock("2026-10-01")), "case \(i)") { e in
                guard case .useConsistencyViolation = e as? RWCRightsErrorV2 else {
                    return XCTFail("case \(i): \(e)")
                }
            }
        }
    }

    // MARK: 6 — A15-F3 evidence identity / relicense

    func testR2_F3_EvidenceDigestIdentity_RelicenseLaw() throws {
        let store = RWCAssetRightsLedgerStoreV2()
        try store.register(record(evidence: evidence("r2ev0001", digestSeed: "proof-a")),
                           clock: clock("2026-10-01"))
        try store.revoke(assetID: "rwc-asset-r2aaaa01", clock: clock("2026-10-10"))
        // SAME digest under a RENAMED pointer: refused forever (A15-F3 closed)
        expectV2(.reauthorizationRequiresNewEvidence) {
            try store.reauthorize(self.record(acquisition: "2026-10-12",
                                              evidence: self.evidence("r2ev0001x", digestSeed: "proof-a")),
                                  clock: self.clock("2026-10-15"))
        }
        // register can NEVER revive a tombstone — even with new evidence
        expectV2(.resurrectionRefused) {
            try store.register(self.record(acquisition: "2026-10-12",
                                           evidence: self.evidence("r2ev0009", digestSeed: "proof-z")),
                               clock: self.clock("2026-10-15"))
        }
        // genuinely NEW evidence identity reauthorizes lawfully
        XCTAssertNoThrow(try store.reauthorize(record(acquisition: "2026-10-12",
                                                      evidence: evidence("r2ev0002", digestSeed: "proof-b")),
                                               clock: clock("2026-10-15")))
        // ... and the OLD digest stays dead after a second revocation
        try store.revoke(assetID: "rwc-asset-r2aaaa01", clock: clock("2026-10-20"))
        expectV2(.reauthorizationRequiresNewEvidence) {
            try store.reauthorize(self.record(acquisition: "2026-10-21",
                                              evidence: self.evidence("r2evfinal", digestSeed: "proof-a")),
                                  clock: self.clock("2026-10-22"))
        }
        // pointer grammar V2: dashes-only refused (A15-F18), >=1 alphanumeric required
        let dashOnly = RWCRightsEvidenceIdentityV1(pointer: "rwc-rights-ref-----",
                                                   evidenceDigest: evidence("x", digestSeed: "p").evidenceDigest,
                                                   evidenceVersion: "v1.0")
        expectV2(.invalidEvidencePointer(field: "evidence.pointer")) {
            try RWCRightsLawV2.validateRecord(self.record(evidence: dashOnly))
        }
        // digest grammar: uppercase / short refused
        let badDigest = RWCRightsEvidenceIdentityV1(pointer: "rwc-rights-ref-okay1",
                                                    evidenceDigest: String(repeating: "A", count: 64),
                                                    evidenceVersion: "v1.0")
        expectV2(.invalidEvidenceDigest) { try RWCRightsLawV2.validateRecord(self.record(evidence: badDigest)) }
    }

    // MARK: 7 — A15-F4 canonical SHA-256 event chain

    func testR2_F4_CanonicalEventChain_KnownVectors_CrossProcessWitness() throws {
        // genesis constant = SHA-256 of the versioned string (recomputed independently here)
        let genesis = SHA256.hash(data: Data("GEN8-RWC-RIGHTS-CHAIN-V2-GENESIS".utf8))
            .map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(RWCRightsEventV2.genesisDigest, genesis)
        let store = RWCAssetRightsLedgerStoreV2()
        try store.register(record(), clock: clock("2026-10-01"))
        try store.revoke(assetID: "rwc-asset-r2aaaa01", clock: clock("2026-10-10"))
        let e0 = store.events[0], e1 = store.events[1]
        XCTAssertEqual(e0.previousDigest, genesis)
        XCTAssertEqual(e1.previousDigest, e0.eventDigest)
        XCTAssertEqual(e0.eventDigest.count, 64)   // SHA-256, not Hasher-16
        XCTAssertTrue(e0.eventDigest.allSatisfy { "0123456789abcdef".contains($0) })
        // independent canonical-bytes reconstruction (length-prefixed law) → identical digest
        var manual = Data()
        for f in ["rwc-rights-event-v2", "0", genesis, "rwc-asset-r2aaaa01", "registered",
                  e0.evidenceDigest, "2026-09-01", "2026-10-01"] {
            var len = UInt32(f.utf8.count).bigEndian
            withUnsafeBytes(of: &len) { manual.append(contentsOf: $0) }
            manual.append(Data(f.utf8))
        }
        let manualDigest = SHA256.hash(data: manual).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(manualDigest, e0.eventDigest)
        // CROSS-PROCESS WITNESS: an external process (shasum) computes the same digest
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("r2-canon-\(UUID().uuidString)")
        try manual.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/shasum")
        p.arguments = ["-a", "256", tmp.path]
        let pipe = Pipe(); p.standardOutput = pipe
        try p.run(); p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertTrue(out.hasPrefix(e0.eventDigest), "external shasum disagrees: \(out)")
        // determinism across independent store instances (same logical sequence)
        let store2 = RWCAssetRightsLedgerStoreV2()
        try store2.register(record(), clock: clock("2026-10-01"))
        try store2.revoke(assetID: "rwc-asset-r2aaaa01", clock: clock("2026-10-10"))
        XCTAssertEqual(store2.events.map(\.eventDigest), store.events.map(\.eventDigest))
    }

    // MARK: 8 — A15-F4 durable journal

    func testR2_F4_Journal_Replay_Tamper_Reorder_Truncate() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("r2-journal-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("rights.jsonl")
        let journal = RWCAssetRightsJournalV1(url: url)
        let store = RWCAssetRightsLedgerStoreV2(journal: journal)
        try store.register(record(), clock: clock("2026-10-01"))
        try store.revoke(assetID: "rwc-asset-r2aaaa01", clock: clock("2026-10-10"))
        try store.reauthorize(record(acquisition: "2026-10-12",
                                     evidence: evidence("r2ev0002", digestSeed: "proof-b")),
                              clock: clock("2026-10-15"))
        // startup replay reproduces the exact chain
        let replayed = try RWCAssetRightsJournalV1.replay(url: url)
        XCTAssertEqual(replayed.map(\.eventDigest), store.events.map(\.eventDigest))
        XCTAssertNoThrow(try RWCAssetRightsJournalV1.verifyHead(url: url, expectedHeadDigest: store.headDigest,
                                                                expectedCount: 3))
        let original = try String(contentsOf: url, encoding: .utf8)
        var lines = original.split(separator: "\n").map(String.init)
        // MUTATION: flip one byte inside line 1 → digestMismatch
        let mutated = lines[1].replacingOccurrences(of: "revoked", with: "revokeX")
        try ([lines[0], mutated, lines[2]].joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try RWCAssetRightsJournalV1.replay(url: url)) { e in
            if case .malformedLine = e as? RWCRightsJournalErrorV1 { return } // kind change may fail parse-level checks
            XCTAssertEqual(e as? RWCRightsJournalErrorV1, .digestMismatch(index: 1))
        }
        // REORDER: swap lines 1 and 2 → chain break
        try ([lines[0], lines[2], lines[1]].joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try RWCAssetRightsJournalV1.replay(url: url)) { e in
            guard let err = e as? RWCRightsJournalErrorV1 else { return XCTFail() }
            XCTAssertTrue(err == .chainBreak(index: 1) || err == .sequenceGap(expected: 1, found: 2), "\(err)")
        }
        // DUPLICATE line → sequence violation
        try ([lines[0], lines[1], lines[1]].joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try RWCAssetRightsJournalV1.replay(url: url)) { e in
            XCTAssertEqual(e as? RWCRightsJournalErrorV1, .sequenceGap(expected: 2, found: 1))
        }
        // TRUNCATION: drop the tail → internally consistent, caught by the head witness
        try (lines[0] + "\n" + lines[1] + "\n").write(to: url, atomically: true, encoding: .utf8)
        XCTAssertNoThrow(try RWCAssetRightsJournalV1.replay(url: url))
        XCTAssertThrowsError(try RWCAssetRightsJournalV1.verifyHead(url: url, expectedHeadDigest: store.headDigest,
                                                                    expectedCount: 3)) { e in
            XCTAssertEqual(e as? RWCRightsJournalErrorV1, .truncated(expectedCount: 3, found: 2))
        }
        // restore → clean again
        try original.write(to: url, atomically: true, encoding: .utf8)
        XCTAssertNoThrow(try RWCAssetRightsJournalV1.verifyHead(url: url, expectedHeadDigest: store.headDigest,
                                                                expectedCount: 3))
        lines = []
    }

    // MARK: 9 — A15-F5 strict input domain

    func testR2_F5_CalibrationInputDomain_TypedRefusals() throws {
        typealias M = RWCCalibrationMethodologyV3
        func expectInput(_ expected: RWCCalibrationInputErrorV1, _ body: () throws -> Void,
                         file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertThrowsError(try body(), file: file, line: line) { e in
                XCTAssertEqual(e as? RWCCalibrationInputErrorV1, expected, file: file, line: line)
            }
        }
        expectInput(.emptyInput) { _ = try M.eceTieInvariant(preds: [], labels: []) }
        expectInput(.countMismatch(predictions: 1, labels: 2)) {
            _ = try M.eceTieInvariant(preds: [0.5], labels: [true, false])
        }
        expectInput(.nonFiniteProbability(index: 1)) {
            _ = try M.eceTieInvariant(preds: [0.5, .nan, 0.2], labels: [true, false, true])
        }
        expectInput(.nonFiniteProbability(index: 0)) {
            _ = try M.eceTieInvariant(preds: [.infinity, 0.2], labels: [true, false])
        }
        expectInput(.probabilityOutOfRange(index: 0)) {
            _ = try M.decideV3(preds: [Double](repeating: 1.1, count: 50),
                               labels: [Bool](repeating: true, count: 50), seedParts: ["t"])
        }
        expectInput(.probabilityOutOfRange(index: 0)) {
            _ = try M.decideV3(preds: [Double](repeating: -0.1, count: 50),
                               labels: [Bool](repeating: false, count: 50), seedParts: ["t"])
        }
        expectInput(.invalidBins(bins: 0, n: 2)) {
            _ = try M.eceTieInvariant(preds: [0.5, 0.5], labels: [true, false], bins: 0)
        }
        expectInput(.invalidBins(bins: 3, n: 2)) {
            _ = try M.eceTieInvariant(preds: [0.5, 0.5], labels: [true, false], bins: 3)
        }
        expectInput(.invalidSimulationCount(200)) {
            _ = try M.decideV3(preds: [Double](repeating: 0.5, count: 50),
                               labels: [Bool](repeating: false, count: 50), sims: 200, seedParts: ["t"])
        }
        XCTAssertEqual((M.frozenNullSims + 1) % 20, 0)   // exact-test law
    }

    // MARK: 10 — A15-F9 tie invariance + cross-language fixtures

    func testR2_F9_TiePermutationInvariance_And_PythonDifferentialFixtures() throws {
        typealias M = RWCCalibrationMethodologyV3
        // the AUDIT15 flip case: all p=.5, blocked vs interleaved — now IDENTICAL
        let blocked = [Bool](repeating: true, count: 10) + [Bool](repeating: false, count: 10)
        let interleaved = (0..<20).map { $0 % 2 == 0 }
        let p05 = [Double](repeating: 0.5, count: 20)
        let eA = try M.eceTieInvariant(preds: p05, labels: blocked)
        let eB = try M.eceTieInvariant(preds: p05, labels: interleaved)
        XCTAssertEqual(eA, eB)
        XCTAssertEqual(eA, 0.0)
        // 200 shuffles of a mixed tied dataset: identical statistic AND identical decision
        var rng = RWCSplitMix64(seed: M.seed64(["r2", "shuffle"]))
        var preds = (0..<120).map { Double($0 % 6) / 5.0 }
        var labels = (0..<120).map { ($0 * 13) % 4 != 0 }
        let refE = try M.eceTieInvariant(preds: preds, labels: labels)
        let refD = try M.decideV3(preds: preds, labels: labels, seedParts: ["r2", "tie", "decide"])
        for _ in 0..<200 {
            // Fisher-Yates over PAIRS (multiset preserved)
            for i in (1..<preds.count).reversed() {
                let j = Int(rng.next() % UInt64(i + 1))
                preds.swapAt(i, j); labels.swapAt(i, j)
            }
            XCTAssertEqual(try M.eceTieInvariant(preds: preds, labels: labels), refE)
            let d = try M.decideV3(preds: preds, labels: labels, seedParts: ["r2", "tie", "decide"])
            XCTAssertEqual(d, refD)
        }
        // CROSS-LANGUAGE DIFFERENTIAL: committed Python fixtures reproduce bit-exactly in Swift
        let fx = try json("docs/calibration/preregistration/tools/RWC_METHODOLOGY_V3_DIFFERENTIAL_FIXTURES.json")
        let seeds = fx["seed64"] as! [String: String]
        for (ctx, want) in seeds {
            XCTAssertEqual(String(M.seed64(ctx.split(separator: "|").map(String.init))), want, ctx)
        }
        let sm = fx["splitmix64_first5"] as! [String: [String]]
        for (seedStr, wants) in sm {
            var r = RWCSplitMix64(seed: UInt64(seedStr)!)
            for w in wants { XCTAssertEqual(String(r.next()), w) }
        }
        let eceFx = fx["eceTieInvariant"] as! [String: String]
        let e1p = [Double](repeating: 0.5, count: 20)
        let e1l = [Bool](repeating: true, count: 10) + [Bool](repeating: false, count: 10)
        XCTAssertEqual(try M.eceTieInvariant(preds: e1p, labels: e1l), Double(eceFx["all_tied_p05"]!)!)
        let e3p = (0..<40).map { Double($0 % 5) / 4.0 }
        let e3l = (0..<40).map { ($0 * 7) % 3 == 0 }
        XCTAssertEqual(try M.eceTieInvariant(preds: e3p, labels: e3l), Double(eceFx["quantized_grid"]!)!)
        let decFx = fx["decideV3"] as! [String: [String: Any]]
        let d1 = try M.decideV3(preds: e3p, labels: e3l, seedParts: ["fixture", "decide", "quantized"])
        let want1 = decFx["quantized_grid"]!
        XCTAssertEqual(d1.observed, Double(want1["observed"] as! String)!)
        XCTAssertEqual(d1.pMC, Double(want1["pMC"] as! String)!)
        XCTAssertEqual(d1.nullMean, Double(want1["nullMean"] as! String)!)
        XCTAssertEqual(d1.nullAdjustedExcessECE, Double(want1["excess"] as! String)!)
        XCTAssertEqual(d1.passed, want1["passed"] as! Bool)
        // generator differential: clustered/over07 dataset vectors
        let gen = fx["dataset_clustered_over07_n8"] as! [String: Any]
        let wantPreds = (gen["preds"] as! [String]).map { Double($0)! }
        let wantLabels = gen["labels"] as! [Bool]
        let got = RWCPowerDerivationV3.dataset(shape: "clustered", alt: "over07", n: 8,
                                               seedParts: ["fixture", "gen", "clustered"])
        XCTAssertEqual(got.preds, wantPreds)
        XCTAssertEqual(got.labels, wantLabels)
    }

    // MARK: 11 — A15-F11/F7 frozen seed law, exact test, frozen artifacts

    func testR2_F11F7_SeedLaw_Determinism_FrozenDerivationArtifacts() throws {
        typealias M = RWCCalibrationMethodologyV3
        XCTAssertEqual(M.frozenNullSims, 999)
        XCTAssertEqual(M.frozenOverallN, 800)
        // byte-identical repeat under the frozen seed law
        let data = RWCPowerDerivationV3.dataset(shape: "uniform", alt: "null", n: 200,
                                                seedParts: ["r2", "det", "data"])
        let a = try M.decideV3(preds: data.preds, labels: data.labels, seedParts: ["r2", "det", "eval"])
        let b = try M.decideV3(preds: data.preds, labels: data.labels, seedParts: ["r2", "det", "eval"])
        XCTAssertEqual(a, b)
        // stability artifact: predeclared rule + measured zeros recorded
        let stab = try read("docs/calibration/preregistration/tools/RWC_CALIBRATION_MC_STABILITY_V3.json")
        XCTAssertTrue(stab.contains("\"null|S999\": {\"mixed\": 0"))
        XCTAssertTrue(stab.contains("smallest S with null-suite mixed fraction <= 0.015"))
        // power artifact: frozen S=999 design + n-law evidence present
        let power = try json("docs/calibration/preregistration/tools/RWC_CALIBRATION_POWER_RESULTS_V3.json")
        let design = power["design"] as! [String: Any]
        XCTAssertEqual(design["S"] as! Int, 999)
        XCTAssertEqual(design["trials"] as! Int, 200)
        let cells = power["cells"] as! [String: [String: Any]]
        XCTAssertEqual(cells.count, 6 * 9 + 6 * 4 * 2)   // full alts at n800, reduced at n400/n1600
        for shape in RWCPowerDerivationV3.shapes {
            let over = cells["\(shape)|over07|n800"]!["reject_rate"] as! Double
            let under = cells["\(shape)|under07|n800"]!["reject_rate"] as! Double
            XCTAssertGreaterThanOrEqual(over, 0.80, shape)    // n=800 law holds for every shape
            XCTAssertGreaterThanOrEqual(under, 0.80, shape)
            let null = cells["\(shape)|null|n800"]!["reject_rate"] as! Double
            XCTAssertLessThanOrEqual(null, 0.12, shape)       // compatible with 5% at 200-trial noise
        }
        XCTAssertLessThan(cells["uniform|over07|n400"]!["reject_rate"] as! Double, 0.80) // 400 rejected
        // python differential tool contains no hash()-seeding and is PYTHONHASHSEED-invariant by law
        let py = try read("docs/calibration/preregistration/tools/rwc_methodology_v3_differential.py")
        XCTAssertTrue(py.contains("hashlib.sha256"))
        XCTAssertFalse(py.contains("hash(conf"))
        XCTAssertTrue(py.contains("PYTHONHASHSEED"))
    }

    // MARK: 12 — A15-F6 coverage typed counters

    func testR2_F6_CoverageTypedCounters_ZeroDenominators_Gate() throws {
        typealias M = RWCCalibrationMethodologyV3
        func counts(_ d: Int, _ t: Int, ood: (Int, Int) = (10, 20), sen: (Int, Int, Int) = (150, 100, 150))
            -> M.RWCCoverageCountsV1 {
            M.RWCCoverageCountsV1(inDistDecided: d, inDistTotal: t, oodAbstained: ood.0, oodTotal: ood.1,
                                  sentinelProtective: sen.0, sentinelDecided: sen.1, sentinelTotal: sen.2)
        }
        // impossible counters: typed refusals (A15-F6 closed)
        XCTAssertThrowsError(try M.coverageV2(counts(120, 100))) { e in
            XCTAssertEqual(e as? M.RWCCoverageErrorV1, .impossibleCount(rule: "inDistDecided <= inDistTotal"))
        }
        XCTAssertThrowsError(try M.coverageV2(counts(-5, 10))) { e in
            XCTAssertEqual(e as? M.RWCCoverageErrorV1, .negativeCount(field: "inDistDecided"))
        }
        XCTAssertThrowsError(try M.coverageV2(counts(5, 10, ood: (60, 50)))) { e in
            XCTAssertEqual(e as? M.RWCCoverageErrorV1, .impossibleCount(rule: "oodAbstained <= oodTotal"))
        }
        XCTAssertThrowsError(try M.coverageV2(counts(5, 10, sen: (200, 100, 150)))) { e in
            XCTAssertEqual(e as? M.RWCCoverageErrorV1, .impossibleCount(rule: "sentinelProtective <= sentinelTotal"))
        }
        XCTAssertThrowsError(try M.coverageV2(counts(5, 10, sen: (100, 300, 150)))) { e in
            XCTAssertEqual(e as? M.RWCCoverageErrorV1, .impossibleCount(rule: "sentinelDecided <= sentinelTotal"))
        }
        // zero denominators: NOT_APPLICABLE, never a fake 0
        let r = try M.coverageV2(counts(5, 10, ood: (0, 0), sen: (0, 0, 0)))
        XCTAssertEqual(r.oodAbstentionRate, .notApplicable)
        XCTAssertEqual(r.sentinelProtectiveRate, .notApplicable)
        XCTAssertEqual(r.decisionCoverage, .value(0.5))
        // hard gate: exact boundary + refusal semantics
        XCTAssertNoThrow(try M.requireDecisionCoverageGate(counts(640, 800)))   // exactly 0.80
        XCTAssertThrowsError(try M.requireDecisionCoverageGate(counts(639, 800))) { e in
            guard case .decisionCoverageBelowGate = e as? M.RWCCoverageErrorV1 else { return XCTFail() }
        }
        XCTAssertThrowsError(try M.requireDecisionCoverageGate(counts(0, 0))) { e in
            XCTAssertEqual(e as? M.RWCCoverageErrorV1, .hardGateRequiresInDistribution)
        }
    }

    // MARK: 13 — A15-F12 corpus entry authority (synthetic git fixtures)

    private struct Fixture {
        let root: URL
        let anchor: String
        let candidate: String
        let tagObject: String
    }

    @discardableResult
    private func sh(_ root: URL, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git", "-C", root.path, "-c", "user.name=Claude",
                       "-c", "user.email=noreply@anthropic.com"] + args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        try p.run(); p.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shaHex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func write(_ root: URL, _ rel: String, _ content: String) throws {
        let url = root.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Builds a minimal lawful fixture repo: anchor commit (frozen files) → candidate commit
    /// (manifest + report + lock) → annotated tag. Returns identities for tamper variants.
    private func makeFixture(verdict: String = "PASS", authorized: Bool = true,
                             annotatedTag: Bool = true) throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("r2-fixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try sh(root, ["init", "-q"])
        let gates = "{\"gates\": \"fixture-v3\"}\n"
        let code = "// RWCFixtureLaw\nlet law = 1\n"
        try write(root, "docs/prereg/gates.yaml", gates)
        try write(root, "code/RWCFixtureLaw.swift", code)
        try write(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
                  "{\"data_visibility\": false, \"corpus_count\": 0}\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try sh(root, ["rev-parse", "HEAD"])
        // Phase B: manifest references the anchor; SELF entry hash-exempt
        let manifestPath = "docs/prereg/MANIFEST_V3.yaml"
        let artifacts = [
            ("docs/prereg/gates.yaml", shaHex(gates)),
            ("code/RWCFixtureLaw.swift", shaHex(code)),
            (manifestPath, "SELF"),
        ]
        let inventoryDigest = shaHex(artifacts.map { "\($0.0):\($0.1)" }.sorted().joined(separator: "\n"))
        let manifest = """
        {"freeze_version": "fixture-v3", "methodology_anchor_commit": "\(anchor)",
         "artifacts": [\(artifacts.map { "{\"path\": \"\($0.0)\", \"sha256\": \"\($0.1)\"}" }.joined(separator: ", "))],
         "surface_rules": {"doc_root": "docs/prereg",
           "code_scan": [{"root": "code", "prefixes": ["RWC"]}],
           "post_anchor_allowed": [], "hash_exempt": ["\(manifestPath)"]}}
        """
        try write(root, manifestPath, manifest)
        let report = "fixture audit report: PASS\n"
        try write(root, "docs/audit/report.md", report)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit evidence"])
        let auditCommit = try sh(root, ["rev-parse", "HEAD"])
        let lock = """
        {"lock_version": "rwc-pre14-pass-lock-v1", "verdict": "\(verdict)",
         "candidate_commit": "CANDIDATE", "candidate_tag_name": "fixture-candidate",
         "candidate_tag_object_sha": "TAGOBJ", "audit_commit": "\(auditCommit)",
         "audit_report_path": "docs/audit/report.md", "audit_report_sha256": "\(shaHex(report))",
         "freeze_version": "fixture-v3", "freeze_manifest_path": "\(manifestPath)",
         "freeze_manifest_sha256": "\(shaHex(manifest))",
         "methodology_anchor_commit": "\(anchor)", "frozen_inventory_digest": "\(inventoryDigest)",
         "governing_control_plane_lock": "2c345b64c720f965b68ec5ee699e1b71fecf0003",
         "created_by_closeout": true, "corpus_entry_authorized": \(authorized)}
        """
        try write(root, RWCPre14PassLockV1.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout lock"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        if annotatedTag {
            try sh(root, ["tag", "-a", "fixture-candidate", "-m", "fixture"])
        } else {
            try sh(root, ["tag", "fixture-candidate"])
        }
        let tagObject = try sh(root, ["rev-parse", "refs/tags/fixture-candidate"])
        // patch lock with real identities (lock content isn't hash-bound; the PASS lock binds others)
        let patched = lock.replacingOccurrences(of: "CANDIDATE", with: candidate)
            .replacingOccurrences(of: "TAGOBJ", with: tagObject)
        try write(root, RWCPre14PassLockV1.lockRelPath, patched)
        return Fixture(root: root, anchor: anchor, candidate: candidate, tagObject: tagObject)
    }

    func testR2_F12_CorpusEntryVerifier_Authority() throws {
        // (a) REAL repository: NO PASS LOCK EXISTS in R2 — verification fails closed (zero-data law)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: repoRoot().appendingPathComponent(RWCPre14PassLockV1.lockRelPath).path))
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.verify(repoRoot: repoRoot())) { e in
            XCTAssertEqual(e as? RWCCorpusEntryErrorV2, .lockMissing)
        }
        // (b) fully lawful synthetic fixture: the mechanism CAN mint the proof
        let good = try makeFixture()
        defer { try? FileManager.default.removeItem(at: good.root) }
        let proof = try RWCCorpusEntryVerifierV2.verify(repoRoot: good.root)
        XCTAssertEqual(proof.candidateCommit, good.candidate)
        XCTAssertEqual(proof.candidateTagObjectSHA, good.tagObject)
        XCTAssertNotEqual(good.tagObject, good.candidate)   // annotated tag object != commit
        // (c) forged verdict: refused
        let fix = try makeFixture(verdict: "FIX REQUIRED")
        defer { try? FileManager.default.removeItem(at: fix.root) }
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.verify(repoRoot: fix.root)) { e in
            XCTAssertEqual(e as? RWCCorpusEntryErrorV2, .verdictNotPass("FIX REQUIRED"))
        }
        // (d) authorization flag false: refused
        let unauth = try makeFixture(authorized: false)
        defer { try? FileManager.default.removeItem(at: unauth.root) }
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.verify(repoRoot: unauth.root)) { e in
            XCTAssertEqual(e as? RWCCorpusEntryErrorV2, .entryNotAuthorized)
        }
        // (e) lightweight (non-annotated) tag: refused
        let light = try makeFixture(annotatedTag: false)
        defer { try? FileManager.default.removeItem(at: light.root) }
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.verify(repoRoot: light.root)) { e in
            XCTAssertEqual(e as? RWCCorpusEntryErrorV2, .tagNotAnnotated)
        }
        // (f) tag deleted and re-created onto another commit: TAG OBJECT mismatch catches it
        let retag = try makeFixture()
        defer { try? FileManager.default.removeItem(at: retag.root) }
        try write(retag.root, "docs/prereg/extra-note.md", "post-audit note\n")
        try sh(retag.root, ["add", "-A"]); try sh(retag.root, ["commit", "-q", "-m", "post-audit"])
        try sh(retag.root, ["tag", "-d", "fixture-candidate"])
        try sh(retag.root, ["tag", "-a", "fixture-candidate", "-m", "rebind"])
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.verify(repoRoot: retag.root)) { e in
            guard let err = e as? RWCCorpusEntryErrorV2 else { return XCTFail() }
            if case .tagObjectMismatch = err {} else { XCTFail("\(err)") }
        }
        // (g) frozen file drift after lock: refused by LIVE hash recomputation
        let drift = try makeFixture()
        defer { try? FileManager.default.removeItem(at: drift.root) }
        try write(drift.root, "docs/prereg/gates.yaml", "{\"gates\": \"tampered\"}\n")
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.verify(repoRoot: drift.root)) { e in
            XCTAssertEqual(e as? RWCCorpusEntryErrorV2, .frozenFileDrift(path: "docs/prereg/gates.yaml"))
        }
        // (h) EXTRA methodology file (A15-F12 expansion attack): SET EQUALITY catches it
        let extra = try makeFixture()
        defer { try? FileManager.default.removeItem(at: extra.root) }
        try write(extra.root, "code/RWCNewSneakyLaw.swift", "// new behavior\n")
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.verify(repoRoot: extra.root)) { e in
            guard let err = e as? RWCCorpusEntryErrorV2 else { return XCTFail() }
            if case let .surfaceSetMismatch(extraFiles, _) = err {
                XCTAssertEqual(extraFiles, ["code/RWCNewSneakyLaw.swift"])
            } else { XCTFail("\(err)") }
        }
        // (i) bad audit commit SHA: refused
        let badAudit = try makeFixture()
        defer { try? FileManager.default.removeItem(at: badAudit.root) }
        let lockURL = badAudit.root.appendingPathComponent(RWCPre14PassLockV1.lockRelPath)
        var lockObj = try JSONSerialization.jsonObject(with: Data(contentsOf: lockURL)) as! [String: Any]
        lockObj["audit_commit"] = String(repeating: "deadbeef", count: 5)
        try JSONSerialization.data(withJSONObject: lockObj).write(to: lockURL)
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.verify(repoRoot: badAudit.root)) { e in
            XCTAssertEqual(e as? RWCCorpusEntryErrorV2, .commitMissing(field: "audit_commit"))
        }
        // (j) forged in-memory struct is impossible: RWCVerifiedCorpusEntryV1.init is fileprivate —
        //     enforced at compile time; the only mint path is verify(). (Type-level law.)
    }

    // MARK: 14 — freeze v3 anchor law (validates once the manifest exists)

    func testR2_F8_FreezeV3_AnchorConsistency_HashCensus() throws {
        let manifestRel = "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V3.yaml"
        guard FileManager.default.fileExists(atPath: repoRoot().appendingPathComponent(manifestRel).path) else {
            throw XCTSkip("pre-anchor build state: freeze manifest v3 is generated AFTER the methodology anchor commit")
        }
        let m = try json(manifestRel)
        XCTAssertEqual(m["freeze_version"] as! String, "rwc-preregistration-freeze-v3")
        let anchor = m["methodology_anchor_commit"] as! String
        XCTAssertEqual(anchor.count, 40)
        let artifacts = m["artifacts"] as! [[String: Any]]
        let rules = m["surface_rules"] as! [String: Any]
        let hashExempt = Set(rules["hash_exempt"] as! [String])
        var paths = Set<String>()
        for a in artifacts {
            let path = a["path"] as! String, sha = a["sha256"] as! String
            XCTAssertTrue(paths.insert(path).inserted, "duplicate: \(path)")
            if hashExempt.contains(path) { continue }
            XCTAssertEqual(try sha256(path), sha, path)
            // ANCHOR LAW: frozen path content unchanged since the anchor commit
            let diff = try sh(repoRoot(), ["diff", "--name-only", anchor + "..HEAD", "--", path])
            XCTAssertEqual(diff, "", "post-anchor drift: \(path)")
        }
        // anchor is an ancestor of HEAD
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git", "-C", repoRoot().path, "merge-base", "--is-ancestor", anchor, "HEAD"]
        try p.run(); p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0)
        // v3 includes PRE-10/PRE-11 (A15-F15 closed) and the v3 methodology code
        XCTAssertTrue(paths.contains("docs/calibration/preregistration/protocols/RWC_PRE10_SLICES.md"))
        XCTAssertTrue(paths.contains("docs/calibration/preregistration/protocols/RWC_PRE11_GATE_FREEZE.md"))
        XCTAssertTrue(paths.contains("packages/GuardianKit/Sources/GuardianCore/RWCRightsV2.swift"))
        XCTAssertTrue(paths.contains("packages/GuardianKit/Tests/GuardianCoreTests/RWCCalibrationMethodologyV3.swift"))
        XCTAssertTrue(paths.contains("docs/calibration/preregistration/tools/RWC_CALIBRATION_POWER_RESULTS_V3.json"))
        // no fabricated tag object inside the freeze manifest (pinned by audit/PASS lock instead)
        let raw = try read(manifestRel)
        XCTAssertFalse(raw.contains("candidate_tag_object"))
    }

    // MARK: 15 — v3 docs pins + zero-data + production locks

    func testR2_DocsV3Pins_ZeroData_ProductionLocks() throws {
        let gates = try read("docs/calibration/preregistration/RWC_FROZEN_GATES_V3.yaml")
        for pin in ["rwc-frozen-gates-v3", "TIE GROUPS", "permutation invariant",
                    "NOT an unbiased estimator", "NEVER 'true calibration error <= 5%'",
                    "calibrated everywhere", "S = 999", "20*(1+exceed) <= S+1",
                    "SET-EQUALITY", "METHODOLOGY ANCHOR COMMIT", "high_confidence_tail",
                    "NOT_APPLICABLE", "PLANNED_TARGET_N", "INVALID INPUT != VALID METRIC"] {
            XCTAssertTrue(gates.contains(pin), pin)
        }
        let slices = try read("docs/calibration/preregistration/RWC_SLICE_DEFINITIONS_V3.yaml")
        for pin in ["high_confidence_tail", "REPORTABLE/GATE_POWERED/UNDERPOWERED", "D-16 positive",
                    "UNKNOWN", "decision_coverage", "abstention_rate"] {
            XCTAssertTrue(slices.contains(pin), pin)
        }
        let slicesJSON = try json("docs/calibration/preregistration/RWC_SLICE_DEFINITIONS_V3.yaml")
        XCTAssertEqual((slicesJSON["slices"] as! [[String: Any]]).count, 22)
        let prereg = try read("docs/calibration/preregistration/RWC_CALIBRATION_POWER_PREREG_V3.yaml")
        for pin in ["no post-hoc tuning", "PYTHONHASHSEED", "byte-identical", "NOT a bound",
                    "below reliable detection", "smallest candidate"] {
            XCTAssertTrue(prereg.contains(pin), pin)
        }
        let rights = try read("docs/calibration/preregistration/RWC_RIGHTS_LAW_V2.md")
        for pin in ["RWCDateV2", "leap-year law", "Clock authority", "evidenceDigest",
                    "reauthorizationRequiresNewEvidence", "GEN8-RWC-RIGHTS-CHAIN-V2-GENESIS",
                    "expiredAtRegistration", "AT LEAST ONE alphanumeric"] {
            XCTAssertTrue(rights.contains(pin), pin)
        }
        let schema = try read("docs/calibration/preregistration/RWC_PRE14_PASS_LOCK_SCHEMA.yaml")
        for pin in ["must NEVER create this lock", "candidate_tag_object_sha", "fileprivate",
                    "SET EQUALITY", "lockMissing"] {
            XCTAssertTrue(schema.contains(pin), pin)
        }
        let irr = try read("docs/calibration/preregistration/RWC_IRR_PLANNING_V3.md")
        XCTAssertTrue(irr.contains("PLANNED_TARGET_N = 300"))
        XCTAssertTrue(irr.contains("NOT weakened"))
        XCTAssertEqual(RWCCalibrationMethodologyV3.irrMinValidPairs, 50)
        XCTAssertEqual(RWCCalibrationMethodologyV3.irrPlannedTargetPairs, 300)
        let ledger = try read("docs/calibration/preregistration/RWC_PREREGISTRATION_R2_CHANGE_LEDGER.md")
        XCTAssertTrue(ledger.contains("NO REAL CORPUS DATA, NO LABELS, NO FIT, NO HELDOUT"))
        XCTAssertTrue(ledger.contains("SUPERSESSION NOT MUTATION"))
        // master manifest R2 state + intact pins/zeros
        let master = try json("docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml")
        XCTAssertEqual(master["r2_status"] as! String, "BUILDER_COMPLETE")
        XCTAssertEqual(master["r2_candidate_generation"] as! String, "R2")
        XCTAssertEqual(master["candidate_generation"] as! String, "R1")   // historical pin preserved
        XCTAssertEqual(master["corpus_count"] as! Int, 0)
        XCTAssertEqual(master["annotator_count"] as! Int, 0)
        XCTAssertEqual(master["real_fit_count"] as! Int, 0)
        XCTAssertEqual(master["heldout_open_count"] as! Int, 0)
        XCTAssertEqual(master["data_visibility"] as! Bool, false)
        // production locks
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims)
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59)
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0)
        XCTAssertFalse(RealWorldCalibrationExecutorV1.preregistrationAuditPassed)
    }
}
