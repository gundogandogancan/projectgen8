# AUDIT15 tool — run the FROZEN power_derivation.py once in a fresh subprocess under a given
# PYTHONHASHSEED (argv[1]); writes stdout to /tmp/a15_power_h<seed>.json. ADD-ONLY auditor tooling.
import subprocess, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
FROZEN = os.path.join(ROOT, "docs", "calibration", "preregistration", "tools", "power_derivation.py")
hs = sys.argv[1]
env = dict(os.environ)
env["PYTHONHASHSEED"] = hs
out = subprocess.run([sys.executable, FROZEN], env=env, capture_output=True, text=True)
with open("/tmp/a15_power_h%s.json" % hs, "w") as f:
    f.write(out.stdout)
print("done PYTHONHASHSEED=%s bytes=%d" % (hs, len(out.stdout)))
