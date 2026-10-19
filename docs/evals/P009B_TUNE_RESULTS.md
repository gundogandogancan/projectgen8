# P009B — TUNE Results

## R1 (active) — corpus V2, seedless TUNE bank

**Harness:** `P009BR1ClosureTests.testTuneV2` → `P009BR1_TUNE scenarios=24 failures=0`.

TUNE-phase fixes made this round (all honesty/correctness, no threshold tuning; frozen before held-out):
1. **F7-adjacent build defect found by the F7 happy-path test:** honest `.unavailable` evidence records
   (itemID nil) defaulted to `itemProvisional=true`, which wrongly marked whole states provisional and
   blocked lawful mints. Fix: only identity-BEARING evidence (itemID != nil) counts for provisional
   markers/generation checks. A record with no identity makes no identity claim.
2. No other change: the 24 TUNE expectations passed on the first run after the R1 core fixes.

After these, routing policies, lease bounds (maxRetryAttempts=3), TTLs (normal 3.6M ms / low-info 5000 ms),
sanitizer rules, lexicons, and all V2 expectations were FROZEN; HELD_OUT/STRESS/OOD ran once.

## P009B original round (superseded, kept for the record)

`P009B_TUNE scenarios=18 failures=0 abstentions=18 contradictions=2` (count corrected per F4 — the
original print claimed 17). One TUNE defect was found and fixed pre-freeze (audio `no-validated-events`
suppression). The V1 seed-parity split design was later refuted by the independent audit (F2) — V1
results are routing/honesty evidence only, not split-generalization evidence.
