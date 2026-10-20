# GEN8 — RWC PREREGISTRATION PRE-14 R1 INDEPENDENT CLEAN-SESSION RE-AUDIT (AUDIT15)

**Auditor:** independent clean session (non-builder), 2026-10-20/21.
**Mandate:** RWC_PRE14_R1_REAUDIT_MANDATE (§0 custody … §53 return format).
**Candidate:** commit `931f38e05b7167e038dd41237aa46fa865875f6b`,
tag `gen8-rwc-preregistration-r1-audit-candidate` (annotated tag object
`6bde7d4ad845064a3974e6c9f4f8e02bd7217863` — **pinned here as audit evidence**, since the freeze
manifest records only the tag NAME).
**Discipline:** ADD-ONLY. No production code, builder test, frozen artifact, threshold or prior audit
document was modified. Additions: `AUDIT15_RWCPre14R1ReauditProbes.swift` (26 probes),
`docs/audit/audit15_tools/` (7 auditor scripts), this report.

**VERDICT: B) FIX REQUIRED — RWC PREREGISTRATION R1.**
Zero-data, custody, inversion discipline, freeze-v2 hash integrity, production locks and the AUDIT14
negative-evidence record all PASS. But the mandate's PASS standard fails on two axes:
(1) A14-F1, A14-F4, A14-F9 and A14-F13 are **not fully closed** (real-calendar validity, evidence
identity, counter validation, commit binding); (2) **twelve fresh MEDIUM findings** (A15-F1…A15-F12)
exist, several of them mandated-severity items (non-reproducible power derivation, invalid-data
acceptance, freeze binding defect, rights temporal/evidence loopholes). No CRITICAL/HIGH finding;
nothing here invalidates historical evidence or indicates data visibility.

---

## 0. Custody (observed via local git; network custody pre-verified by main session)

- `git branch --show-current` → `phase/rwc-preregistration-preparation`; HEAD =
  `931f38e05b7167e038dd41237aa46fa865875f6b` = `origin/phase/rwc-preregistration-preparation`.
- Tag `gen8-rwc-preregistration-r1-audit-candidate`: object `6bde7d4ad8…17863` (type `tag`),
  dereferences to `931f38e0…75f6b`. MATCHES mandate.
- Range `2b2c344..931f38e`: exactly 6 commits in the declared order
  `03e1d7a → 05e154b → 33e0eac → 2143aac → ace1d94 → 931f38e`
  (committer dates 22:41:11 → 22:46:22 → 23:01:09 → 23:07:52 → 23:10:10 → 23:14:08 +0300, 2026-10-20).
- 26 files changed in the range; all docs/tests/governance code; no media, no fixtures with real URLs
  used as corpus (the only URL strings added are negative-test fixtures asserting refusal).

## 1-2. AUDIT14 discipline

- Frozen original `AUDIT14_RWCPreregistrationPre14Probes_ORIGINAL_LOCKED.swift.txt` SHA-256 measured
  `18ac2633dd55e6073cf80be309db75af3f07c96a2bedd62cf8a360c246186886` — matches declaration. OBSERVED.
- `AUDIT14_FINDING_COUNT_ERRATUM.md` is additive (new file in 03e1d7a), names all NINE MEDIUM rows
  (F1,F2,F4,F5,F7,F8,F9,F10,F13); the immutable AUDIT14 report is byte-unchanged in the range
  (absent from `git diff --name-status 2b2c344..931f38e`) and retains its FIX REQUIRED verdict.
- Inversion ancestry PROVEN: manifest (03e1d7a, I-1…I-13) precedes the code-inverting commit
  (05e154b, I-1…I-5); addenda (33e0eac I-14/I-15; 2143aac I-16) precede the doc-inverting commit
  (ace1d94, I-6…I-16). The AUDIT14 probe file was modified ONLY in 05e154b and ace1d94.
  Diffing active probes vs frozen original: every change maps to a declared inversion; the
  NOT-inverted list (F7 Monte-Carlo negative evidence, F8 MC half, F6/F6b, F16 pins, F15 legacy)
  is preserved — `testA14_PINNED_F7_…` self-contained MC remains in the active file. NO UNDECLARED
  SEMANTIC INVERSION FOUND.

## 3. Zero-data forensics — HARD GATE: PASS

Swept the full range diff and repo state: no media files (`mp4/mov/wav/jpg/…`) outside `.git`; the
only dataset directory (`ml/datasets/golden-v0/`) is the pre-existing synthetic metadata-only
manifest (origin `original_synthetic`, "no binary blobs committed"). Master manifest counters
suite-asserted and re-asserted by AUDIT15: `corpus_count=0, annotator_count=0, real_fit_count=0,
heldout_open_count=0, data_visibility=false`. No fit weights, no heldout IDs, no human labels, no
real model predictions, no hidden caches found. **Zero-data holds. Not BLOCKED.**

## 4-11. Rights model (A14-F1/F2/F3/F4) — partially closed

What HOLDS (probe-verified): valid-THROUGH-expiry law (asOf==expiry eligible; asOf>expiry → typed
`.expired`); asOf<acquisition → `.acquisitionInFuture`; malformed asOf at `requireEligible`/`register`
→ typed `.malformedDate("asOf")`; use-truth matrix exhaustive (all contradictions, case variants,
unknown tokens → `.useConsistencyViolation`; unknown query use fail-closed); resurrection with ANY
previously-seen evidence pointer refused FOREVER (register AND reauthorize); pointer grammar refuses
URLs/paths/newlines/uppercase; lowercase-hex-only 64-char content hash (uppercase, 63-char, non-hex,
fullwidth Unicode all refused, never normalized); duplicate provenance refused; eligibility consults
LEDGER state only.

What FAILS:

- **A15-F1 (MEDIUM)** — `isStrictISODate` (RWCAssetRightsLedgerV1.swift:146-153) checks only month
  1…12 / day 1…31. Measured: `2026-02-31`, `2026-04-31`, `2026-02-29` (2026 is not a leap year) all
  ACCEPTED; the canonical store registers an asset with acquisitionDate `2026-02-31` and answers
  eligibility for asOf `2026-02-31` (probe `testA15_F1_RealCalendarValidity…`). **A14-F1 is NOT
  fully closed**: a rights record can carry acquisition/expiry/revocation dates that exist on no
  calendar, and expiry windows can be bounded by nonexistent dates.
- **A15-F2 (MEDIUM)** — event chronology unenforced (store, lines 269-292): `revoke(onDate:
  "2020-01-01")` on an asset acquired 2026-10-01 is ACCEPTED (event log contains a revocation dated
  before registration); `reauthorize(asOf: "2019-06-01")` after a 2020 revocation is ACCEPTED; a
  MALFORMED asOf in `reauthorize` throws the misleading `.acquisitionInFuture` instead of
  `.malformedDate` (line 285-287). Impossible chronology can enter the append-only log.
- **A15-F3 (MEDIUM)** — "NEW evidence" = new pointer STRING only (lines 260, 280-282). Probe
  `testA15_F4_NewPointerSameUnderlyingEvidence…`: after revocation, a record identical in EVERY
  field (same contentHash, licensor, licenseType) with pointer `…-0001x` instead of `…-0001`
  reauthorizes successfully. NEW POINTER ≠ NEW EVIDENCE: relicensing authority is bypassable by
  renaming. The ledger needs `rightsEvidenceHash`/version or an authoritative external evidence
  identity. **A14-F4 is structurally incomplete for relicensing.**
- **A15-F4 (MEDIUM)** — `chainDigest` uses process-seeded `Hasher()` (lines 243-247). Cross-process
  differential (3 independent `swift test` processes, identical 3-event sequence):
  run1 `00000000990063b8,00000000df14fcdb,0000000019f1b4ee`;
  run2 `00000000d19ffa77,00000000161a0f8c,000000004780f603`;
  run3 `00000000959c9917,0000000032c1ed37,00000000fa7b0ade`. Digests reproduce only WITHIN a
  process. Additionally `String(format:"%016x", UInt64)` truncates to 32 effective bits (all
  observed digests have 8 leading zeros). Append-only semantics and durable audit-chain semantics
  are conflated: there is NO durable cryptographic witness for rights provenance. Must move to
  SHA-256 chaining before any real corpus registration.
- **A15-F13 (LOW)** — `register()` hard-codes `requireEligible(use:"evaluation")` (line 254): a
  lawful, internally-consistent TRAINING-ONLY asset cannot be registered at all (probe-verified
  typed refusal `.useNotAllowed("evaluation")`). Safe-direction over-restriction, but the rights
  model semantics ("every asset must be evaluation-eligible") is undocumented.
- **A15-F16 (LOW)** — already-expired rights register successfully (no expiry-vs-asOf check at
  registration), and the injectable-asOf design permits time-travel eligibility queries (asOf
  in the past re-opens the expired window — probe-verified). No law binds the store's asOf to an
  authoritative current date at the future acquisition boundary.
- **A15-F18 (INFO)** — dashes-only pointer token `rwc-rights-ref-----` satisfies the grammar.

## 12-14. Identity / executor (A14-F5, F6/F6b) — CLOSED / honestly carried

- PRE-04 door: grammar refusal verified BEFORE token mint for uppercase, Unicode, multi-`#`, no-`#`,
  URL, path traversal, empty components, leading-dash profile, whitespace, short token — in both
  declared and resolved positions; same-count valid substitution and duplicates refused by the
  identity guard; valid composites order-independent. **A14-F5 CLOSED.**
- `PreparedCalibrationDatasetV1` still binds `[category, compositeIDs, guardRevision]` only
  (Mirror census) — A14-F6 correctly NOT overclaimed; master manifest carries the binding RWC-FIT
  payload invariant (`PreparedCalibrationDatasetV2 …`) and the F6b callable-but-prohibited law.
- Generic fit surfaces (`DimensionCalibratorV1.fit`, `LogisticCalibrator.fit`,
  `SuitabilityFusionModelV1.fit`) remain CALLABLE (probe-executed on synthetic data) — candidate
  honestly says callable engineering surfaces; `RealWorldCalibrationExecutorV1
  .preregistrationAuditPassed == false` (source line 28, `let` constant).

## 15-21. Calibration methodology v2 — design sound in center, four MEDIUM defects

Independent reimplementation (pure Python, Mersenne-Twister RNG — NO builder code; plus an
independent Swift ECE for differential): matches builder `eceEqualMass` to 1e-12 on 40 random
tie-free datasets + hand-computed case; IRR bootstrap CI reproduced byte-for-byte by replaying the
frozen SplitMix64 stream against the auditor's own kappa.

- **Type-I (combined rule) under perfect calibration** (500 trials/cell, Wilson 95% CIs):
  false-reject = n400: 5.2-6.2%; n800: 4.2-6.0%; n1600: 6.0-7.8% (6 shapes incl. high/low-conf and
  quantized). The builder's own yaml honestly records 2-7%. But **A15-F17 (INFO)**: "Type-I = 5% BY
  CONSTRUCTION" is analytically imprecise — with S=200 and index `Int(0.95*200)-1`=189, the
  exchangeability rejection rate of the TEST gate alone is 11/201 ≈ 5.47% (an exact 5% Monte-Carlo
  test needs (S+1)·0.05 integral, e.g. S=199/k=190), and the effect gate can only ADD rejections.
- **Power replication** (400 trials/cell, independent implementation): n800 reject vs δ=.07 —
  uniform over/under 96.0/95.5%, skewed 92.8/99.3%, clustered 100/99.5% (builder claim ≥94%:
  replicated within MC uncertainty; skewed/over point estimate 92.8% CI[89.8,94.9] marginally
  brushes the claim). n400 over/under 59.5-91.8% (400 correctly REJECTED), n1600 ≥99.8%.
  Tail at n800: uniform 71.8%, skewed 43.3%, clustered 100% — builder's honest 44-100% replicated.
- **δ-sensitivity at n800** (mandate §26): reject rates — δ=.03: 25.3%(uniform)/39.3%(clustered);
  δ=.05: 69.5/95.0%; δ=.07: 92.8/100%; δ=.10: 100/100%. The detection limit is honest: effects in
  (.05,.07) are caught 70-95%; below .05 weakly. effectBound .05 vs power-point .07 are coherent.
- **A15-F5 (MEDIUM)** — invalid metric inputs: `decide(preds:[1.1]×50, labels:[true]×50)` returns a
  CLEAN PASS; `preds:[-0.1]×50` likewise PASSES; NaN silently fails (untyped); `bins:0` yields
  ECE 0.0; shape mismatch yields NaN. The frozen release-gate estimator does not refuse invalid
  input — violates the prior law INVALID INPUT ≠ VALID METRIC (probe
  `testA15_InvalidMetricInputs_NoTypedRefusal_PINNED`).
- **A15-F9 (MEDIUM)** — equal-mass tie/order instability: identical (p,y) MULTISET, different input
  order ⇒ builder ECE 0.5 vs 0.0 (all-tied p=.5, blocked vs interleaved labels, probe-verified);
  decision flips on ordering alone at fixed seed. Python quantification (150 permutations/case,
  fixed null seed): observed-ECE ordering spread 0.025 (all-tied) / 0.0275 (two-level) at n=800 —
  half the effect bound. No tie policy is frozen. Quantized model outputs make this a real-data
  hazard, not a corner case.
- **A15-F10 (MEDIUM)** — "debiased gap = absolute miscalibration bound" is FALSE as named. Against
  analytically-known true L1 miscalibration (uniform p, n=800, 300 trials, MC-SEM ≤ .0008):
  constant .07 shift → true .0676, mean gap .0345 (−49%); nonlinear p^1.5 → .100 vs .065;
  tail-only → .028 vs .0223; oscillating (±.08 sine) → true .0509 vs gap .0192 and **37.3% PASS**
  despite true miscalibration ABOVE the .05 semantic bound; localized → .0251 vs .0165. The gap is
  class C — heuristic bias subtraction, systematically an UNDER-estimate (binning cancels
  within-bin distortions; E[obs] under alternatives is sub-additive in bias+effect). Honest naming
  and scope ("binned, bin-resolvable miscalibration net of null mean") is required; any release
  text implying "PASS ⇒ ≤5pp miscalibration" would overclaim.
- **A15-F11 (MEDIUM)** — S=200 null-seed verdict instability: holding observed data FIXED and
  varying ONLY the internal null seed (120 datasets × 30 seeds, n=800): 8.3% (CI 4.6-14.7%) of
  perfectly-calibrated datasets and 15.8% (CI 10.4-23.4%) of boundary (δ=.03) datasets get MIXED
  PASS/FAIL verdicts across seeds. `decide(seed:)` has NO frozen canonical evaluation seed (unlike
  `irrSeed`), so the release verdict depends on an unpinned nuisance parameter; S=200 gives a
  coarse, noisy Q95. Must freeze the evaluation seed AND/OR raise S (quantile SE shrinks ~√S).
- **External literature (§21, all KNOWN-from-training, UNVERIFIED — no browsing available):**
  Roelofs et al. 2022 ("Mitigating Bias in Calibration Error Estimation", AISTATS) documents
  upward finite-sample bias of binned ECE for calibrated models, recommends equal-mass binning and
  bias-aware estimators (ECE_sweep; debiased estimators in the Kumar/Liang/Ma 2019 line). It does
  NOT define GEN8's null-referenced Q95 rule or the max(0, obs−null-mean) gap. The TEST gate is
  closest to consistency resampling (Bröcker & Smith 2007, forecast verification) — a defensible
  Monte-Carlo test idea — but GEN8's composite rule stands on its own measured behavior only, as
  evaluated above. No literature citation validates the "absolute miscalibration bound" naming.

## 22-24. Power derivation reproducibility — MEDIUM defect

- **A15-F7 (MEDIUM)** — `power_derivation.py:55` seeds cells with `0xA14F7 + n*7 + hash(conf+alt) %
  1000`. Python string `hash()` is process-randomized. Measured (fresh subprocesses): the 36 cell
  seeds differ across PYTHONHASHSEED=1/2/3 (e.g. `n400_uniform_null` → 664039 / 664047 / 663797).
  Full frozen-script triple run under PYTHONHASHSEED=1/2/3: **ALL 36 cells differ** across the
  three runs; worst pass-rate spread 0.112 (`n400_skewed_over`: .504/.392/.436). The FROZEN yaml's
  recorded bands do NOT reproduce: n800 null pass claimed "0.95-0.96" but measured 0.936-0.956 (h1)
  and 0.948-0.964 (h3); n800 over/under pass claimed "0.00-0.06" (power ≥94%) but h2 yields 0.064
  (power 93.6%). The declared "deterministic cell-keyed seeds" claim is FALSE as run: the frozen
  derivation is NOT reproducible as frozen, and its recorded result bands are violated under
  ordinary process hash randomization. Mitigation
  already measured: the auditor's independent replication (above) confirms the n=800 DECISION
  (power ≥~93% over/under; n400 rejected) is robust under seed variation, so the frozen n≥800 law
  itself is not materially wrong — but a frozen statistical derivation must be reproducible
  (mandate lists this as MEDIUM by name).
- **Python↔Swift differential (§23):** same SplitMix64 core, same bin arithmetic (`b*n//bins`),
  same q95 index (`int(0.95*S)-1` / `Int(0.95*Double(sims))-1`), same clip/alternative/tail
  definitions, same S=200 and .05 bound. ONE semantic difference: uniform conversion — Python
  `z/2^64` (64-bit) vs Swift `(next()>>11)/2^53` (53-bit). Distributionally equivalent; immaterial
  to frozen power claims. No discrepancy that changes the frozen law.

## 25-28. Tail limitation, n=800 law, slices (A14-F8) — honest; CLOSED at law level

Tail power honestly disclosed (not claimed); measured 43-100% at n800 by shape. The sentinel
falseSafe gate does NOT cover benign high-confidence miscalibration outside the sentinel class —
this is correctly NOT claimed anywhere; per-bin diagnostics are mandated in the power yaml. Any
future release claim must remain "overall + GATE_POWERED slices" scoped (gates text already does).
Tri-state law (REPORTABLE/GATE_POWERED(n≥800)/UNDERPOWERED) present in gates+slices; no slice is
currently gate-powered; n=799 cannot hard-gate BY LAW TEXT (no machine slice evaluator exists yet —
acceptable staging, noted). 21-slice census intact; rare slices honestly marked UNDERPOWERED-likely;
multiplicity 4-class policy present. A14-F8 CLOSED (law level).

## 29-32. Coverage (A14-F9) — law sound, helper gameable

Law verified: in-dist decision coverage ≥0.80 frozen pre-data; OOD membership is ANNOTATOR-defined
(handbook D-16), independent of model abstention; OOD abstention never penalized; sentinel 3-way
report with conditional-semantics law (A14-F17 text verified); abstention never counted as
success/failure; exact-0.80 boundary meets the gate (probe). Rule-of-three consistency verified:
n=150 is exactly the smallest n with 95% UB ≤ 2% (148 fails). The 0.80-coverage calibration claim
is correctly DECIDED-SET conditional in gates text.
- **A15-F6 (MEDIUM)** — `coverage()` (RWCCalibrationMethodologyV1.swift:170-179) accepts impossible
  counters: decided=120/total=100 → decisionCoverage 1.2 (≥0.80 trivially), abstentionRate −0.2,
  sentinel rates >1, negative counts → negative rates, zero denominators → plausible 0.0, no typed
  refusal anywhere (probe `testA15_F9_CoverageAcceptsImpossibleCounters_PINNED`). The mandate PASS
  standard "coverage cannot be gamed by malformed counters" FAILS. A14-F9 not fully closed.

## 33-35. IRR (A14-F10) — CLOSED; operational power characterized

- Independent kappa (disagreement-weights formulation) matches builder to 1e-9 on 30 random
  datasets; hand values (identity ⇒ 1.0; perfect reversal k=2 ⇒ −1.0) exact; degenerate ⇒ nil both.
  Alpha hand values (-0.5 / 1.0 / single-category nil) exact.
- EXACT bootstrap replication: replaying `RWCSplitMix64(seed: 20261020)` with the auditor's own
  kappa reproduces `irrKappaDecision`'s CI bounds to 1e-9 and the decision equals
  (ciLower ≥ threshold) — deterministic, repeat-call byte-identical.
- Percentile convention characterized: B=2000 ⇒ indices 50/1950 ⇒ the 51st/1951st order statistics
  ⇒ nominal [0.0255, 0.9755] quantiles (slightly narrower than textbook [0.025,0.975]; documented,
  not a failure). Valid-fraction boundary is exact integer arithmetic (1600/2000 passes, 1599/2000
  does not) — deterministic.
- **A15-F14 (LOW)** — operating characteristics (120 trials/cell, mixture-rater model, Wilson CIs):
  true κ=.55 → PASS ≤1.7% (false-PASS controlled, good); κ=.60 → 0.8-5.8%; κ=.65 → 10-14%;
  **κ=.70 → 19.2%(n50)/17.5%(n100)/41.7%(n200)**; κ=.80 → 49.2/75.0/91.7%; κ=.90 → 88-100%.
  The gate is strongly conservative: teams with genuinely acceptable κ≈.70 will usually FAIL at
  n≤200. PRE-08's "≥100 pairs for comfortable passes at kappa ~.75" guidance is optimistic under
  this model. Not corpus-corrupting (fails safe), but the prereg should plan n≥200 and κ≥.8
  expectations or it will be operationally underpowered.

## 36-39. Freeze v2 / binding (A14-F13) — hashes perfect, binding defective

- Full census recomputed independently (Python + Swift probe): 25 artifacts = 18 normative + 7
  METHODOLOGY_CODE, zero duplicate paths, **all 25 SHA-256 valid**. v1 manifest file byte-preserved
  (15 artifacts).
- **v1 historical truth RECOVERABLE**: sha256(`git show 1c4160b:…RWC_FROZEN_GATES.yaml`) =
  `f2fb4e539a28d971b9ee6d9086567e593a007260f354e73a15f4e1d4734457b0` = the hash recorded in the
  preserved v1 manifest; v1 design also embedded as `superseded_v1_design` negative evidence.
  **A15-F20 (INFO)**: builder wording "v1 gates/freeze files byte-preserved" is inaccurate — the
  live gates FILE was superseded in place; only the v1 MANIFEST is byte-preserved. Evidence intact,
  wording false.
- **A15-F8 (MEDIUM)** — `freeze_candidate_commit = 2143aacc…` (23:07:52) PRECEDES the methodology
  commit ace1d94 (23:10:10). Verified: the 2143aac tree contains NEITHER `power_derivation.py` nor
  `RWC_PREREGISTRATION_FREEZE_MANIFEST_V2.yaml` nor gates v2 (gates_version at 2143aac is
  `rwc-frozen-gates-v1`) — 13 of the 25 frozen artifacts are absent or byte-different in the
  declared binding tree (every artifact added/modified by ace1d94, incl. the methodology code file
  RWCCalibrationMethodologyV1.swift). The manifest's own `commit_binding_law` says "Any divergence between them is itself
  drift" — by its own law the declared dual binding is self-contradictory. The anchor_tag does
  dereference to the correct full tree (931f38e), and file hashes bind content, but contradictory
  commit metadata in a FROZEN manifest is a freeze binding defect (mandate: do not accept
  contradictory metadata). A14-F13 not fully closed.
- **A15-F15 (LOW)** — `protocols/RWC_PRE10_SLICES.md` and `RWC_PRE11_GATE_FREEZE.md` are outside
  BOTH freeze boundaries (v1 and v2) although PRE-10 carries tri-state law text and was an
  inversion target (I-6). Operative gates live in frozen YAMLs, so drift there is caught — but the
  law-text files should be inside the boundary.
- Tag binding (§39): the freeze evidence records only the tag NAME. A deleted/recreated tag would
  not change the manifest. The audited tag OBJECT `6bde7d4ad845064a3974e6c9f4f8e02bd7217863` and
  commit `931f38e05b7167e038dd41237aa46fa865875f6b` are hereby pinned as the authoritative
  identities any future corpus-entry PASS evidence must reference.

## 40-42. Corpus entry guard — policy function, not a verifier

- **A15-F12 (MEDIUM)** — `RWCCorpusEntryGuardV1.requireEntry` accepts caller-supplied
  `pre14Verdict`, hash dictionaries, and `postAuditMethodologyDrift`. Probe-verified: a FORGED
  state (`pre14Verdict:"PASS"` though no PASS exists, matching fake hash dicts, drift=false) sails
  through; an EXTRA methodology file added post-audit is INVISIBLE to the hash clause (the loop
  iterates audited paths only) and is caught only by the caller-supplied drift boolean — which the
  caller can set false. The guard enforces its five clauses correctly on honest state (same-path
  drift, version mismatch, visibility, non-PASS verdict all refuse — probe-verified), so it is a
  correct POLICY FUNCTION — but the repo does not define the AUTHORITATIVE PRODUCER of this state.
  Mandate PASS standard requires an explicitly required authoritative binding step; it is absent.
  REQUIRED before any real acquisition: a signed/recorded PRE-14 PASS lock artifact binding the
  audited tag OBJECT sha (6bde7d4a…) + commit (931f38e…) + live recomputation of the full freeze-v2
  hash SET (both directions: audited⊆current AND current⊆audited within the methodology boundary),
  consumed by the acquisition path itself.
- Per-asset composition (§42): PRE-01/ledger laws + the store provide the per-asset gate; gates v2
  window law provides the global gate. The FUTURE acquisition contract must require BOTH (global
  prereg entry AND per-asset `register`+`requireEligible(asOf:today)`+hash+provenance) — currently
  documented across PRE-01/PRE-04/gates, no single composed contract yet (acceptable staging, noted
  under A15-F12 remediation).

## 43-46. Heldout/annotation, device, fail-evidence, production locks — PASS

- PRE-12 v2: opening counts/doesn't-count matrix, authorized-opener law, material/non-material
  matrix, post-opening revocation ⇒ aggregates lose FINAL status (preserved, never deleted) — all
  present (probe-verified strings).
- `RWCAnnotationLawV1`: boundary disagreement ⇒ adjudicationRequired; same-class ⇒ protective min;
  legacy engineering midpoint type UNCHANGED (builder pins intact). TR/EN parity: D-16/D-17 present
  in both; EN "авудible" typo fixed to "audible" (v1.0.1).
- Device (A14-F16): selection RULE frozen; budgets all `UNSET_PENDING_BASELINE`; no measured
  evidence invented; finding stays OPEN blocking RWC-DEVICE. **A15-F19 (INFO)**: PRE-13 attributes
  "iPhone 11 class" to DEVICE_RESOURCE_BUDGETS.yaml, which names NO floor device (probe-verified);
  the attribution is externally plausible for the iOS 26 support matrix (KNOWN-from-training,
  UNVERIFIED) but the citation is wrong as written.
- Fail-evidence: `preregistrationAuditPassed == false` (immutable `let`); no artifact claims a
  PRE-14 PASS; remediation report explicitly states "Builder cannot self-PASS".
- Production locks (probe-asserted): `CalibrationDatasetRegistryV2.supportsRealWorldClaims==false`,
  59 engineering pairs, `calibrationClass==.engineeringOnly`, `productionDisplayAllowed()==false`,
  `ProductionScoreReleaseGateV1.evaluate().0==false`. No real fit, no heldout, no Presentation.

## 47. Fresh auditor test family

`AUDIT15_RWCPre14R1ReauditProbes` — 26 probes, all green; defective behaviors PINNED with
"AUDIT15 FINDING" comments. Baseline before additions: **878/878** (54.8s). After additions:
**904/904** (full suite re-run, 0 failures). Auditor tooling (7 scripts + JSON outputs referenced
above) under `docs/audit/audit15_tools/`.

## Findings table (fresh, AUDIT15)

| ID | Severity | Finding (evidence above) |
|---|---|---|
| A15-F1 | MEDIUM | Impossible Gregorian dates accepted (Feb 31 / Apr 31 / Feb 29 non-leap) — A14-F1 not fully closed |
| A15-F2 | MEDIUM | Rights event chronology unenforced; revoke/reauthorize can predate history; reauthorize malformed-asOf mistyped |
| A15-F3 | MEDIUM | Evidence identity = pointer string; pointer renaming defeats NEW-evidence law — A14-F4 structurally incomplete |
| A15-F4 | MEDIUM | chainDigest process-seeded Hasher (3-process differential) + 32-bit truncation — no durable provenance witness |
| A15-F5 | MEDIUM | decide/eceEqualMass accept invalid probabilities; p=1.1 / p=−0.1 yield clean PASS; no typed refusal |
| A15-F6 | MEDIUM | coverage() accepts impossible counters (rates >1 / negative); coverage gate gameable by malformed counts |
| A15-F7 | MEDIUM | power_derivation.py seeds via Python hash() — PYTHONHASHSEED-dependent; frozen derivation not reproducible |
| A15-F8 | MEDIUM | freeze_candidate_commit (2143aac) predates methodology (ace1d94); binding tree lacks 13/25 artifacts; self-contradictory law |
| A15-F9 | MEDIUM | Equal-mass ECE order-sensitive under ties (0.5 vs 0.0 same multiset; decision flips); no frozen tie policy |
| A15-F10 | MEDIUM | "Absolute miscalibration bound" false: gap underestimates true L1 error ~2× (osc: true .051 passes 37%) |
| A15-F11 | MEDIUM | No frozen evaluation seed for decide(); S=200 ⇒ 8.3%/15.8% of null/boundary datasets flip verdict across seeds |
| A15-F12 | MEDIUM | Corpus entry guard trusts caller strings; forged PASS + drift=false enters; extra-file expansion invisible |
| A15-F13 | LOW | register() refuses lawful training-only assets (hard-coded evaluation eligibility) |
| A15-F14 | LOW | IRR gate underpowered: true κ=.70 passes 17-42% (n≤200); PRE-08 n≥100@κ.75 guidance optimistic |
| A15-F15 | LOW | PRE-10/PRE-11 law texts outside both freeze hash boundaries |
| A15-F16 | LOW | Already-expired rights registrable; injectable asOf permits time-travel eligibility; no authoritative-now law |
| A15-F17 | INFO | "Type-I=5% by construction" imprecise: exact 11/201≈5.47% test gate; measured combined 4.2-7.8% |
| A15-F18 | INFO | Dashes-only pointer token accepted by grammar |
| A15-F19 | INFO | "iPhone 11 class" attributed to a source that names no device |
| A15-F20 | INFO | "v1 gates byte-preserved" wording false (evidence recoverable via 1c4160b + v1 manifest hash) |

## A14 nine-row closure assessment

F1 PARTIAL (A15-F1/F2) · F2 CLOSED · F4 PARTIAL (A15-F3) · F5 CLOSED · F7 CLOSED-as-design but v2
carries A15-F5/F9/F10/F11 · F8 CLOSED (law level) · F9 PARTIAL (A15-F6) · F10 CLOSED · F13 PARTIAL
(A15-F8/F12). Carried: F6/F6b (honest), F16 (honest OPEN), F19 (INFO).

## Verdict

**FIX REQUIRED — RWC PREREGISTRATION R1.** Corpus acquisition remains FORBIDDEN. The remediation
round is disciplined, zero-data-clean, and most laws hold under attack; the remaining defects are
bounded, well-localized, pre-data fixable, and none requires relaxing any threshold. A second
remediation (R2) addressing A15-F1…A15-F12, followed by a fresh independent PRE-14 re-audit, is the
single permitted next step.
