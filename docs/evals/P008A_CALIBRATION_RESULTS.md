# P008A — Calibration Results (§12,§13,§16) — REAL held-out, honest outcome
Method: transparent 1-D logistic (Platt) calibrator fit on a train split, evaluated on a disjoint held-out split
(`CalibrationPilotRunner`, deterministic gradient descent). Metrics are REAL (not asserted-to-pass).

## Held-out results (LAB pilot; project-authored TR+EN text; `P008ACoreTests.testCalibrationPilotHeldOut`)
```
overall n=6  ECE=0.554 (raw ECE=0.400)  Brier=0.155  MAE=0.152  P=0.50  R=1.00  F1=0.67  falseSafe=0.500
lang=en n=3  ECE=0.561  Brier=0.164  MAE=0.152  falseSafe=0.500
lang=tr n=3  ECE=0.546  Brier=0.147  MAE=0.143  falseSafe=0.500
```
## Honest interpretation (this is the point)
The pilot is TINY and the held-out metrics are POOR: **false-safe = 0.50** (half the actually-unsuitable items were
predicted suitable) and calibration did NOT improve ECE. This correctly demonstrates that a toy LAB pilot is
**insufficient** to trust a displayed score. Therefore:
- Calibration level claimed: at most `LAB_CALIBRATED_LIMITED`, and in practice **NOT good enough to display a number** —
  the score gate (CalibrationScope.covers + coverage + identity + no-critical-conflict) keeps real content at UNKNOWN.
- We do **not** upgrade status because a test passed; the metric numbers themselves forbid it (§13).
- A trustworthy calibrated score needs a materially larger, multi-annotator, rights-clear TR/EN dataset (future).
`NO SCORE WITHOUT CALIBRATION` holds: with these metrics, production content stays UNKNOWN.
