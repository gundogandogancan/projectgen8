# P007D — Cross-App Content Observation Architecture (iOS, official API only)

## Official-API verification (iOS 26.x / iPhoneOS26.5 SDK)
- **ScreenCaptureKit: NOT present in the iOS SDK** → cross-app capture via SCK on iOS = **UNAVAILABLE** (SCK is macOS/visionOS).
- **ReplayKit: present** — `RPBroadcastSampleHandler` (Broadcast Upload Extension) + `RPSystemBroadcastPickerView`.
- Therefore the ONLY sanctioned iOS cross-app screen path = **ReplayKit system broadcast → Broadcast Upload Extension**,
  started ONLY by the user via Apple's system sheet (red recording indicator). No private API, no accessibility abuse,
  no hidden capture, no recording without explicit consent.

## What was built (real, installed, signed on device)
- **`GuardianBroadcastExtension`** target (`com.apple.product-type.app-extension`, point `com.apple.broadcast-services-upload`),
  bundle `com.gen8.guardian.dev.GuardianBroadcast`, team `47XQMQZLF6`, embedded in the app, **installed on iPhone 14 Pro Max**.
- `SampleHandler: RPBroadcastSampleHandler` — receives whole-screen `CMSampleBuffer`s of whatever app is on screen.
- App: `CrossAppObservationView` wraps `RPSystemBroadcastPickerView` (user-initiated start/stop) with a consent explanation.

## Performance architecture (frame-driven heavy AI FORBIDDEN)
1. **Every frame** → ultra-cheap 8×8 average-hash (`PerceptualFrameSignature`) sampled in-place from the `CVPixelBuffer`
   (no decode, no copy, no framework). 
2. `ContentChangeDetector` (hamming threshold + settle frames) decides a NEW distinct content; unchanged frames do NOTHING heavy.
3. On a newly-settled content → check in-memory signature cache (ContentDNA-ish) → analyze ONCE. `swift test` proves
   heavy analysis runs once per content, not per frame (`P007DCrossAppTests`).
4. In-extension (≤50 MB broadcast budget): deterministic Shield/admission on the observation + stabilized `NativeSurfaceState`;
   first-trustworthy latency measured + logged. os_signpost intervals make CPU/energy measurable in Instruments.

## Privacy discipline (enforced structurally)
- Raw frames are **ephemeral**: processed in-place, released each call; **never written to disk, never uploaded**.
- Persisted artifact = a 64-bit perceptual hash + derived counters/text only (`ContentObservationEnvelope.privacyClass =
  ephemeral-on-device`). There is no pixel/frame field on the envelope.

## Honest capability boundaries (NOT faked)
- **ScreenCaptureKit cross-app on iOS:** UNAVAILABLE (not in SDK).
- **Heavy heads (Vision OCR / semantic / visual) in the broadcast extension:** deferred — the ~50 MB broadcast budget makes
  in-extension Vision memory-risky. Real OCR→score belongs app-side via extension→app handoff.
- **Extension → app → Dynamic Island LIVE update (score/color/glyph from cross-app content):**
  `BLOCKED_PENDING_PAID_APP_GROUP`. Cross-process handoff (App Group) + cross-process Live Activity update
  (App Group / push token) are unavailable on the free/personal team (App Groups need a paid Apple Developer Program,
  proven in P007B). The extension COMPUTES + logs the stabilized Guardian state; pushing it to the Island needs the paid handoff.
- **Starting the broadcast is a user consent gesture** (system sheet "Start Broadcast") — by design it cannot be triggered
  headlessly by an agent. The device Instagram run is therefore user-performed (procedure below).

## Real Instagram/Reels device test procedure (user-performed; agent cannot tap "Start Broadcast")
1. Launch Gen8 → Short-form → "Cross-app observation" → tap the broadcast picker → "Gen8 Observation" → **Start Broadcast**.
2. Switch to Instagram/Reels; change **≥5** different contents (scroll/swipe), pausing ~1s each.
3. Return to Gen8; stop the broadcast.
4. Pull the ephemeral proof log (derived signals only, no frames):
   `xcrun devicectl device copy from --device <id> --domain-type appDataContainer --domain-identifier com.gen8.guardian.dev.GuardianBroadcast --source Documents/gen8_crossapp_proof.log --destination ./crossapp.log`
   (or read Console.app, subsystem `com.gen8.guardian.dev.GuardianBroadcast`).
   Expect lines: `BROADCAST_STARTED`, per-content `CONTENT analyzed … firstTrustworthyMs=…`, `STATS frames=… changes=… analyzed=… reuse=…`,
   `BROADCAST_FINISHED`. These prove content-change count, analyzed-content count, cache reuse, first-trustworthy latency,
   and — because only hashes/counters are logged — that **no raw frame was persisted**.
