import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT16 — INDEPENDENT PRE-14 R2 RE-AUDIT PROBES (clean session, no builder context).
//
// ADD-ONLY audit evidence. These probes verify the R2 candidate
// 8460f2705de14e01d5e7935ba3aa65306586c064 (tag object 3a71362f…, anchor d380dad1…) with FRESH,
// independent attacks. Where a probe demonstrates a DEFECT, it is marked
//   "AUDIT16 FINDING <id>: pins defective behavior"
// and asserts the CURRENT (defective) behavior so the suite stays green while the independent
// re-audit report (docs/audit/GEN8_RWC_PREREGISTRATION_PRE14_R2_INDEPENDENT_REAUDIT.md) carries
// the finding. NOTHING here fixes anything. All adversarial filesystem/git work happens in
// synthetic temp fixtures only; the real repository is never modified.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT16_RWCPre14R2ReauditProbes: XCTestCase {

    // MARK: constants (audit targets)

    private let candidateSHA = "8460f2705de14e01d5e7935ba3aa65306586c064"
    private let tagName = "gen8-rwc-preregistration-r2-audit-candidate"
    private let tagObjectSHA = "3a71362f51f76daf01ab7c5842e0a65da96018d0"
    private let anchorSHA = "d380dad10ff9548a8ff879c94069a72d69cec52c"
    private let audit15SHA = "9252d7af6be89a773dc6d29b3d0fbe2020c6545e"
    private let audit15FrozenSHA256 = "a68a8d5013f3fa51c7b41972fb3b38bc9b73be2c9aaf1411b2cfa3c80bd9fc4d"

    // MARK: helpers (independent — not reusing builder test helpers)

    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<6 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("docs/calibration").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    @discardableResult
    private func git(_ root: URL, _ args: [String]) throws -> (status: Int32, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git", "-C", root.path, "-c", "user.name=AUDIT16",
                       "-c", "user.email=noreply@anthropic.com"] + args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus,
                String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func sha256Hex(_ s: String) -> String { sha256Hex(Data(s.utf8)) }

    private func writeFile(_ root: URL, _ rel: String, _ content: String) throws {
        let url = root.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func date(_ iso: String) -> RWCDateV2 { try! RWCDateV2.parse(iso, field: "audit16") }

    private func evidence(_ ptr: String, bytes: String, version: String = "v1.0") -> RWCRightsEvidenceIdentityV1 {
        RWCRightsEvidenceIdentityV1(pointer: "rwc-rights-ref-\(ptr)",
                                    evidenceDigest: sha256Hex(bytes), evidenceVersion: version)
    }

    private func record(id: String = "rwc-asset-a16aaa01", acquisition: RWCDateV2,
                        expiry: RWCDateV2? = nil, ev: RWCRightsEvidenceIdentityV1,
                        holder: String = "licensor-x", license: String = "written-license",
                        allowed: [String] = ["training", "evaluation"],
                        training: Bool = true, evaluation: Bool = true) -> RWCAssetRightsRecordV2 {
        RWCAssetRightsRecordV2(
            assetID: id, sourceClass: .licensedRightsClear, sourceReference: "rwc-source-ref-a16src1",
            owner: "gen8", rightsHolder: holder, licenseType: license, evidence: ev,
            allowedUse: allowed, prohibitedUse: [], trainingAllowed: training,
            evaluationAllowed: evaluation, acquisitionDate: acquisition, expiryDate: expiry,
            contentHash: sha256Hex("a16-content"), provenanceChain: ["rwc-source-ref-a16src1"])
    }

    private func tempDir(_ name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit16-\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §0/§2 — custody, tag object, ancestry, AUDIT15 immutability
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test01_Custody_TagObject_Ancestry() throws {
        let root = repoRoot()
        // candidate commit exists
        let cand = try git(root, ["rev-parse", "--verify", "--quiet", candidateSHA + "^{commit}"])
        XCTAssertEqual(cand.status, 0); XCTAssertEqual(cand.out, candidateSHA)
        // annotated tag OBJECT identity + dereference
        let tagObj = try git(root, ["rev-parse", "refs/tags/" + tagName])
        XCTAssertEqual(tagObj.out, tagObjectSHA)
        XCTAssertEqual(try git(root, ["cat-file", "-t", tagName]).out, "tag")
        XCTAssertEqual(try git(root, ["rev-parse", tagName + "^{commit}"]).out, candidateSHA)
        // methodology anchor + AUDIT15 commit are ancestors of the candidate
        XCTAssertEqual(try git(root, ["merge-base", "--is-ancestor", anchorSHA, candidateSHA]).status, 0)
        XCTAssertEqual(try git(root, ["merge-base", "--is-ancestor", audit15SHA, candidateSHA]).status, 0)
    }

    func test02_Audit15_ByteImmutability_ZeroInversions() throws {
        let root = repoRoot()
        let frozen = try Data(contentsOf: root.appendingPathComponent(
            "docs/audit/AUDIT15_RWCPre14R1ReauditProbes_ORIGINAL_LOCKED.swift.txt"))
        let active = try Data(contentsOf: root.appendingPathComponent(
            "packages/GuardianKit/Tests/GuardianCoreTests/AUDIT15_RWCPre14R1ReauditProbes.swift"))
        XCTAssertEqual(sha256Hex(frozen), audit15FrozenSHA256, "frozen AUDIT15 copy SHA drifted")
        XCTAssertEqual(frozen, active, "active AUDIT15 probe is not byte-identical to the frozen original")
        // AUDIT15 report byte-unchanged since the AUDIT15 commit
        let diff = try git(root, ["diff", "--name-only", audit15SHA, candidateSHA, "--",
                                  "docs/audit/GEN8_RWC_PREREGISTRATION_PRE14_R1_INDEPENDENT_REAUDIT.md"])
        XCTAssertEqual(diff.out, "", "AUDIT15 report was modified after its commit")
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §3 — zero-data forensic gate + production locks
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test03_ZeroData_Counters_ProductionLocks() throws {
        let root = repoRoot()
        let data = try Data(contentsOf: root.appendingPathComponent(
            "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml"))
        let m = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(m["corpus_count"] as? Int, 0)
        XCTAssertEqual(m["annotator_count"] as? Int, 0)
        XCTAssertEqual(m["real_fit_count"] as? Int, 0)
        XCTAssertEqual(m["heldout_open_count"] as? Int, 0)
        XCTAssertEqual(m["data_visibility"] as? Bool, false)
        // no PASS lock exists in the candidate
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("docs/audit/RWC_PRE14_PASS_LOCK.yaml").path))
        // production stays engineering-only: 59 synthetic pairs, no real-world claims, gates closed
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59)
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims)
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0)
        XCTAssertFalse(RealWorldCalibrationExecutorV1.preregistrationAuditPassed)
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §4 — A15-F1: the DATE TYPE itself (not just the parser)
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test04_F1_Parser_RefusalMatrix() {
        func refused(_ s: String) {
            XCTAssertThrowsError(try RWCDateV2.parse(s, field: "m"), s)
        }
        refused("2026-02-31"); refused("2026-04-31"); refused("2026-02-29") // 2026 not leap
        refused("1900-02-29")                                              // century non-leap
        refused("2026-00-10"); refused("2026-13-10")                       // month 0 / 13
        refused("2026-05-00"); refused("2026-05-32")                       // day 0 / 32
        refused("-026-05-01"); refused("2026-05-1x"); refused(" 2026-05-01")
        refused("٢٠٢٦-05-01")                                              // non-ASCII digits
        XCTAssertNoThrow(try RWCDateV2.parse("2024-02-29", field: "m"))    // real leap day
        XCTAssertNoThrow(try RWCDateV2.parse("2000-02-29", field: "m"))    // 400-rule leap day
        XCTAssertNoThrow(try RWCDateV2.parse("0000-01-01", field: "m"))    // parser domain floor
        XCTAssertNoThrow(try RWCDateV2.parse("9999-12-31", field: "m"))    // parser domain ceiling
    }

    /// AUDIT16 FINDING A16-F1: pins defective behavior.
    /// RWCDateV2's public memberwise init(year:month:day:) performs NO validation: impossible civil
    /// dates (2026-02-31, month 13, negative components) are REPRESENTABLE as typed values, and no
    /// authority boundary (validateRecord / register / clock) revalidates them. The parser can be
    /// bypassed entirely: an impossible date flows into the clock, the record, the eligibility laws
    /// and the DURABLE event chain. A15-F1 is closed at the parser, NOT at the type.
    func test05_F1_FINDING_DirectInit_Bypass_IntoStoreAndChain() throws {
        // impossible values are representable
        let imp = RWCDateV2(year: 2026, month: 2, day: 31)
        XCTAssertEqual(imp.isoString, "2026-02-31")                    // typed impossible value exists
        XCTAssertEqual(RWCDateV2(year: 2026, month: 13, day: 99).isoString, "2026-13-99")
        XCTAssertEqual(RWCDateV2(year: -5, month: 0, day: 0).isoString, "-005-00-00")
        XCTAssertEqual(RWCDateV2(year: 12026, month: 1, day: 1).isoString, "12026-01-01") // outside parse domain
        // injection 1: impossible acquisitionDate is ACCEPTED by validateRecord + register
        let store = RWCAssetRightsLedgerStoreV2()
        let r = record(acquisition: imp, ev: evidence("f1ev0001", bytes: "proof-f1"))
        let clock = RWCFixedClockV1(date("2026-03-15"))
        XCTAssertNoThrow(try store.register(r, clock: clock),
                         "AUDIT16-F1: impossible acquisition date 2026-02-31 registered without refusal")
        // the impossible date is now embedded in the DURABLE SHA-256 event chain
        XCTAssertEqual(store.events.first?.effectiveDate, "2026-02-31")
        // injection 2: impossible CLOCK date is accepted as 'today' by every law
        let store2 = RWCAssetRightsLedgerStoreV2()
        let badClock = RWCFixedClockV1(RWCDateV2(year: 2026, month: 13, day: 99))
        let r2 = record(id: "rwc-asset-a16aaa02", acquisition: date("2026-09-01"),
                        ev: evidence("f1ev0002", bytes: "proof-f1b"))
        XCTAssertNoThrow(try store2.register(r2, clock: badClock),
                         "AUDIT16-F1: impossible clock date 2026-13-99 accepted as today")
        XCTAssertEqual(store2.events.first?.recordedDate, "2026-13-99")
        // injection 3: impossible expiry passes the only date-order check
        let store3 = RWCAssetRightsLedgerStoreV2()
        let r3 = record(id: "rwc-asset-a16aaa03", acquisition: date("2026-02-28"),
                        expiry: RWCDateV2(year: 2026, month: 2, day: 31),
                        ev: evidence("f1ev0003", bytes: "proof-f1c"))
        XCTAssertNoThrow(try store3.register(r3, clock: RWCFixedClockV1(date("2026-02-28"))),
                         "AUDIT16-F1: impossible expiry date 2026-02-31 accepted")
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §5 — system UTC clock conversion (independent epoch vectors)
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test06_UTCClock_EpochVectors() {
        func day(_ secs: Int64) -> String {
            RWCAcquisitionClockV1(secondsSince1970: { secs }).today().isoString
        }
        XCTAssertEqual(day(0), "1970-01-01")
        XCTAssertEqual(day(86_399), "1970-01-01")
        XCTAssertEqual(day(86_400), "1970-01-02")
        XCTAssertEqual(day(951_782_400), "2000-02-29")      // leap day, 400-rule
        XCTAssertEqual(day(951_868_800), "2000-03-01")
        XCTAssertEqual(day(2_147_483_647), "2038-01-19")    // Y2038 boundary
        XCTAssertEqual(day(4_102_444_800), "2100-01-01")    // 2100 century non-leap year start
        XCTAssertEqual(day(-2_208_988_800), "1900-01-01")   // exact negative multiple of 86400
        XCTAssertEqual(day(-86_400), "1969-12-31")          // exact negative multiple of 86400
    }

    /// AUDIT16 FINDING A16-F2: pins defective behavior.
    /// RWCAcquisitionClockV1.today() divides with Swift's TRUNCATING integer division
    /// (secondsSince1970() / 86_400), not floor division. For negative timestamps that are not
    /// exact day multiples the civil date is one day LATE: epoch -1 (1969-12-31T23:59:59Z) is
    /// reported as 1970-01-01. Unreachable for real acquisition (today >= 2026), but the frozen
    /// conversion law is only correct on the domain secondsSince1970 >= 0.
    func test07_FINDING_UTCClock_NegativeTruncationOffByOne() {
        func day(_ secs: Int64) -> String {
            RWCAcquisitionClockV1(secondsSince1970: { secs }).today().isoString
        }
        XCTAssertEqual(day(-1), "1970-01-01", "AUDIT16-F2 pin: true UTC civil date is 1969-12-31")
        XCTAssertEqual(day(-86_401), "1969-12-31", "AUDIT16-F2 pin: true UTC civil date is 1969-12-30")
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §6 — rights event chronology battery (fresh angles)
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test08_Chronology_Battery() throws {
        let ev1 = evidence("c6ev0001", bytes: "proof-c6a")
        // registration recorded before acquisition date → acquisitionInFuture
        let s1 = RWCAssetRightsLedgerStoreV2()
        XCTAssertThrowsError(try s1.register(record(acquisition: date("2026-09-10"), ev: ev1),
                                             clock: RWCFixedClockV1(date("2026-09-01")))) {
            XCTAssertEqual($0 as? RWCRightsErrorV2, .acquisitionInFuture)
        }
        // revocation clock earlier than registration event → chronology violation (no time travel)
        let s2 = RWCAssetRightsLedgerStoreV2()
        try s2.register(record(acquisition: date("2026-09-01"), ev: ev1),
                        clock: RWCFixedClockV1(date("2026-09-10")))
        XCTAssertThrowsError(try s2.revoke(assetID: "rwc-asset-a16aaa01",
                                           clock: RWCFixedClockV1(date("2026-09-05")))) {
            guard case .chronologyViolation = $0 as? RWCRightsErrorV2 else { return XCTFail("\($0)") }
        }
        // revocation of unknown asset → assetUnknown (revocation before registration)
        let s3 = RWCAssetRightsLedgerStoreV2()
        XCTAssertThrowsError(try s3.revoke(assetID: "rwc-asset-a16aaa01",
                                           clock: RWCFixedClockV1(date("2026-09-01")))) {
            XCTAssertEqual($0 as? RWCRightsErrorV2, .assetUnknown)
        }
        // reauthorize before any revocation → notRevoked
        try s2.revoke(assetID: "rwc-asset-a16aaa01", clock: RWCFixedClockV1(date("2026-09-20")))
        let s4 = RWCAssetRightsLedgerStoreV2()
        try s4.register(record(acquisition: date("2026-09-01"), ev: ev1),
                        clock: RWCFixedClockV1(date("2026-09-10")))
        XCTAssertThrowsError(try s4.reauthorize(record(acquisition: date("2026-09-11"),
                                                       ev: evidence("c6ev0002", bytes: "proof-c6b")),
                                                clock: RWCFixedClockV1(date("2026-09-12")))) {
            XCTAssertEqual($0 as? RWCRightsErrorV2, .notRevoked)
        }
        // reauthorized acquisition BEFORE the revocation date → dateOrderViolation
        XCTAssertThrowsError(try s2.reauthorize(record(acquisition: date("2026-09-15"),
                                                       ev: evidence("c6ev0003", bytes: "proof-c6c")),
                                                clock: RWCFixedClockV1(date("2026-09-25")))) {
            guard case .dateOrderViolation = $0 as? RWCRightsErrorV2 else { return XCTFail("\($0)") }
        }
        // eligibility query dated before the last event → chronologyViolation (non-revoked store;
        // on a tombstoned asset the .revoked refusal fires first)
        XCTAssertThrowsError(try s4.requireEligible(assetID: "rwc-asset-a16aaa01", use: .training,
                                                    clock: RWCFixedClockV1(date("2026-09-05")))) {
            guard case .chronologyViolation = $0 as? RWCRightsErrorV2 else { return XCTFail("\($0)") }
        }
        // and on the tombstoned asset the refusal is .revoked — still a refusal, never eligibility
        XCTAssertThrowsError(try s2.requireEligible(assetID: "rwc-asset-a16aaa01", use: .training,
                                                    clock: RWCFixedClockV1(date("2026-09-15")))) {
            XCTAssertEqual($0 as? RWCRightsErrorV2, .revoked)
        }
        // expired grant refused AT registration
        let s5 = RWCAssetRightsLedgerStoreV2()
        XCTAssertThrowsError(try s5.register(record(acquisition: date("2026-01-01"),
                                                    expiry: date("2026-06-30"), ev: ev1),
                                             clock: RWCFixedClockV1(date("2026-09-01")))) {
            XCTAssertEqual($0 as? RWCRightsErrorV2, .expiredAtRegistration)
        }
        // expiry valid THROUGH the expiry date; one day later → expired
        let s6 = RWCAssetRightsLedgerStoreV2()
        try s6.register(record(acquisition: date("2026-01-01"), expiry: date("2026-09-01"), ev: ev1),
                        clock: RWCFixedClockV1(date("2026-08-01")))
        XCTAssertNoThrow(try s6.requireEligible(assetID: "rwc-asset-a16aaa01", use: .training,
                                                clock: RWCFixedClockV1(date("2026-09-01"))))
        XCTAssertThrowsError(try s6.requireEligible(assetID: "rwc-asset-a16aaa01", use: .training,
                                                    clock: RWCFixedClockV1(date("2026-09-02")))) {
            XCTAssertEqual($0 as? RWCRightsErrorV2, .expired)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §7/§8 — evidence identity: BYTE identity vs LEGAL identity
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    /// AUDIT16 FINDING A16-F3: pins defective behavior (semantic overclaim).
    /// Reauthorization requires only a digest NEVER SEEN for the asset. The SAME legal proof,
    /// reserialized (whitespace / metadata / re-export → new bytes), with the SAME rights holder,
    /// SAME license type and SAME evidenceVersion, is accepted as a lawful NEW grant. NEW BYTES are
    /// treated as NEW LEGAL AUTHORITY; no frozen law requires a new grant version, new holder
    /// attestation or an external review step. (Conversely a bumped evidenceVersion with the same
    /// digest is refused — the version field carries no authority at all.)
    func test09_FINDING_Evidence_NewBytes_MasqueradeAsNewLegalGrant() throws {
        let store = RWCAssetRightsLedgerStoreV2()
        let proofV1 = "LICENSE GRANT #42: asset a16aaa01, holder licensor-x, term 2026"
        let proofV1Reserialized = proofV1 + "\n"   // same legal instrument, one byte appended
        XCTAssertNotEqual(sha256Hex(proofV1), sha256Hex(proofV1Reserialized))
        try store.register(record(acquisition: date("2026-09-01"),
                                  ev: evidence("e7ev0001", bytes: proofV1)),
                           clock: RWCFixedClockV1(date("2026-09-01")))
        try store.revoke(assetID: "rwc-asset-a16aaa01", clock: RWCFixedClockV1(date("2026-09-10")))
        // same digest + bumped evidenceVersion → refused (digest is the ONLY identity)
        XCTAssertThrowsError(try store.reauthorize(
            record(acquisition: date("2026-09-15"),
                   ev: evidence("e7ev0002", bytes: proofV1, version: "v2.0")),
            clock: RWCFixedClockV1(date("2026-09-15")))) {
            XCTAssertEqual($0 as? RWCRightsErrorV2, .reauthorizationRequiresNewEvidence)
        }
        // SAME legal proof, trivially reserialized, same holder/license/version → ACCEPTED
        XCTAssertNoThrow(try store.reauthorize(
            record(acquisition: date("2026-09-15"),
                   ev: evidence("e7ev0003", bytes: proofV1Reserialized)),
            clock: RWCFixedClockV1(date("2026-09-16"))),
            "AUDIT16-F3: a whitespace reserialization of the SAME proof reauthorized the asset")
        XCTAssertNoThrow(try store.requireEligible(assetID: "rwc-asset-a16aaa01", use: .training,
                                                   clock: RWCFixedClockV1(date("2026-09-16"))))
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §9/§10 — durable journal: PROCESS RESTART hard attack
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    /// AUDIT16 FINDING A16-F4: pins defective behavior.
    /// RWCAssetRightsLedgerStoreV2(journal:) initializes EMPTY — it performs NO replay. After a
    /// process restart the canonical rights state (records, tombstones, seenEvidenceDigests,
    /// revocationDates, lastEventDate) is GONE: a revoked asset can be re-registered with the
    /// ORIGINAL revoked evidence digest, and the fresh store then writes seq=0 events into the
    /// existing journal, destroying the chain (replay of the combined file fails). The journal is
    /// an append-only AUDIT LOG, not durable authoritative state. "Durable rights authority" does
    /// not survive restart.
    func test10_FINDING_ProcessRestart_LosesRightsState_CorruptsJournal() throws {
        let dir = try tempDir("journal-restart")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("rights.jsonl")
        let journal = RWCAssetRightsJournalV1(url: url)
        let revokedProof = "proof-r9-original"
        // session A: register + revoke, then "process dies"
        do {
            let a = RWCAssetRightsLedgerStoreV2(journal: journal)
            try a.register(record(acquisition: date("2026-09-01"),
                                  ev: evidence("r9ev0001", bytes: revokedProof)),
                           clock: RWCFixedClockV1(date("2026-09-01")))
            try a.revoke(assetID: "rwc-asset-a16aaa01", clock: RWCFixedClockV1(date("2026-09-10")))
            XCTAssertTrue(a.isTombstoned("rwc-asset-a16aaa01"))
            XCTAssertEqual(a.eventCount, 2)
        }
        XCTAssertEqual(try RWCAssetRightsJournalV1.replay(url: url).count, 2) // journal is intact
        // session B: NEW store over the SAME journal — state is empty
        let b = RWCAssetRightsLedgerStoreV2(journal: RWCAssetRightsJournalV1(url: url))
        XCTAssertNil(b.record(for: "rwc-asset-a16aaa01"),
                     "AUDIT16-F4 pin: restart forgot the registered record")
        XCTAssertFalse(b.isTombstoned("rwc-asset-a16aaa01"),
                       "AUDIT16-F4 pin: restart forgot the tombstone")
        XCTAssertEqual(b.eventCount, 0, "AUDIT16-F4 pin: restart forgot the event chain")
        // resurrection with the ORIGINAL revoked evidence digest now SUCCEEDS
        XCTAssertNoThrow(try b.register(record(acquisition: date("2026-09-12"),
                                               ev: evidence("r9ev0002", bytes: revokedProof)),
                                        clock: RWCFixedClockV1(date("2026-09-12"))),
                         "AUDIT16-F4: revoked asset re-registered with the revoked evidence after restart")
        XCTAssertNoThrow(try b.requireEligible(assetID: "rwc-asset-a16aaa01", use: .training,
                                               clock: RWCFixedClockV1(date("2026-09-12"))))
        // and the lawful append from the fresh store CORRUPTED the shared journal (seq restarts at 0)
        XCTAssertThrowsError(try RWCAssetRightsJournalV1.replay(url: url)) { e in
            guard case .sequenceGap = e as? RWCRightsJournalErrorV1 else { return XCTFail("\(e)") }
        }
    }

    /// AUDIT16 FINDING A16-F5: pins structural gap.
    /// Journal events carry ONLY {seq, prev, asset, kind, evidenceDigest, effectiveDate,
    /// recordedDate, digest}. Allowed/prohibited uses, expiry, rights holder, license type, source
    /// class, content hash and provenance are NOT in the journal, so full eligibility state CANNOT
    /// be reconstructed from replay() even in principle, and no reconstruction API exists.
    func test11_FINDING_Journal_CannotReconstructEligibilityState() throws {
        let dir = try tempDir("journal-recon")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("rights.jsonl")
        let store = RWCAssetRightsLedgerStoreV2(journal: RWCAssetRightsJournalV1(url: url))
        try store.register(record(acquisition: date("2026-09-01"), expiry: date("2027-09-01"),
                                  ev: evidence("rcev0001", bytes: "proof-rc"),
                                  allowed: ["training"], training: true, evaluation: false),
                           clock: RWCFixedClockV1(date("2026-09-01")))
        let events = try RWCAssetRightsJournalV1.replay(url: url)
        XCTAssertEqual(events.count, 1)
        // the journal line for a training-only record with expiry 2027-09-01 carries NEITHER fact
        let raw = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(raw.contains("training"), "AUDIT16-F5 pin: use rights are not journaled")
        XCTAssertFalse(raw.contains("2027-09-01"), "AUDIT16-F5 pin: expiry is not journaled")
        XCTAssertFalse(raw.contains("licensor"), "AUDIT16-F5 pin: rights holder is not journaled")
        // mirror of the Mirror: RWCRightsEventV2 has exactly the 8 chain fields, no rights payload
        let m = Mirror(reflecting: events[0])
        XCTAssertEqual(Set(m.children.compactMap { $0.label }),
                       ["seq", "previousDigest", "assetID", "kind", "evidenceDigest",
                        "effectiveDate", "recordedDate", "eventDigest"])
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §11 — head witness: truncation invisible without an external durable witness
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    /// AUDIT16 FINDING A16-F6: pins structural gap.
    /// verifyHead() needs expectedHeadDigest+expectedCount from an EXTERNAL witness, but no durable
    /// witness is persisted anywhere (the store head lives only in process memory, which A16-F4
    /// shows is lost). Deriving the witness from the truncated journal itself verifies cleanly:
    /// truncation is structurally INVISIBLE across restart.
    func test12_FINDING_HeadWitness_TruncationInvisibleAfterRestart() throws {
        let dir = try tempDir("journal-trunc")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("rights.jsonl")
        let store = RWCAssetRightsLedgerStoreV2(journal: RWCAssetRightsJournalV1(url: url))
        try store.register(record(acquisition: date("2026-09-01"),
                                  ev: evidence("twev0001", bytes: "proof-tw1")),
                           clock: RWCFixedClockV1(date("2026-09-01")))
        try store.revoke(assetID: "rwc-asset-a16aaa01", clock: RWCFixedClockV1(date("2026-09-02")))
        try store.reauthorize(record(acquisition: date("2026-09-03"),
                                     ev: evidence("twev0002", bytes: "proof-tw2")),
                              clock: RWCFixedClockV1(date("2026-09-03")))
        let trueHead = store.headDigest
        // adversary truncates the journal to 2 events (drops the reauthorization)
        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
        try (lines[0] + "\n" + lines[1] + "\n").write(to: url, atomically: true, encoding: .utf8)
        // replay is INTERNALLY consistent after truncation
        let truncated = try RWCAssetRightsJournalV1.replay(url: url)
        XCTAssertEqual(truncated.count, 2)
        // a correct external witness WOULD catch it …
        XCTAssertThrowsError(try RWCAssetRightsJournalV1.verifyHead(
            url: url, expectedHeadDigest: trueHead, expectedCount: 3))
        // … but after restart the only available witness IS the truncated journal: verifies clean
        XCTAssertNoThrow(try RWCAssetRightsJournalV1.verifyHead(
            url: url, expectedHeadDigest: truncated.last!.eventDigest, expectedCount: 2),
            "AUDIT16-F6 pin: self-derived witness makes truncation invisible")
        // no durable witness artifact exists next to the journal
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted(),
                       ["rights.jsonl"], "AUDIT16-F6 pin: no persisted head witness exists")
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §12/§13 — journal concurrency + crash consistency
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    /// AUDIT16 FINDING A16-F7: pins structural gap.
    /// No single-writer invariant exists (no file lock, no declared law in RWC_RIGHTS_LAW_V2.md):
    /// two stores over the same journal each lawfully append seq=0, producing a journal that can
    /// never replay again. Interleaved multi-writer use silently loses the chain.
    func test13_FINDING_Journal_TwoWriters_DuplicateSeqZero() throws {
        let dir = try tempDir("journal-concurrent")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("rights.jsonl")
        let a = RWCAssetRightsLedgerStoreV2(journal: RWCAssetRightsJournalV1(url: url))
        let b = RWCAssetRightsLedgerStoreV2(journal: RWCAssetRightsJournalV1(url: url))
        try a.register(record(id: "rwc-asset-a16wrt01", acquisition: date("2026-09-01"),
                              ev: evidence("cwev0001", bytes: "proof-cw1")),
                       clock: RWCFixedClockV1(date("2026-09-01")))
        try b.register(record(id: "rwc-asset-a16wrt02", acquisition: date("2026-09-01"),
                              ev: evidence("cwev0002", bytes: "proof-cw2")),
                       clock: RWCFixedClockV1(date("2026-09-01")))
        let raw = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(raw.components(separatedBy: "\"seq\":0").count - 1, 2,
                       "AUDIT16-F7 pin: two seq=0 events in one journal")
        XCTAssertThrowsError(try RWCAssetRightsJournalV1.replay(url: url)) { e in
            guard case .sequenceGap = e as? RWCRightsJournalErrorV1 else { return XCTFail("\(e)") }
        }
    }

    func test14_Journal_CrashConsistency_PartialLine_FailsClosed() throws {
        let dir = try tempDir("journal-crash")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("rights.jsonl")
        let store = RWCAssetRightsLedgerStoreV2(journal: RWCAssetRightsJournalV1(url: url))
        try store.register(record(acquisition: date("2026-09-01"),
                                  ev: evidence("crev0001", bytes: "proof-cr1")),
                           clock: RWCFixedClockV1(date("2026-09-01")))
        // simulate a crash mid-append: partial JSON tail without newline
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"v\":\"rwc-rights-event-v2\",\"seq\":1,\"prev\":\"ab".utf8))
        try handle.close()
        XCTAssertThrowsError(try RWCAssetRightsJournalV1.replay(url: url)) { e in
            XCTAssertEqual(e as? RWCRightsJournalErrorV1, .malformedLine(index: 1))
        }
        // reorder attack: swap two valid lines → chain break detected
        let dir2 = try tempDir("journal-reorder")
        defer { try? FileManager.default.removeItem(at: dir2) }
        let url2 = dir2.appendingPathComponent("rights.jsonl")
        let s2 = RWCAssetRightsLedgerStoreV2(journal: RWCAssetRightsJournalV1(url: url2))
        try s2.register(record(acquisition: date("2026-09-01"),
                               ev: evidence("crev0002", bytes: "proof-cr2")),
                        clock: RWCFixedClockV1(date("2026-09-01")))
        try s2.revoke(assetID: "rwc-asset-a16aaa01", clock: RWCFixedClockV1(date("2026-09-02")))
        let lines = try String(contentsOf: url2, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
        try (lines[1] + "\n" + lines[0] + "\n").write(to: url2, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try RWCAssetRightsJournalV1.replay(url: url2))
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §14 — cryptographic chain: independent canonical-byte reconstruction
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    private func audit16CanonicalDigest(seq: Int, prev: String, asset: String, kind: String,
                                        evd: String, eff: String, rec: String) -> String {
        // independent reimplementation of the canonical length-prefixed byte law
        var bytes: [UInt8] = []
        for field in ["rwc-rights-event-v2", String(seq), prev, asset, kind, evd, eff, rec] {
            let u = Array(field.utf8)
            let n = UInt32(u.count)
            bytes.append(contentsOf: [UInt8((n >> 24) & 0xFF), UInt8((n >> 16) & 0xFF),
                                      UInt8((n >> 8) & 0xFF), UInt8(n & 0xFF)])
            bytes.append(contentsOf: u)
        }
        return SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
    }

    func test15_EventChain_IndependentVectors_BoundaryAmbiguity() {
        XCTAssertEqual(RWCRightsEventV2.genesisDigest, sha256Hex("GEN8-RWC-RIGHTS-CHAIN-V2-GENESIS"))
        // independent digest reconstruction across representative vectors
        let vectors: [(Int, String, String, String, String, String, String)] = [
            (0, RWCRightsEventV2.genesisDigest, "rwc-asset-a16aaa01", "registered",
             sha256Hex("p1"), "2026-09-01", "2026-09-01"),
            (1, sha256Hex("prev"), "rwc-asset-a16aaa01", "revoked", sha256Hex("p1"),
             "2026-09-10", "2026-09-10"),
            (1_099_511_627_776, sha256Hex("prev"), "rwc-asset-ünïcode", "reauthorized", // large seq + Unicode
             sha256Hex("p2"), "2026-09-11", "2026-09-11"),
        ]
        for v in vectors {
            let e = RWCRightsEventV2(seq: v.0, previousDigest: v.1, assetID: v.2, kind: v.3,
                                     evidenceDigest: v.4, effectiveDate: v.5, recordedDate: v.6)
            XCTAssertEqual(e.eventDigest, audit16CanonicalDigest(seq: v.0, prev: v.1, asset: v.2,
                                                                 kind: v.3, evd: v.4, eff: v.5, rec: v.6))
        }
        // field-boundary ambiguity: ("ab","c") vs ("a","bc") MUST differ (length prefixes)
        let d1 = RWCRightsEventV2(seq: 0, previousDigest: "ab", assetID: "c", kind: "k",
                                  evidenceDigest: "e", effectiveDate: "f", recordedDate: "r").eventDigest
        let d2 = RWCRightsEventV2(seq: 0, previousDigest: "a", assetID: "bc", kind: "k",
                                  evidenceDigest: "e", effectiveDate: "f", recordedDate: "r").eventDigest
        XCTAssertNotEqual(d1, d2, "length-prefixed canonical bytes must kill boundary aliasing")
        // cross-instance determinism
        let e1 = RWCRightsEventV2(seq: 7, previousDigest: sha256Hex("x"), assetID: "rwc-asset-a16aaa01",
                                  kind: "registered", evidenceDigest: sha256Hex("y"),
                                  effectiveDate: "2026-09-01", recordedDate: "2026-09-01")
        let e2 = RWCRightsEventV2(seq: 7, previousDigest: sha256Hex("x"), assetID: "rwc-asset-a16aaa01",
                                  kind: "registered", evidenceDigest: sha256Hex("y"),
                                  effectiveDate: "2026-09-01", recordedDate: "2026-09-01")
        XCTAssertEqual(e1.eventDigest, e2.eventDigest)
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §15 — calibration v3 input domain (fresh)
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test16_CalibrationV3_InputDomain_Fresh() {
        typealias M = RWCCalibrationMethodologyV3
        func refuse(_ preds: [Double], _ labels: [Bool], bins: Int = 10) {
            XCTAssertThrowsError(try M.eceTieInvariant(preds: preds, labels: labels, bins: bins))
        }
        refuse([], [])
        refuse([0.5], [true, false])
        refuse([Double.nan, 0.5], [true, false])
        refuse([Double.infinity, 0.5], [true, false])
        refuse([-Double.infinity, 0.5], [true, false])
        refuse([-0.0000001, 0.5], [true, false])
        refuse([1.0000001, 0.5], [true, false])
        refuse([0.5, 0.5], [true, false], bins: 0)
        refuse([0.5, 0.5], [true, false], bins: 3)   // bins > n
        // extreme-but-valid p=0 / p=1
        XCTAssertNoThrow(try M.eceTieInvariant(preds: [0.0, 1.0], labels: [false, true], bins: 2))
        // simulation-count law: (S+1) % 20 == 0 and S >= 19
        func simRefuse(_ s: Int) {
            XCTAssertThrowsError(try M.decideV3(preds: [0.5, 0.5], labels: [true, false],
                                                bins: 2, sims: s, seedParts: ["audit16", "sim"]))
        }
        simRefuse(18); simRefuse(20); simRefuse(998); simRefuse(0); simRefuse(-1)
        XCTAssertNoThrow(try M.decideV3(preds: [0.5, 0.5], labels: [true, false], bins: 2,
                                        sims: 19, seedParts: ["audit16", "s19"]))
        XCTAssertNoThrow(try M.decideV3(preds: [0.5, 0.5], labels: [true, false], bins: 2,
                                        sims: 39, seedParts: ["audit16", "s39"]))
        XCTAssertNoThrow(try M.decideV3(preds: [0.5, 0.5], labels: [true, false], bins: 2,
                                        sims: 999, seedParts: ["audit16", "s999"]))
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §16/§17 — tie-group law: independent implementation + permutation invariance + float edges
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    /// Independent tie-group ECE implementation (written from the FROZEN LAW TEXT in
    /// RWC_FROZEN_GATES_V3.yaml, not from the builder code).
    private func audit16ECE(preds: [Double], labels: [Bool], bins: Int) -> Double {
        let n = preds.count
        var positives: [Double: Int] = [:], counts: [Double: Int] = [:]
        for (p, y) in zip(preds, labels) {
            counts[p, default: 0] += 1
            if y { positives[p, default: 0] += 1 }
        }
        let values = counts.keys.sorted()
        var sumP = [Double](repeating: 0, count: bins)
        var sumY = [Double](repeating: 0, count: bins)
        var cnt = [Int](repeating: 0, count: bins)
        var cStart = 0
        for v in values {
            let c = counts[v]!
            let b = (cStart * bins) / n
            sumP[b] += v * Double(c)
            sumY[b] += Double(positives[v] ?? 0)
            cnt[b] += c
            cStart += c
        }
        var ece = 0.0
        for b in 0..<bins where cnt[b] > 0 {
            let c = Double(cnt[b])
            ece += c / Double(n) * abs(sumP[b] / c - sumY[b] / c)
        }
        return ece
    }

    func test17_TieLaw_IndependentImplementation_PermutationInvariance() throws {
        typealias M = RWCCalibrationMethodologyV3
        var rng = RWCSplitMix64(seed: 0xA16A16A16)
        // differential: independent implementation == builder implementation, exactly
        for _ in 0..<50 {
            let n = 20 + Int(rng.next() % 200)
            var preds = [Double](), labels = [Bool]()
            for _ in 0..<n {
                // heavy quantization → many ties, including boundary-straddling tie groups
                preds.append(Double(Int(rng.double01() * 8.0)) / 8.0)
                labels.append(rng.double01() < 0.5)
            }
            let mine = audit16ECE(preds: preds, labels: labels, bins: 10)
            let theirs = try M.eceTieInvariant(preds: preds, labels: labels, bins: 10)
            XCTAssertEqual(mine, theirs, "independent tie-law implementation must agree exactly")
        }
        // permutation invariance of statistic AND verdict (300 shuffles)
        var preds = [Double](), labels = [Bool]()
        for i in 0..<120 {
            preds.append([0.0, 0.1, 0.5, 0.5, 0.5, 0.9, 1.0][i % 7])
            labels.append(i % 3 == 0)
        }
        let baseECE = try M.eceTieInvariant(preds: preds, labels: labels, bins: 10)
        let baseDec = try M.decideV3(preds: preds, labels: labels, sims: 199,
                                     seedParts: ["audit16", "perm"])
        var idx = Array(0..<preds.count)
        for _ in 0..<300 {
            for i in (1..<idx.count).reversed() { idx.swapAt(i, Int(rng.next() % UInt64(i + 1))) }
            let p = idx.map { preds[$0] }, l = idx.map { labels[$0] }
            XCTAssertEqual(try M.eceTieInvariant(preds: p, labels: l, bins: 10), baseECE)
            let d = try M.decideV3(preds: p, labels: l, sims: 199, seedParts: ["audit16", "perm"])
            XCTAssertEqual(d, baseDec, "verdict must be a pure function of the multiset")
        }
        // one huge tie group crossing several ideal bins: all p=0.5
        let allHalf = [Double](repeating: 0.5, count: 100)
        let y = (0..<100).map { $0 < 50 }
        XCTAssertEqual(try M.eceTieInvariant(preds: allHalf, labels: y, bins: 10), 0.0,
                       "single tie group, 50/50 labels → exact 0 (group never split)")
        let y2 = (0..<100).map { $0 < 30 }
        XCTAssertEqual(try M.eceTieInvariant(preds: allHalf, labels: y2, bins: 10), 0.2, accuracy: 1e-12)
    }

    func test18_FloatEdges_EqualityLaw() throws {
        typealias M = RWCCalibrationMethodologyV3
        // +0.0 and -0.0 are numerically equal → ONE tie group (Swift Double == semantics)
        let plan = M.tieGroupPlan(preds: [0.0, -0.0, 0.5], bins: 3)
        XCTAssertEqual(plan.groupCounts.first, 2, "+0.0/-0.0 form one tie group (numeric equality law)")
        let e = try M.eceTieInvariant(preds: [0.0, -0.0], labels: [false, false], bins: 2)
        XCTAssertEqual(e, 0.0)
        // adjacent-but-distinct IEEE values are DIFFERENT groups
        let v = 0.5
        let plan2 = M.tieGroupPlan(preds: [v, v.nextUp, v.nextDown], bins: 3)
        XCTAssertEqual(plan2.groupValues.count, 3)
        // subnormal probabilities are valid inputs
        XCTAssertNoThrow(try M.eceTieInvariant(preds: [Double.leastNonzeroMagnitude, 0.5],
                                               labels: [false, true], bins: 2))
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §18 — exact MC integer boundary
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test19_ExactMC_IntegerBoundary_Consistency() throws {
        typealias M = RWCCalibrationMethodologyV3
        // frozen law at S=999: FAIL iff 20*(1+exceed) <= 1000 ⇔ exceed <= 49.
        // exceed 48,49 → FAIL; 50,51 → PASS (pMC = 0.049, 0.050, 0.051, 0.052).
        for (exceed, expectFail) in [(48, true), (49, true), (50, false), (51, false)] {
            XCTAssertEqual(20 * (1 + exceed) <= 1000, expectFail, "exceed=\(exceed)")
            let pMC = Double(1 + exceed) / 1000.0
            XCTAssertEqual(pMC <= 0.05, expectFail, "float form agrees at exceed=\(exceed)")
        }
        // decision consistency on live datasets: recover exceed from pMC and check the gate bit
        var rng = RWCSplitMix64(seed: 0xB16B00B5)
        for sims in [19, 39, 999] {
            for t in 0..<40 {
                var preds = [Double](), labels = [Bool]()
                for _ in 0..<60 {
                    let p = rng.double01()
                    preds.append(p); labels.append(rng.double01() < p * 0.9)
                }
                let d = try M.decideV3(preds: preds, labels: labels, sims: sims,
                                       seedParts: ["audit16", "bound", String(sims), String(t)])
                let exceed = Int((d.pMC * Double(sims + 1)).rounded()) - 1
                XCTAssertEqual(d.testGatePassed, !(20 * (1 + exceed) <= sims + 1))
                // determinism: identical seedParts → identical decision
                let d2 = try M.decideV3(preds: preds, labels: labels, sims: sims,
                                        seedParts: ["audit16", "bound", String(sims), String(t)])
                XCTAssertEqual(d, d2)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §20/§21 — seed law: context aliasing + outcome-independence status
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    /// AUDIT16 FINDING A16-F8: pins defective behavior.
    /// seed64 joins parts with '|' and NOTHING forbids '|' inside a part: ["a|b","c"] and
    /// ["a","b|c"] produce the SAME seed (context aliasing). No separator-grammar law is enforced
    /// in code or declared in the frozen seed law.
    func test20_FINDING_SeedLaw_ContextAliasing() {
        typealias M = RWCCalibrationMethodologyV3
        XCTAssertEqual(M.seed64(["a|b", "c"]), M.seed64(["a", "b|c"]),
                       "AUDIT16-F8 pin: seed context aliases across part boundaries")
        // independent verification of the seed law itself
        let context = "GEN8-RWC-CAL-V3|eval|deadbeef|metric-x"
        let digest = SHA256.hash(data: Data(context.utf8))
        var expected: UInt64 = 0
        for (i, b) in digest.enumerated() where i < 8 { expected = (expected << 8) | UInt64(b) }
        XCTAssertEqual(M.seed64(["eval", "deadbeef", "metric-x"]), expected)
    }

    func test21_SeedLaw_DatasetManifest_ContentUndefined() throws {
        // The REAL evaluation seed hashes '<datasetManifestSHA256>' but NO frozen artifact defines
        // WHAT the dataset manifest contains (labels? annotations? predictions?). Pin the current
        // state: the placeholder exists; the gates text declares intent ("never outcome-inspecting")
        // but a content schema does not exist anywhere in the frozen surface. (Report: A16-F9.)
        let gates = try String(contentsOf: repoRoot().appendingPathComponent(
            "docs/calibration/preregistration/RWC_FROZEN_GATES_V3.yaml"), encoding: .utf8)
        XCTAssertTrue(gates.contains("<datasetManifestSHA256>"))
        XCTAssertTrue(gates.contains("never outcome-inspecting"))
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §27/§28 — coverage: relational gaps + decided-set semantics
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    /// AUDIT16 FINDING A16-F10: pins defective behavior (LOW).
    /// Sentinel reporting is three-way (protective / explicit decision / abstention) per gates v3,
    /// but coverageV2 never enforces protective+decided <= total: an impossible census
    /// (3 protective + 3 decided among 4 sentinels) is accepted and produces rates summing > 1.
    func test22_FINDING_Coverage_SentinelRelational_Gap_And_Fresh() throws {
        typealias M = RWCCalibrationMethodologyV3
        let impossible = M.RWCCoverageCountsV1(inDistDecided: 10, inDistTotal: 10, oodAbstained: 0,
                                               oodTotal: 0, sentinelProtective: 3, sentinelDecided: 3,
                                               sentinelTotal: 4)
        let rep = try M.coverageV2(impossible)
        XCTAssertEqual(rep.sentinelProtectiveRate, .value(0.75),
                       "AUDIT16-F10 pin: impossible three-way census accepted")
        XCTAssertEqual(rep.sentinelExplicitDecisionRate, .value(0.75))
        // fresh invalid counters still refused
        XCTAssertThrowsError(try M.coverageV2(M.RWCCoverageCountsV1(
            inDistDecided: -1, inDistTotal: 5, oodAbstained: 0, oodTotal: 0,
            sentinelProtective: 0, sentinelDecided: 0, sentinelTotal: 0)))
        XCTAssertThrowsError(try M.coverageV2(M.RWCCoverageCountsV1(
            inDistDecided: 6, inDistTotal: 5, oodAbstained: 0, oodTotal: 0,
            sentinelProtective: 0, sentinelDecided: 0, sentinelTotal: 0)))
        // zero denominators stay NOT_APPLICABLE
        let z = try M.coverageV2(M.RWCCoverageCountsV1(inDistDecided: 0, inDistTotal: 0,
                                                       oodAbstained: 0, oodTotal: 0,
                                                       sentinelProtective: 0, sentinelDecided: 0,
                                                       sentinelTotal: 0))
        XCTAssertEqual(z.decisionCoverage, .notApplicable)
        XCTAssertThrowsError(try M.requireDecisionCoverageGate(M.RWCCoverageCountsV1(
            inDistDecided: 0, inDistTotal: 0, oodAbstained: 0, oodTotal: 0,
            sentinelProtective: 0, sentinelDecided: 0, sentinelTotal: 0)))
        // 80% easy / 20% systematically-hard abstention construction passes the gate — lawful ONLY
        // because the frozen claim is DECIDED-SET conditional (gates v3 decided_set_semantics).
        XCTAssertNoThrow(try M.requireDecisionCoverageGate(M.RWCCoverageCountsV1(
            inDistDecided: 800, inDistTotal: 1000, oodAbstained: 0, oodTotal: 0,
            sentinelProtective: 0, sentinelDecided: 0, sentinelTotal: 0)))
        let gates = try String(contentsOf: repoRoot().appendingPathComponent(
            "docs/calibration/preregistration/RWC_FROZEN_GATES_V3.yaml"), encoding: .utf8)
        XCTAssertTrue(gates.contains("decided_set_semantics"))
        XCTAssertTrue(gates.contains("no claim extends to them"))
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §29 — IRR threshold drift (.60 → .61)
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    /// AUDIT16 FINDING A16-F11: pins documentation drift.
    /// Historical frozen law (RWC_FROZEN_GATES.yaml v2 + PRE-08 protocol) sets the ordinal kappa
    /// CI-lower threshold at 0.60. Frozen v3 (RWC_FROZEN_GATES_V3.yaml + RWC_IRR_PLANNING_V3.md)
    /// states 0.61 while claiming the law is "UNCHANGED"/"carried v2 law", and the R2 change
    /// ledger does not disclose the numeric change. Stricter direction, pre-data, but a SILENT
    /// preregistration threshold drift with internal document inconsistency.
    func test23_FINDING_IRR_ThresholdDrift_60_vs_61() throws {
        let root = repoRoot()
        func read(_ rel: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8)
        }
        let v2 = try read("docs/calibration/preregistration/RWC_FROZEN_GATES.yaml")
        XCTAssertTrue(v2.contains("CI lower bound >= 0.60"), "historical v2 law is 0.60")
        let pre08 = try read("docs/calibration/preregistration/protocols/RWC_PRE08_IRR_METHODOLOGY.md")
        XCTAssertTrue(pre08.contains("kappa_w >= 0.60 retained"), "PRE-08 frozen protocol is 0.60")
        let v3 = try read("docs/calibration/preregistration/RWC_FROZEN_GATES_V3.yaml")
        XCTAssertTrue(v3.contains("CI LOWER BOUND >= 0.61"), "AUDIT16-F11 pin: v3 states 0.61")
        XCTAssertTrue(v3.contains("carried v2 law"), "AUDIT16-F11 pin: v3 claims it carried the v2 law")
        let irr = try read("docs/calibration/preregistration/RWC_IRR_PLANNING_V3.md")
        XCTAssertTrue(irr.contains(">= .61"), "AUDIT16-F11 pin: planning v3 states .61")
        XCTAssertTrue(irr.contains("UNCHANGED"), "AUDIT16-F11 pin: planning v3 claims UNCHANGED")
        let ledger = try read("docs/calibration/preregistration/RWC_PREREGISTRATION_R2_CHANGE_LEDGER.md")
        XCTAssertFalse(ledger.contains("0.61"), "AUDIT16-F11 pin: drift is NOT disclosed in the ledger")
        XCTAssertFalse(ledger.contains(".60 -> .61"))
        // code has NO canonical v3 kappa-threshold constant; the decision function takes a
        // caller-provided threshold (historical tests pass 0.60)
        let m = RWCCalibrationMethodologyV1.irrKappaDecision(a: [0, 1, 2, 3, 4, 0, 1, 2, 3, 4] * 12,
                                                             b: [0, 1, 2, 3, 4, 0, 1, 2, 3, 4] * 12,
                                                             categories: 5, threshold: 0.60)
        XCTAssertNotNil(m.point) // threshold is injected, not frozen in code
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §31/§32 — freeze v3 census + anchor law (independent recount)
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test24_FreezeV3_IndependentCensus_AnchorLaw() throws {
        let root = repoRoot()
        let manifestRel = "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V3.yaml"
        let data = try Data(contentsOf: root.appendingPathComponent(manifestRel))
        let m = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(m["methodology_anchor_commit"] as? String, anchorSHA)
        let artifacts = m["artifacts"] as! [[String: Any]]
        let rules = m["surface_rules"] as! [String: Any]
        let hashExempt = Set(rules["hash_exempt"] as! [String])
        let postAnchor = Set(rules["post_anchor_allowed"] as! [String])
        XCTAssertEqual(artifacts.count, 68)
        var classes: [String: Int] = [:]
        var pathToSHA: [String: String] = [:]
        for a in artifacts {
            let path = a["path"] as! String
            XCTAssertNil(pathToSHA[path], "duplicate artifact path")
            pathToSHA[path] = (a["sha256"] as! String)
            classes[a["class"] as! String, default: 0] += 1
            if hashExempt.contains(path) { continue }
            let fileData = try Data(contentsOf: root.appendingPathComponent(path))
            XCTAssertEqual(sha256Hex(fileData), a["sha256"] as! String, path)
        }
        XCTAssertEqual(classes, ["FROZEN_NORMATIVE": 41, "METHODOLOGY_CODE": 11,
                                 "SUPERSEDED_FROZEN_HISTORY": 8, "TEST_EVIDENCE": 4,
                                 "LEGACY_ENGINEERING_FROZEN": 3, "MUTABLE_BY_LAW": 1])
        // independent inventory digest
        let lines = pathToSHA.keys.sorted().map { "\($0):\(pathToSHA[$0]!)" }.joined(separator: "\n")
        XCTAssertEqual(sha256Hex(lines), m["frozen_inventory_digest"] as? String)
        XCTAssertEqual(m["frozen_inventory_digest"] as? String,
                       "fb5626813cc87605215e09ee63399cdd0b1b2a448b922052af3002eebd661e2d")
        // ANCHOR LAW: the ONLY paths changed between anchor and candidate are the two lawful
        // post-anchor artifacts (manifest SELF + R2 remediation report)
        let diff = try git(root, ["diff", "--name-only", anchorSHA, candidateSHA])
        XCTAssertEqual(Set(diff.out.split(separator: "\n").map(String.init)), postAnchor)
        XCTAssertEqual(postAnchor.count, 2)
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §33–§43 — PASS-lock verifier authority attacks (synthetic git fixtures ONLY)
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    private struct A16Fixture {
        let root: URL
        let base: String        // pre-anchor commit (valid unrelated ancestor)
        let anchor: String
        let auditCommit: String
        let candidate: String
        let tagObject: String
        let manifestPath: String
        let reportPath: String
    }

    /// Independent fixture builder (attacker-grade): lawful by default, every field patchable.
    private func makeA16Fixture(reportContent: String = "AUDIT REPORT\nVERDICT: PASS\n",
                                masterManifest: String =
                                    "{\"data_visibility\": false, \"corpus_count\": 0}\n")
        throws -> A16Fixture {
        let root = try tempDir("fixture")
        try git(root, ["init", "-q"])
        // pre-anchor base commit (so an UNRELATED-but-valid commit exists)
        try writeFile(root, "README.md", "fixture\n")
        try git(root, ["add", "-A"]); try git(root, ["commit", "-q", "-m", "base"])
        let base = try git(root, ["rev-parse", "HEAD"]).out
        // anchor: frozen files
        let gates = "{\"gates\": \"a16-fixture-v3\"}\n"
        let code = "// RWCFixtureLaw — frozen methodology code\n"
        try writeFile(root, "docs/prereg/gates.yaml", gates)
        try writeFile(root, "code/RWCFixtureLaw.swift", code)
        try writeFile(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
                      masterManifest)
        try git(root, ["add", "-A"]); try git(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try git(root, ["rev-parse", "HEAD"]).out
        // freeze manifest (SELF hash-exempt) + audit report
        let manifestPath = "docs/prereg/MANIFEST_V3.yaml"
        let reportPath = "docs/audit/report.md"
        let artifacts = [("docs/prereg/gates.yaml", sha256Hex(gates)),
                         ("code/RWCFixtureLaw.swift", sha256Hex(code)),
                         (manifestPath, "SELF")]
        let invDigest = sha256Hex(artifacts.map { "\($0.0):\($0.1)" }.sorted().joined(separator: "\n"))
        let manifest = """
        {"freeze_version": "a16-fixture-v3", "methodology_anchor_commit": "\(anchor)",
         "frozen_inventory_digest": "\(invDigest)",
         "artifacts": [\(artifacts.map { "{\"path\": \"\($0.0)\", \"sha256\": \"\($0.1)\"}" }.joined(separator: ", "))],
         "surface_rules": {"doc_root": "docs/prereg",
           "code_scan": [{"root": "code", "prefixes": ["RWC"]}],
           "post_anchor_allowed": [], "hash_exempt": ["\(manifestPath)"]}}
        """
        try writeFile(root, manifestPath, manifest)
        try writeFile(root, reportPath, reportContent)
        try git(root, ["add", "-A"]); try git(root, ["commit", "-q", "-m", "audit evidence"])
        let auditCommit = try git(root, ["rev-parse", "HEAD"]).out
        let lock: [String: Any] = [
            "lock_version": "rwc-pre14-pass-lock-v1", "verdict": "PASS",
            "candidate_commit": "PENDING", "candidate_tag_name": "a16-candidate",
            "candidate_tag_object_sha": "PENDING", "audit_commit": auditCommit,
            "audit_report_path": reportPath, "audit_report_sha256": sha256Hex(reportContent),
            "freeze_version": "a16-fixture-v3", "freeze_manifest_path": manifestPath,
            "freeze_manifest_sha256": sha256Hex(manifest),
            "methodology_anchor_commit": anchor, "frozen_inventory_digest": invDigest,
            "governing_control_plane_lock": "2c345b64c720f965b68ec5ee699e1b71fecf0003",
            "created_by_closeout": true, "corpus_entry_authorized": true,
        ]
        let lockData = try JSONSerialization.data(withJSONObject: lock)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("docs/audit"), withIntermediateDirectories: true)
        try lockData.write(to: root.appendingPathComponent(RWCPre14PassLockV1.lockRelPath))
        try git(root, ["add", "-A"]); try git(root, ["commit", "-q", "-m", "closeout"])
        let candidate = try git(root, ["rev-parse", "HEAD"]).out
        try git(root, ["tag", "-a", "a16-candidate", "-m", "candidate"])
        let tagObject = try git(root, ["rev-parse", "refs/tags/a16-candidate"]).out
        try patchLock(root) { $0["candidate_commit"] = candidate; $0["candidate_tag_object_sha"] = tagObject }
        return A16Fixture(root: root, base: base, anchor: anchor, auditCommit: auditCommit,
                          candidate: candidate, tagObject: tagObject,
                          manifestPath: manifestPath, reportPath: reportPath)
    }

    private func patchLock(_ root: URL, _ mutate: (inout [String: Any]) -> Void) throws {
        let url = root.appendingPathComponent(RWCPre14PassLockV1.lockRelPath)
        var obj = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        mutate(&obj)
        try JSONSerialization.data(withJSONObject: obj).write(to: url)
    }

    func test25_Verifier_LawfulFixture_Mints_Control() throws {
        let f = try makeA16Fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        let proof = try RWCCorpusEntryVerifierV2.verify(repoRoot: f.root)
        XCTAssertEqual(proof.candidateCommit, f.candidate)
        XCTAssertEqual(proof.auditCommit, f.auditCommit)
    }

    /// AUDIT16 FINDING A16-F12: pins defective behavior.
    /// The verifier checks lock.verdict == "PASS" and that the lock's report SHA matches the LIVE
    /// report file — it NEVER verifies that the AUDIT ITSELF concluded PASS. A report whose full
    /// content says "VERDICT: FIX REQUIRED" plus a caller-authored lock with verdict="PASS" and the
    /// correct SHA of that FIX report MINTS RWCVerifiedCorpusEntryV1. The lock's own PASS string
    /// substitutes for the independent audit verdict → A15-F12 is NOT fully closed.
    func test26_FINDING_Verifier_ForgedPASS_Over_FIXReport() throws {
        let fixReport = "INDEPENDENT PRE-14 AUDIT\nVERDICT: FIX REQUIRED — RWC PREREGISTRATION R2\n"
        let f = try makeA16Fixture(reportContent: fixReport)
        defer { try? FileManager.default.removeItem(at: f.root) }
        // lock already says PASS with the CORRECT sha of the FIX-REQUIRED report
        let proof = try RWCCorpusEntryVerifierV2.verify(repoRoot: f.root)
        XCTAssertEqual(proof.candidateCommit, f.candidate,
                       "AUDIT16-F12: proof minted although the audit report says FIX REQUIRED")
    }

    /// AUDIT16 FINDING A16-F13: pins defective behavior.
    /// The verifier hashes the LIVE report file; it never runs `git show <audit_commit>:<path>`.
    /// A report REWRITTEN AFTER the audit commit (e.g. FIX → PASS text), with the lock hashing the
    /// newer live file, verifies: the audit_commit does NOT actually bind the report.
    func test27_FINDING_Verifier_LiveReport_NotBoundToAuditCommit() throws {
        let f = try makeA16Fixture(reportContent: "VERDICT: FIX REQUIRED\n")
        defer { try? FileManager.default.removeItem(at: f.root) }
        // attacker rewrites the report AFTER the audit commit and re-points the lock's sha
        let rewritten = "VERDICT: PASS (rewritten after the audit commit)\n"
        try writeFile(f.root, f.reportPath, rewritten)
        try patchLock(f.root) { $0["audit_report_sha256"] = self.sha256Hex(rewritten) }
        // the committed report at audit_commit still says FIX REQUIRED
        let committed = try git(f.root, ["show", "\(f.auditCommit):\(f.reportPath)"]).out
        XCTAssertTrue(committed.contains("FIX REQUIRED"))
        let proof = try RWCCorpusEntryVerifierV2.verify(repoRoot: f.root)
        XCTAssertEqual(proof.auditCommit, f.auditCommit,
                       "AUDIT16-F13: minted with a live report that differs from the audit commit's report")
    }

    /// AUDIT16 FINDING A16-F14: pins defective behavior.
    /// audit_commit is only checked for EXISTENCE. Any unrelated repository commit (here: the
    /// pre-anchor base commit that contains no audit evidence at all) is accepted. No
    /// candidate↔audit ancestry or audited-target relationship is verified.
    func test28_FINDING_Verifier_UnrelatedAuditCommit() throws {
        let f = try makeA16Fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        try patchLock(f.root) { $0["audit_commit"] = f.base }   // unrelated commit, no audit content
        let proof = try RWCCorpusEntryVerifierV2.verify(repoRoot: f.root)
        XCTAssertEqual(proof.auditCommit, f.base,
                       "AUDIT16-F14: arbitrary existing commit accepted as the independent audit")
    }

    /// AUDIT16 FINDING A16-F15: pins defective behavior.
    /// governing_control_plane_lock is parsed but NEVER verified; lock.freeze_version is never
    /// cross-checked against the manifest's own freeze_version; lock.methodology_anchor_commit is
    /// never cross-checked against the manifest's methodology_anchor_commit (any valid ancestor
    /// passes); the manifest's own frozen_inventory_digest field is never read.
    func test29_FINDING_Verifier_GoverningLock_FreezeVersion_AnchorCrossChecks() throws {
        // (a) fake governing control-plane lock SHA → mints
        let f1 = try makeA16Fixture()
        defer { try? FileManager.default.removeItem(at: f1.root) }
        try patchLock(f1.root) { $0["governing_control_plane_lock"] = String(repeating: "f00dbabe", count: 5) }
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV2.verify(repoRoot: f1.root),
                         "AUDIT16-F15a: fake governing lock accepted")
        // (b) lock freeze_version v999 vs manifest a16-fixture-v3 → mints
        let f2 = try makeA16Fixture()
        defer { try? FileManager.default.removeItem(at: f2.root) }
        try patchLock(f2.root) { $0["freeze_version"] = "a16-fixture-v999" }
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV2.verify(repoRoot: f2.root),
                         "AUDIT16-F15b: freeze_version mismatch accepted")
        // (c) lock anchor != manifest anchor (both valid ancestors) → mints
        let f3 = try makeA16Fixture()
        defer { try? FileManager.default.removeItem(at: f3.root) }
        try patchLock(f3.root) { $0["methodology_anchor_commit"] = f3.base }
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV2.verify(repoRoot: f3.root),
                         "AUDIT16-F15c: lock anchor differing from the manifest anchor accepted")
    }

    /// AUDIT16 FINDING A16-F16: pins defective behavior.
    /// The verifier accepts ANY caller-named freeze_manifest_path. An attacker-authored MINIMAL
    /// alternative manifest (own tiny doc_root, empty code scan) narrows the governed surface to
    /// nearly nothing: the canonical frozen files are no longer verified at all, yet the proof
    /// mints. The exact audited manifest identity (path + hash) is not pinned by the verifier.
    func test30_FINDING_Verifier_AlternativeMiniManifest() throws {
        let f = try makeA16Fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        // attacker's mini-surface: one trivial doc, no code scan
        let miniDoc = "mini\n"
        try writeFile(f.root, "docs/mini/README.md", miniDoc)
        let miniPath = "docs/mini/MINI_MANIFEST.yaml"
        let miniArtifacts = [("docs/mini/README.md", sha256Hex(miniDoc)), (miniPath, "SELF")]
        let miniInv = sha256Hex(miniArtifacts.map { "\($0.0):\($0.1)" }.sorted().joined(separator: "\n"))
        let mini = """
        {"freeze_version": "mini-v1", "methodology_anchor_commit": "\(f.anchor)",
         "artifacts": [\(miniArtifacts.map { "{\"path\": \"\($0.0)\", \"sha256\": \"\($0.1)\"}" }.joined(separator: ", "))],
         "surface_rules": {"doc_root": "docs/mini", "code_scan": [],
           "post_anchor_allowed": [], "hash_exempt": ["\(miniPath)"]}}
        """
        try writeFile(f.root, miniPath, mini)
        try patchLock(f.root) {
            $0["freeze_manifest_path"] = miniPath
            $0["freeze_manifest_sha256"] = self.sha256Hex(mini)
            $0["frozen_inventory_digest"] = miniInv
        }
        // now TAMPER a canonical frozen file — the mini surface never looks at it
        try writeFile(f.root, "docs/prereg/gates.yaml", "{\"gates\": \"TAMPERED\"}\n")
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV2.verify(repoRoot: f.root),
                         "AUDIT16-F16: mini-manifest narrowed PASS authority; tampered frozen file unnoticed")
    }

    /// AUDIT16 FINDING A16-F17: pins defective behavior.
    /// The zero-visibility transition law reads ONLY data_visibility and corpus_count from the
    /// master manifest. A manifest with annotator_count=3, real_fit_count=1, heldout_open_count=2
    /// (all sequencing violations) still mints corpus-entry authority.
    func test31_FINDING_Verifier_MasterManifest_OtherCountersIgnored() throws {
        let master = """
        {"data_visibility": false, "corpus_count": 0, "annotator_count": 3,
         "real_fit_count": 1, "heldout_open_count": 2}\n
        """
        let f = try makeA16Fixture(masterManifest: master)
        defer { try? FileManager.default.removeItem(at: f.root) }
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV2.verify(repoRoot: f.root),
                         "AUDIT16-F17: nonzero annotator/fit/heldout counters do not block corpus entry")
        // control: the two checked fields DO refuse
        let g = try makeA16Fixture(masterManifest: "{\"data_visibility\": true, \"corpus_count\": 0}\n")
        defer { try? FileManager.default.removeItem(at: g.root) }
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.verify(repoRoot: g.root)) {
            XCTAssertEqual($0 as? RWCCorpusEntryErrorV2, .dataAlreadyVisible)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §34/§35/§36 — surface scanner: recursion, prefix, symlink bypass (synthetic fixtures)
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    /// AUDIT16 FINDING A16-F18: pins defective behavior.
    /// Code roots are scanned with TOP-LEVEL contentsOfDirectory (not recursive), while Swift
    /// compiles package sources RECURSIVELY. A behavior-changing file in a SUBDIRECTORY of a
    /// governed code root (even with a governed RWC prefix) escapes SET-EQUALITY entirely.
    /// The doc root (recursive enumerator) DOES catch subdirectory files — code roots do not.
    func test32_FINDING_Scanner_RecursiveDirectoryBypass() throws {
        let f = try makeA16Fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        // control: new file under the DOC root is caught (recursive scan)
        try writeFile(f.root, "docs/prereg/sub/RWC_NEW_LAW.md", "new law\n")
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.verify(repoRoot: f.root)) { e in
            guard case let .surfaceSetMismatch(extra, _) = e as? RWCCorpusEntryErrorV2 else {
                return XCTFail("\(e)")
            }
            XCTAssertEqual(extra, ["docs/prereg/sub/RWC_NEW_LAW.md"])
        }
        try FileManager.default.removeItem(at: f.root.appendingPathComponent("docs/prereg/sub"))
        // attack: governed-prefix file in a SUBDIRECTORY of the code root → invisible
        try writeFile(f.root, "code/Hidden/RWCCalibrationBypass.swift", "// bypass law\n")
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV2.verify(repoRoot: f.root),
                         "AUDIT16-F18: code-root subdirectory file escaped the SET-EQUALITY scan")
    }

    /// AUDIT16 FINDING A16-F19: pins defective behavior.
    /// Code-root scanning filters by FILENAME PREFIX. A behavior-changing file with an ungoverned
    /// name (StatisticalHelper.swift / RightsOverride.swift) in the SAME compiled module escapes
    /// the scan even at top level. Frozen code would not need modification for future corpus code
    /// to call it.
    func test33_FINDING_Scanner_PrefixBypass() throws {
        let f = try makeA16Fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        try writeFile(f.root, "code/StatisticalHelper.swift", "// ungoverned name, same module\n")
        try writeFile(f.root, "code/RightsOverride.swift", "// ungoverned name, same module\n")
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV2.verify(repoRoot: f.root),
                         "AUDIT16-F19: non-prefixed files in a governed code root escaped the scan")
        // control: a prefixed TOP-LEVEL file IS caught
        try writeFile(f.root, "code/RWCSneakyTopLevel.swift", "// governed prefix\n")
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.verify(repoRoot: f.root))
    }

    /// AUDIT16 FINDING A16-F20: pins defective behavior.
    /// A SYMLINK under the governed doc root pointing OUTSIDE it is silently SKIPPED by the scan
    /// (resolved-prefix check `continue`s) instead of being reported as drift: a new methodology
    /// entry can be added as a symlink without tripping SET-EQUALITY.
    func test34_FINDING_Scanner_SymlinkEscape() throws {
        let f = try makeA16Fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        try writeFile(f.root, "outside/EXTERNAL_LAW.md", "external methodology text\n")
        try FileManager.default.createSymbolicLink(
            at: f.root.appendingPathComponent("docs/prereg/NEW_LAW_LINK.md"),
            withDestinationURL: f.root.appendingPathComponent("outside/EXTERNAL_LAW.md"))
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV2.verify(repoRoot: f.root),
                         "AUDIT16-F20: out-of-root symlink in the doc root not reported as drift")
        // control: a REGULAR new file at the same path IS caught
        try FileManager.default.removeItem(at: f.root.appendingPathComponent("docs/prereg/NEW_LAW_LINK.md"))
        try writeFile(f.root, "docs/prereg/NEW_LAW_FILE.md", "x\n")
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.verify(repoRoot: f.root))
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §48 — post-audit freeze surface (before/after lock)
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test35_FreezeSurface_PostAuditDrift_CaughtWhereScanned() throws {
        // new methodology file (governed location) AFTER the lock, BEFORE first asset: refused at
        // verification time — verification is live, not one-time (within the scanner's blind spots
        // documented in A16-F18/F19/F20).
        let f = try makeA16Fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        try writeFile(f.root, "docs/prereg/RWC_POST_LOCK_ADDITION.md", "post-lock methodology\n")
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.verify(repoRoot: f.root)) { e in
            guard case .surfaceSetMismatch = e as? RWCCorpusEntryErrorV2 else { return XCTFail("\(e)") }
        }
        // frozen-file content drift after lock: refused by live hash recomputation
        let g = try makeA16Fixture()
        defer { try? FileManager.default.removeItem(at: g.root) }
        try writeFile(g.root, "code/RWCFixtureLaw.swift", "// drifted methodology code\n")
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.verify(repoRoot: g.root)) { e in
            XCTAssertEqual(e as? RWCCorpusEntryErrorV2, .frozenFileDrift(path: "code/RWCFixtureLaw.swift"))
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §45/§46 — real acquisition enforcement status + first-asset composition
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test36_AcquisitionEnforcement_TestTargetOnly_CompositionGate() throws {
        let root = repoRoot()
        // The verifier and proof type live in the TEST target, not in any production/library/tool
        // source: no executable acquisition runner exists yet. (Report §45: PASS wording must be
        // narrowed to tooling-work authorization; FIRST-ASSET stays blocked.)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(
            "packages/GuardianKit/Tests/GuardianCoreTests/RWCCorpusEntryVerifierV2.swift").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(
            "packages/GuardianKit/Sources/GuardianCore/RWCCorpusEntryVerifierV2.swift").path))
        // composition gate: a minted proof alone does NOT bypass per-asset rights
        let f = try makeA16Fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        let proof = try RWCCorpusEntryVerifierV2.verify(repoRoot: f.root)
        let store = RWCAssetRightsLedgerStoreV2()
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.requireAcquisitionStart(
            proof: proof, store: store, assetID: "rwc-asset-a16aaa01", use: .training,
            clock: RWCFixedClockV1(date("2026-10-01")))) {
            XCTAssertEqual($0 as? RWCRightsErrorV2, .assetUnknown)
        }
        // training-only record never authorizes evaluation use even with a global proof
        try store.register(record(acquisition: date("2026-09-01"),
                                  ev: evidence("acev0001", bytes: "proof-ac"),
                                  allowed: ["training"], training: true, evaluation: false),
                           clock: RWCFixedClockV1(date("2026-09-01")))
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV2.requireAcquisitionStart(
            proof: proof, store: store, assetID: "rwc-asset-a16aaa01", use: .evaluation,
            clock: RWCFixedClockV1(date("2026-10-01")))) {
            XCTAssertEqual($0 as? RWCRightsErrorV2, .useNotAllowed(use: "evaluation"))
        }
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV2.requireAcquisitionStart(
            proof: proof, store: store, assetID: "rwc-asset-a16aaa01", use: .training,
            clock: RWCFixedClockV1(date("2026-10-01"))))
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §53 — legacy PRE-03/PRE-04 regression
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test37_Legacy_Pre03Pre04_Regression() throws {
        // invalid RWC composite IDs can NEVER mint a prepared-dataset token
        XCTAssertThrowsError(try CalibrationRunPreparationV1.prepareDataset(
            declaredIDs: ["not-a-composite"], resolvedIDs: ["not-a-composite"])) { e in
            guard case .invalidRWCCompositeIDs = e as? CalibrationIntegrityErrorV1 else {
                return XCTFail("\(e)")
            }
        }
        // executor remains a typed refusal gated on PRE-14
        XCTAssertFalse(RealWorldCalibrationExecutorV1.preregistrationAuditPassed)
        // F6/F6b payload-binding invariant still carried in the master manifest
        let data = try Data(contentsOf: repoRoot().appendingPathComponent(
            "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml"))
        let m = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(m["rwc_fit_binding_invariant"])
    }
}

private func * (lhs: [Int], rhs: Int) -> [Int] {
    var out: [Int] = []; out.reserveCapacity(lhs.count * rhs)
    for _ in 0..<rhs { out.append(contentsOf: lhs) }
    return out
}
