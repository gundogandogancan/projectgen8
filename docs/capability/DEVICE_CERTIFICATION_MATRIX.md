# DEVICE CERTIFICATION MATRIX

**Doc status:** `CANONICAL` · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** Bible §211, §315, §571–§572; Prompt 000 §K.

Certification states: `CERTIFIED` · `SUPPORTED_WITH_LIMITATIONS` · `EXPERIMENTAL` · `COMPANION_ONLY` · `UNSUPPORTED` · `NOT_TESTED`.

> At Phase 0, **no device is certified** — all are `NOT_TESTED`. Certification requires the real-device program (Bible §571, 15 steps): capability handshake → capture → presentation → latency/battery/thermal → privacy/redaction → family/entitlement → evidence artifact. Simulators do not count as certification (real-device evidence required, Bible §120, Prompt 000 §63).

## Available test assets (this machine, 2026-10-18)
Simulators only (not certification): iPhone 17 / 17 Pro / 17 Pro Max / 17e / Air, iPad Pro/Air/mini (M-series), iOS 26.4 & 26.5. **No physical devices confirmed yet.** New Apple ID + Team ID needed for on-device runs (ADR-0003).

## Matrix (seed)

| Device family | Tier target | State | Blocking need |
|---|---|---|---|
| iPhone (Dynamic Island capable) | C3–C4 | NOT_TESTED | physical device + team signing |
| iPhone (no Dynamic Island) | C3 | NOT_TESTED | physical device |
| iPad | C3 | NOT_TESTED | physical device |
| Apple Vision Pro (visionOS) | C2–C3 | NOT_TESTED | device access |
| Mac (Apple Silicon) | C4 | NOT_TESTED | signing |
| Android flagship (Pixel/Samsung) | C3–C4 | NOT_TESTED | device + MediaProjection proof |
| Android mid/low (OEM battery mgrs) | C2–C3 | NOT_TESTED | **lowest supported device** benchmark (Bible §123) |
| Windows (x64/ARM64) | C3–C4 | NOT_TESTED | device |
| Linux (Wayland) | C2–C3 | NOT_TESTED | device |
| ChromeOS | C2–C3 | NOT_TESTED | device |
| Browser: Safari/Chrome/Edge/Firefox/Brave/Opera | C2–C3 | NOT_TESTED | extension build |
| Apple TV / Android TV / Fire TV / Tizen / webOS / Roku | C1–C3 | NOT_TESTED | device per family |
| Apple Watch / Wear OS | C1 | COMPANION_ONLY (target) | companion build |
| PlayStation / Xbox | C0–C1 | UNSUPPORTED (no official API) | n/a |

## Certification evidence per device (required fields)
`device_model · os_version · tier_achieved · capability_results(per axis) · admission_latency_p50/p95 · energy_per_decision · thermal_behavior · false_protected_incidents(must be 0) · privacy_redaction_verified · evidence_artifact · certified_by(independent) · date`

Lowest-supported-device benchmarking is mandatory before setting any SLO (Bible §123).
