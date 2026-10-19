# P009B — Implementation Evidence

**Date:** 2026-10-19 · **Tests:** 388 green (361 at entry + 27 P009B) · **Build:** SwiftPM clean + device BUILD SUCCEEDED + installed

## New files (this phase)

| File | Contents |
|---|---|
| `packages/GuardianKit/Sources/GuardianCore/OctopusRuntimeV2.swift` | runtime core: profiles, domains, availability, evidence record, expert protocol, input bundle, health, registry, capability resolver, resource governor, cache, bus, ledger, calibration skeleton |
| `packages/GuardianKit/Sources/GuardianCore/MetaBrainV2.swift` | InputSanitizerV1, Tier1IdentityHandoffConsumerV1, GuardianMetaBrainV2 (route law), MetaBrainRouteV2 |
| `packages/GuardianKit/Sources/GuardianCore/ExpertArmsV1.swift` | the 10 expert arms (reusing P002–P006 provider outputs + real P003 Lexicons) |
| `packages/GuardianKit/Sources/GuardianCore/CrossModalGraphV1.swift` | CrossModalExpertGraphV1, ContentUnderstandingStateV1, ContentDNACandidateV2 |
| `packages/GuardianKit/Sources/GuardianCore/P009BCorpusV1.swift` | rights-clear corpus (17 scenarios × seeds) + runScenario harness |
| `packages/GuardianKit/Sources/GuardianCore/ExternalAssetAuditV1.swift` | §19 license-provenance audit record + P009B ledger (zero new external assets) |
| `packages/GuardianKit/Tests/GuardianCoreTests/P009BExpertMeshTests.swift` | 27 tests covering the §39 families |
| `Gen8/GuardianIntelligenceHUD.swift` | §25 DEBUG-only HUD (live mesh, real routing display) |

## Modified files

| File | Change |
|---|---|
| `packages/GuardianKit/Sources/GuardianCore/ContentItemGroupingV1.swift` | legacy V1 engine `@available(*, deprecated …)` — audit-reproducibility only (D-0020) |
| `Gen8/GuardianLabView.swift` | mounts HUD under Developer Mode + `#if DEBUG` |

## Evidence chain

- Entry: Phase C independent audit = `PASS — P009A IDENTITY FOUNDATION LOCKED; GO TO P009B`
  (docs/audit/GEN8_PHASE_C_CLOSEOUT_AUDIT_REPORT.md).
- Lab: full suite 388/388; TUNE failures=0 (1 defect found+fixed pre-freeze), HELD-OUT/STRESS/OOD
  failures=0 run-once.
- Device: Debug build + install succeeded (iPhone 14 Pro Max, iOS 26.6). In-app HUD visual proof and
  owned-media runs: user-gated, NOT_MEASURED (see P009B_DEVICE_VALIDATION.md).
- Dual-evidence (D-0016): Intelligence side partially evidenced (lab); Device-health side OPEN.

## Epistemic status

`EXPERT_MESH: IMPLEMENTED + LAB TESTED · DEVICE-OPERATIONAL: UNVERIFIED · SCORE: OFF ·
EXTENSION_TIER1_LITE: UNAVAILABLE · FUTURE_SHARED_TIER1: BLOCKED · H1: OPEN`
