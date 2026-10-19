# P008A-R2 — Content-Region Weighting

Status: `TESTED`. Source: `ContentBoundaryPolicyV3` weights + `BoundaryEvidenceAccumulatorV3.weighted`.

## Principle
A feed/item transition is defined by the **content** changing, not the shared **chrome** (nav bars,
tab bars, comment trays, keyboards, like/overlay buttons). The screen is sampled as normalized
sub-rects — NO hardcoded pixel coordinates, so it generalizes across apps and orientations:

- `center` = `[0.25,0.75]×[0.25,0.75]` → the content region (highest weight)
- `top` = top 25% band, `bottom` = bottom 25% band → chrome (lowest weight)
- `left`/`right` = outer 25% columns → edge content for edge-to-edge media (modest weight)
- `global` = whole frame; `histogram` = 4-bin luma distribution (brightness/scene shifts)

## Frozen weights (`boundary-policy-v3`)
| region | weight |
|--------|-------:|
| center | 0.42 |
| global | 0.18 |
| histogram | 0.18 |
| sides (avg l+r) | 0.10 |
| top | 0.06 |
| bottom | 0.06 |

Weights are normalized by their sum, so `D ∈ [0,1]`. Center dominates; chrome bands are deliberately
weak so overlays/keyboards cannot by themselves cross the transition threshold.

## Center-centric gates (why weighting alone is not enough)
Weighting lowers chrome influence but a big enough chrome jump could still sum past threshold. Two
hard gates make the content requirement explicit:
- **`chromeOnly`**: if `center < sameThreshold (0.06)` AND any chrome region jumped
  (`>= regionJumpFraction 0.22`) → classified **OVERLAY_CHANGE**, never a boundary.
- **`centerContentFloor` (0.12)**: a transition REQUIRES the center to have moved at least this much.

This is what fixed the R1-era over-suppression of center-only / persistent-chrome apps (slice 16/17)
while keeping overlays (slices 5/6/7) at zero false boundaries.

## Evidence
`testMultiRegionDistances` asserts a center-only change yields `d.center > 0.4` with `d.top ≈ d.bottom ≈ 0`.
Held-out `persistent-chrome` R=1.00, `center-only` R=1.00, overlay slices FP=0.
