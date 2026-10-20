# AUDIT15 tool — PYTHONHASHSEED differential driver (mandate section 22).
# Runs the seed probe (fast) and, with --full, the FROZEN power_derivation.py script in fresh
# subprocesses under PYTHONHASHSEED=1/2/3, and compares outputs. ADD-ONLY auditor tooling.
import subprocess, sys, os, json

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
TOOLS = os.path.join(ROOT, "docs", "audit", "audit15_tools")
FROZEN = os.path.join(ROOT, "docs", "calibration", "preregistration", "tools", "power_derivation.py")


def run(script, hashseed):
    env = dict(os.environ)
    env["PYTHONHASHSEED"] = str(hashseed)
    out = subprocess.run([sys.executable, script], env=env, capture_output=True, text=True)
    return out.stdout


if "--full" in sys.argv:
    outs = {}
    for hs in (1, 2, 3):
        print("running frozen power_derivation.py under PYTHONHASHSEED=%d ..." % hs, flush=True)
        outs[hs] = run(FROZEN, hs)
        with open("/tmp/a15_power_h%d.json" % hs, "w") as f:
            f.write(outs[hs])
    same12 = outs[1] == outs[2]
    same13 = outs[1] == outs[3]
    print("output(h1)==output(h2):", same12)
    print("output(h1)==output(h3):", same13)
    if not (same12 and same13):
        r1, r2, r3 = (json.loads(outs[h]) for h in (1, 2, 3))
        diffs = [k for k in r1 if not (r1[k] == r2[k] == r3[k])]
        print("cells differing across hash seeds: %d / %d" % (len(diffs), len(r1)))
        for k in diffs[:12]:
            print(" ", k, "h1=", r1[k], "h2=", r2[k], "h3=", r3[k])
else:
    probe = os.path.join(TOOLS, "audit15_seed_probe.py")
    o1, o2, o3 = run(probe, 1), run(probe, 2), run(probe, 3)
    b1 = o1.splitlines()[1:]
    b2 = o2.splitlines()[1:]
    b3 = o3.splitlines()[1:]
    print("seed list identical h1==h2:", b1 == b2, " h1==h3:", b1 == b3)
    for i in range(4):
        print("h1:", b1[i], "| h2:", b2[i], "| h3:", b3[i])
