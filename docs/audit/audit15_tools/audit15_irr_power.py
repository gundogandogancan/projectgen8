# AUDIT15 tool — IRR gate operating characteristics (mandate sections 33-35). INDEPENDENT
# quadratic-weighted kappa + percentile bootstrap (B=2000, frozen index convention
# lo=sorted[int(.025*B)], hi=sorted[int(.975*B)]; PASS iff CI-lower >= 0.60). Measures
# P(PASS) for true kappa in {.55,.60,.65,.70,.80,.90} at n in {50,100,200}.
# Rater model: rater A ~ uniform{0..4}; with prob m, B=A; else B uniform{0..4} (independent).
# m is calibrated per target kappa by large-sample search. No builder code called.
# Output: /tmp/a15_irr.json.
import random, json, math

K = 5
B_REPS = 2000
THRESH = 0.60


def qwk_from_counts(counts, n):
    """counts: dict (a,b)->count. Returns kappa or None (degenerate)."""
    row = [0.0] * K
    col = [0.0] * K
    po = 0.0
    for (a, b), c in counts.items():
        w = 1.0 - ((a - b) ** 2) / ((K - 1) ** 2)
        po += w * c
        row[a] += c
        col[b] += c
    po /= n
    pe = 0.0
    for i in range(K):
        for j in range(K):
            w = 1.0 - ((i - j) ** 2) / ((K - 1) ** 2)
            pe += w * (row[i] / n) * (col[j] / n)
    den = 1.0 - pe
    if abs(den) <= 1e-12:
        return None
    return (po - pe) / den


def sample_pairs(rng, n, m):
    counts = {}
    for _ in range(n):
        a = rng.randrange(K)
        b = a if rng.random() < m else rng.randrange(K)
        counts[(a, b)] = counts.get((a, b), 0) + 1
    return counts


def pop_kappa(m, probe_n=400000, seed=1):
    rng = random.Random(seed)
    c = sample_pairs(rng, probe_n, m)
    return qwk_from_counts(c, probe_n)


def calibrate_m(target):
    lo, hi = 0.0, 1.0
    for _ in range(40):
        mid = (lo + hi) / 2
        k = pop_kappa(mid)
        if k < target:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def bootstrap_decision(pairs_list, n, rng):
    """pairs_list: list of (a,b). Frozen law: B=2000; degenerate replicates excluded;
    valid fraction >= .80 else INSUFFICIENT; PASS iff sorted[int(.025*count)] >= threshold."""
    point = qwk_from_counts(count_of(pairs_list), n)
    if point is None or n < 50:
        return "insufficient"
    reps = []
    for _ in range(B_REPS):
        counts = {}
        for _ in range(n):
            a, b = pairs_list[rng.randrange(n)]
            counts[(a, b)] = counts.get((a, b), 0) + 1
        k = qwk_from_counts(counts, n)
        if k is not None:
            reps.append(k)
    if len(reps) / B_REPS < 0.80:
        return "insufficient"
    reps.sort()
    lo = reps[max(0, int(0.025 * len(reps)))]
    return "pass" if lo >= THRESH else "fail"


def count_of(pairs_list):
    c = {}
    for ab in pairs_list:
        c[ab] = c.get(ab, 0) + 1
    return c


def wilson(k, n):
    z = 1.959963984540054
    p = k / n
    z2 = z * z
    c = (p + z2 / (2 * n)) / (1 + z2 / n)
    h = (z / (1 + z2 / n)) * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n))
    return [round(max(0.0, c - h), 4), round(min(1.0, c + h), 4)]


res = {}
targets = (0.55, 0.60, 0.65, 0.70, 0.80, 0.90)
ms = {t: calibrate_m(t) for t in targets}
for t in targets:
    for n in (50, 100, 200):
        rng = random.Random(int(t * 1000) * 7919 + n)
        trials = 120
        outcomes = {"pass": 0, "fail": 0, "insufficient": 0}
        for _ in range(trials):
            pl = []
            for _ in range(n):
                a = rng.randrange(K)
                b = a if rng.random() < ms[t] else rng.randrange(K)
                pl.append((a, b))
            outcomes[bootstrap_decision(pl, n, rng)] += 1
        res["kappa%.2f_n%d" % (t, n)] = {
            "mixture_m": round(ms[t], 4),
            "pass_prob": round(outcomes["pass"] / trials, 4),
            "pass_wilson95": wilson(outcomes["pass"], trials),
            "fail": outcomes["fail"], "insufficient": outcomes["insufficient"],
            "trials": trials,
        }
        print("kappa=%.2f n=%d -> %s" % (t, n, res["kappa%.2f_n%d" % (t, n)]), flush=True)
with open("/tmp/a15_irr.json", "w") as f:
    json.dump(res, f, indent=1)
print("done")
