# P009B-R1 — Audit Findings Lock (immutable evidence anchor)

**Date:** 2026-10-19 · **Entry verdict:** `FIX CRITICAL P009B FINDINGS` · **Prompt:** `docs/audit/prompts/PROMPT_P009B_R1_AUDIT_FINDINGS_CLOSEOUT.md`

## SHA-256 locks

| Artifact | SHA-256 |
|---|---|
| Independent P009B audit report (`docs/audit/GEN8_P009B_INDEPENDENT_AUDIT_REPORT.md`) | `f01bba52aaeddbf731ab1f118f614a724b77c119d09bd1e42256b0b0d440d1b7` |
| **ORIGINAL** `AUDIT3_P009BProbes.swift` (frozen copy: `docs/audit/AUDIT3_P009BProbes_ORIGINAL_LOCKED.swift.txt`) | `3c5ae4be495c759ca179627d945afb7c4c49ddbae49daf76ef4d725665b607b1` |
| Audit-artifact commit | `d61ca15` (parent: implementation `de58f0c`; prior lock `4ce238f`) |
| 388-test pre-audit state | commit `de58f0c` (full suite 388/388; reproduced by auditor) |
| 25 auditor probes | contained in the locked original above (25 test funcs) |
| Phase-C immutable: `GuardianBroadcastExtension/SampleHandler.swift` | `89ac5dba66a2d0bd8dd7b499ae401e80f95fdbb3ed71dc0bcc7a61fe58ee0153` (unchanged since lock) |
| Phase-C immutable: `PhaseCContractsV1.swift` | `b6d14ed4bde28b4c3157df3aa5f1dd8a8688356ca8bfad886352227940367335` |
| Phase-C immutable: `ProfileAwareGroupingV2.swift` | `d97428f6eb261d11166890c5cd2c5db708665ff5c9d14627052f8cc8a3f698c6` |
| Phase-C closeout tests (incl. untouched C6 probe) | `9b4eea81c5e2049505402758f797b631e504054f302cd97c9019ee3f0847ab8c` |

## Characterization-probe inversion manifest (declared BEFORE any fix)

Five AUDIT3 probes are **defect characterizations**: they `XCTAssert` the *defective* behavior with
`AUDIT-FINDING (defect/limitation)` messages (the auditor's own header: "CHARACTERIZATION probes assert
CURRENT behavior"). The mandated R1 fixes *invert* that behavior, so after a correct fix these exact
assertions MUST flip. Per "do not modify auditor tests to make them pass": no probe is weakened or
deleted; the original file is SHA-frozen above; in the active file ONLY the assertions listed below are
inverted to lock the FIXED behavior, each annotated `// R1-FIX INVERSION`. Every other line stays
byte-identical. The re-auditor can diff the active file against the frozen original and confirm the
delta is exactly this manifest.

| Probe | Original (defect) assertion | After-fix assertion |
|---|---|---|
| `testUnavailableResultBurnsDeepDedupeBudget_PermanentBlindness` (F1) | later real input NEVER analyzed; `deep-dedupe:VISION` reason | later real input IS analyzed (`scene:cat` present); no dedupe refusal — transient UNAVAILABLE released the lease |
| `testDNAMintTrustsCallerFlag_ProvisionalEvidenceCanMintIfCallerLies` (F7) | spoofed mint returns non-nil | spoofed mint returns **nil** (evidence-level provisional markers verified) |
| `testNoExpertGuessesUnderNaNFuzz` (sanitizer) | NaN editDensity flows into vision features | NaN editDensity is stripped pre-execution; feature absent |
| `testRouteLatencyInstrumentationIsStructurallyZero` (latency) | all recorded latencies == 0 | latencies are monotonic measurements (≥ 0, not structurally pinned to 0; sample presence asserted) |
| `testLowInformationEvidencePoisonsPerItemCache` (cache TTL) | unchanged at t+1ms (still hits within low-info TTL) — **no inversion**; a NEW test proves expiry → re-analysis | n/a |
| `testStaleContextStillReceivesCacheHitsForItsOldItem` (F6) | cache hit for old-generation context of the SAME item | **no inversion** — reuse stays legal because records now bind to per-item identity revision (collision/split/revision bump → MISS); the previously "silent" reuse now emits an explicit `cache-hit-old-generation:` reason (probe does not assert reason absence) |
| `testCorpusActualScenarioCountIs18NotTheClaimed17` + `testSplitSeedsCollapseToTwoDistinctInputSets` | characterize **V1** corpus | **no inversion** — `P009BCorpusV1` is kept frozen as evidence; the rebuilt independent corpus is `P009BCorpusV2` (V1 no longer feeds any gate) |

## Rules honored

- No auditor probe deleted; no assertion weakened; inversions strengthen assertions to the safe behavior.
- Phase-C artifacts remain byte-identical (SHAs above re-verified at lock time).
- This document is append-only evidence; the ORIGINAL probe file copy is never edited.
