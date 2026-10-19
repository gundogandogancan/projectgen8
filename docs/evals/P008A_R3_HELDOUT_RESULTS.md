# P008A-R3 — HELD-OUT Results (run once, frozen policy-v4)

Status: `TESTED`. Set: `corpus(seed: 1)` — evaluated EXACTLY ONCE with `ContentBoundaryPolicyV4.frozenV4`.
Source: `testHeldOutRecorded`. Match tolerance ±4 frames. True boundaries = 18.

## Overall
**P = 1.000 · R = 0.889 · F1 = 0.941 · duplicate/item = 0.000 · false-new/item = 0.000 · maxConsecutiveCommitRun = 0**
(committed 16, true 18 → FN 2, FP 0, duplicates 0.)

## Predeclared aspirational targets (§17) vs achieved
| metric | aspirational | achieved | verdict |
|--------|-------------:|---------:|:-------:|
| precision | ≥ 0.95 | **1.000** | PASS |
| recall | ≥ 0.90 | **0.889** | NARROW MISS (−0.011) |
| F1 | ≥ 0.92 | **0.941** | PASS |
| duplicate/item | ≤ 0.05 | **0.000** | PASS |

## Per-slice (weak slices NOT hidden)
R=1.00 & P=1.00 on **16 of 18** slices: low-motion-static, talking-head, panning... — specifically: static, talking-head,
subtitles, comments-overlay, menu-overlay, autoplay-crossfade, ad-transition, **rapid-3-swipe**, slow-swipe,
repeated-same, same-theme, dark-to-dark, bright-to-bright, **persistent-chrome**, center-only, partial-screen —
all perfect, **zero false positives anywhere**.
The only misses (fail-SAFE, FN not FP): **high-motion-sport R=0.00 (1 FN)** and **panning-landscape R=0.00 (1 FN)** —
cuts between two very-high-motion items whose frame clouds overlap (the device-profile overlap zone). These are the
documented §28 error-budget case; they do not cause spam and precision stays 1.000.

## Reading
This is the exact inverse of every prior failure: BEFORE over-detected (406), R1 under-detected (recall 0.25),
R2/V3 catastrophically over-detected (477, ratio 23.9). V4 commits almost exactly the right number with **zero false
segments** and misses only the two frame-wise-ambiguous high-motion cuts. The predeclared recall gate is narrowly
missed (0.889 vs 0.90) on those, which — together with the user-gated fresh device run — keeps the status at
FIX REQUIRED rather than a full PASS, per §25/§26. Precision, F1, duplicate, and no-spam all exceed target.
