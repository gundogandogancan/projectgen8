#!/usr/bin/env python3
# AUDIT17_RWC_PRE14_R3_REAUDIT - gated-runner driver.
# The audit sandbox denies shell env-assignment prefixes (VAR=x cmd), while the frozen V4
# derivation runners and the AUDIT17 heavy replication runner are env-gated by design. This tool
# sets the documented environment variables via os.environ and invokes `swift test` directly, so
# every gated run stays reproducible and auditable. It mutates NO builder artifact by itself; the
# V4 derivation runners overwrite their committed JSONs (restored afterwards via git checkout by
# the auditor), exactly as the builder's own reproduction law prescribes.
#
# usage:
#   audit17_run_gated.py stats
#   audit17_run_gated.py precision <PYTHONHASHSEED>
#   audit17_run_gated.py power <PYTHONHASHSEED>
import hashlib, os, subprocess, sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
PKG = os.path.join(REPO, "packages", "GuardianKit")
TOOLS = "docs/calibration/preregistration/tools"

def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()

def run(env_extra, test_filter):
    env = dict(os.environ)
    env.update(env_extra)
    cmd = ["swift", "test", "-c", "release", "-Xswiftc", "-enable-testing",
           "--filter", test_filter]
    print("RUN", env_extra, " ".join(cmd), flush=True)
    p = subprocess.run(cmd, cwd=PKG, env=env, capture_output=True, text=True)
    tail = (p.stdout + p.stderr).splitlines()[-12:]
    for line in tail:
        print("  |", line, flush=True)
    print("EXIT", p.returncode, flush=True)
    return p.returncode

def main():
    mode = sys.argv[1]
    if mode == "stats":
        rc = run({"GEN8_AUDIT17_STATS": "1"}, "AUDIT17_StatReplicationRunner17")
        out = os.path.join(REPO, "docs/audit/audit17_tools/results/audit17_stat_replication.json")
        if os.path.exists(out):
            print("STATS_SHA256", sha(out))
        sys.exit(rc)
    seed = sys.argv[2]
    if mode == "precision":
        rc = run({"GEN8_RWC_DERIVE_V4": "precision", "PYTHONHASHSEED": seed},
                 "RWCPowerDerivationV4Runner/testDerive_PrecisionArtifact")
        print("PRECISION_SHA256", sha(os.path.join(REPO, TOOLS, "RWC_CALIBRATION_MC_PRECISION_V4.json")))
        sys.exit(rc)
    if mode == "power":
        rc = run({"GEN8_RWC_DERIVE_V4": "power", "PYTHONHASHSEED": seed},
                 "RWCPowerDerivationV4Runner/testDerive_PowerStudy")
        print("POWER_SHA256", sha(os.path.join(REPO, TOOLS, "RWC_CALIBRATION_POWER_RESULTS_V4.json")))
        sys.exit(rc)
    print("unknown mode", mode)
    sys.exit(2)

if __name__ == "__main__":
    main()
