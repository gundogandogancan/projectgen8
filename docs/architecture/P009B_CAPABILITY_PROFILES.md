# P009B — Capability Profiles (capability truth)

**Source of truth:** `CapabilityResolverV2.permittedDomains(for:)` in OctopusRuntimeV2.swift. Tested in
`testProfileCapabilityTruth`.

| Profile | Permitted expert domains | Rationale / evidence |
|---|---|---|
| `EXTENSION_FAST_TIER0` | `temporal` only | Measured truth (Phase B Outcome C): Tier-0 visual channels materially overlap SAME vs NEW on real content. Extension does boundary sensing + provisional identity + temporal interaction ONLY. No semantic experts in the extension. |
| `EXTENSION_TIER1_LITE` | **empty** | UNAVAILABLE until device-proven (memory/thermal budget proof does not exist). Never assumed. |
| `APP_FULL_TIER1` | all 10 domains | In-app analysis of user-provided/owned media; full mesh. |
| `FUTURE_SHARED_TIER1` | **empty** | BLOCKED (no OS mechanism exists for cross-process shared Tier-1). Contract-only. |

## Laws

- A profile that is not device-proven exposes NOTHING. Capability is never inherited, assumed, or
  "temporarily enabled for testing".
- Tier-0 provisional identity can never admit semantic conclusions; semantic evidence attaches only to
  items routed under `APP_FULL_TIER1` (and caches only once the item is confirmed).
- Requests outside the profile return `profile-forbids:<domain>` unknown reasons — honest refusal, not
  silent drop.
