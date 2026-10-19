# P009A-R1 — Tier-1 Regression Results (run once)
Status: `TESTED`. §14: Tier-1 re-run with its OWN profile policy (`item-grouping-policy-v2-app-tier1`); Tier-0
thresholds NOT reused (profile-normalized ceilings differ: 1.60 vs 0.95).
- v1 engine/policy (frozen P009A evidence): APP_FULL held-out still mergeP ≥ 0.98 — no silent regression, untouched.
- V2 Tier-1 on the Tier-0 held-out corpus (captions/audio absent → graceful): newP **1.000**, mergeP **1.000**,
  false cross-item merge **0.0000**/item ≤ 0.01 ✓ — prior safety metrics preserved.
Tier-1's extra channels only ADD evidence when present; their absence does not penalize (ceiling normalization).
