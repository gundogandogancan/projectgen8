# DEVICE TEST MATRIX

**Doc status:** `CANONICAL` (plan) · **Phase:** 0 · **Date:** 2026-10-18 · **Refs:** PROMPT 000A §7; Bible §211, §123, §315, §571. Complements `DEVICE_CERTIFICATION_MATRIX.md`. **Do not invent certification results.** iOS-first (D-0011) ⇒ iOS coverage leads.

## Test condition axes (every device run sweeps these)
device generation · Dynamic Island vs non-Dynamic-Island · battery-health variation · low-power mode on/off · thermal state (nominal/fair/serious/critical) · network state (wifi/cellular/offline/degraded) · storage pressure (ample/low) · foreground/background · charging/idle.

## iOS representative set (P0-A1/A2 — leads)
| Device | Surface | Why |
|---|---|---|
| iPhone (latest Pro, Dynamic Island) | Dynamic Island / Live Activity | primary Guardian surface |
| iPhone (non-Dynamic-Island / older supported) | in-app / Safari ext | surface fallback truth |
| **iPhone = lowest supported device** | all | **SLO + resource baseline (§123) — mandatory before any SLO** |
| iPad | in-app | tablet layout + perf |
| iPhone in Low Power + thermal-serious | all | P0-B degradation behavior |
| Apple Vision Pro (visionOS) | peripheral ambient | target-set member |

> Physical iPhones required; simulators (iOS 26.4/26.5, available today) are for functional dev only, **not certification** (real-device evidence required — D-0016). Signing needs the new Apple Team (ADR-0003, EXTERNAL_EXECUTION_DEPENDENCY).

## Later families (post-core-proof, per P0 order)
Browser (Safari/Chrome/Edge/Firefox/Brave/Opera) · Android flagship + **mid/low with aggressive OEM battery managers** (OEM_QUIRK_REGISTRY) · Windows x64/ARM64 · Linux Wayland · ChromeOS · Apple TV / Android TV / Fire OS / Fire Vega OS / Tizen / webOS / Roku · Apple Watch / Wear OS companion.

## Per-run required outputs
`device · os · tier_achieved · capability_results · admission_p50/p95 · energy_per_decision · thermal_behavior · false_protected_incidents(=0) · privacy_redaction_verified · UI_frame_time · background_stability · evidence_artifact · certified_by(independent) · date`.

## Phase-0 status
Plan only; **no device tests run**, no certification claimed. Drives OPS-001/OPS-002 + DEVICE_CERTIFICATION_MATRIX.
