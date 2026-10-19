# P009C — Content World Model (architecture)

**Status:** IMPLEMENTED + LAB TESTED (497 tests green) · **Score/glyph:** OFF · **Date:** 2026-10-19

## Canonical path (implemented exactly as mandated)

`MULTIMODAL EXPERT EVIDENCE → CROSS-MODAL GRAPH → SEMANTIC EPISODES → TOPICS/ENTITIES/INTENTS →
EVENT/STATE MODEL → EVIDENCE WEIGHTING → CONTRADICTION RESOLUTION → CONTENT WORLD MODEL → DNA FINALIZATION`

Entry: `EpisodeObservationV1` (per-segment mesh route output — derived evidence only, generation-stamped).
Exit: `ContentWorldModelV1` (identity status, episodes, ranked multi-topics + transitions, entity graph,
intent hypotheses + ambiguity, event/cause-hypothesis graph, narrative labels/motifs, monotone maxRisk,
safety/benefit/manipulation/emotional evidence, contradiction resolutions, modality coverage, 8-axis
uncertainty + knowledge state, OOD, bounded provenance, freshness, model/taxonomy versions, readiness).

## Components (all 16 §31 files in `Sources/GuardianCore/`)

ContentWorldModelV1 · WorldModelBuilderV1 (the assembly law) · SemanticEpisodeV1 (+merge, revision) ·
TopicGraphV1 (+SemanticTaxonomyV1 TR+EN canon `p009c-taxonomy-v1`) · EntityGraphV1 · IntentGraphV1 ·
EventStateGraphV1 · NarrativeTimelineV1 · ContradictionResolverV1 · EvidenceWeigherV1 ·
SemanticUncertaintyModelV1 · WorldModelCacheV1 · ContentDNAFinalizerV1 · WorldModelProvenanceV1 ·
EmotionalSensitiveLoadV1 · WorldModelPrivacyClassV1 (+WorldModelPersistenceLawV1).

## Core laws (all test-asserted)

- Historical strong risk is monotone (`registerRisk`); recovery is OBSERVED, never an eraser.
- Context qualifiers (quote/satire/educational/fiction) qualify lexical-only evidence; they can never
  erase strong MULTIMODAL risk (`STRONG_RISK_DOMINANT`).
- No majority vote anywhere; correlated evidence collapses to ONE independence family.
- Intent is hypothesis with ambiguity; entities are non-identifying; causality is always speculative.
- UNKNOWN over false certainty (6 knowledge states); readiness requires SEMANTIC (non-temporal) strength.
- Segment-scoped mesh routes (`cacheEligible=false`, per-(item,shot,domain) lease) — a shot moment is
  never served from the per-item cache; default mesh behavior byte-identical.
- Not personalized; no score; no user-facing verdict; no glyph.
