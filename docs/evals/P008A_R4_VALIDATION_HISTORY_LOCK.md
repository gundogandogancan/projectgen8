# P008A-R4 — Validation History Lock (immutable; never overwrite)

The full cross-app segmentation evidence chain. Each run is preserved as SHA-locked evidence; nothing is edited.
Device/OS/toolchain for every device run: iPhone 14 Pro Max (iPhone15,3), iOS 26.6, team `47XQMQZLF6`,
app `com.gen8.guardian.dev`, ext `com.gen8.guardian.dev.GuardianBroadcast`, Xcode 26.6 / Swift 6.3.
Ground truth = `MANUAL_APPROXIMATE_GROUND_TRUTH` (~20 distinct items; no frame-level labels).

| run | policy / engine | artifact | SHA-256 | outcome |
|-----|-----------------|----------|---------|---------|
| BEFORE (old aHash) | P007D ContentChangeDetector | `artifacts/P008A_BEFORE_crossapp_session.log` | `96a92d02f1917e9885d57f3518f6ac2cce9c940bafc897dfe864ee5f798224d6` | over-detection 406/168 for ~20 |
| R1 AFTER | `boundary-policy-v2` ContentBoundaryEngineV2 | `artifacts/P008A_R1_AFTER_crossapp_rerun.log` | `8510ee922441894c1f99d7ea87025960c2ca37f4180b1d9cc6023d4064f146ef` | under-detection 5/~20 (recall 0.25) |
| R2 / V3 | `boundary-policy-v3` BoundaryEvidenceAccumulatorV3 | `artifacts/P008A_R2_AFTER_crossapp_device_v3.log` | `e0f2328440f494ff5d0283e5f606ac8882e6702d6a5bce34488932f1f32f1148` | over-detection 477/~20 (ratio 23.9) |
| R3 / V4 | `boundary-policy-v4` BoundaryEvidenceAccumulatorV4 | `artifacts/P008A_R3_AFTER_crossapp_device_v4.log` | `f63c8de3f21fefb1e16b330df503a0a70d6a6ac364054fb436387f53e73f5ba1` | over-detection 73/~20 (ratio 3.65) |

## V4 run facts (entry evidence for R4)
frames 2369 · candidates 341 · committed 73 · ratio ≈ 3.65 · candidate→commit 0.21 · no localized burst ·
confirmation latency ≈ 3 frames median · cheap p50/p95 = 1.327 / 2.862 ms · peak mem 30.2 MB · thermal nominal ·
one uninterrupted automatic session across app switch · raw media persisted = 0 · all score=UNKNOWN · extension survived.
Resource/privacy/UNKNOWN/session-continuity all PASSED; only ACCURACY (count ratio) failed.

## V4 accuracy root cause (from the V4 SEGMENT telemetry)
- 45/73 commits `mode=SCROLL_SWIPE` → the coherent-translation cue over-fires on panning/moving video, and
  `swipeConfirmRelief (0.4)` lowered the confirm bar (a relief, not a gate).
- on-device robust motion `scale` at commits p50 **0.067** (p95 0.119) — below the bootstrap profile 0.123; the
  bootstrap came from biased V3 commit-point telemetry → `normJump = prePost/scale` inflated (p50 1.76, max 11.3).
- frame-count dwell/refractory is fragile under variable ReplayKit cadence.

STATUS entering R4: **FIX REQUIRED** (progress 406 → 5 → 477 → 73; the sensor gate is still open).
