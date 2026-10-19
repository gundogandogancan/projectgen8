# GEN8 — TEST METHODOLOGY AUDIT (Independent Red-Team Audit)

Auditor: independent fresh-context audit session (Claude Fable 5, Claude Code), 2026-10-19. No prior conversational context; markdown reports not trusted as ground truth.

## 1. Independent test run

Command: `cd packages/GuardianKit && swift test`
Result: **323 tests executed, 0 failures, 0 unexpected** (XCTest; plus an empty swift-testing pass). Matches the P009A-R1 claimed count of 323. No test modifications were made before the run. (After the audit, 3 auditor-authored integrity tests + adversarial probes exist in files prefixed `AUDIT_` — these are NOT part of the project's 323.)

Skip/gating sweep (recomputed):
- `XCTSkip`: 27 occurrences in 11 files — ALL in GuardianMediaTests (14) and GuardianIntelligenceTests (13); **zero in GuardianCoreTests**. Mostly legitimate capability guards (AVAssetWriter/Vision/NLEmbedding/Speech availability). One suspect: `GuardianMediaTests/WholeVideoAnalyzerTests.swift:67` converts a functional detection failure ("no flagged segment detected in this run") into a skip — a real-assertion escape hatch.
- `#if`: 9, all `canImport(...)` guards in Media/Intelligence tests. No `#if os`, no `ProcessInfo.environment` gating, no `XCTSkipIf` anywhere in Tests/.

## 2. Do tests exercise production code?

YES for the core engines. GuardianCoreTests instantiate the real production classes used by the broadcast extension: `ShotSegmenterV5`/`BoundaryEvidenceAccumulatorV5` (frozenV5), `ContentItemGroupingEngineV1/V2` (frozenV1/frozenTier0/frozenTier1), `DeferredItemCoalescerV1`, `LocalAdmissionCache`, `ShieldEvaluatorV2.standard()`, `ContentDNAV1`. No parallel fake engine implementations were found in GuardianCoreTests.

Qualifications:
- `SchedulerTests` run the real scheduler/pipeline but on `GuardianLabFixtures` whose scores are a deterministic formula over fixture-authored inputs — scheduler mechanics are tested, intelligence is not.
- `ShieldV2Tests` stub the semantic embedding distance with an injected closure; real embedding behavior is tested separately (and skipped where NLEmbedding is unavailable).
- `TrainingRunTests` writes artifacts into the repo (`ml/training/runs/`) at test time — a test that mutates the working tree.

## 3. Fixture/corpus generation — independence assessment

All five generators (BoundaryFixtureHarnessV3, RealisticFixtureGeneratorV4, FixtureGeneratorV5, Tier0CorpusV1, HierarchicalCorpusV1) follow the same scheme: **tune(seed 0) / held-out(seed 1) / stress(seed 2) are the SAME named scenario templates with a small scalar offset (`seed × 0.04…0.07`) plus a different deterministic RNG stream.** A code comment admits it: "different derivatives, same structure" (BoundaryFixtureHarnessV3.swift:53).

Classification per corpus:
| Corpus | Classification |
|---|---|
| V3/V4/V5 boundary tune vs held-out | **Weakly independent** (same scenario families, scalar offset + reseed) |
| V5 cadence-stress | Weakly independent (reuses held-out seed 1) |
| Tier0CorpusV1 tune/held-out/stress | **Weakly independent** |
| Tier0CorpusV1 `deviceLike(seed 3)` | **Contaminated/overfit risk as "device" evidence**: statistically reconstructed from the FAILING P009A device log (65 CUT/6 CROSSFADE/1 SWIPE shape) with separability ENGINEERED IN (`minSep` forced to 0.30 for rapid-swipe items, 0.15 otherwise — Tier0CorpusV1.swift:191-193). Valid as an engineering regression harness; INVALID as a predictor of device transfer. |
| HierarchicalCorpusV1 (P009A) | Weakly independent; additionally the held-out gate ran only in the APP_FULL_TIER1 profile — the project's own history lock calls this a "METHODOLOGY FAILURE + PROFILE TRANSFER FAILURE" |
| DeviceMotionProfileV1/V2 parameters | Derived from prior device FAILURE logs (sources cited in code: v3 log, v4 log) — fixtures constructed after seeing device failures. Legitimate as failure-driven engineering; it means "held-out PASS" cannot be read as independent validation. |

Circularity note: FixtureGeneratorV5 uses `gap = p.cutDistanceMedian` (0.37) as inter-segment distance while the V5 detector tests `prePostDistance >= 0.6 × cutDistanceMedian` — generator and detector share constants, so synthetic boundaries are detectable partly by construction.

## 4. Threshold provenance (leakage)

- `ContentBoundaryPolicyV5.frozenV5` and `ProfileAwareItemGroupingPolicyV2.frozenTier0/frozenTier1` are the init defaults, with code comments "FROZEN on TUNE only" referencing P008A_R4_TUNE_RESULTS / P009A_R1_TUNE_RESULTS. Tune docs record the selection path on seed 0 and state held-out was not inspected during tuning.
- **Within-generation discipline (tune→freeze→one held-out run) appears genuinely followed** and is locked in validation-history docs with SHA-256'd device logs.
- **Across generations there is structural leakage by design:** every new policy generation (V3→V4→V5, grouping v1→v2) was built in direct response to the previous generation's device/held-out failures, and the fixture distributions themselves were re-derived from those failure logs. The corpus was also edited during tuning at least once (P009A_R1_TUNE_RESULTS "scenario-24 spread fix"). Consequence: lab PASS numbers measure self-consistency with a failure-informed synthetic distribution, not device generalization. The repo's own device history (synthetic PASS → device FAIL at every revision: 406/168 over → 5 under → 477 over → 73 over → 57 → 73-items-0-merges → 72-items-1-merge) empirically confirms this.

## 5. Gate-softening findings (specific)

1. **Recall carve-out:** `Tier0CorpusV1.newRecallExpected` excludes author-labeled `ambiguousOK` boundaries from the recall denominator; raw held-out recall 0.850 is reported/gated as "expected" 1.000 (P009A_R1_TIER0_HELDOUT_RESULTS.md). The raw number is printed but not gated.
2. **Floors below aspirations and just below known results:** P008AR4SegmenterV5Tests asserts recall ≥ 0.85 / F1 ≥ 0.88 while the stated §14 targets are R ≥ 0.90 / F1 ≥ 0.92 and the achieved held-out recall was 0.882 (a documented "NARROW MISS" that the assert floor accommodates).
3. **Comment/gate mismatch:** cadence-invariance comment says "≤10%", code asserts ≤ 0.20 (2× looser).
4. **Relaxed adversarial gate with in-test apologia:** sustained-high-motion test allows `committed <= 2` where 0 was the design intent.
5. **Print-only "tests":** three `testTuneScanExploratory` methods assert only non-emptiness; they are tuning scans living permanently inside the suite (declared exploratory — acceptable but inflates the "323 passing tests" optics; similarly several benchmark tests print without gating).
6. **Tautological assertion:** `P009AR1Tier0Tests.swift:197` — `XCTAssertTrue(... || true)` can never fail; line 199 near-vacuous.
7. **Easy-mode fixtures in places:** e.g. P007D hamming-distance fixtures use maximally separated signatures (64 vs threshold 10).

## 6. Can acceptance tests pass via fixture-specific logic?

No hardcoded engine outputs were found; labels are by construction in generators and the engines under test are the production classes. However, the combination of (a) failure-log-derived fixture parameters, (b) engineered separability in `deviceLike`, and (c) shared constants between generator and detector means acceptance gates CAN pass without implying device transfer — which is exactly the repeatedly observed outcome. The project documents this honestly in its own validation-history locks.

## 7. Dataset verdict table

| Dataset | Verdict |
|---|---|
| Boundary/grouping tune corpora (seed 0) | Independent enough for engineering iteration only |
| Held-out corpora (seed 1) | Weakly independent (perturbations, not new distributions) |
| Stress corpora (seed 2) | Weakly independent; useful for monotonic safety properties (0 false merges etc.) |
| deviceLike (seed 3) | Contaminated/overfit risk if presented as device-predictive; fine as regression harness |
| TrainingRunner golden text set (20 hardcoded sentences) | Toy; any metric from it is not evidence of model quality |
| Real-device logs (7 artifacts) | The only distribution-valid evidence in the repo |

## 8. Overall methodology verdict

The engineering hygiene (frozen policies, predeclared gates, one-shot held-out, SHA-locked device logs, honest FAIL verdicts) is markedly better than typical self-reported projects, and the device-gate culture caught every synthetic-to-real transfer failure. But the lab evidence class remains SELF-REFERENTIAL-SYNTHETIC: tune and held-out are near-duplicates, device-like is failure-informed and separability-engineered, and no lab gate has yet predicted a device PASS. Until per-channel real distributions are measured (the proposed GEN8_EVIDENCE_BUILD step — see main report §7 for whether current code can even capture them), lab PASS results should be treated as regression protection, not validation.
