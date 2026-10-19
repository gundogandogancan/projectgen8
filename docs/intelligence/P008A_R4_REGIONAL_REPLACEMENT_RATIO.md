# P008A-R4 — Regional Replacement Ratio

Status: `TESTED`. Source: `BoundaryEvidenceAccumulatorV5.replacementRatio` + confirm gate.

## Signal (§10)
`regionalReplacementRatio` = what proportion of temporally-reliable content regions appear to be REPLACED by a new
persistent state (vs merely evolving). A local pan/overlay differs from a full item replacement.

```
d = postRep.regions.distances(to: preRef.regions)          // per normalized region (center/global/top/bottom/left/right)
w = temporalRegionReliability.weights()                     // chrome down-weighted, content up-weighted (floored)
ratio = Σ w[r] · [ d[r] ≥ replacementRegionThreshold ] / Σ w[r]
```
Uses normalized regions + temporal region reliability + PRE vs POST signatures. No raw storage.

## Role in the decision
A NEW segment requires `ratio ≥ minReplacementRatio` (frozen 0.6). This is the key signal that rejects:
- panning (regions evolve gradually → in a bounded POST window the replaced fraction stays low),
- overlays (only chrome regions change → low reliability-weighted replacement),
- high-motion oscillation (content returns → net replacement low).
A cut/swipe replaces most content regions at once → ratio ≈ 1.0.

## Evidence
`testReplacementRatio`: a full-item cut shows replacement ≥ 0.6 at commit. Held-out `persistent-chrome` R=1.00
(center replaced, chrome constant), overlays FP=0, `panning-continuous` 0 commits. Frozen
`replacementRegionThreshold = 0.20`, `minReplacementRatio = 0.60`.
