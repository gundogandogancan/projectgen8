# P005 — Device Evidence & Device-Health Gate

**Doc status:** `CANONICAL` · **Phase:** 5 · **Date:** 2026-10-18 · PROMPT 005 §24, §25.

## Real device gate status
`PENDING_EXTERNAL_DEPENDENCY` — no Apple Developer Team / physical iPhone available (new Apple ID pending, ADR-0003). All P005 evidence is **macOS LAB / simulator**, clearly labelled. **No device numbers fabricated.**

## Device-Health Acceptance Gate (§25)
> Does the current GuardianLab analysis create material user-perceived device degradation?

**Answer: `LAB_NO_OBVIOUS_DEGRADATION`** (NOT a device certification).
- Short-clip E2E analysis ~192–218 ms (macOS LAB); sparse decode (16 frames), bounded OCR (16), no full-FPS loop.
- Idle = genuinely idle (test: 0 preflight/decision when no request).
- Cache reuse avoids re-decode (test).
- Cannot claim "device feels nothing" without physical-device evidence — **not claimed.**

## Not certified (requires device + Instruments)
CPU profile · energy impact · memory high-water · thermal behavior · wakeups · UI responsiveness · Low Power Mode behavior · background transitions.

## Reproducible on-device protocol (when Team available)
1. Provision signing (ADR-0003); accept min-OS ADR-0012.
2. Run scenarios (§24): idle GuardianLab · 10-min short-form loop · cached loop · long-form coarse · long-form playback-ahead · ECO/BALANCED/MAX · Low Power · thermal observation · fg/bg transitions.
3. Measure via Time Profiler / Energy Log / Allocations / memory graph / os_signpost intervals.
4. Write `DEVICE_MEASURED` values into `DEVICE_RESOURCE_BUDGETS.yaml` (only actually measured).
