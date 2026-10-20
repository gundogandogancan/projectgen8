# AUDIT15 tool — equal-mass tie/order sensitivity (mandate section 19). Preserves the EXACT (p,y)
# multiset and only permutes input order; measures observed-ECE spread and PASS/FAIL flips with the
# internal null seed HELD FIXED (isolating pure input-ordering sensitivity of the frozen estimator).
# Independent implementation. Output: /tmp/a15_tie.json.
import random, json

BINS, S = 10, 200


def ece_equal_mass(ps, ys):
    n = len(ps)
    order = sorted(range(n), key=lambda i: ps[i])   # ties keep ORIGINAL INDEX order (same as frozen spec)
    total = 0.0
    for b in range(BINS):
        lo, hi = b * n // BINS, (b + 1) * n // BINS
        if hi <= lo:
            continue
        sp = sy = 0.0
        for i in order[lo:hi]:
            sp += ps[i]
            sy += ys[i]
        c = hi - lo
        total += (c / n) * abs(sp / c - sy / c)
    return total


def decide_fixed_nullseed(ps, ys, nullseed):
    rng = random.Random(nullseed)
    obs = ece_equal_mass(ps, ys)
    null = []
    for _ in range(S):
        ysim = [1 if rng.random() < p else 0 for p in ps]
        null.append(ece_equal_mass(ps, ysim))
    null.sort()
    q95 = null[int(0.95 * S) - 1]
    mean = sum(null) / S
    gap = max(0.0, obs - mean)
    return (obs <= q95) and (gap <= 0.05), obs


def permutation_experiment(ps, ys, tag, res, perms=150):
    rng = random.Random(31337)
    pairs = list(zip(ps, ys))
    eces = []
    passes = 0
    for _ in range(perms):
        rng.shuffle(pairs)
        pp = [a for a, _ in pairs]
        yy = [b for _, b in pairs]
        ok, obs = decide_fixed_nullseed(pp, yy, 424242)   # null seed fixed -> ordering is the ONLY variable
        eces.append(obs)
        passes += ok
    res[tag] = {
        "perms": perms,
        "ece_min": round(min(eces), 5), "ece_max": round(max(eces), 5),
        "ece_spread": round(max(eces) - min(eces), 5),
        "pass_count": passes,
        "decision_flips_across_orderings": 0 < passes < perms,
    }


res = {}
# Case 1: ALL predictions tied at 0.5; labels = 460/800 positives (true miscalibration 0.075)
n = 800
permutation_experiment([0.5] * n, [1] * 460 + [0] * 340, "all_tied_p05_460pos", res)
# Case 2: two confidence levels (0.3 / 0.7), labels miscalibrated by ~0.06 at each level
g = random.Random(99)
ps2 = [0.3] * 400 + [0.7] * 400
ys2 = [1 if g.random() < 0.36 else 0 for _ in range(400)] + [1 if g.random() < 0.76 else 0 for _ in range(400)]
permutation_experiment(ps2, ys2, "two_levels_shift06", res)
# Case 3: 10-level quantized grid, perfectly calibrated (null)
ps3 = [((i % 10) + 0.5) / 10 for i in range(n)]
g2 = random.Random(7)
ys3 = [1 if g2.random() < p else 0 for p in ps3]
permutation_experiment(ps3, ys3, "quantized_null", res)
with open("/tmp/a15_tie.json", "w") as f:
    json.dump(res, f, indent=1)
print(json.dumps(res, indent=1))
