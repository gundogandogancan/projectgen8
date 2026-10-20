# REAL-WORLD CALIBRATION ENTRY GATE — R1 FIX REPORT (2026-10-20)

Builder round closing the AUDIT10 findings. Start HEAD `6f1cff7` (AUDIT10 verdict commit; audit target
candidate `28865c3`). Baseline remeasured before any change: **661/661, 0 failures**. Scope law obeyed:
no new features, no real-world corpus, no human annotation, no calibration fitting, no held-out work,
no Presentation/Glyph/Motion. The builder does not grade its own work: final PASS belongs to the
independent clean-session R1 re-audit.

## 1. Calibration call graph (measured before fixing — §3.1)

Before R1 (candidate `28865c3`):

```
CalibrationDatasetRegistryV2.pairs (DECLARED, 59)
   ↓ P009EScoreTests.setUp loop:  guard let sc = scenario(for: pair) else { continue }   ← SILENT DROP
RESOLUTION (per-pair, unresolved pairs vanish)
   ↓ (NO integrity gate — CalibrationRunGuardV1 existed with ZERO non-test callers)
FIT (DimensionCalibratorV1 ×6 slices + SuitabilityFusionModelV1 on TRAIN_TUNE)
   ↓
METRICS (legacy mae / eceAndBins / auroc)
```

After R1:

```
CalibrationDatasetRegistryV2.pairs (DECLARED, 59)
   ↓ CalibrationRunPreparationV1.prepare(declared:resolve:)       ← THE ONLY DOOR
RESOLUTION (every pair resolved or recorded unresolved — cannot be skipped)
   ↓ CalibrationRunGuardV1.requireFullResolution (v2)             ← INTEGRITY GATE ABOVE FIT
     typed CalibrationIntegrityErrorV1: malformedIDs | duplicateDeclaredIDs | duplicateResolvedIDs
     | unresolvedPairs | unexpectedResolvedIDs  →  NO fit, NO MAE/ECE/AUROC, NO partial report
   ↓ records exist ONLY on success
FIT (unchanged algorithms, unchanged data)
   ↓
METRICS — STRICT TYPED ONLY: maeStrict(domain 0…4) / eceAndBinsStrict / aurocStrict
```

The silent-drop construction is impossible through the canonical API: `prepare` returns records only
after the gate passes; a caller never sees a partial dataset.

## 2. Finding matrix

| Finding | Prior severity | Audit evidence | Exact fix | Fresh evidence | Status | Residual risk | Next program |
|---|---|---|---|---|---|---|---|
| A10-F2-WIRING | MEDIUM | P08: guard had 0 non-test callers; real fit path kept `guard … else { continue }`; builder success test tautological | NEW `CalibrationRunPreparationV1` (canonical DECLARED→RESOLUTION→GATE→FIT pipeline); `P009EScoreTests.setUp` migrated — silent drop DELETED; refusal ⇒ zero results, nothing fitted, typed error recorded; tautology replaced with real-ledger/real-resolver proof | `RWCEntryGateR1Tests` A/B/K (58/59 and 59/60 through the REAL entrypoint+resolver REFUSE; zero records escape; live harness gate-accepted 59/59); inverted P08(a) asserts wiring from source | **CLOSED** | enforcement that FUTURE harnesses use the door is convention + probes (Swift can't forbid a new rogue loop); re-audit should re-scan call graph | real-corpus runs must enter via the same door (constitution addendum) |
| A10-F2-MULTISET | MEDIUM | P10: `[a,a,b]`~`[a,b,b]` and `[a,a]`~`[a,b]` ACCEPTED (set-containment+count cancellation) | `CalibrationRunGuardV1` v2 exact-identity law: malformed → duplicate-declared → duplicate-resolved → missing → unexpected-extra, five typed errors; uniqueness makes set==multiset | R1 tests C–J incl. both AUDIT10 cancellation shapes, masked dup, real-pair duplicate via pipeline, order-independence preserved; inverted P10 asserts refusal | **CLOSED** | none known at guard level; registry contract (V2 authored duplicate-free) now enforced, not assumed | real-corpus ledger inherits uniqueness law |
| A10-A9-DISCIPLINE | LOW | AUDIT9 inversion lacked a dedicated lock-doc; in-file "ENTRY_GATE lock notes" pointer dangled; `b08406c` message overstated docs | `docs/audit/AUDIT9_F3_INVERSION_LOCK.md` (full manifest: SHAs, assertions, legitimacy, no-rewrite proof, rollback); pointer resolved by CREATING `docs/calibration/ENTRY_GATE_LOCK_NOTES.md` (the pinned AUDIT9 file is immutable per AUDIT10 P17 — not edited); commit-message imprecision recorded as historical truth in the lock doc | R1 discipline test verifies artefacts from disk + AUDIT9 single-hunk shape unchanged + frozen SHA `a349a487…` byte-exact | **CLOSED** | the in-file pointer text still reads "lock notes" generically; resolution is by artefact, not by edit (deliberate — evidence immutability wins) | inversion manifests now standard (AUDIT10 one pre-declared the same way) |
| A10-F3-SIBLINGS | LOW (CLOSED_WITH_LIMITATION at audit) | P14: `mae` NaN-propagation; `auroc` silent finite miscount on NaN; strict-only enforcement was a comment | Shared `validateValues` doctrine; NEW `maeStrict` (shape/finite/explicit domain/emptyInput) + `aurocStrict` (probability domain + typed `degenerateLabels`); legacy `mae` → explicit NaN refusal marker (incl. shape mismatch, formerly silent zip-truncation), legacy `auroc` → nil undefined-channel on invalid input; pipeline migrated to strict-only (`evalMAE`→maeStrict 0…4, risk reliability→eceAndBinsStrict+aurocStrict) | R1 MAE/AUROC matrices (NaN/±inf/<0/>1/shape/empty/degenerate both classes/domain law/tie law/strict==legacy on valid); inverted P14 auroc pin; historical metrics byte-stable | **CLOSED** | legacy non-throwing signatures still exist (markers, not types) for API compatibility; `CalibrationMetrics.swift` (pre-P009E pilot file, outside the calibration pipeline) untouched — recorded here, not hidden | real-data metrics will be computed strict-only |
| A10-F3-FPEDGE | LOW | P15: `Int(0.3*10.0)==3`; "rounds DOWN → bin 2" false in 4 places | Living sources corrected in place (CalibrationIntegrityV1 doc-comment; implementation report — original wording preserved verbatim in the erratum); immutable carriers (AUDIT9 report, frozen original, P17-pinned active AUDIT9 comment) corrected via `docs/audit/AUDIT9_FPEDGE_ERRATUM.md` | R1 fp-edge test: ground truth + living sources corrected + erratum preserves historical wording | **CLOSED** (living) / erratum (historical) | the false sentence remains readable in immutable historical artefacts BY DESIGN, flagged by erratum | none needed — metrics unaffected either way |
| A10-F1-COVERAGE | LIMITATION | P02: 4/4 lexicon-missing violence paraphrases component-ALIGNED at risk .9 (no end-to-end false-safe) | **No code change (mandate §9: no overfix)** — no synonym lists, no threshold tuning, no invented classifier | — | **CARRIED_LIMITATION** | real violence detection remains NOT validated; cue-gated invariant only | resolved only by rights-clear real corpus + real multimodal evaluation (post-entry-gate program) |
| A10-F1-FALSETRIGGER | INFO | P03: benign educational cue-bearing text → teen review (risk-independent) | No change — doctrine-consistent fail-closed over-restriction (same class as the accepted sexual-sentinel precedent) | — | **CARRIED (RECORD)** | over-restriction on cue-bearing benign educational content | revisit with real-data evaluation |
| A10-DOC-CJK | INFO | stray "扩展" in implementation report | token replaced with "extension", change noted inline | report diff | **CLOSED** | — | — |
| A10-F2-VACUOUS | INFO | `testF2_FullResolutionSucceeds` could not fail | folded into the F2 fix: test now proves the real pipeline on the real ledger | the replaced test | **CLOSED** | — | — |

## 3. AUDIT10 probe migration (frozen-original + pre-declared inversion discipline)

- Frozen original: `docs/audit/AUDIT10_RealWorldCalibrationEntryGateProbes_ORIGINAL_LOCKED.swift.txt`,
  SHA-256 `a1ffb855cea4af9b9ee83e88e9240982d4df31d5393dac2b5a668c597caf0580` (R1-test-asserted from disk).
- Manifest `docs/audit/AUDIT10_INVERSION_LOCK.md` committed (`e2d008d`) BEFORE every inverting commit.
- Exactly three inversions applied (I-1 P08(a) wiring, I-2 P10 multiset, I-3 P14 auroc pin) — each
  anticipated by the probes' own messages; every other AUDIT10 expectation untouched and green,
  R1-test-verified (declared FIXED markers present in active, absent from frozen; retired pins absent
  from active, preserved in frozen).
- AUDIT9 artefacts: zero bytes changed in this round (frozen SHA re-asserted; single-hunk shape re-asserted).

## 4. Verification

- Baseline (pre-change): 661/661 ×1.
- Per-commit: 661/661 after identity fix; 662/662 after wiring (+1 wired-gate test); 662/662 after F3.
- Focused R1 family: 17/17. Full suite final runs: see candidate tag commit (recorded in return report).
- Historical engineering metrics byte-stable after all fixes: TRAIN MAE .628 / CAL MAE .743 /
  HELD_OUT .559 / risk ECE .250 (UNMET, unrelaxed) / Brier .139 / AUROC .94 / abstained=1 held-out /
  fusion w=[-1.83,1.44,-0.19,-1.00,-1.15]. The correctness fixes tuned nothing.
- Build: xcodebuild device target (recorded in return report). Build ≠ runtime proof — the
  physical-device runtime blocker (§23/D-0016) is carried, not closed.

## 5. Security / privacy

Integrity diagnostics carry opaque composite IDs + counts + category only — no content, no PII, no
paths/URLs. Constitution R1 addendum adds the OPAQUE NON-SEMANTIC ASSET ID contract for future
real-corpus ledgers. No networking, no telemetry, no raw persistence added anywhere in this round.

## 6. Locks (unchanged by R1 — all re-asserted in suite)

Production score release gate CLOSED (6/10 unmet, unrelaxed) · production display structurally OFF ·
Presentation/Glyph/Motion BLOCKED · `supportsRealWorldClaims == false` (zero real/licensed items) ·
ENGINEERING_CALIBRATION_ONLY class · no fitting, no corpus, no annotation, no held-out seal in R1 ·
forbidden claims remain forbidden ("production calibrated / scientifically validated / real-world
validated / population validated").

## 7. Carried blockers (none vanished)

ECE .250 ≫ .05 target (UNMET, honest) · real-world violence detection NOT validated (A10-F1-COVERAGE) ·
benign cue over-restriction (A10-F1-FALSETRIGGER) · physical-device runtime evidence missing ·
real corpus/annotation/IRR/held-out program not started (correctly gated behind entry-gate PASS) ·
`gh` PR flow CREDENTIALS-BLOCKED · legacy non-throwing metric signatures exist as markers (documented).

## 8. Next

Single permitted next step: **INDEPENDENT CLEAN-SESSION R1 RE-AUDIT** of the new candidate tag.
The builder asserts READY_FOR_INDEPENDENT_R1_REAUDIT — nothing more.
