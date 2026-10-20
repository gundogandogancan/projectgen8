# GEN8 NEXT ALLOWED WORK (GENERATED VIEW)

> GENERATED_VIEW. Deterministic output of the READY law over the twin (suite-asserted:
> `testCP04_ReadyLawAndNextActionDeterminism`).

## READY now (exactly one)

**CP-INDEPENDENT-AUDIT** — independent clean-session audit of the ULU EVREN control plane
(candidate tag `gen8-ulu-evren-control-plane-audit-candidate`). Attack surface per mandate §31:
missing historical blockers, wrong dependencies, cycles, false VERIFIED states, superseded-treated-active,
latest-doc-wins errors, device/calibration claim inflation, hidden findings, wave inversion, forbidden
recommendations, stale evidence refs, orphan requirements, contradictory evidence resolution.

## BLOCKED until CP-INDEPENDENT-AUDIT PASS

RWC-PRE-01..13 (preregistration lanes). Then RWC-PRE-14 gates RWC-CORPUS.

## FORBIDDEN now (and until their gates pass)

- Corpus acquisition (needs RWC-PRE-14 PASS)
- Annotator recruitment/setup, IRR execution (needs RWC-PRE-14 PASS)
- Calibration fitting on real data (needs corpus + annotation)
- Final held-out selection/sealing (needs RWC-PRE-12 protocol + corpus)
- Production score display; Presentation/Glyph/Motion (needs RWC-HELDOUT + RWC-DEVICE-E2E PASS; gate in CODE stays CLOSED)
- Gate tuning after data visibility (FM-001/FM-007 — permanent)

## The twin may recommend; it may not execute

No auto-merge, no auto-deploy, no gate weakening, no history rewrite, no UNKNOWN→VERIFIED conversion,
no blocker erasure (schema §7). Every transition needs human-authorized, evidence-bearing commits.
