# ENTRY_GATE lock notes — pointer resolution artefact

The in-file comment in `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT9_P009ER1Probes.swift`
(inside the A9-R1-F3 inversion hunk) cites "docs/calibration/ENTRY_GATE lock notes". At candidate
`28865c3` no such artefact existed — AUDIT10 pinned this as the dangling reference in finding
**A10-A9-DISCIPLINE (LOW)**. The comment line itself is inside the AUDIT10-P17 pinned single-hunk
region and is therefore immutable audit evidence.

This file resolves the pointer. The canonical artefacts are:

1. **`docs/audit/AUDIT9_F3_INVERSION_LOCK.md`** — the dedicated AUDIT9 F3 inversion migration record
   (original SHA, original assertion, changed assertion, legitimacy, no-rewrite proof, rollback).
2. **`docs/calibration/REAL_WORLD_CALIBRATION_CONSTITUTION_v1.md`**, ENTRY GATE section (A9-R1-F3
   execution plan) — the pre-declaration committed at `b08406c`, BEFORE the code change.
3. **`docs/audit/AUDIT9_FPEDGE_ERRATUM.md`** — correction record for the false fp-edge claim carried
   by the same probe file and historical reports.
