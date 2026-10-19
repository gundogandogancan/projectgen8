# P002 REAL DEVICE GATE

**Doc status:** `CANONICAL` · **Phase:** 2 · **Date:** 2026-10-18 · PROMPT 002 §23 / 002A §15.

## Status: `PENDING_EXTERNAL_DEPENDENCY`
No Apple Developer Team / signing is available (new Apple ID pending — ADR-0003, classified EXTERNAL_EXECUTION_DEPENDENCY). Therefore Prompt 002 is validated on **macOS headless (`swift test`) + iOS Simulator build** only.

## What this gate does NOT certify (explicitly)
- ❌ battery SLO certification
- ❌ thermal SLO certification
- ❌ physical-device latency certification
- ❌ Dynamic Island production certification

## What IS validated (labelled)
- ✅ `swift test` 81/81 on macOS (real CryptoKit / Vision / NaturalLanguage providers) — **LAB_MEASURED**
- ✅ iOS Simulator build **BUILD SUCCEEDED**
- ✅ Instruments signposts present (`GuardianSignposter`) for later on-device Time Profiler / Energy Log
- ✅ Measurement protocol documented (`P001_DEVICE_MEASUREMENT_PROTOCOL.md`)

## Unblock procedure (when Team available)
1. Set `DEVELOPMENT_TEAM` + final bundle id (ADR-0003); accept ADR-0012 min-OS.
2. Run the benchmark scenarios on a physical iPhone under Instruments (Time Profiler, Energy Log, Allocations, thermal).
3. Record device results with `MEASURED (device)` labels in `DEVICE_CERTIFICATION_MATRIX.md`.
4. Only then may any battery/thermal/latency SLO move from TARGET/UNSET to CERTIFIED.

**This does NOT block Prompt 002 architecture PASS** (002A §15). Simulator/lab values remain clearly labelled.
