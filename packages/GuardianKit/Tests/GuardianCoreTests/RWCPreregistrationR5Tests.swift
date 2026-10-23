import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
import RWCAcquisition

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC PRE-14 R5 BUILDER TESTS — fresh family for the AUDIT18 remediation (2 HIGH A18-F1/F5 +
// 2 MEDIUM A18-F2/F3 + LOW A18-F4/F6/F10). Zero AUDIT18 inversions; superseded V4/V2 surfaces keep
// their defect pins. Central principle under test: SIGNATURE AUTHENTICITY != TRUST AUTHORITY.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class RWCPreregistrationR5Tests: XCTestCase {

    // MARK: helpers

    private func repoRoot() -> URL { RWCPowerDerivationV3.repoRootURL() }
    private func read(_ rel: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(rel), encoding: .utf8)
    }
    private func shaHex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func d3(_ s: String) -> RWCDateV3 { try! RWCDateV3.parse(s, field: "test") }
    private func clock(_ s: String) -> RWCFixedClockV3 { try! RWCFixedClockV3(s) }
    private func tempDir(_ tag: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("r5-\(tag)-\(UUID().uuidString)")
    }

    // Synthetic governed trust root (explicitly SYNTHETIC; never a real reviewer trust root).
    private func syntheticRoot() -> (RWCVerifiedReviewerTrustRootV1, Curve25519.Signing.PrivateKey) {
        let r = RWCReviewerTrustRootLoaderV1.makeSyntheticTestRoot()
        return (r.root, r.privateKey)
    }

    // A synthetic reviewer key (explicitly SYNTHETIC FIXTURE).
    private let reviewerKey = Curve25519.Signing.PrivateKey()
    private var reviewerPubHex: String {
        reviewerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
    }

    /// Build a root-signed registry document and VERIFY it into an RWCVerifiedReviewerRegistryV1.
    /// This is the lawful path: a caller-authored dictionary can never reach the verified type.
    private func verifiedRegistry(rootPriv: Curve25519.Signing.PrivateKey,
                                  root: RWCVerifiedReviewerTrustRootV1,
                                  reviewerID: String = "rwc-reviewer-r5test01",
                                  reviewerKeyHex: String? = nil,
                                  status: String = "ACTIVE",
                                  role: String = "RIGHTS_REVIEW",
                                  scope: RWCReviewerScopeV1 = .corpus,
                                  validFrom: String = "2026-01-01",
                                  validUntil: String? = "2027-12-31",
                                  revision: Int = 1,
                                  registryRevision: Int = 1,
                                  previousDigest: String? = nil,
                                  signWith: Curve25519.Signing.PrivateKey? = nil,
                                  extraEntries: [RWCReviewerRegistryEntryV1] = [],
                                  previousVerified: RWCVerifiedReviewerRegistryV1? = nil)
        throws -> RWCVerifiedReviewerRegistryV1 {
        let entry = RWCReviewerRegistryEntryV1(
            reviewerID: reviewerID, publicKeyRawHex: reviewerKeyHex ?? reviewerPubHex,
            status: status, role: role, scope: scope.rawValue,
            validFrom: d3(validFrom), validUntil: validUntil.map { d3($0) }, revision: revision)
        let prevDigest = previousDigest
            ?? previousVerified?.documentDigest
            ?? RWCReviewerRegistryDocumentV2.genesisPreviousDigest
        var doc = RWCReviewerRegistryDocumentV2(
            registryVersion: RWCReviewerRegistryDocumentV2.schemaVersion,
            registryRevision: registryRevision, rootID: root.rootID, createdAt: d3("2026-02-01"),
            previousRegistryDigest: prevDigest, reviewers: [entry] + extraEntries, signatureHex: "")
        let signer = signWith ?? rootPriv
        let sig = try signer.signature(for: doc.canonicalPayloadBytes)
        doc = RWCReviewerRegistryDocumentV2(
            registryVersion: doc.registryVersion, registryRevision: doc.registryRevision,
            rootID: doc.rootID, createdAt: doc.createdAt,
            previousRegistryDigest: doc.previousRegistryDigest, reviewers: doc.reviewers,
            signatureHex: sig.map { String(format: "%02x", $0) }.joined())
        return try RWCReviewerRegistryVerifierV1.verify(document: doc, trustRoot: root,
                                                        previousVerified: previousVerified)
    }

    private func grant(id: String = "rwc-grant-r5aa0001", digestSeed: String = "proof-a",
                       allowed: [String] = ["training", "evaluation"], prohibited: [String] = [],
                       effective: String = "2026-08-01", expiry: String? = "2027-08-01",
                       review: String = "rwc-review-r5rv0001") -> RWCLegalGrantIdentityV1 {
        RWCLegalGrantIdentityV1(grantID: id, grantRevision: 1, evidenceDigest: shaHex(digestSeed),
                                evidencePointer: "rwc-rights-ref-r5p0001", rightsHolder: "licensor-a",
                                allowedUse: allowed, prohibitedUse: prohibited,
                                effectiveDate: d3(effective), expiryDate: expiry.map { d3($0) },
                                reviewDecision: "APPROVED", reviewRecordID: review)
    }

    private func signedReview(for g: RWCLegalGrantIdentityV1,
                              source: RWCSourceAuthorizationV1,
                              reviewerID: String = "rwc-reviewer-r5test01",
                              decision: String = "APPROVED",
                              reviewDate: String = "2026-08-15",
                              key: Curve25519.Signing.PrivateKey? = nil,
                              tamperSignature: Bool = false) throws -> RWCSignedRightsReviewV1 {
        var r = RWCSignedRightsReviewV1(
            reviewRecordID: g.reviewRecordID, reviewerID: reviewerID, grantID: g.grantID,
            grantRevision: g.grantRevision, evidenceDigest: g.evidenceDigest,
            rightsHolder: g.rightsHolder, sourceAuthorization: source,
            allowedUse: g.allowedUse, prohibitedUse: g.prohibitedUse,
            effectiveDate: g.effectiveDate, expiryDate: g.expiryDate,
            decision: decision, reviewDate: d3(reviewDate), signatureHex: "")
        let signer = key ?? reviewerKey
        var sig = try signer.signature(for: r.canonicalPayloadBytes)
        if tamperSignature { sig[0] ^= 0xFF }
        let sigHex = sig.map { String(format: "%02x", $0) }.joined()
        r = RWCSignedRightsReviewV1(
            reviewRecordID: r.reviewRecordID, reviewerID: r.reviewerID, grantID: r.grantID,
            grantRevision: r.grantRevision, evidenceDigest: r.evidenceDigest,
            rightsHolder: r.rightsHolder, sourceAuthorization: r.sourceAuthorization,
            allowedUse: r.allowedUse, prohibitedUse: r.prohibitedUse,
            effectiveDate: r.effectiveDate, expiryDate: r.expiryDate,
            decision: r.decision, reviewDate: r.reviewDate, signatureHex: sigHex)
        return r
    }

    private func verifiedGrantV3(_ g: RWCLegalGrantIdentityV1,
                                 source: RWCSourceAuthorizationV1,
                                 registry: RWCVerifiedReviewerRegistryV1) throws -> RWCVerifiedRightsGrantV3 {
        try RWCRightsReviewAuthorityV3.verify(signedReview: try signedReview(for: g, source: source),
                                              grant: g, verifiedRegistry: registry)
    }

    private let exactSource = RWCSourceAuthorizationV1.exactSource("rwc-source-ref-r5src0001")

    private func request(assetID: String = "rwc-asset-r5aaaa01",
                         sourceClass: RWCSourceClassV1 = .licensedRightsClear,
                         source: String = "rwc-source-ref-r5src0001",
                         owner: String = "gen8", use: RWCUseV1 = .training,
                         session: String = "rwc-acq-r5session0000001",
                         manifestSources: [String]? = nil,
                         checksum: String? = nil) -> RWCAcquisitionRequestV1 {
        RWCAcquisitionRequestV1(assetID: assetID, sourceClass: sourceClass, sourceReference: source,
                                owner: owner, intendedUse: use, sessionID: session,
                                manifestSources: manifestSources, trustedExpectedChecksum: checksum)
    }

    // MARK: 1 — discipline (AUDIT18 6 frozen SHAs + active byte-identity + lock pins)

    func testR5_Discipline_AUDIT18Frozen_ZeroInversions_SingleSupersession() throws {
        func sha(_ rel: String) throws -> String {
            let d = try Data(contentsOf: repoRoot().appendingPathComponent(rel))
            return SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
        }
        // The 6 AUDIT18 frozen originals (from AUDIT18_R5_INVERSION_LOCK.md).
        let frozenOriginals: [(String, String)] = [
            ("AUDIT18_RWCPre14R4ReauditProbes_ORIGINAL_LOCKED.swift.txt",
             "08f396c445ca68abfef6706a98b17b16192ccde617ce457ee5f3a50d676eaf12"),
            ("AUDIT18_RightsAuthorityProbes_ORIGINAL_LOCKED.swift.txt",
             "962384897f5a0fdb3ccf412be1228a0ebd7c2d25589b23b1c26678d2e02d87a5"),
            ("AUDIT18_VerifierFreezeProbes_ORIGINAL_LOCKED.swift.txt",
             "dcb9881efb8e696fd86a136966b0d91d47c541b806ae73f7c3320cccb8ea8630"),
            ("AUDIT18_AcquisitionRunnerProbes_ORIGINAL_LOCKED.swift.txt",
             "6ae90e648d480d0c0c9fe32e7454031d74ce251eb76fce0ceb1c62630f09c1a7"),
            ("RWC_PRE14_R4_AUDIT_RESULT_ORIGINAL_LOCKED.json",
             "47358f2a1675b5fec8e8348cbf868d09a5bc60852e68a70ff7f32e9e4e768820"),
            ("GEN8_RWC_PREREGISTRATION_PRE14_R4_INDEPENDENT_REAUDIT_ORIGINAL_LOCKED.md",
             "73fe0f70f946e3a10030bb39960e926ddda3b2894ca3a03f0bb4c29f1755d84e"),
        ]
        for (name, expected) in frozenOriginals {
            XCTAssertEqual(try sha("docs/audit/\(name)"), expected, name)
        }
        // active AUDIT18 probe files: 3 byte-identical; VerifierFreezeProbes carries EXACTLY the
        // pre-declared INVERSION I-1 (ADDENDUM 1): the add-only topology guard re-anchored from
        // floating HEAD to the immutable AUDIT18 commit. Original stays byte-preserved above.
        let byteIdenticalProbes: [(String, String)] = [
            ("AUDIT18_RWCPre14R4ReauditProbes", "AUDIT18_RWCPre14R4ReauditProbes_ORIGINAL_LOCKED.swift.txt"),
            ("AUDIT18_RightsAuthorityProbes", "AUDIT18_RightsAuthorityProbes_ORIGINAL_LOCKED.swift.txt"),
            ("AUDIT18_AcquisitionRunnerProbes", "AUDIT18_AcquisitionRunnerProbes_ORIGINAL_LOCKED.swift.txt"),
        ]
        for (probe, original) in byteIdenticalProbes {
            XCTAssertEqual(
                try sha("packages/GuardianKit/Tests/GuardianCoreTests/\(probe).swift"),
                try sha("docs/audit/\(original)"),
                "\(probe) must be byte-identical to its frozen original")
        }
        let invertedActive = try read(
            "packages/GuardianKit/Tests/GuardianCoreTests/AUDIT18_VerifierFreezeProbes.swift")
        XCTAssertNotEqual(try sha("packages/GuardianKit/Tests/GuardianCoreTests/AUDIT18_VerifierFreezeProbes.swift"),
                          try sha("docs/audit/AUDIT18_VerifierFreezeProbes_ORIGINAL_LOCKED.swift.txt"),
                          "I-1 declared inversion must be present")
        XCTAssertTrue(invertedActive.contains("R5 INVERSION I-1"))
        XCTAssertTrue(invertedActive.contains(
            "let auditCommit = \"ac91974ddba3289031efe1df075185178259472b\""),
            "topology guard must be pinned to the immutable AUDIT18 commit")
        XCTAssertFalse(invertedActive.contains("A18.candidate, \"HEAD\""))
        // R4 machine result remains FIX_REQUIRED 0/2/2 history.
        let r4 = try RWCPre14AuditResultV2.parse(data: try Data(contentsOf:
            repoRoot().appendingPathComponent(RWCPre14AuditResultV2.canonicalPath)))
        XCTAssertEqual(r4.verdict, "FIX_REQUIRED")
        XCTAssertEqual(r4.highCount, 2); XCTAssertEqual(r4.mediumCount, 2)
        let lock = try read("docs/audit/AUDIT18_R5_INVERSION_LOCK.md")
        XCTAssertTrue(lock.contains("ZERO AUDIT18 INVERSIONS DECLARED"))
        XCTAssertTrue(lock.contains("EXACTLY ONE HISTORICAL R4 BUILDER-FILE SUPERSESSION"))
    }

    // MARK: 2 — A18-F1: self-enrollment attack dead + trust-root chain matrix

    func testR5_F1_SelfEnrollmentDead_TrustRootChain_Matrix() throws {
        let (root, rootPriv) = syntheticRoot()
        let reg = try verifiedRegistry(rootPriv: rootPriv, root: root)
        let g = grant()
        // LAWFUL: synthetic root → signed registry → review authority V3 → verified grant V3.
        XCTAssertNoThrow(try verifiedGrantV3(g, source: exactSource, registry: reg))

        // COMPILE-LEVEL LAW (documented): there is NO initializer a caller can reach to build an
        // RWCVerifiedReviewerRegistryV1 or an RWCVerifiedRightsGrantV3 — both inits are fileprivate.
        // RWCRightsReviewAuthorityV3.verify REQUIRES the verified-registry PROOF TYPE as a parameter,
        // so a caller-authored dictionary of reviewers can never substitute. The self-enrollment
        // attack that minted a grant in V4 (caller-supplied RWCAuthorizedReviewerRegistryV1) cannot
        // even be expressed against the V3 API. The runtime matrix below exercises every REFUSAL.

        // unsigned/tampered REGISTRY signature (not the root) → REFUSE at verify.
        XCTAssertThrowsError(try verifiedRegistry(rootPriv: rootPriv, root: root,
                                                  signWith: Curve25519.Signing.PrivateKey())) { e in
            XCTAssertEqual(e as? RWCReviewerTrustErrorV1, .registrySignatureInvalid)
        }
        // WRONG-ROOT registry (document.rootID != trust root) → REFUSE.
        let otherRoot = RWCReviewerTrustRootLoaderV1.makeSyntheticTestRoot(
            rootID: "rwc-root-synthetic99", governanceRecordID: "rwc-gov-synthetic99").root
        var mismatchDoc = RWCReviewerRegistryDocumentV2(
            registryVersion: RWCReviewerRegistryDocumentV2.schemaVersion, registryRevision: 1,
            rootID: otherRoot.rootID, createdAt: d3("2026-02-01"),
            previousRegistryDigest: RWCReviewerRegistryDocumentV2.genesisPreviousDigest,
            reviewers: [RWCReviewerRegistryEntryV1(
                reviewerID: "rwc-reviewer-r5test01", publicKeyRawHex: reviewerPubHex,
                status: "ACTIVE", role: "RIGHTS_REVIEW", scope: RWCReviewerScopeV1.corpus.rawValue,
                validFrom: d3("2026-01-01"), validUntil: d3("2027-12-31"), revision: 1)],
            signatureHex: "")
        let msig = try rootPriv.signature(for: mismatchDoc.canonicalPayloadBytes)
        mismatchDoc = RWCReviewerRegistryDocumentV2(
            registryVersion: mismatchDoc.registryVersion, registryRevision: 1, rootID: otherRoot.rootID,
            createdAt: mismatchDoc.createdAt, previousRegistryDigest: mismatchDoc.previousRegistryDigest,
            reviewers: mismatchDoc.reviewers,
            signatureHex: msig.map { String(format: "%02x", $0) }.joined())
        XCTAssertThrowsError(try RWCReviewerRegistryVerifierV1.verify(document: mismatchDoc,
                                                                      trustRoot: root)) { e in
            XCTAssertEqual(e as? RWCReviewerTrustErrorV1, .registryRootMismatch)
        }
        // DUPLICATE reviewer ID within one document → REFUSE (no silent overwrite).
        let dupEntry = RWCReviewerRegistryEntryV1(
            reviewerID: "rwc-reviewer-r5test01", publicKeyRawHex: reviewerPubHex, status: "ACTIVE",
            role: "RIGHTS_REVIEW", scope: RWCReviewerScopeV1.corpus.rawValue,
            validFrom: d3("2026-01-01"), validUntil: d3("2027-12-31"), revision: 2)
        XCTAssertThrowsError(try verifiedRegistry(rootPriv: rootPriv, root: root,
                                                  extraEntries: [dupEntry])) { e in
            XCTAssertEqual(e as? RWCReviewerTrustErrorV1,
                           .duplicateReviewerInDocument(reviewerID: "rwc-reviewer-r5test01"))
        }

        // UNKNOWN reviewer (not in the verified registry) → REFUSE.
        XCTAssertThrowsError(try RWCRightsReviewAuthorityV3.verify(
            signedReview: try signedReview(for: g, source: exactSource,
                                           reviewerID: "rwc-reviewer-nobody01"),
            grant: g, verifiedRegistry: reg)) { e in
            XCTAssertEqual(e as? RWCRightsAuthorityErrorV3, .reviewerNotInVerifiedRegistry)
        }
        // UNSIGNED / tampered REVIEW signature → REFUSE.
        XCTAssertThrowsError(try RWCRightsReviewAuthorityV3.verify(
            signedReview: try signedReview(for: g, source: exactSource, tamperSignature: true),
            grant: g, verifiedRegistry: reg)) { e in
            XCTAssertEqual(e as? RWCRightsAuthorityErrorV3, .signatureInvalid)
        }
        // review signed by an UNKNOWN key (not the registered reviewer key) → REFUSE.
        XCTAssertThrowsError(try RWCRightsReviewAuthorityV3.verify(
            signedReview: try signedReview(for: g, source: exactSource,
                                           key: Curve25519.Signing.PrivateKey()),
            grant: g, verifiedRegistry: reg)) { e in
            XCTAssertEqual(e as? RWCRightsAuthorityErrorV3, .signatureInvalid)
        }
        // REVOKED reviewer → REFUSE.
        let revokedReg = try verifiedRegistry(rootPriv: rootPriv, root: root, status: "REVOKED")
        XCTAssertThrowsError(try verifiedGrantV3(g, source: exactSource, registry: revokedReg)) { e in
            XCTAssertEqual(e as? RWCRightsAuthorityErrorV3, .reviewerNotActive(status: "REVOKED"))
        }
        // review date OUTSIDE validity → REFUSE.
        XCTAssertThrowsError(try RWCRightsReviewAuthorityV3.verify(
            signedReview: try signedReview(for: g, source: exactSource, reviewDate: "1500-01-01"),
            grant: g, verifiedRegistry: reg)) { e in
            XCTAssertEqual(e as? RWCRightsAuthorityErrorV3, .reviewerOutsideValidity)
        }
    }

    // MARK: 3 — A18-F2: reviewer.scope enforced

    func testR5_F2_ReviewerScopeEnforced() throws {
        let (root, rootPriv) = syntheticRoot()
        let g = grant()
        // annotation-scoped reviewer cannot approve a corpus grant.
        let annReg = try verifiedRegistry(rootPriv: rootPriv, root: root, scope: .annotation)
        XCTAssertThrowsError(try verifiedGrantV3(g, source: exactSource, registry: annReg)) { e in
            XCTAssertEqual(e as? RWCRightsAuthorityErrorV3,
                           .reviewerScopeUnauthorized(scope: "rwc-annotation"))
        }
        // governance-scoped reviewer cannot approve a corpus grant.
        let govReg = try verifiedRegistry(rootPriv: rootPriv, root: root, scope: .governance)
        XCTAssertThrowsError(try verifiedGrantV3(g, source: exactSource, registry: govReg)) { e in
            XCTAssertEqual(e as? RWCRightsAuthorityErrorV3,
                           .reviewerScopeUnauthorized(scope: "rwc-governance"))
        }
        // wrong ROLE → REFUSE.
        let roleReg = try verifiedRegistry(rootPriv: rootPriv, root: root, role: "ANNOTATION")
        XCTAssertThrowsError(try verifiedGrantV3(g, source: exactSource, registry: roleReg)) { e in
            XCTAssertEqual(e as? RWCRightsAuthorityErrorV3, .reviewerRoleUnauthorized)
        }
        // corpus-scoped reviewer: lawful mint.
        let corpusReg = try verifiedRegistry(rootPriv: rootPriv, root: root, scope: .corpus)
        XCTAssertNoThrow(try verifiedGrantV3(g, source: exactSource, registry: corpusReg))
    }

    // MARK: 4 — A18-F1 registry rollback/rotation law

    func testR5_F1_RegistryRevisionRollback_Rotation() throws {
        let (root, rootPriv) = syntheticRoot()
        let rev1 = try verifiedRegistry(rootPriv: rootPriv, root: root, registryRevision: 1)
        // lawful next revision (rev2 chained onto rev1).
        let rev2 = try verifiedRegistry(rootPriv: rootPriv, root: root, revision: 2,
                                        registryRevision: 2, previousVerified: rev1)
        XCTAssertEqual(rev2.registryRevision, 2)
        // rollback: presenting rev1-shaped revision against a rev2 previous → REFUSE monotonic.
        XCTAssertThrowsError(try verifiedRegistry(rootPriv: rootPriv, root: root, registryRevision: 1,
                                                  previousVerified: rev2)) { e in
            XCTAssertEqual(e as? RWCReviewerTrustErrorV1,
                           .registryRevisionNotMonotonic(expected: 3, found: 1))
        }
        // wrong previous digest at the right revision → REFUSE.
        XCTAssertThrowsError(try verifiedRegistry(
            rootPriv: rootPriv, root: root, registryRevision: 2,
            previousDigest: String(repeating: "ab", count: 32), previousVerified: rev1)) { e in
            XCTAssertEqual(e as? RWCReviewerTrustErrorV1, .registryPreviousDigestMismatch)
        }
    }

    // MARK: 5 — A18-F1 production loader fail-closed

    func testR5_F1_ProductionLoaderFailClosed_NoInstanceInRepo() throws {
        // docs/operations/rwc instance MUST NOT exist in R5.
        XCTAssertFalse(FileManager.default.fileExists(atPath:
            repoRoot().appendingPathComponent(RWCReviewerTrustRootV1.canonicalInstancePath).path))
        XCTAssertThrowsError(try RWCReviewerTrustRootLoaderV1.loadProduction(repoRoot: repoRoot())) { e in
            XCTAssertEqual(e as? RWCReviewerTrustErrorV1, .noOperationalRoot)
        }
        // a temp repo with no root also fails closed.
        let empty = tempDir("noroot")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }
        XCTAssertThrowsError(try RWCReviewerTrustRootLoaderV1.loadProduction(repoRoot: empty)) { e in
            XCTAssertEqual(e as? RWCReviewerTrustErrorV1, .noOperationalRoot)
        }
        // a RETIRED root file never mints (fail-closed on status).
        let retiredRepo = tempDir("retired")
        let retiredDir = retiredRepo.appendingPathComponent("docs/operations/rwc")
        try FileManager.default.createDirectory(at: retiredDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: retiredRepo) }
        let (_, priv) = syntheticRoot()
        let keyHex = priv.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let retired = """
        {"root_id": "rwc-root-retired01", "public_key_raw_hex": "\(keyHex)", "algorithm": "ed25519",
         "activation_date": "2026-01-01", "status": "RETIRED", "governance_record_id": "rwc-gov-x"}
        """
        try retired.write(to: retiredRepo.appendingPathComponent(RWCReviewerTrustRootV1.canonicalInstancePath),
                          atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try RWCReviewerTrustRootLoaderV1.loadProduction(repoRoot: retiredRepo)) { e in
            XCTAssertEqual(e as? RWCReviewerTrustErrorV1, .rootNotActive(status: "RETIRED"))
        }
    }

    // MARK: 6 — A18-F10: source manifest canonicality

    func testR5_F10_SourceManifestCanonicality() throws {
        // empty manifest → REFUSE.
        XCTAssertThrowsError(try RWCSourceManifestLawV2.canonicalManifestDigest(sources: [])) { e in
            XCTAssertEqual(e as? RWCSourceManifestLawV2.ErrorV1, .emptyManifest)
        }
        // duplicate → REFUSE.
        XCTAssertThrowsError(try RWCSourceManifestLawV2.canonicalManifestDigest(
            sources: ["rwc-source-ref-r5m01", "rwc-source-ref-r5m01"])) { e in
            XCTAssertEqual(e as? RWCSourceManifestLawV2.ErrorV1,
                           .duplicateSourceReference("rwc-source-ref-r5m01"))
        }
        // invalid grammar → REFUSE.
        XCTAssertThrowsError(try RWCSourceManifestLawV2.canonicalManifestDigest(
            sources: ["https://evil"])) { e in
            XCTAssertEqual(e as? RWCSourceManifestLawV2.ErrorV1,
                           .invalidSourceReference("https://evil"))
        }
        // valid list: canonical digest == the V1 helper digest (byte-stable history).
        let valid = ["rwc-source-ref-r5m0002", "rwc-source-ref-r5m0001"]
        XCTAssertEqual(try RWCSourceManifestLawV2.canonicalManifestDigest(sources: valid),
                       RWCSourceAuthorizationV1.manifestDigest(ofSources: valid))
        // evaluator V2: member covered, non-member + degenerate manifest refused pre-fetch.
        let (root, rootPriv) = syntheticRoot()
        let reg = try verifiedRegistry(rootPriv: rootPriv, root: root)
        let manifest = RWCSourceAuthorizationV1.sourceManifest(
            digest: try RWCSourceManifestLawV2.canonicalManifestDigest(sources: valid))
        let gM = grant(id: "rwc-grant-r5mm0002", review: "rwc-review-r5rv0002")
        let vgM = try verifiedGrantV3(gM, source: manifest, registry: reg)
        XCTAssertNoThrow(try RWCPreAcquisitionEvaluatorV2.authorize(
            request: request(source: "rwc-source-ref-r5m0001", manifestSources: valid),
            verifiedGrant: vgM, transactionDate: d3("2026-10-01")))
        XCTAssertThrowsError(try RWCPreAcquisitionEvaluatorV2.authorize(
            request: request(source: "rwc-source-ref-r5m0001",
                             manifestSources: ["rwc-source-ref-r5m0001", "rwc-source-ref-r5m0001"]),
            verifiedGrant: vgM, transactionDate: d3("2026-10-01"))) { e in
            XCTAssertEqual(e as? RWCSourceManifestLawV2.ErrorV1,
                           .duplicateSourceReference("rwc-source-ref-r5m0001"))
        }
    }

    // MARK: 7 — A18-F3: durable receipt store

    private final class SpyAcquirer: RWCAssetAcquirerV1 {
        var calls = 0
        let payload: Data
        init(_ payload: Data = Data("r5-synthetic-bytes".utf8)) { self.payload = payload }
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

    @discardableResult
    private func prepareSample(_ store: RWCAcquisitionReceiptStoreV1,
                               session: String = "rwc-acq-r5receipt00000001",
                               asset: String = "rwc-asset-r5rcpt01") throws -> RWCAcquisitionReceiptV2 {
        try store.prepare(
            sessionID: session, assetID: asset, contentHash: shaHex("bytes"),
            intendedUse: .training, legalGrantID: "rwc-grant-r5aa0001", grantRevision: 1,
            reviewRecordID: "rwc-review-r5rv0001", reviewerID: "rwc-reviewer-r5test01",
            rightsLedgerHeadDigest: shaHex("head"), rightsEventCount: 1,
            passLockCandidateCommit: "candidate", passLockTagObjectSHA: "tagobj",
            auditResultBlobSHA256: "auditblob", freezeManifestSHA256: "freeze",
            methodologyAnchorCommit: "anchor", transactionDate: "2026-10-01")
    }

    func testR5_F3_ReceiptStore_Durable_Idempotent_IntegrityTamper() throws {
        let dir = tempDir("rcpt")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try RWCAcquisitionReceiptStoreV1(directory: dir)
        defer { store.closeStore() }
        let r = try prepareSample(store)
        XCTAssertEqual(try store.load(r.sessionID).state, .prepared)
        // duplicate session → typed refusal.
        XCTAssertThrowsError(try prepareSample(store)) { e in
            XCTAssertEqual(e as? RWCReceiptStoreErrorV1, .duplicateSession(r.sessionID))
        }
        try store.confirmPromotion(sessionID: r.sessionID)
        XCTAssertEqual(try store.load(r.sessionID).state, .promotionConfirmed)
        // idempotent re-confirm.
        try store.confirmPromotion(sessionID: r.sessionID)
        XCTAssertEqual(try store.load(r.sessionID).state, .promotionConfirmed)
        try store.complete(sessionID: r.sessionID)
        XCTAssertEqual(try store.load(r.sessionID).state, .completed)
        // idempotent re-complete.
        try store.complete(sessionID: r.sessionID)
        XCTAssertEqual(try store.load(r.sessionID).state, .completed)
        // unknown session → typed refusal.
        XCTAssertThrowsError(try store.load("rwc-acq-r5unknown000000001")) { e in
            XCTAssertEqual(e as? RWCReceiptStoreErrorV1, .unknownSession("rwc-acq-r5unknown000000001"))
        }
        XCTAssertEqual(try store.allReceipts().count, 1)
        // durability across reopen: a second store instance reads the completed receipt.
        store.closeStore()
        let store2 = try RWCAcquisitionReceiptStoreV1(directory: dir)
        defer { store2.closeStore() }
        XCTAssertEqual(try store2.load(r.sessionID).state, .completed)
        // integrity tamper detection (corruption, NOT authentication): corrupt the body only.
        let url = dir.appendingPathComponent("receipt-\(r.sessionID).json")
        var raw = try String(contentsOf: url, encoding: .utf8)
        raw = raw.replacingOccurrences(of: "\"COMPLETED\"", with: "\"PREPARED\"")  // body != digest now
        try raw.write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try store2.load(r.sessionID)) { e in
            guard case .integrityFailure = e as? RWCReceiptStoreErrorV1 else { return XCTFail("\(e)") }
        }
    }

    // MARK: 8 — A18-F3/F6: runner V3 lawful flow + crash recovery + authority mismatch

    private func runnerFixture() throws -> (RWCVerifiedCorpusEntryV5, URL,
                                            RWCVerifiedRightsGrantV3, Curve25519.Signing.PrivateKey) {
        let fx = try makeFixtureV5()
        let proof = try RWCCorpusEntryVerifierV5.verify(repoRoot: fx.root)
        let (root, rootPriv) = syntheticRoot()
        let reg = try verifiedRegistry(rootPriv: rootPriv, root: root)
        let vg = try verifiedGrantV3(grant(), source: exactSource, registry: reg)
        return (proof, fx.root, vg, rootPriv)
    }

    func testR5_F3F6_RunnerV3_LawfulFlow_CrashRecovery_AuthorityMismatch() throws {
        let (proof, fxRoot, vg, rootPriv) = try runnerFixture()
        defer { try? FileManager.default.removeItem(at: fxRoot) }
        let qRoot = tempDir("q")
        try FileManager.default.createDirectory(at: qRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: qRoot) }
        let runner = RWCCorpusAcquisitionRunnerV3(quarantineRoot: qRoot)
        let ledgerDir = tempDir("led")
        defer { try? FileManager.default.removeItem(at: ledgerDir) }
        let store = try RWCAssetRightsLedgerStoreV3.create(directory: ledgerDir)
        defer { store.closeStore() }
        let rcptDir = tempDir("rcpt")
        defer { try? FileManager.default.removeItem(at: rcptDir) }
        let receiptStore = try RWCAcquisitionReceiptStoreV1(directory: rcptDir)
        defer { receiptStore.closeStore() }
        let corpus = FixtureCorpusStore()

        // lawful flow: durable COMPLETED receipt; returned receipt derived from the record.
        let spy = SpyAcquirer()
        let receipt = try runner.acquire(proof: proof, request: request(), verifiedGrant: vg,
                                         rightsStore: store, corpusStore: corpus, acquirer: spy,
                                         clock: clock("2026-10-01"), receiptStore: receiptStore)
        XCTAssertEqual(receipt.assetID, "rwc-asset-r5aaaa01")
        XCTAssertEqual(try receiptStore.load("rwc-acq-r5session0000001").state, .completed)
        XCTAssertEqual(corpus.promoted["rwc-asset-r5aaaa01"], spy.payload)
        XCTAssertEqual(spy.calls, 1)

        // CRASH after rights commit + durable PREPARED, before promote: PREPARED survives.
        let (root2, rootPriv2) = syntheticRoot()
        _ = rootPriv  // silence
        let reg2 = try verifiedRegistry(rootPriv: rootPriv2, root: root2)
        let g2 = grant(id: "rwc-grant-r5gg0007", review: "rwc-review-r5rv0007")
        let vg2 = try verifiedGrantV3(g2, source: .exactSource("rwc-source-ref-r5src0002"),
                                      registry: reg2)
        corpus.failPromote = true
        XCTAssertThrowsError(try runner.acquire(
            proof: proof,
            request: request(assetID: "rwc-asset-r5bbbb02", source: "rwc-source-ref-r5src0002",
                             session: "rwc-acq-r5session0000007"),
            verifiedGrant: vg2, rightsStore: store, corpusStore: corpus,
            acquirer: SpyAcquirer(), clock: clock("2026-10-02"), receiptStore: receiptStore))
        XCTAssertEqual(try receiptStore.load("rwc-acq-r5session0000007").state, .prepared,
                       "PREPARED receipt must survive a post-rights-commit, pre-promote crash")
        corpus.failPromote = false
        // reconcileV3: promote the recoverable payload + finalize the durable receipt.
        let report = try runner.reconcileV3(rightsStore: store, corpusStore: corpus,
                                            receiptStore: receiptStore)
        XCTAssertEqual(report.recoveredSessions, ["rwc-acq-r5session0000007"])
        XCTAssertEqual(report.finalizedReceipts, ["rwc-acq-r5session0000007"])
        XCTAssertEqual(try receiptStore.load("rwc-acq-r5session0000007").state, .completed)
        XCTAssertNotNil(corpus.promoted["rwc-asset-r5bbbb02"])
        // idempotent: second reconcile promotes/finalizes nothing new.
        let report2 = try runner.reconcileV3(rightsStore: store, corpusStore: corpus,
                                             receiptStore: receiptStore)
        XCTAssertTrue(report2.recoveredSessions.isEmpty)
        XCTAssertTrue(report2.finalizedReceipts.isEmpty)
        XCTAssertTrue(report2.registeredButUnpromoted.isEmpty)

        // CRASH-AFTER-PROMOTE simulation: prepare+promote then skip finalize → reconcile finalizes.
        let g3 = grant(id: "rwc-grant-r5gg0009", review: "rwc-review-r5rv0009")
        let payload3 = Data("r5-crash-after-promote".utf8)
        let hash3 = RWCCorpusAcquisitionRunnerV3.sha256Hex(payload3)
        let session3 = "rwc-acq-r5session0000009"
        let asset3 = "rwc-asset-r5cccc03"
        // register rights + promote corpus + durable PREPARED, but leave the session metadata behind.
        let record3 = RWCAssetRightsRecordV3(
            assetID: asset3, sourceClass: .licensedRightsClear,
            sourceReference: "rwc-source-ref-r5src0003", owner: "gen8", grant: g3,
            acquisitionDate: d3("2026-10-03"), contentHash: hash3,
            provenanceChain: ["rwc-source-ref-r5src0003"])
        let v1Token3 = try RWCRightsReviewAuthorityV1.verify(
            grant: g3, reviewRecord: RWCRightsReviewRecordV1(
                reviewRecordID: g3.reviewRecordID, grantID: g3.grantID, grantRevision: 1,
                evidenceDigest: g3.evidenceDigest, decision: "APPROVED", reviewDate: d3("2026-10-03")))
        try store.register(record3, verifiedGrant: v1Token3, clock: clock("2026-10-03"))
        try corpus.promote(assetID: asset3, contentHash: hash3, payload: payload3)
        try receiptStore.prepare(
            sessionID: session3, assetID: asset3, contentHash: hash3, intendedUse: .training,
            legalGrantID: g3.grantID, grantRevision: 1, reviewRecordID: g3.reviewRecordID,
            reviewerID: "rwc-reviewer-r5test01", rightsLedgerHeadDigest: store.headDigest,
            rightsEventCount: store.eventCount, passLockCandidateCommit: proof.candidateCommit,
            passLockTagObjectSHA: proof.candidateTagObjectSHA,
            auditResultBlobSHA256: proof.auditResultBlobSHA256,
            freezeManifestSHA256: proof.freezeManifestSHA256,
            methodologyAnchorCommit: proof.methodologyAnchorCommit, transactionDate: "2026-10-03")
        let crashDir = qRoot.appendingPathComponent("rwc-quarantine-\(session3)")
        try FileManager.default.createDirectory(at: crashDir, withIntermediateDirectories: true)
        var meta3 = RWCCorpusAcquisitionRunnerV3.SessionMetadataV1(
            sessionID: session3, assetID: asset3, grantID: g3.grantID, grantRevision: 1,
            reviewRecordID: g3.reviewRecordID, reviewerID: "rwc-reviewer-r5test01",
            sourceReference: "rwc-source-ref-r5src0003", intendedUse: "training",
            transactionDate: "2026-10-03", passCandidate: proof.candidateCommit,
            state: .rightsCommitted, contentHash: hash3)
        try meta3.write(to: crashDir)
        try payload3.write(to: crashDir.appendingPathComponent("payload"))
        let report3 = try runner.reconcileV3(rightsStore: store, corpusStore: corpus,
                                             receiptStore: receiptStore)
        XCTAssertEqual(report3.finalizedReceipts, [session3],
                       "crash-after-promote: receipt finalized without double promotion")
        XCTAssertTrue(report3.recoveredSessions.isEmpty)
        XCTAssertEqual(try receiptStore.load(session3).state, .completed)

        // AUTHORITY-FIELD MISMATCH in metadata → never promoted (A18-F6).
        let g4 = grant(id: "rwc-grant-r5gg0011", review: "rwc-review-r5rv0011")
        let payload4 = Data("r5-authority-mismatch".utf8)
        let hash4 = RWCCorpusAcquisitionRunnerV3.sha256Hex(payload4)
        let asset4 = "rwc-asset-r5dddd04"
        let v1Token4 = try RWCRightsReviewAuthorityV1.verify(
            grant: g4, reviewRecord: RWCRightsReviewRecordV1(
                reviewRecordID: g4.reviewRecordID, grantID: g4.grantID, grantRevision: 1,
                evidenceDigest: g4.evidenceDigest, decision: "APPROVED", reviewDate: d3("2026-10-04")))
        try store.register(RWCAssetRightsRecordV3(
            assetID: asset4, sourceClass: .licensedRightsClear,
            sourceReference: "rwc-source-ref-r5src0004", owner: "gen8", grant: g4,
            acquisitionDate: d3("2026-10-04"), contentHash: hash4,
            provenanceChain: ["rwc-source-ref-r5src0004"]),
            verifiedGrant: v1Token4, clock: clock("2026-10-04"))
        let misDir = qRoot.appendingPathComponent("rwc-quarantine-rwc-acq-r5session0000011")
        try FileManager.default.createDirectory(at: misDir, withIntermediateDirectories: true)
        // metadata claims a DIFFERENT grantID than the authoritative rights record → hostile.
        var misMeta = RWCCorpusAcquisitionRunnerV3.SessionMetadataV1(
            sessionID: "rwc-acq-r5session0000011", assetID: asset4, grantID: "rwc-grant-r5forged01",
            grantRevision: 1, reviewRecordID: g4.reviewRecordID, reviewerID: "rwc-reviewer-r5test01",
            sourceReference: "rwc-source-ref-r5src0004", intendedUse: "training",
            transactionDate: "2026-10-04", passCandidate: proof.candidateCommit,
            state: .rightsCommitted, contentHash: hash4)
        try misMeta.write(to: misDir)
        try payload4.write(to: misDir.appendingPathComponent("payload"))
        let report4 = try runner.reconcileV3(rightsStore: store, corpusStore: corpus,
                                             receiptStore: receiptStore)
        XCTAssertTrue(report4.destroyedOrphanSessions.contains("rwc-acq-r5session0000011"),
                      "authority-field mismatch → never promoted, destroyed")
        XCTAssertNil(corpus.promoted[asset4], "authority-mismatch asset NEVER promoted")
    }

    // MARK: 9 — verifier V5 fixtures (A18-F5/F4 + schema V3 + lock V4 + V6 paths)

    private struct FixtureV5 {
        let root: URL
        let governing: String
        let anchor: String
        let candidate: String
        let audit: String
        let tagObject: String
        let manifestSHA: String
        let resultSHA: String
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

    /// Extends makeFixtureV4 to V6 paths + lock v4 + result v3. The freeze V6 manifest is committed
    /// IN THE CANDIDATE COMMIT (A18-F5 candidate-blob binding) and left byte-identical live.
    private func makeFixtureV5(resultVerdict: String = "PASS",
                               counts: (Int, Int, Int, Int, Int, Int) = (2, 1, 3, 0, 0, 0),
                               resultPathOverride: String? = nil,
                               resultTagNameOverride: String? = nil) throws -> FixtureV5 {
        let root = tempDir("vfx5")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try sh(root, ["init", "-q"])
        try write(root, "seed.txt", "governing base\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "governing"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV5.governingTagName, "-m", "governing"])
        let gates = "{\"gates\": \"fixture-v6\"}\n"
        let code = "// RWCFixtureLaw\nlet law = 5\n"
        try write(root, "docs/prereg/gates.yaml", gates)
        try write(root, "code/method/RWCFixtureLaw.swift", code)
        try write(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
                  "{\"immutable_a\": \"x\", \"data_visibility\": false, \"corpus_count\": 0, \"annotator_count\": 0, \"real_fit_count\": 0, \"heldout_open_count\": 0}\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try sh(root, ["rev-parse", "HEAD"])
        let manifestPath = RWCCorpusEntryVerifierV5.canonicalFreezeManifestPath
        let artifacts: [(String, String)] = [("docs/prereg/gates.yaml", shaHex(gates)),
                                             ("code/method/RWCFixtureLaw.swift", shaHex(code))]
        let invDigest = shaHex(artifacts.map { "\($0.0):\($0.1)" }.sorted().joined(separator: "\n"))
        let manifest = """
        {"freeze_version": "rwc-preregistration-freeze-v6", "methodology_anchor_commit": "\(anchor)",
         "governing_control_plane_lock": "\(governing)", "frozen_inventory_digest": "\(invDigest)",
         "artifacts": [\(artifacts.map { "{\"path\": \"\($0.0)\", \"sha256\": \"\($0.1)\"}" }.joined(separator: ", "))],
         "surface_rules": {"governed_roots": ["docs/prereg", "code"],
           "post_anchor_allowed": [],
           "post_audit_allowances": [{"root": "code/auditevidence", "filename_prefix": "AUDIT"}],
           "hash_exempt": []}}
        """
        // A18-F5: the manifest is committed IN THE CANDIDATE commit.
        try write(root, manifestPath, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        let tagName = "fixture-r5-candidate"
        try sh(root, ["tag", "-a", tagName, "-m", "candidate"])
        let tagObject = try sh(root, ["rev-parse", "refs/tags/" + tagName])
        let resultPath = resultPathOverride ?? RWCPre14AuditResultV3.canonicalPath
        let resultTagName = resultTagNameOverride ?? tagName
        let result = """
        {"result_version": "rwc-pre14-audit-result-v3", "verdict": "\(resultVerdict)",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "\(resultTagName)",
         "candidate_tag_object_sha": "\(tagObject)", "methodology_anchor_commit": "\(anchor)",
         "freeze_manifest_path": "\(manifestPath)", "freeze_manifest_sha256": "\(shaHex(manifest))",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "audit_probe_family": "AUDIT19_FIXTURE", "baseline_count": \(counts.0),
         "fresh_probe_count": \(counts.1), "total_count": \(counts.2),
         "critical_count": \(counts.3), "high_count": \(counts.4), "medium_count": \(counts.5),
         "auditor_declaration": "SYNTHETIC FIXTURE independent audit"}
        """
        try write(root, resultPath, result)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit"])
        let audit = try sh(root, ["rev-parse", "HEAD"])
        let lock = """
        {"lock_version": "rwc-pre14-pass-lock-v4", "audit_result_path": "\(resultPath)",
         "audit_result_blob_sha256": "\(shaHex(result))", "audit_commit": "\(audit)",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "\(tagName)",
         "candidate_tag_object_sha": "\(tagObject)", "freeze_manifest_path": "\(manifestPath)",
         "freeze_manifest_sha256": "\(shaHex(manifest))", "methodology_anchor_commit": "\(anchor)",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "corpus_entry_authorized": true, "verdict": "\(resultVerdict)"}
        """
        try write(root, RWCPre14PassLockV4.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
        return FixtureV5(root: root, governing: governing, anchor: anchor, candidate: candidate,
                         audit: audit, tagObject: tagObject, manifestSHA: shaHex(manifest),
                         resultSHA: shaHex(result))
    }

    private func expectV5(_ root: URL, _ check: (RWCCorpusEntryErrorV5) -> Bool, _ label: String,
                          file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV5.verify(repoRoot: root), label,
                             file: file, line: line) { e in
            guard let err = e as? RWCCorpusEntryErrorV5, check(err) else {
                return XCTFail("\(label): \(e)", file: file, line: line)
            }
        }
    }

    func testR5_F5F4_VerifierV5_CandidateBlob_TagName_Authority() throws {
        // real repo: fail-closed (no lock).
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV5.verify(repoRoot: repoRoot())) { e in
            XCTAssertEqual(e as? RWCCorpusEntryErrorV5, .lockMissing)
        }
        // lawful fixture mints.
        let good = try makeFixtureV5()
        defer { try? FileManager.default.removeItem(at: good.root) }
        let proof = try RWCCorpusEntryVerifierV5.verify(repoRoot: good.root)
        XCTAssertEqual(proof.candidateCommit, good.candidate)

        // A18-F5: post-candidate LIVE manifest broadening endorsed by matching result+lock → REFUSE.
        // Rewrite the live manifest AFTER the candidate commit (new commit) with the same recomputed
        // hash threaded through result+lock, but the candidate-commit blob is now stale.
        let broaden = try makeFixtureV5()
        defer { try? FileManager.default.removeItem(at: broaden.root) }
        let manifestURL = broaden.root.appendingPathComponent(
            RWCCorpusEntryVerifierV5.canonicalFreezeManifestPath)
        var mobj = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as! [String: Any]
        var rules = mobj["surface_rules"] as! [String: Any]
        rules["post_audit_allowances"] = [["root": "code", "filename_prefix": ""]]  // broaden
        mobj["surface_rules"] = rules
        let broadened = try JSONSerialization.data(withJSONObject: mobj)
        try broadened.write(to: manifestURL)
        // thread the broadened hash through result + lock + a fresh audit commit so ONLY the
        // candidate-blob binding can catch it.
        let newFreezeSHA = SHA256.hash(data: broadened).map { String(format: "%02x", $0) }.joined()
        let resURL = broaden.root.appendingPathComponent(RWCPre14AuditResultV3.canonicalPath)
        var robj = try JSONSerialization.jsonObject(with: Data(contentsOf: resURL)) as! [String: Any]
        robj["freeze_manifest_sha256"] = newFreezeSHA
        let newResult = try JSONSerialization.data(withJSONObject: robj)
        try newResult.write(to: resURL)
        try sh(broaden.root, ["add", "-A"]); try sh(broaden.root, ["commit", "-q", "-m", "post-cand"])
        let newAudit = try sh(broaden.root, ["rev-parse", "HEAD"])
        let lockURL = broaden.root.appendingPathComponent(RWCPre14PassLockV4.lockRelPath)
        var lobj = try JSONSerialization.jsonObject(with: Data(contentsOf: lockURL)) as! [String: Any]
        lobj["freeze_manifest_sha256"] = newFreezeSHA
        lobj["audit_commit"] = newAudit
        lobj["audit_result_blob_sha256"] = SHA256.hash(data: newResult)
            .map { String(format: "%02x", $0) }.joined()
        try JSONSerialization.data(withJSONObject: lobj).write(to: lockURL)
        expectV5(broaden.root, { if case .candidateFreezeBlobMismatch = $0 { return true }; return false },
                 "post-candidate manifest broadening")

        // A18-F5: live one-byte drift (result+lock still agree on the OLD hash) → REFUSE at live.
        let drift = try makeFixtureV5()
        defer { try? FileManager.default.removeItem(at: drift.root) }
        let driftURL = drift.root.appendingPathComponent(
            RWCCorpusEntryVerifierV5.canonicalFreezeManifestPath)
        var driftRaw = try String(contentsOf: driftURL, encoding: .utf8)
        driftRaw += " "   // one byte drift (not committed)
        try driftRaw.write(to: driftURL, atomically: true, encoding: .utf8)
        expectV5(drift.root, { if case .carried(.freezeManifestHashMismatch) = $0 { return true }
                               return false }, "live one-byte drift")

        // A18-F4: tag-name mismatch (result says a different tag than the lock) → REFUSE.
        let tagMismatch = try makeFixtureV5(resultTagNameOverride: "fixture-r5-wrong-tag")
        defer { try? FileManager.default.removeItem(at: tagMismatch.root) }
        expectV5(tagMismatch.root, { if case .tagNameMismatch = $0 { return true }; return false },
                 "tag-name mismatch")

        // non-canonical R5 result path → REFUSE.
        let altPath = try makeFixtureV5(resultPathOverride: "docs/audit/fake_pass.json")
        defer { try? FileManager.default.removeItem(at: altPath.root) }
        expectV5(altPath.root, { if case .nonCanonicalAuditResultPath = $0 { return true }; return false },
                 "alternate result path")
        // committed FIX result → REFUSE.
        let fix = try makeFixtureV5(resultVerdict: "FIX_REQUIRED", counts: (2, 1, 3, 0, 1, 0))
        defer { try? FileManager.default.removeItem(at: fix.root) }
        expectV5(fix.root, { if case .auditVerdictNotPass = $0 { return true }; return false },
                 "FIX result")
        // PASS with open findings → REFUSE.
        let open = try makeFixtureV5(counts: (2, 1, 3, 0, 0, 2))
        defer { try? FileManager.default.removeItem(at: open.root) }
        expectV5(open.root, { if case .auditFindingsOpen = $0 { return true }; return false },
                 "open findings")

        // scoped allowance works (auditor evidence file in the allowance root).
        let allowed = try makeFixtureV5()
        defer { try? FileManager.default.removeItem(at: allowed.root) }
        try write(allowed.root, "code/auditevidence/AUDIT19_Probe.swift", "// auditor evidence\n")
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV5.verify(repoRoot: allowed.root))
        // production AUDIT file (outside the scoped root) → surface drift REFUSE.
        let prodAudit = try makeFixtureV5()
        defer { try? FileManager.default.removeItem(at: prodAudit.root) }
        try write(prodAudit.root, "code/AUDITBackdoor.swift", "// backdoor\n")
        expectV5(prodAudit.root, { if case .carried(.surfaceSetMismatch) = $0 { return true }
                                   return false }, "production AUDIT file")
    }

    // MARK: 10 — R4-result supersession truth + zero-data/phase truths + docs pins

    func testR5_ZeroData_PhaseTruths_DocsPins_ProductionLocks() throws {
        // R5 result MUST NOT exist; PASS lock MUST NOT exist; production reviewer root ABSENT.
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: repoRoot().appendingPathComponent(RWCPre14AuditResultV3.canonicalPath).path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: repoRoot().appendingPathComponent(RWCPre14PassLockV4.lockRelPath).path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: repoRoot().appendingPathComponent(RWCReviewerTrustRootV1.canonicalInstancePath).path))

        // R4 result supersession truth: present + FIX_REQUIRED 0/2/2; absent in the R4 candidate tree.
        let r4 = try RWCPre14AuditResultV2.parse(data: try Data(contentsOf:
            repoRoot().appendingPathComponent(RWCPre14AuditResultV2.canonicalPath)))
        XCTAssertEqual(r4.candidateCommit, "206783074e2167afa0689aa7873a917076089749")
        XCTAssertEqual(r4.verdict, "FIX_REQUIRED")
        XCTAssertEqual(r4.criticalCount, 0); XCTAssertEqual(r4.highCount, 2); XCTAssertEqual(r4.mediumCount, 2)
        let r4Show = Process()
        r4Show.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        r4Show.arguments = ["git", "-C", repoRoot().path, "cat-file", "-e",
                            "206783074e2167afa0689aa7873a917076089749:" + RWCPre14AuditResultV2.canonicalPath]
        try r4Show.run(); r4Show.waitUntilExit()
        XCTAssertNotEqual(r4Show.terminationStatus, 0, "R4 candidate must NOT contain the audit result")

        // gates V6 load-bearing pins.
        let gates = try read("docs/calibration/preregistration/RWC_FROZEN_GATES_V6.yaml")
        for pin in ["rwc-frozen-gates-v6", "SIGNATURE AUTHENTICITY != TRUST AUTHORITY",
                    "FAIL CLOSED", "candidate", "RWC-REVIEWER-ROOT-ONBOARDING",
                    "rwc-corpus", "candidateFreezeBlobMismatch", "tagNameMismatch",
                    "CORRUPTION DETECTION", "RWCSourceManifestLawV2", "CARRIED CLEAN"] {
            XCTAssertTrue(gates.contains(pin), pin)
        }
        // trust-root schema + onboarding law pins.
        let trustSchema = try read("docs/calibration/preregistration/RWC_REVIEWER_TRUST_ROOT_SCHEMA_V1.yaml")
        for pin in ["rwc-reviewer-trust-root-v1", "docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json",
                    "NEVER stored", "NO instance exists"] {
            XCTAssertTrue(trustSchema.contains(pin), pin)
        }
        let onboarding = try read("docs/calibration/preregistration/RWC_REVIEWER_ROOT_ONBOARDING_LAW_V1.md")
        for pin in ["RWC-REVIEWER-ROOT-ONBOARDING", "FIRST-ASSET BLOCKER",
                    "NO ACTUAL ONBOARDING HAS OCCURRED", "public key only"] {
            XCTAssertTrue(onboarding.contains(pin), pin)
        }
        // schema V3 + lock schema V4 pins.
        let resSchema = try read("docs/calibration/preregistration/RWC_PRE14_AUDIT_RESULT_SCHEMA_V3.yaml")
        XCTAssertTrue(resSchema.contains("rwc-pre14-audit-result-v3"))
        XCTAssertTrue(resSchema.contains("docs/audit/RWC_PRE14_R5_AUDIT_RESULT.json"))
        XCTAssertTrue(resSchema.contains("candidate_freeze_blob_law"))
        let lockSchema = try read("docs/calibration/preregistration/RWC_PRE14_PASS_LOCK_SCHEMA_V4.yaml")
        XCTAssertTrue(lockSchema.contains("rwc-pre14-pass-lock-v4"))
        XCTAssertTrue(lockSchema.contains("CANDIDATE-FREEZE-BLOB"))
        XCTAssertTrue(lockSchema.contains("TAG-NAME cross-check"))
        // change ledger pins.
        let ledger = try read("docs/calibration/preregistration/RWC_PREREGISTRATION_R5_CHANGE_LEDGER.md")
        XCTAssertTrue(ledger.contains("NO REAL DATA USED"))
        XCTAssertTrue(ledger.contains("NO production reviewer root was fabricated"))

        // master manifest R5 keys + intact pins/zeros.
        let masterData = try Data(contentsOf: repoRoot().appendingPathComponent(
            "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml"))
        let master = try JSONSerialization.jsonObject(with: masterData) as! [String: Any]
        XCTAssertEqual(master["r5_status"] as! String, "BUILDER_COMPLETE")
        XCTAssertEqual(master["r5_candidate_generation"] as! String, "R5")
        XCTAssertEqual(master["r4_status"] as! String, "BUILDER_COMPLETE")
        XCTAssertEqual(master["candidate_generation"] as! String, "R1")
        XCTAssertNotNil(master["audit18"])
        for field in ["corpus_count", "annotator_count", "real_fit_count", "heldout_open_count"] {
            XCTAssertEqual(master[field] as! Int, 0, field)
        }
        XCTAssertEqual(master["data_visibility"] as! Bool, false)

        // production locks.
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims)
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59)
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0)
        XCTAssertFalse(RealWorldCalibrationExecutorV1.preregistrationAuditPassed)
        // calibration V4 + IRR 0.60 carried (no churn).
        XCTAssertEqual(RWCCalibrationMethodologyV4.frozenNullSims, 9999)
        XCTAssertEqual(RWCCalibrationMethodologyV4.frozenOverallN, 800)
        XCTAssertEqual(RWCCalibrationMethodologyV4.irrOrdinalKappaThreshold, 0.60)
    }

    // MARK: 11 — freeze V6 anchor law census (validates once the manifest exists, post-anchor)

    func testR5_FreezeV6_AnchorConsistency_HashCensus() throws {
        let manifestRel = "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V6.yaml"
        guard FileManager.default.fileExists(atPath: repoRoot().appendingPathComponent(manifestRel).path) else {
            throw XCTSkip("pre-anchor build state: freeze manifest v6 is generated AFTER the R5 anchor")
        }
        let data = try Data(contentsOf: repoRoot().appendingPathComponent(manifestRel))
        let m = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(m["freeze_version"] as! String, "rwc-preregistration-freeze-v6")
        XCTAssertEqual(m["governing_control_plane_lock"] as! String,
                       "2c345b64c720f965b68ec5ee699e1b71fecf0003")
        let anchor = m["methodology_anchor_commit"] as! String
        let rules = m["surface_rules"] as! [String: Any]
        let allowances = rules["post_audit_allowances"] as! [[String: Any]]
        XCTAssertEqual(allowances.count, 1)
        XCTAssertEqual(allowances[0]["root"] as! String, "packages/GuardianKit/Tests/GuardianCoreTests")
        XCTAssertEqual(allowances[0]["filename_prefix"] as! String, "AUDIT")
        let hashExempt = Set(rules["hash_exempt"] as! [String])
        let artifacts = m["artifacts"] as! [[String: Any]]
        var paths = Set<String>()
        var pathToSHA: [String: String] = [:]
        for a in artifacts {
            let path = a["path"] as! String, sha = a["sha256"] as! String
            XCTAssertTrue(paths.insert(path).inserted, "duplicate: \(path)")
            pathToSHA[path] = sha
            if hashExempt.contains(path) { continue }
            let d = try Data(contentsOf: repoRoot().appendingPathComponent(path))
            XCTAssertEqual(SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined(), sha, path)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = ["git", "-C", repoRoot().path, "diff", "--name-only",
                           anchor + "..HEAD", "--", path]
            let pipe = Pipe(); p.standardOutput = pipe
            try p.run(); p.waitUntilExit()
            let diff = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
                .trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertEqual(diff, "", "post-anchor drift: \(path)")
        }
        let lines = pathToSHA.keys.sorted().map { "\($0):\(pathToSHA[$0]!)" }.joined(separator: "\n")
        let digest = SHA256.hash(data: Data(lines.utf8)).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digest, m["frozen_inventory_digest"] as! String)
        for must in ["packages/GuardianKit/Sources/GuardianCore/RWCRightsV5.swift",
                     "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV3.swift",
                     "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV5.swift",
                     "packages/GuardianKit/Sources/RWCAcquisition/RWCAcquisitionReceiptStoreV1.swift",
                     "docs/calibration/preregistration/RWC_FROZEN_GATES_V6.yaml",
                     "docs/calibration/preregistration/RWC_PRE14_AUDIT_RESULT_SCHEMA_V3.yaml",
                     "docs/calibration/preregistration/RWC_PRE14_PASS_LOCK_SCHEMA_V4.yaml",
                     "docs/calibration/preregistration/RWC_REVIEWER_TRUST_ROOT_SCHEMA_V1.yaml",
                     "packages/GuardianKit/Package.swift"] {
            XCTAssertTrue(paths.contains(must), must)
        }
        let anc = Process()
        anc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        anc.arguments = ["git", "-C", repoRoot().path, "merge-base", "--is-ancestor", anchor, "HEAD"]
        try anc.run(); anc.waitUntilExit()
        XCTAssertEqual(anc.terminationStatus, 0)
    }
}
