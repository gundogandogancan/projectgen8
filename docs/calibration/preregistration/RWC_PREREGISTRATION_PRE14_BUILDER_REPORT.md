# RWC PREREGISTRATION — PRE-14 BUILDER REPORT (2026-10-20)

First real execution of the LOCKED GOVERNING control plane. Entry `2c345b6` (tag
`gen8-ulu-evren-control-plane-r1-locked-governing`); branch `phase/rwc-preregistration-preparation`.
Baseline remeasured at entry: **817/817**. Final: **830/830 ×2** (+13 RWCPreregistrationTests).
Builder cannot self-PASS: **RWC-PRE-14 independent preregistration audit required** before RWC-CORPUS.

## Per-node status (all BUILDER_COMPLETE; packets in `packets/`, hashes in the master manifest)

| Node | Deliverables | Key law | Tests |
|---|---|---|---|
| PRE-01 rights | `RWC_PRE01_RIGHTS_GOVERNANCE.md` + `RWC_ASSET_RIGHTS_LEDGER_SCHEMA.yaml` + `RWCAssetRightsLedgerV1.swift` | eligible = PROJECT_OWNED_REAL/LICENSED only; 4 refused classes explicit; fail-closed per use (unknown use refused); monotone revocation; opaque pointers; **zero assets** | eligibility matrix, revocation, zero-records |
| PRE-02 identity | `RWCAssetIdentityV1.swift` + protocol doc | `rwc-asset-[a-z0-9]{8,32}`; ASCII byte-law, NO normalization (canonical-input law); `#` forbidden in components → composite aliasing structurally impossible; **closes A11-IDCHARSET + A11-COMPOSITE-ALIAS** | adversarial matrix (newline/tab/NFC/NFD/Cyrillic/case/##/overlength/empty) |
| PRE-03 legacy | retirement law + markers | HARDEN not delete (FM-014): `EngineeringOnlyExecutionContextV1` (no real-world case exists — compile-time separation), deprecations, bridgeless type worlds; **behavior unchanged — AUDIT11 legacy pins green**; **closes A11-LEGACY-P008** | bridgeless + marker + pinned-behavior tests |
| PRE-04 executor | `PreparedCalibrationDatasetV1` (fileprivate init) + `RealWorldCalibrationExecutorV1` | single door `prepareDataset` (guard v2 before token exists; `@testable` cannot forge); executor accepts ONLY the token; **double typed refusal** (`preregistrationNotPassed(RWC-PRE-14)` → `fitPhaseNotAuthorized(RWC-FIT)`); **closes A11-F2-APIBYPASS structurally** | bypass matrix + double-refusal tests |
| PRE-05 handbook | TR/EN v1 (single-source generated) | 17 dimensions × 7 mandatory fields; structural parity machine-checked; original archetypes; frozen pre-annotation | parity 17×7 test |
| PRE-06 isolation | protocol | blindness matrix (incl. sentinel indistinguishability, split identity, model outputs); seeded assignment; append-only logs; opaque annotator IDs; abstention first-class, no quotas | law-presence test |
| PRE-07 adjudication | protocol | triggers (REQUIRED at \|A−B\|≥2, safety splits, abstain-vs-label); A/B originals NEVER rewritten (third layer; engineering precedent CalibrationAnnotationV1); UNRESOLVED_AMBIGUOUS; safety escalation | law + precedent test |
| PRE-08 IRR | methodology + `RWCStatisticsV1` | quadratic-weighted κ ≥.60 (justified pre-data), α ≥.67, **strong-protection tightened to α ≥.80**; 50-pair minimum; degenerate → INSUFFICIENT_DATA (nil, never 0/1); seeded bootstrap CI | hand-verified κ=.5 fixture, α laws |
| PRE-09 feasibility | analysis + calculators | preregistered assumptions only; zero-event law: n≥150 ⇒ 95% UB ≤2% (exact 3/n family); ECE pool ≥400, HELD_OUT ≥150; slices 60/15/15; "zero observed ≠ zero rate" binding | 3/n, planning-n=385/196, Wilson fixtures |
| PRE-10 slices | `RWC_SLICE_DEFINITIONS.yaml` | 21 slices; powered law; underpowered → UNKNOWN, never aggregate-hidden; mixed-language pre-declared scarce | registry test |
| PRE-11 gates | **`RWC_FROZEN_GATES.yaml` FROZEN** | feasibility→freeze→data order honored (`data_visibility_at_freeze:false`); ECE ≤.05 overall / ≤.07 powered slices / falseSafe 0-observed + UB ≤2% / MAE ≤.80 held-out / AUROC+Brier REPORT-only (hard gate REJECTED with reason); 4 rejected/modified candidates documented; invalidation law | gates test |
| PRE-12 splits | protocol | item + near-duplicate + creator-cluster disjointness; HELD_OUT_FINAL SHA-sealed run-once with opening log; material-change → FINAL-status loss; emergency invalidation | law test |
| PRE-13 device | protocol | full-path measurement set; device matrix; cold/warm/≥3 repeats/10-min thermal; release vs debug logging as SEPARATE cells (thermal-SERIOUS history); UNKNOWN never imputed; **no measurements claimed** | law test |

## A13-F2 hygiene (packet requirements)

Packet `requirements` were read from the AUTHORITATIVE registry (all P0); the requirement-map
`release_blocking:false` nuance on 14 records (A13-F2) was NOT trusted — packets derive blocking from
registry priority + governing graph. Discrepancy carried as the existing A13-F2 LOW (no control-plane
redesign).

## A13-F4 (outcome-blind evidence) — RWC-specific encoding

PRE-14 audit requirement (packets + this report): an audit/evidence reference whose verdict is
FAIL/FIX-class may NEVER count as satisfactory evidence for any PRE node closure. Encoded for the
preregistration program only (no control-plane rewrite).

## Zero-data proof (load-bearing, suite-asserted)

`corpus_count = 0` · `annotator_count = 0` · `real_fit_count = 0` · `heldout_open_count = 0` ·
`data_visibility = false`. Freeze manifest hashes 15 binding artifacts (SHA-256, drift = suite failure)
with the declaration: **NO REAL CORPUS RESULTS WERE AVAILABLE WHEN THESE GATES WERE FROZEN.**

## Limitations / carried

ECE ≤.05 frozen vs engineering .250 (BLK-ECE-UNMET — honest gap, gate NOT relaxed) · PRE-13 is protocol
only (BLK-DEVICE-RWC-OPEN/BLK-H4 carried) · mixed-language slice expected UNDERPOWERED initially ·
handbook examples are archetypes, not a labeled corpus · executor flag flip requires post-PRE-14
evidence commit (FM-003 class if violated) · control-plane A13 LOW/INFO carried unchanged.

## Next

Single permitted next step: **independent clean-session RWC-PRE-14 preregistration audit** of the
candidate tag. Only its PASS can unlock RWC-CORPUS.
