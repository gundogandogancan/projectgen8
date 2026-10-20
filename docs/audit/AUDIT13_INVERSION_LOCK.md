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

## ADDENDUM (same closeout round, committed BEFORE the inverting change — ordering law preserved)

Applying the mandate's ORDERED additions (AUDIT13 alias record; RES-006) collided with three further
AUDIT13 census pins that pin registry CARDINALITY at the candidate. The additions are mandated; the
pins therefore invert. Declared here exhaustively, discovered before any inverting commit existed:

### I-2 · `testA13_20_AliasRegistryResolvesDeterministically_NoCollision`
- `XCTAssertEqual(Set(a.keys), Set((2...12)…), "exactly AUDIT2..AUDIT12")` →
  `Set((2...13)…), "exactly AUDIT2..AUDIT13 (AUDIT13 resolver added at governing lock)"`.
  All per-record laws (existence, collision, SHA resolution, non-empty verdict) unchanged and must
  hold for the new AUDIT13 record too.

### I-3 · `testA13_36_ResolutionLedger_RealPriorStates_NoInventedClosure`
- Record-ID census `[RES-001…RES-005]` → `[RES-001, RES-002, RES-003, RES-004, RES-006, RES-005]`
  (physical file order; RES-006 inserted at governing lock per mandate §7).
- A13-F8 pin (`effective_commit == "CP-R1"` for all records) → RE-ANCHORED exactly as the pin's own
  text prescribes ("should be re-anchored to the candidate SHA at lock time via the ledger"):
  RES-001..005 `effective_commit == "12300e6"` (machine-resolvable R1 candidate that made them
  effective); RES-006 carries the symbolic `"CP-GOVERNING-LOCK"` plus a machine `anchor_tag`
  (`gen8-ulu-evren-control-plane-r1-locked-governing`) — a record can never carry its own commit SHA;
  this structural latest-record limitation is documented in the inverted assertion message.
  → A13-F8: CLOSED for RES-001..005 by the auditor's own prescription; carried as the documented
  latest-record pattern for the newest entry.
- Every other assertion in the test (evidence reality, frozen-string checks, RES-004/005 applied
  state, BLK-H1 deliberately-open) unchanged.
