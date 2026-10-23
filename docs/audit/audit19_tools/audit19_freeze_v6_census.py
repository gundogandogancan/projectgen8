#!/usr/bin/env python3
# AUDIT19 independent freeze V6 census (§42): recompute EVERY artifact hash from the live tree,
# recompute the inventory digest, and check per-path git diff anchor..candidate emptiness.
# Independent implementation — does NOT import or reuse the builder generator.
import hashlib, json, os, subprocess, sys

REPO = "/Users/dogancangundogan/PROJECTGEN8/Gen8"
MANIFEST = os.path.join(REPO, "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V6.yaml")
ANCHOR = "31267a4e34e6639fcca0448694425dfabfc025a2"
CANDIDATE = "f30b39322500da6e9e8602645e287cd41a61018e"

def sha256_file(rel):
    with open(os.path.join(REPO, rel), "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()

def main():
    with open(MANIFEST, "r", encoding="utf-8") as f:
        m = json.load(f)
    artifacts = m["artifacts"]
    print("artifact_count=%d (builder claim: count entries yourself)" % len(artifacts))
    print("declared_inventory_digest=%s" % m["frozen_inventory_digest"])

    mismatches, missing, exempt_count = [], [], 0
    for a in artifacts:
        p, declared = a["path"], a["sha256"]
        if declared in ("SELF", "MUTABLE_BY_LAW"):
            exempt_count += 1
            continue
        full = os.path.join(REPO, p)
        if not os.path.exists(full):
            missing.append(p); continue
        actual = sha256_file(p)
        if actual != declared:
            mismatches.append((p, declared, actual))
    print("hash_exempt_entries=%d" % exempt_count)
    print("missing_files=%d %s" % (len(missing), missing[:5]))
    print("hash_mismatches=%d" % len(mismatches))
    for p, d, act in mismatches[:10]:
        print("  MISMATCH %s declared=%s actual=%s" % (p, d, act))

    # inventory digest recompute over declared entries (generator law: path:sha256 joined by \n)
    inv = hashlib.sha256("\n".join("%s:%s" % (a["path"], a["sha256"]) for a in artifacts)
                         .encode()).hexdigest()
    print("recomputed_inventory_digest=%s" % inv)
    print("inventory_digest_match=%s" % (inv == m["frozen_inventory_digest"]))

    # anchor law: per-path git diff anchor..candidate EMPTY for every frozen artifact (except
    # post_anchor_allowed).
    allowed_post_anchor = set(m["surface_rules"]["post_anchor_allowed"])
    drift = []
    for a in artifacts:
        p = a["path"]
        if p in allowed_post_anchor:
            continue
        r = subprocess.run(["git", "diff", "--name-only", "%s..%s" % (ANCHOR, CANDIDATE), "--", p],
                           cwd=REPO, capture_output=True, text=True)
        if r.stdout.strip():
            drift.append(p)
    print("anchor_to_candidate_frozen_drift=%d %s" % (len(drift), drift[:10]))

    ok = (not mismatches and not missing and inv == m["frozen_inventory_digest"] and not drift)
    print("CENSUS_RESULT=%s" % ("CLEAN" if ok else "DRIFT_DETECTED"))
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
