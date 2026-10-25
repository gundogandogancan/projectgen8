# APPLE CAPTURE STRATEGY — R2 (§D2): ReplayKit vs ScreenCaptureKit for GEN8's cross-app + Dynamic Island goal

> STATUS: ANALYSIS / DECISION NOTE. Agent is NETWORK-SANDBOXED and could not fetch Apple documentation at authoring
> time. Every Apple-API claim below that could not be confirmed against official docs offline is marked
> **[UNVERIFIED]** and MUST be re-verified against current Apple documentation at implementation time (CLAUDE.md §3,
> Build Bible §16). Nothing here fabricates a minimum OS version, entitlement, or API capability as established fact.
> No private API is proposed anywhere.

## 0. What problem are we actually solving?

GEN8's product chain (mandate §1): observe the user's REAL social-media feed with consent → understand content
character + personal policy → produce a calibrated Guardian state → show it on a supported live surface (Dynamic
Island). Today the ONLY shipping path is **ReplayKit** (a system broadcast; `SampleHandler` is live and does the real
work). The §D2 question: does Apple's **ScreenCaptureKit** family solve a problem ReplayKit does not — specifically
(a) the SUSPENDED-app Dynamic Island update gap (§D1 state 2), and (b) running the Guardian runtime in-process?

## 1. ReplayKit (the current, shipping path)

| Property | Status |
|---|---|
| API class | `RPBroadcastSampleHandler` broadcast upload extension — **VERIFIED** (we ship it; `SampleHandler.swift`). |
| What it captures | Whole-screen `CMSampleBuffer`s of WHATEVER app is foreground (Instagram, etc.). **VERIFIED** (observed in R1 lab). |
| Process model | A SEPARATE extension process with a hard memory budget (~50 MB enforced in practice). **VERIFIED** (we measure `residentMemoryMB`). |
| Cross-app | YES — this is the only official iOS way to see another app's screen with user consent. **VERIFIED.** |
| Island update | The extension writes the App Group; the **app** process owns ActivityKit. When the app is SUSPENDED (user in Instagram) the app-side poller is NOT running → the App Group write does NOT become an ActivityKit update until resume. **This is the known §D1 gap.** |
| Entitlements | App Group + broadcast extension entitlement. **VERIFIED** (present in `GuardianBroadcastExtension.entitlements`). |
| Privacy | Raw frames EPHEMERAL, never persisted; only derived signatures kept. **VERIFIED** (enforced in `SampleHandler`). |

ReplayKit's limitation for our goal is NOT capture — it is the **update path to the Island while the app is
suspended**. The extension cannot drive ActivityKit; only the app can, and the app is not running.

## 2. ScreenCaptureKit (the candidate)

ScreenCaptureKit (`SCStream`, `SCContentSharingPicker`, `SCContentFilter`, `SCStreamOutput`) is Apple's modern capture
framework, long-established on macOS.

- **iOS availability / minimum OS** — **[UNVERIFIED].** ScreenCaptureKit on iOS (the mandate references an "iOS 27+"
  sample architecture) could not be confirmed offline. The *existence, minimum iOS version, and exact API surface of
  ScreenCaptureKit on iOS must be verified against current Apple documentation at implementation time.* Do not assume
  it is present on our deployment target.
- `SCContentSharingPicker` — a system picker for choosing what to share. **[UNVERIFIED]** on iOS.
- Full-display capture + `SCStream` output — **[UNVERIFIED]** whether iOS permits full-display (other-app) capture
  outside a broadcast extension, and under what entitlement/privacy-manifest requirement.
- `screen-capture` background mode — **[UNVERIFIED]** whether this exists on iOS and whether it would let a capture +
  ActivityKit update run while GEN8 is backgrounded.
- In-process observation — IF (and only if) iOS ScreenCaptureKit can deliver frames to the **app** process (not a
  separate extension), then the app could run both the Guardian runtime AND ActivityKit updates in ONE process,
  which would directly close the suspended-app Island gap. Whether iOS allows app-process capture of OTHER apps'
  content is **[UNVERIFIED]** and is the crux of the decision.

## 3. The decision

**KEEP ReplayKit as the shipping path. Do NOT remove or weaken it (mandate §D2).** It is the only VERIFIED cross-app
capture mechanism we have, and R1/R2 real work runs through it.

**Treat ScreenCaptureKit-on-iOS as RESEARCH, gated on documentation verification, NOT a committed migration.** The
single question that would justify a capability-gated prototype is: *does iOS ScreenCaptureKit allow the APP process
to receive other-app screen frames with user consent?* — because only an in-process path closes the §D1 suspended-app
Island update gap without a push-based update path.

### What was NOT built this round (honest)

- **A ScreenCaptureKit prototype: NOT_DONE.** The mandate authorizes a capability-gated prototype ONLY if it can be
  written with compile-safe `@available` guards and ZERO risk to the ReplayKit path. Because the iOS API surface,
  minimum OS, and even availability are **[UNVERIFIED]** offline (network-sandboxed), writing a prototype now would
  mean inventing API signatures — a direct violation of CLAUDE.md §3 (never invent APIs). We therefore mark it
  NOT_DONE with a clear next step, rather than ship fabricated availability guards.

## 4. The suspended-app Island gap — what we DID do instead (§D1)

We made the gap EXPLICIT and HONEST in code rather than papering over it:

- `GuardianIslandUpdateChainV1` (new, GuardianMedia) models the three operating states —
  `appForeground` / `appSuspendedOtherForeground` / `captureEnded` — and keeps **APP GROUP WRITE ≠ ACTIVITYKIT UPDATE
  ≠ ISLAND PRESENTED** as three separate evidence fields. In the suspended case a fresh App Group write that could NOT
  reach ActivityKit is reported as `WRITTEN_NOT_UPDATED` + `blockedBySuspension = true` (reason
  `APP_SUSPENDED_ACTIVITYKIT_UPDATE_BLOCKED`) — never pretended to be an update, never pretended to be on screen.
- This is the capability-gated honest record the mandate asks for: the Live Activity update from a suspended app is
  **BLOCKED** without an OS-supported background update path (e.g. push-token Live Activity updates) — a real gap,
  reported, not worked around. Verifying whether push-token Live Activity updates are a viable path on our target OS
  is **[UNVERIFIED]** and is itemized in NEXT.

## 5. NEXT (verification backlog — all require network + device)

1. Verify ScreenCaptureKit iOS availability, minimum iOS version, API surface, entitlements, privacy manifest against
   CURRENT Apple docs. Only then decide on a prototype.
2. Verify whether iOS permits APP-process capture of other-app content (the in-process crux).
3. Verify the push-token Live Activity update path for the suspended-app case (could close §D1 state 2 without
   ScreenCaptureKit at all).
4. Device experiment: measure whether a foreground app + ActivityKit update reaches the Island, and whether a
   suspended-app write ever updates on resume (feeds the `GuardianIslandUpdateChainV1` evidence fields with real
   observations instead of synthetic ones).
