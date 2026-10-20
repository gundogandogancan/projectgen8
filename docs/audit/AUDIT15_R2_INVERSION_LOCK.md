# AUDIT15 → R2 INVERSION LOCK (pre-declared BEFORE any R2 behavior commit)

Date: 2026-10-21 (pre-data; zero corpus/annotator/fit/heldout).
AUDIT15 verdict: FIX REQUIRED — RWC PREREGISTRATION R1 (commit 9252d7a, target 931f38e).

## Frozen original

`docs/audit/AUDIT15_RWCPre14R1ReauditProbes_ORIGINAL_LOCKED.swift.txt`
SHA-256: `a68a8d5013f3fa51c7b41972fb3b38bc9b73be2c9aaf1411b2cfa3c80bd9fc4d`

The ACTIVE AUDIT15 probe file (`packages/GuardianKit/Tests/GuardianCoreTests/AUDIT15_RWCPre14R1ReauditProbes.swift`)
is auditor evidence. It may not be modified except under an inversion declared in THIS manifest (or a
later addendum committed BEFORE the inverting commit).

## R2 remediation strategy: SUPERSESSION, NOT MUTATION — ZERO INVERSIONS DECLARED

All A15-F1..F12 root causes are closed in NEW canonical modules/artifacts:

- Rights truth: `RWCRightsV2.swift` (RWCDateV2 real-Gregorian civil date, RWCRightsClockV1 clock
  authority, RWCRightsEvidenceIdentityV1 digest-based evidence identity, RWCAssetRightsLedgerStoreV2
  chronology-lawful store, SHA-256 canonical event chain, RWCAssetRightsJournalV1 durable journal).
- Calibration methodology: `RWCCalibrationMethodologyV3.swift` (typed input domain, tie-invariant
  binning law, exact Monte-Carlo p-value rule, SHA-256 cross-language seed law, honest statistic
  naming, CoverageV2 typed counters) + `RWCPowerDerivationV3.swift` + v3 power/stability artifacts.
- Freeze: `RWC_PREREGISTRATION_FREEZE_MANIFEST_V3.yaml` (two-phase: METHODOLOGY ANCHOR COMMIT →
  manifest commit; non-circular) + full surface inventory.
- Corpus entry: PRE14 PASS-LOCK schema + `RWCCorpusEntryVerifierV2` (repository-truth verifier;
  type-minted VerifiedEntry; no caller-string authority). NO PASS LOCK is created in R2.
- Gates/slices/power prereg: NEW `_V3` files superseding v2 BY RECORD; the v2 files remain
  byte-preserved FAILED-candidate history.

Consequences, declared pre-build:

1. The 25 freeze-v2 artifacts, the v2 manifest, the v1 manifest, gates v2, and every file hashed or
   substring-pinned by AUDIT14/AUDIT15/R1 suites remain BYTE-UNTOUCHED.
2. Every AUDIT15 probe that PINS defective V1 behavior (A15-F1 impossible dates, F2 chronology,
   F3 pointer-rename, F4 Hasher chain, F5/F9/F11 methodology-V1 defects, F6 coverage counters,
   F12 guard caller-trust, F13 register-use hardcode, F16 expired/time-travel, F18 dashes-only
   pointer, F8 freeze_candidate_commit string, tag-object absence in v2 manifest) KEEPS PASSING
   against the superseded V1 surfaces and stands as PERMANENT NEGATIVE EVIDENCE of the R1 design,
   exactly like the AUDIT14 F7/F8 Monte-Carlo pins.
3. Canonical authority is MOVED by record: master manifest R2 fields + gates v3 + rights law v2 +
   freeze v3 declare the V2/V3 modules canonical and the V1 surfaces
   SUPERSEDED_ENGINEERING_HISTORY (never a lawful real-world path).
4. Therefore ZERO inversions of AUDIT15 probes are declared or planned. If ANY later R2 step turns
   out to require modifying the AUDIT15 probe file, a dated ADDENDUM to this manifest (finding, old
   truth, new intended truth, affected probe, reason, expected semantic delta) MUST be committed
   BEFORE the inverting commit. Absent such an addendum, any AUDIT15 probe edit is an audit
   violation.

## Builder-owned (non-auditor) test files

`RWCPreregistrationR1Tests.swift` / `RWCPreregistrationTests.swift` are BUILDER tests, not auditor
evidence; the same caution applies in spirit: R2 plans NO edits to them (master manifest R2 state is
added via NEW keys so the pinned `candidate_generation == "R1"`, zero counters and substrings stay
true). Any exception will be listed in the R2 change ledger with justification.

## Carried negative evidence (unchanged)

AUDIT14 frozen original 18ac2633…, AUDIT14 R1 inversion manifest I-1..I-16, AUDIT14 F7/F8 MC pins,
gates/freeze v1+v2 artifacts, AUDIT15 report + audit15_tools results: all immutable history.
