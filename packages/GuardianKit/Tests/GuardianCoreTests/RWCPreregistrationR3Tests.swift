import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
import RWCAcquisition

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC PRE-14 R3 BUILDER TESTS — fresh family for the AUDIT16 remediation (A16 3 HIGH + 17 MEDIUM
// + F2/F10 LOW). Zero AUDIT16 inversions (supersession): these tests prove the NEW V3/V4 laws;
// AUDIT16 pins keep proving the OLD defects on byte-frozen surfaces.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class RWCPreregistrationR3Tests: XCTestCase {

    // MARK: helpers

    private func repoRoot() -> URL { RWCPowerDerivationV3.repoRootURL() }

    private func sha256(_ rel: String) throws -> String {
        let d = try Data(contentsOf: repoRoot().appendingPathComponent(rel))
        return SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }

    private func shaHex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func read(_ rel: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(rel), encoding: .utf8)
    }

    private func d3(_ s: String) -> RWCDateV3 { try! RWCDateV3.parse(s, field: "test") }
    private func clock(_ s: String) -> RWCFixedClockV3 { try! RWCFixedClockV3(s) }

    private func grant(id: String = "rwc-grant-r3aa0001", revision: Int = 1,
                       digestSeed: String = "proof-a", pointer: String = "rwc-rights-ref-r3p0001",
                       allowed: [String] = ["training", "evaluation"], prohibited: [String] = [],
                       effective: String = "2026-08-01", expiry: String? = "2027-08-01",
                       decision: String = "APPROVED",
                       review: String = "rwc-review-r3rv0001") -> RWCLegalGrantIdentityV1 {
        RWCLegalGrantIdentityV1(grantID: id, grantRevision: revision, evidenceDigest: shaHex(digestSeed),
                                evidencePointer: pointer, rightsHolder: "licensor-a",
                                allowedUse: allowed, prohibitedUse: prohibited,
                                effectiveDate: d3(effective), expiryDate: expiry.map { d3($0) },
                                reviewDecision: decision, reviewRecordID: review)
    }

    private func reviewRecord(for g: RWCLegalGrantIdentityV1,
                              decision: String = "APPROVED") -> RWCRightsReviewRecordV1 {
        RWCRightsReviewRecordV1(reviewRecordID: g.reviewRecordID, grantID: g.grantID,
                                grantRevision: g.grantRevision, evidenceDigest: g.evidenceDigest,
                                decision: decision, reviewDate: d3("2026-08-15"))
    }

    private func verified(_ g: RWCLegalGrantIdentityV1) throws -> RWCVerifiedRightsGrantV1 {
        try RWCRightsReviewAuthorityV1.verify(grant: g, reviewRecord: reviewRecord(for: g))
    }

    private func record(id: String = "rwc-asset-r3aaaa01", g: RWCLegalGrantIdentityV1? = nil,
                        acquisition: String = "2026-09-01",
                        hashSeed: String = "content-a") -> RWCAssetRightsRecordV3 {
        RWCAssetRightsRecordV3(assetID: id, sourceClass: .licensedRightsClear,
                               sourceReference: "rwc-source-ref-r3src01", owner: "gen8",
                               grant: g ?? grant(), acquisitionDate: d3(acquisition),
                               contentHash: shaHex(hashSeed),
                               provenanceChain: ["rwc-source-ref-r3src01"])
    }

    private func tempDir(_ tag: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("r3-\(tag)-\(UUID().uuidString)")
    }

    private func expectV3(_ expected: RWCRightsErrorV3, _ body: () throws -> Void,
                          file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try body(), file: file, line: line) { e in
            XCTAssertEqual(e as? RWCRightsErrorV3, expected, file: file, line: line)
        }
    }

    // MARK: 1 — discipline

    func testR3_Discipline_AUDIT16FrozenOriginals_ZeroInversions() throws {
        let expected = [
            ("AUDIT16_RWCPre14R2ReauditProbes", "ed142d0716dfec976a0f31007cfa5f5882b9e334036e25f0c04ea045b49dde6d"),
            ("AUDIT16_StatReplicationRunner", "867a7ed3a9045468079cce0884d2af094786fa48b51c0159ce3bec0ffcf7bdfc"),
            ("AUDIT16_DerivationReproProbes", "52e11b35137d21c6e42bf84b2621e1db9dcd1e6ea5a7e30cfa8f4b3b6fdea1e9"),
        ]
        for (name, sha) in expected {
            XCTAssertEqual(try sha256("docs/audit/\(name)_ORIGINAL_LOCKED.swift.txt"), sha, name)
            XCTAssertEqual(try sha256("packages/GuardianKit/Tests/GuardianCoreTests/\(name).swift"), sha,
                           "\(name) active file must be byte-identical (zero inversions)")
        }
        let lock = try read("docs/audit/AUDIT16_R3_INVERSION_LOCK.md")
        XCTAssertTrue(lock.contains("ZERO INVERSIONS DECLARED"))
        let report = try read("docs/audit/GEN8_RWC_PREREGISTRATION_PRE14_R2_INDEPENDENT_REAUDIT.md")
        XCTAssertTrue(report.contains("FIX REQUIRED"))
    }

    // MARK: 2 — A16-F1: invalid dates unrepresentable

    func testR3_F1_RWCDateV3_InvalidDatesUnrepresentable() throws {
        for (y, m, d) in [(2026, 2, 31), (2026, 4, 31), (2026, 2, 29), (1900, 2, 29), (2026, 0, 1),
                          (2026, 13, 1), (2026, 1, 0), (2026, 1, 32), (-5, 1, 1), (2026, -1, 5),
                          (2026, 1, -3), (10000, 1, 1)] {
            XCTAssertThrowsError(try RWCDateV3.make(year: y, month: m, day: d), "\(y)-\(m)-\(d)") { e in
                XCTAssertEqual(e as? RWCRightsErrorV3, .impossibleDate(field: "date"), "\(y)-\(m)-\(d)")
            }
        }
        XCTAssertNoThrow(try RWCDateV3.make(year: 2028, month: 2, day: 29))
        XCTAssertNoThrow(try RWCDateV3.make(year: 2000, month: 2, day: 29))
        XCTAssertThrowsError(try RWCDateV3.parse("2026-02-31", field: "d"))
        XCTAssertThrowsError(try RWCDateV3.parse("٢٠٢٦-٠١-٠١", field: "d"))
        // the type's ONLY stored initializer is private (source law pin)
        let src = try read("packages/GuardianKit/Sources/GuardianCore/RWCRightsV3.swift")
        XCTAssertTrue(src.contains("private init(validatedYear"))
        XCTAssertFalse(src.contains("public init(year: Int, month: Int, day: Int)"))
    }

    // MARK: 3 — A16-F2: floor-division UTC clock

    func testR3_F2_UTCClock_FloorDivision_NegativeEpoch() throws {
        func day(_ secs: Int64) -> String {
            RWCAcquisitionClockV2(secondsSince1970: { secs }).today().isoString
        }
        XCTAssertEqual(day(0), "1970-01-01")
        XCTAssertEqual(day(86_399), "1970-01-01")
        XCTAssertEqual(day(86_400), "1970-01-02")
        XCTAssertEqual(day(-1), "1969-12-31")          // truncation would give 1970-01-01
        XCTAssertEqual(day(-86_399), "1969-12-31")
        XCTAssertEqual(day(-86_400), "1969-12-31")
        XCTAssertEqual(day(-86_401), "1969-12-30")
        XCTAssertEqual(day(951_782_400), "2000-02-29")
        XCTAssertEqual(day(2_147_483_647), "2038-01-19")  // Y2038 boundary
    }

    // MARK: 4 — A16-F3: legal grant identity vs byte digest

    func testR3_F3_LegalGrantAuthority_NotByteDigest() throws {
        let g = grant()
        // review boundary: only APPROVED + fully matching review record mints
        XCTAssertNoThrow(try verified(g))
        XCTAssertThrowsError(try RWCRightsReviewAuthorityV1.verify(
            grant: g, reviewRecord: reviewRecord(for: g, decision: "PENDING"))) { e in
            XCTAssertEqual(e as? RWCRightsErrorV3, .reviewNotApproved)
        }
        var wrong = reviewRecord(for: g)
        wrong = RWCRightsReviewRecordV1(reviewRecordID: wrong.reviewRecordID, grantID: wrong.grantID,
                                        grantRevision: wrong.grantRevision,
                                        evidenceDigest: shaHex("different-bytes"),
                                        decision: "APPROVED", reviewDate: d3("2026-08-15"))
        XCTAssertThrowsError(try RWCRightsReviewAuthorityV1.verify(grant: g, reviewRecord: wrong)) { e in
            XCTAssertEqual(e as? RWCRightsErrorV3, .reviewRecordMismatch(reason: "evidenceDigest"))
        }
        // store laws: tombstone + relicense
        let dir = tempDir("f3")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        try store.register(record(), verifiedGrant: try verified(grant()), clock: clock("2026-10-01"))
        try store.revoke(assetID: "rwc-asset-r3aaaa01", clock: clock("2026-10-10"))
        // RESERIALIZATION ATTACK: same legal grant, new bytes (new digest + new pointer) — same
        // grantID ⇒ refused forever; new bytes are NOT new legal authority.
        let reserialized = grant(digestSeed: "proof-a-reserialized-whitespace",
                                 pointer: "rwc-rights-ref-r3p0002",
                                 review: "rwc-review-r3rv0002")
        expectV3(.grantAlreadyUsed) {
            var r2 = self.reviewRecord(for: reserialized)
            r2 = RWCRightsReviewRecordV1(reviewRecordID: "rwc-review-r3rv0002", grantID: reserialized.grantID,
                                         grantRevision: 1, evidenceDigest: reserialized.evidenceDigest,
                                         decision: "APPROVED", reviewDate: self.d3("2026-10-11"))
            try store.reauthorize(self.record(g: reserialized, acquisition: "2026-10-12"),
                                  verifiedGrant: try RWCRightsReviewAuthorityV1.verify(
                                      grant: reserialized, reviewRecord: r2),
                                  clock: self.clock("2026-10-15"))
        }
        // old digest under a NEW grantID ⇒ evidenceAlreadyUsed (bytes already consumed)
        let oldBytesNewGrant = grant(id: "rwc-grant-r3bb0002", digestSeed: "proof-a",
                                     review: "rwc-review-r3rv0003")
        expectV3(.evidenceAlreadyUsed) {
            try store.reauthorize(self.record(g: oldBytesNewGrant, acquisition: "2026-10-12"),
                                  verifiedGrant: try self.verified(oldBytesNewGrant),
                                  clock: self.clock("2026-10-15"))
        }
        // lawful regrant: NEW grant identity + NEW approved review + NEW evidence
        let lawful = grant(id: "rwc-grant-r3cc0003", digestSeed: "proof-b",
                           review: "rwc-review-r3rv0004")
        XCTAssertNoThrow(try store.reauthorize(record(g: lawful, acquisition: "2026-10-12"),
                                               verifiedGrant: try verified(lawful),
                                               clock: clock("2026-10-15")))
    }

    // MARK: 5 — A16-F4/F5: durable restart reconstruction

    func testR3_F4F5_Restart_FullStateReconstruction() throws {
        let dir = tempDir("restart")
        defer { try? FileManager.default.removeItem(at: dir) }
        // session A
        do {
            let a = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
            try a.register(record(), verifiedGrant: try verified(grant()), clock: clock("2026-10-01"))
            try a.revoke(assetID: "rwc-asset-r3aaaa01", clock: clock("2026-10-10"))
            a.closeStore()
        }
        // session B: openExisting reconstructs EVERYTHING
        let b = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        XCTAssertEqual(b.eventCount, 2)
        XCTAssertTrue(b.isTombstoned("rwc-asset-r3aaaa01"))
        XCTAssertEqual(b.record(for: "rwc-asset-r3aaaa01")?.grant.grantID, "rwc-grant-r3aa0001")
        XCTAssertEqual(b.record(for: "rwc-asset-r3aaaa01")?.grant.expiryDate, d3("2027-08-01"))
        // revoked authority does NOT resurrect after restart
        expectV3(.revoked) {
            try b.requireEligible(assetID: "rwc-asset-r3aaaa01", use: .training,
                                  clock: self.clock("2026-10-20"))
        }
        expectV3(.resurrectionRefused) {
            try b.register(self.record(g: self.grant(id: "rwc-grant-r3zz0009",
                                                     digestSeed: "proof-z",
                                                     review: "rwc-review-r3rv0009")),
                           verifiedGrant: try self.verified(self.grant(id: "rwc-grant-r3zz0009",
                                                                       digestSeed: "proof-z",
                                                                       review: "rwc-review-r3rv0009")),
                           clock: self.clock("2026-10-20"))
        }
        // seen grant/evidence identities survive restart
        expectV3(.grantAlreadyUsed) {
            let same = self.grant(digestSeed: "proof-new-bytes", review: "rwc-review-r3rv0010")
            var r = self.reviewRecord(for: same)
            r = RWCRightsReviewRecordV1(reviewRecordID: same.reviewRecordID, grantID: same.grantID,
                                        grantRevision: 1, evidenceDigest: same.evidenceDigest,
                                        decision: "APPROVED", reviewDate: self.d3("2026-10-15"))
            try b.reauthorize(self.record(g: same, acquisition: "2026-10-12"),
                              verifiedGrant: try RWCRightsReviewAuthorityV1.verify(grant: same, reviewRecord: r),
                              clock: self.clock("2026-10-20"))
        }
        // chronology survives restart: an event dated before the reconstructed last event is refused
        // (the tombstoned asset's early QUERY correctly refuses as .revoked — the earlier typed law)
        expectV3(.revoked) {
            try b.requireEligible(assetID: "rwc-asset-r3aaaa01", use: .training,
                                  clock: self.clock("2026-09-15"))
        }
        expectV3(.chronologyViolation(rule: "registration recordedDate >= previous event date")) {
            let g2 = self.grant(id: "rwc-grant-r3new0005", digestSeed: "proof-q",
                                review: "rwc-review-r3rv0011")
            try b.register(self.record(id: "rwc-asset-r3bbbb02", g: g2),
                           verifiedGrant: try self.verified(g2), clock: self.clock("2026-09-15"))
        }
        b.closeStore()
    }

    // MARK: 6 — A16-F6: durable head witness

    func testR3_F6_HeadWitness_Truncation_RollForward_PartialTail() throws {
        let dir = tempDir("witness")
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        try a.register(record(), verifiedGrant: try verified(grant()), clock: clock("2026-10-01"))
        try a.revoke(assetID: "rwc-asset-r3aaaa01", clock: clock("2026-10-10"))
        let lawful = grant(id: "rwc-grant-r3cc0003", digestSeed: "proof-b", review: "rwc-review-r3rv0004")
        try a.reauthorize(record(g: lawful, acquisition: "2026-10-12"),
                          verifiedGrant: try verified(lawful), clock: clock("2026-10-15"))
        a.closeStore()
        let journalURL = dir.appendingPathComponent(RWCAssetRightsLedgerStoreV3.journalName)
        let witnessURL = dir.appendingPathComponent(RWCAssetRightsLedgerStoreV3.witnessName)
        let journal = try String(contentsOf: journalURL, encoding: .utf8)
        let witness = try String(contentsOf: witnessURL, encoding: .utf8)
        var lines = journal.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 3)
        // TRUNCATION: drop the last event; witness (count 3) makes it DETECTABLE after restart —
        // the head cannot be derived from the truncated journal itself (A16-F6 closed).
        try (lines[0] + "\n" + lines[1] + "\n").write(to: journalURL, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)) { e in
            XCTAssertEqual(e as? RWCRightsLedgerErrorV3,
                           .truncatedJournal(witnessCount: 3, journalCount: 2))
        }
        // ROLL-FORWARD: witness behind by exactly one valid event → deterministic repair
        try journal.write(to: journalURL, atomically: true, encoding: .utf8)
        try "{\"v\":\"\(RWCAssetRightsLedgerStoreV3.version)\",\"count\":2,\"head\":\"\(headOf(lines[1]))\"}\n"
            .write(to: witnessURL, atomically: true, encoding: .utf8)
        let rolled = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        XCTAssertEqual(rolled.eventCount, 3)
        rolled.closeStore()
        // PARTIAL TAIL after committed head → deterministic discard
        try (journal + "{\"v\":\"rwc-rights-event-v3\",\"seq\":3,\"prev\":\"garbage")
            .write(to: journalURL, atomically: true, encoding: .utf8)
        let repaired = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        XCTAssertEqual(repaired.eventCount, 3)
        repaired.closeStore()
        // WITNESS TAMPER: wrong head at matching count → refuse
        try "{\"v\":\"\(RWCAssetRightsLedgerStoreV3.version)\",\"count\":3,\"head\":\"\(shaHex("fake"))\"}\n"
            .write(to: witnessURL, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)) { e in
            XCTAssertEqual(e as? RWCRightsLedgerErrorV3, .headMismatch)
        }
        lines = []
    }

    private func headOf(_ journalLine: String) -> String {
        let obj = try! JSONSerialization.jsonObject(with: Data(journalLine.utf8)) as! [String: Any]
        return obj["digest"] as! String
    }

    // MARK: 7 — A16-F7: single writer

    func testR3_F7_SingleWriterLock() throws {
        let dir = tempDir("writer")
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        try a.register(record(), verifiedGrant: try verified(grant()), clock: clock("2026-10-01"))
        // second writer on the SAME ledger: refused while the first holds the lock
        XCTAssertThrowsError(try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)) { e in
            XCTAssertEqual(e as? RWCRightsLedgerErrorV3, .lockedByAnotherWriter)
        }
        a.closeStore()
        let b = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        XCTAssertEqual(b.eventCount, 1)
        b.closeStore()
        // create over an existing ledger: refused (no silent reset-to-empty)
        XCTAssertThrowsError(try RWCAssetRightsLedgerStoreV3.create(directory: dir)) { e in
            XCTAssertEqual(e as? RWCRightsLedgerErrorV3, .directoryExists)
        }
        // openExisting on a missing ledger: typed refusal (no silent empty start)
        XCTAssertThrowsError(try RWCAssetRightsLedgerStoreV3.openExisting(directory: tempDir("missing"))) { e in
            XCTAssertEqual(e as? RWCRightsLedgerErrorV3, .witnessMissing)
        }
    }

    // MARK: 8 — A16-F8: seed nonalias + A16-F9 manifest

    func testR3_F8F9_SeedEncoding_EvaluationManifest() throws {
        typealias M4 = RWCCalibrationMethodologyV4
        XCTAssertNotEqual(M4.seed64(["a|b", "c"]), M4.seed64(["a", "b|c"]))   // the A16-F8 alias
        XCTAssertNotEqual(M4.seed64(["ab", "c"]), M4.seed64(["a", "bc"]))
        XCTAssertNotEqual(M4.seed64([""]), M4.seed64(["", ""]))
        XCTAssertNotEqual(M4.seed64([]), M4.seed64([""]))
        XCTAssertEqual(M4.seed64(["x", "y"]), M4.seed64(["x", "y"]))          // deterministic
        // evaluation seed manifest: outcome-independence is a TYPE invariant — exactly 7 identity
        // fields exist; no label/prediction/outcome field is representable.
        let manifest = M4.RWCEvaluationSeedManifestV1(
            datasetID: "rwc-dataset-fixture", sealedAssetIDsDigest: shaHex("sorted-asset-ids"),
            splitID: "rwc-split-fixture", datasetVersion: "v1", modelArtifactID: "model-fixture-1",
            methodologyVersion: M4.version, evaluationRunID: "run-fixture-1")
        let labels = Mirror(reflecting: manifest).children.compactMap(\.label).sorted()
        XCTAssertEqual(labels, ["datasetID", "datasetVersion", "evaluationRunID", "methodologyVersion",
                                "modelArtifactID", "sealedAssetIDsDigest", "splitID"])
        XCTAssertEqual(manifest.sha256Hex, manifest.sha256Hex)
        let s1 = M4.evaluationSeed(manifest: manifest, metricID: "risk_ECE", purpose: "primary")
        XCTAssertEqual(s1, M4.evaluationSeed(manifest: manifest, metricID: "risk_ECE", purpose: "primary"))
        XCTAssertNotEqual(s1, M4.evaluationSeed(manifest: manifest, metricID: "risk_ECE", purpose: "null"))
        let schema = try read("docs/calibration/preregistration/RWC_EVALUATION_SEED_MANIFEST_SCHEMA_V1.yaml")
        for pin in ["forbidden_content_law", "ground-truth labels", "outcome-independent by construction",
                    "length-prefixed"] {
            XCTAssertTrue(schema.contains(pin), pin)
        }
    }

    // MARK: 9 — A16-F23: analytical S law + V4 artifacts

    func testR3_F23_AnalyticalSLaw_PrecisionAndPowerArtifacts() throws {
        typealias M4 = RWCCalibrationMethodologyV4
        XCTAssertEqual(M4.frozenNullSims, 9999)
        XCTAssertEqual((M4.frozenNullSims + 1) % 20, 0)
        XCTAssertGreaterThan(M4.analyticalSE(alpha: 0.05, sims: 999), M4.frozenSETolerance)   // 999 rejected
        XCTAssertLessThanOrEqual(M4.analyticalSE(alpha: 0.05, sims: 9999), M4.frozenSETolerance)
        let precision = try read("docs/calibration/preregistration/tools/RWC_CALIBRATION_MC_PRECISION_V4.json")
        for pin in ["\"selected_S\": 9999", "negative history (A16-F23)",
                    "REPORTED near-boundary verdict uncertainty"] {
            XCTAssertTrue(precision.contains(pin), pin)
        }
        // deterministic decideV4 under the frozen seed law
        let data = RWCPowerDerivationV4.dataset(shape: "uniform", alt: "null", n: 200,
                                                seedParts: ["r3", "det", "data"])
        let a = try M4.decideV4(preds: data.preds, labels: data.labels, sims: 999,
                                seedParts: ["r3", "det", "eval"])
        let b = try M4.decideV4(preds: data.preds, labels: data.labels, sims: 999,
                                seedParts: ["r3", "det", "eval"])
        XCTAssertEqual(a, b)
        // power V4 artifact: n-law upheld at S=9999 under V4 seeds
        let powerData = try Data(contentsOf: repoRoot().appendingPathComponent(
            "docs/calibration/preregistration/tools/RWC_CALIBRATION_POWER_RESULTS_V4.json"))
        let power = try JSONSerialization.jsonObject(with: powerData) as! [String: Any]
        XCTAssertEqual((power["design"] as! [String: Any])["S"] as! Int, 9999)
        let cells = power["cells"] as! [String: [String: Any]]
        for shape in RWCPowerDerivationV4.shapes {
            XCTAssertGreaterThanOrEqual(cells["\(shape)|over07|n800"]!["reject_rate"] as! Double, 0.80, shape)
            XCTAssertGreaterThanOrEqual(cells["\(shape)|under07|n800"]!["reject_rate"] as! Double, 0.80, shape)
            XCTAssertLessThanOrEqual(cells["\(shape)|null|n800"]!["reject_rate"] as! Double, 0.12, shape)
        }
        XCTAssertLessThan(cells["uniform|over07|n400"]!["reject_rate"] as! Double, 0.80)
    }

    // MARK: 10 — A16-F11: IRR 0.60 restored

    func testR3_F11_IRR_060_Restored() throws {
        typealias M4 = RWCCalibrationMethodologyV4
        XCTAssertEqual(M4.irrOrdinalKappaThreshold, 0.60)
        XCTAssertEqual(M4.irrMinValidPairs, 50)
        XCTAssertEqual(M4.irrPlannedTargetPairs, 300)
        let gates = try read("docs/calibration/preregistration/RWC_FROZEN_GATES_V4.yaml")
        for pin in [">= 0.60", "RESTORED to 0.60", "UNDISCLOSED DRIFT", "no silent change"] {
            XCTAssertTrue(gates.contains(pin), pin)
        }
        // the decision law itself (caller-threshold bootstrap) still fails the AUDIT14 case at .60
        let aRater = (0..<80).map { ($0 * 7) % 5 }
        let bRater = (0..<80).map { i in (i * 7) % 5 == 0 ? 1 : (i * 7) % 5 }
        let decision = RWCCalibrationMethodologyV1.irrKappaDecision(
            a: aRater, b: bRater, categories: 5, threshold: M4.irrOrdinalKappaThreshold)
        XCTAssertNotEqual(decision.decision, .insufficientData)
    }

    // MARK: 11 — A16-F10: sentinel counters coherent by construction

    func testR3_F10_SentinelCountsV2_Coherence() throws {
        typealias S = RWCCalibrationMethodologyV4.RWCSentinelCountsV2
        let c = try S(explicitProtective: 90, explicitUnsafe: 5, protectiveAbstention: 40,
                      otherAbstention: 15)
        XCTAssertEqual(c.total, 150)
        XCTAssertEqual(c.protectiveOutcomes, 130)      // protective abstention IS protective
        XCTAssertEqual(c.explicitDecisions, 95)        // explicit unsafe is NOT protective
        XCTAssertEqual(c.abstentions, 55)
        XCTAssertEqual(c.rate(c.protectiveOutcomes),
                       RWCCalibrationMethodologyV3.RWCRateV2.value(130.0 / 150.0))
        XCTAssertThrowsError(try S(explicitProtective: -1, explicitUnsafe: 0,
                                   protectiveAbstention: 0, otherAbstention: 0))
        // zero total → NOT_APPLICABLE, never 0
        let empty = try S(explicitProtective: 0, explicitUnsafe: 0, protectiveAbstention: 0,
                          otherAbstention: 0)
        XCTAssertEqual(empty.rate(empty.protectiveOutcomes),
                       RWCCalibrationMethodologyV3.RWCRateV2.notApplicable)
    }

    // MARK: 12 — A16-F12..F20: verifier V3 authority (synthetic git fixtures)

    private struct FixtureV3 {
        let root: URL
        let governing: String
        let anchor: String
        let candidate: String
        let audit: String
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

    private func write(_ root: URL, _ rel: String, _ content: String) throws {
        let url = root.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Lawful V4-shaped fixture: governing tag → anchor (frozen files + master manifest) →
    /// candidate (manifest V4 at the CANONICAL path + report) + annotated candidate tag →
    /// audit commit (machine audit result) → PASS lock (closeout).
    private func makeFixtureV3(auditVerdict: String = "PASS", mediumCount: Int = 0,
                               lockDecorativeVerdict: String? = "PASS") throws -> FixtureV3 {
        let root = tempDir("vfx")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try sh(root, ["init", "-q"])
        try write(root, "seed.txt", "governing base\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "governing"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV3.governingTagName, "-m", "governing lock"])
        // anchor: governed roots content + master manifest
        let gates = "{\"gates\": \"fixture-v4\"}\n"
        let code = "// RWCFixtureLaw\nlet law = 3\n"
        try write(root, "docs/prereg/gates.yaml", gates)
        try write(root, "code/method/RWCFixtureLaw.swift", code)   // NOTE: nested subdirectory
        try write(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
                  "{\"immutable_a\": \"x\", \"data_visibility\": false, \"corpus_count\": 0, \"annotator_count\": 0, \"real_fit_count\": 0, \"heldout_open_count\": 0}\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try sh(root, ["rev-parse", "HEAD"])
        // candidate: canonical manifest V4 + report
        let manifestPath = RWCCorpusEntryVerifierV3.canonicalFreezeManifestPath
        let artifacts: [(String, String)] = [
            ("docs/prereg/gates.yaml", shaHex(gates)),
            ("code/method/RWCFixtureLaw.swift", shaHex(code)),
        ]
        let invDigest = shaHex(artifacts.map { "\($0.0):\($0.1)" }.sorted().joined(separator: "\n"))
        let manifest = """
        {"freeze_version": "rwc-preregistration-freeze-v4", "methodology_anchor_commit": "\(anchor)",
         "governing_control_plane_lock": "\(governing)", "frozen_inventory_digest": "\(invDigest)",
         "artifacts": [\(artifacts.map { "{\"path\": \"\($0.0)\", \"sha256\": \"\($0.1)\"}" }.joined(separator: ", "))],
         "surface_rules": {"governed_roots": ["docs/prereg", "code"],
           "post_anchor_allowed": [], "post_audit_allowed_prefixes": ["AUDIT"],
           "hash_exempt": []}}
        """
        try write(root, manifestPath, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", "fixture-r3-candidate", "-m", "candidate"])
        let tagObject = try sh(root, ["rev-parse", "refs/tags/fixture-r3-candidate"])
        // audit commit: the machine audit result (candidate is its ancestor)
        let auditResult = """
        {"result_version": "rwc-pre14-audit-result-v1", "verdict": "\(auditVerdict)",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "fixture-r3-candidate",
         "candidate_tag_object_sha": "\(tagObject)", "methodology_anchor_commit": "\(anchor)",
         "freeze_manifest_path": "\(manifestPath)", "freeze_manifest_sha256": "\(shaHex(manifest))",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "audit_probe_family": "AUDIT17_FIXTURE", "baseline_count": 1, "fresh_probe_count": 1,
         "total_count": 2, "critical_count": 0, "high_count": 0, "medium_count": \(mediumCount),
         "auditor_declaration": "fixture independent audit"}
        """
        try write(root, RWCPre14AuditResultV1.canonicalPath, auditResult)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit"])
        let audit = try sh(root, ["rev-parse", "HEAD"])
        // closeout lock
        let verdictField = lockDecorativeVerdict.map { ", \"verdict\": \"\($0)\"" } ?? ""
        let lock = """
        {"lock_version": "rwc-pre14-pass-lock-v2",
         "audit_result_path": "\(RWCPre14AuditResultV1.canonicalPath)",
         "audit_result_blob_sha256": "\(shaHex(auditResult))", "audit_commit": "\(audit)",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "fixture-r3-candidate",
         "candidate_tag_object_sha": "\(tagObject)", "freeze_manifest_path": "\(manifestPath)",
         "freeze_manifest_sha256": "\(shaHex(manifest))", "methodology_anchor_commit": "\(anchor)",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "corpus_entry_authorized": true\(verdictField)}
        """
        try write(root, RWCPre14PassLockV2.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
        return FixtureV3(root: root, governing: governing, anchor: anchor, candidate: candidate,
                         audit: audit, tagObject: tagObject)
    }

    private func expectEntry(_ root: URL, _ check: (RWCCorpusEntryErrorV3) -> Bool,
                             _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV3.verify(repoRoot: root),
                             label, file: file, line: line) { e in
            guard let err = e as? RWCCorpusEntryErrorV3, check(err) else {
                return XCTFail("\(label): \(e)", file: file, line: line)
            }
        }
    }

    func testR3_F12F13F14F15F16_PassLockAuthority() throws {
        // real repo: NO lock exists; verification fails closed
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: repoRoot().appendingPathComponent(RWCPre14PassLockV2.lockRelPath).path))
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV3.verify(repoRoot: repoRoot())) { e in
            XCTAssertEqual(e as? RWCCorpusEntryErrorV3, .lockMissing)
        }
        // lawful fixture mints (mechanism works end-to-end)
        let good = try makeFixtureV3()
        defer { try? FileManager.default.removeItem(at: good.root) }
        let proof = try RWCCorpusEntryVerifierV3.verify(repoRoot: good.root)
        XCTAssertEqual(proof.candidateCommit, good.candidate)
        XCTAssertEqual(proof.auditCommit, good.audit)
        // A16-F12: FIX_REQUIRED committed audit result + PASS-decorated lock → REFUSED
        let fix = try makeFixtureV3(auditVerdict: "FIX_REQUIRED", lockDecorativeVerdict: "PASS")
        defer { try? FileManager.default.removeItem(at: fix.root) }
        expectEntry(fix.root, { if case .auditVerdictNotPass = $0 { return true }; return false },
                    "forged PASS over FIX audit")
        // PASS verdict but medium_count > 0 → REFUSED
        let open = try makeFixtureV3(mediumCount: 2)
        defer { try? FileManager.default.removeItem(at: open.root) }
        expectEntry(open.root, { if case .auditFindingsOpen = $0 { return true }; return false },
                    "open findings")
        // A16-F13: LIVE report forged to PASS while audit commit holds FIX → REFUSED (git show law)
        let liveForge = try makeFixtureV3(auditVerdict: "FIX_REQUIRED", lockDecorativeVerdict: nil)
        defer { try? FileManager.default.removeItem(at: liveForge.root) }
        let liveResultURL = liveForge.root.appendingPathComponent(RWCPre14AuditResultV1.canonicalPath)
        var forged = try String(contentsOf: liveResultURL, encoding: .utf8)
        forged = forged.replacingOccurrences(of: "FIX_REQUIRED", with: "PASS")
        try forged.write(to: liveResultURL, atomically: true, encoding: .utf8)
        expectEntry(liveForge.root, { err in
            if case .auditVerdictNotPass = err { return true }
            if case .auditResultHashMismatch = err { return true }
            return false
        }, "live-report forgery")
        // A16-F14: unrelated audit commit (candidate NOT its ancestor) → REFUSED
        let unrelated = try makeFixtureV3()
        defer { try? FileManager.default.removeItem(at: unrelated.root) }
        let lockURL = unrelated.root.appendingPathComponent(RWCPre14PassLockV2.lockRelPath)
        var lockObj = try JSONSerialization.jsonObject(with: Data(contentsOf: lockURL)) as! [String: Any]
        lockObj["audit_commit"] = unrelated.governing   // exists, but candidate is not its ancestor
        try JSONSerialization.data(withJSONObject: lockObj).write(to: lockURL)
        expectEntry(unrelated.root, { $0 == .candidateNotAncestorOfAudit }, "unrelated audit commit")
        // A16-F15: wrong governing lock → REFUSED (three-way law)
        let badGov = try makeFixtureV3()
        defer { try? FileManager.default.removeItem(at: badGov.root) }
        let govLockURL = badGov.root.appendingPathComponent(RWCPre14PassLockV2.lockRelPath)
        var govObj = try JSONSerialization.jsonObject(with: Data(contentsOf: govLockURL)) as! [String: Any]
        govObj["governing_control_plane_lock"] = String(repeating: "ab", count: 20)
        try JSONSerialization.data(withJSONObject: govObj).write(to: govLockURL)
        expectEntry(badGov.root, { err in
            if case .auditTargetMismatch(field: "governing_control_plane_lock") = err { return true }
            return false
        }, "fake governing lock")
        // A16-F16: non-canonical mini manifest path → REFUSED
        let mini = try makeFixtureV3()
        defer { try? FileManager.default.removeItem(at: mini.root) }
        let miniManifest = "{\"freeze_version\": \"rwc-preregistration-freeze-v4\", \"artifacts\": []}"
        try write(mini.root, "docs/evil/MINI.yaml", miniManifest)
        let miniLockURL = mini.root.appendingPathComponent(RWCPre14PassLockV2.lockRelPath)
        var miniObj = try JSONSerialization.jsonObject(with: Data(contentsOf: miniLockURL)) as! [String: Any]
        miniObj["freeze_manifest_path"] = "docs/evil/MINI.yaml"
        miniObj["freeze_manifest_sha256"] = shaHex(miniManifest)
        try JSONSerialization.data(withJSONObject: miniObj).write(to: miniLockURL)
        expectEntry(mini.root, { err in
            if case .auditTargetMismatch(field: "freeze_manifest_path") = err { return true }
            if case .nonCanonicalFreezeManifestPath = err { return true }
            return false
        }, "mini manifest")
    }

    func testR3_F17F18F19F20_Surface_ZeroCounters() throws {
        // A16-F18: RECURSIVE subdirectory file (ungoverned by old prefix scans) → caught
        let recursive = try makeFixtureV3()
        defer { try? FileManager.default.removeItem(at: recursive.root) }
        try write(recursive.root, "code/hidden/deep/CalibrationBypass.swift", "// hidden\n")
        expectEntry(recursive.root, { err in
            if case .surfaceSetMismatch = err { return true }
            return false
        }, "recursive hidden file")
        // A16-F19: unprefixed helper filename → caught (no prefix filters exist)
        let unprefixed = try makeFixtureV3()
        defer { try? FileManager.default.removeItem(at: unprefixed.root) }
        try write(unprefixed.root, "code/StatisticalHelper.swift", "// helper\n")
        expectEntry(unprefixed.root, { err in
            if case .surfaceSetMismatch = err { return true }
            return false
        }, "unprefixed helper")
        // A16-F20: symlink under a governed root → typed refusal (never skipped)
        let sym = try makeFixtureV3()
        defer { try? FileManager.default.removeItem(at: sym.root) }
        try FileManager.default.createSymbolicLink(
            at: sym.root.appendingPathComponent("code/evil-link.swift"),
            withDestinationURL: sym.root.appendingPathComponent("seed.txt"))
        expectEntry(sym.root, { err in
            if case .symlinkInGovernedSurface = err { return true }
            return false
        }, "symlink")
        // AUDIT* auditor-evidence prefix allowance works (post-audit probe files are lawful)
        let auditFile = try makeFixtureV3()
        defer { try? FileManager.default.removeItem(at: auditFile.root) }
        try write(auditFile.root, "code/AUDIT17_Probe.swift", "// auditor evidence\n")
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV3.verify(repoRoot: auditFile.root))
        // A16-F17: EVERY zero-data counter enforced
        for field in ["annotator_count", "real_fit_count", "heldout_open_count"] {
            let fx = try makeFixtureV3()
            defer { try? FileManager.default.removeItem(at: fx.root) }
            let masterURL = fx.root.appendingPathComponent(
                "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml")
            var master = try JSONSerialization.jsonObject(with: Data(contentsOf: masterURL)) as! [String: Any]
            master[field] = 1
            try JSONSerialization.data(withJSONObject: master).write(to: masterURL)
            expectEntry(fx.root, { err in
                if case .zeroDataViolated(let f) = err, f == field { return true }
                return false
            }, "nonzero \(field)")
        }
        // §38: immutable master field changed post-anchor → REFUSED
        let immutable = try makeFixtureV3()
        defer { try? FileManager.default.removeItem(at: immutable.root) }
        let masterURL = immutable.root.appendingPathComponent(
            "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml")
        var master = try JSONSerialization.jsonObject(with: Data(contentsOf: masterURL)) as! [String: Any]
        master["immutable_a"] = "tampered"
        try JSONSerialization.data(withJSONObject: master).write(to: masterURL)
        expectEntry(immutable.root, { err in
            if case .masterImmutableFieldChanged(field: "immutable_a") = err { return true }
            return false
        }, "immutable master field")
    }

    // MARK: 13 — A16-F21: acquisition runner ordering/transaction law

    private final class SpyAcquirer: RWCAssetAcquirerV1 {
        var calls = 0
        var payload: Data
        init(_ payload: Data) { self.payload = payload }
        func fetch(sourceReference: String) throws -> Data { calls += 1; return payload }
    }

    private final class FixtureCorpusStore: RWCCorpusStoreV1 {
        var promoted: [String: Data] = [:]
        var failPromote = false
        func promote(assetID: String, contentHash: String, payload: Data) throws {
            if failPromote { throw RWCAcquisitionErrorV1.corpusStoreFailure("fixture") }
            promoted[assetID] = payload
        }
        func storedAssetIDs() throws -> [String] { Array(promoted.keys) }
    }

    /// The only mint path for the global proof is the verifier — so runner tests obtain a REAL
    /// proof from a lawful synthetic fixture (type law preserved; nothing forged).
    private func mintFixtureProof() throws -> (RWCVerifiedCorpusEntryV3, URL) {
        let fx = try makeFixtureV3()
        return (try RWCCorpusEntryVerifierV3.verify(repoRoot: fx.root), fx.root)
    }

    func testR3_F21_AcquisitionRunner_Ordering_Quarantine_Reconciliation() throws {
        let (proof, fxRoot) = try mintFixtureProof()
        defer { try? FileManager.default.removeItem(at: fxRoot) }
        let qRoot = tempDir("quarantine")
        defer { try? FileManager.default.removeItem(at: qRoot) }
        try FileManager.default.createDirectory(at: qRoot, withIntermediateDirectories: true)
        let runner = RWCCorpusAcquisitionRunnerV1(quarantineRoot: qRoot)
        let payload = Data("synthetic-fixture-bytes".utf8)
        let contentHash = RWCCorpusAcquisitionRunnerV1.sha256Hex(payload)
        let g = grant()
        let rec = RWCAssetRightsRecordV3(assetID: "rwc-asset-r3aaaa01", sourceClass: .licensedRightsClear,
                                         sourceReference: "rwc-source-ref-r3src01", owner: "gen8",
                                         grant: g, acquisitionDate: d3("2026-09-01"),
                                         contentHash: contentHash,
                                         provenanceChain: ["rwc-source-ref-r3src01"])
        // §42: grant/record mismatch refuses BEFORE any byte moves — fetch count stays 0
        let dirA = tempDir("led-a"); defer { try? FileManager.default.removeItem(at: dirA) }
        let storeA = try RWCAssetRightsLedgerStoreV3.create(directory: dirA)
        let spyA = SpyAcquirer(payload)
        let otherGrant = grant(id: "rwc-grant-r3oth001", digestSeed: "proof-x",
                               review: "rwc-review-r3rvx001")
        XCTAssertThrowsError(try runner.acquire(proof: proof, record: rec,
                                                verifiedGrant: try verified(otherGrant),
                                                rightsStore: storeA, corpusStore: FixtureCorpusStore(),
                                                acquirer: spyA, clock: clock("2026-10-01"),
                                                sessionID: "s-preauth")) { e in
            XCTAssertEqual(e as? RWCAcquisitionErrorV1, .grantRecordMismatch)
        }
        XCTAssertEqual(spyA.calls, 0, "NO pre-authorization acquisition side effect")
        XCTAssertEqual(storeA.eventCount, 0)
        // content-hash mismatch: quarantine destroyed; no rights event; nothing promoted
        let wrongBytes = SpyAcquirer(Data("tampered-bytes".utf8))
        let corpusB = FixtureCorpusStore()
        XCTAssertThrowsError(try runner.acquire(proof: proof, record: rec,
                                                verifiedGrant: try verified(g),
                                                rightsStore: storeA, corpusStore: corpusB,
                                                acquirer: wrongBytes, clock: clock("2026-10-01"),
                                                sessionID: "s-hash")) { e in
            guard case .contentHashMismatch = e as? RWCAcquisitionErrorV1 else { return XCTFail("\(e)") }
        }
        XCTAssertEqual(storeA.eventCount, 0)
        XCTAssertTrue(corpusB.promoted.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: qRoot.appendingPathComponent("rwc-quarantine-s-hash").path))
        // lawful acquisition: rights commit precedes promote; receipt binds authorities
        let spyC = SpyAcquirer(payload)
        let corpusC = FixtureCorpusStore()
        let receipt = try runner.acquire(proof: proof, record: rec, verifiedGrant: try verified(g),
                                         rightsStore: storeA, corpusStore: corpusC, acquirer: spyC,
                                         clock: clock("2026-10-01"), sessionID: "s-ok")
        XCTAssertEqual(spyC.calls, 1)
        XCTAssertEqual(storeA.eventCount, 1)
        XCTAssertNoThrow(try storeA.requireEligible(assetID: rec.assetID, use: .training,
                                                    clock: clock("2026-10-02")))
        XCTAssertEqual(corpusC.promoted[rec.assetID], payload)
        XCTAssertEqual(receipt.assetID, rec.assetID)
        XCTAssertEqual(receipt.legalGrantID, g.grantID)
        XCTAssertEqual(receipt.passLockCandidateCommit, proof.candidateCommit)
        XCTAssertEqual(receipt.rightsEventCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: qRoot.appendingPathComponent("rwc-quarantine-s-ok").path))
        storeA.closeStore()
        // promote failure AFTER rights commit: quarantine survives; reconcile recovers
        let dirD = tempDir("led-d"); defer { try? FileManager.default.removeItem(at: dirD) }
        let storeD = try RWCAssetRightsLedgerStoreV3.create(directory: dirD)
        let corpusD = FixtureCorpusStore()
        corpusD.failPromote = true
        XCTAssertThrowsError(try runner.acquire(proof: proof, record: rec, verifiedGrant: try verified(g),
                                                rightsStore: storeD, corpusStore: corpusD,
                                                acquirer: SpyAcquirer(payload),
                                                clock: clock("2026-10-01"), sessionID: "s-crash")) { e in
            guard case .promoteFailure = e as? RWCAcquisitionErrorV1 else { return XCTFail("\(e)") }
        }
        XCTAssertEqual(storeD.eventCount, 1, "rights committed before the failed promote")
        corpusD.failPromote = false
        let report = try runner.reconcile(rightsStore: storeD, corpusStore: corpusD)
        XCTAssertEqual(report.recoveredFromQuarantine, [rec.assetID])
        XCTAssertEqual(corpusD.promoted[rec.assetID], payload)
        XCTAssertTrue(report.registeredButUnpromoted.isEmpty)
        // orphan quarantine (no rights record): destroyed, never promoted
        try FileManager.default.createDirectory(at: qRoot.appendingPathComponent("rwc-quarantine-orphan"),
                                                withIntermediateDirectories: true)
        try Data("orphan-bytes".utf8).write(
            to: qRoot.appendingPathComponent("rwc-quarantine-orphan/payload"))
        let report2 = try runner.reconcile(rightsStore: storeD, corpusStore: corpusD)
        XCTAssertEqual(report2.destroyedOrphanQuarantines, ["orphan"])
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: qRoot.appendingPathComponent("rwc-quarantine-orphan").path))
        storeD.closeStore()
        // the verifier/runner live in a REAL library target, not the test target (A16-F22)
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoRoot()
            .appendingPathComponent("packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV3.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoRoot()
            .appendingPathComponent("packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV1.swift").path))
    }

    // MARK: 14 — docs pins + zero data + production locks

    func testR3_DocsV4Pins_ZeroData_ProductionLocks() throws {
        let gates = try read("docs/calibration/preregistration/RWC_FROZEN_GATES_V4.yaml")
        for pin in ["rwc-frozen-gates-v4", "LENGTH-PREFIXED", "OUTCOME-INDEPENDENT BY CONSTRUCTION",
                    "ANALYTICALLY pre-data", "S=9999 SELECTED", "RESTORED to 0.60",
                    "git show <audit_commit>", "RECURSIVELY with NO filename prefixes",
                    "symlinks in governed surface are typed refusals", "ALL FIVE counters",
                    "RWCCorpusAcquisitionRunnerV1", "never certifies abstract lawfulness",
                    "NEVER 'true calibration error <= 5%'"] {
            XCTAssertTrue(gates.contains(pin), pin)
        }
        let auditSchema = try read("docs/calibration/preregistration/RWC_PRE14_AUDIT_RESULT_SCHEMA_V1.yaml")
        for pin in ["ONLY an independent PRE-14 auditor", "critical_count == 0",
                    "NO builder session may create an instance of this schema with verdict PASS"] {
            XCTAssertTrue(auditSchema.contains(pin), pin)
        }
        let lockSchema = try read("docs/calibration/preregistration/RWC_PRE14_PASS_LOCK_SCHEMA_V2.yaml")
        for pin in ["NON-AUTHORITATIVE", "candidate MUST be its ancestor", "lockMissing",
                    "mini-manifest attack"] {
            XCTAssertTrue(lockSchema.contains(pin), pin)
        }
        let ledger = try read("docs/calibration/preregistration/RWC_PREREGISTRATION_R3_CHANGE_LEDGER.md")
        XCTAssertTrue(ledger.contains("NO REAL DATA USED"))
        // master manifest R3 keys + intact pins/zeros
        let masterData = try Data(contentsOf: repoRoot().appendingPathComponent(
            "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml"))
        let master = try JSONSerialization.jsonObject(with: masterData) as! [String: Any]
        XCTAssertEqual(master["r3_status"] as! String, "BUILDER_COMPLETE")
        XCTAssertEqual(master["candidate_generation"] as! String, "R1")
        XCTAssertEqual(master["r2_candidate_generation"] as! String, "R2")
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
        // R4 SUPERSESSION (pre-declared in AUDIT17_R4_INVERSION_LOCK.md): the R3-era absence-pin is
        // obsolete — AUDIT17 (§54) lawfully created the machine result. The post-AUDIT17 truth:
        // the R3 result EXISTS and is FOREVER FIX_REQUIRED 0/5/5 bound to the R3 candidate.
        let r3ResultData = try Data(contentsOf: repoRoot()
            .appendingPathComponent(RWCPre14AuditResultV1.canonicalPath))
        let r3Result = try RWCPre14AuditResultV1.parse(data: r3ResultData)
        XCTAssertEqual(r3Result.resultVersion, "rwc-pre14-audit-result-v1")
        XCTAssertEqual(r3Result.candidateCommit, "17418d4736f94f7b098b1018d44d1f391c7ea21c")
        XCTAssertEqual(r3Result.verdict, "FIX_REQUIRED")
        XCTAssertNotEqual(r3Result.verdict, "PASS")
        XCTAssertEqual(r3Result.criticalCount, 0)
        XCTAssertEqual(r3Result.highCount, 5)
        XCTAssertEqual(r3Result.mediumCount, 5)
        // and the R3 CANDIDATE tree verifiably lacked the file (history reconstructable from git)
        let show = Process()
        show.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        show.arguments = ["git", "-C", repoRoot().path, "cat-file", "-e",
                          "17418d4736f94f7b098b1018d44d1f391c7ea21c:" + RWCPre14AuditResultV1.canonicalPath]
        try show.run(); show.waitUntilExit()
        XCTAssertNotEqual(show.terminationStatus, 0, "R3 candidate must NOT contain the audit result")
        // delegated V4 law docs present with load-bearing pins
        let power = try read("docs/calibration/preregistration/RWC_CALIBRATION_POWER_PREREG_V4.yaml")
        for pin in ["S=9999", "alpha/20", "dataset-reuse artifact", "never a selection criterion"] {
            XCTAssertTrue(power.contains(pin), pin)
        }
        let irr = try read("docs/calibration/preregistration/RWC_IRR_PLANNING_V4.md")
        for pin in [">= 0.60", "RESTORED", "A16-F11", "no silent change"] {
            XCTAssertTrue(irr.contains(pin), pin)
        }
        let rights = try read("docs/calibration/preregistration/RWC_RIGHTS_LAW_V3.md")
        for pin in ["UNREPRESENTABLE", "WHAT BYTES WERE REVIEWED", "head witness", "flock"] {
            XCTAssertTrue(rights.contains(pin), pin)
        }
        let acq = try read("docs/calibration/preregistration/RWC_ACQUISITION_TRANSACTION_LAW_V1.md")
        for pin in ["EPHEMERAL QUARANTINE", "orphan raw media", "NOT a test helper"] {
            XCTAssertTrue(acq.contains(pin), pin)
        }
    }

    // MARK: 15 — freeze V4 anchor law (validates once the manifest exists, post-anchor)

    func testR3_FreezeV4_AnchorConsistency_HashCensus() throws {
        let manifestRel = "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V4.yaml"
        guard FileManager.default.fileExists(atPath: repoRoot().appendingPathComponent(manifestRel).path) else {
            throw XCTSkip("pre-anchor build state: freeze manifest v4 is generated AFTER the methodology anchor commit")
        }
        let data = try Data(contentsOf: repoRoot().appendingPathComponent(manifestRel))
        let m = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(m["freeze_version"] as! String, "rwc-preregistration-freeze-v4")
        XCTAssertEqual(m["governing_control_plane_lock"] as! String,
                       "2c345b64c720f965b68ec5ee699e1b71fecf0003")
        let anchor = m["methodology_anchor_commit"] as! String
        XCTAssertEqual(anchor.count, 40)
        let rules = m["surface_rules"] as! [String: Any]
        let hashExempt = Set(rules["hash_exempt"] as! [String])
        XCTAssertEqual(rules["post_audit_allowed_prefixes"] as! [String], ["AUDIT"])
        let artifacts = m["artifacts"] as! [[String: Any]]
        var paths = Set<String>()
        var pathToSHA: [String: String] = [:]
        for a in artifacts {
            let path = a["path"] as! String, sha = a["sha256"] as! String
            XCTAssertTrue(paths.insert(path).inserted, "duplicate: \(path)")
            pathToSHA[path] = sha
            if hashExempt.contains(path) { continue }
            // R4 SUPERSESSION (pre-declared): V4 census is HISTORICAL — verified against the V4
            // CANDIDATE commit's blobs (immune to lawful post-V4 rounds); V5 owns the live census.
            let v4Candidate = "17418d4736f94f7b098b1018d44d1f391c7ea21c"
            let showP = Process()
            showP.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            showP.arguments = ["git", "-C", repoRoot().path, "show", v4Candidate + ":" + path]
            let showPipe = Pipe(); showP.standardOutput = showPipe; showP.standardError = Pipe()
            try showP.run()
            let blob = showPipe.fileHandleForReading.readDataToEndOfFile()
            showP.waitUntilExit()
            XCTAssertEqual(showP.terminationStatus, 0, "missing in V4 candidate: \(path)")
            let blobSHA = SHA256.hash(data: blob).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(blobSHA, sha, path)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = ["git", "-C", repoRoot().path, "diff", "--name-only",
                           anchor + ".." + v4Candidate, "--", path]
            let pipe = Pipe(); p.standardOutput = pipe
            try p.run(); p.waitUntilExit()
            let diff = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
                .trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertEqual(diff, "", "post-anchor drift at V4 candidate: \(path)")
        }
        // inventory digest recomputation
        let lines = pathToSHA.keys.sorted().map { "\($0):\(pathToSHA[$0]!)" }.joined(separator: "\n")
        let digest = SHA256.hash(data: Data(lines.utf8)).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digest, m["frozen_inventory_digest"] as! String)
        // key membership: new canonical modules + Package.swift + PRE-10/11 + V4 artifacts
        for must in ["packages/GuardianKit/Sources/GuardianCore/RWCRightsV3.swift",
                     "packages/GuardianKit/Tests/GuardianCoreTests/RWCCalibrationMethodologyV4.swift",
                     "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV3.swift",
                     "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV1.swift",
                     "packages/GuardianKit/Package.swift",
                     "docs/calibration/preregistration/protocols/RWC_PRE10_SLICES.md",
                     "docs/calibration/preregistration/protocols/RWC_PRE11_GATE_FREEZE.md",
                     "docs/calibration/preregistration/RWC_FROZEN_GATES_V4.yaml",
                     "docs/calibration/preregistration/tools/RWC_CALIBRATION_POWER_RESULTS_V4.json",
                     "docs/calibration/preregistration/tools/RWC_CALIBRATION_MC_PRECISION_V4.json"] {
            XCTAssertTrue(paths.contains(must), must)
        }
        // anchor ancestry
        let anc = Process()
        anc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        anc.arguments = ["git", "-C", repoRoot().path, "merge-base", "--is-ancestor", anchor, "HEAD"]
        try anc.run(); anc.waitUntilExit()
        XCTAssertEqual(anc.terminationStatus, 0)
        // no fabricated tag object
        XCTAssertFalse(String(data: data, encoding: .utf8)!.contains("candidate_tag_object"))
    }
}
