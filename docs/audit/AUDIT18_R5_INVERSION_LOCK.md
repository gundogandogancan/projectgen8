# AUDIT18 → R5 INVERSION LOCK (pre-declared BEFORE any R5 behavior commit)

Date: 2026-10-23 (pre-data; zero corpus/annotator/fit/heldout; NO PASS lock; NO R5 audit result;
NO production reviewer trust root — and NONE will be invented in R5).
AUDIT18 verdict: FIX REQUIRED — RWC PREREGISTRATION R4 (commit ac91974, target 2067830; machine
result RWC_PRE14_R4_AUDIT_RESULT.json = FIX_REQUIRED, 0 CRITICAL / 2 HIGH / 2 MEDIUM, 1029+32=1061).

## Frozen originals (AUDIT18 auditor evidence — immutable)

- `AUDIT18_RWCPre14R4ReauditProbes_ORIGINAL_LOCKED.swift.txt`
  `08f396c445ca68abfef6706a98b17b16192ccde617ce457ee5f3a50d676eaf12`
- `AUDIT18_RightsAuthorityProbes_ORIGINAL_LOCKED.swift.txt`
  `962384897f5a0fdb3ccf412be1228a0ebd7c2d25589b23b1c26678d2e02d87a5`
- `AUDIT18_VerifierFreezeProbes_ORIGINAL_LOCKED.swift.txt`
  `dcb9881efb8e696fd86a136966b0d91d47c541b806ae73f7c3320cccb8ea8630`
- `AUDIT18_AcquisitionRunnerProbes_ORIGINAL_LOCKED.swift.txt`
  `6ae90e648d480d0c0c9fe32e7454031d74ce251eb76fce0ceb1c62630f09c1a7`
- `RWC_PRE14_R4_AUDIT_RESULT_ORIGINAL_LOCKED.json`
  `47358f2a1675b5fec8e8348cbf868d09a5bc60852e68a70ff7f32e9e4e768820`
- `GEN8_RWC_PREREGISTRATION_PRE14_R4_INDEPENDENT_REAUDIT_ORIGINAL_LOCKED.md`
  `73fe0f70f946e3a10030bb39960e926ddda3b2894ca3a03f0bb4c29f1755d84e`

The ACTIVE AUDIT18 files (4 probes, machine result, report, audit18_tools) are auditor evidence:
immutable except under an inversion declared HERE (or a dated addendum committed BEFORE the
inverting commit). The R4 machine result remains FIX_REQUIRED 0/2/2 forever; the R5 result will
live at the NEW canonical path `docs/audit/RWC_PRE14_R5_AUDIT_RESULT.json` and is created ONLY by
AUDIT19. The LIVE freeze V5 manifest is pinned byte-identical to the R4 candidate blob by an
AUDIT18 probe — R5 therefore NEVER touches the V5 manifest (V6 is a NEW file).

## R5 strategy: SUPERSESSION NOT MUTATION — ZERO AUDIT18 INVERSIONS DECLARED

All A18-F1/F2/F3/F5 (+F4/F6/F10 LOW) root causes close in NEW surfaces (mandate §7/§26/§36/§49/§75):
reviewer TRUST-ROOT architecture (root schema/law + root-signed immutable registry documents +
verified-registry proof + review authority V3 + verified grant V3 — SIGNATURE AUTHENTICITY ≠ TRUST
AUTHORITY; no caller-supplied registry on the lawful path; NO production root invented —
fail-closed + RWC-REVIEWER-ROOT-ONBOARDING blocker), scope enforcement, durable acquisition
receipt store (PREPARED→PROMOTION_CONFIRMED→COMPLETED; survives post-promote crash) + runner V3,
verifier V5 (candidate-commit FREEZE BLOB binding via git show; tag-name cross-check; audit result
schema V3; PASS-lock schema V4), source-manifest duplicate/empty canonicality, gates V6, freeze V6
(new anchor → manifest; candidate tree MUST contain the manifest; tag after manifest). V2 review
authority, runner V2, verifier V4 and gates V5 stay byte-frozen SUPERSEDED_ENGINEERING_HISTORY
(A18 pins keep passing). Calibration V4 and durable store V3 are CARRIED CLEAN (regression only).

## EXACTLY ONE HISTORICAL R4 BUILDER-FILE SUPERSESSION (pre-declared; mandate §3)

File: `packages/GuardianKit/Tests/GuardianCoreTests/RWCPreregistrationR4Tests.swift`
(builder-owned R4 evidence; listed in the freeze-V5 inventory; verified: NO other test or AUDIT18
probe hashes/pins this file — the only coupled assertion lives INSIDE the same file).

Declared changes (applied only in the later R5 test commit, strictly AFTER this declaration):

1. `testR4_ZeroData_PhaseTruths_DocsPins_ProductionLocks` (~line 678)
   - OLD R4 truth: `docs/audit/RWC_PRE14_R4_AUDIT_RESULT.json` does NOT exist.
   - NEW lawful post-AUDIT18 truth: the file EXISTS, parses under schema V2, binds candidate
     `206783074e2167afa0689aa7873a917076089749`, verdict `FIX_REQUIRED`, critical 0, high 2,
     medium 2 — and its ABSENCE in the R4 candidate tree is git-verified. Never asserted as PASS.
   - Reason: AUDIT18's mandate (§61) required creating the machine result; the absence-pin is
     obsolete phase truth (identical pattern to the R3→R4 transition).
2. `testR4_FreezeV5_AnchorConsistency_HashCensus` (same file)
   - OLD: live-hash census of V5 artifacts + `git diff anchorV5..HEAD` per path.
   - NEW: identical census pinned to the R4 CANDIDATE commit (`git show 2067830:<path>` blobs +
     `git diff anchorV5..2067830`) — historical V5 truth, immune to lawful post-V5 rounds;
     freeze V6 owns the live census.
   - Reason: unavoidable physical consequence of change 1 (the file is itself a hashed V5
     artifact). Expected semantic delta for V5 history: none.

No other builder/auditor file changes semantics. Any additional need requires a dated ADDENDUM
committed BEFORE the inverting commit.

## Execution model (mandate preamble + §84)

OPUS is the R5 main contractor; FABLE performs the pre-anchor delta review (root-of-trust bypass,
scope bypass, caller-injection leakage, manifest candidate-binding, receipt crash windows,
recovery idempotence, test/production access-control separation) and authors this lock and the
final mechanics. Neither can declare PRE-14 PASS.

## Baseline truth (mandate §1, measured pre-change)

Recorded after the suite run completes: expected exactly ONE lawful phase-transition failure
(the obsolete R4 absence-pin at RWCPreregistrationR4Tests.swift:678). Any other failure stops R5.

## Carried negative evidence (unchanged)

AUDIT14..17 frozen originals + locks + reports + machine results, gates/freeze v1..v5, all
superseded surfaces, AUDIT18 report + result + tools: immutable history.

## ADDENDUM 1 (2026-10-23, committed BEFORE the inverting commit) — ONE DECLARED AUDIT18 PROBE INVERSION

Discovered at final R5 verification (suite x2): AUDIT18 probe
`AUDIT18_VerifierFreezeProbes.test_A18_46_AuditCommit_AddOnly_RealRepo_NoPassLock` (lines 404-413)
guards topology as `git diff <candidate>..HEAD` must contain ONLY auditor surfaces. TRUE at audit
time (HEAD == the AUDIT18 commit) and at the R5 baseline; STRUCTURALLY UNABLE to survive any lawful
later round (the 16 final-suite failures are exactly the 9 lawful R5 commits' non-audit paths).
This is the AUDIT-probe variant of the recurring phase-transition pattern (R3/R4 absence-pins).

INVERSION I-1 (pre-declared):
- File: packages/GuardianKit/Tests/GuardianCoreTests/AUDIT18_VerifierFreezeProbes.swift
- Old truth: every path in `diff <candidate>..HEAD` is auditor surface.
- New truth (semantic PRESERVED, target frozen): every path in
  `diff <candidate>..ac91974ddba3289031efe1df075185178259472b` (the immutable AUDIT18 commit) is
  auditor surface — i.e., THE AUDIT18 COMMIT WAS ADD-ONLY, pinned forever.
- Expected delta: none for the audited fact; the guard merely stops floating with HEAD.
- The frozen original (`dcb9881e…`) remains byte-preserved; the lock-missing assertion and all
  other content in the file are untouched.

CONSEQUENCE EDITS (same declaration):
- RWCPreregistrationR5Tests discipline test: the byte-identity expectation for THIS ONE file
  becomes: active != original (declared inversion I-1), active contains the frozen-commit-anchored
  guard, original locked copy intact; the other 3 AUDIT18 probe files remain byte-identical.
- Because both files are V6-frozen, the R5 anchor is REPLACED by a NEW METHODOLOGY ANCHOR and
  freeze manifest V6 is REGENERATED at it (lawful: pre-candidate, pre-AUDIT19 — the invalidation
  law's own procedure; the superseded anchor/manifest commits remain plain history).
