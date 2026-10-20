# AUDIT15 tool — INDEPENDENT reimplementation of the frozen calibration decision rule
# (equal-mass 10-bin ECE + null-referenced Q95 test gate + debiased-gap effect gate) and
# independent Type-I / power replication. Does NOT call any builder code. RNG = Python
# Mersenne Twister (random.Random), independent of the builder's SplitMix64 streams.
# Usage: python3 audit15_reference_replication.py <n>    (n in 400/800/1600)
# Output: JSON to /tmp/a15_ref_n<n>.json. ADD-ONLY auditor tooling.
import random, json, sys, math

BINS = 10
S = 200          # frozen null-sim count
EFFECT = 0.05    # frozen effect bound


def ece_equal_mass(ps, ys):
    """Independent implementation of the frozen spec: sort by p (ties by original index),
    bins [b*n//10, (b+1)*n//10), weighted |mean p - mean y|."""
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


def decide(ps, ys, rng):
    """Independent implementation of the frozen decision rule (PASS iff obs<=Q95(null) AND
    max(0,obs-mean(null))<=0.05), with the frozen quantile convention null_sorted[int(0.95*S)-1]."""
    obs = ece_equal_mass(ps, ys)
    null = []
    for _ in range(S):
        ysim = [1 if rng.random() < p else 0 for p in ps]
        null.append(ece_equal_mass(ps, ysim))
    null.sort()
    q95 = null[int(0.95 * S) - 1]
    mean = sum(null) / S
    gap = max(0.0, obs - mean)
    return (obs <= q95) and (gap <= EFFECT), obs, gap


def gen_conf(rng, n, kind):
    if kind == "uniform":
        return [rng.random() for _ in range(n)]
    if kind == "skewed":
        return [rng.random() ** 2 for _ in range(n)]
    if kind == "clustered":
        return [0.1 + 0.02 * rng.random() if rng.random() < 0.5 else 0.85 + 0.1 * rng.random()
                for _ in range(n)]
    if kind == "highconf":                      # mass near 1 (extra Type-I shape)
        return [1.0 - rng.random() ** 3 for _ in range(n)]
    if kind == "lowconf":                       # mass near 0 (extra Type-I shape)
        return [rng.random() ** 3 for _ in range(n)]
    if kind == "quantized":                     # heavy ties: 10-level grid
        return [round(rng.random() * 9) / 9 * 0.9 + 0.05 for _ in range(n)]
    raise ValueError(kind)


def true_q(p, alt, delta):
    if alt == "null":
        return p
    if alt == "over":
        return max(0.0, min(1.0, p - delta))
    if alt == "under":
        return max(0.0, min(1.0, p + delta))
    if alt == "tail":
        return max(0.0, min(1.0, p - 2 * delta)) if p > 0.8 else p
    raise ValueError(alt)


def labels(rng, ps, alt, delta):
    return [1 if rng.random() < true_q(p, alt, delta) else 0 for p in ps]


def wilson(k, n):
    z = 1.959963984540054
    p = k / n
    z2 = z * z
    c = (p + z2 / (2 * n)) / (1 + z2 / n)
    h = (z / (1 + z2 / n)) * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n))
    return (max(0.0, c - h), min(1.0, c + h))


def cell(n, conf, alt, delta, trials, seed):
    rng = random.Random(seed)
    passes = 0
    for _ in range(trials):
        ps = gen_conf(rng, n, conf)
        ys = labels(rng, ps, alt, delta)
        ok, _, _ = decide(ps, ys, rng)
        passes += ok
    lo, hi = wilson(passes, trials)
    return {"pass_rate": round(passes / trials, 4), "trials": trials,
            "wilson95": [round(lo, 4), round(hi, 4)]}


def main():
    n = int(sys.argv[1])
    res = {}
    # A) Type-I under PERFECT calibration — combined rule — 6 shapes, 500 trials
    for conf in ("uniform", "skewed", "clustered", "highconf", "lowconf", "quantized"):
        res["typeI_%s" % conf] = cell(n, conf, "null", 0.0, 500, 100000 + n + hashn(conf))
    # B) Power, frozen delta=.07 — 3 predeclared shapes x over/under/tail, 400 trials
    for conf in ("uniform", "skewed", "clustered"):
        for alt in ("over", "under", "tail"):
            r = cell(n, conf, alt, 0.07, 400, 200000 + n + hashn(conf + alt))
            r["reject_rate"] = round(1.0 - r["pass_rate"], 4)
            res["power_%s_%s" % (conf, alt)] = r
    # C) delta sensitivity at this n: uniform/clustered x over x delta .03/.05/.07/.10 (n=800 only)
    if n == 800:
        for conf in ("uniform", "clustered"):
            for d in (0.03, 0.05, 0.07, 0.10):
                r = cell(n, conf, "over", d, 400, 300000 + int(d * 1000) + hashn(conf))
                r["reject_rate"] = round(1.0 - r["pass_rate"], 4)
                res["delta_%s_%.2f" % (conf, d)] = r
    with open("/tmp/a15_ref_n%d.json" % n, "w") as f:
        json.dump(res, f, indent=1)
    print("done n=%d cells=%d" % (n, len(res)))


def hashn(s):
    # deterministic string key (NOT Python hash()): avoids the frozen script's PYTHONHASHSEED defect
    v = 0
    for ch in s:
        v = (v * 131 + ord(ch)) % 100000
    return v


if __name__ == "__main__":
    main()
