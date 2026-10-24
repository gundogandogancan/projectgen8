# GEN8 — RWC LANE A V10 TARGETED INDEPENDENT AUDIT (AUDIT22T)

**Audit identity:** `AUDIT22T_RWC_V10_TARGETED` · independent, fresh, clean-session auditor.
**Candidate:** `df952d260567c8ffcdde0fed83f8f36617b94c62` (tag `gen8-rwc-lane-a-v10-transition-candidate`,
tag object `c3174ef4611c9b8e3c06ed73605d46f0787d29ea`).
**Anchor:** `6cdfb3ff…` · **Governing lock:** `2c345b64…` · **Freeze V10:** 320 artifacts, digest `464bffe8…`.
**Verdict:** **PASS** — targeted engineering scope only. **PASS ≠ real human governance approval.**
**`OPERATIONAL_ROOT_ACTIVE = FALSE` remains.** No real key / root file / V10 PASS lock created.

This audit follows `/tmp/RWC_V10_TARGETED_AUDIT_MANDATE_DRAFT.md` (narrow scope A–E + V7 matrix). It is NOT
a new audit marathon. The builder's `AUDIT21_V10_TransitionProbes` + `AUDIT21_LaneAOnboardingProofs` were
treated as EVIDENCE, independently re-run, and EXTENDED with 21 fresh adversarial probes.

---

## 1. Custody (re-verified LOCALLY)

| Fact | Value | Status |
|---|---|---|
| Branch / HEAD | `audit/audit22t-v10` / `df952d2…` | OK |
| Candidate tag object | `c3174ef…` (annotated `tag`) | OK |
| Tag → commit deref | `df952d2…` == HEAD | OK |
| Methodology anchor | `6cdfb3ff…` | ancestor of candidate (merge-base) |
| V9 tag | `gen8-rwc-lane-a-onboarding-candidate` → `a74bb57…` → `ec89a5b…` | PRESERVED (not deleted/re-pointed); ancestor of V10 |
| Governing control-plane lock | `2c345b64…` | commit; governing tag derefs to it |
| AUDIT21 / R7 history | `30c7c7c` / `104dad4` | present |
| V8 PASS lock | `docs/audit/RWC_PRE14_PASS_LOCK.yaml` | PRESENT (historical; NOT rebound to V9/V10) |
| Operational trust root | `docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json` | ABSENT |

Network was not required: custody re-derived locally (tag deref, anchor + V9 ancestry, V9/V8 byte
preservation, per-path anchor law). No mismatch → not BLOCKED.

## 2. Independent V10 census (own script: `docs/audit/audit22t_tools/audit22t_v10_census.py`)

- **320 artifacts** in the freeze V10 manifest (expected 320).
- Per-path LIVE sha256 vs manifest: **drift = 0, missing = 0** (319 hashed; manifest + master are hash-exempt).
- **Recomputed inventory digest** `464bffe8…` == declared manifest digest == mandate expected digest
  (formula `sha256("\n".join(sorted("path:sha")))`, matching `RWCCorpusEntryVerifierV3.inventoryDigest`).
- **V8 + V9 freeze manifests byte-identical** anchor..candidate (preservation).
- **Per-path `git diff anchor..candidate` EMPTY** for all 320 frozen artifacts (anchor law clean).
- Freeze V10 manifest blob sha256 (A18-F5 binding) = `1b5198de7637…` (live == candidate-commit blob).

## 3. Baseline red-set match (cwd `packages/GuardianKit`)

Baseline (candidate, before fresh probes): **1225 test methods, 17 failures — matching the mandate's known
set EXACTLY; no red outside the known set.**

| Group | Count | Tests | Classification |
|---|---|---|---|
| 1 — historical lock-absence stale pins | 13 | AUDIT16 test03; AUDIT17 A17_03/A17_29; AUDIT18 A18_03/A18_46; AUDIT19 A19_06/A19_45; R2_F12; R3_F12…; R4_F3F4F11F12; R4_ZeroData; R5_F5F4; R5_ZeroData | PRESERVED stale (OLD truth git-reproducible at `30c7c7c`); V10 does not touch the V8 PASS lock these observe |
| 2 — V8→V10 transition red | 1 | AUDIT21_CLOSEOUT_TransitionProbes…VerifierV6_Succeeds | lawful `frozenFileDrift(RunnerV5)` — V6 is permanently V8-bound; the A21-F5 byte change invalidates the V8 hash (expected security behavior) |
| 3 — worktree AUDIT12 git-tag | 3 | A12_08, A12_09, A12_14 | environment artifact: in a worktree `.git` is a gitdir-pointer FILE, so the frozen AUDIT12 file-probe of `.git/refs/tags` returns false; the tags DO exist (`git tag -l`). Vanishes in the main checkout |

## 4. Attack outcomes (A–E) — evidence: probes + measured results

Fresh probe file: `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT22T_RWCV10TargetedProbes.swift`
(21 probes, all green). Builder's 25 `AUDIT21_V10_TransitionProbes` independently re-run green.

### SCOPE A — operational root bootstrap (`RWCOperationalRootOnboardingV1`)
- `A01_SelfSuppliedFingerprint_SameChannel_AcceptedByForm_NotHumanGate` — **CLASSIFIED HONESTLY:** when the
  caller supplies both the governance record and the fingerprint it computed itself, `verifyCandidate`
  ACCEPTS on form (fingerprint == recomputed). This proves exactly the mandate's critical limit:
  **form-match ≠ independent human approval.** The code CANNOT distinguish an out-of-band fingerprint from
  a self-supplied one; that separation is the human G1–G9 gate (outside code). No authority is minted.
- `A02_FakeGovernanceRecord_Refused` → `.governanceRecordMalformed` (wrong `rwc-gov-` prefix).
- `A03_WrongFingerprint_Refused` → `.fingerprintMismatch`.
- `A04_DuplicateActivation_SameRoot_Refused` → `.alreadyActiveSameRoot`.
- `A05_OldRootReactivation_AfterRotate_Refused` → re-activating the rotated-out root → `.alreadyActiveDifferentRoot`; rotating a non-head retiring id → `.rotateRetiringMismatch`.
- `A06_RestartPersistence_HeadSurvives` → closeStore + openExisting re-derives the same ACTIVE head + chain digest.
- `A07_DiskRollback_OldConsistentState_HonestLimitClassified` — **HONEST LIMIT:** rolling the journal back to
  a CONSISTENT earlier (pre-revoke) snapshot reopens ACTIVE — the revoke is "lost". This is the DECLARED
  local-disk R-5 residual (tamper-DETECTION under a non-hostile-disk model), NOT a regression; absolute
  currentness needs an external monotonic authority (out of scope pre-data).
- `A08_InconsistentTamper_Detected_FailsClosed` → a flipped fingerprint breaks the chain digest → `.storeMalformed`.
- `A09_SecondWriter_Refused` → `.storeLockedByAnotherWriter` (flock single-writer).
- (Also independently covered by the builder: missing/malformed record, unacceptable scope, non-ACTIVE
  candidate, silent replacement, revoke-then-reactivate, rotate.)
- Also confirmed: `loadProduction` stays `.noOperationalRoot`; the capability init / mint stay `internal`
  (A19-F2); `package`-scoped activate/revoke/rotate — an ordinary external consumer cannot activate.

### SCOPE B — A21-F5 receipt fix (`reconcileV5` / `ensureReceipt`)
- `B01_ReconstructionFailure_ReportsDeficit_PreservesEvidence` — with NO receipt + a read-only receipt dir,
  the R-6 reconstruction write fails → NOT reconstructed, NOT finalized, surfaced as explicit
  `receiptDeficit`, quarantine payload PRESERVED (no evidence loss).
- `B02_HealthyReconstruction_Finalizes_Durably` → reconstructs + reload-verified `.completed`; quarantine cleaned only after durable completion.
- `B03_SecondReconciliation_Idempotent` → re-run yields no deficit, state stays `.completed`.
- `B04_CorruptReceipt_TypedRefusal_NotSilentlyCompleted` → a broken SHA-256 integrity line → `.integrityFailure`
  on load (cannot false-finalize off a corrupt file).
- Code-read confirms `finalized`/`reconstructed` are appended ONLY after a RELOAD confirms `.completed`;
  a failed finalize → `deficit` + caller preserves the quarantine. **False finalize is impossible.**

### SCOPE C — rotate() two-write crash safety
- `C01_RotateCrashBetweenWrites_SafeClosed_NoActiveRoot_RecoveryOpen` — injecting a fault between
  `append(ROTATED_OUT)` and `append(ROTATED_IN)` leaves `currentHead.status == REVOKED` → **NO active root
  (SAFE-CLOSED, not partial-active).** Old root NOT active (rotated out); new root NOT active (never written).
  **Recovery is OPEN:** a fresh `activate()` of the new root succeeds (head is non-ACTIVE, so the
  silent-replacement block does not fire); journal chain stays consistent.
- `C02_RotateComplete_BothEventsChained_NewRootActive` — the non-crash control: both events chained, new root active.
- **Classification (honest):** rotate() is TWO durable writes; it is NOT atomic. Its crash-intermediate
  window is a safe-closed no-active-root state with an open recovery path — NOT a window of dual/partial authority.

### SCOPE D — authority-chain backward preservation
- `D01_RealRepo_FullChain_StillFailsClosed_NoRegression` — on the real repo: V7 does not mint (fail-closed),
  V6 still fails (no V8-PASS auto-rebind), `loadProduction` → `.noOperationalRoot`, no trust-root file.
- The A20-F1..F4 chain (token-gated authorization, intended-use + current-registry rechecks) is intact: the
  governed-root → registry → grant → token → authorization → receipt → promotion flow is exercised green by
  the builder's end-to-end proof and by this audit's B-scope staging; no bypass regressed. The 13 stale pins
  + Group-2 red confirm the PRE-14/zero-data seals still hold (unchanged by V10's additive transition).

### SCOPE E — V7 release-verifier matrix (`RWCCorpusEntryVerifierV7`)
Builder matrix (re-run green): positive V10 fixture ACCEPTED + mints `RWCVerifiedCorpusEntryV7`; AUDIT19/20/R7
result-path replays REFUSED (`nonCanonicalAuditResultPath`); V9-no-result REFUSED
(`auditResultMissingInAuditCommit`); V8-PASS rebind REFUSED (V6 accepts a V8-shaped fixture, V7 refuses it);
wrong blob/candidate/tag-object/freeze-sha/digest/governing/anchor/authorized/lock-version/freeze-version/
manifest-path/schema-V4-as-V5 each REFUSED; verdict≠PASS (committed FIX_REQUIRED) REFUSED; real repo fail-closed.
Fresh extensions (green):
- `E01` independent lawful V10 fixture verifies under V7.
- `E02_LiveResultEditedAfterCommit_V7BindsToGitHistory_NotLiveFile` — V7 reads the result blob via
  `git show <audit_commit>:<path>`, so editing the LIVE file post-closeout does NOT change the verdict
  (immune to live-file forgery; closes the A16/A17 "live report not bound to audit commit" class under V7).
- `E03_ForgedBlobShaInLock_Refused` → `.auditResultHashMismatch`.
- `E04_GoverningLockNotMatchingTag_Refused` → a governing value not backed by the governing tag is refused.
- `E05_FloatCount_TypedRefusal` → a float `critical_count` → `.auditCountInvalid` (strict count law carried).
- Confirmed: lock_version stays `rwc-pre14-pass-lock-v4` (no gratuitous V5 bump); V10 identity enforced via
  values (result path, manifest path, freeze_version). V6 stays byte-frozen + historically verifiable.

## 5. Fresh findings

| ID | Sev | File:line | Exploit | Consequence | Min-fix |
|---|---|---|---|---|---|
| — | — | — | NONE | no reproducible defect found in the targeted scope | — |

No CRITICAL / HIGH / MEDIUM finding. Two HONEST LIMITS (not findings, already declared by the builder and
re-confirmed here): (a) `verifyCandidate` form+fingerprint ≠ independent human approval (A01); (b) local
hash-chain rollback to a CONSISTENT earlier state is undetected — the R-5 residual (A07). rotate() non-atomicity
(C01) is a safe-closed design property, not a defect.

## 6. Honest test counts

- Baseline: **1225** methods, **17** failures (known set; enumerated §3).
- Fresh AUDIT22T: **21** methods, **0** failures (session-id fixture bug self-fixed; not a product defect).
- **Total: 1225 + 21 = 1246** (re-confirmed via `swift test list`). Full-suite failures with fresh probes added
  = still exactly 17 (no new red).
- Skips: none introduced by this audit. The only not-green tests are the 17 lawful/known reds above
  (13 stale + 1 transition + 3 worktree-environment); none is a V10 regression.

## 7. Three-status truth

- **PRE14_AUTHORIZED (historical):** the V8-era AUDIT21 PASS stays true for candidate `104dad4`, validated
  ONLY by the byte-frozen `RWCCorpusEntryVerifierV6`. Not rebound to V9/V10.
- **LANE_A (engineering):** V10 release-verifier transition is lawful and additive (0 edited V9-frozen files),
  census-clean, and passes this targeted audit → **LANE_A_SECURITY_ACCEPTED (targeted) / PRE14_VERSIONED_AUTHORITY_VALID**
  at the engineering level. The onboarding engine is `ONBOARDING_ENGINEERING_READY`.
- **OPERATIONAL_ROOT_ACTIVE = FALSE.** No real key, no real root file, no V10 PASS lock. Real activation is a
  separate human gate (G1–G9); this PASS does NOT open it.

## 8. Machine result binding

`docs/audit/RWC_PRE14_V10_AUDIT_RESULT.json` (schema `rwc-pre14-audit-result-v5`, verdict PASS, 0/0/0 findings,
counts 1225+21=1246) binds candidate `df952d2`, tag object `c3174ef`, tag name
`gen8-rwc-lane-a-v10-transition-candidate`, anchor `6cdfb3ff`, freeze manifest V10 sha256 `1b5198de7637…`,
inventory digest `464bffe8…`, governing lock `2c345b64…`. Result blob sha256 (for the eventual V10 PASS lock)
= `c294310b4c61bf95ccd6f47c0fcd8d422f6140b3f0a24977bb7008a4e75b6ebb`.

**PASS authority is earned by this independent auditor, NOT minted by a builder.** The main session performs
the single audit commit and the subsequent lawful closeout (mint the V10 PASS lock bound to V10; V8 lock +
AUDIT21 history preserved; transition reversible; root NOT auto-activated; corpus/score NOT opened).
