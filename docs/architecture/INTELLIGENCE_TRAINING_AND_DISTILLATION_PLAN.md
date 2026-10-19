# INTELLIGENCE TRAINING & DISTILLATION PLAN

**Doc status:** `CANONICAL` (plan) · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** PROMPT 000A §7; Bible §64, §68, §178–§179, §244–§279, §512–§514, §563. **No "self-learning" language without governance.** Self-improving, **not** self-governing (§68).

## Task taxonomy (what we train/evaluate)
content identity · OCR/ASR quality · topic/message/intent/contribution · sensitive-content classification · Semantic Shield concept matching · manipulation/influence signals · temporal segment classification · confidence/calibration · claim/evidence (gated/specialist) · child/family safety · positive-exposure categorization · multilingual/cultural.

## Label hierarchy (Bible §248, §111)
`verified labels (expert / outcome) > user explicit judgment > recall/comprehension/application/retention > weak/auto labels`. **Weak labels never silently become verified labels.** Ground-truth hierarchy per EVALUATION_MASTER_PLAN.

## Pipeline
1. **Ground-truth labeling** with documented guidelines; inter-rater agreement tracked.
2. **Human review lab** (§514) for high-risk domains + disagreements.
3. **Active learning** targets uncertain/novel/failed cases (feeds from Failure Memory §66).
4. **Teacher → student distillation** (§254): large/specialist teacher → small on-device student, with eval parity floors before promotion.
5. **Three learning loops** (§178, §247): Personal (local, bounded, reversible) · Shared (privacy/rights-gated aggregate) · Global (governed model evolution).

## Dataset coverage (defined in DATASET_GOVERNANCE)
golden · adversarial · multilingual · sensitive-content · TemporalGraph (long-form, alternate cuts, inserted ads) · Semantic Shield · child/family · calibration · drift/regression.

## Governance gates (Bible §68, §563)
`OBSERVE → ERROR ANALYSIS → PROPOSAL → CHALLENGER → OFFLINE EVAL → ADVERSARIAL EVAL → SHADOW → CANARY → APPROVAL → DEPLOY → MONITOR → ROLLBACK`. Champion/challenger (§274); shadow intelligence (§273); self-improvement scorecard (§275). Every pack: signed manifest + rollback artifact (MODEL_REGISTRY).

## Defenses
- **Data poisoning defense** (§269) on all training inputs; provenance + rights required (DATA_CLASSIFICATION).
- **Personal learning isolation** (§270): personal adaptation never leaks into global pool without consent (§4.16).
- **No uncontrolled self-modification** (§4.20): production agents cannot change their own weights/policy.

## Phase-0 status
Plan only. No training run, no datasets collected, no model packs. First calibration dataset + feedback begin at VAL-001; governance validated by AI-002.
