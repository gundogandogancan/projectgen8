# SYSTEM CONTEXT (C4 Level 1)

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §94, §320; Prompt 000 §O.

Gen8 sits between the user, the content/platforms they already use, and official data/model/billing providers. It observes **permitted** content, understands it, protects/scores it against the user's own policy, and (for creators) helps publish — **one brain, many native bodies.**

## Actors / external systems

| Actor / system | Relationship to Gen8 | Trust | Notes |
|---|---|---|---|
| **Individual user** | Primary. Defines goals, Personal Algorithm, threshold, Semantic Shield; sees Pure Bar; gives feedback | Owner of own data | USER AGENCY > ENGAGEMENT |
| **Family: guardian / teen / child** | Guardian pairs child devices; teen autonomy preserved; anti-coercion | Verified guardian authority | Billing ≠ authority (§19 P000) |
| **Creator (SOCIME surface)** | Consume→learn→create→publish loop | User | Reuses the impact chain (§78) |
| **Operating systems** (iOS/iPadOS/macOS/visionOS, Android, Windows, Linux, ChromeOS, tvOS/AndroidTV/FireOS/Tizen/webOS/Roku, watchOS/WearOS, XR) | Provide capture/presentation/family/billing/thermal APIs | Platform policy authority | Capability tiers C5–C0; verify current docs (§54 P000) |
| **Browsers** (Safari/Chromium/Edge/Firefox/Brave/Opera) | Extension host for page observation + Guardian surface | Platform policy | MV3/WebExtensions; min permissions (§31 P000) |
| **Official content/data sources** (platform APIs, data-portability exports, user import, first-party player) | Permitted observation + identity | Official only | No scraping/private API/cookie bots |
| **Social providers** (publishing/inbox/analytics) | OAuth-connected accounts for Creator surface | Delegated via OAuth/PKCE | §334 capabilities need reverification |
| **Billing providers** (App Store/Play/other-store/TV) | Subscription + 7-day trial | Store authority | Provider-independent entitlement abstraction (§304) |
| **AI model providers / local models** | Inference under Model Router | Signed, versioned | Smallest sufficient; approved frontier fallback only |
| **External evidence sources** | Claim/evidence verification | Rights-tracked | Freshness + lineage (§38) |

## Context boundaries (what Gen8 does NOT do)
- Does not control or claim to control native third-party feeds (warn/analyze only on native surfaces — §234, §47).
- Does not retain raw screen content by default; does not globally cache private content.
- Does not let AI deploy its own policy/weights; final actions are deterministic + policy-governed.
- Does not optimize for screen time.

## Primary data flows (high level)
```
user + permitted source → observation → boundary → identity → ContentDNA/cache
   → fast cognition + protection + personal fit → ScoreContract fusion (PBS) + protection status
   → admission decision (pre-exposure where possible) → Pure Bar presentation + explanation
   → user feedback → outcome/calibration → controlled evolution
creator: consume signals → idea → compose → platform variants → publish → reconcile → learn
family: guardian policy → child/teen admission + protection → consent-bounded visibility
```
Detailed container view: `CONTAINER_ARCHITECTURE.md`. Domain ownership: `CORE_DOMAIN_BOUNDARIES.md`.
