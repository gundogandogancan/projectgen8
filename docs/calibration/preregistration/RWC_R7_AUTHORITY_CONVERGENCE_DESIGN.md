# RWC R7 — AUTHORITY CONVERGENCE DECISION (§2 FIRST DELIVERABLE)

Date: 2026-10-24 (pre-data; zero corpus/annotator/fit/heldout; NO PASS lock; NO operational reviewer
trust root — and NONE is invented in R7). Branch `phase/rwc-preregistration-r7`; base candidate
`47ca59e29f499d79deac21024ef93b5c7d711a05`; AUDIT20 commit (HEAD) `5185101…`.

This design record is produced **before** any fix is implemented (mandate §2) and before the
inversion/supersession lock content is finalised. It governs R7-02 … R7-06. It is authoritative; the
implementation must not deviate without amending this record.

Toolchain confirmed: Apple Swift 6.3.3 / `swift-tools-version:5.9` → the `package` access level is
available for cross-target sealing inside the GuardianKit package.

---

## 0. The fundamental invariant (restated)

> **NO VERIFIED METHODOLOGY AUTHORITY + NO CURRENT RIGHTS AUTHORITY + NO DURABLE TRANSACTION EVIDENCE
> = NO CORPUS PROMOTION.**

Holds across initial acquisition, direct public calls, restart, recovery, migration and legacy-API
composition. R7 must make the **negation structurally impossible for an ordinary consumer**, not merely
caught by one more runtime check.

---

## 1. AUDIT20 common cause (one sentence)

`RWCAssetRightsLedgerStoreV4.authorizeAcquisition` (GuardianCore, `RWCRightsV6Store.swift:439-476`) —
the **sole writer** of the ledger-resident `RWCAcquisitionAuthorizationRecordV1` that `reconcileV4`
trusts to promote — accepts **caller-controlled scalars** (`candidateCommit`,
`auditResultBlobSHA256`, `intendedUse`, `sourceReference`) plus a **rights-only**
`RWCVerifiedRightsGrantV6`, and validates **none** of: (F1) methodology-PASS proof identity, (F3)
intended-use against the grant, (F4) **current** registry authority. Because the methodology-PASS proof
type `RWCVerifiedCorpusEntryV5` lives in the **RWCAcquisition** module and **GuardianCore cannot import
RWCAcquisition** (acyclic: `RWCAcquisition → GuardianCore`), the write gate structurally *could not*
require the proof. That module boundary is the real reason the scalar shortcut exists — and the thing
R7 must solve without creating a cycle.

A20-F2 (legacy V1/V3 public mint/register/reconcile surface) is a *parallel* bypass: the R6 fix added a
closed V2/V6/V4 surface **beside** the still-`public` V1/V3 surface rather than sealing it.

R-6 (crash authorize→receipt gap) and A20-F1 share a cause: the authorization record did **not** carry
the full PASS-proof identity, so a crashed session could be promoted but its durable receipt could
neither be reconstructed nor reported as deficient.

---

## 2. Trust boundaries and the seven state components (§2)

| # | Authority | Owning module | Unforgeable proof type (mint path) | R7 status |
|---|---|---|---|---|
| 1 | Verified methodology authority (PRE-14 PASS) | RWCAcquisition | `RWCVerifiedCorpusEntryV5` → **V6** (`RWCCorpusEntryVerifierV6.verify`, `fileprivate` init) | VERSIONED (new V6/schema V4) |
| 2 | Verified reviewer/root authority | GuardianCore | `RWCVerifiedReviewerTrustRootV2` (`fileprivate` init; capability-gated loader; no public mint) | carried CLEAN (A19-F2 closed) |
| 3 | Current registry + revocation authority | GuardianCore | `RWCVerifiedReviewerRegistryV2` + `RWCReviewerRegistryCurrentnessStoreV1` head witness | reused + **enforced at authorize** (A20-F4) |
| 4 | Source + intended-use authorization | GuardianCore | `RWCPreAcquisitionAuthorizationV3` (`fileprivate` init; evaluator V3) | reused + **enforced at the final gate** (A20-F3) |
| 5 | Durable acquisition authorization (ledger write) | GuardianCore | `RWCAcquisitionAuthorizationRecordV1` (write gated by a **new capability token**) | **re-gated** (A20-F1) |
| 6 | Durable receipt + crash recovery | RWCAcquisition | `RWCAcquisitionReceiptStoreV2` + explicit transaction state machine | **state machine + deficit report** (R-6) |
| 7 | Corpus promotion | RWCAcquisition | `RWCCorpusStoreV1.promote`, reached ONLY via `RWCCorpusAcquisitionRunnerV5.acquire`/`reconcileV5` | **single coordinator** |

---

## 3. Every path that can reach `RWCCorpusStoreV1.promote` — before vs after

### 3.1 BEFORE R7 (as audited)

```
LAWFUL (intended):
  TrustRootV2(cap-gated) → RegistryVerifierV2.verifyCurrent → AuthorityV6.verify → VerifiedGrantV6
    → PreAcquisitionEvaluatorV3.authorize → RunnerV4.acquire(proof: VerifiedCorpusEntryV5, grant)
    → store.register(grant) → store.authorizeAcquisition(grant, SCALARS) → receipt.prepare → promote → finalize

BYPASS #1 (A20-F1 CRITICAL):  [public, no V5 proof, no evaluator]
  VerifiedGrantV6 → store.register → store.authorizeAcquisition(grant, FABRICATED scalars)
    → hand-built quarantine → RunnerV4.reconcileV4 → promote           ← PROMOTES

BYPASS #2 (A20-F2 HIGH):      [public legacy chain, external consumer]
  RWCReviewerTrustRootLoaderV1.mint(fromJSON:) → RWCRightsReviewAuthorityV1.verify (V1 grant)
    → RWCAssetRightsLedgerStoreV3.register → RunnerV3.reconcileV3                 ← composable

BYPASS #3 (A20-F3 MEDIUM):    intendedUse recorded verbatim, never checked vs grant.allowedUse
BYPASS #4 (A20-F4 MEDIUM):    grant minted under rev1 still authorizes after rev2 revocation
```

`promote` is `RWCCorpusStoreV1.promote` — a **public protocol requirement**; any conformer is a direct
promote surface. Today there is **no concrete production conformer** and **no ingress** in `Sources/`
(so none of the above is end-to-end exploitable in the shipped artifact *today*), but the structural
bypasses are real the moment a store/ingress is wired. R7 fixes them structurally regardless.

### 3.2 AFTER R7 (target)

```
THE ONLY LAWFUL PATH (single coordinator = RWCCorpusAcquisitionRunnerV5 in RWCAcquisition):
  TrustRootV2(cap-gated) → RegistryVerifierV2.verifyCurrent(currentness) → AuthorityV6.verify → VerifiedGrantV6
    → PreAcquisitionEvaluatorV3.authorize  (source + intended-use)                          [component 4]
    → CorpusEntryVerifierV6.verify(repoRoot) → VerifiedCorpusEntryV6 (PRE-14 PASS proof)     [component 1]
    → RunnerV5 MINTS  RWCAcquisitionAuthorityTokenV1   (package-init, RWCAcquisition only)   [component 5 gate]
         carrying: {proof identity (candidate/tag/audit/anchor/freeze/inventory),
                    evaluator-validated intendedUse + sourceReference + asset/grant identity,
                    current-registry witness head (root,rev,digest)}
    → store.authorizeAcquisitionV2(token, verifiedGrant, currentRegistryWitness, clock)      [component 5]
         • REQUIRES the token (no scalars accepted)
         • re-checks the grant's reviewer is ACTIVE in the CURRENT head + digest == head      (A20-F4)
         • re-checks intendedUse ∈ grant.allowedUse, ∉ grant.prohibitedUse                    (A20-F3)
         • copies candidate/audit/anchor/freeze/inventory FROM the token into the record      (A20-F1)
    → receipt.prepare(authorization=record, …proof scalars FROM the record) → promote → finalize

reconcileV5 (recovery): promotes ONLY sessions whose ledger-resident authorization record exists AND
  carries a NON-EMPTY proof identity (candidate+auditBlob+tagObj+anchor+freeze+inventory). If the
  durable receipt is absent, it RECONSTRUCTS a PREPARED→COMPLETED receipt from the authenticated
  authorization record (component 5) — or, if any proof field is missing, keeps the session UNPROMOTED
  and reports an explicit per-session receipt/authorization DEFICIT (R-6). Never silent promotion.
```

No external consumer can mint `RWCAcquisitionAuthorityTokenV1` (its init is `package`), so
`store.authorizeAcquisitionV2` cannot be driven by a direct caller; the scalar `authorizeAcquisition`
is **removed from the public surface** (sealed to `package`, and additionally requires the token — see
§5). Legacy V1/V3 surfaces are sealed to `package` (§6). The single coordinator is `RunnerV5`.

---

## 4. The chosen architecture (Option A refined) and why it is strongest + simplest

The mandate offers Option A (coordinator consumes an opaque verified release proof; low-level ledger
mutation restricted to package/internal) and Option B (narrowly scoped independently-verified authority
capability minted at a cryptographically grounded boundary). **R7 chooses a fusion that is strictly
Option A in structure with Option B's capability discipline**, because the module layout forces it:

- **Why not "require `RWCVerifiedCorpusEntryV5` directly in `authorizeAcquisition`":** impossible without
  a module cycle — the proof type is in RWCAcquisition; the store is in GuardianCore; GuardianCore must
  not import RWCAcquisition (mandate §2 "GuardianCore cannot import RWCAcquisition"; "do not resolve the
  cycle by making proof constructors public").
- **Why the capability token works:** `RWCAcquisitionAuthorityTokenV1` is declared in **GuardianCore**
  (so the store can name it in the write signature) but its initialiser is **`package`**. In Swift
  `package` access, only code in the *same SwiftPM package* can call the init. The GuardianKit package
  contains `GuardianCore`, `RWCAcquisition`, and the test targets — **not** any external SwiftPM
  consumer. We additionally restrict minting *by discipline + code location* to exactly one function:
  `RWCCorpusAcquisitionRunnerV5.mintAuthorityToken(...)` (in RWCAcquisition), which runs only after
  (a) `RWCCorpusEntryVerifierV6.verify` returns a `RWCVerifiedCorpusEntryV6` PASS proof,
  (b) `RWCPreAcquisitionEvaluatorV3.authorize` returns a `RWCPreAcquisitionAuthorizationV3`, and
  (c) a current-registry currentness recheck passes. The token therefore *is* the structured proof the
  mandate demands — **not** a free-form scalar, SHA string, or JSON digest.
- **Why it is simplest:** it reuses every existing proven component (trust root V2, currentness store,
  registry verifier V2, authority V6, evaluator V3, receipt store V2, the V3-core verifier plumbing). It
  adds exactly **one** new value type (`RWCAcquisitionAuthorityTokenV1`), **one** new verifier
  (`RWCCorpusEntryVerifierV6` + its proof `RWCVerifiedCorpusEntryV6`), **one** new coordinator
  (`RunnerV5`) and **one** new sealed writer (`authorizeAcquisitionV2`). No proliferation of redundant
  validators; the four findings close at **one** boundary (component 5), not four.
- **Identity across restarts:** the token itself is ephemeral (process-local), but the facts it carries
  are written **durably** into the ledger-resident `RWCAcquisitionAuthorizationRecordV1` (append-only,
  flock-single-writer, SHA-256-chained journal). After a restart, `reconcileV5` re-reads the record; the
  authority identity is preserved by the **durable record**, re-validated against the live rights record
  and (where the current registry is available) the current head. The token is never persisted and never
  needs to be.

**A valid rights grant is never by itself a methodology PASS:** the token can be minted only when BOTH a
`RWCVerifiedRightsGrantV6` (rights authority) AND a `RWCVerifiedCorpusEntryV6` (methodology PASS) exist,
AND the evaluator authorised the source+use, AND the current registry still lists the reviewer ACTIVE.
Missing any one ⇒ no token ⇒ no authorization record ⇒ no promotion.

---

## 5. Component 5 — the sealed ledger write (A20-F1 / F3 / F4 + R-6 carrier)

New type in GuardianCore (`RWCRightsV7Store.swift`, NEW file — supersession not mutation of the frozen
V7 store file where avoidable; see §9):

```
public struct RWCAcquisitionAuthorityTokenV1: Sendable {
    // proof identity (from RWCVerifiedCorpusEntryV6)
    public let candidateCommit, candidateTagObjectSHA, auditCommit, auditResultBlobSHA256,
               methodologyAnchorCommit, freezeManifestSHA256, frozenInventoryDigest: String
    // evaluator-validated acquisition facts (from RWCPreAcquisitionAuthorizationV3)
    public let assetID, sourceReference, intendedUseToken: String   // "training" | "evaluation"
    public let grantID: String; public let grantRevision: Int
    public let sessionID: String
    // current-registry witness captured at mint time (A20-F4)
    public let currentRegistryRootID: String; public let currentRegistryRevision: Int
    public let currentRegistryDocumentDigest: String
    package init(...)      // ONLY GuardianKit-package code can mint; disciplined to RunnerV5
}
```

New writer on the R7 ledger store (`RWCAssetRightsLedgerStoreV5`, NEW file superseding V4 BY RECORD —
V4 stays byte-frozen; see §9 for why a new store rather than mutating V4):

```
public func authorizeAcquisitionV2(token: RWCAcquisitionAuthorityTokenV1,
                                    verifiedGrant: RWCVerifiedRightsGrantV6,
                                    currentRegistry: RWCVerifiedReviewerRegistryV2,     // A20-F4 witness
                                    clock: RWCRightsClockV3) throws -> RWCAcquisitionAuthorizationRecordV2
```

Enforced at this single gate (all fail-closed, typed refusals):
1. **A20-F1** — identity is taken from `token`, never from caller scalars; the asset must have a live
   rights record bound to `verifiedGrant`; token.sessionID/assetID/grant identity must match.
2. **A20-F3** — `token.intendedUseToken` **must** be ∈ `verifiedGrant.grant.allowedUse` and ∉
   `prohibitedUse`; else `.useNotAuthorized`. (Mirrors the evaluator so the gate holds even if the
   evaluator were skipped — but the token can only exist via the evaluator anyway: belt + suspenders.)
3. **A20-F4** — `currentRegistry` (the verified CURRENT head, produced by `verifyCurrent`) must list the
   grant's `reviewerID` with status `ACTIVE`, and `currentRegistry.documentDigest` must equal
   `verifiedGrant.registryDocumentDigest` **and** `token.currentRegistryDocumentDigest`; a grant minted
   under a now-superseded revision is refused `.reviewerNotCurrent`. Missing/empty currentness ⇒
   fail-closed.
4. The written `RWCAcquisitionAuthorizationRecordV2` carries the **full proof identity**
   (candidate/tag/audit/anchor/freeze/inventory) so recovery can reconstruct a durable receipt (R-6).

The legacy scalar `authorizeAcquisition` on store V4 is **sealed to `package`** (declared in the lock)
so `@testable`/in-package historical tests keep compiling, while no external consumer can call it; the
R7 lawful path never calls it.

---

## 6. A20-F2 — legacy surface sealing (lawful freeze supersession)

Sealing mechanism = **access-control demotion `public → package`** (NOT `@available(*,unavailable)`),
because (measured) the dangerous legacy symbols are referenced by ~8 historical test files
(AUDIT17/18/19, R3/R4/R5 tests). `package` keeps every in-package caller (production wiring + ALL test
targets, whether `@testable` or plain `import`) compiling **unchanged**, while removing the symbol from
the compiled library's **external** API — an ordinary SwiftPM consumer can no longer name it. This is
the mandate's preferred "sealing mechanism that keeps test-target access so historical probes keep
compiling," so **A20-F2 requires ZERO historical-test inversions.**

Symbols demoted `public → package` (each in the V7 freeze inventory → declared in the lock, §9):

| Symbol | File | Why dangerous |
|---|---|---|
| `RWCReviewerTrustRootLoaderV1.mint(fromJSON:)` | `RWCRightsV5.swift:160` | signature-free root self-mint |
| `RWCReviewerTrustRootLoaderV1.loadProduction` | `RWCRightsV5.swift:150` | reaches `mint` from a caller-chosen dir |
| `RWCRightsReviewAuthorityV1.verify` | `RWCRightsV3.swift:300` | mints a no-crypto `RWCVerifiedRightsGrantV1` |
| `RWCReviewerRegistryVerifierV1.verify` | `RWCRightsV5.swift:324` | standalone/stale registry acceptance |
| `RWCAssetRightsLedgerStoreV3.register` | `RWCRightsV3.swift` | accepts the V1 grant token |
| `RWCCorpusAcquisitionRunnerV3.reconcileV3` | `RWCCorpusAcquisitionRunnerV3.swift` | forgeable-metadata promotion backdoor |

**Kept accessible (NOT dangerous, reused widely):** `RWCRightsReviewAuthorityV1.validateGrant`,
`.knownUses`, `.isToken`, `.isLowercaseHex64` (pure grammar validators, called across production and
tests; `isToken`/`isLowercaseHex64` are already non-public). `RWCAssetRightsLedgerStoreV3.create` /
`.openExisting` / `.journalName` / `.witnessName` / `.lockName` / `.version` are durability-store
historical ABI pinned by AUDIT17/18 crash-recovery probes — these are **not** the dangerous mint/promote
path; they stay `package` too (demote the whole legacy store type surface to `package` uniformly so no
external consumer can even construct the legacy store, while every in-package historical probe keeps
compiling). `RWCVerifiedRightsGrantV1`/`V3` inits are already `fileprivate` (sealing `.verify` fully
seals V1/V3 grant minting).

**Compile-negative proof:** new ordinary-consumer package `docs/audit/audit20_tools/a20consumer_r7/`
(pattern: `a19consumer_r6`) — a non-`@testable` executable depending only on the `GuardianCore` product,
asserting at runtime that `loadProduction` fails closed, and documenting (as must-not-compile commented
lines) that `mint(fromJSON:)`, `RWCRightsReviewAuthorityV1.verify`, `RWCReviewerRegistryVerifierV1.verify`,
`RWCAssetRightsLedgerStoreV3.register`/`.create`, and `RWCAcquisitionAuthorityTokenV1(init)` are
unreachable (`package`/`fileprivate`). RWCAcquisition legacy (`reconcileV3`) is proven unreachable the
same way via a second consumer importing the (non-exported-dangerous) surface.

---

## 7. Component 1 — verifier V6 + schema V4 (§7 release/authorization integration blocker)

`RWCCorpusEntryVerifierV5` is pinned to the **R5** result path + **V6** manifest + `freeze-v6`
(`RWCCorpusEntryVerifierV5.swift:56,198,354`). It stays byte-frozen SUPERSEDED_ENGINEERING_HISTORY.

New files (NOT mutation):
- Schema: `docs/calibration/preregistration/RWC_PRE14_AUDIT_RESULT_SCHEMA_V4.yaml` — `schema_version:
  rwc-pre14-audit-result-v4`; `canonical_instance_path:
  docs/audit/RWC_PRE14_R7_AUDIT_RESULT.json`; `freeze_manifest_path` must equal
  `RWC_PREREGISTRATION_FREEZE_MANIFEST_V8.yaml`; `freeze_version: rwc-preregistration-freeze-v8`; all
  V3 strict count laws + A18-F5 candidate-freeze-blob law + A18-F4 tag-name cross-check carried verbatim.
- Source: `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV6.swift` — binds the
  **R7** canonical result path + **V8** manifest + `freeze-v8`; otherwise structurally identical to V5
  (reuses the V3-core plumbing). Mints `RWCVerifiedCorpusEntryV6` (`fileprivate` init).

The verifier V6 **must** reject (typed): AUDIT19 FIX_REQUIRED, AUDIT20 FIX_REQUIRED, a schema-V3 result
disguised as V4, a correct-looking result under the wrong path, a PASS-looking JSON unsupported by git
history, mismatched tag object / freeze blob, an uncommitted result, a result missing authority
evidence, a result from an unrelated candidate, and any legacy fallback to the V5 verifier.

**NO real PASS result or PASS lock is created in R7.** Verifying the real repo fails closed with
`lockMissing`. Synthetic positive + adversarial-negative verifier tests prove the contract. The real
candidate remains release-blocked until a separate independent audit + lawful closeout.

Freeze: **V8** — new generator `tools/generate_freeze_manifest_v8.py`; the manifest itself is
regenerated at the R7 anchor **by the MAIN SESSION** (not by the builder sandbox). A new freeze version
is justified by a coherent independently-testable contract (new source files + new result path), not
cosmetics.

---

## 8. Component 6 — durable receipt + crash state machine (R-6)

Explicit transaction states (durable, observable):
`RESERVED → FETCHED_QUARANTINED → RIGHTS_REGISTERED → AUTHORITY_COMMITTED → RECEIPT_PREPARED →
PROMOTED → RECEIPT_FINALIZED`, plus terminal `RECOVERY_REQUIRED` and `REFUSED_REVOKED`.

The R6 gap: a crash in the `AUTHORITY_COMMITTED → RECEIPT_PREPARED` window left a promotable session with
**no** durable receipt, and `reconcileV4` promoted it silently and reported no deficit.

R7 rule (chosen policy — **reconstruct-or-report**, combining mandate §8 options 1 and 2):
- `reconcileV5` promotes a session ONLY if its ledger-resident authorization record exists **and** carries
  a complete proof identity.
- If the durable receipt is **absent** but the authorization record is complete, `reconcileV5`
  **reconstructs** a PREPARED receipt from the authenticated authorization record (all `prepare` fields
  are present in `RWCAcquisitionAuthorizationRecordV2`), then promotes and finalises — so a promoted
  asset **always** has a durable receipt. Idempotent under repeated recovery.
- If any proof field is missing/unverifiable, the session is kept **UNPROMOTED** and surfaced in a new
  `receiptDeficitSessions` report field (explicit `RECOVERY_REQUIRED`). **Never** silent promotion
  followed by silent quarantine deletion.
- All A19/A18 crash windows are re-proven on the V5 path (crash at every transition; repeated
  reconciliation; reopen stores; missing receipt; partial write; duplicated session; revocation during
  recovery; hash mismatch; unauthorized quarantine; corrupted/missing witnesses; concurrent writer).

---

## 9. Freeze V7 inventory files touched — enumerated + justified (SUPERSESSION preferred)

Policy: **new files / new versions** wherever possible; mutate a frozen file ONLY to seal a dangerous
export (access-control demotion), which is the lawful freeze-supersession the mandate explicitly permits
(§4). Each mutation is declared in `AUDIT20_R7_INVERSION_LOCK.md` with a byte-preserved original.

NEW files (zero mutation):
- `packages/GuardianKit/Sources/GuardianCore/RWCRightsV7Store.swift` (token + store V5 + authz record V2)
- `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV5.swift` (coordinator + token mint + reconcileV5)
- `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV6.swift`
- `docs/calibration/preregistration/RWC_PRE14_AUDIT_RESULT_SCHEMA_V4.yaml`
- `docs/calibration/preregistration/RWC_FROZEN_GATES_V8.yaml` (only if gates change; else carry V7)
- `docs/calibration/preregistration/tools/generate_freeze_manifest_v8.py`
- `packages/GuardianKit/Tests/GuardianCoreTests/RWCPreregistrationR7Tests.swift` (lawful + crash + matrix)
- `docs/audit/audit20_tools/a20consumer_r7/` (compile-negative consumer)

MUTATED frozen-V7 source files (access-control demotion `public→package` ONLY — declared in lock):
- `packages/GuardianKit/Sources/GuardianCore/RWCRightsV5.swift` (loader V1 mint/loadProduction; registry verifier V1)
- `packages/GuardianKit/Sources/GuardianCore/RWCRightsV3.swift` (authority V1 `.verify`; ledger store V3 surface)
- `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV3.swift` (reconcileV3)
- `packages/GuardianKit/Sources/GuardianCore/RWCRightsV6Store.swift` (scalar `authorizeAcquisition` demoted `public→package`)

No frozen **test/auditor** verdict file, machine result, manifest V1–V7, gate V1–V7, or AUDIT14–20
report is mutated. The AUDIT20 probes that must invert are handled per §10.

---

## 10. AUDIT20 probe inversion census (declared in the lock, implemented after)

The 11 AUDIT20 probes were **created in the AUDIT20 commit `5185101`** (NOT the R6 candidate) —
reproducibility of the R6 defect is anchored at `git show 5185101:…AUDIT20_RWCPre14R6ReauditProbes.swift`.
R7 refusal is proven by the inverted active probe. Planned inversions:

| probe | AUDIT20 (R6) OLD truth | R7 NEW truth |
|---|---|---|
| `test_A20_P1_01` | direct authorize+reconcile **PROMOTES** w/o V5 proof | R7: no token ⇒ `authorizeAcquisitionV2` unreachable w/ scalars; `reconcileV5` refuses; **corpus empty** |
| `test_A20_P1_02` | documents scalar-only signature | R7: documents token-required signature (no scalar authorize on the lawful path) |
| `test_A20_P2_01` | stale grant after revocation **still authorizes** | R7: `authorizeAcquisitionV2` refuses `.reviewerNotCurrent` |
| `test_A20_P3_01` | prohibited `training` **recorded** | R7: refused `.useNotAuthorized` at the gate |
| `test_A20_P3_02` (control) | wrong source refused | unchanged (still refused) |
| `test_A20_P6_01` | whole-dir rollback accepted (R-5 disk class) | **UNCHANGED** — documented residual (hostile-disk out of API scope); see §11 |
| `test_A20_P6_02` (control) | public-API rollback refused | unchanged |
| `test_A20_R5_01` | hostile-disk journal forgery accepted | **UNCHANGED** — documented R-5 residual (not an API bypass) |
| `test_A20_R6_01` | crash-before-receipt **promotes, no receipt, no deficit** | R7: `reconcileV5` reconstructs receipt (receipt present) OR reports `receiptDeficit`; the silent-no-receipt behaviour is gone |
| `test_A20_P7_01` | verifier V5 pinned R5 path/V6 manifest | **UNCHANGED** (V5 stays frozen); R7 adds a NEW verifier-V6 probe proving R7 path/V8 binding |
| `test_A20_P7_02` | verifier V5 refuses R6 path lock | **UNCHANGED**; new probe: verifier V6 refuses AUDIT20 FIX_REQUIRED + wrong path/manifest |

R-5 residual probes (`P6_01`, `R5_01`) are **preserved unchanged** — they are honest documentation of a
hostile-local-disk class that this phase does not claim to defeat (§11). They are not API bypasses, so
they are not "defects R7 must flip"; the lock records them as carried residuals.

A second question the lock must resolve (mandate §5 d): whether `RWCPreregistrationR6Tests` absence-pins
a file that the AUDIT20 commit lawfully changed. The R6 builder tests absence-pin the **operational
root** path only (`RWCReviewerTrustRootLoaderV2.canonicalInstancePath` does NOT exist) — still true at
HEAD. The AUDIT20 **result** `docs/audit/RWC_PRE14_R6_AUDIT_RESULT.json` was added by the AUDIT20 commit
(HEAD); the baseline run will reveal whether any builder test pins its absence. **Measured in the lock
after baseline; declared as a lawful phase-transition supersession if present** (known pattern:
R5Tests went through exactly this when AUDIT19 created the R5 result).

---

## 11. R-5 honest threat model (§9) — unchanged, re-affirmed

API-inaccessible forging, accidental-corruption detection, hostile-local-disk tampering, and genuine
cryptographic authentication remain explicitly distinguished. The SHA-256 journal chain and the
user-writable monotonic witness are **corruption/replay detection, NOT an external trust anchor**. A
hostile writer with directory write access can rewrite the chain (`R5_01`, `P6_01`) — this is an
**accepted, visible, bounded residual** valid only where the deployment threat model excludes hostile
local-disk writers. R7 does **not** invent a production root or backend authority to make it disappear,
and does **not** market "unforgeable ledger-resident authorization" as comprehensive corpus security.

---

## 12. Decision log (threat-model)

- **D-R7-1** Capability token in GuardianCore with `package` init, minted only by RunnerV5 — chosen over
  (a) making the V5 proof public (rejected: mandate forbids public proof constructors / would not solve
  the cycle cleanly), (b) merging the store into RWCAcquisition (rejected: larger blast radius, breaks
  the GuardianCore rights/registry ownership, more frozen-file churn).
- **D-R7-2** Seal legacy via `public→package` not `@available(unavailable)` — chosen to preserve
  historical-probe compilation with zero test inversions (measured dependency across 8 files).
- **D-R7-3** New store V5 + runner V5 (supersession) rather than mutating frozen V4 — chosen to keep the
  frozen-file mutation set to pure access-control demotions (declared), avoiding semantic edits to frozen
  R6 code.
- **D-R7-4** Receipt policy = reconstruct-or-report (R-6) — chosen over prohibit-only (which would leave
  authorised-and-paid-for assets stuck) and over promote-then-silently-skip (the audited defect).
- **D-R7-5** Revocation-effective-time policy (A20-F4): **current authorized reviewer status is mandatory
  at authorization-commit time; an authorization created after effective revocation is prohibited.**
  Already-authorized, not-yet-promoted transactions: `reconcileV5` promotes them (their authority record
  is durable and was lawful when committed) but does **not** permit a NEW authorization under a revoked
  reviewer; recovery uses the durable record, and if the current registry is presented and shows the
  reviewer revoked, a NEW authorize is refused while an EXISTING durable authorization still reconciles
  (deterministic, auditable, safety-preserving). Fully documented in the R6/R7 security design §6 lane.

---

## 13. Traceability (requirement → code → test)

| Requirement | Code | Test (R7) |
|---|---|---|
| A20-F1 methodology gate | `RWCAcquisitionAuthorityTokenV1`, `authorizeAcquisitionV2`, RunnerV5 mint | invert `P1_01`; `R7_F1_DirectAuthorize_NoToken_Refused`; lawful-accept |
| A20-F2 legacy seal | `public→package` demotions | `a20consumer_r7` compile-negative; historical probes still green |
| A20-F3 intended-use | `authorizeAcquisitionV2` use check | invert `P3_01`; `R7_F3_*` |
| A20-F4 revocation | currentness recheck at authorize | invert `P2_01`; `R7_F4_StaleGrant_Refused` |
| §7 verifier V6 | `RWCCorpusEntryVerifierV6` + schema V4 | synthetic PASS + 11 negatives; new V6 probes |
| R-6 receipt | state machine + `reconcileV5` reconstruct/report | invert `R6_01`; crash-matrix |
| R-5 residual | (none — documented) | `P6_01`/`R5_01` preserved |

---

## 14. What R7 is NOT

Not a PASS; not a PASS lock; not an operational reviewer root; not real corpus acquisition; not a
production-ready claim. Ceiling: **R7 BUILDER READY FOR INDEPENDENT AUDIT (AUDIT21)**. The next auditor
remains free to return FIX_REQUIRED.
