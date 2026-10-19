# P008A-R4 — Pan vs Swipe

Status: `TESTED`. Source: `BoundaryEvidenceAccumulatorV5` (open spike-gate + confirm-side settle/replacement).

## The distinction (§4)
| | PAN / camera motion | FEED SWIPE / cut |
|---|---|---|
| direction | may be coherent | coherent |
| adjacent frames | temporally CONTINUOUS (no jump) | a DISCONTINUITY (old content exits) |
| PRE→POST content | remains related, evolves gradually | substantially NEW persistent state |
| replacement | gradual, spread over seconds | completes within a bounded time window |
| new stable state | none arrives abruptly | lands within maxTransitionMs |

## Two complementary mechanisms (no app-specific geometry)
1. **OPEN = abrupt STEP spike** (continuity filter). A candidate opens only when the max single inter-frame step is
   a SPIKE above the typical recent motion: `maxStep ≥ openStepRatio · median(recentMotion)`. A pan is smooth →
   every step ≈ the median → spike ≈ 1 → never opens. A cut/swipe is one isolated large step → spike ≫ 1 → opens.
2. **CONFIRM = persistent content REPLACEMENT that SETTLES** (not continuous evolution). Even if a pan opens, it
   must produce `regionalReplacementRatio ≥ minReplacementRatio` AND a settled POST (within-POST motion low relative
   to the jump) AND min dwell. A pan keeps evolving / does not land on a distinct replaced state within
   `maxTransitionMs` → classified `PAN_SAME_SEGMENT`, no commit.

## Evidence
Held-out: `panning-continuous` committed **0** (R=1.00 correct), `pan-then-cut` committed exactly **1** (the real cut
after the pan). Stress: `stress-long-pan-no-cut` (50 frames) committed **0**. `testPanDoesNotBecomeSwipe`: 24-frame
continuous pan → 0 commits. The cheap continuity score is the spike test; the replacement/settle gate is the backstop.
