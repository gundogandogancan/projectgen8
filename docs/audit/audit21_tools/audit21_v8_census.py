#!/usr/bin/env python3
# AUDIT21 INDEPENDENT V8 FREEZE CENSUS — authored by the independent CHIEF SECURITY AUDITOR.
#
# This is an AUDITOR-OWN re-derivation. It does NOT call the builder's manifest generator and does NOT
# trust any builder count. It independently:
#   (1) parses the 309 frozen artifacts from RWC_PREREGISTRATION_FREEZE_MANIFEST_V8.yaml (STRICT JSON),
#   (2) recomputes each artifact's sha256 from the LIVE filesystem and compares to the manifest,
#   (3) recomputes the frozen_inventory_digest with the CANONICAL algorithm the verifier uses
#       (RWCCorpusEntryVerifierV3.inventoryDigest): sha256( sorted("path:sha256").join("\n") ),
#       and compares to the declared c64f7632… ,
#   (4) proves the anchor->candidate per-path git diff is EMPTY for every hashed frozen artifact
#       (no post-anchor drift of frozen surfaces),
#       allowing ONLY the manifest + remediation report + post-audit AUDIT* test files to differ,
#   (5) proves .build is fully untracked (git ls-files has zero .build entries),
#   (6) prints a machine-checkable summary.
#
# ZERO-DATA: reads only the frozen methodology tree; creates nothing operational.

import hashlib, json, subprocess, sys, os

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
MANIFEST_REL = "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V8.yaml"
ANCHOR = "3abb24a22b63a734539fb5aebe92c1953325b590"
CANDIDATE = "104dad450f3c96e13cb0b785c7c58b21f6b793c5"
EXPECTED_DIGEST = "c64f7632bb892f8fb519050de3dc86aad576078c089f85992e7dcdfd0651fb33"
EXPECTED_COUNT = 309


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def git(*args):
    return subprocess.run(["git", "-C", REPO, *args], capture_output=True, text=True)


def main():
    failures = []
    manifest_path = os.path.join(REPO, MANIFEST_REL)
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)  # STRICT JSON in .yaml

    arts = manifest["artifacts"]
    # hash_exempt files are carried in the digest with their DECLARED sha string (e.g. "MUTABLE_BY_LAW")
    # and are EXEMPT from the live file-drift check — exactly as RWCCorpusEntryVerifierV6 does
    # (pathToSHA[path]=sha for all; `if hashExempt.contains(path) { continue }` skips the drift check).
    hash_exempt = set(manifest["surface_rules"]["hash_exempt"])
    print(f"[1] manifest artifact count = {len(arts)} (expected {EXPECTED_COUNT}); hash_exempt = {len(hash_exempt)}")
    if len(arts) != EXPECTED_COUNT:
        failures.append(f"artifact count {len(arts)} != {EXPECTED_COUNT}")

    # (2) + (3): build path->sha for the digest from DECLARED shas (verifier semantics); independently
    # VERIFY every NON-exempt declared sha against the live filesystem hash.
    path_to_sha = {}          # path -> DECLARED sha (used for the digest, mirroring the verifier)
    live_verified = 0
    live_drift = []
    missing = []
    for a in arts:
        p, declared = a["path"], a["sha256"]
        path_to_sha[p] = declared
        if p in hash_exempt:
            continue
        full = os.path.join(REPO, p)
        if not os.path.isfile(full):
            missing.append(p)
            continue
        live = sha256_file(full)
        live_verified += 1
        if live != declared:
            live_drift.append((p, declared, live))
    print(f"[2] non-exempt files independently hashed & verified = {live_verified}; "
          f"missing = {len(missing)}; drift = {len(live_drift)}")
    if missing:
        failures.append(f"missing frozen files: {missing[:5]}{'...' if len(missing) > 5 else ''}")
    if live_drift:
        failures.append(f"live sha != manifest sha for {len(live_drift)} file(s): {live_drift[:3]}")

    # canonical inventory digest = sha256( sorted('path:sha').join('\n') ) over DECLARED shas (verifier law)
    canonical = "\n".join(f"{k}:{path_to_sha[k]}" for k in sorted(path_to_sha))
    recomputed = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    manifest_declared = manifest["frozen_inventory_digest"]
    print(f"[3] recomputed inventory digest = {recomputed}")
    print(f"    manifest declared digest     = {manifest_declared}")
    print(f"    mandate expected digest       = {EXPECTED_DIGEST}")
    if recomputed != EXPECTED_DIGEST:
        failures.append(f"recomputed digest {recomputed} != expected {EXPECTED_DIGEST}")
    if manifest_declared != EXPECTED_DIGEST:
        failures.append(f"manifest digest {manifest_declared} != expected {EXPECTED_DIGEST}")

    # (4) anchor->candidate per-path diff EMPTY for every hashed frozen artifact.
    r = git("rev-parse", "HEAD")
    head = r.stdout.strip()
    print(f"[4] HEAD = {head} (candidate {CANDIDATE})")
    if head != CANDIDATE:
        failures.append(f"HEAD {head} != candidate {CANDIDATE}")
    # the manifest + remediation report are LAWFULLY allowed to land AFTER the anchor (post_anchor_allowed);
    # every OTHER frozen artifact must be byte-identical anchor..candidate (per-path diff EMPTY).
    post_anchor_allowed = set(manifest["surface_rules"]["post_anchor_allowed"])
    drifted_paths = []
    for p in sorted(path_to_sha):
        if p in post_anchor_allowed:
            continue
        d = git("diff", "--name-only", f"{ANCHOR}..{CANDIDATE}", "--", p)
        if d.stdout.strip():
            drifted_paths.append(p)
    print(f"    anchor->candidate drifted frozen artifacts (excl. post_anchor_allowed) = {len(drifted_paths)}")
    if drifted_paths:
        failures.append(f"frozen artifacts changed anchor..candidate: {drifted_paths[:5]}")

    # (5) .build fully untracked.
    r = git("ls-files", "--", "*.build/*", ".build", ".build/*")
    build_tracked = [l for l in r.stdout.splitlines() if l.strip()]
    print(f"[5] tracked .build entries = {len(build_tracked)} (expected 0)")
    if build_tracked:
        failures.append(f".build tracked entries present: {len(build_tracked)}")

    print("\n==== CENSUS RESULT ====")
    if failures:
        for fl in failures:
            print("  FAIL:", fl)
        print("CENSUS: FAIL")
        sys.exit(1)
    print("CENSUS: PASS — 309 artifacts, digest c64f7632 recomputed independently, no anchor drift, .build untracked")
    sys.exit(0)


if __name__ == "__main__":
    main()
