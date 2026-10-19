# P007C — Live Activity Device Proof + Localization + Developer-Mode Separation

## Dynamic Island root cause (proven on device)
BEFORE: Dynamic Island showed nothing for TWO reasons, both proven on the physical iPhone 14 Pro Max (iOS 26.6):
1. The app **never called `Activity.request`** (adapter computed state but nothing started an Activity) — static proof.
2. Device log: `START error=… Target does not include NSSupportsLiveActivities plist key` → the app Info.plist lacked
   `NSSupportsLiveActivities`, so iOS refused the request.
Device log BEFORE: `areActivitiesEnabled=true activeCount=0` + `START error=NSSupportsLiveActivities`.

## Fix
- Added `INFOPLIST_KEY_NSSupportsLiveActivities = YES` (app, Debug+Release) → generated Info.plist `NSSupportsLiveActivities=true` (verified via PlistBuddy).
- Unified `GuardianActivityAttributes` into ONE canonical shared type (`Shared/GuardianLiveShared.swift`) compiled into
  BOTH the app and the widget extension (added to both Sources phases) — required for the widget to render the app's Activity.
- Added `GuardianLiveActivityController` (real `Activity.request` / `update` / `end`): user-initiated start on Guardian ON,
  debounced updates via the tested `LiveActivityUpdatePolicy` (no per-swipe spam; safety escalation bypasses debounce),
  content-identity change ends old + starts new (no stale positive carried across content), end on Guardian OFF.
- Control Center + app continue to drive the same activation source of truth (`GuardianActivationController` /
  `GuardianActivationBridge`).

## AFTER (device log, stable across runs)
```
GEN8_LA DIAG tag=before-start areActivitiesEnabled=true activeCount=0 hasCurrent=false
GEN8_LA START ok id=D5A3E5DA-… contentID=dev-exercise surface=GUARDIAN_ON activeCount=1 activityState=active
GEN8_LA DIAG tag=after-start areActivitiesEnabled=true activeCount=1 hasCurrent=true
```
→ a real Live Activity of our shared attributes type is **active** on device; the widget extension (installed + process
running, pid confirmed earlier) provides the `ActivityConfiguration` + Dynamic Island regions that render it.

## Honest limit
A headless agent cannot photograph the Dynamic Island. Proof here is OS-reported: authorization enabled, request
succeeded, `activeCount 0→1`, `activityState=active`, rendering extension present. Final visual confirmation (seeing the
island/lock-screen pill) is a human glance. The on-device trigger used the env-gated dev exercise (`GEN8_LA_EXERCISE=1`),
which calls the SAME controller code path as the Guardian-ON toggle.

## Localization (TR/EN)
`Gen8/Localizable.xcstrings` (source en + tr); `tr` added to knownRegions; **`tr.lproj` compiled into the device bundle**
(verified). Language setting System Default / Türkçe / English via `AppSettings` + `.environment(\.locale)`. Internal
canonical reason codes unchanged — only presentation localized (friendly labels via `Present`). Coverage: primary
user-facing strings (Guardian, Short-form/Long-form, My Shield/Kalkanım, glyph/surface labels, rule types/actions/states,
settings, onboarding titles/buttons). NOT yet localized: some long onboarding sentences and the widget extension's static
`displayName`/`description` (English only) — honest gap.

## Developer-Mode separation
`AppSettings.developerMode` (default OFF). Hidden from normal UX, revealed only in Developer Mode: Diagnostics (internal),
P007 Evidence panel, raw reason codes (TEXT_EXACT/MATCH_LOW/NO_SHIELD_ACTION/sf-unknown/INSUFFICIENT_EVIDENCE etc.),
"Use wrong-version TemporalGraph" + Temporal mode, Real preflight. Normal UI shows localized friendly text only.
