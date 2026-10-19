# P008A-R4 — Time-Based Segmentation

Status: `TESTED`. Source: `ContentBoundaryPolicyV5` (ms fields) + `BoundaryEvidenceAccumulatorV5.process(_:timestampMs:)`.

## Why (§8)
ReplayKit broadcast cadence varies (dropped samples, variable FPS). V4's frame-count dwell/refractory changed
behavior when capture FPS changed (root cause #5 of the V4 failure). R4 makes the critical logic TIME-based.

## Time-based parameters (replace frame counts)
| was (frame-count) | now (time, ms) | frozen v5 |
|---|---|---|
| refractoryFrames | `minSegmentDwellMs` | 220 |
| postPersistenceFrames | `postPersistenceMs` | 66 |
| maxTransitionFrames | `maxTransitionMs` | 400 |

The accumulator takes the real presentation timestamp (`CMSampleBufferGetPresentationTimeStamp` → ms in the
extension; synthetic per-frame timestamps in fixtures). Dwell, POST persistence, and transition-timeout are all
measured in elapsed ms, so the SAME semantic stream yields the same commits regardless of FPS. Frame-count helpers
(very-short/short/medium windows for the motion baseline) remain internal and are robust to cadence because they
describe motion statistics, not timing decisions.

## Evidence
`testTimeBasedDwellRefractory`: two cuts ~100 ms apart collapse to ≤1 commit under a 450 ms dwell.
`testCadenceInvariantSegmentation` (§9/§10): 60/30/20 fps + jitter + dropped samples → commit counts 14/15/15/15/15
(≤7% deviation, within the predeclared ≤10% gate). See P008A_R4_CADENCE_STRESS_RESULTS.
