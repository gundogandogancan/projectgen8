# LEARNING & DRIFT PLAN

**Doc status:** `CANONICAL` (plan) · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** PROMPT 000A §7; Bible §66–§69, §178–§179, §244–§279. **Self-improving, NOT self-governing** (§68).

## Three learning loops (§178, §247)
1. **Personal adaptation** — fast, local, bounded, reversible; within editable preference/skill/goal state only (§195, §270, §276).
2. **Shared intelligence** — privacy/rights-gated aggregate / reusable non-personal content intelligence (§252, §641).
3. **Global model evolution** — slow, governed, evaluated, shadowed, canaried, rollbackable (§68).

## Controlled evolution gate (§68)
`OBSERVE → ERROR ANALYSIS → PROPOSAL → CHALLENGER → OFFLINE EVAL → ADVERSARIAL EVAL → SHADOW → CANARY → APPROVAL → DEPLOY → MONITOR → ROLLBACK`.

## Drift detection (§272)
**Model Drift Sentinel** monitors calibration drift, input distribution shift, score drift, disagreement-rate change. On trip: raise incident → shadow re-eval → canary → rollback if regressed. Freshness watchers (§265) + reality revalidation (§266) keep knowledge current.

## Champion / challenger (§274) + shadow (§273)
New models run as challengers in shadow against the champion on golden + adversarial + calibration sets; promoted only on meeting quality floors; self-improvement scorecard (§275) records deltas.

## Failure-driven improvement (§66, §240, §267)
Every significant error → `FailureCase` + regression test; new releases re-run the historical failure set + adversarial suite. Pre-flight failure memory (§240) feeds pre-exposure.

## Governors & defenses
Global Learning Governor (§268) bounds what can change. Data-poisoning defense (§269). Personal learning isolation (§270) — no leak to global pool without consent. No production agent rewrites its own policy/weights (§4.20).

## Phase-0 status
Plan only; no learning active. Governance validated by AI-001 (rollback) + AI-002 (model governance) + VAL-001 (calibration).
