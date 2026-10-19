# API CONTRACTS

**Doc status:** `CANONICAL` (principles + seed, no impl) · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** PROMPT 000A §7; Bible §98, §323–§324, §334, §337–§339. Prefer explicit, versioned contracts.

## Principles (§98)
explicit versioning · idempotency for side effects · authz by workspace/user/role · structured error taxonomy (maps to FAILURE_TAXONOMY) · request correlation IDs · no opaque `success=true` without state · pagination · freshness + provenance metadata · optimistic concurrency where appropriate. **No raw private content in API payloads.**

## Internal boundary contracts (domain → domain)
Domains communicate via versioned contracts/events only (no shared tables — CORE_DOMAIN_BOUNDARIES). Core contract objects (schemas defined with their domain packages later): `DigitalObservation`, `ContentIdentity`, `ContentDNA`, `TemporalContentGraph/TemporalSegment`, `ContentCognition`, `EvidenceNode`, `ScoreContract`/`ContentAssessment`/`ScoreExplanation`, `AdmissionDecision`, `PersonalAlgorithmProfile`, `PersonalGrowthTwin`, `SubscriptionEntitlement`, `TrustedDevice`, `FamilyRelationship`, `CanonicalSocialPost`, `PublishJob`.

## External provider contracts (Creator surface — RCOV)
Each social/billing provider gets a **capability manifest** (Bible §324, §55 P000) with fields: `provider, auth, scopes, account_types, publish_formats, direct_publish, draft_publish, scheduling, limits, rate_limits, comments, replies, inbox, analytics, webhooks, idempotency, reconciliation, automation_rules, user_confirmation_rules, fallback, last_verified, official_evidence`.
- **UI must not expose unsupported actions** (§55 P000).
- Auth: **OAuth/PKCE + state/nonce**; tokens in secure vault; **account identity firewall** (wrong-account = catastrophic).
- Publish: idempotency mandatory; **reconcile-before-retry**; no private APIs / scraping / cookie bots.
- The §334 provider capability claims (TikTok/YouTube/LinkedIn/Pinterest/X/Bluesky/Snap/Reddit; Instagram/Threads flagged) are **RCOV** — verify current official docs at implementation time with `last_verified`.

## Error taxonomy
Structured errors map 1:1 to FAILURE_TAXONOMY codes; every user-visible error has a safe UX state.

## Phase-0 status
Principles + contract inventory only; no endpoints/clients implemented. First provider chosen in ADR-0011 (PUB-001).
