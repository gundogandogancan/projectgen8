# RWC-PRE-09 — SAMPLE SIZE / CI / BASE-RATE FEASIBILITY (preregistered assumptions ONLY)

ASSUMPTIONS (explicit; engineering-era synthetic corpus informed, NO real-corpus observation):
unsuitable-class base rate 0.25-0.40; strong-protection prevalence in sentinel-targeted sampling
>= 0.80; TR/EN roughly balanced by design of acquisition targets; per-item dual annotation.
METHODS (code twin RWCStatisticsV1): Wilson score CI for proportions; rule-of-three for zero-event
upper bounds (95% UB ~= 3/n); normal-approximation planning n = z^2 p(1-p)/h^2; bootstrap (B=2000,
seeded) planned for ECE/MAE CIs at evaluation time.
KEY FEASIBILITY RESULTS (planning, not measurements):
- falseSafe: ZERO observed events on n sentinels implies 95% UB 3/n -> n=150 gives UB 2.0%; n=300 gives
  1.0%. FROZEN REQUIREMENT: sentinel n >= 150 AND observed falseSafe = 0; REPORT the UB always -
  'zero observed' NEVER claims 'zero rate'.
- ECE <= .05 gate: detecting a .05 calibration gap against bin noise requires >= ~380 evaluation items
  (h=.05, p~.5 worst case, z=1.96 planning bound) -> FROZEN: overall evaluation pool (CAL+HELDOUT)
  >= 400 labeled pairs; HELD_OUT_FINAL >= 150.
- Powered slice: h=.07 -> n >= ~196 is infeasible per slice initially; slices therefore use a RELAXED
  CI-report regime with min n = 60 and min 15 positive / 15 negative where class-relevant; slices below
  minimums are UNDERPOWERED -> UNKNOWN/INSUFFICIENT_DATA (never gate-passing, never aggregate-hidden).
- AUROC: Hanley-McNeil-style SE at n=400, prevalence .3 => +/-~.03-.05 - adequate for REPORTING with CI;
  rejected as a hard release gate (base-rate sensitive; discrimination is secondary to calibration).
- IRR: 50-pair minimum gives kappa SE ~0.1 under moderate agreement - acceptable for batch gating.
NO OUTCOME-AWARE TUNING: these numbers freeze BEFORE any real data exists and cannot be revised after
results without invalidation (PRE-11 law).
