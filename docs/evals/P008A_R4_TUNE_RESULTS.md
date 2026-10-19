# P008A-R4 — TUNE Results

Status: `TESTED`. Set: `corpus(seed:0)` ONLY. Source: `testTuneScanExploratory`. True boundaries = 17.

## Selection path (recorded)
The frozen policy was converged on TUNE through a sequence of principled fixes (each verified on TUNE only):
1. shorter time dwell (450→140→220 ms) so short-segment boundaries aren't suppressed;
2. widened match tolerance to 7 (time-based confirm adds a few frames latency);
3. **spike-based OPEN** (`maxStep ÷ median(recentMotion) ≥ openStepRatio`) instead of step÷scale — separates a cut's
   isolated spike from a pan's uniform motion;
4. smoother pan fixtures (realistic low-noise camera motion);
5. dwell 220 ms to collapse single-cut double-commits (duplicate aftermath).

Final frozen TUNE result: **P=1.000 · R=0.765 · F1=0.867 · dup/item=0.000 · fp/item=0.000 · maxRun=0**
(committed 13, true 17 → 4 FN: high-motion-sport, one of the rapid-swipe pair, and the sub-dwell cases). Zero spam,
zero duplicates. Looser candidates raised recall slightly but re-introduced the pan false-commit / duplicates — the
no-spam posture was chosen deliberately (four prior over-detection failures).

## Frozen parameters (`boundary-policy-v5`, selected on TUNE only)
`veryShortWindow 3 · mediumWindow 40 · madK 1.4 · minMotionScale 0.03 · maxMotionScale 0.45 · baselineReseed 8 ·
warmupFrames 5 · openStepRatio 1.8 · absoluteSafetyFloor 0.14 · confirmMotionRatio 1.6 · minReplacementRatio 0.60 ·
replacementRegionThreshold 0.20 · postCoherenceFraction 0.55 · centerTransitionFloor 0.12 · postPersistenceMs 66 ·
minSegmentDwellMs 220 · maxTransitionMs 400 · overlayMaxRegions 2 · reliabilityAlpha 0.1 · reliabilityFloor 0.15 ·
coherentPeak 0.7 · coherentMinOffset 1 · swipeDirectionConsistency 0.6` → `ContentBoundaryPolicyV5.frozenV5`.
Ranges seeded from DeviceMotionProfileV2; no held-out/stress/cadence label inspected during tuning.
