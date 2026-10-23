#!/usr/bin/env python3
# AUDIT18 independent Freeze V5 census (mandate section 38).
# Recounts all artifacts, re-hashes every non-exempt artifact from the LIVE tree,
# recomputes the frozen inventory digest with the V3 algorithm
# (sha256 over newline-joined sorted "path:sha" lines), and reports the live
# manifest + master-manifest SHA-256 values. ASCII only. Python 3.9, stdlib only.
import json, hashlib, sys, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
MANIFEST = os.path.join(ROOT, "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V5.yaml")
MASTER = os.path.join(ROOT, "docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml")

def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        h.update(f.read())
    return h.hexdigest()

def main():
    with open(MANIFEST, "rb") as f:
        raw = f.read()
    d = json.loads(raw)
    arts = d["artifacts"]
    exempt = set(d["surface_rules"]["hash_exempt"])
    paths = [a["path"] for a in arts]
    p2s = {}
    drift, missing = [], []
    for a in arts:
        p, s = a["path"], a["sha256"]
        p2s[p] = s
        if p in exempt:
            continue
        fp = os.path.join(ROOT, p)
        if not os.path.exists(fp):
            missing.append(p)
            continue
        if sha256_file(fp) != s:
            drift.append(p)
    inv = hashlib.sha256("\n".join("%s:%s" % (k, p2s[k]) for k in sorted(p2s)).encode()).hexdigest()
    out = {
        "artifact_entries": len(arts),
        "unique_paths": len(set(paths)),
        "duplicate_paths": sorted(set(p for p in paths if paths.count(p) > 1)),
        "hash_exempt": sorted(exempt),
        "drift": drift,
        "missing": missing,
        "recomputed_inventory_digest": inv,
        "manifest_declared_digest": d["frozen_inventory_digest"],
        "inventory_digest_match": inv == d["frozen_inventory_digest"],
        "live_freeze_manifest_sha256": hashlib.sha256(raw).hexdigest(),
        "live_master_manifest_sha256": sha256_file(MASTER),
        "methodology_anchor_commit": d["methodology_anchor_commit"],
        "governing_control_plane_lock": d["governing_control_plane_lock"],
        "governed_roots": d["surface_rules"]["governed_roots"],
        "post_audit_allowances": d["surface_rules"]["post_audit_allowances"],
    }
    print(json.dumps(out, indent=2))

if __name__ == "__main__":
    main()
