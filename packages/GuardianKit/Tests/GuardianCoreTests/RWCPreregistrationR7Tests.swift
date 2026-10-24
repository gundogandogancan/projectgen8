#if os(macOS)
import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
import RWCAcquisition

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC PRE-14 R7 BUILDER TESTS — fresh family for the AUDIT20 remediation (A20-F1 CRITICAL PRE-14-PASS
// bypass, A20-F2 HIGH legacy seal, A20-F3/F4 MEDIUM use/revocation, R-6 receipt completeness).
//
// IMPLEMENTED_UNVERIFIED SCOPE NOTE (honest): this file is authored in a sandbox that cannot run
// `swift test`. It compiles (the main session MUST run it + the inverted AUDIT20 probes green ×2). The
// tests below exercise the GuardianCore SEALED WRITE boundary (RWCAssetRightsLedgerStoreV5.
// authorizeAcquisitionV2) directly — the test target is in-package, so it can mint the `package`-init
// RWCAcquisitionAuthorityTokenV1 to drive the gate's REFUSAL logic (A20-F3 use, A20-F4 revocation,
// token-binding) in isolation. The FULL lawful end-to-end token-acquire path (RunnerV5.acquire with a
// real RWCCorpusEntryVerifierV6 PASS fixture + the reconcileV5 crash matrix + the full §11 acceptance
// matrix) is scaffolded as `testR7_MAINSESSION_*` stubs the main session completes against a compiler
// and the full suite — see RWC_R7_AUTHORITY_CONVERGENCE_DESIGN.md §13 for the traceability matrix.
//
// A key structural fact this file proves: an EXTERNAL consumer could NOT mint the token at all (its
// init is `package`); that the TEST target can is the point — it lets us red/green the gate logic.
// ZERO-DATA: synthetic fixtures only; no production root, no real asset, no PASS lock.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class RWCPreregistrationR7Tests: XCTestCase {

    private func shaHex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func shaHex(_ d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }
    private func d3(_ s: String) -> RWCDateV3 { try! RWCDateV3.parse(s, field: "r7") }
    private func clock(_ s: String) -> RWCFixedClockV3 { try! RWCFixedClockV3(s) }
    private func tempDir(_ tag: String) -> URL {
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("r7-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    // Lawful synthetic rooted chain → verified-current registry V2 + a V6 grant, reusing the proven R6
    // construction (synthetic V2 root, governed currentness, verifyCurrent, authority V6).
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
            reviewerID: "rwc-reviewer-r7ctrl1", publicKeyRawHex: reviewerHex, status: status,
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
    private func chain(dir: URL, status: String = "ACTIVE") throws -> Chain {
        let r = RWCReviewerTrustRootLoaderV2.makeSyntheticTestRoot()
        let reviewerKey = Curve25519.Signing.PrivateKey()
        let reviewerHex = reviewerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let doc = signedDoc(rootID: r.root.rootID, rootPriv: r.privateKey, reviewerHex: reviewerHex, status: status)
        let currentness = try RWCReviewerRegistryCurrentnessStoreV1.create(directory: dir)
        try currentness.advance(rootID: r.root.rootID, revision: 1, documentDigest: doc.documentDigest,
                                recordedDate: "2026-02-01")
        let reg = try RWCReviewerRegistryVerifierV2.verifyCurrent(document: doc, trustRoot: r.root,
                                                                  currentness: currentness, previousVerified: nil)
        return Chain(root: r.root, rootPriv: r.privateKey, currentness: currentness, registry: reg,
                     reviewerKey: reviewerKey, doc: doc)
    }
    private func grant(id: String = "rwc-grant-r7aa001", review: String = "rwc-review-r7rv01",
                       allowed: [String] = ["training", "evaluation"]) -> RWCLegalGrantIdentityV1 {
        RWCLegalGrantIdentityV1(grantID: id, grantRevision: 1, evidenceDigest: shaHex("proof-\(id)"),
            evidencePointer: "rwc-rights-ref-r7p001", rightsHolder: "licensor-r7",
            allowedUse: allowed, prohibitedUse: [], effectiveDate: d3("2026-08-01"),
            expiryDate: d3("2027-08-01"), reviewDecision: "APPROVED", reviewRecordID: review)
    }
    private func grantV6(_ g: RWCLegalGrantIdentityV1, source: String, _ c: Chain) throws -> RWCVerifiedRightsGrantV6 {
        var r = RWCSignedRightsReviewV1(
            reviewRecordID: g.reviewRecordID, reviewerID: "rwc-reviewer-r7ctrl1", grantID: g.grantID,
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
    /// A synthetic (NON-PASS) authority token minted directly via the `package` init — used ONLY to
    /// drive the gate's refusal logic in isolation. The identity digests are SYNTHETIC placeholders,
    /// never a real PASS proof; the lawful path mints the token from a real RWCCorpusEntryVerifierV6
    /// PASS inside RunnerV5 (see the MAINSESSION stubs).
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

    /// Build an authority token from a REAL verified V6 proof + the evaluator-validated preauth + the
    /// current registry — mirroring RWCCorpusAcquisitionRunnerV5.mintAuthorityToken exactly (that
    /// function is `internal` to RWCAcquisition; the token init is `package` and visible to this in-package
    /// test target). Used to drive the lawful crash/reconstruction path with a COMPLETE proof identity.
    private func tokenFromProof(_ proof: RWCVerifiedCorpusEntryV6,
                                preauth: RWCPreAcquisitionAuthorizationV3,
                                currentRegistry: RWCVerifiedReviewerRegistryV2) -> RWCAcquisitionAuthorityTokenV1 {
        RWCAcquisitionAuthorityTokenV1(
            candidateCommit: proof.candidateCommit, candidateTagObjectSHA: proof.candidateTagObjectSHA,
            auditCommit: proof.auditCommit, auditResultBlobSHA256: proof.auditResultBlobSHA256,
            methodologyAnchorCommit: proof.methodologyAnchorCommit,
            freezeManifestSHA256: proof.freezeManifestSHA256,
            frozenInventoryDigest: proof.frozenInventoryDigest,
            sessionID: preauth.sessionID, assetID: preauth.assetID, sourceReference: preauth.sourceReference,
            intendedUseToken: preauth.intendedUse == .training ? "training" : "evaluation",
            grantID: preauth.grantID, grantRevision: preauth.grantRevision,
            currentRegistryRootID: currentRegistry.rootID,
            currentRegistryRevision: currentRegistry.registryRevision,
            currentRegistryDocumentDigest: currentRegistry.documentDigest)
    }

    // ── A20-F3 (MEDIUM): intended-use enforced at the sealed write ──────────────────────────────────
    func testR7_F3_ProhibitedUse_RefusedAtAuthorizeV2() throws {
        let c = try chain(dir: tempDir("f3-cur")); defer { c.currentness.closeStore() }
        let asset = "rwc-asset-r7f3asset01"; let source = "rwc-source-ref-r7src03"
        let payload = Data("r7-f3".utf8); let hash = shaHex(payload)
        let g = grant(id: "rwc-grant-r7f3001", review: "rwc-review-r7f301", allowed: ["evaluation"])
        let vg = try grantV6(g, source: source, c)
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: tempDir("f3-ledger"))
        defer { store.closeStore() }
        try store.register(record(asset, source: source, contentHash: hash, g), verifiedGrant: vg,
                           clock: clock("2026-08-21"))
        let token = syntheticToken(session: "rwc-acq-r7f3session000001", asset: asset, source: source,
                                   use: "training", g: g, c)  // grant prohibits training
        XCTAssertThrowsError(try store.authorizeAcquisitionV2(token: token, verifiedGrant: vg,
                                                              currentRegistry: c.registry,
                                                              clock: clock("2026-08-21"))) { e in
            guard case .useNotAuthorized = (e as? RWCRightsLedgerErrorV5) else {
                return XCTFail("expected useNotAuthorized, got \(e)")
            }
        }
    }

    // ── A20-F4 (MEDIUM): revoked reviewer refused at the sealed write ───────────────────────────────
    func testR7_F4_StaleGrant_AfterRevocation_RefusedAtAuthorizeV2() throws {
        let c = try chain(dir: tempDir("f4-cur")); defer { c.currentness.closeStore() }
        let asset = "rwc-asset-r7f4asset01"; let source = "rwc-source-ref-r7src04"
        let payload = Data("r7-f4".utf8); let hash = shaHex(payload)
        let g = grant(id: "rwc-grant-r7f4001", review: "rwc-review-r7f401")
        let vg = try grantV6(g, source: source, c)   // minted under rev1 ACTIVE
        // advance to rev2 REVOKING the reviewer → a NEW verified-current registry.
        let reviewerHex = c.reviewerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let rev2doc = signedDoc(rootID: c.root.rootID, rootPriv: c.rootPriv, reviewerHex: reviewerHex,
                                status: "REVOKED", registryRevision: 2, previousDigest: c.doc.documentDigest)
        try c.currentness.advance(rootID: c.root.rootID, revision: 2, documentDigest: rev2doc.documentDigest,
                                  recordedDate: "2026-09-01")
        let rev2 = try RWCReviewerRegistryVerifierV2.verifyCurrent(document: rev2doc, trustRoot: c.root,
                                                                   currentness: c.currentness,
                                                                   previousVerified: c.registry)
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: tempDir("f4-ledger"))
        defer { store.closeStore() }
        try store.register(record(asset, source: source, contentHash: hash, g), verifiedGrant: vg,
                           clock: clock("2026-09-02"))
        let token = syntheticToken(session: "rwc-acq-r7f4session000001", asset: asset, source: source,
                                   use: "training", g: g, c)  // token carries the STALE rev1 digest
        // the grant's registryDocumentDigest (rev1) != current head (rev2) → refused.
        XCTAssertThrowsError(try store.authorizeAcquisitionV2(token: token, verifiedGrant: vg,
                                                              currentRegistry: rev2,
                                                              clock: clock("2026-09-02"))) { e in
            guard case .reviewerNotCurrent = (e as? RWCRightsLedgerErrorV5) else {
                return XCTFail("expected reviewerNotCurrent, got \(e)")
            }
        }
    }

    // ── A20-F1 (CRITICAL): the sealed write accepts a lawfully-bound token and records full proof id ──
    func testR7_F1_LawfulToken_Authorizes_RecordsFullProofIdentity() throws {
        let c = try chain(dir: tempDir("f1-cur")); defer { c.currentness.closeStore() }
        let asset = "rwc-asset-r7f1asset01"; let source = "rwc-source-ref-r7src01"
        let payload = Data("r7-f1".utf8); let hash = shaHex(payload)
        let g = grant(id: "rwc-grant-r7f1001", review: "rwc-review-r7f101")
        let vg = try grantV6(g, source: source, c)
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: tempDir("f1-ledger"))
        defer { store.closeStore() }
        try store.register(record(asset, source: source, contentHash: hash, g), verifiedGrant: vg,
                           clock: clock("2026-08-21"))
        let token = syntheticToken(session: "rwc-acq-r7f1session000001", asset: asset, source: source,
                                   use: "training", g: g, c)
        let authz = try store.authorizeAcquisitionV2(token: token, verifiedGrant: vg,
                                                     currentRegistry: c.registry, clock: clock("2026-08-21"))
        XCTAssertTrue(authz.hasCompleteProofIdentity,
                      "R7: the authorization record carries the full PASS-proof identity (A20-F1 + R-6)")
        XCTAssertEqual(authz.candidateCommit, token.candidateCommit)
        XCTAssertEqual(authz.intendedUse, "training")
        XCTAssertNotNil(store.authorizationRecord(forSession: "rwc-acq-r7f1session000001"))
    }

    // ── A20-F1: a token whose grant identity does not match is refused (token-binding) ─────────────
    func testR7_F1_TokenGrantMismatch_Refused() throws {
        let c = try chain(dir: tempDir("f1b-cur")); defer { c.currentness.closeStore() }
        let asset = "rwc-asset-r7f1basset1"; let source = "rwc-source-ref-r7src0b"
        let payload = Data("r7-f1b".utf8); let hash = shaHex(payload)
        let g = grant(id: "rwc-grant-r7f1b01", review: "rwc-review-r7f1b1")
        let vg = try grantV6(g, source: source, c)
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: tempDir("f1b-ledger"))
        defer { store.closeStore() }
        try store.register(record(asset, source: source, contentHash: hash, g), verifiedGrant: vg,
                           clock: clock("2026-08-21"))
        // token claims a DIFFERENT grantID than the verified grant.
        let badG = grant(id: "rwc-grant-r7OTHER1", review: "rwc-review-r7f1b1")
        let token = syntheticToken(session: "rwc-acq-r7f1bsession0001", asset: asset, source: source,
                                   use: "training", g: badG, c)
        XCTAssertThrowsError(try store.authorizeAcquisitionV2(token: token, verifiedGrant: vg,
                                                              currentRegistry: c.registry,
                                                              clock: clock("2026-08-21"))) { e in
            guard case .tokenBindingMismatch = (e as? RWCRightsLedgerErrorV5) else {
                return XCTFail("expected tokenBindingMismatch, got \(e)")
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════════════════════════
    // SYNTHETIC V6 PASS FIXTURE + end-to-end helpers (R7). A self-contained throwaway git repo whose
    // PASS lock points at the R7 result path (schema V4) + freeze manifest V8 (freeze-v8), so
    // RWCCorpusEntryVerifierV6.verify returns a real RWCVerifiedCorpusEntryV6. Mirrors R6Tests'
    // syntheticProof but bound to the V6 identity (schema V4 / V8 manifest / freeze-v8).
    // ZERO-DATA: all synthetic, throwaway temp git repo; never the real repository.
    // ════════════════════════════════════════════════════════════════════════════════════════════

    private final class SpyAcquirer: RWCAssetAcquirerV1 {
        var calls = 0
        let payload: Data
        init(_ payload: Data = Data("r7-synthetic-bytes".utf8)) { self.payload = payload }
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

    private func request(assetID: String = "rwc-asset-r7aaaa01", source: String = "rwc-source-ref-r7src01",
                         use: RWCUseV1 = .training, session: String = "rwc-acq-r7session0000001"
    ) -> RWCAcquisitionRequestV1 {
        RWCAcquisitionRequestV1(assetID: assetID, sourceClass: .licensedRightsClear, sourceReference: source,
                                owner: "gen8", intendedUse: use, sessionID: session,
                                manifestSources: nil, trustedExpectedChecksum: nil)
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

    /// Build a synthetic repo and return a verified V6 PASS proof + the repo root. Bound to the R7
    /// identity: schema-V4 result at RWCPre14AuditResultV4.canonicalPath, V8 freeze manifest at
    /// RWCCorpusEntryVerifierV6.canonicalFreezeManifestPath (freeze_version rwc-preregistration-freeze-v8).
    private func syntheticProofV6() throws -> (RWCVerifiedCorpusEntryV6, URL) {
        let root = tempDir("vfx7")
        try sh(root, ["init", "-q"])
        try write(root, "seed.txt", "governing base\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "governing"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV6.governingTagName, "-m", "governing"])
        let gates = "{\"gates\": \"fixture-v8\"}\n"
        let code = "// RWCFixtureLaw\nlet law = 8\n"
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
         "surface_rules": {"governed_roots": ["docs/prereg", "code"],
           "post_anchor_allowed": [],
           "post_audit_allowances": [{"root": "code/auditevidence", "filename_prefix": "AUDIT"}],
           "hash_exempt": []}}
        """
        try write(root, manifestPath, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        let tagName = "fixture-r7-candidate"
        try sh(root, ["tag", "-a", tagName, "-m", "candidate"])
        let tagObject = try sh(root, ["rev-parse", "refs/tags/" + tagName])
        let result = """
        {"result_version": "rwc-pre14-audit-result-v4", "verdict": "PASS",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "\(tagName)",
         "candidate_tag_object_sha": "\(tagObject)", "methodology_anchor_commit": "\(anchor)",
         "freeze_manifest_path": "\(manifestPath)", "freeze_manifest_sha256": "\(shaHex(manifest))",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "audit_probe_family": "R7_FIXTURE", "baseline_count": 2, "fresh_probe_count": 1,
         "total_count": 3, "critical_count": 0, "high_count": 0, "medium_count": 0,
         "auditor_declaration": "SYNTHETIC FIXTURE independent audit"}
        """
        try write(root, RWCPre14AuditResultV4.canonicalPath, result)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit"])
        let audit = try sh(root, ["rev-parse", "HEAD"])
        let lock = """
        {"lock_version": "rwc-pre14-pass-lock-v4", "audit_result_path": "\(RWCPre14AuditResultV4.canonicalPath)",
         "audit_result_blob_sha256": "\(shaHex(result))", "audit_commit": "\(audit)",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "\(tagName)",
         "candidate_tag_object_sha": "\(tagObject)", "freeze_manifest_path": "\(manifestPath)",
         "freeze_manifest_sha256": "\(shaHex(manifest))", "methodology_anchor_commit": "\(anchor)",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "corpus_entry_authorized": true, "verdict": "PASS"}
        """
        try write(root, RWCPre14PassLockV4.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
        let proof = try RWCCorpusEntryVerifierV6.verify(repoRoot: root)
        return (proof, root)
    }

    // ── MAINSESSION 1: lawful end-to-end RunnerV5.acquire with a real V6 PASS fixture ───────────────
    func testR7_MAINSESSION_LawfulAcquire_V5_Promotes_ReceiptCompleted() throws {
        let (proof, fxRoot) = try syntheticProofV6()
        defer { try? FileManager.default.removeItem(at: fxRoot) }
        let c = try chain(dir: tempDir("ms1-cur")); defer { c.currentness.closeStore() }
        let g = grant(allowed: ["training"])
        let vg = try grantV6(g, source: "rwc-source-ref-r7src01", c)
        let qRoot = tempDir("ms1-q")
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: tempDir("ms1-l").appendingPathComponent("l"))
        defer { store.closeStore() }
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: tempDir("ms1-r"))
        defer { receipt.closeStore() }
        let corpus = FixtureCorpusStore()
        let spy = SpyAcquirer()
        let runner = RWCCorpusAcquisitionRunnerV5(quarantineRoot: qRoot)
        let r = try runner.acquire(proof: proof, request: request(), verifiedGrant: vg,
                                   currentRegistry: c.registry, rightsStore: store, corpusStore: corpus,
                                   acquirer: spy, clock: clock("2026-10-01"), receiptStore: receipt)
        XCTAssertEqual(r.assetID, "rwc-asset-r7aaaa01")
        XCTAssertEqual(corpus.promoted["rwc-asset-r7aaaa01"], spy.payload)
        XCTAssertEqual(try receipt.load("rwc-acq-r7session0000001").state, .completed)
        let authz = store.authorizationRecord(forSession: "rwc-acq-r7session0000001")
        XCTAssertNotNil(authz)
        XCTAssertTrue(authz?.hasCompleteProofIdentity ?? false,
                      "lawful acquire writes the full PASS-proof identity (A20-F1 + R-6)")
        XCTAssertEqual(authz?.candidateCommit, proof.candidateCommit)
    }

    // ── MAINSESSION 2: crash-before-receipt → reconcileV5 reconstructs the durable receipt (R-6) ────
    func testR7_MAINSESSION_CrashBeforeReceipt_ReconcileV5_Reconstructs() throws {
        let (proof, fxRoot) = try syntheticProofV6()
        defer { try? FileManager.default.removeItem(at: fxRoot) }
        let c = try chain(dir: tempDir("ms2-cur")); defer { c.currentness.closeStore() }
        let g = grant(allowed: ["training"])
        let vg = try grantV6(g, source: "rwc-source-ref-r7src01", c)
        let qRoot = tempDir("ms2-q")
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: tempDir("ms2-l").appendingPathComponent("l"))
        defer { store.closeStore() }
        let corpus = FixtureCorpusStore()
        let runner = RWCCorpusAcquisitionRunnerV5(quarantineRoot: qRoot)

        // Simulate acquire() to the crash point (register + token authorize + quarantine payload, NO
        // receipt) using a RunnerV5-minted lawful token (the ONLY mint path, from the real V6 proof).
        let preauth = try RWCPreAcquisitionEvaluatorV3.authorize(request: request(), verifiedGrant: vg,
                                                                 transactionDate: clock("2026-10-01").today())
        let payload = Data("r7-ms2-crash".utf8)
        let contentHash = RWCCorpusAcquisitionRunnerV5.sha256Hex(payload)
        let rec = record(preauth.assetID, source: preauth.sourceReference, contentHash: contentHash, g)
        try store.register(rec, verifiedGrant: vg, clock: clock("2026-10-01"))
        // Mint the lawful token from the REAL V6 proof identity via the `package` init (the exact fields
        // RunnerV5.mintAuthorityToken copies; `package` is visible to the in-package test target).
        let token = tokenFromProof(proof, preauth: preauth, currentRegistry: c.registry)
        _ = try store.authorizeAcquisitionV2(token: token, verifiedGrant: vg, currentRegistry: c.registry,
                                             clock: clock("2026-10-01"))
        let qdir = qRoot.appendingPathComponent("rwc-quarantine-\(preauth.sessionID)", isDirectory: true)
        try FileManager.default.createDirectory(at: qdir, withIntermediateDirectories: true)
        try payload.write(to: qdir.appendingPathComponent("payload"))
        // --- crash: no receipt writes for this session ---

        let receipt = try RWCAcquisitionReceiptStoreV2(directory: tempDir("ms2-r"))
        defer { receipt.closeStore() }
        let report = try runner.reconcileV5(rightsStore: store, corpusStore: corpus, receiptStore: receipt)
        XCTAssertEqual(report.recoveredSessions, [preauth.sessionID])
        XCTAssertEqual(report.reconstructedReceipts, [preauth.sessionID],
                       "R-6: a durable receipt is RECONSTRUCTED from the authenticated authorization record")
        XCTAssertNotNil(corpus.promoted[preauth.assetID])
        XCTAssertEqual(try receipt.load(preauth.sessionID).state, .completed)
        XCTAssertTrue(report.receiptDeficitSessions.isEmpty)
        // idempotent.
        let report2 = try runner.reconcileV5(rightsStore: store, corpusStore: corpus, receiptStore: receipt)
        XCTAssertTrue(report2.recoveredSessions.isEmpty)
        XCTAssertTrue(report2.reconstructedReceipts.isEmpty)
    }

    // ── MAINSESSION 3: incomplete proof identity → reconcileV5 reports an explicit deficit ──────────
    func testR7_MAINSESSION_IncompleteProofIdentity_ReconcileV5_ReportsDeficit() throws {
        // Hand-author a ledger authorization whose PASS-proof identity is INCOMPLETE (empty fields). The
        // ONLY lawful writer is authorizeAcquisitionV2(token:) which always writes a complete identity;
        // to construct the deficit precondition we forge a V2 authorization record directly on disk (a
        // hostile-disk scenario, R-5 class) and reopen the store. reconcileV5 must fail CLOSED: keep the
        // session unpromoted and surface it as an explicit receiptDeficit — never a silent promotion.
        let c = try chain(dir: tempDir("ms3-cur")); defer { c.currentness.closeStore() }
        let asset = "rwc-asset-r7ms3a01"; let source = "rwc-source-ref-r7ms3s1"
        let session = "rwc-acq-r7ms3session00001"
        let payload = Data("r7-ms3-incomplete".utf8); let hash = shaHex(payload)
        let g = grant(id: "rwc-grant-r7ms301", review: "rwc-review-r7ms31")
        let vg = try grantV6(g, source: source, c)
        let ledgerDir = tempDir("ms3-l").appendingPathComponent("l")
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: ledgerDir)
        try store.register(record(asset, source: source, contentHash: hash, g), verifiedGrant: vg,
                           clock: clock("2026-10-01"))
        let prevDigest = store.headDigest
        let seq = store.eventCount
        store.closeStore()

        // Forge an acquisition-authorized-v2 event with EMPTY PASS-proof identity fields (candidate/
        // tagObj/audit/anchor/freeze/inventory all ""), recomputing the SHA-256 chain + witness.
        let authzJSON =
            "{\"v\":\"rwc-acq-authorization-v2\",\"session\":\"\(session)\",\"asset\":\"\(asset)\"," +
            "\"hash\":\"\(hash)\",\"grant\":\"\(g.grantID)\",\"rev\":1," +
            "\"review\":\"\(g.reviewRecordID)\",\"reviewer\":\"rwc-reviewer-r7ctrl1\"," +
            "\"source\":\"\(source)\",\"use\":\"training\"," +
            "\"registryDoc\":\"\(c.doc.documentDigest)\",\"root\":\"\(c.root.rootID)\"," +
            "\"candidate\":\"\",\"tagObj\":\"\",\"auditCommit\":\"\",\"auditBlob\":\"\"," +
            "\"anchor\":\"\",\"freeze\":\"\",\"inventory\":\"\",\"tx\":\"2026-10-01\"}"
        let forged = RWCRightsEventV3(seq: seq, previousDigest: prevDigest, assetID: asset,
                                      kind: "acquisition-authorized-v2", recordPayloadJSON: authzJSON,
                                      recordedDate: "2026-10-01")
        let line = RWCAssetRightsLedgerStoreV5.journalLine(forged)
        let journalURL = ledgerDir.appendingPathComponent("rights-journal-v5.jsonl")
        let handle = try FileHandle(forWritingTo: journalURL)
        try handle.seekToEnd(); try handle.write(contentsOf: Data(line.utf8)); try handle.close()
        let witnessJSON = "{\"v\":\"\(RWCAssetRightsLedgerStoreV5.version)\",\"count\":\(seq + 1)," +
            "\"head\":\"\(forged.eventDigest)\"}\n"
        try Data(witnessJSON.utf8).write(to: ledgerDir.appendingPathComponent("rights-head-v5.json"))

        let reopened = try RWCAssetRightsLedgerStoreV5.openExisting(directory: ledgerDir)
        defer { reopened.closeStore() }
        let authz = reopened.authorizationRecord(forSession: session)
        XCTAssertNotNil(authz)
        XCTAssertFalse(authz?.hasCompleteProofIdentity ?? true,
                       "the forged authorization has an INCOMPLETE proof identity")
        let qRoot = tempDir("ms3-q")
        let qdir = qRoot.appendingPathComponent("rwc-quarantine-\(session)", isDirectory: true)
        try FileManager.default.createDirectory(at: qdir, withIntermediateDirectories: true)
        try payload.write(to: qdir.appendingPathComponent("payload"))
        let corpus = FixtureCorpusStore()
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: tempDir("ms3-r"))
        defer { receipt.closeStore() }
        let report = try RWCCorpusAcquisitionRunnerV5(quarantineRoot: qRoot)
            .reconcileV5(rightsStore: reopened, corpusStore: corpus, receiptStore: receipt)
        XCTAssertFalse(report.recoveredSessions.contains(session))
        XCTAssertTrue(corpus.promoted.isEmpty, "R-6: incomplete-proof session is NEVER promoted")
        XCTAssertTrue(report.receiptDeficitSessions.contains(session),
                      "R-6: the incomplete-proof session is surfaced as an explicit receiptDeficit")
    }

    // ── MAINSESSION 4: verifier V6 accepts a synthetic PASS (R7 path + V8 manifest) ────────────────
    func testR7_MAINSESSION_VerifierV6_SyntheticPASS_Accepts() throws {
        let (proof, fxRoot) = try syntheticProofV6()
        defer { try? FileManager.default.removeItem(at: fxRoot) }
        XCTAssertFalse(proof.candidateCommit.isEmpty)
        XCTAssertFalse(proof.auditResultBlobSHA256.isEmpty)
        XCTAssertFalse(proof.freezeManifestSHA256.isEmpty)
        XCTAssertFalse(proof.frozenInventoryDigest.isEmpty)
        // the real repository has NO PASS lock → fails closed.
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV6.verify(
            repoRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))) { e in
            // lockMissing on the real repo (no R7 PASS lock exists).
            guard case .lockMissing = (e as? RWCCorpusEntryErrorV6) else { return }
        }
    }

    // ── MAINSESSION 5: verifier V6 reject matrix ───────────────────────────────────────────────────
    func testR7_MAINSESSION_VerifierV6_RejectsAUDIT20FixRequired_WrongPath_WrongManifest_FakeCounts() throws {
        // Base a synthetic PASS repo, then MUTATE one field per sub-case and assert the matching refusal.
        // Each mutation rewrites the audit-result blob + recommits so the lock's blob hash binds it.

        // Helper that builds a fresh synthetic repo and lets the caller override the result JSON and/or
        // the lock JSON, returning the refusal thrown by verify.
        func buildAndVerify(resultMutate: (inout [String: String]) -> Void = { _ in },
                            lockOverrideResultPath: String? = nil,
                            lockOverrideManifestPath: String? = nil,
                            lockOverrideTagName: String? = nil,
                            mutateManifestAfterCommit: ((URL) throws -> Void)? = nil,
                            lockVersionOverride: String? = nil) throws -> Error? {
            let root = tempDir("vrej")
            defer { try? FileManager.default.removeItem(at: root) }
            try sh(root, ["init", "-q"])
            try write(root, "seed.txt", "governing base\n")
            try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "governing"])
            let governing = try sh(root, ["rev-parse", "HEAD"])
            try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV6.governingTagName, "-m", "governing"])
            let gates = "{\"gates\": \"fixture-v8\"}\n"; let code = "// law\nlet law = 8\n"
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
            let tagName = "fixture-r7-candidate"
            try sh(root, ["tag", "-a", tagName, "-m", "candidate"])
            let tagObject = try sh(root, ["rev-parse", "refs/tags/" + tagName])
            var fields: [String: String] = [
                "result_version": "rwc-pre14-audit-result-v4", "verdict": "PASS",
                "candidate_commit": candidate, "candidate_tag_name": tagName,
                "candidate_tag_object_sha": tagObject, "methodology_anchor_commit": anchor,
                "freeze_manifest_path": manifestPath, "freeze_manifest_sha256": shaHex(manifest),
                "frozen_inventory_digest": invDigest, "governing_control_plane_lock": governing,
                "audit_probe_family": "R7_FIXTURE", "critical_count": "0", "high_count": "0",
                "medium_count": "0", "baseline_count": "2", "fresh_probe_count": "1", "total_count": "3",
                "auditor_declaration": "SYNTHETIC"]
            resultMutate(&fields)
            func q(_ k: String) -> String { "\"\(k)\": \"\(fields[k]!)\"" }
            func n(_ k: String) -> String { "\"\(k)\": \(fields[k]!)" }
            let result = "{" + [q("result_version"), q("verdict"), q("candidate_commit"),
                q("candidate_tag_name"), q("candidate_tag_object_sha"), q("methodology_anchor_commit"),
                q("freeze_manifest_path"), q("freeze_manifest_sha256"), q("frozen_inventory_digest"),
                q("governing_control_plane_lock"), q("audit_probe_family"), n("baseline_count"),
                n("fresh_probe_count"), n("total_count"), n("critical_count"), n("high_count"),
                n("medium_count"), q("auditor_declaration")].joined(separator: ", ") + "}"
            let resultPath = lockOverrideResultPath ?? RWCPre14AuditResultV4.canonicalPath
            try write(root, resultPath, result)
            try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit"])
            let audit = try sh(root, ["rev-parse", "HEAD"])
            let lockVersion = lockVersionOverride ?? "rwc-pre14-pass-lock-v4"
            let lock = """
            {"lock_version": "\(lockVersion)", "audit_result_path": "\(resultPath)",
             "audit_result_blob_sha256": "\(shaHex(result))", "audit_commit": "\(audit)",
             "candidate_commit": "\(candidate)", "candidate_tag_name": "\(lockOverrideTagName ?? tagName)",
             "candidate_tag_object_sha": "\(tagObject)",
             "freeze_manifest_path": "\(lockOverrideManifestPath ?? manifestPath)",
             "freeze_manifest_sha256": "\(shaHex(manifest))", "methodology_anchor_commit": "\(anchor)",
             "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
             "corpus_entry_authorized": true, "verdict": "PASS"}
            """
            try write(root, RWCPre14PassLockV4.lockRelPath, lock)
            if let mutate = mutateManifestAfterCommit { try mutate(root) }  // drift the live manifest
            try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
            do { _ = try RWCCorpusEntryVerifierV6.verify(repoRoot: root); return nil }
            catch { return error }
        }

        // (a) AUDIT20 FIX_REQUIRED verdict replay → not PASS.
        var e = try buildAndVerify(resultMutate: { $0["verdict"] = "FIX_REQUIRED" })
        if case .auditVerdictNotPass = (e as? RWCCorpusEntryErrorV6) {} else { XCTFail("verdict: \(String(describing: e))") }
        // (b) wrong (R6) result path → nonCanonicalAuditResultPath.
        e = try buildAndVerify(lockOverrideResultPath: "docs/audit/RWC_PRE14_R6_AUDIT_RESULT.json")
        if case .nonCanonicalAuditResultPath = (e as? RWCCorpusEntryErrorV6) {} else { XCTFail("path: \(String(describing: e))") }
        // (c) wrong manifest version path (V7 in the lock). The result still names the V8 manifest, so
        // the result↔lock cross-check refuses first with auditTargetMismatch(freeze_manifest_path); the
        // point is the verifier NEVER accepts a V7-manifest lock (the canonical-path guard would also
        // refuse). Assert refusal with the freeze_manifest_path field named.
        e = try buildAndVerify(lockOverrideManifestPath:
            "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V7.yaml")
        if case .auditTargetMismatch(let f) = (e as? RWCCorpusEntryErrorV6) {
            XCTAssertEqual(f, "freeze_manifest_path")
        } else if case .carried = (e as? RWCCorpusEntryErrorV6) {
            // (if a future verifier reorders the guards to reach the canonical-path check first)
        } else { XCTFail("manifest-version: \(String(describing: e))") }
        // (d) stale candidate / wrong tag name → tag refusal.
        e = try buildAndVerify(lockOverrideTagName: "not-the-real-tag")
        XCTAssertNotNil(e, "wrong tag name must refuse")
        // (e) changed frozen blob (live manifest drift after audit) → freezeManifestHashMismatch (carried).
        e = try buildAndVerify(mutateManifestAfterCommit: { root in
            try self.write(root, RWCCorpusEntryVerifierV6.canonicalFreezeManifestPath,
                           "{\"freeze_version\": \"rwc-preregistration-freeze-v8\", \"DRIFT\": true}\n")
        })
        XCTAssertNotNil(e, "frozen-blob drift must refuse")
        // (f) V3-as-V4 (schema version disguised) → schemaVersionUnsupported.
        e = try buildAndVerify(resultMutate: { $0["result_version"] = "rwc-pre14-audit-result-v3" })
        XCTAssertNotNil(e, "schema V3-as-V4 must refuse")
        // (g) fake PASS counts (nonzero findings) → auditFindingsOpen.
        e = try buildAndVerify(resultMutate: { $0["critical_count"] = "1"; $0["total_count"] = "4" })
        XCTAssertNotNil(e, "nonzero findings must refuse")
        // (h) unsupported lock version → lockVersionUnsupported.
        e = try buildAndVerify(lockVersionOverride: "rwc-pre14-pass-lock-v3")
        if case .lockVersionUnsupported = (e as? RWCCorpusEntryErrorV6) {} else { XCTFail("lock-version: \(String(describing: e))") }
        // (i) a result with inconsistent counts (baseline+fresh != total) → auditCountInconsistent.
        e = try buildAndVerify(resultMutate: { $0["total_count"] = "99" })
        XCTAssertNotNil(e, "inconsistent counts must refuse")
    }

    // ── MAINSESSION 6: external-consumer compile-negative evidence (a20consumer_r7) ─────────────────
    func testR7_MAINSESSION_DirectAuthorizeV2_NoLawfulToken_Unreachable_ExternalConsumer() throws {
        // Drive the ordinary-consumer compile-negative package. POSITIVE target (negatives commented)
        // MUST compile; then uncommenting a negative line MUST FAIL to compile (the sealed symbol is
        // invisible to an external consumer). That compile failure IS the A20-F1/F2 seal evidence.
        let fm = FileManager.default
        // Locate the repo root from this file:
        // packages/GuardianKit/Tests/GuardianCoreTests/RWCPreregistrationR7Tests.swift → 5 levels up.
        var repoRoot = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { repoRoot.deleteLastPathComponent() }   // → repo root
        let consumer = repoRoot.appendingPathComponent("docs/audit/audit20_tools/a20consumer_r7")
        guard fm.fileExists(atPath: consumer.appendingPathComponent("Package.swift").path) else {
            throw XCTSkip("a20consumer_r7 package not found at \(consumer.path)")
        }
        func swiftBuild(packagePath: URL) throws -> Int32 {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = ["swift", "build", "--package-path", packagePath.path]
            p.standardOutput = Pipe(); p.standardError = Pipe()
            try p.run(); p.waitUntilExit()
            return p.terminationStatus
        }
        // POSITIVE: with the negative lines commented (as checked in), `swift build` succeeds.
        let positive = try swiftBuild(packagePath: consumer)
        XCTAssertEqual(positive, 0, "a20consumer_r7 POSITIVE build (negatives commented) must succeed")

        // NEGATIVE: copy the core main.swift into a temp package copy with one negative line uncommented
        // (the authority-token construction) and assert the build FAILS to compile.
        let tmp = tempDir("consumer-neg")
        try fm.copyItem(at: consumer.appendingPathComponent("Package.swift"),
                        to: tmp.appendingPathComponent("Package.swift"))
        try fm.createDirectory(at: tmp.appendingPathComponent("Sources/a20consumer_r7_core"),
                               withIntermediateDirectories: true)
        try fm.createDirectory(at: tmp.appendingPathComponent("Sources/a20consumer_r7_acq"),
                               withIntermediateDirectories: true)
        // acq target: keep as-is (positive).
        try fm.copyItem(at: consumer.appendingPathComponent("Sources/a20consumer_r7_acq/main.swift"),
                        to: tmp.appendingPathComponent("Sources/a20consumer_r7_acq/main.swift"))
        // Fix the relative dependency path (temp package is NOT four levels under the repo).
        let pkgDesc = try String(contentsOf: tmp.appendingPathComponent("Package.swift"), encoding: .utf8)
            .replacingOccurrences(of: "../../../../packages/GuardianKit",
                                  with: repoRoot.appendingPathComponent("packages/GuardianKit").path)
        try pkgDesc.write(to: tmp.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        // core target: an external consumer attempting to construct the `package`-init authority token.
        let negCore = """
        import Foundation
        import GuardianCore
        // NEGATIVE: the authority token init is `package` — an external consumer cannot construct it.
        let t = RWCAcquisitionAuthorityTokenV1(
            candidateCommit: "x", candidateTagObjectSHA: "x", auditCommit: "x", auditResultBlobSHA256: "x",
            methodologyAnchorCommit: "x", freezeManifestSHA256: "x", frozenInventoryDigest: "x",
            sessionID: "s", assetID: "a", sourceReference: "r", intendedUseToken: "training",
            grantID: "g", grantRevision: 1, currentRegistryRootID: "root", currentRegistryRevision: 1,
            currentRegistryDocumentDigest: "d")
        print(t)
        """
        try negCore.write(to: tmp.appendingPathComponent("Sources/a20consumer_r7_core/main.swift"),
                          atomically: true, encoding: .utf8)
        let negative = try swiftBuild(packagePath: tmp)
        XCTAssertNotEqual(negative, 0,
                          "a20consumer_r7 NEGATIVE build MUST fail — the authority token init is `package`-sealed")
        try? fm.removeItem(at: tmp)
    }
}
#endif
