# CONTAINER ARCHITECTURE (C4 Level 2) + Target Repo Shape

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §94–§97, §320, §496, §113; Prompt 000 §46; D-0003.

## Architecture stance
**Modular monolith first** (Bible §95): local-first native app with strong modular domain boundaries; cloud control-plane/services only where justified (independent scale, security isolation, data residency, failure isolation, operational ownership). Do **not** start with dozens of microservices. Core domain packages must not import platform UI frameworks (Prompt 000 §32).

## Containers (logical)

| Container | Responsibility | Where | Notes |
|---|---|---|---|
| **Native app shell** (per platform) | UI, Guardian surface (Pure Bar), onboarding, settings | device | iOS/visionOS/macOS first (existing target); others later |
| **Platform Adapter** | capture/observation, presentation surface, player control, family authority, secure storage, device trust, billing, notifications, telemetry | device | Implements `SocimePlatformAdapter` (§530); one per platform family |
| **Browser extension** | page observation + Guardian surface + semantic page filter | browser | MV3/WebExtensions; site adapters versioned independently (§531) |
| **On-device intelligence** | Tier 0–4 stack, Model Router, fast pre-flight, local ContentDNA (L1), personal brain | device | battery/thermal governed (§187–§193) |
| **Domain core (packages)** | pure contracts + deterministic logic (no UI, no provider SDK) | shared | see package list below |
| **Cloud control plane / services** | auth, family, entitlement, content-intelligence, evidence, inference, sync, calibration, publishing, workers | cloud | only where justified; isolated failure domains (§43 P000) |
| **Shared intelligence network** | non-personal ContentDNA (L2 edge / L3 cloud), global calibration, model registry | cloud/edge | rights-gated; no private content |

## Target monorepo shape (DOCUMENTED, not materialized in Phase 0)
Per Prompt 000 §46 — "create only what Phase 0 requires; document future structure separately." Phase 0 created only `docs/…`. Future structure:
```
/ README.md CLAUDE.md
  docs/ (exists)
  apps/        ios/ android/ web/ extension/ macos/ windows/ linux/ tv/
  packages/    contracts/ domain/ capability-registry/ observation/ identity/
               content-dna/ temporal-graph/ cognition/ semantic-shield/ protection/
               positive-exposure/ spiritual-lens/ personal-algorithm/ growth-twin/
               family-policy/ score-kernel/ admission-controller/ entitlement/
               device-trust/ model-router/ resource-governor/ provenance/ telemetry/
               platform-adapter-sdk/ extension-sdk/
  services/    api/ auth/ family/ entitlement/ content-intelligence/ evidence/
               inference/ sync/ calibration/ publishing/ workers/
  evals/       golden/ adversarial/ multilingual/ temporal/ family/ scoring/ calibration/
  infra/  scripts/  tests/
```
**Existing code:** the current Xcode app (`Gen8/` + `Gen8.xcodeproj`) lives at the repo root today. Relocating it to `apps/ios/` and adopting Swift 6 language mode is **ADR-0002** (deferred; not executed in Phase 0, which forbids product-code moves).

## Local vs cloud split (Bible §96)
- **Local preferred:** consent state, personal profile, fast feature extraction, cache lookup, fast score components, sensitive-surface handling, user threshold, lightweight personal adaptation.
- **Cloud when justified:** heavy multimodal inference, evidence retrieval, shared ContentDNA, global calibration, model registry, cross-device sync, specialist models.
- **Privacy class gates eligibility** — private content never leaves device for global reuse by default.

## Data storage principles (Bible §97)
Relational primary for transactional truth; vector index only for real semantic use; graph begins relationally; immutable audit events for critical changes; encrypted local store for device-sensitive data; retention by purpose; delete/export propagation. Specific DB/provider choices are Phase-1 ADRs (no provider invented in Phase 0).
