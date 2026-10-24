# AUDIT21 → LANE A INVERSION / SUPERSESSION LOCK (pre-declared BEFORE any inverting commit)

Date: 2026-10-24. Phase branch: `phase/rwc-lane-a-onboarding`. Worktree HEAD = closeout commit
`e437036407f5d535eb209bd9499aec1ef0c2bc62`. Pre-closeout immutable snapshot (lock ABSENT) =
`30c7c7cd0bc98b01b008506bfa79c7fe0090fbf0`.

Template: `docs/audit/AUDIT20_R7_INVERSION_LOCK.md`. **COMMITTED FIRST by the main session, BEFORE any
inverting/implementing content** (commit-order law). Any semantic change to a frozen V8 surface not
declared here is rejected. The main session may amend this lock before committing.

Zero-data / fail-closed invariants UNCHANGED: corpus=0, annotator=0, real_fit=0, heldout=0,
data_visibility=false; NO operational reviewer trust root (`docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json`
stays ABSENT); production score CLOSED; NO `OPERATIONAL_ROOT_ACTIVE`. LANE A ceiling:
**ONBOARDING_ENGINEERING_READY — ACTIVATION_BLOCKED**.

---

## 0. KEY DECISION — why the 13 stale pins are PRESERVED (not edited), unlike the A21-F5 probe

The mandate §4.b asked to "update each pin to assert the new truth." On measurement that is **unlawful for
the 13 lock-absence pins + the cwd-sensitive pin C2**, because the files that hold them are protected by TWO
independent freeze-immutability mechanisms that a textual inversion would violate:

1. **Freeze-manifest hash census.** The builder test files (`RWCPreregistrationR2/R3/R4/R5/R7Tests.swift`)
   are HASHED artifacts in freeze manifests V3–V8. Four census tests
   (`testR2_F8_FreezeV3_AnchorConsistency_HashCensus`, `testR3_FreezeV4_…`, `testR4_FreezeV5_…`,
   `testR5_FreezeV6_…`) assert `sha256(live)==manifest_sha` + `git diff anchor..HEAD -- path == ""`.
   Editing any of these files breaks its own historical census — measured: editing R2Tests flipped
   `testR2_F8` to a hash mismatch (`bc7339ee…` vs frozen `9a133e06…`).
2. **Byte-identity "discipline" pins.** `testR3_Discipline_AUDIT16FrozenOriginals_ZeroInversions`,
   `testR4_Discipline_AUDIT17Frozen_…`, `testR5_Discipline_AUDIT18Frozen_…`, `test_A19_04_AUDIT18_
   FrozenOriginals_Immutable`, and `test02_Audit15_ByteImmutability_ZeroInversions` assert specific
   AUDIT14–18 probe files are byte-identical to hard-coded SHA-256s. Editing AUDIT16/AUDIT17/AUDIT18 files
   breaks these discipline pins.

Because each pinning test is itself a frozen, mutually-pinned file, "updating" one requires re-anchoring the
entire discipline chain — which is exactly what the freeze design forbids in place (supersession is by NEW
files at a NEW anchor, never in-place edits of historical frozen tests). Per the decision-precedence law
(LEGAL/SECURITY > …), the freeze-immutability law overrides the §4.b "edit the pins" instruction. We
therefore **preserve the 13 lock-absence pins + C2 exactly as the closeout left them** — lawful
stale-by-phase-transition, red, NOT edited, with the OLD truth git-reproducible at `30c7c7c` — and record
the inversion census below as documentation of the new truth without mutating the frozen files.

The A21-F5 §7 probe is the ONE exception that IS lawfully editable (see Part 2B): it lives in
`AUDIT21_RWCPre14R7ReauditProbes.swift`, which is AUDIT-prefixed (freeze `post_audit_allowances` →
NOT a hashed artifact) AND is NOT referenced by any byte-identity discipline pin (verified exhaustively).

---

## CUSTODY (re-verified locally in the LANE A worktree)

| Fact | Value | Status |
|---|---|---|
| Branch | `phase/rwc-lane-a-onboarding` | OK |
| HEAD (= closeout) | `e437036407f5d535eb209bd9499aec1ef0c2bc62` | OK |
| Pre-closeout snapshot (lock absent) | `30c7c7cd0bc98b01b008506bfa79c7fe0090fbf0` | lock ABSENT (git-verified: `git cat-file -e 30c7c7c:docs/audit/RWC_PRE14_PASS_LOCK.yaml` → fatal) |
| PASS lock at HEAD | `docs/audit/RWC_PRE14_PASS_LOCK.yaml` | PRESENT (git-verified at e437036) |
| R7 candidate commit / tag | `104dad45…` / `gen8-rwc-preregistration-r7-audit-candidate-final` | present |
| Operational trust root file | `docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json` | ABSENT (never created by LANE A) |

No history rewrite, no commit (worktree cannot commit). Main session commits in the lawful order, lock FIRST.

---

## PART 1 — NEW surfaces (zero mutation of any frozen artifact)

- `packages/GuardianKit/Sources/GuardianCore/RWCOperationalRootOnboardingV1.swift` — the governed
  activation engine (`RWCOperationalRootOnboardingV1` load/verify/activate/revoke/rotate) +
  `RWCGovernanceRecordV1` + inert value types + the durable hash-chained `RWCOperationalRootActivationStoreV1`.
  Mints the A19-F2 capability + verified root V2 ONLY after the OOB-fingerprint + governance-record laws pass;
  `activate`/`revoke`/`rotate` are `package` (external GuardianCore consumers cannot activate). This file is a
  NEW governed-root source → it enters freeze **V9** automatically (recursive scan).
- `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT21_LaneAOnboardingProofs.swift` — onboarding positive +
  fail-closed negatives, full synthetic chain with a GOVERNED root, A21-F5 fault-injection. AUDIT-prefixed →
  `post_audit_allowances` (not hashed). MEASURED 12/12 green.
- Operational docs (UNGOVERNED `docs/operations/rwc/`, outside every governed root):
  `RWC_OPERATIONAL_ONBOARDING_ARCHITECTURE_V1.md`, `RWC_GOVERNANCE_AND_KEY_MANAGEMENT_V1.md`,
  `RWC_OPERATIONAL_TRANSITION_CONTRACT_V1.md`, `RWC_RIGHTS_REVIEW_CHECKLIST_V1.md`,
  `RWC_GOVERNANCE_RECORD_TEMPLATE_V1.json`, `RWC_HUMAN_ACTIVATION_GATE_V1.md`.
- `docs/calibration/preregistration/tools/generate_freeze_manifest_v9.py` — V9 generator (manifest
  regenerated by the MAIN SESSION at the new anchor; see Part 4).
- This lock + two frozen-original archives (Part 3).

---

## PART 2 — MUTATED frozen-V8 surfaces — DECLARED supersessions (EXACTLY TWO files)

### 2A. A21-F5 TARGETED FIX — `RWCCorpusAcquisitionRunnerV5.swift` (FROZEN V8 production source)

In-place minimal fix of `reconcileV5.ensureReceipt` (no new architecture version). Declared supersession:

| | OLD (A21-F5, LOW) | NEW |
|---|---|---|
| failed `complete()` on finalize | `try?`-swallowed, then UNCONDITIONAL `finalized.append` (false finalize while durable receipt stays `.prepared`) | finalize attempted, receipt RELOADED, `finalized.append` ONLY if durable `.completed`; else explicit `receiptDeficit` |
| reconstruction path | append without post-write recheck | append ONLY after reload confirms `.completed`; else `receiptDeficit` |
| quarantine deletion | deleted regardless of outcome (evidence loss on failed finalize) | `ensureReceipt` returns success; quarantine deleted ONLY on durable completion — a deficit PRESERVES the payload evidence |
| recovery | n/a | the preserved-evidence deficit is retryable (next reconcile finalizes once the fault clears) |

The old swallow-and-report logic is retained inline as negative-history. Idempotence + all other reconcile
behavior unchanged. Only frozen V8 source file mutated.

### 2B. A21-F5 PROBE SUPERSESSION — `AUDIT21_RWCPre14R7ReauditProbes.swift`, `test_A21_R6_01_…FaultInjection`

The AUDIT21 §7 probe PINNED the A21-F5 defect (`XCTAssertTrue(report.finalizedReceipts.contains(session), …)`
+ "reconcile #1 deletes quarantine so #2 cannot self-heal"). Since LANE A FIXES the defect, this probe is
inverted to assert the FIXED behavior: the failed finalize is `XCTAssertFalse(…finalizedReceipts…)` +
`receiptDeficitSessions.contains(session)` + quarantine PRESERVED + reconcile #2 (fault cleared) finalizes.
The old EXPLOIT assertions are retained inline as negative history. This file is **lawfully editable**:
AUDIT-prefixed (`post_audit_allowances`, not a hashed freeze artifact) AND not referenced by any byte-identity
discipline pin (verified exhaustively across the test suite). Measured: the inverted probe passes.

> FREEZE-V8 INVALIDATION LAW: the 2A change to a frozen V8 source requires a NEW anchor + manifest V9 +
> independent verification. The worktree prepares the V9 generator + this lock; the MAIN SESSION does the
> anchor + manifest V9 regen + candidate tag, and a TARGETED independent verification (not a full AUDIT22
> marathon) is recommended per mandate §10.

---

## PART 2C — PRESERVED lawful-stale pins (NOT edited — documented new truth only)

The following remain EXACTLY as the closeout left them (red, lawful stale-by-phase-transition), NOT edited,
for the freeze-immutability reasons in §0. The OLD truth is git-reproducible at `30c7c7c`; the NEW truth is
recorded here as documentation. (Errors were measured in the closeout post-lock suite; census rows cited.)

| # | file:line | test | OLD truth (30c7c7c) | NEW truth (e437036) — documented, test left red |
|---|---|---|---|---|
| 1 | AUDIT16_RWCPre14R2ReauditProbes.swift:144 | test03_ZeroData_Counters_ProductionLocks | lock ABSENT | lock EXISTS; counters still 0 |
| 2 | AUDIT17_RWCPre14R3ReauditProbes.swift:346 | test_A17_03_ZeroData_ProductionLocks | lock ABSENT | lock EXISTS |
| 3 | AUDIT17_VerifierAuthorityProbes.swift:599,602 | test_A17_29_RealRepo_FailClosed_NoPassLock | ABSENT + V3 `.lockMissing` | EXISTS + V3 `.lockVersionUnsupported` |
| 4 | AUDIT18_RWCPre14R4ReauditProbes.swift:305,309 | test_A18_03_ZeroData_HardGate_NoPassLock_FailClosed | ABSENT + V4 `.lockMissing` | EXISTS + V4 `.lockVersionUnsupported` |
| 5 | AUDIT18_VerifierFreezeProbes.swift:402 | test_A18_46_AuditCommit_AddOnly_RealRepo_NoPassLock | V4 `.lockMissing` | V4 `.lockVersionUnsupported` |
| 6 | AUDIT19_RWCPre14R5ReauditProbes.swift:227 | test_A19_06_ZeroData_RootAndResultAndLockAbsent | lock ABSENT (root-absence KEPT TRUE) | lock EXISTS; operational-root absence + loadProduction fail-closed UNCHANGED |
| 7 | AUDIT19_RWCPre14R5ReauditProbes.swift:1198 | test_A19_45_NoPassLock_Present | lock ABSENT | lock EXISTS |
| 8 | RWCPreregistrationR2Tests.swift:634,637 | testR2_F12_CorpusEntryVerifier_Authority | ABSENT + V2 `.lockMissing` | EXISTS + V2 `.lockMalformed` |
| 9 | RWCPreregistrationR3Tests.swift:545,548 | testR3_F12F13F14F15F16_PassLockAuthority | ABSENT + V3 `.lockMissing` | EXISTS + V3 `.lockVersionUnsupported` |
| 10 | RWCPreregistrationR4Tests.swift:593 | testR4_F3F4F11F12_VerifierV4_Authority | V4 `.lockMissing` | V4 `.lockVersionUnsupported` |
| 11 | RWCPreregistrationR4Tests.swift:699 | testR4_ZeroData_PhaseTruths_DocsPins_ProductionLocks | lock ABSENT (R4-candidate git pin KEPT) | lock EXISTS |
| 12 | RWCPreregistrationR5Tests.swift:753 | testR5_F5F4_VerifierV5_CandidateBlob_TagName_Authority | V5 `.lockMissing` | V5 `.nonCanonicalAuditResultPath` |
| 13 | RWCPreregistrationR5Tests.swift:860 | testR5_ZeroData_PhaseTruths_DocsPins_ProductionLocks | lock ABSENT (R5-candidate git pin + root-absence KEPT) | lock EXISTS; root absence UNCHANGED |
| C1 | AUDIT21_RWCPre14R7ReauditProbes.swift:840 | test_A21_V8_12_RealRepo_FailsClosed_LockMissing | raw-cwd real-repo V6 `.lockMissing` | PRESERVED unchanged (soft raw-cwd; under `--package-path packages/GuardianKit` cwd has no lock → still `.lockMissing` → GREEN; it is NOT edited) |
| C2 | RWCPreregistrationR7Tests.swift:515 | testR7_MAINSESSION_VerifierV6_SyntheticPASS_Accepts | raw-cwd real-repo `.lockMissing` (soft `else { return }`) | PRESERVED unchanged (soft branch stays green; byte-identity/census-protected file not edited) |

NOTE on C1/C2: both read raw `FileManager.default.currentDirectoryPath` and both have SOFT handling (C1's
throws-closure that only fails on the wrong case under package-path cwd; C2's `else { return }`). Under the
closeout's measured invocation (`--package-path packages/GuardianKit`, cwd has no lock) they remain GREEN.
They are LEFT UNEDITED for the same freeze-immutability reasons (AUDIT21_R7 is editable, but C1 at line 840 is
a separate probe from the A21-F5 §7 probe; editing C1 is unnecessary — it is already green under the
baseline invocation — so it is preserved to minimize frozen-surface churn; RWCPreregistrationR7Tests is
census+discipline-protected and is NOT edited).

Interpretation: 0 NEW defects mis-classified as stale. The 13 reds are the exact lawful
stale-by-phase-transition set the closeout measured and forbade editing; LANE A preserves them and documents
the new truth here rather than violating freeze immutability.

---

## PART 3 — FROZEN ORIGINALS (byte-preserved for the TWO edited files)

Archived from `git show e437036:<path>` (HEAD blob = pre-edit byte state; worktree was clean before editing).
**Main session MUST re-verify** each equals `git show e437036:<path>` before committing.

| Frozen original | SHA-256 |
|---|---|
| `docs/audit/RWCCorpusAcquisitionRunnerV5_ORIGINAL_LOCKED.swift.txt` | `08d4aad64662cd2b78cb51c10d7907c291f4158d7822b890530a5d1de7f7bf16` |
| `docs/audit/AUDIT21_RWCPre14R7ReauditProbes_ORIGINAL_LOCKED.swift.txt` | `1d4e924d24dd6da188bfd8c00ab191dfaf982293e689073ea14ca7fd913e0c48` |

(No other `_ORIGINAL_LOCKED` archive is created or modified; the pre-existing AUDIT14–18 discipline archives
are untouched.) OLD stale-pin truth reproduction:
`git show 30c7c7c:docs/audit/RWC_PRE14_PASS_LOCK.yaml` → fatal (lock ABSENT).

---

## PART 4 — FREEZE V8 INVALIDATION → V9 PREPARATION (mandate §4.b note)

LANE A changes a frozen V8 source (the A21-F5 RunnerV5 fix) AND adds a new governed GuardianCore source
(`RWCOperationalRootOnboardingV1.swift`). Per the freeze-V8 invalidation law this requires a NEW anchor +
manifest V9. `generate_freeze_manifest_v9.py` is prepared (copied from v8): `freeze_version →
rwc-preregistration-freeze-v9`; self/post-anchor → V9; `RWCOperationalRootOnboardingV1.swift` added to
`METHODOLOGY_CODE`; v9 self-listed; `supersession_reason` = A21-F5 fix + onboarding engine. `governed_roots`
UNCHANGED; the recursive scan auto-includes the new source + the edited RunnerV5 bytes. `docs/operations/rwc/`
is NOT a governed root. The AUDIT21_R7 §7 edit is covered by `post_audit_allowances` (not hashed) so it does
not change the inventory digest.

MAIN SESSION order: (1) commit this lock FIRST; (2) new surfaces; (3) the 2A/2B supersessions; (4) docs;
(5) new LANE A anchor → run the V9 generator → regenerate the V9 manifest → candidate tag; (6) TARGETED
independent verification. Manifests V1–V8, gates V1–V8, AUDIT14–21 results/locks are NOT edited.

---

## PART 5 — MEASURED SUITE OUTCOME (honest; cwd = `packages/GuardianKit`, matching the closeout baseline)

Not "all green." The MEASURED full-suite red set is THREE categories, all accounted for:

**(a) The SAME 13 lawful stale reds as the closeout baseline (Part 2C rows 1–13).** Measured present and
matching exactly. Preserved by design; NOT edited (freeze-immutability). This is the documented baseline.

**(b) ONE declared freeze-V8-invalidation red caused by the A21-F5 RunnerV5 byte change:**
`AUDIT21_CLOSEOUT_TransitionProbes.test_CLOSEOUT_RealRepo_VerifierV6_Succeeds_WithExactBindings` →
`carried(.frozenFileDrift(path: …RWCCorpusAcquisitionRunnerV5.swift))`. The real-repo VerifierV6 does a
per-artifact live-hash check over freeze V8's governed roots; the A21-F5 fix changed RunnerV5's bytes, so
the LIVE file no longer matches the V8 manifest. This is EXACTLY the declared freeze-V8 invalidation. It is
GREEN again after the MAIN SESSION regenerates manifest V9 at the new LANE A anchor and mints a new PASS
lock bound to V9. (The new `AUDIT21_LaneAOnboardingProofs` full-chain + A21-F5 fault-injection use
self-contained synthetic fixtures whose manifests exclude RunnerV5, so they are 12/12 GREEN; the inverted
A21-F5 §7 probe is GREEN; the existing R7 reconcile tests stay GREEN — all measured.)

**(c) THREE PRE-EXISTING worktree-baseline reds, UNRELATED to this round:**
`AUDIT12_UluEvrenControlPlaneProbes.testA12_08/testA12_09/testA12_14`. Root cause: these use
`gitTagExists(tag)` which FILE-PROBES `<repoRoot>/.git/refs/tags/<tag>` and `<repoRoot>/.git/packed-refs`.
In a git WORKTREE `.git` is a FILE (gitdir pointer), so `.git/refs/tags/` does not exist and the probe
returns FALSE for every tag — even though the tags DO exist (shared object store). Verified: `.git` is a
file here; `git tag -l` lists all five tags; `.git/refs/tags/` is absent. These fail identically at the
CLEAN e437036 worktree checkout and PASS in the main checkout (where `.git` is a directory — where the
closeout measured its 1174/1174). They are a worktree-vs-main-checkout environment artifact, NOT caused by
any LANE A change (LANE A touches neither AUDIT12 nor any git-tag surface). FLAGGED for the main session:
re-measure (b)+(c) in the main checkout after the V9 re-anchor; (c) should vanish there and (b) should go
green once the new V9 lock is bound.

Any red OUTSIDE (a)+(b)+(c) = stop and investigate.
