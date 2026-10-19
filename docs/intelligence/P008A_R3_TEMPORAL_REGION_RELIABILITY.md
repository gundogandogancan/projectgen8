# P008A-R3 — TemporalRegionReliabilityV1

Status: `TESTED`. Source: `TemporalRegionReliabilityV1` (ContentSegmenterV4.swift).

## Principle (§10)
Instead of static region weights, estimate TEMPORAL PERSISTENCE per generic normalized region
(center / global / top / bottom / left / right). Regions that stay nearly constant for long periods are likely UI
chrome → reduced transition influence. Regions carrying dynamic content → more influence. Edges are **never
permanently discarded** (a floor keeps them contributing for edge-to-edge media).

## Mechanism
Per region, a bounded EMA of its per-frame change:
```
changeEMA[r] = (1-α)·changeEMA[r] + α·observedChange[r]      // α = reliabilityAlpha (0.1)
weight[r]    = max(floor, changeEMA[r] / max(dynamicMax, ε))  // floor = reliabilityFloor (0.15)
```
Weights normalize so the most dynamic region ≈ 1 and persistently-static chrome falls to the floor (0.15) — down-
weighted but never zero. These weights feed the reliability-weighted frame distance used for MotionEnergy and
PRE/POST discontinuity, so a chrome-only change contributes little and cannot by itself cross the transition bar.

## Interaction with the overlay / center rules
Reliability weighting is the soft signal; two hard rules complement it: `isOverlay` (localized low-reliability
change with a stable center → OVERLAY_CHANGE, never a boundary) and `centerTransitionFloor` (a NEW segment must
move the content/center). Together they held overlays (subtitles / comments / menu / dense-overlay stress) to
**zero false segments** in held-out and stress.

## Evidence
`testRegionReliability`: after repeated center-only change, `w.center > w.top` and `w.top ≥ 0.15` (floored, not
discarded). Held-out persistent-chrome R=1.00 / P=1.00; all overlay slices FP=0.
