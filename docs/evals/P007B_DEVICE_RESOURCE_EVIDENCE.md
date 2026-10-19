# P007B — Device Resource Evidence

## Captured (automatable)
- App + extension processes confirmed running on device (pids 7138 / 7139). App launches and stays resident.
- No crash on launch observed via devicectl.

## NOT captured (require Instruments / interactive operation — an agent cannot drive them)
CPU %, memory high-water, energy impact, wakeups, thermal-state transitions, UI frame time, decode/OCR/speech/model
invocation counts during a timed on-device run. These need Xcode Instruments (Time Profiler / Allocations / Energy) or
`xctrace` with an interactive device session.

## No fabrication
No joules, CPU %, battery %, or thermal numbers are asserted. `DEVICE_RESOURCE_BUDGETS.yaml` device fields remain null.

## Gate (§24)
`DEVICE_EVIDENCE_INSUFFICIENT` for the no-material-degradation gate — install/launch proven, but behavioral energy/
thermal/memory profiling not performed. (LAB-logic soak-to-baseline + leak accounting remain green, P007.)
