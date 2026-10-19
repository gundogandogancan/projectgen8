# P009A Phase C — Implementation Evidence
| file | SHA-256 | role |
|------|---------|------|
| `Sources/GuardianCore/PhaseCContractsV1.swift` | b6d14ed4bde28b4c3157df3aa5f1dd8a8688356ca8bfad886352227940367335 | provisional identity, Tier-1 handoff + buffer, shot-only record, release policy |
| `Sources/GuardianCore/ProfileAwareGroupingV2.swift` | d97428f6eb261d11166890c5cd2c5db708665ff5c9d14627052f8cc8a3f698c6 | dwell fix, EvidenceIndependenceGuardV1, inheritance profile-gate, provisional-DNA rule, shot-only evidence |
| `GuardianBroadcastExtension/SampleHandler.swift` | 89ac5dba66a2d0bd8dd7b499ae401e80f95fdbb3ed71dc0bcc7a61fe58ee0153 | provisional relation logging, handoff wiring, EvidenceBuildPolicyV1 release-off |
| `Tests/GuardianCoreTests/PHASEC_CloseoutTests.swift` | — | 12 Phase-C tests (dwell, C6 family ×10, guard units, provisional DNA, handoff, release policy) |
Build/test (2026-10-19): `swift test` **348 tests, 0 failures** — including the UNTOUCHED auditor C6 probe (now
passing by principle) and the §4-rewritten gates (safety asserts; count-quality diagnostic). Device: BUILD SUCCEEDED
(no evidence flag) + installed `com.gen8.guardian.dev`. Frozen policies NOT retuned (guard is additive safety; dwell
fix is a correctness repair). Lab quality after safety rework (diagnostic): held-out newP 1.000 / mergeP 1.000 /
xMerge 0.0000 / mergeR 0.836 / avoided 0.52; device-like mergeFP 0.
