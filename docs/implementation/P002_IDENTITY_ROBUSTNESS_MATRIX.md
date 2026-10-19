# P002 — Content Identity Robustness Matrix

**Doc status:** `CANONICAL` (empirical, fixture-level) · **Phase:** 2 · **Date:** 2026-10-18 · PROMPT 002A §4.
Robustness is claimed **only** for transformations actually observed to pass in the fixture tests. Algorithm versions: perceptual avg-hash `identity-v1`; Vision feature-print `apple-vision-featureprint-v1`. All results are **fixture-level / LAB**, not production guarantees.

| Transformation | Expected relation | Tested? | Observed tier/behavior | False match? | Evidence |
|---|---|---|---|---|---|
| Byte-identical file | SAME (I4 / near-zero distance) | ✅ | feature-print distance `< 1.0`; perceptual hamming `0` → I4 | no | `IdentityRobustnessTests.testByteIdenticalIsNearZeroDistance`, `IdentityV1Tests.testExactSameFileIsI4` |
| PNG re-encode (round-trip) | SAME/close | ✅ | feature-print distance `< 1.0` after decode→encode→decode | no | `testPngReencodeStaysClose` |
| Small byte perturbation (sim. re-encode) | close (I3+) | ✅ | perceptual hamming ≤6 → I3/I4 | no | `IdentityV1Tests.testReEncodedSimilarStaysStrong` |
| Different content (negative control) | DIFFERENT | ✅ | feature-print distance greater; perceptual tier ≤ I2 | **no false match** | `testDifferentContentIsFarNegativeControl`, `IdentityV1Tests.testDifferentContentIsNotFalseMatched` |
| Long-form alternate cut (version mismatch) | DIFFERENT version → refuse skip | ✅ | temporal skip-safety gate refuses auto-skip | n/a | `TemporalTests.testWrongVersionRefusesAutoSkip` |
| Resolution change | close | ⏳ not yet tested | — | — | requires scaled-image fixture (next increment) |
| Bitrate change | close | ⏳ N/A (fixtures are images) | — | — | needs real video pipeline |
| Minor crop | close | ⏳ not yet tested | — | — | crop fixture (next increment) |
| Minor scale | close | ⏳ not yet tested | — | — | scale fixture (next increment) |
| Frame-rate change | close | ⏳ N/A (images) | — | — | video pipeline |
| Brightness/contrast change | close | ⏳ not yet tested | — | — | tone-mapped fixture (next increment) |
| Small overlay/watermark | close | ⏳ not yet tested | — | — | overlay fixture (next increment) |
| Trim beginning/end (long-form) | same content, shifted timeline | ⏳ partial | version-tag mismatch currently treated as different | — | temporal alignment v2 (future) |

## Honest claim
Current empirically-supported robustness: **byte-identical, PNG re-encode, small perturbation → SAME; different content → not false-matched; alternate-cut → refused.** Resolution/crop/scale/brightness/overlay are **NOT yet claimed** (tests pending with scaled/transformed fixtures). The Vision feature-print path is the upgrade route for geometric/photometric robustness.
