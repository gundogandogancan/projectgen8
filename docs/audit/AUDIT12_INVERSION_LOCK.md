# AUDIT12 INVERSION LOCK — pre-declared probe migration manifest (Control-Plane R1)

**Status:** IMMUTABLE MIGRATION RECORD. Committed BEFORE any inverting code/data change (pre-declaration
law: fix commits reference this manifest; the manifest never references fix SHAs).
**Created:** 2026-10-20 on `phase/ulu-evren-control-plane`, start HEAD `b0039eb` (AUDIT12 verdict commit;
audit target `4d6649c`).

## Frozen original

`docs/audit/AUDIT12_UluEvrenControlPlaneProbes_ORIGINAL_LOCKED.swift.txt`
SHA-256: `4671898b38159721b6bbd29d6c77c1715623175cbea8554e747a3fc0b8a24a20`
(byte-exact copy of the active AUDIT12 probe file at HEAD `b0039eb`, the commit that introduced it.)

## Law

AUDIT12 probes characterize pinned defects of candidate `4d6649c`. Remediating A12-F2/F3 (and the
directly-coupled A12-F6/F10) necessarily inverts the probes that pin the DEFECTIVE state. Discipline:
freeze original (above), pre-declare every inversion here, apply ONLY the declared inversions, keep every
other AUDIT12 expectation byte-identical. Each inverted assertion asserts the FIXED contract — strictly
stronger than the pinned defect. The mutation/characterization probes A12_22–A12_26 and A12_36 are NOT
inverted: they exercise FROZEN REIMPLEMENTATIONS of the old builder checks and remain true as historical
characterization of the old law's blindness.

## Declared inversions — exhaustive list (nothing else may change in the probe file)

### I-1 · `testA12_05_OrphanRegistryRequirements_FINDING`
Pinned defect: exactly 12 registry requirements orphaned from all twin nodes. Fixed truth: every
registry requirement has an explicit disposition (GEN8_REQUIREMENT_NODE_MAP.yaml) and ≥1 owner node in
the twin → orphans == []. Inversion: `XCTAssertEqual(orphans, [the 12 IDs])` →
`XCTAssertEqual(orphans, [], "A12-F2 FIXED: every registry requirement has an explicit twin owner (see GEN8_REQUIREMENT_NODE_MAP.yaml)")`;
test doc-comment flips to FIXED tense citing this manifest.

### I-2 · `testA12_06_RegistryCountMetaMismatch_FINDING`
Pinned defect: registry metadata `count: 35` while 36 entries exist; twin source note repeats 35.
Fixed truth: LIVING metadata corrected to 36 (historical artifacts untouched). Inversion:
`XCTAssertTrue(regText.contains("count: 35"))` → `XCTAssertTrue(regText.contains("count: 36"))` +
`XCTAssertFalse(regText.contains("count: 35"))`; any companion assertions in the test flip accordingly.

### I-3 · `testA12_08_FullReferenceCensus_ClassifiedAndResolved`
Pinned defect: broken == exactly the 3 refs (2 fabricated rollback tags + wrong P009D path); exact
census pinned for candidate 4d6649c (total 253; breakdown [71,7,8,22,8,29,2,16,90]; machine 163).
Fixed truth: broken == []; fabricated tag strings ABSENT from the twin; P009D implementation ref points
to the real artifact `docs/intelligence/P009D_POLICY_INTELLIGENCE.md`. Inversions: broken-set equality →
`XCTAssertEqual(broken, [], "A12-F3 FIXED")`; the two `XCTAssertFalse(fileExists/…P009D…))` /
`XCTAssertTrue(fileExists(real))` lines stay; the exact census totals are RE-DERIVED against the R1
candidate and re-pinned with the same partition law (classification logic byte-identical; only the
pinned numbers and the FIXED-tense comments change). The frozen original preserves the 4d6649c census.

### I-4 · `testA12_09_RollbackTagAnchors_TwoNeverExisted_FINDING`
Pinned defect: twin still carries the fabricated tag string on P009A (exact-equality pin). Fixed truth:
no fabricated tag claims anywhere in the twin; rollback truth is typed (`tag_status: NEVER_CREATED`,
tag empty; rollback-by-commit remains valid: 4ce238f / 42b96a2). Inversions: the git-level
`XCTAssertFalse(gitTagExists(fabricated))` lines STAY (we never create those tags retroactively); the
twin-level pin flips to assert the fabricated strings are ABSENT from the twin text and that
`rollback.tag_status == "NEVER_CREATED"` + non-empty `rollback.commit` on both nodes.

### I-5 · `testA12_16_ControlPlaneSelfGrade_PrecedesItsOwnAudit_FINDING`
Pinned defect: CP-CONTROL-PLANE privacy/security self-graded VERIFIED_WITH_LIMITATIONS while
audit.status == PENDING. Fixed truth: honest `LAB_ONLY` on both axes until the independent control-plane
audit supports stronger status. Inversions: the two VWL equality pins →
`XCTAssertEqual(truth["privacy"/"security"], "LAB_ONLY", "A12-F10 FIXED: no self-grade above lab truth before the node's own audit")`;
PENDING + overall-UNVERIFIED pins stay.

## Explicitly NOT inverted (must stay green against the fixed candidate)

A12_01 (status census — no node added/removed, no status changed), A12_02, A12_03 (blocked_by legacy
mirror kept byte-identical; new canonical `gated_by`/`dependency_contracts` fields are ADDITIVE),
A12_04, A12_07, A12_10–A12_15, A12_17–A12_36. A12_28's exact `depends_on` equalities bind R1: dependency
arrays are IMMUTABLE this round; typed semantics are expressed in the ADDITIVE `dependency_contracts`
field, never by rewriting `depends_on`.

## Verification hooks

`ControlPlaneR1RemediationTests` re-verifies from disk: frozen-original SHA byte-exact; active probe
file contains each declared FIXED assertion and none of the five retired pinned assertions; and each
fixed behavior holds at data/evaluator level independently of the probe file.
