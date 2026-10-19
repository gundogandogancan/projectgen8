# P008A-R4 — Device Calibration Protocol (no App Group, evidence build)

Status: evidence-build telemetry WIRED (compile/env gated); scripted user run is user-gated (§6).
Privacy: ONLY derived scalars — no raw frames, audio, OCR text, title, or app-private content (§5).

## Enablement without App Group (§5)
DEBUG/EVIDENCE builds enable per-frame derived telemetry at BUILD level — no runtime App Group toggle:
- compile flag `-D GEN8_EVIDENCE_BUILD`, OR
- environment `GEN8_EVIDENCE_BUILD=1`.
Release builds leave it off (high-volume logging disabled). The extension logs, per sampled frame:
`MOTION f=<n> ts=<ms> state=<SegmentStateV5> energy=<motionEnergy> scale=<robustScale> disc=<normalizedDiscontinuity>
repl=<regionalReplacement> postMs=<postPersistence> swipe=<SwipeGateState> committed=<bool>`.

## Scripted session (§6 — user-executed, unbiased per-frame)
A. 8–10 s high-motion video WITHOUT swiping · B. one normal swipe · C. 5 s low-motion/static item ·
D. one normal swipe · E. 8 s panning/scrolling-looking video WITHOUT changing item · F. rapid two-item swipe ·
G. comments/controls overlay if possible · H. one app switch + return · I. stop broadcast.
User records only approximate block order/times. This is CALIBRATION evidence, not final validation.

## Pull + archive
```
xcrun devicectl device copy from --device C7C6CE6E-B577-558A-8992-DC6C1F492B39 \
  --domain-type appDataContainer --domain-identifier com.gen8.guardian.dev.GuardianBroadcast \
  --source Documents/gen8_crossapp_proof.log --destination ./P008A_R4_CALIB_device.log
```
Archive + SHA-lock the derived log. It feeds `DeviceMotionProfileV2` v2.1 (unbiased, per-frame — the current
`v2-partial` is bootstrapped from the V4 run's on-device scale; see P008A_R4_DEVICE_MOTION_PROFILE_V2).
