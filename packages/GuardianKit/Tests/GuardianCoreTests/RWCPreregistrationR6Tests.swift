#if os(macOS)
import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
import RWCAcquisition

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC PRE-14 R6 BUILDER TESTS — fresh family for the AUDIT19 remediation (1 CRITICAL A19-F1 + 2 HIGH
// A19-F2/F3 + 2 MEDIUM A19-F4/F5). Proves the R6 lawful corpus-entry path (trust root V2 → governed
// current registry V2 → authority V6 → grant V6 → store V4 + ledger-resident authorization → runner
// V4 acquire/reconcile → receipt store V2) works end-to-end with crash recovery, AND that every A19
// attack is refused on the R6 surfaces. R5 surfaces stay frozen SUPERSEDED_ENGINEERING_HISTORY.
// ZERO-DATA: synthetic fixtures only; no production root, no real asset.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class RWCPreregistrationR6Tests: XCTestCase {

    // MARK: helpers

    private func repoRoot() -> URL { RWCPowerDerivationV3.repoRootURL() }
    private func shaHex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func shaHex(_ d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }
    private func d3(_ s: String) -> RWCDateV3 { try! RWCDateV3.parse(s, field: "r6") }
    private func clock(_ s: String) -> RWCFixedClockV3 { try! RWCFixedClockV3(s) }
    private func tempDir(_ tag: String) -> URL {
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("r6-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    private final class SpyAcquirer: RWCAssetAcquirerV1 {
        var calls = 0
        let payload: Data
        init(_ payload: Data = Data("r6-synthetic-bytes".utf8)) { self.payload = payload }
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

    // lawful R6 rooted chain (synthetic V2 root + governed current registry V2)
    private func syntheticRootV2() -> (RWCVerifiedReviewerTrustRootV2, Curve25519.Signing.PrivateKey) {
        let r = RWCReviewerTrustRootLoaderV2.makeSyntheticTestRoot()
        return (r.root, r.privateKey)
    }
    private func signedDoc(rootID: String, rootPriv: Curve25519.Signing.PrivateKey, reviewerHex: String,
                           status: String = "ACTIVE", scope: RWCReviewerScopeV1 = .corpus,
                           role: String = "RIGHTS_REVIEW", registryRevision: Int = 1,
                           previousDigest: String? = nil) -> RWCReviewerRegistryDocumentV2 {
        let entry = RWCReviewerRegistryEntryV1(
            reviewerID: "rwc-reviewer-r6ctrl01", publicKeyRawHex: reviewerHex, status: status,
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
    private struct Chain {
        let root: RWCVerifiedReviewerTrustRootV2
        let rootPriv: Curve25519.Signing.PrivateKey
        let currentness: RWCReviewerRegistryCurrentnessStoreV1
        let registry: RWCVerifiedReviewerRegistryV2
        let reviewerKey: Curve25519.Signing.PrivateKey
        let doc: RWCReviewerRegistryDocumentV2
    }
    private func chain(dir: URL, status: String = "ACTIVE", scope: RWCReviewerScopeV1 = .corpus,
                       role: String = "RIGHTS_REVIEW") throws -> Chain {
        let (root, rootPriv) = syntheticRootV2()
        let reviewerKey = Curve25519.Signing.PrivateKey()
        let reviewerHex = reviewerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let doc = signedDoc(rootID: root.rootID, rootPriv: rootPriv, reviewerHex: reviewerHex,
                            status: status, scope: scope, role: role)
        let currentness = try RWCReviewerRegistryCurrentnessStoreV1.create(directory: dir)
        try currentness.advance(rootID: root.rootID, revision: 1, documentDigest: doc.documentDigest,
                                recordedDate: "2026-02-01")
        let reg = try RWCReviewerRegistryVerifierV2.verifyCurrent(document: doc, trustRoot: root,
                                                                  currentness: currentness, previousVerified: nil)
        return Chain(root: root, rootPriv: rootPriv, currentness: currentness, registry: reg,
                     reviewerKey: reviewerKey, doc: doc)
    }
    private func grant(id: String = "rwc-grant-r6aa0001", review: String = "rwc-review-r6rv0001",
                       allowed: [String] = ["training", "evaluation"], seed: String = "r6") -> RWCLegalGrantIdentityV1 {
        RWCLegalGrantIdentityV1(grantID: id, grantRevision: 1, evidenceDigest: shaHex("proof-\(id)-\(seed)"),
            evidencePointer: "rwc-rights-ref-r6p0001", rightsHolder: "licensor-r6",
            allowedUse: allowed, prohibitedUse: [], effectiveDate: d3("2026-08-01"),
            expiryDate: d3("2027-08-01"), reviewDecision: "APPROVED", reviewRecordID: review)
    }
    private func signedReview(_ g: RWCLegalGrantIdentityV1, source: RWCSourceAuthorizationV1,
                              key: Curve25519.Signing.PrivateKey, reviewerID: String = "rwc-reviewer-r6ctrl01"
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
    private func request(assetID: String = "rwc-asset-r6aaaa01", source: String = "rwc-source-ref-r6src0001",
                         use: RWCUseV1 = .training, session: String = "rwc-acq-r6session0000001"
    ) -> RWCAcquisitionRequestV1 {
        RWCAcquisitionRequestV1(assetID: assetID, sourceClass: .licensedRightsClear, sourceReference: source,
                                owner: "gen8", intendedUse: use, sessionID: session,
                                manifestSources: nil, trustedExpectedChecksum: nil)
    }

    // Synthetic V5 corpus-entry PASS proof (self-contained temp git repo; mirrors R5 makeFixtureV5).
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
    private func syntheticProof() throws -> (RWCVerifiedCorpusEntryV5, URL) {
        let root = tempDir("vfx6")
        try sh(root, ["init", "-q"])
        try write(root, "seed.txt", "governing base\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "governing"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV5.governingTagName, "-m", "governing"])
        let gates = "{\"gates\": \"fixture-v6\"}\n"
        let code = "// RWCFixtureLaw\nlet law = 6\n"
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
        try write(root, manifestPath, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        let tagName = "fixture-r6-candidate"
        try sh(root, ["tag", "-a", tagName, "-m", "candidate"])
        let tagObject = try sh(root, ["rev-parse", "refs/tags/" + tagName])
        let result = """
        {"result_version": "rwc-pre14-audit-result-v3", "verdict": "PASS",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "\(tagName)",
         "candidate_tag_object_sha": "\(tagObject)", "methodology_anchor_commit": "\(anchor)",
         "freeze_manifest_path": "\(manifestPath)", "freeze_manifest_sha256": "\(shaHex(manifest))",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "audit_probe_family": "R6_FIXTURE", "baseline_count": 2, "fresh_probe_count": 1,
         "total_count": 3, "critical_count": 0, "high_count": 0, "medium_count": 0,
         "auditor_declaration": "SYNTHETIC FIXTURE independent audit"}
        """
        try write(root, RWCPre14AuditResultV3.canonicalPath, result)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit"])
        let audit = try sh(root, ["rev-parse", "HEAD"])
        let lock = """
        {"lock_version": "rwc-pre14-pass-lock-v4", "audit_result_path": "\(RWCPre14AuditResultV3.canonicalPath)",
         "audit_result_blob_sha256": "\(shaHex(result))", "audit_commit": "\(audit)",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "\(tagName)",
         "candidate_tag_object_sha": "\(tagObject)", "freeze_manifest_path": "\(manifestPath)",
         "freeze_manifest_sha256": "\(shaHex(manifest))", "methodology_anchor_commit": "\(anchor)",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "corpus_entry_authorized": true, "verdict": "PASS"}
        """
        try write(root, RWCPre14PassLockV4.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
        let proof = try RWCCorpusEntryVerifierV5.verify(repoRoot: root)
        return (proof, root)
    }

    // MARK: F2 — trust root V2 structural unreachability

    func testR6_F2_TrustRootV2_NoPublicMint_FailClosed() throws {
        // production fails closed with a caller-chosen repoRoot (path != trust).
        XCTAssertThrowsError(try RWCReviewerTrustRootLoaderV2.loadProduction(repoRoot: repoRoot())) { e in
            XCTAssertEqual(e as? RWCReviewerTrustErrorV2, .noOperationalRoot)
        }
        let attackerDir = tempDir("f2-attacker")
        XCTAssertThrowsError(try RWCReviewerTrustRootLoaderV2.loadProduction(repoRoot: attackerDir)) { e in
            XCTAssertEqual(e as? RWCReviewerTrustErrorV2, .noOperationalRoot)
        }
        // lawful synthetic chain still mints a rooted V6 grant (test-only factory).
        let c = try chain(dir: tempDir("f2-cur"))
        defer { c.currentness.closeStore() }
        let g = grant()
        XCTAssertNoThrow(try grantV6(g, source: .exactSource("rwc-source-ref-r6src0001"), c))
        // operational root instance absent in R6.
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: repoRoot().appendingPathComponent(RWCReviewerTrustRootLoaderV2.canonicalInstancePath).path))
    }

    // MARK: F3 — governed current-registry head witness laws

    func testR6_F3_RegistryCurrentness_Monotonic_RollbackRefused() throws {
        let c = try chain(dir: tempDir("f3-cur"))
        defer { c.currentness.closeStore() }
        // revision > 1 with previousVerified:nil refused.
        let reviewerHex = c.reviewerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let rev5 = signedDoc(rootID: c.root.rootID, rootPriv: c.rootPriv, reviewerHex: reviewerHex,
                             registryRevision: 5, previousDigest: shaHex("garbage"))
        XCTAssertThrowsError(try RWCReviewerRegistryVerifierV2.verifyCurrent(
            document: rev5, trustRoot: c.root, currentness: c.currentness, previousVerified: nil)) { e in
            XCTAssertEqual(e as? RWCReviewerTrustErrorV2, .revisionWithoutAncestry(revision: 5))
        }
        // advance to rev2, then replaying rev1 is not current.
        let rev2 = signedDoc(rootID: c.root.rootID, rootPriv: c.rootPriv, reviewerHex: reviewerHex,
                             status: "REVOKED", registryRevision: 2, previousDigest: c.doc.documentDigest)
        try c.currentness.advance(rootID: c.root.rootID, revision: 2, documentDigest: rev2.documentDigest,
                                  recordedDate: "2026-03-01")
        XCTAssertThrowsError(try RWCReviewerRegistryVerifierV2.verifyCurrent(
            document: c.doc, trustRoot: c.root, currentness: c.currentness, previousVerified: nil)) { _ in }
        // the currentness store refuses a non-monotonic advance (rollback).
        XCTAssertThrowsError(try c.currentness.advance(rootID: c.root.rootID, revision: 1,
            documentDigest: c.doc.documentDigest, recordedDate: "2026-03-02")) { e in
            guard case .notMonotonic = (e as? RWCRegistryCurrentnessErrorV1) else {
                return XCTFail("expected notMonotonic, got \(e)")
            }
        }
        // durable reopen preserves the head.
        c.currentness.closeStore()
        let reopened = try RWCReviewerRegistryCurrentnessStoreV1.openExisting(directory: c.currentness.directory)
        defer { reopened.closeStore() }
        XCTAssertEqual(reopened.currentHead?.revision, 2)
        XCTAssertEqual(reopened.currentHead?.documentDigest, rev2.documentDigest)
    }

    // MARK: F1 — lawful acquire end-to-end + crash recovery on store V4 / runner V4

    func testR6_F1_LawfulAcquire_Promotes_ReceiptCompleted() throws {
        let (proof, fxRoot) = try syntheticProof()
        defer { try? FileManager.default.removeItem(at: fxRoot) }
        let c = try chain(dir: tempDir("f1-cur"))
        defer { c.currentness.closeStore() }
        let g = grant(allowed: ["training"])
        let vg = try grantV6(g, source: .exactSource("rwc-source-ref-r6src0001"), c)
        let qRoot = tempDir("f1-q")
        let store = try RWCAssetRightsLedgerStoreV4.create(directory: tempDir("f1-l").appendingPathComponent("l"))
        defer { store.closeStore() }
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: tempDir("f1-r"))
        defer { receipt.closeStore() }
        let corpus = FixtureCorpusStore()
        let spy = SpyAcquirer()
        let runner = RWCCorpusAcquisitionRunnerV4(quarantineRoot: qRoot)
        let r = try runner.acquire(proof: proof, request: request(), verifiedGrant: vg, rightsStore: store,
                                   corpusStore: corpus, acquirer: spy, clock: clock("2026-10-01"), receiptStore: receipt)
        XCTAssertEqual(r.assetID, "rwc-asset-r6aaaa01")
        XCTAssertEqual(corpus.promoted["rwc-asset-r6aaaa01"], spy.payload)
        XCTAssertEqual(try receipt.load("rwc-acq-r6session0000001").state, .completed)
        XCTAssertNotNil(store.authorizationRecord(forSession: "rwc-acq-r6session0000001"))
    }

    func testR6_F1_CrashBeforePromote_ReconcileV4_Recovers() throws {
        let (proof, fxRoot) = try syntheticProof()
        defer { try? FileManager.default.removeItem(at: fxRoot) }
        let c = try chain(dir: tempDir("f1c-cur"))
        defer { c.currentness.closeStore() }
        let g = grant(allowed: ["training"])
        let vg = try grantV6(g, source: .exactSource("rwc-source-ref-r6src0001"), c)
        let qRoot = tempDir("f1c-q")
        let store = try RWCAssetRightsLedgerStoreV4.create(directory: tempDir("f1c-l").appendingPathComponent("l"))
        defer { store.closeStore() }
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: tempDir("f1c-r"))
        defer { receipt.closeStore() }
        let corpus = FixtureCorpusStore()
        corpus.failPromote = true
        let runner = RWCCorpusAcquisitionRunnerV4(quarantineRoot: qRoot)
        // crash at promote: rights committed + authorization written + PREPARED receipt + quarantine kept.
        XCTAssertThrowsError(try runner.acquire(proof: proof, request: request(), verifiedGrant: vg,
            rightsStore: store, corpusStore: corpus, acquirer: SpyAcquirer(), clock: clock("2026-10-01"),
            receiptStore: receipt))
        XCTAssertEqual(try receipt.load("rwc-acq-r6session0000001").state, .prepared)
        XCTAssertNotNil(store.authorizationRecord(forSession: "rwc-acq-r6session0000001"))
        XCTAssertTrue(corpus.promoted.isEmpty)
        // reconcileV4 recovers: authorized quarantine → promote + finalize.
        corpus.failPromote = false
        let report = try runner.reconcileV4(rightsStore: store, corpusStore: corpus, receiptStore: receipt)
        XCTAssertEqual(report.recoveredSessions, ["rwc-acq-r6session0000001"])
        XCTAssertEqual(report.finalizedReceipts, ["rwc-acq-r6session0000001"])
        XCTAssertNotNil(corpus.promoted["rwc-asset-r6aaaa01"])
        XCTAssertEqual(try receipt.load("rwc-acq-r6session0000001").state, .completed)
        // idempotent.
        let report2 = try runner.reconcileV4(rightsStore: store, corpusStore: corpus, receiptStore: receipt)
        XCTAssertTrue(report2.recoveredSessions.isEmpty)
        XCTAssertTrue(report2.finalizedReceipts.isEmpty)
    }

    func testR6_F1_ForgedQuarantine_NoAuthorization_NeverPromotes() throws {
        // an attacker places a RIGHTS_COMMITTED metadata + payload but there is NO ledger authorization.
        let qRoot = tempDir("f1f-q")
        let store = try RWCAssetRightsLedgerStoreV4.create(directory: tempDir("f1f-l").appendingPathComponent("l"))
        defer { store.closeStore() }
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: tempDir("f1f-r"))
        defer { receipt.closeStore() }
        let session = "rwc-acq-r6forged00000001"
        let qdir = qRoot.appendingPathComponent("rwc-quarantine-\(session)", isDirectory: true)
        try FileManager.default.createDirectory(at: qdir, withIntermediateDirectories: true)
        try Data("smuggled".utf8).write(to: qdir.appendingPathComponent("payload"))
        let corpus = FixtureCorpusStore()
        let report = try RWCCorpusAcquisitionRunnerV4(quarantineRoot: qRoot)
            .reconcileV4(rightsStore: store, corpusStore: corpus, receiptStore: receipt)
        XCTAssertTrue(corpus.promoted.isEmpty)
        XCTAssertTrue(report.destroyedUnauthorizedSessions.contains(session))
    }

    func testR6_F1_RevokedAsset_NeverPromoted() throws {
        let (proof, fxRoot) = try syntheticProof()
        defer { try? FileManager.default.removeItem(at: fxRoot) }
        let c = try chain(dir: tempDir("f1rev-cur"))
        defer { c.currentness.closeStore() }
        let g = grant(allowed: ["training"])
        let vg = try grantV6(g, source: .exactSource("rwc-source-ref-r6src0001"), c)
        let qRoot = tempDir("f1rev-q")
        let store = try RWCAssetRightsLedgerStoreV4.create(directory: tempDir("f1rev-l").appendingPathComponent("l"))
        defer { store.closeStore() }
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: tempDir("f1rev-r"))
        defer { receipt.closeStore() }
        let corpus = FixtureCorpusStore()
        corpus.failPromote = true
        let runner = RWCCorpusAcquisitionRunnerV4(quarantineRoot: qRoot)
        XCTAssertThrowsError(try runner.acquire(proof: proof, request: request(), verifiedGrant: vg,
            rightsStore: store, corpusStore: corpus, acquirer: SpyAcquirer(), clock: clock("2026-10-01"),
            receiptStore: receipt))
        // revoke the asset, then reconcile → never promoted, quarantine destroyed as revoked.
        try store.revoke(assetID: "rwc-asset-r6aaaa01", clock: clock("2026-10-02"))
        corpus.failPromote = false
        let report = try runner.reconcileV4(rightsStore: store, corpusStore: corpus, receiptStore: receipt)
        XCTAssertTrue(corpus.promoted.isEmpty)
        XCTAssertTrue(report.destroyedRevokedSessions.contains("rwc-acq-r6session0000001"))
    }

    // MARK: F1 forged-V1-token cannot register into store V4 (type-level) — documented at compile time.
    // RWCAssetRightsLedgerStoreV4.register requires RWCVerifiedRightsGrantV6; the public no-crypto
    // RWCRightsReviewAuthorityV1.verify yields RWCVerifiedRightsGrantV1, which cannot be passed. This
    // is a compile-level guarantee asserted by the fact that this suite builds.

    // MARK: F4/F5 — strict receipt store V2

    func testR6_F4F5_ReceiptStoreV2_StrictScalars_StrictUse_AuthorityBound() throws {
        let c = try chain(dir: tempDir("f45-cur"))
        defer { c.currentness.closeStore() }
        let g = grant(allowed: ["training"])
        let vg = try grantV6(g, source: .exactSource("rwc-source-ref-r6src0001"), c)
        let store = try RWCAssetRightsLedgerStoreV4.create(directory: tempDir("f45-l").appendingPathComponent("l"))
        defer { store.closeStore() }
        let hash = shaHex("f45-bytes")
        let rec = RWCAssetRightsRecordV3(assetID: "rwc-asset-r6f45001", sourceClass: .licensedRightsClear,
            sourceReference: "rwc-source-ref-r6src0001", owner: "gen8", grant: g,
            acquisitionDate: d3("2026-08-15"), contentHash: hash, provenanceChain: ["rwc-source-ref-r6src0001"])
        try store.register(rec, verifiedGrant: vg, clock: clock("2026-08-15"))
        let authz = try store.authorizeAcquisition(sessionID: "rwc-acq-r6f4500000000001",
            assetID: "rwc-asset-r6f45001", contentHash: hash, intendedUse: .training,
            sourceReference: "rwc-source-ref-r6src0001", verifiedGrant: vg,
            candidateCommit: "f30b3932", auditResultBlobSHA256: shaHex("blob"), clock: clock("2026-08-15"))
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: tempDir("f45-r"))
        defer { receipt.closeStore() }
        // lawful prepare → PREPARED; authority copied from authz.
        let r = try receipt.prepare(authorization: authz, rightsLedgerHeadDigest: store.headDigest,
            rightsEventCount: store.eventCount, passLockCandidateCommit: "f30b3932",
            passLockTagObjectSHA: "e599cc9", auditResultBlobSHA256: shaHex("a"),
            freezeManifestSHA256: shaHex("f"), methodologyAnchorCommit: "anchor")
        XCTAssertEqual(r.legalGrantID, g.grantID)
        XCTAssertEqual(r.intendedUse, .training)
        XCTAssertEqual(try receipt.load("rwc-acq-r6f4500000000001").state, .prepared)
        // strict scalar: bad ledger head refused.
        let authz2 = try store.authorizeAcquisition(sessionID: "rwc-acq-r6f4500000000002",
            assetID: "rwc-asset-r6f45001", contentHash: hash, intendedUse: .training,
            sourceReference: "rwc-source-ref-r6src0001", verifiedGrant: vg,
            candidateCommit: "f30b3932", auditResultBlobSHA256: shaHex("blob2"), clock: clock("2026-08-15"))
        XCTAssertThrowsError(try receipt.prepare(authorization: authz2, rightsLedgerHeadDigest: "nothex",
            rightsEventCount: 0, passLockCandidateCommit: "c", passLockTagObjectSHA: "t",
            auditResultBlobSHA256: "a", freezeManifestSHA256: "f", methodologyAnchorCommit: "m")) { e in
            XCTAssertEqual(e as? RWCReceiptStoreErrorV2, .malformedScalar(field: "rightsLedgerHeadDigest"))
        }
        // strict use parse: a hand-written garbage use is a typed refusal on read.
        let dir = tempDir("f45-use")
        let s0 = try RWCAcquisitionReceiptStoreV2(directory: dir); s0.closeStore()
        let session = "rwc-acq-r6f45use00000001"
        let body = "{\"v\":\"rwc-acq-receipt-v2\",\"state\":\"PREPARED\",\"session\":\"\(session)\"," +
            "\"asset\":\"rwc-asset-r6f45001\",\"hash\":\"\(hash)\",\"use\":\"garbage\",\"grant\":\"rwc-grant-u\"," +
            "\"rev\":1,\"review\":\"rwc-review-u\",\"reviewer\":\"rwc-reviewer-u\",\"ledgerHead\":\"\(shaHex("h"))\"," +
            "\"eventCount\":0,\"candidate\":\"c\",\"tagObj\":\"t\",\"auditBlob\":\"a\",\"freeze\":\"f\"," +
            "\"anchor\":\"m\",\"tx\":\"2026-08-15\"}"
        let line = body + "\n" + shaHex(body) + "\n"
        try Data(line.utf8).write(to: dir.appendingPathComponent("receipt-v2-\(session).json"))
        let s2 = try RWCAcquisitionReceiptStoreV2(directory: dir)
        defer { s2.closeStore() }
        XCTAssertThrowsError(try s2.load(session)) { e in
            XCTAssertEqual(e as? RWCReceiptStoreErrorV2, .malformedUse("garbage"))
        }
    }

    // MARK: F5 — strict intendedUse everywhere (request enum is already typed; evaluator refuses bad class)

    func testR6_F5_IntendedUse_TypedAtRequest_And_EvaluatorRefusesIneligibleClass() throws {
        let c = try chain(dir: tempDir("f5-cur"))
        defer { c.currentness.closeStore() }
        let g = grant(allowed: ["training"])
        let vg = try grantV6(g, source: .exactSource("rwc-source-ref-r6src0001"), c)
        // ineligible source class → refuse pre-fetch (no silent default anywhere).
        let bad = RWCAcquisitionRequestV1(assetID: "rwc-asset-r6f5aaa1", sourceClass: .refusedScraped,
            sourceReference: "rwc-source-ref-r6src0001", owner: "gen8", intendedUse: .training,
            sessionID: "rwc-acq-r6f5session00001", manifestSources: nil, trustedExpectedChecksum: nil)
        XCTAssertThrowsError(try RWCPreAcquisitionEvaluatorV3.authorize(
            request: bad, verifiedGrant: vg, transactionDate: d3("2026-08-20")))
        // intendedUse not in the grant's allowed set → refuse.
        let evalReq = RWCAcquisitionRequestV1(assetID: "rwc-asset-r6f5aaa2", sourceClass: .licensedRightsClear,
            sourceReference: "rwc-source-ref-r6src0001", owner: "gen8", intendedUse: .evaluation,
            sessionID: "rwc-acq-r6f5session00002", manifestSources: nil, trustedExpectedChecksum: nil)
        XCTAssertThrowsError(try RWCPreAcquisitionEvaluatorV3.authorize(
            request: evalReq, verifiedGrant: vg, transactionDate: d3("2026-08-20")))
    }
}
#endif
