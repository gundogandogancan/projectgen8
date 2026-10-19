# P009A — Network Intelligence Flywheel

Status: contracts `TESTED`; honest evidence class (§30): **`LOCAL_LEARNING_IMPLEMENTED` is NOT yet claimed in full** —
what exists today is the SIGNAL CONTRACT + consent-gated bus + local cache reuse. See evidence classes below.
Permanent doctrine: **EVERY USER IMPROVES GEN8** — locally by default, globally only privacy-gated.

## LOCAL loop (default, §15)
The user's own Gen8 improves from: ContentDNA/cache reuse (implemented: `ContentIdentityCacheV1`), explicit
corrections, Shield preferences, repeated interests, local FP/FN feedback, local disagreement, local latency history,
enabled personal history. **Raw private content stays local by default.**

## GLOBAL loop (privacy-gated, §15)
Global improvement may use ONLY: privacy-preserving derived telemetry, aggregate disagreement, aggregate FP/FN,
opt-in correction labels, rights-clear eval data, latency/resource statistics, federated/secure aggregation and
DP-style aggregate metrics where appropriate. FORBIDDEN: silent screenshot/video/audio upload; treating viewing
history as unrestricted training data.

## `LearningSignalV1` (§16) — enforced by construction
Fields: signalType, derivedFeatureClass, scope (LOCAL/GLOBAL_AGGREGATE), consent (DEFAULT_LOCAL/OPT_IN_GLOBAL),
privacyClass, model/policy versions, outcome, correctionLabel, confidence, latency, locale, capability bucket,
retentionDays, aggregationEligible. **No raw-media payload field exists**; `testLearningSignalNoRawMedia` structurally
asserts no Data/byte fields. `LearningSignalBusV1` REJECTS global-scope signals without opt-in consent (tested).

## Controlled evolution (§17) — no self-rewriting production brain
`EvolutionCandidateV1` enforces the canonical order: CANDIDATE → OFFLINE_EVAL → SHADOW → CANARY → CALIBRATION →
SAFETY/PRIVACY/RESOURCE GATE → SIGNED_RELEASE → MEASURING, with rollback/kill always permitted and **no SHADOW
without offline-eval evidence** (`testControlledEvolutionPipeline`). Contracts cover candidate version, eval evidence
ref, canary cohort, rollback, kill switch.

## §30 honest evidence classes (current)
| class | status |
|-------|--------|
| LOCAL_LEARNING_IMPLEMENTED | PARTIAL — cache-reuse loop + signal contract implemented; correction-driven local improvement not yet wired to models |
| GLOBAL_SIGNAL_COLLECTION_IMPLEMENTED | NO — bus exists, no collection endpoint |
| FEDERATED_OR_AGGREGATE_LEARNING_EXPERIMENTAL | NO |
| GLOBAL_MODEL_IMPROVEMENT_PROVEN | NO |
Only the demonstrated class is claimed. No "self-improving" claim is made.
