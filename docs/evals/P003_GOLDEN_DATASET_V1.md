# P003 — Golden Dataset v1

**Doc status:** `CANONICAL` · **Phase:** 3 · **Date:** 2026-10-18 · PROMPT 003 §20. Legally safe: synthetic/original/public-domain only. No copyrighted social video, no private/child data. Materialized as in-code fixtures + manifests (no binary blobs committed).

## Task slices (TR + EN where text)
| Slice | Examples (synthetic) | Head | Expected |
|---|---|---|---|
| mortality/disease/disaster | "earthquake struck", "deprem", "chronic disease", "kanser teşhisi" | H2 | correct label(s) |
| semantic shield concept | rule "RivalTeam\|Rakip Takım" vs matching/non-matching text | H3 | high/none tiers |
| topic/message | CTA-heavy vs informational text | H4 | advertisement vs informational |
| attention signals | "Hurry! last chance subscribe" / "Acele! son şans" | H5 | count > 0 |
| positive exposure | disease topic + avoid policy | fusion | NOT_RECOMMENDED, truth unchanged |
| child policy | warConflict + childMode block | fusion | childPolicyBlock |
| false-positive trap | neutral river documentary vs RivalTeam rule | H3 | none (no false hide) |
| ambiguous / neutral medical | "immune system explainer" | H2 | diseaseIllness topic (not a hide) |
| multilingual | TR + EN variants of above | H2–H5 | per-language correct |
| identity variant / version mismatch | from golden-v0 + temporal wrong-version | identity/temporal | SAME / refuse-skip |

## Harness
Covered by `GuardianCoreTests` + `GuardianIntelligenceTests` (108 tests) + `EvalHarness` artifact (`ml/evaluation/results/latest.json`). Per-task metrics only; abstentions separate; no aggregate "AI accuracy". Expand with labeled real (rights-clear) data in later phases.
