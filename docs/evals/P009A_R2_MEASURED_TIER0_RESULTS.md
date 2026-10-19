# P009A-R2 — MEASURED Real-Device Tier-0 Evidence Distributions

Status: `MEASURED — TIER-0 NOT SAFELY SEPARABLE` (Outcome C). Policies untouched (no tuning in this turn).
Evidence (immutable, git-anchored): `artifacts/P009A_R2_MEASURED_tier0_evidence.log`
SHA-256 `09f28beedbdc991ffbccccdd777e8484eb7f789d34136427f2f093d62019b0a7` · commit follows the H1 discipline.
Session: `evidence=true`, frames 7844 (~154 s), **89 shots / 88 SHOTEV per-channel records / 86 items / 3 SAME /
12 AMBIGUOUS / 73 NEW**, reuse 3, 1 START + 1 FINISHED, 89/89 `score=UNKNOWN`. First-ever per-channel capture
(closes audit finding B1).

## Labels (MANUAL_APPROXIMATE, conservative — §4)
From the scripted A→K order + large-gap anchors: SAME_ITEM_INTERNAL_CUT n=10 (interiors of blocks A/B/C),
NEW_ITEM n=3 (A→B, B→C, D slow swipe), launch-noise excluded n=7, **UNLABELED n=68** (dense mid-session activity —
F/G/H/I/J blocks could not be pinned without exact user times; left out rather than guessed).

## §4 per-channel distributions (SAME vs NEW)
| chan | class | min | p25 | p50 | p75 | max |
|------|-------|----:|----:|----:|----:|----:|
| theme | SAME | 0.270 | 0.308 | 0.386 | 0.455 | 0.531 |
| theme | NEW | 0.319 | 0.319 | 0.559 | 0.661 | 0.661 |
| proj | SAME | 0.000 | 0.082 | 0.430 | 0.440 | 0.979 |
| proj | NEW | 0.038 | 0.038 | 0.072 | 0.455 | 0.455 |
| hist | SAME | 0.062 | 0.094 | 0.438 | 0.688 | 0.844 |
| hist | NEW | 0.203 | 0.203 | 0.344 | 0.406 | 0.406 |
| chrome | SAME | 0.148 | 0.297 | 0.375 | 0.477 | 0.586 |
| chrome | NEW | 0.094 | 0.094 | 0.117 | 0.500 | 0.500 |
| regional | SAME | 0.156 | 0.240 | 0.349 | 0.500 | 0.661 |
| regional | NEW | 0.172 | 0.172 | 0.479 | 0.573 | 0.573 |

## §6 separability — MEASURED, every channel materially overlaps
- **theme**: SAME p50 0.386 ≫ continuity threshold 0.22 → theme continuity almost never fires even on true internal
  cuts; ranges overlap. NON-SEPARATING at 64-bit thermo resolution.
- **hist**: SAME p50 0.438 > NEW p50 0.344 — the 4-bin histogram changes MORE across internal cuts than across item
  boundaries in this sample. NOISE (the "production color-grade continuity" assumption is measured FALSE at 4 bins).
- **chrome / regional**: both classes 0.1–0.66; real top/bottom bands churn constantly (translucent UI over video).
  NOISE.
- **proj**: the only real signal — a distinct high-continuity mode (≥0.70: 14/88 rows, with hist p50 0.109,
  theme p50 0.286; produced 2 SAME + 10 AMBIGUOUS + 2 NEW). But ONE-SIDED and SPARSE: only ~2/10 labeled internal
  cuts reach it → merge-recall ceiling from proj alone ≈ 20%. High-proj ⇒ likely same; low-proj ⇒ nothing.
- **dwell/cadence**: `prevDwellMs = 0 on ALL 88 rows` — **DEFECT FOUND BY MEASUREMENT**: stored shot descriptors
  never receive their end-time update (ShotSegmenterV5 updates only its internal copy), so the long-dwell feature
  and the weak-theme dwell gate were dead on device in ALL prior runs too. Gap-based cadence remains but cannot
  separate (rapid swipes = sub-second NEW; montage = sub-second SAME).

## §7 redundancy (Pearson, all 88 rows)
theme~regional +0.64 · hist~regional +0.60 · chrome~regional +0.58 · proj anti-correlated with all (−0.44…−0.70):
the channels are mutually redundant views of gross luma change; combining them adds no independent information.

## §8 Tier-0 information ceiling (measured)
At current feature resolution (64-bit region thermo hashes, 8-bin projections, 4-bin histograms), internal cuts and
item boundaries **materially overlap on every channel**; the only reliable structure is a sparse one-sided
projection-continuity mode good for occasional precision-first merges (observed: 3 safe SAMEs, 0 false merges).
Item-grouping economy is NOT achievable from these features. Richer candidate features (dHash, higher-resolution
projections, color moments, edge histograms) were NOT logged in this run and can only be assessed by a future
instrumented benchmark (Outcome-B path, optional, not shipped).

## §9 resource overhead of the evidence build (measured separately — DEBUG/AUDIT ONLY, must never ship)
cheap p50/p95 **3.181 / 5.278 ms** (vs 1.372/2.887 non-evidence = ~2.3×, driven by 7844 per-frame MOTION log
writes) · peak memory 30.4 MB · **thermal SERIOUS on 89/89 decisions** (first serious ever — logging I/O load).
Confirms: `GEN8_EVIDENCE_BUILD` is a measurement instrument, not release behavior.

## §10 privacy recheck — PASS
Container = exactly one derived `.log` (1,438,888 B); media sweep (mp4/mov/png/jpg/heic/wav/m4a/caf/yuv/raw) = **0**;
SHOTEV fields are derived scalars only; 89/89 `score=UNKNOWN`; no upload (`cloud=false`). 6th consecutive clean container.

## §11 OUTCOME: **C — TIER-0 IS NOT SAFELY SEPARABLE** (current features)
Per prompt-02 §5: do NOT force item grouping in the extension. **Capability truth declared:**
- `EXTENSION_FAST_TIER0` provides **shot segmentation + provisional item identity** (safe splits, rare
  precision-first proj merges, zero false merges) — its item COUNT is APPROXIMATE by design.
- **Full item grouping requires Tier-1 in-process multimodal evidence** (captions/audio/feature-print in the app
  process) **or a future official shared-container capability.** Safety beats count-matching.

## §12 next architecture decision (for P009A closeout / Phase C of the DAG)
1. Fix the measured dwell defect (end-time propagation) — a correctness bug, not tuning.
2. Reclassify Tier-0 outputs: provisional-item identity feeds Tier-1; stop gating the extension on item-ratio.
3. Optional future Outcome-B benchmark (dHash/higher-res projections/color moments) via one more instrumented run —
  only if Tier-1 grouping proves insufficient.
4. Known open safety blocker preserved: auditor probe C6 (`testAUDIT_rapidSwipeAndMontageStressNoFalseMerge`,
  bright-to-bright stress false merge) remains FAILING in the suite intentionally as an open blocker.
