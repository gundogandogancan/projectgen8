# RWC IRR PLANNING LAW V4 (FROZEN PRE-DATA — R3)

Supersedes RWC_IRR_PLANNING_V3.md (byte-preserved; its ">= .61" threshold is the A16-F11 drift
negative evidence — it is never the operative threshold).

## 1. CANONICAL THRESHOLD RESTORED (A16-F11)

The IRR decision law threshold is RESTORED to its historical frozen value:

**Ordinal quadratic-weighted kappa hard gate: 95% bootstrap CI LOWER BOUND >= 0.60**

This is the actual historical frozen value, established in gates v2 and PRE-08 ("kappa_w >= 0.60
retained"). The v3 value of 0.61 was silent undisclosed drift (AUDIT16 A16-F11): never
predeclared, never rationale-documented, ledger silent on the change; it is hereby RESTORED
pre-data (no labels have ever been seen). Restoration requires no scientific justification because
no predeclared justification existed for the silent upward drift.

**Law:** Any future threshold change requires an explicit dated prereg amendment with scientific
rationale — no silent change is ever permitted.

The full gate remains: PASS iff 95% seeded-bootstrap CI LOWER BOUND >= 0.60 (quadratic-weighted
kappa); B=2000; degenerate replicates excluded; valid-replicate fraction >= 0.80 else
INSUFFICIENT_DATA.

## 2. Planning constants (unchanged from V3)

- **MIN_VALID = 50** pairs — mathematical evaluability floor only (below this: INSUFFICIENT_DATA,
  not FAIL). Unchanged.
- **PLANNED_TARGET_N = 300** pairs — the minimum the annotation campaign must plan per gated IRR
  family.

Independent support (AUDIT16 replication): true kappa .70 -> 19.2% / 17.5% / 41.7% pass rate at
n=50 / n=100 / n=200; kappa .75 -> 87.3% / 84.7% pass at n=300 under thresholds .60 / .61
respectively (thresholds .60 and .61 differ only 2-6pp in pass probability at n=300); kappa .80
-> 98.7% at n=300 under either threshold.

Campaigns must plan kappa >= ~.75 performance AND n >= 300 or expect honest FAIL/INSUFFICIENT_DATA
outcomes — which block, and are meant to block, annotation scale-up.

## 3. Mirrored code constants

`RWCCalibrationMethodologyV4.irrOrdinalKappaThreshold = 0.60`
`RWCCalibrationMethodologyV4.irrMinValidPairs = 50`
`RWCCalibrationMethodologyV4.irrPlannedTargetPairs = 300`

## 4. Zero-data declaration

No annotators have run; this is campaign planning law only. No labels have been seen. The
threshold RESTORED here is the pre-data canonical value.
