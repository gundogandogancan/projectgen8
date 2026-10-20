# AUDIT15 tool — benchmark one frozen-script decide() call to plan run budgets. ADD-ONLY auditor tooling.
import time


def splitmix(seed):
    s = seed & 0xFFFFFFFFFFFFFFFF
    while True:
        s = (s + 0x9E3779B97F4A7C15) & 0xFFFFFFFFFFFFFFFF
        z = s
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & 0xFFFFFFFFFFFFFFFF
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & 0xFFFFFFFFFFFFFFFF
        yield ((z ^ (z >> 31)) & 0xFFFFFFFFFFFFFFFF) / 2**64


def ece_eqmass(ps, ys, bins=10):
    order = sorted(range(len(ps)), key=lambda i: ps[i])
    n = len(ps)
    e = 0.0
    for b in range(bins):
        idx = order[b * n // bins:(b + 1) * n // bins]
        if not idx:
            continue
        mp = sum(ps[i] for i in idx) / len(idx)
        fp = sum(ys[i] for i in idx) / len(idx)
        e += len(idx) / n * abs(mp - fp)
    return e


def decide(ps, ys, rng, S=200):
    obs = ece_eqmass(ps, ys)
    null = []
    for _ in range(S):
        ysim = [1 if next(rng) < p else 0 for p in ps]
        null.append(ece_eqmass(ps, ysim))
    null.sort()
    q95 = null[int(0.95 * S) - 1]
    mean = sum(null) / S
    gap = max(0.0, obs - mean)
    return (obs <= q95) and (gap <= 0.05), gap


rng = splitmix(123)
ps = [next(rng) for _ in range(800)]
ys = [1 if next(rng) < p else 0 for p in ps]
t0 = time.time()
decide(ps, ys, rng)
t1 = time.time()
per = t1 - t0
print("one decide n=800: %.3fs" % per)
print("full frozen script est: %.1f min" % (per * 250 * 12 * (0.5 + 1 + 2) / 60))
