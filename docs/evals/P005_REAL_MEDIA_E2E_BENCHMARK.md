# P005 — Real Media E2E Benchmark

**Doc status:** `CANONICAL` (LAB_MEASURED) · **Phase:** 5 · **Date:** 2026-10-18 · PROMPT 005 §31. Artifact: `ml/evaluation/results/p005-e2e-benchmark.json`. **macOS LAB timing — NOT device certification.** Assets are project-OWNED synthetic MP4s generated headless (AVAssetWriter). Unlike devices are not compared as one metric.

## Measured (real AVFoundation decode + Vision OCR E2E, macOS LAB)
| Asset | Duration | Samples | Frames extracted | OCR calls | Scene boundaries | Flagged windows | Coverage visual% | Analysis (ms, LAB) |
|---|---|---|---|---|---|---|---|---|
| neutral-2s | 2s | 16 | 16 | 16 | 0 | 0 | ~100 | ~218 |
| textoverlay-3s | 3s | 16 | 16 | 16 | 2 | 0 | ~100 | ~196 |
| flagged-4s ("EARTHQUAKE DISASTER") | 4s | 16 | 16 | 16 | 2 | **4** | ~100 | ~192 |

(Values regenerate deterministically per run; exact ms varies with host load — labelled LAB.)

## What this proves
- Real decode → OCR → MDD flagging works E2E on genuine video (flagged windows arise from **real OCR of decoded frames**, not fixtures).
- Sample counts bounded (16 @ balanced); no full-FPS loop.
- Coverage reported with every result.

## Not claimed (honest)
Device CPU/energy/thermal/memory high-water/UI smoothness and first-trustworthy-decision on real device → require physical device + Instruments (`P005_DEVICE_EVIDENCE.md`, PENDING). Longer-duration (15/30/60 min) real assets are device/manual to keep CI bounded.
