# P009A Phase C — Dwell Fix Results
Measured defect (Phase B): `prevDwellMs=0` on 100% of device rows — stored shot descriptors never received end-time
updates (ShotSegmenterV5 mutated only its value-type copy), so long-dwell evidence + the weak-theme dwell gate were
dead in ALL prior device runs. Fix (ProfileAwareGroupingV2.process): prior-shot dwell derived from MONOTONIC
presentation timestamps — `prevDwell = max(0, newShot.startMs − prevShot.startMs)` (the previous shot ends exactly
when the next begins). No threshold retuned; lab fixtures are contiguous so lab semantics unchanged. Tests
(`PHASEC_CloseoutTests`): start-difference correctness, 60/30/20-fps cadence scaling, rapid cuts (no negatives),
session-boundary behavior, and long-dwell evidence now firing (`testDwellSessionBoundaryReset`). First-shot dwell:
no decision exists before the second shot, so no dwell claim is ever made for it.
