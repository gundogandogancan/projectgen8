# GEN8 — INDEPENDENT RED-TEAM AUDIT REPORT (P000 → P009A-R1)

## 1. AUDITOR SESSION / MODEL

- **Fresh-context continuation auditor.** This report was produced by a clean Claude Code session (model: Claude Fable 5) with no prior conversational context about the project, completing the remaining work of a prior clean-context auditor whose session hit a limit after producing four partial audit docs and two AUDIT_-prefixed test files. All prior auditor outputs were spot-verified against the repo (not trusted blindly); every number repeated below was either recomputed by this session or cross-checked in this session's own test run.
- Environment: macOS (Darwin 25.4.0), Xcode 26.6 toolchain, Swift 6.3; package at `packages/GuardianKit`. No device was touched; no installs performed. READ-ONLY on all production source/policies/fixtures/history; only `docs/audit/` files were written.
- Sandbox limits hit this session (recorded honestly): `shasum` and several compound shell forms were denied; SHA-256 verification was therefore performed via the spec-sanctioned auditor-authored test (`AUDIT_ArtifactIntegrityTests`, CryptoKit), executed by this session.
- Key commands this session: `swift test` (3 runs; totals identical), `grep`/`tail` recomputations over `docs/evals/artifacts/*`, `git status`/`git log`, direct pbxproj + source reads.

## 2. REPO / BUILD INTEGRITY

- **Git:** branch `main`, exactly ONE commit (`725153a Initial Commit` — Xcode template). `git status`: 3 modified tracked files (pbxproj, ContentView, Gen8App) and EVERYTHING else untracked — all GuardianKit sources/tests, both extensions, docs, ml, artifacts, SHA locks. **The entire evidence chain is unanchored in VCS** (finding H1).
- **Targets (pbxproj, objectVersion 77, synchronized folders):** 3 targets — `Gen8` (app), `GuardianControlExtension` (appex), `GuardianBroadcastExtension` (appex). Both appex embedded in the app ("Embed Foundation Extensions"). Membership via `PBXFileSystemSynchronizedRootGroup` with only `Info.plist` excepted — so `SampleHandler.swift` is in the broadcast target, widget files in the control target; `Shared/GuardianLiveShared.swift` explicitly compiled into app+control targets.
- **Package wiring:** GuardianCore → all 3 targets; GuardianIntelligence → app only; **GuardianMedia → linked nowhere** (lab-only, matches claims).
- **Signing/entitlements:** `DEVELOPMENT_TEAM = 47XQMQZLF6` (6 configs), bundle ids `com.gen8.guardian.dev[.GuardianBroadcast|.GuardianControl]`, `CODE_SIGN_STYLE = Automatic`, `INFOPLIST_KEY_NSSupportsLiveActivities = YES` (app + control). **No `CODE_SIGN_ENTITLEMENTS`, no `.entitlements` files anywhere** → App Group claim cannot be real (confirmed in code: stale `group.com.aymedo.Gen8` + silent `.standard` fallback).
- **ReplayKit path:** broadcast Info.plist declares `com.apple.broadcast-services-upload` + `RPBroadcastProcessModeSampleBuffer`. Public API only — a repo-wide scan for `dlopen/dlsym/NSClassFromString/performSelector/private` patterns in production sources returned ZERO hits. No hidden capture path; no silent-start code.
- **No stale duplicate engine bypass:** the extension uses `ShotSegmenterV5` + `ContentItemGroupingEngineV2(.frozenTier0, .extensionFastTier0)` + `DeferredItemCoalescerV1` — the same canonical classes the tests exercise. Older generations (V2/V3/V4, grouping v1) still exist as source but are not referenced by the extension.
- `xcodebuild` of the app was not run this session (not permitted); compile-state of the current working tree for the iOS targets is therefore NOT re-verified here. Device logs dated 2026-10-19 imply it built then.
- CLAUDE.md "environment facts" are stale (claims old bundle id and no team) — contradicted by pbxproj.

## 3. CLAIM LEDGER SUMMARY

Full ledger: `GEN8_CLAIM_EVIDENCE_LEDGER.csv` (30 rows, P000 → P009A-R1 + cross-cutting rows), produced by the prior auditor and spot-verified this session (rows 17-24 and 27-29 re-checked against raw artifacts/sources — all consistent). Headline distribution:
- VERIFIED or VERIFIED-incl.-honest-FAIL: 8 rows (notably every device-run claim, including the FAIL verdicts).
- VERIFIED_WITH_LIMITATIONS: 12 rows (lab-only scope, fixture-formula scores, vacuous extension shield eval, etc.).
- PLAUSIBLE_NOT_PROVEN: 2 (Live Activity render; P009A-R1 root-cause channel attribution).
- CONTRADICTED: 1 — "the proposed evidence-build run will measure per-channel distributions" **as currently implemented** (code emits no such values; see §7).
- UNSUPPORTED as product capability: 2 (self-improving/learning; child/family). NOT IMPLEMENTED: cross-platform.
- The project's self-reports are notably honest: every synthetic-PASS→device-FAIL was reported as FAIL by the project itself. No fabricated device numbers were found anywhere (see §6).

## 4. TEST SUITE INDEPENDENT RUN

- Command: `cd packages/GuardianKit && swift test` (run three times this session; identical totals).
- **Result: 336 executed, 1 failure, 0 unexpected, 0 skipped** (plus an empty swift-testing pass). 336 = **323 project tests (ALL PASS)** + 13 auditor-authored AUDIT_ tests (12 pass, 1 fail).
- The single failure is the prior auditor's deliberately **stricter-than-documented** probe `testAUDIT_rapidSwipeAndMontageStressNoFalseMerge`: zero-false-merge assertion over the FULL seed-2 stress corpus → `mergeFP 1 ≠ 0`, offending slice `bright-to-bright` (overall xM/item 0.0189 there). The project's own documented gates (montage newFP=0, rapid mergeFP=0, xM/item ≤ 0.005 on seed-1 held-out) all PASS, including inside this probe. This is a genuine red-team finding (C6), not a project test regression.
- 0 tests skipped at runtime on this machine (the 27 `XCTSkip` guards are capability gates that did not trigger; all in Media/Intelligence tests). No env-var or `#if os` test hiding found; 9 `#if canImport` guards only.
- Tests exercise the real production classes used by the extension (ShotSegmenterV5, GroupingV2 frozenTier0, coalescer, cache, ShieldEvaluatorV2, ContentDNA). Known soft spots (verified): tautological assert at `P009AR1Tier0Tests.swift:197` (`|| true`), print-only tune scans, floors below stated targets, recall carve-out (details in GEN8_TEST_METHODOLOGY_AUDIT.md §5 — all spot-confirmed).

## 5. EVAL METHODOLOGY / LEAKAGE

Verified conclusions of `GEN8_TEST_METHODOLOGY_AUDIT.md` (spot-checked in generator sources this session):
- Tune(seed 0)/held-out(seed 1)/stress(seed 2) are the SAME scenario templates with scalar offsets + reseeded RNG → **weakly independent**; a code comment admits "different derivatives, same structure".
- `Tier0CorpusV1.deviceLike(seed 3)` is statistically reconstructed from the FAILING P009A device log with separability engineered in (`minSep` forced 0.30/0.15) → **contaminated as device-predictive evidence**; acceptable only as a regression harness.
- Within-generation discipline (freeze on tune → one held-out run, SHA-locked) appears genuinely followed; across generations there is structural leakage by design (each fixture generation is derived from the previous device failure).
- Empirical confirmation: **no lab gate has ever predicted a device PASS** (406/168→5→477→73→57→73/0-merge→72/1-merge). Lab PASS = regression protection, not validation.
- Historical pattern "synthetic PASS → physical FAIL" is thus CONFIRMED and is the central epistemic fact of this project.

## 6. DEVICE EVIDENCE RECOMPUTATION

Full detail: `GEN8_DEVICE_EVIDENCE_RECOMPUTATION.md` (prior auditor) — **independently re-verified this session**:
- **SHA-256: all 7 artifacts match their locks** — recomputed via CryptoKit in this session's own test run (`AUDIT_SHA … match=true` × 7). `shasum` itself was sandbox-denied; the test route is the recorded substitute. Prefix-chain property (each artifact byte-extends the previous) re-verified: 7/7.
- Headline numbers recomputed from raw logs this session with grep (commands recorded in the recomputation doc; session boundaries at lines 1/91/337/344/823/898/957/1105 of the cumulative log):
  - P009A-R1 final session: **58 NEW + 14 AMBIGUOUS + 1 SAME = 73 decisions, items=72** ✓; merge distribution 0.00×4, 0.05×1, 0.16×4, **0.21×41 (p50)**, 0.32×1, **0.37×19 (p75)**, 0.58×2, **0.68×1 (max)** ✓; `score=UNKNOWN` 73/73 ✓; COALESCE count 0 ✓; FINISHED counters verbatim (frames=3391, analyzed=72, reuse=1, cheapP50/95=1.372/2.887 ms, peak 30.2 MB, thermal nominal) ✓.
  - P009A session: **31 NEW + 42 AMBIGUOUS, 0 SAME, `openedNew=false` count = 0 (zero merges)** ✓; thermal 45 fair / 28 nominal ✓.
  - V3: **477** TRANSITION lines ✓; V5: **57** SEGMENT lines ✓; R1: **5** TRANSITION lines ✓; aHash-era: frames 525+3033=3558, changes 406, analyzed 168 ✓ (cross-file totals reconcile: 146 ITEM = 73+73 etc.).
- **Every claimed device number matches the raw artifacts exactly.** What the artifacts CANNOT support: device precision/recall (manual ~20-item ground truth, no stored labels), CPU/energy (zero Instruments artifacts), per-channel Tier-0 evidence (never captured), and any claim that on-device "analysis" involved real perception (it was a nil-OCR shield lookup against one demo rule).

## 7. LATEST ROOT-CAUSE CLAIM AUDIT

Claim under audit (P009A_R1_DEVICE_VALIDATION_RESULTS.md:31-33): real projection/histogram/theme continuity "essentially ABSENT" across real cuts.
1. **Channel values actually present in the device log (session 8):** per-SHOT `in=` transition type (64 CUT/7 CROSSFADE/1 SWIPE/1 SESSION_START — directly measured), `swipe=`, `repl=` replacement ratio, `reasons=`; per-ITEM aggregate `merge=` (S) and `new=` (N), state, openedNew, provisional. **ZERO per-channel fields** — grep for `proj|hist|theme|chrome|channel|EVIDENCE` over session 8 returns 0; `evidence=false` on all 8 BROADCAST_STARTED lines.
2. **Directly measured conclusions:** the S/N distributions themselves; the cut/crossfade/swipe mix; zero coalesces; 1 SAME at S=0.58.
3. **Inferred from aggregates:** ALL per-channel attribution. Under the frozen Tier-0 weights (wTheme .20, wProj .20, wHist .15, wCadence .15, wChrome .10, wRegional .10, wCutPrior .05; ceiling 0.95 — matches the logged `sameCeiling=0.95`), S=0.21 ⇒ raw≈0.20, which decomposes into at least five distinct subsets ({theme}, {projection}, {chrome+regional}, {histogram+cutPrior}, {cadence+cutPrior}). The 41 p50 decisions cannot be attributed.
4. **Verdict on "projection/histogram/theme absent": PARTIALLY SUPPORTED, NOT PROVEN.** What IS provable from the aggregate: at the p50 decisions at most ONE of the heavy channels fired (their joint presence sums past 0.20), and across all 73 decisions the three channels never jointly dominated. "Essentially absent" as a per-channel statement remains an inference. Classification: PLAUSIBLE_NOT_PROVEN.
5. **Does the proposed evidence-build run close the gap? NOT as currently implemented — CONTRADICTED.** `SampleHandler.swift:75-78` under `GEN8_EVIDENCE_BUILD` emits only segmenter MOTION scalars (energy/scale/disc/repl/postMs/swipe/committed). No code path emits theme/projection/histogram/chrome/regional/cadence values or fired-evidence lists at grouping decisions. A derived-only telemetry addition is REQUIRED first (the repo's own doc, step 1 of its plan, says the same). This is blocker B1.

## 8. PRIVACY

Verified by direct source inspection (detail: GEN8_PRIVACY_RESOURCE_CAPABILITY_AUDIT.md §1, spot-confirmed this session):
- **Network/cloud/analytics: structurally absent** — zero URLSession/sockets/analytics imports in any production source. Nothing can leave the device.
- **Raw frames: ephemeral** — locked read-only, luma sampled in place into 64-bit region hashes + 8-bin projections; never retained/encoded/serialized. No OCR/speech/audio/title code exists in the extension process.
- **Local persistence (flagged):** two ALWAYS-ON derived proof-log writers in production code (`gen8_crossapp_proof.log` in the extension container — the artifact source itself — and `gen8_la_proof.log` in the app), plus unified-log mirroring at `privacy: .public`; the logged `persistToDisk=false` is true only of raw frames → mislabel (C1). Shield store persists user rules + typed derived features (atomic, file-protected, cascade delete) — legitimate.
- No transcript/title/history persistence anywhere. Device-container sweep: NOT_TESTABLE_IN_THIS_SESSION (no device access); code-consistent.

## 9. RESOURCE / PERFORMANCE

- Directly measured on device (from raw logs): cheap-path p50/p95 per session (0.125→2.887 ms band across policies; summary-only, in-extension bounded 4000-sample buffer), memory high-water 29.2–30.3 MB vs ~50 MB budget, coarse thermal per decision (one FAIR period: 45/73 decisions in the P009A session), 8/8 clean broadcast start/finish.
- **`firstTrustworthyMs` (p50 0.073 ms recomputed) is shield-lookup latency on a nil-OCR envelope vs one demo rule — NOT semantic-understanding latency.** Milestone docs currently label it as first-decision latency (no misrepresentation found in docs), but the measurement is near-vacuous and must be re-based when real perception enters the extension.
- NOT captured anywhere: CPU, energy, queue depth, dropped frames (zero Instruments/xctrace artifacts — admitted in docs). Pack/bundle size claims not recomputed this session (xcodebuild unavailable) → PLAUSIBLE_NOT_PROVEN.
- Lab micro-benchmarks reproduced live in this session's run: shield ~15.3 µs/eval flat 10→1000 rules; durable store lookup p50 ~14 µs, cold load 81 ms @10k rules.

## 10. PLATFORM CAPABILITY TRUTH

| Capability | Truth class |
|---|---|
| ReplayKit user-consented cross-app observation | implemented + physically proven (8 SHA-locked device sessions) |
| Silent ReplayKit start impossibility | correctly platform-enforced; no circumvention code (verified absence) |
| Automatic session continuity | planned at best; each broadcast is one session |
| Live Activity / Dynamic Island | implemented (real ActivityKit + DynamicIsland widget, NSSupportsLiveActivities=YES) but render **not physically proven**; only a static on/off flows; no content state reaches any surface |
| App Group cross-process transfer | **broken**: no entitlements, stale `group.com.aymedo.Gen8`, silent `.standard` fallback (C2) |
| App/window identity | not exposed by ReplayKit; code honestly reports surface=UNKNOWN |
| OCR/speech/audio in extension | absent by design (Tier-0); lab/app only |
| Control Center toggle | real iOS-18 ControlWidget code; not device-proven |

## 11. OCTOPUS / THIN-APP TRUTH

- `OctopusBrainSkeletonV1.swift` (GuardianMetaBrain, ExpertRegistry, router, evidence bus, provenance ledger, capability resolver, learning signal bus) + `ModelPack.swift` (registry, manifest, lifecycle manager): types exist, contract tests pass, header self-describes as SKELETON.
- **Referenced ONLY by tests** (grep: sole non-test occurrence is the defining file). The extension uses `ResourceGovernorV1` purely as write-only counters. No runtime inference flows through any of it.
- Verdict: **contract-only skeletons — honest, but NOT implemented intelligence.** Bundle-size measurement for packs: no artifact.

## 12. SELF-IMPROVING INTELLIGENCE TRUTH

- Evidence class achieved: **NONE of the four tiers.** Not LOCAL_LEARNING_IMPLEMENTED (no user experience updates any model/policy at runtime; TrainingRunner is a lab toy whose output model is never loaded), not GLOBAL_SIGNAL_COLLECTION_IMPLEMENTED (no producer calls the bus outside tests; no network exists), no federated/DP process, no proven improvement.
- Consent gate is functional at the contract level — independently re-proven by this session's run of auditor probe 4: `globalAggregate` without `optInGlobal` is rejected and not stored; local-scope default consent passes.
- Verdict: honest interfaces; "self-improving" is UNSUPPORTED as a capability claim today.

## 13. SAFETY / CALIBRATION

- Score/confidence separation + UNKNOWN gating: real and enforced in types (`PersonalSuitabilityScoreV1`: score=nil + band UNKNOWN unless coverage ≥ min AND calibrationValid; calibrationValid has no true source today). All 146 device decisions logged `score=UNKNOWN` (hardcoded literal in the extension — honest, since no scoring pipeline runs there).
- Calibration: pilot honestly FAILED (false-safe 0.50 → POOR). **No trustworthy calibrated score exists.** (C4)
- H1 violence/gore/explicit visual safety: honest stub `sensitive-visual-unavailable-v0` returning `.unavailable` (verified in source). (C5)
- ChildAgePolicy: no implementation found in production sources; precedence fixtures only. (C5)
- Shield: engine real and fast in lab; extension wiring vacuous (demo rule + nil OCR) (C3). Corrupted/tampered store rejected safely (auditor probe 7 passed: garbage → typed error; tampered checksum → `corrupted`; missing file → safe empty).
- Positive-state leak across ambiguous identity: auditor probe 3 passed — AMBIGUOUS never inherits safe admission state and is provisional. However auditor probe 9 found **1 cross-item false merge** in the seed-2 `bright-to-bright` stress slice — a false merge DOES inherit (`safeAdmissionInheritance=true` on SAME), so this is the one measured mechanism by which a safe state could cross distinct items (synthetic evidence; C6).

## 14. CODE QUALITY / DEAD PATHS

- TODO/FIXME/HACK in production sources: **0**. `fatalError`: **0**. No debug flags that alter decision behavior (the only conditional is the evidence-telemetry flag, additive logging).
- Dead/stale-but-present: ContentBoundaryV2/V3, ContentSegmenterV4, ContentItemGroupingV1 (superseded generations kept as source; only V5+V2-Tier0 wired); GuardianMedia linked nowhere; Octopus skeleton test-only; SuitabilityFusionV1 has no non-test caller.
- Hardcoded acceptance risks found: `demo-spoiler` rule in the extension; `score=UNKNOWN` literal; tautological assert (P009AR1Tier0Tests.swift:197); assert floors below stated targets; recall carve-out; cadence comment/gate mismatch; print-only tune scans. None of these fabricate a PASS of a documented device gate; they soften lab-gate optics (H2).

## 15. ADVERSARIAL TEST RESULTS

13 auditor-authored tests (AUDIT_-prefixed, in-target, clearly labeled), executed by this session:
- **12 PASS / 1 FAIL.** Contracts that held: AMBIGUOUS no-inheritance; no-consent global signal rejected; pack checksum tamper → verify fails + lifecycle QUARANTINED; no-rollback activation refused; thermal degradation contract (optional deep work blocked at FAIR+; safety-critical until SERIOUS); corrupted/tampered shield store rejected with typed errors; cache version-mismatch + TTL-expiry misses; 2×50 session start/stop churn fully deterministic; montage newFP=0 and rapid-swipe mergeFP=0 per documented gates.
- **FAIL (red-team finding C6):** full seed-2 stress corpus produced 1 cross-item false merge (`bright-to-bright`; corpus-wide xM/item 0.0189). The project never documented a gate over this corpus — the gate gap is the finding.
- Informational probes (asserted nothing, by design): a pixel-identical different item over a cut after long dwell → SAME (S=0.84, inherits) and the segmenter sees NO boundary on an identical-frame "cut" — Tier-0 is structurally blind to same-looking different items; an item whose internal cuts break every Tier-0 channel → all NEW (over-split, never false-merge) — expected fail-safe direction.

## 16. EVIDENCE MATRIX

| Subsystem | Implementation | Lab Evidence | Physical Device Evidence | Independent Audit Verdict | Blocking Issue |
|---|---|---|---|---|---|
| Observation (ReplayKit) | real, wired | n/a | 8 SHA-locked sessions | VERIFIED | — |
| Privacy | real constraints | tests | logs consistent; no container sweep | VERIFIED (code-level) | C1 proof logs |
| Shot segmentation (V5) | real, wired | pass (weak independence) | 57-segment run matches; GT approximate | VERIFIED_WITH_LIMITATIONS | manual GT only |
| Item grouping (Tier-0 V2) | real, wired | pass | 72 items / 1 merge / economy 1.4% = FAIL (honest) | VERIFIED incl. FAIL | B1/B2 evidence gap |
| Temporal hierarchy | real (lib) | pass | shots+items logged separately | VERIFIED_WITH_LIMITATIONS | — |
| ContentDNA | real (lib) | pass | none | VERIFIED_WITH_LIMITATIONS | — |
| Cache | real (lib) | pass + audit probes | reuse=1 observed | VERIFIED | — |
| Shield | engine real; ext wiring vacuous | pass (µs bench) | demo rule only | VERIFIED_WITH_LIMITATIONS | C3 |
| Multimodal perception | lab only | pass | none | VERIFIED_WITH_LIMITATIONS | not in extension |
| Speech | honest unavailable/lab | capability-gated | P007B-era claims only | PLAUSIBLE_NOT_PROVEN | — |
| Audio (SoundAnalysis) | lab only | pass | none | VERIFIED_WITH_LIMITATIONS | — |
| Score calibration | types + failed pilot | pilot FAIL (honest) | all UNKNOWN | VERIFIED as NOT ACHIEVED | C4 |
| Dynamic Island / Live Activity | compiled | policy tests | lifecycle claims; no render proof | PLAUSIBLE_NOT_PROVEN | C2 app group |
| Model packs | contract skeleton | contract tests | none | contract-only | — |
| Local learning | not implemented (toy trainer) | toy tests | none | UNSUPPORTED | — |
| Global learning | not implemented | consent-gate tests | none | UNSUPPORTED | — |
| Family/child | not implemented | precedence fixtures | none | UNSUPPORTED | C5 |
| Cross-platform | none | none | none | NOT IMPLEMENTED (planned) | — |

## 17. VERIFIED PROJECT PROGRESS

Counting rules (explicit): only independently verified subsystems count; weights = equal per subsystem over the 17 iOS-relevant matrix rows (cross-platform excluded for the beta path); credit 1.0 = device-verified working, 0.5 = device-run but failing its own goal OR lab-verified production-wired, 0.25 = lab-only/compiled-unproven, 0.1 = honest stub/contract-only, 0 = absent. Documentation volume counts for nothing.
- **iOS Guardian beta path: ≈ 30% (band 22–38%).** Device-proven: observation, privacy envelope, resource boundedness. Device-run but not yet correct: shot/item identity (the core bet — currently FAIL on economy). Missing entirely for a beta: calibrated score (failed), real extension shield, H1 safety, Live Activity content flow, App Group, session continuity, CPU/energy evidence.
- **Full Universal Gen8 vision (multi-platform, packs, learning network, family): ≈ 8% (band 5–12%).** Everything beyond the iOS observation+identity spine is contracts, stubs, or absent.
- Uncertainty bands reflect: manual ~20-item ground truth on all device runs, zero CPU/energy artifacts, unproven Live Activity render, and unanchored VCS state.

## 18. CRITICAL FINDINGS

1. **B1 — per-channel Tier-0 evidence telemetry does not exist in code**; the proposed evidence run cannot close the root-cause gap without a derived-only telemetry addition first (`SampleHandler.swift:75-78` emits segmenter MOTION only; `evidence=false` on all 8 recorded sessions).
2. **B2 — the "projection/histogram/theme essentially absent" root-cause is an inference from aggregate S/N**, under-determined at the frozen weights (≥5 valid decompositions of S=0.21). Do not re-tune from it; measure first.
3. **C1 — always-on derived proof-log writers + `privacy: .public` mirroring + misleading `persistToDisk=false` label** in production code paths.
4. **C2 — App Group broken and silently faked** (no entitlements, stale `group.com.aymedo.Gen8`, silent `.standard` fallback).
5. **C3 — extension shield evaluation is vacuous** (hardcoded demo rule vs always-nil OCR); `match=`/`firstTrustworthyMs` telemetry near-meaningless as protection evidence.
6. **C4 — no trustworthy calibrated score exists** (pilot false-safe 0.50 = POOR); correctly gated to UNKNOWN everywhere.
7. **C5 — H1 visual safety is a stub and no child/age capability exists** (both honestly declared).
8. **C6 — measured Tier-0 false-merge under stress** (auditor probe: 1 cross-item merge, `bright-to-bright`, xM/item 0.0189 on seed-2) — the one mechanism by which a safe admission state can cross distinct items; documented gates do not cover this corpus.
9. **H1 — the entire evidence chain is untracked in git** (single template commit); SHA locks alone are not tamper-evidence (mitigated by the verified 7/7 byte-prefix chain).

## 19. NON-CRITICAL FINDINGS

- Gate-softening debt: recall carve-out (raw 0.850 reported as expected 1.000), assert floors below stated §14 targets, cadence comment ≤10% vs gate ≤0.20, tautological assert (`|| true`), print-only tune scans inside the 323-test count, relaxed sustained-motion gate (≤2 where 0 was intent).
- `TrainingRunTests` mutates the repo (`ml/training/runs/`) during `swift test`.
- Superseded engine generations (V2/V3/V4, grouping v1) remain compiled into GuardianCore.
- Doc-internal test-count inconsistency at P002 (81 vs 83); "BEFORE" artifact is two concatenated sessions (correctly summed in docs).
- CLAUDE.md environment facts stale (bundle id/team) vs pbxproj.
- `deviceLike(seed 3)` corpus has separability engineered in — must never be cited as device-predictive.
- No broadcast interruption/resume evidence exists either way (8/8 clean pairs only).

## 20. GO / NO-GO

The device evidence is faithful (every recomputed number matches raw SHA-locked artifacts), failures were self-reported honestly, privacy constraints are structurally real, and the architecture (frozen sensor + profile-aware grouping + UNKNOWN-first gating) is internally coherent. The single thing blocking better Tier-0 decisions is MISSING MEASUREMENT, not a contradicted claim — and the correct next step is exactly the measured evidence session, whose first act must be adding derived-only per-channel telemetry (B1), then one scripted device run producing per-shot cross-cut channel distributions (theme distance, projection corr, histogram L1, chrome delta, regional, cadence, fired-evidence list) under `GEN8_EVIDENCE_BUILD`, SHA-locked and committed (H1). C-class findings gate the beta, not this step. No "production ready" claim is supportable today, and none is made.

`GO — CONTINUE TO MEASURED TIER-0 EVIDENCE CALIBRATION`
