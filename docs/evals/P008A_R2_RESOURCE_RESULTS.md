# P008A-R2 — Resource Regression Results

Status: lab `TESTED` (algorithmic cost) · device `PENDING` (fresh V3 session user-gated).

## Algorithmic cost of V3 vs V2 (lab, deterministic)
V3 replaces V2's single 64-sample global aHash with a fixed **6×64 = 384 luma samples** + a 64-sample
4-bin histogram pass, plus per-region popcounts and a ≤12-element rolling mean/MAD. All O(1) per frame,
no allocation growth, no decode, no copy, buffer not retained. Memory is bounded to `prev` signature +
`recent[≤12]` + counters regardless of session length (proven by the 253-test suite running unbounded
fixture lengths without growth).

Cost delta is a small constant multiple of the per-pixel sampling only; the expensive path
(downstream analysis) still runs ONLY on a committed NEW_CONTENT, exactly as in R1.

## R1 device baseline (reference, `boundary-policy-v2`, immutably locked)
From `docs/evals/P008A_R2_R1_EVIDENCE_LOCK.md`: cheap path p50 0.125 ms / p95 0.311 ms, peak memory
29.2 MB (budget ~50 MB), thermal nominal, raw media persisted 0. These are the regression reference
points for the V3 fresh run.

## V3 device telemetry — CAPTURED (fresh run, `P008A_R2_AFTER_crossapp_device_v3.log`)
The resource gate stayed GREEN even though boundary ACCURACY failed (§14 is a resource check; accuracy is §16).
| field | R1 ref | V3 observed | verdict |
|-------|-------:|------------:|:------:|
| cheap path p50 / p95 (ms) | 0.125 / 0.311 | **0.618 / 1.344** | within budget (<2 ms) |
| boundary eval p50 / p95 (ms) | — | not separately aggregated in log | NOT CAPTURED |
| downstream firstTrustworthyMs p50 / p95 | — | 0.083 / 0.156 (max 0.694) | cheap |
| peak memory (MB) | 29.2 | **29.7** (range 27.9–29.7) | under ~40/50 budget |
| thermal state | nominal | **nominal** (477/477) | PASS |
| low-power mode | — | false (477/477) | — |
| candidate count / committed count | 74 / 5 | **657 / 477** | ACCURACY FAIL (see §16) |
| dropped/skipped frame candidates | — | not instrumented | NOT CAPTURED |
| queue depth | — | not instrumented | NOT CAPTURED |
| extension survived full session | yes | **yes** (1 start / 1 finish, no termination) | PASS |

Notes:
- Cheap-path cost rose ~5× vs R1 (0.125→0.618 ms p50) — expected, since V3 samples 6×64 regions + a
  64-sample histogram vs V2's single 64-sample aHash. Still sub-2 ms and thermally nominal; not a resource blocker.
- **Resource gate = PASS**, but this does not rescue the run: the 477-commit over-detection (§16) means the
  cheap engine ran fine while producing wrong boundaries, and invoked 477 downstream analyses vs ~5 expected —
  wasteful, though each analysis is sub-ms and memory stayed flat (no leak/growth: 27.9–29.7 MB).

## xctrace note
Deep CPU/energy xctrace templates (Allocations, CPU Profiler, Power, System Trace, Leaks) are available and
verified real on this host, but were NOT run for this session (only the extension's own derived telemetry was
pulled). `boundary eval p50/p95`, `queue depth`, and `dropped/skipped candidates` are NOT instrumented in the
extension and are honestly reported as NOT CAPTURED — not fabricated.
