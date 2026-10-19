# P008A-R2 — TUNE Split Results (policy selection)

Status: `TESTED`. Set: `corpus(seed: 0)` ONLY (held-out labels never inspected during tuning).
Source test: `P008AR2BoundaryV3Tests.testTuneScanExploratory`. True boundaries in TUNE = 36.

## Candidate scan (recorded, every candidate)
| candidate | P | R | F1 | dup/item | committed |
|-----------|--:|--:|---:|---------:|----------:|
| default (= frozen V3) | 1.000 | 0.972 | 0.986 | 0.000 | 35 |
| c2r2 (agree2,confirm2,refr2,mult2.0) | 1.000 | 0.500 | 0.667 | 0.000 | 18 |
| c1r2 (confirm1,refr2,mult1.8) | 1.000 | 0.972 | 0.986 | 0.000 | 35 |
| sensitive (jump0.18,floor0.10,mult1.6) | 1.000 | 0.917 | 0.957 | 0.000 | 33 |
| frozen (`.frozenV3`) | 1.000 | 0.972 | 0.986 | 0.000 | 35 |

## Selection rationale
Optimized jointly for high recall, high precision, low duplicate commits, low latency, bounded memory:
- `c2r2` collapses recall (0.50) — too conservative (the R1 failure mode). Rejected.
- `sensitive` over-lowers thresholds for no precision gain and risks device-side spam. Rejected.
- `default`/`c1r2`/`frozen` tie at the top (R=0.972, P=1.000, dup=0). Chose the **default constructor
  values** as the frozen policy — the simplest, no bespoke overrides, easiest to audit and version.

## Frozen parameters (selected on TUNE only)
`wCenter 0.42 · wGlobal 0.18 · wHistogram 0.18 · wSides 0.10 · wTop 0.06 · wBottom 0.06 ·
sameThreshold 0.06 · regionJumpFraction 0.22 · minRegionAgreement 2 · transitionFloor 0.07 ·
strongJumpDistance 0.30 · strongRegionAgreement 3 · centerContentFloor 0.12 · confirmFrames 1 ·
refractoryFrames 2 · dynamicWindow 12 · dynamicJumpMultiplier 1.5 · minDynamicThreshold 0.07 ·
maxDynamicThreshold 0.40` → `ContentBoundaryPolicyV3.frozenV3`, revision `boundary-policy-v3`.

No held-out label was examined to produce any of the above.
