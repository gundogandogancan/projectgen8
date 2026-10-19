# P009A — Device Item-Group Validation Results

Status: `RUN COMPLETE` → **FIX REQUIRED** (grouping merged NOTHING on device: shots=73, items=73, ratio ≈ 3.65 —
a structural Tier-0 evidence ceiling, failing SAFE with zero false merges). Accuracy label `APPROXIMATE`.
Evidence (immutable): `docs/evals/artifacts/P009A_AFTER_crossapp_device_itemgroup.log`
SHA-256 `7a13fcf063e3d38b79c79c5c36282871b739af243e3a5ca0233622b413801252` (P009A = last block,
`groupingPolicy=item-grouping-policy-v1`, `BROADCAST_FINISHED frames=3813 … shots=73 items=73`).

## §21 — Device item-group results (approximate ground truth)
| field | value | verdict |
|-------|-------|:------:|
| ShotSegmenter count | **73** (1 per ~52 frames ≈ 1.7 s; 65 CUT / 6 CROSSFADE / 1 SWIPE / 1 start) | consistent w/ V5 run (57) |
| grouped ContentItem count | **73** (31 NEW_ITEM_CONFIRMED + 42 AMBIGUOUS provisional) | — |
| shots/item distribution | **1.0 for every item — ZERO merges fired** | **FAIL** (multi-cut items did not coalesce) |
| grouped/expected ratio | 73 / ~20 ≈ **3.65** (gate 0.75–1.25) | **FAIL** |
| obvious false merges | **0** (no SAME_ITEM decision ever fired — vacuously zero; fails SAFE) | PASS |
| obvious false splits | 42 AMBIGUOUS + every internal cut split | FAIL (over-split) |
| downstream analyses / cache reuse | 73 analyses, reuse **0** — no §26 economy gain this run | FAIL |
| rapid distinct item separation | trivially preserved (everything separate) | PASS (vacuous) |
| automatic session continuity | 1 BROADCAST_STARTED + 1 FINISHED; app switch survived; 0 interruptions | PASS |
| resource | cheap p50/p95 **1.294 / 2.856 ms**; peak **30.3 MB** (24.4–30.3); thermal **fair** (45/73) / nominal (28/73) — first non-nominal run, still no serious/critical | PASS |
| privacy container | only derived `.log`; media sweep 0; 73/73 `score=UNKNOWN` | PASS |

## Root cause (honest; frozen policy NOT retuned to this run)
**Structural Tier-0 merge ceiling.** In `EXTENSION_FAST_TIER0` the only available merge evidence is
cut-prior (0.10) + edit-burst (0.12) + theme-continuity (0.22) + chrome-same (0.05) → theoretical max ≈ **0.49**,
which is BELOW the frozen `confirmSameThreshold = 0.50`. A SAME_ITEM confirmation was therefore mathematically
unreachable on device: observed merge scores min 0.00 / p50 0.22 / max **0.44**. Every internal cut became either
NEW_ITEM_CONFIRMED (when discontinuity evidence stacked) or AMBIGUOUS provisional split.

**Methodology gap (owned):** the lab §20 held-out gate was evaluated in the `APP_FULL_TIER1` profile
(captions/audio available — merge evidence rich); no Tier-0 lab eval was run before freezing. The lab→device
PROFILE gap is exactly what slipped through. The safety design held perfectly (zero cross-item merges, provisional
splits only — no admission leakage possible), but the grouping economy did not transfer to the extension tier.

## FIX DIRECTION (next revision — NOT applied here)
1. **Profile-aware acceptance**: run the full lab gate suite in `EXTENSION_FAST_TIER0` as a predeclared gate BEFORE
   freezing (the missing eval), and define per-profile thresholds — Tier-0 `confirmSame` must sit BELOW the Tier-0
   evidence ceiling, with the §7 strongNew veto keeping merge precision safe.
2. **Add Tier-0 merge evidence**: cross-shot projection correlation, histogram continuity, richer cadence features —
   all already computed or cheap; raises the Tier-0 ceiling honestly rather than lowering the bar blindly.
3. Longer-term: Tier-1-lite caption fingerprint in-extension if budget permits, or official shared-container capability.
Per the no-retune rule this run is archived as validation evidence; `item-grouping-policy-v1` is unchanged.

## Build under validation (installed, ready)
- Scheme `Gen8` + `GuardianBroadcastExtension`: `ShotSegmenterV5` (frozen `boundary-policy-v5`, untouched) +
  extension-local TIER-0 `ContentItemGroupingEngineV1` (frozen `item-grouping-policy-v1`, profile EXTENSION_FAST_TIER0 —
  visual/chrome/temporal/cache evidence only; captions/audio honestly unavailable in-process, §22).
- `BUILD SUCCEEDED`, installed `com.gen8.guardian.dev` on iPhone 14 Pro Max (iPhone15,3) iOS 26.6 (2026-10-19).
- SampleHandler SHA-256 `5dce29c4866e095ecd62c128c827ad557aa4c9bb4ed46a55d37813dc692dca0e`.
- Logs per shot `SHOT id=… in=… reasons=…` and per grouping decision `ITEM id=… state=… openedNew=… provisional=…
  merge=… new=… score=UNKNOWN`; session line `BROADCAST_FINISHED … shots=<n> items=<m> …` (derived-only).
- Downstream analysis now runs ONCE PER ITEM (confirmed or provisional), not per shot (§9/§26).

## Why not run headlessly
ReplayKit needs the user's one-tap Start-Broadcast gesture; an agent cannot traverse a real feed (Bible rules 18/19).

## §21 protocol (approximate ground truth only — no fake exact device P/R)
Open Gen8 → Start Broadcast → traverse ~20 distinct feed items including several edited multi-cut videos, a
high-motion item, a panning item, same-theme adjacent items, a few rapid swipes → one app switch → return → stop.
Record approximate: distinct item count, obvious multi-cut items, app transitions, interruptions.

## Pull evidence
```
xcrun devicectl device copy from --device C7C6CE6E-B577-558A-8992-DC6C1F492B39 \
  --domain-type appDataContainer --domain-identifier com.gen8.guardian.dev.GuardianBroadcast \
  --source Documents/gen8_crossapp_proof.log --destination ./P009A_AFTER_crossapp_device_itemgroup.log
```

## §21 report slots (fill from the pulled log)
| field | value | accept |
|-------|-------|--------|
| ShotSegmenter count | _pending_ | — |
| grouped ContentItem count | _pending_ | — |
| shots/item distribution | _pending_ | multi-cut items coalesce |
| grouped/expected ratio | _pending_ | 0.75–1.25 |
| obvious false merges | _pending_ | none |
| obvious false splits | _pending_ | no burst |
| automatic session continuity | _pending_ | 1 session, app-switch no reopen |
| resource (cheap p50/p95, peak mem, thermal) | _pending_ | bounded |
| privacy container (0 raw media) | _pending_ | green |

Honest Tier-0 caveat: without caption/audio evidence, cut-presenting swipes between visually-similar items may land
AMBIGUOUS (provisional split) — that inflates the item count SAFELY (never a cross-item merge). The device ratio
gate should be read with that asymmetry in mind. If it fails: archive + FIX REQUIRED; no retune to the run.
