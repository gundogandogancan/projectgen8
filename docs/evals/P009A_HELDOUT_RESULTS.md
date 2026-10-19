# P009A — HELD-OUT Results (run once, frozen `item-grouping-policy-v1`)

Status: `TESTED`. Set: `corpus(seed:1)`, evaluated ONCE. Source: `testHeldOutGroupingTargets`. 42 items / 24 slices.

## §20 predeclared gates — ALL PASS
| metric | gate | achieved | verdict |
|--------|-----:|---------:|:-------:|
| new-item precision | ≥ 0.97 | **1.000** | PASS |
| new-item recall | ≥ 0.90 | **0.944** | PASS |
| new-item F1 | ≥ 0.93 | **0.971** | PASS |
| same-item merge precision | ≥ 0.98 | **1.000** | PASS |
| false cross-item merge / item | ≤ 0.01 | **0.0000** | PASS |
| internal-cut items must not explode | — | multi-cut/montage/music-video/slideshow all 1 item (0 FP) | PASS |
| rapid distinct items must not collapse | — | rapid-swipes 3/3 boundaries confirmed, 0 merges | PASS |

Supplementary: merge recall 0.970 · ambiguous 3 (1 in the designed-ambiguous slice; the other 2 are that slice's
remaining internal merges held provisional) · shots/item 2.60 · efficiency: one downstream analysis per item.

## Per-slice honesty
23 of 24 slices fully correct. The only imperfect slice is `ambiguous-identity` (scenario 24 — no caption, no audio,
similar theme, cut entry): its true boundary returns AMBIGUOUS rather than CONFIRMED-new, and its internal merges are
held provisional. That is the LABELED-ACCEPTABLE outcome (§7/§18): identity genuinely is ambiguous at Tier 0, and the
safety rule forbids guessing. All edited multi-cut forms (montage, music-video, slideshow, talking-head+B-roll,
topic-continuous, caption-continuity, same-speaker, no-audio) coalesce to exactly one item; all true item boundaries
(swipes, cut-presenting swipes, crossfade/autoplay, ad, app-surface, visually-similar/same-template adjacent) are
confirmed with zero false merges.

## Reading
The brain closes the exact device gap the V5 sensor exposed (57 shots vs ~20 items): shots/item 2.60 on fixtures with
ZERO cross-item leakage and new-item precision 1.000. This is the first phase where ALL predeclared lab gates pass
outright. The remaining step before a full PASS is the §21 fresh real-device item-group validation (user-gated).
