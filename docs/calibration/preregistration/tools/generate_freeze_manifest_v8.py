#!/usr/bin/env python3
# FREEZE MANIFEST V8 GENERATOR (AUDIT20 R7; frozen methodology tooling; v7 variant).
#
# NON-CIRCULAR TWO-PHASE LAW (carried): run AFTER the R7 METHODOLOGY ANCHOR COMMIT with its SHA as
# argv[1]; the manifest lands in a LATER commit. Deterministic output (no clock, no hash()).
#
# SURFACE LAW (carried from v7): governed roots enumerated RECURSIVELY; NO filename prefixes; dotfiles
# excluded; a SYMLINK anywhere under a governed root is a hard generation error. Package.swift is an
# explicit artifact. The ONLY post-audit allowance is auditor-evidence files (AUDIT*) in the tests root.
# The MAIN SESSION runs this at the new R7 anchor to regenerate the live manifest; the new R7
# sources/tests/docs are automatically included by the recursive scan.
#
# R7 DELTA vs V7: freeze_version → v8; self/post-anchor paths → V8; supersession reason = AUDIT20
# A20-F1/F2/F3/F4 + R-6; the R7 new sources (RWCRightsV7Store, RunnerV5, VerifierV6) added to
# METHODOLOGY_CODE; the v8 generator self-listed; the four `public→package` demotions and the additive
# receipt overload are reflected automatically by re-hashing the (now-demoted) frozen-source bytes.
import hashlib
import json
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
GOVERNED_ROOTS = [
    "docs/calibration/preregistration",
    "packages/GuardianKit/Sources/GuardianCore",
    "packages/GuardianKit/Sources/RWCAcquisition",
    "packages/GuardianKit/Tests/GuardianCoreTests",
]
EXTRA_ARTIFACTS = ["packages/GuardianKit/Package.swift"]
DOCP = "docs/calibration/preregistration"
POST_ANCHOR_ALLOWED = [
    DOCP + "/RWC_PREREGISTRATION_FREEZE_MANIFEST_V8.yaml",
    DOCP + "/RWC_PREREGISTRATION_R7_REMEDIATION_REPORT.md",
]
POST_AUDIT_ALLOWANCES = [
    {"root": "packages/GuardianKit/Tests/GuardianCoreTests", "filename_prefix": "AUDIT"},
]
HASH_EXEMPT = [
    DOCP + "/RWC_PREREGISTRATION_FREEZE_MANIFEST_V8.yaml",   # SELF (post-anchor)
    DOCP + "/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",      # MUTABLE_BY_LAW (field-level law)
]
METHODOLOGY_CODE = {
    # R7 new surfaces (AUDIT20 remediation)
    "packages/GuardianKit/Sources/GuardianCore/RWCRightsV7Store.swift",
    "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV5.swift",
    "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV6.swift",
    # R6 surfaces (AUDIT19 remediation)
    "packages/GuardianKit/Sources/GuardianCore/RWCRightsV6.swift",
    "packages/GuardianKit/Sources/GuardianCore/RWCRightsV6Store.swift",
    "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV4.swift",
    "packages/GuardianKit/Sources/RWCAcquisition/RWCAcquisitionReceiptStoreV2.swift",
    # R5 and earlier methodology (carried)
    "packages/GuardianKit/Sources/GuardianCore/RWCRightsV5.swift",
    "packages/GuardianKit/Sources/GuardianCore/RWCRightsV4.swift",
    "packages/GuardianKit/Sources/GuardianCore/RWCRightsV3.swift",
    "packages/GuardianKit/Sources/GuardianCore/RWCRightsV2.swift",
    "packages/GuardianKit/Sources/GuardianCore/RWCAssetRightsLedgerV1.swift",
    "packages/GuardianKit/Sources/GuardianCore/RWCAssetIdentityV1.swift",
    "packages/GuardianKit/Sources/GuardianCore/CalibrationRunPreparationV1.swift",
    "packages/GuardianKit/Sources/GuardianCore/CalibrationIntegrityV1.swift",
    "packages/GuardianKit/Sources/GuardianCore/RealWorldCalibrationExecutorV1.swift",
    "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV5.swift",
    "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV4.swift",
    "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV3.swift",
    "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV3.swift",
    "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV2.swift",
    "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV1.swift",
    "packages/GuardianKit/Sources/RWCAcquisition/RWCAcquisitionReceiptStoreV1.swift",
    "packages/GuardianKit/Tests/GuardianCoreTests/RWCCalibrationMethodologyV4.swift",
    "packages/GuardianKit/Tests/GuardianCoreTests/RWCCalibrationMethodologyV3.swift",
    "packages/GuardianKit/Tests/GuardianCoreTests/RWCCalibrationMethodologyV1.swift",
    "packages/GuardianKit/Tests/GuardianCoreTests/RWCPowerDerivationV4.swift",
    "packages/GuardianKit/Tests/GuardianCoreTests/RWCPowerDerivationV3.swift",
    "packages/GuardianKit/Tests/GuardianCoreTests/RWCCorpusEntryVerifierV2.swift",
    "packages/GuardianKit/Tests/GuardianCoreTests/RWCStatisticsV1.swift",
    "packages/GuardianKit/Package.swift",
    DOCP + "/tools/rwc_methodology_v3_differential.py",
    DOCP + "/tools/generate_freeze_manifest_v3.py",
    DOCP + "/tools/generate_freeze_manifest_v4.py",
    DOCP + "/tools/generate_freeze_manifest_v5.py",
    DOCP + "/tools/generate_freeze_manifest_v6.py",
    DOCP + "/tools/generate_freeze_manifest_v7.py",
    DOCP + "/tools/generate_freeze_manifest_v8.py",
}


def sha256(path):
    with open(os.path.join(REPO, path), "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def scan():
    found = set()
    for root in GOVERNED_ROOTS:
        root_abs = os.path.join(REPO, root)
        for base, dirs, names in os.walk(root_abs):
            for n in list(dirs) + list(names):
                full = os.path.join(base, n)
                if os.path.islink(full):
                    raise SystemExit("SYMLINK IN GOVERNED SURFACE: " + full)
            for n in names:
                if n.startswith("."):
                    continue
                rel = os.path.relpath(os.path.join(base, n), REPO).replace(os.sep, "/")
                found.add(rel)
    found.update(EXTRA_ARTIFACTS)
    return found


def classify(path):
    if path in METHODOLOGY_CODE:
        return "METHODOLOGY_CODE"
    if path in HASH_EXEMPT:
        return "MUTABLE_BY_LAW" if "MASTER_MANIFEST" in path else "SELF"
    if path.startswith("packages/GuardianKit/Sources/RWCAcquisition/"):
        return "METHODOLOGY_CODE"
    if path.startswith("packages/GuardianKit/Sources/"):
        return "LEGACY_ENGINEERING_FROZEN"
    if path.startswith("packages/GuardianKit/Tests/"):
        return "TEST_EVIDENCE"
    if "_ORIGINAL_LOCKED" in path or "/audit15_tools/" in path or "/audit16_tools/" in path:
        return "AUDIT_EVIDENCE_FROZEN"
    if "SUPERSEDED" in path or path.endswith("RWC_FROZEN_GATES.yaml") \
            or path.endswith("RWC_FROZEN_GATES_V3.yaml") \
            or path.endswith("RWC_CALIBRATION_POWER_PREREG.yaml") \
            or path.endswith("RWC_CALIBRATION_POWER_PREREG_V3.yaml") \
            or path.endswith("RWC_SLICE_DEFINITIONS.yaml") \
            or path.endswith("RWC_PREREGISTRATION_FREEZE_MANIFEST.yaml") \
            or path.endswith("RWC_PREREGISTRATION_FREEZE_MANIFEST_V2.yaml") \
            or path.endswith("RWC_PREREGISTRATION_FREEZE_MANIFEST_V3.yaml") \
            or path.endswith("power_derivation.py"):
        return "SUPERSEDED_FROZEN_HISTORY"
    return "FROZEN_NORMATIVE"


def main():
    if len(sys.argv) < 2 or len(sys.argv[1]) != 40:
        print("usage: generate_freeze_manifest_v8.py <anchor_sha40>")
        return 1
    anchor = sys.argv[1]
    paths = sorted(scan() - set(POST_ANCHOR_ALLOWED))
    artifacts = []
    for p in paths:
        exempt = p in HASH_EXEMPT
        artifacts.append({
            "path": p,
            "sha256": "SELF" if (exempt and "FREEZE_MANIFEST_V8" in p) else
                      ("MUTABLE_BY_LAW" if exempt else sha256(p)),
            "class": classify(p),
        })
    inv = hashlib.sha256("\n".join("%s:%s" % (a["path"], a["sha256"])
                                   for a in sorted(artifacts, key=lambda a: a["path"]))
                         .encode("utf-8")).hexdigest()
    manifest = {
        "freeze_version": "rwc-preregistration-freeze-v8",
        "format_law": "STRICT JSON in .yaml. FROZEN.",
        "supersedes": "rwc-preregistration-freeze-v7 (byte-preserved history)",
        "supersession_reason": "AUDIT20 FIX_REQUIRED (A20-F1 CRITICAL PRE-14-PASS bypass via the scalar authorizeAcquisition writer; A20-F2 HIGH legacy V1/V3 public mint/register/reconcile surface; A20-F3 MEDIUM intended-use unenforced at the ledger gate; A20-F4 MEDIUM stale grant after reviewer revocation; R-6 crash authorize->receipt silent-no-receipt): R7 closes all four at ONE boundary via a package-init acquisition authority TOKEN (RWCRightsV7Store.swift: RWCAcquisitionAuthorityTokenV1 + RWCAssetRightsLedgerStoreV5.authorizeAcquisitionV2 requiring the token + current-registry recheck + intended-use check + full proof-identity authorization record V2), the single coordinator RWCCorpusAcquisitionRunnerV5 (sole token minter; reconcileV5 reconstruct-or-report receipts, R-6), and the lawfully versioned RWCCorpusEntryVerifierV6 + audit-result schema V4 (R7 result path + V8 manifest). The legacy V1/V3 dangerous surfaces + the scalar authorizeAcquisition are demoted public->package (declared in docs/audit/AUDIT20_R7_INVERSION_LOCK.md). Verifier V5 + calibration V4 + durable store V3/V4 carried as SUPERSEDED history.",
        "methodology_anchor_commit": anchor,
        "governing_control_plane_lock": "2c345b64c720f965b68ec5ee699e1b71fecf0003",
        "anchor_law": "carried: all frozen files FINAL at methodology_anchor_commit; this manifest lands in a LATER commit; per-path git diff anchor..candidate EMPTY; only this manifest, the R7 report and candidate metadata may follow the anchor; any frozen-surface change requires a NEW anchor + manifest + independent audit.",
        "candidate_blob_binding_law": "A18-F5 carried: the verifier binds the LIVE freeze V8 manifest to sha256(git show <candidate_commit>:<this path>); this manifest MUST be present in the candidate tree and MUST NOT be replaced post-candidate.",
        "tag_identity_law": "carried: candidate annotated TAG OBJECT SHA + TAG NAME cross-check (A18-F4) pinned by the independent machine audit result (schema V4) and the future PASS lock.",
        "authority_token_law_pointer": "A20-F1: the ledger acquisition-authorization write (RWCAssetRightsLedgerStoreV5.authorizeAcquisitionV2) REQUIRES an RWCAcquisitionAuthorityTokenV1 whose init is `package`; the token is minted ONLY by RWCCorpusAcquisitionRunnerV5 after RWCCorpusEntryVerifierV6.verify (PRE-14 PASS proof) + RWCPreAcquisitionEvaluatorV3.authorize + a current-registry recheck. Caller scalars can no longer author a promotable authorization record.",
        "revocation_policy_pointer": "A20-F4: current authorized reviewer status is MANDATORY at authorization-commit time; an authorization created after effective revocation is prohibited; already-authorized not-yet-promoted transactions still reconcile from their durable record but no NEW authorize is minted under a revoked reviewer (see RWC_R7_AUTHORITY_CONVERGENCE_DESIGN.md D-R7-5).",
        "receipt_completeness_law_pointer": "R-6: reconcileV5 reconstructs a durable receipt from the authenticated authorization record V2 (no silent promotion without a receipt); an incomplete proof identity keeps the session UNPROMOTED and reports an explicit receiptDeficit.",
        "legacy_seal_law_pointer": "A20-F2: RWCReviewerTrustRootLoaderV1.mint/loadProduction, RWCReviewerRegistryVerifierV1.verify, RWCRightsReviewAuthorityV1.verify, RWCAssetRightsLedgerStoreV3.register, RWCCorpusAcquisitionRunnerV3.reconcileV3 and the scalar RWCAssetRightsLedgerStoreV4.authorizeAcquisition are demoted public->package; RWCAcquisition is not a package product, so its legacy runner is unreachable to any external consumer (proven by docs/audit/audit20_tools/a20consumer_r7).",
        "trust_root_law_pointer": "carried A19-F2: production reviewer trust root minted ONLY through the capability-gated RWCReviewerTrustRootLoaderV2; the instance path docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json does NOT exist pre-data and is NOT a governed root; RWC-REVIEWER-ROOT-ONBOARDING blocker remains open.",
        "registry_currentness_law_pointer": "carried A19-F3 + enforced at authorize (A20-F4). Honest local-disk threat model unchanged (R-5 residual preserved).",
        "historical_truth": "v1..v7 methodology is RECOVERABLE from candidate commits + manifest hashes + git history + supersession records.",
        "pre_data_declaration": "corpus_count=0, annotator_count=0, real_fit_count=0, heldout_open_count=0, data_visibility=false. No PASS lock, no R7 audit-result instance, no production reviewer trust root exists. R7 is BUILDER READY FOR AUDIT21 — NOT a PRE-14 PASS.",
        "surface_rules": {
            "governed_roots": GOVERNED_ROOTS,
            "extra_artifacts": EXTRA_ARTIFACTS,
            "post_anchor_allowed": POST_ANCHOR_ALLOWED,
            "post_audit_allowances": POST_AUDIT_ALLOWANCES,
            "hash_exempt": HASH_EXEMPT,
            "law": "RECURSIVE enumeration, NO filename prefixes, symlinks are typed refusals; SET EQUALITY both directions at corpus entry against candidate git tree AND live filesystem; the live manifest is bound to the candidate-commit blob (A18-F5); post-audit allowances are PATH-SCOPED {root, filename_prefix} objects; master manifest mutability is FIELD-LEVEL.",
        },
        "frozen_inventory_digest": inv,
        "artifacts": artifacts,
    }
    out = os.path.join(REPO, DOCP, "RWC_PREREGISTRATION_FREEZE_MANIFEST_V8.yaml")
    with open(out, "w") as f:
        f.write(json.dumps(manifest, indent=2) + "\n")
    print("WROTE=%s artifacts=%d inventory_digest=%s" % (out, len(artifacts), inv))
    return 0


if __name__ == "__main__":
    sys.exit(main())
