# P008A-R1 — Resource Device Results
## Status: instrumentation ADDED; on-device capture PENDING the user's broadcast re-run.
The fixed extension now emits (derived-only, in `gen8_crossapp_proof.log` + os_signpost): per-frame cheap-path duration,
per-boundary duration, resident `memoryMB` (mach task_info), `peakMemoryMB`, `thermal`, `lowPower`, and cheap-path
p50/p95 at BROADCAST_FINISHED. os_signpost intervals (`frame`, `boundary`) allow Instruments CPU/energy capture.
Actual CPU / memory-high-water / thermal / energy numbers require the user to run a broadcast (one-tap, unautomatable by
an agent) + attach xctrace per the procedure. Until then: `DEVICE_EVIDENCE_INSUFFICIENT` for CPU/energy; memory/thermal
will be present in the pulled log after the re-run. No metric fabricated.
