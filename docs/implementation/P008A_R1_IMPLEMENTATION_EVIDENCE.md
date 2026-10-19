# P008A-R1 — Implementation Evidence
Verify: `swift test` → **246/246**; sim build + signed device build (fixed extension) SUCCEEDED + installed.
## Done
- BEFORE baseline preserved immutable + SHA-256 (docs/evals/artifacts/).
- `ContentBoundaryEngineV2` + `ContentBoundaryPolicyV2` + `BoundaryCapabilityProfile` + `BoundaryEvent` + `BoundaryEngineBenchmark` (GuardianCore) — ONE canonical engine (lab + extension).
- SampleHandler rewired: aHash + layout hash → ContentBoundaryEngineV2 → committedNew gate → deterministic Shield → UNKNOWN; OCR off (extension profile); resource instrumentation (mach task_info memory, thermal, lowPower, per-frame/boundary durations, os_signpost); derived log schema V2 (TRANSITION lines). No ContentChangeDetector in the extension path.
- Instruments/xctrace templates verified on the real toolchain; resource trace procedure documented.
- +6 tests (P008AR1BoundaryTests): motion-suppression, rapid-swipe, overlay-non-boundary, policy revision, engine benchmark, capability profiles. All prior 240 green → 246.
## Pending (user-gated / honest)
- Real device re-run (§11–§14): needs the user's one-tap Start-Broadcast gesture (unautomatable by an agent) → device boundary + resource numbers PENDING.
- Live Dynamic Island cross-process delivery: BLOCKED_PENDING_PAID_APP_GROUP (separate).
- Score: stays UNKNOWN (calibration untouched this prompt).
