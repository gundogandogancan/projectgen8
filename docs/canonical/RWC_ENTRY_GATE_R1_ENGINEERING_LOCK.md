# RWC ENTRY GATE R1 — ENGINEERING LOCK (closeout record)

**Status:** LOCKED — ENGINEERING ONLY. **Date:** 2026-10-20.
**Law:** this record is append-only; the audit reports it cites (AUDIT9/AUDIT10/AUDIT11) are immutable
and are NOT rewritten by this closeout.

## What is locked

| Field | Value |
|---|---|
| Candidate | `06b338640925b6e6df4b4acc2a71bd83052f395d` (tag `gen8-real-world-calibration-entry-gate-r1-audit-candidate`, tag object `2627744a1ae0a7be3e3356af2fe4b0c82d7d3b8b`) |
| Independent re-audit | **AUDIT11**, commit `e5b5d612c06a30288028f2943bbf822f59b6f819` — report `docs/audit/GEN8_RWC_ENTRY_GATE_R1_INDEPENDENT_REAUDIT.md`, probes `AUDIT11_RWCEntryGateR1ReauditProbes.swift` (25) |
| Verdict | **PASS — REAL-WORLD CALIBRATION ENTRY GATE ENGINEERING LOCKABLE; ULU EVREN EXECUTION CONTROL PLANE + REAL-WORLD CALIBRATION PREREGISTRATION NEXT; NO CORPUS/FITTING YET** |
| Evidence | **704/704** ×3 full-suite runs (679 historical/builder + 25 AUDIT11); zero failures |
| Fresh CRITICAL/MEDIUM findings | **ZERO** |
| Rollback | tag `gen8-real-world-calibration-entry-gate-r1-audit-candidate` (`06b3386`); pre-entry-gate fallback `gen8-p009e-r1-locked-engineering-only` (`f991aba`) |

## Verified truth (per AUDIT11, independently re-derived)

- **F2 current canonical path: VERIFIED.** `CalibrationRunPreparationV1.prepare → CalibrationRunGuardV1 (v2)` is
  the only door the current harness uses; silent drop structurally impossible through it; exact identity
  (uniqueness + set equality, order-independent) holds under lookalike/case/compound attacks.
- **F2 future-executor bypass: VERIFIED_WITH_LIMITATIONS** (A11-F2-APIBYPASS pinned) — direct fit APIs
  remain callable by hypothetical future code; gate enforcement is convention + probes + constitution
  contract today. MUST become a release-blocking invariant in RWC preregistration (RWC-PRE-04).
- **F3 metric doctrine: VERIFIED** — strict typed MAE/AUROC/ECE/Brier; legacy signatures refuse via
  markers; independent Mann-Whitney AUROC agreement to 1e-12; historical metrics independently
  recomputed with ZERO drift (TRAIN .628 / CAL .743 / HELD_OUT .559 / ECE .250 / Brier .139 / AUROC .938 / falseSafe 0).
- **AUDIT10 inversion discipline: LEGITIMATE** (manifest `e2d008d` git-proven BEFORE first inverting
  commit `905eab5`; frozen original `a1ffb855…` byte-exact; exactly 3 declared inversions, zero undeclared).
- **AUDIT9 evidence:** zero bytes changed in R1; frozen `a349a487…` byte-exact.

## What is explicitly NOT true (claim ceiling — binding)

- **REAL-WORLD CALIBRATION HAS NOT BEEN PERFORMED.** This lock must never be described as
  "real-world calibrated", "production calibrated", "scientifically validated" or "population validated".
- **F1 violence coverage = CARRIED_LIMITATION** — cue-gated routing only; paraphrase/morphology misses
  re-pinned fresh by AUDIT11 (3/3 component-ALIGNED at risk .9; no end-to-end false-safe observed, which
  is NOT detection validation).
- **ECE .250 = UNMET / UNRELAXED** (gate target ≤ .05 pending preregistration feasibility, RWC-PRE-09/11).
- Real corpus = **NOT STARTED** · independent human annotation = **NOT STARTED** · real fitting =
  **NOT STARTED** · final held-out seal = **NOT STARTED**.
- Physical-device runtime proof of the calibration/score path = **OPEN** (§23/D-0016; build ≠ runtime).
- Production score display = **BLOCKED** (ProductionScoreReleaseGateV1 CLOSED; display structurally OFF).
- Presentation/Glyph/Motion = **BLOCKED**.

## AUDIT11 fresh LOW/INFO findings (all carried into the control plane, none closed here)

| ID | Sev | Substance | Owner node |
|---|---|---|---|
| A11-F2-IDCHARSET | LOW | malformed-ID law uses `CharacterSet.whitespaces`; a newline-only ID passes as well-formed (fail-closed today, no substitution window) | RWC-PRE-02 |
| A11-F2-COMPOSITE-ALIAS | INFO | `#` separator unescaped in composite IDs; aliasing collapses to typed duplicate refusal; forbid `#` in opaque asset IDs | RWC-PRE-02 |
| A11-LEGACY-P008 / A11-LEGACY-PILOT-PATH | LOW | P008A `CalibrationPilotRunner` + old `CalibrationMetrics` enum are gate-free calibration-shaped producers (test-only callers today); harden/retire before corpus | RWC-PRE-03 |
| A11-F2-APIBYPASS | SCOPE LIMITATION | direct `DimensionCalibratorV1.fit`/`SuitabilityFusionModelV1.fit` callable without the gate | RWC-PRE-04 |
| INFO | empty-ledger vacuous gate acceptance (downstream refuses); Unicode NFC==NFD identity semantics; `ABC`≠`abc` case-sensitive by contract | RWC-PRE-02 (document in asset-ID contract) |

## Carried blockers (complete, none vanished)

ECE .250 ≫ .05 (UNMET) · real-world violence detection NOT validated (A10-F1-COVERAGE) · benign-cue
over-restriction (A10-F1-FALSETRIGGER, INFO) · physical-device runtime evidence missing (§23/D-0016) ·
RWC corpus/annotation/IRR/held-out program not started (correctly gated) · legacy non-throwing V1 metric
marker signatures + P008 pilot metrics (A11-LEGACY-*) · future-executor gate enforcement structural gap
(A11-F2-APIBYPASS) · `gh` PR flow CREDENTIALS-BLOCKED (SSH push works) · Tier-0 full item grouping
remains CONTRADICTED (shot+provisional only) · evidence-build thermal SERIOUS on device (release
logging OFF law).

## Next authorized program

**GEN8 ULU EVREN MASTER EXECUTION CONTROL PLANE** (workstream `phase/ulu-evren-control-plane`):
Project Twin + master execution DAG + failure memory + agentic execution constitution + deterministic
validation, then its own independent audit. Only after the control plane passes independent audit does
**REAL-WORLD CALIBRATION PREREGISTRATION** (RWC-PRE-01…14) become READY. Corpus acquisition remains
forbidden until the preregistration audit (RWC-PRE-14) passes.
