#!/usr/bin/env python3
"""
AUDIT22T independent V10 census. Author: AUDIT22T independent auditor (clean session).
Read-only. Recomputes, from the LIVE worktree and git objects, WITHOUT trusting the
builder's generator:
  (1) artifact count in RWC_PREREGISTRATION_FREEZE_MANIFEST_V10.yaml,
  (2) per-path live sha256 == manifest sha256 (hash_exempt skipped per surface_rules),
  (3) inventory digest recompute == declared frozen_inventory_digest,
      formula == sha256( "\n".join(sorted("path:sha")) )  [matches RWCCorpusEntryVerifierV3.inventoryDigest],
  (4) V8 + V9 freeze-manifest blobs byte-identical anchor..candidate (preservation),
  (5) per-path git diff anchor..candidate EMPTY for every frozen artifact (anchor law).
Exit 0 only if ALL checks pass.
"""
import hashlib, json, subprocess, sys, os

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
CAND = "df952d260567c8ffcdde0fed83f8f36617b94c62"
ANCHOR = "6cdfb3ff23a51d799bb89a625c7f815a0f56f5f6"
MANIFEST = "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V10.yaml"
V8 = "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V8.yaml"
V9 = "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V9.yaml"
EXPECTED_DIGEST = "464bffe815c041418c0176829fef555ffd005de748d1bf4ec0ac3b99a05295ba"
EXPECTED_COUNT = 320

def sh(args):
    return subprocess.run(["git", "-C", REPO] + args, capture_output=True, text=True)

def sha256_file(path):
    with open(os.path.join(REPO, path), "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()

def blob_at(commit, path):
    r = subprocess.run(["git", "-C", REPO, "show", f"{commit}:{path}"], capture_output=True)
    return r.stdout if r.returncode == 0 else None

def main():
    fails = []
    with open(os.path.join(REPO, MANIFEST), "rb") as f:
        raw = f.read()
    m = json.loads(raw)
    arts = m["artifacts"]
    hash_exempt = set(m["surface_rules"]["hash_exempt"])

    # (1) count
    print(f"[1] artifact count = {len(arts)} (expected {EXPECTED_COUNT})")
    if len(arts) != EXPECTED_COUNT:
        fails.append(f"artifact count {len(arts)} != {EXPECTED_COUNT}")

    # (2) per-path live sha + (3) build digest map
    path_to_sha = {}
    drift = 0
    missing = 0
    for a in arts:
        p, declared = a["path"], a["sha256"]
        path_to_sha[p] = declared
        if p in hash_exempt:
            continue
        full = os.path.join(REPO, p)
        if not os.path.exists(full):
            missing += 1
            fails.append(f"MISSING live file: {p}")
            continue
        live = sha256_file(p)
        if live != declared:
            drift += 1
            fails.append(f"DRIFT {p}: live {live[:12]} != manifest {declared[:12]}")
    print(f"[2] per-path live hash: {len(arts)-len(hash_exempt&set(path_to_sha))} hashed; drift={drift} missing={missing}")

    # (3) inventory digest recompute (verifier formula)
    recomputed = hashlib.sha256(
        "\n".join(sorted(f"{k}:{v}" for k, v in path_to_sha.items())).encode()
    ).hexdigest()
    declared_digest = m["frozen_inventory_digest"]
    print(f"[3] recomputed digest = {recomputed}")
    print(f"    declared digest   = {declared_digest}")
    print(f"    expected (mandate)= {EXPECTED_DIGEST}")
    if recomputed != declared_digest:
        fails.append("recomputed digest != declared manifest digest")
    if declared_digest != EXPECTED_DIGEST:
        fails.append("declared digest != mandate expected digest")

    # (4) V8/V9 preservation anchor..candidate (and candidate vs live)
    for label, path in [("V8", V8), ("V9", V9)]:
        a_blob = blob_at(ANCHOR, path)
        c_blob = blob_at(CAND, path)
        if a_blob is None or c_blob is None:
            fails.append(f"{label} manifest blob missing at anchor/candidate")
            print(f"[4] {label}: MISSING at anchor or candidate")
            continue
        same = (a_blob == c_blob)
        print(f"[4] {label} anchor==candidate bytes: {same} ({hashlib.sha256(c_blob).hexdigest()[:12]})")
        if not same:
            fails.append(f"{label} manifest changed anchor..candidate")

    # (5) per-path git diff anchor..candidate EMPTY for every frozen artifact
    post_anchor = set(m["surface_rules"]["post_anchor_allowed"])
    diffed = 0
    non_empty = 0
    for a in arts:
        p = a["path"]
        if p in post_anchor:
            continue  # lawfully may follow the anchor
        r = sh(["diff", "--quiet", ANCHOR, CAND, "--", p])
        diffed += 1
        if r.returncode != 0:
            non_empty += 1
            fails.append(f"anchor..candidate DIFF non-empty for frozen artifact: {p}")
    print(f"[5] per-path anchor..candidate diff: checked {diffed} frozen artifacts; non-empty={non_empty}")
    print(f"    (manifest itself is post_anchor_allowed, excluded from [5])")

    print()
    if fails:
        print(f"CENSUS RESULT: FAIL ({len(fails)} issue(s))")
        for f in fails:
            print("  -", f)
        sys.exit(1)
    print("CENSUS RESULT: PASS — 320 artifacts, digest match, V8/V9 preserved, anchor law clean.")
    sys.exit(0)

if __name__ == "__main__":
    main()
