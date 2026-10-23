import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT17_RWC_PRE14_R3_REAUDIT — independent clean-session re-audit probe family (part 1 of 3).
// Fresh probes; nothing copied from builder R3 tests. Probes that PIN defective behavior are
// marked "AUDIT17 FINDING A17-Fn: pins defective behavior" and assert the CURRENT (defective)
// behavior so the suite stays green while the defect remains on record.
// ZERO-DATA: synthetic fixtures only; no media/labels/predictions/real grants.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

enum A17 {
    static let candidate = "17418d4736f94f7b098b1018d44d1f391c7ea21c"
    static let tagName = "gen8-rwc-preregistration-r3-audit-candidate"
    static let tagObject = "9dfac63d0b7ccdd078de6d1f767e11bd0a8b513f"
    static let anchor = "e85346208170a8d8b34eb80b6bd47900d71f29e2"
    static let governing = "2c345b64c720f965b68ec5ee699e1b71fecf0003"
    static let inventoryDigest = "921730b5fec2c23976757dc19b6eb7a76825bc3bee946d568b9258f201d5b0ee"
    static let masterPath = "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml"

    static func repoRoot() -> URL {
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<6 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("docs/calibration").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    static func sha256Hex(_ d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }
    static func shaHex(_ s: String) -> String { sha256Hex(Data(s.utf8)) }

    @discardableResult
    static func run(_ exe: String, _ args: [String], cwd: URL? = nil) throws -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = [exe] + args
        if let cwd { p.currentDirectoryURL = cwd }
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus,
                String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }

    @discardableResult
    static func git(_ root: URL, _ args: [String]) throws -> (Int32, String) {
        try run("git", ["-C", root.path, "-c", "user.name=audit17", "-c", "user.email=audit17@local"] + args)
    }

    static func gitShowRaw(_ root: URL, _ spec: String) throws -> Data {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git", "-C", root.path, "show", spec]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return data
    }

    static func tempDir(_ tag: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("a17-\(tag)-\(UUID().uuidString.prefix(8))")
    }

    static func write(_ root: URL, _ rel: String, _ content: String) throws {
        let url = root.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // Independent auditor factories (not builder helpers).
    static func d(_ iso: String) -> RWCDateV3 { try! RWCDateV3.parse(iso, field: "a17") }

    static func grant(id: String = "rwc-grant-a17g0001", rev: Int = 1,
                      digestSeed: String = "a17-proof-1", pointer: String = "rwc-rights-ref-a17p0001",
                      holder: String = "licensor-a17",
                      allowed: [String] = ["training", "evaluation"], prohibited: [String] = [],
                      effective: String = "2026-08-01", expiry: String? = "2027-08-01",
                      decision: String = "APPROVED",
                      review: String = "rwc-review-a17r0001") -> RWCLegalGrantIdentityV1 {
        RWCLegalGrantIdentityV1(grantID: id, grantRevision: rev, evidenceDigest: shaHex(digestSeed),
                                evidencePointer: pointer, rightsHolder: holder, allowedUse: allowed,
                                prohibitedUse: prohibited, effectiveDate: d(effective),
                                expiryDate: expiry.map { d($0) }, reviewDecision: decision,
                                reviewRecordID: review)
    }

    static func approvedReview(_ g: RWCLegalGrantIdentityV1,
                               reviewDate: String = "2026-08-15") -> RWCRightsReviewRecordV1 {
        RWCRightsReviewRecordV1(reviewRecordID: g.reviewRecordID, grantID: g.grantID,
                                grantRevision: g.grantRevision, evidenceDigest: g.evidenceDigest,
                                decision: "APPROVED", reviewDate: d(reviewDate))
    }

    static func mint(_ g: RWCLegalGrantIdentityV1) throws -> RWCVerifiedRightsGrantV1 {
        try RWCRightsReviewAuthorityV1.verify(grant: g, reviewRecord: approvedReview(g))
    }

    static func record(asset: String = "rwc-asset-a17asset01", g: RWCLegalGrantIdentityV1? = nil,
                       sourceClass: RWCSourceClassV1 = .licensedRightsClear,
                       sourceRef: String = "rwc-source-ref-a17s0001", owner: String = "gen8-a17",
                       acquisition: String = "2026-09-01", contentHash: String? = nil,
                       provenance: [String]? = nil) -> RWCAssetRightsRecordV3 {
        RWCAssetRightsRecordV3(assetID: asset, sourceClass: sourceClass, sourceReference: sourceRef,
                               owner: owner, grant: g ?? grant(), acquisitionDate: d(acquisition),
                               contentHash: contentHash ?? shaHex("a17-content-1"),
                               provenanceChain: provenance ?? [sourceRef])
    }

    static func clock(_ iso: String) -> RWCFixedClockV3 { try! RWCFixedClockV3(iso) }
}

// MARK: - independent statistics engine (own RNG, own ECE, own decision; frozen-design generators)

enum A17Stat {
    struct RNG {
        var s: UInt64
        init(seed: UInt64) { s = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
        mutating func next() -> UInt64 {
            s ^= s >> 12; s ^= s << 25; s ^= s >> 27
            return s &* 0x2545_F491_4F6C_DD1D
        }
        mutating func u01() -> Double { Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0) }
    }

    /// Independent seeding (own domain string; own LP framing implementation).
    static func seed(_ parts: [String]) -> UInt64 {
        var bytes = Data()
        func lp(_ s: String) {
            let b = Data(s.utf8)
            var len = UInt32(b.count).bigEndian
            withUnsafeBytes(of: &len) { bytes.append(contentsOf: $0) }
            bytes.append(b)
        }
        lp("AUDIT17-INDEPENDENT-STAT")
        var n = UInt32(parts.count).bigEndian
        withUnsafeBytes(of: &n) { bytes.append(contentsOf: $0) }
        for p in parts { lp(p) }
        let digest = SHA256.hash(data: bytes)
        var v: UInt64 = 0
        for (i, b) in digest.enumerated() where i < 8 { v = (v << 8) | UInt64(b) }
        return v
    }

    static func clamp01(_ x: Double) -> Double { min(1.0, max(0.0, x)) }

    /// Frozen predeclared design shapes (RWC_CALIBRATION_POWER_PREREG_V4 design, re-implemented).
    static func confidence(_ shape: String, _ rng: inout RNG) -> Double {
        switch shape {
        case "skewed": let u = rng.u01(); return u * u
        case "clustered": return rng.u01() < 0.5 ? 0.1 + 0.02 * rng.u01() : 0.85 + 0.1 * rng.u01()
        case "quantized": return Double(min(20, max(0, Int(rng.u01() * 21.0)))) / 20.0
        case "highconf": let u = rng.u01(); return 1.0 - u * u
        case "lowconf": let u = rng.u01(); return u * u * u
        default: return rng.u01()
        }
    }

    static func trueProb(_ alt: String, _ p: Double) -> Double {
        switch alt {
        case "over03": return clamp01(p - 0.03)
        case "over05": return clamp01(p - 0.05)
        case "over07": return clamp01(p - 0.07)
        case "over10": return clamp01(p - 0.10)
        case "under07": return clamp01(p + 0.07)
        case "tail07": return p > 0.8 ? clamp01(p - 0.14) : p
        case "osc05": return clamp01(p + (Int((p * 10.0).rounded(.down)) % 2 == 0 ? 0.05 : -0.05))
        case "localized07": return (p >= 0.4 && p < 0.6) ? clamp01(p + 0.21) : p
        default: return p
        }
    }

    static func dataset(shape: String, alt: String, n: Int, seedParts: [String]) -> ([Double], [Bool]) {
        var rng = RNG(seed: seed(seedParts))
        var preds = [Double](), labels = [Bool]()
        preds.reserveCapacity(n); labels.reserveCapacity(n)
        for _ in 0..<n {
            let p = confidence(shape, &rng)
            preds.append(p)
            labels.append(rng.u01() < trueProb(alt, p))
        }
        return (preds, labels)
    }

    struct Plan { let n: Int; let values: [Double]; let counts: [Int]; let bins: [Int]; let pos: [Int] }

    /// Independent tie-group equal-mass plan: ties atomic; bin = (startIndex*10)/n.
    static func plan(_ preds: [Double], _ labels: [Bool], bins: Int = 10) -> Plan {
        let order = preds.indices.sorted { preds[$0] < preds[$1] }
        var values: [Double] = [], counts: [Int] = [], binIdx: [Int] = [], pos: [Int] = []
        var i = 0
        while i < order.count {
            let v = preds[order[i]]
            var j = i, p = 0
            while j < order.count, preds[order[j]] == v {
                if labels[order[j]] { p += 1 }
                j += 1
            }
            values.append(v); counts.append(j - i); binIdx.append((i * bins) / order.count); pos.append(p)
            i = j
        }
        return Plan(n: order.count, values: values, counts: counts, bins: binIdx, pos: pos)
    }

    static func ece(_ plan: Plan, positives: [Int], bins: Int = 10) -> Double {
        var sumP = [Double](repeating: 0, count: bins)
        var sumY = [Double](repeating: 0, count: bins)
        var cnt = [Int](repeating: 0, count: bins)
        for g in 0..<plan.values.count {
            let b = plan.bins[g]
            sumP[b] += plan.values[g] * Double(plan.counts[g])
            sumY[b] += Double(positives[g])
            cnt[b] += plan.counts[g]
        }
        var e = 0.0
        for b in 0..<bins where cnt[b] > 0 {
            let c = Double(cnt[b])
            e += c / Double(plan.n) * abs(sumP[b] / c - sumY[b] / c)
        }
        return e
    }

    struct Decision { let mcReject: Bool; let combinedReject: Bool; let observed: Double }

    /// Independent frozen decision law: exact MC test (integer boundary) + excess gate <= 0.05.
    static func decide(preds: [Double], labels: [Bool], sims: Int, seedParts: [String]) -> Decision {
        let pl = plan(preds, labels)
        let observed = ece(pl, positives: pl.pos)
        var rng = RNG(seed: seed(seedParts))
        var exceed = 0
        var nullSum = 0.0
        var nullPos = [Int](repeating: 0, count: pl.values.count)
        for _ in 0..<sims {
            for g in 0..<pl.values.count {
                var p = 0
                for _ in 0..<pl.counts[g] where rng.u01() < pl.values[g] { p += 1 }
                nullPos[g] = p
            }
            let e = ece(pl, positives: nullPos)
            nullSum += e
            if e >= observed { exceed += 1 }
        }
        let mcReject = 20 * (1 + exceed) <= (sims + 1)
        let excess = max(0, observed - nullSum / Double(sims))
        return Decision(mcReject: mcReject, combinedReject: mcReject || excess > 0.05, observed: observed)
    }

    static func wilson(_ k: Int, _ n: Int) -> (Double, Double) {
        guard n > 0 else { return (0, 1) }
        let z = 1.959963984540054
        let p = Double(k) / Double(n)
        let den = 1 + z * z / Double(n)
        let c = p + z * z / (2 * Double(n))
        let w = z * (p * (1 - p) / Double(n) + z * z / (4 * Double(n) * Double(n))).squareRoot()
        return ((c - w) / den, (c + w) / den)
    }
}

final class AUDIT17_RWCPre14R3ReauditProbes: XCTestCase {

    private func read(_ rel: String) throws -> String {
        try String(contentsOf: A17.repoRoot().appendingPathComponent(rel), encoding: .utf8)
    }

    private func expectRights(_ expected: RWCRightsErrorV3, _ body: () throws -> Void,
                              _ label: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try body(), label, file: file, line: line) { e in
            XCTAssertEqual(e as? RWCRightsErrorV3, expected, label, file: file, line: line)
        }
    }

    private func expectLedger(_ expected: RWCRightsLedgerErrorV3, _ body: () throws -> Void,
                              _ label: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try body(), label, file: file, line: line) { e in
            XCTAssertEqual(e as? RWCRightsLedgerErrorV3, expected, label, file: file, line: line)
        }
    }

    // MARK: §0 custody

    func test_A17_01_Custody_TagObject_Anchor_Governing() throws {
        let root = A17.repoRoot()
        XCTAssertEqual(try A17.git(root, ["rev-parse", "refs/tags/\(A17.tagName)"]).1, A17.tagObject)
        XCTAssertEqual(try A17.git(root, ["rev-parse", "\(A17.tagName)^{commit}"]).1, A17.candidate)
        XCTAssertEqual(try A17.git(root, ["cat-file", "-t", A17.tagName]).1, "tag")
        XCTAssertEqual(try A17.git(root, ["merge-base", "--is-ancestor", A17.anchor, A17.candidate]).0, 0)
        XCTAssertEqual(try A17.git(root, ["merge-base", "--is-ancestor", A17.candidate, "HEAD"]).0, 0)
        XCTAssertEqual(try A17.git(root,
            ["rev-parse", "\(RWCCorpusEntryVerifierV3Names.governingTag)^{commit}"]).1, A17.governing)
    }

    // MARK: §2 AUDIT16 immutability

    func test_A17_02_Audit16Immutability_ByteIdentical() throws {
        let root = A17.repoRoot()
        let expected = [
            ("AUDIT16_RWCPre14R2ReauditProbes",
             "ed142d0716dfec976a0f31007cfa5f5882b9e334036e25f0c04ea045b49dde6d"),
            ("AUDIT16_StatReplicationRunner",
             "867a7ed3a9045468079cce0884d2af094786fa48b51c0159ce3bec0ffcf7bdfc"),
            ("AUDIT16_DerivationReproProbes",
             "52e11b35137d21c6e42bf84b2621e1db9dcd1e6ea5a7e30cfa8f4b3b6fdea1e9"),
        ]
        for (name, sha) in expected {
            let locked = try Data(contentsOf: root.appendingPathComponent(
                "docs/audit/\(name)_ORIGINAL_LOCKED.swift.txt"))
            let active = try Data(contentsOf: root.appendingPathComponent(
                "packages/GuardianKit/Tests/GuardianCoreTests/\(name).swift"))
            XCTAssertEqual(A17.sha256Hex(locked), sha, name)
            XCTAssertEqual(A17.sha256Hex(active), sha, "\(name) active drifted")
        }
        // prior independent reports unchanged vs the candidate commit blobs (raw bytes)
        for rel in ["docs/audit/GEN8_RWC_PREREGISTRATION_PRE14_R2_INDEPENDENT_REAUDIT.md",
                    "docs/audit/AUDIT16_R3_INVERSION_LOCK.md"] {
            let live = try Data(contentsOf: root.appendingPathComponent(rel))
            let committed = try A17.gitShowRaw(root, "\(A17.candidate):\(rel)")
            XCTAssertEqual(A17.sha256Hex(committed), A17.sha256Hex(live), rel)
        }
    }

    // MARK: §3 zero-data + production locks

    func test_A17_03_ZeroData_ProductionLocks() throws {
        let root = A17.repoRoot()
        let master = try JSONSerialization.jsonObject(with: Data(contentsOf:
            root.appendingPathComponent(A17.masterPath))) as! [String: Any]
        XCTAssertEqual(master["corpus_count"] as? Int, 0)
        XCTAssertEqual(master["annotator_count"] as? Int, 0)
        XCTAssertEqual(master["real_fit_count"] as? Int, 0)
        XCTAssertEqual(master["heldout_open_count"] as? Int, 0)
        XCTAssertEqual(master["data_visibility"] as? Bool, false)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("docs/audit/RWC_PRE14_PASS_LOCK.yaml").path),
            "NO PASS lock may exist")
        // the audit-result instance may exist only as the AUDIT17 machine result itself
        let resPath = root.appendingPathComponent("docs/audit/RWC_PRE14_R3_AUDIT_RESULT.json")
        if FileManager.default.fileExists(atPath: resPath.path) {
            let o = try JSONSerialization.jsonObject(with: Data(contentsOf: resPath)) as! [String: Any]
            XCTAssertEqual(o["audit_probe_family"] as? String, "AUDIT17_RWC_PRE14_R3_REAUDIT")
        }
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims)
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59)
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0)
        XCTAssertFalse(RealWorldCalibrationExecutorV1.preregistrationAuditPassed)
    }

    // MARK: §4 RWCDateV3 construction surface

    func test_A17_04_DateV3_InvalidDatesUnrepresentable() throws {
        let invalid = [(2026, 2, 31), (2026, 4, 31), (2026, 2, 29), (1900, 2, 29), (2026, 0, 15),
                       (2026, 13, 1), (2026, 6, 0), (2026, 1, 32), (-1, 1, 1), (10000, 1, 1)]
        for (y, m, dd) in invalid {
            XCTAssertThrowsError(try RWCDateV3.make(year: y, month: m, day: dd), "\(y)-\(m)-\(dd)")
        }
        XCTAssertNoThrow(try RWCDateV3.make(year: 2000, month: 2, day: 29))
        XCTAssertNoThrow(try RWCDateV3.make(year: 2028, month: 2, day: 29))
        for s in ["2026-02-31", "2026-2-01", "2026/01/01", "20260101xx", "2026-01-01 ", "٢٠٢٦-٠١-٠١"] {
            XCTAssertThrowsError(try RWCDateV3.parse(s, field: "x"), s)
        }
        // construction surface census: no Codable synthesis, no public memberwise init
        XCTAssertFalse(RWCDateV3.self is Decodable.Type, "Codable bypass must not exist")
        XCTAssertFalse(RWCDateV3.self is Encodable.Type)
        let src = try read("packages/GuardianKit/Sources/GuardianCore/RWCRightsV3.swift")
        XCTAssertTrue(src.contains("private init(validatedYear"))
        XCTAssertFalse(src.contains("public init(year"))
    }

    // MARK: §5 UTC clock vs independent civil-date references (python calendar.timegm)

    func test_A17_05_UTCClock_IndependentReferenceVectors() throws {
        func day(_ s: Int64) -> String {
            RWCAcquisitionClockV2(secondsSince1970: { s }).today().isoString
        }
        XCTAssertEqual(day(-1), "1969-12-31")
        XCTAssertEqual(day(-86_399), "1969-12-31")
        XCTAssertEqual(day(-86_400), "1969-12-31")
        XCTAssertEqual(day(-86_401), "1969-12-30")
        XCTAssertEqual(day(0), "1970-01-01")
        XCTAssertEqual(day(1), "1970-01-01")
        XCTAssertEqual(day(86_399), "1970-01-01")
        XCTAssertEqual(day(86_400), "1970-01-02")
        XCTAssertEqual(day(951_782_400), "2000-02-29")          // 2000 leap (div-400)
        XCTAssertEqual(day(951_868_799), "2000-02-29")
        XCTAssertEqual(day(951_868_800), "2000-03-01")
        XCTAssertEqual(day(-2_203_977_600), "1900-02-28")       // 1900 non-leap
        XCTAssertEqual(day(-2_203_891_201), "1900-02-28")
        XCTAssertEqual(day(-2_203_891_200), "1900-03-01")       // no 1900-02-29
        XCTAssertEqual(day(2_147_483_647), "2038-01-19")        // Y2038
        XCTAssertEqual(day(4_107_542_399), "2100-02-28")        // 2100 non-leap
        XCTAssertEqual(day(4_107_542_400), "2100-03-01")
        XCTAssertEqual(day(253_402_300_799), "9999-12-31")      // domain top
    }

    // MARK: §6/§38 rights review authority — the central attack

    func test_A17_06_FINDING_A17F1_FakeApprovedReviewMintable() throws {
        // AUDIT17 FINDING A17-F1: pins defective behavior.
        // An ORDINARY CALLER (this test) authors BOTH the grant and the "APPROVED" review record
        // from thin air — no reviewer identity, no registry, no repository-backed review ledger,
        // no workflow state, no approval commit. verify() mints the "unforgeable" token anyway.
        let forgedGrant = A17.grant(id: "rwc-grant-a17forged1", digestSeed: "bytes-nobody-reviewed",
                                    review: "rwc-review-a17forged1")
        let forgedReview = RWCRightsReviewRecordV1(
            reviewRecordID: "rwc-review-a17forged1", grantID: "rwc-grant-a17forged1",
            grantRevision: 1, evidenceDigest: A17.shaHex("bytes-nobody-reviewed"),
            decision: "APPROVED", reviewDate: A17.d("2026-08-15"))
        let token = try RWCRightsReviewAuthorityV1.verify(grant: forgedGrant, reviewRecord: forgedReview)
        XCTAssertEqual(token.grant.grantID, "rwc-grant-a17forged1",
                       "A17-F1: caller-forged APPROVED review minted a verified-grant token")
        // the forged token registers an asset in the rights store (legal gate fully bypassed)
        let dir = A17.tempDir("f1")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        defer { store.closeStore() }
        XCTAssertNoThrow(try store.register(A17.record(g: forgedGrant), verifiedGrant: token,
                                            clock: A17.clock("2026-10-01")),
                         "A17-F1: forged approval reaches durable rights registration")
        // reviewDate is completely unconstrained: a review 'performed' centuries before the grant
        // window is accepted (no temporal relation is enforced anywhere).
        let g2 = A17.grant(id: "rwc-grant-a17forged2", digestSeed: "b2", review: "rwc-review-a17f2")
        let ancient = RWCRightsReviewRecordV1(reviewRecordID: "rwc-review-a17f2",
                                              grantID: g2.grantID, grantRevision: 1,
                                              evidenceDigest: g2.evidenceDigest,
                                              decision: "APPROVED", reviewDate: A17.d("1500-01-01"))
        XCTAssertNoThrow(try RWCRightsReviewAuthorityV1.verify(grant: g2, reviewRecord: ancient),
                         "A17-F1: reviewDate 1500-01-01 accepted — no temporal review law")
    }

    func test_A17_07_ReviewAuthority_NoProvenanceFieldExists() throws {
        // §7/§39: census — the review record TYPE has no reviewer identity/role/authorization field.
        let g = A17.grant()
        let labels = Mirror(reflecting: A17.approvedReview(g)).children.compactMap(\.label).sorted()
        XCTAssertEqual(labels, ["decision", "evidenceDigest", "grantID", "grantRevision",
                                "reviewDate", "reviewRecordID"],
                       "no reviewer-identity/provenance field exists on the review record")
        // no reviewer registry / review-ledger symbol exists anywhere in the canonical rights source
        let src = try read("packages/GuardianKit/Sources/GuardianCore/RWCRightsV3.swift")
        for absent in ["ReviewerRegistry", "reviewerID", "authorizedReviewer", "reviewLedger"] {
            XCTAssertFalse(src.contains(absent), absent)
        }
        // non-APPROVED and mismatching records refuse (the matching law itself works)
        expectRights(.reviewNotApproved) {
            _ = try RWCRightsReviewAuthorityV1.verify(
                grant: g, reviewRecord: RWCRightsReviewRecordV1(
                    reviewRecordID: g.reviewRecordID, grantID: g.grantID, grantRevision: 1,
                    evidenceDigest: g.evidenceDigest, decision: "PENDING",
                    reviewDate: A17.d("2026-08-15")))
        }
        expectRights(.reviewRecordMismatch(reason: "evidenceDigest")) {
            _ = try RWCRightsReviewAuthorityV1.verify(
                grant: g, reviewRecord: RWCRightsReviewRecordV1(
                    reviewRecordID: g.reviewRecordID, grantID: g.grantID, grantRevision: 1,
                    evidenceDigest: A17.shaHex("other-bytes"), decision: "APPROVED",
                    reviewDate: A17.d("2026-08-15")))
        }
    }

    // MARK: §8 legal grant semantics

    func test_A17_08_GrantSemantics_Relicense_UseScopes() throws {
        let dir = A17.tempDir("f8")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        defer { store.closeStore() }
        let g1 = A17.grant()
        try store.register(A17.record(g: g1), verifiedGrant: A17.mint(g1), clock: A17.clock("2026-10-01"))
        try store.revoke(assetID: "rwc-asset-a17asset01", clock: A17.clock("2026-10-05"))
        // same grant + new bytes (reserialized proof => new digest/pointer/review): refused forever
        let reser = A17.grant(digestSeed: "a17-proof-1-reserialized",
                              pointer: "rwc-rights-ref-a17p0002", review: "rwc-review-a17r0002")
        expectRights(.grantAlreadyUsed) {
            try store.reauthorize(A17.record(g: reser, acquisition: "2026-10-06"),
                                  verifiedGrant: try A17.mint(reser), clock: A17.clock("2026-10-07"))
        }
        // same bytes + new grant: refused (digest already consumed)
        let oldBytes = A17.grant(id: "rwc-grant-a17g0002", digestSeed: "a17-proof-1",
                                 review: "rwc-review-a17r0003")
        expectRights(.evidenceAlreadyUsed) {
            try store.reauthorize(A17.record(g: oldBytes, acquisition: "2026-10-06"),
                                  verifiedGrant: try A17.mint(oldBytes), clock: A17.clock("2026-10-07"))
        }
        // new pointer alone changes nothing (same identity refused): covered by reser above.
        // lawful regrant: new identity + new approved review + new bytes
        let lawful = A17.grant(id: "rwc-grant-a17g0003", digestSeed: "a17-proof-2",
                               review: "rwc-review-a17r0004")
        XCTAssertNoThrow(try store.reauthorize(A17.record(g: lawful, acquisition: "2026-10-06"),
                                               verifiedGrant: try A17.mint(lawful),
                                               clock: A17.clock("2026-10-07")))
        // revoked/expired/training-only/evaluation-only eligibility semantics
        try store.revoke(assetID: "rwc-asset-a17asset01", clock: A17.clock("2026-10-08"))
        expectRights(.revoked) {
            try store.requireEligible(assetID: "rwc-asset-a17asset01", use: .training,
                                      clock: A17.clock("2026-10-09"))
        }
        let trainOnly = A17.grant(id: "rwc-grant-a17g0005", digestSeed: "a17-proof-3",
                                  allowed: ["training"], review: "rwc-review-a17r0005")
        try store.register(A17.record(asset: "rwc-asset-a17asset02", g: trainOnly),
                           verifiedGrant: A17.mint(trainOnly), clock: A17.clock("2026-10-10"))
        XCTAssertNoThrow(try store.requireEligible(assetID: "rwc-asset-a17asset02", use: .training,
                                                   clock: A17.clock("2026-10-11")))
        expectRights(.useNotAllowed(use: "evaluation")) {
            try store.requireEligible(assetID: "rwc-asset-a17asset02", use: .evaluation,
                                      clock: A17.clock("2026-10-11"))
        }
        let shortLived = A17.grant(id: "rwc-grant-a17g0006", digestSeed: "a17-proof-4",
                                   expiry: "2026-10-20", review: "rwc-review-a17r0006")
        try store.register(A17.record(asset: "rwc-asset-a17asset03", g: shortLived,
                                      acquisition: "2026-10-01"),
                           verifiedGrant: A17.mint(shortLived), clock: A17.clock("2026-10-12"))
        expectRights(.expired) {
            try store.requireEligible(assetID: "rwc-asset-a17asset03", use: .training,
                                      clock: A17.clock("2026-11-01"))
        }
        // expired grant cannot register at all
        expectRights(.expiredAtRegistration) {
            let dead = A17.grant(id: "rwc-grant-a17g0007", digestSeed: "a17-proof-5",
                                 expiry: "2026-10-20", review: "rwc-review-a17r0007")
            try store.register(A17.record(asset: "rwc-asset-a17asset04", g: dead,
                                          acquisition: "2026-10-15"),
                               verifiedGrant: try A17.mint(dead), clock: A17.clock("2026-11-02"))
        }
    }

    // MARK: §10/§11 durable restart + independent replay

    func test_A17_09_Restart_IndependentJournalReplay_FieldForField() throws {
        let dir = A17.tempDir("f9")
        defer { try? FileManager.default.removeItem(at: dir) }
        let g1 = A17.grant()
        let lawful = A17.grant(id: "rwc-grant-a17g0003", digestSeed: "a17-proof-2",
                               review: "rwc-review-a17r0004")
        var liveHead = ""
        var liveCount = 0
        do {
            let a = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
            try a.register(A17.record(g: g1), verifiedGrant: A17.mint(g1), clock: A17.clock("2026-10-01"))
            try a.revoke(assetID: "rwc-asset-a17asset01", clock: A17.clock("2026-10-05"))
            try a.reauthorize(A17.record(g: lawful, acquisition: "2026-10-06"),
                              verifiedGrant: A17.mint(lawful), clock: A17.clock("2026-10-07"))
            liveHead = a.headDigest
            liveCount = a.eventCount
            a.closeStore()
        }
        // INDEPENDENT reconstruction: parse the journal with our own code (not builder replay)
        let journalURL = dir.appendingPathComponent(RWCAssetRightsLedgerStoreV3.journalName)
        let lines = try String(contentsOf: journalURL, encoding: .utf8)
            .split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 3)
        var myHead = RWCRightsEventV3.genesisDigest
        var kinds: [String] = []
        var lastPayload: [String: Any] = [:]
        for (i, line) in lines.enumerated() {
            let o = try JSONSerialization.jsonObject(with: Data(line.utf8)) as! [String: Any]
            XCTAssertEqual(o["seq"] as? Int, i)
            XCTAssertEqual(o["prev"] as? String, myHead)
            myHead = o["digest"] as! String
            kinds.append(o["kind"] as! String)
            if let p = o["payload"] as? String, !p.isEmpty {
                lastPayload = try JSONSerialization.jsonObject(with: Data(p.utf8)) as! [String: Any]
            }
        }
        XCTAssertEqual(kinds, ["registered", "revoked", "reauthorized"])
        XCTAssertEqual(myHead, liveHead, "independent chain head == live head")
        // reopen and compare field-for-field against BOTH the live state and my replay
        let b = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        defer { b.closeStore() }
        XCTAssertEqual(b.eventCount, liveCount)
        XCTAssertEqual(b.headDigest, liveHead)
        XCTAssertFalse(b.isTombstoned("rwc-asset-a17asset01"), "reauthorized ⇒ active")
        let rec = b.record(for: "rwc-asset-a17asset01")
        XCTAssertEqual(rec?.grant.grantID, lastPayload["grantID"] as? String)
        XCTAssertEqual(rec?.grant.evidenceDigest, lastPayload["evd"] as? String)
        XCTAssertEqual(rec?.owner, lastPayload["owner"] as? String)
        XCTAssertEqual(rec?.contentHash, lastPayload["hash"] as? String)
        XCTAssertEqual(rec?.acquisitionDate.isoString, lastPayload["acq"] as? String)
        XCTAssertEqual(rec?.grant.allowedUse, lastPayload["allowed"] as? [String])
        // seen identities + revocation chronology survive the restart
        try b.revoke(assetID: "rwc-asset-a17asset01", clock: A17.clock("2026-10-08"))
        expectRights(.grantAlreadyUsed) {
            let again = A17.grant(digestSeed: "a17-proof-9", review: "rwc-review-a17r0009")
            try b.reauthorize(A17.record(g: again, acquisition: "2026-10-09"),
                              verifiedGrant: try A17.mint(again), clock: A17.clock("2026-10-10"))
        }
        expectRights(.evidenceAlreadyUsed) {
            let oldB = A17.grant(id: "rwc-grant-a17g0010", digestSeed: "a17-proof-2",
                                 review: "rwc-review-a17r0010")
            try b.reauthorize(A17.record(g: oldB, acquisition: "2026-10-09"),
                              verifiedGrant: try A17.mint(oldB), clock: A17.clock("2026-10-10"))
        }
        expectRights(.dateOrderViolation(rule: "reauthorized acquisitionDate >= revocationDate")) {
            let fresh = A17.grant(id: "rwc-grant-a17g0011", digestSeed: "a17-proof-11",
                                  review: "rwc-review-a17r0011")
            try b.reauthorize(A17.record(g: fresh, acquisition: "2026-10-02"),
                              verifiedGrant: try A17.mint(fresh), clock: A17.clock("2026-10-10"))
        }
        expectRights(.chronologyViolation(rule: "registration recordedDate >= previous event date")) {
            let g = A17.grant(id: "rwc-grant-a17g0012", digestSeed: "a17-proof-12",
                              review: "rwc-review-a17r0012")
            try b.register(A17.record(asset: "rwc-asset-a17asset05", g: g),
                           verifiedGrant: try A17.mint(g), clock: A17.clock("2026-09-01"))
        }
    }

    // MARK: §12/§14 head witness + crash states

    func test_A17_10_HeadWitness_CrashStateBattery() throws {
        let dir = A17.tempDir("f10")
        defer { try? FileManager.default.removeItem(at: dir) }
        let g1 = A17.grant()
        let a = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        try a.register(A17.record(g: g1), verifiedGrant: A17.mint(g1), clock: A17.clock("2026-10-01"))
        try a.revoke(assetID: "rwc-asset-a17asset01", clock: A17.clock("2026-10-05"))
        let lawful = A17.grant(id: "rwc-grant-a17g0003", digestSeed: "a17-proof-2",
                               review: "rwc-review-a17r0004")
        try a.reauthorize(A17.record(g: lawful, acquisition: "2026-10-06"),
                          verifiedGrant: A17.mint(lawful), clock: A17.clock("2026-10-07"))
        a.closeStore()
        let jURL = dir.appendingPathComponent(RWCAssetRightsLedgerStoreV3.journalName)
        let wURL = dir.appendingPathComponent(RWCAssetRightsLedgerStoreV3.witnessName)
        let journal = try String(contentsOf: jURL, encoding: .utf8)
        let witness = try String(contentsOf: wURL, encoding: .utf8)
        let lines = journal.split(separator: "\n").map(String.init)
        func digest(_ line: String) -> String {
            (try! JSONSerialization.jsonObject(with: Data(line.utf8)) as! [String: Any])["digest"] as! String
        }
        func setWitness(count: Int, head: String) throws {
            try "{\"v\":\"\(RWCAssetRightsLedgerStoreV3.version)\",\"count\":\(count),\"head\":\"\(head)\"}\n"
                .write(to: wURL, atomically: true, encoding: .utf8)
        }
        func restore() throws {
            try journal.write(to: jURL, atomically: true, encoding: .utf8)
            try witness.write(to: wURL, atomically: true, encoding: .utf8)
        }
        // journal truncation (witness 3, journal 2) → typed refusal
        try (lines[0] + "\n" + lines[1] + "\n").write(to: jURL, atomically: true, encoding: .utf8)
        expectLedger(.truncatedJournal(witnessCount: 3, journalCount: 2)) {
            _ = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        }
        try restore()
        // witness rollback by exactly one with CORRECT prefix head → deterministic roll-forward
        try setWitness(count: 2, head: digest(lines[1]))
        do {
            let rolled = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
            XCTAssertEqual(rolled.eventCount, 3)
            rolled.closeStore()
            let again = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
            XCTAssertEqual(again.eventCount, 3, "roll-forward is deterministic and settles")
            again.closeStore()
        }
        // witness behind by TWO → refusal (not a predeclared recoverable state)
        try setWitness(count: 1, head: digest(lines[0]))
        expectLedger(.witnessBehindBeyondOnePending(witnessCount: 1, journalCount: 3)) {
            _ = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        }
        try restore()
        // witness behind one with WRONG head → headMismatch (no blind roll-forward)
        try setWitness(count: 2, head: A17.shaHex("wrong"))
        expectLedger(.headMismatch) { _ = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir) }
        try restore()
        // partial/garbage tail after committed head → deterministic discard
        try (journal + "{\"v\":\"rwc-rights-event-v3\",\"seq\":3,\"prev\":\"gar")
            .write(to: jURL, atomically: true, encoding: .utf8)
        do {
            let repaired = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
            XCTAssertEqual(repaired.eventCount, 3)
            repaired.closeStore()
            XCTAssertEqual(try String(contentsOf: jURL, encoding: .utf8), journal,
                           "journal rewritten to exactly the committed prefix")
        }
        // modified last event (payload byte flipped) → eventDigestMismatch
        var tampered = lines
        tampered[2] = tampered[2].replacingOccurrences(of: "gen8-a17", with: "genX-a17")
        try (tampered.joined(separator: "\n") + "\n").write(to: jURL, atomically: true, encoding: .utf8)
        expectLedger(.eventDigestMismatch(line: 2)) {
            _ = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        }
        try restore()
        // modified witness count ahead of journal → truncatedJournal
        try setWitness(count: 5, head: digest(lines[2]))
        expectLedger(.truncatedJournal(witnessCount: 5, journalCount: 3)) {
            _ = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        }
        try restore()
        // modified witness digest at matching count → headMismatch
        try setWitness(count: 3, head: A17.shaHex("forged-head"))
        expectLedger(.headMismatch) { _ = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir) }
        try restore()
        // malformed witness → typed refusal; missing witness → typed refusal
        try "not json\n".write(to: wURL, atomically: true, encoding: .utf8)
        expectLedger(.witnessMalformed) { _ = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir) }
        try FileManager.default.removeItem(at: wURL)
        expectLedger(.witnessMissing) { _ = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir) }
    }

    // MARK: §13 single-writer — REAL cross-process flock

    func test_A17_11_DualProcess_Flock() throws {
        let dir = A17.tempDir("f11")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        let lockPath = dir.appendingPathComponent(RWCAssetRightsLedgerStoreV3.lockName).path
        let probe = "import fcntl,sys\nf=open(sys.argv[1],'a')\n" +
            "try:\n fcntl.flock(f.fileno(), fcntl.LOCK_EX|fcntl.LOCK_NB)\n print('ACQUIRED')\n" +
            "except Exception:\n print('BLOCKED')\n"
        // while the Swift store holds the lock, a SEPARATE OS PROCESS cannot take it
        XCTAssertEqual(try A17.run("python3", ["-c", probe, lockPath]).1, "BLOCKED",
                       "flock is a real OS lock visible across processes")
        // in-process second writer also refused
        expectLedger(.lockedByAnotherWriter) {
            _ = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        }
        store.closeStore()
        XCTAssertEqual(try A17.run("python3", ["-c", probe, lockPath]).1, "ACQUIRED")
        // a foreign process holding the lock blocks the Swift store (register/register impossible)
        let holder = Process()
        holder.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        let holdScript = "import fcntl,sys,time,os\nf=open(sys.argv[1],'a')\n" +
            "fcntl.flock(f.fileno(), fcntl.LOCK_EX|fcntl.LOCK_NB)\n" +
            "open(sys.argv[2],'w').write('held')\ntime.sleep(10)\n"
        let marker = dir.appendingPathComponent("held.marker").path
        holder.arguments = ["python3", "-c", holdScript, lockPath, marker]
        try holder.run()
        defer { holder.terminate() }
        var waited = 0.0
        while !FileManager.default.fileExists(atPath: marker), waited < 5.0 {
            Thread.sleep(forTimeInterval: 0.05); waited += 0.05
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker), "python holder started")
        expectLedger(.lockedByAnotherWriter) {
            _ = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        }
        holder.terminate()
        holder.waitUntilExit()
        let reopened = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        XCTAssertEqual(reopened.eventCount, 0)
        reopened.closeStore()
        // create-over-existing and open-missing stay typed
        expectLedger(.directoryExists) { _ = try RWCAssetRightsLedgerStoreV3.create(directory: dir) }
        expectLedger(.witnessMissing) {
            _ = try RWCAssetRightsLedgerStoreV3.openExisting(directory: A17.tempDir("missing"))
        }
    }

    // MARK: §15 seed framing — cross-language vectors (python hashlib independent implementation)

    func test_A17_12_SeedFraming_CrossLanguageVectors() throws {
        typealias M4 = RWCCalibrationMethodologyV4
        // values computed by docs/audit/audit17_tools/audit17_seed_slaw_manifest.py (Python 3.9)
        let vectors: [([String], UInt64)] = [
            (["a|b", "c"], 7_536_921_199_413_276_207),
            (["a", "b|c"], 3_136_611_556_425_352_344),
            (["ab", "c"], 1_712_244_635_539_802_493),
            (["a", "bc"], 15_889_655_143_833_197_139),
            ([], 5_952_767_197_798_734_789),
            ([""], 7_846_850_344_681_638_623),
            (["", ""], 12_570_984_145_599_017_423),
            (["", "a"], 489_013_509_949_218_239),
            (["a", ""], 940_220_433_216_354_405),
            (["\u{00e9}"], 7_153_533_919_819_791_205),          // NFC e-acute
            (["e\u{0301}"], 17_796_179_609_432_808_930),        // NFD e + combining acute
            (["x", "y"], 11_396_026_456_453_440_033),
            ([String(repeating: "L", count: 100_000)], 7_479_314_742_684_834_141),
            (["eval", "deadbeef", "risk_ECE", "primary"], 3_620_746_795_137_266_239),
        ]
        for (parts, expected) in vectors {
            XCTAssertEqual(M4.seed64(parts), expected,
                           "cross-language seed mismatch for \(parts.map { String($0.prefix(8)) })")
        }
        // framing law: no context collision across the alias battery
        XCTAssertNotEqual(M4.seed64(["a|b", "c"]), M4.seed64(["a", "b|c"]))
        XCTAssertNotEqual(M4.seed64(["ab", "c"]), M4.seed64(["a", "bc"]))
        XCTAssertNotEqual(M4.seed64(["", "a"]), M4.seed64(["a", ""]))
        XCTAssertNotEqual(M4.seed64([]), M4.seed64([""]))
        XCTAssertNotEqual(M4.seed64(["\u{00e9}"]), M4.seed64(["e\u{0301}"]))
    }

    // MARK: §16/§17 evaluation seed manifest

    func test_A17_13_EvalSeedManifest_Census_DatasetBindingStatus() throws {
        typealias M4 = RWCCalibrationMethodologyV4
        let m = M4.RWCEvaluationSeedManifestV1(
            datasetID: "a17-ds", sealedAssetIDsDigest: A17.shaHex("ids"), splitID: "a17-split",
            datasetVersion: "v1", modelArtifactID: "a17-model", methodologyVersion: M4.version,
            evaluationRunID: "a17-run")
        let labels = Mirror(reflecting: m).children.compactMap(\.label).sorted()
        XCTAssertEqual(labels, ["datasetID", "datasetVersion", "evaluationRunID",
                                "methodologyVersion", "modelArtifactID", "sealedAssetIDsDigest",
                                "splitID"],
                       "exactly 7 identity fields; no label/prediction/outcome field exists")
        XCTAssertFalse(M4.RWCEvaluationSeedManifestV1.self is Decodable.Type)
        let s1 = M4.evaluationSeed(manifest: m, metricID: "risk_ECE", purpose: "primary")
        XCTAssertEqual(s1, M4.evaluationSeed(manifest: m, metricID: "risk_ECE", purpose: "primary"))
        XCTAssertNotEqual(s1, M4.evaluationSeed(manifest: m, metricID: "risk_ECE", purpose: "null"))
        let schema = try read("docs/calibration/preregistration/RWC_EVALUATION_SEED_MANIFEST_SCHEMA_V1.yaml")
        XCTAssertTrue(schema.contains("outcome-independent"))
        // §17 HONESTY: no STRUCTURAL binding of sealedAssetIDsDigest to the dataset actually
        // evaluated exists yet (future RWC-FIT invariant). Do not overclaim closure.
        XCTAssertFalse(schema.contains("structural dataset binding enforced"),
                       "binding enforcement is a future invariant — recorded, not claimed")
    }

    // MARK: §18 analytical S law

    func test_A17_14_AnalyticalSLaw_Independent() throws {
        typealias M4 = RWCCalibrationMethodologyV4
        func se(_ s: Int) -> Double { (0.05 * 0.95 / Double(s)).squareRoot() }
        XCTAssertEqual(M4.frozenNullSims, 9999)
        XCTAssertEqual((M4.frozenNullSims + 1) % 20, 0)
        XCTAssertGreaterThan(se(999), 0.0025, "S=999 fails alpha/20")
        XCTAssertLessThanOrEqual(se(9999), 0.0025, "S=9999 passes alpha/20")
        XCTAssertEqual(se(999), M4.analyticalSE(alpha: 0.05, sims: 999), accuracy: 1e-12)
        // uniqueness on the frozen 10^k grid: smallest passing candidate is exactly 9999
        var smallest: Int? = nil
        for k in 2...6 {
            let s = Int(pow(10.0, Double(k))) - 1
            if (s + 1) % 20 == 0, se(s) <= 0.0025, smallest == nil { smallest = s }
        }
        XCTAssertEqual(smallest, 9999, "no hidden data-dependent selection is possible")
    }

    // MARK: §19 Type-I smoke (independent engine; heavy replication in the env-gated runner)

    func test_A17_15_TypeI_Smoke_IndependentEngine() throws {
        var results: [String: (Int, Int)] = [:]
        for shape in ["uniform", "clustered"] {
            var rejects = 0, mcRejects = 0
            let trials = 150
            for t in 0..<trials {
                let (p, y) = A17Stat.dataset(shape: shape, alt: "null", n: 400,
                                             seedParts: ["smoke", shape, String(t), "data"])
                let dec = A17Stat.decide(preds: p, labels: y, sims: 399,
                                         seedParts: ["smoke", shape, String(t), "eval"])
                if dec.combinedReject { rejects += 1 }
                if dec.mcReject { mcRejects += 1 }
            }
            results[shape] = (rejects, mcRejects)
            let ci = A17Stat.wilson(rejects, trials)
            XCTAssertLessThanOrEqual(ci.0, 0.05, "\(shape): Wilson CI must cover <=5% null rate")
            XCTAssertLessThanOrEqual(Double(rejects) / Double(trials), 0.13,
                                     "\(shape): null rejection far above alpha")
        }
        XCTAssertFalse(results.isEmpty)
    }

    // MARK: §22 tie / input regression on the V4 decision surface

    func test_A17_16_TieInput_Regression_V4() throws {
        typealias M4 = RWCCalibrationMethodologyV4
        let good: [Double] = (0..<40).map { Double($0 % 20) / 20.0 }
        let labels: [Bool] = (0..<40).map { $0 % 3 == 0 }
        XCTAssertThrowsError(try M4.decideV4(preds: good + [.nan], labels: labels + [true],
                                             sims: 199, seedParts: ["a17"]))
        XCTAssertThrowsError(try M4.decideV4(preds: good + [.infinity], labels: labels + [true],
                                             sims: 199, seedParts: ["a17"]))
        XCTAssertThrowsError(try M4.decideV4(preds: good + [-0.001], labels: labels + [true],
                                             sims: 199, seedParts: ["a17"]))
        XCTAssertThrowsError(try M4.decideV4(preds: good + [1.001], labels: labels + [true],
                                             sims: 199, seedParts: ["a17"]))
        XCTAssertThrowsError(try M4.decideV4(preds: good, labels: labels, bins: 0,
                                             sims: 199, seedParts: ["a17"]))
        XCTAssertThrowsError(try M4.decideV4(preds: good, labels: labels, sims: 1000,
                                             seedParts: ["a17"])) { e in
            XCTAssertEqual(e as? RWCCalibrationInputErrorV1, .invalidSimulationCount(1000))
        }
        // ties atomic + permutation invariance (identical decision for any input order)
        let base = try M4.decideV4(preds: good, labels: labels, sims: 199, seedParts: ["a17", "tie"])
        let shuffledIdx = Array(good.indices.reversed())
        let p2 = shuffledIdx.map { good[$0] }
        let y2 = shuffledIdx.map { labels[$0] }
        let perm = try M4.decideV4(preds: p2, labels: y2, sims: 199, seedParts: ["a17", "tie"])
        XCTAssertEqual(base, perm, "permutation invariance under the frozen seed")
        // quantized/tied predictions deterministic across repeats
        let q = try M4.decideV4(preds: good, labels: labels, sims: 199, seedParts: ["a17", "q"])
        let q2 = try M4.decideV4(preds: good, labels: labels, sims: 199, seedParts: ["a17", "q"])
        XCTAssertEqual(q, q2)
    }

    // MARK: §23 IRR census

    func test_A17_17_IRR_Exact060_Census() throws {
        typealias M4 = RWCCalibrationMethodologyV4
        XCTAssertEqual(M4.irrOrdinalKappaThreshold, 0.60)
        XCTAssertEqual(M4.irrMinValidPairs, 50)
        XCTAssertEqual(M4.irrPlannedTargetPairs, 300)
        let gates = try read("docs/calibration/preregistration/RWC_FROZEN_GATES_V4.yaml")
        let obj = try JSONSerialization.jsonObject(with: Data(gates.utf8)) as! [String: Any]
        let irr = ((obj["metric_gates"] as! [String: Any])["IRR_ordinal"] as! [String: Any])
        let gate = irr["gate"] as! String
        XCTAssertTrue(gate.contains(">= 0.60"), "active gate threshold is 0.60")
        XCTAssertFalse(gate.contains("0.61"), "no active 0.61 semantics")
        // 0.61 appears ONLY as recorded negative evidence (drift history), never as a gate
        let restoration = irr["threshold_restoration_law"] as! String
        XCTAssertTrue(restoration.contains("UNDISCLOSED DRIFT"))
        let v4src = try read("packages/GuardianKit/Tests/GuardianCoreTests/RWCCalibrationMethodologyV4.swift")
        XCTAssertTrue(v4src.contains("irrOrdinalKappaThreshold = 0.60"))
        XCTAssertFalse(v4src.contains("= 0.61"), "no active 0.61 constant in canonical V4 code")
        let planning = try read("docs/calibration/preregistration/RWC_IRR_PLANNING_V4.md")
        XCTAssertTrue(planning.contains(">= 0.60"))
    }

    // MARK: §46 AUDIT17 FINDING A17-F10 — grant scope / source binding model absent

    func test_A17_19_FINDING_A17F10_GrantScope_SourceBinding_Absent() throws {
        // AUDIT17 FINDING A17-F10: pins defective behavior.
        // Nothing binds a verified grant to a SOURCE or to an ASSET POPULATION: the review record
        // carries no source scope (field census in test_A17_07), and grant-consumption bookkeeping
        // (seenGrantIDs/seenEvidenceDigests) is keyed PER ASSET. One caller-authored APPROVED
        // grant therefore registers unlimited DISTINCT assets from unrelated sourceReferences.
        let dir = A17.tempDir("f10x")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        defer { store.closeStore() }
        let g = A17.grant()
        let token = try A17.mint(g)
        try store.register(A17.record(asset: "rwc-asset-a17srcone1", g: g,
                                      sourceRef: "rwc-source-ref-a17alpha1",
                                      contentHash: A17.shaHex("payload-one"),
                                      provenance: ["rwc-source-ref-a17alpha1"]),
                           verifiedGrant: token, clock: A17.clock("2026-10-01"))
        XCTAssertNoThrow(try store.register(A17.record(asset: "rwc-asset-a17srctwo2", g: g,
                                                       sourceRef: "rwc-source-ref-a17beta02",
                                                       contentHash: A17.shaHex("payload-two"),
                                                       provenance: ["rwc-source-ref-a17beta02"]),
                                            verifiedGrant: token, clock: A17.clock("2026-10-02")),
                         "A17-F10: the SAME verified grant registered a second, unrelated source")
        XCTAssertNoThrow(try store.register(A17.record(asset: "rwc-asset-a17srcthr3", g: g,
                                                       sourceRef: "rwc-source-ref-a17gamma3",
                                                       contentHash: A17.shaHex("payload-three"),
                                                       provenance: ["rwc-source-ref-a17gamma3"]),
                                            verifiedGrant: token, clock: A17.clock("2026-10-03")),
                         "A17-F10: unlimited cross-asset reuse — no grant scope model exists")
        // the grant's only locator (evidencePointer) is never related to record.sourceReference
        XCTAssertNotEqual(g.evidencePointer, "rwc-source-ref-a17alpha1")
    }

    // MARK: §42 content-hash first-asset coherence (A17-F8 evidence census)

    func test_A17_18_ContentHash_FirstAsset_CoherenceGap() throws {
        // AUDIT17 FINDING A17-F8: pins the documentation state. The runner REQUIRES
        // record.contentHash BEFORE fetch (stage 6 compares actual vs declared), but no frozen law
        // declares a lawful PROVENANCE for that expected hash (trusted source checksum /
        // rights-holder manifest / project-owned preknown hash). Without it, the first real asset
        // either cannot be constructed or invites a secret pre-download — circular with the
        // no-pre-auth law.
        let law = try read("docs/calibration/preregistration/RWC_ACQUISITION_TRANSACTION_LAW_V1.md")
        XCTAssertTrue(law.contains("must equal the declared `record.contentHash`"))
        for absent in ["checksum", "source-supplied", "rights-holder manifest", "preknown",
                       "hash provenance"] {
            XCTAssertFalse(law.contains(absent),
                           "A17-F8: no declared provenance mechanism for the expected content hash (\(absent))")
        }
        let rights = try read("docs/calibration/preregistration/RWC_RIGHTS_LAW_V3.md")
        XCTAssertFalse(rights.contains("content hash provenance"))
    }
}

/// Internal name indirection so part-1 compiles without importing RWCAcquisition (macOS-only).
enum RWCCorpusEntryVerifierV3Names {
    static let governingTag = "gen8-ulu-evren-control-plane-r1-locked-governing"
}
