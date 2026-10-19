# P006 — Long-Content Budget Benchmark

**Doc status:** `CANONICAL` (LAB_MEASURED) · **Phase:** 6 · **Date:** 2026-10-18 · PROMPT 006 §43. Artifact: `ml/evaluation/results/p006-long-content-budget.json`.

## Measured (macOS LAB, balanced mode)
| Duration | Sample count | Audio windows | Fast heads | Deep heads |
|---|---|---|---|---|
| 60 s | 18 | 6 | — | — |
| 5 min | 26 | 6 | — | — |
| 30 min | 32 | 6 | — | — |
| 60 min | 32 | 6 | — | — |

## Proven invariant
**Complexity grows sublinearly:** a 60× longer video (60s→3600s) uses **<2×** the samples (18→32), not 60×. Audio windows bounded. No full-FPS/full-audio brute force. Head plans are selected (FAST/DEEP), never "run all heads".

## Honesty
Memory high-water, first-decision wall-clock, deepening time on real long assets → require real media + device (PENDING; §44). Long real assets kept out of CI to bound time; this benchmark measures the **budgeting/planning layer** deterministically.
