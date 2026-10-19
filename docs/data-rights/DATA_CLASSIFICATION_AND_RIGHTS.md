# DATA CLASSIFICATION & RIGHTS

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §44(P000 Prompt), §348, §349, §564, §621; Prompt 000 §44.

## Classification
| Class | Examples | Default handling |
|---|---|---|
| **RAW_SENSITIVE** | screen frames, audio, private messages, health/banking surfaces | ephemeral; `RETAIN=FALSE`; on-device features then discard; never globally cached |
| **PERSONAL** | goals, Growth Twin, skill/knowledge, preferences, feedback | local-first; user rights (view/correct/export/reset/delete); encrypted; `GLOBAL_REUSE=DENY` |
| **PERSONAL_DECISION** | a user's score/admission/exclusion outcomes | personal; not global truth (§85, §270) |
| **NON_PERSONAL_CONTENT_INTELLIGENCE** | ContentDNA (identity, topics, claim map, features) for public/permitted content | may be shared/cached if rights allow |
| **ACCOUNT/ENTITLEMENT** | identity, subscription, device trust | sensitive; minimal; separate from safety data |
| **FAMILY** | roles, relationships, consents, child data | sensitive; consent-ledgered; anti-coercion |
| **OPERATIONAL** | telemetry, metrics (no raw private content) | internal; no PII |

## Rights state (before any cross-user reuse — §564, §348)
Track for each reusable item: `source · visibility · platform · rights_state · derived_feature_rights · retention · training_permission · deletion/takedown · provenance · freshness · content_version`.

Rule: **Private content ⇒ `GLOBAL_REUSE = DENY` by default.** Only `NON_PERSONAL_CONTENT_INTELLIGENCE` with permitted rights enters the shared intelligence network.

## Training / learning (Bible §4.16, §68, §270)
No private user activity enters a global training pool without explicit consent. Personal adaptation is local, bounded, reversible. Shared intelligence is privacy/rights-gated aggregate. Global model evolution is governed (shadow→canary→rollback). **Self-improving, not self-governing.**

## Deletion / takedown propagation (§349)
Deletion and takedown requests propagate across device, cache, shared ContentDNA, and derived features. Export is available. Verified by **DVT-001** and **PRI-001**.

## Shared content rights registry
A `rights & provenance registry` (§348) governs what may be reused; entries carry `last_verified` + evidence. No cross-user reuse without a rights entry. (Materialized as a package/service in later phases.)

## Phase-0 status
Design baseline; no data processed. The non-personal/personal boundary is enforced architecturally in `CORE_DOMAIN_BOUNDARIES.md` (rule 4) and `CONTAINER_ARCHITECTURE.md` (local/cloud split).
