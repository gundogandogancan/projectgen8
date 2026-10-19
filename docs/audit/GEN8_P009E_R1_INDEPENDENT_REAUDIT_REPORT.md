# GEN8 — P009E-R1 INDEPENDENT CLEAN-SESSION RE-AUDIT REPORT

**Auditor:** fresh-context independent red-team session (no builder state inherited; builder prints/claims never trusted — every number independently reproduced with auditor-owned implementations before acceptance)
**Mandate:** `docs/audit/prompts/GEN8_P009E_R1_INDEPENDENT_REAUDIT_MANDATE.md` (S0–S20 executed in full)
**Audit target commit:** `8dfdbf0fe34b9fab11a418ada0c30a20f3366fdc` (= `origin/phase/p009e-r1` at import time = `gen8-p009e-r1-audit-candidate^{commit}`)
**Date:** 2026-10-20

---

## 1. GIT / REPO INTEGRITY — PASS

- `gen8-p009e-r1-audit-candidate` is an annotated **tag object `5c1e2671cf22000e30eaa6211793d7ec220c6a6b`** → `cat-file -t` = `tag`; `rev-parse …^{commit}` = `8dfdbf0fe34b9fab11a418ada0c30a20f3366fdc`. Tag message: "P009E-R1 audit candidate (617/617)".
- Branch `phase/p009e-r1` now carries ONE commit after the target: `fb713247e90dda7820c43fd67a838996651f7ba6` — `git diff 8dfdbf0..fb71324 --stat` shows **only** `docs/audit/prompts/GEN8_P009E_R1_INDEPENDENT_REAUDIT_MANDATE.md | 24 +` (docs-only, verified). The audited tree = the target commit's tree + that mandate file; working tree clean at audit start.
- Prior chain intact: `57c8662` (P009E engineering lock merge) → `960b033` (ledger) → `a87aa0c` (P009E-R1 impl) → `8dfdbf0` (marker). No rewrite/force/amend observed; `fetch` introduced nothing unexpected. Remote `origin = git@github.com:gundogandogancan/projectgen8.git` exists (the P009E-era "no remote" blocker is resolved at the remote-existence level; pushing remains out of audit scope).
- **R1 production-source blast radius (verified by `git diff 57c8662..8dfdbf0 --stat`): exactly 10 files** — 3 production source files (`P009ECalibrationDatasetV1.swift` +80, `CalibrationCoreV1.swift` ±11, `PersonalSuitabilityScoreV2.swift` ±3), 1 HUD label line, 1 test file (`P009EScoreTests.swift` V1→V2 + divergence test), the frozen AUDIT8 artifact, and 4 docs. **Everything else in the tree is byte-identical to the independently audited P009E lock** — Tier-0, C6, policy engines, shield, governor, mesh, world model all untouched (load-bearing for the S11–S13 regression findings below, in addition to the fresh probes).
- **Frozen AUDIT8:** `docs/audit/AUDIT8_P009EProbes_ORIGINAL_LOCKED.swift.txt` SHA-256 recomputed = `930a4cc4c1c08b9b5a92084e1c0af6eddbcb28a0b536a4f5506185fec6019792` (matches lock), and the ACTIVE `Tests/GuardianCoreTests/AUDIT8_P009EProbes.swift` is **byte-identical** to it (`cmp` + SHA + in-suite probe `testA9_12`). **The builder's claim "no AUDIT8 inversions needed" is TRUE** — V1 stayed frozen, so every AUDIT8 pin (declared=59 / auditorResolved=54 / builderEffective=52 / exact phantom set) still passes against V1 unmodified.

## 2. TEST RESULTS (S14)

- Baseline suite at the target: **617/617 PASS** (first full run, before any auditor file existed).
- Combined suite with the fresh auditor family: **635 tests, 0 failures** (`Executed 635 tests, with 0 failures (0 unexpected)`), i.e. **617 builder + 18 AUDIT9 probes**. Tree stayed clean after full runs.
- Fresh family: `Tests/GuardianCoreTests/AUDIT9_P009ER1Probes.swift` (ADD-ONLY; no production source or existing test modified). One probe (`testA9_09`) initially failed on an auditor over-assertion at the *component* level; the production behavior was investigated, classified as finding **A9-R1-F1** (below), and the probe was corrected to assert the actual locked invariant. **No probe required a production source change.**

## 3. S2 — DatasetRegistryV2 REFERENTIAL INTEGRITY — PASS

- **59/59 pairs resolve** under the auditor's independently re-derived strict resolver (probe `A9_01`; `AUDIT9_V2 resolved=59/59`). Split populations: TRAIN 26 / CAL 12 / HELD_OUT 8 / STRESS 4 / OOD 4 / SENTINEL 5.
- **V1→V2 delta is EXACTLY the 7 remapped pairs** (5 phantom corrections + 2 alias materializations), order-preserving, splits/sources/labels of untouched pairs pinned unchanged: `pd-persuasive-ad→tc-persuasive-ad ×2`, `pd-manipulative-urgency→tc-manipulative-urgency`, `pd-calm-nature→tc-calm-nature` (adult pair re-profiled to `adult-shield-mortality` to avoid a duplicate item×profile identity — verified no duplicate exists dataset-wide), `tc-persuasive-ad-like-urgency→tc-intent-ambiguity`, `hd-ocean-calm-alias→hc-ocean-calm`.
- **No alias indirection remains anywhere in V2** (itemID + corpus scanned). Adversarial constructions: dangling ref → nil; alias-to-missing → nil; alias-loop → nil (single-level resolver, cannot recurse) — in BOTH the auditor resolver and the builder harness resolver (`A9_02`). No hidden fallback silently heals a bad reference.
- V1 remains frozen as audit evidence: phantoms still present and still unresolvable; both dead ALIAS pairs still present (`A9_15`); AUDIT8 pins green against it in the same run (`AUDIT8_RESOLUTION declared=59 auditorResolved=54 builderEffective=52 phantom=5`).
- Residual (A9-R1-F2, LOW): the builder harness `setUp` still uses `guard … else { continue }` — the silent-drop *mechanism* survives even though nothing drops today; only AUDIT9/AUDIT8 pins would catch a future regression.

## 4. S3 — oodStatus EVIDENCE-ONLY — PASS (A8-F3 closed)

- Verified over **all 59 resolved pairs** on both paths (`A9_08`): `oodStatus` is a pure function of `m.oodFlags` — `oodFlags>0` ⇒ `"OOD"`/`"OOD-flagged(n)"`, never `"in-distribution"`; `oodFlags==0` ⇒ `"in-distribution"`, never invented OOD. No second truth source.
- State separation verified: unsupported locale (`ja`) → `language-slice-unsupported` + in-distribution (UNSUPPORTED ≠ OOD); empty content → `knowledge-UNKNOWN` + flags=0 (UNKNOWN ≠ OOD); poisoned inputs → typed abstention + OOD flags honestly surfaced; missing calibrator → `UNCALIBRATED_SLICE` (UNAVAILABLE ≠ OOD); nil score always presents `UNKNOWN` + typed reason, never positively.
- OOD-split rows observed: `od-empty-content reason=knowledge-UNKNOWN flags=0`, `od-unsupported-language-child flags=1 status=OOD`, `oc-poisoned-values flags=2 status=OOD`, `od-poisoned-input flags=1 status=OOD` — all abstain.

## 5. S4 — ECE INDEX BINNING — PASS (A8-F4 closed)

- Production `eceAndBins` now assigns by index (`min(bins-1, max(0, Int(p*bins)))`): **every prediction in exactly one bin — no drop, no double-count** — verified on exhaustive fixtures (`A9_05`): conf=0/1 extremes, exact decimal boundaries, repeated identical confidences, 1-per-bin, all-in-one-bin, uneven occupancy, empty input; counts always sum to n; ECE hand-recomputed to 1e-12 agreement; tiny fixture hand value (preds .25/.25, labels T/F → ECE 0.25) exact.
- INFO (A9-R1-F3): out-of-domain preds are silently clamped into edge bins (never dropped), and binary-fp boundary placement puts e.g. 0.3 in bin [0.2,0.3) deterministically. Harmless on current data (calibrator outputs are strict logistic values); harden the domain contract before real-data calibration.

## 6. S5 — MULTI-PROFILE REAL DIVERGENCE — PASS (A8-F5 closed), one finding

- Builder's rewritten `testSameDNAMultipleProfiles` now asserts DISTINCT STATE VALUES on fear-band content + adult≠child — no longer vacuous (code read + green in suite).
- Auditor fresh run (`A9_09`): fear-band world model → `adult-neutral=CAUTION` vs `parent-child9-tr=AGE_CAUTION` (plus `parent-teen14-strict=AGE_CAUTION`) — genuine divergence via the real policy path on ONE world model.
- **Strong-risk universal protection intact at the decision level:** fresh severe-violence scenario → **STRONG_PROTECTION for all 5 profiles**, no positive interpretation, score capped ≤10 under veto.
- **FINDING A9-R1-F1 (LOW):** on that severe item, the *component* `childOutcome` reads `AGE_ALIGNED` for the 13+ profiles (`parent-teen14-tr`, `parent-teen14-strict`) because violence/gore is H1-UNAVAILABLE (unbandable: age bands exist only for sensitiveNews/fearThreat/manipulationAttention), the `h1RequiredUnderAge` fail-closed law stops at <13, and the teen fail-closed lexicon covers only the sexual sentinel class. **No end-to-end false-safe exists** (state/score/interpretation all protective, probe-asserted), and under-13 correctly reads `AGE_UNKNOWN_REVIEW`. But a subordinate verdict "AGE_ALIGNED" co-existing with STRONG_PROTECTION on gore content is a component-honesty gap that must be addressed (violence-class teen banding or an UNBANDED/NOT_EVALUATED outcome label) before any real-world claim. No safety loosening occurred — this behavior predates R1 (the age engine is untouched since the P009D lock) and is newly *observed*, not newly introduced.

## 7. S6 — ANNOTATION / ADJUDICATION — PASS (A8-F6 closed by honest relabeling)

- `CalibrationDatasetRegistryV2.annotationMode = "SIMULATED_DUAL_SLOT(single-author; engineering-only — not independent humans)"` — the simulation is DECLARED in code and in `P009E_ANNOTATION_RUBRIC.md` (R1 section), never presented as independent human calibration (`A9_10`).
- Adjudication rule rewritten to match practice: "permitted on any disagreement; REQUIRED when |A−B| ≥ 2". Data satisfies the declared rule (every |A−B|≥2 pair would require adjudication — currently vacuous since max disagreement in data is 1; every adjudicated pair has a genuine disagreement). This is a rule-text correction honestly labeled as such in the rubric doc ("truth corrections"), not a reinterpretation of a historical failure as green — the original mismatch remains on record in the P009E audit report and in frozen AUDIT8.
- Disagreement preserved (>3 pairs); no agreement metric overclaimed anywhere.

## 8. S7 — DEMO FUSION WEIGHTS HONESTY — PASS (A8-F7 label closed; wiring residual carried)

- HUD header now reads "Score (P009E — INTERNAL · **DEMO FUSION WEIGHTS, not the fitted artifact**; PRODUCTION SCORE DISPLAY: OFF)" (file-read probe `A9_12`). The label is **load-bearing, not cosmetic**: the demo constants (−1.6/1.12/0/−1) now genuinely differ from the live V2 fitted artifact (−1.83/1.44/−0.19/−1.00/−1.15) — probe-asserted.
- Repo-wide sweep: **zero** occurrences of "production calibrated / scientifically validated / real-world validated / population validated / calibrated personal score" in any source (grep + in-suite HUD scan).
- Residual (A9-R1-F6, INFO): the HUD still constructs an empty `CalibrationRegistryV2` → the score row can never display a number (NIL + reason only). Truthful as a DEBUG display; wire to the fitted artifact when a production path is ever authorized.

## 9. S8 — PRIOR 8-FINDING MATRIX (none vanished)

| ID | Sev | Original claim (P009E audit) | Claimed R1 fix | Fresh probe | Result | Residual | Truth class | Next action |
|---|---|---|---|---|---|---|---|---|
| A8-F1 | MED | 5 declared pairs reference non-existent P009D scenarios; silently skipped; docs misdescribe as "abstentions" | V2 remaps to real P009C items; V1 frozen as evidence | A9_01 (59/59 + exact 7-pair delta), A9_15 (V1 phantoms preserved), AUDIT8 pins green | **CLOSED** | harness silent-drop mechanism remains (A9-R1-F2) | VERIFIED | keep AUDIT9 pin; add harness-side resolution assert next hygiene pass |
| A8-F2 | MED | 2 ALIAS pairs never execute (alias in `corpus`, resolver checks `itemID`); effective 52/59 | V2 uses direct references; no alias indirection | A9_01/A9_02 (no ALIAS in V2; alias loop/missing fail closed; builder+auditor resolvers agree) | **CLOSED** | none | VERIFIED | none |
| A8-F3 | LOW | scored path hardcoded `oodStatus:"in-distribution"` | derive from `m.oodFlags` on scored path | A9_08 (all-59 both-path scan; contradiction cases) | **CLOSED** | none observed | VERIFIED | none |
| A8-F4 | LOW | ECE bin predicates overlap at exact decimal boundaries (latent double-count) | index-based exactly-one-bin assignment | A9_05 (exhaustive fixtures; hand recompute to 1e-12) | **CLOSED** | fp-edge placement + silent clamp (A9-R1-F3, INFO) | VERIFIED | domain-guard preds before real data |
| A8-F5 | MED-LOW | builder multi-profile test vacuous (counted profileID-prefixed strings) | test rewritten to assert distinct STATES + adult≠child | A9_09 (fresh divergence + strong-risk universal) | **CLOSED** | component-level teen AGE_ALIGNED observation (A9-R1-F1, LOW — pre-existing behavior) | VERIFIED | teen banding/label before real-world phase |
| A8-F6 | LOW | adjudication rule "only when ≥2" violated by data; "dual annotators" = single author | rule corrected + SIMULATED_DUAL_SLOT declared in code+docs | A9_10 (rule-vs-data law; honesty strings) | **CLOSED (honest relabel)** | simulated annotation acceptable ONLY for engineering scope | VERIFIED_WITH_LIMITATIONS | real-world phase requires true independent annotators |
| A8-F7 | LOW | HUD hardcoded demo weights implied live fitted pipeline; drift risk | "DEMO FUSION WEIGHTS, not the fitted artifact" label | A9_12 (label present; demo≠fitted now true; forbidden-claim sweep) | **LABEL CLOSED** | empty registry → row never shows a number (A9-R1-F6, INFO) | VERIFIED_WITH_LIMITATIONS | wire real artifact or keep NIL-only |
| A8-F8 | LOW | thinnest cross-split margin J=0.75 (legal, <0.8) | none claimed | A9_04 (fresh Jaccard over executed V2 set) | **UNCHANGED** — worst now TRAIN/`tc-manipulative-urgency` ~ SENTINEL/`hd-cross-language-en-config-tr-content` J=0.75 (sentinel never fitted → no tuning leak); calm-family TRAIN~CAL pair J=0.00 | thin margin carried | VERIFIED_WITH_LIMITATIONS | margin policy for real-data corpus |

## 10. S9 — CALIBRATION TRUTH (independently reproduced; no gate relaxed)

Auditor-owned resolution + refit + metric loops (strict half-open binning, own Brier/AUROC/MAE), fresh brains, fresh item IDs:

| Claim | Builder | Auditor reproduction | Verdict |
|---|---|---|---|
| Full resolution | 59/59 | 59/59 (strict resolver; zero drops) | MATCH |
| TRAIN fit | n=26, MAE .628, w=[−1.83, 1.44, −0.19, −1.00, −1.15] | n=26, MAE 0.628, weights match ≤0.02; refit **bit-exact deterministic** on repeat | MATCH |
| CAL ordinal MAE | .743 (n=12, 0 abst) | 0.743, n=12, abst=0 (no denominator exclusion) | MATCH |
| HELD_OUT_FINAL | .559 (n=7, 1 abst) | 0.559, n=7, abst=1, typed (`hc-educational-cooking: policy-REVIEW`) | MATCH |
| Risk ECE | .250 UNMET-UNRELAXED | 0.250 (auditor binning AND builder binning; all 12 preds assigned exactly once) | MATCH — **genuinely poor; UNMET stands; not relaxed anywhere** |
| Brier | .139 | 0.139 | MATCH |
| AUROC | .94 | 0.938 | MATCH — high ranking + poor calibration is consistent (small n); **AUROC does not license any "calibrated" claim** |
| Sentinel falseSafe | 0 | 0 (5/5 executed; + rename and benefit-wrap challenges fail closed) | MATCH |

- **Leakage probes:** item-level split disjointness holds (builder detector + auditor map; detector *sensitivity* proven by injected violation); semantic cross-split worst J=0.75 < 0.8; no exact/translation duplicate; P009B `CorpusSplitLeakageAuditorV1` clean; sentinel split never enters any fit (structural + probe).
- **Held-out contamination counterfactual:** refit including HELD_OUT_FINAL moves the artifact by Σ|Δ| = **0.2128** → the TRAIN-only exact reproduction is load-bearing; no post-hoc held-out tuning. Risk calibrator (en) re-fit reproduces the registered calibrator exactly.
- **Aggregation masking:** per-locale CAL slices tr MAE 0.555 (n=5) / en 0.877 (n=7) — the 0.743 aggregate hides a locale asymmetry (recorded, A9-R1-F5 INFO; slices honestly underpowered). Simpson-type protect-label law verified globally: across all 59 pairs, no label-0 pair ever scores in the aligned band or presents positively; child-9 label≤1 pairs never ALIGNED.
- Honest context: CAL MAE **worsened** 0.580→0.743 when the dataset defects were fixed — the direction the prior audit predicted; the builder reported the worse number instead of hiding it. ECE target ≤0.05 remains UNMET and is reported unmet.

## 11. S10 — CLASSIFICATION CEILING — RESPECTED

Everything above is **ENGINEERING CALIBRATION MACHINERY VERIFIED (with limitations)**. Zero PROJECT_OWNED_REAL / LICENSED_RIGHTS_CLEAR items (55 synthetic + 4 structural; `supportsRealWorldClaims == false` probe-asserted). Nothing in this report is a production / scientific / real-world / population / age / multilingual validation claim, and no such claim exists in the repo (swept).

## 12. S11–S13 — REGRESSION INVARIANTS — PASS

- **S11 Tier-0:** `CapabilityResolverV2.permittedDomains(.extensionFastTier0) == [.temporal]` (no cheap-channel semantics); `extensionTier1Lite`/`futureSharedTier1` empty (UNAVAILABLE/BLOCKED); frozen grouping policy revision `item-grouping-policy-v2-extension-tier0` unchanged (`A9_16`); zero Tier-0 source changes in the R1 diff; no threshold tuned toward item counts.
- **S12 historical bugs:** prevDwellMs device-defect fix still documented+active in `ProfileAwareGroupingV2` (untouched since lock); no ungated `print(` in any GuardianKit production source (full file-walk probe `A9_17` — release logging OFF); **C6 bright-to-bright protection present, active, unweakened and LOAD-BEARING**: fresh auditor value pairs never merge/inherit, and the independence guard blocks 64 would-merge grid cases (`AUDIT9_C6 loadBearingCases=64`), alongside the untouched AUDIT2/PHASEC probes in the same green run.
- **S13 legacy invariants:** UNKNOWN-first + nil-score-first (A9_08/A9_12-family asserts); no uncalibrated production display (`productionDisplayAllowed()==false`, P009B skeleton refusing, gate CLOSED 6/10 unmet); safety precedence + Hard Shield unfusable (veto caps ≤10/≤25 probe-held); missing≠negative (UNAVAILABLE dims fail closed, H1 under-13 law held); stale firewall (score cache version-axis invalidation — AUDIT8 re-green); no unsupported-language hallucination (`ja` abstains); no raw-media persist + no networking primitives anywhere in GuardianKit (`A9_17`); governor/thermal untouched by diff; unavailable experts honest; frozen history intact (AUDIT3/5/7/8 actives and locks unchanged this phase; AUDIT8 byte-identical).

## 13. S15 — DEVICE / PERF / PRIVACY / SECURITY CLASSIFICATION

| Axis | Status |
|---|---|
| Build | VERIFIED earlier phases (no R1 claim made; package builds + 635/635 on macOS host) |
| Install | Claimed build+install from P009E (unchanged); not re-proven here |
| Launch / path-executed | **PENDING, user-gated §23** — honestly not claimed anywhere |
| Latency / CPU / mem / energy / thermal | **NOT_MEASURED** on device (declared); lab micro-benchmarks only (shield µs-range, in-suite) |
| Privacy | Repo-wide scan clean: no URLSession/URLRequest/NWConnection/CFSocket in GuardianKit (probe-enforced), no analytics/telemetry endpoints, no calibration/training upload path, no persistent sensitive logs, no raw media retention (shield store = encrypted-at-rest rule file with `FileProtectionType.complete`), no transcript leakage (score explanation fields structured + <200 chars, test-held), no debug leakage into release (no ungated print; HUD `#if DEBUG`) |
| Security | Lab-only posture: poisoned/malformed inputs abstain (OOD rows); no secrets found; no device pen-test performed or claimed |

## 14. S17 — 25-ROW SUBSYSTEM TRUTH MATRIX

| # | Subsystem | Truth class | Key evidence |
|---|---|---|---|
| 1 | Dataset V1 (frozen) | VERIFIED (as frozen evidence) | 59 declared; defects preserved unresolvable; AUDIT8 pins green |
| 2 | Dataset V2 (live) | VERIFIED | 59/59 resolve; exact 7-pair delta; no dup identity; no alias |
| 3 | Referential integrity | VERIFIED | dangling/alias-loop/alias-missing fail closed both resolvers |
| 4 | Split independence | VERIFIED_WITH_LIMITATIONS | item-disjoint + detector sensitivity proven; worst J=0.75 thin; cross-phase reuse erosion declared |
| 5 | Annotation | VERIFIED_WITH_LIMITATIONS | SIMULATED_DUAL_SLOT single-author DECLARED; engineering-only |
| 6 | Adjudication | VERIFIED_WITH_LIMITATIONS | R1 rule consistent with data; REQUIRED-branch vacuous on current data |
| 7 | MetricsEngine | VERIFIED | exactly-one-bin; exhaustive fixtures; hand recompute 1e-12 |
| 8 | MAE | VERIFIED (LAB_ONLY numbers) | .628/.743/.559 reproduced independently |
| 9 | ECE | VERIFIED-UNMET (LAB_ONLY) | 0.250 reproduced; ≤0.05 gate UNMET-UNRELAXED |
| 10 | AUROC | VERIFIED (LAB_ONLY) | 0.938; ranking ≠ calibration, stated |
| 11 | False-safe | VERIFIED | 0/5, all sentinels executed; rename + benefit-wrap closed |
| 12 | OOD handling | VERIFIED | status = pure f(evidence flags) both paths; typed abstentions; no conflation |
| 13 | Multi-profile | VERIFIED_WITH_LIMITATIONS | real state divergence; strong-risk universal at STATE level; A9-R1-F1 component gap (teen AGE_ALIGNED label) |
| 14 | Fusion | VERIFIED | deterministic TRAIN-only; contamination counterfactual Δ=0.2128 |
| 15 | HUD | VERIFIED_WITH_LIMITATIONS | DEBUG-only; DEMO label truthful + load-bearing; row never renders a number; §23 pending |
| 16 | Score admission | VERIFIED | no numeric field in admission state (type law); vetoes dominate; nil-first |
| 17 | Tier-0 | VERIFIED | temporal-only capability truth; frozen revision; zero R1 diff |
| 18 | C6 | VERIFIED | fresh pairs never merge; guard load-bearing (64 cases) |
| 19 | Privacy | VERIFIED (lab scope) | no networking/telemetry/upload/raw-retention; probe-enforced |
| 20 | Security | VERIFIED_WITH_LIMITATIONS | lab-only; poisoned inputs abstain; no device pen-test |
| 21 | Resource governor | LAB_ONLY | untouched by R1; device cost NOT_MEASURED (D-0016 open) |
| 22 | Thermal | UNAVAILABLE (NOT_MEASURED) | no device evidence exists or is claimed |
| 23 | Physical-device evidence | UNVERIFIED / OPEN | build+install earlier; §23 user-gated run pending |
| 24 | Real-world readiness | BLOCKED | zero real data; gate CLOSED 6/10 unmet, truth strings verified |
| 25 | Presentation readiness | BLOCKED | ECE .250 UNMET (S16 law); glyph/motion OFF everywhere |

CONTRADICTED rows: **none**. OPEN rows: #23 (physical-device evidence; user-gated).

## 15. FRESH FINDINGS (AUDIT9)

| ID | Sev | Finding |
|---|---|---|
| A9-R1-F1 | LOW | Teen (13+) component `childOutcome` reads AGE_ALIGNED on strong-violence content: violence/gore is H1-UNAVAILABLE (unbandable), `h1RequiredUnderAge` stops at <13, teen fail-closed lexicon covers only the sexual sentinel class. **No end-to-end false-safe** (STRONG_PROTECTION state for all 5 profiles, score ≤10, no positive interpretation — probe-held); pre-existing behavior (age engine unchanged since P009D lock), newly observed. Fix (violence-class teen banding or an UNBANDED/NOT_EVALUATED component label) is a REAL-WORLD-CALIBRATION entry requirement. |
| A9-R1-F2 | LOW | Builder harness `setUp` retains the silent `guard … continue` drop mechanism; nothing drops today (59/59) and AUDIT9/AUDIT8 pins would catch regressions, but the production-side harness has no self-assertion. |
| A9-R1-F3 | INFO | ECE index binning silently clamps out-of-domain preds into edge bins; binary-fp boundary placement (e.g. 0.3 → bin [0.2,0.3)) is deterministic/exactly-once but mathematically off-boundary. Harden the [0,1] domain contract before real-data calibration. |
| A9-R1-F4 | INFO | Worst cross-split Jaccard remains 0.75, now TRAIN `tc-manipulative-urgency` ~ SENTINEL `hd-cross-language-en-config-tr-content` (sentinel never fitted → no tuning leak). Carried thin-margin concern (ex-A8-F8). |
| A9-R1-F5 | INFO | CAL locale slices asymmetric: tr MAE 0.555 (n=5) vs en 0.877 (n=7); aggregate 0.743 masks it. Underpowered slices honestly declared; real-data phase needs per-slice gates. |
| A9-R1-F6 | INFO | HUD score row (empty registry + labeled demo constants) can never display a number — truthful NIL-only DEBUG display; carried A8-F7 wiring residual. |

No CRITICAL or MEDIUM fresh findings. No false-safe, no overclaim, no leak, no veto bypass, no display leak, no gate relaxation.

## 16. S16 — PRESENTATION / GLYPH / MOTION

**BLOCKED** regardless of verdict (ECE 0.250 ≥ 0.05 UNMET). Verified no glyph/motion/presentation code was added in R1 (diff scope) and production display refuses at every layer.

## 17. CARRIED BLOCKERS (none vanished)

C2 App Group · C3 extension shield vacuity · C5 H1 visual (evidence-backed registry, still OPEN) · ChildAgePolicy device proof pending · Tier-0 burst-window merge residual · proof-log beta decision · LAB_ONLY/UNAVAILABLE experts (8/11 safety dimensions UNAVAILABLE) · §23 user-gated P009E device run · D-0016 device-health evidence for mesh/world-model/score paths · production score gate 6/10 unmet · push/PR to remote remains a user action (remote now EXISTS; the old "no remote" blocker is superseded).

## 18. S18 — VERDICT

**PASS — P009E-R1 ENGINEERING LOCKED; REAL-WORLD CALIBRATION NEXT; PRODUCTION SCORE / PRESENTATION / GLYPH / MOTION REMAIN BLOCKED**

(Explicitly NOT claimed: production calibrated · scientifically validated · real-world validated · population validated.)

## 19. S19 — PLAN-ONLY: REAL-WORLD CALIBRATION PROGRAM (no feature work authorized)

1. **Rights-clear corpus:** acquire PROJECT_OWNED_REAL and/or LICENSED_RIGHTS_CLEAR media (TR+EN), every item in a provenance ledger + rights ledger (license, scope, expiry, revocation path); no scraped/platform content.
2. **Annotation:** ≥2 genuinely independent human annotators per pair (not pseudonym slots), recruited/trained on a versioned handbook (`suitability-rubric-v2` with examples, edge cases, TR/EN parity); annotator IDs, blinding, time-stamps recorded.
3. **True dual annotation + adjudicator:** independent labels collected blind; disagreement preserved; a third adjudicator (not A/B) resolves per the declared rule (REQUIRED |A−B|≥2, permitted on any disagreement); IRR (Cohen/Krippendorff) computed and gated before fitting.
4. **Slices predeclared:** age bands (child/teen/adult), Shield-on/off, safety-class, TR/EN, content domains — with minimum n per slice; no slice may be dropped post hoc.
5. **Splits:** item-level + semantic-level (near-dup J-gate with a safety margin > the current 0.75 worst case) disjoint TRAIN / CALIBRATION / HELD_OUT_FINAL; HELD_OUT_FINAL sealed (hash-locked) before any fit; leakage audit re-run by an independent session.
6. **Predeclared metrics/gates (hard, unrelaxable):** false-safe = 0 on an expanded sentinel set (incl. violence-class teen sentinels per A9-R1-F1); risk ECE ≤ 0.05 overall and ≤ 0.07 per slice; MAE targets per slice; abstention-rate band; AUROC reported but never a gate substitute.
7. **Pre-entry fixes:** A9-R1-F1 (teen component label/banding), A9-R1-F2 (harness self-assert), A9-R1-F3 (ECE domain guard) — all closed before fitting on real data.
8. **Device end-to-end evidence:** §23 user-gated run + D-0016 dual-evidence (intelligence + device-health: CPU/GPU/mem/battery/thermal/wakeups) on physical hardware; privacy re-scan on device builds.
9. **Rollback:** fitted artifacts versioned + reversible; production display stays OFF until the full gate (incl. independent final audit) opens it explicitly.
10. **Independent final audit** of the real-data calibration (fresh session, this mandate's structure) before any classification upgrade.

## 20. AUDIT ARTIFACTS

- `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT9_P009ER1Probes.swift` — 18 fresh probes (ADD-ONLY).
- This report.
- Key commands: `git fetch` · `git cat-file -t/-p gen8-p009e-r1-audit-candidate` · `git rev-parse …^{commit}` · `git diff 8dfdbf0..fb71324 --stat` · `git diff 57c8662..8dfdbf0 --stat` · `shasum -a 256` + `cmp` on AUDIT8 frozen/active · `swift test` (×2 full: 617/617 baseline, then 635/635 with AUDIT9).
