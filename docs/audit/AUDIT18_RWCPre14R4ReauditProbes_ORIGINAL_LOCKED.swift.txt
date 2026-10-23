import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
#if os(macOS)
import RWCAcquisition
#endif

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT18_RWC_PRE14_R4_REAUDIT — part 1 of 4: independent clean-session custody / AUDIT17
// discipline / zero-data / durable-rights + calibration regression probes.
// Probes pinning defective behavior are marked "AUDIT18 FINDING <id>: pins defective behavior".
// Synthetic fixtures only; the real tracked tree is never modified. No real reviewer, grant,
// media, annotation, fit or held-out data exists or is created here.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

#if os(macOS)

enum A18 {
    static let candidate = "206783074e2167afa0689aa7873a917076089749"
    static let tagName = "gen8-rwc-preregistration-r4-audit-candidate"
    static let tagObject = "30aa63e3f9dcdd920aa66cf77050c4b61ebda0d3"
    static let anchor = "f9c10ff0f105aa52b4b7cde78e5629d21f7270a6"
    static let governing = "2c345b64c720f965b68ec5ee699e1b71fecf0003"
    static let inventoryDigest = "80ff22e3affc553ad1bfb2dc58a570cbbd0c8dc3fbe01bfc005519714ec7a51c"
    static let freezeBlobSHA = "d776b080b26d08b50262d1442f2bf04ef361a85d6fffcaa0de3a61d12b5498e6"
    static let freezePath = "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V5.yaml"
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
        try run("git", ["-C", root.path, "-c", "user.name=audit18", "-c", "user.email=audit18@local"] + args)
    }

    /// Raw (untrimmed) blob bytes via `git show` — exact byte identity for hashing.
    static func gitShowRaw(_ root: URL, _ spec: String) throws -> (Int32, Data) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git", "-C", root.path, "show", spec]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, data)
    }

    static func tempDir(_ tag: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("a18-\(tag)-\(UUID().uuidString.prefix(8))")
    }

    static func write(_ root: URL, _ rel: String, _ content: String) throws {
        let url = root.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: independent auditor factories (no builder helpers reused)

    static func d(_ iso: String) -> RWCDateV3 { try! RWCDateV3.parse(iso, field: "a18") }
    static func clock(_ iso: String) -> RWCFixedClockV3 { try! RWCFixedClockV3(iso) }

    static func grant(id: String = "rwc-grant-a18g0001", rev: Int = 1,
                      digestSeed: String = "a18-proof-1",
                      pointer: String = "rwc-rights-ref-a18p0001",
                      holder: String = "licensor-a18",
                      allowed: [String] = ["training", "evaluation"], prohibited: [String] = [],
                      effective: String = "2026-08-01", expiry: String? = "2027-08-01",
                      review: String = "rwc-review-a18r0001") -> RWCLegalGrantIdentityV1 {
        RWCLegalGrantIdentityV1(grantID: id, grantRevision: rev, evidenceDigest: shaHex(digestSeed),
                                evidencePointer: pointer, rightsHolder: holder, allowedUse: allowed,
                                prohibitedUse: prohibited, effectiveDate: d(effective),
                                expiryDate: expiry.map { d($0) }, reviewDecision: "APPROVED",
                                reviewRecordID: review)
    }

    static func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }

    /// Synthetic in-memory Ed25519 key — explicitly a FIXTURE; never a real reviewer credential.
    static func reviewer(id: String = "rwc-reviewer-a18rev01",
                         key: Curve25519.Signing.PrivateKey,
                         status: RWCAuthorizedReviewerV1.Status = .active,
                         role: String = "RIGHTS_REVIEW", scope: String = "rwc-corpus",
                         validFrom: String = "2026-01-01",
                         validUntil: String? = "2027-12-31",
                         pubHexOverride: String? = nil) -> RWCAuthorizedReviewerV1 {
        RWCAuthorizedReviewerV1(reviewerID: id,
                                publicKeyRawHex: pubHexOverride ?? hex(key.publicKey.rawRepresentation),
                                status: status, role: role, scope: scope,
                                validFrom: d(validFrom), validUntil: validUntil.map { d($0) })
    }

    static func registry(_ reviewers: [RWCAuthorizedReviewerV1]) -> RWCAuthorizedReviewerRegistryV1 {
        var reg = RWCAuthorizedReviewerRegistryV1()
        for r in reviewers { reg.enroll(r) }
        return reg
    }

    /// Sign a canonical review payload; mutations applied AFTER signing keep the old signature.
    static func signedReview(for g: RWCLegalGrantIdentityV1,
                             source: RWCSourceAuthorizationV1,
                             reviewerID: String = "rwc-reviewer-a18rev01",
                             decision: String = "APPROVED",
                             reviewDate: String = "2026-08-15",
                             key: Curve25519.Signing.PrivateKey) throws -> RWCSignedRightsReviewV1 {
        let unsigned = RWCSignedRightsReviewV1(
            reviewRecordID: g.reviewRecordID, reviewerID: reviewerID, grantID: g.grantID,
            grantRevision: g.grantRevision, evidenceDigest: g.evidenceDigest,
            rightsHolder: g.rightsHolder, sourceAuthorization: source,
            allowedUse: g.allowedUse, prohibitedUse: g.prohibitedUse,
            effectiveDate: g.effectiveDate, expiryDate: g.expiryDate,
            decision: decision, reviewDate: d(reviewDate), signatureHex: "")
        let sig = try key.signature(for: unsigned.canonicalPayloadBytes)
        return RWCSignedRightsReviewV1(
            reviewRecordID: unsigned.reviewRecordID, reviewerID: unsigned.reviewerID,
            grantID: unsigned.grantID, grantRevision: unsigned.grantRevision,
            evidenceDigest: unsigned.evidenceDigest, rightsHolder: unsigned.rightsHolder,
            sourceAuthorization: unsigned.sourceAuthorization, allowedUse: unsigned.allowedUse,
            prohibitedUse: unsigned.prohibitedUse, effectiveDate: unsigned.effectiveDate,
            expiryDate: unsigned.expiryDate, decision: unsigned.decision,
            reviewDate: unsigned.reviewDate, signatureHex: hex(sig))
    }

    static func request(assetID: String = "rwc-asset-a18asset01",
                        sourceClass: RWCSourceClassV1 = .licensedRightsClear,
                        source: String = "rwc-source-ref-a18s0001",
                        owner: String = "gen8-a18", use: RWCUseV1 = .training,
                        session: String = "rwc-acq-a18session000001",
                        manifestSources: [String]? = nil,
                        checksum: String? = nil) -> RWCAcquisitionRequestV1 {
        RWCAcquisitionRequestV1(assetID: assetID, sourceClass: sourceClass, sourceReference: source,
                                owner: owner, intendedUse: use, sessionID: session,
                                manifestSources: manifestSources, trustedExpectedChecksum: checksum)
    }

    static let exactSource = RWCSourceAuthorizationV1.exactSource("rwc-source-ref-a18s0001")

    /// V1-token ABI mint (the SUPERSEDED public surface — used only where the probe is explicitly
    /// exercising the V1 bridge or constructing durable-store fixtures).
    static func mintV1(_ g: RWCLegalGrantIdentityV1,
                       reviewDate: String = "2026-08-15") throws -> RWCVerifiedRightsGrantV1 {
        try RWCRightsReviewAuthorityV1.verify(
            grant: g,
            reviewRecord: RWCRightsReviewRecordV1(
                reviewRecordID: g.reviewRecordID, grantID: g.grantID, grantRevision: g.grantRevision,
                evidenceDigest: g.evidenceDigest, decision: "APPROVED", reviewDate: d(reviewDate)))
    }

    static func record(asset: String = "rwc-asset-a18asset01", g: RWCLegalGrantIdentityV1? = nil,
                       sourceClass: RWCSourceClassV1 = .licensedRightsClear,
                       sourceRef: String = "rwc-source-ref-a18s0001", owner: String = "gen8-a18",
                       acquisition: String = "2026-09-01", contentHash: String? = nil,
                       provenance: [String]? = nil) -> RWCAssetRightsRecordV3 {
        RWCAssetRightsRecordV3(assetID: asset, sourceClass: sourceClass, sourceReference: sourceRef,
                               owner: owner, grant: g ?? grant(), acquisitionDate: d(acquisition),
                               contentHash: contentHash ?? shaHex("a18-content-1"),
                               provenanceChain: provenance ?? [sourceRef])
    }
}

final class AUDIT18_RWCPre14R4ReauditProbes: XCTestCase {

    // MARK: §0 custody — candidate / tag / anchor / governing / freeze blob binding

    func test_A18_01_Custody_Tag_Anchor_Governing_FreezeBlob() throws {
        let root = A18.repoRoot()
        // candidate commit exists as a commit object
        let cand = try A18.git(root, ["rev-parse", "--verify", "--quiet", A18.candidate + "^{commit}"])
        XCTAssertEqual(cand.0, 0)
        XCTAssertEqual(cand.1, A18.candidate)
        // annotated tag object + dereference laws
        let tagObj = try A18.git(root, ["rev-parse", "refs/tags/" + A18.tagName])
        XCTAssertEqual(tagObj.1, A18.tagObject, "annotated tag object identity")
        let tagType = try A18.git(root, ["cat-file", "-t", A18.tagName])
        XCTAssertEqual(tagType.1, "tag", "tag must be annotated (tag object, not lightweight)")
        let deref = try A18.git(root, ["rev-parse", A18.tagName + "^{commit}"])
        XCTAssertEqual(deref.1, A18.candidate, "tag dereferences to the R4 candidate")
        // methodology anchor is an ancestor of the candidate
        let anc = try A18.git(root, ["merge-base", "--is-ancestor", A18.anchor, A18.candidate])
        XCTAssertEqual(anc.0, 0, "anchor ancestry")
        // governing control-plane tag dereferences to the frozen governing commit
        let gov = try A18.git(root, ["rev-parse",
                                     RWCCorpusEntryVerifierV4.governingTagName + "^{commit}"])
        XCTAssertEqual(gov.1, A18.governing, "governing lock identity")
        // the CANDIDATE COMMIT's freeze V5 blob (immutable git truth; raw bytes)
        let blob = try A18.gitShowRaw(root, "\(A18.candidate):\(A18.freezePath)")
        XCTAssertEqual(blob.0, 0)
        XCTAssertEqual(A18.sha256Hex(blob.1), A18.freezeBlobSHA,
                       "candidate freeze V5 blob SHA-256")
        // live freeze manifest equals the candidate blob at audit time
        let live = try Data(contentsOf: root.appendingPathComponent(A18.freezePath))
        XCTAssertEqual(A18.sha256Hex(live), A18.freezeBlobSHA, "live freeze == candidate blob")
    }

    // MARK: §2 AUDIT17 immutability + lawful predeclared R3 supersession

    func test_A18_02_AUDIT17_Immutability_R3Result_PredeclaredSupersession() throws {
        let root = A18.repoRoot()
        func sha(_ rel: String) throws -> String {
            A18.sha256Hex(try Data(contentsOf: root.appendingPathComponent(rel)))
        }
        let frozen: [(String, String)] = [
            ("docs/audit/AUDIT17_RWCPre14R3ReauditProbes_ORIGINAL_LOCKED.swift.txt",
             "b423adcd1146ffa9bf685d9f016a7e003c1d2b30318f19e9d15aff6ea0301bef"),
            ("packages/GuardianKit/Tests/GuardianCoreTests/AUDIT17_RWCPre14R3ReauditProbes.swift",
             "b423adcd1146ffa9bf685d9f016a7e003c1d2b30318f19e9d15aff6ea0301bef"),
            ("docs/audit/AUDIT17_VerifierAuthorityProbes_ORIGINAL_LOCKED.swift.txt",
             "901e1f762f81700cd8bd0d630b613ed1d8074e3cde2a667f1229c80493a432c1"),
            ("packages/GuardianKit/Tests/GuardianCoreTests/AUDIT17_VerifierAuthorityProbes.swift",
             "901e1f762f81700cd8bd0d630b613ed1d8074e3cde2a667f1229c80493a432c1"),
            ("docs/audit/AUDIT17_AcquisitionRunnerProbes_ORIGINAL_LOCKED.swift.txt",
             "cc06649629dac53e2edd7cb7c2c810d4c936830c44b737f1777649a21511bb1a"),
            ("packages/GuardianKit/Tests/GuardianCoreTests/AUDIT17_AcquisitionRunnerProbes.swift",
             "cc06649629dac53e2edd7cb7c2c810d4c936830c44b737f1777649a21511bb1a"),
            ("docs/audit/RWC_PRE14_R3_AUDIT_RESULT.json",
             "2ebd7f8f608946701197df772f3454bffeb934157c3d46e484fffaef2b821061"),
            ("docs/audit/RWC_PRE14_R3_AUDIT_RESULT_ORIGINAL_LOCKED.json",
             "2ebd7f8f608946701197df772f3454bffeb934157c3d46e484fffaef2b821061"),
            ("docs/audit/GEN8_RWC_PREREGISTRATION_PRE14_R3_INDEPENDENT_REAUDIT.md",
             "7debbfc53ee40696642c68cd96f76b177cc5bfbced7c61df2ac543aced64829a"),
        ]
        for (rel, expected) in frozen {
            XCTAssertEqual(try sha(rel), expected, "AUDIT17 evidence immutability: \(rel)")
        }
        // the R3 machine result REMAINS FIX_REQUIRED 0/5/5 — never rewritten to PASS
        let r3 = try JSONSerialization.jsonObject(with: Data(contentsOf:
            root.appendingPathComponent("docs/audit/RWC_PRE14_R3_AUDIT_RESULT.json"))) as! [String: Any]
        XCTAssertEqual(r3["verdict"] as? String, "FIX_REQUIRED")
        XCTAssertEqual(r3["critical_count"] as? Int, 0)
        XCTAssertEqual(r3["high_count"] as? Int, 5)
        XCTAssertEqual(r3["medium_count"] as? Int, 5)
        // EXACTLY ONE builder-file supersession, declared BEFORE the inverting commit
        let lock = try String(contentsOf: root.appendingPathComponent(
            "docs/audit/AUDIT17_R4_INVERSION_LOCK.md"), encoding: .utf8)
        XCTAssertTrue(lock.contains("ZERO AUDIT17 INVERSIONS DECLARED"))
        XCTAssertTrue(lock.contains("EXACTLY ONE HISTORICAL BUILDER-FILE SUPERSESSION"))
        XCTAssertTrue(lock.contains("RWCPreregistrationR3Tests.swift"))
        // declaration commit precedes-or-equals the superseding mutation commit (ordering check,
        // searched over history UP TO the candidate commit only).
        let declCommit = try A18.git(root, ["log", A18.candidate, "--diff-filter=A", "--format=%H",
                                            "--", "docs/audit/AUDIT17_R4_INVERSION_LOCK.md"]).1
            .split(separator: "\n").map(String.init).last ?? ""
        XCTAssertFalse(declCommit.isEmpty, "inversion lock introduction commit found in candidate history")
        // the declaration blob is present at the candidate commit (predeclaration landed)
        let declAtCand = try A18.gitShowRaw(root,
            "\(A18.candidate):docs/audit/AUDIT17_R4_INVERSION_LOCK.md")
        XCTAssertEqual(declAtCand.0, 0, "inversion lock exists at the candidate commit")
        let mutCommits = try A18.git(root, ["log", A18.candidate, "--format=%H", "--",
            "packages/GuardianKit/Tests/GuardianCoreTests/RWCPreregistrationR3Tests.swift"]).1
            .split(separator: "\n").map(String.init)
        if let newestMut = mutCommits.first {
            let order = try A18.git(root, ["merge-base", "--is-ancestor", declCommit, newestMut])
            XCTAssertEqual(order.0, 0,
                           "supersession PRE-DECLARED at/before the inverting commit")
        }
    }

    // MARK: §3 zero-data hard gate

    func test_A18_03_ZeroData_HardGate_NoPassLock_FailClosed() throws {
        let root = A18.repoRoot()
        let master = try JSONSerialization.jsonObject(with: Data(contentsOf:
            root.appendingPathComponent(A18.masterPath))) as! [String: Any]
        XCTAssertEqual(master["corpus_count"] as? Int, 0)
        XCTAssertEqual(master["annotator_count"] as? Int, 0)
        XCTAssertEqual(master["real_fit_count"] as? Int, 0)
        XCTAssertEqual(master["heldout_open_count"] as? Int, 0)
        XCTAssertEqual(master["data_visibility"] as? Bool, false)
        // NO PASS lock may exist; the REAL repo fails closed at the V4 boundary
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: root.appendingPathComponent(RWCPre14PassLockV3.lockRelPath).path),
            "PASS lock must be ABSENT")
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV4.verify(repoRoot: root)) { e in
            XCTAssertEqual(e as? RWCCorpusEntryErrorV4, .lockMissing,
                           "real repo fails closed (lockMissing) — no corpus entry authority exists")
        }
        // no R4 audit-result blob exists in the CANDIDATE tree (pre-audit truth, git-pinned)
        let blob = try A18.run("git", ["-C", root.path, "show",
                                       "\(A18.candidate):docs/audit/RWC_PRE14_R4_AUDIT_RESULT.json"])
        XCTAssertNotEqual(blob.0, 0, "no R4 audit result in the candidate tree")
    }

    // MARK: §52 durable rights store V3 regression (reopen / tombstone / witness / flock)

    func test_A18_04_DurableRights_Regression_Reopen_Tombstone_Witness_Flock() throws {
        let dir = A18.tempDir("led-reg")
        defer { try? FileManager.default.removeItem(at: dir) }
        let payloadHash = A18.shaHex("a18-reg-payload")
        var headAfterRegister = ""
        do {
            let store = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
            let g = A18.grant()
            try store.register(A18.record(contentHash: payloadHash), verifiedGrant: A18.mintV1(g),
                               clock: A18.clock("2026-10-01"))
            headAfterRegister = store.headDigest
            XCTAssertEqual(store.eventCount, 1)
            // flock single-writer law: second open while the first holds the lock refuses
            XCTAssertThrowsError(try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)) { e in
                XCTAssertEqual(e as? RWCRightsLedgerErrorV3, .lockedByAnotherWriter)
            }
            try store.revoke(assetID: "rwc-asset-a18asset01", clock: A18.clock("2026-10-02"))
            XCTAssertTrue(store.isTombstoned("rwc-asset-a18asset01"))
            store.closeStore()
        }
        // reopen: events survive, chain verified, tombstone durable, head witnessed
        let reopened = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        defer { reopened.closeStore() }
        XCTAssertEqual(reopened.eventCount, 2, "register + revoke survive restart")
        XCTAssertTrue(reopened.isTombstoned("rwc-asset-a18asset01"), "tombstone is durable")
        XCTAssertNotEqual(reopened.headDigest, headAfterRegister, "head advanced past register")
        // resurrection is refused forever (register after revoke)
        let g2 = A18.grant(id: "rwc-grant-a18res001", digestSeed: "a18-res",
                           review: "rwc-review-a18res01")
        XCTAssertThrowsError(try reopened.register(A18.record(g: g2, contentHash: payloadHash),
                                                   verifiedGrant: A18.mintV1(g2),
                                                   clock: A18.clock("2026-10-03"))) { e in
            XCTAssertEqual(e as? RWCRightsErrorV3, .resurrectionRefused)
        }
    }

    // MARK: §51 calibration regression (light; AUDIT17 upheld V4 — no redesign)

    func test_A18_05_Calibration_Regression_S_n_IRR_Frozen() throws {
        XCTAssertEqual(RWCCalibrationMethodologyV4.frozenNullSims, 9999, "S=9999 law")
        XCTAssertEqual(RWCCalibrationMethodologyV4.frozenOverallN, 800, "n=800 law")
        XCTAssertEqual(RWCCalibrationMethodologyV4.irrOrdinalKappaThreshold, 0.60, "IRR 0.60 law")
        let root = A18.repoRoot()
        let gates = try String(contentsOf: root.appendingPathComponent(
            "docs/calibration/preregistration/RWC_FROZEN_GATES_V5.yaml"), encoding: .utf8)
        XCTAssertTrue(gates.contains("S=9999"), "gates V5 carries the S=9999 analytical law")
        XCTAssertTrue(gates.contains("IRR(0.60)"), "gates V5 carries the IRR 0.60 law")
        let power = try String(contentsOf: root.appendingPathComponent(
            "docs/calibration/preregistration/RWC_CALIBRATION_POWER_PREREG_V4.yaml"), encoding: .utf8)
        XCTAssertTrue(power.contains("800"), "power prereg V4 carries n=800")
    }
}

#endif
