# RWC PREREGISTRATION — R2 CHANGE LEDGER (FROZEN PRE-DATA)

Strategy: SUPERSESSION NOT MUTATION (AUDIT15_R2_INVERSION_LOCK.md — ZERO probe inversions). Every
row: old behavior → AUDIT15 evidence → root cause → new behavior → pre-data justification → new
tests → freeze impact. All 25 freeze-v2 artifacts and every pinned file remain byte-untouched.

| F | Old (V1, now SUPERSEDED_ENGINEERING_HISTORY) | AUDIT15 evidence | Root cause | New (canonical V2/V3) | Pre-data justification | Tests | Freeze impact |
|---|---|---|---|---|---|---|---|
| A15-F1 | `isStrictISODate` accepted 2026-02-31/-04-31/-02-29; store registered impossible dates | probe `testA15_F1_RealCalendarValidity…PINNED` | range check (1..12/1..31), no calendar | `RWCDateV2`: real Gregorian month lengths + leap law; typed `impossibleDate`/`malformedDate`; 2028-02-29 valid | calendar truth is not data-dependent | R2: date red-team incl. leap matrix | RWCRightsV2.swift frozen v3 |
| A15-F2 | revoke("2020-01-01") after 2026 acquisition accepted; reauthorize before revocation accepted; malformed asOf → `.acquisitionInFuture` | probe `…EventChronology…PINNED` | caller-supplied date strings, no timeline law | clock-supplied event dates + MONOTONE law; `revocation >= acquisition`; `reauth acquisition >= revocation`; malformed → `malformedDate(field:)` always | chronology is structural, not data-derived | R2: chronology matrix | same |
| A15-F3 | new pointer string = "new evidence"; renamed pointer reauthorized | probe `…NewPointerSameUnderlyingEvidence…PINNED` | pointer-as-identity | `RWCRightsEvidenceIdentityV1`: evidenceDigest (SHA-256) is identity; same digest ⇒ `reauthorizationRequiresNewEvidence` FOREVER; pointer = location only | WHAT vs WHERE separation | R2: same-digest/new-pointer refusal; lawful new-digest reauth | same |
| A15-F4 | chainDigest via process-seeded Swift `Hasher` (16 hex, 32-bit), non-reproducible across processes | probe `…ChainDigest_HasherBased…PINNED` + 3-process differential | append-only vs durable-witness conflated | SHA-256 over canonical length-prefixed event bytes; versioned genesis; `RWCAssetRightsJournalV1` durable JSONL + replay/chain/digest/duplicate verification + head-witness truncation law | cryptographic determinism is data-independent | R2: known-vector digests, cross-process stability, journal tamper/reorder/truncate/duplicate | same |
| A15-F5 | `decide()` PASSed p=1.1/−0.1; NaN silent; bins=0 → ECE 0 | probe `testA15_InvalidMetricInputs…PINNED` | no input domain | `RWCCalibrationInputErrorV1` typed refusals: finite, [0,1], nonempty, count match, 1<=bins<=n, (S+1)%20==0 | INVALID INPUT != VALID METRIC (standing law) | R2: domain attack battery | RWCCalibrationMethodologyV3.swift frozen v3 |
| A15-F6 | `coverage()` accepted decided>total (→1.2), negatives, zero-denominator → fake 0 | probe `testA15_F9_CoverageAcceptsImpossibleCounters_PINNED` | raw Int rates | `coverageV2`: typed counter validation; `RWCRateV2.notApplicable` for zero denominators; hard gate requires valid nonzero in-dist denominator | counter sanity is data-independent | R2: impossible-counter battery + exact 0.80 boundary | same |
| A15-F7 | `power_derivation.py` seeds via Python `hash()`: all 36 cells differ across PYTHONHASHSEED; frozen bands violated | auditor PYTHONHASHSEED differential | process-randomized seeding | SHA-256 seed law; canonical Swift engine (no numpy on host; recorded); two full power runs BYTE-IDENTICAL; python differential byte-identical under PYTHONHASHSEED {random,1,2,3,999} (sha256 3ff6929d…) | reproducibility is a property of the law, not the data | R2: fixture equality Swift↔Python; byte-identity recorded | power results/stability/fixtures JSONs frozen v3 |
| A15-F8 | freeze_candidate_commit (2143aac) predates methodology commit; tree lacked 13/25 artifacts; tag object unrecorded | probe `testA15_FreezeV2_FullHashCensus…` | self-referential single-commit binding | TWO-PHASE NON-CIRCULAR freeze: METHODOLOGY ANCHOR COMMIT (all frozen files final) → manifest V3 in a LATER commit recording `methodology_anchor_commit`; anchor-diff-empty law; tag OBJECT pinned by audit + future PASS LOCK, never fabricated | pure process design | R2: anchor ancestry + per-path `git diff anchor..HEAD` empty + hash census v3 | FREEZE_MANIFEST_V3 (post-anchor) |
| A15-F9 | equal-mass sort split ties by input order: same multiset → ECE 0.5 vs 0.0; verdict flipped | probe `testA15_EqualMassTies_OrderSensitivity_PINNED` | order-dependent binning | TIE-GROUP BINNING LAW: atomic equal-value groups; bin=(cStart*B)/n integer; exact per-group sums; permutation invariant by construction; labels never tie-breakers; cross-language frozen text | multiset invariance is structural | R2: permutation battery (incl. 200 shuffles), Python↔Swift tied fixtures | gates v3 + methodology v3 |
| A15-F10 | "debiased gap = absolute miscalibration bound" (false; underestimates true L1 up to ~62% rel.) | auditor a15_gap.json | unproven terminology | renamed `nullAdjustedExcessECE`; gates v3 `scientific_status`: OPERATIONAL ACCEPTANCE STATISTIC, explicitly NOT a bound/unbiased estimator; claim_scope_law forbids "calibrated everywhere"/"true error <= 5%" | honesty requirement; no proof exists | R2: naming + claim-scope pins | gates v3 |
| A15-F11 | S=200, no frozen evaluation seed: verdict flipped across internal seeds 8.3% null / 15.8% boundary | auditor a15_seed_instability.json | unseeded evaluation + coarse quantile | frozen SHA-256 evaluation-seed law (verdict single-valued); EXACT MC test ((S+1)%20==0, integer boundary); S chosen by PREDECLARED rule (smallest with null mixed <= 1.5%): measured 0.0% at ALL {999,4999,9999} ⇒ S=999; boundary 3.3% documented as inherent | rule predeclared in engine header BEFORE runs; no post-hoc tuning | R2: seed determinism, stability artifact pins | methodology v3 + stability JSON |
| A15-F12 | `RWCCorpusEntryGuardV1` trusted caller strings: forged PASS + fake dicts + drift=false ENTERED; extra files invisible | probe `testA15_CorpusEntryGuard_TrustsCallerState_PINNED` | policy-function-as-verifier | PASS-LOCK SCHEMA + `RWCCorpusEntryVerifierV2`: repository-truth verification (tag OBJECT, commits, anchor ancestry, live hashes, SET-EQUALITY surface scan, zero-visibility); unforgeable `RWCVerifiedCorpusEntryV1` (fileprivate init); NO PASS LOCK exists in R2; global+per-asset composition law | authority design, not data | R2: forged-lock/tag/report/drift/extra-file refusal battery on synthetic git fixtures; real-repo verify ⇒ lockMissing | schema yaml frozen v3 |

Coupled LOW/INFO: **F13** register() use-agnostic (training-only registrable; evaluation use still
refused) · **F14** IRR planning law MIN_VALID=50 vs PLANNED_TARGET_N=300 (RWC_IRR_PLANNING_V3.md;
threshold NOT weakened) · **F15** PRE-10/PRE-11 included in the freeze v3 inventory (files
unedited) · **F16** already-expired registration refused (`expiredAtRegistration`) + monotone
no-time-travel law · **F17** "Type-I=5% by construction" wording retired: exact 5.0% proven for the
MC test gate alone; combined rule measured 2.0–7.5% per cell · **F18** pointer grammar requires >=1
alphanumeric (dashes-only refused in V2) · **F19** device citation defect stands as INFO; no device
evidence invented; RWC-DEVICE blocked · **F20** v1/v2 history wording corrected to RECOVERABILITY
(master manifest `r2_v1v2_history_truth`).

Builder-test edits this round: NONE (master manifest extended via NEW keys only; all R1/AUDIT
pins intact).

## Pre-data declaration

ALL R2 METHODOLOGY CHANGES WERE MADE BEFORE REAL-DATA VISIBILITY.
NO REAL CORPUS DATA, NO LABELS, NO FIT, NO HELDOUT influenced any R2 decision.
corpus_count=0 · annotator_count=0 · real_fit_count=0 · heldout_open_count=0 ·
data_visibility=false · no PASS lock exists · production score/display/Presentation blocked.
