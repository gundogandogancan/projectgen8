# P001 PRE-FLIGHT REPORT

**Doc status:** `CANONICAL` · **Phase:** 1 (PROMPT 001) · **Date:** 2026-10-18 · Required by PROMPT 001 §1 before any product code.

| # | Item | Finding |
|---|---|---|
| 1 | git branch/status | `main`; only `docs/`, `README.md`, `CLAUDE.md` untracked (Phase 0 docs). No product code modified yet. |
| 2 | Xcode project/targets | Project `Gen8.xcodeproj`; **one target `Gen8`**, one scheme `Gen8`; Debug/Release configs. |
| 3 | Bundle identifier | `com.aymedo.Gen8` (OLD account — provisional, non-canonical; ADR-0003 / EXTERNAL_EXECUTION_DEPENDENCY). |
| 4 | Swift language mode | **Swift 5.0** (`SWIFT_VERSION = 5.0`); toolchain is Swift 6.3.3. Swift-6 mode = ADR-0002 (deferred; not silently changed — §27). |
| 5 | Min deployment target | iOS 26.5 (`IPHONEOS_DEPLOYMENT_TARGET = 26.5`); `SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx xros xrsimulator`. |
| 6 | Simulator runtimes | iOS 26.4, 26.4.1, 26.5 available (iPhone 17 family, iPad M-series, iPhone Air). |
| 7 | Real-device signing | **Not available** — no `DEVELOPMENT_TEAM` set; new Apple ID pending (ADR-0003). Simulator-only this phase. |
| 8 | Unit/UI test targets | **None exist** in the Xcode project. PROMPT 001 introduces tests via a local Swift Package (`packages/GuardianKit`) runnable headless with `swift test` (real evidence without signing). |
| 9 | Missing Phase 0 artifacts | **None.** All PROMPT 000 + 000A inputs listed in §0 are present under `docs/`. Verified: constitution, master spec, decision ledger, requirements registry, traceability matrix, canonical-section coverage matrix, P0 DAG, PRE_EXPOSURE_SLO, DEVICE_RESOURCE_BUDGETS, DEVICE_NATIVE_RUNTIME_CONSTITUTION, design system + Guardian visual constitution + screen-state inventory, threat/privacy/data-rights, eval + calibration + dataset governance, MODEL_REGISTRY, EVENT_CONTRACTS, API_CONTRACTS, CLAUDE.md. |
| 10 | P0 requirements traceable | Yes. This slice exercises: ADM-001/002 (pre-exposure/admission), IDR-001 (identity, fixture), CDNA-001 (local cache), COG-001 (fixture cognition/HEURISTIC_V0), SCO-001/002 (score states), PAI-001 (personal algorithm v0), PROT-001/002 (protection + semantic shield v0), TMP-001/002 (temporal + skip safety), UX-001/002 + ACC-001 (Pure Bar), OPS-002/OPS-003 (device health + telemetry). All `NOT_STARTED` → moving to in-progress. |

## Architecture approach for PROMPT 001 (keeps domain platform-free, §5/§26)
- **`packages/GuardianKit/` — local Swift Package** with:
  - `GuardianCore` target — **pure Swift, NO SwiftUI/UIKit** — all domain + application logic (types, cache, scheduler actor, heuristic preflight, personal algorithm, protection/semantic shield, positive exposure, admission controller, score states, temporal graph + skip-safety + analysis-ahead, telemetry/diagnostics, decision trace, event emission, logging facade). **Runnable + testable headless via `swift test`** → real evidence without signing.
  - `GuardianCoreTests` target — XCTest covering the §23 matrix + §31 benchmark scenarios S1–S10.
- The SwiftUI UI (Pure Bar, onboarding, GuardianLab screens) is implemented against `GuardianCore`. Wiring the existing Xcode `Gen8` target to the local package (+ relocation to `apps/ios`) is the ADR-0002 step; if hand-wiring the `.xcodeproj` proves fragile in this environment it is reported as a known limitation with the SPM package + passing tests standing as the primary evidence.

**No required file missing or contradictory ⇒ NOT BLOCKED.** Proceeding to implementation.
