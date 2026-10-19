# P009B — Rights-Clear Multimodal Eval Corpus (R1: split-independent V2)

**Active corpus:** `P009BCorpusV2` (`packages/GuardianKit/Sources/GuardianCore/P009BCorpusV2.swift`) · **Date:** 2026-10-19

## R1 correction record (F2/F3/F4 — the audit was right)

- **F2:** the original `P009BCorpusV1` acted only through `seed % 2`: STRESS(2) ≡ TUNE(0) and
  OOD(3) ≡ HELD-OUT(1) **byte-identical**; CAL(9) ≡ HELD-OUT(1); held-out was a TR translation of tune.
  That design is invalid split evidence. V1 is retained ONLY as frozen audit evidence (the AUDIT3 probes
  characterize it); it feeds **no gate** anymore.
- **F4:** V1 actually contains **18** scenarios (docs/prints previously claimed 17 — corrected everywhere;
  the TUNE print now derives the count from code).
- **F3:** the earlier STRESS/OOD doc claims ("different surface variants", "route reports
  all-modalities-unavailable in the all-unavailable scenario") were false and are retracted — see
  P009B_STRESS_OOD_RESULTS.md.

## V2 design (split independence by construction)

No seed parameter exists. Every split is a separately AUTHORED bank with distinct scenario instances,
surface text (TR and EN mixed **inside** every split — held-out is NOT a translation of tune), modality
combinations, temporal structures (scripted `TemporalStepV1` sequences), and OOD transforms.

Scenario counts (generated from code — `P009BCorpusV2.countsBySplit`, asserted by `testDocCodeConsistency`):

- TUNE: 24
- HELD_OUT: 16
- STRESS: 10
- OOD: 8
- CALIBRATION_RESERVED: 6

## Leakage auditor (runs in the suite — `CorpusSplitLeakageAuditorV1`)

Fails on: exact canonical duplicates across splits (also catches any seed-style aliasing), duplicate
scenario names, and **near-template leakage** under the declared rule: surface-token Jaccard > 0.8 with
the same modality combination. The detector's rule is itself tested against a planted near-copy
(`testF2DetectorCatchesPlantedNearDuplicate`). Current result: **0 violations**.

## CALIBRATION_RESERVED

Authored (6 scenarios), fingerprinted (`CorpusSplitLeakageAuditorV1.reservedBankFingerprint()` =
FNV-1a `aa6bd546ae28278f`), and **never executed** in P009B — reserved intact for P009C calibration.
The only permitted access is hashing/reservation verification.

## New R1 §11 families (all in TUNE, with distinct held-out/stress instances where applicable)

sarcasm-vs-literal (literal trigger must survive; no sarcasm label may be fabricated — none exists),
cheerful-visual + distressing-audio (contradiction required), risky→benign recovery (historical strong
risk survives the calm ending — monotone-max — and is represented as a contradiction), montage,
repeated scene (`routeTwice` + cache-hit expectation), talking-head + B-roll (narrative shifts).

## Rights status & limits

100% project-authored derived-input bundles; no third-party media; provenance = the source files
(registered in the §19 asset ledger). The corpus validates mesh ROUTING/HONESTY/STRUCTURE semantics —
it is NOT a real-world perception-accuracy measurement and carries no exact P/R claims. Real perception
is exercised separately through `RealObservationToExpertInputAdapterV1` (real Vision OCR trace test) and
the user-gated device run.
