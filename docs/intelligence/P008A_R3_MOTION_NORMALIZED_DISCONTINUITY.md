# P008A-R3 — Motion-Normalized Discontinuity

Status: `TESTED`. Source: `BoundaryEvidenceAccumulatorV4` (ContentSegmenterV4.swift).

## The V3 trap
V3 used an absolute rule `D ≥ 0.07`. On real video the per-frame content change is ≥ that nearly every frame
(device telemetry: within-item motion median 0.123), so it fired constantly. §6: do NOT rely on an absolute
constant as the primary transition rule; absolute floors may exist only as safety guards.

## V4 normalized rule
```
recentMotionScale = clamp(median(MotionEnergy) + madK·MAD, minMotionScale, maxMotionScale)   // robust, learned
normalizedAbrupt  = shortWindowChange / max(ε, recentMotionScale)                              // OPEN trigger
confirm:  prePostDistance ≥ confirmMotionRatio · max(recentMotionScale, withinPreMotion, withinPostMotion)
```
Bounded caps (`minMotionScale 0.05`, `maxMotionScale 0.45`) prevent explosion when motion is near zero. The only
absolute term is `absoluteSafetyFloor (0.16)` guarding against near-zero-motion noise — a guard, not the rule.

## Why it separates motion from cuts (evidence)
Device-derived separation (P008A_R2_AFTER_crossapp_device_v3.log): within-item motion median 0.123 (p95 0.257),
cut-like 0.370 — ratio ≈ 3.0. So a cut's PRE→POST distance is ~3× the motion scale, while ongoing motion's
normalized value stays ≈1. The confirm requires the discontinuity to exceed the motion scale AND both within-window
motions, so a motion *excursion* (which has high within-window motion) cannot masquerade as a persistent cut.

## Frozen thresholds (`boundary-policy-v4`, tuned on TUNE only)
`openNormalizedJump 1.3 · confirmMotionRatio 1.6 · absoluteSafetyFloor 0.16 · madK 1.4 · minMotionScale 0.05 ·
maxMotionScale 0.45 · centerTransitionFloor 0.10 · postPersistenceFrames 2 · maxTransitionFrames 10 ·
shortWindow 8 · veryShortWindow 3 · mediumWindow 40 · warmupFrames 5 · minSegmentFrames 3`.

## Known limit (honest)
When two adjacent items are BOTH very high motion (p95 ≈ 0.257) and their identity gap is near the transition
minimum (≈0.30), the frame clouds overlap and the cut is frame-wise ambiguous — the detector may miss it (held-out
high-motion-sport / panning). Per §28 this is an error-budget case, not a systemic failure; precision stays 1.000.
