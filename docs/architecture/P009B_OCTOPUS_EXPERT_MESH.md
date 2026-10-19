# P009B — Octopus Expert Mesh (architecture)

**Status:** IMPLEMENTED + LAB TESTED (388 tests green) · **Score display:** OFF (law) · **Date:** 2026-10-19

## What this is

The capability-aware multimodal expert mesh above the locked P009A identity foundation. It answers:
*what is happening, what evidence supports it, which modalities agree/conflict, what remains unknown* —
NOT the personal suitability score (P009C, not started).

## Components (all in `packages/GuardianKit/Sources/GuardianCore/`)

| Component | File | Role |
|---|---|---|
| `GuardianMetaBrainV2` | MetaBrainV2.swift | the exercised router: capability → cache → cheapest-sufficient → thermal → execute → provenance → UNKNOWN |
| `ExpertRegistryV2` + `ExpertHealthRegistryV1` | OctopusRuntimeV2.swift | expert registration, availability truth, p50/p95 health |
| `CapabilityResolverV2` | OctopusRuntimeV2.swift | profile → permitted domains (capability truth, §profiles doc) |
| `ResourceGovernorV2` | OctopusRuntimeV2.swift | thermal routing law + deep-dedupe per (item, domain) |
| `IntelligenceCacheV2` | OctopusRuntimeV2.swift | confirmed-item-only evidence cache; model-version + split invalidation |
| `EvidenceBusV2` | OctopusRuntimeV2.swift | bounded evidence stream with generation stale firewall |
| `ProvenanceLedgerV2` | OctopusRuntimeV2.swift | who produced what, with which model version, under which profile |
| `CalibrationRegistrySkeletonV1` | OctopusRuntimeV2.swift | always refuses score display (P009B law) |
| 10 expert arms | ExpertArmsV1.swift | vision / languageOCR / speech / audioEvent / music / symbol / temporal / safetyEvidence / benefitEvidence / attentionPressure |
| `CrossModalExpertGraphV1` | CrossModalGraphV1.swift | pairwise agree/contradict/stale/unavailable edges; no majority vote |
| `ContentUnderstandingStateV1` / `ContentDNACandidateV2` | CrossModalGraphV1.swift | unified "what is happening" + durable-mint-only-on-confirmed |
| `InputSanitizerV1` + `Tier1IdentityHandoffConsumerV1` | MetaBrainV2.swift | quarantine NaN/∞/negative-ts/malformed/stale handoffs |
| `P009BCorpusV1` | P009BCorpusV1.swift | rights-clear 17-scenario corpus + mesh harness |

## Routing law (implemented, tested)

1. Profile permission (capability truth — never pretend).
2. Registry availability — unregistered/unavailable → explicit `.unavailable` evidence + unknown reason.
3. Cache (confirmed items only; provisional never caches).
4. Thermal gate (see resource doc).
5. Deep dedupe: cost ≥ 5 experts run at most once per (item, domain).
6. Cancellation check before work.
7. Execute; stale-generation results discarded, never attached (`stale-discarded:` reason).
8. Health/bus/cache/ledger bookkeeping; all-modalities-unavailable → UNKNOWN.

## Naming note

The P008-era `CrossModalEvidenceGraphV1` (CrossModalEvidenceGraph.swift) is the frozen concept-level
fuser. The P009B expert-evidence graph is `CrossModalExpertGraphV1` — different layer, kept distinct.

## What this is NOT

- No numeric score, glyph, or motion language (OFF until P009C+P008B calibration).
- No raw media persistence or upload; derived evidence only (`derivedNonReconstructive`).
- No new external model assets (see model/asset audit — Apple system frameworks + project-authored only).
- H1 visual safety dimensions remain UNAVAILABLE (open blocker, carried).
