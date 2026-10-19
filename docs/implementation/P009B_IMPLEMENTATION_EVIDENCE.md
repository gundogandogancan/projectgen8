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

---

# P009B-R1 addendum — audit findings closeout (2026-10-19)

**Entry verdict:** `FIX CRITICAL P009B FINDINGS` → all findings closed. **Suite:** 450/450 (388 + 27 original P009B + 25 AUDIT3 [4 asserts inverted per declared manifest] + 35 R1 closure + 2 real-trace − overlaps).

| Finding | Fix | Evidence |
|---|---|---|
| F1 deep-lease burn | `DeepAnalysisLeaseStateV1` 9-state machine in `ResourceGovernorV2`; transient releases, meaningful dedupes, permanent suppresses, retries bounded (3), cancel/stale retry | testF1* (5 tests) + inverted AUDIT3 probe |
| F2 split aliasing | `P009BCorpusV2` seedless authored banks (24/16/10/8/6) + `CorpusSplitLeakageAuditorV1` (exact dup / alias / J>0.8 near-template; detector itself tested); CAL fingerprint `aa6bd546ae28278f` never executed | testF2* (4 tests); gates 0 failures run-once |
| F5 availability inflation | 5-tier enum; ALL arms honestly `REAL_IN_PROCESS_LAB_ONLY`; `RealObservationToExpertInputAdapterV1` (+audio variant) wires REAL Vision OCR/classify/NL/SoundAnalysis → mesh with NO synthetic fallback; real trace test proves provider→adapter→expert→MetaBrain→graph→state with measured latency | P009BR1RealProviderTraceTests (real OCR read rendered text); testAvailabilityTruthMatchesRuntime |
| F6 cache firewall | entries bind identityRevision/schema/privacy/TTL/modelVersion/generation; mismatch → MISS+invalidate/REANALYZE; `reportIdentityCollision` strong→invalidate, ambiguous→forced reanalysis; low-info TTL 5s; old-gen reuse explicitly reported | testF6* (7 tests) |
| F7 DNA authority | `IdentityResolutionSnapshotV1` + authoritative mint (authority/profile/generation/split/conflict/evidence-marker/foreign-item checks); legacy entry point hardened too | testF7* (3 tests) + inverted AUDIT3 probe |
| Input sanitizer | `ExpertInputSanitizerV2` pre-execution; flags → unknown reasons; fuzz+property tests | testSanitizer* (3 tests) + inverted AUDIT3 probe |
| Latency | monotonic clock (injectable); route/per-expert/cache/graph/state measured; `OperationLatencyRegistryV1`; nil → NOT_MEASURED | testLatency* + inverted AUDIT3 probe; real trace p50 0.338ms |
| Deadline | pre-schedule gate + late-result discard + cache-past-deadline + FAIR compose + identity race | testDeadline*/testExpired*/testOnTime* (3 tests) |
| Asset ledger | `ExternalIntelligenceAssetAuditV2` full governance fields; NOT_APPLICABLE_OS_FRAMEWORK/NOT_MEASURED sentinels; 6 records lawful | testAssetAuditV2CompleteAndLawful |
| Corpus families | sarcasm-vs-literal, cheerful+distressing, risky→benign (risk survives), montage, repeated-scene (cache law), B-roll | testRequiredFamiliesPresentInTune + TUNE gate |
| F3/F4 docs | STRESS/OOD false claims retracted; V1 count corrected to 18 everywhere incl. code print; doc↔code consistency TESTED | testDocCodeConsistency; testV1CorpusCountTruth |
| HUD truth | SOURCE banner (REAL IN-PROCESS vs SYNTHETIC/DERIVED LAB), actual tier display, NOT_MEASURED latency, REAL-capture button through the adapter | GuardianIntelligenceHUD.swift; device build+install OK |

**Build defect found by R1 tests (fixed pre-freeze):** honest `.unavailable` records (itemID nil) defaulted
`itemProvisional=true` and wrongly blocked lawful mints — identity-bearing-only rule applied.

**AUDIT3 handling:** original file SHA-frozen at `docs/audit/AUDIT3_P009BProbes_ORIGINAL_LOCKED.swift.txt`
(`3c5ae4be…`); exactly 4 defect-characterization asserts inverted, each annotated `R1-FIX INVERSION`,
declared in advance in `docs/audit/P009B_R1_AUDIT_FINDINGS_LOCK.md`. No probe weakened or deleted.
