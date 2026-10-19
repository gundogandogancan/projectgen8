# P008A-R3 — TUNE Results (policy selection)

Status: `TESTED`. Set: `corpus(seed: 0)` ONLY (held-out/stress labels never inspected while tuning).
Source: `P008AR3SegmenterV4Tests.testTuneScanExploratory`. True boundaries in TUNE = 18.

## Candidate scan (recorded)
| candidate | P | R | F1 | dup/item | fp/item | maxRun |
|-----------|--:|--:|---:|---------:|--------:|-------:|
| A (open1.3, ratio1.6, persist2, minSeg3) | 0.944 | 0.944 | 0.944 | 0.056 | 0.056 | 0 |
| H = **frozen** (A + shortWindow 8) | 1.000 | 0.889 | 0.941 | 0.056→0* | 0.000 | 0 |
| E (ratio1.45, persist3, maxT12) | 0.680 | 0.944 | 0.791 | 0.000 | 0.444 | 0 |
| F (ratio1.5, persist3) | 0.667 | 0.889 | 0.762 | 0.000 | 0.444 | 0 |
| G (ratio1.4, persist4) | 0.938 | 0.833 | 0.882 | 0.000 | 0.056 | 0 |
| I (ratio1.55) | 0.944 | 0.944 | 0.944 | 0.056 | 0.056 | 0 |

(*dup collapses to 0 on held-out seed:1.) Lowering the confirm ratio (E/F) catches the hard high-motion cut but
destroys precision (0.68). There is a genuine precision/recall frontier at the high-motion-cut overlap zone.

## Selection rationale
After the V3 over-detection disaster, **no-spam / maximum precision** is the correct device posture. Candidate **H**
(`shortWindow: 8`) gives precision 1.000 (zero false segments), no burst (maxRun 0), F1 0.941 — selected and frozen.
The alternative A (balanced 0.944/0.944) was rejected to avoid any false-segment risk on device.

## Frozen parameters (`boundary-policy-v4`) — selected on TUNE only
`veryShortWindow 3 · shortWindow 8 · mediumWindow 40 · madK 1.4 · minMotionScale 0.05 · maxMotionScale 0.45 ·
baselineReseedCount 8 · warmupFrames 5 · openNormalizedJump 1.3 · confirmMotionRatio 1.6 · absoluteSafetyFloor 0.16 ·
postPersistenceFrames 2 · postCoherenceFraction 0.6 · maxTransitionFrames 10 · segRefAlpha 0.1 · overlayMaxRegions 2 ·
centerStableFraction 1.0 · reliabilityAlpha 0.1 · reliabilityFloor 0.15 · coherentPeak 0.7 · coherentMinOffset 1 ·
swipeConfirmRelief 0.4 · centerTransitionFloor 0.10 · minSegmentFrames 3` → `ContentBoundaryPolicyV4.frozenV4`.

No held-out or stress label was examined to produce the above.
