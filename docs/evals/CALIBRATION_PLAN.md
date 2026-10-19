# CALIBRATION PLAN

**Doc status:** `CANONICAL` (plan) · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** PROMPT 000A §7; Bible §52, §69, §111, §250, §271, §501, §629. Requirement: VAL-001.

## Why
A score is only as good as its calibration. **Confidence is separate from the score** (§52). A high score that repeatedly fails real-outcome validation means the score model is wrong (§69).

## Metrics (§69)
calibration error · Brier / proper scoring where probabilistic · false-warning rate · override rate · domain bias · expert disagreement · user disagreement · score drift · predictive validity · construct validity · outcome association · coverage/confidence error.

## Ground-truth hierarchy (§111)
domain-expert evidence → user explicit judgment → recall → comprehension → application → retention → real-world output → reproducible cohort outcomes.

## Two calibration layers
- **Domain calibration** (global, governed): versioned constants derived in the Calibration Lab — **no constants invented in Phase 0** (§S). Feeds ScoreContract `domainCalibrationPolicy`.
- **Personal calibration residual** (§250, §271): bounded, local, reversible adjustment; **online calibration without model rewrite** (§271). Never rewrites the global model.

## Process
1. Seed consented calibration dataset (VAL-001). 2. Compute calibration error per domain/language/segment. 3. Compare predicted benefit vs observed outcomes. 4. Feed disagreements to Failure Memory + active learning. 5. Gate releases on calibration floors (set after baseline). 6. Drift sentinel (§272) triggers shadow/canary re-calibration (LEARNING_AND_DRIFT_PLAN).

## Acceptance (release quality floor — §649)
No public score-accuracy claim until calibration is validated on a named dataset with inter-rater agreement and outcome association measured. Reproducibility required (same inputs+versions ⇒ same score).

## Phase-0 status
Plan only; no calibration constants set; PBS v0.1 `acceptanceThresholds: {}`.
