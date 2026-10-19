# P007 — Full-Pipeline Admission Benchmark

Measures `candidate_discovered_at → first_trustworthy_admission_at` across the **real** stage set (not fusion-only).
Test: `P007FullPipelineBenchmarkTests`. **First-trustworthy = sum of NON-deep stages**; deep stages (temporal/speech)
are tracked but excluded (the fast path never waits for deep work). LAB host, 2026-10-18.

## Honesty label
Deterministic stages (identity/cache, text-merge, Shield, fusion, admission) use **measured** costs (the Shield+fusion
stage is measured live each run). Media stages (OCR/audio/visual-sample/speech) use **MODELED** representative costs
anchored to the real providers' observed order of magnitude from P004/P005 (OCR ~120µs, visual feature ~150µs). Modeled
stages are labelled so no one mistakes this for device-measured end-to-end latency.

## Results (first-trustworthy; all 15 cases, no cherry-picking)
Aggregate (non-cancelled): **p50 = 0.235 ms, p95 = 0.398 ms, max = 0.398 ms** (LAB, mostly modeled media stages).

| # | Case | Route | First-trustworthy | Deep (excluded) | Heads | Result | Lead |
|---|------|-------|-------------------|-----------------|-------|--------|------|
| 1 | exact cache hit | cache | 0.003 ms | — | 0 | VERIFIED_FAST | 800 ms |
| 2 | ContentDNA hit | cache+reuse | 0.004 ms | — | 0 | VERIFIED_FAST | 750 ms |
| 3 | fresh text-only | fast | 0.235 ms | — | 4 | VERIFIED_FAST | 500 ms |
| 4 | fresh image + OCR | fast | 0.356 ms | — | 5 | VERIFIED_FAST | 300 ms |
| 5 | short video preloaded | fast+deep | 0.387 ms | 0.400 ms | 6 | VERIFIED_FAST | 250 ms |
| 6 | short video no-cache | fast+deep | 0.398 ms | 0.450 ms | 6 | PROVISIONAL_FAST | 120 ms |
| 7 | audio-light | fast | 0.291 ms | — | 4 | VERIFIED_FAST | 400 ms |
| 8 | speech path | fast+deep | 0.235 ms | 0.900 ms | 4 | PROVISIONAL_FAST | 100 ms |
| 9 | Shield exact | fast | 0.227 ms | — | 1 | VERIFIED_FAST | 600 ms |
| 10 | Shield semantic | fast | 0.267 ms | — | 1 | VERIFIED_FAST | 450 ms |
| 11 | visual reference match | fast | 0.374 ms | — | 1 | VERIFIED_FAST | 200 ms |
| 12 | low-power plan | eco | 0.227 ms | — | 2 | VERIFIED_FAST | 300 ms |
| 13 | thermal-degraded plan | eco | 0.227 ms | — | 2 | VERIFIED_FAST | 300 ms |
| 14 | unsupported language | fast | 0.227 ms | — | 2 | UNKNOWN | 400 ms |
| 15 | cancelled before reveal | cancelled | 0.003 ms | — | 0 | CANCELLED | 0 ms |

## Key invariants (asserted)
- **Fast path never includes deep time:** case 8 first-trustworthy (0.235 ms) excludes 0.900 ms deep speech; case 5/6
  exclude deep temporal. The deep path is non-blocking.
- Cancelled candidate produces no admission (result CANCELLED), no surfaced state.
- Unsupported language → UNKNOWN result (no fabricated confidence).

## Limits
LAB host; media stages MODELED. **Device-measured** end-to-end latency is `NOT_MEASURED` (no signing team wired). These
are LAB objectives, not production or device claims. See PRE_EXPOSURE_SLO.yaml for TARGET vs LAB vs DEVICE separation.
