# AUDIT10 INVERSION LOCK — pre-declared probe migration manifest (R1 fix round)

**Status:** IMMUTABLE MIGRATION RECORD. Committed **BEFORE** any inverting code change (pre-declaration
law: the fix commits reference this manifest; this manifest never references fix SHAs).
**Created:** 2026-10-20 on `phase/real-world-calibration`, start HEAD `6f1cff7` (= AUDIT10 verdict
commit; audit target candidate `28865c3`).

## Frozen original

`docs/audit/AUDIT10_RealWorldCalibrationEntryGateProbes_ORIGINAL_LOCKED.swift.txt`
SHA-256: `a1ffb855cea4af9b9ee83e88e9240982d4df31d5393dac2b5a668c597caf0580`
(byte-exact copy of `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT10_RealWorldCalibrationEntryGateProbes.swift`
at HEAD `6f1cff7`, the commit that introduced it.)

## Law

AUDIT10's probes P08, P10 and P14 **characterize pinned defects** (A10-F2-WIRING, A10-F2-MULTISET,
A10-F3-SIBLINGS). Their messages pre-authorize exactly this migration ("If this assertion now fails,
the defect was fixed: re-audit and retire the finding via the frozen-original discipline (never
silently)"). Fixing the defects necessarily inverts those characterization assertions. Discipline:
freeze original (above), pre-declare every inversion here, apply ONLY the declared inversions, keep
every other AUDIT10 expectation byte-identical. **No inversion may be used to hide a regression** —
each inverted assertion asserts the FIXED behavior, which is strictly stronger than the pinned defect.

## Declared inversions — exhaustive list (nothing else may change in the probe file)

### I-1 · `testP08_F2_ProductionCallgraph_GuardIsUnwired_Pinned` — part (a) only

Pinned defect: harness source does NOT reference the integrity gate; silent `else { continue }` drop
present. Fixed truth: the harness routes the declared ledger through the canonical integrity pipeline
`CalibrationRunPreparationV1` (which calls the hardened `CalibrationRunGuardV1`); the silent drop is gone.

- `XCTAssertFalse(harnessSrc.contains("requireFullResolution"), …)` →
  `XCTAssertTrue(harnessSrc.contains("CalibrationRunPreparationV1"), "A10-F2-WIRING FIXED: the real fit path routes through the canonical integrity pipeline")`
- `XCTAssertTrue(harnessSrc.contains("else { continue }"), …)` →
  `XCTAssertFalse(harnessSrc.contains("else { continue }"), "A10-F2-WIRING FIXED: the silent-drop control flow is gone from the real fit path")`
- The (a) block comment is updated to FIXED tense and cites this manifest.
- Parts (b)/(c)/(d) stay byte-identical: (c) remains a self-contained replica demonstrating the
  *former* defect shape; (d) still proves the guard refuses the phantom-bearing ledger.

### I-2 · `testP10_F2_MultisetDuplicates_PinnedDefect` — both pins

Pinned defect: `[a,a,b]` vs `[a,b,b]` and `[a,a]` vs `[a,b]` ACCEPTED. Fixed truth: composite IDs are
unique by contract (duplicate declared/resolved IDs are typed integrity errors), so both shapes REFUSE.

- `XCTAssertTrue(accepted, "FINDING A10-F2-MULTISET: …")` →
  `XCTAssertFalse(accepted, "A10-F2-MULTISET FIXED: [a,a,b] vs [a,b,b] refused (duplicate-declared typed error)")`
- `XCTAssertTrue(accepted2, "FINDING A10-F2-MULTISET(b): …")` →
  `XCTAssertFalse(accepted2, "A10-F2-MULTISET(b) FIXED: [a,a] vs [a,b] refused (duplicate-declared typed error)")`
- The test's doc comment and the trailing `print` label flip from "pinned" to "inverted/FIXED" tense
  and cite this manifest.

### I-3 · `testP14_F3_LegacyNaNMarker_And_UnguardedSiblings_Pinned` — auroc pin only

Pinned defect: legacy `auroc()` swallows NaN via comparison semantics and returns a finite WRONG value
(silent miscount — no marker at all). Fixed truth: legacy `auroc` refuses invalid probability inputs
via its existing undefined-channel (`nil`); the strict typed path is `aurocStrict` (typed throw).

- `XCTAssertNotNil(aurocNaN)` + `XCTAssertFalse(aurocNaN!.isNaN, "FINDING A10-F3-SIBLINGS: …")` →
  `XCTAssertNil(aurocNaN, "A10-F3-SIBLINGS FIXED: legacy auroc refuses invalid preds via nil marker; aurocStrict is the canonical typed path")`
- The legacy-`mae` pin `XCTAssertTrue(maeNaN.isNaN, …)` **remains TRUE and is NOT inverted** (mae now
  returns the NaN refusal marker *explicitly* instead of by accidental propagation); only its message
  is updated from "silently propagates NaN (no refusal)" to "explicit NaN refusal marker; maeStrict is
  the canonical typed path".
- The test's finding comment (lines pinning "NO domain guard") and the trailing `print` label are
  updated to FIXED tense and cite this manifest.

## Explicitly NOT inverted (must stay green against the fixed code)

P01–P07 (F1 matrix), P08(b,c,d), P09, P11, P12, P13, P15, P16, P17, P18, P19 — byte-identical.
P11's full-resolution acceptance (`all.shuffled()`) remains the order-independence contract; P09/P11/P12
typed-shape expectations (`.unresolvedPairs` with counts + sorted IDs + category) are preserved by the
hardened guard for the missing-ID class.

## Verification hooks (R1 test family)

`RWCEntryGateR1Tests` re-verifies from disk: frozen-original SHA byte-exact; the active probe file
contains each declared FIXED assertion and none of the three retired pinned assertions; and the fixed
behaviors hold at the API level independently of the probe file.
