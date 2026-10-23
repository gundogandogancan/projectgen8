# GEN8 — RWC PRE-14 R5 INDEPENDENT CLEAN-SESSION RE-AUDIT (AUDIT19)

Date: 2026-10-24 (pre-data; zero corpus/annotator/fit/heldout; no PASS lock; no operational reviewer root).
Auditor: fresh independent clean session. NOT the builder. No stake in the outcome.
Mandate: `/tmp/RWC_PRE14_R5_REAUDIT_MANDATE_AUDIT19.md` (followed verbatim).

## FINAL VERDICT

**FIX REQUIRED — RWC PREREGISTRATION R5** (mandate §1 verdict B).

1 CRITICAL, 2 HIGH, 2 MEDIUM (+ LOW/INFO). A PASS is impossible with these open findings
(mandate §1/§60). The PRE-14 authority architecture is NOT yet lockable: an ordinary production
consumer can both self-mint the reviewer trust root AND drive raw attacker bytes into the corpus
store through the reconcile recovery path, with no authentic PRE-14 PASS and no rooted reviewer
authority. These are the exact CRITICAL/HIGH conditions mandate §59 enumerates.

The first real asset remains blocked regardless (no PASS lock, no operational root, no governed
current registry); but the architecture itself must be fixed before PRE-14 can PASS.

---

## 1. CUSTODY (independently re-measured against the local object store)

| check | measured |
|---|---|
| branch | phase/rwc-preregistration-preparation |
| HEAD | f30b39322500da6e9e8602645e287cd41a61018e |
| origin/<branch> | f30b39322500da6e9e8602645e287cd41a61018e |
| tag ref (annotated TAG OBJECT) | e599cc909a910d1bf7a96798ecd268f26e5facfa |
| `git cat-file -t <tag>` | tag (annotated) |
| tag^{commit} dereference | f30b39322500da6e9e8602645e287cd41a61018e |
| anchor 31267a4e ancestry of candidate | ANCESTOR_OK (exit 0) |
| AUDIT18 commit ac91974 | exists (commit) |
| working tree | clean except untracked `.planning/` (out of scope) |

All match mandate §0. No mismatch → not BLOCKED on custody.

## 2. AUDIT18 DISCIPLINE + INVERSION I-1

- AUDIT18 machine result remains **FIX_REQUIRED 0/2/2** (sha 47358f2a1675b5fec8…). R3 remains
  FIX_REQUIRED 0/5/5 (sha 2ebd7f8f…). Historical truth intact.
- 4 AUDIT18 frozen probe originals byte-identical to the SHAs in `AUDIT18_R5_INVERSION_LOCK.md`
  (verified in probe `test_A19_04`).
- **I-1 ordering proven**: `git merge-base --is-ancestor 9a253a1 (ADDENDUM 1 declaration)
  31267a4e (inverting commit)` → exit 0. Declaration committed BEFORE inversion.
- **I-1 exact delta**: `test_A18_46` in `AUDIT18_VerifierFreezeProbes.swift` re-anchored from
  `candidate..floating HEAD` to `candidate..ac91974` (immutable AUDIT18 commit). The active file
  now references `ac91974ddba3289031efe1df075185178259472b`; the frozen original
  (`AUDIT18_VerifierFreezeProbes_ORIGINAL_LOCKED.swift.txt`, dcb9881e…) remains recoverable.
- **No other undeclared inversion**: the freeze V6 census shows zero anchor→candidate drift on all
  287 frozen artifacts except the two lawful `post_anchor_allowed` files (manifest V6 + R5 report).

## 3. ZERO DATA (independently proven)

corpus=0, annotators=0, real_fit=0, heldout_open=0, data_visibility=false (master manifest /
pre_data_declaration). `preregistrationAuditPassed=false`. Absent: operational reviewer root
(`docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json`), R5 machine result in the candidate tree,
PASS lock (`docs/audit/RWC_PRE14_PASS_LOCK.yaml`). Real repo verifier V5 fails closed with
`lockMissing`.

## 4. ROOT OF TRUST — A19-F2 (HIGH)

- **public `mint(fromJSON:)` callable by a normal consumer? YES.**
  `RWCReviewerTrustRootLoaderV1.mint(fromJSON:)` is `public` (RWCRightsV5.swift:160). Probe
  `test_A19_07` (public symbols only) crafts attacker Ed25519 JSON → mints a
  `RWCVerifiedReviewerTrustRootV1`, signs a registry, verifies it, signs an APPROVED review and
  mints `RWCVerifiedRightsGrantV3` — the ENTIRE governed chain forged from attacker keys. A normal
  `/tmp` SwiftPM consumer (`docs/audit/audit19_tools/a19consumer_main.swift`, `import GuardianCore`,
  NO @testable) compiles against this same public symbol.
- **attacker repoRoot loadProduction? VERIFIED ROOT obtained.** `loadProduction(repoRoot:)` takes a
  caller URL; probe `test_A19_08` points it at an attacker temp dir containing a self-authored
  ACTIVE root JSON and obtains a verified production root. Canonical PATH is configuration, not
  trust (mandate §53).
- **actual production trust bootstrap: ABSENT.** Nothing pretrusted exists before parsing the JSON;
  the JSON "says so" (mandate §9 self-signed-without-bootstrap case). The design DEFERS trust to
  operational onboarding — but because `mint(fromJSON:)` is public, a production caller CAN mint a
  verified root today. Mandate §52 is explicit: "PASS is impossible if production caller can
  self-mint a root via public API." → **A18-F1 is NOT closed at the root link.**
- **governanceRecord verified? NO** (probe `test_A19_09`): accepted verbatim, caller-controlled
  metadata.
- **synthetic factory production accessible? NO.** `makeSyntheticTestRoot` is `internal`
  (RWCRightsV5.swift:199) — not the leak. The leak is the public production mint itself.
- verdict: **HIGH (A19-F2).** Self-root public API with trivial caller setup (mandate §59 HIGH).

## 5. REVIEWER REGISTRY — A19-F3 (HIGH)

- **current registry authority: ABSENT.** No durable current-registry head/pointer mechanism
  exists anywhere in the sources; `RWCReviewerRegistryVerifierV1.verify` accepts any standalone
  root-signed document when `previousVerified == nil`.
- **old-registry replay: SUCCEEDS** (probe `test_A19_11`): rev1 ACTIVE, rev2 REVOKED (correct
  chain); replaying rev1 with `previousVerified:nil` re-verifies the reviewer ACTIVE.
- **rev>1 previous=nil: VERIFIES** (probe `test_A19_12`): revision 5 + arbitrary
  previousRegistryDigest verifies — the chain/rollback law only engages when a previous proof is
  supplied; genesis check only binds revision 1.
- **rollback / key rotation**: old rotated-out registry (key A) still verifies standalone
  (`test_A19_14`); a review signed pre-revocation re-mints a grant via the replayed registry
  (`test_A19_17`).
- **reviewer scope: ENFORCED** (`test_A19_15`): corpus PASS; annotation/governance REFUSE
  (reviewerScopeUnauthorized). Wrong role REFUSE (`test_A19_48`). Revoked/suspended/wrong-key/
  unknown REFUSE (`test_A19_16`). Wrong-root + duplicate-in-document REFUSE (`test_A19_49/50`).
- verdict: **HIGH (A19-F3).** A stale root-signed registry resurrects a revoked reviewer because
  there is no governed current-registry selection (mandate §13/§59 HIGH). Note: this is only
  reachable on the real acquisition path once an operational root exists — but combined with
  A19-F1 it is immediately dangerous.

## 6. RIGHTS / PRE-FETCH (clean regression)

source binding, intended-use law, expiry, ineligible class, invalid review all REFUSE pre-fetch
with fetchCount==0 and no residue (probe `test_A19_19`; carried A17/A18 laws). Source manifest V2
refuses empty/duplicate/invalid and is order-independent (`test_A19_18`). verdict: CLEAN.

## 7. RECOVERY BYPASS — A19-F1 (CRITICAL) — the decisive finding

Probe `test_A19_20` executes the full mandate §21 chain using **ONLY public API**, with NO
`RWCVerifiedRightsGrantV3`, NO `RWCPreAcquisitionEvaluatorV2`, NO verified corpus-entry V5 proof,
NO `RunnerV3.acquire()`:

1. forged V1 token: `RWCRightsReviewAuthorityV1.verify(grant:reviewRecord:)` is `public`
   (RWCRightsV3.swift:300) and performs NO cryptographic check — it only compares caller-supplied
   string fields of a caller-constructed `RWCRightsReviewRecordV1` (public init) against a
   caller-constructed grant, both saying "APPROVED". It returns a `RWCVerifiedRightsGrantV1`.
2. `RWCAssetRightsLedgerStoreV3.register(record, verifiedGrant: forgedToken, clock:)` accepts it
   and commits a rights record.
3. public `SessionMetadataV1(... state: .rightsCommitted ...)` + `write(to:)` manufacture a
   RIGHTS_COMMITTED quarantine (probe `test_A19_22`).
4. public `receiptStore.prepare(...)` persists a PREPARED receipt from caller-chosen authority
   scalars (probe `test_A19_21`).
5. `runner.reconcileV3(rightsStore:corpusStore:receiptStore:)` → **MEASURED: promote == true**;
   the attacker payload is written to the corpus store.

`reconcileV3.authorityConsistent` only checks that the (forgeable) metadata matches the (forgeable)
rights record and the (forgeable) receipt — all three are publicly caller-constructible. There is
NO unforgeable, authority-bound transaction marker proving the transaction was originally authorized
by `RunnerV3.acquire()` (mandate §22 requirement unmet). PRE-14 PASS proof is not required by the
recovery path, and a rooted grant is not required by the recovery path.

- rooted grant required by recovery? **NO.**
- PRE14 proof required by recovery? **NO.**
- verdict: **CRITICAL (A19-F1).** "reconcile can be used as an acquisition backdoor without rooted
  reviewer/PRE14 authority" AND "corpus entry occurs without authentic PRE14 PASS" — both CRITICAL
  conditions in mandate §59.

Note on R4→R5 regression: AUDIT18 found the forged-V1-ledger path "bounded because it only
produced registeredButUnpromoted." R5 added the public durable receipt store + public
SessionMetadataV1 + a reconcileV3 that CAN promote — which converts that previously-bounded path
into a full promotion backdoor. The new recovery surface re-opened a closed boundary.

## 8. DURABLE RECEIPT (mostly clean; strict-parse + authority-scalar gaps)

- prepare ordering: PREPARED written after rights commit, before promote; finalize to COMPLETED
  (lawful control `test_A19_27`).
- crash-after-promote: reconcileV3 finalizes receipt, single promotion, COMPLETED (`test_A19_29`).
- confirm/complete idempotent; survives store reopen byte-equivalent (`test_A19_30`).
- accidental corruption detected via integrity line (`test_A19_47`).
- authority-field mismatch never promotes (`test_A19_32`).
- **strict parse (A19-F5, MEDIUM)**: receipt + session-metadata intendedUse parse as
  if-"training"-else-evaluation. A garbage `"use":"garbage"` with recomputed integrity hash silently
  becomes `.evaluation` (probe `test_A19_23`) instead of a typed refusal.
- **authority scalars (A19-F4, MEDIUM)**: `prepare(...)` accepts arbitrary caller authority strings
  and negative numerics (grantRevision=-5, rightsEventCount=-1) as durable "acquisition evidence"
  (probes `test_A19_21/24`). Acceptable ONLY if reconcile never treats the receipt as authority —
  but A19-F1 shows the receipt IS part of the (forgeable) authority-consistency check, so this is a
  must-fix-before-first-asset MEDIUM.

## 9. RECONCILIATION (clean where authority is honest)

same-hash distinct assets no cross-binding (`test_A19_34`); reauthorize-after-revoke correct state
(`test_A19_35`); revoked asset never promoted (`test_A19_33`); duplicate session destroyed;
idempotent. The defect is not the reconciliation bookkeeping — it is that the authority inputs are
forgeable (§7).

## 10. FREEZE V6 (candidate-object bound; clean)

Independent census (`docs/audit/audit19_tools/audit19_freeze_v6_census.py`, stdlib only):
- **287 artifacts** counted independently (builder claim 287 — concordant; not targeted).
- 0 hash mismatches, 0 missing files, 1 hash-exempt (the manifest self-entry).
- recomputed `frozen_inventory_digest` = `4cc1a7f33b91ead71802f0df0ef9f6ce5a038e7742f6e9a69c33627ac48d80d5` == declared.
- zero anchor(31267a4e)→candidate(f30b393) frozen drift.
- **candidate blob == live**: both SHA-256 =
  `0e68365940d46144174f4d3802d2a3ae6b6bebd69e1621148cf3b203003ea531` (probe `test_A19_36`;
  A18-F5 binding precondition holds). Verifier V5 enforces the 4-way equality + tag-name cross-check.
- verdict: CLEAN. A18-F5 candidate-freeze-blob binding genuinely closed.

## 11. AUDIT AUTHORITY

- canonical result path `docs/audit/RWC_PRE14_R5_AUDIT_RESULT.json`, schema V3 (strict verdict
  enum, non-negative integer counts, baseline+fresh==total). This instance: FIX_REQUIRED,
  1072+45=1117, 1/2/2.
- tag-name binding: result == lock-to-be == dereferenced annotated tag name
  `gen8-rwc-preregistration-r5-audit-candidate` (verifier V5 A18-F4).
- candidate is ancestor of the (future) AUDIT19 audit commit; add-only surface.
- verdict: result authority laws CLEAN (schema-valid instance created only after verdict
  determination, per §4/§62).

## 12. CALIBRATION + DURABLE RIGHTS REGRESSION

- Calibration invariants S=9999 / n=800 / IRR=.60, strict input / tie / seed law carried, no drift
  (`test_A19_43`; full R1..R5 calibration families green in the suite).
- Durable rights: reopen head-witness consistent (`test_A19_44`); tombstone/revoke/reauthorize/
  flock/crash recovery all green across the suite. verdict: CLEAN.

## 13. FRESH FINDINGS

| ID | severity | evidence | first-asset impact |
|---|---|---|---|
| A19-F1 | CRITICAL | `test_A19_20`: forged public V1 token → register → public metadata + receipt → `reconcileV3` promotes attacker bytes (measured promote==true); no rooted grant / PRE14 proof / RunnerV3 required | Corpus can be populated with unauthorized bytes through the recovery API once a ledger+quarantine+receipt dir exist — bypasses the entire rooted authority chain. Must fix before ANY asset. |
| A19-F2 | HIGH | `test_A19_07/08/09`: public `mint(fromJSON:)` + `loadProduction(repoRoot:)` self-mint a verified root; full chain to grant V3 from attacker keys | A production caller can self-mint the reviewer root; the "SIGNATURE ≠ TRUST" principle is defeated at the root link. |
| A19-F3 | HIGH | `test_A19_11/12/14/17`: old/standalone registry replay resurrects REVOKED reviewer; rev>1 w/ previous=nil + arbitrary prev digest verifies; no current-head pointer | A stale root-signed registry resurrects revoked authority on the acquisition path. |
| A19-F4 | MEDIUM | `test_A19_21/24`: receipt `prepare()` accepts arbitrary + negative authority scalars as durable evidence | Durable "acquisition evidence" is forgeable; feeds A19-F1's consistency check. |
| A19-F5 | MEDIUM | `test_A19_23`: `"use":"garbage"` silently → `.evaluation` in receipt + session metadata | Non-strict enum parse with authorization impact. |
| A19-F6 | LOW/INFO | `test_A19_09/46`: governanceRecordID unverified; entry-revision cross-document monotonicity not enforced; canonical root path is config not trust | Documentation/threat-model clarifications. |

## 14. LOCKS / STATE

- R5 machine audit result: CREATED by AUDIT19 (this audit), FIX_REQUIRED 1/2/2.
- PASS lock: ABSENT (not created — mandate §63).
- operational root: ABSENT. corpus/annotation/fitting/heldout/device/score/display/Presentation:
  all GATED/BLOCKED.

## 15. LAWFUL PHASE-TRANSITION TRUTH (mandate §4f)

Creating `docs/audit/RWC_PRE14_R5_AUDIT_RESULT.json` lawfully makes the R5 builder absence-pin
(`RWCPreregistrationR5Tests` asserting the R5 result file does NOT exist) go STALE — exactly as
pre-declared in `AUDIT18_R5_INVERSION_LOCK.md` line 25-26 ("the R5 result … is created ONLY by
AUDIT19"), the identical pattern to the R3→R4→R5 transitions. **The R5 builder test was NOT edited
and the auditor does NOT claim a post-result green suite on that pin.** The authoritative measured
counts (1072 baseline + 45 fresh = 1117, 0 failures, 11 skips) were taken BEFORE this instance was
written. The post-result staleness of that one builder pin is lawful and expected; it is NOT a
regression and NOT within AUDIT19's edit scope.

## 16. CONCLUSION

**FIX REQUIRED — RWC PREREGISTRATION R5.** The PRE-14 methodology/authority architecture is not
lockable: A19-F1 (CRITICAL recovery backdoor) and A19-F2/F3 (HIGH self-root + registry replay)
defeat the core claims that corpus entry requires authentic PRE-14 PASS and rooted reviewer
authority. A18-F5 (freeze candidate-blob binding) and A18-F2 (scope) are genuinely closed; A18-F3
durable receipt is durable but its authority scalars are forgeable (A19-F4). No PASS lock created.

NEXT ACTION: Builder R6 must (a) bind the recovery path to an unforgeable RunnerV3-authorized
transaction marker so reconcileV3 cannot promote caller-constructed state; (b) remove/replace the
public `mint(fromJSON:)`/`loadProduction` self-mint surface with a real trust bootstrap or make the
production mint structurally unreachable pre-onboarding; (c) add a governed current-registry
head/monotonic selection so old root-signed registries cannot be replayed. Then a fresh independent
re-audit (AUDIT20).
