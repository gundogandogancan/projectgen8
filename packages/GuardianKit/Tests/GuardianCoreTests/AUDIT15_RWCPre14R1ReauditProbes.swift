import XCTest
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT15_RWC_PRE14_R1_REAUDIT — independent clean-session re-audit probe family (ADD-ONLY).
// Auditor: independent (non-builder) session, candidate 931f38e05b7167e038dd41237aa46fa865875f6b,
// tag gen8-rwc-preregistration-r1-audit-candidate (object 6bde7d4ad845064a3974e6c9f4f8e02bd7217863).
//
// LAW OF THIS FILE: every probe asserts a FACT the auditor verified. Where a probe documents a
// DEFECT, it PINS the defective behavior (comment "AUDIT15 FINDING <id>") so the suite stays green
// while the finding is recorded in docs/audit/GEN8_RWC_PREREGISTRATION_PRE14_R1_INDEPENDENT_REAUDIT.md.
// Statistical heavy lifting (Type-I, power, seed instability, debiased-gap truth, IRR power,
// PYTHONHASHSEED differential) lives in docs/audit/audit15_tools/*.py — results in the report.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT15_RWCPre14R1ReauditProbes: XCTestCase {

    private var repoRoot: String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }
    private func text(_ rel: String) throws -> String {
        try String(contentsOfFile: repoRoot + "/" + rel, encoding: .utf8)
    }
    private func json(_ rel: String) throws -> [String: Any] {
        let d = try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + rel))
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: d) as? [String: Any])
    }
    private func sha256(_ rel: String) throws -> String {
        let d = try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + rel))
        return SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }
    private func record(assetID: String = "rwc-asset-a15probe1",
                        evidence: String = "rwc-rights-ref-a15-0001",
                        acquisition: String = "2026-10-01", expiry: String? = nil,
                        revocationDate: String? = nil,
                        allowedUse: [String] = ["training", "evaluation"],
                        prohibitedUse: [String] = ["redistribution"],
                        training: Bool = true, evaluation: Bool = true,
                        owner: String = "gen8-project",
                        contentHash: String = String(repeating: "ab", count: 32)) -> RWCAssetRightsRecordV1 {
        RWCAssetRightsRecordV1(assetID: assetID, sourceClass: .licensedRightsClear,
                               sourceReference: "rwc-source-ref-a15-0001", owner: owner,
                               rightsHolder: "licensor-a15", licenseType: "lic", licenseEvidence: evidence,
                               allowedUse: allowedUse, prohibitedUse: prohibitedUse,
                               trainingAllowed: training, evaluationAllowed: evaluation,
                               derivativeRights: "d", redistributionAllowed: false, language: "tr",
                               contentType: "video", modality: "v", acquisitionDate: acquisition,
                               expiryDate: expiry, revocationState: .active, revocationDate: revocationDate,
                               contentHash: contentHash, provenanceChain: ["rwc-prov-a15"])
    }

    // ── §0/§2 — custody + discipline artifacts (git-level custody is recorded in the report) ──

    func testA15_Custody_FrozenOriginal_Erratum_InversionLock() throws {
        XCTAssertEqual(try sha256("docs/audit/AUDIT14_RWCPreregistrationPre14Probes_ORIGINAL_LOCKED.swift.txt"),
                       "18ac2633dd55e6073cf80be309db75af3f07c96a2bedd62cf8a360c246186886",
                       "AUDIT14 frozen original byte-exact")
        let erratum = try text("docs/audit/AUDIT14_FINDING_COUNT_ERRATUM.md")
        XCTAssertTrue(erratum.contains("NINE MEDIUM-labelled rows"))
        for f in ["A14-F1", "A14-F2", "A14-F4", "A14-F5", "A14-F7", "A14-F8", "A14-F9", "A14-F10", "A14-F13"] {
            XCTAssertTrue(erratum.contains(f), "erratum names \(f)")
        }
        // the immutable AUDIT14 report retains its FIX REQUIRED verdict; no artifact claims PRE14 PASS
        let a14 = try text("docs/audit/GEN8_RWC_PREREGISTRATION_PRE14_INDEPENDENT_AUDIT.md")
        XCTAssertTrue(a14.contains("FIX REQUIRED"), "AUDIT14 verdict preserved")
        let lock = try text("docs/audit/AUDIT14_R1_INVERSION_LOCK.md")
        for inv in ["I-1", "I-5", "I-9", "I-14", "I-16"] { XCTAssertTrue(lock.contains(inv)) }
        XCTAssertTrue(lock.contains("testA14_PINNED_F7_") && lock.contains("permanent negative evidence"),
                      "F7 Monte-Carlo negative evidence declared NOT inverted")
        // remediation report does not self-PASS
        let rem = try text("docs/calibration/preregistration/RWC_PREREGISTRATION_R1_REMEDIATION_REPORT.md")
        XCTAssertTrue(rem.contains("Builder cannot self-PASS"))
    }

    // ── §4 — A14-F1 real-calendar red team ──

    func testA15_F1_RealCalendarValidity_ImpossibleDatesAccepted_PINNED() throws {
        // Correctly refused shapes:
        for bad in ["2026-00-10", "2026-13-01", "2026-1-01", "2026-01-1", "not-a-date",
                    "2026-01-01\n", " 2026-01-01", "2026/01/01", "2026-01-32", "٢٠٢٦-٠١-٠١"] {
            XCTAssertFalse(RWCAssetRightsLedgerV1.isStrictISODate(bad), "must refuse: \(bad)")
        }
        XCTAssertTrue(RWCAssetRightsLedgerV1.isStrictISODate("0000-01-01"), "year 0000 accepted (documented)")
        XCTAssertTrue(RWCAssetRightsLedgerV1.isStrictISODate("9999-12-31"))
        // AUDIT15 FINDING A15-F1: pins defective behavior — IMPOSSIBLE Gregorian dates pass the
        // "strict" validator (month 1...12 / day 1...31 range check only; no real calendar validity).
        XCTAssertTrue(RWCAssetRightsLedgerV1.isStrictISODate("2026-02-31"), "Feb 31 accepted (defect)")
        XCTAssertTrue(RWCAssetRightsLedgerV1.isStrictISODate("2026-04-31"), "Apr 31 accepted (defect)")
        XCTAssertTrue(RWCAssetRightsLedgerV1.isStrictISODate("2026-02-29"), "2026 is NOT a leap year (defect)")
        // and the STORE registers a record whose acquisition date does not exist on any calendar:
        let store = RWCAssetRightsLedgerStoreV1()
        XCTAssertNoThrow(try store.register(record(acquisition: "2026-02-31"), asOf: "2026-10-20"),
                         "AUDIT15 FINDING A15-F1: impossible acquisitionDate registered")
        XCTAssertNoThrow(try store.requireEligible(assetID: "rwc-asset-a15probe1", use: .training,
                                                   asOf: "2026-02-31"),
                         "AUDIT15 FINDING A15-F1: impossible asOf accepted by canonical eligibility")
    }

    // ── §5 — expiry boundary laws ──

    func testA15_F1_ExpiryBoundary_ThroughLaw_TypedAsOf() throws {
        let store = RWCAssetRightsLedgerStoreV1()
        try store.register(record(expiry: "2027-06-30"), asOf: "2026-10-20")
        XCTAssertNoThrow(try store.requireEligible(assetID: "rwc-asset-a15probe1", use: .evaluation,
                                                   asOf: "2027-06-30"), "valid THROUGH expiry date")
        XCTAssertThrowsError(try store.requireEligible(assetID: "rwc-asset-a15probe1", use: .evaluation,
                                                       asOf: "2027-07-01")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .expired)
        }
        XCTAssertThrowsError(try store.requireEligible(assetID: "rwc-asset-a15probe1", use: .evaluation,
                                                       asOf: "2026-09-30")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .acquisitionInFuture, "asOf before acquisition refused")
        }
        XCTAssertThrowsError(try store.requireEligible(assetID: "rwc-asset-a15probe1", use: .evaluation,
                                                       asOf: "yesterday")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .malformedDate(field: "asOf"), "typed malformedDate")
        }
        // Registration of ALREADY-EXPIRED rights is ACCEPTED (no expiry-vs-asOf check at register);
        // eligibility correctly refuses for asOf>expiry, but a PAST asOf re-opens the window
        // (asOf is caller-injectable by design — documented as A15-F19 in the report).
        let store2 = RWCAssetRightsLedgerStoreV1()
        XCTAssertNoThrow(try store2.register(record(acquisition: "2026-01-01", expiry: "2026-06-30"),
                                             asOf: "2026-10-20"), "already-expired registration accepted")
        XCTAssertThrowsError(try store2.requireEligible(assetID: "rwc-asset-a15probe1", use: .training,
                                                        asOf: "2026-10-20")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .expired)
        }
        XCTAssertNoThrow(try store2.requireEligible(assetID: "rwc-asset-a15probe1", use: .training,
                                                    asOf: "2026-06-30"),
                         "time-travel query with past asOf is eligible (injectable-asOf semantics)")
    }

    // ── §6 — revocation / reauthorization chronology ──

    func testA15_F1F4_EventChronology_TemporalNonsenseAccepted_PINNED() throws {
        let store = RWCAssetRightsLedgerStoreV1()
        try store.register(record(acquisition: "2026-10-01"), asOf: "2026-10-20")
        // AUDIT15 FINDING A15-F2: pins defective behavior — the store accepts a revocation dated
        // BEFORE acquisition and BEFORE the registration event (impossible chronology in the event log).
        XCTAssertNoThrow(try store.revoke(assetID: "rwc-asset-a15probe1", onDate: "2020-01-01"))
        XCTAssertEqual(store.events.map(\.kind), ["registered", "revoked"])
        XCTAssertEqual(store.events[1].date, "2020-01-01", "revocation event predates registration event date")
        // reauthorize with an event date BEFORE the revocation is also accepted:
        let relicensed = record(evidence: "rwc-rights-ref-a15-0002", acquisition: "2019-01-01")
        XCTAssertNoThrow(try store.reauthorize(relicensed, asOf: "2019-06-01"),
                         "AUDIT15 FINDING A15-F2: reauthorization dated before the revocation accepted")
        // and a MALFORMED asOf in reauthorize surfaces as the MISLEADING type .acquisitionInFuture:
        try store.revoke(assetID: "rwc-asset-a15probe1", onDate: "2026-10-20")
        let relicensed2 = record(evidence: "rwc-rights-ref-a15-0003", acquisition: "2026-10-01")
        XCTAssertThrowsError(try store.reauthorize(relicensed2, asOf: "not-a-date")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .acquisitionInFuture,
                           "AUDIT15 FINDING A15-F2: malformed asOf mapped to acquisitionInFuture, not malformedDate")
        }
    }

    // ── §7 — A14-F2 use-authorization single truth, exhaustive matrix ──

    func testA15_F2_UseTruthMatrix_Exhaustive() throws {
        func rec(_ allowed: [String], _ prohibited: [String], t: Bool, e: Bool) -> RWCAssetRightsRecordV1 {
            record(allowedUse: allowed, prohibitedUse: prohibited, training: t, evaluation: e)
        }
        func violates(_ r: RWCAssetRightsRecordV1) -> Bool {
            do { try RWCAssetRightsLedgerV1.requireEligible(r, use: "evaluation"); return false }
            catch RWCRightsErrorV1.useConsistencyViolation { return true }
            catch { return false }
        }
        // consistent records pass:
        XCTAssertNoThrow(try RWCAssetRightsLedgerV1.requireEligible(
            rec(["training", "evaluation"], [], t: true, e: true), use: "evaluation"))
        XCTAssertNoThrow(try RWCAssetRightsLedgerV1.requireEligible(
            rec(["evaluation"], ["redistribution"], t: false, e: true), use: "evaluation"))
        // every contradiction is a typed useConsistencyViolation:
        XCTAssertTrue(violates(rec([], [], t: true, e: true)), "flag true, absent from allowedUse")
        XCTAssertTrue(violates(rec(["training", "evaluation"], ["training"], t: true, e: true)),
                      "granted AND prohibited")
        XCTAssertTrue(violates(rec(["training", "evaluation"], ["TRAINING"], t: true, e: true)),
                      "case-variant prohibition caught")
        XCTAssertTrue(violates(rec(["Training", "evaluation"], [], t: true, e: true)),
                      "case-variant allowed token = unknown token")
        XCTAssertTrue(violates(rec(["training", "evaluation", "mining"], [], t: true, e: true)),
                      "unknown allowed token")
        XCTAssertTrue(violates(rec(["training", "evaluation"], [], t: false, e: true)),
                      "allowedUse contains a use whose flag is false")
        XCTAssertTrue(violates(rec(["evaluation"], ["evaluation"], t: false, e: true)),
                      "same token allowed+prohibited")
        // duplicates inside allowedUse are TOLERATED (no typed refusal — documented, not a contradiction):
        XCTAssertNoThrow(try RWCAssetRightsLedgerV1.requireEligible(
            rec(["evaluation", "evaluation"], [], t: false, e: true), use: "evaluation"))
        // unknown use string on the query side never passes:
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(
            rec(["training", "evaluation"], [], t: true, e: true), use: "Training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .useNotAllowed(use: "Training"))
        }
    }

    // ── §8 — register() over-restriction: lawful TRAINING-ONLY asset cannot register ──

    func testA15_F2_TrainingOnlyAsset_RegistrationOverRestriction_PINNED() throws {
        let store = RWCAssetRightsLedgerStoreV1()
        let trainingOnly = record(allowedUse: ["training"], training: true, evaluation: false)
        XCTAssertNoThrow(try RWCAssetRightsLedgerV1.requireUseConsistency(trainingOnly),
                         "record is internally consistent (lawful training-only)")
        // AUDIT15 FINDING A15-F13 (safe-direction product limitation, pinned): register() hard-codes
        // use:"evaluation", so a lawful training-only asset is REFUSED registration entirely.
        XCTAssertThrowsError(try store.register(trainingOnly, asOf: "2026-10-20")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .useNotAllowed(use: "evaluation"))
        }
    }

    // ── §9 — A14-F4 resurrection & relicensing evidence identity ──

    func testA15_F4_Resurrection_OldEvidenceRefusedForever() throws {
        let store = RWCAssetRightsLedgerStoreV1()
        try store.register(record(), asOf: "2026-10-20")
        try store.revoke(assetID: "rwc-asset-a15probe1", onDate: "2026-10-21")
        XCTAssertThrowsError(try store.register(record(), asOf: "2026-10-22")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .resurrectionRefused)
        }
        XCTAssertThrowsError(try store.reauthorize(record(), asOf: "2026-10-22")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .reauthorizationRequiresNewEvidence)
        }
        // revoke is monotone: no API un-revokes; eligibility consults LEDGER state, not caller values
        XCTAssertThrowsError(try store.requireEligible(assetID: "rwc-asset-a15probe1", use: .training,
                                                       asOf: "2026-10-22")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .revoked)
        }
    }

    func testA15_F4_NewPointerSameUnderlyingEvidence_Passes_PINNED() throws {
        let store = RWCAssetRightsLedgerStoreV1()
        try store.register(record(evidence: "rwc-rights-ref-a15-0001"), asOf: "2026-10-20")
        try store.revoke(assetID: "rwc-asset-a15probe1", onDate: "2026-10-21")
        // AUDIT15 FINDING A15-F3: pins structural gap — "NEW evidence" is identified ONLY by the
        // opaque pointer STRING. A renamed pointer with every other field IDENTICAL (same contentHash,
        // same licensor, same license type — i.e. conceptually the SAME underlying proof) reauthorizes.
        // NEW POINTER != NEW EVIDENCE; no rightsEvidenceHash/version binds pointer to proof identity.
        let renamedPointerOnly = record(evidence: "rwc-rights-ref-a15-0001x")
        XCTAssertNoThrow(try store.reauthorize(renamedPointerOnly, asOf: "2026-10-22"))
        XCTAssertNoThrow(try store.requireEligible(assetID: "rwc-asset-a15probe1", use: .evaluation,
                                                   asOf: "2026-10-23"))
    }

    // ── §10 — append-only chain digest: Hasher-based, intra-process only ──

    func testA15_ChainDigest_HasherBased_IntraProcessOnly_PINNED() throws {
        func play(_ s: RWCAssetRightsLedgerStoreV1) throws {
            try s.register(record(), asOf: "2026-10-20")
            try s.revoke(assetID: "rwc-asset-a15probe1", onDate: "2026-10-21")
            try s.reauthorize(record(evidence: "rwc-rights-ref-a15-0002"), asOf: "2026-10-22")
        }
        let s1 = RWCAssetRightsLedgerStoreV1(), s2 = RWCAssetRightsLedgerStoreV1()
        try play(s1); try play(s2)
        XCTAssertEqual(s1.events.map(\.chainDigest), s2.events.map(\.chainDigest),
                       "same logical sequence reproduces digests WITHIN one process")
        XCTAssertEqual(s1.events.map(\.seq), [0, 1, 2], "append-only sequence numbers")
        // AUDIT15 FINDING A15-F4: pins the digest construction — 16 lowercase hex chars (UInt64 from
        // Swift Hasher), NOT a 64-char SHA-256. Swift Hasher is PROCESS-SEEDED by design, so this
        // chain digest does NOT reproduce across processes (cross-process differential executed by
        // the auditor outside XCTest; see report). Durable audit-chain and append-only semantics
        // are conflated: no durable cryptographic witness exists for rights provenance.
        for e in s1.events {
            XCTAssertEqual(e.chainDigest.count, 16, "Hasher-width digest, not SHA-256")
            XCTAssertTrue(e.chainDigest.allSatisfy { ("0"..."9").contains(String($0)) || ("a"..."f").contains(String($0)) })
        }
        print("AUDIT15_XPROC_DIGEST=\(s1.events.map(\.chainDigest).joined(separator: ","))")
    }

    // ── §11 — pointer / hash / provenance hygiene ──

    func testA15_F3_PointerHashProvenanceHygiene() throws {
        let store = RWCAssetRightsLedgerStoreV1()
        func reg(_ r: RWCAssetRightsRecordV1) -> RWCRightsErrorV1? {
            do { try store.register(r, asOf: "2026-10-20"); return nil }
            catch { return error as? RWCRightsErrorV1 }
        }
        XCTAssertEqual(reg(record(evidence: "https://example.com/license.pdf")),
                       .invalidEvidencePointer(field: "licenseEvidence"), "raw URL refused")
        XCTAssertEqual(reg(record(evidence: "/var/data/license.pdf")),
                       .invalidEvidencePointer(field: "licenseEvidence"), "file path refused")
        XCTAssertEqual(reg(record(evidence: "rwc-rights-ref-ABCD")),
                       .invalidEvidencePointer(field: "licenseEvidence"), "uppercase token refused")
        XCTAssertEqual(reg(record(evidence: "rwc-rights-ref-ab\ncd")),
                       .invalidEvidencePointer(field: "licenseEvidence"), "newline refused")
        XCTAssertEqual(reg(record(evidence: "rwc-rights-ref-ab")),
                       .invalidEvidencePointer(field: "licenseEvidence"), "under-length token refused")
        XCTAssertEqual(reg(record(evidence: "\n")), .missingLicenseEvidence, "newline-only evidence")
        XCTAssertEqual(reg(record(owner: "  \n")), .missingOwner)
        XCTAssertEqual(reg(record(contentHash: String(repeating: "AB", count: 32))), .invalidContentHash,
                       "uppercase hex refused (canonical lowercase law, never normalized)")
        XCTAssertEqual(reg(record(contentHash: String(repeating: "ab", count: 31) + "a")), .invalidContentHash,
                       "63 chars refused")
        XCTAssertEqual(reg(record(contentHash: String(repeating: "ab", count: 31) + "gz")), .invalidContentHash,
                       "non-hex refused")
        XCTAssertEqual(reg(record(contentHash: String(repeating: "ab", count: 31) + "ａb")), .invalidContentHash,
                       "fullwidth Unicode 'ａ' refused (no Unicode-lowercase alias)")
        var dup = record()
        dup = RWCAssetRightsRecordV1(assetID: dup.assetID, sourceClass: dup.sourceClass,
                                     sourceReference: dup.sourceReference, owner: dup.owner,
                                     rightsHolder: dup.rightsHolder, licenseType: dup.licenseType,
                                     licenseEvidence: dup.licenseEvidence, allowedUse: dup.allowedUse,
                                     prohibitedUse: dup.prohibitedUse, trainingAllowed: true,
                                     evaluationAllowed: true, derivativeRights: "d",
                                     redistributionAllowed: false, language: "tr", contentType: "v",
                                     modality: "v", acquisitionDate: "2026-10-01", expiryDate: nil,
                                     revocationState: .active, revocationDate: nil,
                                     contentHash: dup.contentHash,
                                     provenanceChain: ["rwc-prov-a15", "rwc-prov-a15"])
        XCTAssertEqual(reg(dup), .duplicateProvenance)
        // dashes-only pointer token is ACCEPTED by the grammar (documented hygiene gap A15-F18):
        XCTAssertNoThrow(try store.register(record(evidence: "rwc-rights-ref-----"), asOf: "2026-10-20"))
    }

    // ── §12 — A14-F5 PRE-02→PRE-04 grammar door ──

    func testA15_F5_Pre04Door_GarbageRefused_OrderIndependent() throws {
        let valid = ["rwc-asset-aaaa1111#p-aa", "rwc-asset-bbbb2222#p-bb"]
        let tok = try CalibrationRunPreparationV1.prepareDataset(declaredIDs: valid,
                                                                 resolvedIDs: valid.reversed())
        XCTAssertEqual(tok.count, 2, "valid composites, order-independent")
        func refusedAsGrammar(_ declared: [String], _ resolved: [String]) -> Bool {
            do { _ = try CalibrationRunPreparationV1.prepareDataset(declaredIDs: declared, resolvedIDs: resolved) }
            catch let e as CalibrationIntegrityErrorV1 {
                if case .invalidRWCCompositeIDs = e { return true }
                return false
            } catch { return false }
            return false
        }
        for garbage in ["RWC-ASSET-AAAA1111#p-aa",                 // uppercase
                        "rwc-asset-aaaa1111#p-aa#p-bb",            // multiple '#'
                        "rwc-asset-aaaa1111",                      // no '#'
                        "https://cdn.example/v.mp4#p-aa",          // URL
                        "rwc-asset-../../etc#p-aa",                // path traversal
                        "#p-aa",                                   // empty asset
                        "rwc-asset-aaaa1111#",                     // empty profile
                        "rwc-asset-aaaa1111#-p-aa",                // leading dash profile
                        "rwc-asset-ááaa1111#p-aa",                 // Unicode
                        "rwc-asset-aaaa1111 #p-aa",                // whitespace
                        "rwc-asset-aa11#p-aa"] {                   // under-length token
            XCTAssertTrue(refusedAsGrammar([garbage, valid[1]], [garbage, valid[1]]),
                          "grammar refusal before token mint: \(garbage)")
            XCTAssertTrue(refusedAsGrammar(valid, [valid[0], garbage]),
                          "resolved-only garbage refused: \(garbage)")
        }
        // same-count VALID substitution is an identity error, not a count match:
        XCTAssertThrowsError(try CalibrationRunPreparationV1.prepareDataset(
            declaredIDs: valid, resolvedIDs: [valid[0], "rwc-asset-cccc3333#p-cc"]))
        // duplicates refused:
        XCTAssertThrowsError(try CalibrationRunPreparationV1.prepareDataset(
            declaredIDs: [valid[0], valid[0]], resolvedIDs: [valid[0], valid[0]]))
    }

    // ── §13/§14 — F6 payload limitation carried; generic fit surfaces callable (engineering) ──

    func testA15_F6_TokenBindsIdentitiesOnly_InvariantRecorded() throws {
        let tok = try CalibrationRunPreparationV1.prepareDataset(
            declaredIDs: ["rwc-asset-aaaa1111#p-aa"], resolvedIDs: ["rwc-asset-aaaa1111#p-aa"])
        let fields = Mirror(reflecting: tok).children.compactMap(\.label).sorted()
        XCTAssertEqual(fields, ["category", "compositeIDs", "guardRevision"],
                       "token still binds IDs only — NO labels/features/rights/split/dataset-hash payload (A14-F6 CARRIED)")
        let m = try json("docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml")
        let inv = m["rwc_fit_binding_invariant"] as? String ?? ""
        XCTAssertTrue(inv.contains("PreparedCalibrationDatasetV2") && inv.contains("A14-F6"),
                      "binding RWC-FIT prerequisite recorded in master manifest")
        XCTAssertTrue(inv.contains("REAL-WORLD execution is prohibited"), "F6b carried honestly")
    }

    func testA15_GenericFitSurfaces_RemainCallable_EngineeringScoped() {
        // Candidate claims callable-but-prohibited, NOT structurally inaccessible. Verify callable:
        let dim = DimensionCalibratorV1.fit(name: "a15", slice: "engineering",
                                            xs: [0.1, 0.4, 0.6, 0.9], ys: [false, false, true, true])
        XCTAssertFalse(dim.name.isEmpty)
        let logit = LogisticCalibrator.fit([(raw: 0.2, label: false), (raw: 0.8, label: true)],
                                           iterations: 50, lr: 0.3)
        XCTAssertTrue(logit.calibrated(0.8) > logit.calibrated(0.2))
        let fusion = SuitabilityFusionModelV1.fit(features: [[0.1, 0.2], [0.8, 0.9]], targets: [0.0, 1.0])
        _ = fusion
        // and the PRE-14 gate flag that would authorize REAL-WORLD execution remains false:
        XCTAssertFalse(RealWorldCalibrationExecutorV1.preregistrationAuditPassed)
    }

    // ── §15/§18/§19 — independent ECE; invalid metric inputs; tie/order sensitivity ──

    /// Auditor's OWN equal-mass ECE (written from the frozen spec; used only for differential checks).
    private func a15ECE(_ preds: [Double], _ labels: [Bool], bins: Int = 10) -> Double {
        let n = preds.count
        guard n > 0, labels.count == n else { return .nan }
        let order = preds.indices.sorted { preds[$0] == preds[$1] ? $0 < $1 : preds[$0] < preds[$1] }
        var total = 0.0
        for b in 0..<bins {
            let lo = b * n / bins, hi = (b + 1) * n / bins
            guard hi > lo else { continue }
            var sp = 0.0, sy = 0.0
            for i in order[lo..<hi] { sp += preds[i]; sy += labels[i] ? 1 : 0 }
            let c = Double(hi - lo)
            total += c / Double(n) * abs(sp / c - sy / c)
        }
        return total
    }

    func testA15_IndependentECE_MatchesBuilder_OnTieFreeData() {
        // hand-computed tiny case: n=10, preds 0.05..0.95 step .1, labels alternate F/T…
        let p = (0..<10).map { 0.05 + 0.1 * Double($0) }
        let y = (0..<10).map { $0 % 2 == 1 }
        // each bin holds exactly 1 item: ece = mean(|p_i - y_i|) = hand value
        let hand = zip(p, y).map { abs($0 - ($1 ? 1.0 : 0.0)) }.reduce(0, +) / 10
        XCTAssertEqual(RWCCalibrationMethodologyV1.eceEqualMass(preds: p, labels: y), hand, accuracy: 1e-12)
        XCTAssertEqual(a15ECE(p, y), hand, accuracy: 1e-12)
        // differential on 40 random TIE-FREE datasets (distinct preds ⇒ order unambiguous):
        var rng = RWCSplitMix64(seed: 1_515_151)
        for _ in 0..<40 {
            let n = 10 + Int(rng.next() % 890)
            var preds = (0..<n).map { _ in rng.double01() }
            preds = Array(Set(preds)).sorted().shuffled()           // force distinctness
            let labels = preds.map { _ in rng.double01() < 0.5 }
            XCTAssertEqual(RWCCalibrationMethodologyV1.eceEqualMass(preds: preds, labels: labels),
                           a15ECE(preds, labels), accuracy: 1e-12)
        }
    }

    func testA15_InvalidMetricInputs_NoTypedRefusal_PINNED() {
        // AUDIT15 FINDING A15-F5: pins defective behavior — the frozen decision rule computes
        // "valid-looking" outcomes from INVALID probability inputs instead of refusing them.
        XCTAssertTrue(RWCCalibrationMethodologyV1.eceEqualMass(preds: [], labels: []).isNaN)
        XCTAssertTrue(RWCCalibrationMethodologyV1.eceEqualMass(preds: [0.5], labels: [true, false]).isNaN,
                      "shape mismatch -> NaN, not a typed refusal")
        // out-of-domain p > 1: decide() returns a CLEAN PASS (invalid input == valid metric — defect):
        let over = RWCCalibrationMethodologyV1.decide(preds: [Double](repeating: 1.1, count: 50),
                                                      labels: [Bool](repeating: true, count: 50), seed: 7)
        XCTAssertTrue(over.passed, "AUDIT15 FINDING A15-F5: p=1.1 inputs yield a PASS")
        // out-of-domain p < 0: same
        let under = RWCCalibrationMethodologyV1.decide(preds: [Double](repeating: -0.1, count: 50),
                                                       labels: [Bool](repeating: false, count: 50), seed: 7)
        XCTAssertTrue(under.passed, "AUDIT15 FINDING A15-F5: p=-0.1 inputs yield a PASS")
        // NaN prediction: silently FAILS (accidentally fail-closed, still not typed):
        let nan = RWCCalibrationMethodologyV1.decide(preds: [Double.nan, 0.5, 0.5, 0.5],
                                                     labels: [true, false, true, false], seed: 7)
        XCTAssertTrue(nan.observed.isNaN)
        XCTAssertFalse(nan.passed)
        // bins = 0: silent ECE = 0 (trivial perfect score from an invalid parameter):
        XCTAssertEqual(RWCCalibrationMethodologyV1.eceEqualMass(preds: [0.5, 0.5], labels: [true, false],
                                                                bins: 0), 0.0)
        // bins > n handled by empty-bin skip (documented):
        XCTAssertFalse(RWCCalibrationMethodologyV1.eceEqualMass(preds: [0.5, 0.5], labels: [true, false],
                                                                bins: 10).isNaN)
    }

    func testA15_EqualMassTies_OrderSensitivity_PINNED() {
        // AUDIT15 FINDING A15-F9: pins methodology instability — IDENTICAL (p,y) multiset, different
        // input ORDER ⇒ different equal-mass ECE (ties split across bins by position; no tie policy).
        let n = 20
        let allHalf = [Double](repeating: 0.5, count: n)
        let blocked = (0..<n).map { $0 < 10 }                       // ten 1s then ten 0s
        let interleaved = (0..<n).map { $0 % 2 == 0 }               // alternating — SAME multiset
        let e1 = RWCCalibrationMethodologyV1.eceEqualMass(preds: allHalf, labels: blocked)
        let e2 = RWCCalibrationMethodologyV1.eceEqualMass(preds: allHalf, labels: interleaved)
        XCTAssertEqual(e1, 0.5, accuracy: 1e-12, "blocked ordering: every bin purely 1s or 0s")
        XCTAssertEqual(e2, 0.0, accuracy: 1e-12, "interleaved ordering: every bin balanced")
        XCTAssertNotEqual(e1, e2, "same multiset, order changes the frozen estimator by 0.5 (defect)")
        // decision-level: the same multiset can flip the TEST gate verdict purely by ordering
        let d1 = RWCCalibrationMethodologyV1.decide(preds: allHalf, labels: blocked, seed: 11)
        let d2 = RWCCalibrationMethodologyV1.decide(preds: allHalf, labels: interleaved, seed: 11)
        XCTAssertNotEqual(d1.passed, d2.passed,
                          "AUDIT15 FINDING A15-F9: PASS/FAIL flips on input ordering alone")
    }

    func testA15_Decide_SeededDeterminism_And_Q95IndexConvention() {
        var rng = RWCSplitMix64(seed: 2_024)
        let preds = RWCCalibrationMethodologyV1.confidences("uniform", n: 400, rng: &rng)
        let labels = RWCCalibrationMethodologyV1.labels(for: preds, alternative: "null", rng: &rng)
        let a = RWCCalibrationMethodologyV1.decide(preds: preds, labels: labels, seed: 99)
        let b = RWCCalibrationMethodologyV1.decide(preds: preds, labels: labels, seed: 99)
        XCTAssertEqual(a, b, "same seed ⇒ byte-identical decision")
        let c = RWCCalibrationMethodologyV1.decide(preds: preds, labels: labels, seed: 100)
        XCTAssertNotEqual(a.nullQ95, c.nullQ95,
                          "different internal null seed ⇒ different critical value (S=200 coarseness; see report)")
        // frozen quantile convention: index Int(0.95*200)-1 = 189 ⇒ the 190th of 200 order statistics.
        // Under exchangeability the TEST gate alone rejects with probability 11/201 ≈ 5.47%, not 5.00%.
        XCTAssertEqual(Int(0.95 * Double(RWCCalibrationMethodologyV1.nullSims)) - 1, 189)
    }

    // ── §27/§29 — gates text (tri-state, coverage) + coverage counter validation attack ──

    func testA15_GatesV2_TriState_Coverage_Sentinel_Multiplicity_WindowLaw() throws {
        let gates = try text("docs/calibration/preregistration/RWC_FROZEN_GATES.yaml")
        for s in ["REPORTABLE/GATE_POWERED/UNDERPOWERED", "slice n >= 800", "coverage >= 0.80",
                  "CONDITIONAL ON SENTINEL-CLASS SAMPLING", "SAFETY_HARD_GATE", "never counted as success or failure",
                  "ANY change to a frozen normative artifact OR frozen methodology code AFTER PRE-14 PASS",
                  "superseded_v1_design", "rule-of-three"] {
            XCTAssertTrue(gates.contains(s), "gates v2 law present: \(s)")
        }
        XCTAssertEqual(RWCCalibrationMethodologyV1.frozenOverallN, 800)
        XCTAssertEqual(RWCCalibrationMethodologyV1.frozenMinDecisionCoverage, 0.80)
        // sentinel rule-of-three consistency: n=150 is exactly the smallest n with 95% UB <= 2%
        XCTAssertLessThanOrEqual(try XCTUnwrap(RWCStatisticsV1.zeroEventUpperBound95(n: 150)), 0.02)
        XCTAssertGreaterThan(try XCTUnwrap(RWCStatisticsV1.zeroEventUpperBound95(n: 148)), 0.02)
    }

    func testA15_F9_CoverageAcceptsImpossibleCounters_PINNED() {
        // AUDIT15 FINDING A15-F6: pins defective behavior — coverage() performs NO count validation.
        let impossible = RWCCalibrationMethodologyV1.coverage(
            inDistDecided: 120, inDistTotal: 100, oodAbstained: 60, oodTotal: 50,
            sentinelProtective: 200, sentinelDecided: 300, sentinelTotal: 150)
        XCTAssertEqual(impossible.decisionCoverage, 1.2, accuracy: 1e-12,
                       "decided > total ⇒ coverage 1.2 ≥ 0.80 gate trivially satisfied (defect)")
        XCTAssertEqual(impossible.abstentionRate, -0.2, accuracy: 1e-12, "negative abstention rate")
        XCTAssertEqual(impossible.oodAbstentionRate, 1.2, accuracy: 1e-12)
        XCTAssertGreaterThan(impossible.sentinelProtectiveRate, 1.0)
        let negative = RWCCalibrationMethodologyV1.coverage(
            inDistDecided: -5, inDistTotal: 10, oodAbstained: 0, oodTotal: 0,
            sentinelProtective: 0, sentinelDecided: 0, sentinelTotal: 0)
        XCTAssertEqual(negative.decisionCoverage, -0.5, accuracy: 1e-12, "negative counts accepted")
        XCTAssertEqual(negative.oodAbstentionRate, 0, "zero denominator yields plausible 0, not a refusal")
        // honest counters still behave correctly (law itself is sound when inputs are sane):
        let sane = RWCCalibrationMethodologyV1.coverage(inDistDecided: 640, inDistTotal: 800,
                                                        oodAbstained: 50, oodTotal: 50,
                                                        sentinelProtective: 150, sentinelDecided: 100,
                                                        sentinelTotal: 150)
        XCTAssertEqual(sane.decisionCoverage, 0.80, accuracy: 1e-12, "exactly 0.80 meets the frozen gate")
    }

    // ── §33/§34 — IRR: independent kappa/alpha + exact bootstrap differential + conventions ──

    /// Auditor's OWN quadratic-weighted kappa (independent formulation via disagreement weights).
    private func a15QWK(_ a: [Int], _ b: [Int], k: Int) -> Double? {
        guard a.count == b.count, !a.isEmpty, k >= 2,
              a.allSatisfy({ (0..<k).contains($0) }), b.allSatisfy({ (0..<k).contains($0) }) else { return nil }
        let n = Double(a.count)
        var rowP = [Double](repeating: 0, count: k), colP = [Double](repeating: 0, count: k)
        var dObs = 0.0
        let denomW = Double((k - 1) * (k - 1))
        for (x, y) in zip(a, b) {
            rowP[x] += 1 / n; colP[y] += 1 / n
            dObs += Double((x - y) * (x - y)) / denomW / n          // observed weighted DISagreement
        }
        var dExp = 0.0
        for i in 0..<k { for j in 0..<k { dExp += rowP[i] * colP[j] * Double((i - j) * (i - j)) / denomW } }
        guard dExp > 1e-12 else { return nil }
        return 1.0 - dObs / dExp                                    // identical to 1 - (1-po)/(1-pe)
    }

    func testA15_IndependentKappa_MatchesBuilder_AndHandValues() throws {
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.quadraticWeightedKappa(a: [0, 1, 2, 3, 4],
                                                                            b: [0, 1, 2, 3, 4], categories: 5)),
                       1.0, accuracy: 1e-12)
        // hand case: a=[0,0,1,1], b=[1,1,0,0], k=2 ⇒ po=0, pe=0.5 ⇒ kappa = -1
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.quadraticWeightedKappa(a: [0, 0, 1, 1],
                                                                            b: [1, 1, 0, 0], categories: 2)),
                       -1.0, accuracy: 1e-12)
        var rng = RWCSplitMix64(seed: 606)
        for _ in 0..<30 {
            let n = 20 + Int(rng.next() % 180)
            let a = (0..<n).map { _ in Int(rng.next() % 5) }
            let b = (0..<n).map { i in rng.double01() < 0.7 ? a[i % n] : Int(rng.next() % 5) }
            let mine = a15QWK(a, b, k: 5)
            let theirs = RWCStatisticsV1.quadraticWeightedKappa(a: a, b: b, categories: 5)
            if let m = mine, let t = theirs { XCTAssertEqual(m, t, accuracy: 1e-9) }
            else { XCTAssertEqual(mine == nil, theirs == nil, "degeneracy agreement") }
        }
        // degenerate single-category marginals ⇒ nil (INSUFFICIENT_DATA), never a number:
        XCTAssertNil(RWCStatisticsV1.quadraticWeightedKappa(a: [2, 2, 2], b: [2, 2, 2], categories: 5))
        // builder alpha hand case: a=[0,1], b=[1,0] ⇒ alpha = -0.5 (coincidence formulation)
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.krippendorffAlphaNominal(a: [0, 1], b: [1, 0])),
                       -0.5, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.krippendorffAlphaNominal(a: [0, 0, 1, 1],
                                                                              b: [0, 0, 1, 1])),
                       1.0, accuracy: 1e-12)
        XCTAssertNil(RWCStatisticsV1.krippendorffAlphaNominal(a: [1, 1], b: [1, 1]), "single category ⇒ nil")
    }

    func testA15_IRRBootstrap_ExactReplication_PercentileConvention() throws {
        // Reconstruct the builder's EXACT seeded bootstrap stream (same RWCSplitMix64 + same index
        // arithmetic) but score replicates with the AUDITOR'S OWN kappa; the final CI/decision must
        // match irrKappaDecision byte-for-byte — proving the frozen convention end to end.
        var a = [Int](), b = [Int]()
        var g = RWCSplitMix64(seed: 505)
        for _ in 0..<120 { let v = Int(g.next() % 5); a.append(v); b.append(g.double01() < 0.9 ? v : max(0, v - 1)) }
        let theirs = RWCCalibrationMethodologyV1.irrKappaDecision(a: a, b: b, categories: 5, threshold: 0.60)
        var rng = RWCSplitMix64(seed: RWCCalibrationMethodologyV1.irrSeed)
        var reps = [Double]()
        for _ in 0..<RWCCalibrationMethodologyV1.irrBootstrapB {
            var ra = [Int](), rb = [Int]()
            for _ in a.indices { let i = Int(rng.next() % UInt64(a.count)); ra.append(a[i]); rb.append(b[i]) }
            if let kk = a15QWK(ra, rb, k: 5) { reps.append(kk) }
        }
        XCTAssertGreaterThanOrEqual(Double(reps.count) / 2000.0, 0.80)
        reps.sort()
        let lo = reps[max(0, Int(0.025 * Double(reps.count)))]
        let hi = reps[min(reps.count - 1, Int(0.975 * Double(reps.count)))]
        XCTAssertEqual(lo, try XCTUnwrap(theirs.ciLower), accuracy: 1e-9, "independent CI lower matches")
        XCTAssertEqual(hi, try XCTUnwrap(theirs.ciUpper), accuracy: 1e-9)
        XCTAssertEqual(theirs.decision, lo >= 0.60 ? .pass : .fail, "decision IS the CI-lower rule")
        // frozen percentile convention characterized: with B=2000 valid replicates the bounds are the
        // 51st and 1951st order statistics ⇒ nominal [0.0255, 0.9755] quantiles (documented in report).
        XCTAssertEqual(Int(0.025 * 2000.0), 50)
        XCTAssertEqual(Int(0.975 * 2000.0), 1950)
        // determinism: repeated call byte-identical (frozen seed law)
        XCTAssertEqual(RWCCalibrationMethodologyV1.irrKappaDecision(a: a, b: b, categories: 5, threshold: 0.60),
                       theirs)
        // valid-replicate-fraction boundary arithmetic is exact integer/2000 comparison (deterministic):
        XCTAssertTrue(1600.0 / 2000.0 >= 0.80)
        XCTAssertFalse(1599.0 / 2000.0 >= 0.80)
    }

    // ── §36/§37/§38 — freeze v2 census; v1 recoverability; commit-binding contradiction ──

    func testA15_FreezeV2_FullHashCensus_18Normative_7Code() throws {
        let v2 = try json("docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V2.yaml")
        let arts = try XCTUnwrap(v2["artifacts"] as? [[String: Any]])
        XCTAssertEqual(arts.count, 25)
        let paths = arts.compactMap { $0["path"] as? String }
        XCTAssertEqual(Set(paths).count, 25, "no duplicate paths")
        let code = arts.filter { ($0["class"] as? String) == "METHODOLOGY_CODE" }
        XCTAssertEqual(code.count, 7, "7 methodology-code artifacts")
        XCTAssertEqual(arts.count - code.count, 18, "18 normative artifacts")
        for a in arts {
            let p = try XCTUnwrap(a["path"] as? String)
            XCTAssertEqual(try sha256(p), a["sha256"] as? String, "freeze v2 hash valid: \(p)")
        }
        XCTAssertEqual(v2["anchor_tag"] as? String, "gen8-rwc-preregistration-r1-audit-candidate")
        // AUDIT15 FINDING A15-F8 (pinned metadata): freeze_candidate_commit references 2143aac…,
        // a tree that PREDATES the methodology commit (ace1d94) and does NOT contain 12 of the 25
        // frozen artifacts (verified by the auditor via git; see report). The manifest's own
        // commit_binding_law declares tree/hash divergence to be drift — contradictory metadata.
        XCTAssertEqual(v2["freeze_candidate_commit"] as? String,
                       "2143aacc8f965de34872a502a57c034bba972888")
        // tag OBJECT sha is not recorded anywhere in the freeze evidence (name-only anchor):
        let raw = try text("docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V2.yaml")
        XCTAssertFalse(raw.contains("6bde7d4a"), "tag object SHA absent — pinned in the AUDIT15 report instead")
    }

    func testA15_FreezeV1_HistoricalTruth_Recoverable() throws {
        let v1 = try json("docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST.yaml")
        let arts = try XCTUnwrap(v1["artifacts"] as? [[String: Any]])
        XCTAssertEqual(arts.count, 15, "v1 manifest file itself byte-preserved (15 artifacts)")
        // v1's recorded gates hash is the HISTORICAL truth anchor; the LIVE gates file is v2 and
        // intentionally drifts. Auditor verified: sha256(git show 1c4160b:…RWC_FROZEN_GATES.yaml)
        // == f2fb4e53… == the hash recorded below (see report). Live file differs (expected):
        let gatesEntry = try XCTUnwrap(arts.first { ($0["path"] as? String)?.hasSuffix("RWC_FROZEN_GATES.yaml") == true })
        XCTAssertEqual(gatesEntry["sha256"] as? String,
                       "f2fb4e539a28d971b9ee6d9086567e593a007260f354e73a15f4e1d4734457b0")
        XCTAssertNotEqual(try sha256("docs/calibration/preregistration/RWC_FROZEN_GATES.yaml"),
                          "f2fb4e539a28d971b9ee6d9086567e593a007260f354e73a15f4e1d4734457b0",
                          "live gates file is v2 — 'v1 gates byte-preserved' wording is inaccurate (A15-F15)")
        let gates = try text("docs/calibration/preregistration/RWC_FROZEN_GATES.yaml")
        XCTAssertTrue(gates.contains("superseded_v1_design"), "v1 design preserved inline as negative evidence")
        // PRE-10 / PRE-11 protocol docs are OUTSIDE both freeze boundaries (A15-F12, LOW):
        let v2 = try json("docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V2.yaml")
        let v2paths = Set((v2["artifacts"] as? [[String: Any]] ?? []).compactMap { $0["path"] as? String })
        XCTAssertFalse(v2paths.contains("docs/calibration/preregistration/protocols/RWC_PRE10_SLICES.md"))
        XCTAssertFalse(v2paths.contains("docs/calibration/preregistration/protocols/RWC_PRE11_GATE_FREEZE.md"))
    }

    // ── §40/§41 — corpus entry guard: caller-trust and freeze-boundary-expansion attacks ──

    func testA15_CorpusEntryGuard_TrustsCallerState_PINNED() throws {
        // AUDIT15 FINDING A15-F11: pins the trust model — the guard is a POLICY FUNCTION over
        // caller-supplied state, NOT an authoritative PRE-14 verifier. A forged "PASS" string +
        // matching fake dictionaries + drift=false sails through:
        let fake = ["fake/path.yaml": "0000000000000000000000000000000000000000000000000000000000000000"]
        let forged = RWCCorpusEntryGuardV1.StateV1(
            pre14Verdict: "PASS",                       // no real audit PASS exists at this commit
            currentFrozenHashes: fake, auditedFrozenHashes: fake,
            freezeVersion: "rwc-prereg-freeze-v2", auditedFreezeVersion: "rwc-prereg-freeze-v2",
            dataVisibility: 0, postAuditMethodologyDrift: false)
        XCTAssertNoThrow(try RWCCorpusEntryGuardV1.requireEntry(forged),
                         "guard cannot detect a forged verdict — authoritative producer undefined")
        // freeze-boundary EXPANSION attack: an EXTRA methodology file in the live set is invisible
        // to the hash loop (it iterates audited paths only); only the caller-supplied drift boolean
        // could catch it — and the caller can lie:
        let audited = ["a.swift": "h1"]
        let current = ["a.swift": "h1", "b_new_methodology.swift": "h2"]   // new behavior-changing file
        let expanded = RWCCorpusEntryGuardV1.StateV1(
            pre14Verdict: "PASS", currentFrozenHashes: current, auditedFrozenHashes: audited,
            freezeVersion: "v2", auditedFreezeVersion: "v2", dataVisibility: 0,
            postAuditMethodologyDrift: false)
        XCTAssertNoThrow(try RWCCorpusEntryGuardV1.requireEntry(expanded),
                         "AUDIT15 FINDING A15-F11: extra-file drift not detected by the hash clause")
        // the clauses the guard DOES enforce still hold (same-path drift, version, visibility, verdict):
        XCTAssertThrowsError(try RWCCorpusEntryGuardV1.requireEntry(
            RWCCorpusEntryGuardV1.StateV1(pre14Verdict: "PASS",
                                          currentFrozenHashes: ["a.swift": "DRIFT"],
                                          auditedFrozenHashes: audited, freezeVersion: "v2",
                                          auditedFreezeVersion: "v2", dataVisibility: 0,
                                          postAuditMethodologyDrift: false)))
        XCTAssertThrowsError(try RWCCorpusEntryGuardV1.requireEntry(
            RWCCorpusEntryGuardV1.StateV1(pre14Verdict: "PASS", currentFrozenHashes: audited,
                                          auditedFrozenHashes: audited, freezeVersion: "v2",
                                          auditedFreezeVersion: "v2", dataVisibility: 1,
                                          postAuditMethodologyDrift: false)))
    }

    // ── §43/§44 — heldout/annotation laws; device F16 honest-open; TR/EN parity ──

    func testA15_Pre12OpeningLaws_Pre13DeviceRule_TREnParity() throws {
        let pre12 = try text("docs/calibration/preregistration/protocols/RWC_PRE12_SPLIT_SEAL.md")
        for s in ["WHAT COUNTS AS OPENING", "NOT opening", "append-only logged",
                  "loses FINAL status"] {
            XCTAssertTrue(pre12.contains(s), "PRE-12 opening/materiality law: \(s)")
        }
        let pre13 = try text("docs/calibration/preregistration/protocols/RWC_PRE13_DEVICE_EVIDENCE.md")
        XCTAssertTrue(pre13.contains("A14-F16 remains OPEN"), "F16 honestly open, blocking RWC-DEVICE")
        XCTAssertTrue(pre13.contains("UNKNOWN"), "unmeasured budgets report UNKNOWN, never PASS/FAIL")
        // the selection rule cites DEVICE_RESOURCE_BUDGETS, but that file names NO device floor —
        // "iPhone 11 class" is asserted only in PRE-13/ledger (A15-F14, INFO):
        let budgets = try text("docs/architecture/DEVICE_RESOURCE_BUDGETS.yaml")
        XCTAssertFalse(budgets.contains("iPhone 11"), "cited source does not name the floor device")
        XCTAssertTrue(budgets.contains("UNSET_PENDING_BASELINE"), "no measured budget values invented")
        // protective annotation law (RWC) vs legacy engineering midpoint — both as frozen:
        XCTAssertEqual(RWCAnnotationLawV1.finalLabel(a: 1, b: 2, adjudicated: nil), .adjudicationRequired)
        XCTAssertEqual(RWCAnnotationLawV1.finalLabel(a: 2, b: 4, adjudicated: nil), .label(2))
        // TR/EN handbook parity spot checks (D-16 OOD + D-17 sentinel present in both):
        let en = try text("docs/calibration/preregistration/handbook/RWC_ANNOTATION_HANDBOOK_v1_EN.md")
        let tr = try text("docs/calibration/preregistration/handbook/RWC_ANNOTATION_HANDBOOK_v1_TR.md")
        XCTAssertTrue(en.contains("[D-16]") && tr.contains("[D-16]"))
        XCTAssertTrue(en.contains("[D-17]") && tr.contains("[D-17]"))
        XCTAssertTrue(en.contains("audible") && !en.contains("авудible"), "A14-F14 typo fixed")
    }

    // ── §45/§46 — fail-evidence state + production locks + zero data ──

    func testA15_ZeroData_ProductionLocks_NoCorpusStarted() throws {
        let m = try json("docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml")
        XCTAssertEqual(m["corpus_count"] as? Int, 0)
        XCTAssertEqual(m["annotator_count"] as? Int, 0)
        XCTAssertEqual(m["real_fit_count"] as? Int, 0)
        XCTAssertEqual(m["heldout_open_count"] as? Int, 0)
        XCTAssertEqual(m["data_visibility"] as? Bool, false)
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims)
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59, "59 engineering pairs, unchanged")
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0, "production score release gate CLOSED")
        XCTAssertFalse(RealWorldCalibrationExecutorV1.preregistrationAuditPassed,
                       "AUDIT14 FIX REQUIRED stands until THIS independent re-audit rules")
        // freeze v2 zero-data declaration intact:
        let v2 = try json("docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V2.yaml")
        XCTAssertTrue((v2["pre_data_declaration"] as? String ?? "").contains("corpus_count=0"))
    }
}
