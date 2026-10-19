# P008A-R4 — TemporalSwipeGateV1

Status: `TESTED`. Source: `TemporalSwipeGateV1` (ContentSegmenterV5.swift).

## Why (§2 — remove the "relief" failure mode)
V4's `swipeConfirmRelief` made a suspected swipe EASIER to commit (45/73 device over-commits were SCROLL_SWIPE).
R4 reverses this: **coherent translation is SUPPORTING evidence, never a threshold discount.** A swipe cue can
NEVER by itself lower the semantic transition evidence requirement.

## Inputs (§3)
vertical/horizontal translation correlation + offset, direction consistency over POST frames, translation
magnitude, PRE→POST discontinuity, POST persistence (ms), regional replacement ratio, elapsed time, motion baseline.

## Outputs
`NO_SWIPE` · `POSSIBLE_SWIPE` · `SWIPE_TRANSITION_CONFIRMED`.

## Rule
```
translated = (rowCorr ≥ coherentPeak ∧ |rowOffset| ≥ minOffset) ∨ (colCorr … )
if !(translated ∧ directionConsistency ≥ swipeDirectionConsistency)      → NO_SWIPE
else if replacementRatio ≥ minReplacement ∧ postPersistenceMs ≥ minMs    → SWIPE_TRANSITION_CONFIRMED
else                                                                      → POSSIBLE_SWIPE
```
`SWIPE_TRANSITION_CONFIRMED` can SUPPORT a NEW_SEGMENT (adds confidence + the `SWIPE_TRANSITION_CONFIRMED` reason)
but the accumulator still independently requires **persistent content replacement + motion-normalized discontinuity
+ settled POST + min dwell**. Translation alone (a pan) reaches only `POSSIBLE_SWIPE` and cannot commit.

## Evidence
`testTemporalSwipeGate`: translation + low replacement → POSSIBLE; translation + high replacement + persistence →
CONFIRMED; no translation → NO_SWIPE. `testSwipeCueCannotReduceEvidence`: 30 frames of pure projection translation
with no content replacement → **0 commits**. Related: [[P008A_R4_PAN_VS_SWIPE]].
