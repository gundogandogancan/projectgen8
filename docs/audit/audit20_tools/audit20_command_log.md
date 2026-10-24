# AUDIT20 — Reproducible Command Log

Independent RWC PRE-14 R6 security re-audit. Repo `/Users/dogancangundogan/PROJECTGEN8/Gen8`,
branch `audit/audit20-r6`, candidate `47ca59e29f499d79deac21024ef93b5c7d711a05`.
Toolchain: Apple Swift 6.3.3 (swiftlang-6.3.3.1.3), Target arm64-apple-macosx26.0, Python 3.9.
Environment law: every command FOREGROUND; max 600 s per call; no background test runs.

## 1. Git custody (§1)

```
git branch --show-current                              -> audit/audit20-r6
git rev-parse HEAD                                     -> 47ca59e29f499d79deac21024ef93b5c7d711a05
git rev-parse phase/rwc-preregistration-r6             -> 47ca59e29f499d79deac21024ef93b5c7d711a05
git rev-parse origin/phase/rwc-preregistration-r6      -> 47ca59e29f499d79deac21024ef93b5c7d711a05
git rev-parse gen8-rwc-preregistration-r6-audit-candidate         -> ce5abefa476dae4e39ffc656bcf2e579937ef738 (annotated tag object)
git cat-file -t gen8-rwc-preregistration-r6-audit-candidate       -> tag
git rev-parse gen8-rwc-preregistration-r6-audit-candidate^{commit} -> 47ca59e29f499d79deac21024ef93b5c7d711a05
git log --format=%H --first-parent 47ca59e -n 6        -> 47ca59e, e40a6ef, 7297bda, e15ce28, 6cf948e, 48f91565  (exact ancestry)
git rev-parse gen8-rwc-preregistration-r5-audit-candidate^{commit} -> f30b39322500da6e9e8602645e287cd41a61018e (R5 candidate recoverable)
git rev-parse gen8-ulu-evren-control-plane-r1-locked-governing^{commit} -> 2c345b64c720f965b68ec5ee699e1b71fecf0003 (governing lock)
git status                                             -> clean except untracked .planning/ (out of scope) + AUDIT20 add-only artifacts
```
Lock commit 6cf948e (inversion/supersession lock) PRECEDES implementation e15ce28 and inversions 7297bda — confirmed by first-parent order.

## 2. Zero-data / no-authority state

```
ls docs/audit/RWC_PRE14_PASS_LOCK.yaml                 -> No such file (NO PASS LOCK)
ls docs/audit/RWC_PRE14_R6_AUDIT_RESULT.json           -> No such file at audit start (created by AUDIT20 only)
ls docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json    -> No such file (NO OPERATIONAL ROOT)
grep data_visibility/corpus_count/... MASTER_MANIFEST  -> data_visibility=false; corpus=annotator=real_fit=heldout=0
```

## 3. Baseline suite (§9) — BEFORE creating any machine result

```
swift build --package-path packages/GuardianKit                         -> Build complete
swift test  --package-path packages/GuardianKit --parallel              -> 1125 tests, 0 failures  (/tmp/audit20_baseline_parallel.log)
swift test  --package-path packages/GuardianKit --no-parallel           -> Executed 1125 tests, with 11 tests skipped and 0 failures (0 unexpected) in 515.292 s  (/tmp/audit20_baseline_serial.log)
```
The 11 skips are env/flag-gated heavy statistical replication / power-derivation runners
(AUDIT16 x4, AUDIT17 x1, RWCPowerDerivationV3 x3, RWCPowerDerivationV4 x3) — none security-critical.

## 4. Fresh AUDIT20 probes (§4–§7)

```
# compile
swift build --package-path packages/GuardianKit --build-tests           -> Build complete (only benign unused-result warnings)
# fresh family only
swift test  --package-path packages/GuardianKit --no-parallel --filter AUDIT20_RWCPre14R6ReauditProbes
                                                                         -> Executed 11 tests, with 0 failures  (/tmp/a20_probes2.log)
```
All 11 AUDIT20 probes PASS, i.e. the measured behavior matches the adversarial assertions
(EXPLOIT probes encode the observed insecure behavior; CONTROL probes the lawful refusal).

## 5. Full suite WITH fresh probes (§5 evidence-order (c)) — before machine result

```
swift test --package-path packages/GuardianKit --no-parallel           -> Executed 1136 tests, with 11 tests skipped and 0 failures (0 unexpected) in 561.937 s  (/tmp/a20_full_serial.log)
swift test --package-path packages/GuardianKit --parallel              -> 1136 test lines, 0 failures, 11 AUDIT20 probes present (/tmp/a20_full_parallel.log)
```
Honest measured total: baseline 1125 + fresh 11 = **1136**, 11 skips, 0 failures (serial AND parallel agree).

## 6. V7 freeze census (§3)

```
python3 docs/audit/audit20_tools/audit20_v7_census.py   (independent logic; NOT the builder generator)
  -> 299 artifacts, 0 duplicates, 0 live drift, 0 candidate-blob drift,
     recomputed inventory digest = 8a1751c397523d743fe77d9dd7c8de6a4a364bc625217fb123b18891f5619a57
     == manifest field == builder claim; anchor e40a6ef; anchor->candidate changed ONLY the V7 manifest;
     surface set equality clean on all 4 governed roots (live + git-tree); no symlinks; negative tests pass.
```
Measurements: docs/audit/audit20_tools/audit20_v7_census_measurements.txt

## 7. Notes on environment refusals
Several compound shell forms using `${PIPESTATUS}`, trailing `echo $?`, or `cd &&` were refused by the
sandbox and re-run as simpler commands / log redirects. Exit status was taken from the Bash tool's own
completion signal and from the XCTest `Executed N tests ... failures` summary lines, not from `$?`.
