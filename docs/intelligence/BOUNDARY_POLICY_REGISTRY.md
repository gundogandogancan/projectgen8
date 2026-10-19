# Content Boundary Policy Registry

Versioned record of every shipped/tested content-boundary policy. The extension logs the active
revision every session (`BROADCAST_STARTED … policy=<revision>`). Newer revisions supersede older
ones but older entries are never edited (audit trail).

| revision | engine | status | selected on | key result | notes |
|----------|--------|--------|-------------|-----------|-------|
| `boundary-policy-v2` | `ContentBoundaryEngineV2` (R1) | SUPERSEDED | — | device: 406→5 committed, recall ≈ 0.25 | stopped spam but UNDER-detected |
| `boundary-policy-v3` | `BoundaryEvidenceAccumulatorV3` (R2) | **DEVICE-FAILED** (lab-accepted, device over-detects) | TUNE `corpus(seed:0)` only | held-out P=1.000 R=0.917 F1=0.957 dup=0.000; **device: 477 committed vs ~20 (ratio ≈23.9)** | lab generalized but real within-item motion ≫ fixture drift → adaptive threshold pinned at floor; do NOT retune to the run (§17) |
| `boundary-policy-v4` | `BoundaryEvidenceAccumulatorV4` / ContentSegmenterV4 (R3) | **DEVICE-FAILED** (lab-accepted; device over-detects 73/~20 ratio 3.65) | TUNE `corpus(seed:0)` only, candidate H | held-out P=1.000 R=0.889 F1=0.941 dup=0.000 (zero false segments); stress: 0 false on extreme/long high-motion, maxRun 0 | motion-normalized: robust baseline LEARNS motion + PRE/POST persistence + center/overlay gates + coherent-translation; fixtures rebuilt from DeviceMotionProfileV1 (real device). Recall misses only the frame-wise-ambiguous high-motion→high-motion cut (error budget §28). Device validation user-gated. |
| `boundary-policy-v5` | `BoundaryEvidenceAccumulatorV5` / ContentSegmenterV5 (R4) | **DEVICE-FAILED-ACCURACY** (lab-accepted; device 57/~20 ratio 2.85 — shot≠item granularity, NO spam) | TUNE `corpus(seed:0)` only | held-out P=1.000 R=0.882 F1=0.938 dup=0 (zero false segments); cadence 60/30/20fps commit dev ≤7%; stress pathological slices 0 false | REMOVED swipe relief → TemporalSwipeGateV1 (supporting); pan-vs-swipe (spike open + replacement/settle confirm); TIME-based dwell (ms); regionalReplacementRatio; DeviceMotionProfileV2 (real on-device scale); 8×8 projections. Misses only high-motion cut + sub-dwell rapid swipe (error budget §23). Device validation user-gated. |

## `boundary-policy-v3` frozen parameters
`wCenter 0.42 · wGlobal 0.18 · wHistogram 0.18 · wSides 0.10 · wTop 0.06 · wBottom 0.06 ·
sameThreshold 0.06 · regionJumpFraction 0.22 · minRegionAgreement 2 · transitionFloor 0.07 ·
strongJumpDistance 0.30 · strongRegionAgreement 3 · centerContentFloor 0.12 · confirmFrames 1 ·
refractoryFrames 2 · dynamicWindow 12 · dynamicJumpMultiplier 1.5 · minDynamicThreshold 0.07 ·
maxDynamicThreshold 0.40`
Source of truth: `ContentBoundaryPolicyV3.frozenV3` in
`packages/GuardianKit/Sources/GuardianCore/ContentBoundaryV3.swift`.

## `boundary-policy-v4` frozen parameters
`veryShortWindow 3 · shortWindow 8 · mediumWindow 40 · madK 1.4 · minMotionScale 0.05 · maxMotionScale 0.45 ·
baselineReseedCount 8 · warmupFrames 5 · openNormalizedJump 1.3 · confirmMotionRatio 1.6 · absoluteSafetyFloor 0.16 ·
postPersistenceFrames 2 · postCoherenceFraction 0.6 · maxTransitionFrames 10 · segRefAlpha 0.1 · overlayMaxRegions 2 ·
centerStableFraction 1.0 · reliabilityAlpha 0.1 · reliabilityFloor 0.15 · coherentPeak 0.7 · coherentMinOffset 1 ·
swipeConfirmRelief 0.4 · centerTransitionFloor 0.10 · minSegmentFrames 3`
Source of truth: `ContentBoundaryPolicyV4.frozenV4` in `ContentSegmenterV4.swift`.

## Change discipline (§17 / R3 §27)
If a fresh real-device run with the frozen policy fails, DO NOT retune to that single run. Archive it as
validation evidence, return FIX REQUIRED, and open a NEW revision with its own tune/held-out/stress cycle.
