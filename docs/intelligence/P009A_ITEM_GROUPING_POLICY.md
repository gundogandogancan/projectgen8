# P009A — Item Grouping Policy (frozen `item-grouping-policy-v1`)

Status: `TESTED` (tuned on TUNE only; frozen before held-out; §20 gates ALL PASS).
Source: `ItemGroupingPolicyV1` / `ContentItemGroupingEngineV1`.

## States (§6)
`SHOT_ONLY · CANDIDATE_SAME_ITEM · SAME_ITEM_CONFIRMED · CANDIDATE_NEW_ITEM · NEW_ITEM_CONFIRMED · AMBIGUOUS`.
Rules enforced: internal cuts may stay within one item; a NEW item requires item-level evidence (never merely a
visual cut); insufficient evidence → AMBIGUOUS; source/app certainty never faked; a confirmed new item closes the
prior window; later evidence may revise grouping — versioned (`reviseMergeProvisional`, MERGED revision).

## Decision rule (precision-first merge, §7)
```
newScore  ≥ confirmNewThreshold (0.42) ∧ newScore ≥ mergeScore + margin (0.12)        → NEW_ITEM_CONFIRMED
mergeScore ≥ confirmSameThreshold (0.50) ∧ mergeScore ≥ newScore + margin ∧ ¬strongNew → SAME_ITEM_CONFIRMED
otherwise                                                                               → AMBIGUOUS (provisional split)
strongNew = confirmed swipe ∨ chrome/app-surface change   (vetoes merge unconditionally)
```
`safeAdmissionInheritance` is granted ONLY by non-provisional SAME_ITEM_CONFIRMED — an uncertain boundary can never
leak a prior safe Guardian admission (§7; `testFalseCrossItemMergeProtection_AmbiguousSafeSplit`).

## Frozen parameters (selected on TUNE seed:0 only — candidate "B_strictMerge")
Thresholds: confirmNew 0.42 · confirmSame 0.50 · margin 0.12 · maxShotsPerItem 64.
Features: themeContinuityMax 0.22 · themeDiscontinuityMin 0.42 · chromeSameMax 0.10 · chromeChangeMin 0.30 ·
burstGapMs 3200 · longDwellMs 3800. Weights: see CONTENT_IDENTITY_EVIDENCE_GRAPH.
Why B over the balanced default: on TUNE, default had mergeP 0.985 / false cross-item merge 0.0238/item (would FAIL
the §20 ≤0.01 gate); B converts that case to AMBIGUOUS → mergeP 1.000, xMerge 0.0000, at the cost of 3 AMBIGUOUS
events (the §7-preferred outcome). Safety-first merge precision selected deliberately.

## Capability tiers (§9/§22)
`EXTENSION_FAST_TIER0` (broadcast extension): visual + chrome + temporal + cache evidence only (captions/audio
honestly unavailable in-process). `APP_FULL_TIER1`: adds caption/audio continuity evidence. Same state machine,
same policy revision, both logged.
