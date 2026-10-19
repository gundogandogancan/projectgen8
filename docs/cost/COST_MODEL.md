# COST MODEL

**Doc status:** `CANONICAL` (formulas/placeholders) · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §61(P000), §86, §261, §308–§310, §363, §518; Prompt 000 §61.

**Rule:** Do **not** invent prices. All numbers are computed later from measured evidence. This document defines the cost *structure and formulas*, not values.

## Cost drivers (Bible §61 P000, §363)
inference · embeddings · transcription · storage · CDN · bandwidth · database · social APIs · observability · support · fraud · billing/store fees.

## Per-decision model
```
cost(content_item) =
    cache_lookup_cost
  + P(miss) * ( fast_path_cost + P(deep) * deep_path_cost )
  + storage_amortization
  - reuse_savings(ContentDNA shared-cache hit)

fast_path_cost  = Σ(model_invocation_i * unit_cost_i)  // smallest sufficient (router order)
deep_path_cost  = transcript + source-verification + specialist models (async, not blocking)
```
Router order drives cost down: `NO_AI → DETERMINISTIC → CACHE → CLASSICAL_ML → SMALL_LOCAL → LOCAL_FOUNDATION → PRIVACY_CLOUD → SPECIALIST_CLOUD → HEAVY_REASONING → HUMAN` (§86).

## Figures to compute from evidence (Bible §61 P000)
- fresh short-form cost
- cached-decision cost
- fresh long-form cost / hour
- reused long-form cost / hour
- monthly cost per active user
- family-plan cost
- creator cost

## Content-reuse economics (§288, §309)
Popular content amortizes fresh-analysis cost across many users via shared **non-personal** ContentDNA; personal scores recomputed locally (cheap). Target: `CLOUD_COST_PER_REUSED_DECISION << CLOUD_COST_PER_FRESH_ANALYSIS` (measured, not assumed).

## Energy cost (device) (§261, §36 P000)
`DEVICE_ENERGY_PER_DECISION` measured per mode (ECO/BALANCED/MAX) on the lowest supported device. Never claim "zero battery impact."

## Pricing decision gate (§310)
Price is set **only after** unit economics are measured. Plans (Personal/Family/Creator/Business) and the 7-day trial are structural; amounts are a later decision. Privacy/security essentials are never paywalled (§108). No private-activity ad targeting.

## Phase-0 status
Formulas only. Real figures produced by **COST-001** (fresh vs reused) + **OPS-001** (energy) after benchmarking.
