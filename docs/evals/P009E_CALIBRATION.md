# P009E — CALIBRATION split results
n=11 scored, 0 abstained: ordinal MAE 0.580. Risk calibrator reliability: ECE 0.220 / Brier 0.163 / AUROC 0.86 / 5 bins (reliability-bin data printed by the suite for auditor recomputation). Aspirational ECE≤0.05 NOT met (tiny engineering data) — reported, not relaxed. First consumption of P009B CAL_RESERVED happened here (7 pairs; bank content intact).

## P009E-R1 (dataset V2 — A8-F1/F2 closed; live numbers)
Full resolution 59/59 (TRAIN 26 / CAL 12): CAL ordinal MAE **0.743** (honest worsening vs the defective-
dataset 0.580 — auditor-predicted direction), risk ECE **0.250** / Brier 0.139 / AUROC 0.94 (3 bins;
index-based binning, each prediction exactly once). HELD_OUT_FINAL once: MAE **0.559**. Still
ENGINEERING_CALIBRATION_ONLY; ECE gate UNMET-UNRELAXED. V1 registry frozen as AUDIT8 evidence.
