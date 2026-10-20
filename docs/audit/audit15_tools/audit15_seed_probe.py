# AUDIT15 tool — prove the frozen power_derivation.py cell seeds depend on Python's randomized
# string hash (PYTHONHASHSEED). Prints the exact seed integers the frozen script would use.
# Run under PYTHONHASHSEED=1 / 2 / 3 / unset and compare. ADD-ONLY auditor tooling.
import os

cells = []
for n in (400, 800, 1600):
    for conf in ("uniform", "skewed", "clustered"):
        for alt in ("null", "over", "under", "tail"):
            seed = 0xA14F7 + n * 7 + hash(conf + alt) % 1000   # EXACT expression from frozen script line 55
            cells.append(("n%d_%s_%s" % (n, conf, alt), seed))
print("PYTHONHASHSEED=%s" % os.environ.get("PYTHONHASHSEED", "<unset/random>"))
for name, seed in cells:
    print(name, seed)
