# P009A-R1 — Fresh Device Validation Results
Status: `RUN COMPLETE` → **FIX REQUIRED** (Tier-0 grouping still did not transfer: shots=73 → items=72, ratio ≈ 3.6;
only 1 merge fired; failed SAFE — no false merges, no spam). Accuracy label `APPROXIMATE`.
Evidence (immutable): `docs/evals/artifacts/P009A_R1_AFTER_crossapp_device_tier0.log`
SHA-256 `2e410a0ad198755cb3fb1155db47eb639929eb18e28c323d0b23f66cb04121e1` (last block,
`groupingPolicy=item-grouping-policy-v2-extension-tier0 profile=EXTENSION_FAST_TIER0 sameCeiling=0.95`).

## §19 slots (FILLED from the pulled log)
| field | value | verdict |
|-------|-------|:------:|
| shot count | **73** (64 CUT / 7 CROSSFADE / 1 SWIPE; 1 per ~46 frames ≈ 1.5 s) | consistent (3rd run ~same) |
| grouped ContentItem count | **72** (58 NEW_CONFIRMED + 14 AMBIGUOUS provisional + 1 SAME) | — |
| **grouped/expected ratio** | 72 / ~20 ≈ **3.6** (gate 0.75–1.25) | **FAIL** |
| shots/item distribution | 1.0 except one 2-shot item | **FAIL** (multi-cut Reels did not coalesce) |
| SAME_ITEM count | **1** (S=0.58 — the only pair where style channels actually fired) | — |
| AMBIGUOUS count | 14 (vs 42 in P009A — N≥0.40 now resolves most boundaries decisively) | — |
| obvious false merges | **0** (the 1 merge had S 0.58, content+style supported; approx GT cannot refute) | PASS |
| obvious false splits | every internal cut split | FAIL |
| deferred coalesces | **0** | FAIL |
| analyses avoided vs per-shot | 72 analyses / 73 shots, reuse 1 → **~1.4%** (lab: 43–48%) | **FAIL** |
| grouping latency | not separately aggregated (signpost `itemgroup` only) | NOT CAPTURED |
| cheap path p50/p95 | **1.372 / 2.887 ms** | PASS (bounded) |
| peak memory | **30.2 MB** (28.6–30.2, no growth) | PASS |
| thermal / time-to-FAIR | **nominal 73/73 — never left nominal** (vs FAIR 45/73 in P009A); no recovery needed | PASS |
| session continuity | 1 START + 1 FINISHED; app switch survived; 0 interruptions | PASS |
| privacy container | only derived `.log` (252,648 B); media sweep 0; 73/73 `score=UNKNOWN` | PASS |

## Root cause (honest; frozen policies NOT retuned — §19/§22 no-retune honored)
**The synthetic style-continuity assumption did not transfer to real signals.** On device the Tier-0 same-evidence
stack almost never fires across real internal cuts: merge S p50 = **0.21** (≈ chrome 0.10 + regional 0.10 only),
p75 = 0.37, max = 0.68. Real projection continuity (corr ≥ 0.80), histogram continuity (L1 ≤ 0.15), and theme
continuity (≤ 0.22) are essentially ABSENT across real cuts at these feature resolutions (8-bin projections, 4-bin
histograms, 64-bit region hashes — these ARE real-pixel-derived on device). Meanwhile the style-BREAK channels fire
constantly (N p50 = 0.65): a real internal cut changes every cheap channel almost as much as an item boundary does.
The lab gates passed because the fixtures ENCODED style continuity by construction — the §5 evidence-distribution
step was performed on synthetic data; the REAL cross-cut distributions were never measured (`evidence=false` on all
runs so far). This is an EVIDENCE-REALISM failure, one level deeper than the R1-fixed ceiling failure.

## What held (not nothing — the safety architecture is now proven twice on device)
0 false merges · no spam/burst · no admission inheritance anywhere · UNKNOWN 73/73 · privacy clean (5th consecutive
clean container) · session continuity · memory flat · thermal NEVER left nominal (improved vs P009A's FAIR 45/73).

## FIX DIRECTION (next revision — NOT applied here)
1. **MEASURE, don't assume (the missing step)**: run the scripted EVIDENCE-BUILD session (`GEN8_EVIDENCE_BUILD`) so
   the extension logs per-shot cross-cut channel values (projection corr, histogram L1, theme distance, regional)
   on REAL content with known block structure (same-item multi-cut blocks vs item boundaries) → derive the real
   Tier-0 separability, then rebuild corpus + thresholds from MEASURED distributions.
2. If real Tier-0 continuity is confirmed this weak, the honest architectural answer: richer cheap features
   (higher-resolution projections/histograms, dHash, color moments — budget permitting) or accept that Tier-0 item
   count stays APPROXIMATE and full grouping is a Tier-1/app capability.
3. Do NOT lower merge thresholds to force coalescing — S p50 0.21 vs threshold 0.50 is signal ABSENCE, not
   miscalibration; lowering would merge across items (the one unsafe direction).

## Build under validation (installed, ready)
Scheme `Gen8` + `GuardianBroadcastExtension`: `ShotSegmenterV5` (frozen boundary-policy-v5) + V2 Tier-0 grouping
(`item-grouping-policy-v2-extension-tier0`, profile EXTENSION_FAST_TIER0, sameCeiling 0.95) + DeferredItemCoalescerV1.
BUILD SUCCEEDED; installed `com.gen8.guardian.dev` on iPhone 14 Pro Max iOS 26.6 (2026-10-19).
SampleHandler SHA-256 `27da814946f4389e1a7a38ca73750e70aada619c655a417e5c05c3f380f9c72a`.
Logs: `BROADCAST_STARTED … shotPolicy=… groupingPolicy=… profile=… sameCeiling=…`, per-shot `SHOT …`, per-decision
`ITEM … state=… merge=… new=…`, `COALESCE deferredMerges=…`, session `BROADCAST_FINISHED … shots=… items=…`.

## §19 protocol (approximate ground truth; no fake exact P/R; §22 no-retune)
One Start Broadcast → ~20 distinct items incl. several multi-cut Reels, same-theme adjacent, high-motion, panning,
rapid swipes → one app switch → return → stop. Report: shot count, grouped item count, grouped/expected ratio,
shots/item distribution, SAME_ITEM count, AMBIGUOUS count, obvious false merges/splits, analyses avoided, cache
reuse, latency, memory, thermal (time-to-FAIR per §20), session continuity, privacy.

## Provisional device gate (fill from pulled log)
grouped/expected 0.75–1.25 · multi-cut items visibly coalesce · no obvious cross-item merge · rapid items separate ·
analyses materially below shot count · privacy/resource/session PASS. If fail: archive + FIX REQUIRED, no retune.
