# EVALUATION MASTER PLAN

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §40(P000), §69, §111, §121–§122, §159, §512–§514, §574; Prompt 000 §40.

**Rule:** Quality claims are dataset-specific. Never "99% accurate" / "87% viral" without a defined benchmark (Bible §13, §40 P000).

## Datasets (seed definitions — data collected in later phases)
| Dataset | Purpose | Key cases |
|---|---|---|
| **Golden** | correctness on representative content | identity-golden, cognition-golden, score-golden |
| **Adversarial** | robustness | prompt injection in caption, hidden frames, OCR poison, fake citations, source laundering, misleading thumbnails, deepfake, keyword stuffing, score gaming, coordinated feedback (§122) |
| **Multilingual** | per-language quality floor | slang, profanity, euphemism, sarcasm, humor, religious vocab, metaphor, news/political vocab (§41 P000, §557) |
| **Long-form temporal** | TemporalGraph + analysis-ahead | 30–60 min videos, alternate cuts, inserted ads, segment boundaries |
| **Child/family safety** | child mode + anti-coercion | positive-exposure, necessary-safety exception, coercive consent attempts (§448) |
| **Semantic Shield** | exclusion precision/recall | near-miss entity, cross-language euphemism, visual symbol |
| **Identity** | resolution + wrong-reuse | duplicate caption, re-upload, version mismatch |
| **Anti-coercion** | family abuse paths | false guardian, replayed invite, silent permission expansion |
| **Offline/outage** | degraded correctness | single-domain outage, stale cache |
| **Battery/thermal** | energy-per-decision | lowest supported device |
| **Social publish** | reliability | wrong-account, duplicate, timeout-after-send |

## Metrics (Bible §69, §648; Prompt 000 §60)
- **Pre-exposure:** PRE_EXPOSURE_COVERAGE_RATE, CACHED_PRE_EXPOSURE_RATE, FRESH_PRELOAD_SUCCESS_RATE, FIRST_FRAME_FALLBACK_RATE.
- **Admission latency:** ADMISSION_P50/P95/P99.
- **Correctness/safety:** FALSE_ALLOW_RATE, FALSE_HIDE_RATE, UNKNOWN_RATE, LATE_WARNING_RATE, WRONG_SKIP_RATE, TEMPORAL_ALIGNMENT_FAILURE_RATE, CONTENT_IDENTITY_ERROR_RATE.
- **Score science:** calibration error, Brier (where applicable), false-warning rate, override rate, domain bias, expert/user disagreement, score drift, predictive validity, construct validity, outcome association, coverage/confidence error.
- **Economy/energy:** CACHE_REUSE_RATE, DEVICE_ENERGY_PER_DECISION, CLOUD_COST_PER_FRESH_ANALYSIS, CLOUD_COST_PER_REUSED_DECISION, MODEL_DISAGREEMENT_RATE.
- **Social:** publish reconciliation success, wrong-account incidents (target 0), duplicate incidents (target 0).

## Ground-truth hierarchy (Bible §111)
domain-expert evidence → user explicit judgment → recall → comprehension → application → retention → real-world output → reproducible cohort outcomes. A high score that repeatedly fails outcome validation ⇒ the score model is wrong (§69).

## Human review lab (§514)
Inter-rater agreement; expert panels for high-risk domains; disagreement feeds calibration + failure memory.

## Regression & failure memory (§66, §67)
Every significant failure → `FailureCase` + regression test; new releases re-run the historical failure set and the adversarial suite.

## Release quality floors (§649)
No public "analyzes before you watch" claim until: pre-exposure coverage measured · false-safe state zero-by-design · calibration validated · battery/thermal acceptable · auto-skip alignment proven. Per-language promotion requires meeting that language's floor (§41 P000).

## Phase-0 status
Plan only; datasets seeded in Phase 1+. Calibration dataset + feedback capture begin at **VAL-001**.
