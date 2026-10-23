# AUDIT17 → R4 INVERSION LOCK (pre-declared BEFORE any R4 behavior commit)

Date: 2026-10-23 (pre-data; zero corpus/annotator/fit/heldout; NO PASS lock; NO R4 audit result).
AUDIT17 verdict: FIX REQUIRED — RWC PREREGISTRATION R3 (commit f87c7fe, target 17418d4;
machine result docs/audit/RWC_PRE14_R3_AUDIT_RESULT.json = FIX_REQUIRED, 0 CRITICAL / 5 HIGH /
5 MEDIUM, 982+38=1020).

## Frozen originals (AUDIT17 auditor evidence — immutable)

- `AUDIT17_RWCPre14R3ReauditProbes_ORIGINAL_LOCKED.swift.txt`
  `b423adcd1146ffa9bf685d9f016a7e003c1d2b30318f19e9d15aff6ea0301bef`
- `AUDIT17_VerifierAuthorityProbes_ORIGINAL_LOCKED.swift.txt`
  `901e1f762f81700cd8bd0d630b613ed1d8074e3cde2a667f1229c80493a432c1`
- `AUDIT17_AcquisitionRunnerProbes_ORIGINAL_LOCKED.swift.txt`
  `cc06649629dac53e2edd7cb7c2c810d4c936830c44b737f1777649a21511bb1a`
- `RWC_PRE14_R3_AUDIT_RESULT_ORIGINAL_LOCKED.json`
  `2ebd7f8f608946701197df772f3454bffeb934157c3d46e484fffaef2b821061`
- `GEN8_RWC_PREREGISTRATION_PRE14_R3_INDEPENDENT_REAUDIT_ORIGINAL_LOCKED.md`
  `7debbfc53ee40696642c68cd96f76b177cc5bfbced7c61df2ac543aced64829a`

The ACTIVE AUDIT17 files (3 probes, machine result, report, audit17_tools) are auditor evidence:
immutable except under an inversion declared HERE (or a later addendum committed BEFORE the
inverting commit). The R3 machine result REMAINS FIX_REQUIRED forever (R4 mandate §44); the R4
audit result will live at a NEW canonical path and is created ONLY by AUDIT18.

## R4 strategy: SUPERSESSION NOT MUTATION — ZERO AUDIT17 INVERSIONS DECLARED

All A17-F1..F12 root causes close in NEW surfaces: `RWCRightsV4.swift` (review authority V2:
Ed25519-signed reviews + authorized reviewer registry; source authorization; preauthorization
evaluator; session-ID law; single transaction date), `RWCCorpusAcquisitionRunnerV2.swift`
(pre-fetch full validation, hash-after-fetch, session reservation/state machine, identity-bound
reconciliation V2), `RWCCorpusEntryVerifierV4.swift` (canonical audit-result V2 path; path-scoped
post-audit allowances; count-law schema V2), schemas V2/V3, gates V5, freeze V5 (new anchor →
manifest). V3/V4 surfaces (incl. the caller-forgeable `RWCRightsReviewAuthorityV1.verify` — the
A17-F1 pin) stay byte-frozen SUPERSEDED_ENGINEERING_HISTORY and permanent negative evidence.
AUDIT17 defect-pinning probes KEEP PASSING against those superseded surfaces.

## EXACTLY ONE HISTORICAL BUILDER-FILE SUPERSESSION (pre-declared; R4 mandate §3/§75)

File: `packages/GuardianKit/Tests/GuardianCoreTests/RWCPreregistrationR3Tests.swift`
(builder-owned R3 evidence; listed in freeze-V4 inventory; recon verified NO other test hashes or
pins this file — the only coupled assertions live INSIDE this same file).

Declared changes (applied in the R4 test commit, strictly AFTER this declaration lands):

1. `testR3_DocsV4Pins_ZeroData_ProductionLocks` (lines ~839-841)
   - OLD R3 truth: `docs/audit/RWC_PRE14_R3_AUDIT_RESULT.json` does NOT exist.
   - NEW lawful post-AUDIT17 truth: the file EXISTS, parses under schema V1, and binds EXACTLY:
     result_version `rwc-pre14-audit-result-v1`, candidate `17418d4736f94f7b098b1018d44d1f391c7ea21c`,
     verdict `FIX_REQUIRED`, critical 0, high 5, medium 5. It must NEVER be asserted as PASS.
   - Reason: AUDIT17's mandate (§54) REQUIRED creating the machine result; the absence-pin is
     obsolete phase truth, not evidence tampering. R3 candidate history remains reconstructable
     (the file is absent in the 17418d4 tree — git-verifiable).
2. `testR3_FreezeV4_AnchorConsistency_HashCensus` (same file)
   - OLD mechanics: hashes every freeze-V4 artifact against the LIVE filesystem and requires
     `git diff anchorV4..HEAD` empty per path.
   - NEW lawful mechanics: identical census verified against the V4 CANDIDATE COMMIT's git tree
     (`git show 17418d4:<path>` blobs) and `git diff anchorV4..17418d4` — the historical V4 freeze
     truth, pinned forever and immune to lawful post-V4 rounds.
   - Reason: unavoidable physical consequence of change 1 — this file is itself a hashed V4
     artifact, so ANY byte edit breaks its own live census; freeze V5 (new anchor) becomes the
     live-census authority, exactly as V3→V4 superseded earlier censuses. Expected semantic delta:
     none for V4 history (same hashes, same anchor law, now candidate-pinned).

No OTHER builder/auditor file changes its semantics. Any additional need requires a dated ADDENDUM
committed BEFORE the inverting commit.

## Baseline truth (R4 mandate §1, measured pre-change)

Post-AUDIT17 suite: `Executed 1020 tests, 1 failure, 11 skipped` — the single failure is exactly
the obsolete absence-pin above (testR3_DocsV4Pins, RWCPreregistrationR3Tests.swift:840). No
unrelated failure exists. This is EXPECTED historical transition, not a product defect.

## Carried negative evidence (unchanged)

AUDIT14/15/16 frozen originals + locks + reports, gates/freeze v1..v4, superseded methodology and
rights surfaces, S=999 stability artifact, AUDIT17 report + machine result + tools: all immutable.
