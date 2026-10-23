import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
import RWCAcquisition

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC PRE-14 R4 BUILDER TESTS — fresh family for the AUDIT17 remediation (5 HIGH + 5 MEDIUM +
// F11/F12 LOW). Zero AUDIT17 inversions; superseded V3/V1 surfaces keep their defect pins.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class RWCPreregistrationR4Tests: XCTestCase {

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
        FileManager.default.temporaryDirectory.appendingPathComponent("r4-\(tag)-\(UUID().uuidString)")
    }

    // synthetic reviewer key (explicitly SYNTHETIC FIXTURE; never a real reviewer)
    private let reviewerKey = Curve25519.Signing.PrivateKey()
    private var reviewerPubHex: String {
        reviewerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
    }

    private func registry(status: RWCAuthorizedReviewerV1.Status = .active,
                          role: String = "RIGHTS_REVIEW",
                          validFrom: String = "2026-01-01",
                          validUntil: String? = "2027-12-31",
                          keyHex: String? = nil) -> RWCAuthorizedReviewerRegistryV1 {
        var reg = RWCAuthorizedReviewerRegistryV1()
        reg.enroll(RWCAuthorizedReviewerV1(
            reviewerID: "rwc-reviewer-r4test01", publicKeyRawHex: keyHex ?? reviewerPubHex,
            status: status, role: role, scope: "rwc-corpus",
            validFrom: d3(validFrom), validUntil: validUntil.map { d3($0) }))
        return reg
    }

    private func grant(id: String = "rwc-grant-r4aa0001", digestSeed: String = "proof-a",
                       allowed: [String] = ["training", "evaluation"], prohibited: [String] = [],
                       effective: String = "2026-08-01", expiry: String? = "2027-08-01",
                       review: String = "rwc-review-r4rv0001") -> RWCLegalGrantIdentityV1 {
        RWCLegalGrantIdentityV1(grantID: id, grantRevision: 1, evidenceDigest: shaHex(digestSeed),
                                evidencePointer: "rwc-rights-ref-r4p0001", rightsHolder: "licensor-a",
                                allowedUse: allowed, prohibitedUse: prohibited,
                                effectiveDate: d3(effective), expiryDate: expiry.map { d3($0) },
                                reviewDecision: "APPROVED", reviewRecordID: review)
    }

    private func signedReview(for g: RWCLegalGrantIdentityV1,
                              source: RWCSourceAuthorizationV1,
                              reviewerID: String = "rwc-reviewer-r4test01",
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

    private func verifiedGrant(_ g: RWCLegalGrantIdentityV1,
                               source: RWCSourceAuthorizationV1) throws -> RWCVerifiedRightsGrantV2 {
        try RWCRightsReviewAuthorityV2.verify(signedReview: try signedReview(for: g, source: source),
                                              grant: g, registry: registry())
    }

    private let exactSource = RWCSourceAuthorizationV1.exactSource("rwc-source-ref-r4src0001")

    private func request(assetID: String = "rwc-asset-r4aaaa01",
                         sourceClass: RWCSourceClassV1 = .licensedRightsClear,
                         source: String = "rwc-source-ref-r4src0001",
                         owner: String = "gen8", use: RWCUseV1 = .training,
                         session: String = "rwc-acq-r4session0000001",
                         manifestSources: [String]? = nil,
                         checksum: String? = nil) -> RWCAcquisitionRequestV1 {
        RWCAcquisitionRequestV1(assetID: assetID, sourceClass: sourceClass, sourceReference: source,
                                owner: owner, intendedUse: use, sessionID: session,
                                manifestSources: manifestSources, trustedExpectedChecksum: checksum)
    }

    private func expectAuth(_ expected: RWCRightsAuthorityErrorV2, _ body: () throws -> Void,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try body(), file: file, line: line) { e in
            XCTAssertEqual(e as? RWCRightsAuthorityErrorV2, expected, file: file, line: line)
        }
    }

    // MARK: 1 — discipline

    func testR4_Discipline_AUDIT17Frozen_ZeroInversions_SingleSupersession() throws {
        func sha(_ rel: String) throws -> String {
            let d = try Data(contentsOf: repoRoot().appendingPathComponent(rel))
            return SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
        }
        let frozen = [
            ("AUDIT17_RWCPre14R3ReauditProbes", "b423adcd1146ffa9bf685d9f016a7e003c1d2b30318f19e9d15aff6ea0301bef"),
            ("AUDIT17_VerifierAuthorityProbes", "901e1f762f81700cd8bd0d630b613ed1d8074e3cde2a667f1229c80493a432c1"),
            ("AUDIT17_AcquisitionRunnerProbes", "cc06649629dac53e2edd7cb7c2c810d4c936830c44b737f1777649a21511bb1a"),
        ]
        for (name, expected) in frozen {
            XCTAssertEqual(try sha("docs/audit/\(name)_ORIGINAL_LOCKED.swift.txt"), expected, name)
            XCTAssertEqual(try sha("packages/GuardianKit/Tests/GuardianCoreTests/\(name).swift"),
                           expected, "\(name) must be byte-identical (zero AUDIT17 inversions)")
        }
        XCTAssertEqual(try sha("docs/audit/RWC_PRE14_R3_AUDIT_RESULT.json"),
                       "2ebd7f8f608946701197df772f3454bffeb934157c3d46e484fffaef2b821061",
                       "R3 machine result is immutable FIX_REQUIRED history")
        let lock = try read("docs/audit/AUDIT17_R4_INVERSION_LOCK.md")
        XCTAssertTrue(lock.contains("ZERO AUDIT17 INVERSIONS DECLARED"))
        XCTAssertTrue(lock.contains("EXACTLY ONE HISTORICAL BUILDER-FILE SUPERSESSION"))
    }

    // MARK: 2 — A17-F1: review authority matrix (§64)

    func testR4_F1_ReviewAuthority_Matrix() throws {
        let g = grant()
        // lawful synthetic authorized reviewer → verified grant V2
        XCTAssertNoThrow(try verifiedGrant(g, source: exactSource))
        // caller-authored APPROVED with NO valid signature → REFUSE
        expectAuth(.signatureInvalid) {
            _ = try RWCRightsReviewAuthorityV2.verify(
                signedReview: try self.signedReview(for: g, source: self.exactSource, tamperSignature: true),
                grant: g, registry: self.registry())
        }
        // signature from an UNKNOWN key (not the registered one) → REFUSE
        expectAuth(.signatureInvalid) {
            _ = try RWCRightsReviewAuthorityV2.verify(
                signedReview: try self.signedReview(for: g, source: self.exactSource,
                                                    key: Curve25519.Signing.PrivateKey()),
                grant: g, registry: self.registry())
        }
        // unknown reviewer ID → REFUSE
        expectAuth(.unknownReviewer) {
            _ = try RWCRightsReviewAuthorityV2.verify(
                signedReview: try self.signedReview(for: g, source: self.exactSource,
                                                    reviewerID: "rwc-reviewer-nobody01"),
                grant: g, registry: self.registry())
        }
        // revoked / suspended reviewer → REFUSE
        expectAuth(.reviewerNotActive(status: "REVOKED")) {
            _ = try RWCRightsReviewAuthorityV2.verify(
                signedReview: try self.signedReview(for: g, source: self.exactSource),
                grant: g, registry: self.registry(status: .revoked))
        }
        // wrong role → REFUSE
        expectAuth(.reviewerRoleUnauthorized) {
            _ = try RWCRightsReviewAuthorityV2.verify(
                signedReview: try self.signedReview(for: g, source: self.exactSource),
                grant: g, registry: self.registry(role: "ANNOTATION"))
        }
        // review date outside reviewer validity (incl. the AUDIT17 1500-01-01 case) → REFUSE
        expectAuth(.reviewDateOutsideReviewerValidity) {
            _ = try RWCRightsReviewAuthorityV2.verify(
                signedReview: try self.signedReview(for: g, source: self.exactSource,
                                                    reviewDate: "1500-01-01"),
                grant: g, registry: self.registry())
        }
        // payload/grant mismatch (wrong digest) → REFUSE
        expectAuth(.payloadFieldMismatch(field: "evidenceDigest")) {
            let other = self.grant(digestSeed: "proof-b")
            _ = try RWCRightsReviewAuthorityV2.verify(
                signedReview: try self.signedReview(for: self.grant(), source: self.exactSource),
                grant: other, registry: self.registry())
        }
        // decision not APPROVED → REFUSE
        expectAuth(.decisionNotApproved) {
            _ = try RWCRightsReviewAuthorityV2.verify(
                signedReview: try self.signedReview(for: g, source: self.exactSource,
                                                    decision: "PENDING"),
                grant: g, registry: self.registry())
        }
        // wrong registered key in registry → REFUSE
        expectAuth(.signatureInvalid) {
            let otherKey = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation
                .map { String(format: "%02x", $0) }.joined()
            _ = try RWCRightsReviewAuthorityV2.verify(
                signedReview: try self.signedReview(for: g, source: self.exactSource),
                grant: g, registry: self.registry(keyHex: otherKey))
        }
        // EMPTY registry (production default): fail-closed
        expectAuth(.unknownReviewer) {
            _ = try RWCRightsReviewAuthorityV2.verify(
                signedReview: try self.signedReview(for: g, source: self.exactSource),
                grant: g, registry: RWCAuthorizedReviewerRegistryV1())
        }
    }

    // MARK: 3 — A17-F10: source binding

    func testR4_F10_SourceBinding_ExactAndManifest() throws {
        let g = grant()
        let vg = try verifiedGrant(g, source: exactSource)
        // exact source: covered
        XCTAssertNoThrow(try RWCPreAcquisitionEvaluatorV1.authorize(
            request: request(), verifiedGrant: vg, transactionDate: d3("2026-10-01")))
        // different source: refused BEFORE fetch
        expectAuth(.sourceNotAuthorized) {
            _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                request: self.request(source: "rwc-source-ref-r4other99"), verifiedGrant: vg,
                transactionDate: self.d3("2026-10-01"))
        }
        // manifest mode: member covered, non-member refused, forged manifest refused
        let sources = ["rwc-source-ref-r4m00001", "rwc-source-ref-r4m00002"]
        let manifest = RWCSourceAuthorizationV1.sourceManifest(
            digest: RWCSourceAuthorizationV1.manifestDigest(ofSources: sources))
        let vgM = try verifiedGrant(grant(id: "rwc-grant-r4mm0002", review: "rwc-review-r4rv0002"),
                                    source: manifest)
        XCTAssertNoThrow(try RWCPreAcquisitionEvaluatorV1.authorize(
            request: request(source: "rwc-source-ref-r4m00002", manifestSources: sources),
            verifiedGrant: vgM, transactionDate: d3("2026-10-01")))
        expectAuth(.sourceNotAuthorized) {
            _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                request: self.request(source: "rwc-source-ref-r4evil01", manifestSources: sources),
                verifiedGrant: vgM, transactionDate: self.d3("2026-10-01"))
        }
        expectAuth(.sourceNotAuthorized) {   // caller-supplied list not matching the signed digest
            _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                request: self.request(source: "rwc-source-ref-r4evil01",
                                      manifestSources: sources + ["rwc-source-ref-r4evil01"]),
                verifiedGrant: vgM, transactionDate: self.d3("2026-10-01"))
        }
    }

    // MARK: 4 — A17-F2/F5: pre-fetch spy matrix (§65)

    private final class SpyAcquirer: RWCAssetAcquirerV1 {
        var calls = 0
        let payload: Data
        init(_ payload: Data = Data("r4-synthetic-bytes".utf8)) { self.payload = payload }
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

    /// Mints a REAL V4 proof from a lawful synthetic verifier fixture (type law preserved).
    private func mintProofV4() throws -> (RWCVerifiedCorpusEntryV4, URL) {
        let fx = try makeFixtureV4()
        return (try RWCCorpusEntryVerifierV4.verify(repoRoot: fx.root), fx.root)
    }

    func testR4_F2F5_PreFetchSpyMatrix_FetchCountZero() throws {
        let (proof, fxRoot) = try mintProofV4()
        defer { try? FileManager.default.removeItem(at: fxRoot) }
        let qRoot = tempDir("q")
        try FileManager.default.createDirectory(at: qRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: qRoot) }
        let runner = RWCCorpusAcquisitionRunnerV2(quarantineRoot: qRoot)
        let dir = tempDir("led")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        defer { store.closeStore() }
        let corpus = FixtureCorpusStore()
        let vg = try verifiedGrant(grant(), source: exactSource)

        func attempt(_ req: RWCAcquisitionRequestV1, _ vgX: RWCVerifiedRightsGrantV2,
                     txDate: String = "2026-10-01", label: String,
                     file: StaticString = #filePath, line: UInt = #line) {
            let spy = SpyAcquirer()
            XCTAssertThrowsError(try runner.acquire(proof: proof, request: req, verifiedGrant: vgX,
                                                    rightsStore: store, corpusStore: corpus,
                                                    acquirer: spy, clock: clock(txDate)),
                                 label, file: file, line: line)
            XCTAssertEqual(spy.calls, 0, "FETCH MUST BE 0: \(label)", file: file, line: line)
        }
        // scraped / ineligible source class
        attempt(request(sourceClass: .refusedScraped), vg, label: "scraped class")
        // invalid sourceReference grammar (raw URL)
        attempt(request(source: "https://evil.example"), vg, label: "raw URL source")
        // source outside grant authorization
        attempt(request(source: "rwc-source-ref-r4other99"), vg, label: "unbound source")
        // grant not yet effective
        attempt(request(), vg, txDate: "2026-07-01", label: "not yet effective")
        // expired grant
        attempt(request(), vg, txDate: "2027-09-01", label: "expired grant")
        // evaluation-only grant requested for training
        let evalOnly = try verifiedGrant(grant(id: "rwc-grant-r4ev0003", allowed: ["evaluation"],
                                               prohibited: ["training"], review: "rwc-review-r4rv0003"),
                                         source: exactSource)
        attempt(request(use: .training), evalOnly, label: "training on evaluation-only")
        // training-only grant requested for evaluation
        let trainOnly = try verifiedGrant(grant(id: "rwc-grant-r4tr0004", allowed: ["training"],
                                                prohibited: ["evaluation"], review: "rwc-review-r4rv0004"),
                                          source: exactSource)
        attempt(request(use: .evaluation), trainOnly, label: "evaluation on training-only")
        // EMPTY allowed use (authorizes nothing)
        let emptyUse = try verifiedGrant(grant(id: "rwc-grant-r4em0005", allowed: [],
                                               review: "rwc-review-r4rv0005"), source: exactSource)
        attempt(request(), emptyUse, label: "empty allowedUse")
        // invalid owner
        attempt(request(owner: "   "), vg, label: "blank owner")
        // invalid asset ID
        attempt(request(assetID: "../evil"), vg, label: "invalid asset ID")
        // invalid session grammar (path traversal attempt is unrepresentable)
        attempt(request(session: "rwc-acq-../../escape"), vg, label: "session traversal")
        attempt(request(session: "short"), vg, label: "session grammar")
        // nothing registered, nothing promoted, no quarantine left behind
        XCTAssertEqual(store.eventCount, 0)
        XCTAssertTrue(corpus.promoted.isEmpty)
        XCTAssertEqual((try? FileManager.default.contentsOfDirectory(atPath: qRoot.path))?.count ?? 0, 0)
    }

    // MARK: 5 — A17-F6/F8/F9: lawful flow, hash-after-fetch, single date, duplicate session

    func testR4_F6F8F9_LawfulFlow_HashAfterFetch_SingleDate_DuplicateSession() throws {
        let (proof, fxRoot) = try mintProofV4()
        defer { try? FileManager.default.removeItem(at: fxRoot) }
        let qRoot = tempDir("q2")
        try FileManager.default.createDirectory(at: qRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: qRoot) }
        let runner = RWCCorpusAcquisitionRunnerV2(quarantineRoot: qRoot)
        let dir = tempDir("led2")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        defer { store.closeStore() }
        let corpus = FixtureCorpusStore()
        let vg = try verifiedGrant(grant(), source: exactSource)
        // NO content hash is required pre-fetch (A17-F8): request carries none.
        let spy = SpyAcquirer()
        // SPLIT CLOCK (A17-F9): a clock whose date would change on a second call — the runner must
        // consult it exactly once, so event date == receipt date deterministically.
        final class SplitClock: RWCRightsClockV3, @unchecked Sendable {
            var calls = 0
            func today() -> RWCDateV3 {
                calls += 1
                return try! RWCDateV3.parse(calls == 1 ? "2026-10-01" : "2026-10-02", field: "clock")
            }
        }
        let split = SplitClock()
        let receipt = try runner.acquire(proof: proof, request: request(), verifiedGrant: vg,
                                         rightsStore: store, corpusStore: corpus, acquirer: spy,
                                         clock: split)
        XCTAssertEqual(split.calls, 1, "clock consulted EXACTLY once")
        XCTAssertEqual(receipt.transactionDate, "2026-10-01")
        XCTAssertEqual(store.events.last?.recordedDate, "2026-10-01")
        XCTAssertEqual(receipt.intendedUse, .training)
        XCTAssertEqual(receipt.reviewerID, "rwc-reviewer-r4test01")
        // content hash derived from acquired bytes
        let expectedHash = RWCCorpusAcquisitionRunnerV2.sha256Hex(spy.payload)
        XCTAssertEqual(receipt.contentHash, expectedHash)
        XCTAssertEqual(store.record(for: "rwc-asset-r4aaaa01")?.contentHash, expectedHash)
        XCTAssertEqual(corpus.promoted["rwc-asset-r4aaaa01"], spy.payload)
        XCTAssertEqual(spy.calls, 1)
        // duplicate session (even for a different asset) → typed refusal BEFORE fetch
        try FileManager.default.createDirectory(
            at: qRoot.appendingPathComponent("rwc-quarantine-rwc-acq-r4dupsession00001"),
            withIntermediateDirectories: true)
        let spy2 = SpyAcquirer()
        XCTAssertThrowsError(try runner.acquire(
            proof: proof,
            request: request(assetID: "rwc-asset-r4bbbb02", session: "rwc-acq-r4dupsession00001"),
            verifiedGrant: vg, rightsStore: store, corpusStore: corpus, acquirer: spy2,
            clock: clock("2026-10-02"))) { e in
            XCTAssertEqual(e as? RWCAcquisitionErrorV2, .duplicateSession)
        }
        XCTAssertEqual(spy2.calls, 0)
        // trusted optional checksum: mismatch refuses AFTER fetch, destroys quarantine, no commit
        let spy3 = SpyAcquirer()
        XCTAssertThrowsError(try runner.acquire(
            proof: proof,
            request: request(assetID: "rwc-asset-r4cccc03", session: "rwc-acq-r4session0000003",
                             checksum: shaHex("different-bytes")),
            verifiedGrant: vg, rightsStore: store, corpusStore: corpus, acquirer: spy3,
            clock: clock("2026-10-02"))) { e in
            guard case .trustedChecksumMismatch = e as? RWCAcquisitionErrorV2 else { return XCTFail("\(e)") }
        }
        XCTAssertNil(store.record(for: "rwc-asset-r4cccc03"))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: qRoot.appendingPathComponent("rwc-quarantine-rwc-acq-r4session0000003").path))
    }

    // MARK: 6 — A17-F7: reconciliation V2 (duplicate events, same-hash, revoked, crash)

    func testR4_F7_ReconciliationV2_IdentityBound() throws {
        let (proof, fxRoot) = try mintProofV4()
        defer { try? FileManager.default.removeItem(at: fxRoot) }
        let qRoot = tempDir("q3")
        try FileManager.default.createDirectory(at: qRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: qRoot) }
        let runner = RWCCorpusAcquisitionRunnerV2(quarantineRoot: qRoot)
        let dir = tempDir("led3")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        defer { store.closeStore() }
        let corpus = FixtureCorpusStore()
        let payload = Data("r4-synthetic-bytes".utf8)
        // crash between rights commit and promote: RIGHTS_COMMITTED session survives
        corpus.failPromote = true
        let vg = try verifiedGrant(grant(), source: exactSource)
        XCTAssertThrowsError(try runner.acquire(proof: proof, request: request(), verifiedGrant: vg,
                                                rightsStore: store, corpusStore: corpus,
                                                acquirer: SpyAcquirer(payload), clock: clock("2026-10-01")))
        XCTAssertEqual(store.eventCount, 1)
        corpus.failPromote = false
        let report = try runner.reconcile(rightsStore: store, corpusStore: corpus)
        XCTAssertEqual(report.recoveredSessions, ["rwc-acq-r4session0000001"])
        XCTAssertEqual(corpus.promoted["rwc-asset-r4aaaa01"], payload)
        // SAME-HASH second asset: identity-bound by session+asset, never cross-bound
        let g2 = grant(id: "rwc-grant-r4gg0006", review: "rwc-review-r4rv0006")
        let vg2 = try RWCRightsReviewAuthorityV2.verify(
            signedReview: try signedReview(for: g2,
                source: .exactSource("rwc-source-ref-r4src0002")),
            grant: g2, registry: registry())
        corpus.failPromote = true
        XCTAssertThrowsError(try runner.acquire(
            proof: proof,
            request: request(assetID: "rwc-asset-r4bbbb02", source: "rwc-source-ref-r4src0002",
                             session: "rwc-acq-r4session0000007"),
            verifiedGrant: vg2, rightsStore: store, corpusStore: corpus,
            acquirer: SpyAcquirer(payload), clock: clock("2026-10-02")))
        corpus.failPromote = false
        let report2 = try runner.reconcile(rightsStore: store, corpusStore: corpus)
        XCTAssertEqual(report2.recoveredSessions, ["rwc-acq-r4session0000007"])
        XCTAssertEqual(corpus.promoted["rwc-asset-r4bbbb02"], payload)
        // duplicate reconcile run: nothing double-promoted (each active asset once; stored respected)
        let report3 = try runner.reconcile(rightsStore: store, corpusStore: corpus)
        XCTAssertTrue(report3.recoveredSessions.isEmpty)
        XCTAssertTrue(report3.registeredButUnpromoted.isEmpty)
        // REVOKED asset session: never promoted, destroyed deterministically
        try store.revoke(assetID: "rwc-asset-r4bbbb02", clock: clock("2026-10-03"))
        corpus.promoted.removeValue(forKey: "rwc-asset-r4bbbb02")
        let revokedDir = qRoot.appendingPathComponent("rwc-quarantine-rwc-acq-r4revoked0000001")
        try FileManager.default.createDirectory(at: revokedDir, withIntermediateDirectories: true)
        var meta = RWCCorpusAcquisitionRunnerV2.SessionMetadataV1(
            sessionID: "rwc-acq-r4revoked0000001", assetID: "rwc-asset-r4bbbb02",
            grantID: g2.grantID, grantRevision: 1, reviewRecordID: g2.reviewRecordID,
            reviewerID: "rwc-reviewer-r4test01", sourceReference: "rwc-source-ref-r4src0002",
            intendedUse: "training", transactionDate: "2026-10-02",
            passCandidate: proof.candidateCommit, state: .rightsCommitted,
            contentHash: RWCCorpusAcquisitionRunnerV2.sha256Hex(payload))
        try meta.write(to: revokedDir)
        try payload.write(to: revokedDir.appendingPathComponent("payload"))
        let report4 = try runner.reconcile(rightsStore: store, corpusStore: corpus)
        XCTAssertEqual(report4.destroyedRevokedSessions, ["rwc-acq-r4revoked0000001"])
        XCTAssertNil(corpus.promoted["rwc-asset-r4bbbb02"], "revoked asset NEVER promoted")
        // tampered metadata → orphan destroyed
        let tamperedDir = qRoot.appendingPathComponent("rwc-quarantine-rwc-acq-r4tampered000001")
        try FileManager.default.createDirectory(at: tamperedDir, withIntermediateDirectories: true)
        try "garbage\nnothash\n".write(
            to: tamperedDir.appendingPathComponent(RWCCorpusAcquisitionRunnerV2.metadataName),
            atomically: true, encoding: .utf8)
        let report5 = try runner.reconcile(rightsStore: store, corpusStore: corpus)
        XCTAssertEqual(report5.destroyedOrphanSessions, ["rwc-quarantine-rwc-acq-r4tampered000001"])
        meta.state = .promoted   // silence unused-mutation warning paths
        _ = meta
    }

    // MARK: 7 — verifier V4 fixtures: A17-F3/F4/F11/F12 + lock V3 identity matrix

    private struct FixtureV4 {
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

    private func makeFixtureV4(resultVerdict: String = "PASS",
                               counts: (Int, Int, Int, Int, Int, Int) = (2, 1, 3, 0, 0, 0),
                               resultPathOverride: String? = nil) throws -> FixtureV4 {
        let root = tempDir("vfx4")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try sh(root, ["init", "-q"])
        try write(root, "seed.txt", "governing base\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "governing"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV4.governingTagName, "-m", "governing"])
        let gates = "{\"gates\": \"fixture-v5\"}\n"
        let code = "// RWCFixtureLaw\nlet law = 4\n"
        try write(root, "docs/prereg/gates.yaml", gates)
        try write(root, "code/method/RWCFixtureLaw.swift", code)
        try write(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
                  "{\"immutable_a\": \"x\", \"data_visibility\": false, \"corpus_count\": 0, \"annotator_count\": 0, \"real_fit_count\": 0, \"heldout_open_count\": 0}\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try sh(root, ["rev-parse", "HEAD"])
        let manifestPath = RWCCorpusEntryVerifierV4.canonicalFreezeManifestPath
        let artifacts: [(String, String)] = [("docs/prereg/gates.yaml", shaHex(gates)),
                                             ("code/method/RWCFixtureLaw.swift", shaHex(code))]
        let invDigest = shaHex(artifacts.map { "\($0.0):\($0.1)" }.sorted().joined(separator: "\n"))
        let manifest = """
        {"freeze_version": "rwc-preregistration-freeze-v5", "methodology_anchor_commit": "\(anchor)",
         "governing_control_plane_lock": "\(governing)", "frozen_inventory_digest": "\(invDigest)",
         "artifacts": [\(artifacts.map { "{\"path\": \"\($0.0)\", \"sha256\": \"\($0.1)\"}" }.joined(separator: ", "))],
         "surface_rules": {"governed_roots": ["docs/prereg", "code"],
           "post_anchor_allowed": [],
           "post_audit_allowances": [{"root": "code/auditevidence", "filename_prefix": "AUDIT"}],
           "hash_exempt": []}}
        """
        try write(root, manifestPath, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", "fixture-r4-candidate", "-m", "candidate"])
        let tagObject = try sh(root, ["rev-parse", "refs/tags/fixture-r4-candidate"])
        let resultPath = resultPathOverride ?? RWCPre14AuditResultV2.canonicalPath
        let result = """
        {"result_version": "rwc-pre14-audit-result-v2", "verdict": "\(resultVerdict)",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "fixture-r4-candidate",
         "candidate_tag_object_sha": "\(tagObject)", "methodology_anchor_commit": "\(anchor)",
         "freeze_manifest_path": "\(manifestPath)", "freeze_manifest_sha256": "\(shaHex(manifest))",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "audit_probe_family": "AUDIT18_FIXTURE", "baseline_count": \(counts.0),
         "fresh_probe_count": \(counts.1), "total_count": \(counts.2),
         "critical_count": \(counts.3), "high_count": \(counts.4), "medium_count": \(counts.5),
         "auditor_declaration": "SYNTHETIC FIXTURE independent audit"}
        """
        try write(root, resultPath, result)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit"])
        let audit = try sh(root, ["rev-parse", "HEAD"])
        let lock = """
        {"lock_version": "rwc-pre14-pass-lock-v3", "audit_result_path": "\(resultPath)",
         "audit_result_blob_sha256": "\(shaHex(result))", "audit_commit": "\(audit)",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "fixture-r4-candidate",
         "candidate_tag_object_sha": "\(tagObject)", "freeze_manifest_path": "\(manifestPath)",
         "freeze_manifest_sha256": "\(shaHex(manifest))", "methodology_anchor_commit": "\(anchor)",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "corpus_entry_authorized": true, "verdict": "\(resultVerdict)"}
        """
        try write(root, RWCPre14PassLockV3.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
        return FixtureV4(root: root, governing: governing, anchor: anchor, candidate: candidate,
                         audit: audit, tagObject: tagObject, manifestSHA: shaHex(manifest),
                         resultSHA: shaHex(result))
    }

    private func expectV4(_ root: URL, _ check: (RWCCorpusEntryErrorV4) -> Bool, _ label: String,
                          file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV4.verify(repoRoot: root), label,
                             file: file, line: line) { e in
            guard let err = e as? RWCCorpusEntryErrorV4, check(err) else {
                return XCTFail("\(label): \(e)", file: file, line: line)
            }
        }
    }

    func testR4_F3F4F11F12_VerifierV4_Authority() throws {
        // real repo: fail-closed (no lock)
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV4.verify(repoRoot: repoRoot())) { e in
            XCTAssertEqual(e as? RWCCorpusEntryErrorV4, .lockMissing)
        }
        // lawful fixture mints
        let good = try makeFixtureV4()
        defer { try? FileManager.default.removeItem(at: good.root) }
        let proof = try RWCCorpusEntryVerifierV4.verify(repoRoot: good.root)
        XCTAssertEqual(proof.candidateCommit, good.candidate)
        // A17-F4: NON-CANONICAL result path (even with a perfectly valid PASS result there) → REFUSE
        let altPath = try makeFixtureV4(resultPathOverride: "docs/audit/fake_pass.json")
        defer { try? FileManager.default.removeItem(at: altPath.root) }
        expectV4(altPath.root, { if case .nonCanonicalAuditResultPath = $0 { return true }; return false },
                 "alternate result path")
        // committed FIX result + PASS lock decoration → REFUSE
        let fix = try makeFixtureV4(resultVerdict: "FIX_REQUIRED", counts: (2, 1, 3, 0, 1, 0))
        defer { try? FileManager.default.removeItem(at: fix.root) }
        expectV4(fix.root, { if case .auditVerdictNotPass = $0 { return true }; return false },
                 "FIX result")
        // PASS with open findings → REFUSE
        let open = try makeFixtureV4(counts: (2, 1, 3, 0, 0, 2))
        defer { try? FileManager.default.removeItem(at: open.root) }
        expectV4(open.root, { if case .auditFindingsOpen = $0 { return true }; return false },
                 "open findings")
        // A17-F12: inconsistent counts → REFUSE at parse
        let inconsistent = try makeFixtureV4(counts: (1000, 0, 900, 0, 0, 0))
        defer { try? FileManager.default.removeItem(at: inconsistent.root) }
        expectV4(inconsistent.root, { if case .auditCountInconsistent = $0 { return true }; return false },
                 "baseline+fresh != total")
        // A17-F11: string/float/negative counts → REFUSE (patch the live+committed result via new commit)
        let badCounts = try makeFixtureV4()
        defer { try? FileManager.default.removeItem(at: badCounts.root) }
        let resultURL = badCounts.root.appendingPathComponent(RWCPre14AuditResultV2.canonicalPath)
        var obj = try JSONSerialization.jsonObject(with: Data(contentsOf: resultURL)) as! [String: Any]
        obj["baseline_count"] = "-100"
        let newResult = try JSONSerialization.data(withJSONObject: obj)
        try newResult.write(to: resultURL)
        try sh(badCounts.root, ["add", "-A"]); try sh(badCounts.root, ["commit", "-q", "-m", "tamper"])
        let newAudit = try sh(badCounts.root, ["rev-parse", "HEAD"])
        let lockURL = badCounts.root.appendingPathComponent(RWCPre14PassLockV3.lockRelPath)
        var lockObj = try JSONSerialization.jsonObject(with: Data(contentsOf: lockURL)) as! [String: Any]
        lockObj["audit_commit"] = newAudit
        lockObj["audit_result_blob_sha256"] = RWCCorpusAcquisitionRunnerV2.sha256Hex(newResult)
        try JSONSerialization.data(withJSONObject: lockObj).write(to: lockURL)
        expectV4(badCounts.root, { if case .auditCountInvalid(field: "baseline_count") = $0 { return true }
                                   return false }, "string count")
        // A17-F3: PRODUCTION AUDIT-prefix file → surface drift (NO allowance outside scoped root)
        let prodAudit = try makeFixtureV4()
        defer { try? FileManager.default.removeItem(at: prodAudit.root) }
        try write(prodAudit.root, "code/AUDITBackdoor.swift", "// backdoor\n")
        expectV4(prodAudit.root, { if case .carried(.surfaceSetMismatch) = $0 { return true }
                                   return false }, "production AUDIT file")
        // nested production AUDIT file → refused
        let nested = try makeFixtureV4()
        defer { try? FileManager.default.removeItem(at: nested.root) }
        try write(nested.root, "code/hidden/AUDITX.swift", "// nested\n")
        expectV4(nested.root, { if case .carried(.surfaceSetMismatch) = $0 { return true }
                                return false }, "nested AUDIT file")
        // scoped allowance root: AUDIT file IS allowed there (auditor evidence)
        let allowed = try makeFixtureV4()
        defer { try? FileManager.default.removeItem(at: allowed.root) }
        try write(allowed.root, "code/auditevidence/AUDIT18_Probe.swift", "// auditor evidence\n")
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV4.verify(repoRoot: allowed.root))
        // non-AUDIT file in the allowance root: still drift (prefix law inside the scope)
        let wrongName = try makeFixtureV4()
        defer { try? FileManager.default.removeItem(at: wrongName.root) }
        try write(wrongName.root, "code/auditevidence/Helper.swift", "// helper\n")
        expectV4(wrongName.root, { if case .carried(.surfaceSetMismatch) = $0 { return true }
                                   return false }, "non-AUDIT in allowance root")
        // wrong governing / anchor / tag-object: V3-core carried refusals
        let badGov = try makeFixtureV4()
        defer { try? FileManager.default.removeItem(at: badGov.root) }
        var gl = try JSONSerialization.jsonObject(with: Data(contentsOf:
            badGov.root.appendingPathComponent(RWCPre14PassLockV3.lockRelPath))) as! [String: Any]
        gl["governing_control_plane_lock"] = String(repeating: "ab", count: 20)
        try JSONSerialization.data(withJSONObject: gl).write(
            to: badGov.root.appendingPathComponent(RWCPre14PassLockV3.lockRelPath))
        expectV4(badGov.root, { err in
            if case .auditTargetMismatch(field: "governing_control_plane_lock") = err { return true }
            return false
        }, "wrong governing")
    }

    // MARK: 8 — zero data, phase truths, docs pins, production locks

    func testR4_ZeroData_PhaseTruths_DocsPins_ProductionLocks() throws {
        // R4/AUDIT18 result MUST NOT exist; PASS lock MUST NOT exist (mandate §71/§72)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: repoRoot().appendingPathComponent(RWCPre14AuditResultV2.canonicalPath).path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: repoRoot().appendingPathComponent(RWCPre14PassLockV3.lockRelPath).path))
        // R3 result remains FIX_REQUIRED history (bytes pinned in discipline test)
        let r3 = try RWCPre14AuditResultV1.parse(data: try Data(contentsOf:
            repoRoot().appendingPathComponent(RWCPre14AuditResultV1.canonicalPath)))
        XCTAssertEqual(r3.verdict, "FIX_REQUIRED")
        // docs pins
        let gates = try read("docs/calibration/preregistration/RWC_FROZEN_GATES_V5.yaml")
        for pin in ["rwc-frozen-gates-v5", "REVIEW DATA is separated from REVIEW AUTHORITY",
                    "Ed25519", "EMPTY and fail-closed", "RWCSourceAuthorizationV1",
                    "fetch count == 0", "computed AFTER authorized quarantine acquisition",
                    "EXACTLY ONCE", "rwc-acq-[a-z0-9]{16,64}", "SESSION + ASSET",
                    "docs/audit/RWC_PRE14_R4_AUDIT_RESULT.json", "PATH-SCOPED",
                    "NO allowance exists for Sources/GuardianCore",
                    "CARRIED UNCHANGED"] {
            XCTAssertTrue(gates.contains(pin), pin)
        }
        let schema2 = try read("docs/calibration/preregistration/RWC_PRE14_AUDIT_RESULT_SCHEMA_V2.yaml")
        for pin in ["STRICT ENUM", "baseline_count + fresh_probe_count == total_count",
                    "strict non-negative integer", "ONLY the independent AUDIT18 auditor"] {
            XCTAssertTrue(schema2.contains(pin), pin)
        }
        let lockSchema = try read("docs/calibration/preregistration/RWC_PRE14_PASS_LOCK_SCHEMA_V3.yaml")
        for pin in ["rwc-pre14-pass-lock-v3", "MUST equal the canonical docs/audit/RWC_PRE14_R4_AUDIT_RESULT.json",
                    "lockMissing"] {
            XCTAssertTrue(lockSchema.contains(pin), pin)
        }
        let ledger = try read("docs/calibration/preregistration/RWC_PREREGISTRATION_R4_CHANGE_LEDGER.md")
        XCTAssertTrue(ledger.contains("NO REAL DATA USED"))
        XCTAssertTrue(ledger.contains("CARRIED CLEAN"))
        // master manifest R4 keys + intact pins/zeros
        let masterData = try Data(contentsOf: repoRoot().appendingPathComponent(
            "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml"))
        let master = try JSONSerialization.jsonObject(with: masterData) as! [String: Any]
        XCTAssertEqual(master["r4_status"] as! String, "BUILDER_COMPLETE")
        XCTAssertEqual(master["candidate_generation"] as! String, "R1")
        XCTAssertEqual(master["r3_status"] as! String, "BUILDER_COMPLETE")
        for field in ["corpus_count", "annotator_count", "real_fit_count", "heldout_open_count"] {
            XCTAssertEqual(master[field] as! Int, 0, field)
        }
        XCTAssertEqual(master["data_visibility"] as! Bool, false)
        // production locks
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims)
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59)
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0)
        XCTAssertFalse(RealWorldCalibrationExecutorV1.preregistrationAuditPassed)
        // calibration V4 + IRR 0.60 carried (no churn)
        XCTAssertEqual(RWCCalibrationMethodologyV4.frozenNullSims, 9999)
        XCTAssertEqual(RWCCalibrationMethodologyV4.frozenOverallN, 800)
        XCTAssertEqual(RWCCalibrationMethodologyV4.irrOrdinalKappaThreshold, 0.60)
    }

    // MARK: 9 — freeze V5 anchor law (validates once the manifest exists, post-anchor)

    func testR4_FreezeV5_AnchorConsistency_HashCensus() throws {
        let manifestRel = "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V5.yaml"
        guard FileManager.default.fileExists(atPath: repoRoot().appendingPathComponent(manifestRel).path) else {
            throw XCTSkip("pre-anchor build state: freeze manifest v5 is generated AFTER the R4 anchor")
        }
        let data = try Data(contentsOf: repoRoot().appendingPathComponent(manifestRel))
        let m = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(m["freeze_version"] as! String, "rwc-preregistration-freeze-v5")
        XCTAssertEqual(m["governing_control_plane_lock"] as! String,
                       "2c345b64c720f965b68ec5ee699e1b71fecf0003")
        let anchor = m["methodology_anchor_commit"] as! String
        let rules = m["surface_rules"] as! [String: Any]
        let allowances = rules["post_audit_allowances"] as! [[String: Any]]
        XCTAssertEqual(allowances.count, 1)
        XCTAssertEqual(allowances[0]["root"] as! String, "packages/GuardianKit/Tests/GuardianCoreTests")
        XCTAssertEqual(allowances[0]["filename_prefix"] as! String, "AUDIT")
        XCTAssertNil(rules["post_audit_allowed_prefixes"], "global prefix law must be GONE")
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
        for must in ["packages/GuardianKit/Sources/GuardianCore/RWCRightsV4.swift",
                     "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV2.swift",
                     "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV4.swift",
                     "docs/calibration/preregistration/RWC_FROZEN_GATES_V5.yaml",
                     "docs/calibration/preregistration/RWC_PRE14_AUDIT_RESULT_SCHEMA_V2.yaml",
                     "docs/calibration/preregistration/RWC_PRE14_PASS_LOCK_SCHEMA_V3.yaml",
                     "packages/GuardianKit/Package.swift"] {
            XCTAssertTrue(paths.contains(must), must)
        }
        let anc = Process()
        anc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        anc.arguments = ["git", "-C", repoRoot().path, "merge-base", "--is-ancestor", anchor, "HEAD"]
        try anc.run(); anc.waitUntilExit()
        XCTAssertEqual(anc.terminationStatus, 0)
        XCTAssertFalse(String(data: data, encoding: .utf8)!.contains("candidate_tag_object"))
    }
}
