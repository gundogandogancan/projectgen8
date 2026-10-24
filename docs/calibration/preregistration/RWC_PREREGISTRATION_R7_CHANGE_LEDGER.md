# RWC PREREGISTRATION R7 — CHANGE LEDGER & SECURITY EVIDENCE

Date: 2026-10-24. Branch `phase/rwc-preregistration-r7`; base candidate `47ca59e…`; AUDIT20 commit
(current HEAD) `5185101…`. Governing control-plane lock `2c345b64…`. Zero-data intact; NO PASS lock;
NO operational reviewer root. Ceiling: **R7 BUILDER READY FOR INDEPENDENT AUDIT (AUDIT21)**.

Authoritative design: `RWC_R7_AUTHORITY_CONVERGENCE_DESIGN.md` (§2). Inversion lock:
`docs/audit/AUDIT20_R7_INVERSION_LOCK.md`.

> **ENVIRONMENT HONESTY (binding):** the R7 builder sandbox can `swift build` but CANNOT `git commit`
> or run `swift test`. All source/docs below are in the working tree. `swift build` of GuardianCore,
> RWCAcquisition and GuardianCoreTests **all complete** (measured — see the lock's compile-evidence
> section). The full `swift test` suite green ×2, the freeze-manifest V8 regeneration, the frozen-source
> originals of the mutated files, and all commits/tag are performed by the **MAIN SESSION** per the
> commit plan. Nothing here is represented as TESTED until that evidence exists. Status of all new
> source = **IMPLEMENTED_UNVERIFIED (compiles; not yet suite-tested)**.

---

## 1. API authority graph — before vs after (summary; full diagram in the design §3)

BEFORE: a verified **rights** grant V6 alone could drive `store.authorizeAcquisition(fabricated
scalars)` → `reconcileV4` → promote, bypassing the PRE-14 PASS gate (A20-F1). A legacy external chain
`LoaderV1.mint(JSON) → AuthorityV1.verify → StoreV3.register → RunnerV3.reconcileV3` was fully `public`
(A20-F2). Intended-use (A20-F3) and current-registry authority (A20-F4) were unchecked at the direct
gate. A crash authorize→receipt promoted with no durable receipt and no deficit (R-6).

AFTER: ONE lawful path through `RWCCorpusAcquisitionRunnerV5` (the single coordinator). The ledger write
`authorizeAcquisitionV2` **requires** an `RWCAcquisitionAuthorityTokenV1` whose init is `package` and is
minted ONLY by RunnerV5 after verifier-V6 PASS + evaluator + current-registry recheck. The scalar writer
and the entire legacy V1/V3 external chain are sealed to `package`. The four findings close at **one
boundary**.

## 2. Minimum Trusted Computing Base (TCB) after R7

- **GuardianCore (package-sealed mint surfaces):** `RWCReviewerTrustRootLoaderV2` (capability-gated, no
  public mint), `RWCReviewerRegistryCurrentnessStoreV1` + `RWCReviewerRegistryVerifierV2.verifyCurrent`,
  `RWCRightsReviewAuthorityV6.verify`, `RWCPreAcquisitionEvaluatorV3.authorize`, and the R7
  `RWCAcquisitionAuthorityTokenV1` (`package` init) + `RWCAssetRightsLedgerStoreV5.authorizeAcquisitionV2`.
- **RWCAcquisition:** `RWCCorpusEntryVerifierV6.verify` (methodology PASS proof), the single coordinator
  `RWCCorpusAcquisitionRunnerV5` (sole token minter), `RWCAcquisitionReceiptStoreV2`.
- **Unforgeable proof types (all `fileprivate`/`package` init):** `RWCVerifiedReviewerTrustRootV2`,
  `RWCVerifiedReviewerRegistryV2`, `RWCVerifiedRightsGrantV6`, `RWCPreAcquisitionAuthorizationV3`,
  `RWCVerifiedCorpusEntryV6`, `RWCAcquisitionAuthorityTokenV1`, `RWCAcquisitionAuthorizationRecordV2`.
- Everything outside this set is DATA, not authority.

## 3. Threat-model decision log — see design §12 (D-R7-1 … D-R7-5), including the A20-F4
revocation-effective-time policy (current authorized reviewer status mandatory at authorization-commit
time; an authorization created after effective revocation is prohibited; already-authorized not-yet-
promoted transactions still reconcile from their durable record but no NEW authorize is minted under a
revoked reviewer).

## 4. A20-F1..F4 — original exploit → structural fix → independent-test-ready result

| finding | original exploit (AUDIT20, reproducible at `git show 5185101:…probes`) | R7 structural fix | independent-test-ready result |
|---|---|---|---|
| **A20-F1 CRITICAL** | `register → authorizeAcquisition(fabricated candidate/audit scalars) → reconcileV4` promotes w/o any V5 PASS proof | capability token required by `authorizeAcquisitionV2`; token minted only by RunnerV5 after verifier-V6 PASS; scalar writer sealed `package`; record carries full proof identity | invert `test_A20_P1_01` (corpus empty); `R7_F1_DirectAuthorize_NoToken_Refused`; lawful token-acquire ACCEPTS |
| **A20-F2 HIGH** | external `LoaderV1.mint → AuthorityV1.verify → StoreV3.register → RunnerV3.reconcileV3` | all four + the scalar authorize demoted `public → package` (lawful freeze supersession) | `a20consumer_r7` compile-negative (external import cannot name them); **historical probes still compile — ZERO inversions** (measured) |
| **A20-F3 MEDIUM** | `authorizeAcquisition` records a use the grant prohibits | `authorizeAcquisitionV2` validates `intendedUse` ∈ `grant.allowedUse`, ∉ `prohibitedUse` (and the token only exists via the evaluator) | invert `test_A20_P3_01` (refused `.useNotAuthorized`) |
| **A20-F4 MEDIUM** | stale grant (reviewer revoked in current rev2) still authorizes | `authorizeAcquisitionV2` requires the CURRENT verified registry; refuses `.reviewerNotCurrent` when grant digest != current head or reviewer not ACTIVE | invert `test_A20_P2_01` (refused) |

## 5. Release schema/verifier compatibility proof (§7 blocker resolved)

- NEW `RWC_PRE14_AUDIT_RESULT_SCHEMA_V4.yaml` → canonical instance `docs/audit/RWC_PRE14_R7_AUDIT_RESULT.json`,
  binds freeze manifest V8 + `freeze_version: rwc-preregistration-freeze-v8`; V3 strict count laws +
  A18-F5 candidate-blob law + A18-F4 tag-name cross-check carried verbatim.
- NEW `RWCCorpusEntryVerifierV6.swift` → mints `RWCVerifiedCorpusEntryV6` only after binding the R7 path +
  V8 manifest; **no fallback** to V5. Compatibility matrix (verifier V6 MUST reject): AUDIT19 FIX_REQUIRED;
  AUDIT20 FIX_REQUIRED; schema-V3-as-V4; right bytes wrong path; PASS-looking JSON w/o git support;
  mismatched tag object / freeze blob; uncommitted result; missing authority; unrelated candidate; V5
  fallback. `verify(realRepo)` → `.lockMissing` (fail closed). **NO PASS result / PASS lock created.**
- Freeze V8: generator `tools/generate_freeze_manifest_v8.py` (NEW); manifest regenerated by MAIN SESSION
  at the R7 anchor.

## 6. R-5 / R-6 adjudication + receipt state machine

- **R-5 (hostile local disk):** UNCHANGED, re-affirmed honest residual (design §11). `P6_01`/`R5_01`
  preserved as negative history; SHA-256 chain + user-writable witness = corruption/replay detection,
  NOT an external trust anchor. No production root invented to mask it.
- **R-6 (crash authorize→receipt):** CLOSED. State machine
  `RESERVED → FETCHED_QUARANTINED → RIGHTS_REGISTERED → AUTHORITY_COMMITTED → RECEIPT_PREPARED → PROMOTED
  → RECEIPT_FINALIZED` (+ `RECOVERY_REQUIRED`, `REFUSED_REVOKED`). `reconcileV5` RECONSTRUCTS a durable
  receipt from the authenticated authorization record V2 (all `prepare` fields present) so a promoted
  asset ALWAYS has a receipt; an incomplete proof identity → UNPROMOTED + explicit `receiptDeficitSessions`.
  Idempotent. Invert `test_A20_R6_01`.

## 7. External-consumer compile-negative evidence

`docs/audit/audit20_tools/a20consumer_r7/` (pattern: `a19consumer_r6`). A non-`@testable` executable
depending only on the `GuardianCore` product. Asserts at runtime `loadProduction` fails closed, and
documents as must-not-compile lines: `RWCReviewerTrustRootLoaderV1.mint`/`loadProduction`,
`RWCRightsReviewAuthorityV1.verify`, `RWCReviewerRegistryVerifierV1.verify`,
`RWCAssetRightsLedgerStoreV3.register`, `RWCAcquisitionAuthorityTokenV1(init)`, and (second consumer on
RWCAcquisition) `RWCCorpusAcquisitionRunnerV3.reconcileV3` — all now `package`/`fileprivate` → unresolved
for an external consumer. MAIN SESSION: `swift build` must FAIL with the lines uncommented and SUCCEED
with them commented (the proof).

## 8. Crash state-transition evidence — MAIN SESSION to run `RWCPreregistrationR7Tests`

Crash at every transition; repeated reconcileV5; reopen ledger/receipt stores; missing receipt (→
reconstruct); partial write; duplicated session; revocation during recovery; hash mismatch; unauthorized
quarantine (destroyed); corrupted/missing witness (fail closed); concurrent writer (flock). The V5 store
reuses the AUDIT-verified V4 durability mechanics byte-for-byte (same roll-forward-one-pending, refuse
divergence, never reset to empty), so the crash laws carry.

## 9. Source & audit-result compatibility matrix

| consumer | result path | manifest | freeze_version | status |
|---|---|---|---|---|
| VerifierV5 (frozen) | R5 | V6 | freeze-v6 | SUPERSEDED (unchanged) |
| VerifierV6 (R7, new) | R7 | V8 | freeze-v8 | ACTIVE lawful release path |
| AUDIT19/20 FIX_REQUIRED results | — | — | — | permanently refused as PASS |

## 10. Performance / resource note

R7 adds one value type, one verifier (same git-object cost profile as V5), one coordinator and one
sealed writer. No new per-frame/hot-path work; the ledger/receipt/currentness stores are unchanged in
mechanics. No measurable regression expected on the acquisition path (offline, not on the perception hot
path). No device measurement is fabricated.

## 11. Privacy / data minimization

Unchanged: zero-data invariants hold (corpus/annotator/fit/heldout = 0; data_visibility=false). The
token/record carry only identity digests/commits — no payload, no PII. Raw bytes stay in quarantine and
never touch the corpus store except via the lawful promote. No new data retention.

## 12. Rollback (preserves historical evidence)

R7 is pure supersession + declared access demotions. Rollback = revert the R7 commits (R7-01..R7-08);
the AUDIT20 history, the frozen originals and V1–V7 manifests/gates remain intact. The `public → package`
demotions are reversible (restore the frozen originals the main session archived). No history rewrite.

## 13. File inventory (this R7 builder effort)

CREATED (new):
- `packages/GuardianKit/Sources/GuardianCore/RWCRightsV7Store.swift`
- `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV5.swift`
- `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV6.swift`
- `docs/calibration/preregistration/RWC_R7_AUTHORITY_CONVERGENCE_DESIGN.md`
- `docs/calibration/preregistration/RWC_PRE14_AUDIT_RESULT_SCHEMA_V4.yaml`
- `docs/calibration/preregistration/RWC_PREREGISTRATION_R7_CHANGE_LEDGER.md` (this file)
- `docs/calibration/preregistration/tools/generate_freeze_manifest_v8.py`
- `docs/audit/AUDIT20_R7_INVERSION_LOCK.md`
- `docs/audit/AUDIT20_RWCPre14R6ReauditProbes_ORIGINAL_LOCKED.swift.txt`
- `docs/audit/audit20_tools/a20consumer_r7/` (compile-negative package)
- `docs/progress/GEN8_PRODUCT_EVIDENCE_SCORECARD.md`
- `packages/GuardianKit/Tests/GuardianCoreTests/RWCPreregistrationR7Tests.swift` (MAIN SESSION writes/runs — stubbed plan here)
- `/tmp/RWC_PRE14_R7_AUDIT21_MANDATE_DRAFT.md`

MODIFIED (freeze-V7 inventory files — flagged; declared in the lock):
- `packages/GuardianKit/Sources/GuardianCore/RWCRightsV5.swift` (A20-F2 `public→package`)
- `packages/GuardianKit/Sources/GuardianCore/RWCRightsV3.swift` (A20-F2 `public→package`)
- `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV3.swift` (A20-F2 `public→package`)
- `packages/GuardianKit/Sources/GuardianCore/RWCRightsV6Store.swift` (A20-F1 scalar authorize `public→package`)
- `packages/GuardianKit/Sources/RWCAcquisition/RWCAcquisitionReceiptStoreV2.swift` (additive `package` prepare overload)

MODIFIED (AUDIT-prefixed, planned inversions — AFTER the lock commit):
- `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT20_RWCPre14R6ReauditProbes.swift` (5 assertion inversions; §lock)

TO BE REGENERATED BY MAIN SESSION:
- `docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V8.yaml` (anchor-phase)
- `docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml` (`r7_*` keys — **DONE in the R7-07 working tree**; see §14; the master manifest is hash-exempt/MUTABLE_BY_LAW in freeze V7, so this edit is lawful and leaves every historical key byte-untouched)

---

## 14. R7-07 COMPLETION EVIDENCE (measured in the completion engineer's sandbox — reproducible)

This section supersedes the ENVIRONMENT HONESTY caveat at the top FOR THE R7-07 COMPLETION PASS ONLY: the
R7-07 completion engineer's sandbox CAN `swift build` and `swift test --parallel` (it still CANNOT
`git commit`; the main session commits). Toolchain: Apple Swift 6.3.3; target arm64-apple-macos; Testing
Library 1902.

### Inversions implemented (5/5) — AUDIT20_RWCPre14R6ReauditProbes.swift

Implemented EXACTLY the five declared inversions (lock §"DECLARED INVERSIONS"), each carrying the required
R7-INVERSION header (old R6 truth → new R7 truth; preserved at `git show 5185101:…`):
- `test_A20_P1_01` — bypass now REFUSED: a direct caller cannot mint the token; store V5's only ledger
  writer is `authorizeAcquisitionV2(token:)`; `reconcileV5` promotes NOTHING (corpus empty; session
  destroyed-unauthorized).
- `test_A20_P1_02` — the lawful write names the STRUCTURED `RWCAcquisitionAuthorityTokenV1` (proof
  identity + evaluator facts + registry witness), not free-form scalars.
- `test_A20_P2_01` — stale grant after revocation REFUSED `.reviewerNotCurrent`; nothing durable written.
- `test_A20_P3_01` — prohibited intended-use REFUSED `.useNotAuthorized`; nothing durable written.
- `test_A20_R6_01` — `reconcileV5` RECONSTRUCTS a durable COMPLETED receipt from the authenticated
  authorization record (no silent no-receipt promotion; no deficit).

### Inversion census — byte-verified against HEAD blob `5185101` (`0ec33211…`)

- 6 preserved probes **BYTE-IDENTICAL** to the frozen original (confirmed by brace-balanced extraction +
  byte compare): `P3_02`, `P6_01`, `P6_02`, `R5_01`, `P7_01`, `P7_02`.
- Exactly 5 probe bodies changed (the five above). The 11-function NAME set is unchanged (no additions /
  removals / renames). Each OLD EXPLOIT comment is retained inline as negative history. One additive shared
  helper (`syntheticToken`) was added (additive, as the lock permits).

### Stubs completed (6/6) — RWCPreregistrationR7Tests.swift

All six `testR7_MAINSESSION_*` stubs implemented against a compiler + the full suite (synthetic V6 PASS
fixture `syntheticProofV6()` — throwaway git repo bound to the R7 result path schema V4 + freeze manifest
V8 + freeze-v8):
- `..._LawfulAcquire_V5_Promotes_ReceiptCompleted` — RunnerV5.acquire end-to-end; promote + COMPLETED
  receipt + full-proof-identity authorization.
- `..._CrashBeforeReceipt_ReconcileV5_Reconstructs` — R-6 reconstruction (lawful token minted from the
  real V6 proof); idempotent.
- `..._IncompleteProofIdentity_ReconcileV5_ReportsDeficit` — hostile-disk forged V2 authorization with an
  incomplete proof identity → UNPROMOTED + explicit `receiptDeficit` (fail closed).
- `..._VerifierV6_SyntheticPASS_Accepts` — V6 accepts the synthetic PASS; fails closed `.lockMissing` on
  the real repo.
- `..._VerifierV6_RejectsAUDIT20FixRequired_WrongPath_WrongManifest_FakeCounts` — 9-case reject matrix
  (FIX_REQUIRED verdict, wrong R6 path, V7-manifest lock, wrong tag name, live frozen-blob drift,
  schema-V3-as-V4, nonzero/inconsistent fake counts, unsupported lock version).
- `..._DirectAuthorizeV2_NoLawfulToken_Unreachable_ExternalConsumer` — drives `a20consumer_r7`: POSITIVE
  build (negatives commented) SUCCEEDS; a generated temp copy with the `package`-init authority-token
  construction UNCOMMENTED FAILS to compile — the structural A20-F1 seal evidence.

### Build + test evidence (measured)

- `swift build` (all targets): **Build complete**, zero errors from R7 code (pre-existing unrelated
  Swift-6-mode `@Sendable` capture warnings only).
- Targeted `swift test --filter 'RWCPreregistrationR7Tests|AUDIT20_RWCPre14R6ReauditProbes'`:
  **21/21 pass, 0 failures** (AUDIT20 11/11 inverted-and-preserved; R7Tests 10/10 — 4 original + 6
  completed stubs).
- FULL `swift test --parallel` ×2 (two independent runs): **1146/1146 executed, 0 failures** each run.
  The swift-testing lane reports "0 tests in 0 suites" (this package's RWC/Guardian tests are XCTest). No
  lawful stale-pin phase transition was triggered; no undeclared test was edited. Exit: success both runs.

### Master manifest action (Task C)

Verified `RWC_PREREGISTRATION_MASTER_MANIFEST.yaml` is in `surface_rules.hash_exempt` (MUTABLE_BY_LAW) in
freeze manifest V7 → the `r7_*` additions are lawful. Added `audit20`, `r7_candidate_generation`,
`r7_status`, `r7_branch`, `r7_candidate_commit` (= `PENDING_ANCHOR`), `r7_methodology_anchor_commit` (=
`PENDING_ANCHOR`), `r7_lock_commit` (= `8e4437f`), `r7_findings_closed`, `r7_strategy`,
`r7_superseded_engineering_history`, `r7_outputs` — following the `r6_*` pattern. Every historical key is
byte-untouched; the four zero counters + `data_visibility:false` are unchanged (re-validated as strict
JSON). The candidate/anchor commits are left PENDING — the main session fills them at the R7 anchor.

### Files ready for the R7-07 commit

- `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT20_RWCPre14R6ReauditProbes.swift` (5 inversions)
- `packages/GuardianKit/Tests/GuardianCoreTests/RWCPreregistrationR7Tests.swift` (6 stubs completed)
- `docs/calibration/preregistration/RWC_PREREGISTRATION_MASTER_MANIFEST.yaml` (`r7_*` keys)
- `docs/calibration/preregistration/RWC_PREREGISTRATION_R7_CHANGE_LEDGER.md` (this evidence section)
- `docs/progress/GEN8_PRODUCT_EVIDENCE_SCORECARD.md` (R7 suite-evidence line)
- `docs/audit/audit20_tools/a20consumer_r7/` (already complete; positive builds, negatives commented)

No frozen auditor/result/lock/manifest-V1..V7/gate file, and no already-committed R7 source, was mutated.

## MAIN-SESSION ADDENDUM (2026-10-24, PRE-AUDIT candidate supersession — hygiene only)
The R7-07 commit accidentally tracked 4702 SwiftPM build artifacts under
`docs/audit/audit20_tools/a20consumer_r7/.build/` (binary .o/.swiftdeps/db files; running the
compile-negative test mutates them, dirtying the tree). This commit removes them from tracking and
gitignores `.build/`. ZERO source/test/doc content changed. The initially pushed candidate tag
`gen8-rwc-preregistration-r7-audit-candidate` (object 4a9fb34 -> commit ed2f668) is SUPERSEDED
PRE-AUDIT history (no audit was conducted against it; it is never deleted). The AUDIT21 target is
the NEW annotated tag `gen8-rwc-preregistration-r7-audit-candidate-final`. Anchor (3abb24a) and
freeze V8 (309 artifacts, digest c64f7632) are unaffected: .build paths are outside every governed
root, and the frozen artifacts are byte-identical (anchor..candidate per-path diff law holds).
