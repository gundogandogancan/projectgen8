# P001 DEVICE MEASUREMENT PROTOCOL (P0-B)

**Doc status:** `CANONICAL` (protocol; no fabricated values) · **Phase:** 1 · **Date:** 2026-10-18 · PROMPT 001 §15. Backs `DEVICE_RESOURCE_BUDGETS.yaml`. **Do not fake CPU/GPU/NPU or battery-energy values** — if a public in-app API can't provide a value reliably, measure externally with Instruments and record the procedure.

## In-app telemetry (obtainable from public APIs — implemented in `GuardianCore.Diagnostics`)
- **Wall-clock decision latency** — monotonic clock around each admission decision (real).
- **Cache hit/miss** counts; **preflight run** count; **candidate cancellations**; **duplicate-analysis-prevented** count; **task count** (bounded scheduler).
- **Thermal state** — `ProcessInfo.thermalState` (nominal/fair/serious/critical).
- **Low-power mode** — `ProcessInfo.isLowPowerModeEnabled`.
- **App lifecycle / foreground-background** transitions.
- **Memory footprint** — best-effort via `task_info`/`os_proc_available_memory` where safely available; otherwise marked `UNSET_PENDING_INSTRUMENTS`.
- **Network bytes = 0** for the local-only GuardianLab fixture path (asserted by test: no URLSession usage on that path).

## Not reliably available in-app ⇒ external measurement (Instruments)
- **CPU/GPU/NPU utilization, energy-per-decision, battery drain, UI frame time/jank** → measured with **Xcode Instruments** (Time Profiler, Energy Log, Core Animation/Hangs) and **os_signpost** intervals, not faked.

## Signposts (added in `GuardianCore`)
`os_signpost`/`OSSignposter` intervals around: candidate discovery, identity resolve, cache lookup, preflight, fusion, admission, surface update, temporal look-ahead. Named so Instruments can attribute cost per stage.

## Reproducible benchmark scenarios (S1–S10, see P001_IMPLEMENTATION_EVIDENCE)
Each scenario runs headless in `swift test` for logic/latency/bounds, and (on device, later) under Instruments for energy/thermal. Idle scenario (S10) asserts **no timer/polling loop and no analysis when the user is not interacting** (event-driven only).

## Labeling
Every measured number is labelled `MEASURED (sim)`, `MEASURED (device)`, or `UNSET_PENDING_INSTRUMENTS`. Simulator timings are labelled as such and never presented as device SLOs (device baseline required before SLOs — Bible §123).
