#!/usr/bin/env python3
# FREEZE MANIFEST V6 GENERATOR (AUDIT18 R5; frozen methodology tooling).
#
# NON-CIRCULAR TWO-PHASE LAW (carried): run AFTER the R5 METHODOLOGY ANCHOR COMMIT with its SHA as
# argv[1]; the manifest lands in a LATER commit. Deterministic output (no clock, no hash()).
#
# SURFACE LAW (carried from v5): governed roots are enumerated RECURSIVELY; NO filename prefixes;
# dotfiles are OS noise and excluded; a SYMLINK anywhere under a governed root is a hard generation
# error (the verifier refuses them too). Package.swift is an explicit artifact.
#
# A18-F5 note: the verifier (RWCCorpusEntryVerifierV5) additionally binds the LIVE freeze V6
# manifest to the manifest blob AS COMMITTED IN THE CANDIDATE COMMIT (git show candidate:path) — so
# this manifest must be present in the candidate tree and never replaced post-candidate.
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
    DOCP + "/RWC_PREREGISTRATION_FREEZE_MANIFEST_V6.yaml",
    DOCP + "/RWC_PREREGISTRATION_R5_REMEDIATION_REPORT.md",
]
# PATH-SCOPED allowance objects (carried A17-F3) — the ONLY allowance is auditor-evidence files in
# the tests root. NO allowance for production source roots or Package.swift.
POST_AUDIT_ALLOWANCES = [
    {"root": "packages/GuardianKit/Tests/GuardianCoreTests", "filename_prefix": "AUDIT"},
]
HASH_EXEMPT = [
    DOCP + "/RWC_PREREGISTRATION_FREEZE_MANIFEST_V6.yaml",   # SELF (post-anchor)
    DOCP + "/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",      # MUTABLE_BY_LAW (field-level law)
]
METHODOLOGY_CODE = {
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
        print("usage: generate_freeze_manifest_v6.py <anchor_sha40>")
        return 1
    anchor = sys.argv[1]
    paths = sorted(scan() - set(POST_ANCHOR_ALLOWED))
    artifacts = []
    for p in paths:
        exempt = p in HASH_EXEMPT
        artifacts.append({
            "path": p,
            "sha256": "SELF" if (exempt and "FREEZE_MANIFEST_V6" in p) else
                      ("MUTABLE_BY_LAW" if exempt else sha256(p)),
            "class": classify(p),
        })
    inv = hashlib.sha256("\n".join("%s:%s" % (a["path"], a["sha256"])
                                   for a in sorted(artifacts, key=lambda a: a["path"]))
                         .encode("utf-8")).hexdigest()
    manifest = {
        "freeze_version": "rwc-preregistration-freeze-v6",
        "format_law": "STRICT JSON in .yaml. FROZEN.",
        "supersedes": "rwc-preregistration-freeze-v5 (byte-preserved history)",
        "supersession_reason": "AUDIT18 FIX REQUIRED (A18-F1/F5/F2/F3 + F4/F6/F10 LOW): reviewer trust-root architecture, scope enforcement, candidate-freeze-blob binding, tag-name cross-check, durable acquisition receipt store + runner V3, source-manifest canonicality; this manifest governs the V6 surface. Calibration V4 + durable store V3 carried CLEAN per AUDIT17/AUDIT18.",
        "methodology_anchor_commit": anchor,
        "governing_control_plane_lock": "2c345b64c720f965b68ec5ee699e1b71fecf0003",
        "anchor_law": "carried: all frozen files FINAL at methodology_anchor_commit; this manifest lands in a LATER commit; per-path git diff anchor..candidate EMPTY; only this manifest, the R5 report and candidate metadata may follow the anchor; any frozen-surface change requires a NEW anchor + manifest + independent audit.",
        "candidate_blob_binding_law": "A18-F5: the verifier binds the LIVE freeze V6 manifest to sha256(git show <candidate_commit>:<this path>); this manifest MUST be present in the candidate tree and MUST NOT be replaced post-candidate. A post-candidate replacement endorsed by a matching PASS result+lock is a typed candidateFreezeBlobMismatch refusal.",
        "tag_identity_law": "carried: the candidate's annotated TAG OBJECT SHA is pinned by the independent machine audit result and the future PASS lock v4; additionally the TAG NAME is cross-checked (A18-F4: result == lock == dereferenced name) — never fabricated here.",
        "trust_root_law_pointer": "SIGNATURE AUTHENTICITY != TRUST AUTHORITY; the governed reviewer trust root instance path docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json does NOT exist pre-data and is NOT a governed root in this inventory; the corpus-phase verifier governs it when that phase opens (RWC_REVIEWER_TRUST_ROOT_SCHEMA_V1.yaml + RWC_REVIEWER_ROOT_ONBOARDING_LAW_V1.md; RWC-REVIEWER-ROOT-ONBOARDING blocker).",
        "historical_truth": "v1/v2/v3/v4/v5 methodology is RECOVERABLE from candidate commits + manifest hashes + git history + supersession records.",
        "pre_data_declaration": "corpus_count=0, annotator_count=0, real_fit_count=0, heldout_open_count=0, data_visibility=false. No PASS lock, no R5 audit-result instance, no production reviewer trust root exists.",
        "surface_rules": {
            "governed_roots": GOVERNED_ROOTS,
            "extra_artifacts": EXTRA_ARTIFACTS,
            "post_anchor_allowed": POST_ANCHOR_ALLOWED,
            "post_audit_allowances": POST_AUDIT_ALLOWANCES,
            "hash_exempt": HASH_EXEMPT,
            "law": "RECURSIVE enumeration, NO filename prefixes, symlinks are typed refusals; SET EQUALITY both directions at corpus entry against candidate git tree AND live filesystem (RWCCorpusEntryVerifierV5); the live manifest is additionally bound to the candidate-commit blob (A18-F5); post-audit allowances are PATH-SCOPED {root, filename_prefix} objects — basename alone grants nothing (A17-F3); master manifest mutability is FIELD-LEVEL (only the five zero-data counters may transition, post-entry).",
        },
        "frozen_inventory_digest": inv,
        "artifacts": artifacts,
    }
    out = os.path.join(REPO, DOCP, "RWC_PREREGISTRATION_FREEZE_MANIFEST_V6.yaml")
    with open(out, "w") as f:
        f.write(json.dumps(manifest, indent=2) + "\n")
    print("WROTE=%s artifacts=%d inventory_digest=%s" % (out, len(artifacts), inv))
    return 0


if __name__ == "__main__":
    sys.exit(main())
