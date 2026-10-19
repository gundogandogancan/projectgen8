# P007 — Live Activity / Dynamic Island Implementation

## Status: ADAPTER IMPLEMENTED + COMPILED (ActivityKit); device run PENDING_EXTERNAL_DEPENDENCY

Dynamic Island is **secondary**; the Pure Bar remains primary per-content truth.

### Implemented + compiling (app target, `Gen8/NativeSurfaces.swift`, `#if canImport(ActivityKit)`)
- `GuardianActivityAttributes` — a **minimal, lock-safe** payload: `surface` (NativeSurfaceState raw), `label`
  (lock-safe), `sequence`. **No Shield rule text, no content character detail** (§24).
- `GuardianLiveActivityAdapter.contentState(...)` — maps a glyph → `NativeSurfaceState`, runs it through the
  headless-tested `LiveActivityUpdatePolicy`, and returns a content state **only when the update is accepted**
  (suppressed/rejected otherwise). `areActivitiesEnabled` reflects `ActivityAuthorizationInfo`.

### Update-ordering & stale safety (§5/§6 — tested in GuardianCore)
- content identity mismatch / out-of-order sequence → rejected,
- no-change / within-debounce → suppressed (no high-frequency spam),
- safety escalation (shield/caution) bypasses debounce,
- stale / Guardian OFF → UNKNOWN/neutral, never a stale positive/safe glyph (`GlyphSurfaceController`, P006C).
- Counters tracked: requested / accepted / suppressed / staleRejected / outOfOrderRejected.

### Not done without a team
Actually starting/updating a real `Activity<GuardianActivityAttributes>` on the Dynamic Island requires the Live
Activity entitlement + on-device run. The adapter + attributes compile; the live push path is device-gated.

### Background/suspension truth (§25)
Live Activities are **OS-managed** once started; the app does not perform arbitrary continuous background analysis.
On background/suspension, in-flight analysis is cancelled/suspended and stale content state is invalidated to UNKNOWN.
