# RWC IRR PLANNING LAW V3 (FROZEN PRE-DATA — R2; A15-F14)

The IRR DECISION LAW is UNCHANGED from the R1 freeze (PRE-08 v2 + gates): PASS iff the 95%
seeded-bootstrap CI LOWER BOUND >= threshold (ordinal quadratic-weighted kappa >= .61 law;
B=2000; degenerate replicates excluded; valid-replicate fraction >= 0.80 else INSUFFICIENT_DATA;
kappa=.61 with CI [.30,.75] => FAIL). The threshold is NOT weakened by this document.

AUDIT15 measured the gate's operating characteristics (120 trials/cell, mixture-rater model,
Wilson CIs): true kappa .55 → PASS <= 1.7%; .60 → 0.8-5.8%; .65 → 10-14%;
**.70 → 19.2% (n=50) / 17.5% (n=100) / 41.7% (n=200)**; .80 → 49.2 / 75.0 / 91.7%;
.90 → 88-100%. The gate is strongly conservative: genuinely acceptable agreement (kappa ≈ .70)
usually FAILS at n <= 200. PRE-08's "≥100 pairs for comfortable passes at kappa ~.75" guidance was
optimistic (A15-F14) and is SUPERSEDED by this planning law; PRE-08's decision law itself stands.

## Frozen planning distinction

- `MIN_VALID = 50` pairs — mathematical evaluability floor ONLY (below: INSUFFICIENT_DATA).
  Unchanged.
- `PLANNED_TARGET_N = 300` pairs — the MINIMUM the annotation campaign must PLAN per gated IRR
  family. Basis (pre-data, from the AUDIT15 operating table): at n=200 the pass probability is
  ~92% only at kappa=.80; extrapolating the measured n-trend, n>=300 is required for a
  comfortably powered decision when true agreement is in the .75-.80 band that the handbook
  training targets. Teams must plan for kappa >= ~.75 performance AND n >= 300, or expect an
  honest FAIL/INSUFFICIENT_DATA outcome — which blocks, and is meant to block, annotation scale-up.

These constants are mirrored in code: `RWCCalibrationMethodologyV3.irrMinValidPairs = 50`,
`RWCCalibrationMethodologyV3.irrPlannedTargetPairs = 300`.

Zero-data: no annotators have run; this is campaign PLANNING law only.
