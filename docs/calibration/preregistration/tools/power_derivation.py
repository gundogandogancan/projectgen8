# RWC-PRE-14 R1 — calibration methodology derivation (FROZEN script; deterministic; NO real data).
# Design: EQUAL-MASS 10-bin ECE + NULL-REFERENCED decision rule (parametric bootstrap under H0):
#   null draws: y* ~ Bernoulli(p_i) using the model's own predictions -> null ECE distribution.
#   TEST gate: observed ECE <= Q95(null)  (Type-I = 5% BY CONSTRUCTION, bias-immune).
#   EFFECT gate: debiased gap = max(0, observed - mean(null)) <= 0.05 (absolute miscalibration bound).
# Alternatives (predeclared): overconfident shift delta (labels ~ Bern(clip(p - delta))),
# underconfident (+delta), tail distortion (only p>0.8), rare-positive regime (Beta-skewed p).
import random, json
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
    n = len(ps); e = 0.0
    for b in range(bins):
        idx = order[b*n//bins:(b+1)*n//bins]
        if not idx: continue
        mp = sum(ps[i] for i in idx)/len(idx); fp = sum(ys[i] for i in idx)/len(idx)
        e += len(idx)/n * abs(mp - fp)
    return e
def decide(ps, ys, rng, S=200):
    obs = ece_eqmass(ps, ys)
    null = []
    for _ in range(S):
        ysim = [1 if next(rng) < p else 0 for p in ps]
        null.append(ece_eqmass(ps, ysim))
    null.sort()
    q95 = null[int(0.95*S)-1]; mean = sum(null)/S
    gap = max(0.0, obs - mean)
    return (obs <= q95) and (gap <= 0.05), gap
def gen_conf(rng, n, kind):
    if kind == "uniform": return [next(rng) for _ in range(n)]
    if kind == "skewed":  return [next(rng)**2 for _ in range(n)]          # mass near 0
    if kind == "clustered": return [0.1+0.02*next(rng) if next(rng)<0.5 else 0.85+0.1*next(rng) for _ in range(n)]
def labels(rng, ps, alt, delta=0.07):
    out = []
    for p in ps:
        q = p
        if alt == "null": q = p
        elif alt == "over": q = max(0.0, min(1.0, p - delta))              # model overconfident by delta
        elif alt == "under": q = max(0.0, min(1.0, p + delta))
        elif alt == "tail": q = max(0.0, min(1.0, p - 2*delta)) if p > 0.8 else p
        out.append(1 if next(rng) < q else 0)
    return out
res = {}
TRIALS = 250
for n in (400, 800, 1600):
    for conf in ("uniform", "skewed", "clustered"):
        for alt in ("null", "over", "under", "tail"):
            rng = splitmix(0xA14F7 + n*7 + hash(conf+alt) % 1000)
            passes = 0; gaps = 0.0
            for _ in range(TRIALS):
                ps = gen_conf(rng, n, conf)
                ys = labels(rng, ps, alt)
                ok, g = decide(ps, ys, rng)
                passes += ok; gaps += g
            res[f"n{n}_{conf}_{alt}"] = {"pass_rate": round(passes/TRIALS, 3), "mean_debiased_gap": round(gaps/TRIALS, 4)}
print(json.dumps(res, indent=1))
