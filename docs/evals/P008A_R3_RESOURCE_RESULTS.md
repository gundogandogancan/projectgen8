# P008A-R3 — Resource Results

Status: lab `TESTED` (algorithmic bound) · device `PENDING` (fresh V4 session user-gated, §21).

## Algorithmic cost (bounded, O(1) per frame)
Per frame V4 computes: 6× 8×8 region aHashes + a 64-sample smooth histogram + 16 row + 16 col projection samples
(16×16 reads) — a fixed constant, no allocation growth. State retained = a bounded `recent` ring (≤ mediumWindow 40),
a ≤40 robust-baseline buffer, a ≤ shortWindow 8 POST buffer, 6 reliability EMAs, counters. **No raw frame retention,
no unbounded queue, no per-frame heavy model.** Verified by `testResourceBoundedness` (5000 frames, bounded commits,
no growth) within the 267-test suite.

## R2/V3 device reference (prior)
V3 cheap path p50/p95 = 0.618 / 1.344 ms, peak 29.7 MB, thermal nominal. V4 adds the projection pass (32 extra
samples) + ring-buffer medians over ≤40 elements — a small constant on top; expected to remain sub-2 ms and well
under the ~40–50 MB budget. Not fabricated — to be measured on the fresh run.

## V4 device telemetry — CAPTURED (fresh run `P008A_R3_AFTER_crossapp_device_v4.log`)
Resource gate GREEN (bounded, no leak, nominal thermal); accuracy FAILED separately (see DEVICE_VALIDATION §26).
| field | V3 ref | V4 observed | verdict |
|-------|-------:|------------:|:------:|
| cheap path p50 / p95 (ms) | 0.618 / 1.344 | **1.327 / 2.862** | bounded (projection pass ~2× V3; p95 <3 ms) |
| segmentation p50 / p95 (ms) | — | not separately aggregated (signpost `segment` for Instruments) | NOT CAPTURED |
| downstream firstTrustworthyMs p50 / p95 | — | 0.080 / 0.163 (max 0.371) | cheap |
| peak memory (MB) | 29.7 | **30.2** (range 28.3–30.2, no growth) | under ~40 budget ✓ |
| thermal | nominal | **nominal** (73/73) | PASS |
| low-power | — | false (73/73) | — |
| confirmation latency (candidate→confirm) | — | POST median ≈ 3 frames (2–8) | bounded |
| committed / expected | 5 / ~20 (V3=477) | **73 / ~20 (ratio 3.65)** | ACCURACY FAIL (§26) |
| queue depth / dropped samples | — | not instrumented | NOT CAPTURED |
| extension survived | yes | **yes** (1 start / 1 finish, no OS kill) | PASS |

Note: the cheap-path p95 rose to 2.862 ms (from V3's 1.344 ms) — the 16×16 row/col projection pass roughly doubled
per-frame cost. Still bounded and thermally nominal, but a candidate for trimming (e.g. 8×8 projections) in the next
revision given the swipe cue is being de-emphasized anyway.

## Latency budget (§20)
V4 may wait briefly for POST persistence (`postPersistenceFrames 2`, `maxTransitionFrames 10`) before confirming —
bounded. Candidate→confirm ≈ 2 frames; downstream analysis starts on NEW_SEGMENT_CONFIRMED only. First trustworthy
Guardian state still lands sub-second on supported paths (V3 firstTrustworthyMs p50 0.083 ms for the deterministic
pipeline). Correctness is not sacrificed for a sub-ms boundary decision (§20).
