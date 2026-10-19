# P009A-R1 — Profile-Aware Grouping Policy (frozen)
Status: `TESTED` (tuned on Tier-0 TUNE only; frozen before held-out/stress/device-like; §17).
Frozen revisions (logged every session with profile + sameCeiling):
- `item-grouping-policy-v2-extension-tier0` (profile EXTENSION_FAST_TIER0, ceiling 0.95)
- `item-grouping-policy-v2-app-tier1` (profile APP_FULL_TIER1, ceiling 1.60)
Shared frozen parameters: confirmSameNormalized 0.50 · confirmNewRaw 0.35 · sameVeto 0.55 · newVeto 0.30 ·
strongTheme ≤0.12 / weakTheme ≤0.22 (weak anchors only below longDwellMs) · themeDisc ≥0.30 · projection 0.80/0.30 ·
histogram 0.15/0.35 · chrome 0.10/0.30 · regional ≤0.15 · burstGap 3200 ms · longDwell 3800 ms · maxShotsPerItem 64.
Tier-0 SAME is now mathematically reachable: max same stack ≈ 0.95 → normalized 1.0 ≫ 0.50 (the P009A bug is
structurally dead; `testTier0SameDecisionReachable` proves it behaviorally). Missing evidence contributes 0 — never
negative (`testAbsentEvidenceNotNegative`). Strong-new veto absolute (`testStrongNewVetoBeatsSameScore`).
NO device-run retuning: the P009A device log was used only for the device-like replay's statistical shape.
