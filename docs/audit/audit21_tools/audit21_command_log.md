# AUDIT21 — Independent Command Log & Measurements (chief security auditor)

Clean-session ADOPT-VERIFY-COMPLETE of the inherited probes artifact. Every load-bearing measurement
below was re-run by this auditor; nothing is trusted from the dead session or the builder.

## Custody (all re-run locally)

- `git rev-parse HEAD` → `104dad450f3c96e13cb0b785c7c58b21f6b793c5` (branch `audit/audit21-r7`).
- `git rev-parse gen8-rwc-preregistration-r7-audit-candidate-final` → `7674f97780c8b38e5a0306bfe397bd04c4f6d7d9` (annotated tag object).
- `… -final ^{commit}` → `104dad4…`; `git cat-file -t` both candidate tags → `tag` (annotated, both preserved).
- Superseded `gen8-rwc-preregistration-r7-audit-candidate` → tag object `4a9fb34…` → commit `ed2f668…` (preserved).
- Anchor `3abb24a…` ancestor of HEAD: YES. AUDIT20 `5185101…` ancestor: YES. Governing lock `2c345b64…` ancestor: YES.
- Inversion/supersession lock `8e4437f` is an ancestor of the candidate AND precedes the anchor `3abb24a`
  (declaration BEFORE inversion — §2 satisfied).
- Post-anchor commits: only `ed2f668` (V8 manifest at anchor), `ef8a68c` (.build untrack + gitignore),
  `104dad4` (anchor-law correction restoring the R7 change ledger byte-identical to the anchor blob).
- R7 change ledger byte-identical anchor..candidate: `git diff --stat 3abb24a 104dad4 -- …R7_CHANGE_LEDGER.md` EMPTY.
- V7 + V6 freeze manifests byte-identical anchor..candidate (EMPTY diff) — history preserved.
- Supersession note `docs/audit/R7_CANDIDATE_SUPERSESSION_NOTE.md` references old tag object `4a9fb34` → `ed2f668`
  and anchor `3abb24a` + V8 manifest at `ed2f668` — consistent with real git history.

## Independent V8 census (docs/audit/audit21_tools/audit21_v8_census.py)

Auditor-own re-derivation (does NOT call the builder generator). Result:

- manifest artifact count = **309** (expected 309); hash_exempt = 2 (V8 manifest + master manifest).
- 308 non-exempt files independently SHA-256 hashed from the LIVE filesystem; drift = 0; missing = 0.
- inventory digest recomputed with the canonical verifier algorithm
  `sha256( sorted("path:declaredsha").join("\n") )` = **c64f7632bb892f8fb519050de3dc86aad576078c089f85992e7dcdfd0651fb33**
  == manifest declared == mandate expected.
- HEAD == candidate `104dad4`; anchor→candidate drifted frozen artifacts (excl. post_anchor_allowed) = **0**.
- tracked `.build` entries (`git ls-files`) = **0** (the 4702-file untrack is complete).
- CENSUS: **PASS**.

Freeze manifest sha256 (live) = `a61caaf866fc5ab90268490ef1047c562f4a6c624b8d2f688b85ed8f8ece3517`
== sha256(git show 104dad4:…V8.yaml) (A18-F5 candidate-freeze-blob law satisfied).

## Test measurements (serial-filtered + full parallel; foreground only)

- `swift build` (GuardianKit): Build complete.
- BASELINE on the clean candidate (probes file stashed OUT): `swift test --parallel` → reaches
  `[1146/1146]`, Test run passed, 0 failures, 0 `error:`, 0 `XCTAssert…failed`. **Baseline = 1146/1146 GREEN**
  (independently confirms the builder 1146 claim).
- Fresh AUDIT21 probes (`swift test --filter AUDIT21_RWCPre14R7ReauditProbes`): after auditor fixes,
  **Executed 28 tests, 0 failures**.
- FULL suite with fresh probes (`swift test --parallel`): reaches `[1174/1174]`, 0 failure lines.
  **Total = 1174 = 1146 baseline + 28 fresh** (arithmetic honest).
- Real skips on this macOS host = **0**. The 5 "skip" string matches are test NAMES containing "skip"
  (skip-logic feature tests), not skipped tests. All `XCTSkip` guards live in GuardianMediaTests
  (AVAssetWriter/speech runtime gates) and did NOT trigger; no security test is gated/skipped.

## §4 external-consumer compile proofs (docs/audit/audit20_tools/a20consumer_r7)

- Positive `swift build` → Build complete.
- Token negative (auditor temporarily uncommented, then reverted): `swift build` FAILS with
  `'RWCAcquisitionAuthorityTokenV1' initializer is inaccessible due to 'package' protection level`.
- Module negative (`import RWCAcquisition`, reverted): `swift build` FAILS with `no such module 'RWCAcquisition'`
  (RWCAcquisition is a target, NOT a product — Package.swift products = GuardianCore/Intelligence/Media only).
- After reverts, `git status --short docs/audit/audit20_tools/` is clean (no net change to the consumer package).

## §7 fault-injection (reconcileV5.ensureReceipt) — FINDING A21-F5

- With a PREPARED receipt + already-promoted asset + receipt dir set 0o500, reconcileV5 runs
  `try? confirmPromotion` / `try? complete` (both fail on the read-only dir) and STILL appends the session
  to `finalizedReceipts`. MEASURED: report line says finalized; durable receipt state = `.prepared`.
- A plain subsequent reconcile does NOT self-heal (quarantine removed on the stored-asset path; the
  second-pass loop skips `stored` assets). With the quarantine re-materialised, the next reconcile DOES
  drive the receipt to `.completed` → the gap is recoverable, not permanent, and never a false durable
  `.completed`. `reconcileV5` and its report have NO production consumer (return-value diagnostic only).

## Verdict artifacts

- `docs/audit/RWC_PRE14_R7_AUDIT_RESULT.json` created (verdict PASS; counts 1146/28/1174; 0/0/0 crit/high/med)
  ONLY after the verdict. Valid strict JSON.
- NO PASS lock created: `docs/audit/RWC_PRE14_PASS_LOCK.yaml` does NOT exist; the real repo still throws
  `lockMissing` (probe A21-V8-12 green after result creation → builder absence-pin NOT staled).
