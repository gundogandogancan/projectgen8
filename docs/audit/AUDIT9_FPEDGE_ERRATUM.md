# AUDIT9 FP-EDGE ERRATUM — correction record for A10-F3-FPEDGE (LOW)

**Status:** CORRECTION RECORD (erratum — historical artefacts stay byte-identical).
**Correction date / state:** 2026-10-20, R1 fix round on `phase/real-world-calibration`
(start HEAD `6f1cff7`; the erratum commit SHA is the commit introducing this file).

## Historical claim (FALSE)

> "0.3*10 rounds DOWN in binary fp → bin 2, exactly once."

Stated in four places at candidate `28865c3`:

1. `packages/GuardianKit/Sources/GuardianCore/CalibrationIntegrityV1.swift` doc-comment
   ("e.g. 0.3*10 rounds DOWN") — **corrected in source** in this R1 round (living code, not evidence).
2. `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT9_P009ER1Probes.swift` line ~333 (active) —
   **NOT edited**: the file is pinned by AUDIT10 P17 to differ from the frozen original by exactly the
   single declared A9-R1-F3 hunk; a second edit would mutate audit evidence. Corrected by this erratum.
3. `docs/audit/AUDIT9_P009ER1Probes_ORIGINAL_LOCKED.swift.txt` (frozen original, same comment) —
   **NOT edited**: byte-exact frozen evidence (SHA `a349a487…`). Corrected by this erratum.
4. `docs/calibration/REAL_WORLD_CALIBRATION_ENTRY_GATE_IMPLEMENTATION_REPORT.md` ("fp-edge doc
   (0.3×10 rounds down)") — **corrected in place** in this R1 round (living builder report; the
   original wording is preserved verbatim above and in AUDIT10's report).

The AUDIT9 *report* language reproducing the claim (committed `0150d06` chain) is likewise immutable
and corrected by this erratum only.

## Actual measured behavior (TRUE — independently proven by AUDIT10 P15)

- `Double(0.3)` = 0.29999999999999998889…; the fp **product** `0.3 × 10.0` rounds **UP to exactly
  3.0**, so `Int(0.3 * 10.0) == 3` → bin index 3, interval [0.3, 0.4).
- Empirical sweep at `bins == 10`: **no** one-decimal boundary k/10 floors down — `Int(k/10 × 10) == k`
  for every k in 1…9. The documented "rounds DOWN" story is false everywhere, not just at 0.3.
- Executable witness: AUDIT10 `testP15_F3_AuditorOwnedMath_ExactBoundaries` (frozen probe family).

## Affected semantics

Documentation truth only. The bin-assignment law `index = min(bins-1, floor(p*bins))` is deterministic
and assigns every valid prediction to exactly one bin **either way**; which concrete bin 0.3 lands in
does not change any aggregate.

## Metric impact

**None.** All historical engineering metrics (TRAIN MAE .628 / CAL MAE .743 / HELD_OUT .559 /
risk ECE .250 UNMET / Brier .139 / AUROC .938 / sentinel falseSafe 0) are computed over the same
deterministic exactly-once assignment and were reproduced unchanged by two independent auditors
(AUDIT9, AUDIT10) and again in this R1 round.
