# SCREEN / STATE INVENTORY

**Doc status:** `CANONICAL` (inventory) · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** PROMPT 000A §12; Bible §104–§107, §157, §204, §321. Every surface must implement the mandatory state set (DESIGN_SYSTEM_CONSTITUTION §states). Priority: P0 / P1 / later. iOS-first (D-0011).

| Surface | Priority | Notes |
|---|---|---|
| Splash / launch | P0 | fast launch (P0-B) |
| Onboarding / My Goals | P0 | TWIN-001 |
| Account / Auth | P0 | SEC-001; OAuth |
| Permissions (capture/notifications/family) | P0 | capability-truthful; sensitive-surface consent |
| **Guardian — Pure Bar (default)** | P0 | UX-001; L0 |
| Score detail ("Why this score") | P0 | SCO-002; L1/L2 |
| Temporal Heatmap + skip controls | P0 | TMP-001/002; L3 |
| My Algorithm (Personal Algorithm + threshold) | P0 | PAI-001 |
| Growth Twin (inspect/correct/reset/export/delete) | P0 | TWIN-001; user rights |
| Semantic Shield (exclusions) | P0 | PROT-002 |
| Protection status (GREEN/AMBER/RED/GREY) | P0 | PROT-001 |
| Positive Exposure settings | P1 | §421, §439 |
| Spiritual Wellbeing Lens settings | P1 | §425; firewall-bounded |
| Privacy / Data sources / Delete / Export | P0 | PRI-001 |
| Subscription / 7-day trial / paywall | P0 | ENT-001; honest |
| Family dashboard / members / visibility / consent | P0(core)/P1 | FAM-001 |
| Child mode / pairing / requests-approvals | P0 | CHD-001; anti-coercion |
| Devices / trusted devices / revoke | P0 | ENT-001 |
| Household / Travel / Away mode | P0 | HSH-001 |
| Settings (display mode, motion, per-device) | P0 | §609 |
| GuardianLab (internal harness UI) | P0 (internal) | D-0011; not consumer feed |
| **Social Command:** Home / Inbox / Create / Calendar / Insights | P1→ | §7 nav |
| Publish center + job states | P1 | PUB-001 state machine |
| Listening / Reports / Team-Approvals | P2 | §7 |
| Creator bridges (Learn→Create, Inspiration) | P2 | §106 |
| Weekly Impact / Digital Coach | P1 | §80, §104 |

## Universal state requirement
Each surface above implements: normal · loading · empty · error · offline · degraded · permission-denied · insufficient-data · low-confidence(`?`) · stale · conflicting · retry · recovery · success · undo · a11y · localization. **No stale Protected state anywhere.**

## Phase-0 status
Inventory only; no screens built. Drives UX-001/UX-002/ACC-001 and the design system.
