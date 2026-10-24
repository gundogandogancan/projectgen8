#!/usr/bin/env python3
# FREEZE MANIFEST V10 GENERATOR (LANE A V10 release-verifier transition; frozen methodology tooling; v9
# variant).
#
# NON-CIRCULAR TWO-PHASE LAW (carried): run AFTER the LANE A V10 METHODOLOGY ANCHOR COMMIT with its SHA as
# argv[1]; the manifest lands in a LATER commit. Deterministic output (no clock, no hash()).
#
# SURFACE LAW (carried from v9): governed roots enumerated RECURSIVELY; NO filename prefixes; dotfiles
# excluded; a SYMLINK anywhere under a governed root is a hard generation error. Package.swift is an
# explicit artifact. The ONLY post-audit allowance is auditor-evidence files (AUDIT*) in the tests root.
# The MAIN SESSION runs this at the new LANE A V10 anchor to regenerate the live manifest; the new V10
# surface (verifier V7 + schema V5) is automatically included by the recursive scan; the V10 transition
# probes (AUDIT-prefixed) are covered by post_audit_allowances and are NOT hashed census members.
#
# V10 DELTA vs V9 (purely additive release-verifier transition; ZERO edits to any V9-frozen artifact):
#   - freeze_version -> v10; self/post-anchor paths -> V10; supersession reason = the release-verifier
#     transition (RWCCorpusEntryVerifierV7 + schema V5 + manifest V10 binding), carrying the A21-F5 fix +
#     onboarding engine from V9 unchanged;
#   - RWCCorpusEntryVerifierV7.swift added to METHODOLOGY_CODE (it is also auto-classified METHODOLOGY_CODE
#     by the RWCAcquisition/ prefix rule — explicit for clarity);
#   - the v10 generator self-listed;
#   - RWC_LANE_A_V10_TRANSITION_RECORD.md added to POST_ANCHOR_ALLOWED (post-anchor evidence doc, like the
#     LANE A remediation report);
#   - governed_roots UNCHANGED (docs/operations/rwc is deliberately NOT a governed root).
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
    DOCP + "/RWC_PREREGISTRATION_FREEZE_MANIFEST_V10.yaml",
    DOCP + "/RWC_PREREGISTRATION_LANE_A_REMEDIATION_REPORT.md",
    DOCP + "/RWC_LANE_A_V10_TRANSITION_RECORD.md",
]
POST_AUDIT_ALLOWANCES = [
    {"root": "packages/GuardianKit/Tests/GuardianCoreTests", "filename_prefix": "AUDIT"},
]
HASH_EXEMPT = [
    DOCP + "/RWC_PREREGISTRATION_FREEZE_MANIFEST_V10.yaml",  # SELF (post-anchor)
    DOCP + "/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",      # MUTABLE_BY_LAW (field-level law)
]
METHODOLOGY_CODE = {
    # LANE A V10 release verifier (new surface)
    "packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV7.swift",
    # LANE A (V9) operational onboarding engine
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
    DOCP + "/tools/generate_freeze_manifest_v10.py",
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
        print("usage: generate_freeze_manifest_v10.py <anchor_sha40>")
        return 1
    anchor = sys.argv[1]
    paths = sorted(scan() - set(POST_ANCHOR_ALLOWED))
    artifacts = []
    for p in paths:
        exempt = p in HASH_EXEMPT
        artifacts.append({
            "path": p,
            "sha256": "SELF" if (exempt and "FREEZE_MANIFEST_V10" in p) else
                      ("MUTABLE_BY_LAW" if exempt else sha256(p)),
            "class": classify(p),
        })
    inv = hashlib.sha256("\n".join("%s:%s" % (a["path"], a["sha256"])
                                   for a in sorted(artifacts, key=lambda a: a["path"]))
                         .encode("utf-8")).hexdigest()
    manifest = {
        "freeze_version": "rwc-preregistration-freeze-v10",
        "format_law": "STRICT JSON in .yaml. FROZEN.",
        "supersedes": "rwc-preregistration-freeze-v9 (byte-preserved history)",
        "supersession_reason": "LANE A V10 release-verifier transition (purely additive; ZERO edits to any V9-frozen artifact). The V9 candidate landed the A21-F5 RunnerV5 fix + the governed onboarding engine, so RWCCorpusEntryVerifierV6 (pinned to the R7 result path + manifest V8 + freeze-version rwc-preregistration-freeze-v8) correctly fails closed with frozenFileDrift on the real repo and the historical V8 PASS must NOT be auto-rebound to V9/V10 code. NEW RWCCorpusEntryVerifierV7 binds the V10 identity under schema V5 (result path docs/audit/RWC_PRE14_V10_AUDIT_RESULT.json, freeze manifest V10, freeze-version rwc-preregistration-freeze-v10) with V6's binding matrix carried VERBATIM; it reuses the PASS-lock schema RWCPre14PassLockV4 (lock_version rwc-pre14-pass-lock-v4) UNCHANGED (contract note in docs/audit/AUDIT21_V10_TRANSITION_LOCK.md §5). V6 stays byte-frozen and keeps validating the historical V8-era AUDIT21 lock from the historical candidate 104dad4. The 13 lock-absence stale pins + the AUDIT21_CLOSEOUT_TransitionProbes Group-2 red + the 3 worktree AUDIT12 git-tag reds are PRESERVED unedited (freeze-immutability; OLD truth git-reproducible at 30c7c7c), per docs/audit/AUDIT21_V10_TRANSITION_LOCK.md. NO real key, NO real root file, NO OPERATIONAL_ROOT_ACTIVE.",
        "methodology_anchor_commit": anchor,
        "governing_control_plane_lock": "2c345b64c720f965b68ec5ee699e1b71fecf0003",
        "anchor_law": "carried: all frozen files FINAL at methodology_anchor_commit; this manifest lands in a LATER commit; per-path git diff anchor..candidate EMPTY; only this manifest, the LANE A report, the V10 transition record and candidate metadata may follow the anchor; any frozen-surface change requires a NEW anchor + manifest + independent audit.",
        "candidate_blob_binding_law": "A18-F5 carried: the verifier binds the LIVE freeze V10 manifest to sha256(git show <candidate_commit>:<this path>); this manifest MUST be present in the candidate tree and MUST NOT be replaced post-candidate.",
        "tag_identity_law": "carried: candidate annotated TAG OBJECT SHA + TAG NAME cross-check (A18-F4) pinned by the independent machine audit result (schema V5) and the PASS lock.",
        "release_verifier_law_pointer": "LANE A V10: the release verifier is RWCCorpusEntryVerifierV7 binding schema V5 + this manifest + freeze-version rwc-preregistration-freeze-v10. It fails closed .lockMissing pre-V10-PASS and refuses the AUDIT19/20 FIX_REQUIRED results, the V9 builder candidate (no audit result), a different candidate's PASS, wrong path/tag/anchor/manifest/digest/counts, uncommitted fake results, and any rebinding of the historical V8 PASS to V9/V10 code. RWCCorpusEntryVerifierV6 stays byte-frozen and historically verifiable (V8-era AUDIT21 lock from candidate 104dad4). PASS authority is the independent auditor's; the builder mints NO PASS.",
        "authority_token_law_pointer": "carried A20-F1: RWCAssetRightsLedgerStoreV5.authorizeAcquisitionV2 REQUIRES an RWCAcquisitionAuthorityTokenV1 (package init), minted ONLY by RWCCorpusAcquisitionRunnerV5 after a release-verifier PASS + RWCPreAcquisitionEvaluatorV3.authorize + a current-registry recheck.",
        "receipt_completeness_law_pointer": "R-6 + A21-F5: reconcileV5 reconstructs a durable receipt from the authenticated authorization record V2 ONLY when it verifiably reaches .completed; a failed finalize / incomplete proof keeps the session UNPROMOTED-or-deficient and reports an explicit receiptDeficit, PRESERVING the quarantine evidence (no false finalize, no evidence loss).",
        "operational_onboarding_law_pointer": "LANE A: production reviewer trust root is activated ONLY through the governed RWCOperationalRootOnboardingV1 ceremony (governance record + out-of-band public-key fingerprint + durable hash-chained activation event). loadProduction stays fail-closed .noOperationalRoot PRE-activation. docs/operations/rwc/ is NOT a governed root. Honest limit: local hash chains are tamper-DETECTION under a non-hostile-disk model; Secure Enclave Ed25519 support is UNKNOWN and NOT assumed. NO real key / root file / OPERATIONAL_ROOT_ACTIVE exists.",
        "trust_root_law_pointer": "carried A19-F2: RWCReviewerRootOnboardingCapabilityV1 init stays `internal`; the capability-gated mint stays `internal`; the instance path docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json does NOT exist pre-data and is NOT a governed root; RWC-REVIEWER-ROOT-ONBOARDING blocker remains OPEN (engine ready, activation blocked).",
        "registry_currentness_law_pointer": "carried A19-F3 + enforced at authorize (A20-F4). Honest local-disk threat model unchanged (R-5 residual preserved).",
        "historical_truth": "v1..v9 methodology is RECOVERABLE from candidate commits + manifest hashes + git history + supersession records; the OLD stale-pin truth is reproducible at 30c7c7c; the V8-era AUDIT21 lock stays validated by RWCCorpusEntryVerifierV6.",
        "pre_data_declaration": "corpus_count=0, annotator_count=0, real_fit_count=0, heldout_open_count=0, data_visibility=false. No production reviewer trust root, no real key, no OPERATIONAL_ROOT_ACTIVE, no V10 PASS lock. LANE A is BUILDER READY FOR TARGETED INDEPENDENT AUDIT (AUDIT22T) — ACTIVATION_BLOCKED; PRE-14 PASS carried historically.",
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
    out = os.path.join(REPO, DOCP, "RWC_PREREGISTRATION_FREEZE_MANIFEST_V10.yaml")
    with open(out, "w") as f:
        f.write(json.dumps(manifest, indent=2) + "\n")
    print("WROTE=%s artifacts=%d inventory_digest=%s" % (out, len(artifacts), inv))
    return 0


if __name__ == "__main__":
    sys.exit(main())
