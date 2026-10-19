# P008 — Universal Observation Adapter Contract (§32,§33)
`ObservationAdapter` → common output `ContentObservationEnvelope`. One brain; many official bodies.
Each adapter DECLARES capability states: PIXELS / AUDIO / TEXT / METADATA / CAPTIONS / NEXT_CANDIDATE /
CONTROLLED_PLAYER / OVERLAY_SURFACE / BACKGROUND_EXECUTION.
Planned adapters (capability-truthful, implemented incrementally — iOS first per §41): iOS/iPadOS ReplayKit
user-consented broadcast (BUILT, P007D) · Android media projection · macOS ScreenCaptureKit · Windows official capture ·
Linux compositor/session capture · browser DOM/tab/provider metadata · tvOS/Android-TV/Smart-TV capability-truthful ·
provider/API integrations. No adapter claims a capability the official platform API does not expose.
## DRM / protected content (§33)
Never bypass DRM/HDCP. If pixels/audio are blocked (Netflix/streaming): fall back in order to provider metadata →
title/episode identity → officially-exposed captions → official provider integration → companion metadata →
UNKNOWN/UNAVAILABLE. No DRM circumvention, ever.
