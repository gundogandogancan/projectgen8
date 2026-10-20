import XCTest
import CryptoKit
@testable import GuardianCore

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC PREREGISTRATION (PRE-01..13) — builder test family. Proves the preregistration laws with
// ZERO data: no corpus, no annotators, no fitting, no held-out. Quality over count.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

final class RWCPreregistrationTests: XCTestCase {

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

    // ═══════ PRE-02: asset identity adversarial matrix (A11-IDCHARSET / A11-COMPOSITE-ALIAS) ═══════

    func testPre02_AssetIDGrammar_AdversarialMatrix() throws {
        XCTAssertNil(RWCAssetIdentityV1.validateAssetID("rwc-asset-a1b2c3d4"), "minimal valid")
        XCTAssertNil(RWCAssetIdentityV1.validateAssetID("rwc-asset-" + String(repeating: "z9", count: 16)), "max valid")
        // A11-IDCHARSET closure: newline/tab/space/control are TYPED refusals, never silently fixed
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("\n"), .controlOrWhitespace(index: 0))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-a1b2c3d4\n"), .controlOrWhitespace(index: 18))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-a1b2\tc3d4"), .controlOrWhitespace(index: 14))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID(" rwc-asset-a1b2c3d4"), .controlOrWhitespace(index: 0))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("   "), .controlOrWhitespace(index: 0))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID(""), .empty)
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-a\u{07}bcdefgh"), .controlOrWhitespace(index: 11))
        // A11-COMPOSITE-ALIAS closure: '#' forbidden in components
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-ab#cdefgh"), .separatorForbidden(index: 12))
        XCTAssertEqual(RWCAssetIdentityV1.validateProfileID("adult#neutral"), .separatorForbidden(index: 5))
        // Unicode law: NO normalization — NFC/NFD and lookalikes refused, not repaired
        XCTAssertNotNil(RWCAssetIdentityV1.validateAssetID("rwc-asset-caf\u{00E9}1234"), "NFC e-acute refused")
        XCTAssertNotNil(RWCAssetIdentityV1.validateAssetID("rwc-asset-cafe\u{0301}1234"), "NFD combining refused")
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-\u{0430}bcdefgh"), .nonASCII(index: 10), "Cyrillic 'a' lookalike refused")
        // case law: lowercase-only; uppercase is a typed refusal (comparison therefore byte-exact)
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-A1b2c3d4"), .forbiddenCharacter(index: 10))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("RWC-ASSET-a1b2c3d4"), .badPrefix)
        // length law
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-a1b2c3d"), .badLength(actual: 7, minimum: 8, maximum: 32))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("rwc-asset-" + String(repeating: "a", count: 33)),
                       .badLength(actual: 33, minimum: 8, maximum: 32))
        XCTAssertEqual(RWCAssetIdentityV1.validateAssetID("asset-a1b2c3d4"), .badPrefix)
    }

    func testPre02_CompositeIdentity_CollisionSafe() throws {
        let c = try RWCAssetIdentityV1.composite(assetID: "rwc-asset-a1b2c3d4", profileID: "parent-teen14-tr")
        XCTAssertEqual(c, "rwc-asset-a1b2c3d4#parent-teen14-tr")
        XCTAssertEqual(c.filter { $0 == "#" }.count, 1, "exactly one separator by construction")
        let p = try RWCAssetIdentityV1.parseComposite(c)
        XCTAssertEqual(p.assetID, "rwc-asset-a1b2c3d4"); XCTAssertEqual(p.profileID, "parent-teen14-tr")
        // aliasing attack shapes all refuse (## / embedded separator / zero separator)
        XCTAssertThrowsError(try RWCAssetIdentityV1.parseComposite("rwc-asset-a1b2c3d4##p"))
        XCTAssertThrowsError(try RWCAssetIdentityV1.parseComposite("rwc-asset-a1b2c3d4"))
        XCTAssertThrowsError(try RWCAssetIdentityV1.composite(assetID: "rwc-asset-a#b2c3d4e", profileID: "p-x1"))
        // same-count substitution remains refused downstream by guard v2 (exact identity law):
        XCTAssertThrowsError(try CalibrationRunGuardV1.requireFullResolution(
            declaredIDs: ["rwc-asset-a1b2c3d4#p-aa", "rwc-asset-b1b2c3d4#p-aa"],
            resolvedIDs: ["rwc-asset-a1b2c3d4#p-aa", "rwc-asset-x1b2c3d4#p-aa"]))
    }

    // ═══════ PRE-01: rights ledger fail-closed eligibility + revocation ═══════

    private func record(source: RWCSourceClassV1 = .licensedRightsClear, training: Bool = true,
                        eval: Bool = true, state: RWCRevocationStateV1 = .active,
                        hash: String = String(repeating: "ab", count: 32),
                        evidence: String = "rights-evidence-ptr-001") -> RWCAssetRightsRecordV1 {
        RWCAssetRightsRecordV1(assetID: "rwc-asset-a1b2c3d4", sourceClass: source,
                               sourceReference: "secure-store-ptr-001", owner: "gen8-project",
                               rightsHolder: "licensor-001", licenseType: "evaluation+training-license",
                               licenseEvidence: evidence, allowedUse: ["training", "evaluation"],
                               prohibitedUse: ["redistribution"], trainingAllowed: training,
                               evaluationAllowed: eval, derivativeRights: "derived-metrics-only",
                               redistributionAllowed: false, language: "tr", contentType: "video",
                               modality: "video+audio", acquisitionDate: "2026-10-20", expiryDate: nil,
                               revocationState: state, revocationDate: nil, contentHash: hash,
                               provenanceChain: ["licensor-transfer-001"])
    }

    func testPre01_EligibilityFailClosed() throws {
        try RWCAssetRightsLedgerV1.requireEligible(record(), use: "training")        // happy path
        // every refused source class is ineligible
        for bad in [RWCSourceClassV1.refusedScraped, .refusedPrivateCapture, .refusedUserPrivate, .refusedUnknownLicense] {
            XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(record(source: bad), use: "training")) { e in
                XCTAssertEqual(e as? RWCRightsErrorV1, .ineligibleSourceClass(bad))
            }
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(record(evidence: "  "), use: "training")) { e in
            XCTAssertEqual(e as? RWCRightsErrorV1, .missingLicenseEvidence)
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(record(training: false), use: "training")) { e in
            XCTAssertEqual(e as? RWCRightsErrorV1, .useNotAllowed(use: "training"))
        }
        // UNKNOWN use never passes (fail closed)
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(record(), use: "marketing")) { e in
            XCTAssertEqual(e as? RWCRightsErrorV1, .useNotAllowed(use: "marketing"))
        }
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(record(hash: "short"), use: "evaluation")) { e in
            XCTAssertEqual(e as? RWCRightsErrorV1, .invalidContentHash)
        }
        // bad asset ID propagates the typed identity error (opaque-ID law end-to-end)
        XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(
            RWCAssetRightsRecordV1(assetID: "funny cat video.mp4", sourceClass: .licensedRightsClear,
                                   sourceReference: "x", owner: "o", rightsHolder: "r", licenseType: "l",
                                   licenseEvidence: "e", allowedUse: [], prohibitedUse: [], trainingAllowed: true,
                                   evaluationAllowed: true, derivativeRights: "d", redistributionAllowed: false,
                                   language: "en", contentType: "video", modality: "v", acquisitionDate: "2026-10-20",
                                   expiryDate: nil, revocationState: .active, revocationDate: nil,
                                   contentHash: String(repeating: "ab", count: 32), provenanceChain: ["p"]),
            use: "evaluation"))
    }

    func testPre01_RevocationMonotone() throws {
        let revoked = RWCAssetRightsLedgerV1.revoked(record(), onDate: "2026-11-01")
        XCTAssertEqual(revoked.revocationState, .revoked)
        XCTAssertFalse(revoked.trainingAllowed); XCTAssertFalse(revoked.evaluationAllowed)
        XCTAssertFalse(revoked.redistributionAllowed)
        XCTAssertTrue(revoked.provenanceChain.contains("revocation-recorded"), "audit trail retained")
        for use in ["training", "evaluation"] {
            XCTAssertThrowsError(try RWCAssetRightsLedgerV1.requireEligible(revoked, use: use)) { e in
                XCTAssertEqual(e as? RWCRightsErrorV1, .revoked)
            }
        }
        XCTAssertTrue((try json("docs/calibration/preregistration/RWC_ASSET_RIGHTS_LEDGER_SCHEMA.yaml")["records"] as? [Any])?.isEmpty ?? false,
                      "ZERO assets registered — corpus_count=0 is load-bearing")
    }

    // ═══════ PRE-03: legacy retirement (behavior unchanged; real-world entry impossible) ═══════

    func testPre03_LegacyEngineeringOnly_RealWorldCannotEnter() throws {
        // type-level law: the ONLY expressible context case is .engineeringLab
        XCTAssertEqual("\(EngineeringOnlyExecutionContextV1.engineeringLab)", "engineeringLab")
        // source law: the real-world executor references ZERO pilot types (bridgeless type worlds)
        let executorSrc = try text("packages/GuardianKit/Sources/GuardianCore/RealWorldCalibrationExecutorV1.swift")
        for pilotType in ["PilotExample", "CalibrationPilotRunner", "LogisticCalibrator", "CalibrationMetrics."] {
            XCTAssertFalse(executorSrc.contains(pilotType), "real-world surface must not reference \(pilotType)")
        }
        // deprecation markers present; historical negative evidence intact (AUDIT11 pins stay green)
        let pilotSrc = try text("packages/GuardianKit/Sources/GuardianCore/CalibrationPilot.swift")
        XCTAssertTrue(pilotSrc.contains("ENGINEERING_ONLY forever"))
        XCTAssertTrue(pilotSrc.contains("@available(*, deprecated"))
        XCTAssertTrue(pilotSrc.contains("NT-P008-PILOT-FAILED"))
        let metricsSrc = try text("packages/GuardianKit/Sources/GuardianCore/CalibrationMetrics.swift")
        XCTAssertTrue(metricsSrc.contains("@available(*, deprecated"))
        // legacy pinned behavior UNCHANGED (AUDIT11 law): mae truncation + silent-NaN ece still legacy
        XCTAssertEqual(CalibrationMetrics.mae(predicted: [0.9, 0.1], truth: [0.9]), 0.0, accuracy: 1e-12)
    }

    // ═══════ PRE-04: structural executor gate (A11-F2-APIBYPASS closure) ═══════

    func testPre04_PreparedDatasetSingleDoor_BypassImpossible() throws {
        // the ONLY door: prepareDataset. Full resolution → token exists.
        let ids = ["rwc-asset-a1b2c3d4#p-aa", "rwc-asset-b2c3d4e5#p-aa"]
        let prepared = try CalibrationRunPreparationV1.prepareDataset(declaredIDs: ids, resolvedIDs: ids.reversed())
        XCTAssertEqual(prepared.count, 2)
        XCTAssertEqual(prepared.guardRevision, "calibration-run-guard-v2", "token carries guard provenance")
        // every integrity violation → NO token ever exists (executor unreachable by construction)
        XCTAssertThrowsError(try CalibrationRunPreparationV1.prepareDataset(declaredIDs: ids, resolvedIDs: [ids[0]]))
        XCTAssertThrowsError(try CalibrationRunPreparationV1.prepareDataset(declaredIDs: ids + [ids[0]], resolvedIDs: ids + [ids[0]]))
        XCTAssertThrowsError(try CalibrationRunPreparationV1.prepareDataset(declaredIDs: ids, resolvedIDs: ids + ["rwc-asset-zzzz9999#p-aa"]))
        XCTAssertThrowsError(try CalibrationRunPreparationV1.prepareDataset(declaredIDs: ["", ids[0]], resolvedIDs: ["", ids[0]]))
        // @testable exposes internal — NOT fileprivate: no init is visible here. The following line
        // DOES NOT COMPILE (verified at authoring; kept as documentation of the structural law):
        //   let forged = PreparedCalibrationDatasetV1(compositeIDs: ids, category: "x")
        // raw-record injection impossible: no API converts arrays/pairs into the token.
        // DOUBLE REFUSAL LAW: even a valid token cannot execute until PRE-14 PASS…
        XCTAssertFalse(RealWorldCalibrationExecutorV1.preregistrationAuditPassed)
        XCTAssertThrowsError(try RealWorldCalibrationExecutorV1.execute(prepared)) { e in
            XCTAssertEqual(e as? RWCExecutorErrorV1, .preregistrationNotPassed(requiredGate: "RWC-PRE-14"))
        }
        // …and the empty token is its own typed refusal
        let empty = try CalibrationRunPreparationV1.prepareDataset(declaredIDs: [], resolvedIDs: [])
        XCTAssertThrowsError(try RealWorldCalibrationExecutorV1.execute(empty)) { e in
            XCTAssertEqual(e as? RWCExecutorErrorV1, .emptyDataset)
        }
    }

    // ═══════ PRE-05: handbook TR/EN structural parity ═══════

    func testPre05_HandbookParityAndCompleteness() throws {
        let en = try text("docs/calibration/preregistration/handbook/RWC_ANNOTATION_HANDBOOK_v1_EN.md")
        let tr = try text("docs/calibration/preregistration/handbook/RWC_ANNOTATION_HANDBOOK_v1_TR.md")
        func sections(_ s: String) -> [String] {
            s.components(separatedBy: "\n").filter { $0.hasPrefix("## [D-") }
                .compactMap { $0.components(separatedBy: "]").first?.replacingOccurrences(of: "## [", with: "") }
        }
        let enIDs = sections(en), trIDs = sections(tr)
        XCTAssertEqual(enIDs, trIDs, "TR/EN section IDs identical and ordered — semantic-parity law")
        XCTAssertEqual(enIDs.count, 17)
        // all mandated dimensions present via their slugs
        for slug in ["ordinal-suitability", "strong-protection", "violence-gore", "sexual-sensitive",
                     "fear-threat", "manipulation", "benefit-educational", "news-documentary",
                     "mixed-language", "satire-sarcasm", "quoted-ambiguous", "h1-unavailable",
                     "age-interpretation", "shield-interpretation", "abstention", "ood", "safety-sentinel"] {
            XCTAssertTrue(en.contains("(\(slug))"), "EN missing \(slug)")
            XCTAssertTrue(tr.contains("(\(slug))"), "TR missing \(slug)")
        }
        // per-dimension required fields (7 bullets per section in both languages)
        XCTAssertEqual(en.components(separatedBy: "- **Definition:**").count - 1, 17)
        XCTAssertEqual(tr.components(separatedBy: "- **Tanim:**").count - 1, 17)
        XCTAssertEqual(en.components(separatedBy: "- **Abstain rule:**").count - 1, 17)
        XCTAssertEqual(tr.components(separatedBy: "- **Cekimserlik kurali:**").count - 1, 17)
        XCTAssertTrue(en.contains("RWC-ANNOTATION-HANDBOOK-v1") && tr.contains("RWC-ANNOTATION-HANDBOOK-v1"))
    }

    // ═══════ PRE-06/07: isolation + adjudication schema laws ═══════

    func testPre0607_IsolationAndAdjudicationLaws() throws {
        let iso = try text("docs/calibration/preregistration/protocols/RWC_PRE06_ANNOTATOR_ISOLATION.md")
        for must in ["BLINDNESS MATRIX", "model prediction", "split identity", "sentinels are indistinguishable",
                     "append-only", "opaque operational IDs", "no quotas"] {
            XCTAssertTrue(iso.contains(must), "isolation law missing: \(must)")
        }
        let adj = try text("docs/calibration/preregistration/protocols/RWC_PRE07_ADJUDICATION.md")
        for must in ["REQUIRED when |A-B| >= 2", "NEVER rewritten", "third layer", "UNRESOLVED_AMBIGUOUS",
                     "safety-disagreement event"] {
            XCTAssertTrue(adj.contains(must), "adjudication law missing: \(must)")
        }
        // engineering precedent anchor: the annotation type already keeps A/B/adjudicated separate
        let ann = CalibrationAnnotationV1(itemID: "x", profileID: "p", locale: "tr", labelA: 1, labelB: 3, adjudicated: 2)
        XCTAssertEqual(ann.labelA, 1); XCTAssertEqual(ann.labelB, 3); XCTAssertEqual(ann.finalLabel, 2)
    }

    // ═══════ PRE-08/09: statistics — hand-verified fixtures + degenerate laws ═══════

    func testPre08_KappaAlpha_HandVerified() throws {
        // perfect agreement → kappa 1; independent-looking disagreement → below 1; degenerate → nil
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.quadraticWeightedKappa(a: [0, 1, 2, 3, 4], b: [0, 1, 2, 3, 4], categories: 5)), 1.0, accuracy: 1e-12)
        // hand-computed 2-category fixture: a=[0,0,1,1], b=[0,1,1,1] (k=2 quadratic == plain kappa)
        // po_w: matches 3/4 with w=1, one (0,1) mismatch w=0 → po=.75; pe = .5*.75+.5*.25 = .5 → kappa=.5
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.quadraticWeightedKappa(a: [0, 0, 1, 1], b: [0, 1, 1, 1], categories: 2)), 0.5, accuracy: 1e-12)
        XCTAssertNil(RWCStatisticsV1.quadraticWeightedKappa(a: [2, 2, 2], b: [2, 2, 2], categories: 5),
                     "degenerate marginals → INSUFFICIENT_DATA (nil), never 1.0 by convention")
        XCTAssertNil(RWCStatisticsV1.quadraticWeightedKappa(a: [], b: [], categories: 5))
        XCTAssertNil(RWCStatisticsV1.quadraticWeightedKappa(a: [0, 9], b: [0, 1], categories: 5), "out-of-scale refused")
        // Krippendorff alpha, hand-checked: perfect agreement on mixed classes → 1.0
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.krippendorffAlphaNominal(a: [0, 1, 0, 1], b: [0, 1, 0, 1])), 1.0, accuracy: 1e-12)
        // single-category data → undefined → nil (typed INSUFFICIENT_DATA upstream)
        XCTAssertNil(RWCStatisticsV1.krippendorffAlphaNominal(a: [1, 1, 1], b: [1, 1, 1]))
        // systematic disagreement is worse than chance → alpha < 0
        let alpha = try XCTUnwrap(RWCStatisticsV1.krippendorffAlphaNominal(a: [0, 0, 1, 1], b: [1, 1, 0, 0]))
        XCTAssertLessThan(alpha, 0)
    }

    func testPre09_FeasibilityMath_HandVerified() throws {
        // rule of three: exact zero-event 95% UB; n=150 → ~1.98%, n=300 → ~0.99% (frozen sentinel law)
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.zeroEventUpperBound95(n: 150)), 0.0197, accuracy: 0.0005)
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.zeroEventUpperBound95(n: 300)), 0.0099, accuracy: 0.0003)
        XCTAssertNil(RWCStatisticsV1.zeroEventUpperBound95(n: 0))
        // planning n for h=.05 at p=.5 → 385 (the ">=400 pool" freeze is a round-up of this)
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.planningSampleSize(p: 0.5, halfWidth: 0.05)), 385)
        XCTAssertEqual(try XCTUnwrap(RWCStatisticsV1.planningSampleSize(p: 0.5, halfWidth: 0.07)), 196)
        // Wilson: textbook check 8/10 → (0.49, 0.94) approximately
        let w = try XCTUnwrap(RWCStatisticsV1.wilson(successes: 8, n: 10))
        XCTAssertEqual(w.lo, 0.49, accuracy: 0.02); XCTAssertEqual(w.hi, 0.945, accuracy: 0.02)
        // seeded bootstrap is deterministic (same seed → same indices) and in-range
        let b1 = RWCStatisticsV1.bootstrapIndices(n: 10, draws: 3, seed: 20261020)
        let b2 = RWCStatisticsV1.bootstrapIndices(n: 10, draws: 3, seed: 20261020)
        XCTAssertEqual(b1, b2)
        XCTAssertTrue(b1.allSatisfy { $0.allSatisfy { (0..<10).contains($0) } })
        XCTAssertNotEqual(b1, RWCStatisticsV1.bootstrapIndices(n: 10, draws: 3, seed: 7))
    }

    // ═══════ PRE-10/11/12/13: frozen registries + laws ═══════

    func testPre1011_SlicesAndFrozenGates() throws {
        let slices = try json("docs/calibration/preregistration/RWC_SLICE_DEFINITIONS.yaml")
        let list = try XCTUnwrap(slices["slices"] as? [[String: Any]])
        XCTAssertEqual(list.count, 21)
        for required in ["lang-tr", "lang-en", "profile-child", "profile-teen", "profile-adult", "shield-on",
                         "shield-off", "dim-violence", "dim-sexual", "dim-manipulation", "dim-fear",
                         "dim-benefit", "news-documentary", "mixed-language", "ood", "safety-sentinel"] {
            XCTAssertTrue(list.contains { ($0["id"] as? String) == required }, "slice missing: \(required)")
        }
        let sentinel = try XCTUnwrap(list.first { ($0["id"] as? String) == "safety-sentinel" })
        XCTAssertEqual(sentinel["min_n"] as? Int, 150, "sentinel law consistent with PRE-09 rule-of-three freeze")
        let gates = try json("docs/calibration/preregistration/RWC_FROZEN_GATES.yaml")
        XCTAssertEqual(gates["data_visibility_at_freeze"] as? Bool, false, "feasibility -> FREEZE -> data law")
        let fm = try XCTUnwrap(gates["frozen_metrics"] as? [String: Any])
        XCTAssertTrue(((fm["risk_ECE"] as? [String: Any])?["gate"] as? String ?? "").contains("Q95(null)"),
                      "v2 null-referenced design (v1 point gate superseded, preserved in superseded_v1_design)")
        XCTAssertTrue(((fm["falseSafe"] as? [String: Any])?["gate"] as? String ?? "").contains("rule-of-three"))
        XCTAssertTrue(((fm["AUROC"] as? [String: Any])?["gate"] as? String ?? "").hasPrefix("REPORT"), "AUROC hard gate rejected")
        let rejected = try XCTUnwrap(gates["rejected_or_modified_candidates"] as? [[String: Any]])
        XCTAssertGreaterThanOrEqual(rejected.count, 4, "rejected/modified candidates documented with WHY")
        XCTAssertFalse((gates["invalidation_law"] as? String ?? "").isEmpty)
    }

    func testPre1213_SealAndDeviceLaws() throws {
        let seal = try text("docs/calibration/preregistration/protocols/RWC_PRE12_SPLIT_SEAL.md")
        for must in ["near-duplicate", "SHA-256 SEALED", "RUN-ONCE", "LOSES FINAL status", "EMERGENCY INVALIDATION",
                     "heldout_open_count = 0"] {
            XCTAssertTrue(seal.contains(must), "seal law missing: \(must)")
        }
        let dev = try text("docs/calibration/preregistration/protocols/RWC_PRE13_DEVICE_EVIDENCE.md")
        for must in ["build success != runtime proof", "simulator != physical device", "thermal",
                     "SEPARATE cell", "UNKNOWN", "reports NOTHING yet"] {
            XCTAssertTrue(dev.contains(must), "device law missing: \(must)")
        }
    }

    // ═══════ zero-data guarantee + locks ═══════

    func testZeroDataGuarantee_AndLocksHold() throws {
        let manifest = try json("docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml")
        XCTAssertEqual(manifest["corpus_count"] as? Int, 0)
        XCTAssertEqual(manifest["annotator_count"] as? Int, 0)
        XCTAssertEqual(manifest["real_fit_count"] as? Int, 0)
        XCTAssertEqual(manifest["heldout_open_count"] as? Int, 0)
        XCTAssertEqual(manifest["data_visibility"] as? Bool, false)
        // freeze manifest V2 (I-15, manifest addendum): every binding artifact hash matches disk NOW.
        // v1 is preserved untouched as the FAILED candidate's historical record (drift expected).
        let freeze = try json("docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V2.yaml")
        XCTAssertTrue((freeze["pre_data_declaration"] as? String ?? "").contains("NO REAL CORPUS RESULTS"))
        for a in try XCTUnwrap(freeze["artifacts"] as? [[String: Any]]) {
            let path = try XCTUnwrap(a["path"] as? String)
            let want = try XCTUnwrap(a["sha256"] as? String)
            let data = try Data(contentsOf: URL(fileURLWithPath: repoRoot + "/" + path))
            let got = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(got, want, "freeze hash drift: \(path)")
        }
        // code locks unchanged
        XCTAssertFalse(ProductionScoreReleaseGateV1.evaluate().0)
        XCTAssertFalse(CalibrationRegistryV2().productionDisplayAllowed())
        XCTAssertEqual(CalibrationRegistryV2().calibrationClass, .engineeringOnly)
        XCTAssertFalse(CalibrationDatasetRegistryV2.supportsRealWorldClaims)
        XCTAssertEqual(CalibrationDatasetRegistryV2.pairs.count, 59, "no dataset growth")
        XCTAssertFalse(RealWorldCalibrationExecutorV1.preregistrationAuditPassed, "PRE-14 not passed — executor sealed")
    }
}
