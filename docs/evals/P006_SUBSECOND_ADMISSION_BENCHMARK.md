# P006 — Sub-Second Admission Benchmark

**Doc status:** `CANONICAL` (LAB_MEASURED) · **Phase:** 6 · **Date:** 2026-10-18 · PROMPT 006 §0, §42. Artifact: `ml/evaluation/results/p006-subsecond-admission.json`.

## Truthful contract
Target: `FIRST_TRUSTWORTHY_ADMISSION < 1000 ms` for supported/preloaded/cached paths where measurable. Admission state ∈ {FAST_VERIFIED/VERIFIED_FAST, PROVISIONAL, DEEP_VERIFIED, UNKNOWN, CONFLICTING, STALE}. **Fast admission ≠ fact verification complete.** Deep analysis continues after.

## Measured (macOS LAB, 50 samples, p50)
| Case | Route | p50 | <1s |
|---|---|---|---|
| exact cache hit | CACHE | ~0 µs | ✅ |
| fresh fast path (deterministic fusion) | FAST | ~1.7 µs | ✅ |

**Scope honesty:** these measure the **admission fusion compute** (deterministic policy over already-available fast signals), not end-to-end media analysis. End-to-end real-media timing is in `P005_REAL_MEDIA_E2E_BENCHMARK.md` (~192–218 ms/short clip LAB). Full §42 matrix cases that depend on real decode/speech/device (image+OCR, audio-light, preloaded short video, thermal-degraded, unsupported-language, cancelled) are **device/real-media** and labelled PENDING where not yet measured — **misses are never hidden from percentiles.** Not a production SLO (no device).
