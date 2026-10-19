# PRIVACY MODEL

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §71–§76, §342–§344, §432, §483, §564; Prompt 000 §37, §21, §44.

## Core principles
Explicit consent · data minimization · purpose limitation · least privilege · local-first where appropriate · encryption · retention limits · deletion · export · revoke · auditability · visible permissions. **USER AGENCY > ENGAGEMENT.**

## Non-negotiable defaults
- **Raw capture `RETAIN = FALSE`.** Preferred pipeline: `FRAME → ON-DEVICE FEATURES → DISCARD FRAME` (§71). No default raw-screen archive.
- **No global cache of private content.** Private screens/messages: `GLOBAL_REUSE = DENY` by default (§344, §564). Global ContentDNA is non-personal only.
- **Sensitive Surface Guard** (§72): allowlist-first; pause/deny on banking, password managers, authentication, private messages, health records, private gallery, payment, sensitive form entry. False-negative risk is measured.
- **Visible Guardian state + one-tap pause** always available.
- **Safety data and subscription anti-sharing data are separate** (Prompt 000 §37). Household enforcement is privacy-preserving (coarse signals, not continuous GPS — §483).
- **No hidden chain-of-thought storage** (§91): persist decision + reason-code + evidence + model/version + confidence + action only.

## Data subject rights (all users)
View · correct · export · reset · delete, for goals, topic weights, inferred/explicit preferences, skill estimates, threshold, mode, exploration (§83). Deletion/export must **propagate** across stores (verified: PRI-001).

## Family / child privacy (§73–§76, §432)
- Default parent visibility: safety alerts, category summaries, protection health, screen time, permission requests. **Restricted by default:** full raw browsing history, full raw message contents, exact location history, hidden mic/camera monitoring. No spyware behavior.
- "Share result, not necessarily raw history." Adult raw history default OFF. Teen can see what guardian can see. Consent is logged in the Family Consent Ledger (§75) and is revocable (anti-coercion §548).

## Consent & audit
Every consent records member/viewer, data type, purpose, visibility, grantedAt/revokedAt, jurisdiction basis. Immutable privacy audit trail for critical changes. No PII in debug logs or telemetry (§102, §39 P000).

## Phase-0 status
This is the design baseline. Enforcement is proven by requirements **PRI-001** (retention/deletion), **DVT-001** (data rights), **CHD-001** (child privacy/anti-coercion). No personal data is processed in Phase 0 (no product code).
