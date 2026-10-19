# DATASET GOVERNANCE

**Doc status:** `CANONICAL` (governance) · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** PROMPT 000A §7; Bible §40(P000), §111, §269, §348, §512–§514, §564. Companion to EVALUATION_MASTER_PLAN + DATA_CLASSIFICATION_AND_RIGHTS.

## Principles
- Every dataset has: **purpose · provenance · rights/license · consent basis · privacy class · retention · versioning · owner · last_verified**.
- **No private user content** enters any shared/training dataset without explicit consent (§4.16). Private ⇒ `GLOBAL_REUSE=DENY`.
- Quality claims are **dataset-specific** (§40 P000). No "99% accurate" without naming the benchmark.
- **Poisoning defense** (§269): untrusted/external data is sanitized + provenance-checked before inclusion.

## Dataset classes (seeded; data collected Phase 1+)
| Dataset | Purpose | Rights source | Privacy class |
|---|---|---|---|
| golden-identity / cognition / score | correctness baselines | permitted/public or synthetic | non-personal |
| adversarial | robustness (§122) | synthetic + permitted | non-personal |
| multilingual | per-language floors | permitted/licensed | non-personal |
| sensitive-content | protection classifiers | strictly governed, access-controlled | high-sensitivity |
| temporal (long-form) | TemporalGraph, alternate cuts, ads | permitted/licensed | non-personal |
| semantic-shield | exclusion precision/recall | synthetic + permitted | non-personal |
| child/family safety | child mode, anti-coercion | synthetic + governed | high-sensitivity |
| calibration | score calibration | user feedback (consented) + expert | personal→aggregate |
| drift/regression | failure-memory re-runs | derived from FailureCases | internal |

## Rights & provenance (§348, §564)
Each item tracks source/visibility/platform/rights_state/derived-feature rights/retention/training-permission/deletion-takedown/provenance/freshness/content-version. Entries without a rights record cannot be used for cross-user reuse or training.

## Lifecycle
versioned snapshots · immutable eval sets for regression · deletion/takedown propagation · access control for sensitive datasets · audit trail. Datasets referenced by ScoreContracts (`validationDatasetRefs`) and MODEL_REGISTRY (`eval_version/eval_hash`).

## Phase-0 status
Governance only; **zero datasets collected**. First consented calibration dataset begins at VAL-001.
