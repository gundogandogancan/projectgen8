# AUDIT15 tool — compare the frozen script's full outputs across PYTHONHASHSEED=1/2/3.
import json

r = {h: json.load(open("/tmp/a15_power_h%d.json" % h)) for h in (1, 2, 3)}
keys = sorted(r[1].keys())
diff = [k for k in keys if not (r[1][k] == r[2][k] == r[3][k])]
print("cells total:", len(keys), "| cells differing across PYTHONHASHSEED 1/2/3:", len(diff))
worst = []
for k in diff:
    rates = [r[h][k]["pass_rate"] for h in (1, 2, 3)]
    worst.append((max(rates) - min(rates), k, rates))
worst.sort(reverse=True)
for spread, k, rates in worst[:12]:
    print("%-28s pass_rate h1/h2/h3 = %.3f / %.3f / %.3f  (spread %.3f)" % (k, rates[0], rates[1], rates[2], spread))
# does the n=800 decision-relevant claim band hold in every run?
for h in (1, 2, 3):
    over_under = [r[h]["n800_%s_%s" % (c, a)]["pass_rate"] for c in ("uniform", "skewed", "clustered")
                  for a in ("over", "under")]
    nulls = [r[h]["n800_%s_null" % c]["pass_rate"] for c in ("uniform", "skewed", "clustered")]
    print("h%d: n800 over/under max pass %.3f (claim <=0.06) | null pass range %.3f-%.3f (claim 0.95-0.96)"
          % (h, max(over_under), min(nulls), max(nulls)))
