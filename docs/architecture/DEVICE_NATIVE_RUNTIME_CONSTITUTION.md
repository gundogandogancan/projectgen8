# DEVICE-NATIVE RUNTIME CONSTITUTION (P0-B)

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** PROMPT 000A §10; Bible §18, §84, §183–§218, §235, §256–§263, §553–§556. Companion to `DEVICE_RESOURCE_BUDGETS.yaml` + `PRE_EXPOSURE_SLO.yaml`.

# THE GUARDIAN MUST FEEL LIKE PART OF THE DEVICE.
**ALWAYS AVAILABLE, NOT ALWAYS EXPENSIVE.** P0-B is a co-equal release gate with P0-A (D-0012).

## Architectural rules (binding)
1. **Change-driven, not frame-driven by default.** Continuous perception ≠ continuous heavy inference. Pipeline: `RAW STREAM → CHANGE DETECTOR → CONTENT BOUNDARY → KEYFRAME SAMPLER → IDENTITY/CACHE CHECK → FAST ANALYSIS → (optional) DEEP ANALYSIS` (§18).
2. **Cache-first.** Identity + L1/L2/L3 cache + ContentDNA reuse before any fresh compute (§85, §499).
3. **Local-first where quality permits.** Cloud only when it materially improves the decision and privacy class allows (§96).
4. **Bounded compute + deadline-aware inference.** Every operation carries latency/cost/battery/thermal/privacy/accuracy budgets; the EarlyExitGovernor stops when further work won't change the decision (§86, §235, §627). "Intelligence attack ≠ unbounded compute" (§235).
5. **Early exit.** Deep work runs **only when it changes the decision** (§107/PROMPT 000A §1).
6. **Adaptive model routing.** Smallest sufficient intelligence; hardware accelerators where appropriate; route by device state (§33 P000, §188, §262).
7. **Adaptive sampling.** Governed by thermal/battery/low-power/foreground-background/network/cached-identity (§18 governor inputs).
8. **Safe suspend/resume.** Clean suspension; on resume, never present stale state; re-establish coverage truthfully.
9. **No stale state.** Never show a stale safe/green/Protected state; degraded ⇒ caution/unknown/limited-coverage, truthfully (§101, §210).
10. **Low-power behavior.** Downgrade to ECO; cache-only where possible; pause non-essential capture.
11. **Thermal behavior.** Downgrade on thermal pressure; suspend heavy inference when thermal-critical.
12. **Background constraints.** Respect each OS's background execution model; minimize wakeups/churn; charging/idle for maintenance windows (§263).
13. **Offline behavior.** Preserve Personal Algorithm, Semantic Shield, local cache, micro-models, family policy, entitlement grace offline; one outage ≠ total collapse (§43 P000, §553).
14. **Minimal network.** Cache-first; dedup before compute (§397); bounded bytes-per-decision.
15. **Ephemeral raw media.** `FRAME → ON-DEVICE FEATURES → DISCARD FRAME`; bounded raw-frame buffers; no default archive (§71, §344).
16. **User-visible coverage truth.** The surface always honestly reflects what is/was analyzed and current coverage; capability tiers C5–C0 govern claims (D-0004).

## Four-tier on-device intelligence stack (Bible §187)
`Tier 0 deterministic rules/cache → Tier 1 classical ML / embeddings → Tier 2 small local models → Tier 3 local foundation → Tier 4 cloud (privacy/specialist/heavy, gated)`. Default stays at the lowest tier that meets quality; escalation lowers confidence budget and respects deadlines.

## Resource governors (Bible §189–§193)
Device Health · Battery (ECO/BALANCED/MAX) · Thermal · Memory/Storage · Network governors continuously adjust sampling, model tier, queue depth and maintenance windows against `DEVICE_RESOURCE_BUDGETS.yaml`.

## Verification (P0-B)
Proven by **OPS-001** (battery/thermal) + **OPS-002** (idle/memory/wakeups/launch/UI) on the lowest supported device; dual-evidence DoD (D-0016). No "zero cost" claims; goal is **no material user-perceived degradation, measured.**
