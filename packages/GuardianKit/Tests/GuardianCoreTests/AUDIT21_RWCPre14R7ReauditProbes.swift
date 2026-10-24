#if os(macOS)
import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
import RWCAcquisition

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT21 — INDEPENDENT R7 SECURITY RE-AUDIT PROBES (family AUDIT21_RWC_PRE14_R7_REAUDIT).
//
// Authored by the independent CHIEF SECURITY AUDITOR (AUDIT21). NOT builder tests. These probes are
// ADD-ONLY audit evidence; they never modify application code or the historical AUDIT14–20 / R-series
// tests. They adversarially re-derive the AUDIT20 findings (A20-F1/F2/F3/F4) and the R-6 receipt /
// crash-recovery contract against the R7 `-final` candidate, going BEYOND the builder's own tests:
//
//   §3  A20-F1 token boundary — in-package constructibility residual, V4→V5 cross-version refusal,
//                               restart proof-identity durability (no re-verification at reconcile).
//   §5  A20-F3 intended-use   — FULL refusal matrix at the sealed write, each hitting its INTENDED
//                               typed guard (not an unrelated fixture error).
//   §6  A20-F4 revocation     — acquire-time currentness; reconcile-time tombstone enforcement; the
//                               EXACT boundary at which currentness is verified.
//   §7  R-6 ensureReceipt     — FAULT INJECTION around the `try?` path and the promote→receipt window;
//                               the SPECIFIC hypothesis: can a session land in finalizedReceipts while
//                               the receipt operation actually failed? Is a persisted state misleading?
//                               Does the next reconcile repair it?
//   §8  verifier V6           — attacks the builder set does NOT cover: real AUDIT19/AUDIT20 FIX_REQUIRED
//                               replay, bool/float/negative/missing counts, wrong anchor, non-canonical
//                               JSON, missing provenance, real-repo lockMissing fail-closed.
//
// ZERO-DATA: synthetic throwaway fixtures only; never the real repository data path; no PASS lock.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT21_RWCPre14R7ReauditProbes: XCTestCase {

    // MARK: fixture vocabulary (independent of the builder's private helpers)

    private func shaHex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func shaHex(_ d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }
    private func d3(_ s: String) -> RWCDateV3 { try! RWCDateV3.parse(s, field: "a21") }
    private func clock(_ s: String) -> RWCFixedClockV3 { try! RWCFixedClockV3(s) }
    private func tempDir(_ tag: String) -> URL {
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("a21-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
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
                           status: String = "ACTIVE", registryRevision: Int = 1,
                           previousDigest: String? = nil) -> RWCReviewerRegistryDocumentV2 {
        let entry = RWCReviewerRegistryEntryV1(
            reviewerID: "rwc-reviewer-a21ctl1", publicKeyRawHex: reviewerHex, status: status,
            role: "RIGHTS_REVIEW", scope: RWCReviewerScopeV1.corpus.rawValue, validFrom: d3("2026-01-01"),
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
    private func chain(dir: URL) throws -> Chain {
        let r = RWCReviewerTrustRootLoaderV2.makeSyntheticTestRoot()
        let reviewerKey = Curve25519.Signing.PrivateKey()
        let reviewerHex = reviewerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let doc = signedDoc(rootID: r.root.rootID, rootPriv: r.privateKey, reviewerHex: reviewerHex)
        let currentness = try RWCReviewerRegistryCurrentnessStoreV1.create(directory: dir)
        try currentness.advance(rootID: r.root.rootID, revision: 1, documentDigest: doc.documentDigest,
                                recordedDate: "2026-02-01")
        let reg = try RWCReviewerRegistryVerifierV2.verifyCurrent(document: doc, trustRoot: r.root,
                                                                  currentness: currentness, previousVerified: nil)
        return Chain(root: r.root, rootPriv: r.privateKey, currentness: currentness, registry: reg,
                     reviewerKey: reviewerKey, doc: doc)
    }
    private func grant(id: String, review: String, allowed: [String] = ["training", "evaluation"],
                       prohibited: [String] = [], effective: String = "2026-08-01",
                       expiry: String? = "2027-08-01") -> RWCLegalGrantIdentityV1 {
        RWCLegalGrantIdentityV1(grantID: id, grantRevision: 1, evidenceDigest: shaHex("proof-\(id)"),
            evidencePointer: "rwc-rights-ref-a21p01", rightsHolder: "licensor-a21",
            allowedUse: allowed, prohibitedUse: prohibited, effectiveDate: d3(effective),
            expiryDate: expiry.map { d3($0) }, reviewDecision: "APPROVED", reviewRecordID: review)
    }
    private func grantV6(_ g: RWCLegalGrantIdentityV1, source: String, _ c: Chain) throws -> RWCVerifiedRightsGrantV6 {
        var r = RWCSignedRightsReviewV1(
            reviewRecordID: g.reviewRecordID, reviewerID: "rwc-reviewer-a21ctl1", grantID: g.grantID,
            grantRevision: g.grantRevision, evidenceDigest: g.evidenceDigest, rightsHolder: g.rightsHolder,
            sourceAuthorization: .exactSource(source), allowedUse: g.allowedUse, prohibitedUse: g.prohibitedUse,
            effectiveDate: g.effectiveDate, expiryDate: g.expiryDate, decision: "APPROVED",
            reviewDate: d3("2026-08-15"), signatureHex: "")
        let sig = try c.reviewerKey.signature(for: r.canonicalPayloadBytes)
        r = RWCSignedRightsReviewV1(
            reviewRecordID: r.reviewRecordID, reviewerID: r.reviewerID, grantID: r.grantID,
            grantRevision: r.grantRevision, evidenceDigest: r.evidenceDigest, rightsHolder: r.rightsHolder,
            sourceAuthorization: r.sourceAuthorization, allowedUse: r.allowedUse, prohibitedUse: r.prohibitedUse,
            effectiveDate: r.effectiveDate, expiryDate: r.expiryDate, decision: r.decision,
            reviewDate: r.reviewDate, signatureHex: sig.map { String(format: "%02x", $0) }.joined())
        return try RWCRightsReviewAuthorityV6.verify(signedReview: r, grant: g, verifiedRegistry: c.registry)
    }
    private func record(_ assetID: String, source: String, contentHash: String,
                        _ g: RWCLegalGrantIdentityV1) -> RWCAssetRightsRecordV3 {
        RWCAssetRightsRecordV3(assetID: assetID, sourceClass: .licensedRightsClear, sourceReference: source,
                               owner: "gen8", grant: g, acquisitionDate: d3("2026-08-20"),
                               contentHash: contentHash, provenanceChain: [source])
    }
    /// A synthetic token minted via the in-package `package` init. NOT a PASS proof — the digests are
    /// placeholders; this drives the SEALED-WRITE refusal logic in isolation. The `use`/digest fields
    /// are parameterised so a probe can target a specific guard.
    private func token(session: String, asset: String, source: String, use: String,
                       grantID: String, grantRev: Int = 1, registryDigest: String,
                       rootID: String, registryRev: Int,
                       completeProof: Bool = true) -> RWCAcquisitionAuthorityTokenV1 {
        func f(_ v: String) -> String { completeProof ? shaHex(v) : "" }
        return RWCAcquisitionAuthorityTokenV1(
            candidateCommit: f("cand"), candidateTagObjectSHA: f("tag"), auditCommit: f("audit"),
            auditResultBlobSHA256: f("blob"), methodologyAnchorCommit: f("anchor"),
            freezeManifestSHA256: f("freeze"), frozenInventoryDigest: f("inv"),
            sessionID: session, assetID: asset, sourceReference: source, intendedUseToken: use,
            grantID: grantID, grantRevision: grantRev,
            currentRegistryRootID: rootID, currentRegistryRevision: registryRev,
            currentRegistryDocumentDigest: registryDigest)
    }

    // A tiny corpus store fixture (independent of the builder's private one).
    private final class CorpusFixture: RWCCorpusStoreV1 {
        var promoted: [String: Data] = [:]
        func promote(assetID: String, contentHash: String, payload: Data) throws { promoted[assetID] = payload }
        func storedAssetIDs() throws -> [String] { Array(promoted.keys) }
    }

    // ═════════════════════════════════════════════════════════════════════════════════════════════
    // §3 — A20-F1 TOKEN BOUNDARY
    // ═════════════════════════════════════════════════════════════════════════════════════════════

    /// §3 Q2/Q3: MEASUREMENT — in-package code (this test target) CAN construct the token directly via
    /// the `package` init, WITHOUT any methodology proof. This is the documented residual: the compiler
    /// seals EXTERNAL consumers only. Recorded here as an explicit, bounded fact (the external seal is
    /// proven by the a21consumer compile-negative + RWCAcquisition-not-a-product fact). This is NOT a
    /// production-reachable bypass: RWCAcquisition is not a product, so no external consumer can even
    /// reach authorizeAcquisitionV2, and in-package the ONLY caller is RunnerV5 by discipline.
    func test_A21_F1_01_InPackageTokenConstructible_DocumentedResidual_NotProductionReachable() throws {
        let c = try chain(dir: tempDir("f1-01-cur")); defer { c.currentness.closeStore() }
        // A token with ENTIRELY FORGED proof identity can be built in-package (by design of `package`).
        let t = token(session: "rwc-acq-a21f101session0001", asset: "rwc-asset-a21f101a1",
                      source: "rwc-source-ref-a21s01", use: "training", grantID: "rwc-grant-a21f1001",
                      registryDigest: c.registry.documentDigest, rootID: c.registry.rootID,
                      registryRev: c.registry.registryRevision)
        XCTAssertEqual(t.intendedUseToken, "training",
                       "MEASURED: the test target constructs the token directly — the `package` seal is " +
                       "an EXTERNAL boundary, not a compiler-guaranteed single minter. Documented residual.")
        // The bounded fact: a forged-proof token still cannot promote, because authorizeAcquisitionV2
        // enforces grant/use/currentness INDEPENDENTLY of the token's (forgeable) proof-identity digests.
        // (The proof identity is checked for COMPLETENESS at reconcile; its AUTHENTICITY is established by
        //  the ONLY disciplined minter RunnerV5 having run RWCCorpusEntryVerifierV6.verify first.)
    }

    /// §3 Q8: a legacy store-V4 directory (witness `v` = ledger-store-v4, authorization kind
    /// "acquisition-authorized" v1) CANNOT be opened by store V5 — cross-version refusal. There is no
    /// path by which a V4-era authorization record reaches reconcileV5 promotion.
    func test_A21_F1_02_StoreV4Directory_RefusedBy_StoreV5_OpenExisting() throws {
        // Build a REAL store V4 directory, then attempt to open it with V5.
        let dir = tempDir("f1-02-ledger").appendingPathComponent("l")
        let v4 = try RWCAssetRightsLedgerStoreV4.create(directory: dir)
        v4.closeStore()
        // MEASURED cross-version refusal: a V4 directory writes its witness to `rights-head-v4.json`,
        // while V5.openExisting looks ONLY for `rights-head-v5.json`. That v5 witness is ABSENT in a V4
        // directory, so openExisting fails CLOSED with `.witnessMissing` BEFORE any V4 state can be read.
        // (The property the mandate's §3 Q8 asks for — "no path by which a V4-era authorization record
        //  reaches reconcileV5 promotion" — holds: V5 never opens the V4 store at all.)
        XCTAssertThrowsError(try RWCAssetRightsLedgerStoreV5.openExisting(directory: dir)) { e in
            guard case .witnessMissing = (e as? RWCRightsLedgerErrorV5) else {
                return XCTFail("expected witnessMissing (V5 cannot open a V4 directory), got \(e)")
            }
        }
    }

    /// §3 Q9: after a restart (openExisting re-reads the journal), a lawful authorization record with a
    /// COMPLETE proof identity stands in as durable evidence — the methodology proof is NOT re-run at
    /// reconcile time; its DURABLE record is trusted. We assert the documented behaviour: reopen
    /// preserves `hasCompleteProofIdentity` and reconcileV5 promotes (no re-verification call). This is
    /// the accepted R-5-class residual (durable ledger record = authority after restart). An INCOMPLETE
    /// record (hostile-disk forgery) is refused — proven separately in F1_03b.
    func test_A21_F1_03a_Restart_CompleteProofRecord_PromotesWithoutReverification() throws {
        let c = try chain(dir: tempDir("f1-03a-cur")); defer { c.currentness.closeStore() }
        let asset = "rwc-asset-a21f103a1"; let source = "rwc-source-ref-a21s03a"
        let session = "rwc-acq-a21f103asession01"
        let payload = Data("a21-f1-03a".utf8); let hash = shaHex(payload)
        let g = grant(id: "rwc-grant-a21f103a", review: "rwc-review-a21r3a")
        let vg = try grantV6(g, source: source, c)
        let ledgerDir = tempDir("f1-03a-l").appendingPathComponent("l")
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: ledgerDir)
        try store.register(record(asset, source: source, contentHash: hash, g), verifiedGrant: vg,
                           clock: clock("2026-08-21"))
        let t = token(session: session, asset: asset, source: source, use: "training",
                      grantID: g.grantID, registryDigest: c.registry.documentDigest,
                      rootID: c.registry.rootID, registryRev: c.registry.registryRevision)
        _ = try store.authorizeAcquisitionV2(token: t, verifiedGrant: vg, currentRegistry: c.registry,
                                             clock: clock("2026-08-21"))
        store.closeStore()   // --- restart ---
        let reopened = try RWCAssetRightsLedgerStoreV5.openExisting(directory: ledgerDir)
        defer { reopened.closeStore() }
        let authz = reopened.authorizationRecord(forSession: session)
        XCTAssertNotNil(authz)
        XCTAssertTrue(authz?.hasCompleteProofIdentity ?? false,
                      "restart preserves the durable COMPLETE proof identity (R-5 residual: durable record = authority)")
        // reconcileV5 promotes from the reopened durable record with a reconstructed receipt.
        let qRoot = tempDir("f1-03a-q")
        let qdir = qRoot.appendingPathComponent("rwc-quarantine-\(session)", isDirectory: true)
        try FileManager.default.createDirectory(at: qdir, withIntermediateDirectories: true)
        try payload.write(to: qdir.appendingPathComponent("payload"))
        let corpus = CorpusFixture()
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: tempDir("f1-03a-r"))
        defer { receipt.closeStore() }
        let report = try RWCCorpusAcquisitionRunnerV5(quarantineRoot: qRoot)
            .reconcileV5(rightsStore: reopened, corpusStore: corpus, receiptStore: receipt)
        XCTAssertEqual(report.recoveredSessions, [session])
        XCTAssertNotNil(corpus.promoted[asset])
    }

    /// §3 Q9 (fail-closed half): a hostile-disk authorization record whose proof identity is INCOMPLETE
    /// (empty fields) is NEVER promoted after restart; reconcileV5 surfaces an explicit receiptDeficit.
    func test_A21_F1_03b_Restart_IncompleteProofRecord_NeverPromoted_ReportsDeficit() throws {
        let c = try chain(dir: tempDir("f1-03b-cur")); defer { c.currentness.closeStore() }
        let asset = "rwc-asset-a21f103b1"; let source = "rwc-source-ref-a21s03b"
        let session = "rwc-acq-a21f103bsession01"
        let payload = Data("a21-f1-03b".utf8); let hash = shaHex(payload)
        let g = grant(id: "rwc-grant-a21f103b", review: "rwc-review-a21r3b")
        let vg = try grantV6(g, source: source, c)
        let ledgerDir = tempDir("f1-03b-l").appendingPathComponent("l")
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: ledgerDir)
        try store.register(record(asset, source: source, contentHash: hash, g), verifiedGrant: vg,
                           clock: clock("2026-08-21"))
        // register writes event 0; now FORGE an authorization event with EMPTY proof identity on disk.
        let prevDigest = store.headDigest; let seq = store.eventCount
        store.closeStore()
        let authzJSON = "{\"v\":\"rwc-acq-authorization-v2\",\"session\":\"\(session)\"," +
            "\"asset\":\"\(asset)\",\"hash\":\"\(hash)\",\"grant\":\"\(g.grantID)\",\"rev\":1," +
            "\"review\":\"\(g.reviewRecordID)\",\"reviewer\":\"rwc-reviewer-a21ctl1\"," +
            "\"source\":\"\(source)\",\"use\":\"training\"," +
            "\"registryDoc\":\"\(c.doc.documentDigest)\",\"root\":\"\(c.root.rootID)\"," +
            "\"candidate\":\"\",\"tagObj\":\"\",\"auditCommit\":\"\",\"auditBlob\":\"\"," +
            "\"anchor\":\"\",\"freeze\":\"\",\"inventory\":\"\",\"tx\":\"2026-08-21\"}"
        let forged = RWCRightsEventV3(seq: seq, previousDigest: prevDigest, assetID: asset,
                                      kind: "acquisition-authorized-v2", recordPayloadJSON: authzJSON,
                                      recordedDate: "2026-08-21")
        let line = RWCAssetRightsLedgerStoreV5.journalLine(forged)
        let journalURL = ledgerDir.appendingPathComponent("rights-journal-v5.jsonl")
        let h = try FileHandle(forWritingTo: journalURL)
        try h.seekToEnd(); try h.write(contentsOf: Data(line.utf8)); try h.close()
        let witnessJSON = "{\"v\":\"\(RWCAssetRightsLedgerStoreV5.version)\",\"count\":\(seq + 1)," +
            "\"head\":\"\(forged.eventDigest)\"}\n"
        try Data(witnessJSON.utf8).write(to: ledgerDir.appendingPathComponent("rights-head-v5.json"))
        let reopened = try RWCAssetRightsLedgerStoreV5.openExisting(directory: ledgerDir)
        defer { reopened.closeStore() }
        XCTAssertFalse(reopened.authorizationRecord(forSession: session)?.hasCompleteProofIdentity ?? true)
        let qRoot = tempDir("f1-03b-q")
        let qdir = qRoot.appendingPathComponent("rwc-quarantine-\(session)", isDirectory: true)
        try FileManager.default.createDirectory(at: qdir, withIntermediateDirectories: true)
        try payload.write(to: qdir.appendingPathComponent("payload"))
        let corpus = CorpusFixture()
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: tempDir("f1-03b-r"))
        defer { receipt.closeStore() }
        let report = try RWCCorpusAcquisitionRunnerV5(quarantineRoot: qRoot)
            .reconcileV5(rightsStore: reopened, corpusStore: corpus, receiptStore: receipt)
        XCTAssertTrue(corpus.promoted.isEmpty, "incomplete-proof session is NEVER promoted")
        XCTAssertTrue(report.receiptDeficitSessions.contains(session), "surfaced as explicit deficit")
    }

    // ═════════════════════════════════════════════════════════════════════════════════════════════
    // §5 — A20-F3 INTENDED-USE FULL REFUSAL MATRIX (each hits its INTENDED typed guard)
    // ═════════════════════════════════════════════════════════════════════════════════════════════

    /// Shared harness: register an asset under grant `g`, then attempt authorizeAcquisitionV2 with a
    /// token built per `mutate`. Returns the thrown error for typed assertion.
    private func authorizeAttempt(assetTag: String, grantAllowed: [String], grantProhibited: [String] = [],
                                  tokenUse: String, tokenGrantID: String? = nil,
                                  tokenSource: String? = nil, tokenRegistryDigest: String? = nil,
                                  grantExpiry: String? = "2027-08-01",
                                  authorizeClock: String = "2026-08-21") throws -> Error? {
        let c = try chain(dir: tempDir("\(assetTag)-cur")); defer { c.currentness.closeStore() }
        // the asset-ID token law requires 8…32 chars after `rwc-asset-`; append a stable suffix so the
        // short per-case tags (e.g. "a21f301") satisfy it without altering the guard under test.
        let asset = "rwc-asset-\(assetTag)asset01"; let source = "rwc-source-ref-\(assetTag)s"
        let payload = Data(assetTag.utf8); let hash = shaHex(payload)
        let g = grant(id: "rwc-grant-\(assetTag)", review: "rwc-review-\(assetTag)",
                      allowed: grantAllowed, prohibited: grantProhibited, expiry: grantExpiry)
        let vg = try grantV6(g, source: source, c)
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: tempDir("\(assetTag)-l").appendingPathComponent("l"))
        defer { store.closeStore() }
        try store.register(record(asset, source: source, contentHash: hash, g), verifiedGrant: vg,
                           clock: clock("2026-08-20"))
        let t = token(session: "rwc-acq-\(assetTag)session0001", asset: asset,
                      source: tokenSource ?? source, use: tokenUse,
                      grantID: tokenGrantID ?? g.grantID,
                      registryDigest: tokenRegistryDigest ?? c.registry.documentDigest,
                      rootID: c.registry.rootID, registryRev: c.registry.registryRevision)
        do {
            _ = try store.authorizeAcquisitionV2(token: t, verifiedGrant: vg, currentRegistry: c.registry,
                                                 clock: clock(authorizeClock))
            return nil
        } catch { return error }
    }

    /// §5 (a) training under an evaluation-only grant → useNotAuthorized("training").
    func test_A21_F3_01_TrainingUnderEvaluationOnlyGrant_UseNotAuthorized() throws {
        let e = try authorizeAttempt(assetTag: "a21f301", grantAllowed: ["evaluation"], tokenUse: "training")
        guard case .useNotAuthorized(let u) = (e as? RWCRightsLedgerErrorV5) else {
            return XCTFail("expected useNotAuthorized, got \(String(describing: e))")
        }
        XCTAssertEqual(u, "training")
    }

    /// §5 (b) PROHIBITED-USE enforcement, measured at BOTH layers:
    ///  (b1) a grant that lists the SAME use as both allowed and prohibited is rejected AT GRANT
    ///       CONSTRUCTION with `useOverlap` (RWCRightsReviewAuthorityV1) — so an overlapping-use grant can
    ///       never even be minted; the authorize-boundary prohibited check is belt-and-suspenders over a
    ///       grant that the construction law already forbids.
    ///  (b2) a use that is prohibited-only (training prohibited, evaluation allowed) is refused at the
    ///       sealed write as `useNotAuthorized("training")` — the asset can never be acquired for a use
    ///       the grant does not positively allow.
    func test_A21_F3_02_ProhibitedUse_RejectedAtConstruction_And_UseNotAuthorizedAtWrite() throws {
        // (b1) overlapping allowed/prohibited → the grant cannot be verified at all.
        let c = try chain(dir: tempDir("f3-02-cur")); defer { c.currentness.closeStore() }
        let overlapping = grant(id: "rwc-grant-a21f302ov", review: "rwc-review-a21f302ov",
                                allowed: ["training", "evaluation"], prohibited: ["training"])
        XCTAssertThrowsError(try grantV6(overlapping, source: "rwc-source-ref-a21f302ovs", c)) { e in
            guard case .useOverlap = (e as? RWCRightsErrorV3) else {
                return XCTFail("expected useOverlap at grant construction, got \(e)")
            }
        }
        // (b2) training is prohibited (and NOT allowed); authorize refuses as useNotAuthorized.
        let e = try authorizeAttempt(assetTag: "a21f302", grantAllowed: ["evaluation"],
                                     grantProhibited: ["training"], tokenUse: "training")
        guard case .useNotAuthorized(let u) = (e as? RWCRightsLedgerErrorV5) else {
            return XCTFail("expected useNotAuthorized, got \(String(describing: e))")
        }
        XCTAssertEqual(u, "training")
    }

    /// §5 (c) malformed use token → useNotAuthorized (strict "training"|"evaluation").
    func test_A21_F3_03_MalformedUseToken_UseNotAuthorized() throws {
        let e = try authorizeAttempt(assetTag: "a21f303", grantAllowed: ["training"], tokenUse: "garbage")
        guard case .useNotAuthorized(let u) = (e as? RWCRightsLedgerErrorV5) else {
            return XCTFail("expected useNotAuthorized, got \(String(describing: e))")
        }
        XCTAssertEqual(u, "garbage")
    }

    /// §5 (d) wrong grant ID in the token → tokenBindingMismatch(grant), NOT a use error.
    func test_A21_F3_04_WrongGrantID_TokenBindingMismatch() throws {
        let e = try authorizeAttempt(assetTag: "a21f304", grantAllowed: ["training"], tokenUse: "training",
                                     tokenGrantID: "rwc-grant-a21WRONG1")
        guard case .tokenBindingMismatch(let f) = (e as? RWCRightsLedgerErrorV5) else {
            return XCTFail("expected tokenBindingMismatch, got \(String(describing: e))")
        }
        XCTAssertEqual(f, "grant")
    }

    /// §5 (e) wrong source reference in the token → authorizationMalformed (record != token), NOT use.
    func test_A21_F3_05_WrongSource_AuthorizationMalformed() throws {
        let e = try authorizeAttempt(assetTag: "a21f305", grantAllowed: ["training"], tokenUse: "training",
                                     tokenSource: "rwc-source-ref-a21DECOY")
        // The token's grant binding still matches; the source mismatch is caught as the record/token
        // consistency guard (authorizationMalformed) — a DIFFERENT typed guard than use/binding.
        guard case .authorizationMalformed = (e as? RWCRightsLedgerErrorV5) else {
            return XCTFail("expected authorizationMalformed (source), got \(String(describing: e))")
        }
    }

    /// §5 (f) stale registry digest in the token → reviewerNotCurrent(token-digest-vs-current).
    func test_A21_F3_06_StaleTokenRegistryDigest_ReviewerNotCurrent() throws {
        let e = try authorizeAttempt(assetTag: "a21f306", grantAllowed: ["training"], tokenUse: "training",
                                     tokenRegistryDigest: String(repeating: "a", count: 64))
        guard case .reviewerNotCurrent(let stage) = (e as? RWCRightsLedgerErrorV5) else {
            return XCTFail("expected reviewerNotCurrent, got \(String(describing: e))")
        }
        XCTAssertEqual(stage, "token-digest-vs-current")
    }

    /// §5 (g) a lawful token with the CORRECT use/source/grant/registry passes (positive control — the
    /// refusals above are not fixture artefacts; the gate DOES accept a correct token).
    func test_A21_F3_07_LawfulUse_Authorizes_PositiveControl() throws {
        let e = try authorizeAttempt(assetTag: "a21f307", grantAllowed: ["training", "evaluation"],
                                     tokenUse: "training")
        XCTAssertNil(e, "a correctly-bound token must be ACCEPTED (positive control)")
    }

    // ═════════════════════════════════════════════════════════════════════════════════════════════
    // §6 — A20-F4 REVOCATION / CURRENT REGISTRY
    // ═════════════════════════════════════════════════════════════════════════════════════════════

    /// §6: the EXACT acquire-time currentness boundary. A grant minted under rev1 ACTIVE, then the
    /// reviewer is REVOKED at rev2; presenting the rev2 current registry refuses at authorizeAcquisitionV2
    /// with reviewerNotCurrent(grant-digest-vs-current) — the grant's rev1 digest no longer equals the
    /// current head. Confirms currentness is checked at the WRITE boundary, not only at registry load.
    func test_A21_F4_01_RevokedReviewer_RefusedAtWrite_GrantDigestVsCurrent() throws {
        let c = try chain(dir: tempDir("f4-01-cur")); defer { c.currentness.closeStore() }
        let asset = "rwc-asset-a21f401a1"; let source = "rwc-source-ref-a21f401s"
        let payload = Data("a21-f4-01".utf8); let hash = shaHex(payload)
        let g = grant(id: "rwc-grant-a21f401", review: "rwc-review-a21f401")
        let vg = try grantV6(g, source: source, c)  // minted under rev1 ACTIVE
        let reviewerHex = c.reviewerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let rev2doc = signedDoc(rootID: c.root.rootID, rootPriv: c.rootPriv, reviewerHex: reviewerHex,
                                status: "REVOKED", registryRevision: 2, previousDigest: c.doc.documentDigest)
        try c.currentness.advance(rootID: c.root.rootID, revision: 2, documentDigest: rev2doc.documentDigest,
                                  recordedDate: "2026-09-01")
        let rev2 = try RWCReviewerRegistryVerifierV2.verifyCurrent(document: rev2doc, trustRoot: c.root,
                                                                   currentness: c.currentness,
                                                                   previousVerified: c.registry)
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: tempDir("f4-01-l").appendingPathComponent("l"))
        defer { store.closeStore() }
        try store.register(record(asset, source: source, contentHash: hash, g), verifiedGrant: vg,
                           clock: clock("2026-09-02"))
        // Even a token that claims the rev2 digest cannot pass: the grant's OWN digest is rev1, and the
        // first currentness guard compares current-vs-GRANT (not current-vs-token).
        let t = token(session: "rwc-acq-a21f401session0001", asset: asset, source: source, use: "training",
                      grantID: g.grantID, registryDigest: rev2.documentDigest,
                      rootID: rev2.rootID, registryRev: rev2.registryRevision)
        XCTAssertThrowsError(try store.authorizeAcquisitionV2(token: t, verifiedGrant: vg,
                                                              currentRegistry: rev2, clock: clock("2026-09-02"))) { e in
            guard case .reviewerNotCurrent(let stage) = (e as? RWCRightsLedgerErrorV5) else {
                return XCTFail("expected reviewerNotCurrent, got \(e)")
            }
            XCTAssertEqual(stage, "grant-digest-vs-current")
        }
    }

    /// §6: reconcile-time revocation. A session lawfully authorized under rev1, then its ASSET is REVOKED
    /// (tombstoned) in the ledger; a subsequent reconcileV5 must DESTROY the session (destroyedRevoked)
    /// and NEVER promote. Determines the reconcile-time revocation-effective boundary (asset tombstone,
    /// not reviewer-registry re-check — recorded honestly in the report).
    func test_A21_F4_02_ReconcileAfterAssetRevocation_DestroysSession_NoPromotion() throws {
        let c = try chain(dir: tempDir("f4-02-cur")); defer { c.currentness.closeStore() }
        let asset = "rwc-asset-a21f402a1"; let source = "rwc-source-ref-a21f402s"
        let session = "rwc-acq-a21f402session0001"
        let payload = Data("a21-f4-02".utf8); let hash = shaHex(payload)
        let g = grant(id: "rwc-grant-a21f402", review: "rwc-review-a21f402")
        let vg = try grantV6(g, source: source, c)
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: tempDir("f4-02-l").appendingPathComponent("l"))
        defer { store.closeStore() }
        try store.register(record(asset, source: source, contentHash: hash, g), verifiedGrant: vg,
                           clock: clock("2026-08-21"))
        let t = token(session: session, asset: asset, source: source, use: "training",
                      grantID: g.grantID, registryDigest: c.registry.documentDigest,
                      rootID: c.registry.rootID, registryRev: c.registry.registryRevision)
        _ = try store.authorizeAcquisitionV2(token: t, verifiedGrant: vg, currentRegistry: c.registry,
                                             clock: clock("2026-08-21"))
        // REVOKE the asset AFTER authorization but BEFORE reconcile (crash window).
        try store.revoke(assetID: asset, clock: clock("2026-08-22"))
        let qRoot = tempDir("f4-02-q")
        let qdir = qRoot.appendingPathComponent("rwc-quarantine-\(session)", isDirectory: true)
        try FileManager.default.createDirectory(at: qdir, withIntermediateDirectories: true)
        try payload.write(to: qdir.appendingPathComponent("payload"))
        let corpus = CorpusFixture()
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: tempDir("f4-02-r"))
        defer { receipt.closeStore() }
        let report = try RWCCorpusAcquisitionRunnerV5(quarantineRoot: qRoot)
            .reconcileV5(rightsStore: store, corpusStore: corpus, receiptStore: receipt)
        XCTAssertTrue(corpus.promoted.isEmpty, "a revoked asset is NEVER promoted at reconcile")
        XCTAssertTrue(report.destroyedRevokedSessions.contains(session),
                      "the revoked session is destroyed and reported")
        XCTAssertFalse(report.recoveredSessions.contains(session))
    }

    // ═════════════════════════════════════════════════════════════════════════════════════════════
    // §7 — R-6 ensureReceipt FAULT INJECTION (the SPECIFIC mandate hypothesis)
    // ═════════════════════════════════════════════════════════════════════════════════════════════

    /// §7 HYPOTHESIS (core): in reconcileV5.ensureReceipt, when a receipt EXISTS but state != .completed,
    /// the finalize transitions run under `try?` and the session is appended to `finalizedReceipts`
    /// REGARDLESS of whether complete() actually succeeded. We FORCE complete() to fail by making the
    /// receipt directory read-only after a PREPARED receipt is written, then driving reconcile over an
    /// already-promoted asset.
    ///
    /// MEASUREMENT: does the session appear in finalizedReceipts while its DURABLE state is NOT completed?
    /// And does the NEXT reconcile (directory writable again) repair it?
    func test_A21_R6_01_EnsureReceipt_FinalizeFails_UnderTryOptional_FaultInjection() throws {
        let c = try chain(dir: tempDir("r6-01-cur")); defer { c.currentness.closeStore() }
        let asset = "rwc-asset-a21r601a1"; let source = "rwc-source-ref-a21r601s"
        let session = "rwc-acq-a21r601session0001"
        let payload = Data("a21-r6-01".utf8); let hash = shaHex(payload)
        let g = grant(id: "rwc-grant-a21r601", review: "rwc-review-a21r601")
        let vg = try grantV6(g, source: source, c)
        let ledgerDir = tempDir("r6-01-l").appendingPathComponent("l")
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: ledgerDir)
        defer { store.closeStore() }
        try store.register(record(asset, source: source, contentHash: hash, g), verifiedGrant: vg,
                           clock: clock("2026-08-21"))
        let t = token(session: session, asset: asset, source: source, use: "training",
                      grantID: g.grantID, registryDigest: c.registry.documentDigest,
                      rootID: c.registry.rootID, registryRev: c.registry.registryRevision)
        let authz = try store.authorizeAcquisitionV2(token: t, verifiedGrant: vg, currentRegistry: c.registry,
                                                     clock: clock("2026-08-21"))
        // The asset is ALREADY promoted in the corpus (so reconcile takes the ensureReceipt "stored" path).
        let corpus = CorpusFixture(); corpus.promoted[asset] = payload
        let receiptDir = tempDir("r6-01-r")
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: receiptDir)
        // Write a PREPARED (NOT completed) receipt via the package overload, mirroring a crash where
        // prepare+promote happened but confirm/complete did not.
        _ = try receipt.prepare(authorizationV2: authz, rightsLedgerHeadDigest: store.headDigest,
                                rightsEventCount: store.eventCount)
        XCTAssertEqual(try receipt.load(session).state, .prepared)
        // FAULT INJECTION: make the receipt directory read-only so writeRecord (atomic write) FAILS,
        // forcing confirmPromotion()/complete() under ensureReceipt's `try?` to silently throw.
        let fm = FileManager.default
        try fm.setAttributes([.posixPermissions: 0o500], ofItemAtPath: receiptDir.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: receiptDir.path) }

        let qRoot = tempDir("r6-01-q")
        let qdir = qRoot.appendingPathComponent("rwc-quarantine-\(session)", isDirectory: true)
        try fm.createDirectory(at: qdir, withIntermediateDirectories: true)
        try payload.write(to: qdir.appendingPathComponent("payload"))
        let report = try RWCCorpusAcquisitionRunnerV5(quarantineRoot: qRoot)
            .reconcileV5(rightsStore: store, corpusStore: corpus, receiptStore: receipt)

        // Restore writability to READ the true durable state.
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: receiptDir.path)
        let durableState = try receipt.load(session).state

        // ── LANE A SUPERSESSION OF THE A21-F5 PROBE (declared in docs/audit/AUDIT21_LANE_A_INVERSION_LOCK.md;
        //    this AUDIT21 §7 probe is NOT byte-pinned by any discipline test and is AUDIT-prefixed /
        //    allowance-covered, so it is lawfully editable to assert the FIXED behavior). ───────────────
        //
        // OLD AUDITOR-MEASURED DEFECT (A21-F5, now FIXED — retained as negative history):
        //   (old-1) the `try?`-swallowed finalize failure produced a MISLEADING `finalizedReceipts` line
        //           while the durable receipt stayed `.prepared`:
        //             XCTAssertTrue(report.finalizedReceipts.contains(session), "false finalize report")
        //   (old-2) reconcile #1 DELETED the quarantine on the stored-asset path even on the failed
        //           finalize, so a plain reconcile #2 could not self-heal (receipt stuck .prepared).
        //
        // NEW FIXED BEHAVIOR (A21-F5 targeted fix in RWCCorpusAcquisitionRunnerV5.reconcileV5.ensureReceipt):
        // (1) a FAILED finalize is NOT reported as finalized — it is surfaced as an explicit receiptDeficit;
        //     the durable receipt honestly stays `.prepared` (never a false `.completed`).
        XCTAssertFalse(report.finalizedReceipts.contains(session),
            "A21-F5 FIX: a failed complete() is NOT falsely reported in finalizedReceipts")
        XCTAssertTrue(report.receiptDeficitSessions.contains(session),
            "A21-F5 FIX: the failed finalize is surfaced as an explicit receiptDeficit")
        XCTAssertEqual(durableState, .prepared,
            "A21-F5 FIX: the durable receipt honestly stays .prepared (no false durable completeness)")

        // (2) EVIDENCE PRESERVED + RETRYABLE: because the finalize failed (deficit), the fix PRESERVES the
        //     quarantine (no evidence loss). Once the fault clears (dir writable), the NEXT reconcile
        //     drives the receipt to .completed — the deficit is recoverable, not permanent corruption.
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: receiptDir.path)
        XCTAssertTrue(fm.fileExists(atPath: qdir.appendingPathComponent("payload").path),
            "A21-F5 FIX: quarantine evidence is PRESERVED on a receiptDeficit (no silent loss)")
        let report2 = try RWCCorpusAcquisitionRunnerV5(quarantineRoot: qRoot)
            .reconcileV5(rightsStore: store, corpusStore: corpus, receiptStore: receipt)
        XCTAssertTrue(report2.finalizedReceipts.contains(session),
            "A21-F5 FIX: the preserved-evidence deficit is retryable — reconcile #2 finalizes it")
        XCTAssertEqual(try receipt.load(session).state, .completed,
            "A21-F5 FIX: the retry repairs the durable receipt to .completed")
    }

    /// §7: promote→receipt window. If promotion succeeds but the receipt is ENTIRELY ABSENT (crash before
    /// any receipt write), reconcileV5 reconstructs it (reconstructedReceipts) and it is NEVER a silent
    /// no-receipt promotion. Positive assurance that a promoted asset always ends with a durable receipt.
    func test_A21_R6_02_PromoteWithoutReceipt_ReconcileReconstructs_NeverSilent() throws {
        let c = try chain(dir: tempDir("r6-02-cur")); defer { c.currentness.closeStore() }
        let asset = "rwc-asset-a21r602a1"; let source = "rwc-source-ref-a21r602s"
        let session = "rwc-acq-a21r602session0001"
        let payload = Data("a21-r6-02".utf8); let hash = shaHex(payload)
        let g = grant(id: "rwc-grant-a21r602", review: "rwc-review-a21r602")
        let vg = try grantV6(g, source: source, c)
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: tempDir("r6-02-l").appendingPathComponent("l"))
        defer { store.closeStore() }
        try store.register(record(asset, source: source, contentHash: hash, g), verifiedGrant: vg,
                           clock: clock("2026-08-21"))
        let t = token(session: session, asset: asset, source: source, use: "training",
                      grantID: g.grantID, registryDigest: c.registry.documentDigest,
                      rootID: c.registry.rootID, registryRev: c.registry.registryRevision)
        _ = try store.authorizeAcquisitionV2(token: t, verifiedGrant: vg, currentRegistry: c.registry,
                                             clock: clock("2026-08-21"))
        // Asset already promoted (crash between promote and FIRST receipt write): NO receipt exists.
        let corpus = CorpusFixture(); corpus.promoted[asset] = payload
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: tempDir("r6-02-r"))
        defer { receipt.closeStore() }
        XCTAssertThrowsError(try receipt.load(session)) // no receipt yet
        let qRoot = tempDir("r6-02-q")
        let qdir = qRoot.appendingPathComponent("rwc-quarantine-\(session)", isDirectory: true)
        try FileManager.default.createDirectory(at: qdir, withIntermediateDirectories: true)
        try payload.write(to: qdir.appendingPathComponent("payload"))
        let report = try RWCCorpusAcquisitionRunnerV5(quarantineRoot: qRoot)
            .reconcileV5(rightsStore: store, corpusStore: corpus, receiptStore: receipt)
        XCTAssertTrue(report.reconstructedReceipts.contains(session),
                      "promoted-without-receipt → receipt RECONSTRUCTED (never a silent no-receipt promotion)")
        XCTAssertEqual(try receipt.load(session).state, .completed)
        XCTAssertTrue(report.receiptDeficitSessions.isEmpty)
    }

    // ═════════════════════════════════════════════════════════════════════════════════════════════
    // §8 — VERIFIER V6 ATTACKS NOT COVERED BY THE BUILDER SET (synthetic throwaway git fixtures)
    // ═════════════════════════════════════════════════════════════════════════════════════════════

    @discardableResult
    private func sh(_ root: URL, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git", "-C", root.path, "-c", "user.name=A21", "-c", "user.email=a21@audit"] + args
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

    /// Build a self-contained throwaway PASS repo. `resultRaw`/`lockRaw` closures receive the computed
    /// identity and return the EXACT JSON bytes to commit, so a probe can inject malformed counts,
    /// non-canonical JSON, missing fields, wrong anchor, etc. Returns the refusal (or nil if verify
    /// unexpectedly succeeded — which would itself be a finding).
    private struct Identity {
        let governing, anchor, candidate, tagName, tagObject, manifestPath, manifestSHA, invDigest, audit: String
    }
    private func buildRepo(mutateAnchorInResult: String? = nil,
                           resultBuilder: (Identity) -> String,
                           lockBuilder: (Identity, _ auditCommit: String, _ resultSHA: String) -> String
    ) throws -> Error? {
        let root = tempDir("v8")
        defer { try? FileManager.default.removeItem(at: root) }
        try sh(root, ["init", "-q"])
        try write(root, "seed.txt", "governing base\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "governing"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV6.governingTagName, "-m", "governing"])
        let gates = "{\"gates\": \"a21-v8\"}\n"; let code = "// a21 law\nlet law = 8\n"
        try write(root, "docs/prereg/gates.yaml", gates)
        try write(root, "code/method/RWCFixtureLaw.swift", code)
        try write(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
                  "{\"immutable_a\": \"x\", \"data_visibility\": false, \"corpus_count\": 0, \"annotator_count\": 0, \"real_fit_count\": 0, \"heldout_open_count\": 0}\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try sh(root, ["rev-parse", "HEAD"])
        let manifestPath = RWCCorpusEntryVerifierV6.canonicalFreezeManifestPath
        let artifacts: [(String, String)] = [("docs/prereg/gates.yaml", shaHex(gates)),
                                             ("code/method/RWCFixtureLaw.swift", shaHex(code))]
        let invDigest = shaHex(artifacts.map { "\($0.0):\($0.1)" }.sorted().joined(separator: "\n"))
        let manifest = """
        {"freeze_version": "rwc-preregistration-freeze-v8", "methodology_anchor_commit": "\(anchor)",
         "governing_control_plane_lock": "\(governing)", "frozen_inventory_digest": "\(invDigest)",
         "artifacts": [\(artifacts.map { "{\"path\": \"\($0.0)\", \"sha256\": \"\($0.1)\"}" }.joined(separator: ", "))],
         "surface_rules": {"governed_roots": ["docs/prereg", "code"], "post_anchor_allowed": [],
           "post_audit_allowances": [{"root": "code/auditevidence", "filename_prefix": "AUDIT"}], "hash_exempt": []}}
        """
        try write(root, manifestPath, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        let tagName = "a21-fixture-candidate"
        try sh(root, ["tag", "-a", tagName, "-m", "candidate"])
        let tagObject = try sh(root, ["rev-parse", "refs/tags/" + tagName])
        let id = Identity(governing: governing, anchor: mutateAnchorInResult ?? anchor, candidate: candidate,
                          tagName: tagName, tagObject: tagObject, manifestPath: manifestPath,
                          manifestSHA: shaHex(manifest), invDigest: invDigest, audit: "")
        let result = resultBuilder(id)
        try write(root, RWCPre14AuditResultV4.canonicalPath, result)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit"])
        let audit = try sh(root, ["rev-parse", "HEAD"])
        let lock = lockBuilder(id, audit, shaHex(result))
        try write(root, RWCPre14PassLockV4.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
        do { _ = try RWCCorpusEntryVerifierV6.verify(repoRoot: root); return nil }
        catch { return error }
    }

    // Canonical lock builder reused by the negative probes below.
    private func canonicalLock(_ id: Identity, _ auditCommit: String, _ resultSHA: String) -> String {
        """
        {"lock_version": "rwc-pre14-pass-lock-v4", "audit_result_path": "\(RWCPre14AuditResultV4.canonicalPath)",
         "audit_result_blob_sha256": "\(resultSHA)", "audit_commit": "\(auditCommit)",
         "candidate_commit": "\(id.candidate)", "candidate_tag_name": "\(id.tagName)",
         "candidate_tag_object_sha": "\(id.tagObject)", "freeze_manifest_path": "\(id.manifestPath)",
         "freeze_manifest_sha256": "\(id.manifestSHA)", "methodology_anchor_commit": "\(id.anchor)",
         "frozen_inventory_digest": "\(id.invDigest)", "governing_control_plane_lock": "\(id.governing)",
         "corpus_entry_authorized": true, "verdict": "PASS"}
        """
    }
    private func passResult(_ id: Identity, overrideCountsBlock: String? = nil) -> String {
        let counts = overrideCountsBlock ?? """
        "baseline_count": 2, "fresh_probe_count": 1, "total_count": 3,
        "critical_count": 0, "high_count": 0, "medium_count": 0
        """
        return """
        {"result_version": "rwc-pre14-audit-result-v4", "verdict": "PASS",
         "candidate_commit": "\(id.candidate)", "candidate_tag_name": "\(id.tagName)",
         "candidate_tag_object_sha": "\(id.tagObject)", "methodology_anchor_commit": "\(id.anchor)",
         "freeze_manifest_path": "\(id.manifestPath)", "freeze_manifest_sha256": "\(id.manifestSHA)",
         "frozen_inventory_digest": "\(id.invDigest)", "governing_control_plane_lock": "\(id.governing)",
         "audit_probe_family": "A21_FIXTURE", \(counts),
         "auditor_declaration": "SYNTHETIC A21"}
        """
    }

    /// §8 positive control: a well-formed synthetic PASS fixture is ACCEPTED (so the negative refusals
    /// below are real security refusals, not fixture breakage).
    func test_A21_V8_00_SyntheticPASS_Accepted_PositiveControl() throws {
        let e = try buildRepo(resultBuilder: { self.passResult($0) }, lockBuilder: canonicalLock)
        XCTAssertNil(e, "a well-formed synthetic PASS fixture MUST verify (positive control)")
    }

    /// §8.12 boolean count → typed parse refusal (not a crash, not acceptance).
    func test_A21_V8_01_BooleanCount_Refused() throws {
        let e = try buildRepo(resultBuilder: {
            self.passResult($0, overrideCountsBlock:
                "\"baseline_count\": true, \"fresh_probe_count\": 1, \"total_count\": 3, \"critical_count\": 0, \"high_count\": 0, \"medium_count\": 0")
        }, lockBuilder: canonicalLock)
        XCTAssertNotNil(e, "boolean baseline_count must be a typed refusal")
    }

    /// §8.12 floating-point count → refused.
    func test_A21_V8_02_FloatCount_Refused() throws {
        let e = try buildRepo(resultBuilder: {
            self.passResult($0, overrideCountsBlock:
                "\"baseline_count\": 2.5, \"fresh_probe_count\": 1, \"total_count\": 3, \"critical_count\": 0, \"high_count\": 0, \"medium_count\": 0")
        }, lockBuilder: canonicalLock)
        XCTAssertNotNil(e, "floating-point baseline_count must be refused")
    }

    /// §8.12 negative count → refused.
    func test_A21_V8_03_NegativeCount_Refused() throws {
        let e = try buildRepo(resultBuilder: {
            self.passResult($0, overrideCountsBlock:
                "\"baseline_count\": -1, \"fresh_probe_count\": 4, \"total_count\": 3, \"critical_count\": 0, \"high_count\": 0, \"medium_count\": 0")
        }, lockBuilder: canonicalLock)
        XCTAssertNotNil(e, "negative baseline_count must be refused")
    }

    /// §8.12 string count → refused.
    func test_A21_V8_04_StringCount_Refused() throws {
        let e = try buildRepo(resultBuilder: {
            self.passResult($0, overrideCountsBlock:
                "\"baseline_count\": \"2\", \"fresh_probe_count\": 1, \"total_count\": 3, \"critical_count\": 0, \"high_count\": 0, \"medium_count\": 0")
        }, lockBuilder: canonicalLock)
        XCTAssertNotNil(e, "string baseline_count must be refused")
    }

    /// §8.12 missing count field → refused.
    func test_A21_V8_05_MissingCount_Refused() throws {
        let e = try buildRepo(resultBuilder: { id in
            """
            {"result_version": "rwc-pre14-audit-result-v4", "verdict": "PASS",
             "candidate_commit": "\(id.candidate)", "candidate_tag_name": "\(id.tagName)",
             "candidate_tag_object_sha": "\(id.tagObject)", "methodology_anchor_commit": "\(id.anchor)",
             "freeze_manifest_path": "\(id.manifestPath)", "freeze_manifest_sha256": "\(id.manifestSHA)",
             "frozen_inventory_digest": "\(id.invDigest)", "governing_control_plane_lock": "\(id.governing)",
             "audit_probe_family": "A21_FIXTURE", "fresh_probe_count": 1, "total_count": 3,
             "critical_count": 0, "high_count": 0, "medium_count": 0,
             "auditor_declaration": "SYNTHETIC A21"}
            """
        }, lockBuilder: canonicalLock)
        XCTAssertNotNil(e, "missing baseline_count must be refused")
    }

    /// §8.13 baseline+fresh != total → auditCountInconsistent.
    func test_A21_V8_06_CountsDontSum_Refused() throws {
        let e = try buildRepo(resultBuilder: {
            self.passResult($0, overrideCountsBlock:
                "\"baseline_count\": 2, \"fresh_probe_count\": 1, \"total_count\": 99, \"critical_count\": 0, \"high_count\": 0, \"medium_count\": 0")
        }, lockBuilder: canonicalLock)
        XCTAssertNotNil(e, "baseline+fresh != total must be refused")
    }

    /// §8.14 PASS verdict but nonzero findings → auditFindingsOpen.
    func test_A21_V8_07_PassWithNonzeroFindings_Refused() throws {
        let e = try buildRepo(resultBuilder: {
            self.passResult($0, overrideCountsBlock:
                "\"baseline_count\": 2, \"fresh_probe_count\": 1, \"total_count\": 3, \"critical_count\": 1, \"high_count\": 0, \"medium_count\": 0")
        }, lockBuilder: canonicalLock)
        guard case .auditFindingsOpen = (e as? RWCCorpusEntryErrorV6) else {
            return XCTFail("expected auditFindingsOpen, got \(String(describing: e))")
        }
    }

    /// §8.7 wrong methodology anchor (a non-ancestor / mismatched commit) → refused.
    func test_A21_V8_08_WrongAnchor_Refused() throws {
        // Put a bogus anchor (the governing commit, which is NOT the manifest anchor) into the result;
        // the result↔lock / manifest cross-checks must refuse.
        let e = try buildRepo(resultBuilder: { id in
            self.passResult(Identity(governing: id.governing, anchor: id.governing, candidate: id.candidate,
                                     tagName: id.tagName, tagObject: id.tagObject, manifestPath: id.manifestPath,
                                     manifestSHA: id.manifestSHA, invDigest: id.invDigest, audit: ""))
        }, lockBuilder: canonicalLock)
        XCTAssertNotNil(e, "wrong methodology anchor must be refused")
    }

    /// §8.15 non-canonical JSON (trailing garbage / not a strict object) → refused at parse.
    func test_A21_V8_09_NonCanonicalJSON_Refused() throws {
        let e = try buildRepo(resultBuilder: { id in self.passResult(id) + "\nTRAILING GARBAGE NOT JSON" },
                              lockBuilder: canonicalLock)
        XCTAssertNotNil(e, "trailing non-JSON garbage must be refused")
    }

    /// §8.16 missing auditor provenance (auditor_declaration absent) → refused.
    func test_A21_V8_10_MissingAuditorProvenance_Refused() throws {
        let e = try buildRepo(resultBuilder: { id in
            """
            {"result_version": "rwc-pre14-audit-result-v4", "verdict": "PASS",
             "candidate_commit": "\(id.candidate)", "candidate_tag_name": "\(id.tagName)",
             "candidate_tag_object_sha": "\(id.tagObject)", "methodology_anchor_commit": "\(id.anchor)",
             "freeze_manifest_path": "\(id.manifestPath)", "freeze_manifest_sha256": "\(id.manifestSHA)",
             "frozen_inventory_digest": "\(id.invDigest)", "governing_control_plane_lock": "\(id.governing)",
             "audit_probe_family": "A21_FIXTURE", "baseline_count": 2, "fresh_probe_count": 1,
             "total_count": 3, "critical_count": 0, "high_count": 0, "medium_count": 0}
            """
        }, lockBuilder: canonicalLock)
        XCTAssertNotNil(e, "missing auditor_declaration provenance must be refused")
    }

    /// §8.1/§8.2 the REAL AUDIT19 and AUDIT20 FIX_REQUIRED results (verdict != PASS) cannot be used as a
    /// PASS even if placed at the canonical path. We simulate by committing a FIX_REQUIRED result.
    func test_A21_V8_11_RealFixRequiredVerdict_NeverPass() throws {
        let e = try buildRepo(resultBuilder: { id in
            self.passResult(id).replacingOccurrences(of: "\"verdict\": \"PASS\"", with: "\"verdict\": \"FIX_REQUIRED\"")
        }, lockBuilder: canonicalLock)
        guard case .auditVerdictNotPass = (e as? RWCCorpusEntryErrorV6) else {
            return XCTFail("expected auditVerdictNotPass, got \(String(describing: e))")
        }
    }

    /// §8 real-repo fail-closed: the ACTUAL R7 repository has NO PASS lock, so verify() throws
    /// .lockMissing. Creating the AUDIT21 result JSON must NOT change this (no PASS lock is ever created).
    func test_A21_V8_12_RealRepo_FailsClosed_LockMissing() throws {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV6.verify(repoRoot: repoRoot)) { e in
            guard case .lockMissing = (e as? RWCCorpusEntryErrorV6) else {
                return XCTFail("expected lockMissing on the real repo, got \(e)")
            }
        }
    }
}
#endif
