# AUDIT13 INVERSION LOCK — pre-declared probe migration manifest (Governing Closeout)

**Status:** IMMUTABLE MIGRATION RECORD. Committed BEFORE the inverting change.
**Created:** 2026-10-20 on `phase/ulu-evren-control-plane`, start HEAD `f72e9ad` (AUDIT13 PASS commit;
audit target `12300e6`).

## Frozen original

`docs/audit/AUDIT13_ControlPlaneR1ReauditProbes_ORIGINAL_LOCKED.swift.txt`
SHA-256: `be8384cc60efe38b297518f56454f900a44a980836b004a9b40792c7572b097f`
(byte-exact copy of the active AUDIT13 probe file at HEAD `f72e9ad`, the commit that introduced it.)

## Law

The governing-closeout mandate ORDERS the A13-F1 correction (exact historical verdict truth in the
alias registry). AUDIT13's `testA13_21` pins the DEFECTIVE paraphrases as current truth; the correction
necessarily inverts exactly that pin block and NOTHING else. All other closeout state is expressed
ADDITIVELY (twin `governing_lock` overlay, DAG `post_lock_next_action`, new AUDIT13 alias record, new
docs/tests) precisely so that NO other frozen AUDIT12/AUDIT13 live-state pin is touched: the candidate
snapshot in `nodes[]`, `current_next_action`, status census, CP node truth values and the live computed
READY set remain byte-level unchanged.

## Declared inversion — exhaustive (nothing else may change in the probe file)

### I-1 · `testA13_21_AliasVerdictIntegrity_TwoUpgradedRecords_FINDING` — the two A13-F1 pins only

Pinned defect: alias registry carries PASS-class paraphrases for the FIX-class AUDIT3/AUDIT5 reports.
Fixed truth: registry carries the EXACT immutable verdicts plus explicit later-generation pointers.

- `XCTAssertEqual(a["AUDIT3"]?["verdict"], "PASS WITH LIMITATION — ENGINEERING MESH LOCKED", "A13-F1 pin…")` →
  `XCTAssertEqual(a["AUDIT3"]?["verdict"], "FIX CRITICAL P009B FINDINGS", "A13-F1 FIXED: exact historical verdict")` +
  `XCTAssertEqual(a["AUDIT3"]?["superseded_by"], "AUDIT4", "later successful re-audit generation")`
- `XCTAssertTrue((a["AUDIT5"]?["verdict"]).hasPrefix("PASS WITH FINDING"), "A13-F1 pin…")` →
  `XCTAssertEqual(a["AUDIT5"]?["verdict"], "FIX CRITICAL P009C FINDINGS", "A13-F1 FIXED: exact historical verdict")` +
  `XCTAssertEqual(a["AUDIT5"]?["superseded_by"], "AUDIT6", "later successful re-audit generation")`
- The report-truth assertions (`r3/r5 contain the FIX verdict lines`; the registry's old paraphrase
  appears nowhere in the reports) STAY — they were always true and remain true.
- The finding's doc-comment flips to FIXED tense citing this manifest and RES-006.
- The exact-match loop in the same test may ADD `"AUDIT3", "AUDIT5"` to its verbatim-verdict alias list
  (the fixed records now satisfy the stronger law) — declared here as part of I-1.

## Explicitly NOT inverted

Every other AUDIT13 probe (A13_01–A13_50 minus the single block above) and ALL AUDIT12 probes stay
byte-identical and must stay green: the closeout's post-lock state lives in the ADDITIVE overlay, and
the live snapshot they pin is unchanged. Historical AUDIT3/AUDIT5/AUDIT13 reports are untouched.
