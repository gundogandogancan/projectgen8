# APPLE CAPTURE STRATEGY — R3 (Background Island Capability)

Status: EVIDENCE-BASED. Author: GEN8 R3 implementation engineer. Date: 2026-10-26.
Sources: the two offline Apple JSON docs the main session downloaded
(`/tmp/apple_sck_ios.json` = "Capturing screen content on iOS"; `/tmp/apple_ak_push.json`
= "Updating Live Activities with ActivityKit push notifications"). Anything not grounded
in those files or in the repo is marked [UNVERIFIED].

---

## 1. What the iOS ScreenCaptureKit article REALLY documents (from `apple_sck_ios.json`)

The article is Apple **sample code** titled "Capturing screen content on iOS". Grounded facts:

- **Platform availability:** every platform entry reads `introducedAt: "27.0"` — iOS 27.0,
  iPadOS 27.0, Mac Catalyst 27.0, Xcode 27.0. The Note states verbatim: *"This sample
  requires a device running iOS 27 or later."*
- **Picker / stream API surface it uses:**
  - `SCContentSharingPicker` — system content-sharing picker. Two entry points:
    `present()` (full display) and `presentForCurrentApplication()` (in-app only).
  - `SCContentSharingPickerObserver` — delivers the chosen `SCContentFilter` via
    `contentSharingPicker(_:didUpdateWith:for:)`; the sample starts the stream from there.
  - `SCContentSharingPickerConfiguration` — toggles mic / (in-app only) camera controls.
  - `SCStream` + `SCStreamConfiguration`; screen frames via an output of type
    `SCStreamOutputType.screen`; `startCapture()` is async.
  - Outputs: `SCRecordingOutput` (MP4 to file), `SCClipBufferingOutput` (≤15 s rolling
    buffer, exported on demand), `SCVideoEffectOutput` (in-app camera overlay).
- **Background capture:** the sample declares **two** `UIBackgroundModes`:
  `screen-capture` (so the stream *survives backgrounding for full-display capture*) and
  `audio` (so the mic tap keeps producing samples). This is the documented mechanism by
  which an SCStream full-display capture continues while the app is not frontmost.
- **Permissions:** runtime camera + add-only Photos (`NSCameraUsageDescription`,
  `NSPhotoLibraryAddUsageDescription`, `PHAccessLevel.addOnly`). A related entitlement,
  `com.apple.developer.persistent-content-capture`, is cross-referenced (VNC-style
  persistent screen access) but the sample itself relies on the background modes.

**Net:** iOS 27 ScreenCaptureKit CAN, per Apple's own documentation, present a system
picker for **full-display** capture and keep an `SCStream` running in the background under
the `screen-capture` background mode — exactly the "user is in another app" scenario GEN8
targets. This is materially stronger than ReplayKit's broadcast-extension model for our use.

## 2. Installed SDK vs the documented APIs → capability verdict

- Repo environment facts (CLAUDE.md §8, dated 2026-10-18): **Xcode 26.6 · iOS 26.4/26.5
  SDK/simulators**. CLAUDE.md "north star" assumes iOS 26.x.
- `xcrun --sdk iphoneos --show-sdk-version` could NOT be executed by the R3 agent — the
  sandbox DENIED the command (`xcrun` is not an allowed tool in this agent's shell). So the
  SDK version is taken from the repo's own authoritative environment record (CLAUDE.md §8),
  not re-measured. [SDK re-measurement: BLOCKED — see §6.]
- The documented ScreenCaptureKit iOS symbols are `introducedAt 27.0`. **The installed SDK
  (iOS 26.x) predates them.**

### Verdict: `UNAVAILABLE_ON_INSTALLED_SDK` → `NOT_DONE` (no prototype possible)

No capability-gated prototype was built. The mandate gates the prototype on the installed
SDK *really* exposing the APIs (verified by a `#if canImport(ScreenCaptureKit)` + `@available`
compile probe). On an iOS 26.x SDK:
- `@available(iOS 27, *)` guards would compile but the symbols
  (`SCContentSharingPicker.presentForCurrentApplication()`, `SCStreamOutputType.screen` on
  iOS, the `screen-capture` background mode semantics) are **not present in the 26.x SDK**,
  so a real stream cannot be constructed or exercised.
- Building a stub that merely *names* the types behind an unavailable guard would be
  dead code that never runs and proves nothing — the mandate explicitly forbids claiming a
  capability we cannot exercise (rule 19: "Never imagine unsupported platform capability").

**Therefore:** ReplayKit stays the shipping cross-app path (NOT removed, per §4.1). The
ScreenCaptureKit iOS path is recorded as a **READY, SDK-GATED upgrade**: the moment the repo
moves to an iOS 27 SDK + a device on iOS 27, a capability-gated prototype should be built
that reuses the existing frame-processing adapter (see §3).

## 3. The capability-gated prototype that SHOULD be built once iOS 27 SDK is available

Design (no code shipped this round — it would not compile/run on 26.x):

- Wrap everything in `#if canImport(ScreenCaptureKit)` + `@available(iOS 27, *)`.
- Present `SCContentSharingPicker.present()` for a **full-display** capture (user grants via
  the system picker — real consent, no private API).
- On `contentSharingPicker(_:didUpdateWith:for:)`, build an `SCStream` with an
  `SCStreamConfiguration` and attach a screen output (`SCStreamOutputType.screen`).
- Feed each `CMSampleBuffer`'s `CVPixelBuffer` into the **existing** adapter
  (`SampleHandler.segmentFrame` / `PhotoShieldLumaMatcherV1.lumaPlane` →
  `GuardianCanonicalSamplerV1`), so the OCTOPUS pipeline is identical to the ReplayKit path —
  **zero risk** to ReplayKit (the SCStream path is additive and capability-gated).
- Declare the `screen-capture` `UIBackgroundMode` so the stream survives backgrounding.
- Bounded memory/CPU: same per-item (not per-frame) analysis gate and thermal skip the
  extension already enforces; SCStream runs in the **app** process, so the §4.3 chain can
  drive ActivityKit directly (no App-Group→poller gap that the suspended-extension case has).
- Stale cleanup: on `SCStream` stop/`startCapture()` failure, clear the heartbeat + end the
  Live Activity (reuse the §4.3 CAPTURE_STALE path).
- **VERIFIED only on a real iOS 27 device** that (a) continues the app process while another
  app is foreground, (b) keeps the SCStream delivering frames, and (c) accepts ActivityKit
  updates driven from those frames. Until then: `REQUIRES_VERIFICATION`.

## 4. ActivityKit push path (from `apple_ak_push.json`) — evaluated, NOT implemented

The ActivityKit push-update API is real and documented. Honest cost assessment:
- It requires a **server + APNs**, a per-activity **push token**, network reachability,
  latency, and is subject to an **OS update budget** (iOS throttles frequent pushes).
- **Privacy-first default (constitution rule 16/17):** GEN8 does NOT transfer on-device
  Guardian signals to a server without explicit user consent + a product architecture
  decision. Standing up a push server would route private screen-derived signals through the
  cloud — a hard NO by default.
- **Decision:** documented as an OPTION only. No server, no push token, no cloud transfer
  implemented. For GEN8's rapid-swipe reality (an update per item transition), a push path
  would also lose to the OS update budget — it cannot be assumed to fire on every transition.
  The local path (SCStream-in-app on iOS 27, or the ReplayKit App-Group bridge today) remains
  the privacy-correct default.

## 5. §4.3 — the real per-event status chain (implemented this round)

`GuardianIslandUpdateChainV1` (R2) already separated APP-GROUP-WRITE ≠ ACTIVITYKIT-UPDATE ≠
PRESENTATION. R3 extends it with an explicit per-event lifecycle so a dead capture can never
show an evergreen band. See `GuardianIslandUpdateChainV1.swift` (new `eventStatus` ladder) and
`GuardianSurfaceSnapshotV1` (which gates `canShowLiveProtection` on capture actually running).
The staleDate/`CAPTURE_STALE` discipline: when the heartbeat ages out of its freshness window
or `broadcastFinished` fires, the chain reports `ENDED_NOT_PRESENTING` / `captureStale`, the
snapshot collapses the surface to UNKNOWN, and the Live Activity is ended — never left green.

## 6. BLOCKED / UNVERIFIED (honest)

- `xcrun --sdk iphoneos --show-sdk-version`: **BLOCKED** (sandbox denied the command). SDK
  version taken from CLAUDE.md §8 (iOS 26.x) — the authoritative repo record.
- iOS 27 ScreenCaptureKit on-device behaviour (process continuity, frame delivery while
  backgrounded, ActivityKit acceptance): **DEVICE_UNVERIFIED / REQUIRES_VERIFICATION** — no
  iOS 27 SDK and no physical device.
- App/extension Xcode build: `BUILD_UNVERIFIED_BY_AGENT` (xcodebuild not runnable in sandbox).
