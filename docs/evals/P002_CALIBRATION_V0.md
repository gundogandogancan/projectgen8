# P002 — Calibration v0

**Doc status:** `CANONICAL` · **Phase:** 2 · **Date:** 2026-10-18 · PROMPT 002 §16 / 002A §10.

## Status
`CALIBRATION_STATUS = UNAVAILABLE_INSUFFICIENT_DATA`

Golden Dataset v0 is a tiny synthetic pipeline-validation set. **There is not enough data to calibrate** probabilistic heads honestly. **No fake calibration curve is produced.** (Build Bible §52, §69; Calibration Plan.)

## Implemented now (infrastructure, honest)
- **Raw vs calibrated confidence separation** — provider outputs carry raw confidence; a calibrated confidence field is introduced but set to `nil`/`UNAVAILABLE` until a calibration artifact exists.
- **Calibration artifact schema** (planned under `ml/manifests/`): `{taskId, method, datasetSplitRef, version, createdAt, reliabilityBins[], ece, brier, status}`.
- **Calibration dataset split** reserved (`split: "calibration"` in `sample.schema.json`).
- **Abstention/UNKNOWN threshold contract** — heads abstain below a confidence floor; thresholds are versioned and never inflate confidence.
- **Per-task calibration** — one artifact per task (identity/language/ocr/semantic…), never a global number.

## Gate
No calibrated confidence may be shown to users or used in admission until a calibration artifact with sufficient data exists. Until then, UI shows raw confidence bands or `?`, and admission treats low/uncalibrated confidence as reduced trust (UNKNOWN where insufficient).
