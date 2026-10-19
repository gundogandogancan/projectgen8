# P008A-R3 — ContentSegmenterV4

Status: lab `TESTED` (held-out + stress, frozen) · device `IMPLEMENTED_UNVERIFIED` (fresh validation user-gated).
Source: `packages/GuardianKit/Sources/GuardianCore/ContentSegmenterV4.swift`, revision `boundary-policy-v4`.

## Reformulation (§2)
V3 asked "did THIS frame change enough?" (absolute floor) and excluded motion frames from its baseline, so on
real moving content it emitted a transition stream (477 commits / ~20 items). V4 asks **"did the stream enter a
NEW PERSISTENT content segment?"** A Reel/video is a temporal SEGMENT; motion inside it is not a boundary.

Canonical states (§2): `SAME_SEGMENT`, `INTRA_SEGMENT_MOTION`, `OVERLAY_CHANGE`, `TRANSITION_IN_PROGRESS`,
`NEW_SEGMENT_CONFIRMED`, `AMBIGUOUS`.

## Signals (§3 — motion energy vs discontinuity, kept independent)
- **MotionEnergy** = reliability-weighted distance to the previous frame (how much is changing now).
- **SegmentDiscontinuity** = PRE-window vs POST-window distance, measured RELATIVE to motion. High motion ≠ discontinuity.

## Pipeline (bounded O(1), in `BoundaryEvidenceAccumulatorV4`)
1. `SegmentFrameV4` = `MultiRegionSignature` (6 region aHashes + 4-bin smooth luma histogram) + 16-bin row/col
   luma projections (for the coherent-translation cue). Computed in place; raw buffer never retained.
2. `RobustMotionBaseline` (§4): bounded rolling window of MotionEnergy, robust **median + MAD** scale. Updated on
   EVERY eligible frame including sustained motion (the V3 fix); never cleared on a tentative candidate; reseeded
   (not cleared) on commit so the scale can't collapse to the floor.
3. Multi-timescale (§7): very-short window → ABRUPT change (continuity filter: pans/high-motion have temporal
   continuity → small over a short window; a cut spikes); short window → POST confirmation; medium window → baseline.
4. OPEN a candidate when the short-window abrupt change, NORMALIZED by the robust motion scale, exceeds a relative
   multiple (`openNormalizedJump`) and a tiny absolute safety floor — never an absolute constant as the primary rule (§6).
5. PRE/POST persistence (§5): PRE = pre-change window; POST accumulates. Confirm only if the median PRE→POST distance
   is materially larger than BOTH within-PRE and within-POST motion (`confirmMotionRatio`), the content (center)
   actually moved (`centerTransitionFloor`, kills overlays), it persisted `postPersistenceFrames`, and refractory OK.
   If POST never stabilizes within `maxTransitionFrames` → it was intra-segment motion; fold back, no commit.
6. Transition modes (§8): CUT / SCROLL_SWIPE (coherent translation) / CROSSFADE_AUTOPLAY / APP_SURFACE / OVERLAY.
7. Reason codes (§12) + confidence on every event.

## Why it fixes V3
The baseline LEARNS real motion → the normalized discontinuity of ongoing motion stays ≈1 (no commit); a true cut
settles into a persistent new state far from PRE relative to motion → commits. Held-out: **zero false segments**,
no spam; extreme/long high-motion stress → **0 false commits**. See HELDOUT/STRESS results.

Related: [[gen8-project]] · MOTION_NORMALIZED_DISCONTINUITY · TEMPORAL_REGION_RELIABILITY · DEVICE_MOTION_PROFILE.
