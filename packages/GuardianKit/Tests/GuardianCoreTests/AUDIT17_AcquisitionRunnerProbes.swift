import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
#if os(macOS)
import RWCAcquisition
#endif

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT17_RWC_PRE14_R3_REAUDIT — part 3 of 3: first-asset acquisition authority battery +
// env-gated independent statistical replication runner. Synthetic fixtures only; the global proof
// token is minted lawfully from a synthetic fixture repo (the type law is never forged).
// ═══════════════════════════════════════════════════════════════════════════════════════════════

#if os(macOS)

private final class A17SpyAcquirer: RWCAssetAcquirerV1 {
    private(set) var calls = 0
    private(set) var lastSourceReference: String?
    let payload: Data
    let onFetch: (() throws -> Void)?
    init(_ payload: Data, onFetch: (() throws -> Void)? = nil) {
        self.payload = payload
        self.onFetch = onFetch
    }
    func fetch(sourceReference: String) throws -> Data {
        calls += 1
        lastSourceReference = sourceReference
        try onFetch?()
        return payload
    }
}

private final class A17CorpusStore: RWCCorpusStoreV1 {
    private(set) var promoted: [String: Data] = [:]
    private(set) var promoteCalls = 0
    var failPromote = false
    func promote(assetID: String, contentHash: String, payload: Data) throws {
        promoteCalls += 1
        if failPromote { throw RWCAcquisitionErrorV1.corpusStoreFailure("a17 fixture failure") }
        promoted[assetID] = payload
    }
    func storedAssetIDs() throws -> [String] { Array(promoted.keys) }
}

private final class A17TickClock: @unchecked Sendable {
    private let lock = NSLock()
    private var i = 0
    private let epochs: [Int64]
    init(_ epochs: [Int64]) { self.epochs = epochs }
    func next() -> Int64 {
        lock.lock(); defer { lock.unlock() }
        let v = epochs[min(i, epochs.count - 1)]
        i += 1
        return v
    }
}

final class AUDIT17_AcquisitionRunnerProbes: XCTestCase {

    private var proofCache: (RWCVerifiedCorpusEntryV3, URL)?

    private func lawfulProof() throws -> RWCVerifiedCorpusEntryV3 {
        if let (p, _) = proofCache { return p }
        let fx = try A17Fx.make()
        let p = try RWCCorpusEntryVerifierV3.verify(repoRoot: fx.root)
        proofCache = (p, fx.root)
        return p
    }

    override func tearDown() {
        if let (_, root) = proofCache { try? FileManager.default.removeItem(at: root) }
        proofCache = nil
        super.tearDown()
    }

    private func payloadAndHash(_ seed: String) -> (Data, String) {
        let d = Data("a17-payload-\(seed)".utf8)
        return (d, RWCCorpusAcquisitionRunnerV1.sha256Hex(d))
    }

    private func freshStore(_ tag: String) throws -> (RWCAssetRightsLedgerStoreV3, URL) {
        let dir = A17.tempDir("led-\(tag)")
        return (try RWCAssetRightsLedgerStoreV3.create(directory: dir), dir)
    }

    // MARK: §41 AUDIT17 FINDING A17-F2 — pre-fetch record validation gap (spy counts)

    func test_A17_30_FINDING_A17F2_PreFetch_SpyBattery() throws {
        // AUDIT17 FINDING A17-F2: pins defective behavior.
        // acquire() validates ONLY (grant==record, grant grammar, assetID) before fetch. The full
        // record validation — source class eligibility, sourceReference grammar, owner,
        // provenance, grant validity window, expiry-at-registration — happens in
        // rightsStore.register AFTER raw bytes have already been fetched into quarantine.
        let proof = try lawfulProof()
        let qRoot = A17.tempDir("q-f2")
        defer { try? FileManager.default.removeItem(at: qRoot) }
        try FileManager.default.createDirectory(at: qRoot, withIntermediateDirectories: true)
        let runner = RWCCorpusAcquisitionRunnerV1(quarantineRoot: qRoot)
        let (payload, hash) = payloadAndHash("f2")

        func attempt(_ label: String, record: RWCAssetRightsRecordV3,
                     grant: RWCLegalGrantIdentityV1, session: String,
                     expectFetches: Int, clockISO: String = "2026-10-01",
                     file: StaticString = #filePath, line: UInt = #line) throws {
            let (store, dir) = try freshStore(session)
            defer { store.closeStore(); try? FileManager.default.removeItem(at: dir) }
            let spy = A17SpyAcquirer(payload)
            let corpus = A17CorpusStore()
            XCTAssertThrowsError(try runner.acquire(
                proof: proof, record: record, verifiedGrant: try A17.mint(grant),
                rightsStore: store, corpusStore: corpus, acquirer: spy,
                clock: A17.clock(clockISO), sessionID: session), label, file: file, line: line)
            XCTAssertEqual(spy.calls, expectFetches, "\(label): fetch count", file: file, line: line)
            XCTAssertEqual(store.eventCount, 0, label, file: file, line: line)
            XCTAssertTrue(corpus.promoted.isEmpty, label, file: file, line: line)
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: qRoot.appendingPathComponent("rwc-quarantine-\(session)").path),
                "\(label): quarantine destroyed", file: file, line: line)
        }

        // INELIGIBLE SOURCE CLASS fetches bytes first (A17-F2)
        try attempt("ineligible sourceClass", record: A17.record(sourceClass: .refusedScraped,
            contentHash: hash), grant: A17.grant(), session: "f2a", expectFetches: 1)
        // invalid sourceReference grammar — the raw invalid reference IS handed to the acquirer
        try attempt("invalid sourceReference", record: A17.record(sourceRef: "https://evil.example",
            contentHash: hash, provenance: ["rwc-source-ref-a17s0001"]), grant: A17.grant(),
            session: "f2b", expectFetches: 1)
        // empty owner
        try attempt("empty owner", record: A17.record(owner: "  ", contentHash: hash),
                    grant: A17.grant(), session: "f2c", expectFetches: 1)
        // empty provenance
        try attempt("empty provenance", record: A17.record(contentHash: hash, provenance: []),
                    grant: A17.grant(), session: "f2d", expectFetches: 1)
        // acquisition before the grant becomes effective
        try attempt("not yet effective", record: A17.record(acquisition: "2026-07-01",
            contentHash: hash), grant: A17.grant(), session: "f2e", expectFetches: 1)
        // grant expired at registration time (acquisition inside window, today past expiry)
        let expiring = A17.grant(id: "rwc-grant-a17exp01", digestSeed: "a17-exp",
                                 expiry: "2026-09-15", review: "rwc-review-a17exp01")
        try attempt("expired at registration", record: A17.record(g: expiring,
            acquisition: "2026-09-01", contentHash: hash), grant: expiring, session: "f2f",
            expectFetches: 1)
        // invalid contentHash grammar — never checked pre-fetch; fails only as a hash mismatch
        try attempt("invalid contentHash grammar", record: A17.record(contentHash: "NOT-A-HASH"),
                    grant: A17.grant(), session: "f2g", expectFetches: 1)
        // duplicate registration also fetches first
        do {
            let (store, dir) = try freshStore("f2h")
            defer { store.closeStore(); try? FileManager.default.removeItem(at: dir) }
            let g = A17.grant()
            try store.register(A17.record(contentHash: hash), verifiedGrant: A17.mint(g),
                               clock: A17.clock("2026-10-01"))
            let spy = A17SpyAcquirer(payload)
            XCTAssertThrowsError(try runner.acquire(
                proof: proof, record: A17.record(contentHash: hash), verifiedGrant: try A17.mint(g),
                rightsStore: store, corpusStore: A17CorpusStore(), acquirer: spy,
                clock: A17.clock("2026-10-02"), sessionID: "f2h"))
            XCTAssertEqual(spy.calls, 1, "A17-F2: duplicate registration fetched bytes first")
        }
        // boundary confirmation: stage-1..3 refusals DO keep fetch at 0
        do {
            let (store, dir) = try freshStore("f2z")
            defer { store.closeStore(); try? FileManager.default.removeItem(at: dir) }
            let spy = A17SpyAcquirer(payload)
            // grant/record mismatch
            XCTAssertThrowsError(try runner.acquire(
                proof: try lawfulProof(), record: A17.record(contentHash: hash),
                verifiedGrant: try A17.mint(A17.grant(id: "rwc-grant-a17other1",
                                                      digestSeed: "other",
                                                      review: "rwc-review-a17oth01")),
                rightsStore: store, corpusStore: A17CorpusStore(), acquirer: spy,
                clock: A17.clock("2026-10-01"), sessionID: "f2z")) { e in
                XCTAssertEqual(e as? RWCAcquisitionErrorV1, .grantRecordMismatch)
            }
            XCTAssertEqual(spy.calls, 0)
            // invalid asset ID
            XCTAssertThrowsError(try runner.acquire(
                proof: try lawfulProof(), record: A17.record(asset: "rwc-asset-BAD!",
                                                             contentHash: hash),
                verifiedGrant: try A17.mint(A17.grant()), rightsStore: store,
                corpusStore: A17CorpusStore(), acquirer: spy, clock: A17.clock("2026-10-01"),
                sessionID: "f2z2"))
            XCTAssertEqual(spy.calls, 0)
            // invalid grant grammar (validateGrant is pre-fetch)
            let badGrant = A17.grant(pointer: "not-a-pointer")
            XCTAssertThrowsError(try runner.acquire(
                proof: try lawfulProof(), record: A17.record(g: badGrant, contentHash: hash),
                verifiedGrant: try A17.mint(A17.grant()), rightsStore: store,
                corpusStore: A17CorpusStore(), acquirer: spy, clock: A17.clock("2026-10-01"),
                sessionID: "f2z3"))
            XCTAssertEqual(spy.calls, 0)
        }
    }

    // MARK: §40 AUDIT17 FINDING A17-F5 — intended use never declared before bytes move

    func test_A17_31_FINDING_A17F5_IntendedUse_EvalOnly_EmptyUse() throws {
        // AUDIT17 FINDING A17-F5: pins defective behavior.
        // acquire() has NO intendedUse parameter; registration is use-agnostic. An
        // EVALUATION-ONLY grant acquires and stores bytes with no declaration that the intended
        // use is authorized; a grant allowing NO use at all passes the entire pipeline.
        let proof = try lawfulProof()
        let qRoot = A17.tempDir("q-f5")
        defer { try? FileManager.default.removeItem(at: qRoot) }
        try FileManager.default.createDirectory(at: qRoot, withIntermediateDirectories: true)
        let runner = RWCCorpusAcquisitionRunnerV1(quarantineRoot: qRoot)
        let (payload, hash) = payloadAndHash("f5")
        // evaluation-only grant: fetch + promote succeed although the project intent may be training
        let evalOnly = A17.grant(id: "rwc-grant-a17eval01", digestSeed: "a17-eval",
                                 allowed: ["evaluation"], prohibited: ["training"],
                                 review: "rwc-review-a17eval1")
        let (store, dir) = try freshStore("f5")
        defer { store.closeStore(); try? FileManager.default.removeItem(at: dir) }
        let spy = A17SpyAcquirer(payload)
        let corpus = A17CorpusStore()
        let receipt = try runner.acquire(
            proof: proof, record: A17.record(g: evalOnly, contentHash: hash),
            verifiedGrant: try A17.mint(evalOnly), rightsStore: store, corpusStore: corpus,
            acquirer: spy, clock: A17.clock("2026-10-01"), sessionID: "f5a")
        XCTAssertEqual(spy.calls, 1, "A17-F5: evaluation-only grant fetched bytes with no use gate")
        XCTAssertNotNil(corpus.promoted["rwc-asset-a17asset01"])
        XCTAssertThrowsError(try store.requireEligible(assetID: "rwc-asset-a17asset01",
                                                       use: .training, clock: A17.clock("2026-10-02")))
        // the receipt has no intendedUse field at all (census)
        let labels = Mirror(reflecting: receipt).children.compactMap(\.label)
        XCTAssertFalse(labels.contains("intendedUse"),
                       "A17-F5: receipt does not record any intended use")
        // grant with EMPTY allowedUse — authorizes NOTHING — passes the full pipeline
        let useless = A17.grant(id: "rwc-grant-a17none01", digestSeed: "a17-none",
                                allowed: [], prohibited: [], review: "rwc-review-a17none1")
        let (store2, dir2) = try freshStore("f5b")
        defer { store2.closeStore(); try? FileManager.default.removeItem(at: dir2) }
        let corpus2 = A17CorpusStore()
        XCTAssertNoThrow(try runner.acquire(
            proof: proof, record: A17.record(asset: "rwc-asset-a17asset06", g: useless,
                                             contentHash: hash),
            verifiedGrant: try A17.mint(useless), rightsStore: store2, corpusStore: corpus2,
            acquirer: A17SpyAcquirer(payload), clock: A17.clock("2026-10-01"), sessionID: "f5c"),
            "A17-F5: a grant allowing NO use acquired and stored bytes")
        XCTAssertThrowsError(try store2.requireEligible(assetID: "rwc-asset-a17asset06",
                                                        use: .training, clock: A17.clock("2026-10-02")))
        XCTAssertThrowsError(try store2.requireEligible(assetID: "rwc-asset-a17asset06",
                                                        use: .evaluation, clock: A17.clock("2026-10-02")))
    }

    // MARK: §44/§45 AUDIT17 FINDING A17-F6 — session-ID path safety + collision

    func test_A17_32_FINDING_A17F6_SessionTraversal_DuplicateSession() throws {
        // AUDIT17 FINDING A17-F6: pins defective behavior.
        // No session-ID grammar exists. A '../'-laden session escapes the quarantine root, and a
        // duplicate session ID silently REUSES the existing quarantine directory, letting a second
        // transaction destroy the preserved payload of a first (crashed) transaction.
        let proof = try lawfulProof()
        let base = A17.tempDir("q-f6")
        defer { try? FileManager.default.removeItem(at: base) }
        let qRoot = base.appendingPathComponent("deep/inner")
        try FileManager.default.createDirectory(at: qRoot, withIntermediateDirectories: true)
        let runner = RWCCorpusAcquisitionRunnerV1(quarantineRoot: qRoot)
        let (payload, hash) = payloadAndHash("f6")
        // TRAVERSAL: quarantine lands OUTSIDE the quarantine root (observed during fetch)
        let escaped = base.appendingPathComponent("deep/escaped-a17")
        let (store, dir) = try freshStore("f6")
        defer { store.closeStore(); try? FileManager.default.removeItem(at: dir) }
        var escapeObserved = false
        let spy = A17SpyAcquirer(payload) {
            escapeObserved = FileManager.default.fileExists(atPath: escaped.path)
            throw RWCAcquisitionErrorV1.corpusStoreFailure("a17 abort after observation")
        }
        XCTAssertThrowsError(try runner.acquire(
            proof: proof, record: A17.record(contentHash: hash),
            verifiedGrant: try A17.mint(A17.grant()), rightsStore: store,
            corpusStore: A17CorpusStore(), acquirer: spy, clock: A17.clock("2026-10-01"),
            sessionID: "../../../escaped-a17"))
        XCTAssertTrue(escapeObserved,
                      "A17-F6: session '../../../escaped-a17' created a directory OUTSIDE the quarantine root")
        // slash/dot session IDs are likewise accepted (no grammar refusal path exists)
        XCTAssertEqual(spy.calls, 1)
        // DUPLICATE SESSION: second transaction reuses and then destroys the shared quarantine
        let (s1, d1) = try freshStore("f6s1")
        defer { s1.closeStore(); try? FileManager.default.removeItem(at: d1) }
        let crashCorpus = A17CorpusStore()
        crashCorpus.failPromote = true
        XCTAssertThrowsError(try runner.acquire(
            proof: proof, record: A17.record(contentHash: hash),
            verifiedGrant: try A17.mint(A17.grant()), rightsStore: s1, corpusStore: crashCorpus,
            acquirer: A17SpyAcquirer(payload), clock: A17.clock("2026-10-01"), sessionID: "dupx"))
        let preserved = qRoot.appendingPathComponent("rwc-quarantine-dupx/payload")
        XCTAssertTrue(FileManager.default.fileExists(atPath: preserved.path),
                      "crashed transaction preserves its quarantine for reconciliation")
        let (s2, d2) = try freshStore("f6s2")
        defer { s2.closeStore(); try? FileManager.default.removeItem(at: d2) }
        let (payload2, hash2) = payloadAndHash("f6-second")
        XCTAssertNoThrow(try runner.acquire(
            proof: proof, record: A17.record(asset: "rwc-asset-a17asset07", g: A17.grant(
                id: "rwc-grant-a17dup02", digestSeed: "a17-dup2", review: "rwc-review-a17dup02"),
                contentHash: hash2),
            verifiedGrant: try A17.mint(A17.grant(id: "rwc-grant-a17dup02", digestSeed: "a17-dup2",
                                                  review: "rwc-review-a17dup02")),
            rightsStore: s2, corpusStore: A17CorpusStore(), acquirer: A17SpyAcquirer(payload2),
            clock: A17.clock("2026-10-01"), sessionID: "dupx"),
            "duplicate session ID accepted without collision refusal")
        XCTAssertFalse(FileManager.default.fileExists(atPath: preserved.path),
                       "A17-F6: the second transaction destroyed the first transaction's preserved payload")
        let report = try runner.reconcile(rightsStore: s1, corpusStore: crashCorpus)
        XCTAssertEqual(report.registeredButUnpromoted, ["rwc-asset-a17asset01"],
                       "A17-F6: recovery is impossible — explicit deficit remains")
    }

    // MARK: §47 AUDIT17 FINDING A17-F9 — no single authoritative transaction date

    func test_A17_33_FINDING_A17F9_ClockDrift_WithinTransaction() throws {
        // AUDIT17 FINDING A17-F9: pins defective behavior.
        // The runner calls clock.today() once inside the rights commit and AGAIN for the receipt.
        // Across a midnight boundary the committed rights event date and the receipt
        // acquisitionDate diverge inside one transaction.
        let proof = try lawfulProof()
        let qRoot = A17.tempDir("q-f9")
        defer { try? FileManager.default.removeItem(at: qRoot) }
        try FileManager.default.createDirectory(at: qRoot, withIntermediateDirectories: true)
        let runner = RWCCorpusAcquisitionRunnerV1(quarantineRoot: qRoot)
        let (payload, hash) = payloadAndHash("f9")
        let tick = A17TickClock([0, 86_400])   // register: 1970-01-01, receipt: 1970-01-02
        let clock = RWCAcquisitionClockV2(secondsSince1970: { tick.next() })
        let g = A17.grant(effective: "1969-12-01", expiry: nil)
        let (store, dir) = try freshStore("f9")
        defer { store.closeStore(); try? FileManager.default.removeItem(at: dir) }
        let receipt = try runner.acquire(
            proof: proof, record: A17.record(g: g, acquisition: "1970-01-01", contentHash: hash),
            verifiedGrant: try A17.mint(g), rightsStore: store, corpusStore: A17CorpusStore(),
            acquirer: A17SpyAcquirer(payload), clock: clock, sessionID: "f9")
        XCTAssertEqual(store.events.last?.recordedDate, "1970-01-01")
        XCTAssertEqual(receipt.acquisitionDate, "1970-01-02",
                       "A17-F9: receipt date != rights-event date within ONE transaction")
    }

    // MARK: §48 promote crash → restart → reconcile

    func test_A17_34_PromoteCrash_Restart_Reconcile() throws {
        let proof = try lawfulProof()
        let qRoot = A17.tempDir("q-f48")
        defer { try? FileManager.default.removeItem(at: qRoot) }
        try FileManager.default.createDirectory(at: qRoot, withIntermediateDirectories: true)
        let runner = RWCCorpusAcquisitionRunnerV1(quarantineRoot: qRoot)
        let (payload, hash) = payloadAndHash("f48")
        let dir = A17.tempDir("led-f48")
        defer { try? FileManager.default.removeItem(at: dir) }
        do {
            let store = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
            let corpus = A17CorpusStore()
            corpus.failPromote = true
            XCTAssertThrowsError(try runner.acquire(
                proof: proof, record: A17.record(contentHash: hash),
                verifiedGrant: try A17.mint(A17.grant()), rightsStore: store, corpusStore: corpus,
                acquirer: A17SpyAcquirer(payload), clock: A17.clock("2026-10-01"),
                sessionID: "f48")) { e in
                guard case .promoteFailure = e as? RWCAcquisitionErrorV1 else {
                    return XCTFail("\(e)")
                }
            }
            XCTAssertEqual(store.eventCount, 1, "rights committed before the failed promote")
            store.closeStore()   // process 'crash' + restart
        }
        let reopened = try RWCAssetRightsLedgerStoreV3.openExisting(directory: dir)
        defer { reopened.closeStore() }
        XCTAssertEqual(reopened.eventCount, 1, "rights survive the restart")
        let corpus = A17CorpusStore()
        let report = try runner.reconcile(rightsStore: reopened, corpusStore: corpus)
        XCTAssertEqual(report.recoveredFromQuarantine, ["rwc-asset-a17asset01"])
        XCTAssertEqual(corpus.promoted["rwc-asset-a17asset01"], payload)
        XCTAssertTrue(report.registeredButUnpromoted.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: qRoot.appendingPathComponent("rwc-quarantine-f48").path))
    }

    // MARK: §49/§50 AUDIT17 FINDING A17-F7 — reconciliation authority defects

    func test_A17_35_FINDING_A17F7_Reconcile_DuplicateEvents_HashOnlyBinding() throws {
        // AUDIT17 FINDING A17-F7: pins defective behavior.
        // (a) reconcile() iterates qualifying EVENTS, not unique assets, and its `stored` snapshot
        //     is never updated: an active reauthorized asset (registered + reauthorized events) is
        //     recovered TWICE, consuming two quarantines and double-promoting.
        // (b) quarantine→asset matching is CONTENT-HASH-ONLY: session identity is never bound, so
        //     with identical payloads the session/receipt provenance is arbitrary.
        let qRoot = A17.tempDir("q-f7")
        defer { try? FileManager.default.removeItem(at: qRoot) }
        try FileManager.default.createDirectory(at: qRoot, withIntermediateDirectories: true)
        let runner = RWCCorpusAcquisitionRunnerV1(quarantineRoot: qRoot)
        let (payload, hash) = payloadAndHash("f7")
        let dir = A17.tempDir("led-f7")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        defer { store.closeStore() }
        let g1 = A17.grant()
        try store.register(A17.record(contentHash: hash), verifiedGrant: A17.mint(g1),
                           clock: A17.clock("2026-10-01"))
        try store.revoke(assetID: "rwc-asset-a17asset01", clock: A17.clock("2026-10-02"))
        let g2 = A17.grant(id: "rwc-grant-a17re01", digestSeed: "a17-re1",
                           review: "rwc-review-a17re01")
        try store.reauthorize(A17.record(g: g2, acquisition: "2026-10-03", contentHash: hash),
                              verifiedGrant: A17.mint(g2), clock: A17.clock("2026-10-04"))
        // two surviving quarantines with the same (correct) payload
        for s in ["qa1", "qa2"] {
            try A17.write(qRoot, "rwc-quarantine-\(s)/payload", "")
            try payload.write(to: qRoot.appendingPathComponent("rwc-quarantine-\(s)/payload"))
        }
        let corpus = A17CorpusStore()
        let report = try runner.reconcile(rightsStore: store, corpusStore: corpus)
        XCTAssertEqual(report.recoveredFromQuarantine,
                       ["rwc-asset-a17asset01", "rwc-asset-a17asset01"],
                       "A17-F7: the SAME asset recovered twice (event-level iteration)")
        XCTAssertEqual(corpus.promoteCalls, 2, "A17-F7: double promote for one asset")
        // (b) two DIFFERENT assets with identical bytes: binding is arbitrary (hash-only)
        let dir2 = A17.tempDir("led-f7b")
        defer { try? FileManager.default.removeItem(at: dir2) }
        let store2 = try RWCAssetRightsLedgerStoreV3.create(directory: dir2)
        defer { store2.closeStore() }
        let gA = A17.grant(id: "rwc-grant-a17tw01", digestSeed: "a17-twA",
                           review: "rwc-review-a17tw01")
        let gB = A17.grant(id: "rwc-grant-a17tw02", digestSeed: "a17-twB",
                           review: "rwc-review-a17tw02")
        try store2.register(A17.record(asset: "rwc-asset-a17twina", g: gA, contentHash: hash),
                            verifiedGrant: A17.mint(gA), clock: A17.clock("2026-10-01"))
        try store2.register(A17.record(asset: "rwc-asset-a17twinb", g: gB, contentHash: hash),
                            verifiedGrant: A17.mint(gB), clock: A17.clock("2026-10-01"))
        for s in ["tw1", "tw2"] {
            try A17.write(qRoot, "rwc-quarantine-\(s)/payload", "")
            try payload.write(to: qRoot.appendingPathComponent("rwc-quarantine-\(s)/payload"))
        }
        let corpus2 = A17CorpusStore()
        let report2 = try runner.reconcile(rightsStore: store2, corpusStore: corpus2)
        XCTAssertEqual(report2.recoveredFromQuarantine.sorted(),
                       ["rwc-asset-a17twina", "rwc-asset-a17twinb"],
                       "both recovered — but session→asset binding is hash-only and arbitrary")
    }

    // MARK: §51 orphan quarantine battery

    func test_A17_36_OrphanQuarantine_Battery() throws {
        let qRoot = A17.tempDir("q-orph")
        defer { try? FileManager.default.removeItem(at: qRoot) }
        try FileManager.default.createDirectory(at: qRoot, withIntermediateDirectories: true)
        let runner = RWCCorpusAcquisitionRunnerV1(quarantineRoot: qRoot)
        let dir = A17.tempDir("led-orph")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try RWCAssetRightsLedgerStoreV3.create(directory: dir)
        defer { store.closeStore() }
        // orphan with payload, orphan without payload (partial), orphan with nested files
        try A17.write(qRoot, "rwc-quarantine-orph1/payload", "orphan-raw-bytes")
        try FileManager.default.createDirectory(
            at: qRoot.appendingPathComponent("rwc-quarantine-orph2"),
            withIntermediateDirectories: true)
        try A17.write(qRoot, "rwc-quarantine-orph3/payload", "nested-raw")
        try A17.write(qRoot, "rwc-quarantine-orph3/extra/deep.bin", "more-raw")
        // orphan whose payload is a SYMLINK to an outside file: must not destroy the target
        let outside = qRoot.deletingLastPathComponent().appendingPathComponent("a17-outside.bin")
        try Data("outside-bytes".utf8).write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createDirectory(
            at: qRoot.appendingPathComponent("rwc-quarantine-orph4"),
            withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: qRoot.appendingPathComponent("rwc-quarantine-orph4/payload"),
            withDestinationURL: outside)
        let corpus = A17CorpusStore()
        let report = try runner.reconcile(rightsStore: store, corpusStore: corpus)
        XCTAssertEqual(report.destroyedOrphanQuarantines.sorted(),
                       ["orph1", "orph2", "orph3", "orph4"], "no raw orphan survives")
        for s in ["orph1", "orph2", "orph3", "orph4"] {
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: qRoot.appendingPathComponent("rwc-quarantine-\(s)").path), s)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path),
                      "symlink target outside quarantine is NOT destroyed")
        XCTAssertTrue(corpus.promoted.isEmpty, "orphans are never promoted")
        // OBSERVATION (recorded): reconcile READS payloads through symlinks (Data(contentsOf:)
        // follows links) — recovery is hash-gated, so substitution requires identical bytes;
        // bounded, recorded in the report as part of the session/quarantine findings.
    }

    // MARK: §53 receipt authority chain

    func test_A17_37_Receipt_AuthorityChain() throws {
        let proof = try lawfulProof()
        let qRoot = A17.tempDir("q-rcpt")
        defer { try? FileManager.default.removeItem(at: qRoot) }
        try FileManager.default.createDirectory(at: qRoot, withIntermediateDirectories: true)
        let runner = RWCCorpusAcquisitionRunnerV1(quarantineRoot: qRoot)
        let (payload, hash) = payloadAndHash("rcpt")
        let (store, dir) = try freshStore("rcpt")
        defer { store.closeStore(); try? FileManager.default.removeItem(at: dir) }
        let g = A17.grant()
        let receipt = try runner.acquire(
            proof: proof, record: A17.record(g: g, contentHash: hash),
            verifiedGrant: try A17.mint(g), rightsStore: store, corpusStore: A17CorpusStore(),
            acquirer: A17SpyAcquirer(payload), clock: A17.clock("2026-10-01"), sessionID: "rcpt1")
        XCTAssertEqual(receipt.sessionID, "rcpt1")
        XCTAssertEqual(receipt.assetID, "rwc-asset-a17asset01")
        XCTAssertEqual(receipt.contentHash, hash)
        XCTAssertEqual(receipt.legalGrantID, g.grantID)
        XCTAssertEqual(receipt.grantRevision, 1)
        XCTAssertEqual(receipt.reviewRecordID, g.reviewRecordID)
        XCTAssertEqual(receipt.rightsLedgerHeadDigest, store.headDigest)
        XCTAssertEqual(receipt.rightsEventCount, 1)
        XCTAssertEqual(receipt.passLockCandidateCommit, proof.candidateCommit)
        XCTAssertEqual(receipt.passLockTagObjectSHA, proof.candidateTagObjectSHA)
        XCTAssertEqual(receipt.auditResultBlobSHA256, proof.auditResultBlobSHA256)
        XCTAssertEqual(receipt.freezeManifestSHA256, proof.freezeManifestSHA256)
        XCTAssertEqual(receipt.methodologyAnchorCommit, proof.methodologyAnchorCommit)
        XCTAssertEqual(receipt.acquisitionDate, "2026-10-01")
        // census: 14 opaque identity/digest fields; no raw content; no sourceReference (the ledger
        // record carries it); no intendedUse (A17-F5 evidence, pinned in test_A17_31)
        let labels = Mirror(reflecting: receipt).children.compactMap(\.label)
        XCTAssertEqual(labels.count, 14)
        XCTAssertFalse(labels.contains("payload"))
    }
}

// MARK: - env-gated independent statistical replication (release-mode standalone)

final class AUDIT17_StatReplicationRunner17: XCTestCase {

    /// GEN8_AUDIT17_STATS=1 — fully independent Type-I + power replication (own RNG, own seeding
    /// domain, own ECE implementation, own decision rule per the frozen V4 law) at S=9999.
    /// Writes docs/audit/audit17_tools/results/audit17_stat_replication.json with Wilson CIs.
    func test_A17_40_IndependentTypeI_And_Power() throws {
        guard ProcessInfo.processInfo.environment["GEN8_AUDIT17_STATS"] == "1" else {
            throw XCTSkip("env-gated AUDIT17 heavy replication (GEN8_AUDIT17_STATS=1)")
        }
        let shapes = ["uniform", "skewed", "clustered", "quantized", "highconf", "lowconf"]
        let trials = 250
        let sims = 9999
        var typeI: [String: String] = [:]
        var power: [String: String] = [:]
        func cellJSON(_ rejects: Int, _ mcOnly: Int) -> String {
            let ci = A17Stat.wilson(rejects, trials)
            return "{\"rejects\": \(rejects), \"mc_only_rejects\": \(mcOnly), " +
                   "\"trials\": \(trials), " +
                   "\"reject_rate\": \(String(format: "%.4f", Double(rejects) / Double(trials))), " +
                   "\"wilson_lo\": \(String(format: "%.4f", ci.0)), " +
                   "\"wilson_hi\": \(String(format: "%.4f", ci.1))}"
        }
        // Type-I at n=800, S=9999
        for shape in shapes {
            var rejects = 0, mcOnly = 0
            for t in 0..<trials {
                let (p, y) = A17Stat.dataset(shape: shape, alt: "null", n: 800,
                                             seedParts: ["t1", shape, String(t), "d"])
                let dec = A17Stat.decide(preds: p, labels: y, sims: sims,
                                         seedParts: ["t1", shape, String(t), "e"])
                if dec.combinedReject { rejects += 1 }
                if dec.mcReject { mcOnly += 1 }
            }
            typeI["\(shape)|null|n800"] = cellJSON(rejects, mcOnly)
            let rate = Double(rejects) / Double(trials)
            XCTAssertLessThanOrEqual(rate, 0.12, "\(shape) Type-I inconsistent with prereg claim")
            let ci = A17Stat.wilson(rejects, trials)
            XCTAssertLessThanOrEqual(ci.0, 0.08, "\(shape) Type-I CI excludes nominal alpha")
        }
        // power cells: over07/under07 at n400+n800; structured alternatives at n800
        var cells: [(String, String, Int)] = []
        for shape in shapes {
            for n in [400, 800] {
                cells.append((shape, "over07", n))
                cells.append((shape, "under07", n))
            }
            for alt in ["tail07", "osc05", "localized07"] { cells.append((shape, alt, 800)) }
        }
        var n800Min = 1.0
        var n400Min = 1.0
        for (shape, alt, n) in cells {
            var rejects = 0, mcOnly = 0
            for t in 0..<trials {
                let (p, y) = A17Stat.dataset(shape: shape, alt: alt, n: n,
                                             seedParts: ["pw", shape, alt, String(n), String(t), "d"])
                let dec = A17Stat.decide(preds: p, labels: y, sims: sims,
                                         seedParts: ["pw", shape, alt, String(n), String(t), "e"])
                if dec.combinedReject { rejects += 1 }
                if dec.mcReject { mcOnly += 1 }
            }
            power["\(shape)|\(alt)|n\(n)"] = cellJSON(rejects, mcOnly)
            let rate = Double(rejects) / Double(trials)
            if alt == "over07" || alt == "under07" {
                if n == 800 {
                    n800Min = min(n800Min, rate)
                    XCTAssertGreaterThanOrEqual(rate, 0.80,
                        "n-law violated: \(shape)|\(alt)|n800 rejection \(rate) < 0.80")
                } else {
                    n400Min = min(n400Min, rate)
                }
            }
        }
        XCTAssertLessThan(n400Min, 0.80, "n=400 must FAIL the frozen selection law")
        XCTAssertGreaterThanOrEqual(n800Min, 0.80, "n=800 must clear the frozen criterion")
        // persist
        func dict(_ d: [String: String]) -> String {
            d.keys.sorted().map { "    \"\($0)\": \(d[$0]!)" }.joined(separator: ",\n")
        }
        let out = "{\n  \"family\": \"AUDIT17_RWC_PRE14_R3_REAUDIT\",\n" +
            "  \"engine\": \"independent (own xorshift64* RNG, own LP seeding domain " +
            "AUDIT17-INDEPENDENT-STAT, own tie-group equal-mass ECE, frozen decision law)\",\n" +
            "  \"design\": {\"trials\": \(trials), \"S\": \(sims), \"alpha\": 0.05},\n" +
            "  \"type_I\": {\n" + dict(typeI) + "\n  },\n" +
            "  \"power\": {\n" + dict(power) + "\n  },\n" +
            "  \"n_law\": {\"n400_min_over_under\": \(String(format: "%.4f", n400Min)), " +
            "\"n800_min_over_under\": \(String(format: "%.4f", n800Min))}\n}\n"
        let url = A17.repoRoot().appendingPathComponent(
            "docs/audit/audit17_tools/results/audit17_stat_replication.json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try out.data(using: .utf8)!.write(to: url)
        print("AUDIT17_STATS_WRITTEN=\(url.path)")
    }
}

#endif
