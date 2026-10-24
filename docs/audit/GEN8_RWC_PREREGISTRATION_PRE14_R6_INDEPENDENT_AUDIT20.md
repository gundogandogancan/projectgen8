# GEN8 — RWC PRE-14 R6 INDEPENDENT SECURITY RE-AUDIT (AUDIT20)

**Role:** Independent Principal Security Auditor / Adversarial Systems Engineer / Git Evidence Custodian
(fresh clean session; NOT the R6 builder).
**Target:** RWC Preregistration R6.
**Repository:** `gundogandogancan/projectgen8`.
**Auditor branch:** `audit/audit20-r6` (from candidate `47ca59e`, no rewrite of the candidate).
**Date:** 2026-10-24.

---

## VERDICT

> # FIX_REQUIRED — 1 CRITICAL / 1 HIGH / 2 MEDIUM (fresh), plus the §7 release/authorization integration BLOCKER.

R6's engineering methodology is **auditable** and its historical custody/freeze state is **sound**
(custody reproducible; AUDIT19 history intact; V7 census reproduces 299 artifacts / digest
`8a1751c3…` exactly; baseline 1125 green). But the R6 remediation of AUDIT19 A19-F1 is **incomplete**:
the PRE-14 PASS methodology gate is bypassable through the public ledger+runner API given a (future,
legitimately onboarded) verified rights grant, because the ledger-resident acquisition authorization
is written from **free-form scalar** PRE-14 identifiers rather than from a verified
`RWCVerifiedCorpusEntryV5` PASS proof. Separately, the production corpus-entry verifier
(`RWCCorpusEntryVerifierV5`) is pinned to the **R5 result path + V6 manifest** and cannot consume a
future R6 PASS (R6 result path + V7 manifest) without a lawfully versioned verifier V6 / schema V4.

First-asset authorization remains **BLOCKED** (no operational reviewer root, no PASS lock, zero-data
intact). This audit does NOT create a PASS lock and does NOT fabricate an operational root.

---

## 1. GIT CUSTODY AND SHA CHAIN (§1) — REPRODUCIBLE

| Fact | Expected | Measured | Status |
|---|---|---|---|
| Auditor branch | audit/audit20-r6 | audit/audit20-r6 | OK |
| HEAD | 47ca59e… | 47ca59e29f499d79deac21024ef93b5c7d711a05 | OK |
| origin/phase/rwc-preregistration-r6 | 47ca59e | 47ca59e29f499d79deac21024ef93b5c7d711a05 | OK |
| Annotated tag object | ce5abefa… | ce5abefa476dae4e39ffc656bcf2e579937ef738 (type `tag`) | OK |
| Tag dereference | 47ca59e | 47ca59e29f499d79deac21024ef93b5c7d711a05 | OK |
| Ancestry (first-parent) | 48f91565→6cf948e→e15ce28→7297bda→e40a6ef→47ca59e | identical | OK |
| Lock precedes inversions | 6cf948e < e15ce28 < 7297bda | confirmed by first-parent order | OK |
| R5 candidate recoverable | f30b3932 | f30b39322500da6e9e8602645e287cd41a61018e | OK |
| Methodology V7 anchor | e40a6ef | e40a6efb9a733030e7e65f309cf0c71bc38c178d | OK |
| Governing control-plane lock | 2c345b64 | gen8-ulu-evren-control-plane-r1-locked-governing^{commit} = 2c345b64c720f965b68ec5ee699e1b71fecf0003 | OK |
| Working tree | clean except untracked .planning/ | clean except .planning/ (+ add-only AUDIT20 artifacts) | OK |

No unauthorized force-push / rewrite observed; the candidate and all historical tag objects are
recoverable. **Custody is reproducible — not BLOCKED on custody.**

## 2. HISTORICAL EVIDENCE INTEGRITY (§2) — HOLDS

- **AUDIT19 verdict preserved:** `docs/audit/RWC_PRE14_R5_AUDIT_RESULT.json` = SHA-256
  `3a72cf046c325104aa79842dfe8f6a9bf7a7850fb8822f23bee79bf5191a1e17`, `verdict=FIX_REQUIRED`,
  critical=1 / high=2 / medium=2, `candidate_commit=f30b3932…`. The five findings are A19-F1 (CRITICAL
  reconcile backdoor + forged V1 token), A19-F2/F3 (HIGH self-mint root / registry replay), A19-F4/F5
  (MEDIUM receipt scalars / intendedUse parse).
- **Frozen originals recoverable + byte-identical:** `git show 48f91565:…AUDIT19_RWCPre14R5ReauditProbes.swift`
  SHA-256 = `b5232e52…`; `…RWCPreregistrationR5Tests.swift` = `be8db856…` — both match the lock's
  declared frozen-original hashes AND the `*_ORIGINAL_LOCKED.swift.txt` archives byte-for-byte. Active
  R6 versions hash to the declared post-edit values `53eb8e13…` / `cea19819…`.
- **Independent inversion recount:** the AUDITOR file (`AUDIT19_RWCPre14R5ReauditProbes.swift`) has
  **12 distinct changed test functions** (test_A19_01 custody re-anchor; 07,08 F2; 11,12,14,17 F3; 20,22
  F1; 21,24 F4; 23 F5) — every one declared in the lock's table; the test-function NAME set is identical
  (no additions/removals/renames). The BUILDER file (`RWCPreregistrationR5Tests.swift`) has exactly
  **2** declared changes (the R5 absence-pin flip + the V6 census re-pin). **No undeclared alteration.**
  - **Labeling flag (INFO, not a defect):** the inversion lock's prose says "thirteen functions change";
    the true count of changed test functions is **12** — the "13" double-counts the custody re-anchor
    (test_A19_01) as both "the one re-anchor" and a member of the twelve-row table. Every changed
    function is individually declared; this is a counting-label discrepancy, not a hidden edit.

## 3. V7 FREEZE CENSUS (§3) — REPRODUCED, NO FINDINGS

Independent census (`docs/audit/audit20_tools/audit20_v7_census.py`, own logic — not the builder
generator) over `RWC_PREREGISTRATION_FREEZE_MANIFEST_V7.yaml`:

| Check | Measured |
|---|---|
| Artifact count | **299** (= builder) |
| Unique paths / duplicates | 299 unique, 0 duplicates |
| Recomputed inventory digest | **`8a1751c397523d743fe77d9dd7c8de6a4a364bc625217fb123b18891f5619a57`** (= manifest field = builder claim) |
| Live sha256 drift (298 non-exempt) | none |
| Candidate-blob drift (`git show 47ca59e:<path>`) | none |
| Live-vs-candidate manifest blob (A18-F5) | identical (`56ec6d26…371ef`) |
| Surface set equality (4 governed roots × live + git-tree) | extra=0, missing=0 everywhere |
| Symlinks / path traversal | none |
| Anchor→candidate changed paths | exactly the V7 manifest (two-phase anchor law holds; no frozen source/test changed) |
| Negative tests (unauthorized add / byte tamper / digest sensitivity) | all flagged correctly |
| hash_exempt | V7 manifest + master manifest (manifest-sha trusted, not re-hashed — matches verifier) |

Inventory-digest algorithm read from `RWCCorpusEntryVerifierV3.inventoryDigest` and replicated exactly:
`sha256( sorted("<path>:<sha256>") joined by "\n" )` over all 299 entries (including exempt entries'
declared shas). The new auditor file `AUDIT20_RWCPre14R6ReauditProbes.swift` is lawfully covered by the
`AUDIT` post-audit allowance under `GuardianCoreTests` and does not break the freeze.

## 4. ATTACK-SURFACE GRAPH (public corpus-entry path)

Lawful path (builder intent):
`RWCReviewerTrustRootLoaderV2.loadProduction` (capability-gated, fail-closed) → governed current
registry `RWCReviewerRegistryCurrentnessStoreV1` + `RWCReviewerRegistryVerifierV2.verifyCurrent` →
`RWCRightsReviewAuthorityV6.verify` → `RWCVerifiedRightsGrantV6` → `RWCPreAcquisitionEvaluatorV3.authorize`
→ `RWCCorpusAcquisitionRunnerV4.acquire(proof: RWCVerifiedCorpusEntryV5, …)` → `RWCAssetRightsLedgerStoreV4`
(register + authorizeAcquisition) → PREPARED receipt → corpus promote → finalize.

Independent (attacker) path discovered: with a verified grant V6, a caller can skip the evaluator AND
the V5 proof and drive **`store.register` → `store.authorizeAcquisition`(fabricated scalars) →
`runner.reconcileV4`** directly (all `public`), reaching corpus promotion. The V5 PASS proof is required
only inside `acquire()`, which `reconcileV4` does not call and does not depend on.

## 5. AUDIT19 FINDINGS — INDEPENDENTLY ADJUDICATED

| AUDIT19 finding | R6 claim | AUDIT20 adjudication |
|---|---|---|
| A19-F1 CRITICAL (reconcile backdoor + forged V1 register) | closed by store V4 + reconcileV4 | **PARTIALLY CLOSED.** The forged-V1-token register is closed (V4.register requires a V6 grant) and reconcileV4 no longer trusts caller metadata/receipts. BUT the authorization record is written from free-form PRE-14 scalars, not a V5 proof → **new A20-F1 CRITICAL** (§6) re-opens a PRE-14-PASS bypass on the same reconcile gate. |
| A19-F2 HIGH (public self-mint root) | closed by loader V2 (no public mint) | **CLOSED for V2/V6.** loadProduction fails closed before any file read; mint/factory/capability inits are internal/fileprivate; verified types fileprivate-init. Ordinary consumer cannot mint a V2 root or V6 grant. **Caveat:** the superseded **V1** loader `RWCReviewerTrustRootLoaderV1.mint(fromJSON:)` is still `public` and signature-free (A20-F2 HIGH, §6). |
| A19-F3 HIGH (registry replay / revoked resurrection) | closed by currentness store + verifyCurrent | **CLOSED at verifyCurrent** (rev>1 w/ nil-previous refused; stale/rolled-back digest refused; empty witness fails closed). **Gaps:** (a) the grant, once minted, is not re-checked against the CURRENT registry at register/authorize time → A20-P2 stale-grant (A20-F4 MEDIUM, §6); (b) whole-directory disk rollback is accepted (documented R-5 hostile-disk class). |
| A19-F4 MEDIUM (receipt scalar laziness) | closed by receipt store V2 strict scalars | **CLOSED on the receipt store** (strict hex64 / enum laws observed). Does not address the ledger authorization scalars (A20-F1). |
| A19-F5 MEDIUM (intendedUse silent default) | closed by strict typed parse | **CLOSED on the receipt store parse.** But direct `store.authorizeAcquisition` still records a use the grant prohibits (A20-F3 MEDIUM, §6) — use enforcement lives only in the evaluator, which the direct path skips. |

## 6. FRESH FINDINGS (§9 item 9)

### A20-F1 — CRITICAL — PRE-14 PASS gate bypass via direct public authorize+reconcile
- **File/line:** `packages/GuardianKit/Sources/GuardianCore/RWCRightsV6Store.swift:439-476`
  (`authorizeAcquisition` takes `candidateCommit: String, auditResultBlobSHA256: String` scalars, never a
  `RWCVerifiedCorpusEntryV5`); `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV4.swift:155-248`
  (`reconcileV4` promotes any session with a matching ledger authorization record; it never consults a V5
  PASS proof). The V5 proof is consumed ONLY in `acquire()` (`:77,115-116`).
- **Exploit:** `test_A20_P1_01_DirectAuthorizeReconcile_Promotes_WithoutV5PassProof` (PASSES = promotion
  occurs). With a legitimately-minted V6 grant: `register` → `authorizeAcquisition(sessionID, …,
  candidateCommit:"deadbeef…", auditResultBlobSHA256:"ffff…")` (fabricated — no PASS lock/result exists,
  and none can without AUDIT20 itself) → hand-built quarantine dir → `reconcileV4` → asset promoted into
  the corpus store.
- **Consequence:** a verified RIGHTS grant (licensing authority) is made sufficient to enter the corpus
  without the independent PRE-14 statistical/methodology PASS gate. The two authorities are orthogonal;
  the builder's own `RWCRightsV6Store.swift:21-23` comment claims writing the authorization "requires
  BOTH an RWCVerifiedRightsGrantV6 AND an RWCVerifiedCorpusEntryV5 PASS proof" — the code does not: it
  requires the grant plus free-form strings. The builder concedes the scalar design in
  `RWC_PREREGISTRATION_R6_SECURITY_DESIGN.md` residual **R-3** ("values not the proof object… low;
  defense rests on the RunnerV4 boundary"). AUDIT20 rejects "low": any caller can reach the ledger gate
  without the RunnerV4 boundary.
- **Exploitability separation (§4/§11):** TODAY, no ordinary consumer can obtain a V6 grant (production
  trust-root is fail-closed; onboarding absent) → not end-to-end exploitable in the shipped artifact today.
  POST-ONBOARDING, a legitimately onboarded reviewer (whose authority is rights-only) can promote corpus
  assets bypassing PRE-14 PASS. Per §11 this CRITICAL is **not demoted** because the first asset is blocked
  by missing onboarding.
- **Minimum R7 remediation:** make `authorizeAcquisition` require a `RWCVerifiedCorpusEntryV5` (not scalars)
  and/or have `reconcileV4` refuse promotion unless the session's authorization is bound to a verified V5
  PASS proof for the current candidate; extract `candidateCommit`/`auditResultBlobSHA256` from the proof,
  never from caller strings. (Do NOT implement in this audit.)

### A20-F2 — HIGH — legacy public signature-free root self-mint still reachable
- **File/line:** `packages/GuardianKit/Sources/GuardianCore/RWCRightsV5.swift:160`
  `public static func mint(fromJSON:)` on `RWCReviewerTrustRootLoaderV1` — validates only
  token/algorithm/ACTIVE/key-format, **no signature**; plus `RWCRightsReviewAuthorityV1.verify`
  (`RWCRightsV3.swift:300`, public, mints a no-crypto V1 grant), `RWCAssetRightsLedgerStoreV3.register`
  (public, accepts the V1 grant), `RWCCorpusAcquisitionRunnerV3.reconcileV3`
  (`RWCCorpusAcquisitionRunnerV3.swift:258`, public, still the forgeable-metadata backdoor).
- **Exploit/consequence:** the A19-F2/F1 root causes were fixed by adding a closed V2/V6 surface *beside*
  the still-public V1/V3 surface, not by sealing V1/V3. An ordinary external consumer can still self-mint a
  verified **V1** root from attacker JSON and compose the entire V1→V3 legacy chain. `RWCCorpusStoreV1` is a
  protocol with **no concrete production conformer** and there is **no executable/ingress** wiring in
  `Sources/`, so this is **not end-to-end exploitable today**; it becomes directly exploitable the moment
  any real corpus store or production ingress is wired. "Not called by RunnerV4" ≠ "unreachable."
- **Minimum R7 remediation:** demote the legacy V1/V3 public mint/register/reconcile surfaces to
  `internal`/`@available(*, unavailable)` (or gate behind the same capability), and extend the
  ordinary-consumer proof package to assert the V1 `mint` is unreachable.

### A20-F3 — MEDIUM — intended-use not enforced at the direct ledger authorization gate
- **File/line:** `RWCRightsV6Store.swift:440-476` — `authorizeAcquisition` records `intendedUse` verbatim
  and never checks it against the grant's `allowedUse`/`prohibitedUse`. Use enforcement lives only in
  `RWCPreAcquisitionEvaluatorV3.authorize` (`RWCRightsV6.swift:650-654`), which the direct path skips.
- **Exploit:** `test_A20_P3_01_DirectAuthorize_ProhibitedUse_SkipsEvaluator` (PASSES): a grant allowing
  only `evaluation` yields an authorization recording `intendedUse="training"`.
- **Consequence:** the ledger authority marker can assert a use the grant forbids; combined with A20-F1
  this promotes an asset for a prohibited use. (Source mismatch IS refused —
  `test_A20_P3_02` control — because the record-binding check catches a different `sourceReference`.)
- **Minimum R7 remediation:** validate `intendedUse` against the grant's use lists inside
  `authorizeAcquisition` (mirror the evaluator), or require the evaluator's `RWCPreAcquisitionAuthorizationV3`
  as input.

### A20-F4 — MEDIUM — stale grant after reviewer revocation still registers/authorizes
- **File/line:** `RWCRightsV6Store.swift:357-374` (`register`) and `:440-476` (`authorizeAcquisition`) bind
  to `verifiedGrant.registryDocumentDigest` captured at mint time; neither re-consults the CURRENT
  `RWCReviewerRegistryCurrentnessStoreV1`.
- **Exploit:** `test_A20_P2_01_StaleGrant_AfterReviewerRevoked_StillRegistersAndAuthorizes` (PASSES): mint a
  V6 grant under rev1 ACTIVE reviewer; advance the governed registry to rev2 REVOKING the reviewer; the old
  grant still registers and authorizes, with the authorization bound to the stale rev1 digest.
- **Consequence:** revocation of a reviewer is not effective against grants already minted — there is no
  current-authority recheck at acquisition time. Policy for revocation-effective-time is not documented;
  a defensible policy is "current reviewer authority required at acquisition time," which the implementation
  does not enforce.
- **Minimum R7 remediation:** at register/authorize, require the caller to present the CURRENT verified
  registry and refuse if the grant's reviewer is not ACTIVE in it (or if the grant's registryDocumentDigest
  != current head), under an explicit written revocation-effective-time policy.

## 7. R-5 / R-6 RESIDUAL-RISK OUTCOMES (§6)

- **R-5 (hostile ledger-disk writes):** `test_A20_R5_01_HostileLedgerDiskForgery_AuthorizationAcceptedAfterReopen`
  (PASSES): a hostile writer with directory write access hand-authors an `acquisition-authorized` journal
  event + matching witness (recomputing the user-writable SHA-256 chain); on reopen the forged
  authorization is accepted (`authorizationRecord(forSession:)` returns it). This is exactly the builder's
  documented R-5 residual: "unforgeable THROUGH THE API, detectable-not-unforgeable ON DISK." **Adjudication:**
  ACCEPTED as a correctly-documented residual *provided* the deployment threat model excludes hostile local
  disk writers (same class as R-1). The "unforgeable, ledger-resident authorization" phrase must not be
  marketed as comprehensive corpus-authorization security; the report language is honest and must remain so.
- **R-6 (authorize→receipt crash gap):** `test_A20_R6_01_CrashBeforeReceipt_PromotesWithNoDurableReceipt`
  (PASSES): a crash after the ledger authorization but before any PREPARED receipt → `reconcileV4` promotes
  the asset (ledger record is the durable authority) but **no durable receipt is ever created**, and the
  reconciliation report does not surface a per-session receipt deficit for the recovered session.
  **Adjudication:** the promotion is authorized and not duplicated, so this is not an escalation; but it is
  a genuine **completeness-law gap** — an asset can be promoted with no completion receipt. The builder
  rates this "low, documented." Against the corpus-completion law (A18-F3 history) this should be an
  explicit reported deficit, not merely a builder-preferred omission. Folded into A20-F1's remediation
  scope (receipt-deficit report field / authorization-record extension) rather than counted as a separate
  numeric finding; recorded here so the completion rule is not quietly weakened.

## 8. R6 RESULT-PATH / VERIFIER COMPATIBILITY (§7) — RELEASE/AUTHORIZATION INTEGRATION BLOCKER

- **File/line:** `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV5.swift:56`
  (`RWCPre14AuditResultV3.canonicalPath = docs/audit/RWC_PRE14_R5_AUDIT_RESULT.json`), `:198`
  (`canonicalFreezeManifestPath = …FREEZE_MANIFEST_V6.yaml`), `:354` (`freezeVersion ==
  "rwc-preregistration-freeze-v6"`), `:264` (`lock.auditResultPath == R5 canonicalPath` or
  `nonCanonicalAuditResultPath`).
- **Probes:** `test_A20_P7_01_VerifierV5_PinnedToR5Path_And_V6Manifest` (asserts the compiled constants) and
  `test_A20_P7_02_VerifierV5_RefusesR6ResultPathLock` (a synthetic PASS lock pointing at
  `docs/audit/RWC_PRE14_R6_AUDIT_RESULT.json` + the V7 manifest is refused). Both PASS.
- **Consequence:** the R6 candidate freezes at **V7**, and the planned R6 result path is
  `docs/audit/RWC_PRE14_R6_AUDIT_RESULT.json`. The compiled production verifier can consume **neither**:
  it reads only the R5 result path and accepts only the V6 manifest / `rwc-preregistration-freeze-v6`. A
  future R6 PASS cannot be consumed without an unlawful R5-path/R5-manifest fallback. Sharing schema
  version "v3" does NOT make the R5 and R6 canonical result paths equivalent.
- **Required lawful versioning:** a new `RWCCorpusEntryVerifierV6` bound to the R6 result path + V7 manifest
  (`rwc-preregistration-freeze-v7`) and a schema **V4** (R6-path canonical instance) must be lawfully
  introduced, independently audited, before any R6 PASS lock could carry release authority. **Treated as a
  release/authorization integration blocker until resolved** (§7). Do NOT mutate the locked V5 source or
  falsify an R5 result.

## 9. §10 AUDIT-RESULT AUTHORITY — SCHEMA V3 CONTRADICTION AND R6 CONTRACT

`docs/calibration/preregistration/RWC_PRE14_AUDIT_RESULT_SCHEMA_V3.yaml` is **R5-path-specific**:
`canonical_instance_path = docs/audit/RWC_PRE14_R5_AUDIT_RESULT.json`; `freeze_manifest_path` "must equal
the canonical …FREEZE_MANIFEST_V6.yaml path"; `candidate_freeze_blob_law` and `pass_law` both bind the
**V6** manifest. Schema V3 therefore **cannot lawfully describe an R6 result** (R6 result path + V7
manifest) without violating its own canonical-path / freeze-blob laws. Per §10 this contradiction is
documented here rather than silently reinterpreting the R5 path as R6.

**R6 authority contract used for the machine result:** the AUDIT20 machine result
`docs/audit/RWC_PRE14_R6_AUDIT_RESULT.json` is created under an **explicitly declared R6 authority
contract** `result_version: rwc-pre14-r6-audit-result-v3-r6` — a NON-RELEASE, R6-bound audit record that
(a) is NOT the frozen schema-V3 instance consumed by `RWCCorpusEntryVerifierV5` (which reads only the R5
path), (b) binds the R6 V7 manifest + R6 result path, and (c) carries an explicit deviation note that a
lawful schema V4 + verifier V6 are required before any R6 PASS could carry release authority. The verdict
is `FIX_REQUIRED`, so no PASS authority is claimed or implied; no PASS lock is created.

## 10. TEST EVIDENCE (§9) — GENUINE, MEASURED

- Toolchain: Apple Swift 6.3.3; Target arm64-apple-macosx26.0; Python 3.9.
- **Baseline (clean candidate, before any fresh probe / result):** serial
  `Executed 1125 tests, with 11 tests skipped and 0 failures (0 unexpected) in 515.292 s`; parallel run
  1125 tests, 0 failures — consistent.
- **Fresh AUDIT20 family:** `Executed 11 tests, with 0 failures` (all 11 probes reach their intended
  branch and the measured behavior matches the adversarial assertions — confirmed by first running with
  deliberately-malformed session IDs which produced real `malformedSessionID` refusals, then correcting
  the fixtures so the probes reach the ledger/reconcile branches).
- **Full suite WITH fresh probes (pre-result):** serial
  `Executed 1136 tests, with 11 tests skipped and 0 failures (0 unexpected) in 561.937 s`; parallel 1136
  tests, 0 failures — consistent. Honest total = baseline 1125 + fresh 11 = **1136**.
- **Skips (11, enumerated, non-security):** AUDIT16 derivation/stat-replication (×4), AUDIT17 heavy stat
  replication (×1), RWCPowerDerivationV3 (×3) and V4 (×3) runners — all env/flag-gated benchmark/power
  runners (GEN8_AUDIT16_STAT, GEN8_AUDIT17_STATS, etc.). None is a security test; none silently skipped.
- Commands and logs: `docs/audit/audit20_tools/audit20_command_log.md`; raw logs under /tmp
  (`audit20_baseline_serial.log`, `a20_probes2.log`, `a20_full_serial.log`, `a20_full_parallel.log`).

## 11. ZERO-DATA & NO-PASS-LOCK STATUS (§11, §14) — INTACT

- `docs/audit/RWC_PRE14_PASS_LOCK.yaml` — ABSENT (no PASS lock created).
- `docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json` — ABSENT (no operational reviewer root fabricated).
- Master manifest: `data_visibility=false`, `corpus_count=annotator_count=real_fit_count=heldout_open_count=0`.
- No real corpus / annotators / model fitting / held-out opening; ECE 0.250 UNMET; Presentation/Glyph/Motion
  blocked. All non-negotiable gates preserved. The AUDIT20 machine result is created with verdict
  FIX_REQUIRED only (never a PASS).

## 12. IS R6 AUDITABLE? DID IT PASS? IS FIRST-ASSET AUTH STILL BLOCKED?

- **Auditable:** YES — custody reproducible, freeze census reproduces exactly, toolchain builds, 1125
  baseline tests green, source is readable and the authority graph reconstructable.
- **Passed:** NO — one CRITICAL (PRE-14 PASS bypass), one HIGH (legacy public self-mint), two MEDIUM
  (use-not-enforced, stale-grant), plus the §7 verifier/schema integration blocker.
- **First-asset authorization:** STILL BLOCKED — no operational reviewer root, no PASS lock, no
  R6-compatible release verifier; zero-data intact.

## 13. EXACT NEXT PERMITTED ENGINEERING ACTION

Open **R7** to (1) bind the ledger acquisition authorization to a verified `RWCVerifiedCorpusEntryV5` PASS
proof (A20-F1) and surface the R-6 receipt deficit; (2) seal the legacy V1/V3 public mint/register/reconcile
surfaces (A20-F2); (3) enforce intended-use at `authorizeAcquisition` (A20-F3); (4) add a current-registry
authority recheck at acquisition time under a written revocation-effective-time policy (A20-F4); and (5)
lawfully introduce `RWCCorpusEntryVerifierV6` + audit-result schema **V4** for the R6 result path + V7
manifest (§7 blocker). No PASS lock, no operational reviewer-root fabrication, no corpus/data operations
until a subsequent independent audit returns PASS on the R7 candidate. Presentation/Glyph/Motion remain
blocked; ECE 0.250 remains UNMET.

---

**Independent-auditor declaration.** This audit was conducted from a fresh, independent context. The
builder's conclusions were treated as hypotheses to falsify. All findings are reproduced by preserved
adversarial tests in `AUDIT20_RWCPre14R6ReauditProbes.swift` (family `AUDIT20_RWC_PRE14_R6_REAUDIT`). No
production implementation was modified; no fix was implemented; no PASS lock or operational root was
created. UNKNOWN was preferred to fabricated certainty. The verdict is **FIX_REQUIRED**.
