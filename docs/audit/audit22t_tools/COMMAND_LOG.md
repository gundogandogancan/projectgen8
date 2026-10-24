# AUDIT22T — command log (independent clean-session auditor)

Worktree: `/Users/dogancangundogan/PROJECTGEN8/Gen8-laneA`, branch `audit/audit22t-v10`,
HEAD = candidate `df952d260567c8ffcdde0fed83f8f36617b94c62`.
Environment laws honored: FOREGROUND-ONLY (no background), git commit DENIED (staged only),
attacks in temp/synthetic fixtures only, real repo read-only except ADD-ONLY audit artifacts.

## Custody (LOCAL re-verification)
- `git rev-parse --abbrev-ref HEAD` → `audit/audit22t-v10`
- `git rev-parse HEAD` → `df952d260567c8ffcdde0fed83f8f36617b94c62`
- `git rev-parse gen8-rwc-lane-a-v10-transition-candidate` → `c3174ef4611c9b8e3c06ed73605d46f0787d29ea` (tag object)
- `git cat-file -t gen8-rwc-lane-a-v10-transition-candidate` → `tag` (annotated)
- `git rev-parse …candidate^{commit}` → `df952d2…` (deref == HEAD)
- V9 tag `gen8-rwc-lane-a-onboarding-candidate` → object `a74bb57…` → commit `ec89a5b…` (PRESERVED, not re-pointed)
- `git merge-base --is-ancestor <V9 commit> df952d2` → YES
- `git merge-base --is-ancestor 6cdfb3ff df952d2` → YES (anchor is ancestor)
- `git cat-file -t 2c345b64…` → `commit` (governing control-plane lock carried)
- `git rev-parse gen8-ulu-evren-control-plane-r1-locked-governing^{commit}` → `2c345b64…` (governing tag derefs to lock)
- AUDIT21 `30c7c7c`, historical R7 `104dad4` present; V8 PASS lock `docs/audit/RWC_PRE14_PASS_LOCK.yaml` PRESENT (not rebound)
- operational trust root `docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json` → ABSENT

## Independent census
- `python3 docs/audit/audit22t_tools/audit22t_v10_census.py`
  → 320 artifacts; per-path live hash drift=0 missing=0;
    recomputed inventory digest == declared == mandate `464bffe8…`;
    V8 + V9 manifest bytes identical anchor..candidate;
    per-path `git diff anchor..candidate` empty for all 320 frozen artifacts → CENSUS PASS.
- freeze V10 manifest sha256 (A18-F5 binding) = `1b5198de7637ebc1e520205e130d117f3c913eb73757b8dd76736b412d88a7b2`
  (live == `git show df952d2:<manifest path>` blob).

## Test state (cwd `packages/GuardianKit`)
- `swift build` → Build complete.
- `swift test list` (baseline) → 1225 test methods.
- `swift test --parallel` (baseline) → 17 failures, matching the known set EXACTLY:
  - 3 worktree AUDIT12 git-tag artifacts (A12_08/09/14) — `.git` gitdir-pointer file-probe, tags DO exist (`git tag -l`);
  - 1 Group-2 transition red (AUDIT21_CLOSEOUT_TransitionProbes…VerifierV6_Succeeds → frozenFileDrift on RunnerV5, lawful);
  - 13 historical lock-absence stale pins (AUDIT16/17/18/19 + R2/R3/R4/R5).
- `swift test --filter AUDIT21_V10_TransitionProbes` → 25/25 pass (builder evidence re-run green).
- V10 result-path absence-pin search in Tests/ → NONE (creating the result flips no pin).

## Fresh probes
- Added `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT22T_RWCV10TargetedProbes.swift` (21 probes; AUDIT-prefixed post-audit allowance).
- `swift build --build-tests` → no errors.
- `swift test --filter AUDIT22T_RWCV10TargetedProbes` → 21/21 pass, 0 failures.
  (first run surfaced 4 B-scope reds caused by a too-short session ID IN MY FIXTURE — grammar
   rwc-acq-[a-z0-9]{16,64}; fixed in the probe; NOT a product defect.)

## Full suite before result creation
- `swift test --parallel` → exactly 17 failures (same baseline set); 0 new reds from the 21 fresh probes.
- `swift test list` → 1246 test methods (1225 baseline + 21 fresh).

## Result
- Created `docs/audit/RWC_PRE14_V10_AUDIT_RESULT.json` (schema V5, verdict PASS, counts 1225+21=1246, 0/0/0).
- Validated: parses under schema V5 count/enum laws; result blob sha256 = `c294310b4c61bf95ccd6f47c0fcd8d422f6140b3f0a24977bb7008a4e75b6ebb`.
- git commit NOT performed (DENIED). All AUDIT22T artifacts STAGED for the main session's single audit commit.
