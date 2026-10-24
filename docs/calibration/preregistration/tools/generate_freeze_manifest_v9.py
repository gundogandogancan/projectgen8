#!/usr/bin/env python3
# FREEZE MANIFEST V9 GENERATOR (LANE A; frozen methodology tooling; v8 variant).
#
# NON-CIRCULAR TWO-PHASE LAW (carried): run AFTER the LANE A METHODOLOGY ANCHOR COMMIT with its SHA as
# argv[1]; the manifest lands in a LATER commit. Deterministic output (no clock, no hash()).
#
# SURFACE LAW (carried from v8): governed roots enumerated RECURSIVELY; NO filename prefixes; dotfiles
# excluded; a SYMLINK anywhere under a governed root is a hard generation error. Package.swift is an
# explicit artifact. The ONLY post-audit allowance is auditor-evidence files (AUDIT*) in the tests root.
# The MAIN SESSION runs this at the new LANE A anchor to regenerate the live manifest; the new LANE A
# source + test + the edited files' new bytes are automatically included by the recursive scan.
#
# V9 DELTA vs V8 (LANE A): freeze_version -> v9; self/post-anchor paths -> V9; supersession reason = the
# A21-F5 targeted receipt-finalization fix (RWCCorpusAcquisitionRunnerV5.reconcileV5.ensureReceipt) + the
# governed operational onboarding engine (RWCOperationalRootOnboardingV1) + the 13+2 stale-pin
# supersessions; RWCOperationalRootOnboardingV1.swift added to METHODOLOGY_CODE; the v9 generator
# self-listed. governed_roots UNCHANGED (docs/operations/rwc is deliberately NOT a governed root).
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
    DOCP + "/RWC_PREREGISTRATION_FREEZE_MANIFEST_V9.yaml",
    DOCP + "/RWC_PREREGISTRATION_LANE_A_REMEDIATION_REPORT.md",
]
POST_AUDIT_ALLOWANCES = [
    {"root": "packages/GuardianKit/Tests/GuardianCoreTests", "filename_prefix": "AUDIT"},
]
HASH_EXEMPT = [
    DOCP + "/RWC_PREREGISTRATION_FREEZE_MANIFEST_V9.yaml",   # SELF (post-anchor)
    DOCP + "/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",      # MUTABLE_BY_LAW (field-level law)
]
METHODOLOGY_CODE = {
    # LANE A new surface (operational onboarding engine)
    "packages/GuardianKit/Sources/GuardianCore/RWCOperationalRootOnboardingV1.swift",
    # R7 surfaces (AUDIT20 remediation) — RunnerV5 carries the A21-F5 fix (re-hashed automatically)
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
    DOCP + "/tools/generate_freeze_manifest_v9.py",
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
        print("usage: generate_freeze_manifest_v9.py <anchor_sha40>")
        return 1
    anchor = sys.argv[1]
    paths = sorted(scan() - set(POST_ANCHOR_ALLOWED))
    artifacts = []
    for p in paths:
        exempt = p in HASH_EXEMPT
        artifacts.append({
            "path": p,
            "sha256": "SELF" if (exempt and "FREEZE_MANIFEST_V9" in p) else
                      ("MUTABLE_BY_LAW" if exempt else sha256(p)),
            "class": classify(p),
        })
    inv = hashlib.sha256("\n".join("%s:%s" % (a["path"], a["sha256"])
                                   for a in sorted(artifacts, key=lambda a: a["path"]))
                         .encode("utf-8")).hexdigest()
    manifest = {
        "freeze_version": "rwc-preregistration-freeze-v9",
        "format_law": "STRICT JSON in .yaml. FROZEN.",
        "supersedes": "rwc-preregistration-freeze-v8 (byte-preserved history)",
        "supersession_reason": "LANE A operational onboarding + A21-F5 targeted fix. (1) A21-F5 LOW report-fidelity gap closed in RWCCorpusAcquisitionRunnerV5.reconcileV5.ensureReceipt: a failed complete() is no longer reported as finalized (reload-verified .completed before finalized.append; else explicit receiptDeficit), and the quarantine evidence is PRESERVED on a deficit (no evidence loss; retryable). (2) NEW governed activation engine RWCOperationalRootOnboardingV1 (load/verify/activate/revoke/rotate) + durable hash-chained RWCOperationalRootActivationStoreV1: the lawful, auditable source of the A19-F2 onboarding capability + a GOVERNED RWCVerifiedReviewerTrustRootV2, gated by an out-of-band public-key fingerprint + a governance record; activate/revoke/rotate are `package`; loadProduction stays byte-identical fail-closed. (3) the AUDIT21 A21-F5 §7 probe (AUDIT21_RWCPre14R7ReauditProbes.swift, post_audit_allowances / not hashed) inverted to assert the FIXED behavior. The 13 lock-absence pins + 2 cwd-sensitive pins are PRESERVED as lawful stale-by-phase-transition (NOT edited — editing them would violate freeze-manifest hash censuses + byte-identity discipline pins; OLD truth git-reproducible at 30c7c7c), per docs/audit/AUDIT21_LANE_A_INVERSION_LOCK.md. NO real key, NO real root file, NO OPERATIONAL_ROOT_ACTIVE.",
        "methodology_anchor_commit": anchor,
        "governing_control_plane_lock": "2c345b64c720f965b68ec5ee699e1b71fecf0003",
        "anchor_law": "carried: all frozen files FINAL at methodology_anchor_commit; this manifest lands in a LATER commit; per-path git diff anchor..candidate EMPTY; only this manifest, the LANE A report and candidate metadata may follow the anchor; any frozen-surface change requires a NEW anchor + manifest + independent audit.",
        "candidate_blob_binding_law": "A18-F5 carried: the verifier binds the LIVE freeze V9 manifest to sha256(git show <candidate_commit>:<this path>); this manifest MUST be present in the candidate tree and MUST NOT be replaced post-candidate.",
        "tag_identity_law": "carried: candidate annotated TAG OBJECT SHA + TAG NAME cross-check (A18-F4) pinned by the independent machine audit result (schema V4) and the PASS lock.",
        "authority_token_law_pointer": "carried A20-F1: RWCAssetRightsLedgerStoreV5.authorizeAcquisitionV2 REQUIRES an RWCAcquisitionAuthorityTokenV1 (package init), minted ONLY by RWCCorpusAcquisitionRunnerV5 after RWCCorpusEntryVerifierV6.verify + RWCPreAcquisitionEvaluatorV3.authorize + a current-registry recheck.",
        "receipt_completeness_law_pointer": "R-6 + A21-F5: reconcileV5 reconstructs a durable receipt from the authenticated authorization record V2 ONLY when it verifiably reaches .completed; a failed finalize / incomplete proof keeps the session UNPROMOTED-or-deficient and reports an explicit receiptDeficit, PRESERVING the quarantine evidence (no false finalize, no evidence loss).",
        "operational_onboarding_law_pointer": "LANE A: production reviewer trust root is activated ONLY through the governed RWCOperationalRootOnboardingV1 ceremony (governance record + out-of-band public-key fingerprint + durable hash-chained activation event). loadProduction stays fail-closed .noOperationalRoot PRE-activation. docs/operations/rwc/ (checklists, governance-record template, human-activation gate, architecture/transition docs) is NOT a governed root. Honest limit: local hash chains are tamper-DETECTION under a non-hostile-disk model; Secure Enclave Ed25519 support is UNKNOWN and NOT assumed. NO real key / root file / OPERATIONAL_ROOT_ACTIVE exists.",
        "trust_root_law_pointer": "carried A19-F2: RWCReviewerRootOnboardingCapabilityV1 init stays `internal`; the capability-gated mint stays `internal`; the instance path docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json does NOT exist pre-data and is NOT a governed root; RWC-REVIEWER-ROOT-ONBOARDING blocker remains OPEN (engine ready, activation blocked).",
        "registry_currentness_law_pointer": "carried A19-F3 + enforced at authorize (A20-F4). Honest local-disk threat model unchanged (R-5 residual preserved).",
        "historical_truth": "v1..v8 methodology is RECOVERABLE from candidate commits + manifest hashes + git history + supersession records; the OLD stale-pin truth is reproducible at 30c7c7c.",
        "pre_data_declaration": "corpus_count=0, annotator_count=0, real_fit_count=0, heldout_open_count=0, data_visibility=false. No production reviewer trust root, no real key, no OPERATIONAL_ROOT_ACTIVE. LANE A is ONBOARDING_ENGINEERING_READY — ACTIVATION_BLOCKED; PRE-14 PASS carried.",
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
    out = os.path.join(REPO, DOCP, "RWC_PREREGISTRATION_FREEZE_MANIFEST_V9.yaml")
    with open(out, "w") as f:
        f.write(json.dumps(manifest, indent=2) + "\n")
    print("WROTE=%s artifacts=%d inventory_digest=%s" % (out, len(artifacts), inv))
    return 0


if __name__ == "__main__":
    sys.exit(main())
