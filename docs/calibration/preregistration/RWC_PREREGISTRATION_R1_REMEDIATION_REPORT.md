# RWC PREREGISTRATION — R1 REMEDIATION REPORT (2026-10-20)

Builder round closing ALL NINE MEDIUM-labelled AUDIT14 rows (count erratum:
`docs/audit/AUDIT14_FINDING_COUNT_ERRATUM.md`) + coupled LOWs, with ZERO data. Start HEAD `2b2c344`
(AUDIT14 FIX REQUIRED; target `1c4160b`). Baseline remeasured: **866/866**. Discipline: AUDIT14 frozen
original SHA `18ac2633…` + pre-declared inversion manifest I-1..I-16 (`AUDIT14_R1_INVERSION_LOCK.md`,
manifest/addenda commits strictly precede every inverting commit). Builder cannot self-PASS — an
independent PRE-14 R1 re-audit is required; corpus remains FORBIDDEN until its PASS.

## Closure matrix (mandatory nine + coupled)

| Finding | Root cause | Fix | Status |
|---|---|---|---|
| **A14-F1** expiry never evaluated | no date logic/time source | strict `yyyy-MM-dd` + cross-field laws (2-arg, deterministic); asOf store law (valid-THROUGH expiry; injectable asOf, no `Date()`) | **CLOSED** |
| **A14-F2** dual use truth | lists never consulted | `RWCUseV1` + consistency law (flag⇔allowedUse⇔prohibitedUse; case-variants caught); typed refusal, never repaired | **CLOSED** |
| **A14-F3** hygiene prose-only | checks missing | newline-trim, owner, lowercase-hex-only hash, dup-provenance (2-arg); opaque-pointer grammar `rwc-rights-ref-`/`rwc-source-ref-` (store) | **CLOSED** |
| **A14-F4** resurrection | value-type ≠ ledger | **`RWCAssetRightsLedgerStoreV1`** append-only canonical authority: tombstone forever for old evidence; relicense ONLY via explicit `reauthorize` + NEW evidence; chained event log | **CLOSED** |
| **A14-F5** garbage IDs mint token | grammar unwired | `prepareDataset` runs `parseComposite` on EVERY declared+resolved composite BEFORE the guard (`invalidRWCCompositeIDs`, count/index-only); PRE-04 doc corrected | **CLOSED** |
| **A14-F7** ECE gate noise-dominated | wrong statistic (single proportion for 10-bin ECE); v1 point gate bias-blind | **Methodology v2**: null-referenced equal-mass design — PASS iff obs ≤ Q95(null) AND debiased gap ≤ .05 (Type-I 5% BY CONSTRUCTION); frozen **n ≥ 800** from the frozen derivation (power ≥94% vs δ=.07 over/under across uniform/skewed/clustered; n=400 REJECTED: 56-63%); NOT tuned to AUDIT14's seed (predeclared generators, cell-keyed seeds, independent Swift re-verification seeds); v1 design preserved as REJECTED/SUPERSEDED negative evidence; tail-only distortion power (44-100% by shape) = HONEST LIMITATION, covered independently by the sentinel safety gate + per-bin diagnostics | **CLOSED** |
| **A14-F8** POWERED contradiction | reportable mislabeled powered | tri-state **REPORTABLE / GATE_POWERED(n≥800) / UNDERPOWERED**; hard slice gate only when a slice meets the SAME power law; initially NO slice is gate-powered (honest) | **CLOSED** |
| **A14-F9** abstention gaming | no coverage accountability | frozen coverage gates: in-distribution decision coverage **≥ 0.80** (pre-data product semantics, not outcome-tuned); abstention-rate reported; OOD abstention EXPECTED/never penalized; sentinel 3-way report (protective / explicit-decision / abstention — 100% abstention never implies understanding) | **CLOSED** |
| **A14-F10** IRR CI rule undefined | asymmetric gate text | **PASS iff 95% bootstrap CI LOWER BOUND ≥ threshold**; B=2000 seeded; degenerate replicates excluded; valid-fraction ≥ 0.80 else INSUFFICIENT_DATA; κ=.61 CI[.30,.75] ⇒ **FAIL** deterministically | **CLOSED** |
| **A14-F13** freeze boundary + window | docs-only freeze; post-result-only invalidation | **FREEZE V2**: 18 normative + **7 methodology-code** SHA-256 + commit binding (+anchor-tag latest-record law); v1 preserved untouched (FAILED candidate); **PRE14→corpus WINDOW LAW** (any frozen-artifact/code change after PASS and before first corpus registration ⇒ new prereg version + new freeze + new independent PRE-14 PASS); machine `RWCCorpusEntryGuardV1` (verdict/hash/version/visibility/drift clauses, synthetic-state tested) | **CLOSED** |
| A14-F11/F12 | opening/materiality undefined | PRE-12 v2: opening counts/doesn't-count matrix, authorized-opener/access law, material/non-material matrix (no discretionary loophole), post-opening revocation ⇒ aggregates NO LONGER VALID FINAL EVIDENCE (preserved, never deleted) | **CLOSED** |
| A14-F15 | anti-protective tie rounding | `RWCAnnotationLawV1`: protection-boundary disagreement ⇒ adjudicationRequired; same-class ⇒ more-protective min; legacy engineering type UNCHANGED (AUDIT pins) | **CLOSED** |
| A14-F17 | sentinel semantics implicit | conditional-on-sentinel report law; population claims prohibited | **CLOSED** |
| A14-F18 | no multiplicity policy | 4-class policy (SAFETY/CALIBRATION hard gates — family-wise any-failure-blocks; DIAGNOSTIC/EXPLORATORY); safety never averaged away | **CLOSED** |
| A14-F14 | EN Cyrillic typo | "audible", rev v1.0.1, semantics unchanged, re-hashed in freeze v2 | **CLOSED** |
| A14-F16 | floor device unnamed | SELECTION RULE frozen (lowest-supported per DEVICE_RESOURCE_BUDGETS = iPhone 11 class; deviation-record law); budgets/measurement remain **OPEN — blocking RWC-DEVICE** (no device invented) | **RULE CLOSED / FINDING OPEN** |
| A14-F6/F6b | token payload unbound; generic fits public | NOT falsely closed: recorded as **binding RWC-FIT prerequisite** in the master manifest (`PreparedCalibrationDatasetV2` must bind identities+labels+features+rights/split revision+manifest hash; structural type separation before RWC-FIT); generic surfaces honestly described as callable-but-prohibited | **CARRIED (honest)** |
| A14-F19 | INFO | preserved | CARRIED |

## Change control

`RWC_PREREGISTRATION_R1_CHANGE_LEDGER.md` — 16 rows (OLD / AUDIT14 REASON / NEW / PRE-DATA
JUSTIFICATION / INVALIDATION EFFECT). Explicit declaration: **ALL R1 METHODOLOGY CHANGES WERE MADE
BEFORE REAL-DATA VISIBILITY — no corpus results, no labels, no fits, no held-out openings.** Gates v1
and freeze v1 are preserved as REJECTED/SUPERSEDED negative evidence (FM-014), never erased.

## Zero-data proof (suite-asserted)

corpus_count 0 · annotator_count 0 · real_fit_count 0 · heldout_open_count 0 · data_visibility false ·
`preregistrationAuditPassed == false` · 59 engineering pairs unchanged · production gate CLOSED ·
display OFF · Presentation blocked.

## Next

Single permitted next step: **independent clean-session RWC PRE-14 R1 re-audit** of the new candidate
tag. Only its PASS (recorded with matching frozen hashes via the corpus entry guard) can unlock
RWC-CORPUS.
