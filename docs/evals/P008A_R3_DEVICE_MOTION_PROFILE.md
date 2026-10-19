# P008A-R3 — DeviceMotionProfileV1 (bootstrap-v0)

Status: `TESTED` (used to parameterize fixtures). Revision `device-motion-profile-bootstrap-v0`.
Source: `DeviceMotionProfileV1.bootstrapV0` in ContentSegmenterV4.swift. Runtime engineering profile — NOT user
content data; no reconstructive features persisted.

## Provenance (derived-only, real device)
Derived from the 477 commit-point `D` values in `docs/evals/artifacts/P008A_R2_AFTER_crossapp_device_v3.log`
(iPhone 14 Pro Max, iOS 26.6). These are region-weighted motion/discontinuity magnitudes at the moments the V3
detector fired — real device motion telemetry, no raw media. Honest caveat: the sample is biased toward D ≥ 0.07
(V3 only logged commits); a scripted per-frame calibration run (§24) would de-bias it for a v1 profile.

## Distributions (§14)
| distribution | value |
|--------------|-------|
| same-item motion energy — median | 0.123 |
| same-item motion — p75 / p95 / max | 0.169 / 0.257 / 0.392 |
| high-motion same-item — p95 | 0.257 |
| transition (cut-like) — min / median | 0.301 / 0.370 |
| transition — p95 / max | 0.472 / 0.573 |
| typical motion scale | 0.123 |
| transition : motion ratio | ≈ 3.0 |

## Interpretation
Real within-item motion routinely reaches 0.12–0.26 (tail 0.39); real cuts sit at 0.30–0.57. The separation exists
**only when measured relative to motion** (ratio ≈ 3), which is exactly what motion-normalized discontinuity
exploits. The overlap zone (high-motion p95 0.257 vs smallest transitions 0.30) is the documented hard case.

This profile replaces the unrepresentative R2 fixture assumption (per-frame drift 0.005–0.10) that caused the lab
to pass while the device failed — it directly parameterizes the R3 realistic fixture generator (§15).
