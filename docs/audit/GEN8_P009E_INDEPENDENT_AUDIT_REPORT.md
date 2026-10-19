# GEN8 — INDEPENDENT P009E CALIBRATION / REAL SCORE RED-TEAM AUDIT REPORT

**Auditor:** fresh-context independent session (no builder state inherited; builder report NOT trusted)
**Mandate:** `docs/audit/prompts/GEN8_INDEPENDENT_P009E_CALIBRATION_AUDIT.md` (checks 1–17 executed)
**Audited object:** tag `gen8-p009e-audit-candidate` = `70fc22265efc3d7b4b39bf645dca052ae8b26d0c`, branch `phase/p009e`, clean tree
**Date:** 2026-10-20

---

## 1. AUDITOR SESSION

- Clean session; read-only first; all metrics recomputed with auditor-owned implementations before any builder print was accepted.
- Fresh probes authored in **one NEW add-only file**: `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT8_P009EProbes.swift` (15 probes). **No existing source or test file was modified.** No probe required a source change.
- Test runs: builder suite alone **602/602 PASS**; combined suite with auditor probes **617/617 PASS** (0 failures). Tree remained clean after full runs (benchmark writers did not churn the tree); the only change is the staged AUDIT8 file.
- Probe file staged with `git add`. No commit was made to the audited candidate itself; the audit report + probe file are left staged for the owner (push remains honestly blocked: `git remote -v` is empty).

## 2. GIT / REPO INTEGRITY — PASS

- `gen8-p009e-audit-candidate` → `70fc222…` on `phase/p009e`; working tree clean at audit start. **No git remote configured** — the builder's `PUSH_BLOCKED_REMOTE_UNCONFIGURED` declaration is true.
- Prior lock chain intact: `gen8-p009d-locked` = `9c049f3` **is an ancestor** of HEAD; `4ce238f` (P009A Phase-C closeout lock) **is an ancestor**; 5 commits since the P009D lock, all P009E-scoped (`3566136 → 38280f8 → daab7c3 → 6d3ec15 → 70fc222`).
- Frozen AUDIT7 original: `docs/audit/AUDIT7_P009DProbes_ORIGINAL_LOCKED.swift.txt` SHA-256 recomputed = `914b4c6adab053b4bf718ab3d0d4d8172a1a53f02bfbd9553473ae860f441423` — **matches** the declared lock.
- **AUDIT7 active-vs-frozen delta verified line-by-line: EXACTLY the 4 pre-declared inversions** of `docs/audit/P009E_ENTRY_LOCK.md` (P13/F-3 three fingerprint asserts → not-equal; P15/F-2 → `CHILD_AGE_CAUTION_PARENT_PREFERENCE`; P16/F-4 → `AGE_JURISDICTION_UNSUPPORTED` preserved; P17/F-5 → `AGE_UNKNOWN_REVIEW` + never NEUTRAL + `TEEN_SENTINEL_UNAVAILABLE_REVIEW`). No other line changed; no probe weakened or deleted.
- AUDIT3/AUDIT5 actives differ from their frozen originals only by the previously locked R1 inversion blocks (documented in `P009B_R1_AUDIT_FINDINGS_LOCK.md` / `P009C_R1_FINDINGS_LOCK.md`). AUDIT6 probes present and green.
- CAL_RESERVED bank: fingerprint probe still green — `reservedBankFingerprint() == aa6bd546ae28278f`, count 6, content byte-intact (asserted by AUDIT4/AUDIT6 probes in the same run that consumed the bank).

## 3. P009D REGRESSION — PASS

- All P009D test families + AUDIT7 (inverted per entry lock) green inside 602/602 and 617/617.
- H1 truth preserved: `SafetyDimensionTruthV1` still marks `explicitSexual`/`violenceGore`/self-harm/drugs/gambling/dangerous-behavior/profanity/sexual-themes **UNAVAILABLE** (8 of 11); no silent upgrade.
- Score/glyph production display OFF everywhere: `CalibrationRegistryV2.productionDisplayAllowed() == false` (hardcoded law), P009B skeleton untouched and refusing (`GuardianMetaBrainV2().calibration.scoreDisplayAllowed() == false`, probe-asserted), no glyph/motion code added.

## 4. F-5 TEEN-BAND VERDICT — CLOSED (verified adversarially)

Auditor reproduction (AUDIT8 `testA8_03`, fresh scenarios, fresh brains, fresh item IDs):
- Teen 14 + sentinel text ("explicit adult romance scenes compilation uncut") → `AGE_UNKNOWN_REVIEW`, state ≠ NEUTRAL, code `TEEN_SENTINEL_UNAVAILABLE_REVIEW` present, **score abstains (nil)**. The original F-5 contradiction (ALIGNED+NEUTRAL) is gone.
- Variants all fail closed: **age 13** ✓, **age 17** ✓, **age 12** (H1 law: never aligned/neutral) ✓, **TR-language trigger** ✓, **severe** ("nsfw 18+ adults only…") ✓, **educational sexual-health** → review floor stands (educational context recorded as qualifier, never erases) ✓, **unsupported jurisdiction "XX"** → `AGE_UNKNOWN_REVIEW` + `AGE_JURISDICTION_UNSUPPORTED`, never neutral ✓.
- **Mild romance without sentinel tokens** ("a sweet first date picnic story with flowers", teen 14) → NEUTRAL + AGE_ALIGNED **with zero sentinel-context labels fired** — policy-consistent (the law is a response to trigger+unavailability, not blanket teen suppression) and honest; recorded, not a defect.
- The trigger lexicon is correctly classed as ROUTING (policy response to evidence unavailability), never detection; H1 remains declared UNAVAILABLE.

## 5. SCORE SEMANTICS — PASS

- `ScoreCandidateV1` separates `score: Double?` (0–100 Personal Suitability/Admission Alignment only), `scoreConfidence` (categorical string), `evidenceCoverage` (0–1), `calibrationStatus`, `oodStatus`, `policyState` (categorical enum), reason codes, abstention reason, interpretation, full version provenance. nil score is first-class; nil presents as `UNKNOWN` with confidence `none` (probe-asserted across every resolved pair, `testA8_12`).
- `AdmissionStateCandidateV1` contains **no numeric field** (type-asserted law). Conflation attempts fail at the type level; runtime domains verified for all pairs.
- One latent honesty defect in the scored path (`oodStatus` hardcoded `"in-distribution"`) — see finding A8-F3.

## 6. DATASET / PROVENANCE — PASS WITH FINDINGS (engineering-only)

Classification of **every** declared pair (59 = item×profile):
- **SYNTHETIC_DERIVED: 55** (project-authored P009D/P009C/P009B_CAL_RESERVED/P009E_TEEN scenario inputs)
- **STRUCTURAL_ONLY: 4** (`od-empty-content`, `od-unsupported-language-child`, `oc-poisoned-values`, `od-poisoned-input`)
- **PROJECT_OWNED_REAL: 0 · LICENSED_RIGHTS_CLEAR: 0** → `supportsRealWorldClaims == false` (test- and probe-asserted).
- No real-world calibration claim found anywhere (sources, tests, 15 P009E docs, OPEN_BLOCKERS swept) — the spec §4 FAIL condition does **not** trigger. Class is consistently `ENGINEERING_CALIBRATION_ONLY`.
- **FINDING A8-F1 (MEDIUM)**: 5 of the 59 declared pairs reference P009D scenario names that **do not exist** in any P009D split (`pd-persuasive-ad` ×2, `pd-manipulative-urgency`, `pd-calm-nature` ×2) — silently skipped by the harness (`guard … else { continue }`). `docs/evals/P009E_TUNE.md` misdescribes this as "20 usable pairs after abstentions" — they are failed lookups, not abstentions. TRAIN also loses its only TR label-4 anchors (`pd-calm-nature` 4,4 / 4,3).
- **FINDING A8-F2 (MEDIUM)**: both ALIAS pairs never execute — the dataset declares the alias in the `corpus` field (`ALIAS:tc-intent-ambiguity`, `ALIAS:hc-ocean-calm`) but the harness's alias fallback checks the `itemID` prefix (dead code path). **Effective dataset = 52/59 (11.9% of declared pairs never run); effective TRAIN = 20/26; effective CALIBRATION = 11/12.** Sensitivity (auditor-measured): including the dropped calibration alias pair moves reported CAL MAE **0.580 → 0.672**. Additionally, the `itemSplitViolations` leakage detector keys on `itemID` and would be blind to alias-based cross-split duplication (no actual leak exists today — auditor probe `testA8_10` verifies alias-RESOLVED disjointness). Resolution truth is now pinned by `testA8_01` (declared=59, auditorResolved=54, builderEffective=52, phantom set exact).

## 7. ANNOTATION QUALITY — PASS WITH FINDINGS (engineering-only)

- Rubric versioned (`suitability-rubric-v1`, 0–4 ordinal, documented target "suitability of exposure given profile", not goodness). Dual annotator slots, disagreement preserved (>3 disagreeing pairs; 13 disagreements in data), adjudication field with trace, locale/profile/rubric-version on every record.
- **Labels are authored literals in source, written before fitting; they do not read model outputs — circularity structurally absent** (verified by code read: `CalibrationAnnotationV1` is data-only; fit consumes `finalLabel`).
- **FINDING A8-F6 (LOW)**: (a) documented adjudication rule "only when |A−B| ≥ 2" (struct comment + `P009E_ANNOTATION_RUBRIC.md`) is violated by the data — all 5 adjudicated pairs have |A−B| = 1; the shipped test only asserts ≥1. (b) "dual independent annotators" are pseudonym slots authored by a single builder — simulated independence. Acceptable **only** under ENGINEERING_CALIBRATION_ONLY; real calibration must use genuinely independent annotators or this becomes a FAIL.

## 8. SPLIT INDEPENDENCE — PASS (thin margins noted)

- Item-level split disjointness holds (builder test + auditor alias-resolved re-check).
- Auditor content-level cross-split audit over executed scenarios (token Jaccard, exact-duplicate, translation re-tokenization): **no violation of the declared J>0.8 law**. Worst cross-split pair: `CALIBRATION/hd-cooking-neutral-adult ~ HELD_OUT_FINAL/hc-educational-cooking` at **J=0.75** — legal but thin (A8-F8, LOW).
- P009B corpus split auditor still clean (`CorpusSplitLeakageAuditorV1.audit()` empty); CAL_RESERVED consumed for the first time in the CALIBRATION split only, content byte-intact.
- Residual (declared) limitation: cross-phase reuse — P009C/P009D items were evaluated in earlier phases, so HELD_OUT_FINAL virginity is relative to the P009E fit, not to all prior human/builder exposure. Honest for engineering scope.
- Sentinel tuning contamination: none — sentinel split never enters any fit (structural + probe).

## 9. DIMENSION CALIBRATION — PASS

- Platt calibrators fitted **on TRAIN_TUNE only** (verified by reading `P009EScoreTests.setUp` and by independent refit, below), slice-aware (tr/en), slope floored ≥ 0 → monotone by construction (probe + builder test), versioned, **abstain** below 8 samples or single-class data (verified: 2-sample fit refuses; `probability()` returns nil).
- Held-out never used for tuning: auditor refit on the builder-effective TRAIN set **exactly reproduces** the shipped fusion weights; refit including HELD_OUT_FINAL diverges by Σ|Δw| = **0.2368** — the reproduction is load-bearing, not vacuous (`testA8_11`).

## 10. COMPOSITE SCORE — PASS

- Learned sign-constrained monotone linear fusion; weights verified **learned, not hand-picked**: auditor deterministic refit = `[-1.599, +1.115, 0.000, -1.000, -1.117]`, bias 2.0, train MAE 0.681 — matches builder's `[-1.60, +1.12, 0, -1.00, -1.12]`.
- Attacks (auditor probes): **benefit flood vs severe risk** (existing stress pair + fresh flood scenario with saturated benefit lexicon + 0.95 temporal risk + child 9) → never NEUTRAL, never ALIGNED-CANDIDATE, score ≤ 10 under protection veto; fusion-level saturated-benefit rubric stays below the aligned band. **High score + low coverage** → abstains. **High score + OOD** → abstains. **Score under age restriction / strong protection** → capped ≤ 10, interpretation PROTECTED. **Shield match** → capped ≤ 25. Policy veto dominates in every attempt.

## 11. SCORE / CONFIDENCE / COVERAGE — PASS

- Verified separate on every resolved pair: confidence ∈ {none, low, medium, high} and never numeric-parsable; coverage ∈ [0,1]; score ∈ [0,100] or nil; nil ⇒ confidence "none" + typed abstention reason + interpretation UNKNOWN. No field-swap path exists (types differ; runtime domains asserted).

## 12. SELECTIVE PREDICTION — PASS

- Abstention verified for: OOD pairs (4/4 abstain, typed reasons), empty content/zero coverage, unsupported locale ("ja" → `language-slice-unsupported`), missing fitted calibrator for slice (`UNCALIBRATED_SLICE` + nil — also the HUD's live behavior), policy REVIEW/UNKNOWN (incl. teen sentinel), unresolved conflicts, identity-unstable, uncertainty ≥ 0.8. Abstention is treated as success (nil + UNKNOWN), never a fake number.

## 13. METRIC RECOMPUTATION — PASS (independently reproduced)

Auditor-owned implementations (strict half-open bins, own Brier/AUROC/MAE loops), builder-effective dataset + artifact:

| Metric | Builder claim | Auditor recomputation | Verdict |
|---|---|---|---|
| TRAIN fit | train=20, MAE 0.681, w=[-1.60,1.12,0,-1.00,-1.12] | 20; 0.681; [-1.599,1.115,0.000,-1.000,-1.117] | MATCH |
| CALIBRATION ordinal MAE | 0.580 (n=11, 0 abst) | 0.580 (n=11, 0 abst) | MATCH |
| HELD_OUT_FINAL MAE | 0.585 (n=7, 1 abst) | 0.585 (n=7, 1 abst) | MATCH |
| Risk ECE (CAL) | 0.220 | **0.220** (own binning; every pred in exactly one bin; builder binning did not double-count on this data) | MATCH — **genuinely poor; UNMET-UNRELAXED is the correct reporting** |
| Brier | 0.163 | 0.163 | MATCH |
| AUROC | 0.86 | 0.857 | MATCH |
| Sentinel false-safe | 0 | 0 (5/5 executed) | MATCH |
| False-warning / abstention | — | OOD abstention 4/4; heldout abstention 1/8; no positive interpretation on any protect-labeled pair | OK |

- Sensitivity disclosure (auditor): with the silently-dropped alias calibration pair executed, CAL MAE would be **0.672 (n=12)** — the reported 0.580 is correct for what ran but fragile to the resolution defect (A8-F2).
- ECE ≤ 0.05 / slice ECE ≤ 0.07 engineering targets: **NOT met (0.220)** — honestly reported unmet, not relaxed; this is a central reason production stays blocked.
- Latent defect A8-F4 (LOW): `CalibrationMetricsV1.eceAndBins` bin predicates overlap at exact decimal boundaries (a pred equal to 0.1, 0.2, … satisfies two bins). Not triggered by current data (bin counts sum to n, probe-asserted) but should be fixed before any real-data calibration.

## 14. SENTINEL FALSE-SAFE — PASS (0)

- All 5 SAFETY_SENTINEL pairs executed (probe-asserted full resolution — a silently dropped sentinel would have passed vacuously; it did not happen). falseSafe = 0: no positive interpretation, no NEUTRAL on protect-labeled pairs.
- **No sentinel-ID memorization**: grep of production sources finds sentinel item names only in corpus/dataset data files; auditor rename probe (same input, fresh name + item ID) produces identical fail-closed outcomes; `SafetySentinelRegistryV1` operates on dimensions/laws, not item IDs.

## 15. TR / EN SLICES — PASS WITH HONESTY NOTE

- Both locales have fitted risk/benefit/manip calibrators (min-8 law met on TRAIN slices). Trigger lexicons are versioned TR+EN; TR teen trigger verified live.
- **Underpowered (identified honestly, matching builder's own declaration):** CALIBRATION split tr n=5, en n=6; TRAIN per-locale ≈ 8–12. No statistically meaningful slice conclusion is possible; acceptable only because the phase claims ENGINEERING_CALIBRATION_ONLY. A8-F1 removed the only TR label-4 train anchors, further skewing the TR slice.

## 16. AGE / SHIELD SLICES — PASS

- Adult, child-9, teen-14 (plain + strict-parent) profiles exercised across splits; child/teen outcomes verified fail-closed under UNAVAILABLE dimensions (H1 under-13 law; teen sentinel law). Shield: hard match caps score ≤ 25; advisory guesses never block; shield-sentinel pair green; adult-shield-mortality profile exercised.
- Teen slice is thin (3 pairs + sentinel + fresh probes) and child slices rely on fail-closed semantics rather than detection — capability-truthful, underpowered; engineering-only.

## 17. CACHE / PROFILE ISOLATION — PASS

- `ScoreCacheV1` keyed by (profileID, item, versions-fingerprint): cross-profile lookup nil even with the victim's own fingerprint; **every version axis independently invalidates** (calibration, fusion, shield, age-registry, world-model — probe `testA8_07`); stale calibrator version cannot serve a cached score.
- Same-DNA-multi-profile: one world model → per-profile policy decisions without re-understanding. **FINDING A8-F5 (MEDIUM-LOW)**: the builder's `testSameDNAMultipleProfiles` is **vacuous** — it counts `"profileID:state"` strings (always 5 distinct, can never fail), and on its chosen scenario the true state set is ONE (all profiles STRONG_PROTECTION). Genuine divergence does exist and is now probe-proven on benign educational content (adult NEUTRAL vs child REVIEW) plus score-level divergence (5 vs 10) under veto; the law holds, but the builder's test did not prove it.

## 18. PRIVACY — PASS

- Calibration data is 100% project-authored synthetic/structural; zero private user content, zero uploads, zero telemetry, no network code added (GuardianCore has no networking; HUD is DEBUG-only).
- Score outputs carry structured short fields only (no string > 200 chars — test + auditor read); no raw child/Shield profile data persisted (profiles are in-memory fixtures; provenance strings carry derived bases only). No raw-media regression.

## 19. DEVICE / HUD — PASS WITH FINDINGS (no physical proof claimed)

- By code read (`Gen8/GuardianIntelligenceHUD.swift`, `#if DEBUG`): Score section is labeled "INTERNAL; PRODUCTION SCORE DISPLAY: OFF"; NIL is distinguished (`"NIL — <abstentionReason>"`); release-gate CLOSED banner shows live unmet count; source banner prevents lab playback masquerading as real perception; latency shows NOT_MEASURED honestly; score-display-OFF law row retained.
- **FINDING A8-F7 (LOW)**: the HUD constructs an **empty `CalibrationRegistryV2`** and a **hardcoded demo fusion constant** (`wRisk:-1.6 …` snapshot of the learned weights). With no fitted calibrator registered, the selective gate always abstains (`calibrator-missing-en`) — the "Internal score" row can therefore **never display a number**, only NIL + reason (unit-probed via the empty-registry path, `testA8_15`). Verdict: acceptable as a DEBUG honesty display (NIL is itself truthful and production stays OFF), but the hardcoded constant can silently drift from the fitted artifact and the row implies a live fitted pipeline that is not wired. Should be wired to the real fitted artifact (or labeled "DEMO WEIGHTS — NOT FITTED ARTIFACT") in the next phase. Cosmetic: `wm.primaryTopics.isEmpty ? "en" : "en"` is a dead conditional.
- Physical/in-app §23 validation: **PENDING, user-gated — honestly not claimed** (`P009E_DEVICE_VALIDATION.md`). Build+install only. No device evidence was accepted by this audit.

## 20. PRODUCTION SCORE RELEASE GATE — PASS (CLOSED, verified)

- `ProductionScoreReleaseGateV1.evaluate()` → **open = false; exactly 6/10 unmet**, each with a truth string: rights-clear corpus (synthetic-only), real-data held-out (none), TR/EN real slices (none), age slices (engineering-only), physical device proof (user-gated, not claimed), independent audit PASS (this audit does not flip code). Met conditions (sentinel false-safe 0; H1 fail-closed blocking; no unresolved critical finding; privacy/resource lab-verified) are true as scoped.
- Bypass attempts: `evaluate()` is pure (no mutation API); re-evaluation after a fully green suite still CLOSED; `open` requires ALL conditions. **No "green gate" exists to accept** — the spec's auto-FAIL conditions do not trigger.

## 21. AUDITOR PROBES — 15/15 PASS (add-only)

`AUDIT8_P009EProbes.swift` (staged): 01 dataset resolution coverage (pins declared=59 / auditorResolved=54 / builderEffective=52 / phantom set exact; sentinel+heldout must fully execute) · 02 independent metric recomputation + drop-sensitivity · 03 F-5 reproduction + 8 variants (13/17/12/edu/severe/TR/jurisdiction/mild) · 04 benefit flood (corpus + fresh + fusion-level) · 05 low-coverage 95-attempt + global high-score/low-coverage scan · 06 OOD high-confidence attempt + oodStatus-honesty scan · 07 stale calibrator/fusion/shield/age/wm version cache invalidation · 08 profile cache contamination + genuine same-DNA divergence (exposes vacuous builder test) · 09 synthetic-only overclaim guards (55+4+0+0; display OFF; skeleton refusing) · 10 duplicate/translation/alias leakage (worst cross-split J=0.75 < 0.8) · 11 held-out tuning-leak counterfactual (Δ=0.2368) + refit determinism · 12 score/confidence/coverage field domains (swap impossible) · 13 sentinel rename (no ID memorization) · 14 release-gate bypass attempt (CLOSED, exact unmet set) · 15 teen-sentinel-unavailable end-to-end nil + uncalibrated-slice abstention (HUD path).

## 22. OPEN LIMITATIONS

1. **Zero real calibration data** — every metric is an engineering statement about synthetic scenarios; nothing here predicts real-world accuracy (correctly declared everywhere).
2. Risk ECE 0.220 vs ≤0.05 target — far from calibrated even on the engineering set.
3. Dataset-to-harness integrity gap (A8-F1/A8-F2): 7/59 declared pairs never execute; docs misdescribe the drop; CAL MAE sensitive to it (0.580→0.672).
4. Simulated dual annotation + adjudication-rule/data mismatch (A8-F6).
5. Vacuous builder multi-profile divergence test (A8-F5) — law true, builder proof defective; auditor probe now covers it.
6. Latent `oodStatus` hardcode in scored path (A8-F3) and ECE boundary double-count (A8-F4) — not currently triggered, must be fixed before real-data calibration.
7. HUD score row can never display a number (empty registry + demo constant, A8-F7); §23 device run user-gated and pending.
8. Underpowered slices (CAL tr=5/en=6; teen thin); cross-split margin thin at J=0.75; cross-phase held-out erosion.
9. Standing blockers unchanged: C2/C3/C5, H1 visual, Tier-0 burst residual, proof-log beta, no git remote (push blocked).

## 23. VERIFIED PROGRESS

- F-5 teen-band contradiction genuinely closed by a written, versioned policy (`TeenBandFailClosedPolicyV1` v1) wired into the age engine with escalate-only semantics; adversarially reproduced + 8 variants fail closed; F-2/F-3/F-4/F-6 hygiene fixes verified via the exact pre-declared AUDIT7 inversions.
- An internal Personal Suitability score V2 exists with honest semantics: selective abstention first, calibrated monotone fusion, policy vetoes above the number, categorical confidence, full version provenance, profile-isolated version-bound caching.
- Metrics are reproducible to the third decimal by an independent implementation; fusion weights are deterministically learned from TRAIN only (held-out counterfactual proves it); sentinel false-safe = 0 with all sentinels actually executing; CAL_RESERVED consumed exactly as reserved, byte-intact.
- The release gate is structurally CLOSED with truthful unmet conditions; production display remains OFF at every layer; privacy posture clean.

## 24. GO / NO-GO

The phase delivers exactly what it honestly claims — an engineering-grade internal score with real discipline — and nothing it doesn't. The findings (A8-F1…F8) are real but none is a critical safety or honesty breach: no false-safe, no overclaim, no leak, no veto bypass, no display leak. They must be fixed in the next working session (dataset resolution integrity A8-F1/F2 and the vacuous test A8-F5 foremost), and none of them can be carried into a real-data calibration phase.

**FINAL VERDICT:**

`PASS WITH LIMITATION — ENGINEERING CALIBRATION ONLY; PRODUCTION SCORE REMAINS BLOCKED`
