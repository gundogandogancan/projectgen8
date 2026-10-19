# P009A-R1 — TUNE Results (Tier-0, seed:0 only)
Status: `TESTED`. Source: `testTuneScanExploratory` + the recorded fix sequence. 20 true boundaries / 55 merges.

## Fix sequence converged on TUNE (each verified on TUNE only; no held-out/stress/device-like label inspected)
1. themeDiscontinuityMin 0.42→0.30; style-break weights 0.15/0.10→0.20/0.20 (full style change = real NEW signal).
2. confirmNewRaw 0.40→0.35 (candidate C: +recall, no precision loss).
3. ANCHOR RULE: burst removed from anchors (a style-similar different item at edit cadence must not merge).
4. TWO-LEVEL THEME ANCHOR: strong ≤0.12 always; weak ≤0.22 only below longDwell (killed the long-dwell weak-theme
   false merge — the device-like mechanism).
5. Corpus scenario-24 spread fix (jitter was collapsing the designed ambiguity gap).

## Final frozen TUNE result
newP 1.000 · newR(raw) 0.850 · F1(raw) 0.919 · **mergeP 1.000 · xMerge/item 0.0000** · mergeR 0.927 · ambRate 0.093 ·
shots/item 2.25 · analyses avoided 0.52. Candidate scan recorded (A/B/C variants). Frozen:
`item-grouping-policy-v2-extension-tier0` + `-app-tier1` (§17).
