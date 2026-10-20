# RWC PREREGISTRATION — R2 REMEDIATION REPORT (2026-10-21)

Builder round closing ALL TWELVE AUDIT15 MEDIUMs (A15-F1..F12) + coupled LOW/INFO, with ZERO data.
Start HEAD `9252d7a` (AUDIT15 FIX REQUIRED, target `931f38e`). Strategy: **SUPERSESSION NOT
MUTATION** (`docs/audit/AUDIT15_R2_INVERSION_LOCK.md`): ZERO AUDIT15 probe inversions — the active
probe file is byte-identical to its frozen original (`a68a8d50…`, suite-asserted); every 25
freeze-v2 artifact and every pinned file stayed byte-untouched; the V1 defect surfaces are
SUPERSEDED_ENGINEERING_HISTORY and permanent negative evidence; canonical authority moved by record
to the V2/V3 modules. Builder cannot self-PASS — an independent PRE-14 R2 re-audit is required;
corpus remains FORBIDDEN until its PASS.

## Closure matrix

| Finding | Root cause | R2 closure | Status |
|---|---|---|---|
| A15-F1 | pseudo-date validation (1..12/1..31) | `RWCDateV2` real proleptic-Gregorian civil date: true month lengths + leap law; strict ASCII; typed `impossibleDate`/`malformedDate`; 2028-02-29 valid, 2026-02-29/-02-31/-04-31 refused; no Calendar/locale/timezone | CLOSED |
| A15-F2 | caller date strings, no timeline | clock-supplied event dates + MONOTONE law (events AND queries); revocation ≥ acquisition; reauth acquisition ≥ revocation; malformed always `malformedDate(field:)` | CLOSED |
| A15-F3 | pointer string = evidence identity | `RWCRightsEvidenceIdentityV1`: SHA-256 `evidenceDigest` is the identity; same digest under ANY pointer ⇒ `reauthorizationRequiresNewEvidence` forever; pointer = location only | CLOSED |
| A15-F4 | Swift `Hasher` chain (process-seeded, 32-bit) | SHA-256 over canonical length-prefixed event bytes; versioned genesis; external `shasum` cross-process witness test; `RWCAssetRightsJournalV1` durable append-only JSONL with replay/sequence/chain/digest/duplicate verification + head-witness truncation law | CLOSED |
| A15-F5 | no statistical input domain | `RWCCalibrationInputErrorV1` typed refusals (finite, [0,1], nonempty, count match, 1≤bins≤n, (S+1)%20==0); INVALID INPUT != VALID METRIC | CLOSED |
| A15-F6 | raw-Int coverage rates | `coverageV2` typed counters; impossible counts typed refusals; zero denominators `NOT_APPLICABLE` (never 0); hard gate requires valid nonzero in-dist denominator; exact-0.80 boundary tested | CLOSED |
| A15-F7 | Python `hash()` seeding | SHA-256 seed law; canonical Swift engine (no numpy on host — recorded); TWO full power runs BYTE-IDENTICAL (sha256 `3f71f356…`); python differential byte-identical under PYTHONHASHSEED {random,1,2,3,999} (sha256 `3ff6929d…`) with committed bit-exact fixtures verified from Swift | CLOSED |
| A15-F8 | self-referential freeze commit | NON-CIRCULAR TWO-PHASE freeze: METHODOLOGY ANCHOR COMMIT `d380dad1…` (all frozen files final) → manifest V3 generated in the NEXT commit; per-path `git diff anchor..HEAD` EMPTY (suite-verified); anchor ancestry law; tag object never fabricated — pinned by audit + future PASS lock | CLOSED |
| A15-F9 | order-dependent equal-mass binning | TIE-GROUP BINNING LAW: atomic equal-value groups; integer bin map `(cStart*B)/n`; exact per-group sums ⇒ permutation-invariant pure function of the multiset (200-shuffle battery; AUDIT15 flip case now identical); cross-language frozen algorithm text | CLOSED |
| A15-F10 | "absolute miscalibration bound" overclaim | renamed `nullAdjustedExcessECE`; gates v3 `scientific_status`: OPERATIONAL ACCEPTANCE STATISTIC, explicitly NOT an unbiased estimator and NOT a bound; `claim_scope_law`: a PASS NEVER means "true calibration error <= 5%" or "calibrated everywhere" | CLOSED |
| A15-F11 | S=200, unseeded evaluation | frozen SHA-256 evaluation-seed law (production verdict single-valued); EXACT MC test (p_MC=(1+exceed)/(S+1); integer boundary `20*(1+exceed)<=S+1`); S selected by PREDECLARED rule (null-suite mixed ≤1.5%): measured **0.0% at ALL candidates {999,4999,9999}** ⇒ S=999 by the rule, no post-hoc tuning; at-boundary 3.3% honestly documented as inherent | CLOSED |
| A15-F12 | guard trusted caller strings | PASS-LOCK SCHEMA + `RWCCorpusEntryVerifierV2`: repository-truth verification (annotated tag OBJECT, dereference, audit/anchor commits, ancestry, live hashes, SET-EQUALITY surface scan, zero-visibility); unforgeable `RWCVerifiedCorpusEntryV1` (fileprivate init); synthetic-git-fixture attack battery incl. tag-rebind and EXTRA-FILE expansion; **NO PASS LOCK EXISTS in R2** (real-repo verify ⇒ `lockMissing`, suite-pinned); global+per-asset composition law | CLOSED |
| A15-F13 | register hard-coded evaluation | registration is use-agnostic record-integrity; training-only registrable; evaluation use still refused | CLOSED |
| A15-F14 | IRR guidance optimistic | `RWC_IRR_PLANNING_V3.md`: MIN_VALID=50 vs PLANNED_TARGET_N=300; threshold NOT weakened | CLOSED |
| A15-F15 | PRE-10/PRE-11 outside freeze | inside the v3 inventory (files unedited) | CLOSED |
| A15-F16 | expired-registrable + time travel | `expiredAtRegistration` + monotone no-time-travel query law | CLOSED |
| A15-F17 | "Type-I=5% by construction" | exact 5.0% proven for the MC test gate alone ((S+1)%20==0); combined rule measured 2.0–7.5%/cell honestly | CLOSED |
| A15-F18 | dashes-only pointer | V2 grammar requires ≥1 alphanumeric | CLOSED |
| A15-F19 | device floor citation | NOT closed by invention: no device evidence created; F16 stays OPEN blocking RWC-DEVICE | CARRIED (honest) |
| A15-F20 | "v1 byte-preserved" wording | corrected to RECOVERABILITY truth (master manifest + freeze v3 `historical_truth`) | CLOSED |

## Power/stability re-derivation (pre-data, predeclared)

Stability: null-suite mixed-verdict 0.0% at all S candidates; S=999 by the predeclared rule.
Power (S=999, trials=200, 6 shapes × {400,800,1600}): null false-reject 2.0–7.5%/cell; **n=800
independently re-selected** (n400 min over07 0.48 REJECTED; n800 min 0.88/0.935); δ-sensitivity at
n800: .03→17–44% (below reliable detection — honest), .05→61–92%, .07→≥88%, .10→100%; tail07 min
25%, osc05 min 18.5%, localized07 min 5% — structured-profile limitations honestly recorded and
mitigated by the `high_confidence_tail` slice law + per-bin diagnostics + claim-scope law.

## Zero-data proof (suite-asserted)

corpus_count 0 · annotator_count 0 · real_fit_count 0 · heldout_open_count 0 · data_visibility
false · NO PASS LOCK exists · `preregistrationAuditPassed == false` · 59 engineering pairs ·
production score gate CLOSED · display OFF · Presentation blocked · device budgets
UNSET_PENDING_BASELINE.

## Next

Single permitted next step: **independent clean-session RWC PRE-14 R2 re-audit** of tag
`gen8-rwc-preregistration-r2-audit-candidate`. Only a closeout AFTER its PASS may create the PASS
lock; corpus acquisition stays FORBIDDEN until then.
