# P008A-R2 — HELD-OUT Results (run once, frozen policy)

Status: `TESTED`. Set: `corpus(seed: 1)` — unseen derivatives, evaluated EXACTLY ONCE with
`ContentBoundaryPolicyV3.frozenV3`. Source: `testHeldOutMeetsPredeclaredTargets`. Match tolerance ±3 frames.

## Predeclared engineering acceptance targets (locked BEFORE eval, §12)
| metric | target | observed | verdict |
|--------|-------:|---------:|:-------:|
| precision | ≥ 0.90 | **1.000** | PASS |
| recall | ≥ 0.85 | **0.917** | PASS |
| F1 | ≥ 0.87 | **0.957** | PASS |
| duplicate NEW / true item | ≤ 0.10 | **0.000** | PASS |

Overall: TP, committed=33, true=36 → FN=3, FP=0, duplicates=0.

## Per-slice metrics (weak slices NOT hidden in aggregate)
| slice | P | R | tp | fp | fn | dup |
|-------|--:|--:|---:|---:|---:|----:|
| static-cards | 1.00 | 1.00 | 3 | 0 | 0 | 0 |
| talking-head | 1.00 | 1.00 | 2 | 0 | 0 | 0 |
| high-motion-sport | 1.00 | 0.50 | 1 | 0 | 1 | 0 |
| panning-landscape | 1.00 | 1.00 | 2 | 0 | 0 | 0 |
| subtitles | 1.00 | 1.00 | 1 | 0 | 0 | 0 |
| comments-overlay | 1.00 | 1.00 | 1 | 0 | 0 | 0 |
| menu-overlay | 1.00 | 1.00 | 1 | 0 | 0 | 0 |
| autoplay-transition | 1.00 | 1.00 | 2 | 0 | 0 | 0 |
| ad-transition | 1.00 | 1.00 | 2 | 0 | 0 | 0 |
| rapid-3-swipe | 1.00 | 1.00 | 3 | 0 | 0 | 0 |
| slow-swipe | 1.00 | 1.00 | 2 | 0 | 0 | 0 |
| repeated-same | 1.00 | 1.00 | 1 | 0 | 0 | 0 |
| same-theme | 1.00 | 0.67 | 2 | 0 | 1 | 0 |
| dark-to-dark | 1.00 | 1.00 | 2 | 0 | 0 | 0 |
| bright-to-bright | 1.00 | 0.50 | 1 | 0 | 1 | 0 |
| persistent-chrome | 1.00 | 1.00 | 3 | 0 | 0 | 0 |
| center-only | 1.00 | 1.00 | 2 | 0 | 0 | 0 |
| partial-screen | 1.00 | 1.00 | 2 | 0 | 0 | 0 |

## Honest weak-slice analysis (the 3 FNs)
The only misses are the deliberately **subtle** transitions where the next item is visually close to the
previous one: `high-motion-sport` (a cut hidden inside large ongoing motion → the adaptive baseline has
risen, so the cut doesn't exceed it), `bright-to-bright` and `same-theme` (small center delta between
adjacent items of the same look). These fail SAFE (missed, not spam) and there are **zero false
positives anywhere** — the R1 over-detection failure mode has not returned. Overlays, persistent chrome,
rapid swipes, and clear transitions are all at R=1.00.

## Detection latency / duplicate rate
Commit occurs at the candidate frame (strong) or after 1 confirm frame; all matched within the ±3
tolerance. Duplicate commit rate = 0.000 across all slices. Boundary eval cost is O(1) per frame
(fixed 6×64 samples + ≤12-window stats) — see P008A_R2_RESOURCE_RESULTS.
