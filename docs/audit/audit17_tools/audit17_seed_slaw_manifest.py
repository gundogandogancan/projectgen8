#!/usr/bin/env python3
# AUDIT17_RWC_PRE14_R3_REAUDIT - independent cross-language tool (Python 3.9, stdlib only).
# 1) Independent implementation of the frozen V4 length-prefixed seed law (A16-F8 closure check):
#    emits seed64 values for an adversarial vector battery. The Swift probe family hardcodes these
#    values and asserts equality against the builder's Swift implementation (two independent
#    implementations agreeing) and asserts the alias pairs are DISTINCT.
# 2) Independent analytical S law (A16-F23 closure check): SE(alpha,S)=sqrt(alpha*(1-alpha)/S),
#    grid S+1 in {10^k} with (S+1)%20==0; smallest passing candidate must be S=9999.
# 3) Independent freeze-manifest V4 recomputation: sha256 of every non-exempt artifact (live tree,
#    verified clean vs HEAD by the auditor), inventory digest, manifest file sha256, class census.
# 4) Wilson 95% CI helper used to cross-check the Swift stat-replication outputs.
# ZERO-DATA: no media, labels, predictions; synthetic strings and repo artifact hashes only.
# NOTE: source is ASCII-only; unicode vectors use \u escapes (NFC e-acute vs NFD e+combining).
import hashlib, struct, json, math, os

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
MANIFEST = "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V4.yaml"

def lp(b):
    return struct.pack(">I", len(b)) + b

def seed64(parts):
    out = lp("GEN8-RWC-CAL-V4".encode())
    out += struct.pack(">I", len(parts))
    for p in parts:
        out += lp(p.encode("utf-8"))
    return int.from_bytes(hashlib.sha256(out).digest()[:8], "big")

def wilson(k, n, z=1.959963984540054):
    if n == 0:
        return (0.0, 1.0)
    p = k / n
    den = 1 + z * z / n
    c = p + z * z / (2 * n)
    w = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return ((c - w) / den, (c + w) / den)

def main():
    out = {"tool": "audit17_seed_slaw_manifest", "family": "AUDIT17_RWC_PRE14_R3_REAUDIT"}

    vectors = [
        ["a|b", "c"], ["a", "b|c"], ["ab", "c"], ["a", "bc"], [], [""], ["", ""],
        ["", "a"], ["a", ""], ["\u00e9"], ["e\u0301"], ["x", "y"], ["L" * 100000],
        ["eval", "deadbeef", "risk_ECE", "primary"],
    ]
    out["seed_vectors"] = [{"parts_json": json.dumps(v), "seed64": str(seed64(v))} for v in vectors]
    aliases = [(0, 1), (2, 3), (4, 5), (5, 6), (7, 8), (9, 10)]
    out["alias_pairs_distinct"] = all(
        seed64(vectors[a]) != seed64(vectors[b]) for a, b in aliases)

    rows = {}
    smallest = None
    for k in range(2, 7):
        s = 10 ** k - 1
        se = math.sqrt(0.05 * 0.95 / s)
        ok = ((s + 1) % 20 == 0) and (se <= 0.0025)
        rows["S%d" % s] = {"se_at_alpha": round(se, 6), "grid_ok": (s + 1) % 20 == 0,
                           "meets_0.0025": se <= 0.0025}
        if ok and smallest is None:
            smallest = s
    out["s_law"] = {"rows": rows, "smallest_passing": smallest,
                    "s999_rejected": math.sqrt(0.05 * 0.95 / 999) > 0.0025,
                    "s9999_selected": smallest == 9999}

    with open(os.path.join(REPO, MANIFEST), "rb") as f:
        mbytes = f.read()
    m = json.loads(mbytes)
    exempt = set(m["surface_rules"]["hash_exempt"])
    census = {}
    drift = []
    path_to_sha = {}
    for a in m["artifacts"]:
        census[a["class"]] = census.get(a["class"], 0) + 1
        path_to_sha[a["path"]] = a["sha256"]
        if a["path"] in exempt:
            continue
        with open(os.path.join(REPO, a["path"]), "rb") as f:
            h = hashlib.sha256(f.read()).hexdigest()
        if h != a["sha256"]:
            drift.append(a["path"])
    inv_lines = "\n".join("%s:%s" % (p, path_to_sha[p]) for p in sorted(path_to_sha))
    out["freeze_v4"] = {
        "manifest_sha256": hashlib.sha256(mbytes).hexdigest(),
        "artifact_count": len(m["artifacts"]),
        "class_census": census,
        "drift_paths": drift,
        "recomputed_inventory_digest": hashlib.sha256(inv_lines.encode()).hexdigest(),
        "declared_inventory_digest": m["frozen_inventory_digest"],
        "inventory_digest_match":
            hashlib.sha256(inv_lines.encode()).hexdigest() == m["frozen_inventory_digest"],
        "methodology_anchor_commit": m["methodology_anchor_commit"],
        "governing_control_plane_lock": m["governing_control_plane_lock"],
        "post_audit_allowed_prefixes": m["surface_rules"]["post_audit_allowed_prefixes"],
        "governed_roots": m["surface_rules"]["governed_roots"],
    }

    stats_path = os.path.join(REPO, "docs/audit/audit17_tools/results/audit17_stat_replication.json")
    if os.path.exists(stats_path):
        with open(stats_path) as f:
            stats = json.load(f)
        checks = []
        for section in ("type_I", "power"):
            for cell, row in sorted(stats.get(section, {}).items()):
                lo, hi = wilson(row["rejects"], row["trials"])
                checks.append({"cell": cell, "rejects": row["rejects"], "trials": row["trials"],
                               "wilson95": [round(lo, 4), round(hi, 4)],
                               "swift_wilson95": [row["wilson_lo"], row["wilson_hi"]],
                               "agree": abs(lo - row["wilson_lo"]) < 5e-4 and
                                        abs(hi - row["wilson_hi"]) < 5e-4})
        out["wilson_crosscheck_all_agree"] = all(c["agree"] for c in checks) if checks else None
        out["wilson_crosscheck_rows"] = checks

    dest = os.path.join(REPO, "docs/audit/audit17_tools/results/audit17_seed_slaw_manifest.json")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "w") as f:
        json.dump(out, f, indent=2, sort_keys=True)
    print("WROTE", dest)
    print("seed alias distinct:", out["alias_pairs_distinct"])
    print("S law: s999_rejected", out["s_law"]["s999_rejected"],
          "s9999_selected", out["s_law"]["s9999_selected"])
    print("freeze artifacts:", out["freeze_v4"]["artifact_count"],
          "digest match:", out["freeze_v4"]["inventory_digest_match"],
          "drift:", out["freeze_v4"]["drift_paths"])
    print("manifest sha256:", out["freeze_v4"]["manifest_sha256"])
    for row in out["seed_vectors"]:
        print("SEED", row["parts_json"], row["seed64"])

if __name__ == "__main__":
    main()
