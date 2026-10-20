#!/usr/bin/env python3
# RWC METHODOLOGY V3 — CROSS-LANGUAGE DIFFERENTIAL TOOL (A15-F7 closure evidence).
#
# Pure-python (stdlib only; python3.9) reimplementation of the frozen v3 statistical law:
#   * SHA-256 seed law        seed64("GEN8-RWC-CAL-V3|" + parts) = first 8 digest bytes, big-endian
#   * SplitMix64 RNG          identical 64-bit stream to the Swift engine
#   * double01                (x >> 11) * 2^-53 — identical IEEE double in both languages
#   * TIE-GROUP BINNING LAW   groups of exactly-equal predictions; bin(g) = (cStart*B)//n (integer);
#                             sumP_b = sum(p_g*count_g); ECE = sum (count_b/n)*|meanP-meanY|
#   * decideV3                exact MC test: FAIL iff 20*(1+exceed) <= (S+1); S=999 frozen;
#                             nullAdjustedExcessECE = max(0, observed - mean(null)) <= 0.05
#   * power-engine generators uniform/skewed/clustered/quantized/highconf/lowconf; alternatives
#
# DETERMINISM LAW: output is byte-identical across processes and across ANY PYTHONHASHSEED value
# (no hash(), no dict-order dependence, no clock). Verified in the R2 build under
# PYTHONHASHSEED in {random,1,2,3,999} and re-verified by RWCPreregistrationR2Tests against the
# committed fixtures file RWC_METHODOLOGY_V3_DIFFERENTIAL_FIXTURES.json (bit-exact doubles, %.17g).
#
# ZERO-DATA: all vectors synthetic/frozen; nothing is fetched; nothing real is scored.
import hashlib
import sys

MASK = (1 << 64) - 1
GOLDEN = 0x9E3779B97F4A7C15


def seed64(parts):
    ctx = "|".join(["GEN8-RWC-CAL-V3"] + list(parts))
    d = hashlib.sha256(ctx.encode("utf-8")).digest()
    v = 0
    for i in range(8):
        v = (v << 8) | d[i]
    return v


class SplitMix64:
    def __init__(self, seed):
        self.state = GOLDEN if seed == 0 else (seed & MASK)

    def next64(self):
        self.state = (self.state + GOLDEN) & MASK
        z = self.state
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK
        return (z ^ (z >> 31)) & MASK

    def double01(self):
        return (self.next64() >> 11) * (1.0 / 9007199254740992.0)


def tie_group_plan(preds, bins):
    n = len(preds)
    s = sorted(preds)
    values, counts, group_bins = [], [], []
    i = 0
    while i < n:
        v = s[i]
        j = i
        while j < n and s[j] == v:
            j += 1
        values.append(v)
        counts.append(j - i)
        group_bins.append((i * bins) // n)
        i = j
    return n, values, counts, group_bins


def ece_tie_invariant(preds, labels, bins=10):
    if not preds or len(preds) != len(labels):
        raise ValueError("invalid input")
    for p in preds:
        if not (p == p) or p in (float("inf"), float("-inf")) or p < 0.0 or p > 1.0:
            raise ValueError("invalid probability")
    if bins < 1 or bins > len(preds):
        raise ValueError("invalid bins")
    n, values, counts, group_bins = tie_group_plan(preds, bins)
    pos_by_value = {}
    for p, y in zip(preds, labels):
        if y:
            pos_by_value[p] = pos_by_value.get(p, 0) + 1
    sum_p = [0.0] * bins
    sum_y = [0.0] * bins
    cnt = [0] * bins
    for g in range(len(values)):
        b = group_bins[g]
        sum_p[b] += values[g] * float(counts[g])
        sum_y[b] += float(pos_by_value.get(values[g], 0))
        cnt[b] += counts[g]
    ece = 0.0
    for b in range(bins):
        if cnt[b] > 0:
            c = float(cnt[b])
            ece += c / float(n) * abs(sum_p[b] / c - sum_y[b] / c)
    return ece


def null_ece(values, counts, group_bins, bins, n, rng):
    sum_p = [0.0] * bins
    sum_y = [0.0] * bins
    cnt = [0] * bins
    for g in range(len(values)):
        b, p, c = group_bins[g], values[g], counts[g]
        pos = 0
        for _ in range(c):
            if rng.double01() < p:
                pos += 1
        sum_p[b] += p * float(c)
        sum_y[b] += float(pos)
        cnt[b] += c
    ece = 0.0
    for b in range(bins):
        if cnt[b] > 0:
            c = float(cnt[b])
            ece += c / float(n) * abs(sum_p[b] / c - sum_y[b] / c)
    return ece


def decide_v3(preds, labels, seed_parts, bins=10, sims=999):
    if sims < 19 or (sims + 1) % 20 != 0:
        raise ValueError("invalid simulation count")
    observed = ece_tie_invariant(preds, labels, bins)
    n, values, counts, group_bins = tie_group_plan(preds, bins)
    rng = SplitMix64(seed64(seed_parts))
    exceed = 0
    null_sum = 0.0
    for _ in range(sims):
        e = null_ece(values, counts, group_bins, bins, n, rng)
        null_sum += e
        if e >= observed:
            exceed += 1
    p_mc = float(1 + exceed) / float(sims + 1)
    null_mean = null_sum / float(sims)
    excess = max(0.0, observed - null_mean)
    test_fails = 20 * (1 + exceed) <= (sims + 1)
    return {
        "observed": observed, "pMC": p_mc, "nullMean": null_mean,
        "nullAdjustedExcessECE": excess,
        "testGatePassed": (not test_fails), "excessGatePassed": excess <= 0.05,
        "passed": (not test_fails) and excess <= 0.05,
    }


def clamp01(x):
    return min(1.0, max(0.0, x))


def confidence(shape, rng):
    if shape == "skewed":
        u = rng.double01()
        return u * u
    if shape == "clustered":
        return 0.1 + 0.02 * rng.double01() if rng.double01() < 0.5 else 0.85 + 0.1 * rng.double01()
    if shape == "quantized":
        return float(min(20, max(0, int(rng.double01() * 21.0)))) / 20.0
    if shape == "highconf":
        u = rng.double01()
        return 1.0 - u * u
    if shape == "lowconf":
        u = rng.double01()
        return u * u * u
    return rng.double01()


def true_probability(alt, p):
    if alt == "over03":
        return clamp01(p - 0.03)
    if alt == "over05":
        return clamp01(p - 0.05)
    if alt == "over07":
        return clamp01(p - 0.07)
    if alt == "over10":
        return clamp01(p - 0.10)
    if alt == "under07":
        return clamp01(p + 0.07)
    if alt == "tail07":
        return clamp01(p - 0.14) if p > 0.8 else p
    if alt == "osc05":
        import math
        return clamp01(p + (0.05 if int(math.floor(p * 10.0)) % 2 == 0 else -0.05))
    if alt == "localized07":
        return clamp01(p + 0.21) if 0.4 <= p < 0.6 else p
    return p


def dataset(shape, alt, n, seed_parts):
    rng = SplitMix64(seed64(seed_parts))
    preds, labels = [], []
    for _ in range(n):
        p = confidence(shape, rng)
        preds.append(p)
        labels.append(rng.double01() < true_probability(alt, p))
    return preds, labels


def g17(x):
    return "%.17g" % x


def fixtures():
    out = []
    out.append('{')
    out.append('  "version": "rwc-methodology-v3-differential-1",')
    # seed law vectors
    seeds = [
        ["eval", "deadbeef", "risk_ECE"],
        ["power", "uniform", "null", "800", "0", "data"],
        ["power", "clustered", "over07", "400", "13", "eval"],
        ["stability", "null", "uniform", "5", "eval", "7"],
        ["fixture", "a"],
    ]
    out.append('  "seed64": {')
    out.append(",\n".join('    "%s": "%d"' % ("|".join(p), seed64(p)) for p in seeds))
    out.append('  },')
    # splitmix vectors
    out.append('  "splitmix64_first5": {')
    sm_lines = []
    for s in [1, seed64(["fixture", "a"])]:
        r = SplitMix64(s)
        sm_lines.append('    "%d": [%s]' % (s, ", ".join('"%d"' % r.next64() for _ in range(5))))
    out.append(",\n".join(sm_lines))
    out.append('  },')
    # tie-law ECE vectors (hardcoded multisets with heavy ties)
    e1p = [0.5] * 20
    e1l = [True] * 10 + [False] * 10
    e2p = [0.1] * 7 + [0.3] * 5 + [0.3] * 3 + [0.9] * 5
    e2l = [True, False, False, True, False, False, False] + [True] * 5 + [False] * 3 + [True, True, True, False, True]
    e3p = [float(k % 5) / 4.0 for k in range(40)]
    e3l = [(k * 7) % 3 == 0 for k in range(40)]
    out.append('  "eceTieInvariant": {')
    out.append('    "all_tied_p05": "%s",' % g17(ece_tie_invariant(e1p, e1l)))
    out.append('    "three_groups": "%s",' % g17(ece_tie_invariant(e2p, e2l)))
    out.append('    "quantized_grid": "%s"' % g17(ece_tie_invariant(e3p, e3l)))
    out.append('  },')
    # full decide vectors (S=999)
    d1 = decide_v3(e3p, e3l, ["fixture", "decide", "quantized"])
    p2, l2 = dataset("uniform", "null", 60, ["fixture", "decide", "uniform", "data"])
    d2 = decide_v3(p2, l2, ["fixture", "decide", "uniform", "eval"])
    out.append('  "decideV3": {')
    for name, d in [("quantized_grid", d1), ("uniform_n60", d2)]:
        out.append('    "%s": {"observed": "%s", "pMC": "%s", "nullMean": "%s", "excess": "%s", "passed": %s},'
                   % (name, g17(d["observed"]), g17(d["pMC"]), g17(d["nullMean"]),
                      g17(d["nullAdjustedExcessECE"]), "true" if d["passed"] else "false"))
    out[-1] = out[-1].rstrip(',')
    out.append('  },')
    # generator vectors
    p3, l3 = dataset("clustered", "over07", 8, ["fixture", "gen", "clustered"])
    out.append('  "dataset_clustered_over07_n8": {')
    out.append('    "preds": [%s],' % ", ".join('"%s"' % g17(x) for x in p3))
    out.append('    "labels": [%s]' % ", ".join("true" if y else "false" for y in l3))
    out.append('  }')
    out.append('}')
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    text = fixtures()
    if len(sys.argv) > 1 and sys.argv[1] == "--write":
        path = sys.argv[2] if len(sys.argv) > 2 else "RWC_METHODOLOGY_V3_DIFFERENTIAL_FIXTURES.json"
        with open(path, "w") as f:
            f.write(text)
        print("WROTE=" + path)
    else:
        sys.stdout.write(text)
