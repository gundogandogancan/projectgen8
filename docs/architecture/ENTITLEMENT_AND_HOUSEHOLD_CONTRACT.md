# ENTITLEMENT & HOUSEHOLD CONTRACT

**Doc status:** `CANONICAL` (contract, no billing code) · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** PROMPT 000A §11; Bible §301–§312, §464–§488, §567; Prompt 000 §23–§24. Requirements: ENT-001, HSH-001.

## Principles
- **Entitlement is account-level, not device-level.** It follows the account across multiple trusted devices.
- **Provider-neutral billing abstraction** (`BillingAdapter`): App Store (StoreKit), Google Play, other stores, TV billing — behind one entitlement interface (§304). No billing implementation in Phase 0.
- **Guardian authority ≠ billing ownership** (§486; Prompt 000 §19). Paying for a plan does not grant guardian control.
- **Privacy/security essentials are never paywalled** (§108). **No private-activity ad targeting.**

## Plans & trial
| Plan | Scope |
|---|---|
| Personal | single account, multiple trusted devices |
| Family | household members + roles, shared policy |
| (Creator / Business) | later commercial tiers (§307, pricing gated) |
| **7-day trial → paid** | `SubscriptionEntitlement` state machine (§305, §481) |

Pricing amounts are **not set** until unit economics are measured (§310; COST_MODEL).

## Entitlement state (schema intent — §305)
`SubscriptionEntitlement { accountId, plan, state(TRIAL/ACTIVE/GRACE/EXPIRED/REVOKED), trialEndsAt, trustedDevices[], provider, lastVerifiedAt }`. Grace state on transient store/network failure; never hard-lock safety features during billing uncertainty (fail-safe).

## Device trust (§465)
`TrustedDevice { deviceId, cryptoIdentity, addedAt, lastSeen, trustState }`. Device revoke supported. Entitlement checks never cause a **cross-user entitlement leak** (hard stop §520).

## Household trust (anti-sharing WITHOUT surveillance — §468–§471)
Signals: trusted device, family membership, device cryptographic identity, household anchor, **coarse region/country** consistency, concurrent-use anomaly, impossible travel, travel/away mode, repeated remote-use patterns.
- **No blind `>100 km = ban`.** 100 km is a **risk bucket**, never an auto-ban (§471). 
- **Precise continuous GPS history is NOT the default** anti-sharing mechanism (§24 P000; coarse signals only).
- **Travel Mode** (§472) and **Family Member Away Mode** (§473) are first-class.
- Household re-verification (§474); concurrent-use policy (§475); sharing-risk states (§476); entitlement challenge flow (§477).

## Privacy separation (§483; Prompt 000 §37)
Subscription anti-sharing data is **separate** from safety/content data. Household enforcement is privacy-preserving. **Adult privacy separation** maintained; adult raw history default OFF.

## Resilience (§362)
Store outage → grace; cross-device policy sync conflicts resolved deterministically (§361, §479); refund/revoke handled; abuse engine (§482) uses coarse signals only.

## Phase-0 status
Contract only. Proven by ENT-001 (account entitlement + trial + revoke, no cross-user leak) and HSH-001 (household trust without GPS-ban; travel mode). Billing provider choice is a later ADR; StoreKit/Play trial-offer capabilities are **RCOV** (capability matrix).
