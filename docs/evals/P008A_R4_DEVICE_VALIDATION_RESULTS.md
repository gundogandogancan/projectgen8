# P008A-R4 — Fresh Device Validation V5 Results

Status: `RUN COMPLETE` → **FIX REQUIRED** (`boundary-policy-v5` still over-detects vs feed-item count: 57 vs ~20,
ratio ≈ 2.85 — but NO longer spam/swipe-misfire; driven by genuine internal content cuts). Accuracy label `APPROXIMATE`.
Evidence (immutable): `docs/evals/artifacts/P008A_R4_AFTER_crossapp_device_v5.log`
SHA-256 `6626b5c1a4b32b078870560924112e9abd3fe8a70c62bf0f9daf26694ca9f7ee` (V5 = last `policy=boundary-policy-v5` block,
`BROADCAST_FINISHED … segments=57`).

## §21/§22 — Device validation results (approximate ground truth)
| field | value | verdict |
|-------|-------|:------:|
| committed NEW_SEGMENT | **57** | — |
| expected distinct items (approx) | ~20 | — |
| **committed/expected ratio** | **≈ 2.85** (target 0.75–1.25) | **FAIL** |
| frames / candidates | 2791 / 654 | — |
| candidate→commit ratio | 57/654 ≈ **0.087** (very selective) | — |
| commit cadence | 1 per ~48 frames (~1.6 s) — NOT per-frame/periodic | PASS |
| burst / periodic commit | none (selective, ~1.6 s apart) | PASS |
| **panning false commits** | **0** (SWIPE gate: 55/57 NO_SWIPE, 0 PAN commits) — pan-vs-swipe works | PASS |
| swipe-cue over-fire (the V4 disaster) | **2/57** SWIPE_CONFIRMED (down from V4's 45/73) — relief removal works | PASS |
| obvious systematic missed swipes | cannot isolate under over-count — `APPROXIMATE` | — |
| confirmation latency (postMs) | median **117 ms** (0–317) | bounded |
| automatic session continuity | 1 BROADCAST_STARTED + 1 FINISHED; app switch no reopen; 0 interruptions | PASS |
| score | 57/57 `UNKNOWN` | PASS |

## §23 root cause — NOT retuned to this run (§22)
The R4 fixes demonstrably worked on device: swipe-cue over-fire collapsed (45→2), panning produced **0** false
commits, no periodic/burst spam, candidate→commit fell to 0.087. The residual over-count is now a **different,
honest signal**: 51/57 commits are `ABRUPT_CUT` with `PERSISTENT_CONTENT_REPLACEMENT` (replacement p50 **1.00**) at a
very low on-device motion scale (commit scale p50 **0.043**, below the V2-partial profile's 0.067). These are GENUINE
abrupt content replacements — i.e., **internal shot/scene cuts inside single feed items** (modern Reels are edited
with multiple internal cuts). At the perceptual-signature level an internal shot cut is indistinguishable from a
feed-item swipe. So 57 "segments" for ~20 "items" ≈ 2.85 segments/item reflects **shot-level** granularity, not
spam. The gate counts FEED ITEMS, so ratio 2.85 fails §22.

Closing shot↔item granularity to ratio ≈ 1.0 is **beyond the pure motion sensor**: it needs higher-level
CONTENT-IDENTITY grouping (recognizing successive shots belong to the same item) — a P009 "brain" capability, not a
threshold. The sensor correctly segments persistent visual states; the item-grouping layer is the next revision/P009.

## FIX DIRECTION (new revision / P009 — NOT applied here)
- Add a ContentIdentity-based item-grouping layer above the shot segmenter (coalesce consecutive shots with related
  identity / short gaps into one feed item) so "item count" ≈ ground truth while shot segments remain available.
- Run the scripted §6 evidence-build calibration to set `minMotionScale`/confirm ranges from the true on-device
  per-frame scale (observed 0.043 ≪ profile 0.067) — the current partial profile still over-estimates scale.
- Consider a longer item-level min dwell distinct from the shot-level dwell.
Per §22 this run is archived as validation evidence; the policy is NOT retuned to it.

## Build under validation (installed, ready)
- Scheme `Gen8` + `GuardianBroadcastExtension`, engine `BoundaryEvidenceAccumulatorV5(policy: .frozenV5)`,
  revision `boundary-policy-v5`, `profile=EXTENSION_FAST`, OCR off, 8×8 projections, TIME-based dwell.
  `BUILD SUCCEEDED`, installed `com.gen8.guardian.dev` on iPhone 14 Pro Max (iPhone15,3) iOS 26.6 (2026-10-19).
- SampleHandler.swift SHA-256 `d817b893a3f6973a4b1b7110aad8b0957d3215026a5b988e2a88d5f983fa9917`.

## Why not run headlessly
iOS cross-app capture is ReplayKit Broadcast Upload only; the fresh untouched session (§21) needs the user's one-tap
Start-Broadcast gesture. Per Build Bible rule 18/19 we never fake it.

## §21 protocol (NOT a tuning set, §22 no-retune)
Open Gen8 → Start Broadcast → traverse ~20 distinct feed items (mix high/low motion, ≥1 panning-style video, ≥1
same-theme adjacent transition, a few rapid swipes) → one app switch → return → stop. Manual approximate ground truth
only (expected distinct items, app transitions, interruptions). No exact fake P/R.

## Pull evidence
```
xcrun devicectl device copy from --device C7C6CE6E-B577-558A-8992-DC6C1F492B39 \
  --domain-type appDataContainer --domain-identifier com.gen8.guardian.dev.GuardianBroadcast \
  --source Documents/gen8_crossapp_proof.log --destination ./P008A_R4_AFTER_crossapp_device_v5.log
```
V5 logs `BROADCAST_FINISHED … segments=<n> … policy=boundary-policy-v5` + per-commit `SEGMENT …` (swipe gate, disc,
repl, reason codes). An EVIDENCE build additionally logs per-frame `MOTION …` (derived-only) for a calibration profile.

## §22 device acceptance (fill from the pulled log — APPROXIMATE)
| field | value | accept |
|-------|-------|--------|
| committed NEW_SEGMENT count | _pending_ | — |
| expected distinct items (approx) | ~20 | — |
| committed/expected ratio | _pending_ | 0.75–1.25 |
| burst spam / periodic commit | _pending_ | none |
| systematic swipe misses | _pending_ | none |
| panning → repeated NEW_SEGMENT? | _pending_ | no |
| one active automatic session / app-switch no-reopen | _pending_ | yes |
| privacy container (0 raw media) | _pending_ | green |
| peak memory / thermal | _pending_ | bounded |
| extension survived | _pending_ | yes |

If it fails: archive + FIX REQUIRED; do NOT tune to that run (§22). Until filled from a real V5 session, the sensor
layer is NOT locked and the status cannot be `PASS — SENSOR LAYER LOCKED FOR P009`.
