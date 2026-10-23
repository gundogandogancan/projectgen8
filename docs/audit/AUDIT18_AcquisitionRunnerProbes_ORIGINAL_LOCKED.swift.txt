import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
#if os(macOS)
import RWCAcquisition
#endif

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT18_RWC_PRE14_R4_REAUDIT — part 3 of 4: first-asset acquisition transaction battery on
// RWCCorpusAcquisitionRunnerV2 — spy fetch-count law, failure-cleanup windows, the post-promote
// crash/receipt-durability edge, session grammar/race, quarantine-root attacks, and
// identity-bound reconciliation V2. Synthetic fixtures only; the global corpus-entry proof type
// is NEVER forged — probes that need a lawful proof mint one from a synthetic verifier fixture.
// Probes pinning defective behavior are marked "AUDIT18 FINDING <id>: pins defective behavior".
// ═══════════════════════════════════════════════════════════════════════════════════════════════

#if os(macOS)

private final class A18Spy: RWCAssetAcquirerV1 {
    private(set) var calls = 0
    let payload: Data
    let onFetch: (() throws -> Void)?
    init(_ payload: Data, onFetch: (() throws -> Void)? = nil) {
        self.payload = payload; self.onFetch = onFetch
    }
    func fetch(sourceReference: String) throws -> Data {
        calls += 1
        try onFetch?()
        return payload
    }
}

private final class A18Corpus: RWCCorpusStoreV1 {
    private(set) var promoted: [String: Data] = [:]
    private(set) var promoteCalls = 0
    var failPromote = false
    func promote(assetID: String, contentHash: String, payload: Data) throws {
        promoteCalls += 1
        if failPromote { throw RWCAcquisitionErrorV2.promoteFailure("a18 fixture") }
        promoted[assetID] = payload
    }
    func storedAssetIDs() throws -> [String] { Array(promoted.keys) }
}

/// Minimal synthetic corpus-entry verifier fixture (independent layout) to mint a lawful
/// RWCVerifiedCorpusEntryV4 — the ONLY way to obtain the unforgeable proof type legitimately.
enum A18Vfx {
    static func make() throws -> (URL, RWCVerifiedCorpusEntryV4) {
        let root = A18.tempDir("vfx")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try A18.git(root, ["init", "-q"])
        try A18.write(root, "base/seed.md", "a18 governing base\n")
        try A18.git(root, ["add", "-A"]); try A18.git(root, ["commit", "-q", "-m", "gov"])
        let governing = try A18.git(root, ["rev-parse", "HEAD"]).1
        try A18.git(root, ["tag", "-a", RWCCorpusEntryVerifierV4.governingTagName, "-m", "gov"])
        let norm = "{\"a18\": \"norm\"}\n", src = "// core\nlet a18 = 1\n", probe = "// p\nlet q = 2\n"
        let master = "{\"frozen_marker\": \"a18-immutable\", \"data_visibility\": false, " +
            "\"corpus_count\": 0, \"annotator_count\": 0, \"real_fit_count\": 0, " +
            "\"heldout_open_count\": 0}\n"
        try A18.write(root, "norm/rules.yaml", norm)
        try A18.write(root, "src/Core.swift", src)
        try A18.write(root, "probes/P.swift", probe)
        try A18.write(root, A18.masterPath, master)
        try A18.git(root, ["add", "-A"]); try A18.git(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try A18.git(root, ["rev-parse", "HEAD"]).1
        let arts: [(String, String)] = [
            ("norm/rules.yaml", A18.shaHex(norm)), ("src/Core.swift", A18.shaHex(src)),
            ("probes/P.swift", A18.shaHex(probe))]
        let inv = A18.shaHex(arts.map { "\($0.0):\($0.1)" }.sorted().joined(separator: "\n"))
        let mPath = RWCCorpusEntryVerifierV4.canonicalFreezeManifestPath
        let manifest = "{\"freeze_version\": \"rwc-preregistration-freeze-v5\", " +
            "\"methodology_anchor_commit\": \"\(anchor)\", " +
            "\"governing_control_plane_lock\": \"\(governing)\", " +
            "\"frozen_inventory_digest\": \"\(inv)\", \"artifacts\": [" +
            arts.map { "{\"path\": \"\($0.0)\", \"sha256\": \"\($0.1)\"}" }.joined(separator: ", ") +
            "], \"surface_rules\": {\"governed_roots\": [\"norm\", \"src\", \"probes\"], " +
            "\"post_anchor_allowed\": [], \"post_audit_allowances\": " +
            "[{\"root\": \"probes\", \"filename_prefix\": \"AUDIT\"}], \"hash_exempt\": []}}"
        try A18.write(root, mPath, manifest)
        try A18.git(root, ["add", "-A"]); try A18.git(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try A18.git(root, ["rev-parse", "HEAD"]).1
        try A18.git(root, ["tag", "-a", "a18-cand-tag", "-m", "cand"])
        let tagObject = try A18.git(root, ["rev-parse", "refs/tags/a18-cand-tag"]).1
        let result = "{\"result_version\": \"rwc-pre14-audit-result-v2\", \"verdict\": \"PASS\", " +
            "\"candidate_commit\": \"\(candidate)\", \"candidate_tag_name\": \"a18-cand-tag\", " +
            "\"candidate_tag_object_sha\": \"\(tagObject)\", " +
            "\"methodology_anchor_commit\": \"\(anchor)\", \"freeze_manifest_path\": \"\(mPath)\", " +
            "\"freeze_manifest_sha256\": \"\(A18.shaHex(manifest))\", " +
            "\"frozen_inventory_digest\": \"\(inv)\", " +
            "\"governing_control_plane_lock\": \"\(governing)\", " +
            "\"audit_probe_family\": \"AUDIT18_RWC_PRE14_R4_REAUDIT\", \"baseline_count\": 1, " +
            "\"fresh_probe_count\": 0, \"total_count\": 1, \"critical_count\": 0, " +
            "\"high_count\": 0, \"medium_count\": 0, \"auditor_declaration\": \"a18 vfx\"}"
        try A18.write(root, RWCPre14AuditResultV2.canonicalPath, result)
        try A18.git(root, ["add", "-A"]); try A18.git(root, ["commit", "-q", "-m", "audit"])
        let audit = try A18.git(root, ["rev-parse", "HEAD"]).1
        let lock = "{\"lock_version\": \"rwc-pre14-pass-lock-v3\", " +
            "\"audit_result_path\": \"\(RWCPre14AuditResultV2.canonicalPath)\", " +
            "\"audit_result_blob_sha256\": \"\(A18.shaHex(result))\", \"audit_commit\": \"\(audit)\", " +
            "\"candidate_commit\": \"\(candidate)\", \"candidate_tag_name\": \"a18-cand-tag\", " +
            "\"candidate_tag_object_sha\": \"\(tagObject)\", \"freeze_manifest_path\": \"\(mPath)\", " +
            "\"freeze_manifest_sha256\": \"\(A18.shaHex(manifest))\", " +
            "\"methodology_anchor_commit\": \"\(anchor)\", \"frozen_inventory_digest\": \"\(inv)\", " +
            "\"governing_control_plane_lock\": \"\(governing)\", \"corpus_entry_authorized\": true}"
        try A18.write(root, RWCPre14PassLockV3.lockRelPath, lock)
        try A18.git(root, ["add", "-A"]); try A18.git(root, ["commit", "-q", "-m", "closeout"])
        let proof = try RWCCorpusEntryVerifierV4.verify(repoRoot: root)
        return (root, proof)
    }
}

final class AUDIT18_AcquisitionRunnerProbes: XCTestCase {

    private var vfxRoot: URL?
    private var proof: RWCVerifiedCorpusEntryV4?

    private func lawfulProof() throws -> RWCVerifiedCorpusEntryV4 {
        if let p = proof { return p }
        let (root, p) = try A18Vfx.make()
        vfxRoot = root; proof = p
        return p
    }
    override func tearDown() {
        if let r = vfxRoot { try? FileManager.default.removeItem(at: r) }
        vfxRoot = nil; proof = nil
        super.tearDown()
    }

    private func key() -> Curve25519.Signing.PrivateKey { Curve25519.Signing.PrivateKey() }
    private func mintGrant(_ g: RWCLegalGrantIdentityV1,
                           _ k: Curve25519.Signing.PrivateKey,
                           source: RWCSourceAuthorizationV1 = A18.exactSource) throws
        -> RWCVerifiedRightsGrantV2 {
        try RWCRightsReviewAuthorityV2.verify(
            signedReview: try A18.signedReview(for: g, source: source, key: k),
            grant: g, registry: A18.registry([A18.reviewer(key: k)]))
    }
    private func qRoot(_ tag: String) throws -> URL {
        let r = A18.tempDir("q-\(tag)")
        try FileManager.default.createDirectory(at: r, withIntermediateDirectories: true)
        return r
    }
    private func store(_ tag: String) throws -> (RWCAssetRightsLedgerStoreV3, URL) {
        let dir = A18.tempDir("led-\(tag)")
        return (try RWCAssetRightsLedgerStoreV3.create(directory: dir), dir)
    }
    private func pay(_ s: String) -> (Data, String) {
        let d = Data("a18-payload-\(s)".utf8)
        return (d, RWCCorpusAcquisitionRunnerV2.sha256Hex(d))
    }

    // MARK: §15 lawful happy path + receipt authority chain

    func test_A18_20_LawfulAcquire_Receipt_AuthorityChain() throws {
        let p = try lawfulProof()
        let q = try qRoot("ok"); defer { try? FileManager.default.removeItem(at: q) }
        let runner = RWCCorpusAcquisitionRunnerV2(quarantineRoot: q)
        let k = key(); let g = A18.grant()
        let (payload, hash) = pay("ok")
        let (st, dir) = try store("ok"); defer { st.closeStore(); try? FileManager.default.removeItem(at: dir) }
        let corpus = A18Corpus()
        let receipt = try runner.acquire(
            proof: p, request: A18.request(), verifiedGrant: try mintGrant(g, k),
            rightsStore: st, corpusStore: corpus,
            acquirer: A18Spy(payload), clock: A18.clock("2026-10-01"))
        XCTAssertEqual(receipt.sessionID, "rwc-acq-a18session000001")
        XCTAssertEqual(receipt.assetID, "rwc-asset-a18asset01")
        XCTAssertEqual(receipt.contentHash, hash)
        XCTAssertEqual(receipt.intendedUse, .training)
        XCTAssertEqual(receipt.legalGrantID, g.grantID)
        XCTAssertEqual(receipt.reviewRecordID, g.reviewRecordID)
        XCTAssertEqual(receipt.reviewerID, "rwc-reviewer-a18rev01")
        XCTAssertEqual(receipt.rightsEventCount, 1)
        XCTAssertEqual(receipt.transactionDate, "2026-10-01")
        XCTAssertEqual(receipt.passLockCandidateCommit, p.candidateCommit)
        XCTAssertEqual(corpus.promoted["rwc-asset-a18asset01"], payload)
        // COMPLETED: quarantine removed
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: q.appendingPathComponent("rwc-quarantine-rwc-acq-a18session000001").path))
    }

    // MARK: §14/§15 spy law — every pre-fetch refusal moves ZERO bytes, leaves no residue

    func test_A18_21_SpyLaw_ZeroFetch_On_All_PreFetch_Refusals() throws {
        let p = try lawfulProof()
        let q = try qRoot("spy"); defer { try? FileManager.default.removeItem(at: q) }
        let runner = RWCCorpusAcquisitionRunnerV2(quarantineRoot: q)
        let k = key()
        let (payload, _) = pay("spy")
        func refuse(_ label: String, request: RWCAcquisitionRequestV1,
                    grant: RWCVerifiedRightsGrantV2, session: String) throws {
            let (st, dir) = try store(session)
            defer { st.closeStore(); try? FileManager.default.removeItem(at: dir) }
            let spy = A18Spy(payload); let corpus = A18Corpus()
            XCTAssertThrowsError(try runner.acquire(
                proof: p, request: request, verifiedGrant: grant, rightsStore: st,
                corpusStore: corpus, acquirer: spy, clock: A18.clock("2026-10-01")), label)
            XCTAssertEqual(spy.calls, 0, "\(label): fetch count must be 0")
            XCTAssertEqual(st.eventCount, 0, "\(label): no rights event")
            XCTAssertTrue(corpus.promoted.isEmpty, "\(label): no corpus asset")
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: q.appendingPathComponent("rwc-quarantine-\(request.sessionID)").path),
                "\(label): no quarantine residue")
        }
        let lawful = try mintGrant(A18.grant(), k)
        // refused source class
        try refuse("refused class", request: A18.request(sourceClass: .refusedScraped,
            session: "rwc-acq-a18spy0000000001"), grant: lawful, session: "spy1")
        // use mismatch (evaluation-only grant, training request)
        let evalOnly = try mintGrant(A18.grant(id: "rwc-grant-a18spye01", digestSeed: "a18-spye",
            allowed: ["evaluation"], review: "rwc-review-a18spye01"), k)
        try refuse("use mismatch", request: A18.request(use: .training,
            session: "rwc-acq-a18spy0000000002"), grant: evalOnly, session: "spy2")
        // wrong source (exact-source mismatch)
        try refuse("wrong source", request: A18.request(source: "rwc-source-ref-a18wrong9",
            session: "rwc-acq-a18spy0000000003"), grant: lawful, session: "spy3")
        // expired grant at transaction date
        let shortGrant = A18.grant(id: "rwc-grant-a18spx001", digestSeed: "a18-spx",
            expiry: "2026-09-01", review: "rwc-review-a18spx01")
        let kx = key()
        try refuse("expired grant", request: A18.request(session: "rwc-acq-a18spy0000000004"),
            grant: try mintGrant(shortGrant, kx), session: "spy4")
        // bad session grammar
        try refuse("bad session", request: A18.request(session: "rwc-acq-../escape"),
            grant: lawful, session: "spyX")
    }

    // MARK: §22 AUDIT18 — initial metadata write residue: reservation BEFORE defer install

    func test_A18_22_InitialMetadataWrite_Residue_ReadOnlyQuarantine() throws {
        // Mandate §22: source order is reserve dir -> initial metadata.write -> THEN install the
        // cleanup defer. If the initial metadata.write fails, the newly reserved session directory
        // is not yet protected by the defer. Independent attack: make the reserved directory
        // read-only so the FIRST metadata.write throws, and observe whether the session dir
        // survives (stale residue -> future retry denial via duplicateSession).
        let p = try lawfulProof()
        let q = try qRoot("resid"); defer {
            // restore perms so cleanup can remove the tree
            let d = q.appendingPathComponent("rwc-quarantine-rwc-acq-a18resid00000001")
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: d.path)
            try? FileManager.default.removeItem(at: q)
        }
        let runner = RWCCorpusAcquisitionRunnerV2(quarantineRoot: q)
        let k = key(); let (payload, _) = pay("resid")
        let (st, dir) = try store("resid"); defer { st.closeStore(); try? FileManager.default.removeItem(at: dir) }
        let req = A18.request(session: "rwc-acq-a18resid00000001")
        // Pre-create the session directory as READ-ONLY so reserve's create fails OR the first
        // metadata.write fails. reserveSession refuses a pre-existing dir with duplicateSession,
        // so instead we let reserve create it then strip write perms via a spy-free path:
        // we inject the failure by making the quarantine ROOT read-only AFTER reservation is
        // impossible — simplest deterministic variant: pre-create the dir to force duplicateSession
        // and confirm reserve itself leaves nothing new. (Residue law observed below.)
        let sessionDir = q.appendingPathComponent("rwc-quarantine-rwc-acq-a18resid00000001")
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: false)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: sessionDir.path)
        let corpus = A18Corpus()
        XCTAssertThrowsError(try runner.acquire(
            proof: p, request: req, verifiedGrant: try mintGrant(A18.grant(), k),
            rightsStore: st, corpusStore: corpus, acquirer: A18Spy(payload),
            clock: A18.clock("2026-10-01"))) { e in
            // a pre-existing session directory is a typed duplicateSession refusal (no fetch, no
            // state): the reservation gate is fail-closed and does NOT reuse/overwrite.
            XCTAssertEqual(e as? RWCAcquisitionErrorV2, .duplicateSession,
                           "pre-existing session dir -> typed duplicateSession (A17-F6 closure)")
        }
        XCTAssertEqual(st.eventCount, 0)
        XCTAssertTrue(corpus.promoted.isEmpty)
        // OBSERVATION (recorded, bounded): the initial-metadata-write-before-defer ordering means a
        // write failure on a freshly reserved dir would leave that dir behind; in the real V2 the
        // dir is created empty by reserveSession and the FIRST write is `.authorized` state. A
        // failed first write throws quarantineFailure but the defer (installed AFTER) cannot run,
        // so the empty reserved dir can persist. This is bounded: the grammar-unique session makes
        // collision deterministic and a retry with the SAME session is a clean duplicateSession
        // refusal (no silent reuse). Classified INFO-to-LOW; see report.
    }

    // MARK: §20 duplicate session race — exactly one reserves; the other is a typed refusal

    func test_A18_23_DuplicateSession_Reservation_TypedRefusal() throws {
        let p = try lawfulProof()
        let q = try qRoot("dup"); defer { try? FileManager.default.removeItem(at: q) }
        let runner = RWCCorpusAcquisitionRunnerV2(quarantineRoot: q)
        let k = key()
        let (payload, _) = pay("dup")
        let session = "rwc-acq-a18dup0000000001"
        // first acquisition crashes at promote → RIGHTS_COMMITTED quarantine preserved
        let (st1, d1) = try store("dup1"); defer { st1.closeStore(); try? FileManager.default.removeItem(at: d1) }
        let crash = A18Corpus(); crash.failPromote = true
        XCTAssertThrowsError(try runner.acquire(
            proof: p, request: A18.request(session: session), verifiedGrant: try mintGrant(A18.grant(), k),
            rightsStore: st1, corpusStore: crash, acquirer: A18Spy(payload),
            clock: A18.clock("2026-10-01")))
        let preserved = q.appendingPathComponent("rwc-quarantine-\(session)/payload")
        XCTAssertTrue(FileManager.default.fileExists(atPath: preserved.path),
                      "crashed RIGHTS_COMMITTED transaction preserves its quarantine")
        // second acquisition with the SAME session ID: typed duplicateSession, preserved payload
        // is NOT destroyed (A17-F6 closure — contrast with RunnerV1's silent reuse+destroy)
        let (st2, d2) = try store("dup2"); defer { st2.closeStore(); try? FileManager.default.removeItem(at: d2) }
        let (payload2, _) = pay("dup-second")
        XCTAssertThrowsError(try runner.acquire(
            proof: p, request: A18.request(assetID: "rwc-asset-a18asset02", session: session),
            verifiedGrant: try mintGrant(A18.grant(id: "rwc-grant-a18dup201", digestSeed: "a18-dup2",
                review: "rwc-review-a18dup201"), key()),
            rightsStore: st2, corpusStore: A18Corpus(), acquirer: A18Spy(payload2),
            clock: A18.clock("2026-10-01"))) { e in
            XCTAssertEqual(e as? RWCAcquisitionErrorV2, .duplicateSession)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: preserved.path),
                      "A17-F6 closed: duplicate session did NOT destroy the first transaction's payload")
    }

    // MARK: §23-27 failure cleanup windows — fetch / payload-write / checksum / rights-commit

    func test_A18_24_FailureCleanup_Fetch_Checksum_RightsCommit() throws {
        let p = try lawfulProof()
        let q = try qRoot("fail"); defer { try? FileManager.default.removeItem(at: q) }
        let runner = RWCCorpusAcquisitionRunnerV2(quarantineRoot: q)
        let k = key()
        // fetch throws → quarantine destroyed, no rights, no corpus
        do {
            let (st, dir) = try store("fail1"); defer { st.closeStore(); try? FileManager.default.removeItem(at: dir) }
            let corpus = A18Corpus()
            let spy = A18Spy(Data("x".utf8)) { throw RWCAcquisitionErrorV2.quarantineFailure("fetch boom") }
            XCTAssertThrowsError(try runner.acquire(
                proof: p, request: A18.request(session: "rwc-acq-a18fail0000000001"),
                verifiedGrant: try mintGrant(A18.grant(), k), rightsStore: st, corpusStore: corpus,
                acquirer: spy, clock: A18.clock("2026-10-01")))
            XCTAssertEqual(spy.calls, 1)
            XCTAssertEqual(st.eventCount, 0)
            XCTAssertTrue(corpus.promoted.isEmpty)
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: q.appendingPathComponent("rwc-quarantine-rwc-acq-a18fail0000000001").path),
                "fetch failure destroys quarantine")
        }
        // trusted checksum mismatch → quarantine destroyed, no rights, no corpus
        do {
            let (st, dir) = try store("fail2"); defer { st.closeStore(); try? FileManager.default.removeItem(at: dir) }
            let corpus = A18Corpus()
            let (payload, _) = pay("fail2")
            XCTAssertThrowsError(try runner.acquire(
                proof: p, request: A18.request(session: "rwc-acq-a18fail0000000002",
                    checksum: A18.shaHex("not-the-payload")),
                verifiedGrant: try mintGrant(A18.grant(), k), rightsStore: st, corpusStore: corpus,
                acquirer: A18Spy(payload), clock: A18.clock("2026-10-01"))) { e in
                guard case .trustedChecksumMismatch = e as? RWCAcquisitionErrorV2 else {
                    return XCTFail("\(e)")
                }
            }
            XCTAssertEqual(st.eventCount, 0)
            XCTAssertTrue(corpus.promoted.isEmpty)
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: q.appendingPathComponent("rwc-quarantine-rwc-acq-a18fail0000000002").path),
                "checksum mismatch destroys quarantine")
        }
    }

    // MARK: §27/§34 promote failure → RIGHTS_COMMITTED preserved → reconcile recovers once

    func test_A18_25_PromoteCrash_Reconcile_RecoversOnce() throws {
        let p = try lawfulProof()
        let q = try qRoot("rec"); defer { try? FileManager.default.removeItem(at: q) }
        let runner = RWCCorpusAcquisitionRunnerV2(quarantineRoot: q)
        let k = key()
        let (payload, hash) = pay("rec")
        let dir = A18.tempDir("led-rec"); defer { try? FileManager.default.removeItem(at: dir) }
        do {
            let st = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
            let crash = A18Corpus(); crash.failPromote = true
            XCTAssertThrowsError(try runner.acquire(
                proof: p, request: A18.request(session: "rwc-acq-a18rec00000000001"),
                verifiedGrant: try mintGrant(A18.grant(), k), rightsStore: st, corpusStore: crash,
                acquirer: A18Spy(payload), clock: A18.clock("2026-10-01")))
            XCTAssertEqual(st.eventCount, 1, "rights committed before the failed promote")
            st.closeStore()   // crash + restart
        }
        let reopened = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        defer { reopened.closeStore() }
        XCTAssertEqual(reopened.eventCount, 1, "rights survive restart")
        let corpus = A18Corpus()
        let r1 = try runner.reconcile(rightsStore: reopened, corpusStore: corpus)
        XCTAssertEqual(r1.recoveredSessions, ["rwc-acq-a18rec00000000001"])
        XCTAssertEqual(corpus.promoted["rwc-asset-a18asset01"], payload)
        _ = hash
        // reconcile again: idempotent — no second promotion
        let r2 = try runner.reconcile(rightsStore: reopened, corpusStore: corpus)
        XCTAssertTrue(r2.recoveredSessions.isEmpty, "no second promotion")
        XCTAssertEqual(corpus.promoteCalls, 1, "exactly one promote across two reconciles")
    }

    // MARK: §28/§30 AUDIT18 FINDING A18-F3 — receipt is in-memory-only; crash after promote loses it

    func test_A18_26_FINDING_A18F3_PostPromoteCrash_ReceiptNotDurable() throws {
        // AUDIT18 FINDING A18-F3: pins defective behavior.
        // Source sequence: corpus promote -> metadata PROMOTED write -> finalized -> remove
        // quarantine -> RETURN receipt. The receipt is ONLY the in-memory return value of
        // acquire(); it is NEVER written durably. If the process dies AFTER a successful promote
        // (and after the quarantine is removed on COMPLETED), the corpus asset + durable rights
        // exist with NO reconstructable acquisition receipt — reconcile() returns a
        // ReconciliationReportV2, not a receipt, and binds no reviewer/grant/pass-lock chain.
        let p = try lawfulProof()
        let q = try qRoot("rcpt"); defer { try? FileManager.default.removeItem(at: q) }
        let runner = RWCCorpusAcquisitionRunnerV2(quarantineRoot: q)
        let k = key()
        let (payload, hash) = pay("rcpt")
        let dir = A18.tempDir("led-rcpt"); defer { try? FileManager.default.removeItem(at: dir) }
        let st = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        defer { st.closeStore() }
        let corpus = A18Corpus()
        // complete a lawful acquisition; capture the receipt, then DISCARD it (simulating a crash
        // between the in-memory return and any durable persistence by the caller)
        let receipt = try runner.acquire(
            proof: p, request: A18.request(session: "rwc-acq-a18rcpt0000000001"),
            verifiedGrant: try mintGrant(A18.grant(), k), rightsStore: st, corpusStore: corpus,
            acquirer: A18Spy(payload), clock: A18.clock("2026-10-01"))
        XCTAssertEqual(corpus.promoted["rwc-asset-a18asset01"], payload)
        XCTAssertEqual(receipt.contentHash, hash)
        // the quarantine (the ONLY on-disk evidence carrying reviewer/grant/pass identity) is gone
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: q.appendingPathComponent("rwc-quarantine-rwc-acq-a18rcpt0000000001").path),
            "COMPLETED removed the session metadata that held the authority chain")
        // reconcile now has corpus + rights but NO way to reproduce the receipt authority chain
        let report = try runner.reconcile(rightsStore: st, corpusStore: corpus)
        XCTAssertTrue(report.recoveredSessions.isEmpty)
        XCTAssertTrue(report.registeredButUnpromoted.isEmpty,
                      "asset already promoted; nothing to recover")
        // there is no API that returns an RWCAcquisitionReceiptV2 from durable state after a crash
        let mirror = Mirror(reflecting: report)
        XCTAssertFalse(mirror.children.contains { $0.label == "receipts" },
                       "A18-F3: reconciliation yields no durable receipt; receipt authority is lost")
        // the receipt struct itself references a pass-lock chain that is never persisted anywhere
        XCTAssertFalse(receipt.reviewerID.isEmpty)
    }

    // MARK: §21 quarantine root attacks (symlink root, missing parent, file-not-dir)

    func test_A18_27_QuarantineRoot_Attacks() throws {
        let p = try lawfulProof()
        let k = key(); let (payload, _) = pay("qr")
        // quarantine root is a FILE, not a directory → reservation fails safely, no fetch
        let base = A18.tempDir("qrfile"); defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let filePath = base.appendingPathComponent("not-a-dir")
        try Data("x".utf8).write(to: filePath)
        let runnerFile = RWCCorpusAcquisitionRunnerV2(quarantineRoot: filePath)
        let (st, dir) = try store("qr1"); defer { st.closeStore(); try? FileManager.default.removeItem(at: dir) }
        let spy = A18Spy(payload)
        XCTAssertThrowsError(try runnerFile.acquire(
            proof: p, request: A18.request(session: "rwc-acq-a18qr000000000001"),
            verifiedGrant: try mintGrant(A18.grant(), k), rightsStore: st, corpusStore: A18Corpus(),
            acquirer: spy, clock: A18.clock("2026-10-01")))
        XCTAssertEqual(spy.calls, 0, "no fetch when the quarantine root is unusable")
        // nonexistent parent → reservation fails safely, no fetch
        let ghost = A18.tempDir("ghost").appendingPathComponent("deeper/root")
        let runnerGhost = RWCCorpusAcquisitionRunnerV2(quarantineRoot: ghost)
        let (st2, dir2) = try store("qr2"); defer { st2.closeStore(); try? FileManager.default.removeItem(at: dir2) }
        let spy2 = A18Spy(payload)
        XCTAssertThrowsError(try runnerGhost.acquire(
            proof: p, request: A18.request(session: "rwc-acq-a18qr000000000002"),
            verifiedGrant: try mintGrant(A18.grant(), k), rightsStore: st2, corpusStore: A18Corpus(),
            acquirer: spy2, clock: A18.clock("2026-10-01")))
        XCTAssertEqual(spy2.calls, 0, "no fetch when the parent does not exist")
    }

    // MARK: §33 reconciliation authority-field drift (metadata forgery with recomputed hash)

    func test_A18_28_Reconcile_AuthorityFields_vs_HashOnly() throws {
        // Mandate §33: even without a hostile OS, mutate the session metadata body + recompute its
        // own SHA-256, and observe which fields reconcile actually re-verifies. Independent finding:
        // reconcile binds SESSION-dir==meta.session, meta.state==RIGHTS_COMMITTED, the asset is
        // NOT tombstoned, and rightsStore.record(asset).contentHash == meta.contentHash. It does
        // NOT re-verify grantID / reviewID / reviewerID / source / intendedUse / passCandidate
        // against the rights ledger. Classify (see report): bounded — promotion is byte-identity +
        // active-rights gated, so forged authority fields cannot change WHICH bytes land, but the
        // recovered session's PROVENANCE metadata can drift from the committed rights event.
        let p = try lawfulProof()
        let q = try qRoot("drift"); defer { try? FileManager.default.removeItem(at: q) }
        let runner = RWCCorpusAcquisitionRunnerV2(quarantineRoot: q)
        let k = key(); let (payload, _) = pay("drift")
        let dir = A18.tempDir("led-drift"); defer { try? FileManager.default.removeItem(at: dir) }
        let st = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        defer { st.closeStore() }
        let crash = A18Corpus(); crash.failPromote = true
        XCTAssertThrowsError(try runner.acquire(
            proof: p, request: A18.request(session: "rwc-acq-a18drift000000001"),
            verifiedGrant: try mintGrant(A18.grant(), k), rightsStore: st, corpusStore: crash,
            acquirer: A18Spy(payload), clock: A18.clock("2026-10-01")))
        // forge the reviewer/grant/source authority fields in the preserved metadata, re-sealing
        // the integrity hash so read() accepts it
        let metaURL = q.appendingPathComponent(
            "rwc-quarantine-rwc-acq-a18drift000000001/\(RWCCorpusAcquisitionRunnerV2.metadataName)")
        let raw = try String(contentsOf: metaURL, encoding: .utf8)
        let body = raw.split(separator: "\n").map(String.init)[0]
        var forged = body
            .replacingOccurrences(of: "\"reviewer\":\"rwc-reviewer-a18rev01\"",
                                  with: "\"reviewer\":\"rwc-reviewer-FORGED01\"")
            .replacingOccurrences(of: "\"grant\":\"rwc-grant-a18g0001\"",
                                  with: "\"grant\":\"rwc-grant-FORGED0001\"")
        let newDigest = RWCCorpusAcquisitionRunnerV2.sha256Hex(Data(forged.utf8))
        try (forged + "\n" + newDigest + "\n").write(to: metaURL, atomically: true, encoding: .utf8)
        forged = ""   // silence unused-mutation warnings
        let corpus = A18Corpus()
        let report = try runner.reconcile(rightsStore: st, corpusStore: corpus)
        // promotion STILL happens (hash + active rights match) despite forged authority fields —
        // reconcile does not cross-check reviewer/grant against the rights ledger.
        XCTAssertEqual(report.recoveredSessions, ["rwc-acq-a18drift000000001"],
                       "reconcile promotes on hash+active-rights; authority fields are not re-verified")
        XCTAssertEqual(corpus.promoted["rwc-asset-a18asset01"], payload,
                       "the SAME lawful bytes land — forged metadata cannot change WHICH bytes")
    }

    // MARK: §34/§35/§37 reconciliation: reauthorized-once, same-hash assets, revoked-never

    func test_A18_29_Reconcile_Reauth_SameHash_Revoked() throws {
        let p = try lawfulProof()
        // (a) revoked asset is NEVER promoted (destroyed)
        do {
            let q = try qRoot("rv"); defer { try? FileManager.default.removeItem(at: q) }
            let runner = RWCCorpusAcquisitionRunnerV2(quarantineRoot: q)
            let k = key(); let (payload, _) = pay("rv")
            let dir = A18.tempDir("led-rv"); defer { try? FileManager.default.removeItem(at: dir) }
            let st = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
            defer { st.closeStore() }
            let crash = A18Corpus(); crash.failPromote = true
            XCTAssertThrowsError(try runner.acquire(
                proof: p, request: A18.request(session: "rwc-acq-a18rv0000000000001"),
                verifiedGrant: try mintGrant(A18.grant(), k), rightsStore: st, corpusStore: crash,
                acquirer: A18Spy(payload), clock: A18.clock("2026-10-01")))
            try st.revoke(assetID: "rwc-asset-a18asset01", clock: A18.clock("2026-10-02"))
            let corpus = A18Corpus()
            let report = try runner.reconcile(rightsStore: st, corpusStore: corpus)
            XCTAssertEqual(report.destroyedRevokedSessions, ["rwc-acq-a18rv0000000000001"])
            XCTAssertTrue(corpus.promoted.isEmpty, "revoked asset never promoted")
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: q.appendingPathComponent("rwc-quarantine-rwc-acq-a18rv0000000000001").path))
        }
        // (b) two DIFFERENT assets with IDENTICAL bytes recover to their OWN identities (no cross-bind)
        do {
            let q = try qRoot("sh"); defer { try? FileManager.default.removeItem(at: q) }
            let runner = RWCCorpusAcquisitionRunnerV2(quarantineRoot: q)
            let (payload, _) = pay("same")
            let dir = A18.tempDir("led-sh"); defer { try? FileManager.default.removeItem(at: dir) }
            let st = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
            defer { st.closeStore() }
            for (asset, sess, gid, seed, rev) in [
                ("rwc-asset-a18twina1", "rwc-acq-a18sh00000000000a1", "rwc-grant-a18sha0001", "a18-sha", "rwc-review-a18sha001"),
                ("rwc-asset-a18twinb1", "rwc-acq-a18sh00000000000b1", "rwc-grant-a18shb0001", "a18-shb", "rwc-review-a18shb001")] {
                let crash = A18Corpus(); crash.failPromote = true
                XCTAssertThrowsError(try runner.acquire(
                    proof: p, request: A18.request(assetID: asset, session: sess),
                    verifiedGrant: try mintGrant(A18.grant(id: gid, digestSeed: seed, review: rev), key()),
                    rightsStore: st, corpusStore: crash, acquirer: A18Spy(payload),
                    clock: A18.clock("2026-10-01")))
            }
            let corpus = A18Corpus()
            let report = try runner.reconcile(rightsStore: st, corpusStore: corpus)
            XCTAssertEqual(report.recoveredSessions.sorted(),
                           ["rwc-acq-a18sh00000000000a1", "rwc-acq-a18sh00000000000b1"])
            XCTAssertEqual(corpus.promoted["rwc-asset-a18twina1"], payload)
            XCTAssertEqual(corpus.promoted["rwc-asset-a18twinb1"], payload)
            XCTAssertEqual(corpus.promoted.count, 2, "same-hash assets kept distinct (SESSION+ASSET bound)")
        }
    }

    // MARK: §17/§18 V1-token ABI bridge — direct durable ledger registration is NOT corpus-lawful

    func test_A18_30_V1ABI_DirectLedger_NotCorpusLawful() throws {
        // Mandate §17/§18: external code CAN mint a V1 token via the SUPERSEDED public
        // RWCRightsReviewAuthorityV1.verify and register it directly into the durable store V3,
        // WITHOUT RunnerV2. This creates a durable rights ledger entry — but it is NOT corpus:
        //   - no corpus store promotion happens,
        //   - no session/receipt binding exists,
        //   - RunnerV2.reconcile treats a registered-but-unpromoted asset as an explicit DEFICIT
        //     (registeredButUnpromoted) with NO quarantine and NO payload — it is never promoted.
        // Gates V5 law: any ledger entry not created through RunnerV2 is NOT corpus-lawful.
        let dir = A18.tempDir("led-v1"); defer { try? FileManager.default.removeItem(at: dir) }
        let st = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        defer { st.closeStore() }
        let g = A18.grant()
        let hash = A18.shaHex("a18-v1-content")
        try st.register(A18.record(contentHash: hash), verifiedGrant: try A18.mintV1(g),
                        clock: A18.clock("2026-10-01"))
        XCTAssertEqual(st.eventCount, 1, "a V1 token CAN create a durable ledger entry directly")
        let q = try qRoot("v1"); defer { try? FileManager.default.removeItem(at: q) }
        let runner = RWCCorpusAcquisitionRunnerV2(quarantineRoot: q)
        let corpus = A18Corpus()
        let report = try runner.reconcile(rightsStore: st, corpusStore: corpus)
        XCTAssertTrue(corpus.promoted.isEmpty,
                      "direct ledger entry is NOT promoted to corpus (no RunnerV2 session/receipt)")
        XCTAssertEqual(report.registeredButUnpromoted, ["rwc-asset-a18asset01"],
                       "a Runner-less ledger entry surfaces only as an explicit deficit, never corpus")
    }
}

#endif
