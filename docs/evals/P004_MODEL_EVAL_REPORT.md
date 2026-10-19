# P004 — Model Eval Report

**Doc status:** `CANONICAL` · **Phase:** 4 · **Date:** 2026-10-18 · PROMPT 004 §28. Per-task metrics only — **no single aggregate "Gen8 AI accuracy".**

## Trained head: `mdd-linear-v1` (Mortality/Disease/Disaster)
- **Architecture:** logistic-regression head over 6-d lexicon features (compact; "distilled lexicon-feature linear head"). Deterministic (zero-init + fixed split).
- **Data:** `synthetic-mdd-v1` — 20 OWNED synthetic samples (TR+EN, balanced). No scraped/private/child data.
- **Split:** idx%5==0 → test (4 samples), rest → train.
- **Metrics (held-out test, LAB):** overall F1 = 1.0, accuracy = 1.0, baseline (majority) F1 ≈ 0.667. EN test n=2, TR test n=2 (per-language reported separately).
- **Honesty:** F1/accuracy are on a **tiny 4-sample synthetic held-out set** — this proves the train→eval→export *pipeline*, **NOT production accuracy**. Status `ACTIVE_LAB`, never production.
- **Artifact:** `ml/training/runs/mdd-linear-v1.model.json` (weights) + `…manifest.json` (metrics, checksum). Checksum in `ON_DEVICE_MODEL_PACK.yaml`.
- **Calibration:** `UNAVAILABLE_INSUFFICIENT_DATA` (4 test samples; no reliability fit forced).

## Apple-native engines (behavior affects scoring)
Language ID / OCR / feature-print / embedding — evaluated functionally in P002/P003 (headless), per-task; device accuracy = RCOV.

## Eval gates (§28) status
Per-task metric table ✅ · confusion counts (tp/fp/tn/fn in `ClassifierMetrics`) ✅ · abstention behavior ✅ (band around 0.5) · TR/EN split ✅ · latency/resource class ✅ (TINY) · model/version ✅. No aggregate accuracy claim.
