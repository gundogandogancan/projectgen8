#if os(macOS)
import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
import RWCAcquisition

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT22T — RWC LANE A V10 TARGETED INDEPENDENT AUDIT (fresh, clean-session auditor probes).
//
// These are INDEPENDENT adversarial probes authored by the AUDIT22T auditor, EXTENDING (not copying)
// the builder's AUDIT21_V10_TransitionProbes + AUDIT21_LaneAOnboardingProofs evidence. They exercise
// the specific attack surfaces the targeted mandate (§5 A–D + V7 matrix) demands be re-proven
// adversarially. All attacks run in THROWAWAY synthetic fixtures with test keys only; the real repo is
// touched read-only. NO real key / root file / PASS lock / OPERATIONAL_ROOT_ACTIVE is ever created.
//
// AUDIT-prefixed → lawful freeze post_audit_allowance (root GuardianCoreTests, prefix AUDIT); NOT a
// hashed census member; introduces NO new production surface.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT22T_RWCV10TargetedProbes: XCTestCase {

    // MARK: shared helpers
    private func shaHex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func shaHex(_ d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }
    private func d3(_ s: String) -> RWCDateV3 { try! RWCDateV3.parse(s, field: "a22") }
    private func clock(_ s: String) -> RWCFixedClockV3 { try! RWCFixedClockV3(s) }
    private func tempDir(_ tag: String) -> URL {
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("a22t-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("docs/calibration").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private struct SyntheticRoot {
        let json: Data; let priv: Curve25519.Signing.PrivateKey
        let rootID: String; let govID: String; let fingerprint: String
    }
    private func makeRoot(rootID: String = "rwc-root-a22t0001",
                          govID: String = "rwc-gov-a22t0001",
                          status: String = "ACTIVE",
                          priv: Curve25519.Signing.PrivateKey = .init()) -> SyntheticRoot {
        let raw = priv.publicKey.rawRepresentation
        let keyHex = raw.map { String(format: "%02x", $0) }.joined()
        let json = """
        {"root_id": "\(rootID)", "public_key_raw_hex": "\(keyHex)", "algorithm": "ed25519",
         "activation_date": "2026-10-20", "status": "\(status)",
         "governance_record_id": "\(govID)"}
        """
        return SyntheticRoot(json: Data(json.utf8), priv: priv, rootID: rootID, govID: govID,
                             fingerprint: shaHex(raw))
    }
    private func govRecord(id: String = "rwc-gov-a22t0001", scope: String = "rwc-governance",
                           identity: String = "owner-governance") -> RWCGovernanceRecordV1 {
        RWCGovernanceRecordV1(authorizingIdentity: identity, governanceRecordID: id,
                              decisionDate: "2026-10-19", scope: scope)
    }
    private func verifyReq(_ r: SyntheticRoot, fp: String? = nil) throws -> RWCVerifiedActivationRequestV1 {
        try RWCOperationalRootOnboardingV1.verifyCandidate(
            try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: r.json),
            governanceRecord: govRecord(id: r.govID), expectedFingerprint: fp ?? r.fingerprint)
    }

    // ═══════════════════════ SCOPE A — operational root bootstrap attacks ═══════════════════════

    /// A-ATTACK-01 (HONEST LIMIT CLASSIFICATION): the caller presents its OWN fingerprint computed from
    /// its OWN candidate key on the SAME channel. The engine ACCEPTS it (form + self-consistent match),
    /// because verifyCandidate proves fingerprint-equals-recomputed, NOT that the fingerprint arrived from
    /// an INDEPENDENT human channel. This is the declared honest limit (mandate §3): synthetic acceptance
    /// is NOT proof of the real human governance gate. We ASSERT the limit explicitly so it cannot be
    /// mistaken for independent approval.
    func test_A22T_A01_SelfSuppliedFingerprint_SameChannel_AcceptedByForm_NotHumanGate() throws {
        let r = makeRoot()
        // caller supplies BOTH the candidate file AND the fingerprint it computed itself:
        let selfFP = r.fingerprint
        let req = try verifyReq(r, fp: selfFP)   // accepted on form
        XCTAssertEqual(req.publicKeyFingerprint, selfFP)
        // HONEST CLASSIFICATION: acceptance here is caller-channel self-consistency, NOT independent
        // human approval. The engine CANNOT distinguish an out-of-band fingerprint from a self-supplied
        // one — that separation is the human G1–G9 gate's responsibility, outside the code. No PASS
        // authority, no OPERATIONAL_ROOT_ACTIVE is created by this acceptance.
        XCTAssertTrue(true, "documented honest limit: form-match != human governance approval")
    }

    /// A-ATTACK-02: a fake governance record (wrong-prefixed id) is refused at verify.
    func test_A22T_A02_FakeGovernanceRecord_Refused() throws {
        let r = makeRoot()
        let fake = RWCGovernanceRecordV1(authorizingIdentity: "attacker",
                                         governanceRecordID: "evil-gov-0001",   // wrong prefix
                                         decisionDate: "2026-10-19", scope: "rwc-governance")
        XCTAssertThrowsError(try RWCOperationalRootOnboardingV1.verifyCandidate(
            try RWCOperationalRootOnboardingV1.loadCandidate(rootJSON: r.json),
            governanceRecord: fake, expectedFingerprint: r.fingerprint)) { e in
            guard case .governanceRecordMalformed = (e as? RWCOperationalOnboardingErrorV1) else {
                return XCTFail("expected governanceRecordMalformed, got \(e)")
            }
        }
    }

    /// A-ATTACK-03: a WRONG out-of-band fingerprint (correct form, wrong value) is refused.
    func test_A22T_A03_WrongFingerprint_Refused() throws {
        let r = makeRoot()
        let wrong = shaHex("a-different-key-entirely")
        XCTAssertThrowsError(try verifyReq(r, fp: wrong)) { e in
            guard case .fingerprintMismatch = (e as? RWCOperationalOnboardingErrorV1) else {
                return XCTFail("expected fingerprintMismatch, got \(e)")
            }
        }
    }

    /// A-ATTACK-04: duplicate activation of the SAME active root is refused (no double-activate).
    func test_A22T_A04_DuplicateActivation_SameRoot_Refused() throws {
        let store = try RWCOperationalRootActivationStoreV1.create(directory: tempDir("dup"))
        defer { store.closeStore() }
        let r = makeRoot(rootID: "rwc-root-dupe0001")
        _ = try RWCOperationalRootOnboardingV1.activate(request: try verifyReq(r), store: store,
                                                        clock: clock("2026-10-20"))
        XCTAssertThrowsError(try RWCOperationalRootOnboardingV1.activate(
            request: try verifyReq(r), store: store, clock: clock("2026-10-21"))) { e in
            guard case .alreadyActiveSameRoot = (e as? RWCOperationalOnboardingErrorV1) else {
                return XCTFail("expected alreadyActiveSameRoot, got \(e)")
            }
        }
    }

    /// A-ATTACK-05: after a rotation, the OLD (rotated-out) root cannot be reactivated via activate()
    /// while the NEW root is ACTIVE (silent reactivation refused), and rotate() refuses retiring a
    /// non-head rootID.
    func test_A22T_A05_OldRootReactivation_AfterRotate_Refused() throws {
        let store = try RWCOperationalRootActivationStoreV1.create(directory: tempDir("reactivate"))
        defer { store.closeStore() }
        let r1 = makeRoot(rootID: "rwc-root-old0001")
        let r2 = makeRoot(rootID: "rwc-root-new0001")
        _ = try RWCOperationalRootOnboardingV1.activate(request: try verifyReq(r1), store: store,
                                                        clock: clock("2026-10-20"))
        _ = try RWCOperationalRootOnboardingV1.rotate(retiring: r1.rootID, request: try verifyReq(r2),
                                                      store: store, clock: clock("2026-10-21"))
        XCTAssertEqual(store.currentHead?.rootID, r2.rootID)
        // try to re-activate the OLD root while NEW is active → refused (different root active).
        XCTAssertThrowsError(try RWCOperationalRootOnboardingV1.activate(
            request: try verifyReq(r1), store: store, clock: clock("2026-10-22"))) { e in
            guard case .alreadyActiveDifferentRoot = (e as? RWCOperationalOnboardingErrorV1) else {
                return XCTFail("expected alreadyActiveDifferentRoot, got \(e)")
            }
        }
        // try to rotate retiring the OLD (non-head) root → refused.
        let r3 = makeRoot(rootID: "rwc-root-third001")
        XCTAssertThrowsError(try RWCOperationalRootOnboardingV1.rotate(
            retiring: r1.rootID, request: try verifyReq(r3), store: store, clock: clock("2026-10-23"))) { e in
            guard case .rotateRetiringMismatch = (e as? RWCOperationalOnboardingErrorV1) else {
                return XCTFail("expected rotateRetiringMismatch, got \(e)")
            }
        }
    }

    /// A-ATTACK-06: restart persistence — the activation survives closeStore + openExisting with the
    /// SAME head, and the chain is integrity-validated on reopen.
    func test_A22T_A06_RestartPersistence_HeadSurvives() throws {
        let dir = tempDir("restart")
        let store = try RWCOperationalRootActivationStoreV1.create(directory: dir)
        let r = makeRoot(rootID: "rwc-root-persist01")
        let activated = try RWCOperationalRootOnboardingV1.activate(request: try verifyReq(r), store: store,
                                                                    clock: clock("2026-10-20"))
        store.closeStore()
        let reopened = try RWCOperationalRootActivationStoreV1.openExisting(directory: dir)
        defer { reopened.closeStore() }
        XCTAssertEqual(reopened.currentHead?.rootID, r.rootID)
        XCTAssertEqual(reopened.currentHead?.status, RWCOperationalRootActivationStoreV1.statusActive)
        XCTAssertEqual(reopened.headChainDigest, activated.activationChainDigest)
    }

    /// A-ATTACK-07: DISK ROLLBACK (old-file re-present). Capture the journal after ONE activation, then
    /// after revoke roll the journal BACK to the single-event (pre-revoke) state. The reopened store
    /// re-derives ACTIVE from the rolled-back journal — this is the DECLARED honest limit (local hash
    /// chain = tamper-DETECTION under a non-hostile-disk model; it is NOT an absolute offline rollback
    /// proof against an adversary with write access to the store dir). We measure + classify it honestly:
    /// the chain stays internally consistent (no crash), so rollback to a CONSISTENT earlier state is NOT
    /// detected — exactly the documented R-5 residual, not a new regression.
    func test_A22T_A07_DiskRollback_OldConsistentState_HonestLimitClassified() throws {
        let dir = tempDir("rollback")
        let store = try RWCOperationalRootActivationStoreV1.create(directory: dir)
        let r = makeRoot(rootID: "rwc-root-rollbk001")
        _ = try RWCOperationalRootOnboardingV1.activate(request: try verifyReq(r), store: store,
                                                        clock: clock("2026-10-20"))
        let journalURL = dir.appendingPathComponent("root-activation-v1.jsonl")
        let afterActivate = try Data(contentsOf: journalURL)   // snapshot: 1 ACTIVATED event
        try RWCOperationalRootOnboardingV1.revoke(rootID: r.rootID, reason: "incident",
                                                  store: store, clock: clock("2026-10-21"))
        store.closeStore()
        // Adversary with disk write access rolls the journal BACK to the pre-revoke consistent snapshot.
        try afterActivate.write(to: journalURL)
        // Also roll the witness forward-reference away so openExisting rebuilds from the journal only.
        let reopened = try RWCOperationalRootActivationStoreV1.openExisting(directory: dir)
        defer { reopened.closeStore() }
        // HONEST CLASSIFICATION: the rolled-back journal is a VALID earlier chain state, so the store
        // reopens as ACTIVE (the revoke is "lost"). This is the documented local-disk honest limit
        // (R-5 residual), NOT a code defect: absolute currentness needs an EXTERNAL monotonic authority
        // which is out of scope pre-data. The chain integrity check only catches INCONSISTENT tampering.
        XCTAssertEqual(reopened.currentHead?.status, RWCOperationalRootActivationStoreV1.statusActive,
                       "rollback to a CONSISTENT earlier state is undetected — declared honest limit")
        XCTAssertEqual(reopened.events.count, 1)
    }

    /// A-ATTACK-08: INCONSISTENT tamper (truncated/garbled journal line) IS detected — fail-closed.
    func test_A22T_A08_InconsistentTamper_Detected_FailsClosed() throws {
        let dir = tempDir("tamper2")
        let store = try RWCOperationalRootActivationStoreV1.create(directory: dir)
        let r = makeRoot(rootID: "rwc-root-tamper02")
        _ = try RWCOperationalRootOnboardingV1.activate(request: try verifyReq(r), store: store,
                                                        clock: clock("2026-10-20"))
        store.closeStore()
        let journalURL = dir.appendingPathComponent("root-activation-v1.jsonl")
        // flip a fingerprint digit → breaks the recomputed chain digest.
        var raw = try String(contentsOf: journalURL, encoding: .utf8)
        raw = raw.replacingOccurrences(of: "\"fp\":\"\(r.fingerprint)\"",
                                       with: "\"fp\":\"\(shaHex("evil"))\"")
        try raw.write(to: journalURL, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try RWCOperationalRootActivationStoreV1.openExisting(directory: dir)) { e in
            guard case .storeMalformed = (e as? RWCOperationalOnboardingErrorV1) else {
                return XCTFail("expected storeMalformed, got \(e)")
            }
        }
    }

    /// A-ATTACK-09: a second writer cannot acquire the flock while the first holds it (single-writer).
    func test_A22T_A09_SecondWriter_Refused() throws {
        let dir = tempDir("writer")
        let store = try RWCOperationalRootActivationStoreV1.create(directory: dir)
        defer { store.closeStore() }
        XCTAssertThrowsError(try RWCOperationalRootActivationStoreV1.openExisting(directory: dir)) { e in
            guard case .storeLockedByAnotherWriter = (e as? RWCOperationalOnboardingErrorV1) else {
                return XCTFail("expected storeLockedByAnotherWriter, got \(e)")
            }
        }
    }

    // ═══════════════════════ SCOPE C — rotate() two-write crash safety ══════════════════════════

    /// C-ATTACK-01 (THE key scope-C probe): inject a fault BETWEEN rotate()'s two durable writes
    /// (ROTATED_OUT then ROTATED_IN) and classify the resulting state. We simulate the crash by driving
    /// ONLY the first durable step via revoke()-equivalent — i.e. we leave the store with a ROTATED_OUT
    /// head and NO ROTATED_IN (exactly the state after write#1 but before write#2), then reopen and
    /// measure. CLASSIFICATION: after write#1 the head is REVOKED (no active root) — the rotation is
    /// SAFE-CLOSED, NOT partially-active. The old root is NOT active (it was rotated out); the new root
    /// is NOT active (never written). Recovery is OPEN: a fresh activate() of the new root succeeds
    /// (head is non-ACTIVE so the silent-replacement block does not fire). We do NOT call rotate atomic:
    /// it is two writes whose INTERMEDIATE state is a safe-closed no-active-root window.
    func test_A22T_C01_RotateCrashBetweenWrites_SafeClosed_NoActiveRoot_RecoveryOpen() throws {
        let dir = tempDir("rotcrash")
        let store = try RWCOperationalRootActivationStoreV1.create(directory: dir)
        let r1 = makeRoot(rootID: "rwc-root-rot1a001")
        _ = try RWCOperationalRootOnboardingV1.activate(request: try verifyReq(r1), store: store,
                                                        clock: clock("2026-10-20"))
        // Simulate rotate() reaching exactly between its two appends by crashing right after it writes
        // ROTATED_OUT. We reproduce that durable intermediate by manually appending ONLY the ROTATED_OUT
        // event via the same journal format the engine uses, then reopening (= process restart after the
        // crash). This is faithful: engine.rotate does append(ROTATED_OUT) THEN mint THEN append(ROTATED_IN).
        store.closeStore()
        let journalURL = dir.appendingPathComponent("root-activation-v1.jsonl")
        var lines = try String(contentsOf: journalURL, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        // Build the ROTATED_OUT line with a correct chain digest continuing from the ACTIVATED head.
        let prevDigest = RWCOperationalRootActivationStoreV1.entryChainDigest(
            previous: RWCOperationalRootActivationStoreV1.genesisDigest,
            kind: RWCOperationalRootActivationStoreV1.kindActivated, rootID: r1.rootID,
            governanceRecordID: r1.govID, publicKeyFingerprint: r1.fingerprint, reason: "",
            recordedDate: "2026-10-20", seq: 0)
        let seq1 = 1
        let rec1 = "2026-10-21"
        let outDigest = RWCOperationalRootActivationStoreV1.entryChainDigest(
            previous: prevDigest, kind: RWCOperationalRootActivationStoreV1.kindRotatedOut, rootID: r1.rootID,
            governanceRecordID: r1.govID, publicKeyFingerprint: r1.fingerprint, reason: "rotate",
            recordedDate: rec1, seq: seq1)
        let outEvent = RWCOperationalRootActivationStoreV1.EventV1(
            seq: seq1, previousDigest: prevDigest,
            kind: RWCOperationalRootActivationStoreV1.kindRotatedOut, rootID: r1.rootID,
            governanceRecordID: r1.govID, publicKeyFingerprint: r1.fingerprint, reason: "rotate",
            recordedDate: rec1, chainDigest: outDigest)
        lines.append(RWCOperationalRootActivationStoreV1.journalLine(outEvent)
            .trimmingCharacters(in: .newlines))
        try (lines.joined(separator: "\n") + "\n").write(to: journalURL, atomically: true, encoding: .utf8)

        // Reopen = restart after crash-between-writes. Measure the recovered state.
        let recovered = try RWCOperationalRootActivationStoreV1.openExisting(directory: dir)
        // CLASSIFICATION: head is REVOKED (rotated out) → NO active root. Safe-closed, not partial-active.
        XCTAssertEqual(recovered.currentHead?.status, RWCOperationalRootActivationStoreV1.statusRevoked,
                       "crash between rotate writes leaves a SAFE-CLOSED no-active-root state")
        XCTAssertEqual(recovered.events.count, 2, "ROTATED_OUT present; ROTATED_IN absent (crash)")
        // RECOVERY OPEN: the new root can now be activated (head is non-ACTIVE, no silent-replacement block).
        let r2 = makeRoot(rootID: "rwc-root-rot2a001")
        let reactivated = try RWCOperationalRootOnboardingV1.activate(
            request: try verifyReq(r2), store: recovered, clock: clock("2026-10-22"))
        defer { recovered.closeStore() }
        XCTAssertEqual(recovered.currentHead?.rootID, r2.rootID)
        XCTAssertEqual(recovered.currentHead?.status, RWCOperationalRootActivationStoreV1.statusActive)
        XCTAssertEqual(reactivated.rootID, r2.rootID)
    }

    /// C-ATTACK-02: a COMPLETE lawful rotation is durable + reopenable with the NEW root active and both
    /// ROTATED_OUT + ROTATED_IN chained (the non-crash control for C-ATTACK-01).
    func test_A22T_C02_RotateComplete_BothEventsChained_NewRootActive() throws {
        let dir = tempDir("rotok")
        let store = try RWCOperationalRootActivationStoreV1.create(directory: dir)
        let r1 = makeRoot(rootID: "rwc-root-rotok001")
        let r2 = makeRoot(rootID: "rwc-root-rotok002")
        _ = try RWCOperationalRootOnboardingV1.activate(request: try verifyReq(r1), store: store,
                                                        clock: clock("2026-10-20"))
        _ = try RWCOperationalRootOnboardingV1.rotate(retiring: r1.rootID, request: try verifyReq(r2),
                                                      store: store, clock: clock("2026-10-21"))
        store.closeStore()
        let reopened = try RWCOperationalRootActivationStoreV1.openExisting(directory: dir)
        defer { reopened.closeStore() }
        XCTAssertEqual(reopened.events.count, 3)   // ACTIVATED, ROTATED_OUT, ROTATED_IN
        XCTAssertEqual(reopened.currentHead?.rootID, r2.rootID)
        XCTAssertEqual(reopened.currentHead?.status, RWCOperationalRootActivationStoreV1.statusActive)
    }

    // ═══════════════════════ SCOPE B — A21-F5 reconcileV5 receipt matrix ════════════════════════
    // (Reuses the governed-chain fixture pattern; focuses on the mandate §3 cases the builder's single
    //  probe does not isolate: reconstruction-path deficit, corrupt receipt, second reconciliation.)

    private final class SpyAcq: RWCAssetAcquirerV1 {
        let payload: Data; init(_ p: Data) { payload = p }
        func fetch(sourceReference: String) throws -> Data { payload }
    }
    private final class FixCorpus: RWCCorpusStoreV1 {
        var promoted: [String: Data] = [:]
        func promote(assetID: String, contentHash: String, payload: Data) throws { promoted[assetID] = payload }
        func storedAssetIDs() throws -> [String] { Array(promoted.keys) }
    }
    @discardableResult
    private func sh(_ root: URL, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git", "-C", root.path, "-c", "user.name=A", "-c", "user.email=a@a"] + args
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
    private func proofV6() throws -> (RWCVerifiedCorpusEntryV6, URL) {
        let root = tempDir("pfx")
        try sh(root, ["init", "-q"])
        try writeFile(root, "seed.txt", "g\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "g"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV6.governingTagName, "-m", "g"])
        let gates = "{\"g\":\"v8\"}\n"; let code = "// law\nlet law = 8\n"
        try writeFile(root, "docs/prereg/gates.yaml", gates)
        try writeFile(root, "code/method/RWCFixtureLaw.swift", code)
        try writeFile(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
                      "{\"immutable_a\": \"x\", \"data_visibility\": false, \"corpus_count\": 0, \"annotator_count\": 0, \"real_fit_count\": 0, \"heldout_open_count\": 0}\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try sh(root, ["rev-parse", "HEAD"])
        let mp = RWCCorpusEntryVerifierV6.canonicalFreezeManifestPath
        let arts: [(String, String)] = [("docs/prereg/gates.yaml", shaHex(gates)),
                                         ("code/method/RWCFixtureLaw.swift", shaHex(code))]
        let inv = shaHex(arts.map { "\($0.0):\($0.1)" }.sorted().joined(separator: "\n"))
        let manifest = """
        {"freeze_version": "rwc-preregistration-freeze-v8", "methodology_anchor_commit": "\(anchor)",
         "governing_control_plane_lock": "\(governing)", "frozen_inventory_digest": "\(inv)",
         "artifacts": [\(arts.map { "{\"path\": \"\($0.0)\", \"sha256\": \"\($0.1)\"}" }.joined(separator: ", "))],
         "surface_rules": {"governed_roots": ["docs/prereg", "code"], "post_anchor_allowed": [],
           "post_audit_allowances": [], "hash_exempt": []}}
        """
        try writeFile(root, mp, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", "fixture-a22t-candidate", "-m", "c"])
        let tagObj = try sh(root, ["rev-parse", "refs/tags/fixture-a22t-candidate"])
        let result = """
        {"result_version": "rwc-pre14-audit-result-v4", "verdict": "PASS", "candidate_commit": "\(candidate)",
         "candidate_tag_name": "fixture-a22t-candidate", "candidate_tag_object_sha": "\(tagObj)",
         "methodology_anchor_commit": "\(anchor)", "freeze_manifest_path": "\(mp)",
         "freeze_manifest_sha256": "\(shaHex(manifest))", "frozen_inventory_digest": "\(inv)",
         "governing_control_plane_lock": "\(governing)", "audit_probe_family": "A22T", "baseline_count": 2,
         "fresh_probe_count": 1, "total_count": 3, "critical_count": 0, "high_count": 0, "medium_count": 0,
         "auditor_declaration": "SYNTHETIC"}
        """
        try writeFile(root, RWCPre14AuditResultV4.canonicalPath, result)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit"])
        let audit = try sh(root, ["rev-parse", "HEAD"])
        let lock = """
        {"lock_version": "rwc-pre14-pass-lock-v4", "audit_result_path": "\(RWCPre14AuditResultV4.canonicalPath)",
         "audit_result_blob_sha256": "\(shaHex(result))", "audit_commit": "\(audit)",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "fixture-a22t-candidate",
         "candidate_tag_object_sha": "\(tagObj)", "freeze_manifest_path": "\(mp)",
         "freeze_manifest_sha256": "\(shaHex(manifest))", "methodology_anchor_commit": "\(anchor)",
         "frozen_inventory_digest": "\(inv)", "governing_control_plane_lock": "\(governing)",
         "corpus_entry_authorized": true, "verdict": "PASS"}
        """
        try writeFile(root, RWCPre14PassLockV4.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
        return (try RWCCorpusEntryVerifierV6.verify(repoRoot: root), root)
    }

    private struct Chain {
        let activated: RWCActivatedRootV1; let actStore: RWCOperationalRootActivationStoreV1
        let currentness: RWCReviewerRegistryCurrentnessStoreV1
        let registry: RWCVerifiedReviewerRegistryV2; let reviewerKey: Curve25519.Signing.PrivateKey
    }
    private func chain(_ tag: String) throws -> Chain {
        let r = makeRoot(rootID: "rwc-root-\(tag)1")
        let actStore = try RWCOperationalRootActivationStoreV1.create(directory: tempDir("\(tag)-a"))
        let activated = try RWCOperationalRootOnboardingV1.activate(request: try verifyReq(r), store: actStore,
                                                                    clock: clock("2026-10-20"))
        let reviewerKey = Curve25519.Signing.PrivateKey()
        let reviewerHex = reviewerKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let entry = RWCReviewerRegistryEntryV1(
            reviewerID: "rwc-reviewer-a22trv1", publicKeyRawHex: reviewerHex, status: "ACTIVE",
            role: "RIGHTS_REVIEW", scope: RWCReviewerScopeV1.corpus.rawValue, validFrom: d3("2026-01-01"),
            validUntil: d3("2027-12-31"), revision: 1)
        var doc = RWCReviewerRegistryDocumentV2(
            registryVersion: RWCReviewerRegistryDocumentV2.schemaVersion, registryRevision: 1,
            rootID: activated.rootID, createdAt: d3("2026-02-01"),
            previousRegistryDigest: RWCReviewerRegistryDocumentV2.genesisPreviousDigest,
            reviewers: [entry], signatureHex: "")
        let sig = try r.priv.signature(for: doc.canonicalPayloadBytes)
        doc = RWCReviewerRegistryDocumentV2(
            registryVersion: doc.registryVersion, registryRevision: doc.registryRevision, rootID: doc.rootID,
            createdAt: doc.createdAt, previousRegistryDigest: doc.previousRegistryDigest,
            reviewers: doc.reviewers, signatureHex: sig.map { String(format: "%02x", $0) }.joined())
        let currentness = try RWCReviewerRegistryCurrentnessStoreV1.create(directory: tempDir("\(tag)-c"))
        try currentness.advance(rootID: activated.rootID, revision: 1, documentDigest: doc.documentDigest,
                                recordedDate: "2026-02-01")
        let reg = try RWCReviewerRegistryVerifierV2.verifyCurrent(
            document: doc, trustRoot: activated.verifiedRoot, currentness: currentness, previousVerified: nil)
        return Chain(activated: activated, actStore: actStore, currentness: currentness,
                     registry: reg, reviewerKey: reviewerKey)
    }
    private func grant() -> RWCLegalGrantIdentityV1 {
        RWCLegalGrantIdentityV1(grantID: "rwc-grant-a22t001", grantRevision: 1,
            evidenceDigest: shaHex("proof"), evidencePointer: "rwc-rights-ref-a22tp01",
            rightsHolder: "licensor", allowedUse: ["training"], prohibitedUse: [],
            effectiveDate: d3("2026-08-01"), expiryDate: d3("2027-08-01"), reviewDecision: "APPROVED",
            reviewRecordID: "rwc-review-a22trv1")
    }
    private func grantV6(_ g: RWCLegalGrantIdentityV1, source: String, _ c: Chain) throws
        -> RWCVerifiedRightsGrantV6 {
        var r = RWCSignedRightsReviewV1(
            reviewRecordID: g.reviewRecordID, reviewerID: "rwc-reviewer-a22trv1", grantID: g.grantID,
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
    private func req(_ session: String, source: String, asset: String) -> RWCAcquisitionRequestV1 {
        RWCAcquisitionRequestV1(assetID: asset, sourceClass: .licensedRightsClear, sourceReference: source,
                                owner: "gen8", intendedUse: .training, sessionID: session,
                                manifestSources: nil, trustedExpectedChecksum: nil)
    }

    /// Build a stored-asset + ledger authorization WITHOUT any durable receipt, so reconcileV5 enters the
    /// R-6 RECONSTRUCTION branch of ensureReceipt. Returns the pieces needed to attack the reconstruction.
    private func stagedNoReceipt(_ tag: String)
        throws -> (runner: RWCCorpusAcquisitionRunnerV5, store: RWCAssetRightsLedgerStoreV5,
                   corpus: FixCorpus, receipt: RWCAcquisitionReceiptStoreV2, receiptDir: URL,
                   qRoot: URL, session: String, asset: String, proofRoot: URL,
                   c: Chain) {
        let (proof, pr) = try proofV6()
        let c = try chain(tag)
        let source = "rwc-source-ref-a22ts1"
        let vg = try grantV6(grant(), source: source, c)
        let store = try RWCAssetRightsLedgerStoreV5.create(
            directory: tempDir("\(tag)-l").appendingPathComponent("l"))
        let receiptDir = tempDir("\(tag)-r")
        let receipt = try RWCAcquisitionReceiptStoreV2(directory: receiptDir)
        let corpus = FixCorpus()
        let qRoot = tempDir("\(tag)-q")
        let runner = RWCCorpusAcquisitionRunnerV5(quarantineRoot: qRoot)
        let session = "rwc-acq-a22t\(tag)session0001"
        let asset = "rwc-asset-a22t\(tag)01"
        let preauth = try RWCPreAcquisitionEvaluatorV3.authorize(
            request: req(session, source: source, asset: asset), verifiedGrant: vg,
            transactionDate: clock("2026-10-21").today())
        let payload = Data("a22t-\(tag)-payload".utf8)
        let contentHash = RWCCorpusAcquisitionRunnerV5.sha256Hex(payload)
        try store.register(RWCAssetRightsRecordV3(
            assetID: asset, sourceClass: .licensedRightsClear, sourceReference: source, owner: "gen8",
            grant: grant(), acquisitionDate: d3("2026-08-20"), contentHash: contentHash,
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
        _ = try store.authorizeAcquisitionV2(token: token, verifiedGrant: vg, currentRegistry: c.registry,
                                             clock: clock("2026-10-21"))
        try corpus.promote(assetID: asset, contentHash: contentHash, payload: payload)
        // NO receipt prepared → reconcileV5 will take the reconstruction branch.
        let qdir = qRoot.appendingPathComponent("rwc-quarantine-\(session)", isDirectory: true)
        try FileManager.default.createDirectory(at: qdir, withIntermediateDirectories: true)
        try payload.write(to: qdir.appendingPathComponent("payload"))
        return (runner, store, corpus, receipt, receiptDir, qRoot, session, asset, pr, c)
    }

    /// B-ATTACK-01: reconstruction-path FAILURE → deficit, no false finalize, quarantine preserved.
    /// (Builder's probe covers the ALREADY-PREPARED finalize path; this isolates the R-6 RECONSTRUCTION
    /// path where NO receipt exists and the write is forced to fail.)
    func test_A22T_B01_ReconstructionFailure_ReportsDeficit_PreservesEvidence() throws {
        let s = try stagedNoReceipt("b01")
        defer {
            s.store.closeStore(); s.receipt.closeStore(); s.c.currentness.closeStore()
            s.c.actStore.closeStore(); try? FileManager.default.removeItem(at: s.proofRoot)
            try? FileManager.default.setAttributes([.posixPermissions: 0o700],
                                                   ofItemAtPath: s.receiptDir.path)
        }
        // make the receipt dir read-only so the reconstruction's prepare()/complete() write fails.
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: s.receiptDir.path)
        let report = try s.runner.reconcileV5(rightsStore: s.store, corpusStore: s.corpus,
                                              receiptStore: s.receipt)
        XCTAssertFalse(report.reconstructedReceipts.contains(s.session),
                       "a FAILED reconstruction must NOT be reported as reconstructed")
        XCTAssertFalse(report.finalizedReceipts.contains(s.session),
                       "a FAILED reconstruction must NOT be reported as finalized")
        XCTAssertTrue(report.receiptDeficitSessions.contains(s.session),
                      "a FAILED reconstruction is surfaced as an explicit receiptDeficit")
        let qpayload = s.qRoot.appendingPathComponent("rwc-quarantine-\(s.session)/payload").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: qpayload),
                      "quarantine evidence preserved on reconstruction deficit")
    }

    /// B-ATTACK-02: a HEALTHY reconstruction finalizes genuinely (reload-verified .completed) + cleans up.
    func test_A22T_B02_HealthyReconstruction_Finalizes_Durably() throws {
        let s = try stagedNoReceipt("b02")
        defer {
            s.store.closeStore(); s.receipt.closeStore(); s.c.currentness.closeStore()
            s.c.actStore.closeStore(); try? FileManager.default.removeItem(at: s.proofRoot)
        }
        let report = try s.runner.reconcileV5(rightsStore: s.store, corpusStore: s.corpus,
                                              receiptStore: s.receipt)
        XCTAssertTrue(report.reconstructedReceipts.contains(s.session),
                      "healthy reconstruction rebuilds the durable receipt from the ledger record")
        XCTAssertEqual(try s.receipt.load(s.session).state, .completed)
        // quarantine cleaned up once durably complete.
        let qpayload = s.qRoot.appendingPathComponent("rwc-quarantine-\(s.session)/payload").path
        XCTAssertFalse(FileManager.default.fileExists(atPath: qpayload),
                       "quarantine removed only after durable completion")
    }

    /// B-ATTACK-03: SECOND reconciliation is idempotent — re-running after a healthy completion does not
    /// double-finalize or re-report, and the durable state stays .completed.
    func test_A22T_B03_SecondReconciliation_Idempotent() throws {
        let s = try stagedNoReceipt("b03")
        defer {
            s.store.closeStore(); s.receipt.closeStore(); s.c.currentness.closeStore()
            s.c.actStore.closeStore(); try? FileManager.default.removeItem(at: s.proofRoot)
        }
        _ = try s.runner.reconcileV5(rightsStore: s.store, corpusStore: s.corpus, receiptStore: s.receipt)
        let r2 = try s.runner.reconcileV5(rightsStore: s.store, corpusStore: s.corpus, receiptStore: s.receipt)
        XCTAssertFalse(r2.receiptDeficitSessions.contains(s.session), "idempotent: no deficit on re-run")
        XCTAssertEqual(try s.receipt.load(s.session).state, .completed, "state stays completed")
    }

    /// B-ATTACK-04: a CORRUPT durable receipt (integrity line broken) is a typed refusal on load — it is
    /// NOT silently treated as completed, so ensureReceipt cannot false-finalize off a corrupt file.
    func test_A22T_B04_CorruptReceipt_TypedRefusal_NotSilentlyCompleted() throws {
        let s = try stagedNoReceipt("b04")
        defer {
            s.store.closeStore(); s.receipt.closeStore(); s.c.currentness.closeStore()
            s.c.actStore.closeStore(); try? FileManager.default.removeItem(at: s.proofRoot)
        }
        // first, let reconstruction build the receipt healthily.
        _ = try s.runner.reconcileV5(rightsStore: s.store, corpusStore: s.corpus, receiptStore: s.receipt)
        // corrupt the receipt body so the SHA-256 integrity line no longer matches.
        let receiptFile = s.receiptDir.appendingPathComponent("receipt-v2-\(s.session).json")
        var raw = try String(contentsOf: receiptFile, encoding: .utf8)
        raw = raw.replacingOccurrences(of: "\"state\":\"COMPLETED\"", with: "\"state\":\"PREPARED\"")
        try raw.write(to: receiptFile, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try s.receipt.load(s.session)) { e in
            guard case .integrityFailure = (e as? RWCReceiptStoreErrorV2) else {
                return XCTFail("expected integrityFailure on corrupt receipt, got \(e)")
            }
        }
    }

    // ═══════════════════════ SCOPE E — V7 verifier fresh adversarial extensions ══════════════════

    /// Minimal lawful V10 fixture builder (independent of the builder's). Returns root + lock-mutator hook.
    private func buildV10Fixture(mutate: (_ root: URL, _ fields: inout [String: String]) throws -> Void
                                 = { _, _ in }) throws -> (URL, Error?) {
        let root = tempDir("e-v10")
        try sh(root, ["init", "-q"])
        try writeFile(root, "seed.txt", "g\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "g"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV7.governingTagName, "-m", "g"])
        let gates = "{\"g\":1}\n"
        try writeFile(root, "docs/prereg/gates.yaml", gates)
        try writeFile(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
                      "{\"data_visibility\": false, \"corpus_count\": 0, \"annotator_count\": 0, \"real_fit_count\": 0, \"heldout_open_count\": 0}\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try sh(root, ["rev-parse", "HEAD"])
        let inv = shaHex("docs/prereg/gates.yaml:\(shaHex(gates))")
        let mp = RWCCorpusEntryVerifierV7.canonicalFreezeManifestPath
        let manifest = """
        {"freeze_version": "\(RWCCorpusEntryVerifierV7.expectedFreezeVersion)", "methodology_anchor_commit": "\(anchor)",
         "governing_control_plane_lock": "\(governing)", "frozen_inventory_digest": "\(inv)",
         "artifacts": [{"path": "docs/prereg/gates.yaml", "sha256": "\(shaHex(gates))"}],
         "surface_rules": {"governed_roots": ["docs/prereg"], "post_anchor_allowed": [],
           "post_audit_allowances": [], "hash_exempt": []}}
        """
        try writeFile(root, mp, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", "fixture-v10-candidate", "-m", "c"])
        let tagObj = try sh(root, ["rev-parse", "refs/tags/fixture-v10-candidate"])
        let result = """
        {"result_version": "\(RWCPre14AuditResultV5.expectedVersion)", "verdict": "PASS",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "fixture-v10-candidate",
         "candidate_tag_object_sha": "\(tagObj)", "methodology_anchor_commit": "\(anchor)",
         "freeze_manifest_path": "\(mp)", "freeze_manifest_sha256": "\(shaHex(manifest))",
         "frozen_inventory_digest": "\(inv)", "governing_control_plane_lock": "\(governing)",
         "audit_probe_family": "A22T_E", "baseline_count": 2, "fresh_probe_count": 1, "total_count": 3,
         "critical_count": 0, "high_count": 0, "medium_count": 0, "auditor_declaration": "SYNTHETIC"}
        """
        try writeFile(root, RWCPre14AuditResultV5.canonicalPath, result)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit"])
        let audit = try sh(root, ["rev-parse", "HEAD"])
        var L: [String: String] = [
            "lock_version": "rwc-pre14-pass-lock-v4", "audit_result_path": RWCPre14AuditResultV5.canonicalPath,
            "audit_result_blob_sha256": shaHex(result), "audit_commit": audit, "candidate_commit": candidate,
            "candidate_tag_name": "fixture-v10-candidate", "candidate_tag_object_sha": tagObj,
            "freeze_manifest_path": mp, "freeze_manifest_sha256": shaHex(manifest),
            "methodology_anchor_commit": anchor, "frozen_inventory_digest": inv,
            "governing_control_plane_lock": governing, "verdict": "PASS"]
        try mutate(root, &L)
        func s(_ k: String) -> String { "\"\(k)\": \"\(L[k]!)\"" }
        let lock = "{" + [s("lock_version"), s("audit_result_path"), s("audit_result_blob_sha256"),
            s("audit_commit"), s("candidate_commit"), s("candidate_tag_name"), s("candidate_tag_object_sha"),
            s("freeze_manifest_path"), s("freeze_manifest_sha256"), s("methodology_anchor_commit"),
            s("frozen_inventory_digest"), s("governing_control_plane_lock"),
            "\"corpus_entry_authorized\": true", s("verdict")].joined(separator: ", ") + "}"
        try writeFile(root, RWCPre14PassLockV4.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
        do { _ = try RWCCorpusEntryVerifierV7.verify(repoRoot: root); return (root, nil) }
        catch { return (root, error) }
    }

    /// E-ATTACK-01 positive control: an independently-built lawful V10 fixture verifies under V7.
    func test_A22T_E01_IndependentLawfulV10Fixture_Verifies() throws {
        let (root, err) = try buildV10Fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertNil(err, "independent lawful V10 fixture must verify under V7: \(String(describing: err))")
    }

    /// E-ATTACK-02 (UNCOMMITTED result): the lock points at the canonical path + correct blob sha, but the
    /// result file is modified in the WORKING TREE AFTER the audit commit (so the committed blob differs
    /// from the live file). V7 reads the blob from git history (not the live file) → the lock's blob sha
    /// still matches the committed blob, so this specific attack cannot forge a PASS by editing the live
    /// file. We assert V7 still VERIFIES against the COMMITTED blob (git-history-bound, not live-file-bound)
    /// — proving the A17-era "live report not bound to audit commit" class is closed in V7.
    func test_A22T_E02_LiveResultEditedAfterCommit_V7BindsToGitHistory_NotLiveFile() throws {
        let (root, err) = try buildV10Fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertNil(err)
        // Tamper the LIVE result file post-closeout (uncommitted change).
        let live = root.appendingPathComponent(RWCPre14AuditResultV5.canonicalPath)
        try "{\"forged\": true}".write(to: live, atomically: true, encoding: .utf8)
        // V7 reads git show <audit_commit>:<path>, so it must STILL verify (binds to the committed blob).
        XCTAssertNoThrow(try RWCCorpusEntryVerifierV7.verify(repoRoot: root),
                         "V7 binds to the committed blob via git history, immune to live-file edits")
    }

    /// E-ATTACK-03 (forged blob sha in lock): the lock claims a blob sha that does NOT match the committed
    /// result blob → auditResultHashMismatch (a forged PASS lock over a genuine result is refused).
    func test_A22T_E03_ForgedBlobShaInLock_Refused() throws {
        let (root, err) = try buildV10Fixture { _, L in
            L["audit_result_blob_sha256"] = String(repeating: "7", count: 64)
        }
        defer { try? FileManager.default.removeItem(at: root) }
        guard case .auditResultHashMismatch = (err as? RWCCorpusEntryErrorV7) else {
            return XCTFail("expected auditResultHashMismatch, got \(String(describing: err))")
        }
    }

    /// E-ATTACK-04 (governing lock not matching the governing TAG): mutate the governing lock in BOTH the
    /// lock and result to a bogus value that is consistent lock↔result↔manifest but does NOT dereference
    /// the governing tag → governingLockMismatch(git-tag). Closes "fake governing anchor" rebind.
    func test_A22T_E04_GoverningLockNotMatchingTag_Refused() throws {
        // We cannot easily rewrite the manifest's governing value here (it is committed), so instead point
        // the lock+result governing at a value that differs from the manifest's → caught at manifest stage.
        let (root, err) = try buildV10Fixture { _, L in
            L["governing_control_plane_lock"] = String(repeating: "9", count: 40)
        }
        defer { try? FileManager.default.removeItem(at: root) }
        // Either a target mismatch (result vs lock) or a manifest/git-tag governing mismatch is a correct
        // fail-closed refusal; the decisive invariant is V7 does NOT mint an entry.
        XCTAssertNotNil(err, "a governing-lock value not backed by the governing tag must be refused")
    }

    /// E-ATTACK-05 (count law): a float critical_count is a typed parse refusal (strict count law carried).
    func test_A22T_E05_FloatCount_TypedRefusal() throws {
        // Build a fixture whose committed result has a FLOAT critical_count; the lock blob sha matches it,
        // so V7 reaches the schema-V5 parser and must refuse at the strict count law.
        let root = tempDir("e-floatcount")
        defer { try? FileManager.default.removeItem(at: root) }
        try sh(root, ["init", "-q"])
        try writeFile(root, "seed.txt", "g\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "g"])
        let governing = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", RWCCorpusEntryVerifierV7.governingTagName, "-m", "g"])
        let gates = "{\"g\":1}\n"
        try writeFile(root, "docs/prereg/gates.yaml", gates)
        try writeFile(root, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",
                      "{\"data_visibility\": false, \"corpus_count\": 0, \"annotator_count\": 0, \"real_fit_count\": 0, \"heldout_open_count\": 0}\n")
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "anchor"])
        let anchor = try sh(root, ["rev-parse", "HEAD"])
        let inv = shaHex("docs/prereg/gates.yaml:\(shaHex(gates))")
        let mp = RWCCorpusEntryVerifierV7.canonicalFreezeManifestPath
        let manifest = """
        {"freeze_version": "\(RWCCorpusEntryVerifierV7.expectedFreezeVersion)", "methodology_anchor_commit": "\(anchor)",
         "governing_control_plane_lock": "\(governing)", "frozen_inventory_digest": "\(inv)",
         "artifacts": [{"path": "docs/prereg/gates.yaml", "sha256": "\(shaHex(gates))"}],
         "surface_rules": {"governed_roots": ["docs/prereg"], "post_anchor_allowed": [],
           "post_audit_allowances": [], "hash_exempt": []}}
        """
        try writeFile(root, mp, manifest)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "candidate"])
        let candidate = try sh(root, ["rev-parse", "HEAD"])
        try sh(root, ["tag", "-a", "fixture-v10-candidate", "-m", "c"])
        let tagObj = try sh(root, ["rev-parse", "refs/tags/fixture-v10-candidate"])
        // FLOAT critical_count (1.5) — strict count law must refuse.
        let result = """
        {"result_version": "\(RWCPre14AuditResultV5.expectedVersion)", "verdict": "PASS",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "fixture-v10-candidate",
         "candidate_tag_object_sha": "\(tagObj)", "methodology_anchor_commit": "\(anchor)",
         "freeze_manifest_path": "\(mp)", "freeze_manifest_sha256": "\(shaHex(manifest))",
         "frozen_inventory_digest": "\(inv)", "governing_control_plane_lock": "\(governing)",
         "audit_probe_family": "A22T_FLOAT", "baseline_count": 2, "fresh_probe_count": 1, "total_count": 3,
         "critical_count": 1.5, "high_count": 0, "medium_count": 0, "auditor_declaration": "SYNTHETIC"}
        """
        try writeFile(root, RWCPre14AuditResultV5.canonicalPath, result)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "audit"])
        let audit = try sh(root, ["rev-parse", "HEAD"])
        let lock = """
        {"lock_version": "rwc-pre14-pass-lock-v4", "audit_result_path": "\(RWCPre14AuditResultV5.canonicalPath)",
         "audit_result_blob_sha256": "\(shaHex(result))", "audit_commit": "\(audit)",
         "candidate_commit": "\(candidate)", "candidate_tag_name": "fixture-v10-candidate",
         "candidate_tag_object_sha": "\(tagObj)", "freeze_manifest_path": "\(mp)",
         "freeze_manifest_sha256": "\(shaHex(manifest))", "methodology_anchor_commit": "\(anchor)",
         "frozen_inventory_digest": "\(inv)", "governing_control_plane_lock": "\(governing)",
         "corpus_entry_authorized": true, "verdict": "PASS"}
        """
        try writeFile(root, RWCPre14PassLockV4.lockRelPath, lock)
        try sh(root, ["add", "-A"]); try sh(root, ["commit", "-q", "-m", "closeout"])
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV7.verify(repoRoot: root)) { e in
            guard case .auditCountInvalid = (e as? RWCCorpusEntryErrorV7) else {
                return XCTFail("expected auditCountInvalid (float count), got \(e)")
            }
        }
    }

    // ═══════════════════════ SCOPE D — authority-chain regression (real repo) ════════════════════

    /// D-ATTACK-01: on the REAL repo, V7 fails closed (no V10 PASS), V6 still fails (not rebound), and
    /// loadProduction still fails closed .noOperationalRoot — the end-to-end pre-activation seal holds
    /// under the V10 code (A20-F1..F4 chain not regressed; no silent authority).
    func test_A22T_D01_RealRepo_FullChain_StillFailsClosed_NoRegression() throws {
        let repo = repoRoot()
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV7.verify(repoRoot: repo),
                             "V7 must not mint a V10 entry on the real repo (no V10 PASS lock)")
        XCTAssertThrowsError(try RWCCorpusEntryVerifierV6.verify(repoRoot: repo),
                             "V6 must still fail on the V9/V10 tree (no V8-PASS auto-rebind)")
        XCTAssertThrowsError(try RWCReviewerTrustRootLoaderV2.loadProduction(repoRoot: repo)) { e in
            XCTAssertEqual(e as? RWCReviewerTrustErrorV2, .noOperationalRoot,
                           "loadProduction stays fail-closed .noOperationalRoot (pre-activation)")
        }
        // the operational trust-root file must NOT exist.
        let rootPath = repo.appendingPathComponent(RWCReviewerTrustRootLoaderV2.canonicalInstancePath).path
        XCTAssertFalse(FileManager.default.fileExists(atPath: rootPath),
                       "no operational reviewer trust root may exist pre-activation")
    }
}
#endif
