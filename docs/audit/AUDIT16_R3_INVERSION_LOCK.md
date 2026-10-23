# AUDIT16 → R3 INVERSION LOCK (pre-declared BEFORE any R3 behavior commit)

Date: 2026-10-23 (pre-data; zero corpus/annotator/fit/heldout; NO PASS lock exists).
AUDIT16 verdict: FIX REQUIRED — RWC PREREGISTRATION R2 (commit a8c4ec8, target 8460f27).

## Frozen originals (AUDIT16 auditor evidence)

- `docs/audit/AUDIT16_RWCPre14R2ReauditProbes_ORIGINAL_LOCKED.swift.txt`
  SHA-256 `ed142d0716dfec976a0f31007cfa5f5882b9e334036e25f0c04ea045b49dde6d`
- `docs/audit/AUDIT16_StatReplicationRunner_ORIGINAL_LOCKED.swift.txt`
  SHA-256 `867a7ed3a9045468079cce0884d2af094786fa48b51c0159ce3bec0ffcf7bdfc`
- `docs/audit/AUDIT16_DerivationReproProbes_ORIGINAL_LOCKED.swift.txt`
  SHA-256 `52e11b35137d21c6e42bf84b2621e1db9dcd1e6ea5a7e30cfa8f4b3b6fdea1e9`

The ACTIVE AUDIT16 probe/runner files, the AUDIT16 report, audit16_tools and result JSONs are
auditor evidence: immutable except under an inversion declared HERE (or a later addendum committed
BEFORE the inverting commit).

## R3 strategy: SUPERSESSION NOT MUTATION — ZERO INVERSIONS DECLARED

All A16-F1..F23 root causes are closed in NEW canonical V3/V4 modules and artifacts:

- Rights: `RWCRightsV3.swift` — RWCDateV3 (invalid dates UNREPRESENTABLE: throwing make/parse only,
  no public memberwise init), floor-division UTC clock (A16-F2), RWCLegalGrantIdentityV1 +
  RWCVerifiedRightsGrantV1 (byte digest ≠ legal authority; review-boundary minting),
  RWCAssetRightsLedgerStoreV3 — DURABLE event-sourced authority (full state payload in events,
  openExisting replay, durable head witness, OS advisory single-writer lock, crash recovery).
- Calibration: `RWCCalibrationMethodologyV4.swift` — length-prefixed seed encoding (no '|' join),
  RWC evaluation-seed-manifest law (outcome-independent by schema), S selected by an ANALYTICAL
  precision law (the failed "mixed <= 1.5%" selection premise is RETIRED as negative history —
  A16-F23), sentinel counters remodeled (A16-F10), IRR canonical threshold RESTORED to 0.60
  (A16-F11; the v3 0.61 drift stays recorded as negative evidence).
- Power: `RWCPowerDerivationV4.swift` + V4 artifacts (re-derived pre-data; n=800 retained only if
  it still satisfies the frozen power law).
- Authority: machine audit-result schema + PASS-lock schema v2 + `RWCCorpusEntryVerifierV3` in a
  NEW non-test target (git-object truth: `git show <audit_commit>:<audit result path>`; candidate
  ancestry; every lock field verified; canonical freeze V4 path only; recursive no-prefix
  git-tree + live surface scan; symlink refusal; all five zero-data counters) +
  `RWCCorpusAcquisitionRunnerV1` (first-asset ordering law, quarantine, rights↔media transaction).
- Freeze V4: new anchor → new manifest (non-circular), v1/v2/v3 history preserved.

Consequences, declared pre-build:

1. Every file hashed by freeze v2 (25) and freeze v3 (68 inventory) and every AUDIT14/15/16-pinned
   file remains BYTE-UNTOUCHED. The v3 methodology anchor record and manifest V3 are history.
2. Every AUDIT16 probe that PINS defective V2/V3 behavior (RWCDateV2 memberwise init, store V2
   restart loss, verifier V2 forged-PASS/mini-manifest/scan bypasses, seed '|' aliasing,
   gates-v3 0.61 text, S=999 premise) KEEPS PASSING against the superseded surfaces and stands as
   PERMANENT NEGATIVE EVIDENCE.
3. Canonical authority moves BY RECORD (master manifest R3 keys + gates V4 + freeze V4) to the
   V3/V4 modules; superseded surfaces are SUPERSEDED_ENGINEERING_HISTORY, never a lawful
   real-world path.
4. ZERO inversions of AUDIT16 artifacts are declared or planned. If any R3 step requires touching
   an AUDIT16 file, a dated ADDENDUM (finding, old truth, new truth, affected probe, reason,
   expected delta) MUST be committed BEFORE the inverting commit.
5. `packages/GuardianKit/Package.swift` gains a NEW target for the non-test acquisition authority
   (A16-F22/§39). Package.swift is not pinned by any manifest/test (verified in R2 recon); it
   enters the governed V4 surface from this round on.
6. Builder-owned test files (R1/R2/prereg) are planned UNTOUCHED; master manifest is extended via
   NEW keys only (pinned fields/zero counters preserved). Exceptions, if any, go to the R3 change
   ledger with justification.

Carried negative evidence (unchanged): AUDIT14/15 frozen originals + inversion locks, F7/F8 MC
pins, gates/freeze v1+v2+v3, power_derivation.py, S=999 stability artifact (now FAILED-premise
history), AUDIT16 report + tools + results.
