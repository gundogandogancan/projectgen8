# P007 — Release Readiness Levels

| Level | Meaning | Required gates | Gen8 status (2026-10-18) |
|-------|---------|----------------|--------------------------|
| **R0** | Architecture only | canonical docs, contracts, ADRs | ✅ done (P000–P000A) |
| **R1** | Simulator / Lab proof | headless tests green; sim build; LAB benchmarks; honest UNAVAILABLE states | ✅ **CURRENT** — 214/214 tests, sim BUILD SUCCEEDED, LAB pipeline/durability/soak benchmarks, native-surface logic compiled |
| **R2** | Physical-device proof | run on real iPhone; device CPU/mem/thermal/energy; Control Center + Live Activity live; on-device TR/EN speech; real soak | ⛔ **BLOCKED** — signing team not wired (connected iPhone + certs exist; needs team + bundle id + provisioning + trust) |
| **R3** | Calibrated internal alpha | per-task calibration with real data; H1 ACTIVE_LAB or explicit gap; device budgets populated | ⛔ not started (calibration UNAVAILABLE_INSUFFICIENT_DATA; H1 UNAVAILABLE) |
| **R4** | TestFlight candidate | signed build distributed; crash-free sessions; privacy review; store metadata | ⛔ not started |
| **R5** | Production candidate | full legal/privacy completion; scaled eval; support/ops; rollback | ⛔ not started |

## Honest current assignment: **R1 (Simulator/Lab proof), with R2 unblockable on one human signing step**
- R1 is fully satisfied.
- R2 is **blocked only** by the external signing decision; unlike earlier phases, the hardware (connected iPhone 14 Pro
  Max) and signing identities now exist. Completing R2 requires the user to wire `DEVELOPMENT_TEAM` + a unique bundle id
  (ADR-0003) + provisioning + on-device trust — then run the P007 §18 device gate.
- We do **not** claim R3/R4/R5. No production certification is claimed without evidence.

## P007B update — R2 PARTIAL (not certified)
Real device signing + install + launch + extension-process-running are **verified** on iPhone 14 Pro Max (iOS 26.6),
team `47XQMQZLF6`. However R2 CERTIFICATION (§29) also requires on-device Control Center proof, Live Activity render,
device benchmark percentiles, energy/thermal/memory evidence, and a 30-min device soak — none captured (require
human-operated device UI / Instruments / an on-device test target). App Group (shared state + full Live Activity) is
blocked pending a **paid Apple Developer Program** membership. **Current level remains R1**; R2 is in progress with a
real device foothold. R2 not claimed.
