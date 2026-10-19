# P008A-R3 — Fresh Device Validation Results

Status: `RUN COMPLETE` → **FIX REQUIRED** (`boundary-policy-v4` over-detects on real content: 73 vs ~20, ratio ≈ 3.65).
Accuracy label: `APPROXIMATE` (manual ground truth; not reported as exact P/R).
Evidence (immutable): `docs/evals/artifacts/P008A_R3_AFTER_crossapp_device_v4.log`
SHA-256 `f63c8de3f21fefb1e16b330df503a0a70d6a6ac364054fb436387f53e73f5ba1`
(append-only log; V4 is the last block — `policy=boundary-policy-v4`, `BROADCAST_FINISHED … segments=73`).

## §26/§27 — Device validation results (approximate ground truth)
| field | value | verdict |
|-------|-------|:------:|
| committed NEW_SEGMENT count | **73** | — |
| expected distinct items (approx) | ~20 | — |
| **committed/expected ratio** | **≈ 3.65** (target 0.75–1.25) | **FAIL** |
| frames | 2369 | — |
| candidate count (changes) | 341 | — |
| candidate→commit ratio | 73 / 341 ≈ **0.21** | — |
| burst / commit-every-few-frames | avg cadence 1 commit / ~32 frames; refractory 3 + persistence 2 structurally prevents per-frame; **no localized burst**, but systemic over-count | partial |
| obvious systematic missed swipes | cannot isolate under over-count — `APPROXIMATE` | — |
| confirmation latency (candidate→confirm) | POST persistence median ≈ **3 frames** (range 2–8) | bounded |
| automatic session continuity | **1** BROADCAST_STARTED + **1** FINISHED; app switch did NOT force reopen; **0 interruptions** | PASS |
| score | 73/73 `UNKNOWN` (gating held) | PASS |

## §28 root-cause (NOT retuned to this run, §27)
The segmenter is **far better than V3** (73 vs 477; ratio 3.65 vs 23.9) — the robust baseline + PRE/POST persistence
work — but two real-device gaps drive the residual over-count:
1. **Coherent-translation cue over-fires**: 45/73 commits are `mode=SCROLL_SWIPE` (`COHERENT_SWIPE`). Real feed video
   contains frequent coherent-ish translation/panning that trips the cheap row/col cross-correlation, and
   `swipeConfirmRelief (0.4)` lowers the confirm bar for anything labeled a swipe → over-commit.
2. **On-device motion scale sits near the floor**: robust `scale` at commits has p50 **0.067** (p95 0.119, max 0.133) —
   well below the lab/profile within-item motion (0.123). Consecutive broadcast frames are more similar than the lab
   fixtures assumed, so per-frame MotionEnergy is small → the robust scale stays near `minMotionScale 0.05` →
   `normJump = prePostDistance / scale` is inflated (commit normJump p50 1.76, up to 11.3) → the confirm ratio is
   crossed too easily. This is the SAME lab↔device representativeness gap as V3, much reduced but not eliminated —
   the bootstrap motion profile (from biased V3 commit-point telemetry) over-estimated the per-frame motion scale.

## FIX DIRECTION (new revision — NOT applied here)
- Make the coherent-translation cue a *gate that raises* the bar, not a relief that lowers it; require a genuinely
  large, persistent, non-chrome content shift even for swipes; or drop `swipeConfirmRelief`.
- Calibrate `minMotionScale` / the confirm ratio from a **scripted §24 per-frame calibration run** (unbiased
  on-device motion scale), not the biased V3 commit-point bootstrap.
- Consider a minimum inter-segment dwell (time-based refractory) matched to real feed cadence.
Per §27 this run is archived as validation evidence; the policy is NOT retuned to it.

## Build under validation (installed, ready)
- Scheme `Gen8` + `GuardianBroadcastExtension`, engine `BoundaryEvidenceAccumulatorV4(policy: .frozenV4)`,
  revision `boundary-policy-v4`, `profile=EXTENSION_FAST`, OCR off. `BUILD SUCCEEDED`, installed
  `com.gen8.guardian.dev` on iPhone 14 Pro Max (iPhone15,3) iOS 26.6 (2026-10-19).
- SampleHandler.swift SHA-256 `992655aaa393044879ce40f1807c47bfabcc244bbf3b312e737b2fd38c55d7bb`.

## Why not run headlessly
iOS cross-app capture is ReplayKit Broadcast Upload only and needs the user's one physical Start-Broadcast gesture
(§26). An agent cannot start the broadcast or traverse a feed. Per Build Bible rule 18/19 we never fake it.

## Protocol for the fresh untouched session (§26 — NOT a tuning set, §27 no-retune)
1. Open Gen8 → Start Broadcast. 2. Traverse ~20 distinct feed items (high-motion + low-motion + similar-theme).
3. A few rapid swipes. 4. One app switch → return. 5. Stop. Record only `MANUAL_APPROXIMATE_GROUND_TRUTH`
(expected distinct items, app transitions, interruptions).

## Pull evidence
```
xcrun devicectl device copy from --device C7C6CE6E-B577-558A-8992-DC6C1F492B39 \
  --domain-type appDataContainer --domain-identifier com.gen8.guardian.dev.GuardianBroadcast \
  --source Documents/gen8_crossapp_proof.log --destination ./P008A_R3_AFTER_crossapp_device_v4.log
```
The V4 session logs `BROADCAST_FINISHED … segments=<n> … policy=boundary-policy-v4` and per-commit `SEGMENT …`
lines with reason codes. Isolate the last `policy=boundary-policy-v4` block.

## §27 device acceptance (fill from the pulled log — APPROXIMATE, no fake exact P/R)
| field | value | accept |
|-------|-------|--------|
| committed NEW_SEGMENT count | _pending_ | — |
| expected distinct items (approx) | ~20 | — |
| committed/expected ratio | _pending_ | 0.75–1.25 |
| burst spam? | _pending_ | none |
| commit-every-few-frames? | _pending_ | none |
| obvious systematic missed swipes? | _pending_ | none |
| automatic session active / app-switch no-reopen | _pending_ | yes |
| privacy container (0 raw media) | _pending_ | green |
| peak memory / thermal | _pending_ | bounded |
| extension survived | _pending_ | yes |

If it fails: archive the run and FIX REQUIRED; **do NOT retune to that run** (§27). Until this is filled from a real
V4 session, device segmentation is not proven and the overall status cannot be
`PASS — REAL-WORLD CONTENT SEGMENTATION V4 PROVEN`.
