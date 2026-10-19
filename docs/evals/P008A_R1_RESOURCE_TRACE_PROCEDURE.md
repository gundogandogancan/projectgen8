# P008A-R1 — Resource Trace Procedure (§7,§8) — real toolchain
`xcrun xctrace list templates` (verified on this toolchain) → available: Allocations, CPU Profiler, Power Profiler,
Activity Monitor, System Trace, Leaks, Logging, Time Profiler (via CPU Profiler), Metal/Game/etc.
## Repeatable capture (broadcast extension)
1. Install the signed build; user starts a Gen8 Observation broadcast.
2. Attach a device trace on the running extension process `GuardianBroadcastExtension`:
   `xcrun xctrace record --device <udid> --template "Allocations" --attach GuardianBroadcastExtension --output ext_mem.trace`
   (repeat with "CPU Profiler" and "Power Profiler"; or "System Trace" for thermal/system state).
3. In-extension telemetry (always-on, derived-only): resident memory (mach task_info), per-frame + per-boundary
   durations, os_signpost intervals (frame / boundary / committed-new), thermalState, lowPowerMode, peak memory.
## Honesty
Broadcast Upload Extensions can be awkward to attach live; if a specific metric cannot be captured for the extension
process it is marked `UNAVAILABLE_TOOLING` — never invented. CPU%/energy joules are reported only if the tool exposes them.
