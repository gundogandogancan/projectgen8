# SCORE CONTRACT FRAMEWORK

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §49–§53, §50, §501, §629, Appendix A; Prompt 000 §17, §S. Decision: **D-0005** (deterministic fusion; LLM never emits a final score).

## Rule
> **No ScoreContract → no production numeric score.** An LLM/model may output components, labels, evidence and confidence; the **final PBS is produced by deterministic, versioned fusion** under a registered ScoreContract. Same inputs + same versions ⇒ same final score (reproducibility is a P0 demo criterion, Bible App G.15).

## Score states (Bible §629; Prompt 000 §17)
`VERIFIED_FAST` · `PROVISIONAL_FAST` · `DEEP_VERIFIED` · `INSUFFICIENT_EVIDENCE` · `STALE` · `CONFLICTING`.
If insufficient ⇒ show `?`. Never fabricate precision. **Confidence is separate from the score** (§52).

## When a numeric score is allowed (Prompt 000 §17)
identity sufficiently known · minimum signal coverage met · score version known · model versions known · Personal Algorithm version known · confidence threshold met · no critical unresolved contradiction. Otherwise: no number.

## ScoreContract schema (Bible §50, Appendix A)
```yaml
scoreId: string
version: semver
constructDefinition: string
measures: [string]
doesNotMeasure: [string]
requiredInputs: [string]
components: [ScoreComponentDefinition]
formulaSpec: string            # deterministic, versioned
missingDataPolicy: string      # missing != zero (§4.6)
normalizationPolicy: string
confidencePolicy: string       # separate from score
domainCalibrationPolicy: string
personalCalibrationPolicy: string
knownBiases: [string]
validationDatasetRefs: [string]
acceptanceThresholds: {metric: number}
lastValidatedAt: date|null
rollbackVersion: string|null
```

## Component families feeding PBS (Bible §49)
Intrinsic (ContentQuality, EvidenceQuality, InformationDensity, PracticalUtility, Novelty) · Personal (GoalFit, SkillFit, PersonalRelevance, DevelopmentDelta, ModeFit) · Human Value (LearningValue, CriticalThinking, Creativity, MeaningfulEntertainment, WellbeingFit, AttentionEfficiency) · Risk (ManipulationRisk, ToxicitySignal, UnsupportedHighRiskClaim, RepetitionPenalty, ExcessiveStimulation, Scam/Deception) · Trust (Coverage, IdentityConfidence, ModelAgreement, EvidenceConfidence, Freshness, CalibrationConfidence).

## Separate from PBS
**Personal Protection Status (GREEN/AMBER/RED/GREY)** is a distinct output (§148), not merged into PBS. The Admission Controller consumes both under deterministic precedence (ADR-0007).

## Phase-0 status
Framework + PBS v0.1 contract skeleton only (`PBS_v0.1.yaml`). **No domain calibration constants invented** (Prompt 000 §S). Constants are derived in the Calibration Lab (VAL-001).
