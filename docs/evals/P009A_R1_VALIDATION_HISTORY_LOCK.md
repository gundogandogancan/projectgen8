# P009A-R1 — Validation History Lock (immutable; never overwrite)

Device/OS/toolchain for all runs: iPhone 14 Pro Max (iPhone15,3), iOS 26.6, team `47XQMQZLF6`,
`com.gen8.guardian.dev` (+`.GuardianBroadcast`), Xcode 26.6 / Swift 6.3. Ground truth = `MANUAL_APPROXIMATE`.

| run | policy / engine | artifact | SHA-256 | outcome |
|-----|-----------------|----------|---------|---------|
| BEFORE aHash | P007D ContentChangeDetector | `artifacts/P008A_BEFORE_crossapp_session.log` | `96a92d02…224d6` | 406 over |
| R1 | boundary-policy-v2 | `artifacts/P008A_R1_AFTER_crossapp_rerun.log` | `8510ee92…146ef` | 5 under (R 0.25) |
| R2/V3 | boundary-policy-v3 | `artifacts/P008A_R2_AFTER_crossapp_device_v3.log` | `e0f23284…f148` | 477 over (23.9) |
| R3/V4 | boundary-policy-v4 | `artifacts/P008A_R3_AFTER_crossapp_device_v4.log` | `f63c8de3…5ba1` | 73 over (3.65) |
| R4/V5 | boundary-policy-v5 | `artifacts/P008A_R4_AFTER_crossapp_device_v5.log` | `6626b5c1…f7ee` | 57 shots (shot-level OK; shot≠item) |
| **P009A item-group** | `item-grouping-policy-v1` on frozen V5 shots | `artifacts/P009A_AFTER_crossapp_device_itemgroup.log` | `7a13fcf063e3d38b79c79c5c36282871b739af243e3a5ca0233622b413801252` | **shots=73 items=73 (ratio 3.65): ZERO merges** |

## P009A device failure facts (entry evidence, §0 — preserved, not rewritten)
frames 3813 · candidates 1082 · shots 73 (65 CUT / 6 CROSSFADE / 1 SWIPE / 1 start) · items 73 (31 NEW_CONFIRMED +
42 AMBIGUOUS provisional) · SAME_ITEM = 0 · false merges = 0 (failed SAFE) · analyses 73, reuse 0 (no economy) ·
cheap p50/p95 1.294/2.856 ms · peak 30.3 MB · thermal FAIR 45/73 (no serious/critical) · 1 uninterrupted session ·
privacy container clean · 73/73 score=UNKNOWN.

## Structural root cause (locked)
`EXTENSION_FAST_TIER0` maximum practical same-item evidence ≈ **0.49** (cut-prior 0.10 + edit-burst 0.12 +
theme 0.22 + chrome 0.05) < frozen `confirmSameThreshold = 0.50` → SAME_ITEM mathematically unreachable.
Observed device merge scores: p50 ≈ 0.22, max ≈ 0.44.

## Methodology failure (locked, owned)
The §20 held-out gate ran ONLY in `APP_FULL_TIER1` (caption/audio evidence present). No predeclared Tier-0 gate
existed before freeze. This is a METHODOLOGY FAILURE + PROFILE TRANSFER FAILURE — not device noise, and not fixable
by "lower 0.50 to 0.49" or retuning to the archived run. `item-grouping-policy-v1` + the APP_FULL_TIER1 held-out
results remain frozen as evidence; R1 introduces profile-aware policies (V2) with their own predeclared gates.
