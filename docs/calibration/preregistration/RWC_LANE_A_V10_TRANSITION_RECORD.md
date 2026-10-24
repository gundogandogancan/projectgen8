# RWC LANE A — V10 RELEASE-VERIFIER TRANSITION RECORD

Date: 2026-10-24. Branch `phase/rwc-lane-a-onboarding`. V9 candidate `ec89a5b9de799a3eff8a8d12fc59217d83475873`.
Status after this transition: **ONBOARDING_ENGINEERING_READY → BUILDER READY FOR TARGETED INDEPENDENT
AUDIT (AUDIT22T)**. NOT a PRE-14 PASS. `OPERATIONAL_ROOT_ACTIVE = FALSE`.

This record is the mandate §12.1 architecture-decision evidence for the V10 release-verifier transition. It
is a post-anchor evidence doc (listed in `post_anchor_allowed` of the V10 generator; NOT a hashed census
member). The binding contract is `docs/audit/AUDIT21_V10_TRANSITION_LOCK.md` (committed FIRST).

---

## 1. Architecture decision (mandate §3 / §12.1) — why V9 is preserved and V10 is purely additive

The V9 candidate is a proven, independently-closed engineering state (A21-F5 fix + governed onboarding
engine; V8/AUDIT21 PASS carried historically). The mandate required moving to the next valid
release-verifier contract WITHOUT a new audit marathon, WITHOUT reinventing the security architecture, and
WITHOUT auto-rebinding the historical V8 PASS to the new code.

Measured facts that forced the shape of the transition:

- `RWCCorpusEntryVerifierV6` is bound by compiled constants to the R7/V8 identity (result path
  `docs/audit/RWC_PRE14_R7_AUDIT_RESULT.json` schema V4; manifest V8; freeze-version
  `rwc-preregistration-freeze-v8`). On the live V9 tree it correctly fails closed with
  `carried(.frozenFileDrift(path: …RWCCorpusAcquisitionRunnerV5.swift))` — the A21-F5 fix changed RunnerV5's
  bytes vs the V8 manifest. This is the EXPECTED freeze-V8 invalidation security behavior (mandate §2), NOT
  a defect. V6 must stay byte-frozen and keep validating only the historical V8-era lock from the historical
  candidate `104dad4`.
- Therefore the next release verifier is a NEW file, `RWCCorpusEntryVerifierV7`. It lands under the
  already-governed root `packages/GuardianKit/Sources/RWCAcquisition/`, so the freeze census GROWS. Per the
  freeze design, growing the census is lawful ONLY via a NEW methodology anchor + manifest V10 + independent
  audit — which is exactly the single V10 candidate the mandate asked for. It is NOT an edit-supersession:
  **zero V9-frozen files are edited.**

Measured census (V9 vs regenerated V10, same governed roots): **315 → 320 artifacts, +5 added, 0 removed,
0 re-hashed.** The five additions are the only new surfaces: schema V5, the now-hashed V9 manifest
(frozen history), the v10 generator (self-listed), verifier V7, and the AUDIT-prefixed V10 transition
probes. This confirms the transition is additive and lawful.

**Decision: preserve V9 (tag never deleted/re-pointed); mint a single V10 candidate that adds the V7
release verifier + schema V5 + V10 manifest; hand ONLY that candidate to one targeted independent audit.**
No simpler lawful path exists: V6 cannot be reused (version-pinned + forbidden rebinding), and editing V9
frozen files to repoint V6 would violate freeze immutability and the no-auto-rebind rule.

---

## 2. What the verifier transition BINDS (mandate §4)

`RWCCorpusEntryVerifierV7.verify(repoRoot:)` is V6's binding matrix carried VERBATIM, differing ONLY in
three bound constants (result path → V10 path; manifest → V10 manifest; freeze-version →
`rwc-preregistration-freeze-v10`). It checks, against the PASS lock (schema `rwc-pre14-pass-lock-v4`,
reused UNCHANGED): candidate commit exists; audit commit exists; anchor exists + is ancestor of candidate;
candidate is ancestor of audit; annotated tag object SHA + tag NAME cross-check (A18-F4) + tag→commit
dereference; canonical V10 result path ONLY; result blob present in the audit commit + SHA match; schema V5
`result_version`; verdict == PASS; CRITICAL/HIGH/MEDIUM == 0; every identity field (candidate/tag-object/
anchor/manifest-path/manifest-sha/inventory-digest/governing-lock) result↔lock agreement; canonical V10
manifest path; live manifest SHA == lock SHA; A18-F5 candidate-freeze-blob binding (live == candidate-blob
== result == lock); `freeze_version == rwc-preregistration-freeze-v10`; manifest anchor/governing/digest
agreement; governing tag dereference; per-artifact live-hash integrity over governed roots; recomputed
inventory digest; recursive symlink-refusing surface-set equality (live AND candidate git-tree, both
directions); master-manifest field-level immutability; the five zero-data invariants
(`data_visibility=false`, corpus/annotator/real_fit/heldout == 0). On success it mints the unforgeable
`RWCVerifiedCorpusEntryV7` (fileprivate init — the ONLY mint path is a full verification).

Refusals (measured, §4 negative matrix green in `AUDIT21_V10_TransitionProbes`): wrong result-blob-sha,
candidate-sha, tag-object-sha, freeze-sha, inventory-digest, governing-lock, anchor; `corpus_entry_authorized=false`;
wrong lock_version; wrong result path INCLUDING the R7/R6/R5 historical paths (AUDIT19/20/R7 replay refusal);
schema-V4-disguised-as-V5; wrong freeze-version; wrong manifest path; verdict FIX_REQUIRED; the V9 builder
candidate with NO audit result (`auditResultMissingInAuditCommit`). V6 REFUSES the lawful V10 fixture (path
+ freeze-version mismatch → no V8-PASS rebinding onto V10) while V6 still ACCEPTS a V8-shaped fixture
(historical verifiability preserved) — both measured green.

The V10 PASS lock does NOT exist and is minted by NO builder session. On the real repo V7 fails closed
(no V10 PASS). Only the independent AUDIT22T auditor may create `docs/audit/RWC_PRE14_V10_AUDIT_RESULT.json`
and earn a verdict; only the main session performs the subsequent closeout.

---

## 3. The three-status truth (mandate §2)

- **PRE14_AUTHORIZED** (historical V8 scope PASS): TRUE — the V8/AUDIT21 PASS lock stays valid and is
  validated ONLY by the byte-frozen `RWCCorpusEntryVerifierV6` from the historical candidate `104dad4`. NOT
  rebound to V9/V10 code.
- **ONBOARDING_ENGINEERING_READY** (V9 builder): TRUE and PRESERVED (tag never deleted/re-pointed).
- **OPERATIONAL_ROOT_ACTIVE**: **FALSE.** No real operational root, no real Ed25519 key pair, no authorized
  reviewer registry, no data ingest. G1–G9 human activation gate OPEN. `verifyCandidate` checks
  form + fingerprint match only; a caller-written governance record + self-presented fingerprint do NOT
  prove independent human approval — that boundary is preserved. `package` access limits external consumers,
  not in-package code; it is NOT cryptographic authority proof.

---

## 4. Honest test-state table (mandate §6 — six-category separation)

Measured baseline on the CLEAN V9 candidate `ec89a5b` in this worktree (cwd `packages/GuardianKit`):
**17 reds, all accounted for** (matching the LANE A report Part 5 verbatim). After the V10 additions: the
SAME 17 reds + the 25 new `AUDIT21_V10_TransitionProbes` all GREEN; no NEW unexplained red.

| Category (mandate §6) | Count | Detail |
|---|---|---|
| NEW engineering tests | 0 | V10 adds no production engine; the verifier is a release-gate contract |
| NEW independent-attack / transition tests | 25 (GREEN) | `AUDIT21_V10_TransitionProbes`: positive V10 fixture + minted entry; §4 negative matrix (17 negatives incl. AUDIT19/20/R7 replay, V9-no-result, FIX_REQUIRED, schema-V4-as-V5, wrong freeze-version/path); real-repo V7 fail-closed; V6 still-fails / V6-refuses-V10 / V6-accepts-V8-shape; worktree-aware git-tag check |
| Regressions | 0 | zero frozen source/test edited; verifier V7 + schema V5 are new files; V7 compiles; RWCAcquisition + GuardianCoreTests build clean |
| Historical stale pins | 13 (RED, preserved) | the lock-absence / stale-by-phase pins — `AUDIT21_LANE_A_INVERSION_LOCK.md` §2C rows 1–13; OLD truth git-reproducible at `30c7c7c`; NOT edited (freeze-immutability) |
| Environment errors | 3 (RED, measured artifact) | `AUDIT12_UluEvrenControlPlaneProbes` testA12_08/09/14 — worktree `.git`-file-pointer breaks the frozen `gitTagExists` file-probe; `git tag -l` subprocess resolves all tags; worktree-fail / checkout-pass |
| Real new bugs | 0 | — |
| V8/V9→V10 transition | 1 (RED, lawful) | `AUDIT21_CLOSEOUT_TransitionProbes.test_CLOSEOUT_RealRepo_VerifierV6_Succeeds_WithExactBindings` → `carried(.frozenFileDrift(…RunnerV5.swift))`; HASHED V9 artifact → NOT edited; stays red on V10 (V6 permanently V8-bound); the NEW V10 probes assert the correct V10 truth instead |

The suite is NOT fully green and we do NOT claim green. The 13 stale pins + 1 transition red + 3 worktree
artifacts do NOT block the lawful transition. Any red OUTSIDE these 17 = STOP and investigate.

Main-session note: re-measure the transition red + the 3 worktree AUDIT12 reds in the MAIN checkout after
the V10 re-anchor — Group 3 (worktree artifact) vanishes there; the transition red stays red (correct, V6
is permanently V8-bound) until/unless the V10 closeout mints a V10 PASS lock validated by V7.

---

## 5. PASS-lock contract (mandate §4) — no gratuitous schema bump

V7 reuses `RWCPre14PassLockV4` (lock_version `rwc-pre14-pass-lock-v4`) UNCHANGED. The lock fields are
version-agnostic identity carriers; V10 identity is enforced through the VALUES V7 checks (V10 result
path, V10 manifest path, V10 freeze-version), not a new lock field. No `RWC_PRE14_PASS_LOCK_SCHEMA_V5.yaml`
is created. See `docs/audit/AUDIT21_V10_TRANSITION_LOCK.md` §5 and
`RWC_PRE14_AUDIT_RESULT_SCHEMA_V5.yaml` `pass_lock_contract_note`.

---

## 6. Next move (mandate §12.10)

Single operational next step: run ONE targeted independent audit (AUDIT22T, draft mandate in
`/tmp/RWC_V10_TARGETED_AUDIT_MANDATE_DRAFT.md`) on the V10 candidate — narrow scope (operational-root
bootstrap, A21-F5 reconcileV5, root-rotation crash safety, authority-chain backward preservation, + the
V7 verifier matrix). The auditor alone creates `docs/audit/RWC_PRE14_V10_AUDIT_RESULT.json` and earns a
verdict; on PASS a separate lawful closeout mints the V10 PASS lock (validated by V7), preserving the V8
lock + AUDIT21 history, keeping the transition reversible, and leaving `OPERATIONAL_ROOT_ACTIVE = FALSE`.
Real key/root activation remains a separate human gate (G1–G9); no key enters the repo; no ingest before
rights verification. (LANE C proceeds in parallel on its own git/test/data boundary.)
