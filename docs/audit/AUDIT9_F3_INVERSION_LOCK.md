# AUDIT9 F3 INVERSION LOCK — dedicated migration record (A10-A9-DISCIPLINE closeout)

**Status:** IMMUTABLE MIGRATION RECORD (append errata only — never rewrite).
**Created:** 2026-10-20, R1 fix round, branch `phase/real-world-calibration` (start HEAD `6f1cff7`).
**Purpose:** AUDIT10 ruled the AUDIT9 probe mutation *NOT a mandate violation* but found the inversion
discipline incomplete: every prior auditor-probe inversion (AUDIT3/5/7/8) had a dedicated lock-doc
manifest; the AUDIT9 inversion had only the constitution pre-declaration plus an in-file pointer to a
non-existent artefact. This record closes finding **A10-A9-DISCIPLINE (LOW)** retroactively and
canonically — without touching any historical evidence file.

## 1. The migration, exactly

| Field | Value |
|---|---|
| Finding that forced the inversion | **A9-R1-F3** (AUDIT9: out-of-range probabilities were silently CLAMPED into the ECE denominator — INFO pin in the original audit) |
| Original audit | `docs/audit/` AUDIT9 report, committed `0150d06` (verdict PASS — P009E-R1 ENGINEERING LOCKED) |
| Original probe file (frozen) | `docs/audit/AUDIT9_P009ER1Probes_ORIGINAL_LOCKED.swift.txt` |
| Frozen original SHA-256 | `a349a487dc091d444f04939864582175409542f47d6275c6bb0bd8022163bc4e` (byte-exact == the file at `0150d06`/`b08406c`; re-verified by AUDIT10 P17 from disk) |
| Original assertion (the ONLY inverted expectation) | `XCTAssertEqual(oor.bins.map { $0.count }.reduce(0, +), 2, "out-of-range values are clamped, never silently dropped")` on `eceAndBins(preds: [-0.2, 1.3], …)` |
| Changed active assertion | `XCTAssertTrue(oor.ece.isNaN && oor.bins.isEmpty, "A9-R1-F3 FIXED: no silent clamp into the metric")` |
| Mutation shape | single hunk, −2/+4 lines, net +2 (pinned executable by AUDIT10 `testP17_AUDIT9FrozenCopy_ByteExact_SingleHunk`) |
| Candidate SHA where the inversion occurred | `6510079` (entry-gate F3 commit), first audited at candidate `28865c3` |
| Pre-declaration source | `docs/calibration/REAL_WORLD_CALIBRATION_CONSTITUTION_v1.md` (commit `b08406c`, **before** the code change), F3 execution plan: "typed invalid-input REJECT … never silently clamped … no silent clamp" |

## 2. Why the behavior inversion is legitimate

The original AUDIT9 probe *characterized a defect* (silent clamp) as then-current truth. The entry-gate
mandate (A9-R1-F3) ordered exactly that defect fixed: invalid domain must be REFUSED, never clamped.
A fixed system cannot satisfy a probe that asserts the defect; the probe expectation — and only that
one expectation — was inverted to assert the FIXED behavior. Every other original F3 expectation still
holds against the candidate (executable proof: AUDIT10 `testP16_AUDIT9Original_vs_Candidate_DeltaRecorded`
runs the ORIGINAL expectations and records the single delta). This is the same frozen-original +
pinned-finding migration applied at AUDIT3/5/7/8 (e.g. `464c79d` locked before fix; `38280f8`
froze+inverted atomically).

## 3. No deletion / no rewrite proof

- The historical AUDIT9 report (`0150d06`) is unmodified — verified by immutable git history (no
  amend/rebase/force anywhere on the chain; remote refs match local).
- The frozen original is byte-exact (SHA above), asserted from disk on every suite run (AUDIT10 P17).
- The active file differs from the frozen original by exactly the declared single hunk (AUDIT10 P17
  asserts removed==2, added==4, net +2, both removed lines in the clamp block).

## 4. Dangling-pointer remap (the A10-A9-DISCIPLINE gap (b))

The in-file comment in `AUDIT9_P009ER1Probes.swift` cites "docs/calibration/ENTRY_GATE lock notes" —
an artefact that did not exist at candidate `28865c3`. That comment line sits inside the AUDIT10-P17
pinned hunk and **must not be edited** (editing it would mutate audit evidence a second time). The
pointer is resolved instead by creating the referenced artefact:
`docs/calibration/ENTRY_GATE_LOCK_NOTES.md` → redirects to **this** canonical lock record and to the
ENTRY GATE section of `REAL_WORLD_CALIBRATION_CONSTITUTION_v1.md` (the actual pre-declaration).
Gap (c) — the `b08406c` commit message implying separate execution-plan docs — is recorded here as a
TRUE historical imprecision: the execution plans live INSIDE the constitution document, not as
separate files. Commit messages are immutable; this record is the correction.
Gap (d) — the legacy-path NaN-marker split (vs the pre-declared "typed REJECT") first appeared in the
fix commit `6510079`: the typed-REJECT strict API is the pre-declared contract; the NaN marker is a
compatibility refusal marker on the legacy signature, judged CLOSED_WITH_LIMITATION by AUDIT10.

## 5. Rollback / reference

- Rollback reference: tag `gen8-p009e-r1-locked-engineering-only` (`f991aba`) — pre-entry-gate state.
- Auditor requirement satisfied: AUDIT10 required fix item (4) — "AUDIT9 inversion manifest lock doc +
  fix the dangling pointer".
- Related: `docs/audit/AUDIT9_FPEDGE_ERRATUM.md` (false fp-edge claim inside the same probe file —
  corrected by erratum because the file is P17-pinned).
