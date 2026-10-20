#!/usr/bin/env python3
# FREEZE MANIFEST V3 GENERATOR (A15-F8 closure; frozen methodology tooling).
#
# NON-CIRCULAR TWO-PHASE LAW: run AFTER the METHODOLOGY ANCHOR COMMIT with that commit's SHA as
# argv[1]; the manifest is committed in a LATER commit, so the anchor tree never needs to contain
# the manifest that describes it. Deterministic: output is a pure function of the working tree +
# the anchor SHA (sorted paths, fixed formatting, no clock, no hash()).
#
# Usage: python3 generate_freeze_manifest_v3.py <methodology_anchor_commit_sha>
import hashlib
import json
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
DOC_ROOT = "docs/calibration/preregistration"
CODE_SCAN = [
    {"root": "packages/GuardianKit/Sources/GuardianCore",
     "prefixes": ["RWC", "Calibration", "RealWorld"]},
    {"root": "packages/GuardianKit/Tests/GuardianCoreTests",
     "prefixes": ["RWC", "Calibration"]},
]
POST_ANCHOR_ALLOWED = [
    DOC_ROOT + "/RWC_PREREGISTRATION_FREEZE_MANIFEST_V3.yaml",
    DOC_ROOT + "/RWC_PREREGISTRATION_R2_REMEDIATION_REPORT.md",
]
HASH_EXEMPT = [
    DOC_ROOT + "/RWC_PREREGISTRATION_FREEZE_MANIFEST_V3.yaml",          # SELF (post-anchor)
    DOC_ROOT + "/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml",             # MUTABLE_BY_LAW status record
]
METHODOLOGY_CODE = {
    "packages/GuardianKit/Sources/GuardianCore/RWCRightsV2.swift",
    "packages/GuardianKit/Sources/GuardianCore/RWCAssetIdentityV1.swift",
    "packages/GuardianKit/Sources/GuardianCore/CalibrationRunPreparationV1.swift",
    "packages/GuardianKit/Sources/GuardianCore/CalibrationIntegrityV1.swift",
    "packages/GuardianKit/Sources/GuardianCore/RealWorldCalibrationExecutorV1.swift",
    "packages/GuardianKit/Tests/GuardianCoreTests/RWCCalibrationMethodologyV3.swift",
    "packages/GuardianKit/Tests/GuardianCoreTests/RWCPowerDerivationV3.swift",
    "packages/GuardianKit/Tests/GuardianCoreTests/RWCCorpusEntryVerifierV2.swift",
    "packages/GuardianKit/Tests/GuardianCoreTests/RWCStatisticsV1.swift",
    DOC_ROOT + "/tools/rwc_methodology_v3_differential.py",
    DOC_ROOT + "/tools/generate_freeze_manifest_v3.py",
}
SUPERSEDED = {
    "packages/GuardianKit/Sources/GuardianCore/RWCAssetRightsLedgerV1.swift",
    "packages/GuardianKit/Tests/GuardianCoreTests/RWCCalibrationMethodologyV1.swift",
    DOC_ROOT + "/tools/power_derivation.py",
    DOC_ROOT + "/RWC_FROZEN_GATES.yaml",
    DOC_ROOT + "/RWC_CALIBRATION_POWER_PREREG.yaml",
    DOC_ROOT + "/RWC_SLICE_DEFINITIONS.yaml",
    DOC_ROOT + "/RWC_PREREGISTRATION_FREEZE_MANIFEST.yaml",
    DOC_ROOT + "/RWC_PREREGISTRATION_FREEZE_MANIFEST_V2.yaml",
}


def sha256(path):
    with open(os.path.join(REPO, path), "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def scan():
    found = set()
    doc_abs = os.path.join(REPO, DOC_ROOT)
    for base, _, names in os.walk(doc_abs):
        for n in names:
            if n.startswith("."):
                continue  # OS metadata (.DS_Store etc.) is never methodology surface
            rel = os.path.relpath(os.path.join(base, n), REPO).replace(os.sep, "/")
            found.add(rel)
    for entry in CODE_SCAN:
        root_abs = os.path.join(REPO, entry["root"])
        for n in sorted(os.listdir(root_abs)):
            if any(n.startswith(p) for p in entry["prefixes"]):
                if os.path.isfile(os.path.join(root_abs, n)):
                    found.add(entry["root"] + "/" + n)
    return found


def classify(path):
    if path in METHODOLOGY_CODE:
        return "METHODOLOGY_CODE"
    if path in SUPERSEDED:
        return "SUPERSEDED_FROZEN_HISTORY"
    if path in HASH_EXEMPT:
        return "MUTABLE_BY_LAW" if "MASTER_MANIFEST" in path else "SELF"
    if path.startswith(DOC_ROOT + "/packets/") or path.startswith(DOC_ROOT + "/handbook/") \
            or path.startswith(DOC_ROOT + "/protocols/"):
        return "FROZEN_NORMATIVE"
    if path.startswith("packages/GuardianKit/Sources/"):
        return "LEGACY_ENGINEERING_FROZEN"
    if path.endswith(".swift"):
        return "TEST_EVIDENCE"
    return "FROZEN_NORMATIVE"


def main():
    if len(sys.argv) < 2 or len(sys.argv[1]) != 40:
        print("usage: generate_freeze_manifest_v3.py <anchor_sha40>")
        return 1
    anchor = sys.argv[1]
    paths = sorted(scan() - set(POST_ANCHOR_ALLOWED) | {HASH_EXEMPT[1]})
    artifacts = []
    for p in paths:
        exempt = p in HASH_EXEMPT
        artifacts.append({
            "path": p,
            "sha256": "SELF" if (exempt and "FREEZE_MANIFEST_V3" in p) else
                      ("MUTABLE_BY_LAW" if exempt else sha256(p)),
            "class": classify(p),
        })
    inv_digest = hashlib.sha256("\n".join(
        "%s:%s" % (a["path"], a["sha256"]) for a in sorted(artifacts, key=lambda a: a["path"])
    ).encode("utf-8")).hexdigest()
    manifest = {
        "freeze_version": "rwc-preregistration-freeze-v3",
        "format_law": "STRICT JSON in .yaml. FROZEN.",
        "supersedes": "rwc-preregistration-freeze-v2 (byte-preserved FAILED-candidate history)",
        "supersession_reason": "AUDIT15 FIX REQUIRED (A15-F8 self-contradictory commit binding; A15-F13/F15 boundary gaps). Non-circular two-phase binding: all frozen files are FINAL in methodology_anchor_commit; this manifest is generated and committed AFTER the anchor.",
        "methodology_anchor_commit": anchor,
        "anchor_law": "For every hashed artifact: git diff <methodology_anchor_commit>..<candidate> -- <path> MUST be empty. Only this manifest, the builder report, tests and candidate metadata may land after the anchor. Any frozen-surface change requires a NEW anchor + NEW manifest + NEW independent PRE-14 audit.",
        "tag_identity_law": "The candidate's annotated TAG OBJECT SHA is pinned by the independent audit and by the future RWC_PRE14_PASS_LOCK (schema: RWC_PRE14_PASS_LOCK_SCHEMA.yaml). It is NEVER fabricated here (the tag does not exist at freeze time).",
        "historical_truth": "v1/v2 methodology is RECOVERABLE from original candidate commits + v1/v2 manifest hashes + git history + supersession records; no claim of live byte-identity is made for superseded files that were lawfully superseded (A15-F20).",
        "pre_data_declaration": "corpus_count=0, annotator_count=0, real_fit_count=0, heldout_open_count=0, data_visibility=false. No real data influenced any frozen choice. No PASS lock exists.",
        "surface_rules": {
            "doc_root": DOC_ROOT,
            "code_scan": CODE_SCAN,
            "post_anchor_allowed": POST_ANCHOR_ALLOWED,
            "hash_exempt": HASH_EXEMPT,
            "law": "SET EQUALITY both directions at corpus entry: scanned governed surface == artifact paths UNION post_anchor_allowed. New, removed or renamed files are drift (RWCCorpusEntryVerifierV2).",
        },
        "frozen_inventory_digest": inv_digest,
        "artifacts": artifacts,
    }
    out = os.path.join(REPO, DOC_ROOT, "RWC_PREREGISTRATION_FREEZE_MANIFEST_V3.yaml")
    with open(out, "w") as f:
        f.write(json.dumps(manifest, indent=2) + "\n")
    print("WROTE=%s artifacts=%d inventory_digest=%s" % (out, len(artifacts), inv_digest))
    return 0


if __name__ == "__main__":
    sys.exit(main())
