# CONTROL PLANE R1 — REFERENCE CORRECTIONS (A12-F3 closure record)

**Law:** honest correction record — NO history rewrite, NO retroactive tag creation. The historical
candidate `4d6649c` remains wrong by design and auditable (AUDIT12 frozen probes + frozen original
`4671898b…` preserve the defective census exactly).

## Correction 1 — P009A fabricated rollback tag

- **Incorrect canonical claim (at 4d6649c):** `P009A-IDENTITY-FOUNDATION.rollback.tag = "gen8-p009a-identity-foundation-locked-phase-c-ok"`
- **Why wrong:** that tag exists NOWHERE in git and in no other repo document. I (the builder) wrote a
  plausible-sounding tag name into the twin without verifying it against `git tag -l` — invented
  history, FM-003 class. AUDIT12 finding A12-F3 (probe `testA12_09`).
- **Actual git evidence:** the P009A lock anchor is commit `4ce238f` (AUDIT2 PASS); no lock tag was
  ever created for P009A.
- **Corrected representation:** `rollback: { commit: "4ce238f", tag: "", tag_status: "NEVER_CREATED", evidence: … }` —
  rollback-by-verified-commit remains fully legitimate.

## Correction 2 — P009B fabricated rollback tag

- **Incorrect claim:** `P009B-EXPERT-MESH.rollback.tag = "gen8-p009b-expert-mesh-r1-reaudit-pass"` —
  same root cause (unverified invented tag name; A12-F3).
- **Actual git evidence:** lock anchor is commit `42b96a2` (AUDIT4 PASS); no P009B lock tag exists.
- **Corrected representation:** `tag_status: "NEVER_CREATED"`, commit anchor retained.

## Correction 3 — P009D implementation evidence path

- **Incorrect claim:** `docs/implementation/P009D_IMPLEMENTATION_EVIDENCE.md` (file does not exist).
- **Independent verification:** `docs/implementation/` contains NO P009D artifact; the single P009D
  evidence artifact in the repo is `docs/intelligence/P009D_POLICY_INTELLIGENCE.md` (title line:
  "P009D — Safety + Child Age + Personal Shield Policy Intelligence"). No competing P009D artifacts
  found (filename-resemblance was not the only criterion; directory sweeps of docs/implementation and
  docs/intelligence were used).
- **Corrected representation:** implementation ref now points to the real artifact.

## Root cause and structural fix

The builder validator (CP07 at 4d6649c) hard-checked only 5 selected paths — "broken refs = 0" was an
overclaim. R1 adds full machine-reference resolution to the suite (ControlPlaneValidationTests CP10:
every FILE/DIR/TAG/COMMIT/LEDGER-ANCHOR/AUDIT-ALIAS/TEST-SYMBOL machine ref must resolve; no hardcoded
shortcut), a typed rollback model (`tag_status: EXISTS | NEVER_CREATED | NOT_APPLICABLE`), and a
deterministic audit-alias registry (`GEN8_AUDIT_ALIAS_REGISTRY.yaml`).

Post-fix census (classifier identical to AUDIT12's): total 251 · machine-resolvable 161 · semantic 90 ·
**broken 0** · ambiguous 0 · orphan 0. (Historical candidate baseline: 253/163/90/3 — preserved in the
frozen AUDIT12 original.)
