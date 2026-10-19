# P008A-R4 — STRESS Results (run once, frozen policy-v5)

Status: `TESTED`. Set: `corpus(seed:2, stress:true)` — motion ×1.6 + pathological slices. Source: `testStressTargets`.

## Overall
P = 0.778 · R = 0.412 · false-new/item = 0.118 · **maxRun = 0** (committed 9, true 17). The lower overall P/R is
dominated by the regular slices replayed at ×1.6 (deliberately beyond observed motion). The §14 gates are the
per-category safety metrics, which pass:

## §14 stress acceptance
| §14 target | result | verdict |
|-----------|--------|:------:|
| sustained high-motion false-new ≤ 0.05/item | `stress-extreme-motion-no-cut` (40f) FP **0**, `stress-long-high-motion` (60f) FP **0** | **PASS** |
| panning false-new ≤ 0.05/item | `stress-long-pan-no-cut` (50f) FP **0**, `panning-continuous` FP **0** | **PASS** |
| overlay false-new ≈ 0 | `stress-dense-overlays` FP **0** | **PASS** |
| no periodic commit behavior | maxConsecutiveCommitRun **0** | **PASS** |

## Reading
Every pathological slice — the V4/V3 killer cases (sustained extreme motion, long pan, dense overlays) — produces
**zero** false commits at ×1.6 motion. The engine degrades SAFE (misses hard cuts, never spams). Rapid-swipe recall
under ×1.6 extreme cadence is reduced (the 220 ms dwell), logged as a known stress limitation (error budget §23),
not a device-spam risk.
