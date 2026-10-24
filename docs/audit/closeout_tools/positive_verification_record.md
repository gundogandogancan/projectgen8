# CLOSEOUT POSITIVE VERIFICATION RECORD — RWCCorpusEntryVerifierV6.verify(realRepo)

This records the ACTUAL `RWCVerifiedCorpusEntryV6` minted by the production verifier against the REAL repo
(working tree at `phase/rwc-pre14-r7-pass-closeout`, HEAD `30c7c7c`) AFTER `docs/audit/RWC_PRE14_PASS_LOCK.yaml`
was created. The verification is driven by the state-transition probe
`AUDIT21_CLOSEOUT_TransitionProbes.test_CLOSEOUT_RealRepo_VerifierV6_Succeeds_WithExactBindings`
(packages/GuardianKit/Tests/GuardianCoreTests/AUDIT21_CLOSEOUT_TransitionProbes.swift).

## How to reproduce

From the repo root (or any dir — the probe walks up to find `docs/calibration`):

```
swift test --package-path packages/GuardianKit --filter AUDIT21_CLOSEOUT_TransitionProbes
```

Expected: `Executed 4 tests, with 0 failures`.

## Actual minted RWCVerifiedCorpusEntryV6 (asserted equal; all pass)

| Field | Actual returned value |
|---|---|
| candidateCommit | `104dad450f3c96e13cb0b785c7c58b21f6b793c5` |
| candidateTagObjectSHA | `7674f97780c8b38e5a0306bfe397bd04c4f6d7d9` |
| auditCommit | `30c7c7cd0bc98b01b008506bfa79c7fe0090fbf0` |
| auditResultBlobSHA256 | `1e0ed74f22f2f85f7cf4e7fb9bb726a653a8113d473ef99f2ea71e9f485cc1ca` |
| methodologyAnchorCommit | `3abb24a22b63a734539fb5aebe92c1953325b590` |
| freezeManifestSHA256 | `a61caaf866fc5ab90268490ef1047c562f4a6c624b8d2f688b85ed8f8ece3517` |
| frozenInventoryDigest | `c64f7632bb892f8fb519050de3dc86aad576078c089f85992e7dcdfd0651fb33` |

Run timestamp: 2026-10-24 (macOS 26, Swift 6.3.3). Result: **verify() SUCCEEDED — PRE-14 PASS lock bound.**

## Commit-timing finding (mandate §4e)

The verifier reads the LOCK file from the WORKING TREE (`Data(contentsOf:)`), and reads the AUDIT RESULT and
the CANDIDATE FREEZE BLOB from COMMITTED git history (`git show <commit>:<path>`). The audit result
(committed at `30c7c7c`) and the candidate freeze blob (committed at `104dad4`) already exist in history, so
`verify()` succeeds the moment the working-tree lock file is present. **The lock does NOT need to be committed
for positive verification to pass** — measured and confirmed here (pre-commit). The closeout commit makes the
lock durable/shareable but does not change the verification outcome. There is NO pre-commit refusal law that
blocks this positive result.
