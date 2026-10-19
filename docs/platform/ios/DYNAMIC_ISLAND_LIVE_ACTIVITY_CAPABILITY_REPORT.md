# iOS Dynamic Island / Live Activity — Capability Report (SPIKE)

**Doc status:** `UNVERIFIED — PENDING LIVE OFFICIAL-DOC CONFIRMATION` · **Phase:** 1 · **Date:** 2026-10-18 · PROMPT 001 §9. Capability-truth rule: do not emulate unsupported behavior; do not claim a false PROTECTED surface (D-0004).

> **Honesty note:** This session's sub-agents are network-sandboxed and I did not fetch live `developer.apple.com` pages this turn. The statements below reflect ActivityKit's documented model as known at the assistant knowledge cutoff (Jan 2026) and are marked **RCOV** (requires current official verification) per Prompt 000 §54. They must be re-confirmed against current Apple docs at implementation time before any claim moves to VERIFIED. No prototype is shipped that depends on unverified behavior.

## Desired Guardian presentation
A minimal, ambient **Pure Bar** status (aligned/caution/unknown via color + non-color cue) surfaced on the Dynamic Island / Live Activity while a controlled Guardian session (e.g., GuardianLab playback) is active — tap to reveal compact score/status, expand for why/protection/evidence.

## Capability assessment (RCOV)
| Aspect | Known model (RCOV) | Implication for Gen8 |
|---|---|---|
| Framework | **ActivityKit** provides Live Activities; Dynamic Island presentations (compact/minimal/expanded) + Lock Screen presentation | Fits a per-session Guardian status surface |
| Start/update/end | Started from the foreground app while active; updated in-app or via ActivityKit push (APNs); ends on completion/timeout | Our GuardianLab session can start + update a Live Activity in-app (no push needed for the local harness) |
| Update latency/limits | Frequent in-app updates while app active; background/remote updates are **budgeted/throttled**; Live Activities have a **max duration** and system may end them | Pure Bar must degrade truthfully when updates pause; **never show stale safe state** (§101) |
| Interaction limits | Limited interactivity (App Intents for buttons on supported OS); not a general overlay | Tap/expand semantics must respect the constrained interaction model |
| Background constraints | Not a continuous background compute surface; no arbitrary wakeups | Aligns with P0-B event-driven doctrine (no polling) |
| Cross-app overlay | **NOT available** — no persistent floating bar over arbitrary third-party apps | **Capability GAP** (§181/§5720): we must NOT claim a universal overlay; GuardianLab is a controlled in-app surface |
| Entitlement/signing | Live Activities require the app to run on device with proper signing/entitlements | Blocked by EXTERNAL_EXECUTION_DEPENDENCY (no team yet, ADR-0003) for on-device validation |

## Decision for PROMPT 001
- **DEFER the on-device Dynamic Island prototype** — it needs device signing (no team yet) and live-doc confirmation. Not a blocker: GuardianLab's Pure Bar is implemented as a **controlled in-app SwiftUI surface** this phase (§8/§313).
- Architecture keeps a `GuardianSurface` presentation abstraction so a Live Activity adapter can be added later without rewriting the app (matches `SocimePlatformAdapter` presentation boundary, §530).
- A compile-safe Live Activity component may be added only after: (a) current Apple docs confirm the update/interaction model, and (b) a signing team exists.

## Action items
1. At implementation time, verify current official docs: ActivityKit, Live Activities, Dynamic Island presentations, update mechanisms + budgets, max duration, App Intents interactivity, background constraints, privacy. Record citations + `last_verified`.
2. Keep Pure Bar surface-agnostic behind `GuardianSurface`.
3. Do not emulate a cross-app overlay anywhere.
