# P009A — Octopus Meta-Brain Skeleton

Status: `CONTRACTS + REFERENCE IMPLEMENTATIONS TESTED` (skeleton only — P009B+ fills behavior).
Source: `OctopusBrainSkeletonV1.swift`. Adapters wrap existing healthy subsystems; nothing rewritten for naming.

## Contracts (§12)
| contract | reference impl | role |
|----------|----------------|------|
| `GuardianMetaBrain` | `GuardianMetaBrainV1` | facade: registry + bus + ledger + governor |
| `ExpertRegistry` | `ExpertRegistryV1` | 13 expert domains (Vision, OCR/Language, Speech, Audio, Music, Symbol, Temporal, Safety, ChildAge, Personalization, Calibration, Observation, Surface/Motion) |
| `IntelligenceTaskRouter` | `GuardianMetaBrainV1.route` | capability-gated routing; missing capability → nil → honest UNKNOWN upstream, never faked |
| `EvidenceBus` | `EvidenceBusV1` | bounded derived-summary records per item |
| `ProvenanceLedger` | `ProvenanceLedgerV1` | subject → producer/model/policy/time trace |
| `CapabilityResolver` | `CapabilityResolverV1` | official-capability truth only |
| `ResourceGovernor` | `ResourceGovernorV1` | session economy counters + DEDUPES deep inference: one expensive understanding per (item, domain); duplicates denied → reuse (`testResourceGovernorDedupesDeepInference`) |
| `ModelPackRegistry` | `IntelligencePackLifecycleManagerV1` | see THIN_APP_INTELLIGENCE_PACKS |
| `IntelligenceCache` | `ContentIdentityCacheV1` (identity tier) | one understanding → many cheap decisions |
| `LearningSignalBus` | `LearningSignalBusV1` | consent-gated (global without opt-in rejected) |

## Existing components mapped as the first experts (adapters, §12)
- Surface/Motion → `ShotSegmenterV5` (`boundary-policy-v5`) — registered built-in, no pack required.
- Temporal → `HierarchicalTemporalGraphV1` + grouping engine.
- Safety/Shield → existing `ShieldEvaluatorV2` (unchanged).
Future experts arrive as capability-routed packs (see pack contract); the base app stays usable without them.

## Fast vs deep identity (§9)
Tier 0 (every shot, cheap): timing, compact signatures, chrome/layout continuity, swipe/pan cues, cache lookup.
Tier 1 (ambiguity escalation only, capability-permitting): Vision feature print, OCR fingerprint, speech/audio
continuity, compact embeddings, future VLM. Heavy identity NEVER runs every frame; the governor enforces
one-deep-run-per-(item, domain).
