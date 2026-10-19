# P009D — Safety + Child Age + Personal Shield Policy Intelligence

**Status:** IMPLEMENTED + LAB TESTED (563/563) · **Score/glyph:** OFF · **Branch:** `phase/p009d` · **Date:** 2026-10-20

## Canonical path (implemented)
`ContentWorldModelV1 → SafetyPolicyEngineV1 → ChildAgePolicyEngineV1 → PersonalShieldPolicyV2 →
PolicyConflictResolverV1 → AdmissionStateCandidateV1 (+ typed reason codes)` — one call:
`AdmissionPolicyPipelineV1.evaluate`.

## Safety dimensions (§3 — truthful statuses, never upgraded; test-asserted)
sensitiveNews = IMPLEMENTED_UNCALIBRATED · fearThreat = HEURISTIC_SUPPORT_ONLY ·
manipulationAttention = IMPLEMENTED_UNCALIBRATED · the other 8 (explicit, violence/gore, self-harm,
drugs, gambling, dangerous, profanity, sexual themes) = **UNAVAILABLE** — they can neither clear nor
convict; corpus families on those dimensions assert FAIL-CLOSED behavior, never fake distinctions.

## H1 (§4)
`HighRiskVisualSafetyRegistryV1`: 4 visual high-risk classes, all `UNAVAILABLE_EVIDENCE_BACKED`
(provider NONE, full record fields). `visuallySafeConclusionAllowed() == false` structurally; the
`H1_VISUAL_UNAVAILABLE` reason code rides on EVERY decision. Strong lexical/audio/world-model risk
still escalates (maxRisk ≥ 0.8 or STRONG_RISK_DOMINANT ⇒ STRONG_PROTECTION).

## Child/age (§5/§6)
Guardian-ATTESTED age only (no image/face API exists in the module — reflection-tested); jurisdiction
registry TR/US/EU v1 (developmental bands: sensitiveNews caution<13/restricted-strong<10, fear
caution<10/restricted-strong<7, manipulation caution<13); **under-13 H1 law**: H1 gap visible on every
decision, aligned→UNKNOWN_REVIEW; parent preference is stricter-only; unsupported jurisdiction/missing
attestation/weak identity fail CLOSED. Source classes separated — developmental policy is structurally
unpresentable as a legal rating (`AgeSuitabilityPolicyV1.legalRatingsIngested == false`). No numeric.

## Shield V2 (§7)
Canonical `concept:`/`entity:` IDs only — non-canonical entries demoted to ADVISORY guesses at the
constructor (can NEVER hard-block; test-asserted). Cross-language purely via taxonomy IDs (TR content ×
one canonical config — tested both directions). Match confidence categorical and separate; local-first
(no cloud field exists).

## Precedence + conflict (§8/§9)
STRONG_PROTECTION > AGE_RESTRICTED > SHIELD_MATCH > CAUTION/AGE_CAUTION/CONFLICT > UNKNOWN/REVIEW >
NEUTRAL (precedence ranks on the enum). Benefit recorded as `BENEFIT_PRESENT_NOT_OVERRIDING`, never
overriding. Unresolved contradictions surfaced. No vote. Admission is CATEGORICAL (no numeric field —
Mirror-tested).

## Sentinels / cache / versions (§15/§17/§18)
6 curated sentinel classes with the standing no-false-safe calibration law (sentinel input never
NEUTRAL — tested). `PolicyDecisionCacheV1` profile-keyed + policy-fingerprint-bound; cross-user lookup
structurally impossible; shield/policy change ⇒ new fingerprint ⇒ recompute from the SAME world model
(no re-understanding — tested). Every decision binds engine/taxonomy/age/jurisdiction/shield/world-model/
mesh versions + freshness.

## Gates (§22) — all test-asserted
Strong-protection-over-benefit; age-restriction-over-content-character; H1-never-visually-safe;
cross-language shield; guess-cannot-hard-block; age-never-inferred; legal/developmental separation;
versioned child policy; no raw data in policy outputs (planted-token test); isolated personal cache;
provenance-bearing reason codes; UNKNOWN/REVIEW first-class; score/glyph OFF.

## TUNE-phase record (pre-freeze, honest)
5 fixes: H1-visibility law (<13 always coded), sensitiveNews strong-restricted band authored at 10,
`deaths/ölümler` exact tokens (supplement r1), 2 annotation authoring corrections. Then frozen;
HELD_OUT 8 / STRESS 4 / OOD 4 run-once failures=0.

## Known limitations
UNAVAILABLE dimensions dominate the child fail-closed surface (honest, not capability); jurisdiction
bands identical across TR/US/EU in v1 (structure supports divergence); shield preferred-topics carry no
ranking effect yet (calibration-phase work); device/in-app §20 run user-gated.
