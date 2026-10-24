#if os(macOS)
import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
import RWCAcquisition

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// LANE A — OPERATIONAL ROOT ONBOARDING PROOFS (AUDIT-prefixed; lawful post-audit allowance in the
// GuardianCoreTests root). Proves, in ISOLATED SYNTHETIC fixtures with test keys only:
//
//   (1) the governed activation engine RWCOperationalRootOnboardingV1 (load / verify / activate / revoke
//       / rotate) with its fail-closed negatives (wrong fingerprint, missing/malformed governance record,
//       unacceptable scope, non-ACTIVE candidate, silent root replacement, revoked root, already active);
//   (2) the COMPLETE synthetic chain feeding a GOVERNED root (from the activation ceremony) into the
//       AUDIT21-PASS downstream chain: PRE-14 PASS proof (V6) + governed root + current root-signed
//       registry + V6 grant + evaluator + lawful token + durable authorization + receipt + authorized
//       promotion;
//   (3) the A21-F5 fix: a FAILED receipt finalize is reported as an explicit receiptDeficit (NOT a false
//       finalize) and the quarantine evidence is PRESERVED (no silent loss), with retryability.
//
// It NEVER creates a real key, a real root file at the canonical path, or OPERATIONAL_ROOT_ACTIVE.
// Status ceiling proven here: ONBOARDING_ENGINEERING_READY — ACTIVATION_BLOCKED.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT21_LaneAOnboardingProofs: XCTestCase {

    // MARK: helpers

    private func shaHex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func shaHex(_ d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }
    private func d3(_ s: String) -> RWCDateV3 { try! RWCDateV3.parse(s, field: "la") }
    private func clock(_ s: String) -> RWCFixedClockV3 { try! RWCFixedClockV3(s) }
    private func tempDir(_ tag: String) -> URL {
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("laneA-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    /// A synthetic governed root JSON bytes + its ephemeral private key + the OOB fingerprint. The private
    /// key lives ONLY in test memory and is NEVER persisted (mirrors the production public-key-only law).
    private struct SyntheticGovernedRoot {
        let json: Data
        let privateKey: Curve25519.Signing.PrivateKey
        let rootID: String
        let governanceRecordID: String
        let fingerprint: String
        let publicKeyRawHex: String
    }
    private func makeGovernedRootJSON(rootID: String = "rwc-root-lanea01",
                                      governanceRecordID: String = "rwc-gov-lanea0001",
                                      status: String = "ACTIVE",
                                      activationDate: String = "2026-10-20",
                                      privateKey: Curve25519.Signing.PrivateKey = .init()
    ) -> SyntheticGovernedRoot {
        let raw = privateKey.publicKey.rawRepresentation
        let keyHex = raw.map { String(format: "%02x", $0) }.joined()
        let fp = shaHex(raw)
        let json = """
        {"root_id": "\(rootID)", "public_key_raw_hex": "\(keyHex)", "algorithm": "ed25519",
         "activation_date": "\(activationDate)", "status": "\(status)",
         "governance_record_id": "\(governanceRecordID)"}
        """
        return SyntheticGovernedRoot(json: Data(json.utf8), privateKey: privateKey, rootID: rootID,
                                     governanceRecordID: governanceRecordID, fingerprint: fp,
                                     publicKeyRawHex: keyHex)
    }
    private func govRecord(id: String = "rwc-gov-lanea0001", scope: String = "rwc-governance",
                           identity: String = "owner-governance-authority",
                           date: String = "2026-10-19") -> RWCGovernanceRecordV1 {
        RWCGovernanceRecordV1(authorizingIdentity: identity, governanceRecordID: id,
                              decisionDate: date, scope: scope)
    }

    // ════════════════════════ 1. ONBOARDING ENGINE: positive activation ════════════════════════

    func test_LaneA_Activate_Governed_Positive() throws {
        let g = makeGovernedRootJSON()
        let candidate = try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: g.json)
        XCTAssertEqual(candidate.rootID, g.rootID)
        XCTAssertEqual(candidate.publicKeyFingerprint, g.fingerprint)
        let request = try RWCOperationalRootOnboardingV1.verifyCandidate(
            candidate, governanceRecord: govRecord(), expectedFingerprint: g.fingerprint)
        let store = try RWCOperationalRootActivationStoreV1.create(directory: tempDir("act1"))
        defer { store.closeStore() }
        let activated = try RWCOperationalRootOnboardingV1.activate(request: request, store: store,
                                                                    clock: clock("2026-10-20"))
        XCTAssertEqual(activated.rootID, g.rootID)
        XCTAssertEqual(activated.verifiedRoot.rootID, g.rootID)
        XCTAssertEqual(activated.verifiedRoot.publicKeyRawHex, g.publicKeyRawHex)
        XCTAssertEqual(store.currentHead?.status, RWCOperationalRootActivationStoreV1.statusActive)
        XCTAssertEqual(store.currentHead?.rootID, g.rootID)
    }

    // ════════════════════════ 2. ONBOARDING ENGINE: fail-closed negatives ═══════════════════════

    func test_LaneA_WrongFingerprint_Refused() throws {
        let g = makeGovernedRootJSON()
        let candidate = try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: g.json)
        XCTAssertThrowsError(try RWCOperationalRootOnboardingV1.verifyCandidate(
            candidate, governanceRecord: govRecord(), expectedFingerprint: shaHex("not-the-key"))) { e in
            guard case .fingerprintMismatch = (e as? RWCOperationalOnboardingErrorV1) else {
                return XCTFail("expected fingerprintMismatch, got \(e)")
            }
        }
    }

    func test_LaneA_MissingGovernanceRecordFields_Refused() throws {
        let g = makeGovernedRootJSON()
        let candidate = try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: g.json)
        // malformed governance_record_id grammar
        let bad = RWCGovernanceRecordV1(authorizingIdentity: "owner", governanceRecordID: "not-a-gov-id",
                                        decisionDate: "2026-10-19", scope: "rwc-governance")
        XCTAssertThrowsError(try RWCOperationalRootOnboardingV1.verifyCandidate(
            candidate, governanceRecord: bad, expectedFingerprint: g.fingerprint)) { e in
            guard case .governanceRecordMalformed = (e as? RWCOperationalOnboardingErrorV1) else {
                return XCTFail("expected governanceRecordMalformed, got \(e)")
            }
        }
    }

    func test_LaneA_UnacceptableGovernanceScope_Refused() throws {
        let g = makeGovernedRootJSON()
        let candidate = try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: g.json)
        // a well-formed scope that is NOT a governance decision
        XCTAssertThrowsError(try RWCOperationalRootOnboardingV1.verifyCandidate(
            candidate, governanceRecord: govRecord(scope: "rwc-corpus"),
            expectedFingerprint: g.fingerprint)) { e in
            guard case .governanceScopeUnacceptable = (e as? RWCOperationalOnboardingErrorV1) else {
                return XCTFail("expected governanceScopeUnacceptable, got \(e)")
            }
        }
    }

    func test_LaneA_GovernanceRecordIDMismatchWithFile_Refused() throws {
        let g = makeGovernedRootJSON(governanceRecordID: "rwc-gov-filevalue01")
        let candidate = try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: g.json)
        XCTAssertThrowsError(try RWCOperationalRootOnboardingV1.verifyCandidate(
            candidate, governanceRecord: govRecord(id: "rwc-gov-differ0001"),
            expectedFingerprint: g.fingerprint)) { e in
            guard case .governanceRecordMalformed = (e as? RWCOperationalOnboardingErrorV1) else {
                return XCTFail("expected governanceRecordMalformed (id mismatch), got \(e)")
            }
        }
    }

    func test_LaneA_NonActiveCandidate_Refused() throws {
        let g = makeGovernedRootJSON(status: "RETIRED")
        XCTAssertThrowsError(try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: g.json)) { e in
            guard case .candidateNotActive = (e as? RWCOperationalOnboardingErrorV1) else {
                return XCTFail("expected candidateNotActive, got \(e)")
            }
        }
    }

    func test_LaneA_SilentRootReplacement_Refused() throws {
        let store = try RWCOperationalRootActivationStoreV1.create(directory: tempDir("act-silent"))
        defer { store.closeStore() }
        let g1 = makeGovernedRootJSON(rootID: "rwc-root-laneafirst")
        let r1 = try RWCOperationalRootOnboardingV1.verifyCandidate(
            try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: g1.json),
            governanceRecord: govRecord(), expectedFingerprint: g1.fingerprint)
        _ = try RWCOperationalRootOnboardingV1.activate(request: r1, store: store, clock: clock("2026-10-20"))
        // a DIFFERENT rootID while one is ACTIVE must be refused (no silent replacement).
        let g2 = makeGovernedRootJSON(rootID: "rwc-root-laneasecond")
        let r2 = try RWCOperationalRootOnboardingV1.verifyCandidate(
            try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: g2.json),
            governanceRecord: govRecord(), expectedFingerprint: g2.fingerprint)
        XCTAssertThrowsError(try RWCOperationalRootOnboardingV1.activate(
            request: r2, store: store, clock: clock("2026-10-21"))) { e in
            guard case .alreadyActiveDifferentRoot = (e as? RWCOperationalOnboardingErrorV1) else {
                return XCTFail("expected alreadyActiveDifferentRoot, got \(e)")
            }
        }
    }

    func test_LaneA_RevokeThenReactivate_And_Rotate() throws {
        let store = try RWCOperationalRootActivationStoreV1.create(directory: tempDir("act-rev"))
        defer { store.closeStore() }
        let g1 = makeGovernedRootJSON(rootID: "rwc-root-lanearev01")
        let r1 = try RWCOperationalRootOnboardingV1.verifyCandidate(
            try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: g1.json),
            governanceRecord: govRecord(), expectedFingerprint: g1.fingerprint)
        _ = try RWCOperationalRootOnboardingV1.activate(request: r1, store: store, clock: clock("2026-10-20"))
        // revoke of a wrong rootID is refused.
        XCTAssertThrowsError(try RWCOperationalRootOnboardingV1.revoke(
            rootID: "rwc-root-wrong0001", reason: "x", store: store, clock: clock("2026-10-21")))
        // lawful revoke.
        try RWCOperationalRootOnboardingV1.revoke(rootID: g1.rootID, reason: "incident",
                                                  store: store, clock: clock("2026-10-21"))
        XCTAssertEqual(store.currentHead?.status, RWCOperationalRootActivationStoreV1.statusRevoked)
        // after revoke, a NEW root may activate (no silent-replacement block once revoked).
        let g2 = makeGovernedRootJSON(rootID: "rwc-root-lanearev02")
        let r2 = try RWCOperationalRootOnboardingV1.verifyCandidate(
            try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: g2.json),
            governanceRecord: govRecord(), expectedFingerprint: g2.fingerprint)
        _ = try RWCOperationalRootOnboardingV1.activate(request: r2, store: store, clock: clock("2026-10-22"))
        XCTAssertEqual(store.currentHead?.rootID, g2.rootID)
        XCTAssertEqual(store.currentHead?.status, RWCOperationalRootActivationStoreV1.statusActive)
        // rotate the active root to a third.
        let g3 = makeGovernedRootJSON(rootID: "rwc-root-lanearev03")
        let r3 = try RWCOperationalRootOnboardingV1.verifyCandidate(
            try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: g3.json),
            governanceRecord: govRecord(), expectedFingerprint: g3.fingerprint)
        let rotated = try RWCOperationalRootOnboardingV1.rotate(
            retiring: g2.rootID, request: r3, store: store, clock: clock("2026-10-23"))
        XCTAssertEqual(rotated.rootID, g3.rootID)
        XCTAssertEqual(store.currentHead?.rootID, g3.rootID)
        XCTAssertEqual(store.currentHead?.status, RWCOperationalRootActivationStoreV1.statusActive)
        // the event chain is durable + reopenable (tamper-DETECTION roll-forward).
        store.closeStore()
        let reopened = try RWCOperationalRootActivationStoreV1.openExisting(directory: store.directory)
        defer { reopened.closeStore() }
        XCTAssertEqual(reopened.currentHead?.rootID, g3.rootID)
        XCTAssertEqual(reopened.events.count, 5)   // ACTIVATED, REVOKED, ACTIVATED, ROTATED_OUT, ROTATED_IN
    }

    func test_LaneA_TamperedActivationStore_FailsClosed() throws {
        let store = try RWCOperationalRootActivationStoreV1.create(directory: tempDir("act-tamper"))
        let g = makeGovernedRootJSON()
        let r = try RWCOperationalRootOnboardingV1.verifyCandidate(
            try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: g.json),
            governanceRecord: govRecord(), expectedFingerprint: g.fingerprint)
        _ = try RWCOperationalRootOnboardingV1.activate(request: r, store: store, clock: clock("2026-10-20"))
        let dir = store.directory
        store.closeStore()
        // corrupt the journal: flip the rootID in the single line (breaks the SHA-256 chain digest).
        let journal = dir.appendingPathComponent("root-activation-v1.jsonl")
        let raw = try String(contentsOf: journal, encoding: .utf8)
        try raw.replacingOccurrences(of: g.rootID, with: "rwc-root-tampered1")
            .write(to: journal, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try RWCOperationalRootActivationStoreV1.openExisting(directory: dir)) { e in
            guard case .storeMalformed = (e as? RWCOperationalOnboardingErrorV1) else {
                return XCTFail("expected storeMalformed, got \(e)")
            }
        }
    }

    // ════════════════════════ 3. ORDINARY-CONSUMER / PRE-ACTIVATION FAIL-CLOSED ═════════════════

    func test_LaneA_LoadProduction_StillFailsClosed_Unchanged() throws {
        // the onboarding engine does NOT change the PRE-activation world: loadProduction stays
        // .noOperationalRoot (A19-F2), even with a caller-chosen directory.
        XCTAssertThrowsError(try RWCReviewerTrustRootLoaderV2.loadProduction(
            repoRoot: tempDir("lp"))) { e in
            XCTAssertEqual(e as? RWCReviewerTrustErrorV2, .noOperationalRoot)
        }
    }

    // ════════════════════════ 4. FULL SYNTHETIC CHAIN WITH A GOVERNED ROOT ══════════════════════

    private final class SpyAcquirer: RWCAssetAcquirerV1 {
        let payload: Data
        init(_ payload: Data) { self.payload = payload }
        func fetch(sourceReference: String) throws -> Data { payload }
    }
    private final class FixtureCorpusStore: RWCCorpusStoreV1 {
        var promoted: [String: Data] = [:]
        func promote(assetID: String, contentHash: String, payload: Data) throws { promoted[assetID] = payload }
        func storedAssetIDs() throws -> [String] { Array(promoted.keys) }
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
    private func writeFile(_ root: URL, _ rel: String, _ content: String) throws {
        let url = root.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Synthetic PRE-14 PASS proof fixture (schema V4 result + V8 freeze manifest). Mirrors the proven R7
    /// builder fixture.
    private func syntheticProofV6() throws -> (RWCVerifiedCorpusEntryV6, URL) {
        let root = tempDir("vfx")
        try sh(root, ["init", "-q"])
        try writeFile(root, "seed.txt", "governing base\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "governing"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV6.governingTagName, "-m", "governing"])
        let gates = "{\"gates\": \"laneA-v8\"}\n"
        let code = "// RWCFixtureLaw\nlet law = 8\n"
        try writeFile(root, "docs/prereg/gates.yaml", gates)
        try writeFile(root, "code/method/RWCFixtureLaw.swift", code)
        try writeFile(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
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
        try writeFile(root, manifestPath, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        let tagName = "fixture-laneA-candidate"
        try sh(root, ["tag", "-a", tagName, "-m", "candidate"])
        let tagObject = try sh(root, ["rev-parse", "refs/tags/" + tagName])
        let result = """
        {"result_version": "rwc-pre14-audit-result-v4", "verdict": "PASS",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "\(tagName)",
         "candidate_tag_object_sha": "\(tagObject)", "methodology_anchor_commit": "\(anchor)",
         "freeze_manifest_path": "\(manifestPath)", "freeze_manifest_sha256": "\(shaHex(manifest))",
         "frozen_inventory_digest": "\(invDigest)", "governing_control_plane_lock": "\(governing)",
         "audit_probe_family": "LANEA_FIXTURE", "baseline_count": 2, "fresh_probe_count": 1,
         "total_count": 3, "critical_count": 0, "high_count": 0, "medium_count": 0,
         "auditor_declaration": "SYNTHETIC FIXTURE independent audit"}
        """
        try writeFile(root, RWCPre14AuditResultV4.canonicalPath, result)
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
        try writeFile(root, RWCPre14PassLockV4.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
        let proof = try RWCCorpusEntryVerifierV6.verify(repoRoot: root)
        return (proof, root)
    }

    /// Build a root-signed CURRENT registry + a V6 grant, rooted in a GOVERNED (activation-ceremony) root.
    private struct GovChain {
        let activated: RWCActivatedRootV1
        let activationStore: RWCOperationalRootActivationStoreV1
        let rootPriv: Curve25519.Signing.PrivateKey
        let currentness: RWCReviewerRegistryCurrentnessStoreV1
        let registry: RWCVerifiedReviewerRegistryV2
        let reviewerKey: Curve25519.Signing.PrivateKey
    }
    private func governedChain(tag: String) throws -> GovChain {
        // governed root via the full onboarding ceremony (NOT makeSyntheticTestRoot).
        let g = makeGovernedRootJSON(rootID: "rwc-root-\(tag)01")
        let request = try RWCOperationalRootOnboardingV1.verifyCandidate(
            try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: g.json),
            governanceRecord: govRecord(), expectedFingerprint: g.fingerprint)
        let actStore = try RWCOperationalRootActivationStoreV1.create(directory: tempDir("\(tag)-act"))
        let activated = try RWCOperationalRootOnboardingV1.activate(request: request, store: actStore,
                                                                    clock: clock("2026-10-20"))
        // registry signed by the governed root key.
        let reviewerKey = Curve25519.Signing.PrivateKey()
        let reviewerHex = reviewerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let entry = RWCReviewerRegistryEntryV1(
            reviewerID: "rwc-reviewer-lanearv1", publicKeyRawHex: reviewerHex, status: "ACTIVE",
            role: "RIGHTS_REVIEW", scope: RWCReviewerScopeV1.corpus.rawValue, validFrom: d3("2026-01-01"),
            validUntil: d3("2027-12-31"), revision: 1)
        var doc = RWCReviewerRegistryDocumentV2(
            registryVersion: RWCReviewerRegistryDocumentV2.schemaVersion, registryRevision: 1,
            rootID: activated.rootID, createdAt: d3("2026-02-01"),
            previousRegistryDigest: RWCReviewerRegistryDocumentV2.genesisPreviousDigest,
            reviewers: [entry], signatureHex: "")
        let sig = try g.privateKey.signature(for: doc.canonicalPayloadBytes)
        doc = RWCReviewerRegistryDocumentV2(
            registryVersion: doc.registryVersion, registryRevision: doc.registryRevision, rootID: doc.rootID,
            createdAt: doc.createdAt, previousRegistryDigest: doc.previousRegistryDigest,
            reviewers: doc.reviewers, signatureHex: sig.map { String(format: "%02x", $0) }.joined())
        let currentness = try RWCReviewerRegistryCurrentnessStoreV1.create(directory: tempDir("\(tag)-cur"))
        try currentness.advance(rootID: activated.rootID, revision: 1, documentDigest: doc.documentDigest,
                                recordedDate: "2026-02-01")
        let reg = try RWCReviewerRegistryVerifierV2.verifyCurrent(
            document: doc, trustRoot: activated.verifiedRoot, currentness: currentness, previousVerified: nil)
        return GovChain(activated: activated, activationStore: actStore, rootPriv: g.privateKey,
                        currentness: currentness, registry: reg, reviewerKey: reviewerKey)
    }
    private func grant(allowed: [String] = ["training", "evaluation"]) -> RWCLegalGrantIdentityV1 {
        RWCLegalGrantIdentityV1(grantID: "rwc-grant-lanea001", grantRevision: 1,
            evidenceDigest: shaHex("proof-lanea"), evidencePointer: "rwc-rights-ref-laneap01",
            rightsHolder: "licensor-laneA", allowedUse: allowed, prohibitedUse: [],
            effectiveDate: d3("2026-08-01"), expiryDate: d3("2027-08-01"), reviewDecision: "APPROVED",
            reviewRecordID: "rwc-review-lanearv1")
    }
    private func grantV6(_ g: RWCLegalGrantIdentityV1, source: String, _ c: GovChain) throws
        -> RWCVerifiedRightsGrantV6 {
        var r = RWCSignedRightsReviewV1(
            reviewRecordID: g.reviewRecordID, reviewerID: "rwc-reviewer-lanearv1", grantID: g.grantID,
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
    private func request(session: String, use: RWCUseV1 = .training,
                         source: String = "rwc-source-ref-laneas1",
                         asset: String = "rwc-asset-laneaaaa01") -> RWCAcquisitionRequestV1 {
        RWCAcquisitionRequestV1(assetID: asset, sourceClass: .licensedRightsClear, sourceReference: source,
                                owner: "gen8", intendedUse: use, sessionID: session,
                                manifestSources: nil, trustedExpectedChecksum: nil)
    }

    func test_LaneA_FullSyntheticChain_GovernedRoot_EndToEnd_Promotes() throws {
        let (proof, fxRoot) = try syntheticProofV6()
        defer { try? FileManager.default.removeItem(at: fxRoot) }
        let c = try governedChain(tag: "e2e")
        defer { c.currentness.closeStore(); c.activationStore.closeStore() }
        let g = grant(allowed: ["training"])
        let vg = try grantV6(g, source: "rwc-source-ref-laneas1", c)
        let store = try RWCAssetRightsLedgerStoreV5.create(
            directory: tempDir("e2e-l").appendingPathComponent("l"))
        defer { store.closeStore() }
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: tempDir("e2e-r"))
        defer { receipt.closeStore() }
        let corpus = FixtureCorpusStore()
        let spy = SpyAcquirer(Data("laneA-governed-root-bytes".utf8))
        let runner = RWCCorpusAcquisitionRunnerV5(quarantineRoot: tempDir("e2e-q"))
        let session = "rwc-acq-laneasession00001"
        let r = try runner.acquire(proof: proof, request: request(session: session), verifiedGrant: vg,
                                   currentRegistry: c.registry, rightsStore: store, corpusStore: corpus,
                                   acquirer: spy, clock: clock("2026-10-21"), receiptStore: receipt)
        XCTAssertEqual(r.assetID, "rwc-asset-laneaaaa01")
        XCTAssertEqual(corpus.promoted["rwc-asset-laneaaaa01"], spy.payload)
        XCTAssertEqual(try receipt.load(session).state, .completed)
        // the governed root identity flows all the way into the durable authorization record.
        let authz = store.authorizationRecord(forSession: session)
        XCTAssertEqual(authz?.rootID, c.activated.rootID)
        XCTAssertEqual(authz?.candidateCommit, proof.candidateCommit)
        XCTAssertTrue(authz?.hasCompleteProofIdentity ?? false)
    }

    // ════════════════════════ 5. A21-F5 FIX: fault-injected receipt finalize ════════════════════

    /// Drives reconcileV5's `ensureReceipt` finalize path and forces `complete()` to FAIL by making the
    /// receipt directory read-only after a PREPARED receipt exists. OLD behavior (A21-F5): the session
    /// would be reported in `finalizedReceipts` even though the durable receipt stayed `.prepared`, and
    /// the quarantine would be deleted (evidence loss). NEW behavior: the session is reported as an
    /// explicit `receiptDeficit`, the durable receipt is NOT `.completed`, and the quarantine is PRESERVED.
    func test_LaneA_A21F5_FailedFinalize_ReportsDeficit_PreservesEvidence_Retryable() throws {
        let (proof, fxRoot) = try syntheticProofV6()
        defer { try? FileManager.default.removeItem(at: fxRoot) }
        let c = try governedChain(tag: "f5")
        defer { c.currentness.closeStore(); c.activationStore.closeStore() }
        let g = grant(allowed: ["training"])
        let source = "rwc-source-ref-laneas1"
        let vg = try grantV6(g, source: source, c)
        let ledgerDir = tempDir("f5-l").appendingPathComponent("l")
        let store = try RWCAssetRightsLedgerStoreV5.create(directory: ledgerDir)
        defer { store.closeStore() }
        let receiptDir = tempDir("f5-r")
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: receiptDir)
        let corpus = FixtureCorpusStore()
        let qRoot = tempDir("f5-q")
        let runner = RWCCorpusAcquisitionRunnerV5(quarantineRoot: qRoot)
        let session = "rwc-acq-laneaf5session01"
        let asset = "rwc-asset-laneaaaa01"

        // Drive the lawful path up to a PREPARED (not completed) receipt + a stored asset + a surviving
        // quarantine, so reconcileV5 will enter ensureReceipt's finalize branch.
        let preauth = try RWCPreAcquisitionEvaluatorV3.authorize(
            request: request(session: session, source: source, asset: asset), verifiedGrant: vg,
            transactionDate: clock("2026-10-21").today())
        let payload = Data("laneA-f5-payload".utf8)
        let contentHash = RWCCorpusAcquisitionRunnerV5.sha256Hex(payload)
        try store.register(RWCAssetRightsRecordV3(
            assetID: asset, sourceClass: .licensedRightsClear, sourceReference: source, owner: "gen8",
            grant: g, acquisitionDate: d3("2026-08-20"), contentHash: contentHash,
            provenanceChain: [source]), verifiedGrant: vg, clock: clock("2026-10-21"))
        let token = RWCAcquisitionAuthorityTokenV1(
            candidateCommit: proof.candidateCommit, candidateTagObjectSHA: proof.candidateTagObjectSHA,
            auditCommit: proof.auditCommit, auditResultBlobSHA256: proof.auditResultBlobSHA256,
            methodologyAnchorCommit: proof.methodologyAnchorCommit,
            freezeManifestSHA256: proof.freezeManifestSHA256, frozenInventoryDigest: proof.frozenInventoryDigest,
            sessionID: preauth.sessionID, assetID: preauth.assetID, sourceReference: preauth.sourceReference,
            intendedUseToken: "training", grantID: preauth.grantID, grantRevision: preauth.grantRevision,
            currentRegistryRootID: c.registry.rootID, currentRegistryRevision: c.registry.registryRevision,
            currentRegistryDocumentDigest: c.registry.documentDigest)
        let authz = try store.authorizeAcquisitionV2(token: token, verifiedGrant: vg,
                                                     currentRegistry: c.registry, clock: clock("2026-10-21"))
        try corpus.promote(assetID: asset, contentHash: contentHash, payload: payload)
        // a PREPARED (not completed) durable receipt exists for this session.
        _ = try receipt.prepare(authorizationV2: authz, rightsLedgerHeadDigest: store.headDigest,
                                rightsEventCount: store.eventCount)
        XCTAssertEqual(try receipt.load(session).state, .prepared)
        let qdir = qRoot.appendingPathComponent("rwc-quarantine-\(session)", isDirectory: true)
        try FileManager.default.createDirectory(at: qdir, withIntermediateDirectories: true)
        try payload.write(to: qdir.appendingPathComponent("payload"))

        // FAULT INJECTION: make the receipt directory read-only so complete()'s atomic write fails.
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: receiptDir.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700],
                                                       ofItemAtPath: receiptDir.path) }

        let report = try runner.reconcileV5(rightsStore: store, corpusStore: corpus, receiptStore: receipt)
        // NEW TRUTH (A21-F5 fix): NOT reported as finalized; surfaced as an explicit deficit.
        XCTAssertFalse(report.finalizedReceipts.contains(session),
                       "A21-F5: a FAILED finalize must NOT be reported in finalizedReceipts")
        XCTAssertTrue(report.receiptDeficitSessions.contains(session),
                      "A21-F5: the failed finalize is surfaced as an explicit receiptDeficit")
        // durable receipt is still NOT completed.
        XCTAssertEqual(try receipt.load(session).state, .prepared)
        // evidence preserved: the quarantine payload survives (no silent loss).
        XCTAssertTrue(FileManager.default.fileExists(atPath: qdir.appendingPathComponent("payload").path),
                      "A21-F5: quarantine evidence must be PRESERVED on a receiptDeficit")

        // RETRYABLE: restore write access and reconcile again → now finalizes + cleans up.
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: receiptDir.path)
        let report2 = try runner.reconcileV5(rightsStore: store, corpusStore: corpus, receiptStore: receipt)
        XCTAssertTrue(report2.finalizedReceipts.contains(session),
                      "A21-F5: the deficit is retryable — the next reconcile finalizes it")
        XCTAssertEqual(try receipt.load(session).state, .completed)
        receipt.closeStore()
    }
}
#endif
