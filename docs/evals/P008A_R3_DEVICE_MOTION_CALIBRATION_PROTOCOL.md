# P008A-R3 — Device Motion Calibration Protocol (derived-only)

Status: calibration MODE wired in the extension (env-gated); scripted user run is user-gated (§24).
Privacy: records ONLY derived motion telemetry — **no raw frames, no audio, no OCR text, no content titles**.

## What is logged (per sampled frame, when enabled)
`CALIB f=<n> state=<SegmentStateV4> energy=<MotionEnergy> scale=<robustMotionScale> normJump=<normalized>
post=<postPersistence> mode=<TransitionModeV4> committed=<bool>` — all derived scalars; no reconstructive features.

## Enablement
`GEN8_CALIBRATION=1` in the extension environment. NOTE (honest): a system-launched ReplayKit broadcast extension
does not inherit a user-set env var, and the per-user settings toggle would need an App Group (BLOCKED on the free
team). So on-device per-frame calibration logging is wired but not switchable without App Group / a launch-env
harness. The **bootstrap-v0** profile was therefore derived from the already-captured V3 derived telemetry (real
device, derived-only) — see P008A_R3_DEVICE_MOTION_PROFILE. A future enriched profile uses the scripted run below.

## Scripted session (§13, for a future enriched profile — user-run)
1. 8–10 s on one HIGH-MOTION item (no swipe).
2. one swipe → 5 s on the next item.
3. one swipe → 5 s on a LOW-MOTION item.
4. repeat the block several times.
5. one app switch → return.
User records only approximate event times/counts (`MANUAL_APPROXIMATE_GROUND_TRUTH`).

Purpose: learn REAL MOTION DISTRIBUTIONS, not content. The timing blocks let us label derived telemetry windows as
same-item / high-motion / transition / overlay / swipe / low-motion without any content capture.

## Pull + archive
```
xcrun devicectl device copy from --device C7C6CE6E-B577-558A-8992-DC6C1F492B39 \
  --domain-type appDataContainer --domain-identifier com.gen8.guardian.dev.GuardianBroadcast \
  --source Documents/gen8_crossapp_proof.log --destination ./P008A_R3_CALIB_device.log
```
Archive + SHA-lock the pulled log; it is CALIBRATION EVIDENCE, not final validation (§24).
