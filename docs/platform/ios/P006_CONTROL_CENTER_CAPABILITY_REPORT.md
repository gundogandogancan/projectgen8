# P006 — Control Center Guardian Control Capability Report

**Doc status:** `RCOV` · **Phase:** 6 · **Date:** 2026-10-18 · PROMPT 006 §2, §4. Verify current Apple docs at implementation time.

## Desired UX
Swipe down → Control Center → **Gen8 Guardian** control → ON / OFF. Toggles product **policy/runtime** state only — it does **NOT** grant cross-app capture iOS does not provide (never claimed).

## API assessment (RCOV)
| API | Status | Min OS (RCOV) | Notes |
|---|---|---|---|
| WidgetKit **Controls** (`ControlWidget`) | RCOV | iOS 18 | Control Center / Lock Screen / Action button |
| `ControlWidgetToggle` | RCOV | iOS 18 | ON/OFF control |
| `StaticControlConfiguration` / `AppIntentControlConfiguration` | RCOV | iOS 18 | control config |
| App Intents / `SetValueIntent` | RCOV | iOS 16 / 18 for controls | toggle action |
| Shared app↔extension state (App Group) | RCOV | — | `UserDefaults(suiteName:)` / App Group entitlement |
| ControlCenter reload | RCOV | iOS 18 | `ControlCenter.shared.reloadControls(...)` |

## Decision
- **GuardianActivationState is implemented now** as the single source of truth (`GuardianActivationController`, tested) — enabled/paused/disabled/temporarilySuspendedBySystem/restrictedByCapability/restrictedByPolicy; OFF fires cancel handlers; relaunch-safe; `canClaimProtection` false when not enabled.
- **In-app Guardian toggle implemented** (GuardianLab) as the fallback and primary driver this phase.
- The **WidgetKit Control extension target + SetValueIntent** is a **device-gated remaining step** (needs iOS-18 baseline decision + App Group entitlement + signing Team, none available). Not faked; documented as ADR candidate.
- **ADR (candidate):** either move app min-OS to the Controls baseline (iOS 18) OR keep older min-OS with the Control conditional. Do **not** silently change deployment target.

## Honesty
No "Protected" claimed when runtime cannot operate. Control extension not yet compiled (no Team/extension target); `GuardianActivationState` + in-app toggle are real and tested.
