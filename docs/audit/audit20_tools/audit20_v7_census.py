#!/usr/bin/env python3
"""AUDIT20 §3 — INDEPENDENT V7 freeze census (red-team recomputation).

Independent of the builder's generator. Reproduces, from first principles:
  - artifact count + unique-path set
  - live + candidate-blob sha256 for every non-exempt artifact
  - inventory digest (replicating RWCCorpusEntryVerifierV3.inventoryDigest exactly:
        sha256( "\\n".join(sorted("path:sha256")) ), over ALL artifacts incl. hash_exempt)
  - surface set equality per governed root (live + git-tree) with scoped allowances
  - anchor->candidate changed-path check
  - negative tests (extra file + byte tamper) in a throwaway /tmp copy

Usage: python3 audit20_v7_census.py            (census against the real repo, read-only)
       python3 audit20_v7_census.py --selftest (negative tests only, in /tmp)
"""
import hashlib, json, os, subprocess, sys, tempfile, shutil

REPO = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                      capture_output=True, text=True).stdout.strip()
CANDIDATE = "47ca59e29f499d79deac21024ef93b5c7d711a05"
ANCHOR = "e40a6efb9a733030e7e65f309cf0c71bc38c178d"
MANIFEST_REL = "docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V7.yaml"
R6_REPORT_REL = "docs/calibration/preregistration/RWC_PREREGISTRATION_R6_REMEDIATION_REPORT.md"
EXPECT_DIGEST = "8a1751c397523d743fe77d9dd7c8de6a4a364bc625217fb123b18891f5619a57"
EXPECT_COUNT = 299


def sha256_hex(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def git_show_blob(repo, commit, path):
    r = subprocess.run(["git", "-C", repo, "show", f"{commit}:{path}"],
                       capture_output=True)
    return r.stdout if r.returncode == 0 else None


def git_ls_tree(repo, commit, root):
    r = subprocess.run(["git", "-C", repo, "ls-tree", "-r", "--name-only", commit, root],
                       capture_output=True, text=True)
    return set(l for l in r.stdout.splitlines() if l) if r.returncode == 0 else set()


def live_scan(repo, root):
    """Recursive live scan; records symlinks separately."""
    files, symlinks = set(), []
    base = os.path.join(repo, root)
    for dirpath, dirnames, filenames in os.walk(base):
        if ".git" in dirnames:
            dirnames.remove(".git")
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, repo)
            if os.path.islink(full):
                symlinks.append(rel)
                continue
            files.add(rel)
        for dn in list(dirnames):
            full = os.path.join(dirpath, dn)
            if os.path.islink(full):
                symlinks.append(os.path.relpath(full, repo))
                dirnames.remove(dn)
    return files, symlinks


def inventory_digest(path_to_sha: dict) -> str:
    lines = [f"{p}:{path_to_sha[p]}" for p in sorted(path_to_sha.keys())]
    return sha256_hex("\n".join(lines).encode("utf-8"))


def allowed(path, inventory, post_anchor, allowances):
    if path in inventory:
        return True
    if path in post_anchor:
        return True
    name = path.split("/")[-1]
    for a in allowances:
        if path.startswith(a["root"] + "/") and name.startswith(a["filename_prefix"]):
            return True
    return False


def load_manifest(repo):
    with open(os.path.join(repo, MANIFEST_REL)) as f:
        return json.load(f)


def census(repo, out):
    def log(*a):
        line = " ".join(str(x) for x in a)
        print(line)
        out.append(line)

    m = load_manifest(repo)
    arts = m["artifacts"]
    sr = m["surface_rules"]
    governed = sr["governed_roots"]
    extra_arts = set(sr.get("extra_artifacts", []))
    post_anchor = set(sr.get("post_anchor_allowed", []))
    allowances = sr.get("post_audit_allowances", [])
    hash_exempt = set(sr.get("hash_exempt", []))

    log("=== AUDIT20 §3 INDEPENDENT V7 CENSUS ===")
    log("repo:", repo, "candidate:", CANDIDATE)

    # (2) count + unique paths
    paths = [a["path"] for a in arts]
    log("[2] artifact_count =", len(arts), "(expect", EXPECT_COUNT, ") ->",
        "MATCH" if len(arts) == EXPECT_COUNT else "MISMATCH")
    dupes = [p for p in set(paths) if paths.count(p) > 1]
    log("[2] unique_paths =", len(set(paths)), "duplicates:", dupes if dupes else "none")

    # (3) live + candidate drift
    path_to_sha = {}
    live_drift, cand_drift, missing_live, missing_cand = [], [], [], []
    for a in arts:
        p, declared = a["path"], a["sha256"]
        path_to_sha[p] = declared
        if p in hash_exempt:
            continue
        full = os.path.join(repo, p)
        if not os.path.exists(full):
            missing_live.append(p)
        else:
            with open(full, "rb") as f:
                if sha256_hex(f.read()) != declared:
                    live_drift.append(p)
        blob = git_show_blob(repo, CANDIDATE, p)
        if blob is None:
            missing_cand.append(p)
        elif sha256_hex(blob) != declared:
            cand_drift.append(p)
    log("[3] non-exempt checked:", len([p for p in path_to_sha if p not in hash_exempt]))
    log("[3] live_drift:", live_drift or "none")
    log("[3] candidate_blob_drift:", cand_drift or "none")
    log("[3] missing_live:", missing_live or "none")
    log("[3] missing_candidate:", missing_cand or "none")
    log("[3] hash_exempt (manifest-sha trusted, not re-hashed):", sorted(hash_exempt))

    # candidate-blob binding of the manifest itself (A18-F5 law)
    man_live = open(os.path.join(repo, MANIFEST_REL), "rb").read()
    man_cand = git_show_blob(repo, CANDIDATE, MANIFEST_REL)
    log("[3] manifest live sha256 =", sha256_hex(man_live))
    log("[3] manifest candidate-blob sha256 =",
        sha256_hex(man_cand) if man_cand else "MISSING",
        "->", "MATCH" if man_cand and sha256_hex(man_cand) == sha256_hex(man_live) else "MISMATCH")

    # (4) inventory digest
    recomputed = inventory_digest(path_to_sha)
    log("[4] recomputed_inventory_digest =", recomputed)
    log("[4] manifest field               =", m["frozen_inventory_digest"])
    log("[4] expected (builder claim)      =", EXPECT_DIGEST)
    log("[4] digest vs manifest_field:", "MATCH" if recomputed == m["frozen_inventory_digest"] else "MISMATCH")
    log("[4] digest vs builder_claim :", "MATCH" if recomputed == EXPECT_DIGEST else "MISMATCH")

    # (5) surface set equality
    inventory = set(path_to_sha.keys())
    log("[5] anchor field =", m["methodology_anchor_commit"],
        "->", "MATCH" if m["methodology_anchor_commit"] == ANCHOR else "MISMATCH")
    log("[5] governing field =", m["governing_control_plane_lock"])
    all_symlinks = []
    for root in governed:
        live, symlinks = live_scan(repo, root)
        all_symlinks += symlinks
        tree = git_ls_tree(repo, CANDIDATE, root)
        inv_here = {p for p in inventory if p.startswith(root + "/")}
        for stage, found in [("live", live), ("git-tree", tree)]:
            extra = sorted(f for f in found
                           if not allowed(f, inventory, post_anchor, allowances))
            missing = sorted(inv_here - found)
            log(f"[5] {root} [{stage}] extra(unauthorized)=", extra or "none")
            log(f"[5] {root} [{stage}] missing=", missing or "none")
    # extra_artifacts (single files outside governed roots)
    for ea in extra_arts:
        present = os.path.exists(os.path.join(repo, ea))
        log("[5] extra_artifact", ea, "present_live:", present, "in_inventory:", ea in inventory)
    log("[5] symlinks_found:", all_symlinks or "none")

    # (6) anchor -> candidate changed paths
    r = subprocess.run(["git", "-C", repo, "diff", "--name-only", ANCHOR, CANDIDATE],
                       capture_output=True, text=True)
    changed = [l for l in r.stdout.splitlines() if l]
    log("[6] anchor..candidate changed paths (", len(changed), "):")
    for c in changed:
        log("      ", c)
    expected_post_anchor = {MANIFEST_REL, R6_REPORT_REL}
    unexpected = [c for c in changed if c not in expected_post_anchor]
    log("[6] changed beyond {manifest V7, R6 remediation report}:", unexpected or "none")

    return {"recomputed": recomputed, "count": len(arts),
            "live_drift": live_drift, "cand_drift": cand_drift,
            "unexpected_anchor_changes": unexpected, "symlinks": all_symlinks,
            "digest_match": recomputed == m["frozen_inventory_digest"] == EXPECT_DIGEST}


def selftest(out):
    def log(*a):
        line = " ".join(str(x) for x in a)
        print(line)
        out.append(line)
    log("=== [7] NEGATIVE TESTS (throwaway /tmp copy) ===")
    tmp = tempfile.mkdtemp(prefix="a20census-")
    try:
        # minimal synthetic manifest + tree
        root = os.path.join(tmp, "repo")
        os.makedirs(os.path.join(root, "docs/g"))
        os.makedirs(os.path.join(root, "src/x"))
        open(os.path.join(root, "docs/g/a.txt"), "w").write("A\n")
        open(os.path.join(root, "src/x/b.swift"), "w").write("let b=1\n")
        a_sha = sha256_hex(b"A\n")
        b_sha = sha256_hex(b"let b=1\n")
        inv = {"docs/g/a.txt": a_sha, "src/x/b.swift": b_sha}
        post_anchor, allowances = set(), []
        governed = ["docs/g", "src/x"]

        # NEG-A: add unauthorized file -> must be EXTRA
        open(os.path.join(root, "docs/g/evil.txt"), "w").write("evil\n")
        extra_flagged = False
        for r in governed:
            live, _ = live_scan(root, r)
            extra = [f for f in live if not allowed(f, set(inv.keys()), post_anchor, allowances)]
            if "docs/g/evil.txt" in extra:
                extra_flagged = True
        log("[7] NEG-A unauthorized file flagged as EXTRA:", "PASS" if extra_flagged else "FAIL")

        # NEG-B: tamper a byte -> live hash drift
        open(os.path.join(root, "src/x/b.swift"), "w").write("let b=2\n")
        with open(os.path.join(root, "src/x/b.swift"), "rb") as f:
            drift = sha256_hex(f.read()) != inv["src/x/b.swift"]
        log("[7] NEG-B tampered byte flagged as DRIFT:", "PASS" if drift else "FAIL")

        # NEG-C: inventory digest changes if any sha changes
        d1 = inventory_digest(inv)
        inv2 = dict(inv); inv2["src/x/b.swift"] = sha256_hex(b"let b=2\n")
        d2 = inventory_digest(inv2)
        log("[7] NEG-C digest sensitive to sha change:", "PASS" if d1 != d2 else "FAIL")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    out = []
    if "--selftest" in sys.argv:
        selftest(out)
    else:
        res = census(REPO, out)
        out.append("")
        out.append("VERDICT: digest reproduces builder claim = " + str(res["digest_match"]))
        selftest(out)
    mp = os.path.join(REPO, "docs/audit/audit20_tools/audit20_v7_census_measurements.txt")
    with open(mp, "w") as f:
        f.write("\n".join(out) + "\n")
    print("\n(measurements written to", mp, ")")
