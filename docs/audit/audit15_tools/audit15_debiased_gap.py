# AUDIT15 tool — scientific status of "debiased gap = max(0, observed ECE - mean(null ECE))"
# (mandate section 20). Compares the gap against the ANALYTICALLY KNOWN true L1 calibration error
# E_p |p - q(p)| for generators where q is known, including distortions that cancel INSIDE
# equal-mass bins (oscillating / localized). Independent implementation; no builder code.
# Output: /tmp/a15_gap.json.
import random, json, math

BINS, S = 10, 200


def ece_equal_mass(ps, ys):
    n = len(ps)
    order = sorted(range(n), key=lambda i: ps[i])
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


def gap_and_pass(ps, ys, rng):
    obs = ece_equal_mass(ps, ys)
    null = []
    for _ in range(S):
        ysim = [1 if rng.random() < p else 0 for p in ps]
        null.append(ece_equal_mass(ps, ysim))
    null.sort()
    q95 = null[int(0.95 * S) - 1]
    mean = sum(null) / S
    g = max(0.0, obs - mean)
    return g, (obs <= q95) and (g <= 0.05)


SCENARIOS = {
    # name: q(p)  — p ~ Uniform(0,1), n=800
    "constant_over_07": lambda p: max(0.0, min(1.0, p - 0.07)),
    "nonlinear_p15": lambda p: p ** 1.5,
    "tail_only_14": lambda p: max(0.0, min(1.0, p - 0.14)) if p > 0.8 else p,
    "oscillating_08": lambda p: max(0.0, min(1.0, p + 0.08 * math.sin(31.4159 * p))),
    "localized_25": lambda p: max(0.0, min(1.0, p - 0.25)) if 0.45 <= p <= 0.55 else p,
}

res = {}
tr = random.Random(42)
for name, qf in SCENARIOS.items():
    # true L1 calibration error by large-sample numeric estimate (200k draws)
    true_l1 = sum(abs(p - qf(p)) for p in (tr.random() for _ in range(200000))) / 200000
    rng = random.Random(900000 + len(name))
    gaps = []
    passes = 0
    trials = 300
    n = 800
    for _ in range(trials):
        ps = [rng.random() for _ in range(n)]
        ys = [1 if rng.random() < qf(p) else 0 for p in ps]
        g, ok = gap_and_pass(ps, ys, rng)
        gaps.append(g)
        passes += ok
    mg = sum(gaps) / trials
    sd = math.sqrt(sum((g - mg) ** 2 for g in gaps) / (trials - 1))
    res[name] = {
        "true_L1_miscalibration": round(true_l1, 4),
        "mean_debiased_gap": round(mg, 4),
        "gap_mc_sem": round(sd / math.sqrt(trials), 5),
        "gap_underestimates_truth_by": round(true_l1 - mg, 4),
        "pass_rate": round(passes / trials, 4),
        "trials": trials,
    }
with open("/tmp/a15_gap.json", "w") as f:
    json.dump(res, f, indent=1)
print(json.dumps(res, indent=1))
