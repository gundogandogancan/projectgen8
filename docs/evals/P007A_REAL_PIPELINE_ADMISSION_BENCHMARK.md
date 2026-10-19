# P007A — Real Pipeline Admission Benchmark

**Evidence correction (§1/§2):** the P007 "full-pipeline" benchmark mixed measured + MODELED media stages, so it is
relabelled **MODELED_PROJECTION** (`P007FullPipelineBenchmarkTests`, output tag `P007_MODELED_*`) and proves only the
*invariant* that first-trustworthy excludes deep stages — not real latency. This document reports the **actually
executed** pipeline.

Test: `GuardianMediaTests/P007ARealPipelineBenchmarkTests.testRealMeasuredPipeline`. Every stage in a route's latency is
really executed (real Vision OCR, real AVAssetWriter MP4 + AVAssetImageGenerator frame extraction, real SoundAnalysis,
real on-device Speech adapter, real Shield index/eval, real `ScoreAdmissionFusionV1`). **No modeled durations, no fake
sleep.** Host: macOS dev host (LAB). No device metrics claimed.

## Measured routes (one run; `firstTrustworthy` = sum of the route's actually-executed, non-deep stages)

| route_id | cache | actual stages invoked | unavailable | first-trustworthy | result | evidence_class |
|----------|-------|------------------------|-------------|-------------------|--------|----------------|
| A-exact-cache-hit | HIT | identity, cache_lookup, admission | — | **0.134 ms** | approveWithCaution | LAB_MEASURED_REAL_PIPELINE |
| C-structured-text | MISS | shield, admission | — | **0.061 ms** | NO_SHIELD_ACTION | LAB_MEASURED_REAL_PIPELINE |
| D-image-ocr | MISS | **ocr**, shield, admission | — | **217.920 ms** | ocr=READ | LAB_MEASURED_REAL_PIPELINE |
| F-video-fresh-no-cache | MISS | media_metadata, **frame_extraction**, **ocr**, admission | — | **85.193 ms** | frames=2 | LAB_MEASURED_REAL_PIPELINE |
| G-general-audio | MISS | **sound_analysis**, admission | — | **38.113 ms** | audio=unknown | LAB_MEASURED_REAL_PIPELINE |
| H-speech | MISS | **speech_adapter**, admission | **speech** | **66.927 ms** | BLOCKED_NOT_AUTHORIZED | LAB_MEASURED_PARTIAL_PIPELINE |
| I-shield-exact | MISS | shield, admission | — | **0.077 ms** | EXECUTE | LAB_MEASURED_REAL_PIPELINE |
| J-visual-reference | MISS | visual_signature_match, admission | — | **0.715 ms** | MATCH_HIGH | LAB_MEASURED_REAL_PIPELINE |
| K-cancellation | N/A | task_start, cancel | — | 0 | CANCELLED_NO_STALE | LAB_MEASURED_REAL_PIPELINE |

Warmup: none (single cold run per route; runs > 1 would be needed for stable p95/p99 — not claimed here).

## What the real numbers reveal (the point of this closeout)
- **Real Vision OCR is ~218 ms** — ~1800× the P007 modeled "~120 µs". The modeled figure was misleading; the measured
  figure is the truth. Real video frame-extraction+OCR ~85 ms; SoundAnalysis ~38 ms.
- **Deterministic routes are genuinely sub-millisecond** (cache 0.134 ms, structured-text 0.061 ms, shield 0.077 ms,
  visual-reference 0.715 ms).
- **Speech really hits the adapter** and returns `BLOCKED_NOT_AUTHORIZED` (UNAVAILABLE) — no modeled speech duration;
  the route is `LAB_MEASURED_PARTIAL_PIPELINE` and the admission still resolves honestly.
- **Cache route ran NO media work** (asserted: no `ocr`/`frame_extraction` stage). **Video/image routes DID** invoke
  real provider work (asserted). **Cancellation**: stale result never became current (asserted).

## Honest aggregation rule (§5)
Per-route only. We do **not** publish a single "Gen8 latency." A meaningful cross-route p95 would mix a 0.06 ms
text route with a 218 ms OCR route — meaningless. The `P007A_SUMMARY` line aggregates only same-class real routes and is
explicitly labelled "per-route; not a universal latency."

## Sub-second claim (§6)
`LAB SUB-SECOND` is stated **only** per-route where measured first-trustworthy < 1000 ms: all nine routes here are
< 1000 ms on this host **for a single frame / short fixture**. Not generalized to all modalities, devices, languages, or
production. Real OCR-heavy multi-frame content on a real device is NOT_MEASURED.
