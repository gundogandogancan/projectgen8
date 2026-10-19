# P008A-R4 — HELD-OUT Results (run once, frozen policy-v5)

Status: `TESTED`. Set: `corpus(seed:1)`, evaluated ONCE with `ContentBoundaryPolicyV5.frozenV5`. Tolerance ±7. True = 17.

## Overall
**P = 1.000 · R = 0.882 · F1 = 0.938 · duplicate/item = 0.000 · false-new/item = 0.000 · maxRun = 0**
(committed 15, true 17 → FN 2, FP 0, duplicates 0.)

## Predeclared aspirational targets (§14) vs achieved
| metric | aspirational | achieved | verdict |
|--------|-------------:|---------:|:-------:|
| precision | ≥ 0.95 | **1.000** | PASS |
| recall | ≥ 0.90 | **0.882** | NARROW MISS (−0.018) |
| F1 | ≥ 0.92 | **0.938** | PASS |
| duplicate/item | ≤ 0.05 | **0.000** | PASS |

## Per-slice (nothing hidden)
R=1.00 & P=1.00 on **16 of 18** slices — including the R4-critical ones: **panning-continuous (0 commits, correct)**,
**pan-then-cut (1, the real cut)**, **slow-swipe**, **same-theme**, **persistent-chrome**, **repeated-same**, all
overlays, crossfade, ad, dark/bright, partial-screen, low/talking. **Zero false positives anywhere.**
Misses (fail-SAFE, FN not FP): **high-motion-sport R=0.00** (frame-ambiguous high-motion→high-motion cut) and
**rapid-3-swipe R=0.50** (1 of 2; the second swipe falls inside the 220 ms dwell). Both are the §23 error budget.

## Reading
Every prior run failed on over/under-detection: 406 → 5 → 477 → 73. V5 commits almost exactly the right number with
**zero false segments and zero duplicates**, and — critically for R4 — **panning no longer produces false
segments**. The predeclared recall gate is narrowly missed (0.882 vs 0.90) on the two documented hard cases, which,
together with the user-gated fresh device run (§21), keeps the status at FIX REQUIRED rather than a full lock.
