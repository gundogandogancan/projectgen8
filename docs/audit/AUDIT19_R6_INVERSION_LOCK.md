# AUDIT19 → R6 INVERSION / SUPERSESSION LOCK (pre-declared BEFORE any inverting commit)

Date: 2026-10-24 (pre-data; zero corpus/annotator/fit/heldout; NO PASS lock; NO operational reviewer
trust root — and NONE is invented in R6).

AUDIT19 verdict (immutable history): **FIX REQUIRED — RWC PREREGISTRATION R5** — 1 CRITICAL / 2 HIGH
/ 2 MEDIUM. Candidate `f30b39322500da6e9e8602645e287cd41a61018e`; annotated tag object
`e599cc909a910d1bf7a96798ecd268f26e5facfa` → candidate; methodology anchor
`31267a4e34e6639fcca0448694425dfabfc025a2`; machine result
`docs/audit/RWC_PRE14_R5_AUDIT_RESULT.json` = FIX_REQUIRED 1/2/2 (schema V3), 1072+45=1117.

This lock is COMMITTED FIRST by the main session. Any semantic change to a frozen/auditor file that
is NOT declared here is rejected. The main session may amend this lock before committing.

## R6 strategy: SUPERSESSION NOT MUTATION

All five findings close in NEW versioned surfaces. The R5 surfaces stay BYTE-FROZEN
SUPERSEDED_ENGINEERING_HISTORY so the R5 builder tests keep passing and R5 behavior stays
reproducible from the candidate. NEW surfaces (all new files — zero mutation of frozen sources):

- `packages/GuardianKit/Sources/GuardianCore/RWCRightsV6.swift` — A19-F2 trust-root loader V2
  (NO public mint; capability-gated; fail-closed) + A19-F3 governed current-registry head witness
  (`RWCReviewerRegistryCurrentnessStoreV1`) + registry verifier V2 (`verifyCurrent`) + review
  authority V6 → verified grant V6 + pre-acquisition evaluator/authorization V3.
- `packages/GuardianKit/Sources/GuardianCore/RWCRightsV6Store.swift` — A19-F1 ledger store V4:
  `register` requires the unforgeable `RWCVerifiedRightsGrantV6` (the forged V1 token can no longer
  register) + unforgeable, ledger-resident `RWCAcquisitionAuthorizationRecordV1` written by
  `authorizeAcquisition` (requires the V6 grant).
- `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV4.swift` — A19-F1
  `acquire` (writes the authorization marker) + `reconcileV4` (promotes ONLY sessions backed by a
  ledger-resident authorization record; caller metadata/receipts are inert).
- `packages/GuardianKit/Sources/RWCAcquisition/RWCAcquisitionReceiptStoreV2.swift` — A19-F4 strict
  scalar validation + authority-bound `prepare` (copies authority from the authorization record) +
  A19-F5 strict typed `intendedUse` parse.
- `packages/GuardianKit/Tests/GuardianCoreTests/RWCPreregistrationR6Tests.swift` — fresh R6 builder
  family (lawful acquire + all crash windows + F1–F5 refusals; AUDIT-prefixed, post-audit allowance).
- `docs/calibration/preregistration/RWC_FROZEN_GATES_V7.yaml`,
  `docs/calibration/preregistration/tools/generate_freeze_manifest_v7.py`,
  `docs/calibration/preregistration/RWC_PREREGISTRATION_R6_SECURITY_DESIGN.md`,
  `docs/calibration/preregistration/RWC_PREREGISTRATION_R6_CHANGE_LEDGER.md`,
  `docs/audit/audit19_tools/a19consumer_r6/` (F2 ordinary-consumer package) — all NEW files.

R5 surfaces that stay byte-frozen SUPERSEDED_ENGINEERING_HISTORY (no edits): RWCRightsV5.swift
(loader V1, registry verifier V1, authority V3), RWCRightsV3.swift (ledger store V3, V1 no-crypto
token), RWCAcquisitionReceiptStoreV1.swift, RWCCorpusAcquisitionRunnerV3.swift,
RWCCorpusEntryVerifierV5.swift (the V5 PASS proof is sound and is reused by RunnerV4).

## Frozen originals (byte-preserved BEFORE the inverting edits)

- `AUDIT19_RWCPre14R5ReauditProbes_ORIGINAL_LOCKED.swift.txt`
  `b5232e524f659b2f51f2c7e46efb35b69760ef016bd4baff2cf9aee5a0ea8a51`
- `RWCPreregistrationR5Tests_ORIGINAL_LOCKED.swift.txt`
  `be8db856a0ec42192f2a11512b6ed5fa077217bcc2f0915e4d661956a8590fbb`

Post-edit SHAs (informational; the main session will re-verify after committing):
- active `AUDIT19_RWCPre14R5ReauditProbes.swift`
  `53eb8e13808aed5664c242cda36e4203345bf00a64245369246961ae6f21dbd9`
- active `RWCPreregistrationR5Tests.swift`
  `cea198198430916f9d40f647b80611bde7fff2bbb106b6bd9b1dd2d11e0e3e1d`

## DECLARED EDITS TO EXISTING AUDITOR / BUILDER FILES (the ONLY two)

### A. `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT19_RWCPre14R5ReauditProbes.swift` (AUDITOR)

The AUDIT19 independent probe family. Thirteen functions change (one re-anchor + twelve
finding-evidence inversions). Every other probe is byte-unchanged. R5-era probe behavior is
reproducible from the AUDIT19 audit commit (NOT the candidate — this auditor file was CREATED by
AUDIT19): `git show 48f91565f494f7125e9c4947369443fb5b0fc8f6:packages/GuardianKit/Tests/GuardianCoreTests/AUDIT19_RWCPre14R5ReauditProbes.swift`
(blob SHA-256 b5232e52…, byte-identical to the frozen original above — main-session verified). Shared R6 fixture helpers (`syntheticRootV2`, `signedRegistryDocV2`,
`lawfulChainV6`, `verifiedGrantV6`) were ADDED (additive).

| probe | finding | OLD truth (R5, frozen) | NEW truth (R6) |
|---|---|---|---|
| test_A19_01 | custody | HEAD == candidate f30b3932 | candidate is an ANCESTOR of the R6 HEAD; tag still dereferences to candidate; anchor still ancestor of candidate (re-anchored off floating HEAD — identical pattern to I-1) |
| test_A19_07 | A19-F2 | public `RWCReviewerTrustRootLoaderV1.mint(fromJSON:)` self-mints a verified root + full chain | `RWCReviewerTrustRootLoaderV2` exposes NO public mint; `loadProduction` throws `.noOperationalRoot`; lawful synthetic V6 chain mints a rooted grant |
| test_A19_08 | A19-F2 | attacker `repoRoot` yields a verified production root | `loaderV2.loadProduction(attackerDir)` throws `.noOperationalRoot` (path != trust) |
| test_A19_11 | A19-F3 | replayed rev1 re-verifies ACTIVE (revoked resurrection) | `verifyCurrent` refuses the replayed rev1 vs the current head (typed refusal) |
| test_A19_12 | A19-F3 | rev5 + arbitrary prev digest verifies with previous=nil | `verifyCurrent` refuses `.revisionWithoutAncestry(5)` |
| test_A19_14 | A19-F3 | rotated-out old rev1 still verifies standalone | `verifyCurrent` refuses the rotated-out rev1 vs the current head |
| test_A19_17 | A19-F3 | old-registry replay re-mints a grant from a pre-revocation review | replayed old registry refused → no verified-current registry → grant cannot be minted |
| test_A19_20 | A19-F1 | forged V1 token → register → public metadata + receipt → `reconcileV3` PROMOTES (promote==true) | forged V1 token cannot register into store V4; `reconcileV4` promotes nothing (no ledger authorization) → promote==false, corpus empty, session destroyed-unauthorized |
| test_A19_21 | A19-F4 | receipt `prepare` accepts arbitrary caller authority strings | receipt V2 `prepare` requires the unforgeable ledger authorization record; authority copied from it; bad ledger head → `.malformedScalar` |
| test_A19_22 | A19-F1 | manufactured RIGHTS_COMMITTED metadata is trusted by reconcile | metadata is inert under `reconcileV4` (drives off the ledger authorization only) |
| test_A19_23 | A19-F5 | garbage `use` silently becomes `.evaluation` | receipt V2 strict parse → `.malformedUse("garbage")` typed refusal |
| test_A19_24 | A19-F4 | negative grantRevision accepted as durable evidence | receipt V2 strict parse → `.malformedScalar(field: "grantRevision")` typed refusal |

The non-finding probes (A19_02..06, 09, 10, 13, 15, 16, 18, 19, 25..50) are byte-unchanged and
continue to validate the carried-clean R5 laws (scope, status, source manifest, durable receipt V1
crash recovery, freeze V6 candidate-blob binding, zero-data, no-PASS-lock).

### B. `packages/GuardianKit/Tests/GuardianCoreTests/RWCPreregistrationR5Tests.swift` (R5 BUILDER)

Two coupled changes (the SAME two-change pattern as the R4→R5 transition):

1. `testR5_ZeroData_PhaseTruths_DocsPins_ProductionLocks` (~line 842, the absence-pin)
   - OLD R5 truth: `docs/audit/RWC_PRE14_R5_AUDIT_RESULT.json` does NOT exist.
   - NEW lawful truth: the file EXISTS, parses under schema V3, binds candidate `f30b3932`, verdict
     FIX_REQUIRED, critical 1 / high 2 / medium 2 — and its ABSENCE in the R5 CANDIDATE tree
     (`git cat-file -e f30b3932:docs/audit/RWC_PRE14_R5_AUDIT_RESULT.json` → non-zero) is
     git-verified. Never asserted as PASS. PASS lock + operational root remain ABSENT.
   - Reason: AUDIT19 lawfully created the R5 machine result (pre-declared in
     `AUDIT18_R5_INVERSION_LOCK.md` line 25-26: "the R5 result … is created ONLY by AUDIT19").
2. `testR5_FreezeV6_AnchorConsistency_HashCensus` (~line 926, the live census)
   - OLD: live-hash census of V6 artifacts + `git diff anchor..HEAD` per path.
   - NEW: identical census pinned to the R5 CANDIDATE commit (`git show f30b3932:<path>` blobs +
     `git diff anchor..f30b3932`) — historical V6 truth, immune to the lawful post-V6 R6 edits;
     freeze V7 owns the live census at the R6 anchor.
   - Reason: unavoidable physical consequence of change 1 and the two AUDIT19/R5 files being
     themselves V6-hashed artifacts that R6 lawfully edits (identical to the R4Tests V5-census
     supersession template `testR4_FreezeV5_AnchorConsistency_HashCensus`). Expected semantic delta
     for V6 history: none.

No other builder/auditor file changes semantics. AUDIT14–AUDIT19 verdicts/reports/machine
results/frozen originals are untouched. The V6 freeze manifest and gates V6 are untouched (freeze
V7 + gates V7 are NEW files). If a new need is discovered mid-implementation it is added here as a
dated ADDENDUM committed BEFORE the inverting content.

## Zero-data / no-PASS invariants (unchanged by R6)

corpus=0, annotator=0, real_fit=0, heldout_open=0, data_visibility=false; no PASS lock; no
operational reviewer trust root; production score CLOSED; RWC-REVIEWER-ROOT-ONBOARDING open. R6 is
"BUILDER READY FOR AUDIT20" — NOT a PRE-14 PASS.
