import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT14 — INDEPENDENT CLEAN-SESSION RWC PREREGISTRATION (PRE-14) PROBES.
// Candidate: 1c4160b11f807999437f36ae36ad0dc5d63853f3 (tag gen8-rwc-preregistration-audit-candidate).
// These probes are AUDITOR-AUTHORED (not copies of builder tests). They are deterministic and GREEN
// against the candidate AS-IS. Tests named *PINNED_* assert the CURRENT TRUTH of a finding
// (A14-F*): they document a defect/limitation exactly as it exists today and MUST be revisited
// (not deleted) when the finding is fixed. Independent reference implementations of the frozen
// statistics (quadratic-weighted kappa, Krippendorff nominal alpha, Wilson, zero-event UB,
// planning-n) are implemented HERE from first principles and differential-tested against
// RWCStatisticsV1. ZERO real data is used anywhere — synthetic fixtures only.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class AUDIT14_RWCPreregistrationPre14Probes: XCTestCase {

    // MARK: - helpers

    private var repoRoot: String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }
    private func text(_ rel: String) throws -> String {
        try String(contentsOfFile: repoRoot + "/" + rel, encoding: .utf8)
    }
    private func jsonObj(_ rel: String) throws -> [String: Any] {
        let d = try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + rel))
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: d) as? [String: Any])
    }
    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Deterministic splitmix64 — auditor's own PRNG (independent of RWCStatisticsV1 xorshift).
    private struct SplitMix64 {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state = state &+ 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func double01() -> Double { Double(next() >> 11) * 0x1.0p-53 }
        mutating func int(_ upper: Int) -> Int { Int(next() % UInt64(upper)) }
    }

    /// Auditor's INDEPENDENT quadratic-weighted Cohen kappa (first-principles).
    private func refQWK(_ a: [Int], _ b: [Int], k: Int) -> Double? {
        guard a.count == b.count, !a.isEmpty, k >= 2,
              a.allSatisfy({ (0..<k).contains($0) }), b.allSatisfy({ (0..<k).contains($0) }) else { return nil }
        let n = Double(a.count)
        var obs = Array(repeating: Array(repeating: 0.0, count: k), count: k)
        for (x, y) in zip(a, b) { obs[x][y] += 1 }
        var row = Array(repeating: 0.0, count: k), col = Array(repeating: 0.0, count: k)
        for i in 0..<k { for j in 0..<k { row[i] += obs[i][j]; col[j] += obs[i][j] } }
        func w(_ i: Int, _ j: Int) -> Double { 1 - Double((i - j) * (i - j)) / Double((k - 1) * (k - 1)) }
        var po = 0.0, pe = 0.0
        for i in 0..<k { for j in 0..<k {
            po += w(i, j) * obs[i][j] / n
            pe += w(i, j) * (row[i] / n) * (col[j] / n)
        } }
        guard abs(1 - pe) > 1e-12 else { return nil }
        return (po - pe) / (1 - pe)
    }

    /// Auditor's INDEPENDENT Krippendorff alpha (nominal, 2 coders, coincidence matrix with the
    /// true (n..−1) denominator — the property that distinguishes alpha from kappa-in-disguise).
    private func refAlpha(_ a: [Int], _ b: [Int]) -> Double? {
        guard a.count == b.count, !a.isEmpty else { return nil }
        var counts: [Int: Double] = [:]
        var disagreeCoincidence = 0.0
        for (x, y) in zip(a, b) {
            counts[x, default: 0] += 1; counts[y, default: 0] += 1
            if x != y { disagreeCoincidence += 2 }           // (x,y) and (y,x)
        }
        guard counts.count >= 2 else { return nil }
        let nTot = Double(2 * a.count)
        let Do = disagreeCoincidence / nTot
        var De = 0.0
        for (x, nx) in counts { for (y, ny) in counts where x != y { De += nx * ny } }
        De /= (nTot * (nTot - 1))
        guard De > 1e-12 else { return nil }
        return 1 - Do / De
    }

    /// Canonical rights-record fixture (synthetic; mirrors nothing real).
    private func rights(assetID: String = "rwc-asset-aud14f001",
                        source: RWCSourceClassV1 = .licensedRightsClear,
                        owner: String = "gen8-project",
                        rightsHolder: String = "licensor-aud",
                        evidence: String = "evidence-ptr-aud14",
                        allowed: [String] = ["training", "evaluation"],
                        prohibited: [String] = ["redistribution"],
                        training: Bool = true, eval: Bool = true,
                        acquisition: String = "2026-10-20", expiry: String? = nil,
                        state: RWCRevocationStateV1 = .active,
                        hash: String = String(repeating: "ab", count: 32),
                        provenance: [String] = ["step-001"]) -> RWCAssetRightsRecordV1 {
        RWCAssetRightsRecordV1(assetID: assetID, sourceClass: source, sourceReference: "store-ptr-aud",
                               owner: owner, rightsHolder: rightsHolder, licenseType: "lic-aud",
                               licenseEvidence: evidence, allowedUse: allowed, prohibitedUse: prohibited,
                               trainingAllowed: training, evaluationAllowed: eval,
                               derivativeRights: "derived-metrics-only", redistributionAllowed: false,
                               language: "tr", contentType: "video", modality: "video+audio",
                               acquisitionDate: acquisition, expiryDate: expiry, revocationState: state,
                               revocationDate: nil, contentHash: hash, provenanceChain: provenance)
    }

    // ═══════════════ §3/§4 CUSTODY + FREEZE ═══════════════

    /// §4 — auditor hash recomputation. I-16 (manifest addendum): re-anchored to the V2 freeze
    /// boundary after the R1 artifact edits — the v1 FILE stays byte-preserved as the FAILED
    /// candidate's record (count/paths pinned), its listed hashes are EXPECTED to drift from the
    /// edited artifacts, and EVERY v2 hash (normative + methodology code) must recompute valid.
    func testA14_Custody_FreezeManifest15_AllHashesRecomputedValid() throws {
        let v1 = try jsonObj("docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST.yaml")
        let v1arts = try XCTUnwrap(v1["artifacts"] as? [[String: Any]])
        XCTAssertEqual(v1arts.count, 15, "v1 manifest preserved exactly (FAILED-candidate history)")
        XCTAssertTrue((v1["pre_data_declaration"] as? String ?? "").contains("NO REAL CORPUS RESULTS"))
        let v1Drifted = v1arts.contains { a in
            guard let path = a["path"] as? String, let want = a["sha256"] as? String,
                  let data = try? Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + path)) else { return true }
            return sha256(data) != want
        }
        XCTAssertTrue(v1Drifted, "R1 edits necessarily drift v1-listed hashes — recorded, never hidden")
        let v2 = try jsonObj("docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V2.yaml")
        XCTAssertEqual(v2["supersedes"] as? String, "rwc-prereg-freeze-v1")
        for a in try XCTUnwrap(v2["artifacts"] as? [[String: Any]]) {
            let path = try XCTUnwrap(a["path"] as? String)
            let want = try XCTUnwrap(a["sha256"] as? String)
            let got = sha256(try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + path)))
            XCTAssertEqual(got, want, "freeze V2 hash drift (auditor recomputation): \(path)")
        }
        XCTAssertTrue((v2["pre_data_declaration"] as? String ?? "").contains("NO REAL CORPUS RESULTS"))
    }

    /// §4/§5 — master manifest: 13 packet hashes recomputed; load-bearing ZERO counters.
    func testA14_Custody_MasterManifest_PacketHashes_And_ZeroCounters() throws {
        let mm = try jsonObj("docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml")
        let hashes = try XCTUnwrap(mm["packet_hashes"] as? [String: String])
        XCTAssertEqual(hashes.count, 13)
        for (pid, want) in hashes {
            let p = repoRoot + "/docs/calibration/preregistration/packets/\(pid).yaml"
            XCTAssertEqual(sha256(try Data(contentsOf: URL(fileURLWithPath: p))), want, "packet hash drift: \(pid)")
        }
        XCTAssertEqual(mm["corpus_count"] as? Int, 0)
        XCTAssertEqual(mm["annotator_count"] as? Int, 0)
        XCTAssertEqual(mm["real_fit_count"] as? Int, 0)
        XCTAssertEqual(mm["heldout_open_count"] as? Int, 0)
        XCTAssertEqual(mm["data_visibility"] as? Bool, false)
        XCTAssertEqual(mm["entry_sha"] as? String, "2c345b64c720f965b68ec5ee699e1b71fecf0003")
        // zero asset records registered
        let schema = try jsonObj("docs/calibration/preregistration/RWC_ASSET_RIGHTS_LEDGER_SCHEMA.yaml")
        XCTAssertEqual((schema["records"] as? [Any])?.count, 0, "corpus must be ZERO")
    }

    /// A14-F13 (PINNED, MEDIUM): the freeze boundary hashes ONLY docs/* artifacts. NONE of the code
    /// files that IMPLEMENT the frozen methodology (RWCStatisticsV1.swift, RWCAssetIdentityV1.swift,
    /// RWCAssetRightsLedgerV1.swift, CalibrationRunPreparationV1.swift,
    /// RealWorldCalibrationExecutorV1.swift) are inside the hash freeze; and the frozen invalidation
    /// law binds POST-RESULT changes only — no written law forces re-freeze/re-audit for silent
    /// methodology-code edits in the post-PRE-14 / pre-corpus window.
    func testA14_PINNED_F13_FreezeBoundary_ExcludesMethodologyCode_PostResultOnlyInvalidation() throws {
        let freeze = try jsonObj("docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST.yaml")
        let paths = try XCTUnwrap(freeze["artifacts"] as? [[String: Any]]).compactMap { $0["path"] as? String }
        XCTAssertEqual(paths.count, 15)
        XCTAssertTrue(paths.allSatisfy { $0.hasPrefix("docs/") }, "PINNED: freeze boundary is docs-only")
        XCTAssertFalse(paths.contains { $0.hasSuffix(".swift") }, "PINNED: no methodology code is hashed")
        let gates = try jsonObj("docs/calibration/preregistration/RWC_FROZEN_GATES.yaml")
        let law = try XCTUnwrap(gates["invalidation_law"] as? String)
        XCTAssertTrue(law.contains("post-result"), "invalidation law is post-result scoped")
        // A14-F13 FIXED (inversion I-9): PRE14->corpus WINDOW law + commit-level freeze binding exist;
        // the V2 freeze manifest hashes methodology CODE too.
        XCTAssertTrue(law.lowercased().contains("pre-corpus") && law.lowercased().contains("commit"),
                      "A14-F13 FIXED: window re-freeze law + commit binding present")
        let v2 = try jsonObj("docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V2.yaml")
        let v2paths = try XCTUnwrap(v2["artifacts"] as? [[String: Any]]).compactMap { $0["path"] as? String }
        XCTAssertTrue(v2paths.contains { $0.hasSuffix(".swift") },
                      "A14-F13 FIXED: methodology code is inside the V2 freeze boundary")
    }

    /// §40 — freeze/hash attack on a TEMP COPY (never the canonical file): one flipped byte must
    /// diverge from the manifest hash, proving the drift check actually detects tampering.
    func testA14_HashAttack_TempCopyByteFlip_Diverges() throws {
        // I-14 (manifest addendum): re-anchored to the V2 freeze manifest — v1 is the FAILED
        // candidate's preserved historical record whose drift is expected and change-ledgered.
        let rel = "docs/calibration/preregistration/RWC_FROZEN_GATES.yaml"
        let freeze = try jsonObj("docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V2.yaml")
        let entry = try XCTUnwrap((freeze["artifacts"] as? [[String: Any]])?.first { ($0["path"] as? String) == rel })
        let want = try XCTUnwrap(entry["sha256"] as? String)
        var data = try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + rel))
        XCTAssertEqual(sha256(data), want, "canonical file matches before the attack")
        data[42] ^= 0x01                                    // flip ONE bit in the temp copy
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("a14_gates_flip.yaml")
        try data.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        XCTAssertNotEqual(sha256(try Data(contentsOf: tmp)), want, "one flipped bit must diverge")
    }

    // ═══════════════ §6 PRE-01 RIGHTS RED TEAM ═══════════════

    /// §6.1 — exactly two eligible classes; unknown/case-variant source classes FAIL CLOSED at decode.
    func testA14_Pre01_SourceClasses_TwoEligible_UnknownDecodeFailsClosed() throws {
        XCTAssertEqual(RWCSourceClassV1.allCases.filter(\.eligible),
                       [.projectOwnedReal, .licensedRightsClear])
        XCTAssertEqual(RWCSourceClassV1.allCases.count, 6)
        // decode attack: unknown / blank / lowercase-variant source classes must throw, never default
        let valid = try JSONEncoder().encode(rights())
        var dict = try XCTUnwrap(try JSONSerialization.jsonObject(with: valid) as? [String: Any])
        for attack in ["PUBLICLY_VISIBLE", "", "licensed_rights_clear", "Project_Owned_Real", "LICENSED"] {
            dict["sourceClass"] = attack
            let mutated = try JSONSerialization.data(withJSONObject: dict)
            XCTAssertThrowsError(try JSONDecoder().decode(RWCAssetRightsRecordV1.self, from: mutated),
                                 "source class '\(attack)' must fail closed at decode")
        }
        dict["sourceClass"] = "LICENSED_RIGHTS_CLEAR"
        dict["revocationState"] = "UNREVOKED"
        let badState = try JSONSerialization.data(withJSONObject: dict)
        XCTAssertThrowsError(try JSONDecoder().decode(RWCAssetRightsRecordV1.self, from: badState),
                             "unknown revocation state must fail closed at decode")
    }

    /// A14-F1 (PINNED, MEDIUM — fail-closed violation): requireEligible NEVER evaluates expiryDate.
    /// An ACTIVE record whose expiry is YEARS in the past passes for training AND evaluation.
    /// Malformed expiry, expiry == today, and expiry < acquisitionDate all pass too — there is no
    /// date logic and no canonical time source anywhere in the eligibility path. The contract's
    /// lifecycle ("…use → revoke/delete/expire") is enforced only if a caller manually sets
    /// revocationState = EXPIRED — convention, not structure.
    // A14-F1 FIXED (inversion I-1, docs/audit/AUDIT14_R1_INVERSION_LOCK.md): record-internal date laws
    // (strict yyyy-MM-dd; expiry>=acquisition; revocation>=acquisition) live in the 2-arg validator;
    // asOf-dependent expiry (valid THROUGH the expiry date) lives in the canonical store with
    // injectable asOf — no hidden clock anywhere.
    func testA14_PINNED_F1_ExpiredButActive_PassesEligibility() throws {
        let expired = rights(expiry: "2020-01-01")                      // long past vs acquisition 2026-10-20
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(expired, use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .dateOrderViolation(rule: "expiry >= acquisition"),
                           "A14-F1 FIXED: cross-field date law refuses expiry before acquisition")
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(expired, use: "evaluation"))
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(expiry: "not-a-date"), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .malformedDate(field: "expiryDate"),
                           "A14-F1 FIXED: malformed expiry fails closed")
        }
        // valid-THROUGH law: expiry == acquisition day is record-internally valid; the asOf check is a
        // store law (asOf > expiry => expired):
        XCTAssertNoThrow(try RWCAssetRightsLedgerV1.requireEligible(rights(expiry: "2026-10-20"), use: "training"),
                         "expiry == acquisition day is valid THROUGH that date (record-internal)")
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(
            rights(acquisition: "2026-10-20", expiry: "2025-01-01"), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .dateOrderViolation(rule: "expiry >= acquisition"))
        }
        // store asOf law: active record, future expiry, asOf past expiry => EXPIRED (deterministic clock)
        let store = RWCAssetRightsLedgerStoreV1()
        try store.register(storeRights(expiry: "2026-12-31"), asOf: "2026-10-20")
        XCTAssertNoThrow(try store.requireEligible(assetID: storeRights().assetID, use: .training, asOf: "2026-12-31"),
                         "valid through the expiry date itself")
        XCTAssertThrowsError(try store.requireEligible(assetID: storeRights().assetID, use: .training, asOf: "2027-01-01")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .expired, "A14-F1 FIXED: asOf past expiry refuses")
        }
        // the EXPIRED *state* still refuses too
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(state: .expired), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .expired)
        }
    }

    /// R1 store fixture: grammar-conforming pointers/provenance for the canonical store door.
    private func storeRights(assetID: String = "rwc-asset-aud14f001", expiry: String? = nil,
                             evidence: String = "rwc-rights-ref-aud14-0001") -> RWCAssetRightsRecordV1 {
        RWCAssetRightsRecordV1(assetID: assetID, sourceClass: .licensedRightsClear,
                               sourceReference: "rwc-source-ref-aud14-0001", owner: "gen8-project",
                               rightsHolder: "licensor-aud", licenseType: "lic-aud",
                               licenseEvidence: evidence, allowedUse: ["training", "evaluation"],
                               prohibitedUse: ["redistribution"], trainingAllowed: true, evaluationAllowed: true,
                               derivativeRights: "derived-metrics-only", redistributionAllowed: false,
                               language: "tr", contentType: "video", modality: "video+audio",
                               acquisitionDate: "2026-10-20", expiryDate: expiry, revocationState: .active,
                               revocationDate: nil, contentHash: String(repeating: "ab", count: 32),
                               provenanceChain: ["rwc-prov-0001"])
    }

    /// A14-F2 (PINNED, MEDIUM — contradictory dual truth): allowedUse/prohibitedUse are NEVER
    /// consulted by requireEligible; only the booleans decide. A record that PROHIBITS "training"
    /// while trainingAllowed=true passes for training. A record whose allowedUse excludes
    /// evaluation but evaluationAllowed=true passes for evaluation. Both lists containing the same
    /// use is representable and undetected. No field is declared authoritative anywhere.
    // A14-F2 FIXED (inversion I-2): ONE authoritative use truth — list/flag contradictions are typed
    // refusals (useConsistencyViolation); records are never silently repaired.
    func testA14_PINNED_F2_ContradictoryUseFields_Pass() throws {
        let prohibitsTraining = rights(allowed: [], prohibited: ["training"], training: true)
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(prohibitsTraining, use: "training")) {
            guard case .useConsistencyViolation? = $0 as? RWCRightsErrorV1 else { return XCTFail("typed consistency refusal required") }
        }
        let excludesEval = rights(allowed: ["training"], prohibited: [], eval: true)
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(excludesEval, use: "evaluation")) {
            guard case .useConsistencyViolation? = $0 as? RWCRightsErrorV1 else { return XCTFail("typed consistency refusal required") }
        }
        let bothLists = rights(allowed: ["training"], prohibited: ["training", "Training"])
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(bothLists, use: "training")) {
            guard case .useConsistencyViolation? = $0 as? RWCRightsErrorV1 else { return XCTFail("typed consistency refusal required") }
        }
    }

    /// A14-F3 (PINNED, LOW — opaque-pointer and field-hygiene laws are prose-only):
    /// newline-only licenseEvidence passes (.whitespaces excludes \n); raw URLs and filesystem
    /// paths pass as "opaque pointers"; owner may be EMPTY; contentHash accepts UPPER/MIXED-case
    /// hex (Character.isHexDigit) so one content can carry case-variant hash strings;
    /// acquisitionDate is never validated; duplicate provenance entries pass.
    // A14-F3 FIXED (inversion I-3): field hygiene is machine law — newline/empty fields and hash-case
    // in the 2-arg validator; opaque-pointer grammar at the canonical STORE door.
    func testA14_PINNED_F3_FieldHygiene_ProseOnlyLaws() throws {
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(evidence: "\n\n"), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .missingLicenseEvidence,
                           "A14-F3 FIXED: newline-only evidence fails the upgraded emptiness law")
        }
        // opaque-pointer grammar enforced at the canonical store registration (raw URL / path refused)
        let store = RWCAssetRightsLedgerStoreV1()
        XCTAssertThrowsError(try store.register(storeRights(evidence: "https-example-com-license"), asOf: "2026-10-20")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .invalidEvidencePointer(field: "licenseEvidence"))
        }
        var url = storeRights(); _ = url
        XCTAssertThrowsError(try store.register(
            RWCAssetRightsRecordV1(assetID: "rwc-asset-aud14f003", sourceClass: .licensedRightsClear,
                                   sourceReference: "/Users/someone/Documents/store",
                                   owner: "gen8-project", rightsHolder: "licensor-aud", licenseType: "lic",
                                   licenseEvidence: "rwc-rights-ref-aud14-0003", allowedUse: ["training", "evaluation"],
                                   prohibitedUse: [], trainingAllowed: true, evaluationAllowed: true,
                                   derivativeRights: "d", redistributionAllowed: false, language: "tr",
                                   contentType: "video", modality: "v", acquisitionDate: "2026-10-20",
                                   expiryDate: nil, revocationState: .active, revocationDate: nil,
                                   contentHash: String(repeating: "ab", count: 32),
                                   provenanceChain: ["rwc-prov-0001"]), asOf: "2026-10-20")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .invalidEvidencePointer(field: "sourceReference"),
                           "A14-F3 FIXED: filesystem path refused by pointer grammar")
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(owner: ""), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .missingOwner, "A14-F3 FIXED: empty owner refused")
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(
            rights(hash: String(repeating: "AB", count: 32)), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .invalidContentHash, "A14-F3 FIXED: uppercase hex refused, not normalized")
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(
            rights(hash: String(repeating: "aB", count: 32)), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .invalidContentHash, "A14-F3 FIXED: mixed-case hex refused")
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(acquisition: "someday"), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .malformedDate(field: "acquisitionDate"),
                           "A14-F3 FIXED: acquisitionDate strictly validated")
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(
            rights(provenance: ["p1", "p1", "p1"]), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .duplicateProvenance, "A14-F3 FIXED: duplicate provenance refused")
        }
    }

    /// §6 — the refusals that DO hold today (fail-closed surface that works).
    func testA14_Pre01_RefusalsThatHold() throws {
        for bad in [RWCSourceClassV1.refusedScraped, .refusedPrivateCapture, .refusedUserPrivate, .refusedUnknownLicense] {
            XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(source: bad), use: "training")) {
                XCTAssertEqual($0 as? RWCRightsErrorV1, .ineligibleSourceClass(bad))
            }
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(state: .revoked), use: "evaluation")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .revoked)
        }
        // unknown uses fail closed — including case variants of the known uses (byte-exact law)
        for use in ["marketing", "", "Training", "TRAINING", "Evaluation", "training ", "retraining"] {
            XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(), use: use),
                                 "unknown/case-variant use '\(use)' must refuse") {
                XCTAssertEqual($0 as? RWCRightsErrorV1, .useNotAllowed(use: use))
            }
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(training: false), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .useNotAllowed(use: "training"))
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(hash: String(repeating: "zz", count: 32)), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .invalidContentHash)
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(hash: "abc123"), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .invalidContentHash)
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(provenance: []), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .emptyProvenance)
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(evidence: "   "), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .missingLicenseEvidence)
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(rightsHolder: " "), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .missingRightsHolder)
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(rights(assetID: "funny cat video.mp4"), use: "training"))
    }

    /// A14-F4 (PINNED, MEDIUM — resurrection): revocation monotonicity is a property of ONE value,
    /// not of a ledger. No global registry/history exists, so a caller can construct a FRESH ACTIVE
    /// record with the SAME assetID and the SAME old evidence after revocation and it passes
    /// eligibility. "Resurrection requires new registration + new evidence" is enforced nowhere.
    // A14-F4 FIXED (inversion I-4): the append-only RWCAssetRightsLedgerStoreV1 is the CANONICAL
    // eligibility authority — resurrection with old evidence is a typed refusal; relicensing exists
    // only as an explicit reauthorize event with NEW evidence identity (auditable).
    func testA14_PINNED_F4_Resurrection_SameIDOldEvidence_Passes() throws {
        let original = rights()
        let revokedValue = RWCAssetRightsLedgerV1.revoked(original, onDate: "2026-11-01")
        XCTAssertEqual(revokedValue.revocationState, .revoked)
        XCTAssertFalse(revokedValue.trainingAllowed); XCTAssertFalse(revokedValue.evaluationAllowed)
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(revokedValue, use: "training"))
        // canonical store: register → eligible → revoke → every resurrection shape refused
        let store = RWCAssetRightsLedgerStoreV1()
        try store.register(storeRights(), asOf: "2026-10-20")
        XCTAssertNoThrow(try store.requireEligible(assetID: storeRights().assetID, use: .training, asOf: "2026-10-20"))
        try store.revoke(assetID: storeRights().assetID, onDate: "2026-11-01")
        XCTAssertThrowsError(try store.requireEligible(assetID: storeRights().assetID, use: .training, asOf: "2026-11-02")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .revoked)
        }
        XCTAssertThrowsError(try store.register(storeRights(), asOf: "2026-11-03")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .resurrectionRefused,
                           "A14-F4 FIXED: same assetID + OLD evidence can never re-register after revocation")
        }
        XCTAssertThrowsError(try store.reauthorize(storeRights(), asOf: "2026-11-03")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .reauthorizationRequiresNewEvidence,
                           "A14-F4 FIXED: reauthorization demands a NEW evidence identity")
        }
        // lawful relicensing: explicit event + NEW evidence → eligible again, fully auditable
        XCTAssertNoThrow(try store.reauthorize(storeRights(evidence: "rwc-rights-ref-aud14-0002"), asOf: "2026-11-03"))
        XCTAssertNoThrow(try store.requireEligible(assetID: storeRights().assetID, use: .training, asOf: "2026-11-04"))
        XCTAssertEqual(store.events.map(\.kind), ["registered", "revoked", "reauthorized"],
                       "append-only event chain witnesses the transition")
    }

    // ═══════════════ §7 PRE-02 IDENTITY — INDEPENDENT ADVERSARIAL MATRIX ═══════════════

    func testA14_Pre02_AssetGrammar_AdversarialMatrix() throws {
        // valid boundaries
        XCTAssertNil(RWCAssetIdentityV1.validateAssetID("rwc-asset-00000000"), "8-char min")
        XCTAssertNil(RWCAssetIdentityV1.validateAssetID("rwc-asset-" + String(repeating: "a", count: 32)), "32-char max")
        // CR / LF / CRLF / tab / interior and edge whitespace
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-a1b2c3d4\r\n"), .controlOrWhitespace(index: 18))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-a1b2c3d4\r"), .controlOrWhitespace(index: 18))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-a1b2 c3d4"), .controlOrWhitespace(index: 14))
        // zero-width + BOM + emoji + DEL
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-a\u{200B}b2c3d4e"), .nonASCII(index: 11), "U+200B refused")
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("\u{FEFF}rwc-asset-a1b2c3d4"), .nonASCII(index: 0), "BOM refused")
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-\u{1F600}bcdefgh"), .nonASCII(index: 10), "emoji refused")
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-a\u{7F}b2c3d4e"), .controlOrWhitespace(index: 11), "DEL 0x7F refused")
        // URL / path / colon / slash syntax
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("https://cdn.example/v.mp4"), .badPrefix)
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("../../etc/passwd"), .badPrefix)
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-a:b2c3d4e"), .forbiddenCharacter(index: 11))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-a/b2c3d4e"), .forbiddenCharacter(index: 11))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-a_b2c3d4e"), .forbiddenCharacter(index: 11))
        // Unicode normalization / lookalike law: NFC vs NFD are DIFFERENT refusals, never unified
        XCTAssertNotNil(RWCAssetIdentityV1.validateAssetID("rwc-asset-caf\u{00E9}5678"))
        XCTAssertNotNil(RWCAssetIdentityV1.validateAssetID("rwc-asset-cafe\u{0301}5678"))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-\u{0430}1b2c3d4"), .nonASCII(index: 10), "Cyrillic а refused")
        // case law
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-A1B2C3D4"), .forbiddenCharacter(index: 10))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("Rwc-asset-a1b2c3d4"), .badPrefix)
        // separator injection
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-a1#2c3d4e"), .separatorForbidden(index: 12))
        // length bounds
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-abcdefg"), .badLength(actual: 7, minimum: 8, maximum: 32))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-"), .badLength(actual: 0, minimum: 8, maximum: 32))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID(""), .empty)
    }

    func testA14_Pre02_ProfileGrammar_EdgeCases() throws {
        XCTAssertNil(RWCAssetIdentityV1.validateProfileID("p-1"), "3-char min valid")
        XCTAssertNil(RWCAssetIdentityV1.validateProfileID(String(repeating: "a", count: 40)), "40 max valid")
        XCTAssertEqual(RWCAssetIdentityV1.validateProfileID("ab"), .badLength(actual: 2, minimum: 3, maximum: 40))
        XCTAssertEqual(RWCAssetIdentityV1.validateProfileID(String(repeating: "a", count: 41)),
                       .badLength(actual: 41, minimum: 3, maximum: 40))
        XCTAssertNotNil(RWCAssetIdentityV1.validateProfileID("-abc"), "leading dash refused")
        XCTAssertNotNil(RWCAssetIdentityV1.validateProfileID("abc-"), "trailing dash refused")
        XCTAssertNotNil(RWCAssetIdentityV1.validateProfileID("a--b"), "double dash refused")
        XCTAssertEqual(RWCAssetIdentityV1.validateProfileID("Adult"), .forbiddenCharacter(index: 0))
        XCTAssertEqual(RWCAssetIdentityV1.validateProfileID("a b"), .controlOrWhitespace(index: 1))
        XCTAssertEqual(RWCAssetIdentityV1.validateProfileID("p\u{200B}xy"), .nonASCII(index: 1))
    }

    func testA14_Pre02_Composite_RoundtripIdentity_AndShapeAttacks() throws {
        let pairs = [("rwc-asset-a1b2c3d4", "p-1"), ("rwc-asset-" + String(repeating: "z", count: 32),
                                                     String(repeating: "q", count: 40))]
        for (a, p) in pairs {
            let c = try RWCAssetIdentityV1.composite(assetID: a, profileID: p)
            let back = try RWCAssetIdentityV1.parseComposite(c)
            XCTAssertEqual(back.assetID, a); XCTAssertEqual(back.profileID, p)   // parse∘compose == identity
            XCTAssertEqual(c.filter { $0 == "#" }.count, 1)
        }
        XCTAssertThrowsError(try RWCAssetIdentityV1.parseComposite("a#b#c")) {
            XCTAssertEqual($0 as? RWCAssetIdentityErrorV1, .compositeShape(separators: 2))
        }
        XCTAssertThrowsError(try RWCAssetIdentityV1.parseComposite("rwc-asset-a1b2c3d4#p-1#"))
        XCTAssertThrowsError(try RWCAssetIdentityV1.parseComposite("#p-abc"))         // empty asset refused
        XCTAssertThrowsError(try RWCAssetIdentityV1.parseComposite("rwc-asset-a1b2c3d4#"))  // empty profile refused
        XCTAssertThrowsError(try RWCAssetIdentityV1.parseComposite("#"))
        XCTAssertThrowsError(try RWCAssetIdentityV1.parseComposite("no-separator-here"))
        XCTAssertThrowsError(try RWCAssetIdentityV1.composite(assetID: "rwc-asset-A1b2c3d4", profileID: "p-1"))
        XCTAssertThrowsError(try RWCAssetIdentityV1.composite(assetID: "rwc-asset-a1b2c3d4", profileID: "-p1"))
    }

    // ═══════════════ §8/§9 PRE-02 ↔ PRE-04 INTEGRATION ═══════════════

    /// A14-F5 (PINNED, MEDIUM): the canonical PRE-04 door `prepareDataset` does NOT enforce the
    /// PRE-02 RWC grammar. Any garbage-but-consistent string (invalid composite, path traversal,
    /// uppercase asset, Unicode, multi-#, no # at all) mints a PreparedCalibrationDatasetV1 token.
    /// The frozen PRE-04 protocol claims "bad asset ID … → no PreparedCalibrationDatasetV1 ever
    /// exists" — that claim is FALSE for consistent garbage. (The executor still refuses to run,
    /// and the rights ledger validates grammar separately at registration — exploitability is
    /// bounded, but PRE-02 is NOT wired into the canonical PRE-04 door.)
    func testA14_PINNED_F5_GarbageConsistentIDs_MintPreparedToken() throws {
        let garbage = ["not-a-valid-rwc-id#profile",
                       "funny cat video#abc",
                       "../../secret#abc",
                       "rwc-asset-ABCDEFGH#abc",
                       "rwc-asset-caf\u{00E9}1234#p-aa",
                       "a#b#c###",
                       "no-separator-at-all",
                       "rwc-asset-a1b2c3d4#p\u{200B}xy"]
        // A14-F5 FIXED (inversion I-5): the RWC door validates EVERY composite with
        // RWCAssetIdentityV1.parseComposite BEFORE the exact-identity guard — exact-but-RWC-invalid
        // identities can never mint a token; diagnostics carry count/index only (no raw echo).
        for bad in garbage {
            XCTAssertNotNil(RWCAssetIdentityV1.validateAssetID(bad), "each fixture IS RWC-invalid: \(bad)")
            XCTAssertThrowsError(try CalibrationRunPreparationV1.prepareDataset(declaredIDs: [bad], resolvedIDs: [bad])) {
                guard case let .invalidRWCCompositeIDs(count, firstIndex, category)? = $0 as? CalibrationIntegrityErrorV1
                else { return XCTFail("typed grammar refusal required for '\(bad)'") }
                XCTAssertEqual(count, 1); XCTAssertEqual(firstIndex, 0)
                XCTAssertTrue(category.hasSuffix(":declared"))
            }
        }
        // a VALID composite still mints (grammar wired, door not broken) and the executor still refuses
        let ok = try CalibrationRunPreparationV1.prepareDataset(declaredIDs: ["rwc-asset-a1b2c3d4#p-aa"],
                                                                resolvedIDs: ["rwc-asset-a1b2c3d4#p-aa"])
        XCTAssertEqual(ok.count, 1)
        XCTAssertThrowsError(try RealWorldCalibrationExecutorV1.execute(ok)) {
            XCTAssertEqual($0 as? RWCExecutorErrorV1, .preregistrationNotPassed(requiredGate: "RWC-PRE-14"))
        }
        // the corrected protocol text now states the implemented law (phrase kept, claim now TRUE)
        let proto = try text("docs/calibration/preregistration/protocols/RWC_PRE04_EXECUTOR_GATE.md")
        XCTAssertTrue(proto.contains("bad asset ID"),
                      "the PRE-04 doc's bad-asset-ID protection claim is now implemented by the door")
    }

    /// §10 executor locks: flag false; valid token → preregistrationNotPassed; empty token typed.
    /// (The second refusal fitPhaseNotAuthorized is source-pinned below since the first guard
    /// structurally precedes it while preregistrationAuditPassed == false.)
    func testA14_Pre04_ExecutorDoubleRefusal_CurrentTruth() throws {
        XCTAssertFalse(RealWorldCalibrationExecutorV1.preregistrationAuditPassed, "PRE-14 has NOT passed")
        let ids = ["rwc-asset-aud14a001#p-aud", "rwc-asset-aud14a002#p-aud"]
        let token = try CalibrationRunPreparationV1.prepareDataset(declaredIDs: ids, resolvedIDs: ids.reversed())
        XCTAssertEqual(token.count, 2)
        XCTAssertThrowsError(try RealWorldCalibrationExecutorV1.execute(token)) {
            XCTAssertEqual($0 as? RWCExecutorErrorV1, .preregistrationNotPassed(requiredGate: "RWC-PRE-14"))
        }
        let empty = try CalibrationRunPreparationV1.prepareDataset(declaredIDs: [], resolvedIDs: [])
        XCTAssertThrowsError(try RealWorldCalibrationExecutorV1.execute(empty)) {
            XCTAssertEqual($0 as? RWCExecutorErrorV1, .emptyDataset)
        }
        // hypothetical flag-flip: the SECOND refusal must exist in source AFTER the flag guard,
        // unconditionally — so flipping the flag alone still cannot fit anything.
        let src = try text("packages/GuardianKit/Sources/GuardianCore/RealWorldCalibrationExecutorV1.swift")
        let guardPos = try XCTUnwrap(src.range(of: "preregistrationNotPassed(requiredGate:"))
        let secondPos = try XCTUnwrap(src.range(of: "throw RWCExecutorErrorV1.fitPhaseNotAuthorized"))
        XCTAssertTrue(guardPos.lowerBound < secondPos.lowerBound,
                      "fit refusal is the unconditional tail — flag flip alone cannot authorize a fit")
        XCTAssertFalse(src.contains("LogisticCalibrator") && src.contains("PilotExample"),
                       "no pilot bridge on the real-world surface")
    }

    /// A14-F6 (PINNED, LOW): the prepared token binds OPAQUE IDs ONLY — compositeIDs + category +
    /// guardRevision are its complete stored state (Mirror census). It does NOT bind features,
    /// labels, content hashes, or any data payload. CLOSED for the CURRENT no-fit surface (execute
    /// always refuses), but an ID↔record/payload binding invariant is REQUIRED at RWC-FIT:
    /// a future caller could pair a valid token with mismatched raw data.
    func testA14_PINNED_F6_TokenPayload_IDsOnly_NoDataBinding() throws {
        let ids = ["rwc-asset-aud14b001#p-aud"]
        let token = try CalibrationRunPreparationV1.prepareDataset(declaredIDs: ids, resolvedIDs: ids)
        let stored = Mirror(reflecting: token).children.compactMap(\.label).sorted()
        XCTAssertEqual(stored, ["category", "compositeIDs", "guardRevision"],
                       "PINNED A14-F6: token stores exactly 3 fields — no payload binding exists")
        XCTAssertEqual(token.guardRevision, "calibration-run-guard-v2")
    }

    /// A14-F6b (PINNED, LOW — A11-F2-APIBYPASS residue): the GENERIC fit surfaces remain public and
    /// directly callable with raw arrays, entirely outside the prepared-token door. Nothing in the
    /// type system distinguishes "real-world" numbers from engineering numbers at these entrypoints;
    /// the separation is governance (rights law + zero-data + process), not structure. The builder's
    /// "closes A11-F2-APIBYPASS structurally" is true ONLY for the executor door itself.
    func testA14_PINNED_F6b_GenericFitSurfaces_RemainDirectlyCallable() throws {
        // All inputs below are SYNTHETIC. The point is expressibility, not data.
        let cal = DimensionCalibratorV1.fit(name: "aud-probe", slice: "all",
                                            xs: [0.1, 0.2, 0.3, 0.4, 0.6, 0.7, 0.8, 0.9],
                                            ys: [false, false, false, false, true, true, true, true])
        XCTAssertTrue(cal.fitted, "PINNED: DimensionCalibratorV1.fit callable with raw arrays — no token required")
        let logistic = LogisticCalibrator.fit([(0.1, false), (0.2, false), (0.8, true), (0.9, true)], iterations: 50)
        XCTAssertTrue(logistic.a.isFinite, "PINNED: LogisticCalibrator.fit callable directly")
        let fusion = SuitabilityFusionModelV1.fit(
            features: (0..<10).map { [Double($0) / 10, 0.5, 0.1, 0, 0] },
            targets: (0..<10).map { _ in 2.0 })
        XCTAssertTrue(fusion.fitted, "PINNED: SuitabilityFusionModelV1.fit callable directly")
    }

    // ═══════════════ §11 PRE-03 LEGACY ═══════════════

    /// Legacy pins: behavior unchanged; context parameter is DEFAULTED so every old call site still
    /// compiles — deprecation is WARNING-ONLY enforcement (pinned honestly, not claimed structural);
    /// the type-level law is that no real-world case exists to pass.
    func testA14_Pre03_Legacy_PinnedBehavior_WarningOnlyEnforcement() throws {
        // AUDIT11-pinned legacy semantics unchanged: mae min-count truncation
        XCTAssertEqual(CalibrationMetrics.mae(predicted: [0.9, 0.1], truth: [0.9]), 0.0, accuracy: 1e-12)
        // single-case context type — a real-world case cannot be expressed
        XCTAssertEqual("\(EngineeringOnlyExecutionContextV1.engineeringLab)", "engineeringLab")
        // the legacy pilot runner remains DIRECTLY callable with the defaulted context (warning-only):
        let train = [PilotExample(id: "s1", language: "tr", modality: "video", rawSuitability: 0.2, labelSuitable: false, labelScore: 20),
                     PilotExample(id: "s2", language: "tr", modality: "video", rawSuitability: 0.8, labelSuitable: true, labelScore: 80),
                     PilotExample(id: "s3", language: "tr", modality: "video", rawSuitability: 0.3, labelSuitable: false, labelScore: 30),
                     PilotExample(id: "s4", language: "tr", modality: "video", rawSuitability: 0.9, labelSuitable: true, labelScore: 90)]
        let result = CalibrationPilotRunner.run(train: train, test: train, modalities: ["video"], revision: "aud14-probe")
        XCTAssertLessThanOrEqual(result.scope.level, .labCalibratedLimited,
                                 "legacy pilot can NEVER exceed LAB_CALIBRATED_LIMITED")
        // bridgelessness: no conversion API exists between the worlds (source-level census)
        let prep = try text("packages/GuardianKit/Sources/GuardianCore/CalibrationRunPreparationV1.swift")
        XCTAssertFalse(prep.contains("PilotExample"), "no PreparedDataset↔PilotExample bridge")
    }

    // ═══════════════ §12/§13 PRE-05 HANDBOOK ═══════════════

    /// Bilingual semantic spot anchors + A14-F14 (PINNED, INFO): the EN handbook D-02 contains
    /// Cyrillic lookalike bytes ("ав удible" typo class) — ironic given the ID charset law, but
    /// not label-shifting. Direction/sentinel/abstention laws are semantically aligned TR↔EN.
    func testA14_Pre05_Handbooks_SemanticAnchors_PINNED_F14_CyrillicTypoInEN() throws {
        let en = try text("docs/calibration/preregistration/handbook/RWC_ANNOTATION_HANDBOOK_v1_EN.md")
        let tr = try text("docs/calibration/preregistration/handbook/RWC_ANNOTATION_HANDBOOK_v1_TR.md")
        // scale direction identical: 0 = protect … 4 = strongly aligned (no inversion)
        XCTAssertTrue(en.contains("0 strongly-unsuitable/protect") && en.contains("4 strongly aligned"))
        XCTAssertTrue(tr.contains("0 kesin-uygunsuz/koru") && tr.contains("4 guclu uyumlu"))
        // sentinel laws: protective-only outcome; abstention on a sentinel is NOT false-safe; blindness
        XCTAssertTrue(en.contains("abstention on a sentinel is NOT false-safe"))
        XCTAssertTrue(tr.contains("sentinelde cekimserlik false-safe DEGILDIR"))
        XCTAssertTrue(en.contains("never revealed as sentinels"))
        XCTAssertTrue(tr.contains("asla sentinel olarak acilmaz"))
        // strong-protection four-element definition present in both
        for needle in ["self-harm instruction", "credible direct threat"] { XCTAssertTrue(en.contains(needle)) }
        for needle in ["kendine-zarar talimati", "inandirici dogrudan tehdit"] { XCTAssertTrue(tr.contains(needle)) }
        // abstention first-class in both; no quotas
        XCTAssertTrue(en.contains("never a failure") && tr.contains("asla basarisizlik degildir"))
        // age law: never infer age from imagery (both)
        XCTAssertTrue(en.contains("never infer age from imagery") && tr.contains("yasi asla goruntuden cikarma"))
        // PINNED A14-F14: EN D-02 carries Cyrillic scalars (lookalike typo) — INFO-level divergence
        let cyrillic = en.unicodeScalars.filter { (0x0400...0x04FF).contains($0.value) }
        XCTAssertTrue(cyrillic.isEmpty,
                      "A14-F14 FIXED (I-13): Cyrillic lookalike bytes removed from the EN handbook (rev v1.0.1)")
    }

    /// §13 label direction vs code + A14-F15 (PINNED, LOW): unadjudicated |A−B|=1 disagreements
    /// with odd sum round HALF AWAY FROM ZERO — i.e. systematically toward the LESS protective
    /// label (0/1→1, 1/2→2, 2/3→3, 3/4→4). Adjudication is only REQUIRED at |A−B|≥2, so this
    /// tie-break direction can stand in final labels.
    func testA14_Pre05_LabelDirection_CodeConsistency_PINNED_F15_TieRounding() throws {
        XCTAssertEqual(SuitabilityRubricV1.levels.first, "0=strongly-unsuitable/protect")
        XCTAssertEqual(SuitabilityRubricV1.levels.last, "4=strongly-aligned")
        // finalLabel: adjudication wins; unsuitable class is ≤1 (P009E consumers use finalLabel<=1)
        let adjudicated = CalibrationAnnotationV1(itemID: "i", profileID: "p", locale: "tr",
                                                  labelA: 0, labelB: 4, adjudicated: 1)
        XCTAssertEqual(adjudicated.finalLabel, 1)
        XCTAssertTrue(adjudicated.disagreement)
        // PINNED A14-F15: anti-protective tie rounding on unadjudicated odd-sum pairs
        XCTAssertEqual(CalibrationAnnotationV1(itemID: "i", profileID: "p", locale: "tr",
                                               labelA: 0, labelB: 1).finalLabel, 1,
                       "PINNED: 0/1 rounds UP to 1 (same class, but away from protect)")
        XCTAssertEqual(CalibrationAnnotationV1(itemID: "i", profileID: "p", locale: "tr",
                                               labelA: 1, labelB: 2).finalLabel, 2,
                       "PINNED A14-F15: 1/2 rounds UP to 2 — unsuitable→caution class flip without adjudication")
        XCTAssertEqual(CalibrationAnnotationV1(itemID: "i", profileID: "p", locale: "tr",
                                               labelA: 3, labelB: 4).finalLabel, 4)
        // score mapping: rubric×25 → /25 round trip (0–4 ↔ 0–100), no inversion
        XCTAssertEqual(4.0 * 25.0 / 25.0, 4.0, accuracy: 1e-12)
    }

    // ═══════════════ §17/§18 INDEPENDENT IRR MATH ═══════════════

    /// Differential test: auditor's independent QWK vs RWCStatisticsV1 across seeded random
    /// matrices (k = 2/3/5 × n = 10/37/120) + perfect/systematic/imbalanced/constant-vs-variable.
    func testA14_Pre08_IndependentQWK_DifferentialMatch() throws {
        var rng = SplitMix64(seed: 0xA14_2026_1020)
        for k in [2, 3, 5] {
            for n in [10, 37, 120] {
                let a = (0..<n).map { _ in rng.int(k) }
                let b = (0..<n).map { _ in rng.int(k) }
                let mine = refQWK(a, b, k: k)
                let theirs = RWCStatisticsV1.quadraticWeightedKappa(a: a, b: b, categories: k)
                switch (mine, theirs) {
                case let (m?, t?): XCTAssertEqual(m, t, accuracy: 1e-9, "QWK mismatch k=\(k) n=\(n)")
                case (nil, nil): break
                default: XCTFail("degenerate-detection disagreement k=\(k) n=\(n)")
                }
            }
        }
        // perfect agreement
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.quadraticWeightedKappa(a: [0, 1, 2, 3, 4], b: [0, 1, 2, 3, 4], categories: 5)),
                       1.0, accuracy: 1e-12)
        // systematic total disagreement k=2 → −1 (both implementations)
        XCTAssertEqual(try XCTUnwrap(refQWK([0, 0, 1, 1], [1, 1, 0, 0], k: 2)), -1.0, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.quadraticWeightedKappa(a: [0, 0, 1, 1], b: [1, 1, 0, 0], categories: 2)),
                       -1.0, accuracy: 1e-12)
        // constant-vs-variable: defined (marginals not fully concentrated) and must agree
        let cv = RWCStatisticsV1.quadraticWeightedKappa(a: [2, 2, 2, 2], b: [0, 1, 3, 4], categories: 5)
        XCTAssertEqual(try XCTUnwrap(cv), try XCTUnwrap(refQWK([2, 2, 2, 2], [0, 1, 3, 4], k: 5)), accuracy: 1e-9)
        // imbalanced 90/10
        let aI = Array(repeating: 0, count: 18) + [1, 1]
        let bI = Array(repeating: 0, count: 17) + [1, 1, 0]
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.quadraticWeightedKappa(a: aI, b: bI, categories: 2)),
                       try XCTUnwrap(refQWK(aI, bI, k: 2)), accuracy: 1e-9)
    }

    /// Differential alpha + proof it is TRUE alpha (coincidence (n..−1) denominator), not kappa.
    func testA14_Pre08_IndependentAlpha_DifferentialMatch_NotKappaInDisguise() throws {
        var rng = SplitMix64(seed: 0xA14_0808)
        for k in [2, 3, 5] {
            for n in [10, 37, 120] {
                let a = (0..<n).map { _ in rng.int(k) }
                let b = (0..<n).map { _ in rng.int(k) }
                let mine = refAlpha(a, b)
                let theirs = RWCStatisticsV1.krippendorffAlphaNominal(a: a, b: b)
                switch (mine, theirs) {
                case let (m?, t?): XCTAssertEqual(m, t, accuracy: 1e-9, "alpha mismatch k=\(k) n=\(n)")
                case (nil, nil): break
                default: XCTFail("degenerate-detection disagreement k=\(k) n=\(n)")
                }
            }
        }
        // hand fixture (independent): a=[0,1,1,0,1], b=[0,1,0,0,1] → alpha = 0.64 exactly
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.krippendorffAlphaNominal(a: [0, 1, 1, 0, 1], b: [0, 1, 0, 0, 1])),
                       0.64, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(refAlpha([0, 1, 1, 0, 1], [0, 1, 0, 0, 1])), 0.64, accuracy: 1e-12)
        // alpha ≠ kappa separation witness: systematic disagreement → kappa = −1 but alpha = −0.75
        // (the (n..−1) small-sample correction) — proves the implementation is not kappa in disguise.
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.krippendorffAlphaNominal(a: [0, 0, 1, 1], b: [1, 1, 0, 0])),
                       -0.75, accuracy: 1e-12)
        // perfect agreement on mixed classes → exactly 1
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.krippendorffAlphaNominal(a: [0, 1, 0, 1], b: [0, 1, 0, 1])),
                       1.0, accuracy: 1e-12)
    }

    /// Degenerate laws: nil (INSUFFICIENT_DATA), never 0/1-by-convention; out-of-scale refused.
    func testA14_Pre08_DegenerateLaws() throws {
        XCTAssertNil(RWCStatisticsV1.quadraticWeightedKappa(a: [], b: [], categories: 5))
        XCTAssertNil(RWCStatisticsV1.quadraticWeightedKappa(a: [3, 3, 3], b: [3, 3, 3], categories: 5),
                     "both-constant-same → pe=1 → nil, never 1.0")
        XCTAssertNil(RWCStatisticsV1.quadraticWeightedKappa(a: [0], b: [5], categories: 5), "out-of-scale refused")
        XCTAssertNil(RWCStatisticsV1.quadraticWeightedKappa(a: [0, 1], b: [0], categories: 5), "shape mismatch refused")
        XCTAssertNil(RWCStatisticsV1.krippendorffAlphaNominal(a: [], b: []))
        XCTAssertNil(RWCStatisticsV1.krippendorffAlphaNominal(a: [1, 1, 1], b: [1, 1, 1]), "single category → nil")
        XCTAssertNil(RWCStatisticsV1.wilson(successes: 5, n: 0))
        XCTAssertNil(RWCStatisticsV1.wilson(successes: 11, n: 10))
        XCTAssertNil(RWCStatisticsV1.zeroEventUpperBound95(n: 0))
        XCTAssertNil(RWCStatisticsV1.planningSampleSize(p: 0, halfWidth: 0.05))
        XCTAssertNil(RWCStatisticsV1.planningSampleSize(p: 0.5, halfWidth: 0))
        XCTAssertEqual(RWCStatisticsV1.bootstrapIndices(n: 0, draws: 5, seed: 1), [])
    }

    // ═══════════════ §24 FALSE-SAFE EXACT MATH ═══════════════

    /// Exact zero-event bound: UB(n) = 1 − 0.05^(1/n). Auditor recomputation: the MINIMAL n with
    /// UB ≤ 2% is 149 (UB(148) = 2.0038% fails; UB(149) = 1.9905% passes). The frozen requirement
    /// n ≥ 150 is therefore CONSERVATIVE-SAFE (sound; INFO only). Wilson differential included.
    func testA14_Pre09_ZeroEventExactMath_MinimalN149_Frozen150Conservative() throws {
        func ub(_ n: Int) -> Double { 1.0 - pow(0.05, 1.0 / Double(n)) }      // independent formula
        for n in [1, 10, 149, 150, 300, 1000] {
            XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.zeroEventUpperBound95(n: n)), ub(n), accuracy: 1e-15)
        }
        XCTAssertGreaterThan(ub(148), 0.02, "n=148 does NOT meet UB≤2%")
        XCTAssertLessThanOrEqual(ub(149), 0.02, "n=149 is the exact minimum for UB≤2%")
        XCTAssertLessThanOrEqual(ub(150), 0.02, "frozen sentinel law n≥150 is conservative-safe")
        // zero observed NEVER claims zero rate: the bound is strictly positive for every n
        XCTAssertGreaterThan(ub(1_000_000), 0)
        // Wilson differential (independent formula)
        func refWilson(_ s: Int, _ n: Int) -> (Double, Double) {
            let z = 1.959963984540054, p = Double(s) / Double(n), nn = Double(n), z2 = z * z
            let c = (p + z2 / (2 * nn)) / (1 + z2 / nn)
            let h = (z / (1 + z2 / nn)) * (p * (1 - p) / nn + z2 / (4 * nn * nn)).squareRoot()
            return (max(0, c - h), min(1, c + h))
        }
        for (s, n) in [(8, 10), (0, 150), (1, 400), (200, 400)] {
            let mine = refWilson(s, n), theirs = try XCTUnwrap(RWCStatisticsV1.wilson(successes: s, n: n))
            XCTAssertEqual(mine.0, theirs.lo, accuracy: 1e-12)
            XCTAssertEqual(mine.1, theirs.hi, accuracy: 1e-12)
        }
    }

    /// Planning-n reproduced independently: ceil(z²·p(1−p)/h²) → 385 (h=.05), 196 (h=.07).
    func testA14_Pre09_PlanningN_ReproducedIndependently() throws {
        func refN(_ p: Double, _ h: Double) -> Int {
            let z = 1.959963984540054
            return Int((z * z * p * (1 - p) / (h * h)).rounded(.up))
        }
        XCTAssertEqual(refN(0.5, 0.05), 385)
        XCTAssertEqual(refN(0.5, 0.07), 196)
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.planningSampleSize(p: 0.5, halfWidth: 0.05)), 385)
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.planningSampleSize(p: 0.5, halfWidth: 0.07)), 196)
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.planningSampleSize(p: 0.3, halfWidth: 0.05)), 323)
    }

    /// §19 bootstrap determinism + A14-F10 (PINNED, MEDIUM): the IRR gate text defines NO pass rule
    /// for the CI (point estimate vs CI-lower-bound) while the ECE gate explicitly says "point
    /// estimate". κ=.61 with CI [.30,.75] is UNDECIDABLE under the frozen text. Degenerate
    /// bootstrap replicates (nil kappa inside a replicate) and a valid-fraction minimum are
    /// likewise unspecified.
    func testA14_Pre08_BootstrapDeterminism_PINNED_F10_IRRCIRuleUndefined() throws {
        let b1 = RWCStatisticsV1.bootstrapIndices(n: 25, draws: 50, seed: 20261020)
        let b2 = RWCStatisticsV1.bootstrapIndices(n: 25, draws: 50, seed: 20261020)
        XCTAssertEqual(b1, b2, "seeded bootstrap deterministic")
        XCTAssertEqual(b1.count, 50)
        XCTAssertTrue(b1.allSatisfy { $0.count == 25 && $0.allSatisfy { (0..<25).contains($0) } })
        XCTAssertNotEqual(b1, RWCStatisticsV1.bootstrapIndices(n: 25, draws: 50, seed: 7))
        // a bootstrap replicate of constant-label resamples CAN be degenerate → nil kappa is real:
        XCTAssertNil(RWCStatisticsV1.quadraticWeightedKappa(a: [2, 2, 2, 2, 2], b: [2, 2, 2, 2, 2], categories: 5))
        // PINNED A14-F10: frozen IRR gates carry no point-vs-CI rule and no valid-fraction law
        let gates = try jsonObj("docs/calibration/preregistration/RWC_FROZEN_GATES.yaml")
        let fm = try XCTUnwrap(gates["frozen_metrics"] as? [String: Any])
        let irrO = try XCTUnwrap((fm["IRR_ordinal"] as? [String: Any])?["gate"] as? String)
        let irrS = try XCTUnwrap((fm["IRR_safety"] as? [String: Any])?["gate"] as? String)
        for t in [irrO, irrS] {
            XCTAssertTrue(t.lowercased().contains("lower bound"),
                          "A14-F10 FIXED (I-8): IRR gates pass ONLY on the 95% CI lower bound")
            XCTAssertTrue(t.contains("INSUFFICIENT_DATA"), "degenerate/valid-fraction law in the frozen gate text")
        }
        let eceCI = try XCTUnwrap((fm["risk_ECE"] as? [String: Any])?["ci"] as? String)
        XCTAssertTrue(eceCI.contains("point estimate"), "ECE DOES declare its rule — the asymmetry is the finding")
        let pre08 = try text("docs/calibration/preregistration/protocols/RWC_PRE08_IRR_METHODOLOGY.md")
        XCTAssertTrue(pre08.lowercased().contains("valid-fraction"),
                      "A14-F10 FIXED: degenerate-replicate / valid-fraction law present in PRE-08")
        XCTAssertTrue(pre08.contains("CI [.30,.75] => FAIL"), "kappa=.61 CI[.30,.75] now has ONE outcome: FAIL")
    }

    // ═══════════════ §21-§23 STATISTICAL FEASIBILITY ═══════════════

    /// A14-F7 (PINNED, MEDIUM): the frozen ECE ≤ .05 POINT-ESTIMATE gate at n=400 with 10 bins is
    /// NOISE-DOMINATED. Deterministic seeded Monte Carlo: a PERFECTLY calibrated model has
    /// E[ECE] ≈ .05 (binned |gap| aggregates pure sampling noise) and passes the gate only ~half
    /// the time. The PRE-09 planning computation (single-proportion n≥385 at h=.05) used the wrong
    /// statistic for a 10-bin ECE. The pass rule is explicit (point estimate) but statistically
    /// unsupported at n=400.
    func testA14_PINNED_F7_ECEGate_NoiseDominated_AtN400() throws {
        var rng = SplitMix64(seed: 0xECE_400)
        let trials = 600, n = 400, bins = 10
        var sumECE = 0.0, passes = 0
        for _ in 0..<trials {
            var count = [Double](repeating: 0, count: bins)
            var sumP = [Double](repeating: 0, count: bins)
            var sumY = [Double](repeating: 0, count: bins)
            for _ in 0..<n {
                let p = rng.double01()                       // uniform confidences
                let y = rng.double01() < p                   // PERFECT calibration by construction
                let i = min(bins - 1, Int(p * Double(bins))) // the frozen bin law
                count[i] += 1; sumP[i] += p; sumY[i] += y ? 1 : 0
            }
            var ece = 0.0
            for i in 0..<bins where count[i] > 0 {
                ece += (count[i] / Double(n)) * abs(sumP[i] / count[i] - sumY[i] / count[i])
            }
            sumECE += ece
            if ece <= 0.05 { passes += 1 }
        }
        let meanECE = sumECE / Double(trials)
        let passRate = Double(passes) / Double(trials)
        XCTAssertGreaterThan(meanECE, 0.040,
                             "PINNED A14-F7: E[ECE] of a PERFECT model at n=400 ≈ .05 — same magnitude as the gate")
        XCTAssertLessThan(meanECE, 0.065)
        XCTAssertLessThan(passRate, 0.75,
                          "PINNED A14-F7: a perfectly calibrated model passes the frozen gate only ~half the time")
        XCTAssertGreaterThan(passRate, 0.25)
    }

    /// A14-F8 (PINNED, MEDIUM): internal contradiction — PRE-10 defines POWERED = minimums met
    /// (default n ≥ 60), PRE-11 applies a HARD slice-ECE ≤ .07 gate to POWERED slices, yet PRE-09
    /// itself states h=.07 needs n ≈ 196. Deterministic Monte Carlo: at n=60 a PERFECT model has
    /// E[ECE] ≈ .13 and virtually never passes ≤ .07. "POWERED" at 60/15/15 is mislabeled —
    /// it is REPORTABLE, not powered for the frozen slice gate.
    func testA14_PINNED_F8_PoweredSliceGate_InternalContradiction() throws {
        // the contradiction triple, pinned from the frozen texts themselves:
        let pre10 = try text("docs/calibration/preregistration/protocols/RWC_PRE10_SLICES.md")
        XCTAssertTrue(pre10.contains("TRI-STATE POWER LAW"), "A14-F8 FIXED (I-6): tri-state law replaces the contradictory POWERED definition")
        let slices = try jsonObj("docs/calibration/preregistration/RWC_SLICE_DEFINITIONS.yaml")
        XCTAssertEqual(((slices["defaults"] as? [String: Any])?["min_n"] as? Int), 60)
        let pre09 = try text("docs/calibration/preregistration/protocols/RWC_PRE09_FEASIBILITY.md")
        XCTAssertTrue(pre09.contains("n >= ~196 is infeasible"), "PRE-09's own math: .07 needs ~196")
        let gates = try jsonObj("docs/calibration/preregistration/RWC_FROZEN_GATES.yaml")
        let sliceGate = try XCTUnwrap(((gates["frozen_metrics"] as? [String: Any])?["slice_ECE"] as? [String: Any]))
        XCTAssertTrue((sliceGate["gate"] as? String ?? "").contains("GATE_POWERED"),
                      "A14-F8 FIXED: hard slice gate applies ONLY to GATE_POWERED slices (n >= 800 power law)")
        XCTAssertTrue((sliceGate["scope"] as? String ?? "").contains("tri-state"),
                      "A14-F8 FIXED: REPORTABLE != gate-powered — the contradiction is deleted")
        // Monte Carlo at the POWERED minimum n=60: perfect model essentially cannot pass ≤ .07
        var rng = SplitMix64(seed: 0xECE_60)
        let trials = 600, n = 60, bins = 10
        var sumECE = 0.0, passes = 0
        for _ in 0..<trials {
            var count = [Double](repeating: 0, count: bins)
            var sumP = [Double](repeating: 0, count: bins)
            var sumY = [Double](repeating: 0, count: bins)
            for _ in 0..<n {
                let p = rng.double01()
                let y = rng.double01() < p
                let i = min(bins - 1, Int(p * Double(bins)))
                count[i] += 1; sumP[i] += p; sumY[i] += y ? 1 : 0
            }
            var ece = 0.0
            for i in 0..<bins where count[i] > 0 {
                ece += (count[i] / Double(n)) * abs(sumP[i] / count[i] - sumY[i] / count[i])
            }
            sumECE += ece
            if ece <= 0.07 { passes += 1 }
        }
        XCTAssertGreaterThan(sumECE / Double(trials), 0.10,
                             "PINNED A14-F8: E[ECE] of a PERFECT model at the POWERED minimum n=60 is ≈ .13")
        XCTAssertLessThan(Double(passes) / Double(trials), 0.10,
                          "PINNED A14-F8: the ≤.07 slice gate is essentially unpassable at n=60 — 'POWERED' is mislabeled")
    }

    /// A14-F9 (PINNED, MEDIUM — abstention gaming): NO coverage/decision-rate gate or
    /// abstention-rate bound exists anywhere in the frozen gates or slice registry. A model that
    /// abstains on every hard item inherits excellent ECE/MAE with zero accountability beyond
    /// "honestly reported".
    func testA14_PINNED_F9_NoCoverageGate_AbstentionGamingUnbounded() throws {
        let gatesRaw = try text("docs/calibration/preregistration/RWC_FROZEN_GATES.yaml").lowercased()
        XCTAssertTrue(gatesRaw.contains("never counted as success or failure"))
        // A14-F9 FIXED (inversion I-7): coverage accountability is a frozen gate.
        XCTAssertTrue(gatesRaw.contains("coverage"), "A14-F9 FIXED: coverage gate present in frozen gates")
        XCTAssertTrue(gatesRaw.contains("decision_coverage") || gatesRaw.contains("decision coverage"))
        XCTAssertTrue(gatesRaw.contains(">= 0.80"), "A14-F9 FIXED: in-distribution coverage bound frozen pre-data")
        let slicesRaw = try text("docs/calibration/preregistration/RWC_SLICE_DEFINITIONS.yaml").lowercased()
        XCTAssertTrue(slicesRaw.contains("abstention_rate"), "abstention_rate is REPORT-only in slices")
        XCTAssertTrue(slicesRaw.contains("decision_coverage"), "A14-F9 FIXED: per-slice decision coverage reported")
    }

    // ═══════════════ §26-§28 GATES/SLICES REGISTRIES ═══════════════

    /// AUROC/Brier REPORT-only everywhere; falseSafe/MAE gate shape; OOD routing law human-anchored.
    func testA14_Pre11_GateRegistry_ReportOnlyLaws_And_OODIndependence() throws {
        let gates = try jsonObj("docs/calibration/preregistration/RWC_FROZEN_GATES.yaml")
        XCTAssertEqual(gates["data_visibility_at_freeze"] as? Bool, false)
        let fm = try XCTUnwrap(gates["frozen_metrics"] as? [String: Any])
        XCTAssertTrue(((fm["AUROC"] as? [String: Any])?["gate"] as? String ?? "").hasPrefix("REPORT"))
        XCTAssertTrue(((fm["Brier"] as? [String: Any])?["gate"] as? String ?? "").hasPrefix("REPORT"))
        XCTAssertTrue(((fm["AUROC"] as? [String: Any])?["rationale"] as? String ?? "").contains("REJECTED"),
                      "FM-007 rejection documented")
        let fs = try XCTUnwrap((fm["falseSafe"] as? [String: Any])?["gate"] as? String)
        XCTAssertTrue(fs.contains("observed == 0") && fs.contains("0.02") && fs.contains("n>=150"))
        XCTAssertTrue(((fm["ordinal_MAE"] as? [String: Any])?["gate"] as? String ?? "").contains("0.80"))
        XCTAssertTrue(((fm["ordinal_MAE"] as? [String: Any])?["rationale"] as? String ?? "").contains("pre-data"),
                      "MAE rationale labeled as pre-data hypothesis")
        // OOD truth comes from the human handbook dimension (D-16), not from model prediction
        let ood = try XCTUnwrap((fm["OOD"] as? [String: Any])?["gate"] as? String)
        XCTAssertTrue(ood.contains("abstain") && ood.contains("finding"))
        let slices = try jsonObj("docs/calibration/preregistration/RWC_SLICE_DEFINITIONS.yaml")
        let list = try XCTUnwrap(slices["slices"] as? [[String: Any]])
        let oodSlice = try XCTUnwrap(list.first { ($0["id"] as? String) == "ood" })
        XCTAssertEqual(oodSlice["rule"] as? String, "D-16 positive", "OOD membership = HUMAN label, model-independent")
        // 4 rejected/modified candidates preserved with reasons
        XCTAssertGreaterThanOrEqual((gates["rejected_or_modified_candidates"] as? [[String: Any]])?.count ?? 0, 4)
    }

    /// §27/§28 — 21 slices, ids unique, every rule non-empty; sentinel/mixed minimums; and the
    /// PINNED absence of any multiple-comparison policy (A14-F18, LOW) across 21 overlapping slices.
    func testA14_Pre10_SliceRegistry_Complete_PINNED_F18_NoMultiplicityPolicy() throws {
        let slices = try jsonObj("docs/calibration/preregistration/RWC_SLICE_DEFINITIONS.yaml")
        let list = try XCTUnwrap(slices["slices"] as? [[String: Any]])
        XCTAssertEqual(list.count, 21)
        let ids = list.compactMap { $0["id"] as? String }
        XCTAssertEqual(Set(ids).count, 21, "slice ids unique")
        XCTAssertTrue(list.allSatisfy { !(($0["rule"] as? String) ?? "").isEmpty }, "every slice has a rule")
        XCTAssertEqual(try XCTUnwrap(list.first { ($0["id"] as? String) == "safety-sentinel" })["min_n"] as? Int, 150)
        XCTAssertEqual(try XCTUnwrap(list.first { ($0["id"] as? String) == "mixed-language" })["min_n"] as? Int, 40)
        // PINNED A14-F18: no family-wise / multiplicity statement anywhere in the frozen slice/gate texts
        let combined = (try text("docs/calibration/preregistration/RWC_SLICE_DEFINITIONS.yaml")
                        + (try text("docs/calibration/preregistration/RWC_FROZEN_GATES.yaml"))
                        + (try text("docs/calibration/preregistration/protocols/RWC_PRE10_SLICES.md"))).lowercased()
        XCTAssertTrue(combined.contains("family-wise") || combined.contains("multiplicity"),
                      "A14-F18 FIXED (I-12): explicit multiplicity policy (safety hard gates never averaged away)")
    }

    // ═══════════════ §32-§34 SPLIT/SEAL + §35-§38 DEVICE ═══════════════

    /// Seal laws present; A14-F11 (PINNED, LOW): what COUNTS as 'opening' HELD_OUT_FINAL (listing
    /// IDs? hash recomputation? metadata inspection? debug run?) is undefined, and no access-control
    /// / authorized-opener law exists. A14-F12 (PINNED, LOW): 'materially' is discretionary — no
    /// material vs non-material change matrix; post-opening revocation leaves the status of
    /// already-computed aggregates undefined.
    func testA14_Pre12_SealLaws_PINNED_F11_F12_OpeningAndMaterialityUnderdefined() throws {
        let seal = try text("docs/calibration/preregistration/protocols/RWC_PRE12_SPLIT_SEAL.md")
        for must in ["near-duplicate", "SHA-256 SEALED", "RUN-ONCE", "LOSES FINAL status",
                     "EMERGENCY INVALIDATION", "creator/series/template"] {
            XCTAssertTrue(seal.contains(must), "seal law missing: \(must)")
        }
        // PINNED A14-F11: opening is logged but never DEFINED; no authorized-opener/access law
        XCTAssertTrue(seal.contains("every opening event is logged"))
        let low = seal.lowercased()
        XCTAssertTrue(seal.contains("WHAT COUNTS AS OPENING"), "A14-F11 FIXED (I-10): opening act defined")
        XCTAssertTrue(seal.contains("AUTHORIZED OPENER"), "A14-F11 FIXED: opener authority + access law defined")
        // PINNED A14-F12: materiality is discretionary; computed-aggregate status after revocation absent
        // ("changes\nmaterially" wraps across a line in the frozen doc — normalize before matching)
        XCTAssertTrue(seal.replacingOccurrences(of: "\n", with: " ").contains("changes materially"))
        XCTAssertTrue(seal.contains("MATERIAL-CHANGE MATRIX") && seal.contains("NON-MATERIAL"),
                      "A14-F12 FIXED: material/non-material matrix defined — no discretionary loophole")
        XCTAssertTrue(seal.contains("NO LONGER VALID FINAL EVIDENCE"),
                      "A14-F12 FIXED: post-opening revocation aggregate law predefined (preserved, never deleted)")
    }

    /// Device protocol laws + A14-F16 (PINNED, LOW): the floor device is NOT concretely named
    /// anywhere (budgets say 'lowest supported device' without a model; certification matrix rows
    /// are NOT_TESTED), and every budget is UNSET_PENDING_BASELINE — so PRE-13 FAIL semantics
    /// ('any exceedance = FAIL') cannot bind yet; an explicit budget-freeze-before-RWC-DEVICE law
    /// is required to prevent post-measurement threshold setting.
    func testA14_Pre13_DeviceLaws_PINNED_F16_FloorUnnamed_BudgetsUnset() throws {
        let dev = try text("docs/calibration/preregistration/protocols/RWC_PRE13_DEVICE_EVIDENCE.md")
        for must in ["iPhone 14 Pro Max", "DEVICE_RESOURCE_BUDGETS", "release", "SEPARATE cell",
                     "UNKNOWN", "reports NOTHING yet", "simulator != physical device",
                     "build success != runtime proof", "p50/p95/p99", "10-minute sustained"] {
            XCTAssertTrue(dev.contains(must), "device law missing: \(must)")
        }
        let budgets = try text("docs/architecture/DEVICE_RESOURCE_BUDGETS.yaml")
        XCTAssertTrue(budgets.contains("lowest supported device"))
        XCTAssertTrue(budgets.contains("UNSET_PENDING_BASELINE"))
        XCTAssertFalse(budgets.lowercased().contains("floor_device:"),
                       "PINNED A14-F16: no concrete floor-device model is selected anywhere")
        // debug/release separation preserved BOTH directions (thermal-SERIOUS history)
        XCTAssertTrue(dev.contains("release logging stays structurally OFF"))
        XCTAssertTrue(dev.contains("can\nnever stand in for the release cell") ||
                      dev.contains("never stand in for the release cell"))
    }

    // ═══════════════ §39/§24 semantics + §42-§46 LOCKS ═══════════════

    /// A14-F17 (PINNED, LOW): the sentinel falseSafe bound is CONDITIONAL on sentinel-class content
    /// (targeted sampling, prevalence ≥ .80 by design) — it is NOT a natural-prevalence population
    /// false-safe rate, and no frozen artifact carries a report-semantics law making that
    /// distinction explicit.
    func testA14_PINNED_F17_SentinelConditionalSemantics_NoReportSemanticsLaw() throws {
        let pre09 = try text("docs/calibration/preregistration/protocols/RWC_PRE09_FEASIBILITY.md")
        XCTAssertTrue(pre09.contains("sentinel-targeted sampling"), "targeted sampling is declared")
        let all = (pre09 + (try text("docs/calibration/preregistration/RWC_FROZEN_GATES.yaml"))
                   + (try text("docs/calibration/preregistration/protocols/RWC_PRE10_SLICES.md"))).lowercased()
        XCTAssertTrue(all.contains("conditional on sentinel"),
                      "A14-F17 FIXED (I-11): sentinel-conditional report-semantics law present")
        XCTAssertTrue(all.contains("natural prevalence") || all.contains("natural-prevalence"),
                      "population-claim prohibition explicit")
    }

    /// §42 FAIL-evidence law: present, but PROCEDURAL (report prose + packet audit_requirements),
    /// not mechanical. §44 sequencing: packet chain 05→…→12 and terminal nodes → PRE-14 only.
    func testA14_FailEvidenceLaw_Procedural_And_SequencingPreserved() throws {
        let report = try text("docs/calibration/preregistration/RWC_PREREGISTRATION_PRE14_BUILDER_REPORT.md")
        XCTAssertTrue(report.contains("FAIL/FIX-class may NEVER count as satisfactory evidence"),
                      "FAIL-evidence law encoded (procedurally) in the builder report")
        let expectedNext: [String: String] = [
            "RWC-PRE-05": "RWC-PRE-06", "RWC-PRE-06": "RWC-PRE-07", "RWC-PRE-07": "RWC-PRE-08",
            "RWC-PRE-08": "RWC-PRE-09", "RWC-PRE-09": "RWC-PRE-10", "RWC-PRE-10": "RWC-PRE-11",
            "RWC-PRE-11": "RWC-PRE-12"]
        for (pid, next) in expectedNext {
            let p = try text("docs/calibration/preregistration/packets/\(pid).yaml")
            XCTAssertTrue(p.contains("next_allowed_node: \"\(next)\""), "\(pid) must chain to \(next)")
        }
        for terminal in ["RWC-PRE-01", "RWC-PRE-02", "RWC-PRE-03", "RWC-PRE-04", "RWC-PRE-12", "RWC-PRE-13"] {
            let p = try text("docs/calibration/preregistration/packets/\(terminal).yaml")
            XCTAssertTrue(p.contains("next_allowed_node: \"RWC-PRE-14 (gate)\""),
                          "\(terminal) must authorize ONLY the PRE-14 gate")
            XCTAssertTrue(p.contains("no real corpus acquisition"), "global forbidden-action law on \(terminal)")
            XCTAssertTrue(p.contains("builder cannot self-PASS"))
        }
    }

    /// §43/§45/§46 — production truths and locks: PRE-14 PASS must not auto-change ANY of these.
    func testA14_Locks_ProductionTruths_Unchanged() throws {
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0, "production score gate CLOSED")
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed(), "display stays OFF")
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims, "no real-world claim support")
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59, "engineering pairs unchanged (no corpus growth)")
        XCTAssertFalse(RealWorldCalibrationExecutorV1.preregistrationAuditPassed, "executor sealed until PRE-14 evidence commit")
        // fitting remains blocked even conceptually post-PRE-14: the fit body does not exist —
        // the executor source ends in the RWC-FIT refusal (no metrics code on the surface).
        let src = try text("packages/GuardianKit/Sources/GuardianCore/RealWorldCalibrationExecutorV1.swift")
        XCTAssertTrue(src.contains("fitPhaseNotAuthorized(requiredNode: \"RWC-FIT\")"))
        XCTAssertFalse(src.contains("eceAndBinsStrict("), "no fit/metric body exists on the executor yet")
    }
}
