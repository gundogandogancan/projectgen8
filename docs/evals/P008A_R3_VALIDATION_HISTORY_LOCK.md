# P008A-R3 — Validation History Lock (immutable; never overwrite)

All prior cross-app boundary/segmentation runs preserved as evidence. The V3 failure is valuable — it
exposed that real video motion is not a boundary. Nothing here is edited by later work.

Device/OS/toolchain for every device run below: iPhone 14 Pro Max (iPhone15,3), iOS 26.6, team `47XQMQZLF6`,
app `com.gen8.guardian.dev`, ext `com.gen8.guardian.dev.GuardianBroadcast`. Xcode 26.6 / Swift 6.3.
Ground truth = `MANUAL_APPROXIMATE_GROUND_TRUTH` (~20 distinct items; no frame-level labels).

| run | policy / engine | artifact | SHA-256 | outcome |
|-----|-----------------|----------|---------|---------|
| BEFORE (old aHash) | P007D `ContentChangeDetector` | `docs/evals/artifacts/P008A_BEFORE_crossapp_session.log` | `96a92d02f1917e9885d57f3518f6ac2cce9c940bafc897dfe864ee5f798224d6` | over-detection: 406 candidates / 168 analyzed for ~20 items |
| R1 AFTER | `boundary-policy-v2` `ContentBoundaryEngineV2` | `docs/evals/artifacts/P008A_R1_AFTER_crossapp_rerun.log` | `8510ee922441894c1f99d7ea87025960c2ca37f4180b1d9cc6023d4064f146ef` | UNDER-detection: 5 committed vs ~20 (recall ≈ 0.25) |
| R2 / V3 | `boundary-policy-v3` `BoundaryEvidenceAccumulatorV3` | `docs/evals/artifacts/P008A_R2_AFTER_crossapp_device_v3.log` | `e0f2328440f494ff5d0283e5f606ac8882e6702d6a5bce34488932f1f32f1148` | OVER-detection: 477 committed vs ~20 (ratio ≈ 23.9) |

## R2 / V3 failure facts (entry evidence for R3)
frames 3919 · candidates 657 · committed 477 · committed/expected ≈ 23.9 · candidate→commit ≈ 73% ·
343/477 commits `strong=false & agree≤1` · 260/477 `agree=0` · dynThr pinned at 0.070 floor for 391/477 (82%).
Real continuous motion drove center ≥ 0.12 almost every frame; jump frames were excluded from baseline
updates and the baseline was cleared on commit → the adaptive baseline never learned real motion → the
detector emitted a transition stream.

Synthetic held-out had passed P=1.000 R=0.917 F1=0.957 dup=0 → **the fixture distribution was not
representative of real device motion.** (That lab suite remains in `BoundaryFixtureHarnessV3.swift`.)

## Real device-derived motion separation (extracted from the V3 log, derived-only — no raw media)
From the 477 commit-point `D` values (region-weighted motion/discontinuity at the moment the detector fired):
- within-item motion (`strong=false`, n=411): median **0.123**, p75 0.169, p95 0.257, max 0.392
- cut-like (`strong=true`, n=66): median **0.370**, min 0.301, p95 0.472, max 0.573
- transition/motion ratio ≈ **3.0** → a motion-NORMALIZED discontinuity rule separates them; the absolute
  floor 0.07 did not. This grounds `DeviceMotionProfileV1` (bootstrap-v0) and the R3 fixture rebuild.

Non-accuracy gates (all runs' latest): automatic session ✓, one broadcast survived app switch ✓, privacy ✓
(raw media persisted = 0), UNKNOWN gating ✓, V3 peak mem 29.7 MB, thermal nominal, cheap p95 ≈ 1.344 ms,
extension survived ✓.

STATUS entering R3: **FIX REQUIRED.**
