# P007A — Control / Widget Extension Compile Evidence

**The real WidgetKit extension target now exists and compiles** (closes P007 §3/§7 — an adapter is not an extension).

## Target & product names
- Xcode target: **`GuardianControlExtension`** (productType `com.apple.product-type.app-extension`)
- Product: **`GuardianControlExtension.appex`**
- Extension bundle id: **`com.aymedo.Gen8.GuardianControl`** — PROPOSED placeholder (the app's `com.aymedo.Gen8` is
  UNCHANGED; no portal registration; see P007A_R2_SIGNING_HANDOFF)
- App Group used at runtime: `group.com.aymedo.Gen8` — PROPOSED only (NOT created/registered; the bridge falls back to
  standard defaults in R1)
- Embedded in the app via an "Embed Foundation Extensions" copy-files phase + explicit target dependency.

## Source (real, not a contract)
- `GuardianControlExtension/GuardianControlBundle.swift` — `@main WidgetBundle` combining the control + Live Activity.
- `GuardianControlWidget.swift` — real `ControlWidget` + `ControlWidgetToggle` + `SetValueIntent` (AppIntents), reads/
  writes shared activation, accessibility + availability (`@available(iOS 18.0, *)`).
- `GuardianLiveActivityWidget.swift` — real `ActivityConfiguration` + Dynamic Island regions (compact/minimal/expanded/
  lock-screen), minimal privacy-safe labels, UNKNOWN fallback.
- `GuardianControlState.swift` — shared activation read/write (App-Group-ready, standard fallback).
- `Info.plist` — `NSExtensionPointIdentifier = com.apple.widgetkit-extension`.

## Build commands + results (verbatim, 2026-10-18)
```
# Extension target alone (simulator, no signing)
xcodebuild -project Gen8.xcodeproj -target GuardianControlExtension \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
→ ** BUILD SUCCEEDED **

# Whole scheme (app + embedded extension)
xcodebuild -scheme Gen8 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO build
→ ** BUILD SUCCEEDED **
```
- SDK: iphonesimulator (iOS 26.x). Destination: iPhone 17 Pro simulator. Code signing: disabled.
- One transient failure was hit and fixed honestly: `AppIntentsSSUTraining` (the AppIntents NL metadata post-step) could
  not parse a minimal Info.plist → added the standard `CFBundle*` keys → resolved. Not a "would risk the build" hand-wave.

## Status
`COMPILED_NOT_DEVICE_VERIFIED`. The extension compiles and embeds under the installed toolchain. Appearing in Control
Center / rendering a real Dynamic Island requires signing + on-device run (R2, user-approved). No device claim is made.

## Known R1→R2 note
The app (`Gen8/NativeSurfaces.swift`) and the extension each declare `GuardianActivityAttributes`. For device runtime
these MUST be a single shared type (shared file or framework). Unifying them is an R2 task listed in the handoff.
