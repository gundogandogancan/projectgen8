# RWC-PRE-13 — PHYSICAL-DEVICE E2E EVIDENCE PROTOCOL (protocol only; NO measurements claimed)

PATH UNDER TEST (release configuration): rights-clear input -> perception -> identity -> cognition ->
world model -> policy -> calibration -> admission -> explanation (full Guardian chain, on device).
MEASUREMENTS: end-to-end latency (p50/p95/p99), per-stage latency, CPU%, GPU% (where measurable),
NPU/ANE utilization (where measurable), peak+steady memory, energy per decision, battery %/hour,
thermal state transitions (nominal/fair/serious/critical), wakeups, queue depth + drop behavior, cache
hit/miss, logging overhead delta, privacy leakage scan (no raw content in logs/artifacts), raw-content
persistence scan (must be ZERO by default), crash/error behavior under kill/memory pressure.
DEVICE MATRIX: primary iPhone 14 Pro Max (iOS 26.x, the project device); floor device per
DEVICE_RESOURCE_BUDGETS (lowest supported class); matrix extends via DEVICE_CERTIFICATION_MATRIX waves.
RUN DISCIPLINE: cold + warm runs; >= 3 repeats per cell; >= 10-minute sustained session for thermal;
thermal precondition recorded (start <= fair); background state controlled (fresh boot + quiesce);
network state pinned (offline AND online cells); power state recorded (battery level band, not charging).
INSTRUMENTATION: Instruments/xctrace + MetricKit where available; measurement artifact = content-free
JSON (device, os, build SHA, config, cell, metrics, thermal timeline) committed under evals/device.
LOGGING LAW (thermal-SERIOUS history, NT-THERMAL-EVIDENCE-BUILD): debug/audit logging measured as a
SEPARATE cell from release behavior; release logging stays structurally OFF; the evidence-build cell can
never stand in for the release cell.
FAILURE THRESHOLDS: budgets from DEVICE_RESOURCE_BUDGETS.yaml; any exceedance = FAIL cell; UNKNOWN
handling: unmeasurable metric on a platform is reported UNKNOWN - never imputed.
LAWS: build success != runtime proof (FM-004); simulator != physical device (FM-002); zero fabricated
numbers - this protocol defines HOW to measure, it reports NOTHING yet.
