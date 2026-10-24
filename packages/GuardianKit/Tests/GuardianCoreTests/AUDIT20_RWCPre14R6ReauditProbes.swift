#if os(macOS)
import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
import RWCAcquisition

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT20 — INDEPENDENT RWC PRE-14 R6 SECURITY RE-AUDIT PROBES.
//
// Family: AUDIT20_RWC_PRE14_R6_REAUDIT.  Fresh, independent red-team probes written by the AUDIT20
// auditor (NOT the R6 builder).  These are ADVERSARIAL: several of them DEMONSTRATE DEFECTS and assert
// the (insecure) observed behavior so the exploit is preserved as reproducible evidence.  Each such
// probe is labeled EXPLOIT and its XCTAssert encodes the ACTUAL measured behavior, with a comment
// stating what a SECURE implementation would have done instead.  Control probes labeled CONTROL
// assert the lawful refusal.
//
// Why @testable + RWCAcquisition:  the @testable import of GuardianCore is required ONLY to drive the
// INTERNAL synthetic trust-root factory so the auditor can mint a LAWFUL V6 grant (the legitimate
// capability a real onboarded reviewer would hold); the ATTACK itself then uses ONLY PUBLIC API
// (store V4 register / authorizeAcquisition, runner V4 reconcileV4).  RWCVerifiedCorpusEntryV5 cannot
// be minted here except through the full RWCCorpusEntryVerifierV5.verify (fileprivate init) — that is
// precisely the point: A20-P1 shows the V5 PASS proof is NOT required to write the ledger
// authorization that reconcileV4 trusts.
//
// ZERO-DATA: synthetic fixtures only; all mutation in throwaway temp dirs.  No production root, no
// real grant/media, no PASS lock, no operational root created by these probes.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT20_RWCPre14R6ReauditProbes: XCTestCase {

    // MARK: fixtures (lawful synthetic rooted chain → lawful V6 grant; same construction the builder uses)

    private func shaHex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func shaHex(_ d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }
    private func d3(_ s: String) -> RWCDateV3 { try! RWCDateV3.parse(s, field: "a20") }
    private func clock(_ s: String) -> RWCFixedClockV3 { try! RWCFixedClockV3(s) }
    private func tempDir(_ tag: String) -> URL {
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("a20-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    private final class SpyAcquirer: RWCAssetAcquirerV1 {
        var calls = 0
        let payload: Data
        init(_ payload: Data = Data("a20-synthetic-bytes".utf8)) { self.payload = payload }
        func fetch(sourceReference: String) throws -> Data { calls += 1; return payload }
    }
    private final class FixtureCorpusStore: RWCCorpusStoreV1 {
        var promoted: [String: Data] = [:]
        func promote(assetID: String, contentHash: String, payload: Data) throws { promoted[assetID] = payload }
        func storedAssetIDs() throws -> [String] { Array(promoted.keys) }
    }

    private struct Chain {
        let root: RWCVerifiedReviewerTrustRootV2
        let rootPriv: Curve25519.Signing.PrivateKey
        let currentness: RWCReviewerRegistryCurrentnessStoreV1
        let registry: RWCVerifiedReviewerRegistryV2
        let reviewerKey: Curve25519.Signing.PrivateKey
        let doc: RWCReviewerRegistryDocumentV2
    }
    private func signedDoc(rootID: String, rootPriv: Curve25519.Signing.PrivateKey, reviewerHex: String,
                           status: String = "ACTIVE", scope: RWCReviewerScopeV1 = .corpus,
                           role: String = "RIGHTS_REVIEW", registryRevision: Int = 1,
                           previousDigest: String? = nil) -> RWCReviewerRegistryDocumentV2 {
        let entry = RWCReviewerRegistryEntryV1(
            reviewerID: "rwc-reviewer-a20ctrl1", publicKeyRawHex: reviewerHex, status: status,
            role: role, scope: scope.rawValue, validFrom: d3("2026-01-01"),
            validUntil: d3("2027-12-31"), revision: 1)
        var doc = RWCReviewerRegistryDocumentV2(
            registryVersion: RWCReviewerRegistryDocumentV2.schemaVersion, registryRevision: registryRevision,
            rootID: rootID, createdAt: d3("2026-02-01"),
            previousRegistryDigest: previousDigest ?? RWCReviewerRegistryDocumentV2.genesisPreviousDigest,
            reviewers: [entry], signatureHex: "")
        let sig = try! rootPriv.signature(for: doc.canonicalPayloadBytes)
        doc = RWCReviewerRegistryDocumentV2(
            registryVersion: doc.registryVersion, registryRevision: doc.registryRevision, rootID: doc.rootID,
            createdAt: doc.createdAt, previousRegistryDigest: doc.previousRegistryDigest,
            reviewers: doc.reviewers, signatureHex: sig.map { String(format: "%02x", $0) }.joined())
        return doc
    }
    private func chain(dir: URL, status: String = "ACTIVE", scope: RWCReviewerScopeV1 = .corpus,
                       role: String = "RIGHTS_REVIEW") throws -> Chain {
        let r = RWCReviewerTrustRootLoaderV2.makeSyntheticTestRoot()
        let reviewerKey = Curve25519.Signing.PrivateKey()
        let reviewerHex = reviewerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let doc = signedDoc(rootID: r.root.rootID, rootPriv: r.privateKey, reviewerHex: reviewerHex,
                            status: status, scope: scope, role: role)
        let currentness = try RWCReviewerRegistryCurrentnessStoreV1.create(directory: dir)
        try currentness.advance(rootID: r.root.rootID, revision: 1, documentDigest: doc.documentDigest,
                                recordedDate: "2026-02-01")
        let reg = try RWCReviewerRegistryVerifierV2.verifyCurrent(document: doc, trustRoot: r.root,
                                                                  currentness: currentness, previousVerified: nil)
        return Chain(root: r.root, rootPriv: r.privateKey, currentness: currentness, registry: reg,
                     reviewerKey: reviewerKey, doc: doc)
    }
    private func grant(id: String = "rwc-grant-a20aa001", review: String = "rwc-review-a20rv01",
                       allowed: [String] = ["training", "evaluation"]) -> RWCLegalGrantIdentityV1 {
        RWCLegalGrantIdentityV1(grantID: id, grantRevision: 1, evidenceDigest: shaHex("proof-\(id)"),
            evidencePointer: "rwc-rights-ref-a20p001", rightsHolder: "licensor-a20",
            allowedUse: allowed, prohibitedUse: [], effectiveDate: d3("2026-08-01"),
            expiryDate: d3("2027-08-01"), reviewDecision: "APPROVED", reviewRecordID: review)
    }
    private func signedReview(_ g: RWCLegalGrantIdentityV1, source: RWCSourceAuthorizationV1,
                              key: Curve25519.Signing.PrivateKey, reviewerID: String = "rwc-reviewer-a20ctrl1"
    ) throws -> RWCSignedRightsReviewV1 {
        var r = RWCSignedRightsReviewV1(
            reviewRecordID: g.reviewRecordID, reviewerID: reviewerID, grantID: g.grantID,
            grantRevision: g.grantRevision, evidenceDigest: g.evidenceDigest, rightsHolder: g.rightsHolder,
            sourceAuthorization: source, allowedUse: g.allowedUse, prohibitedUse: g.prohibitedUse,
            effectiveDate: g.effectiveDate, expiryDate: g.expiryDate, decision: "APPROVED",
            reviewDate: d3("2026-08-15"), signatureHex: "")
        let sig = try key.signature(for: r.canonicalPayloadBytes)
        r = RWCSignedRightsReviewV1(
            reviewRecordID: r.reviewRecordID, reviewerID: r.reviewerID, grantID: r.grantID,
            grantRevision: r.grantRevision, evidenceDigest: r.evidenceDigest, rightsHolder: r.rightsHolder,
            sourceAuthorization: r.sourceAuthorization, allowedUse: r.allowedUse, prohibitedUse: r.prohibitedUse,
            effectiveDate: r.effectiveDate, expiryDate: r.expiryDate, decision: r.decision,
            reviewDate: r.reviewDate, signatureHex: sig.map { String(format: "%02x", $0) }.joined())
        return r
    }
    private func grantV6(_ g: RWCLegalGrantIdentityV1, source: RWCSourceAuthorizationV1, _ c: Chain
    ) throws -> RWCVerifiedRightsGrantV6 {
        try RWCRightsReviewAuthorityV6.verify(signedReview: try signedReview(g, source: source, key: c.reviewerKey),
                                              grant: g, verifiedRegistry: c.registry)
    }

    /// Build a LAWFUL V6 grant + a rights record bound to it, with a given content hash/source.
    private func lawfulGrantAndRecord(_ c: Chain, assetID: String, source: String, contentHash: String,
                                      g: RWCLegalGrantIdentityV1
    ) throws -> (RWCVerifiedRightsGrantV6, RWCAssetRightsRecordV3) {
        let vg = try grantV6(g, source: .exactSource(source), c)
        let rec = RWCAssetRightsRecordV3(
            assetID: assetID, sourceClass: .licensedRightsClear, sourceReference: source, owner: "gen8",
            grant: g, acquisitionDate: d3("2026-08-20"), contentHash: contentHash,
            provenanceChain: [source])
        return (vg, rec)
    }

    /// A SYNTHETIC (NON-PASS) authority token minted via the `package` init — used ONLY to witness the
    /// STRUCTURED shape of the R7 lawful write and to drive the sealed gate's refusal logic in isolation
    /// (the test target is in-package, so it CAN mint; an external consumer canNOT — its init is
    /// `package`). The identity digests are synthetic placeholders, never a real PASS proof. The lawful
    /// path mints the token from a real RWCCorpusEntryVerifierV6 PASS inside RunnerV5.
    private func syntheticToken(session: String, asset: String, source: String, use: String,
                                g: RWCLegalGrantIdentityV1, _ c: Chain) -> RWCAcquisitionAuthorityTokenV1 {
        RWCAcquisitionAuthorityTokenV1(
            candidateCommit: shaHex("cand"), candidateTagObjectSHA: shaHex("tag"),
            auditCommit: shaHex("audit"), auditResultBlobSHA256: shaHex("blob"),
            methodologyAnchorCommit: shaHex("anchor"), freezeManifestSHA256: shaHex("freeze"),
            frozenInventoryDigest: shaHex("inv"),
            sessionID: session, assetID: asset, sourceReference: source, intendedUseToken: use,
            grantID: g.grantID, grantRevision: g.grantRevision,
            currentRegistryRootID: c.registry.rootID, currentRegistryRevision: c.registry.registryRevision,
            currentRegistryDocumentDigest: c.registry.documentDigest)
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // A20-P1 — DIRECT PUBLIC-API BYPASS OF THE PRE-14 PASS GATE.
    //
    // Hypothesis: a caller holding a LEGITIMATELY MINTED V6 grant can promote a corpus asset through
    // the PUBLIC store V4 + runner V4 API — register + authorizeAcquisition (with FABRICATED
    // candidateCommit/auditResultBlobSHA256 scalars) + hand-built quarantine + reconcileV4 — WITHOUT
    // ever minting an RWCVerifiedCorpusEntryV5 PASS proof and WITHOUT calling RunnerV4.acquire.
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test_A20_P1_01_DirectAuthorizeReconcile_Promotes_WithoutV5PassProof() throws {
        // R7 INVERSION (declared in AUDIT20_R7_INVERSION_LOCK.md, lock commit 8e4437f): OLD R6 truth —
        // direct `register → authorizeAcquisition(fabricated scalars) → reconcileV4` PROMOTED without any
        // V5 PASS proof (preserved at git show 5185101:packages/GuardianKit/Tests/GuardianCoreTests/
        // AUDIT20_RWCPre14R6ReauditProbes.swift). NEW R7 truth — the scalar `authorizeAcquisition` writer
        // on store V4 is `public → package` sealed; the lawful write `authorizeAcquisitionV2` on store V5
        // REQUIRES an RWCAcquisitionAuthorityTokenV1 that only RunnerV5 can mint (after verifier-V6 PASS +
        // evaluator + currentness). A direct caller cannot mint the token, so reconcileV5 promotes NOTHING:
        // the corpus is empty and the unauthorized quarantine session is destroyed.
        //
        // OLD EXPLOIT (negative history, now UNREACHABLE for an external caller): the V4 scalar path
        //   store.authorizeAcquisition(sessionID:…, candidateCommit: "deadbeef…", auditResultBlobSHA256:
        //   "ffff…", …) wrote a ledger-resident authorization record from FABRICATED scalars with NO V5
        //   PASS proof, and reconcileV4 then promoted it. In R7 that method is `package`-sealed and the
        //   promotion authority (reconcileV5) trusts ONLY a token-backed RWCAcquisitionAuthorizationRecordV2.
        let c = try chain(dir: tempDir("p1-cur")); defer { c.currentness.closeStore() }
        let assetID = "rwc-asset-a20p1a01"
        let source = "rwc-source-ref-a20src01"
        let session = "rwc-acq-a20p1session0001"
        let payload = Data("hostile-corpus-bytes-no-pass-proof".utf8)
        let contentHash = RWCCorpusAcquisitionRunnerV5.sha256Hex(payload)
        let g = grant()
        let (vg, rec) = try lawfulGrantAndRecord(c, assetID: assetID, source: source,
                                                 contentHash: contentHash, g: g)

        // The R7 lawful store is V5. A direct caller can still PUBLIC-register the lawful V6 grant …
        let ledgerDir = tempDir("p1-ledger")
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: ledgerDir)
        defer { store.closeStore() }
        try store.register(rec, verifiedGrant: vg, clock: clock("2026-08-21"))
        // … but there is NO public scalar writer to produce a ledger-resident authorization: the ONLY
        // writer is authorizeAcquisitionV2(token:), and the token's init is `package` — an external caller
        // cannot construct one, and only RunnerV5 (after a verifier-V6 PASS) mints it in-package. No
        // authorization record is written here, so NO session is promotable.
        XCTAssertNil(store.authorizationRecord(forSession: session),
                     "R7: no ledger-resident authorization exists without a RunnerV5-minted token")

        // Hand-build a quarantine directory matching the session (as the old exploit did).
        let quarantineRoot = tempDir("p1-quar")
        let runner = RWCCorpusAcquisitionRunnerV5(quarantineRoot: quarantineRoot)
        let qdir = quarantineRoot.appendingPathComponent("rwc-quarantine-\(session)", isDirectory: true)
        try FileManager.default.createDirectory(at: qdir, withIntermediateDirectories: false)
        try payload.write(to: qdir.appendingPathComponent("payload"))

        // reconcileV5 — the R7 promotion authority. Without a token-backed authorization record it
        // promotes NOTHING and destroys the unauthorized session.
        let corpus = FixtureCorpusStore()
        let receipts = try RWCAcquisitionReceiptStoreV2(directory: tempDir("p1-rcpt"))
        defer { receipts.closeStore() }
        let report = try runner.reconcileV5(rightsStore: store, corpusStore: corpus, receiptStore: receipts)

        // MEASURED R7 BEHAVIOR (REFUSAL): nothing promoted; corpus empty; session destroyed-unauthorized.
        XCTAssertFalse(report.recoveredSessions.contains(session),
                       "R7 A20-P1: reconcileV5 refused to promote a session with no token-backed authorization")
        XCTAssertNil(corpus.promoted[assetID],
                     "R7 A20-P1: no corpus asset promoted without a V6 PASS proof / RunnerV5-minted token")
        XCTAssertTrue(corpus.promoted.isEmpty, "R7 A20-P1: corpus is empty")
        XCTAssertTrue(report.destroyedUnauthorizedSessions.contains(session),
                      "R7 A20-P1: the unauthorized quarantine session was destroyed")
        // The PRE-14 methodology gate (the V6 proof, bound into the token) is now the ONLY promotion path.
    }

    func test_A20_P1_02_NoV5ProofType_ReachableFromPublicAPI_Control() throws {
        // R7 INVERSION (declared in AUDIT20_R7_INVERSION_LOCK.md, lock commit 8e4437f): OLD R6 truth —
        // this control documented that store V4's scalar `authorizeAcquisition` signature named ONLY
        // free-form scalars (candidateCommit / auditResultBlobSHA256), never the structured V5 PASS proof
        // (preserved at git show 5185101:packages/GuardianKit/Tests/GuardianCoreTests/
        // AUDIT20_RWCPre14R6ReauditProbes.swift). NEW R7 truth — the lawful write names the STRUCTURED
        // proof object RWCAcquisitionAuthorityTokenV1 (carrying the full V6 PASS-proof identity +
        // evaluator-validated facts + current-registry witness), not scalars.
        //
        // OLD EXPLOIT (negative history): the P1 promotion occurred with only scalars because
        // authorizeAcquisition(…candidateCommit:auditResultBlobSHA256:…) accepted them verbatim. That
        // method is now `package`-sealed; the only ledger-write path is authorizeAcquisitionV2(token:).
        //
        // COMPILE-TIME FACT asserted structurally: minting an authority token with only the proof
        // identity + facts + registry witness (NOT scalars) is the shape of the lawful write. We build a
        // synthetic token to witness that the write's authority parameter is the structured token type.
        let c = try chain(dir: tempDir("p1b-cur")); defer { c.currentness.closeStore() }
        let g = grant(id: "rwc-grant-a20p1b01", review: "rwc-review-a20p1b1")
        let token = syntheticToken(session: "rwc-acq-a20p1bsession01", asset: "rwc-asset-a20p1b01",
                                   source: "rwc-source-ref-a20srcp1b", use: "training", g: g, c)
        // The token names STRUCTURED proof identity (not free-form scalars): the candidate/tag/audit/
        // anchor/freeze/inventory PASS-proof identity plus the evaluator facts and the registry witness.
        XCTAssertEqual(token.grantID, g.grantID,
                       "documented: authorizeAcquisitionV2 names RWCAcquisitionAuthorityTokenV1 (structured proof), not scalars")
        XCTAssertFalse(token.candidateCommit.isEmpty)
        XCTAssertFalse(token.currentRegistryDocumentDigest.isEmpty)
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // A20-P2 — STALE V6 GRANT AFTER REVIEWER REVOCATION (registry advanced to rev2 revoking reviewer).
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test_A20_P2_01_StaleGrant_AfterReviewerRevoked_StillRegistersAndAuthorizes() throws {
        // R7 INVERSION (declared in AUDIT20_R7_INVERSION_LOCK.md, lock commit 8e4437f): OLD R6 truth —
        // a stale V6 grant (reviewer REVOKED in the current rev2 registry) STILL registered and the
        // scalar authorizeAcquisition wrote an authorization bound to the STALE rev1 digest (preserved at
        // git show 5185101:packages/GuardianKit/Tests/GuardianCoreTests/AUDIT20_RWCPre14R6ReauditProbes
        // .swift). NEW R7 truth — authorizeAcquisitionV2 re-consults the CURRENT verified registry and
        // refuses with .reviewerNotCurrent: the grant's registryDocumentDigest (rev1) != the current head
        // (rev2), and the reviewer is no longer ACTIVE in the current head.
        //
        // OLD EXPLOIT (negative history): store V4 wrote authz.registryDocumentDigest == c.doc
        // .documentDigest (rev1) even after revocation, because the scalar writer never rechecked current
        // reviewer authority at authorization time.
        let c = try chain(dir: tempDir("p2-cur")); defer { c.currentness.closeStore() }
        let assetID = "rwc-asset-a20p2a01"
        let source = "rwc-source-ref-a20src02"
        let session = "rwc-acq-a20p2session0001"
        let payload = Data("stale-grant-bytes".utf8)
        let contentHash = RWCCorpusAcquisitionRunnerV5.sha256Hex(payload)
        let g = grant(id: "rwc-grant-a20p2001", review: "rwc-review-a20p201")
        // Mint V6 grant under revision-1 ACTIVE reviewer (the only mint moment).
        let (vg, rec) = try lawfulGrantAndRecord(c, assetID: assetID, source: source,
                                                 contentHash: contentHash, g: g)

        // Advance the governed registry to revision 2 REVOKING the reviewer, and verify the NEW current.
        let reviewerHex = c.reviewerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let rev2doc = signedDoc(rootID: c.root.rootID, rootPriv: c.rootPriv, reviewerHex: reviewerHex,
                                status: "REVOKED", registryRevision: 2, previousDigest: c.doc.documentDigest)
        try c.currentness.advance(rootID: c.root.rootID, revision: 2, documentDigest: rev2doc.documentDigest,
                                  recordedDate: "2026-09-01")
        let rev2 = try RWCReviewerRegistryVerifierV2.verifyCurrent(document: rev2doc, trustRoot: c.root,
                                                                   currentness: c.currentness,
                                                                   previousVerified: c.registry)

        let ledgerDir = tempDir("p2-ledger")
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: ledgerDir)
        defer { store.closeStore() }
        // Registration of the record itself still succeeds (register is grant-authenticity only) …
        try store.register(rec, verifiedGrant: vg, clock: clock("2026-09-02"))
        // … but the sealed authorization write refuses: the token carries the stale rev1 witness and the
        // CURRENT registry (rev2) no longer matches the grant's digest / lists the reviewer ACTIVE.
        let token = syntheticToken(session: session, asset: assetID, source: source, use: "training",
                                   g: g, c)   // token carries the STALE rev1 digest (from chain `c`)
        XCTAssertThrowsError(try store.authorizeAcquisitionV2(token: token, verifiedGrant: vg,
                                                              currentRegistry: rev2,
                                                              clock: clock("2026-09-02"))) { e in
            guard case .reviewerNotCurrent = (e as? RWCRightsLedgerErrorV5) else {
                return XCTFail("R7 A20-P2: expected reviewerNotCurrent, got \(e)")
            }
        }
        // MEASURED R7 BEHAVIOR (REFUSAL): no ledger-resident authorization is written against a reviewer
        // the current registry revoked.
        XCTAssertNil(store.authorizationRecord(forSession: session),
                     "R7 A20-P2: stale-grant authorization refused; nothing durable written")
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // A20-P3 — SOURCE / INTENDED-USE BYPASS THROUGH DIRECT LEDGER CALLS (skipping the evaluator V3).
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test_A20_P3_01_DirectAuthorize_ProhibitedUse_SkipsEvaluator() throws {
        // R7 INVERSION (declared in AUDIT20_R7_INVERSION_LOCK.md, lock commit 8e4437f): OLD R6 truth —
        // a grant allowing ONLY "evaluation" still yielded an authorization recording
        // intendedUse="training" because the scalar authorizeAcquisition never checked the grant's
        // allowedUse/prohibitedUse (preserved at git show 5185101:packages/GuardianKit/Tests/
        // GuardianCoreTests/AUDIT20_RWCPre14R6ReauditProbes.swift). NEW R7 truth — authorizeAcquisitionV2
        // validates the intended-use against grant.allowedUse / grant.prohibitedUse and refuses with
        // .useNotAuthorized (belt-and-suspenders over the evaluator).
        //
        // OLD EXPLOIT (negative history): store V4 wrote authz.intendedUse == "training" verbatim for a
        // grant whose allowedUse == ["evaluation"].
        let c = try chain(dir: tempDir("p3-cur")); defer { c.currentness.closeStore() }
        let assetID = "rwc-asset-a20p3a01"
        let source = "rwc-source-ref-a20src03"
        let session = "rwc-acq-a20p3session0001"
        let payload = Data("use-bypass-bytes".utf8)
        let contentHash = RWCCorpusAcquisitionRunnerV5.sha256Hex(payload)
        let g = grant(id: "rwc-grant-a20p3001", review: "rwc-review-a20p301", allowed: ["evaluation"])
        let (vg, rec) = try lawfulGrantAndRecord(c, assetID: assetID, source: source,
                                                 contentHash: contentHash, g: g)
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: tempDir("p3-ledger"))
        defer { store.closeStore() }
        try store.register(rec, verifiedGrant: vg, clock: clock("2026-08-21"))
        // Request intendedUse="training" though the grant prohibits training (allowed=["evaluation"]).
        let token = syntheticToken(session: session, asset: assetID, source: source, use: "training",
                                   g: g, c)
        XCTAssertThrowsError(try store.authorizeAcquisitionV2(token: token, verifiedGrant: vg,
                                                              currentRegistry: c.registry,
                                                              clock: clock("2026-08-21"))) { e in
            guard case .useNotAuthorized = (e as? RWCRightsLedgerErrorV5) else {
                return XCTFail("R7 A20-P3: expected useNotAuthorized, got \(e)")
            }
        }
        // MEASURED R7 BEHAVIOR (REFUSAL): the sealed write refuses a use the grant does not permit; no
        // ledger-resident authorization is produced.
        XCTAssertNil(store.authorizationRecord(forSession: session),
                     "R7 A20-P3: prohibited-use authorization refused; nothing durable written")
    }

    func test_A20_P3_02_DirectAuthorize_WrongSource_RefusedByRecordBinding_Control() throws {
        // CONTROL: authorizeAcquisition binds to the registered record's sourceReference; a mismatched
        // source is refused (authorization != rights record).  Source B cannot be smuggled past a
        // record registered for source A.
        let c = try chain(dir: tempDir("p3b-cur")); defer { c.currentness.closeStore() }
        let assetID = "rwc-asset-a20p3b01"
        let sourceA = "rwc-source-ref-a20srcaa"
        let sourceB = "rwc-source-ref-a20srcbb"
        let payload = Data("wrong-source-bytes".utf8)
        let contentHash = RWCCorpusAcquisitionRunnerV4.sha256Hex(payload)
        let g = grant(id: "rwc-grant-a20p3b01", review: "rwc-review-a20p3b1")
        let (vg, rec) = try lawfulGrantAndRecord(c, assetID: assetID, source: sourceA,
                                                 contentHash: contentHash, g: g)
        let store = try RWCAssetRightsLedgerStoreV4.create(directory: tempDir("p3b-ledger"))
        defer { store.closeStore() }
        try store.register(rec, verifiedGrant: vg, clock: clock("2026-08-21"))
        XCTAssertThrowsError(try store.authorizeAcquisition(
            sessionID: "rwc-acq-a20p3bsession001", assetID: assetID, contentHash: contentHash,
            intendedUse: .training, sourceReference: sourceB, verifiedGrant: vg,
            candidateCommit: "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
            auditResultBlobSHA256: String(repeating: "c", count: 64), clock: clock("2026-08-21"))) { e in
            XCTAssertEqual(e as? RWCRightsLedgerErrorV4,
                           .authorizationMalformed("authorization != rights record"))
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // A20-P6 — CURRENTNESS STORE: directory snapshot rollback by a hostile direct-disk writer.
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test_A20_P6_01_CurrentnessStore_DirectorySnapshotRollback_Accepted() throws {
        // Advance rev1 → rev2 (revoking the reviewer).  A hostile writer who snapshots the whole
        // currentness directory at rev1 and restores it after rev2 rolls the governed head BACK to rev1.
        // The store cannot detect a whole-directory rollback because the witness+journal are both
        // user-writable and internally consistent at rev1.
        let dir = tempDir("p6-cur")
        let snap = tempDir("p6-snap")
        let c = try chain(dir: dir)
        // snapshot the directory contents at rev1 (before advancing).
        for f in try FileManager.default.contentsOfDirectory(atPath: dir.path) {
            try? FileManager.default.copyItem(at: dir.appendingPathComponent(f),
                                              to: snap.appendingPathComponent(f))
        }
        let reviewerHex = c.reviewerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let rev2 = signedDoc(rootID: c.root.rootID, rootPriv: c.rootPriv, reviewerHex: reviewerHex,
                             status: "REVOKED", registryRevision: 2, previousDigest: c.doc.documentDigest)
        try c.currentness.advance(rootID: c.root.rootID, revision: 2, documentDigest: rev2.documentDigest,
                                  recordedDate: "2026-09-01")
        XCTAssertEqual(c.currentness.currentHead?.revision, 2)
        c.currentness.closeStore()
        // hostile rollback: restore the rev1 snapshot over the directory.
        for f in try FileManager.default.contentsOfDirectory(atPath: dir.path) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(f))
        }
        for f in try FileManager.default.contentsOfDirectory(atPath: snap.path) {
            try FileManager.default.copyItem(at: snap.appendingPathComponent(f),
                                             to: dir.appendingPathComponent(f))
        }
        let reopened = try RWCReviewerRegistryCurrentnessStoreV1.openExisting(directory: dir)
        defer { reopened.closeStore() }
        // MEASURED (EXPLOIT, but WITHIN the documented R-5-class disk threat model): the governed head
        // is silently back at rev1 — the revocation is erased.  openExisting accepts the rolled-back
        // directory because witness+journal are internally consistent.
        XCTAssertEqual(reopened.currentHead?.revision, 1,
                       "EXPLOIT A20-P6: whole-directory snapshot rollback silently reverted the governed head to rev1")
        XCTAssertEqual(reopened.currentHead?.documentDigest, c.doc.documentDigest)
        // This is a HOSTILE-DISK attack; the builder's R6 security design documents the SHA-256 chain as
        // rollback-DETECTING only against old-signed-file replay / accidental rewind, NOT against a
        // hostile writer with directory write access.  Classified accordingly in the AUDIT20 report.
    }

    func test_A20_P6_02_CurrentnessStore_PublicAPI_RollbackRefused_Control() throws {
        // CONTROL: through the PUBLIC API a rollback (advance revision 1 after reaching rev2) is refused.
        let c = try chain(dir: tempDir("p6b-cur")); defer { c.currentness.closeStore() }
        let reviewerHex = c.reviewerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let rev2 = signedDoc(rootID: c.root.rootID, rootPriv: c.rootPriv, reviewerHex: reviewerHex,
                             status: "REVOKED", registryRevision: 2, previousDigest: c.doc.documentDigest)
        try c.currentness.advance(rootID: c.root.rootID, revision: 2, documentDigest: rev2.documentDigest,
                                  recordedDate: "2026-09-01")
        XCTAssertThrowsError(try c.currentness.advance(rootID: c.root.rootID, revision: 1,
            documentDigest: c.doc.documentDigest, recordedDate: "2026-09-02")) { e in
            guard case .notMonotonic = (e as? RWCRegistryCurrentnessErrorV1) else {
                return XCTFail("expected notMonotonic, got \(e)")
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // R-5 — HOSTILE DIRECT-DISK LEDGER FORGERY: hand-author an acquisition-authorized journal event
    // and reopen the store.  Does a forged ledger authorization become a valid promotion precondition?
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test_A20_R5_01_HostileLedgerDiskForgery_AuthorizationAcceptedAfterReopen() throws {
        // Build a legitimate store with a registered record (so the record-consistency gate in
        // reconcileV4 passes), then CLOSE it and hand-author a forged "acquisition-authorized" event
        // directly into the journal + witness, recomputing the SHA-256 chain (all user-writable).
        let c = try chain(dir: tempDir("r5-cur")); defer { c.currentness.closeStore() }
        let assetID = "rwc-asset-a20r5a01"
        let source = "rwc-source-ref-a20src05"
        let session = "rwc-acq-a20r5session0001"
        let payload = Data("hostile-disk-forged-authorization".utf8)
        let contentHash = RWCCorpusAcquisitionRunnerV4.sha256Hex(payload)
        let g = grant(id: "rwc-grant-a20r5001", review: "rwc-review-a20r501")
        let (vg, rec) = try lawfulGrantAndRecord(c, assetID: assetID, source: source,
                                                 contentHash: contentHash, g: g)
        let ledgerDir = tempDir("r5-ledger")
        let store = try RWCAssetRightsLedgerStoreV4.create(directory: ledgerDir)
        try store.register(rec, verifiedGrant: vg, clock: clock("2026-08-21"))
        store.closeStore()

        // Reopen to learn the current head digest + event count (public, read-only facts).
        let probe = try RWCAssetRightsLedgerStoreV4.openExisting(directory: ledgerDir)
        let prevDigest = probe.headDigest
        let seq = probe.eventCount
        probe.closeStore()

        // Hand-author a forged acquisition-authorized event using the SAME canonical serialization the
        // store uses (replicated here by a hostile offline tool — all fields attacker-chosen except the
        // chain must be internally valid).  This mirrors RWCRightsEventV3 + RWCAcquisitionAuthorizationRecordV1.
        let authzJSON =
            "{\"v\":\"rwc-acq-authorization-v1\",\"session\":\"\(session)\",\"asset\":\"\(assetID)\"," +
            "\"hash\":\"\(contentHash)\",\"grant\":\"\(g.grantID)\",\"rev\":1," +
            "\"review\":\"\(g.reviewRecordID)\",\"reviewer\":\"rwc-reviewer-a20ctrl1\"," +
            "\"source\":\"\(source)\",\"use\":\"training\"," +
            "\"registryDoc\":\"\(c.doc.documentDigest)\",\"root\":\"\(c.root.rootID)\"," +
            "\"candidate\":\"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef\"," +
            "\"auditBlob\":\"\(String(repeating: "e", count: 64))\",\"tx\":\"2026-08-21\"}"
        let forgedEvent = RWCRightsEventV3(seq: seq, previousDigest: prevDigest, assetID: assetID,
                                           kind: "acquisition-authorized", recordPayloadJSON: authzJSON,
                                           recordedDate: "2026-08-21")
        let line = RWCAssetRightsLedgerStoreV4.journalLine(forgedEvent)
        let journalURL = ledgerDir.appendingPathComponent("rights-journal-v4.jsonl")
        let handle = try FileHandle(forWritingTo: journalURL)
        try handle.seekToEnd(); try handle.write(contentsOf: Data(line.utf8)); try handle.close()
        // forge the witness to match the new count+head (witness is a plain user-writable JSON file).
        let witnessJSON = "{\"v\":\"rwc-asset-rights-ledger-store-v4\",\"count\":\(seq + 1)," +
            "\"head\":\"\(forgedEvent.eventDigest)\"}\n"
        try Data(witnessJSON.utf8).write(to: ledgerDir.appendingPathComponent("rights-head-v4.json"))

        // Reopen: does the store accept the forged authorization as a real ledger-resident record?
        let reopened = try RWCAssetRightsLedgerStoreV4.openExisting(directory: ledgerDir)
        defer { reopened.closeStore() }
        // MEASURED (EXPLOIT, WITHIN the documented R-5 hostile-disk threat model): the forged
        // authorization is accepted — authorizationRecord(forSession:) returns the attacker's record.
        XCTAssertNotNil(reopened.authorizationRecord(forSession: session),
                        "EXPLOIT R-5: hostile direct-disk journal forgery produced an accepted ledger authorization")
        XCTAssertEqual(reopened.authorizationRecord(forSession: session)?.candidateCommit,
                       "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef")
        // Consequence: a hostile disk writer can manufacture the exact precondition reconcileV4 trusts.
        // The "unforgeable, ledger-resident authorization" claim holds ONLY through the public API; on
        // disk the SHA-256 chain is recomputable and therefore forgeable.  Documented R-5 residual —
        // classified in the AUDIT20 report against the actual deployment threat model.
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // R-6 — AUTHORIZE-TO-RECEIPT CRASH GAP: a crash AFTER the ledger authorization but BEFORE any
    // PREPARED receipt.  reconcileV4 promotes with NO durable receipt ever created.
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test_A20_R6_01_CrashBeforeReceipt_PromotesWithNoDurableReceipt() throws {
        // R7 INVERSION (declared in AUDIT20_R7_INVERSION_LOCK.md, lock commit 8e4437f): OLD R6 truth —
        // a crash AFTER the ledger authorization but BEFORE any PREPARED receipt caused reconcileV4 to
        // PROMOTE with NO durable receipt ever created, and the report surfaced NO deficit (preserved at
        // git show 5185101:packages/GuardianKit/Tests/GuardianCoreTests/
        // AUDIT20_RWCPre14R6ReauditProbes.swift). NEW R7 truth — reconcileV5 RECONSTRUCTS a durable
        // receipt from the authenticated authorization record V2 (receipt present + finalized) so a
        // promoted asset ALWAYS has a receipt; the silent no-receipt promotion is eliminated. (The
        // incomplete-proof-identity → explicit receiptDeficit path is proven in
        // RWCPreregistrationR7Tests.testR7_MAINSESSION_IncompleteProofIdentity_ReconcileV5_ReportsDeficit.)
        //
        // OLD EXPLOIT (negative history): reconcileV4 promoted and `receipts.load(session)` threw (no
        // durable receipt) while report.finalizedReceipts omitted the session — a silent completion gap.
        let c = try chain(dir: tempDir("r6-cur")); defer { c.currentness.closeStore() }
        let assetID = "rwc-asset-a20r6a01"
        let source = "rwc-source-ref-a20src06"
        let session = "rwc-acq-a20r6session0001"
        let payload = Data("crash-before-receipt-bytes".utf8)
        let contentHash = RWCCorpusAcquisitionRunnerV5.sha256Hex(payload)
        let g = grant(id: "rwc-grant-a20r6001", review: "rwc-review-a20r601")
        let (vg, rec) = try lawfulGrantAndRecord(c, assetID: assetID, source: source,
                                                 contentHash: contentHash, g: g)
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: tempDir("r6-ledger"))
        defer { store.closeStore() }
        // Simulate acquire() up to the crash point on the R7 path: register + token-backed
        // authorizeAcquisitionV2 (full proof identity) + quarantine payload, then CRASH with NO receipt.
        try store.register(rec, verifiedGrant: vg, clock: clock("2026-08-21"))
        let token = syntheticToken(session: session, asset: assetID, source: source, use: "training",
                                   g: g, c)
        let authz = try store.authorizeAcquisitionV2(token: token, verifiedGrant: vg,
                                                     currentRegistry: c.registry, clock: clock("2026-08-21"))
        XCTAssertTrue(authz.hasCompleteProofIdentity,
                      "R7 A20-R6: the ledger authorization record carries the full PASS-proof identity")
        let quarantineRoot = tempDir("r6-quar")
        let qdir = quarantineRoot.appendingPathComponent("rwc-quarantine-\(session)", isDirectory: true)
        try FileManager.default.createDirectory(at: qdir, withIntermediateDirectories: false)
        try payload.write(to: qdir.appendingPathComponent("payload"))
        // --- crash here: no receipt store writes occurred for this session ---

        // Recovery: reconcileV5 with a FRESH (empty) receipt store.
        let runner = RWCCorpusAcquisitionRunnerV5(quarantineRoot: quarantineRoot)
        let corpus = FixtureCorpusStore()
        let receipts = try RWCAcquisitionReceiptStoreV2(directory: tempDir("r6-rcpt"))
        defer { receipts.closeStore() }
        let report = try runner.reconcileV5(rightsStore: store, corpusStore: corpus, receiptStore: receipts)
        // MEASURED R7 BEHAVIOR: reconcileV5 promotes the asset AND reconstructs a durable, COMPLETED
        // receipt from the authenticated authorization record — never a silent no-receipt promotion.
        XCTAssertTrue(report.recoveredSessions.contains(session))
        XCTAssertNotNil(corpus.promoted[assetID], "R7 A20-R6: asset promoted on crash recovery")
        XCTAssertTrue(report.reconstructedReceipts.contains(session),
                      "R7 A20-R6: the missing receipt was RECONSTRUCTED from the ledger authorization record")
        XCTAssertEqual(try receipts.load(session).state, .completed,
                       "R7 A20-R6: promoted session now has a durable COMPLETED receipt")
        XCTAssertFalse(report.receiptDeficitSessions.contains(session),
                       "R7 A20-R6: no deficit — the receipt was successfully reconstructed")
        // The corpus-completion law (A18-F3 history) is now upheld on crash recovery.
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // §7 — VERIFIER / RESULT-PATH COMPATIBILITY: the compiled RWCCorpusEntryVerifierV5 is pinned to the
    // R5 result path + V6 manifest.  A future R6 PASS (R6 result path + V7 manifest) cannot be consumed.
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    func test_A20_P7_01_VerifierV5_PinnedToR5Path_And_V6Manifest() throws {
        // Compile-time/constant facts: the ONLY path the verifier reads is the R5 result path, and the
        // ONLY manifest it accepts is V6.  An R6 result at docs/audit/RWC_PRE14_R6_AUDIT_RESULT.json
        // with a V7 manifest is structurally unconsumable without a lawfully versioned verifier V6.
        XCTAssertEqual(RWCPre14AuditResultV3.canonicalPath, "docs/audit/RWC_PRE14_R5_AUDIT_RESULT.json",
                       "§7 BLOCKER: verifier reads ONLY the R5 result path")
        XCTAssertEqual(RWCCorpusEntryVerifierV5.canonicalFreezeManifestPath,
                       "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V6.yaml",
                       "§7 BLOCKER: verifier accepts ONLY the V6 freeze manifest path, but R6 uses V7")
    }

    func test_A20_P7_02_VerifierV5_RefusesR6ResultPathLock() throws {
        // Build a synthetic repo whose PASS lock points at the R6 result path; the verifier must refuse
        // it with nonCanonicalAuditResultPath (it will never consume an R6 result).
        let root = tempDir("p7-vfx")
        func sh(_ args: [String]) throws -> String {
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = ["git", "-C", root.path, "-c", "user.name=Claude",
                           "-c", "user.email=noreply@anthropic.com"] + args
            let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
            try p.run(); p.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        func write(_ rel: String, _ content: String) throws {
            let url = root.appendingPathComponent(rel)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
        try sh(["init", "-q"])
        try write("seed.txt", "x\n"); try sh(["add", "-A"]); try sh(["commit", "-q", "-m", "c"])
        let commit = try sh(["rev-parse", "HEAD"])
        // PASS lock pointing at the R6 result path (what a future R6 release would need).
        let lock = """
        {"lock_version": "rwc-pre14-pass-lock-v4", "audit_result_path": "docs/audit/RWC_PRE14_R6_AUDIT_RESULT.json",
         "audit_result_blob_sha256": "\(String(repeating: "0", count: 64))", "audit_commit": "\(commit)",
         "candidate_commit": "\(commit)", "candidate_tag_name": "fixture-r6", "candidate_tag_object_sha": "\(commit)",
         "freeze_manifest_path": "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V7.yaml",
         "freeze_manifest_sha256": "\(String(repeating: "0", count: 64))", "methodology_anchor_commit": "\(commit)",
         "frozen_inventory_digest": "\(String(repeating: "0", count: 64))", "governing_control_plane_lock": "\(commit)",
         "corpus_entry_authorized": true, "verdict": "PASS"}
        """
        try write(RWCPre14PassLockV4.lockRelPath, lock)
        try sh(["add", "-A"]); try sh(["commit", "-q", "-m", "lock"])
        // The verifier refuses — it never consumes an R6 result path.  (It may throw an earlier git
        // identity refusal first; the point is it NEVER returns a verified proof for an R6 result path.)
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV5.verify(repoRoot: root),
                             "§7: verifier V5 cannot consume an R6-result-path / V7-manifest PASS lock")
        try? FileManager.default.removeItem(at: root)
    }
}
#endif
