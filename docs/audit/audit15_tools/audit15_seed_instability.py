# AUDIT15 tool — null-seed decision instability (mandate section 17). Holds the OBSERVED dataset
# fixed; re-runs the frozen decision rule with many different internal null-bootstrap seeds (S=200);
# measures how often IDENTICAL data flips PASS/FAIL purely from the internal seed.
# Independent implementation (no builder code). Output: /tmp/a15_seed_instability.json.
import random, json, math

BINS, S, EFFECT = 10, 200, 0.05


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


def decide_with_seed(ps, ys, seed):
    rng = random.Random(seed)
    obs = ece_equal_mass(ps, ys)
    null = []
    for _ in range(S):
        ysim = [1 if rng.random() < p else 0 for p in ps]
        null.append(ece_equal_mass(ps, ysim))
    null.sort()
    q95 = null[int(0.95 * S) - 1]
    mean = sum(null) / S
    gap = max(0.0, obs - mean)
    return (obs <= q95) and (gap <= EFFECT)


def experiment(gen_delta, n_datasets, n, seeds_per_dataset, tag, res):
    g = random.Random(555000 + int(gen_delta * 1000))
    mixed = 0
    pass_fracs = []
    for d in range(n_datasets):
        ps = [g.random() for _ in range(n)]
        q = [max(0.0, min(1.0, p - gen_delta)) for p in ps]
        ys = [1 if g.random() < qq else 0 for qq in q]
        outcomes = [decide_with_seed(ps, ys, 777000 + d * 1000 + s) for s in range(seeds_per_dataset)]
        frac = sum(outcomes) / seeds_per_dataset
        pass_fracs.append(frac)
        if 0.0 < frac < 1.0:
            mixed += 1
    res[tag] = {
        "datasets": n_datasets, "seeds_per_dataset": seeds_per_dataset,
        "datasets_with_mixed_verdicts": mixed,
        "mixed_fraction": round(mixed / n_datasets, 4),
        "mean_pass_fraction": round(sum(pass_fracs) / len(pass_fracs), 4),
        # binomial CI on the mixed fraction
        "mixed_wilson95": wilson(mixed, n_datasets),
    }


def wilson(k, n):
    z = 1.959963984540054
    p = k / n
    z2 = z * z
    c = (p + z2 / (2 * n)) / (1 + z2 / n)
    h = (z / (1 + z2 / n)) * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n))
    return [round(max(0.0, c - h), 4), round(min(1.0, c + h), 4)]


res = {}
# null data (perfectly calibrated): is PASS/FAIL stable across internal seeds?
experiment(0.00, 120, 800, 30, "null_n800", res)
# near-boundary miscalibration (delta=.03, between 0 and effect bound): worst-case instability zone
experiment(0.03, 120, 800, 30, "boundary_delta03_n800", res)
with open("/tmp/a15_seed_instability.json", "w") as f:
    json.dump(res, f, indent=1)
print(json.dumps(res, indent=1))
