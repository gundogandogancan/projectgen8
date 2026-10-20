import XCTest
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC PRE-14 R1 — fresh builder test family (ADDITIVE). Proves the FIXED contracts for the nine
// MEDIUM-labelled AUDIT14 rows + coupled LOWs with zero data. Quality over count.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class RWCPreregistrationR1Tests: XCTestCase {

    private var repoRoot: String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }
    private func text(_ rel: String) throws -> String { try String(contentsOfFile: repoRoot + "/" + rel, encoding: .utf8) }
    private func json(_ rel: String) throws -> [String: Any] {
        let d = try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + rel))
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: d) as? [String: Any])
    }
    private func rec(expiry: String? = nil, evidence: String = "rwc-rights-ref-r1-0001",
                     assetID: String = "rwc-asset-r1test01") -> RWCAssetRightsRecordV1 {
        RWCAssetRightsRecordV1(assetID: assetID, sourceClass: .licensedRightsClear,
                               sourceReference: "rwc-source-ref-r1-0001", owner: "gen8-project",
                               rightsHolder: "licensor-r1", licenseType: "lic", licenseEvidence: evidence,
                               allowedUse: ["training", "evaluation"], prohibitedUse: ["redistribution"],
                               trainingAllowed: true, evaluationAllowed: true, derivativeRights: "d",
                               redistributionAllowed: false, language: "tr", contentType: "video",
                               modality: "v", acquisitionDate: "2026-10-20", expiryDate: expiry,
                               revocationState: .active, revocationDate: nil,
                               contentHash: String(repeating: "cd", count: 32), provenanceChain: ["rwc-prov-r1"])
    }

    // ── F1/F2/F4: rights truth (expiry matrix via store asOf; resurrection; relicense) ──
    func testR1_ExpiryMatrix_StoreAsOfLaw() throws {
        let store = RWCAssetRightsLedgerStoreV1()
        try store.register(rec(expiry: "2027-06-30"), asOf: "2026-10-20")
        try store.requireEligible(assetID: "rwc-asset-r1test01", use: .training, asOf: "2027-06-30") // through
        XCTAssertThrowsError(try store.requireEligible(assetID: "rwc-asset-r1test01", use: .training, asOf: "2027-07-01")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .expired)
        }
        // asOf before acquisition refused; malformed asOf refused; future acquisition refused at register
        XCTAssertThrowsError(try store.requireEligible(assetID: "rwc-asset-r1test01", use: .training, asOf: "2026-10-19")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .acquisitionInFuture)
        }
        XCTAssertThrowsError(try store.requireEligible(assetID: "rwc-asset-r1test01", use: .training, asOf: "20261020")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .malformedDate(field: "asOf"))
        }
        let future = rec(assetID: "rwc-asset-r1test02")
        XCTAssertThrowsError(try store.register(future, asOf: "2026-10-19")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .acquisitionInFuture)
        }
        // record-internal: revocationDate before acquisition refused
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(
            RWCAssetRightsRecordV1(assetID: "rwc-asset-r1test03", sourceClass: .licensedRightsClear,
                                   sourceReference: "rwc-source-ref-x1", owner: "o", rightsHolder: "r",
                                   licenseType: "l", licenseEvidence: "rwc-rights-ref-x1",
                                   allowedUse: ["training", "evaluation"], prohibitedUse: [],
                                   trainingAllowed: true, evaluationAllowed: true, derivativeRights: "d",
                                   redistributionAllowed: false, language: "tr", contentType: "v", modality: "v",
                                   acquisitionDate: "2026-10-20", expiryDate: nil, revocationState: .active,
                                   revocationDate: "2026-10-19", contentHash: String(repeating: "cd", count: 32),
                                   provenanceChain: ["rwc-prov-1"]), use: "training")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .dateOrderViolation(rule: "revocation >= acquisition"))
        }
    }

    func testR1_Resurrection_And_LawfulRelicense() throws {
        let store = RWCAssetRightsLedgerStoreV1()
        try store.register(rec(), asOf: "2026-10-20")
        XCTAssertThrowsError(try store.register(rec(), asOf: "2026-10-21")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .duplicateRegistration)
        }
        try store.revoke(assetID: "rwc-asset-r1test01", onDate: "2026-11-01")
        XCTAssertThrowsError(try store.register(rec(), asOf: "2026-11-02")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .resurrectionRefused)
        }
        XCTAssertThrowsError(try store.reauthorize(rec(), asOf: "2026-11-02")) {
            XCTAssertEqual($0 as? RWCRightsErrorV1, .reauthorizationRequiresNewEvidence)
        }
        try store.reauthorize(rec(evidence: "rwc-rights-ref-r1-0002"), asOf: "2026-11-02")
        try store.requireEligible(assetID: "rwc-asset-r1test01", use: .evaluation, asOf: "2026-11-03")
        XCTAssertEqual(store.events.map(\.kind), ["registered", "revoked", "reauthorized"])
        XCTAssertEqual(Set(store.events.map(\.chainDigest)).count, 3, "append-only chain digests distinct")
    }

    // ── F5: grammar wired — valid order-independence + typed refusal taxonomy ──
    func testR1_PreparedDoor_GrammarAndOrderIndependence() throws {
        let ids = ["rwc-asset-aaaa1111#p-aa", "rwc-asset-bbbb2222#p-bb"]
        let tok = try CalibrationRunPreparationV1.prepareDataset(declaredIDs: ids, resolvedIDs: ids.reversed())
        XCTAssertEqual(tok.count, 2, "valid exact composites, order-independent")
        XCTAssertThrowsError(try CalibrationRunPreparationV1.prepareDataset(
            declaredIDs: ids, resolvedIDs: [ids[0], "rwc-asset-ABCD1111#p-bb"])) {
            guard case let .invalidRWCCompositeIDs(count, firstIndex, category)? = $0 as? CalibrationIntegrityErrorV1
            else { return XCTFail("typed grammar refusal") }
            XCTAssertEqual(count, 1); XCTAssertEqual(firstIndex, 1); XCTAssertTrue(category.hasSuffix(":resolved"))
        }
    }

    // ── F7: calibration methodology v2 — Type-I by construction + power, multi-seed (NOT the audit seed) ──
    func testR1_CalibrationDesign_TypeI_ByConstruction() throws {
        // null model: perfect calibration must pass ~95% across distributions and INDEPENDENT seeds
        for (kind, seedBase) in [("uniform", UInt64(771)), ("skewed", 772), ("clustered", 773)] {
            var passes = 0
            let trials = 40
            for s in 0..<trials {
                var rng = RWCSplitMix64(seed: seedBase &* 1000 &+ UInt64(s))
                let preds = RWCCalibrationMethodologyV1.confidences(kind, n: 800, rng: &rng)
                let labels = RWCCalibrationMethodologyV1.labels(for: preds, alternative: "null", rng: &rng)
                if RWCCalibrationMethodologyV1.decide(preds: preds, labels: labels,
                                                      seed: 99_000 &+ UInt64(s)).passed { passes += 1 }
            }
            XCTAssertGreaterThanOrEqual(passes, 32, "\(kind): perfect model must pass >=80% of trials (observed \(passes)/40; design target ~95%)")
        }
    }

    func testR1_CalibrationDesign_PowerAgainstMiscalibration() throws {
        // delta=.07 overconfidence at frozen n=800 must be caught with high probability
        for (kind, seedBase) in [("uniform", UInt64(881)), ("skewed", 882)] {
            var rejects = 0
            let trials = 40
            for s in 0..<trials {
                var rng = RWCSplitMix64(seed: seedBase &* 1000 &+ UInt64(s))
                let preds = RWCCalibrationMethodologyV1.confidences(kind, n: 800, rng: &rng)
                let labels = RWCCalibrationMethodologyV1.labels(for: preds, alternative: "over", rng: &rng)
                if !RWCCalibrationMethodologyV1.decide(preds: preds, labels: labels,
                                                       seed: 88_000 &+ UInt64(s)).passed { rejects += 1 }
            }
            XCTAssertGreaterThanOrEqual(rejects, 32, "\(kind): power >= 80% vs delta=.07 at n=800 (observed \(rejects)/40)")
        }
        // and the OLD failure mode is gone: at n=400 the null no longer auto-fails the TEST gate
        var rng = RWCSplitMix64(seed: 4242)
        let preds = RWCCalibrationMethodologyV1.confidences("uniform", n: 400, rng: &rng)
        let labels = RWCCalibrationMethodologyV1.labels(for: preds, alternative: "null", rng: &rng)
        let d = RWCCalibrationMethodologyV1.decide(preds: preds, labels: labels, seed: 4243)
        XCTAssertLessThan(abs(d.debiasedGap), 0.05, "debiasing removes the finite-sample bias the v1 gate ignored (null-mean subtraction)")
    }

    // ── F10: IRR decision law — the canonical ambiguity case is deterministic ──
    func testR1_IRRDecisionLaw_LowerBound_ValidFraction() throws {
        // strong agreement: lower bound clears .60 → PASS
        var a = [Int](), b = [Int]()
        var rng = RWCSplitMix64(seed: 505)
        for _ in 0..<120 { let v = Int(rng.next() % 5); a.append(v); b.append(rng.double01() < 0.9 ? v : max(0, v - 1)) }
        let strong = RWCCalibrationMethodologyV1.irrKappaDecision(a: a, b: b, categories: 5, threshold: 0.60)
        XCTAssertEqual(strong.decision, .pass)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(strong.ciLower), 0.60)
        // borderline point with wide CI → FAIL (κ=.61-style case can never pass on point alone)
        var a2 = [Int](), b2 = [Int]()
        for _ in 0..<55 { let v = Int(rng.next() % 5); a2.append(v); b2.append(rng.double01() < 0.62 ? v : Int(rng.next() % 5)) }
        let border = RWCCalibrationMethodologyV1.irrKappaDecision(a: a2, b: b2, categories: 5, threshold: 0.60)
        if let lo = border.ciLower, let pt = border.point {
            XCTAssertEqual(border.decision, lo >= 0.60 ? .pass : .fail,
                           "decision is EXACTLY the lower-bound rule (point \(pt), lo \(lo)) — no ambiguity")
        }
        // insufficient pairs → INSUFFICIENT_DATA
        XCTAssertEqual(RWCCalibrationMethodologyV1.irrKappaDecision(a: [0, 1], b: [0, 1], categories: 5,
                                                                    threshold: 0.6).decision, .insufficientData)
        // high-degeneracy data (near-constant) → degenerate point → INSUFFICIENT_DATA
        XCTAssertEqual(RWCCalibrationMethodologyV1.irrKappaDecision(a: [Int](repeating: 2, count: 60),
                                                                    b: [Int](repeating: 2, count: 60),
                                                                    categories: 5, threshold: 0.6).decision,
                       .insufficientData)
    }

    // ── F9: coverage accountability — gaming attack ──
    func testR1_CoverageLaw_AbstentionGamingBlocked() throws {
        // a model abstaining on 40% of in-distribution items violates the frozen coverage gate
        let gamed = RWCCalibrationMethodologyV1.coverage(inDistDecided: 480, inDistTotal: 800,
                                                         oodAbstained: 50, oodTotal: 50,
                                                         sentinelProtective: 150, sentinelDecided: 0, sentinelTotal: 150)
        XCTAssertLessThan(gamed.decisionCoverage, RWCCalibrationMethodologyV1.frozenMinDecisionCoverage,
                          "excellent-ECE-via-abstention cannot reach a counting PASS")
        XCTAssertEqual(gamed.oodAbstentionRate, 1.0, "OOD abstention is EXPECTED and separately reported")
        XCTAssertEqual(gamed.sentinelProtectiveRate, 1.0)
        XCTAssertEqual(gamed.sentinelExplicitDecisionRate, 0.0,
                       "100% sentinel abstention is visible — protective but NEVER evidence of understanding")
        let honest = RWCCalibrationMethodologyV1.coverage(inDistDecided: 700, inDistTotal: 800,
                                                          oodAbstained: 48, oodTotal: 50,
                                                          sentinelProtective: 150, sentinelDecided: 120, sentinelTotal: 150)
        XCTAssertGreaterThanOrEqual(honest.decisionCoverage, 0.80)
    }

    // ── F13: freeze v2 + corpus entry guard (window law, machine form) ──
    func testR1_FreezeV2_HashesAndMethodologyBoundary() throws {
        let v2 = try json("docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V2.yaml")
        XCTAssertEqual(v2["supersedes"] as? String, "rwc-prereg-freeze-v1")
        XCTAssertTrue((v2["pre_data_declaration"] as? String ?? "").contains("NO REAL CORPUS RESULTS"))
        let arts = try XCTUnwrap(v2["artifacts"] as? [[String: Any]])
        XCTAssertTrue(arts.contains { ($0["path"] as? String)?.hasSuffix(".swift") == true },
                      "methodology CODE inside the freeze boundary")
        XCTAssertFalse((v2["freeze_candidate_commit"] as? String ?? "").isEmpty, "commit-level binding recorded")
        for a in arts {
            let path = try XCTUnwrap(a["path"] as? String)
            let want = try XCTUnwrap(a["sha256"] as? String)
            let data = try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + path))
            XCTAssertEqual(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), want,
                           "freeze v2 drift: \(path)")
        }
        // v1 preserved untouched as the FAILED candidate's historical record
        let v1 = try json("docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST.yaml")
        XCTAssertEqual((v1["artifacts"] as? [[String: Any]])?.count, 15)
    }

    func testR1_CorpusEntryGuard_WindowLaw() throws {
        let hashes = ["a": "h1", "b": "h2"]
        let good = RWCCorpusEntryGuardV1.StateV1(pre14Verdict: "PASS", currentFrozenHashes: hashes,
                                                 auditedFrozenHashes: hashes, freezeVersion: "v2",
                                                 auditedFreezeVersion: "v2", dataVisibility: 0,
                                                 postAuditMethodologyDrift: false)
        XCTAssertNoThrow(try RWCCorpusEntryGuardV1.requireEntry(good))
        XCTAssertThrowsError(try RWCCorpusEntryGuardV1.requireEntry(
            RWCCorpusEntryGuardV1.StateV1(pre14Verdict: "FIX REQUIRED", currentFrozenHashes: hashes,
                                          auditedFrozenHashes: hashes, freezeVersion: "v2",
                                          auditedFreezeVersion: "v2", dataVisibility: 0,
                                          postAuditMethodologyDrift: false))) {
            XCTAssertEqual($0 as? RWCCorpusEntryGuardV1.EntryErrorV1, .pre14NotPassed("FIX REQUIRED"))
        }
        XCTAssertThrowsError(try RWCCorpusEntryGuardV1.requireEntry(
            RWCCorpusEntryGuardV1.StateV1(pre14Verdict: "PASS", currentFrozenHashes: ["a": "h1", "b": "DRIFTED"],
                                          auditedFrozenHashes: hashes, freezeVersion: "v2",
                                          auditedFreezeVersion: "v2", dataVisibility: 0,
                                          postAuditMethodologyDrift: false))) {
            XCTAssertEqual($0 as? RWCCorpusEntryGuardV1.EntryErrorV1, .frozenHashDrift(path: "b"))
        }
        XCTAssertThrowsError(try RWCCorpusEntryGuardV1.requireEntry(
            RWCCorpusEntryGuardV1.StateV1(pre14Verdict: "PASS", currentFrozenHashes: hashes,
                                          auditedFrozenHashes: hashes, freezeVersion: "v3",
                                          auditedFreezeVersion: "v2", dataVisibility: 0,
                                          postAuditMethodologyDrift: false))) {
            XCTAssertEqual($0 as? RWCCorpusEntryGuardV1.EntryErrorV1, .freezeVersionMismatch)
        }
    }

    // ── F15 protective law + discipline + zero-data ──
    func testR1_ProtectiveAnnotationLaw() throws {
        XCTAssertEqual(RWCAnnotationLawV1.finalLabel(a: 1, b: 2, adjudicated: nil), .adjudicationRequired,
                       "protection-boundary disagreement can NEVER be resolved arithmetically")
        XCTAssertEqual(RWCAnnotationLawV1.finalLabel(a: 0, b: 1, adjudicated: nil), .label(0),
                       "same-class disagreement resolves to the MORE protective value")
        XCTAssertEqual(RWCAnnotationLawV1.finalLabel(a: 3, b: 4, adjudicated: nil), .label(3))
        XCTAssertEqual(RWCAnnotationLawV1.finalLabel(a: 0, b: 4, adjudicated: 1), .label(1), "adjudication wins")
        // legacy engineering type untouched (AUDIT pins)
        XCTAssertEqual(CalibrationAnnotationV1(itemID: "i", profileID: "p", locale: "tr",
                                               labelA: 1, labelB: 2).finalLabel, 2)
    }

    func testR1_Discipline_FrozenOriginalAndErratum() throws {
        let frozen = try Data(contentsOf: URL(fileURLWithPath:
            repoRoot + "/docs/audit/AUDIT14_RWCPreregistrationPre14Probes_ORIGINAL_LOCKED.swift.txt"))
        XCTAssertEqual(SHA256.hash(data: frozen).map { String(format: "%02x", $0) }.joined(),
                       "18ac2633dd55e6073cf80be309db75af3f07c96a2bedd62cf8a360c246186886")
        let frozenSrc = String(decoding: frozen, as: UTF8.self)
        let active = try text("packages/GuardianKit/Tests/GuardianCoreTests/AUDIT14_RWCPreregistrationPre14Probes.swift")
        for marker in ["A14-F1 FIXED", "A14-F2", "A14-F4 FIXED", "A14-F5 FIXED", "A14-F8 FIXED",
                       "A14-F9 FIXED", "A14-F10 FIXED", "A14-F13 FIXED", "A14-F14 FIXED"] {
            XCTAssertTrue(active.contains(marker), "declared inversion present: \(marker)")
        }
        for retired in ["PINNED A14-F1: ACTIVE + past expiry PASSES",
                        "PINNED A14-F5: RWC-INVALID identity",
                        "PINNED A14-F9: no coverage gate in frozen gates"] {
            XCTAssertFalse(active.contains(retired), "retired pin gone: \(retired)")
            XCTAssertTrue(frozenSrc.contains(retired), "retired pin preserved in frozen original")
        }
        XCTAssertTrue(try text("docs/audit/AUDIT14_FINDING_COUNT_ERRATUM.md").contains("NINE MEDIUM-labelled rows"))
        // NOT-inverted characterization survives (F7 MC permanent negative evidence)
        XCTAssertTrue(active.contains("PINNED A14-F7"), "F7 Monte-Carlo stays as permanent negative evidence")
    }

    func testR1_ZeroData_AndLocks() throws {
        let m = try json("docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml")
        XCTAssertEqual(m["corpus_count"] as? Int, 0); XCTAssertEqual(m["annotator_count"] as? Int, 0)
        XCTAssertEqual(m["real_fit_count"] as? Int, 0); XCTAssertEqual(m["heldout_open_count"] as? Int, 0)
        XCTAssertEqual(m["data_visibility"] as? Bool, false)
        XCTAssertEqual(m["candidate_generation"] as? String, "R1")
        XCTAssertTrue((m["rwc_fit_binding_invariant"] as? String ?? "").contains("PreparedCalibrationDatasetV2"),
                      "A14-F6 payload-binding invariant recorded as a binding RWC-FIT prerequisite")
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims)
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59)
        XCTAssertFalse(RealWorldCalibrationExecutorV1.preregistrationAuditPassed)
        XCTAssertTrue(try text("docs/calibration/preregistration/RWC_PREREGISTRATION_R1_CHANGE_LEDGER.md")
            .contains("NO REAL CORPUS"))
    }
}
