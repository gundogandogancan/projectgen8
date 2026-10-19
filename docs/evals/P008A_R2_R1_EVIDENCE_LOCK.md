# P008A-R2 — R1 Evidence Lock (immutable, never overwritten)
| Artifact | Path | SHA-256 |
|----------|------|---------|
| BEFORE baseline (old aHash) | docs/evals/artifacts/P008A_BEFORE_crossapp_session.log | 96a92d02f1917e9885d57f3518f6ac2cce9c940bafc897dfe864ee5f798224d6 |
| R1 AFTER (BoundaryEngineV2) | docs/evals/artifacts/P008A_R1_AFTER_crossapp_rerun.log | 8510ee922441894c1f99d7ea87025960c2ca37f4180b1d9cc6023d4064f146ef |

- Device/build: iPhone 14 Pro Max (iPhone15,3), iOS 26.6, team 47XQMQZLF6, app com.gen8.guardian.dev.
- R1 policy revision used: `boundary-policy-v2` (ContentBoundaryEngineV2, EXTENSION_FAST, OCR off).
- BEFORE: frames 3558, candidates 406, analyzed 168 (~20 real items) → severe over-detection.
- R1 AFTER: frames 3593, candidates 74, committed 5 (~20 real) → recall ≈ 0.25 (under-detection), precision ≈ 1.0,
  peak mem 29.2 MB, thermal nominal, cheap p50/p95 0.125/0.311 ms, score UNKNOWN 5/5, raw media 0, 1 session survived app switch.
- Manual ground truth: `MANUAL_APPROXIMATE_GROUND_TRUTH` (~20 items; no frame-level labels).
R2 must NOT tune directly to this run. These artifacts are frozen validation evidence.
