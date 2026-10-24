# AUDIT21 → V10 RELEASE-VERIFIER TRANSITION / SUPERSESSION LOCK (pre-declared BEFORE any committing)

Date: 2026-10-24. Phase branch: `phase/rwc-lane-a-onboarding`. Worktree HEAD (= V9 candidate) =
`ec89a5b9de799a3eff8a8d12fc59217d83475873`. Pre-closeout immutable snapshot (PASS lock ABSENT) =
`30c7c7cd0bc98b01b008506bfa79c7fe0090fbf0`.

Template: `docs/audit/AUDIT20_R7_INVERSION_LOCK.md` + `docs/audit/AUDIT21_LANE_A_INVERSION_LOCK.md`.
**COMMITTED FIRST by the main session, BEFORE any transition/implementing content** (commit-order law).
Any semantic change to a frozen V9 surface not declared here is rejected. The main session may amend this
lock before committing.

Zero-data / fail-closed invariants UNCHANGED: corpus=0, annotator=0, real_fit=0, heldout=0,
data_visibility=false; NO operational reviewer trust root (`docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json`
stays ABSENT); production score CLOSED; NO `OPERATIONAL_ROOT_ACTIVE`. LANE A ceiling after this transition:
**ONBOARDING_ENGINEERING_READY → BUILDER READY FOR TARGETED INDEPENDENT AUDIT (AUDIT22T)** — NOT a PRE-14
PASS, NOT production-ready.

---

## 0. KEY DECISION — why V9 is PRESERVED and V10 is a PURELY-ADDITIVE census-growth transition

The mandate (§3) requires: "V9 → proven, preserved engineering candidate; V10 → the single new audit
candidate that ALSO carries the release-verifier transition." On measurement the lawful minimal form is a
**purely-additive transition — ZERO edits to any V9-frozen artifact:**

- The existing release verifier `RWCCorpusEntryVerifierV6` is bound (by compiled constants) to the R7/V8
  identity: canonical result path `docs/audit/RWC_PRE14_R7_AUDIT_RESULT.json` (schema V4), manifest
  `…_V8.yaml`, freeze-version `rwc-preregistration-freeze-v8`. It CANNOT consume a V9/V10 identity, and the
  mandate (§4) FORBIDS auto-rebinding the historical V8 PASS to V9/V10 code. V6 must therefore stay
  byte-frozen and continue validating ONLY the historical V8-era lock from the historical candidate.
- The new release verifier `RWCCorpusEntryVerifierV7` is therefore a NEW FILE. Because it lands under the
  already-governed root `packages/GuardianKit/Sources/RWCAcquisition/`, a NEW governed source is created →
  the freeze census grows. Per the freeze design that is lawful **ONLY via a NEW methodology anchor +
  manifest V10 + independent audit** — exactly the V10 candidate. It is NOT an edit-supersession.
- Likewise schema V5 (`RWC_PRE14_AUDIT_RESULT_SCHEMA_V5.yaml`) is a NEW governed file under
  `docs/calibration/preregistration/`. The V10 transition tests are NEW AUDIT-prefixed files under
  `packages/GuardianKit/Tests/GuardianCoreTests/` (freeze `post_audit_allowances` → NOT hashed → do NOT
  change the inventory digest). The V10 manifest generator is a NEW tool under `.../tools/`.

Measured census check (grep over `RWC_PREREGISTRATION_FREEZE_MANIFEST_V9.yaml`): NONE of the V10 deliverable
paths (`RWCCorpusEntryVerifierV7.swift`, `RWC_PRE14_AUDIT_RESULT_SCHEMA_V5.yaml`,
`AUDIT21_V10_TransitionProbes.swift`, `generate_freeze_manifest_v10.py`,
`RWC_PRE14_V10_AUDIT_RESULT.json`, this lock, the transition record) appears in V9. They are all NEW.

**Therefore: SUPERSESSION CENSUS = 0 EDITED V9-frozen files. 0 frozen-original archives required.** This is
a lawful NEW-anchor census-growth transition, not a mutation supersession. (Contrast the R7 lock, which
declared `public→package` demotions, and the LANE A lock, which declared the A21-F5 RunnerV5 byte edit —
V10 declares NEITHER.)

---

## 1. CUSTODY (re-verified locally in the LANE A worktree — `git rev-parse` / `merge-base` / `tag -l` only)

| Fact | Value | Status |
|---|---|---|
| Branch | `phase/rwc-lane-a-onboarding` | OK |
| HEAD (= V9 candidate) | `ec89a5b9de799a3eff8a8d12fc59217d83475873` | OK (`git rev-parse HEAD`) |
| V9 annotated tag object | `a74bb57877edb3ccbd3a5a9c14ccf3903f00ca23` | OK (`git rev-parse gen8-rwc-lane-a-onboarding-candidate`) |
| V9 tag → commit | `ec89a5b…` | OK (`…candidate^{commit}`) |
| V9 methodology anchor | `314b7e812397155a94b6f204099e16878ccd8fef` | ancestor of HEAD (`merge-base --is-ancestor` → true) |
| AUDIT21 commit | `30c7c7cd0bc98b01b008506bfa79c7fe0090fbf0` | ancestor of HEAD (→ true) |
| Governing control-plane lock | `2c345b64c720f965b68ec5ee699e1b71fecf0003` | OK (carried) |
| Historical R7 candidate | `104dad450f3c96e13cb0b785c7c58b21f6b793c5` | carried (V6 keeps validating V8-era lock from here) |
| V8 PASS lock at HEAD | `docs/audit/RWC_PRE14_PASS_LOCK.yaml` | PRESENT (historical V8/AUDIT21 bindings — NOT rebound) |
| Operational trust root file | `docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json` | ABSENT (never created) |
| `.git` in this worktree | FILE (gitdir pointer), not a directory | measured (see §4 Group 3) |

No history rewrite, no commit (the worktree cannot commit). The main session commits in the lawful order,
this lock FIRST. The V9 tag is NEVER deleted or re-pointed.

---

## 2. NEW surfaces (ZERO mutation of any frozen V9 artifact)

- `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV7.swift` — THE V10 release verifier.
  Smallest real delta from V6: identical binding matrix + plumbing (carried VERBATIM from V6/V3), differing
  ONLY in three bound constants:
  - canonical audit-result path → `docs/audit/RWC_PRE14_V10_AUDIT_RESULT.json` (schema V5 instance);
  - canonical freeze manifest → `…/RWC_PREREGISTRATION_FREEZE_MANIFEST_V10.yaml`;
  - expected freeze-version → `rwc-preregistration-freeze-v10`.
  Reuses `RWCPre14PassLockV4` (lock_version `rwc-pre14-pass-lock-v4`) UNCHANGED — the lock schema already
  carries every binding V7 needs (candidate/tag/anchor/manifest/digest/governing/result-path/result-blob/
  authorized/decorative-verdict); see §5 contract note. Mints a NEW proof type `RWCVerifiedCorpusEntryV7`
  (fileprivate init). Fails closed `.lockMissing` on the real repo (no V10 PASS lock exists). Refuses the
  mandate §4 list (AUDIT19/20 FIX_REQUIRED; V9-builder candidate which has NO audit result; a different
  candidate's PASS; wrong path/tag/anchor/manifest/digest/counts; uncommitted fake result; and — enforced
  by the freeze-version + result-path + manifest-sha triad — any attempt to rebind the historical V8 PASS
  to V9/V10 code).
- `docs/calibration/preregistration/RWC_PRE14_AUDIT_RESULT_SCHEMA_V5.yaml` — schema
  `rwc-pre14-audit-result-v5`; canonical instance `docs/audit/RWC_PRE14_V10_AUDIT_RESULT.json`; binds freeze
  manifest V10. Count-laws / A18-F4 tag-name / A18-F5 candidate-freeze-blob carried VERBATIM from V4.
- `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT21_V10_TransitionProbes.swift` — NEW V10 transition +
  verifier probes. AUDIT-prefixed → `post_audit_allowances` (NOT hashed, NOT in the inventory digest).
  Synthetic positive V10 PASS fixture accepted by V7; the §4 negative matrix; real-repo fail-closed; a
  worktree-aware git-tag verification note (§4 Group 3 helper, `git tag -l` subprocess).
- `docs/calibration/preregistration/tools/generate_freeze_manifest_v10.py` — V10 generator (param/copy of
  v9: `freeze_version → v10`; self/post-anchor paths → V10; `RWCCorpusEntryVerifierV7.swift` added to
  METHODOLOGY_CODE; v10 generator self-listed; governed_roots UNCHANGED).
- `docs/calibration/preregistration/RWC_LANE_A_V10_TRANSITION_RECORD.md` — the transition evidence doc
  (architecture decision §12.1, what the verifier transition binds, three-status truth, honest test-state
  table). This path is added to `POST_ANCHOR_ALLOWED` in the V10 generator (post-anchor evidence, like the
  LANE A remediation report), so it is NOT a hashed census member.
- This lock (`docs/audit/AUDIT21_V10_TRANSITION_LOCK.md`) — under `docs/audit/`, which is NOT a governed
  root → not a census member.

---

## 3. MUTATED frozen-V9 surfaces — **NONE**

No frozen V9 artifact is edited. No `public→package` demotion. No in-place source edit. No test edit.
Consequently NO `_ORIGINAL_LOCKED` archive is created for this transition. The pre-existing R7 and LANE A
frozen-original archives are untouched.

Specifically PRESERVED byte-frozen (declared, not touched):
- `RWCCorpusEntryVerifierV6.swift` (V9 manifest line 1152) — stays bound to V8/R7; historical verifiability.
- `AUDIT21_CLOSEOUT_TransitionProbes.swift` (V9 manifest line 1247, HASHED artifact) — NOT edited (see §4
  Group 2 for why it stays lawfully red on V10).
- The 13 stale-pin test files, schema V4, manifests V1–V9, gates, AUDIT14–21 results/reports/locks.

---

## 4. HONEST TEST-STATE MANAGEMENT (mandate §6)

Measured baseline on the CLEAN V9 candidate `ec89a5b` in THIS worktree (`cwd = packages/GuardianKit`):
**17 reds in exactly three categories — matching the LANE A report Part 5 verbatim.**

### Group 1 — 13 historical stale pins (lock-absence / stale-by-phase-transition)
PRESERVED exactly (red, NOT edited; OLD truth git-reproducible at `30c7c7c`); enumerated in
`AUDIT21_LANE_A_INVERSION_LOCK.md` §2C rows 1–13. Unaffected by the V10 transition (V10 adds only new
files; it does not create/alter the V8 PASS lock these pins observe). The 13:
AUDIT16 `test03_ZeroData_Counters_ProductionLocks`; AUDIT17 `test_A17_03_ZeroData_ProductionLocks`,
`test_A17_29_RealRepo_FailClosed_NoPassLock`; AUDIT18 `test_A18_03_ZeroData_HardGate_NoPassLock_FailClosed`,
`test_A18_46_AuditCommit_AddOnly_RealRepo_NoPassLock`; AUDIT19 `test_A19_06_…RootAndResultAndLockAbsent`,
`test_A19_45_NoPassLock_Present`; R2 `testR2_F12_CorpusEntryVerifier_Authority`; R3
`testR3_F12F13F14F15F16_PassLockAuthority`; R4 `testR4_F3F4F11F12_VerifierV4_Authority`,
`testR4_ZeroData_PhaseTruths_DocsPins_ProductionLocks`; R5 `testR5_F5F4_VerifierV5_…`,
`testR5_ZeroData_PhaseTruths_DocsPins_ProductionLocks`.

### Group 2 — V8/V9→V10 release-verifier transition (1)
`AUDIT21_CLOSEOUT_TransitionProbes.test_CLOSEOUT_RealRepo_VerifierV6_Succeeds_WithExactBindings`.
MEASURED error on clean V9: `carried(.frozenFileDrift(path: …RWCCorpusAcquisitionRunnerV5.swift))`.
Root cause: V6 does a per-artifact live-hash check over freeze V8's governed roots; the A21-F5 fix (landed
in V9) changed RunnerV5's bytes, so the LIVE file no longer matches the V8 manifest hash — the expected,
declared freeze-V8-invalidation security behavior (mandate §2). **This test STAYS lawfully RED on V10**: V6
remains bound to the V8 manifest, RunnerV5 still differs from V8, so V6.verify(realRepo) still throws
`frozenFileDrift`. It is a HASHED V9 artifact → NOT edited. The NEW V10 transition probes
(`AUDIT21_V10_TransitionProbes`) assert the correct V10 truth instead:
(i) V7.verify(realRepo) fails closed `.lockMissing` (no V10 PASS lock exists);
(ii) a synthetic V10 PASS fixture is accepted by V7;
(iii) V6.verify(realRepo) STILL fails (frozenFileDrift) — the historical verifier does NOT silently
     consume V9/V10 code;
(iv) V6 STILL validates the historical V8-era lock from the historical candidate (historical
     verifiability preserved) — asserted against a synthetic V8-shaped fixture.

### Group 3 — worktree AUDIT12 git-tag probes (3) — MEASURED environment artifact, NOT a finding
`AUDIT12_UluEvrenControlPlaneProbes.testA12_08 / testA12_09 / testA12_14`.
MEASURED root cause (this worktree): `gitTagExists(_:)` (AUDIT12 probe helper, line 76) FILE-PROBES
`<repoRoot>/.git/refs/tags/<tag>` and `<repoRoot>/.git/packed-refs`. In a git WORKTREE `.git` is a FILE
(a `gitdir:` pointer — measured here: 75-byte file pointing at
`/Users/dogancangundogan/PROJECTGEN8/Gen8/.git/worktrees/Gen8-laneA`), so `<repoRoot>/.git/refs/tags/` does
NOT exist and the file-probe returns FALSE for every tag — even though the tags DO exist in the shared
object store. MEASURED proof:
- `git rev-parse --git-dir` → `…/Gen8/.git/worktrees/Gen8-laneA` (≠ worktree `.git`);
- `git rev-parse --git-common-dir` → `…/Gen8/.git`;
- `.git` is a FILE (not a dir); `<repoRoot>/.git/refs/tags/` is ABSENT;
- `git tag -l gen8-p009c-locked gen8-p009d-locked gen8-ulu-evren-control-plane-audit-candidate` →
  lists all three (worktree-aware subprocess SEES them).
- testA12_09 error: `XCTAssertTrue failed - expected real tag missing: gen8-…` (the test EXPECTS the tags
  present; the file-probe wrongly reports them absent).
**Classification: worktree-fail / checkout-pass environment artifact** — identical to the LANE A report
Part 5(c). These fail at the CLEAN `ec89a5b` worktree checkout and PASS in the main checkout (where `.git`
is a directory). NOT caused by any V10 change (V10 touches neither AUDIT12 nor any git-tag surface). The
frozen AUDIT12 tests are NOT edited. The modern worktree-aware remedy (a `git tag -l` subprocess helper) is
added as a self-contained check inside `AUDIT21_V10_TransitionProbes` — it does NOT modify the frozen test.
FLAGGED for the main session: re-measure Group 2 + Group 3 in the main checkout after the V10 re-anchor;
Group 3 vanishes there; Group 2 stays red (V6 is permanently V8-bound) and that is correct.

### Mandatory six-category separation (mandate §6)
- NEW engineering tests: none this round (V10 adds no production engine; the verifier is a release-gate
  contract, exercised by the new audit-prefixed probes).
- NEW independent-attack tests: `AUDIT21_V10_TransitionProbes` positive + §4 negative matrix (to be run
  green by the main session; the worktree measures them under `swift test --filter`).
- Regressions: ZERO (V10 adds only new files; no frozen source/test edited).
- Historical stale: the 13 Group-1 reds (preserved).
- Environment errors: the 3 Group-3 worktree AUDIT12 reds.
- Real new bugs: ZERO. Any red OUTSIDE Group 1 + Group 2 + Group 3 = STOP and investigate.

The suite is NOT fully green and we do NOT claim green; the 13 stale pins and 3 worktree artifacts do NOT
block the lawful transition.

---

## 5. PASS-LOCK CONTRACT NOTE — lock_version STAYS `rwc-pre14-pass-lock-v4` (no gratuitous schema bump)

V7 parses the PASS lock with the EXISTING `RWCPre14PassLockV4` struct (lock_version
`rwc-pre14-pass-lock-v4`), UNCHANGED. Rationale (same discipline as the R7 closeout, which kept
`rwc-pre14-pass-lock-v4` while moving the result schema V3→V4):

- The lock schema fields are version-agnostic identity carriers: `audit_result_path`,
  `audit_result_blob_sha256`, `audit_commit`, `candidate_commit`, `candidate_tag_name`,
  `candidate_tag_object_sha`, `freeze_manifest_path`, `freeze_manifest_sha256`, `methodology_anchor_commit`,
  `frozen_inventory_digest`, `governing_control_plane_lock`, `corpus_entry_authorized`, `verdict`.
- V7 binds the V10 identity through the VALUES it checks (`audit_result_path` must equal the V10 canonical
  path; `freeze_manifest_path` must equal the V10 manifest path; the live V10 manifest must declare
  `freeze_version == rwc-preregistration-freeze-v10`) — NOT through a new lock field. A V8 lock presented to
  V7 fails on `nonCanonicalAuditResultPath` / `freezeVersionMismatch`, so no new lock_version is needed to
  refuse cross-version rebinding.
- Introducing `rwc-pre14-pass-lock-v5` would be a gratuitous version bump the mandate (§4) forbids. The lock
  schema contract is therefore DOCUMENTED here as carrying V10 bindings under lock_version
  `rwc-pre14-pass-lock-v4`, and no new `RWC_PRE14_PASS_LOCK_SCHEMA_V5.yaml` is created.

The real V10 PASS lock does NOT exist and is NOT minted by any builder session — only the independent
AUDIT22T auditor may earn a V10 PASS, and only the main session performs the subsequent closeout.

---

## 6. MAIN-SESSION COMMIT ORDER (lock FIRST)

1. Commit THIS lock FIRST (`docs/audit/AUDIT21_V10_TRANSITION_LOCK.md`).
2. New surfaces: `RWCCorpusEntryVerifierV7.swift` + `RWC_PRE14_AUDIT_RESULT_SCHEMA_V5.yaml`.
3. New tests: `AUDIT21_V10_TransitionProbes.swift`.
4. Docs/tools: `RWC_LANE_A_V10_TRANSITION_RECORD.md` + `generate_freeze_manifest_v10.py`.
5. NEW LANE A V10 methodology anchor → run the V10 generator at that anchor → regenerate
   `RWC_PREREGISTRATION_FREEZE_MANIFEST_V10.yaml` → verify per-path `git diff anchor..candidate` empty for
   every frozen surface → candidate tag `gen8-rwc-lane-a-v10-transition-candidate` (annotated).
6. TARGETED independent audit (AUDIT22T) on the V10 candidate — the auditor alone may create
   `docs/audit/RWC_PRE14_V10_AUDIT_RESULT.json` and earn a verdict.
7. If PASS: separate lawful closeout mints the V10 PASS lock bound to V10; V8 lock + AUDIT21 history
   preserved; transition reversible; root NOT auto-activated; corpus/score NOT opened.

Manifests V1–V9, gates V1–V9, AUDIT14–21 results/reports/locks, the V8 PASS lock, the 13 stale-pin files,
and the two frozen originals from the LANE A lock are NOT edited. The V9 tag is NOT deleted or re-pointed.

---

## 7. Zero-data / no-PASS invariants (unchanged by the V10 transition)

corpus=0, annotator=0, real_fit=0, heldout_open=0, data_visibility=false; no V10 PASS lock; no operational
reviewer trust root; production score CLOSED; `OPERATIONAL_ROOT_ACTIVE = FALSE`; G1–G9 human activation gate
OPEN. V10 ceiling is **BUILDER READY FOR TARGETED INDEPENDENT AUDIT (AUDIT22T)** — NOT a PRE-14 PASS, NOT
production-ready. PASS authority remains with the independent auditor; the builder mints NO PASS.
