# P008A-R4 — DeviceMotionProfileV2

Status: `TESTED` (used to parameterize fixtures + seed ranges). Revision `device-motion-profile-v2-partial`.
Source: `DeviceMotionProfileV2.v2` in ContentSegmenterV5.swift. Runtime engineering profile — not user content;
no reconstructive features persisted.

## Provenance (§7, derived-only)
Corrects the key V4 bias: the on-device robust motion **scale** was lower than the V3-bootstrap profile. v2 uses the
REAL on-device scale observed in the V4 run (`P008A_R3_AFTER_crossapp_device_v4.log` commit-point scale p50 **0.067**,
p95 0.119, max 0.133) plus the V3 distance-distribution shape. Honest caveat: still partly commit-biased →
`-partial`. The scripted UNBIASED per-frame calibration (§6, now enabled by the evidence build) refines it to v2.1.
**Not computed only from commit frames** once the scripted run exists (§7).

## Distributions (§7)
| field | value |
|-------|-------|
| low-motion median | 0.05 |
| high-motion p95 | 0.26 |
| panning median | 0.10 |
| true swipe translation median | 0.30 |
| cut-like transition median | 0.37 |
| overlay/local-change median | 0.20 |
| on-device motion scale median / p95 | **0.067 / 0.119** |
| frame interval median (ms) | 33 |
| POST persistence median (ms) | 120 |

## Use (§11 — motion-normalized discontinuity V2)
Robust percentile-derived SEED RANGES only (not one run's values hardcoded): `minMotionScale` lowered to 0.03
(reflecting the low on-device scale), `confirmMotionRatio`/`replacementRegionThreshold`/`openStepRatio` seeded from
these ranges, then **tuned only on generated TUNE data**. The fixture generator (`FixtureGeneratorV5`) is
parameterized from this profile so realized fixture motion matches the device.
