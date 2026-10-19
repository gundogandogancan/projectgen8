# P008A-R4 — Resource Results

Status: lab `TESTED` (algorithmic bound + projection benchmark) · device `PENDING` (fresh V5 session user-gated, §18).

## Algorithmic cost (bounded, O(1) per frame)
Per frame: 6× 8×8 region aHashes + 64-sample histogram + **8-bin** row/col projections (8×8 reads, down from V4's
16×16 — §17). Retained state: bounded `recent` ring (≤40), ≤40 robust-baseline buffer, ≤veryShort step window, POST
buffer, 6 reliability EMAs, counters. No raw frame retention, no unbounded queue, no per-frame heavy model.
`testResourceBoundedness` (5000 frames) confirms no runaway.

## §17 projection 8×8 vs 16×16 benchmark
`testProjection8vs16`: at **8×8**, a shifted projection is still detected as a translation (swipeDetected=1) and a
static frame stays stable (offset 0) — same discrimination as 16×16. 8×8 ≈ ¼ the projection sample cost. Accepted:
swipe/pan discrimination does not regress, cost drops, memory flat. The extension uses 8×8.

## V5 device telemetry — CAPTURED (fresh run `P008A_R4_AFTER_crossapp_device_v5.log`)
Resource gate GREEN; accuracy failed separately (shot↔item granularity, see DEVICE_VALIDATION §22).
| field | V4 ref | V5 observed | verdict |
|-------|-------:|------------:|:------:|
| cheap path p50 / p95 (ms) | 1.327 / 2.862 | **1.338 / 2.748** | bounded (<3 ms; 8×8 offset by replacement+gate compute) |
| downstream firstTrustworthyMs p50 / p95 | — | 0.071 / 0.119 | cheap |
| confirmation latency postMs (median) | — | 117 (0–317) | bounded |
| peak memory (MB) | 30.2 | **30.0** (27.8–30.0, no growth) | under ~40 ✓ |
| thermal | nominal | **nominal** (57/57) | PASS |
| commit cadence | — | 1 per ~48 frames (~1.6 s), candidate→commit 0.087 | no periodic/burst ✓ |
| committed / expected | 73 / ~20 | **57 / ~20 (ratio 2.85)** | ACCURACY FAIL (§22) |
| queue depth / dropped samples | — | not instrumented | NOT CAPTURED |
| extension survived | yes | **yes** (1 start / 1 finish) | PASS |

Note: cheap p95 stayed ≈ V4 (2.748 vs 2.862 ms) — the 8×8 projection saving was offset by the replacement-ratio +
swipe-gate compute. Still bounded and thermally nominal. Resource = PASS.

## §18 device instrumentation (to capture on the fresh run)
Logged: `BROADCAST_FINISHED frames … cheapP50ms … cheapP95ms … peakMemoryMB … thermal … segments … policy`;
per-commit `firstTrustworthyMs … memoryMB … thermal … lowPower …`; signposts `frame` + `segment` (segmentation
p50/p95 via Instruments). Frame-interval distribution available from the evidence-build `MOTION ts=` field.
NOT INSTRUMENTED (honest): queue depth, dropped/skipped samples. CPU/energy via xctrace only if actually captured.

## Latency
Time-based confirm waits `postPersistenceMs` (66 ms) for POST persistence and up to `maxTransitionMs` (400 ms) to
settle — bounded. First trustworthy Guardian state still lands sub-second on supported paths (deterministic pipeline
firstTrustworthyMs p50 ≈ 0.08 ms). Correctness not sacrificed for a sub-ms decision.
