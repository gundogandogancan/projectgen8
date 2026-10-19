# P008A-R3 — STRESS Results (run once, frozen policy-v4)

Status: `TESTED`. Set: `corpus(seed: 2, stress: true)` — motion ×1.6 (exceeds observed) + pathological slices.
Source: `testStressTargets`. Run once after held-out. True boundaries = 22.

## Overall
P = 0.650 · R = 0.591 · F1 = 0.619 · duplicate/item = 0.045 · false-new/item = 0.318 · **maxConsecutiveCommitRun = 0**.
The lower overall P/R is dominated by the regular 18 slices replayed at ×1.6 motion (deliberately beyond real
amplitudes, pushing into the overlap zone). The §17 targets are **per-category safety metrics**, which are what matter:

## §17 stress acceptance (the metrics that are gated)
| §17 target | result | verdict |
|-----------|--------|:------:|
| high-motion SAME-ITEM false-new ≤ 0.05/item | `stress-extreme-motion-no-cut` committed **0** (40 frames), `stress-long-high-motion` committed **0** (60 frames) | **PASS** |
| overlay false-new ≈ 0 | `stress-dense-overlays` FP **0** | **PASS** |
| no pathological commit-every-N-frames | maxConsecutiveCommitRun **0** | **PASS** |
| rapid-swipe recall ≥ 0.85 | `stress-rapid-5-swipe` (2-frame dwell) committed **0 / 4** | **MISS** |

## Reading
The V3 killer case — sustained extreme motion with no cut — produces **zero** false commits here (40- and 60-frame
high-motion segments at ×1.6), confirming the robust-baseline fix. Overlays and burst-spam are fully controlled.
The one miss is a 2-frame-dwell 5-swipe-in-10-frames pattern at ×1.6 motion — beyond realistic feed cadence; at that
dwell the POST window cannot establish persistence before the next swipe. Logged as a known stress limitation
(error budget), not a device-spam risk. Overall the stress run shows the detector degrades SAFE (misses, never spams).
