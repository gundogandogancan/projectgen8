# P003 — Multimodal Fusion Contract

**Doc status:** `CANONICAL` · **Phase:** 3 · **Date:** 2026-10-18 · PROMPT 003 §6, §16. Implemented in `ScoreAdmissionFusionV1` (deterministic, versioned `fusion-v1`).

## Rules (NOT simple averaging)
1. **No averaging of head probabilities.** Explicit deterministic precedence (ADR-0007) over structured signals.
2. **Modality disagreement lowers confidence** (not a vote average).
3. **Missing modality ≠ negative evidence** — an absent head is UNAVAILABLE, never counted as "safe" or "bad".
4. **Low-confidence image signal cannot override strong contradictory text context** (and vice-versa).
5. **Known graphic visual signal may trigger protection even if transcript is neutral** (when H1 becomes available).
6. **User hard-exclusion may act on a strong entity/topic signal** (Semantic Shield high → exclude).
7. **Truth/Evidence stays separate from exposure policy** — Positive Exposure can down-rank a factually-correct item.

## Precedence (deterministic)
`EVIDENCE-COVERAGE GATE → CHILD SAFETY FLOOR → USER HARD SEMANTIC SHIELD (high) → POSITIVE EXPOSURE POLICY → MANIPULATION PRESSURE (caution) → PERSONAL BENEFIT THRESHOLD`. Medium shield → caution (never silent hide). Below evidence-coverage threshold → UNKNOWN, **no numeric score**.

## Score rule
Numeric score only when: evidence coverage ≥ required heads AND a benefit vector exists AND (future) ScoreContract eligibility. Otherwise `INSUFFICIENT_EVIDENCE` + `?`. Provisional benefit scalar is deterministic/versioned (`benefit-estimator-v1` + `fusion-v1`), never an LLM output.

## Calibration coupling
Heads expose `rawConfidence` + `calibratedConfidence` (nil = UNAVAILABLE). Fusion treats uncalibrated/low confidence as reduced trust; it does not inflate.
