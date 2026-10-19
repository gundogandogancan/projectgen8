# P008A-R2 — Boundary Evidence Accumulator V3

Status: `TESTED` (lab held-out) · `IMPLEMENTED_UNVERIFIED` (fresh device run pending user gesture).
Source: `packages/GuardianKit/Sources/GuardianCore/ContentBoundaryV3.swift`
(`BoundaryEvidenceAccumulatorV3`, policy `boundary-policy-v3`).

## Why V3
R1 (`boundary-policy-v2`) stopped false-new spam (406 → 5 committed) but over-corrected into
UNDER-detection (recall ≈ 0.25). V3 restores recall WITHOUT returning to spam by replacing a single
global aHash + fixed thresholds with a **multi-region signature + temporal (adaptive) change model +
bounded evidence accumulator + strong-jump refractory bypass**. No app-specific logic, no private API,
no hardcoded pixel coordinates, no raw media.

## Pipeline (per frame, O(1) memory)
1. `MultiRegionSignature` sampled in place (global/center/top/bottom/left/right 8×8 aHash + 4-bin luma
   histogram). No decode, no copy, buffer not retained.
2. Per-region hamming distances + histogram L1 → `RegionDistances` (each 0..1).
3. Weighted distance `D` with content-heavy weights (see CONTENT_REGION_WEIGHTING).
4. Temporal baseline: bounded rolling window (`dynamicWindow=12`) of *within-item* `D` → mean + MAD;
   dynamic threshold `dynThr = clamp(mean + 1.5·MAD, 0.07, 0.40)`.
5. Classification:
   - `chromeOnly` = center stable (`< sameThreshold`) while a chrome region jumped → **OVERLAY**, never a boundary.
   - `contentMoved` = center moved `>= centerContentFloor (0.12)`.
   - `strong` = `D >= 0.30` AND `>=3` regions jumped → bypasses soft refractory.
   - `isJump` = `strong` OR (`contentMoved` AND `D >= dynThr` AND `D >= transitionFloor`).
6. Commit discipline: candidate must persist `confirmFrames` (strong → 1) AND satisfy soft refractory
   (`framesSinceCommit >= refractoryFrames (2)`, or be strong). On commit: `contentSequence += 1`,
   rolling baseline cleared (don't carry the prior item's motion stats).
7. Baseline is updated ONLY on non-jump, non-chrome frames → sustained high motion within one item
   raises the adaptive threshold instead of committing.

## Bounded memory
Only `prev` signature + a ≤12-element `recent` window + small counters are retained — constant memory
regardless of session length. Verified by `testResourceBoundedness`-style slices and the 253-test suite.

## Behavioral guarantees (tests)
- high-motion same item → ≤2 commits (`testHighMotionSameItemNoFalseBoundary`)
- bottom-only overlay → 0 commits (`testOverlayNotBoundary`)
- rapid distinct swipes → each commits (`testRapidSwipeDistinctCommits`, strong-jump bypass)
- center-only / persistent-chrome apps → center change still detected (center-centric logic)
- policy revision logged every session (`testPolicyRevisionV3` → `boundary-policy-v3`)

Related: [[gen8-project]] · CONTENT_REGION_WEIGHTING · P008A_R2_TUNE_RESULTS · P008A_R2_HELDOUT_RESULTS.
