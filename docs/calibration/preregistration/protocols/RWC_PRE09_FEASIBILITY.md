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

V2 SUPERSESSION NOTE (A14-F7): the single-proportion planning above (n~385 for h=.05) was the WRONG
statistic for a 10-bin ECE - AUDIT14 proved the v1 point gate noise-dominated (perfect model
E[ECE]~.050 at n=400). The calibration gate now follows the null-referenced equal-mass design in
RWC_CALIBRATION_POWER_PREREG.yaml with the frozen n >= 800 power law (Type-I 5% by construction;
power >= 94% vs delta=.07 over/under across three confidence shapes). falseSafe/IRR sections remain
valid. The v1 text above is preserved as negative evidence, not rewritten.

SENTINEL REPORT-SEMANTICS LAW (A14-F17): the falseSafe bound is CONDITIONAL ON SENTINEL-CLASS SAMPLING
- it is NOT a natural prevalence estimate; no population false-safe claim may be derived from targeted
sentinel sampling alone; every report labels the denominator and sampling design.
