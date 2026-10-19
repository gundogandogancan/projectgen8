# P009E — Annotation Rubric (suitability-rubric-v1)
Ordinal 0–4: 0 protect / 1 unsuitable / 2 caution-mixed / 3 generally suitable / 4 strongly aligned — target is "suitability of exposure under the Gen8 policy rubric GIVEN the explicit profile", never "is it good". Dual independent annotator slots (pseudonyms ann-A/ann-B), disagreement PRESERVED (>3 disagreeing pairs test-asserted), adjudication only when |A−B|≥2 with trace; locale/profile/item/rubric-version on every record. Sentinel labels use the stricter categorical rubric (label 0 + no-false-safe gate). No labels derive from model output (authored before fitting; circularity structurally absent).

## P009E-R1 truth corrections (A8-F6 + simulation labeling)
Annotator slots are **SIMULATED_DUAL_SLOT (single-author; engineering-only)** — NOT independent humans
(`CalibrationDatasetRegistryV2.annotationMode`). Adjudication rule corrected to match practice:
"permitted on any disagreement; REQUIRED when |A−B| ≥ 2". Independent human annotation is a
REAL-WORLD-CALIBRATION-phase requirement.
