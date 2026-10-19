# P009B — HELD-OUT Results

## R1 (active) — corpus V2 HELD_OUT bank, run once after freeze

**Harness:** `P009BR1ClosureTests.testHeldOutV2RunOnce` → `P009BR1_HELDOUT scenarios=16 failures=0`.

The V2 held-out bank is structurally independent from TUNE (leakage auditor: 0 violations; declared
near-duplicate rule J>0.8 + same modality combo): different scenario instances (cooking/garden/wedding/
spa/vlog-fight content vs TUNE's birdhouse/party/war-news content), different modality combinations,
different temporal scripts, TR+EN mixed within the bank (NOT a translation of TUNE — audit F2 closed).
Nothing was modified after freeze.

## P009B original round (superseded)

`P009B_HELDOUT failures=0` on V1 seed 1 — refuted as independence evidence by the audit (seed 1 was a
translation-only variant of TUNE with shared expectations). Kept only as historical record.

**Interpretation limits (unchanged):** structural/honesty gates on project-authored derived inputs; no
exact P/R claims; real-world perception accuracy requires the user-gated device validation.
