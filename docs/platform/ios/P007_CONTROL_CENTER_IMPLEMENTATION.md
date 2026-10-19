# P007 — Control Center Implementation

## Status: LOGIC IMPLEMENTED + COMPILED; extension target + device run PENDING_EXTERNAL_DEPENDENCY

A real WidgetKit **Control** (iOS 18+) that toggles `Gen8 Guardian` from Control Center requires: (a) a widget
extension target, (b) an App Group entitlement, (c) a signing team, (d) on-device run. (a)–(d) are all gated by the
signing team (see P007_DEVICE_AND_SIGNING_ENVIRONMENT). What is done now:

### Implemented + compiling (app target)
- `GuardianActivationBridge` (`Gen8/NativeSurfaces.swift`) — the **shared activation state** a Control extension and
  the app both read/write. App-Group-ready (`group.com.aymedo.Gen8`), falls back to standard defaults when the group
  entitlement is absent. This is the single source of truth the Control toggle would drive.
- `GuardianActivationController` + `NativeSurfaceState` (GuardianCore) — ON/OFF semantics, OFF cancels future Guardian
  work, stale-state handling. Headless-tested (P006 + P007 suites).

### Deliberately NOT added (would break/not-function without a team)
- The `ControlWidget` / `ControlWidgetToggle` / `SetValueIntent` types + a widget extension `@main` bundle. A
  `ControlWidget` only registers from a widget extension; adding that target needs signing + provisioning. We did not
  add a non-functional extension target that would also risk the working simulator build.

### State-safety requirements (met at the logic level, tested)
- ON/OFF backed by `GuardianActivationController` (single source of truth).
- OFF cancels future Guardian work; in-flight work that the OS cannot cancel immediately has its **results discarded**
  (never surfaced after OFF).
- App relaunch / extension-process recreation read the same shared state (bridge).
- Accessibility labels + lock-safe labels via `NativeSurfaceState.lockSafeLabel`.
- Unsupported-OS fallback: the in-app Guardian toggle remains the control (P006 posture).

### To certify (requires the human step)
Set `DEVELOPMENT_TEAM`, choose a unique bundle id, add the widget extension + App Group entitlement, run on the
connected iPhone, then run the P007 §4 Control Center state tests on-device.
